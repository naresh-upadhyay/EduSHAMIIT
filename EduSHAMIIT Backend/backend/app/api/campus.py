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
from datetime import datetime, date, time
from decimal import Decimal
import io
import csv
import json
import uuid
import os
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


# ----------------------------------------------------------------------------
# 11. Campus Image Upload & Serving
# ----------------------------------------------------------------------------
@router.post("/upload-image")
async def upload_campus_image(
    file: UploadFile = File(...),
    user: dict = Depends(get_current_user),
):
    """Upload an image file (building, room, floor) and return an accessible URL."""
    try:
        content = await file.read()
        if len(content) == 0:
            raise HTTPException(status_code=400, detail="Uploaded image is empty")
        if len(content) > 15 * 1024 * 1024:
            raise HTTPException(status_code=400, detail="Image size exceeds 15MB limit")

        content_type = file.content_type or "image/jpeg"
        if not content_type.startswith("image/"):
            raise HTTPException(status_code=400, detail="File must be an image (JPEG, PNG, WebP)")

        file_ext = os.path.splitext(file.filename or "")[1].lower()
        if not file_ext:
            file_ext = ".jpg" if "jpeg" in content_type else ".png"

        safe_name = f"{uuid.uuid4().hex[:12]}_{os.path.basename(file.filename or 'campus_image' + file_ext)}"

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
            logger.info(f"[Campus Image Upload] Supabase Storage upload fallback: {storage_err}")

        return {
            "success": True,
            "data": {
                "file_name": file.filename,
                "safe_name": safe_name,
                "file_url": file_url,
                "url": file_url,
                "file_size": len(content),
                "content_type": content_type
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Campus image upload failed: {e}")
        raise HTTPException(status_code=500, detail=f"Image upload failed: {str(e)}")


@router.get("/images/{file_name}")
async def get_campus_image(file_name: str):
    """Serve locally uploaded campus images with browser caching."""
    media_dirs = [
        os.path.abspath(os.path.join(os.getcwd(), "assets", "campus_images")),
        os.path.abspath(os.path.join(os.getcwd(), "assets", "uploads")),
        os.path.abspath(os.path.join(os.getcwd(), "assets")),
    ]
    target_path = None
    for d in media_dirs:
        candidate = os.path.abspath(os.path.join(d, file_name))
        if candidate.startswith(d) and os.path.exists(candidate) and os.path.isfile(candidate):
            target_path = candidate
            break

    if not target_path:
        raise HTTPException(status_code=404, detail="Image not found")

    ext = os.path.splitext(file_name)[1].lower()
    media_types = {
        ".png": "image/png",
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".webp": "image/webp",
        ".gif": "image/gif",
        ".svg": "image/svg+xml",
    }
    content_type = media_types.get(ext, "image/jpeg")
    return FileResponse(target_path, media_type=content_type)


# ----------------------------------------------------------------------------
# 12. Building Documents CRUD
# ----------------------------------------------------------------------------
@router.get("/buildings/{building_id}/documents")
async def list_building_documents(
    building_id: str,
    user: dict = Depends(get_current_user),
):
    """List all compliance, insurance, architectural, and safety documents for a building."""
    school_id = _get_school_id(user)
    try:
        sql = """
            SELECT id, school_id, building_id, room_id, document_name, document_type,
                   file_url, file_size_bytes, mime_type, issue_date, expiry_date,
                   issuing_authority, status, created_at
            FROM public.building_documents
            WHERE building_id = %s::UUID AND school_id = %s::UUID AND deleted_at IS NULL
            ORDER BY created_at DESC
        """
        rows = await exec_sql(sql, (building_id, school_id))
        return {
            "success": True,
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
# 13. Building Occupancy & Allocations CRUD
# ----------------------------------------------------------------------------
@router.get("/buildings/{building_id}/occupancy")
async def get_building_occupancy(
    building_id: str,
    user: dict = Depends(get_current_user),
):
    """Get building occupancy summary metrics and room allocations."""
    school_id = _get_school_id(user)
    try:
        stats_sql = """
            SELECT 
                COALESCE(SUM(r.max_capacity), 0)::INT AS total_capacity,
                COALESCE(SUM(r.current_occupancy), 0)::INT AS current_occupancy,
                COUNT(r.id)::INT AS total_rooms,
                COUNT(CASE WHEN r.assignment_status = 'Assigned' THEN 1 END)::INT AS occupied_rooms
            FROM public.rooms r
            WHERE r.building_id = %s::UUID AND r.school_id = %s::UUID AND r.deleted_at IS NULL
        """
        stats_rows = await exec_sql(stats_sql, (building_id, school_id))
        stats = stats_rows[0] if stats_rows else {"total_capacity": 0, "current_occupancy": 0, "total_rooms": 0, "occupied_rooms": 0}
        total_cap = stats["total_capacity"]
        curr_occ = stats["current_occupancy"]
        available_cap = max(0, total_cap - curr_occ)
        occ_rate = round((curr_occ / total_cap * 100.0), 1) if total_cap > 0 else 0.0

        alloc_sql = """
            SELECT ra.id, ra.room_id, r.room_number, r.name AS room_name, f.name AS floor_name,
                   ra.reference_module, ra.reference_name, ra.assignment_purpose,
                   ra.start_date, ra.end_date, ra.assigned_to_name, ra.status, ra.notes,
                   r.max_capacity, r.current_occupancy, ra.created_at
            FROM public.room_assignments ra
            JOIN public.rooms r ON ra.room_id = r.id
            JOIN public.building_floors f ON r.floor_id = f.id
            WHERE r.building_id = %s::UUID AND ra.school_id = %s::UUID AND ra.deleted_at IS NULL
            ORDER BY ra.created_at DESC
        """
        alloc_rows = await exec_sql(alloc_sql, (building_id, school_id))

        return {
            "success": True,
            "metrics": {
                "total_capacity": total_cap,
                "current_occupancy": curr_occ,
                "available_capacity": available_cap,
                "occupancy_rate": occ_rate,
                "total_rooms": stats["total_rooms"],
                "occupied_rooms": stats["occupied_rooms"],
            },
            "data": [_serialize_val(r) for r in alloc_rows]
        }
    except Exception as e:
        logger.error(f"Error fetching building occupancy: {e}")
        raise HTTPException(status_code=500, detail=f"Database query error: {str(e)}")


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
                %s, %s, %s::UUID
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
            payload.reference_module or "General", payload.reference_name, payload.assignment_purpose,
            payload.start_date, payload.end_date, payload.assigned_to_name, payload.status or "Active",
            payload.notes, assignment_id, school_id
        )
        rows = await exec_sql(sql, params)
        if not rows:
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
    user: dict = Depends(get_current_user),
):
    """List maintenance requests and work orders for a building."""
    school_id = _get_school_id(user)
    try:
        sql = """
            SELECT mr.id, mr.request_code, mr.title, mr.description, mr.request_type,
                   mr.priority, mr.status, mr.building_id, mr.floor_id, mr.room_id,
                   r.room_number, f.name AS floor_name, mr.reported_by_name, mr.assigned_to_name,
                   mr.scheduled_at, mr.preferred_date, mr.estimated_cost, mr.actual_cost,
                   mr.resolution_notes, mr.created_at
            FROM public.maintenance_requests mr
            LEFT JOIN public.rooms r ON mr.room_id = r.id
            LEFT JOIN public.building_floors f ON mr.floor_id = f.id
            WHERE (mr.building_id = %s::UUID OR r.building_id = %s::UUID)
              AND mr.school_id = %s::UUID AND mr.deleted_at IS NULL
            ORDER BY mr.created_at DESC
        """
        rows = await exec_sql(sql, (building_id, building_id, school_id))
        return {
            "success": True,
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
        sql = """
            INSERT INTO public.maintenance_requests (
                school_id, request_code, title, description, request_type,
                priority, status, building_id, floor_id, room_id,
                reported_by_name, reported_by_user_id, assigned_to_name,
                preferred_date, estimated_cost, actual_cost, resolution_notes,
                created_by, created_at, updated_at
            ) VALUES (
                %s::UUID, %s, %s, %s, %s,
                %s, %s, %s::UUID, NULLIF(%s, '')::UUID, NULLIF(%s, '')::UUID,
                %s, %s::UUID, %s,
                %s::DATE, %s, %s, %s,
                %s::UUID, NOW(), NOW()
            ) RETURNING *;
        """
        params = (
            school_id, req_code, payload.title, payload.description, payload.request_type or "Corrective",
            payload.priority or "Medium", payload.status or "Pending", building_id, payload.floor_id, payload.room_id,
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
            payload.floor_id, payload.room_id, payload.assigned_to_name,
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
