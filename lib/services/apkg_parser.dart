import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/roadmap.dart';

class ApkgParser {
  ApkgParser._();

  /// Parse an .apkg file from bytes (from file picker or download)
  static Future<Roadmap> parseApkgBytes(List<int> bytes, {String? defaultName}) async {
    final archive = ZipDecoder().decodeBytes(bytes);

    ArchiveFile? dbFile;
    for (final file in archive) {
      if (file.name == 'collection.anki2' || file.name == 'collection.anki21') {
        dbFile = file;
        break;
      }
    }

    if (dbFile == null) {
      // Check if it's a media-only zip or plain text export
      return _tryFallbackParse(archive, defaultName ?? 'Anki Deck');
    }

    final tempDir = await getTemporaryDirectory();
    final tempDbPath = '${tempDir.path}/anki_${DateTime.now().millisecondsSinceEpoch}.db';
    final tempFile = File(tempDbPath);

    try {
      await tempFile.writeAsBytes(dbFile.content as List<int>);
      final db = await openReadOnlyDatabase(tempDbPath);

      try {
        // 1. Get Deck Name & Model Definitions from col table
        String deckName = defaultName ?? 'Anki Deck';
        final modelFieldMap = <int, Map<String, int>>{};

        try {
          final colRows = await db.rawQuery('SELECT models, decks FROM col LIMIT 1');
          if (colRows.isNotEmpty) {
            // Deck name: find root non-Default deck
            if (colRows.first['decks'] != null) {
              final decksJson = jsonDecode(colRows.first['decks'] as String) as Map<String, dynamic>;
              final names = <String>[];
              for (final entry in decksJson.values) {
                if (entry is Map<String, dynamic>) {
                  final name = entry['name'] as String?;
                  if (name != null && name.isNotEmpty && name != 'Default') {
                    names.add(name);
                  }
                }
              }
              // Prioritize clean root deck without '::'
              final rootName = names.firstWhere(
                (n) => !n.contains('::'),
                orElse: () => names.isNotEmpty ? names.first.split('::').first : '',
              );
              if (rootName.isNotEmpty) {
                deckName = rootName;
              }
            }

            // Models: map field indices for Front, Back, Stage
            if (colRows.first['models'] != null) {
              final modelsJson = jsonDecode(colRows.first['models'] as String) as Map<String, dynamic>;
              for (final entry in modelsJson.entries) {
                final mid = int.tryParse(entry.key);
                if (mid == null || entry.value is! Map<String, dynamic>) continue;
                final m = entry.value as Map<String, dynamic>;
                final flds = (m['flds'] as List<dynamic>?) ?? [];

                final sortedFlds = List<Map<String, dynamic>>.from(
                  flds.whereType<Map<String, dynamic>>(),
                )..sort((a, b) => ((a['ord'] as int? ?? 0).compareTo(b['ord'] as int? ?? 0)));

                int frontIdx = -1;
                int backIdx = -1;
                int stageIdx = -1;

                for (int i = 0; i < sortedFlds.length; i++) {
                  final fName = (sortedFlds[i]['name'] as String? ?? '').toLowerCase().trim();
                  if (fName == 'front' || fName == 'question' || fName == 'topic' ||
                      fName == 'prompt' || fName == 'term' || fName == 'word' || fName == 'text') {
                    frontIdx = i;
                  } else if (fName == 'back' || fName == 'answer' || fName == 'definition' ||
                             fName == 'meaning' || fName == 'notes' || fName == 'explanation') {
                    backIdx = i;
                  } else if (fName == 'stage' || fName == 'category' || fName == 'tag' ||
                             fName == 'chapter' || fName == 'section' || fName == 'group') {
                    stageIdx = i;
                  }
                }

                // If not explicitly named, assign unused indices
                if (frontIdx == -1) {
                  for (int i = 0; i < sortedFlds.length; i++) {
                    if (i != stageIdx && i != backIdx) {
                      frontIdx = i;
                      break;
                    }
                  }
                }
                if (backIdx == -1) {
                  for (int i = 0; i < sortedFlds.length; i++) {
                    if (i != stageIdx && i != frontIdx) {
                      backIdx = i;
                      break;
                    }
                  }
                }

                modelFieldMap[mid] = {
                  'front': frontIdx != -1 ? frontIdx : 0,
                  'back': backIdx != -1 ? backIdx : (sortedFlds.length > 1 ? 1 : 0),
                  'stage': stageIdx,
                };
              }
            }
          }
        } catch (e) {
          print('Could not read col metadata: $e');
        }

        // 2. Read Notes with accurate field extraction
        final noteRows = await db.rawQuery('SELECT id, mid, flds, tags FROM notes');
        final notesMap = <int, Map<String, String>>{};

        for (final row in noteRows) {
          final id = row['id'] as int;
          final mid = row['mid'] as int? ?? 0;
          final flds = row['flds'] as String? ?? '';
          final parts = flds.split('\x1f');

          final mMapping = modelFieldMap[mid];
          int fIdx = mMapping?['front'] ?? 0;
          int bIdx = mMapping?['back'] ?? 1;
          int sIdx = mMapping?['stage'] ?? -1;

          // Heuristic fallback if model wasn't mapped
          if (mMapping == null && parts.length >= 3) {
            final p0 = parts[0].trim();
            final p1 = parts[1].trim();
            if (p0.length < 40 && (p1.contains('?') || p1.length > p0.length)) {
              fIdx = 1;
              bIdx = 2;
              sIdx = 0;
            }
          }

          final frontRaw = (fIdx < parts.length && parts[fIdx].trim().isNotEmpty)
              ? parts[fIdx]
              : (parts.isNotEmpty ? parts[0] : 'Card $id');
          final backRaw = (bIdx < parts.length && bIdx != fIdx)
              ? parts[bIdx]
              : (parts.length > 1 ? parts[1] : '');
          final stageRaw = (sIdx >= 0 && sIdx < parts.length) ? parts[sIdx] : '';

          notesMap[id] = {
            'front': _cleanHtml(frontRaw),
            'back': _cleanHtml(backRaw),
            'stage': _cleanHtml(stageRaw),
          };
        }

        // 3. Read Cards
        final topics = <RoadmapTopic>[];
        try {
          final cardRows = await db.rawQuery(
            'SELECT id, nid, type, due, ivl, factor, reps, lapses FROM cards ORDER BY id ASC',
          );

          for (final c in cardRows) {
            final cardId = c['id'] as int;
            final nid = c['nid'] as int;
            final note = notesMap[nid];
            if (note == null) continue;

            final type = c['type'] as int? ?? 0;
            final ivl = c['ivl'] as int? ?? 0;
            final factor = (c['factor'] as int? ?? 2500) / 1000.0;
            final reps = c['reps'] as int? ?? 0;
            final lapses = c['lapses'] as int? ?? 0;

            DateTime? dueDate;
            if (type == 2 && ivl > 0) {
              dueDate = DateTime.now().add(Duration(days: ivl > 1 ? ivl : 0));
            } else if (type == 1) {
              dueDate = DateTime.now().add(const Duration(minutes: 10));
            }

            final front = note['front'] ?? 'Topic';
            final back = note['back'] ?? '';
            final stage = note['stage'] ?? '';

            // Clean topic title from the actual question (not repeating stage)
            final topicTitle = front.length > 75 ? '${front.substring(0, 72)}...' : front;

            topics.add(RoadmapTopic(
              id: 'anki-$cardId',
              name: topicTitle,
              question: front,
              answer: back.isNotEmpty ? back : (stage.isNotEmpty ? 'Category: $stage' : 'Master this topic today.'),
              easeFactor: factor > 0 ? factor : 2.50,
              interval: ivl > 0 ? ivl : 0,
              reps: reps,
              lapses: lapses,
              state: type.clamp(0, 3),
              dueDate: dueDate,
            ));
          }
        } catch (e) {
          print('Could not query cards table, falling back to notes: $e');
        }

        // If cards table was empty or failed, create topics from notes
        if (topics.isEmpty) {
          for (final entry in notesMap.entries) {
            final front = entry.value['front']!;
            final back = entry.value['back']!;
            final stage = entry.value['stage'] ?? '';
            final topicTitle = front.length > 75 ? '${front.substring(0, 72)}...' : front;
            topics.add(RoadmapTopic(
              id: 'anki-note-${entry.key}',
              name: topicTitle,
              question: front,
              answer: back.isNotEmpty ? back : (stage.isNotEmpty ? 'Category: $stage' : 'Master this topic today.'),
              state: 0,
            ));
          }
        }

        if (topics.isEmpty) {
          throw Exception('The Anki package did not contain any valid flashcards.');
        }

        final slug = 'anki-${deckName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-')}';

        return Roadmap(
          id: slug,
          name: deckName,
          url: 'anki://$slug',
          topics: topics,
          addedAt: DateTime.now(),
          isAnkiDeck: true,
        );
      } finally {
        await db.close();
      }
    } finally {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  /// Clean HTML markup from Anki cards into clean readable text
  static String _cleanHtml(String html) {
    if (html.isEmpty) return '';

    var clean = html
        .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</div>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'</li>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'&nbsp;', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'&lt;', caseSensitive: false), '<')
        .replaceAll(RegExp(r'&gt;', caseSensitive: false), '>')
        .replaceAll(RegExp(r'&amp;', caseSensitive: false), '&')
        .replaceAll(RegExp(r'&quot;', caseSensitive: false), '"')
        .replaceAll(RegExp(r'&#39;', caseSensitive: false), "'")
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim();

    // Clean multiple consecutive newlines
    clean = clean.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return clean;
  }

  /// Fallback if SQLite file was missing
  static Roadmap _tryFallbackParse(Archive archive, String fallbackName) {
    for (final file in archive) {
      if (file.name.endsWith('.txt') || file.name.endsWith('.tsv')) {
        final content = utf8.decode(file.content as List<int>);
        final lines = content.split('\n');
        final topics = <RoadmapTopic>[];

        for (int i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.isEmpty || line.startsWith('#')) continue;
          final cols = line.split('\t');
          final front = cols.isNotEmpty ? cols[0] : 'Card $i';
          final back = cols.length > 1 ? cols[1] : '';

          topics.add(RoadmapTopic(
            id: 'anki-txt-$i',
            name: front.length > 50 ? '${front.substring(0, 47)}...' : front,
            question: front,
            answer: back,
          ));
        }

        if (topics.isNotEmpty) {
          final slug = 'anki-${fallbackName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-')}';
          return Roadmap(
            id: slug,
            name: fallbackName,
            url: 'anki://$slug',
            topics: topics,
            addedAt: DateTime.now(),
            isAnkiDeck: true,
          );
        }
      }
    }
    throw Exception('Could not find collection.anki2 or card data inside the APKG package.');
  }

  /// Built-in sample Anki decks to let user test immediately
  static Roadmap getSampleDeck(String key) {
    if (key == 'python') {
      return Roadmap(
        id: 'anki-python-core',
        name: 'Python Core & Algorithms (Anki)',
        url: 'anki://python-core',
        addedAt: DateTime.now(),
        isAnkiDeck: true,
        topics: [
          RoadmapTopic(
            id: 'py-1',
            name: 'Mutable vs Immutable in Python',
            question: 'What is the fundamental difference between Mutable and Immutable objects in Python?\nGive 2 examples of each.',
            answer: '• Immutable objects cannot be modified after creation. Modifying creates a new object.\nExamples: int, float, str, tuple, frozenset.\n\n• Mutable objects can be modified in-place.\nExamples: list, dict, set, bytearray.',
          ),
          RoadmapTopic(
            id: 'py-2',
            name: 'Python GIL (Global Interpreter Lock)',
            question: 'What is the Global Interpreter Lock (GIL) and why does it affect CPU-bound multi-threaded programs in CPython?',
            answer: 'The GIL is a mutex that prevents multiple native OS threads from executing Python bytecodes simultaneously in CPython.\n\nFor CPU-bound tasks, threading does not provide speedup. Use multiprocessing or concurrent.futures.ProcessPoolExecutor instead.',
          ),
          RoadmapTopic(
            id: 'py-3',
            name: 'Generators vs List Comprehensions',
            question: 'What is the difference in memory and evaluation between (x for x in data) and [x for x in data]?',
            answer: '• (x for x in data) is a Generator Expression: Lazy evaluation, generates items on-demand using next(), O(1) memory.\n\n• [x for x in data] is a List Comprehension: Eager evaluation, constructs the entire list in RAM at once, O(N) memory.',
          ),
          RoadmapTopic(
            id: 'py-4',
            name: '__init__ vs __new__',
            question: 'What is the difference between __new__ and __init__ in Python OOP?',
            answer: '• __new__(cls, ...) is the constructor: it actually allocates and returns the new instance.\n\n• __init__(self, ...) is the initializer: it receives the created instance to initialize its attributes.\n__new__ is used for singletons and immutable types.',
          ),
          RoadmapTopic(
            id: 'py-5',
            name: 'Time Complexity of Python Dict & Set',
            question: 'What is the average and worst-case time complexity for key lookup in a Python dictionary or set?',
            answer: '• Average Case: O(1) constant time lookup via hash table.\n\n• Worst Case: O(N) linear time if hash collisions occur across all keys.',
          ),
        ],
      );
    } else {
      return Roadmap(
        id: 'anki-sql-mastery',
        name: 'SQL & Database Design (Anki)',
        url: 'anki://sql-mastery',
        addedAt: DateTime.now(),
        isAnkiDeck: true,
        topics: [
          RoadmapTopic(
            id: 'sql-1',
            name: 'WHERE vs HAVING',
            question: 'What is the exact execution difference between WHERE and HAVING in SQL?',
            answer: '• WHERE filters rows BEFORE aggregation (GROUP BY) occurs.\n\n• HAVING filters grouped rows AFTER aggregation (GROUP BY) occurs and can evaluate aggregate functions like COUNT(), SUM(), AVG().',
          ),
          RoadmapTopic(
            id: 'sql-2',
            name: 'ACID Properties',
            question: 'Define the 4 ACID properties of relational database transactions.',
            answer: '• Atomicity: All operations succeed or all roll back (all-or-nothing).\n• Consistency: Database moves from one valid state to another, preserving constraints.\n• Isolation: Concurrent transactions do not interfere with each other.\n• Durability: Committed transactions persist permanently even after system failure.',
          ),
          RoadmapTopic(
            id: 'sql-3',
            name: 'Clustered vs Non-Clustered Index',
            question: 'What is the difference between a Clustered and Non-Clustered index?',
            answer: '• Clustered Index: Sorts and physically stores the actual table data rows in order. Only ONE clustered index per table (typically Primary Key).\n\n• Non-Clustered Index: Stored in a separate structure containing index key values and row pointers to physical data. Can have multiple.',
          ),
        ],
      );
    }
  }
}
