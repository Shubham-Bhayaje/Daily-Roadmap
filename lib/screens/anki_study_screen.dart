import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/roadmap.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class AnkiStudyScreen extends StatefulWidget {
  final Roadmap roadmap;

  const AnkiStudyScreen({super.key, required this.roadmap});

  @override
  State<AnkiStudyScreen> createState() => _AnkiStudyScreenState();
}

class _AnkiStudyScreenState extends State<AnkiStudyScreen> {
  int _currentCardIndex = 0;
  int _cardsReviewedSession = 0;
  List<RoadmapTopic> _studyQueue = [];

  // Undo support
  RoadmapTopic? _lastReviewedTopic;
  Map<String, dynamic>? _lastTopicPreviousState;

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  void _loadQueue() {
    final due = widget.roadmap.dueCards;
    if (due.isNotEmpty) {
      _studyQueue = List.from(due);
    } else {
      // If no cards strictly due, take uncompleted cards
      _studyQueue = widget.roadmap.topics.where((t) => !t.isCompleted).toList();
    }
    _currentCardIndex = 0;
  }

  RoadmapTopic? get _currentCard {
    if (_currentCardIndex < _studyQueue.length) {
      return _studyQueue[_currentCardIndex];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final currentRoadmap = provider.roadmaps
            .where((r) => r.id == widget.roadmap.id)
            .firstOrNull ?? widget.roadmap;

        final isFinished = _currentCard == null;

        return Scaffold(
          backgroundColor: AppColors.canvas,
          appBar: _buildAppBar(context, currentRoadmap),
          body: SafeArea(
            child: isFinished
                ? _buildSessionCompleted(context, currentRoadmap)
                : _buildCardStudyView(context, provider, currentRoadmap),
          ),
        );
      },
    );
  }

  // ── Top App Bar ────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext context, Roadmap roadmap) {
    return AppBar(
      backgroundColor: AppColors.canvas,
      foregroundColor: AppColors.textPrimary,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            roadmap.name,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            'Daily Practice & Spaced Learning',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
      actions: [
        // Undo button
        if (_lastReviewedTopic != null)
          IconButton(
            icon: const Icon(Icons.undo, size: 20),
            tooltip: 'Undo last card',
            onPressed: () => _undoLastRating(),
          ),
        // Counters: Blue (New), Orange (Learning), Green (Mastered)
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _countBadge(roadmap.newCount, const Color(0xFF4A9DFF), 'New'),
              const SizedBox(width: 6),
              _countBadge(roadmap.learningCount, const Color(0xFFFF9900), 'Learn'),
              const SizedBox(width: 6),
              _countBadge(roadmap.completedCount, AppColors.accent, 'Done'),
            ],
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textMuted),
          color: AppColors.surface2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tooltip: 'Deck options',
          onSelected: (val) {
            if (val == 'delete') {
              _confirmDeleteDeck(context, roadmap);
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                  SizedBox(width: 10),
                  Text('Delete Deck', style: TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _countBadge(int count, Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ── Card Study View (Topic & Notes directly visible) ───────────────────────

  Widget _buildCardStudyView(BuildContext context, AppProvider provider, Roadmap roadmap) {
    final card = _currentCard!;
    final hasDetails = card.answer != null && card.answer!.isNotEmpty;

    return Column(
      children: [
        // Progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _studyQueue.isEmpty ? 0 : (_currentCardIndex / _studyQueue.length),
                    minHeight: 4,
                    backgroundColor: AppColors.surface3,
                    valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_currentCardIndex + 1}/${_studyQueue.length}',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // Main Card Body
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 340),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // State badge & repetition info
                  Row(
                    children: [
                      _cardStateBadge(card.state),
                      const Spacer(),
                      if (card.reps > 0)
                        Text(
                          '${card.reps} reviews',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // TOPIC / QUESTION
                  Text(
                    'TOPIC',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    card.frontContent,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),

                  // DETAILS / EXPLANATION directly visible
                  if (hasDetails) ...[
                    const SizedBox(height: 22),
                    Container(
                      height: 1.5,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.accent.withOpacity(0.5),
                            AppColors.surface3,
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'CONCEPT & NOTES',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      card.backContent,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                        height: 1.55,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 24),
                    Text(
                      'Master this concept for your daily roadmap practice. Review and apply this concept today.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // ── Two Clean Buttons: LEARN & DONE ─────────────────────────────────
        _buildLearnAndDoneButtons(context, provider, card),
      ],
    );
  }

  Widget _cardStateBadge(int state) {
    Color color;
    String label;
    switch (state) {
      case 1:
        color = const Color(0xFFFF9900);
        label = 'LEARNING';
        break;
      case 2:
        color = AppColors.accent;
        label = 'MASTERED';
        break;
      case 3:
        color = const Color(0xFFFF4466);
        label = 'PRACTICE AGAIN';
        break;
      case 0:
      default:
        color = const Color(0xFF4A9DFF);
        label = 'NEW';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }

  // ── Two Buttons: "Learn" & "Done" ──────────────────────────────────────────

  Widget _buildLearnAndDoneButtons(BuildContext context, AppProvider provider, RoadmapTopic card) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: const BoxDecoration(
        color: AppColors.surface1,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // ── LEARN BUTTON (Needs more practice / review again) ────────────
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => _onLearnPressed(provider, card),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text(
                    'Learn',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF9900),
                    side: BorderSide(color: const Color(0xFFFF9900).withOpacity(0.6), width: 1.5),
                    backgroundColor: const Color(0xFFFF9900).withOpacity(0.08),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 14),

            // ── DONE BUTTON (Mastered / Completed) ───────────────────────────
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: () => _onDonePressed(provider, card),
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.canvas,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Handlers for Learn & Done ──────────────────────────────────────────────

  void _onLearnPressed(AppProvider provider, RoadmapTopic card) {
    HapticFeedback.lightImpact();

    _saveUndoState(card);

    // Keep in learning queue
    card.state = 1; // learning
    card.reps += 1;
    card.isCompleted = false;
    card.dueDate = DateTime.now().add(const Duration(days: 1)); // review again tomorrow

    provider.notifyDeckUpdated(widget.roadmap.id);

    // Add to the end of the current session queue so user sees it again
    _studyQueue.add(card);

    setState(() {
      _currentCardIndex++;
    });
  }

  void _onDonePressed(AppProvider provider, RoadmapTopic card) {
    HapticFeedback.mediumImpact();

    _saveUndoState(card);

    // Mark as completed / mastered
    card.state = 2; // mastered / review
    card.reps += 1;
    card.isCompleted = true;
    card.completedAt = DateTime.now();

    // SM-2 Spaced Repetition scheduling for future review
    final currentIvl = card.interval <= 0 ? 1 : card.interval;
    card.interval = (currentIvl * card.easeFactor).round().clamp(1, 180);
    card.dueDate = DateTime.now().add(Duration(days: card.interval));

    _cardsReviewedSession++;

    provider.notifyDeckUpdated(widget.roadmap.id);

    setState(() {
      _currentCardIndex++;
    });
  }

  void _saveUndoState(RoadmapTopic card) {
    _lastReviewedTopic = card;
    _lastTopicPreviousState = {
      'easeFactor': card.easeFactor,
      'interval': card.interval,
      'reps': card.reps,
      'lapses': card.lapses,
      'dueDate': card.dueDate,
      'state': card.state,
      'isCompleted': card.isCompleted,
      'completedAt': card.completedAt,
    };
  }

  void _undoLastRating() {
    if (_lastReviewedTopic == null || _lastTopicPreviousState == null) return;
    HapticFeedback.lightImpact();

    setState(() {
      _lastReviewedTopic!.easeFactor = _lastTopicPreviousState!['easeFactor'] as double;
      _lastReviewedTopic!.interval = _lastTopicPreviousState!['interval'] as int;
      _lastReviewedTopic!.reps = _lastTopicPreviousState!['reps'] as int;
      _lastReviewedTopic!.lapses = _lastTopicPreviousState!['lapses'] as int;
      _lastReviewedTopic!.dueDate = _lastTopicPreviousState!['dueDate'] as DateTime?;
      _lastReviewedTopic!.state = _lastTopicPreviousState!['state'] as int;
      _lastReviewedTopic!.isCompleted = _lastTopicPreviousState!['isCompleted'] as bool;
      _lastReviewedTopic!.completedAt = _lastTopicPreviousState!['completedAt'] as DateTime?;

      if (_currentCardIndex > 0) _currentCardIndex--;
      _lastReviewedTopic = null;
      _lastTopicPreviousState = null;
    });

    context.read<AppProvider>().notifyDeckUpdated(widget.roadmap.id);
  }

  // ── Session Completed Screen ───────────────────────────────────────────────

  Widget _buildSessionCompleted(BuildContext context, Roadmap roadmap) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, size: 54, color: AppColors.accent),
            ),
            const SizedBox(height: 24),
            const Text(
              'All Done for Today! 🎉',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You have reviewed today\'s topics for ${roadmap.name}. Great consistency on your daily roadmap!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),
            // Session Stats
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem('Completed', '$_cardsReviewedSession', AppColors.accent),
                  Container(width: 1, height: 30, color: AppColors.border),
                  _statItem('Total Topics', '${roadmap.totalCount}', AppColors.info),
                  Container(width: 1, height: 30, color: AppColors.border),
                  _statItem('Mastered', '${roadmap.completedCount}', AppColors.warning),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.canvas,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Back to Dashboard', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ],
    );
  }

  void _confirmDeleteDeck(BuildContext context, Roadmap roadmap) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline, color: AppColors.error, size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delete Deck',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${roadmap.name}"? All cards and progress will be permanently removed.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          FilledButton.icon(
            onPressed: () {
              context.read<AppProvider>().removeRoadmap(roadmap.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.delete, size: 16),
            label: const Text('Delete'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
