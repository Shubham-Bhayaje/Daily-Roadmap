import '../models/roadmap.dart';

enum AnkiRating {
  again, // 1: Failed recall
  hard,  // 2: Recalled with serious difficulty
  good,  // 3: Recalled with normal effort
  easy,  // 4: Perfect recall with zero effort
}

class AnkiScheduleResult {
  final DateTime nextDue;
  final int nextInterval; // In days
  final double nextEase;
  final int nextState;    // 0=new, 1=learning, 2=review, 3=relearning
  final int nextReps;
  final int nextLapses;
  final String label;     // e.g. "< 1m", "1d", "4d"

  AnkiScheduleResult({
    required this.nextDue,
    required this.nextInterval,
    required this.nextEase,
    required this.nextState,
    required this.nextReps,
    required this.nextLapses,
    required this.label,
  });
}

class AnkiScheduler {
  AnkiScheduler._();

  static const double minEase = 1.30;
  static const double defaultEase = 2.50;
  static const double easyBonus = 1.30;

  /// Calculate the new card schedule after user gives a rating
  static AnkiScheduleResult schedule(RoadmapTopic topic, AnkiRating rating) {
    final now = DateTime.now();
    final currentState = topic.state;
    final currentEase = topic.easeFactor <= 0 ? defaultEase : topic.easeFactor;
    final currentIvl = topic.interval;
    final reps = topic.reps + 1;
    var lapses = topic.lapses;

    DateTime nextDue;
    int nextIvl;
    double nextEase = currentEase;
    int nextState;

    // ── NEW OR LEARNING CARD ───────────────────────────────────────────────
    if (currentState == 0 || currentState == 1) {
      switch (rating) {
        case AnkiRating.again:
          nextDue = now.add(const Duration(minutes: 1));
          nextIvl = 0;
          nextState = 1; // learning
          break;
        case AnkiRating.hard:
          nextDue = now.add(const Duration(minutes: 6));
          nextIvl = 0;
          nextState = 1;
          break;
        case AnkiRating.good:
          if (topic.reps == 0) {
            // First good -> 10 minutes step
            nextDue = now.add(const Duration(minutes: 10));
            nextIvl = 0;
            nextState = 1;
          } else {
            // Graduate to review
            nextIvl = 1;
            nextDue = now.add(const Duration(days: 1));
            nextState = 2; // review
          }
          break;
        case AnkiRating.easy:
          // Immediately graduate with easy bonus
          nextIvl = 4;
          nextDue = now.add(const Duration(days: 4));
          nextState = 2;
          nextEase = currentEase + 0.15;
          break;
      }
    }
    // ── RELEARNING CARD (after lapse) ──────────────────────────────────────
    else if (currentState == 3) {
      switch (rating) {
        case AnkiRating.again:
          nextDue = now.add(const Duration(minutes: 1));
          nextIvl = 0;
          nextState = 3;
          break;
        case AnkiRating.hard:
          nextDue = now.add(const Duration(minutes: 6));
          nextIvl = 0;
          nextState = 3;
          break;
        case AnkiRating.good:
          nextIvl = 1;
          nextDue = now.add(const Duration(days: 1));
          nextState = 2;
          break;
        case AnkiRating.easy:
          nextIvl = 2;
          nextDue = now.add(const Duration(days: 2));
          nextState = 2;
          break;
      }
    }
    // ── REVIEW CARD (Graduated SM-2) ───────────────────────────────────────
    else {
      final safeIvl = currentIvl < 1 ? 1 : currentIvl;

      switch (rating) {
        case AnkiRating.again:
          lapses += 1;
          nextEase = (currentEase - 0.20).clamp(minEase, 5.0);
          nextIvl = 1;
          nextDue = now.add(const Duration(minutes: 10));
          nextState = 3; // relearning
          break;

        case AnkiRating.hard:
          nextEase = (currentEase - 0.15).clamp(minEase, 5.0);
          nextIvl = (safeIvl * 1.2).round();
          if (nextIvl <= safeIvl) nextIvl = safeIvl + 1;
          nextDue = now.add(Duration(days: nextIvl));
          nextState = 2;
          break;

        case AnkiRating.good:
          nextIvl = (safeIvl * currentEase).round();
          if (nextIvl <= safeIvl) nextIvl = safeIvl + 1;
          nextDue = now.add(Duration(days: nextIvl));
          nextState = 2;
          break;

        case AnkiRating.easy:
          nextEase = currentEase + 0.15;
          nextIvl = (safeIvl * currentEase * easyBonus).round();
          if (nextIvl <= safeIvl) nextIvl = safeIvl + 2;
          nextDue = now.add(Duration(days: nextIvl));
          nextState = 2;
          break;
      }
    }

    final label = _formatInterval(nextDue.difference(now), nextIvl);

    return AnkiScheduleResult(
      nextDue: nextDue,
      nextInterval: nextIvl,
      nextEase: nextEase,
      nextState: nextState,
      nextReps: reps,
      nextLapses: lapses,
      label: label,
    );
  }

  /// Get estimated interval preview labels for all 4 buttons (AnkiDroid style)
  static Map<AnkiRating, String> getPreviewLabels(RoadmapTopic topic) {
    return {
      AnkiRating.again: schedule(topic, AnkiRating.again).label,
      AnkiRating.hard: schedule(topic, AnkiRating.hard).label,
      AnkiRating.good: schedule(topic, AnkiRating.good).label,
      AnkiRating.easy: schedule(topic, AnkiRating.easy).label,
    };
  }

  static String _formatInterval(Duration diff, int days) {
    if (days >= 365) {
      final years = (days / 365).toStringAsFixed(1);
      return '${years}y';
    }
    if (days >= 30) {
      final months = (days / 30).toStringAsFixed(1);
      return '${months}mo';
    }
    if (days >= 1) {
      return '${days}d';
    }
    final mins = diff.inMinutes;
    if (mins <= 1) return '< 1m';
    if (mins < 60) return '< ${mins}m';
    return '< ${diff.inHours}h';
  }
}
