import 'dart:convert';

class RoadmapTopic {
  final String id;
  final String name;
  bool isCompleted;
  DateTime? completedAt;
  DateTime? assignedDate;

  // ── Anki / Flashcard & SM-2 fields ───────────────────────────────────────
  String? question;
  String? answer;
  double easeFactor; // default 2.50 (250%)
  int interval;     // interval in days
  int reps;         // total repetitions
  int lapses;       // times failed (pressed Again)
  DateTime? dueDate;// when card is due for review
  int state;        // 0=new, 1=learning, 2=review, 3=relearning

  RoadmapTopic({
    required this.id,
    required this.name,
    this.isCompleted = false,
    this.completedAt,
    this.assignedDate,
    this.question,
    this.answer,
    this.easeFactor = 2.50,
    this.interval = 0,
    this.reps = 0,
    this.lapses = 0,
    this.dueDate,
    this.state = 0,
  });

  /// Check if card is due for review right now
  bool get isDue {
    if (isCompleted) return false;
    if (dueDate == null) return true; // new cards are due
    return dueDate!.isBefore(DateTime.now());
  }

  /// Front content for flashcard
  String get frontContent => question ?? name;

  /// Back content for flashcard
  String get backContent => answer ?? 'Core concept for $name.\nReview and test your understanding.';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isCompleted': isCompleted,
        'completedAt': completedAt?.toIso8601String(),
        'assignedDate': assignedDate?.toIso8601String(),
        'question': question,
        'answer': answer,
        'easeFactor': easeFactor,
        'interval': interval,
        'reps': reps,
        'lapses': lapses,
        'dueDate': dueDate?.toIso8601String(),
        'state': state,
      };

  factory RoadmapTopic.fromJson(Map<String, dynamic> json) => RoadmapTopic(
        id: json['id'] as String,
        name: json['name'] as String,
        isCompleted: json['isCompleted'] as bool? ?? false,
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'] as String)
            : null,
        assignedDate: json['assignedDate'] != null
            ? DateTime.parse(json['assignedDate'] as String)
            : null,
        question: json['question'] as String?,
        answer: json['answer'] as String?,
        easeFactor: (json['easeFactor'] as num?)?.toDouble() ?? 2.50,
        interval: json['interval'] as int? ?? 0,
        reps: json['reps'] as int? ?? 0,
        lapses: json['lapses'] as int? ?? 0,
        dueDate: json['dueDate'] != null
            ? DateTime.parse(json['dueDate'] as String)
            : null,
        state: json['state'] as int? ?? 0,
      );
}

class Roadmap {
  final String id;
  final String name;
  final String url;
  final List<RoadmapTopic> topics;
  final DateTime addedAt;
  int currentIndex;
  bool isAnkiDeck;

  Roadmap({
    required this.id,
    required this.name,
    required this.url,
    required this.topics,
    required this.addedAt,
    this.currentIndex = 0,
    this.isAnkiDeck = false,
  });

  int get completedCount => topics.where((t) => t.isCompleted).length;
  int get totalCount => topics.length;
  double get progress => totalCount > 0 ? completedCount / totalCount : 0;

  // ── Anki Deck metrics ─────────────────────────────────────────────────────
  int get newCount => topics.where((t) => t.state == 0 && !t.isCompleted).length;
  int get learningCount => topics.where((t) => (t.state == 1 || t.state == 3) && !t.isCompleted).length;
  int get dueReviewCount => topics.where((t) => t.state == 2 && t.isDue && !t.isCompleted).length;
  int get totalDueCount => topics.where((t) => t.isDue && !t.isCompleted).length;

  /// Returns cards that are due for study today
  List<RoadmapTopic> get dueCards {
    final list = topics.where((t) => t.isDue && !t.isCompleted).toList();
    // Sort: learning first, then review by dueDate, then new
    list.sort((a, b) {
      if (a.state != b.state) {
        // learning (1, 3) first, then review (2), then new (0)
        final priorityA = a.state == 1 || a.state == 3 ? 0 : (a.state == 2 ? 1 : 2);
        final priorityB = b.state == 1 || b.state == 3 ? 0 : (b.state == 2 ? 1 : 2);
        return priorityA.compareTo(priorityB);
      }
      if (a.dueDate != null && b.dueDate != null) {
        return a.dueDate!.compareTo(b.dueDate!);
      }
      return 0;
    });
    return list;
  }

  RoadmapTopic? get todaysTopic {
    // If it's an Anki deck or has flashcards, recommend the highest priority due card!
    if (isAnkiDeck) {
      final due = dueCards;
      if (due.isNotEmpty) return due.first;
    }
    if (currentIndex >= topics.length) return null;
    return topics[currentIndex];
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'topics': topics.map((t) => t.toJson()).toList(),
        'addedAt': addedAt.toIso8601String(),
        'currentIndex': currentIndex,
        'isAnkiDeck': isAnkiDeck,
      };

  factory Roadmap.fromJson(Map<String, dynamic> json) => Roadmap(
        id: json['id'] as String,
        name: json['name'] as String,
        url: json['url'] as String,
        topics: (json['topics'] as List)
            .map((t) => RoadmapTopic.fromJson(t as Map<String, dynamic>))
            .toList(),
        addedAt: DateTime.parse(json['addedAt'] as String),
        currentIndex: json['currentIndex'] as int? ?? 0,
        isAnkiDeck: json['isAnkiDeck'] as bool? ?? (json['url'] as String? ?? '').startsWith('anki://'),
      );

  String serialize() => jsonEncode(toJson());
  static Roadmap deserialize(String data) =>
      Roadmap.fromJson(jsonDecode(data) as Map<String, dynamic>);
}
