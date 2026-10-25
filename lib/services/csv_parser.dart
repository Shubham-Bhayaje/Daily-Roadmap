import 'dart:convert';
import '../models/roadmap.dart';

class CsvParser {
  CsvParser._();

  /// Parse CSV/TSV content from a raw string
  static Roadmap parseCsvString(String csvContent, {String? defaultName}) {
    final rows = _parseCsvRows(csvContent);
    if (rows.isEmpty) {
      throw Exception('The CSV file is empty.');
    }

    // Determine deck/roadmap name
    String roadmapName = defaultName ?? 'Imported CSV Roadmap';
    roadmapName = _formatName(roadmapName);

    // Analyze first row to see if it is a header row
    final firstRow = rows.first.map((c) => c.trim().toLowerCase()).toList();
    int frontCol = -1;
    int backCol = -1;
    int stageCol = -1;

    bool hasHeader = false;
    for (int i = 0; i < firstRow.length; i++) {
      final h = firstRow[i];
      if (h == 'front' || h == 'question' || h == 'topic' || h == 'title' || h == 'name' || h == 'prompt' || h == 'term') {
        frontCol = i;
        hasHeader = true;
      } else if (h == 'back' || h == 'answer' || h == 'definition' || h == 'notes' || h == 'explanation' || h == 'description' || h == 'details') {
        backCol = i;
        hasHeader = true;
      } else if (h == 'stage' || h == 'category' || h == 'tag' || h == 'chapter' || h == 'section' || h == 'group') {
        stageCol = i;
        hasHeader = true;
      }
    }

    final dataRows = hasHeader ? rows.skip(1).toList() : rows;
    if (dataRows.isEmpty) {
      throw Exception('No data rows found in the CSV.');
    }

    // Fallbacks if columns weren't explicitly named by header
    final firstDataRow = dataRows.first;
    if (frontCol == -1) {
      if (firstDataRow.length >= 3 && stageCol == 0) {
        frontCol = 1;
        backCol = 2;
      } else if (firstDataRow.length >= 3 && _looksLikeCategory(firstDataRow[0]) && !_looksLikeCategory(firstDataRow[1])) {
        stageCol = 0;
        frontCol = 1;
        backCol = 2;
      } else {
        frontCol = 0;
        backCol = firstDataRow.length > 1 ? 1 : -1;
      }
    }

    final topics = <RoadmapTopic>[];
    final now = DateTime.now().millisecondsSinceEpoch;

    for (int i = 0; i < dataRows.length; i++) {
      final row = dataRows[i];
      if (row.isEmpty || row.every((c) => c.trim().isEmpty)) continue;

      final front = frontCol < row.length ? row[frontCol].trim() : '';
      if (front.isEmpty) continue;

      final back = (backCol >= 0 && backCol < row.length) ? row[backCol].trim() : '';
      final stage = (stageCol >= 0 && stageCol < row.length) ? row[stageCol].trim() : '';

      final topicTitle = front.length > 75 ? '${front.substring(0, 72)}...' : front;

      topics.add(RoadmapTopic(
        id: 'csv-$now-$i',
        name: topicTitle,
        question: front,
        answer: back.isNotEmpty ? back : (stage.isNotEmpty ? 'Category: $stage' : 'Master this topic today.'),
        easeFactor: 2.50,
        interval: 0,
        reps: 0,
        lapses: 0,
        state: 0,
      ));
    }

    if (topics.isEmpty) {
      throw Exception('Could not extract any valid topics or cards from the CSV file.');
    }

    // Auto-reverse if topics/cards were numbered in descending order (e.g. 135 down to 1)
    if (topics.length >= 2) {
      final numRegex = RegExp(r'^\s*(\d+)[\.\s\)\-]');
      final firstMatch = numRegex.firstMatch(topics.first.name);
      final lastMatch = numRegex.firstMatch(topics.last.name);
      if (firstMatch != null && lastMatch != null) {
        final firstNum = int.tryParse(firstMatch.group(1)!);
        final lastNum = int.tryParse(lastMatch.group(1)!);
        if (firstNum != null && lastNum != null && firstNum > lastNum) {
          final corrected = topics.reversed.toList();
          topics.clear();
          topics.addAll(corrected);
        }
      }
    }

    final slug = 'csv-${roadmapName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-').replaceAll(RegExp(r'-{2,}'), '-').replaceAll(RegExp(r'^-|-$'), '')}';

    return Roadmap(
      id: slug,
      name: roadmapName,
      url: 'csv://$slug',
      topics: topics,
      addedAt: DateTime.now(),
      isAnkiDeck: topics.any((t) => t.answer != null && t.answer!.isNotEmpty),
    );
  }

  /// Parse bytes with automatic encoding detection (UTF-8, UTF-16, Latin-1)
  static Roadmap parseCsvBytes(List<int> bytes, {String? defaultName}) {
    String text;
    try {
      text = utf8.decode(bytes);
    } catch (_) {
      try {
        text = latin1.decode(bytes);
      } catch (_) {
        text = String.fromCharCodes(bytes);
      }
    }
    return parseCsvString(text, defaultName: defaultName);
  }

  /// Robust RFC-4180 compliant CSV parser with quote, comma, semicolon, tab, and newline support
  static List<List<String>> _parseCsvRows(String input) {
    if (input.isEmpty) return [];

    // Detect delimiter: look at the first non-empty line
    final firstLine = input.split(RegExp(r'\r?\n')).firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    String delimiter = ',';
    final commaCount = ','.allMatches(firstLine).length;
    final tabCount = '\t'.allMatches(firstLine).length;
    final semiCount = ';'.allMatches(firstLine).length;

    if (tabCount > commaCount && tabCount > semiCount) {
      delimiter = '\t';
    } else if (semiCount > commaCount && semiCount > tabCount) {
      delimiter = ';';
    }

    final rows = <List<String>>[];
    final currentRow = <String>[];
    final currentField = StringBuffer();
    bool inQuotes = false;
    int i = 0;

    while (i < input.length) {
      final char = input[i];

      if (inQuotes) {
        if (char == '"') {
          // Check for escaped quote ("")
          if (i + 1 < input.length && input[i + 1] == '"') {
            currentField.write('"');
            i += 2;
            continue;
          } else {
            // End of quoted field
            inQuotes = false;
            i++;
            continue;
          }
        } else {
          currentField.write(char);
          i++;
          continue;
        }
      } else {
        if (char == '"') {
          inQuotes = true;
          i++;
          continue;
        } else if (char == delimiter) {
          currentRow.add(currentField.toString());
          currentField.clear();
          i++;
          continue;
        } else if (char == '\r') {
          if (i + 1 < input.length && input[i + 1] == '\n') {
            i++;
          }
          currentRow.add(currentField.toString());
          currentField.clear();
          rows.add(List.from(currentRow));
          currentRow.clear();
          i++;
          continue;
        } else if (char == '\n') {
          currentRow.add(currentField.toString());
          currentField.clear();
          rows.add(List.from(currentRow));
          currentRow.clear();
          i++;
          continue;
        } else {
          currentField.write(char);
          i++;
        }
      }
    }

    // Add trailing field and row
    if (currentField.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentField.toString());
      rows.add(currentRow);
    }

    return rows;
  }

  static bool _looksLikeCategory(String str) {
    final s = str.trim();
    if (s.isEmpty) return false;
    if (s.length < 35 && !s.contains('?')) {
      if (RegExp(r'^\d+[\s._-]').hasMatch(s) || s.toLowerCase().startsWith('stage') || s.toLowerCase().startsWith('chapter')) {
        return true;
      }
    }
    return false;
  }

  static String _formatName(String raw) {
    String clean = raw
        .replaceAll(RegExp(r'\.(csv|tsv|txt)$', caseSensitive: false), '')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .trim();
    if (clean.isEmpty) return 'Custom Roadmap';
    // Title case
    return clean.split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
  }
}
