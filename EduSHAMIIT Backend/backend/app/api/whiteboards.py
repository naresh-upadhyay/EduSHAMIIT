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
# 1B. ACADEMIC DIRECTORY FOR SHARING (CLASSES -> SECTIONS -> MEMBERS & SEARCH)
# ============================================================================

@router.get("/whiteboards/directory/classes")
async def get_share_directory_classes(
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Return active classes with nested active sections, student counts & teacher counts."""
    rows = await exec_sql(
        """
        SELECT
            c.id::TEXT AS id,
            c.name,
            c.code,
            c.stage,
            c.academic_year,
            COALESCE((
                SELECT COUNT(DISTINCT sca.student_id)
                FROM public.student_class_assignments sca
                WHERE sca.class_id = c.id AND sca.school_id = %s::UUID AND UPPER(COALESCE(sca.status, 'ACTIVE')) = 'ACTIVE'
            ), 0) AS students_count,
            COALESCE((
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'id', s.id::TEXT,
                        'name', s.name,
                        'code', s.code,
                        'students_count', COALESCE((
                            SELECT COUNT(DISTINCT sca2.student_id)
                            FROM public.student_class_assignments sca2
                            WHERE sca2.section_id = s.id AND sca2.school_id = %s::UUID AND UPPER(COALESCE(sca2.status, 'ACTIVE')) = 'ACTIVE'
                        ), 0),
                        'teachers_count', COALESCE((
                            SELECT COUNT(DISTINCT tid) FROM (
                                SELECT cta.teacher_id AS tid
                                FROM public.class_teacher_assignments cta
                                WHERE cta.class_id = c.id AND cta.section_id = s.id AND cta.school_id = %s::UUID
                                UNION
                                SELECT sst.teacher_id AS tid
                                FROM public.section_subject_teachers sst
                                WHERE sst.class_id = c.id AND sst.section_id = s.id AND sst.school_id = %s::UUID
                                  AND UPPER(COALESCE(sst.status, 'ACTIVE')) = 'ACTIVE'
                            ) t_cnt
                        ), 0)
                    )
                    ORDER BY s.display_order ASC, s.name ASC
                )
                FROM public.academic_sections s
                WHERE s.class_id = c.id
                  AND s.school_id = %s::UUID
                  AND s.deleted_at IS NULL
                  AND UPPER(COALESCE(s.status, 'ACTIVE')) = 'ACTIVE'
            ), '[]'::JSONB) AS sections
        FROM public.academic_classes c
        WHERE c.school_id = %s::UUID
          AND c.deleted_at IS NULL
          AND UPPER(COALESCE(c.status, 'ACTIVE')) = 'ACTIVE'
        ORDER BY c.display_order ASC, c.name ASC;
        """,
        (school_id, school_id, school_id, school_id, school_id, school_id),
    )
    return {"success": True, "data": rows}


@router.get("/whiteboards/directory/class-members")
async def get_share_class_members(
    class_id: str = Query(...),
    section_ids: Optional[str] = Query(None, description="Comma-separated section UUIDs"),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Return students & teachers belonging to the selected class and optional multiple sections."""
    parsed_sections = [s.strip() for s in (section_ids or "").split(",") if s.strip()]

    student_sql = """
        SELECT DISTINCT ON (p.id)
            p.id::TEXT AS id,
            COALESCE(p.full_name, p.email, 'Student') AS full_name,
            p.email,
            'student'::TEXT AS role,
            COALESCE(sca.roll_number, p.roll_number::TEXT, '') AS roll_number,
            COALESCE(p.admission_number, '') AS admission_number,
            sca.section_id::TEXT AS section_id,
            COALESCE(sec.name, '') AS section_name,
            COALESCE(c.name, '') AS class_name
        FROM public.student_class_assignments sca
        JOIN public.profiles p ON p.id = sca.student_id
        JOIN public.academic_classes c ON c.id = sca.class_id
        LEFT JOIN public.academic_sections sec ON sec.id = sca.section_id
        WHERE sca.school_id = %s::UUID
          AND sca.class_id = %s::UUID
          AND UPPER(COALESCE(sca.status, 'ACTIVE')) = 'ACTIVE'
    """
    student_params: List[Any] = [school_id, class_id]
    if parsed_sections:
        student_sql += " AND sca.section_id = ANY(%s::UUID[])"
        student_params.append(parsed_sections)
    student_sql += " ORDER BY p.id, sec.name ASC, sca.roll_number ASC;"

    students = await exec_sql(student_sql, tuple(student_params))
    students.sort(key=lambda r: (r.get("section_name") or "", r.get("full_name") or ""))

    teacher_sql = """
        WITH scoped_teachers AS (
            SELECT
                cta.teacher_id,
                cta.section_id,
                CASE WHEN cta.section_id IS NULL THEN 'Class Teacher' ELSE 'Section Teacher' END AS assignment_label
            FROM public.class_teacher_assignments cta
            WHERE cta.school_id = %s::UUID
              AND cta.class_id = %s::UUID
              AND (%s::BOOLEAN OR cta.section_id IS NULL OR cta.section_id = ANY(%s::UUID[]))
            UNION ALL
            SELECT
                sst.teacher_id,
                sst.section_id,
                COALESCE(sub.name, 'Subject Teacher') AS assignment_label
            FROM public.section_subject_teachers sst
            LEFT JOIN public.academic_subjects sub ON sub.id = sst.subject_id
            WHERE sst.school_id = %s::UUID
              AND sst.class_id = %s::UUID
              AND UPPER(COALESCE(sst.status, 'ACTIVE')) = 'ACTIVE'
              AND (%s::BOOLEAN OR sst.section_id IS NULL OR sst.section_id = ANY(%s::UUID[]))
        )
        SELECT DISTINCT ON (p.id)
            p.id::TEXT AS id,
            COALESCE(p.full_name, p.email, 'Teacher') AS full_name,
            p.email,
            COALESCE(NULLIF(LOWER(p.role), ''), 'teacher') AS role,
            COALESCE(p.employee_id, '') AS employee_id,
            COALESCE(p.department, '') AS department,
            st.section_id::TEXT AS section_id,
            COALESCE(sec.name, 'All Sections') AS section_name,
            st.assignment_label
        FROM scoped_teachers st
        JOIN public.profiles p ON p.id = st.teacher_id
        LEFT JOIN public.academic_sections sec ON sec.id = st.section_id
        ORDER BY p.id, st.assignment_label ASC;
    """
    no_sec_filter = len(parsed_sections) == 0
    sec_array = parsed_sections if parsed_sections else []
    teachers = await exec_sql(
        teacher_sql,
        (school_id, class_id, no_sec_filter, sec_array, school_id, class_id, no_sec_filter, sec_array),
    )
    teachers.sort(key=lambda r: (r.get("full_name") or ""))

    return {
        "success": True,
        "data": {
            "students": students,
            "teachers": teachers,
        },
    }


@router.get("/whiteboards/directory/search-users")
async def search_share_users(
    q: str = Query(""),
    role_filter: str = Query("all"),
    limit: int = Query(60, ge=1, le=200),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Search individual students, teachers, and staff across the institution."""
    rf = (role_filter or "all").strip().lower()
    search_term = (q or "").strip()

    sql = """
        SELECT DISTINCT ON (p.id)
            p.id::TEXT AS id,
            COALESCE(p.full_name, p.email, 'User') AS full_name,
            p.email,
            LOWER(COALESCE(p.role, 'student')) AS role,
            COALESCE(p.employee_id, '') AS employee_id,
            COALESCE(p.admission_number, '') AS admission_number,
            COALESCE(sca.roll_number, p.roll_number::TEXT, '') AS roll_number,
            COALESCE(p.department, '') AS department,
            COALESCE(c.name, '') AS class_name,
            COALESCE(sec.name, '') AS section_name
        FROM public.profiles p
        LEFT JOIN public.student_class_assignments sca
               ON sca.student_id = p.id
              AND sca.school_id = %s::UUID
              AND UPPER(COALESCE(sca.status, 'ACTIVE')) = 'ACTIVE'
        LEFT JOIN public.academic_classes c ON c.id = sca.class_id
        LEFT JOIN public.academic_sections sec ON sec.id = sca.section_id
        WHERE p.school_id = %s::UUID
          AND UPPER(COALESCE(p.status, 'ACTIVE')) NOT IN ('DELETED', 'INACTIVE', 'ARCHIVED')
    """
    params: List[Any] = [school_id, school_id]

    if rf == "student":
        sql += " AND LOWER(COALESCE(p.role, 'student')) = 'student'"
    elif rf == "teacher":
        sql += " AND LOWER(COALESCE(p.role, '')) IN ('teacher', 'faculty', 'instructor', 'staff', 'admin', 'principal', 'headmaster', 'coordinator', 'superadmin', 'super_admin')"

    if search_term:
        like = f"%{search_term}%"
        sql += """
          AND (
              p.full_name ILIKE %s
              OR COALESCE(p.email, '') ILIKE %s
              OR COALESCE(p.employee_id, '') ILIKE %s
              OR COALESCE(p.admission_number, '') ILIKE %s
              OR COALESCE(p.department, '') ILIKE %s
              OR COALESCE(c.name, '') ILIKE %s
              OR COALESCE(sec.name, '') ILIKE %s
          )
        """
        params.extend([like, like, like, like, like, like, like])

    sql += " ORDER BY p.id, p.full_name ASC LIMIT %s;"
    params.append(limit)

    rows = await exec_sql(sql, tuple(params))
    rows.sort(key=lambda r: (r.get("full_name") or ""))
    return {"success": True, "data": rows}


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

    if payload.get("description") is not None:
        await exec_sql(
            "UPDATE public.live_class_whiteboards SET description = %s::TEXT, updated_at = NOW() WHERE id = %s::UUID AND school_id = %s::UUID AND deleted_at IS NULL;",
            (str(payload.get("description")), whiteboard_id, school_id),
            fetch=False,
        )

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


@router.post("/whiteboards/{whiteboard_id}/duplicate")
async def duplicate_whiteboard(
    whiteboard_id: str,
    payload: Dict[str, Any] = Body(default={}),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    await _check_permission(whiteboard_id, school_id, user)
    role = str(user.get("role", "")).lower()
    if role == "student":
        raise HTTPException(status_code=403, detail="Only teachers or admins can duplicate whiteboards")

    src_rows = await exec_sql(
        """
        SELECT id, session_id, title, description, template_type, collaboration_enabled,
               presentation_mode, teacher_only_mode, default_permissions
        FROM public.live_class_whiteboards
        WHERE id = %s::UUID AND school_id = %s::UUID AND deleted_at IS NULL
        LIMIT 1;
        """,
        (whiteboard_id, school_id),
    )
    if not src_rows:
        raise HTTPException(status_code=404, detail="Whiteboard not found")
    src = src_rows[0]

    new_wb_id = str(uuid.uuid4())
    new_title = (payload.get("title") or "").strip() or f"{src.get('title') or 'Class Whiteboard'} (Copy)"
    target_session_id = payload.get("session_id")
    if target_session_id is None and payload.get("preserve_session") is True:
        target_session_id = str(src["session_id"]) if src.get("session_id") else None

    def _clone_tx():
        conn = psycopg2.connect(settings.DATABASE_URL, connect_timeout=5)
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(
                    """
                    INSERT INTO public.live_class_whiteboards (
                        id, session_id, school_id, title, description,
                        created_by, owner_user_id, last_saved_by,
                        current_revision, teacher_only_mode, collaboration_enabled,
                        presentation_mode, template_type, default_permissions, status
                    ) VALUES (
                        %s::UUID, %s::UUID, %s::UUID, %s::TEXT, %s::TEXT,
                        %s::UUID, %s::UUID, %s::UUID,
                        1, %s::BOOLEAN, %s::BOOLEAN,
                        %s::BOOLEAN, %s::TEXT, %s::JSONB, 'ACTIVE'
                    );
                    """,
                    (
                        new_wb_id,
                        target_session_id,
                        school_id,
                        new_title,
                        src.get("description") or "",
                        user["id"],
                        user["id"],
                        user["id"],
                        bool(src.get("teacher_only_mode", False)),
                        bool(src.get("collaboration_enabled", True)),
                        bool(src.get("presentation_mode", False)),
                        src.get("template_type") or "blank",
                        json.dumps(src.get("default_permissions") or {}),
                    ),
                )
                cur.execute(
                    """
                    INSERT INTO public.whiteboard_permissions (whiteboard_id, school_id, user_id, permission_type, granted_by)
                    VALUES (%s::UUID, %s::UUID, %s::UUID, 'OWNER', %s::UUID)
                    ON CONFLICT DO NOTHING;
                    """,
                    (new_wb_id, school_id, user["id"], user["id"]),
                )

                cur.execute(
                    """
                    SELECT id, title, page_order, background_type, background_config, canvas_config, is_locked
                    FROM public.whiteboard_pages
                    WHERE whiteboard_id = %s::UUID AND deleted_at IS NULL
                    ORDER BY page_order ASC;
                    """,
                    (whiteboard_id,),
                )
                pages = cur.fetchall()
                page_map: Dict[str, str] = {}
                if not pages:
                    cur.execute(
                        """
                        INSERT INTO public.whiteboard_pages (id, whiteboard_id, school_id, title, page_order, background_type, created_by)
                        VALUES (%s::UUID, %s::UUID, %s::UUID, '1. Drawing Canvas', 1, 'plain', %s::UUID);
                        """,
                        (str(uuid.uuid4()), new_wb_id, school_id, user["id"]),
                    )
                else:
                    for p in pages:
                        new_page_id = str(uuid.uuid4())
                        page_map[str(p["id"])] = new_page_id
                        cur.execute(
                            """
                            INSERT INTO public.whiteboard_pages (
                                id, whiteboard_id, school_id, title, page_order,
                                background_type, background_config, canvas_config, is_locked, created_by
                            ) VALUES (
                                %s::UUID, %s::UUID, %s::UUID, %s::TEXT, %s::INTEGER,
                                %s::TEXT, %s::JSONB, %s::JSONB, %s::BOOLEAN, %s::UUID
                            );
                            """,
                            (
                                new_page_id,
                                new_wb_id,
                                school_id,
                                p.get("title") or "Page 1",
                                int(p.get("page_order") or 1),
                                p.get("background_type") or "plain",
                                json.dumps(p.get("background_config") or {}),
                                json.dumps(p.get("canvas_config") or {"width": 2400, "height": 1600}),
                                bool(p.get("is_locked", False)),
                                user["id"],
                            ),
                        )

                    cur.execute(
                        """
                        SELECT page_id, object_id, object_type, object_data, z_index, is_locked
                        FROM public.whiteboard_objects
                        WHERE whiteboard_id = %s::UUID AND deleted_at IS NULL
                        ORDER BY z_index ASC;
                        """,
                        (whiteboard_id,),
                    )
                    for obj in cur.fetchall():
                        mapped_page_id = page_map.get(str(obj["page_id"]))
                        if not mapped_page_id:
                            continue
                        cur.execute(
                            """
                            INSERT INTO public.whiteboard_objects (
                                whiteboard_id, page_id, school_id, object_id,
                                object_type, object_data, z_index, is_locked, created_by
                            ) VALUES (
                                %s::UUID, %s::UUID, %s::UUID, %s::TEXT,
                                %s::TEXT, %s::JSONB, %s::INTEGER, %s::BOOLEAN, %s::UUID
                            );
                            """,
                            (
                                new_wb_id,
                                mapped_page_id,
                                school_id,
                                obj.get("object_id"),
                                obj.get("object_type"),
                                json.dumps(obj.get("object_data") or {}),
                                int(obj.get("z_index") or 0),
                                bool(obj.get("is_locked", False)),
                                user["id"],
                            ),
                        )

                cur.execute(
                    "SELECT public.sp_log_whiteboard_audit(%s::UUID, %s::UUID, %s::UUID, 'whiteboard.duplicated', %s::jsonb);",
                    (new_wb_id, school_id, user["id"], json.dumps({"source_whiteboard_id": whiteboard_id})),
                )
                cur.execute(
                    "SELECT public.sp_get_whiteboard_full(%s::UUID, %s::UUID, %s::UUID) AS data;",
                    (new_wb_id, school_id, user["id"]),
                )
                row = cur.fetchone()
                conn.commit()
                return row["data"] if row else None
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    duplicated = await asyncio.to_thread(_clone_tx)
    if not duplicated:
        raise HTTPException(status_code=500, detail="Failed to duplicate whiteboard")
    return {"success": True, "data": duplicated}


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

    target_id = payload.get("target_id")
    share_type = payload.get("share_type", "class")
    access_level = str(payload.get("access_level", "VIEW")).upper()
    capabilities = payload.get("capabilities")

    rows = await exec_sql(
        "SELECT public.sp_share_whiteboard(%s::UUID, %s::UUID, %s::UUID, %s::TEXT, %s::UUID, %s::TEXT, %s::TEXT, %s::TIMESTAMPTZ) AS share;",
        (
            whiteboard_id,
            school_id,
            user["id"],
            share_type,
            target_id,
            payload.get("target_label", "Class 10 - A"),
            access_level,
            payload.get("expires_at"),
        ),
    )
    if target_id and str(share_type).lower() in ("student", "teacher", "user"):
        await _upsert_shared_user_permission(
            whiteboard_id=whiteboard_id,
            school_id=school_id,
            granter_id=user["id"],
            target_user_id=target_id,
            access_level=access_level,
            capabilities=capabilities,
        )
    return {"success": True, "data": rows[0]["share"]}


async def _upsert_shared_user_permission(
    whiteboard_id: str,
    school_id: str,
    granter_id: str,
    target_user_id: str,
    access_level: str,
    capabilities: Optional[Dict[str, Any]] = None,
) -> None:
    lvl = str(access_level or "VIEW").upper()
    if lvl not in ("VIEW", "ANNOTATE", "EDIT", "OWNER"):
        lvl = "VIEW"
    assigned_area = json.dumps({"capabilities": capabilities}) if capabilities else None
    await exec_sql(
        """
        INSERT INTO public.whiteboard_permissions (
            whiteboard_id, school_id, user_id, permission_type, assigned_area, granted_by
        ) VALUES (
            %s::UUID, %s::UUID, %s::UUID, %s::TEXT, %s::JSONB, %s::UUID
        )
        ON CONFLICT (whiteboard_id, user_id) WHERE user_id IS NOT NULL
        DO UPDATE SET
            permission_type = EXCLUDED.permission_type,
            assigned_area = COALESCE(EXCLUDED.assigned_area, public.whiteboard_permissions.assigned_area),
            granted_by = EXCLUDED.granted_by,
            updated_at = NOW();
        """,
        (whiteboard_id, school_id, target_user_id, lvl, assigned_area, granter_id),
        fetch=False,
    )


@router.post("/whiteboards/{whiteboard_id}/share/batch")
async def share_whiteboard_batch(
    whiteboard_id: str,
    payload: Dict[str, Any] = Body(...),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Share whiteboard with cascading Class/Multiple Sections + Members OR Multiple Searched Individuals."""
    perm = await _check_permission(whiteboard_id, school_id, user)
    if not perm.get("can_manage_permissions"):
        raise HTTPException(status_code=403, detail="Only owner/teacher can share whiteboard")

    mode = str(payload.get("mode", "individual")).lower()
    access_level = str(payload.get("access_level", "VIEW")).upper()
    if access_level not in ("VIEW", "ANNOTATE", "EDIT", "OWNER"):
        access_level = "VIEW"
    capabilities = payload.get("capabilities") if isinstance(payload.get("capabilities"), dict) else {}
    expires_at = payload.get("expires_at")

    created_shares: List[Dict[str, Any]] = []
    granted_user_ids: set = set()

    if mode == "class_sections":
        class_id = payload.get("class_id")
        class_name = (payload.get("class_name") or "Class").strip()
        sections = payload.get("sections") or []  # [{id, name}]
        include_students = bool(payload.get("include_students", True))
        include_teachers = bool(payload.get("include_teachers", True))
        explicit_users = payload.get("users") or []

        audience_parts = []
        if include_students:
            audience_parts.append("Students")
        if include_teachers:
            audience_parts.append("Teachers")
        audience_suffix = f" ({' & '.join(audience_parts)})" if audience_parts else ""

        if sections:
            for sec in sections:
                sec_id = sec.get("id")
                sec_name = (sec.get("name") or "Section").strip()
                label = f"{class_name} - {sec_name}{audience_suffix}"
                rows = await exec_sql(
                    "SELECT public.sp_share_whiteboard(%s::UUID, %s::UUID, %s::UUID, 'section', %s::UUID, %s::TEXT, %s::TEXT, %s::TIMESTAMPTZ) AS share;",
                    (whiteboard_id, school_id, user["id"], sec_id, label, access_level, expires_at),
                )
                if rows and rows[0].get("share"):
                    created_shares.append(rows[0]["share"])
        elif class_id:
            label = f"{class_name} (All Sections){audience_suffix}"
            rows = await exec_sql(
                "SELECT public.sp_share_whiteboard(%s::UUID, %s::UUID, %s::UUID, 'class', %s::UUID, %s::TEXT, %s::TEXT, %s::TIMESTAMPTZ) AS share;",
                (whiteboard_id, school_id, user["id"], class_id, label, access_level, expires_at),
            )
            if rows and rows[0].get("share"):
                created_shares.append(rows[0]["share"])

        # Resolve user IDs to grant real board permissions (explicitly checked OR DB lookup)
        if explicit_users:
            for u in explicit_users:
                uid = (u.get("id") or "").strip()
                if uid:
                    granted_user_ids.add(uid)
        elif class_id:
            sec_id_list = [str(s.get("id")) for s in sections if s.get("id")]
            if include_students:
                stu_q = """
                    SELECT DISTINCT student_id::TEXT AS uid
                    FROM public.student_class_assignments
                    WHERE school_id = %s::UUID AND class_id = %s::UUID AND UPPER(COALESCE(status, 'ACTIVE')) = 'ACTIVE'
                """
                stu_p: List[Any] = [school_id, class_id]
                if sec_id_list:
                    stu_q += " AND section_id = ANY(%s::UUID[])"
                    stu_p.append(sec_id_list)
                for r in await exec_sql(stu_q + ";", tuple(stu_p)):
                    if r.get("uid"):
                        granted_user_ids.add(r["uid"])
            if include_teachers:
                no_sec = len(sec_id_list) == 0
                t_rows = await exec_sql(
                    """
                    SELECT DISTINCT tid::TEXT AS uid FROM (
                        SELECT teacher_id AS tid FROM public.class_teacher_assignments
                        WHERE school_id = %s::UUID AND class_id = %s::UUID AND (%s::BOOLEAN OR section_id IS NULL OR section_id = ANY(%s::UUID[]))
                        UNION
                        SELECT teacher_id AS tid FROM public.section_subject_teachers
                        WHERE school_id = %s::UUID AND class_id = %s::UUID AND UPPER(COALESCE(status, 'ACTIVE')) = 'ACTIVE'
                          AND (%s::BOOLEAN OR section_id IS NULL OR section_id = ANY(%s::UUID[]))
                    ) q;
                    """,
                    (school_id, class_id, no_sec, sec_id_list, school_id, class_id, no_sec, sec_id_list),
                )
                for r in t_rows:
                    if r.get("uid"):
                        granted_user_ids.add(r["uid"])
    elif mode == "individual":
        users_list = payload.get("users") or []
        if not users_list:
            raise HTTPException(status_code=400, detail="Select at least one student or teacher to share with")
        for u in users_list:
            uid = (u.get("id") or "").strip()
            name = (u.get("name") or u.get("full_name") or "User").strip()
            urole = str(u.get("role") or "student").lower()
            stype = "teacher" if urole in ("teacher", "faculty", "staff", "admin", "super_admin", "principal") else "student"
            subtitle = (u.get("label") or "").strip()
            target_label = f"{name} ({subtitle})" if subtitle else name
            rows = await exec_sql(
                "SELECT public.sp_share_whiteboard(%s::UUID, %s::UUID, %s::UUID, %s::TEXT, %s::UUID, %s::TEXT, %s::TEXT, %s::TIMESTAMPTZ) AS share;",
                (whiteboard_id, school_id, user["id"], stype, uid or None, target_label, access_level, expires_at),
            )
            if rows and rows[0].get("share"):
                created_shares.append(rows[0]["share"])
            if uid:
                granted_user_ids.add(uid)
    else:
        target_label = (payload.get("target_label") or "Authorized Institutional Link").strip()
        rows = await exec_sql(
            "SELECT public.sp_share_whiteboard(%s::UUID, %s::UUID, %s::UUID, 'link', NULL, %s::TEXT, %s::TEXT, %s::TIMESTAMPTZ) AS share;",
            (whiteboard_id, school_id, user["id"], target_label, access_level, expires_at),
        )
        if rows and rows[0].get("share"):
            created_shares.append(rows[0]["share"])

    for uid in granted_user_ids:
        await _upsert_shared_user_permission(
            whiteboard_id=whiteboard_id,
            school_id=school_id,
            granter_id=user["id"],
            target_user_id=uid,
            access_level=access_level,
            capabilities=capabilities,
        )

    if granted_user_ids:
        await whiteboard_ws_manager.broadcast_event(
            whiteboard_id=whiteboard_id,
            institution_id=school_id,
            session_id=None,
            user_id=user["id"],
            event_type="permission.changed",
            payload={"shared_user_count": len(granted_user_ids), "access_level": access_level},
        )

    return {
        "success": True,
        "data": {
            "shares": created_shares,
            "granted_users_count": len(granted_user_ids),
        },
    }


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
    revoked_rows = await exec_sql(
        """
        UPDATE public.whiteboard_shares
        SET revoked_at = NOW()
        WHERE id = %s::UUID AND whiteboard_id = %s::UUID AND school_id = %s::UUID
        RETURNING target_id::TEXT AS target_id, share_type;
        """,
        (share_id, whiteboard_id, school_id),
    )
    if revoked_rows:
        t_id = revoked_rows[0].get("target_id")
        s_type = str(revoked_rows[0].get("share_type") or "").lower()
        if t_id and s_type in ("student", "teacher", "user"):
            remaining = await exec_sql(
                "SELECT 1 FROM public.whiteboard_shares WHERE whiteboard_id = %s::UUID AND school_id = %s::UUID AND target_id = %s::UUID AND revoked_at IS NULL LIMIT 1;",
                (whiteboard_id, school_id, t_id),
            )
            if not remaining:
                await exec_sql(
                    "DELETE FROM public.whiteboard_permissions WHERE whiteboard_id = %s::UUID AND school_id = %s::UUID AND user_id = %s::UUID;",
                    (whiteboard_id, school_id, t_id),
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
