class MathFormatter {
  static String _toSuperscript(String input) {
    const map = {
      '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴',
      '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹',
      '+': '⁺', '-': '⁻', '=': '⁼', '(': '⁽', ')': '⁾',
      'n': 'ⁿ', 'x': 'ˣ', 'i': 'ⁱ', 'r': 'ʳ', 't': 'ᵗ',
      'a': 'ᵃ', 'b': 'ᵇ', 'c': 'ᶜ', 'd': 'ᵈ', 'e': 'ᵉ',
      'f': 'ᶠ', 'g': 'ᵍ', 'h': 'ʰ', 'j': 'ʲ', 'k': 'ᵏ',
      'l': 'ˡ', 'm': 'ᵐ', 'o': 'ᵒ', 'p': 'ᵖ', 's': 'ˢ',
      'u': 'ᵘ', 'v': 'ᵛ', 'w': 'ʷ', 'y': 'ʸ', 'z': 'ᶻ',
    };
    return input.split('').map((char) => map[char] ?? char).join();
  }

  static String _toSubscript(String input) {
    const map = {
      '0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄',
      '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉',
      '+': '₊', '-': '₋', '=': '₌', '(': '₍', ')': '₎',
      'a': 'ₐ', 'e': 'ₑ', 'i': 'ᵢ', 'j': 'ⱼ', 'k': 'ₖ',
      'l': 'ₗ', 'm': 'ₘ', 'n': 'ₙ', 'o': 'ₒ', 'p': 'ₚ',
      'r': 'ᵣ', 's': 'ₛ', 't': 'ₜ', 'u': 'ᵤ', 'v': 'ᵥ',
      'x': 'ₓ',
    };
    return input.split('').map((char) => map[char] ?? char).join();
  }

  static const Map<String, String> _latexMap = {
    // Operators
    r'\cdot':       '·',
    r'\times':      '×',
    r'\div':        '÷',
    r'\pm':         '±',
    r'\mp':         '∓',
    r'\approx':     '≈',
    r'\neq':        '≠',
    r'\ne':         '≠',
    r'\leq':        '≤',
    r'\geq':        '≥',
    r'\le':         '≤',
    r'\ge':         '≥',
    r'\ll':         '≪',
    r'\gg':         '≫',
    r'\sim':        '~',
    r'\simeq':      '≃',
    r'\equiv':      '≡',
    r'\propto':     '∝',
    r'\in':         '∈',
    r'\notin':      '∉',
    r'\subset':     '⊂',
    r'\supset':     '⊃',
    r'\cup':        '∪',
    r'\cap':        '∩',
    r'\emptyset':   '∅',
    // Arrows
    r'\rightarrow': '→',
    r'\lefttarrow':  '←',
    r'\Rightarrow': '⇒',
    r'\Leftarrow':  '⇐',
    r'\leftrightarrow': '↔',
    r'\Leftrightarrow': '⟺',
    r'\leftharpoons': '⇌',
    r'\rightleftharpoons': '⇌',
    r'\to':         '→',
    r'\gets':       '←',
    r'\uparrow':    '↑',
    r'\downarrow':  '↓',
    // Dots & misc
    r'\ldots':      '…',
    r'\cdots':      '···',
    r'\vdots':      '⋮',
    r'\ddots':      '⋱',
    r'\therefore':  '∴',
    r'\because':    '∵',
    r'\forall':     '∀',
    r'\exists':     '∃',
    // Geometry / trig
    r'\angle':      '∠',
    r'\perp':       '⊥',
    r'\parallel':   '∥',
    r'\circ':       '°',
    r'\degree':     '°',
    r'^\circ':      '°',
    r'^\degree':    '°',
    r'^o':          '°',
    // Calc / analysis
    r'\int':        '∫',
    r'\iint':       '∬',
    r'\iiint':      '∭',
    r'\oint':       '∮',
    r'\sum':        '∑',
    r'\prod':       '∏',
    r'\partial':    '∂',
    r'\nabla':      '∇',
    r'\infty':      '∞',
    r'\sqrt':       '√',
    // Named functions
    r'\sin':  'sin',
    r'\cos':  'cos',
    r'\tan':  'tan',
    r'\cot':  'cot',
    r'\sec':  'sec',
    r'\csc':  'csc',
    r'\arcsin': 'arcsin',
    r'\arccos': 'arccos',
    r'\arctan': 'arctan',
    r'\sinh': 'sinh',
    r'\cosh': 'cosh',
    r'\tanh': 'tanh',
    r'\log':  'log',
    r'\ln':   'ln',
    r'\exp':  'exp',
    r'\lim':  'lim',
    r'\max':  'max',
    r'\min':  'min',
    r'\gcd':  'gcd',
    r'\lcm':  'lcm',
    r'\det':  'det',
    r'\dim':  'dim',
    r'\ker':  'ker',
    // Lowercase Greek
    r'\alpha':   'α',
    r'\beta':    'β',
    r'\gamma':   'γ',
    r'\delta':   'δ',
    r'\epsilon': 'ε',
    r'\varepsilon': 'ε',
    r'\zeta':    'ζ',
    r'\eta':     'η',
    r'\theta':   'θ',
    r'\vartheta':'ϑ',
    r'\iota':    'ι',
    r'\kappa':   'κ',
    r'\lambda':  'λ',
    r'\mu':      'μ',
    r'\nu':      'ν',
    r'\xi':      'ξ',
    r'\pi':      'π',
    r'\varpi':   'ϖ',
    r'\rho':     'ρ',
    r'\varrho':  'ϱ',
    r'\sigma':   'σ',
    r'\varsigma':'ς',
    r'\tau':     't',
    r'\upsilon': 'υ',
    r'\phi':     'φ',
    r'\varphi':  'φ',
    r'\chi':     'χ',
    r'\psi':     'ψ',
    r'\omega':   'ω',
    // Uppercase Greek
    r'\Gamma':   'Γ',
    r'\Delta':   'Δ',
    r'\Theta':   'Θ',
    r'\Lambda':  'Λ',
    r'\Xi':      'Ξ',
    r'\Pi':      'Π',
    r'\Sigma':   'Σ',
    r'\Upsilon': 'Υ',
    r'\Phi':     'Φ',
    r'\Psi':     'Ψ',
    r'\Omega':   'Ω',
    // Brackets
    r'\lfloor': '⌊', r'\rfloor': '⌋',
    r'\lceil':  '⌈', r'\rceil':  '⌉',
    r'\langle': '⟨', r'\rangle': '⟩',
    // Font/style wrappers
    r'\text':    '',
    r'\mathrm':  '',
    r'\mathbf':  '',
    r'\mathit':  '',
    r'\mathbb':  '',
    r'\boldsymbol': '',
    r'\displaystyle': '',
    r'\textstyle': '',
    // Spacing
    r'\,': ' ', r'\;': ' ', r'\:': ' ', r'\!': '',
    r'\quad': '  ', r'\qquad': '   ',
    // Brackets \left / \right
    r'\left(':  '(',  r'\right)': ')',
    r'\left[':  '[',  r'\right]': ']',
    r'\left\{': '{',  r'\right\}': '}',
    r'\left|':  '|',  r'\right|': '|',
    r'\left':   '',   r'\right':  '',
    // Misc
    r'\limits': '',
    r'\bullet': '•',
    r'\star':   '★',
    r'\dagger': '†',
    r'\ddagger': '‡',
    r'\hbar':   'ℏ',
    r'\ell':    'ℓ',
    r'\Re':     'ℜ',
    r'\Im':     'ℑ',
    r'\aleph':  'ℵ',
  };

  static String _formatChemicalFormulas(String text) {
    const commonChem = {
      'H', 'He', 'Li', 'Be', 'B', 'C', 'N', 'O', 'F', 'Ne',
      'Na', 'Mg', 'Al', 'Si', 'P', 'S', 'Cl', 'Ar', 'K', 'Ca',
      'Sc', 'Ti', 'V', 'Cr', 'Mn', 'Fe', 'Co', 'Ni', 'Cu', 'Zn',
      'Ga', 'Ge', 'As', 'Se', 'Br', 'Kr', 'Rb', 'Sr', 'Y', 'Zr',
      'Ag', 'Cd', 'In', 'Sn', 'Sb', 'Te', 'I', 'Xe',
      'Ba', 'La', 'Ce', 'W', 'Re', 'Os', 'Ir', 'Pt', 'Au', 'Hg',
      'Tl', 'Pb', 'Bi', 'Ra', 'U', 'Pu',
    };
    final regex = RegExp(
      r'\b([A-Z][a-z]?)([0-9]+)(?=[A-Z0-9])|\b([A-Z][a-z]?)([0-9]+)\b',
    );
    return text.replaceAllMapped(regex, (match) {
      final element = match.group(1) ?? match.group(3) ?? '';
      final digits  = match.group(2) ?? match.group(4) ?? '';
      if (element.isEmpty || digits.isEmpty) return match.group(0)!;
      if (!commonChem.contains(element)) return match.group(0)!;
      return '$element${_toSubscript(digits)}';
    });
  }

  static String _cleanSingleMathBlock(String math) {
    var r = math.trim();

    final wrapperRx = RegExp(r'\\(?:text|mathrm|mathbf|mathit|mathbb|boldsymbol)\{([^{}]*)\}');
    while (wrapperRx.hasMatch(r)) {
      r = r.replaceAllMapped(wrapperRx, (m) => m.group(1)!);
    }

    final sqrtNRx = RegExp(r'\\sqrt\[([^\]]+)\]\{([^{}]*)\}');
    while (sqrtNRx.hasMatch(r)) {
      r = r.replaceAllMapped(sqrtNRx, (m) => '${_toSuperscript(m.group(1)!)}√(${m.group(2)!})');
    }
    final sqrtRx = RegExp(r'\\sqrt\{([^{}]*)\}');
    while (sqrtRx.hasMatch(r)) {
      r = r.replaceAllMapped(sqrtRx, (m) => '√(${m.group(1)!})');
    }
    r = r.replaceAll(r'\sqrt', '√');

    final fracRx = RegExp(r'\\frac\{([^{}]*)\}\{([^{}]*)\}');
    for (int pass = 0; pass < 4; pass++) {
      if (!fracRx.hasMatch(r)) break;
      r = r.replaceAllMapped(fracRx, (m) {
        final n = m.group(1)!.trim();
        final d = m.group(2)!.trim();
        final nd = (n.contains(RegExp(r'[+\-]')) && n.length > 1) ? '($n)' : n;
        final dd = (d.contains(RegExp(r'[+\-]')) && d.length > 1) ? '($d)' : d;
        return '$nd/$dd';
      });
    }

    final keys = _latexMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final key in keys) {
      r = r.replaceAll(key, _latexMap[key]!);
    }

    final unknownCmd = RegExp(r'\\[a-zA-Z]+\{([^{}]*)\}');
    while (unknownCmd.hasMatch(r)) {
      r = r.replaceAllMapped(unknownCmd, (m) => m.group(1)!);
    }
    r = r.replaceAll(RegExp(r'\\[a-zA-Z]+'), '');

    final supBrace = RegExp(r'\^\{([^{}]*)\}');
    while (supBrace.hasMatch(r)) {
      r = r.replaceAllMapped(supBrace, (m) => _toSuperscript(m.group(1)!));
    }
    r = r.replaceAllMapped(
      RegExp(r'\^([0-9a-zA-Z+\-])'),
      (m) => _toSuperscript(m.group(1)!),
    );

    final subBrace = RegExp(r'_\{([^{}]*)\}');
    while (subBrace.hasMatch(r)) {
      r = r.replaceAllMapped(subBrace, (m) => _toSubscript(m.group(1)!));
    }
    r = r.replaceAllMapped(
      RegExp(r'_([0-9a-zA-Z+\-])'),
      (m) => _toSubscript(m.group(1)!),
    );

    r = r.replaceAll('{', '').replaceAll('}', '');
    r = r.replaceAll(r'\\', ' ');
    r = r.replaceAll(RegExp(r'  +'), ' ').trim();
    return r;
  }

  static String cleanMathExpressions(String text) {
    var r = text;

    r = r.replaceAllMapped(
      RegExp(r'\$\$(.+?)\$\$', dotAll: true),
      (m) => '\n${_cleanSingleMathBlock(m.group(1)!)}\n',
    );

    r = r.replaceAllMapped(
      RegExp(r'\\\[(.+?)\\\]', dotAll: true),
      (m) => '\n${_cleanSingleMathBlock(m.group(1)!)}\n',
    );

    r = r.replaceAllMapped(
      RegExp(r'\$([^\$\n]+)\$'),
      (m) => _cleanSingleMathBlock(m.group(1)!),
    );

    r = r.replaceAllMapped(
      RegExp(r'\\\((.+?)\\\)', dotAll: true),
      (m) => _cleanSingleMathBlock(m.group(1)!),
    );

    final keys = _latexMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final key in keys) {
      if (_latexMap[key]!.isEmpty) continue;
      r = r.replaceAll(key, _latexMap[key]!);
    }

    final fracRx = RegExp(r'\\frac\{([^{}]*)\}\{([^{}]*)\}');
    for (int pass = 0; pass < 4; pass++) {
      if (!fracRx.hasMatch(r)) break;
      r = r.replaceAllMapped(fracRx, (m) {
        final n = m.group(1)!.trim();
        final d = m.group(2)!.trim();
        return '$n/$d';
      });
    }

    final sqrtBrace = RegExp(r'√\{([^{}]*)\}');
    while (sqrtBrace.hasMatch(r)) {
      r = r.replaceAllMapped(sqrtBrace, (m) => '√(${m.group(1)!})');
    }
    final wrapRx = RegExp(r'\\[a-zA-Z]+\{([^{}]*)\}');
    while (wrapRx.hasMatch(r)) {
      r = r.replaceAllMapped(wrapRx, (m) => m.group(1)!);
    }
    r = r.replaceAll(RegExp(r'\\[a-zA-Z]+'), '');

    r = r.replaceAllMapped(
      RegExp(r'(?<=\w)\^\{([^{}]+)\}'),
      (m) => _toSuperscript(m.group(1)!),
    );
    r = r.replaceAllMapped(
      RegExp(r'(?<=\w)\^([0-9+\-])'),
      (m) => _toSuperscript(m.group(1)!),
    );

    r = r.replaceAllMapped(
      RegExp(r'(?<=[A-Za-z])_\{([^{}]+)\}'),
      (m) => _toSubscript(m.group(1)!),
    );
    r = r.replaceAllMapped(
      RegExp(r'(?<=[A-Za-z])_([0-9])'),
      (m) => _toSubscript(m.group(1)!),
    );

    r = _formatChemicalFormulas(r);
    r = r.replaceAll(r'\$', '\u0024');
    r = r.replaceAll(r'$', '');
    r = r.replaceAll(r'\(', '').replaceAll(r'\)', '');
    r = r.replaceAll(r'\[', '').replaceAll(r'\]', '');
    r = r.replaceAll('^°', '°').replaceAll('^∘', '°').replaceAll('^o', '°');

    return r;
  }
}
