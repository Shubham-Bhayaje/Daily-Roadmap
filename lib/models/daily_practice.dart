class DailyPractice {
  final String roadmapId;
  final String roadmapName;
  final String topicName;
  final String topicId;
  final int topicIndex;
  bool isCompleted;
  final bool isAnkiDeck;
  final String? question;
  final String? answer;

  DailyPractice({
    required this.roadmapId,
    required this.roadmapName,
    required this.topicName,
    required this.topicId,
    required this.topicIndex,
    this.isCompleted = false,
    this.isAnkiDeck = false,
    this.question,
    this.answer,
  });
}
