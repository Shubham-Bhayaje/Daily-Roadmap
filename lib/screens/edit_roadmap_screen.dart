import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/roadmap.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class EditRoadmapScreen extends StatefulWidget {
  /// Pass a roadmap to edit it; leave null to create a new one.
  final Roadmap? roadmap;

  const EditRoadmapScreen({super.key, this.roadmap});

  @override
  State<EditRoadmapScreen> createState() => _EditRoadmapScreenState();
}

class _EditRoadmapScreenState extends State<EditRoadmapScreen> {
  final _nameController = TextEditingController();
  final _topicController = TextEditingController();
  final _topics = <RoadmapTopic>[];
  bool _isSaving = false;

  bool get isEditing => widget.roadmap != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _nameController.text = widget.roadmap!.name;
      // Deep‑copy existing topics to preserve completion state
      _topics.addAll(widget.roadmap!.topics.map((t) => RoadmapTopic(
            id: t.id,
            name: t.name,
            isCompleted: t.isCompleted,
            completedAt: t.completedAt,
            assignedDate: t.assignedDate,
          )));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Roadmap' : 'Create Roadmap',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 22),
              tooltip: 'Delete Roadmap',
              onPressed: _confirmDeleteRoadmap,
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.canvas,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.canvas,
                      ),
                    )
                  : Text(
                      isEditing ? 'Save' : 'Create',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNameField(),
                  const SizedBox(height: 28),
                  _buildTopicsHeader(),
                  const SizedBox(height: 12),
                  _buildTopicsList(),
                  const SizedBox(height: 16),
                  _buildAddTopicRow(),
                  const SizedBox(height: 12),
                  _buildBulkAddButton(),
                  if (isEditing) ...[
                    const SizedBox(height: 32),
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 24),
                    Center(
                      child: TextButton.icon(
                        onPressed: _confirmDeleteRoadmap,
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
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ── Name field ─────────────────────────────────────────────────────────────

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ROADMAP NAME',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _nameController,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: 'e.g. System Design, DSA, My Python Plan',
            prefixIcon: const Icon(Icons.edit_outlined, color: AppColors.textMuted, size: 20),
          ),
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  // ── Topics header ──────────────────────────────────────────────────────────

  Widget _buildTopicsHeader() {
    final completed = _topics.where((t) => t.isCompleted).length;
    return Row(
      children: [
        const Text(
          'TOPICS',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${_topics.length}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (isEditing && completed > 0) ...[
          const SizedBox(width: 8),
          Icon(Icons.check_circle, color: AppColors.accent, size: 14),
          const SizedBox(width: 4),
          Text(
            '$completed done',
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const Spacer(),
        if (_topics.length >= 2) ...[
          // Sort 1 -> N button
          InkWell(
            onTap: _sortTopicsAscending,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.format_list_numbered, size: 14, color: AppColors.accent),
                  SizedBox(width: 4),
                  Text(
                    '1 → N',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Flip / Reverse button
          InkWell(
            onTap: _reverseTopics,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_vert, size: 14, color: AppColors.textSecondary),
                  SizedBox(width: 4),
                  Text(
                    'Flip',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _sortTopicsAscending() {
    final numRegex = RegExp(r'^\s*(\d+)[\.\s\)\-]');
    setState(() {
      _topics.sort((a, b) {
        final matchA = numRegex.firstMatch(a.name);
        final matchB = numRegex.firstMatch(b.name);
        if (matchA != null && matchB != null) {
          final numA = int.tryParse(matchA.group(1)!) ?? 0;
          final numB = int.tryParse(matchB.group(1)!) ?? 0;
          return numA.compareTo(numB);
        }
        return a.name.compareTo(b.name);
      });
    });
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Topics sorted 1 → N numerically! 🔢'),
        backgroundColor: AppColors.surface2,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _reverseTopics() {
    setState(() {
      final reversed = _topics.reversed.toList();
      _topics.clear();
      _topics.addAll(reversed);
    });
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Topic list order flipped! ⇄'),
        backgroundColor: AppColors.surface2,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Topics list (reorderable) ──────────────────────────────────────────────

  Widget _buildTopicsList() {
    if (_topics.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(Icons.playlist_add, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              'No topics yet',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add topics below or use bulk add',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: _topics.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex--;
            final item = _topics.removeAt(oldIndex);
            _topics.insert(newIndex, item);
          });
          HapticFeedback.lightImpact();
        },
        proxyDecorator: (child, index, animation) {
          return Material(
            color: AppColors.surface2,
            elevation: 4,
            shadowColor: Colors.black54,
            borderRadius: BorderRadius.circular(12),
            child: child,
          );
        },
        itemBuilder: (context, index) {
          final topic = _topics[index];
          return _buildTopicTile(topic, index);
        },
      ),
    );
  }

  Widget _buildTopicTile(RoadmapTopic topic, int index) {
    return Container(
      key: ValueKey(topic.id),
      decoration: BoxDecoration(
        border: index < _topics.length - 1
            ? const Border(bottom: BorderSide(color: AppColors.border))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            // Drag handle
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.drag_handle, color: AppColors.textMuted, size: 20),
              ),
            ),
            // Number
            SizedBox(
              width: 26,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // Completion indicator (edit mode only)
            if (topic.isCompleted)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent,
                  ),
                  child: const Icon(Icons.check, size: 12, color: AppColors.canvas),
                ),
              ),
            // Topic name
            Expanded(
              child: Text(
                AppColors.fixTopicName(topic.name),
                style: TextStyle(
                  color: topic.isCompleted
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Delete button
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: AppColors.textMuted,
              onPressed: () {
                HapticFeedback.lightImpact();
                setState(() => _topics.removeAt(index));
              },
              tooltip: 'Remove topic',
            ),
          ],
        ),
      ),
    );
  }

  // ── Add topic row ──────────────────────────────────────────────────────────

  Widget _buildAddTopicRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _topicController,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Add a topic...',
              prefixIcon: const Icon(Icons.add, color: AppColors.textMuted, size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _addSingleTopic(),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: _addSingleTopic,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.surface2,
              foregroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  void _addSingleTopic() {
    final name = _topicController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _topics.add(RoadmapTopic(
        id: 'custom-${DateTime.now().millisecondsSinceEpoch}-${_topics.length}',
        name: name,
      ));
    });
    _topicController.clear();
    HapticFeedback.lightImpact();
  }

  // ── Bulk add ───────────────────────────────────────────────────────────────

  Widget _buildBulkAddButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _showBulkAddDialog,
        icon: const Icon(Icons.content_paste, size: 18),
        label: const Text(
          'Bulk Add Topics',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  void _showBulkAddDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Bulk Add Topics',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter one topic per line:',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 10,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Variables\nData Types\nFunctions\nLoops\n...',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  filled: true,
                  fillColor: AppColors.surface2,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          FilledButton(
            onPressed: () {
              final rawLines = controller.text
                  .split('\n')
                  .map((l) => l.trim())
                  .where((l) => l.isNotEmpty)
                  .toList();
              if (rawLines.isNotEmpty) {
                var lines = List<String>.from(rawLines);
                bool wasFlipped = false;

                // Auto-reverse if lines are numbered in descending order (e.g. 135 down to 1)
                if (lines.length >= 2) {
                  final numRegex = RegExp(r'^\s*(\d+)[\.\s\)\-]');
                  final firstMatch = numRegex.firstMatch(lines.first);
                  final lastMatch = numRegex.firstMatch(lines.last);
                  if (firstMatch != null && lastMatch != null) {
                    final firstNum = int.tryParse(firstMatch.group(1)!);
                    final lastNum = int.tryParse(lastMatch.group(1)!);
                    if (firstNum != null && lastNum != null && firstNum > lastNum) {
                      lines = lines.reversed.toList();
                      wasFlipped = true;
                    }
                  }
                }

                setState(() {
                  for (int i = 0; i < lines.length; i++) {
                    _topics.add(RoadmapTopic(
                      id: 'custom-${DateTime.now().millisecondsSinceEpoch}-${_topics.length}-$i',
                      name: lines[i],
                    ));
                  }
                });
                HapticFeedback.mediumImpact();

                if (wasFlipped && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Auto-organized ${lines.length} topics from 1 → ${lines.length} roadmap order! 🎯'),
                      backgroundColor: AppColors.surface2,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.canvas,
            ),
            child: const Text('Add All', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Bottom bar ─────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.surface1,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: Icon(isEditing ? Icons.save : Icons.rocket_launch, size: 20),
            label: Text(
              isEditing ? 'Save Changes' : 'Create Roadmap',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.canvas,
              disabledBackgroundColor: AppColors.surface3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Save / Create ──────────────────────────────────────────────────────────

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Please enter a roadmap name');
      return;
    }
    if (_topics.isEmpty) {
      _showError('Add at least one topic');
      return;
    }

    setState(() => _isSaving = true);
    final provider = context.read<AppProvider>();

    try {
      if (isEditing) {
        await provider.updateRoadmap(widget.roadmap!.id, name, _topics);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.accent, size: 20),
                  const SizedBox(width: 8),
                  Text('Roadmap updated! ✅', style: TextStyle(color: AppColors.textPrimary)),
                ],
              ),
              backgroundColor: AppColors.surface2,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          Navigator.pop(context);
        }
      } else {
        final err = await provider.createCustomRoadmap(name, _topics.map((t) => t.name).toList());
        if (err != null) {
          _showError(err);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.accent, size: 20),
                  const SizedBox(width: 8),
                  Text('Roadmap created! 🎉', style: TextStyle(color: AppColors.textPrimary)),
                ],
              ),
              backgroundColor: AppColors.surface2,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          Navigator.pop(context);
          // Also pop the add screen if it's in the back stack
          if (Navigator.canPop(context)) Navigator.pop(context);
        }
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _confirmDeleteRoadmap() {
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
          'Are you sure you want to delete "${widget.roadmap!.name}"? All progress and cards will be permanently removed.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          FilledButton.icon(
            onPressed: () {
              final provider = context.read<AppProvider>();
              provider.removeRoadmap(widget.roadmap!.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
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

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(msg, style: const TextStyle(color: AppColors.textPrimary)),
            ),
          ],
        ),
        backgroundColor: AppColors.surface2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
