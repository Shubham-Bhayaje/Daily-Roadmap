import '../models/daily_practice.dart';
import '../models/roadmap.dart';
import 'storage_service.dart';

class PracticeManager {
  final StorageService _storage;

  PracticeManager(this._storage);

  /// Check if we need to advance to the next topic (new day).
  bool shouldAdvance() {
    final lastDate = _storage.getLastAdvanceDate();
    if (lastDate == null) return true;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last = DateTime(lastDate.year, lastDate.month, lastDate.day);

    return today.isAfter(last);
  }

  /// Advance all roadmaps to their next topic.
  Future<void> advanceTopics(List<Roadmap> roadmaps) async {
    for (final roadmap in roadmaps) {
      if (roadmap.isAnkiDeck) {
        // Anki decks use SM-2 spaced repetition dates; no simple linear advance needed
        continue;
      }

      // Find the next uncompleted topic
      bool found = false;
      for (int i = roadmap.currentIndex; i < roadmap.topics.length; i++) {
        if (!roadmap.topics[i].isCompleted) {
          roadmap.currentIndex = i;
          roadmap.topics[i].assignedDate = DateTime.now();
          found = true;
          break;
        }
      }
      // If all from current index onwards are done, wrap around
      if (!found) {
        for (int i = 0; i < roadmap.currentIndex; i++) {
          if (!roadmap.topics[i].isCompleted) {
            roadmap.currentIndex = i;
            roadmap.topics[i].assignedDate = DateTime.now();
            found = true;
            break;
          }
        }
      }
    }

    await _storage.setLastAdvanceDate(DateTime.now());
    await _storage.saveRoadmaps(roadmaps);
  }

  /// Get today's practice items — one topic per roadmap.
  List<DailyPractice> getTodaysPractice(List<Roadmap> roadmaps) {
    final practices = <DailyPractice>[];

    for (final roadmap in roadmaps) {
      final topic = roadmap.todaysTopic;
      if (topic != null) {
        final topicIdx = roadmap.topics.indexOf(topic);
        practices.add(DailyPractice(
          roadmapId: roadmap.id,
          roadmapName: roadmap.name,
          topicName: topic.name,
          topicId: topic.id,
          topicIndex: topicIdx != -1 ? topicIdx : roadmap.currentIndex,
          isCompleted: topic.isCompleted,
          isAnkiDeck: roadmap.isAnkiDeck,
          question: topic.question,
          answer: topic.answer,
        ));
      }
    }

    return practices;
  }

  /// Mark a topic as completed and advance to next.
  Future<void> completeTopic(
    List<Roadmap> roadmaps,
    String roadmapId,
    int topicIndex,
  ) async {
    final roadmap = roadmaps.firstWhere((r) => r.id == roadmapId);
    if (topicIndex < roadmap.topics.length) {
      roadmap.topics[topicIndex].isCompleted = true;
      roadmap.topics[topicIndex].completedAt = DateTime.now();

      if (!roadmap.isAnkiDeck) {
        // Advance to next uncompleted topic for standard roadmaps
        for (int i = topicIndex + 1; i < roadmap.topics.length; i++) {
          if (!roadmap.topics[i].isCompleted) {
            roadmap.currentIndex = i;
            break;
          }
        }
      }
    }

    await _storage.saveRoadmaps(roadmaps);
  }
}
