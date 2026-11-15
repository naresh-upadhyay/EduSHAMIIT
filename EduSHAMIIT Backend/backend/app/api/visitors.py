"""
Universal Enterprise Visitors Management API for EduSHAMIIT ERP.
Institution-wide visitor registration, appointments & approvals, multi-location check-in / check-out,
overstay monitoring, QR-verifiable gate passes, security restriction / blacklist engine,
analytics, CSV reporting, RBAC, and multi-tenant isolation.
"""
from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status
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
import csv
import psycopg2
from psycopg2.extras import RealDictCursor, register_uuid

register_uuid()

import base64
import re
import cv2
import numpy as np
import qrcode
from app.config import settings
from app.middleware.auth import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter()
visits_router = APIRouter()
appointments_router = APIRouter()
gate_passes_router = APIRouter()
restrictions_router = APIRouter()


# ============================================================================
# DATABASE EXECUTION HELPER
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


def _serialize_val(val: Any) -> Any:
    """Format dates, datetimes, decimals, and UUIDs for clean JSON serialization."""
    if isinstance(val, (datetime, date, time)):
        return val.isoformat()
    if isinstance(val, uuid.UUID):
        return str(val)
    if isinstance(val, Decimal):
        return float(val)
    if isinstance(val, dict):
        return {k: _serialize_val(v) for k, v in val.items()}
    if isinstance(val, list):
        return [_serialize_val(item) for item in val]
    return val


def _get_school_id(current_user: dict, school_id_override: Optional[str] = None) -> str:
    """Extract school_id from authenticated user session or fallback to default."""
    if school_id_override and str(school_id_override).strip():
        return str(school_id_override).strip()
    user_school = current_user.get("school_id")
    if user_school:
        return str(user_school)
    return "11111111-1111-1111-1111-111111111111"


def _normalize_pagination(pag: dict, page: int = 1, page_size: int = 10) -> dict:
    """Ensure both total and total_records keys are present for frontend compatibility."""
    if not isinstance(pag, dict):
        pag = {}
    p = _serialize_val(pag)
    total = p.get("total_records") if "total_records" in p and p.get("total_records") is not None else p.get("total", 0)
    total_val = int(total) if total is not None else 0
    p["total"] = total_val
    p["total_records"] = total_val
    p.setdefault("page", page)
    p.setdefault("page_size", page_size)
    p.setdefault("total_pages", (total_val + page_size - 1) // page_size if page_size > 0 else 1)
    return p


# ============================================================================
# QR CODE GENERATION & COMPUTER VISION DECODING
# ============================================================================

def generate_qr_bytes(text: Optional[str]) -> bytes:
    """Generate high-resolution, high-contrast crisp PNG image bytes for QR code."""
    clean_text = str(text or "GP-EMPTY").strip()
    try:
        qr = qrcode.QRCode(
            version=None,  # Auto-size version to fit any length of string without overflow
            error_correction=qrcode.constants.ERROR_CORRECT_M,
            box_size=10,
            border=3,
        )
        qr.add_data(clean_text)
        qr.make(fit=True)
        img = qr.make_image(fill_color="black", back_color="white")
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        return buf.getvalue()
    except Exception as e:
        logger.error(f"Error in qrcode generation for '{clean_text}', falling back to cv2: {e}")
        # Robust fallback using OpenCV rendering
        blank = np.ones((300, 300, 3), dtype=np.uint8) * 255
        cv2.putText(blank, clean_text[:24], (15, 150), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 0), 2)
        _, enc = cv2.imencode(".png", blank)
        return enc.tobytes()


def generate_qr_base64(text: Optional[str]) -> str:
    """Generate base64 data URI string for instant zero-latency embedding."""
    raw_bytes = generate_qr_bytes(text)
    return f"data:image/png;base64,{base64.b64encode(raw_bytes).decode('utf-8')}"


def decode_qr_from_bytes(image_bytes: Optional[bytes]) -> Optional[str]:
    """Decode QR code from image bytes using OpenCV detector with multi-stage adaptive preprocessing."""
    if not image_bytes or len(image_bytes) < 10:
        return None
    try:
        nparr = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            return None

        detector = cv2.QRCodeDetector()

        def _try_detect(im):
            try:
                val, _, _ = detector.detectAndDecode(im)
                if val and val.strip():
                    return val.strip()
            except Exception:
                pass
            return None

        # 1. Direct color detection
        res = _try_detect(img)
        if res:
            return res

        # 2. Grayscale
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        res = _try_detect(gray)
        if res:
            return res

        # 3. Multi-scale normalization (crucial for 1080p, 4K, 8K mobile camera photos)
        h, w = gray.shape
        max_dim = max(h, w)
        min_dim = min(h, w)

        if max_dim > 600:
            scale = 450.0 / max_dim
            norm = cv2.resize(gray, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_AREA)
            res = _try_detect(norm)
            if res:
                return res
        elif min_dim < 350:
            scale = 450.0 / max(min_dim, 1)
            norm = cv2.resize(gray, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_CUBIC)
            res = _try_detect(norm)
            if res:
                return res

        # 4. Inverted image (critical for dark mode themes and inverted badge designs)
        inverted = cv2.bitwise_not(gray)
        res = _try_detect(inverted)
        if res:
            return res

        if max_dim > 600:
            scale = 450.0 / max_dim
            inv_norm = cv2.resize(inverted, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_AREA)
            res = _try_detect(inv_norm)
            if res:
                return res

        # 5. Adaptive Gaussian Thresholding
        thresh = cv2.adaptiveThreshold(
            gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 11, 2
        )
        res = _try_detect(thresh)
        if res:
            return res

        # 6. Otsu Binarization
        _, otsu = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        res = _try_detect(otsu)
        if res:
            return res

        return None
    except Exception as e:
        logger.error(f"Error decoding QR from image bytes: {e}")
        return None


def _is_expired(exp_dt: Optional[datetime]) -> bool:
    """Safe timezone-aware or naive datetime expiration checker."""
    if not exp_dt:
        return False
    try:
        now = datetime.now(exp_dt.tzinfo) if exp_dt.tzinfo else datetime.now()
        return exp_dt < now
    except Exception:
        return False


# ============================================================================
# PYDANTIC SCHEMAS
# ============================================================================

class VisitorRegisterPayload(BaseModel):
    full_name: str = Field(..., min_length=2, max_length=150)
    phone: str = Field(..., min_length=7, max_length=50)
    alternate_phone: Optional[str] = None
    email: Optional[str] = None
    company: Optional[str] = None
    designation: Optional[str] = None
    visitor_type: Optional[str] = "Parent"
    id_type: Optional[str] = "Aadhaar Card"
    id_number_masked: Optional[str] = "XXXX-XXXX-1234"
    photo_url: Optional[str] = None
    purpose: str = Field(..., min_length=2, max_length=150)
    category: Optional[str] = None
    entry_location: Optional[str] = "Main Gate"
    destination: str = Field(..., min_length=2, max_length=150)
    host_name: Optional[str] = None
    host_department: Optional[str] = None
    host_phone: Optional[str] = None
    visit_type: Optional[str] = "WALK_IN"
    expected_out_at: Optional[str] = None
    vehicle_number: Optional[str] = None
    vehicle_type: Optional[str] = None
    accompanying_count: Optional[int] = 0
    items_carried: Optional[str] = None
    remarks: Optional[str] = None
    auto_check_in: Optional[bool] = True
    override_restriction: Optional[bool] = False
    notes: Optional[str] = None
    documents: Optional[List[Dict[str, Any]]] = None


class VisitCheckInPayload(BaseModel):
    entry_location: Optional[str] = "Main Gate"
    operator_name: Optional[str] = "Security Desk"
    expected_out_at: Optional[str] = None
    remarks: Optional[str] = None


class VisitCheckOutPayload(BaseModel):
    exit_location: Optional[str] = "Main Gate"
    operator_name: Optional[str] = "Security Desk"
    remarks: Optional[str] = None


class VisitBulkCheckOutPayload(BaseModel):
    visit_ids: List[str]
    exit_location: Optional[str] = "Main Gate"
    operator_name: Optional[str] = "Security Desk"
    remarks: Optional[str] = "Bulk check-out"


class VisitExtendPayload(BaseModel):
    extension_minutes: int = Field(default=60, ge=5, le=1440)
    reason: Optional[str] = "Host requested extension"


class VisitUpdatePayload(BaseModel):
    full_name: Optional[str] = None
    phone: Optional[str] = None
    alternate_phone: Optional[str] = None
    email: Optional[str] = None
    company: Optional[str] = None
    visitor_type: Optional[str] = None
    id_type: Optional[str] = None
    id_number_masked: Optional[str] = None
    photo_url: Optional[str] = None
    purpose: Optional[str] = None
    destination: Optional[str] = None
    host_name: Optional[str] = None
    vehicle_number: Optional[str] = None
    remarks: Optional[str] = None
    status: Optional[str] = None
    documents: Optional[List[Dict[str, Any]]] = None


class VisitorDocumentUploadPayload(BaseModel):
    visitor_id: Optional[str] = None
    appointment_id: Optional[str] = None
    restriction_id: Optional[str] = None
    visit_id: Optional[str] = None
    document_name: str = Field(..., min_length=2, max_length=255)
    document_type: str = Field(default="ID Proof", max_length=100)
    file_url: str = Field(..., min_length=3)
    file_size_bytes: Optional[int] = 0
    verification_status: Optional[str] = "VERIFIED"


class AppointmentSchedulePayload(BaseModel):
    full_name: str = Field(..., min_length=2, max_length=150)
    phone: str = Field(..., min_length=7, max_length=50)
    email: Optional[str] = None
    company: Optional[str] = None
    visitor_type: Optional[str] = "Parent"
    host_name: str = Field(..., min_length=2, max_length=150)
    host_department: Optional[str] = None
    purpose: str = Field(..., min_length=2, max_length=150)
    destination: Optional[str] = "Main Gate"
    scheduled_date: Optional[str] = None
    scheduled_start_at: Optional[str] = None
    scheduled_end_at: Optional[str] = None
    expected_count: Optional[int] = 1
    expected_visitors_text: Optional[str] = None
    vehicle_number: Optional[str] = None
    id_type: Optional[str] = "Aadhaar Card"
    id_number_masked: Optional[str] = None
    date_time_text: Optional[str] = None
    remarks: Optional[str] = None
    notes: Optional[str] = None


class AppointmentDecisionPayload(BaseModel):
    reason: Optional[str] = None
    decided_by_name: Optional[str] = "Institution Admin"


class AppointmentReschedulePayload(BaseModel):
    new_date: Optional[str] = None
    new_start_time: Optional[str] = None
    new_end_time: Optional[str] = None
    new_host: Optional[str] = None
    new_location: Optional[str] = None
    reason: Optional[str] = None
    rescheduled_by_name: Optional[str] = None


class AppointmentCancelPayload(BaseModel):
    reason: Optional[str] = "Cancelled by host"
    cancelled_by_name: Optional[str] = None


class RestrictionCreatePayload(BaseModel):
    visitor_id: Optional[str] = None
    full_name: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    id_type: Optional[str] = "Aadhaar Card"
    id_number_masked: Optional[str] = None
    photo_url: Optional[str] = None
    scope_type: Optional[str] = "INSTITUTION"
    scope_name: Optional[str] = "Entire Institution"
    reason_category: str = Field(..., min_length=3, max_length=100)
    confidential_notes: Optional[str] = None
    is_permanent: Optional[bool] = False
    valid_till: Optional[str] = None
    blocked_by_name: Optional[str] = "Security Officer"
    remarks: Optional[str] = None
    requested_by_name: Optional[str] = "Security Officer"
    approved_by_name: Optional[str] = "Director / Principal"


class RestrictionUpdatePayload(BaseModel):
    reason_category: Optional[str] = None
    scope_name: Optional[str] = None
    valid_till: Optional[str] = None
    is_permanent: Optional[bool] = None
    remarks: Optional[str] = None
    updated_by_name: Optional[str] = None


class RestrictionLiftPayload(BaseModel):
    lifted_by_name: Optional[str] = "Director / Principal"
    reason: str = Field(..., min_length=3)


class VisitorUnblockPayload(BaseModel):
    visitor_id: Optional[str] = None
    reason: Optional[str] = "Administrative review completed; access restored"
    lifted_by_name: Optional[str] = "Director / Principal"


class RestrictionEligibilityCheckPayload(BaseModel):
    visitor_id: Optional[str] = None
    phone: Optional[str] = None
    location: Optional[str] = "Main Gate"


class GatePassVerifyPayload(BaseModel):
    token_or_ref: str = Field(..., min_length=3)


class VisitorProfileCreatePayload(BaseModel):
    full_name: str = Field(..., min_length=2, max_length=150)
    phone: str = Field(..., min_length=7, max_length=50)
    alternate_phone: Optional[str] = None
    email: Optional[str] = None
    company: Optional[str] = None
    organization: Optional[str] = None
    designation: Optional[str] = None
    visitor_type: Optional[str] = None
    category: Optional[str] = None
    id_type: Optional[str] = None
    id_number_masked: Optional[str] = None
    id_number: Optional[str] = None
    photo_url: Optional[str] = None
    notes: Optional[str] = None
    address: Optional[str] = None


class BatchGatePassPayload(BaseModel):
    visitor_ids: List[str] = Field(..., min_items=1)
    location: Optional[str] = "Main Gate"
    destination: Optional[str] = None
    entry_location: Optional[str] = None
    host_name: Optional[str] = "Administration"
    host_department: Optional[str] = "Administration"
    host_phone: Optional[str] = None
    purpose: Optional[str] = "Official Visit"
    duration_hours: Optional[int] = 4
    expected_duration_hours: Optional[int] = None
    vehicle_number: Optional[str] = None
    vehicle_type: Optional[str] = None
    auto_check_in: Optional[bool] = False
    remarks: Optional[str] = None


class GatePassScanImagePayload(BaseModel):
    image_base64: str = Field(..., min_length=10)


class GatePassScanActionPayload(BaseModel):
    action: str = Field(..., description="CHECK_IN or CHECK_OUT")
    location: Optional[str] = "Main Gate"
    gate: Optional[str] = None
    entry_location: Optional[str] = None
    exit_location: Optional[str] = None
    operator_name: Optional[str] = "Gate Security"
    remarks: Optional[str] = None


# ============================================================================
# API ENDPOINTS
# ============================================================================

# 1. KPIs / Summary
@router.get("/kpis")
@router.get("/summary")
async def get_visitor_kpis(
    school_id: Optional[str] = None,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    date_range_label: Optional[str] = None,
    location: Optional[str] = None,
    category: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Retrieve 6 KPI card metrics computed dynamically from PostgreSQL records."""
    effective_school_id = _get_school_id(current_user, school_id)
    filter_params = {}
    if date_from:
        filter_params["date_from"] = date_from
    if date_to:
        filter_params["date_to"] = date_to
    if date_range_label:
        filter_params["date_range_label"] = date_range_label
    if location and location not in ("All", "All Locations"):
        filter_params["location"] = location
    if category and category not in ("All", "All Visitor Types"):
        filter_params["category"] = category

    try:
        rows = await exec_sql(
            "SELECT public.fn_visitors_get_kpis(%s::UUID, %s::JSONB) AS kpis;",
            (effective_school_id, json.dumps(filter_params))
        )
        if rows and rows[0].get("kpis"):
            return {"success": True, "data": _serialize_val(rows[0]["kpis"])}
        return {"success": True, "data": {}}
    except Exception as e:
        logger.error(f"Error fetching visitor KPIs: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 2. Analytics & Visualizations
@router.get("/analytics")
async def get_visitor_analytics(
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Retrieve categories distribution, location counts, and recent visitors."""
    effective_school_id = _get_school_id(current_user, school_id)
    try:
        rows = await exec_sql(
            "SELECT public.fn_visitors_get_analytics(%s::UUID) AS analytics;",
            (effective_school_id,)
        )
        if rows and rows[0].get("analytics"):
            return {"success": True, "data": _serialize_val(rows[0]["analytics"])}
        return {"success": True, "data": {}}
    except Exception as e:
        logger.error(f"Error fetching visitor analytics: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 3. List Visits (Main All Visitors Grid)
@router.get("/visits")
@router.get("/")
@visits_router.get("")
async def list_visits(
    search: Optional[str] = None,
    location: Optional[str] = None,
    category: Optional[str] = None,
    status: Optional[str] = None,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    sort_by: Optional[str] = None,
    sort_order: Optional[str] = None,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Server-side debounced search, filtering, and pagination for All Visitors grid."""
    effective_school_id = _get_school_id(current_user, school_id)
    params = {
        "search": search or "",
        "location": location or "All",
        "category": category or "All",
        "status": status or "All",
        "date_from": date_from,
        "date_to": date_to,
        "page": page,
        "page_size": page_size,
        "sort_by": sort_by or "created_at",
        "sort_order": sort_order or "DESC",
    }
    try:
        rows = await exec_sql(
            "SELECT public.fn_visitors_list_visits(%s::UUID, %s::JSONB) AS result;",
            (effective_school_id, json.dumps(params))
        )
        if rows and rows[0].get("result"):
            res = rows[0]["result"]
            return {
                "success": True,
                "data": _serialize_val(res.get("records", [])),
                "pagination": _normalize_pagination(res.get("pagination", {}), page=page, page_size=page_size)
            }
        return {"success": True, "data": [], "pagination": _normalize_pagination({}, page=page, page_size=page_size)}
    except Exception as e:
        logger.error(f"Error listing visits: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 4. Visit Details by ID (Detail Drawer 360 View)
@router.get("/visits/{visit_id}")
@visits_router.get("/{visit_id}")
async def get_visit_details(
    visit_id: str,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Get complete visit profile, documents, history, and access events for drawer."""
    effective_school_id = _get_school_id(current_user, school_id)
    try:
        rows = await exec_sql(
            "SELECT public.fn_visitors_get_visit_details(%s::UUID, %s::UUID) AS details;",
            (effective_school_id, visit_id)
        )
        if rows and rows[0].get("details"):
            res = rows[0]["details"]
            if not res.get("success"):
                raise HTTPException(status_code=404, detail=res.get("error", "Visit not found"))
            return {"success": True, "data": _serialize_val(res)}
        raise HTTPException(status_code=404, detail="Visit not found")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching visit details: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 5. Register Visitor & Create Visit Record
@router.post("/register")
@router.post("/visits")
@visits_router.post("")
async def register_visitor(
    payload: VisitorRegisterPayload,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Register a new or returning visitor, check restrictions, and create visit."""
    effective_school_id = _get_school_id(current_user, school_id)
    try:
        rows = await exec_sql(
            "SELECT public.fn_visitors_register_and_visit(%s::UUID, %s::JSONB) AS result;",
            (effective_school_id, json.dumps(payload.dict()))
        )
        if rows and rows[0].get("result"):
            res = rows[0]["result"]
            if not res.get("success"):
                if res.get("is_restricted"):
                    raise HTTPException(status_code=403, detail=res.get("detail"))
                raise HTTPException(status_code=400, detail=res.get("detail", "Registration failed"))

            # Sync documents if provided
            if payload.documents and res.get("visitor_id") and res.get("visit_id"):
                await exec_sql(
                    "SELECT public.fn_visitors_sync_documents(%s::UUID, %s::UUID, %s::UUID, %s::JSONB) AS result;",
                    (effective_school_id, res["visitor_id"], res["visit_id"], json.dumps(payload.documents))
                )

            return {"success": True, "data": _serialize_val(res)}
        raise HTTPException(status_code=500, detail="Database registration execution failed")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error registering visitor: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 6. Check In Visit
@router.post("/visits/{visit_id}/check-in")
@visits_router.post("/{visit_id}/check-in")
async def check_in_visit(
    visit_id: str,
    payload: Optional[VisitCheckInPayload] = None,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Record physical entry check-in for an authorized visit."""
    effective_school_id = _get_school_id(current_user, school_id)
    body = payload.dict() if payload else {}
    if not body.get("operator_name") and current_user.get("full_name"):
        body["operator_name"] = current_user.get("full_name")
    try:
        rows = await exec_sql(
            "SELECT public.fn_visitors_check_in(%s::UUID, %s::UUID, %s::JSONB) AS result;",
            (effective_school_id, visit_id, json.dumps(body))
        )
        if rows and rows[0].get("result"):
            res = rows[0]["result"]
            if not res.get("success"):
                raise HTTPException(status_code=400, detail=res.get("detail"))
            return {"success": True, "data": _serialize_val(res)}
        raise HTTPException(status_code=500, detail="Check-in failed")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error during check-in: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 7. Check Out Visit
@router.post("/visits/{visit_id}/check-out")
@visits_router.post("/{visit_id}/check-out")
async def check_out_visit(
    visit_id: str,
    payload: Optional[VisitCheckOutPayload] = None,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Record checkout, mark visit completed, and close active access authorization."""
    effective_school_id = _get_school_id(current_user, school_id)
    body = payload.dict() if payload else {}
    if not body.get("operator_name") and current_user.get("full_name"):
        body["operator_name"] = current_user.get("full_name")
    try:
        rows = await exec_sql(
            "SELECT public.fn_visitors_check_out(%s::UUID, %s::UUID, %s::JSONB) AS result;",
            (effective_school_id, visit_id, json.dumps(body))
        )
        if rows and rows[0].get("result"):
            res = rows[0]["result"]
            if not res.get("success"):
                raise HTTPException(status_code=400, detail=res.get("detail"))
            return {"success": True, "data": _serialize_val(res)}
        raise HTTPException(status_code=500, detail="Checkout failed")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error during checkout: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 7b. Bulk Check Out Visits
@router.post("/visits/bulk-check-out")
@visits_router.post("/bulk-check-out")
async def bulk_check_out_visits(
    payload: VisitBulkCheckOutPayload,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Bulk check out multiple visitors in a single database transaction."""
    effective_school_id = _get_school_id(current_user, school_id)
    body = payload.dict()
    if not body.get("operator_name") and current_user.get("full_name"):
        body["operator_name"] = current_user.get("full_name")
    try:
        rows = await exec_sql(
            "SELECT public.fn_visitors_bulk_check_out(%s::UUID, %s::UUID[], %s::JSONB) AS result;",
            (effective_school_id, payload.visit_ids, json.dumps(body))
        )
        if rows and rows[0].get("result"):
            res = rows[0]["result"]
            if not res.get("success"):
                raise HTTPException(status_code=400, detail=res.get("detail"))
            return {"success": True, "data": _serialize_val(res)}
        raise HTTPException(status_code=500, detail="Bulk checkout failed")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error during bulk checkout: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 8. Extend Visit
@router.post("/visits/{visit_id}/extend")
@visits_router.post("/{visit_id}/extend")
async def extend_visit(
    visit_id: str,
    payload: VisitExtendPayload,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Extend authorized stay duration and update gate pass validity."""
    effective_school_id = _get_school_id(current_user, school_id)
    try:
        rows = await exec_sql(
            "SELECT public.fn_visitors_extend_visit(%s::UUID, %s::UUID, %s::JSONB) AS result;",
            (effective_school_id, visit_id, json.dumps(payload.dict()))
        )
        if rows and rows[0].get("result"):
            res = rows[0]["result"]
            if not res.get("success"):
                raise HTTPException(status_code=400, detail=res.get("detail"))
            return {"success": True, "data": _serialize_val(res)}
        raise HTTPException(status_code=500, detail="Visit extension failed")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error extending visit: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 9. Cancel Visit
@router.post("/visits/{visit_id}/cancel")
@visits_router.post("/{visit_id}/cancel")
async def cancel_visit(
    visit_id: str,
    reason: Optional[str] = "Cancelled by administration",
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Cancel an active or scheduled visit."""
    effective_school_id = _get_school_id(current_user, school_id)
    try:
        await exec_sql(
            """
            UPDATE public.visitor_visits
            SET status = 'Cancelled', remarks = COALESCE(remarks || ' | ', '') || 'Cancelled: ' || %s,
                updated_at = NOW()
            WHERE id = %s::UUID AND school_id = %s::UUID;
            """,
            (reason, visit_id, effective_school_id),
            fetch=False
        )
        return {"success": True, "status": "Cancelled"}
    except Exception as e:
        logger.error(f"Error cancelling visit: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 9b. Update Visit & Visitor Profile
@router.put("/visits/{visit_id}")
@visits_router.put("/{visit_id}")
@router.patch("/visits/{visit_id}")
@visits_router.patch("/{visit_id}")
async def update_visit(
    visit_id: str,
    payload: VisitUpdatePayload,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Update existing visit record and visitor profile including photo, name, destination, host, etc."""
    effective_school_id = _get_school_id(current_user, school_id)
    try:
        visit_rows = await exec_sql(
            "SELECT id, visitor_id FROM public.visitor_visits WHERE id = %s::UUID AND school_id = %s::UUID;",
            (visit_id, effective_school_id)
        )
        if not visit_rows:
            raise HTTPException(status_code=404, detail="Visit record not found.")

        visitor_id = str(visit_rows[0]["visitor_id"])

        # Update visitor_profiles
        p_sets = []
        p_vals = []
        if payload.full_name is not None and payload.full_name.strip():
            p_sets.append("full_name = %s")
            p_vals.append(payload.full_name.strip())
        if payload.phone is not None and payload.phone.strip():
            p_sets.append("phone = %s")
            p_vals.append(payload.phone.strip())
        if payload.alternate_phone is not None:
            p_sets.append("alternate_phone = %s")
            p_vals.append(payload.alternate_phone.strip() if payload.alternate_phone else None)
        if payload.email is not None:
            p_sets.append("email = %s")
            p_vals.append(payload.email.strip() if payload.email else None)
        if payload.company is not None:
            p_sets.append("company = %s")
            p_vals.append(payload.company.strip() if payload.company else None)
        if payload.visitor_type is not None and payload.visitor_type.strip():
            p_sets.append("visitor_type = %s")
            p_vals.append(payload.visitor_type.strip())
        if payload.id_type is not None and payload.id_type.strip():
            p_sets.append("id_type = %s")
            p_vals.append(payload.id_type.strip())
        if payload.id_number_masked is not None:
            p_sets.append("id_number_masked = %s")
            p_vals.append(payload.id_number_masked.strip() if payload.id_number_masked else None)
        if payload.photo_url is not None:
            p_sets.append("photo_url = %s")
            p_vals.append(payload.photo_url)

        if p_sets:
            p_sets.append("updated_at = NOW()")
            p_sql = f"UPDATE public.visitor_profiles SET {', '.join(p_sets)} WHERE id = %s::UUID AND school_id = %s::UUID;"
            p_vals.extend([visitor_id, effective_school_id])
            await exec_sql(p_sql, tuple(p_vals), fetch=False)

        # Update visitor_visits
        v_sets = []
        v_vals = []
        if payload.purpose is not None and payload.purpose.strip():
            v_sets.append("purpose = %s")
            v_vals.append(payload.purpose.strip())
        if payload.destination is not None and payload.destination.strip():
            v_sets.append("destination = %s")
            v_vals.append(payload.destination.strip())
        if payload.visitor_type is not None and payload.visitor_type.strip():
            v_sets.append("category = %s")
            v_vals.append(payload.visitor_type.strip())
        if payload.host_name is not None:
            v_sets.append("host_name = %s")
            v_vals.append(payload.host_name.strip() if payload.host_name else None)
        if payload.vehicle_number is not None:
            v_sets.append("vehicle_number = %s")
            v_vals.append(payload.vehicle_number.strip() if payload.vehicle_number else None)
        if payload.remarks is not None:
            v_sets.append("remarks = %s")
            v_vals.append(payload.remarks.strip() if payload.remarks else None)
        if payload.status is not None and payload.status.strip():
            v_sets.append("status = %s")
            v_vals.append(payload.status.strip())
        if payload.photo_url is not None:
            v_sets.append("photo_url = %s")
            v_vals.append(payload.photo_url)

        if v_sets:
            v_sets.append("updated_at = NOW()")
            v_sql = f"UPDATE public.visitor_visits SET {', '.join(v_sets)} WHERE id = %s::UUID AND school_id = %s::UUID;"
            v_vals.extend([visit_id, effective_school_id])
            await exec_sql(v_sql, tuple(v_vals), fetch=False)

        # Sync documents if provided
        if payload.documents is not None:
            await exec_sql(
                "SELECT public.fn_visitors_sync_documents(%s::UUID, %s::UUID, %s::UUID, %s::JSONB) AS result;",
                (effective_school_id, visitor_id, visit_id, json.dumps(payload.documents))
            )

        # Return updated details
        details_rows = await exec_sql(
            "SELECT public.fn_visitors_get_visit_details(%s::UUID, %s::UUID) AS details;",
            (effective_school_id, visit_id)
        )
        if details_rows and details_rows[0].get("details"):
            return {"success": True, "data": _serialize_val(details_rows[0]["details"])}

        return {"success": True, "message": "Visit updated successfully."}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating visit: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 9c. Direct Document Upload (Works across All Visitors, Scheduled Visitors, and Blacklisted Visitors)
@router.post("/documents")
@router.post("/visitors/documents")
@router.post("/visitors/{visitor_id}/documents")
async def upload_visitor_document(
    payload: VisitorDocumentUploadPayload,
    visitor_id: Optional[str] = None,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Directly attach or upload a verification/incident document to any visitor profile."""
    effective_school_id = _get_school_id(current_user, school_id)
    target_visitor_id = visitor_id or payload.visitor_id
    try:
        rows = await exec_sql(
            """
            SELECT public.fn_visitors_upload_document(
                %s::UUID, %s::UUID, %s, %s, %s, %s::INT, %s, %s::UUID, %s::UUID, %s::UUID
            ) AS result;
            """,
            (
                effective_school_id,
                target_visitor_id,
                payload.document_name,
                payload.document_type,
                payload.file_url,
                payload.file_size_bytes or 0,
                payload.verification_status or "VERIFIED",
                payload.visit_id,
                payload.appointment_id,
                payload.restriction_id,
            )
        )
        if rows and rows[0].get("result"):
            res = rows[0]["result"]
            if not res.get("success"):
                raise HTTPException(status_code=400, detail=res.get("error", "Document upload failed"))
            return {"success": True, "data": _serialize_val(res)}
        raise HTTPException(status_code=500, detail="Document upload execution failed")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error uploading visitor document: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/documents/{document_id}")
@router.delete("/visitors/documents/{document_id}")
async def delete_visitor_document(
    document_id: str,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Remove a previously attached document from a visitor profile."""
    effective_school_id = _get_school_id(current_user, school_id)
    try:
        await exec_sql(
            "DELETE FROM public.visitor_documents WHERE id = %s::UUID AND school_id = %s::UUID;",
            (document_id, effective_school_id),
            fetch=False
        )
        return {"success": True, "message": "Document removed successfully"}
    except Exception as e:
        logger.error(f"Error deleting visitor document: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 10. List Scheduled Appointments (Tab 2)
@router.get("/appointments/kpis")
@appointments_router.get("/kpis")
async def get_scheduled_kpis(
    school_id: Optional[str] = None,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Retrieve 5 KPI card metrics for Scheduled Visitors matching UI design."""
    effective_school_id = _get_school_id(current_user, school_id)
    try:
        rows = await exec_sql(
            "SELECT public.fn_visitors_get_scheduled_kpis(%s::UUID, %s::TIMESTAMPTZ, %s::TIMESTAMPTZ) AS kpis;",
            (effective_school_id, date_from, date_to)
        )
        if rows and rows[0].get("kpis"):
            return {"success": True, "data": _serialize_val(rows[0]["kpis"])}
        return {"success": True, "data": {}}
    except Exception as e:
        logger.error(f"Error fetching scheduled KPIs: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/appointments")
@appointments_router.get("")
async def list_appointments(
    search: Optional[str] = None,
    status: Optional[str] = None,
    location: Optional[str] = None,
    category: Optional[str] = None,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    sort_by: Optional[str] = None,
    sort_order: Optional[str] = None,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Retrieve scheduled visitor appointments with approval statuses and date range filtering."""
    effective_school_id = _get_school_id(current_user, school_id)
    params = {
        "search": search or "",
        "status": status or "All",
        "location": location or "All Locations",
        "category": category or "All Visitor Types",
        "date_from": date_from,
        "date_to": date_to,
        "page": page,
        "page_size": page_size,
        "sort_by": sort_by or "scheduled_start",
        "sort_order": sort_order or "DESC",
    }
    try:
        rows = await exec_sql(
            "SELECT public.fn_visitors_list_appointments(%s::UUID, %s::JSONB) AS result;",
            (effective_school_id, json.dumps(params))
        )
        if rows and rows[0].get("result"):
            res = rows[0]["result"]
            return {
                "success": True,
                "data": _serialize_val(res.get("records", [])),
                "pagination": _normalize_pagination(res.get("pagination", {}), page=page, page_size=page_size)
            }
        return {"success": True, "data": [], "pagination": _normalize_pagination({}, page=page, page_size=page_size)}
    except Exception as e:
        logger.error(f"Error listing appointments: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/appointments/{appointment_id}/details")
@appointments_router.get("/{appointment_id}/details")
async def get_appointment_details(
    appointment_id: str,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Get 360 degree appointment details, related scheduled visitors, documents for right drawer."""
    effective_school_id = _get_school_id(current_user, school_id)
    try:
        rows = await exec_sql(
            "SELECT public.fn_visitors_get_appointment_details(%s::UUID, %s::UUID) AS details;",
            (effective_school_id, appointment_id)
        )
        if rows and rows[0].get("details"):
            res = rows[0]["details"]
            if not res.get("success"):
                raise HTTPException(status_code=404, detail=res.get("error", "Appointment not found"))
            return {"success": True, "data": _serialize_val(res)}
        raise HTTPException(status_code=404, detail="Appointment not found")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching appointment details: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 11. Schedule Appointment
@router.post("/appointments")
@appointments_router.post("")
async def schedule_appointment(
    payload: AppointmentSchedulePayload,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Schedule an appointment in advance for host review/approval."""
    effective_school_id = _get_school_id(current_user, school_id)
    try:
        rows = await exec_sql(
            "SELECT public.fn_visitors_schedule_appointment(%s::UUID, %s::JSONB) AS result;",
            (effective_school_id, json.dumps(payload.dict()))
        )
        if rows and rows[0].get("result"):
            res = rows[0]["result"]
            if not res.get("success"):
                raise HTTPException(status_code=400, detail=res.get("detail"))
            return {"success": True, "data": _serialize_val(res)}
        raise HTTPException(status_code=500, detail="Failed to schedule appointment")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error scheduling appointment: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 12. Approve Appointment
@router.post("/appointments/{appointment_id}/approve")
@appointments_router.post("/{appointment_id}/approve")
async def approve_appointment(
    appointment_id: str,
    payload: Optional[AppointmentDecisionPayload] = None,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Approve a scheduled visitor appointment."""
    effective_school_id = _get_school_id(current_user, school_id)
    approver = payload.decided_by_name if payload else current_user.get("full_name", "Host")
    try:
        rows = await exec_sql(
            "SELECT public.fn_visitors_decide_appointment(%s::UUID, %s::UUID, 'APPROVED', NULL, %s) AS result;",
            (effective_school_id, appointment_id, approver)
        )
        if rows and rows[0].get("result") and rows[0]["result"].get("success"):
            return {"success": True, "status": "APPROVED"}
        raise HTTPException(status_code=400, detail="Failed to approve appointment")
    except Exception as e:
        logger.error(f"Error approving appointment: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 13. Reject Appointment
@router.post("/appointments/{appointment_id}/reject")
@appointments_router.post("/{appointment_id}/reject")
async def reject_appointment(
    appointment_id: str,
    payload: Optional[AppointmentDecisionPayload] = None,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Reject a scheduled visitor appointment with reason."""
    effective_school_id = _get_school_id(current_user, school_id)
    reason = payload.reason if payload else "Host unavailable"
    approver = payload.decided_by_name if payload else current_user.get("full_name", "Host")
    try:
        rows = await exec_sql(
            "SELECT public.fn_visitors_decide_appointment(%s::UUID, %s::UUID, 'REJECTED', %s, %s) AS result;",
            (effective_school_id, appointment_id, reason, approver)
        )
        if rows and rows[0].get("result") and rows[0]["result"].get("success"):
            return {"success": True, "status": "REJECTED"}
        raise HTTPException(status_code=400, detail="Failed to reject appointment")
    except Exception as e:
        logger.error(f"Error rejecting appointment: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 13b. Reschedule Appointment
@router.post("/appointments/{appointment_id}/reschedule")
@appointments_router.post("/{appointment_id}/reschedule")
async def reschedule_appointment(
    appointment_id: str,
    payload: AppointmentReschedulePayload,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Reschedule a visitor appointment and log revision history."""
    effective_school_id = _get_school_id(current_user, school_id)
    body = payload.dict()
    if not body.get("rescheduled_by_name"):
        body["rescheduled_by_name"] = current_user.get("full_name", "Host")
    try:
        rows = await exec_sql(
            "SELECT public.fn_visitors_reschedule_appointment(%s::UUID, %s::UUID, %s::JSONB) AS result;",
            (effective_school_id, appointment_id, json.dumps(body))
        )
        if rows and rows[0].get("result"):
            res = rows[0]["result"]
            if not res.get("success"):
                raise HTTPException(status_code=400, detail=res.get("detail"))
            return {"success": True, "data": _serialize_val(res)}
        raise HTTPException(status_code=400, detail="Failed to reschedule appointment")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error rescheduling appointment: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 13c. Cancel Appointment
@router.post("/appointments/{appointment_id}/cancel")
@appointments_router.post("/{appointment_id}/cancel")
async def cancel_appointment(
    appointment_id: str,
    payload: Optional[AppointmentCancelPayload] = None,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Cancel a visitor appointment with reason."""
    effective_school_id = _get_school_id(current_user, school_id)
    body = payload.dict() if payload else {}
    if not body.get("cancelled_by_name"):
        body["cancelled_by_name"] = current_user.get("full_name", "Host")
    try:
        rows = await exec_sql(
            "SELECT public.fn_visitors_cancel_appointment(%s::UUID, %s::UUID, %s::JSONB) AS result;",
            (effective_school_id, appointment_id, json.dumps(body))
        )
        if rows and rows[0].get("result"):
            res = rows[0]["result"]
            if not res.get("success"):
                raise HTTPException(status_code=400, detail=res.get("detail"))
            return {"success": True, "data": _serialize_val(res)}
        raise HTTPException(status_code=400, detail="Failed to cancel appointment")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error cancelling appointment: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 13d. Check In Appointment (Convert Scheduled Appointment to Active Visit)
@router.post("/appointments/{appointment_id}/check-in")
@appointments_router.post("/{appointment_id}/check-in")
async def check_in_appointment(
    appointment_id: str,
    payload: Optional[VisitCheckInPayload] = None,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Convert an authorized/confirmed scheduled appointment into an active check-in visit."""
    effective_school_id = _get_school_id(current_user, school_id)
    operator = payload.operator_name if (payload and payload.operator_name) else current_user.get("full_name", "Gate Security")
    entry_loc = payload.entry_location if (payload and payload.entry_location) else "Main Gate"
    remarks = payload.remarks if payload else None
    
    try:
        # Fetch the appointment
        appt_rows = await exec_sql(
            """
            SELECT a.*, p.full_name, p.phone, p.email, p.visitor_type, p.id_type, p.id_number_masked, p.photo_url
            FROM public.visitor_appointments a
            JOIN public.visitor_profiles p ON a.visitor_id = p.id
            WHERE a.id = %s::UUID AND a.school_id = %s::UUID;
            """,
            (appointment_id, effective_school_id)
        )
        if not appt_rows:
            raise HTTPException(status_code=404, detail="Appointment not found")
        appt = appt_rows[0]

        # Check restriction eligibility
        chk_rows = await exec_sql(
            "SELECT public.fn_visitors_check_restriction_eligibility(%s::UUID, %s::UUID, %s, %s) AS result;",
            (effective_school_id, appt["visitor_id"], appt["phone"], entry_loc)
        )
        if chk_rows and chk_rows[0].get("result") and chk_rows[0]["result"].get("is_restricted"):
            res_info = chk_rows[0]["result"]
            raise HTTPException(
                status_code=403, 
                detail=f"Security Restriction Active: {res_info.get('reason_category', 'Blacklisted')} at {res_info.get('scope_name', 'Campus')}."
            )

        # Call register_and_visit or insert directly into visitor_visits
        visit_reg_payload = {
            "visitor_id": str(appt["visitor_id"]),
            "appointment_id": str(appt["id"]),
            "full_name": appt["full_name"],
            "phone": appt["phone"],
            "email": appt["email"],
            "visitor_type": appt["visitor_type"] or "Parent",
            "purpose": appt["purpose"],
            "destination": appt["destination"] or "Main Gate",
            "entry_location": entry_loc,
            "host_name": appt["host_name"],
            "host_department": appt["host_department"],
            "host_user_id": str(appt["host_user_id"]) if appt.get("host_user_id") else None,
            "visit_type": "SCHEDULED",
            "vehicle_number": appt.get("vehicle_number"),
            "remarks": remarks or f"Scheduled Appointment #{appt['appointment_number']}",
            "auto_check_in": True,
            "checked_in_by_name": operator
        }

        visit_res = await exec_sql(
            "SELECT public.fn_visitors_register_and_visit(%s::UUID, %s::JSONB) AS result;",
            (effective_school_id, json.dumps(visit_reg_payload))
        )

        # Update appointment status to COMPLETED
        await exec_sql(
            """
            UPDATE public.visitor_appointments
            SET status = 'COMPLETED', updated_at = NOW()
            WHERE id = %s::UUID AND school_id = %s::UUID;
            """,
            (appointment_id, effective_school_id),
            fetch=False
        )

        res_data = visit_res[0]["result"] if visit_res else {}
        return {
            "success": True,
            "message": f"Appointment #{appt['appointment_number']} checked in successfully.",
            "data": _serialize_val(res_data)
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error checking in appointment: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 14. List Restrictions / Blacklist (Tab 3)
@router.get("/restrictions/kpis")
@restrictions_router.get("/kpis")
async def get_blacklisted_kpis(
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Retrieve 4 KPI card metrics for Blacklisted Visitors matching UI design with optional date range."""
    effective_school_id = _get_school_id(current_user, school_id)
    try:
        rows = await exec_sql(
            "SELECT public.fn_visitors_get_blacklisted_kpis(%s::UUID, %s::TIMESTAMPTZ, %s::TIMESTAMPTZ) AS kpis;",
            (effective_school_id, date_from, date_to)
        )
        if rows and rows[0].get("kpis"):
            return {"success": True, "data": _serialize_val(rows[0]["kpis"])}
        return {"success": True, "data": {}}
    except Exception as e:
        logger.error(f"Error fetching blacklisted KPIs: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/restrictions")
@restrictions_router.get("")
async def list_restrictions(
    search: Optional[str] = None,
    status: Optional[str] = None,
    location: Optional[str] = None,
    category: Optional[str] = None,
    reason: Optional[str] = None,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    sort_by: Optional[str] = None,
    sort_order: Optional[str] = None,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Access-controlled retrieval of blacklisted & restricted visitors with date range filtering."""
    effective_school_id = _get_school_id(current_user, school_id)
    params = {
        "search": search or "",
        "status": status or "All",
        "location": location or "All Locations",
        "category": category or reason or "All",
        "reason": reason or category or "All",
        "date_from": date_from,
        "date_to": date_to,
        "page": page,
        "page_size": page_size,
        "sort_by": sort_by or "created_at",
        "sort_order": sort_order or "DESC",
    }
    try:
        rows = await exec_sql(
            "SELECT public.fn_visitors_list_restrictions(%s::UUID, %s::JSONB) AS result;",
            (effective_school_id, json.dumps(params))
        )
        if rows and rows[0].get("result"):
            res = rows[0]["result"]
            return {
                "success": True,
                "data": _serialize_val(res.get("records", [])),
                "pagination": _normalize_pagination(res.get("pagination", {}), page=page, page_size=page_size)
            }
        return {"success": True, "data": [], "pagination": _normalize_pagination({}, page=page, page_size=page_size)}
    except Exception as e:
        logger.error(f"Error listing restrictions: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/restrictions/{restriction_id}/details")
@restrictions_router.get("/{restriction_id}/details")
async def get_restriction_details(
    restriction_id: str,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Get 360 degree restriction details, attempted entries, and restriction history for right drawer."""
    effective_school_id = _get_school_id(current_user, school_id)
    try:
        rows = await exec_sql(
            "SELECT public.fn_visitors_get_restriction_details(%s::UUID, %s::UUID) AS details;",
            (effective_school_id, restriction_id)
        )
        if rows and rows[0].get("details"):
            res = rows[0]["details"]
            if not res.get("success"):
                raise HTTPException(status_code=404, detail=res.get("error", "Restriction not found"))
            return {"success": True, "data": _serialize_val(res)}
        raise HTTPException(status_code=404, detail="Restriction not found")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching restriction details: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 15. Create Restriction (Flag / Blacklist Visitor)
@router.post("/restrictions")
@restrictions_router.post("")
async def create_restriction(
    payload: RestrictionCreatePayload,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Submit access restriction request or add visitor to blacklist."""
    effective_school_id = _get_school_id(current_user, school_id)
    try:
        rows = await exec_sql(
            "SELECT public.fn_visitors_create_restriction(%s::UUID, %s::JSONB) AS result;",
            (effective_school_id, json.dumps(payload.dict()))
        )
        if rows and rows[0].get("result"):
            res = rows[0]["result"]
            if not res.get("success"):
                raise HTTPException(status_code=400, detail=res.get("detail"))
            return {"success": True, "data": _serialize_val(res)}
        raise HTTPException(status_code=500, detail="Failed to create restriction")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating restriction: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 15b. Update Restriction Details
@router.patch("/restrictions/{restriction_id}")
@restrictions_router.patch("/{restriction_id}")
async def update_restriction(
    restriction_id: str,
    payload: RestrictionUpdatePayload,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Update restriction fields (reason category, scope, valid till, remarks)."""
    effective_school_id = _get_school_id(current_user, school_id)
    body = payload.dict()
    if not body.get("updated_by_name"):
        body["updated_by_name"] = current_user.get("full_name", "Administrator")
    try:
        rows = await exec_sql(
            "SELECT public.fn_visitors_update_restriction(%s::UUID, %s::UUID, %s::JSONB) AS result;",
            (effective_school_id, restriction_id, json.dumps(body))
        )
        if rows and rows[0].get("result"):
            res = rows[0]["result"]
            if not res.get("success"):
                raise HTTPException(status_code=400, detail=res.get("detail"))
            return {"success": True, "data": _serialize_val(res)}
        raise HTTPException(status_code=400, detail="Failed to update restriction")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating restriction: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 16. Lift Restriction
@router.post("/restrictions/{restriction_id}/lift")
@restrictions_router.post("/{restriction_id}/lift")
async def lift_restriction(
    restriction_id: str,
    payload: RestrictionLiftPayload,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Lift active blacklist restriction with documented administrative justification."""
    effective_school_id = _get_school_id(current_user, school_id)
    lifter = payload.lifted_by_name or current_user.get("full_name", "Administrator")
    try:
        rows = await exec_sql(
            "SELECT public.fn_visitors_lift_restriction(%s::UUID, %s::UUID, %s, %s) AS result;",
            (effective_school_id, restriction_id, lifter, payload.reason)
        )
        if rows and rows[0].get("result") and rows[0]["result"].get("success"):
            return {"success": True, "status": "LIFTED"}
        raise HTTPException(status_code=400, detail="Failed to lift restriction")
    except Exception as e:
        logger.error(f"Error lifting restriction: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 16b. Unblock Visitor (by visitor profile ID)
@router.post("/{visitor_id}/unblock")
@router.post("/visitors/{visitor_id}/unblock")
@router.post("/restrictions/unblock-visitor")
@restrictions_router.post("/unblock-visitor")
async def unblock_visitor(
    visitor_id: Optional[str] = None,
    payload: Optional[VisitorUnblockPayload] = None,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Lift active blacklist restriction by visitor profile id."""
    effective_school_id = _get_school_id(current_user, school_id)
    target_visitor_id = visitor_id or (payload.visitor_id if payload else None)
    if not target_visitor_id:
        raise HTTPException(status_code=400, detail="visitor_id is required")
    lifter = (payload.lifted_by_name if payload else None) or current_user.get("full_name", "Director / Principal")
    reason = (payload.reason if payload else None) or "Administrative review completed; access restored"
    try:
        rows = await exec_sql(
            "SELECT public.fn_visitors_lift_visitor_restriction(%s::UUID, %s::UUID, %s, %s) AS result;",
            (effective_school_id, target_visitor_id, lifter, reason)
        )
        if rows and rows[0].get("result") and rows[0]["result"].get("success"):
            return {"success": True, "status": "LIFTED"}
        raise HTTPException(status_code=400, detail="Failed to unblock visitor")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error unblocking visitor: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 16c. Check Restriction Eligibility (Gate Entry Access Control)
@router.post("/restrictions/check-eligibility")
@restrictions_router.post("/check-eligibility")
async def check_restriction_eligibility(
    payload: RestrictionEligibilityCheckPayload,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Check if a visitor is blacklisted or restricted at a given location and log attempt."""
    effective_school_id = _get_school_id(current_user, school_id)
    try:
        rows = await exec_sql(
            "SELECT public.fn_visitors_check_restriction_eligibility(%s::UUID, %s::UUID, %s, %s) AS result;",
            (effective_school_id, payload.visitor_id, payload.phone, payload.location or "Main Gate")
        )
        if rows and rows[0].get("result"):
            return {"success": True, "data": _serialize_val(rows[0]["result"])}
        return {"success": True, "data": {"is_restricted": False}}
    except Exception as e:
        logger.error(f"Error checking restriction eligibility: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 17. Verify Gate Pass (QR Code Scanner)
@router.post("/gate-passes/verify")
@gate_passes_router.post("/verify")
async def verify_gate_pass(
    payload: GatePassVerifyPayload,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Verify QR code scanned gate pass token against database authorization via stored procedure."""
    effective_school_id = _get_school_id(current_user, school_id)
    token = payload.token_or_ref.strip()
    try:
        rows = await exec_sql(
            "SELECT public.fn_visitors_verify_gate_pass(%s::UUID, %s) AS result;",
            (effective_school_id, token)
        )
        if rows and rows[0].get("result"):
            return _serialize_val(rows[0]["result"])
        return {
            "success": False,
            "is_valid": False,
            "message": f"Invalid or unrecognized gate pass '{token}'."
        }
    except Exception as e:
        logger.error(f"Error verifying gate pass: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 17b. Generate Batch Gate Passes for Selected Visitor Profiles
@router.post("/gate-passes/generate-batch")
@gate_passes_router.post("/generate-batch")
async def generate_batch_gate_passes(
    payload: BatchGatePassPayload,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Generate official gate passes and visit records for selected visitor profiles via stored procedure."""
    effective_school_id = _get_school_id(current_user, school_id)
    if not payload.visitor_ids:
        raise HTTPException(status_code=400, detail="At least one visitor profile must be selected.")

    try:
        payload_json = json.dumps(payload.dict())
        rows = await exec_sql(
            "SELECT public.fn_visitors_generate_batch_gate_passes(%s::UUID, %s::JSONB) AS result;",
            (effective_school_id, payload_json)
        )
        if not rows or not rows[0].get("result"):
            raise HTTPException(status_code=500, detail="Failed to generate batch gate passes.")

        res = rows[0]["result"]
        # Attach instant base64 QR codes to the generated passes for seamless UI rendering
        if res.get("data") and isinstance(res["data"], list):
            for item in res["data"]:
                p_num = item.get("pass_number")
                if p_num:
                    item["qr_code_base64"] = generate_qr_base64(p_num)

        return _serialize_val(res)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error generating batch gate passes: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 17c. Crisp 300x300 PNG QR Code Image Stream
@router.get("/gate-passes/{pass_number}/qr.png")
@gate_passes_router.get("/{pass_number}/qr.png")
async def get_gate_pass_qr_png(
    pass_number: str
):
    """Stream a high-definition 300x300 PNG QR code image for a gate pass."""
    try:
        clean_pass = pass_number.strip()
        if clean_pass.lower().endswith(".png"):
            clean_pass = clean_pass[:-4].strip()
        img_bytes = generate_qr_bytes(clean_pass)
        return Response(
            content=img_bytes,
            media_type="image/png",
            headers={
                "Cache-Control": "public, max-age=86400",
                "Content-Disposition": f'inline; filename="{clean_pass}_qr.png"'
            }
        )
    except Exception as e:
        logger.error(f"Error generating QR image for {pass_number}: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 17d. Computer Vision QR Code Image Scanner
@router.post("/gate-passes/scan-image")
@gate_passes_router.post("/scan-image")
async def scan_gate_pass_image(
    payload: GatePassScanImagePayload,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Scan and decode QR code from base64 image data using OpenCV computer vision and verify via stored procedure."""
    effective_school_id = _get_school_id(current_user, school_id)
    raw_b64 = payload.image_base64.strip()
    if "," in raw_b64:
        raw_b64 = raw_b64.split(",", 1)[1]

    # Clean whitespace and sanitize base64 padding
    raw_b64 = re.sub(r"\s+", "", raw_b64)
    missing_padding = len(raw_b64) % 4
    if missing_padding:
        raw_b64 += "=" * (4 - missing_padding)

    try:
        image_bytes = base64.b64decode(raw_b64)
    except Exception as e:
        return {
            "success": False,
            "is_valid": False,
            "message": f"Invalid base64 image encoding: {e}"
        }

    decoded_text = decode_qr_from_bytes(image_bytes)
    if not decoded_text:
        return {
            "success": False,
            "is_valid": False,
            "message": "No valid QR code could be detected in the provided image. Please ensure the QR code is clearly visible and well-lit."
        }

    try:
        rows = await exec_sql(
            "SELECT public.fn_visitors_verify_gate_pass(%s::UUID, %s) AS result;",
            (effective_school_id, decoded_text)
        )
        if rows and rows[0].get("result"):
            result_obj = dict(rows[0]["result"])
            result_obj["decoded_text"] = decoded_text
            return _serialize_val(result_obj)
        return {
            "success": False,
            "is_valid": False,
            "decoded_text": decoded_text,
            "message": f"QR code decoded '{decoded_text}', but no matching gate pass was found in the system."
        }
    except Exception as e:
        logger.error(f"Error processing decoded pass in scan_gate_pass_image: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 17e. Execute Gate Check-In / Check-Out via QR Scan
@router.post("/gate-passes/{pass_number}/scan-action")
@gate_passes_router.post("/{pass_number}/scan-action")
async def execute_gate_pass_scan_action(
    pass_number: str,
    payload: GatePassScanActionPayload,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Execute gate check-in or check-out for a verified gate pass via stored procedure."""
    effective_school_id = _get_school_id(current_user, school_id)
    clean_pass = pass_number.strip()
    if clean_pass.lower().endswith(".png"):
        clean_pass = clean_pass[:-4].strip()

    action = payload.action.upper()
    if action not in ("CHECK_IN", "CHECK_OUT"):
        raise HTTPException(status_code=400, detail="Action must be CHECK_IN or CHECK_OUT")

    try:
        body = payload.dict()
        if not body.get("operator_name"):
            body["operator_name"] = current_user.get("full_name", "Gate Security")

        rows = await exec_sql(
            "SELECT public.fn_visitors_scan_gate_pass_action(%s::UUID, %s, %s::JSONB) AS result;",
            (effective_school_id, clean_pass, json.dumps(body))
        )
        if not rows or not rows[0].get("result"):
            raise HTTPException(status_code=500, detail="Failed to execute gate scan action.")

        res = rows[0]["result"]
        if not res.get("success"):
            status_code = 404 if "not found" in res.get("message", "").lower() else 400
            raise HTTPException(status_code=status_code, detail=res.get("message", "Action failed."))

        return _serialize_val(res)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error executing scan action for pass {clean_pass}: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 17f. List Visitor Profiles (For View Visitors Profile Popup)
@router.get("/profiles")
async def list_visitor_profiles(
    search: Optional[str] = None,
    visitor_type: Optional[str] = None,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """List all visitor profiles with search, filter, and visit statistics via stored procedure."""
    effective_school_id = _get_school_id(current_user, school_id)
    try:
        rows = await exec_sql(
            "SELECT public.fn_visitors_list_profiles(%s::UUID, %s, %s, %s::INT, %s::INT) AS result;",
            (effective_school_id, search, visitor_type, page, page_size)
        )
        if rows and rows[0].get("result"):
            return _serialize_val(rows[0]["result"])
        return {
            "success": True,
            "data": [],
            "pagination": {"page": page, "page_size": page_size, "total_records": 0, "total_pages": 1}
        }
    except Exception as e:
        logger.error(f"Error fetching visitor profiles: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 17g. Create or Update Visitor Profile Inline
@router.post("/profiles")
async def create_visitor_profile(
    payload: VisitorProfileCreatePayload,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Create a new visitor profile or update existing profile via stored procedure."""
    effective_school_id = _get_school_id(current_user, school_id)
    try:
        rows = await exec_sql(
            "SELECT public.fn_visitors_upsert_profile(%s::UUID, %s::JSONB) AS result;",
            (effective_school_id, json.dumps(payload.dict()))
        )
        if rows and rows[0].get("result"):
            return _serialize_val(rows[0]["result"])
        raise HTTPException(status_code=500, detail="Failed to save visitor profile.")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating visitor profile: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 18. Campus Checkpoints / Locations
@router.get("/locations")
async def get_locations(
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Retrieve active visitor checkpoints via stored procedure."""
    effective_school_id = _get_school_id(current_user, school_id)
    try:
        rows = await exec_sql(
            "SELECT public.fn_visitors_get_locations(%s::UUID) AS result;",
            (effective_school_id,)
        )
        if rows and rows[0].get("result"):
            return _serialize_val(rows[0]["result"])
        return {"success": True, "data": []}
    except Exception as e:
        logger.error(f"Error fetching locations: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 19. Search Existing Visitors (Autocomplete on Registration)
@router.get("/search-existing")
async def search_existing_visitors(
    query: str = Query(..., min_length=1),
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Search existing visitor profiles in this institution to reuse profiles and prevent duplicates."""
    effective_school_id = _get_school_id(current_user, school_id)
    try:
        rows = await exec_sql(
            "SELECT public.fn_visitors_search_existing(%s::UUID, %s) AS results;",
            (effective_school_id, query)
        )
        if rows and rows[0].get("results"):
            return {"success": True, "data": _serialize_val(rows[0]["results"])}
        return {"success": True, "data": []}
    except Exception as e:
        logger.error(f"Error searching existing visitors: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 20. CSV Export of Visitor Log
@router.get("/reports/export")
@router.post("/reports/export")
async def export_visitors_log(
    search: Optional[str] = None,
    location: Optional[str] = None,
    category: Optional[str] = None,
    status: Optional[str] = None,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Export filtered visitor log to streaming CSV."""
    effective_school_id = _get_school_id(current_user, school_id)
    params = {
        "search": search or "",
        "location": location or "All",
        "category": category or "All",
        "status": status or "All",
        "date_from": date_from,
        "date_to": date_to,
        "page": 1,
        "page_size": 1000
    }
    try:
        rows = await exec_sql(
            "SELECT public.fn_visitors_list_visits(%s::UUID, %s::JSONB) AS result;",
            (effective_school_id, json.dumps(params))
        )
        records = []
        if rows and rows[0].get("result"):
            records = rows[0]["result"].get("records", [])

        output = io.StringIO()
        writer = csv.writer(output)
        writer.writerow([
            "Visit Number", "Visitor Name", "Phone", "Category", "Purpose",
            "Location", "Host", "Check In", "Expected Out", "Actual Exit",
            "Status", "Vehicle Number", "Remarks"
        ])

        for r in records:
            writer.writerow([
                r.get("visit_number", ""),
                r.get("visitor_name", ""),
                r.get("phone", ""),
                r.get("category", ""),
                r.get("purpose", ""),
                r.get("location", ""),
                r.get("host_name", ""),
                r.get("check_in_at", ""),
                r.get("expected_out_at", ""),
                r.get("actual_check_out_at", ""),
                r.get("status", ""),
                r.get("vehicle_number", ""),
                r.get("remarks", "")
            ])

        output.seek(0)
        return StreamingResponse(
            iter([output.getvalue()]),
            media_type="text/csv",
            headers={"Content-Disposition": f"attachment; filename=visitors_log_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"}
        )
    except Exception as e:
        logger.error(f"Error exporting visitors log: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 21. Smart Host Search (Students, Teachers, Staff, and Hostel Residents)
@router.get("/hosts/search")
async def search_hosts(
    query: str = Query(..., min_length=1),
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """
    Intelligent cross-module host search for visitor registration and scheduling.
    Searches:
      1. Students: pulls class, section, roll number, parent details, and active hostel room/bed.
      2. Staff / Faculty: pulls department, designation, employee ID, and contact info.
      3. Active Hostel Outing Passes: indicates if a student has an approved outing gate pass.
    """
    effective_school_id = _get_school_id(current_user, school_id)
    clean_q = f"%{query.strip()}%"

    try:
        sql = """
        SELECT 
            p.id,
            p.full_name,
            p.role,
            p.class,
            p.department,
            p.designation,
            p.roll_number,
            p.admission_number,
            p.employee_id,
            p.phone,
            p.email,
            p.avatar_url,
            p.father_name,
            p.mother_name,
            -- Hostel resident check
            ha.room_id,
            hr.room_number AS hostel_room,
            hb.name AS hostel_name,
            ha.allocation_status AS hostel_status,
            -- Active Outing pass check for today
            (
                SELECT lo.request_number
                FROM public.hostel_leave_outing_requests lo
                WHERE lo.student_id = p.id
                  AND lo.school_id = p.school_id
                  AND lo.status = 'APPROVED'
                  AND CURRENT_DATE BETWEEN lo.start_at::date AND lo.expected_return_at::date
                LIMIT 1
            ) AS active_outing_pass
        FROM public.profiles p
        LEFT JOIN public.hostel_allocations ha 
            ON ha.student_id = p.id 
            AND ha.deleted_at IS NULL 
            AND ha.allocation_status IN ('CHECKED_IN', 'CONFIRMED')
        LEFT JOIN public.hostel_rooms hr ON ha.room_id = hr.id
        LEFT JOIN public.hostel_buildings hb ON ha.building_id = hb.id
        WHERE p.school_id = %s::UUID
          AND (
              p.full_name ILIKE %s
              OR COALESCE(p.admission_number, '') ILIKE %s
              OR COALESCE(p.employee_id, '') ILIKE %s
              OR COALESCE(p.phone, '') ILIKE %s
              OR COALESCE(p.class, '') ILIKE %s
              OR COALESCE(p.department, '') ILIKE %s
          )
        ORDER BY 
            CASE WHEN p.full_name ILIKE %s THEN 0 ELSE 1 END,
            p.full_name ASC
        LIMIT 25;
        """
        rows = await exec_sql(sql, (effective_school_id, clean_q, clean_q, clean_q, clean_q, clean_q, clean_q, f"{query.strip()}%"))
        results = []
        for r in rows:
            is_student = (r.get("role") or "").lower() == "student"
            if is_student:
                cls_info = f"Class {r.get('class')}" if r.get('class') else "Student"
                roll_info = f" (Roll: {r.get('roll_number')})" if r.get('roll_number') else ""
                hostel_info = f" | Hostel: {r.get('hostel_name')} ({r.get('hostel_room')})" if r.get('hostel_room') else ""
                dept_desc = f"{cls_info}{roll_info}"
                details_text = f"Adm: {r.get('admission_number') or 'N/A'}{hostel_info}"
            else:
                dept_desc = r.get("department") or r.get("designation") or "Faculty / Staff"
                emp_info = f"Emp ID: {r.get('employee_id') or 'N/A'}"
                details_text = f"{r.get('role', 'Staff').title()} | {emp_info}"

            results.append({
                "id": str(r["id"]),
                "name": r["full_name"],
                "role": r.get("role") or "staff",
                "host_type": "STUDENT" if is_student else "STAFF",
                "department": dept_desc,
                "phone": r.get("phone") or "",
                "email": r.get("email") or "",
                "avatar_url": r.get("avatar_url"),
                "details": details_text,
                "is_hostel_resident": bool(r.get("hostel_room")),
                "hostel_name": r.get("hostel_name"),
                "hostel_room": r.get("hostel_room"),
                "active_outing_pass": r.get("active_outing_pass"),
            })

        return {"success": True, "count": len(results), "data": results}
    except Exception as e:
        logger.error(f"Error searching hosts: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 22. Instant Blacklist & Existing Visitor Check (Realtime Debounce Intercept)
@router.get("/restrictions/check-instant")
async def check_instant_restriction(
    phone: Optional[str] = None,
    id_number: Optional[str] = None,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """
    Real-time pre-submission check for visitor registration / appointment scheduling.
    Instantly alerts guard if phone or ID is on active restriction list and fetches
    existing visitor profile to auto-populate the form.
    """
    effective_school_id = _get_school_id(current_user, school_id)
    clean_phone = re.sub(r"\D", "", phone or "")[-10:] if phone else ""
    clean_id = re.sub(r"\s+", "", id_number or "").upper() if id_number else ""

    if not clean_phone and not clean_id:
        return {"success": True, "is_restricted": False, "profile": None}

    try:
        # Check active restriction
        sql_res = """
        SELECT 
            r.id,
            r.reason_category,
            r.scope_type,
            r.scope_name,
            r.confidential_notes,
            r.remarks,
            r.status,
            r.blocked_on,
            r.valid_till_text,
            r.is_permanent,
            r.expires_at,
            p.id AS visitor_id,
            p.full_name AS visitor_name,
            p.phone,
            p.id_type,
            p.id_number_masked,
            p.photo_url
        FROM public.visitor_restrictions r
        JOIN public.visitor_profiles p ON r.visitor_id = p.id
        WHERE r.school_id = %s::UUID
          AND r.status = 'ACTIVE'
          AND (
              (%s != '' AND RIGHT(REGEXP_REPLACE(p.phone, '\D', '', 'g'), 10) = %s)
              OR
              (%s != '' AND UPPER(REGEXP_REPLACE(p.id_number_masked, '\s+', '', 'g')) = %s)
          )
        ORDER BY r.created_at DESC
        LIMIT 1;
        """
        rows_res = await exec_sql(sql_res, (effective_school_id, clean_phone, clean_phone, clean_id, clean_id))
        
        # Check existing profile for auto-population
        sql_prof = """
        SELECT 
            p.id,
            p.full_name,
            p.phone,
            p.email,
            p.visitor_type,
            p.id_type,
            p.id_number_masked,
            p.photo_url,
            p.company,
            p.designation,
            p.is_blacklisted
        FROM public.visitor_profiles p
        WHERE p.school_id = %s::UUID
          AND (
              (%s != '' AND RIGHT(REGEXP_REPLACE(p.phone, '\D', '', 'g'), 10) = %s)
              OR
              (%s != '' AND UPPER(REGEXP_REPLACE(p.id_number_masked, '\s+', '', 'g')) = %s)
          )
        LIMIT 1;
        """
        rows_prof = await exec_sql(sql_prof, (effective_school_id, clean_phone, clean_phone, clean_id, clean_id))
        profile_data = _serialize_val(rows_prof[0]) if rows_prof else None

        if rows_res:
            res = rows_res[0]
            return {
                "success": True,
                "is_restricted": True,
                "restriction": _serialize_val(res),
                "profile": profile_data
            }
        
        return {
            "success": True,
            "is_restricted": False,
            "profile": profile_data
        }
    except Exception as e:
        logger.error(f"Error checking instant restriction: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 23. Executive Management Summary Report
@router.get("/reports/executive-summary")
async def get_executive_summary_report(
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    school_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Generate comprehensive executive summary data for visitors management auditing and board reports."""
    effective_school_id = _get_school_id(current_user, school_id)
    try:
        kpi_filter = {}
        if date_from:
            kpi_filter["date_from"] = date_from
        if date_to:
            kpi_filter["date_to"] = date_to
        kpis_row = await exec_sql(
            "SELECT public.fn_visitors_get_kpis(%s::UUID, %s::JSONB) AS result;",
            (effective_school_id, json.dumps(kpi_filter))
        )
        an_row = await exec_sql("SELECT public.fn_visitors_get_analytics(%s::UUID) AS result;", (effective_school_id,))
        rest_kpis = await exec_sql(
            "SELECT public.fn_visitors_get_blacklisted_kpis(%s::UUID, %s::TIMESTAMPTZ, %s::TIMESTAMPTZ) AS result;",
            (effective_school_id, date_from, date_to)
        )
        sch_kpis = await exec_sql(
            "SELECT public.fn_visitors_get_scheduled_kpis(%s::UUID, %s::TIMESTAMPTZ, %s::TIMESTAMPTZ) AS result;",
            (effective_school_id, date_from, date_to)
        )
        
        return {
            "success": True,
            "data": {
                "institution": "EduSHAMIIT ERP Enterprise Campus",
                "generated_at": datetime.now().isoformat(),
                "generated_by": current_user.get("full_name", "System Administrator"),
                "date_range": {"from": date_from, "to": date_to},
                "kpis": _serialize_val(kpis_row[0]["result"] if kpis_row else {}),
                "scheduled_kpis": _serialize_val(sch_kpis[0]["result"] if sch_kpis else {}),
                "security_kpis": _serialize_val(rest_kpis[0]["result"] if rest_kpis else {}),
                "analytics": _serialize_val(an_row[0]["result"] if an_row else {})
            }
        }
    except Exception as e:
        logger.error(f"Error fetching executive summary: {e}")
        raise HTTPException(status_code=500, detail=str(e))

