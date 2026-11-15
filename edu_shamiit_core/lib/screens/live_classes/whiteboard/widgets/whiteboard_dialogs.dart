import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../config/app_config.dart';
import '../models/whiteboard_models.dart';
import '../providers/whiteboard_provider.dart';

class RichTextEditorDialog extends StatefulWidget {
  final String initialText;
  final bool isStickyNote;
  final double initialFontSize;
  final bool initialBold;
  final bool initialItalic;
  final bool initialUnderline;
  final Color initialColor;
  final Color? initialBgColor;

  const RichTextEditorDialog({
    super.key,
    this.initialText = '',
    this.isStickyNote = false,
    this.initialFontSize = 18.0,
    this.initialBold = false,
    this.initialItalic = false,
    this.initialUnderline = false,
    this.initialColor = const Color(0xFF0F172A),
    this.initialBgColor,
  });

  @override
  State<RichTextEditorDialog> createState() => _RichTextEditorDialogState();
}

class _RichTextEditorDialogState extends State<RichTextEditorDialog> {
  late TextEditingController _ctrl;
  late double _fontSize;
  late bool _bold;
  late bool _italic;
  late bool _underline;
  late Color _textColor;
  Color? _bgColor;
  String _align = 'left';

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
    _fontSize = widget.initialFontSize;
    _bold = widget.initialBold;
    _italic = widget.initialItalic;
    _underline = widget.initialUnderline;
    _textColor = widget.initialColor;
    _bgColor = widget.initialBgColor ?? (widget.isStickyNote ? const Color(0xFFFEF3C7) : null);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.isStickyNote ? 'Edit Sticky Note' : 'Rich Text Annotation',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (!widget.isStickyNote) ...[
                  _fmtBtn(Icons.format_bold, _bold, () => setState(() => _bold = !_bold)),
                  _fmtBtn(Icons.format_italic, _italic, () => setState(() => _italic = !_italic)),
                  _fmtBtn(Icons.format_underline, _underline, () => setState(() => _underline = !_underline)),
                  _fmtBtn(Icons.format_align_left, _align == 'left', () => setState(() => _align = 'left')),
                  _fmtBtn(Icons.format_align_center, _align == 'center', () => setState(() => _align = 'center')),
                  _fmtBtn(Icons.format_align_right, _align == 'right', () => setState(() => _align = 'right')),
                ],
                DropdownButton<double>(
                  value: _fontSize,
                  isDense: true,
                  items: [14.0, 16.0, 18.0, 22.0, 28.0, 34.0]
                      .map((s) => DropdownMenuItem(value: s, child: Text('${s.toInt()}pt', style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _fontSize = v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Color:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                for (final c in [
                  const Color(0xFF0F172A),
                  const Color(0xFF1D4ED8),
                  const Color(0xFFDC2626),
                  const Color(0xFF16A34A),
                  const Color(0xFF7C3AED),
                ])
                  GestureDetector(
                    onTap: () => setState(() => _textColor = c),
                    child: Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(color: _textColor == c ? Colors.amber : Colors.transparent, width: 2),
                      ),
                    ),
                  ),
                const Spacer(),
                if (widget.isStickyNote) ...[
                  const Text('Note:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  for (final bg in [
                    const Color(0xFFFEF3C7),
                    const Color(0xFFDBEAFE),
                    const Color(0xFFDCFCE7),
                    const Color(0xFFFCE7F3),
                  ])
                    GestureDetector(
                      onTap: () => setState(() => _bgColor = bg),
                      child: Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.only(left: 4),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _bgColor == bg ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1)),
                        ),
                      ),
                    ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              maxLines: 5,
              autofocus: true,
              style: TextStyle(
                fontSize: 15,
                color: _textColor,
                fontWeight: _bold ? FontWeight.bold : FontWeight.normal,
                fontStyle: _italic ? FontStyle.italic : FontStyle.normal,
                decoration: _underline ? TextDecoration.underline : TextDecoration.none,
              ),
              decoration: InputDecoration(
                hintText: widget.isStickyNote ? 'Enter sticky note content...' : 'Enter board text...',
                filled: _bgColor != null,
                fillColor: _bgColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
          onPressed: () {
            final t = _ctrl.text.trim();
            if (t.isEmpty) return;
            Navigator.pop(context, {
              'text': t,
              'fontSize': _fontSize,
              'bold': _bold,
              'italic': _italic,
              'underline': _underline,
              'align': _align,
              'color': WhiteboardColorHelper.toHex(_textColor),
              if (_bgColor != null) 'bgColor': WhiteboardColorHelper.toHex(_bgColor!),
            });
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _fmtBtn(IconData icon, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
        ),
        child: Icon(icon, size: 16, color: active ? const Color(0xFF2563EB) : const Color(0xFF475569)),
      ),
    );
  }
}

class WhiteboardTemplatesDialog extends ConsumerStatefulWidget {
  const WhiteboardTemplatesDialog({super.key});

  @override
  ConsumerState<WhiteboardTemplatesDialog> createState() => _WhiteboardTemplatesDialogState();
}

class _WhiteboardTemplatesDialogState extends ConsumerState<WhiteboardTemplatesDialog> {
  final TextEditingController _titleCtrl = TextEditingController(text: 'New Interactive Whiteboard');
  String _selectedTemplate = 'blank';
  bool _collabEnabled = true;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(whiteboardProvider);
    final templates = s.templates;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.dashboard_customize_rounded, color: Color(0xFF2563EB)),
          SizedBox(width: 8),
          Text('Create New Board / Select Template', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: 'Whiteboard Title',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable Real-time Student Collaboration', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                value: _collabEnabled,
                onChanged: (v) => setState(() => _collabEnabled = v),
              ),
              const SizedBox(height: 8),
              const Text('Subject & Layout Templates', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: templates.map((t) {
                  final sel = _selectedTemplate == t.id;
                  return InkWell(
                    onTap: () => setState(() => _selectedTemplate = t.id),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 178,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: sel ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: sel ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0), width: sel ? 1.8 : 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: sel ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 3),
                          Text(t.description, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton.icon(
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Create Board'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
          onPressed: () async {
            final ok = await ref.read(whiteboardProvider.notifier).createNewBoard(
                  title: _titleCtrl.text.trim().isEmpty ? 'Class Whiteboard' : _titleCtrl.text.trim(),
                  templateType: _selectedTemplate,
                  collaborationEnabled: _collabEnabled,
                );
            if (context.mounted) {
              Navigator.pop(context, ok);
            }
          },
        ),
      ],
    );
  }
}

class WhiteboardVersionHistoryDialog extends ConsumerStatefulWidget {
  const WhiteboardVersionHistoryDialog({super.key});

  @override
  ConsumerState<WhiteboardVersionHistoryDialog> createState() => _WhiteboardVersionHistoryDialogState();
}

class _WhiteboardVersionHistoryDialogState extends ConsumerState<WhiteboardVersionHistoryDialog> {
  final TextEditingController _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(whiteboardProvider);
    final versions = s.document?.versions ?? [];

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.history_rounded, color: Color(0xFF2563EB)),
          SizedBox(width: 8),
          Text('Version History & Checkpoints', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 520,
        height: 400,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'Checkpoint name (e.g., Solved Example 1)',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                  label: const Text('Save Checkpoint'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                  onPressed: () async {
                    final name = _nameCtrl.text.trim().isEmpty ? 'Manual Checkpoint' : _nameCtrl.text.trim();
                    final ok = await ref.read(whiteboardProvider.notifier).saveManual(versionName: name, isCheckpoint: true);
                    if (ok) _nameCtrl.clear();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: versions.isEmpty
                  ? const Center(child: Text('No saved versions yet.', style: TextStyle(color: Color(0xFF64748B))))
                  : ListView.separated(
                      itemCount: versions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, idx) {
                        final v = versions[idx];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: v.isCheckpoint ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                            child: Icon(
                              v.isCheckpoint ? Icons.bookmark_rounded : Icons.schedule_rounded,
                              size: 14,
                              color: v.isCheckpoint ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                            ),
                          ),
                          title: Text(v.versionName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text('Rev #${v.revision} • ${v.createdByName}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          trailing: OutlinedButton(
                            onPressed: () async {
                              final ok = await ref.read(whiteboardProvider.notifier).restoreVersion(v.id);
                              if (context.mounted && ok) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Restored "${v.versionName}" cleanly!')),
                                );
                              }
                            },
                            child: const Text('Restore', style: TextStyle(fontSize: 11)),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}

class WhiteboardShareDialog extends ConsumerStatefulWidget {
  const WhiteboardShareDialog({super.key});

  @override
  ConsumerState<WhiteboardShareDialog> createState() => _WhiteboardShareDialogState();
}

class _WhiteboardShareDialogState extends ConsumerState<WhiteboardShareDialog> {
  String _shareType = 'class';
  String _accessLevel = 'VIEW';
  final TextEditingController _targetCtrl = TextEditingController(text: 'Class 10 - A');
  WhiteboardShareItem? _createdShare;

  @override
  void dispose() {
    _targetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.share_rounded, color: Color(0xFF2563EB)),
          SizedBox(width: 8),
          Text('Share Whiteboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _shareType,
              decoration: InputDecoration(
                labelText: 'Share With',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: const [
                DropdownMenuItem(value: 'class', child: Text('Class')),
                DropdownMenuItem(value: 'section', child: Text('Section')),
                DropdownMenuItem(value: 'student', child: Text('Selected Student(s)')),
                DropdownMenuItem(value: 'teacher', child: Text('Faculty / Teachers')),
                DropdownMenuItem(value: 'link', child: Text('Authorized Institutional Link')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _shareType = v);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _targetCtrl,
              decoration: InputDecoration(
                labelText: 'Recipient / Label',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _accessLevel,
              decoration: InputDecoration(
                labelText: 'Access Level',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: const [
                DropdownMenuItem(value: 'VIEW', child: Text('View Only')),
                DropdownMenuItem(value: 'ANNOTATE', child: Text('View & Annotate')),
                DropdownMenuItem(value: 'EDIT', child: Text('Full Collaborate / Edit')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _accessLevel = v);
              },
            ),
            if (_createdShare != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Share Token: ${_createdShare!.shareToken}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _createdShare!.shareToken));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Share token copied!')));
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ElevatedButton.icon(
          icon: const Icon(Icons.send_rounded, size: 16),
          label: const Text('Share Board'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
          onPressed: () async {
            final res = await ref.read(whiteboardProvider.notifier).shareBoard(
                  shareType: _shareType,
                  targetLabel: _targetCtrl.text.trim(),
                  accessLevel: _accessLevel,
                );
            if (res != null && mounted) {
              setState(() => _createdShare = res);
            }
          },
        ),
      ],
    );
  }
}

class WhiteboardExportDialog extends ConsumerStatefulWidget {
  const WhiteboardExportDialog({super.key});

  @override
  ConsumerState<WhiteboardExportDialog> createState() => _WhiteboardExportDialogState();
}

class _WhiteboardExportDialogState extends ConsumerState<WhiteboardExportDialog> {
  String _format = 'PDF';
  String _scope = 'all_pages';
  String _orientation = 'landscape';
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.download_rounded, color: Color(0xFF2563EB)),
          SizedBox(width: 8),
          Text('Export Whiteboard Notes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _format,
              decoration: InputDecoration(
                labelText: 'Export Format',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: const [
                DropdownMenuItem(value: 'PDF', child: Text('Multi-Page Vector PDF (.pdf)')),
                DropdownMenuItem(value: 'PNG', child: Text('High-Resolution Image (.png)')),
                DropdownMenuItem(value: 'JPEG', child: Text('Compressed Image (.jpg)')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _format = v);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _scope,
              decoration: InputDecoration(
                labelText: 'Pages Scope',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: const [
                DropdownMenuItem(value: 'all_pages', child: Text('All Whiteboard Pages')),
                DropdownMenuItem(value: 'current_page', child: Text('Current Active Page Only')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _scope = v);
              },
            ),
            if (_format == 'PDF') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _orientation,
                decoration: InputDecoration(
                  labelText: 'Page Orientation',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: const [
                  DropdownMenuItem(value: 'landscape', child: Text('Landscape (Widescreen)')),
                  DropdownMenuItem(value: 'portrait', child: Text('Portrait (A4 Document)')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _orientation = v);
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton.icon(
          icon: _isExporting
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.file_download_outlined, size: 16),
          label: Text(_isExporting ? 'Exporting...' : 'Download $_format'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
          onPressed: _isExporting
              ? null
              : () async {
                  setState(() => _isExporting = true);
                  final res = await ref.read(whiteboardProvider.notifier).exportBoard(
                        format: _format,
                        scope: _scope,
                        orientation: _orientation,
                      );
                  setState(() => _isExporting = false);
                  if (res != null && context.mounted) {
                    final prefs = await SharedPreferences.getInstance();
                    final token = prefs.getString('auth_token') ?? '';
                    final dlPath = res['download_url']?.toString() ?? '';
                    if (dlPath.isNotEmpty) {
                      final uri = Uri.parse('${AppConfig.baseUrl}$dlPath?token=${Uri.encodeQueryComponent(token)}');
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Exported $_format successfully (${res['size_bytes']} bytes)')),
                      );
                    }
                  }
                },
        ),
      ],
    );
  }
}

class WhiteboardPermissionsDialog extends ConsumerWidget {
  const WhiteboardPermissionsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(whiteboardProvider);
    final doc = s.document;
    final notifier = ref.read(whiteboardProvider.notifier);

    if (doc == null) return const SizedBox.shrink();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.admin_panel_settings_outlined, color: Color(0xFF2563EB)),
          SizedBox(width: 8),
          Text('Classroom Whiteboard Permissions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Enable Real-Time Student Collaboration', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: const Text('Allow students to participate live when permitted', style: TextStyle(fontSize: 11)),
              value: doc.collaborationEnabled,
              onChanged: (v) => notifier.updateBoardMeta(collaborationEnabled: v, teacherOnlyMode: !v),
            ),
            SwitchListTile(
              title: const Text('Presentation Mode (Hide Student Controls)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: const Text('Keep students focused on teacher board without edit tools', style: TextStyle(fontSize: 11)),
              value: doc.presentationMode,
              onChanged: (v) => notifier.updateBoardMeta(presentationMode: v),
            ),
            SwitchListTile(
              title: const Text('Allow Students to Draw & Solve Equations', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              value: doc.defaultPermissions['students_can_draw'] == true,
              onChanged: (v) {
                final perms = Map<String, dynamic>.from(doc.defaultPermissions);
                perms['students_can_draw'] = v;
                notifier.updateBoardMeta(defaultPermissions: perms, teacherOnlyMode: !v);
                notifier.updateParticipantPermission(targetRole: 'student', permissionType: v ? 'EDIT' : 'VIEW');
              },
            ),
            if (s.activePage != null)
              SwitchListTile(
                title: Text('Lock "${s.activePage!.title}" Page', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text('Prevent student edits on the current board page', style: TextStyle(fontSize: 11)),
                value: s.activePage!.isLocked,
                onChanged: (_) => notifier.togglePageLock(s.activePage!.id),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
      ],
    );
  }
}

class WhiteboardAssetDialog extends ConsumerStatefulWidget {
  const WhiteboardAssetDialog({super.key});

  @override
  ConsumerState<WhiteboardAssetDialog> createState() => _WhiteboardAssetDialogState();
}

class _WhiteboardAssetDialogState extends ConsumerState<WhiteboardAssetDialog> {
  bool _importPdfPages = true;
  bool _uploading = false;
  String? _status;

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'pdf', 'ppt', 'pptx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    setState(() {
      _uploading = true;
      _status = 'Uploading ${file.name}...';
    });

    final res = await ref.read(whiteboardProvider.notifier).uploadAndInsertAsset(
          filename: file.name,
          bytes: bytes,
          importPdfPages: _importPdfPages,
        );

    if (mounted) {
      setState(() => _uploading = false);
      if (res != null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Inserted ${file.name} onto whiteboard!')),
        );
      } else {
        setState(() => _status = 'Upload failed. Please verify file type/size.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF2563EB)),
          SizedBox(width: 8),
          Text('Insert Image, PDF or Slides', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Supported formats: PNG, JPG, JPEG, WebP, PDF, PPT/PPTX (Max 25 MB). Files are stored securely in ERP Object Storage.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Import multi-page PDF as separate board pages', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              value: _importPdfPages,
              onChanged: (v) => setState(() => _importPdfPages = v),
            ),
            if (_status != null) ...[
              const SizedBox(height: 8),
              Text(_status!, style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB))),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton.icon(
          icon: _uploading
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.upload_file_rounded, size: 16),
          label: Text(_uploading ? 'Uploading...' : 'Select File & Upload'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
          onPressed: _uploading ? null : _pickAndUpload,
        ),
      ],
    );
  }
}
