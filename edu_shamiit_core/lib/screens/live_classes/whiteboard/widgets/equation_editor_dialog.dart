import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EquationEditorDialog extends StatefulWidget {
  final String? initialLatex;
  final String? initialBgHex;
  final String? initialTextColor;
  final double? initialFontSize;

  const EquationEditorDialog({
    super.key,
    this.initialLatex,
    this.initialBgHex,
    this.initialTextColor,
    this.initialFontSize,
  });

  @override
  State<EquationEditorDialog> createState() => _EquationEditorDialogState();
}

class _EquationEditorDialogState extends State<EquationEditorDialog> {
  late TextEditingController _ctrl;
  late String _selectedBgHex;
  late String _selectedTextColor;
  late double _selectedFontSize;
  int _activeCategoryIndex = 0;

  static const _categories = [
    '🌟 Presets',
    '➗ Algebra',
    '∫ Calculus',
    '📐 Trig & Exp',
    '⊞ Matrices',
    'αβ Greek',
    '⇄ Logic & Sets',
  ];

  static const _presets = <Map<String, String>>[
    {'label': 'Quadratic Formula', 'latex': r'x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}'},
    {'label': 'Pythagorean Theorem', 'latex': 'a^2 + b^2 = c^2'},
    {'label': "Newton's 2nd Law", 'latex': r'\vec{F} = m \cdot \vec{a}'},
    {'label': 'Calculus Fund. Theorem', 'latex': r'\int_{a}^{b} f(x) dx = F(b) - F(a)'},
    {'label': "Euler's Identity", 'latex': r'e^{i\pi} + 1 = 0'},
    {'label': 'Binomial Theorem', 'latex': r'(x + y)^n = \sum_{k=0}^{n} \binom{n}{k} x^{n-k} y^k'},
    {'label': 'Standard Polynomial', 'latex': 'ax^2 + bx + c = 0'},
    {'label': 'Discriminant', 'latex': r'\Delta = b^2 - 4ac'},
    {'label': 'Limit Definition', 'latex': r'\lim_{x \to 0} \frac{\sin x}{x} = 1'},
    {'label': 'Log Change of Base', 'latex': r'\log_b(a) = \frac{\ln a}{\ln b}'},
    {'label': 'Normal Distribution', 'latex': r'f(x) = \frac{1}{\sigma\sqrt{2\pi}} e^{-\frac{1}{2}\left(\frac{x-\mu}{\sigma}\right)^2}'},
    {'label': 'Matrix Determinant', 'latex': r'\det(A) = ad - bc'},
  ];

  static const _quickKeypad = [
    {'label': '+', 'insert': ' + '},
    {'label': '−', 'insert': ' - '},
    {'label': '±', 'insert': r'\pm '},
    {'label': '×', 'insert': r'\times '},
    {'label': '÷', 'insert': r'\div '},
    {'label': '=', 'insert': ' = '},
    {'label': '≠', 'insert': r'\neq '},
    {'label': 'x', 'insert': 'x'},
    {'label': 'y', 'insert': 'y'},
    {'label': 'z', 'insert': 'z'},
    {'label': 't', 'insert': 't'},
    {'label': '²', 'insert': '^2'},
    {'label': '³', 'insert': '^3'},
    {'label': 'ⁿ', 'insert': '^{n}'},
    {'label': '√', 'insert': r'\sqrt{x}'},
    {'label': 'a/b', 'insert': r'\frac{a}{b}'},
    {'label': '( )', 'insert': '()'},
    {'label': 'π', 'insert': r'\pi '},
    {'label': 'θ', 'insert': r'\theta '},
    {'label': '∞', 'insert': r'\infty '},
  ];

  static const _symbolGroups = <String, List<Map<String, String>>>{
    'Algebra': [
      {'label': 'a/b', 'insert': r'\frac{a}{b}'},
      {'label': 'x²', 'insert': '^2'},
      {'label': 'x³', 'insert': '^3'},
      {'label': 'xⁿ', 'insert': '^{n}'},
      {'label': 'xᵢ', 'insert': '_{i}'},
      {'label': 'xᵢ²', 'insert': '_{i}^2'},
      {'label': '√x', 'insert': r'\sqrt{x}'},
      {'label': 'ⁿ√x', 'insert': r'\sqrt[n]{x}'},
      {'label': '±', 'insert': r'\pm '},
      {'label': '∓', 'insert': r'\mp '},
      {'label': '×', 'insert': r'\times '},
      {'label': '·', 'insert': r'\cdot '},
      {'label': '÷', 'insert': r'\div '},
      {'label': '≠', 'insert': r'\neq '},
      {'label': '≤', 'insert': r'\le '},
      {'label': '≥', 'insert': r'\ge '},
      {'label': '≈', 'insert': r'\approx '},
      {'label': '≡', 'insert': r'\equiv '},
      {'label': '∝', 'insert': r'\propto '},
      {'label': '|x|', 'insert': '|x|'},
      {'label': '(x)', 'insert': '(x)'},
      {'label': '[x]', 'insert': '[x]'},
      {'label': '{x}', 'insert': r'\{x\}'},
    ],
    'Calculus': [
      {'label': 'dy/dx', 'insert': r'\frac{dy}{dx}'},
      {'label': 'd²y/dx²', 'insert': r'\frac{d^2y}{dx^2}'},
      {'label': '∂f/∂x', 'insert': r'\frac{\partial f}{\partial x}'},
      {'label': '∂', 'insert': r'\partial '},
      {'label': '∇', 'insert': r'\nabla '},
      {'label': '∫ dx', 'insert': r'\int f(x) dx'},
      {'label': '∫ₐᵇ', 'insert': r'\int_{a}^{b} f(x) dx'},
      {'label': '∬', 'insert': r'\iint_D f(x, y) dA'},
      {'label': '∮', 'insert': r'\oint_C '},
      {'label': 'lim(x→0)', 'insert': r'\lim_{x \to 0} '},
      {'label': 'lim(x→∞)', 'insert': r'\lim_{x \to \infty} '},
      {'label': '∑ᵢ₌₁ⁿ', 'insert': r'\sum_{i=1}^{n} '},
      {'label': '∏ᵢ₌₁ⁿ', 'insert': r'\prod_{i=1}^{n} '},
      {'label': 'Δx', 'insert': r'\Delta x'},
      {'label': 'dx', 'insert': ' dx'},
      {'label': 'dt', 'insert': ' dt'},
      {'label': '∞', 'insert': r'\infty '},
    ],
    'Trig & Exp': [
      {'label': 'sin θ', 'insert': r'\sin(\theta)'},
      {'label': 'cos θ', 'insert': r'\cos(\theta)'},
      {'label': 'tan θ', 'insert': r'\tan(\theta)'},
      {'label': 'sec θ', 'insert': r'\sec(\theta)'},
      {'label': 'csc θ', 'insert': r'\csc(\theta)'},
      {'label': 'cot θ', 'insert': r'\cot(\theta)'},
      {'label': 'arcsin', 'insert': r'\arcsin(x)'},
      {'label': 'arccos', 'insert': r'\arccos(x)'},
      {'label': 'arctan', 'insert': r'\arctan(x)'},
      {'label': 'log₁₀(x)', 'insert': r'\log_{10}(x)'},
      {'label': 'ln(x)', 'insert': r'\ln(x)'},
      {'label': 'log_b(x)', 'insert': r'\log_{b}(x)'},
      {'label': 'eˣ', 'insert': 'e^{x}'},
      {'label': 'e⁻ˣ', 'insert': 'e^{-x}'},
      {'label': 'f(x)', 'insert': 'f(x)'},
      {'label': 'g(x)', 'insert': 'g(x)'},
    ],
    'Matrices': [
      {'label': '2×2 Bracket', 'insert': r'\begin{bmatrix} a & b \\ c & d \end{bmatrix}'},
      {'label': '2×2 Parenthesis', 'insert': r'\begin{pmatrix} a & b \\ c & d \end{pmatrix}'},
      {'label': '2×2 Determinant', 'insert': r'\begin{vmatrix} a & b \\ c & d \end{vmatrix}'},
      {'label': '3×3 Matrix', 'insert': r'\begin{bmatrix} a & b & c \\ d & e & f \\ g & h & i \end{bmatrix}'},
      {'label': 'Row Vector', 'insert': r'\begin{bmatrix} x & y & z \end{bmatrix}'},
      {'label': 'Column Vector', 'insert': r'\begin{bmatrix} x \\ y \\ z \end{bmatrix}'},
      {'label': 'v⃗', 'insert': r'\vec{v}'},
      {'label': 'î', 'insert': r'\hat{i}'},
      {'label': 'ĵ', 'insert': r'\hat{j}'},
      {'label': 'k̂', 'insert': r'\hat{k}'},
      {'label': 'det(A)', 'insert': r'\det(A)'},
      {'label': 'Aᵀ', 'insert': 'A^T'},
      {'label': 'A⁻¹', 'insert': 'A^{-1}'},
    ],
    'Greek': [
      {'label': 'α (alpha)', 'insert': r'\alpha '},
      {'label': 'β (beta)', 'insert': r'\beta '},
      {'label': 'γ (gamma)', 'insert': r'\gamma '},
      {'label': 'δ (delta)', 'insert': r'\delta '},
      {'label': 'ε (epsilon)', 'insert': r'\epsilon '},
      {'label': 'θ (theta)', 'insert': r'\theta '},
      {'label': 'λ (lambda)', 'insert': r'\lambda '},
      {'label': 'μ (mu)', 'insert': r'\mu '},
      {'label': 'π (pi)', 'insert': r'\pi '},
      {'label': 'ρ (rho)', 'insert': r'\rho '},
      {'label': 'σ (sigma)', 'insert': r'\sigma '},
      {'label': 'τ (tau)', 'insert': r'\tau '},
      {'label': 'φ (phi)', 'insert': r'\phi '},
      {'label': 'ω (omega)', 'insert': r'\omega '},
      {'label': 'Δ (Delta)', 'insert': r'\Delta '},
      {'label': 'Σ (Sigma)', 'insert': r'\Sigma '},
      {'label': 'Ω (Omega)', 'insert': r'\Omega '},
      {'label': 'Γ (Gamma)', 'insert': r'\Gamma '},
      {'label': 'Θ (Theta)', 'insert': r'\Theta '},
    ],
    'Logic & Sets': [
      {'label': '→ (to)', 'insert': r'\to '},
      {'label': '⇒ (implies)', 'insert': r'\implies '},
      {'label': '⇔ (iff)', 'insert': r'\iff '},
      {'label': '∈ (in)', 'insert': r'\in '},
      {'label': '∉ (not in)', 'insert': r'\notin '},
      {'label': '⊂ (subset)', 'insert': r'\subset '},
      {'label': '∪ (union)', 'insert': r'\cup '},
      {'label': '∩ (intersect)', 'insert': r'\cap '},
      {'label': '∅ (empty)', 'insert': r'\emptyset '},
      {'label': '∀ (for all)', 'insert': r'\forall '},
      {'label': '∃ (exists)', 'insert': r'\exists '},
      {'label': '∴ (therefore)', 'insert': r'\therefore '},
      {'label': '∵ (because)', 'insert': r'\because '},
      {'label': '¬ (not)', 'insert': r'\neg '},
      {'label': '∧ (and)', 'insert': r'\wedge '},
      {'label': '∨ (or)', 'insert': r'\vee '},
    ],
  };

  static const _tintPresets = [
    {'name': 'Ice Blue', 'hex': '#E0F2FE', 'border': '#93C5FD', 'text': '#0369A1'},
    {'name': 'Mint Green', 'hex': '#DCFCE7', 'border': '#86EFAC', 'text': '#15803D'},
    {'name': 'Warm Amber', 'hex': '#FEF3C7', 'border': '#FCD34D', 'text': '#B45309'},
    {'name': 'Lavender', 'hex': '#F3E8FF', 'border': '#D8B4FE', 'text': '#7E22CE'},
    {'name': 'Rose Pearl', 'hex': '#FFE4E6', 'border': '#FDA4AF', 'text': '#BE123C'},
    {'name': 'Blackboard', 'hex': '#0F172A', 'border': '#334155', 'text': '#38BDF8'},
    {'name': 'Pure Canvas', 'hex': '#FFFFFF', 'border': '#CBD5E1', 'text': '#0F172A'},
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.initialLatex ?? r'x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}',
    );
    _selectedBgHex = widget.initialBgHex ?? '#E0F2FE';
    _selectedTextColor = widget.initialTextColor ?? '#0F172A';
    _selectedFontSize = widget.initialFontSize ?? 20.0;
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

    int newOffset = start + snippet.length;
    // If snippet has an argument placeholder like \frac{a}{b}, select 'a'
    if (snippet.contains(r'\frac{a}{b}')) {
      newOffset = start + 6;
    } else if (snippet.contains(r'\sqrt{x}')) {
      newOffset = start + 6;
    }

    setState(() {
      _ctrl.value = TextEditingValue(
        text: updated,
        selection: TextSelection.collapsed(offset: newOffset),
      );
    });
  }

  static String formatReadablePreview(String raw) {
    var out = raw
        .replaceAll(r'\pm', '±')
        .replaceAll(r'\mp', '∓')
        .replaceAll(r'\times', '×')
        .replaceAll(r'\cdot', '·')
        .replaceAll(r'\div', '÷')
        .replaceAll(r'\neq', '≠')
        .replaceAll(r'\leq', '≤')
        .replaceAll(r'\le', '≤')
        .replaceAll(r'\geq', '≥')
        .replaceAll(r'\ge', '≥')
        .replaceAll(r'\approx', '≈')
        .replaceAll(r'\equiv', '≡')
        .replaceAll(r'\infty', '∞')
        .replaceAll(r'\propto', '∝')
        .replaceAll(r'\Delta', 'Δ')
        .replaceAll(r'\Sigma', 'Σ')
        .replaceAll(r'\Omega', 'Ω')
        .replaceAll(r'\Gamma', 'Γ')
        .replaceAll(r'\Theta', 'Θ')
        .replaceAll(r'\alpha', 'α')
        .replaceAll(r'\beta', 'β')
        .replaceAll(r'\gamma', 'γ')
        .replaceAll(r'\delta', 'δ')
        .replaceAll(r'\epsilon', 'ε')
        .replaceAll(r'\theta', 'θ')
        .replaceAll(r'\lambda', 'λ')
        .replaceAll(r'\mu', 'μ')
        .replaceAll(r'\pi', 'π')
        .replaceAll(r'\rho', 'ρ')
        .replaceAll(r'\sigma', 'σ')
        .replaceAll(r'\tau', 'τ')
        .replaceAll(r'\phi', 'φ')
        .replaceAll(r'\omega', 'ω')
        .replaceAll(r'\to', '→')
        .replaceAll(r'\implies', '⇒')
        .replaceAll(r'\iff', '⇔')
        .replaceAll(r'\in', '∈')
        .replaceAll(r'\notin', '∉')
        .replaceAll(r'\subset', '⊂')
        .replaceAll(r'\cup', '∪')
        .replaceAll(r'\cap', '∩')
        .replaceAll(r'\emptyset', '∅')
        .replaceAll(r'\forall', '∀')
        .replaceAll(r'\exists', '∃')
        .replaceAll(r'\therefore', '∴')
        .replaceAll(r'\because', '∵')
        .replaceAll(r'\partial', '∂')
        .replaceAll(r'\nabla', '∇')
        .replaceAll(r'\int', '∫')
        .replaceAll(r'\sum', '∑')
        .replaceAll(r'\prod', '∏')
        .replaceAll(r'\vec{v}', 'v⃗')
        .replaceAll(r'\vec{F}', 'F⃗')
        .replaceAll(r'\vec{a}', 'a⃗')
        .replaceAll(r'\hat{i}', 'î')
        .replaceAll(r'\hat{j}', 'ĵ')
        .replaceAll(r'\hat{k}', 'k̂');

    // Convert powers like ^2, ^3, ^n
    out = out
        .replaceAll('^2', '²')
        .replaceAll('^{2}', '²')
        .replaceAll('^3', '³')
        .replaceAll('^{3}', '³')
        .replaceAll('^0', '⁰')
        .replaceAll('^1', '¹')
        .replaceAll('^4', '⁴')
        .replaceAll('^5', '⁵')
        .replaceAll('^6', '⁶')
        .replaceAll('^7', '⁷')
        .replaceAll('^8', '⁸')
        .replaceAll('^9', '⁹')
        .replaceAll('^n', 'ⁿ')
        .replaceAll('^{n}', 'ⁿ')
        .replaceAll('^{n-1}', '⁽ⁿ⁻¹⁾')
        .replaceAll('^{n-k}', '⁽ⁿ⁻ᵏ⁾')
        .replaceAll('^{x}', 'ˣ')
        .replaceAll('^{-x}', '⁻ˣ')
        .replaceAll('^{-1}', '⁻¹')
        .replaceAll('^T', 'ᵀ');

    // Convert subscripts like _0, _1, _i
    out = out
        .replaceAll('_0', '₀')
        .replaceAll('_{0}', '₀')
        .replaceAll('_1', '₁')
        .replaceAll('_{1}', '₁')
        .replaceAll('_2', '₂')
        .replaceAll('_{2}', '₂')
        .replaceAll('_i', 'ᵢ')
        .replaceAll('_{i}', 'ᵢ')
        .replaceAll('_{k}', 'ₖ')
        .replaceAll('_{n}', 'ₙ')
        .replaceAll('_n', 'ₙ');

    // Fractions \frac{num}{den} -> (num) / (den)
    out = out.replaceAllMapped(RegExp(r'\\frac\{(.+?)\}\{(.+?)\}'), (m) {
      return '(${m.group(1)}) / (${m.group(2)})';
    });

    // Radicals \sqrt[n]{x} -> ⁿ√(x), \sqrt{x} -> √(x)
    out = out.replaceAllMapped(RegExp(r'\\sqrt\[(.+?)\]\{(.+?)\}'), (m) {
      return '${m.group(1)}√(${m.group(2)})';
    });
    out = out.replaceAllMapped(RegExp(r'\\sqrt\{(.+?)\}'), (m) {
      return '√(${m.group(1)})';
    });

    // Matrices bracket cleanup
    out = out
        .replaceAll(r'\begin{bmatrix}', '[ ')
        .replaceAll(r'\end{bmatrix}', ' ]')
        .replaceAll(r'\begin{pmatrix}', '( ')
        .replaceAll(r'\end{pmatrix}', ' )')
        .replaceAll(r'\begin{vmatrix}', '| ')
        .replaceAll(r'\end{vmatrix}', ' |')
        .replaceAll(r'\\', ' ; ')
        .replaceAll('&', ' ');

    return out.replaceAll(r'\left(', '(').replaceAll(r'\right)', ')');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final bgTint = Color(int.parse(_selectedBgHex.replaceFirst('#', 'FF'), radix: 16));
    final isBlackboard = _selectedBgHex == '#0F172A';

    return AlertDialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1.2),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF4F46E5)]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.functions_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Text(
                        'Mathematical Equation Editor',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('LaTeX & Math Engine', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6))),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Compose and format rich formulas, expressions and matrices',
                  style: TextStyle(fontSize: 11.5, color: textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Live Formula Preview Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: bgTint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isBlackboard ? const Color(0xFF38BDF8).withValues(alpha: 0.6) : const Color(0xFF93C5FD),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'LIVE FORMULA PREVIEW',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: isBlackboard ? const Color(0xFF38BDF8) : textSecondary,
                          ),
                        ),
                        Text(
                          '${_selectedFontSize.toInt()}pt • ${_ctrl.text.length} chars',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: isBlackboard ? const Color(0xFF94A3B8) : textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildStructuredMathPreview(isBlackboard),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 2. Fast Keypad Ribbon
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _quickKeypad.map((k) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: InkWell(
                          onTap: () => _insertSnippet(k['insert']!),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: borderColor),
                            ),
                            child: Text(
                              k['label']!,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 3. LaTeX Input Field with Clear & Copy
              TextField(
                controller: _ctrl,
                maxLines: 2,
                onChanged: (_) => setState(() {}),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF1E293B),
                ),
                decoration: InputDecoration(
                  labelText: 'LaTeX / Mathematical Expression',
                  labelStyle: TextStyle(fontSize: 12, color: textSecondary),
                  hintText: r'e.g. x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}',
                  hintStyle: TextStyle(fontSize: 12, color: textSecondary),
                  filled: true,
                  fillColor: cardBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.6)),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Copy LaTeX',
                        icon: Icon(Icons.copy_rounded, size: 15, color: textSecondary),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _ctrl.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('LaTeX copied to clipboard'), duration: Duration(seconds: 1)),
                          );
                        },
                      ),
                      if (_ctrl.text.isNotEmpty)
                        IconButton(
                          tooltip: 'Clear',
                          icon: Icon(Icons.clear_rounded, size: 16, color: textSecondary),
                          onPressed: () => setState(() => _ctrl.clear()),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 4. Category Tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_categories.length, (idx) {
                    final isSel = _activeCategoryIndex == idx;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(_categories[idx]),
                        selected: isSel,
                        onSelected: (_) => setState(() => _activeCategoryIndex = idx),
                        selectedColor: const Color(0xFF2563EB),
                        backgroundColor: cardBg,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          color: isSel ? Colors.white : textPrimary,
                        ),
                        side: BorderSide(color: isSel ? const Color(0xFF2563EB) : borderColor),
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 8),

              // 5. Active Tab Contents
              _buildCategoryContent(isDark, cardBg, borderColor, textPrimary, textSecondary),
              const SizedBox(height: 12),

              // 6. Style Customization: Highlight Tint & Font Size
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('Box Tint:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary)),
                  const SizedBox(width: 8),
                  for (final tint in _tintPresets)
                    GestureDetector(
                      onTap: () => setState(() => _selectedBgHex = tint['hex']!),
                      child: Container(
                        width: 22,
                        height: 22,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: Color(int.parse(tint['hex']!.replaceFirst('#', 'FF'), radix: 16)),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _selectedBgHex == tint['hex'] ? const Color(0xFF2563EB) : Color(int.parse(tint['border']!.replaceFirst('#', 'FF'), radix: 16)),
                            width: _selectedBgHex == tint['hex'] ? 2.5 : 1,
                          ),
                        ),
                      ),
                    ),
                  const Spacer(),
                  Text('Size:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary)),
                  const SizedBox(width: 6),
                  for (final sz in [16.0, 18.0, 20.0, 24.0, 28.0])
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: InkWell(
                        onTap: () => setState(() => _selectedFontSize = sz),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: _selectedFontSize == sz ? const Color(0xFF2563EB) : cardBg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: _selectedFontSize == sz ? const Color(0xFF2563EB) : borderColor),
                          ),
                          child: Text(
                            '${sz.toInt()}pt',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _selectedFontSize == sz ? Colors.white : textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
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
        ElevatedButton.icon(
          icon: const Icon(Icons.check_rounded, size: 16),
          label: const Text('Insert Equation'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            final raw = _ctrl.text.trim();
            if (raw.isEmpty) return;
            Navigator.pop(context, {
              'latex': raw,
              'display': formatReadablePreview(raw),
              'bgColor': _selectedBgHex,
              'fontSize': _selectedFontSize,
              'color': _selectedBgHex == '#0F172A' ? '#38BDF8' : _selectedTextColor,
              'borderColor': _selectedBgHex == '#0F172A' ? '#38BDF8' : '#93C5FD',
            });
          },
        ),
      ],
    );
  }

  Widget _buildCategoryContent(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (_activeCategoryIndex == 0) {
      // 🌟 Presets
      return Container(
        height: 120,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: SingleChildScrollView(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _presets.map((p) {
              final isCurrent = _ctrl.text.trim() == p['latex']!.trim();
              return ActionChip(
                label: Text(p['label']!, style: const TextStyle(fontSize: 11)),
                backgroundColor: isCurrent ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF0F172A) : Colors.white),
                labelStyle: TextStyle(
                  color: isCurrent ? Colors.white : textPrimary,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                ),
                side: BorderSide(color: isCurrent ? const Color(0xFF2563EB) : borderColor),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _ctrl.text = p['latex']!),
              );
            }).toList(),
          ),
        ),
      );
    }

    final groupKey = _categories[_activeCategoryIndex].replaceAll(RegExp(r'^[^\w]+'), '').trim();
    final group = _symbolGroups[groupKey] ?? [];

    return Container(
      height: 120,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: group.map((sym) {
            return InkWell(
              onTap: () => _insertSnippet(sym['insert']!),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  sym['label']!,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStructuredMathPreview(bool isBlackboard) {
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) {
      return const Text(
        'Type an equation or select a preset above...',
        style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)),
      );
    }

    final textColor = isBlackboard ? const Color(0xFF38BDF8) : const Color(0xFF0F172A);

    // Check stacked fraction for quadratic formula or \frac
    final fracMatch = RegExp(r'^(.*?)=\s*\\frac\{(.+?)\}\{(.+?)\}$').firstMatch(raw);
    if (fracMatch != null) {
      final lhs = '${fracMatch.group(1)!.trim()} = ';
      final numStr = formatReadablePreview(fracMatch.group(2)!);
      final denStr = formatReadablePreview(fracMatch.group(3)!);

      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            lhs,
            style: TextStyle(
              fontSize: _selectedFontSize,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                numStr,
                style: TextStyle(
                  fontSize: _selectedFontSize * 0.85,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                height: 1.8,
                width: 140,
                color: textColor,
              ),
              Text(
                denStr,
                style: TextStyle(
                  fontSize: _selectedFontSize * 0.85,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Text(
      formatReadablePreview(raw),
      style: TextStyle(
        fontSize: _selectedFontSize,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w600,
        color: textColor,
        height: 1.3,
      ),
      textAlign: TextAlign.center,
    );
  }
}
