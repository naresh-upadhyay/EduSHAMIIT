"""
Enterprise Universal Work Management API
EduSHAMIIT Multi-Tenant School ERP Platform
Provides high-performance endpoints executing PostgreSQL stored procedures and functions for
Kanban Boards, Data Grid Lists, Backlog Hierarchy, Sprint Iterations, and Academic Homework.
"""

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status, UploadFile, File
from fastapi.responses import FileResponse, RedirectResponse
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any, Union
from datetime import datetime, date, time
import io
import os
import re
import csv
import json
import uuid
import mimetypes
import logging
import asyncio
import psycopg2
from psycopg2.extras import RealDictCursor, register_uuid

register_uuid()

from app.config import settings
from app.middleware.auth import get_current_user_optional as get_current_user

logger = logging.getLogger(__name__)
router = APIRouter()


def safe_uuid(val: Optional[Any]) -> Optional[str]:
    """Safely converts string or value to a valid UUID string, or returns None if invalid or placeholder."""
    if hasattr(val, "default"):
        val = val.default
    if val is None:
        return None
    s = str(val).strip()
    if s.lower() in ("default", "null", "undefined", "none", "s8", "current", "all", ""):
        return None
    try:
        u = uuid.UUID(s)
        return str(u)
    except (ValueError, AttributeError):
        return None


def safe_str(val: Any, default: Optional[str] = None) -> Optional[str]:
    """Safely extracts string from FastAPI Query parameter or plain value."""
    if hasattr(val, "default"):
        val = val.default
    if val is None:
        return default
    return str(val)


def safe_int(val: Any, default: int = 1) -> int:
    """Safely extracts int from FastAPI Query parameter or plain value."""
    if hasattr(val, "default"):
        val = val.default
    try:
        return int(val)
    except Exception:
        return default


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


async def resolve_board_id(board_id: Optional[str], school_id: str) -> Optional[str]:
    """
    Resolves a UUID string, shorthand identifier ('default', 'academic', 'infra', 'it', 'all')
    or board name ('Institute Work Board', 'Academic Board', 'IT & Infra Board') to board UUID.
    Returns None for 'all', 'none', etc.
    """
    if not board_id or str(board_id).strip().lower() in ("all", "none", "null", "undefined", "*", "all boards", ""):
        return None
    clean = safe_uuid(board_id)
    if clean:
        return clean
    b_str = str(board_id).strip().lower()
    if b_str in ("default", "institute", "iwb", "institute work board"):
        rows = await exec_sql(
            "SELECT id FROM public.work_boards WHERE (school_id = %s::UUID OR %s::UUID IS NULL) AND (code = 'IWB' OR name ILIKE %s) LIMIT 1;",
            (school_id, school_id, '%Institute%')
        )
        if not rows:
            rows = await exec_sql("SELECT id FROM public.work_boards WHERE (code = 'IWB' OR name ILIKE %s) LIMIT 1;", ('%Institute%',))
        if rows:
            return str(rows[0]["id"])
    elif b_str in ("academic", "acb", "academic board"):
        rows = await exec_sql(
            "SELECT id FROM public.work_boards WHERE (school_id = %s::UUID OR %s::UUID IS NULL) AND (code = 'ACB' OR name ILIKE %s) LIMIT 1;",
            (school_id, school_id, '%Academic%')
        )
        if not rows:
            rows = await exec_sql("SELECT id FROM public.work_boards WHERE (code = 'ACB' OR name ILIKE %s) LIMIT 1;", ('%Academic%',))
        if rows:
            return str(rows[0]["id"])
    elif b_str in ("it", "infra", "it & infra", "it & infra board", "itb"):
        rows = await exec_sql(
            "SELECT id FROM public.work_boards WHERE (school_id = %s::UUID OR %s::UUID IS NULL) AND (code = 'ITB' OR name ILIKE %s OR name ILIKE %s) LIMIT 1;",
            (school_id, school_id, '%Infra%', '%IT & Infra%')
        )
        if not rows:
            rows = await exec_sql("SELECT id FROM public.work_boards WHERE (code = 'ITB' OR name ILIKE %s OR name ILIKE %s) LIMIT 1;", ('%Infra%', '%IT & Infra%'))
        if rows:
            return str(rows[0]["id"])
    rows = await exec_sql(
        "SELECT id FROM public.work_boards WHERE (school_id = %s::UUID OR %s::UUID IS NULL) AND (name ILIKE %s OR code ILIKE %s) LIMIT 1;",
        (school_id, school_id, f"%{str(board_id).strip()}%", str(board_id).strip())
    )
    if not rows:
        rows = await exec_sql(
            "SELECT id FROM public.work_boards WHERE (name ILIKE %s OR code ILIKE %s) LIMIT 1;",
            (f"%{str(board_id).strip()}%", str(board_id).strip())
        )
    return str(rows[0]["id"]) if rows else None


async def resolve_sprint_id(sprint_id: Optional[str], school_id: str) -> Optional[str]:
    """
    Resolves a UUID string, shorthand identifier ('s8', 'sprint-8', '8', 'current')
    or falls back to the active sprint for the school. Returns None for 'all', 'none', etc.
    """
    if not sprint_id or str(sprint_id).strip().lower() in ("all", "none", "null", "undefined", "backlog", "no_sprint", ""):
        return None
    clean = safe_uuid(sprint_id)
    if clean:
        return clean
    s_str = str(sprint_id).strip()

    # 1. Match by sprint name first (e.g. "Sprint 103 (Active)", "Sprint 103", "Sprint 9", "Sprint 8")
    clean_name = s_str.split('(')[0].strip()
    if clean_name:
        rows = await exec_sql(
            "SELECT id FROM public.work_sprints WHERE (school_id = %s::UUID OR %s::UUID IS NULL) AND (name ILIKE %s OR name = %s) ORDER BY sprint_number DESC LIMIT 1;",
            (school_id, school_id, f"%{clean_name}%", clean_name)
        )
        if rows:
            return str(rows[0]["id"])

    # 2. Match by sprint_number
    num_match = re.search(r'\d+', s_str)
    if num_match:
        s_num = int(num_match.group(0))
        rows = await exec_sql(
            "SELECT id FROM public.work_sprints WHERE (school_id = %s::UUID OR %s::UUID IS NULL) AND sprint_number = %s LIMIT 1;",
            (school_id, school_id, s_num)
        )
        if rows:
            return str(rows[0]["id"])

    # 3. Fallback to active sprint
    rows = await exec_sql(
        "SELECT id FROM public.work_sprints WHERE (school_id = %s::UUID OR %s::UUID IS NULL) AND status = 'ACTIVE' ORDER BY start_date DESC LIMIT 1;",
        (school_id, school_id)
    )
    if rows:
        return str(rows[0]["id"])
    rows2 = await exec_sql(
        "SELECT id FROM public.work_sprints WHERE (school_id = %s::UUID OR %s::UUID IS NULL) ORDER BY start_date DESC LIMIT 1;",
        (school_id, school_id)
    )
    return str(rows2[0]["id"]) if rows2 else None


# ============================================================================
# REQUEST & RESPONSE SCHEMAS
# ============================================================================

class CreateWorkItemRequest(BaseModel):
    board_id: Optional[str] = None
    title: str = Field(..., description="Title of the work item")
    description: Optional[str] = None
    work_type: str = Field("TASK", description="EPIC, STORY, TASK, SUBTASK, BUG, ISSUE, HOMEWORK, ASSIGNMENT, IMPROVEMENT, REQUEST, MILESTONE")
    priority: str = Field("MEDIUM", description="CRITICAL, URGENT, HIGH, MEDIUM, LOW")
    status: str = Field("NEW", description="NEW, ACTIVE, IN_PROGRESS, RESOLVED, COMPLETED, BLOCKED, ON_HOLD")
    category: Optional[str] = "General"
    parent_id: Optional[str] = None
    sprint_id: Optional[str] = None
    start_date: Optional[str] = None
    due_date: Optional[str] = None
    estimated_hours: Optional[float] = 0.0
    story_points: Optional[float] = 0.0
    assignee_ids: Optional[List[str]] = None
    labels: Optional[List[str]] = None
    team_id: Optional[str] = None
    team_name: Optional[str] = None

    # Bulk Assignment & Targeting
    assignment_mode: Optional[str] = "INDIVIDUAL"  # INDIVIDUAL, ROLE, CLASS_SECTION
    target_role: Optional[str] = None              # teacher, student, admin, staff, etc.
    class_id: Optional[str] = None
    class_name: Optional[str] = None
    section_id: Optional[str] = None
    section_name: Optional[str] = None
    subject_id: Optional[str] = None
    subject_name: Optional[str] = None
    department: Optional[str] = None
    is_class_wide: Optional[bool] = False
    max_marks: Optional[float] = 0.0
    submission_deadline: Optional[str] = None

    # Bug specific
    affected_module: Optional[str] = None
    severity: Optional[str] = None
    reproduction_steps: Optional[str] = None

    # Team assignment
    team_id: Optional[str] = None
    team_name: Optional[str] = None


class PreviewAssigneesRequest(BaseModel):
    assignment_mode: str = "INDIVIDUAL"
    target_role: Optional[str] = None
    class_id: Optional[str] = None
    class_name: Optional[str] = None
    section_id: Optional[str] = None
    section_name: Optional[str] = None
    department: Optional[str] = None
    q: Optional[str] = None
    limit: Optional[int] = 100


class UpdateWorkItemRequest(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    work_type: Optional[str] = None
    priority: Optional[str] = None
    status: Optional[str] = None
    category: Optional[str] = None
    board_id: Optional[str] = None
    parent_id: Optional[str] = None
    sprint_id: Optional[str] = None
    start_date: Optional[str] = None
    due_date: Optional[str] = None
    progress_percentage: Optional[int] = None
    estimated_hours: Optional[float] = None
    remaining_hours: Optional[float] = None
    actual_hours: Optional[float] = None
    story_points: Optional[float] = None
    severity: Optional[str] = None
    reason: Optional[str] = None
    assignee_ids: Optional[List[str]] = None
    labels: Optional[List[str]] = None
    team_id: Optional[str] = None
    team_name: Optional[str] = None


class CopyWorkItemRequest(BaseModel):
    new_title: Optional[str] = None
    include_children: bool = True
    include_attachments: bool = True


class LinkWorkItemRequest(BaseModel):
    target_id: str
    link_type: str = "RELATED"


class UpdateLinkRelationshipRequest(BaseModel):
    link_type: str = "RELATED"


class AddAttachmentRequest(BaseModel):
    file_name: str
    file_url: str
    file_size_bytes: Optional[int] = 0
    file_type: Optional[str] = "document"


class TransitionStatusRequest(BaseModel):
    new_status: str
    notes: Optional[str] = None


class ReorderKanbanRequest(BaseModel):
    item_id: str
    new_status: str
    new_rank: float


class ReorderBacklogRequest(BaseModel):
    item_id: str
    new_rank: float
    new_parent_id: Optional[str] = None


class CreateSprintRequest(BaseModel):
    board_id: Optional[str] = None
    name: str
    goal: Optional[str] = None
    start_date: str
    end_date: str
    capacity_hours: Optional[float] = 160.0
    capacity_unit: Optional[str] = "HOURS"
    working_days: Optional[int] = 10
    working_hours_per_day: Optional[float] = 8.0
    team_id: Optional[str] = None
    team_name: Optional[str] = "All Teams"
    owner_id: Optional[str] = None
    status: Optional[str] = "PLANNED"


class UpdateSprintRequest(BaseModel):
    name: Optional[str] = None
    goal: Optional[str] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    capacity_hours: Optional[float] = None
    capacity_unit: Optional[str] = None
    working_days: Optional[int] = None
    team_id: Optional[str] = None
    team_name: Optional[str] = None
    owner_id: Optional[str] = None
    status: Optional[str] = None


class CompleteSprintRequest(BaseModel):
    move_incomplete_to_sprint_id: Optional[str] = None
    retrospective_notes: Optional[str] = None


class TransitionSprintLifecycleRequest(BaseModel):
    new_status: str
    reason: Optional[str] = None
    move_incomplete_to_sprint_id: Optional[str] = None


class AddItemsToSprintRequest(BaseModel):
    item_ids: List[str]


class MoveItemsToSprintRequest(BaseModel):
    target_sprint_id: Optional[str] = None
    item_ids: List[str]


class ManageSprintMemberRequest(BaseModel):
    user_id: str
    role: Optional[str] = "Member"
    available_hours: Optional[float] = 80.0
    action: Optional[str] = "UPSERT"


class ManageSprintBlockerRequest(BaseModel):
    work_item_id: Optional[str] = None
    title: Optional[str] = None
    description: Optional[str] = None
    severity: Optional[str] = "HIGH"
    status: Optional[str] = "OPEN"
    owner_id: Optional[str] = None
    expected_resolution_date: Optional[str] = None
    resolution_notes: Optional[str] = None
    action: Optional[str] = "CREATE"


class ManageRetroEntryRequest(BaseModel):
    category: str = "WENT_WELL"
    content: str
    action: Optional[str] = "ADD"
    team_id: Optional[str] = None
    team_name: Optional[str] = None


class ManageRetroCommentRequest(BaseModel):
    content: str


class UpdateRetroSessionRequest(BaseModel):
    title: Optional[str] = None
    status: Optional[str] = None
    session_date: Optional[str] = None
    duration_minutes: Optional[int] = None
    facilitator_id: Optional[str] = None
    sprint_goal: Optional[str] = None
    summary: Optional[str] = None
    notes: Optional[str] = None
    meeting_link: Optional[str] = None
    visibility: Optional[str] = None
    action: Optional[str] = "UPDATE"


class ManageActionItemRequest(BaseModel):
    item_key: Optional[str] = None
    title: Optional[str] = None
    description: Optional[str] = None
    owner_id: Optional[str] = None
    due_date: Optional[str] = None
    priority: Optional[str] = "MEDIUM"
    status: Optional[str] = "OPEN"
    progress: Optional[int] = 0
    linked_work_item_id: Optional[str] = None
    source_entry_id: Optional[str] = None
    team_id: Optional[str] = None
    team_name: Optional[str] = None
    action: Optional[str] = "ADD"


class ManageRetroFeedbackRequest(BaseModel):
    category: str = "General"
    rating: int = 5
    content: Optional[str] = None
    suggested_improvement: Optional[str] = None
    is_anonymous: bool = False


class BulkUpdateActionItemsRequest(BaseModel):
    action_item_ids: List[str]
    status: Optional[str] = None
    priority: Optional[str] = None


class ManageMemberCapacityRequest(BaseModel):
    user_id: str
    role: Optional[str] = "Member"
    team_name: Optional[str] = "Digital Campus Team"
    team_id: Optional[str] = None
    available_hours: Optional[float] = 40.0
    daily_hours: Optional[float] = 8.0
    working_days: Optional[int] = 10
    days_off: Optional[float] = 0.0
    override_value: Optional[float] = None
    override_reason: Optional[str] = None
    notes: Optional[str] = None
    action: Optional[str] = "UPSERT"


class MemberAvailabilityRequest(BaseModel):
    user_id: str
    availability_id: Optional[str] = None
    availability_type: Optional[str] = "LEAVE"
    start_date: str
    end_date: str
    unavailable_hours: Optional[float] = 8.0
    reason: Optional[str] = None
    action: Optional[str] = "ADD"


class RebalanceWorkloadRequest(BaseModel):
    work_item_id: str
    from_user_id: str
    to_user_id: str
    reason: Optional[str] = "Workload rebalancing"


class AddCommentRequest(BaseModel):
    comment_text: str


class ToggleChecklistRequest(BaseModel):
    is_completed: bool


class AddChecklistRequest(BaseModel):
    title: str


class UpdateChecklistRequest(BaseModel):
    title: Optional[str] = None
    is_completed: Optional[bool] = None


class BulkUpdateRequest(BaseModel):
    item_ids: List[str]
    status: Optional[str] = None
    priority: Optional[str] = None
    assignee_id: Optional[str] = None
    assignee_ids: Optional[List[str]] = None
    sprint_id: Optional[str] = None
    team_id: Optional[str] = None
    team_name: Optional[str] = None


class CreateWorkTeamRequest(BaseModel):
    name: str = Field(..., description="Team name")
    team_key: Optional[str] = None
    department: Optional[str] = "General"
    lead_id: Optional[str] = None
    description: Optional[str] = None
    icon: Optional[str] = "layers"
    color: Optional[str] = "#2563EB"
    capacity_hours: Optional[float] = 280.0
    tags: Optional[List[str]] = []
    goal: Optional[str] = None
    member_ids: Optional[List[str]] = []


class UpdateWorkTeamRequest(BaseModel):
    name: Optional[str] = None
    team_key: Optional[str] = None
    department: Optional[str] = None
    lead_id: Optional[str] = None
    description: Optional[str] = None
    icon: Optional[str] = None
    color: Optional[str] = None
    status: Optional[str] = None
    is_active: Optional[bool] = None
    capacity_hours: Optional[float] = None
    tags: Optional[List[str]] = None
    goal: Optional[str] = None


class ManageWorkTeamMemberRequest(BaseModel):
    user_id: Optional[str] = None
    user_ids: Optional[List[str]] = None
    role: Optional[str] = None
    capacity_hours: Optional[float] = 40.0
    daily_hours: Optional[float] = 8.0
    is_lead: Optional[bool] = False


class DuplicateWorkTeamRequest(BaseModel):
    new_name: Optional[str] = None
    new_key: Optional[str] = None


# ============================================================================
# API ENDPOINTS
# ============================================================================

# ----------------------------------------------------------------------------
# 1. OVERVIEW
# ----------------------------------------------------------------------------
@router.get("/overview")
async def get_work_overview(
    board_id: Optional[str] = Query(None),
    sprint_id: Optional[str] = Query(None),
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """
    Get Work Management Overview:
    - 6 KPIs (Total, New, Active, Resolved, Completed, Overdue)
    - Overall Progress multi-segment breakdown
    - My Work Summary (Assigned to Me, Created by Me, Overdue, Due This Week)
    - Work By Type (Donut chart data: Task, Story, Bug, Epic, Other)
    - Work By Category (Bar chart data)
    - Recent Activity stream
    """
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    uid = safe_uuid(current_user.get("id")) if current_user else None
    clean_board_id = await resolve_board_id(board_id, sid)
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)

    try:
        rows = await exec_sql(
            "SELECT public.sp_get_work_management_overview(%s::UUID, %s::UUID, %s::UUID, %s::UUID) AS overview;",
            (sid, clean_board_id, clean_sprint_id, uid)
        )
        if rows and rows[0].get("overview"):
            return rows[0]["overview"]
        return {"kpis": {}, "overall_progress": {}, "my_work_summary": {}}
    except Exception as e:
        logger.error(f"[Work Overview Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# ----------------------------------------------------------------------------
# 2. BOARDS
# ----------------------------------------------------------------------------
@router.get("/boards")
async def list_work_boards(
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """List all active Work Boards for the institution."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    try:
        rows = await exec_sql(
            """
            SELECT id, name, code, description, board_type, is_active, created_at
            FROM public.work_boards
            WHERE school_id = %s::UUID AND is_active = TRUE
            ORDER BY created_at ASC;
            """,
            (sid,)
        )
        return {"success": True, "boards": rows}
    except Exception as e:
        logger.error(f"[List Boards Error]: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/boards/{board_id}/kanban")
async def get_board_kanban(
    board_id: str,
    sprint_id: Optional[str] = Query(None),
    view: Optional[str] = Query("All"),
    group_by: Optional[str] = Query("Status"),
    search: Optional[str] = Query(None),
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """
    Get full Kanban Board cards partitioned by columns (Status, Work Type, or Priority).
    """
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user and hasattr(current_user, 'get') else None) or "11111111-1111-1111-1111-111111111111"
    clean_board = await resolve_board_id(board_id, sid) or safe_str(board_id, None)
    clean_sprint = safe_str(sprint_id, None)
    clean_view = safe_str(view, "All")
    clean_group_by = safe_str(group_by, "Status")
    clean_search = safe_str(search, None)
    uid = safe_uuid(current_user.get("id")) if current_user and hasattr(current_user, 'get') else None
    try:
        rows = await exec_sql(
            "SELECT public.sp_list_board_kanban(%s::UUID, %s, %s, %s, %s, %s, %s::UUID) AS result;",
            (sid, clean_board, clean_sprint, clean_view, clean_group_by, clean_search, uid)
        )
        if rows and rows[0].get("result"):
            return rows[0]["result"]
        return {"board_id": board_id, "columns": []}
    except Exception as e:
        logger.error(f"[Board Kanban Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/boards/{board_id}/reorder")
async def reorder_board_card(
    board_id: str,
    payload: ReorderKanbanRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """
    Drag and drop card reorder or status transition on Kanban board.
    """
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_item_id = safe_uuid(payload.item_id)
    clean_board_id = await resolve_board_id(board_id, sid)
    uid = safe_uuid(current_user.get("id")) if current_user else None
    try:
        rows = await exec_sql(
            "SELECT public.sp_reorder_kanban(%s::UUID, %s::UUID, %s::UUID, %s, %s, %s::UUID) AS result;",
            (sid, clean_board_id, clean_item_id, payload.new_status, payload.new_rank, uid)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Kanban Reorder Error]: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ----------------------------------------------------------------------------
# 3. LIST TAB (DATA GRID)
# ----------------------------------------------------------------------------
@router.get("/items")
async def list_work_items(
    board_id: Optional[str] = Query(None),
    sprint_id: Optional[str] = Query(None),
    type: Optional[str] = Query("All"),
    status: Optional[str] = Query("All"),
    assignee_id: Optional[str] = Query(None),
    priority: Optional[str] = Query("All"),
    search: Optional[str] = Query(None),
    sort_col: Optional[str] = Query("created_at"),
    sort_dir: Optional[str] = Query("DESC"),
    page: int = Query(1, ge=1),
    page_size: int = Query(100, ge=1, le=500),
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """
    Server-paginated data grid list of work items with KPI metrics and multi-criteria filters.
    """
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user and hasattr(current_user, 'get') else None) or "11111111-1111-1111-1111-111111111111"
    clean_board_id = await resolve_board_id(board_id, sid)
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    clean_assignee_id = safe_uuid(assignee_id)
    clean_type = safe_str(type, "All")
    clean_status = safe_str(status, "All")
    clean_priority = safe_str(priority, "All")
    clean_search = safe_str(search, None)
    clean_sort_col = safe_str(sort_col, "created_at")
    clean_sort_dir = safe_str(sort_dir, "DESC")
    clean_page = safe_int(page, 1)
    clean_page_size = safe_int(page_size, 100)
    try:
        rows = await exec_sql(
            """
            SELECT public.sp_list_work_items_paged(
                %s::UUID, %s::UUID, %s::UUID, %s, %s, %s::UUID, %s, %s, %s, %s, %s, %s
            ) AS result;
            """,
            (sid, clean_board_id, clean_sprint_id, clean_type, clean_status, clean_assignee_id, clean_priority, clean_search, clean_sort_col, clean_sort_dir, clean_page, clean_page_size)
        )
        if rows and rows[0].get("result"):
            res = rows[0]["result"]
            if not res.get("kpis"):
                items = res.get("items", [])
                res["kpis"] = {
                    "total": res.get("total", len(items)),
                    "new": len([i for i in items if str(i.get("status", "")).upper() in ("NEW", "OPEN", "PLANNED", "NOT STARTED", "NOT_STARTED", "TODO")]),
                    "active": len([i for i in items if str(i.get("status", "")).upper() in ("ACTIVE", "IN_PROGRESS", "IN PROGRESS", "DOING", "CRITICAL")]),
                    "resolved": len([i for i in items if str(i.get("status", "")).upper() in ("RESOLVED", "TESTING", "QA", "CODE REVIEW")]),
                    "completed": len([i for i in items if str(i.get("status", "")).upper() in ("COMPLETED", "CLOSED", "DONE")]),
                    "overdue": len([i for i in items if i.get("is_overdue")]),
                }
            return res
        return {"total": 0, "page": page, "page_size": page_size, "kpis": {}, "items": []}
    except Exception as e:
        logger.error(f"[List Items Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# ----------------------------------------------------------------------------
# 4. WORK ITEM DETAIL & CRUD
# ----------------------------------------------------------------------------
@router.get("/items/{item_id}")
async def get_work_item_detail(
    item_id: str,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """
    Get full details, assignees, checklists, attachments, comments, activity logs for slide drawer.
    """
    try:
        rows = await exec_sql("SELECT public.sp_get_work_item_detail(%s::UUID) AS result;", (item_id,))
        if rows and rows[0].get("result"):
            detail = rows[0]["result"]
            if not detail or not detail.get("id"):
                raise HTTPException(status_code=404, detail="Work item not found")
            t_rows = await exec_sql("SELECT team_id, team_name FROM public.work_items WHERE id = %s::UUID LIMIT 1;", (detail["id"],))
            if t_rows:
                detail["team_id"] = str(t_rows[0]["team_id"]) if t_rows[0]["team_id"] else None
                detail["team_name"] = t_rows[0]["team_name"]
            if "activity_logs" in detail and "activity" not in detail:
                detail["activity"] = detail["activity_logs"]
            elif "activity" in detail and "activity_logs" not in detail:
                detail["activity_logs"] = detail["activity"]
            return {"success": True, "item": detail, **detail}
        raise HTTPException(status_code=404, detail="Work item not found")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Work Item Detail Error]: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/items")
async def create_work_item(
    payload: CreateWorkItemRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """
    Create a new work item (Task, Story, Bug, Epic, Homework, Issue, etc.).
    """
    sid = school_id or (current_user.get("school_id") if current_user else None) or "11111111-1111-1111-1111-111111111111"
    uid = current_user.get("id") if current_user else None

    # Fallback board_id if not given
    bid = await resolve_board_id(payload.board_id, sid)
    if not bid:
        boards = await exec_sql("SELECT id FROM public.work_boards WHERE school_id = %s::UUID ORDER BY created_at ASC LIMIT 1;", (sid,))
        bid = str(boards[0]["id"]) if boards else None

    if not bid:
        raise HTTPException(status_code=400, detail="No active work board found for institution")

    clean_sprint_id = await resolve_sprint_id(payload.sprint_id, sid)

    try:
        assignee_uuids = [uuid.UUID(a) for a in payload.assignee_ids] if payload.assignee_ids else None
        cid = uuid.UUID(payload.class_id) if payload.class_id else None
        secid = uuid.UUID(payload.section_id) if payload.section_id else None
        subid = uuid.UUID(payload.subject_id) if payload.subject_id else None
        if not subid and payload.subject_name:
            s_rows = await exec_sql(
                "SELECT id FROM public.academic_subjects WHERE school_id = %s::UUID AND (LOWER(name) = LOWER(%s) OR UPPER(code) = UPPER(%s)) AND deleted_at IS NULL LIMIT 1;",
                (sid, payload.subject_name.strip(), payload.subject_name.strip())
            )
            if s_rows:
                subid = uuid.UUID(str(s_rows[0]["id"]))

        rows = await exec_sql(
            """
            SELECT public.sp_create_work_item(
                %s::UUID, %s::UUID, %s, %s, %s, %s, %s, %s, %s::UUID, %s::UUID,
                %s::DATE, %s::DATE, %s, %s, %s, %s, %s::UUID,
                %s, %s, %s::UUID, %s::UUID, %s::UUID, %s, %s
            ) AS result;
            """,
            (
                sid, bid, payload.title, payload.description, payload.work_type, payload.priority,
                payload.status, payload.category, payload.parent_id, clean_sprint_id,
                payload.due_date, payload.start_date, payload.estimated_hours, payload.story_points,
                assignee_uuids, payload.labels, uid,
                payload.assignment_mode or "INDIVIDUAL",
                payload.target_role,
                cid, secid, subid,
                payload.is_class_wide or (payload.assignment_mode == "CLASS_SECTION"),
                payload.max_marks
            )
        )
        res = rows[0]["result"] if rows else {"success": True}
        if res and isinstance(res, dict) and (res.get("id") or res.get("item_id")):
            new_id = res.get("id") or res.get("item_id")
            res["id"] = str(new_id)
            res["item_id"] = str(new_id)
            # Enforce exact explicit assignee selection (do not auto-assign everyone if user selected 0 or specific users)
            if payload.assignee_ids is not None:
                await exec_sql(
                    "DELETE FROM public.work_item_assignees WHERE work_item_id = %s::UUID;",
                    (safe_uuid(new_id),),
                    fetch=False
                )
                for a_id in payload.assignee_ids:
                    clean_uid = safe_uuid(a_id)
                    if clean_uid:
                        await exec_sql(
                            """
                            INSERT INTO public.work_item_assignees (work_item_id, user_id, role_type)
                            VALUES (%s::UUID, %s::UUID, 'PRIMARY')
                            ON CONFLICT DO NOTHING;
                            """,
                            (safe_uuid(new_id), clean_uid),
                            fetch=False
                        )

            if payload.team_id is not None or payload.team_name is not None:
                t_id = safe_uuid(payload.team_id)
                t_name = payload.team_name
                if t_id and not t_name:
                    t_rows = await exec_sql("SELECT name FROM public.work_teams WHERE id = %s::UUID AND COALESCE(status, 'ACTIVE') NOT IN ('ARCHIVED', 'DELETED') AND COALESCE(is_active, TRUE) = TRUE LIMIT 1;", (t_id,))
                    if t_rows:
                        t_name = t_rows[0]["name"]
                    else:
                        t_id = None
                        t_name = None
                elif t_name and not t_id:
                    if str(t_name).strip().upper() not in ("NONE", "NULL", "UNASSIGN", "ALL", "NO TEAM"):
                        t_rows = await exec_sql("SELECT id, name FROM public.work_teams WHERE school_id = %s::UUID AND LOWER(name) = LOWER(%s) AND COALESCE(status, 'ACTIVE') NOT IN ('ARCHIVED', 'DELETED') AND COALESCE(is_active, TRUE) = TRUE LIMIT 1;", (sid, str(t_name).strip()))
                        if t_rows:
                            t_id = str(t_rows[0]["id"])
                            t_name = t_rows[0]["name"]
                        else:
                            t_name = None
                            t_id = None
                    else:
                        t_name = None
                        t_id = None
                await exec_sql(
                    "UPDATE public.work_items SET team_id = %s::UUID, team_name = %s, updated_at = NOW() WHERE id = %s::UUID;",
                    (t_id, t_name, safe_uuid(new_id)),
                    fetch=False
                )
                res["team_id"] = str(t_id) if t_id else None
                res["team_name"] = t_name
        return res
    except Exception as e:
        logger.error(f"[Create Work Item Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.patch("/items/{item_id}")
async def update_work_item(
    item_id: str,
    payload: UpdateWorkItemRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """
    Update fields on a work item with SHAMIIT effort calculations and audit trails.
    """
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    uid = safe_uuid(current_user.get("id")) if current_user else None
    clean_item_id = safe_uuid(item_id)
    if not clean_item_id and item_id:
        it_rows = await exec_sql(
            "SELECT id FROM public.work_items WHERE school_id = %s::UUID AND UPPER(item_number) = UPPER(%s) LIMIT 1;",
            (sid, str(item_id).strip())
        )
        if it_rows:
            clean_item_id = str(it_rows[0]["id"])
    try:
        payload_dict = payload.model_dump(exclude_unset=True)
        if "board_id" in payload_dict and payload_dict["board_id"]:
            resolved_bid = await resolve_board_id(payload_dict["board_id"], sid)
            if resolved_bid:
                payload_dict["board_id"] = resolved_bid
        if "sprint_id" in payload_dict and payload_dict["sprint_id"]:
            resolved_sp = await resolve_sprint_id(payload_dict["sprint_id"], sid)
            if resolved_sp:
                payload_dict["sprint_id"] = resolved_sp
        payload_json = json.dumps(payload_dict)
        rows = await exec_sql(
            "SELECT public.sp_update_work_item_azure(%s::UUID, %s::UUID, %s::UUID, %s::JSONB) AS result;",
            (sid, clean_item_id, uid, payload_json)
        )
        if rows and rows[0].get("result"):
            detail = rows[0]["result"]
            if payload.team_id is not None or payload.team_name is not None:
                t_id = safe_uuid(payload.team_id)
                t_name = payload.team_name
                if t_id and not t_name:
                    t_rows = await exec_sql("SELECT name FROM public.work_teams WHERE id = %s::UUID AND COALESCE(status, 'ACTIVE') NOT IN ('ARCHIVED', 'DELETED') AND COALESCE(is_active, TRUE) = TRUE LIMIT 1;", (t_id,))
                    if t_rows:
                        t_name = t_rows[0]["name"]
                    else:
                        t_id = None
                        t_name = None
                elif t_name and not t_id:
                    if str(t_name).strip().upper() not in ("NONE", "NULL", "UNASSIGN", "ALL", "NO TEAM"):
                        t_rows = await exec_sql("SELECT id, name FROM public.work_teams WHERE school_id = %s::UUID AND LOWER(name) = LOWER(%s) AND COALESCE(status, 'ACTIVE') NOT IN ('ARCHIVED', 'DELETED') AND COALESCE(is_active, TRUE) = TRUE LIMIT 1;", (sid, str(t_name).strip()))
                        if t_rows:
                            t_id = str(t_rows[0]["id"])
                            t_name = t_rows[0]["name"]
                        else:
                            t_name = None
                            t_id = None
                    else:
                        t_name = None
                        t_id = None
                await exec_sql(
                    "UPDATE public.work_items SET team_id = %s::UUID, team_name = %s, updated_at = NOW() WHERE id = %s::UUID;",
                    (t_id, t_name, clean_item_id),
                    fetch=False
                )
                if isinstance(detail, dict):
                    detail["team_id"] = str(t_id) if t_id else None
                    detail["team_name"] = t_name
            return {"success": True, "item": detail, **detail}
        if payload.team_id is not None or payload.team_name is not None:
            t_id = safe_uuid(payload.team_id)
            t_name = payload.team_name
            if t_id and not t_name:
                t_rows = await exec_sql("SELECT name FROM public.work_teams WHERE id = %s::UUID AND COALESCE(status, 'ACTIVE') NOT IN ('ARCHIVED', 'DELETED') AND COALESCE(is_active, TRUE) = TRUE LIMIT 1;", (t_id,))
                if t_rows:
                    t_name = t_rows[0]["name"]
                else:
                    t_id = None
                    t_name = None
            elif t_name and not t_id:
                if str(t_name).strip().upper() not in ("NONE", "NULL", "UNASSIGN", "ALL", "NO TEAM"):
                    t_rows = await exec_sql("SELECT id, name FROM public.work_teams WHERE school_id = %s::UUID AND LOWER(name) = LOWER(%s) AND COALESCE(status, 'ACTIVE') NOT IN ('ARCHIVED', 'DELETED') AND COALESCE(is_active, TRUE) = TRUE LIMIT 1;", (sid, str(t_name).strip()))
                    if t_rows:
                        t_id = str(t_rows[0]["id"])
                        t_name = t_rows[0]["name"]
                    else:
                        t_name = None
                        t_id = None
                else:
                    t_name = None
                    t_id = None
            await exec_sql(
                "UPDATE public.work_items SET team_id = %s::UUID, team_name = %s, updated_at = NOW() WHERE id = %s::UUID;",
                (t_id, t_name, clean_item_id),
                fetch=False
            )
        return {"success": True, "item_id": item_id}
    except Exception as e:
        logger.error(f"[Update Work Item Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/items/{item_id}/copy")
async def copy_work_item(
    item_id: str,
    payload: CopyWorkItemRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """SHAMIIT: Create Copy / Clone of Story, Task, Bug, Epic."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_source_id = safe_uuid(item_id)
    uid = safe_uuid(current_user.get("id")) if current_user else None
    try:
        rows = await exec_sql(
            "SELECT public.sp_copy_work_item(%s::UUID, %s::UUID, %s, %s, %s, %s::UUID) AS result;",
            (sid, clean_source_id, payload.new_title, payload.include_children, payload.include_attachments, uid)
        )
        if rows and rows[0].get("result"):
            return rows[0]["result"]
        return {"success": True}
    except Exception as e:
        logger.error(f"[Copy Work Item Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/items/{item_id}/links")
async def link_work_items(
    item_id: str,
    payload: LinkWorkItemRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """SHAMIIT: Link work items (CHILD, PARENT, RELATED, BLOCKS, BLOCKED_BY) by UUID or item_number."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_source_id = safe_uuid(item_id)
    target_ref = (payload.target_id or "").strip()
    uid = safe_uuid(current_user.get("id")) if current_user else None
    try:
        rows = await exec_sql(
            "SELECT public.sp_link_work_item_by_ref(%s::UUID, %s::UUID, %s, %s, %s::UUID) AS result;",
            (sid, clean_source_id, target_ref, payload.link_type, uid)
        )
        if rows and rows[0].get("result"):
            return rows[0]["result"]
        return {"success": True}
    except Exception as e:
        logger.error(f"[Link Work Items Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/items/{item_id}/links/{target_id}")
async def unlink_work_items(
    item_id: str,
    target_id: str,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """SHAMIIT: Unlink work item dependency or child/parent link."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_source_id = safe_uuid(item_id)
    clean_target_id = safe_uuid(target_id)
    uid = safe_uuid(current_user.get("id")) if current_user else None
    try:
        rows = await exec_sql(
            "SELECT public.sp_unlink_work_items(%s::UUID, %s::UUID, %s::UUID, %s::UUID) AS result;",
            (sid, clean_source_id, clean_target_id, uid)
        )
        if rows and rows[0].get("result"):
            return rows[0]["result"]
        return {"success": True}
    except Exception as e:
        logger.error(f"[Unlink Work Items Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/items/{item_id}/links/{target_id}")
async def update_work_item_link_endpoint(
    item_id: str,
    target_id: str,
    payload: UpdateLinkRelationshipRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """SHAMIIT: Update relationship type between work items (CHILD, PARENT, BLOCKS, BLOCKED_BY, RELATED)."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_source_id = safe_uuid(item_id)
    clean_target_id = safe_uuid(target_id)
    uid = safe_uuid(current_user.get("id")) if current_user else None
    try:
        rows = await exec_sql(
            "SELECT public.sp_update_work_item_link(%s::UUID, %s::UUID, %s::UUID, %s, %s::UUID) AS result;",
            (sid, clean_source_id, clean_target_id, payload.link_type, uid)
        )
        if rows and rows[0].get("result"):
            return rows[0]["result"]
        return {"success": True}
    except Exception as e:
        logger.error(f"[Update Link Relationship Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/items/{item_id}/attachments")
async def add_item_attachment(
    item_id: str,
    payload: AddAttachmentRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Add an attachment document reference and log audit trail via stored procedure."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_item_id = safe_uuid(item_id)
    uid = safe_uuid(current_user.get("id")) if current_user else None
    try:
        rows = await exec_sql(
            "SELECT public.sp_add_work_item_attachment(%s::UUID, %s::UUID, %s, %s, %s, %s, %s::UUID, %s::UUID) AS result;",
            (sid, clean_item_id, payload.file_name, payload.file_url, payload.file_size_bytes or 0, payload.file_type or "document", uid, None)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Add Attachment Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/items/{item_id}/attachments/upload")
async def upload_item_attachment(
    item_id: str,
    file: UploadFile = File(...),
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Upload a local file (PDF, DOCX, XLSX, PNG, JPG, etc.) and attach it to a work item."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_item_id = safe_uuid(item_id)
    uid = safe_uuid(current_user.get("id")) if current_user else None

    if not clean_item_id:
        raise HTTPException(status_code=400, detail="Invalid work item ID")

    try:
        file_bytes = await file.read()
        file_size = len(file_bytes)
        if file_size == 0:
            raise HTTPException(status_code=400, detail="Uploaded file is empty")
        if file_size > 50 * 1024 * 1024:
            raise HTTPException(status_code=413, detail="File too large (max 50 MB)")

        raw_name = os.path.basename(file.filename or "attachment")
        safe_name = "".join(c if c.isalnum() or c in "._- ()" else "_" for c in raw_name).strip() or "attachment"
        ext = safe_name.rsplit(".", 1)[-1].lower() if "." in safe_name else "bin"
        att_id = str(uuid.uuid4())

        # Save locally under assets/work_attachments/{school_id}/{att_id}.{ext}
        rel_path = f"assets/work_attachments/{sid}/{att_id}.{ext}"
        abs_path = os.path.join(os.getcwd(), rel_path)
        os.makedirs(os.path.dirname(abs_path), exist_ok=True)
        with open(abs_path, "wb") as f:
            f.write(file_bytes)

        file_url = f"/api/v1/work/attachments/{att_id}/download"
        file_type = "pdf" if ext == "pdf" else ("image" if ext in ("png", "jpg", "jpeg", "gif", "webp") else ext)

        rows = await exec_sql(
            "SELECT public.sp_add_work_item_attachment(%s::UUID, %s::UUID, %s, %s, %s, %s, %s::UUID, %s::UUID) AS result;",
            (sid, clean_item_id, safe_name, file_url, file_size, file_type, uid, att_id)
        )
        return rows[0]["result"] if rows else {"success": True, "attachment_id": att_id, "file_name": safe_name}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Upload Work Attachment Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/attachments/{att_id}/download")
async def download_item_attachment(
    att_id: str,
):
    """Download a work item attachment stored locally or redirect if external URL."""
    clean_att_id = safe_uuid(att_id)
    if not clean_att_id:
        raise HTTPException(status_code=400, detail="Invalid attachment ID")
    try:
        rows = await exec_sql(
            "SELECT public.sp_get_work_item_attachment(%s::UUID) AS result;",
            (clean_att_id,)
        )
        res = rows[0]["result"] if rows else None
        if not res or not res.get("success"):
            raise HTTPException(status_code=404, detail="Attachment not found")

        file_name = res.get("file_name") or "attachment"
        file_url = res.get("file_url") or ""
        school_id = res.get("school_id") or "11111111-1111-1111-1111-111111111111"
        ext = file_name.rsplit(".", 1)[-1].lower() if "." in file_name else "bin"

        local_path = os.path.join(os.getcwd(), f"assets/work_attachments/{school_id}/{clean_att_id}.{ext}")
        if os.path.exists(local_path):
            mime, _ = mimetypes.guess_type(file_name)
            return FileResponse(
                path=local_path,
                filename=file_name,
                media_type=mime or "application/octet-stream",
            )

        if file_url.startswith("http://") or file_url.startswith("https://"):
            return RedirectResponse(url=file_url)

        raise HTTPException(status_code=404, detail="Attachment file not found on server")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Download Work Attachment Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/attachments/{att_id}")
async def delete_item_attachment(
    att_id: str,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Delete a work item attachment record and remove stored file."""
    clean_att_id = safe_uuid(att_id)
    uid = safe_uuid(current_user.get("id")) if current_user else None
    try:
        rows = await exec_sql(
            "SELECT public.sp_delete_work_item_attachment(%s::UUID, %s::UUID) AS result;",
            (clean_att_id, uid)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Delete Attachment Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/items/{item_id}")
async def delete_work_item(
    item_id: str,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Soft delete / archive a work item via stored procedure."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    uid = safe_uuid(current_user.get("id")) if current_user else None
    clean_item_id = safe_uuid(item_id)
    if not clean_item_id and item_id:
        it_rows = await exec_sql(
            "SELECT id FROM public.work_items WHERE school_id = %s::UUID AND UPPER(item_number) = UPPER(%s) LIMIT 1;",
            (sid, str(item_id).strip())
        )
        if it_rows:
            clean_item_id = str(it_rows[0]["id"])
    try:
        rows = await exec_sql(
            "SELECT public.sp_delete_work_item(%s::UUID, %s::UUID, %s::UUID) AS result;",
            (sid, clean_item_id, uid)
        )
        return rows[0]["result"] if rows else {"success": True, "item_id": item_id}
    except Exception as e:
        logger.error(f"[Delete Work Item Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/items/{item_id}/transition")
async def transition_work_item(
    item_id: str,
    payload: TransitionStatusRequest,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """
    Transition work item status and record audit trail.
    """
    uid = current_user.get("id") if current_user else None
    try:
        rows = await exec_sql(
            "SELECT public.sp_transition_work_item_status(%s::UUID, %s, %s::UUID, %s) AS result;",
            (item_id, payload.new_status, uid, payload.notes)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Transition Status Error]: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ----------------------------------------------------------------------------
# 5. BACKLOG TAB
# ----------------------------------------------------------------------------
@router.get("/backlog")
async def get_backlog_tree(
    board_id: Optional[str] = Query(None),
    epic_id: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    type: Optional[str] = Query("All"),
    assignee_id: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """
    Get Backlog tree view: 12 Epics sidebar, Active Epic stories and child tasks,
    KPI summary cards (Total Backlog Items 142, Epics 12, Stories 28, Tasks 76, Bugs 14, Issues 12).
    """
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user and hasattr(current_user, 'get') else None) or "11111111-1111-1111-1111-111111111111"
    clean_board_id = await resolve_board_id(board_id, sid)
    clean_epic_id = safe_uuid(epic_id)
    
    # If epic_id is an item number like 'EP-003', resolve to UUID
    if not clean_epic_id and epic_id:
        epic_rows = await exec_sql(
            "SELECT id FROM public.work_items WHERE school_id = %s::UUID AND UPPER(item_number) = UPPER(%s) AND work_type = 'EPIC' LIMIT 1;",
            (sid, str(epic_id).strip())
        )
        if epic_rows:
            clean_epic_id = str(epic_rows[0]["id"])
    
    clean_assignee_id = safe_uuid(assignee_id)
    clean_search = safe_str(search, None)
    clean_type = safe_str(type, "All")
    clean_page = safe_int(page, 1)
    clean_page_size = safe_int(page_size, 10)
    try:
        rows = await exec_sql(
            "SELECT public.sp_get_backlog_tree(%s::UUID, %s::UUID, %s::UUID, %s, %s, %s::UUID, %s, %s) AS result;",
            (sid, clean_board_id, clean_epic_id, clean_search, clean_type, clean_assignee_id, clean_page, clean_page_size)
        )
        if rows and rows[0].get("result"):
            res = rows[0]["result"]
            stories = res.get("stories") or res.get("items") or []
            res["stories"] = stories
            res["items"] = stories
            return res
        return {"kpis": {}, "epics": [], "items": [], "stories": []}
    except Exception as e:
        logger.error(f"[Backlog Tree Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/backlog/reorder")
async def reorder_backlog_item(
    payload: ReorderBacklogRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Reorder backlog priority or nest under an Epic/Story."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_item_id = safe_uuid(payload.item_id)
    if not clean_item_id and payload.item_id:
        item_rows = await exec_sql(
            "SELECT id FROM public.work_items WHERE school_id = %s::UUID AND UPPER(item_number) = UPPER(%s) LIMIT 1;",
            (sid, str(payload.item_id).strip())
        )
        if item_rows:
            clean_item_id = str(item_rows[0]["id"])
    clean_parent_id = None
    if payload.new_parent_id is not None:
        clean_parent_id = safe_uuid(payload.new_parent_id)
        if not clean_parent_id and payload.new_parent_id:
            p_rows = await exec_sql(
                "SELECT id FROM public.work_items WHERE school_id = %s::UUID AND UPPER(item_number) = UPPER(%s) LIMIT 1;",
                (sid, str(payload.new_parent_id).strip())
            )
            if p_rows:
                clean_parent_id = str(p_rows[0]["id"])
    try:
        if payload.new_parent_id is not None:
            await exec_sql(
                "UPDATE public.work_items SET rank = %s, parent_id = %s::UUID, updated_at = NOW() WHERE id = %s::UUID AND school_id = %s::UUID;",
                (payload.new_rank, clean_parent_id, clean_item_id, sid),
                fetch=False
            )
        else:
            await exec_sql(
                "UPDATE public.work_items SET rank = %s, updated_at = NOW() WHERE id = %s::UUID AND school_id = %s::UUID;",
                (payload.new_rank, clean_item_id, sid),
                fetch=False
            )
        return {"success": True, "item_id": payload.item_id, "rank": payload.new_rank}
    except Exception as e:
        logger.error(f"[Backlog Reorder Error]: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/items/bulk-update")
async def bulk_update_work_items(
    payload: BulkUpdateRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """
    Bulk update selected work items: status, priority, sprint, or assignee.
    Supports resolving both UUIDs and item numbers (e.g. ST-101, TK-1001).
    """
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    if not payload.item_ids:
        return {"success": True, "updated_count": 0}

    # Resolve IDs
    resolved_ids: List[str] = []
    for raw_id in payload.item_ids:
        c_id = safe_uuid(raw_id)
        if c_id:
            resolved_ids.append(c_id)
        else:
            rows = await exec_sql(
                "SELECT id FROM public.work_items WHERE school_id = %s::UUID AND UPPER(item_number) = UPPER(%s) LIMIT 1;",
                (sid, str(raw_id).strip())
            )
            if rows:
                resolved_ids.append(str(rows[0]["id"]))

    if not resolved_ids:
        return {"success": True, "updated_count": 0}

    # Resolve target sprint
    target_sprint_id: Optional[str] = None
    if payload.sprint_id and str(payload.sprint_id).strip().upper() not in ("BACKLOG", "NONE", "NULL", "UNASSIGN"):
        target_sprint_id = await resolve_sprint_id(payload.sprint_id, sid)

    try:
        # Build update fields dynamically
        updates = []
        params = []
        if payload.status:
            updates.append("status = %s")
            params.append(payload.status.upper())
        if payload.priority:
            updates.append("priority = %s")
            params.append(payload.priority.upper())
        if payload.sprint_id is not None:
            updates.append("sprint_id = %s::UUID")
            params.append(target_sprint_id)
        if payload.team_id is not None or payload.team_name is not None:
            t_id = safe_uuid(payload.team_id)
            t_name = payload.team_name
            if t_id and not t_name:
                t_rows = await exec_sql("SELECT name FROM public.work_teams WHERE id = %s::UUID AND COALESCE(status, 'ACTIVE') NOT IN ('ARCHIVED', 'DELETED') AND COALESCE(is_active, TRUE) = TRUE LIMIT 1;", (t_id,))
                if t_rows:
                    t_name = t_rows[0]["name"]
                else:
                    t_id = None
                    t_name = None
            elif t_name and not t_id:
                if str(t_name).strip().upper() in ("NONE", "NULL", "UNASSIGN", "ALL", "NO TEAM"):
                    t_name = None
                    t_id = None
                else:
                    t_rows = await exec_sql("SELECT id, name FROM public.work_teams WHERE school_id = %s::UUID AND LOWER(name) = LOWER(%s) AND COALESCE(status, 'ACTIVE') NOT IN ('ARCHIVED', 'DELETED') AND COALESCE(is_active, TRUE) = TRUE LIMIT 1;", (sid, str(t_name).strip()))
                    if t_rows:
                        t_id = str(t_rows[0]["id"])
                        t_name = t_rows[0]["name"]
                    else:
                        t_id = None
                        t_name = None
            updates.append("team_id = %s::UUID")
            params.append(t_id)
            updates.append("team_name = %s")
            params.append(t_name)

        updates.append("updated_at = NOW()")

        if updates:
            set_clause = ", ".join(updates)
            sql = f"UPDATE public.work_items SET {set_clause} WHERE id = ANY(%s::UUID[]) AND school_id = %s::UUID;"
            params.append(resolved_ids)
            params.append(sid)
            await exec_sql(sql, tuple(params), fetch=False)

        # Handle assignee update if requested
        if payload.assignee_ids is not None:
            clean_uids = [safe_uuid(a) for a in payload.assignee_ids if safe_uuid(a)]
            for item_id in resolved_ids:
                await exec_sql(
                    "DELETE FROM public.work_item_assignees WHERE work_item_id = %s::UUID;",
                    (item_id,),
                    fetch=False
                )
                for clean_uid in clean_uids:
                    await exec_sql(
                        """
                        INSERT INTO public.work_item_assignees (work_item_id, user_id, role_type)
                        VALUES (%s::UUID, %s::UUID, 'PRIMARY')
                        ON CONFLICT DO NOTHING;
                        """,
                        (item_id, clean_uid),
                        fetch=False
                    )
            await exec_sql(
                "UPDATE public.work_items SET updated_at = NOW() WHERE id = ANY(%s::UUID[]);",
                (resolved_ids,),
                fetch=False
            )
        elif payload.assignee_id is not None:
            clean_assignee = safe_uuid(payload.assignee_id)
            for item_id in resolved_ids:
                if clean_assignee:
                    await exec_sql(
                        """
                        INSERT INTO public.work_item_assignees (work_item_id, user_id)
                        VALUES (%s::UUID, %s::UUID)
                        ON CONFLICT (work_item_id, user_id) DO NOTHING;
                        """,
                        (item_id, clean_assignee),
                        fetch=False
                    )
                else:
                    await exec_sql(
                        "DELETE FROM public.work_item_assignees WHERE work_item_id = %s::UUID;",
                        (item_id,),
                        fetch=False
                    )
            await exec_sql(
                "UPDATE public.work_items SET updated_at = NOW() WHERE id = ANY(%s::UUID[]);",
                (resolved_ids,),
                fetch=False
            )

        return {"success": True, "updated_count": len(resolved_ids), "item_ids": resolved_ids}
    except Exception as e:
        logger.error(f"[Bulk Update Work Items Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/items/bulk-delete")
async def bulk_delete_work_items(
    payload: Dict[str, Any],
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Bulk soft-delete (archive) selected work items."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    raw_ids = payload.get("item_ids", [])
    if not raw_ids:
        return {"success": True, "deleted_count": 0}

    resolved_ids: List[str] = []
    for raw_id in raw_ids:
        c_id = safe_uuid(raw_id)
        if c_id:
            resolved_ids.append(c_id)
        else:
            rows = await exec_sql(
                "SELECT id FROM public.work_items WHERE school_id = %s::UUID AND UPPER(item_number) = UPPER(%s) LIMIT 1;",
                (sid, str(raw_id).strip())
            )
            if rows:
                resolved_ids.append(str(rows[0]["id"]))

    if not resolved_ids:
        return {"success": True, "deleted_count": 0}

    try:
        await exec_sql(
            "UPDATE public.work_items SET is_archived = TRUE, updated_at = NOW() WHERE id = ANY(%s::UUID[]) AND school_id = %s::UUID;",
            (resolved_ids, sid),
            fetch=False
        )
        return {"success": True, "deleted_count": len(resolved_ids)}
    except Exception as e:
        logger.error(f"[Bulk Delete Work Items Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# ----------------------------------------------------------------------------
# 6. SPRINTS TAB
# ----------------------------------------------------------------------------
@router.get("/sprints")
async def list_sprints(
    board_id: Optional[str] = Query(None),
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """List all sprints for board/school."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_board_id = await resolve_board_id(board_id, sid)
    try:
        rows = await exec_sql(
            """
            SELECT s.id, s.name, s.sprint_number, s.goal, s.status, s.team_id,
                   COALESCE(s.team_name, t.name, 'All Teams') AS team_name,
                   to_char(s.start_date, 'Mon DD, YYYY') AS start_date_fmt,
                   to_char(s.end_date, 'Mon DD, YYYY') AS end_date_fmt,
                   s.start_date, s.end_date, s.capacity_hours, s.total_points,
                   COALESCE(GREATEST(1, (s.end_date - s.start_date + 1)), 14) AS duration_days,
                   COALESCE(s.color, '#2563EB') AS color,
                   COALESCE(COUNT(DISTINCT w.id), 0) AS total_items,
                   COALESCE(COUNT(DISTINCT CASE WHEN UPPER(w.status) IN ('COMPLETED', 'RESOLVED', 'CLOSED', 'DONE') THEN w.id END), 0) AS completed_items
            FROM public.work_sprints s
            LEFT JOIN public.work_teams t ON t.id = s.team_id
            LEFT JOIN public.work_items w ON w.sprint_id = s.id AND COALESCE(w.is_archived, FALSE) = FALSE
            WHERE s.school_id = %s::UUID 
              AND COALESCE(s.is_archived, FALSE) = FALSE 
              AND ( %s::UUID IS NULL OR s.board_id = %s::UUID )
            GROUP BY s.id, t.name
            ORDER BY s.sprint_number ASC, s.start_date ASC;
            """,
            (sid, clean_board_id, clean_board_id)
        )
        return {"success": True, "sprints": rows}
    except Exception as e:
        logger.error(f"[List Sprints Error]: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/sprints/{sprint_id}")
async def get_sprint_dashboard(
    sprint_id: str,
    board_id: Optional[str] = Query(None),
    team: Optional[str] = Query("All Teams"),
    search: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """
    Get Sprint Dashboard:
    - Active Sprint details, duration, completion rate 68%
    - 5 KPIs (Total Items 42, Completed 29, In Progress 8, Not Started 5, Blocked 0)
    - Sprint Goal card
    - Sprint Burndown Line Chart data (Ideal vs Remaining)
    - Sprint Backlog items hierarchy
    - Sprint Progress by Type (Donut chart data)
    - Upcoming Sprints
    """
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user and hasattr(current_user, 'get') else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    clean_board_id = await resolve_board_id(board_id, sid)
    clean_team = safe_str(team, "All Teams")
    clean_search = safe_str(search, None)
    clean_page = safe_int(page, 1)
    clean_page_size = safe_int(page_size, 10)
    try:
        rows = await exec_sql(
            "SELECT public.sp_get_sprint_dashboard(%s::UUID, %s::UUID, %s::UUID, %s, %s, %s, %s) AS result;",
            (sid, clean_board_id, clean_sprint_id, clean_team, clean_search, clean_page, clean_page_size)
        )
        if rows and rows[0].get("result"):
            return rows[0]["result"]
        return {"kpis": {}, "burndown": [], "items": []}
    except Exception as e:
        logger.error(f"[Sprint Dashboard Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/sprints")
async def create_sprint(
    payload: CreateSprintRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Create a new sprint/iteration."""
    sid = school_id or (current_user.get("school_id") if current_user else None) or "11111111-1111-1111-1111-111111111111"
    uid = current_user.get("id") if current_user else None
    bid = payload.board_id
    if not bid:
        boards = await exec_sql("SELECT id FROM public.work_boards WHERE school_id = %s::UUID ORDER BY created_at ASC LIMIT 1;", (sid,))
        bid = boards[0]["id"] if boards else None

    try:
        sprint_id = str(uuid.uuid4())
        s_match = re.search(r'\d+', payload.name)
        if s_match:
            s_num = int(s_match.group(0))
        else:
            max_rows = await exec_sql("SELECT COALESCE(MAX(sprint_number), 0) + 1 AS next_num FROM public.work_sprints WHERE school_id = %s::UUID;", (sid,))
            s_num = max_rows[0]["next_num"] if max_rows else 1

        clean_team_id = safe_uuid(payload.team_id)
        team_name = payload.team_name or "All Teams"
        if clean_team_id and (not team_name or team_name == "All Teams"):
            t_rows = await exec_sql("SELECT name FROM public.work_teams WHERE id = %s::UUID LIMIT 1;", (clean_team_id,))
            if t_rows:
                team_name = t_rows[0]["name"]
        elif team_name and not clean_team_id and team_name not in ("All Teams", "None", ""):
            t_rows = await exec_sql("SELECT id FROM public.work_teams WHERE school_id = %s::UUID AND LOWER(name) = LOWER(%s) LIMIT 1;", (sid, team_name))
            if t_rows:
                clean_team_id = str(t_rows[0]["id"])

        sprint_status = (payload.status or "PLANNED").upper()

        await exec_sql(
            """
            INSERT INTO public.work_sprints (
                id, school_id, board_id, name, sprint_number, goal, start_date, end_date, capacity_hours,
                capacity_unit, working_days, working_hours_per_day, team_id, team_name, owner_id, status
            ) VALUES (%s::UUID, %s::UUID, %s::UUID, %s, %s, %s, %s::DATE, %s::DATE, %s, %s, %s, %s, %s::UUID, %s, %s::UUID, %s);
            """,
            (sprint_id, sid, bid, payload.name, s_num, payload.goal, payload.start_date, payload.end_date,
             payload.capacity_hours, payload.capacity_unit or "HOURS", payload.working_days or 10,
             payload.working_hours_per_day or 8.0, clean_team_id, team_name, uid or payload.owner_id, sprint_status),
            fetch=False
        )
        return {"success": True, "sprint_id": sprint_id, "name": payload.name, "status": sprint_status}
    except Exception as e:
        logger.error(f"[Create Sprint Error]: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.patch("/sprints/{sprint_id}")
async def update_sprint(
    sprint_id: str,
    payload: UpdateSprintRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Update sprint configuration (name, goal, dates, capacity, working days, team, status)."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    uid = safe_uuid(current_user.get("id")) if current_user else None
    clean_owner_id = safe_uuid(payload.owner_id)
    try:
        clean_team_id = safe_uuid(payload.team_id)
        team_name = payload.team_name
        if clean_team_id and not team_name:
            t_rows = await exec_sql("SELECT name FROM public.work_teams WHERE id = %s::UUID LIMIT 1;", (clean_team_id,))
            if t_rows:
                team_name = t_rows[0]["name"]
        elif team_name and not clean_team_id and team_name not in ("All Teams", "None", ""):
            t_rows = await exec_sql("SELECT id FROM public.work_teams WHERE school_id = %s::UUID AND LOWER(name) = LOWER(%s) LIMIT 1;", (sid, team_name))
            if t_rows:
                clean_team_id = str(t_rows[0]["id"])

        # Direct robust update to ensure all fields persist
        await exec_sql(
            """
            UPDATE public.work_sprints
            SET name = COALESCE(%s, name),
                goal = COALESCE(%s, goal),
                start_date = COALESCE(%s::DATE, start_date),
                end_date = COALESCE(%s::DATE, end_date),
                capacity_hours = COALESCE(%s, capacity_hours),
                working_days = COALESCE(%s, working_days),
                team_id = COALESCE(%s::UUID, team_id),
                team_name = COALESCE(%s, team_name),
                owner_id = COALESCE(%s::UUID, owner_id),
                status = COALESCE(UPPER(%s), status),
                capacity_unit = COALESCE(UPPER(%s), capacity_unit),
                updated_at = NOW()
            WHERE id = %s::UUID AND school_id = %s::UUID;
            """,
            (payload.name, payload.goal, payload.start_date, payload.end_date,
             payload.capacity_hours, payload.working_days, clean_team_id, team_name,
             clean_owner_id, payload.status, payload.capacity_unit, clean_sprint_id, sid),
            fetch=False
        )
        return {"success": True, "sprint_id": sprint_id}
    except Exception as e:
        logger.error(f"[Update Sprint Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/sprints/{sprint_id}")
async def delete_sprint(
    sprint_id: str,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """
    Safely archive/delete a sprint. Work items assigned to this sprint are returned to the backlog.
    """
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    try:
        # 1. Unassign all work items back to backlog
        await exec_sql(
            "UPDATE public.work_items SET sprint_id = NULL, updated_at = NOW() WHERE sprint_id = %s::UUID AND school_id = %s::UUID;",
            (clean_sprint_id, sid),
            fetch=False
        )
        # 2. Soft delete / archive the sprint
        await exec_sql(
            "UPDATE public.work_sprints SET is_archived = TRUE, deleted_at = NOW() WHERE id = %s::UUID AND school_id = %s::UUID;",
            (clean_sprint_id, sid),
            fetch=False
        )
        return {"success": True, "sprint_id": sprint_id, "message": "Sprint archived and work items returned to backlog"}
    except Exception as e:
        logger.error(f"[Delete Sprint Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/sprints/{sprint_id}/duplicate")
async def duplicate_sprint(
    sprint_id: str,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Duplicate sprint configuration (copies team, capacity, working days shifted to next duration)."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    uid = safe_uuid(current_user.get("id")) if current_user else None
    try:
        sprints = await exec_sql(
            "SELECT * FROM public.work_sprints WHERE id = %s::UUID AND school_id = %s::UUID;",
            (clean_sprint_id, sid)
        )
        if not sprints:
            raise HTTPException(status_code=404, detail="Source sprint not found")
        orig = sprints[0]

        # Shift dates by 14 days
        new_start = orig["end_date"]
        new_sprint_id = str(uuid.uuid4())
        new_number = (orig.get("sprint_number") or 1) + 1
        new_name = f"Sprint {new_number}"

        await exec_sql(
            """
            INSERT INTO public.work_sprints (
                id, school_id, board_id, name, sprint_number, goal, start_date, end_date,
                capacity_hours, working_days, team_name, owner_id, status
            ) VALUES (
                %s::UUID, %s::UUID, %s::UUID, %s, %s, %s, (%s::DATE + INTERVAL '1 day')::DATE,
                (%s::DATE + INTERVAL '14 day')::DATE, %s, %s, %s, %s::UUID, 'PLANNED'
            );
            """,
            (new_sprint_id, sid, orig["board_id"], new_name, new_number, orig["goal"],
             new_start, new_start, orig["capacity_hours"], orig["working_days"], orig["team_name"], uid),
            fetch=False
        )

        # Copy team members
        await exec_sql(
            """
            INSERT INTO public.sprint_members (school_id, sprint_id, user_id, role, available_hours)
            SELECT school_id, %s::UUID, user_id, role, available_hours
            FROM public.sprint_members
            WHERE sprint_id = %s::UUID;
            """,
            (new_sprint_id, clean_sprint_id),
            fetch=False
        )

        return {"success": True, "new_sprint_id": new_sprint_id, "name": new_name}
    except Exception as e:
        logger.error(f"[Duplicate Sprint Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/sprints/{sprint_id}/start")
async def start_sprint(
    sprint_id: str,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Start sprint and mark status as ACTIVE via stored procedure."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    uid = safe_uuid(current_user.get("id")) if current_user else None
    try:
        await exec_sql(
            "UPDATE public.work_sprints SET status = 'ACTIVE', updated_at = NOW() WHERE id = %s::UUID AND school_id = %s::UUID;",
            (clean_sprint_id, sid),
            fetch=False
        )
        return {"success": True, "sprint_id": sprint_id, "status": "ACTIVE"}
    except Exception as e:
        logger.error(f"[Start Sprint Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/sprints/{sprint_id}/complete")
async def complete_sprint(
    sprint_id: str,
    payload: CompleteSprintRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Complete active sprint and optionally move incomplete items to another sprint or backlog."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    clean_target_id = await resolve_sprint_id(payload.move_incomplete_to_sprint_id, sid) if payload.move_incomplete_to_sprint_id else None
    uid = safe_uuid(current_user.get("id")) if current_user else None
    try:
        # Move incomplete items if requested
        if clean_target_id:
            await exec_sql(
                "UPDATE public.work_items SET sprint_id = %s::UUID, updated_at = NOW() WHERE sprint_id = %s::UUID AND school_id = %s::UUID AND status NOT IN ('COMPLETED', 'RESOLVED');",
                (clean_target_id, clean_sprint_id, sid),
                fetch=False
            )
        else:
            await exec_sql(
                "UPDATE public.work_items SET sprint_id = NULL, updated_at = NOW() WHERE sprint_id = %s::UUID AND school_id = %s::UUID AND status NOT IN ('COMPLETED', 'RESOLVED');",
                (clean_sprint_id, sid),
                fetch=False
            )
        # Mark sprint completed
        await exec_sql(
            "UPDATE public.work_sprints SET status = 'COMPLETED', updated_at = NOW() WHERE id = %s::UUID AND school_id = %s::UUID;",
            (clean_sprint_id, sid),
            fetch=False
        )
        return {"success": True, "sprint_id": sprint_id, "status": "COMPLETED"}
    except Exception as e:
        logger.error(f"[Complete Sprint Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/sprints/{sprint_id}/cancel")
async def cancel_sprint(
    sprint_id: str,
    payload: TransitionSprintLifecycleRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Cancel a sprint with a mandatory reason."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    uid = safe_uuid(current_user.get("id")) if current_user else None
    try:
        rows = await exec_sql(
            "SELECT public.sp_transition_sprint_lifecycle(%s::UUID, %s::UUID, 'CANCELLED', %s::UUID, %s) AS result;",
            (sid, clean_sprint_id, uid, payload.reason or "Cancelled by user")
        )
        return rows[0]["result"] if rows else {"success": True, "sprint_id": sprint_id, "status": "CANCELLED"}
    except Exception as e:
        logger.error(f"[Cancel Sprint Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/sprints/{sprint_id}/work-items")
async def add_work_items_to_sprint(
    sprint_id: str,
    payload: AddItemsToSprintRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Add existing backlog items to a sprint."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    clean_item_ids = [safe_uuid(i) for i in payload.item_ids if safe_uuid(i)]
    uid = safe_uuid(current_user.get("id")) if current_user else None
    try:
        rows = await exec_sql(
            "SELECT public.sp_add_items_to_sprint(%s::UUID, %s::UUID, %s::UUID[], %s::UUID) AS result;",
            (sid, clean_sprint_id, clean_item_ids, uid)
        )
        return rows[0]["result"] if rows else {"success": True, "sprint_id": sprint_id}
    except Exception as e:
        logger.error(f"[Add Items To Sprint Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/sprints/{sprint_id}/work-items/{work_item_id}")
async def remove_item_from_sprint(
    sprint_id: str,
    work_item_id: str,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Remove a work item from the sprint without deleting it (returns to backlog)."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    clean_item_id = safe_uuid(work_item_id)
    uid = safe_uuid(current_user.get("id")) if current_user else None
    try:
        rows = await exec_sql(
            "SELECT public.sp_remove_item_from_sprint(%s::UUID, %s::UUID, %s::UUID, %s::UUID) AS result;",
            (sid, clean_sprint_id, clean_item_id, uid)
        )
        return rows[0]["result"] if rows else {"success": True, "item_id": work_item_id}
    except Exception as e:
        logger.error(f"[Remove Item From Sprint Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/sprints/{sprint_id}/work-items/move")
async def move_items_to_another_sprint(
    sprint_id: str,
    payload: MoveItemsToSprintRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Move work items to another sprint (or to backlog if target is null)."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_target_id = await resolve_sprint_id(payload.target_sprint_id, sid) if payload.target_sprint_id and payload.target_sprint_id != "BACKLOG" else None
    clean_item_ids = []
    for raw_id in payload.item_ids:
        u = safe_uuid(raw_id)
        if u:
            clean_item_ids.append(u)
        elif raw_id:
            resolved = await exec_sql(
                "SELECT id FROM public.work_items WHERE school_id = %s::UUID AND UPPER(item_number) = UPPER(%s) LIMIT 1;",
                (sid, str(raw_id).strip())
            )
            if resolved:
                clean_item_ids.append(str(resolved[0]["id"]))
    uid = safe_uuid(current_user.get("id")) if current_user else None
    try:
        rows = await exec_sql(
            "SELECT public.sp_move_items_to_sprint(%s::UUID, %s::UUID, %s::UUID[], %s::UUID) AS result;",
            (sid, clean_target_id, clean_item_ids, uid)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Move Items Sprint Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================================
# SPRINT CAPACITY & WORKLOAD MANAGEMENT ENDPOINTS
# ============================================================================

@router.get("/capacity/teams")
async def list_capacity_teams(
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """List all available teams for the searchable team selector."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    try:
        rows = await exec_sql(
            """
            SELECT t.id, t.name, t.department, t.icon, p.full_name AS lead_name,
                   COUNT(sm.id) AS members_count
            FROM public.work_teams t
            LEFT JOIN public.profiles p ON p.id = t.lead_id
            LEFT JOIN public.sprint_members sm ON sm.team_name = t.name
            WHERE t.school_id = %s::UUID 
              AND COALESCE(t.status, 'ACTIVE') NOT IN ('ARCHIVED', 'DELETED') 
              AND COALESCE(t.is_active, TRUE) = TRUE
            GROUP BY t.id, t.name, t.department, t.icon, p.full_name
            ORDER BY t.name ASC;
            """,
            (sid,)
        )
        return {"success": True, "teams": rows}
    except Exception as e:
        logger.error(f"[List Capacity Teams Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/sprints/{sprint_id}/capacity")
async def get_sprint_capacity_dashboard(
    sprint_id: str,
    team: Optional[str] = Query("All Teams"),
    search: Optional[str] = Query(None),
    page: Optional[int] = Query(1, ge=1),
    limit: Optional[int] = Query(None),
    sort_by: Optional[str] = Query("name"),
    sort_order: Optional[str] = Query("asc"),
    role: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """
    Get Sprint Capacity & Workload Dashboard:
    - 6 KPIs: Team Members, Total Capacity, Planned Work, Remaining, Util %, Over Allocation
    - Capacity vs Workload (Daily) chart points
    - Team Member Capacity & Workload table with DB-level Filtering, Sorting & Pagination
    - Capacity Utilization Donut Chart
    - Capacity Summary Breakdown
    - Smart Capacity Insights Recommendations
    - Searchable Teams & Sprints list
    """
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user and hasattr(current_user, 'get') else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    clean_team = safe_str(team, "All Teams")
    clean_search = safe_str(search, None)
    clean_page = max(1, page or 1)
    clean_limit = limit if (limit and limit > 0) else None
    clean_sort_by = safe_str(sort_by, "name")
    clean_sort_order = safe_str(sort_order, "asc")
    clean_role = safe_str(role, None)
    clean_status = safe_str(status, None)

    try:
        rows = await exec_sql(
            "SELECT public.sp_get_sprint_capacity_dashboard(%s::UUID, %s::UUID, %s, %s, %s, %s, %s, %s, %s, %s) AS result;",
            (sid, clean_sprint_id, clean_team, clean_search, clean_page, clean_limit, clean_sort_by, clean_sort_order, clean_role, clean_status)
        )
        if rows and rows[0].get("result"):
            return rows[0]["result"]
        return {"kpis": {}, "daily_chart": [], "members": []}
    except Exception as e:
        logger.error(f"[Sprint Capacity Dashboard Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/sprints/{sprint_id}/capacity/members")
async def manage_capacity_member(
    sprint_id: str,
    payload: ManageMemberCapacityRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Add or adjust member capacity (daily hours, working days, overrides, notes)."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    clean_user_id = safe_uuid(payload.user_id)
    try:
        rows = await exec_sql(
            """
            SELECT public.sp_manage_member_capacity(
                %s::UUID, %s::UUID, %s::UUID, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s::UUID
            ) AS result;
            """,
            (sid, clean_sprint_id, clean_user_id, payload.role, payload.team_name,
             payload.available_hours, payload.daily_hours, payload.working_days,
             payload.override_value, payload.override_reason, payload.notes, payload.action or "UPSERT",
             payload.days_off or 0.0, safe_uuid(payload.team_id))
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Manage Capacity Member Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/sprints/{sprint_id}/capacity/members/{user_id}")
async def remove_capacity_member(
    sprint_id: str,
    user_id: str,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Remove member from sprint team capacity."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    clean_user_id = safe_uuid(user_id)
    try:
        rows = await exec_sql(
            "SELECT public.sp_manage_member_capacity(%s::UUID, %s::UUID, %s::UUID, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'REMOVE') AS result;",
            (sid, clean_sprint_id, clean_user_id)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Remove Capacity Member Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/roles")
async def get_work_roles(
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Fetch all active system and application roles from app_roles table for work role dropdowns."""
    try:
        rows = await exec_sql(
            """
            SELECT code, name, COALESCE(display_name, name) AS label, description
            FROM public.app_roles
            WHERE LOWER(status) = 'active'
            ORDER BY COALESCE(display_order, 99) ASC, COALESCE(display_name, name) ASC;
            """
        )
        return {"roles": rows or []}
    except Exception as e:
        logger.error(f"[Get Work Roles Error]: {e}", exc_info=True)
        return {"roles": []}


@router.post("/sprints/{sprint_id}/capacity/availability")
async def manage_member_availability(
    sprint_id: str,
    payload: MemberAvailabilityRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Add or update member leave / availability exception, deducting available hours."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    clean_user_id = safe_uuid(payload.user_id)
    clean_avail_id = safe_uuid(payload.availability_id)
    try:
        rows = await exec_sql(
            """
            SELECT public.sp_manage_member_availability(
                %s::UUID, %s::UUID, %s::UUID, %s::UUID, %s, %s::DATE, %s::DATE, %s, %s, %s
            ) AS result;
            """,
            (sid, clean_sprint_id, clean_user_id, clean_avail_id, payload.availability_type,
             payload.start_date, payload.end_date, payload.unavailable_hours, payload.reason, payload.action or "ADD")
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Manage Availability Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/sprints/{sprint_id}/capacity/availability/{availability_id}")
async def delete_member_availability(
    sprint_id: str,
    availability_id: str,
    user_id: Optional[str] = Query(None),
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Delete an availability exception and recalculate capacity."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    clean_avail_id = safe_uuid(availability_id)
    clean_user_id = safe_uuid(user_id) or "00000000-0000-0000-0000-000000000000"
    try:
        rows = await exec_sql(
            "SELECT public.sp_manage_member_availability(%s::UUID, %s::UUID, %s::UUID, %s::UUID, NULL, CURRENT_DATE, CURRENT_DATE, 0, NULL, 'DELETE') AS result;",
            (sid, clean_sprint_id, clean_user_id, clean_avail_id)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Delete Availability Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/sprints/{sprint_id}/capacity/rebalance")
async def rebalance_workload(
    sprint_id: str,
    payload: RebalanceWorkloadRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Rebalance a work item from an overloaded member to an eligible member."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    clean_item_id = safe_uuid(payload.work_item_id)
    clean_from_id = safe_uuid(payload.from_user_id)
    clean_to_id = safe_uuid(payload.to_user_id)
    uid = safe_uuid(current_user.get("id")) if current_user else None
    try:
        rows = await exec_sql(
            """
            SELECT public.sp_rebalance_sprint_workload(
                %s::UUID, %s::UUID, %s::UUID, %s::UUID, %s::UUID, %s, %s::UUID
            ) AS result;
            """,
            (sid, clean_sprint_id, clean_item_id, clean_from_id, clean_to_id, payload.reason, uid)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Rebalance Workload Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/sprints/{sprint_id}/capacity/export")
async def export_sprint_capacity_csv(
    sprint_id: str,
    team: Optional[str] = Query("All Teams"),
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Export the team member capacity report to CSV."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    clean_team = safe_str(team, "All Teams")
    try:
        dash = await exec_sql(
            "SELECT public.sp_get_sprint_capacity_dashboard(%s::UUID, %s::UUID, %s, NULL) AS result;",
            (sid, clean_sprint_id, clean_team)
        )
        data = dash[0]["result"] if dash else {}
        members = data.get("members", [])

        output = io.StringIO()
        writer = csv.writer(output)
        writer.writerow(["Team Member", "Role", "Department", "Capacity (h)", "Planned (h)", "Actual (h)", "Remaining (h)", "Utilization (%)", "Work Items", "Status"])
        for m in members:
            writer.writerow([
                m.get("full_name"),
                m.get("role"),
                m.get("department"),
                m.get("capacity_hours"),
                m.get("planned_hours"),
                m.get("actual_hours"),
                m.get("remaining_hours"),
                m.get("utilization_pct"),
                m.get("work_items_count"),
                m.get("status")
            ])

        output.seek(0)
        return Response(
            content=output.getvalue(),
            media_type="text/csv",
            headers={"Content-Disposition": f"attachment; filename=Capacity_{clean_team.replace(' ', '_')}.csv"}
        )
    except Exception as e:
        logger.error(f"[Export Capacity CSV Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================================
# 6. SPRINT TEAMS DIRECTORY & ENTERPRISE TEAM ADMINISTRATION ENDPOINTS
# ============================================================================

@router.get("/teams/export")
async def export_teams_csv(
    sprint_id: Optional[str] = Query(None),
    status: Optional[str] = Query("ALL"),
    department: Optional[str] = Query("ALL"),
    search: Optional[str] = Query(None),
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Export the Teams Directory as a CSV file matching table columns."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint = await resolve_sprint_id(sprint_id, sid)
    try:
        rows = await exec_sql(
            "SELECT public.sp_get_teams_directory(%s::UUID, %s::UUID, %s, %s, %s, 'NAME_ASC', 500, 0) AS result;",
            (sid, clean_sprint, status, department, search)
        )
        data = rows[0]["result"] if rows and rows[0]["result"] else {}
        teams = data.get("teams", [])

        output = io.StringIO()
        writer = csv.writer(output)
        writer.writerow(["Team Name", "Key", "Department", "Lead", "Members Count", "Capacity (h)", "Allocated (h)", "Utilization (%)", "Status"])
        for t in teams:
            lead = t.get("lead", {})
            lead_name = lead.get("name", "Unassigned") if isinstance(lead, dict) else "Unassigned"
            writer.writerow([
                t.get("name", ""),
                t.get("team_key", ""),
                t.get("department", ""),
                lead_name,
                t.get("member_count", 0),
                t.get("capacity_hours", 0),
                t.get("planned_hours", 0),
                f"{t.get('utilization_pct', 0)}%",
                t.get("status", "ACTIVE")
            ])

        output.seek(0)
        return Response(
            content=output.getvalue(),
            media_type="text/csv",
            headers={"Content-Disposition": "attachment; filename=Teams_Directory.csv"}
        )
    except Exception as e:
        logger.error(f"[Export Teams Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/teams")
async def list_work_teams(
    sprint_id: Optional[str] = Query(None),
    status: Optional[str] = Query("ALL"),
    department: Optional[str] = Query("ALL"),
    search: Optional[str] = Query(None),
    sort_by: Optional[str] = Query("NAME_ASC"),
    page: int = Query(1, ge=1),
    limit: int = Query(10, ge=1, le=100),
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """
    Get Teams Directory for Sprint Team Management:
    - 7 KPI summary metrics (Total Teams, Members, Capacity, Allocated, Utilization, Active, Inactive)
    - Filterable and paginated teams directory table with avatar stacks and capacity
    """
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint = await resolve_sprint_id(sprint_id, sid)
    offset = (page - 1) * limit
    try:
        rows = await exec_sql(
            "SELECT public.sp_get_teams_directory(%s::UUID, %s::UUID, %s, %s, %s, %s, %s, %s) AS result;",
            (sid, clean_sprint, status, department, search, sort_by, limit, offset)
        )
        if rows and rows[0]["result"]:
            res = rows[0]["result"]
            if isinstance(res, str):
                try:
                    res = json.loads(res)
                except Exception:
                    pass
            if isinstance(res, dict):
                res["page"] = page
                res["limit"] = limit
                return res
        return {"success": True, "kpis": {}, "total_count": 0, "teams": [], "page": page, "limit": limit}
    except Exception as e:
        logger.error(f"[List Work Teams Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/teams/{team_id}")
async def get_team_detail(
    team_id: str,
    sprint_id: Optional[str] = Query(None),
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """
    Get Detailed Team Drawer payload:
    - Team Master info (Code, Department, Lead, Created On, Last Updated)
    - Sprint Capacity & Workload progress stats
    - Team Members list with avatars, roles, individual capacities
    - Team Tags & Sprint Goal
    - Recent Activity audit logs
    - Sprint Work items assigned to this team
    """
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_team_id = safe_uuid(team_id)
    if not clean_team_id:
        raise HTTPException(status_code=400, detail="Invalid team id")
    clean_sprint = await resolve_sprint_id(sprint_id, sid)
    try:
        rows = await exec_sql(
            "SELECT public.sp_get_team_detail_drawer(%s::UUID, %s::UUID, %s::UUID) AS result;",
            (sid, clean_team_id, clean_sprint)
        )
        if rows and rows[0]["result"]:
            res = rows[0]["result"]
            if not res.get("success"):
                raise HTTPException(status_code=404, detail=res.get("error", "Team not found"))
            return res
        raise HTTPException(status_code=404, detail="Team not found")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Get Team Detail Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/teams")
async def create_work_team(
    req: CreateWorkTeamRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Create a new work team with initial lead, members, and default capacity."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    actor_name = (current_user.get("full_name") or current_user.get("name") or "Administrator") if current_user else "Administrator"
    actor_id = safe_uuid(current_user.get("id")) if current_user else None

    team_key = req.team_key
    if not team_key or not team_key.strip():
        words = req.name.strip().split()
        team_key = "".join([w[0].upper() for w in words if w])[:4] or "TEAM"

    try:
        team_rows = await exec_sql(
            """
            INSERT INTO public.work_teams (
                school_id, name, team_key, department, lead_id, description,
                icon, color, default_capacity_hours, tags, goal, status, is_active
            ) VALUES (
                %s::UUID, %s, %s, %s, %s::UUID, %s, %s, %s, %s, %s, %s, 'ACTIVE', TRUE
            )
            RETURNING id, name, team_key, department, is_active, status;
            """,
            (
                sid, req.name.strip(), team_key.strip(), req.department or "General",
                safe_uuid(req.lead_id), req.description or "", req.icon or "layers",
                req.color or "#2563EB", req.capacity_hours or 280.0,
                req.tags or ['General'], req.goal or ""
            )
        )
        if not team_rows:
            raise HTTPException(status_code=400, detail="Failed to create team")

        new_team_id = team_rows[0]["id"]

        if req.lead_id and safe_uuid(req.lead_id):
            await exec_sql(
                """
                INSERT INTO public.work_team_members (school_id, team_id, user_id, role, capacity_hours, is_lead)
                VALUES (%s::UUID, %s::UUID, %s::UUID, 'Team Lead', 40.0, TRUE)
                ON CONFLICT (team_id, user_id) DO UPDATE SET role = 'Team Lead', is_lead = TRUE;
                """,
                (sid, new_team_id, safe_uuid(req.lead_id))
            )

        if req.member_ids:
            for mid in req.member_ids:
                clean_mid = safe_uuid(mid)
                if clean_mid and clean_mid != safe_uuid(req.lead_id):
                    prof_rows = await exec_sql("SELECT role, designation FROM public.profiles WHERE id = %s::UUID;", (clean_mid,))
                    member_role = (prof_rows[0].get("designation") if prof_rows and prof_rows[0].get("designation") else (prof_rows[0].get("role") if prof_rows and prof_rows[0].get("role") else "Member"))
                    await exec_sql(
                        """
                        INSERT INTO public.work_team_members (school_id, team_id, user_id, role, capacity_hours, is_lead)
                        VALUES (%s::UUID, %s::UUID, %s::UUID, %s, 40.0, FALSE)
                        ON CONFLICT DO NOTHING;
                        """,
                        (sid, new_team_id, clean_mid, member_role)
                    )

        # Log activity
        await exec_sql(
            """
            INSERT INTO public.work_team_activities (school_id, team_id, activity_type, description, actor_name, actor_id)
            VALUES (%s::UUID, %s::UUID, 'TEAM_CREATED', %s, %s, %s::UUID);
            """,
            (sid, new_team_id, f"Team '{req.name}' created with key '{team_key}'", actor_name, actor_id)
        )

        return {"success": True, "message": "Team created successfully", "team": team_rows[0]}
    except Exception as e:
        logger.error(f"[Create Work Team Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.patch("/teams/{team_id}")
async def update_work_team(
    team_id: str,
    req: UpdateWorkTeamRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Update team metadata, capacity, lead, tags, goal, or status."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_team_id = safe_uuid(team_id)
    if not clean_team_id:
        raise HTTPException(status_code=400, detail="Invalid team id")
    actor_name = (current_user.get("full_name") or current_user.get("name") or "Administrator") if current_user else "Administrator"
    actor_id = safe_uuid(current_user.get("id")) if current_user else None

    try:
        updates = []
        params = []
        is_lead_explicit = "lead_id" in req.model_fields_set or req.lead_id is not None
        clean_lead_id = safe_uuid(req.lead_id) if (req.lead_id and str(req.lead_id).strip().lower() not in ("unassigned", "none", "null", "")) else None
        if req.name is not None:
            updates.append("name = %s")
            params.append(req.name.strip())
        if req.team_key is not None:
            updates.append("team_key = %s")
            params.append(req.team_key.strip())
        if req.department is not None:
            updates.append("department = %s")
            params.append(req.department.strip())
        if is_lead_explicit:
            if clean_lead_id:
                updates.append("lead_id = %s::UUID")
                params.append(clean_lead_id)
            else:
                updates.append("lead_id = NULL")
        if req.description is not None:
            updates.append("description = %s")
            params.append(req.description)
        if req.icon is not None:
            updates.append("icon = %s")
            params.append(req.icon)
        if req.color is not None:
            updates.append("color = %s")
            params.append(req.color)
        if req.status is not None:
            updates.append("status = %s")
            params.append(req.status)
        if req.is_active is not None:
            updates.append("is_active = %s")
            params.append(req.is_active)
        if req.capacity_hours is not None:
            updates.append("default_capacity_hours = %s")
            params.append(req.capacity_hours)
        if req.tags is not None:
            updates.append("tags = %s")
            params.append(req.tags)
        if req.goal is not None:
            updates.append("goal = %s")
            params.append(req.goal)

        if updates:
            updates.append("updated_at = NOW()")
            params.extend([clean_team_id, sid])
            await exec_sql(
                f"UPDATE public.work_teams SET {', '.join(updates)} WHERE id = %s::UUID AND school_id = %s::UUID;",
                tuple(params),
                fetch=False
            )

        # Synchronize team members is_lead flag if lead was modified
        if is_lead_explicit:
            if clean_lead_id:
                await exec_sql(
                    "UPDATE public.work_team_members SET is_lead = FALSE WHERE team_id = %s::UUID;",
                    (clean_team_id,),
                    fetch=False
                )
                m_exist = await exec_sql(
                    "SELECT id FROM public.work_team_members WHERE team_id = %s::UUID AND user_id = %s::UUID LIMIT 1;",
                    (clean_team_id, clean_lead_id)
                )
                if m_exist:
                    await exec_sql(
                        "UPDATE public.work_team_members SET is_lead = TRUE, role = 'Team Lead' WHERE team_id = %s::UUID AND user_id = %s::UUID;",
                        (clean_team_id, clean_lead_id),
                        fetch=False
                    )
                else:
                    await exec_sql(
                        """
                        INSERT INTO public.work_team_members (school_id, team_id, user_id, role, is_lead, capacity_hours, daily_hours)
                        VALUES (%s::UUID, %s::UUID, %s::UUID, 'Team Lead', TRUE, 80.0, 8.0)
                        ON CONFLICT (team_id, user_id) DO UPDATE SET is_lead = TRUE;
                        """,
                        (sid, clean_team_id, clean_lead_id),
                        fetch=False
                    )
            else:
                await exec_sql(
                    "UPDATE public.work_team_members SET is_lead = FALSE WHERE team_id = %s::UUID;",
                    (clean_team_id,),
                    fetch=False
                )

        act_desc = f"Team updated by {actor_name}"
        act_type = "TEAM_UPDATED"
        if is_lead_explicit:
            if clean_lead_id:
                lead_prof = await exec_sql("SELECT full_name FROM public.profiles WHERE id = %s::UUID LIMIT 1;", (clean_lead_id,))
                lead_name = lead_prof[0]["full_name"] if lead_prof else "Team Lead"
                act_desc = f"Team lead assigned to {lead_name} by {actor_name}"
                act_type = "LEAD_ASSIGNED"
            else:
                act_desc = f"Team lead unassigned by {actor_name}"
                act_type = "LEAD_UNASSIGNED"
        elif req.capacity_hours is not None:
            act_desc = f"Team capacity updated to {int(req.capacity_hours)} h by {actor_name}"
            act_type = "CAPACITY_UPDATED"
        elif req.goal is not None:
            act_desc = f"Team goal updated by {actor_name}"
            act_type = "GOAL_UPDATED"

        await exec_sql(
            """
            INSERT INTO public.work_team_activities (school_id, team_id, activity_type, description, actor_name, actor_id)
            VALUES (%s::UUID, %s::UUID, %s, %s, %s, %s::UUID);
            """,
            (sid, clean_team_id, act_type, act_desc, actor_name, actor_id)
        )

        return {"success": True, "message": "Team updated successfully"}
    except Exception as e:
        logger.error(f"[Update Work Team Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/teams/{team_id}/duplicate")
async def duplicate_work_team(
    team_id: str,
    req: DuplicateWorkTeamRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Duplicate a team with all member assignments."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_team_id = safe_uuid(team_id)
    if not clean_team_id:
        raise HTTPException(status_code=400, detail="Invalid team id")
    actor_name = current_user.get("full_name") if current_user else "Dr. Rajesh Verma"

    try:
        orig = await exec_sql(
            "SELECT * FROM public.work_teams WHERE id = %s::UUID AND school_id = %s::UUID;",
            (clean_team_id, sid)
        )
        if not orig:
            raise HTTPException(status_code=404, detail="Original team not found")

        t = orig[0]
        new_name = (req.new_name or f"Copy of {t['name']}")[:100]
        new_key = (req.new_key or f"{t.get('team_key', 'TM')}_C")[:20]

        dup_rows = await exec_sql(
            """
            INSERT INTO public.work_teams (
                school_id, name, team_key, department, lead_id, description,
                icon, color, default_capacity_hours, tags, goal, status, is_active
            ) VALUES (
                %s::UUID, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'ACTIVE', TRUE
            )
            RETURNING id, name, team_key;
            """,
            (
                sid, new_name, new_key, t["department"], t["lead_id"],
                t["description"], t["icon"], t["color"], t["default_capacity_hours"],
                t["tags"], t["goal"]
            )
        )
        new_id = dup_rows[0]["id"]

        # Copy members
        await exec_sql(
            """
            INSERT INTO public.work_team_members (school_id, team_id, user_id, role, capacity_hours, daily_hours, is_lead)
            SELECT school_id, %s::UUID, user_id, role, capacity_hours, daily_hours, is_lead
            FROM public.work_team_members WHERE team_id = %s::UUID;
            """,
            (new_id, clean_team_id)
        )

        await exec_sql(
            """
            INSERT INTO public.work_team_activities (school_id, team_id, activity_type, description, actor_name)
            VALUES (%s::UUID, %s::UUID, 'TEAM_CREATED', %s, %s);
            """,
            (sid, new_id, f"Team duplicated from '{t['name']}' by {actor_name}", actor_name)
        )

        return {"success": True, "message": "Team duplicated successfully", "team": dup_rows[0]}
    except Exception as e:
        logger.error(f"[Duplicate Work Team Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/teams/{team_id}")
async def delete_work_team(
    team_id: str,
    hard: bool = Query(False),
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Soft-archive or permanently delete a work team."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_team_id = safe_uuid(team_id)
    if not clean_team_id:
        raise HTTPException(status_code=400, detail="Invalid team id")

    try:
        if hard:
            await exec_sql(
                "DELETE FROM public.work_teams WHERE id = %s::UUID AND school_id = %s::UUID;",
                (clean_team_id, sid),
                fetch=False
            )
        else:
            await exec_sql(
                "UPDATE public.work_teams SET is_active = FALSE, status = 'ARCHIVED', updated_at = NOW() WHERE id = %s::UUID AND school_id = %s::UUID;",
                (clean_team_id, sid),
                fetch=False
            )
        return {"success": True, "message": "Team removed/archived successfully"}
    except Exception as e:
        logger.error(f"[Delete Work Team Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/teams/{team_id}/members")
async def add_work_team_member(
    team_id: str,
    req: ManageWorkTeamMemberRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Add one or multiple members to the work team with auto-resolved roles and default capacity."""
    clean_team_id = safe_uuid(team_id)
    if not clean_team_id:
        raise HTTPException(status_code=400, detail="Invalid team id")

    t_rows = await exec_sql("SELECT school_id, name, lead_id FROM public.work_teams WHERE id = %s::UUID LIMIT 1;", (clean_team_id,))
    if not t_rows:
        raise HTTPException(status_code=404, detail="Team not found")
    team_sid = str(t_rows[0]["school_id"])
    actor_name = (current_user.get("full_name") or current_user.get("name") or "Administrator") if current_user else "Administrator"

    # Support both single user_id and multiple user_ids list
    target_uids = []
    if req.user_ids:
        target_uids.extend([safe_uuid(u) for u in req.user_ids if safe_uuid(u)])
    elif req.user_id and safe_uuid(req.user_id):
        target_uids.append(safe_uuid(req.user_id))

    if not target_uids:
        raise HTTPException(status_code=400, detail="At least one valid user_id must be provided")

    try:
        added_names = []
        for uid in target_uids:
            prof_rows = await exec_sql("SELECT full_name, role, designation FROM public.profiles WHERE id = %s::UUID;", (uid,))
            member_role = req.role or (prof_rows[0].get("designation") if prof_rows and prof_rows[0].get("designation") else (prof_rows[0].get("role") if prof_rows and prof_rows[0].get("role") else "Member"))
            uname = prof_rows[0]["full_name"] if prof_rows else "Member"

            await exec_sql(
                """
                INSERT INTO public.work_team_members (
                    school_id, team_id, user_id, role, capacity_hours, daily_hours, is_lead
                ) VALUES (
                    %s::UUID, %s::UUID, %s::UUID, %s, %s, %s, %s
                )
                ON CONFLICT (team_id, user_id) DO UPDATE SET
                    role = COALESCE(EXCLUDED.role, work_team_members.role),
                    capacity_hours = COALESCE(EXCLUDED.capacity_hours, work_team_members.capacity_hours),
                    daily_hours = COALESCE(EXCLUDED.daily_hours, work_team_members.daily_hours),
                    is_lead = COALESCE(EXCLUDED.is_lead, work_team_members.is_lead),
                    updated_at = NOW();
                """,
                (
                    team_sid, clean_team_id, uid, member_role,
                    req.capacity_hours or 40.0, req.daily_hours or 8.0, req.is_lead or False
                )
            )
            added_names.append(uname)

        desc = f"Added {len(added_names)} member(s): {', '.join(added_names[:3])}" + ("..." if len(added_names) > 3 else "")
        await exec_sql(
            """
            INSERT INTO public.work_team_activities (school_id, team_id, activity_type, description, actor_name)
            VALUES (%s::UUID, %s::UUID, 'MEMBER_ADDED', %s, %s);
            """,
            (team_sid, clean_team_id, desc, actor_name)
        )

        return {
            "success": True,
            "message": f"{len(added_names)} member(s) added successfully",
            "added_count": len(added_names),
            "members": added_names
        }
    except Exception as e:
        logger.error(f"[Add Work Team Member Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/teams/{team_id}/members/{user_id}")
async def remove_work_team_member(
    team_id: str,
    user_id: str,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Remove a member from the work team."""
    clean_team_id = safe_uuid(team_id)
    clean_user_id = safe_uuid(user_id)
    if not clean_team_id or not clean_user_id:
        raise HTTPException(status_code=400, detail="Invalid team or user id")

    t_rows = await exec_sql("SELECT school_id, name, lead_id FROM public.work_teams WHERE id = %s::UUID LIMIT 1;", (clean_team_id,))
    if not t_rows:
        raise HTTPException(status_code=404, detail="Team not found")
    team_sid = str(t_rows[0]["school_id"])
    team_lead_id = str(t_rows[0]["lead_id"]) if t_rows[0].get("lead_id") else None

    actor_name = (current_user.get("full_name") or current_user.get("name") or "Administrator") if current_user else "Administrator"

    try:
        user_rows = await exec_sql("SELECT full_name FROM public.profiles WHERE id = %s::UUID;", (clean_user_id,))
        uname = user_rows[0]["full_name"] if user_rows else "Member"

        await exec_sql(
            "DELETE FROM public.work_team_members WHERE team_id = %s::UUID AND user_id = %s::UUID;",
            (clean_team_id, clean_user_id),
            fetch=False
        )

        # If removed user was the team lead, unassign lead from team
        if team_lead_id and team_lead_id == str(clean_user_id):
            await exec_sql(
                "UPDATE public.work_teams SET lead_id = NULL, updated_at = NOW() WHERE id = %s::UUID;",
                (clean_team_id,),
                fetch=False
            )

        await exec_sql(
            """
            INSERT INTO public.work_team_activities (school_id, team_id, activity_type, description, actor_name)
            VALUES (%s::UUID, %s::UUID, 'MEMBER_REMOVED', %s, %s);
            """,
            (team_sid, clean_team_id, f"Member {uname} removed from the team", actor_name)
        )

        return {"success": True, "message": f"Member {uname} removed successfully"}
    except Exception as e:
        logger.error(f"[Remove Work Team Member Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/sprints/{sprint_id}/members")
async def manage_sprint_member(
    sprint_id: str,
    payload: ManageSprintMemberRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Add or update member capacity for a sprint."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    clean_user_id = safe_uuid(payload.user_id)
    try:
        rows = await exec_sql(
            "SELECT public.sp_manage_sprint_member(%s::UUID, %s::UUID, %s::UUID, %s, %s, %s) AS result;",
            (sid, clean_sprint_id, clean_user_id, payload.role, payload.available_hours, payload.action or "UPSERT")
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Manage Sprint Member Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/sprints/{sprint_id}/members/{user_id}")
async def remove_sprint_member(
    sprint_id: str,
    user_id: str,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Remove member from a sprint."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    clean_user_id = safe_uuid(user_id)
    try:
        rows = await exec_sql(
            "SELECT public.sp_manage_sprint_member(%s::UUID, %s::UUID, %s::UUID, NULL, NULL, 'REMOVE') AS result;",
            (sid, clean_sprint_id, clean_user_id)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Remove Sprint Member Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/sprints/{sprint_id}/blockers")
async def create_sprint_blocker(
    sprint_id: str,
    payload: ManageSprintBlockerRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Report an impediment / blocker on a sprint."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    clean_item_id = safe_uuid(payload.work_item_id)
    clean_owner_id = safe_uuid(payload.owner_id)
    uid = safe_uuid(current_user.get("id")) if current_user else None
    try:
        rows = await exec_sql(
            """
            SELECT public.sp_manage_sprint_blocker(
                %s::UUID, %s::UUID, NULL, %s::UUID, %s, %s, %s, %s, %s::UUID, %s::DATE, NULL, 'CREATE', %s::UUID
            ) AS result;
            """,
            (sid, clean_sprint_id, clean_item_id, payload.title, payload.description,
             payload.severity, payload.status, clean_owner_id, payload.expected_resolution_date, uid)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Create Blocker Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.patch("/sprints/{sprint_id}/blockers/{blocker_id}")
async def update_sprint_blocker(
    sprint_id: str,
    blocker_id: str,
    payload: ManageSprintBlockerRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Update or resolve a blocker."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    clean_blocker_id = safe_uuid(blocker_id)
    clean_item_id = safe_uuid(payload.work_item_id)
    clean_owner_id = safe_uuid(payload.owner_id)
    action = "RESOLVE" if payload.status == "RESOLVED" else "UPDATE"
    try:
        rows = await exec_sql(
            """
            SELECT public.sp_manage_sprint_blocker(
                %s::UUID, %s::UUID, %s::UUID, %s::UUID, %s, %s, %s, %s, %s::UUID, %s::DATE, %s, %s, NULL
            ) AS result;
            """,
            (sid, clean_sprint_id, clean_blocker_id, clean_item_id, payload.title, payload.description,
             payload.severity, payload.status, clean_owner_id, payload.expected_resolution_date, payload.resolution_notes, action)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Update Blocker Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/sprints/{sprint_id}/blockers/{blocker_id}")
async def delete_sprint_blocker(
    sprint_id: str,
    blocker_id: str,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Delete a blocker."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    clean_blocker_id = safe_uuid(blocker_id)
    try:
        rows = await exec_sql(
            "SELECT public.sp_manage_sprint_blocker(%s::UUID, %s::UUID, %s::UUID, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'DELETE', NULL) AS result;",
            (sid, clean_sprint_id, clean_blocker_id)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Delete Blocker Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# ----------------------------------------------------------------------------
# 6. SPRINT RETROSPECTIVE & ACTION ITEMS
# ----------------------------------------------------------------------------
@router.get("/sprints/{sprint_id}/retrospective")
async def get_sprint_retrospective_workspace(
    sprint_id: str,
    team_id: Optional[str] = Query(None),
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Retrieve full Sprint Retrospective workspace with discussion board, action items, participants, history, and feedback."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    clean_team_id = safe_uuid(team_id)
    t_name = None
    if not clean_team_id and team_id and str(team_id).strip().lower() not in ("all", "all teams", "none", ""):
        t_rows = await exec_sql(
            "SELECT id, name FROM public.work_teams WHERE school_id = %s::UUID AND LOWER(name) = LOWER(%s) AND COALESCE(status, 'ACTIVE') NOT IN ('ARCHIVED', 'DELETED') AND COALESCE(is_active, TRUE) = TRUE LIMIT 1;",
            (sid, str(team_id).strip())
        )
        if t_rows:
            clean_team_id = t_rows[0]["id"]
            t_name = t_rows[0]["name"]
        else:
            clean_team_id = None
            t_name = None
    elif clean_team_id:
        t_rows = await exec_sql(
            "SELECT name FROM public.work_teams WHERE id = %s::UUID AND school_id = %s::UUID AND COALESCE(status, 'ACTIVE') NOT IN ('ARCHIVED', 'DELETED') AND COALESCE(is_active, TRUE) = TRUE LIMIT 1;", 
            (clean_team_id, sid)
        )
        if t_rows:
            t_name = t_rows[0]["name"]
        else:
            clean_team_id = None
            t_name = None

    actor_id = safe_uuid(current_user.get("id")) if (current_user and hasattr(current_user, 'get')) else None
    try:
        rows = await exec_sql(
            "SELECT public.sp_get_sprint_retrospective_workspace(%s::UUID, %s::UUID, %s::UUID, %s::UUID, %s) AS workspace;",
            (sid, clean_sprint_id, clean_team_id, actor_id, t_name)
        )
        return rows[0]["workspace"] if rows else {}
    except Exception as e:
        logger.error(f"[Get Retro Workspace Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.patch("/sprints/{sprint_id}/retrospective")
async def update_sprint_retrospective_session(
    sprint_id: str,
    payload: UpdateRetroSessionRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Update retrospective title, facilitator, duration, sprint goal, summary or notes."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    clean_fac_id = safe_uuid(payload.facilitator_id)
    uid = safe_uuid(current_user.get("id")) if current_user else None
    try:
        rows = await exec_sql(
            """
            SELECT public.sp_manage_sprint_retrospective_session(
                %s::UUID, %s::UUID, %s, %s, %s::TIMESTAMPTZ, %s, %s::UUID, %s, %s, %s, %s, %s::UUID
            ) AS result;
            """,
            (sid, clean_sprint_id, payload.title, payload.status, payload.session_date,
             payload.duration_minutes, clean_fac_id, payload.sprint_goal, payload.summary,
             payload.notes, payload.action or "UPDATE", uid)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Update Retro Session Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/sprints/{sprint_id}/retrospective/start")
async def start_sprint_retrospective_session(
    sprint_id: str,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Start active retrospective discussion session."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    uid = safe_uuid(current_user.get("id")) if current_user else None
    try:
        rows = await exec_sql(
            "SELECT public.sp_manage_sprint_retrospective_session(%s::UUID, %s::UUID, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'START', %s::UUID) AS result;",
            (sid, clean_sprint_id, uid)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Start Retro Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/sprints/{sprint_id}/retrospective/close")
async def close_sprint_retrospective_session(
    sprint_id: str,
    payload: Optional[UpdateRetroSessionRequest] = None,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Close retrospective and finalize summary."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    uid = safe_uuid(current_user.get("id")) if current_user else None
    summary = payload.summary if payload else None
    try:
        rows = await exec_sql(
            "SELECT public.sp_manage_sprint_retrospective_session(%s::UUID, %s::UUID, NULL, NULL, NULL, NULL, NULL, NULL, %s, NULL, 'CLOSE', %s::UUID) AS result;",
            (sid, clean_sprint_id, summary, uid)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Close Retro Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/sprints/{sprint_id}/retrospective/reopen")
async def reopen_sprint_retrospective_session(
    sprint_id: str,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Reopen retrospective session."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    uid = safe_uuid(current_user.get("id")) if current_user else None
    try:
        rows = await exec_sql(
            "SELECT public.sp_manage_sprint_retrospective_session(%s::UUID, %s::UUID, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'REOPEN', %s::UUID) AS result;",
            (sid, clean_sprint_id, uid)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Reopen Retro Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/sprints/{sprint_id}/retrospective/start-new")
async def start_new_sprint_retrospective_session(
    sprint_id: str,
    payload: Optional[UpdateRetroSessionRequest] = None,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Start a new retrospective session cycle for this sprint."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    uid = safe_uuid(current_user.get("id")) if current_user else None
    title = payload.title if payload else None
    dur = payload.duration_minutes if payload else None
    goal = payload.sprint_goal if payload else None
    summary = payload.summary if payload else None
    notes = payload.notes if payload else None
    fac_id = safe_uuid(payload.facilitator_id) if payload else None
    try:
        rows = await exec_sql(
            """
            SELECT public.sp_manage_sprint_retrospective_session(
                %s::UUID, %s::UUID, %s, 'IN_PROGRESS', NOW(), %s, %s::UUID, %s, %s, %s, 'START_NEW', %s::UUID
            ) AS result;
            """,
            (sid, clean_sprint_id, title, dur, fac_id, goal, summary, notes, uid)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Start New Retro Session Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/sprints/{sprint_id}/retrospective/reset")
async def reset_sprint_retrospective_board(
    sprint_id: str,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Reset retrospective discussion board entries and reopen session."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    uid = safe_uuid(current_user.get("id")) if current_user else None
    try:
        rows = await exec_sql(
            "SELECT public.sp_manage_sprint_retrospective_session(%s::UUID, %s::UUID, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'RESET', %s::UUID) AS result;",
            (sid, clean_sprint_id, uid)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Reset Retro Board Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))



@router.post("/sprints/{sprint_id}/retrospective/entries")
async def add_retro_entry(
    sprint_id: str,
    payload: ManageRetroEntryRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Add a feedback card to Sprint Retrospective (WENT_WELL, DID_NOT_GO_WELL, TO_IMPROVE)."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    uid = safe_uuid(current_user.get("id")) if current_user else None
    clean_team_id = safe_uuid(payload.team_id)
    t_name = payload.team_name
    if not clean_team_id and payload.team_id and str(payload.team_id).strip().lower() not in ("all", "all teams", "none", ""):
        t_name = str(payload.team_id).strip()
    try:
        rows = await exec_sql(
            "SELECT public.sp_manage_sprint_retrospective_entry_v2(%s::UUID, %s::UUID, NULL, %s, %s, 'ADD', %s::UUID, %s::UUID, %s) AS result;",
            (sid, clean_sprint_id, payload.category, payload.content, uid, clean_team_id, t_name)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Add Retro Entry Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.patch("/sprints/{sprint_id}/retrospective/entries/{entry_id}")
async def update_retro_entry(
    sprint_id: str,
    entry_id: str,
    payload: ManageRetroEntryRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Update content or category of a retrospective feedback card."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    clean_entry_id = safe_uuid(entry_id)
    clean_team_id = safe_uuid(payload.team_id)
    uid = safe_uuid(current_user.get("id")) if current_user else None
    try:
        rows = await exec_sql(
            "SELECT public.sp_manage_sprint_retrospective_entry_v2(%s::UUID, %s::UUID, %s::UUID, %s, %s, 'UPDATE', %s::UUID, %s::UUID, %s) AS result;",
            (sid, clean_sprint_id, clean_entry_id, payload.category, payload.content, uid, clean_team_id, payload.team_name)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Update Retro Entry Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/sprints/{sprint_id}/retrospective/entries/{entry_id}")
async def delete_retro_entry(
    sprint_id: str,
    entry_id: str,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Delete a retrospective feedback card."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    clean_entry_id = safe_uuid(entry_id)
    uid = safe_uuid(current_user.get("id")) if current_user else None
    try:
        rows = await exec_sql(
            "SELECT public.sp_manage_sprint_retrospective_entry_v2(%s::UUID, %s::UUID, %s::UUID, NULL, NULL, 'DELETE', %s::UUID, NULL, NULL) AS result;",
            (sid, clean_sprint_id, clean_entry_id, uid)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Delete Retro Entry Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/sprints/{sprint_id}/retrospective/entries/{entry_id}/vote")
async def vote_retro_entry(
    sprint_id: str,
    entry_id: str,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Toggle vote/unvote for a retrospective feedback card."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    clean_entry_id = safe_uuid(entry_id)
    actor_id = safe_uuid(current_user.get("id")) if (current_user and hasattr(current_user, 'get')) else None
    try:
        rows = await exec_sql(
            "SELECT public.sp_manage_sprint_retrospective_entry_v2(%s::UUID, %s::UUID, %s::UUID, NULL, NULL, 'VOTE', %s::UUID, NULL, NULL) AS result;",
            (sid, clean_sprint_id, clean_entry_id, actor_id)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Vote Retro Entry Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# ----------------------------------------------------------------------------
# 6.1 SPRINT RETROSPECTIVE COMMENTS CRUD
# ----------------------------------------------------------------------------
@router.get("/sprints/{sprint_id}/retrospective/entries/{entry_id}/comments")
async def get_retro_entry_comments(
    sprint_id: str,
    entry_id: str,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """List comments on a sprint retrospective entry."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_entry_id = safe_uuid(entry_id)
    uid = safe_uuid(current_user.get("id")) if (current_user and hasattr(current_user, 'get')) else None
    try:
        rows = await exec_sql(
            "SELECT public.sp_manage_sprint_retro_comment(%s::UUID, %s::UUID, NULL, NULL, 'LIST', %s::UUID) AS result;",
            (sid, clean_entry_id, uid)
        )
        return rows[0]["result"] if rows else {"success": True, "comments": []}
    except Exception as e:
        logger.error(f"[Get Retro Comments Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/sprints/{sprint_id}/retrospective/entries/{entry_id}/comments")
async def add_retro_entry_comment(
    sprint_id: str,
    entry_id: str,
    payload: ManageRetroCommentRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Add a new comment on a sprint retrospective entry."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_entry_id = safe_uuid(entry_id)
    uid = safe_uuid(current_user.get("id")) if (current_user and hasattr(current_user, 'get')) else None
    try:
        rows = await exec_sql(
            "SELECT public.sp_manage_sprint_retro_comment(%s::UUID, %s::UUID, %s, NULL, 'ADD', %s::UUID) AS result;",
            (sid, clean_entry_id, payload.content, uid)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Add Retro Comment Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/sprints/{sprint_id}/retrospective/entries/{entry_id}/comments/{comment_id}")
async def delete_retro_entry_comment(
    sprint_id: str,
    entry_id: str,
    comment_id: str,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Delete a comment on a sprint retrospective entry."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_entry_id = safe_uuid(entry_id)
    clean_comment_id = safe_uuid(comment_id)
    uid = safe_uuid(current_user.get("id")) if (current_user and hasattr(current_user, 'get')) else None
    try:
        rows = await exec_sql(
            "SELECT public.sp_manage_sprint_retro_comment(%s::UUID, %s::UUID, NULL, %s::UUID, 'DELETE', %s::UUID) AS result;",
            (sid, clean_entry_id, clean_comment_id, uid)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Delete Retro Comment Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/sprints/{sprint_id}/retrospective/action-items")
async def add_action_item(
    sprint_id: str,
    payload: ManageActionItemRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Create an action item from a sprint retrospective."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    clean_owner_id = safe_uuid(payload.owner_id)
    clean_link_id = safe_uuid(payload.linked_work_item_id)
    clean_source_id = safe_uuid(payload.source_entry_id)
    clean_team_id = safe_uuid(payload.team_id)
    t_name = payload.team_name
    if not clean_team_id and payload.team_id and str(payload.team_id).strip().lower() not in ("all", "all teams", "none", ""):
        t_name = str(payload.team_id).strip()
    uid = safe_uuid(current_user.get("id")) if current_user else None
    try:
        rows = await exec_sql(
            """
            SELECT public.sp_manage_sprint_action_item_v2(
                %s::UUID, %s::UUID, NULL, %s, %s, %s, %s::UUID, %s::DATE, %s, %s, %s, %s::UUID, %s::UUID, 'ADD', %s::UUID, %s::UUID, %s
            ) AS result;
            """,
            (sid, clean_sprint_id, payload.item_key, payload.title, payload.description,
             clean_owner_id, payload.due_date, payload.priority or "MEDIUM",
             payload.status or "OPEN", payload.progress or 0, clean_link_id, clean_source_id, uid, clean_team_id, t_name)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Add Action Item Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.patch("/sprints/{sprint_id}/retrospective/action-items/{action_item_id}")
async def update_action_item(
    sprint_id: str,
    action_item_id: str,
    payload: ManageActionItemRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Update status, owner, priority or title of a retrospective action item."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    clean_action_id = safe_uuid(action_item_id)
    clean_owner_id = safe_uuid(payload.owner_id)
    clean_link_id = safe_uuid(payload.linked_work_item_id)
    clean_team_id = safe_uuid(payload.team_id)
    t_name = payload.team_name
    if not clean_team_id and payload.team_id and str(payload.team_id).strip().lower() not in ("all", "all teams", "none", ""):
        t_name = str(payload.team_id).strip()
    uid = safe_uuid(current_user.get("id")) if current_user else None
    try:
        rows = await exec_sql(
            """
            SELECT public.sp_manage_sprint_action_item_v2(
                %s::UUID, %s::UUID, %s::UUID, %s, %s, %s, %s::UUID, %s::DATE, %s, %s, %s, %s::UUID, NULL, 'UPDATE', %s::UUID, %s::UUID, %s
            ) AS result;
            """,
            (sid, clean_sprint_id, clean_action_id, payload.item_key, payload.title, payload.description,
             clean_owner_id, payload.due_date, payload.priority, payload.status, payload.progress or 0, clean_link_id, uid, clean_team_id, t_name)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Update Action Item Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/sprints/{sprint_id}/retrospective/action-items/{action_item_id}")
async def delete_action_item(
    sprint_id: str,
    action_item_id: str,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Delete a retrospective action item."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    clean_action_id = safe_uuid(action_item_id)
    uid = safe_uuid(current_user.get("id")) if current_user else None
    try:
        rows = await exec_sql(
            """
            SELECT public.sp_manage_sprint_action_item_v2(
                %s::UUID, %s::UUID, %s::UUID, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'DELETE', %s::UUID, NULL, NULL
            ) AS result;
            """,
            (sid, clean_sprint_id, clean_action_id, uid)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Delete Action Item Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/sprints/{sprint_id}/retrospective/action-items/{action_item_id}/convert-to-work-item")
async def convert_action_item_to_work_item(
    sprint_id: str,
    action_item_id: str,
    payload: Optional[ManageActionItemRequest] = None,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Convert an action item into an actual trackable Work Item."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    clean_action_id = safe_uuid(action_item_id)
    uid = safe_uuid(current_user.get("id")) if current_user else None
    title = payload.title if payload else None
    desc = payload.description if payload else None
    clean_owner = safe_uuid(payload.owner_id) if payload else None
    prio = payload.priority if payload else 'HIGH'
    try:
        rows = await exec_sql(
            """
            SELECT public.sp_manage_sprint_action_item_v2(
                %s::UUID, %s::UUID, %s::UUID, NULL, %s, %s, %s::UUID, NULL, %s, NULL, NULL, NULL, NULL, 'CONVERT_TO_WORK_ITEM', %s::UUID, NULL, NULL
            ) AS result;
            """,
            (sid, clean_sprint_id, clean_action_id, title, desc, clean_owner, prio, uid)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Convert to Work Item Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/sprints/{sprint_id}/retrospective/action-items/{action_item_id}/link-work-item")
async def link_action_item_to_work_item(
    sprint_id: str,
    action_item_id: str,
    payload: Optional[Dict[str, Any]] = None,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Link or unlink an action item with an existing work item."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    clean_action_id = safe_uuid(action_item_id)
    uid = safe_uuid(current_user.get("id")) if current_user else None

    raw_work_item_id = payload.get("work_item_id") if payload else None
    clean_work_id = safe_uuid(raw_work_item_id) if raw_work_item_id else None

    try:
        rows = await exec_sql(
            """
            SELECT public.sp_manage_sprint_action_item_v2(
                %s::UUID, %s::UUID, %s::UUID, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, %s::UUID, NULL, 'LINK_WORK_ITEM', %s::UUID, NULL, NULL
            ) AS result;
            """,
            (sid, clean_sprint_id, clean_action_id, clean_work_id, uid)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Link Work Item Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/sprints/{sprint_id}/retrospective/action-items/bulk-update")
async def bulk_update_action_items(
    sprint_id: str,
    payload: BulkUpdateActionItemsRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Bulk update multiple action items with new status or priority."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    updated_count = 0
    for action_id in payload.action_item_ids:
        clean_id = safe_uuid(action_id)
        if clean_id:
            await exec_sql(
                """
                UPDATE public.sprint_action_items
                SET status = COALESCE(UPPER(%s), status),
                    priority = COALESCE(UPPER(%s), priority),
                    updated_at = NOW()
                WHERE id = %s::UUID;
                """,
                (payload.status, payload.priority, clean_id)
            )
            updated_count += 1
    return {"success": True, "updated_count": updated_count}


@router.post("/sprints/{sprint_id}/retrospective/feedback")
async def submit_retrospective_feedback(
    sprint_id: str,
    payload: ManageRetroFeedbackRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Submit anonymous or identified sprint retrospective feedback."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    uid = safe_uuid(current_user.get("id")) if current_user else None
    try:
        rows = await exec_sql(
            """
            SELECT public.sp_manage_sprint_retrospective_feedback(
                %s::UUID, %s::UUID, %s, %s, %s, %s, %s, %s::UUID, 'SUBMIT', NULL
            ) AS result;
            """,
            (sid, clean_sprint_id, payload.category, payload.rating, payload.content,
             payload.suggested_improvement, payload.is_anonymous, uid)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Submit Retro Feedback Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.patch("/sprints/{sprint_id}/retrospective/feedback/{feedback_id}")
async def update_retrospective_feedback(
    sprint_id: str,
    feedback_id: str,
    payload: ManageRetroFeedbackRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Update own retrospective feedback."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    clean_fid = safe_uuid(feedback_id)
    uid = safe_uuid(current_user.get("id")) if current_user else None
    try:
        rows = await exec_sql(
            """
            SELECT public.sp_manage_sprint_retrospective_feedback(
                %s::UUID, %s::UUID, %s, %s, %s, %s, %s, %s::UUID, 'UPDATE', %s::UUID
            ) AS result;
            """,
            (sid, clean_sprint_id, payload.category, payload.rating, payload.content,
             payload.suggested_improvement, payload.is_anonymous, uid, clean_fid)
        )
        res = rows[0]["result"] if rows else {"success": True}
        if res.get("success") is False:
            raise HTTPException(status_code=403, detail=res.get("error", "Permission denied"))
        return res
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Update Retro Feedback Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/sprints/{sprint_id}/retrospective/feedback/{feedback_id}")
async def delete_retrospective_feedback(
    sprint_id: str,
    feedback_id: str,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Delete own retrospective feedback."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    clean_fid = safe_uuid(feedback_id)
    uid = safe_uuid(current_user.get("id")) if current_user else None
    try:
        rows = await exec_sql(
            """
            SELECT public.sp_manage_sprint_retrospective_feedback(
                %s::UUID, %s::UUID, NULL, NULL, NULL, NULL, NULL, %s::UUID, 'DELETE', %s::UUID
            ) AS result;
            """,
            (sid, clean_sprint_id, uid, clean_fid)
        )
        res = rows[0]["result"] if rows else {"success": True}
        if res.get("success") is False:
            raise HTTPException(status_code=403, detail=res.get("error", "Permission denied"))
        return res
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Delete Retro Feedback Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/sprints/{sprint_id}/retrospective/export")
async def export_sprint_retrospective_csv(
    sprint_id: str,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Export complete sprint retrospective report including action items as CSV."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_sprint_id = await resolve_sprint_id(sprint_id, sid)
    try:
        rows = await exec_sql(
            "SELECT public.sp_get_sprint_retrospective_workspace(%s::UUID, %s::UUID, NULL::UUID) AS ws;",
            (sid, clean_sprint_id)
        )
        ws = rows[0]["ws"] if rows else {}
        action_items = ws.get("action_items", [])

        output = io.StringIO()
        writer = csv.writer(output)
        writer.writerow(["ID", "Action Item", "Owner", "Priority", "Due Date", "Status", "Progress", "Linked Work Item"])

        for ai in action_items:
            writer.writerow([
                ai.get("item_key", ""),
                ai.get("title", ""),
                ai.get("owner_name", ""),
                ai.get("priority", ""),
                ai.get("due_date", ""),
                ai.get("status", ""),
                f"{ai.get('progress_percentage', 0)}%",
                ai.get("linked_work_item_key") or "-"
            ])

        csv_content = output.getvalue()
        output.close()

        filename = f"sprint_retrospective_action_items_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}.csv"
        return Response(
            content=csv_content,
            media_type="text/csv",
            headers={"Content-Disposition": f"attachment; filename={filename}"}
        )
    except Exception as e:
        logger.error(f"[Export Retro CSV Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# ----------------------------------------------------------------------------
# 7. COMMENTS & CHECKLISTS
# ----------------------------------------------------------------------------
@router.post("/items/{item_id}/comments")
async def add_item_comment(
    item_id: str,
    payload: AddCommentRequest,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Add a comment to a work item."""
    uid = current_user.get("id") if current_user else "11111111-1111-1111-1111-111111111111"
    try:
        rows = await exec_sql(
            "SELECT public.sp_add_work_item_comment(%s::UUID, %s::UUID, %s) AS result;",
            (item_id, uid, payload.comment_text)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Add Comment Error]: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/items/{item_id}/checklists")
async def add_checklist_item(
    item_id: str,
    payload: AddChecklistRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Add a checklist item to a work item via stored procedure."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    clean_item_id = safe_uuid(item_id)
    uid = safe_uuid(current_user.get("id")) if current_user else None
    try:
        rows = await exec_sql(
            "SELECT public.sp_add_checklist_entry(%s::UUID, %s::UUID, %s, %s::UUID) AS result;",
            (sid, clean_item_id, payload.title, uid)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Add Checklist Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.patch("/checklists/{entry_id}")
async def update_checklist_item(
    entry_id: str,
    payload: UpdateChecklistRequest,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Update a checklist item's title or completion status via stored procedure."""
    clean_entry_id = safe_uuid(entry_id)
    uid = safe_uuid(current_user.get("id")) if current_user else None
    try:
        rows = await exec_sql(
            "SELECT public.sp_update_checklist_entry(%s::UUID, %s, %s, %s::UUID) AS result;",
            (clean_entry_id, payload.title, payload.is_completed, uid)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Update Checklist Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/checklists/{entry_id}")
async def delete_checklist_item(
    entry_id: str,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Delete a checklist item via stored procedure."""
    clean_entry_id = safe_uuid(entry_id)
    uid = safe_uuid(current_user.get("id")) if current_user else None
    try:
        rows = await exec_sql(
            "SELECT public.sp_delete_checklist_entry(%s::UUID, %s::UUID) AS result;",
            (clean_entry_id, uid)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Delete Checklist Error]: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/checklists/{entry_id}/toggle")
async def toggle_checklist(
    entry_id: str,
    payload: ToggleChecklistRequest
):
    """Toggle a checklist item and automatically recalculate work item progress."""
    try:
        rows = await exec_sql(
            "SELECT public.sp_toggle_checklist_entry(%s::UUID, %s) AS result;",
            (entry_id, payload.is_completed)
        )
        return rows[0]["result"] if rows else {"success": True}
    except Exception as e:
        logger.error(f"[Toggle Checklist Error]: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ----------------------------------------------------------------------------
# 8. INTEGRATIONS: USERS & LOOKUPS & ACADEMICS
# ----------------------------------------------------------------------------
@router.get("/users")
async def list_assignable_users(
    q: Optional[str] = Query(None),
    role: Optional[str] = Query(None),
    department: Optional[str] = Query(None),
    limit: Optional[int] = Query(100),
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """
    Search and retrieve institutional users from public.profiles
    (Admins, Teachers, Staff, Students, Hostel, Security, etc.).
    """
    sid = school_id or (current_user.get("school_id") if current_user else None) or "11111111-1111-1111-1111-111111111111"
    try:
        sql = """
            SELECT id, full_name, role, email, avatar_url, department, class_name, roll_number
            FROM public.sp_resolve_target_assignees(
                %s::UUID, 'INDIVIDUAL', %s, NULL, NULL, NULL, NULL, %s, %s
            )
            LIMIT %s;
        """
        clean_role = role if role and role != "All" else None
        clean_dept = department if department and department != "All" else None
        clean_q = q.strip() if q and q.strip() else None
        rows = await exec_sql(sql, (sid, clean_role, clean_dept, clean_q, limit or 100))
        return {"success": True, "users": rows, "count": len(rows)}
    except Exception as e:
        logger.error(f"[List Assignable Users Error]: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/preview-assignees")
async def preview_target_assignees(
    payload: PreviewAssigneesRequest,
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """
    Preview matching assignees dynamically based on assignment mode, role, class, and section.
    """
    sid = school_id or (current_user.get("school_id") if current_user else None) or "11111111-1111-1111-1111-111111111111"
    try:
        cid = safe_uuid(payload.class_id)
        secid = safe_uuid(payload.section_id)
        clean_role = payload.target_role if payload.target_role and payload.target_role != "All" else None
        clean_dept = payload.department if payload.department and payload.department != "All" else None
        clean_q = payload.q.strip() if payload.q and payload.q.strip() else None

        sql = """
            SELECT id, full_name, role, email, avatar_url, department, class_name, roll_number
            FROM public.sp_resolve_target_assignees(
                %s::UUID, %s, %s, %s::UUID, %s, %s::UUID, %s, %s, %s
            )
            LIMIT %s;
        """
        rows = await exec_sql(sql, (
            sid,
            payload.assignment_mode,
            clean_role,
            cid,
            payload.class_name,
            secid,
            payload.section_name,
            clean_dept,
            clean_q,
            payload.limit or 150
        ))
        return {"success": True, "count": len(rows), "users": rows}
    except Exception as e:
        logger.error(f"[Preview Target Assignees Error]: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/academic-options")
async def get_academic_options(
    class_id: Optional[str] = Query(None),
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Get classes with nested sections, subjects per class, and all active subjects from academic records."""
    sid = safe_uuid(school_id) or (safe_uuid(current_user.get("school_id")) if current_user else None) or "11111111-1111-1111-1111-111111111111"
    try:
        sql = """
            SELECT c.id, c.name, c.code,
                   COALESCE(
                     json_agg(
                       json_build_object('id', s.id, 'name', s.name, 'code', s.code)
                       ORDER BY s.display_order ASC NULLS LAST, s.name ASC
                     ) FILTER (WHERE s.id IS NOT NULL), '[]'::json
                   ) as sections
            FROM public.academic_classes c
            LEFT JOIN public.academic_sections s ON s.class_id = c.id AND s.deleted_at IS NULL
            WHERE c.school_id = %s::UUID AND c.deleted_at IS NULL
            GROUP BY c.id, c.name, c.code, c.display_order
            ORDER BY c.display_order ASC NULLS LAST, c.name ASC
            LIMIT 100;
        """
        classes = await exec_sql(sql, (sid,))

        # Fetch all active general subjects
        all_subjects = await exec_sql(
            """
            SELECT id, name, code, type
            FROM public.academic_subjects
            WHERE school_id = %s::UUID
              AND deleted_at IS NULL
              AND (status = 'ACTIVE' OR status IS NULL OR status = 'Active')
            ORDER BY name ASC
            LIMIT 100;
            """,
            (sid,)
        )

        # Map assigned subjects per class from class_subject_assignments
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
            (sid,)
        )
        class_subjects_map = {}
        for r in class_subjects_rows:
            subs = r.get("subjects") or []
            if isinstance(subs, list):
                subs.sort(key=lambda x: str(x.get("name", "")).lower())
            class_subjects_map[str(r["class_id"])] = subs

        target_subjects = []
        if class_id:
            cid = safe_uuid(class_id)
            if cid and cid in class_subjects_map and class_subjects_map[cid]:
                target_subjects = class_subjects_map[cid]
        if not target_subjects:
            target_subjects = all_subjects

        return {
            "success": True,
            "classes": classes,
            "subjects": target_subjects,
            "all_subjects": all_subjects,
            "class_subjects": class_subjects_map
        }
    except Exception as e:
        logger.warning(f"[Academic Options Warning]: {e}")
        return {"success": True, "classes": [], "subjects": [], "all_subjects": [], "class_subjects": {}}


@router.get("/lookups")
async def get_work_lookups(
    school_id: Optional[str] = Query(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user)
):
    """Retrieve dynamic lookup values for Work Types, Priorities, Statuses, and Categories."""
    sid = school_id or (current_user.get("school_id") if current_user else None) or "11111111-1111-1111-1111-111111111111"
    try:
        rows = await exec_sql(
            """
            SELECT k.key_code, lv.value_code, lv.value_name, lv.sort_order
            FROM public.lookup_values lv
            JOIN public.lookup_keys k ON k.id = lv.lookup_key_id
            WHERE lv.school_id = %s::UUID
              AND k.key_code IN ('WORK_ITEM_TYPE', 'WORK_ITEM_PRIORITY', 'WORK_ITEM_STATUS', 'WORK_ITEM_CATEGORY')
              AND lv.status = 'ACTIVE'
            ORDER BY k.key_code, lv.sort_order ASC;
            """,
            (sid,)
        )
        grouped = {}
        for r in rows:
            kc = r["key_code"]
            if kc not in grouped:
                grouped[kc] = []
            grouped[kc].append({"code": r["value_code"], "name": r["value_name"]})

        return {"success": True, "lookups": grouped}
    except Exception as e:
        logger.error(f"[Work Lookups Error]: {e}")
        raise HTTPException(status_code=500, detail=str(e))
