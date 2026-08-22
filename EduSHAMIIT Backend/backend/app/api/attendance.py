"""
==============================================================================
Attendance Management API Module - EduSHAMIIT ERP
==============================================================================
Production-ready, role-aware, multi-tenant Attendance Management API.
Supports:
  - Daily & Period-Wise Attendance with Atomic All-Day Propagation & Locking
  - Role-Based Permissions & Scoping (Admin, Principal, Teacher, Staff, Student)
  - Staff / Employee Attendance with Manager Hierarchy
  - Leave Application Integration & Warning Overrides
  - Bulk Operations, Concurrency Protection, Audit Logging, & Real-Time Insights
==============================================================================
"""

import asyncio
import json
import logging
import uuid
from datetime import date, datetime, time
from typing import Any, Dict, List, Optional

import psycopg2
from psycopg2.extras import RealDictCursor
from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from fastapi.responses import PlainTextResponse
from pydantic import BaseModel, Field

from app.config import settings
from app.middleware.auth import get_current_user, require_school_id

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/attendance", tags=["Attendance Management"])


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
                if fetch and cur.description is not None:
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
    """Recursively serialize datetime, date, and UUID objects for JSON responses."""
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

class AttendanceItemPayload(BaseModel):
    student_id: uuid.UUID
    status: str = Field("PRESENT", description="PRESENT, ABSENT, LATE, ON_LEAVE, HALF_DAY, NOT_MARKED")
    remarks: Optional[str] = Field(None)
    period_number: Optional[int] = Field(None)
    subject_id: Optional[uuid.UUID] = Field(None)


class SaveAttendanceRequest(BaseModel):
    attendance_date: str = Field(..., description="YYYY-MM-DD")
    class_id: uuid.UUID
    section_id: Optional[uuid.UUID] = Field(None)
    mode: str = Field("ALL_DAY", description="ALL_DAY, PERIOD, MULTI_SCHEDULE, CUSTOM_SELECTION")
    period_number: Optional[int] = Field(None)
    subject_id: Optional[uuid.UUID] = Field(None)
    schedule_id: Optional[uuid.UUID] = Field(None)
    selected_schedule_ids: List[str] = Field(default_factory=list)
    selected_periods: List[Dict[str, Any]] = Field(default_factory=list)
    records: List[AttendanceItemPayload] = Field(default_factory=list)
    allow_override: Optional[bool] = Field(False)


class OverrideAttendanceRequest(BaseModel):
    record_id: uuid.UUID
    record_type: str = Field("DAILY", description="DAILY or PERIOD")
    new_status: str = Field(..., description="PRESENT, ABSENT, LATE, ON_LEAVE, HALF_DAY")
    reason: str = Field(..., min_length=3, description="Mandatory justification for overriding locked record")


class StaffAttendanceItemPayload(BaseModel):
    employee_id: uuid.UUID
    status: str = Field("PRESENT", description="PRESENT, ABSENT, LATE, HALF_DAY, ON_LEAVE, WORK_FROM_HOME, HOLIDAY")
    check_in_time: Optional[str] = Field(None)
    check_out_time: Optional[str] = Field(None)
    is_wfh: Optional[bool] = Field(False)
    remarks: Optional[str] = Field(None)


class SaveStaffAttendanceRequest(BaseModel):
    attendance_date: str = Field(..., description="YYYY-MM-DD")
    records: List[StaffAttendanceItemPayload] = Field(default_factory=list)


class BulkAttendanceOperationRequest(BaseModel):
    operation: str = Field(..., description="MARK_STATUS, ADD_REMARKS, LOCK, UNLOCK")
    attendance_date: str = Field(...)
    class_id: uuid.UUID
    section_id: Optional[uuid.UUID] = Field(None)
    student_ids: List[uuid.UUID] = Field(default_factory=list)
    target_status: Optional[str] = Field(None)
    remarks: Optional[str] = Field(None)
    reason: Optional[str] = Field(None)


class AttendanceSettingsUpdateRequest(BaseModel):
    allow_late: Optional[bool] = Field(None)
    late_cutoff_minutes: Optional[int] = Field(None, ge=1, le=120)
    require_absent_remark: Optional[bool] = Field(None)
    require_late_remark: Optional[bool] = Field(None)
    auto_mark_approved_leave: Optional[bool] = Field(None)
    lock_after_hours: Optional[int] = Field(None, ge=1, le=168)
    allow_teacher_override_locked: Optional[bool] = Field(None)
    enable_notifications: Optional[bool] = Field(None)


class LeaveActionRequest(BaseModel):
    action: str = Field(..., description="APPROVE, REJECT, CANCEL")
    remarks: Optional[str] = Field(None)


# ============================================================================
# ROLE & SCOPING HELPERS
# ============================================================================

def _serialize_val(obj: Any) -> Any:
    if isinstance(obj, (datetime, date)):
        return obj.isoformat()
    if isinstance(obj, uuid.UUID):
        return str(obj)
    if isinstance(obj, list):
        return [_serialize_val(item) for item in obj]
    if isinstance(obj, dict):
        return {k: _serialize_val(v) for k, v in obj.items()}
    return obj


def _resolve_teacher_id_scope(current_user: dict, explicit_teacher_id: Optional[str] = None) -> Optional[str]:
    role = str(current_user.get("role", "")).lower()
    if role in ("teacher", "faculty", "instructor"):
        return str(current_user.get("id"))
    return explicit_teacher_id


def _require_permission(current_user: dict, required_perm: str):
    role = str(current_user.get("role", "")).lower()
    if role in (
        "superadmin", "super_admin", "super-admin",
        "admin", "administrator", "director", "principal",
        "school_admin", "school-admin", "teacher_admin", "student_admin",
        "hr", "management"
    ):
        return  # Administrators and school leadership have full bypass
    
    # Check if user has explicit permission array
    user_perms = current_user.get("permissions", [])
    if isinstance(user_perms, list) and (required_perm in user_perms or "*" in user_perms):
        return
        
    # Teacher standard permissions
    if role in ("teacher", "faculty", "instructor") and (
        required_perm in ("attendance.view", "attendance.take", "attendance.edit", "attendance.override_locked", "attendance.staff", "attendance.leave.view", "attendance.leave.approve", "attendance.bulk", "attendance.insights")
    ):
        return
        
    raise HTTPException(
        status_code=403,
        detail=f"Forbidden: You do not possess the required '{required_perm}' permission."
    )


# ============================================================================
# STATS & OVERVIEW ENDPOINTS
# ============================================================================

@router.get("/stats")
async def get_attendance_stats(
    attendance_date: str = Query(..., description="YYYY-MM-DD"),
    class_id: Optional[uuid.UUID] = Query(None),
    section_id: Optional[uuid.UUID] = Query(None),
    teacher_id: Optional[uuid.UUID] = Query(None),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Retrieve dynamic summary cards and day summary for attendance."""
    _require_permission(current_user, "attendance.view")
    scoped_teacher = _resolve_teacher_id_scope(current_user, str(teacher_id) if teacher_id and isinstance(teacher_id, (str, uuid.UUID)) else None)
    c_id = str(class_id) if class_id and isinstance(class_id, (str, uuid.UUID)) else None
    s_id = str(section_id) if section_id and isinstance(section_id, (str, uuid.UUID)) else None

    rows = await exec_sql(
        "SELECT public.fn_get_attendance_dashboard_stats(%s::UUID, %s::DATE, %s::UUID, %s::UUID, %s::UUID) AS result;",
        (school_id, attendance_date, c_id, s_id, scoped_teacher)
    )
    if not rows or not rows[0].get("result"):
        return {"success": True, "data": {"overall_attendance_pct": 0, "total_students": 0, "students_present": 0, "students_absent": 0, "late_entries": 0, "on_leave": 0}}
    return _serialize_val(rows[0]["result"])


# ============================================================================
# STUDENT ATTENDANCE ROSTER & SAVING
# ============================================================================

@router.get("/roster")
async def get_daily_attendance_roster(
    attendance_date: str = Query(..., description="YYYY-MM-DD"),
    class_id: uuid.UUID = Query(...),
    section_id: Optional[uuid.UUID] = Query(None),
    mode: str = Query("ALL_DAY", description="ALL_DAY, PERIOD, MULTI_SCHEDULE"),
    period_number: Optional[int] = Query(None),
    subject_id: Optional[uuid.UUID] = Query(None),
    search: str = Query("", description="Search student name, roll number, admission number"),
    status_filter: str = Query("ALL", description="ALL, PRESENT, ABSENT, LATE, ON_LEAVE, HALF_DAY, NOT_MARKED"),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=200),
    teacher_id: Optional[uuid.UUID] = Query(None),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Retrieve paginated student roster with leave detection, lock status, and last updated info."""
    _require_permission(current_user, "attendance.view")
    scoped_teacher = _resolve_teacher_id_scope(current_user, str(teacher_id) if teacher_id and isinstance(teacher_id, (str, uuid.UUID)) else None)

    search_val = search.strip() if isinstance(search, str) else ""
    status_val = status_filter if isinstance(status_filter, str) else "ALL"
    page_val = int(page) if isinstance(page, int) else 1
    page_size_val = int(page_size) if isinstance(page_size, int) else 10

    rows = await exec_sql(
        "SELECT public.fn_get_daily_attendance_roster(%s::UUID, %s::DATE, %s::UUID, %s::UUID, %s, %s, %s::UUID, %s, %s, %s, %s, %s::UUID) AS result;",
        (
            school_id, attendance_date, str(class_id), str(section_id) if section_id else None,
            mode, period_number, str(subject_id) if subject_id else None,
            search_val, status_val, page_val, page_size_val, scoped_teacher
        )
    )
    if not rows or not rows[0].get("result"):
        return {"success": True, "data": {"students": [], "total_count": 0, "page": page_val, "page_size": page_size_val, "total_pages": 0, "is_locked_all_day": False}}
    return _serialize_val(rows[0]["result"])


@router.post("/save")
async def save_daily_attendance(
    payload: SaveAttendanceRequest,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Save attendance. In ALL_DAY mode, automatically propagates and locks across all day's schedules."""
    _require_permission(current_user, "attendance.take")
    user_id = str(current_user.get("id"))
    
    payload_dict = _serialize_val(payload.dict())
    payload_json = json.dumps(payload_dict, default=str)

    rows = await exec_sql(
        "SELECT public.fn_save_daily_attendance(%s::UUID, %s::UUID, %s::JSONB) AS result;",
        (school_id, user_id, payload_json)
    )
    res = rows[0]["result"] if rows else {"success": False, "error": "Save failed"}
    if not res.get("success"):
        raise HTTPException(status_code=res.get("code", 400), detail=res.get("error", "Failed to save attendance"))
    return _serialize_val(res)


@router.post("/override")
async def override_locked_attendance(
    payload: OverrideAttendanceRequest,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Override a locked or leave-restricted attendance record with mandatory reason via stored procedure."""
    _require_permission(current_user, "attendance.override_locked")
    user_id = str(current_user.get("id"))
    reason_clean = payload.reason.strip()
    if not reason_clean:
        raise HTTPException(status_code=400, detail="An override reason is mandatory")

    rows = await exec_sql(
        "SELECT public.fn_override_locked_attendance(%s::UUID, %s::UUID, %s::UUID, %s, %s, %s) AS result;",
        (school_id, user_id, str(payload.record_id), payload.record_type, payload.new_status, reason_clean)
    )
    res = rows[0]["result"] if rows else {"success": False, "error": "Override failed"}
    if not res.get("success"):
        raise HTTPException(status_code=res.get("code", 400), detail=res.get("error", "Failed to override attendance"))
    return _serialize_val(res)


# ============================================================================
# SCHEDULES & STUDENT ATTENDANCE DETAILS
# ============================================================================

@router.get("/schedules")
async def get_class_schedules_today(
    attendance_date: str = Query(..., description="YYYY-MM-DD"),
    class_id: uuid.UUID = Query(...),
    section_id: Optional[uuid.UUID] = Query(None),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Fetch today's scheduled academic periods from Academic Calendar with class-section-subject offerings."""
    _require_permission(current_user, "attendance.view")

    sec_str = str(section_id) if section_id else None
    rows = await exec_sql(
        "SELECT public.fn_get_class_academic_periods_for_date(%s::UUID, %s::DATE, %s::UUID, %s::UUID) AS result;",
        (school_id, attendance_date, str(class_id), sec_str)
    )
    if not rows or not rows[0].get("result"):
        return {"success": True, "data": {"schedules": [], "count": 0, "source": "empty"}}
    return _serialize_val(rows[0]["result"])


@router.get("/student-detail/{student_id}")
async def get_student_attendance_detail(
    student_id: uuid.UUID,
    attendance_date: str = Query(..., description="YYYY-MM-DD"),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Retrieve in-depth student attendance details for side drawer/modal."""
    _require_permission(current_user, "attendance.view")

    # Fetch Student Profile
    profile_rows = await exec_sql(
        """
        SELECT p.id, p.full_name, p.email, p.avatar_url, p.admission_number, sca.roll_number,
               c.id as class_id, c.name as class_name, s.id as section_id, s.name as section_name
        FROM public.profiles p
        LEFT JOIN public.student_class_assignments sca ON sca.student_id = p.id AND sca.status = 'ACTIVE'
        LEFT JOIN public.academic_classes c ON c.id = sca.class_id
        LEFT JOIN public.academic_sections s ON s.id = sca.section_id
        WHERE p.id = %s::UUID AND p.school_id = %s::UUID;
        """,
        (str(student_id), school_id)
    )
    if not profile_rows:
        raise HTTPException(status_code=404, detail="Student not found")
    student = profile_rows[0]

    # Today's Master Attendance
    daily_rows = await exec_sql(
        """
        SELECT status, remarks, is_locked, is_overridden, override_reason, updated_at
        FROM public.attendance_daily_records
        WHERE school_id = %s::UUID AND student_id = %s::UUID AND attendance_date = %s::DATE;
        """,
        (school_id, str(student_id), attendance_date)
    )
    today_status = daily_rows[0].get("status") if daily_rows else "NOT_MARKED"
    today_remarks = daily_rows[0].get("remarks") if daily_rows else ""

    # Today's Period Attendance Matrix
    period_rows = await exec_sql(
        """
        SELECT apr.period_number, apr.status, apr.remarks, apr.is_locked, sub.name as subject_name, sub.color as subject_color
        FROM public.attendance_period_records apr
        LEFT JOIN public.academic_subjects sub ON sub.id = apr.subject_id
        WHERE apr.school_id = %s::UUID AND apr.student_id = %s::UUID AND apr.attendance_date = %s::DATE
        ORDER BY apr.period_number ASC;
        """,
        (school_id, str(student_id), attendance_date)
    )

    # Monthly Attendance Stats (Past 30 days)
    stats_rows = await exec_sql(
        """
        SELECT 
            COUNT(*) as total_days,
            COUNT(CASE WHEN UPPER(status) = 'PRESENT' THEN 1 END) as present_days,
            COUNT(CASE WHEN UPPER(status) = 'ABSENT' THEN 1 END) as absent_days,
            COUNT(CASE WHEN UPPER(status) = 'LATE' THEN 1 END) as late_days,
            COUNT(CASE WHEN UPPER(status) = 'ON_LEAVE' THEN 1 END) as leave_days
        FROM public.attendance_daily_records
        WHERE school_id = %s::UUID AND student_id = %s::UUID AND attendance_date >= (%s::DATE - INTERVAL '30 days');
        """,
        (school_id, str(student_id), attendance_date)
    )
    st = stats_rows[0] if stats_rows else {}
    tot = int(st.get("total_days") or 0)
    pres = int(st.get("present_days") or 0)
    ab = int(st.get("absent_days") or 0)
    lt = int(st.get("late_days") or 0)
    lv = int(st.get("leave_days") or 0)
    pct = round((float(pres + lt) / max(tot, 1)) * 100.0, 1) if tot > 0 else 0.0

    return {
        "success": True,
        "data": {
            "profile": _serialize_val(student),
            "today": {
                "status": today_status,
                "remarks": today_remarks,
                "periods": _serialize_val(period_rows)
            },
            "monthly_metrics": {
                "total_days": tot,
                "present_days": pres,
                "absent_days": ab,
                "late_days": lt,
                "leave_days": lv,
                "attendance_percentage": pct
            }
        }
    }


# ============================================================================
# STAFF ATTENDANCE & MANAGER HIERARCHY
# ============================================================================

@router.get("/manager-status",
    summary="Get Manager Status for Current User",
    description="Returns whether the logged-in user is a reporting manager for any staff/users and their direct reports count."
)
async def get_manager_status(
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Check if the current authenticated user has direct reports or leadership roles."""
    user_id = str(current_user.get("id"))
    user_role = str(current_user.get("role", "")).lower()

    # Count how many users report to this user
    rows = await exec_sql(
        "SELECT COUNT(*)::INT AS direct_reports_count FROM public.profiles WHERE manager_id = %s::UUID;",
        (user_id,)
    )
    direct_reports_count = rows[0]["direct_reports_count"] if rows else 0

    # User is a manager if they have direct reports > 0 OR if super_admin / admin
    is_leadership = user_role in ("super_admin", "admin")
    is_manager = (direct_reports_count > 0) or is_leadership

    return {
        "success": True,
        "data": {
            "is_manager": is_manager,
            "direct_reports_count": direct_reports_count,
            "role": user_role,
            "is_leadership": is_leadership,
            "user_id": user_id
        }
    }


@router.get("/staff")
async def get_staff_attendance(
    attendance_date: str = Query(..., description="YYYY-MM-DD"),
    department: str = Query("ALL"),
    role: str = Query("ALL"),
    status: str = Query("ALL"),
    search: str = Query(""),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    manager_id: Optional[uuid.UUID] = Query(None),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Retrieve staff attendance roster with department filtering and manager hierarchy."""
    _require_permission(current_user, "attendance.staff")
    
    # If user is a manager (not admin/super_admin), strictly enforce their own manager scope
    user_role = str(current_user.get("role", "")).lower()
    user_id = str(current_user.get("id"))
    scoped_manager = str(manager_id) if (user_role in ("super_admin", "admin") and manager_id) else (None if user_role in ("super_admin", "admin") else user_id)

    rows = await exec_sql(
        "SELECT public.fn_get_staff_attendance_roster(%s::UUID, %s::DATE, %s, %s, %s, %s, %s, %s, %s::UUID) AS result;",
        (school_id, attendance_date, department, role, status, search.strip(), page, page_size, scoped_manager)
    )
    if not rows or not rows[0].get("result"):
        return {"success": True, "data": {"staff": [], "total_count": 0, "page": page, "page_size": page_size, "total_pages": 0}}
    return _serialize_val(rows[0]["result"])


@router.post("/staff/save")
async def save_staff_attendance(
    payload: SaveStaffAttendanceRequest,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Save staff/employee attendance."""
    _require_permission(current_user, "attendance.staff")
    user_id = str(current_user.get("id"))

    payload_dict = _serialize_val(payload.dict())
    payload_json = json.dumps(payload_dict, default=str)

    rows = await exec_sql(
        "SELECT public.fn_save_staff_attendance(%s::UUID, %s::UUID, %s::JSONB) AS result;",
        (school_id, user_id, payload_json)
    )
    res = rows[0]["result"] if rows else {"success": False, "error": "Save staff attendance failed"}
    if not res.get("success"):
        raise HTTPException(status_code=res.get("code", 400), detail=res.get("error", "Failed to save staff attendance"))
    return _serialize_val(res)


# ============================================================================
# LEAVE & PERMISSIONS INTEGRATION
# ============================================================================

@router.get("/leave-requests")
async def get_leave_requests(
    status: str = Query("ALL", description="ALL, pending, approved, rejected, cancelled"),
    role: str = Query("ALL", description="ALL, student, teacher, staff"),
    manager_id: Optional[uuid.UUID] = Query(None),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """List leave requests for attendance integration. Non-admins only see leave requests from their direct reports."""
    _require_permission(current_user, "attendance.leave.view")

    user_role = str(current_user.get("role", "")).lower()
    user_id = str(current_user.get("id"))
    scoped_manager = str(manager_id) if (user_role in ("super_admin", "admin") and manager_id) else (None if user_role in ("super_admin", "admin") else user_id)

    manager_clause = "AND p.manager_id = %s::UUID" if scoped_manager else ""
    query_params = [school_id, status, status, role, role]
    if scoped_manager:
        query_params.append(scoped_manager)

    query = f"""
        SELECT la.id, la.applicant_id, p.full_name as applicant_name, p.avatar_url, la.applicant_role,
               la.leave_type, la.start_date, la.end_date, la.reason, la.status, la.remarks,
               la.created_at, ap.full_name as approved_by_name,
               (la.end_date - la.start_date + 1) as days_count
        FROM public.leave_applications la
        JOIN public.profiles p ON p.id = la.applicant_id
        LEFT JOIN public.profiles ap ON ap.id = la.approved_by
        WHERE (la.school_id = %s::UUID OR la.school_id IS NULL)
          AND (LOWER(%s) = 'all' OR LOWER(la.status) = LOWER(%s))
          AND (LOWER(%s) = 'all' OR LOWER(COALESCE(la.applicant_role, p.role)) = LOWER(%s))
          {manager_clause}
        ORDER BY la.created_at DESC;
    """
    rows = await exec_sql(query, tuple(query_params))
    return {"success": True, "data": {"leave_requests": _serialize_val(rows), "count": len(rows)}}


@router.post("/leave-requests/{leave_id}/action")
async def handle_leave_request_action(
    leave_id: uuid.UUID,
    payload: LeaveActionRequest,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Approve or Reject leave application with automatic attendance synchronization."""
    _require_permission(current_user, "attendance.leave.approve")
    user_id = str(current_user.get("id"))
    act = payload.action.upper()
    new_status = "approved" if act == "APPROVE" else ("rejected" if act == "REJECT" else "cancelled")

    # Update Leave Application
    rows = await exec_sql(
        """
        UPDATE public.leave_applications SET
            status = %s,
            approved_by = (SELECT id FROM public.profiles WHERE id = %s::UUID),
            approved_at = NOW(),
            remarks = %s,
            updated_at = NOW()
        WHERE id = %s::UUID AND (school_id = %s::UUID OR school_id IS NULL)
        RETURNING *;
        """,
        (new_status, user_id, payload.remarks, str(leave_id), school_id)
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Leave request not found")

    leave_rec = rows[0]

    # If Approved, Automatically Mark Attendance as ON_LEAVE for all dates in leave period
    if new_status == "approved":
        applicant_id = str(leave_rec.get("applicant_id"))
        start_d = leave_rec.get("start_date")
        end_d = leave_rec.get("end_date")
        rec_school_id = str(leave_rec.get("school_id") or school_id)

        # Retrieve student's class and section if assigned
        class_sec_rows = await exec_sql(
            """
            SELECT class_id, section_id FROM public.student_class_assignments
            WHERE student_id = %s::UUID AND school_id = %s::UUID
            LIMIT 1;
            """,
            (applicant_id, rec_school_id)
        )
        c_id = str(class_sec_rows[0]["class_id"]) if class_sec_rows and class_sec_rows[0].get("class_id") else None
        s_id = str(class_sec_rows[0]["section_id"]) if class_sec_rows and class_sec_rows[0].get("section_id") else None

        await exec_sql(
            """
            INSERT INTO public.attendance_daily_records (
                school_id, student_id, class_id, section_id, attendance_date, status, remarks, is_locked, is_all_day, created_by, updated_by
            )
            SELECT %s::UUID, %s::UUID, %s::UUID, %s::UUID, d.dt::DATE, 'ON_LEAVE', %s, TRUE, TRUE,
                   (SELECT id FROM public.profiles WHERE id = %s::UUID),
                   (SELECT id FROM public.profiles WHERE id = %s::UUID)
            FROM generate_series(%s::DATE, %s::DATE, INTERVAL '1 day') AS d(dt)
            ON CONFLICT (school_id, student_id, attendance_date) DO UPDATE SET
                status = 'ON_LEAVE',
                remarks = EXCLUDED.remarks,
                is_locked = TRUE,
                updated_by = EXCLUDED.updated_by,
                updated_at = NOW();
            """,
            (rec_school_id, applicant_id, c_id, s_id, f"Approved Leave: {leave_rec.get('reason') or 'Approved'}", user_id, user_id, start_d, end_d)
        )

    return {"success": True, "message": f"Leave request {new_status} successfully"}


# ============================================================================
# BULK OPERATIONS & CSV EXPORT
# ============================================================================

@router.post("/bulk")
async def execute_bulk_attendance_operation(
    payload: BulkAttendanceOperationRequest,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Execute bulk attendance actions (Mark All Present/Absent, Lock/Unlock) with audit tracking."""
    _require_permission(current_user, "attendance.bulk")
    user_id = str(current_user.get("id"))
    sec_str = str(payload.section_id) if payload.section_id else None

    op = payload.operation.upper()
    count = 0

    if op in ("PRESENT", "ABSENT", "LATE", "HALF_DAY"):
        st = op
        for s_id in payload.student_ids:
            await exec_sql(
                """
                INSERT INTO public.attendance_daily_records (
                    school_id, student_id, class_id, section_id, attendance_date, status, remarks, created_by, updated_by
                ) VALUES (
                    %s::UUID, %s::UUID, %s::UUID, %s::UUID, %s::DATE, %s, %s,
                    (SELECT id FROM public.profiles WHERE id = %s::UUID),
                    (SELECT id FROM public.profiles WHERE id = %s::UUID)
                )
                ON CONFLICT (school_id, student_id, attendance_date) DO UPDATE SET
                    status = EXCLUDED.status,
                    remarks = COALESCE(EXCLUDED.remarks, public.attendance_daily_records.remarks),
                    updated_by = EXCLUDED.updated_by,
                    updated_at = NOW();
                """,
                (school_id, str(s_id), str(payload.class_id), sec_str, payload.attendance_date, st, payload.remarks or "", user_id, user_id)
            )
            count += 1

    elif op in ("LOCK", "UNLOCK"):
        lock_val = (op == "LOCK")
        for s_id in payload.student_ids:
            await exec_sql(
                """
                UPDATE public.attendance_daily_records SET
                    is_locked = %s,
                    locked_by = (SELECT id FROM public.profiles WHERE id = %s::UUID),
                    locked_at = NOW(),
                    updated_by = (SELECT id FROM public.profiles WHERE id = %s::UUID),
                    updated_at = NOW()
                WHERE school_id = %s::UUID AND student_id = %s::UUID AND attendance_date = %s::DATE;
                """,
                (lock_val, user_id, user_id, school_id, str(s_id), payload.attendance_date)
            )
            count += 1

    # Record Audit
    await exec_sql(
        """
        INSERT INTO public.attendance_audit_logs (school_id, record_type, user_id, action, new_value, reason)
        VALUES (%s::UUID, 'BULK', (SELECT id FROM public.profiles WHERE id = %s::UUID), %s, %s::JSONB, %s);
        """,
        (school_id, user_id, op, json.dumps({"count": count, "date": payload.attendance_date}), payload.reason or "Bulk attendance update")
    )

    return {"success": True, "message": f"Bulk operation '{op}' executed successfully for {count} students", "processed_count": count}


@router.get("/export")
async def export_attendance_csv(
    attendance_date: str = Query(..., description="YYYY-MM-DD"),
    class_id: uuid.UUID = Query(...),
    section_id: Optional[uuid.UUID] = Query(None),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Export attendance roster as a CSV file."""
    _require_permission(current_user, "attendance.export")

    sec_str = str(section_id) if section_id else None
    rows = await exec_sql(
        """
        SELECT sca.roll_number, p.admission_number, p.full_name, c.name as class_name, s.name as section_name,
               COALESCE(adr.status, 'NOT_MARKED') as status, COALESCE(adr.remarks, '') as remarks,
               adr.updated_at
        FROM public.student_class_assignments sca
        JOIN public.profiles p ON p.id = sca.student_id
        LEFT JOIN public.academic_classes c ON c.id = sca.class_id
        LEFT JOIN public.academic_sections s ON s.id = sca.section_id
        LEFT JOIN public.attendance_daily_records adr ON adr.student_id = p.id AND adr.attendance_date = %s::DATE AND adr.school_id = %s::UUID
        WHERE sca.school_id = %s::UUID AND sca.class_id = %s::UUID AND (%s::UUID IS NULL OR sca.section_id = %s::UUID)
        ORDER BY sca.roll_number ASC, p.full_name ASC;
        """,
        (attendance_date, school_id, school_id, str(class_id), sec_str, sec_str)
    )

    csv_lines = ["Roll No,Admission No,Student Name,Class,Section,Date,Status,Remarks"]
    for r in rows:
        csv_lines.append(
            f'"{r.get("roll_number", "")}","{r.get("admission_number", "")}","{r.get("full_name", "")}",'
            f'"{r.get("class_name", "")}","{r.get("section_name", "")}","{attendance_date}",'
            f'"{r.get("status", "NOT_MARKED")}","{r.get("remarks", "")}"'
        )

    csv_content = "\n".join(csv_lines)
    return Response(
        content=csv_content,
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename=attendance_{attendance_date}.csv"}
    )


# ============================================================================
# INSIGHTS, SETTINGS & AUDIT
# ============================================================================

@router.get("/insights")
async def get_attendance_insights(
    start_date: str = Query(..., description="YYYY-MM-DD"),
    end_date: str = Query(..., description="YYYY-MM-DD"),
    class_id: Optional[uuid.UUID] = Query(None),
    section_id: Optional[uuid.UUID] = Query(None),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Retrieve analytical insights, trends, class comparisons, and at-risk students (<75%)."""
    _require_permission(current_user, "attendance.report")

    rows = await exec_sql(
        "SELECT public.fn_get_attendance_insights(%s::UUID, %s::DATE, %s::DATE, %s::UUID, %s::UUID) AS result;",
        (school_id, start_date, end_date, str(class_id) if class_id else None, str(section_id) if section_id else None)
    )
    if not rows or not rows[0].get("result"):
        return {"success": True, "data": {"daily_trend": [], "at_risk_students": [], "at_risk_count": 0, "class_comparison": []}}
    return _serialize_val(rows[0]["result"])


@router.get("/settings")
async def get_attendance_settings(
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Retrieve school attendance configuration rules."""
    _require_permission(current_user, "attendance.view")

    rows = await exec_sql("SELECT public.fn_get_attendance_settings(%s::UUID) AS result;", (school_id,))
    if not rows or not rows[0].get("result"):
        return {"success": True, "data": {}}
    return _serialize_val(rows[0]["result"])


@router.put("/settings")
async def update_attendance_settings(
    payload: AttendanceSettingsUpdateRequest,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Update school attendance configuration rules."""
    _require_permission(current_user, "attendance.settings")
    user_id = str(current_user.get("id"))
    payload_dict = _serialize_val({k: v for k, v in payload.dict().items() if v is not None})
    payload_json = json.dumps(payload_dict, default=str)

    rows = await exec_sql(
        "SELECT public.fn_update_attendance_settings(%s::UUID, %s::UUID, %s::JSONB) AS result;",
        (school_id, user_id, payload_json)
    )
    res = rows[0]["result"] if rows else {"success": False, "error": "Update settings failed"}
    if not res.get("success"):
        raise HTTPException(status_code=res.get("code", 400), detail=res.get("error", "Failed to update settings"))
    return _serialize_val(res)


@router.get("/audit")
async def get_attendance_audit_logs(
    limit: int = Query(25, ge=1, le=100),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Retrieve audit history logs for attendance changes and overrides."""
    _require_permission(current_user, "attendance.audit")

    rows = await exec_sql(
        """
        SELECT a.id, a.record_type, a.record_id, a.action, a.old_value, a.new_value, a.reason,
               a.created_at, p.full_name as user_name, p.avatar_url as user_avatar, p.role as user_role
        FROM public.attendance_audit_logs a
        LEFT JOIN public.profiles p ON p.id = a.user_id
        WHERE a.school_id = %s::UUID
        ORDER BY a.created_at DESC
        LIMIT %s;
        """,
        (school_id, limit)
    )
    return {"success": True, "data": {"audit_logs": _serialize_val(rows), "count": len(rows)}}
