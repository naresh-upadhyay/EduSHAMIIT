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
from datetime import datetime, date, time, timedelta
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


def safe_uuid(val: Any) -> Optional[str]:
    """Safely parse UUID string, returning None for invalid values like 'all', 'b1', etc."""
    if not val or str(val).strip().lower() in ("all", "none", "", "undefined"):
        return None
    try:
        return str(uuid.UUID(str(val).strip()))
    except (ValueError, AttributeError):
        return None


def _parse_time_str(time_str: str) -> time:
    """Parse time string like '14:00', '14:00:00', '02:00 PM', '2:00 PM'."""
    clean = time_str.strip().upper()
    try:
        if "AM" in clean or "PM" in clean:
            return datetime.strptime(clean, "%I:%M %p").time()
    except Exception:
        pass
    try:
        if len(clean) == 5:
            return datetime.strptime(clean, "%H:%M").time()
        elif len(clean) == 8:
            return datetime.strptime(clean, "%H:%M:%S").time()
    except Exception:
        pass
    return time(14, 0)


# ============================================================================
# PYDANTIC SCHEMAS
# ============================================================================

class RecurringBookingCreateSchema(BaseModel):
    title: str = Field(..., min_length=2, max_length=250)
    room_id: Optional[str] = None
    facility_id: Optional[str] = None
    space_target_type: Optional[str] = "room"
    start_date: date
    end_date: Optional[date] = None
    days_of_week: Optional[List[int]] = [1, 3, 5]
    start_time: str
    end_time: str
    purpose: Optional[str] = "Academic"
    organizer_name: Optional[str] = "Faculty"
    organizer_role: Optional[str] = "Faculty"
    attendee_count: Optional[int] = 30

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
    room_id: Optional[str] = None
    facility_id: Optional[str] = None
    space_target_type: Optional[str] = "room"
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
    requested_by: Optional[str] = None
    attendee_count: Optional[int] = 1
    special_instructions: Optional[str] = None
    amenities_required: Optional[List[str]] = []
    status: Optional[str] = "Pending"
    is_recurring: Optional[bool] = False
    recurrence: Optional[Dict[str, Any]] = None
    allow_conflict: Optional[bool] = False


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
    query_date = target_date or date.today()
    
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
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    building_id: Optional[str] = Query(None),
    room_type: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    s_date = start_date or target_date or date.today()
    e_date = end_date or s_date
    
    b_id = safe_uuid(building_id)
    r_type = room_type if (room_type and str(room_type).strip().lower() not in ("all", "none", "")) else None

    sql = "SELECT public.fn_space_booking_get_availability_timeline(%s::UUID, %s::DATE, %s::DATE, %s::UUID, %s::VARCHAR) AS timeline;"
    rows = await exec_sql(sql, (school_id, s_date, e_date, b_id, r_type))
    timeline = rows[0]["timeline"] if rows else []
    return {
        "success": True,
        "school_id": school_id,
        "start_date": s_date.isoformat(),
        "end_date": e_date.isoformat(),
        "date": s_date.isoformat(),
        "rooms": _serialize_val(timeline)
    }


@router.get("/requests", summary="Paged Space Booking Requests with Tabs and Filters")
async def get_booking_requests(
    status: Optional[str] = Query(None, description="All, Pending, Approved, Rejected, Conflict"),
    building_id: Optional[str] = Query(None),
    room_type: Optional[str] = Query(None),
    purpose: Optional[str] = Query(None),
    priority: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    date_from: Optional[date] = Query(None),
    date_to: Optional[date] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    sort_by: Optional[str] = Query("booking_date"),
    sort_order: Optional[str] = Query("asc"),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    st = status if (status and str(status).strip().lower() not in ("all", "none", "")) else None
    b_id = safe_uuid(building_id)
    r_type = room_type if (room_type and str(room_type).strip().lower() not in ("all", "none", "")) else None
    purp = purpose if (purpose and str(purpose).strip().lower() not in ("all", "none", "")) else None
    prio = priority if (priority and str(priority).strip().lower() not in ("all", "none", "")) else None
    search_term = search.strip() if (search and isinstance(search, str) and search.strip()) else None
    s_by = sort_by.strip() if (sort_by and isinstance(sort_by, str) and sort_by.strip()) else "booking_date"
    s_order = sort_order.strip().lower() if (sort_order and isinstance(sort_order, str)) else "asc"

    sql = """
        SELECT public.fn_space_booking_list(
            p_school_id => %s::UUID,
            p_status => %s::VARCHAR,
            p_building_id => %s::UUID,
            p_room_type => %s::VARCHAR,
            p_search => %s::VARCHAR,
            p_date_from => %s::DATE,
            p_date_to => %s::DATE,
            p_page => %s::INT,
            p_page_size => %s::INT,
            p_purpose => %s::VARCHAR,
            p_priority => %s::VARCHAR,
            p_sort_by => %s::VARCHAR,
            p_sort_order => %s::VARCHAR
        ) AS result;
    """
    rows = await exec_sql(sql, (
        school_id, st, b_id, r_type, search_term, date_from, date_to,
        page, page_size, purp, prio, s_by, s_order
    ))
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
    allow_conflict = bool(payload.allow_conflict or data_dict.get("allow_conflict", False))
    data_dict["allow_conflict"] = allow_conflict

    try:
        # If recurrence settings are specified and not 'none', generate recurring series
        rec = data_dict.get("recurrence")
        if rec and isinstance(rec, dict) and rec.get("frequency") and rec.get("frequency") != "none":
            freq = str(rec.get("frequency", "weekly")).lower()
            days = rec.get("days_of_week") or [1, 2, 3, 4, 5, 6, 7]
            interval = max(int(rec.get("interval", 1)), 1)
            end_type = str(rec.get("end_type", "never")).lower()
            
            start_d = payload.booking_date
            end_d = start_d + timedelta(days=60)
            max_occ = 30
            if end_type == "date" and rec.get("until_date"):
                try:
                    end_d = datetime.strptime(str(rec["until_date"])[:10], "%Y-%m-%d").date()
                except Exception:
                    end_d = start_d + timedelta(days=60)
            elif end_type == "count" and rec.get("count"):
                count = max(int(rec["count"]), 1)
                max_occ = count
                if freq == "daily":
                    end_d = start_d + timedelta(days=count * interval + 5)
                elif freq in ("weekly", "weekdays"):
                    end_d = start_d + timedelta(weeks=count * interval + 2)
                elif freq == "monthly":
                    end_d = start_d + timedelta(days=count * 31 * interval + 10)
            else:
                end_d = start_d + timedelta(days=60)

            st = data_dict["start_time"]
            et = data_dict["end_time"]
            if len(st) == 5:
                st += ":00"
            if len(et) == 5:
                et += ":00"

            rec_payload = {
                "school_id": school_id,
                "user_id": user_id,
                "existing_booking_id": safe_uuid(data_dict.get("id")),
                "title": payload.title,
                "description": payload.description,
                "room_id": payload.room_id,
                "facility_id": payload.facility_id,
                "space_target_type": payload.space_target_type or ("facility" if payload.facility_id else "room"),
                "frequency": freq,
                "start_date": str(start_d),
                "end_date": str(end_d),
                "days_of_week": days,
                "start_time": st,
                "end_time": et,
                "setup_minutes": payload.setup_minutes or 0,
                "cleanup_minutes": payload.cleanup_minutes or 0,
                "purpose": payload.purpose,
                "category": payload.category or "Academic",
                "priority": payload.priority or "Normal",
                "organizer_name": payload.organizer_name,
                "organizer_role": payload.organizer_role,
                "organizer_email": payload.organizer_email,
                "organizer_phone": payload.organizer_phone,
                "attendee_count": payload.attendee_count or 30,
                "interval": interval,
                "end_type": end_type,
                "max_occurrences": max_occ,
                "allow_conflict": allow_conflict
            }
            rec_json = json.dumps(rec_payload, default=str)
            sql = "SELECT public.fn_space_booking_create_recurring(%s::JSONB) AS result;"
            rows = await exec_sql(sql, (rec_json,))
            result = rows[0]["result"] if rows else {"success": False, "message": "Failed to create recurring series"}
            if not result.get("success"):
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT if "conflict" in result.get("message", "").lower() else status.HTTP_400_BAD_REQUEST,
                    detail=result.get("message", "Recurring booking creation failed")
                )
            return {
                "success": True,
                "data": _serialize_val(result)
            }

        # Single Booking Flow
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
                detail=result.get("message", "Booking could not be created or updated.")
            )

        return {
            "success": True,
            "data": _serialize_val(result)
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.exception(f"Error creating/updating space booking: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to process space booking: {str(e)}"
        )


@router.put("/book/{booking_id}", summary="Update Existing Space Booking")
async def update_existing_booking(
    booking_id: str,
    payload: SpaceBookingCreateUpdateSchema,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    payload.id = booking_id
    return await create_or_update_booking(payload, current_user)


@router.delete("/{booking_id}", summary="Delete or Cancel Space Booking")
async def delete_space_booking(
    booking_id: str,
    delete_series: bool = Query(False),
    reason: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    user_id = get_user_id(current_user)

    sql = "SELECT public.fn_space_booking_delete(%s::UUID, %s::UUID, %s::UUID, %s::BOOLEAN, %s::TEXT) AS result;"
    rows = await exec_sql(sql, (school_id, booking_id, user_id, delete_series, reason or "Deleted by user"))
    result = rows[0]["result"] if rows else {"success": False, "message": "Failed to delete booking"}

    if not result.get("success"):
        raise HTTPException(status_code=400, detail=result.get("message", "Deletion failed"))

    return {
        "success": True,
        "message": result.get("message", "Booking deleted successfully"),
        "data": _serialize_val(result)
    }


@router.post("/recurring", summary="Generate Recurring Space Booking Series")
async def create_recurring_space_booking(
    payload: RecurringBookingCreateSchema,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    user_id = get_user_id(current_user)

    data_dict = payload.dict()
    data_dict["school_id"] = school_id
    data_dict["user_id"] = user_id

    if len(data_dict["start_time"]) == 5:
        data_dict["start_time"] += ":00"
    if len(data_dict["end_time"]) == 5:
        data_dict["end_time"] += ":00"

    payload_json = json.dumps(data_dict, default=str)
    sql = "SELECT public.fn_space_booking_create_recurring(%s::JSONB) AS result;"
    rows = await exec_sql(sql, (payload_json,))
    result = rows[0]["result"] if rows else {"success": False, "message": "Failed to create recurring series"}

    if not result.get("success"):
        raise HTTPException(status_code=400, detail=result.get("message", "Recurring booking creation failed"))

    return {
        "success": True,
        "data": _serialize_val(result)
    }


@router.get("/check-slot", summary="Real-time Space Availability & Conflict Check")
async def check_space_slot_availability(
    room_id: Optional[str] = Query(None),
    facility_id: Optional[str] = Query(None),
    booking_date: date = Query(..., alias="date"),
    start_time: str = Query(...),
    end_time: str = Query(...),
    setup_minutes: int = Query(0),
    cleanup_minutes: int = Query(0),
    exclude_booking_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Real-time conflict detection and free/busy query for space and time slot."""
    school_id = get_school_id(current_user)
    parsed_room_id = safe_uuid(room_id)
    parsed_facility_id = safe_uuid(facility_id)
    if not parsed_room_id and not parsed_facility_id:
        return {"has_conflict": False, "status": "FREE", "message": "Space not selected"}

    parsed_exclude = safe_uuid(exclude_booking_id)

    # Parse start and end times
    start_t = _parse_time_str(start_time)
    end_t = _parse_time_str(end_time)
    start_dt = datetime.combine(booking_date, start_t) - timedelta(minutes=setup_minutes)
    end_dt = datetime.combine(booking_date, end_t) + timedelta(minutes=cleanup_minutes)

    sql = """
    SELECT * FROM public.fn_space_booking_check_conflict(
        %s::UUID, %s::UUID, %s::TIMESTAMPTZ, %s::TIMESTAMPTZ, %s::UUID, TRUE, %s::UUID
    );
    """
    rows = await exec_sql(sql, (school_id, parsed_room_id, start_dt, end_dt, parsed_exclude, parsed_facility_id))
    if not rows:
        return {"has_conflict": False, "status": "FREE", "message": "Slot is free and available"}

    row = rows[0]
    has_conflict = bool(row.get("has_conflict", False))
    return {
        "has_conflict": has_conflict,
        "status": "BUSY" if has_conflict else "FREE",
        "conflict_type": row.get("conflict_type"),
        "conflicting_ref": row.get("conflicting_ref"),
        "conflicting_title": row.get("conflicting_title"),
        "conflicting_start": str(row.get("conflicting_start")) if row.get("conflicting_start") else None,
        "conflicting_end": str(row.get("conflicting_end")) if row.get("conflicting_end") else None,
        "message": f"Collides with {row.get('conflicting_title')}" if has_conflict else "Slot is free and available"
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
        if result.get("conflict"):
            return {
                "success": False,
                "conflict": True,
                "message": result.get("message", "Slot conflict detected with an approved booking"),
                "data": _serialize_val(result)
            }
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
    query_date = target_date or date.today()

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
    b_id = safe_uuid(building_id)
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
    b_id = safe_uuid(building_id)

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


@router.get("/requesters", summary="Search and List Space Booking Requesters from User Directory")
async def get_booking_requesters(
    search: Optional[str] = Query(None, description="Search by name, email, or role"),
    role: Optional[str] = Query(None, description="Filter by role"),
    limit: int = Query(50, ge=1, le=100),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    sql = """
        SELECT id, full_name, email, phone, role, department, avatar_url
        FROM public.profiles
        WHERE (school_id = %s::UUID OR school_id IS NULL)
          AND full_name IS NOT NULL AND TRIM(full_name) != ''
    """
    params: List[Any] = [school_id]
    if search and search.strip():
        term = f"%{search.strip()}%"
        sql += " AND (full_name ILIKE %s OR email ILIKE %s OR phone ILIKE %s OR role ILIKE %s)"
        params.extend([term, term, term, term])
    if role and role.strip() and role.lower() != 'all':
        sql += " AND LOWER(role) = LOWER(%s)"
        params.append(role.strip())
    
    sql += " ORDER BY full_name ASC LIMIT %s;"
    params.append(limit)

    rows = await exec_sql(sql, tuple(params))
    return {
        "success": True,
        "data": _serialize_val(rows or [])
    }


@router.get("/analytics-report", summary="Comprehensive Space Booking Analytics & Usage Report")
async def get_booking_analytics_report(
    building_id: Optional[str] = Query(None),
    timeframe: Optional[str] = Query("today"),
    target_date: Optional[date] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    b_id = safe_uuid(building_id)
    tf = timeframe or "today"
    q_date = target_date or date.today()

    sql = "SELECT public.fn_space_booking_get_analytics_report(%s::UUID, %s::UUID, %s::TEXT, %s::DATE) AS report;"
    rows = await exec_sql(sql, (school_id, b_id, tf, q_date))
    report = rows[0]["report"] if rows else {"success": False}
    return {
        "success": True,
        "data": _serialize_val(report)
    }
