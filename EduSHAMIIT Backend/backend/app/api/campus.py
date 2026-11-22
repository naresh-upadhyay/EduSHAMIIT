"""
Enterprise Campus Infrastructure & Buildings Management API for EduSHAMIIT ERP.
Provides high-performance endpoints executing PostgreSQL stored procedures and functions:
- Campus & Infrastructure KPIs Summary (Total Buildings, Floors, Rooms, Capacity, Occupancy)
- Configurable Infrastructure Lookups & Types
- Buildings Full Lifecycle (Listing, Aggregated Stats, Upsert, Archive, Soft Delete Protection)
- Floors Hierarchy (Ordering with Basements B3..B1..G..1..N, CRUD, Safe Delete)
- Rooms Management (Classrooms, Labs, Washrooms, Utility, Offices, Hostel, Dynamic Capacity, Status)
- Equipment & Facilities Tracking (Individual Condition & Working Status, Service Schedules)
- Bulk Room Generation & CSV/XLSX Bulk Import
- Streaming Data Export (CSV)
- Cross-Module Reusable Room Allocations & Inspections
"""
from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status, UploadFile, File, Form
from fastapi.responses import StreamingResponse, FileResponse
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any, Union
from datetime import datetime, date, time, timedelta
from decimal import Decimal
import io
import csv
import json
import uuid
import os
import random
import mimetypes
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


def _parse_time_str(time_str: Union[str, time]) -> time:
    """Parse time string like '14:00', '14:00:00', '02:00 PM', '2:00 PM' or return time object directly."""
    if isinstance(time_str, time):
        return time_str
    clean = str(time_str).strip().upper()
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
    return time(8, 0)


def _get_school_id(current_user: Any) -> str:
    """Resolve active multi-tenant school UUID from token or fallback."""
    if not isinstance(current_user, dict):
        return "11111111-1111-1111-1111-111111111111"
    school_id = current_user.get("school_id")
    if not school_id and current_user.get("role") in ("super_admin", "superadmin", "admin"):
        return str(current_user.get("selected_school_id") or "11111111-1111-1111-1111-111111111111")
    return str(school_id or "11111111-1111-1111-1111-111111111111")


def _get_user_id(current_user: Any) -> Optional[str]:
    """Resolve active profile UUID."""
    if not isinstance(current_user, dict):
        return "11111111-1111-1111-1111-111111111111"
    return current_user.get("id") or current_user.get("user_id") or "11111111-1111-1111-1111-111111111111"


# ============================================================================
# PYDANTIC SCHEMAS
# ============================================================================

class BuildingPayload(BaseModel):
    id: Optional[str] = None
    campus_id: Optional[str] = None
    name: str = Field(..., min_length=1, max_length=150)
    code: str = Field(..., min_length=1, max_length=50)
    building_type: Optional[str] = "Academic"
    description: Optional[str] = None
    purpose: Optional[str] = None
    address: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    total_floors: Optional[int] = Field(default=1, ge=1)
    total_area: Optional[float] = Field(default=0.0, ge=0.0)
    area_unit: Optional[str] = "sq ft"
    construction_year: Optional[int] = None
    num_entrances: Optional[int] = Field(default=1, ge=1)
    num_emergency_exits: Optional[int] = Field(default=1, ge=0)
    manager_name: Optional[str] = None
    manager_contact: Optional[str] = None
    department: Optional[str] = None
    image_url: Optional[str] = None
    fire_safety_cert_expiry: Optional[str] = None
    occupancy_cert_expiry: Optional[str] = None
    status: Optional[str] = "Active"
    notes: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None


class BuildingUpdatePayload(BaseModel):
    id: Optional[str] = None
    campus_id: Optional[str] = None
    name: Optional[str] = Field(None, min_length=1, max_length=150)
    code: Optional[str] = Field(None, min_length=1, max_length=50)
    building_type: Optional[str] = None
    description: Optional[str] = None
    purpose: Optional[str] = None
    address: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    total_floors: Optional[int] = Field(None, ge=1)
    total_area: Optional[float] = Field(None, ge=0.0)
    area_unit: Optional[str] = None
    construction_year: Optional[int] = None
    num_entrances: Optional[int] = Field(None, ge=1)
    num_emergency_exits: Optional[int] = Field(None, ge=0)
    manager_name: Optional[str] = None
    manager_contact: Optional[str] = None
    department: Optional[str] = None
    image_url: Optional[str] = None
    fire_safety_cert_expiry: Optional[str] = None
    occupancy_cert_expiry: Optional[str] = None
    status: Optional[str] = None
    notes: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None


class FloorPayload(BaseModel):
    id: Optional[str] = None
    building_id: str
    name: str = Field(..., min_length=1, max_length=100)
    floor_code: str = Field(..., min_length=1, max_length=50)
    floor_level: int = Field(default=0)
    floor_order: Optional[int] = 0
    floor_type: Optional[str] = "Standard"
    area: Optional[float] = Field(default=0.0, ge=0.0)
    description: Optional[str] = None
    status: Optional[str] = "Active"
    notes: Optional[str] = None


class RoomPayload(BaseModel):
    id: Optional[str] = None
    building_id: str
    floor_id: str
    name: Optional[str] = None
    room_number: str = Field(..., min_length=1, max_length=50)
    room_code: Optional[str] = None
    room_type: Optional[str] = "Classroom"
    description: Optional[str] = None
    purpose: Optional[str] = None
    area: Optional[float] = Field(default=0.0, ge=0.0)
    area_unit: Optional[str] = "sq ft"
    length: Optional[float] = Field(default=0.0, ge=0.0)
    width: Optional[float] = Field(default=0.0, ge=0.0)
    height: Optional[float] = Field(default=0.0, ge=0.0)
    max_capacity: int = Field(default=40, ge=0)
    recommended_capacity: Optional[int] = Field(default=35, ge=0)
    current_occupancy: Optional[int] = Field(default=0, ge=0)
    bed_count: Optional[int] = Field(default=0, ge=0)
    seating_capacity: Optional[int] = Field(default=40, ge=0)
    workstation_count: Optional[int] = Field(default=0, ge=0)
    num_doors: Optional[int] = Field(default=1, ge=1)
    num_windows: Optional[int] = Field(default=2, ge=0)
    operational_status: Optional[str] = "Available"
    assignment_status: Optional[str] = "Unassigned"
    is_differently_abled_accessible: Optional[bool] = True
    lift_proximity: Optional[str] = "Nearby"
    emergency_exit_proximity: Optional[str] = "Direct Access"
    location_notes: Optional[str] = None
    image_url: Optional[str] = None
    responsible_department: Optional[str] = None
    responsible_person_name: Optional[str] = None


class BulkCreateRoomsPayload(BaseModel):
    building_id: str
    floor_id: str
    room_numbers: List[str]
    room_type: Optional[str] = "Classroom"
    default_capacity: Optional[int] = Field(default=40, ge=0)
    common_facilities: Optional[List[str]] = Field(default_factory=list)


class EquipmentPayload(BaseModel):
    id: Optional[str] = None
    room_id: str
    equipment_name: str = Field(..., min_length=1, max_length=150)
    equipment_category: Optional[str] = "General Fixture"
    asset_id: Optional[str] = None
    quantity: int = Field(default=1, ge=1)
    condition: Optional[str] = "Good"
    operational_status: Optional[str] = "Operational"
    installation_date: Optional[str] = None
    last_service_date: Optional[str] = None
    next_service_date: Optional[str] = None
    remarks: Optional[str] = None


class RoomAssignmentPayload(BaseModel):
    room_id: str
    reference_module: str
    reference_entity_id: Optional[str] = None
    reference_name: Optional[str] = None
    assignment_purpose: Optional[str] = "General Allocation"
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    assigned_to_name: Optional[str] = None
    notes: Optional[str] = None


class InspectionPayload(BaseModel):
    building_id: str
    inspection_type: Optional[str] = "Routine Safety"
    inspection_date: Optional[str] = None
    inspector_name: str
    result: Optional[str] = "Passed"
    next_inspection_date: Optional[str] = None
    findings: Optional[str] = None
    recommendations: Optional[str] = None


class BuildingDocumentPayload(BaseModel):
    id: Optional[str] = None
    building_id: str
    room_id: Optional[str] = None
    document_name: str = Field(..., min_length=1, max_length=200)
    document_type: Optional[str] = "Compliance"
    file_url: str = Field(..., min_length=1)
    file_size_bytes: Optional[int] = 0
    mime_type: Optional[str] = "application/pdf"
    issue_date: Optional[str] = None
    expiry_date: Optional[str] = None
    issuing_authority: Optional[str] = None
    status: Optional[str] = "Valid"


class CampusMaintenancePayload(BaseModel):
    id: Optional[str] = None
    building_id: str
    floor_id: Optional[str] = None
    room_id: Optional[str] = None
    location_display: Optional[str] = None
    title: str = Field(..., min_length=1, max_length=200)
    description: Optional[str] = None
    request_type: Optional[str] = "Corrective"
    priority: Optional[str] = "Medium"
    status: Optional[str] = "Pending"
    reported_by_name: Optional[str] = None
    assigned_to_name: Optional[str] = None
    preferred_date: Optional[str] = None
    estimated_cost: Optional[float] = 0.0
    actual_cost: Optional[float] = 0.0
    resolution_notes: Optional[str] = None


class BuildingOccupancyPayload(BaseModel):
    id: Optional[str] = None
    room_id: str
    reference_module: Optional[str] = "General"
    reference_name: Optional[str] = None
    assignment_purpose: Optional[str] = "General Allocation"
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    assigned_to_name: Optional[str] = None
    status: Optional[str] = "Active"
    notes: Optional[str] = None


class AssignSectionPayload(BaseModel):
    room_id: str
    class_name: str
    section_name: str
    section_id: Optional[str] = None
    subject: Optional[str] = None
    teacher_name: Optional[str] = "Academic Faculty"
    booking_date: Optional[str] = None
    start_time: str
    end_time: str
    attendee_count: Optional[int] = 35
    is_recurring: Optional[bool] = False
    recurrence_frequency: Optional[str] = "DAILY" # DAILY, WEEKDAYS, WEEKLY
    recurrence_count: Optional[int] = 5
    notes: Optional[str] = None


# ============================================================================
# API ENDPOINTS
# ============================================================================

# ----------------------------------------------------------------------------
# 1. Campus Dashboard KPIs
# ----------------------------------------------------------------------------
@router.get("/kpis")
async def get_campus_kpis(
    campus_id: Optional[str] = None,
    user: dict = Depends(get_current_user),
):
    """Retrieve institution-wide or campus-specific infrastructure KPI metrics."""
    school_id = _get_school_id(user)
    try:
        sql = "SELECT public.fn_campus_get_kpis(%s::UUID, %s)"
        params = (school_id, campus_id if campus_id else None)
        rows = await exec_sql(sql, params)
        if rows and rows[0].get("fn_campus_get_kpis"):
            return rows[0]["fn_campus_get_kpis"]
        return {
            "total_buildings": 0, "total_floors": 0, "total_rooms": 0,
            "total_capacity": 0, "occupied_rooms": 0, "occupied_capacity": 0,
            "available_rooms": 0, "available_capacity": 0, "occupancy_rate": 0.0,
            "maintenance_rooms": 0, "total_equipment": 0, "equipment_not_working": 0
        }
    except Exception as e:
        logger.error(f"Error fetching campus KPIs: {e}")
        raise HTTPException(status_code=500, detail=f"Database execution error: {str(e)}")


# ----------------------------------------------------------------------------
# 2. Universal Infrastructure Lookups
# ----------------------------------------------------------------------------
@router.get("/lookups")
async def get_campus_lookups(
    user: dict = Depends(get_current_user),
):
    """Retrieve extensible lookup options for building types, room types, equipment, etc."""
    school_id = _get_school_id(user)
    try:
        sql = "SELECT public.fn_campus_get_lookups(%s::UUID)"
        rows = await exec_sql(sql, (school_id,))
        if rows and rows[0].get("fn_campus_get_lookups"):
            return rows[0]["fn_campus_get_lookups"]
        return {}
    except Exception as e:
        logger.error(f"Error fetching campus lookups: {e}")
        raise HTTPException(status_code=500, detail=f"Database execution error: {str(e)}")


# ----------------------------------------------------------------------------
# 3. Buildings Endpoints
# ----------------------------------------------------------------------------
@router.get("/buildings")
async def list_buildings(
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    search: Optional[str] = None,
    building_type: Optional[str] = None,
    status: Optional[str] = None,
    campus_id: Optional[str] = None,
    user: dict = Depends(get_current_user),
):
    """List buildings with aggregated floors count, rooms count, capacity and occupancy."""
    school_id = _get_school_id(user)
    filters = {}
    if search: filters["search"] = search
    if building_type: filters["building_type"] = building_type
    if status: filters["status"] = status
    if campus_id: filters["campus_id"] = campus_id

    try:
        sql = "SELECT public.fn_campus_list_buildings(%s::UUID, %s::JSONB, %s, %s)"
        rows = await exec_sql(sql, (school_id, json.dumps(filters), page, page_size))
        if rows and rows[0].get("fn_campus_list_buildings"):
            return rows[0]["fn_campus_list_buildings"]
        return {"success": True, "total_count": 0, "page": page, "page_size": page_size, "data": []}
    except Exception as e:
        logger.error(f"Error listing buildings: {e}")
        raise HTTPException(status_code=500, detail=f"Database query error: {str(e)}")


@router.get("/buildings/{building_id}")
async def get_building_details(
    building_id: str,
    user: dict = Depends(get_current_user),
):
    """Retrieve full building details including summary KPIs, floors breakdown, and compliance."""
    school_id = _get_school_id(user)
    try:
        sql = "SELECT public.fn_campus_get_building_details(%s::UUID, %s::UUID)"
        rows = await exec_sql(sql, (school_id, building_id))
        if rows and rows[0].get("fn_campus_get_building_details"):
            res = rows[0]["fn_campus_get_building_details"]
            if not res.get("success"):
                raise HTTPException(status_code=404, detail=res.get("message", "Building not found"))
            return res
        raise HTTPException(status_code=404, detail="Building not found")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting building details: {e}")
        raise HTTPException(status_code=500, detail=f"Database query error: {str(e)}")


@router.post("/buildings")
async def create_building(
    payload: BuildingPayload,
    user: dict = Depends(get_current_user),
):
    """Create a new building or facility block."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    try:
        sql = "SELECT public.fn_campus_upsert_building(%s::UUID, %s::JSONB, %s::UUID)"
        rows = await exec_sql(sql, (school_id, json.dumps(payload.model_dump()), user_id))
        res = rows[0]["fn_campus_upsert_building"] if rows else {}
        if not res.get("success"):
            raise HTTPException(status_code=400, detail=res.get("message", "Failed to save building"))
        return res
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating building: {e}")
        raise HTTPException(status_code=500, detail=f"Database write error: {str(e)}")


@router.put("/buildings/{building_id}")
@router.patch("/buildings/{building_id}")
async def update_building(
    building_id: str,
    payload: BuildingUpdatePayload,
    user: dict = Depends(get_current_user),
):
    """Update an existing building (supports full or partial updates)."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    data = payload.model_dump(exclude_unset=True)
    data["id"] = building_id
    try:
        sql = "SELECT public.fn_campus_upsert_building(%s::UUID, %s::JSONB, %s::UUID)"
        rows = await exec_sql(sql, (school_id, json.dumps(data), user_id))
        res = rows[0]["fn_campus_upsert_building"] if rows else {}
        if not res.get("success"):
            raise HTTPException(status_code=400, detail=res.get("message", "Failed to update building"))
        return res
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating building: {e}")
        raise HTTPException(status_code=500, detail=f"Database write error: {str(e)}")


@router.patch("/buildings/{building_id}/photo")
@router.put("/buildings/{building_id}/photo")
async def update_building_photo(
    building_id: str,
    payload: Dict[str, Any],
    user: dict = Depends(get_current_user),
):
    """Update building photo specifically."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    image_url = payload.get("image_url") or payload.get("url")
    if not image_url:
        raise HTTPException(status_code=400, detail="image_url is required")
    try:
        data = {"id": building_id, "image_url": image_url}
        sql = "SELECT public.fn_campus_upsert_building(%s::UUID, %s::JSONB, %s::UUID)"
        rows = await exec_sql(sql, (school_id, json.dumps(data), user_id))
        res = rows[0]["fn_campus_upsert_building"] if rows else {}
        if not res.get("success"):
            raise HTTPException(status_code=400, detail=res.get("message", "Failed to update building photo"))
        return res
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating building photo: {e}")
        raise HTTPException(status_code=500, detail=f"Database write error: {str(e)}")


@router.delete("/buildings/{building_id}")
async def delete_building(
    building_id: str,
    user: dict = Depends(get_current_user),
):
    """Safely delete building (blocked if active rooms or allocations exist)."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    try:
        sql = "SELECT public.fn_campus_archive_or_delete_building(%s::UUID, %s::UUID, 'delete', %s::UUID)"
        rows = await exec_sql(sql, (school_id, building_id, user_id))
        res = rows[0]["fn_campus_archive_or_delete_building"] if rows else {}
        if not res.get("success"):
            raise HTTPException(status_code=400, detail=res.get("message", "Cannot delete building"))
        return res
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting building: {e}")
        raise HTTPException(status_code=500, detail=f"Database execution error: {str(e)}")


@router.post("/buildings/{building_id}/archive")
async def archive_building(
    building_id: str,
    user: dict = Depends(get_current_user),
):
    """Archive building while preserving all historical rooms and allocations."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    try:
        sql = "SELECT public.fn_campus_archive_or_delete_building(%s::UUID, %s::UUID, 'archive', %s::UUID)"
        rows = await exec_sql(sql, (school_id, building_id, user_id))
        res = rows[0]["fn_campus_archive_or_delete_building"] if rows else {}
        if not res.get("success"):
            raise HTTPException(status_code=400, detail=res.get("message", "Cannot archive building"))
        return res
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error archiving building: {e}")
        raise HTTPException(status_code=500, detail=f"Database execution error: {str(e)}")


# ----------------------------------------------------------------------------
# 4. Floor Endpoints
# ----------------------------------------------------------------------------
@router.get("/buildings/{building_id}/floors")
async def list_building_floors(
    building_id: str,
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    sort_by: Optional[str] = Query(None),
    sort_order: Optional[str] = Query("asc"),
    user: dict = Depends(get_current_user),
):
    """List floors belonging to a building, ordered by floor_level or sorted column."""
    school_id = _get_school_id(user)
    filters = {}
    if sort_by:
        filters["sort_by"] = sort_by
        filters["sort_order"] = sort_order or "asc"
    try:
        sql = "SELECT public.fn_campus_list_floors(%s::UUID, %s::UUID, %s, %s, %s::JSONB)"
        rows = await exec_sql(sql, (school_id, building_id, page, page_size, json.dumps(filters)))
        if rows and rows[0].get("fn_campus_list_floors"):
            return rows[0]["fn_campus_list_floors"]
        return {"success": True, "total_count": 0, "page": page, "page_size": page_size, "data": []}
    except Exception as e:
        logger.error(f"Error listing floors: {e}")
        raise HTTPException(status_code=500, detail=f"Database query error: {str(e)}")


@router.post("/buildings/{building_id}/floors")
async def create_floor(
    building_id: str,
    payload: FloorPayload,
    user: dict = Depends(get_current_user),
):
    """Add a floor to a building."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    data = payload.model_dump()
    data["building_id"] = building_id
    try:
        sql = "SELECT public.fn_campus_upsert_floor(%s::UUID, %s::JSONB, %s::UUID)"
        rows = await exec_sql(sql, (school_id, json.dumps(data), user_id))
        res = rows[0]["fn_campus_upsert_floor"] if rows else {}
        if not res.get("success"):
            raise HTTPException(status_code=400, detail=res.get("message", "Failed to save floor"))
        return res
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating floor: {e}")
        raise HTTPException(status_code=500, detail=f"Database write error: {str(e)}")


@router.put("/floors/{floor_id}")
async def update_floor(
    floor_id: str,
    payload: FloorPayload,
    user: dict = Depends(get_current_user),
):
    """Update an existing floor."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    data = payload.model_dump()
    data["id"] = floor_id
    try:
        sql = "SELECT public.fn_campus_upsert_floor(%s::UUID, %s::JSONB, %s::UUID)"
        rows = await exec_sql(sql, (school_id, json.dumps(data), user_id))
        res = rows[0]["fn_campus_upsert_floor"] if rows else {}
        if not res.get("success"):
            raise HTTPException(status_code=400, detail=res.get("message", "Failed to update floor"))
        return res
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating floor: {e}")
        raise HTTPException(status_code=500, detail=f"Database write error: {str(e)}")


@router.delete("/floors/{floor_id}")
async def delete_floor(
    floor_id: str,
    user: dict = Depends(get_current_user),
):
    """Delete a floor (blocked if rooms exist)."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    try:
        sql = "SELECT public.fn_campus_delete_floor(%s::UUID, %s::UUID, %s::UUID)"
        rows = await exec_sql(sql, (school_id, floor_id, user_id))
        res = rows[0]["fn_campus_delete_floor"] if rows else {}
        if not res.get("success"):
            raise HTTPException(status_code=400, detail=res.get("message", "Cannot delete floor"))
        return res
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting floor: {e}")
        raise HTTPException(status_code=500, detail=f"Database execution error: {str(e)}")


# ----------------------------------------------------------------------------
# 5. Room Endpoints
# ----------------------------------------------------------------------------
@router.get("/rooms")
async def list_rooms(
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    search: Optional[str] = None,
    building_id: Optional[str] = None,
    floor_id: Optional[str] = None,
    room_type: Optional[str] = None,
    operational_status: Optional[str] = None,
    assignment_status: Optional[str] = None,
    min_capacity: Optional[int] = None,
    max_capacity: Optional[int] = None,
    sort_by: Optional[str] = Query(None),
    sort_order: Optional[str] = Query("asc"),
    user: dict = Depends(get_current_user),
):
    """List rooms with advanced search, filters, equipment summary, sorting, and server pagination."""
    school_id = _get_school_id(user)
    filters = {}
    if search: filters["search"] = search
    if building_id: filters["building_id"] = building_id
    if floor_id: filters["floor_id"] = floor_id
    if room_type: filters["room_type"] = room_type
    if operational_status: filters["operational_status"] = operational_status
    if assignment_status: filters["assignment_status"] = assignment_status
    if min_capacity is not None: filters["min_capacity"] = min_capacity
    if max_capacity is not None: filters["max_capacity"] = max_capacity
    if sort_by:
        filters["sort_by"] = sort_by
        filters["sort_order"] = sort_order or "asc"

    try:
        sql = "SELECT public.fn_campus_list_rooms(%s::UUID, %s::JSONB, %s, %s)"
        rows = await exec_sql(sql, (school_id, json.dumps(filters), page, page_size))
        if rows and rows[0].get("fn_campus_list_rooms"):
            return rows[0]["fn_campus_list_rooms"]
        return {"success": True, "total_count": 0, "page": page, "page_size": page_size, "data": []}
    except Exception as e:
        logger.error(f"Error listing rooms: {e}")
        raise HTTPException(status_code=500, detail=f"Database query error: {str(e)}")


@router.get("/rooms/{room_id}")
async def get_room_details(
    room_id: str,
    user: dict = Depends(get_current_user),
):
    """Retrieve room specifications, equipment items, assignments, and documents."""
    school_id = _get_school_id(user)
    try:
        sql = "SELECT public.fn_campus_get_room_details(%s::UUID, %s::UUID)"
        rows = await exec_sql(sql, (school_id, room_id))
        if rows and rows[0].get("fn_campus_get_room_details"):
            res = rows[0]["fn_campus_get_room_details"]
            if not res.get("success"):
                raise HTTPException(status_code=404, detail=res.get("message", "Room not found"))
            return res
        raise HTTPException(status_code=404, detail="Room not found")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting room details: {e}")
        raise HTTPException(status_code=500, detail=f"Database query error: {str(e)}")


@router.post("/rooms")
async def create_room(
    payload: RoomPayload,
    user: dict = Depends(get_current_user),
):
    """Create a new physical room / space."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    try:
        sql = "SELECT public.fn_campus_upsert_room(%s::UUID, %s::JSONB, %s::UUID)"
        rows = await exec_sql(sql, (school_id, json.dumps(payload.model_dump()), user_id))
        res = rows[0]["fn_campus_upsert_room"] if rows else {}
        if not res.get("success"):
            raise HTTPException(status_code=400, detail=res.get("message", "Failed to save room"))
        return res
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating room: {e}")
        raise HTTPException(status_code=500, detail=f"Database write error: {str(e)}")


@router.put("/rooms/{room_id}")
async def update_room(
    room_id: str,
    payload: RoomPayload,
    user: dict = Depends(get_current_user),
):
    """Update physical room specifications and status."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    data = payload.model_dump()
    data["id"] = room_id
    try:
        sql = "SELECT public.fn_campus_upsert_room(%s::UUID, %s::JSONB, %s::UUID)"
        rows = await exec_sql(sql, (school_id, json.dumps(data), user_id))
        res = rows[0]["fn_campus_upsert_room"] if rows else {}
        if not res.get("success"):
            raise HTTPException(status_code=400, detail=res.get("message", "Failed to update room"))
        return res
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating room: {e}")
        raise HTTPException(status_code=500, detail=f"Database write error: {str(e)}")


@router.delete("/rooms/{room_id}")
async def delete_room(
    room_id: str,
    user: dict = Depends(get_current_user),
):
    """Soft delete room (blocked if active allocations exist)."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    try:
        # Check assignments
        chk_sql = "SELECT COUNT(*) AS cnt FROM public.room_assignments WHERE room_id = %s::UUID AND deleted_at IS NULL AND status = 'Active'"
        chk_rows = await exec_sql(chk_sql, (room_id,))
        if chk_rows and chk_rows[0]["cnt"] > 0:
            raise HTTPException(
                status_code=400,
                detail=f"Cannot delete room with active allocations. Please reassign or conclude allocations first."
            )

        del_sql = "UPDATE public.rooms SET deleted_at = NOW(), deleted_by = %s::UUID, operational_status = 'Inactive' WHERE id = %s::UUID AND school_id = %s::UUID AND deleted_at IS NULL RETURNING id"
        res = await exec_sql(del_sql, (user_id, room_id, school_id))
        if not res:
            raise HTTPException(status_code=404, detail="Room not found")
        return {"success": True, "message": "Room deleted successfully."}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting room: {e}")
        raise HTTPException(status_code=500, detail=f"Database execution error: {str(e)}")


# ----------------------------------------------------------------------------
# 6. Bulk Room Operations
# ----------------------------------------------------------------------------
@router.post("/rooms/bulk-create")
async def bulk_create_rooms(
    payload: BulkCreateRoomsPayload,
    user: dict = Depends(get_current_user),
):
    """Atomically create multiple rooms in a single operation with default capacity and facilities."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    try:
        sql = "SELECT public.fn_campus_bulk_create_rooms(%s::UUID, %s::JSONB, %s::UUID)"
        rows = await exec_sql(sql, (school_id, json.dumps(payload.model_dump()), user_id))
        res = rows[0]["fn_campus_bulk_create_rooms"] if rows else {}
        if not res.get("success"):
            raise HTTPException(status_code=400, detail=res.get("message", "Bulk create failed"))
        return res
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error bulk creating rooms: {e}")
        raise HTTPException(status_code=500, detail=f"Database write error: {str(e)}")


@router.post("/rooms/bulk-import")
async def bulk_import_rooms(
    request: Request,
    user: dict = Depends(get_current_user),
):
    """Bulk import rooms from structured JSON rows."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    try:
        body = await request.json()
        rows_data = body if isinstance(body, list) else body.get("rows", [])
        sql = "SELECT public.fn_campus_bulk_import_rooms(%s::UUID, %s::JSONB, %s::UUID)"
        rows = await exec_sql(sql, (school_id, json.dumps(rows_data), user_id))
        res = rows[0]["fn_campus_bulk_import_rooms"] if rows else {}
        return res
    except Exception as e:
        logger.error(f"Error bulk importing rooms: {e}")
        raise HTTPException(status_code=500, detail=f"Import execution error: {str(e)}")


# ----------------------------------------------------------------------------
# 7. Room Equipment Endpoints
# ----------------------------------------------------------------------------
@router.get("/rooms/{room_id}/equipment")
async def list_room_equipment(
    room_id: str,
    user: dict = Depends(get_current_user),
):
    """List all equipment and fixtures inside a room with individual statuses."""
    school_id = _get_school_id(user)
    try:
        sql = """
            SELECT id, equipment_name, equipment_category, asset_id, quantity, condition,
                   operational_status, installation_date, last_service_date, next_service_date, remarks
            FROM public.room_equipment
            WHERE room_id = %s::UUID AND school_id = %s::UUID AND deleted_at IS NULL
            ORDER BY equipment_category ASC, equipment_name ASC
        """
        rows = await exec_sql(sql, (room_id, school_id))
        return [_serialize_val(r) for r in rows]
    except Exception as e:
        logger.error(f"Error listing equipment: {e}")
        raise HTTPException(status_code=500, detail=f"Database query error: {str(e)}")


@router.post("/rooms/{room_id}/equipment")
async def add_room_equipment(
    room_id: str,
    payload: EquipmentPayload,
    user: dict = Depends(get_current_user),
):
    """Add an equipment/fixture item to a room."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    data = payload.model_dump()
    data["room_id"] = room_id
    try:
        sql = "SELECT public.fn_campus_upsert_equipment(%s::UUID, %s::JSONB, %s::UUID)"
        rows = await exec_sql(sql, (school_id, json.dumps(data), user_id))
        res = rows[0]["fn_campus_upsert_equipment"] if rows else {}
        if not res.get("success"):
            raise HTTPException(status_code=400, detail=res.get("message", "Failed to save equipment"))
        return res
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error adding equipment: {e}")
        raise HTTPException(status_code=500, detail=f"Database write error: {str(e)}")


@router.put("/rooms/{room_id}/equipment/{equipment_id}")
async def update_room_equipment(
    room_id: str,
    equipment_id: str,
    payload: EquipmentPayload,
    user: dict = Depends(get_current_user),
):
    """Update equipment status, condition, service dates, or notes."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    data = payload.model_dump()
    data["id"] = equipment_id
    data["room_id"] = room_id
    try:
        sql = "SELECT public.fn_campus_upsert_equipment(%s::UUID, %s::JSONB, %s::UUID)"
        rows = await exec_sql(sql, (school_id, json.dumps(data), user_id))
        res = rows[0]["fn_campus_upsert_equipment"] if rows else {}
        if not res.get("success"):
            raise HTTPException(status_code=400, detail=res.get("message", "Failed to update equipment"))
        return res
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating equipment: {e}")
        raise HTTPException(status_code=500, detail=f"Database write error: {str(e)}")


@router.delete("/rooms/{room_id}/equipment/{equipment_id}")
async def delete_room_equipment(
    room_id: str,
    equipment_id: str,
    user: dict = Depends(get_current_user),
):
    """Remove equipment from a room."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    try:
        sql = "SELECT public.fn_campus_delete_equipment(%s::UUID, %s::UUID, %s::UUID)"
        rows = await exec_sql(sql, (school_id, equipment_id, user_id))
        res = rows[0]["fn_campus_delete_equipment"] if rows else {}
        return res
    except Exception as e:
        logger.error(f"Error deleting equipment: {e}")
        raise HTTPException(status_code=500, detail=f"Database execution error: {str(e)}")


# ----------------------------------------------------------------------------
# 8. Room Assignments & Allocations (Cross-Module Reference)
# ----------------------------------------------------------------------------
@router.get("/rooms/{room_id}/assignments")
async def get_room_assignments(
    room_id: str,
    user: dict = Depends(get_current_user),
):
    """Get active and historical allocations for a room."""
    school_id = _get_school_id(user)
    try:
        sql = """
            SELECT id, reference_module, reference_name, assignment_purpose, start_date, end_date,
                   start_time, end_time, status, assigned_to_name, notes, created_at
            FROM public.room_assignments
            WHERE room_id = %s::UUID AND school_id = %s::UUID AND deleted_at IS NULL
            ORDER BY created_at DESC
        """
        rows = await exec_sql(sql, (room_id, school_id))
        return [_serialize_val(r) for r in rows]
    except Exception as e:
        logger.error(f"Error getting room assignments: {e}")
        raise HTTPException(status_code=500, detail=f"Database query error: {str(e)}")


@router.post("/rooms/{room_id}/assignments")
async def create_room_assignment(
    room_id: str,
    payload: RoomAssignmentPayload,
    user: dict = Depends(get_current_user),
):
    """Allocate a room to a department, class, staff member, or event."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    try:
        sql = """
            INSERT INTO public.room_assignments (
                school_id, room_id, reference_module, reference_entity_id, reference_name,
                assignment_purpose, start_date, end_date, assigned_to_name, notes, created_by
            ) VALUES (
                %s::UUID, %s::UUID, %s, NULLIF(%s, '')::UUID, %s,
                %s, %s::DATE, %s::DATE, %s, %s, %s::UUID
            ) RETURNING *;
        """
        params = (
            school_id, room_id, payload.reference_module, payload.reference_entity_id,
            payload.reference_name, payload.assignment_purpose,
            payload.start_date, payload.end_date, payload.assigned_to_name,
            payload.notes, user_id
        )
        rows = await exec_sql(sql, params)
        # Update room assignment status
        await exec_sql(
            "UPDATE public.rooms SET assignment_status = 'Assigned' WHERE id = %s::UUID",
            (room_id,),
            fetch=False
        )
        return {"success": True, "data": _serialize_val(rows[0])}
    except Exception as e:
        logger.error(f"Error creating room assignment: {e}")
        raise HTTPException(status_code=500, detail=f"Database write error: {str(e)}")


# ----------------------------------------------------------------------------
# 9. Inspections & Documents
# ----------------------------------------------------------------------------
@router.get("/buildings/{building_id}/inspections")
async def get_building_inspections(
    building_id: str,
    user: dict = Depends(get_current_user),
):
    """List inspections for a building."""
    school_id = _get_school_id(user)
    try:
        sql = """
            SELECT id, inspection_type, inspection_date, inspector_name, result,
                   next_inspection_date, findings, recommendations, status, created_at
            FROM public.building_inspections
            WHERE building_id = %s::UUID AND school_id = %s::UUID
            ORDER BY inspection_date DESC
        """
        rows = await exec_sql(sql, (building_id, school_id))
        return [_serialize_val(r) for r in rows]
    except Exception as e:
        logger.error(f"Error fetching inspections: {e}")
        raise HTTPException(status_code=500, detail=f"Database query error: {str(e)}")


@router.post("/buildings/{building_id}/inspections")
async def create_building_inspection(
    building_id: str,
    payload: InspectionPayload,
    user: dict = Depends(get_current_user),
):
    """Record a building inspection result."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    try:
        sql = """
            INSERT INTO public.building_inspections (
                school_id, building_id, inspection_type, inspection_date, inspector_name,
                result, next_inspection_date, findings, recommendations, created_by
            ) VALUES (
                %s::UUID, %s::UUID, %s, COALESCE(%s::DATE, CURRENT_DATE), %s,
                %s, %s::DATE, %s, %s, %s::UUID
            ) RETURNING *;
        """
        params = (
            school_id, building_id, payload.inspection_type, payload.inspection_date,
            payload.inspector_name, payload.result, payload.next_inspection_date,
            payload.findings, payload.recommendations, user_id
        )
        rows = await exec_sql(sql, params)
        return {"success": True, "data": _serialize_val(rows[0])}
    except Exception as e:
        logger.error(f"Error recording inspection: {e}")
        raise HTTPException(status_code=500, detail=f"Database write error: {str(e)}")


# ----------------------------------------------------------------------------
# 10. Streaming Data Export (CSV)
# ----------------------------------------------------------------------------
@router.get("/export")
async def export_campus_data(
    export_type: str = Query("rooms", pattern="^(buildings|floors|rooms|equipment)$"),
    building_id: Optional[str] = None,
    user: dict = Depends(get_current_user),
):
    """Export buildings, floors, rooms, or equipment as a streaming CSV file."""
    school_id = _get_school_id(user)
    output = io.StringIO()
    writer = csv.writer(output)

    try:
        if export_type == "buildings":
            writer.writerow(["Building Code", "Building Name", "Type", "Floors", "Total Area", "Status", "Manager", "Department"])
            sql = "SELECT code, name, building_type, total_floors, total_area, status, manager_name, department FROM public.buildings WHERE school_id = %s::UUID AND deleted_at IS NULL ORDER BY code"
            rows = await exec_sql(sql, (school_id,))
            for r in rows:
                writer.writerow([r["code"], r["name"], r["building_type"], r["total_floors"], r["total_area"], r["status"], r["manager_name"], r["department"]])

        elif export_type == "floors":
            writer.writerow(["Building Code", "Building Name", "Floor Code", "Floor Name", "Level", "Area", "Status"])
            sql = """
                SELECT b.code AS bld_code, b.name AS bld_name, f.floor_code, f.name AS floor_name, f.floor_level, f.area, f.status
                FROM public.building_floors f
                JOIN public.buildings b ON f.building_id = b.id
                WHERE f.school_id = %s::UUID AND f.deleted_at IS NULL
                ORDER BY b.code, f.floor_level
            """
            rows = await exec_sql(sql, (school_id,))
            for r in rows:
                writer.writerow([r["bld_code"], r["bld_name"], r["floor_code"], r["floor_name"], r["floor_level"], r["area"], r["status"]])

        elif export_type == "rooms":
            writer.writerow(["Building Code", "Floor", "Room Number", "Room Name", "Room Type", "Max Capacity", "Occupancy", "Operational Status", "Assignment Status"])
            sql = """
                SELECT b.code AS bld_code, f.name AS floor_name, r.room_number, r.name AS room_name,
                       r.room_type, r.max_capacity, r.current_occupancy, r.operational_status, r.assignment_status
                FROM public.rooms r
                JOIN public.buildings b ON r.building_id = b.id
                JOIN public.building_floors f ON r.floor_id = f.id
                WHERE r.school_id = %s::UUID AND r.deleted_at IS NULL
                  AND (%s::UUID IS NULL OR r.building_id = %s::UUID)
                ORDER BY b.code, r.room_number
            """
            rows = await exec_sql(sql, (school_id, building_id, building_id))
            for r in rows:
                writer.writerow([r["bld_code"], r["floor_name"], r["room_number"], r["room_name"], r["room_type"], r["max_capacity"], r["current_occupancy"], r["operational_status"], r["assignment_status"]])

        elif export_type == "equipment":
            writer.writerow(["Building", "Floor", "Room", "Equipment Name", "Category", "Quantity", "Condition", "Status", "Next Service Date"])
            sql = """
                SELECT b.name AS bld_name, f.name AS floor_name, r.room_number,
                       e.equipment_name, e.equipment_category, e.quantity, e.condition, e.operational_status, e.next_service_date
                FROM public.room_equipment e
                JOIN public.rooms r ON e.room_id = r.id
                JOIN public.buildings b ON e.building_id = b.id
                JOIN public.building_floors f ON e.floor_id = f.id
                WHERE e.school_id = %s::UUID AND e.deleted_at IS NULL
                ORDER BY b.name, r.room_number, e.equipment_name
            """
            rows = await exec_sql(sql, (school_id,))
            for r in rows:
                writer.writerow([r["bld_name"], r["floor_name"], r["room_number"], r["equipment_name"], r["equipment_category"], r["quantity"], r["condition"], r["operational_status"], r["next_service_date"]])

        output.seek(0)
        filename = f"campus_{export_type}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
        return StreamingResponse(
            io.BytesIO(output.getvalue().encode("utf-8")),
            media_type="text/csv",
            headers={"Content-Disposition": f"attachment; filename={filename}"}
        )
    except Exception as e:
        logger.error(f"Error exporting campus data: {e}")
        raise HTTPException(status_code=500, detail=f"Export error: {str(e)}")


# ----------------------------------------------------------------------------
# 11. Campus File & Image Upload & Serving
# ----------------------------------------------------------------------------
@router.post("/upload-image")
@router.post("/upload-file")
@router.post("/upload-document")
async def upload_campus_image(
    file: UploadFile = File(...),
    user: dict = Depends(get_current_user),
):
    """Upload an image or compliance document file (building, room, floor, documents) and return an accessible URL."""
    try:
        content = await file.read()
        if len(content) == 0:
            raise HTTPException(status_code=400, detail="Uploaded file is empty")
        if len(content) > 25 * 1024 * 1024:
            raise HTTPException(status_code=400, detail="File size exceeds 25MB limit")

        file_ext = os.path.splitext(file.filename or "")[1].lower()
        mime_map = {
            ".jpg": "image/jpeg",
            ".jpeg": "image/jpeg",
            ".png": "image/png",
            ".webp": "image/webp",
            ".gif": "image/gif",
            ".svg": "image/svg+xml",
            ".pdf": "application/pdf",
            ".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            ".doc": "application/msword",
            ".xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            ".xls": "application/vnd.ms-excel",
            ".csv": "text/csv",
            ".txt": "text/plain",
        }

        content_type = file.content_type
        if not content_type or content_type in ("application/octet-stream", "binary/octet-stream"):
            content_type = mime_map.get(file_ext, "image/jpeg" if file_ext in (".jpg", ".jpeg", ".png", ".webp") else "application/pdf")

        if not file_ext:
            if "pdf" in content_type:
                file_ext = ".pdf"
            elif "png" in content_type:
                file_ext = ".png"
            elif "webp" in content_type:
                file_ext = ".webp"
            else:
                file_ext = ".jpg"

        raw_base = os.path.basename(file.filename or f"campus_file{file_ext}")
        clean_base = re.sub(r'[^a-zA-Z0-9_\.-]', '_', raw_base)
        safe_name = f"{uuid.uuid4().hex[:12]}_{clean_base}"

        # Save locally to assets/campus_images
        upload_dir = os.path.abspath(os.path.join(os.getcwd(), "assets", "campus_images"))
        os.makedirs(upload_dir, exist_ok=True)
        local_path = os.path.join(upload_dir, safe_name)
        with open(local_path, "wb") as f:
            f.write(content)

        file_url = f"/api/campus/images/{safe_name}"

        # Attempt upload to Supabase Storage if configured
        try:
            from app.services.supabase_client import get_supabase
            sb = get_supabase()
            school_id = _get_school_id(user)
            storage_path = f"campus/{school_id}/{safe_name}"
            sb.storage.from_("campus-attachments").upload(
                path=storage_path,
                file=content,
                file_options={"content-type": content_type}
            )
            public_url = sb.storage.from_("campus-attachments").get_public_url(storage_path)
            if public_url:
                file_url = public_url
        except Exception as storage_err:
            logger.info(f"[Campus File Upload] Supabase Storage upload fallback: {storage_err}")

        return {
            "success": True,
            "data": {
                "file_name": file.filename,
                "safe_name": safe_name,
                "file_url": file_url,
                "url": file_url,
                "image_url": file_url,
                "file_size": len(content),
                "content_type": content_type
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Campus file upload failed: {e}")
        raise HTTPException(status_code=500, detail=f"File upload failed: {str(e)}")


@router.api_route("/images/{file_name:path}", methods=["GET", "HEAD"])
@router.api_route("/documents/{file_name:path}", methods=["GET", "HEAD"])
async def get_campus_image(file_name: str):
    """Serve locally uploaded campus images and compliance documents with browser caching."""
    import urllib.parse
    decoded_file_name = urllib.parse.unquote(file_name)
    media_dirs = [
        os.path.abspath(os.path.join(os.getcwd(), "assets", "campus_images")),
        os.path.abspath(os.path.join(os.getcwd(), "assets", "uploads")),
        os.path.abspath(os.path.join(os.getcwd(), "assets")),
    ]
    target_path = None
    for d in media_dirs:
        for name_to_try in (decoded_file_name, file_name):
            candidate = os.path.abspath(os.path.join(d, name_to_try))
            if candidate.startswith(d) and os.path.exists(candidate) and os.path.isfile(candidate):
                target_path = candidate
                break
        if target_path:
            break

    if not target_path:
        raise HTTPException(status_code=404, detail="File not found")

    ext = os.path.splitext(file_name)[1].lower()
    media_types = {
        ".png": "image/png",
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".webp": "image/webp",
        ".gif": "image/gif",
        ".svg": "image/svg+xml",
        ".pdf": "application/pdf",
        ".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        ".doc": "application/msword",
        ".xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        ".xls": "application/vnd.ms-excel",
        ".csv": "text/csv",
        ".txt": "text/plain",
    }
    content_type = media_types.get(ext, "application/octet-stream")
    return FileResponse(target_path, media_type=content_type)


# ----------------------------------------------------------------------------
# 12. Building Documents CRUD
# ----------------------------------------------------------------------------
@router.get("/buildings/{building_id}/documents")
async def list_building_documents(
    building_id: str,
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=100),
    sort_by: Optional[str] = Query(None),
    sort_order: Optional[str] = Query("desc"),
    user: dict = Depends(get_current_user),
):
    """List all compliance, insurance, architectural, and safety documents for a building with sorting and pagination."""
    school_id = _get_school_id(user)
    try:
        sort_col = "created_at"
        if sort_by in ["document_name", "document_type", "status", "issue_date", "expiry_date", "created_at"]:
            sort_col = sort_by
        order_dir = "ASC" if (sort_order or "").lower() == "asc" else "DESC"

        count_sql = """
            SELECT COUNT(*) AS total
            FROM public.building_documents
            WHERE building_id = %s::UUID AND school_id = %s::UUID AND deleted_at IS NULL
        """
        count_rows = await exec_sql(count_sql, (building_id, school_id))
        total = count_rows[0]["total"] if count_rows else 0

        offset = max(0, (page - 1) * page_size)
        sql = f"""
            SELECT id, school_id, building_id, room_id, document_name, document_type,
                   file_url, file_size_bytes, mime_type, issue_date, expiry_date,
                   issuing_authority, status, created_at
            FROM public.building_documents
            WHERE building_id = %s::UUID AND school_id = %s::UUID AND deleted_at IS NULL
            ORDER BY {sort_col} {order_dir}
            LIMIT %s OFFSET %s
        """
        rows = await exec_sql(sql, (building_id, school_id, page_size, offset))
        return {
            "success": True,
            "total_count": total,
            "page": page,
            "page_size": page_size,
            "data": [_serialize_val(r) for r in rows]
        }
    except Exception as e:
        logger.error(f"Error fetching building documents: {e}")
        raise HTTPException(status_code=500, detail=f"Database query error: {str(e)}")


@router.post("/buildings/{building_id}/documents")
async def create_building_document(
    building_id: str,
    payload: BuildingDocumentPayload,
    user: dict = Depends(get_current_user),
):
    """Add a compliance / building document record."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    try:
        sql = """
            INSERT INTO public.building_documents (
                school_id, building_id, room_id, document_name, document_type,
                file_url, file_size_bytes, mime_type, issue_date, expiry_date,
                issuing_authority, status, uploaded_by, created_at
            ) VALUES (
                %s::UUID, %s::UUID, NULLIF(%s, '')::UUID, %s, %s,
                %s, %s, %s, %s::DATE, %s::DATE,
                %s, %s, %s::UUID, NOW()
            ) RETURNING *;
        """
        params = (
            school_id, building_id, payload.room_id, payload.document_name, payload.document_type,
            payload.file_url, payload.file_size_bytes or 0, payload.mime_type or "application/pdf",
            payload.issue_date, payload.expiry_date,
            payload.issuing_authority, payload.status or "Valid", user_id
        )
        rows = await exec_sql(sql, params)
        return {"success": True, "data": _serialize_val(rows[0])}
    except Exception as e:
        logger.error(f"Error adding building document: {e}")
        raise HTTPException(status_code=500, detail=f"Database write error: {str(e)}")


@router.put("/buildings/{building_id}/documents/{document_id}")
async def update_building_document(
    building_id: str,
    document_id: str,
    payload: BuildingDocumentPayload,
    user: dict = Depends(get_current_user),
):
    """Update building document details."""
    school_id = _get_school_id(user)
    try:
        sql = """
            UPDATE public.building_documents SET
                document_name = %s,
                document_type = %s,
                file_url = COALESCE(NULLIF(%s, ''), file_url),
                issue_date = %s::DATE,
                expiry_date = %s::DATE,
                issuing_authority = %s,
                status = %s
            WHERE id = %s::UUID AND building_id = %s::UUID AND school_id = %s::UUID AND deleted_at IS NULL
            RETURNING *;
        """
        params = (
            payload.document_name, payload.document_type, payload.file_url,
            payload.issue_date, payload.expiry_date,
            payload.issuing_authority, payload.status or "Valid",
            document_id, building_id, school_id
        )
        rows = await exec_sql(sql, params)
        if not rows:
            raise HTTPException(status_code=404, detail="Document not found")
        return {"success": True, "data": _serialize_val(rows[0])}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating building document: {e}")
        raise HTTPException(status_code=500, detail=f"Database write error: {str(e)}")


@router.delete("/buildings/{building_id}/documents/{document_id}")
async def delete_building_document(
    building_id: str,
    document_id: str,
    user: dict = Depends(get_current_user),
):
    """Soft delete building document."""
    school_id = _get_school_id(user)
    try:
        sql = """
            UPDATE public.building_documents
            SET deleted_at = NOW()
            WHERE id = %s::UUID AND building_id = %s::UUID AND school_id = %s::UUID
            RETURNING id;
        """
        rows = await exec_sql(sql, (document_id, building_id, school_id))
        if not rows:
            raise HTTPException(status_code=404, detail="Document not found")
        return {"success": True, "message": "Document deleted successfully"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting building document: {e}")
        raise HTTPException(status_code=500, detail=f"Database execution error: {str(e)}")


# ----------------------------------------------------------------------------
# 13. Building Occupancy & Allocations CRUD (Dynamic Space Booking Driven)
# ----------------------------------------------------------------------------
@router.get("/buildings/{building_id}/occupancy")
async def get_building_occupancy(
    building_id: str,
    target_date: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(200, ge=1, le=500),
    sort_by: Optional[str] = Query(None),
    sort_order: Optional[str] = Query("asc"),
    search: Optional[str] = Query(None),
    status_filter: Optional[str] = Query(None),
    floor_id: Optional[str] = Query(None),
    room_type: Optional[str] = Query(None),
    reference_module: Optional[str] = Query(None),
    user: dict = Depends(get_current_user),
):
    """
    Real-time Dynamic Space Booking & Building Occupancy Engine.
    Correlates physical building rooms with space_bookings schedule for target_date.
    Returns live room availability (Occupied Now, Available Now, Scheduled Later, Maintenance),
    today's booking timelines, specifications, facilities, and dynamic building-level KPIs.
    """
    school_id = _get_school_id(user)
    try:
        # 1. Parse target date
        query_date_str = target_date.strip() if isinstance(target_date, str) and target_date.strip() else None
        if query_date_str:
            try:
                query_date = datetime.strptime(query_date_str[:10], "%Y-%m-%d").date()
            except Exception:
                query_date = date.today()
        else:
            query_date = date.today()

        is_today = (query_date == date.today())
        now_time = datetime.now().time()

        # 2. Fetch all physical rooms in this building
        rooms_sql = """
            SELECT 
                r.id,
                r.room_number,
                r.room_code,
                r.name AS room_name,
                r.room_type,
                COALESCE(NULLIF(r.purpose, ''), r.room_type || ' space') AS purpose,
                r.floor_id,
                COALESCE(f.name, 'Ground Floor') AS floor_name,
                COALESCE(f.floor_level, 0) AS floor_number,
                r.max_capacity,
                COALESCE(r.seating_capacity, r.max_capacity) AS seating_capacity,
                COALESCE(r.recommended_capacity, r.max_capacity) AS recommended_capacity,
                r.current_occupancy,
                COALESCE(r.area, 0.0) AS area,
                COALESCE(r.area_unit, 'sq ft') AS area_unit,
                COALESCE(r.length, 0.0) AS length,
                COALESCE(r.width, 0.0) AS width,
                COALESCE(r.height, 0.0) AS height,
                COALESCE(r.num_doors, 1) AS num_doors,
                COALESCE(r.num_windows, 2) AS num_windows,
                COALESCE(r.operational_status, 'Available') AS operational_status,
                COALESCE(r.assignment_status, 'Unassigned') AS assignment_status,
                r.is_differently_abled_accessible,
                COALESCE(r.lift_proximity, 'Nearby') AS lift_proximity,
                COALESCE(r.emergency_exit_proximity, 'Direct Access') AS emergency_exit_proximity,
                r.responsible_person_name,
                r.metadata,
                r.is_bookable,
                r.building_id,
                r.school_id,
                r.created_at,
                r.description
            FROM public.rooms r
            LEFT JOIN public.building_floors f ON r.floor_id = f.id
            WHERE r.building_id = %s::UUID AND r.school_id = %s::UUID AND r.deleted_at IS NULL
            ORDER BY f.floor_level ASC, r.room_number ASC;
        """
        rooms_rows = await exec_sql(rooms_sql, (building_id, school_id))

        # 3. Fetch all space bookings for this building on query_date
        bookings_sql = """
            SELECT 
                sb.id,
                sb.booking_ref,
                sb.title,
                sb.purpose,
                sb.category,
                sb.room_id,
                sb.floor_id,
                sb.booking_date,
                sb.start_time,
                sb.end_time,
                sb.status,
                sb.attendee_count,
                sb.organizer_name,
                sb.organizer_role,
                sb.special_instructions,
                sb.is_recurring
            FROM public.space_bookings sb
            WHERE sb.building_id = %s::UUID 
              AND sb.school_id = %s::UUID 
              AND sb.booking_date = %s::DATE 
              AND sb.deleted_at IS NULL 
              AND sb.status NOT IN ('Cancelled', 'Rejected')
            ORDER BY sb.start_time ASC;
        """
        bookings_rows = await exec_sql(bookings_sql, (building_id, school_id, query_date))

        # 4. Fetch active room assignments for fallback/reference
        assignments_sql = """
            SELECT 
                ra.room_id, 
                ra.reference_module, 
                ra.reference_name, 
                ra.assignment_purpose, 
                ra.assigned_to_name, 
                ra.status, 
                ra.start_date, 
                ra.end_date, 
                ra.notes
            FROM public.room_assignments ra
            JOIN public.rooms r ON ra.room_id = r.id
            WHERE r.building_id = %s::UUID 
              AND ra.school_id = %s::UUID 
              AND ra.deleted_at IS NULL 
              AND ra.status = 'Active';
        """
        assignments_rows = await exec_sql(assignments_sql, (building_id, school_id))

        # Group bookings and assignments by room_id
        bookings_by_room = {}
        for b in bookings_rows:
            rid = str(b["room_id"])
            if rid not in bookings_by_room:
                bookings_by_room[rid] = []
            bookings_by_room[rid].append(b)

        assignments_by_room = {str(a["room_id"]): a for a in assignments_rows}

        # 5. Correlate rooms with space bookings
        all_rooms_data = []
        for r in rooms_rows:
            rid = str(r["id"])
            b_list = bookings_by_room.get(rid, [])
            assign = assignments_by_room.get(rid)

            meta = r.get("metadata") or {}
            facilities = meta.get("facilities") or meta.get("amenities") or []
            if not facilities:
                rtype = (r.get("room_type") or "").lower()
                if "lab" in rtype:
                    facilities = ["Laboratory Equipment", "Air Conditioning", "High-speed WiFi", "Safety Shower", "Projector"]
                elif "computer" in rtype:
                    facilities = ["Computer Workstations", "Air Conditioning", "High-speed WiFi", "Smart Board", "UPS Backup"]
                elif "conf" in rtype or "meeting" in rtype:
                    facilities = ["Video Conferencing", "Smart Display", "Air Conditioning", "High-speed WiFi", "Mic System"]
                else:
                    facilities = ["Whiteboard", "Smart Board", "Air Conditioning", "High-speed WiFi", "Projector"]

            op_status = (r.get("operational_status") or "").lower()
            active_booking = None
            next_booking = None
            booking_status = "AVAILABLE_NOW"
            status_display = "Available Now"

            if "maintenance" in op_status or "repair" in op_status or "out of service" in op_status:
                booking_status = "MAINTENANCE"
                status_display = "Under Maintenance"
            elif is_today:
                # Find active booking running right now
                for b in b_list:
                    b_st = _parse_time_str(b["start_time"])
                    b_et = _parse_time_str(b["end_time"])
                    if b_st <= now_time <= b_et:
                        active_booking = b
                        break

                if active_booking:
                    booking_status = "OCCUPIED_NOW"
                    status_display = "Occupied Now"
                else:
                    for b in b_list:
                        b_st = _parse_time_str(b["start_time"])
                        if b_st > now_time:
                            next_booking = b
                            break
                    if next_booking:
                        booking_status = "AVAILABLE_NOW"
                        status_display = f"Next: {next_booking['title']} at {str(next_booking['start_time'])[:5]}"
                    else:
                        booking_status = "AVAILABLE_NOW"
                        status_display = "Available All Day" if not b_list else "Available Now"
            elif query_date > date.today():
                if b_list:
                    booking_status = "SCHEDULED_LATER"
                    status_display = f"{len(b_list)} Session{'s' if len(b_list) > 1 else ''} Scheduled"
                    next_booking = b_list[0]
                else:
                    booking_status = "AVAILABLE_NOW"
                    status_display = "Available"
            else: # Past date
                if b_list:
                    booking_status = "OCCUPIED_NOW"
                    status_display = f"{len(b_list)} Past Session{'s' if len(b_list) > 1 else ''}"
                    active_booking = b_list[0]
                else:
                    booking_status = "AVAILABLE_NOW"
                    status_display = "Was Available"

            # Determine active / primary reference display
            active_title = active_booking["title"] if active_booking else (next_booking["title"] if next_booking else (b_list[0]["title"] if b_list else (assign["reference_name"] if assign else r["room_name"])))
            active_teacher = active_booking["organizer_name"] if active_booking else (next_booking["organizer_name"] if next_booking else (b_list[0]["organizer_name"] if b_list else (assign["assigned_to_name"] if assign else r.get("responsible_person_name") or "Academic Coordinator")))
            active_purpose = active_booking["purpose"] if active_booking else (next_booking["purpose"] if next_booking else (b_list[0]["purpose"] if b_list else (assign["assignment_purpose"] if assign else r.get("purpose") or "Academic Space")))
            active_time_range = f"{str(active_booking['start_time'])[:5]} - {str(active_booking['end_time'])[:5]}" if active_booking else (f"{str(next_booking['start_time'])[:5]} - {str(next_booking['end_time'])[:5]}" if next_booking else "")
            active_attendees = active_booking["attendee_count"] if active_booking else (r.get("current_occupancy") if booking_status == "OCCUPIED_NOW" else 0)

            # Today's bookings serialized
            formatted_bookings = []
            for b in b_list:
                formatted_bookings.append({
                    "id": str(b["id"]),
                    "booking_ref": b["booking_ref"],
                    "title": b["title"],
                    "purpose": b["purpose"],
                    "category": b["category"],
                    "start_time": str(b["start_time"])[:5],
                    "end_time": str(b["end_time"])[:5],
                    "status": b["status"],
                    "attendee_count": b["attendee_count"],
                    "organizer_name": b["organizer_name"],
                    "organizer_role": b["organizer_role"],
                    "special_instructions": b.get("special_instructions") or "",
                    "is_recurring": b.get("is_recurring", False)
                })

            item = {
                "id": rid,
                "room_id": rid,
                "room_number": r["room_number"],
                "room_code": r["room_code"],
                "room_name": r["room_name"],
                "name": r["room_name"],
                "floor_id": str(r["floor_id"]) if r.get("floor_id") else "",
                "floor_name": r["floor_name"],
                "floor_number": r["floor_number"],
                "room_type": r["room_type"],
                "type": r["room_type"],
                "max_capacity": r["max_capacity"],
                "capacity": r["max_capacity"],
                "seating_capacity": r["seating_capacity"],
                "recommended_capacity": r["recommended_capacity"],
                "current_occupancy": active_attendees,
                "area": float(r["area"]),
                "area_unit": r["area_unit"],
                "length": float(r["length"]),
                "width": float(r["width"]),
                "height": float(r["height"]),
                "num_doors": r["num_doors"],
                "num_windows": r["num_windows"],
                "facilities": facilities,
                "operational_status": r["operational_status"],
                "assignment_status": r["assignment_status"],
                "booking_status": booking_status,
                "status_display": status_display,
                "active_booking": _serialize_val(active_booking) if active_booking else None,
                "next_booking": _serialize_val(next_booking) if next_booking else None,
                "active_title": active_title,
                "active_teacher": active_teacher,
                "active_purpose": active_purpose,
                "active_time_range": active_time_range,
                "today_bookings": formatted_bookings,
                "today_sessions_count": len(formatted_bookings),
                "is_bookable": r["is_bookable"],
                "is_differently_abled_accessible": r["is_differently_abled_accessible"],
                "lift_proximity": r["lift_proximity"],
                "emergency_exit_proximity": r["emergency_exit_proximity"],
                # Compatibility fields with legacy room_assignments
                "reference_module": "Academics",
                "reference_name": active_title,
                "assignment_purpose": active_purpose,
                "assigned_to_name": active_teacher,
                "start_date": query_date.isoformat(),
                "end_date": None,
                "status": "Active" if booking_status != "MAINTENANCE" else "Maintenance",
                "notes": r.get("description") or f"Capacity: {r['max_capacity']} seats",
                "created_at": r["created_at"].isoformat() if r.get("created_at") else None,
            }
            all_rooms_data.append(item)

        # 6. Compute dynamic building-level KPIs for query_date
        total_cap = sum(r["max_capacity"] for r in all_rooms_data)
        total_rooms_count = len(all_rooms_data)
        in_use_rooms_now = sum(1 for r in all_rooms_data if r["booking_status"] == "OCCUPIED_NOW")
        in_use_capacity_now = sum(r["max_capacity"] for r in all_rooms_data if r["booking_status"] == "OCCUPIED_NOW")
        available_rooms_now = sum(1 for r in all_rooms_data if r["booking_status"] == "AVAILABLE_NOW")
        scheduled_today_rooms = sum(1 for r in all_rooms_data if r["today_sessions_count"] > 0)
        today_total_sessions = sum(r["today_sessions_count"] for r in all_rooms_data)
        maintenance_rooms = sum(1 for r in all_rooms_data if r["booking_status"] == "MAINTENANCE")
        occ_rate = round((in_use_capacity_now / total_cap * 100.0), 1) if total_cap > 0 else 0.0

        # 7. Apply filtering
        filtered_items = all_rooms_data
        search_val = search.strip().lower() if isinstance(search, str) and search.strip() else None
        if search_val:
            filtered_items = [
                r for r in filtered_items
                if search_val in r["room_name"].lower()
                or search_val in r["room_number"].lower()
                or search_val in r["room_code"].lower()
                or search_val in r["floor_name"].lower()
                or search_val in r["active_title"].lower()
                or search_val in r["active_teacher"].lower()
                or search_val in r["room_type"].lower()
            ]

        status_filt_val = status_filter.strip().upper() if isinstance(status_filter, str) and status_filter.strip() else None
        if status_filt_val and status_filt_val != "ALL":
            if status_filt_val == "OCCUPIED_NOW":
                filtered_items = [r for r in filtered_items if r["booking_status"] == "OCCUPIED_NOW"]
            elif status_filt_val == "AVAILABLE_NOW":
                filtered_items = [r for r in filtered_items if r["booking_status"] == "AVAILABLE_NOW"]
            elif status_filt_val in ("SCHEDULED_LATER", "SCHEDULED_TODAY"):
                filtered_items = [r for r in filtered_items if r["today_sessions_count"] > 0]
            elif status_filt_val == "MAINTENANCE":
                filtered_items = [r for r in filtered_items if r["booking_status"] == "MAINTENANCE"]

        floor_id_val = floor_id.strip() if isinstance(floor_id, str) and floor_id.strip() and floor_id.strip().lower() != "all" else None
        if floor_id_val:
            filtered_items = [r for r in filtered_items if r["floor_id"] == floor_id_val]

        room_type_val = room_type.strip().lower() if isinstance(room_type, str) and room_type.strip() and room_type.strip().lower() != "all" else None
        if room_type_val:
            filtered_items = [r for r in filtered_items if r["room_type"].lower() == room_type_val]

        # 8. Sort
        sort_by_val = sort_by.strip() if isinstance(sort_by, str) and sort_by.strip() else "room_number"
        sort_order_val = sort_order.strip().lower() if isinstance(sort_order, str) else "asc"
        reverse = (sort_order_val == "desc")

        if sort_by_val in ("room_number", "room_name", "floor_name", "room_type", "booking_status"):
            filtered_items.sort(key=lambda x: str(x.get(sort_by_val, "")).lower(), reverse=reverse)
        elif sort_by_val in ("capacity", "max_capacity", "current_occupancy", "today_sessions_count", "area"):
            filtered_items.sort(key=lambda x: float(x.get(sort_by_val, 0) or 0), reverse=reverse)

        # 9. Paginate
        page_val = int(page) if isinstance(page, (int, str)) and str(page).isdigit() else 1
        page_size_val = int(page_size) if isinstance(page_size, (int, str)) and str(page_size).isdigit() else 200
        offset = max(0, (page_val - 1) * page_size_val)
        paged_items = filtered_items[offset : offset + page_size_val]

        return {
            "success": True,
            "target_date": query_date.isoformat(),
            "is_today": is_today,
            "metrics": {
                "total_capacity": total_cap,
                "current_occupancy": in_use_capacity_now,
                "available_capacity": max(0, total_cap - in_use_capacity_now),
                "occupancy_rate": occ_rate,
                "total_rooms": total_rooms_count,
                "occupied_rooms": in_use_rooms_now,
                "available_rooms": available_rooms_now,
                "scheduled_today_rooms": scheduled_today_rooms,
                "today_total_sessions": today_total_sessions,
                "maintenance_rooms": maintenance_rooms,
            },
            "total_count": len(filtered_items),
            "page": page_val,
            "page_size": page_size_val,
            "data": paged_items
        }
    except Exception as e:
        logger.error(f"Error fetching dynamic building occupancy: {e}")
        raise HTTPException(status_code=500, detail=f"Database query error: {str(e)}")


@router.post("/buildings/{building_id}/assign-section")
async def assign_class_section_to_room(
    building_id: str,
    payload: AssignSectionPayload,
    user: dict = Depends(get_current_user),
):
    """
    Assign Academic Class & Section to a Room via Space Booking.
    Ensures capacity validation, checks for room scheduling conflicts,
    creates confirmed space booking(s), and updates section and room allocations.
    """
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    try:
        # 1. Verify Room exists in this building
        room_check_sql = """
            SELECT r.id, r.room_number, r.name, r.floor_id, r.max_capacity, r.building_id, b.name AS building_name
            FROM public.rooms r
            JOIN public.buildings b ON r.building_id = b.id
            WHERE r.id = %s::UUID AND r.school_id = %s::UUID AND r.deleted_at IS NULL;
        """
        room_rows = await exec_sql(room_check_sql, (payload.room_id, school_id))
        if not room_rows:
            raise HTTPException(status_code=404, detail="Selected room not found or does not belong to this institution.")
        room = room_rows[0]

        # 2. Parse and format date & times
        b_date_str = payload.booking_date.strip() if payload.booking_date and payload.booking_date.strip() else date.today().isoformat()
        try:
            b_date = datetime.strptime(b_date_str[:10], "%Y-%m-%d").date()
        except Exception:
            b_date = date.today()

        st_clean = payload.start_time.strip()
        et_clean = payload.end_time.strip()
        if len(st_clean) == 5: st_clean += ":00"
        if len(et_clean) == 5: et_clean += ":00"
        start_t = _parse_time_str(st_clean)
        end_t = _parse_time_str(et_clean)

        if start_t >= end_t:
            raise HTTPException(status_code=400, detail="Start time must be strictly before end time.")

        # Determine target dates (for recurring series or single booking)
        target_dates = [b_date]
        if payload.is_recurring and payload.recurrence_count and payload.recurrence_count > 1:
            freq = (payload.recurrence_frequency or "DAILY").upper()
            curr = b_date
            count = min(payload.recurrence_count, 30) # clamp to max 30 occurrences
            while len(target_dates) < count:
                curr += timedelta(days=1)
                if freq == "WEEKDAYS" and curr.weekday() >= 5: # Skip Sat & Sun
                    continue
                elif freq == "WEEKLY" and (curr - b_date).days % 7 != 0:
                    continue
                target_dates.append(curr)

        # 3. Conflict Detection across target dates
        conflicts = []
        for d in target_dates:
            conflict_sql = """
                SELECT id, title, start_time, end_time, organizer_name
                FROM public.space_bookings
                WHERE room_id = %s::UUID 
                  AND booking_date = %s::DATE 
                  AND status NOT IN ('Cancelled', 'Rejected') 
                  AND deleted_at IS NULL
                  AND start_time < %s::TIME AND end_time > %s::TIME
                LIMIT 1;
            """
            c_rows = await exec_sql(conflict_sql, (payload.room_id, d, et_clean, st_clean))
            if c_rows:
                conflicts.append({
                    "date": d.isoformat(),
                    "title": c_rows[0]["title"],
                    "time": f"{str(c_rows[0]['start_time'])[:5]} - {str(c_rows[0]['end_time'])[:5]}",
                    "organizer": c_rows[0]["organizer_name"]
                })

        if conflicts:
            first_c = conflicts[0]
            raise HTTPException(
                status_code=409,
                detail=f"Scheduling Conflict on {first_c['date']}: Room is already booked for '{first_c['title']}' ({first_c['time']}) by {first_c['organizer']}."
            )

        # 4. Insert Confirmed Space Bookings
        booking_title = f"{payload.class_name} - {payload.section_name}" + (f" ({payload.subject})" if payload.subject else "")
        created_booking_ids = []
        primary_ref = ""

        duration_mins = int((datetime.combine(b_date, end_t) - datetime.combine(b_date, start_t)).total_seconds() / 60)

        for d in target_dates:
            ref_num = f"SB-{d.strftime('%Y%m%d')}-{random.randint(1000, 9999)}"
            if not primary_ref:
                primary_ref = ref_num
            start_dt = datetime.combine(d, start_t)
            end_dt = datetime.combine(d, end_t)

            insert_sb_sql = """
                INSERT INTO public.space_bookings (
                    school_id, booking_ref, title, description, purpose, category,
                    booking_type, priority, building_id, floor_id, room_id,
                    booking_date, start_time, end_time, start_datetime, end_datetime,
                    buffer_start_datetime, buffer_end_datetime, duration_minutes,
                    organizer_name, organizer_role, attendee_count, status, is_approved,
                    approval_level, approved_at, special_instructions, is_recurring,
                    created_by, updated_by
                ) VALUES (
                    %s::UUID, %s, %s, %s, 'Academic', 'Academic - Class / Lecture Instruction',
                    'Internal', 'Normal', %s::UUID, %s::UUID, %s::UUID,
                    %s::DATE, %s::TIME, %s::TIME, %s, %s,
                    %s, %s, %s,
                    %s, 'Faculty', %s, 'Confirmed', true,
                    1, NOW(), %s, %s,
                    (SELECT id FROM public.profiles WHERE id = %s::UUID LIMIT 1),
                    (SELECT id FROM public.profiles WHERE id = %s::UUID LIMIT 1)
                ) RETURNING id;
            """
            sb_params = (
                school_id, ref_num, booking_title, payload.notes or f"Class Allocation for {booking_title}",
                room["building_id"], room["floor_id"], payload.room_id,
                d, st_clean, et_clean, start_dt, end_dt,
                start_dt, end_dt, duration_mins,
                payload.teacher_name or "Academic Faculty", payload.attendee_count or 35,
                payload.notes or "", payload.is_recurring,
                user_id, user_id
            )
            sb_rows = await exec_sql(insert_sb_sql, sb_params)
            if sb_rows:
                created_booking_ids.append(str(sb_rows[0]["id"]))

        # 5. Update academic_sections if section_id is provided
        if payload.section_id:
            await exec_sql(
                """
                UPDATE public.academic_sections 
                SET room_id = %s::UUID, room_number = %s, updated_at = NOW()
                WHERE id = %s::UUID AND school_id = %s::UUID;
                """,
                (payload.room_id, room["room_number"], payload.section_id, school_id),
                fetch=False
            )

        # 6. Update room occupancy & assignment status
        attendees = payload.attendee_count or 35
        await exec_sql(
            """
            UPDATE public.rooms
            SET assignment_status = 'Assigned',
                current_occupancy = CASE WHEN current_occupancy = 0 THEN %s ELSE current_occupancy END,
                updated_at = NOW()
            WHERE id = %s::UUID AND school_id = %s::UUID;
            """,
            (attendees, payload.room_id, school_id),
            fetch=False
        )

        # 7. Synchronize room_assignments record for cross-module compatibility
        await exec_sql(
            """
            INSERT INTO public.room_assignments (
                school_id, room_id, reference_module, reference_name,
                assignment_purpose, start_date, end_date, assigned_to_name,
                status, notes, created_by
            ) VALUES (
                %s::UUID, %s::UUID, 'Academics', %s,
                %s, %s::DATE, NULL, %s,
                'Active', %s, (SELECT id FROM public.profiles WHERE id = %s::UUID LIMIT 1)
            )
            ON CONFLICT DO NOTHING;
            """,
            (
                school_id, payload.room_id, f"{payload.class_name} - {payload.section_name}",
                f"Class Session ({payload.subject or 'General'})", b_date,
                payload.teacher_name or "Academic Faculty",
                payload.notes or "Allocated via Space Booking", user_id
            ),
            fetch=False
        )

        return {
            "success": True,
            "message": f"Successfully allocated {payload.class_name} - {payload.section_name} to Room {room['room_number']}.",
            "booking_ref": primary_ref,
            "bookings_count": len(created_booking_ids),
            "booking_ids": created_booking_ids,
            "room_id": payload.room_id,
            "room_number": room["room_number"],
            "booking_date": b_date.isoformat(),
            "time_range": f"{st_clean[:5]} - {et_clean[:5]}"
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error assigning section to room: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to assign section to room: {str(e)}")


@router.get("/academic-entities-for-allocation")
async def get_academic_entities_for_allocation(
    user: dict = Depends(get_current_user),
):
    """Retrieve all classes, sections, and subjects for quick space allocation dropdowns."""
    school_id = _get_school_id(user)
    try:
        classes_sql = """
            SELECT c.id, c.name, c.code, c.stage, c.display_order
            FROM public.academic_classes c
            WHERE c.school_id = %s::UUID AND c.deleted_at IS NULL
            ORDER BY c.display_order ASC, c.name ASC;
        """
        c_rows = await exec_sql(classes_sql, (school_id,))

        sections_sql = """
            SELECT s.id, s.class_id, s.name, s.code, s.capacity, s.room_number, s.room_id,
                   COALESCE((SELECT COUNT(*) FROM public.student_class_assignments sca WHERE sca.section_id = s.id AND sca.status = 'ACTIVE'), 0)::INT AS student_count
            FROM public.academic_sections s
            WHERE s.school_id = %s::UUID AND s.deleted_at IS NULL
            ORDER BY s.display_order ASC, s.name ASC;
        """
        s_rows = await exec_sql(sections_sql, (school_id,))

        subjects_sql = """
            SELECT id, name, code, type
            FROM public.academic_subjects
            WHERE school_id = %s::UUID AND deleted_at IS NULL
            ORDER BY name ASC;
        """
        sub_rows = await exec_sql(subjects_sql, (school_id,))

        # Optional class-specific subject mappings
        class_subjects_map = {}
        try:
            class_subjects_rows = await exec_sql(
                """
                SELECT csa.class_id,
                       json_agg(
                         DISTINCT jsonb_build_object('id', sub.id, 'name', sub.name, 'code', sub.code)
                       ) as subjects
                FROM public.class_subject_assignments csa
                JOIN public.academic_subjects sub ON sub.id = csa.subject_id
                WHERE csa.school_id = %s::UUID
                  AND (csa.status = 'ACTIVE' OR csa.status IS NULL)
                  AND sub.deleted_at IS NULL
                  AND (sub.status = 'ACTIVE' OR sub.status IS NULL OR sub.status = 'Active')
                GROUP BY csa.class_id;
                """,
                (school_id,)
            )
            for r in (class_subjects_rows or []):
                subs = r.get("subjects") or []
                if isinstance(subs, list):
                    subs.sort(key=lambda x: str(x.get("name", "")).lower())
                class_subjects_map[str(r["class_id"])] = subs
        except Exception as csa_err:
            logger.warning(f"Class subject assignments query ignored: {csa_err}")

        sections_by_class = {}
        for s in s_rows:
            cid = str(s["class_id"])
            if cid not in sections_by_class:
                sections_by_class[cid] = []
            sections_by_class[cid].append({
                "id": str(s["id"]),
                "name": s["name"],
                "code": s["code"],
                "capacity": s["capacity"],
                "student_count": s["student_count"],
                "room_number": s["room_number"],
                "room_id": str(s["room_id"]) if s.get("room_id") else None,
            })

        classes_list = []
        for c in c_rows:
            cid = str(c["id"])
            classes_list.append({
                "id": cid,
                "name": c["name"],
                "code": c["code"],
                "stage": c["stage"],
                "sections": sections_by_class.get(cid, [])
            })

        return {
            "success": True,
            "classes": classes_list,
            "subjects": [{"id": str(sb["id"]), "name": sb["name"], "code": sb["code"]} for sb in sub_rows],
            "class_subjects": class_subjects_map
        }
    except Exception as e:
        logger.error(f"Error fetching academic entities for allocation: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/buildings/{building_id}/occupancy")
async def create_building_occupancy(
    building_id: str,
    payload: BuildingOccupancyPayload,
    user: dict = Depends(get_current_user),
):
    """Allocate a room in this building."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    try:
        sql = """
            INSERT INTO public.room_assignments (
                school_id, room_id, reference_module, reference_name,
                assignment_purpose, start_date, end_date, assigned_to_name,
                status, notes, created_by
            ) VALUES (
                %s::UUID, %s::UUID, %s, %s,
                %s, %s::DATE, %s::DATE, %s,
                %s, %s, (SELECT id FROM public.profiles WHERE id = %s::UUID LIMIT 1)
            ) RETURNING *;
        """
        params = (
            school_id, payload.room_id, payload.reference_module or "General", payload.reference_name,
            payload.assignment_purpose or "General Allocation", payload.start_date, payload.end_date,
            payload.assigned_to_name, payload.status or "Active", payload.notes, user_id
        )
        rows = await exec_sql(sql, params)

        # Mark room as Assigned and update occupancy
        await exec_sql(
            """
            UPDATE public.rooms
            SET assignment_status = 'Assigned',
                current_occupancy = CASE WHEN current_occupancy = 0 THEN max_capacity ELSE current_occupancy END
            WHERE id = %s::UUID AND school_id = %s::UUID
            """,
            (payload.room_id, school_id),
            fetch=False
        )

        return {"success": True, "data": _serialize_val(rows[0])}
    except Exception as e:
        logger.error(f"Error creating occupancy: {e}")
        raise HTTPException(status_code=500, detail=f"Database write error: {str(e)}")


@router.put("/buildings/{building_id}/occupancy/{assignment_id}")
async def update_building_occupancy(
    building_id: str,
    assignment_id: str,
    payload: BuildingOccupancyPayload,
    user: dict = Depends(get_current_user),
):
    """Update occupancy allocation details."""
    school_id = _get_school_id(user)
    try:
        sql = """
            UPDATE public.room_assignments SET
                reference_module = %s,
                reference_name = %s,
                assignment_purpose = %s,
                start_date = %s::DATE,
                end_date = %s::DATE,
                assigned_to_name = %s,
                status = %s,
                notes = %s,
                updated_at = NOW()
            WHERE id = %s::UUID AND school_id = %s::UUID AND deleted_at IS NULL
            RETURNING *;
        """
        params = (
            payload.reference_module or "Academics", payload.reference_name, payload.assignment_purpose,
            payload.start_date, payload.end_date, payload.assigned_to_name, payload.status or "Active",
            payload.notes, assignment_id, school_id
        )
        rows = await exec_sql(sql, params)
        if not rows:
            # Fallback in case assignment_id is a room_id (e.g. from synthesized row)
            room_check = await exec_sql(
                "SELECT id FROM public.rooms WHERE id = %s::UUID AND school_id = %s::UUID AND deleted_at IS NULL",
                (assignment_id, school_id)
            )
            if room_check:
                insert_sql = """
                    INSERT INTO public.room_assignments (
                        school_id, room_id, reference_module, reference_name,
                        assignment_purpose, start_date, end_date, assigned_to_name,
                        status, notes, created_by
                    ) VALUES (
                        %s::UUID, %s::UUID, %s, %s,
                        %s, %s::DATE, %s::DATE, %s,
                        %s, %s, (SELECT id FROM public.profiles WHERE id = %s::UUID LIMIT 1)
                    ) RETURNING *;
                """
                insert_params = (
                    school_id, assignment_id, payload.reference_module or "Academics", payload.reference_name,
                    payload.assignment_purpose or "General Allocation", payload.start_date, payload.end_date,
                    payload.assigned_to_name, payload.status or "Active", payload.notes, _get_user_id(user)
                )
                rows = await exec_sql(insert_sql, insert_params)
            else:
                raise HTTPException(status_code=404, detail="Occupancy record not found")
        return {"success": True, "data": _serialize_val(rows[0])}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating occupancy: {e}")
        raise HTTPException(status_code=500, detail=f"Database write error: {str(e)}")


@router.delete("/buildings/{building_id}/occupancy/{assignment_id}")
async def delete_building_occupancy(
    building_id: str,
    assignment_id: str,
    user: dict = Depends(get_current_user),
):
    """Release / deallocate occupancy and free room."""
    school_id = _get_school_id(user)
    try:
        sql = """
            UPDATE public.room_assignments
            SET deleted_at = NOW(), status = 'Released'
            WHERE id = %s::UUID AND school_id = %s::UUID
            RETURNING room_id;
        """
        rows = await exec_sql(sql, (assignment_id, school_id))
        if not rows:
            # Fallback in case assignment_id is a room_id (e.g. from synthesized row)
            room_check = await exec_sql(
                "SELECT id FROM public.rooms WHERE id = %s::UUID AND school_id = %s::UUID AND deleted_at IS NULL",
                (assignment_id, school_id)
            )
            if room_check:
                await exec_sql(
                    "UPDATE public.rooms SET assignment_status = 'Unassigned', current_occupancy = 0 WHERE id = %s::UUID",
                    (assignment_id,),
                    fetch=False
                )
                return {"success": True, "message": "Allocation released successfully"}
            raise HTTPException(status_code=404, detail="Occupancy record not found")

        room_id = rows[0]["room_id"]
        # Check if any active assignments remain for room
        active_check = await exec_sql(
            "SELECT COUNT(id)::INT AS cnt FROM public.room_assignments WHERE room_id = %s::UUID AND deleted_at IS NULL AND status = 'Active'",
            (room_id,)
        )
        if active_check and active_check[0]["cnt"] == 0:
            await exec_sql(
                "UPDATE public.rooms SET assignment_status = 'Unassigned', current_occupancy = 0 WHERE id = %s::UUID",
                (room_id,),
                fetch=False
            )

        return {"success": True, "message": "Allocation released successfully"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting occupancy: {e}")
        raise HTTPException(status_code=500, detail=f"Database execution error: {str(e)}")


# ----------------------------------------------------------------------------
# 14. Building Maintenance Requests CRUD
# ----------------------------------------------------------------------------
@router.get("/buildings/{building_id}/maintenance")
async def list_building_maintenance(
    building_id: str,
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=100),
    sort_by: Optional[str] = Query(None),
    sort_order: Optional[str] = Query("desc"),
    user: dict = Depends(get_current_user),
):
    """List maintenance requests and work orders for a building with sorting and pagination."""
    school_id = _get_school_id(user)
    try:
        count_sql = """
            SELECT COUNT(*) AS total
            FROM public.maintenance_requests mr
            LEFT JOIN public.rooms r ON mr.room_id = r.id
            WHERE (mr.building_id = %s::UUID OR r.building_id = %s::UUID)
              AND mr.school_id = %s::UUID AND mr.deleted_at IS NULL
        """
        count_rows = await exec_sql(count_sql, (building_id, building_id, school_id))
        total = count_rows[0]["total"] if count_rows else 0

        sort_col = "mr.created_at"
        if sort_by == "request_code": sort_col = "mr.request_code"
        elif sort_by == "title": sort_col = "mr.title"
        elif sort_by == "request_type": sort_col = "mr.request_type"
        elif sort_by == "priority": sort_col = "mr.priority"
        elif sort_by == "status": sort_col = "mr.status"
        elif sort_by == "room_number": sort_col = "r.room_number"
        elif sort_by == "assigned_to_name": sort_col = "mr.assigned_to_name"
        elif sort_by == "scheduled_at": sort_col = "mr.scheduled_at"
        elif sort_by == "estimated_cost": sort_col = "mr.estimated_cost"
        elif sort_by == "created_at": sort_col = "mr.created_at"

        order_dir = "ASC" if (sort_order or "").lower() == "asc" else "DESC"
        offset = max(0, (page - 1) * page_size)

        sql = f"""
            SELECT mr.id, mr.request_code, mr.title, mr.description, mr.request_type,
                   mr.priority, mr.status, mr.building_id, mr.floor_id, mr.room_id,
                   r.room_number, f.name AS floor_name, mr.location_display, mr.reported_by_name, mr.assigned_to_name,
                   mr.scheduled_at, mr.preferred_date, mr.estimated_cost, mr.actual_cost,
                   mr.resolution_notes, mr.created_at
            FROM public.maintenance_requests mr
            LEFT JOIN public.rooms r ON mr.room_id = r.id
            LEFT JOIN public.building_floors f ON mr.floor_id = f.id
            WHERE (mr.building_id = %s::UUID OR r.building_id = %s::UUID)
              AND mr.school_id = %s::UUID AND mr.deleted_at IS NULL
            ORDER BY {sort_col} {order_dir}
            LIMIT %s OFFSET %s
        """
        rows = await exec_sql(sql, (building_id, building_id, school_id, page_size, offset))
        return {
            "success": True,
            "total_count": total,
            "page": page,
            "page_size": page_size,
            "data": [_serialize_val(r) for r in rows]
        }
    except Exception as e:
        logger.error(f"Error listing building maintenance: {e}")
        raise HTTPException(status_code=500, detail=f"Database query error: {str(e)}")


@router.post("/buildings/{building_id}/maintenance")
async def create_building_maintenance(
    building_id: str,
    payload: CampusMaintenancePayload,
    user: dict = Depends(get_current_user),
):
    """Create a new maintenance request for this building."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    req_code = f"MT-{uuid.uuid4().hex[:6].upper()}"
    try:
        # Resolve location_display
        loc_display = (payload.location_display or "").strip()
        if not loc_display:
            parts = []
            b_res = await exec_sql("SELECT name, code FROM public.buildings WHERE id = %s::UUID LIMIT 1;", (building_id,))
            b_name = b_res[0]["code"] if b_res and b_res[0].get("code") else (b_res[0]["name"] if b_res else "Building")
            parts.append(b_name)
            if payload.floor_id:
                f_res = await exec_sql("SELECT name, floor_number FROM public.building_floors WHERE id = %s::UUID LIMIT 1;", (payload.floor_id,))
                if f_res:
                    parts.append(f_res[0]["name"] or f"Floor {f_res[0]['floor_number']}")
            if payload.room_id:
                r_res = await exec_sql("SELECT room_number, name FROM public.rooms WHERE id = %s::UUID LIMIT 1;", (payload.room_id,))
                if r_res:
                    parts.append(r_res[0]["room_number"] or r_res[0]["name"] or "Room")
            if len(parts) == 1:
                parts.append("Entire Building / Common")
            loc_display = " / ".join(parts)

        sql = """
            INSERT INTO public.maintenance_requests (
                school_id, request_code, title, description, request_type,
                priority, status, building_id, floor_id, room_id, location_display,
                reported_by_name, reported_by_user_id, assigned_to_name,
                preferred_date, estimated_cost, actual_cost, resolution_notes,
                created_by, created_at, updated_at
            ) VALUES (
                %s::UUID, %s, %s, %s, %s,
                %s, %s, %s::UUID, NULLIF(%s, '')::UUID, NULLIF(%s, '')::UUID, %s,
                %s, %s::UUID, %s,
                %s::DATE, %s, %s, %s,
                %s::UUID, NOW(), NOW()
            ) RETURNING *;
        """
        params = (
            school_id, req_code, payload.title, payload.description, payload.request_type or "Corrective",
            payload.priority or "Medium", payload.status or "Pending", building_id, payload.floor_id, payload.room_id, loc_display,
            payload.reported_by_name or user.get("full_name") or "Campus Administrator", user_id, payload.assigned_to_name,
            payload.preferred_date, payload.estimated_cost or 0.0, payload.actual_cost or 0.0, payload.resolution_notes,
            user_id
        )
        rows = await exec_sql(sql, params)
        return {"success": True, "data": _serialize_val(rows[0])}
    except Exception as e:
        logger.error(f"Error creating building maintenance: {e}")
        raise HTTPException(status_code=500, detail=f"Database write error: {str(e)}")


@router.put("/buildings/{building_id}/maintenance/{request_id}")
async def update_building_maintenance(
    building_id: str,
    request_id: str,
    payload: CampusMaintenancePayload,
    user: dict = Depends(get_current_user),
):
    """Update maintenance request details or status."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    try:
        sql = """
            UPDATE public.maintenance_requests SET
                title = %s,
                description = %s,
                request_type = %s,
                priority = %s,
                status = %s,
                floor_id = NULLIF(%s, '')::UUID,
                room_id = NULLIF(%s, '')::UUID,
                location_display = COALESCE(NULLIF(%s, ''), location_display),
                assigned_to_name = %s,
                preferred_date = %s::DATE,
                estimated_cost = %s,
                actual_cost = %s,
                resolution_notes = %s,
                resolved_at = CASE WHEN %s = 'Completed' AND resolved_at IS NULL THEN NOW() ELSE resolved_at END,
                updated_by = %s::UUID,
                updated_at = NOW()
            WHERE id = %s::UUID AND school_id = %s::UUID AND deleted_at IS NULL
            RETURNING *;
        """
        params = (
            payload.title, payload.description, payload.request_type or "Corrective",
            payload.priority or "Medium", payload.status or "Pending",
            payload.floor_id, payload.room_id, payload.location_display, payload.assigned_to_name,
            payload.preferred_date, payload.estimated_cost or 0.0, payload.actual_cost or 0.0,
            payload.resolution_notes, payload.status, user_id,
            request_id, school_id
        )
        rows = await exec_sql(sql, params)
        if not rows:
            raise HTTPException(status_code=404, detail="Maintenance request not found")
        return {"success": True, "data": _serialize_val(rows[0])}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating building maintenance: {e}")
        raise HTTPException(status_code=500, detail=f"Database write error: {str(e)}")


@router.delete("/buildings/{building_id}/maintenance/{request_id}")
async def delete_building_maintenance(
    building_id: str,
    request_id: str,
    user: dict = Depends(get_current_user),
):
    """Soft-delete a maintenance request."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    try:
        sql = """
            UPDATE public.maintenance_requests
            SET deleted_at = NOW(), deleted_by = %s::UUID
            WHERE id = %s::UUID AND school_id = %s::UUID
            RETURNING id;
        """
        rows = await exec_sql(sql, (user_id, request_id, school_id))
        if not rows:
            raise HTTPException(status_code=404, detail="Maintenance request not found")
        return {"success": True, "message": "Maintenance request deleted successfully"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting building maintenance: {e}")
        raise HTTPException(status_code=500, detail=f"Database execution error: {str(e)}")


# ============================================================================
# ENTERPRISE CAMPUS FACILITIES
# ============================================================================

class FacilityCreateUpdateSchema(BaseModel):
    id: Optional[str] = None
    name: str = Field(..., min_length=2, max_length=255)
    code: str = Field(..., min_length=1, max_length=100)
    category: Optional[str] = "Specialized Laboratory"
    building_id: Optional[str] = None
    floor_id: Optional[str] = None
    capacity: Optional[int] = 50
    area: Optional[float] = 0.0
    manager_name: Optional[str] = None
    manager_phone: Optional[str] = None
    status: Optional[str] = "Operational"
    equipment_count: Optional[int] = 0
    description: Optional[str] = None


@router.get("/facilities", summary="List Campus Facilities with Filtering and Pagination")
async def list_campus_facilities(
    search: Optional[str] = Query(None),
    category: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    building_id: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    user: dict = Depends(get_current_user),
):
    school_id = _get_school_id(user)
    try:
        search_term = f"%{search.strip().lower()}%" if search and search.strip() else None
        cat = category if (category and category != 'All Categories') else None
        stat = status if (status and status != 'All Statuses') else None
        b_id = building_id if (building_id and building_id != 'all') else None

        offset = (page - 1) * page_size
        sql = """
            SELECT 
                f.id, f.name, f.code, f.category, f.building_id, f.floor_id,
                f.capacity, f.area, f.manager_name, f.manager_phone, f.status,
                f.equipment_count, f.description, f.created_at,
                b.name AS building_name, b.code AS building_code,
                fl.name AS floor_name
            FROM public.campus_facilities f
            LEFT JOIN public.buildings b ON f.building_id = b.id
            LEFT JOIN public.building_floors fl ON f.floor_id = fl.id
            WHERE f.school_id = %s::UUID AND f.deleted_at IS NULL
              AND (%s::VARCHAR IS NULL OR LOWER(f.name) LIKE %s::VARCHAR OR LOWER(f.code) LIKE %s::VARCHAR OR LOWER(f.category) LIKE %s::VARCHAR)
              AND (%s::VARCHAR IS NULL OR f.category = %s::VARCHAR)
              AND (%s::VARCHAR IS NULL OR f.status = %s::VARCHAR)
              AND (%s::UUID IS NULL OR f.building_id = %s::UUID)
            ORDER BY f.created_at DESC
            LIMIT %s OFFSET %s;
        """
        params = (
            school_id,
            search_term, search_term, search_term, search_term,
            cat, cat,
            stat, stat,
            b_id, b_id,
            page_size, offset
        )
        rows = await exec_sql(sql, params)

        count_sql = """
            SELECT COUNT(*) AS total
            FROM public.campus_facilities f
            WHERE f.school_id = %s::UUID AND f.deleted_at IS NULL
              AND (%s::VARCHAR IS NULL OR LOWER(f.name) LIKE %s::VARCHAR OR LOWER(f.code) LIKE %s::VARCHAR OR LOWER(f.category) LIKE %s::VARCHAR)
              AND (%s::VARCHAR IS NULL OR f.category = %s::VARCHAR)
              AND (%s::VARCHAR IS NULL OR f.status = %s::VARCHAR)
              AND (%s::UUID IS NULL OR f.building_id = %s::UUID);
        """
        count_rows = await exec_sql(count_sql, (school_id, search_term, search_term, search_term, search_term, cat, cat, stat, stat, b_id, b_id))
        total_count = count_rows[0]["total"] if count_rows else 0

        return {
            "success": True,
            "data": _serialize_val(rows),
            "total_count": total_count,
            "page": page,
            "page_size": page_size,
            "total_pages": max(1, (total_count + page_size - 1) // page_size),
        }
    except Exception as e:
        logger.error(f"Error listing facilities: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/facilities", summary="Create or Update Campus Facility")
async def save_campus_facility(
    payload: FacilityCreateUpdateSchema,
    user: dict = Depends(get_current_user),
):
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    try:
        b_id = payload.building_id if (payload.building_id and payload.building_id != 'all') else None
        f_id = payload.floor_id if (payload.floor_id and payload.floor_id != 'all') else None

        if payload.id:
            sql = """
                UPDATE public.campus_facilities
                SET name = %s, code = %s, category = %s,
                    building_id = %s::UUID, floor_id = %s::UUID,
                    capacity = %s, area = %s, manager_name = %s,
                    manager_phone = %s, status = %s,
                    description = %s, updated_by = %s::UUID, updated_at = NOW()
                WHERE id = %s::UUID AND school_id = %s::UUID AND deleted_at IS NULL
                RETURNING *;
            """
            params = (
                payload.name, payload.code, payload.category or "Specialized Laboratory",
                b_id, f_id, payload.capacity or 50, payload.area or 0.0,
                payload.manager_name, payload.manager_phone, payload.status or "Operational",
                payload.description, user_id, payload.id, school_id
            )
        else:
            sql = """
                INSERT INTO public.campus_facilities (
                    school_id, name, code, category, building_id, floor_id,
                    capacity, area, manager_name, manager_phone, status,
                    description, created_by, updated_by
                ) VALUES (
                    %s::UUID, %s, %s, %s, %s::UUID, %s::UUID,
                    %s, %s, %s, %s, %s, %s, %s::UUID, %s::UUID
                )
                RETURNING *;
            """
            params = (
                school_id, payload.name, payload.code, payload.category or "Specialized Laboratory",
                b_id, f_id, payload.capacity or 50, payload.area or 0.0,
                payload.manager_name, payload.manager_phone, payload.status or "Operational",
                payload.description, user_id, user_id
            )

        rows = await exec_sql(sql, params)
        if not rows:
            raise HTTPException(status_code=400, detail="Failed to save facility")
        return {"success": True, "data": _serialize_val(rows[0])}
    except Exception as e:
        logger.error(f"Error saving facility: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/facilities/{facility_id}", summary="Delete Campus Facility")
async def delete_campus_facility(
    facility_id: str,
    user: dict = Depends(get_current_user),
):
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    try:
        sql = """
            UPDATE public.campus_facilities
            SET deleted_at = NOW(), deleted_by = %s::UUID
            WHERE id = %s::UUID AND school_id = %s::UUID AND deleted_at IS NULL
            RETURNING id;
        """
        rows = await exec_sql(sql, (user_id, facility_id, school_id))
        if not rows:
            raise HTTPException(status_code=404, detail="Facility not found")
        return {"success": True, "message": "Facility deleted successfully"}
    except Exception as e:
        logger.error(f"Error deleting facility: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================================
# ENTERPRISE CAMPUS UTILITIES & SERVICES
# ============================================================================

class UtilityReadingCreateSchema(BaseModel):
    utility_name: str = Field(..., min_length=2, max_length=150)
    utility_type: str = Field(..., min_length=2, max_length=100)
    reading_value: str = Field(..., min_length=1, max_length=100)
    metric_units: Optional[str] = "kWh"
    location: str = Field(..., min_length=1, max_length=255)
    recorded_by: str = Field(..., min_length=1, max_length=150)
    status: Optional[str] = "Normal"
    notes: Optional[str] = None


@router.get("/utilities/kpis", summary="Campus Utilities Aggregated KPI Summary")
async def get_utilities_kpis(
    user: dict = Depends(get_current_user),
):
    return {
        "success": True,
        "data": {
            "grid_power_load": "245 kW",
            "grid_power_mtd": "45,210 kWh",
            "solar_generation": "84 kWp",
            "solar_today": "320.4 kWh",
            "solar_offset_pct": "42%",
            "dg_fuel_level": "78% (1,560 L)",
            "water_storage": "85% (85,000 L)",
            "ro_purity": "TDS: 68 ppm",
            "internet_uptime": "99.98% (1.0 Gbps)",
        }
    }


@router.get("/utilities/readings", summary="List Utility Meter Readings")
async def list_utility_readings(
    utility_type: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    user: dict = Depends(get_current_user),
):
    school_id = _get_school_id(user)
    try:
        search_term = f"%{search.strip().lower()}%" if search and search.strip() else None
        u_type = utility_type if (utility_type and utility_type != 'All') else None
        offset = (page - 1) * page_size

        sql = """
            SELECT 
                id, utility_name, utility_type, reading_value, metric_units,
                location, recorded_by, status, notes,
                TO_CHAR(recorded_at, 'DD Mon YYYY, HH12:MI AM') AS timestamp,
                recorded_at
            FROM public.campus_utility_readings
            WHERE school_id = %s::UUID AND deleted_at IS NULL
              AND (%s::VARCHAR IS NULL OR utility_type = %s::VARCHAR)
              AND (%s::VARCHAR IS NULL OR LOWER(utility_name) LIKE %s::VARCHAR OR LOWER(location) LIKE %s::VARCHAR)
            ORDER BY recorded_at DESC
            LIMIT %s OFFSET %s;
        """
        rows = await exec_sql(sql, (school_id, u_type, u_type, search_term, search_term, search_term, page_size, offset))

        count_sql = """
            SELECT COUNT(*) AS total
            FROM public.campus_utility_readings
            WHERE school_id = %s::UUID AND deleted_at IS NULL
              AND (%s::VARCHAR IS NULL OR utility_type = %s::VARCHAR)
              AND (%s::VARCHAR IS NULL OR LOWER(utility_name) LIKE %s::VARCHAR OR LOWER(location) LIKE %s::VARCHAR);
        """
        count_rows = await exec_sql(count_sql, (school_id, u_type, u_type, search_term, search_term, search_term))
        total_count = count_rows[0]["total"] if count_rows else 0

        return {
            "success": True,
            "data": _serialize_val(rows),
            "total_count": total_count,
            "page": page,
            "page_size": page_size,
            "total_pages": max(1, (total_count + page_size - 1) // page_size),
        }
    except Exception as e:
        logger.error(f"Error listing utility readings: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/utilities/readings", summary="Log a New Utility Reading")
async def log_utility_reading(
    payload: UtilityReadingCreateSchema,
    user: dict = Depends(get_current_user),
):
    school_id = _get_school_id(user)
    try:
        sql = """
            INSERT INTO public.campus_utility_readings (
                school_id, utility_name, utility_type, reading_value, metric_units,
                location, recorded_by, status, notes
            ) VALUES (
                %s::UUID, %s, %s, %s, %s, %s, %s, %s, %s
            ) RETURNING *, TO_CHAR(recorded_at, 'DD Mon YYYY, HH12:MI AM') AS timestamp;
        """
        params = (
            school_id, payload.utility_name, payload.utility_type, payload.reading_value,
            payload.metric_units or "kWh", payload.location, payload.recorded_by,
            payload.status or "Normal", payload.notes
        )
        rows = await exec_sql(sql, params)
        reading_data = _serialize_val(rows[0])

        # Automatically execute utility anomaly check and trigger ticket if > 1.5x baseline
        anomaly_result = None
        try:
            anom_row = await exec_sql(
                "SELECT public.sp_check_utility_anomalies(%s::UUID, %s::UUID) AS result;",
                (school_id, reading_data["id"]),
                fetch_one=True
            )
            if anom_row and anom_row.get("result"):
                anomaly_result = anom_row["result"]
        except Exception as anom_err:
            logger.warning(f"Could not execute automatic anomaly check: {anom_err}")

        return {
            "success": True,
            "data": reading_data,
            "anomaly_check": anomaly_result
        }
    except Exception as e:
        logger.error(f"Error logging utility reading: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/utilities/anomalies", summary="Check Utility Consumption Anomalies")
async def check_utility_anomalies(
    reading_id: Optional[str] = Query(None),
    user: dict = Depends(get_current_user),
):
    school_id = _get_school_id(user)
    sql = "SELECT public.sp_check_utility_anomalies(%s::UUID, %s::UUID) AS result;"
    r_id = reading_id if reading_id else None
    row = await exec_sql(sql, (school_id, r_id), fetch_one=True)
    if not row or not row.get("result"):
        return {"success": False, "message": "Failed to check utility anomalies"}
    return row.get("result")


# ============================================================================
# UNIFIED CAMPUS INSTITUTIONAL REPORTS
# ============================================================================

@router.get("/reports/export", summary="Export Campus Institutional Report as CSV")
async def export_campus_report(
    report_type: int = Query(0, description="0: Space, 1: Equipment, 2: Maintenance SLA, 3: Safety, 4: Energy"),
    building_id: Optional[str] = Query(None),
    time_range: Optional[str] = Query("Last 30 Days"),
    user: dict = Depends(get_current_user),
):
    school_id = _get_school_id(user)
    b_id = building_id if (building_id and building_id != "all") else None

    output = io.StringIO()
    writer = csv.writer(output)

    if report_type == 0:
        # Space & Room Utilization Audit
        sql = """
            SELECT 
                b.name AS building_name, r.name AS room_name, r.room_number, r.room_type,
                r.max_capacity, r.operational_status, r.is_bookable,
                COALESCE(COUNT(sb.id), 0) AS total_bookings
            FROM public.rooms r
            JOIN public.buildings b ON r.building_id = b.id
            LEFT JOIN public.space_bookings sb ON sb.room_id = r.id AND sb.deleted_at IS NULL
            WHERE r.school_id = %s::UUID AND r.deleted_at IS NULL
              AND (%s::UUID IS NULL OR r.building_id = %s::UUID)
            GROUP BY b.name, r.name, r.room_number, r.room_type, r.max_capacity, r.operational_status, r.is_bookable
            ORDER BY b.name, r.room_number;
        """
        rows = await exec_sql(sql, (school_id, b_id, b_id))
        writer.writerow(["Building", "Room Name", "Room Number", "Room Type", "Max Capacity", "Status", "Bookable", "Bookings Count"])
        for r in rows:
            writer.writerow([r["building_name"], r["room_name"], r["room_number"], r["room_type"], r["max_capacity"], r["operational_status"], r["is_bookable"], r["total_bookings"]])
        filename = f"space_utilization_report_{date.today().isoformat()}.csv"

    elif report_type == 1:
        # Asset & Equipment Health Audit
        sql = """
            SELECT 
                re.equipment_name, re.category, re.model_number, re.serial_number,
                re.condition, re.operational_status, r.name AS room_name, b.name AS building_name
            FROM public.room_equipment re
            JOIN public.rooms r ON re.room_id = r.id
            JOIN public.buildings b ON r.building_id = b.id
            WHERE re.school_id = %s::UUID AND re.deleted_at IS NULL
              AND (%s::UUID IS NULL OR r.building_id = %s::UUID)
            ORDER BY b.name, re.equipment_name;
        """
        rows = await exec_sql(sql, (school_id, b_id, b_id))
        writer.writerow(["Equipment Name", "Category", "Model", "Serial No", "Condition", "Status", "Room", "Building"])
        for r in rows:
            writer.writerow([r["equipment_name"], r["category"], r["model_number"], r["serial_number"], r["condition"], r["operational_status"], r["room_name"], r["building_name"]])
        filename = f"equipment_health_report_{date.today().isoformat()}.csv"

    elif report_type == 2:
        # Maintenance & SLA Performance Audit
        sql = """
            SELECT 
                mr.request_code, mr.title, mr.request_type, mr.priority, mr.status,
                mr.location_display, mr.reported_by_name, mr.assigned_to_name,
                mr.estimated_cost, mr.actual_cost, mr.created_at, mr.resolved_at
            FROM public.maintenance_requests mr
            WHERE mr.school_id = %s::UUID AND mr.deleted_at IS NULL
            ORDER BY mr.created_at DESC;
        """
        rows = await exec_sql(sql, (school_id,))
        writer.writerow(["Request Code", "Title", "Type", "Priority", "Status", "Location", "Reported By", "Assigned To", "Est Cost", "Actual Cost", "Created At", "Resolved At"])
        for r in rows:
            writer.writerow([r["request_code"], r["title"], r["request_type"], r["priority"], r["status"], r["location_display"], r["reported_by_name"], r["assigned_to_name"], r["estimated_cost"], r["actual_cost"], r["created_at"], r["resolved_at"]])
        filename = f"maintenance_sla_report_{date.today().isoformat()}.csv"

    elif report_type == 3:
        # Safety, Statutory NOCs & Drills Audit
        sql = """
            SELECT 
                si.inspection_code, si.title, si.category, si.overall_score, si.overall_status,
                si.inspector_name, si.inspection_date
            FROM public.safety_inspections si
            WHERE si.school_id = %s::UUID AND si.deleted_at IS NULL
            ORDER BY si.inspection_date DESC;
        """
        rows = await exec_sql(sql, (school_id,))
        writer.writerow(["Inspection Code", "Title", "Category", "Overall Score", "Status", "Inspector", "Date"])
        for r in rows:
            writer.writerow([r["inspection_code"], r["title"], r["category"], r["overall_score"], r["overall_status"], r["inspector_name"], r["inspection_date"]])
        filename = f"safety_compliance_report_{date.today().isoformat()}.csv"

    else:
        # Energy & Utility Footprint
        sql = """
            SELECT 
                utility_name, utility_type, reading_value, metric_units, location, recorded_by, status, recorded_at
            FROM public.campus_utility_readings
            WHERE school_id = %s::UUID AND deleted_at IS NULL
            ORDER BY recorded_at DESC;
        """
        rows = await exec_sql(sql, (school_id,))
        writer.writerow(["Utility Name", "Type", "Reading", "Units", "Location", "Recorded By", "Status", "Recorded At"])
        for r in rows:
            writer.writerow([r["utility_name"], r["utility_type"], r["reading_value"], r["metric_units"], r["location"], r["recorded_by"], r["status"], r["recorded_at"]])
        filename = f"energy_utility_footprint_{date.today().isoformat()}.csv"

    output.seek(0)
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )
