import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/roadmap.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'edit_roadmap_screen.dart';
import 'anki_study_screen.dart';

class RoadmapDetailScreen extends StatefulWidget {
  final Roadmap roadmap;

  const RoadmapDetailScreen({super.key, required this.roadmap});

  @override
  State<RoadmapDetailScreen> createState() => _RoadmapDetailScreenState();
}

class _RoadmapDetailScreenState extends State<RoadmapDetailScreen> {
  final Set<int> _expandedIndices = {};

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final current = provider.roadmaps
            .where((r) => r.id == widget.roadmap.id)
            .firstOrNull;

        if (current == null) {
          return Scaffold(
            backgroundColor: AppColors.canvas,
            appBar: AppBar(title: Text(widget.roadmap.name)),
            body: const Center(child: Text('Roadmap not found')),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.canvas,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              _buildAppBar(context, current, provider),
              SliverToBoxAdapter(child: _progressHeader(context, current)),
              SliverToBoxAdapter(child: const SizedBox(height: 14)),
              SliverToBoxAdapter(child: _ankiStudyCard(context, current)),
              SliverToBoxAdapter(child: const SizedBox(height: 18)),
              _topicsList(context, current, provider),
              SliverToBoxAdapter(child: _buildDeleteSection(context, provider, current)),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        );
      },
    );
  }

  // ── App bar ────────────────────────────────────────────────────────────────

  SliverAppBar _buildAppBar(BuildContext context, Roadmap r, AppProvider p) {
    return SliverAppBar(
      backgroundColor: AppColors.canvas,
      foregroundColor: AppColors.textPrimary,
      pinned: true,
      title: Text(
        AppColors.fixTopicName(r.name),
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 22),
          tooltip: 'Edit roadmap',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditRoadmapScreen(roadmap: r),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 22),
          tooltip: 'Remove roadmap',
          onPressed: () => _confirmDelete(context, p),
          style: IconButton.styleFrom(foregroundColor: AppColors.error),
        ),
      ],
    );
  }

  // ── Progress header ────────────────────────────────────────────────────────

  Widget _progressHeader(BuildContext context, Roadmap r) {
    final color = AppColors.roadmapColor(r.id);
    final pct = r.progress;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            // Large circular progress
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: pct,
                      strokeWidth: 8,
                      strokeCap: StrokeCap.round,
                      backgroundColor: AppColors.surface3,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(pct * 100).toInt()}%',
                        style: TextStyle(
                          color: color,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Text(
                        'complete',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _miniStat('Done', '${r.completedCount}', AppColors.success),
                Container(width: 1, height: 30, color: AppColors.border),
                _miniStat('Remaining', '${r.totalCount - r.completedCount}', AppColors.warning),
                Container(width: 1, height: 30, color: AppColors.border),
                _miniStat('Total', '${r.totalCount}', AppColors.info),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Anki Study Action Card ─────────────────────────────────────────────────

  Widget _ankiStudyCard(BuildContext context, Roadmap r) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF4A9DFF).withOpacity(0.35)),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF4A9DFF).withOpacity(0.08),
              AppColors.surface1,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A9DFF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.style, color: Color(0xFF4A9DFF), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Daily Practice Mode',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          // Counts
                          _ankiBadge('${r.newCount}', const Color(0xFF4A9DFF)),
                          const SizedBox(width: 4),
                          _ankiBadge('${r.learningCount}', const Color(0xFFFF9900)),
                          const SizedBox(width: 4),
                          _ankiBadge('${r.completedCount}', AppColors.accent),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Smart Spaced Practice (Learn • Done)',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AnkiStudyScreen(roadmap: r),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow, size: 18),
                label: Text(
                  r.dueCards.isNotEmpty
                      ? 'Study ${r.dueCards.length} Due Cards'
                      : 'Review Flashcards',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4A9DFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ankiBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Topics list ────────────────────────────────────────────────────────────

  SliverList _topicsList(BuildContext context, Roadmap r, AppProvider p) {
    final color = AppColors.roadmapColor(r.id);

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final topic = r.topics[index];
          final isCurrent = index == r.currentIndex && !topic.isCompleted;
          final displayName = AppColors.fixTopicName(topic.name);
          final isExpanded = _expandedIndices.contains(index);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (isExpanded) {
                      _expandedIndices.remove(index);
                    } else {
                      _expandedIndices.add(index);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? color.withOpacity(0.08)
                        : (isExpanded ? AppColors.surface1 : Colors.transparent),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isCurrent
                          ? color.withOpacity(0.3)
                          : (isExpanded ? AppColors.border : Colors.transparent),
                      width: 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Number
                          SizedBox(
                            width: 28,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: topic.isCompleted
                                    ? AppColors.textMuted
                                    : isCurrent
                                        ? color
                                        : AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          // Checkbox (dedicated tap target)
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              if (topic.isCompleted) {
                                p.uncompleteTopic(r.id, index);
                              } else {
                                p.completeTopic(r.id, index);
                              }
                            },
                            child: _topicCheckbox(topic.isCompleted, isCurrent, color),
                          ),
                          const SizedBox(width: 12),
                          // Name
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: TextStyle(
                                    color: topic.isCompleted
                                        ? AppColors.textMuted
                                        : AppColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                    decoration: topic.isCompleted ? TextDecoration.lineThrough : null,
                                    decorationColor: AppColors.textMuted,
                                  ),
                                  maxLines: isExpanded ? 4 : 1,
                                  overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                                ),
                                if (isCurrent)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      "Today's topic",
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (topic.reps > 0)
                            Padding(
                              padding: const EdgeInsets.only(left: 6, right: 4),
                              child: Text(
                                '${topic.interval}d ivl',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                              ),
                            ),
                          Icon(
                            isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textMuted,
                            size: 18,
                          ),
                        ],
                      ),

                      // Expanded full info
                      if (isExpanded) ...[
                        const SizedBox(height: 12),
                        Container(height: 1, color: AppColors.border),
                        const SizedBox(height: 12),
                        SelectableText(
                          displayName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Explanation / Answer / Content
                        if (topic.answer != null && topic.answer!.trim().isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.lightbulb_outline_rounded, size: 14, color: color),
                                    const SizedBox(width: 6),
                                    Text(
                                      'CONCEPT & EXPLANATION',
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                SelectableText(
                                  topic.answer!.trim(),
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        // Actions
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () {
                                  HapticFeedback.mediumImpact();
                                  if (topic.isCompleted) {
                                    p.uncompleteTopic(r.id, index);
                                  } else {
                                    p.completeTopic(r.id, index);
                                  }
                                },
                                icon: Icon(
                                  topic.isCompleted ? Icons.undo_rounded : Icons.check_circle_rounded,
                                  size: 15,
                                ),
                                label: Text(
                                  topic.isCompleted ? 'Mark Incomplete' : 'Mark as Completed',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: topic.isCompleted ? AppColors.surface3 : AppColors.accent,
                                  foregroundColor: topic.isCompleted ? AppColors.textPrimary : AppColors.canvas,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        childCount: r.topics.length,
      ),
    );
  }

  Widget _topicCheckbox(bool isCompleted, bool isCurrent, Color color) {
    if (isCompleted) {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.accent,
        ),
        child: const Icon(Icons.check, size: 14, color: AppColors.canvas),
      );
    }
    if (isCurrent) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
        child: const Icon(Icons.play_arrow, size: 14, color: Colors.white),
      );
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderLight, width: 1.5),
      ),
    );
  }

  Widget _buildDeleteSection(BuildContext context, AppProvider provider, Roadmap r) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: TextButton.icon(
          onPressed: () => _confirmDelete(context, provider),
          icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
          label: const Text(
            'Delete this Roadmap',
            style: TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            backgroundColor: AppColors.error.withOpacity(0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: AppColors.error.withOpacity(0.25)),
            ),
          ),
        ),
      ),
    );
  }

  // ── Delete confirmation ────────────────────────────────────────────────────

  void _confirmDelete(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
              'Delete Roadmap',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${widget.roadmap.name}"? All progress, flashcards, and schedule history will be permanently removed.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          FilledButton.icon(
            onPressed: () {
              provider.removeRoadmap(widget.roadmap.id);
              Navigator.pop(context);
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
