import 'package:flutter/material.dart';

class EquationEditorDialog extends StatefulWidget {
  final String? initialLatex;
  final String? initialBgHex;

  const EquationEditorDialog({
    super.key,
    this.initialLatex,
    this.initialBgHex,
  });

  @override
  State<EquationEditorDialog> createState() => _EquationEditorDialogState();
}

class _EquationEditorDialogState extends State<EquationEditorDialog> {
  late TextEditingController _ctrl;
  String _selectedBgHex = '#E0F2FE';

  static const _symbolGroups = <String, List<Map<String, String>>>{
    'Algebra & Ops': [
      {'label': 'a/b', 'insert': r'\frac{a}{b}'},
      {'label': 'x²', 'insert': '^2'},
      {'label': 'xⁿ', 'insert': '^{n}'},
      {'label': '√', 'insert': r'\sqrt{x}'},
      {'label': '∛', 'insert': '∛(x)'},
      {'label': '±', 'insert': '±'},
      {'label': '×', 'insert': '×'},
      {'label': '÷', 'insert': '÷'},
      {'label': '≠', 'insert': '≠'},
      {'label': '≤', 'insert': '≤'},
      {'label': '≥', 'insert': '≥'},
      {'label': '⇒', 'insert': '⇒'},
    ],
    'Calculus & Matrices': [
      {'label': '∫', 'insert': '∫'},
      {'label': '∫ab', 'insert': '∫_{a}^{b} '},
      {'label': 'dy/dx', 'insert': r'\frac{dy}{dx}'},
      {'label': '∂', 'insert': '∂'},
      {'label': 'lim', 'insert': 'lim_{x→0} '},
      {'label': '∑', 'insert': '∑_{i=1}^{n} '},
      {'label': '∞', 'insert': '∞'},
      {'label': '2×2 Matrix', 'insert': '[a  b ; c  d]'},
    ],
    'Greek & Trig/Log': [
      {'label': 'α', 'insert': 'α'},
      {'label': 'β', 'insert': 'β'},
      {'label': 'θ', 'insert': 'θ'},
      {'label': 'π', 'insert': 'π'},
      {'label': 'Δ', 'insert': 'Δ'},
      {'label': 'λ', 'insert': 'λ'},
      {'label': 'σ', 'insert': 'σ'},
      {'label': 'sin θ', 'insert': 'sin(θ)'},
      {'label': 'cos θ', 'insert': 'cos(θ)'},
      {'label': 'log', 'insert': 'log_{10}(x)'},
      {'label': 'ln', 'insert': 'ln(x)'},
    ],
  };

  static const _presets = <Map<String, String>>[
    {'label': 'Quadratic Formula', 'latex': r'x = \frac{-b ± \sqrt{b^2 - 4ac}}{2a}'},
    {'label': 'Standard Form', 'latex': 'ax² + bx + c = 0'},
    {'label': 'Discriminant', 'latex': 'D = b² - 4ac'},
    {'label': 'Pythagorean', 'latex': 'a² + b² = c²'},
    {'label': 'Derivative', 'latex': r'\frac{d}{dx}(x^n) = n x^{n-1}'},
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.initialLatex ?? r'x = \frac{-b ± \sqrt{b^2 - 4ac}}{2a}',
    );
    if (widget.initialBgHex != null) _selectedBgHex = widget.initialBgHex!;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _insertSnippet(String snippet) {
    final text = _ctrl.text;
    final sel = _ctrl.selection;
    final start = sel.start >= 0 ? sel.start : text.length;
    final end = sel.end >= 0 ? sel.end : text.length;
    final updated = text.replaceRange(start, end, snippet);
    setState(() {
      _ctrl.value = TextEditingValue(
        text: updated,
        selection: TextSelection.collapsed(offset: start + snippet.length),
      );
    });
  }

  String _formatReadablePreview(String raw) {
    return raw
        .replaceAll(r'\frac{', '(')
        .replaceAll('}{', ') / (')
        .replaceAll(r'\sqrt{', '√(')
        .replaceAll(r'\pm', '±')
        .replaceAll('^2', '²')
        .replaceAll('^3', '³')
        .replaceAll('}', ')');
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Color(int.parse(_selectedBgHex.replaceFirst('#', 'FF'), radix: 16));
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.functions_rounded, color: Color(0xFF2563EB)),
          SizedBox(width: 8),
          Text('Mathematical Equation Editor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Formula Presets
              const Text('Quick Formula Presets', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _presets.map((p) {
                  return ActionChip(
                    label: Text(p['label']!, style: const TextStyle(fontSize: 11)),
                    onPressed: () => setState(() => _ctrl.text = p['latex']!),
                    backgroundColor: const Color(0xFFF1F5F9),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // Input Box
              TextField(
                controller: _ctrl,
                maxLines: 2,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'LaTeX / Mathematical Expression',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),

              // Live Preview Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF93C5FD)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('LIVE FORMULA PREVIEW', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    const SizedBox(height: 6),
                    Text(
                      _formatReadablePreview(_ctrl.text),
                      style: const TextStyle(fontSize: 20, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Highlight tint
              Row(
                children: [
                  const Text('Highlight Box:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                  const SizedBox(width: 10),
                  for (final hex in ['#E0F2FE', '#FEF08A', '#DCFCE7', '#F5F3FF', '#FFFFFF'])
                    GestureDetector(
                      onTap: () => setState(() => _selectedBgHex = hex),
                      child: Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16)),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _selectedBgHex == hex ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                            width: _selectedBgHex == hex ? 2.5 : 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Symbol Palette
              for (final entry in _symbolGroups.entries) ...[
                Text(entry.key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: entry.value.map((sym) {
                    return InkWell(
                      onTap: () => _insertSnippet(sym['insert']!),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(sym['label']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton.icon(
          icon: const Icon(Icons.check_rounded, size: 16),
          label: const Text('Insert Equation'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
          onPressed: () {
            final raw = _ctrl.text.trim();
            if (raw.isEmpty) return;
            Navigator.pop(context, {
              'latex': raw,
              'display': _formatReadablePreview(raw),
              'bgColor': _selectedBgHex,
            });
          },
        ),
      ],
    );
  }
}
