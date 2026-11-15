import os
import re
from langchain_core.tools import tool
from app.services.supabase_client import get_supabase
from app.middleware.auth import get_current_user_id

# ─── Unicode maps and math cleaner ───────────────────────────────────────────

SUPERSCRIPT_MAP = {
    '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴',
    '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹',
    '+': '⁺', '-': '⁻', '=': '⁼', '(': '⁽', ')': '⁾',
    'n': 'ⁿ', 'x': 'ˣ', 'i': 'ⁱ', 'r': 'ʳ', 't': 'ᵗ',
    'a': 'ᵃ', 'b': 'ᵇ', 'c': 'ᶜ', 'd': 'ᵈ', 'e': 'ᵉ',
    'f': 'ᶠ', 'g': 'ᵍ', 'h': 'ʰ', 'j': 'ʲ', 'k': 'ᵏ',
    'l': 'ˡ', 'm': 'ᵐ', 'o': 'ᵒ', 'p': 'ᵖ', 's': 'ˢ',
    'u': 'ᵘ', 'v': 'ᵛ', 'w': 'ʷ', 'y': 'ʸ', 'z': 'ᶻ',
}

SUBSCRIPT_MAP = {
    '0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄',
    '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉',
    '+': '₊', '-': '₋', '=': '₌', '(': '₍', ')': '₎',
    'a': 'ₐ', 'e': 'ₑ', 'i': 'ᵢ', 'j': 'ⱼ', 'k': 'ₖ',
    'l': 'ₗ', 'm': 'ₘ', 'n': 'ₙ', 'o': 'ₒ', 'p': 'ₚ',
    'r': 'ᵣ', 's': 'ₛ', 't': 'ₜ', 'u': 'ᵤ', 'v': 'ᵥ',
    'x': 'ₓ',
}

LATEX_MAP = {
    # Operators
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
    # Arrows
    r'\rightarrow': '→',
    r'\leftarrow':  '←',
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
    # Dots & misc
    r'\ldots':      '…',
    r'\cdots':      '···',
    r'\vdots':      '⋮',
    r'\ddots':      '⋱',
    r'\therefore':  '∴',
    r'\because':    '∵',
    r'\forall':     '∀',
    r'\exists':     '∃',
    # Geometry / trig
    r'\angle':      '∠',
    r'\perp':       '⊥',
    r'\parallel':   '∥',
    r'\circ':       '°',
    r'\degree':     '°',
    r'^\circ':      '°',
    r'^\degree':    '°',
    r'^o':          '°',
    # Calc / analysis
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
    # Named functions
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
    # Lowercase Greek
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
    r'\tau':     'τ',
    r'\upsilon': 'υ',
    r'\phi':     'φ',
    r'\varphi':  'φ',
    r'\chi':     'χ',
    r'\psi':     'ψ',
    r'\omega':   'ω',
    # Uppercase Greek
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
    # Brackets
    r'\lfloor': '⌊', r'\rfloor': '⌋',
    r'\lfloor ': '⌊', r'\rfloor ': '⌋',
    r'\lceil':  '⌈', r'\rceil':  '⌉',
    r'\langle': '⟨', r'\rangle': '⟩',
    # Font wrappers (remove, keep content)
    r'\text':    '',
    r'\mathrm':  '',
    r'\mathbf':  '',
    r'\mathit':  '',
    r'\mathbb':  '',
    r'\boldsymbol': '',
    r'\displaystyle': '',
    r'\textstyle': '',
    # Spacing
    r'\,': ' ', r'\;': ' ', r'\:': ' ', r'\!': '',
    r'\quad': '  ', r'\qquad': '   ',
    # Brackets \left / \right
    r'\left(':  '(',  r'\right)': ')',
    r'\left[':  '[',  r'\right]': ']',
    r'\left\{': '{',  r'\right\}': '}',
    r'\left|':  '|',  r'\right|': '|',
    r'\left':   '',   r'\right':  '',
    # Misc
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
}

def clean_math_to_unicode(text: str) -> str:
    if not text or not isinstance(text, str):
        return text

    # 1. Superscript / Subscript character builders
    def to_superscript(s: str) -> str:
        return "".join(SUPERSCRIPT_MAP.get(c, c) for c in s)

    def to_subscript(s: str) -> str:
        return "".join(SUBSCRIPT_MAP.get(c, c) for c in s)

    # 2. Local cleaner for individual math blocks (delimiters already stripped)
    def clean_single_block(math: str) -> str:
        r = math.strip()
        # wrappers \text{...} etc -> extract content
        r = re.sub(r'\\(?:text|mathrm|mathbf|mathit|mathbb|boldsymbol)\{([^{}]*)\}', r'\1', r)

        # \sqrt{x} -> √(x), \sqrt[n]{x} -> ⁿ√(x)
        r = re.sub(r'\\sqrt\[([^\]]+)\]\{([^{}]*)\}', lambda m: f"{to_superscript(m.group(1))}√({m.group(2)})", r)
        r = re.sub(r'\\sqrt\{([^{}]*)\}', r'√(\1)', r)
        r = r.replace(r'\sqrt', '√')

        # \frac{num}{den} -> num/den
        frac_rx = re.compile(r'\\frac\{([^{}]*)\}\{([^{}]*)\}')
        for _ in range(4):
            if not frac_rx.search(r):
                break
            r = frac_rx.sub(lambda m: f"{m.group(1)}/{m.group(2)}", r)

        # Apply symbol map
        keys = sorted(LATEX_MAP.keys(), key=len, reverse=True)
        for key in keys:
            r = r.replace(key, LATEX_MAP[key])

        # Remove remaining unknown \cmd{...}
        r = re.sub(r'\\[a-zA-Z]+\{([^{}]*)\}', r'\1', r)
        r = re.sub(r'\\[a-zA-Z]+', '', r)

        # Superscripts ^{...} and ^x
        r = re.sub(r'\^\{([^{}]*)\}', lambda m: to_superscript(m.group(1)), r)
        r = re.sub(r'\^([0-9a-zA-Z+\-])', lambda m: to_superscript(m.group(1)), r)

        # Subscripts _{...} and _x
        r = re.sub(r'_\{([^{}]*)\}', lambda m: to_subscript(m.group(1)), r)
        r = re.sub(r'_([0-9a-zA-Z+\-])', lambda m: to_subscript(m.group(1)), r)

        r = r.replace('{', '').replace('}', '')
        r = r.replace('\\\\', ' ')
        return re.sub(r'  +', ' ', r).strip()

    # 3. Main processing loop
    r = text

    # Display math blocks $$...$$ and \[...\]
    r = re.compile(r'\$\$(.+?)\$\$', re.DOTALL).sub(lambda m: f"\n{clean_single_block(m.group(1))}\n", r)
    r = re.compile(r'\\\[(.+?)\\\]', re.DOTALL).sub(lambda m: f"\n{clean_single_block(m.group(1))}\n", r)

    # Inline math blocks $...$ and \(...\)
    r = re.sub(r'\$([^\$\n]+)\$', lambda m: clean_single_block(m.group(1)), r)
    r = re.compile(r'\\\((.+?)\\\)', re.DOTALL).sub(lambda m: clean_single_block(m.group(1)), r)

    # Bare symbols outside delimiters
    keys = sorted(LATEX_MAP.keys(), key=len, reverse=True)
    for key in keys:
        if not LATEX_MAP[key]:
            continue
        r = r.replace(key, LATEX_MAP[key])

    # Bare \frac outside delimiters
    frac_rx = re.compile(r'\\frac\{([^{}]*)\}\{([^{}]*)\}')
    for _ in range(4):
        if not frac_rx.search(r):
            break
        r = frac_rx.sub(lambda m: f"{m.group(1)}/{m.group(2)}", r)

    # Bare \sqrt outside delimiters
    r = re.sub(r'√\{([^{}]*)\}', r'√(\1)', r)
    r = re.sub(r'\\[a-zA-Z]+\{([^{}]*)\}', r'\1', r)
    r = re.sub(r'\\[a-zA-Z]+', '', r)

    # Bare superscripts
    r = re.sub(r'(?<=\w)\^\{([^{}]+)\}', lambda m: to_superscript(m.group(1)), r)
    r = re.sub(r'(?<=\w)\^([0-9+\-])', lambda m: to_superscript(m.group(1)), r)

    # Bare subscripts
    r = re.sub(r'(?<=[A-Za-z])_\{([^{}]+)\}', lambda m: to_subscript(m.group(1)), r)
    r = re.sub(r'(?<=[A-Za-z])_([0-9])', lambda m: to_subscript(m.group(1)), r)

    # Chemical subscripts H2O -> H₂O
    common_chem = {
      'H', 'He', 'Li', 'Be', 'B', 'C', 'N', 'O', 'F', 'Ne',
      'Na', 'Mg', 'Al', 'Si', 'P', 'S', 'Cl', 'Ar', 'K', 'Ca',
      'Sc', 'Ti', 'V', 'Cr', 'Mn', 'Fe', 'Co', 'Ni', 'Cu', 'Zn',
      'Ga', 'Ge', 'As', 'Se', 'Br', 'Kr', 'Rb', 'Sr', 'Y', 'Zr',
      'Ag', 'Cd', 'In', 'Sn', 'Sb', 'Te', 'I', 'Xe',
      'Ba', 'La', 'Ce', 'W', 'Re', 'Os', 'Ir', 'Pt', 'Au', 'Hg',
      'Tl', 'Pb', 'Bi', 'Ra', 'U', 'Pu'
    }
    r = re.sub(r'\b([A-Z][a-z]?)([0-9]+)(?=[A-Z0-9])|\b([A-Z][a-z]?)([0-9]+)\b',
               lambda m: f"{m.group(1) or m.group(3)}{to_subscript(m.group(2) or m.group(4))}" if (m.group(1) or m.group(3)) in common_chem else m.group(0),
               r)

    # Stray dollar signs
    r = r.replace(r'\$', '\u0024')
    r = r.replace('$', '')

    # Leftover bracket wrappers
    r = r.replace(r'\(', '').replace(r'\)', '').replace(r'\[', '').replace(r'\]', '')

    # Caret-degree / caret-circle patterns
    r = r.replace('^°', '°').replace('^∘', '°').replace('^o', '°')

    # Clean up escaped single quotes
    r = r.replace(r"\'", "'")
    
    # Clean up backslash space and stray backslashes
    r = re.sub(r'\\([^\w\s])', r'\1', r)
    r = r.replace(r'\ ', ' ')
    r = r.replace('\\', '')

    return r


def create_document_file(doc_type: str, filename: str, content: str, school_id: str = "") -> dict:
    """Generate a physical document file (PDF, DOCX, XLSX, PPTX, CSV, TXT) and return download URLs."""
    import os as _os
    import re as _re
    raw_ext = doc_type.lower().strip()
    type_aliases = {
        "word": "docx", "doc": "docx", "document": "docx",
        "excel": "xlsx", "xls": "xlsx", "sheet": "xlsx", "spreadsheet": "xlsx",
        "ppt": "pptx", "powerpoint": "pptx", "presentation": "pptx", "slides": "pptx",
        "text": "txt", "notes": "txt", "plain": "txt"
    }
    ext = type_aliases.get(raw_ext, raw_ext)
    base_name = filename.rsplit(".", 1)[0] if "." in filename else filename
    # Sanitize base_name
    base_name = _re.sub(r'[^\w\-_\. ]', '_', base_name).strip() or "document"
    filename = f"{base_name}.{ext}"

    assets_dir = _os.path.join(_os.getcwd(), "assets")
    _os.makedirs(assets_dir, exist_ok=True)
    file_path = _os.path.join(assets_dir, filename)

    try:
        # ──────────────────────────────────────────────────────────────────
        #  PDF Generation – Professional, Beautiful Output
        # ──────────────────────────────────────────────────────────────────
        if ext == "pdf":
            content = clean_math_to_unicode(content)
            import re
            from reportlab.lib.pagesizes import letter
            from reportlab.lib import colors
            from reportlab.lib.units import inch
            from reportlab.lib.enums import TA_LEFT, TA_CENTER, TA_JUSTIFY
            from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
            from reportlab.platypus import (
                SimpleDocTemplate, Paragraph, Spacer, HRFlowable,
                Table, TableStyle, KeepTogether
            )

            # ── Colour palette ────────────────────────────────────────────
            C_PRIMARY = colors.HexColor('#1E1B4B')  # Deep Indigo
            C_BRAND   = colors.HexColor('#4F46E5')  # Vibrant Indigo
            C_ACCENT  = colors.HexColor('#06B6D4')  # Cyan accent
            C_H2      = colors.HexColor('#312E81')
            C_H3      = colors.HexColor('#4338CA')
            C_BODY    = colors.HexColor('#1E293B')  # Slate-800
            C_MUTED   = colors.HexColor('#64748B')  # Slate-500
            C_BORDER  = colors.HexColor('#E2E8F0')  # Slate-200
            C_BG_ALT  = colors.HexColor('#F8FAFC')  # Slate-50
            C_WHITE   = colors.white

            doc = SimpleDocTemplate(
                file_path,
                pagesize=letter,
                rightMargin=0.7 * inch,
                leftMargin=0.7 * inch,
                topMargin=0.75 * inch,
                bottomMargin=0.75 * inch,
            )

            usable_w = letter[0] - 1.4 * inch  # ~504 pt

            styles = getSampleStyleSheet()

            sty_title = ParagraphStyle(
                'DocTitle', parent=styles['Normal'],
                fontSize=20, leading=24, fontName='Helvetica-Bold',
                textColor=C_PRIMARY, alignment=TA_CENTER, spaceAfter=4,
            )
            sty_sub = ParagraphStyle(
                'DocSub', parent=styles['Normal'],
                fontSize=10, leading=14, fontName='Helvetica',
                textColor=C_MUTED, alignment=TA_CENTER, spaceAfter=8,
            )
            sty_h1 = ParagraphStyle(
                'SecH1', parent=styles['Normal'],
                fontSize=13, leading=17, fontName='Helvetica-Bold',
                textColor=C_BRAND, spaceBefore=10, spaceAfter=4,
                keepWithNext=True,
            )
            sty_h2 = ParagraphStyle(
                'SecH2', parent=styles['Normal'],
                fontSize=11.5, leading=15, fontName='Helvetica-Bold',
                textColor=C_H2, spaceBefore=8, spaceAfter=3,
                keepWithNext=True,
            )
            sty_h3 = ParagraphStyle(
                'SecH3', parent=styles['Normal'],
                fontSize=10.5, leading=14, fontName='Helvetica-Bold',
                textColor=C_H3, spaceBefore=6, spaceAfter=2,
                keepWithNext=True,
            )
            sty_h4 = ParagraphStyle(
                'SecH4', parent=styles['Normal'],
                fontSize=10, leading=13, fontName='Helvetica-Bold',
                textColor=C_BODY, spaceBefore=4, spaceAfter=2,
                keepWithNext=True,
            )
            sty_body = ParagraphStyle(
                'Body', parent=styles['Normal'],
                fontSize=10, leading=14.5, fontName='Helvetica',
                textColor=C_BODY, alignment=TA_LEFT, spaceAfter=4,
            )
            sty_bullet = ParagraphStyle(
                'Bul', parent=styles['Normal'],
                fontSize=10, leading=14, fontName='Helvetica',
                textColor=C_BODY, leftIndent=14, spaceAfter=2,
            )
            sty_num = ParagraphStyle(
                'Num', parent=styles['Normal'],
                fontSize=10, leading=14, fontName='Helvetica',
                textColor=C_BODY, leftIndent=14, spaceAfter=2,
            )
            sty_formula = ParagraphStyle(
                'Formula', parent=styles['Normal'],
                fontSize=10.5, leading=15, fontName='Helvetica-Bold',
                textColor=C_PRIMARY, alignment=TA_CENTER,
                backColor=C_BG_ALT,
                borderPadding=(5, 8, 5, 8),
            )
            sty_quote = ParagraphStyle(
                'Quote', parent=styles['Normal'],
                fontSize=11, leading=15, fontName='Helvetica-Oblique',
                textColor=C_MUTED, leftIndent=18,
                spaceBefore=3, spaceAfter=3,
            )
            sty_thead = ParagraphStyle(
                'THead', parent=styles['Normal'],
                fontSize=10, fontName='Helvetica-Bold',
                textColor=C_H2, alignment=TA_CENTER,
            )
            sty_tcell = ParagraphStyle(
                'TCell', parent=styles['Normal'],
                fontSize=10, fontName='Helvetica',
                textColor=C_BODY,
            )

            # ── Page header & footer callback ─────────────────────────────
            def _on_page(canvas, doc):
                canvas.saveState()
                w, h = letter
                # Top rule
                canvas.setStrokeColor(C_BRAND)
                canvas.setLineWidth(2)
                canvas.line(0.7*inch, h - 0.45*inch, w - 0.7*inch, h - 0.45*inch)
                # Footer text
                canvas.setFont('Helvetica', 8)
                canvas.setFillColor(C_MUTED)
                canvas.drawString(0.7*inch, 0.38*inch, "EduSHAMIIT – AI Generated Document")
                canvas.drawRightString(w - 0.7*inch, 0.38*inch, f"Page {doc.page}")
                canvas.restoreState()

            # ── Table parser ──────────────────────────────────────────────
            def build_table(rows_raw: list) -> list:
                """Turn raw markdown table lines into a ReportLab Table."""
                clean = []
                for row in rows_raw:
                    if re.match(r'^\s*\|?[-:| ]+\|?\s*$', row):
                        continue
                    cells = [c.strip() for c in row.strip().strip('|').split('|')]
                    if any(cells):
                        clean.append(cells)
                if not clean:
                    return []

                num_cols = max(len(r) for r in clean)
                for r in clean:
                    while len(r) < num_cols:
                        r.append('')

                col_w = usable_w / num_cols
                col_widths = [col_w] * num_cols

                data = []
                for row_idx, row in enumerate(clean):
                    r_data = []
                    for cell in row:
                        sty = sty_thead if row_idx == 0 else sty_tcell
                        cell_fmt = re.sub(r'\*\*(.*?)\*\*', r'<b>\1</b>', cell)
                        cell_fmt = re.sub(r'\*(.*?)\*', r'<i>\1</i>', cell_fmt)
                        r_data.append(Paragraph(cell_fmt, sty))
                    data.append(r_data)

                t = Table(data, colWidths=col_widths, repeatRows=1)
                t_style = [
                    ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#EEF2FF')),
                    ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
                    ('TOPPADDING', (0, 0), (-1, -1), 4),
                    ('LEFTPADDING', (0, 0), (-1, -1), 6),
                    ('RIGHTPADDING', (0, 0), (-1, -1), 6),
                    ('GRID', (0, 0), (-1, -1), 0.5, C_BORDER),
                    ('LINEBELOW', (0, 0), (-1, 0), 1.5, C_BRAND),
                    ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ]
                for r_i in range(1, len(clean)):
                    if r_i % 2 == 0:
                        t_style.append(('BACKGROUND', (0, r_i), (-1, r_i), C_BG_ALT))
                t.setStyle(TableStyle(t_style))
                return [Spacer(1, 4), t, Spacer(1, 6)]

            def md_to_rl(txt: str) -> str:
                txt = txt.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
                txt = re.sub(r'&lt;b&gt;(.*?)&lt;/b&gt;', r'<b>\1</b>', txt)
                txt = re.sub(r'&lt;i&gt;(.*?)&lt;/i&gt;', r'<i>\1</i>', txt)
                txt = re.sub(r'\*\*\*(.*?)\*\*\*', r'<b><i>\1</i></b>', txt)
                txt = re.sub(r'\*\*(.*?)\*\*', r'<b>\1</b>', txt)
                txt = re.sub(r'\*(.*?)\*', r'<i>\1</i>', txt)
                txt = re.sub(r'`(.*?)`', r'<font name="Courier" color="#312E81"><b>\1</b></font>', txt)
                return txt

            story = []

            # ── Header banner ─────────────────────────────────────────────
            title_text = base_name.replace('_', ' ').replace('-', ' ').title()
            story.append(Paragraph(f"<b>{title_text}</b>", sty_title))
            story.append(Paragraph("EduSHAMIIT Academic &amp; Administrative Management", sty_sub))
            story.append(HRFlowable(width='100%', thickness=2, color=C_BRAND, spaceAfter=10))

            # ── Parse markdown lines ──────────────────────────────────────
            lines = content.split('\n')
            in_table = False
            tbl_buf = []

            i = 0
            while i < len(lines):
                raw = lines[i].rstrip()
                s = raw.strip()

                # Table handling
                if s.startswith('|') and s.endswith('|'):
                    in_table = True
                    tbl_buf.append(raw)
                    i += 1
                    continue
                else:
                    if in_table and tbl_buf:
                        story.extend(build_table(tbl_buf))
                        tbl_buf = []
                        in_table = False

                # Empty line
                if not s:
                    story.append(Spacer(1, 3))
                    i += 1
                    continue

                # Horizontal rule
                if re.match(r'^(\*{3,}|-{3,}|_{3,})$', s):
                    story.append(HRFlowable(width='100%', thickness=0.8,
                                            color=C_BORDER, spaceBefore=4, spaceAfter=4))
                    i += 1
                    continue

                # ── headings ────────────────────────────────────────
                if re.match(r'^#{1} [^#]', raw):
                    text = raw.lstrip('#').strip()
                    story.append(Spacer(1, 6))
                    story.append(Paragraph(md_to_rl(text), sty_h1))
                    story.append(HRFlowable(width='100%', thickness=2,
                                            color=C_BRAND, spaceAfter=8))
                    i += 1
                    continue

                if re.match(r'^#{2} [^#]', raw):
                    text = raw.lstrip('#').strip()
                    story.append(Paragraph(md_to_rl(text), sty_h2))
                    story.append(HRFlowable(width='50%', thickness=1,
                                            color=C_BRAND, spaceAfter=4))
                    i += 1
                    continue

                if re.match(r'^#{3} [^#]', raw):
                    text = raw.lstrip('#').strip()
                    story.append(Paragraph(md_to_rl(text), sty_h3))
                    i += 1
                    continue

                if re.match(r'^#{4,} ', raw):
                    text = raw.lstrip('#').strip()
                    story.append(Paragraph(md_to_rl(text), sty_h4))
                    i += 1
                    continue

                # ── blockquote ──────────────────────────────────────
                if raw.startswith('> '):
                    story.append(Paragraph(md_to_rl(raw[2:].strip()), sty_quote))
                    i += 1
                    continue

                # ── unordered list ───────────────────────────────────
                if re.match(r'^[-*+] ', raw):
                    text = re.sub(r'^[-*+] ', '', raw)
                    story.append(Paragraph(f'• {md_to_rl(text)}', sty_bullet))
                    i += 1
                    continue

                # ── ordered list ─────────────────────────────────────
                m = re.match(r'^(\d+)[.)]\s+(.+)', raw)
                if m:
                    story.append(
                        Paragraph(f'<b>{m.group(1)}.</b>  {md_to_rl(m.group(2))}',
                                  sty_num)
                    )
                    i += 1
                    continue

                # ── normal paragraph ─────────────────────────────────
                story.append(Paragraph(md_to_rl(raw), sty_body))
                i += 1

            if in_table and tbl_buf:
                story.extend(build_table(tbl_buf))

            doc.build(story, onFirstPage=_on_page, onLaterPages=_on_page)

        # ──────────────────────────────────────────────────────────────────
        #  Word Document (.docx) Generation
        # ──────────────────────────────────────────────────────────────────
        elif ext == "docx":
            import docx
            from docx.shared import Inches, Pt, RGBColor
            from docx.enum.text import WD_ALIGN_PARAGRAPH
            from docx.enum.table import WD_TABLE_ALIGNMENT
            from docx.oxml import OxmlElement
            from docx.oxml.ns import qn
            import re

            doc = docx.Document()

            for section in doc.sections:
                section.top_margin = Inches(0.8)
                section.bottom_margin = Inches(0.8)
                section.left_margin = Inches(0.8)
                section.right_margin = Inches(0.8)

            cleaned_content = clean_math_to_unicode(content)

            # Title
            title_p = doc.add_paragraph()
            title_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            title_run = title_p.add_run(base_name.replace('_', ' ').replace('-', ' ').title())
            title_run.font.size = Pt(22)
            title_run.font.bold = True
            title_run.font.color.rgb = RGBColor(0x1E, 0x1B, 0x4B)

            sub_p = doc.add_paragraph()
            sub_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            sub_run = sub_p.add_run("EduSHAMIIT — Academic & Administrative Document")
            sub_run.font.size = Pt(10)
            sub_run.font.color.rgb = RGBColor(0x64, 0x74, 0x8B)
            sub_run.font.italic = True
            doc.add_paragraph()

            in_table = False
            table_lines = []

            def _flush_docx_table(t_lines):
                if not t_lines:
                    return
                rows = []
                for line in t_lines:
                    if re.match(r'^\s*\|?[-:| ]+\|?\s*$', line):
                        continue
                    cells = [c.strip() for c in line.strip().strip('|').split('|')]
                    if any(cells):
                        rows.append(cells)
                if not rows:
                    return
                cols = max(len(r) for r in rows)
                t = doc.add_table(rows=len(rows), cols=cols)
                t.alignment = WD_TABLE_ALIGNMENT.CENTER
                for r_idx, row in enumerate(rows):
                    for c_idx, cell_text in enumerate(row):
                        if c_idx < cols:
                            cell = t.cell(r_idx, c_idx)
                            cell.text = cell_text
                            p = cell.paragraphs[0]
                            p.alignment = WD_ALIGN_PARAGRAPH.LEFT
                            if r_idx == 0:
                                for r in p.runs:
                                    r.font.bold = True
                                    r.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
                                tcPr = cell._tc.get_or_add_tcPr()
                                shd = OxmlElement('w:shd')
                                shd.set(qn('w:val'), 'clear')
                                shd.set(qn('w:color'), 'auto')
                                shd.set(qn('w:fill'), '4F46E5')
                                tcPr.append(shd)
                doc.add_paragraph()

            for line in cleaned_content.split('\n'):
                trimmed = line.strip()
                if not trimmed:
                    continue

                if trimmed.startswith('|') and trimmed.endswith('|'):
                    in_table = True
                    table_lines.append(trimmed)
                    continue
                else:
                    if in_table:
                        _flush_docx_table(table_lines)
                        table_lines = []
                        in_table = False

                if trimmed.startswith('# '):
                    doc.add_heading(trimmed[2:].strip(), level=1)
                elif trimmed.startswith('## '):
                    doc.add_heading(trimmed[3:].strip(), level=2)
                elif trimmed.startswith('### '):
                    doc.add_heading(trimmed[4:].strip(), level=3)
                elif trimmed.startswith('- ') or trimmed.startswith('* '):
                    doc.add_paragraph(trimmed[2:].strip(), style='List Bullet')
                elif re.match(r'^\d+\.\s', trimmed):
                    text_part = re.sub(r'^\d+\.\s*', '', trimmed)
                    doc.add_paragraph(text_part, style='List Number')
                elif trimmed.startswith('> '):
                    p = doc.add_paragraph(trimmed[2:].strip())
                    p.paragraph_format.left_indent = Inches(0.4)
                    for run in p.runs:
                        run.font.italic = True
                        run.font.color.rgb = RGBColor(0x47, 0x55, 0x69)
                else:
                    doc.add_paragraph(trimmed)

            if in_table:
                _flush_docx_table(table_lines)

            doc.save(file_path)

        # ──────────────────────────────────────────────────────────────────
        #  PowerPoint (.pptx) Generation
        # ──────────────────────────────────────────────────────────────────
        elif ext == "pptx":
            import pptx
            from pptx.util import Inches, Pt
            from pptx.dml.color import RGBColor
            from pptx.enum.text import PP_ALIGN
            import re

            prs = pptx.Presentation()
            prs.slide_width = Inches(13.333)
            prs.slide_height = Inches(7.5)
            blank_layout = prs.slide_layouts[6]

            cleaned_content = clean_math_to_unicode(content)

            # Slide 1: Title Slide
            title_slide = prs.slides.add_slide(blank_layout)
            t_shape = title_slide.shapes.add_shape(1, 0, 0, Inches(13.333), Inches(7.5))
            t_shape.fill.solid()
            t_shape.fill.fore_color.rgb = RGBColor(0x0F, 0x17, 0x2A)
            t_shape.line.color.rgb = RGBColor(0x0F, 0x17, 0x2A)

            txBox = title_slide.shapes.add_textbox(Inches(1.5), Inches(2.2), Inches(10.333), Inches(3.0))
            tf = txBox.text_frame
            tf.word_wrap = True
            p = tf.paragraphs[0]
            p.text = base_name.replace('_', ' ').replace('-', ' ').title()
            p.font.size = Pt(40)
            p.font.bold = True
            p.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
            p.alignment = PP_ALIGN.CENTER

            p2 = tf.add_paragraph()
            p2.text = "EduSHAMIIT — Interactive Academic Presentation"
            p2.font.size = Pt(20)
            p2.font.color.rgb = RGBColor(0x81, 0x8C, 0xF8)
            p2.alignment = PP_ALIGN.CENTER
            p2.space_before = Pt(16)

            # Parse content into slides
            slide_sections = []
            curr_title = "Overview"
            curr_bullets = []

            for line in cleaned_content.split('\n'):
                trimmed = line.strip()
                if not trimmed:
                    continue
                if trimmed.startswith('# ') or trimmed.startswith('## '):
                    if curr_bullets or curr_title != "Overview":
                        slide_sections.append((curr_title, curr_bullets))
                    curr_title = trimmed.lstrip('#').strip()
                    curr_bullets = []
                elif trimmed.startswith('- ') or trimmed.startswith('* '):
                    curr_bullets.append(trimmed[2:].strip())
                elif re.match(r'^\d+\.\s', trimmed):
                    curr_bullets.append(re.sub(r'^\d+\.\s*', '', trimmed))
                elif not trimmed.startswith('|') and not trimmed.startswith('---'):
                    curr_bullets.append(trimmed)

            if curr_bullets or curr_title:
                slide_sections.append((curr_title, curr_bullets))

            if not slide_sections:
                slide_sections.append(("Content", [cleaned_content[:400]]))

            for s_title, s_bullets in slide_sections:
                slide = prs.slides.add_slide(blank_layout)
                bg = slide.shapes.add_shape(1, 0, 0, Inches(13.333), Inches(7.5))
                bg.fill.solid()
                bg.fill.fore_color.rgb = RGBColor(0x1E, 0x29, 0x3B)
                bg.line.color.rgb = RGBColor(0x1E, 0x29, 0x3B)

                h_box = slide.shapes.add_textbox(Inches(1.0), Inches(0.8), Inches(11.333), Inches(1.2))
                h_tf = h_box.text_frame
                h_tf.word_wrap = True
                hp = h_tf.paragraphs[0]
                hp.text = s_title
                hp.font.size = Pt(28)
                hp.font.bold = True
                hp.font.color.rgb = RGBColor(0x60, 0xA5, 0xFA)

                b_box = slide.shapes.add_textbox(Inches(1.0), Inches(2.2), Inches(11.333), Inches(4.5))
                b_tf = b_box.text_frame
                b_tf.word_wrap = True
                for b_idx, bullet in enumerate(s_bullets[:7]):
                    bp = b_tf.paragraphs[0] if b_idx == 0 else b_tf.add_paragraph()
                    bp.text = f"•  {bullet}"
                    bp.font.size = Pt(18)
                    bp.font.color.rgb = RGBColor(0xF1, 0xF5, 0xF9)
                    bp.space_after = Pt(12)

            prs.save(file_path)

        # ──────────────────────────────────────────────────────────────────
        #  Excel (.xlsx) Generation
        # ──────────────────────────────────────────────────────────────────
        elif ext == "xlsx":
            import json
            import openpyxl
            from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
            from openpyxl.utils import get_column_letter

            wb = openpyxl.Workbook()
            ws = wb.active
            ws.title = "Report"
            cleaned_content = clean_math_to_unicode(content)

            table_rows = []
            try:
                data = json.loads(cleaned_content)
                if isinstance(data, list):
                    for row in data:
                        if isinstance(row, list):
                            table_rows.append([str(c) for c in row])
                        elif isinstance(row, dict):
                            if not table_rows:
                                table_rows.append(list(row.keys()))
                            table_rows.append([str(v) for v in row.values()])
            except Exception:
                pass

            if not table_rows:
                for line in cleaned_content.split('\n'):
                    trimmed = line.strip()
                    if not trimmed or trimmed.startswith('---'):
                        continue
                    if '|' in trimmed:
                        cells = [c.strip() for c in trimmed.split('|')]
                        if len(cells) > 2:
                            cells = cells[1:-1]
                        if cells and not all(set(c).issubset({'-', ':', ' '}) for c in cells):
                            table_rows.append(cells)
                    elif ',' in trimmed and not trimmed.startswith('•') and not trimmed.startswith('-'):
                        table_rows.append([c.strip() for c in trimmed.split(',')])

            # Special enrichment: If table_rows is empty or <= 4 summary rows,
            # and the report is about fees/defaulters, pull the full live student invoice roster!
            is_fee_query = any(k in filename.lower() or k in content.lower() for k in ["fee", "defaulter", "due", "dues"])
            if (len(table_rows) <= 4 or len(table_rows[0]) <= 2) and is_fee_query:
                try:
                    from app.services.supabase_client import get_supabase
                    sb = get_supabase()
                    invoices_res = sb.table("student_fee_invoices").select(
                        "id, invoice_number, title, fee_type, fee_plan, total_billed, paid_amount, balance_amount, status, due_date, student_id, profiles:student_id(full_name, class, roll_number, admission_number, phone)"
                    ).in_("status", ["Pending", "Partial", "Overdue"]).order("balance_amount", ascending=False).limit(100).execute()
                    
                    raw_invs = invoices_res.data or []
                    if raw_invs:
                        ws.title = "Pending Fees Roster"
                        # Header Banner
                        ws.merge_cells("A1:K1")
                        t_cell = ws["A1"]
                        t_cell.value = "EduSHAMIIT — Student Fee Defaulters & Outstanding Balances Roster"
                        t_cell.font = Font(name="Calibri", size=14, bold=True, color="FFFFFF")
                        t_cell.fill = PatternFill("solid", fgColor="1E1B4B")
                        t_cell.alignment = Alignment(horizontal="center", vertical="center")
                        ws.row_dimensions[1].height = 30

                        tot_dues = sum(float(r.get("balance_amount") or 0.0) for r in raw_invs)
                        ws.merge_cells("A2:K2")
                        s_cell = ws["A2"]
                        s_cell.value = f"Total Pending Students: {len(raw_invs)}  |  Total Outstanding Dues: ₹ {tot_dues:,.2f}  |  Official School ERP Export"
                        s_cell.font = Font(name="Calibri", size=10, italic=True, color="475569")
                        s_cell.fill = PatternFill("solid", fgColor="F1F5F9")
                        s_cell.alignment = Alignment(horizontal="center", vertical="center")
                        ws.row_dimensions[2].height = 20

                        fee_headers = [
                            "Student Name", "Class", "Roll No", "Admission No", "Fee Type",
                            "Billing Plan", "Total Billed (₹)", "Paid Amount (₹)", "Pending Balance (₹)", "Status", "Due Date"
                        ]
                        h_fill = PatternFill("solid", fgColor="4F46E5")
                        h_font = Font(name="Calibri", size=11, bold=True, color="FFFFFF")
                        h_align = Alignment(horizontal="center", vertical="center")
                        for c_idx, h_name in enumerate(fee_headers, 1):
                            c = ws.cell(row=4, column=c_idx, value=h_name)
                            c.fill = h_fill
                            c.font = h_font
                            c.alignment = h_align
                        ws.row_dimensions[4].height = 24

                        odd_fill = PatternFill("solid", fgColor="F8FAFC")
                        even_fill = PatternFill("solid", fgColor="FFFFFF")
                        thin_b = Border(
                            left=Side(style='thin', color='E2E8F0'),
                            right=Side(style='thin', color='E2E8F0'),
                            top=Side(style='thin', color='E2E8F0'),
                            bottom=Side(style='thin', color='E2E8F0')
                        )

                        for r_idx, inv in enumerate(raw_invs, 5):
                            p = inv.get("profiles") or {}
                            s_name = p.get("full_name") or "Student"
                            s_cls = p.get("class") or "General"
                            s_roll = str(p.get("roll_number") or "-")
                            s_adm = p.get("admission_number") or f"ADM-{str(inv.get('student_id'))[:6]}"
                            s_ftype = inv.get("fee_type") or "Tuition Fee"
                            s_fplan = inv.get("fee_plan") or "Monthly"
                            s_billed = float(inv.get("total_billed") or 0.0)
                            s_paid = float(inv.get("paid_amount") or 0.0)
                            s_bal = float(inv.get("balance_amount") or 0.0)
                            s_status = inv.get("status") or "Pending"
                            s_due = str(inv.get("due_date") or "-")

                            row_data = [s_name, s_cls, s_roll, s_adm, s_ftype, s_fplan, s_billed, s_paid, s_bal, s_status, s_due]
                            row_fill = odd_fill if (r_idx % 2 == 1) else even_fill

                            for c_idx, val in enumerate(row_data, 1):
                                c = ws.cell(row=r_idx, column=c_idx, value=val)
                                c.fill = row_fill
                                c.border = thin_b
                                if c_idx in (7, 8, 9):
                                    c.number_format = '"₹"#,##0.00'
                                    c.alignment = Alignment(horizontal="right", vertical="center")
                                elif c_idx in (2, 3, 4, 10, 11):
                                    c.alignment = Alignment(horizontal="center", vertical="center")
                                else:
                                    c.alignment = Alignment(horizontal="left", vertical="center")

                                if c_idx == 10:
                                    if s_status == "Overdue":
                                        c.font = Font(name="Calibri", bold=True, color="DC2626")
                                    elif s_status == "Partial":
                                        c.font = Font(name="Calibri", bold=True, color="D97706")
                                    else:
                                        c.font = Font(name="Calibri", bold=True, color="2563EB")

                        for c_idx in range(1, len(fee_headers) + 1):
                            m_len = 0
                            for r_idx in range(4, 5 + len(raw_invs)):
                                v_str = str(ws.cell(row=r_idx, column=c_idx).value or "")
                                if len(v_str) > m_len:
                                    m_len = len(v_str)
                            ws.column_dimensions[get_column_letter(c_idx)].width = max(m_len + 4, 15)

                        table_rows = []  # marked as processed
                except Exception as fee_err:
                    print(f"Fee enrichment error: {fee_err}")

            if table_rows:
                for row_idx, row_vals in enumerate(table_rows, 1):
                    for col_idx, val in enumerate(row_vals, 1):
                        cell = ws.cell(row=row_idx, column=col_idx, value=val)
                        if row_idx == 1:
                            cell.font = Font(bold=True, color="FFFFFF")
                            cell.fill = PatternFill("solid", fgColor="4F46E5")
                            cell.alignment = Alignment(horizontal="center", vertical="center")
                        elif row_idx % 2 == 0:
                            cell.fill = PatternFill("solid", fgColor="F8FAFC")

                for col_idx in range(1, max(len(r) for r in table_rows) + 1):
                    max_len = max((len(str(ws.cell(row=r, column=col_idx).value or '')) for r in range(1, len(table_rows) + 1)), default=0)
                    ws.column_dimensions[get_column_letter(col_idx)].width = max(min(max_len + 4, 50), 12)

            wb.save(file_path)
        # ──────────────────────────────────────────────────────────────────
        #  CSV Generation
        # ──────────────────────────────────────────────────────────────────
        elif ext == "csv":
            import json
            import csv
            cleaned_content = clean_math_to_unicode(content)
            with open(file_path, mode='w', newline='', encoding='utf-8') as f:
                writer = csv.writer(f)
                try:
                    data = json.loads(cleaned_content)
                    if isinstance(data, list):
                        for row in data:
                            if isinstance(row, list):
                                writer.writerow([str(val) for val in row])
                            else:
                                writer.writerow([str(row)])
                    else:
                        writer.writerow([cleaned_content])
                except Exception:
                    for line in cleaned_content.split('\n'):
                        if '|' in line:
                            cells = [c.strip() for c in line.split('|')]
                            if len(cells) > 2:
                                cells = cells[1:-1]
                            if cells and not all(set(c).issubset({'-', ':', ' '}) for c in cells):
                                writer.writerow(cells)
                        else:
                            writer.writerow([c.strip() for c in line.split(',')])

        # ──────────────────────────────────────────────────────────────────
        #  Plain text / Notes fallback (.txt)
        # ──────────────────────────────────────────────────────────────────
        else:
            cleaned_content = clean_math_to_unicode(content)
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(cleaned_content)

        # ── Auto-save to Documents Hub ────────────────────────────────────
        try:
            import uuid
            from app.middleware.auth import get_current_user_id
            user_id = get_current_user_id()
            if user_id:
                with open(file_path, "rb") as f:
                    file_bytes = f.read()
                file_size = len(file_bytes)
                doc_id = str(uuid.uuid4())
                storage_path = f"documents/{school_id}/{user_id}/{doc_id}.{ext}"
                from app.config import settings
                import httpx
                import mimetypes
                supabase_url = settings.SUPABASE_URL.rstrip("/")
                storage_url = f"{supabase_url}/storage/v1/object/{storage_path}"
                mime = mimetypes.guess_type(filename)[0] or "application/octet-stream"
                headers = {
                    "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
                    "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
                    "Content-Type": mime,
                    "x-upsert": "true",
                }
                with httpx.Client(timeout=30.0) as http_client:
                    upload_response = http_client.post(storage_url, headers=headers, content=file_bytes)
                if upload_response.status_code in (200, 201):
                    from app.middleware.auth import get_public_supabase_url
                    public_url_base = get_public_supabase_url(supabase_url)
                    file_url = f"{public_url_base}/storage/v1/object/public/{storage_path}"
                    from app.services.supabase_client import get_supabase
                    sb = get_supabase()
                    clean_title = filename.rsplit(".", 1)[0].replace("_", " ").title()
                    record = {
                        "id": doc_id,
                        "school_id": school_id,
                        "owner_id": user_id,
                        "title": clean_title,
                        "description": f"AI generated {ext.upper()} document.",
                        "category": "ai_generated",
                        "file_url": file_url,
                        "file_name": filename,
                        "file_size": file_size,
                        "mime_type": mime,
                        "storage_path": storage_path,
                    }
                    sb.table("user_documents").insert(record).execute()
                    print(f"Auto-saved document {filename} for user {user_id}.")
        except Exception as auto_save_err:
            print(f"Auto-save error: {auto_save_err}")

        download_url = f"/api/chat/download/{filename}"
        return {
            "success": True,
            "filename": filename,
            "download_url": download_url,
            "markdown_link": f"[Download {filename}]({download_url})",
            "result": f"I have successfully generated your document! You can download it here: [Download {filename}]({download_url})"
        }
    except Exception as e:
        return {"success": False, "error": str(e)}


def get_academic_tools(school_id: str):
    """Return academic AI tools scoped to this school."""

    def _llm():
        from langchain_google_genai import ChatGoogleGenerativeAI
        return ChatGoogleGenerativeAI(
            model=os.getenv("GEMINI_MODEL", "gemini-1.5-flash"),
            temperature=0.7,
            google_api_key=os.getenv("GOOGLE_API_KEY", ""),
        )

    @tool
    def generate_questions(
        subject: str,
        topic: str,
        difficulty: str = "medium",
        num_questions: int = 5,
        question_type: str = "mcq",
    ) -> dict:
        """Generate exam or practice questions for a subject and topic using AI.
        Input: subject name, topic, difficulty (easy/medium/hard),
        number of questions (default 5), question type (mcq/short_answer/long_answer).
        Use when a teacher asks to create questions, make a quiz, or generate test paper."""
        try:
            llm = _llm()
            from langchain_core.messages import HumanMessage
            q_type = question_type.replace("_", " ")
            prompt = (
                f"Generate {num_questions} {q_type} questions for {subject} "
                f"on the topic \"{topic}\" at {difficulty} difficulty level. "
                "For each question provide: question text, options (if MCQ, 4 choices), "
                "the correct answer, and a brief explanation. "
                "Format as a clean numbered list. NCERT-aligned."
            )
            response = llm.invoke([HumanMessage(content=prompt)])
            return {
                "success": True,
                "subject": subject,
                "topic": topic,
                "difficulty": difficulty,
                "question_type": question_type,
                "questions": response.content,
            }
        except Exception as e:
            return {"success": False, "error": str(e)}

    @tool
    def create_lesson_plan(
        subject: str,
        topic: str,
        grade: str,
        duration_minutes: int = 40,
        learning_objectives: str = "",
    ) -> dict:
        """Create a detailed lesson plan for a teacher using AI.
        Input: subject, topic, grade/class, duration in minutes (default 40),
        optional learning objectives.
        Use when a teacher asks for a lesson plan, teaching plan, or class preparation."""
        try:
            llm = _llm()
            from langchain_core.messages import HumanMessage
            obj = f" with learning objectives: {learning_objectives}" if learning_objectives else ""
            prompt = (
                f"Create a detailed {duration_minutes}-minute lesson plan for {subject} "
                f"on the topic \"{topic}\" for Grade {grade}{obj}. "
                "Include: Learning Objectives, Materials Needed, Lesson Structure "
                "with time allocation, Activities, Differentiation strategies, "
                "Assessment methods, and Homework. "
                "Make it practical and NCERT-aligned."
            )
            response = llm.invoke([HumanMessage(content=prompt)])
            return {
                "success": True,
                "subject": subject,
                "topic": topic,
                "grade": grade,
                "duration_minutes": duration_minutes,
                "lesson_plan": response.content,
            }
        except Exception as e:
            return {"success": False, "error": str(e)}

    @tool
    def get_timetable(class_name: str = "", teacher_id: str = "") -> dict:
        """Get the school timetable for a class or teacher.
        Input: class_name (e.g. '10A') or teacher_id (UUID), or both.
        Use when a teacher or admin asks about the class schedule or teacher timetable."""
        try:
            supabase = get_supabase()
            query = supabase.table("timetable").select("*, subjects(name, color), profiles!teacher_id(full_name)").eq("school_id", school_id)
            if class_name:
                c_clean = str(class_name).replace("Class", "").replace("class", "").strip()
                query = query.ilike("class", f"%{c_clean}%")
            if teacher_id:
                query = query.eq("teacher_id", teacher_id)
            resp = query.order("day_of_week").order("start_time").execute()
            entries = resp.data or []
            days_names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
            timetable: dict = {}
            for entry in entries:
                dow = entry.get("day_of_week", 0)
                day = days_names[dow] if 0 <= dow < len(days_names) else f"Day {dow}"
                if day not in timetable:
                    timetable[day] = []
                subj = entry.get("subjects") or {}
                prof = entry.get("profiles") or {}
                timetable[day].append({
                    "class": entry.get("class", ""),
                    "subject": subj.get("name") or "Core Subject",
                    "teacher": prof.get("full_name", ""),
                    "room": entry.get("room", "Room 302"),
                    "start_time": str(entry.get("start_time", "")),
                    "end_time": str(entry.get("end_time", "")),
                })
            return {
                "success": True,
                "class_name": class_name,
                "teacher_id": teacher_id,
                "timetable": timetable,
                "total_entries": len(entries),
            }
        except Exception as e:
            return {"success": False, "error": str(e)}

    @tool
    def generate_image(prompt: str) -> dict:
        """Generate a beautiful, premium, watermark-free image or academic formula infographic.
        Input: a clear description of the image to generate.
        Use when the user asks to draw, generate, show, create, or display an image, picture, formula sheet, chart, or illustration in chat."""
        try:
            from app.services.image_studio_service import generate_custom_image
            return generate_custom_image(prompt)
        except Exception as e:
            import urllib.parse
            encoded = urllib.parse.quote(prompt.strip())
            url = f"https://image.pollinations.ai/prompt/{encoded}?width=800&height=800&nologo=true"
            markdown_link = f"![Generated Image]({url})"
            return {
                "success": True,
                "prompt": prompt,
                "image_url": url,
                "markdown": markdown_link,
                "result": f"Here is your generated image:\n\n{markdown_link}\n\n*Prompt: {prompt}*"
            }

    @tool
    def generate_document(doc_type: str, filename: str, content: str) -> dict:
        """Generate a document (PDF, Word docx, Excel spreadsheet, PowerPoint pptx, CSV, or text file) for download.
        Input:
          - doc_type: 'pdf', 'docx', 'xlsx', 'pptx', 'csv', or 'txt'
          - filename: preferred name of the file (e.g. 'lesson_plan.pdf', 'grades.xlsx', 'lecture_slides.pptx', 'notes.docx')
          - content: structured text or formatted data in Markdown:
            - For PDF / DOCX / PPTX / TXT: formatted Markdown text with headers (#, ##), bullet points (-), bold (**text**), tables (| col |), and key formulas.
            - For Excel (xlsx) / CSV: structured JSON rows or Markdown table format.
        Use when a user asks to generate, export, download, or create a PDF, Word document, Excel spreadsheet, PowerPoint slides, or text document."""
        return create_document_file(doc_type=doc_type, filename=filename, content=content, school_id=school_id)

    return [generate_questions, create_lesson_plan, get_timetable, generate_image, generate_document]