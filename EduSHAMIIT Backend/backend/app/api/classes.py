"""
Academic Class, Section & Subject Management API for EduSHAMIIT ERP.
Provides full REST operations, multi-tenant scoping, contextual student/teacher assignments,
and academic year isolation.
"""
from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any, Union
from datetime import datetime, date, time
import json
import uuid
import logging
import asyncio
import psycopg2
from psycopg2.extras import RealDictCursor

from app.config import settings
from app.middleware.auth import get_current_user, require_school_id

logger = logging.getLogger(__name__)
router = APIRouter()


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
    """Recursively serialize datetime and UUID objects for JSON responses."""
    if isinstance(val, (datetime, date, time)):
        return val.isoformat()
    if isinstance(val, uuid.UUID):
        return str(val)
    if isinstance(val, dict):
        return {k: _serialize_val(v) for k, v in val.items()}
    if isinstance(val, list):
        return [_serialize_val(item) for item in val]
    return val


# ============================================================================
# PYDANTIC SCHEMAS
# ============================================================================

class InlineSectionCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=50)
    code: Optional[str] = Field(None, max_length=50)
    capacity: Optional[int] = Field(40, ge=1, le=500)
    status: Optional[str] = Field("ACTIVE")


class ClassCreateRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    code: Optional[str] = Field(None, max_length=50)
    stage: Optional[str] = Field("Secondary")
    academic_year: Optional[str] = Field("2026-27")
    display_order: Optional[int] = Field(1)
    status: Optional[str] = Field("ACTIVE")
    sections: Optional[List[InlineSectionCreate]] = Field(default_factory=list)


class ClassUpdateRequest(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    code: Optional[str] = Field(None, max_length=50)
    stage: Optional[str] = Field(None)
    academic_year: Optional[str] = Field(None)
    display_order: Optional[int] = Field(None)
    status: Optional[str] = Field(None)


class SectionCreateRequest(BaseModel):
    class_id: uuid.UUID
    name: str = Field(..., min_length=1, max_length=50)
    code: Optional[str] = Field(None, max_length=50)
    capacity: Optional[int] = Field(40, ge=1, le=500)
    room_number: Optional[str] = Field(None, max_length=50)
    academic_year: Optional[str] = Field("2026-27")
    status: Optional[str] = Field("ACTIVE")


class SectionUpdateRequest(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=50)
    code: Optional[str] = Field(None, max_length=50)
    capacity: Optional[int] = Field(None, ge=1, le=500)
    room_number: Optional[str] = Field(None, max_length=50)
    status: Optional[str] = Field(None)


class SubjectCreateRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=150)
    code: Optional[str] = Field(None, max_length=50)
    type: Optional[str] = Field("Core")
    description: Optional[str] = Field(None)
    periods_per_week: Optional[int] = Field(5, ge=1, le=50)
    color: Optional[str] = Field("#4F46E5")
    icon: Optional[str] = Field("book")
    status: Optional[str] = Field("ACTIVE")
    class_ids: Optional[List[uuid.UUID]] = Field(default_factory=list)


class SubjectUpdateRequest(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=150)
    code: Optional[str] = Field(None, max_length=50)
    type: Optional[str] = Field(None)
    description: Optional[str] = Field(None)
    periods_per_week: Optional[int] = Field(None, ge=1, le=50)
    color: Optional[str] = Field(None)
    icon: Optional[str] = Field(None)
    status: Optional[str] = Field(None)
    class_ids: Optional[List[uuid.UUID]] = Field(None)


class AssignTeachersRequest(BaseModel):
    teacher_ids: List[uuid.UUID] = Field(default_factory=list)
    academic_year: Optional[str] = Field("2026-27")


class AssignStudentsRequest(BaseModel):
    student_ids: List[uuid.UUID] = Field(default_factory=list)
    academic_year: Optional[str] = Field("2026-27")
    confirm_move: Optional[bool] = Field(False)


class ManageSubjectsRequest(BaseModel):
    subject_ids: List[uuid.UUID] = Field(default_factory=list)
    academic_year: Optional[str] = Field("2026-27")


class CheckStudentMovesRequest(BaseModel):
    student_ids: List[uuid.UUID] = Field(default_factory=list)
    academic_year: Optional[str] = Field("2026-27")
    target_class_id: Optional[uuid.UUID] = Field(None)
    target_section_id: Optional[uuid.UUID] = Field(None)


# ============================================================================
# ROLE & SCOPING HELPERS
# ============================================================================

def _resolve_teacher_id_scope(current_user: dict, explicit_teacher_id: Optional[str] = None) -> Optional[str]:
    """If user is a teacher, force scoping to their user/profile ID. For admins, allow optional filtering."""
    role = str(current_user.get("role", "")).lower()
    if role in ("teacher", "faculty", "instructor"):
        return current_user.get("id")
    return explicit_teacher_id


def _require_admin_or_staff(current_user: dict):
    """Enforce that only administrators/staff can modify academic structures."""
    role = str(current_user.get("role", "")).lower()
    if role in ("teacher", "faculty", "instructor", "student", "parent"):
        raise HTTPException(
            status_code=403,
            detail="Forbidden: Only administrators can modify academic structures."
        )


# ============================================================================
# STATS & OVERVIEW ENDPOINTS
# ============================================================================

@router.get("/stats")
async def get_academic_stats(
    academic_year: str = Query("2026-27"),
    teacher_id: Optional[uuid.UUID] = Query(None, description="Optional teacher filter (enforced automatically for teacher role)"),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Retrieve high-level statistics for Class Management."""
    scoped_teacher_id = _resolve_teacher_id_scope(current_user, str(teacher_id) if teacher_id else None)
    rows = await exec_sql(
        "SELECT public.fn_get_academic_stats(%s::UUID, %s, %s::UUID) AS result;",
        (school_id, academic_year, scoped_teacher_id)
    )
    if not rows or not rows[0].get("result"):
        return {"success": True, "data": {"total_classes": 0, "active_classes": 0, "total_sections": 0, "total_subjects": 0}}
    
    return _serialize_val(rows[0]["result"])


# ============================================================================
# CLASSES ENDPOINTS
# ============================================================================

@router.get("")
async def get_classes(
    search: str = Query("", description="Search by class name, code, or stage"),
    academic_year: str = Query("2026-27"),
    status: str = Query("ALL", description="ALL, ACTIVE, INACTIVE, ARCHIVED"),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    sort_by: str = Query("display_order"),
    sort_order: str = Query("ASC"),
    teacher_id: Optional[uuid.UUID] = Query(None, description="Optional teacher filter (enforced automatically for teacher role)"),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Get paginated list of classes with section/student/subject counts and primary teachers."""
    scoped_teacher_id = _resolve_teacher_id_scope(current_user, str(teacher_id) if teacher_id else None)
    rows = await exec_sql(
        "SELECT public.fn_get_academic_classes(%s::UUID, %s, %s, %s, %s, %s, %s, %s, %s::UUID) AS result;",
        (school_id, search, academic_year, status, page, page_size, sort_by, sort_order, scoped_teacher_id)
    )
    if not rows or not rows[0].get("result"):
        return {"success": True, "data": {"classes": [], "total_count": 0, "page": page, "page_size": page_size}}
    
    return _serialize_val(rows[0]["result"])


@router.post("")
async def create_class(
    payload: ClassCreateRequest,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Create an academic class with optional inline sections in an atomic transaction."""
    _require_admin_or_staff(current_user)
    user_id = current_user.get("id")
    payload_json = json.dumps(payload.dict())
    
    rows = await exec_sql(
        "SELECT public.fn_create_academic_class(%s::UUID, %s::UUID, %s::JSONB) AS result;",
        (school_id, user_id, payload_json)
    )
    res = rows[0]["result"] if rows else {"success": False, "error": "Internal server error"}
    if not res.get("success"):
        raise HTTPException(status_code=res.get("code", 400), detail=res.get("error", "Failed to create class"))
    
    return _serialize_val(res)


@router.get("/{class_id}")
async def get_class_detail(
    class_id: uuid.UUID,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Get complete details of a specific class including its sections, subjects, and teachers."""
    scoped_teacher_id = _resolve_teacher_id_scope(current_user)
    rows = await exec_sql(
        "SELECT public.fn_get_academic_class_detail(%s::UUID, %s::UUID, %s::UUID) AS result;",
        (school_id, str(class_id), scoped_teacher_id)
    )
    res = rows[0]["result"] if rows else {"success": False, "error": "Class not found"}
    if not res.get("success"):
        raise HTTPException(status_code=res.get("code", 404), detail=res.get("error", "Class not found"))
    
    return _serialize_val(res)


@router.patch("/{class_id}")
@router.put("/{class_id}")
async def update_class(
    class_id: uuid.UUID,
    payload: ClassUpdateRequest,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Update class attributes (name, code, stage, display_order, status)."""
    _require_admin_or_staff(current_user)
    user_id = current_user.get("id")
    payload_json = json.dumps({k: v for k, v in payload.dict().items() if v is not None})
    
    rows = await exec_sql(
        "SELECT public.fn_update_academic_class(%s::UUID, %s::UUID, %s::UUID, %s::JSONB) AS result;",
        (school_id, user_id, str(class_id), payload_json)
    )
    res = rows[0]["result"] if rows else {"success": False, "error": "Class not found"}
    if not res.get("success"):
        raise HTTPException(status_code=res.get("code", 400), detail=res.get("error", "Failed to update class"))
    
    return _serialize_val(res)


@router.delete("/{class_id}")
@router.patch("/{class_id}/archive")
async def archive_class(
    class_id: uuid.UUID,
    force: bool = Query(False, description="Force archive even if sections/students exist"),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Archive a class and its sections. If dependencies exist and force=False, returns 400 with impact counts."""
    _require_admin_or_staff(current_user)
    user_id = current_user.get("id")
    rows = await exec_sql(
        "SELECT public.fn_archive_academic_class(%s::UUID, %s::UUID, %s::UUID, %s) AS result;",
        (school_id, user_id, str(class_id), force)
    )
    res = rows[0]["result"] if rows else {"success": False, "error": "Class not found"}
    if not res.get("success"):
        raise HTTPException(status_code=res.get("code", 400), detail=res)
    
    return _serialize_val(res)


@router.post("/{class_id}/restore")
@router.patch("/{class_id}/restore")
async def restore_class(
    class_id: uuid.UUID,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Restore an archived class and its sections."""
    _require_admin_or_staff(current_user)
    user_id = current_user.get("id")
    rows = await exec_sql(
        "SELECT public.fn_restore_academic_class(%s::UUID, %s::UUID, %s::UUID) AS result;",
        (school_id, user_id, str(class_id))
    )
    res = rows[0]["result"] if rows else {"success": False, "error": "Class not found"}
    if not res.get("success"):
        raise HTTPException(status_code=res.get("code", 400), detail=res.get("error", "Failed to restore class"))
    
    return _serialize_val(res)


# ============================================================================
# SECTIONS ENDPOINTS
# ============================================================================

@router.get("/sections/all")
async def get_sections(
    search: str = Query("", description="Search section name, code, or class name"),
    class_id: Optional[uuid.UUID] = Query(None),
    academic_year: str = Query("2026-27"),
    status: str = Query("ALL"),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    sort_by: str = Query("class_name"),
    sort_order: str = Query("ASC"),
    teacher_id: Optional[uuid.UUID] = Query(None, description="Optional teacher filter (enforced automatically for teacher role)"),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Get paginated sections across all classes."""
    class_id_str = str(class_id) if class_id else None
    scoped_teacher_id = _resolve_teacher_id_scope(current_user, str(teacher_id) if teacher_id else None)
    rows = await exec_sql(
        "SELECT public.fn_get_academic_sections(%s::UUID, %s, %s::UUID, %s, %s, %s, %s, %s, %s, %s::UUID) AS result;",
        (school_id, search, class_id_str, academic_year, status, page, page_size, sort_by, sort_order, scoped_teacher_id)
    )
    if not rows or not rows[0].get("result"):
        return {"success": True, "data": {"sections": [], "total_count": 0, "page": page, "page_size": page_size}}
    
    return _serialize_val(rows[0]["result"])


@router.post("/sections")
async def create_section(
    payload: SectionCreateRequest,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Create a standalone section under an existing class."""
    _require_admin_or_staff(current_user)
    user_id = current_user.get("id")
    payload_json = json.dumps({
        "class_id": str(payload.class_id),
        "name": payload.name,
        "code": payload.code,
        "capacity": payload.capacity,
        "room_number": payload.room_number,
        "academic_year": payload.academic_year,
        "status": payload.status
    })
    rows = await exec_sql(
        "SELECT public.fn_create_academic_section(%s::UUID, %s::UUID, %s::JSONB) AS result;",
        (school_id, user_id, payload_json)
    )
    res = rows[0]["result"] if rows else {"success": False, "error": "Internal server error"}
    if not res.get("success"):
        raise HTTPException(status_code=res.get("code", 400), detail=res.get("error", "Failed to create section"))
    
    return _serialize_val(res)


@router.patch("/sections/{section_id}")
@router.put("/sections/{section_id}")
async def update_section(
    section_id: uuid.UUID,
    payload: SectionUpdateRequest,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Update section details."""
    _require_admin_or_staff(current_user)
    user_id = current_user.get("id")
    payload_json = json.dumps({k: v for k, v in payload.dict().items() if v is not None})
    
    rows = await exec_sql(
        "SELECT public.fn_update_academic_section(%s::UUID, %s::UUID, %s::UUID, %s::JSONB) AS result;",
        (school_id, user_id, str(section_id), payload_json)
    )
    res = rows[0]["result"] if rows else {"success": False, "error": "Section not found"}
    if not res.get("success"):
        raise HTTPException(status_code=res.get("code", 400), detail=res.get("error", "Failed to update section"))
    
    return _serialize_val(res)


@router.delete("/sections/{section_id}")
@router.patch("/sections/{section_id}/archive")
async def archive_section(
    section_id: uuid.UUID,
    force: bool = Query(False),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Archive an academic section."""
    _require_admin_or_staff(current_user)
    user_id = current_user.get("id")
    rows = await exec_sql(
        "SELECT public.fn_archive_academic_section(%s::UUID, %s::UUID, %s::UUID, %s) AS result;",
        (school_id, user_id, str(section_id), force)
    )
    res = rows[0]["result"] if rows else {"success": False, "error": "Section not found"}
    if not res.get("success"):
        raise HTTPException(status_code=res.get("code", 400), detail=res)
    
    return _serialize_val(res)


@router.post("/sections/{section_id}/restore")
@router.patch("/sections/{section_id}/restore")
async def restore_section(
    section_id: uuid.UUID,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Restore an archived section."""
    _require_admin_or_staff(current_user)
    user_id = current_user.get("id")
    rows = await exec_sql(
        "SELECT public.fn_restore_academic_section(%s::UUID, %s::UUID, %s::UUID) AS result;",
        (school_id, user_id, str(section_id))
    )
    res = rows[0]["result"] if rows else {"success": False, "error": "Section not found"}
    if not res.get("success"):
        raise HTTPException(status_code=res.get("code", 400), detail=res.get("error", "Failed to restore section"))
    
    return _serialize_val(res)


# ============================================================================
# SUBJECTS ENDPOINTS
# ============================================================================

@router.get("/subjects/all")
async def get_subjects(
    search: str = Query("", description="Search by subject name, code, or type"),
    type: str = Query("ALL", description="ALL, Core, Elective, Language, Practical, Activity, Other"),
    status: str = Query("ALL"),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    sort_by: str = Query("name"),
    sort_order: str = Query("ASC"),
    teacher_id: Optional[uuid.UUID] = Query(None, description="Optional teacher filter (enforced automatically for teacher role)"),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Get paginated list of subjects in catalog."""
    scoped_teacher_id = _resolve_teacher_id_scope(current_user, str(teacher_id) if teacher_id else None)
    rows = await exec_sql(
        "SELECT public.fn_get_academic_subjects(%s::UUID, %s, %s, %s, %s, %s, %s, %s, %s::UUID) AS result;",
        (school_id, search, type, status, page, page_size, sort_by, sort_order, scoped_teacher_id)
    )
    if not rows or not rows[0].get("result"):
        return {"success": True, "data": {"subjects": [], "total_count": 0, "page": page, "page_size": page_size}}
    
    return _serialize_val(rows[0]["result"])


@router.post("/subjects")
async def create_subject(
    payload: SubjectCreateRequest,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Create a new subject in the catalog with optional class assignments."""
    _require_admin_or_staff(current_user)
    user_id = current_user.get("id")
    payload_dict = payload.dict()
    payload_dict["class_ids"] = [str(cid) for cid in payload.class_ids or []]
    payload_json = json.dumps(payload_dict)
    
    rows = await exec_sql(
        "SELECT public.fn_create_academic_subject(%s::UUID, %s::UUID, %s::JSONB) AS result;",
        (school_id, user_id, payload_json)
    )
    res = rows[0]["result"] if rows else {"success": False, "error": "Internal server error"}
    if not res.get("success"):
        raise HTTPException(status_code=res.get("code", 400), detail=res.get("error", "Failed to create subject"))
    
    return _serialize_val(res)


@router.patch("/subjects/{subject_id}")
@router.put("/subjects/{subject_id}")
async def update_subject(
    subject_id: uuid.UUID,
    payload: SubjectUpdateRequest,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Update subject in catalog."""
    _require_admin_or_staff(current_user)
    user_id = current_user.get("id")
    p_dict = {k: v for k, v in payload.dict(exclude_unset=True).items() if v is not None}
    if "class_ids" in p_dict and p_dict["class_ids"] is not None:
        p_dict["class_ids"] = [str(c) for c in p_dict["class_ids"]]
    payload_json = json.dumps(p_dict)
    
    rows = await exec_sql(
        "SELECT public.fn_update_academic_subject(%s::UUID, %s::UUID, %s::UUID, %s::JSONB) AS result;",
        (school_id, user_id, str(subject_id), payload_json)
    )
    res = rows[0]["result"] if rows else {"success": False, "error": "Subject not found"}
    if not res.get("success"):
        raise HTTPException(status_code=res.get("code", 400), detail=res.get("error", "Failed to update subject"))
    
    return _serialize_val(res)


@router.delete("/subjects/{subject_id}")
@router.patch("/subjects/{subject_id}/archive")
async def archive_subject(
    subject_id: uuid.UUID,
    force: bool = Query(False),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Archive a subject from catalog."""
    _require_admin_or_staff(current_user)
    user_id = current_user.get("id")
    rows = await exec_sql(
        "SELECT public.fn_archive_academic_subject(%s::UUID, %s::UUID, %s::UUID, %s) AS result;",
        (school_id, user_id, str(subject_id), force)
    )
    res = rows[0]["result"] if rows else {"success": False, "error": "Subject not found"}
    if not res.get("success"):
        raise HTTPException(status_code=res.get("code", 400), detail=res)
    
    return _serialize_val(res)


@router.post("/subjects/{subject_id}/restore")
@router.patch("/subjects/{subject_id}/restore")
async def restore_subject(
    subject_id: uuid.UUID,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Restore an archived subject."""
    _require_admin_or_staff(current_user)
    user_id = current_user.get("id")
    rows = await exec_sql(
        "SELECT public.fn_restore_academic_subject(%s::UUID, %s::UUID, %s::UUID) AS result;",
        (school_id, user_id, str(subject_id))
    )
    res = rows[0]["result"] if rows else {"success": False, "error": "Subject not found"}
    if not res.get("success"):
        raise HTTPException(status_code=res.get("code", 400), detail=res.get("error", "Failed to restore subject"))
    
    return _serialize_val(res)


# ============================================================================
# CONTEXTUAL ASSIGNMENT ENDPOINTS
# ============================================================================

@router.post("/{class_id}/teachers")
async def assign_class_teachers(
    class_id: uuid.UUID,
    payload: AssignTeachersRequest,
    section_id: Optional[uuid.UUID] = Query(None, description="Optional section ID; if omitted, assigns to class directly"),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Assign class teachers directly to Class or Section."""
    _require_admin_or_staff(current_user)
    user_id = current_user.get("id")
    teacher_ids_arr = [str(tid) for tid in payload.teacher_ids]
    section_id_str = str(section_id) if section_id else None
    
    rows = await exec_sql(
        "SELECT public.fn_assign_class_teachers(%s::UUID, %s::UUID, %s::UUID, %s::UUID, %s::UUID[], %s) AS result;",
        (school_id, user_id, str(class_id), section_id_str, teacher_ids_arr, payload.academic_year)
    )
    res = rows[0]["result"] if rows else {"success": False, "error": "Failed to assign teachers"}
    if not res.get("success"):
        raise HTTPException(status_code=res.get("code", 400), detail=res.get("error", "Failed to assign teachers"))
    
    return _serialize_val(res)


@router.post("/{class_id}/students")
async def assign_class_students(
    class_id: uuid.UUID,
    payload: AssignStudentsRequest,
    section_id: Optional[uuid.UUID] = Query(None, description="Optional section ID; if omitted, assigns directly to class (no-section mode)"),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Assign students to Class or Section with safe move validation."""
    _require_admin_or_staff(current_user)
    user_id = current_user.get("id")
    student_ids_arr = [str(sid) for sid in payload.student_ids]
    section_id_str = str(section_id) if section_id else None
    
    rows = await exec_sql(
        "SELECT public.fn_assign_class_students(%s::UUID, %s::UUID, %s::UUID, %s::UUID, %s::UUID[], %s, %s) AS result;",
        (school_id, user_id, str(class_id), section_id_str, student_ids_arr, payload.academic_year, payload.confirm_move)
    )
    res = rows[0]["result"] if rows else {"success": False, "error": "Failed to assign students"}
    if not res.get("success"):
        raise HTTPException(status_code=res.get("code", 400), detail=res)
    
    return _serialize_val(res)


@router.post("/{class_id}/subjects")
async def manage_class_subjects(
    class_id: uuid.UUID,
    payload: ManageSubjectsRequest,
    section_id: Optional[uuid.UUID] = Query(None, description="Optional section ID for section-specific subjects"),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Assign/manage subjects assigned to a class or section."""
    _require_admin_or_staff(current_user)
    user_id = current_user.get("id")
    subject_ids_arr = [str(sid) for sid in payload.subject_ids]
    section_id_str = str(section_id) if section_id else None
    
    rows = await exec_sql(
        "SELECT public.fn_manage_class_subjects(%s::UUID, %s::UUID, %s::UUID, %s::UUID, %s::UUID[], %s) AS result;",
        (school_id, user_id, str(class_id), section_id_str, subject_ids_arr, payload.academic_year)
    )
    res = rows[0]["result"] if rows else {"success": False, "error": "Failed to assign subjects"}
    if not res.get("success"):
        raise HTTPException(status_code=res.get("code", 400), detail=res.get("error", "Failed to assign subjects"))
    
    return _serialize_val(res)


# ============================================================================
# USER MANAGEMENT PICKER & CONFLICT DETECTION
# ============================================================================

@router.get("/users/teachers")
async def search_academic_teachers(
    search: str = Query("", description="Search by name, employee ID, email, or department"),
    limit: int = Query(20, ge=1, le=100),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Search teachers from User Management / profiles."""
    rows = await exec_sql(
        "SELECT public.fn_search_academic_teachers(%s::UUID, %s, %s) AS result;",
        (school_id, search, limit)
    )
    if not rows or not rows[0].get("result"):
        return {"success": True, "data": []}
    
    return _serialize_val(rows[0]["result"])


@router.get("/users/students")
async def search_academic_students(
    search: str = Query("", description="Search by name, roll number, or admission number"),
    academic_year: str = Query("2026-27"),
    class_id: Optional[uuid.UUID] = Query(None),
    section_id: Optional[uuid.UUID] = Query(None),
    limit: int = Query(50, ge=1, le=200),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Search students from User Management with existing class/section assignments."""
    class_id_str = str(class_id) if class_id else None
    section_id_str = str(section_id) if section_id else None
    
    rows = await exec_sql(
        "SELECT public.fn_search_academic_students(%s::UUID, %s, %s, %s::UUID, %s::UUID, %s) AS result;",
        (school_id, search, academic_year, class_id_str, section_id_str, limit)
    )
    if not rows or not rows[0].get("result"):
        return {"success": True, "data": []}
    
    return _serialize_val(rows[0]["result"])


@router.post("/users/check-student-moves")
async def check_student_moves(
    payload: CheckStudentMovesRequest,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Check if any of the given students are already assigned to other classes/sections for the academic year."""
    student_ids_arr = [str(sid) for sid in payload.student_ids]
    target_class_str = str(payload.target_class_id) if payload.target_class_id else None
    target_section_str = str(payload.target_section_id) if payload.target_section_id else None
    
    rows = await exec_sql(
        "SELECT public.fn_check_student_assignments(%s::UUID, %s::UUID[], %s, %s::UUID, %s::UUID) AS result;",
        (school_id, student_ids_arr, payload.academic_year, target_class_str, target_section_str)
    )
    if not rows or not rows[0].get("result"):
        return {"success": True, "has_conflicts": False, "conflicts": []}
    
    return _serialize_val(rows[0]["result"])
