"""
EduSHAMIIT – Enterprise Collaborative Whiteboard REST & Asset API
Provides full CRUD, multi-page management, idempotent operation sync,
snapshots & version history, RBAC permission control, file/PDF/image asset
storage integration, PDF/PNG/JPEG/SVG export, sharing, and audit logs.
"""
import asyncio
import base64
import json
import os
import re
import tempfile
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

import psycopg2
from psycopg2.extras import RealDictCursor, register_uuid
from fastapi import APIRouter, Body, Depends, File, Form, HTTPException, Query, Request, UploadFile, status
from fastapi.responses import Response, StreamingResponse

from app.config import settings
from app.middleware.auth import get_current_user, require_school_id
from app.services.minio_client import minio_client
from app.services.whiteboard_export import render_whiteboard_pdf, render_whiteboard_raster
from app.services.whiteboard_ws import whiteboard_ws_manager

register_uuid()

router = APIRouter()

ALLOWED_IMAGE_MIMES = {
    "image/png",
    "image/jpeg",
    "image/jpg",
    "image/webp",
    "image/gif",
    "image/bmp",
    "image/svg+xml",
}
ALLOWED_DOC_MIMES = {
    "application/pdf",
    "application/vnd.ms-powerpoint",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    "application/msword",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
}
MAX_ASSET_BYTES = 25 * 1024 * 1024  # 25 MB
LOCAL_WB_STORAGE_DIR = os.path.join(tempfile.gettempdir(), "edushamiit_whiteboard_storage")
os.makedirs(LOCAL_WB_STORAGE_DIR, exist_ok=True)


async def exec_sql(sql: str, params: tuple = (), fetch: bool = True) -> List[Dict[str, Any]]:
    def _run():
        conn = psycopg2.connect(settings.DATABASE_URL, connect_timeout=5)
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(sql, params)
                if fetch and cur.description:
                    rows = cur.fetchall()
                    conn.commit()
                    return [dict(r) for r in rows]
                conn.commit()
                return []
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    return await asyncio.to_thread(_run)


async def _check_permission(whiteboard_id: str, school_id: str, user: Dict[str, Any]) -> Dict[str, Any]:
    rows = await exec_sql(
        "SELECT public.sp_get_whiteboard_user_permission(%s::UUID, %s::UUID, %s::UUID, %s::TEXT) AS perm;",
        (whiteboard_id, school_id, user["id"], user.get("role", "student")),
    )
    perm = rows[0]["perm"] if rows and rows[0].get("perm") else {"allowed": False, "permission": "NONE"}
    if not perm.get("allowed"):
        reason = perm.get("reason", "Access denied")
        code = 404 if "not found" in reason.lower() else 403
        raise HTTPException(status_code=code, detail=reason)
    return perm


_S3_BACKOFF_UNTIL = 0.0


def _s3_is_reachable() -> bool:
    global _S3_BACKOFF_UNTIL
    import socket, time
    from urllib.parse import urlparse
    if not minio_client.s3 or time.time() < _S3_BACKOFF_UNTIL:
        return False
    try:
        parsed = urlparse(minio_client.endpoint_url)
        host = parsed.hostname or "localhost"
        port = parsed.port or (443 if parsed.scheme == "https" else 80)
        with socket.create_connection((host, port), timeout=0.35):
            return True
    except Exception:
        _S3_BACKOFF_UNTIL = time.time() + 120.0
        return False


def _store_bytes_object(storage_key: str, raw_bytes: bytes, content_type: str) -> None:
    """Persist binary object in configured S3/Supabase storage, plus local cache fallback."""
    if _s3_is_reachable():
        try:
            minio_client.s3.put_object(
                Bucket=minio_client.bucket_name,
                Key=storage_key,
                Body=raw_bytes,
                ContentType=content_type,
            )
        except Exception:
            pass
    local_path = os.path.join(LOCAL_WB_STORAGE_DIR, storage_key.replace("/", "_"))
    with open(local_path, "wb") as f:
        f.write(raw_bytes)


def _read_bytes_object(storage_key: str) -> Optional[bytes]:
    if _s3_is_reachable():
        try:
            res = minio_client.s3.get_object(Bucket=minio_client.bucket_name, Key=storage_key)
            return res["Body"].read()
        except Exception:
            pass
    local_path = os.path.join(LOCAL_WB_STORAGE_DIR, storage_key.replace("/", "_"))
    if os.path.exists(local_path):
        with open(local_path, "rb") as f:
            return f.read()
    return None


def _count_pdf_pages(raw_bytes: bytes) -> int:
    try:
        import pypdf
        reader = pypdf.PdfReader(io.BytesIO(raw_bytes))
        return max(1, len(reader.pages))
    except Exception:
        matches = re.findall(rb"/Type\s*/Page[^s]", raw_bytes)
        return max(1, len(matches))


# ============================================================================
# 1. TEMPLATES CATALOG
# ============================================================================

WHITEBOARD_TEMPLATES = [
    {"id": "blank", "name": "Blank Canvas", "category": "General", "background_type": "plain", "description": "Clean crisp white drawing canvas"},
    {"id": "mathematics", "name": "Mathematics (Quadratic & Algebra)", "category": "STEM", "background_type": "light_grid", "description": "Pre-configured coordinate plane and equation layout"},
    {"id": "physics", "name": "Physics & Mechanics", "category": "STEM", "background_type": "engineering", "description": "Engineering grid for force diagrams, circuits & optics"},
    {"id": "chemistry", "name": "Chemistry & Molecular Lab", "category": "STEM", "background_type": "dotted", "description": "Dotted structural layout for reactions & molecular rings"},
    {"id": "biology", "name": "Biology & Life Sciences", "category": "Science", "background_type": "plain", "description": "Diagramming canvas with labelled annotation callouts"},
    {"id": "geography", "name": "Geography & Maps", "category": "Humanities", "background_type": "light_grid", "description": "Grid layout for cartography & climate charts"},
    {"id": "engineering", "name": "Engineering Blueprint", "category": "Technical", "background_type": "engineering", "description": "Precision dark/light technical drawing grid"},
    {"id": "graph_paper", "name": "Graph Paper", "category": "STEM", "background_type": "graph", "description": "High-density Cartesian plotting paper"},
    {"id": "mind_map", "name": "Concept Mind Map", "category": "Planning", "background_type": "dotted", "description": "Central topic hub with branching idea nodes"},
    {"id": "flowchart", "name": "Process Flowchart", "category": "Logic", "background_type": "light_grid", "description": "Structured decision and step boxes with connectors"},
    {"id": "general_teaching", "name": "Ruled Lecture Notebook", "category": "General", "background_type": "ruled", "description": "Classic ruled classroom notes format"},
]


@router.get("/whiteboards/templates")
async def list_whiteboard_templates(user=Depends(get_current_user)):
    return {"success": True, "data": WHITEBOARD_TEMPLATES}


# ============================================================================
# 2. WHITEBOARD CRUD
# ============================================================================

@router.get("/whiteboards")
async def list_whiteboards(
    session_id: Optional[str] = Query(None),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    rows = await exec_sql(
        "SELECT public.sp_list_whiteboards(%s::UUID, %s::UUID, %s::UUID) AS items;",
        (school_id, session_id, user["id"]),
    )
    items = rows[0]["items"] if rows and rows[0].get("items") is not None else []
    return {"success": True, "data": items}


@router.post("/whiteboards")
async def create_whiteboard(
    payload: Dict[str, Any] = Body(...),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    role = str(user.get("role", "")).lower()
    session_id = payload.get("session_id") or payload.get("live_session_id")
    if role == "student" and not session_id:
        raise HTTPException(status_code=403, detail="Only teachers or admins can create standalone whiteboards")
    title = payload.get("title") or "New Class Whiteboard"
    template_type = payload.get("template_type") or "blank"
    collab = payload.get("collaboration_enabled", True)
    description = payload.get("description", "")

    rows = await exec_sql(
        "SELECT public.sp_create_whiteboard(%s::UUID, %s::UUID, %s::UUID, %s::TEXT, %s::TEXT, %s::BOOLEAN, %s::TEXT) AS data;",
        (school_id, session_id, user["id"], title, template_type, collab, description),
    )
    if not rows or not rows[0].get("data"):
        raise HTTPException(status_code=400, detail="Failed to create whiteboard")
    return {"success": True, "data": rows[0]["data"]}


@router.get("/whiteboards/{whiteboard_id}")
async def get_whiteboard(
    whiteboard_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    await _check_permission(whiteboard_id, school_id, user)
    rows = await exec_sql(
        "SELECT public.sp_get_whiteboard_full(%s::UUID, %s::UUID, %s::UUID) AS data;",
        (whiteboard_id, school_id, user["id"]),
    )
    if not rows or not rows[0].get("data"):
        raise HTTPException(status_code=404, detail="Whiteboard not found")
    data = rows[0]["data"]
    data["active_collaborators"] = whiteboard_ws_manager.get_collaborators(whiteboard_id)
    return {"success": True, "data": data}


@router.patch("/whiteboards/{whiteboard_id}")
async def update_whiteboard(
    whiteboard_id: str,
    payload: Dict[str, Any] = Body(...),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    perm = await _check_permission(whiteboard_id, school_id, user)
    if not perm.get("can_manage_permissions") and not perm.get("can_manage_pages"):
        raise HTTPException(status_code=403, detail="Only host/owner can update whiteboard settings")

    rows = await exec_sql(
        "SELECT public.sp_update_whiteboard_meta(%s::UUID, %s::UUID, %s::UUID, %s::TEXT, %s::BOOLEAN, %s::BOOLEAN, %s::BOOLEAN, %s::JSONB, %s::TEXT) AS data;",
        (
            whiteboard_id,
            school_id,
            user["id"],
            payload.get("title"),
            payload.get("collaboration_enabled"),
            payload.get("presentation_mode"),
            payload.get("teacher_only_mode"),
            json.dumps(payload["default_permissions"]) if payload.get("default_permissions") is not None else None,
            payload.get("status"),
        ),
    )
    if not rows or not rows[0].get("data"):
        raise HTTPException(status_code=404, detail="Whiteboard not found")
    wb = rows[0]["data"]

    await whiteboard_ws_manager.broadcast_event(
        whiteboard_id=whiteboard_id,
        institution_id=school_id,
        session_id=str(wb.get("session_id")) if wb.get("session_id") else None,
        user_id=user["id"],
        event_type="permission.changed",
        revision=wb.get("current_revision"),
        payload={
            "title": wb.get("title"),
            "collaboration_enabled": wb.get("collaboration_enabled"),
            "presentation_mode": wb.get("presentation_mode"),
            "teacher_only_mode": wb.get("teacher_only_mode"),
            "default_permissions": wb.get("default_permissions"),
        },
    )
    return {"success": True, "data": wb}


@router.delete("/whiteboards/{whiteboard_id}")
async def delete_whiteboard(
    whiteboard_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    perm = await _check_permission(whiteboard_id, school_id, user)
    if not perm.get("can_manage_permissions"):
        raise HTTPException(status_code=403, detail="Only owner or admin can delete whiteboard")
    await exec_sql(
        "UPDATE public.live_class_whiteboards SET deleted_at = NOW() WHERE id = %s::UUID AND school_id = %s::UUID;",
        (whiteboard_id, school_id),
        fetch=False,
    )
    await exec_sql(
        "SELECT public.sp_log_whiteboard_audit(%s::UUID, %s::UUID, %s::UUID, 'whiteboard.deleted', '{}'::jsonb);",
        (whiteboard_id, school_id, user["id"]),
        fetch=False,
    )
    return {"success": True, "message": "Whiteboard archived"}


# ============================================================================
# 3. MULTI-PAGE MANAGEMENT
# ============================================================================

@router.get("/whiteboards/{whiteboard_id}/pages")
async def list_pages(
    whiteboard_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    await _check_permission(whiteboard_id, school_id, user)
    rows = await exec_sql(
        "SELECT public.sp_get_whiteboard_full(%s::UUID, %s::UUID, %s::UUID)->'pages' AS pages;",
        (whiteboard_id, school_id, user["id"]),
    )
    return {"success": True, "data": (rows[0]["pages"] if rows else []) or []}


@router.post("/whiteboards/{whiteboard_id}/pages")
async def create_page(
    whiteboard_id: str,
    payload: Dict[str, Any] = Body(default={}),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    perm = await _check_permission(whiteboard_id, school_id, user)
    if not perm.get("can_manage_pages"):
        raise HTTPException(status_code=403, detail="Permission denied to create pages")

    rows = await exec_sql(
        "SELECT public.sp_create_whiteboard_page(%s::UUID, %s::UUID, %s::UUID, %s::TEXT, %s::TEXT, %s::JSONB) AS page;",
        (
            whiteboard_id,
            school_id,
            user["id"],
            payload.get("title"),
            payload.get("background_type", "plain"),
            json.dumps(payload.get("background_config", {})),
        ),
    )
    page = rows[0]["page"]
    await whiteboard_ws_manager.broadcast_event(
        whiteboard_id=whiteboard_id,
        institution_id=school_id,
        session_id=None,
        user_id=user["id"],
        page_id=str(page["id"]),
        event_type="page.created",
        payload={"page": page},
    )
    return {"success": True, "data": page}


@router.patch("/whiteboards/{whiteboard_id}/pages/{page_id}")
async def update_page(
    whiteboard_id: str,
    page_id: str,
    payload: Dict[str, Any] = Body(...),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    perm = await _check_permission(whiteboard_id, school_id, user)
    if not perm.get("can_manage_pages"):
        raise HTTPException(status_code=403, detail="Permission denied to update page settings")

    rows = await exec_sql(
        "SELECT public.sp_update_whiteboard_page(%s::UUID, %s::UUID, %s::UUID, %s::UUID, %s::TEXT, %s::TEXT, %s::JSONB, %s::BOOLEAN) AS page;",
        (
            page_id,
            whiteboard_id,
            school_id,
            user["id"],
            payload.get("title"),
            payload.get("background_type"),
            json.dumps(payload["background_config"]) if payload.get("background_config") is not None else None,
            payload.get("is_locked"),
        ),
    )
    page = rows[0]["page"]
    await whiteboard_ws_manager.broadcast_event(
        whiteboard_id=whiteboard_id,
        institution_id=school_id,
        session_id=None,
        user_id=user["id"],
        page_id=page_id,
        event_type="page.updated",
        payload={"page": page},
    )
    return {"success": True, "data": page}


@router.delete("/whiteboards/{whiteboard_id}/pages/{page_id}")
async def delete_page(
    whiteboard_id: str,
    page_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    perm = await _check_permission(whiteboard_id, school_id, user)
    if not perm.get("can_manage_pages"):
        raise HTTPException(status_code=403, detail="Permission denied to delete page")

    rows = await exec_sql(
        "SELECT public.sp_delete_whiteboard_page(%s::UUID, %s::UUID, %s::UUID, %s::UUID) AS deleted;",
        (page_id, whiteboard_id, school_id, user["id"]),
    )
    if not rows or not rows[0].get("deleted"):
        raise HTTPException(status_code=400, detail="Cannot delete the last remaining page")

    await whiteboard_ws_manager.broadcast_event(
        whiteboard_id=whiteboard_id,
        institution_id=school_id,
        session_id=None,
        user_id=user["id"],
        page_id=page_id,
        event_type="page.deleted",
        payload={"page_id": page_id},
    )
    return {"success": True, "page_id": page_id}


@router.post("/whiteboards/{whiteboard_id}/pages/reorder")
async def reorder_pages(
    whiteboard_id: str,
    payload: Dict[str, Any] = Body(...),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    perm = await _check_permission(whiteboard_id, school_id, user)
    if not perm.get("can_manage_pages"):
        raise HTTPException(status_code=403, detail="Permission denied to reorder pages")
    page_ids = payload.get("page_ids") or []
    await exec_sql(
        "SELECT public.sp_reorder_whiteboard_pages(%s::UUID, %s::UUID, %s::UUID, %s::UUID[]);",
        (whiteboard_id, school_id, user["id"], page_ids),
    )
    await whiteboard_ws_manager.broadcast_event(
        whiteboard_id=whiteboard_id,
        institution_id=school_id,
        session_id=None,
        user_id=user["id"],
        event_type="page.updated",
        payload={"reordered_page_ids": page_ids},
    )
    return {"success": True}


@router.post("/whiteboards/{whiteboard_id}/pages/{page_id}/duplicate")
async def duplicate_page(
    whiteboard_id: str,
    page_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    perm = await _check_permission(whiteboard_id, school_id, user)
    if not perm.get("can_manage_pages"):
        raise HTTPException(status_code=403, detail="Permission denied to duplicate page")

    rows = await exec_sql(
        "SELECT public.sp_duplicate_whiteboard_page(%s::UUID, %s::UUID, %s::UUID, %s::UUID) AS page;",
        (page_id, whiteboard_id, school_id, user["id"]),
    )
    if not rows or not rows[0].get("page"):
        raise HTTPException(status_code=404, detail="Source page not found")
    page = rows[0]["page"]
    await whiteboard_ws_manager.broadcast_event(
        whiteboard_id=whiteboard_id,
        institution_id=school_id,
        session_id=None,
        user_id=user["id"],
        page_id=str(page["id"]),
        event_type="page.created",
        payload={"page": page},
    )
    return {"success": True, "data": page}


# ============================================================================
# 4. OPERATIONS, SYNC & SNAPSHOTS
# ============================================================================

@router.post("/whiteboards/{whiteboard_id}/operations")
async def apply_operation(
    whiteboard_id: str,
    payload: Dict[str, Any] = Body(...),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    perm = await _check_permission(whiteboard_id, school_id, user)
    if not perm.get("can_edit"):
        raise HTTPException(status_code=403, detail="You do not have edit permission on this whiteboard")

    # Enforce page lock & student assigned-area constraint on backend
    page_id = payload.get("page_id")
    if page_id and perm.get("permission") != "OWNER":
        p_rows = await exec_sql(
            "SELECT is_locked FROM public.whiteboard_pages WHERE id = %s::UUID AND whiteboard_id = %s::UUID;",
            (page_id, whiteboard_id),
        )
        if p_rows and p_rows[0].get("is_locked"):
            raise HTTPException(status_code=403, detail="This page is locked by the teacher")

    op_id = payload.get("operation_id") or str(uuid.uuid4())
    op_type = payload.get("operation_type") or "object.create"
    obj_id = payload.get("object_id")
    obj_type = payload.get("object_type") or "stroke"
    op_data = payload.get("operation_data") or payload.get("data") or {}

    rows = await exec_sql(
        "SELECT public.sp_apply_whiteboard_operation(%s::UUID, %s::UUID, %s::UUID, %s::UUID, %s::UUID, %s::TEXT, %s::TEXT, %s::TEXT, %s::JSONB) AS res;",
        (
            whiteboard_id,
            page_id,
            school_id,
            user["id"],
            op_id,
            op_type,
            obj_id,
            obj_type,
            json.dumps(op_data),
        ),
    )
    res = rows[0]["res"] if rows else {"success": False}
    if not res.get("success"):
        raise HTTPException(status_code=400, detail=res.get("message", "Operation failed"))

    if not res.get("duplicate"):
        ev_type = {
            "object.create": "object.created",
            "object.update": "object.updated",
            "object.delete": "object.deleted",
            "objects.batch_create": "object.created",
            "objects.batch_delete": "object.deleted",
            "page.clear": "page.updated",
        }.get(op_type, "object.updated")
        await whiteboard_ws_manager.broadcast_event(
            whiteboard_id=whiteboard_id,
            institution_id=school_id,
            session_id=None,
            user_id=user["id"],
            page_id=page_id,
            operation_id=op_id,
            revision=res.get("revision"),
            event_type=ev_type,
            payload={
                "operation_type": op_type,
                "object_id": obj_id,
                "object_type": obj_type,
                "operation_data": op_data,
            },
        )
    return {"success": True, "data": res}


@router.get("/whiteboards/{whiteboard_id}/operations")
async def get_operations(
    whiteboard_id: str,
    since_revision: int = Query(0, ge=0),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    await _check_permission(whiteboard_id, school_id, user)
    rows = await exec_sql(
        "SELECT public.sp_sync_whiteboard_since(%s::UUID, %s::UUID, %s::BIGINT) AS sync;",
        (whiteboard_id, school_id, since_revision),
    )
    sync_data = rows[0]["sync"] if rows and rows[0].get("sync") else {"operations": []}
    return {"success": True, "data": sync_data.get("operations", [])}


@router.get("/whiteboards/{whiteboard_id}/sync")
async def sync_whiteboard(
    whiteboard_id: str,
    since_revision: int = Query(0, ge=0),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    await _check_permission(whiteboard_id, school_id, user)
    rows = await exec_sql(
        "SELECT public.sp_sync_whiteboard_since(%s::UUID, %s::UUID, %s::BIGINT) AS sync;",
        (whiteboard_id, school_id, since_revision),
    )
    if not rows or not rows[0].get("sync"):
        raise HTTPException(status_code=404, detail="Whiteboard not found")
    return {"success": True, "data": rows[0]["sync"]}


@router.post("/whiteboards/{whiteboard_id}/snapshots")
async def create_snapshot(
    whiteboard_id: str,
    payload: Dict[str, Any] = Body(default={}),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    perm = await _check_permission(whiteboard_id, school_id, user)
    if not perm.get("can_edit"):
        raise HTTPException(status_code=403, detail="Edit permission required to save snapshot")
    rows = await exec_sql(
        "SELECT public.sp_create_whiteboard_snapshot(%s::UUID, %s::UUID, %s::UUID, %s::TEXT, %s::BOOLEAN) AS ver;",
        (
            whiteboard_id,
            school_id,
            user["id"],
            payload.get("version_name"),
            payload.get("is_checkpoint", False),
        ),
    )
    if not rows or not rows[0].get("ver"):
        raise HTTPException(status_code=404, detail="Whiteboard not found")
    return {"success": True, "data": rows[0]["ver"]}


# ============================================================================
# 5. COLLABORATORS & PERMISSIONS
# ============================================================================

@router.post("/whiteboards/{whiteboard_id}/join")
async def join_whiteboard(
    whiteboard_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    perm = await _check_permission(whiteboard_id, school_id, user)
    return {
        "success": True,
        "data": {
            "whiteboard_id": whiteboard_id,
            "permission": perm,
            "collaborators": whiteboard_ws_manager.get_collaborators(whiteboard_id),
        },
    }


@router.post("/whiteboards/{whiteboard_id}/leave")
async def leave_whiteboard(
    whiteboard_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    return {"success": True}


@router.get("/whiteboards/{whiteboard_id}/collaborators")
async def get_collaborators(
    whiteboard_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    await _check_permission(whiteboard_id, school_id, user)
    return {"success": True, "data": whiteboard_ws_manager.get_collaborators(whiteboard_id)}


@router.patch("/whiteboards/{whiteboard_id}/permissions")
async def update_permissions(
    whiteboard_id: str,
    payload: Dict[str, Any] = Body(...),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    perm = await _check_permission(whiteboard_id, school_id, user)
    if not perm.get("can_manage_permissions"):
        raise HTTPException(status_code=403, detail="Only host/admin can manage student permissions")

    rows = await exec_sql(
        "SELECT public.sp_set_whiteboard_permission(%s::UUID, %s::UUID, %s::UUID, %s::UUID, %s::TEXT, %s::TEXT, %s::JSONB) AS res;",
        (
            whiteboard_id,
            school_id,
            user["id"],
            payload.get("target_user_id"),
            payload.get("target_role"),
            payload.get("permission_type", "VIEW"),
            json.dumps(payload["assigned_area"]) if payload.get("assigned_area") is not None else None,
        ),
    )
    res = rows[0]["res"]
    await whiteboard_ws_manager.broadcast_event(
        whiteboard_id=whiteboard_id,
        institution_id=school_id,
        session_id=None,
        user_id=user["id"],
        event_type="permission.changed",
        payload={
            "target_user_id": payload.get("target_user_id"),
            "target_role": payload.get("target_role"),
            "permission_type": payload.get("permission_type", "VIEW"),
            "assigned_area": payload.get("assigned_area"),
        },
    )
    return {"success": True, "data": res}


# ============================================================================
# 6. ASSETS (IMAGES / PDF IMPORT)
# ============================================================================

@router.post("/whiteboards/{whiteboard_id}/assets")
async def upload_asset(
    whiteboard_id: str,
    file: UploadFile = File(...),
    page_id: Optional[str] = Form(None),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    perm = await _check_permission(whiteboard_id, school_id, user)
    if not perm.get("can_edit"):
        raise HTTPException(status_code=403, detail="Edit permission required to upload assets")

    mime = (file.content_type or "").lower()
    if mime in ("application/octet-stream", "", "binary/octet-stream") and file.filename:
        import mimetypes
        guessed, _ = mimetypes.guess_type(file.filename)
        if guessed:
            mime = guessed.lower()
        else:
            ext_lower = os.path.splitext(file.filename)[1].lower()
            ext_map = {
                ".png": "image/png",
                ".jpg": "image/jpeg",
                ".jpeg": "image/jpeg",
                ".webp": "image/webp",
                ".gif": "image/gif",
                ".bmp": "image/bmp",
                ".svg": "image/svg+xml",
                ".pdf": "application/pdf",
                ".ppt": "application/vnd.ms-powerpoint",
                ".pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
            }
            if ext_lower in ext_map:
                mime = ext_map[ext_lower]

    if mime not in ALLOWED_IMAGE_MIMES and mime not in ALLOWED_DOC_MIMES:
        raise HTTPException(status_code=400, detail=f"Unsupported file type: {mime}")

    raw_bytes = await file.read()
    if len(raw_bytes) > MAX_ASSET_BYTES:
        raise HTTPException(status_code=400, detail="File exceeds 25 MB limit")

    ext = os.path.splitext(file.filename or "asset.png")[1] or ".bin"
    asset_uuid = str(uuid.uuid4())
    storage_key = f"whiteboards/{school_id}/{whiteboard_id}/{asset_uuid}{ext}"
    _store_bytes_object(storage_key, raw_bytes, mime)

    width = None
    height = None
    page_count = 1
    if mime in ALLOWED_IMAGE_MIMES:
        try:
            from PIL import Image
            import io
            with Image.open(io.BytesIO(raw_bytes)) as im:
                width, height = im.size
        except Exception:
            pass
    elif mime == "application/pdf":
        page_count = _count_pdf_pages(raw_bytes)

    rows = await exec_sql(
        "SELECT public.sp_register_whiteboard_asset(%s::UUID, %s::UUID, %s::UUID, %s::UUID, %s::TEXT, %s::TEXT, %s::TEXT, %s::BIGINT, %s::INT, %s::INT, %s::INT) AS asset;",
        (
            whiteboard_id,
            page_id,
            school_id,
            user["id"],
            storage_key,
            file.filename or "asset",
            mime,
            len(raw_bytes),
            width,
            height,
            page_count,
        ),
    )
    asset = rows[0]["asset"]
    asset["content_url"] = f"/api/whiteboards/{whiteboard_id}/assets/{asset['id']}/content"
    return {"success": True, "data": asset}


@router.get("/whiteboards/{whiteboard_id}/assets")
async def list_assets(
    whiteboard_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    await _check_permission(whiteboard_id, school_id, user)
    rows = await exec_sql(
        "SELECT id, page_id, file_name, mime_type, file_size, width, height, page_count, created_at FROM public.whiteboard_assets WHERE whiteboard_id = %s::UUID AND school_id = %s::UUID AND deleted_at IS NULL ORDER BY created_at DESC;",
        (whiteboard_id, school_id),
    )
    for r in rows:
        r["content_url"] = f"/api/whiteboards/{whiteboard_id}/assets/{r['id']}/content"
    return {"success": True, "data": rows}


@router.get("/whiteboards/{whiteboard_id}/assets/{asset_id}/content")
async def get_asset_content(
    whiteboard_id: str,
    asset_id: str,
    request: Request,
):
    # Support canvas rendering, Web img tags, and direct cross-origin fetches
    rows = await exec_sql(
        "SELECT storage_key, mime_type, file_name FROM public.whiteboard_assets WHERE id = %s::UUID AND whiteboard_id = %s::UUID AND deleted_at IS NULL LIMIT 1;",
        (asset_id, whiteboard_id),
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Asset not found")
    data = _read_bytes_object(rows[0]["storage_key"])
    if data is None:
        raise HTTPException(status_code=404, detail="Asset content unavailable")
    return Response(
        content=data,
        media_type=rows[0]["mime_type"],
        headers={
            "Cache-Control": "public, max-age=86400",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS",
            "Access-Control-Allow-Headers": "*",
        },
    )


@router.delete("/whiteboards/{whiteboard_id}/assets/{asset_id}")
async def delete_asset(
    whiteboard_id: str,
    asset_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    perm = await _check_permission(whiteboard_id, school_id, user)
    if not perm.get("can_edit"):
        raise HTTPException(status_code=403, detail="Edit permission required")
    await exec_sql(
        "UPDATE public.whiteboard_assets SET deleted_at = NOW() WHERE id = %s::UUID AND whiteboard_id = %s::UUID AND school_id = %s::UUID;",
        (asset_id, whiteboard_id, school_id),
        fetch=False,
    )
    return {"success": True}


# ============================================================================
# 7. VERSION HISTORY & RESTORE + AUDIT LOGS
# ============================================================================

@router.get("/whiteboards/{whiteboard_id}/versions")
async def list_versions(
    whiteboard_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    await _check_permission(whiteboard_id, school_id, user)
    rows = await exec_sql(
        "SELECT id, revision, version_name, is_checkpoint, snapshot_id, created_by, COALESCE(created_by_name, 'Teacher') AS created_by_name, created_at FROM public.whiteboard_versions WHERE whiteboard_id = %s::UUID AND school_id = %s::UUID ORDER BY created_at DESC LIMIT 50;",
        (whiteboard_id, school_id),
    )
    return {"success": True, "data": rows}


@router.post("/whiteboards/{whiteboard_id}/versions")
async def create_named_version(
    whiteboard_id: str,
    payload: Dict[str, Any] = Body(...),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    perm = await _check_permission(whiteboard_id, school_id, user)
    if not perm.get("can_edit"):
        raise HTTPException(status_code=403, detail="Edit permission required to save version checkpoint")
    rows = await exec_sql(
        "SELECT public.sp_create_whiteboard_snapshot(%s::UUID, %s::UUID, %s::UUID, %s::TEXT, %s::BOOLEAN) AS ver;",
        (whiteboard_id, school_id, user["id"], payload.get("version_name") or "Named Checkpoint", True),
    )
    return {"success": True, "data": rows[0]["ver"]}


@router.post("/whiteboards/{whiteboard_id}/versions/{version_id}/restore")
async def restore_version(
    whiteboard_id: str,
    version_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    perm = await _check_permission(whiteboard_id, school_id, user)
    if not perm.get("can_manage_pages"):
        raise HTTPException(status_code=403, detail="Only host/teacher can restore a version")
    rows = await exec_sql(
        "SELECT public.sp_restore_whiteboard_version(%s::UUID, %s::UUID, %s::UUID, %s::UUID) AS data;",
        (whiteboard_id, version_id, school_id, user["id"]),
    )
    if not rows or not rows[0].get("data"):
        raise HTTPException(status_code=404, detail="Version not found")
    data = rows[0]["data"]
    await whiteboard_ws_manager.broadcast_event(
        whiteboard_id=whiteboard_id,
        institution_id=school_id,
        session_id=str(data.get("session_id")) if data.get("session_id") else None,
        user_id=user["id"],
        event_type="whiteboard.saved",
        revision=data.get("current_revision"),
        payload={"restored": True, "whiteboard": data},
    )
    return {"success": True, "data": data}


@router.get("/whiteboards/{whiteboard_id}/audit-logs")
async def list_audit_logs(
    whiteboard_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    await _check_permission(whiteboard_id, school_id, user)
    rows = await exec_sql(
        "SELECT id, user_id, user_name, action, metadata, created_at FROM public.whiteboard_audit_logs WHERE whiteboard_id = %s::UUID AND school_id = %s::UUID ORDER BY created_at DESC LIMIT 100;",
        (whiteboard_id, school_id),
    )
    return {"success": True, "data": rows}


# ============================================================================
# 8. SHARING & EXPORT (PDF / PNG / JPEG)
# ============================================================================

@router.post("/whiteboards/{whiteboard_id}/share")
async def share_whiteboard(
    whiteboard_id: str,
    payload: Dict[str, Any] = Body(...),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    perm = await _check_permission(whiteboard_id, school_id, user)
    if not perm.get("can_manage_permissions"):
        raise HTTPException(status_code=403, detail="Only owner/teacher can share whiteboard")

    rows = await exec_sql(
        "SELECT public.sp_share_whiteboard(%s::UUID, %s::UUID, %s::UUID, %s::TEXT, %s::UUID, %s::TEXT, %s::TEXT, %s::TIMESTAMPTZ) AS share;",
        (
            whiteboard_id,
            school_id,
            user["id"],
            payload.get("share_type", "class"),
            payload.get("target_id"),
            payload.get("target_label", "Class 10 - A"),
            payload.get("access_level", "VIEW"),
            payload.get("expires_at"),
        ),
    )
    return {"success": True, "data": rows[0]["share"]}


@router.get("/whiteboards/{whiteboard_id}/shares")
async def list_shares(
    whiteboard_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    await _check_permission(whiteboard_id, school_id, user)
    rows = await exec_sql(
        "SELECT id, share_type, target_id, target_label, access_level, share_token, expires_at, created_at FROM public.whiteboard_shares WHERE whiteboard_id = %s::UUID AND school_id = %s::UUID AND revoked_at IS NULL ORDER BY created_at DESC;",
        (whiteboard_id, school_id),
    )
    return {"success": True, "data": rows}


@router.delete("/whiteboards/{whiteboard_id}/shares/{share_id}")
async def revoke_share(
    whiteboard_id: str,
    share_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    perm = await _check_permission(whiteboard_id, school_id, user)
    if not perm.get("can_manage_permissions"):
        raise HTTPException(status_code=403, detail="Only owner/teacher can revoke share")
    await exec_sql(
        "UPDATE public.whiteboard_shares SET revoked_at = NOW() WHERE id = %s::UUID AND whiteboard_id = %s::UUID AND school_id = %s::UUID;",
        (share_id, whiteboard_id, school_id),
        fetch=False,
    )
    return {"success": True}


@router.post("/whiteboards/{whiteboard_id}/export")
async def export_whiteboard(
    whiteboard_id: str,
    payload: Dict[str, Any] = Body(default={}),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    await _check_permission(whiteboard_id, school_id, user)
    rows = await exec_sql(
        "SELECT public.sp_get_whiteboard_full(%s::UUID, %s::UUID, %s::UUID) AS data;",
        (whiteboard_id, school_id, user["id"]),
    )
    if not rows or not rows[0].get("data"):
        raise HTTPException(status_code=404, detail="Whiteboard not found")
    wb_data = rows[0]["data"]

    fmt = str(payload.get("format", "PDF")).upper()
    scope = str(payload.get("scope", "all_pages"))
    orientation = str(payload.get("orientation", "landscape"))
    page_ids = payload.get("page_ids")
    current_page_id = payload.get("page_id")

    if scope == "current_page" and current_page_id and not page_ids:
        page_ids = [current_page_id]

    if fmt == "PDF":
        out_bytes = await asyncio.to_thread(render_whiteboard_pdf, wb_data, page_ids, orientation)
        mime = "application/pdf"
        ext = "pdf"
    elif fmt in ("PNG", "JPEG", "JPG"):
        target_pid = page_ids[0] if page_ids else current_page_id
        out_bytes = await asyncio.to_thread(render_whiteboard_raster, wb_data, target_pid, fmt)
        mime = "image/jpeg" if fmt in ("JPEG", "JPG") else "image/png"
        ext = "jpg" if fmt in ("JPEG", "JPG") else "png"
    else:
        raise HTTPException(status_code=400, detail="Unsupported export format. Use PDF, PNG, or JPEG.")

    export_key = f"whiteboards/{school_id}/{whiteboard_id}/exports/{uuid.uuid4()}.{ext}"
    _store_bytes_object(export_key, out_bytes, mime)

    rec_rows = await exec_sql(
        "SELECT public.sp_record_whiteboard_export(%s::UUID, %s::UUID, %s::UUID, %s::TEXT, %s::TEXT, %s::TEXT, 'READY') AS exp;",
        (whiteboard_id, school_id, user["id"], fmt, scope, export_key),
    )
    exp = rec_rows[0]["exp"]
    exp["download_url"] = f"/api/whiteboards/{whiteboard_id}/export/{exp['id']}"
    exp["size_bytes"] = len(out_bytes)
    exp["base64"] = base64.b64encode(out_bytes).decode("ascii")
    exp["mime_type"] = mime
    return {"success": True, "data": exp}


@router.get("/whiteboards/{whiteboard_id}/export/{export_id}")
async def download_export(
    whiteboard_id: str,
    export_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    await _check_permission(whiteboard_id, school_id, user)
    rows = await exec_sql(
        "SELECT export_format, storage_key FROM public.whiteboard_exports WHERE id = %s::UUID AND whiteboard_id = %s::UUID AND school_id = %s::UUID LIMIT 1;",
        (export_id, whiteboard_id, school_id),
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Export not found")
    fmt = rows[0]["export_format"].upper()
    data = _read_bytes_object(rows[0]["storage_key"])
    if data is None:
        raise HTTPException(status_code=404, detail="Export file not available")
    mime = "application/pdf" if fmt == "PDF" else ("image/jpeg" if fmt in ("JPEG", "JPG") else "image/png")
    ext = "pdf" if fmt == "PDF" else ("jpg" if fmt in ("JPEG", "JPG") else "png")
    return Response(
        content=data,
        media_type=mime,
        headers={"Content-Disposition": f'attachment; filename="whiteboard_export.{ext}"'},
    )
