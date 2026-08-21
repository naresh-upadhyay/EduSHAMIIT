"""
Universal Notices & Circulars Engine API for EduSHAMIIT ERP.
Multi-tenant, enterprise-grade notice system supporting all user roles, rich content,
multi-group target audience, approval workflows, recipient acknowledgement tracking,
scheduling & expiry, delivery logs, analytics, and audit logging.
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
# HELPER FUNCTIONS & DATABASE EXECUTION
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


def _serialize_datetime(val: Any) -> Any:
    """Format dates, datetimes, and UUIDs for clean JSON serialization."""
    if isinstance(val, (datetime, date, time)):
        return val.isoformat()
    if isinstance(val, uuid.UUID):
        return str(val)
    if isinstance(val, dict):
        return {k: _serialize_datetime(v) for k, v in val.items()}
    if isinstance(val, list):
        return [_serialize_datetime(v) for v in val]
    return val


# ============================================================================
# PYDANTIC REQUEST & RESPONSE SCHEMAS
# ============================================================================

class NoticeAttachmentSchema(BaseModel):
    id: Optional[str] = None
    name: str
    url: str
    size: Optional[int] = None
    type: Optional[str] = None


class NoticeLinkSchema(BaseModel):
    title: str
    url: str
    type: Optional[str] = "external"


class NoticeCreateRequest(BaseModel):
    title: str = Field(..., min_length=1, max_length=300)
    content: str = Field(..., min_length=1)
    category: Optional[str] = "General"
    priority: Optional[str] = "normal" # 'low', 'normal', 'high', 'urgent'
    status: Optional[str] = "published" # 'draft', 'published', 'scheduled', 'pending_approval'
    target_scope: Optional[str] = "entire_institute" # 'entire_institute', 'roles', 'classes', 'departments', 'custom'
    target_roles: Optional[List[str]] = []
    target_classes: Optional[List[str]] = []
    target_departments: Optional[List[str]] = []
    target_user_ids: Optional[List[str]] = []
    timezone: Optional[str] = "Asia/Kolkata"
    published_at: Optional[str] = None
    scheduled_at: Optional[str] = None
    expires_at: Optional[str] = None
    requires_acknowledgement: Optional[bool] = False
    acknowledgement_deadline: Optional[str] = None
    notification_channels: Optional[List[str]] = ["in_app"]
    send_notification_immediately: Optional[bool] = True
    attachments: Optional[List[NoticeAttachmentSchema]] = []
    links: Optional[List[NoticeLinkSchema]] = []
    requires_approval: Optional[bool] = False
    is_pinned: Optional[bool] = False
    is_urgent: Optional[bool] = False


class NoticeUpdateRequest(BaseModel):
    title: Optional[str] = None
    content: Optional[str] = None
    category: Optional[str] = None
    priority: Optional[str] = None
    status: Optional[str] = None
    target_scope: Optional[str] = None
    target_roles: Optional[List[str]] = None
    target_classes: Optional[List[str]] = None
    target_departments: Optional[List[str]] = None
    target_user_ids: Optional[List[str]] = None
    timezone: Optional[str] = None
    published_at: Optional[str] = None
    scheduled_at: Optional[str] = None
    expires_at: Optional[str] = None
    requires_acknowledgement: Optional[bool] = None
    acknowledgement_deadline: Optional[str] = None
    notification_channels: Optional[List[str]] = None
    attachments: Optional[List[NoticeAttachmentSchema]] = None
    links: Optional[List[NoticeLinkSchema]] = None
    is_pinned: Optional[bool] = None
    is_urgent: Optional[bool] = None


class NoticeAcknowledgeRequest(BaseModel):
    status: Optional[str] = "acknowledged" # 'acknowledged', 'declined'
    decline_reason: Optional[str] = None


class NoticeApprovalRequest(BaseModel):
    action: str = Field(..., description="'approve', 'reject', or 'request_changes'")
    reason: Optional[str] = None


class NoticeBulkActionRequest(BaseModel):
    notice_ids: List[str] = Field(..., min_length=1)
    action: str = Field(..., description="'archive', 'delete', 'restore', 'publish', 'mark_read'")


class NoticeBulkImportRequest(BaseModel):
    notices: List[Dict[str, Any]] = Field(..., min_length=1)


class NoticeCategoryRequest(BaseModel):
    name: str
    code: str
    description: Optional[str] = None
    icon: Optional[str] = "notifications"
    color: Optional[str] = "#3B82F6"
    is_active: Optional[bool] = True
    sort_order: Optional[int] = 0


# ============================================================================
# API ENDPOINTS
# ============================================================================

@router.get("/metadata")
async def get_notice_metadata(
    school_id=Depends(require_school_id),
):
    """Retrieve dynamic roles, classes, and categories for the school."""
    try:
        rows = await exec_sql(
            "SELECT public.fn_get_notice_metadata(%s::UUID) AS result;",
            (school_id,)
        )
        if rows and rows[0].get("result"):
            return _serialize_datetime(rows[0]["result"])
        return {"success": True, "roles": [], "classes": [], "categories": []}
    except Exception as e:
        logger.error(f"[Notices] Failed to fetch notice metadata: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/roles")
async def get_notice_roles(
    school_id=Depends(require_school_id),
):
    """Retrieve active roles dynamically from app_roles and profiles."""
    try:
        rows = await exec_sql(
            """
            SELECT DISTINCT name FROM public.app_roles WHERE status = 'Active' OR status IS NULL
            UNION
            SELECT DISTINCT role AS name FROM public.profiles 
            WHERE (school_id = %s::UUID OR school_id IS NULL) 
              AND role IS NOT NULL 
              AND role != ''
              AND role NOT IN (SELECT name FROM public.app_roles WHERE status = 'Inactive')
            ORDER BY name;
            """,
            (school_id,)
        )
        roles = [r["name"] for r in rows if r.get("name")]
        return {"success": True, "data": roles}
    except Exception as e:
        logger.error(f"[Notices] Failed to fetch roles: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/classes")
async def get_notice_classes(
    school_id=Depends(require_school_id),
):
    """Retrieve active classes dynamically from classes table and profiles."""
    try:
        rows = await exec_sql(
            """
            SELECT DISTINCT name FROM public.classes WHERE (school_id = %s::UUID OR school_id IS NULL) AND is_active = TRUE
            UNION
            SELECT DISTINCT class AS name FROM public.profiles WHERE (school_id = %s::UUID OR school_id IS NULL) AND class IS NOT NULL AND class != ''
            ORDER BY name;
            """,
            (school_id, school_id)
        )
        classes = [r["name"] for r in rows if r.get("name")]
        return {"success": True, "data": classes}
    except Exception as e:
        logger.error(f"[Notices] Failed to fetch classes: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("")
@router.get("/")
async def get_notices(
    tab: str = Query("all", description="Tab filter"),
    search: str = Query("", description="Search term"),
    category: str = Query("", description="Category filter"),
    priority: str = Query("", description="Priority filter"),
    status: str = Query("", description="Status filter"),
    audience: str = Query("", description="Audience filter"),
    from_date: Optional[str] = Query(None, description="From ISO Date"),
    to_date: Optional[str] = Query(None, description="To ISO Date"),
    requires_ack: Optional[bool] = Query(None, description="Requires acknowledgement"),
    is_read: Optional[bool] = Query(None, description="Is read filter"),
    has_attachment: Optional[bool] = Query(None, description="Has attachment filter"),
    sort_by: str = Query("published_at", description="Sort column"),
    sort_order: str = Query("DESC", description="Sort direction"),
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(10, ge=1, le=100, description="Page size"),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Retrieve paginated list of notices matching role, permissions, and filters."""
    user_id = user.get("id")
    try:
        sql = """
            SELECT public.fn_get_notices(
                %s::UUID,
                %s::UUID,
                %s,
                %s,
                %s,
                %s,
                %s,
                %s,
                %s::TIMESTAMPTZ,
                %s::TIMESTAMPTZ,
                %s::BOOLEAN,
                %s::BOOLEAN,
                %s::BOOLEAN,
                %s,
                %s,
                %s::INT,
                %s::INT
            ) AS result;
        """
        rows = await exec_sql(sql, (
            school_id,
            user_id,
            tab,
            search,
            category,
            priority,
            status,
            audience,
            from_date,
            to_date,
            requires_ack,
            is_read,
            has_attachment,
            sort_by,
            sort_order,
            page,
            page_size
        ))
        if rows and rows[0].get("result"):
            return _serialize_datetime(rows[0]["result"])
        return {"success": True, "page": page, "page_size": page_size, "total_records": 0, "total_pages": 0, "data": []}
    except Exception as e:
        logger.error(f"[Notices] Failed to fetch notices: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/summary")
async def get_notice_summary(
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Get aggregated metrics, engagement statistics, and category distribution."""
    user_id = user.get("id")
    try:
        sql = "SELECT public.fn_get_notice_summary(%s::UUID, %s::UUID) AS result;"
        rows = await exec_sql(sql, (school_id, user_id))
        if rows and rows[0].get("result"):
            return _serialize_datetime(rows[0]["result"])
        return {
            "success": True,
            "stats": {"total_notices": 0, "published": 0, "scheduled": 0, "drafts": 0, "expired": 0, "archived": 0, "pending_approval": 0},
            "engagement": {"total_views": 0, "viewed": 0, "not_viewed": 0, "partially_viewed": 0, "view_rate_pct": 0},
            "category_distribution": []
        }
    except Exception as e:
        logger.error(f"[Notices] Failed to fetch summary: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/categories")
async def get_notice_categories(
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """List active notice categories for the school."""
    try:
        sql = """
            SELECT id, name, code, description, icon, color, is_active, sort_order
            FROM public.notice_categories
            WHERE school_id = %s OR school_id IS NULL
            ORDER BY sort_order ASC, name ASC;
        """
        rows = await exec_sql(sql, (school_id,))
        return {"success": True, "data": _serialize_datetime(rows)}
    except Exception as e:
        logger.error(f"[Notices] Failed to fetch categories: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/categories")
async def create_or_update_category(
    req: NoticeCategoryRequest,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Create or update a notice category (Admin & Principal)."""
    user_role = (user.get("role") or "").lower()
    if user_role not in ("super_admin", "admin", "principal", "director"):
        raise HTTPException(status_code=403, detail="Only administrators can manage notice categories")

    try:
        sql = """
            INSERT INTO public.notice_categories (
                school_id, name, code, description, icon, color, is_active, sort_order, created_at
            ) VALUES (
                %s, %s, %s, %s, %s, %s, %s, %s, NOW()
            )
            ON CONFLICT (school_id, code) DO UPDATE SET
                name = EXCLUDED.name,
                description = EXCLUDED.description,
                icon = EXCLUDED.icon,
                color = EXCLUDED.color,
                is_active = EXCLUDED.is_active,
                sort_order = EXCLUDED.sort_order
            RETURNING id, name, code;
        """
        rows = await exec_sql(sql, (
            school_id, req.name, req.code, req.description, req.icon, req.color, req.is_active, req.sort_order
        ))
        return {"success": True, "data": _serialize_datetime(rows[0]) if rows else {}}
    except Exception as e:
        logger.error(f"[Notices] Failed to save category: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/template/download")
async def download_notice_template():
    """Download standardized sample CSV template for bulk notice uploads."""
    csv_content = (
        "title,content,category,priority,status,target_scope,target_roles,target_classes,requires_acknowledgement,is_urgent\n"
        "Annual Sports Day Announcement,All students and staff are invited to participate in the Annual Sports Meet.,Event,high,published,entire_institute,,,true,false\n"
        "Parent Teacher Meeting Notice,Term-1 Parent Teacher Meeting will be conducted this Saturday.,Meeting,normal,published,roles,\"parent,teacher\",,false,false\n"
        "Class 10 Revision Schedule,Extra revision classes schedule for Class 10 Board Examinations.,Academic,high,published,classes,,\"10A, 10B\",true,false\n"
    )
    return Response(
        content=csv_content,
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=notices_sample_template.csv"}
    )


@router.post("/bulk-import")
async def bulk_import_notices(
    req: NoticeBulkImportRequest,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Bulk import multiple notices with validation and audience mapping."""
    user_id = user.get("id")
    created = []
    errors = []

    for idx, item in enumerate(req.notices, start=1):
        title = str(item.get("title") or "").strip()
        content = str(item.get("content") or "").strip()

        if not title:
            errors.append(f"Row {idx}: Title is required")
            continue
        if not content:
            errors.append(f"Row {idx}: Notice content is required")
            continue

        target_roles = item.get("target_roles")
        if isinstance(target_roles, str):
            target_roles = [r.strip().lower() for r in target_roles.split(",") if r.strip()]
        elif not isinstance(target_roles, list):
            target_roles = []

        target_classes = item.get("target_classes")
        if isinstance(target_classes, str):
            target_classes = [c.strip() for c in target_classes.split(",") if c.strip()]
        elif not isinstance(target_classes, list):
            target_classes = []

        target_scope = str(item.get("target_scope") or "entire_institute").strip().lower()
        if target_roles and target_scope != "classes":
            target_scope = "roles"
        elif target_classes and not target_roles:
            target_scope = "classes"

        is_urgent = bool(item.get("is_urgent", False)) or str(item.get("priority", "")).lower() == "urgent"
        priority = "urgent" if is_urgent else str(item.get("priority") or "normal").strip().lower()

        payload = {
            "title": title,
            "content": content,
            "category": str(item.get("category") or "General").strip(),
            "priority": priority,
            "status": str(item.get("status") or "published").strip().lower(),
            "target_scope": target_scope,
            "target_roles": target_roles,
            "target_classes": target_classes,
            "target_departments": [],
            "target_user_ids": [],
            "timezone": "Asia/Kolkata",
            "requires_acknowledgement": bool(item.get("requires_acknowledgement", False)),
            "notification_channels": ["in_app"],
            "send_notification_immediately": True,
            "attachments": [],
            "links": [],
            "is_pinned": bool(item.get("is_pinned", False)),
            "is_urgent": is_urgent,
        }

        try:
            sql = "SELECT public.fn_create_notice(%s::UUID, %s::UUID, %s::JSONB) AS result;"
            rows = await exec_sql(sql, (school_id, user_id, json.dumps(payload)))
            if rows and rows[0].get("result") and rows[0]["result"].get("success"):
                created.append(rows[0]["result"]["notice_id"])
            else:
                err_msg = rows[0]["result"].get("error") if rows and rows[0].get("result") else "Failed to insert notice"
                errors.append(f"Row {idx} ('{title}'): {err_msg}")
        except Exception as e:
            errors.append(f"Row {idx} ('{title}'): {str(e)}")

    return {
        "success": len(created) > 0,
        "message": f"Successfully imported {len(created)} of {len(req.notices)} notices" if created else "No notices were imported",
        "data": {
            "imported_count": len(created),
            "total_rows": len(req.notices),
            "created_notice_ids": created,
            "errors": errors,
        },
        "imported_count": len(created),
        "total_rows": len(req.notices),
        "errors": errors,
    }


@router.get("/{notice_id}")
async def get_notice_detail(
    notice_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Get full details of a notice, attachments, links, and auto-mark as read."""
    user_id = user.get("id")
    try:
        sql = "SELECT public.fn_get_notice_detail(%s::UUID, %s::UUID, %s::UUID) AS result;"
        rows = await exec_sql(sql, (school_id, notice_id, user_id))
        if rows and rows[0].get("result"):
            res = rows[0]["result"]
            if not res.get("success"):
                raise HTTPException(status_code=404, detail=res.get("error", "Notice not found"))
            return _serialize_datetime(res)
        raise HTTPException(status_code=404, detail="Notice not found")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Notices] Failed to get notice detail: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("")
@router.post("/")
async def create_notice(
    req: NoticeCreateRequest,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Create a new notice (draft, schedule, publish, or submit for approval)."""
    user_id = user.get("id")
    user_role = (user.get("role") or "").lower()

    payload = req.dict()
    # Normalize dates
    if req.scheduled_at and req.status == "published":
        payload["status"] = "scheduled"

    try:
        sql = "SELECT public.fn_create_notice(%s::UUID, %s::UUID, %s::JSONB) AS result;"
        rows = await exec_sql(sql, (school_id, user_id, json.dumps(payload)))
        if rows and rows[0].get("result"):
            return _serialize_datetime(rows[0]["result"])
        raise HTTPException(status_code=500, detail="Failed to create notice")
    except Exception as e:
        logger.error(f"[Notices] Failed to create notice: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/{notice_id}")
async def update_notice(
    notice_id: str,
    req: NoticeUpdateRequest,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Update notice details."""
    user_id = user.get("id")
    payload = {k: v for k, v in req.dict().items() if v is not None}
    try:
        sql = "SELECT public.fn_update_notice(%s::UUID, %s::UUID, %s::UUID, %s::JSONB) AS result;"
        rows = await exec_sql(sql, (school_id, notice_id, user_id, json.dumps(payload)))
        if rows and rows[0].get("result"):
            res = rows[0]["result"]
            if not res.get("success"):
                raise HTTPException(status_code=400, detail=res.get("error", "Failed to update notice"))
            return _serialize_datetime(res)
        raise HTTPException(status_code=500, detail="Failed to update notice")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Notices] Failed to update notice: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/{notice_id}")
async def delete_notice(
    notice_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Soft-delete a notice."""
    user_id = user.get("id")
    try:
        sql = "SELECT public.fn_bulk_notice_action(%s::UUID, %s::UUID, ARRAY[%s::UUID], 'delete') AS result;"
        rows = await exec_sql(sql, (school_id, user_id, notice_id))
        return {"success": True, "message": "Notice deleted successfully"}
    except Exception as e:
        logger.error(f"[Notices] Failed to delete notice: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/{notice_id}/publish")
async def publish_notice(
    notice_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Publish a draft or scheduled notice immediately."""
    user_id = user.get("id")
    try:
        sql = "SELECT public.fn_bulk_notice_action(%s::UUID, %s::UUID, ARRAY[%s::UUID], 'publish') AS result;"
        rows = await exec_sql(sql, (school_id, user_id, notice_id))
        return {"success": True, "message": "Notice published successfully"}
    except Exception as e:
        logger.error(f"[Notices] Failed to publish notice: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/{notice_id}/archive")
async def archive_notice(
    notice_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Archive a notice."""
    user_id = user.get("id")
    try:
        sql = "SELECT public.fn_bulk_notice_action(%s::UUID, %s::UUID, ARRAY[%s::UUID], 'archive') AS result;"
        rows = await exec_sql(sql, (school_id, user_id, notice_id))
        return {"success": True, "message": "Notice archived successfully"}
    except Exception as e:
        logger.error(f"[Notices] Failed to archive notice: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/{notice_id}/restore")
async def restore_notice(
    notice_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Restore an archived or deleted notice to draft state."""
    user_id = user.get("id")
    try:
        sql = "SELECT public.fn_bulk_notice_action(%s::UUID, %s::UUID, ARRAY[%s::UUID], 'restore') AS result;"
        rows = await exec_sql(sql, (school_id, user_id, notice_id))
        return {"success": True, "message": "Notice restored to draft"}
    except Exception as e:
        logger.error(f"[Notices] Failed to restore notice: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/{notice_id}/duplicate")
async def duplicate_notice(
    notice_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Duplicate a notice as a new draft."""
    user_id = user.get("id")
    try:
        # Fetch original notice
        orig = await exec_sql(
            "SELECT * FROM public.notices WHERE id = %s AND (school_id = %s OR school_id IS NULL);",
            (notice_id, school_id)
        )
        if not orig:
            raise HTTPException(status_code=404, detail="Original notice not found")

        n = orig[0]
        payload = {
            "title": f"Copy of {n.get('title')}",
            "content": n.get("content"),
            "category": n.get("category"),
            "priority": n.get("priority"),
            "status": "draft",
            "target_scope": n.get("target_scope"),
            "target_roles": n.get("target_roles"),
            "target_classes": n.get("target_classes"),
            "target_departments": n.get("target_departments"),
            "target_user_ids": n.get("target_user_ids"),
            "timezone": n.get("timezone"),
            "requires_acknowledgement": n.get("requires_acknowledgement"),
            "notification_channels": n.get("notification_channels"),
            "attachments": n.get("attachments"),
            "links": n.get("links"),
            "is_pinned": False,
            "is_urgent": n.get("is_urgent"),
        }

        sql = "SELECT public.fn_create_notice(%s::UUID, %s::UUID, %s::JSONB) AS result;"
        rows = await exec_sql(sql, (school_id, user_id, json.dumps(payload)))
        return _serialize_datetime(rows[0]["result"])
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Notices] Failed to duplicate notice: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/{notice_id}/acknowledge")
async def acknowledge_notice(
    notice_id: str,
    req: NoticeAcknowledgeRequest = NoticeAcknowledgeRequest(),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Submit recipient acknowledgement or decline with reason."""
    user_id = user.get("id")
    try:
        sql = "SELECT public.fn_acknowledge_notice(%s::UUID, %s::UUID, %s::UUID, %s, %s) AS result;"
        rows = await exec_sql(sql, (school_id, notice_id, user_id, req.status, req.decline_reason))
        if rows and rows[0].get("result"):
            return _serialize_datetime(rows[0]["result"])
        raise HTTPException(status_code=500, detail="Failed to record acknowledgement")
    except Exception as e:
        logger.error(f"[Notices] Failed to acknowledge notice: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/{notice_id}/approve")
async def approve_notice(
    notice_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Approve a notice submitted for approval."""
    user_id = user.get("id")
    user_role = (user.get("role") or "").lower()
    if user_role not in ("super_admin", "admin", "principal", "vice_principal", "director"):
        raise HTTPException(status_code=403, detail="Only administrators or principals can approve notices")

    try:
        sql = "SELECT public.fn_approve_reject_notice(%s::UUID, %s::UUID, %s::UUID, 'approve', NULL) AS result;"
        rows = await exec_sql(sql, (school_id, notice_id, user_id))
        return _serialize_datetime(rows[0]["result"])
    except Exception as e:
        logger.error(f"[Notices] Failed to approve notice: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/{notice_id}/reject")
async def reject_notice(
    notice_id: str,
    req: NoticeApprovalRequest,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Reject a notice with mandatory reason."""
    user_id = user.get("id")
    user_role = (user.get("role") or "").lower()
    if user_role not in ("super_admin", "admin", "principal", "vice_principal", "director"):
        raise HTTPException(status_code=403, detail="Only administrators or principals can reject notices")

    if not req.reason or not req.reason.strip():
        raise HTTPException(status_code=400, detail="Rejection reason is mandatory")

    try:
        sql = "SELECT public.fn_approve_reject_notice(%s::UUID, %s::UUID, %s::UUID, 'reject', %s) AS result;"
        rows = await exec_sql(sql, (school_id, notice_id, user_id, req.reason.strip()))
        return _serialize_datetime(rows[0]["result"])
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Notices] Failed to reject notice: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{notice_id}/acknowledgements")
async def get_notice_acknowledgements(
    notice_id: str,
    search: str = Query("", description="Search recipient name/class"),
    status: str = Query("", description="Status filter: acknowledged, pending, declined"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Get recipient acknowledgement dashboard with individual read & ack timestamps."""
    try:
        sql = "SELECT public.fn_get_notice_acknowledgements(%s::UUID, %s::UUID, %s, %s, %s::INT, %s::INT) AS result;"
        rows = await exec_sql(sql, (school_id, notice_id, search, status, page, page_size))
        if rows and rows[0].get("result"):
            return _serialize_datetime(rows[0]["result"])
        return {"success": True, "page": page, "page_size": page_size, "data": []}
    except Exception as e:
        logger.error(f"[Notices] Failed to get acknowledgements: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/{notice_id}/remind")
async def remind_pending_recipients(
    notice_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Send reminder notifications to all pending recipients for this notice."""
    user_id = user.get("id")
    try:
        # Query count of pending recipients
        pending_rows = await exec_sql(
            """
            SELECT COUNT(*) AS count
            FROM public.notice_recipients
            WHERE notice_id = %s AND (is_acknowledged IS FALSE OR is_acknowledged IS NULL);
            """,
            (notice_id,)
        )
        count = pending_rows[0]["count"] if pending_rows else 0

        # Log audit entry
        await exec_sql(
            """
            INSERT INTO public.notice_audit_logs (school_id, notice_id, user_id, action, details)
            VALUES (%s, %s, %s, 'reminder_sent', %s::JSONB);
            """,
            (school_id, notice_id, user_id, json.dumps({"reminders_dispatched": count}))
        )

        return {"success": True, "message": f"Reminders queued for {count} pending recipients", "reminded_count": count}
    except Exception as e:
        logger.error(f"[Notices] Failed to send reminders: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/bulk-action")
async def bulk_notice_action(
    req: NoticeBulkActionRequest,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Perform bulk operations across multiple notices."""
    user_id = user.get("id")
    try:
        sql = "SELECT public.fn_bulk_notice_action(%s::UUID, %s::UUID, %s::UUID[], %s) AS result;"
        rows = await exec_sql(sql, (school_id, user_id, req.notice_ids, req.action))
        if rows and rows[0].get("result"):
            return _serialize_datetime(rows[0]["result"])
        return {"success": True, "action": req.action, "affected_count": len(req.notice_ids)}
    except Exception as e:
        logger.error(f"[Notices] Failed to execute bulk action: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

