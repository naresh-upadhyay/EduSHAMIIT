"""
Enterprise Whiteboard Export Engine.
Generates multi-page vector PDFs (via ReportLab), high-res PNG/JPEG raster images
(via Pillow), and SVG exports preserving backgrounds, drawing objects, text,
sticky notes, and mathematical equations.
"""
import io
import math
from typing import Any, Dict, List, Optional, Tuple
from reportlab.lib.pagesizes import A4, landscape, portrait
from reportlab.lib.colors import HexColor, Color
from reportlab.pdfgen import canvas as rl_canvas
from PIL import Image, ImageDraw, ImageFont


def _parse_hex_color(hex_str: Optional[str], default: str = "#0F172A") -> Tuple[int, int, int]:
    val = (hex_str or default).strip()
    if not val.startswith("#"):
        val = default
    val = val.lstrip("#")
    if len(val) == 3:
        val = "".join(c * 2 for c in val)
    if len(val) == 8:
        val = val[2:]  # strip AARRGGBB alpha prefix
    if len(val) != 6:
        return (15, 23, 42)
    try:
        return (int(val[0:2], 16), int(val[2:4], 16), int(val[4:6], 16))
    except Exception:
        return (15, 23, 42)


def _rl_color(hex_str: Optional[str], opacity: float = 1.0, default: str = "#0F172A") -> Color:
    r, g, b = _parse_hex_color(hex_str, default)
    return Color(r / 255.0, g / 255.0, b / 255.0, alpha=max(0.05, min(1.0, opacity)))


def _draw_pdf_background(c: rl_canvas.Canvas, width: float, height: float, bg_type: str) -> None:
    if bg_type == "dark_grid":
        c.setFillColor(HexColor("#0F172A"))
        c.rect(0, 0, width, height, fill=1, stroke=0)
        line_color = HexColor("#1E293B")
    else:
        c.setFillColor(HexColor("#FFFFFF"))
        c.rect(0, 0, width, height, fill=1, stroke=0)
        line_color = HexColor("#E2E8F0")

    if bg_type in ("light_grid", "dark_grid", "graph", "engineering"):
        step = 18 if bg_type in ("graph", "engineering") else 28
        c.setStrokeColor(HexColor("#DBEAFE") if bg_type == "graph" else line_color)
        c.setLineWidth(0.5)
        x = 0.0
        while x <= width:
            c.line(x, 0, x, height)
            x += step
        y = 0.0
        while y <= height:
            c.line(0, y, width, y)
            y += step
    elif bg_type == "dotted":
        c.setFillColor(HexColor("#CBD5E1"))
        x = 20.0
        while x < width:
            y = 20.0
            while y < height:
                c.circle(x, y, 0.8, fill=1, stroke=0)
                y += 24
            x += 24
    elif bg_type == "ruled":
        c.setStrokeColor(HexColor("#DBEAFE"))
        c.setLineWidth(0.6)
        y = height - 48
        while y > 24:
            c.line(0, y, width, y)
            y -= 24
        c.setStrokeColor(HexColor("#FCA5A5"))
        c.line(56, 0, 56, height)
    elif bg_type == "music":
        c.setStrokeColor(HexColor("#94A3B8"))
        c.setLineWidth(0.6)
        y = height - 70
        while y > 60:
            for offset in range(5):
                c.line(30, y - offset * 8, width - 30, y - offset * 8)
            y -= 72


def render_whiteboard_pdf(
    wb_data: Dict[str, Any],
    page_ids: Optional[List[str]] = None,
    orientation: str = "landscape",
) -> bytes:
    """Render multi-page whiteboard JSON document into a ReportLab vector PDF."""
    buf = io.BytesIO()
    pagesize = landscape(A4) if orientation == "landscape" else portrait(A4)
    pw, ph = pagesize
    c = rl_canvas.Canvas(buf, pagesize=pagesize)
    c.setTitle(wb_data.get("title", "EduSHAMIIT Whiteboard"))

    pages = wb_data.get("pages") or []
    if page_ids:
        target_set = {str(pid) for pid in page_ids}
        selected_pages = [p for p in pages if str(p.get("id")) in target_set]
    else:
        selected_pages = pages

    if not selected_pages:
        selected_pages = [{"title": "Page 1", "background_type": "plain", "objects": []}]

    # Logical canvas reference space 1000 x 620 -> map onto PDF page with padding
    margin = 28.0
    usable_w = pw - margin * 2
    usable_h = ph - margin * 2 - 24
    scale = min(usable_w / 1000.0, usable_h / 620.0)
    ox = margin + (usable_w - 1000.0 * scale) / 2.0
    oy_top = ph - margin - 22.0

    def map_pt(lx: float, ly: float) -> Tuple[float, float]:
        return ox + lx * scale, oy_top - ly * scale

    for idx, page in enumerate(selected_pages):
        bg_type = page.get("background_type", "plain")
        _draw_pdf_background(c, pw, ph, bg_type)

        # Page header bar
        c.setFillColor(HexColor("#64748B") if bg_type != "dark_grid" else HexColor("#94A3B8"))
        c.setFont("Helvetica-Bold", 9)
        header_txt = f"{wb_data.get('title', 'Whiteboard')}  •  {page.get('title', f'Page {idx + 1}')}"
        c.drawString(margin, ph - 20, header_txt)
        c.drawRightString(pw - margin, ph - 20, f"Page {idx + 1} / {len(selected_pages)}")

        objs = sorted(page.get("objects") or [], key=lambda o: int(o.get("z_index") or 0))
        for obj in objs:
            otype = obj.get("type", "")
            data = obj.get("data") or {}
            opacity = float(data.get("opacity", 1.0))
            stroke_hex = data.get("color", "#0F172A")
            fill_hex = data.get("bgColor") or data.get("fillColor")
            stroke_w = max(0.8, float(data.get("strokeWidth", 2.5)) * scale)

            if otype in ("stroke", "pencil", "highlighter", "freeform_shape"):
                pts = data.get("points") or []
                if len(pts) >= 2:
                    alpha = 0.35 if otype == "highlighter" else opacity
                    c.setStrokeColor(_rl_color(stroke_hex, alpha))
                    c.setLineWidth(stroke_w * (2.5 if otype == "highlighter" else 1.0))
                    c.setLineCap(1)
                    c.setLineJoin(1)
                    p = c.beginPath()
                    x0, y0 = map_pt(float(pts[0][0]), float(pts[0][1]))
                    p.moveTo(x0, y0)
                    for pt in pts[1:]:
                        px, py = map_pt(float(pt[0]), float(pt[1]))
                        p.lineTo(px, py)
                    if otype == "freeform_shape":
                        p.close()
                    c.drawPath(p, stroke=1, fill=0)

            elif otype in ("line", "arrow", "double_arrow", "connector", "measurement"):
                x1, y1 = map_pt(float(data.get("x1", 0)), float(data.get("y1", 0)))
                x2, y2 = map_pt(float(data.get("x2", 0)), float(data.get("y2", 0)))
                c.setStrokeColor(_rl_color(stroke_hex, opacity))
                c.setLineWidth(stroke_w)
                c.line(x1, y1, x2, y2)
                if otype in ("arrow", "double_arrow"):
                    angle = math.atan2(y2 - y1, x2 - x1)
                    alen = 8.0
                    c.line(x2, y2, x2 - alen * math.cos(angle - math.pi / 6), y2 - alen * math.sin(angle - math.pi / 6))
                    c.line(x2, y2, x2 - alen * math.cos(angle + math.pi / 6), y2 - alen * math.sin(angle + math.pi / 6))
                    if otype == "double_arrow":
                        c.line(x1, y1, x1 + alen * math.cos(angle - math.pi / 6), y1 + alen * math.sin(angle - math.pi / 6))
                        c.line(x1, y1, x1 + alen * math.cos(angle + math.pi / 6), y1 + alen * math.sin(angle + math.pi / 6))
                if otype == "measurement":
                    dist = math.hypot(float(data.get("x2", 0)) - float(data.get("x1", 0)), float(data.get("y2", 0)) - float(data.get("y1", 0)))
                    c.setFont("Helvetica", 8)
                    c.setFillColor(_rl_color(stroke_hex))
                    c.drawCentredString((x1 + x2) / 2, (y1 + y2) / 2 + 5, f"{dist:.0f} px")

            elif otype in ("rectangle", "student_zone"):
                lx, ly = float(data.get("x", 0)), float(data.get("y", 0))
                lw, lh = float(data.get("width", 120)), float(data.get("height", 80))
                px, py_top = map_pt(lx, ly)
                rw, rh = lw * scale, lh * scale
                c.setStrokeColor(_rl_color(stroke_hex, opacity))
                c.setLineWidth(stroke_w)
                has_fill = 1 if fill_hex else 0
                if has_fill:
                    c.setFillColor(_rl_color(fill_hex, min(opacity, 0.85)))
                c.roundRect(px, py_top - rh, rw, rh, 6, stroke=1, fill=has_fill)
                if otype == "student_zone" and data.get("label"):
                    c.setFont("Helvetica-Bold", 8)
                    c.setFillColor(_rl_color(stroke_hex))
                    c.drawString(px + 6, py_top - 12, str(data.get("label")))

            elif otype in ("circle", "ellipse"):
                lx, ly = float(data.get("x", 0)), float(data.get("y", 0))
                lw, lh = float(data.get("width", 100)), float(data.get("height", 100))
                if otype == "circle":
                    lh = lw
                x1, y_top = map_pt(lx, ly)
                x2, y_bot = map_pt(lx + lw, ly + lh)
                c.setStrokeColor(_rl_color(stroke_hex, opacity))
                c.setLineWidth(stroke_w)
                has_fill = 1 if fill_hex else 0
                if has_fill:
                    c.setFillColor(_rl_color(fill_hex, min(opacity, 0.85)))
                c.ellipse(x1, y_bot, x2, y_top, stroke=1, fill=has_fill)

            elif otype in ("triangle", "star", "polygon"):
                lx, ly = float(data.get("x", 0)), float(data.get("y", 0))
                lw, lh = float(data.get("width", 100)), float(data.get("height", 100))
                c.setStrokeColor(_rl_color(stroke_hex, opacity))
                c.setLineWidth(stroke_w)
                p = c.beginPath()
                if otype == "triangle":
                    p1 = map_pt(lx + lw / 2, ly)
                    p2 = map_pt(lx, ly + lh)
                    p3 = map_pt(lx + lw, ly + lh)
                    p.moveTo(*p1)
                    p.lineTo(*p2)
                    p.lineTo(*p3)
                else:
                    cx, cy = lx + lw / 2, ly + lh / 2
                    r_outer = min(lw, lh) / 2
                    n_pts = 10 if otype == "star" else int(data.get("sides", 6))
                    for i in range(n_pts):
                        ang = -math.pi / 2 + i * (2 * math.pi / n_pts)
                        r = r_outer if (otype == "polygon" or i % 2 == 0) else r_outer * 0.45
                        pt = map_pt(cx + r * math.cos(ang), cy + r * math.sin(ang))
                        if i == 0:
                            p.moveTo(*pt)
                        else:
                            p.lineTo(*pt)
                p.close()
                has_fill = 1 if fill_hex else 0
                if has_fill:
                    c.setFillColor(_rl_color(fill_hex, min(opacity, 0.85)))
                c.drawPath(p, stroke=1, fill=has_fill)

            elif otype in ("text", "sticky_note", "equation"):
                lx, ly = float(data.get("x", 0)), float(data.get("y", 0))
                lw, lh = float(data.get("width", 220)), float(data.get("height", 60))
                px, py_top = map_pt(lx, ly)
                rw, rh = lw * scale, lh * scale
                if otype in ("sticky_note", "equation") or fill_hex:
                    bg = fill_hex or ("#FEF3C7" if otype == "sticky_note" else "#EFF6FF")
                    bd = data.get("borderColor") or ("#F59E0B" if otype == "sticky_note" else "#93C5FD")
                    c.setFillColor(_rl_color(bg, 0.95))
                    c.setStrokeColor(_rl_color(bd, 0.9))
                    c.setLineWidth(1.0)
                    c.roundRect(px, py_top - rh, rw, rh, 6, stroke=1, fill=1)

                txt = str(data.get("display") or data.get("text") or data.get("latex") or "")
                fsize = max(8.0, float(data.get("fontSize", 16)) * scale * 0.8)
                font_name = "Helvetica-Bold" if data.get("bold") else "Helvetica"
                c.setFont(font_name, fsize)
                c.setFillColor(_rl_color(stroke_hex, opacity))
                lines = txt.split("\n")
                cur_y = py_top - fsize - 6
                for ln in lines:
                    if cur_y < py_top - rh + 4:
                        break
                    c.drawString(px + 8, cur_y, ln)
                    cur_y -= fsize * 1.35

        c.showPage()

    c.save()
    return buf.getvalue()


def render_whiteboard_raster(
    wb_data: Dict[str, Any],
    page_id: Optional[str] = None,
    fmt: str = "PNG",
    width: int = 1600,
    height: int = 992,
) -> bytes:
    """Render a whiteboard page into high-res PNG or JPEG bytes using Pillow."""
    pages = wb_data.get("pages") or []
    target_page = None
    if page_id:
        for p in pages:
            if str(p.get("id")) == str(page_id):
                target_page = p
                break
    if target_page is None:
        target_page = pages[0] if pages else {"background_type": "plain", "objects": []}

    bg_type = target_page.get("background_type", "plain")
    bg_rgb = (15, 23, 42) if bg_type == "dark_grid" else (255, 255, 255)
    img = Image.new("RGB", (width, height), bg_rgb)
    draw = ImageDraw.Draw(img)

    # Background grid/ruled patterns
    if bg_type in ("light_grid", "dark_grid", "graph", "engineering"):
        step = int(32 if bg_type in ("graph", "engineering") else 48)
        g_col = (30, 41, 59) if bg_type == "dark_grid" else ((219, 234, 254) if bg_type == "graph" else (226, 232, 240))
        for x in range(0, width, step):
            draw.line([(x, 0), (x, height)], fill=g_col, width=1)
        for y in range(0, height, step):
            draw.line([(0, y), (width, y)], fill=g_col, width=1)
    elif bg_type == "ruled":
        for y in range(60, height, 38):
            draw.line([(0, y), (width, y)], fill=(219, 234, 254), width=1)
        draw.line([(90, 0), (90, height)], fill=(252, 165, 165), width=2)

    sx = width / 1000.0
    sy = height / 620.0
    scale = min(sx, sy)

    font_default = ImageFont.load_default()
    objs = sorted(target_page.get("objects") or [], key=lambda o: int(o.get("z_index") or 0))
    for obj in objs:
        otype = obj.get("type", "")
        data = obj.get("data") or {}
        col = _parse_hex_color(data.get("color"), "#0F172A")
        sw = max(1, int(float(data.get("strokeWidth", 2.5)) * scale))

        if otype in ("stroke", "pencil", "highlighter", "freeform_shape"):
            pts = data.get("points") or []
            if len(pts) >= 2:
                mapped = [(float(pt[0]) * scale, float(pt[1]) * scale) for pt in pts]
                draw.line(mapped, fill=col, width=sw * (2 if otype == "highlighter" else 1))
        elif otype in ("line", "arrow", "double_arrow", "connector", "measurement"):
            x1, y1 = float(data.get("x1", 0)) * scale, float(data.get("y1", 0)) * scale
            x2, y2 = float(data.get("x2", 0)) * scale, float(data.get("y2", 0)) * scale
            draw.line([(x1, y1), (x2, y2)], fill=col, width=sw)
        elif otype in ("rectangle", "student_zone"):
            x, y = float(data.get("x", 0)) * scale, float(data.get("y", 0)) * scale
            w, h = float(data.get("width", 120)) * scale, float(data.get("height", 80)) * scale
            fill_c = _parse_hex_color(data.get("bgColor")) if data.get("bgColor") else None
            draw.rectangle([x, y, x + w, y + h], fill=fill_c, outline=col, width=sw)
        elif otype in ("circle", "ellipse"):
            x, y = float(data.get("x", 0)) * scale, float(data.get("y", 0)) * scale
            w, h = float(data.get("width", 100)) * scale, float(data.get("height", 100)) * scale
            if otype == "circle":
                h = w
            draw.ellipse([x, y, x + w, y + h], outline=col, width=sw)
        elif otype in ("text", "sticky_note", "equation"):
            x, y = float(data.get("x", 0)) * scale, float(data.get("y", 0)) * scale
            w, h = float(data.get("width", 220)) * scale, float(data.get("height", 60)) * scale
            bg = data.get("bgColor") or ("#FEF3C7" if otype == "sticky_note" else None)
            if bg:
                draw.rectangle([x, y, x + w, y + h], fill=_parse_hex_color(bg), outline=col, width=1)
            txt = str(data.get("display") or data.get("text") or data.get("latex") or "")
            draw.multiline_text((x + 10, y + 10), txt, fill=col, font=font_default)

    out = io.BytesIO()
    img.save(out, format="JPEG" if fmt.upper() in ("JPG", "JPEG") else "PNG")
    return out.getvalue()
