"""
Production-Grade Space Booking Management API for EduSHAMIIT ERP.
Provides high-performance endpoints executing PostgreSQL stored procedures and functions:
- Space Booking KPIs (Total, Confirmed, Pending, Rejected, Current Usage, Utilization)
- Availability Timeline Grid (8 AM - 5 PM time slot breakdown for classrooms, halls, labs)
- Booking Requests Table with Status Filtering (All, Pending, Approved, Rejected), Search & Pagination
- Conflict Detection Engine (with setup/cleanup buffer intervals)
- Multi-Level Approval Workflows (Approve, Reject, Cancel, Remarks)
- Check-In & Check-Out Execution (Space condition tracking & audit logs)
- Utilization Breakdown Analytics (Donut Chart stats: In Use, Available, Maintenance, Not Bookable)
- Streaming CSV Export
"""

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any, Union
from datetime import datetime, date, time
from decimal import Decimal
import io
import csv
import json
import uuid
import logging
import asyncio
import psycopg2
from psycopg2.extras import RealDictCursor, register_uuid

register_uuid()

from app.config import settings
from app.middleware.auth import get_current_user

logger = logging.getLogger(__name__)
router = APIRouter()


# ============================================================================
# DATABASE EXECUTION & UTILITY HELPERS
# ============================================================================

async def exec_sql(sql: str, params: tuple = (), fetch: bool = True) -> List[Dict[str, Any]]:
    """Execute raw parameterized SQL query asynchronously via psycopg2."""
    def _run():
        conn = psycopg2.connect(settings.DATABASE_URL, connect_timeout=5)
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(sql, params)
                if fetch and cur.description:
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
    if isinstance(val, list):
        return [_serialize_val(x) for x in val]
    if isinstance(val, dict):
        return {k: _serialize_val(v) for k, v in val.items()}
    return val


def get_school_id(current_user: Optional[Dict[str, Any]]) -> str:
    """Extract authenticated school_id with fallback to demo school ID."""
    if current_user and current_user.get("school_id"):
        return str(current_user["school_id"])
    return "11111111-1111-1111-1111-111111111111"


def get_user_id(current_user: Optional[Dict[str, Any]]) -> Optional[str]:
    """Extract authenticated user profile ID."""
    if current_user and current_user.get("id"):
        return str(current_user["id"])
    return None


# ============================================================================
# PYDANTIC SCHEMAS
# ============================================================================

class SpaceBookingCreateUpdateSchema(BaseModel):
    id: Optional[str] = None
    title: str = Field(..., min_length=2, max_length=250)
    description: Optional[str] = None
    purpose: str = Field(default="Academic")
    category: Optional[str] = "Academic"
    booking_type: Optional[str] = "Internal"
    priority: Optional[str] = "Normal"
    visibility: Optional[str] = "Public"
    building_id: Optional[str] = None
    floor_id: Optional[str] = None
    room_id: str
    booking_date: date
    start_time: str # "08:00:00" or "08:00"
    end_time: str
    setup_minutes: Optional[int] = 0
    cleanup_minutes: Optional[int] = 0
    organizer_name: str
    organizer_email: Optional[str] = None
    organizer_phone: Optional[str] = None
    organizer_role: Optional[str] = "Faculty"
    organizer_department: Optional[str] = None
    attendee_count: Optional[int] = 1
    special_instructions: Optional[str] = None
    amenities_required: Optional[List[str]] = []
    status: Optional[str] = "Pending"


class ApprovalDecisionSchema(BaseModel):
    action: str = Field(..., pattern="^(APPROVE|REJECT|CANCEL)$")
    comments: Optional[str] = None


class CheckinCheckoutSchema(BaseModel):
    action: str = Field(..., pattern="^(CHECK_IN|CHECK_OUT)$")
    condition: Optional[str] = "Good"
    remarks: Optional[str] = None


# ============================================================================
# API ENDPOINTS
# ============================================================================

@router.get("/kpis", summary="Space Booking High-Level KPI Summary")
async def get_booking_kpis(
    target_date: Optional[date] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    query_date = target_date or date(2026, 3, 15)
    
    sql = "SELECT public.fn_space_booking_get_kpis(%s::UUID, %s::DATE) AS kpis;"
    rows = await exec_sql(sql, (school_id, query_date))
    kpis = rows[0]["kpis"] if rows else {}
    return {
        "success": True,
        "school_id": school_id,
        "date": query_date.isoformat(),
        "data": _serialize_val(kpis)
    }


@router.get("/timeline", summary="Space Availability & Booking Interactive Timeline Grid")
async def get_availability_timeline(
    target_date: Optional[date] = Query(None),
    building_id: Optional[str] = Query(None),
    room_type: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    query_date = target_date or date(2026, 3, 15)
    
    b_id = building_id if (building_id and str(building_id).strip().lower() not in ("all", "none", "")) else None
    r_type = room_type if (room_type and str(room_type).strip().lower() not in ("all", "none", "")) else None

    sql = "SELECT public.fn_space_booking_get_availability_timeline(%s::UUID, %s::UUID, %s::VARCHAR, %s::DATE) AS timeline;"
    rows = await exec_sql(sql, (school_id, b_id, r_type, query_date))
    timeline = rows[0]["timeline"] if rows else []
    return {
        "success": True,
        "school_id": school_id,
        "date": query_date.isoformat(),
        "rooms": _serialize_val(timeline)
    }


@router.get("/requests", summary="Paged Space Booking Requests with Tabs and Filters")
async def get_booking_requests(
    status: Optional[str] = Query(None, description="All, Pending, Approved, Rejected"),
    building_id: Optional[str] = Query(None),
    room_type: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    date_from: Optional[date] = Query(None),
    date_to: Optional[date] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    st = status if (status and str(status).strip().lower() not in ("all", "none", "")) else None
    b_id = building_id if (building_id and str(building_id).strip().lower() not in ("all", "none", "")) else None
    r_type = room_type if (room_type and str(room_type).strip().lower() not in ("all", "none", "")) else None
    search_term = search.strip() if (search and isinstance(search, str) and search.strip()) else None

    sql = """
        SELECT public.fn_space_booking_list(
            %s::UUID, %s::VARCHAR, %s::UUID, %s::VARCHAR, 
            %s::VARCHAR, %s::DATE, %s::DATE, %s::INT, %s::INT
        ) AS result;
    """
    rows = await exec_sql(sql, (school_id, st, b_id, r_type, search_term, date_from, date_to, page, page_size))
    result = rows[0]["result"] if rows else {"items": [], "total_count": 0, "page": page, "page_size": page_size}
    return {
        "success": True,
        "data": _serialize_val(result)
    }


@router.get("/details/{booking_id}", summary="Inspect Specific Booking with Approvals and Audit Log")
async def get_booking_details(
    booking_id: str,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    sql = "SELECT public.fn_space_booking_get_details(%s::UUID, %s::UUID) AS details;"
    rows = await exec_sql(sql, (booking_id, school_id))
    if not rows or not rows[0]["details"]:
        raise HTTPException(status_code=404, detail="Space booking not found")
    return {
        "success": True,
        "data": _serialize_val(rows[0]["details"])
    }


@router.post("/book", summary="Create or Update Space Booking")
async def create_or_update_booking(
    payload: SpaceBookingCreateUpdateSchema,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    user_id = get_user_id(current_user)

    data_dict = payload.dict()
    data_dict["school_id"] = school_id
    data_dict["user_id"] = user_id

    # Format time strings if provided without seconds
    if len(data_dict["start_time"]) == 5:
        data_dict["start_time"] += ":00"
    if len(data_dict["end_time"]) == 5:
        data_dict["end_time"] += ":00"

    payload_json = json.dumps(data_dict, default=str)
    sql = "SELECT public.fn_space_booking_create_or_update(%s::JSONB) AS result;"
    rows = await exec_sql(sql, (payload_json,))
    result = rows[0]["result"] if rows else {"success": False, "message": "Failed to process booking"}

    if not result.get("success"):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT if result.get("error") == "CONFLICT" else status.HTTP_400_BAD_REQUEST,
            detail=result.get("message", "Booking could not be created.")
        )

    return {
        "success": True,
        "data": _serialize_val(result)
    }


@router.post("/decision/{booking_id}", summary="Approve, Reject, or Cancel Booking Request")
async def decide_booking_approval(
    booking_id: str,
    decision: ApprovalDecisionSchema,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    user_id = get_user_id(current_user)

    sql = "SELECT public.fn_space_booking_decide_approval(%s::UUID, %s::UUID, %s::VARCHAR, %s::UUID, %s::TEXT) AS result;"
    rows = await exec_sql(sql, (booking_id, school_id, decision.action, user_id, decision.comments))
    result = rows[0]["result"] if rows else {"success": False, "message": "Failed to decide approval"}

    if not result.get("success"):
        raise HTTPException(status_code=400, detail=result.get("message", "Action failed"))

    return {
        "success": True,
        "data": _serialize_val(result)
    }


@router.post("/checkin-checkout/{booking_id}", summary="Check-In or Check-Out Space Usage")
async def checkin_checkout_booking(
    booking_id: str,
    payload: CheckinCheckoutSchema,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    user_id = get_user_id(current_user)

    sql = "SELECT public.fn_space_booking_checkin_checkout(%s::UUID, %s::UUID, %s::VARCHAR, %s::UUID, %s::VARCHAR, %s::TEXT) AS result;"
    rows = await exec_sql(sql, (booking_id, school_id, payload.action, user_id, payload.condition, payload.remarks))
    result = rows[0]["result"] if rows else {"success": False, "message": "Failed to update checkin status"}

    if not result.get("success"):
        raise HTTPException(status_code=400, detail=result.get("message", "Action failed"))

    return {
        "success": True,
        "data": _serialize_val(result)
    }


@router.get("/utilization", summary="Space Utilization Breakdown (Donut Chart Analytics)")
async def get_space_utilization(
    target_date: Optional[date] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    query_date = target_date or date(2026, 3, 15)

    sql = "SELECT public.fn_space_booking_get_utilization_stats(%s::UUID, %s::DATE) AS stats;"
    rows = await exec_sql(sql, (school_id, query_date))
    stats = rows[0]["stats"] if rows else {}
    return {
        "success": True,
        "school_id": school_id,
        "date": query_date.isoformat(),
        "data": _serialize_val(stats)
    }


@router.get("/bookable-rooms", summary="List All Bookable Rooms for Booking Form Dropdowns")
async def get_bookable_rooms(
    building_id: Optional[str] = Query(None),
    room_type: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    sql = """
        SELECT 
            r.id, r.name, r.room_number, r.room_code, r.room_type, r.max_capacity,
            b.id AS building_id, b.name AS building_name, b.code AS building_code,
            f.id AS floor_id, f.name AS floor_name
        FROM public.rooms r
        JOIN public.buildings b ON r.building_id = b.id
        LEFT JOIN public.building_floors f ON r.floor_id = f.id
        WHERE r.school_id = %s::UUID
          AND r.deleted_at IS NULL
          AND r.is_bookable = TRUE
          AND (%s::UUID IS NULL OR r.building_id = %s::UUID)
          AND (%s::VARCHAR IS NULL OR %s::VARCHAR = 'All' OR r.room_type ILIKE %s::VARCHAR)
        ORDER BY b.name ASC, r.room_number ASC, r.name ASC;
    """
    b_id = building_id if (building_id and building_id != "all") else None
    r_type = room_type if (room_type and room_type != "All") else None
    rows = await exec_sql(sql, (school_id, b_id, b_id, r_type, r_type, r_type))
    return {
        "success": True,
        "data": _serialize_val(rows)
    }


@router.get("/export", summary="Stream Space Bookings as CSV")
async def export_space_bookings_csv(
    status: Optional[str] = Query(None),
    building_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    b_id = building_id if (building_id and building_id != "all") else None

    sql = """
        SELECT 
            sb.booking_ref, sb.title, r.name AS room_name, r.room_type, b.name AS building_name,
            sb.organizer_name, sb.organizer_role, sb.booking_date,
            TO_CHAR(sb.start_time, 'HH12:MI AM') AS start_time,
            TO_CHAR(sb.end_time, 'HH12:MI AM') AS end_time,
            sb.purpose, sb.status, sb.attendee_count, sb.created_at
        FROM public.space_bookings sb
        JOIN public.rooms r ON sb.room_id = r.id
        JOIN public.buildings b ON sb.building_id = b.id
        WHERE sb.school_id = %s::UUID
          AND sb.deleted_at IS NULL
          AND (%s::VARCHAR IS NULL OR sb.status ILIKE %s::VARCHAR)
          AND (%s::UUID IS NULL OR sb.building_id = %s::UUID)
        ORDER BY sb.booking_date DESC, sb.start_time DESC;
    """
    rows = await exec_sql(sql, (school_id, status, status, b_id, b_id))

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow([
        "Booking Ref", "Title", "Room Name", "Room Type", "Building",
        "Organizer", "Role", "Booking Date", "Start Time", "End Time",
        "Purpose", "Status", "Attendees", "Created At"
    ])
    for r in rows:
        writer.writerow([
            r.get("booking_ref"), r.get("title"), r.get("room_name"), r.get("room_type"),
            r.get("building_name"), r.get("organizer_name"), r.get("organizer_role"),
            r.get("booking_date"), r.get("start_time"), r.get("end_time"),
            r.get("purpose"), r.get("status"), r.get("attendee_count"), r.get("created_at")
        ])

    output.seek(0)
    filename = f"space_bookings_{date.today().isoformat()}.csv"
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )
