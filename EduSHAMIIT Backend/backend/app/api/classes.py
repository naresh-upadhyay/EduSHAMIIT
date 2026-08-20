"""
Academic Class, Section, Subject & Room Management API for EduSHAMIIT ERP.
Provides full REST operations, multi-tenant scoping, contextual student/teacher assignments,
optional subject offerings, room allocations, conflict detection, and academic year isolation.
"""
from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, UploadFile, File
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any, Union
from datetime import datetime, date, time
import json
import uuid
import logging
import asyncio
import io
import csv
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
    """Recursively serialize datetime, date, time and UUID objects for JSON responses."""
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
    room_number: Optional[str] = Field(None, max_length=50)
    room_id: Optional[uuid.UUID] = Field(None)
    status: Optional[str] = Field("ACTIVE")


class ClassCreateRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    code: str = Field(..., min_length=1, max_length=50)
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
    room_id: Optional[uuid.UUID] = Field(None)
    academic_year: Optional[str] = Field("2026-27")
    status: Optional[str] = Field("ACTIVE")


class SectionUpdateRequest(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=50)
    code: Optional[str] = Field(None, max_length=50)
    capacity: Optional[int] = Field(None, ge=1, le=500)
    room_number: Optional[str] = Field(None, max_length=50)
    room_id: Optional[uuid.UUID] = Field(None)
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
    is_optional: Optional[bool] = Field(False)
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
    is_optional: Optional[bool] = Field(None)
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


# Room Schemas
class RoomCreateRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=150)
    code: str = Field(..., min_length=1, max_length=50)
    type: Optional[str] = Field("Classroom")
    building: Optional[str] = Field("Academic Block")
    floor: Optional[str] = Field("Ground Floor")
    capacity: Optional[int] = Field(40, ge=1, le=2000)
    facilities: Optional[List[str]] = Field(default_factory=list)
    status: Optional[str] = Field("AVAILABLE")
    description: Optional[str] = Field(None)


class RoomUpdateRequest(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=150)
    code: Optional[str] = Field(None, max_length=50)
    type: Optional[str] = Field(None)
    building: Optional[str] = Field(None)
    floor: Optional[str] = Field(None)
    capacity: Optional[int] = Field(None, ge=1, le=2000)
    facilities: Optional[List[str]] = Field(None)
    status: Optional[str] = Field(None)
    description: Optional[str] = Field(None)


class RoomBulkStatusRequest(BaseModel):
    room_ids: List[uuid.UUID] = Field(..., min_items=1)
    status: str = Field(..., description="AVAILABLE, OCCUPIED, MAINTENANCE, INACTIVE")


class SectionSubjectTeacherRequest(BaseModel):
    class_id: uuid.UUID
    section_ids: List[uuid.UUID] = Field(..., min_items=1)
    subject_id: uuid.UUID
    teacher_id: Optional[uuid.UUID] = Field(None)
    academic_year: Optional[str] = Field("2026-27")


class StudentOptionalEnrollmentRequest(BaseModel):
    class_id: uuid.UUID
    section_id: Optional[uuid.UUID] = None
    subject_id: uuid.UUID
    student_ids: List[uuid.UUID] = Field(default_factory=list)
    academic_year: Optional[str] = Field("2026-27")


class AssignSubjectToSectionsRequest(BaseModel):
    class_id: uuid.UUID
    section_ids: Optional[List[uuid.UUID]] = Field(default_factory=list)
    subject_id: uuid.UUID
    teacher_id: Optional[uuid.UUID] = Field(None)
    academic_year: Optional[str] = Field("2026-27")


class UnassignSubjectFromSectionRequest(BaseModel):
    class_id: uuid.UUID
    section_id: Optional[uuid.UUID] = Field(None)
    subject_id: uuid.UUID
    academic_year: Optional[str] = Field("2026-27")


class ToggleClassSubjectStatusRequest(BaseModel):
    class_id: uuid.UUID
    section_id: Optional[uuid.UUID] = Field(None)
    subject_id: uuid.UUID
    status: str = Field(..., description="ACTIVE or INACTIVE")
    academic_year: Optional[str] = Field("2026-27")


# ============================================================================
# ROLE-BASED ACCESS & SCOPING HELPERS
# ============================================================================

def _resolve_teacher_id_scope(current_user: dict, requested_teacher_id: Optional[str] = None) -> Optional[str]:
    """
    If the current user is a teacher/faculty, force teacher_id to their profile ID.
    If the current user is admin/staff/principal, honor the requested_teacher_id if provided.
    """
    role = (current_user.get("role") or "").lower()
    user_id = current_user.get("id")
    if role in ("teacher", "faculty", "instructor"):
        return user_id
    return requested_teacher_id


def _require_admin_or_staff(current_user: dict):
    """Ensure mutating operations can only be performed by administrators/staff."""
    role = (current_user.get("role") or "").lower()
    if role in ("teacher", "faculty", "instructor", "student", "parent"):
        raise HTTPException(
            status_code=403,
            detail="Forbidden: Only administrators can modify academic structures."
        )


# ============================================================================
# 1. TOP-LEVEL STATS & OVERVIEW
# ============================================================================

@router.get("/stats")
async def get_academic_stats(
    academic_year: str = Query("2026-27"),
    teacher_id: Optional[uuid.UUID] = Query(None, description="Optional teacher filter (enforced automatically for teacher role)"),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Retrieve high-level statistics for Academic Management (Classes, Sections, Subjects, Rooms)."""
    scoped_teacher_id = _resolve_teacher_id_scope(current_user, str(teacher_id) if teacher_id else None)
    rows = await exec_sql(
        "SELECT public.fn_get_academic_stats(%s::UUID, %s, %s::UUID) AS result;",
        (school_id, academic_year, scoped_teacher_id)
    )
    if not rows or not rows[0].get("result"):
        return {"success": True, "data": {"total_classes": 0, "active_classes": 0, "total_sections": 0, "total_subjects": 0, "total_rooms": 0}}
    
    return _serialize_val(rows[0]["result"])


# ============================================================================
# 2. CSV EXPORT
# ============================================================================

@router.get("/export/{entity}")
async def export_academic_data(
    entity: str,
    academic_year: str = Query("2026-27"),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Export academic entity datasets in CSV format."""
    output = io.StringIO()
    writer = csv.writer(output)

    if entity == "classes":
        writer.writerow(["Class Name", "Code", "Stage", "Academic Year", "Display Order", "Status"])
        rows = await exec_sql("""
            SELECT name, code, stage, academic_year, display_order, status 
            FROM public.academic_classes 
            WHERE school_id = %s::UUID AND academic_year = %s AND deleted_at IS NULL
            ORDER BY display_order ASC;
        """, (school_id, academic_year))
        for r in (rows or []):
            writer.writerow([r["name"], r["code"], r["stage"], r["academic_year"], r["display_order"], r["status"]])

    elif entity == "sections":
        writer.writerow(["Class", "Section Name", "Section Code", "Capacity", "Room", "Status"])
        rows = await exec_sql("""
            SELECT c.name as class_name, s.name, s.code, s.capacity, s.room_number, s.status 
            FROM public.academic_sections s
            JOIN public.academic_classes c ON c.id = s.class_id
            WHERE s.school_id = %s::UUID AND s.academic_year = %s AND s.deleted_at IS NULL
            ORDER BY c.display_order ASC, s.name ASC;
        """, (school_id, academic_year))
        for r in (rows or []):
            writer.writerow([r["class_name"], r["name"], r["code"], r["capacity"], r.get("room_number", ""), r["status"]])

    elif entity == "subjects":
        writer.writerow(["Subject Name", "Code", "Type", "Status"])
        rows = await exec_sql("""
            SELECT name, code, type, status 
            FROM public.academic_subjects 
            WHERE school_id = %s::UUID AND deleted_at IS NULL
            ORDER BY name ASC;
        """, (school_id,))
        for r in (rows or []):
            writer.writerow([r["name"], r["code"], r["type"], r["status"]])

    elif entity == "rooms":
        writer.writerow(["Room Name", "Room Code", "Type", "Building", "Floor", "Capacity", "Facilities", "Status"])
        rows = await exec_sql("""
            SELECT name, code, type, building, floor, capacity, facilities, status 
            FROM public.academic_rooms 
            WHERE school_id = %s::UUID AND deleted_at IS NULL
            ORDER BY building ASC, floor ASC, name ASC;
        """, (school_id,))
        for r in (rows or []):
            fac = ", ".join(r["facilities"]) if isinstance(r.get("facilities"), list) else ""
            writer.writerow([r["name"], r["code"], r["type"], r["building"], r["floor"], r["capacity"], fac, r["status"]])
    else:
        raise HTTPException(status_code=400, detail="Invalid export entity")

    return Response(
        content=output.getvalue(),
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename=edushamiit_{entity}_{academic_year}.csv"}
    )


@router.get("/template/{entity}")
async def download_academic_template(
    entity: str,
    academic_year: str = Query("2026-27"),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Download standardized sample CSV template for bulk uploads."""
    output = io.StringIO()
    writer = csv.writer(output)

    if entity == "classes":
        writer.writerow(["Class Name", "Code", "Stage", "Academic Year", "Display Order", "Status"])
        writer.writerow(["Class 9", "C9", "Secondary", academic_year, "9", "ACTIVE"])
        writer.writerow(["Class 10", "C10", "Secondary", academic_year, "10", "ACTIVE"])
        writer.writerow(["Class 11", "C11", "Higher Secondary", academic_year, "11", "ACTIVE"])
        writer.writerow(["Class 12", "C12", "Higher Secondary", academic_year, "12", "ACTIVE"])
    elif entity == "sections":
        writer.writerow(["Class", "Section Name", "Section Code", "Capacity", "Room", "Status"])
        writer.writerow(["Class 10", "Section A", "10A", "40", "Room 101", "ACTIVE"])
        writer.writerow(["Class 10", "Section B", "10B", "40", "Room 102", "ACTIVE"])
        writer.writerow(["Class 11", "Section Science", "11SCI", "35", "Lab 01", "ACTIVE"])
        writer.writerow(["Class 11", "Section Commerce", "11COM", "35", "Room 201", "ACTIVE"])
    elif entity == "subjects":
        writer.writerow(["Subject Name", "Code", "Type", "Status"])
        writer.writerow(["Advanced Mathematics", "MATH10", "Core", "ACTIVE"])
        writer.writerow(["English Literature", "ENG10", "Core", "ACTIVE"])
        writer.writerow(["Physics", "PHY11", "Core", "ACTIVE"])
        writer.writerow(["Computer Science", "CS10", "Elective", "ACTIVE"])
    elif entity == "rooms":
        writer.writerow(["Room Name", "Room Code", "Type", "Building", "Floor", "Capacity", "Facilities", "Status"])
        writer.writerow(["Classroom 101", "CR-101", "Classroom", "Academic Block", "1st Floor", "40", "Projector, AC, Smart Board", "AVAILABLE"])
        writer.writerow(["Classroom 102", "CR-102", "Classroom", "Academic Block", "1st Floor", "40", "Projector, AC", "AVAILABLE"])
        writer.writerow(["Physics Lab", "PHY-LAB-01", "Laboratory", "Science Block", "2nd Floor", "35", "AC, Laboratory Equipment, Projector", "AVAILABLE"])
        writer.writerow(["Computer Lab 1", "COMP-01", "Computer Lab", "IT Block", "Ground Floor", "30", "Computers, AC, Projector", "AVAILABLE"])
    else:
        raise HTTPException(status_code=400, detail="Invalid template entity")

    return Response(
        content=output.getvalue(),
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename=edushamiit_{entity}_template.csv"}
    )


class BulkImportRequest(BaseModel):
    csv_content: Optional[str] = None
    records: Optional[List[Dict[str, Any]]] = None
    academic_year: str = "2026-27"


@router.post("/import/{entity}")
async def import_academic_data(
    entity: str,
    req: BulkImportRequest,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Bulk import classes, sections, subjects, or rooms from CSV content or record list."""
    rows_to_process = []
    
    if req.csv_content and req.csv_content.strip():
        cleaned_csv = req.csv_content.strip().lstrip("\ufeff")
        f = io.StringIO(cleaned_csv)
        reader = csv.DictReader(f)
        for r in reader:
            if any(v.strip() for v in r.values() if v):
                rows_to_process.append({k.strip(): (v.strip() if v else "") for k, v in r.items() if k})
    elif req.records:
        rows_to_process = req.records

    if not rows_to_process:
        raise HTTPException(status_code=400, detail="No data records provided for import.")

    imported_count = 0
    failed_count = 0
    errors = []
    user_id = current_user.get("id")

    if entity == "classes":
        for i, row in enumerate(rows_to_process, start=1):
            name = row.get("Class Name") or row.get("name") or row.get("className") or ""
            if not name:
                errors.append(f"Row {i}: Missing Class Name")
                failed_count += 1
                continue
            
            code = row.get("Code") or row.get("code") or name.upper().replace(" ", "")
            stage = row.get("Stage") or row.get("stage") or "Secondary"
            ay = row.get("Academic Year") or row.get("academic_year") or req.academic_year
            
            raw_order = row.get("Display Order") or row.get("display_order") or i
            try:
                display_order = int(raw_order)
            except:
                display_order = i
            
            status = (row.get("Status") or row.get("status") or "ACTIVE").upper()
            if status not in ["ACTIVE", "INACTIVE", "ARCHIVED"]:
                status = "ACTIVE"

            try:
                existing = await exec_sql("""
                    SELECT id FROM public.academic_classes
                    WHERE school_id = %s::UUID AND academic_year = %s AND deleted_at IS NULL
                      AND (UPPER(code) = UPPER(%s) OR UPPER(name) = UPPER(%s))
                    LIMIT 1;
                """, (school_id, ay, code, name))

                if existing:
                    class_id = existing[0]["id"]
                    await exec_sql("""
                        UPDATE public.academic_classes SET
                            name = %s,
                            code = %s,
                            stage = %s,
                            display_order = %s,
                            status = %s,
                            updated_by = %s::UUID,
                            updated_at = NOW()
                        WHERE id = %s::UUID;
                    """, (name, code, stage, display_order, status, user_id, class_id), fetch=False)
                else:
                    await exec_sql("""
                        INSERT INTO public.academic_classes (
                            school_id, name, code, stage, academic_year, display_order, status, created_by, updated_by
                        ) VALUES (%s::UUID, %s, %s, %s, %s, %s, %s, %s::UUID, %s::UUID);
                    """, (school_id, name, code, stage, ay, display_order, status, user_id, user_id), fetch=False)
                imported_count += 1
            except Exception as e:
                failed_count += 1
                errors.append(f"Row {i} ({name}): {str(e)}")

    elif entity == "sections":
        classes_rows = await exec_sql("""
            SELECT id, name, code FROM public.academic_classes 
            WHERE school_id = %s::UUID AND academic_year = %s AND deleted_at IS NULL;
        """, (school_id, req.academic_year))
        class_map = {}
        for c in (classes_rows or []):
            class_map[c["name"].lower().strip()] = c["id"]
            class_map[c["code"].lower().strip()] = c["id"]

        for i, row in enumerate(rows_to_process, start=1):
            class_ident = (row.get("Class") or row.get("class_name") or row.get("className") or "").lower().strip()
            class_id = class_map.get(class_ident)
            
            if not class_id:
                errors.append(f"Row {i}: Class '{row.get('Class', '')}' not found. Please create the Class first.")
                failed_count += 1
                continue

            sec_name = row.get("Section Name") or row.get("name") or row.get("section_name") or ""
            if not sec_name:
                errors.append(f"Row {i}: Missing Section Name")
                failed_count += 1
                continue

            sec_code = row.get("Section Code") or row.get("code") or sec_name.upper().replace(" ", "")
            raw_cap = row.get("Capacity") or row.get("capacity") or 40
            try:
                capacity = int(raw_cap)
            except:
                capacity = 40
            
            room = row.get("Room") or row.get("room_number") or None
            status = (row.get("Status") or row.get("status") or "ACTIVE").upper()
            if status not in ["ACTIVE", "INACTIVE", "ARCHIVED"]:
                status = "ACTIVE"

            try:
                existing_sec = await exec_sql("""
                    SELECT id FROM public.academic_sections
                    WHERE school_id = %s::UUID AND class_id = %s::UUID AND academic_year = %s AND deleted_at IS NULL
                      AND (UPPER(code) = UPPER(%s) OR UPPER(name) = UPPER(%s))
                    LIMIT 1;
                """, (school_id, class_id, req.academic_year, sec_code, sec_name))

                if existing_sec:
                    sec_id = existing_sec[0]["id"]
                    await exec_sql("""
                        UPDATE public.academic_sections SET
                            name = %s,
                            code = %s,
                            capacity = %s,
                            room_number = %s,
                            status = %s,
                            updated_by = %s::UUID,
                            updated_at = NOW()
                        WHERE id = %s::UUID;
                    """, (sec_name, sec_code, capacity, room, status, user_id, sec_id), fetch=False)
                else:
                    await exec_sql("""
                        INSERT INTO public.academic_sections (
                            school_id, class_id, name, code, capacity, room_number, academic_year, status, created_by, updated_by
                        ) VALUES (%s::UUID, %s::UUID, %s, %s, %s, %s, %s, %s, %s::UUID, %s::UUID);
                    """, (school_id, class_id, sec_name, sec_code, capacity, room, req.academic_year, status, user_id, user_id), fetch=False)
                imported_count += 1
            except Exception as e:
                failed_count += 1
                errors.append(f"Row {i} ({sec_name}): {str(e)}")

    elif entity == "subjects":
        for i, row in enumerate(rows_to_process, start=1):
            sub_name = row.get("Subject Name") or row.get("name") or row.get("subject_name") or ""
            if not sub_name:
                errors.append(f"Row {i}: Missing Subject Name")
                failed_count += 1
                continue

            code = row.get("Code") or row.get("code") or sub_name[:6].upper().replace(" ", "")
            sub_type = row.get("Type") or row.get("type") or "Core"
            raw_periods = row.get("Periods Per Week") or row.get("periods_per_week") or 5
            try:
                periods = int(raw_periods)
            except:
                periods = 5

            status = (row.get("Status") or row.get("status") or "ACTIVE").upper()
            if status not in ["ACTIVE", "INACTIVE", "ARCHIVED"]:
                status = "ACTIVE"

            try:
                existing_sub = await exec_sql("""
                    SELECT id FROM public.academic_subjects
                    WHERE school_id = %s::UUID AND deleted_at IS NULL
                      AND (UPPER(code) = UPPER(%s) OR UPPER(name) = UPPER(%s))
                    LIMIT 1;
                """, (school_id, code, sub_name))

                if existing_sub:
                    sub_id = existing_sub[0]["id"]
                    await exec_sql("""
                        UPDATE public.academic_subjects SET
                            name = %s,
                            code = %s,
                            type = %s,
                            periods_per_week = %s,
                            status = %s,
                            updated_by = %s::UUID,
                            updated_at = NOW()
                        WHERE id = %s::UUID;
                    """, (sub_name, code, sub_type, periods, status, user_id, sub_id), fetch=False)
                else:
                    await exec_sql("""
                        INSERT INTO public.academic_subjects (
                            school_id, name, code, type, periods_per_week, status, created_by, updated_by
                        ) VALUES (%s::UUID, %s, %s, %s, %s, %s, %s::UUID, %s::UUID);
                    """, (school_id, sub_name, code, sub_type, periods, status, user_id, user_id), fetch=False)
                imported_count += 1
            except Exception as e:
                failed_count += 1
                errors.append(f"Row {i} ({sub_name}): {str(e)}")

    elif entity == "rooms":
        for i, row in enumerate(rows_to_process, start=1):
            room_name = row.get("Room Name") or row.get("name") or row.get("room_name") or ""
            if not room_name:
                errors.append(f"Row {i}: Missing Room Name")
                failed_count += 1
                continue

            code = row.get("Room Code") or row.get("code") or room_name.upper().replace(" ", "-")
            room_type = row.get("Type") or row.get("type") or "Classroom"
            building = row.get("Building") or row.get("building") or "Academic Block"
            floor = row.get("Floor") or row.get("floor") or "Ground Floor"
            raw_cap = row.get("Capacity") or row.get("capacity") or 40
            try:
                capacity = int(raw_cap)
            except:
                capacity = 40

            raw_fac = row.get("Facilities") or row.get("facilities") or ""
            if isinstance(raw_fac, str):
                facilities = [f.strip() for f in raw_fac.split(",") if f.strip()]
            elif isinstance(raw_fac, list):
                facilities = raw_fac
            else:
                facilities = []

            status = (row.get("Status") or row.get("status") or "AVAILABLE").upper()
            if status not in ["AVAILABLE", "OCCUPIED", "RESERVED", "MAINTENANCE", "INACTIVE"]:
                status = "AVAILABLE"

            try:
                existing_room = await exec_sql("""
                    SELECT id FROM public.academic_rooms
                    WHERE school_id = %s::UUID AND deleted_at IS NULL
                      AND (UPPER(code) = UPPER(%s) OR UPPER(name) = UPPER(%s))
                    LIMIT 1;
                """, (school_id, code, room_name))

                if existing_room:
                    room_id = existing_room[0]["id"]
                    await exec_sql("""
                        UPDATE public.academic_rooms SET
                            name = %s,
                            code = %s,
                            type = %s,
                            building = %s,
                            floor = %s,
                            capacity = %s,
                            facilities = %s::JSONB,
                            status = %s,
                            updated_by = %s::UUID,
                            updated_at = NOW()
                        WHERE id = %s::UUID;
                    """, (room_name, code, room_type, building, floor, capacity, json.dumps(facilities), status, user_id, room_id), fetch=False)
                else:
                    await exec_sql("""
                        INSERT INTO public.academic_rooms (
                            school_id, name, code, type, building, floor, capacity, facilities, status, created_by, updated_by
                        ) VALUES (%s::UUID, %s, %s, %s, %s, %s, %s, %s::JSONB, %s, %s::UUID, %s::UUID);
                    """, (school_id, room_name, code, room_type, building, floor, capacity, json.dumps(facilities), status, user_id, user_id), fetch=False)
                imported_count += 1
            except Exception as e:
                failed_count += 1
                errors.append(f"Row {i} ({room_name}): {str(e)}")
    else:
        raise HTTPException(status_code=400, detail="Invalid import entity")

    return {
        "success": True,
        "imported_count": imported_count,
        "failed_count": failed_count,
        "errors": errors,
        "message": f"Successfully processed {imported_count} {entity} ({failed_count} failed)."
    }


# ============================================================================
# 3. USER MANAGEMENT PICKER & CONFLICT DETECTION
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


# ============================================================================
# 4. ROOMS ENDPOINTS (STATIC & SUBPATHS MUST BE BEFORE /{class_id})
# ============================================================================

@router.get("/rooms/stats")
async def get_room_stats(
    academic_year: str = Query("2026-27"),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Retrieve statistics and dashboard metrics for Rooms Management."""
    rows = await exec_sql(
        "SELECT public.fn_get_academic_stats(%s::UUID, %s) AS result;",
        (school_id, academic_year)
    )
    if not rows or not rows[0].get("result"):
        return {"success": True, "data": {"total_rooms": 0, "available_rooms": 0, "in_use_rooms": 0, "maintenance_rooms": 0, "total_room_capacity": 0}}
    
    full_data = rows[0]["result"].get("data", {})
    return {
        "success": True,
        "data": {
            "total_rooms": full_data.get("total_rooms", 0),
            "available_rooms": full_data.get("available_rooms", 0),
            "in_use_rooms": full_data.get("in_use_rooms", 0),
            "maintenance_rooms": full_data.get("maintenance_rooms", 0),
            "total_room_capacity": full_data.get("total_room_capacity", 0),
            "room_types_breakdown": full_data.get("room_types_breakdown", []),
            "buildings_breakdown": full_data.get("buildings_breakdown", [])
        }
    }


@router.get("/rooms/buildings-floors")
async def get_buildings_and_floors(
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Get list of distinct buildings and floors configured for the school."""
    rows = await exec_sql("""
        SELECT DISTINCT building, floor 
        FROM public.academic_rooms 
        WHERE school_id = %s::UUID AND deleted_at IS NULL
        ORDER BY building ASC, floor ASC;
    """, (school_id,))
    
    buildings = sorted(list(set(r["building"] for r in (rows or []) if r.get("building"))))
    floors = sorted(list(set(r["floor"] for r in (rows or []) if r.get("floor"))))
    
    return {
        "success": True,
        "data": {
            "buildings": buildings or ["Academic Block", "Science Block", "IT Block", "Library Block", "Activity Block", "Administrative Block", "Main Building"],
            "floors": floors or ["Ground Floor", "1st Floor", "2nd Floor", "3rd Floor", "4th Floor"]
        }
    }


@router.post("/rooms/bulk-status")
async def bulk_update_room_status(
    payload: RoomBulkStatusRequest,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Bulk update status of multiple rooms (e.g. mark maintenance or available)."""
    _require_admin_or_staff(current_user)
    user_id = current_user.get("id")
    room_ids_arr = [str(rid) for rid in payload.room_ids]

    await exec_sql("""
        UPDATE public.academic_rooms 
        SET status = %s, updated_by = %s::UUID, updated_at = NOW()
        WHERE school_id = %s::UUID AND id = ANY(%s::UUID[]) AND deleted_at IS NULL;
    """, (payload.status, user_id, school_id, room_ids_arr), fetch=False)

    return {"success": True, "message": f"{len(payload.room_ids)} rooms updated to {payload.status}."}


@router.get("/rooms/{room_id}")
async def get_room_detail(
    room_id: uuid.UUID,
    academic_year: str = Query("2026-27"),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Get complete room details including assigned sections, capacity utilization, and facilities."""
    rows = await exec_sql("""
        SELECT * FROM public.academic_rooms 
        WHERE id = %s::UUID AND school_id = %s::UUID AND deleted_at IS NULL;
    """, (str(room_id), school_id))

    if not rows:
        raise HTTPException(status_code=404, detail="Room not found")
    
    room_data = rows[0]

    # Fetch assigned academic sections utilizing this room strictly in the selected academic year
    sec_rows = await exec_sql("""
        SELECT 
            s.id,
            s.name,
            s.code,
            s.capacity,
            s.status,
            s.academic_year,
            c.id as class_id,
            c.name as class_name,
            c.code as class_code,
            c.stage as class_stage,
            COALESCE(
                (SELECT COUNT(DISTINCT sca.student_id) 
                 FROM public.student_class_assignments sca 
                 WHERE sca.section_id = s.id 
                   AND sca.school_id = %s::UUID
                   AND sca.status = 'ACTIVE'
                   AND (sca.academic_year = %s OR sca.academic_year IS NULL)),
                0
            ) as students_count,
            (
                SELECT jsonb_build_object(
                    'id', p.id,
                    'full_name', p.full_name,
                    'email', p.email,
                    'avatar_url', p.avatar_url,
                    'employee_id', p.employee_id,
                    'department', p.department
                )
                FROM public.class_teacher_assignments cta
                JOIN public.profiles p ON p.id = cta.teacher_id
                WHERE cta.section_id = s.id 
                  AND (cta.academic_year = %s OR cta.academic_year IS NULL)
                ORDER BY cta.is_primary DESC, cta.created_at DESC
                LIMIT 1
            ) as class_teacher
        FROM public.academic_sections s
        JOIN public.academic_classes c ON c.id = s.class_id
        WHERE s.room_id = %s::UUID 
          AND s.school_id = %s::UUID
          AND s.academic_year = %s
          AND c.academic_year = %s
          AND s.deleted_at IS NULL 
          AND c.deleted_at IS NULL
        ORDER BY c.display_order ASC, s.name ASC;
    """, (school_id, academic_year, academic_year, str(room_id), school_id, academic_year, academic_year))

    sections_list = sec_rows or []
    total_students_seated = sum(int(s.get("students_count") or 0) for s in sections_list)
    room_capacity = int(room_data.get("capacity") or 40)

    room_data["assigned_sections"] = sections_list
    room_data["assigned_sections_count"] = len(sections_list)
    room_data["total_students_seated"] = total_students_seated
    room_data["capacity_utilization"] = round((total_students_seated / max(room_capacity, 1)) * 100, 1) if room_capacity > 0 else 0.0

    return {"success": True, "data": _serialize_val(room_data)}


@router.patch("/rooms/{room_id}")
@router.put("/rooms/{room_id}")
async def update_room(
    room_id: uuid.UUID,
    payload: RoomUpdateRequest,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Update room attributes."""
    _require_admin_or_staff(current_user)
    user_id = current_user.get("id")
    payload_json = json.dumps({k: v for k, v in payload.dict().items() if v is not None})

    rows = await exec_sql(
        "SELECT public.fn_update_academic_room(%s::UUID, %s::UUID, %s::UUID, %s::JSONB) AS result;",
        (school_id, user_id, str(room_id), payload_json)
    )
    res = rows[0]["result"] if rows else {"success": False, "error": "Room not found"}
    if not res.get("success"):
        raise HTTPException(status_code=res.get("code", 400), detail=res.get("error", "Failed to update room"))
    
    return _serialize_val(res)


@router.delete("/rooms/{room_id}")
@router.patch("/rooms/{room_id}/archive")
async def archive_room(
    room_id: uuid.UUID,
    force: bool = Query(False),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Archive a room with dependency safeguards."""
    _require_admin_or_staff(current_user)
    user_id = current_user.get("id")
    rows = await exec_sql(
        "SELECT public.fn_archive_academic_room(%s::UUID, %s::UUID, %s::UUID, %s) AS result;",
        (school_id, user_id, str(room_id), force)
    )
    res = rows[0]["result"] if rows else {"success": False, "error": "Room not found"}
    if not res.get("success"):
        raise HTTPException(status_code=res.get("code", 400), detail=res)
    
    return _serialize_val(res)


@router.post("/rooms/{room_id}/restore")
@router.patch("/rooms/{room_id}/restore")
async def restore_room(
    room_id: uuid.UUID,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Restore an archived room."""
    _require_admin_or_staff(current_user)
    user_id = current_user.get("id")
    rows = await exec_sql(
        "SELECT public.fn_restore_academic_room(%s::UUID, %s::UUID, %s::UUID) AS result;",
        (school_id, user_id, str(room_id))
    )
    res = rows[0]["result"] if rows else {"success": False, "error": "Room not found"}
    if not res.get("success"):
        raise HTTPException(status_code=res.get("code", 400), detail=res.get("error", "Failed to restore room"))
    
    return _serialize_val(res)


@router.get("/rooms")
async def get_rooms(
    search: str = Query("", description="Search by room name, code, type, or building"),
    type: str = Query("ALL"),
    building: str = Query("ALL"),
    floor: str = Query("ALL"),
    status: str = Query("ALL"),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    sort_by: str = Query("name"),
    sort_order: str = Query("ASC"),
    academic_year: str = Query("2026-27"),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Get paginated rooms list with filters and dynamic in-use/timings status."""
    rows = await exec_sql(
        "SELECT public.fn_get_academic_rooms(%s::UUID, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s) AS result;",
        (school_id, search, type, building, floor, status, page, page_size, sort_by, sort_order, academic_year)
    )
    if not rows or not rows[0].get("result"):
        return {"success": True, "data": {"rooms": [], "total_count": 0, "page": page, "page_size": page_size}}
    
    return _serialize_val(rows[0]["result"])


@router.post("/rooms")
async def create_room(
    payload: RoomCreateRequest,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Create a new room or facility in the school."""
    _require_admin_or_staff(current_user)
    user_id = current_user.get("id")
    payload_json = json.dumps(payload.dict())

    rows = await exec_sql(
        "SELECT public.fn_create_academic_room(%s::UUID, %s::UUID, %s::JSONB) AS result;",
        (school_id, user_id, payload_json)
    )
    res = rows[0]["result"] if rows else {"success": False, "error": "Internal server error"}
    if not res.get("success"):
        raise HTTPException(status_code=res.get("code", 400), detail=res.get("error", "Failed to create room"))
    
    return _serialize_val(res)


# ============================================================================
# 5. SECTIONS ENDPOINTS (BEFORE /{class_id})
# ============================================================================

@router.get("/sections/stats")
async def get_sections_overview_stats(
    academic_year: str = Query("2026-27"),
    teacher_id: Optional[uuid.UUID] = Query(None),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Retrieve overview statistics, class distributions, and buildings overview for Sections Management."""
    scoped_teacher_id = _resolve_teacher_id_scope(current_user, str(teacher_id) if teacher_id else None)
    rows = await exec_sql(
        "SELECT public.fn_get_academic_stats(%s::UUID, %s, %s::UUID) AS result;",
        (school_id, academic_year, scoped_teacher_id)
    )
    if not rows or not rows[0].get("result"):
        return {
            "success": True,
            "data": {
                "total_sections": 0,
                "active_sections": 0,
                "inactive_sections": 0,
                "total_students": 0,
                "avg_students_per_section": 0.0,
                "sections_by_class": [],
                "buildings_overview": []
            }
        }
    
    full_data = rows[0]["result"].get("data", {})
    return {
        "success": True,
        "data": {
            "total_sections": full_data.get("total_sections", 0),
            "active_sections": full_data.get("active_sections", 0),
            "inactive_sections": full_data.get("inactive_sections", 0),
            "total_students": full_data.get("total_students", 0),
            "avg_students_per_section": full_data.get("avg_students_per_section", 0.0),
            "sections_by_class": full_data.get("sections_by_class", []),
            "buildings_overview": full_data.get("buildings_breakdown", [])
        }
    }


@router.get("/sections/all")
async def get_sections(
    search: str = Query("", description="Search section name, code, or class name"),
    class_id: Optional[uuid.UUID] = Query(None),
    academic_year: str = Query("2026-27"),
    status: str = Query("ALL"),
    building: str = Query("ALL", description="Filter by room building name or 'Unassigned'"),
    floor: str = Query("ALL", description="Filter by room floor or 'Unassigned'"),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    sort_by: str = Query("class_name"),
    sort_order: str = Query("ASC"),
    teacher_id: Optional[uuid.UUID] = Query(None, description="Optional teacher filter (enforced automatically for teacher role)"),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Get paginated sections across all classes with multi-criteria filters."""
    class_id_str = str(class_id) if class_id else None
    scoped_teacher_id = _resolve_teacher_id_scope(current_user, str(teacher_id) if teacher_id else None)
    rows = await exec_sql(
        "SELECT public.fn_get_academic_sections(%s::UUID, %s::UUID, %s, %s, %s, %s, %s, %s, %s, %s::UUID, %s, %s) AS result;",
        (school_id, class_id_str, search, academic_year, status, page, page_size, sort_by, sort_order, scoped_teacher_id, building, floor)
    )
    if not rows or not rows[0].get("result"):
        return {"success": True, "data": {"sections": [], "total_count": 0, "page": page, "page_size": page_size}}
    
    return _serialize_val(rows[0]["result"])


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
    p_dict = {k: v for k, v in payload.dict().items() if v is not None}
    if "room_id" in p_dict and p_dict["room_id"] is not None:
        p_dict["room_id"] = str(p_dict["room_id"])
    payload_json = json.dumps(p_dict)
    
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
        "room_id": str(payload.room_id) if payload.room_id else None,
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


# ============================================================================
# 6. SUBJECTS ENDPOINTS (BEFORE /{class_id})
# ============================================================================

@router.get("/subjects/all")
async def get_subjects(
    search: str = Query("", description="Search by subject name, code, or type"),
    type: str = Query("ALL", description="ALL, Core, Elective, Language, Practical, Activity, Other"),
    status: str = Query("ALL"),
    class_id: Optional[uuid.UUID] = Query(None, description="Optional class filter"),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    sort_by: str = Query("name"),
    sort_order: str = Query("ASC"),
    teacher_id: Optional[uuid.UUID] = Query(None, description="Optional teacher filter (enforced automatically for teacher role)"),
    academic_year: str = Query("2026-27"),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Get paginated list of subjects in catalog."""
    scoped_teacher_id = _resolve_teacher_id_scope(current_user, str(teacher_id) if teacher_id else None)
    class_id_str = str(class_id) if class_id else None
    rows = await exec_sql(
        "SELECT public.fn_get_academic_subjects(%s::UUID, %s, %s, %s, %s::UUID, %s, %s, %s, %s, %s::UUID, %s) AS result;",
        (school_id, search, type, status, class_id_str, page, page_size, sort_by, sort_order, scoped_teacher_id, academic_year)
    )
    if not rows or not rows[0].get("result"):
        return {"success": True, "data": {"subjects": [], "total_count": 0, "page": page, "page_size": page_size}}
    
    return _serialize_val(rows[0]["result"])


@router.get("/subjects/mappings")
async def get_subject_section_mappings(
    subject_id: Optional[uuid.UUID] = Query(None),
    academic_year: str = Query("2026-27"),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Get aggregated elective/optional subject mappings with section offerings, enrollments, and assigned teachers."""
    subject_id_str = str(subject_id) if subject_id else None
    rows = await exec_sql(
        "SELECT public.fn_get_subject_section_mappings(%s::UUID, %s::UUID, %s) AS result;",
        (school_id, subject_id_str, academic_year)
    )
    if not rows or not rows[0].get("result"):
        return {"success": True, "data": []}
    return _serialize_val(rows[0]["result"])


@router.post("/subjects/assign-sections")
async def assign_subject_to_sections(
    payload: AssignSubjectToSectionsRequest,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Assign a subject to one or more sections of a class or directly to the class. Auto-enrolls students if Mandatory."""
    _require_admin_or_staff(current_user)
    user_id = current_user.get("id")
    section_ids_arr = [str(sid) for sid in (payload.section_ids or [])]
    teacher_id_str = str(payload.teacher_id) if payload.teacher_id else None

    rows = await exec_sql(
        "SELECT public.fn_assign_subject_to_sections(%s::UUID, %s::UUID, %s::UUID, %s::UUID[], %s::UUID, %s::UUID, %s) AS result;",
        (school_id, user_id, str(payload.class_id), section_ids_arr, str(payload.subject_id), teacher_id_str, payload.academic_year)
    )
    res = rows[0]["result"] if rows else {"success": False, "error": "Failed to assign subject"}
    if not res.get("success"):
        raise HTTPException(status_code=res.get("code", 400), detail=res.get("error", "Failed to assign subject"))
    return _serialize_val(res)


@router.post("/subjects/unassign-section")
async def unassign_subject_from_section(
    payload: UnassignSubjectFromSectionRequest,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Unassign a subject from a section or direct class."""
    _require_admin_or_staff(current_user)
    user_id = current_user.get("id")
    section_id_str = str(payload.section_id) if payload.section_id else None

    rows = await exec_sql(
        "SELECT public.fn_unassign_subject_from_section(%s::UUID, %s::UUID, %s::UUID, %s::UUID, %s::UUID, %s) AS result;",
        (school_id, user_id, str(payload.class_id), section_id_str, str(payload.subject_id), payload.academic_year)
    )
    res = rows[0]["result"] if rows else {"success": False, "error": "Failed to unassign subject"}
    if not res.get("success"):
        raise HTTPException(status_code=res.get("code", 400), detail=res.get("error", "Failed to unassign subject"))
    return _serialize_val(res)


@router.post("/subjects/toggle-status")
async def toggle_class_subject_status(
    payload: ToggleClassSubjectStatusRequest,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Toggle status (ACTIVE/INACTIVE) of a subject offering for a class & section combo."""
    _require_admin_or_staff(current_user)
    user_id = current_user.get("id")
    section_id_str = str(payload.section_id) if payload.section_id else None

    rows = await exec_sql(
        "SELECT public.fn_toggle_class_subject_status(%s::UUID, %s::UUID, %s::UUID, %s::UUID, %s::UUID, %s, %s) AS result;",
        (school_id, user_id, str(payload.class_id), section_id_str, str(payload.subject_id), payload.status, payload.academic_year)
    )
    res = rows[0]["result"] if rows else {"success": False, "error": "Failed to update offering status"}
    if not res.get("success"):
        raise HTTPException(status_code=res.get("code", 400), detail=res.get("error", "Failed to update offering status"))
    return _serialize_val(res)


@router.post("/subjects/section-teachers")
async def assign_section_subject_teachers(
    payload: SectionSubjectTeacherRequest,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Assign a teacher to a specific subject for selected sections of a class."""
    _require_admin_or_staff(current_user)
    user_id = current_user.get("id")
    section_ids_arr = [str(sid) for sid in payload.section_ids]
    teacher_id_str = str(payload.teacher_id) if payload.teacher_id else None

    rows = await exec_sql(
        "SELECT public.fn_manage_section_subject_teachers(%s::UUID, %s::UUID, %s::UUID, %s::UUID[], %s::UUID, %s::UUID, %s) AS result;",
        (school_id, user_id, str(payload.class_id), section_ids_arr, str(payload.subject_id), teacher_id_str, payload.academic_year)
    )
    res = rows[0]["result"] if rows else {"success": False, "error": "Failed to assign teacher"}
    if not res.get("success"):
        raise HTTPException(status_code=res.get("code", 400), detail=res.get("error", "Failed to assign teacher"))
    return _serialize_val(res)


@router.post("/subjects/enrollments")
async def manage_student_optional_enrollments(
    payload: StudentOptionalEnrollmentRequest,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Enroll or unenroll students in an optional / elective subject for a section or class."""
    _require_admin_or_staff(current_user)
    user_id = current_user.get("id")
    student_ids_arr = [str(sid) for sid in payload.student_ids]
    section_id_str = str(payload.section_id) if payload.section_id else None

    rows = await exec_sql(
        "SELECT public.fn_manage_student_subject_enrollments(%s::UUID, %s::UUID, %s::UUID, %s::UUID, %s::UUID, %s::UUID[], %s) AS result;",
        (school_id, user_id, str(payload.class_id), section_id_str, str(payload.subject_id), student_ids_arr, payload.academic_year)
    )
    res = rows[0]["result"] if rows else {"success": False, "error": "Failed to update enrollments"}
    if not res.get("success"):
        raise HTTPException(status_code=res.get("code", 400), detail=res.get("error", "Failed to update enrollments"))
    return _serialize_val(res)


@router.get("/subjects/enrollments")
async def get_student_optional_enrollments(
    subject_id: uuid.UUID = Query(...),
    section_id: Optional[uuid.UUID] = Query(None),
    class_id: Optional[uuid.UUID] = Query(None),
    academic_year: str = Query("2026-27"),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Fetch list of enrolled student IDs and full student profiles for an optional subject in a section or class."""
    if section_id:
        rows = await exec_sql("""
            SELECT 
                p.id,
                p.full_name,
                p.email,
                p.admission_number,
                p.roll_number,
                p.avatar_url,
                (sse.id IS NOT NULL AND sse.status = 'ACTIVE') as is_enrolled
            FROM public.student_class_assignments sca
            JOIN public.profiles p ON p.id = sca.student_id
            LEFT JOIN public.student_subject_enrollments sse 
                ON (sse.student_id = p.id AND sse.section_id = %s::UUID AND sse.subject_id = %s::UUID AND sse.academic_year = %s)
            WHERE sca.section_id = %s::UUID 
              AND sca.school_id = %s::UUID
              AND sca.academic_year = %s
              AND sca.status = 'ACTIVE'
            ORDER BY p.full_name ASC;
        """, (str(section_id), str(subject_id), academic_year, str(section_id), school_id, academic_year))
    elif class_id:
        rows = await exec_sql("""
            SELECT 
                p.id,
                p.full_name,
                p.email,
                p.admission_number,
                p.roll_number,
                p.avatar_url,
                (sse.id IS NOT NULL AND sse.status = 'ACTIVE') as is_enrolled
            FROM public.student_class_assignments sca
            JOIN public.profiles p ON p.id = sca.student_id
            LEFT JOIN public.student_subject_enrollments sse 
                ON (sse.student_id = p.id AND sse.class_id = %s::UUID AND sse.subject_id = %s::UUID AND sse.academic_year = %s)
            WHERE sca.class_id = %s::UUID 
              AND sca.school_id = %s::UUID
              AND sca.academic_year = %s
              AND sca.status = 'ACTIVE'
            ORDER BY p.full_name ASC;
        """, (str(class_id), str(subject_id), academic_year, str(class_id), school_id, academic_year))
    else:
        return {"success": True, "data": []}

    return {"success": True, "data": _serialize_val(rows or [])}


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


# ============================================================================
# 7. CLASSES ROOT ENDPOINTS
# ============================================================================

@router.get("")
async def get_classes(
    search: str = Query("", description="Search by class name, code, or stage"),
    academic_year: str = Query("2026-27"),
    status: str = Query("ALL", description="ALL, ACTIVE, INACTIVE, ARCHIVED"),
    stage: str = Query("ALL", description="Filter by class stage: ALL, Primary, Middle, Secondary, Senior Secondary, etc."),
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
        "SELECT public.fn_get_academic_classes(%s::UUID, %s, %s, %s, %s, %s, %s, %s, %s::UUID, %s) AS result;",
        (school_id, search, academic_year, status, page, page_size, sort_by, sort_order, scoped_teacher_id, stage)
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


# ============================================================================
# 8. CLASS CONTEXTUAL ASSIGNMENTS (BEFORE /{class_id})
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
# 9. CLASS SPECIFIC PARAMETERIZED ENDPOINTS (MUST BE LAST)
# ============================================================================

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
