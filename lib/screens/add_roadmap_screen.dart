import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'edit_roadmap_screen.dart';

class AddRoadmapScreen extends StatefulWidget {
  const AddRoadmapScreen({super.key});

  @override
  State<AddRoadmapScreen> createState() => _AddRoadmapScreenState();
}

class _AddRoadmapScreenState extends State<AddRoadmapScreen> {
  final _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPickingFile = false;

  static const _quickPicks = <Map<String, String>>[
    {'name': 'Frontend',    'icon': '🌐', 'url': 'https://roadmap.sh/frontend'},
    {'name': 'Backend',     'icon': '⚙️', 'url': 'https://roadmap.sh/backend'},
    {'name': 'DevOps',      'icon': '🔄', 'url': 'https://roadmap.sh/devops'},
    {'name': 'React',       'icon': '⚛️', 'url': 'https://roadmap.sh/react'},
    {'name': 'Python',      'icon': '🐍', 'url': 'https://roadmap.sh/python'},
    {'name': 'JavaScript',  'icon': '📜', 'url': 'https://roadmap.sh/javascript'},
    {'name': 'SQL',         'icon': '🗄️', 'url': 'https://roadmap.sh/sql'},
    {'name': 'Docker',      'icon': '🐳', 'url': 'https://roadmap.sh/docker'},
    {'name': 'Kubernetes',  'icon': '☸️', 'url': 'https://roadmap.sh/kubernetes'},
    {'name': 'Flutter',     'icon': '💙', 'url': 'https://roadmap.sh/flutter'},
    {'name': 'AI Engineer', 'icon': '🤖', 'url': 'https://roadmap.sh/ai-engineer'},
    {'name': 'TypeScript',  'icon': '🔷', 'url': 'https://roadmap.sh/typescript'},
    {'name': 'Java',        'icon': '☕', 'url': 'https://roadmap.sh/java'},
    {'name': 'Node.js',     'icon': '🟢', 'url': 'https://roadmap.sh/nodejs'},
    {'name': 'Go',          'icon': '🐹', 'url': 'https://roadmap.sh/golang'},
    {'name': 'Rust',        'icon': '🦀', 'url': 'https://roadmap.sh/rust'},
    {'name': 'AWS',         'icon': '☁️', 'url': 'https://roadmap.sh/aws'},
    {'name': 'Angular',     'icon': '🅰️', 'url': 'https://roadmap.sh/angular'},
  ];

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text(
          'Add Roadmap',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. IMPORT ANKI & CSV CARD ───────────────────────────────
                _buildDeckAndCsvImportCard(context, provider),

                const SizedBox(height: 24),

                // ── 2. CREATE MANUALLY CARD ──────────────────────────────────
                _buildManualCreateCard(context),

                const SizedBox(height: 28),
                Divider(color: AppColors.border),
                const SizedBox(height: 24),

                // ── 3. ROADMAP.SH URL INPUT ──────────────────────────────────
                Text(
                  'PASTE ROADMAP.SH URL',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _urlController,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'https://roadmap.sh/sql',
                      prefixIcon: Icon(Icons.link, color: AppColors.textMuted, size: 20),
                    ),
                    keyboardType: TextInputType.url,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter a URL';
                      if (!v.contains('roadmap.sh/')) return 'Must be a roadmap.sh URL';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 14),

                // Error banner
                if (provider.error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            provider.error!,
                            style: const TextStyle(color: AppColors.error, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // URL Submit button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: provider.isLoading ? null : () => _submit(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.canvas,
                      disabledBackgroundColor: AppColors.surface3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: provider.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.canvas,
                            ),
                          )
                        : const Text(
                            'Add from roadmap.sh',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 32),
                Divider(color: AppColors.border),
                const SizedBox(height: 24),

                // ── 4. QUICK PICKS ───────────────────────────────────────────
                Text(
                  'POPULAR ROADMAPS',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tap to add any tech track instantly',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),

                // Grid of quick picks
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 3.0,
                  children: _quickPicks.map((rm) {
                    final isAdded = provider.roadmaps
                        .any((r) => r.url == rm['url']);
                    return _quickPickTile(context, rm, isAdded, provider);
                  }).toList(),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Anki & CSV Import Card ──────────────────────────────────────────────────

  Widget _buildDeckAndCsvImportCard(BuildContext context, AppProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF4A9DFF).withOpacity(0.35), width: 1.2),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A9DFF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.style_outlined, color: Color(0xFF4A9DFF), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Import Deck / CSV',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A9DFF).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '.apkg',
                            style: TextStyle(color: Color(0xFF4A9DFF), fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E599).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '.csv',
                            style: TextStyle(color: Color(0xFF00E599), fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'AnkiDroid presentation & SM-2 Spaced Repetition',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Import your .apkg deck or .csv/.tsv spreadsheet to study flashcards with Spaced Repetition and simple Learn & Done buttons.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 16),
          // Pick file button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: _isPickingFile || provider.isLoading
                  ? null
                  : () => _pickImportFile(context, provider),
              icon: _isPickingFile
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.canvas),
                    )
                  : const Icon(Icons.file_upload_outlined, size: 18),
              label: Text(
                _isPickingFile ? 'Selecting File...' : 'Choose .apkg / .csv File from Device',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4A9DFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Instant sample deck tester
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Demo decks: ',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500),
              ),
              _sampleChip(context, provider, 'Docker (135 cards)', 'docker', isAnki: true),
              _sampleChip(context, provider, 'System Design (CSV)', 'system-design-csv', isCsv: true),
              _sampleChip(context, provider, 'Python', 'python', isAnki: true),
              _sampleChip(context, provider, 'SQL', 'sql', isAnki: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sampleChip(BuildContext context, AppProvider provider, String label, String key, {bool isAnki = false, bool isCsv = false}) {
    final chipColor = isCsv ? const Color(0xFF00E599) : const Color(0xFF4A9DFF);
    return InkWell(
      onTap: provider.isLoading ? null : () => _loadSampleDeck(context, provider, key),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: chipColor.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCsv) ...[
              Icon(Icons.table_chart_outlined, size: 12, color: chipColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(color: chipColor, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadSampleDeck(BuildContext context, AppProvider provider, String key) async {
    final err = await provider.importSampleDeck(key);
    if (err != null) {
      if (mounted) _showToast(context, err, isError: true);
    } else if (mounted) {
      final isCsv = key.contains('csv');
      _showToast(context, isCsv ? 'CSV Deck loaded! Enjoy flashcard study 🎉' : 'Anki Deck loaded! Enjoy AnkiDroid study mode 🎉');
      Navigator.pop(context);
    }
  }

  Future<void> _pickImportFile(BuildContext context, AppProvider provider) async {
    setState(() => _isPickingFile = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['apkg', 'zip', 'csv', 'tsv', 'txt'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final name = file.name;
        final ext = (name.split('.').lastOrNull ?? '').toLowerCase();
        final defaultName = name.replaceAll(RegExp(r'\.(apkg|zip|csv|tsv|txt)$', caseSensitive: false), '');
        final isCsv = ext == 'csv' || ext == 'tsv' || ext == 'txt';

        String? err;
        if (isCsv) {
          if (file.bytes != null) {
            err = await provider.importCsvBytes(file.bytes!, defaultName: defaultName);
          } else if (file.path != null) {
            err = await provider.importCsvFile(file.path!, defaultName: defaultName);
          }
        } else {
          if (file.bytes != null) {
            err = await provider.importApkgBytes(file.bytes!, defaultName: defaultName);
          } else if (file.path != null) {
            err = await provider.importApkgFile(file.path!, defaultName: defaultName);
          }
        }

        if (err != null && mounted) {
          _showToast(context, err, isError: true);
        } else if (mounted) {
          _showToast(context, isCsv ? 'CSV Roadmap imported successfully! 🚀' : 'Anki deck imported successfully! 🎉');
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) _showToast(context, 'Failed to read file: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isPickingFile = false);
    }
  }

  // ── Manual Create Card ─────────────────────────────────────────────────────

  Widget _buildManualCreateCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 1.2),
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withOpacity(0.06),
            AppColors.surface1,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.edit_note, color: AppColors.accent, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Build Your Own Roadmap',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Add custom topics, reorder, or bulk paste',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditRoadmapScreen()),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.canvas,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Create', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ── Quick Pick Tile ────────────────────────────────────────────────────────

  Widget _quickPickTile(
    BuildContext context,
    Map<String, String> rm,
    bool isAdded,
    AppProvider provider,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isAdded || provider.isLoading
            ? null
            : () {
                _urlController.text = rm['url']!;
                _submit(context);
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isAdded
                ? AppColors.accent.withOpacity(0.08)
                : AppColors.surface1,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isAdded
                  ? AppColors.accent.withOpacity(0.25)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Text(rm['icon']!, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  rm['name']!,
                  style: TextStyle(
                    color: isAdded ? AppColors.accent : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isAdded)
                const Icon(Icons.check_circle, color: AppColors.accent, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final url = _urlController.text.trim();
    if (url.isEmpty && !_formKey.currentState!.validate()) return;

    final provider = context.read<AppProvider>();
    provider.clearError();
    await provider.addRoadmap(url.isNotEmpty ? url : _urlController.text.trim());

    if (provider.error == null && mounted) {
      _showToast(context, 'Roadmap added! 🎉');
      Navigator.pop(context);
    }
  }

  void _showToast(BuildContext context, String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: isError ? AppColors.error : AppColors.accent,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: const TextStyle(color: AppColors.textPrimary))),
          ],
        ),
        backgroundColor: AppColors.surface2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
