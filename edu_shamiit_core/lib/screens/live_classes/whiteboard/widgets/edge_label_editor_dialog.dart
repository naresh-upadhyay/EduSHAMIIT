import 'package:flutter/material.dart';
import '../models/whiteboard_models.dart';

class EdgeLabelEditorDialog extends StatefulWidget {
  final WhiteboardObject edge;

  const EdgeLabelEditorDialog({
    super.key,
    required this.edge,
  });

  @override
  State<EdgeLabelEditorDialog> createState() => _EdgeLabelEditorDialogState();
}

class _EdgeLabelEditorDialogState extends State<EdgeLabelEditorDialog> {
  late TextEditingController _labelCtrl;
  late String _selectedType;
  late String _selectedStyle;
  late String _selectedColorHex;

  static const _relationshipPresets = <String, List<String>>{
    'Flow & Causality': ['leads to', 'causes', 'yields', 'results in', 'produces'],
    'Hierarchy & Structure': ['part of', 'derived from', 'subtopic of', 'comprises'],
    'Logic & Reasoning': ['supports', 'applies to', 'depends on', 'proves', 'inhibits', 'connects to'],
  };

  static const _palette = <String>[
    '#2563EB', // Blue
    '#0EA5E9', // Sky
    '#10B981', // Emerald
    '#059669', // Forest
    '#F59E0B', // Amber
    '#EA580C', // Orange
    '#8B5CF6', // Purple
    '#EC4899', // Pink
    '#EF4444', // Red
    '#64748B', // Slate
  ];

  @override
  void initState() {
    super.initState();
    final existingLabel = (widget.edge.data['label'] ?? widget.edge.data['text'] ?? '').toString();
    _labelCtrl = TextEditingController(text: existingLabel);
    _selectedType = widget.edge.type;
    _selectedStyle = (widget.edge.data['strokeStyle'] ?? 'solid').toString();
    _selectedColorHex = (widget.edge.data['color'] ?? '#2563EB').toString();
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final activeColor = WhiteboardColorHelper.parse(_selectedColorHex);

    return AlertDialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1.2),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.alt_route_rounded, color: Color(0xFF2563EB), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Edge Relationship & Label',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                ),
                Text(
                  'Label and style the connection between mind map entities',
                  style: TextStyle(fontSize: 11.5, color: textSecondary),
                ),
              ],
            ),
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
              // 1. Live Visual Preview Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    Text(
                      'LIVE EDGE PREVIEW',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Entity A box
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.5)),
                          ),
                          child: Text('Topic A', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textPrimary)),
                        ),
                        // Dynamic Edge with Badge
                        Expanded(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Line
                              CustomPaint(
                                size: const Size(double.infinity, 24),
                                painter: _PreviewEdgePainter(
                                  color: activeColor,
                                  isDashed: _selectedStyle == 'dashed',
                                  isDoubleArrow: _selectedType == 'double_arrow',
                                  hasArrow: _selectedType == 'connector' || _selectedType == 'arrow',
                                ),
                              ),
                              // Badge
                              if (_labelCtrl.text.trim().isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: activeColor.withValues(alpha: 0.7), width: 1.2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    _labelCtrl.text.trim(),
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: activeColor),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Entity B box
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                          ),
                          child: Text('Topic B', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textPrimary)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Label Input Field with Clear Button
              Text('Relationship Label', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary)),
              const SizedBox(height: 6),
              TextField(
                controller: _labelCtrl,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'e.g. leads to, causes, yields, depends on...',
                  hintStyle: TextStyle(fontSize: 12.5, color: textSecondary),
                  filled: true,
                  fillColor: cardBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.6)),
                  suffixIcon: _labelCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 16, color: textSecondary),
                          onPressed: () => setState(() => _labelCtrl.clear()),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),

              // 3. 1-Click Relationship Presets
              Text('Quick Semantic Presets', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary)),
              const SizedBox(height: 6),
              for (final entry in _relationshipPresets.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, top: 2),
                  child: Text(entry.key, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textSecondary.withValues(alpha: 0.8))),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: entry.value.map((preset) {
                    final isSelected = _labelCtrl.text.trim().toLowerCase() == preset.toLowerCase();
                    return ActionChip(
                      label: Text(preset, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
                      backgroundColor: isSelected ? const Color(0xFF2563EB) : cardBg,
                      labelStyle: TextStyle(color: isSelected ? Colors.white : textPrimary),
                      side: BorderSide(color: isSelected ? const Color(0xFF2563EB) : borderColor),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _labelCtrl.text = preset),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 6),
              ],
              const SizedBox(height: 10),

              // 4. Direction & Arrow Style
              Text('Arrowhead & Direction', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: textPrimary)),
              const SizedBox(height: 6),
              Row(
                children: [
                  _styleOption(
                    title: 'Forward →',
                    selected: _selectedType == 'connector' || _selectedType == 'arrow',
                    isDark: isDark,
                    onTap: () => setState(() => _selectedType = 'connector'),
                  ),
                  const SizedBox(width: 8),
                  _styleOption(
                    title: 'Both ↔',
                    selected: _selectedType == 'double_arrow',
                    isDark: isDark,
                    onTap: () => setState(() => _selectedType = 'double_arrow'),
                  ),
                  const SizedBox(width: 8),
                  _styleOption(
                    title: 'Plain —',
                    selected: _selectedType == 'line' || _selectedType == 'curved_line',
                    isDark: isDark,
                    onTap: () => setState(() => _selectedType = 'curved_line'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 5. Stroke Pattern & Color Palette
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Line Style', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: textPrimary)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _styleOption(
                              title: 'Solid',
                              selected: _selectedStyle == 'solid',
                              isDark: isDark,
                              onTap: () => setState(() => _selectedStyle = 'solid'),
                            ),
                            const SizedBox(width: 6),
                            _styleOption(
                              title: 'Dashed',
                              selected: _selectedStyle == 'dashed',
                              isDark: isDark,
                              onTap: () => setState(() => _selectedStyle = 'dashed'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Edge Color', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: textPrimary)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _palette.map((hex) {
                            final c = WhiteboardColorHelper.parse(hex);
                            final isSel = _selectedColorHex.toUpperCase() == hex.toUpperCase();
                            return InkWell(
                              onTap: () => setState(() => _selectedColorHex = hex),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSel ? (isDark ? Colors.white : const Color(0xFF0F172A)) : Colors.transparent,
                                    width: 2.2,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (_labelCtrl.text.isNotEmpty)
          TextButton.icon(
            icon: const Icon(Icons.label_off_outlined, size: 15, color: Color(0xFFEF4444)),
            label: const Text('Remove Label', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
            onPressed: () {
              Navigator.pop(context, {
                'removeLabel': true,
                'type': _selectedType,
                'strokeStyle': _selectedStyle,
                'color': _selectedColorHex,
              });
            },
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: textSecondary)),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.check_rounded, size: 16),
          label: const Text('Apply Changes'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            Navigator.pop(context, {
              'label': _labelCtrl.text.trim(),
              'type': _selectedType,
              'strokeStyle': _selectedStyle,
              'color': _selectedColorHex,
            });
          },
        ),
      ],
    );
  }

  Widget _styleOption({
    required String title,
    required bool selected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2563EB).withValues(alpha: 0.15) : cardBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? const Color(0xFF2563EB) : borderColor,
            width: selected ? 1.6 : 1.0,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? const Color(0xFF2563EB) : textPrimary,
          ),
        ),
      ),
    );
  }
}

class _PreviewEdgePainter extends CustomPainter {
  final Color color;
  final bool isDashed;
  final bool hasArrow;
  final bool isDoubleArrow;

  const _PreviewEdgePainter({
    required this.color,
    required this.isDashed,
    required this.hasArrow,
    required this.isDoubleArrow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cy = size.height / 2;
    if (isDashed) {
      double cur = 6;
      while (cur < size.width - 6) {
        canvas.drawLine(Offset(cur, cy), Offset(cur + 6, cy), paint);
        cur += 11;
      }
    } else {
      canvas.drawLine(Offset(6, cy), Offset(size.width - 6, cy), paint);
    }

    if (hasArrow || isDoubleArrow) {
      final arr = Paint()
        ..color = color
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      // Forward arrow
      canvas.drawLine(Offset(size.width - 6, cy), Offset(size.width - 13, cy - 4), arr);
      canvas.drawLine(Offset(size.width - 6, cy), Offset(size.width - 13, cy + 4), arr);

      if (isDoubleArrow) {
        // Backward arrow
        canvas.drawLine(Offset(6, cy), Offset(13, cy - 4), arr);
        canvas.drawLine(Offset(6, cy), Offset(13, cy + 4), arr);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PreviewEdgePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.isDashed != isDashed ||
      oldDelegate.hasArrow != hasArrow ||
      oldDelegate.isDoubleArrow != isDoubleArrow;
}
