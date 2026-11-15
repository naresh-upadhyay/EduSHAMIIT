"""
Enterprise Invoice and Order PDF Generator for EduSHAMIIT ERP Inventory System.
Generates publication-quality, print-ready, professional A4 PDF invoices
for Purchase Orders and Sales Orders using ReportLab.
"""
import io
import re
from datetime import datetime, date
from decimal import Decimal
from typing import Any, Dict, List, Optional
from reportlab.lib.pagesizes import A4
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, HRFlowable, KeepTogether
)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib import colors


def _clean_text(val: Optional[Any]) -> str:
    if val is None:
        return ""
    # Standard Helvetica fonts lack the Unicode ₹ glyph (U+20B9).
    # Replace with INR or Rs. to avoid missing glyph square box.
    return str(val).replace("₹", "INR ").strip()


def _format_curr(val: Optional[Any]) -> str:
    if val is None:
        return "0.00"
    try:
        f = float(val)
        return f"{f:,.2f}"
    except Exception:
        return str(val)


def _number_to_words(amount: float) -> str:
    """Helper to convert numeric amount to readable words for invoice."""
    ones = ["", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine",
            "Ten", "Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen", "Sixteen",
            "Seventeen", "Eighteen", "Nineteen"]
    tens = ["", "", "Twenty", "Thirty", "Forty", "Fifty", "Sixty", "Seventy", "Eighty", "Ninety"]

    def _two_digits(n):
        if n < 20:
            return ones[n]
        return tens[n // 10] + (" " + ones[n % 10] if n % 10 != 0 else "")

    def _three_digits(n):
        res = ""
        if n >= 100:
            res += ones[n // 100] + " Hundred "
            n %= 100
        if n > 0:
            res += _two_digits(n)
        return res.strip()

    amt_int = int(amount)
    if amt_int == 0:
        return "Zero"

    parts = []
    crores = amt_int // 10000000
    if crores > 0:
        parts.append(_three_digits(crores) + " Crore")
        amt_int %= 10000000

    lakhs = amt_int // 100000
    if lakhs > 0:
        parts.append(_three_digits(lakhs) + " Lakh")
        amt_int %= 100000

    thousands = amt_int // 1000
    if thousands > 0:
        parts.append(_three_digits(thousands) + " Thousand")
        amt_int %= 1000

    hundreds = amt_int
    if hundreds > 0:
        parts.append(_three_digits(hundreds))

    return "Rupees " + " ".join(parts) + " Only"


def generate_purchase_order_invoice_pdf(
    order: Dict[str, Any],
    items: List[Dict[str, Any]],
    school_info: Optional[Dict[str, Any]] = None
) -> bytes:
    """
    Generate a high-resolution, print-ready Purchase Order Tax Invoice PDF.
    """
    buf = io.BytesIO()
    doc = SimpleDocTemplate(
        buf,
        pagesize=A4,
        leftMargin=36,
        rightMargin=36,
        topMargin=32,
        bottomMargin=32
    )

    styles = getSampleStyleSheet()

    # Color Scheme
    primary_color = colors.HexColor("#1E1B4B")  # Deep Indigo
    brand_color = colors.HexColor("#2563EB")    # Blue
    slate_900 = colors.HexColor("#0F172A")
    slate_600 = colors.HexColor("#475569")
    slate_100 = colors.HexColor("#F1F5F9")
    slate_50 = colors.HexColor("#F8FAFC")
    border_color = colors.HexColor("#CBD5E1")
    emerald = colors.HexColor("#059669")
    amber = colors.HexColor("#D97706")

    title_style = ParagraphStyle(
        'DocTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=18,
        leading=22,
        textColor=primary_color
    )

    subtitle_style = ParagraphStyle(
        'DocSubtitle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9,
        leading=13,
        textColor=slate_600
    )

    badge_style = ParagraphStyle(
        'Badge',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=11,
        alignment=2,  # Right
        textColor=brand_color
    )

    table_header_style = ParagraphStyle(
        'TH',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8.5,
        leading=11,
        textColor=colors.white
    )

    cell_style = ParagraphStyle(
        'TD',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8.5,
        leading=11,
        textColor=slate_900
    )

    cell_bold_style = ParagraphStyle(
        'TDBold',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8.5,
        leading=11,
        textColor=slate_900
    )

    cell_right_style = ParagraphStyle(
        'TDRight',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8.5,
        leading=11,
        alignment=2,
        textColor=slate_900
    )

    cell_right_bold_style = ParagraphStyle(
        'TDRightBold',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8.5,
        leading=11,
        alignment=2,
        textColor=slate_900
    )

    story = []

    # School Header Details
    school_name = _clean_text((school_info or {}).get("name") or "Greenwood High International School")
    school_addr = _clean_text((school_info or {}).get("address") or "Campus Road, Sarjapur, Bangalore, Karnataka - 560035")
    school_gst = _clean_text((school_info or {}).get("gstin") or "29AAACG1234F1Z8")
    school_phone = _clean_text((school_info or {}).get("phone") or "+91 80 4567 8900")
    school_email = _clean_text((school_info or {}).get("email") or "inventory@edushamiit.edu.in")

    po_number = _clean_text(order.get("po_number") or "PO-DRAFT")
    order_date = str(order.get("order_date") or date.today())
    delivery_date = str(order.get("delivery_date") or "N/A")
    supplier_name = _clean_text(order.get("supplier_name") or "General Supplier")
    supplier_gstin = _clean_text(order.get("supplier_gstin") or "29AAACG1234F1Z8")
    shipping_address = _clean_text(order.get("shipping_address") or "Main Campus Store, Greenwood High")
    status = _clean_text(order.get("status") or "PENDING").upper()
    payment_terms = _clean_text(order.get("payment_terms") or "Net 30 Days")
    department = _clean_text(order.get("department") or "Central Inventory Store")
    notes = _clean_text(order.get("notes") or "Procurement sanctioned by Institutional Purchasing Committee.")
    terms_text = _clean_text(order.get("terms_conditions") or "1. Goods must match the specifications outlined in this Purchase Order.\n2. Materials subject to verification and quality control inspection at receiving bay.\n3. Deliveries must include the official PO Number on all shipping labels and delivery challans.\n4. Invoices must be submitted with accompanying Goods Received Note (GRN).").replace("\n", "<br/>")

    # 1. Top Header Row: School Branding + Document Badge
    header_data = [
        [
            Paragraph(f"<b>{school_name}</b><br/>{school_addr}<br/><b>GSTIN:</b> {school_gst} | <b>Phone:</b> {school_phone}<br/><b>Email:</b> {school_email}", subtitle_style),
            Paragraph(f"<font color='{brand_color}'><b>PURCHASE ORDER INVOICE</b></font><br/><font size='9' color='{slate_600}'>PO Reference: <b>{po_number}</b><br/>Status: <b>{status}</b><br/>Date: <b>{order_date}</b></font>", badge_style)
        ]
    ]
    t_header = Table(header_data, colWidths=[340, 183])
    t_header.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
    ]))
    story.append(t_header)
    story.append(Spacer(1, 8))
    story.append(HRFlowable(width="100%", thickness=1.5, color=brand_color, spaceAfter=10))

    # 2. Order Metadata & Counterparty Boxes
    meta_box = [
        [
            Paragraph(f"<b>SUPPLIER / VENDOR DETAILS:</b><br/>"
                      f"<b>{supplier_name}</b><br/>"
                      f"Vendor Account: Active Verified<br/>"
                      f"GSTIN / Tax ID: <b>{supplier_gstin}</b><br/>"
                      f"Payment Terms: <b>{payment_terms}</b>", cell_style),
            Paragraph(f"<b>SHIPPING & ORDER DETAILS:</b><br/>"
                      f"Target Store: <b>{department}</b><br/>"
                      f"PO Order Date: <b>{order_date}</b><br/>"
                      f"Expected Delivery Date: <b>{delivery_date}</b><br/>"
                      f"Delivery Location: <b>{shipping_address}</b><br/>"
                      f"Fulfillment Status: <b>{status}</b>", cell_style)
        ]
    ]
    t_meta = Table(meta_box, colWidths=[260, 263])
    t_meta.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), slate_50),
        ('BOX', (0, 0), (-1, -1), 0.75, border_color),
        ('INNERGRID', (0, 0), (-1, -1), 0.5, border_color),
        ('TOPPADDING', (0, 0), (-1, -1), 8),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
        ('LEFTPADDING', (0, 0), (-1, -1), 10),
        ('RIGHTPADDING', (0, 0), (-1, -1), 10),
    ]))
    story.append(t_meta)
    story.append(Spacer(1, 14))

    # 3. Line Items Table
    headers = [
        Paragraph("<b>#</b>", table_header_style),
        Paragraph("<b>Item Name & Description</b>", table_header_style),
        Paragraph("<b>SKU / Code</b>", table_header_style),
        Paragraph("<b>Qty</b>", table_header_style),
        Paragraph("<b>Unit</b>", table_header_style),
        Paragraph("<b>Rate (INR)</b>", table_header_style),
        Paragraph("<b>Tax %</b>", table_header_style),
        Paragraph("<b>Total (INR)</b>", table_header_style),
    ]

    items_rows = [headers]
    subtotal = 0.0
    total_tax = 0.0

    for idx, it in enumerate(items, 1):
        item_name = _clean_text(it.get("item_name") or it.get("name") or "Standard Item")
        sku = _clean_text(it.get("sku") or "SKU-N/A")
        qty = float(it.get("quantity_ordered") or it.get("quantity") or 1.0)
        unit = _clean_text(it.get("unit") or "Pcs")
        unit_price = float(it.get("unit_price") or it.get("price") or 0.0)
        tax_rate = float(it.get("tax_rate") or 18.0)
        line_total = float(it.get("line_total") or (qty * unit_price))

        line_tax = line_total * (tax_rate / 100.0)
        subtotal += line_total
        total_tax += line_tax

        items_rows.append([
            Paragraph(str(idx), cell_style),
            Paragraph(f"<b>{item_name}</b>", cell_style),
            Paragraph(sku, cell_style),
            Paragraph(f"{qty:g}", cell_right_style),
            Paragraph(unit, cell_style),
            Paragraph(_format_curr(unit_price), cell_right_style),
            Paragraph(f"{tax_rate:g}%", cell_right_style),
            Paragraph(_format_curr(line_total), cell_right_bold_style),
        ])

    grand_total = float(order.get("total_amount") or (subtotal + total_tax))
    # If order total_amount is already provided, calibrate subtotal/tax accordingly
    if order.get("subtotal") is not None:
        subtotal = float(order.get("subtotal"))
    if order.get("tax_amount") is not None:
        total_tax = float(order.get("tax_amount"))

    col_widths = [24, 185, 84, 38, 38, 54, 38, 62]
    t_items = Table(items_rows, colWidths=col_widths, repeatRows=1)
    t_items_style = [
        ('BACKGROUND', (0, 0), (-1, 0), primary_color),
        ('ALIGN', (0, 0), (-1, 0), 'LEFT'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('LEFTPADDING', (0, 0), (-1, -1), 4),
        ('RIGHTPADDING', (0, 0), (-1, -1), 4),
        ('BOX', (0, 0), (-1, -1), 0.75, border_color),
        ('INNERGRID', (0, 0), (-1, -1), 0.5, border_color),
    ]

    for r_idx in range(1, len(items_rows)):
        if r_idx % 2 == 0:
            t_items_style.append(('BACKGROUND', (0, r_idx), (-1, r_idx), slate_50))

    t_items.setStyle(TableStyle(t_items_style))
    story.append(t_items)
    story.append(Spacer(1, 10))

    # 4. Summary & Calculations Block
    words = _number_to_words(grand_total)

    summary_data = [
        [
            Paragraph(f"<b>Amount Chargeable (in words):</b><br/>{words}<br/><br/>"
                      f"<b>Notes & Special Instructions:</b><br/>{notes}", cell_style),
            Table([
                [Paragraph("Subtotal:", cell_style), Paragraph(f"INR {_format_curr(subtotal)}", cell_right_style)],
                [Paragraph("Estimated GST (18%):", cell_style), Paragraph(f"INR {_format_curr(total_tax)}", cell_right_style)],
                [Paragraph("Shipping / Handling:", cell_style), Paragraph("INR 0.00", cell_right_style)],
                [Paragraph("<b>Grand Total:</b>", cell_bold_style), Paragraph(f"<b>INR {_format_curr(grand_total)}</b>", cell_right_bold_style)],
            ], colWidths=[110, 100])
        ]
    ]

    t_summary = Table(summary_data, colWidths=[313, 210])
    t_summary.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('BOX', (0, 0), (-1, -1), 0.75, border_color),
        ('BACKGROUND', (0, 0), (0, 0), slate_50),
        ('TOPPADDING', (0, 0), (-1, -1), 6),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('LEFTPADDING', (0, 0), (-1, -1), 8),
        ('RIGHTPADDING', (0, 0), (-1, -1), 8),
    ]))
    story.append(t_summary)
    story.append(Spacer(1, 20))

    # 5. Terms, Conditions & Signatures
    terms_block = [
        [
            Paragraph(f"<b>TERMS & CONDITIONS:</b><br/>{terms_text}", subtitle_style),
            Paragraph("<br/><br/><br/>________________________________________<br/>"
                      "<b>Authorized Signatory</b><br/>"
                      "EduSHAMIIT Institutional Procurement Authority<br/>"
                      "<font size='7' color='#94A3B8'>Digitally verified through ERP Ledger</font>", cell_style)
        ]
    ]
    t_terms = Table(terms_block, colWidths=[330, 193])
    t_terms.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('LEFTPADDING', (0, 0), (-1, -1), 4),
        ('RIGHTPADDING', (0, 0), (-1, -1), 4),
    ]))
    story.append(KeepTogether(t_terms))

    doc.build(story)
    buf.seek(0)
    return buf.getvalue()


def generate_sales_order_invoice_pdf(
    order: Dict[str, Any],
    items: List[Dict[str, Any]],
    school_info: Optional[Dict[str, Any]] = None
) -> bytes:
    """
    Generate a high-resolution, print-ready Sales Order Tax Invoice PDF.
    """
    buf = io.BytesIO()
    doc = SimpleDocTemplate(
        buf,
        pagesize=A4,
        leftMargin=36,
        rightMargin=36,
        topMargin=32,
        bottomMargin=32
    )

    styles = getSampleStyleSheet()

    primary_color = colors.HexColor("#065F46")  # Emerald Dark
    brand_color = colors.HexColor("#059669")    # Emerald 600
    slate_900 = colors.HexColor("#0F172A")
    slate_600 = colors.HexColor("#475569")
    slate_50 = colors.HexColor("#F8FAFC")
    border_color = colors.HexColor("#CBD5E1")

    subtitle_style = ParagraphStyle(
        'DocSubtitle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9,
        leading=13,
        textColor=slate_600
    )

    badge_style = ParagraphStyle(
        'Badge',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=11,
        alignment=2,
        textColor=brand_color
    )

    table_header_style = ParagraphStyle(
        'TH',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8.5,
        leading=11,
        textColor=colors.white
    )

    cell_style = ParagraphStyle(
        'TD',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8.5,
        leading=11,
        textColor=slate_900
    )

    cell_bold_style = ParagraphStyle(
        'TDBold',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8.5,
        leading=11,
        textColor=slate_900
    )

    cell_right_style = ParagraphStyle(
        'TDRight',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8.5,
        leading=11,
        alignment=2,
        textColor=slate_900
    )

    cell_right_bold_style = ParagraphStyle(
        'TDRightBold',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8.5,
        leading=11,
        alignment=2,
        textColor=slate_900
    )

    story = []

    school_name = _clean_text((school_info or {}).get("name") or "Greenwood High International School")
    school_addr = _clean_text((school_info or {}).get("address") or "Campus Road, Sarjapur, Bangalore, Karnataka - 560035")
    school_gst = _clean_text((school_info or {}).get("gstin") or "29AAACG1234F1Z8")
    school_phone = _clean_text((school_info or {}).get("phone") or "+91 80 4567 8900")
    school_email = _clean_text((school_info or {}).get("email") or "sales@edushamiit.edu.in")

    so_number = _clean_text(order.get("so_number") or "SO-DRAFT")
    order_date = str(order.get("order_date") or date.today())
    delivery_date = str(order.get("delivery_date") or "N/A")
    customer_name = _clean_text(order.get("customer_name") or "Institutional Buyer")
    customer_type = _clean_text(order.get("customer_type") or "Partner School")
    customer_gstin = _clean_text(order.get("customer_gstin") or "29AAACG1234F1Z8")
    shipping_address = _clean_text(order.get("shipping_address") or "Bangalore Center Distribution")
    payment_terms = _clean_text(order.get("payment_terms") or "Due on Receipt")
    status = _clean_text(order.get("status") or "DELIVERED").upper()
    department = _clean_text(order.get("department") or "Distribution & Sales Desk")
    notes = _clean_text(order.get("notes") or "Consignment sales fulfilled under institutional educational quota.")
    terms_text = _clean_text(order.get("terms_conditions") or "1. Certified that the particulars given above are true and correct.\n2. Subject to Bangalore Jurisdiction.\n3. Any discrepancies must be brought to notice within 7 days of delivery.\n4. This is a computer generated tax invoice.").replace("\n", "<br/>")

    header_data = [
        [
            Paragraph(f"<b>{school_name}</b><br/>{school_addr}<br/><b>GSTIN:</b> {school_gst} | <b>Phone:</b> {school_phone}<br/><b>Email:</b> {school_email}", subtitle_style),
            Paragraph(f"<font color='{brand_color}'><b>TAX INVOICE & SALES ORDER</b></font><br/><font size='9' color='{slate_600}'>Invoice / SO: <b>{so_number}</b><br/>Status: <b>{status}</b><br/>Date: <b>{order_date}</b></font>", badge_style)
        ]
    ]
    t_header = Table(header_data, colWidths=[340, 183])
    t_header.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
    ]))
    story.append(t_header)
    story.append(Spacer(1, 8))
    story.append(HRFlowable(width="100%", thickness=1.5, color=brand_color, spaceAfter=10))

    meta_box = [
        [
            Paragraph(f"<b>BILL TO / CUSTOMER DETAILS:</b><br/>"
                      f"<b>{customer_name}</b><br/>"
                      f"Client Classification: <b>{customer_type}</b><br/>"
                      f"GSTIN / Tax ID: <b>{customer_gstin}</b><br/>"
                      f"Payment Terms: <b>{payment_terms}</b><br/>"
                      f"Dispatch Location: <b>{shipping_address}</b>", cell_style),
            Paragraph(f"<b>DISPATCH & SALES RECORD:</b><br/>"
                      f"Origin Store: <b>{department}</b><br/>"
                      f"SO Date: <b>{order_date}</b><br/>"
                      f"Delivery Date: <b>{delivery_date}</b><br/>"
                      f"Fulfillment State: <b>{status}</b>", cell_style)
        ]
    ]
    t_meta = Table(meta_box, colWidths=[260, 263])
    t_meta.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), slate_50),
        ('BOX', (0, 0), (-1, -1), 0.75, border_color),
        ('INNERGRID', (0, 0), (-1, -1), 0.5, border_color),
        ('TOPPADDING', (0, 0), (-1, -1), 8),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
        ('LEFTPADDING', (0, 0), (-1, -1), 10),
        ('RIGHTPADDING', (0, 0), (-1, -1), 10),
    ]))
    story.append(t_meta)
    story.append(Spacer(1, 14))

    headers = [
        Paragraph("<b>#</b>", table_header_style),
        Paragraph("<b>Item Name & Description</b>", table_header_style),
        Paragraph("<b>SKU / Code</b>", table_header_style),
        Paragraph("<b>Qty</b>", table_header_style),
        Paragraph("<b>Unit</b>", table_header_style),
        Paragraph("<b>Rate (INR)</b>", table_header_style),
        Paragraph("<b>Tax %</b>", table_header_style),
        Paragraph("<b>Total (INR)</b>", table_header_style),
    ]

    items_rows = [headers]
    subtotal = 0.0
    total_tax = 0.0

    for idx, it in enumerate(items, 1):
        item_name = _clean_text(it.get("item_name") or it.get("name") or "Standard Item")
        sku = _clean_text(it.get("sku") or "SKU-N/A")
        qty = float(it.get("quantity_ordered") or it.get("quantity") or 1.0)
        unit = _clean_text(it.get("unit") or "Pcs")
        unit_price = float(it.get("unit_price") or it.get("price") or 0.0)
        tax_rate = float(it.get("tax_rate") or 5.0)
        line_total = float(it.get("line_total") or (qty * unit_price))

        line_tax = line_total * (tax_rate / 100.0)
        subtotal += line_total
        total_tax += line_tax

        items_rows.append([
            Paragraph(str(idx), cell_style),
            Paragraph(f"<b>{item_name}</b>", cell_style),
            Paragraph(sku, cell_style),
            Paragraph(f"{qty:g}", cell_right_style),
            Paragraph(unit, cell_style),
            Paragraph(_format_curr(unit_price), cell_right_style),
            Paragraph(f"{tax_rate:g}%", cell_right_style),
            Paragraph(_format_curr(line_total), cell_right_bold_style),
        ])

    grand_total = float(order.get("total_amount") or (subtotal + total_tax))
    if order.get("subtotal") is not None:
        subtotal = float(order.get("subtotal"))
    if order.get("tax_amount") is not None:
        total_tax = float(order.get("tax_amount"))

    col_widths = [24, 185, 84, 38, 38, 54, 38, 62]
    t_items = Table(items_rows, colWidths=col_widths, repeatRows=1)
    t_items_style = [
        ('BACKGROUND', (0, 0), (-1, 0), primary_color),
        ('ALIGN', (0, 0), (-1, 0), 'LEFT'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('LEFTPADDING', (0, 0), (-1, -1), 4),
        ('RIGHTPADDING', (0, 0), (-1, -1), 4),
        ('BOX', (0, 0), (-1, -1), 0.75, border_color),
        ('INNERGRID', (0, 0), (-1, -1), 0.5, border_color),
    ]

    for r_idx in range(1, len(items_rows)):
        if r_idx % 2 == 0:
            t_items_style.append(('BACKGROUND', (0, r_idx), (-1, r_idx), slate_50))

    t_items.setStyle(TableStyle(t_items_style))
    story.append(t_items)
    story.append(Spacer(1, 10))

    words = _number_to_words(grand_total)

    discount = float(order.get("discount_amount") or 0.0)
    summary_data = [
        [
            Paragraph(f"<b>Invoice Total (in words):</b><br/>{words}<br/><br/>"
                      f"<b>Remarks / Dispatch Notes:</b><br/>{notes}", cell_style),
            Table([
                [Paragraph("Taxable Subtotal:", cell_style), Paragraph(f"INR {_format_curr(subtotal)}", cell_right_style)],
                [Paragraph("Integrated GST:", cell_style), Paragraph(f"INR {_format_curr(total_tax)}", cell_right_style)],
                [Paragraph("Discount:", cell_style), Paragraph(f"INR {_format_curr(discount)}", cell_right_style)],
                [Paragraph("<b>Invoice Grand Total:</b>", cell_bold_style), Paragraph(f"<b>INR {_format_curr(grand_total)}</b>", cell_right_bold_style)],
            ], colWidths=[115, 95])
        ]
    ]

    t_summary = Table(summary_data, colWidths=[313, 210])
    t_summary.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('BOX', (0, 0), (-1, -1), 0.75, border_color),
        ('BACKGROUND', (0, 0), (0, 0), slate_50),
        ('TOPPADDING', (0, 0), (-1, -1), 6),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('LEFTPADDING', (0, 0), (-1, -1), 8),
        ('RIGHTPADDING', (0, 0), (-1, -1), 8),
    ]))
    story.append(t_summary)
    story.append(Spacer(1, 20))

    terms_block = [
        [
            Paragraph(f"<b>DECLARATION & TERMS:</b><br/>{terms_text}", subtitle_style),
            Paragraph("<br/><br/><br/>________________________________________<br/>"
                      "<b>Authorized Signatory</b><br/>"
                      "EduSHAMIIT Inventory & Sales Operations<br/>"
                      "<font size='7' color='#94A3B8'>Official Digital Billing Document</font>", cell_style)
        ]
    ]
    t_terms = Table(terms_block, colWidths=[330, 193])
    t_terms.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('LEFTPADDING', (0, 0), (-1, -1), 4),
        ('RIGHTPADDING', (0, 0), (-1, -1), 4),
    ]))
    story.append(KeepTogether(t_terms))

    doc.build(story)
    buf.seek(0)
    return buf.getvalue()
