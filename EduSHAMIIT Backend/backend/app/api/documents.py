import time as _sys_time
_SUPABASE_STORAGE_DISABLED_UNTIL = 0.0
"""
Enterprise Documents Management System API for EduSHAMIIT ERP.
Provides full end-to-end capabilities:
1. Institute-wide Centralized Document Repository & Personal Vault
2. Hierarchical Folder Management with Subfolders & Circular Reference Prevention
3. Real Database-Driven KPI Analytics (Total Documents, Storage Usage, Shared, Approvals, Expirations)
4. Multi-Tenant Role-Based Access Control (RBAC) & School Isolation
5. Comprehensive Document Sharing (Users, Roles, Departments, Classes, Public)
6. Immutable Version Control & Historical Restoration
7. Document Approval Lifecycle (Draft -> Pending -> Approved -> Rejected -> Published)
8. Document Requests & Fulfillment
9. Compliance Expiry Tracking & Automated Reminders
10. Secure File Streaming, Preview, and In-Memory ZIP Bulk Downloads
11. Full-Text Search, Filtering (Types, Departments, Users), Sorting & Pagination
12. Append-Only Audit Logging & Activity Timelines
13. Backward-compatible integration with Shami AI (/save-ai) and existing mobile/web callers
"""

import os
import io
import json
import uuid
import base64
import hashlib
import mimetypes
import zipfile
import logging
import asyncio
import urllib.parse
from datetime import datetime, date, time, timedelta
from typing import Optional, List, Dict, Any, Union, Tuple

import httpx
import psycopg2
from psycopg2.extras import RealDictCursor
from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status, UploadFile, File, Form, WebSocket, WebSocketDisconnect
from fastapi.responses import StreamingResponse, RedirectResponse, JSONResponse, FileResponse, HTMLResponse
from pydantic import BaseModel, Field

from app.config import settings
from app.middleware.auth import get_current_user, get_current_user_optional, require_school_id, get_public_supabase_url
from app.services.supabase_client import get_supabase
from app.api.collab_editor import collab_hub, render_collaborative_editor_html, render_access_denied_html, save_sheets_to_disk, resolve_local_file_path

logger = logging.getLogger(__name__)

router = APIRouter()

ALLOWED_CATEGORIES = {
    "academic",
    "administration",
    "student_records",
    "finance",
    "library",
    "transport",
    "hostel",
    "policies",
    "general",
    "ai_generated",
    "my_uploads",
    "teacher_shared",
    "chat_shared",
    "school_notice",
    "others",
}

STORAGE_LOCAL_BASE = os.path.join(os.getcwd(), "assets", "documents")
os.makedirs(STORAGE_LOCAL_BASE, exist_ok=True)


# ============================================================================
# DATABASE EXECUTION & UTILITIES
# ============================================================================

async def exec_sql(sql: str, params: tuple = (), fetch: bool = True) -> List[Dict[str, Any]]:
    """Execute parameterized SQL query asynchronously via psycopg2."""
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
    """Format dates, datetimes, and UUIDs for JSON serialization."""
    if isinstance(val, (datetime, date, time)):
        return val.isoformat()
    if isinstance(val, uuid.UUID):
        return str(val)
    if isinstance(val, dict):
        return {k: _serialize_datetime(v) for k, v in val.items()}
    if isinstance(val, list):
        return [_serialize_datetime(item) for item in val]
    return val


def _detect_file_type(filename: str, mime_type: Optional[str] = None) -> str:
    """Derive standard file type badge label (PDF, DOCX, XLSX, JPG, PPTX, etc.)."""
    ext = filename.rsplit(".", 1)[-1].upper() if "." in filename else ""
    if ext in ("PDF", "DOC", "DOCX", "XLS", "XLSX", "PPT", "PPTX", "TXT", "CSV", "JPG", "JPEG", "PNG", "ZIP"):
        return ext
    if mime_type:
        if "pdf" in mime_type: return "PDF"
        if "word" in mime_type or "officedocument.word" in mime_type: return "DOCX"
        if "sheet" in mime_type or "excel" in mime_type: return "XLSX"
        if "presentation" in mime_type or "powerpoint" in mime_type: return "PPTX"
        if "image" in mime_type: return "JPG"
        if "text" in mime_type: return "TXT"
        if "zip" in mime_type: return "ZIP"
    return ext or "FILE"


async def log_document_activity(
    school_id: str,
    document_id: Optional[str],
    user_id: Optional[str],
    action: str,
    action_details: Optional[dict] = None,
    folder_id: Optional[str] = None,
    ip_address: Optional[str] = None,
):
    """Record an immutable audit log entry for document actions."""
    try:
        sql = """
            INSERT INTO document_activity_logs (school_id, document_id, folder_id, user_id, action, action_details, ip_address)
            VALUES (%s, %s, %s, %s, %s, %s, %s);
        """
        await exec_sql(sql, (
            school_id,
            document_id,
            folder_id,
            user_id,
            action,
            json.dumps(action_details or {}, default=str),
            ip_address or "127.0.0.1",
        ), fetch=False)
    except Exception as e:
        logger.warning(f"Failed to record document activity log: {e}")


# ============================================================================
# KPI & REPOSITORY ANALYTICS
# ============================================================================

@router.get("/stats")
async def get_document_stats(
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """
    Return real database-calculated metrics for the dashboard KPI cards.
    - Total Documents
    - Shared Documents
    - Storage Used (bytes and formatted label)
    - Storage Quota (default 5 GB)
    - Recent Uploads count (last 7 days and today)
    - Pending Approvals count
    - Expiring Soon count (< 30 days)
    """
    user_id = user["id"]

    # 1. Total active non-deleted documents in school
    total_sql = """
        SELECT COUNT(*) AS total_count, COALESCE(SUM(file_size), 0) AS total_bytes
        FROM user_documents
        WHERE school_id = %s AND is_deleted = FALSE;
    """
    total_res = await exec_sql(total_sql, (school_id,))
    total_docs = total_res[0]["total_count"] if total_res else 0
    total_bytes = int(total_res[0]["total_bytes"]) if total_res else 0

    # 2. Shared documents with this user
    shared_sql = """
        SELECT COUNT(DISTINCT d.id) AS shared_count
        FROM user_documents d
        LEFT JOIN document_shares s ON s.document_id = d.id
        WHERE d.school_id = %s AND d.is_deleted = FALSE
          AND (s.target_id = %s OR d.shared_with_id = %s::uuid OR s.target_id = %s);
    """
    shared_res = await exec_sql(shared_sql, (school_id, user_id, user_id, user.get("role", "")))
    shared_count = shared_res[0]["shared_count"] if shared_res else 0

    # 3. Recent uploads in last 7 days and today
    recent_sql = """
        SELECT 
            COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '7 days') AS recent_7d,
            COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE) AS recent_today
        FROM user_documents
        WHERE school_id = %s AND is_deleted = FALSE;
    """
    recent_res = await exec_sql(recent_sql, (school_id,))
    recent_7d = recent_res[0]["recent_7d"] if recent_res else 0
    recent_today = recent_res[0]["recent_today"] if recent_res else 0

    # 4. Pending approvals
    pending_sql = """
        SELECT COUNT(*) AS pending_count
        FROM user_documents
        WHERE school_id = %s AND is_deleted = FALSE AND approval_status = 'Pending';
    """
    pending_res = await exec_sql(pending_sql, (school_id,))
    pending_count = pending_res[0]["pending_count"] if pending_res else 0

    # 5. Expiring soon (< 30 days)
    expiring_sql = """
        SELECT COUNT(*) AS expiring_count
        FROM user_documents
        WHERE school_id = %s AND is_deleted = FALSE 
          AND expiry_date IS NOT NULL 
          AND expiry_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + INTERVAL '30 days');
    """
    expiring_res = await exec_sql(expiring_sql, (school_id,))
    expiring_count = expiring_res[0]["expiring_count"] if expiring_res else 0

    # Storage labels
    quota_bytes = 5 * 1024 * 1024 * 1024 # 5 GB
    pct_used = min(100, max(1, round((total_bytes / quota_bytes) * 100))) if quota_bytes > 0 else 0

    if total_bytes < 1024 * 1024:
        storage_label = f"{round(total_bytes / 1024, 1)} KB"
    elif total_bytes < 1024 * 1024 * 1024:
        storage_label = f"{round(total_bytes / (1024 * 1024), 1)} MB"
    else:
        storage_label = f"{round(total_bytes / (1024 * 1024 * 1024), 2)} GB"

    return {
        "success": True,
        "school_id": school_id,
        "data": {
            "total_documents": total_docs,
            "shared_documents": shared_count,
            "storage_used_bytes": total_bytes,
            "storage_used_label": storage_label,
            "storage_quota_bytes": quota_bytes,
            "storage_quota_label": "5 GB",
            "storage_percentage": pct_used,
            "recent_uploads": recent_7d,
            "recent_today": recent_today,
            "pending_approvals": pending_count,
            "expiring_soon": expiring_count,
        }
    }


# ============================================================================
# FOLDERS MANAGEMENT & HIERARCHY
# ============================================================================

class FolderCreateRequest(BaseModel):
    name: str
    description: Optional[str] = None
    parent_id: Optional[str] = None
    category: Optional[str] = "General"
    color: Optional[str] = "#2563EB"
    icon: Optional[str] = "folder"


class FolderUpdateRequest(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    parent_id: Optional[str] = None
    color: Optional[str] = None
    icon: Optional[str] = None


@router.get("/folders")
async def list_folders(
    tab: Optional[str] = Query(None, description="Optional tab context e.g. my_documents"),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """
    Return all active folders for the school with document counts and hierarchical structure.
    Optionally scoped by tab (e.g. my_documents).
    """
    user_id = user["id"]
    if tab == "my_documents":
        doc_count_filter = "AND d.owner_id = %s::uuid"
        params = (user_id, school_id)
    else:
        doc_count_filter = ""
        params = (school_id,)

    sql = f"""
        SELECT 
            f.id, f.parent_id, f.name, f.description, f.category, f.color, f.icon, 
            f.is_system, f.created_at, f.updated_at,
            COUNT(d.id) FILTER (WHERE d.is_deleted = FALSE {doc_count_filter}) AS document_count
        FROM document_folders f
        LEFT JOIN user_documents d ON d.folder_id = f.id
        WHERE f.school_id = %s AND f.is_deleted = FALSE
        GROUP BY f.id
        ORDER BY f.is_system DESC, f.name ASC;
    """
    rows = await exec_sql(sql, params)
    folder_map = {}
    for r in rows:
        r_clean = _serialize_datetime(r)
        r_clean["document_count"] = int(r_clean.get("document_count") or 0)
        r_clean["children"] = []
        folder_map[r_clean["id"]] = r_clean

    root_folders = []
    for f in folder_map.values():
        p_id = f.get("parent_id")
        if p_id and p_id in folder_map:
            folder_map[p_id]["children"].append(f)
        else:
            root_folders.append(f)

    # Compute rolled-up document count for parent folders
    def _rollup_counts(folder):
        count = folder["document_count"]
        for child in folder["children"]:
            count += _rollup_counts(child)
        folder["total_tree_count"] = count
        return count

    for rf in root_folders:
        _rollup_counts(rf)

    return {
        "success": True,
        "school_id": school_id,
        "data": {
            "folders": root_folders,
            "all_folders_flat": list(folder_map.values()),
        }
    }


@router.post("/folders")
async def create_folder(
    body: FolderCreateRequest,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Create a new folder or nested subfolder."""
    name = body.name.strip()
    if not name:
        raise HTTPException(status_code=400, detail="Folder name is required")

    parent_id = body.parent_id
    if parent_id in ("", "null", "None"):
        parent_id = None
    elif parent_id:
        try:
            uuid.UUID(str(parent_id))
        except (ValueError, TypeError):
            parent_id = None

    # Prevent duplicate folder name under same parent in same school
    if parent_id:
        check_sql = """
            SELECT id FROM document_folders
            WHERE school_id = %s AND is_deleted = FALSE AND LOWER(name) = LOWER(%s)
              AND parent_id = %s;
        """
        exists = await exec_sql(check_sql, (school_id, name, parent_id))
    else:
        check_sql = """
            SELECT id FROM document_folders
            WHERE school_id = %s AND is_deleted = FALSE AND LOWER(name) = LOWER(%s)
              AND parent_id IS NULL;
        """
        exists = await exec_sql(check_sql, (school_id, name))

    if exists:
        raise HTTPException(status_code=400, detail=f"A folder named '{name}' already exists in this location.")

    owner_id = user.get("id")
    try:
        if owner_id:
            uuid.UUID(str(owner_id))
    except (ValueError, TypeError):
        owner_id = None

    folder_id = str(uuid.uuid4())
    insert_sql = """
        INSERT INTO document_folders (id, school_id, parent_id, name, description, category, color, icon, owner_id)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        RETURNING *;
    """
    res = await exec_sql(insert_sql, (
        folder_id,
        school_id,
        parent_id,
        name,
        body.description or "",
        body.category or "General",
        body.color or "#2563EB",
        body.icon or "folder",
        owner_id,
    ))

    await log_document_activity(
        school_id=school_id,
        document_id=None,
        folder_id=folder_id,
        user_id=owner_id,
        action="folder_create",
        action_details={"folder_name": name, "parent_id": parent_id},
    )

    created = _serialize_datetime(res[0]) if res else {}
    return {"success": True, "message": "Folder created successfully", "data": {"folder": created}}


@router.patch("/folders/{folder_id}")
async def update_folder(
    folder_id: str,
    body: FolderUpdateRequest,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Update folder metadata, rename or move."""
    # Check folder exists
    f_res = await exec_sql("SELECT * FROM document_folders WHERE id = %s AND school_id = %s AND is_deleted = FALSE;", (folder_id, school_id))
    if not f_res:
        raise HTTPException(status_code=404, detail="Folder not found")

    folder = f_res[0]

    # Validate circular reference if parent_id is modified
    if body.parent_id is not None:
        if body.parent_id == folder_id:
            raise HTTPException(status_code=400, detail="A folder cannot be its own parent")

        # Recursive check to verify new parent is not a descendant of folder_id
        desc_sql = """
            WITH RECURSIVE subordinates AS (
                SELECT id, parent_id FROM document_folders WHERE parent_id = %s AND is_deleted = FALSE
                UNION ALL
                SELECT f.id, f.parent_id FROM document_folders f
                JOIN subordinates s ON f.parent_id = s.id
                WHERE f.is_deleted = FALSE
            )
            SELECT id FROM subordinates WHERE id = %s;
        """
        is_desc = await exec_sql(desc_sql, (folder_id, body.parent_id))
        if is_desc:
            raise HTTPException(status_code=400, detail="Cannot move a folder into one of its own subfolders (circular hierarchy).")

    new_name = body.name.strip() if body.name is not None else folder["name"]
    new_desc = body.description if body.description is not None else folder["description"]
    new_parent = body.parent_id if body.parent_id is not None else folder["parent_id"]
    new_color = body.color if body.color is not None else folder["color"]
    new_icon = body.icon if body.icon is not None else folder["icon"]

    update_sql = """
        UPDATE document_folders
        SET name = %s, description = %s, parent_id = %s, color = %s, icon = %s, updated_at = NOW()
        WHERE id = %s AND school_id = %s
        RETURNING *;
    """
    up_res = await exec_sql(update_sql, (new_name, new_desc, new_parent, new_color, new_icon, folder_id, school_id))

    await log_document_activity(
        school_id=school_id,
        document_id=None,
        folder_id=folder_id,
        user_id=user["id"],
        action="folder_update",
        action_details={"new_name": new_name, "new_parent": new_parent},
    )

    return {"success": True, "message": "Folder updated successfully", "data": {"folder": _serialize_datetime(up_res[0])}}


@router.delete("/folders/{folder_id}")
async def delete_folder(
    folder_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Soft-delete a folder. Moves child documents to the parent folder so no files are orphaned."""
    f_res = await exec_sql("SELECT * FROM document_folders WHERE id = %s AND school_id = %s AND is_deleted = FALSE;", (folder_id, school_id))
    if not f_res:
        raise HTTPException(status_code=404, detail="Folder not found")

    folder = f_res[0]
    parent_id = folder["parent_id"]

    # Reassign child documents to parent folder
    await exec_sql("UPDATE user_documents SET folder_id = %s WHERE folder_id = %s AND school_id = %s;", (parent_id, folder_id, school_id), fetch=False)
    # Reassign child subfolders to parent folder
    await exec_sql("UPDATE document_folders SET parent_id = %s WHERE parent_id = %s AND school_id = %s;", (parent_id, folder_id, school_id), fetch=False)
    # Mark folder deleted
    await exec_sql("UPDATE document_folders SET is_deleted = TRUE, deleted_at = NOW() WHERE id = %s AND school_id = %s;", (folder_id, school_id), fetch=False)

    await log_document_activity(
        school_id=school_id,
        document_id=None,
        folder_id=folder_id,
        user_id=user["id"],
        action="folder_delete",
        action_details={"folder_name": folder["name"]},
    )

    return {"success": True, "message": f"Folder '{folder['name']}' deleted. Contents moved to parent directory."}



# ============================================================================
# USER SEARCH FOR SHARING
# ============================================================================

@router.get("/users/search")
async def search_document_users(
    q: str = Query("", description="Search user by name or email"),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Search registered users in the school for document sharing."""
    search_term = f"%{q.strip().lower()}%" if q.strip() else "%"
    sql = """
        SELECT id, full_name, email, role, avatar_url, phone
        FROM profiles
        WHERE school_id = %s
          AND (LOWER(full_name) LIKE %s OR LOWER(COALESCE(email, '')) LIKE %s)
        ORDER BY full_name ASC
        LIMIT 30;
    """
    rows = await exec_sql(sql, (school_id, search_term, search_term))
    return {
        "success": True,
        "data": {
            "users": [
                {
                    "id": str(r["id"]),
                    "full_name": r.get("full_name") or "User",
                    "email": r.get("email") or "",
                    "role": r.get("role") or "User",
                    "avatar_url": r.get("avatar_url"),
                    "phone": r.get("phone") or "",
                }
                for r in rows
            ]
        }
    }


@router.get("/{doc_id}/live-editor")
async def get_document_live_editor_url(
    doc_id: str,
    request: Request,
    service: str = Query("google", description="google or office"),
):
    """
    Generate a live collaborative viewing/editing link for Word (.docx) and Excel (.xlsx/.csv) files.
    Returns our self-hosted, enterprise collaborative editor for simultaneous multi-user editing.
    """
    user = await get_current_user_optional(request)
    school_id = str(user.get("school_id") or "11111111-1111-1111-1111-111111111111") if user else "11111111-1111-1111-1111-111111111111"
    d_res = await exec_sql("SELECT * FROM user_documents WHERE id = %s;", (doc_id,))
    if not d_res:
        raise HTTPException(status_code=404, detail="Document not found")
    doc = d_res[0]
    
    file_type = (doc.get("file_type") or "").upper()
    file_name = doc.get("file_name") or doc.get("title") or "document"
    
    # Native self-hosted collaborative editor path
    auth_token = request.query_params.get("token") or request.query_params.get("access_token")
    if not auth_token:
        ah = request.headers.get("Authorization") or ""
        if ah.startswith("Bearer "):
            auth_token = ah[7:].strip()
    if not auth_token:
        auth_token = request.cookies.get("access_token") or request.cookies.get("auth_token")

    editor_path = f"/api/documents/{doc_id}/editor"
    if auth_token:
        editor_path += f"?token={auth_token}"

    public_url = doc.get("file_url") or ""
    if not public_url.startswith("http"):
        public_url = f"/api/documents/{doc_id}/preview"
        
    encoded_url = urllib.parse.quote(public_url, safe="")
    
    if "XLS" in file_type or "CSV" in file_type or "SHEET" in file_type:
        google_url = f"https://docs.google.com/viewer?url={encoded_url}&embedded=true"
        office_url = f"https://view.officeapps.live.com/op/view.aspx?src={encoded_url}"
        direct_edit_url = editor_path
    else:
        google_url = f"https://docs.google.com/viewer?url={encoded_url}&embedded=true"
        office_url = f"https://view.officeapps.live.com/op/view.aspx?src={encoded_url}"
        direct_edit_url = editor_path
        
    return {
        "success": True,
        "data": {
            "live_url": editor_path,
            "editor_url": editor_path,
            "collaborative_url": editor_path,
            "is_native_editor": True,
            "google_viewer_url": google_url,
            "office_viewer_url": office_url,
            "collaborative_create_url": direct_edit_url,
            "file_type": file_type,
            "file_name": file_name,
        }
    }


# ============================================================================
# COLLABORATIVE LIVE EDITOR & MULTI-USER REAL-TIME ENGINE
# ============================================================================

async def _save_room_to_database(room, user: dict) -> dict:
    """Commit live room state to physical file and record version in PostgreSQL."""
    doc_id = room.doc_id
    school_id = room.school_id
    doc = room.doc_metadata
    storage_path = doc.get("storage_path")
    file_path = resolve_local_file_path(storage_path)
    
    ft = (doc.get("file_type") or "").upper()
    ext = "pptx" if "PPT" in ft else ("docx" if "DOC" in ft else ("csv" if "CSV" in ft else "xlsx"))
    if not file_path:
        storage_path = f"assets/documents/{school_id}/{doc_id}.{ext}"
        file_path = os.path.join(os.getcwd(), storage_path)
        os.makedirs(os.path.dirname(file_path), exist_ok=True)

    file_size, checksum = save_sheets_to_disk(file_path, ft or "DOCX", room.data, doc.get("title") or "Document")

    # Next version integer (document_versions.version_number is integer)
    curr_ver = doc.get("version_number") or 1
    if isinstance(curr_ver, str):
        try:
            curr_ver = int(curr_ver.lstrip("vV").split(".")[0])
        except Exception:
            curr_ver = 1
    new_ver = int(curr_ver) + 1
    version_display = f"v{new_ver}.0"

    version_id = str(uuid.uuid4())
    safe_name = doc.get("file_name") or f"{doc.get('title')}.{ext}"
    raw_user_id = user.get("id")
    try:
        uuid.UUID(str(raw_user_id))
        user_id = str(raw_user_id)
    except Exception:
        user_id = str(doc.get("owner_id") or "5198c4b0-f1cb-45db-9649-41688d0438ba")
    user_name = user.get("full_name") or user.get("name") or "User"

    # Insert into document_versions
    v_sql = """
        INSERT INTO document_versions (
            id, document_id, version_number, file_url, file_name, file_size, mime_type, storage_path, checksum, change_summary, uploaded_by_id
        ) VALUES (%s, %s::uuid, %s, %s, %s, %s, %s, %s, %s, %s, %s::uuid)
        RETURNING *;
    """
    await exec_sql(v_sql, (
        version_id, doc_id, new_ver, f"/api/documents/{doc_id}/download", safe_name, file_size,
        doc.get("mime_type") or "application/octet-stream", storage_path, checksum,
        f"Collaborative edit saved by {user_name}", user_id
    ), fetch=False)

    # Update user_documents
    await exec_sql("""
        UPDATE user_documents
        SET version_number = %s, current_version_id = %s::uuid, file_size = %s,
            updated_at = NOW(), updated_by = %s
        WHERE id = %s;
    """, (new_ver, version_id, file_size, user_id, doc_id), fetch=False)

    await log_document_activity(
        school_id=school_id,
        document_id=doc_id,
        user_id=user_id,
        action="edit_collaborative",
        action_details={"version": new_ver, "saved_by": user_name},
    )

    room.doc_metadata["version_number"] = new_ver
    room.dirty = False
    return {"success": True, "version_number": version_display, "version": new_ver, "file_size": file_size}


async def resolve_document_user_and_access(
    doc_id: str,
    request: Optional[Request] = None,
    token: Optional[str] = None,
    allow_public_share: bool = True
) -> Tuple[Optional[dict], Optional[dict], bool, str, str]:
    """
    Authoritative access resolution for collaborative document viewing and editing.
    Returns: (user, doc, can_edit, access_level, denial_reason)
    access_level is one of:
      - 'owner', 'admin', 'editor' (can_edit = True)
      - 'viewer' (can_edit = False)
      - 'unauthorized', 'forbidden_school', 'forbidden_no_access', 'not_found' (can_edit = False, access denied)
    """
    user = None
    if request:
        try:
            if hasattr(request, "app") and get_current_user in getattr(request.app, "dependency_overrides", {}):
                override = request.app.dependency_overrides[get_current_user]
                user = override() if callable(override) else override
            else:
                user = await get_current_user_optional(request)
        except Exception:
            user = None

    extracted_token = token
    if not extracted_token and request:
        extracted_token = request.query_params.get("token") or request.query_params.get("access_token")
        if not extracted_token:
            auth_header = request.headers.get("Authorization") or ""
            if auth_header.startswith("Bearer "):
                extracted_token = auth_header[7:].strip()
        if not extracted_token:
            extracted_token = request.cookies.get("access_token") or request.cookies.get("auth_token")

    if not user and extracted_token:
        try:
            payload = None
            try:
                from app.middleware.jwt_cache import get_cached_payload
                payload = await get_cached_payload(extracted_token)
            except Exception:
                payload = None

            if not payload:
                try:
                    from jose import jwt
                except ImportError:
                    import jwt
                jwt_secret = settings.SUPABASE_JWT_SECRET or settings.JWT_SECRET
                payload = jwt.decode(
                    extracted_token,
                    jwt_secret,
                    algorithms=["HS256"],
                    options={"verify_aud": False}
                )
            if payload:
                user_id = str(payload.get("sub") or payload.get("user_id"))
                p_rows = await exec_sql("SELECT id, school_id, role, full_name, email FROM profiles WHERE id = %s;", (user_id,))
                if p_rows:
                    user = dict(p_rows[0])
                    user["id"] = str(user["id"])
                else:
                    user = {
                        "id": user_id,
                        "full_name": payload.get("user_metadata", {}).get("full_name") or payload.get("name") or "Collaborator",
                        "role": payload.get("role") or "User",
                        "school_id": payload.get("school_id") or "11111111-1111-1111-1111-111111111111",
                        "email": payload.get("email") or ""
                    }
        except Exception as e:
            logger.debug(f"Collab token decode: {e}")

    # Fetch document
    d_res = await exec_sql("SELECT * FROM user_documents WHERE id = %s AND (is_deleted IS NULL OR is_deleted = false);", (doc_id,))
    if not d_res:
        return (user, None, False, "not_found", "The requested document was not found or has been moved to trash.")
    doc = dict(d_res[0])
    doc_school_id = str(doc.get("school_id") or "")

    # Unauthenticated handling
    if not user:
        if allow_public_share and extracted_token:
            share_res = await exec_sql(
                "SELECT * FROM document_shares WHERE document_id = %s AND access_token = %s AND (expiry_date IS NULL OR expiry_date > NOW());",
                (doc_id, extracted_token)
            )
            if share_res:
                share = share_res[0]
                perm = (share.get("permission_level") or "Viewer").lower()
                is_ed = perm in ("editor", "manager", "edit", "write")
                guest_user = {
                    "id": f"guest_{str(uuid.uuid4())[:8]}",
                    "full_name": "Shared Guest User",
                    "role": "Guest",
                    "school_id": doc_school_id
                }
                return (guest_user, doc, is_ed, "editor" if is_ed else "viewer", "")
        return (None, doc, False, "unauthorized", "You must sign in to your EduSHAMIIT institute account to view or edit this document.")

    user_school_id = str(user.get("school_id") or "")
    user_role = (user.get("role") or "").lower()
    user_id = str(user.get("id") or "")

    # Multi-tenant school isolation
    if user_role not in ("superadmin", "super_admin"):
        if doc_school_id and user_school_id and doc_school_id != user_school_id:
            return (user, doc, False, "forbidden_school", "This document belongs to another educational institution. Cross-institute access is prohibited under EduSHAMIIT Data Isolation protocols.")

    # Owner check
    owner_id = str(doc.get("owner_id") or "")
    created_by = str(doc.get("created_by") or "")
    if user_id in (owner_id, created_by):
        return (user, doc, True, "owner", "")

    # School Administrator check
    if user_role in ("superadmin", "super_admin", "principal", "school_admin", "admin"):
        return (user, doc, True, "admin", "")

    # Explicit shares check
    user_dept = user.get("department") or ""
    user_email = user.get("email") or ""
    shares_sql = """
        SELECT * FROM document_shares 
        WHERE document_id = %s 
          AND (expiry_date IS NULL OR expiry_date > NOW())
          AND (
            (share_type = 'user' AND (target_id = %s OR target_id = %s))
            OR (share_type = 'role' AND LOWER(target_id) = LOWER(%s))
            OR (share_type = 'department' AND target_id = %s AND %s != '')
            OR (share_type = 'public')
          )
        ORDER BY CASE 
            WHEN LOWER(permission_level) IN ('manager', 'editor', 'edit', 'write') THEN 1 
            ELSE 2 
        END ASC;
    """
    shares_res = await exec_sql(shares_sql, (doc_id, user_id, user_email, user_role, user_dept, user_dept))
    if shares_res:
        highest_share = shares_res[0]
        perm_level = (highest_share.get("permission_level") or "Viewer").lower()
        if perm_level in ("editor", "manager", "edit", "write"):
            return (user, doc, True, "editor", "")
        else:
            return (user, doc, False, "viewer", "")

    # Legacy direct share in user_documents
    shared_with = str(doc.get("shared_with_id") or "")
    if shared_with and shared_with == user_id:
        acc_type = (doc.get("access_type") or "").lower()
        if acc_type in ("edit", "editor", "write"):
            return (user, doc, True, "editor", "")
        return (user, doc, False, "viewer", "")

    # Institute-wide / public documents in user_documents
    access_type = (doc.get("access_type") or "").lower()
    if access_type in ("public", "institute", "school"):
        return (user, doc, False, "viewer", "")

    return (user, doc, False, "forbidden_no_access", "You do not have permission to access this document. Please request access from the document owner.")


@router.get("/{doc_id}/editor", response_class=HTMLResponse)
async def open_collaborative_editor(
    doc_id: str,
    request: Request,
    token: Optional[str] = Query(None)
):
    """
    Interactive in-browser collaborative spreadsheet, document, and presentation editor.
    Enforces strict Institute Isolation, Role-Based Access Control, and View-Only vs Edit permissions.
    """
    user, doc, can_edit, access_level, denial_reason = await resolve_document_user_and_access(
        doc_id=doc_id, request=request, token=token
    )

    if access_level in ("unauthorized", "forbidden_school", "forbidden_no_access"):
        status_code = 401 if access_level == "unauthorized" else 403
        title = "Authentication Required" if access_level == "unauthorized" else "Access Restricted"
        return HTMLResponse(content=render_access_denied_html(title, denial_reason, status_code), status_code=status_code)

    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")

    school_id = str(doc.get("school_id") or user.get("school_id") or "11111111-1111-1111-1111-111111111111")
    room = await collab_hub.get_or_create_room(doc_id, school_id, doc)

    # Log viewing activity
    await log_document_activity(
        school_id=school_id,
        document_id=doc_id,
        user_id=user["id"],
        action="open_editor",
        action_details={"title": doc["title"], "access_level": access_level, "can_edit": can_edit},
    )

    html = render_collaborative_editor_html(
        doc=doc,
        initial_data=room.data,
        current_user=user,
        token=token or "",
        can_edit=can_edit,
        access_level=access_level
    )
    return HTMLResponse(content=html, status_code=200)


@router.get("/{doc_id}/collab/data")
async def get_collab_data(doc_id: str, request: Request):
    """Fetch current structured sheet data, version, and active collaborators."""
    user, doc, can_edit, access_level, denial_reason = await resolve_document_user_and_access(doc_id=doc_id, request=request)
    if access_level in ("unauthorized", "forbidden_school", "forbidden_no_access"):
        raise HTTPException(status_code=401 if access_level == "unauthorized" else 403, detail=denial_reason)
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")

    school_id = str(doc.get("school_id") or "11111111-1111-1111-1111-111111111111")
    room = await collab_hub.get_or_create_room(doc_id, school_id, doc)
    return {
        "success": True,
        "doc": {
            "id": doc_id,
            "title": doc.get("title"),
            "file_name": doc.get("file_name"),
            "file_type": doc.get("file_type"),
            "version_number": room.doc_metadata.get("version_number") or doc.get("version_number"),
            "can_edit": can_edit,
            "access_level": access_level
        },
        "data": room.data,
        "version": room.version,
        "users": list(room.users.values())
    }


@router.post("/{doc_id}/collab/edit")
async def post_collab_edit(doc_id: str, payload: dict, request: Request):
    """Apply a live edit (spreadsheet cell, word content, or presentation slide), increment version, and broadcast."""
    user, doc, can_edit, access_level, denial_reason = await resolve_document_user_and_access(doc_id=doc_id, request=request)
    if access_level in ("unauthorized", "forbidden_school", "forbidden_no_access"):
        raise HTTPException(status_code=401 if access_level == "unauthorized" else 403, detail=denial_reason)
    if not can_edit:
        raise HTTPException(
            status_code=403,
            detail="Permission Denied: You have view-only access to this document. Editing is disabled."
        )
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")

    school_id = str(doc.get("school_id") or "11111111-1111-1111-1111-111111111111")
    room = await collab_hub.get_or_create_room(doc_id, school_id, doc)

    edit_type = payload.get("type") or room.data.get("type")
    if edit_type == "document" or "content" in payload:
        content = payload.get("content", "")
        event = room.apply_content_edit(content, user)
    elif edit_type == "presentation" or "action" in payload or "slides" in payload:
        action = payload.get("action", "update_slide")
        event = room.apply_presentation_edit(action, payload, user)
    else:
        sheet_idx = int(payload.get("sheet", 0))
        row = int(payload.get("row", 0))
        col = int(payload.get("col", 0))
        val = str(payload.get("value", ""))
        event = room.apply_cell_edit(sheet_idx, row, col, val, user)

    await room.broadcast(event)
    return {"success": True, "version": room.version, "event": event}


@router.post("/{doc_id}/collab/save")
async def post_collab_save(doc_id: str, request: Request, payload: Optional[dict] = None):
    """Commit document changes to disk and database version history."""
    user, doc, can_edit, access_level, denial_reason = await resolve_document_user_and_access(doc_id=doc_id, request=request)
    if access_level in ("unauthorized", "forbidden_school", "forbidden_no_access"):
        raise HTTPException(status_code=401 if access_level == "unauthorized" else 403, detail=denial_reason)
    if not can_edit:
        raise HTTPException(
            status_code=403,
            detail="Permission Denied: You have view-only access to this document. Saving versions is disabled."
        )
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")

    school_id = str(doc.get("school_id") or "11111111-1111-1111-1111-111111111111")
    room = await collab_hub.get_or_create_room(doc_id, school_id, doc)
    
    if payload:
        if payload.get("sheets"):
            room.data["sheets"] = payload["sheets"]
        if payload.get("content") is not None:
            room.data["content"] = payload["content"]
        if payload.get("slides") is not None:
            room.data["slides"] = payload["slides"]
        
    res = await _save_room_to_database(room, user)
    await room.broadcast({
        "type": "saved",
        "version": res["version_number"],
        "timestamp": datetime.utcnow().strftime("%H:%M:%S"),
        "saved_by": user.get("full_name") or user.get("name") or "User"
    })
    return res


@router.get("/{doc_id}/collab/poll")
async def poll_collab_events(doc_id: str, since_version: int = Query(0)):
    """HTTP polling fallback for real-time events and presence updates."""
    room = collab_hub.get_room(doc_id)
    if not room:
        return {"success": True, "events": [], "version": 0, "users": []}
    new_events = [e for e in room.events_history if e.get("_version", 0) > since_version]
    return {
        "success": True,
        "events": new_events,
        "version": room.version,
        "users": list(room.users.values())
    }


@router.get("/{doc_id}/collab/collaborators")
async def get_collab_collaborators(doc_id: str):
    """List currently active collaborators editing this document."""
    room = collab_hub.get_room(doc_id)
    users = list(room.users.values()) if room else []
    return {"success": True, "count": len(users), "collaborators": users}


async def handle_collab_websocket(websocket: WebSocket, doc_id: str):
    """Shared WebSocket session handler for live multi-user editing with strict RBAC enforcement."""
    await websocket.accept()
    token = websocket.query_params.get("token")
    client_id = websocket.query_params.get("client_id")
    client_name = websocket.query_params.get("name")

    user, doc, can_edit, access_level, denial_reason = await resolve_document_user_and_access(doc_id=doc_id, token=token)
    if access_level in ("unauthorized", "forbidden_school", "forbidden_no_access") or not doc:
        await websocket.send_json({
            "type": "error",
            "error": "ACCESS_DENIED",
            "message": denial_reason or "You do not have access to this document."
        })
        await websocket.close(code=4403)
        return

    school_id = str(doc.get("school_id") or "11111111-1111-1111-1111-111111111111")
    room = await collab_hub.get_or_create_room(doc_id, school_id, doc)

    conn_id = str(uuid.uuid4())[:8]
    user_info = await room.add_connection(conn_id, user, websocket)
    user_info["can_edit"] = can_edit
    user_info["access_level"] = access_level

    # Send initial room state and existing active participants to the client
    await websocket.send_json({
        "type": "init",
        "doc": {
            "id": doc_id,
            "title": doc.get("title"),
            "file_name": doc.get("file_name"),
            "file_type": doc.get("file_type"),
            "version_number": doc.get("version_number"),
            "can_edit": can_edit,
            "access_level": access_level
        },
        "data": room.data,
        "version": room.version,
        "my_user": user_info,
        "users": list(room.users.values())
    })

    try:
        while True:
            msg = await websocket.receive_json()
            mtype = msg.get("type")

            # Check edit permission for mutating message types
            if mtype in ("content_edit", "presentation_edit", "cell_edit", "structure_change", "save") and not can_edit:
                await websocket.send_json({
                    "type": "error",
                    "error": "PERMISSION_DENIED",
                    "message": "Permission Denied: You have view-only access to this document."
                })
                continue

            if mtype == "join":
                client_user = msg.get("user")
                if isinstance(client_user, dict):
                    if client_user.get("id"):
                        user_info["id"] = client_user["id"]
                    if client_user.get("name") or client_user.get("full_name"):
                        user_info["name"] = client_user.get("name") or client_user.get("full_name")
                    if client_user.get("role"):
                        user_info["role"] = client_user["role"]
                await room.broadcast({
                    "type": "user_joined",
                    "user": user_info,
                    "total_users": len(room.users),
                    "users": list(room.users.values())
                })

            elif mtype in ("cursor", "cursor_move"):
                user_info["cursor"] = {
                    "sheet": msg.get("sheet", 0),
                    "row": msg.get("row", 0),
                    "col": msg.get("col", 0),
                    "cursor_pos": msg.get("cursor_pos", 0)
                }
                await room.broadcast({
                    "type": "cursor_update",
                    "conn_id": conn_id,
                    "user": user_info,
                    "cursor": user_info["cursor"]
                }, exclude_conn_id=conn_id)

            elif mtype == "content_edit":
                content = str(msg.get("content", ""))
                event = room.apply_content_edit(content, user_info)
                event["cursor_pos"] = msg.get("cursor_pos")
                event["conn_id"] = conn_id
                event["author_id"] = user_info["id"]
                event["author_name"] = user_info["name"]
                await room.broadcast(event, exclude_conn_id=conn_id)

            elif mtype == "presentation_edit":
                action = msg.get("action", "update_slide")
                params = msg.get("params") or {}
                if "slides" in msg:
                    params["slides"] = msg["slides"]
                if "slide_idx" in msg:
                    params["slide_idx"] = msg["slide_idx"]
                event = room.apply_presentation_edit(action, params, user_info)
                event["conn_id"] = conn_id
                event["author_id"] = user_info["id"]
                event["author_name"] = user_info["name"]
                event["active_slide"] = msg.get("active_slide", 0)
                await room.broadcast(event, exclude_conn_id=conn_id)

            elif mtype == "cell_edit":
                sheet_idx = int(msg.get("sheet", 0))
                row = int(msg.get("row", 0))
                col = int(msg.get("col", 0))
                val = str(msg.get("value", ""))
                event = room.apply_cell_edit(sheet_idx, row, col, val, user_info)
                await room.broadcast(event, exclude_conn_id=conn_id)

            elif mtype == "structure_change":
                change_type = msg.get("change")
                sheet_idx = int(msg.get("sheet", 0))
                params = {"row": msg.get("row")}
                event = room.apply_structure_change(change_type, sheet_idx, params, user_info)
                await room.broadcast(event, exclude_conn_id=conn_id)

            elif mtype == "save":
                res = await _save_room_to_database(room, user)
                await room.broadcast({
                    "type": "saved",
                    "version": res["version_number"],
                    "timestamp": datetime.utcnow().strftime("%H:%M:%S"),
                    "saved_by": user_info["name"],
                    "content": room.data.get("content"),
                    "slides": room.data.get("slides")
                })

            elif mtype == "ping":
                await websocket.send_json({"type": "pong", "ts": time.time()})

    except WebSocketDisconnect:
        await room.remove_connection(conn_id)
    except Exception as e:
        logger.warning(f"WebSocket session error: {e}")
        await room.remove_connection(conn_id)


@router.websocket("/{doc_id}/collab/ws")
@router.websocket("/ws/{doc_id}")
async def websocket_document_collab_endpoint(websocket: WebSocket, doc_id: str):
    """Direct WebSocket endpoint for collaborative document editing."""
    await handle_collab_websocket(websocket, doc_id)


# ============================================================================
# DOCUMENTS LIST, FILTERING & TABS
# ============================================================================

@router.get("")
async def list_documents(
    tab: str = Query("all", description="all, my_documents, shared_with_me, recent, starred, trash"),
    folder_id: Optional[str] = Query(None, description="Filter by folder UUID"),
    category: Optional[str] = Query(None, description="Category filter"),
    file_type: Optional[str] = Query(None, description="File type (PDF, DOCX, XLSX, etc.)"),
    department: Optional[str] = Query(None, description="Department filter"),
    owner_id: Optional[str] = Query(None, description="Filter by document owner/author UUID"),
    search: Optional[str] = Query(None, description="Keyword search"),
    approval_status: Optional[str] = Query(None, description="Approval status filter"),
    sort_by: str = Query("created_at", description="name, created_at, file_size, updated_at"),
    sort_order: str = Query("desc", description="asc or desc"),
    page: int = Query(1, ge=1, description="1-based page number"),
    page_size: int = Query(12, ge=1, le=100, description="Items per page"),
    limit: Optional[int] = None,
    offset: Optional[int] = None,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """
    List documents supporting:
    - 6 standard navigation tabs: All Documents, My Documents, Shared with Me, Recent, Starred, Trash
    - Server-side search & filtering by folder, category, file_type, department, owner_id
    - Multi-column sorting & pagination
    - Seamless backward compatibility for older API callers
    """
    user_id = user["id"]
    if limit is not None:
        page_size = limit
    if offset is not None:
        page = (offset // page_size) + 1

    offset_val = (page - 1) * page_size

    # Validate sort field
    sort_column_map = {
        "name": "d.title",
        "title": "d.title",
        "created_at": "d.created_at",
        "file_size": "d.file_size",
        "updated_at": "d.updated_at",
        "file_type": "d.file_type",
        "category": "d.category",
        "owner": "p.full_name",
        "owner_name": "p.full_name",
    }
    order_col = sort_column_map.get(sort_by.lower(), "d.created_at")
    order_dir = "ASC" if sort_order.lower() == "asc" else "DESC"

    if tab == "recent" and sort_by == "created_at":
        order_col = "COALESCE(rec.last_accessed_at, d.updated_at, d.created_at)"
        order_dir = "DESC"

    where_clauses = ["d.school_id = %s"]
    params = [school_id]

    # Handle Tab scoping
    if tab == "trash":
        where_clauses.append("d.is_deleted = TRUE")
    else:
        where_clauses.append("d.is_deleted = FALSE")

        if tab == "my_documents":
            where_clauses.append("d.owner_id = %s::uuid")
            params.append(user_id)
        elif tab == "shared_with_me":
            where_clauses.append("""
                (d.id IN (
                    SELECT s.document_id FROM document_shares s 
                    WHERE s.school_id = %s AND (s.target_id = %s OR s.target_id = %s)
                ) OR d.shared_with_id = %s::uuid)
            """)
            params.extend([school_id, user_id, user.get("role", ""), user_id])
        elif tab == "starred":
            where_clauses.append("""
                (d.is_starred = TRUE OR d.id IN (
                    SELECT f.document_id FROM document_favorites f WHERE f.user_id = %s::uuid AND f.school_id = %s
                ))
            """)
            params.extend([user_id, school_id])
        elif tab == "recent":
            where_clauses.append("""
                d.id IN (
                    SELECT r.document_id FROM document_recent_activity r WHERE r.user_id = %s::uuid AND r.school_id = %s
                )
            """)
            params.extend([user_id, school_id])

    # Folder filter
    if isinstance(folder_id, str) and folder_id.strip():
        where_clauses.append("d.folder_id = %s::uuid")
        params.append(folder_id.strip())

    # Owner filter
    if isinstance(owner_id, str) and owner_id.strip() and owner_id.strip().lower() != "all":
        where_clauses.append("d.owner_id = %s::uuid")
        params.append(owner_id.strip())

    # Category filter
    if isinstance(category, str) and category.lower() != "all" and category.strip():
        where_clauses.append("LOWER(d.category) = LOWER(%s)")
        params.append(category.strip())

    # File type filter
    if isinstance(file_type, str) and file_type.lower() != "all" and file_type.strip():
        where_clauses.append("UPPER(d.file_type) = UPPER(%s)")
        params.append(file_type.strip())

    # Department filter
    if isinstance(department, str) and department.lower() != "all" and department.strip():
        where_clauses.append("LOWER(d.department) = LOWER(%s)")
        params.append(department.strip())

    # Approval status filter
    if isinstance(approval_status, str) and approval_status.lower() != "all" and approval_status.strip():
        where_clauses.append("LOWER(d.approval_status) = LOWER(%s)")
        params.append(approval_status.strip())

    # Search filter
    if isinstance(search, str) and search.strip():
        search_kw = f"%{search.strip().lower()}%"
        where_clauses.append("""
            (LOWER(d.title) LIKE %s 
             OR LOWER(COALESCE(d.file_name, '')) LIKE %s 
             OR LOWER(COALESCE(d.description, '')) LIKE %s 
             OR %s = ANY(d.tags))
        """)
        params.extend([search_kw, search_kw, search_kw, search.strip().lower()])

    where_sql = " AND ".join(where_clauses)

    # Count total matching rows
    count_sql = f"SELECT COUNT(*) AS total FROM user_documents d WHERE {where_sql};"
    count_res = await exec_sql(count_sql, tuple(params))
    total_records = count_res[0]["total"] if count_res else 0

    # Fetch paginated items with joins
    query_sql = f"""
        SELECT 
            d.id, d.school_id, d.owner_id, d.folder_id, d.title, d.description, d.category,
            d.file_url, d.file_name, d.file_size, d.mime_type, d.storage_path, d.content,
            d.department, d.tags, d.file_type, d.access_type, d.approval_status, d.approval_notes,
            d.version_number, d.is_starred, d.is_archived, d.is_deleted, d.deleted_at,
            d.expiry_date, d.download_count, d.preview_count, d.created_at, d.updated_at,
            f.name AS folder_name,
            p.full_name AS owner_name, p.role AS owner_role, p.avatar_url AS owner_avatar,
            COALESCE(fav.id IS NOT NULL, FALSE) AS user_has_starred,
            (SELECT COUNT(*) FROM document_versions v WHERE v.document_id = d.id) AS versions_count,
            (SELECT COUNT(*) FROM document_shares s WHERE s.document_id = d.id) AS shares_count,
            sh.permission_level AS share_permission_level,
            sh.allow_download AS share_allow_download,
            rec.last_accessed_at
        FROM user_documents d
        LEFT JOIN document_folders f ON f.id = d.folder_id
        LEFT JOIN profiles p ON p.id = d.owner_id
        LEFT JOIN document_favorites fav ON fav.document_id = d.id AND fav.user_id = %s::uuid
        LEFT JOIN document_shares sh ON sh.document_id = d.id AND sh.school_id = %s AND (sh.target_id = %s OR sh.target_id = %s)
        LEFT JOIN (
            SELECT document_id, MAX(accessed_at) AS last_accessed_at
            FROM document_recent_activity
            WHERE user_id = %s::uuid AND school_id = %s
            GROUP BY document_id
        ) rec ON rec.document_id = d.id
        WHERE {where_sql}
        ORDER BY {order_col} {order_dir}, d.id {order_dir}
        LIMIT %s OFFSET %s;
    """
    fetch_params = [user_id, school_id, user_id, user.get("role", ""), user_id, school_id] + params + [page_size, offset_val]
    doc_rows = await exec_sql(query_sql, tuple(fetch_params))

    # Format items
    items = []
    for r in doc_rows:
        item = _serialize_datetime(r)
        if item.get("user_has_starred"):
            item["is_starred"] = True
        if not item.get("file_type"):
            item["file_type"] = _detect_file_type(item.get("file_name") or "", item.get("mime_type"))
        # Add shared_by / owner structures for backward compatibility
        item["owner"] = {"full_name": item.get("owner_name") or "Administrator"}
        # Compute user's effective permission on this document
        is_owner = str(item.get("owner_id")) == str(user_id) or user.get("role") in ["admin", "superadmin"]
        if is_owner:
            item["current_user_permission"] = "Manager"
            item["allow_download"] = True
        elif item.get("share_permission_level"):
            item["current_user_permission"] = item["share_permission_level"]
            item["allow_download"] = bool(item.get("share_allow_download", True))
        else:
            item["current_user_permission"] = "Viewer"
            item["allow_download"] = True
        items.append(item)

    # Category counts tally
    counts_sql = f"""
        SELECT category, COUNT(*) AS cat_count
        FROM user_documents
        WHERE school_id = %s AND is_deleted = FALSE
        GROUP BY category;
    """
    cat_counts_res = await exec_sql(counts_sql, (school_id,))
    category_counts = {c: 0 for c in ALLOWED_CATEGORIES}
    for row in cat_counts_res:
        c = (row.get("category") or "").lower()
        category_counts[c] = int(row.get("cat_count") or 0)

    total_pages = (total_records + page_size - 1) // page_size if total_records > 0 else 1

    return {
        "success": True,
        "school_id": school_id,
        "data": {
            "documents": items,      # For backward compatibility
            "items": items,          # Modern standard
            "total": total_records,
            "page": page,
            "page_size": page_size,
            "total_pages": total_pages,
            "category_counts": category_counts,
        }
    }


# ============================================================================
# UPLOAD, DOWNLOAD & PREVIEW
# ============================================================================

@router.post("/upload")
async def upload_document(
    file: UploadFile = File(...),
    title: str = Form(""),
    description: str = Form(""),
    category: str = Form("my_uploads"),
    folder_id: Optional[str] = Form(None),
    department: str = Form("All"),
    tags: str = Form(""),
    approval_required: bool = Form(False),
    expiry_date: Optional[str] = Form(None),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """
    Upload a document (PDF, DOCX, XLSX, Images, etc.) with metadata,
    store securely, calculate SHA-256 checksum, record Version 1, and optional approval.
    """
    file_bytes = await file.read()
    file_size = len(file_bytes)

    # 50 MB limit
    if file_size > 50 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="File too large (maximum size is 50 MB)")
    if file_size == 0:
        raise HTTPException(status_code=400, detail="Uploaded file is empty")

    safe_name = file.filename or "document"
    extension = safe_name.rsplit(".", 1)[-1].lower() if "." in safe_name else "bin"
    file_type = _detect_file_type(safe_name, file.content_type)
    doc_id = str(uuid.uuid4())
    user_id = user["id"]

    # Compute SHA-256 Checksum
    checksum = hashlib.sha256(file_bytes).hexdigest()

    # Save to local storage for instant streaming & preview
    storage_path = f"assets/documents/{school_id}/{doc_id}.{extension}"
    full_local_path = os.path.join(os.getcwd(), storage_path)
    os.makedirs(os.path.dirname(full_local_path), exist_ok=True)
    with open(full_local_path, "wb") as f:
        f.write(file_bytes)

    # Attempt upload to Supabase Storage if configured
    supabase_storage_path = f"documents/{school_id}/{user_id}/{doc_id}.{extension}"
    supabase_url = settings.SUPABASE_URL.rstrip("/")
    storage_url = f"{supabase_url}/storage/v1/object/{supabase_storage_path}"
    headers = {
        "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
        "Content-Type": file.content_type or "application/octet-stream",
        "x-upsert": "true",
    }
    file_url = None
    try:
        global _SUPABASE_STORAGE_DISABLED_UNTIL
        if _sys_time.time() < _SUPABASE_STORAGE_DISABLED_UNTIL:
            raise RuntimeError("Supabase storage offline backoff")
        async with httpx.AsyncClient(timeout=3.0) as client:
            upload_response = await client.post(storage_url, headers=headers, content=file_bytes)
            if upload_response.status_code in (200, 201):
                public_url_base = get_public_supabase_url(supabase_url)
                file_url = f"{public_url_base}/storage/v1/object/public/{supabase_storage_path}"
    except Exception as e:
        _SUPABASE_STORAGE_DISABLED_UNTIL = _sys_time.time() + 300.0
        logger.warning(f"Supabase storage upload skipped or failed: {e}")

    if not file_url:
        file_url = f"/api/documents/{doc_id}/download"

    doc_title = title.strip() or safe_name
    mime = file.content_type or mimetypes.guess_type(safe_name)[0] or "application/octet-stream"

    # Parse tags from comma-separated string
    parsed_tags = [t.strip() for t in tags.split(",") if t.strip()] if tags else []

    approval_status = "Pending" if approval_required else "Approved"

    # Insert into user_documents
    insert_sql = """
        INSERT INTO user_documents (
            id, school_id, owner_id, folder_id, title, description, category,
            file_url, file_name, file_size, mime_type, storage_path, department,
            tags, file_type, approval_status, version_number, expiry_date, created_at, updated_at
        ) VALUES (
            %s, %s, %s::uuid, %s, %s, %s, %s,
            %s, %s, %s, %s, %s, %s,
            %s, %s, %s, 1, %s, NOW(), NOW()
        ) RETURNING *;
    """
    res = await exec_sql(insert_sql, (
        doc_id, school_id, user_id, folder_id, doc_title, description, category,
        file_url, safe_name, file_size, mime, storage_path, department,
        parsed_tags, file_type, approval_status, expiry_date or None
    ))

    # Create Version 1 record in document_versions
    v_id = str(uuid.uuid4())
    v_sql = """
        INSERT INTO document_versions (
            id, document_id, version_number, file_url, file_name, file_size, mime_type, storage_path, checksum, change_summary, uploaded_by_id
        ) VALUES (%s, %s::uuid, 1, %s, %s, %s, %s, %s, %s, 'Initial version upload', %s::uuid);
    """
    await exec_sql(v_sql, (v_id, doc_id, file_url, safe_name, file_size, mime, storage_path, checksum, user_id), fetch=False)

    # If approval required, create document_approvals entry
    if approval_required:
        app_sql = """
            INSERT INTO document_approvals (document_id, school_id, requester_id, status, comments)
            VALUES (%s::uuid, %s, %s::uuid, 'Pending', 'Initial upload submitted for administrative approval.');
        """
        await exec_sql(app_sql, (doc_id, school_id, user_id), fetch=False)

    await log_document_activity(
        school_id=school_id,
        document_id=doc_id,
        user_id=user_id,
        action="upload",
        action_details={"filename": safe_name, "size": file_size, "version": 1},
    )

    created_doc = _serialize_datetime(res[0]) if res else {}
    return {
        "success": True,
        "message": "Document uploaded successfully",
        "data": {"document": created_doc}
    }


@router.post("/save-ai")
async def save_ai_document(
    request: dict,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """
    Save an AI-generated document generated by Shami AI directly to the Documents Hub.
    Maintains 100% backward compatibility with chat sessions.
    """
    title = request.get("title", "").strip()
    content = request.get("content", "").strip()
    session_id = request.get("session_id")
    description = request.get("description", "")

    if not title:
        raise HTTPException(status_code=400, detail="Title is required")
    if not content:
        raise HTTPException(status_code=400, detail="Content is required")

    doc_id = str(uuid.uuid4())
    user_id = user["id"]

    insert_sql = """
        INSERT INTO user_documents (
            id, school_id, owner_id, title, description, category,
            content, source_chat_session_id, mime_type, file_type,
            approval_status, version_number, created_at, updated_at
        ) VALUES (
            %s, %s, %s::uuid, %s, %s, 'ai_generated',
            %s, %s, 'text/plain', 'TXT',
            'Approved', 1, NOW(), NOW()
        ) RETURNING *;
    """
    res = await exec_sql(insert_sql, (
        doc_id, school_id, user_id, title, description,
        content, session_id
    ))

    await log_document_activity(
        school_id=school_id,
        document_id=doc_id,
        user_id=user_id,
        action="ai_save",
        action_details={"session_id": session_id, "title": title},
    )

    return {"success": True, "data": {"document": _serialize_datetime(res[0])}}


# ============================================================================
# TRASH MANAGEMENT
# ============================================================================

@router.post("/empty-trash")
async def empty_trash(
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Permanently delete all documents in Trash for the current user/school."""
    await exec_sql("DELETE FROM user_documents WHERE school_id = %s AND is_deleted = TRUE;", (school_id,), fetch=False)
    return {"success": True, "message": "Trash emptied successfully"}



@router.get("/approvals/pending")
async def list_pending_approvals(
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """List all documents currently awaiting approval in this school."""
    sql = """
        SELECT 
            d.id, d.title, d.file_name, d.file_size, d.file_type, d.category, d.created_at,
            p.full_name AS requester_name, p.role AS requester_role
        FROM user_documents d
        LEFT JOIN profiles p ON p.id = d.owner_id
        WHERE d.school_id = %s AND d.is_deleted = FALSE AND d.approval_status = 'Pending'
        ORDER BY d.created_at ASC;
    """
    rows = await exec_sql(sql, (school_id,))
    serialized = [_serialize_datetime(r) for r in rows]
    return {"success": True, "data": {"pending_documents": serialized, "approvals": serialized}}


# ============================================================================
# DOCUMENT REQUESTS
# ============================================================================

class DocumentRequestCreate(BaseModel):
    title: str
    description: Optional[str] = None
    category: str = "General"
    priority: str = "Medium" # Low, Medium, High, Urgent
    required_by_date: Optional[str] = None


@router.post("/requests")
async def create_document_request(
    body: DocumentRequestCreate,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Submit a document request (e.g. transfer certificate, receipt, bonafide)."""
    req_id = str(uuid.uuid4())
    sql = """
        INSERT INTO document_requests (id, school_id, requester_id, title, description, category, priority, required_by_date, status)
        VALUES (%s, %s, %s::uuid, %s, %s, %s, %s, %s, 'New')
        RETURNING *;
    """
    res = await exec_sql(sql, (
        req_id, school_id, user["id"], body.title, body.description or "",
        body.category, body.priority, body.required_by_date or None
    ))

    return {"success": True, "message": "Document request submitted successfully", "data": {"request": _serialize_datetime(res[0])}}


@router.get("/requests")
async def list_document_requests(
    status: Optional[str] = Query(None),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """List document requests for the school."""
    where_sql = "r.school_id = %s"
    params = [school_id]
    if status and status.lower() != "all":
        if status.lower() in ("pending", "new"):
            where_sql += " AND LOWER(r.status) IN ('pending', 'new')"
        else:
            where_sql += " AND LOWER(r.status) = LOWER(%s)"
            params.append(status)

    sql = f"""
        SELECT r.*, p.full_name AS requester_name, p.role AS requester_role
        FROM document_requests r
        LEFT JOIN profiles p ON p.id = r.requester_id
        WHERE {where_sql}
        ORDER BY r.created_at DESC;
    """
    rows = await exec_sql(sql, tuple(params))
    return {"success": True, "data": {"requests": [_serialize_datetime(r) for r in rows]}}


@router.post("/requests/{request_id}/fulfill")
async def fulfill_document_request(
    request_id: str,
    document_id: str = Query(...),
    notes: Optional[str] = Query(None),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Fulfill a document request by associating an uploaded document."""
    sql = """
        UPDATE document_requests
        SET status = 'Fulfilled', fulfilled_document_id = %s::uuid, response_notes = %s, updated_at = NOW()
        WHERE id = %s AND school_id = %s
        RETURNING *;
    """
    res = await exec_sql(sql, (document_id, notes or "Fulfilled", request_id, school_id))
    if not res:
        raise HTTPException(status_code=404, detail="Request not found")

    return {"success": True, "message": "Request fulfilled successfully", "data": {"request": _serialize_datetime(res[0])}}


class DocumentRequestUpdate(BaseModel):
    status: Optional[str] = None # Pending, In Progress, Fulfilled, Rejected
    response_notes: Optional[str] = None
    fulfilled_document_id: Optional[str] = None


@router.patch("/requests/{request_id}")
async def update_document_request(
    request_id: str,
    body: DocumentRequestUpdate,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Update status and remarks for a document request."""
    r_res = await exec_sql("SELECT * FROM document_requests WHERE id = %s AND school_id = %s;", (request_id, school_id))
    if not r_res:
        raise HTTPException(status_code=404, detail="Request not found")

    updates = []
    params = []
    if body.status:
        st = body.status.strip()
        if st.lower() in ("pending", "new"):
            st = "New"
        elif st.lower() == "in progress":
            st = "In Progress"
        elif st.lower() == "fulfilled":
            st = "Fulfilled"
        elif st.lower() == "rejected":
            st = "Rejected"
        elif st.lower() == "awaiting information":
            st = "Awaiting Information"
        elif st.lower() == "cancelled":
            st = "Cancelled"
        updates.append("status = %s")
        params.append(st)
    if body.response_notes is not None:
        updates.append("response_notes = %s")
        params.append(body.response_notes)
    if body.fulfilled_document_id:
        updates.append("fulfilled_document_id = %s::uuid")
        params.append(body.fulfilled_document_id)

    if not updates:
        return {"success": True, "message": "No changes requested", "data": {"request": _serialize_datetime(r_res[0])}}

    updates.append("updated_at = NOW()")
    params.extend([request_id, school_id])
    up_sql = f"UPDATE document_requests SET {', '.join(updates)} WHERE id = %s AND school_id = %s RETURNING *;"
    res = await exec_sql(up_sql, tuple(params))
    return {"success": True, "message": "Request updated successfully", "data": {"request": _serialize_datetime(res[0])}}



# ============================================================================
# BULK OPERATIONS
# ============================================================================

class BulkActionRequest(BaseModel):
    document_ids: List[str]
    target_folder_id: Optional[str] = None
    target_category: Optional[str] = None


@router.post("/bulk/move")
async def bulk_move_documents(
    body: BulkActionRequest,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Move multiple documents to a target folder."""
    if not body.document_ids:
        raise HTTPException(status_code=400, detail="No document IDs provided")

    sql = """
        UPDATE user_documents
        SET folder_id = %s, updated_at = NOW()
        WHERE id = ANY(%s::uuid[]) AND school_id = %s;
    """
    await exec_sql(sql, (body.target_folder_id, body.document_ids, school_id), fetch=False)

    return {"success": True, "message": f"Moved {len(body.document_ids)} documents successfully"}


@router.post("/bulk/delete")
async def bulk_delete_documents(
    body: BulkActionRequest,
    permanent: bool = Query(False),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Bulk soft-delete (or permanent delete) documents."""
    if not body.document_ids:
        raise HTTPException(status_code=400, detail="No document IDs provided")

    if not permanent:
        sql = """
            UPDATE user_documents
            SET is_deleted = TRUE, deleted_at = NOW(), deleted_by_id = %s::uuid
            WHERE id = ANY(%s::uuid[]) AND school_id = %s;
        """
        await exec_sql(sql, (user["id"], body.document_ids, school_id), fetch=False)
        return {"success": True, "message": f"Moved {len(body.document_ids)} documents to Trash"}
    else:
        sql = "DELETE FROM user_documents WHERE id = ANY(%s::uuid[]) AND school_id = %s;"
        await exec_sql(sql, (body.document_ids, school_id), fetch=False)
        return {"success": True, "message": f"Permanently deleted {len(body.document_ids)} documents"}


@router.post("/bulk/restore")
async def bulk_restore_documents(
    body: BulkActionRequest,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Bulk restore soft-deleted documents from Trash."""
    if not body.document_ids:
        raise HTTPException(status_code=400, detail="No document IDs provided")

    sql = """
        UPDATE user_documents
        SET is_deleted = FALSE, deleted_at = NULL, deleted_by_id = NULL, updated_at = NOW()
        WHERE id = ANY(%s::uuid[]) AND school_id = %s AND is_deleted = TRUE;
    """
    await exec_sql(sql, (body.document_ids, school_id), fetch=False)
    return {"success": True, "message": f"Restored {len(body.document_ids)} documents from Trash"}


@router.post("/bulk/star")
async def bulk_star_documents(
    body: BulkActionRequest,
    star: bool = Query(True),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Bulk star or unstar documents."""
    if not body.document_ids:
        raise HTTPException(status_code=400, detail="No document IDs provided")

    user_id = user["id"]
    if star:
        for doc_id in body.document_ids:
            await exec_sql("""
                INSERT INTO document_favorites (school_id, user_id, document_id)
                VALUES (%s, %s::uuid, %s::uuid)
                ON CONFLICT DO NOTHING;
            """, (school_id, user_id, doc_id), fetch=False)
    else:
        await exec_sql("""
            DELETE FROM document_favorites
            WHERE user_id = %s::uuid AND document_id = ANY(%s::uuid[]);
        """, (user_id, body.document_ids), fetch=False)

    return {"success": True, "message": f"Updated starred state for {len(body.document_ids)} documents"}


@router.post("/bulk/download")
@router.post("/bulk/download-zip")
async def bulk_download_zip(
    body: BulkActionRequest,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """
    Stream a compressed ZIP file containing all selected documents.
    Supports local storage files, base64 data URIs, external URLs, and formatted content summaries.
    """
    if not body.document_ids:
        raise HTTPException(status_code=400, detail="No document IDs provided")

    sql = "SELECT id, title, file_name, storage_path, file_url, content FROM user_documents WHERE id = ANY(%s::uuid[]) AND school_id = %s;"
    docs = await exec_sql(sql, (body.document_ids, school_id))

    zip_buffer = io.BytesIO()
    with zipfile.ZipFile(zip_buffer, "w", zipfile.ZIP_DEFLATED) as zip_file:
        for d in docs:
            fname = d.get("file_name") or f"{d['title']}.pdf"
            fname = "".join(c for c in fname if c.isalnum() or c in "._- ").strip() or f"{d['id']}.pdf"
            storage_path = d.get("storage_path")
            file_url = d.get("file_url")
            added = False

            if storage_path:
                local_path = os.path.join(os.getcwd(), storage_path)
                if os.path.exists(local_path):
                    try:
                        with open(local_path, "rb") as f:
                            zip_file.writestr(fname, f.read())
                        added = True
                    except Exception:
                        pass

            if not added and file_url and file_url.startswith("data:"):
                try:
                    _, encoded = file_url.split(",", 1)
                    zip_file.writestr(fname, base64.b64decode(encoded))
                    added = True
                except Exception:
                    pass

            if not added and file_url and file_url.startswith("http"):
                try:
                    async with httpx.AsyncClient(timeout=2.0) as client:
                        resp = await client.get(file_url)
                        if resp.status_code == 200:
                            zip_file.writestr(fname, resp.content)
                            added = True
                except Exception:
                    pass

            if not added:
                content = d.get("content") or f"Document Title: {d['title']}\nUUID: {d['id']}\nFile Reference: {file_url or storage_path or 'Vault'}\n"
                zip_file.writestr(f"{d['title']}.txt", content.encode("utf-8"))

    zip_buffer.seek(0)
    zip_name = f"EduSHAMIIT_Documents_{datetime.now().strftime('%Y%m%d_%H%M%S')}.zip"
    return StreamingResponse(
        zip_buffer,
        media_type="application/zip",
        headers={
            "Content-Disposition": f'attachment; filename="{zip_name}"',
            "Access-Control-Expose-Headers": "Content-Disposition"
        }
    )


@router.post("/sync-cross-module")
async def sync_cross_module(
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Synchronize any external documents uploaded in Hostel, HR, Onboarding, Visitors, etc."""
    try:
        res = await exec_sql("SELECT sync_all_cross_module_documents(%s);", (school_id,))
        count = res[0]["sync_all_cross_module_documents"] if res else 0
        return {"success": True, "message": f"Successfully synchronized {count} cross-module documents", "synced_count": count}
    except Exception as e:
        logger.warning(f"Cross-module sync error: {e}")
        return {"success": False, "message": str(e), "synced_count": 0}



# ============================================================================
# DOCUMENT DETAIL, UPDATE & CRUD
# ============================================================================

@router.get("/{doc_id}")
async def get_document_detail(
    doc_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """
    Get full metadata, versions, permissions, and recent activity for a document.
    Also tracks recent activity for the user.
    """
    try:
        uuid.UUID(str(doc_id))
    except (ValueError, AttributeError):
        raise HTTPException(status_code=404, detail="Document not found")

    user_id = user["id"]
    sql = """
        SELECT 
            d.*, f.name AS folder_name,
            p.full_name AS owner_name, p.role AS owner_role, p.avatar_url AS owner_avatar,
            COALESCE(fav.id IS NOT NULL, FALSE) AS user_has_starred
        FROM user_documents d
        LEFT JOIN document_folders f ON f.id = d.folder_id
        LEFT JOIN profiles p ON p.id = d.owner_id
        LEFT JOIN document_favorites fav ON fav.document_id = d.id AND fav.user_id = %s::uuid
        WHERE d.id = %s AND d.school_id = %s;
    """
    res = await exec_sql(sql, (user_id, doc_id, school_id))
    if not res:
        raise HTTPException(status_code=404, detail="Document not found")

    doc = _serialize_datetime(res[0])
    if doc.get("user_has_starred"):
        doc["is_starred"] = True

    # Record recent access
    try:
        recent_upsert = """
            INSERT INTO document_recent_activity (school_id, user_id, document_id, activity_type, accessed_at)
            VALUES (%s, %s::uuid, %s::uuid, 'viewed', NOW())
            ON CONFLICT (user_id, document_id) DO UPDATE SET accessed_at = NOW();
        """
        await exec_sql(recent_upsert, (school_id, user_id, doc_id), fetch=False)
    except Exception as e:
        logger.warning(f"Failed to update document recent activity: {e}")

    # Fetch versions
    v_sql = """
        SELECT v.*, p.full_name AS uploader_name
        FROM document_versions v
        LEFT JOIN profiles p ON p.id = v.uploaded_by_id
        WHERE v.document_id = %s
        ORDER BY v.version_number DESC;
    """
    v_res = await exec_sql(v_sql, (doc_id,))
    doc["versions"] = [_serialize_datetime(v) for v in v_res]

    # Fetch shares
    s_sql = "SELECT * FROM document_shares WHERE document_id = %s ORDER BY created_at DESC;"
    s_res = await exec_sql(s_sql, (doc_id,))
    doc["shares"] = [_serialize_datetime(s) for s in s_res]

    # Fetch activity trail
    a_sql = """
        SELECT a.*, p.full_name AS user_name, p.role AS user_role
        FROM document_activity_logs a
        LEFT JOIN profiles p ON p.id = a.user_id
        WHERE a.document_id = %s
        ORDER BY a.created_at DESC
        LIMIT 20;
    """
    a_res = await exec_sql(a_sql, (doc_id,))
    doc["activities"] = [_serialize_datetime(a) for a in a_res]

    return {"success": True, "data": {"document": doc}}


class DocumentUpdateRequest(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    folder_id: Optional[str] = None
    category: Optional[str] = None
    department: Optional[str] = None
    tags: Optional[List[str]] = None
    expiry_date: Optional[str] = None
    approval_status: Optional[str] = None


@router.patch("/{doc_id}")
async def update_document_metadata(
    doc_id: str,
    body: DocumentUpdateRequest,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Update metadata for an existing document."""
    d_res = await exec_sql("SELECT * FROM user_documents WHERE id = %s AND school_id = %s;", (doc_id, school_id))
    if not d_res:
        raise HTTPException(status_code=404, detail="Document not found")

    doc = d_res[0]
    new_title = body.title.strip() if body.title is not None else doc["title"]
    new_desc = body.description if body.description is not None else doc["description"]
    new_folder = body.folder_id if body.folder_id is not None else doc["folder_id"]
    new_cat = body.category if body.category is not None else doc["category"]
    new_dept = body.department if body.department is not None else doc["department"]
    new_tags = body.tags if body.tags is not None else doc["tags"]
    new_expiry = body.expiry_date if body.expiry_date is not None else doc["expiry_date"]
    new_approval = body.approval_status if body.approval_status is not None else doc["approval_status"]

    up_sql = """
        UPDATE user_documents
        SET title = %s, description = %s, folder_id = %s, category = %s, department = %s,
            tags = %s, expiry_date = %s, approval_status = %s, updated_at = NOW()
        WHERE id = %s AND school_id = %s
        RETURNING *;
    """
    res = await exec_sql(up_sql, (
        new_title, new_desc, new_folder, new_cat, new_dept,
        new_tags, new_expiry, new_approval, doc_id, school_id
    ))

    await log_document_activity(
        school_id=school_id,
        document_id=doc_id,
        user_id=user["id"],
        action="edit",
        action_details={"title": new_title, "folder_id": new_folder},
    )

    return {"success": True, "message": "Document updated successfully", "data": {"document": _serialize_datetime(res[0])}}


@router.delete("/{doc_id}")
async def delete_document(
    doc_id: str,
    permanent: bool = Query(False, description="Whether to permanently remove from database and storage"),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """
    Soft-delete document (moves to Trash) or permanently delete if permanent=True.
    """
    d_res = await exec_sql("SELECT * FROM user_documents WHERE id = %s AND school_id = %s;", (doc_id, school_id))
    if not d_res:
        raise HTTPException(status_code=404, detail="Document not found")

    doc = d_res[0]

    if not permanent:
        # Soft delete: move to Trash
        await exec_sql("""
            UPDATE user_documents
            SET is_deleted = TRUE, deleted_at = NOW(), deleted_by_id = %s::uuid
            WHERE id = %s AND school_id = %s;
        """, (user["id"], doc_id, school_id), fetch=False)

        await log_document_activity(
            school_id=school_id,
            document_id=doc_id,
            user_id=user["id"],
            action="trash",
            action_details={"title": doc["title"]},
        )
        return {"success": True, "message": f"Document '{doc['title']}' moved to Trash"}

    # Permanent delete: remove file from storage and database
    storage_path = doc.get("storage_path")
    if storage_path:
        local_path = os.path.join(os.getcwd(), storage_path)
        if os.path.exists(local_path):
            try:
                os.remove(local_path)
            except Exception as e:
                logger.warning(f"Failed to remove local file: {e}")

        # Supabase storage deletion attempt
        try:
            supabase_url = settings.SUPABASE_URL.rstrip("/")
            prefix = storage_path[len("documents/"):] if storage_path.startswith("documents/") else storage_path
            delete_url = f"{supabase_url}/storage/v1/object/documents"
            headers = {
                "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
                "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
                "Content-Type": "application/json",
            }
            global _SUPABASE_STORAGE_DISABLED_UNTIL
            if _sys_time.time() < _SUPABASE_STORAGE_DISABLED_UNTIL:
                raise RuntimeError("Supabase storage offline backoff")
            async with httpx.AsyncClient(timeout=3.0) as client:
                await client.request("DELETE", delete_url, headers=headers, json={"prefixes": [prefix]})
        except Exception as e:
            _SUPABASE_STORAGE_DISABLED_UNTIL = _sys_time.time() + 300.0
            logger.warning(f"Supabase storage delete attempt: {e}")

    await exec_sql("DELETE FROM user_documents WHERE id = %s AND school_id = %s;", (doc_id, school_id), fetch=False)

    await log_document_activity(
        school_id=school_id,
        document_id=None,
        folder_id=doc.get("folder_id"),
        user_id=user["id"],
        action="permanent_delete",
        action_details={"deleted_document_id": doc_id, "title": doc["title"]},
    )

    return {"success": True, "message": f"Document '{doc['title']}' permanently deleted"}


@router.post("/{doc_id}/restore")
async def restore_document(
    doc_id: str,
    target_folder_id: Optional[str] = Query(None),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Restore a soft-deleted document from Trash."""
    d_res = await exec_sql("SELECT * FROM user_documents WHERE id = %s AND school_id = %s;", (doc_id, school_id))
    if not d_res:
        raise HTTPException(status_code=404, detail="Document not found")

    doc = d_res[0]
    folder_id = target_folder_id or doc.get("folder_id")

    # If original folder was deleted or missing, check if it's active
    if folder_id:
        f_check = await exec_sql("SELECT id FROM document_folders WHERE id = %s AND is_deleted = FALSE;", (folder_id,))
        if not f_check:
            folder_id = None # restore to root

    await exec_sql("""
        UPDATE user_documents
        SET is_deleted = FALSE, deleted_at = NULL, deleted_by_id = NULL, folder_id = %s, updated_at = NOW()
        WHERE id = %s AND school_id = %s;
    """, (folder_id, doc_id, school_id), fetch=False)

    await log_document_activity(
        school_id=school_id,
        document_id=doc_id,
        user_id=user["id"],
        action="restore",
        action_details={"title": doc["title"]},
    )

    return {"success": True, "message": f"Document '{doc['title']}' restored successfully"}


@router.post("/{doc_id}/favorite")
async def toggle_favorite(
    doc_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Toggle starred status for a document for the logged-in user."""
    user_id = user["id"]
    fav_check = await exec_sql("SELECT id FROM document_favorites WHERE user_id = %s::uuid AND document_id = %s::uuid;", (user_id, doc_id))
    if fav_check:
        await exec_sql("DELETE FROM document_favorites WHERE id = %s;", (fav_check[0]["id"],), fetch=False)
        await exec_sql("UPDATE user_documents SET is_starred = FALSE WHERE id = %s;", (doc_id,), fetch=False)
        is_fav = False
        msg = "Removed from starred"
    else:
        await exec_sql("""
            INSERT INTO document_favorites (school_id, user_id, document_id)
            VALUES (%s, %s::uuid, %s::uuid);
        """, (school_id, user_id, doc_id), fetch=False)
        await exec_sql("UPDATE user_documents SET is_starred = TRUE WHERE id = %s;", (doc_id,), fetch=False)
        is_fav = True
        msg = "Added to starred"

    return {"success": True, "is_starred": is_fav, "message": msg}


# ============================================================================
# DOWNLOAD & PREVIEW
# ============================================================================

@router.get("/{doc_id}/download")
async def download_document(
    doc_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """
    Authenticated streaming download.
    Increments download count and records audit trail.
    """
    d_res = await exec_sql("SELECT * FROM user_documents WHERE id = %s AND school_id = %s;", (doc_id, school_id))
    if not d_res:
        raise HTTPException(status_code=404, detail="Document not found")

    doc = d_res[0]
    user_id = user["id"]

    # Increment download count
    await exec_sql("UPDATE user_documents SET download_count = download_count + 1 WHERE id = %s;", (doc_id,), fetch=False)

    await log_document_activity(
        school_id=school_id,
        document_id=doc_id,
        user_id=user_id,
        action="download",
        action_details={"title": doc["title"]},
    )

    storage_path = doc.get("storage_path")
    if storage_path:
        local_path = os.path.join(os.getcwd(), storage_path)
        if os.path.exists(local_path):
            filename = doc.get("file_name") or f"{doc['title']}.pdf"
            return FileResponse(
                local_path,
                media_type=doc.get("mime_type") or "application/octet-stream",
                filename=filename,
            )

    # Check if public file_url is valid external redirect
    if doc.get("file_url") and doc["file_url"].startswith("http"):
        return RedirectResponse(url=get_public_supabase_url(doc["file_url"]))

    # Text content fallback
    content = doc.get("content") or ""
    filename = f"{doc.get('title', 'document')}.txt".replace('"', "'")
    return StreamingResponse(
        iter([content.encode("utf-8")]),
        media_type="text/plain; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get("/{doc_id}/preview")
async def preview_document(
    doc_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """
    Authenticated preview endpoint.
    Serves the document inline with appropriate Content-Disposition: inline headers.
    """
    d_res = await exec_sql("SELECT * FROM user_documents WHERE id = %s AND school_id = %s;", (doc_id, school_id))
    if not d_res:
        raise HTTPException(status_code=404, detail="Document not found")

    doc = d_res[0]
    user_id = user["id"]

    await exec_sql("UPDATE user_documents SET preview_count = preview_count + 1 WHERE id = %s;", (doc_id,), fetch=False)

    await log_document_activity(
        school_id=school_id,
        document_id=doc_id,
        user_id=user_id,
        action="preview",
        action_details={"title": doc["title"]},
    )

    storage_path = doc.get("storage_path")
    if storage_path:
        local_path = os.path.join(os.getcwd(), storage_path)
        if os.path.exists(local_path):
            return FileResponse(
                local_path,
                media_type=doc.get("mime_type") or "application/octet-stream",
                headers={"Content-Disposition": "inline"},
            )

    if doc.get("file_url") and doc["file_url"].startswith("http"):
        return RedirectResponse(url=get_public_supabase_url(doc["file_url"]))

    content = doc.get("content") or ""
    return StreamingResponse(
        iter([content.encode("utf-8")]),
        media_type="text/plain; charset=utf-8",
        headers={"Content-Disposition": "inline"},
    )


# ============================================================================
# DOCUMENT SHARING
# ============================================================================

class ShareCreateRequest(BaseModel):
    share_type: str = "user" # user, role, department, class, public
    target_id: Optional[str] = None
    target_name: Optional[str] = None
    permission_level: str = "Viewer" # Viewer, Commenter, Editor, Manager
    allow_download: bool = True
    allow_print: bool = True
    expiry_date: Optional[str] = None
    message: Optional[str] = None


@router.post("/{doc_id}/share")
async def share_document(
    doc_id: str,
    body: ShareCreateRequest,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Share document with a user, role, department, or class."""
    d_res = await exec_sql("SELECT * FROM user_documents WHERE id = %s AND school_id = %s;", (doc_id, school_id))
    if not d_res:
        raise HTTPException(status_code=404, detail="Document not found")

    share_id = str(uuid.uuid4())
    norm_share_type = body.share_type.lower().strip() if body.share_type else "user"
    access_token = str(uuid.uuid4()) if norm_share_type == "public" else None

    sql = """
        INSERT INTO document_shares (
            id, document_id, school_id, shared_by_id, share_type, target_id, target_name,
            permission_level, allow_download, allow_print, expiry_date, access_token, message
        ) VALUES (
            %s, %s::uuid, %s, %s::uuid, %s, %s, %s,
            %s, %s, %s, %s, %s, %s
        ) RETURNING *;
    """
    res = await exec_sql(sql, (
        share_id, doc_id, school_id, user["id"], norm_share_type, body.target_id, body.target_name,
        body.permission_level, body.allow_download, body.allow_print, body.expiry_date or None,
        access_token, body.message or ""
    ))

    await log_document_activity(
        school_id=school_id,
        document_id=doc_id,
        user_id=user["id"],
        action="share",
        action_details={"share_type": body.share_type, "target": body.target_name or body.target_id, "level": body.permission_level},
    )

    return {"success": True, "message": "Document shared successfully", "data": {"share": _serialize_datetime(res[0])}}


@router.get("/{doc_id}/shares")
async def list_document_shares(
    doc_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """List all current shares for a document."""
    sql = """
        SELECT s.*, p.full_name AS shared_by_name
        FROM document_shares s
        LEFT JOIN profiles p ON p.id = s.shared_by_id
        WHERE s.document_id = %s::uuid AND s.school_id = %s
        ORDER BY s.created_at DESC;
    """
    rows = await exec_sql(sql, (doc_id, school_id))
    return {"success": True, "data": {"shares": [_serialize_datetime(r) for r in rows]}}


@router.delete("/shares/{share_id}")
async def revoke_share(
    share_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Revoke an existing document share."""
    s_res = await exec_sql("SELECT * FROM document_shares WHERE id = %s AND school_id = %s;", (share_id, school_id))
    if not s_res:
        raise HTTPException(status_code=404, detail="Share record not found")

    share = s_res[0]
    await exec_sql("DELETE FROM document_shares WHERE id = %s;", (share_id,), fetch=False)

    await log_document_activity(
        school_id=school_id,
        document_id=str(share["document_id"]),
        user_id=user["id"],
        action="revoke_share",
        action_details={"target": share.get("target_name")},
    )

    return {"success": True, "message": "Share access revoked successfully"}


# ============================================================================
# VERSION CONTROL
# ============================================================================

@router.post("/{doc_id}/versions")
async def create_new_version(
    doc_id: str,
    file: UploadFile = File(...),
    change_summary: str = Form("Updated document version"),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """
    Upload a replacement file creating a new immutable version.
    Increments version number while keeping previous versions intact.
    """
    d_res = await exec_sql("SELECT * FROM user_documents WHERE id = %s AND school_id = %s;", (doc_id, school_id))
    if not d_res:
        raise HTTPException(status_code=404, detail="Document not found")

    doc = d_res[0]
    file_bytes = await file.read()
    file_size = len(file_bytes)

    if file_size == 0:
        raise HTTPException(status_code=400, detail="Empty file cannot be uploaded")

    new_version_num = (doc.get("version_number") or 1) + 1
    safe_name = file.filename or doc.get("file_name") or "document"
    ext = safe_name.rsplit(".", 1)[-1].lower() if "." in safe_name else "bin"
    mime = file.content_type or mimetypes.guess_type(safe_name)[0] or "application/octet-stream"
    file_type = _detect_file_type(safe_name, mime)
    checksum = hashlib.sha256(file_bytes).hexdigest()

    version_id = str(uuid.uuid4())
    storage_path = f"assets/documents/{school_id}/{doc_id}_v{new_version_num}.{ext}"
    full_local_path = os.path.join(os.getcwd(), storage_path)
    os.makedirs(os.path.dirname(full_local_path), exist_ok=True)
    with open(full_local_path, "wb") as f:
        f.write(file_bytes)

    file_url = f"/api/documents/{doc_id}/download"

    # Insert into document_versions
    v_sql = """
        INSERT INTO document_versions (
            id, document_id, version_number, file_url, file_name, file_size, mime_type, storage_path, checksum, change_summary, uploaded_by_id
        ) VALUES (%s, %s::uuid, %s, %s, %s, %s, %s, %s, %s, %s, %s::uuid)
        RETURNING *;
    """
    v_res = await exec_sql(v_sql, (
        version_id, doc_id, new_version_num, file_url, safe_name, file_size, mime, storage_path, checksum, change_summary, user["id"]
    ))

    # Update current document pointers
    await exec_sql("""
        UPDATE user_documents
        SET version_number = %s, current_version_id = %s::uuid, file_size = %s, file_name = %s,
            file_type = %s, mime_type = %s, storage_path = %s, updated_at = NOW()
        WHERE id = %s AND school_id = %s;
    """, (new_version_num, version_id, file_size, safe_name, file_type, mime, storage_path, doc_id, school_id), fetch=False)

    await log_document_activity(
        school_id=school_id,
        document_id=doc_id,
        user_id=user["id"],
        action="version_upload",
        action_details={"version": new_version_num, "change_summary": change_summary},
    )

    return {
        "success": True,
        "message": f"Version {new_version_num} uploaded successfully",
        "data": {"version": _serialize_datetime(v_res[0])}
    }


@router.get("/{doc_id}/versions")
async def list_versions(
    doc_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """List all version history for a document."""
    sql = """
        SELECT v.*, p.full_name AS uploader_name
        FROM document_versions v
        LEFT JOIN profiles p ON p.id = v.uploaded_by_id
        WHERE v.document_id = %s::uuid
        ORDER BY v.version_number DESC;
    """
    rows = await exec_sql(sql, (doc_id,))
    return {"success": True, "data": {"versions": [_serialize_datetime(r) for r in rows]}}


@router.post("/{doc_id}/versions/{version_id}/restore")
async def restore_version(
    doc_id: str,
    version_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Restore a historical version to become the current document version."""
    v_res = await exec_sql("SELECT * FROM document_versions WHERE id = %s::uuid AND document_id = %s::uuid;", (version_id, doc_id))
    if not v_res:
        raise HTTPException(status_code=404, detail="Version not found")

    target_ver = v_res[0]
    await exec_sql("""
        UPDATE user_documents
        SET current_version_id = %s::uuid, file_url = %s, file_name = %s, file_size = %s,
            mime_type = %s, storage_path = %s, updated_at = NOW()
        WHERE id = %s AND school_id = %s;
    """, (
        version_id, target_ver["file_url"], target_ver["file_name"], target_ver["file_size"],
        target_ver["mime_type"], target_ver["storage_path"], doc_id, school_id
    ), fetch=False)

    await log_document_activity(
        school_id=school_id,
        document_id=doc_id,
        user_id=user["id"],
        action="version_restore",
        action_details={"restored_version": target_ver["version_number"]},
    )

    return {"success": True, "message": f"Restored Version {target_ver['version_number']} as current document"}


# ============================================================================
# APPROVAL WORKFLOW
# ============================================================================

class ApprovalActionRequest(BaseModel):
    comments: Optional[str] = None
    reason: Optional[str] = None


@router.post("/{doc_id}/submit-approval")
async def submit_for_approval(
    doc_id: str,
    body: ApprovalActionRequest,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Submit document for administrative review and approval."""
    await exec_sql("""
        UPDATE user_documents
        SET approval_status = 'Pending', approval_notes = %s, updated_at = NOW()
        WHERE id = %s AND school_id = %s;
    """, (body.comments or "Submitted for review", doc_id, school_id), fetch=False)

    app_id = str(uuid.uuid4())
    await exec_sql("""
        INSERT INTO document_approvals (id, document_id, school_id, requester_id, status, comments)
        VALUES (%s, %s::uuid, %s, %s::uuid, 'Pending', %s);
    """, (app_id, doc_id, school_id, user["id"], body.comments or "Submitted for review"), fetch=False)

    await log_document_activity(
        school_id=school_id,
        document_id=doc_id,
        user_id=user["id"],
        action="submit_approval",
        action_details={"notes": body.comments},
    )

    return {"success": True, "message": "Document submitted for approval"}


@router.post("/{doc_id}/approve")
async def approve_document(
    doc_id: str,
    body: ApprovalActionRequest,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Approve a pending document."""
    await exec_sql("""
        UPDATE user_documents
        SET approval_status = 'Approved', approval_notes = %s, updated_at = NOW()
        WHERE id = %s AND school_id = %s;
    """, (body.comments or "Approved", doc_id, school_id), fetch=False)

    await exec_sql("""
        UPDATE document_approvals
        SET status = 'Approved', approver_id = %s::uuid, reviewed_at = NOW(), comments = %s
        WHERE document_id = %s::uuid AND school_id = %s AND status = 'Pending';
    """, (user["id"], body.comments or "Approved", doc_id, school_id), fetch=False)

    await log_document_activity(
        school_id=school_id,
        document_id=doc_id,
        user_id=user["id"],
        action="approved",
        action_details={"comments": body.comments},
    )

    return {"success": True, "message": "Document approved successfully"}


@router.post("/{doc_id}/reject")
async def reject_document(
    doc_id: str,
    body: ApprovalActionRequest,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Reject a pending document with mandatory reason."""
    reason = (body.reason or body.comments or "").strip()
    if not reason:
        raise HTTPException(status_code=400, detail="Rejection reason is mandatory")

    await exec_sql("""
        UPDATE user_documents
        SET approval_status = 'Rejected', approval_notes = %s, updated_at = NOW()
        WHERE id = %s AND school_id = %s;
    """, (reason, doc_id, school_id), fetch=False)

    await exec_sql("""
        UPDATE document_approvals
        SET status = 'Rejected', approver_id = %s::uuid, reviewed_at = NOW(), rejection_reason = %s
        WHERE document_id = %s::uuid AND school_id = %s AND status = 'Pending';
    """, (user["id"], reason, doc_id, school_id), fetch=False)

    await log_document_activity(
        school_id=school_id,
        document_id=doc_id,
        user_id=user["id"],
        action="rejected",
        action_details={"rejection_reason": reason},
    )

    return {"success": True, "message": "Document rejected with reason recorded"}


# ============================================================================
# AUDIT & ACTIVITY TIMELINE
# ============================================================================

@router.get("/{doc_id}/activity")
async def get_document_activity(
    doc_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Retrieve full chronological activity history for a document."""
    sql = """
        SELECT a.*, p.full_name AS user_name, p.role AS user_role, p.avatar_url
        FROM document_activity_logs a
        LEFT JOIN profiles p ON p.id = a.user_id
        WHERE a.document_id = %s::uuid AND a.school_id = %s
        ORDER BY a.created_at DESC;
    """
    rows = await exec_sql(sql, (doc_id, school_id))
    return {"success": True, "data": {"activities": [_serialize_datetime(r) for r in rows]}}
