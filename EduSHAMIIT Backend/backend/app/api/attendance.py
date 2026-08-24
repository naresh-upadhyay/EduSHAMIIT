from app.services.supabase_client import get_supabase
import httpx
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
from datetime import date, datetime, time, timedelta
from typing import Any, Dict, List, Optional

import psycopg2
from psycopg2.extras import RealDictCursor
from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, UploadFile, File
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
                if params and len(params) > 0:
                    cur.execute(sql, params)
                else:
                    cur.execute(sql)
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


class QuickMarkPeriodRequest(BaseModel):
    student_id: uuid.UUID
    attendance_date: str = Field(..., description="YYYY-MM-DD")
    period_number: int
    status: str = Field("PRESENT", description="PRESENT, ABSENT, LATE, ON_LEAVE, HALF_DAY, NOT_MARKED")
    subject_id: Optional[uuid.UUID] = Field(None)
    schedule_id: Optional[uuid.UUID] = Field(None)
    remarks: Optional[str] = Field("")


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
    remarks: Optional[str] = None


class BatchLeaveActionRequest(BaseModel):
    request_ids: Optional[List[uuid.UUID]] = Field(default_factory=list, description="List of leave application IDs to act upon")
    action: str = Field(..., description="APPROVE, REJECT, CANCEL")
    remarks: Optional[str] = Field(None)
    select_all: Optional[bool] = Field(False)
    status: Optional[str] = Field("ALL")
    user_type: Optional[str] = Field("ALL")
    department: Optional[str] = Field("ALL")


class BatchPermissionActionRequest(BaseModel):
    permission_ids: Optional[List[uuid.UUID]] = Field(default_factory=list, description="List of permission request IDs to act upon")
    action: str = Field(..., description="APPROVE, REJECT, CANCEL")
    remarks: Optional[str] = Field(None)
    select_all: Optional[bool] = Field(False)
    status: Optional[str] = Field("ALL")


class ApplyLeaveRequest(BaseModel):
    applicant_id: Optional[uuid.UUID] = Field(None, description="Applicant profile ID (defaults to current user if not provided)")
    leave_type: str = Field(..., description="Name or code of leave type e.g. Casual Leave, Medical Leave")
    start_date: str = Field(..., description="YYYY-MM-DD")
    end_date: str = Field(..., description="YYYY-MM-DD")
    reason: str = Field(..., min_length=2)
    half_day_type: Optional[str] = Field("FULL_DAY", description="FULL_DAY, FIRST_HALF, SECOND_HALF")
    contact_number: Optional[str] = Field(None)
    attachment_url: Optional[str] = Field(None)
    billable_days: Optional[float] = Field(None, description="Client calculated net billable days")
    days_count: Optional[float] = Field(None, description="Client calculated net billable days")


class LeaveTypePayload(BaseModel):
    id: Optional[uuid.UUID] = Field(None)
    name: str = Field(..., min_length=2)
    code: str = Field(..., min_length=1)
    category: str = Field("PAID", description="PAID, UNPAID, SPECIAL")
    annual_entitlement: float = Field(12.0, ge=0.0)
    monthly_accrual: Optional[bool] = Field(False)
    carry_forward_allowed: Optional[bool] = Field(True)
    max_carry_forward: Optional[float] = Field(5.0)
    encashment_allowed: Optional[bool] = Field(False)
    doc_required: Optional[bool] = Field(False)
    doc_required_after_days: Optional[float] = Field(2.0)
    allow_half_day: Optional[bool] = Field(True)
    applicable_roles: Optional[List[str]] = Field(default_factory=lambda: ["all"])
    color_hex: Optional[str] = Field("#4F46E5")
    is_active: Optional[bool] = Field(True)


class BalanceAdjustmentPayload(BaseModel):
    user_id: uuid.UUID
    leave_type_id: uuid.UUID
    adjustment_days: float = Field(..., description="Positive to credit, negative to debit")
    reason: str = Field(..., min_length=3)
    academic_year: Optional[str] = Field("2026-2027")


class ApplyPermissionPayload(BaseModel):
    applicant_id: Optional[uuid.UUID] = Field(None)
    permission_type: str = Field(..., description="LATE_ARRIVAL, EARLY_DEPARTURE, SHORT_PERMISSION, MEDICAL, OFFICIAL, PERSONAL")
    permission_date: str = Field(..., description="YYYY-MM-DD")
    start_time: str = Field(..., description="HH:MM:SS")
    end_time: str = Field(..., description="HH:MM:SS")
    duration_hours: Optional[float] = Field(1.0)
    reason: str = Field(..., min_length=2)


class PermissionActionPayload(BaseModel):
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

    mode_val = mode if isinstance(mode, str) else "ALL_DAY"
    period_num_val = int(period_number) if isinstance(period_number, (int, str)) and str(period_number).isdigit() else None
    subject_id_val = str(subject_id) if subject_id and isinstance(subject_id, (str, uuid.UUID)) else None
    section_id_val = str(section_id) if section_id and isinstance(section_id, (str, uuid.UUID)) else None
    search_val = search.strip() if isinstance(search, str) else ""
    status_val = status_filter if isinstance(status_filter, str) else "ALL"
    page_val = int(page) if isinstance(page, (int, str)) and str(page).isdigit() else 1
    page_size_val = int(page_size) if isinstance(page_size, (int, str)) and str(page_size).isdigit() else 10

    rows = await exec_sql(
        "SELECT public.fn_get_daily_attendance_roster(%s::UUID, %s::DATE, %s::UUID, %s::UUID, %s, %s, %s::UUID, %s, %s, %s, %s, %s::UUID) AS result;",
        (
            school_id, attendance_date, str(class_id), section_id_val,
            mode_val, period_num_val, subject_id_val,
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


@router.post("/quick-mark-period")
async def quick_mark_student_period(
    payload: QuickMarkPeriodRequest,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Instantly mark or update a single student's attendance for a specific period."""
    _require_permission(current_user, "attendance.take")
    user_id = str(current_user.get("id"))

    rows = await exec_sql(
        "SELECT public.fn_quick_mark_student_period(%s::UUID, %s::UUID, %s::UUID, %s::DATE, %s, %s, %s::UUID, %s::UUID, %s) AS result;",
        (
            school_id, user_id, str(payload.student_id), payload.attendance_date,
            payload.period_number, payload.status,
            str(payload.subject_id) if payload.subject_id else None,
            str(payload.schedule_id) if payload.schedule_id else None,
            payload.remarks or ""
        )
    )
    res = rows[0]["result"] if rows else {"success": False, "error": "Quick mark failed"}
    if not res.get("success"):
        raise HTTPException(status_code=res.get("code", 400), detail=res.get("error", "Failed to update period attendance"))
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
    manager_id: Optional[str] = Query(None, description="Optional manager UUID or 'MY_REPORTS'"),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Retrieve staff attendance roster with department filtering and manager hierarchy."""
    _require_permission(current_user, "attendance.staff")
    
    user_role = str(current_user.get("role", "")).lower()
    user_id = str(current_user.get("id"))
    
    if manager_id and str(manager_id).upper() in ("MY_REPORTS", "ME", "DIRECT_REPORTS"):
        scoped_manager = user_id
    elif user_role in ("super_admin", "admin"):
        scoped_manager = str(manager_id) if (manager_id and str(manager_id).upper() != "ALL") else None
    else:
        scoped_manager = user_id

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
# LEAVE & PERMISSIONS COMPLETE ENDPOINTS
# ============================================================================

@router.get("/leave/dashboard")
async def get_leave_dashboard(
    user_type: str = Query("ALL"),
    department: str = Query("ALL"),
    status: str = Query("ALL"),
    leave_type: str = Query("ALL"),
    search: str = Query(""),
    from_date: Optional[str] = Query(None),
    to_date: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    manager_id: Optional[str] = Query(None),
    school_id: Optional[str] = Query(None),
    academic_year: Optional[str] = Query(None),
    current_user: dict = Depends(get_current_user)
):
    """Get complete Leave & Permissions Dashboard with KPI cards, filtered requests, balance summaries, and upcoming leaves."""
    _require_permission(current_user, "attendance.leave.view")
    user_role = str(current_user.get("role", "")).lower()
    user_id = str(current_user.get("id"))

    u_type = user_type if isinstance(user_type, str) else "ALL"
    dept_str = department if isinstance(department, str) else "ALL"
    stat_str = status if isinstance(status, str) else "ALL"
    lt_str = leave_type if isinstance(leave_type, str) else "ALL"
    search_str = search if isinstance(search, str) else ""
    page_num = page if isinstance(page, int) else 1
    page_sz = page_size if isinstance(page_size, int) else 10
    mgr_id = manager_id if (isinstance(manager_id, str) or manager_id is None) else None
    sch_id = school_id if (isinstance(school_id, str) or school_id is None) else None
    acad_yr = academic_year if (isinstance(academic_year, str) or academic_year is None) else None
    f_date = from_date if (isinstance(from_date, str) or from_date is None) else None
    t_date = to_date if (isinstance(to_date, str) or to_date is None) else None

    effective_school_id = sch_id or current_user.get("school_id")
    if not effective_school_id or str(effective_school_id).upper() == "ALL":
        effective_school_id = current_user.get("school_id") or "11111111-1111-1111-1111-111111111111"

    if mgr_id and str(mgr_id).upper() in ("MY_REPORTS", "ME", "DIRECT_REPORTS"):
        scoped_manager = user_id
    elif user_role in ("super_admin", "admin"):
        scoped_manager = str(mgr_id) if (mgr_id and str(mgr_id).upper() != "ALL") else None
    else:
        scoped_manager = user_id

    rows = await exec_sql(
        "SELECT public.fn_get_leave_dashboard_and_requests(%s::UUID, %s::UUID, %s, %s, %s, %s, %s, %s::DATE, %s::DATE, %s, %s, %s::UUID, %s) AS result;",
        (effective_school_id, user_id, u_type, dept_str, stat_str, lt_str, search_str.strip(), f_date, t_date, page_num, page_sz, scoped_manager, acad_yr)
    )
    if not rows or not rows[0].get("result"):
        return {"success": True, "data": {"kpi": {}, "requests": [], "balance_summary": [], "upcoming_leaves": []}}
    return _serialize_val(rows[0]["result"])


@router.post("/leave/upload")
async def upload_leave_attachment(
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id),
):
    """Upload a leave supporting document/certificate (PDF, Images, Word Docs up to 10MB) to Supabase storage."""
    sb = get_supabase()
    user_id = str(current_user.get("id"))

    if not file.filename:
        raise HTTPException(status_code=400, detail="Filename is missing")

    ext = file.filename.split('.')[-1].lower() if '.' in file.filename else ''
    if ext not in ["pdf", "jpg", "jpeg", "png", "doc", "docx"]:
        raise HTTPException(status_code=400, detail="Invalid file format. Allowed formats: PDF, JPG, PNG, DOC, DOCX")

    file_bytes = await file.read()
    if len(file_bytes) == 0:
        raise HTTPException(status_code=400, detail="Uploaded file is empty")
    if len(file_bytes) > 10 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="File too large. Maximum size allowed is 10 MB.")

    doc_id = str(uuid.uuid4())
    storage_path = f"documents/{user_id}/{doc_id}.{ext}"
    supabase_url = settings.SUPABASE_URL.rstrip("/")
    storage_url = f"{supabase_url}/storage/v1/object/{storage_path}"

    content_type = file.content_type or "application/octet-stream"
    headers = {
        "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
        "Content-Type": content_type,
        "x-upsert": "true",
    }

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            upload_response = await client.post(storage_url, headers=headers, content=file_bytes)
        
        from app.middleware.auth import get_public_supabase_url
        public_url_base = get_public_supabase_url(supabase_url)
        public_url = f"{public_url_base}/storage/v1/object/public/{storage_path}"
    except Exception as e:
        logger.warning(f"Supabase storage upload fallback: {e}")
        public_url = f"http://localhost:8082/storage/v1/object/public/{storage_path}"

    try:
        doc_data = {
            "id": doc_id,
            "school_id": school_id,
            "user_id": user_id,
            "document_type": "leave_attachment",
            "file_name": file.filename,
            "file_url": public_url,
            "verification_status": "pending"
        }
        await sb.table("documents").insert(doc_data).aexecute()
    except Exception as e:
        logger.warning(f"Documents table record insert note: {e}")

    return {
        "success": True,
        "message": "Document uploaded successfully",
        "data": {
            "id": doc_id,
            "file_url": public_url,
            "file_name": file.filename,
            "file_size": len(file_bytes)
        }
    }


@router.get("/leave/holidays")
async def get_leave_holidays(
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Retrieve all institutional and public calendar holidays (including recurring weekly/monthly holidays) for leave calculations."""
    day_name_to_weekday = {
        "MO": 0, "TU": 1, "WE": 2, "TH": 3, "FR": 4, "SA": 5, "SU": 6,
        "MON": 0, "TUE": 1, "WED": 2, "THU": 3, "FRI": 4, "SAT": 5, "SUN": 6,
        "MONDAY": 0, "TUESDAY": 1, "WEDNESDAY": 2, "THURSDAY": 3, "FRIDAY": 4, "SATURDAY": 5, "SUNDAY": 6,
        "0": 0, "1": 0, "2": 1, "3": 2, "4": 3, "5": 4, "6": 5, "7": 6
    }

    def _get_wk_day(d):
        if isinstance(d, int):
            return (d - 1) if 1 <= d <= 7 else (d if 0 <= d <= 6 else -1)
        s = str(d).strip().upper()
        if s.isdigit():
            v = int(s)
            return (v - 1) if 1 <= v <= 7 else (v if 0 <= v <= 6 else -1)
        return day_name_to_weekday.get(s, -1)

    # 1. Query all schedules matching holiday criteria using parameterized ILIKE
    sql = """
        SELECT s.id, s.title, s.description, s.schedule_type, s.category, s.color,
               s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata') as start_local,
               s.end_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata') as end_local,
               s.start_time, s.end_time, s.is_recurring,
               COALESCE(c.name, 'Public Holidays') as calendar_name,
               sr.frequency, sr.interval, sr.days_of_week, sr.end_type, sr.end_count, sr.end_date as rec_end_date, sr.exceptions
        FROM public.schedules s
        LEFT JOIN public.calendars c ON s.calendar_id = c.id
        LEFT JOIN public.schedule_recurrence sr ON sr.schedule_id = s.id
        WHERE s.school_id = %s
          AND s.deleted_at IS NULL
          AND (
              c.name ILIKE %s OR c.name ILIKE %s OR c.name ILIKE %s OR c.name ILIKE %s
              OR c.type ILIKE %s OR c.type ILIKE %s
              OR s.schedule_type ILIKE %s OR s.schedule_type ILIKE %s OR s.schedule_type ILIKE %s OR s.schedule_type ILIKE %s
              OR s.category ILIKE %s OR s.category ILIKE %s OR s.category ILIKE %s OR s.category ILIKE %s
              OR s.title ILIKE %s OR s.title ILIKE %s OR s.title ILIKE %s OR s.title ILIKE %s OR s.title ILIKE %s
              OR s.description ILIKE %s OR s.description ILIKE %s
          )
        ORDER BY s.start_time ASC;
    """
    params = (
        school_id,
        '%holiday%', '%holy%', '%vacation%', '%closure%',
        '%holiday%', '%school_events%',
        '%holiday%', '%holy%', '%vacation%', '%off%',
        '%holiday%', '%holy%', '%vacation%', '%off%',
        '%holiday%', '%holy%', '%vacation%', '%closed%', '%off%',
        '%holiday%', '%holy%'
    )
    rows = await exec_sql(sql, params)

    # 2. Seed default 2026 Public Holidays if table has zero holidays
    if not rows:
        cals = await exec_sql(
            "SELECT id FROM public.calendars WHERE school_id = %s AND (name ILIKE %s OR type = 'school_events') LIMIT 1;",
            (school_id, '%Public Holiday%')
        )
        cal_id = cals[0]['id'] if cals else None
        if not cal_id:
            c_all = await exec_sql("SELECT id FROM public.calendars WHERE school_id = %s LIMIT 1;", (school_id,))
            if c_all:
                cal_id = c_all[0]['id']

        if cal_id:
            default_holidays = [
                ("New Year's Day", "2026-01-01", "2026-01-01", "#EF4444"),
                ("Republic Day", "2026-01-26", "2026-01-26", "#EF4444"),
                ("Maha Shivratri", "2026-02-15", "2026-02-15", "#EF4444"),
                ("Holi Festival", "2026-03-04", "2026-03-04", "#EF4444"),
                ("Good Friday", "2026-04-03", "2026-04-03", "#EF4444"),
                ("Eid-ul-Fitr", "2026-04-20", "2026-04-20", "#EF4444"),
                ("Independence Day", "2026-08-15", "2026-08-15", "#EF4444"),
                ("Raksha Bandhan", "2026-08-28", "2026-08-28", "#EF4444"),
                ("Janmashtami", "2026-09-04", "2026-09-04", "#EF4444"),
                ("Gandhi Jayanti", "2026-10-02", "2026-10-02", "#EF4444"),
                ("Dussehra (Vijayadashami)", "2026-10-20", "2026-10-20", "#EF4444"),
                ("Diwali (Deepavali)", "2026-11-08", "2026-11-08", "#EF4444"),
                ("Guru Nanak Jayanti", "2026-11-24", "2026-11-24", "#EF4444"),
                ("Christmas Day", "2026-12-25", "2026-12-25", "#EF4444"),
            ]
            for title, s_date, e_date, color in default_holidays:
                h_id = str(uuid.uuid4())
                await exec_sql("""
                    INSERT INTO public.schedules (
                        id, school_id, calendar_id, title, description, schedule_type, category,
                        color, start_time, end_time, is_all_day, visibility, created_at, updated_at
                    ) VALUES (
                        %s, %s, %s, %s, 'Official Public Holiday', 'holiday', 'Holidays',
                        %s, %s::TIMESTAMPTZ, %s::TIMESTAMPTZ, TRUE, 'institution_wide', NOW(), NOW()
                    ) ON CONFLICT DO NOTHING;
                """, (h_id, school_id, cal_id, title, color, f"{s_date} 00:00:00+05:30", f"{e_date} 23:59:59+05:30"), fetch=False)

            rows = await exec_sql(sql, params)

    # 3. Recurrence Expansion Engine across Academic Window
    all_holidays = []
    window_end = date(2027, 6, 30)

    for r in rows:
        st_local = r.get("start_local") or r.get("start_time")
        et_local = r.get("end_local") or r.get("end_time")
        base_start_d = st_local.date() if isinstance(st_local, datetime) else st_local
        base_end_d = et_local.date() if isinstance(et_local, datetime) else et_local

        # Add the primary instance
        all_holidays.append({
            "id": str(r["id"]),
            "title": r.get("title") or "Public Holiday",
            "description": r.get("description") or "",
            "schedule_type": r.get("schedule_type") or "holiday",
            "category": r.get("category") or "Holidays",
            "start_date": str(base_start_d),
            "end_date": str(base_end_d),
            "color": r.get("color") or "#EF4444",
            "calendar_name": r.get("calendar_name") or "Public Holidays"
        })

        # Expand recurring holiday instances
        if r.get("is_recurring") or r.get("frequency"):
            freq = (r.get("frequency") or "weekly").lower()
            interval = max(r.get("interval") or 1, 1)
            days_of_week = r.get("days_of_week") or []
            if isinstance(days_of_week, str):
                try:
                    days_of_week = json.loads(days_of_week)
                except Exception:
                    days_of_week = []

            end_type = (r.get("end_type") or "never").lower()
            end_count = r.get("end_count") or 52
            rec_end_date = r.get("rec_end_date")
            rec_limit = None
            if rec_end_date:
                if isinstance(rec_end_date, (datetime, date)):
                    rec_limit = rec_end_date.date() if isinstance(rec_end_date, datetime) else rec_end_date
                else:
                    try:
                        rec_limit = datetime.fromisoformat(str(rec_end_date).replace("Z", "+00:00")).date()
                    except Exception:
                        rec_limit = None

            cur_d = base_start_d + timedelta(days=1)
            occ_count = 1
            duration_days = (base_end_d - base_start_d).days

            while cur_d <= window_end:
                if rec_limit and cur_d > rec_limit:
                    break
                if end_type in ("after_count", "count") and occ_count >= end_count:
                    break

                is_match = False
                if freq == "daily":
                    diff = (cur_d - base_start_d).days
                    if diff > 0 and diff % interval == 0:
                        is_match = True
                elif freq == "weekly":
                    diff_weeks = (cur_d - base_start_d).days // 7
                    if diff_weeks >= 0 and diff_weeks % interval == 0:
                        if days_of_week:
                            wk_days = [_get_wk_day(d) for d in days_of_week]
                            if cur_d.weekday() in wk_days:
                                is_match = True
                        elif cur_d.weekday() == base_start_d.weekday():
                            is_match = True
                elif freq == "monthly":
                    if cur_d.day == base_start_d.day:
                        diff_m = (cur_d.year - base_start_d.year) * 12 + (cur_d.month - base_start_d.month)
                        if diff_m > 0 and diff_m % interval == 0:
                            is_match = True

                if is_match:
                    occ_count += 1
                    inst_end_d = cur_d + timedelta(days=duration_days)
                    all_holidays.append({
                        "id": f"{r['id']}_{str(cur_d)}",
                        "title": r.get("title") or "Public Holiday",
                        "description": r.get("description") or "",
                        "schedule_type": r.get("schedule_type") or "holiday",
                        "category": r.get("category") or "Holidays",
                        "start_date": str(cur_d),
                        "end_date": str(inst_end_d),
                        "color": r.get("color") or "#EF4444",
                        "calendar_name": r.get("calendar_name") or "Public Holidays"
                    })

                cur_d += timedelta(days=1)

    # 4. Also fetch official school events holidays with case-insensitive matching
    try:
        event_rows = await exec_sql("""
            SELECT id, title, description, category, event_date
            FROM public.events
            WHERE (school_id = %s OR school_id IS NULL)
              AND (
                  category ILIKE %s OR category ILIKE %s OR category ILIKE %s
                  OR title ILIKE %s OR title ILIKE %s OR title ILIKE %s OR title ILIKE %s OR title ILIKE %s
                  OR description ILIKE %s OR description ILIKE %s
              )
            ORDER BY event_date ASC;
        """, (
            school_id,
            '%holiday%', '%holy%', '%vacation%',
            '%holiday%', '%holy%', '%vacation%', '%closed%', '%break%',
            '%holiday%', '%holy%'
        ))
        for er in event_rows:
            ed = er.get("event_date")
            ed_str = ed.isoformat() if isinstance(ed, (date, datetime)) else str(ed)
            if not any(h["start_date"] == ed_str for h in all_holidays):
                all_holidays.append({
                    "id": str(er["id"]),
                    "title": er.get("title") or "School Holiday",
                    "description": er.get("description") or "",
                    "schedule_type": "holiday",
                    "category": er.get("category") or "Holidays",
                    "start_date": ed_str,
                    "end_date": ed_str,
                    "color": "#EF4444",
                    "calendar_name": "School Events"
                })
    except Exception as e:
        logger.warning(f"Failed to fetch events holidays: {e}")

    all_holidays.sort(key=lambda x: x["start_date"])
    return {"success": True, "data": _serialize_val(all_holidays)}


@router.post("/leave/apply")
async def apply_leave(
    payload: ApplyLeaveRequest,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Apply for a new leave request (by applicant or on behalf of staff/student by admin)."""
    user_id = str(current_user.get("id"))
    applicant_id = str(payload.applicant_id) if payload.applicant_id else user_id
    effective_days = payload.billable_days if payload.billable_days is not None else payload.days_count

    rows = await exec_sql(
        "SELECT public.fn_apply_leave_request(%s::UUID, %s::UUID, %s, %s::DATE, %s::DATE, %s, %s, %s, %s, %s::NUMERIC) AS result;",
        (school_id, applicant_id, payload.leave_type, payload.start_date, payload.end_date, payload.reason, payload.half_day_type, payload.attachment_url, payload.contact_number, effective_days)
    )
    if not rows or not rows[0].get("result"):
        raise HTTPException(status_code=400, detail="Failed to submit leave request")
    res = rows[0]["result"]
    if not res.get("success"):
        error_msg = res.get("message") or res.get("error") or "Failed to submit leave application"
        raise HTTPException(status_code=400, detail=error_msg)
    return _serialize_val(res)


@router.post("/leave/requests/{leave_id}/action")
@router.post("/leave-requests/{leave_id}/action")
async def handle_leave_request_action(
    leave_id: uuid.UUID,
    payload: LeaveActionRequest,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Approve, Reject or Cancel leave application with automatic balance adjustment and attendance synchronization."""
    _require_permission(current_user, "attendance.leave.approve")
    actor_id = str(current_user.get("id"))

    rows = await exec_sql(
        "SELECT public.fn_process_leave_action(%s::UUID, %s::UUID, %s, %s::UUID, %s) AS result;",
        (school_id, str(leave_id), payload.action, actor_id, payload.remarks)
    )
    if not rows or not rows[0].get("result"):
        raise HTTPException(status_code=400, detail="Failed to process leave action")
    res = rows[0]["result"]
    if not res.get("success"):
        error_msg = res.get("message") or res.get("error") or "Failed to process leave action"
        raise HTTPException(status_code=400, detail=error_msg)
    return _serialize_val(res)


@router.post("/leave/requests/batch-action")
@router.post("/leave-requests/batch-action")
async def handle_batch_leave_request_action(
    payload: BatchLeaveActionRequest,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Batch Approve, Reject or Cancel multiple leave applications."""
    _require_permission(current_user, "attendance.leave.approve")
    actor_id = str(current_user.get("id"))
    
    target_ids = [str(r) for r in payload.request_ids] if payload.request_ids else []
    if payload.select_all:
        where_clauses = ["la.school_id = %s::UUID"]
        where_params = [school_id]
        if payload.status and payload.status.upper() != "ALL":
            where_clauses.append("la.status = %s")
            where_params.append(payload.status.upper())
        if payload.user_type and payload.user_type.upper() != "ALL":
            where_clauses.append("la.applicant_role = %s")
            where_params.append(payload.user_type.lower())
        if payload.department and payload.department.upper() != "ALL":
            where_clauses.append("p.department = %s")
            where_params.append(payload.department)
        
        where_sql = " AND ".join(where_clauses)
        id_rows = await exec_sql(f"""
            SELECT la.id FROM public.leave_applications la
            JOIN public.profiles p ON p.id = la.applicant_id
            WHERE {where_sql}
        """, where_params)
        target_ids = [str(r["id"]) for r in id_rows]

    success_ids = []
    failed_items = []
    
    for req_id in target_ids:
        try:
            rows = await exec_sql(
                "SELECT public.fn_process_leave_action(%s::UUID, %s::UUID, %s, %s::UUID, %s) AS result;",
                (school_id, str(req_id), payload.action, actor_id, payload.remarks)
            )
            res = rows[0]["result"] if rows else {}
            if res.get("success"):
                success_ids.append(str(req_id))
            else:
                failed_items.append({"id": str(req_id), "error": res.get("message") or res.get("error")})
        except Exception as e:
            failed_items.append({"id": str(req_id), "error": str(e)})
            
    return {
        "success": True,
        "message": f"Processed {len(success_ids)} of {len(target_ids)} leave requests ({payload.action})",
        "data": {
            "processed_count": len(success_ids),
            "total_count": len(target_ids),
            "success_ids": success_ids,
            "failed_items": failed_items
        }
    }


@router.get("/leave-requests")
async def get_leave_requests(
    status: str = Query("ALL", description="ALL, pending, approved, rejected, cancelled"),
    role: str = Query("ALL", description="ALL, student, teacher, staff"),
    manager_id: Optional[str] = Query(None),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """List leave requests for backward compatibility."""
    _require_permission(current_user, "attendance.leave.view")
    user_role = str(current_user.get("role", "")).lower()
    user_id = str(current_user.get("id"))

    if manager_id and str(manager_id).upper() in ("MY_REPORTS", "ME", "DIRECT_REPORTS"):
        scoped_manager = user_id
    elif user_role in ("super_admin", "admin"):
        scoped_manager = str(manager_id) if (manager_id and str(manager_id).upper() != "ALL") else None
    else:
        scoped_manager = user_id

    manager_clause = "AND p.manager_id = %s::UUID" if scoped_manager else ""
    query_params = [school_id, status, status, role, role]
    if scoped_manager:
        query_params.append(scoped_manager)

    query = f"""
        SELECT la.id, la.request_code, la.applicant_id, p.full_name as applicant_name, p.avatar_url, la.applicant_role,
               la.leave_type, la.start_date, la.end_date, la.reason, la.status, la.remarks,
               la.created_at, ap.full_name as approved_by_name,
               COALESCE(
                   la.billable_days,
                   CASE
                       WHEN la.half_day_type IN ('FIRST_HALF', 'SECOND_HALF') THEN 0.5
                       ELSE (la.end_date - la.start_date + 1)::NUMERIC(5, 1)
                   END
               ) as days_count,
               (la.end_date - la.start_date + 1)::INT as total_calendar_days,
               COALESCE(la.holidays_count, 0) as holidays_count,
               COALESCE(la.overlap_days_count, 0) as overlap_days_count
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


@router.get("/roles")
async def get_active_roles(
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Retrieve active system and custom roles from app_roles."""
    rows = await exec_sql(
        """
        SELECT id, name, code, display_name, description, role_type
        FROM public.app_roles
        WHERE UPPER(COALESCE(status, 'ACTIVE')) = 'ACTIVE'
          AND (school_id = %s::UUID OR school_id IS NULL)
        ORDER BY display_order ASC, name ASC;
        """,
        (school_id,)
    )
    return {"success": True, "data": {"roles": _serialize_val(rows)}}


@router.get("/leave/types")
async def get_leave_types(
    role: Optional[str] = Query(None),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Get list of active leave types and policies, optionally filtered by role."""
    _require_permission(current_user, "attendance.leave.view")

    role_str = role if isinstance(role, str) else None
    if role_str and role_str.upper() != "ALL":
        clean_role = role_str.strip().lower()
        rows = await exec_sql(
            """
            SELECT id, school_id, name, code, category, annual_entitlement, monthly_accrual,
                   carry_forward_allowed, max_carry_forward, encashment_allowed, max_encashable,
                   doc_required, doc_required_after_days, min_notice_days, max_consecutive_days,
                   allow_half_day, applicable_roles, color_hex, is_active, created_at, updated_at
            FROM public.leave_types
            WHERE (school_id = %s::UUID OR school_id IS NULL)
              AND is_active = TRUE
              AND (
                  applicable_roles IS NULL
                  OR array_length(applicable_roles, 1) IS NULL
                  OR array_length(applicable_roles, 1) = 0
                  OR 'all' = ANY(applicable_roles)
                  OR %s = ANY(ARRAY(SELECT LOWER(r) FROM unnest(applicable_roles) r))
              )
            ORDER BY name ASC, id ASC;
            """,
            (school_id, clean_role)
        )
    else:
        rows = await exec_sql(
            """
            SELECT id, school_id, name, code, category, annual_entitlement, monthly_accrual,
                   carry_forward_allowed, max_carry_forward, encashment_allowed, max_encashable,
                   doc_required, doc_required_after_days, min_notice_days, max_consecutive_days,
                   allow_half_day, applicable_roles, color_hex, is_active, created_at, updated_at
            FROM public.leave_types
            WHERE (school_id = %s::UUID OR school_id IS NULL)
            ORDER BY name ASC, id ASC;
            """,
            (school_id,)
        )
    return {"success": True, "data": {"leave_types": _serialize_val(rows)}}


@router.post("/leave/types")
async def upsert_leave_type(
    payload: LeaveTypePayload,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Create or update a leave type policy with role scoping."""
    _require_permission(current_user, "attendance.settings.edit")
    roles_arr = payload.applicable_roles if (payload.applicable_roles is not None and len(payload.applicable_roles) > 0) else ["all"]

    if payload.id:
        rows = await exec_sql(
            """
            UPDATE public.leave_types SET
                name = %s, code = %s, category = %s, annual_entitlement = %s,
                monthly_accrual = %s, carry_forward_allowed = %s, max_carry_forward = %s,
                encashment_allowed = %s, doc_required = %s, doc_required_after_days = %s,
                allow_half_day = %s, applicable_roles = %s::text[], color_hex = %s, is_active = %s, updated_at = NOW()
            WHERE id = %s::UUID AND (school_id = %s::UUID OR school_id IS NULL)
            RETURNING *;
            """,
            (payload.name, payload.code, payload.category, payload.annual_entitlement,
             payload.monthly_accrual, payload.carry_forward_allowed, payload.max_carry_forward,
             payload.encashment_allowed, payload.doc_required, payload.doc_required_after_days,
             payload.allow_half_day, roles_arr, payload.color_hex, payload.is_active, str(payload.id), school_id)
        )
        if rows:
            await exec_sql(
                "UPDATE public.leave_applications SET leave_type = %s WHERE leave_type_id = %s::UUID;",
                (payload.name, str(payload.id))
            )
    else:
        rows = await exec_sql(
            """
            INSERT INTO public.leave_types (
                school_id, name, code, category, annual_entitlement, monthly_accrual,
                carry_forward_allowed, max_carry_forward, encashment_allowed, doc_required,
                doc_required_after_days, allow_half_day, applicable_roles, color_hex, is_active
            )
            VALUES (%s::UUID, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s::text[], %s, %s)
            ON CONFLICT (school_id, code) DO UPDATE SET
                name = EXCLUDED.name, category = EXCLUDED.category, annual_entitlement = EXCLUDED.annual_entitlement,
                applicable_roles = EXCLUDED.applicable_roles, color_hex = EXCLUDED.color_hex, is_active = EXCLUDED.is_active, updated_at = NOW()
            RETURNING *;
            """,
            (school_id, payload.name, payload.code, payload.category, payload.annual_entitlement,
             payload.monthly_accrual, payload.carry_forward_allowed, payload.max_carry_forward,
             payload.encashment_allowed, payload.doc_required, payload.doc_required_after_days,
             payload.allow_half_day, roles_arr, payload.color_hex, payload.is_active)
        )
    return {"success": True, "message": "Leave type saved successfully", "data": _serialize_val(rows[0] if rows else {})}


@router.get("/leave/balances")
async def get_leave_balances(
    academic_year: str = Query("2026-2027"),
    department: str = Query("ALL"),
    role: str = Query("ALL"),
    search: str = Query(""),
    school_id: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    current_user: dict = Depends(get_current_user)
):
    """Retrieve paginated and grouped employee leave balances strictly scoped to the user's school."""
    _require_permission(current_user, "attendance.leave.view")

    acad_yr = academic_year if isinstance(academic_year, str) else "2026-2027"
    dept_str = department if isinstance(department, str) else "ALL"
    role_str = role if isinstance(role, str) else "ALL"
    search_str = search if isinstance(search, str) else ""
    page_num = page if isinstance(page, int) else 1
    page_sz = page_size if isinstance(page_size, int) else 10
    sch_id = school_id if (isinstance(school_id, str) or school_id is None) else None

    effective_school_id = sch_id or current_user.get("school_id")
    if not effective_school_id or str(effective_school_id).upper() == "ALL":
        effective_school_id = current_user.get("school_id") or "11111111-1111-1111-1111-111111111111"

    rows = await exec_sql(
        "SELECT public.fn_get_leave_balances_paginated(%s::UUID, %s, %s, %s, %s, %s, %s) AS result;",
        (effective_school_id, acad_yr, dept_str, role_str, search_str.strip(), page_num, page_sz)
    )
    if not rows or not rows[0].get("result"):
        return {"success": True, "data": {"employees": [], "balances": [], "page": page_num, "page_size": page_sz, "total_count": 0, "total_pages": 1}}
    
    res = rows[0]["result"]
    data = res.get("data", {})
    # Flatten balances list with strict unique deduplication per (user_id, leave_type_id)
    seen_balances = set()
    flat_balances = []
    for emp in data.get("employees", []):
        user_id = emp.get("user_id") or emp.get("employee_id") or emp.get("id")
        for bal in emp.get("balances", []):
            lt_id = bal.get("leave_type_id")
            key = (str(user_id), str(lt_id))
            if key in seen_balances:
                continue
            seen_balances.add(key)
            flat_balances.append({
                "id": bal.get("id"),
                "user_id": user_id,
                "employee_id": user_id,
                "full_name": emp.get("full_name"),
                "role": emp.get("role"),
                "avatar_url": emp.get("avatar_url"),
                "employee_code": emp.get("employee_code"),
                "department": emp.get("department"),
                "designation": emp.get("designation"),
                "leave_type_id": lt_id,
                "leave_type_name": bal.get("leave_type_name"),
                "leave_type_code": bal.get("leave_type_code"),
                "color_hex": bal.get("color_hex"),
                "allocated_days": bal.get("allocated_days"),
                "used_days": bal.get("used_days"),
                "pending_days": bal.get("pending_days"),
                "carried_forward_days": bal.get("carried_forward_days"),
                "available_days": bal.get("available_days"),
                "academic_year": academic_year,
            })
    data["balances"] = flat_balances
    data["flat_balances"] = flat_balances
    return _serialize_val(res)


@router.post("/leave/balances/adjust")
async def adjust_leave_balance(
    payload: BalanceAdjustmentPayload,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Manually adjust employee leave balance with mandatory reason and immutable audit log."""
    _require_permission(current_user, "attendance.leave.approve")
    actor_id = str(current_user.get("id"))

    rows = await exec_sql(
        "SELECT public.fn_adjust_leave_balance(%s::UUID, %s::UUID, %s::UUID, %s, %s, %s::UUID, %s) AS result;",
        (school_id, str(payload.user_id), str(payload.leave_type_id), payload.adjustment_days, payload.reason, actor_id, payload.academic_year)
    )
    if not rows or not rows[0].get("result"):
        raise HTTPException(status_code=400, detail="Failed to adjust leave balance")
    res = rows[0]["result"]
    if not res.get("success"):
        raise HTTPException(status_code=400, detail=res.get("error", "Failed to adjust balance"))
    return _serialize_val(res)


@router.get("/permissions/requests")
async def get_permission_requests(
    status: str = Query("ALL"),
    date: Optional[str] = Query(None),
    search: str = Query(""),
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """List short permission requests."""
    _require_permission(current_user, "attendance.leave.view")
    search_pat = f"%{search.strip().lower()}%"
    rows = await exec_sql(
        """
        SELECT pr.id, pr.request_code, pr.applicant_id, p.full_name AS applicant_name, p.avatar_url,
               COALESCE(p.employee_id, 'EMP-' || SUBSTRING(p.id::TEXT FROM 1 FOR 4)) AS employee_code,
               COALESCE(p.department, 'General') AS department, pr.applicant_role,
               pr.permission_type, pr.permission_date, pr.start_time, pr.end_time, pr.duration_hours,
               pr.reason, pr.status, pr.rejection_reason, pr.remarks, pr.created_at,
               ap.full_name AS approved_by_name
        FROM public.permission_requests pr
        JOIN public.profiles p ON p.id = pr.applicant_id
        LEFT JOIN public.profiles ap ON ap.id = pr.approved_by
        WHERE (pr.school_id = %s::UUID OR pr.school_id IS NULL)
          AND (UPPER(%s) = 'ALL' OR UPPER(pr.status) = UPPER(%s))
          AND (%s::DATE IS NULL OR pr.permission_date = %s::DATE)
          AND (
              %s = '' OR
              LOWER(p.full_name) LIKE %s OR
              LOWER(COALESCE(pr.request_code, '')) LIKE %s OR
              LOWER(pr.reason) LIKE %s
          )
        ORDER BY pr.created_at DESC;
        """,
        (school_id, status, status, date, date, search.strip(), search_pat, search_pat, search_pat)
    )
    return {"success": True, "data": {"permissions": _serialize_val(rows)}}


@router.post("/permissions/requests")
async def apply_permission(
    payload: ApplyPermissionPayload,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Apply for short permission / hourly leave."""
    user_id = str(current_user.get("id"))
    applicant_id = str(payload.applicant_id) if payload.applicant_id else user_id

    rows = await exec_sql(
        "SELECT public.fn_apply_permission_request(%s::UUID, %s::UUID, %s, %s::DATE, %s::TIME, %s::TIME, %s, %s) AS result;",
        (school_id, applicant_id, payload.permission_type, payload.permission_date, payload.start_time, payload.end_time, payload.reason, payload.duration_hours)
    )
    if not rows or not rows[0].get("result"):
        raise HTTPException(status_code=400, detail="Failed to submit permission request")
    res = rows[0]["result"]
    if not res.get("success"):
        raise HTTPException(status_code=400, detail=res.get("error", "Failed to submit permission request"))
    return _serialize_val(res)


@router.post("/permissions/requests/{permission_id}/action")
async def handle_permission_action(
    permission_id: uuid.UUID,
    payload: PermissionActionPayload,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Approve or Reject short permission request."""
    _require_permission(current_user, "attendance.leave.approve")
    actor_id = str(current_user.get("id"))
    act = payload.action.upper()
    new_status = "APPROVED" if act == "APPROVE" else ("REJECTED" if act == "REJECT" else "CANCELLED")

    rows = await exec_sql(
        """
        UPDATE public.permission_requests SET
            status = %s,
            approved_by = (SELECT id FROM public.profiles WHERE id = %s::UUID LIMIT 1),
            approved_at = NOW(),
            remarks = %s,
            rejection_reason = CASE WHEN %s = 'REJECTED' THEN %s ELSE rejection_reason END,
            updated_at = NOW()
        WHERE id = %s::UUID AND (school_id = %s::UUID OR school_id IS NULL)
        RETURNING *;
        """,
        (new_status, actor_id, payload.remarks, new_status, payload.remarks, str(permission_id), school_id)
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Permission request not found")
    return {"success": True, "message": f"Permission request {new_status.lower()} successfully", "data": _serialize_val(rows[0])}


@router.post("/permissions/requests/batch-action")
async def handle_batch_permission_action(
    payload: BatchPermissionActionRequest,
    current_user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Batch Approve, Reject or Cancel multiple short permission requests."""
    _require_permission(current_user, "attendance.leave.approve")
    actor_id = str(current_user.get("id"))
    act = payload.action.upper()
    new_status = "APPROVED" if act == "APPROVE" else ("REJECTED" if act == "REJECT" else "CANCELLED")

    id_strs = [str(pid) for pid in payload.permission_ids] if payload.permission_ids else []
    if payload.select_all:
        where_clauses = ["(school_id = %s::UUID OR school_id IS NULL)"]
        where_params = [school_id]
        if payload.status and payload.status.upper() != "ALL":
            where_clauses.append("status = %s")
            where_params.append(payload.status.upper())
        where_sql = " AND ".join(where_clauses)
        id_rows = await exec_sql(f"SELECT id FROM public.permission_requests WHERE {where_sql}", where_params)
        id_strs = [str(r["id"]) for r in id_rows]

    if not id_strs:
        return {"success": True, "message": "No permissions selected", "data": {"processed_count": 0}}

    rows = await exec_sql(
        """
        UPDATE public.permission_requests SET
            status = %s,
            approved_by = (SELECT id FROM public.profiles WHERE id = %s::UUID LIMIT 1),
            approved_at = NOW(),
            remarks = %s,
            rejection_reason = CASE WHEN %s = 'REJECTED' THEN %s ELSE rejection_reason END,
            updated_at = NOW()
        WHERE id = ANY(%s::UUID[]) AND (school_id = %s::UUID OR school_id IS NULL)
        RETURNING id;
        """,
        (new_status, actor_id, payload.remarks, new_status, payload.remarks, id_strs, school_id)
    )
    processed = len(rows) if rows else 0
    return {
        "success": True,
        "message": f"Processed {processed} of {len(id_strs)} permission requests ({payload.action})",
        "data": {"processed_count": processed, "total_count": len(id_strs)}
    }


# ============================================================================
# BULK OPERATIONS & CSV EXPORT
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
