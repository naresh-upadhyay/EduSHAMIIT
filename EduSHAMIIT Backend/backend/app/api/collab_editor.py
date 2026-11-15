"""
EduSHAMIIT Enterprise Multi-Format Collaborative Document Suite.
Provides real-time multi-user simultaneous viewing, editing, cursor synchronization,
autosaving, and version-committed saving for:
  - Spreadsheets: Excel (.xlsx, .xls) & CSV (.csv)
  - Documents: Word (.docx, .doc), Rich Text (.rtf), Plain Text (.txt, .md)
  - Presentations: PowerPoint (.pptx, .ppt)
  - PDF & Media Documents (.pdf)
"""

import os
import io
import re
import csv
import json
import time
import uuid
import hashlib
import asyncio
import logging
import urllib.parse
from datetime import datetime, date
from typing import Optional, List, Dict, Any, Tuple

try:
    import openpyxl
    from openpyxl.utils import get_column_letter
except ImportError:
    openpyxl = None

try:
    import docx
except ImportError:
    docx = None

try:
    import pptx
    import pptx.util
except ImportError:
    pptx = None

from fastapi import WebSocket, WebSocketDisconnect

logger = logging.getLogger(__name__)

COLLAB_COLORS = [
    "#2563EB", # Royal Blue
    "#10B981", # Emerald
    "#F59E0B", # Amber
    "#8B5CF6", # Purple
    "#EC4899", # Pink
    "#06B6D4", # Cyan
    "#F97316", # Orange
    "#14B8A6", # Teal
    "#6366F1", # Indigo
    "#84CC16", # Lime
]


def resolve_local_file_path(storage_path: Optional[str]) -> Optional[str]:
    """Find the local physical file path across docker volumes and host paths."""
    if not storage_path:
        return None
    candidates = [
        storage_path,
        os.path.join(os.getcwd(), storage_path),
        os.path.join(os.getcwd(), "volumes", storage_path),
        os.path.join("/app", storage_path),
        os.path.join("E:/EduSHAMIIT/volumes", storage_path),
    ]
    for p in candidates:
        if os.path.exists(p) and os.path.isfile(p):
            return p
    return None


# ============================================================================
# MULTI-FORMAT PARSERS
# ============================================================================

def parse_docx_file(file_path: Optional[str], fallback_title: str, fallback_content: Optional[str] = None) -> str:
    """Parse a .docx file or HTML/text fallback into semantic rich HTML for the document editor."""
    html_paragraphs = []
    if file_path and os.path.exists(file_path):
        try:
            with open(file_path, "rb") as f:
                sig = f.read(4)
            if sig == b'PK\x03\x04' and docx:
                # Authentic Word Document package
                d = docx.Document(file_path)
                for p in d.paragraphs:
                    text = p.text.strip()
                    if not text:
                        continue
                    s_name = (p.style.name if p.style else "").lower()
                    if "heading 1" in s_name or "title" in s_name:
                        html_paragraphs.append(f"<h1>{text}</h1>")
                    elif "heading 2" in s_name:
                        html_paragraphs.append(f"<h2>{text}</h2>")
                    elif "heading 3" in s_name:
                        html_paragraphs.append(f"<h3>{text}</h3>")
                    elif "bullet" in s_name or "list" in s_name:
                        html_paragraphs.append(f"<li>{text}</li>")
                    else:
                        run_html = []
                        for run in p.runs:
                            r_text = run.text
                            if not r_text:
                                continue
                            if run.bold:
                                r_text = f"<b>{r_text}</b>"
                            if run.italic:
                                r_text = f"<i>{r_text}</i>"
                            if run.underline:
                                r_text = f"<u>{r_text}</u>"
                            run_html.append(r_text)
                        joined = "".join(run_html) if run_html else text
                        html_paragraphs.append(f"<p>{joined}</p>")

                # Extract tables
                for tbl in d.tables:
                    rows_html = []
                    for row in tbl.rows:
                        cells = [f"<td>{c.text.strip()}</td>" for c in row.cells]
                        rows_html.append(f"<tr>{''.join(cells)}</tr>")
                    if rows_html:
                        html_paragraphs.append(f"<table class='doc-table'>{''.join(rows_html)}</table>")
            else:
                # Text or HTML file (e.g. created from text editor)
                with open(file_path, "r", encoding="utf-8", errors="replace") as f:
                    raw_text = f.read().strip()
                if raw_text:
                    if "<p>" in raw_text or "<h1>" in raw_text or "<div>" in raw_text:
                        html_paragraphs.append(raw_text)
                    else:
                        for line in raw_text.splitlines():
                            line_s = line.strip()
                            if line_s:
                                html_paragraphs.append(f"<p>{line_s}</p>")
        except Exception as e:
            logger.warning(f"Error reading docx/text file {file_path}: {e}")

    if not html_paragraphs and fallback_content:
        if "<p>" in fallback_content or "<h1>" in fallback_content:
            html_paragraphs.append(fallback_content)
        else:
            for line in fallback_content.splitlines():
                if line.strip():
                    html_paragraphs.append(f"<p>{line.strip()}</p>")

    if not html_paragraphs:
        title = fallback_title or "Institutional Document"
        html_paragraphs = [
            f"<h1>{title}</h1>",
            "<p>This document is ready for real-time collaborative editing by authorized institute members.</p>",
            "<h2>1. Purpose & Guidelines</h2>",
            "<p>Please review and update the content below. All changes made by educators, staff, and administrators are synchronized live across the institute.</p>",
            "<ul>",
            "<li>Maintain complete accuracy of institutional records, policies, and curriculum standards.</li>",
            "<li>Format headings, bullet points, and tables using the top formatting toolbar.</li>",
            "<li>Changes auto-save every 4 seconds with complete version tracking.</li>",
            "</ul>",
            "<h2>2. Summary Table</h2>",
            "<table class='doc-table'>",
            "<tr><th>Section</th><th>Responsible Authority</th><th>Status</th></tr>",
            "<tr><td>Academic Review</td><td>Department Head</td><td>Verified</td></tr>",
            "<tr><td>Administrative Approval</td><td>Principal Office</td><td>Approved</td></tr>",
            "</table>"
        ]

    return "\n".join(html_paragraphs)


def parse_pptx_file(file_path: Optional[str], fallback_title: str) -> List[Dict[str, Any]]:
    """Parse a .pptx presentation file into structured slide objects."""
    slides = []
    if file_path and os.path.exists(file_path) and pptx:
        try:
            with open(file_path, "rb") as f:
                sig = f.read(4)
            if sig == b'PK\x03\x04':
                prs = pptx.Presentation(file_path)
                for idx, slide in enumerate(prs.slides):
                    title = ""
                    subtitle = ""
                    bullets = []
                    notes = ""

                    if slide.shapes.title and slide.shapes.title.text:
                        title = slide.shapes.title.text.strip()

                    for shape in slide.shapes:
                        if shape == slide.shapes.title:
                            continue
                        if shape.has_text_frame:
                            for p in shape.text_frame.paragraphs:
                                text = p.text.strip()
                                if text:
                                    if not subtitle and idx == 0:
                                        subtitle = text
                                    else:
                                        bullets.append(text)

                    if slide.has_notes_slide and slide.notes_slide.notes_text_frame:
                        notes = slide.notes_slide.notes_text_frame.text.strip()

                    slides.append({
                        "id": idx + 1,
                        "title": title or f"Slide {idx + 1}",
                        "subtitle": subtitle,
                        "bullets": bullets if bullets else ["Key topic discussion", "Progress updates and timeline"],
                        "notes": notes,
                        "layout": "title" if idx == 0 else "bullets"
                    })
        except Exception as e:
            logger.warning(f"Error parsing PPTX {file_path}: {e}")

    if not slides:
        title = fallback_title or "Annual Institute Presentation"
        slides = [
            {
                "id": 1,
                "title": title,
                "subtitle": "EduSHAMIIT School ERP • Academic & Strategic Overview",
                "bullets": [],
                "notes": "Welcome parents, staff, and leadership committee members.",
                "layout": "title"
            },
            {
                "id": 2,
                "title": "Agenda & Session Objectives",
                "subtitle": "Overview of today's key discussion topics",
                "bullets": [
                    "Review of academic milestones and student performance accomplishments",
                    "New pedagogical infrastructure and interactive smart classroom upgrades",
                    "Extracurricular achievements & upcoming sports tournaments",
                    "Open forum discussion and interactive parent-teacher Q&A"
                ],
                "notes": "Cover each agenda point concisely before moving to performance metrics.",
                "layout": "bullets"
            },
            {
                "id": 3,
                "title": "Academic Performance & Curricular Highlights",
                "subtitle": "Term assessment breakdown & student recognition",
                "bullets": [
                    "Overall school pass percentage increased by 8.4% this semester",
                    "Advanced STEM laboratories and smart digital classroom deployments",
                    "Targeted remedial coaching programs for junior cohorts",
                    "Over 45 distinction awards across national talent searches"
                ],
                "notes": "Highlight student growth and teacher commendations.",
                "layout": "bullets"
            },
            {
                "id": 4,
                "title": "Strategic Roadmap & Next Steps",
                "subtitle": "Key milestones for the upcoming semester",
                "bullets": [
                    "Parent-Teacher progress reporting portal opens next Monday",
                    "Final project submissions due by end of month",
                    "Annual cultural festival scheduled for December 15th",
                    "Enrollment confirmations for advanced diploma streams"
                ],
                "notes": "Thank all participants and open for questions.",
                "layout": "bullets"
            }
        ]
    return slides


def parse_file_to_sheets(file_path: Optional[str], file_type: str, fallback_content: Optional[str] = None, fallback_title: str = "Document") -> Dict[str, Any]:
    """Parse local document, presentation, or spreadsheet into structured editable data."""
    ft = (file_type or "").upper()
    
    # 1. Presentations (.pptx, .ppt)
    if "PPT" in ft or (file_path and (file_path.lower().endswith(".pptx") or file_path.lower().endswith(".ppt"))):
        slides = parse_pptx_file(file_path, fallback_title)
        return {
            "type": "presentation",
            "file_type": "PPTX",
            "title": fallback_title,
            "slides": slides
        }

    # 2. Documents (.docx, .doc, .rtf, .txt, .md)
    if "DOC" in ft or "TXT" in ft or "MD" in ft or (file_path and (file_path.lower().endswith((".docx", ".doc", ".txt", ".rtf", ".md")))):
        content = parse_docx_file(file_path, fallback_title, fallback_content)
        return {
            "type": "document",
            "file_type": "DOCX" if "DOC" in ft else "TXT",
            "title": fallback_title,
            "content": content
        }

    # 3. CSV / TSV handling
    if "CSV" in ft or (file_path and file_path.lower().endswith(".csv")):
        rows: List[List[str]] = []
        if file_path and os.path.exists(file_path):
            try:
                with open(file_path, "r", encoding="utf-8-sig", errors="replace") as f:
                    reader = csv.reader(f)
                    for r in reader:
                        rows.append(r)
            except Exception as e:
                logger.warning(f"Error reading CSV {file_path}: {e}")
        elif fallback_content:
            reader = csv.reader(io.StringIO(fallback_content))
            for r in reader:
                rows.append(r)
                
        if not rows:
            rows = [
                ["A", "B", "C", "D", "E"],
                ["", "", "", "", ""],
                ["", "", "", "", ""]
            ]
        max_cols = max((len(r) for r in rows), default=5)
        for r in rows:
            if len(r) < max_cols:
                r.extend([""] * (max_cols - len(r)))
                
        return {
            "type": "spreadsheet",
            "file_type": "CSV",
            "title": fallback_title,
            "sheets": [
                {
                    "name": "Sheet1",
                    "rows_count": len(rows),
                    "cols_count": max_cols,
                    "data": rows
                }
            ]
        }

    # 4. XLSX / XLS handling
    if "XLS" in ft or "SHEET" in ft or (file_path and (file_path.lower().endswith(".xlsx") or file_path.lower().endswith(".xls"))):
        sheets_data = []
        if file_path and os.path.exists(file_path) and openpyxl:
            try:
                wb = openpyxl.load_workbook(file_path, data_only=False)
                for sheet_name in wb.sheetnames:
                    ws = wb[sheet_name]
                    s_rows = []
                    for row in ws.iter_rows(values_only=False):
                        r_vals = []
                        for cell in row:
                            val = cell.value
                            if val is None:
                                r_vals.append("")
                            elif isinstance(val, (datetime, date)):
                                r_vals.append(val.isoformat())
                            else:
                                r_vals.append(str(val))
                        s_rows.append(r_vals)
                        
                    if not s_rows:
                        s_rows = [[""] * 8 for _ in range(15)]
                    max_cols = max((len(r) for r in s_rows), default=8)
                    for r in s_rows:
                        if len(r) < max_cols:
                            r.extend([""] * (max_cols - len(r)))
                    sheets_data.append({
                        "name": sheet_name,
                        "rows_count": len(s_rows),
                        "cols_count": max_cols,
                        "data": s_rows
                    })
            except Exception as e:
                logger.warning(f"Error reading XLSX {file_path}: {e}")

        if not sheets_data:
            default_grid = [[""] * 10 for _ in range(20)]
            sheets_data = [{
                "name": "Sheet1",
                "rows_count": len(default_grid),
                "cols_count": 10,
                "data": default_grid
            }]
            
        return {
            "type": "spreadsheet",
            "file_type": "XLSX",
            "title": fallback_title,
            "sheets": sheets_data
        }

    # 5. PDF Documents
    if "PDF" in ft or (file_path and file_path.lower().endswith(".pdf")):
        return {
            "type": "pdf",
            "file_type": "PDF",
            "title": fallback_title,
            "file_path": file_path
        }

    # 6. Fallback Document
    content = parse_docx_file(file_path, fallback_title, fallback_content)
    return {
        "type": "document",
        "file_type": "DOCX",
        "title": fallback_title,
        "content": content
    }


# ============================================================================
# MULTI-FORMAT SAVERS
# ============================================================================

def _html_to_docx_file(html: str, output_path: str, title: str = "Document"):
    """Compile rich HTML paragraphs, headings, bullet lists, and tables into a valid Word .docx file."""
    if not docx:
        # Fallback to plain text writing
        clean_text = re.sub(r'<[^>]+>', '', html)
        with open(output_path, "w", encoding="utf-8") as f:
            f.write(clean_text)
        return

    doc = docx.Document()
    html = html.replace('&nbsp;', ' ').replace('&amp;', '&').replace('&lt;', '<').replace('&gt;', '>')
    blocks = re.findall(r'<(h[1-4]|p|li|blockquote|table)[^>]*>(.*?)</\1>', html, re.DOTALL | re.IGNORECASE)

    if not blocks:
        doc.add_paragraph(re.sub(r'<[^>]+>', '', html).strip())
        doc.save(output_path)
        return

    for tag, content in blocks:
        tag = tag.lower()
        if tag == 'table':
            row_matches = re.findall(r'<tr[^>]*>(.*?)</tr>', content, re.DOTALL | re.IGNORECASE)
            if row_matches:
                first_cells = re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>', row_matches[0], re.DOTALL | re.IGNORECASE)
                num_cols = max(len(first_cells), 1)
                tbl = doc.add_table(rows=len(row_matches), cols=num_cols)
                try:
                    tbl.style = 'Table Grid'
                except Exception:
                    pass
                for r_idx, r_html in enumerate(row_matches):
                    cell_matches = re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>', r_html, re.DOTALL | re.IGNORECASE)
                    for c_idx, c_html in enumerate(cell_matches):
                        if c_idx < num_cols:
                            tbl.cell(r_idx, c_idx).text = re.sub(r'<[^>]+>', '', c_html).strip()
            continue

        raw_text = re.sub(r'<[^>]+>', '', content).strip()
        if not raw_text:
            continue

        if tag == 'h1':
            doc.add_heading(raw_text, level=1)
        elif tag == 'h2':
            doc.add_heading(raw_text, level=2)
        elif tag == 'h3':
            doc.add_heading(raw_text, level=3)
        elif tag == 'h4':
            doc.add_heading(raw_text, level=4)
        elif tag == 'li':
            p = doc.add_paragraph(style='List Bullet')
            _add_formatted_runs_to_paragraph(p, content)
        elif tag == 'blockquote':
            p = doc.add_paragraph(style='Intense Quote')
            _add_formatted_runs_to_paragraph(p, content)
        else:
            p = doc.add_paragraph()
            _add_formatted_runs_to_paragraph(p, content)

    doc.save(output_path)


def _add_formatted_runs_to_paragraph(paragraph, inner_html: str):
    """Tokenize HTML inline tags (<b>, <i>, <u>) and add formatted runs."""
    tokens = re.split(r'(<b[^>]*>.*?</b>|<strong[^>]*>.*?</strong>|<i[^>]*>.*?</i>|<em[^>]*>.*?</em>|<u[^>]*>.*?</u>)', inner_html, flags=re.DOTALL | re.IGNORECASE)
    for tok in tokens:
        if not tok:
            continue
        is_bold = bool(re.match(r'<(b|strong)[^>]*>', tok, re.I))
        is_italic = bool(re.match(r'<(i|em)[^>]*>', tok, re.I))
        is_under = bool(re.match(r'<u[^>]*>', tok, re.I))
        text = re.sub(r'<[^>]+>', '', tok)
        if text:
            run = paragraph.add_run(text)
            if is_bold:
                run.bold = True
            if is_italic:
                run.italic = True
            if is_under:
                run.underline = True


def _slides_to_pptx_file(slides_list: List[Dict[str, Any]], output_path: str, title: str = "Presentation"):
    """Compile structured slide list into a valid 16:9 widescreen PowerPoint .pptx presentation file."""
    if not pptx:
        with open(output_path, "w", encoding="utf-8") as f:
            f.write(json.dumps(slides_list, indent=2))
        return

    prs = pptx.Presentation()
    prs.slide_width = pptx.util.Inches(13.333)
    prs.slide_height = pptx.util.Inches(7.5)

    for idx, s in enumerate(slides_list):
        layout = 0 if idx == 0 else 1
        slide = prs.slides.add_slide(prs.slide_layouts[layout])
        if slide.shapes.title:
            slide.shapes.title.text = s.get("title") or f"Slide {idx + 1}"

        subtitle = s.get("subtitle") or ""
        bullets = s.get("bullets") or []
        body_text = s.get("content") or ""

        if layout == 0:
            if len(slide.placeholders) > 1:
                slide.placeholders[1].text = subtitle or body_text or "EduSHAMIIT Presentation"
        else:
            if len(slide.placeholders) > 1:
                tf = slide.placeholders[1].text_frame
                tf.clear()
                if bullets:
                    for b_idx, b in enumerate(bullets):
                        p = tf.paragraphs[0] if b_idx == 0 else tf.add_paragraph()
                        p.text = str(b)
                        p.level = 0
                elif body_text:
                    tf.paragraphs[0].text = body_text

        notes = s.get("notes") or ""
        if notes and slide.has_notes_slide:
            slide.notes_slide.notes_text_frame.text = notes

    prs.save(output_path)


def save_sheets_to_disk(file_path: str, file_type: str, payload_data: Dict[str, Any], title: str = "Document") -> Tuple[int, str]:
    """Write updated sheet matrix, presentation slides, or document content back to disk, returning (size, sha256)."""
    os.makedirs(os.path.dirname(file_path), exist_ok=True)
    ft = (file_type or "").upper()
    data_type = payload_data.get("type") or ""

    # 1. Plain Text / Markdown Save (.txt, .md, .log, .json)
    if "TXT" in ft or "MD" in ft or file_path.lower().endswith((".txt", ".md", ".log", ".json")):
        content = payload_data.get("content") or ""
        import html as html_lib
        plain_text = re.sub(r'</?(p|div|h[1-6]|li|blockquote)[^>]*>', '\n', content, flags=re.IGNORECASE)
        plain_text = re.sub(r'<br\s*/?>', '\n', plain_text, flags=re.IGNORECASE)
        plain_text = re.sub(r'<[^>]+>', '', plain_text)
        plain_text = html_lib.unescape(plain_text).strip()
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(plain_text)

    # 2. Presentation Save (.pptx)
    elif data_type == "presentation" or "PPT" in ft or file_path.lower().endswith((".pptx", ".ppt")):
        slides = payload_data.get("slides") or []
        _slides_to_pptx_file(slides, file_path, title)

    # 3. Document Save (.docx, .doc, .rtf)
    elif data_type == "document" or "DOC" in ft or file_path.lower().endswith((".docx", ".doc", ".rtf")):
        content = payload_data.get("content") or "<p></p>"
        _html_to_docx_file(content, file_path, title)

    # 4. CSV Save
    elif "CSV" in ft or file_path.lower().endswith(".csv"):
        sheets = payload_data.get("sheets") or []
        first_sheet_data = sheets[0].get("data") if sheets else []
        with open(file_path, "w", encoding="utf-8", newline="") as f:
            writer = csv.writer(f)
            for row in first_sheet_data:
                writer.writerow(row)

    # 5. XLSX Save
    elif ("XLS" in ft or file_path.lower().endswith(".xlsx")) and openpyxl:
        wb = openpyxl.Workbook()
        default_sheet = wb.active
        sheets = payload_data.get("sheets") or []
        for idx, s in enumerate(sheets):
            s_name = s.get("name") or f"Sheet{idx+1}"
            ws = wb.create_sheet(title=s_name[:31])
            for r in s.get("data", []):
                ws.append(r)
        if default_sheet and len(wb.sheetnames) > 1:
            wb.remove(default_sheet)
        wb.save(file_path)

    # 6. Fallback
    else:
        content = payload_data.get("content") or ""
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(content)

    file_size = os.path.getsize(file_path)
    with open(file_path, "rb") as f:
        checksum = hashlib.sha256(f.read()).hexdigest()

    return file_size, checksum


# Backward compatibility alias
save_document_data = save_sheets_to_disk


# ============================================================================
# REAL-TIME COLLABORATIVE ROOM & HUB (REDIS PUB/SUB MULTI-WORKER ENABLED)
# ============================================================================

LOCAL_WORKER_ID = str(uuid.uuid4())[:8]


class DocumentCollabRoom:
    """In-memory & Redis PubSub collaboration room supporting cross-worker synchronization across all formats."""
    def __init__(self, doc_id: str, school_id: str, doc_metadata: dict, initial_data: dict, file_path: Optional[str]):
        self.doc_id = doc_id
        self.school_id = school_id
        self.doc_metadata = doc_metadata
        self.data = initial_data
        self.file_path = file_path
        self.version = 1
        self.users: Dict[str, dict] = {} # conn_id -> user_dict
        self.connections: Dict[str, WebSocket] = {} # conn_id -> ws
        self.events_history: List[dict] = []
        self.dirty = False
        self.last_saved_at = datetime.utcnow()
        self.color_idx = 0
        self._sub_task = None

    def start_redis_listener(self):
        if not self._sub_task or self._sub_task.done():
            self._sub_task = asyncio.create_task(self._redis_subscribe_loop())

    async def _redis_subscribe_loop(self):
        try:
            from app.cache.redis_client import get_redis
            rc = get_redis()
            if not rc:
                return
            pubsub = rc.pubsub()
            await pubsub.subscribe(f"collab:channel:{self.doc_id}")
            async for item in pubsub.listen():
                if item.get("type") == "message":
                    try:
                        raw = item.get("data")
                        if not raw:
                            continue
                        msg = json.loads(raw)
                        if msg.get("_worker_id") == LOCAL_WORKER_ID:
                            continue  # Ignore self-published messages

                        mtype = msg.get("type")
                        if mtype == "content_updated" and msg.get("content") is not None:
                            self.data["content"] = msg["content"]
                        elif mtype == "presentation_updated" and msg.get("slides") is not None:
                            self.data["slides"] = msg["slides"]
                        elif mtype == "cell_updated":
                            sheet = msg.get("sheet", 0)
                            row = msg.get("row", 0)
                            col = msg.get("col", 0)
                            val = msg.get("value", "")
                            sheets = self.data.get("sheets") or []
                            if sheet < len(sheets):
                                grid = sheets[sheet].get("data") or []
                                while len(grid) <= row: grid.append([])
                                while len(grid[row]) <= col: grid[row].append("")
                                grid[row][col] = val

                        # Broadcast to all local WebSockets on this worker
                        dead_conns = []
                        for cid, ws in list(self.connections.items()):
                            try:
                                await ws.send_json(msg)
                            except Exception:
                                dead_conns.append(cid)
                        for cid in dead_conns:
                            self.connections.pop(cid, None)
                            self.users.pop(cid, None)
                    except Exception as err:
                        logger.warning(f"Error handling Redis collab message: {err}")
        except asyncio.CancelledError:
            pass
        except Exception as e:
            logger.warning(f"Redis collab listener stopped: {e}")

    def get_next_color(self) -> str:
        color = COLLAB_COLORS[self.color_idx % len(COLLAB_COLORS)]
        self.color_idx += 1
        return color

    async def add_connection(self, conn_id: str, user_dict: dict, ws: Optional[WebSocket] = None):
        user_info = {
            "conn_id": conn_id,
            "id": user_dict.get("id") or conn_id,
            "name": user_dict.get("full_name") or user_dict.get("name") or "Collaborator",
            "role": user_dict.get("role") or "User",
            "color": self.get_next_color(),
            "cursor": None,
            "joined_at": datetime.utcnow().isoformat()
        }
        self.users[conn_id] = user_info
        if ws:
            self.connections[conn_id] = ws

        self.start_redis_listener()

        # Update Redis user registry
        all_users = list(self.users.values())
        try:
            from app.cache.redis_client import get_redis
            rc = get_redis()
            if rc:
                await rc.hset(f"collab:users:{self.doc_id}", conn_id, json.dumps(user_info, default=str))
                await rc.expire(f"collab:users:{self.doc_id}", 3600)
                raw_users = await rc.hgetall(f"collab:users:{self.doc_id}")
                if raw_users:
                    all_users = [json.loads(v) for v in raw_users.values()]
        except Exception:
            pass

        event = {
            "type": "user_joined",
            "user": user_info,
            "total_users": len(all_users),
            "users": all_users
        }
        await self.broadcast(event, exclude_conn_id=conn_id)
        return user_info

    async def remove_connection(self, conn_id: str):
        user_info = self.users.pop(conn_id, None)
        self.connections.pop(conn_id, None)

        all_users = list(self.users.values())
        try:
            from app.cache.redis_client import get_redis
            rc = get_redis()
            if rc:
                await rc.hdel(f"collab:users:{self.doc_id}", conn_id)
                raw_users = await rc.hgetall(f"collab:users:{self.doc_id}")
                if raw_users:
                    all_users = [json.loads(v) for v in raw_users.values()]
        except Exception:
            pass

        if user_info:
            event = {
                "type": "user_left",
                "conn_id": conn_id,
                "user": user_info,
                "total_users": len(all_users),
                "users": all_users
            }
            await self.broadcast(event)

    async def broadcast(self, message: dict, exclude_conn_id: Optional[str] = None):
        message["_version"] = self.version
        message["_ts"] = time.time()
        message["_worker_id"] = LOCAL_WORKER_ID
        self.events_history.append(message)
        if len(self.events_history) > 100:
            self.events_history.pop(0)

        # 1. Send locally to this worker's connections
        dead_conns = []
        for cid, ws in list(self.connections.items()):
            if cid == exclude_conn_id:
                continue
            try:
                await ws.send_json(message)
            except Exception:
                dead_conns.append(cid)

        for cid in dead_conns:
            self.connections.pop(cid, None)
            self.users.pop(cid, None)

        # 2. Publish to Redis so all other Gunicorn workers broadcast to their connections
        try:
            from app.cache.redis_client import get_redis
            rc = get_redis()
            if rc:
                await rc.publish(f"collab:channel:{self.doc_id}", json.dumps(message, default=str))
                if message.get("type") in ("content_updated", "presentation_updated", "cell_updated", "saved"):
                    await rc.setex(f"collab:state:{self.doc_id}", 7200, json.dumps(self.data, default=str))
        except Exception as e:
            logger.warning(f"Redis broadcast publish failed: {e}")

    # ─── Spreadsheet Actions ───
    def apply_cell_edit(self, sheet_idx: int, row: int, col: int, value: str, user_dict: dict) -> dict:
        sheets = self.data.get("sheets") or []
        if sheet_idx >= len(sheets):
            return {"error": "Sheet index out of range"}
        sheet = sheets[sheet_idx]
        grid = sheet.get("data") or []

        while len(grid) <= row:
            grid.append([""] * (sheet.get("cols_count") or 10))
        while len(grid[row]) <= col:
            grid[row].append("")

        old_val = grid[row][col]
        grid[row][col] = str(value)
        sheet["rows_count"] = len(grid)
        sheet["cols_count"] = max(len(r) for r in grid)

        self.version += 1
        self.dirty = True

        event = {
            "type": "cell_updated",
            "sheet": sheet_idx,
            "row": row,
            "col": col,
            "value": str(value),
            "old_value": old_val,
            "author_id": user_dict.get("id"),
            "author_name": user_dict.get("full_name") or user_dict.get("name") or "User",
            "version": self.version
        }
        return event

    def apply_structure_change(self, change_type: str, sheet_idx: int, params: dict, user_dict: dict) -> dict:
        sheets = self.data.get("sheets") or []
        if sheet_idx >= len(sheets):
            return {"error": "Sheet index out of range"}
        sheet = sheets[sheet_idx]
        grid = sheet.get("data") or []
        cols_count = sheet.get("cols_count") or 10

        if change_type == "add_row":
            after_row = params.get("row", len(grid))
            new_row = [""] * cols_count
            grid.insert(after_row, new_row)
            sheet["rows_count"] = len(grid)
        elif change_type == "delete_row":
            del_row = params.get("row", len(grid) - 1)
            if 0 <= del_row < len(grid) and len(grid) > 1:
                grid.pop(del_row)
                sheet["rows_count"] = len(grid)
        elif change_type == "add_col":
            for r in grid:
                r.append("")
            sheet["cols_count"] = len(grid[0]) if grid else 10

        self.version += 1
        self.dirty = True
        return {
            "type": "structure_updated",
            "change_type": change_type,
            "sheet": sheet_idx,
            "rows_count": sheet["rows_count"],
            "cols_count": sheet["cols_count"],
            "data": grid,
            "version": self.version
        }

    # ─── Word / Document Actions ───
    def apply_content_edit(self, content: str, user_dict: dict) -> dict:
        self.data["content"] = str(content)
        self.version += 1
        self.dirty = True
        event = {
            "type": "content_updated",
            "content": str(content),
            "author_id": user_dict.get("id"),
            "author_name": user_dict.get("full_name") or user_dict.get("name") or "User",
            "version": self.version
        }
        return event

    # ─── Presentation Actions ───
    def apply_presentation_edit(self, action: str, params: dict, user_dict: dict) -> dict:
        slides = self.data.get("slides") or []
        if "slides" in params and isinstance(params["slides"], list):
            slides = params["slides"]
        elif action == "update_slide":
            slide_idx = int(params.get("slide_idx", 0))
            if 0 <= slide_idx < len(slides):
                if "title" in params:
                    slides[slide_idx]["title"] = str(params["title"])
                if "subtitle" in params:
                    slides[slide_idx]["subtitle"] = str(params["subtitle"])
                if "bullets" in params:
                    slides[slide_idx]["bullets"] = list(params["bullets"])
                if "notes" in params:
                    slides[slide_idx]["notes"] = str(params["notes"])
        elif action == "add_slide":
            new_id = len(slides) + 1
            slides.append({
                "id": new_id,
                "title": params.get("title") or f"Slide {new_id}",
                "subtitle": params.get("subtitle") or "",
                "bullets": params.get("bullets") or ["New discussion topic", "Key takeaway"],
                "notes": params.get("notes") or "",
                "layout": "bullets"
            })
        elif action == "delete_slide":
            slide_idx = int(params.get("slide_idx", -1))
            if 0 <= slide_idx < len(slides) and len(slides) > 1:
                slides.pop(slide_idx)
                for i, s in enumerate(slides):
                    s["id"] = i + 1

        self.data["slides"] = slides
        self.version += 1
        self.dirty = True

        event = {
            "type": "presentation_updated",
            "action": action,
            "slides": slides,
            "active_slide": params.get("active_slide", 0),
            "author_id": user_dict.get("id"),
            "author_name": user_dict.get("full_name") or user_dict.get("name") or "User",
            "version": self.version
        }
        return event


class DocumentCollabHub:
    """Global manager for all live collaborative rooms."""
    def __init__(self):
        self.rooms: Dict[str, DocumentCollabRoom] = {}
        self.lock = asyncio.Lock()

    async def get_or_create_room(self, doc_id: str, school_id: str, doc_metadata: dict) -> DocumentCollabRoom:
        async with self.lock:
            if doc_id in self.rooms:
                return self.rooms[doc_id]

            storage_path = doc_metadata.get("storage_path")
            file_path = resolve_local_file_path(storage_path)
            file_type = doc_metadata.get("file_type") or "DOCX"
            title = doc_metadata.get("title") or doc_metadata.get("file_name") or "Document"
            initial_data = parse_file_to_sheets(file_path, file_type, doc_metadata.get("content"), fallback_title=title)

            # Check if Redis has live state from another worker
            try:
                from app.cache.redis_client import get_redis
                rc = get_redis()
                if rc:
                    cached_state = await rc.get(f"collab:state:{doc_id}")
                    if cached_state:
                        state_dict = json.loads(cached_state)
                        if isinstance(state_dict, dict) and state_dict:
                            initial_data = state_dict
            except Exception:
                pass

            room = DocumentCollabRoom(
                doc_id=doc_id,
                school_id=school_id,
                doc_metadata=doc_metadata,
                initial_data=initial_data,
                file_path=file_path
            )
            self.rooms[doc_id] = room
            return room

    def get_room(self, doc_id: str) -> Optional[DocumentCollabRoom]:
        return self.rooms.get(doc_id)


# Global Hub Singleton
collab_hub = DocumentCollabHub()


# ============================================================================
# HTML TEMPLATE RENDERERS
# ============================================================================

def render_access_denied_html(title: str, reason: str, error_code: int = 403) -> str:
    """Render an authoritative branded Access Denied / Unauthorized page."""
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{title} • EduSHAMIIT Security</title>
  <style>
    body {{
      background: #0B132B;
      color: #E2E8F0;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      margin: 0;
      padding: 20px;
      box-sizing: border-box;
    }}
    .card {{
      background: #1C2541;
      border: 1px solid rgba(239, 68, 68, 0.35);
      border-radius: 18px;
      max-width: 520px;
      width: 100%;
      padding: 40px 36px;
      text-align: center;
      box-shadow: 0 24px 48px rgba(0,0,0,0.5);
    }}
    .icon {{
      width: 72px;
      height: 72px;
      margin: 0 auto 24px;
      background: rgba(239, 68, 68, 0.15);
      border: 1px solid rgba(239, 68, 68, 0.4);
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 32px;
    }}
    h1 {{
      font-size: 22px;
      font-weight: 800;
      color: #F87171;
      margin: 0 0 14px;
    }}
    p {{
      color: #94A3B8;
      font-size: 14.5px;
      line-height: 1.65;
      margin: 0 0 28px;
    }}
    .btn {{
      display: inline-block;
      background: #2563EB;
      color: #FFFFFF;
      text-decoration: none;
      font-size: 14px;
      font-weight: 700;
      padding: 12px 28px;
      border-radius: 10px;
      transition: background 0.2s, transform 0.1s;
    }}
    .btn:hover {{
      background: #1D4ED8;
      transform: translateY(-1px);
    }}
    .security-note {{
      margin-top: 24px;
      font-size: 11.5px;
      color: #64748B;
    }}
  </style>
</head>
<body>
  <div class="card">
    <div class="icon">🔒</div>
    <h1>{title}</h1>
    <p>{reason}</p>
    <a href="/admin/documents" class="btn">Return to Documents Vault</a>
    <div class="security-note">EduSHAMIIT Unified Security &amp; Access Control Protocol</div>
  </div>
</body>
</html>"""


def render_collaborative_editor_html(
    doc: Dict[str, Any],
    initial_data: Dict[str, Any],
    current_user: Dict[str, Any],
    token: str,
    can_edit: bool = True,
    access_level: str = "editor"
) -> str:
    """Dispatch to format-specific collaborative editor application."""
    doc_type = initial_data.get("type", "document")
    file_type = (doc.get("file_type") or "DOCX").upper()

    if doc_type == "presentation" or "PPT" in file_type:
        return render_collaborative_presentation_html(doc, initial_data, current_user, token, can_edit, access_level)
    elif doc_type == "document" or "DOC" in file_type or "TXT" in file_type or "MD" in file_type:
        return render_collaborative_document_html(doc, initial_data, current_user, token, can_edit, access_level)
    elif doc_type == "pdf" or "PDF" in file_type:
        return render_collaborative_pdf_html(doc, initial_data, current_user, token)
    else:
        return render_collaborative_spreadsheet_html(doc, initial_data, current_user, token, can_edit, access_level)


# ────────────────────────────────────────────────────────────────────────────
# 1. COLLABORATIVE WORD / DOCUMENT EDITOR (Google Docs / MS Word Style)
# ────────────────────────────────────────────────────────────────────────────

def render_collaborative_document_html(
    doc: Dict[str, Any],
    initial_data: Dict[str, Any],
    current_user: Dict[str, Any],
    token: str,
    can_edit: bool = True,
    access_level: str = "editor"
) -> str:
    doc_id = str(doc.get("id"))
    doc_title = doc.get("title") or doc.get("file_name") or "Document"
    file_name = doc.get("file_name") or f"{doc_title}.docx"
    file_type = (doc.get("file_type") or "DOCX").upper()
    version_num = f"v{doc.get('version_number') or 1}.0"
    content_html = initial_data.get("content") or "<p>Start typing...</p>"

    save_btn_html = '<button class="btn btn-primary" onclick="saveDocument()">💾 Save &amp; Version</button>' if can_edit else '<span style="background: rgba(59, 130, 246, 0.15); color: #60A5FA; border: 1px solid rgba(59, 130, 246, 0.3); padding: 6px 14px; border-radius: 8px; font-size: 12px; font-weight: 700; display: inline-flex; align-items: center; gap: 6px;">👁️ View Only</span>'
    toolbar_style = "" if can_edit else 'style="display: none;"'
    editable_attr = 'contenteditable="true"' if can_edit else 'contenteditable="false"'
    status_text = 'All changes saved to EduSHAMIIT' if can_edit else 'View Only Mode • Read Access'
    footer_text = 'EduSHAMIIT Unified Collaborative Word Suite • Live Autosave Active' if can_edit else 'EduSHAMIIT Unified Collaborative Word Suite • View Only Mode'

    user_json = json.dumps(current_user).replace("</script>", "<\\/script>")
    doc_json = json.dumps({
        "id": doc_id,
        "title": doc_title,
        "file_name": file_name,
        "file_type": file_type,
        "version_number": version_num,
        "can_edit": can_edit,
        "access_level": access_level
    }).replace("</script>", "<\\/script>")

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>{doc_title} - EduSHAMIIT Live Document Editor</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
  <style>
    :root {{
      --bg-page: #0B1120;
      --bg-panel: #1E293B;
      --bg-subtle: #0F172A;
      --border-color: #334155;
      --text-primary: #F8FAFC;
      --text-secondary: #94A3B8;
      --primary: #2563EB;
      --primary-hover: #1D4ED8;
      --font-main: 'Plus Jakarta Sans', system-ui, sans-serif;
    }}
    * {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{
      font-family: var(--font-main);
      background-color: var(--bg-page);
      color: var(--text-primary);
      height: 100vh;
      overflow: hidden;
      display: flex;
      flex-direction: column;
    }}
    .editor-header {{
      background: var(--bg-panel);
      border-bottom: 1px solid var(--border-color);
      padding: 10px 20px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
      flex-shrink: 0;
      z-index: 100;
    }}
    .header-left {{ display: flex; align-items: center; gap: 12px; min-width: 0; }}
    .brand-icon {{
      width: 38px; height: 38px;
      background: linear-gradient(135deg, #2563EB, #1D4ED8);
      border-radius: 10px;
      display: flex; align-items: center; justify-content: center;
      color: #fff; font-size: 18px; font-weight: 800;
      box-shadow: 0 4px 12px rgba(37, 99, 235, 0.35);
      flex-shrink: 0;
    }}
    .doc-meta {{ display: flex; flex-direction: column; min-width: 0; }}
    .doc-title-row {{ display: flex; align-items: center; gap: 8px; }}
    .doc-title {{
      font-size: 15px; font-weight: 800; color: #fff;
      white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 320px;
    }}
    .badge-type {{
      background: #2563EB; color: #fff; font-size: 10px; font-weight: 800;
      padding: 2px 7px; border-radius: 4px; letter-spacing: 0.5px;
    }}
    .badge-ver {{
      background: rgba(37, 99, 235, 0.2); border: 1px solid rgba(37, 99, 235, 0.4);
      color: #93C5FD; font-size: 10px; font-weight: 700; padding: 2px 6px; border-radius: 4px;
    }}
    .save-status {{ display: flex; align-items: center; gap: 6px; font-size: 11px; color: var(--text-secondary); margin-top: 2px; }}
    .status-dot {{ width: 7px; height: 7px; border-radius: 50%; background: #10B981; }}
    .status-dot.dirty {{ background: #F59E0B; }}

    .header-right {{ display: flex; align-items: center; gap: 10px; flex-shrink: 0; }}
    .collab-group {{ display: flex; align-items: center; gap: -6px; }}
    .collab-avatar {{
      width: 30px; height: 30px; border-radius: 50%;
      display: flex; align-items: center; justify-content: center;
      font-weight: 700; font-size: 11.5px; color: #fff;
      border: 2px solid var(--bg-panel);
    }}
    .online-counter {{
      background: rgba(37, 99, 235, 0.18); border: 1px solid rgba(37, 99, 235, 0.4);
      color: #93C5FD; font-size: 11px; font-weight: 600; padding: 4px 10px; border-radius: 20px;
      display: flex; align-items: center; gap: 5px;
    }}
    .btn {{
      font-family: var(--font-main); font-size: 12px; font-weight: 600;
      padding: 6px 12px; border-radius: 8px; border: 1px solid transparent;
      cursor: pointer; display: inline-flex; align-items: center; gap: 6px;
      transition: all 0.2s ease;
    }}
    .btn-primary {{ background: var(--primary); color: #fff; }}
    .btn-primary:hover {{ background: var(--primary-hover); }}
    .btn-outline {{ background: transparent; border-color: var(--border-color); color: var(--text-primary); }}
    .btn-outline:hover {{ background: rgba(255, 255, 255, 0.05); }}

    /* ─── Rich Toolbar ─── */
    .editor-toolbar {{
      background: var(--bg-subtle);
      border-bottom: 1px solid var(--border-color);
      padding: 6px 20px;
      display: flex;
      align-items: center;
      gap: 6px;
      overflow-x: auto;
      flex-shrink: 0;
    }}
    .tool-btn {{
      background: transparent; border: 1px solid transparent; color: var(--text-secondary);
      width: 30px; height: 30px; border-radius: 6px; font-size: 13px; font-weight: 700;
      cursor: pointer; display: flex; align-items: center; justify-content: center;
    }}
    .tool-btn:hover {{ background: rgba(255, 255, 255, 0.08); color: #fff; }}
    .tool-btn.active {{ background: rgba(37, 99, 235, 0.25); color: #93C5FD; border-color: rgba(37, 99, 235, 0.4); }}
    .tool-select {{
      background: var(--bg-panel); color: var(--text-primary); border: 1px solid var(--border-color);
      border-radius: 6px; padding: 4px 8px; font-size: 12px; font-family: var(--font-main); outline: none;
    }}
    .tool-divider {{ width: 1px; height: 20px; background: var(--border-color); margin: 0 4px; }}

    /* ─── Document Canvas (Google Docs Sheet View) ─── */
    .document-viewport {{
      flex: 1;
      overflow-y: auto;
      background: var(--bg-page);
      padding: 30px 16px 80px;
      display: flex;
      justify-content: center;
    }}
    .document-page {{
      width: 816px;
      min-height: 1056px;
      background: #FFFFFF;
      color: #0F172A;
      box-shadow: 0 10px 40px rgba(0, 0, 0, 0.45);
      border-radius: 4px;
      padding: 64px 72px;
      outline: none;
      font-size: 14px;
      line-height: 1.7;
    }}
    .document-page h1 {{ font-size: 28px; font-weight: 800; color: #0F172A; margin: 0 0 16px; line-height: 1.3; }}
    .document-page h2 {{ font-size: 20px; font-weight: 700; color: #1E293B; margin: 24px 0 12px; }}
    .document-page h3 {{ font-size: 16px; font-weight: 700; color: #334155; margin: 18px 0 8px; }}
    .document-page p {{ margin: 0 0 12px; }}
    .document-page ul, .document-page ol {{ margin: 0 0 14px; padding-left: 24px; }}
    .document-page li {{ margin-bottom: 4px; }}
    .document-page blockquote {{
      border-left: 4px solid var(--primary);
      padding: 10px 16px;
      background: #F1F5F9;
      color: #475569;
      font-style: italic;
      margin: 14px 0;
      border-radius: 0 6px 6px 0;
    }}
    .document-page table.doc-table {{
      width: 100%;
      border-collapse: collapse;
      margin: 16px 0;
      font-size: 13px;
    }}
    .document-page table.doc-table th, .document-page table.doc-table td {{
      border: 1px solid #CBD5E1;
      padding: 8px 12px;
      text-align: left;
    }}
    .document-page table.doc-table th {{
      background: #F8FAFC;
      font-weight: 700;
      color: #1E293B;
    }}

    .editor-footer {{
      background: var(--bg-panel);
      border-top: 1px solid var(--border-color);
      padding: 6px 20px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      flex-shrink: 0;
      font-size: 11.5px;
      color: var(--text-secondary);
    }}
    .toast {{
      position: fixed; bottom: 24px; right: 24px;
      background: var(--bg-panel); border: 1px solid var(--border-color);
      padding: 12px 18px; border-radius: 10px; color: #fff;
      font-size: 13px; font-weight: 600; box-shadow: 0 10px 25px rgba(0,0,0,0.5);
      display: flex; align-items: center; gap: 10px;
      transform: translateY(100px); opacity: 0; transition: all 0.3s ease; z-index: 1000;
    }}
    .toast.show {{ transform: translateY(0); opacity: 1; }}

    @media print {{
      body {{ background: #fff; color: #000; overflow: visible; height: auto; }}
      .editor-header, .editor-toolbar, .editor-footer, .toast {{ display: none !important; }}
      .document-viewport {{ padding: 0; background: #fff; overflow: visible; }}
      .document-page {{ box-shadow: none; width: 100%; min-height: auto; padding: 0; margin: 0; }}
    }}
  </style>
</head>
<body>

  <!-- Top Header -->
  <header class="editor-header">
    <div class="header-left">
      <div class="brand-icon">E</div>
      <div class="doc-meta">
        <div class="doc-title-row">
          <span class="doc-title" id="doc-title">{file_name}</span>
          <span class="badge-type">{file_type}</span>
          <span class="badge-ver" id="version-badge">{version_num}</span>
        </div>
        <div class="save-status">
          <span class="status-dot" id="status-dot"></span>
          <span id="status-text">{status_text}</span>
        </div>
      </div>
    </div>

    <div class="header-right">
      <div class="collab-group" id="collab-avatars"></div>
      <div class="online-counter" id="online-counter">
        <span>🟢</span> <span id="online-count">1</span> Editing Live
      </div>
      <button class="btn btn-outline" onclick="window.print()">🖨️ Print / PDF</button>
      <button class="btn btn-outline" onclick="exportDocx()">📥 Export (.docx)</button>
      <button class="btn btn-outline" onclick="copyCollabLink()">🔗 Share Link</button>
      {save_btn_html}
    </div>
  </header>

  <!-- Formatting Toolbar -->
  <div class="editor-toolbar" {toolbar_style}>
    <select class="tool-select" onchange="formatBlock(this.value)">
      <option value="p">Normal Text</option>
      <option value="h1">Heading 1</option>
      <option value="h2">Heading 2</option>
      <option value="h3">Heading 3</option>
      <option value="blockquote">Quote</option>
      <option value="pre">Code Block</option>
    </select>
    <div class="tool-divider"></div>
    <button class="tool-btn" onclick="execCmd('bold')" title="Bold (Ctrl+B)"><b>B</b></button>
    <button class="tool-btn" onclick="execCmd('italic')" title="Italic (Ctrl+I)"><i>I</i></button>
    <button class="tool-btn" onclick="execCmd('underline')" title="Underline (Ctrl+U)"><u>U</u></button>
    <button class="tool-btn" onclick="execCmd('strikeThrough')" title="Strikethrough"><s>S</s></button>
    <div class="tool-divider"></div>
    <button class="tool-btn" onclick="execCmd('justifyLeft')" title="Align Left">≡</button>
    <button class="tool-btn" onclick="execCmd('justifyCenter')" title="Align Center">⫘</button>
    <button class="tool-btn" onclick="execCmd('justifyRight')" title="Align Right">≡</button>
    <button class="tool-btn" onclick="execCmd('justifyFull')" title="Justify">☰</button>
    <div class="tool-divider"></div>
    <button class="tool-btn" onclick="execCmd('insertUnorderedList')" title="Bullet List">• ≡</button>
    <button class="tool-btn" onclick="execCmd('insertOrderedList')" title="Numbered List">1. ≡</button>
    <div class="tool-divider"></div>
    <button class="tool-btn" onclick="insertTable()" title="Insert Table">▦</button>
    <button class="tool-btn" onclick="execCmd('insertHorizontalRule')" title="Divider Line">—</button>
    <button class="tool-btn" onclick="execCmd('removeFormat')" title="Clear Formatting">⌫</button>
    <div class="tool-divider"></div>
    <span style="font-size: 11.5px; color: var(--text-secondary); margin-left: auto;" id="stat-words">
      Words: 0 • Chars: 0
    </span>
  </div>

  <!-- Document Viewport -->
  <div class="document-viewport">
    <div class="document-page" id="editor" {editable_attr} spellcheck="true">
      {content_html}
    </div>
  </div>

  <!-- Footer -->
  <footer class="editor-footer">
    <div>{footer_text}</div>
    <div id="footer-save-time">Last saved: Just now</div>
  </footer>

  <div class="toast" id="toast">
    <span id="toast-message">Document saved</span>
  </div>

  <script>
    const CAN_EDIT = {"true" if can_edit else "false"};
    const CURRENT_USER = {user_json};
    const DOC_INFO = {doc_json};
    const AUTH_TOKEN = "{token}";
    let isDirty = false;
    let autoSaveTimer = null;
    let ws = null;
    const editor = document.getElementById('editor');

    function execCmd(command, value = null) {{
      if (!CAN_EDIT) return;
      document.execCommand(command, false, value);
      editor.focus();
      triggerDirty();
    }}

    function formatBlock(tag) {{
      if (!CAN_EDIT) return;
      document.execCommand('formatBlock', false, tag);
      editor.focus();
      triggerDirty();
    }}

    function insertTable() {{
      if (!CAN_EDIT) return;
      const tbl = '<table class="doc-table"><tr><th>Header 1</th><th>Header 2</th><th>Header 3</th></tr><tr><td>Data 1</td><td>Data 2</td><td>Data 3</td></tr><tr><td>Data 4</td><td>Data 5</td><td>Data 6</td></tr></table><p></p>';
      document.execCommand('insertHTML', false, tbl);
      triggerDirty();
    }}

    function updateWordCount() {{
      const text = editor.innerText || '';
      const words = text.trim() ? text.trim().split(/\s+/).length : 0;
      const chars = text.length;
      document.getElementById('stat-words').innerText = `Words: ${{words}} • Chars: ${{chars}}`;
    }}

    function triggerDirty() {{
      if (!CAN_EDIT) return;
      isDirty = true;
      document.getElementById('status-dot').className = 'status-dot dirty';
      document.getElementById('status-text').innerText = 'Unsaved changes...';
      updateWordCount();
      if (autoSaveTimer) clearTimeout(autoSaveTimer);
      autoSaveTimer = setTimeout(saveDocument, 4000);
      broadcastEdit();
    }}

    if (CAN_EDIT) {{
      editor.addEventListener('input', triggerDirty);
    }} else {{
      editor.setAttribute('contenteditable', 'false');
    }}
    updateWordCount();

    function showToast(msg) {{
      const t = document.getElementById('toast');
      document.getElementById('toast-message').innerText = msg;
      t.className = 'toast show';
      setTimeout(() => {{ t.className = 'toast'; }}, 3000);
    }}

    async function saveDocument() {{
      if (!CAN_EDIT) return;
      if (autoSaveTimer) clearTimeout(autoSaveTimer);
      document.getElementById('status-text').innerText = 'Saving version...';
      try {{
        const res = await fetch(`/api/documents/${{DOC_INFO.id}}/collab/save`, {{
          method: 'POST',
          headers: {{ 'Content-Type': 'application/json', 'Authorization': `Bearer ${{AUTH_TOKEN}}` }},
          body: JSON.stringify({{ content: editor.innerHTML }})
        }});
        const data = await res.json();
        if (data.success) {{
          isDirty = false;
          document.getElementById('status-dot').className = 'status-dot';
          document.getElementById('status-text').innerText = `Saved ${{data.version_number || ''}}`;
          if (data.version_number) document.getElementById('version-badge').innerText = data.version_number;
          document.getElementById('footer-save-time').innerText = `Last saved: ${{new Date().toLocaleTimeString()}}`;
          showToast(`Saved version ${{data.version_number || ''}} successfully`);
        }}
      }} catch (e) {{
        document.getElementById('status-text').innerText = 'Save error';
      }}
    }}

    function exportDocx() {{
      window.location.href = `/api/documents/${{DOC_INFO.id}}/download`;
    }}

    function copyCollabLink() {{
      navigator.clipboard.writeText(window.location.href).then(() => {{
        showToast('Live collaborative link copied to clipboard!');
      }});
    }}

    // ─── Caret Preservation for Real-Time Content Sync ───
    function getCaretOffset(element) {{
      let caretOffset = 0;
      const sel = window.getSelection();
      if (sel && sel.rangeCount > 0) {{
        const range = sel.getRangeAt(0);
        const preCaretRange = range.cloneRange();
        preCaretRange.selectNodeContents(element);
        preCaretRange.setEnd(range.endContainer, range.endOffset);
        caretOffset = preCaretRange.toString().length;
      }}
      return caretOffset;
    }}

    function setCaretOffset(element, offset) {{
      const range = document.createRange();
      const sel = window.getSelection();
      let currentOffset = 0;
      let found = false;

      function walk(node) {{
        if (found) return;
        if (node.nodeType === Node.TEXT_NODE) {{
          const nextOffset = currentOffset + node.length;
          if (offset >= currentOffset && offset <= nextOffset) {{
            range.setStart(node, offset - currentOffset);
            range.collapse(true);
            found = true;
            return;
          }}
          currentOffset = nextOffset;
        }} else {{
          for (let i = 0; i < node.childNodes.length; i++) {{
            walk(node.childNodes[i]);
            if (found) return;
          }}
        }}
      }}

      walk(element);
      if (!found) {{
        range.selectNodeContents(element);
        range.collapse(false);
      }}
      sel.removeAllRanges();
      sel.addRange(range);
    }}

    let broadcastDebounceTimer = null;
    function broadcastEdit() {{
      if (!CAN_EDIT) return;
      if (broadcastDebounceTimer) clearTimeout(broadcastDebounceTimer);
      broadcastDebounceTimer = setTimeout(() => {{
        if (ws && ws.readyState === WebSocket.OPEN) {{
          ws.send(JSON.stringify({{
            type: 'content_edit',
            content: editor.innerHTML,
            cursor_pos: getCaretOffset(editor)
          }}));
        }}
      }}, 40);
    }}

    // ─── WebSocket Multi-User Presence & Real-Time Sync ───
    let MY_CONN_ID = null;
    let lastKnownVersion = 0;

    function initWebSocket() {{
      const proto = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
      const wsUrl = `${{proto}}//${{window.location.host}}/api/ws/documents/${{DOC_INFO.id}}?token=${{AUTH_TOKEN}}&client_id=${{encodeURIComponent(CURRENT_USER.id)}}&name=${{encodeURIComponent(CURRENT_USER.name || CURRENT_USER.full_name || 'Collaborator')}}`;
      try {{
        ws = new WebSocket(wsUrl);
        ws.onopen = () => {{
          ws.send(JSON.stringify({{ type: 'join', user: CURRENT_USER }}));
        }};
        ws.onmessage = (event) => {{
          try {{
            const msg = JSON.parse(event.data);
            if (msg.type === 'init') {{
              MY_CONN_ID = msg.my_user ? msg.my_user.conn_id : null;
              updateUsers(msg.users || []);
              if (msg.version) lastKnownVersion = msg.version;
            }} else if (msg.type === 'user_joined' || msg.type === 'user_left') {{
              updateUsers(msg.users || []);
            }} else if (msg.type === 'content_updated') {{
              if (msg.conn_id !== MY_CONN_ID && msg.author_id !== CURRENT_USER.id) {{
                if (editor.innerHTML !== msg.content) {{
                  const isFocused = (document.activeElement === editor);
                  if (isFocused) {{
                    const savedOffset = getCaretOffset(editor);
                    editor.innerHTML = msg.content;
                    setCaretOffset(editor, savedOffset);
                  }} else {{
                    editor.innerHTML = msg.content;
                  }}
                  updateWordCount();
                  const statusDot = document.getElementById('status-dot');
                  const statusText = document.getElementById('status-text');
                  statusDot.className = 'status-dot';
                  statusText.innerText = `Live synced with ${{msg.author_name || 'Collaborator'}}`;
                }}
              }}
            }} else if (msg.type === 'saved') {{
              if (msg.version) {{
                document.getElementById('version-badge').innerText = `v${{msg.version}}.0`;
                document.getElementById('status-text').innerText = `Saved v${{msg.version}}.0`;
                document.getElementById('status-dot').className = 'status-dot';
              }}
            }}
          }} catch (_) {{}}
        }};
        ws.onclose = () => {{
          setTimeout(initWebSocket, 2000);
        }};
      }} catch (_) {{
        setTimeout(initWebSocket, 2000);
      }}
    }}

    async function pollCollabFallback() {{
      if (ws && ws.readyState === WebSocket.OPEN) return;
      try {{
        const res = await fetch(`/api/documents/${{DOC_INFO.id}}/collab/poll?since_version=${{lastKnownVersion}}`);
        if (res.ok) {{
          const pollData = await res.json();
          if (pollData.users) updateUsers(pollData.users);
          if (pollData.events && pollData.events.length) {{
            pollData.events.forEach(ev => {{
              if (ev.type === 'content_updated' && ev.author_id !== CURRENT_USER.id) {{
                if (editor.innerHTML !== ev.content) {{
                  const isFocused = (document.activeElement === editor);
                  if (isFocused) {{
                    const off = getCaretOffset(editor);
                    editor.innerHTML = ev.content;
                    setCaretOffset(editor, off);
                  }} else {{
                    editor.innerHTML = ev.content;
                  }}
                  updateWordCount();
                }}
              }}
            }});
            lastKnownVersion = pollData.version || lastKnownVersion;
          }}
        }}
      }} catch (_) {{}}
    }}
    setInterval(pollCollabFallback, 2500);

    function updateUsers(users) {{
      const avatars = document.getElementById('collab-avatars');
      avatars.innerHTML = '';
      (users || []).slice(0, 5).forEach(u => {{
        const d = document.createElement('div');
        d.className = 'collab-avatar';
        d.style.backgroundColor = u.color || '#2563EB';
        d.title = `${{u.name}} (${{u.role}})`;
        d.innerText = (u.name || 'U').charAt(0).toUpperCase();
        avatars.appendChild(d);
      }});
      document.getElementById('online-count').innerText = Math.max(1, (users || []).length);
    }}

    initWebSocket();
  </script>
</body>
</html>"""


# ────────────────────────────────────────────────────────────────────────────
# 2. COLLABORATIVE PRESENTATION / SLIDE DECK EDITOR (PowerPoint Style)
# ────────────────────────────────────────────────────────────────────────────

def render_collaborative_presentation_html(
    doc: Dict[str, Any],
    initial_data: Dict[str, Any],
    current_user: Dict[str, Any],
    token: str,
    can_edit: bool = True,
    access_level: str = "editor"
) -> str:
    doc_id = str(doc.get("id"))
    doc_title = doc.get("title") or doc.get("file_name") or "Presentation"
    file_name = doc.get("file_name") or f"{doc_title}.pptx"
    file_type = (doc.get("file_type") or "PPTX").upper()
    version_num = f"v{doc.get('version_number') or 1}.0"
    slides = initial_data.get("slides") or []

    save_btn_html = '<button class="btn btn-primary" onclick="savePresentation()">💾 Save &amp; Version</button>' if can_edit else '<span style="background: rgba(59, 130, 246, 0.15); color: #60A5FA; border: 1px solid rgba(59, 130, 246, 0.3); padding: 6px 14px; border-radius: 8px; font-size: 12px; font-weight: 700; display: inline-flex; align-items: center; gap: 6px;">👁️ View Only</span>'
    add_slide_btn_html = '<button class="btn btn-outline" onclick="addSlide()">➕ Add Slide</button>' if can_edit else ''
    del_slide_btn_html = '<button class="btn btn-outline" onclick="deleteCurrentSlide()">🗑️ Delete Slide</button>' if can_edit else ''
    status_text = 'All changes saved to EduSHAMIIT' if can_edit else 'View Only Mode • Read Access'
    editable_attr = 'contenteditable="true"' if can_edit else 'contenteditable="false"'
    notes_readonly = '' if can_edit else 'readonly'

    initial_slides_json = json.dumps(slides).replace("</script>", "<\\/script>")
    user_json = json.dumps(current_user).replace("</script>", "<\\/script>")
    doc_json = json.dumps({
        "id": doc_id,
        "title": doc_title,
        "file_name": file_name,
        "file_type": file_type,
        "version_number": version_num,
        "can_edit": can_edit,
        "access_level": access_level
    }).replace("</script>", "<\\/script>")

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>{doc_title} - EduSHAMIIT Presentation Studio</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
  <style>
    :root {{
      --bg-page: #050811;
      --bg-panel: #0F172A;
      --bg-subtle: #1E293B;
      --border-color: #334155;
      --text-primary: #F8FAFC;
      --text-secondary: #94A3B8;
      --primary: #F59E0B;
      --primary-hover: #D97706;
      --font-main: 'Plus Jakarta Sans', system-ui, sans-serif;
    }}
    * {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{
      font-family: var(--font-main);
      background-color: var(--bg-page);
      color: var(--text-primary);
      height: 100vh;
      overflow: hidden;
      display: flex;
      flex-direction: column;
    }}
    .editor-header {{
      background: var(--bg-panel);
      border-bottom: 1px solid var(--border-color);
      padding: 10px 20px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
      flex-shrink: 0;
      z-index: 100;
    }}
    .header-left {{ display: flex; align-items: center; gap: 12px; min-width: 0; }}
    .brand-icon {{
      width: 38px; height: 38px;
      background: linear-gradient(135deg, #F59E0B, #EA580C);
      border-radius: 10px;
      display: flex; align-items: center; justify-content: center;
      color: #fff; font-size: 18px; font-weight: 800;
      box-shadow: 0 4px 12px rgba(245, 158, 11, 0.35);
      flex-shrink: 0;
    }}
    .doc-meta {{ display: flex; flex-direction: column; min-width: 0; }}
    .doc-title-row {{ display: flex; align-items: center; gap: 8px; }}
    .doc-title {{ font-size: 15px; font-weight: 800; color: #fff; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 320px; }}
    .badge-type {{ background: #F59E0B; color: #fff; font-size: 10px; font-weight: 800; padding: 2px 7px; border-radius: 4px; }}
    .badge-ver {{ background: rgba(245, 158, 11, 0.2); border: 1px solid rgba(245, 158, 11, 0.4); color: #FCD34D; font-size: 10px; font-weight: 700; padding: 2px 6px; border-radius: 4px; }}
    .save-status {{ display: flex; align-items: center; gap: 6px; font-size: 11px; color: var(--text-secondary); margin-top: 2px; }}
    .status-dot {{ width: 7px; height: 7px; border-radius: 50%; background: #10B981; }}
    .status-dot.dirty {{ background: #F59E0B; }}

    .header-right {{ display: flex; align-items: center; gap: 10px; flex-shrink: 0; }}
    .collab-group {{ display: flex; align-items: center; gap: -6px; }}
    .collab-avatar {{
      width: 30px; height: 30px; border-radius: 50%;
      display: flex; align-items: center; justify-content: center;
      font-weight: 700; font-size: 11.5px; color: #fff;
      border: 2px solid var(--bg-panel);
    }}
    .btn {{
      font-family: var(--font-main); font-size: 12px; font-weight: 600;
      padding: 6px 12px; border-radius: 8px; border: 1px solid transparent;
      cursor: pointer; display: inline-flex; align-items: center; gap: 6px;
      transition: all 0.2s ease;
    }}
    .btn-present {{
      background: linear-gradient(135deg, #F59E0B, #EA580C);
      color: #fff; font-weight: 700; box-shadow: 0 4px 12px rgba(245, 158, 11, 0.3);
    }}
    .btn-present:hover {{ transform: translateY(-1px); }}
    .btn-primary {{ background: #2563EB; color: #fff; }}
    .btn-outline {{ background: transparent; border-color: var(--border-color); color: var(--text-primary); }}
    .btn-outline:hover {{ background: rgba(255, 255, 255, 0.05); }}

    /* ─── Main Workspace (Sidebar + Canvas) ─── */
    .studio-body {{
      flex: 1;
      display: flex;
      overflow: hidden;
    }}
    .slide-sidebar {{
      width: 240px;
      background: var(--bg-panel);
      border-right: 1px solid var(--border-color);
      overflow-y: auto;
      padding: 14px 10px;
      display: flex;
      flex-direction: column;
      gap: 12px;
      flex-shrink: 0;
    }}
    .thumb-card {{
      background: var(--bg-subtle);
      border: 2px solid var(--border-color);
      border-radius: 8px;
      padding: 10px;
      cursor: pointer;
      position: relative;
      transition: all 0.15s ease;
    }}
    .thumb-card:hover {{ border-color: #64748B; }}
    .thumb-card.active {{
      border-color: var(--primary);
      box-shadow: 0 0 12px rgba(245, 158, 11, 0.35);
      background: rgba(245, 158, 11, 0.08);
    }}
    .thumb-num {{
      position: absolute; top: 6px; left: 8px;
      font-size: 10px; font-weight: 800; color: var(--text-secondary);
    }}
    .thumb-title {{
      font-size: 11.5px; font-weight: 700; color: #fff;
      margin: 14px 0 4px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
    }}
    .thumb-bullets {{
      font-size: 9.5px; color: var(--text-secondary); line-height: 1.3;
      max-height: 26px; overflow: hidden;
    }}

    .canvas-stage {{
      flex: 1;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 24px;
      overflow: auto;
      background: var(--bg-page);
    }}
    .stage-nav {{
      display: flex; align-items: center; gap: 14px; margin-bottom: 16px;
    }}
    .nav-btn {{
      background: var(--bg-panel); border: 1px solid var(--border-color); color: #fff;
      padding: 6px 14px; border-radius: 8px; font-size: 12px; font-weight: 700; cursor: pointer;
    }}
    .nav-btn:hover {{ background: var(--bg-subtle); }}

    /* ─── 16:9 Slide Canvas ─── */
    .slide-canvas {{
      width: 960px;
      height: 540px;
      background: linear-gradient(135deg, #1E293B 0%, #0F172A 100%);
      border: 1px solid var(--border-color);
      border-radius: 12px;
      box-shadow: 0 16px 48px rgba(0,0,0,0.7);
      padding: 48px 60px;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      position: relative;
    }}
    .slide-canvas.title-layout {{
      justify-content: center; text-align: center;
    }}
    .canvas-title {{
      font-size: 36px; font-weight: 800; color: #FFFFFF;
      outline: none; margin-bottom: 12px; line-height: 1.25;
    }}
    .canvas-subtitle {{
      font-size: 18px; font-weight: 600; color: #F59E0B;
      outline: none; margin-bottom: 24px; line-height: 1.4;
    }}
    .canvas-bullets {{
      display: flex; flex-direction: column; gap: 12px; flex: 1;
    }}
    .bullet-row {{
      display: flex; align-items: flex-start; gap: 12px; font-size: 16px; color: #E2E8F0;
    }}
    .bullet-dot {{
      width: 8px; height: 8px; border-radius: 50%; background: #F59E0B; margin-top: 7px; flex-shrink: 0;
    }}
    .bullet-text {{
      flex: 1; outline: none; border-bottom: 1px dashed transparent;
    }}
    .bullet-text:focus {{ border-color: #F59E0B; }}

    /* ─── Speaker Notes Drawer ─── */
    .notes-drawer {{
      background: var(--bg-panel);
      border-top: 1px solid var(--border-color);
      padding: 8px 24px;
      font-size: 12px;
      display: flex;
      align-items: center;
      gap: 12px;
      flex-shrink: 0;
    }}
    .notes-input {{
      flex: 1; background: var(--bg-subtle); border: 1px solid var(--border-color);
      color: #fff; padding: 6px 12px; border-radius: 6px; font-size: 12px; outline: none;
    }}

    /* ─── Theater Fullscreen Mode ─── */
    .fullscreen-modal {{
      display: none; position: fixed; top: 0; left: 0; width: 100vw; height: 100vh;
      background: #020408; z-index: 9999; flex-direction: column; align-items: center; justify-content: center;
    }}
    .fullscreen-modal.active {{ display: flex; }}
    .fullscreen-slide {{
      width: 92vw; max-width: 1280px; height: 52vw; max-height: 720px;
      background: linear-gradient(135deg, #1E293B 0%, #0F172A 100%);
      border-radius: 16px; padding: 60px 80px; display: flex; flex-direction: column;
      justify-content: space-between; box-shadow: 0 0 60px rgba(0,0,0,0.9);
    }}
    .fs-pill {{
      position: fixed; bottom: 20px;
      background: rgba(15, 23, 42, 0.85); border: 1px solid #334155;
      padding: 6px 16px; border-radius: 20px; font-size: 12px; color: #CBD5E1;
      display: flex; align-items: center; gap: 12px;
    }}

    .toast {{
      position: fixed; bottom: 24px; right: 24px;
      background: var(--bg-panel); border: 1px solid var(--border-color);
      padding: 12px 18px; border-radius: 10px; color: #fff; font-size: 13px; font-weight: 600;
      display: flex; align-items: center; gap: 10px; transform: translateY(100px); opacity: 0;
      transition: all 0.3s ease; z-index: 1000;
    }}
    .toast.show {{ transform: translateY(0); opacity: 1; }}
  </style>
</head>
<body>

  <!-- Top Header -->
  <header class="editor-header">
    <div class="header-left">
      <div class="brand-icon">E</div>
      <div class="doc-meta">
        <div class="doc-title-row">
          <span class="doc-title">{file_name}</span>
          <span class="badge-type">{file_type}</span>
          <span class="badge-ver" id="version-badge">{version_num}</span>
        </div>
        <div class="save-status">
          <span class="status-dot" id="status-dot"></span>
          <span id="status-text">All changes saved to EduSHAMIIT</span>
        </div>
      </div>
    </div>

    <div class="header-right">
      <div class="collab-group" id="collab-avatars"></div>
      <button class="btn btn-present" onclick="startSlideshow()">📽️ Present Slideshow (F5)</button>
      {add_slide_btn_html}
      {del_slide_btn_html}
      <button class="btn btn-outline" onclick="exportPPTX()">📥 Export (.pptx)</button>
      <button class="btn btn-outline" onclick="copyCollabLink()">🔗 Share Link</button>
      {save_btn_html}
    </div>
  </header>

  <!-- Studio Body (Thumbnails + Canvas) -->
  <div class="studio-body">
    <!-- Sidebar Thumbnails -->
    <div class="slide-sidebar" id="slide-sidebar"></div>

    <!-- Center Canvas Stage -->
    <div class="canvas-stage">
      <div class="stage-nav">
        <button class="nav-btn" onclick="prevSlide()">◀ Prev Slide</button>
        <span style="font-weight: 700; font-size: 13px;" id="slide-indicator">Slide 1 of 4</span>
        <button class="nav-btn" onclick="nextSlide()">Next Slide ▶</button>
      </div>

      <div class="slide-canvas" id="slide-canvas">
        <div>
          <div class="canvas-title" id="canvas-title" {editable_attr} spellcheck="false" oninput="onSlideTitleChange(this.innerText)">Title</div>
          <div class="canvas-subtitle" id="canvas-subtitle" {editable_attr} spellcheck="false" oninput="onSlideSubtitleChange(this.innerText)">Subtitle</div>
        </div>
        <div class="canvas-bullets" id="canvas-bullets"></div>
      </div>
    </div>
  </div>

  <!-- Speaker Notes Drawer -->
  <div class="notes-drawer">
    <span style="font-weight: 700; color: var(--primary);">📝 Speaker Notes:</span>
    <input type="text" class="notes-input" id="notes-input" {notes_readonly} placeholder="Type private notes or speaking cues..." oninput="onSlideNotesChange(this.value)" />
  </div>

  <!-- Fullscreen Slideshow Theater -->
  <div class="fullscreen-modal" id="fs-modal">
    <div class="fullscreen-slide" id="fs-slide">
      <div>
        <h1 id="fs-title" style="font-size: 46px; font-weight: 800; color: #fff; margin-bottom: 14px;"></h1>
        <h3 id="fs-subtitle" style="font-size: 24px; color: #F59E0B; margin-bottom: 30px;"></h3>
      </div>
      <div id="fs-bullets" style="display: flex; flex-direction: column; gap: 18px; font-size: 22px; color: #F1F5F9;"></div>
    </div>
    <div class="fs-pill">
      <span id="fs-counter">Slide 1 / 4</span>
      <span>•</span>
      <span>[Arrow Keys] Navigate • [ESC] Exit</span>
    </div>
  </div>

  <div class="toast" id="toast">
    <span id="toast-message">Presentation saved</span>
  </div>

  <script>
    const CAN_EDIT = {"true" if can_edit else "false"};
    let slides = {initial_slides_json};
    const CURRENT_USER = {user_json};
    const DOC_INFO = {doc_json};
    const AUTH_TOKEN = "{token}";
    let activeSlideIdx = 0;
    let isDirty = false;
    let autoSaveTimer = null;
    let ws = null;

    if (!slides || !slides.length) {{
      slides = [{{ id: 1, title: 'Annual Institute Keynote', subtitle: 'EduSHAMIIT Presentation', bullets: ['Key objective', 'Summary notes'], notes: '' }}];
    }}

    function renderSidebar() {{
      const sidebar = document.getElementById('slide-sidebar');
      sidebar.innerHTML = '';
      slides.forEach((s, idx) => {{
        const card = document.createElement('div');
        card.className = `thumb-card ${{idx === activeSlideIdx ? 'active' : ''}}`;
        card.onclick = () => switchSlide(idx);
        card.innerHTML = `
          <div class="thumb-num">${{idx + 1}}</div>
          <div class="thumb-title">${{s.title || 'Untitled Slide'}}</div>
          <div class="thumb-bullets">${{(s.bullets || []).join(' • ') || s.subtitle || ''}}</div>
        `;
        sidebar.appendChild(card);
      }});
    }}

    function renderActiveSlide() {{
      const s = slides[activeSlideIdx];
      document.getElementById('slide-indicator').innerText = `Slide ${{activeSlideIdx + 1}} of ${{slides.length}}`;
      document.getElementById('canvas-title').innerText = s.title || '';
      document.getElementById('canvas-subtitle').innerText = s.subtitle || '';
      document.getElementById('notes-input').value = s.notes || '';
      if (!CAN_EDIT) {{
        document.getElementById('canvas-title').contentEditable = "false";
        document.getElementById('canvas-subtitle').contentEditable = "false";
        document.getElementById('notes-input').readOnly = true;
      }}

      const canvas = document.getElementById('slide-canvas');
      if (s.layout === 'title' || (!s.bullets || !s.bullets.length)) {{
        canvas.className = 'slide-canvas title-layout';
      }} else {{
        canvas.className = 'slide-canvas';
      }}

      const bulletsContainer = document.getElementById('canvas-bullets');
      bulletsContainer.innerHTML = '';
      (s.bullets || []).forEach((b, bIdx) => {{
        const row = document.createElement('div');
        row.className = 'bullet-row';
        const bEditable = CAN_EDIT ? `contenteditable="true" oninput="onBulletChange(${{bIdx}}, this.innerText)"` : `contenteditable="false"`;
        row.innerHTML = `
          <div class="bullet-dot"></div>
          <div class="bullet-text" ${{bEditable}}>${{b}}</div>
        `;
        bulletsContainer.appendChild(row);
      }});

      renderSidebar();
    }}

    function switchSlide(idx) {{
      if (idx >= 0 && idx < slides.length) {{
        activeSlideIdx = idx;
        renderActiveSlide();
      }}
    }}

    function prevSlide() {{ if (activeSlideIdx > 0) switchSlide(activeSlideIdx - 1); }}
    function nextSlide() {{ if (activeSlideIdx < slides.length - 1) switchSlide(activeSlideIdx + 1); }}

    function onSlideTitleChange(val) {{
      if (!CAN_EDIT) return;
      slides[activeSlideIdx].title = val;
      triggerDirty();
    }}
    function onSlideSubtitleChange(val) {{
      if (!CAN_EDIT) return;
      slides[activeSlideIdx].subtitle = val;
      triggerDirty();
    }}
    function onSlideNotesChange(val) {{
      if (!CAN_EDIT) return;
      slides[activeSlideIdx].notes = val;
      triggerDirty();
    }}
    function onBulletChange(bIdx, val) {{
      if (!CAN_EDIT) return;
      if (slides[activeSlideIdx].bullets) {{
        slides[activeSlideIdx].bullets[bIdx] = val;
        triggerDirty();
      }}
    }}

    function addSlide() {{
      if (!CAN_EDIT) return;
      const newId = slides.length + 1;
      slides.push({{
        id: newId,
        title: `Slide ${{newId}} Topic`,
        subtitle: 'Key points and milestones',
        bullets: ['First strategic priority', 'Operational milestone'],
        notes: '',
        layout: 'bullets'
      }});
      switchSlide(slides.length - 1);
      triggerDirty();
    }}

    function deleteCurrentSlide() {{
      if (!CAN_EDIT) return;
      if (slides.length <= 1) return;
      slides.splice(activeSlideIdx, 1);
      activeSlideIdx = Math.max(0, activeSlideIdx - 1);
      renderActiveSlide();
      triggerDirty();
    }}

    function triggerDirty() {{
      if (!CAN_EDIT) return;
      isDirty = true;
      document.getElementById('status-dot').className = 'status-dot dirty';
      document.getElementById('status-text').innerText = 'Unsaved changes...';
      if (autoSaveTimer) clearTimeout(autoSaveTimer);
      autoSaveTimer = setTimeout(savePresentation, 4000);
      broadcastEdit();
    }}

    async function savePresentation() {{
      if (!CAN_EDIT) return;
      if (autoSaveTimer) clearTimeout(autoSaveTimer);
      document.getElementById('status-text').innerText = 'Saving version...';
      try {{
        const res = await fetch(`/api/documents/${{DOC_INFO.id}}/collab/save`, {{
          method: 'POST',
          headers: {{ 'Content-Type': 'application/json', 'Authorization': `Bearer ${{AUTH_TOKEN}}` }},
          body: JSON.stringify({{ slides: slides }})
        }});
        const data = await res.json();
        if (data.success) {{
          isDirty = false;
          document.getElementById('status-dot').className = 'status-dot';
          document.getElementById('status-text').innerText = `Saved ${{data.version_number || ''}}`;
          if (data.version_number) document.getElementById('version-badge').innerText = data.version_number;
          showToast(`Saved version ${{data.version_number || ''}} successfully`);
        }}
      }} catch (e) {{
        document.getElementById('status-text').innerText = 'Save error';
      }}
    }}

    function showToast(msg) {{
      const t = document.getElementById('toast');
      document.getElementById('toast-message').innerText = msg;
      t.className = 'toast show';
      setTimeout(() => {{ t.className = 'toast'; }}, 3000);
    }}

    function exportPPTX() {{
      window.location.href = `/api/documents/${{DOC_INFO.id}}/download`;
    }}

    function copyCollabLink() {{
      navigator.clipboard.writeText(window.location.href).then(() => {{
        showToast('Presentation live link copied to clipboard!');
      }});
    }}

    // ─── Theater Slideshow Mode ───
    function startSlideshow() {{
      const modal = document.getElementById('fs-modal');
      modal.className = 'fullscreen-modal active';
      renderFullscreenSlide();
    }}

    function closeSlideshow() {{
      document.getElementById('fs-modal').className = 'fullscreen-modal';
    }}

    function renderFullscreenSlide() {{
      const s = slides[activeSlideIdx];
      document.getElementById('fs-counter').innerText = `Slide ${{activeSlideIdx + 1}} / ${{slides.length}}`;
      document.getElementById('fs-title').innerText = s.title || '';
      document.getElementById('fs-subtitle').innerText = s.subtitle || '';
      const bContainer = document.getElementById('fs-bullets');
      bContainer.innerHTML = '';
      (s.bullets || []).forEach(b => {{
        const div = document.createElement('div');
        div.style.display = 'flex';
        div.style.alignItems = 'center';
        div.style.gap = '14px';
        div.innerHTML = `<span style="color: #F59E0B;">•</span> <span>${{b}}</span>`;
        bContainer.appendChild(div);
      }});
    }}

    window.addEventListener('keydown', (e) => {{
      const inFs = document.getElementById('fs-modal').classList.contains('active');
      if (e.key === 'F5') {{
        e.preventDefault();
        startSlideshow();
      }} else if (inFs) {{
        if (e.key === 'Escape') closeSlideshow();
        else if (e.key === 'ArrowRight' || e.key === ' ') {{ nextSlide(); renderFullscreenSlide(); }}
        else if (e.key === 'ArrowLeft') {{ prevSlide(); renderFullscreenSlide(); }}
      }}
    }});

    let broadcastDebounceTimer = null;
    function broadcastEdit() {{
      if (!CAN_EDIT) return;
      if (broadcastDebounceTimer) clearTimeout(broadcastDebounceTimer);
      broadcastDebounceTimer = setTimeout(() => {{
        if (ws && ws.readyState === WebSocket.OPEN) {{
          ws.send(JSON.stringify({{
            type: 'presentation_edit',
            action: 'update_slide',
            slides: slides,
            active_slide: activeSlideIdx
          }}));
        }}
      }}, 40);
    }}

    let MY_CONN_ID = null;
    function initWebSocket() {{
      const proto = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
      const wsUrl = `${{proto}}//${{window.location.host}}/api/ws/documents/${{DOC_INFO.id}}?token=${{AUTH_TOKEN}}&client_id=${{encodeURIComponent(CURRENT_USER.id)}}&name=${{encodeURIComponent(CURRENT_USER.name || CURRENT_USER.full_name || 'Collaborator')}}`;
      try {{
        ws = new WebSocket(wsUrl);
        ws.onopen = () => ws.send(JSON.stringify({{ type: 'join', user: CURRENT_USER }}));
        ws.onmessage = (event) => {{
          try {{
            const msg = JSON.parse(event.data);
            if (msg.type === 'init') {{
              MY_CONN_ID = msg.my_user ? msg.my_user.conn_id : null;
              updateUsers(msg.users || []);
            }} else if (msg.type === 'user_joined' || msg.type === 'user_left') {{
              updateUsers(msg.users || []);
            }} else if (msg.type === 'presentation_updated') {{
              if (msg.conn_id !== MY_CONN_ID && msg.author_id !== CURRENT_USER.id) {{
                if (msg.slides) {{
                  slides = msg.slides;
                  renderActiveSlide();
                  if (document.getElementById('fs-modal').classList.contains('active')) {{
                    renderFullscreenSlide();
                  }}
                  const statusDot = document.getElementById('status-dot');
                  const statusText = document.getElementById('status-text');
                  statusDot.className = 'status-dot';
                  statusText.innerText = `Synced with ${{msg.author_name || 'Collaborator'}}`;
                }}
              }}
            }} else if (msg.type === 'saved') {{
              if (msg.version) {{
                document.getElementById('version-badge').innerText = `v${{msg.version}}.0`;
                document.getElementById('status-text').innerText = `Saved v${{msg.version}}.0`;
                document.getElementById('status-dot').className = 'status-dot';
              }}
            }}
          }} catch (_) {{}}
        }};
        ws.onclose = () => {{
          setTimeout(initWebSocket, 2000);
        }};
      }} catch (_) {{
        setTimeout(initWebSocket, 2000);
      }}
    }}

    function updateUsers(users) {{
      const avatars = document.getElementById('collab-avatars');
      if (!avatars) return;
      avatars.innerHTML = '';
      (users || []).slice(0, 5).forEach(u => {{
        const d = document.createElement('div');
        d.className = 'collab-avatar';
        d.style.backgroundColor = u.color || '#2563EB';
        d.title = `${{u.name}} (${{u.role}})`;
        d.innerText = (u.name || 'U').charAt(0).toUpperCase();
        avatars.appendChild(d);
      }});
      const onlineEl = document.getElementById('online-count');
      if (onlineEl) onlineEl.innerText = Math.max(1, (users || []).length);
    }}

    renderActiveSlide();
    initWebSocket();
  </script>
</body>
</html>"""


# ────────────────────────────────────────────────────────────────────────────
# 3. INTERACTIVE PDF VIEWER
# ────────────────────────────────────────────────────────────────────────────

def render_collaborative_pdf_html(
    doc: Dict[str, Any],
    initial_data: Dict[str, Any],
    current_user: Dict[str, Any],
    token: str
) -> str:
    doc_id = str(doc.get("id"))
    doc_title = doc.get("title") or doc.get("file_name") or "Document"
    file_name = doc.get("file_name") or f"{doc_title}.pdf"
    preview_url = f"/api/documents/{doc_id}/preview"

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>{doc_title} - EduSHAMIIT Document Viewer</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;600;700;800&display=swap" rel="stylesheet">
  <style>
    * {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{
      font-family: 'Plus Jakarta Sans', system-ui, sans-serif;
      background: #0B1120; color: #F8FAFC; height: 100vh; display: flex; flex-direction: column;
    }}
    .pdf-header {{
      background: #1E293B; border-bottom: 1px solid #334155; padding: 10px 20px;
      display: flex; align-items: center; justify-content: space-between;
    }}
    .pdf-frame {{ flex: 1; border: none; width: 100%; height: 100%; }}
    .btn {{
      padding: 6px 12px; border-radius: 8px; font-size: 12px; font-weight: 600;
      cursor: pointer; border: 1px solid #334155; background: transparent; color: #fff;
    }}
    .btn-primary {{ background: #2563EB; border-color: #2563EB; }}
  </style>
</head>
<body>
  <div class="pdf-header">
    <div style="display: flex; align-items: center; gap: 10px;">
      <span style="font-size: 18px;">📄</span>
      <span style="font-weight: 800; font-size: 14px;">{file_name}</span>
      <span style="background: #EF4444; color: #fff; font-size: 10px; font-weight: 800; padding: 2px 6px; border-radius: 4px;">PDF</span>
    </div>
    <div style="display: flex; gap: 8px;">
      <button class="btn btn-primary" onclick="window.open('{preview_url}', '_blank')">↗ Open Full Screen</button>
      <button class="btn" onclick="window.location.href='/api/documents/{doc_id}/download'">📥 Download</button>
    </div>
  </div>
  <iframe class="pdf-frame" src="{preview_url}"></iframe>
</body>
</html>"""


# ────────────────────────────────────────────────────────────────────────────
# 4. COLLABORATIVE SPREADSHEET EDITOR (Preserving Full Working Implementation)
# ────────────────────────────────────────────────────────────────────────────

def render_collaborative_spreadsheet_html(
    doc: Dict[str, Any],
    initial_data: Dict[str, Any],
    current_user: Dict[str, Any],
    token: str,
    can_edit: bool = True,
    access_level: str = "editor"
) -> str:
    """Render the full responsive, self-hosted web spreadsheet editor."""
    doc_id = str(doc.get("id"))
    doc_title = doc.get("title") or doc.get("file_name") or "Document"
    file_name = doc.get("file_name") or f"{doc_title}.csv"
    file_type = (doc.get("file_type") or "CSV").upper()
    version_num = f"v{doc.get('version_number') or 1}.0"

    save_btn_html = '<button class="btn btn-primary" onclick="saveDocument()">💾 Save &amp; Version</button>' if can_edit else '<span style="background: rgba(59, 130, 246, 0.15); color: #60A5FA; border: 1px solid rgba(59, 130, 246, 0.3); padding: 6px 14px; border-radius: 8px; font-size: 12px; font-weight: 700; display: inline-flex; align-items: center; gap: 6px;">👁️ View Only</span>'
    row_col_tools_html = '''
    <button class="tool-btn" onclick="addRow()">➕ Add Row</button>
    <button class="tool-btn" onclick="addCol()">➕ Add Column</button>
    <button class="tool-btn" onclick="deleteRow()">🗑️ Delete Row</button>
    <div class="tool-divider"></div>
    ''' if can_edit else ''
    formula_readonly = '' if can_edit else 'readonly'
    status_text = 'All changes saved to EduSHAMIIT' if can_edit else 'View Only Mode • Read Access'
    footer_text = 'EduSHAMIIT Unified Collaboration Engine • Autosave Active' if can_edit else 'EduSHAMIIT Unified Collaboration Engine • View Only Mode'
    
    initial_data_json = json.dumps(initial_data).replace("</script>", "<\\/script>")
    user_json = json.dumps(current_user).replace("</script>", "<\\/script>")
    doc_json = json.dumps({
        "id": doc_id,
        "title": doc_title,
        "file_name": file_name,
        "file_type": file_type,
        "version_number": version_num,
        "can_edit": can_edit,
        "access_level": access_level
    }).replace("</script>", "<\\/script>")

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>{doc_title} - EduSHAMIIT Collaborative Live Editor</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet">
  <script src="https://cdn.jsdelivr.net/npm/xlsx@0.18.5/dist/xlsx.full.min.js"></script>
  <style>
    :root {{
      --bg-page: #0B1120;
      --bg-panel: #1E293B;
      --bg-subtle: #0F172A;
      --border-color: #334155;
      --text-primary: #F8FAFC;
      --text-secondary: #94A3B8;
      --primary: #2563EB;
      --primary-hover: #1D4ED8;
      --emerald: #10B981;
      --amber: #F59E0B;
      --rose: #F43F5E;
      --cell-selected: rgba(37, 99, 235, 0.25);
      --font-main: 'Plus Jakarta Sans', system-ui, sans-serif;
      --font-mono: 'JetBrains Mono', monospace;
    }}
    * {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{
      font-family: var(--font-main);
      background-color: var(--bg-page);
      color: var(--text-primary);
      height: 100vh;
      overflow: hidden;
      display: flex;
      flex-direction: column;
    }}
    .editor-header {{
      background: var(--bg-panel);
      border-bottom: 1px solid var(--border-color);
      padding: 10px 20px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
      flex-shrink: 0;
      z-index: 100;
    }}
    .header-left {{ display: flex; align-items: center; gap: 12px; min-width: 0; }}
    .brand-icon {{
      width: 38px; height: 38px;
      background: linear-gradient(135deg, #10B981, #059669);
      border-radius: 10px;
      display: flex; align-items: center; justify-content: center;
      color: #fff; font-size: 18px; font-weight: 800;
      box-shadow: 0 4px 12px rgba(16, 185, 129, 0.35);
      flex-shrink: 0;
    }}
    .doc-meta {{ display: flex; flex-direction: column; min-width: 0; }}
    .doc-title-row {{ display: flex; align-items: center; gap: 8px; }}
    .doc-title {{
      font-size: 15px; font-weight: 800; color: #fff;
      white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 320px;
    }}
    .badge-type {{
      background: #10B981; color: #fff; font-size: 10px; font-weight: 800;
      padding: 2px 7px; border-radius: 4px; letter-spacing: 0.5px;
    }}
    .badge-ver {{
      background: rgba(37, 99, 235, 0.2); border: 1px solid rgba(37, 99, 235, 0.4);
      color: #93C5FD; font-size: 10px; font-weight: 700; padding: 2px 6px; border-radius: 4px;
    }}
    .save-status {{ display: flex; align-items: center; gap: 6px; font-size: 11px; color: var(--text-secondary); margin-top: 2px; }}
    .status-dot {{ width: 7px; height: 7px; border-radius: 50%; background: var(--emerald); }}
    .status-dot.dirty {{ background: var(--amber); }}
    .header-right {{ display: flex; align-items: center; gap: 12px; flex-shrink: 0; }}
    .collab-group {{ display: flex; align-items: center; gap: -8px; }}
    .collab-avatar {{
      width: 32px; height: 32px; border-radius: 50%;
      display: flex; align-items: center; justify-content: center;
      font-weight: 700; font-size: 12px; color: #fff;
      border: 2px solid var(--bg-panel);
    }}
    .online-counter {{
      background: rgba(37, 99, 235, 0.2); border: 1px solid rgba(37, 99, 235, 0.4);
      color: #93C5FD; font-size: 11px; font-weight: 600; padding: 4px 10px; border-radius: 20px;
      display: flex; align-items: center; gap: 5px;
    }}
    .btn {{
      font-family: var(--font-main); font-size: 12.5px; font-weight: 600;
      padding: 7px 14px; border-radius: 8px; border: 1px solid transparent;
      cursor: pointer; display: inline-flex; align-items: center; gap: 6px;
      transition: all 0.2s ease;
    }}
    .btn-primary {{ background: var(--primary); color: #fff; }}
    .btn-primary:hover {{ background: var(--primary-hover); }}
    .btn-outline {{ background: transparent; border-color: var(--border-color); color: var(--text-primary); }}
    .btn-outline:hover {{ background: rgba(255, 255, 255, 0.05); border-color: #64748B; }}

    .editor-toolbar {{
      background: var(--bg-subtle); border-bottom: 1px solid var(--border-color);
      padding: 6px 20px; display: flex; align-items: center; gap: 12px;
      overflow-x: auto; flex-shrink: 0;
    }}
    .tool-btn {{
      background: transparent; border: 1px solid transparent; color: var(--text-secondary);
      padding: 5px 9px; border-radius: 6px; font-size: 12px; font-weight: 600;
      cursor: pointer; display: flex; align-items: center; gap: 5px;
    }}
    .tool-btn:hover {{ background: rgba(255, 255, 255, 0.08); color: var(--text-primary); }}
    .tool-divider {{ width: 1px; height: 20px; background: var(--border-color); }}

    .formula-bar {{
      background: var(--bg-panel); border-bottom: 1px solid var(--border-color);
      padding: 6px 20px; display: flex; align-items: center; gap: 10px; flex-shrink: 0;
    }}
    .cell-ref {{
      width: 60px; padding: 4px 8px; background: var(--bg-subtle);
      border: 1px solid var(--border-color); border-radius: 6px;
      font-family: var(--font-mono); font-size: 12px; font-weight: 700;
      color: var(--text-primary); text-align: center;
    }}
    .fx-symbol {{ font-family: var(--font-mono); font-size: 14px; font-weight: 700; color: var(--primary); }}
    .formula-input {{
      flex: 1; padding: 5px 12px; background: var(--bg-subtle);
      border: 1px solid var(--border-color); border-radius: 6px;
      font-family: var(--font-mono); font-size: 13px; color: var(--text-primary); outline: none;
    }}

    .grid-container {{ flex: 1; overflow: auto; position: relative; background: var(--bg-page); }}
    .sheet-table {{
      border-collapse: separate; border-spacing: 0; table-layout: fixed;
      font-size: 12.5px; width: max-content;
    }}
    .sheet-table th, .sheet-table td {{
      border-right: 1px solid var(--border-color); border-bottom: 1px solid var(--border-color);
      padding: 6px 10px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
    }}
    .sheet-table thead th {{
      background: var(--bg-panel); color: var(--text-secondary); font-weight: 700;
      text-align: center; position: sticky; top: 0; z-index: 20; min-width: 110px;
    }}
    .sheet-table thead th:first-child {{ min-width: 50px; width: 50px; left: 0; z-index: 30; background: #111827; }}
    .sheet-table tbody th {{
      background: var(--bg-panel); color: var(--text-secondary); font-weight: 600;
      text-align: center; position: sticky; left: 0; z-index: 10; min-width: 50px; width: 50px;
    }}
    .sheet-table td {{
      background: var(--bg-page); color: var(--text-primary); outline: none;
      min-width: 110px; height: 32px; position: relative;
    }}
    .sheet-table td:focus {{
      background: var(--cell-selected); box-shadow: inset 0 0 0 2px var(--primary); z-index: 5;
    }}
    .collab-cursor {{
      position: absolute; top: 0; left: 0; right: 0; bottom: 0;
      pointer-events: none; border: 2px solid; z-index: 8;
    }}
    .collab-tag {{
      position: absolute; top: -20px; left: -2px; font-size: 10px; font-weight: 700;
      color: #fff; padding: 1px 6px; border-radius: 4px 4px 0 0; white-space: nowrap; pointer-events: none;
    }}

    .editor-footer {{
      background: var(--bg-panel); border-top: 1px solid var(--border-color);
      padding: 6px 20px; display: flex; align-items: center; justify-content: space-between; flex-shrink: 0;
    }}
    .sheet-tabs {{ display: flex; align-items: center; gap: 4px; }}
    .sheet-tab {{
      padding: 5px 14px; background: var(--bg-subtle); border: 1px solid var(--border-color);
      border-radius: 6px; font-size: 11.5px; font-weight: 600; color: var(--text-secondary); cursor: pointer;
    }}
    .sheet-tab.active {{ background: var(--primary); color: #fff; border-color: var(--primary); }}

    .toast {{
      position: fixed; bottom: 24px; right: 24px; background: var(--bg-panel);
      border: 1px solid var(--border-color); padding: 12px 18px; border-radius: 10px;
      color: var(--text-primary); font-size: 13px; font-weight: 600; box-shadow: 0 10px 25px rgba(0,0,0,0.5);
      display: flex; align-items: center; gap: 10px; transform: translateY(100px); opacity: 0;
      transition: all 0.3s ease; z-index: 1000;
    }}
    .toast.show {{ transform: translateY(0); opacity: 1; }}
  </style>
</head>
<body>

  <!-- Top Header -->
  <header class="editor-header">
    <div class="header-left">
      <div class="brand-icon">E</div>
      <div class="doc-meta">
        <div class="doc-title-row">
          <span class="doc-title" id="doc-title">{file_name}</span>
          <span class="badge-type">{file_type}</span>
          <span class="badge-ver" id="version-badge">{version_num}</span>
        </div>
        <div class="save-status">
          <span class="status-dot" id="status-dot"></span>
          <span id="status-text">{status_text}</span>
        </div>
      </div>
    </div>

    <div class="header-right">
      <div class="collab-group" id="collab-avatars"></div>
      <div class="online-counter" id="online-counter">
        <span>🟢</span> <span id="online-count">1</span> Editing Live
      </div>
      <button class="btn btn-outline" onclick="copyCollabLink()">🔗 Share Link</button>
      {save_btn_html}
    </div>
  </header>

  <!-- Toolbar -->
  <div class="editor-toolbar">
    {row_col_tools_html}
    <button class="tool-btn" onclick="exportXLSX()">📥 Export Excel (.xlsx)</button>
    <button class="tool-btn" onclick="exportCSV()">📥 Export CSV</button>
    <div class="tool-divider"></div>
    <span style="font-size: 11.5px; color: var(--text-secondary); margin-left: auto;">
      Institute Multi-User Real-Time Sync Enabled • Autosaves Every 4s
    </span>
  </div>

  <!-- Formula Bar -->
  <div class="formula-bar">
    <div class="cell-ref" id="active-cell-ref">A1</div>
    <div class="fx-symbol">ƒx</div>
    <input type="text" class="formula-input" id="formula-input" {formula_readonly} placeholder="Type text or formula (e.g. =SUM(A1:A5), =AVERAGE(B1:B10))" />
  </div>

  <!-- Grid View -->
  <div class="grid-container" id="grid-container">
    <table class="sheet-table" id="sheet-table">
      <thead id="sheet-head"></thead>
      <tbody id="sheet-body"></tbody>
    </table>
  </div>

  <!-- Footer Sheet Tabs -->
  <footer class="editor-footer">
    <div class="sheet-tabs" id="sheet-tabs">
      <div class="sheet-tab active">Sheet 1</div>
    </div>
    <div style="font-size: 11.5px; color: var(--text-secondary);">
      {footer_text}
    </div>
  </footer>

  <div class="toast" id="toast">
    <span id="toast-icon">✓</span>
    <span id="toast-message">Notification</span>
  </div>

  <script>
    const CAN_EDIT = {"true" if can_edit else "false"};
    const INITIAL_DATA = {initial_data_json};
    const CURRENT_USER = {user_json};
    const DOC_INFO = {doc_json};
    const AUTH_TOKEN = "{token}";

    let activeSheetIdx = 0;
    let selectedRow = 0;
    let selectedCol = 0;
    let currentData = INITIAL_DATA.sheets || [{{ name: "Sheet1", data: [[""]] }}];
    let isDirty = false;
    let autoSaveTimer = null;
    let ws = null;
    let activeCollaborators = [];

    function colToLetter(col) {{
      let temp, letter = '';
      while (col >= 0) {{
        temp = col % 26;
        letter = String.fromCharCode(temp + 65) + letter;
        col = Math.floor(col / 26) - 1;
      }}
      return letter;
    }}

    function letterToCol(letter) {{
      let col = 0;
      for (let i = 0; i < letter.length; i++) {{
        col = col * 26 + (letter.charCodeAt(i) - 64);
      }}
      return col - 1;
    }}

    function evaluateFormula(val, grid) {{
      if (typeof val !== 'string' || !val.startsWith('=')) return val;
      const expr = val.substring(1).trim().toUpperCase();
      try {{
        const sumMatch = expr.match(/^SUM\\(([A-Z]+)(\\d+):([A-Z]+)(\\d+)\\)$/);
        if (sumMatch) {{
          const c1 = letterToCol(sumMatch[1]);
          const r1 = parseInt(sumMatch[2], 10) - 1;
          const c2 = letterToCol(sumMatch[3]);
          const r2 = parseInt(sumMatch[4], 10) - 1;
          let sum = 0;
          for (let r = Math.min(r1, r2); r <= Math.max(r1, r2); r++) {{
            for (let c = Math.min(c1, c2); c <= Math.max(c1, c2); c++) {{
              if (grid[r] && grid[r][c]) {{
                const num = parseFloat(grid[r][c]);
                if (!isNaN(num)) sum += num;
              }}
            }}
          }}
          return sum;
        }}
        const avgMatch = expr.match(/^AVERAGE\\(([A-Z]+)(\\d+):([A-Z]+)(\\d+)\\)$/);
        if (avgMatch) {{
          const c1 = letterToCol(avgMatch[1]);
          const r1 = parseInt(avgMatch[2], 10) - 1;
          const c2 = letterToCol(avgMatch[3]);
          const r2 = parseInt(avgMatch[4], 10) - 1;
          let sum = 0, count = 0;
          for (let r = Math.min(r1, r2); r <= Math.max(r1, r2); r++) {{
            for (let c = Math.min(c1, c2); c <= Math.max(c1, c2); c++) {{
              if (grid[r] && grid[r][c]) {{
                const num = parseFloat(grid[r][c]);
                if (!isNaN(num)) {{ sum += num; count++; }}
              }}
            }}
          }}
          return count > 0 ? (sum / count).toFixed(2) : 0;
        }}
        const cellRefRegex = /[A-Z]+\\d+/g;
        const resolvedExpr = expr.replace(cellRefRegex, (match) => {{
          const colLetters = match.match(/[A-Z]+/)[0];
          const rowNum = parseInt(match.match(/\\d+/)[0], 10) - 1;
          const c = letterToCol(colLetters);
          if (grid[rowNum] && grid[rowNum][c]) {{
            const n = parseFloat(grid[rowNum][c]);
            return isNaN(n) ? 0 : n;
          }}
          return 0;
        }});
        if (/^[0-9+\\-*/().\\s]+$/.test(resolvedExpr)) {{
          return Function(`"use strict"; return (${{resolvedExpr}})`)();
        }}
      }} catch (err) {{
        return "#ERROR!";
      }}
      return val;
    }}

    function renderGrid() {{
      const sheet = currentData[activeSheetIdx] || {{ data: [[""]] }};
      const grid = sheet.data || [[""]];
      const maxCols = Math.max(grid[0]?.length || 1, 8);
      const rowsCount = grid.length;

      const thead = document.getElementById('sheet-head');
      let headHtml = '<tr><th>#</th>';
      for (let c = 0; c < maxCols; c++) {{
        headHtml += `<th>${{colToLetter(c)}}</th>`;
      }}
      headHtml += '</tr>';
      thead.innerHTML = headHtml;

      const tbody = document.getElementById('sheet-body');
      let bodyHtml = '';
      const cellEditable = CAN_EDIT ? 'contenteditable="true"' : 'contenteditable="false"';
      for (let r = 0; r < rowsCount; r++) {{
        bodyHtml += `<tr><th>${{r + 1}}</th>`;
        for (let c = 0; c < maxCols; c++) {{
          const rawVal = (grid[r] && grid[r][c] !== undefined) ? grid[r][c] : '';
          const displayVal = evaluateFormula(rawVal, grid);
          bodyHtml += `<td ${{cellEditable}} data-row="${{r}}" data-col="${{c}}" data-raw="${{escapeHtml(rawVal)}}">${{escapeHtml(String(displayVal))}}</td>`;
        }}
        bodyHtml += '</tr>';
      }}
      tbody.innerHTML = bodyHtml;
      attachCellEvents();
      renderTabs();
    }}

    function escapeHtml(str) {{
      return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }}

    function renderTabs() {{
      const container = document.getElementById('sheet-tabs');
      container.innerHTML = '';
      currentData.forEach((s, idx) => {{
        const btn = document.createElement('div');
        btn.className = `sheet-tab ${{idx === activeSheetIdx ? 'active' : ''}}`;
        btn.innerText = s.name || `Sheet${{idx+1}}`;
        btn.onclick = () => {{ activeSheetIdx = idx; renderGrid(); }};
        container.appendChild(btn);
      }});
    }}

    function attachCellEvents() {{
      const cells = document.querySelectorAll('.sheet-table td');
      cells.forEach(td => {{
        td.addEventListener('focus', () => {{
          selectedRow = parseInt(td.getAttribute('data-row'), 10);
          selectedCol = parseInt(td.getAttribute('data-col'), 10);
          const rawVal = td.getAttribute('data-raw') || td.innerText;
          document.getElementById('active-cell-ref').innerText = `${{colToLetter(selectedCol)}}${{selectedRow + 1}}`;
          const fInput = document.getElementById('formula-input');
          fInput.value = rawVal;
          if (CAN_EDIT && rawVal.startsWith('=')) td.innerText = rawVal;
          broadcastCursor(selectedRow, selectedCol);
        }});

        if (CAN_EDIT) {{
          td.addEventListener('blur', () => {{
            const newVal = td.innerText;
            td.setAttribute('data-raw', newVal);
            updateCellValue(selectedRow, selectedCol, newVal);
          }});

          td.addEventListener('keydown', (e) => {{
            if (e.key === 'Enter') {{
              e.preventDefault();
              td.blur();
              const nextRow = document.querySelector(`td[data-row="${{selectedRow + 1}}"][data-col="${{selectedCol}}"]`);
              if (nextRow) nextRow.focus();
            }} else if (e.key === 'Tab') {{
              e.preventDefault();
              td.blur();
              const nextCol = document.querySelector(`td[data-row="${{selectedRow}}"][data-col="${{selectedCol + 1}}"]`);
              if (nextCol) nextCol.focus();
            }}
          }});
        }}
      }});
    }}

    if (CAN_EDIT) {{
      document.getElementById('formula-input').addEventListener('input', (e) => {{
        const val = e.target.value;
        const td = document.querySelector(`td[data-row="${{selectedRow}}"][data-col="${{selectedCol}}"]`);
        if (td) {{
          td.innerText = val;
          td.setAttribute('data-raw', val);
          updateCellValue(selectedRow, selectedCol, val);
        }}
      }});
    }}

    function updateCellValue(r, c, val) {{
      if (!CAN_EDIT) return;
      const grid = currentData[activeSheetIdx].data;
      while (grid.length <= r) grid.push([]);
      while (grid[r].length <= c) grid[r].push('');
      if (grid[r][c] === val) return;
      grid[r][c] = val;
      triggerDirty();

      if (ws && ws.readyState === WebSocket.OPEN) {{
        ws.send(JSON.stringify({{
          type: "cell_edit", sheet: activeSheetIdx, row: r, col: c, value: val
        }}));
      }} else {{
        fetch(`/api/documents/${{DOC_INFO.id}}/collab/edit`, {{
          method: 'POST',
          headers: {{ 'Content-Type': 'application/json', 'Authorization': `Bearer ${{AUTH_TOKEN}}` }},
          body: JSON.stringify({{ sheet: activeSheetIdx, row: r, col: c, value: val }})
        }}).catch(() => {{}});
      }}
    }}

    function triggerDirty() {{
      if (!CAN_EDIT) return;
      isDirty = true;
      document.getElementById('status-dot').className = 'status-dot dirty';
      document.getElementById('status-text').innerText = 'Unsaved changes...';
      if (autoSaveTimer) clearTimeout(autoSaveTimer);
      autoSaveTimer = setTimeout(saveDocument, 4000);
    }}

    async function saveDocument() {{
      if (!CAN_EDIT) return;
      if (autoSaveTimer) clearTimeout(autoSaveTimer);
      document.getElementById('status-text').innerText = 'Saving version...';
      try {{
        const res = await fetch(`/api/documents/${{DOC_INFO.id}}/collab/save`, {{
          method: 'POST',
          headers: {{ 'Content-Type': 'application/json', 'Authorization': `Bearer ${{AUTH_TOKEN}}` }},
          body: JSON.stringify({{ sheets: currentData }})
        }});
        const data = await res.json();
        if (data.success) {{
          isDirty = false;
          document.getElementById('status-dot').className = 'status-dot';
          document.getElementById('status-text').innerText = `Saved ${{data.version_number || ''}}`;
          if (data.version_number) document.getElementById('version-badge').innerText = data.version_number;
          showToast(`Saved version ${{data.version_number || ''}} successfully`);
        }}
      }} catch (e) {{
        document.getElementById('status-text').innerText = 'Save error';
      }}
    }}

    function addRow() {{
      if (!CAN_EDIT) return;
      const grid = currentData[activeSheetIdx].data;
      const cols = grid[0]?.length || 8;
      grid.push(new Array(cols).fill(''));
      renderGrid();
      triggerDirty();
    }}

    function addCol() {{
      if (!CAN_EDIT) return;
      const grid = currentData[activeSheetIdx].data;
      grid.forEach(row => row.push(''));
      renderGrid();
      triggerDirty();
    }}

    function deleteRow() {{
      if (!CAN_EDIT) return;
      const grid = currentData[activeSheetIdx].data;
      if (grid.length > 1) {{
        grid.splice(selectedRow, 1);
        selectedRow = Math.max(0, selectedRow - 1);
        renderGrid();
        triggerDirty();
      }}
    }}

    function exportXLSX() {{
      const wb = XLSX.utils.book_new();
      currentData.forEach(sheet => {{
        const ws = XLSX.utils.aoa_to_sheet(sheet.data);
        XLSX.utils.book_append_sheet(wb, ws, sheet.name || 'Sheet1');
      }});
      XLSX.writeFile(wb, `${{DOC_INFO.title || 'document'}}.xlsx`);
    }}

    function exportCSV() {{
      const grid = currentData[activeSheetIdx].data;
      const csv = grid.map(r => r.map(c => `"${{String(c).replace(/"/g, '""')}}"`).join(',')).join('\\n');
      const blob = new Blob([csv], {{ type: 'text/csv;charset=utf-8;' }});
      const link = document.createElement('a');
      link.href = URL.createObjectURL(blob);
      link.download = `${{DOC_INFO.title || 'document'}}.csv`;
      link.click();
    }}

    function copyCollabLink() {{
      navigator.clipboard.writeText(window.location.href).then(() => {{
        showToast('Collaborative live link copied to clipboard!');
      }});
    }}

    function showToast(msg) {{
      const t = document.getElementById('toast');
      document.getElementById('toast-message').innerText = msg;
      t.className = 'toast show';
      setTimeout(() => {{ t.className = 'toast'; }}, 3000);
    }}

    function broadcastCursor(r, c) {{
      if (ws && ws.readyState === WebSocket.OPEN) {{
        ws.send(JSON.stringify({{ type: "cursor_move", row: r, col: c, sheet: activeSheetIdx }}));
      }}
    }}

    let MY_CONN_ID = null;
    function initWebSocket() {{
      const proto = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
      const wsUrl = `${{proto}}//${{window.location.host}}/api/ws/documents/${{DOC_INFO.id}}?token=${{AUTH_TOKEN}}&client_id=${{encodeURIComponent(CURRENT_USER.id)}}&name=${{encodeURIComponent(CURRENT_USER.name || CURRENT_USER.full_name || 'Collaborator')}}`;
      try {{
        ws = new WebSocket(wsUrl);
        ws.onopen = () => ws.send(JSON.stringify({{ type: 'join', user: CURRENT_USER }}));
        ws.onmessage = (event) => {{
          try {{
            const msg = JSON.parse(event.data);
            if (msg.type === 'init') {{
              MY_CONN_ID = msg.my_user ? msg.my_user.conn_id : null;
              updateUsers(msg.users || []);
            }} else if (msg.type === 'user_joined' || msg.type === 'user_left') {{
              updateUsers(msg.users || []);
            }} else if (msg.type === 'cell_updated' && msg.author_id !== CURRENT_USER.id) {{
              if (currentData[msg.sheet]) {{
                currentData[msg.sheet].data[msg.row][msg.col] = msg.value;
                const td = document.querySelector(`td[data-row="${{msg.row}}"][data-col="${{msg.col}}"]`);
                if (td) {{
                  td.innerText = evaluateFormula(msg.value, currentData[msg.sheet].data);
                  td.setAttribute('data-raw', msg.value);
                }}
              }}
            }} else if (msg.type === 'saved') {{
              if (msg.version) {{
                document.getElementById('version-badge').innerText = `v${{msg.version}}.0`;
                document.getElementById('status-text').innerText = `Saved v${{msg.version}}.0`;
                document.getElementById('status-dot').className = 'status-dot';
              }}
            }}
          }} catch (_) {{}}
        }};
        ws.onclose = () => {{
          setTimeout(initWebSocket, 2000);
        }};
      }} catch (_) {{
        setTimeout(initWebSocket, 2000);
      }}
    }}

    function updateUsers(users) {{
      const avatars = document.getElementById('collab-avatars');
      if (!avatars) return;
      avatars.innerHTML = '';
      (users || []).slice(0, 5).forEach(u => {{
        const d = document.createElement('div');
        d.className = 'collab-avatar';
        d.style.backgroundColor = u.color || '#2563EB';
        d.title = `${{u.name}} (${{u.role}})`;
        d.innerText = (u.name || 'U').charAt(0).toUpperCase();
        avatars.appendChild(d);
      }});
      const onlineEl = document.getElementById('online-count');
      if (onlineEl) onlineEl.innerText = Math.max(1, (users || []).length);
    }}

    renderGrid();
    initWebSocket();
  </script>
</body>
</html>"""
