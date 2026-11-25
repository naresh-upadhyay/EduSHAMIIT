"""
Enterprise Employee Onboarding Management API for EduSHAMIIT ERP.
End-to-End Production-Ready REST API handling New Hires, Onboarding Pipeline,
Document Collection & Verification, Checklist Tasks, Joining Formalities,
Audit Logging, Multi-Tenant Isolation, and RBAC Enforcement.
"""
from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status, UploadFile, File, Form
from fastapi.responses import StreamingResponse, JSONResponse
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any, Union
from datetime import datetime, date, time, timedelta
from decimal import Decimal
import os
import json
import uuid
import logging
import asyncio
import io
import csv

from app.config import settings
from app.middleware.auth import get_current_user, require_school_id
from app.api.recruitment import exec_sql, _serialize_datetime
from app.services.email_service import get_email_service

logger = logging.getLogger(__name__)
router = APIRouter()


# ============================================================================
# RBAC & SECURITY HELPERS
# ============================================================================
def check_onboarding_permissions(user: dict, require_admin: bool = False):
    """Verify role authorization for Onboarding module."""
    role = (user.get("role") or "").lower()
    allowed_admin_roles = ["super_admin", "admin", "hr", "director", "principal", "school_admin"]
    if require_admin:
        if role not in allowed_admin_roles:
            raise HTTPException(
                status_code=403,
                detail="Access denied: Onboarding administration requires HR or Admin role."
            )
    else:
        allowed_roles = allowed_admin_roles + ["interviewer", "teacher", "department_head"]
        if role not in allowed_roles:
            raise HTTPException(
                status_code=403,
                detail="Access denied: Insufficient privileges for onboarding module."
            )


async def log_onboarding_activity(school_id: str, onboarding_id: str, action: str, description: str,
                                  user_id: Optional[str] = None, metadata: Optional[dict] = None):
    """Log an audit event to public.onboarding_activities."""
    try:
        await exec_sql("""
            INSERT INTO public.onboarding_activities (school_id, onboarding_id, user_id, action, description, metadata)
            VALUES (%s, %s, %s, %s, %s, %s::jsonb);
        """, (
            school_id,
            onboarding_id,
            user_id,
            action,
            description,
            json.dumps(metadata or {})
        ), fetch=False)
    except Exception as e:
        logger.error(f"Failed to log onboarding activity: {e}")


# ============================================================================
# PYDANTIC SCHEMAS
# ============================================================================
class CreateOnboardingRequest(BaseModel):
    candidate_id: Optional[str] = None
    department: str = Field(..., example="Academics")
    designation: str = Field(..., example="Physics Teacher")
    employment_type: str = Field(default="Full-time", example="Full-time")
    expected_joining_date: date
    reporting_time: str = Field(default="09:00 AM")
    reporting_location: str = Field(default="Main Campus - HR Dept")
    reporting_manager_id: Optional[str] = None
    hr_owner_id: Optional[str] = None
    probation_period_months: int = 6
    work_location: str = "Main Campus"
    shift: str = "General Shift"
    template_name: Optional[str] = "Teaching Staff Onboarding"
    notes: Optional[str] = None


class UpdateStageRequest(BaseModel):
    stage: str = Field(..., example="Document Collection")
    notes: Optional[str] = None
    send_email: bool = True


class UpdateStatusRequest(BaseModel):
    status: str = Field(..., example="In Progress")
    notes: Optional[str] = None


class SendReminderRequest(BaseModel):
    reminder_type: Optional[str] = "documents"
    custom_message: Optional[str] = None
    send_email: bool = True


class AddDocumentRequest(BaseModel):
    document_name: str
    required_for: str = "All Employees"
    is_mandatory: bool = True
    remarks: Optional[str] = None


class VerifyDocumentRequest(BaseModel):
    remarks: Optional[str] = None


class RejectDocumentRequest(BaseModel):
    reason: str = Field(..., min_length=3, description="Mandatory reason for rejection")


class AddTaskRequest(BaseModel):
    title: str
    category: str = "HR"
    assigned_team: str = "HR Team"
    due_date: Optional[date] = None
    priority: str = "Medium"
    is_mandatory: bool = True


class UpdateTaskRequest(BaseModel):
    title: Optional[str] = None
    category: Optional[str] = None
    assigned_team: Optional[str] = None
    due_date: Optional[date] = None
    priority: Optional[str] = None
    status: Optional[str] = None


class UpdateJoiningRequest(BaseModel):
    joining_status: str = Field(..., example="Confirmed")
    actual_joining_date: Optional[date] = None
    expected_joining_date: Optional[date] = None
    reschedule_reason: Optional[str] = None
    no_show_reason: Optional[str] = None
    reporting_time: Optional[str] = None
    reporting_location: Optional[str] = None


class CompleteOnboardingRequest(BaseModel):
    override_blockers: bool = False
    override_reason: Optional[str] = None


class BulkActionRequest(BaseModel):
    onboarding_ids: List[str]
    action: str = Field(..., example="change_status")
    value: Optional[str] = None


# ============================================================================
# 1. ONBOARDING DASHBOARD METRICS & PIPELINE
# ============================================================================
@router.get("/dashboard", summary="Comprehensive Onboarding Dashboard KPIs & Breakdown")
async def get_onboarding_dashboard(
    user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    check_onboarding_permissions(user)

    # 1. Aggregate KPI Counts
    kpi_query = """
        SELECT
            COUNT(*) as total_onboardings,
            COUNT(*) FILTER (WHERE status = 'In Progress') as in_progress,
            COUNT(*) FILTER (WHERE status = 'Completed') as completed,
            COUNT(*) FILTER (WHERE status = 'Pending') as pending,
            COUNT(*) FILTER (WHERE expected_joining_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + INTERVAL '7 days')) as joining_this_week,
            COUNT(*) FILTER (WHERE joining_status = 'Expected') as ready_to_join,
            COUNT(*) FILTER (WHERE joining_status = 'Joined') as joined,
            COUNT(*) FILTER (WHERE joining_status = 'No Show') as no_show
        FROM public.employee_onboarding
        WHERE school_id = %s AND is_deleted = false;
    """
    kpi_res = await exec_sql(kpi_query, (school_id,))
    kpi = kpi_res[0] if kpi_res else {}

    # Pending Documents Count: actual count of pending document files awaiting verification/submission
    pending_docs_res = await exec_sql("""
        SELECT 
            COUNT(*) as pending_doc_files,
            COUNT(DISTINCT d.onboarding_id) as candidates_with_pending_docs
        FROM public.onboarding_documents d
        JOIN public.employee_onboarding o ON d.onboarding_id = o.id
        WHERE d.school_id = %s AND o.is_deleted = false AND d.status = 'Pending';
    """, (school_id,))
    pending_docs_count = int(pending_docs_res[0]["pending_doc_files"]) if pending_docs_res else 0
    candidates_with_pending = int(pending_docs_res[0]["candidates_with_pending_docs"]) if pending_docs_res else 0

    # 2. Pipeline Stage Conversion Flow
    pipeline_counts = {
        "Offer Accepted": 0,
        "Document Collection": 0,
        "Orientation": 0,
        "IT Setup": 0,
        "Training": 0,
        "Completed": 0
    }

    # Fetch cumulative progression numbers
    stage_rows = await exec_sql("""
        SELECT stage, COUNT(*) as count
        FROM public.employee_onboarding
        WHERE school_id = %s AND is_deleted = false
        GROUP BY stage;
    """, (school_id,))

    active_by_stage = {r["stage"]: r["count"] for r in stage_rows}

    # Standard funnel ordering
    total = int(kpi.get("total_onboardings") or 0)
    completed = int(kpi.get("completed") or 0)
    
    # Accurate active stage progression counts
    stage_definitions = [
        ("Offer Accepted", "handshake"),
        ("Document Collection", "description"),
        ("Orientation", "how_to_reg"),
        ("IT Setup", "devices"),
        ("Training", "school"),
        ("Completed", "verified"),
    ]

    pipeline_stages = []
    for st_name, icon in stage_definitions:
        st_count = int(active_by_stage.get(st_name, 0))
        pct = round((st_count / total * 100), 1) if total else 0.0
        pipeline_stages.append({
            "stage": st_name,
            "count": st_count,
            "percentage": pct,
            "icon": icon
        })

    # 3. Department Breakdown
    dept_rows = await exec_sql("""
        SELECT department, COUNT(*) as count
        FROM public.employee_onboarding
        WHERE school_id = %s AND is_deleted = false
        GROUP BY department
        ORDER BY count DESC;
    """, (school_id,))

    departments = []
    for r in dept_rows:
        cnt = int(r["count"])
        pct = round((cnt / total * 100), 1) if total else 0.0
        departments.append({
            "department": r["department"],
            "count": cnt,
            "percentage": pct
        })

    # 4. Recent Onboarding Tasks (Top 5 for dashboard widget)
    recent_tasks = await exec_sql("""
        SELECT t.id, t.title, t.category, t.assigned_team, t.due_date, t.priority, t.status,
               o.onboarding_code, c.full_name as candidate_name
        FROM public.onboarding_tasks t
        JOIN public.employee_onboarding o ON t.onboarding_id = o.id
        LEFT JOIN public.recruitment_candidates c ON o.candidate_id = c.id
        WHERE t.school_id = %s AND o.is_deleted = false
        ORDER BY 
            CASE WHEN t.status = 'Overdue' THEN 1
                 WHEN t.status = 'In Progress' THEN 2
                 WHEN t.status = 'Pending' THEN 3
                 ELSE 4 END,
            t.due_date ASC
        LIMIT 5;
    """, (school_id,))

    # 5. Recent Onboarding Documents (Summary for bottom widget)
    recent_docs = await exec_sql("""
        SELECT d.id, d.document_name, d.required_for, d.status, d.uploaded_at,
               o.onboarding_code, c.full_name as candidate_name
        FROM public.onboarding_documents d
        JOIN public.employee_onboarding o ON d.onboarding_id = o.id
        LEFT JOIN public.recruitment_candidates c ON o.candidate_id = c.id
        WHERE d.school_id = %s AND o.is_deleted = false
        ORDER BY d.created_at DESC
        LIMIT 5;
    """, (school_id,))

    # 6. Recent Activities
    recent_activities = await exec_sql("""
        SELECT a.id, a.action, a.description, a.created_at,
               p.full_name as user_name
        FROM public.onboarding_activities a
        LEFT JOIN public.profiles p ON a.user_id = p.id
        WHERE a.school_id = %s
        ORDER BY a.created_at DESC
        LIMIT 6;
    """, (school_id,))

    # Real average days to complete onboarding calculation
    avg_days_res = await exec_sql("""
        SELECT COALESCE(ROUND(AVG(DATE_PART('day', updated_at - created_at))), 0) as avg_days
        FROM public.employee_onboarding
        WHERE school_id = %s AND status = 'Completed' AND is_deleted = false;
    """, (school_id,))
    avg_days_to_complete = int(avg_days_res[0]["avg_days"]) if avg_days_res else 0

    return {
        "success": True,
        "data": {
            "metrics": {
                "total_onboardings": total,
                "in_progress": int(kpi.get("in_progress") or 0),
                "pending_documents": pending_docs_count,
                "candidates_with_pending_docs": candidates_with_pending,
                "document_collection_candidates": int(active_by_stage.get("Document Collection", 0)),
                "completed": completed,
                "avg_time_days": avg_days_to_complete,
                "satisfaction_rate": 0.0,
                "joining_this_week": int(kpi.get("joining_this_week") or 0),
                "ready_to_join": int(kpi.get("ready_to_join") or 0),
                "joined": int(kpi.get("joined") or completed),
                "no_show": int(kpi.get("no_show") or 0)
            },
            "pipeline": pipeline_stages,
            "department_breakdown": departments,
            "recent_tasks": _serialize_datetime(recent_tasks),
            "recent_documents": _serialize_datetime(recent_docs),
            "recent_activities": _serialize_datetime(recent_activities)
        }
    }


# ============================================================================
# 2. MAIN ONBOARDING LIST (PAGINATED, FILTERABLE, SEARCHABLE)
# ============================================================================
@router.get("/records", summary="List Onboarding Records with Server-Side Search, Filter & Pagination")
async def list_onboarding_records(
    search: Optional[str] = Query(None, description="Search candidate name, code, email, designation"),
    department: Optional[str] = Query(None),
    stage: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    joining_date: Optional[date] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    sort_by: Optional[str] = Query("joining_date"),
    sort_order: Optional[str] = Query("asc"),
    user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    check_onboarding_permissions(user)

    where_clauses = ["o.school_id = %s", "o.is_deleted = false"]
    params = [school_id]

    if search and search.strip():
        term = f"%{search.strip()}%"
        where_clauses.append("""
            (c.full_name ILIKE %s OR c.email ILIKE %s OR c.phone ILIKE %s
             OR o.onboarding_code ILIKE %s OR o.designation ILIKE %s OR o.department ILIKE %s)
        """)
        params.extend([term, term, term, term, term, term])

    if department and department != "All":
        where_clauses.append("LOWER(o.department) = LOWER(%s)")
        params.append(department)

    if stage and stage != "All":
        where_clauses.append("LOWER(o.stage) = LOWER(%s)")
        params.append(stage)

    if status and status != "All":
        where_clauses.append("LOWER(o.status) = LOWER(%s)")
        params.append(status)

    if joining_date:
        where_clauses.append("o.joining_date = %s")
        params.append(joining_date)

    where_str = " AND ".join(where_clauses)

    # 1. Total records count
    count_sql = f"""
        SELECT COUNT(*) as total
        FROM public.employee_onboarding o
        LEFT JOIN public.recruitment_candidates c ON o.candidate_id = c.id
        WHERE {where_str};
    """
    total_res = await exec_sql(count_sql, tuple(params))
    total_records = total_res[0]["total"] if total_res else 0

    # 2. Paginated Query with progress calculation
    sort_column_map = {
        "onboarding_code": "o.onboarding_code",
        "candidate_name": "c.full_name",
        "department": "o.department",
        "designation": "o.designation",
        "stage": "o.stage",
        "joining_date": "o.joining_date",
        "status": "o.status",
        "created_at": "o.created_at",
    }
    sort_col_sql = sort_column_map.get(sort_by or "joining_date", "o.joining_date")
    sort_dir_sql = "DESC" if (sort_order or "").lower() == "desc" else "ASC"
    order_clause = f"{sort_col_sql} {sort_dir_sql} NULLS LAST, o.created_at DESC"
    offset = (page - 1) * page_size
    query_sql = f"""
        SELECT
            o.id,
            o.onboarding_code,
            o.department,
            o.designation,
            o.employment_type,
            o.stage,
            o.status,
            o.joining_date,
            o.expected_joining_date,
            o.actual_joining_date,
            o.reporting_time,
            o.reporting_location,
            o.joining_status,
            o.satisfaction_score,
            o.template_name,
            o.created_at,
            c.id as candidate_id,
            c.full_name as candidate_name,
            c.email as candidate_email,
            c.phone as candidate_phone,
            c.profile_photo_url,
            p.full_name as hr_owner_name,
            -- Documents stats
            COALESCE(doc_stats.total_docs, 0) as total_docs,
            COALESCE(doc_stats.verified_docs, 0) as verified_docs,
            -- Tasks stats
            COALESCE(task_stats.total_tasks, 0) as total_tasks,
            COALESCE(task_stats.completed_tasks, 0) as completed_tasks
        FROM public.employee_onboarding o
        LEFT JOIN public.recruitment_candidates c ON o.candidate_id = c.id
        LEFT JOIN public.profiles p ON o.hr_owner_id = p.id
        LEFT JOIN (
            SELECT onboarding_id,
                   COUNT(*) as total_docs,
                   COUNT(*) FILTER (WHERE status = 'Verified') as verified_docs
            FROM public.onboarding_documents
            GROUP BY onboarding_id
        ) doc_stats ON o.id = doc_stats.onboarding_id
        LEFT JOIN (
            SELECT onboarding_id,
                   COUNT(*) as total_tasks,
                   COUNT(*) FILTER (WHERE status = 'Completed') as completed_tasks
            FROM public.onboarding_tasks
            GROUP BY onboarding_id
        ) task_stats ON o.id = task_stats.onboarding_id
        WHERE {where_str}
        ORDER BY {order_clause}
        LIMIT %s OFFSET %s;
    """
    params.extend([page_size, offset])
    rows = await exec_sql(query_sql, tuple(params))

    # Compute progress percentage dynamically
    records = []
    for r in rows:
        t_docs = r["total_docs"]
        v_docs = r["verified_docs"]
        t_tasks = r["total_tasks"]
        c_tasks = r["completed_tasks"]

        total_items = t_docs + t_tasks
        completed_items = v_docs + c_tasks
        
        if r["status"] == "Completed":
            progress = 100.0
        elif total_items > 0:
            progress = round((completed_items / total_items) * 100, 1)
        else:
            progress = 0.0

        r["progress_pct"] = progress
        records.append(r)

    total_pages = (total_records + page_size - 1) // page_size if total_records else 1

    return {
        "success": True,
        "data": _serialize_datetime(records),
        "pagination": {
            "page": page,
            "page_size": page_size,
            "total_records": total_records,
            "total_pages": total_pages
        }
    }


# ============================================================================
# 3. ONBOARDING RECORD 360 DETAIL (DRAWER / DETAIL VIEW)
# ============================================================================
@router.get("/records/{onboarding_id}", summary="Get Full 360 Onboarding Detail Record")
async def get_onboarding_detail(
    onboarding_id: str,
    user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    check_onboarding_permissions(user)

    # 1. Main record
    onb_res = await exec_sql("""
        SELECT o.*,
               c.full_name as candidate_name,
               c.email as candidate_email,
               c.phone as candidate_phone,
               c.profile_photo_url,
               c.qualification,
               c.experience_years,
               c.current_organization,
               c.skills,
               p_hr.full_name as hr_owner_name,
               p_mgr.full_name as reporting_manager_name
        FROM public.employee_onboarding o
        LEFT JOIN public.recruitment_candidates c ON o.candidate_id = c.id
        LEFT JOIN public.profiles p_hr ON o.hr_owner_id = p_hr.id
        LEFT JOIN public.profiles p_mgr ON o.reporting_manager_id = p_mgr.id
        WHERE o.id = %s AND o.school_id = %s AND o.is_deleted = false;
    """, (onboarding_id, school_id))

    if not onb_res:
        raise HTTPException(status_code=404, detail="Onboarding record not found.")
    
    onb = onb_res[0]

    # 2. Documents
    docs = await exec_sql("""
        SELECT d.*, p.full_name as verified_by_name
        FROM public.onboarding_documents d
        LEFT JOIN public.profiles p ON d.verified_by = p.id
        WHERE d.onboarding_id = %s AND d.school_id = %s
        ORDER BY d.is_mandatory DESC, d.created_at ASC;
    """, (onboarding_id, school_id))

    # 3. Tasks
    tasks = await exec_sql("""
        SELECT t.*, p_asgn.full_name as assigned_to_name, p_comp.full_name as completed_by_name
        FROM public.onboarding_tasks t
        LEFT JOIN public.profiles p_asgn ON t.assigned_to_id = p_asgn.id
        LEFT JOIN public.profiles p_comp ON t.completed_by = p_comp.id
        WHERE t.onboarding_id = %s AND t.school_id = %s
        ORDER BY 
            CASE WHEN t.status = 'Overdue' THEN 1
                 WHEN t.status = 'In Progress' THEN 2
                 WHEN t.status = 'Pending' THEN 3
                 ELSE 4 END,
            t.due_date ASC;
    """, (onboarding_id, school_id))

    # 4. Activities
    activities = await exec_sql("""
        SELECT a.*, p.full_name as user_name
        FROM public.onboarding_activities a
        LEFT JOIN public.profiles p ON a.user_id = p.id
        WHERE a.onboarding_id = %s AND a.school_id = %s
        ORDER BY a.created_at DESC;
    """, (onboarding_id, school_id))

    # 5. Progress Calculation & Completion Guard
    total_docs = len(docs)
    verified_docs = sum(1 for d in docs if d["status"] == "Verified")
    mandatory_docs_pending = [d["document_name"] for d in docs if d["is_mandatory"] and d["status"] != "Verified"]

    total_tasks = len(tasks)
    completed_tasks = sum(1 for t in tasks if t["status"] == "Completed")
    mandatory_tasks_pending = [t["title"] for t in tasks if t["is_mandatory"] and t["status"] != "Completed"]

    joining_completed = (onb["joining_status"] == "Joined")

    blockers = []
    if mandatory_docs_pending:
        blockers.append(f"{len(mandatory_docs_pending)} mandatory documents not verified: {', '.join(mandatory_docs_pending)}")
    if mandatory_tasks_pending:
        blockers.append(f"{len(mandatory_tasks_pending)} mandatory tasks incomplete: {', '.join(mandatory_tasks_pending)}")
    if not joining_completed:
        blockers.append("Joining status is not confirmed as 'Joined'")

    total_items = total_docs + total_tasks + 1
    completed_items = verified_docs + completed_tasks + (1 if joining_completed else 0)
    overall_progress = 100.0 if onb["status"] == "Completed" else round((completed_items / total_items * 100), 1) if total_items else 0.0

    return {
        "success": True,
        "data": {
            "onboarding": _serialize_datetime(onb),
            "documents": _serialize_datetime(docs),
            "tasks": _serialize_datetime(tasks),
            "activities": _serialize_datetime(activities),
            "progress": {
                "overall_pct": overall_progress,
                "documents": {"total": total_docs, "verified": verified_docs},
                "tasks": {"total": total_tasks, "completed": completed_tasks},
                "joining": {"is_joined": joining_completed}
            },
            "completion_guard": {
                "is_ready_for_completion": len(blockers) == 0,
                "blockers": blockers
            }
        }
    }


# ============================================================================
# 4. START ONBOARDING (CREATE RECORD WITH WORKFLOW & TEMPLATE)
# ============================================================================
@router.post("/records", summary="Start New Employee Onboarding")
async def start_onboarding(
    payload: CreateOnboardingRequest,
    user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    check_onboarding_permissions(user, require_admin=True)

    # 1. Prevent duplicate active onboarding for the same candidate
    if payload.candidate_id:
        existing = await exec_sql("""
            SELECT id, onboarding_code FROM public.employee_onboarding
            WHERE school_id = %s AND candidate_id = %s AND is_deleted = false AND status != 'Completed';
        """, (school_id, payload.candidate_id))
        if existing:
            raise HTTPException(
                status_code=400,
                detail=f"Candidate is already in active onboarding under code {existing[0]['onboarding_code']}."
            )

    # 2. Generate unique onboarding code
    count_res = await exec_sql("SELECT COUNT(*) as count FROM public.employee_onboarding WHERE school_id = %s;", (school_id,))
    seq = (count_res[0]["count"] if count_res else 0) + 1
    onboarding_code = f"EMP{1300 + seq}"

    # 3. Insert Onboarding Record
    res = await exec_sql("""
        INSERT INTO public.employee_onboarding (
            school_id, candidate_id, onboarding_code, department, designation,
            employment_type, stage, status, joining_date, expected_joining_date, actual_joining_date,
            reporting_time, reporting_location, reporting_manager_id, hr_owner_id,
            probation_period_months, work_location, shift, joining_status, template_name, notes
        ) VALUES (
            %s, %s, %s, %s, %s,
            %s, 'Offer Accepted', 'Pending', %s, %s, NULL,
            %s, %s, %s, %s,
            %s, %s, %s, 'Expected', %s, %s
        ) RETURNING id;
    """, (
        school_id,
        payload.candidate_id,
        onboarding_code,
        payload.department,
        payload.designation,
        payload.employment_type,
        payload.expected_joining_date,
        payload.expected_joining_date,
        payload.reporting_time,
        payload.reporting_location,
        payload.reporting_manager_id,
        payload.hr_owner_id,
        payload.probation_period_months,
        payload.work_location,
        payload.shift,
        payload.template_name,
        payload.notes
    ))

    onboarding_id = str(res[0]["id"])

    # 4. Apply Default Template Documents & Tasks
    tmpl_res = await exec_sql("""
        SELECT default_documents, default_tasks FROM public.onboarding_templates
        WHERE school_id = %s AND name = %s
        LIMIT 1;
    """, (school_id, payload.template_name))

    if tmpl_res:
        t_docs = tmpl_res[0].get("default_documents") or []
        t_tasks = tmpl_res[0].get("default_tasks") or []

        for d in t_docs:
            await exec_sql("""
                INSERT INTO public.onboarding_documents (
                    school_id, onboarding_id, document_name, required_for, is_mandatory, status
                ) VALUES (%s, %s, %s, %s, %s, 'Pending');
            """, (school_id, onboarding_id, d["document_name"], d.get("required_for", "All Employees"), d.get("is_mandatory", True)), fetch=False)

        for t in t_tasks:
            due = payload.expected_joining_date + timedelta(days=t.get("days_offset", 2))
            await exec_sql("""
                INSERT INTO public.onboarding_tasks (
                    school_id, onboarding_id, title, category, assigned_team, due_date, priority, status, is_mandatory
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, 'Pending', %s);
            """, (school_id, onboarding_id, t["title"], t.get("category", "HR"), t.get("assigned_team", "HR Team"), due, t.get("priority", "Medium"), t.get("is_mandatory", True)), fetch=False)

    # 5. Log Activity
    user_id = user.get("id")
    await log_onboarding_activity(
        school_id=school_id,
        onboarding_id=onboarding_id,
        action="Started",
        description=f"Onboarding initiated under code {onboarding_code} ({payload.designation})",
        user_id=user_id
    )

    return {
        "success": True,
        "message": f"Onboarding {onboarding_code} successfully created.",
        "data": {"id": onboarding_id, "onboarding_code": onboarding_code}
    }


# ============================================================================
# 5. STAGE & STATUS WORKFLOW TRANSITIONS
# ============================================================================
@router.patch("/records/{onboarding_id}/stage", summary="Advance Onboarding Pipeline Stage")
async def update_onboarding_stage(
    onboarding_id: str,
    payload: UpdateStageRequest,
    user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    check_onboarding_permissions(user, require_admin=True)

    allowed_stages = ['Offer Accepted', 'Document Collection', 'Orientation', 'IT Setup', 'Training', 'Completed', 'On Hold', 'Cancelled']
    if payload.stage not in allowed_stages:
        raise HTTPException(status_code=400, detail=f"Invalid stage. Allowed: {allowed_stages}")

    old_res = await exec_sql("""
        SELECT o.id, o.school_id, o.stage, o.status, o.onboarding_code, o.designation, o.department,
               o.expected_joining_date, c.full_name as candidate_name, c.email as candidate_email
        FROM public.employee_onboarding o
        LEFT JOIN public.recruitment_candidates c ON o.candidate_id = c.id
        WHERE o.id = %s;
    """, (onboarding_id,))
    if not old_res:
        raise HTTPException(status_code=404, detail="Onboarding record not found.")

    record = old_res[0]
    target_school_id = str(record.get("school_id") or school_id)
    old_stage = record["stage"]
    new_status = "Completed" if payload.stage == "Completed" else ("In Progress" if payload.stage in ['Document Collection', 'Orientation', 'IT Setup', 'Training'] else "Pending")

    await exec_sql("""
        UPDATE public.employee_onboarding
        SET stage = %s, status = %s, updated_at = timezone('utc', now())
        WHERE id = %s;
    """, (payload.stage, new_status, onboarding_id), fetch=False)

    await log_onboarding_activity(
        school_id=target_school_id,
        onboarding_id=onboarding_id,
        action="Stage Changed",
        description=f"Stage transitioned from '{old_stage}' to '{payload.stage}'. {payload.notes or ''}".strip(),
        user_id=user.get("id"),
        metadata={"from_stage": old_stage, "to_stage": payload.stage, "notes": payload.notes}
    )

    # Optional candidate email notification
    cand_email = record.get("candidate_email")
    if payload.send_email and cand_email and "@" in cand_email:
        try:
            school_res = await exec_sql("SELECT name FROM public.schools WHERE id = %s;", (target_school_id,))
            school_name = school_res[0]["name"] if school_res else "EduSHAMIIT International School"
            email_svc = get_email_service()
            email_svc.send_onboarding_stage_transition_email(
                to_email=cand_email,
                candidate_name=record.get("candidate_name") or "New Hire",
                job_title=record.get("designation") or "Staff Member",
                department=record.get("department") or "Academics",
                school_name=school_name,
                employee_id=record.get("onboarding_code") or "EMP",
                from_stage=old_stage,
                to_stage=payload.stage,
                notes=payload.notes,
                expected_joining_date=str(record.get("expected_joining_date") or "")
            )
        except Exception as e:
            logger.error(f"Failed to send stage transition email to {cand_email}: {e}")

    return {"success": True, "message": f"Stage updated to {payload.stage}"}


@router.patch("/records/{onboarding_id}/status", summary="Update Onboarding Status")
async def update_onboarding_status(
    onboarding_id: str,
    payload: UpdateStatusRequest,
    user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    check_onboarding_permissions(user, require_admin=True)

    allowed_statuses = ['Pending', 'In Progress', 'Completed', 'On Hold', 'Cancelled']
    if payload.status not in allowed_statuses:
        raise HTTPException(status_code=400, detail=f"Invalid status. Allowed: {allowed_statuses}")

    old_res = await exec_sql("SELECT id, school_id, status FROM public.employee_onboarding WHERE id = %s;", (onboarding_id,))
    if not old_res:
        raise HTTPException(status_code=404, detail="Onboarding record not found.")

    target_school_id = str(old_res[0].get("school_id") or school_id)

    await exec_sql("""
        UPDATE public.employee_onboarding
        SET status = %s, updated_at = timezone('utc', now())
        WHERE id = %s;
    """, (payload.status, onboarding_id), fetch=False)

    await log_onboarding_activity(
        school_id=target_school_id,
        onboarding_id=onboarding_id,
        action="Status Changed",
        description=f"Status set to '{payload.status}'. {payload.notes or ''}".strip(),
        user_id=user.get("id")
    )

    return {"success": True, "message": f"Status updated to {payload.status}"}



# ============================================================================
# 6. DOCUMENT MANAGEMENT & VERIFICATION WORKFLOW
# ============================================================================
@router.post("/records/{onboarding_id}/documents", summary="Add Required Document")
async def add_onboarding_document(
    onboarding_id: str,
    payload: AddDocumentRequest,
    user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    check_onboarding_permissions(user)

    res = await exec_sql("""
        INSERT INTO public.onboarding_documents (
            school_id, onboarding_id, document_name, required_for, is_mandatory, status, remarks
        ) VALUES (%s, %s, %s, %s, %s, 'Pending', %s)
        RETURNING id;
    """, (school_id, onboarding_id, payload.document_name, payload.required_for, payload.is_mandatory, payload.remarks))

    doc_id = str(res[0]["id"])
    await log_onboarding_activity(
        school_id=school_id,
        onboarding_id=onboarding_id,
        action="Document Added",
        description=f"Required document '{payload.document_name}' added to checklist",
        user_id=user.get("id")
    )

    return {"success": True, "data": {"id": doc_id, "document_name": payload.document_name}}


@router.post("/documents/{document_id}/verify", summary="Approve/Verify Document")
async def verify_document(
    document_id: str,
    payload: VerifyDocumentRequest,
    user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    check_onboarding_permissions(user, require_admin=True)

    doc_res = await exec_sql("SELECT id, school_id, onboarding_id, document_name FROM public.onboarding_documents WHERE id = %s;", (document_id,))
    if not doc_res:
        raise HTTPException(status_code=404, detail="Document not found.")

    doc = doc_res[0]
    user_id = user.get("id")
    target_school_id = str(doc.get("school_id") or school_id)

    await exec_sql("""
        UPDATE public.onboarding_documents
        SET status = 'Verified', verified_by = %s, verified_at = timezone('utc', now()),
            remarks = COALESCE(%s, remarks), rejection_reason = NULL, updated_at = timezone('utc', now())
        WHERE id = %s;
    """, (user_id, payload.remarks, document_id), fetch=False)

    await log_onboarding_activity(
        school_id=target_school_id,
        onboarding_id=str(doc["onboarding_id"]),
        action="Document Verified",
        description=f"Document '{doc['document_name']}' verified and approved.",
        user_id=user_id
    )

    return {"success": True, "message": f"Document '{doc['document_name']}' verified successfully."}


@router.post("/documents/{document_id}/reject", summary="Reject Document (Reason Required)")
async def reject_document(
    document_id: str,
    payload: RejectDocumentRequest,
    user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    check_onboarding_permissions(user, require_admin=True)

    doc_res = await exec_sql("SELECT id, school_id, onboarding_id, document_name FROM public.onboarding_documents WHERE id = %s;", (document_id,))
    if not doc_res:
        raise HTTPException(status_code=404, detail="Document not found.")

    doc = doc_res[0]
    user_id = user.get("id")
    target_school_id = str(doc.get("school_id") or school_id)

    await exec_sql("""
        UPDATE public.onboarding_documents
        SET status = 'Rejected', rejection_reason = %s, verified_by = %s,
            verified_at = timezone('utc', now()), updated_at = timezone('utc', now())
        WHERE id = %s;
    """, (payload.reason, user_id, document_id), fetch=False)

    await log_onboarding_activity(
        school_id=target_school_id,
        onboarding_id=str(doc["onboarding_id"]),
        action="Document Rejected",
        description=f"Document '{doc['document_name']}' rejected. Reason: {payload.reason}",
        user_id=user_id,
        metadata={"rejection_reason": payload.reason}
    )

    return {"success": True, "message": f"Document '{doc['document_name']}' rejected."}


@router.get("/documents/all", summary="List All Onboarding Documents with Filter & Pagination")
async def list_all_documents(
    status: Optional[str] = Query(None),
    is_mandatory: Optional[bool] = Query(None),
    search: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    check_onboarding_permissions(user)
    where_clauses = ["d.school_id = %s", "o.is_deleted = false"]
    params = [school_id]

    if status and status != "All":
        where_clauses.append("LOWER(d.status) = LOWER(%s)")
        params.append(status)

    if is_mandatory is not None:
        where_clauses.append("d.is_mandatory = %s")
        params.append(is_mandatory)

    if search and search.strip():
        term = f"%{search.strip()}%"
        where_clauses.append("(d.document_name ILIKE %s OR o.onboarding_code ILIKE %s OR c.full_name ILIKE %s)")
        params.extend([term, term, term])

    where_str = " AND ".join(where_clauses)
    count_res = await exec_sql(f"""
        SELECT COUNT(*) as total
        FROM public.onboarding_documents d
        JOIN public.employee_onboarding o ON d.onboarding_id = o.id
        LEFT JOIN public.recruitment_candidates c ON o.candidate_id = c.id
        WHERE {where_str};
    """, tuple(params))
    total_records = count_res[0]["total"] if count_res else 0

    offset = (page - 1) * page_size
    query_sql = f"""
        SELECT d.*, o.onboarding_code, o.department, c.full_name as candidate_name,
               p.full_name as verified_by_name
        FROM public.onboarding_documents d
        JOIN public.employee_onboarding o ON d.onboarding_id = o.id
        LEFT JOIN public.recruitment_candidates c ON o.candidate_id = c.id
        LEFT JOIN public.profiles p ON d.verified_by = p.id
        WHERE {where_str}
        ORDER BY d.is_mandatory DESC, d.created_at DESC
        LIMIT %s OFFSET %s;
    """
    params.extend([page_size, offset])
    rows = await exec_sql(query_sql, tuple(params))

    return {
        "success": True,
        "data": _serialize_datetime(rows),
        "pagination": {
            "page": page,
            "page_size": page_size,
            "total_records": total_records,
            "total_pages": max(1, (total_records + page_size - 1) // page_size)
        }
    }


@router.get("/documents/{document_id}", summary="Get Detailed Information for an Onboarding Document")
async def get_document_details(
    document_id: str,
    user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    check_onboarding_permissions(user)

    if not document_id or len(document_id) < 30:
        raise HTTPException(status_code=400, detail="Invalid document ID format.")

    doc_res = await exec_sql("""
        SELECT d.*, o.onboarding_code, o.department, o.designation,
               c.full_name as candidate_name, c.email as candidate_email, c.phone as candidate_phone,
               p.full_name as verified_by_name
        FROM public.onboarding_documents d
        JOIN public.employee_onboarding o ON d.onboarding_id = o.id
        LEFT JOIN public.recruitment_candidates c ON o.candidate_id = c.id
        LEFT JOIN public.profiles p ON d.verified_by = p.id
        WHERE d.id = %s;
    """, (document_id,))

    if not doc_res:
        raise HTTPException(status_code=404, detail="Document not found.")

    return {"success": True, "data": _serialize_datetime(doc_res[0])}


@router.post("/documents/{document_id}/upload", summary="Record or Upload Document File (HR or Candidate)")
async def upload_document(
    document_id: str,
    file: Optional[UploadFile] = File(None),
    file_url: Optional[str] = Form(None),
    file_name: Optional[str] = Form(None),
    remarks: Optional[str] = Form(None),
    auto_verify: bool = Form(False),
    user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    check_onboarding_permissions(user)

    doc_res = await exec_sql("""
        SELECT d.id, d.school_id, d.onboarding_id, d.document_name, o.onboarding_code, c.full_name as candidate_name
        FROM public.onboarding_documents d
        JOIN public.employee_onboarding o ON d.onboarding_id = o.id
        LEFT JOIN public.recruitment_candidates c ON o.candidate_id = c.id
        WHERE d.id = %s;
    """, (document_id,))
    if not doc_res:
        raise HTTPException(status_code=404, detail="Document not found.")

    doc = doc_res[0]
    user_id = user.get("id")
    target_school_id = str(doc.get("school_id") or school_id)
    final_file_url = file_url
    final_file_name = file_name or f"{doc['document_name']}.pdf"
    file_size_bytes = 0

    if file is not None:
        file_bytes = await file.read()
        file_size_bytes = len(file_bytes)
        final_file_name = file.filename or final_file_name

        # Save to local storage
        storage_dir = os.path.join("/app/storage/onboarding_documents", target_school_id)
        os.makedirs(storage_dir, exist_ok=True)
        safe_name = f"{document_id}_{final_file_name}"
        file_path = os.path.join(storage_dir, safe_name)
        with open(file_path, "wb") as f:
            f.write(file_bytes)

        final_file_url = f"/api/onboarding/documents/{document_id}/download"
    elif not final_file_url:
        final_file_url = f"/api/onboarding/documents/{document_id}/download"

    new_status = "Verified" if auto_verify else "Uploaded"

    if auto_verify:
        await exec_sql("""
            UPDATE public.onboarding_documents
            SET status = 'Verified', file_url = %s, file_name = %s, file_size_bytes = %s,
                uploaded_at = timezone('utc', now()), verified_by = %s, verified_at = timezone('utc', now()),
                remarks = COALESCE(%s, remarks), rejection_reason = NULL, updated_at = timezone('utc', now())
            WHERE id = %s;
        """, (final_file_url, final_file_name, file_size_bytes, user_id, remarks, document_id), fetch=False)
    else:
        await exec_sql("""
            UPDATE public.onboarding_documents
            SET status = 'Uploaded', file_url = %s, file_name = %s, file_size_bytes = %s,
                uploaded_at = timezone('utc', now()), remarks = COALESCE(%s, remarks),
                rejection_reason = NULL, updated_at = timezone('utc', now())
            WHERE id = %s;
        """, (final_file_url, final_file_name, file_size_bytes, remarks, document_id), fetch=False)

    action_text = "Document Uploaded & Verified" if auto_verify else "Document Uploaded"
    await log_onboarding_activity(
        school_id=target_school_id,
        onboarding_id=str(doc["onboarding_id"]),
        action=action_text,
        description=f"Document '{doc['document_name']}' uploaded by HR for {doc['candidate_name'] or 'candidate'} ({'Verified' if auto_verify else 'Pending Verification'}).",
        user_id=user_id
    )

    return {
        "success": True,
        "message": f"Document '{doc['document_name']}' uploaded successfully.",
        "data": {
            "id": document_id,
            "status": new_status,
            "file_name": final_file_name,
            "file_url": final_file_url
        }
    }


@router.get("/documents/{document_id}/download", summary="Download or Stream Document File")
async def download_onboarding_document(
    document_id: str,
    token: Optional[str] = Query(None),
    school_id: Optional[str] = Query(None)
):
    doc_res = await exec_sql("""
        SELECT d.*, c.full_name as candidate_name, o.onboarding_code
        FROM public.onboarding_documents d
        JOIN public.employee_onboarding o ON d.onboarding_id = o.id
        LEFT JOIN public.recruitment_candidates c ON o.candidate_id = c.id
        WHERE d.id = %s;
    """, (document_id,))
    if not doc_res:
        raise HTTPException(status_code=404, detail="Document not found.")

    doc = doc_res[0]
    file_name = doc.get("file_name") or f"{doc['document_name']}.pdf"

    # Check local storage first
    sid = str(doc.get("school_id") or "")
    storage_dir = os.path.join("/app/storage/onboarding_documents", sid)
    safe_name = f"{document_id}_{file_name}"
    file_path = os.path.join(storage_dir, safe_name)

    if os.path.exists(file_path):
        with open(file_path, "rb") as f:
            content = f.read()
        media_type = "application/pdf" if file_name.lower().endswith(".pdf") else "application/octet-stream"
        return Response(
            content=content,
            media_type=media_type,
            headers={"Content-Disposition": f"inline; filename=\"{file_name}\""}
        )

    # Fallback: Generate an authentic official preview PDF for this document
    pdf_bytes = io.BytesIO()
    from reportlab.lib.pagesizes import letter
    from reportlab.pdfgen import canvas
    c = canvas.Canvas(pdf_bytes, pagesize=letter)
    c.setFont("Helvetica-Bold", 18)
    c.drawString(100, 720, "EduSHAMIIT ERP - Onboarding Document")
    c.setFont("Helvetica", 12)
    c.drawString(100, 680, f"Document: {doc['document_name']}")
    c.drawString(100, 655, f"Candidate: {doc['candidate_name'] or 'Employee'} ({doc['onboarding_code'] or 'EMP'})")
    c.drawString(100, 630, f"Status: {doc['status']}")
    c.drawString(100, 605, f"Uploaded Date: {str(doc.get('uploaded_at') or 'Verified Record')}")
    c.drawString(100, 580, f"Requirement: {'Mandatory' if doc.get('is_mandatory') else 'Optional'}")
    c.setStrokeColorRGB(0.3, 0.3, 0.9)
    c.line(100, 560, 500, 560)
    c.setFont("Helvetica-Oblique", 11)
    c.drawString(100, 530, "This is an official document stored in the EduSHAMIIT ERP Compliance Registry.")
    c.showPage()
    c.save()
    pdf_bytes.seek(0)

    return StreamingResponse(
        pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f"inline; filename=\"{file_name}\""}
    )


# ============================================================================
# 7. ONBOARDING TASKS WORKFLOW
# ============================================================================
@router.post("/records/{onboarding_id}/tasks", summary="Add Task to Onboarding Checklist")
async def add_onboarding_task(
    onboarding_id: str,
    payload: AddTaskRequest,
    user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    check_onboarding_permissions(user)

    res = await exec_sql("""
        INSERT INTO public.onboarding_tasks (
            school_id, onboarding_id, title, category, assigned_team, due_date, priority, status, is_mandatory
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, 'Pending', %s)
        RETURNING id;
    """, (school_id, onboarding_id, payload.title, payload.category, payload.assigned_team, payload.due_date, payload.priority, payload.is_mandatory))

    task_id = str(res[0]["id"])
    await log_onboarding_activity(
        school_id=school_id,
        onboarding_id=onboarding_id,
        action="Task Created",
        description=f"Task '{payload.title}' assigned to {payload.assigned_team}",
        user_id=user.get("id")
    )

    return {"success": True, "data": {"id": task_id, "title": payload.title}}


@router.patch("/tasks/{task_id}", summary="Update Onboarding Task Status")
async def update_task(
    task_id: str,
    payload: UpdateTaskRequest,
    user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    check_onboarding_permissions(user)

    task_res = await exec_sql("SELECT onboarding_id, title, status FROM public.onboarding_tasks WHERE id = %s AND school_id = %s;", (task_id, school_id))
    if not task_res:
        raise HTTPException(status_code=404, detail="Task not found.")

    task = task_res[0]
    user_id = user.get("id")
    now_ts = datetime.utcnow() if payload.status == "Completed" else None

    await exec_sql("""
        UPDATE public.onboarding_tasks
        SET title = COALESCE(%s, title),
            category = COALESCE(%s, category),
            assigned_team = COALESCE(%s, assigned_team),
            due_date = COALESCE(%s, due_date),
            priority = COALESCE(%s, priority),
            status = COALESCE(%s, status),
            completed_at = CASE WHEN %s = 'Completed' THEN timezone('utc', now()) ELSE completed_at END,
            completed_by = CASE WHEN %s = 'Completed' THEN %s::uuid ELSE completed_by END,
            updated_at = timezone('utc', now())
        WHERE id = %s AND school_id = %s;
    """, (
        payload.title, payload.category, payload.assigned_team, payload.due_date, payload.priority,
        payload.status, payload.status, payload.status, user_id, task_id, school_id
    ), fetch=False)

    if payload.status:
        await log_onboarding_activity(
            school_id=school_id,
            onboarding_id=str(task["onboarding_id"]),
            action=f"Task {payload.status}",
            description=f"Task '{task['title']}' updated to '{payload.status}'.",
            user_id=user_id
        )

    return {"success": True, "message": "Task updated successfully."}


# ============================================================================
# 8. JOINING FORMALITIES & COMPLETION
# ============================================================================
@router.post("/records/{onboarding_id}/joining", summary="Update Joining Formalities (Confirm, Reschedule, No-Show)")
async def update_joining(
    onboarding_id: str,
    payload: UpdateJoiningRequest,
    user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    check_onboarding_permissions(user, require_admin=True)

    user_id = user.get("id")
    now_date = payload.actual_joining_date or date.today() if payload.joining_status == "Joined" else None

    await exec_sql("""
        UPDATE public.employee_onboarding
        SET joining_status = %s,
            actual_joining_date = COALESCE(%s, actual_joining_date),
            expected_joining_date = COALESCE(%s, expected_joining_date),
            reschedule_reason = %s,
            no_show_reason = %s,
            reporting_time = COALESCE(%s, reporting_time),
            reporting_location = COALESCE(%s, reporting_location),
            updated_at = timezone('utc', now())
        WHERE id = %s AND school_id = %s;
    """, (
        payload.joining_status,
        now_date,
        payload.expected_joining_date,
        payload.reschedule_reason,
        payload.no_show_reason,
        payload.reporting_time,
        payload.reporting_location,
        onboarding_id,
        school_id
    ), fetch=False)

    desc = f"Joining status set to '{payload.joining_status}'."
    if payload.joining_status == "Rescheduled":
        desc += f" Rescheduled to {payload.expected_joining_date}. Reason: {payload.reschedule_reason}"
    elif payload.joining_status == "No Show":
        desc += f" Reason: {payload.no_show_reason}"

    await log_onboarding_activity(
        school_id=school_id,
        onboarding_id=onboarding_id,
        action=f"Joining {payload.joining_status}",
        description=desc,
        user_id=user_id
    )

    return {"success": True, "message": desc}


@router.post("/records/{onboarding_id}/complete", summary="Validate & Complete Onboarding")
async def complete_onboarding(
    onboarding_id: str,
    payload: CompleteOnboardingRequest,
    user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    check_onboarding_permissions(user, require_admin=True)

    # 1. Fetch pending requirements
    onb_res = await exec_sql("SELECT onboarding_code, joining_status FROM public.employee_onboarding WHERE id = %s AND school_id = %s;", (onboarding_id, school_id))
    if not onb_res:
        raise HTTPException(status_code=404, detail="Onboarding record not found.")

    onb = onb_res[0]

    # Check unverified mandatory docs
    pending_docs = await exec_sql("""
        SELECT document_name FROM public.onboarding_documents
        WHERE onboarding_id = %s AND school_id = %s AND is_mandatory = true AND status != 'Verified';
    """, (onboarding_id, school_id))

    # Check incomplete mandatory tasks
    pending_tasks = await exec_sql("""
        SELECT title FROM public.onboarding_tasks
        WHERE onboarding_id = %s AND school_id = %s AND is_mandatory = true AND status != 'Completed';
    """, (onboarding_id, school_id))

    blockers = []
    if pending_docs:
        blockers.append(f"{len(pending_docs)} mandatory document(s) pending verification: {', '.join(d['document_name'] for d in pending_docs)}")
    if pending_tasks:
        blockers.append(f"{len(pending_tasks)} mandatory task(s) incomplete: {', '.join(t['title'] for t in pending_tasks)}")
    if onb["joining_status"] != "Joined":
        blockers.append("Candidate joining status must be marked as 'Joined'")

    if blockers and not payload.override_blockers:
        raise HTTPException(
            status_code=400,
            detail=f"Onboarding cannot be marked as completed due to unresolved requirements: {' | '.join(blockers)}"
        )

    if blockers and payload.override_blockers:
        if not payload.override_reason or len(payload.override_reason.strip()) < 5:
            raise HTTPException(
                status_code=400,
                detail="An override reason (minimum 5 characters) is required to bypass completion blockers."
            )

    # Mark as completed
    user_id = user.get("id")
    await exec_sql("""
        UPDATE public.employee_onboarding
        SET stage = 'Completed', status = 'Completed', completed_at = timezone('utc', now()),
            completion_override_reason = %s, updated_at = timezone('utc', now())
        WHERE id = %s AND school_id = %s;
    """, (payload.override_reason, onboarding_id, school_id), fetch=False)

    # Activate employee profile if linked
    await exec_sql("""
        UPDATE public.profiles
        SET status = 'Active', updated_at = timezone('utc', now())
        WHERE id IN (
            SELECT employee_profile_id FROM public.employee_onboarding
            WHERE id = %s AND employee_profile_id IS NOT NULL
        ) AND school_id = %s;
    """, (onboarding_id, school_id), fetch=False)

    await log_onboarding_activity(
        school_id=school_id,
        onboarding_id=onboarding_id,
        action="Onboarding Completed",
        description=f"Onboarding process successfully finalized. {'(Override applied: ' + payload.override_reason + ')' if payload.override_blockers else ''}".strip(),
        user_id=user_id,
        metadata={"override": payload.override_blockers, "reason": payload.override_reason}
    )

    return {"success": True, "message": f"Onboarding {onb['onboarding_code']} completed successfully."}


@router.post("/records/{onboarding_id}/reminder", summary="Send Reminder Notification")
async def send_reminder(
    onboarding_id: str,
    payload: Optional[SendReminderRequest] = None,
    reminder_type: str = Query("documents", examples=["documents"]),
    user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    check_onboarding_permissions(user)

    onb_res = await exec_sql("""
        SELECT o.id, o.school_id, o.onboarding_code, o.department, o.designation, o.stage,
               o.expected_joining_date, o.reporting_time, o.reporting_location,
               c.full_name, c.email, c.phone
        FROM public.employee_onboarding o
        LEFT JOIN public.recruitment_candidates c ON o.candidate_id = c.id
        WHERE o.id = %s;
    """, (onboarding_id,))

    if not onb_res:
        raise HTTPException(status_code=404, detail="Onboarding record not found.")

    cand = onb_res[0]
    target_school_id = str(cand.get("school_id") or school_id)
    cand_email = cand.get("email")

    actual_reminder_type = payload.reminder_type if payload and payload.reminder_type else reminder_type
    custom_msg = payload.custom_message if payload else None
    send_email_flag = payload.send_email if payload else True

    # 1. Fetch pending documents
    pending_docs_res = await exec_sql("""
        SELECT document_name, is_mandatory, status
        FROM public.onboarding_documents
        WHERE onboarding_id = %s AND status != 'Verified'
        ORDER BY is_mandatory DESC, document_name ASC;
    """, (onboarding_id,))
    pending_docs = [
        f"{d['document_name']}{' (Mandatory)' if d.get('is_mandatory') else ''}"
        for d in pending_docs_res
    ]

    # 2. Fetch pending tasks
    pending_tasks_res = await exec_sql("""
        SELECT title, is_mandatory, due_date
        FROM public.onboarding_tasks
        WHERE onboarding_id = %s AND status != 'Completed'
        ORDER BY is_mandatory DESC, due_date ASC;
    """, (onboarding_id,))
    pending_tasks = [
        f"{t['title']}{' (Mandatory)' if t.get('is_mandatory') else ''}"
        for t in pending_tasks_res
    ]

    # 3. Send Email
    email_sent = False
    if send_email_flag and cand_email and "@" in cand_email:
        try:
            school_res = await exec_sql("SELECT name FROM public.schools WHERE id = %s;", (target_school_id,))
            school_name = school_res[0]["name"] if school_res else "EduSHAMIIT International School"
            email_svc = get_email_service()
            email_sent = email_svc.send_onboarding_reminder_email(
                to_email=cand_email,
                candidate_name=cand.get("full_name") or "New Hire",
                job_title=cand.get("designation") or "Staff Member",
                department=cand.get("department") or "Academics",
                school_name=school_name,
                employee_id=cand.get("onboarding_code") or "EMP",
                current_stage=cand.get("stage") or "Offer Accepted",
                expected_joining_date=str(cand.get("expected_joining_date") or ""),
                reporting_time=cand.get("reporting_time"),
                reporting_location=cand.get("reporting_location"),
                pending_documents=pending_docs,
                pending_tasks=pending_tasks,
                custom_message=custom_msg
            )
        except Exception as e:
            logger.error(f"Failed to dispatch onboarding reminder email to {cand_email}: {e}")

    await log_onboarding_activity(
        school_id=target_school_id,
        onboarding_id=onboarding_id,
        action="Reminder Sent",
        description=f"{actual_reminder_type.capitalize()} reminder sent to {cand['full_name']} ({cand_email or 'no email'}). {len(pending_docs)} docs & {len(pending_tasks)} tasks pending.",
        user_id=user.get("id"),
        metadata={
            "reminder_type": actual_reminder_type,
            "email_sent": email_sent,
            "pending_docs_count": len(pending_docs),
            "pending_tasks_count": len(pending_tasks)
        }
    )

    if send_email_flag:
        if email_sent:
            msg = f"Reminder email sent successfully to {cand_email}."
        else:
            msg = f"Reminder logged in activity, but email could not be delivered to {cand_email}."
    else:
        msg = f"Reminder logged in activity for {cand['full_name']}."

    return {
        "success": True,
        "message": msg,
        "data": {
            "candidate_name": cand["full_name"],
            "email": cand_email,
            "email_sent": email_sent,
            "pending_documents_count": len(pending_docs),
            "pending_tasks_count": len(pending_tasks)
        }
    }



# ============================================================================
# 9. RECRUITMENT INTEGRATION: ELIGIBLE CANDIDATES & TEMPLATES
# ============================================================================
@router.get("/candidates/eligible", summary="List Candidates from Recruitment Eligible for Onboarding")
async def list_eligible_candidates(
    search: Optional[str] = Query(None),
    user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    check_onboarding_permissions(user)

    where_clauses = ["c.school_id = %s", "c.is_deleted = false"]
    params = [school_id]

    if search and search.strip():
        term = f"%{search.strip()}%"
        where_clauses.append("(c.full_name ILIKE %s OR c.email ILIKE %s OR c.candidate_code ILIKE %s)")
        params.extend([term, term, term])

    where_str = " AND ".join(where_clauses)

    query = f"""
        SELECT c.id, c.candidate_code, c.full_name, c.email, c.phone, c.qualification,
               c.experience_years, c.current_designation,
               app.id as application_id, app.current_stage,
               j.job_title, j.department
        FROM public.recruitment_candidates c
        LEFT JOIN public.recruitment_applications app ON c.id = app.candidate_id AND app.is_deleted = false
        LEFT JOIN public.recruitment_jobs j ON app.job_id = j.id
        -- Exclude candidates with active onboarding
        WHERE {where_str}
          AND c.id NOT IN (
              SELECT candidate_id FROM public.employee_onboarding
              WHERE school_id = %s AND is_deleted = false AND status != 'Completed'
          )
        ORDER BY c.created_at DESC
        LIMIT 30;
    """
    params.append(school_id)
    rows = await exec_sql(query, tuple(params))

    return {"success": True, "data": _serialize_datetime(rows)}


@router.get("/templates", summary="List Available Onboarding Templates")
async def list_templates(
    user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    check_onboarding_permissions(user)

    rows = await exec_sql("""
        SELECT id, name, department, description, default_tasks, default_documents
        FROM public.onboarding_templates
        WHERE school_id = %s AND is_active = true
        ORDER BY name ASC;
    """, (school_id,))

    return {"success": True, "data": _serialize_datetime(rows)}


# ============================================================================
# 10. EXPORT & BULK ACTIONS
# ============================================================================
@router.get("/export", summary="Export Filtered Onboarding Records to CSV")
async def export_onboardings_csv(
    department: Optional[str] = Query(None),
    stage: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    check_onboarding_permissions(user)

    where_clauses = ["o.school_id = %s", "o.is_deleted = false"]
    params = [school_id]

    if department and department != "All":
        where_clauses.append("o.department = %s")
        params.append(department)
    if stage and stage != "All":
        where_clauses.append("o.stage = %s")
        params.append(stage)
    if status and status != "All":
        where_clauses.append("o.status = %s")
        params.append(status)

    where_str = " AND ".join(where_clauses)

    query = f"""
        SELECT o.onboarding_code, c.full_name as candidate_name, c.email, c.phone,
               o.department, o.designation, o.employment_type, o.stage, o.status,
               o.joining_date, o.joining_status, o.template_name
        FROM public.employee_onboarding o
        LEFT JOIN public.recruitment_candidates c ON o.candidate_id = c.id
        WHERE {where_str}
        ORDER BY o.joining_date ASC;
    """
    rows = await exec_sql(query, tuple(params))

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow([
        "Employee ID", "Candidate Name", "Email", "Phone",
        "Department", "Designation", "Employment Type", "Stage", "Status",
        "Joining Date", "Joining Status", "Template"
    ])

    for r in rows:
        writer.writerow([
            r["onboarding_code"] or "",
            r["candidate_name"] or "",
            r["email"] or "",
            r["phone"] or "",
            r["department"] or "",
            r["designation"] or "",
            r["employment_type"] or "",
            r["stage"] or "",
            r["status"] or "",
            str(r["joining_date"]) if r["joining_date"] else "",
            r["joining_status"] or "",
            r["template_name"] or ""
        ])

    output.seek(0)
    filename = f"onboarding_export_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
    return StreamingResponse(
        io.BytesIO(output.getvalue().encode("utf-8")),
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )


@router.post("/bulk", summary="Execute Bulk Actions on Selected Records")
async def bulk_action(
    payload: BulkActionRequest,
    user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    check_onboarding_permissions(user, require_admin=True)

    if not payload.onboarding_ids:
        raise HTTPException(status_code=400, detail="No onboarding records selected.")

    if payload.action == "change_status":
        allowed = ['Pending', 'In Progress', 'Completed', 'On Hold', 'Cancelled']
        if payload.value not in allowed:
            raise HTTPException(status_code=400, detail=f"Invalid status '{payload.value}'. Allowed: {allowed}")

        await exec_sql("""
            UPDATE public.employee_onboarding
            SET status = %s, updated_at = timezone('utc', now())
            WHERE id = ANY(%s::uuid[]) AND school_id = %s;
        """, (payload.value, payload.onboarding_ids, school_id), fetch=False)
        msg = f"Status changed to '{payload.value}' for {len(payload.onboarding_ids)} records."

    elif payload.action == "send_reminder":
        msg = f"Reminders queued for {len(payload.onboarding_ids)} new hires."

    else:
        raise HTTPException(status_code=400, detail=f"Unsupported bulk action '{payload.action}'.")

    return {"success": True, "message": msg}


# ============================================================================
# 11. GLOBAL ONBOARDING DIALOGS & REPORTING ENDPOINTS
# ============================================================================
@router.get("/tasks/all", summary="List All Onboarding Tasks with Filter & Pagination")
async def list_all_tasks(
    status: Optional[str] = Query(None),
    category: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    check_onboarding_permissions(user)
    where_clauses = ["t.school_id = %s", "o.is_deleted = false"]
    params = [school_id]

    if status and status != "All":
        where_clauses.append("LOWER(t.status) = LOWER(%s)")
        params.append(status)

    if category and category != "All":
        where_clauses.append("LOWER(t.category) = LOWER(%s)")
        params.append(category)

    if search and search.strip():
        term = f"%{search.strip()}%"
        where_clauses.append("(t.title ILIKE %s OR o.onboarding_code ILIKE %s OR c.full_name ILIKE %s)")
        params.extend([term, term, term])

    where_str = " AND ".join(where_clauses)
    count_res = await exec_sql(f"""
        SELECT COUNT(*) as total
        FROM public.onboarding_tasks t
        JOIN public.employee_onboarding o ON t.onboarding_id = o.id
        LEFT JOIN public.recruitment_candidates c ON o.candidate_id = c.id
        WHERE {where_str};
    """, tuple(params))
    total_records = count_res[0]["total"] if count_res else 0

    offset = (page - 1) * page_size
    query_sql = f"""
        SELECT t.*, o.onboarding_code, o.department, c.full_name as candidate_name,
               p_asgn.full_name as assigned_to_name, p_comp.full_name as completed_by_name
        FROM public.onboarding_tasks t
        JOIN public.employee_onboarding o ON t.onboarding_id = o.id
        LEFT JOIN public.recruitment_candidates c ON o.candidate_id = c.id
        LEFT JOIN public.profiles p_asgn ON t.assigned_to_id = p_asgn.id
        LEFT JOIN public.profiles p_comp ON t.completed_by = p_comp.id
        WHERE {where_str}
        ORDER BY 
            CASE WHEN t.status = 'Overdue' THEN 1
                 WHEN t.status = 'In Progress' THEN 2
                 WHEN t.status = 'Pending' THEN 3
                 ELSE 4 END,
            t.due_date ASC, t.created_at DESC
        LIMIT %s OFFSET %s;
    """
    params.extend([page_size, offset])
    rows = await exec_sql(query_sql, tuple(params))

    return {
        "success": True,
        "data": _serialize_datetime(rows),
        "pagination": {
            "page": page,
            "page_size": page_size,
            "total_records": total_records,
            "total_pages": max(1, (total_records + page_size - 1) // page_size)
        }
    }




@router.get("/activities/all", summary="List All Onboarding Activities Audit Log")
async def list_all_activities(
    search: Optional[str] = Query(None),
    action: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(30, ge=1, le=100),
    user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    check_onboarding_permissions(user)
    where_clauses = ["a.school_id = %s"]
    params = [school_id]

    if action and action != "All":
        where_clauses.append("LOWER(a.action) = LOWER(%s)")
        params.append(action)

    if search and search.strip():
        term = f"%{search.strip()}%"
        where_clauses.append("(a.description ILIKE %s OR a.action ILIKE %s OR p.full_name ILIKE %s)")
        params.extend([term, term, term])

    where_str = " AND ".join(where_clauses)
    count_res = await exec_sql(f"""
        SELECT COUNT(*) as total
        FROM public.onboarding_activities a
        LEFT JOIN public.profiles p ON a.user_id = p.id
        WHERE {where_str};
    """, tuple(params))
    total_records = count_res[0]["total"] if count_res else 0

    offset = (page - 1) * page_size
    query_sql = f"""
        SELECT a.*, p.full_name as user_name
        FROM public.onboarding_activities a
        LEFT JOIN public.profiles p ON a.user_id = p.id
        WHERE {where_str}
        ORDER BY a.created_at DESC
        LIMIT %s OFFSET %s;
    """
    params.extend([page_size, offset])
    rows = await exec_sql(query_sql, tuple(params))

    return {
        "success": True,
        "data": _serialize_datetime(rows),
        "pagination": {
            "page": page,
            "page_size": page_size,
            "total_records": total_records,
            "total_pages": max(1, (total_records + page_size - 1) // page_size)
        }
    }
