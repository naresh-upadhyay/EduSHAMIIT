"""
Offer Letter PDF Generator for EduSHAMIIT ERP.
Generates institutional, print-ready, professional employment offer letters
matching the Preview Offer Letter design.
"""
import io
import re
from datetime import datetime, date
from typing import Optional
from reportlab.lib.pagesizes import A4
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, HRFlowable, KeepTogether
)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib import colors


def _clean_currency(val: Optional[str]) -> float:
    if not val:
        return 0.0
    try:
        clean = re.sub(r"[^\d.]", "", str(val))
        return float(clean) if clean else 0.0
    except Exception:
        return 0.0


def _clean_text(val: Optional[str]) -> str:
    if not val:
        return ""
    # Standard Helvetica fonts in PDF generators lack the Unicode ₹ glyph (U+20B9).
    # Replace with standard INR to prevent PDF readers from displaying solid missing-glyph color blocks.
    return str(val).replace("₹", "INR ")


def generate_offer_letter_pdf(
    candidate_name: str,
    job_title: str,
    school_name: str,
    salary: Optional[str] = None,
    joining_date: Optional[str] = None,
    employment_type: Optional[str] = None,
    probation_period_months: Optional[int] = 6,
    benefits: Optional[str] = None,
    offer_expiry_date: Optional[str] = None,
    terms: Optional[str] = None,
    application_reference: Optional[str] = None,
    to_email: Optional[str] = None
) -> bytes:
    """
    Generate a high-resolution, professional PDF offer letter using ReportLab.
    Returns the generated PDF as raw bytes.
    """
    buf = io.BytesIO()
    # A4: 595.27 x 841.89 points. Margins: 40pt left/right/top/bottom
    doc = SimpleDocTemplate(
        buf,
        pagesize=A4,
        leftMargin=40,
        rightMargin=40,
        topMargin=36,
        bottomMargin=36
    )

    styles = getSampleStyleSheet()

    # Color Palette
    primary_color = colors.HexColor("#1E1B4B")  # Deep Navy/Indigo
    brand_color = colors.HexColor("#4F46E5")    # Indigo
    emerald_color = colors.HexColor("#059669")  # Emerald
    text_dark = colors.HexColor("#0F172A")      # Slate 900
    text_muted = colors.HexColor("#64748B")     # Slate 500
    table_bg = colors.HexColor("#F8FAFC")       # Slate 50
    table_border = colors.HexColor("#CBD5E1")   # Slate 300

    # Typography Styles
    school_title_style = ParagraphStyle(
        'SchoolTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=17,
        leading=21,
        textColor=primary_color
    )

    directorate_style = ParagraphStyle(
        'Directorate',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9,
        leading=12,
        textColor=text_muted
    )

    ref_style = ParagraphStyle(
        'RefStyle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=9.5,
        leading=13,
        alignment=2,  # Right aligned
        textColor=brand_color
    )

    date_style = ParagraphStyle(
        'DateStyle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9,
        leading=12,
        alignment=2,  # Right aligned
        textColor=text_muted
    )

    subject_style = ParagraphStyle(
        'SubjectStyle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=11,
        leading=14,
        textColor=brand_color
    )

    body_style = ParagraphStyle(
        'LetterBody',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9.5,
        leading=14.5,
        textColor=text_dark
    )

    body_bold = ParagraphStyle(
        'LetterBodyBold',
        parent=body_style,
        fontName='Helvetica-Bold'
    )

    table_header_style = ParagraphStyle(
        'TableHeader',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=10,
        leading=13,
        textColor=primary_color
    )

    table_label_style = ParagraphStyle(
        'TableLabel',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8.5,
        leading=11.5,
        textColor=text_muted
    )

    table_val_style = ParagraphStyle(
        'TableVal',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9,
        leading=12,
        textColor=text_dark
    )

    salary_monthly_style = ParagraphStyle(
        'SalMonthly',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=12,
        leading=15,
        textColor=emerald_color
    )

    salary_annual_style = ParagraphStyle(
        'SalAnnual',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=11,
        leading=14,
        textColor=brand_color
    )

    sign_title_style = ParagraphStyle(
        'SignTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=9.5,
        leading=13,
        textColor=text_dark
    )

    sign_sub_style = ParagraphStyle(
        'SignSub',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8.5,
        leading=11,
        textColor=text_muted
    )

    footer_style = ParagraphStyle(
        'FooterStyle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=7.5,
        leading=10,
        alignment=1,  # Centered
        textColor=text_muted
    )

    # Format salary calculations
    sal_num = _clean_currency(salary)
    monthly_disp = f"INR {sal_num:,.2f} / month" if sal_num > 0 else (_clean_text(salary) or "As negotiated")
    annual_ctc_disp = f"INR {sal_num * 12:,.2f} per annum" if sal_num > 0 else "Competitive Package"
    probation_disp = f"{probation_period_months} Months" if probation_period_months else "6 Months"
    joining_disp = _clean_text(joining_date) or "To be mutually agreed"
    expiry_disp = _clean_text(offer_expiry_date) or "Within 7 calendar days"
    ref_disp = _clean_text(application_reference) or "EDU-REC-2026"
    today_disp = datetime.now().strftime("%d %B %Y")

    story = []

    # 1. INSTITUTIONAL LETTERHEAD
    header_data = [
        [
            Paragraph(f"<b>{school_name.upper()}</b>", school_title_style),
            Paragraph(f"<b>REF:</b> {ref_disp}", ref_style)
        ],
        [
            Paragraph("Directorate of Human Resources & Faculty Development", directorate_style),
            Paragraph(f"<b>Date:</b> {today_disp}", date_style)
        ]
    ]
    header_table = Table(header_data, colWidths=[335, 180])
    header_table.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
        ('TOPPADDING', (0, 0), (-1, -1), 0),
        ('LEFTPADDING', (0, 0), (-1, -1), 0),
        ('RIGHTPADDING', (0, 0), (-1, -1), 0),
    ]))
    story.append(header_table)

    story.append(Spacer(1, 8))
    story.append(HRFlowable(width="100%", thickness=2, color=brand_color, spaceBefore=4, spaceAfter=14))

    # 2. ADDRESSEE DETAILS
    to_text = f"<b>To,</b><br/><b>{candidate_name}</b>"
    if to_email:
        to_text += f"<br/><font color='#64748B'>{to_email}</font>"
    story.append(Paragraph(to_text, body_style))
    story.append(Spacer(1, 12))

    # 3. SUBJECT BANNER
    subject_table = Table(
        [[Paragraph(f"<b>SUB: FORMAL EMPLOYMENT OFFER — {job_title.upper()}</b>", subject_style)]],
        colWidths=[515]
    )
    subject_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor("#EEF2FF")),
        ('LEFTPADDING', (0, 0), (-1, -1), 12),
        ('RIGHTPADDING', (0, 0), (-1, -1), 12),
        ('TOPPADDING', (0, 0), (-1, -1), 8),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
        ('BOX', (0, 0), (-1, -1), 1, colors.HexColor("#C7D2FE")),
    ]))
    story.append(subject_table)
    story.append(Spacer(1, 12))

    # 4. SALUTATION & OPENING
    story.append(Paragraph(f"Dear <b>{candidate_name}</b>,", body_style))
    story.append(Spacer(1, 6))
    intro_text = (
        f"Following your successful evaluations, interview rounds, and pedagogical assessments throughout our recruitment "
        f"selection process, we are pleased to extend this formal offer of employment for the position of "
        f"<b>{job_title}</b> at <b>{school_name}</b>. Our academic leadership and management committee have been "
        f"thoroughly impressed by your qualifications, subject mastery, and dedication to educational excellence."
    )
    story.append(Paragraph(intro_text, body_style))
    story.append(Spacer(1, 12))

    # 5. REMUNERATION & EMPLOYMENT TERMS TABLE
    comp_data = [
        [
            Paragraph("<b>SUMMARY OF COMPENSATION & TERMS</b>", table_header_style),
            ""
        ],
        [
            Paragraph("Monthly Gross Salary", table_label_style),
            Paragraph(monthly_disp, salary_monthly_style)
        ],
        [
            Paragraph("Annual Cost to Company (CTC)", table_label_style),
            Paragraph(annual_ctc_disp, salary_annual_style)
        ],
        [
            Paragraph("Position / Designation", table_label_style),
            Paragraph(f"<b>{job_title}</b>", table_val_style)
        ],
        [
            Paragraph("Employment Type", table_label_style),
            Paragraph(employment_type or "Full-time", table_val_style)
        ],
        [
            Paragraph("Expected Date of Commencement", table_label_style),
            Paragraph(f"<b>{joining_disp}</b>", table_val_style)
        ],
        [
            Paragraph("Probation Period", table_label_style),
            Paragraph(probation_disp, table_val_style)
        ],
        [
            Paragraph("Offer Acceptance Deadline", table_label_style),
            Paragraph(f"<b>{expiry_disp}</b>", table_val_style)
        ]
    ]

    if benefits and benefits.strip():
        comp_data.append([
            Paragraph("Benefits & Allowances", table_label_style),
            Paragraph(_clean_text(benefits.strip()).replace("\n", "<br/>"), table_val_style)
        ])

    if terms and terms.strip():
        comp_data.append([
            Paragraph("Specific Terms & Conditions", table_label_style),
            Paragraph(_clean_text(terms.strip()).replace("\n", "<br/>"), table_val_style)
        ])

    comp_table = Table(comp_data, colWidths=[180, 335])
    comp_table.setStyle(TableStyle([
        ('SPAN', (0, 0), (1, 0)),
        ('BACKGROUND', (0, 0), (1, 0), colors.HexColor("#F1F5F9")),
        ('BACKGROUND', (0, 1), (-1, -1), table_bg),
        ('BOX', (0, 0), (-1, -1), 1, table_border),
        ('INNERGRID', (0, 0), (-1, -1), 0.5, table_border),
        ('TOPPADDING', (0, 0), (-1, -1), 6),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('LEFTPADDING', (0, 0), (-1, -1), 10),
        ('RIGHTPADDING', (0, 0), (-1, -1), 10),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
    ]))
    story.append(comp_table)
    story.append(Spacer(1, 12))

    # 6. CONDITIONS & POLICIES
    terms_clause = (
        "<b>Conditions of Employment:</b><br/>"
        "1. This appointment is subject to the formal verification of all original educational degrees, experience certificates, and identity records.<br/>"
        "2. You will be expected to adhere to the institution's professional code of conduct, academic calendar, and confidentiality guidelines.<br/>"
        "3. A formal Appointment Order outlining specific faculty/departmental responsibilities will be handed over on your date of joining."
    )
    story.append(Paragraph(terms_clause, body_style))
    story.append(Spacer(1, 16))

    # 7. ACCEPTANCE & SIGNOFF
    signoff_data = [
        [
            Paragraph("<b>Sincerely,</b><br/><br/><b>Directorate of Human Resources</b><br/>"
                      f"<font color='#64748B'>{school_name}</font><br/>"
                      "<font size='7' color='#059669'>[Digitally Approved &amp; Certified]</font>",
                      sign_title_style),
            Paragraph("<b>Candidate Acceptance &amp; Signature:</b><br/><br/>"
                      "I accept the terms and conditions outlined in this offer letter.<br/><br/>"
                      "Signature: __________________________<br/>"
                      "Date: _______________________________",
                      sign_title_style)
        ]
    ]
    sign_table = Table(signoff_data, colWidths=[255, 260])
    sign_table.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('BOX', (0, 0), (-1, -1), 0.5, colors.HexColor("#E2E8F0")),
        ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor("#F8FAFC")),
        ('LEFTPADDING', (0, 0), (-1, -1), 12),
        ('RIGHTPADDING', (0, 0), (-1, -1), 12),
        ('TOPPADDING', (0, 0), (-1, -1), 10),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 10),
    ]))
    story.append(KeepTogether(sign_table))

    story.append(Spacer(1, 14))
    story.append(HRFlowable(width="100%", thickness=0.5, color=colors.HexColor("#E2E8F0"), spaceAfter=6))
    story.append(Paragraph(
        f"Official Document Generated via EduSHAMIIT ERP System • Document ID: {ref_disp} • Confirmed by HR Directorate",
        footer_style
    ))

    # Build document
    doc.build(story)
    return buf.getvalue()
