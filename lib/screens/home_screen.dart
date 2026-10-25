import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../models/daily_practice.dart';
import '../models/roadmap.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import 'add_roadmap_screen.dart';
import 'roadmap_detail_screen.dart';
import 'anki_study_screen.dart';
import 'edit_roadmap_screen.dart';
import '../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Set<String> _expandedPracticeIds = {};

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.canvas,
          body: SafeArea(
            child: provider.hasRoadmaps
                ? _buildDashboard(context, provider)
                : EmptyState(onAddRoadmap: () => _goToAdd(context)),
          ),
          floatingActionButton: provider.hasRoadmaps
              ? FloatingActionButton(
                  onPressed: () => _goToAdd(context),
                  child: const Icon(Icons.add, size: 26),
                )
              : null,
        );
      },
    );
  }

  // ── Dashboard ──────────────────────────────────────────────────────────────

  Widget _buildDashboard(BuildContext context, AppProvider p) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(child: _header(context, p)),
        SliverToBoxAdapter(child: const SizedBox(height: 20)),
        SliverToBoxAdapter(child: _statsRow(context, p)),
        SliverToBoxAdapter(child: const SizedBox(height: 24)),
        SliverToBoxAdapter(child: _weeklyCalendar(context, p)),
        SliverToBoxAdapter(child: const SizedBox(height: 28)),
        SliverToBoxAdapter(child: _sectionTitle(context, "TODAY'S PRACTICE", '${p.todayDoneCount}/${p.todaysPractice.length} done')),
        SliverToBoxAdapter(child: _todaysProgressBar(context, p)),
        SliverToBoxAdapter(child: const SizedBox(height: 12)),
        _practiceList(context, p),
        SliverToBoxAdapter(child: const SizedBox(height: 28)),
        SliverToBoxAdapter(child: _sectionTitle(context, 'YOUR ROADMAPS', '${p.roadmaps.length} active')),
        SliverToBoxAdapter(child: const SizedBox(height: 8)),
        SliverToBoxAdapter(child: _roadmapsList(context, p)),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _header(BuildContext context, AppProvider p) {
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMM d').format(now);
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: App Identity (Left) & Actions (Right)
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(right: 10),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const Expanded(
                child: Text(
                  'Daily Roadmap',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _reminderButton(context, p),
              const SizedBox(width: 8),
              _streakBadge(p.currentStreak),
            ],
          ),
          const SizedBox(height: 8),
          // Row 2: Greeting (Left) & Date (Right)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                greeting,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                dateStr,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reminderButton(BuildContext context, AppProvider p) {
    final enabled = p.notificationsEnabled && p.activeReminderCount > 0;
    final count = p.activeReminderCount;
    final text = enabled ? '$count alerts' : 'Off';

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        HapticFeedback.lightImpact();
        _showReminderSheet(context, p);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.accent.withOpacity(0.12)
              : AppColors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled
                ? AppColors.accent.withOpacity(0.28)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              enabled
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_outlined,
              size: 16,
              color: enabled ? AppColors.accent : AppColors.textMuted,
            ),
            const SizedBox(width: 5),
            Text(
              text,
              style: TextStyle(
                color: enabled ? AppColors.accent : AppColors.textMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _streakBadge(int streak) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: streak > 0
            ? const Color(0xFFFF6B2C).withOpacity(0.15)
            : AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: streak > 0
              ? const Color(0xFFFF6B2C).withOpacity(0.3)
              : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '🔥',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: TextStyle(
              color: streak > 0 ? const Color(0xFFFF6B2C) : AppColors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats row ──────────────────────────────────────────────────────────────

  Widget _statsRow(BuildContext context, AppProvider p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _statCard('Completed', '${p.totalCompleted}', Icons.check_circle_outline, AppColors.success),
          const SizedBox(width: 10),
          _statCard('Tracking', '${p.roadmaps.length}', Icons.auto_stories_outlined, AppColors.info),
          const SizedBox(width: 10),
          _statCard('Topics', '${p.totalTopics}', Icons.layers_outlined, AppColors.warning),
          const SizedBox(width: 10),
          _statCard('Streak', '${p.currentStreak}d', Icons.local_fire_department_outlined, const Color(0xFFFF6B2C)),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Weekly calendar ────────────────────────────────────────────────────────

  Widget _weeklyCalendar(BuildContext context, AppProvider p) {
    final labels = p.weeklyLabels;
    final completions = p.weeklyCompletions;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(7, (i) {
            final isToday = i == 6;
            final isDone = completions[i];
            return Column(
              children: [
                Text(
                  labels[i],
                  style: TextStyle(
                    color: isToday ? AppColors.textPrimary : AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? AppColors.accent
                        : isToday
                            ? AppColors.accent.withOpacity(0.15)
                            : AppColors.surface2,
                    border: isToday && !isDone
                        ? Border.all(color: AppColors.accent, width: 1.5)
                        : null,
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check, size: 16, color: AppColors.canvas)
                        : isToday
                            ? Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.accent,
                                ),
                              )
                            : Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.textMuted.withOpacity(0.3),
                                ),
                              ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // ── Section title ──────────────────────────────────────────────────────────

  Widget _sectionTitle(BuildContext context, String title, String trailing) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          Text(
            trailing,
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Today's progress bar ───────────────────────────────────────────────────

  Widget _todaysProgressBar(BuildContext context, AppProvider p) {
    final total = p.todaysPractice.length;
    final done = p.todayDoneCount;
    final pct = total > 0 ? done / total : 0.0;
    final allDone = done == total && total > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: AppColors.surface2,
              valueColor: AlwaysStoppedAnimation(
                allDone ? AppColors.success : AppColors.accent,
              ),
            ),
          ),
          if (allDone) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent.withOpacity(0.2)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🎉', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8),
                  Text(
                    "All done for today!",
                    style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Practice list ──────────────────────────────────────────────────────────

  Widget _practiceList(BuildContext context, AppProvider p) {
    if (p.todaysPractice.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'No practice items yet.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final practice = p.todaysPractice[index];
          return _practiceCard(context, p, practice);
        },
        childCount: p.todaysPractice.length,
      ),
    );
  }

  Widget _practiceCard(BuildContext context, AppProvider p, DailyPractice practice) {
    final color = AppColors.roadmapColor(practice.roadmapId);
    final roadmap = p.roadmaps.firstWhere((r) => r.id == practice.roadmapId);
    final pct = roadmap.progress;
    final isDone = practice.isCompleted;
    final topicName = AppColors.fixTopicName(practice.topicName);
    final isAnki = roadmap.isAnkiDeck;
    final practiceKey = '${practice.roadmapId}_${practice.topicIndex}';
    final isExpanded = _expandedPracticeIds.contains(practiceKey);
    final topic = (practice.topicIndex >= 0 && practice.topicIndex < roadmap.topics.length)
        ? roadmap.topics[practice.topicIndex]
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              if (isExpanded) {
                _expandedPracticeIds.remove(practiceKey);
              } else {
                _expandedPracticeIds.add(practiceKey);
              }
            });
          },
          onLongPress: () async {
            if (roadmap.url.startsWith('http')) {
              final uri = Uri.parse(roadmap.url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RoadmapDetailScreen(roadmap: roadmap),
                ),
              );
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDone
                  ? AppColors.accent.withOpacity(0.06)
                  : AppColors.surface1,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDone
                    ? AppColors.accent.withOpacity(0.25)
                    : (isExpanded ? color.withOpacity(0.4) : AppColors.border),
                width: isExpanded ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // ── Progress ring ──
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: CircularProgressIndicator(
                              value: pct,
                              strokeWidth: 3.5,
                              backgroundColor: AppColors.surface3,
                              valueColor: AlwaysStoppedAnimation(color),
                            ),
                          ),
                          Text(
                            '${(pct * 100).toInt()}%',
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    // ── Text content ──
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (isAnki) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4A9DFF).withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'CARD',
                                    style: TextStyle(
                                      color: Color(0xFF4A9DFF),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                              Expanded(
                                child: Text(
                                  topicName,
                                  style: TextStyle(
                                    color: isDone
                                        ? AppColors.textSecondary
                                        : AppColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    decoration: isDone ? TextDecoration.lineThrough : null,
                                    decorationColor: AppColors.textMuted,
                                  ),
                                  maxLines: isExpanded ? 3 : 1,
                                  overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${AppColors.fixTopicName(roadmap.name)}  •  ${roadmap.completedCount}/${roadmap.totalCount}',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // ── Action / completion buttons ──
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        if (isDone) {
                          p.uncompleteTopic(practice.roadmapId, practice.topicIndex);
                        } else {
                          p.completeTopic(practice.roadmapId, practice.topicIndex);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDone ? AppColors.accent : Colors.transparent,
                          border: Border.all(
                            color: isDone ? AppColors.accent : AppColors.borderLight,
                            width: 2,
                          ),
                        ),
                        child: isDone
                            ? const Icon(Icons.check, size: 18, color: AppColors.canvas)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ],
                ),

                // ── Expanded Info Section ──
                if (isExpanded) ...[
                  const SizedBox(height: 14),
                  Container(
                    height: 1,
                    color: AppColors.border,
                  ),
                  const SizedBox(height: 14),

                  // Full point title (multiline)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SelectableText(
                          topicName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ),
                      if (isDone)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check, size: 12, color: AppColors.accent),
                              SizedBox(width: 4),
                              Text(
                                'DONE',
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Detailed concept / explanation / answer
                  if (topic != null && topic.answer != null && topic.answer!.trim().isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lightbulb_outline_rounded, size: 15, color: color),
                              const SizedBox(width: 6),
                              Text(
                                'CONCEPT & EXPLANATION',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            topic.answer!.trim(),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13.5,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: color),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Focus checkpoint for today in the ${roadmap.name} track. Complete this exercise to build your daily streak.',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12.5,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Action buttons bar
                  Row(
                    children: [
                      // Toggle Done / Undo button
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            if (isDone) {
                              p.uncompleteTopic(practice.roadmapId, practice.topicIndex);
                            } else {
                              p.completeTopic(practice.roadmapId, practice.topicIndex);
                            }
                          },
                          icon: Icon(
                            isDone ? Icons.undo_rounded : Icons.check_circle_rounded,
                            size: 16,
                          ),
                          label: Text(
                            isDone ? 'Mark Incomplete' : 'Mark as Done',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: isDone ? AppColors.surface3 : AppColors.accent,
                            foregroundColor: isDone ? AppColors.textPrimary : AppColors.canvas,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Study or Web button
                      if (isAnki)
                        FilledButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => AnkiStudyScreen(roadmap: roadmap)),
                            );
                          },
                          icon: const Icon(Icons.style_outlined, size: 15),
                          label: const Text('Study Card', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF4A9DFF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        )
                      else if (roadmap.url.startsWith('http'))
                        OutlinedButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse(roadmap.url);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: const Icon(Icons.open_in_new, size: 14),
                          label: const Text('roadmap.sh', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),

                      const SizedBox(width: 6),

                      // View Roadmap Overview
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => RoadmapDetailScreen(roadmap: roadmap)),
                          );
                        },
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        tooltip: 'View Roadmap',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surface2,
                          foregroundColor: AppColors.textSecondary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
  }

  // ── Roadmaps list ──────────────────────────────────────────────────────────

  Widget _roadmapsList(BuildContext context, AppProvider p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            for (int i = 0; i < p.roadmaps.length; i++) ...[
              _roadmapRow(context, p, p.roadmaps[i]),
              if (i < p.roadmaps.length - 1)
                const Divider(color: AppColors.border, height: 1, indent: 60),
            ],
          ],
        ),
      ),
    );
  }

  Widget _roadmapRow(BuildContext context, AppProvider p, Roadmap roadmap) {
    final color = AppColors.roadmapColor(roadmap.id);
    final pct = roadmap.progress;
    final isAnki = roadmap.isAnkiDeck;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RoadmapDetailScreen(roadmap: roadmap),
          ),
        );
      },
      onLongPress: () {
        HapticFeedback.heavyImpact();
        _confirmDeleteRoadmap(context, p, roadmap);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Colored initial circle or Anki icon
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: (isAnki ? const Color(0xFF4A9DFF) : color).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isAnki
                    ? const Icon(Icons.style, color: Color(0xFF4A9DFF), size: 20)
                    : Text(
                        roadmap.name.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Name + progress bar
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isAnki) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A9DFF).withOpacity(0.18),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'ANKI',
                            style: TextStyle(
                              color: Color(0xFF4A9DFF),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          AppColors.fixTopicName(roadmap.name),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 4,
                      backgroundColor: AppColors.surface3,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Percentage or due count
            if (isAnki && roadmap.totalDueCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${roadmap.totalDueCount} due',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            else
              Text(
                '${(pct * 100).toInt()}%',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert,
                color: AppColors.textMuted,
                size: 20,
              ),
              color: AppColors.surface2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              tooltip: 'Roadmap actions',
              onSelected: (val) {
                if (val == 'edit') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditRoadmapScreen(roadmap: roadmap),
                    ),
                  );
                } else if (val == 'delete') {
                  _confirmDeleteRoadmap(context, p, roadmap);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18, color: AppColors.textPrimary),
                      SizedBox(width: 10),
                      Text('Edit Roadmap', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                      SizedBox(width: 10),
                      Text('Delete Roadmap', style: TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Delete confirmation ────────────────────────────────────────────────────

  void _confirmDeleteRoadmap(BuildContext context, AppProvider p, Roadmap roadmap) {
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
          'Are you sure you want to delete "${roadmap.name}"? All progress, flashcards, and schedule history will be permanently removed.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          FilledButton.icon(
            onPressed: () {
              p.removeRoadmap(roadmap.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Removed "${roadmap.name}"'),
                  backgroundColor: AppColors.surface2,
                  behavior: SnackBarBehavior.floating,
                ),
              );
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

  // ── Reminder Settings Sheet ───────────────────────────────────────────────

  void _showReminderSheet(BuildContext context, AppProvider p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isMasterEnabled = p.notificationsEnabled;
            final reminders = p.reminders;
            final activeCount = p.activeReminderCount;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface1,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.borderLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Header Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.alarm_on_rounded,
                          color: AppColors.accent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Practice Reminders',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isMasterEnabled
                                  ? '$activeCount active alert${activeCount == 1 ? '' : 's'} scheduled'
                                  : 'Reminders currently paused',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textMuted),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Master toggle card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isMasterEnabled
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_off_outlined,
                          color: isMasterEnabled ? AppColors.accent : AppColors.textMuted,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Daily Practice Reminders',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Master toggle for all scheduled practice sessions',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isMasterEnabled,
                          activeColor: AppColors.accent,
                          activeTrackColor: AppColors.accent.withOpacity(0.35),
                          inactiveThumbColor: AppColors.textMuted,
                          inactiveTrackColor: AppColors.surface3,
                          onChanged: (val) async {
                            HapticFeedback.lightImpact();
                            if (val) {
                              await p.requestNotificationPermissions();
                            }
                            await p.toggleMasterNotifications(val);
                            setSheetState(() {});
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Scrollable Reminders List + Add Button
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isMasterEnabled) ...[
                            // Section header
                            Row(
                              children: [
                                Text(
                                  'SCHEDULED SESSIONS (${reminders.length})',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const Spacer(),
                                InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => _showAddReminderDialog(context, p, setSheetState),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.add_circle_outline, size: 15, color: AppColors.accent),
                                        SizedBox(width: 4),
                                        Text(
                                          'Add Session',
                                          style: TextStyle(
                                            color: AppColors.accent,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Reminder list cards
                            ...reminders.map((item) {
                              final timeStr = item.formatTime(context);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: item.isEnabled ? AppColors.surface2 : AppColors.surface2.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: item.isEnabled
                                        ? AppColors.border
                                        : AppColors.border.withOpacity(0.5),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Session info + time picker
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.label,
                                                  style: TextStyle(
                                                    color: item.isEnabled ? AppColors.textPrimary : AppColors.textMuted,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.textMuted),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                tooltip: 'Rename session',
                                                onPressed: () => _showEditLabelDialog(context, p, item, setSheetState),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          // Time button
                                          InkWell(
                                            borderRadius: BorderRadius.circular(8),
                                            onTap: () async {
                                              HapticFeedback.selectionClick();
                                              final picked = await showTimePicker(
                                                context: context,
                                                initialTime: TimeOfDay(hour: item.hour, minute: item.minute),
                                                builder: (ctx, child) {
                                                  return Theme(
                                                    data: Theme.of(ctx).copyWith(
                                                      colorScheme: const ColorScheme.dark(
                                                        primary: AppColors.accent,
                                                        onPrimary: AppColors.canvas,
                                                        surface: AppColors.surface1,
                                                        onSurface: AppColors.textPrimary,
                                                      ),
                                                    ),
                                                    child: child!,
                                                  );
                                                },
                                              );
                                              if (picked != null) {
                                                await p.updateReminderTime(item.id, picked.hour, picked.minute);
                                                setSheetState(() {});
                                              }
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: item.isEnabled
                                                    ? AppColors.accent.withOpacity(0.12)
                                                    : AppColors.surface3,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: item.isEnabled
                                                      ? AppColors.accent.withOpacity(0.3)
                                                      : AppColors.border,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.schedule_rounded,
                                                    size: 14,
                                                    color: item.isEnabled ? AppColors.accent : AppColors.textMuted,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    timeStr,
                                                    style: TextStyle(
                                                      color: item.isEnabled ? AppColors.accent : AppColors.textMuted,
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Icon(
                                                    Icons.expand_more_rounded,
                                                    size: 14,
                                                    color: item.isEnabled ? AppColors.accent : AppColors.textMuted,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Switch
                                    Switch(
                                      value: item.isEnabled,
                                      activeColor: AppColors.accent,
                                      activeTrackColor: AppColors.accent.withOpacity(0.35),
                                      inactiveThumbColor: AppColors.textMuted,
                                      inactiveTrackColor: AppColors.surface3,
                                      onChanged: (val) async {
                                        HapticFeedback.lightImpact();
                                        await p.toggleReminder(item.id, val);
                                        setSheetState(() {});
                                      },
                                    ),
                                    if (reminders.length > 1) ...[
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.textMuted),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        tooltip: 'Delete alert',
                                        onPressed: () async {
                                          HapticFeedback.lightImpact();
                                          await p.deleteReminder(item.id);
                                          setSheetState(() {});
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }),

                            // Add session button card
                            InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _showAddReminderDialog(context, p, setSheetState),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.surface1,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppColors.accent.withOpacity(0.35),
                                    style: BorderStyle.solid,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_alarm_rounded, size: 18, color: AppColors.accent),
                                    SizedBox(width: 8),
                                    Text(
                                      'Add Another Practice Time',
                                      style: TextStyle(
                                        color: AppColors.accent,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 14),

                          // Notification preview
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.canvas,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 18,
                                      height: 18,
                                      decoration: const BoxDecoration(shape: BoxShape.circle),
                                      clipBehavior: Clip.antiAlias,
                                      child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Daily Roadmap',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text('•', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                    const SizedBox(width: 6),
                                    Text(
                                      isMasterEnabled ? '$activeCount active alerts' : 'Off',
                                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Daily Practice Time 🎯',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  p.todaysPractice.isNotEmpty
                                      ? 'Today\'s focus: ${p.todaysPractice.first.roadmapName}: ${AppColors.fixTopicName(p.todaysPractice.first.topicName)}'
                                      : 'Time for your daily roadmap checkpoint! 🔥 Keep your streak alive!',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    height: 1.35,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    children: [
                      // Test notification button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            HapticFeedback.mediumImpact();
                            await p.sendTestNotification();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.check_circle, color: AppColors.accent, size: 18),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Test alert triggered! Pull down status bar or check notification tray 🔔',
                                          style: TextStyle(fontSize: 12.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: AppColors.surface2,
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 4),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.send_rounded, size: 15),
                          label: const Text(
                            'Test Alert',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.accent,
                            side: const BorderSide(color: AppColors.accent),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Done button
                      FilledButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.surface3,
                          foregroundColor: AppColors.textPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddReminderDialog(BuildContext context, AppProvider p, StateSetter setSheetState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (addContext) {
        final presets = [
          {'label': 'Morning Practice 🌅', 'hour': 9, 'minute': 0, 'time': '09:00 AM'},
          {'label': 'Midday Sprint 🥪', 'hour': 13, 'minute': 0, 'time': '01:00 PM'},
          {'label': 'Afternoon Focus ☀️', 'hour': 16, 'minute': 0, 'time': '04:00 PM'},
          {'label': 'Evening Review 🌙', 'hour': 20, 'minute': 0, 'time': '08:00 PM'},
          {'label': 'Night Owl Session 🦉', 'hour': 22, 'minute': 30, 'time': '10:30 PM'},
        ];

        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(context).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Add Practice Reminder',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose a quick preset or customize your own time',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              // Presets list
              ...presets.map((preset) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      Navigator.pop(addContext);
                      await p.addReminder(
                        label: preset['label'] as String,
                        hour: preset['hour'] as int,
                        minute: preset['minute'] as int,
                      );
                      setSheetState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              preset['label'] as String,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              preset['time'] as String,
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.add_rounded, color: AppColors.accent, size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 6),
              // Custom time button
              OutlinedButton.icon(
                onPressed: () async {
                  HapticFeedback.selectionClick();
                  Navigator.pop(addContext);
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 12, minute: 0),
                    builder: (ctx, child) {
                      return Theme(
                        data: Theme.of(ctx).copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: AppColors.accent,
                            onPrimary: AppColors.canvas,
                            surface: AppColors.surface1,
                            onSurface: AppColors.textPrimary,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    await p.addReminder(
                      label: 'Custom Practice 🎯',
                      hour: picked.hour,
                      minute: picked.minute,
                    );
                    setSheetState(() {});
                  }
                },
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text('Pick Custom Time...'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.borderLight),
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditLabelDialog(BuildContext context, AppProvider p, ReminderItem item, StateSetter setSheetState) {
    final controller = TextEditingController(text: item.label);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Edit Session Name', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'e.g. Morning Practice 🌅',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surface2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await p.updateReminderLabel(item.id, newName);
                setSheetState(() {});
              }
              if (dialogCtx.mounted) {
                Navigator.pop(dialogCtx);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.canvas),
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _goToAdd(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddRoadmapScreen()),
    );
  }
}
