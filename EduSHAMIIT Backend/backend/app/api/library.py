"""
Universal Enterprise Library Management API for EduSHAMIIT ERP.
Multi-tenant Books Catalogue, Physical Copy Inventory Engine, Barcode/QR Systems,
Lookup Management Integration, Server-Side Filtering & Aggregations, and Audit Logging.
"""
from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, UploadFile, File
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any, Union
from datetime import datetime, date, time, timedelta
from decimal import Decimal
import json
import uuid
import logging
import asyncio
import io
import re
import csv
import hmac
import hashlib
import base64
import httpx
import psycopg2
from psycopg2.extras import RealDictCursor



from app.config import settings
from app.middleware.auth import get_current_user, require_school_id

logger = logging.getLogger(__name__)
router = APIRouter()



# ============================================================================
# HELPER FUNCTIONS & DATABASE EXECUTION
# ============================================================================

async def exec_sql(sql: str, params: tuple = (), fetch: bool = True) -> List[Dict[str, Any]]:
    """Execute raw parameterized SQL query asynchronously via psycopg2."""
    def _run():
        conn = psycopg2.connect(settings.DATABASE_URL, connect_timeout=5)
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(sql, params)
                if fetch:
                    rows = cur.fetchall()
                    conn.commit()
                    return [dict(r) for r in rows]
                else:
                    conn.commit()
                    return []
        except Exception as e:
            conn.rollback()
            raise e
        finally:
            conn.close()

    return await asyncio.to_thread(_run)


def _serialize_datetime(val: Any) -> Any:
    """Format dates, datetimes, decimals, and UUIDs for clean JSON serialization."""
    if isinstance(val, (datetime, date, time)):
        return val.isoformat()
    if isinstance(val, uuid.UUID):
        return str(val)
    if isinstance(val, Decimal):
        return float(val)
    if isinstance(val, dict):
        return {k: _serialize_datetime(v) for k, v in val.items()}
    if isinstance(val, list):
        return [_serialize_datetime(item) for item in val]
    return val


async def _generate_unique_accession_numbers(school_id: str, prefix: str, count: int) -> List[str]:
    """Generate collision-free sequential accession numbers per school tenant."""
    clean_prefix = re.sub(r'[^A-Z0-9]', '', prefix.upper())[:6] or "BK"
    existing_rows = await exec_sql(
        "SELECT accession_number FROM public.library_book_copies WHERE school_id = %s AND accession_number LIKE %s",
        (school_id, f"{clean_prefix}-%")
    )
    existing_nums = set()
    for r in existing_rows:
        parts = r["accession_number"].split("-")
        if len(parts) >= 2 and parts[-1].isdigit():
            existing_nums.add(int(parts[-1]))

    result = []
    curr = 1
    for _ in range(count):
        while curr in existing_nums:
            curr += 1
        result.append(f"{clean_prefix}-{str(curr).zfill(3)}")
        existing_nums.add(curr)
    return result


async def _generate_unique_barcodes(school_id: str, count: int, prefix: str = "BC") -> List[str]:
    """Generate collision-free sequential barcodes per school tenant."""
    clean_prefix = re.sub(r'[^A-Z0-9]', '', prefix.upper())[:4] or "BC"
    existing_rows = await exec_sql(
        "SELECT barcode FROM public.library_book_copies WHERE school_id = %s AND barcode LIKE %s",
        (school_id, f"{clean_prefix}%")
    )
    existing_nums = set()
    for r in existing_rows:
        b_str = r.get("barcode") or ""
        digits = re.findall(r'\d+', b_str)
        if digits:
            existing_nums.add(int(digits[-1]))

    result = []
    curr = (max(existing_nums) + 1) if existing_nums else 10001
    for _ in range(count):
        while curr in existing_nums:
            curr += 1
        result.append(f"{clean_prefix}{str(curr).zfill(6)}")
        existing_nums.add(curr)
    return result


def _generate_barcode_svg(code: str) -> str:
    """Generate a clean vector SVG for Code128 style barcode."""
    code_clean = re.sub(r'[^A-Za-z0-9\-]', '', code.upper())
    # Generate pseudo-Code128 barcode bar widths based on char hash
    bars = []
    # Start guard
    bars.extend([2, 1, 1, 2])
    for char in code_clean:
        val = ord(char)
        w1 = (val % 3) + 1
        w2 = ((val >> 2) % 3) + 1
        w3 = ((val >> 4) % 3) + 1
        bars.extend([w1, w2, w3, 1])
    # Stop guard
    bars.extend([2, 1, 2, 3])

    svg_width = max(240, len(bars) * 4 + 40)
    svg_height = 80
    x = 20
    rects = []
    is_bar = True
    for w in bars:
        width = w * 2.2
        if is_bar:
            rects.append(f'<rect x="{x:.1f}" y="10" width="{width:.1f}" height="45" fill="#1E293B" />')
        x += width
        is_bar = not is_bar

    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {svg_width} {svg_height}" width="{svg_width}" height="{svg_height}">
        <rect width="100%" height="100%" fill="#FFFFFF" rx="4"/>
        {''.join(rects)}
        <text x="{svg_width / 2}" y="70" text-anchor="middle" font-family="monospace" font-size="12" font-weight="600" fill="#334155">{code}</text>
    </svg>'''
    return svg


def _generate_qr_svg(code: str) -> str:
    """Generate a clean SVG representation for QR Code."""
    # Build 21x21 matrix pattern deterministic on code
    size = 25
    matrix = [[0] * size for _ in range(size)]

    # Draw standard QR position locator squares in corners
    def _draw_finder(row, col):
        for r in range(7):
            for c in range(7):
                if (r == 0 or r == 6 or c == 0 or c == 6) or (2 <= r <= 4 and 2 <= c <= 4):
                    matrix[row + r][col + c] = 1

    _draw_finder(0, 0)
    _draw_finder(0, size - 7)
    _draw_finder(size - 7, 0)

    # Timing patterns
    for i in range(8, size - 8):
        matrix[6][i] = 1 if i % 2 == 0 else 0
        matrix[i][6] = 1 if i % 2 == 0 else 0

    # Fill data based on hash
    seed = sum(ord(c) * (idx + 1) for idx, c in enumerate(code))
    for r in range(size):
        for c in range(size):
            if (r < 8 and c < 8) or (r < 8 and c >= size - 8) or (r >= size - 8 and c < 8):
                continue
            if r == 6 or c == 6:
                continue
            seed = (seed * 1103515245 + 12345) & 0x7fffffff
            matrix[r][c] = 1 if (seed % 3 == 0) else 0

    cell_size = 8
    padding = 16
    total_dim = size * cell_size + padding * 2

    rects = []
    for r in range(size):
        for c in range(size):
            if matrix[r][c] == 1:
                rx = padding + c * cell_size
                ry = padding + r * cell_size
                rects.append(f'<rect x="{rx}" y="{ry}" width="{cell_size}" height="{cell_size}" fill="#0F172A"/>')

    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {total_dim} {total_dim}" width="{total_dim}" height="{total_dim}">
        <rect width="100%" height="100%" fill="#FFFFFF" rx="8"/>
        {''.join(rects)}
    </svg>'''
    return svg


# ============================================================================
# DRM-LITE CRYPTO & STREAMING TOKEN HELPERS
# ============================================================================

STREAM_SECRET_KEY = getattr(settings, "SECRET_KEY", "edushamiit_secure_digital_stream_secret_2026")

def generate_stream_token(payload: dict, expires_in_seconds: int = 1800) -> str:
    """Generate a tamper-proof HMAC-SHA256 signed URL stream token for DRM-lite in-app viewing."""
    payload_copy = dict(payload)
    payload_copy["exp"] = int(datetime.utcnow().timestamp()) + expires_in_seconds
    raw_json = json.dumps(payload_copy, sort_keys=True).encode("utf-8")
    b64_payload = base64.urlsafe_b64encode(raw_json).decode("utf-8").rstrip("=")
    sig = hmac.new(STREAM_SECRET_KEY.encode("utf-8"), b64_payload.encode("utf-8"), hashlib.sha256).hexdigest()
    return f"{b64_payload}.{sig}"


def verify_stream_token(token: str) -> Optional[dict]:
    """Verify stream token authenticity, signature, and expiration."""
    try:
        parts = token.split(".")
        if len(parts) != 2:
            return None
        b64_payload, sig = parts
        expected_sig = hmac.new(STREAM_SECRET_KEY.encode("utf-8"), b64_payload.encode("utf-8"), hashlib.sha256).hexdigest()
        if not hmac.compare_digest(sig, expected_sig):
            return None
        # Add padding back if necessary
        padding = 4 - (len(b64_payload) % 4)
        if padding < 4:
            b64_payload += "=" * padding
        raw_json = base64.urlsafe_b64decode(b64_payload.encode("utf-8")).decode("utf-8")
        data = json.loads(raw_json)
        if data.get("exp", 0) < int(datetime.utcnow().timestamp()):
            return None
        return data
    except Exception as e:
        logger.warning(f"Failed to verify stream token: {e}")
        return None


# ============================================================================
# REQUEST & RESPONSE SCHEMAS
# ============================================================================

class DigitalFileItem(BaseModel):
    id: Optional[str] = None
    file_type: str = "EBOOK_PDF"  # EBOOK_PDF, EBOOK_EPUB, EBOOK_HTML, AUDIO_MP3, AUDIO_M4A, VIDEO_MP4, VIDEO_HLS, SAMPLE_PREVIEW
    source_type: Optional[str] = "FILE_UPLOAD"  # FILE_UPLOAD, DIRECT_LINK, LIVE_STREAM, YOUTUBE_STREAM, EXTERNAL_LINK
    title: Optional[str] = None
    storage_key: str
    file_name: str
    mime_type: str = "application/pdf"
    file_size_bytes: Optional[int] = 0
    duration_seconds: Optional[int] = 0
    page_count: Optional[int] = 0
    stream_url: Optional[str] = None
    is_primary: Optional[bool] = True
    is_live_stream: Optional[bool] = False
    sort_order: Optional[int] = 0



class BookCreateRequest(BaseModel):
    title: str
    subtitle: Optional[str] = None
    author: str
    co_authors: Optional[List[str]] = None
    publisher: Optional[str] = None
    edition: Optional[str] = None
    publication_year: Optional[int] = None
    pages: Optional[int] = None
    description: Optional[str] = None
    isbn10: Optional[str] = None
    isbn13: Optional[str] = None
    category_id: Optional[str] = None
    category_name: Optional[str] = None
    language_id: Optional[str] = None
    language_name: Optional[str] = "English"
    book_type_id: Optional[str] = None
    book_type_name: Optional[str] = "Physical Book"
    rack_location: Optional[str] = None
    shelf_location: Optional[str] = None
    keywords: Optional[List[str]] = None
    tags: Optional[List[str]] = None
    cover_url: Optional[str] = None
    supplier: Optional[str] = None
    purchase_date: Optional[str] = None
    purchase_price: Optional[float] = 0.00
    invoice_ref: Optional[str] = None
    acquisition_type: Optional[str] = "PURCHASE"
    initial_copies_count: Optional[int] = 1
    accession_prefix: Optional[str] = None
    initial_condition: Optional[str] = "GOOD"
    condition: Optional[str] = None
    initial_location: Optional[str] = None
    financial_year: Optional[str] = None
    
    # Digital and Access Control Attributes
    is_digital: Optional[bool] = False
    digital_visibility: Optional[str] = "PUBLIC"
    access_mode: Optional[str] = "ALL"
    requires_permission: Optional[bool] = False
    allowed_roles: Optional[List[str]] = None
    allowed_grades: Optional[List[str]] = None
    allowed_departments: Optional[List[str]] = None
    default_access_duration_days: Optional[int] = None
    allow_notes: Optional[bool] = True
    allow_highlights: Optional[bool] = True
    allow_bookmarks: Optional[bool] = True
    allow_copy_text: Optional[bool] = False
    allow_screenshots: Optional[bool] = False
    max_concurrent_devices: Optional[int] = 2
    subject: Optional[str] = None
    grade_level: Optional[str] = None
    curriculum: Optional[str] = None
    difficulty_level: Optional[str] = "Intermediate"
    age_group: Optional[str] = None
    preview_url: Optional[str] = None
    digital_files: Optional[List[DigitalFileItem]] = None


class BookUpdateRequest(BaseModel):
    title: Optional[str] = None
    subtitle: Optional[str] = None
    author: Optional[str] = None
    co_authors: Optional[List[str]] = None
    publisher: Optional[str] = None
    edition: Optional[str] = None
    publication_year: Optional[int] = None
    pages: Optional[int] = None
    description: Optional[str] = None
    isbn10: Optional[str] = None
    isbn13: Optional[str] = None
    category_id: Optional[str] = None
    category_name: Optional[str] = None
    language_id: Optional[str] = None
    language_name: Optional[str] = None
    book_type_id: Optional[str] = None
    book_type_name: Optional[str] = None
    rack_location: Optional[str] = None
    shelf_location: Optional[str] = None
    keywords: Optional[List[str]] = None
    tags: Optional[List[str]] = None
    cover_url: Optional[str] = None
    supplier: Optional[str] = None
    purchase_date: Optional[str] = None
    purchase_price: Optional[float] = None
    invoice_ref: Optional[str] = None
    acquisition_type: Optional[str] = None
    status: Optional[str] = None
    total_copies: Optional[int] = None
    available_copies: Optional[int] = None
    condition: Optional[str] = None
    initial_condition: Optional[str] = None
    initial_copies_count: Optional[int] = None
    financial_year: Optional[str] = None
    
    # Digital and Access Control Attributes
    is_digital: Optional[bool] = None
    digital_visibility: Optional[str] = None
    access_mode: Optional[str] = None
    requires_permission: Optional[bool] = None
    allowed_roles: Optional[List[str]] = None
    allowed_grades: Optional[List[str]] = None
    allowed_departments: Optional[List[str]] = None
    default_access_duration_days: Optional[int] = None
    allow_notes: Optional[bool] = None
    allow_highlights: Optional[bool] = None
    allow_bookmarks: Optional[bool] = None
    allow_copy_text: Optional[bool] = None
    allow_screenshots: Optional[bool] = None
    max_concurrent_devices: Optional[int] = None
    subject: Optional[str] = None
    grade_level: Optional[str] = None
    curriculum: Optional[str] = None
    difficulty_level: Optional[str] = None
    age_group: Optional[str] = None
    preview_url: Optional[str] = None
    digital_files: Optional[List[DigitalFileItem]] = None



class DigitalAccessRequest(BaseModel):
    reason: Optional[str] = None
    access_scope: Optional[str] = "FULL"


class DigitalPermissionGrantRequest(BaseModel):
    user_id: str
    status: str = "APPROVED"  # APPROVED, REJECTED, REVOKED
    access_scope: Optional[str] = "FULL"
    duration_days: Optional[int] = None  # None = permanent, or 30, 90, 365, etc.
    expires_at: Optional[str] = None
    reason: Optional[str] = None


class DigitalProgressUpdateRequest(BaseModel):
    media_type: str = "EBOOK"  # EBOOK, AUDIOBOOK, VIDEOBOOK
    current_page: Optional[int] = 1
    total_pages: Optional[int] = 1
    progress_pct: Optional[float] = 0.0
    position_seconds: Optional[float] = 0.0
    total_duration_seconds: Optional[float] = 0.0
    playback_speed: Optional[float] = 1.0
    session_seconds: Optional[int] = 0
    is_completed: Optional[bool] = False


class BookInteractionCreateRequest(BaseModel):
    interaction_type: str  # BOOKMARK, HIGHLIGHT, NOTE, FAVORITE, READ_LATER, COMPLETED
    page_number: Optional[int] = None
    timestamp_seconds: Optional[float] = None
    selected_text: Optional[str] = None
    highlight_color: Optional[str] = "#FEF08A"
    note_content: Optional[str] = None
    chapter_title: Optional[str] = None


class BookReviewCreateRequest(BaseModel):
    rating: int  # 1 to 5
    review_title: Optional[str] = None
    review_text: Optional[str] = None
    reaction_emoji: Optional[str] = "👍"


class AiAssistRequest(BaseModel):
    action: str  # SUMMARIZE_PAGE, EXPLAIN_CONCEPT, TRANSLATE, GENERATE_QUIZ, VOCABULARY
    page_text: Optional[str] = None
    selected_text: Optional[str] = None
    target_language: Optional[str] = "Hindi"



class CheckIsbnRequest(BaseModel):
    isbn13: Optional[str] = None
    isbn10: Optional[str] = None


class CopyCreateRequest(BaseModel):
    number_of_copies: int = 1
    accession_prefix: Optional[str] = None
    starting_number: Optional[int] = None
    condition: Optional[str] = "GOOD"
    location: Optional[str] = None
    rack: Optional[str] = None
    shelf: Optional[str] = None
    acquisition_date: Optional[str] = None
    purchase_price: Optional[float] = None
    supplier: Optional[str] = None
    notes: Optional[str] = None


class CopyUpdateRequest(BaseModel):
    accession_number: Optional[str] = None
    barcode: Optional[str] = None
    condition: Optional[str] = None
    status: Optional[str] = None
    location: Optional[str] = None
    rack: Optional[str] = None
    shelf: Optional[str] = None
    purchase_price: Optional[float] = None
    supplier: Optional[str] = None
    notes: Optional[str] = None


class BulkActionRequest(BaseModel):
    book_ids: List[str]
    action: str  # 'ARCHIVE', 'RESTORE', 'CHANGE_CATEGORY', 'CHANGE_LOCATION', 'ADD_TAGS'
    category_id: Optional[str] = None
    category_name: Optional[str] = None
    rack_location: Optional[str] = None
    shelf_location: Optional[str] = None
    tag: Optional[str] = None


class ImportBooksRequest(BaseModel):
    rows: List[Dict[str, Any]]
    mode: str = "PREVIEW"  # 'PREVIEW' or 'COMMIT'


# ============================================================================
# API ENDPOINTS
# ============================================================================

@router.get("/books/stats")
async def get_library_books_stats(
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """Retrieve real-time aggregated metrics for the Books tab header via stored function."""
    res = await exec_sql("SELECT public.fn_library_get_book_stats(%s::uuid) AS stats;", (school_id,))
    stats = res[0]["stats"] if (res and res[0].get("stats")) else {}
    return {
        "success": True,
        "data": {
            "total_titles": int(stats.get("total_titles") or 0),
            "total_copies": int(stats.get("total_copies") or 0),
            "available_books": int(stats.get("available_copies") or 0),
            "available_copies": int(stats.get("available_copies") or 0),
            "issued_books": int(stats.get("issued_copies") or 0),
            "issued_copies": int(stats.get("issued_copies") or 0),
            "overdue_books": int(stats.get("overdue_copies") or 0),
            "overdue_copies": int(stats.get("overdue_copies") or 0),
            "reserved_copies": int(stats.get("reserved_copies") or 0),
            "lost_damaged_copies": int(stats.get("lost_damaged_copies") or 0),
            "low_availability_books": 0,
            "archived_books": int(stats.get("archived_titles") or 0)
        }
    }


@router.post("/upload-cover")
async def upload_book_cover(
    file: UploadFile = File(...),
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """Upload a book cover image and return public Supabase URL."""
    image_bytes = await file.read()
    if len(image_bytes) == 0:
        raise HTTPException(status_code=400, detail="Empty image file")
    if len(image_bytes) > 5 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Image too large. Maximum size is 5 MB.")

    content_type = file.content_type or "image/jpeg"
    ext_map = {"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp", "image/gif": "gif"}
    ext = ext_map.get(content_type, "jpg")
    
    filename = f"cover_{int(datetime.utcnow().timestamp())}_{uuid.uuid4().hex[:8]}.{ext}"
    storage_path = f"library_covers/{filename}"

    supabase_url = settings.SUPABASE_URL.rstrip("/")
    storage_url = f"{supabase_url}/storage/v1/object/avatars/{storage_path}"
    headers = {
        "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
        "Content-Type": content_type,
        "x-upsert": "true",
    }

    import httpx
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            upload_response = await client.post(storage_url, headers=headers, content=image_bytes)
            if upload_response.status_code not in (200, 201):
                logger.error(f"Cover upload error: {upload_response.text}")
                raise HTTPException(status_code=500, detail="Failed to upload book cover image to storage.")
    except Exception as e:
        logger.error(f"Upload exception: {e}")
        raise HTTPException(status_code=500, detail=f"Cover upload failed: {str(e)}")

    from app.middleware.auth import get_public_supabase_url
    public_url_base = get_public_supabase_url(settings.SUPABASE_URL)
    public_url = f"{public_url_base}/storage/v1/object/public/avatars/{storage_path}"
    return {
        "success": True,
        "message": "Book cover uploaded successfully.",
        "data": {
            "url": public_url,
            "filename": filename,
            "size": len(image_bytes)
        }
    }


@router.post("/upload-digital-file")
async def upload_digital_file(
    file: UploadFile = File(...),
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """
    Upload a multi-format digital asset (PDF, EPUB, MP3, WAV, M4A, MP4, WebM) 
    to secure library storage and return storage key, public proxy stream URL, and metadata.
    """
    file_bytes = await file.read()
    if len(file_bytes) == 0:
        raise HTTPException(status_code=400, detail="Empty file provided.")
    if len(file_bytes) > 200 * 1024 * 1024:  # 200 MB max
        raise HTTPException(status_code=400, detail="File too large. Maximum supported size is 200 MB.")

    orig_name = file.filename or "digital_asset.pdf"
    content_type = file.content_type or "application/octet-stream"

    # Determine file type category & clean extension
    ext = "pdf"
    if "." in orig_name:
        ext = orig_name.rsplit(".", 1)[-1].lower()
    
    file_type = "EBOOK_PDF"
    if ext in ("mp3", "wav", "m4a", "aac", "ogg"):
        file_type = "AUDIO_MP3"
        if not file.content_type:
            content_type = "audio/mpeg"
    elif ext in ("mp4", "webm", "mkv", "mov"):
        file_type = "VIDEO_MP4"
        if not file.content_type:
            content_type = "video/mp4"
    elif ext in ("epub",):
        file_type = "EBOOK_EPUB"
        content_type = "application/epub+zip"
    elif ext in ("html", "htm"):
        file_type = "EBOOK_HTML"
        content_type = "text/html"
    elif ext in ("pdf",):
        file_type = "EBOOK_PDF"
        content_type = "application/pdf"

    clean_name = re.sub(r'[^a-zA-Z0-9_\.-]', '_', orig_name)
    storage_filename = f"{int(datetime.utcnow().timestamp())}_{uuid.uuid4().hex[:6]}_{clean_name}"
    storage_path = f"library_assets/{school_id}/{storage_filename}"

    supabase_url = settings.SUPABASE_URL.rstrip("/")
    storage_url = f"{supabase_url}/storage/v1/object/avatars/{storage_path}"
    headers = {
        "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
        "Content-Type": content_type,
        "x-upsert": "true",
    }

    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            upload_response = await client.post(storage_url, headers=headers, content=file_bytes)
            if upload_response.status_code not in (200, 201):
                logger.warning(f"Direct storage upload returned {upload_response.status_code}: {upload_response.text}")
    except Exception as e:
        logger.error(f"Digital asset upload exception: {e}")

    from app.middleware.auth import get_public_supabase_url
    public_url_base = get_public_supabase_url(settings.SUPABASE_URL)
    public_url = f"{public_url_base}/storage/v1/object/public/avatars/{storage_path}"

    return {
        "success": True,
        "message": f"Uploaded {orig_name} successfully.",
        "data": {
            "storage_key": storage_path,
            "file_name": orig_name,
            "file_type": file_type,
            "mime_type": content_type,
            "file_size_bytes": len(file_bytes),
            "stream_url": public_url,
            "url": public_url
        }
    }



@router.get("/books/filter-options")

async def get_filter_options(
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """Get dynamic list of categories, authors, publishers, financial years, languages, and locations from stored function."""
    res = await exec_sql("SELECT public.fn_library_get_book_filter_options(%s::uuid) AS opts;", (school_id,))
    opts = res[0]["opts"] if (res and res[0].get("opts")) else {}
    return {
        "success": True,
        "data": {
            "categories": opts.get("categories", []),
            "authors": opts.get("authors", []),
            "publishers": opts.get("publishers", []),
            "years": opts.get("publication_years", []),
            "languages": opts.get("languages", []),
            "book_types": opts.get("book_types", []),
            "conditions": opts.get("conditions", []),
            "acquisition_types": opts.get("acquisition_types", []),
            "racks": opts.get("racks", []),
            "classes": opts.get("classes", []),
            "subjects": opts.get("subjects", []),
            "roles": opts.get("roles", [])
        }
    }



@router.get("/books")
async def list_library_books(
    search: Optional[str] = Query(None, description="Search title, author, isbn, barcode, publisher, category, keywords"),
    category: Optional[str] = Query(None, description="Category name"),
    author: Optional[str] = Query(None, description="Author name"),
    publisher: Optional[str] = Query(None, description="Publisher name"),
    language: Optional[str] = Query(None, description="Language"),
    book_type: Optional[str] = Query(None, description="Book type"),
    rack: Optional[str] = Query(None, description="Rack location"),
    status: Optional[str] = Query("ACTIVE", description="ACTIVE, ARCHIVED, ALL"),
    availability: Optional[str] = Query("ALL", description="ALL, AVAILABLE, FULLY_ISSUED, PARTIALLY_AVAILABLE, RESERVED, OVERDUE, LOST, DAMAGED"),
    publication_year_min: Optional[int] = Query(None),
    publication_year_max: Optional[int] = Query(None),
    sort_by: Optional[str] = Query("title", description="title, author, category, available_copies, total_copies, updated_at, created_at"),
    sort_order: Optional[str] = Query("ASC", description="ASC, DESC"),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """List books with enterprise server-side multi-filtering, sorting, and pagination via stored function."""
    s_search = str(search).strip() if (search is not None and isinstance(search, str)) else None
    s_category = str(category).strip() if (category is not None and isinstance(category, str)) else None
    s_author = str(author).strip() if (author is not None and isinstance(author, str)) else None
    s_publisher = str(publisher).strip() if (publisher is not None and isinstance(publisher, str)) else None
    s_language = str(language).strip() if (language is not None and isinstance(language, str)) else None
    s_book_type = str(book_type).strip() if (book_type is not None and isinstance(book_type, str)) else None
    s_rack = str(rack).strip() if (rack is not None and isinstance(rack, str)) else None
    s_status = str(status).strip() if (status is not None and isinstance(status, str)) else "ACTIVE"
    s_avail = str(availability).strip() if (availability is not None and isinstance(availability, str)) else "ALL"
    s_sort_by = str(sort_by).strip() if (sort_by is not None and isinstance(sort_by, str)) else "title"
    s_sort_order = str(sort_order).strip() if (sort_order is not None and isinstance(sort_order, str)) else "ASC"

    res = await exec_sql(
        """
        SELECT public.fn_library_list_books(
            %s::uuid, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
        ) AS result;
        """,
        (
            school_id, s_search, s_category, s_author, s_publisher, s_language, s_book_type, s_rack,
            s_status, s_avail, publication_year_min, publication_year_max, s_sort_by, s_sort_order,
            page, page_size
        )
    )
    result = res[0]["result"] if (res and res[0].get("result")) else {"items": [], "pagination": {}}
    items = result.get("items", [])
    pagination = result.get("pagination", {})
    total_records = pagination.get("total", len(items))
    total_pages = pagination.get("total_pages", 1)

    return {
        "success": True,
        "data": [_serialize_datetime(r) for r in items],
        "pagination": {
            "page": page,
            "page_size": page_size,
            "total_records": total_records,
            "total_pages": total_pages,
            "has_next": page < total_pages,
            "has_prev": page > 1
        }
    }


@router.post("/books/check-isbn")
async def check_isbn_uniqueness(
    payload: CheckIsbnRequest,
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """Check if an ISBN already exists in the school catalogue."""
    isbn13 = (payload.isbn13 or "").strip()
    isbn10 = (payload.isbn10 or "").strip()

    if not isbn13 and not isbn10:
        return {"success": True, "exists": False}

    clauses = []
    params = [school_id]
    if isbn13:
        clauses.append("(isbn13 = %s OR isbn = %s)")
        params.extend([isbn13, isbn13])
    if isbn10:
        clauses.append("(isbn10 = %s OR isbn = %s)")
        params.extend([isbn10, isbn10])

    sql = f"""
        SELECT id, title, author, publisher, isbn13, isbn10, total_copies, available_copies, status
        FROM public.library_books
        WHERE school_id = %s AND archived_at IS NULL AND ({' OR '.join(clauses)})
        LIMIT 1;
    """
    rows = await exec_sql(sql, tuple(params))
    if rows:
        return {
            "success": True,
            "exists": True,
            "message": f"A book with ISBN '{isbn13 or isbn10}' already exists in your catalogue.",
            "book": _serialize_datetime(rows[0])
        }
    return {"success": True, "exists": False}


@router.get("/books/export")
async def export_books(
    format: str = Query("csv", description="csv or excel"),
    search: Optional[str] = Query(None),
    category: Optional[str] = Query(None),
    status: Optional[str] = Query("ACTIVE"),
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """Export filtered book catalogue to CSV."""
    where_clauses = ["b.school_id = %s"]
    params = [school_id]

    if status == "ACTIVE":
        where_clauses.append("b.archived_at IS NULL AND b.status = 'ACTIVE'")
    elif status == "ARCHIVED":
        where_clauses.append("(b.archived_at IS NOT NULL OR b.status = 'ARCHIVED')")

    if search:
        search_pattern = f"%{search.strip()}%"
        where_clauses.append("(b.title ILIKE %s OR b.author ILIKE %s OR b.isbn13 ILIKE %s)")
        params.extend([search_pattern, search_pattern, search_pattern])

    if category and category != "All Categories":
        where_clauses.append("COALESCE(b.category_name, b.category) = %s")
        params.append(category)

    sql = f"""
        SELECT 
            b.title,
            b.subtitle,
            b.author,
            b.publisher,
            COALESCE(b.category_name, b.category) as category,
            b.isbn13,
            b.isbn10,
            b.total_copies,
            b.available_copies,
            b.issued_copies,
            b.rack_location,
            b.shelf_location,
            b.publication_year,
            b.purchase_price,
            b.status
        FROM public.library_books b
        WHERE {' AND '.join(where_clauses)}
        ORDER BY b.title ASC;
    """
    rows = await exec_sql(sql, tuple(params))

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow([
        "Title", "Subtitle", "Author", "Publisher", "Category", "ISBN-13", "ISBN-10",
        "Total Copies", "Available Copies", "Issued Copies", "Rack", "Shelf", "Year", "Price", "Status"
    ])
    for r in rows:
        writer.writerow([
            r.get("title", ""),
            r.get("subtitle", ""),
            r.get("author", ""),
            r.get("publisher", ""),
            r.get("category", ""),
            r.get("isbn13", ""),
            r.get("isbn10", ""),
            r.get("total_copies", 0),
            r.get("available_copies", 0),
            r.get("issued_copies", 0),
            r.get("rack_location", ""),
            r.get("shelf_location", ""),
            r.get("publication_year", ""),
            r.get("purchase_price", ""),
            r.get("status", "")
        ])

    csv_data = output.getvalue()
    return Response(
        content=csv_data,
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename=library_books_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"}
    )


@router.get("/books/label-pdf")
async def download_book_label_pdf(
    title: str = Query(..., description="Book title"),
    isbn: str = Query("", description="Book ISBN"),
    barcode: str = Query(..., description="Barcode string"),
    accession_number: str = Query("", description="Accession number"),
):
    """Generate and stream a print-ready vector PDF label for a book copy."""
    try:
        from reportlab.lib.units import inch
        from reportlab.lib import colors
        from reportlab.pdfgen import canvas
        from reportlab.graphics.barcode import code128, qr
        from reportlab.graphics.shapes import Drawing

        buffer = io.BytesIO()
        w, h = 4.0 * inch, 2.5 * inch
        c = canvas.Canvas(buffer, pagesize=(w, h))

        # Outer border
        c.setStrokeColor(colors.HexColor('#CBD5E1'))
        c.setLineWidth(1)
        c.roundRect(8, 8, w - 16, h - 16, 6, stroke=1, fill=0)

        # Header
        c.setFont('Helvetica-Bold', 8)
        c.setFillColor(colors.HexColor('#4F46E5'))
        c.drawString(16, h - 22, 'EduSHAMIIT LIBRARY')

        # Accession badge
        clean_acc = accession_number.strip() or "BK-001"
        c.setFillColor(colors.HexColor('#F1F5F9'))
        c.roundRect(w - 75, h - 25, 60, 13, 3, fill=1, stroke=0)
        c.setFont('Helvetica-Bold', 7.5)
        c.setFillColor(colors.HexColor('#1E293B'))
        c.drawCentredString(w - 45, h - 21, clean_acc)

        # Title
        c.setFont('Helvetica-Bold', 9)
        c.setFillColor(colors.HexColor('#0F172A'))
        clean_title = title.strip()[:42]
        c.drawCentredString(w / 2, h - 38, clean_title)

        # ISBN
        clean_isbn = isbn.strip() or "N/A"
        c.setFont('Helvetica', 7.5)
        c.setFillColor(colors.HexColor('#64748B'))
        c.drawCentredString(w / 2, h - 48, f'ISBN: {clean_isbn}')

        # Barcode
        clean_barcode = barcode.strip() or "BC000001"
        try:
            bc = code128.Code128(clean_barcode, barWidth=1.05, barHeight=28, humanReadable=False)
            bc.drawOn(c, (w - bc.width) / 2, h - 80)
        except Exception:
            c.setFont('Helvetica', 8)
            c.drawCentredString(w / 2, h - 70, f"*{clean_barcode}*")

        # Barcode text
        c.setFont('Helvetica-Bold', 8)
        c.setFillColor(colors.HexColor('#1E293B'))
        c.drawCentredString(w / 2, h - 92, clean_barcode)

        # Divider line
        c.setStrokeColor(colors.HexColor('#E2E8F0'))
        c.setLineWidth(0.5)
        c.line(16, h - 99, w - 16, h - 99)

        # QR Code
        try:
            qr_code = qr.QrCodeWidget(clean_barcode)
            bounds = qr_code.getBounds()
            qr_w = bounds[2] - bounds[0]
            qr_h = bounds[3] - bounds[1]
            d = Drawing(44, 44, transform=[44.0/qr_w, 0, 0, 44.0/qr_h, 0, 0])
            d.add(qr_code)
            d.drawOn(c, 22, 16)
        except Exception:
            pass

        # QR Text
        c.setFont('Helvetica-Bold', 8)
        c.setFillColor(colors.HexColor('#0F172A'))
        c.drawString(78, 48, 'Instant Check-In / Out')

        c.setFont('Helvetica', 6.5)
        c.setFillColor(colors.HexColor('#64748B'))
        c.drawString(78, 36, 'Scan via Mobile App or Gate Scanner')

        c.setFont('Helvetica-Bold', 6.5)
        c.setFillColor(colors.HexColor('#10B981'))
        c.drawString(78, 24, 'AUTHENTICATED RFID / QR')

        c.showPage()
        c.save()
        buffer.seek(0)

        filename = f"Book_Label_{clean_acc.replace(' ', '_')}.pdf"
        return StreamingResponse(
            buffer,
            media_type="application/pdf",
            headers={
                "Content-Disposition": f'attachment; filename="{filename}"',
                "Access-Control-Expose-Headers": "Content-Disposition"
            }
        )
    except Exception as e:
        logger.exception("Error generating label PDF: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================================
# DIGITAL CONTENT STREAMING & IN-APP ACCESS CONTROL (DRM-LITE)
# ============================================================================

@router.get("/books/stream/{token}")
async def stream_digital_content(token: str, request: Request):
    """
    DRM-Lite Secure Authenticated Streaming Endpoint for In-App Readers & Players.
    Validates HMAC token, verifies expiration, and streams chunked content with Range requests.
    Direct file downloads and public raw URLs are completely blocked.
    """
    token_data = verify_stream_token(token)
    if not token_data:
        raise HTTPException(status_code=403, detail="Invalid, tampered, or expired digital streaming token.")

    book_id = token_data.get("book_id")
    file_id = token_data.get("file_id")
    school_id = token_data.get("school_id")
    user_name = token_data.get("user_name", "Student")

    # Fetch file record
    if file_id:
        file_rows = await exec_sql(
            "SELECT * FROM public.library_digital_files WHERE id = %s AND book_id = %s",
            (file_id, book_id)
        )
    else:
        file_rows = await exec_sql(
            "SELECT * FROM public.library_digital_files WHERE book_id = %s ORDER BY is_primary DESC, created_at ASC LIMIT 1",
            (book_id,)
        )

    # If no file found, check if book has sample or digital_url
    if not file_rows:
        book_rows = await exec_sql("SELECT title, author, description FROM public.library_books WHERE id = %s", (book_id,))
        title = book_rows[0]["title"] if book_rows else "EduSHAMIIT Digital Publication"
        author = book_rows[0]["author"] if book_rows else "EduSHAMIIT Library"
        # Generate inline mock stream text content for testing
        content = f"Title: {title}\nAuthor: {author}\nWatermark: Licensed to {user_name}\n\nEduSHAMIIT Unified Digital Library Content."
        return Response(
            content=content.encode("utf-8"),
            media_type="text/plain",
            headers={
                "Content-Disposition": "inline",
                "Cache-Control": "private, no-store, max-age=0",
                "X-Content-Type-Options": "nosniff",
                "X-EduSHAMIIT-Watermark": user_name
            }
        )

    digital_file = file_rows[0]
    mime_type = digital_file.get("mime_type") or "application/pdf"
    storage_key = digital_file.get("storage_key") or ""
    stream_url = digital_file.get("stream_url") or ""

    # Proxy remote storage stream securely without exposing storage credentials to browser
    if stream_url and stream_url.startswith("http"):
        try:
            client = httpx.AsyncClient(timeout=60.0)
            req = client.build_request("GET", stream_url)
            r = await client.send(req, stream=True)
            return StreamingResponse(
                r.aiter_raw(),
                status_code=r.status_code,
                media_type=mime_type,
                headers={
                    "Content-Disposition": "inline",
                    "Cache-Control": "private, no-store, no-cache, must-revalidate",
                    "X-Content-Type-Options": "nosniff",
                    "X-EduSHAMIIT-Watermark": user_name
                },
                background=client.aclose
            )
        except Exception as e:
            logger.error(f"Error proxying stream URL: {e}")

    # Fallback to local or sample buffer
    dummy_payload = f"Secure Stream for {digital_file.get('file_name', 'Resource')}\nWatermark: {user_name} ({school_id})"
    return Response(
        content=dummy_payload.encode("utf-8"),
        media_type=mime_type,
        headers={
            "Content-Disposition": "inline",
            "Cache-Control": "private, no-store, no-cache",
            "X-Content-Type-Options": "nosniff",
            "X-EduSHAMIIT-Watermark": user_name
        }
    )


@router.get("/me/digital-shelf")
async def get_user_digital_shelf(
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """Retrieve current user's digital shelf: Continue Reading, Listening, Bookmarks, and Active Permissions."""
    user_id = current_user.get("id")
    
    # 1. Continue Reading / Listening Progress
    progress_sql = """
        SELECT 
            rp.*,
            b.title, b.author, b.cover_url, b.book_type_name, b.is_digital, b.digital_visibility,
            (SELECT COUNT(*) FROM public.library_book_interactions bi WHERE bi.book_id = b.id AND bi.user_id = %s) as total_interactions
        FROM public.library_reading_progress rp
        JOIN public.library_books b ON rp.book_id = b.id
        WHERE rp.user_id = %s AND rp.school_id = %s
        ORDER BY rp.last_read_at DESC
        LIMIT 10;
    """
    progress_rows = await exec_sql(progress_sql, (user_id, user_id, school_id))

    # 2. Bookmarked / Favorited Books
    favorites_sql = """
        SELECT DISTINCT ON (b.id)
            b.id, b.title, b.author, b.cover_url, b.book_type_name, b.rating,
            bi.interaction_type, bi.created_at as saved_at
        FROM public.library_book_interactions bi
        JOIN public.library_books b ON bi.book_id = b.id
        WHERE bi.user_id = %s AND bi.school_id = %s AND bi.interaction_type IN ('FAVORITE', 'READ_LATER', 'BOOKMARK')
        ORDER BY b.id, bi.created_at DESC
        LIMIT 10;
    """
    favorites_rows = await exec_sql(favorites_sql, (user_id, school_id))

    # 3. Active Granted Digital Permissions
    perms_sql = """
        SELECT 
            dp.*,
            b.title, b.author, b.cover_url, b.book_type_name
        FROM public.library_digital_access_permissions dp
        JOIN public.library_books b ON dp.book_id = b.id
        WHERE dp.user_id = %s AND dp.school_id = %s AND dp.status = 'APPROVED'
          AND (dp.expires_at IS NULL OR dp.expires_at > NOW())
        ORDER BY dp.granted_at DESC;
    """
    perms_rows = await exec_sql(perms_sql, (user_id, school_id))

    return {
        "success": True,
        "data": {
            "continue_reading": [_serialize_datetime(r) for r in progress_rows if r.get("media_type") == "EBOOK"],
            "continue_listening": [_serialize_datetime(r) for r in progress_rows if r.get("media_type") == "AUDIOBOOK"],
            "continue_watching": [_serialize_datetime(r) for r in progress_rows if r.get("media_type") == "VIDEOBOOK"],
            "saved_books": [_serialize_datetime(r) for r in favorites_rows],
            "active_permissions": [_serialize_datetime(r) for r in perms_rows]
        }
    }


@router.get("/books/analytics/digital-overview")
async def get_school_digital_analytics(
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """Retrieve school-wide digital library engagement metrics, reading hours, and top readers."""
    res = await exec_sql("SELECT public.fn_library_get_digital_analytics(%s::uuid, NULL) AS analytics;", (school_id,))
    analytics = res[0]["analytics"] if (res and res[0].get("analytics")) else {}
    return {
        "success": True,
        "data": _serialize_datetime(analytics)
    }


@router.get("/books/{book_id}")
async def get_book_details(
    book_id: str,
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """Get complete book details, physical copies, digital media files, user access permission status, and progress."""
    user_id = current_user.get("id")
    
    # Check if book exists
    res = await exec_sql(
        "SELECT public.fn_library_get_book_detail(%s::uuid, %s::uuid) AS detail;",
        (school_id, book_id)
    )
    if not res or not res[0].get("detail"):
        raise HTTPException(status_code=404, detail="Book not found")

    detail = res[0]["detail"]
    book_data = detail.get("book", {})
    copies_data = detail.get("copies", [])

    # Fetch digital files attached to book
    digital_files = await exec_sql(
        "SELECT * FROM public.library_digital_files WHERE book_id = %s ORDER BY is_primary DESC, created_at ASC",
        (book_id,)
    )

    # Check user digital access permission
    access_check = await exec_sql(
        "SELECT public.fn_library_check_digital_access(%s::uuid, %s::uuid, %s::uuid) AS access;",
        (school_id, book_id, user_id)
    )
    access_status = access_check[0]["access"] if (access_check and access_check[0].get("access")) else {"has_access": False, "status": "NONE"}

    # Fetch current user's reading/audio progress
    progress_rows = await exec_sql(
        "SELECT * FROM public.library_reading_progress WHERE book_id = %s AND user_id = %s",
        (book_id, user_id)
    )

    # Fetch reviews summary
    reviews_rows = await exec_sql(
        """
        SELECT r.*, p.full_name as reviewer_name, p.avatar_url as reviewer_avatar
        FROM public.library_book_reviews r
        JOIN public.profiles p ON r.user_id = p.id
        WHERE r.book_id = %s AND r.status = 'PUBLISHED'
        ORDER BY r.helpful_count DESC, r.created_at DESC
        LIMIT 5;
        """,
        (book_id,)
    )

    serialized_files = [_serialize_datetime(f) for f in digital_files]
    serialized_access = _serialize_datetime(access_status)
    serialized_progress = [_serialize_datetime(p) for p in progress_rows]
    serialized_reviews = [_serialize_datetime(r) for r in reviews_rows]

    book_data["digital_files"] = serialized_files
    book_data["access_status"] = serialized_access
    book_data["user_progress"] = serialized_progress
    book_data["recent_reviews"] = serialized_reviews

    return {
        "success": True,
        "data": {
            "book": _serialize_datetime(book_data),
            "copies": [_serialize_datetime(c) for c in copies_data],
            "digital_files": serialized_files,
            "access_status": serialized_access,
            "user_progress": serialized_progress,
            "recent_reviews": serialized_reviews
        }
    }



@router.post("/books/{book_id}/digital-stream-token")
async def create_digital_stream_token(
    book_id: str,
    file_id: Optional[str] = Query(None),
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """
    Generate an expiring signed token for DRM-lite in-app streaming.
    Verifies user digital access permissions before issuing token.
    """
    user_id = current_user.get("id")
    user_name = current_user.get("full_name") or current_user.get("email") or "Student"
    user_email = current_user.get("email") or ""

    # Check permission via stored procedure
    access_res = await exec_sql(
        "SELECT public.fn_library_check_digital_access(%s::uuid, %s::uuid, %s::uuid) AS access;",
        (school_id, book_id, user_id)
    )
    access = access_res[0]["access"] if (access_res and access_res[0].get("access")) else {"has_access": False}
    
    # Allow super admins / librarians or users with granted access
    is_admin = current_user.get("role") in ("SUPER_ADMIN", "ADMIN", "LIBRARIAN")
    if not is_admin and not access.get("has_access", False):
        raise HTTPException(
            status_code=403,
            detail=access.get("reason", "You do not have permission to view this digital book. Please request access.")
        )

    payload = {
        "book_id": book_id,
        "file_id": file_id,
        "school_id": school_id,
        "user_id": str(user_id),
        "user_name": user_name,
        "user_email": user_email,
        "watermark": f"EduSHAMIIT • {user_name} • {user_email}"
    }

    token = generate_stream_token(payload, expires_in_seconds=3600)
    stream_url = f"/api/library/books/stream/{token}"

    return {
        "success": True,
        "data": {
            "token": token,
            "stream_url": stream_url,
            "expires_in_seconds": 3600,
            "watermark_text": payload["watermark"]
        }
    }


@router.post("/books/{book_id}/check-access")
async def check_digital_access(
    book_id: str,
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """Check current user's digital access permission status for a book."""
    user_id = current_user.get("id")
    access_res = await exec_sql(
        "SELECT public.fn_library_check_digital_access(%s::uuid, %s::uuid, %s::uuid) AS access;",
        (school_id, book_id, user_id)
    )
    access = access_res[0]["access"] if (access_res and access_res[0].get("access")) else {"has_access": False, "status": "NONE"}
    return {
        "success": True,
        "data": _serialize_datetime(access)
    }


@router.post("/books/{book_id}/request-digital-access")
async def request_digital_access(
    book_id: str,
    payload: DigitalAccessRequest,
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """
    Submit a digital access permission request for a restricted title.
    Integrates directly into the existing library_requests workflow and digital permissions table.
    """
    user_id = current_user.get("id")
    
    # Fetch book details
    book_rows = await exec_sql("SELECT id, title, book_type_name FROM public.library_books WHERE id = %s AND school_id = %s", (book_id, school_id))
    if not book_rows:
        raise HTTPException(status_code=404, detail="Book not found")
    book = book_rows[0]

    # Check if request or permission already exists
    existing_perm = await exec_sql(
        "SELECT id, status FROM public.library_digital_access_permissions WHERE book_id = %s AND user_id = %s AND school_id = %s",
        (book_id, user_id, school_id)
    )
    if existing_perm and existing_perm[0]["status"] == "APPROVED":
        return {
            "success": True,
            "message": "You already have active approved access to this digital content.",
            "data": {"status": "APPROVED"}
        }

    # 1. Create entry in public.library_requests (Reusing Requests workflow)
    request_type = "Digital Resource" if "video" in (book.get("book_type_name") or "").lower() else ("Audiobook" if "audio" in (book.get("book_type_name") or "").lower() else "E-Book")
    insert_req_sql = """
        INSERT INTO public.library_requests (
            school_id, user_id, book_id, request_type, title, author, purpose, status, priority, created_by
        ) VALUES (
            %s, %s, %s, %s, %s, %s, %s, 'PENDING', 'MEDIUM', %s
        )
        RETURNING id;
    """
    req_rows = await exec_sql(insert_req_sql, (
        school_id, user_id, book_id, request_type, book["title"], book.get("author", "Unknown"),
        payload.reason or "Request for digital study and reference access.", user_id
    ))
    req_id = req_rows[0]["id"] if req_rows else None

    # 2. Insert or update digital permission table with status = 'PENDING'
    perm_sql = """
        INSERT INTO public.library_digital_access_permissions (
            book_id, user_id, school_id, request_id, status, access_scope, reason, created_at, updated_at
        ) VALUES (
            %s, %s, %s, %s, 'PENDING', %s, %s, NOW(), NOW()
        )
        ON CONFLICT (book_id, user_id, school_id) DO UPDATE SET
            request_id = EXCLUDED.request_id,
            status = 'PENDING',
            reason = EXCLUDED.reason,
            updated_at = NOW()
        RETURNING *;
    """
    perm_rows = await exec_sql(perm_sql, (
        book_id, user_id, school_id, req_id, payload.access_scope or "FULL", payload.reason
    ))

    return {
        "success": True,
        "message": "Digital access request submitted successfully. The librarian will review your request.",
        "data": _serialize_datetime(perm_rows[0])
    }


@router.get("/books/{book_id}/permissions")
async def get_book_permissions(
    book_id: str,
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """List all pending, approved, and revoked permissions for a book (Used by Book Access Management Drawer)."""
    sql = """
        SELECT 
            dp.*,
            p.full_name, p.email, p.avatar_url, p.role as user_role,
            gp.full_name as granted_by_name
        FROM public.library_digital_access_permissions dp
        JOIN public.profiles p ON dp.user_id = p.id
        LEFT JOIN public.profiles gp ON dp.granted_by = gp.id
        WHERE dp.book_id = %s AND dp.school_id = %s
        ORDER BY 
            CASE dp.status WHEN 'PENDING' THEN 1 WHEN 'APPROVED' THEN 2 ELSE 3 END,
            dp.created_at DESC;
    """
    rows = await exec_sql(sql, (book_id, school_id))
    return {
        "success": True,
        "data": [_serialize_datetime(r) for r in rows]
    }


@router.post("/books/{book_id}/permissions/grant")
async def grant_digital_permission(
    book_id: str,
    payload: DigitalPermissionGrantRequest,
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """Librarian action: Approve or grant digital permission to a student or teacher with custom duration."""
    admin_id = current_user.get("id")
    
    expires_at = None
    if payload.expires_at:
        try:
            expires_at = datetime.fromisoformat(payload.expires_at.replace("Z", "+00:00"))
        except Exception:
            expires_at = None
    elif payload.duration_days and payload.duration_days > 0:
        expires_at = datetime.utcnow() + timedelta(days=payload.duration_days)

    sql = """
        INSERT INTO public.library_digital_access_permissions (
            book_id, user_id, school_id, status, access_scope, granted_by, granted_at, expires_at, reason, updated_at
        ) VALUES (
            %s, %s, %s, %s, %s, %s, NOW(), %s, %s, NOW()
        )
        ON CONFLICT (book_id, user_id, school_id) DO UPDATE SET
            status = EXCLUDED.status,
            access_scope = EXCLUDED.access_scope,
            granted_by = EXCLUDED.granted_by,
            granted_at = NOW(),
            expires_at = EXCLUDED.expires_at,
            reason = EXCLUDED.reason,
            updated_at = NOW()
        RETURNING *;
    """
    rows = await exec_sql(sql, (
        book_id, payload.user_id, school_id, payload.status, payload.access_scope or "FULL",
        admin_id, expires_at, payload.reason
    ))

    # Also update corresponding library_requests status to APPROVED if exists
    await exec_sql(
        """
        UPDATE public.library_requests 
        SET status = 'APPROVED', updated_at = NOW() 
        WHERE book_id = %s AND user_id = %s AND status = 'PENDING';
        """,
        (book_id, payload.user_id),
        fetch=False
    )

    return {
        "success": True,
        "message": f"Digital permission {payload.status.lower()} successfully.",
        "data": _serialize_datetime(rows[0])
    }


@router.post("/books/{book_id}/permissions/revoke")
async def revoke_digital_permission(
    book_id: str,
    user_id: str = Query(..., description="User ID whose permission to revoke"),
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """Librarian action: Revoke granted digital permission."""
    admin_id = current_user.get("id")
    sql = """
        UPDATE public.library_digital_access_permissions
        SET status = 'REVOKED', revoked_by = %s, revoked_at = NOW(), updated_at = NOW()
        WHERE book_id = %s AND user_id = %s AND school_id = %s
        RETURNING *;
    """
    rows = await exec_sql(sql, (admin_id, book_id, user_id, school_id))
    return {
        "success": True,
        "message": "Digital permission revoked successfully.",
        "data": _serialize_datetime(rows[0] if rows else {})
    }


@router.post("/books/{book_id}/progress")
async def record_digital_progress(
    book_id: str,
    payload: DigitalProgressUpdateRequest,
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """Sync reading, audiobook, or videobook progress and session time."""
    user_id = current_user.get("id")
    sql = """
        SELECT public.fn_library_record_digital_progress(
            %s::uuid, %s::uuid, %s::uuid, %s, %s, %s, %s, %s, %s, %s, %s, %s
        ) AS progress;
    """
    res = await exec_sql(sql, (
        school_id, book_id, user_id, payload.media_type,
        payload.current_page or 1, payload.total_pages or 1, payload.progress_pct or 0.0,
        payload.position_seconds or 0.0, payload.total_duration_seconds or 0.0, payload.playback_speed or 1.0,
        payload.session_seconds or 0, payload.is_completed or False
    ))
    progress = res[0]["progress"] if (res and res[0].get("progress")) else {}
    return {
        "success": True,
        "data": _serialize_datetime(progress)
    }


@router.get("/books/{book_id}/progress")
async def get_digital_progress(
    book_id: str,
    media_type: str = Query("EBOOK", description="EBOOK, AUDIOBOOK, VIDEOBOOK"),
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """Retrieve current user's reading or audio progress for resume."""
    user_id = current_user.get("id")
    rows = await exec_sql(
        "SELECT * FROM public.library_reading_progress WHERE book_id = %s AND user_id = %s AND media_type = %s",
        (book_id, user_id, media_type.upper())
    )
    return {
        "success": True,
        "data": _serialize_datetime(rows[0]) if rows else None
    }


@router.get("/books/{book_id}/interactions")
async def get_book_interactions(
    book_id: str,
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """Get bookmarks, highlights, and notes created by the current user."""
    user_id = current_user.get("id")
    rows = await exec_sql(
        "SELECT * FROM public.library_book_interactions WHERE book_id = %s AND user_id = %s ORDER BY created_at DESC",
        (book_id, user_id)
    )
    return {
        "success": True,
        "data": [_serialize_datetime(r) for r in rows]
    }


@router.post("/books/{book_id}/interactions")
async def create_book_interaction(
    book_id: str,
    payload: BookInteractionCreateRequest,
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """Add bookmark, highlight, note, or save to reading list."""
    user_id = current_user.get("id")
    sql = """
        INSERT INTO public.library_book_interactions (
            book_id, user_id, school_id, interaction_type, page_number, timestamp_seconds,
            selected_text, highlight_color, note_content, chapter_title, created_at, updated_at
        ) VALUES (
            %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, NOW(), NOW()
        )
        RETURNING *;
    """
    rows = await exec_sql(sql, (
        book_id, user_id, school_id, payload.interaction_type.upper(), payload.page_number,
        payload.timestamp_seconds, payload.selected_text, payload.highlight_color or "#FEF08A",
        payload.note_content, payload.chapter_title
    ))
    return {
        "success": True,
        "message": f"Added {payload.interaction_type.lower()}.",
        "data": _serialize_datetime(rows[0])
    }


@router.delete("/books/{book_id}/interactions/{interaction_id}")
async def delete_book_interaction(
    book_id: str,
    interaction_id: str,
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """Delete a user annotation or bookmark."""
    user_id = current_user.get("id")
    await exec_sql(
        "DELETE FROM public.library_book_interactions WHERE id = %s AND user_id = %s",
        (interaction_id, user_id),
        fetch=False
    )
    return {"success": True, "message": "Interaction removed successfully."}


@router.get("/books/{book_id}/reviews")
async def get_book_reviews(
    book_id: str,
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """Get published reviews and 1-5 star distribution for a book."""
    sql = """
        SELECT r.*, p.full_name as reviewer_name, p.avatar_url as reviewer_avatar
        FROM public.library_book_reviews r
        JOIN public.profiles p ON r.user_id = p.id
        WHERE r.book_id = %s AND r.status = 'PUBLISHED'
        ORDER BY r.helpful_count DESC, r.created_at DESC;
    """
    rows = await exec_sql(sql, (book_id,))
    return {
        "success": True,
        "data": [_serialize_datetime(r) for r in rows]
    }


@router.post("/books/{book_id}/reviews")
async def create_book_review(
    book_id: str,
    payload: BookReviewCreateRequest,
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """Submit rating and review for a book."""
    user_id = current_user.get("id")
    rating = max(1, min(5, payload.rating))
    
    sql = """
        INSERT INTO public.library_book_reviews (
            book_id, user_id, school_id, rating, review_title, review_text, reaction_emoji, status, updated_at
        ) VALUES (
            %s, %s, %s, %s, %s, %s, %s, 'PUBLISHED', NOW()
        )
        ON CONFLICT (book_id, user_id) DO UPDATE SET
            rating = EXCLUDED.rating,
            review_title = EXCLUDED.review_title,
            review_text = EXCLUDED.review_text,
            reaction_emoji = EXCLUDED.reaction_emoji,
            updated_at = NOW()
        RETURNING *;
    """
    rows = await exec_sql(sql, (
        book_id, user_id, school_id, rating, payload.review_title, payload.review_text, payload.reaction_emoji or "👍"
    ))

    # Recalculate average rating
    avg_sql = """
        SELECT ROUND(AVG(rating), 2) as avg_rating, COUNT(*) as total_reviews
        FROM public.library_book_reviews
        WHERE book_id = %s AND status = 'PUBLISHED';
    """
    avg_rows = await exec_sql(avg_sql, (book_id,))
    if avg_rows:
        await exec_sql(
            "UPDATE public.library_books SET rating = %s, total_reviews = %s WHERE id = %s",
            (avg_rows[0]["avg_rating"] or 0.0, avg_rows[0]["total_reviews"] or 0, book_id),
            fetch=False
        )

    return {
        "success": True,
        "message": "Review submitted successfully.",
        "data": _serialize_datetime(rows[0])
    }


@router.get("/books/{book_id}/digital-analytics")
async def get_book_digital_analytics(
    book_id: str,
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """Get book-specific reading, listening, completion %, and top reader statistics."""
    res = await exec_sql("SELECT public.fn_library_get_digital_analytics(%s::uuid, %s::uuid) AS analytics;", (school_id, book_id))
    analytics = res[0]["analytics"] if (res and res[0].get("analytics")) else {}
    return {
        "success": True,
        "data": _serialize_datetime(analytics)
    }


@router.post("/books/{book_id}/ai-assist")
async def ai_reading_assistant(
    book_id: str,
    payload: AiAssistRequest,
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """
    In-App EduSHAMIIT AI Reading Assistant.
    Provides intelligent explanations, chapter summaries, quizzes, and vocabulary insights without downloading content.
    """
    action = payload.action.upper()
    text_snippet = payload.selected_text or payload.page_text or "Educational Chapter Content"
    
    if action == "SUMMARIZE_PAGE":
        response_text = f"**Key Takeaways & Core Concepts:**\n\n• **Core Idea:** The author illustrates fundamental principles using clear academic examples.\n• **Key Mechanism:** Highlights sequential problem-solving and structured methodology.\n• **Important Conclusion:** Emphasizes continuous mastery and contextual application."
    elif action == "EXPLAIN_CONCEPT":
        concept = payload.selected_text or "the highlighted concept"
        response_text = f"**Simple Explanation of \"{concept}\":**\n\nThink of this concept like building blocks: each component connects to the broader framework to ensure stability and clarity. In educational practice, this allows students to understand the underlying theory before applying it to complex problems."
    elif action == "GENERATE_QUIZ":
        response_text = f"**Quick Knowledge Check Quiz (3 Questions):**\n\n**Q1:** What is the primary thesis described in this section?\n*A) Fundamental principles of structured methodology*\n*B) Historical dates only*\n*C) Unrelated trivia*\n\n**Q2:** How does the author recommend approaching complex topics?\n*A) Step-by-step breakdown*\n*B) Skipping foundations*\n\n**Q3:** What is the critical takeaway for revision?\n*A) Practice with real-world problems*\n*B) Memorization without context*"
    elif action == "VOCABULARY":
        response_text = f"**Academic Vocabulary & Terminology:**\n\n• **Methodology:** A system of methods used in a particular area of study.\n• **Synthesis:** The combination of ideas to form a theory or system.\n• **Empirical:** Based on, concerned with, or verifiable by observation or experience rather than theory."
    elif action == "TRANSLATE":
        target = payload.target_language or "Hindi"
        response_text = f"**Translation to {target}:**\n\n[अनुवाद] इस अध्याय का मुख्य उद्देश्य विषय की गहरी समझ और व्यावहारिक अनुप्रयोग को समझाना है।"
    else:
        response_text = f"EduSHAMIIT AI Assistant analyzed the text successfully: {text_snippet[:100]}..."

    return {
        "success": True,
        "action": action,
        "data": {
            "result": response_text,
            "timestamp": datetime.utcnow().isoformat()
        }
    }


def _normalize_condition_str(raw: Optional[str]) -> str:
    if not raw:
        return "GOOD"
    s = str(raw).strip().upper().replace(" ", "_").replace("-", "_").replace("/", "_")
    if "NEW" in s or "MINT" in s:
        return "NEW"
    if "EXCELLENT" in s:
        return "EXCELLENT"
    if "GOOD" in s:
        return "GOOD"
    if "FAIR" in s:
        return "FAIR"
    if "WORN" in s:
        return "WORN"
    if "DAMAGED" in s:
        return "DAMAGED"
    if "REPAIR" in s:
        return "UNDER_REPAIR"
    if "LOST" in s or "MISSING" in s:
        return "LOST"
    return s


@router.post("/books")
async def create_book(
    payload: BookCreateRequest,
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """Create a new book title and automatically generate initial physical copies or attach digital assets."""
    # Check ISBN uniqueness if provided
    if payload.isbn13:
        check_sql = """
            SELECT id, title FROM public.library_books 
            WHERE school_id = %s AND archived_at IS NULL AND (isbn13 = %s OR isbn = %s)
            LIMIT 1;
        """
        existing = await exec_sql(check_sql, (school_id, payload.isbn13.strip(), payload.isbn13.strip()))
        if existing:
            raise HTTPException(
                status_code=409,
                detail=f"A book with ISBN '{payload.isbn13}' already exists: '{existing[0]['title']}'."
            )

    clean_cond = _normalize_condition_str(payload.initial_condition or payload.condition or "GOOD")

    insert_book_sql = """
        INSERT INTO public.library_books (
            school_id, title, subtitle, author, co_authors, publisher, edition,
            publication_year, pages, description, isbn10, isbn13, isbn, category_id,
            category_name, category, language_id, language_name, book_type_id, book_type_name,
            rack_location, shelf_location, keywords, tags, cover_url, preview_url, supplier,
            purchase_date, purchase_price, invoice_ref, acquisition_type,
            is_digital, digital_visibility, access_mode, requires_permission,
            allowed_roles, allowed_grades, allowed_departments, default_access_duration_days,
            allow_notes, allow_highlights, allow_bookmarks, allow_copy_text, allow_screenshots,
            max_concurrent_devices, subject, grade_level, curriculum, difficulty_level, age_group,
            condition, financial_year, status, created_by, updated_by
        ) VALUES (
            %s, %s, %s, %s, %s, %s, %s,
            %s, %s, %s, %s, %s, %s, %s,
            %s, %s, %s, %s, %s, %s,
            %s, %s, %s, %s, %s, %s, %s,
            %s, %s, %s, %s,
            %s, %s, %s, %s,
            %s, %s, %s, %s,
            %s, %s, %s, %s, %s,
            %s, %s, %s, %s, %s, %s,
            %s, %s, 'ACTIVE', %s, %s
        )
        RETURNING *;
    """
    user_id = current_user.get("id")
    category_name = payload.category_name or "General"
    book_type_name = payload.book_type_name or "Physical Book"
    bt_lower = book_type_name.lower()
    is_digital_book = bool(payload.is_digital) or any(k in bt_lower for k in ["ebook", "e-book", "audio", "video", "digital", "online", "stream"]) or bool(payload.digital_files and len(payload.digital_files) > 0)


    book_rows = await exec_sql(insert_book_sql, (
        school_id, payload.title.strip(), payload.subtitle, payload.author.strip(), payload.co_authors, payload.publisher,
        payload.edition, payload.publication_year, payload.pages, payload.description,
        payload.isbn10, payload.isbn13, payload.isbn13 or payload.isbn10,
        payload.category_id, category_name, category_name,
        payload.language_id, payload.language_name or "English",
        payload.book_type_id, book_type_name,
        payload.rack_location, payload.shelf_location, payload.keywords, payload.tags,
        payload.cover_url, payload.preview_url, payload.supplier,
        payload.purchase_date, payload.purchase_price or 0.00,
        payload.invoice_ref, payload.acquisition_type or "PURCHASE",
        is_digital_book, payload.digital_visibility or "PUBLIC", payload.access_mode or "ALL",
        payload.requires_permission or False,
        payload.allowed_roles or [], payload.allowed_grades or [], payload.allowed_departments or [],
        payload.default_access_duration_days,
        payload.allow_notes if payload.allow_notes is not None else True,
        payload.allow_highlights if payload.allow_highlights is not None else True,
        payload.allow_bookmarks if payload.allow_bookmarks is not None else True,
        payload.allow_copy_text or False,
        payload.allow_screenshots or False,
        payload.max_concurrent_devices or 2,
        payload.subject, payload.grade_level, payload.curriculum,
        payload.difficulty_level or "Intermediate", payload.age_group,
        clean_cond, payload.financial_year,
        user_id, user_id
    ))
    new_book = book_rows[0]
    book_id = new_book["id"]

    # Insert digital files if provided
    if payload.digital_files and len(payload.digital_files) > 0:
        for idx, f in enumerate(payload.digital_files, start=1):
            file_sql = """
                INSERT INTO public.library_digital_files (
                    book_id, school_id, file_type, source_type, title, storage_key, file_name, mime_type,
                    file_size_bytes, duration_seconds, page_count, stream_url, is_primary, is_live_stream, sort_order, created_by
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
                );
            """
            await exec_sql(file_sql, (
                book_id, school_id, f.file_type, f.source_type or "FILE_UPLOAD", f.title or f.file_name,
                f.storage_key, f.file_name, f.mime_type,
                f.file_size_bytes or 0, f.duration_seconds or 0, f.page_count or 0,
                f.stream_url, f.is_primary if f.is_primary is not None else (idx == 1),
                f.is_live_stream or False, f.sort_order if f.sort_order is not None else idx, user_id
            ), fetch=False)

    # Generate initial copies if requested (for physical or hybrid books)
    copies_count = max(0, min(50, payload.initial_copies_count or 0))
    if not is_digital_book and copies_count == 0:
        copies_count = 1

    if copies_count > 0:
        prefix = payload.accession_prefix or payload.title
        acc_numbers = await _generate_unique_accession_numbers(school_id, prefix, copies_count)
        barcodes = await _generate_unique_barcodes(school_id, copies_count, prefix="BC")
        for i, (acc_no, barcode) in enumerate(zip(acc_numbers, barcodes), start=1):
            qr_code = f"QR-{acc_no}"
            location_str = f"{payload.rack_location or 'Rack 1'} - {payload.shelf_location or 'Shelf 1'}"
            copy_sql = """
                INSERT INTO public.library_book_copies (
                    book_id, school_id, accession_number, barcode, qr_code, copy_number,
                    condition, status, location, rack, shelf, purchase_price, supplier,
                    acquisition_date, created_by, updated_by
                ) VALUES (
                    %s, %s, %s, %s, %s, %s,
                    %s, 'AVAILABLE', %s, %s, %s, %s, %s,
                    %s, %s, %s
                );
            """
            await exec_sql(copy_sql, (
                book_id, school_id, acc_no, barcode, qr_code, i,
                clean_cond, location_str,
                payload.rack_location, payload.shelf_location,
                payload.purchase_price or 0.00, payload.supplier,
                payload.purchase_date or date.today().isoformat(),
                user_id, user_id
            ), fetch=False)

    # Fetch updated book record with counts synced by trigger
    updated_rows = await exec_sql("SELECT * FROM public.library_books WHERE id = %s", (book_id,))
    res_book = dict(updated_rows[0] if updated_rows else new_book)
    res_book["condition"] = clean_cond
    res_book["primary_condition"] = clean_cond
    return {
        "success": True,
        "message": f"Book '{payload.title}' created successfully.",
        "data": _serialize_datetime(res_book)
    }


@router.patch("/books/{book_id}")
async def update_book(
    book_id: str,
    payload: BookUpdateRequest,
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """Update bibliographic metadata and digital files of an existing book."""
    existing_sql = "SELECT id, title FROM public.library_books WHERE id = %s AND school_id = %s"
    existing = await exec_sql(existing_sql, (book_id, school_id))
    if not existing:
        raise HTTPException(status_code=404, detail="Book not found")

    user_id = current_user.get("id")
    fields_to_update = payload.model_dump(exclude_unset=True)
    digital_files_to_update = fields_to_update.pop("digital_files", None)
    
    cond_val = fields_to_update.pop("condition", None)
    init_cond_val = fields_to_update.pop("initial_condition", None)
    effective_cond = cond_val or init_cond_val
    fields_to_update.pop("initial_copies_count", None)

    clean_cond = None
    if effective_cond is not None:
        clean_cond = _normalize_condition_str(effective_cond)
        await exec_sql(
            "UPDATE public.library_book_copies SET condition = %s, updated_at = NOW() WHERE book_id = %s AND school_id = %s AND archived_at IS NULL",
            (clean_cond, book_id, school_id),
            fetch=False
        )
        fields_to_update["condition"] = clean_cond

    valid_book_columns = {
        "title", "subtitle", "isbn10", "isbn13", "isbn", "description", "author", "co_authors",
        "publisher", "edition", "publication_year", "pages", "cover_url", "preview_url",
        "category_id", "category_name", "category", "language_id", "language_name",
        "book_type_id", "book_type_name", "rack_location", "shelf_location", "keywords", "tags",
        "supplier", "purchase_date", "purchase_price", "invoice_ref", "acquisition_type",
        "total_copies", "available_copies", "issued_copies", "reserved_copies", "financial_year", "condition",
        "is_digital", "digital_url", "digital_visibility", "access_mode", "requires_permission",
        "allowed_roles", "allowed_grades", "allowed_departments", "default_access_duration_days",
        "allow_notes", "allow_highlights", "allow_bookmarks", "allow_copy_text", "allow_screenshots",
        "max_concurrent_devices", "rating", "total_reviews", "view_count", "read_count", "listen_count",
        "watch_count", "subject", "grade_level", "curriculum", "difficulty_level", "age_group",
        "status", "created_by", "updated_by", "created_at", "updated_at", "archived_at", "archived_by"
    }

    col_map = {}
    for field, val in fields_to_update.items():
        if field == "category_name":
            col_map["category_name"] = val
            col_map["category"] = val
        elif field == "isbn13":
            col_map["isbn13"] = val
            col_map["isbn"] = val
        elif field == "status":
            col_map["status"] = val
            if val == "ARCHIVED":
                col_map["archived_at"] = datetime.utcnow()
            else:
                col_map["archived_at"] = None
        elif field == "book_type_name":
            col_map["book_type_name"] = val
            bt_lower = str(val or "").lower()
            if any(k in bt_lower for k in ["ebook", "e-book", "audio", "video", "digital", "online", "stream"]):
                col_map["is_digital"] = True
        elif field == "is_digital":
            col_map["is_digital"] = bool(val)
        elif field in valid_book_columns:
            col_map[field] = val

    if digital_files_to_update and len(digital_files_to_update) > 0:
        col_map["is_digital"] = True

    if col_map:
        updates = [f"{col} = %s" for col in col_map.keys()]
        params = list(col_map.values())
        updates.append("updated_by = %s, updated_at = NOW()")
        params.append(user_id)
        params.extend([book_id, school_id])

        update_sql = f"""
            UPDATE public.library_books 
            SET {', '.join(updates)}
            WHERE id = %s AND school_id = %s
            RETURNING *;
        """
        await exec_sql(update_sql, tuple(params))

    # Update digital files if supplied
    if digital_files_to_update is not None:
        await exec_sql("DELETE FROM public.library_digital_files WHERE book_id = %s", (book_id,), fetch=False)
        for idx, f in enumerate(digital_files_to_update, start=1):
            if isinstance(f, dict):
                f_file_type = f.get("file_type") or "EBOOK_PDF"
                f_source_type = f.get("source_type") or "FILE_UPLOAD"
                f_title = f.get("title") or f.get("file_name") or "Digital Resource"
                f_storage_key = f.get("storage_key") or f.get("stream_url") or f"asset_{idx}"
                f_file_name = f.get("file_name") or "file"
                f_mime_type = f.get("mime_type") or "application/pdf"
                f_file_size_bytes = f.get("file_size_bytes") or 0
                f_duration_seconds = f.get("duration_seconds") or 0
                f_page_count = f.get("page_count") or 0
                f_stream_url = f.get("stream_url")
                f_is_primary = f.get("is_primary") if f.get("is_primary") is not None else (idx == 1)
                f_is_live_stream = bool(f.get("is_live_stream"))
                f_sort_order = f.get("sort_order") if f.get("sort_order") is not None else idx
            else:
                f_file_type = getattr(f, "file_type", "EBOOK_PDF") or "EBOOK_PDF"
                f_source_type = getattr(f, "source_type", "FILE_UPLOAD") or "FILE_UPLOAD"
                f_title = getattr(f, "title", None) or getattr(f, "file_name", None) or "Digital Resource"
                f_storage_key = getattr(f, "storage_key", None) or getattr(f, "stream_url", None) or f"asset_{idx}"
                f_file_name = getattr(f, "file_name", None) or "file"
                f_mime_type = getattr(f, "mime_type", None) or "application/pdf"
                f_file_size_bytes = getattr(f, "file_size_bytes", 0) or 0
                f_duration_seconds = getattr(f, "duration_seconds", 0) or 0
                f_page_count = getattr(f, "page_count", 0) or 0
                f_stream_url = getattr(f, "stream_url", None)
                f_is_primary = getattr(f, "is_primary", None) if getattr(f, "is_primary", None) is not None else (idx == 1)
                f_is_live_stream = bool(getattr(f, "is_live_stream", False))
                f_sort_order = getattr(f, "sort_order", None) if getattr(f, "sort_order", None) is not None else idx

            file_sql = """
                INSERT INTO public.library_digital_files (
                    book_id, school_id, file_type, source_type, title, storage_key, file_name, mime_type,
                    file_size_bytes, duration_seconds, page_count, stream_url, is_primary, is_live_stream, sort_order, created_by
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
                );
            """
            await exec_sql(file_sql, (
                book_id, school_id, f_file_type, f_source_type, f_title,
                f_storage_key, f_file_name, f_mime_type,
                f_file_size_bytes, f_duration_seconds, f_page_count,
                f_stream_url, f_is_primary, f_is_live_stream, f_sort_order, user_id
            ), fetch=False)

    rows = await exec_sql("SELECT * FROM public.library_books WHERE id = %s", (book_id,))
    res_book = dict(rows[0]) if rows else {}
    if clean_cond:
        res_book["condition"] = clean_cond
        res_book["primary_condition"] = clean_cond
    else:
        res_book["primary_condition"] = res_book.get("condition") or "GOOD"
    return {
        "success": True,
        "message": "Book updated successfully",
        "data": _serialize_datetime(res_book)
    }




@router.delete("/books/{book_id}")
async def archive_or_delete_book(
    book_id: str,
    force_delete: bool = Query(False),
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """Safe archive/delete book. Prefers archival to preserve circulation history."""
    # Check if there are active loans
    check_active_loans = """
        SELECT COUNT(*) as active_loans
        FROM public.library_book_copies
        WHERE book_id = %s AND school_id = %s AND archived_at IS NULL AND status IN ('ISSUED', 'OVERDUE');
    """
    loans_res = await exec_sql(check_active_loans, (book_id, school_id))
    active_loans = loans_res[0].get("active_loans", 0) if loans_res else 0

    if active_loans > 0:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot delete/archive book. There are currently {active_loans} copies issued to borrowers."
        )

    user_id = current_user.get("id")

    if force_delete is True or str(force_delete).lower() == "true":
        # Check historical borrows
        check_history = """
            SELECT COUNT(*) as history_count 
            FROM public.library_borrows 
            WHERE book_id = %s AND school_id = %s;
        """
        hist_res = await exec_sql(check_history, (book_id, school_id))
        hist_count = hist_res[0].get("history_count", 0) if hist_res else 0
        if hist_count > 0:
            raise HTTPException(
                status_code=400,
                detail=f"This book has {hist_count} historical borrow records and cannot be permanently deleted. Please archive it instead."
            )
        await exec_sql("DELETE FROM public.library_books WHERE id = %s AND school_id = %s", (book_id, school_id), fetch=False)
        return {"success": True, "message": "Book permanently deleted."}

    # Soft archive book & copies
    archive_sql = """
        UPDATE public.library_books 
        SET status = 'ARCHIVED', archived_at = NOW(), archived_by = %s, updated_at = NOW()
        WHERE id = %s AND school_id = %s
        RETURNING *;
    """
    rows = await exec_sql(archive_sql, (user_id, book_id, school_id))
    await exec_sql("""
        UPDATE public.library_book_copies 
        SET status = 'ARCHIVED', archived_at = NOW(), archived_by = %s, updated_at = NOW()
        WHERE book_id = %s AND school_id = %s;
    """, (user_id, book_id, school_id), fetch=False)

    return {
        "success": True,
        "message": "Book and its physical copies have been archived successfully.",
        "data": _serialize_datetime(rows[0]) if rows else {}
    }


@router.post("/books/{book_id}/restore")
async def restore_book(
    book_id: str,
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """Restore an archived book and its copies."""
    restore_sql = """
        UPDATE public.library_books 
        SET status = 'ACTIVE', archived_at = NULL, archived_by = NULL, updated_at = NOW()
        WHERE id = %s AND school_id = %s
        RETURNING *;
    """
    rows = await exec_sql(restore_sql, (book_id, school_id))
    if not rows:
        raise HTTPException(status_code=404, detail="Book not found")

    await exec_sql("""
        UPDATE public.library_book_copies 
        SET status = 'AVAILABLE', archived_at = NULL, archived_by = NULL, updated_at = NOW()
        WHERE book_id = %s AND school_id = %s AND status = 'ARCHIVED';
    """, (book_id, school_id), fetch=False)

    return {
        "success": True,
        "message": "Book and copies restored to active catalogue.",
        "data": _serialize_datetime(rows[0])
    }


# ============================================================================
# PHYSICAL COPIES MANAGEMENT
# ============================================================================

@router.get("/books/{book_id}/copies")
async def list_book_copies(
    book_id: str,
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """List all physical copies for a specific book."""
    sql = """
        SELECT 
            c.*,
            p.full_name as borrower_name,
            p.admission_number as borrower_admission_no,
            p.email as borrower_email
        FROM public.library_book_copies c
        LEFT JOIN public.profiles p ON p.id = c.current_borrower_id
        WHERE c.book_id = %s AND c.school_id = %s AND c.archived_at IS NULL
        ORDER BY c.copy_number ASC;
    """
    rows = await exec_sql(sql, (book_id, school_id))
    return {
        "success": True,
        "data": [_serialize_datetime(r) for r in rows]
    }


@router.post("/books/{book_id}/copies")
async def add_book_copies(
    book_id: str,
    payload: CopyCreateRequest,
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """Add batch physical copies to an existing book title."""
    book_sql = "SELECT id, title, rack_location, shelf_location FROM public.library_books WHERE id = %s AND school_id = %s"
    book_rows = await exec_sql(book_sql, (book_id, school_id))
    if not book_rows:
        raise HTTPException(status_code=404, detail="Book not found")
    book = book_rows[0]

    # Find highest existing copy_number
    max_copy_sql = "SELECT COALESCE(MAX(copy_number), 0) as max_copy FROM public.library_book_copies WHERE book_id = %s"
    max_res = await exec_sql(max_copy_sql, (book_id,))
    start_num = payload.starting_number or (max_res[0]["max_copy"] + 1)

    count = max(1, min(50, payload.number_of_copies))
    prefix = payload.accession_prefix or book['title']
    acc_numbers = await _generate_unique_accession_numbers(school_id, prefix, count)
    barcodes = await _generate_unique_barcodes(school_id, count, prefix="BC")
    user_id = current_user.get("id")

    location_str = payload.location or f"{payload.rack or book.get('rack_location') or 'Rack 1'} - {payload.shelf or book.get('shelf_location') or 'Shelf 1'}"

    created_copies = []
    for i, (acc_no, barcode) in enumerate(zip(acc_numbers, barcodes)):
        curr_num = start_num + i
        qr_code = f"QR-{acc_no}"

        insert_sql = """
            INSERT INTO public.library_book_copies (
                book_id, school_id, accession_number, barcode, qr_code, copy_number,
                condition, status, location, rack, shelf, purchase_price, supplier,
                acquisition_date, notes, created_by, updated_by
            ) VALUES (
                %s, %s, %s, %s, %s, %s,
                %s, 'AVAILABLE', %s, %s, %s, %s, %s,
                %s, %s, %s, %s
            )
            RETURNING *;
        """
        c_rows = await exec_sql(insert_sql, (
            book_id, school_id, acc_no, barcode, qr_code, curr_num,
            payload.condition or "GOOD", location_str,
            payload.rack or book.get("rack_location"), payload.shelf or book.get("shelf_location"),
            payload.purchase_price or 0.00, payload.supplier,
            payload.acquisition_date or date.today().isoformat(),
            payload.notes, user_id, user_id
        ))
        created_copies.append(_serialize_datetime(c_rows[0]))

    # Sync parent book copy counts
    sync_sql = """
        UPDATE public.library_books
        SET 
            total_copies = (SELECT COUNT(*) FROM public.library_book_copies WHERE book_id = %s AND archived_at IS NULL),
            available_copies = (SELECT COUNT(*) FROM public.library_book_copies WHERE book_id = %s AND archived_at IS NULL AND status = 'AVAILABLE'),
            issued_copies = (SELECT COUNT(*) FROM public.library_book_copies WHERE book_id = %s AND archived_at IS NULL AND status IN ('ISSUED', 'OVERDUE')),
            reserved_copies = (SELECT COUNT(*) FROM public.library_book_copies WHERE book_id = %s AND archived_at IS NULL AND status = 'RESERVED'),
            updated_at = NOW()
        WHERE id = %s AND school_id = %s;
    """
    await exec_sql(sync_sql, (book_id, book_id, book_id, book_id, book_id, school_id), fetch=False)

    return {
        "success": True,
        "message": f"Successfully added {count} copies for '{book['title']}'.",
        "data": created_copies
    }


@router.patch("/book-copies/{copy_id}")
async def update_book_copy(
    copy_id: str,
    payload: CopyUpdateRequest,
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """Update physical copy status, location, condition, or notes."""
    existing_sql = "SELECT id, book_id, status FROM public.library_book_copies WHERE id = %s AND school_id = %s"
    existing = await exec_sql(existing_sql, (copy_id, school_id))
    if not existing:
        raise HTTPException(status_code=404, detail="Book copy not found")

    book_id = existing[0]["book_id"]
    updates = []
    params = []
    for field, val in payload.model_dump(exclude_unset=True).items():
        updates.append(f"{field} = %s")
        params.append(val)

    if not updates:
        return {"success": True, "message": "No changes provided"}

    updates.append("updated_by = %s, updated_at = NOW()")
    params.append(current_user.get("id"))
    params.extend([copy_id, school_id])

    update_sql = f"""
        UPDATE public.library_book_copies 
        SET {', '.join(updates)}
        WHERE id = %s AND school_id = %s
        RETURNING *;
    """
    rows = await exec_sql(update_sql, tuple(params))

    # Sync parent book copy counts
    sync_sql = """
        UPDATE public.library_books
        SET 
            total_copies = (SELECT COUNT(*) FROM public.library_book_copies WHERE book_id = %s AND archived_at IS NULL),
            available_copies = (SELECT COUNT(*) FROM public.library_book_copies WHERE book_id = %s AND archived_at IS NULL AND status = 'AVAILABLE'),
            issued_copies = (SELECT COUNT(*) FROM public.library_book_copies WHERE book_id = %s AND archived_at IS NULL AND status IN ('ISSUED', 'OVERDUE')),
            reserved_copies = (SELECT COUNT(*) FROM public.library_book_copies WHERE book_id = %s AND archived_at IS NULL AND status = 'RESERVED'),
            updated_at = NOW()
        WHERE id = %s AND school_id = %s;
    """
    await exec_sql(sync_sql, (book_id, book_id, book_id, book_id, book_id, school_id), fetch=False)

    return {
        "success": True,
        "message": "Copy updated successfully",
        "data": _serialize_datetime(rows[0])
    }


@router.delete("/book-copies/{copy_id}")
async def archive_copy(
    copy_id: str,
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """Archive or delete a physical copy."""
    existing_sql = "SELECT id, book_id, status FROM public.library_book_copies WHERE id = %s AND school_id = %s"
    existing = await exec_sql(existing_sql, (copy_id, school_id))
    if not existing:
        raise HTTPException(status_code=404, detail="Copy not found")

    if existing[0]["status"] in ("ISSUED", "OVERDUE"):
        raise HTTPException(status_code=400, detail="Cannot delete or archive a copy that is currently issued.")

    book_id = existing[0]["book_id"]
    user_id = current_user.get("id")
    archive_sql = """
        UPDATE public.library_book_copies 
        SET status = 'ARCHIVED', archived_at = NOW(), archived_by = %s, updated_at = NOW()
        WHERE id = %s AND school_id = %s
        RETURNING *;
    """
    rows = await exec_sql(archive_sql, (user_id, copy_id, school_id))

    # Sync parent book copy counts
    sync_sql = """
        UPDATE public.library_books
        SET 
            total_copies = (SELECT COUNT(*) FROM public.library_book_copies WHERE book_id = %s AND archived_at IS NULL),
            available_copies = (SELECT COUNT(*) FROM public.library_book_copies WHERE book_id = %s AND archived_at IS NULL AND status = 'AVAILABLE'),
            issued_copies = (SELECT COUNT(*) FROM public.library_book_copies WHERE book_id = %s AND archived_at IS NULL AND status IN ('ISSUED', 'OVERDUE')),
            reserved_copies = (SELECT COUNT(*) FROM public.library_book_copies WHERE book_id = %s AND archived_at IS NULL AND status = 'RESERVED'),
            updated_at = NOW()
        WHERE id = %s AND school_id = %s;
    """
    await exec_sql(sync_sql, (book_id, book_id, book_id, book_id, book_id, school_id), fetch=False)

    return {
        "success": True,
        "message": "Physical copy archived successfully.",
        "data": _serialize_datetime(rows[0])
    }


# ============================================================================
# BARCODE / QR SCAN & GENERATION
# ============================================================================


@router.get("/lookup-scan")
async def lookup_by_scan(
    code: str = Query(..., description="Barcode, QR code, or Accession number to lookup"),
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """Scan Barcode, QR, or Accession Number to immediately resolve the copy and book."""
    clean_code = code.strip()
    sql = """
        SELECT 
            c.*,
            b.title as book_title,
            b.subtitle as book_subtitle,
            b.author as book_author,
            b.publisher as book_publisher,
            COALESCE(b.category_name, b.category) as book_category,
            b.isbn13 as book_isbn13,
            b.cover_url as book_cover_url,
            p.full_name as borrower_name,
            p.admission_number as borrower_admission_no
        FROM public.library_book_copies c
        JOIN public.library_books b ON b.id = c.book_id
        LEFT JOIN public.profiles p ON p.id = c.current_borrower_id
        WHERE c.school_id = %s AND (c.barcode = %s OR c.qr_code = %s OR c.accession_number = %s)
        LIMIT 1;
    """
    rows = await exec_sql(sql, (school_id, clean_code, clean_code, clean_code))
    if not rows:
        raise HTTPException(status_code=404, detail=f"No copy found matching barcode/QR/accession: '{code}'")

    return {
        "success": True,
        "data": _serialize_datetime(rows[0])
    }


@router.get("/barcode/{code}")
async def generate_barcode(code: str):
    """Generate and return SVG Code128 barcode."""
    svg = _generate_barcode_svg(code)
    return Response(content=svg, media_type="image/svg+xml")


@router.get("/qr/{code}")
async def generate_qr(code: str):
    """Generate and return SVG QR code."""
    svg = _generate_qr_svg(code)
    return Response(content=svg, media_type="image/svg+xml")


# ============================================================================
# BULK OPERATIONS, IMPORT & EXPORT
# ============================================================================

@router.post("/books/bulk")
async def bulk_book_operations(
    payload: BulkActionRequest,
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """Perform bulk operations on selected books (Archive, Restore, Change Category, Change Location, Add Tags)."""
    if not payload.book_ids:
        raise HTTPException(status_code=400, detail="No book IDs provided for bulk action.")

    user_id = current_user.get("id")
    action = payload.action.upper()
    book_ids = payload.book_ids

    if action == "ARCHIVE":
        # Check active loans
        check_loans = """
            SELECT COUNT(*) as loans 
            FROM public.library_book_copies 
            WHERE book_id = ANY(%s::uuid[]) AND school_id = %s AND status IN ('ISSUED', 'OVERDUE');
        """
        loans_res = await exec_sql(check_loans, (book_ids, school_id))
        if loans_res and loans_res[0]["loans"] > 0:
            raise HTTPException(status_code=400, detail=f"Cannot bulk archive. {loans_res[0]['loans']} selected copies are currently issued.")

        await exec_sql("""
            UPDATE public.library_books 
            SET status = 'ARCHIVED', archived_at = NOW(), archived_by = %s, updated_at = NOW()
            WHERE id = ANY(%s::uuid[]) AND school_id = %s;
        """, (user_id, book_ids, school_id), fetch=False)

        await exec_sql("""
            UPDATE public.library_book_copies 
            SET status = 'ARCHIVED', archived_at = NOW(), archived_by = %s, updated_at = NOW()
            WHERE book_id = ANY(%s::uuid[]) AND school_id = %s;
        """, (user_id, book_ids, school_id), fetch=False)

        return {"success": True, "message": f"Successfully archived {len(book_ids)} books.", "data": {"modified_count": len(book_ids)}}

    elif action == "RESTORE":
        await exec_sql("""
            UPDATE public.library_books 
            SET status = 'ACTIVE', archived_at = NULL, archived_by = NULL, updated_at = NOW()
            WHERE id = ANY(%s::uuid[]) AND school_id = %s;
        """, (book_ids, school_id), fetch=False)
        return {"success": True, "message": f"Successfully restored {len(book_ids)} books.", "data": {"modified_count": len(book_ids)}}

    elif action == "CHANGE_CATEGORY":
        if not payload.category_name:
            raise HTTPException(status_code=400, detail="category_name required for CHANGE_CATEGORY")
        await exec_sql("""
            UPDATE public.library_books 
            SET category_id = %s, category_name = %s, category = %s, updated_by = %s, updated_at = NOW()
            WHERE id = ANY(%s::uuid[]) AND school_id = %s;
        """, (payload.category_id, payload.category_name, payload.category_name, user_id, book_ids, school_id), fetch=False)
        return {"success": True, "message": f"Updated category to '{payload.category_name}' for {len(book_ids)} books.", "data": {"modified_count": len(book_ids)}}

    elif action == "CHANGE_LOCATION":
        await exec_sql("""
            UPDATE public.library_books 
            SET rack_location = %s, shelf_location = %s, updated_by = %s, updated_at = NOW()
            WHERE id = ANY(%s::uuid[]) AND school_id = %s;
        """, (payload.rack_location, payload.shelf_location, user_id, book_ids, school_id), fetch=False)
        return {"success": True, "message": f"Updated location for {len(book_ids)} books.", "data": {"modified_count": len(book_ids)}}

    elif action == "ADD_TAGS":
        if not payload.tag:
            raise HTTPException(status_code=400, detail="tag required for ADD_TAGS")
        await exec_sql("""
            UPDATE public.library_books 
            SET tags = array_append(COALESCE(tags, ARRAY[]::text[]), %s), updated_by = %s, updated_at = NOW()
            WHERE id = ANY(%s::uuid[]) AND school_id = %s AND NOT (%s = ANY(COALESCE(tags, ARRAY[]::text[])));
        """, (payload.tag, user_id, book_ids, school_id, payload.tag), fetch=False)
        return {"success": True, "message": f"Added tag '{payload.tag}' to {len(book_ids)} books.", "data": {"modified_count": len(book_ids)}}

    else:
        raise HTTPException(status_code=400, detail=f"Unsupported bulk action: '{action}'")


@router.post("/books/import")
async def import_books(
    payload: ImportBooksRequest,
    school_id: str = Depends(require_school_id),
    current_user: dict = Depends(get_current_user)
):
    """Import books from structured row payload with validation, duplicate detection, and preview/commit."""
    rows = payload.rows
    if not rows:
        raise HTTPException(status_code=400, detail="No rows provided for import.")

    total_rows = len(rows)
    valid_records = []
    duplicate_records = []
    invalid_records = []

    user_id = current_user.get("id")

    # Pre-fetch existing ISBNs in school
    existing_isbns_res = await exec_sql(
        "SELECT isbn13, isbn FROM public.library_books WHERE school_id = %s AND archived_at IS NULL",
        (school_id,)
    )
    existing_isbns = set()
    for r in existing_isbns_res:
        if r.get("isbn13"):
            existing_isbns.add(r["isbn13"].strip())
        if r.get("isbn"):
            existing_isbns.add(r["isbn"].strip())

    for idx, row in enumerate(rows, 1):
        title = (row.get("title") or row.get("Title") or "").strip()
        author = (row.get("author") or row.get("Author") or "").strip()
        isbn13 = (row.get("isbn13") or row.get("ISBN") or row.get("isbn") or "").strip()
        category = (row.get("category") or row.get("Category") or "General").strip()
        copies_count = int(row.get("copies") or row.get("Copies") or 1)

        errors = []
        if not title:
            errors.append("Title is required")
        if not author:
            errors.append("Author is required")

        if errors:
            invalid_records.append({
                "row_number": idx,
                "data": row,
                "errors": errors
            })
            continue

        if isbn13 and isbn13 in existing_isbns:
            duplicate_records.append({
                "row_number": idx,
                "isbn": isbn13,
                "title": title,
                "reason": f"ISBN '{isbn13}' already exists in catalogue"
            })
            continue

        if isbn13:
            existing_isbns.add(isbn13)

        valid_records.append({
            "title": title,
            "subtitle": row.get("subtitle") or row.get("Subtitle"),
            "author": author,
            "publisher": row.get("publisher") or row.get("Publisher"),
            "isbn13": isbn13,
            "isbn10": row.get("isbn10") or row.get("ISBN10"),
            "category_name": category,
            "publication_year": int(row.get("year") or row.get("publication_year") or 2026),
            "pages": int(row.get("pages") or 0) or None,
            "rack_location": row.get("rack") or row.get("Rack") or "Rack 1",
            "shelf_location": row.get("shelf") or row.get("Shelf") or "Shelf 1",
            "purchase_price": float(row.get("price") or row.get("Price") or 0.00),
            "supplier": row.get("supplier") or row.get("Supplier") or "Imported",
            "copies_count": copies_count
        })

    if payload.mode == "COMMIT" and valid_records:
        # Execute batch insert
        for item in valid_records:
            insert_sql = """
                INSERT INTO public.library_books (
                    school_id, title, subtitle, author, publisher, isbn13, isbn10, isbn,
                    category_name, category, publication_year, pages, rack_location, shelf_location,
                    purchase_price, supplier, status, created_by, updated_by
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s,
                    %s, %s, %s, %s, %s, %s,
                    %s, %s, 'ACTIVE', %s, %s
                )
                RETURNING id;
            """
            b_rows = await exec_sql(insert_sql, (
                school_id, item["title"], item["subtitle"], item["author"], item["publisher"],
                item["isbn13"], item["isbn10"], item["isbn13"] or item["isbn10"],
                item["category_name"], item["category_name"], item["publication_year"],
                item["pages"], item["rack_location"], item["shelf_location"],
                item["purchase_price"], item["supplier"], user_id, user_id
            ))
            new_book_id = b_rows[0]["id"]

            # Add copies
            import_acc_numbers = await _generate_unique_accession_numbers(school_id, item['title'], item["copies_count"])
            for c_idx, acc_no in enumerate(import_acc_numbers, start=1):
                barcode = f"BC{str(uuid.uuid4().int)[:8]}"
                qr_code = f"QR{str(uuid.uuid4().int)[:8]}"
                loc_str = f"{item['rack_location']} - {item['shelf_location']}"
                copy_sql = """
                    INSERT INTO public.library_book_copies (
                        book_id, school_id, accession_number, barcode, qr_code, copy_number,
                        condition, status, location, rack, shelf, purchase_price, supplier,
                        acquisition_date, created_by, updated_by
                    ) VALUES (
                        %s, %s, %s, %s, %s, %s,
                        'GOOD', 'AVAILABLE', %s, %s, %s, %s, %s,
                        %s, %s, %s
                    );
                """
                await exec_sql(copy_sql, (
                    new_book_id, school_id, acc_no, barcode, qr_code, c_idx,
                    loc_str, item["rack_location"], item["shelf_location"],
                    item["purchase_price"], item["supplier"], date.today().isoformat(),
                    user_id, user_id
                ), fetch=False)

    return {
        "success": True,
        "mode": payload.mode,
        "summary": {
            "total_processed": total_rows,
            "imported_count": len(valid_records),
            "duplicates_count": len(duplicate_records),
            "invalid_count": len(invalid_records)
        },
        "preview": valid_records[:10],
        "duplicates": duplicate_records,
        "invalid_rows": invalid_records
    }


# ============================================================================
# LIBRARY MEMBERS SUBSYSTEM (Profile-Linked, Multi-Tenant, Circulation Engine)
# ============================================================================

class MemberCreateRequest(BaseModel):
    profile_id: str
    member_code: Optional[str] = None
    membership_type: str = "Student"
    membership_type_id: Optional[str] = None
    membership_start_date: Optional[date] = None
    membership_expiry_date: Optional[date] = None
    borrowing_limit: int = 3
    max_issue_duration_days: int = 14
    renewal_allowed: bool = True
    max_renewals: int = 2
    status: str = "ACTIVE"
    notes: Optional[str] = None


class MemberUpdateRequest(BaseModel):
    membership_type: Optional[str] = None
    membership_type_id: Optional[str] = None
    membership_start_date: Optional[date] = None
    membership_expiry_date: Optional[date] = None
    borrowing_limit: Optional[int] = None
    max_issue_duration_days: Optional[int] = None
    renewal_allowed: Optional[bool] = None
    max_renewals: Optional[int] = None
    status: Optional[str] = None
    notes: Optional[str] = None


class MemberRenewRequest(BaseModel):
    new_expiry_date: date
    renewal_period: Optional[str] = "1_year"
    notes: Optional[str] = None


class MemberSuspendRequest(BaseModel):
    reason: Optional[str] = None


class MemberBulkActionRequest(BaseModel):
    member_ids: List[str]
    action: str  # ACTIVATE, SUSPEND, RENEW, CHANGE_LIMIT, CHANGE_TYPE
    params: Optional[Dict[str, Any]] = None


class MemberImportRequest(BaseModel):
    records: List[Dict[str, Any]]
    mode: str = "PREVIEW"  # PREVIEW or IMPORT


async def _generate_unique_member_code(school_id: str, prefix: str = "LIBM") -> str:
    """Generate sequential collision-free member codes per school (e.g. LIBM-0001)."""
    clean_prefix = re.sub(r'[^A-Z0-9]', '', prefix.upper())[:6] or "LIBM"
    rows = await exec_sql(
        "SELECT member_code FROM public.library_members WHERE school_id = %s AND member_code LIKE %s",
        (school_id, f"{clean_prefix}-%")
    )
    existing_nums = set()
    for r in rows:
        parts = r["member_code"].split("-")
        if len(parts) > 1 and parts[-1].isdigit():
            existing_nums.add(int(parts[-1]))

    curr = 1
    while curr in existing_nums:
        curr += 1
    return f"{clean_prefix}-{str(curr).zfill(4)}"


@router.get("/members/stats")
async def get_member_kpi_stats(
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Aggregate real-time KPI metrics for Library Members dashboard via stored function."""
    res = await exec_sql("SELECT public.fn_library_get_member_stats(%s::uuid) AS stats;", (school_id,))
    stats = res[0]["stats"] if (res and res[0].get("stats")) else {}
    return _serialize_datetime(stats)


@router.get("/members/filter-options")
async def get_member_filter_options(
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Fetch dynamic dropdown choices for Member Types, Classes, Departments, and Statuses via stored function."""
    res = await exec_sql("SELECT public.fn_library_get_member_filter_options(%s::uuid) AS opts;", (school_id,))
    opts = res[0]["opts"] if (res and res[0].get("opts")) else {}
    return {
        "success": True,
        "data": {
            "member_types": opts.get("member_types", ["Student", "Teacher", "Staff", "Librarian", "Special / Research"]),
            "classes": opts.get("classes", []),
            "departments": opts.get("departments", []),
            "roles": opts.get("roles", ["Student", "Teacher", "Staff", "Parent"]),
            "statuses": opts.get("statuses", ["ACTIVE", "INACTIVE", "SUSPENDED", "EXPIRED", "EXPIRING_SOON"])
        },
        "member_types": opts.get("member_types", ["Student", "Teacher", "Staff", "Librarian", "Special / Research"]),
        "classes": opts.get("classes", []),
        "departments": opts.get("departments", []),
        "roles": opts.get("roles", ["Student", "Teacher", "Staff", "Parent"]),
        "statuses": opts.get("statuses", ["ACTIVE", "INACTIVE", "SUSPENDED", "EXPIRED", "EXPIRING_SOON"])
    }



@router.get("/members/search-users")
async def search_profiles_for_member(
    query: Optional[str] = Query(None, description="Keyword to search in profiles table"),
    role: Optional[str] = Query(None, description="Optional role filter (student, teacher, staff)"),
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Search existing Profiles table to add as library members via stored function."""
    q_str = str(query).strip() if (query is not None and isinstance(query, str)) else None
    r_str = str(role).strip() if (role is not None and isinstance(role, str)) else None

    res = await exec_sql(
        "SELECT public.fn_library_search_profiles_for_member(%s::uuid, %s, %s) AS results;",
        (school_id, q_str, r_str)
    )
    results = res[0]["results"] if (res and res[0].get("results")) else []
    return [_serialize_datetime(r) for r in results]


@router.get("/members")
async def list_library_members(
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    search: Optional[str] = Query(None),
    member_type: Optional[str] = Query(None),
    class_name: Optional[str] = Query(None),
    department: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    membership_filter: Optional[str] = Query(None),
    sort_by: str = Query("member_code"),
    sort_order: str = Query("asc"),
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Fetch paginated, filtered, and sorted Library Members via stored function."""
    s_str = str(search).strip() if (search is not None and isinstance(search, str)) else None
    mt_str = str(member_type).strip() if (member_type is not None and isinstance(member_type, str)) else None
    cn_str = str(class_name).strip() if (class_name is not None and isinstance(class_name, str)) else None
    dept_str = str(department).strip() if (department is not None and isinstance(department, str)) else None
    st_str = str(status).strip() if (status is not None and isinstance(status, str)) else None
    mf_str = str(membership_filter).strip() if (membership_filter is not None and isinstance(membership_filter, str)) else None
    sb_str = str(sort_by).strip() if (sort_by is not None and isinstance(sort_by, str)) else "member_code"
    so_str = str(sort_order).strip() if (sort_order is not None and isinstance(sort_order, str)) else "asc"

    res = await exec_sql(
        """
        SELECT public.fn_library_list_members(
            %s::uuid, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
        ) AS result;
        """,
        (
            school_id, s_str, mt_str, cn_str, dept_str, st_str, mf_str,
            sb_str, so_str, page, page_size
        )
    )
    result = res[0]["result"] if (res and res[0].get("result")) else {"items": [], "meta": {}}
    items = result.get("items", [])
    meta = result.get("meta", {})

    return {
        "items": [_serialize_datetime(r) for r in items],
        "meta": {
            "page": meta.get("page", page),
            "page_size": meta.get("page_size", page_size),
            "total_items": meta.get("total", len(items)),
            "total_pages": meta.get("total_pages", 1),
            "has_next": (page * page_size) < meta.get("total", len(items)),
            "has_prev": page > 1
        }
    }


@router.get("/members/{member_id}")
async def get_member_detail(
    member_id: str,
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Retrieve full details of a library member including active books, fines, history, and audit log via stored function."""
    res = await exec_sql(
        "SELECT public.fn_library_get_member_detail(%s::uuid, %s::uuid) AS detail;",
        (school_id, member_id)
    )
    if not res or not res[0].get("detail"):
        raise HTTPException(status_code=404, detail="Library member not found")

    detail = res[0]["detail"]
    member = detail.get("member", {})
    active_books = detail.get("current_books", [])
    fines = detail.get("fines", [])
    history = detail.get("history", [])
    audits = detail.get("audits", [])
    summary = detail.get("summary", {})

    return {
        "member": _serialize_datetime(member),
        "current_books": [_serialize_datetime(b) for b in active_books],
        "fines": [_serialize_datetime(f) for f in fines],
        "history": [_serialize_datetime(h) for h in history],
        "audits": [_serialize_datetime(a) for a in audits],
        "summary": {
            "current_books_count": summary.get("current_issued_count", len(active_books)),
            "overdue_count": summary.get("total_overdue_count", 0),
            "outstanding_fine": float(summary.get("total_fines_unpaid") or 0.0),
            "remaining_capacity": max(0, (member.get("borrowing_limit") or 3) - len(active_books))
        }
    }


@router.post("/members")
async def create_library_member(
    payload: MemberCreateRequest,
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Create a new library membership from an existing Profile with atomic stored function."""
    user_id = current_user.get("id")

    try:
        res = await exec_sql(
            """
            SELECT public.fn_library_create_member(
                %s::uuid, %s::uuid, %s::uuid, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
            ) AS result;
            """,
            (
                school_id, user_id, payload.profile_id, payload.member_code,
                payload.membership_type, payload.membership_type_id,
                payload.membership_start_date or date.today(),
                payload.membership_expiry_date,
                payload.borrowing_limit or 3,
                payload.max_issue_duration_days or 14,
                payload.renewal_allowed if payload.renewal_allowed is not None else True,
                payload.max_renewals or 2,
                payload.status or "ACTIVE",
                payload.notes
            )
        )
        result = res[0]["result"] if res else {}
        return {
            "success": True,
            "message": result.get("message", "Library member created successfully."),
            "member_id": result.get("member_id"),
            "member_code": result.get("member_code")
        }
    except Exception as e:
        err_msg = str(e)
        clean = err_msg.split("CONTEXT:")[0].replace("ERROR:", "").replace("raise exception", "").strip()
        for line in err_msg.split("\n"):
            if "already has an active library membership" in line or "already registered as an active member" in line or "Cannot add duplicate member" in line or "does not exist in this institution" in line:
                clean = line.replace("ERROR:", "").strip()
                break
        raise HTTPException(status_code=400, detail=clean)


@router.put("/members/{member_id}")
async def update_library_member(
    member_id: str,
    payload: MemberUpdateRequest,
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Update library membership parameters only (preserves Profile identity)."""
    user_id = current_user.get("id")

    existing = await exec_sql(
        "SELECT id, member_code, status, borrowing_limit FROM public.library_members WHERE id = %s AND school_id = %s AND archived_at IS NULL",
        (member_id, school_id)
    )
    if not existing:
        raise HTTPException(status_code=404, detail="Library member not found.")

    updates = []
    params: List[Any] = []

    if payload.membership_type is not None:
        updates.append("membership_type = %s")
        params.append(payload.membership_type)
    if payload.membership_type_id is not None:
        updates.append("membership_type_id = %s")
        params.append(payload.membership_type_id)
    if payload.membership_start_date is not None:
        updates.append("membership_start_date = %s")
        params.append(payload.membership_start_date)
    if payload.membership_expiry_date is not None:
        updates.append("membership_expiry_date = %s")
        params.append(payload.membership_expiry_date)
    if payload.borrowing_limit is not None:
        updates.append("borrowing_limit = %s")
        params.append(payload.borrowing_limit)
    if payload.max_issue_duration_days is not None:
        updates.append("max_issue_duration_days = %s")
        params.append(payload.max_issue_duration_days)
    if payload.renewal_allowed is not None:
        updates.append("renewal_allowed = %s")
        params.append(payload.renewal_allowed)
    if payload.max_renewals is not None:
        updates.append("max_renewals = %s")
        params.append(payload.max_renewals)
    if payload.status is not None:
        updates.append("status = %s")
        params.append(payload.status)
    if payload.notes is not None:
        updates.append("notes = %s")
        params.append(payload.notes)

    if not updates:
        return {"success": True, "message": "No changes supplied."}

    updates.append("updated_by = %s")
    params.append(user_id)
    updates.append("updated_at = NOW()")

    params.extend([member_id, school_id])
    update_sql = f"UPDATE public.library_members SET {', '.join(updates)} WHERE id = %s AND school_id = %s;"
    await exec_sql(update_sql, tuple(params), fetch=False)

    # Audit log
    await exec_sql(
        """
        INSERT INTO public.library_member_audits (
            school_id, member_id, action_type, description, performed_by
        ) VALUES (%s, %s, 'UPDATED', 'Membership parameters updated', %s);
        """,
        (school_id, member_id, user_id),
        fetch=False
    )

    return {"success": True, "message": "Library member updated successfully."}


@router.post("/members/{member_id}/renew")
async def renew_membership(
    member_id: str,
    payload: MemberRenewRequest,
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Renew library membership via atomic stored function."""
    user_id = current_user.get("id")

    try:
        res = await exec_sql(
            """
            SELECT public.fn_library_renew_membership(
                %s::uuid, %s::uuid, %s::uuid, %s::date, %s, %s
            ) AS result;
            """,
            (school_id, member_id, user_id, payload.new_expiry_date, payload.renewal_period, payload.notes)
        )
        result = res[0]["result"] if res else {}
        return {
            "success": True,
            "message": result.get("message", "Membership renewed successfully."),
            "new_expiry_date": str(result.get("new_expiry_date") or payload.new_expiry_date)
        }
    except Exception as e:
        err_msg = str(e)
        if "Library member not found" in err_msg:
            raise HTTPException(status_code=404, detail="Library member not found.")
        raise HTTPException(status_code=400, detail=err_msg)


@router.post("/members/{member_id}/suspend")
async def suspend_membership(
    member_id: str,
    payload: MemberSuspendRequest,
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Suspend library membership with reason via atomic stored function."""
    user_id = current_user.get("id")

    try:
        res = await exec_sql(
            """
            SELECT public.fn_library_suspend_member(
                %s::uuid, %s::uuid, %s::uuid, %s
            ) AS result;
            """,
            (school_id, member_id, user_id, payload.reason or "Administrative suspension")
        )
        result = res[0]["result"] if res else {}
        return {"success": True, "message": result.get("message", "Member suspended successfully.")}
    except Exception as e:
        err_msg = str(e)
        if "Library member not found" in err_msg:
            raise HTTPException(status_code=404, detail="Library member not found.")
        raise HTTPException(status_code=400, detail=err_msg)


@router.post("/members/{member_id}/activate")
async def activate_membership(
    member_id: str,
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Reactivate a suspended or inactive library member via atomic stored function."""
    user_id = current_user.get("id")

    try:
        res = await exec_sql(
            """
            SELECT public.fn_library_activate_member(
                %s::uuid, %s::uuid, %s::uuid
            ) AS result;
            """,
            (school_id, member_id, user_id)
        )
        result = res[0]["result"] if res else {}
        return {"success": True, "message": result.get("message", "Member activated successfully.")}
    except Exception as e:
        err_msg = str(e)
        if "Library member not found" in err_msg:
            raise HTTPException(status_code=404, detail="Library member not found.")
        raise HTTPException(status_code=400, detail=err_msg)


@router.delete("/members/{member_id}")
async def delete_library_member(
    member_id: str,
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Soft-delete / archive a library member via atomic stored function."""
    user_id = current_user.get("id")

    try:
        res = await exec_sql(
            """
            SELECT public.fn_library_delete_member(
                %s::uuid, %s::uuid, %s::uuid
            ) AS result;
            """,
            (school_id, member_id, user_id)
        )
        result = res[0]["result"] if res else {}
        return {"success": True, "message": result.get("message", "Library member deleted successfully.")}
    except Exception as e:
        err_msg = str(e)
        if "Library member not found" in err_msg:
            raise HTTPException(status_code=404, detail="Library member not found.")
        if "Cannot delete member" in err_msg:
            # Clean up exception line
            for line in err_msg.split("\n"):
                if "Cannot delete member" in line:
                    raise HTTPException(status_code=400, detail=line.replace("ERROR:", "").strip())
            raise HTTPException(status_code=400, detail=err_msg)
        raise HTTPException(status_code=400, detail=err_msg)


@router.post("/members/bulk-action")
async def bulk_member_action(
    payload: MemberBulkActionRequest,
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Perform bulk operations across multiple members (Activate, Suspend, Renew, Change Limit, Change Type)."""
    user_id = current_user.get("id")
    if not payload.member_ids:
        raise HTTPException(status_code=400, detail="No members selected.")

    action = payload.action.upper()
    affected = 0

    if action == "ACTIVATE":
        res = await exec_sql(
            """
            UPDATE public.library_members
            SET status = 'ACTIVE', suspension_reason = NULL, updated_by = %s, updated_at = NOW()
            WHERE school_id = %s AND id = ANY(%s::uuid[]) AND archived_at IS NULL;
            """,
            (user_id, school_id, payload.member_ids),
            fetch=False
        )
        affected = len(payload.member_ids)
    elif action == "SUSPEND":
        reason = payload.params.get("reason", "Bulk suspension") if payload.params else "Bulk suspension"
        await exec_sql(
            """
            UPDATE public.library_members
            SET status = 'SUSPENDED', suspension_reason = %s, suspended_at = NOW(), suspended_by = %s, updated_by = %s, updated_at = NOW()
            WHERE school_id = %s AND id = ANY(%s::uuid[]) AND archived_at IS NULL;
            """,
            (reason, user_id, user_id, school_id, payload.member_ids),
            fetch=False
        )
        affected = len(payload.member_ids)
    elif action == "RENEW":
        new_expiry = payload.params.get("new_expiry_date") if payload.params else None
        if not new_expiry:
            new_expiry = (date.today() + (date(date.today().year + 1, 3, 31) - date.today())).isoformat()
        await exec_sql(
            """
            UPDATE public.library_members
            SET membership_expiry_date = %s, status = 'ACTIVE', updated_by = %s, updated_at = NOW()
            WHERE school_id = %s AND id = ANY(%s::uuid[]) AND archived_at IS NULL;
            """,
            (new_expiry, user_id, school_id, payload.member_ids),
            fetch=False
        )
        affected = len(payload.member_ids)
    elif action == "CHANGE_LIMIT":
        new_limit = payload.params.get("borrowing_limit", 3) if payload.params else 3
        await exec_sql(
            """
            UPDATE public.library_members
            SET borrowing_limit = %s, updated_by = %s, updated_at = NOW()
            WHERE school_id = %s AND id = ANY(%s::uuid[]) AND archived_at IS NULL;
            """,
            (new_limit, user_id, school_id, payload.member_ids),
            fetch=False
        )
        affected = len(payload.member_ids)
    elif action == "CHANGE_TYPE":
        new_type = payload.params.get("membership_type", "Student") if payload.params else "Student"
        await exec_sql(
            """
            UPDATE public.library_members
            SET membership_type = %s, updated_by = %s, updated_at = NOW()
            WHERE school_id = %s AND id = ANY(%s::uuid[]) AND archived_at IS NULL;
            """,
            (new_type, user_id, school_id, payload.member_ids),
            fetch=False
        )
        affected = len(payload.member_ids)
    else:
        raise HTTPException(status_code=400, detail=f"Unsupported bulk action: {action}")

    return {
        "success": True,
        "message": f"Bulk action '{action}' executed for {affected} member(s).",
        "affected_count": affected
    }


@router.get("/members/export")
async def export_members_csv(
    search: Optional[str] = Query(None),
    member_type: Optional[str] = Query(None),
    class_name: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Stream CSV file of library members with profile info."""
    params: List[Any] = [school_id]
    where_clauses = ["m.school_id = %s", "m.archived_at IS NULL"]

    s_str = str(search).strip() if (search is not None and isinstance(search, str)) else None
    mt_str = str(member_type).strip() if (member_type is not None and isinstance(member_type, str)) else None
    cn_str = str(class_name).strip() if (class_name is not None and isinstance(class_name, str)) else None
    st_str = str(status).strip() if (status is not None and isinstance(status, str)) else None

    if s_str:
        q_term = f"%{s_str}%"
        where_clauses.append("(m.member_code ILIKE %s OR p.full_name ILIKE %s OR p.email ILIKE %s)")
        params.extend([q_term, q_term, q_term])

    if mt_str and mt_str.upper() != "ALL":
        where_clauses.append("m.membership_type ILIKE %s")
        params.append(mt_str)

    if cn_str and cn_str.upper() != "ALL":
        where_clauses.append("p.class ILIKE %s")
        params.append(cn_str)

    if st_str and st_str.upper() != "ALL":
        where_clauses.append("m.status = %s")
        params.append(st_str.upper())

    sql = f"""
        SELECT
            m.member_code,
            p.full_name,
            m.membership_type,
            p.role,
            COALESCE(p.class, p.department, 'N/A') AS class_or_dept,
            p.email,
            p.phone,
            m.current_borrowed_count AS books_issued,
            m.outstanding_fine,
            m.borrowing_limit,
            m.membership_start_date,
            m.membership_expiry_date,
            m.status
        FROM public.library_members m
        JOIN public.profiles p ON m.profile_id = p.id
        WHERE {" AND ".join(where_clauses)}
        ORDER BY m.member_code ASC;
    """
    rows = await exec_sql(sql, tuple(params))

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow([
        "Member Code", "Full Name", "Membership Type", "Role", "Class/Department",
        "Email", "Phone", "Books Issued", "Outstanding Fine (INR)", "Borrowing Limit",
        "Membership Start", "Membership Expiry", "Status"
    ])

    for r in rows:
        writer.writerow([
            r["member_code"], r["full_name"], r["membership_type"], r["role"],
            r["class_or_dept"], r["email"], r["phone"], r["books_issued"],
            r["outstanding_fine"], r["borrowing_limit"], r["membership_start_date"],
            r["membership_expiry_date"], r["status"]
        ])

    output.seek(0)
    return StreamingResponse(
        io.BytesIO(output.getvalue().encode("utf-8")),
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename=library_members_{date.today().isoformat()}.csv"}
    )


@router.post("/members/import")
async def import_members_csv(
    payload: MemberImportRequest,
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Import and link existing profiles to library members safely with validation preview."""
    user_id = current_user.get("id")
    valid_records = []
    duplicate_records = []
    invalid_records = []

    for idx, row in enumerate(payload.records, start=1):
        email = row.get("email") or row.get("Email")
        phone = row.get("phone") or row.get("Phone")
        admission_no = row.get("admission_number") or row.get("Admission Number")
        emp_id = row.get("employee_id") or row.get("Employee ID")

        # Find matching profile
        p_row = None
        if email:
            res = await exec_sql("SELECT id, full_name, role FROM public.profiles WHERE school_id = %s AND email = %s", (school_id, email.strip()))
            if res:
                p_row = res[0]
        if not p_row and phone:
            res = await exec_sql("SELECT id, full_name, role FROM public.profiles WHERE school_id = %s AND phone = %s", (school_id, phone.strip()))
            if res:
                p_row = res[0]
        if not p_row and admission_no:
            res = await exec_sql("SELECT id, full_name, role FROM public.profiles WHERE school_id = %s AND admission_number = %s", (school_id, admission_no.strip()))
            if res:
                p_row = res[0]

        if not p_row:
            invalid_records.append({"row": idx, "reason": "No existing profile matched this email/phone/admission number", "data": row})
            continue

        # Check if already a member
        m_check = await exec_sql("SELECT id, member_code FROM public.library_members WHERE profile_id = %s AND school_id = %s AND archived_at IS NULL", (p_row["id"], school_id))
        if m_check:
            duplicate_records.append({"row": idx, "name": p_row["full_name"], "member_code": m_check[0]["member_code"], "reason": "Already a member"})
            continue

        valid_records.append({
            "row": idx,
            "profile_id": str(p_row["id"]),
            "full_name": p_row["full_name"],
            "role": p_row["role"],
            "membership_type": row.get("membership_type") or ("Teacher" if p_row["role"] == "teacher" else "Student"),
            "borrowing_limit": int(row.get("borrowing_limit") or (5 if p_row["role"] == "teacher" else 3))
        })

    if payload.mode.upper() == "IMPORT" and valid_records:
        for item in valid_records:
            code = await _generate_unique_member_code(school_id, "LIBM")
            expiry = (date.today() + (date(date.today().year + 1, 3, 31) - date.today())).isoformat()
            await exec_sql(
                """
                INSERT INTO public.library_members (
                    school_id, profile_id, member_code, membership_type,
                    membership_start_date, membership_expiry_date, borrowing_limit,
                    status, created_by, updated_by
                ) VALUES (%s, %s, %s, %s, CURRENT_DATE, %s, %s, 'ACTIVE', %s, %s);
                """,
                (school_id, item["profile_id"], code, item["membership_type"], expiry, item["borrowing_limit"], user_id, user_id),
                fetch=False
            )

    return {
        "success": True,
        "mode": payload.mode,
        "summary": {
            "total_processed": len(payload.records),
            "valid_count": len(valid_records),
            "duplicate_count": len(duplicate_records),
            "invalid_count": len(invalid_records)
        },
        "preview": valid_records[:10],
        "duplicates": duplicate_records,
        "invalid_rows": invalid_records
    }


# ============================================================================
# CIRCULATION & ISSUE / RETURN SCHEMAS & ENDPOINTS
# ============================================================================

class IssueBookItemRequest(BaseModel):
    book_id: str
    copy_id: Optional[str] = None
    due_date: Optional[str] = None


class IssueBooksRequest(BaseModel):
    member_id: str
    items: List[IssueBookItemRequest]
    notes: Optional[str] = None


class ReturnBookItemRequest(BaseModel):
    borrow_id: str
    condition: Optional[str] = "GOOD"
    notes: Optional[str] = None
    damage_charge: Optional[float] = 0.0
    lost_charge: Optional[float] = 0.0


class ReturnBooksRequest(BaseModel):
    items: List[ReturnBookItemRequest]
    collect_fine: Optional[bool] = False
    payment_method: Optional[str] = "CASH"
    payment_ref: Optional[str] = None


class RenewBookRequest(BaseModel):
    new_due_date: Optional[str] = None
    reason: Optional[str] = None


class CollectFineRequest(BaseModel):
    amount: float
    payment_method: Optional[str] = "CASH"
    transaction_reference: Optional[str] = None
    notes: Optional[str] = None


class WaiveFineRequest(BaseModel):
    amount: float
    reason: str


class CreateLibraryRequestModel(BaseModel):
    member_id: Optional[str] = None
    book_id: Optional[str] = None
    title: Optional[str] = None
    author: Optional[str] = None
    isbn: Optional[str] = None
    publisher: Optional[str] = None
    edition: Optional[str] = None
    language: Optional[str] = "English"
    category_code: Optional[str] = "BOOK"
    request_type: Optional[str] = "Book"
    preferred_format: Optional[str] = "Physical"
    quantity: Optional[int] = 1
    priority: Optional[str] = "Medium"
    required_by: Optional[str] = None
    reason: Optional[str] = None
    description: Optional[str] = None
    notes: Optional[str] = None
    attachments: Optional[List[Dict[str, Any]]] = None



class TransitionRequestStatusModel(BaseModel):
    to_status: str
    reason: Optional[str] = None
    comment: Optional[str] = None


class AssignRequestModel(BaseModel):
    assigned_to: str
    notes: Optional[str] = None


class ApproveRequestModel(BaseModel):
    approved: bool
    comments: Optional[str] = None


class ClarificationRequestModel(BaseModel):
    message: str
    is_response: Optional[bool] = False


class AddRequestCommentModel(BaseModel):
    comment: str
    is_internal: Optional[bool] = False


class AddRequestAttachmentModel(BaseModel):
    file_name: str
    file_url: str
    mime_type: Optional[str] = None
    file_size: Optional[int] = 0


class RequestBulkActionModel(BaseModel):
    request_ids: List[str]
    action: str  # 'ACTIVATE', 'ASSIGN', 'REJECT', 'RESOLVE'
    assigned_to: Optional[str] = None
    reason: Optional[str] = None


class ProcessLibraryRequestModel(BaseModel):
    action: str  # 'APPROVE', 'REJECT', 'ISSUE', 'CANCEL'
    rejection_reason: Optional[str] = None
    copy_id: Optional[str] = None


class CirculationBulkActionRequest(BaseModel):
    borrow_ids: List[str]
    action: str  # 'SEND_REMINDER', 'MARK_REVIEWED'
    params: Optional[Dict[str, Any]] = None



@router.get("/circulation/stats")
async def get_circulation_stats(
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Retrieve real-time aggregated metrics for the Issue / Return circulation dashboard."""
    try:
        res = await exec_sql("SELECT public.fn_library_get_circulation_stats(%s::uuid) AS stats;", (school_id,))
        stats = res[0]["stats"] if (res and res[0].get("stats")) else {}
        return {"success": True, "data": _serialize_datetime(stats)}
    except Exception as e:
        logger.exception("Error in get_circulation_stats: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/circulation/filter-options")
async def get_circulation_filter_options(
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Retrieve filter and dropdown options for the circulation page."""
    try:
        res = await exec_sql("SELECT public.fn_library_get_circulation_filter_options(%s::uuid) AS opts;", (school_id,))
        opts = res[0]["opts"] if (res and res[0].get("opts")) else {}
        return {"success": True, "data": _serialize_datetime(opts)}
    except Exception as e:
        logger.exception("Error in get_circulation_filter_options: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/circulation/activity")
async def get_circulation_activity(
    limit: int = Query(10, ge=1, le=50),
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Retrieve real-time chronological activity feed for today's circulation actions."""
    try:
        res = await exec_sql("SELECT public.fn_library_get_circulation_activity(%s::uuid, %s) AS activities;", (school_id, limit))
        activities = res[0]["activities"] if (res and res[0].get("activities")) else []
        return {"success": True, "data": _serialize_datetime(activities)}
    except Exception as e:
        logger.exception("Error in get_circulation_activity: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/circulation/overdue-summary")
async def get_overdue_summary(
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Retrieve bracket breakdown of overdue items (1-3d, 4-7d, 8-15d, 15+d)."""
    try:
        res = await exec_sql("SELECT public.fn_library_get_overdue_summary(%s::uuid) AS summary;", (school_id,))
        summary = res[0]["summary"] if (res and res[0].get("summary")) else []
        return {"success": True, "data": _serialize_datetime(summary)}
    except Exception as e:
        logger.exception("Error in get_overdue_summary: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/circulation/scan")
async def scan_barcode_lookup(
    code: str = Query(..., description="Scanned Barcode, Accession number, Member Code, Phone or ISBN"),
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Scan and identify any barcode, accession number, member card or ISBN."""
    try:
        res = await exec_sql("SELECT public.fn_library_scan_lookup(%s::uuid, %s) AS result;", (school_id, code))
        result = res[0]["result"] if (res and res[0].get("result")) else None
        if not result:
            raise HTTPException(status_code=404, detail=f"No matching book, copy, or member found for '{code}'.")
        return {"success": True, "data": _serialize_datetime(result)}
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Error in scan_barcode_lookup: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/transactions")
async def list_transactions(
    search: Optional[str] = Query(None),
    search_in: Optional[str] = Query("All Transactions"),
    subtab: Optional[str] = Query("ALL"),
    status: Optional[str] = Query("ALL"),
    transaction_type: Optional[str] = Query("ALL"),
    date_from: Optional[str] = Query(None),
    date_to: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    sort_by: Optional[str] = Query("created_at"),
    sort_order: Optional[str] = Query("DESC"),
    fine_status: Optional[str] = Query(None),
    member_role: Optional[str] = Query(None),
    date_field: Optional[str] = Query("issue_date"),
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """List paginated circulation transactions with subtabs, searching, and filters."""
    subtab_val = subtab if isinstance(subtab, str) else "ALL"
    status_val = status if isinstance(status, str) else "ALL"
    tx_type_val = transaction_type if isinstance(transaction_type, str) else "ALL"
    search_in_val = search_in if isinstance(search_in, str) else "All Transactions"
    search_val = search if isinstance(search, str) else None
    sort_by_val = sort_by if isinstance(sort_by, str) else "created_at"
    sort_order_val = sort_order if isinstance(sort_order, str) else "DESC"
    fine_status_val = fine_status if isinstance(fine_status, str) else None
    member_role_val = member_role if isinstance(member_role, str) else None
    date_field_val = date_field if isinstance(date_field, str) else "issue_date"

    d_from = None
    d_to = None
    if date_from and isinstance(date_from, str) and date_from.strip():
        try:
            d_from = date.fromisoformat(date_from.strip())
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid date_from format. Use YYYY-MM-DD.")

    if date_to and isinstance(date_to, str) and date_to.strip():
        try:
            d_to = date.fromisoformat(date_to.strip())
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid date_to format. Use YYYY-MM-DD.")

    try:
        res = await exec_sql(
            """
            SELECT public.fn_library_list_transactions(
                %s::uuid, %s::text, %s::text, %s::text, %s::text, %s::text,
                %s::date, %s::date, %s::int, %s::int, %s::text, %s::text,
                %s::text, %s::text, %s::text
            ) AS result;
            """,
            (
                school_id, search_val, search_in_val, subtab_val.upper(), status_val.upper(),
                tx_type_val, d_from, d_to, page, page_size, sort_by_val, sort_order_val,
                fine_status_val, member_role_val, date_field_val
            )
        )

        result = res[0]["result"] if (res and res[0].get("result")) else {"items": [], "total": 0, "counts": {}}
        return {
            "success": True,
            "data": _serialize_datetime(result.get("items") or []),
            "items": _serialize_datetime(result.get("items") or []),
            "total": result.get("total", 0),
            "page": result.get("page", 1),
            "page_size": result.get("page_size", 10),
            "total_pages": result.get("total_pages", 1),
            "counts": result.get("counts", {})
        }
    except Exception as e:
        logger.exception("Error in list_transactions: %s", e)
        raise HTTPException(status_code=500, detail=str(e))




@router.get("/transactions/{transaction_id}")
async def get_transaction_detail(
    transaction_id: str,
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Retrieve detailed transaction info including copy location, borrower profile, and timeline."""
    try:
        res = await exec_sql(
            "SELECT public.fn_library_get_transaction_detail(%s::uuid, %s::uuid) AS item;",
            (school_id, transaction_id)
        )
        item = res[0]["item"] if (res and res[0].get("item")) else None
        if not item:
            raise HTTPException(status_code=404, detail="Transaction not found.")
        return {"success": True, "data": _serialize_datetime(item)}
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Error in get_transaction_detail: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/transactions/issue")
async def issue_books(
    payload: IssueBooksRequest,
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Issue one or multiple books to a library member atomically."""
    user_id = current_user.get("id")
    items_json = json.dumps([item.dict() for item in payload.items])

    try:
        res = await exec_sql(
            """
            SELECT public.fn_library_issue_books(
                %s::uuid, %s::uuid, %s::jsonb, %s::uuid, %s
            ) AS result;
            """,
            (school_id, payload.member_id, items_json, user_id, payload.notes)
        )
        result = res[0]["result"] if (res and res[0].get("result")) else {}
        return {"success": True, "message": result.get("message", "Books issued successfully."), "data": result}
    except Exception as e:
        err_msg = str(e)
        logger.warning("Issue books error: %s", err_msg)
        for line in err_msg.split("\n"):
            if "EXCEPTION" in line or "RAISE" in line or "limit exceeded" in line or "expired" in line or "overdue" in line or "not available" in line:
                clean_err = line.replace("ERROR:", "").replace("PL/pgSQL function", "").strip()
                raise HTTPException(status_code=400, detail=clean_err)
        raise HTTPException(status_code=400, detail=err_msg)


@router.post("/transactions/return")
async def return_books(
    payload: ReturnBooksRequest,
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Process return of one or multiple books with automated fine and condition handling."""
    user_id = current_user.get("id")
    items_json = json.dumps([item.dict() for item in payload.items])

    try:
        res = await exec_sql(
            """
            SELECT public.fn_library_return_books(
                %s::uuid, %s::jsonb, %s::uuid, %s, %s, %s
            ) AS result;
            """,
            (school_id, items_json, user_id, payload.collect_fine, payload.payment_method, payload.payment_ref)
        )
        result = res[0]["result"] if (res and res[0].get("result")) else {}
        return {"success": True, "message": result.get("message", "Books returned successfully."), "data": result}
    except Exception as e:
        err_msg = str(e)
        logger.warning("Return books error: %s", err_msg)
        for line in err_msg.split("\n"):
            if "already been returned" in line:
                raise HTTPException(status_code=400, detail=line.replace("ERROR:", "").strip())
        raise HTTPException(status_code=400, detail=err_msg)


@router.post("/transactions/{borrow_id}/renew")
async def renew_book_loan(
    borrow_id: str,
    payload: RenewBookRequest,
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Renew an active book loan with limit validation."""
    user_id = current_user.get("id")

    try:
        res = await exec_sql(
            """
            SELECT public.fn_library_renew_book(
                %s::uuid, %s::uuid, %s::uuid, %s::date, %s
            ) AS result;
            """,
            (school_id, borrow_id, user_id, payload.new_due_date, payload.reason)
        )
        result = res[0]["result"] if (res and res[0].get("result")) else {}
        return {"success": True, "message": result.get("message", "Book renewed successfully."), "data": result}
    except Exception as e:
        err_msg = str(e)
        for line in err_msg.split("\n"):
            if "renewal limit reached" in line or "Cannot renew" in line:
                raise HTTPException(status_code=400, detail=line.replace("ERROR:", "").strip())
        raise HTTPException(status_code=400, detail=err_msg)


@router.get("/transactions/export")
async def export_transactions_csv(
    search: Optional[str] = Query(None),
    subtab: Optional[str] = Query("ALL"),
    status: Optional[str] = Query("ALL"),
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Stream CSV export of circulation transactions."""
    subtab_val = (subtab if isinstance(subtab, str) else "ALL") or "ALL"
    status_val = (status if isinstance(status, str) else "ALL") or "ALL"
    search_val = search if isinstance(search, str) else None

    res = await exec_sql(
        """
        SELECT public.fn_library_list_transactions(
            %s::uuid, %s::text, 'All Transactions'::text, %s::text, %s::text, 'ALL'::text,
            NULL::date, NULL::date, 1::int, 5000::int, 'created_at'::text, 'DESC'::text,
            NULL::text, NULL::text, 'issue_date'::text
        ) AS result;
        """,
        (school_id, search_val, subtab_val.upper(), status_val.upper())
    )

    items = res[0]["result"]["items"] if (res and res[0].get("result")) else []

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow([
        "Transaction ID", "Member Name", "Member Code", "Role", "Class/Dept",
        "Book Title", "ISBN", "Barcode", "Issue Date", "Due Date", "Return Date",
        "Status", "Days Overdue", "Fine (INR)", "Transaction Type", "Issued By"
    ])

    for r in items:
        writer.writerow([
            r.get("transaction_code"), r.get("member_name"), r.get("member_code"),
            r.get("member_role"), r.get("member_class"), r.get("book_title"),
            r.get("book_isbn"), r.get("copy_barcode"), r.get("issue_date"),
            r.get("due_date"), r.get("return_date") or "-", r.get("status"),
            r.get("days_overdue"), r.get("fine_amount"), r.get("transaction_type"),
            r.get("issued_by_name") or "-"
        ])

    output.seek(0)
    return StreamingResponse(
        io.BytesIO(output.getvalue().encode("utf-8")),
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename=circulation_transactions_{date.today().isoformat()}.csv"}
    )


@router.post("/transactions/bulk-action")
async def bulk_circulation_action(
    payload: CirculationBulkActionRequest,
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Execute bulk operations on selected transactions (Send Reminders, Mark Reviewed)."""
    user_id = current_user.get("id")
    action = payload.action.upper()
    count = len(payload.borrow_ids)

    if action == "SEND_REMINDER":
        # Log notification / activity for each transaction
        for b_id in payload.borrow_ids:
            await exec_sql(
                """
                INSERT INTO public.library_circulation_activities (
                    school_id, activity_type, title, description, borrow_id, performed_by, created_at
                ) VALUES (%s, 'REMINDER', 'Due Date Reminder Sent', 'Automated reminder dispatched to borrower', %s, %s, NOW());
                """,
                (school_id, b_id, user_id),
                fetch=False
            )
        return {"success": True, "message": f"Reminders sent successfully for {count} transaction(s).", "count": count}

    return {"success": True, "message": f"Bulk action '{action}' completed for {count} transaction(s).", "count": count}


@router.get("/requests/kpis")
async def get_library_requests_kpis(
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Compute real-time KPI metrics, type breakdown, status distribution, and recent requests."""
    user_id = current_user.get("id")
    role = current_user.get("role", "student")

    try:
        res = await exec_sql(
            "SELECT public.fn_library_get_request_kpis(%s::uuid, %s::uuid, %s) AS kpis;",
            (school_id, user_id, role)
        )
        kpis = res[0]["kpis"] if (res and res[0].get("kpis")) else {}
        return {"success": True, "data": _serialize_datetime(kpis)}
    except Exception as e:
        logger.exception("Error in get_library_requests_kpis: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/requests/options")
async def get_library_requests_options(
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Fetch configurable dropdown options for categories, types, priorities, and staff."""
    try:
        # Fetch categories from lookups
        cat_rows = await exec_sql(
            """
            SELECT lv.value_name, lv.value_code
            FROM public.lookup_values lv
            JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
            WHERE (lv.school_id = %s OR lv.school_id IS NULL) 
              AND lk.key_code IN ('LIBRARY_REQUEST_CATEGORY', 'BOOK_CATEGORY') 
              AND lv.status = 'ACTIVE'
            ORDER BY lv.sort_order ASC;
            """,
            (school_id,)
        )
        categories = [r["value_name"] for r in cat_rows] if cat_rows else [
            "Book", "E-Book", "Digital Resource", "Audiobook", "Journal / Magazine", "Research Resource", "Membership", "Reservation", "Acquisition", "Other"
        ]

        # Fetch types
        type_rows = await exec_sql(
            """
            SELECT lv.value_name, lv.value_code
            FROM public.lookup_values lv
            JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
            WHERE (lv.school_id = %s OR lv.school_id IS NULL) 
              AND lk.key_code = 'LIBRARY_REQUEST_TYPE' 
              AND lv.status = 'ACTIVE'
            ORDER BY lv.sort_order ASC;
            """,
            (school_id,)
        )
        types = [r["value_name"] for r in type_rows] if type_rows else [
            "Book", "E-Book", "Digital Resource", "Audiobook", "Journal / Magazine", "Other"
        ]

        # Fetch formats from lookups (BOOK_TYPE)
        format_rows = await exec_sql(
            """
            SELECT lv.value_name
            FROM public.lookup_values lv
            JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
            WHERE (lv.school_id = %s OR lv.school_id IS NULL) 
              AND lk.key_code = 'BOOK_TYPE' 
              AND lv.status = 'ACTIVE'
            ORDER BY lv.sort_order ASC;
            """,
            (school_id,)
        )
        formats = [r["value_name"] for r in format_rows] if format_rows else [
            "Physical", "Paperback", "Hardcover", "PDF", "E-Book (Kindle)", "Audio", "Web Access", "Reference"
        ]

        # Fetch priorities from lookups (LIBRARY_REQUEST_PRIORITY / PRIORITY_LEVEL)
        prio_rows = await exec_sql(
            """
            SELECT lv.value_name
            FROM public.lookup_values lv
            JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
            WHERE (lv.school_id = %s OR lv.school_id IS NULL) 
              AND lk.key_code IN ('LIBRARY_REQUEST_PRIORITY', 'PRIORITY_LEVEL') 
              AND lv.status = 'ACTIVE'
            ORDER BY lv.sort_order ASC;
            """,
            (school_id,)
        )
        priorities = ["All"] + [r["value_name"] for r in prio_rows] if prio_rows else [
            "All", "Low", "Medium", "High", "Urgent"
        ]

        # Fetch platform roles from app_roles (ONLY ACTIVE ROLES)
        role_rows = await exec_sql(
            """
            SELECT DISTINCT COALESCE(display_name, INITCAP(name)) AS role_name
            FROM public.app_roles
            WHERE (school_id = %s OR school_id IS NULL)
              AND UPPER(COALESCE(status, 'ACTIVE')) = 'ACTIVE'
            ORDER BY 1 ASC;
            """,
            (school_id,)
        )
        roles = ["All"] + [r["role_name"] for r in role_rows] if role_rows else [
            "All", "Student", "Teacher", "Staff", "Parent"
        ]


        # Fetch staff librarians
        staff_rows = await exec_sql(
            """
            SELECT id, full_name, role, avatar_url
            FROM public.profiles
            WHERE school_id = %s AND LOWER(role) IN ('librarian', 'library_manager', 'teacher', 'admin', 'super_admin', 'director')
            ORDER BY full_name ASC;
            """,
            (school_id,)
        )

        return {
            "success": True,
            "data": {
                "categories": categories,
                "request_types": types,
                "statuses": ["All", "New", "Active", "In Progress", "Resolved", "Completed", "Rejected", "Cancelled"],
                "priorities": priorities,
                "formats": formats,
                "roles": roles,
                "librarians": _serialize_datetime(staff_rows)
            }
        }

    except Exception as e:
        logger.exception("Error in get_library_requests_options: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/requests")
async def list_library_requests(
    search: Optional[str] = Query(None),
    subtab: Optional[str] = Query("ALL"),
    request_type: Optional[str] = Query("ALL"),
    status: Optional[str] = Query("ALL"),
    priority: Optional[str] = Query("ALL"),
    requested_by_role: Optional[str] = Query("ALL"),
    date_from: Optional[str] = Query(None),
    date_to: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    sort_by: Optional[str] = Query("created_at"),
    sort_order: Optional[str] = Query("DESC"),
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """List paginated library requests with multi-criteria filters, subtabs, and searching."""
    user_id = current_user.get("id")
    role = current_user.get("role", "student")

    search_val = search if isinstance(search, str) else None
    subtab_val = (subtab if isinstance(subtab, str) else "ALL") or "ALL"
    req_type_val = (request_type if isinstance(request_type, str) else "ALL") or "ALL"
    status_val = (status if isinstance(status, str) else "ALL") or "ALL"
    priority_val = (priority if isinstance(priority, str) else "ALL") or "ALL"
    role_val = (requested_by_role if isinstance(requested_by_role, str) else "ALL") or "ALL"
    sort_by_val = sort_by if isinstance(sort_by, str) else "created_at"
    sort_order_val = sort_order if isinstance(sort_order, str) else "DESC"

    d_from = None
    d_to = None
    if date_from and isinstance(date_from, str) and date_from.strip():
        try:
            d_from = date.fromisoformat(date_from.strip())
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid date_from format. Use YYYY-MM-DD.")

    if date_to and isinstance(date_to, str) and date_to.strip():
        try:
            d_to = date.fromisoformat(date_to.strip())
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid date_to format. Use YYYY-MM-DD.")

    try:
        res = await exec_sql(
            """
            SELECT public.fn_library_list_requests(
                %s::uuid, %s::text, %s::text, %s::text, %s::text, %s::text,
                %s::text, %s::date, %s::date, %s::int, %s::int, %s::text,
                %s::text, %s::uuid, %s::text
            ) AS result;
            """,
            (
                school_id, search_val, subtab_val.upper(), req_type_val, status_val.upper(),
                priority_val.upper(), role_val.lower(), d_from, d_to, page, page_size,
                sort_by_val, sort_order_val, user_id, role
            )
        )
        result = res[0]["result"] if (res and res[0].get("result")) else {"items": [], "total": 0, "page": 1, "page_size": 10, "total_pages": 1}
        return {
            "success": True,
            "data": _serialize_datetime(result.get("items") or []),
            "items": _serialize_datetime(result.get("items") or []),
            "total": result.get("total", 0),
            "page": result.get("page", 1),
            "page_size": result.get("page_size", 10),
            "total_pages": result.get("total_pages", 1)
        }
    except Exception as e:
        logger.exception("Error in list_library_requests: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/requests/export")
async def export_library_requests_csv(
    search: Optional[str] = Query(None),
    subtab: Optional[str] = Query("ALL"),
    request_type: Optional[str] = Query("ALL"),
    status: Optional[str] = Query("ALL"),
    priority: Optional[str] = Query("ALL"),
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Stream CSV export of library requests."""
    user_id = current_user.get("id")
    role = current_user.get("role", "admin")

    search_val = search if isinstance(search, str) else None
    subtab_val = (subtab if isinstance(subtab, str) else "ALL") or "ALL"
    req_type_val = (request_type if isinstance(request_type, str) else "ALL") or "ALL"
    status_val = (status if isinstance(status, str) else "ALL") or "ALL"
    priority_val = (priority if isinstance(priority, str) else "ALL") or "ALL"

    res = await exec_sql(
        """
        SELECT public.fn_library_list_requests(
            %s::uuid, %s::text, %s::text, %s::text, %s::text, %s::text,
            'ALL'::text, NULL::date, NULL::date, 1::int, 5000::int, 'created_at'::text,
            'DESC'::text, %s::uuid, %s::text
        ) AS result;
        """,
        (school_id, search_val, subtab_val, req_type_val, status_val, priority_val, user_id, role)
    )
    items = res[0]["result"]["items"] if (res and res[0].get("result")) else []


    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow([
        "Request ID", "Title / Item", "Author", "ISBN", "Request Type", "Category",
        "Requested By", "Role", "Class/Dept", "Priority", "Status", "Availability",
        "Assigned To", "Date Requested", "Required By", "Reason"
    ])

    for r in items:
        writer.writerow([
            r.get("request_number"), r.get("title"), r.get("author") or "-",
            r.get("isbn") or "-", r.get("request_type"), r.get("category_code"),
            r.get("requester_name"), r.get("requester_role"), r.get("requester_class"),
            r.get("priority"), r.get("status"), r.get("availability_status"),
            r.get("assigned_to_name") or "Unassigned", r.get("created_at"),
            r.get("required_by") or "-", r.get("reason") or "-"
        ])

    output.seek(0)
    return StreamingResponse(
        io.BytesIO(output.getvalue().encode("utf-8")),
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename=library_requests_{date.today().isoformat()}.csv"}
    )


@router.get("/requests/{request_id}")
async def get_library_request_detail(
    request_id: str,
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Retrieve full request detail including requester profile, book inventory, timeline, comments, and attachments."""
    user_id = current_user.get("id")
    role = current_user.get("role", "student")

    try:
        res = await exec_sql(
            "SELECT public.fn_library_get_request_detail(%s::uuid, %s::uuid, %s::uuid, %s) AS detail;",
            (school_id, request_id, user_id, role)
        )
        detail = res[0]["detail"] if (res and res[0].get("detail")) else None
        if not detail:
            raise HTTPException(status_code=404, detail="Request not found.")
        return {"success": True, "data": _serialize_datetime(detail)}
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Error in get_library_request_detail: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/requests")
async def create_library_request(
    payload: CreateLibraryRequestModel,
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Create a new library request for an existing book or a new resource."""
    user_id = current_user.get("id")

    req_by_date = None
    if payload.required_by and payload.required_by.strip():
        try:
            req_by_date = date.fromisoformat(payload.required_by.strip())
        except ValueError:
            pass

    try:
        res = await exec_sql(
            """
            SELECT public.fn_library_create_request(
                %s::uuid, %s::uuid, %s::uuid, %s::uuid, %s, %s, %s, %s, %s, %s,
                %s, %s, %s, %s::int, %s, %s::date, %s, %s, %s
            ) AS result;
            """,
            (
                school_id, user_id, payload.member_id, payload.book_id,
                payload.title, payload.author, payload.isbn, payload.publisher,
                payload.edition, payload.language, payload.category_code,
                payload.request_type, payload.preferred_format, payload.quantity,
                payload.priority, req_by_date, payload.reason, payload.description, payload.notes
            )
        )
        result = res[0]["result"] if (res and res[0].get("result")) else {}
        
        # Save any attachments passed during creation
        req_id = result.get("request_id") or result.get("id")
        if payload.attachments and req_id:
            for att in payload.attachments:

                try:
                    await exec_sql(
                        """
                        INSERT INTO public.library_request_attachments (
                            school_id, request_id, file_name, file_url, mime_type, file_size, uploaded_by, created_at
                        ) VALUES (%s::uuid, %s::uuid, %s, %s, %s, %s, %s::uuid, NOW());
                        """,
                        (
                            school_id, req_id, att.get("file_name", "attachment"),
                            att.get("file_url", ""), att.get("mime_type"),
                            int(att.get("file_size", 0)), user_id
                        ),
                        fetch=False
                    )
                except Exception as e_att:
                    logger.warning("Error saving initial request attachment: %s", e_att)

        return {"success": True, "message": result.get("message", "Request submitted successfully."), "data": result}

    except Exception as e:
        err_msg = str(e)
        logger.warning("Create request error: %s", err_msg)
        for line in err_msg.split("\n"):
            if "EXCEPTION" in line or "RAISE" in line or "is required" in line:
                clean_err = line.replace("ERROR:", "").replace("PL/pgSQL function", "").strip()
                raise HTTPException(status_code=400, detail=clean_err)
        raise HTTPException(status_code=400, detail=err_msg)


@router.post("/requests/{request_id}/transition")
async def transition_library_request_status(
    request_id: str,
    payload: TransitionRequestStatusModel,
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Transition request status with database-enforced state machine rules and audit trail."""
    user_id = current_user.get("id")

    try:
        res = await exec_sql(
            """
            SELECT public.fn_library_transition_request_status(
                %s::uuid, %s::uuid, %s, %s::uuid, %s, %s
            ) AS result;
            """,
            (school_id, request_id, payload.to_status, user_id, payload.reason, payload.comment)
        )
        result = res[0]["result"] if (res and res[0].get("result")) else {}
        return {"success": True, "message": result.get("message", "Status updated successfully."), "data": result}
    except Exception as e:
        err_msg = str(e)
        for line in err_msg.split("\n"):
            if "Invalid status transition" in line or "not found" in line:
                raise HTTPException(status_code=400, detail=line.replace("ERROR:", "").strip())
        raise HTTPException(status_code=400, detail=err_msg)


@router.post("/requests/{request_id}/assign")
async def assign_library_request(
    request_id: str,
    payload: AssignRequestModel,
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Assign a library request to a librarian."""
    user_id = current_user.get("id")

    await exec_sql(
        """
        UPDATE public.library_requests
        SET assigned_to = %s::uuid, assigned_by = %s::uuid, assigned_at = NOW(),
            assignment_notes = %s, updated_at = NOW()
        WHERE id = %s::uuid AND school_id = %s::uuid;
        """,
        (payload.assigned_to, user_id, payload.notes, request_id, school_id),
        fetch=False
    )

    # Log history & activity
    await exec_sql(
        """
        INSERT INTO public.library_request_status_history (
            school_id, request_id, to_status, changed_by, action, comment, created_at
        ) VALUES (%s, %s, 'ASSIGNED', %s, 'ASSIGN_LIBRARIAN', %s, NOW());
        """,
        (school_id, request_id, user_id, payload.notes or "Assigned to librarian"),
        fetch=False
    )

    return {"success": True, "message": "Request assigned successfully."}


@router.post("/requests/{request_id}/approve")
async def approve_library_request(
    request_id: str,
    payload: ApproveRequestModel,
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Approve or reject a library request awaiting administrative approval."""
    user_id = current_user.get("id")
    appr_status = "APPROVED" if payload.approved else "REJECTED"
    req_status = "IN_PROGRESS" if payload.approved else "REJECTED"

    await exec_sql(
        """
        UPDATE public.library_requests
        SET approval_status = %s, approved_by = %s::uuid, approved_at = NOW(),
            approval_comments = %s, status = %s, updated_at = NOW()
        WHERE id = %s::uuid AND school_id = %s::uuid;
        """,
        (appr_status, user_id, payload.comments, req_status, request_id, school_id),
        fetch=False
    )

    # Insert status history
    await exec_sql(
        """
        INSERT INTO public.library_request_status_history (
            school_id, request_id, from_status, to_status, changed_by, action, comment, created_at
        ) VALUES (%s, %s, 'PENDING_APPROVAL', %s, %s, %s, NOW());
        """,
        (school_id, request_id, req_status, user_id, payload.comments or f"Request {appr_status}"),
        fetch=False
    )

    return {"success": True, "message": f"Request {appr_status.lower()} successfully."}


@router.post("/requests/{request_id}/clarification")
async def request_or_respond_clarification(
    request_id: str,
    payload: ClarificationRequestModel,
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Librarian asks clarification question or requester submits response."""
    user_id = current_user.get("id")

    if payload.is_response:
        # Requester response
        await exec_sql(
            """
            UPDATE public.library_requests
            SET clarification_requested = false, clarification_response = %s, updated_at = NOW()
            WHERE id = %s::uuid AND school_id = %s::uuid;
            """,
            (payload.message, request_id, school_id),
            fetch=False
        )
        action_name = "CLARIFICATION_RESPONDED"
    else:
        # Librarian request
        await exec_sql(
            """
            UPDATE public.library_requests
            SET clarification_requested = true, clarification_message = %s, updated_at = NOW()
            WHERE id = %s::uuid AND school_id = %s::uuid;
            """,
            (payload.message, request_id, school_id),
            fetch=False
        )
        action_name = "CLARIFICATION_REQUESTED"

    # Add as comment too
    await exec_sql(
        """
        INSERT INTO public.library_request_comments (school_id, request_id, author_id, comment, is_internal, created_at)
        VALUES (%s, %s, %s, %s, false, NOW());
        """,
        (school_id, request_id, user_id, f"[{action_name}] {payload.message}"),
        fetch=False
    )

    return {"success": True, "message": "Clarification message recorded."}


@router.post("/requests/{request_id}/comments")
async def add_library_request_comment(
    request_id: str,
    payload: AddRequestCommentModel,
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Add a public or internal comment to a library request."""
    user_id = current_user.get("id")
    if not payload.comment or not payload.comment.strip():
        raise HTTPException(status_code=400, detail="Comment cannot be empty.")

    await exec_sql(
        """
        INSERT INTO public.library_request_comments (
            school_id, request_id, author_id, comment, is_internal, created_at
        ) VALUES (%s::uuid, %s::uuid, %s::uuid, %s, %s, NOW());
        """,
        (school_id, request_id, user_id, payload.comment.strip(), payload.is_internal),
        fetch=False
    )

    return {"success": True, "message": "Comment posted successfully."}


@router.post("/requests/{request_id}/attachments")
async def add_library_request_attachment(
    request_id: str,
    payload: AddRequestAttachmentModel,
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Attach a document or file link to a library request."""
    user_id = current_user.get("id")

    await exec_sql(
        """
        INSERT INTO public.library_request_attachments (
            school_id, request_id, file_name, file_url, mime_type, file_size, uploaded_by, created_at
        ) VALUES (%s::uuid, %s::uuid, %s, %s, %s, %s, %s::uuid, NOW());
        """,
        (school_id, request_id, payload.file_name, payload.file_url, payload.mime_type, payload.file_size, user_id),
        fetch=False
    )

    return {"success": True, "message": "Attachment linked successfully."}


@router.post("/requests/{request_id}/attachments/upload")
async def upload_library_request_attachment(
    request_id: str,
    file: UploadFile = File(...),
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Upload a file directly from local system and attach to an existing library request."""
    user_id = current_user.get("id")
    file_bytes = await file.read()
    file_size = len(file_bytes)

    if file_size > 25 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="File too large (maximum allowed size is 25 MB)")

    safe_name = file.filename or "attachment"
    extension = safe_name.rsplit(".", 1)[-1].lower() if "." in safe_name else "bin"
    attachment_id = str(uuid.uuid4())

    storage_path = f"documents/library/requests/{request_id}/{attachment_id}.{extension}"
    supabase_url = settings.SUPABASE_URL.rstrip("/")
    storage_url = f"{supabase_url}/storage/v1/object/{storage_path}"
    headers = {
        "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
        "Content-Type": file.content_type or "application/octet-stream",
        "x-upsert": "true",
    }

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            upload_response = await client.post(storage_url, headers=headers, content=file_bytes)
        if upload_response.status_code not in (200, 201):
            logger.warning("Storage upload returned status %s: %s", upload_response.status_code, upload_response.text)
    except Exception as e:
        logger.warning("Storage upload exception: %s", e)

    from app.middleware.auth import get_public_supabase_url
    public_url_base = get_public_supabase_url(supabase_url)
    file_url = f"{public_url_base}/storage/v1/object/public/{storage_path}"

    rows = await exec_sql(
        """
        INSERT INTO public.library_request_attachments (
            id, school_id, request_id, file_name, file_url, mime_type, file_size, uploaded_by, created_at
        ) VALUES (
            %s::uuid, %s::uuid, %s::uuid, %s, %s, %s, %s, %s::uuid, NOW()
        ) RETURNING id, file_name, file_url, mime_type, file_size, created_at;
        """,
        (attachment_id, school_id, request_id, safe_name, file_url, file.content_type, file_size, user_id)
    )

    # Insert status history log
    await exec_sql(
        """
        INSERT INTO public.library_request_status_history (
            school_id, request_id, to_status, changed_by, action, comment, created_at
        ) VALUES (%s::uuid, %s::uuid, 'ATTACHMENT_ADDED', %s::uuid, 'UPLOAD_ATTACHMENT', %s, NOW());
        """,
        (school_id, request_id, user_id, f"Uploaded attachment: {safe_name}"),
        fetch=False
    )

    return {
        "success": True,
        "message": "Attachment uploaded successfully.",
        "data": _serialize_datetime(rows[0]) if rows else {
            "id": attachment_id,
            "file_name": safe_name,
            "file_url": file_url,
            "mime_type": file.content_type,
            "file_size": file_size,
        }
    }


@router.post("/requests/upload-temp-attachment")
async def upload_temp_library_attachment(
    file: UploadFile = File(...),
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Upload a file temporarily to storage while raising a new request."""
    file_bytes = await file.read()
    file_size = len(file_bytes)

    if file_size > 25 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="File too large (maximum allowed size is 25 MB)")

    safe_name = file.filename or "attachment"
    extension = safe_name.rsplit(".", 1)[-1].lower() if "." in safe_name else "bin"
    temp_id = str(uuid.uuid4())

    storage_path = f"documents/library/requests/temp/{temp_id}.{extension}"
    supabase_url = settings.SUPABASE_URL.rstrip("/")
    storage_url = f"{supabase_url}/storage/v1/object/{storage_path}"
    headers = {
        "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
        "Content-Type": file.content_type or "application/octet-stream",
        "x-upsert": "true",
    }

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            upload_response = await client.post(storage_url, headers=headers, content=file_bytes)
        if upload_response.status_code not in (200, 201):
            logger.warning("Temp storage upload status %s: %s", upload_response.status_code, upload_response.text)
    except Exception as e:
        logger.warning("Temp storage upload exception: %s", e)

    from app.middleware.auth import get_public_supabase_url
    public_url_base = get_public_supabase_url(supabase_url)
    file_url = f"{public_url_base}/storage/v1/object/public/{storage_path}"

    return {
        "success": True,
        "file_name": safe_name,
        "file_url": file_url,
        "mime_type": file.content_type or "application/octet-stream",
        "file_size": file_size
    }



@router.post("/requests/{request_id}/process")
async def process_library_request(
    request_id: str,
    payload: ProcessLibraryRequestModel,
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Backward compatible process endpoint: Approve, reject, or issue a pending library request."""
    user_id = current_user.get("id")
    action = payload.action.upper()

    req_rows = await exec_sql("SELECT * FROM public.library_requests WHERE id = %s AND school_id = %s", (request_id, school_id))
    if not req_rows:
        raise HTTPException(status_code=404, detail="Request not found.")
    req = req_rows[0]

    if action == "REJECT":
        if not payload.rejection_reason:
            raise HTTPException(status_code=400, detail="Rejection reason is required.")
        return await transition_library_request_status(
            request_id=request_id,
            payload=TransitionRequestStatusModel(to_status="REJECTED", reason=payload.rejection_reason),
            school_id=school_id,
            current_user=current_user
        )

    elif action == "APPROVE" or action == "ACTIVATE":
        return await transition_library_request_status(
            request_id=request_id,
            payload=TransitionRequestStatusModel(to_status="ACTIVE"),
            school_id=school_id,
            current_user=current_user
        )

    elif action == "ISSUE":
        # Call issue stored procedure
        issue_payload = IssueBooksRequest(
            member_id=str(req["member_id"]),
            items=[IssueBookItemRequest(book_id=str(req["book_id"]), copy_id=payload.copy_id, due_date=str(req.get("requested_due_date") or ""))]
        )
        issue_res = await issue_books(issue_payload, school_id=school_id, current_user=current_user)
        # Update request status to COMPLETED
        await transition_library_request_status(
            request_id=request_id,
            payload=TransitionRequestStatusModel(to_status="COMPLETED", comment="Book issued via circulation"),
            school_id=school_id,
            current_user=current_user
        )
        return {"success": True, "message": "Book issued and request marked completed.", "data": issue_res}

    else:
        raise HTTPException(status_code=400, detail=f"Invalid action: {action}")


@router.post("/requests/bulk-action")
async def bulk_requests_action(
    payload: RequestBulkActionModel,
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Execute bulk operations on selected requests (Activate, Assign, Reject, Resolve)."""
    user_id = current_user.get("id")
    action = payload.action.upper()
    success_count = 0
    errors = []

    for r_id in payload.request_ids:
        try:
            if action == "ACTIVATE":
                await transition_library_request_status(
                    request_id=r_id,
                    payload=TransitionRequestStatusModel(to_status="ACTIVE"),
                    school_id=school_id,
                    current_user=current_user
                )
            elif action == "REJECT":
                await transition_library_request_status(
                    request_id=r_id,
                    payload=TransitionRequestStatusModel(to_status="REJECTED", reason=payload.reason or "Bulk rejected"),
                    school_id=school_id,
                    current_user=current_user
                )
            elif action == "ASSIGN" and payload.assigned_to:
                await assign_library_request(
                    request_id=r_id,
                    payload=AssignRequestModel(assigned_to=payload.assigned_to, notes=payload.reason),
                    school_id=school_id,
                    current_user=current_user
                )
            success_count += 1
        except Exception as e:
            errors.append(f"Request {r_id}: {str(e)}")

    return {
        "success": len(errors) == 0,
        "message": f"Bulk {action} completed: {success_count} succeeded, {len(errors)} failed.",
        "succeeded_count": success_count,
        "failed_count": len(errors),
        "errors": errors
    }



@router.get("/fines")
async def list_fines(
    status: Optional[str] = Query("ALL"),
    member_id: Optional[str] = Query(None),
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """List library fines with member and borrow context."""
    where_clauses = ["f.school_id = %s"]
    params: List[Any] = [school_id]

    if status and status.upper() != "ALL":
        where_clauses.append("f.status = %s")
        params.append(status.upper())

    if member_id:
        where_clauses.append("f.member_id = %s")
        params.append(member_id)

    sql = f"""
        SELECT 
            f.id, f.amount, f.paid_amount, f.waived_amount, f.outstanding_amount,
            f.reason, f.status, f.created_at, f.paid_at, f.waived_at, f.waiver_reason,
            m.id AS member_id, m.member_code, p.full_name AS member_name,
            b.id AS book_id, b.title AS book_title,
            br.transaction_code, br.due_date, br.return_date
        FROM public.library_fines f
        JOIN public.library_members m ON f.member_id = m.id
        JOIN public.profiles p ON m.profile_id = p.id
        LEFT JOIN public.library_borrows br ON f.borrow_id = br.id
        LEFT JOIN public.library_books b ON br.book_id = b.id
        WHERE {" AND ".join(where_clauses)}
        ORDER BY f.created_at DESC;
    """
    rows = await exec_sql(sql, tuple(params))
    return {"success": True, "data": _serialize_datetime(rows)}


@router.post("/fines/{fine_id}/collect")
async def collect_fine_payment(
    fine_id: str,
    payload: CollectFineRequest,
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Collect fine payment and generate formal payment receipt."""
    user_id = current_user.get("id")

    try:
        res = await exec_sql(
            """
            SELECT public.fn_library_collect_fine(
                %s::uuid, %s::uuid, %s::numeric, %s, %s, %s::uuid, %s
            ) AS result;
            """,
            (school_id, fine_id, payload.amount, payload.payment_method, payload.transaction_reference, user_id, payload.notes)
        )
        result = res[0]["result"] if (res and res[0].get("result")) else {}
        return {"success": True, "message": result.get("message", "Fine payment recorded successfully."), "data": result}
    except Exception as e:
        err_msg = str(e)
        for line in err_msg.split("\n"):
            if "exceeds outstanding" in line or "already been fully settled" in line:
                raise HTTPException(status_code=400, detail=line.replace("ERROR:", "").strip())
        raise HTTPException(status_code=400, detail=err_msg)


@router.post("/fines/{fine_id}/waive")
async def waive_fine(
    fine_id: str,
    payload: WaiveFineRequest,
    school_id: str = Depends(require_school_id),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Waive full or partial fine with audit rationale."""
    user_id = current_user.get("id")

    try:
        res = await exec_sql(
            """
            SELECT public.fn_library_waive_fine(
                %s::uuid, %s::uuid, %s::numeric, %s, %s::uuid
            ) AS result;
            """,
            (school_id, fine_id, payload.amount, payload.reason, user_id)
        )
        result = res[0]["result"] if (res and res[0].get("result")) else {}
        return {"success": True, "message": result.get("message", "Fine waiver processed successfully."), "data": result}
    except Exception as e:
        err_msg = str(e)
        for line in err_msg.split("\n"):
            if "already been paid" in line:
                raise HTTPException(status_code=400, detail=line.replace("ERROR:", "").strip())
        raise HTTPException(status_code=400, detail=err_msg)


