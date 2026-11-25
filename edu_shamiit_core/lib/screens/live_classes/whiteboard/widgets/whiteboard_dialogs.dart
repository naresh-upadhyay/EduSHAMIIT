import 'dart:async';
import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
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
  bool _strikethrough = false;
  String _fontFamily = 'sans-serif';
  late Color _textColor;
  Color? _bgColor;
  String _align = 'left';

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
    _fontSize = (widget.initialFontSize <= 0 || widget.initialFontSize.isNaN)
        ? 14.0
        : widget.initialFontSize;
    _bold = widget.initialBold;
    _italic = widget.initialItalic;
    _underline = widget.initialUnderline;
    _textColor = widget.initialColor;
    _bgColor = widget.initialBgColor ??
        (widget.isStickyNote ? const Color(0xFFFEF3C7) : null);
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
    final textPrimary =
        isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
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
      10.0,
      11.0,
      12.0,
      13.0,
      14.0,
      15.0,
      16.0,
      18.0,
      20.0,
      22.0,
      24.0,
      28.0,
      32.0,
      36.0,
      48.0,
      _fontSize,
    }.toList()
      ..sort();

    return AlertDialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1.2),
      ),
      title: Row(
        children: [
          Icon(
            widget.isStickyNote
                ? Icons.sticky_note_2_rounded
                : Icons.text_fields_rounded,
            color: const Color(0xFF2563EB),
            size: 22,
          ),
          const SizedBox(width: 10),
          Text(
            widget.isStickyNote ? 'Edit Sticky Note' : 'Rich Text Annotation',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
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
                      _fmtBtn(Icons.format_bold, _bold, isDark,
                          () => setState(() => _bold = !_bold)),
                      _fmtBtn(Icons.format_italic, _italic, isDark,
                          () => setState(() => _italic = !_italic)),
                      _fmtBtn(Icons.format_underline, _underline, isDark,
                          () => setState(() => _underline = !_underline)),
                      _fmtBtn(
                          Icons.format_strikethrough,
                          _strikethrough,
                          isDark,
                          () =>
                              setState(() => _strikethrough = !_strikethrough)),
                      Container(width: 1, height: 18, color: borderColor),
                      _fmtBtn(Icons.format_align_left, _align == 'left', isDark,
                          () => setState(() => _align = 'left')),
                      _fmtBtn(Icons.format_align_center, _align == 'center',
                          isDark, () => setState(() => _align = 'center')),
                      _fmtBtn(Icons.format_align_right, _align == 'right',
                          isDark, () => setState(() => _align = 'right')),
                      Container(width: 1, height: 18, color: borderColor),
                    ],
                    // Font Family Dropdown
                    DropdownButtonHideUnderline(
                      child: AppSearchableDropdown<String>.fromMenuItems(
                        value: _fontFamily,
                        dropdownColor: dialogBg,
                        isDense: true,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: textPrimary),
                        items: const [
                          DropdownMenuItem(
                              value: 'sans-serif',
                              child: Text('Modern (Sans)')),
                          DropdownMenuItem(
                              value: 'serif', child: Text('Academic (Serif)')),
                          DropdownMenuItem(
                              value: 'monospace', child: Text('Code (Mono)')),
                          DropdownMenuItem(
                              value: 'cursive', child: Text('Handwritten')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _fontFamily = v);
                        },
                      ),
                    ),
                    Container(width: 1, height: 18, color: borderColor),
                    // Font Size Dropdown
                    DropdownButtonHideUnderline(
                      child: AppSearchableDropdown<double>.fromMenuItems(
                        value: _fontSize,
                        dropdownColor: dialogBg,
                        isDense: true,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB)),
                        items: allSizes
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                      '${s == s.roundToDouble() ? s.toInt() : s}pt',
                                      style: TextStyle(
                                          fontSize: 11, color: textPrimary)),
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
                  Text('Color:',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: textSecondary)),
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
                                color: isSelected
                                    ? const Color(0xFF3B82F6)
                                    : borderColor,
                                width: isSelected ? 2.5 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                          color: c.withValues(alpha: 0.5),
                                          blurRadius: 6,
                                          spreadRadius: 1)
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    size: 12, color: Colors.white)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  if (widget.isStickyNote) ...[
                    const SizedBox(width: 10),
                    Text('Paper:',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: textSecondary)),
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
                              color: _bgColor == bg
                                  ? const Color(0xFF2563EB)
                                  : borderColor,
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
                  hintText: widget.isStickyNote
                      ? 'Enter note thoughts, checklist or summary...'
                      : 'Type text annotation or concept name...',
                  hintStyle: TextStyle(
                      color: textSecondary.withValues(alpha: 0.6),
                      fontSize: 13),
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
                    borderSide:
                        const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 10),
              // Live Render Preview Banner
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor.withValues(alpha: 0.7)),
                ),
                child: Row(
                  children: [
                    Text('Preview: ',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: textSecondary)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _ctrl.text.isEmpty
                            ? 'Your styled text appears here'
                            : _ctrl.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: _textColor,
                          fontFamily: _fontFamily,
                          fontWeight:
                              _bold ? FontWeight.bold : FontWeight.normal,
                          fontStyle:
                              _italic ? FontStyle.italic : FontStyle.normal,
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
              if (_bgColor != null)
                'bgColor': WhiteboardColorHelper.toHex(_bgColor!),
            });
          },
          child: const Text('Apply Changes',
              style: TextStyle(fontWeight: FontWeight.bold)),
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
          color: active
              ? Colors.white
              : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
        ),
      ),
    );
  }
}

class WhiteboardTemplatesDialog extends ConsumerStatefulWidget {
  final bool forceStandalone;

  const WhiteboardTemplatesDialog({
    super.key,
    this.forceStandalone = false,
  });

  @override
  ConsumerState<WhiteboardTemplatesDialog> createState() =>
      _WhiteboardTemplatesDialogState();
}

class _WhiteboardTemplatesDialogState
    extends ConsumerState<WhiteboardTemplatesDialog> {
  final TextEditingController _titleCtrl =
      TextEditingController(text: 'New Interactive Whiteboard');
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
    final textPrimary =
        isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
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
          const Icon(Icons.dashboard_customize_rounded,
              color: Color(0xFF2563EB)),
          const SizedBox(width: 8),
          Text(
            'Create New Board / Select Template',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
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
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF2563EB))),
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Enable Real-time Student Collaboration',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textPrimary)),
                value: _collabEnabled,
                activeThumbColor: const Color(0xFF2563EB),
                onChanged: (v) => setState(() => _collabEnabled = v),
              ),
              const SizedBox(height: 8),
              Text('Subject & Layout Templates',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: templates.map((t) {
                  final sel = _selectedTemplate == t.id;
                  final cardBg = sel
                      ? (isDark
                          ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
                          : const Color(0xFFEFF6FF))
                      : (isDark
                          ? const Color(0xFF13182C)
                          : const Color(0xFFF8FAFC));
                  return InkWell(
                    onTap: _isCreating
                        ? null
                        : () {
                            setState(() {
                              _selectedTemplate = t.id;
                              if (_titleCtrl.text.isEmpty ||
                                  _titleCtrl.text ==
                                      'New Interactive Whiteboard' ||
                                  templates
                                      .any((x) => _titleCtrl.text == x.name)) {
                                _titleCtrl.text = t.id == 'blank'
                                    ? 'Class Whiteboard'
                                    : t.name;
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
                            ? [
                                BoxShadow(
                                    color: const Color(0xFF2563EB)
                                        .withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    spreadRadius: 1)
                              ]
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
                              color:
                                  sel ? const Color(0xFF38BDF8) : textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            t.description,
                            style:
                                TextStyle(fontSize: 10, color: textSecondary),
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
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.add_rounded, size: 16),
          label: Text(_isCreating ? 'Creating...' : 'Create Board'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isCreating
              ? null
              : () async {
                  setState(() => _isCreating = true);
                  final titleText = _titleCtrl.text.trim().isEmpty
                      ? 'Class Whiteboard'
                      : _titleCtrl.text.trim();
                  final ok = await ref
                      .read(whiteboardProvider.notifier)
                      .createNewBoard(
                        title: titleText,
                        templateType: _selectedTemplate,
                        collaborationEnabled: _collabEnabled,
                        forceStandalone: widget.forceStandalone,
                      );
                  if (context.mounted) {
                    Navigator.pop(context, ok);
                    if (ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Board "$titleText" created with interactive template objects!'),
                          backgroundColor: const Color(0xFF16A34A),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Failed to create board. Please try again.'),
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
  ConsumerState<WhiteboardVersionHistoryDialog> createState() =>
      _WhiteboardVersionHistoryDialogState();
}

class _WhiteboardVersionHistoryDialogState
    extends ConsumerState<WhiteboardVersionHistoryDialog> {
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
          Text('Version History & Checkpoints',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                  label: const Text('Save Checkpoint'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white),
                  onPressed: () async {
                    final name = _nameCtrl.text.trim().isEmpty
                        ? 'Manual Checkpoint'
                        : _nameCtrl.text.trim();
                    final ok = await ref
                        .read(whiteboardProvider.notifier)
                        .saveManual(versionName: name, isCheckpoint: true);
                    if (ok) _nameCtrl.clear();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: versions.isEmpty
                  ? const Center(
                      child: Text('No saved versions yet.',
                          style: TextStyle(color: Color(0xFF64748B))))
                  : ListView.separated(
                      itemCount: versions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, idx) {
                        final v = versions[idx];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: v.isCheckpoint
                                ? const Color(0xFFEFF6FF)
                                : const Color(0xFFF1F5F9),
                            child: Icon(
                              v.isCheckpoint
                                  ? Icons.bookmark_rounded
                                  : Icons.schedule_rounded,
                              size: 14,
                              color: v.isCheckpoint
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          title: Text(v.versionName,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              'Rev #${v.revision} • ${v.createdByName}',
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF64748B))),
                          trailing: OutlinedButton(
                            onPressed: () async {
                              final ok = await ref
                                  .read(whiteboardProvider.notifier)
                                  .restoreVersion(v.id);
                              if (context.mounted && ok) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Restored "${v.versionName}" cleanly!')),
                                );
                              }
                            },
                            child: const Text('Restore',
                                style: TextStyle(fontSize: 11)),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close')),
      ],
    );
  }
}

class WhiteboardShareDialog extends ConsumerStatefulWidget {
  final String? whiteboardId;
  final String? boardTitle;

  const WhiteboardShareDialog({
    super.key,
    this.whiteboardId,
    this.boardTitle,
  });

  @override
  ConsumerState<WhiteboardShareDialog> createState() =>
      _WhiteboardShareDialogState();
}

class _WhiteboardShareDialogState extends ConsumerState<WhiteboardShareDialog> {
  // Mode: 'class_sections' | 'individual' | 'link'
  String _mode = 'class_sections';

  // Option 1: Cascading Class -> Multiple Sections -> Students & Teachers
  bool _loadingClasses = true;
  List<Map<String, dynamic>> _classes = [];
  String? _selectedClassId;
  final Set<String> _selectedSectionIds = {};
  bool _includeStudents = true;
  bool _includeTeachers = true;
  bool _loadingMembers = false;
  List<Map<String, dynamic>> _classStudents = [];
  List<Map<String, dynamic>> _classTeachers = [];
  final Set<String> _checkedMemberIds = {};
  final TextEditingController _memberFilterCtrl = TextEditingController();

  // Option 2: Individual Search & Multi-Select
  final TextEditingController _individualSearchCtrl = TextEditingController();
  String _individualRoleFilter = 'all'; // 'all' | 'teacher' | 'student'
  bool _searchingIndividuals = false;
  List<Map<String, dynamic>> _searchResults = [];
  final Map<String, Map<String, dynamic>> _selectedIndividuals = {};
  Timer? _searchDebounce;

  // Option 3: Share Link
  final TextEditingController _linkLabelCtrl =
      TextEditingController(text: 'Authorized Institutional Link');

  // Access Level & Granular Capabilities ("What they can do")
  String _accessLevel = 'VIEW'; // 'VIEW' | 'ANNOTATE' | 'EDIT'
  bool _capDraw = false;
  bool _capNotes = false;
  bool _capExport = true;
  bool _capManagePages = false;

  bool _isSubmitting = false;
  List<WhiteboardShareItem> _lastCreatedShares = [];
  List<WhiteboardShareItem> _existingShares = [];
  bool _loadingShares = true;

  @override
  void initState() {
    super.initState();
    _loadInitialDirectory();
    _loadShares();
    _runIndividualSearch();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _memberFilterCtrl.dispose();
    _individualSearchCtrl.dispose();
    _linkLabelCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialDirectory() async {
    final dirs = await ref
        .read(whiteboardProvider.notifier)
        .fetchShareDirectoryClasses();
    if (!mounted) return;
    setState(() {
      _classes = dirs;
      _loadingClasses = false;
      if (dirs.isNotEmpty) {
        _selectedClassId = dirs.first['id']?.toString();
      }
    });
    if (_selectedClassId != null && _selectedClassId!.isNotEmpty) {
      await _loadMembersForSelectedClass();
    }
  }

  Future<void> _loadMembersForSelectedClass() async {
    final cid = _selectedClassId;
    if (cid == null || cid.isEmpty) return;
    setState(() => _loadingMembers = true);
    final res =
        await ref.read(whiteboardProvider.notifier).fetchShareClassMembers(
              classId: cid,
              sectionIds: _selectedSectionIds.toList(),
            );
    if (!mounted) return;
    final students = res['students'] ?? [];
    final teachers = res['teachers'] ?? [];
    setState(() {
      _classStudents = students;
      _classTeachers = teachers;
      _checkedMemberIds.clear();
      if (_includeStudents) {
        for (final s in students) {
          final id = (s['id'] ?? '').toString();
          if (id.isNotEmpty) _checkedMemberIds.add(id);
        }
      }
      if (_includeTeachers) {
        for (final t in teachers) {
          final id = (t['id'] ?? '').toString();
          if (id.isNotEmpty) _checkedMemberIds.add(id);
        }
      }
      _loadingMembers = false;
    });
  }

  Future<void> _runIndividualSearch() async {
    setState(() => _searchingIndividuals = true);
    final users = await ref.read(whiteboardProvider.notifier).searchShareUsers(
          query: _individualSearchCtrl.text.trim(),
          roleFilter: _individualRoleFilter,
          limit: 60,
        );
    if (mounted) {
      setState(() {
        _searchResults = users;
        _searchingIndividuals = false;
      });
    }
  }

  void _onIndividualSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce =
        Timer(const Duration(milliseconds: 250), _runIndividualSearch);
  }

  Future<void> _loadShares() async {
    final shares = await ref
        .read(whiteboardProvider.notifier)
        .listBoardShares(widget.whiteboardId);
    if (mounted) {
      setState(() {
        _existingShares = shares;
        _loadingShares = false;
      });
    }
  }

  void _applyAccessLevelPreset(String level) {
    setState(() {
      _accessLevel = level;
      if (level == 'VIEW') {
        _capDraw = false;
        _capNotes = false;
        _capExport = true;
        _capManagePages = false;
      } else if (level == 'ANNOTATE') {
        _capDraw = true;
        _capNotes = true;
        _capExport = true;
        _capManagePages = false;
      } else {
        _capDraw = true;
        _capNotes = true;
        _capExport = true;
        _capManagePages = true;
      }
    });
  }

  List<Map<String, dynamic>> get _selectedClassSections {
    if (_selectedClassId == null) return const [];
    final cls = _classes
        .where((c) => c['id']?.toString() == _selectedClassId)
        .firstOrNull;
    if (cls == null) return const [];
    return (cls['sections'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  List<Map<String, dynamic>> get _visibleClassMembers {
    final filter = _memberFilterCtrl.text.trim().toLowerCase();
    final combined = <Map<String, dynamic>>[];
    if (_includeTeachers) {
      for (final t in _classTeachers) {
        combined.add({...t, '_kind': 'teacher'});
      }
    }
    if (_includeStudents) {
      for (final s in _classStudents) {
        combined.add({...s, '_kind': 'student'});
      }
    }
    if (filter.isEmpty) return combined;
    return combined.where((m) {
      final name = (m['full_name'] ?? '').toString().toLowerCase();
      final email = (m['email'] ?? '').toString().toLowerCase();
      final sec = (m['section_name'] ?? '').toString().toLowerCase();
      final extra = (m['assignment_label'] ?? m['roll_number'] ?? '')
          .toString()
          .toLowerCase();
      return name.contains(filter) ||
          email.contains(filter) ||
          sec.contains(filter) ||
          extra.contains(filter);
    }).toList();
  }

  Future<void> _submitShare() async {
    setState(() => _isSubmitting = true);
    final caps = {
      'can_view': true,
      'can_draw': _capDraw,
      'can_add_notes': _capNotes,
      'can_export': _capExport,
      'can_manage_pages': _capManagePages,
    };

    Map<String, dynamic>? result;
    if (_mode == 'class_sections') {
      final cls = _classes
          .where((c) => c['id']?.toString() == _selectedClassId)
          .firstOrNull;
      if (cls == null) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a class first.')));
        return;
      }
      final pickedSections = _selectedClassSections
          .where((s) => _selectedSectionIds.contains(s['id']?.toString()))
          .map((s) => {'id': s['id'], 'name': s['name']})
          .toList();

      final checkedUsers = <Map<String, dynamic>>[];
      for (final m in _visibleClassMembers) {
        final uid = (m['id'] ?? '').toString();
        if (uid.isNotEmpty && _checkedMemberIds.contains(uid)) {
          checkedUsers.add({
            'id': uid,
            'name': m['full_name'] ?? 'Member',
            'role':
                m['role'] ?? (m['_kind'] == 'teacher' ? 'teacher' : 'student'),
          });
        }
      }

      result = await ref.read(whiteboardProvider.notifier).shareBoardBatch(
            whiteboardId: widget.whiteboardId,
            mode: 'class_sections',
            classId: cls['id']?.toString(),
            className: cls['name']?.toString(),
            sections: pickedSections,
            includeStudents: _includeStudents,
            includeTeachers: _includeTeachers,
            users: checkedUsers,
            accessLevel: _accessLevel,
            capabilities: caps,
          );
    } else if (_mode == 'individual') {
      if (_selectedIndividuals.isEmpty) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Please select one or more individuals from the search list.')),
        );
        return;
      }
      final userPayloads = _selectedIndividuals.values.map((u) {
        final role = (u['role'] ?? 'student').toString();
        final cls = (u['class_name'] ?? '').toString();
        final sec = (u['section_name'] ?? '').toString();
        final dept = (u['department'] ?? '').toString();
        final label = cls.isNotEmpty
            ? (sec.isNotEmpty ? '$cls - $sec' : cls)
            : (dept.isNotEmpty ? '$role • $dept' : role);
        return {
          'id': u['id'],
          'name': u['full_name'] ?? 'User',
          'role': role,
          'label': label,
        };
      }).toList();

      result = await ref.read(whiteboardProvider.notifier).shareBoardBatch(
            whiteboardId: widget.whiteboardId,
            mode: 'individual',
            users: userPayloads,
            accessLevel: _accessLevel,
            capabilities: caps,
          );
    } else {
      result = await ref.read(whiteboardProvider.notifier).shareBoardBatch(
            whiteboardId: widget.whiteboardId,
            mode: 'link',
            targetLabel: _linkLabelCtrl.text.trim().isEmpty
                ? 'Authorized Institutional Link'
                : _linkLabelCtrl.text.trim(),
            accessLevel: _accessLevel,
            capabilities: caps,
          );
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (result != null) {
      final created = (result['shares'] as List<WhiteboardShareItem>?) ?? [];
      final grantedCount =
          (result['granted_users_count'] as num?)?.toInt() ?? 0;
      setState(() {
        _lastCreatedShares = created;
        if (_mode == 'individual') _selectedIndividuals.clear();
      });
      await _loadShares();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              grantedCount > 0
                  ? 'Shared board cleanly ($grantedCount user permission(s) synced with $_accessLevel access)!'
                  : 'Shared board link created ($_accessLevel)!',
            ),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Failed to share board. Please verify network/permissions.'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final menuBg = isDark ? const Color(0xFF1E2235) : Colors.white;
    final cardBg = isDark ? const Color(0xFF13182C) : const Color(0xFFF8FAFC);
    final borderColor =
        isDark ? const Color(0xFF2E3852) : const Color(0xFFE2E8F0);
    final textPrimary =
        isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final boardName = widget.boardTitle ??
        ref.read(whiteboardProvider).document?.title ??
        'Whiteboard';
    final screenW = MediaQuery.of(context).size.width;
    final dialogW = screenW < 720 ? screenW * 0.92 : 660.0;

    return AlertDialog(
      backgroundColor: menuBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1.2),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.share_rounded,
                color: Color(0xFF2563EB), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Share Whiteboard',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textPrimary)),
                Text(boardName,
                    style: TextStyle(fontSize: 11.5, color: textSecondary),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogW,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Share Mode Selector (No manual label entry required!)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    _modeTab('class_sections', Icons.account_tree_outlined,
                        'Class & Sections', textPrimary, textSecondary),
                    _modeTab('individual', Icons.person_search_rounded,
                        'Search Individuals', textPrimary, textSecondary),
                    _modeTab('link', Icons.link_rounded, 'Share Link',
                        textPrimary, textSecondary),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (_mode == 'class_sections')
                _buildClassSectionsPane(isDark, menuBg, cardBg, borderColor,
                    textPrimary, textSecondary)
              else if (_mode == 'individual')
                _buildIndividualSearchPane(
                    isDark, cardBg, borderColor, textPrimary, textSecondary)
              else
                _buildLinkPane(cardBg, borderColor, textPrimary),

              const SizedBox(height: 14),
              // Access Level + Capabilities ("What they can do")
              _buildAccessLevelAndCapabilitiesPane(
                  isDark, cardBg, borderColor, textPrimary, textSecondary),

              if (_lastCreatedShares.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF065F46).withValues(alpha: 0.28)
                        : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: isDark
                            ? const Color(0xFF059669)
                            : const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 16, color: Color(0xFF16A34A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Latest Token: ${_lastCreatedShares.first.shareToken} (${_lastCreatedShares.length} entry added)',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFF86EFAC)
                                  : const Color(0xFF166534)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy Token',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.copy, size: 15),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(
                              text: _lastCreatedShares.first.shareToken));
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Share token copied!')));
                        },
                      ),
                    ],
                  ),
                ),
              ],

              if (!_loadingShares && _existingShares.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('Active Shares (${_existingShares.length})',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textSecondary)),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _existingShares.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 5),
                    itemBuilder: (_, idx) {
                      final sh = _existingShares[idx];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${sh.targetLabel} (${sh.shareType})',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary),
                                      overflow: TextOverflow.ellipsis),
                                  Text('${sh.accessLevel} • ${sh.shareToken}',
                                      style: TextStyle(
                                          fontSize: 10.5, color: textSecondary),
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Copy Token',
                              visualDensity: VisualDensity.compact,
                              icon: Icon(Icons.copy,
                                  size: 14, color: textSecondary),
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: sh.shareToken));
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Share token copied!')));
                              },
                            ),
                            IconButton(
                              tooltip: 'Revoke Access',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.delete_outline,
                                  size: 15, color: Colors.red),
                              onPressed: () async {
                                final ok = await ref
                                    .read(whiteboardProvider.notifier)
                                    .revokeBoardShare(
                                        sh.id, widget.whiteboardId);
                                if (ok) _loadShares();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: Text('Close', style: TextStyle(color: textSecondary)),
        ),
        ElevatedButton.icon(
          icon: _isSubmitting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_rounded, size: 15),
          label: Text(_isSubmitting ? 'Sharing...' : 'Share & Assign Access'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isSubmitting ? null : _submitShare,
        ),
      ],
    );
  }

  Widget _modeTab(String modeKey, IconData icon, String label,
      Color textPrimary, Color textSecondary) {
    final active = _mode == modeKey;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _mode = modeKey),
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF2563EB) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14, color: active ? Colors.white : textSecondary),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: active ? FontWeight.bold : FontWeight.w500,
                    color: active ? Colors.white : textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassSectionsPane(
    bool isDark,
    Color menuBg,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (_loadingClasses) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_classes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor)),
        child: Text('No classes found in Class Management.',
            style: TextStyle(fontSize: 12, color: textSecondary)),
      );
    }

    final sections = _selectedClassSections;
    final visibleMembers = _visibleClassMembers;
    final selectedVisibleCount = visibleMembers
        .where((m) => _checkedMemberIds.contains((m['id'] ?? '').toString()))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step 1: Class Dropdown
        AppSearchableDropdownFormField<String>.fromMenuItems(
          initialValue: _selectedClassId,
          dropdownColor: menuBg,
          style: TextStyle(fontSize: 13, color: textPrimary),
          decoration: InputDecoration(
            labelText: '1. Select Class',
            labelStyle: TextStyle(color: textSecondary, fontSize: 12),
            filled: true,
            fillColor: cardBg,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor)),
          ),
          items: _classes.map((c) {
            final cid = c['id'].toString();
            final cname = (c['name'] ?? '').toString();
            final scount = (c['students_count'] as num?)?.toInt() ?? 0;
            final secLen = (c['sections'] as List? ?? []).length;
            return DropdownMenuItem(
              value: cid,
              child: Text('$cname  ($secLen sections • $scount students)',
                  style: TextStyle(fontSize: 12.5, color: textPrimary)),
            );
          }).toList(),
          onChanged: (val) async {
            if (val == null || val == _selectedClassId) return;
            setState(() {
              _selectedClassId = val;
              _selectedSectionIds.clear();
            });
            await _loadMembersForSelectedClass();
          },
        ),
        const SizedBox(height: 10),

        // Step 2: Multi-Select Sections
        Row(
          children: [
            Text('2. Select Section(s)',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: textSecondary)),
            const Spacer(),
            Text(
              _selectedSectionIds.isEmpty
                  ? 'All sections included'
                  : '${_selectedSectionIds.length} section(s) selected',
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            FilterChip(
              label: Text('All Sections',
                  style: TextStyle(
                      fontSize: 11,
                      color: _selectedSectionIds.isEmpty
                          ? Colors.white
                          : textPrimary)),
              selected: _selectedSectionIds.isEmpty,
              selectedColor: const Color(0xFF2563EB),
              backgroundColor: cardBg,
              checkmarkColor: Colors.white,
              onSelected: (_) async {
                setState(() => _selectedSectionIds.clear());
                await _loadMembersForSelectedClass();
              },
            ),
            for (final sec in sections)
              () {
                final sid = sec['id'].toString();
                final sname = (sec['name'] ?? '').toString();
                final scnt = (sec['students_count'] as num?)?.toInt() ?? 0;
                final isSel = _selectedSectionIds.contains(sid);
                return FilterChip(
                  label: Text('$sname ($scnt)',
                      style: TextStyle(
                          fontSize: 11,
                          color: isSel ? Colors.white : textPrimary)),
                  selected: isSel,
                  selectedColor: const Color(0xFF2563EB),
                  backgroundColor: cardBg,
                  checkmarkColor: Colors.white,
                  onSelected: (checked) async {
                    setState(() {
                      if (checked) {
                        _selectedSectionIds.add(sid);
                      } else {
                        _selectedSectionIds.remove(sid);
                      }
                    });
                    await _loadMembersForSelectedClass();
                  },
                );
              }(),
          ],
        ),
        const SizedBox(height: 10),

        // Step 3: Students & Teachers inside selected Class/Sections
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            Text('3. Class & Section Members',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: textSecondary)),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                FilterChip(
                  label: Text('Teachers (${_classTeachers.length})',
                      style: TextStyle(
                          fontSize: 10.5,
                          color:
                              _includeTeachers ? Colors.white : textPrimary)),
                  selected: _includeTeachers,
                  selectedColor: const Color(0xFF10B981),
                  backgroundColor: cardBg,
                  checkmarkColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  onSelected: (v) {
                    setState(() {
                      _includeTeachers = v;
                      for (final t in _classTeachers) {
                        final id = (t['id'] ?? '').toString();
                        if (v) {
                          _checkedMemberIds.add(id);
                        } else {
                          _checkedMemberIds.remove(id);
                        }
                      }
                    });
                  },
                ),
                FilterChip(
                  label: Text('Students (${_classStudents.length})',
                      style: TextStyle(
                          fontSize: 10.5,
                          color:
                              _includeStudents ? Colors.white : textPrimary)),
                  selected: _includeStudents,
                  selectedColor: const Color(0xFF2563EB),
                  backgroundColor: cardBg,
                  checkmarkColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  onSelected: (v) {
                    setState(() {
                      _includeStudents = v;
                      for (final s in _classStudents) {
                        final id = (s['id'] ?? '').toString();
                        if (v) {
                          _checkedMemberIds.add(id);
                        } else {
                          _checkedMemberIds.remove(id);
                        }
                      }
                    });
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _memberFilterCtrl,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(fontSize: 12, color: textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Filter members in selected section(s)...',
                          hintStyle:
                              TextStyle(fontSize: 11, color: textSecondary),
                          prefixIcon: Icon(Icons.search,
                              size: 15, color: textSecondary),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(7),
                              borderSide: BorderSide(color: borderColor)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          for (final m in visibleMembers) {
                            final id = (m['id'] ?? '').toString();
                            if (id.isNotEmpty) _checkedMemberIds.add(id);
                          }
                        });
                      },
                      child: const Text('All', style: TextStyle(fontSize: 11)),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          for (final m in visibleMembers) {
                            _checkedMemberIds
                                .remove((m['id'] ?? '').toString());
                          }
                        });
                      },
                      child: const Text('None', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$selectedVisibleCount of ${visibleMembers.length} recipient(s) selected',
                    style: TextStyle(
                        fontSize: 10.5,
                        color: textSecondary,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (_loadingMembers)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child:
                      Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (visibleMembers.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                      'No teachers or students match the selected section filters.',
                      style: TextStyle(fontSize: 11.5, color: textSecondary)),
                )
              else
                Material(
                  type: MaterialType.transparency,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 165),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: visibleMembers.length,
                      itemBuilder: (_, idx) {
                        final m = visibleMembers[idx];
                        final uid = (m['id'] ?? '').toString();
                        final isTeacher = m['_kind'] == 'teacher';
                        final checked = _checkedMemberIds.contains(uid);
                        final subInfo = isTeacher
                            ? '${m['assignment_label'] ?? 'Teacher'} • ${m['section_name'] ?? ''}'
                            : 'Student • ${m['section_name'] ?? ''} ${m['roll_number']?.toString().isNotEmpty == true ? '• Roll ${m['roll_number']}' : ''}';
                        return CheckboxListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          value: checked,
                          activeColor: const Color(0xFF2563EB),
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _checkedMemberIds.add(uid);
                              } else {
                                _checkedMemberIds.remove(uid);
                              }
                            });
                          },
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  (m['full_name'] ?? 'Member').toString(),
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: (isTeacher
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFF2563EB))
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isTeacher ? 'Teacher' : 'Student',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: isTeacher
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF3B82F6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(subInfo,
                              style: TextStyle(
                                  fontSize: 10.5, color: textSecondary),
                              overflow: TextOverflow.ellipsis),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIndividualSearchPane(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _individualSearchCtrl,
          onChanged: _onIndividualSearchChanged,
          style: TextStyle(fontSize: 13, color: textPrimary),
          decoration: InputDecoration(
            hintText:
                'Search student or teacher by name, email, roll no, or employee ID...',
            hintStyle: TextStyle(fontSize: 11.5, color: textSecondary),
            prefixIcon: Icon(Icons.person_search_rounded,
                size: 18, color: textSecondary),
            suffixIcon: _individualSearchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear_rounded,
                        size: 16, color: textSecondary),
                    onPressed: () {
                      _individualSearchCtrl.clear();
                      _runIndividualSearch();
                    },
                  )
                : null,
            filled: true,
            fillColor: cardBg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor)),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final rf in const [
                  ('all', 'All Users'),
                  ('teacher', 'Teachers / Staff'),
                  ('student', 'Students')
                ])
                  ChoiceChip(
                    label: Text(rf.$2,
                        style: TextStyle(
                            fontSize: 11,
                            color: _individualRoleFilter == rf.$1
                                ? Colors.white
                                : textPrimary)),
                    selected: _individualRoleFilter == rf.$1,
                    selectedColor: const Color(0xFF2563EB),
                    backgroundColor: cardBg,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) {
                      setState(() => _individualRoleFilter = rf.$1);
                      _runIndividualSearch();
                    },
                  ),
              ],
            ),
            Text('${_selectedIndividuals.length} selected',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB))),
          ],
        ),
        if (_selectedIndividuals.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB)
                  .withValues(alpha: isDark ? 0.16 : 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.35)),
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _selectedIndividuals.entries.map((entry) {
                final u = entry.value;
                return InputChip(
                  label: Text('${u['full_name'] ?? 'User'}',
                      style: TextStyle(fontSize: 11, color: textPrimary)),
                  deleteIconColor: textSecondary,
                  onDeleted: () =>
                      setState(() => _selectedIndividuals.remove(entry.key)),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: _searchingIndividuals
              ? const Padding(
                  padding: EdgeInsets.all(18),
                  child:
                      Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : _searchResults.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                          child: Text('No matching users found.',
                              style: TextStyle(
                                  fontSize: 12, color: textSecondary))),
                    )
                  : Material(
                      type: MaterialType.transparency,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 195),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          itemBuilder: (_, idx) {
                            final u = _searchResults[idx];
                            final uid = (u['id'] ?? '').toString();
                            final selected =
                                _selectedIndividuals.containsKey(uid);
                            final role = (u['role'] ?? 'student')
                                .toString()
                                .toLowerCase();
                            final isTeacher = role != 'student';
                            final cls = (u['class_name'] ?? '').toString();
                            final sec = (u['section_name'] ?? '').toString();
                            final email = (u['email'] ?? '').toString();
                            final sub = cls.isNotEmpty
                                ? '$cls${sec.isNotEmpty ? ' - $sec' : ''} • $email'
                                : '${u['department']?.toString().isNotEmpty == true ? '${u['department']} • ' : ''}$email';

                            return CheckboxListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              value: selected,
                              activeColor: const Color(0xFF2563EB),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedIndividuals[uid] = u;
                                  } else {
                                    _selectedIndividuals.remove(uid);
                                  }
                                });
                              },
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      (u['full_name'] ?? 'User').toString(),
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: (isTeacher
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFF2563EB))
                                          .withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      role.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: isTeacher
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFF3B82F6),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(sub,
                                  style: TextStyle(
                                      fontSize: 10.5, color: textSecondary),
                                  overflow: TextOverflow.ellipsis),
                            );
                          },
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildLinkPane(Color cardBg, Color borderColor, Color textPrimary) {
    return TextField(
      controller: _linkLabelCtrl,
      style: TextStyle(fontSize: 13, color: textPrimary),
      decoration: InputDecoration(
        labelText: 'Share Link Name / Label',
        filled: true,
        fillColor: cardBg,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: borderColor)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: borderColor)),
      ),
    );
  }

  Widget _buildAccessLevelAndCapabilitiesPane(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Level of Access & What Recipients Can Do',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textPrimary)),
          const SizedBox(height: 8),
          Row(
            children: [
              _accessPresetCard(
                  'VIEW',
                  Icons.visibility_outlined,
                  'View Only',
                  'Read pages',
                  isDark,
                  borderColor,
                  textPrimary,
                  textSecondary),
              const SizedBox(width: 6),
              _accessPresetCard(
                  'ANNOTATE',
                  Icons.rate_review_outlined,
                  'Annotate',
                  'Notes & draw',
                  isDark,
                  borderColor,
                  textPrimary,
                  textSecondary),
              const SizedBox(width: 6),
              _accessPresetCard(
                  'EDIT',
                  Icons.edit_rounded,
                  'Full Edit',
                  'Full board edit',
                  isDark,
                  borderColor,
                  textPrimary,
                  textSecondary),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _capabilityChip('View Board', true, null, textPrimary),
              _capabilityChip(
                'Draw & Shapes',
                _capDraw,
                (v) => setState(() {
                  _capDraw = v;
                  if (v && _accessLevel == 'VIEW') _accessLevel = 'ANNOTATE';
                }),
                textPrimary,
              ),
              _capabilityChip(
                'Sticky Notes & Comments',
                _capNotes,
                (v) => setState(() {
                  _capNotes = v;
                  if (v && _accessLevel == 'VIEW') _accessLevel = 'ANNOTATE';
                }),
                textPrimary,
              ),
              _capabilityChip(
                'Export PDF / PNG',
                _capExport,
                (v) => setState(() => _capExport = v),
                textPrimary,
              ),
              _capabilityChip(
                'Manage Pages',
                _capManagePages,
                (v) => setState(() {
                  _capManagePages = v;
                  if (v) _accessLevel = 'EDIT';
                }),
                textPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _accessPresetCard(
    String value,
    IconData icon,
    String title,
    String subtitle,
    bool isDark,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final active = _accessLevel == value;
    return Expanded(
      child: InkWell(
        onTap: () => _applyAccessLevelPreset(value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: active ? const Color(0xFF2563EB) : borderColor,
                width: active ? 1.6 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon,
                      size: 14,
                      color: active ? const Color(0xFF2563EB) : textSecondary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      title,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color:
                              active ? const Color(0xFF2563EB) : textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(fontSize: 10, color: textSecondary),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  Widget _capabilityChip(String label, bool enabled,
      ValueChanged<bool>? onToggle, Color textPrimary) {
    return FilterChip(
      label: Text(label,
          style: TextStyle(
              fontSize: 10.5, color: enabled ? Colors.white : textPrimary)),
      selected: enabled,
      selectedColor: const Color(0xFF2563EB),
      checkmarkColor: Colors.white,
      visualDensity: VisualDensity.compact,
      onSelected: onToggle,
    );
  }
}

class WhiteboardExportDialog extends ConsumerStatefulWidget {
  final String? whiteboardId;
  final String? boardTitle;

  const WhiteboardExportDialog({
    super.key,
    this.whiteboardId,
    this.boardTitle,
  });

  @override
  ConsumerState<WhiteboardExportDialog> createState() =>
      _WhiteboardExportDialogState();
}

class _WhiteboardExportDialogState
    extends ConsumerState<WhiteboardExportDialog> {
  String _format = 'PDF';
  String _scope = 'all_pages';
  String _orientation = 'landscape';
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final menuBg = isDark ? const Color(0xFF1E2235) : Colors.white;
    final textPrimary =
        isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.download_rounded, color: Color(0xFF2563EB)),
          SizedBox(width: 8),
          Text('Export Whiteboard Notes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSearchableDropdownFormField<String>.fromMenuItems(
              initialValue: _format,
              dropdownColor: menuBg,
              style: TextStyle(fontSize: 13, color: textPrimary),
              decoration: InputDecoration(
                labelText: 'Export Format',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: [
                DropdownMenuItem(
                    value: 'PDF',
                    child: Text('Multi-Page Vector PDF (.pdf)',
                        style: TextStyle(color: textPrimary))),
                DropdownMenuItem(
                    value: 'PNG',
                    child: Text('High-Resolution Image (.png)',
                        style: TextStyle(color: textPrimary))),
                DropdownMenuItem(
                    value: 'JPEG',
                    child: Text('Compressed Image (.jpg)',
                        style: TextStyle(color: textPrimary))),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _format = v);
              },
            ),
            const SizedBox(height: 12),
            AppSearchableDropdownFormField<String>.fromMenuItems(
              initialValue: _scope,
              dropdownColor: menuBg,
              style: TextStyle(fontSize: 13, color: textPrimary),
              decoration: InputDecoration(
                labelText: 'Pages Scope',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: [
                DropdownMenuItem(
                    value: 'all_pages',
                    child: Text('All Whiteboard Pages',
                        style: TextStyle(color: textPrimary))),
                DropdownMenuItem(
                    value: 'current_page',
                    child: Text('Current Active Page Only',
                        style: TextStyle(color: textPrimary))),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _scope = v);
              },
            ),
            if (_format == 'PDF') ...[
              const SizedBox(height: 12),
              AppSearchableDropdownFormField<String>.fromMenuItems(
                initialValue: _orientation,
                dropdownColor: menuBg,
                style: TextStyle(fontSize: 13, color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Page Orientation',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                items: [
                  DropdownMenuItem(
                      value: 'landscape',
                      child: Text('Landscape (Widescreen)',
                          style: TextStyle(color: textPrimary))),
                  DropdownMenuItem(
                      value: 'portrait',
                      child: Text('Portrait (A4 Document)',
                          style: TextStyle(color: textPrimary))),
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
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton.icon(
          icon: _isExporting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.file_download_outlined, size: 16),
          label: Text(_isExporting ? 'Exporting...' : 'Download $_format'),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white),
          onPressed: _isExporting
              ? null
              : () async {
                  setState(() => _isExporting = true);
                  final res =
                      await ref.read(whiteboardProvider.notifier).exportBoard(
                            whiteboardId: widget.whiteboardId,
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
                      final uri = Uri.parse(
                          '${AppConfig.baseUrl}$dlPath?token=${Uri.encodeQueryComponent(token)}');
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Exported $_format successfully (${res['size_bytes']} bytes)')),
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
          Text('Classroom Whiteboard Permissions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Enable Real-Time Student Collaboration',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: const Text(
                  'Allow students to participate live when permitted',
                  style: TextStyle(fontSize: 11)),
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
                notifier.updateParticipantPermission(
                    targetRole: 'student', permissionType: v ? 'EDIT' : 'VIEW');
              },
            ),
            SwitchListTile(
              title: const Text('Presentation Mode (Hide Student Controls)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: const Text(
                  'Keep students focused on teacher board without edit tools',
                  style: TextStyle(fontSize: 11)),
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
                  notifier.updateParticipantPermission(
                      targetRole: 'student', permissionType: 'VIEW');
                }
              },
            ),
            SwitchListTile(
              title: const Text('Allow Students to Draw & Solve Equations',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
                notifier.updateParticipantPermission(
                    targetRole: 'student', permissionType: v ? 'EDIT' : 'VIEW');
              },
            ),
            if (s.activePage != null)
              SwitchListTile(
                title: Text('Lock "${s.activePage!.title}" Page',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text(
                    'Prevent student edits on the current board page',
                    style: TextStyle(fontSize: 11)),
                value: s.activePage!.isLocked,
                onChanged: (_) => notifier.togglePageLock(s.activePage!.id),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Done')),
      ],
    );
  }
}

class WhiteboardAssetDialog extends ConsumerStatefulWidget {
  const WhiteboardAssetDialog({super.key});

  @override
  ConsumerState<WhiteboardAssetDialog> createState() =>
      _WhiteboardAssetDialogState();
}

class _WhiteboardAssetDialogState extends ConsumerState<WhiteboardAssetDialog>
    with SingleTickerProviderStateMixin {
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
      'url':
          'https://upload.wikimedia.org/wikipedia/commons/thumb/6/6f/Benzene_representations.svg/500px-Benzene_representations.svg.png',
    },
    {
      'title': 'Animal Cell Organelles',
      'category': 'Biology & Cytology',
      'icon': '🧬',
      'url':
          'https://upload.wikimedia.org/wikipedia/commons/thumb/4/48/Animal_cell_structure_en.svg/500px-Animal_cell_structure_en.svg.png',
    },
    {
      'title': 'Electric Circuit Diagram',
      'category': 'Physics & Electromagnetism',
      'icon': '⚡',
      'url':
          'https://upload.wikimedia.org/wikipedia/commons/thumb/c/cd/Circuit_diagram_example.svg/500px-Circuit_diagram_example.svg.png',
    },
    {
      'title': 'Trig Unit Circle (Radians & Deg)',
      'category': 'Mathematics',
      'icon': '📐',
      'url':
          'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4c/Unit_circle_angles_color.svg/500px-Unit_circle_angles_color.svg.png',
    },
    {
      'title': 'World Map & Climate Zones',
      'category': 'Geography',
      'icon': '🌐',
      'url':
          'https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/World_map_-_low_resolution.svg/500px-World_map_-_low_resolution.svg.png',
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
        allowedExtensions: [
          'png',
          'jpg',
          'jpeg',
          'webp',
          'gif',
          'bmp',
          'svg',
          'pdf',
          'ppt',
          'pptx'
        ],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() =>
            _status = 'Could not read file data. Please try another file.');
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

    final res =
        await ref.read(whiteboardProvider.notifier).uploadAndInsertAsset(
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
        setState(
            () => _status = 'Upload failed. Please check network/file type.');
      }
    }
  }

  Future<void> _insertFromUrl() async {
    final rawUrl = _urlCtrl.text.trim();
    if (rawUrl.isEmpty) {
      setState(() => _status = 'Please enter a valid image URL.');
      return;
    }

    final title = _titleCtrl.text.trim().isNotEmpty
        ? _titleCtrl.text.trim()
        : 'Web Image';
    await ref
        .read(whiteboardProvider.notifier)
        .insertImageUrl(url: rawUrl, title: title);

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
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary =
        isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    const accentBlue = Color(0xFF2563EB);

    final isImg = _selectedFile != null &&
        ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp']
            .contains(_selectedFile!.extension?.toLowerCase());

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor)),
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
                    child: const Icon(Icons.add_photo_alternate_rounded,
                        color: accentBlue, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Insert Image, PDF or Slides',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textPrimary),
                        ),
                        Text(
                          'Supported: PNG, JPG, WebP, PDF, PPTX (Max 25 MB)',
                          style: TextStyle(fontSize: 11, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        size: 18, color: textSecondary),
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
                  labelStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
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
                                padding: const EdgeInsets.symmetric(
                                    vertical: 28, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: accentBlue.withValues(alpha: 0.4),
                                      width: 1.5),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color:
                                            accentBlue.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                          Icons.cloud_upload_outlined,
                                          color: accentBlue,
                                          size: 28),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Click to browse or choose an image / document',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'PNG, JPG, WebP, GIF, SVG, PDF, PowerPoint up to 25 MB',
                                      style: TextStyle(
                                          fontSize: 11, color: textSecondary),
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
                                        color: isDark
                                            ? const Color(0xFF0F172A)
                                            : Colors.white,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.memory(_fileBytes!,
                                            fit: BoxFit.contain),
                                      ),
                                    )
                                  else
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _selectedFile!.extension
                                                        ?.toLowerCase() ==
                                                    'pdf'
                                                ? Icons.picture_as_pdf_rounded
                                                : Icons.description_rounded,
                                            size: 36,
                                            color: Colors.redAccent,
                                          ),
                                          const SizedBox(width: 10),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _selectedFile!.name,
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: textPrimary),
                                              ),
                                              Text(
                                                _formatFileSize(
                                                    _selectedFile!.size),
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: textSecondary),
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
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: textSecondary),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      TextButton.icon(
                                        icon: const Icon(Icons.refresh_rounded,
                                            size: 14),
                                        label: const Text('Change',
                                            style: TextStyle(fontSize: 11)),
                                        onPressed:
                                            _uploading ? null : _pickFile,
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
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary),
                              ),
                              value: _importPdfPages,
                              activeThumbColor: accentBlue,
                              onChanged: (v) =>
                                  setState(() => _importPdfPages = v),
                            ),
                          if (_uploading) ...[
                            const SizedBox(height: 10),
                            const LinearProgressIndicator(
                                color: accentBlue, minHeight: 4),
                          ],
                          if (_status != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _status!,
                              style: TextStyle(
                                fontSize: 11,
                                color: _status!.contains('failed') ||
                                        _status!.contains('error')
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
                          Text('Direct Image Web URL:',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textSecondary)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _urlCtrl,
                            style: TextStyle(fontSize: 12, color: textPrimary),
                            decoration: InputDecoration(
                              hintText: 'https://example.com/diagram.png',
                              hintStyle: TextStyle(
                                  fontSize: 12,
                                  color: textSecondary.withValues(alpha: 0.6)),
                              prefixIcon:
                                  const Icon(Icons.link_rounded, size: 16),
                              filled: true,
                              fillColor: cardBg,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: borderColor)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: borderColor)),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 10),
                          Text('Optional Label / Title:',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textSecondary)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _titleCtrl,
                            style: TextStyle(fontSize: 12, color: textPrimary),
                            decoration: InputDecoration(
                              hintText: 'e.g. Physics Formula Diagram',
                              hintStyle: TextStyle(
                                  fontSize: 12,
                                  color: textSecondary.withValues(alpha: 0.6)),
                              prefixIcon:
                                  const Icon(Icons.title_rounded, size: 16),
                              filled: true,
                              fillColor: cardBg,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: borderColor)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: borderColor)),
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
                                      style: TextStyle(
                                          fontSize: 11, color: textSecondary),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Text(p['icon']!,
                                    style: const TextStyle(fontSize: 22)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p['title']!,
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: textPrimary),
                                      ),
                                      Text(
                                        p['category']!,
                                        style: TextStyle(
                                            fontSize: 10, color: textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                FilledButton.tonal(
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () => _insertPreset(p),
                                  child: const Text('Insert',
                                      style: TextStyle(fontSize: 11)),
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
                    child:
                        Text('Cancel', style: TextStyle(color: textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  if (_tabController.index == 0)
                    ElevatedButton.icon(
                      icon: _uploading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.upload_file_rounded, size: 16),
                      label: Text(_uploading
                          ? 'Uploading...'
                          : (_selectedFile == null
                              ? 'Select & Upload'
                              : 'Insert onto Board')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
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
