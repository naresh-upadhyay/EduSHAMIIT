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
async def update_building(
    building_id: str,
    payload: BuildingPayload,
    user: dict = Depends(get_current_user),
):
    """Update an existing building."""
    school_id = _get_school_id(user)
    user_id = _get_user_id(user)
    data = payload.model_dump()
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
    user: dict = Depends(get_current_user),
):
    """List floors belonging to a building, ordered by floor_level (basements first)."""
    school_id = _get_school_id(user)
    try:
        sql = "SELECT public.fn_campus_list_floors(%s::UUID, %s::UUID, %s, %s)"
        rows = await exec_sql(sql, (school_id, building_id, page, page_size))
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
    user: dict = Depends(get_current_user),
):
    """List rooms with advanced search, filters, equipment summary, and server pagination."""
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
