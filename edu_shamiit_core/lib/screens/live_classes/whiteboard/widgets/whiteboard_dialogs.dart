import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../config/app_config.dart';
import '../models/whiteboard_models.dart';
import '../providers/whiteboard_provider.dart';
import '../../providers/live_class_management_provider.dart';

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
  bool _strikethrough = false;
  String _fontFamily = 'sans-serif';
  late Color _textColor;
  Color? _bgColor;
  String _align = 'left';

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
    _fontSize = (widget.initialFontSize <= 0 || widget.initialFontSize.isNaN) ? 14.0 : widget.initialFontSize;
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E2235) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF13182C) : const Color(0xFFF8FAFC);

    final paletteColors = [
      isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
      const Color(0xFF2563EB),
      const Color(0xFF0EA5E9),
      const Color(0xFF10B981),
      const Color(0xFF047857),
      const Color(0xFFF59E0B),
      const Color(0xFFEA580C),
      const Color(0xFFDC2626),
      const Color(0xFFE11D48),
      const Color(0xFF8B5CF6),
      const Color(0xFF4F46E5),
      if (isDark) const Color(0xFF94A3B8) else const Color(0xFF64748B),
    ];

    final allSizes = <double>{
      10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 18.0, 20.0, 22.0, 24.0, 28.0, 32.0, 36.0, 48.0,
      _fontSize,
    }.toList()..sort();

    return AlertDialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1.2),
      ),
      title: Row(
        children: [
          Icon(
            widget.isStickyNote ? Icons.sticky_note_2_rounded : Icons.text_fields_rounded,
            color: const Color(0xFF2563EB),
            size: 22,
          ),
          const SizedBox(width: 10),
          Text(
            widget.isStickyNote ? 'Edit Sticky Note' : 'Rich Text Annotation',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Toolbar Row 1: Formatting Styles, Alignments, Font Family
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (!widget.isStickyNote) ...[
                      _fmtBtn(Icons.format_bold, _bold, isDark, () => setState(() => _bold = !_bold)),
                      _fmtBtn(Icons.format_italic, _italic, isDark, () => setState(() => _italic = !_italic)),
                      _fmtBtn(Icons.format_underline, _underline, isDark, () => setState(() => _underline = !_underline)),
                      _fmtBtn(Icons.format_strikethrough, _strikethrough, isDark, () => setState(() => _strikethrough = !_strikethrough)),
                      Container(width: 1, height: 18, color: borderColor),
                      _fmtBtn(Icons.format_align_left, _align == 'left', isDark, () => setState(() => _align = 'left')),
                      _fmtBtn(Icons.format_align_center, _align == 'center', isDark, () => setState(() => _align = 'center')),
                      _fmtBtn(Icons.format_align_right, _align == 'right', isDark, () => setState(() => _align = 'right')),
                      Container(width: 1, height: 18, color: borderColor),
                    ],
                    // Font Family Dropdown
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _fontFamily,
                        dropdownColor: dialogBg,
                        isDense: true,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textPrimary),
                        items: const [
                          DropdownMenuItem(value: 'sans-serif', child: Text('Modern (Sans)')),
                          DropdownMenuItem(value: 'serif', child: Text('Academic (Serif)')),
                          DropdownMenuItem(value: 'monospace', child: Text('Code (Mono)')),
                          DropdownMenuItem(value: 'cursive', child: Text('Handwritten')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _fontFamily = v);
                        },
                      ),
                    ),
                    Container(width: 1, height: 18, color: borderColor),
                    // Font Size Dropdown
                    DropdownButtonHideUnderline(
                      child: DropdownButton<double>(
                        value: _fontSize,
                        dropdownColor: dialogBg,
                        isDense: true,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                        items: allSizes
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text('${s == s.roundToDouble() ? s.toInt() : s}pt', style: TextStyle(fontSize: 11, color: textPrimary)),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _fontSize = v);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Color Palette Section
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('Color:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: paletteColors.map((c) {
                        final isSelected = _textColor == c;
                        return GestureDetector(
                          onTap: () => setState(() => _textColor = c),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? const Color(0xFF3B82F6) : borderColor,
                                width: isSelected ? 2.5 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 6, spreadRadius: 1)]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, size: 12, color: Colors.white)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  if (widget.isStickyNote) ...[
                    const SizedBox(width: 10),
                    Text('Paper:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary)),
                    const SizedBox(width: 6),
                    for (final bg in [
                      const Color(0xFFFEF3C7),
                      const Color(0xFFDBEAFE),
                      const Color(0xFFDCFCE7),
                      const Color(0xFFFCE7F3),
                      const Color(0xFFF3E8FF),
                    ])
                      GestureDetector(
                        onTap: () => setState(() => _bgColor = bg),
                        child: Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.only(left: 3),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: _bgColor == bg ? const Color(0xFF2563EB) : borderColor,
                              width: _bgColor == bg ? 2.0 : 1.0,
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // Text Input Box
              TextField(
                controller: _ctrl,
                maxLines: 5,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                style: TextStyle(
                  fontSize: 14,
                  color: _textColor,
                  fontFamily: _fontFamily,
                  fontWeight: _bold ? FontWeight.bold : FontWeight.normal,
                  fontStyle: _italic ? FontStyle.italic : FontStyle.normal,
                  decoration: TextDecoration.combine([
                    if (_underline) TextDecoration.underline,
                    if (_strikethrough) TextDecoration.lineThrough,
                  ]),
                ),
                decoration: InputDecoration(
                  hintText: widget.isStickyNote ? 'Enter note thoughts, checklist or summary...' : 'Type text annotation or concept name...',
                  hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 13),
                  filled: true,
                  fillColor: _bgColor ?? inputBg,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 10),
              // Live Render Preview Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor.withValues(alpha: 0.7)),
                ),
                child: Row(
                  children: [
                    Text('Preview: ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textSecondary)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _ctrl.text.isEmpty ? 'Your styled text appears here' : _ctrl.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: _textColor,
                          fontFamily: _fontFamily,
                          fontWeight: _bold ? FontWeight.bold : FontWeight.normal,
                          fontStyle: _italic ? FontStyle.italic : FontStyle.normal,
                          decoration: TextDecoration.combine([
                            if (_underline) TextDecoration.underline,
                            if (_strikethrough) TextDecoration.lineThrough,
                          ]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            final t = _ctrl.text.trim();
            if (t.isEmpty) return;
            Navigator.pop(context, {
              'text': t,
              'fontSize': _fontSize,
              'bold': _bold,
              'italic': _italic,
              'underline': _underline,
              'strikethrough': _strikethrough,
              'fontFamily': _fontFamily,
              'align': _align,
              'color': WhiteboardColorHelper.toHex(_textColor),
              if (_bgColor != null) 'bgColor': WhiteboardColorHelper.toHex(_bgColor!),
            });
          },
          child: const Text('Apply Changes', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _fmtBtn(IconData icon, bool active, bool isDark, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF2563EB)
              : (isDark ? const Color(0xFF2A314A) : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 15,
          color: active ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
        ),
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
  bool _isCreating = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E2235) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF13182C) : const Color(0xFFF8FAFC);

    final s = ref.watch(whiteboardProvider);
    final templates = s.templates;

    return AlertDialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1.2),
      ),
      title: Row(
        children: [
          const Icon(Icons.dashboard_customize_rounded, color: Color(0xFF2563EB)),
          const SizedBox(width: 8),
          Text(
            'Create New Board / Select Template',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
          ),
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
                style: TextStyle(fontSize: 13, color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Whiteboard Title',
                  labelStyle: TextStyle(color: textSecondary, fontSize: 13),
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB))),
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Enable Real-time Student Collaboration', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                value: _collabEnabled,
                activeColor: const Color(0xFF2563EB),
                onChanged: (v) => setState(() => _collabEnabled = v),
              ),
              const SizedBox(height: 8),
              Text('Subject & Layout Templates', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: templates.map((t) {
                  final sel = _selectedTemplate == t.id;
                  final cardBg = sel
                      ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF))
                      : (isDark ? const Color(0xFF13182C) : const Color(0xFFF8FAFC));
                  return InkWell(
                    onTap: _isCreating
                        ? null
                        : () {
                            setState(() {
                              _selectedTemplate = t.id;
                              if (_titleCtrl.text.isEmpty ||
                                  _titleCtrl.text == 'New Interactive Whiteboard' ||
                                  templates.any((x) => _titleCtrl.text == x.name)) {
                                _titleCtrl.text = t.id == 'blank' ? 'Class Whiteboard' : t.name;
                              }
                            });
                          },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 178,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sel ? const Color(0xFF2563EB) : borderColor,
                          width: sel ? 2.0 : 1.0,
                        ),
                        boxShadow: sel
                            ? [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.25), blurRadius: 8, spreadRadius: 1)]
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: sel ? const Color(0xFF38BDF8) : textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            t.description,
                            style: TextStyle(fontSize: 10, color: textSecondary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
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
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: textSecondary)),
        ),
        ElevatedButton.icon(
          icon: _isCreating
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.add_rounded, size: 16),
          label: Text(_isCreating ? 'Creating...' : 'Create Board'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isCreating
              ? null
              : () async {
                  setState(() => _isCreating = true);
                  final titleText = _titleCtrl.text.trim().isEmpty ? 'Class Whiteboard' : _titleCtrl.text.trim();
                  final ok = await ref.read(whiteboardProvider.notifier).createNewBoard(
                        title: titleText,
                        templateType: _selectedTemplate,
                        collaborationEnabled: _collabEnabled,
                      );
                  if (context.mounted) {
                    Navigator.pop(context, ok);
                    if (ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Board "$titleText" created with interactive template objects!'),
                          backgroundColor: const Color(0xFF16A34A),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to create board. Please try again.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
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
  late final TextEditingController _targetCtrl;
  WhiteboardShareItem? _createdShare;

  @override
  void initState() {
    super.initState();
    final activeSess = ref.read(liveClassManagementProvider).conductSessionData?.activeSession;
    final sel = ref.read(liveClassManagementProvider).selectedMyClass;
    final cls = activeSess?.classSection ?? sel?.classSection ?? 'Class 12 - A';
    _targetCtrl = TextEditingController(text: cls);
  }

  @override
  void dispose() {
    _targetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final menuBg = isDark ? const Color(0xFF1E2235) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);

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
              dropdownColor: menuBg,
              style: TextStyle(fontSize: 13, color: textPrimary),
              decoration: InputDecoration(
                labelText: 'Share With',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: [
                DropdownMenuItem(value: 'class', child: Text('Class', style: TextStyle(color: textPrimary))),
                DropdownMenuItem(value: 'section', child: Text('Section', style: TextStyle(color: textPrimary))),
                DropdownMenuItem(value: 'student', child: Text('Selected Student(s)', style: TextStyle(color: textPrimary))),
                DropdownMenuItem(value: 'teacher', child: Text('Faculty / Teachers', style: TextStyle(color: textPrimary))),
                DropdownMenuItem(value: 'link', child: Text('Authorized Institutional Link', style: TextStyle(color: textPrimary))),
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
              dropdownColor: menuBg,
              style: TextStyle(fontSize: 13, color: textPrimary),
              decoration: InputDecoration(
                labelText: 'Access Level',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: [
                DropdownMenuItem(value: 'VIEW', child: Text('View Only', style: TextStyle(color: textPrimary))),
                DropdownMenuItem(value: 'ANNOTATE', child: Text('View & Annotate', style: TextStyle(color: textPrimary))),
                DropdownMenuItem(value: 'EDIT', child: Text('Full Collaborate / Edit', style: TextStyle(color: textPrimary))),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final menuBg = isDark ? const Color(0xFF1E2235) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);

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
              dropdownColor: menuBg,
              style: TextStyle(fontSize: 13, color: textPrimary),
              decoration: InputDecoration(
                labelText: 'Export Format',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: [
                DropdownMenuItem(value: 'PDF', child: Text('Multi-Page Vector PDF (.pdf)', style: TextStyle(color: textPrimary))),
                DropdownMenuItem(value: 'PNG', child: Text('High-Resolution Image (.png)', style: TextStyle(color: textPrimary))),
                DropdownMenuItem(value: 'JPEG', child: Text('Compressed Image (.jpg)', style: TextStyle(color: textPrimary))),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _format = v);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _scope,
              dropdownColor: menuBg,
              style: TextStyle(fontSize: 13, color: textPrimary),
              decoration: InputDecoration(
                labelText: 'Pages Scope',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: [
                DropdownMenuItem(value: 'all_pages', child: Text('All Whiteboard Pages', style: TextStyle(color: textPrimary))),
                DropdownMenuItem(value: 'current_page', child: Text('Current Active Page Only', style: TextStyle(color: textPrimary))),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _scope = v);
              },
            ),
            if (_format == 'PDF') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _orientation,
                dropdownColor: menuBg,
                style: TextStyle(fontSize: 13, color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Page Orientation',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: [
                  DropdownMenuItem(value: 'landscape', child: Text('Landscape (Widescreen)', style: TextStyle(color: textPrimary))),
                  DropdownMenuItem(value: 'portrait', child: Text('Portrait (A4 Document)', style: TextStyle(color: textPrimary))),
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
              onChanged: (v) {
                final perms = Map<String, dynamic>.from(doc.defaultPermissions);
                if (v) {
                  perms['students_can_draw'] = true;
                  perms['students_can_annotate'] = true;
                }
                notifier.updateBoardMeta(
                  collaborationEnabled: v,
                  teacherOnlyMode: !v,
                  presentationMode: v ? false : doc.presentationMode,
                  defaultPermissions: perms,
                );
                notifier.updateParticipantPermission(targetRole: 'student', permissionType: v ? 'EDIT' : 'VIEW');
              },
            ),
            SwitchListTile(
              title: const Text('Presentation Mode (Hide Student Controls)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: const Text('Keep students focused on teacher board without edit tools', style: TextStyle(fontSize: 11)),
              value: doc.presentationMode,
              onChanged: (v) {
                final perms = Map<String, dynamic>.from(doc.defaultPermissions);
                if (v) {
                  perms['students_can_draw'] = false;
                }
                notifier.updateBoardMeta(
                  presentationMode: v,
                  teacherOnlyMode: v,
                  defaultPermissions: perms,
                );
                if (v) {
                  notifier.updateParticipantPermission(targetRole: 'student', permissionType: 'VIEW');
                }
              },
            ),
            SwitchListTile(
              title: const Text('Allow Students to Draw & Solve Equations', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              value: doc.defaultPermissions['students_can_draw'] == true,
              onChanged: (v) {
                final perms = Map<String, dynamic>.from(doc.defaultPermissions);
                perms['students_can_draw'] = v;
                if (v) perms['students_can_annotate'] = true;
                notifier.updateBoardMeta(
                  collaborationEnabled: v ? true : doc.collaborationEnabled,
                  presentationMode: v ? false : doc.presentationMode,
                  defaultPermissions: perms,
                  teacherOnlyMode: !v,
                );
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

class _WhiteboardAssetDialogState extends ConsumerState<WhiteboardAssetDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _importPdfPages = true;
  bool _uploading = false;
  String? _status;

  PlatformFile? _selectedFile;
  Uint8List? _fileBytes;

  final TextEditingController _urlCtrl = TextEditingController();
  final TextEditingController _titleCtrl = TextEditingController();

  static const _diagramPresets = <Map<String, String>>[
    {
      'title': 'Benzene Ring & Orbitals',
      'category': 'Organic Chemistry',
      'icon': '⚛️',
      'url': 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/6f/Benzene_representations.svg/500px-Benzene_representations.svg.png',
    },
    {
      'title': 'Animal Cell Organelles',
      'category': 'Biology & Cytology',
      'icon': '🧬',
      'url': 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/48/Animal_cell_structure_en.svg/500px-Animal_cell_structure_en.svg.png',
    },
    {
      'title': 'Electric Circuit Diagram',
      'category': 'Physics & Electromagnetism',
      'icon': '⚡',
      'url': 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/cd/Circuit_diagram_example.svg/500px-Circuit_diagram_example.svg.png',
    },
    {
      'title': 'Trig Unit Circle (Radians & Deg)',
      'category': 'Mathematics',
      'icon': '📐',
      'url': 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4c/Unit_circle_angles_color.svg/500px-Unit_circle_angles_color.svg.png',
    },
    {
      'title': 'World Map & Climate Zones',
      'category': 'Geography',
      'icon': '🌐',
      'url': 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/World_map_-_low_resolution.svg/500px-World_map_-_low_resolution.svg.png',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'svg', 'pdf', 'ppt', 'pptx'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() => _status = 'Could not read file data. Please try another file.');
        return;
      }
      setState(() {
        _selectedFile = file;
        _fileBytes = bytes;
        _status = null;
      });
    } catch (e) {
      setState(() => _status = 'File selection error: $e');
    }
  }

  Future<void> _uploadAndInsert() async {
    if (_selectedFile == null || _fileBytes == null) {
      await _pickFile();
      if (_selectedFile == null || _fileBytes == null) return;
    }

    setState(() {
      _uploading = true;
      _status = 'Uploading ${_selectedFile!.name}...';
    });

    final res = await ref.read(whiteboardProvider.notifier).uploadAndInsertAsset(
          filename: _selectedFile!.name,
          bytes: _fileBytes!,
          importPdfPages: _importPdfPages,
        );

    if (mounted) {
      setState(() => _uploading = false);
      if (res != null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Inserted ${_selectedFile!.name} onto whiteboard!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } else {
        setState(() => _status = 'Upload failed. Please check network/file type.');
      }
    }
  }

  Future<void> _insertFromUrl() async {
    final rawUrl = _urlCtrl.text.trim();
    if (rawUrl.isEmpty) {
      setState(() => _status = 'Please enter a valid image URL.');
      return;
    }

    final title = _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : 'Web Image';
    await ref.read(whiteboardProvider.notifier).insertImageUrl(url: rawUrl, title: title);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Inserted "$title" onto whiteboard!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _insertPreset(Map<String, String> preset) async {
    await ref.read(whiteboardProvider.notifier).insertImageUrl(
          url: preset['url']!,
          title: preset['title'],
        );
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Inserted ${preset['title']} onto whiteboard!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    const accentBlue = Color(0xFF2563EB);

    final isImg = _selectedFile != null &&
        ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'].contains(_selectedFile!.extension?.toLowerCase());

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: borderColor)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_photo_alternate_rounded, color: accentBlue, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Insert Image, PDF or Slides',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                        Text(
                          'Supported: PNG, JPG, WebP, PDF, PPTX (Max 25 MB)',
                          style: TextStyle(fontSize: 11, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 18, color: textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Tab Bar
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: accentBlue,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: textSecondary,
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: '📁 Upload File'),
                    Tab(text: '🌐 Web URL'),
                    Tab(text: '📚 STEM Diagrams'),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Upload File
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_selectedFile == null)
                            InkWell(
                              onTap: _uploading ? null : _pickFile,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: accentBlue.withValues(alpha: 0.4), width: 1.5),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: accentBlue.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.cloud_upload_outlined, color: accentBlue, size: 28),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Click to browse or choose an image / document',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'PNG, JPG, WebP, GIF, SVG, PDF, PowerPoint up to 25 MB',
                                      style: TextStyle(fontSize: 11, color: textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                children: [
                                  if (isImg && _fileBytes != null)
                                    Container(
                                      height: 140,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.memory(_fileBytes!, fit: BoxFit.contain),
                                      ),
                                    )
                                  else
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _selectedFile!.extension?.toLowerCase() == 'pdf'
                                                ? Icons.picture_as_pdf_rounded
                                                : Icons.description_rounded,
                                            size: 36,
                                            color: Colors.redAccent,
                                          ),
                                          const SizedBox(width: 10),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _selectedFile!.name,
                                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
                                              ),
                                              Text(
                                                _formatFileSize(_selectedFile!.size),
                                                style: TextStyle(fontSize: 11, color: textSecondary),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${_selectedFile!.name} (${_formatFileSize(_selectedFile!.size)})',
                                          style: TextStyle(fontSize: 11, color: textSecondary),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      TextButton.icon(
                                        icon: const Icon(Icons.refresh_rounded, size: 14),
                                        label: const Text('Change', style: TextStyle(fontSize: 11)),
                                        onPressed: _uploading ? null : _pickFile,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 10),
                          if (_selectedFile?.extension?.toLowerCase() == 'pdf')
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                'Import multi-page PDF as separate board pages',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
                              ),
                              value: _importPdfPages,
                              activeThumbColor: accentBlue,
                              onChanged: (v) => setState(() => _importPdfPages = v),
                            ),
                          if (_uploading) ...[
                            const SizedBox(height: 10),
                            const LinearProgressIndicator(color: accentBlue, minHeight: 4),
                          ],
                          if (_status != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _status!,
                              style: TextStyle(
                                fontSize: 11,
                                color: _status!.contains('failed') || _status!.contains('error')
                                    ? Colors.redAccent
                                    : accentBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Tab 2: Web URL
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Direct Image Web URL:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _urlCtrl,
                            style: TextStyle(fontSize: 12, color: textPrimary),
                            decoration: InputDecoration(
                              hintText: 'https://example.com/diagram.png',
                              hintStyle: TextStyle(fontSize: 12, color: textSecondary.withValues(alpha: 0.6)),
                              prefixIcon: const Icon(Icons.link_rounded, size: 16),
                              filled: true,
                              fillColor: cardBg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 10),
                          Text('Optional Label / Title:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _titleCtrl,
                            style: TextStyle(fontSize: 12, color: textPrimary),
                            decoration: InputDecoration(
                              hintText: 'e.g. Physics Formula Diagram',
                              hintStyle: TextStyle(fontSize: 12, color: textSecondary.withValues(alpha: 0.6)),
                              prefixIcon: const Icon(Icons.title_rounded, size: 16),
                              filled: true,
                              fillColor: cardBg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                            ),
                          ),
                          if (_urlCtrl.text.trim().startsWith('http')) ...[
                            const SizedBox(height: 12),
                            Container(
                              height: 120,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: cardBg,
                                border: Border.all(color: borderColor),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  _urlCtrl.text.trim(),
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Center(
                                    child: Text(
                                      'Could not load preview from URL',
                                      style: TextStyle(fontSize: 11, color: textSecondary),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Tab 3: STEM Diagram Presets
                    ListView.separated(
                      itemCount: _diagramPresets.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final p = _diagramPresets[i];
                        return InkWell(
                          onTap: () => _insertPreset(p),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Text(p['icon']!, style: const TextStyle(fontSize: 22)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p['title']!,
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
                                      ),
                                      Text(
                                        p['category']!,
                                        style: TextStyle(fontSize: 10, color: textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                FilledButton.tonal(
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () => _insertPreset(p),
                                  child: const Text('Insert', style: TextStyle(fontSize: 11)),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: TextStyle(color: textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  if (_tabController.index == 0)
                    ElevatedButton.icon(
                      icon: _uploading
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.upload_file_rounded, size: 16),
                      label: Text(_uploading ? 'Uploading...' : (_selectedFile == null ? 'Select & Upload' : 'Insert onto Board')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _uploading ? null : _uploadAndInsert,
                    )
                  else if (_tabController.index == 1)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Insert from URL'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _insertFromUrl,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
