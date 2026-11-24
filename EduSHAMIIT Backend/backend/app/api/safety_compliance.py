"""
Production-Grade Safety, Security & Statutory Compliance API for EduSHAMIIT ERP.
Provides high-performance endpoints executing PostgreSQL stored procedures:
- Safety & Statutory Compliance KPIs (Compliance Index, Active Certificates, Open Incidents, Evacuation Readiness)
- Safety Inspections Master (Search, Category, Status, Pagination, Upsert, Soft Delete)
- Safety & Security Incidents (Severity, Type, Emergency Actions, First Aid, Investigations)
- Statutory Compliance Certificates (Fire NOC, Building Stability, Potable Water, Lift Fitness, Expiry alerts)
- Emergency Evacuation Drills (Mega fire drills, night hostel drills, HazMat, target evacuation timings)
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
    """Extract authenticated school_id with fallback to Greenwood High School demo ID."""
    if current_user and current_user.get("school_id"):
        return str(current_user["school_id"])
    return "11111111-1111-1111-1111-111111111111"


def get_user_id(current_user: Optional[Dict[str, Any]]) -> Optional[str]:
    """Extract authenticated user profile ID."""
    if current_user and current_user.get("id"):
        return str(current_user["id"])
    return None


def get_user_name(current_user: Optional[Dict[str, Any]]) -> str:
    """Extract authenticated user display name."""
    if current_user and current_user.get("full_name"):
        return str(current_user["full_name"])
    return "Admin"


# ============================================================================
# PYDANTIC SCHEMAS
# ============================================================================

class SafetyInspectionCreateUpdateSchema(BaseModel):
    id: Optional[str] = None
    title: str = Field(..., min_length=2, max_length=255)
    category: str = Field(default="Fire Safety")
    building_id: Optional[str] = None
    floor_id: Optional[str] = None
    room_id: Optional[str] = None
    location_display: str = Field(..., min_length=1, max_length=150)
    inspector_name: str = Field(default="Safety Officer")
    inspector_role: str = Field(default="Safety Officer")
    inspector_user_id: Optional[str] = None
    inspection_date: Optional[date] = None
    status: str = Field(default="Passed")
    compliance_score: Optional[float] = 95.0
    findings: Optional[str] = None
    action_items: Optional[List[Dict[str, Any]]] = []
    next_inspection_date: Optional[date] = None


class SafetyIncidentCreateUpdateSchema(BaseModel):
    id: Optional[str] = None
    title: str = Field(..., min_length=2, max_length=255)
    severity: str = Field(default="Medium")
    incident_type: str = Field(default="Slip, Trip & Fall")
    building_id: Optional[str] = None
    floor_id: Optional[str] = None
    room_id: Optional[str] = None
    location_display: str = Field(..., min_length=1, max_length=150)
    reported_by_name: Optional[str] = "Staff"
    reported_by_role: Optional[str] = "Staff"
    incident_time: Optional[datetime] = None
    status: str = Field(default="Reported")
    description: Optional[str] = None
    immediate_action_taken: Optional[str] = None
    preventive_measures: Optional[str] = None
    victims_count: Optional[int] = 0
    first_aid_provided: Optional[bool] = False
    resolved_by_name: Optional[str] = None


class ComplianceCertificateCreateUpdateSchema(BaseModel):
    id: Optional[str] = None
    title: str = Field(..., min_length=2, max_length=255)
    category: str = Field(default="Fire Safety")
    issuing_authority: str = Field(..., min_length=2, max_length=200)
    certificate_number: str = Field(..., min_length=1, max_length=100)
    building_id: Optional[str] = None
    location_display: Optional[str] = "All Campus Buildings"
    issue_date: date
    expiry_date: date
    status: Optional[str] = "Valid"
    document_url: Optional[str] = None
    notes: Optional[str] = None


class SafetyDrillCreateUpdateSchema(BaseModel):
    id: Optional[str] = None
    title: str = Field(..., min_length=2, max_length=255)
    drill_type: str = Field(default="Fire Evacuation")
    location_display: Optional[str] = "All Campus Blocks"
    scheduled_date: date
    conducted_date: Optional[date] = None
    status: Optional[str] = "Scheduled"
    participants_count: Optional[int] = 500
    evacuation_time_seconds: Optional[int] = 0
    target_time_seconds: Optional[int] = 180
    coordinator_name: Optional[str] = "Chief Safety Officer"
    performance_rating: Optional[str] = "Good"
    observations: Optional[str] = None


# ============================================================================
# 1. KPIS ENDPOINT
# ============================================================================

@router.get("/kpis", summary="Campus Safety & Compliance KPI Dashboard Metrics")
async def get_safety_kpis(
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    sql = "SELECT public.fn_safety_compliance_get_kpis(%s::UUID) AS kpis;"
    rows = await exec_sql(sql, (school_id,))
    kpis = rows[0]["kpis"] if rows else {}
    return {
        "success": True,
        "school_id": school_id,
        "data": _serialize_val(kpis)
    }


# ============================================================================
# 2. INSPECTIONS ENDPOINTS
# ============================================================================

@router.get("/inspections", summary="List Safety Inspections with Search & Filters")
async def list_safety_inspections(
    category: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    building_id: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    cat = category if (category and str(category).strip().lower() not in ("all", "none", "")) else None
    st = status if (status and str(status).strip().lower() not in ("all", "none", "")) else None
    b_id = building_id if (building_id and str(building_id).strip().lower() not in ("all", "none", "")) else None
    q = search.strip() if (search and search.strip()) else None

    sql = """
    SELECT total_count, records 
    FROM public.sp_list_safety_inspections(
        %s::UUID, %s, %s, %s::UUID, %s, %s, %s
    );
    """
    rows = await exec_sql(sql, (school_id, cat, st, b_id, q, page, page_size))
    total_count = rows[0]["total_count"] if rows else 0
    records = _serialize_val(rows[0]["records"] if rows else [])
    total_pages = (total_count + page_size - 1) // page_size if total_count > 0 else 1

    return {
        "total_count": total_count,
        "records": records,
        "page": page,
        "page_size": page_size,
        "total_pages": total_pages
    }


@router.post("/inspections", status_code=status.HTTP_201_CREATED, summary="Create Safety Inspection")
async def create_safety_inspection(
    payload: SafetyInspectionCreateUpdateSchema,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    data_dict = payload.dict()
    data_dict["school_id"] = school_id
    if not data_dict.get("inspector_user_id"):
        data_dict["inspector_user_id"] = get_user_id(current_user)

    sql = "SELECT public.sp_create_or_update_safety_inspection(%s::JSONB) AS result;"
    rows = await exec_sql(sql, (json.dumps(data_dict, default=str),))
    return rows[0]["result"] if rows else {"success": True}


@router.put("/inspections/{inspection_id}", summary="Update Safety Inspection")
async def update_safety_inspection(
    inspection_id: str,
    payload: SafetyInspectionCreateUpdateSchema,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    data_dict = payload.dict()
    data_dict["id"] = inspection_id
    data_dict["school_id"] = school_id

    sql = "SELECT public.sp_create_or_update_safety_inspection(%s::JSONB) AS result;"
    rows = await exec_sql(sql, (json.dumps(data_dict, default=str),))
    return rows[0]["result"] if rows else {"success": True}


@router.delete("/inspections/{inspection_id}", summary="Delete Safety Inspection")
async def delete_safety_inspection(
    inspection_id: str,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    sql = "SELECT public.sp_delete_safety_entity(%s::UUID, 'inspection', %s::UUID) AS result;"
    rows = await exec_sql(sql, (school_id, inspection_id))
    return rows[0]["result"] if rows else {"success": True}


# ============================================================================
# 3. INCIDENTS ENDPOINTS
# ============================================================================

@router.get("/incidents", summary="List Safety & Security Incidents")
async def list_safety_incidents(
    severity: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    sev = severity if (severity and str(severity).strip().lower() not in ("all", "none", "")) else None
    st = status if (status and str(status).strip().lower() not in ("all", "none", "")) else None
    q = search.strip() if (search and search.strip()) else None

    sql = """
    SELECT total_count, records 
    FROM public.sp_list_safety_incidents(
        %s::UUID, %s, %s, %s, %s, %s
    );
    """
    rows = await exec_sql(sql, (school_id, sev, st, q, page, page_size))
    total_count = rows[0]["total_count"] if rows else 0
    records = _serialize_val(rows[0]["records"] if rows else [])
    total_pages = (total_count + page_size - 1) // page_size if total_count > 0 else 1

    return {
        "total_count": total_count,
        "records": records,
        "page": page,
        "page_size": page_size,
        "total_pages": total_pages
    }


@router.post("/incidents", status_code=status.HTTP_201_CREATED, summary="Report Safety Incident")
async def report_safety_incident(
    payload: SafetyIncidentCreateUpdateSchema,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    data_dict = payload.dict()
    data_dict["school_id"] = school_id
    data_dict["reported_by_user_id"] = get_user_id(current_user)
    if not data_dict.get("reported_by_name") or data_dict["reported_by_name"] == "Staff":
        data_dict["reported_by_name"] = get_user_name(current_user)

    sql = "SELECT public.sp_create_or_update_safety_incident(%s::JSONB) AS result;"
    rows = await exec_sql(sql, (json.dumps(data_dict, default=str),))
    return rows[0]["result"] if rows else {"success": True}


@router.put("/incidents/{incident_id}", summary="Update Safety Incident")
async def update_safety_incident(
    incident_id: str,
    payload: SafetyIncidentCreateUpdateSchema,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    data_dict = payload.dict()
    data_dict["id"] = incident_id
    data_dict["school_id"] = school_id

    sql = "SELECT public.sp_create_or_update_safety_incident(%s::JSONB) AS result;"
    rows = await exec_sql(sql, (json.dumps(data_dict, default=str),))
    return rows[0]["result"] if rows else {"success": True}


@router.delete("/incidents/{incident_id}", summary="Delete Safety Incident")
async def delete_safety_incident(
    incident_id: str,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    sql = "SELECT public.sp_delete_safety_entity(%s::UUID, 'incident', %s::UUID) AS result;"
    rows = await exec_sql(sql, (school_id, incident_id))
    return rows[0]["result"] if rows else {"success": True}


@router.post("/incidents/{incident_id}/trigger-emergency-override", summary="Trigger Life Safety IoT Emergency Override for Incident")
async def trigger_emergency_safety_interlock(
    incident_id: str,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    user_name = get_user_name(current_user)
    sql = "SELECT public.sp_trigger_emergency_safety_interlock(%s::UUID, %s::UUID, %s) AS result;"
    row = await exec_sql(sql, (school_id, incident_id, user_name), fetch_one=True)
    if not row or not row.get("result"):
        raise HTTPException(status_code=500, detail="Failed to trigger emergency safety interlock")
    return row.get("result")


# ============================================================================
# 4. STATUTORY CERTIFICATES ENDPOINTS
# ============================================================================

@router.get("/certificates", summary="List Statutory Compliance Certificates")
async def list_compliance_certificates(
    category: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    cat = category if (category and str(category).strip().lower() not in ("all", "none", "")) else None
    st = status if (status and str(status).strip().lower() not in ("all", "none", "")) else None
    q = search.strip() if (search and search.strip()) else None

    sql = """
    SELECT total_count, records 
    FROM public.sp_list_compliance_certificates(
        %s::UUID, %s, %s, %s, %s, %s
    );
    """
    rows = await exec_sql(sql, (school_id, cat, st, q, page, page_size))
    total_count = rows[0]["total_count"] if rows else 0
    records = _serialize_val(rows[0]["records"] if rows else [])
    total_pages = (total_count + page_size - 1) // page_size if total_count > 0 else 1

    return {
        "total_count": total_count,
        "records": records,
        "page": page,
        "page_size": page_size,
        "total_pages": total_pages
    }


@router.post("/certificates", status_code=status.HTTP_201_CREATED, summary="Create Compliance Certificate")
async def create_compliance_certificate(
    payload: ComplianceCertificateCreateUpdateSchema,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    data_dict = payload.dict()
    data_dict["school_id"] = school_id

    sql = "SELECT public.sp_create_or_update_compliance_certificate(%s::JSONB) AS result;"
    rows = await exec_sql(sql, (json.dumps(data_dict, default=str),))
    return rows[0]["result"] if rows else {"success": True}


@router.put("/certificates/{certificate_id}", summary="Update Compliance Certificate")
async def update_compliance_certificate(
    certificate_id: str,
    payload: ComplianceCertificateCreateUpdateSchema,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    data_dict = payload.dict()
    data_dict["id"] = certificate_id
    data_dict["school_id"] = school_id

    sql = "SELECT public.sp_create_or_update_compliance_certificate(%s::JSONB) AS result;"
    rows = await exec_sql(sql, (json.dumps(data_dict, default=str),))
    return rows[0]["result"] if rows else {"success": True}


@router.delete("/certificates/{certificate_id}", summary="Delete Compliance Certificate")
async def delete_compliance_certificate(
    certificate_id: str,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    sql = "SELECT public.sp_delete_safety_entity(%s::UUID, 'certificate', %s::UUID) AS result;"
    rows = await exec_sql(sql, (school_id, certificate_id))
    return rows[0]["result"] if rows else {"success": True}


# ============================================================================
# 5. EMERGENCY DRILLS ENDPOINTS
# ============================================================================

@router.get("/drills", summary="List Emergency Evacuation & Safety Drills")
async def list_safety_drills(
    status: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    st = status if (status and str(status).strip().lower() not in ("all", "none", "")) else None

    sql = """
    SELECT total_count, records 
    FROM public.sp_list_safety_drills(
        %s::UUID, %s, %s, %s
    );
    """
    rows = await exec_sql(sql, (school_id, st, page, page_size))
    total_count = rows[0]["total_count"] if rows else 0
    records = _serialize_val(rows[0]["records"] if rows else [])
    total_pages = (total_count + page_size - 1) // page_size if total_count > 0 else 1

    return {
        "total_count": total_count,
        "records": records,
        "page": page,
        "page_size": page_size,
        "total_pages": total_pages
    }


@router.post("/drills", status_code=status.HTTP_201_CREATED, summary="Schedule or Log Safety Drill")
async def create_safety_drill(
    payload: SafetyDrillCreateUpdateSchema,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    data_dict = payload.dict()
    data_dict["school_id"] = school_id

    sql = "SELECT public.sp_create_or_update_safety_drill(%s::JSONB) AS result;"
    rows = await exec_sql(sql, (json.dumps(data_dict, default=str),))
    return rows[0]["result"] if rows else {"success": True}


@router.put("/drills/{drill_id}", summary="Update Safety Drill")
async def update_safety_drill(
    drill_id: str,
    payload: SafetyDrillCreateUpdateSchema,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    data_dict = payload.dict()
    data_dict["id"] = drill_id
    data_dict["school_id"] = school_id

    sql = "SELECT public.sp_create_or_update_safety_drill(%s::JSONB) AS result;"
    rows = await exec_sql(sql, (json.dumps(data_dict, default=str),))
    return rows[0]["result"] if rows else {"success": True}


@router.delete("/drills/{drill_id}", summary="Delete Safety Drill")
async def delete_safety_drill(
    drill_id: str,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    sql = "SELECT public.sp_delete_safety_entity(%s::UUID, 'drill', %s::UUID) AS result;"
    rows = await exec_sql(sql, (school_id, drill_id))
    return rows[0]["result"] if rows else {"success": True}


# ============================================================================
# 6. STREAMING CSV EXPORT
# ============================================================================

@router.get("/export", summary="Export Safety & Compliance Data as CSV")
async def export_safety_data(
    export_type: str = Query("inspections", description="inspections, incidents, certificates, drills"),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    school_id = get_school_id(current_user)
    output = io.StringIO()
    writer = csv.writer(output)

    if export_type == "certificates":
        sql = "SELECT certificate_code, title, category, issuing_authority, certificate_number, issue_date, expiry_date, status FROM public.compliance_certificates WHERE school_id = %s::UUID AND deleted_at IS NULL ORDER BY expiry_date ASC;"
        rows = await exec_sql(sql, (school_id,))
        writer.writerow(["Code", "Title", "Category", "Issuing Authority", "Certificate Number", "Issue Date", "Expiry Date", "Status"])
        for r in rows:
            writer.writerow([r.get("certificate_code"), r.get("title"), r.get("category"), r.get("issuing_authority"), r.get("certificate_number"), str(r.get("issue_date")), str(r.get("expiry_date")), r.get("status")])
        filename = f"safety_certificates_{date.today().isoformat()}.csv"
    elif export_type == "incidents":
        sql = "SELECT incident_code, title, severity, incident_type, location_display, reported_by_name, incident_time, status, first_aid_provided FROM public.safety_incidents WHERE school_id = %s::UUID AND deleted_at IS NULL ORDER BY incident_time DESC;"
        rows = await exec_sql(sql, (school_id,))
        writer.writerow(["Code", "Title", "Severity", "Type", "Location", "Reported By", "Incident Time", "Status", "First Aid"])
        for r in rows:
            writer.writerow([r.get("incident_code"), r.get("title"), r.get("severity"), r.get("incident_type"), r.get("location_display"), r.get("reported_by_name"), str(r.get("incident_time")), r.get("status"), r.get("first_aid_provided")])
        filename = f"safety_incidents_{date.today().isoformat()}.csv"
    else:
        sql = "SELECT inspection_code, title, category, location_display, inspector_name, inspection_date, status, compliance_score FROM public.safety_inspections WHERE school_id = %s::UUID AND deleted_at IS NULL ORDER BY inspection_date DESC;"
        rows = await exec_sql(sql, (school_id,))
        writer.writerow(["Code", "Title", "Category", "Location", "Inspector", "Date", "Status", "Score (%)"])
        for r in rows:
            writer.writerow([r.get("inspection_code"), r.get("title"), r.get("category"), r.get("location_display"), r.get("inspector_name"), str(r.get("inspection_date")), r.get("status"), r.get("compliance_score")])
        filename = f"safety_inspections_{date.today().isoformat()}.csv"

    output.seek(0)
    return StreamingResponse(
        output,
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )
