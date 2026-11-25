"""
EduSHAMIIT – Enterprise Live Class & LiveKit Integration API
Orchestrates Join & Conduct, Recordings, Attendance Tracking, LiveKit tokens,
Egress recordings, stored procedure execution, and real-time WebSockets.
"""
import os
import io
import re
import csv
import json
import time
import uuid
import mimetypes
import httpx
from datetime import datetime, timezone
from typing import Optional, List, Dict, Any
import asyncio
from fastapi import APIRouter, Depends, HTTPException, Query, BackgroundTasks, Request, WebSocket, WebSocketDisconnect, status, Body, File, Form, UploadFile
from fastapi.responses import StreamingResponse, Response, RedirectResponse, FileResponse
from jose import jwt
import psycopg2
from psycopg2.extras import RealDictCursor, register_uuid

register_uuid()

from app.middleware.auth import get_current_user, require_school_id, require_teacher, require_student, require_any_role
from app.services.supabase_client import get_supabase
from app.services.minio_client import minio_client
from app.config import settings

# Live class host permissions: Teachers and authorized academic administrators
require_live_class_host = require_any_role(
    "teacher", "admin", "super_admin", "director", "principal", "teacher_admin", "academic_admin"
)

router = APIRouter()


# ============================================================================
# DATABASE EXECUTION HELPER FOR STORED PROCEDURES
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


def resolve_browser_livekit_url(request: Optional[Request] = None) -> str:
    """
    Resolve the browser-accessible LiveKit WebSocket URL dynamically from the request host/proto.
    """
    if request is not None:
        host_hdr = (
            request.headers.get("x-forwarded-host")
            or request.headers.get("host")
            or ""
        ).strip()
        proto = (
            request.headers.get("x-forwarded-proto")
            or request.url.scheme
            or "http"
        ).split(",")[0].strip().lower()
        host_only = host_hdr.split(":")[0].lower()

        is_local = (
            host_only in ("localhost", "127.0.0.1", "0.0.0.0")
            or host_only.startswith("192.168.")
            or host_only.startswith("10.")
            or proto == "http"
        )
        if host_hdr and is_local:
            ws_scheme = "wss" if proto == "https" else "ws"
            if ":" not in host_hdr and host_only in ("localhost", "127.0.0.1", "0.0.0.0"):
                return f"{ws_scheme}://localhost:8082"
            return f"{ws_scheme}://{host_hdr}"

    pub = os.environ.get("LIVEKIT_PUBLIC_URL")
    if pub:
        return pub
    return (
        os.environ.get("LIVEKIT_URL", "ws://localhost:8082")
        .replace("http://livekit:", "ws://localhost:")
        .replace("https://livekit:", "wss://localhost:")
        .replace("http://", "ws://")
        .replace("https://", "wss://")
    )


# ============================================================================
# 1. LIVEKIT TOKEN GENERATION
# ============================================================================

@router.get("/livekit/token")
@router.post("/livekit/token")
async def generate_livekit_token(
    request: Request,
    room: str = Query(..., description="The name of the LiveKit room"),
    identity: Optional[str] = Query(None, description="Participant identity"),
    name: Optional[str] = Query(None, description="Participant display name"),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    api_key = os.environ.get("LIVEKIT_API_KEY", "devkey")
    api_secret = os.environ.get("LIVEKIT_API_SECRET", "secretkey_edushamiit_livekit_2026_secure")
    
    if not identity:
        identity = user["id"]
    if not name:
        name = user.get("full_name", "User")
        
    role = user.get("role", "student")
    is_teacher = role in ("teacher", "admin", "teacher_admin", "superadmin")
    
    now = int(time.time())
    claims = {
        "iss": api_key,
        "sub": identity,
        "name": name,
        "video": {
            "roomJoin": True,
            "room": room,
            "canPublish": True,
            "canSubscribe": True,
            "canPublishData": True,
            "canPublishSources": ["camera", "microphone", "screen_share"],
            "canUpdateOwnMetadata": True,
            "roomAdmin": is_teacher,
            "roomCreate": is_teacher
        },
        "metadata": role,
        "nbf": now - 10,
        "exp": now + 6 * 3600  # 6 hours expiration
    }
    
    token = jwt.encode(claims, api_secret, algorithm="HS256")
    
    is_recording = False
    try:
        livekit_url = os.environ.get("LIVEKIT_URL", "http://livekit:7880")
        admin_claims = {
            "iss": api_key,
            "sub": "admin_backend",
            "video": {"roomAdmin": True},
            "exp": now + 60
        }
        admin_token = jwt.encode(admin_claims, api_secret, algorithm="HS256")
        headers = {"Authorization": f"Bearer {admin_token}", "Content-Type": "application/json"}
        async with httpx.AsyncClient() as client:
            list_resp = await client.post(
                f"{livekit_url}/twirp/livekit.Egress/ListEgress",
                headers=headers,
                json={"room_name": room},
                timeout=3.0
            )
            if list_resp.status_code == 200:
                egress_list = list_resp.json().get("items", [])
                for eg in egress_list:
                    status_val = eg.get("status")
                    if isinstance(status_val, int) and status_val in (0, 1):
                        is_recording = True
                        break
                    elif isinstance(status_val, str) and status_val in ("EGRESS_STARTING", "EGRESS_ACTIVE", "0", "1"):
                        is_recording = True
                        break
    except Exception as e:
        print(f"[LiveKit] Non-fatal check active recording error: {e}")

    return {
        "success": True,
        "token": token,
        "is_recording": is_recording,
        "room": room,
        "identity": identity,
        "name": name,
        "role": role,
        "livekit_url": resolve_browser_livekit_url(request),
    }


# ============================================================================
# 2. DASHBOARD ENDPOINTS (POWERED BY STORED PROCEDURES)
# ============================================================================

@router.get("/live-classes/dashboard/join-conduct")
async def get_join_conduct_dashboard(
    date_filter: str = Query("today"),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Fetch Join & Conduct Tab KPIs, active session, participants, and upcoming classes via SP."""
    rows = await exec_sql(
        "SELECT public.sp_get_live_classes_join_conduct_kpis(%s::UUID, %s::UUID, %s::TEXT) AS data;",
        (school_id, user.get("id"), date_filter)
    )
    if not rows or not rows[0].get("data"):
        raise HTTPException(status_code=500, detail="Failed to load Join & Conduct dashboard")
    return {"success": True, "data": rows[0]["data"]}


@router.get("/live-classes/dashboard/recordings")
async def get_recordings_dashboard(
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Fetch Recordings Tab KPIs, 30-day analytics, and storage breakdown via SP."""
    rows = await exec_sql(
        "SELECT public.sp_get_live_class_recordings_dashboard(%s::UUID) AS data;",
        (school_id,)
    )
    if not rows or not rows[0].get("data"):
        raise HTTPException(status_code=500, detail="Failed to load Recordings dashboard")
    return {"success": True, "data": rows[0]["data"]}


@router.get("/live-classes/dashboard/attendance")
async def get_attendance_dashboard(
    session_id: Optional[str] = Query(None),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Fetch Attendance Tab KPIs, selected session summary, and trend history via SP."""
    rows = await exec_sql(
        "SELECT public.sp_get_live_class_attendance_dashboard(%s::UUID, %s::UUID) AS data;",
        (school_id, session_id)
    )
    if not rows or not rows[0].get("data"):
        raise HTTPException(status_code=500, detail="Failed to load Attendance dashboard")
    return {"success": True, "data": rows[0]["data"]}


@router.get("/live-classes/meta/dropdowns")
async def get_live_class_meta_dropdowns(
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Fetch dynamic dropdown lists for Classes, Sections, Subjects, Teachers, and System Lookups."""
    rows = await exec_sql(
        "SELECT public.sp_get_live_class_meta_dropdowns(%s::UUID) AS data;",
        (school_id,)
    )
    if not rows or not rows[0].get("data"):
        raise HTTPException(status_code=500, detail="Failed to load metadata dropdowns")
    return {"success": True, "data": rows[0]["data"]}


# ============================================================================
# 3. LIVE CLASS SESSION MANAGEMENT & INSTANT CLASS CREATION
# ============================================================================

@router.post("/live-classes/sessions")
@router.post("/live-classes/sessions/instant")
async def create_instant_live_class(
    payload: Dict[str, Any],
    user=Depends(require_live_class_host),
    school_id=Depends(require_school_id),
):
    """Create an instant or scheduled live class session backed by stored procedure."""
    import json
    rows = await exec_sql(
        "SELECT public.sp_create_instant_live_class(%s::UUID, %s::UUID, %s::JSONB) AS data;",
        (school_id, user["id"], json.dumps(payload))
    )
    if not rows or not rows[0].get("data"):
        raise HTTPException(status_code=500, detail="Failed to create live class session")
    return {"success": True, "message": "Class created successfully", "data": rows[0]["data"]}


@router.get("/live-classes/my-classes/dashboard")
async def get_my_classes_dashboard(
    date_filter: str = Query("today"),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Fetch My Classes 6 KPIs, Today's Class Progress Donut, Teaching Summary, and Weekly Class Trend."""
    user_id_param = user["id"] if user.get("role", "").lower() == "teacher" else None
    rows = await exec_sql(
        "SELECT public.sp_get_live_class_my_classes_dashboard(%s::UUID, %s::UUID, %s::TEXT) AS data;",
        (school_id, user_id_param, date_filter)
    )
    if not rows or not rows[0].get("data"):
        raise HTTPException(status_code=500, detail="Failed to load My Classes dashboard")
    return {"success": True, "data": rows[0]["data"]}


@router.get("/live-classes/cascading-subjects")
async def get_cascading_academic_subjects(
    class_id: uuid.UUID = Query(...),
    section_id: Optional[uuid.UUID] = Query(None),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Fetch subjects cascaded by class and optional section using stored procedure."""
    section_id_str = str(section_id) if section_id else None
    rows = await exec_sql(
        "SELECT public.sp_get_cascading_academic_subjects(%s::UUID, %s::UUID, %s::UUID) AS data;",
        (school_id, str(class_id), section_id_str)
    )
    if not rows or not rows[0].get("data"):
        return {"success": True, "data": {"subjects": []}}
    return {"success": True, "data": rows[0]["data"]}


@router.get("/live-classes/my-classes")
@router.get("/live-classes/sessions")
async def get_live_classes_sessions(
    date_filter: str = Query("today"),
    session_name: Optional[str] = Query(None),
    class_id: Optional[str] = Query(None),
    section_id: Optional[str] = Query(None),
    subject_id: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    status_filter: Optional[str] = Query(None, alias="status"),
    search: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(5, ge=1, le=100),
    sort_by: Optional[str] = Query("scheduled_at"),
    sort_order: Optional[str] = Query("ASC"),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """List live class sessions with filtering, database sorting, and pagination via stored procedure."""
    effective_status = status or status_filter
    user_id_param = user["id"] if user.get("role", "").lower() == "teacher" else None
    rows = await exec_sql(
        "SELECT public.sp_get_live_class_my_classes_list(%s::UUID, %s::UUID, %s::TEXT, %s::TEXT, %s::UUID, %s::UUID, %s::TEXT, %s::TEXT, %s::INT, %s::INT, %s::UUID, %s::TEXT, %s::TEXT) AS data;",
        (school_id, user_id_param, date_filter, session_name, class_id, subject_id, effective_status, search, page, page_size, section_id, sort_by, sort_order)
    )
    if not rows or not rows[0].get("data"):
        return {"success": True, "data": {"items": [], "classes": [], "total_count": 0, "page": page, "page_size": page_size, "total_pages": 1}}
    return {"success": True, "data": rows[0]["data"]}


@router.get("/live-classes/sessions/{session_id}/details")
async def get_live_class_session_details(
    session_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Fetch complete class details and quick action statuses for Right Panel."""
    rows = await exec_sql(
        "SELECT public.sp_get_live_class_session_details(%s::UUID, %s::UUID) AS data;",
        (school_id, session_id)
    )
    if not rows or not rows[0].get("data"):
        raise HTTPException(status_code=404, detail="Session details not found")
    return {"success": True, "data": rows[0]["data"]}


@router.put("/live-classes/sessions/{session_id}")
async def update_live_class_session(
    session_id: str,
    payload: Dict[str, Any] = Body(...),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Update/Reschedule an existing live class session via stored procedure."""
    rows = await exec_sql(
        "SELECT public.sp_manage_live_class_crud(%s::UUID, %s::UUID, 'UPDATE', %s::UUID, %s::JSONB) AS data;",
        (school_id, user["id"], session_id, json.dumps(payload))
    )
    if not rows or not rows[0].get("data"):
        raise HTTPException(status_code=400, detail="Failed to update live class")
    return {"success": True, "data": rows[0]["data"]}


@router.delete("/live-classes/sessions/{session_id}")
async def delete_live_class_session(
    session_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Delete a live class session and associated records via stored procedure."""
    rows = await exec_sql(
        "SELECT public.sp_manage_live_class_crud(%s::UUID, %s::UUID, 'DELETE', %s::UUID, '{}'::JSONB) AS data;",
        (school_id, user["id"], session_id)
    )
    if not rows or not rows[0].get("data"):
        raise HTTPException(status_code=400, detail="Failed to delete live class")
    return {"success": True, "data": rows[0]["data"]}


@router.post("/live-classes/sessions/bulk-cancel")
async def bulk_cancel_live_classes(
    payload: Dict[str, Any] = Body(...),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Bulk cancel multiple live classes via stored procedure."""
    rows = await exec_sql(
        "SELECT public.sp_manage_live_class_crud(%s::UUID, %s::UUID, 'BULK_CANCEL', NULL, %s::JSONB) AS data;",
        (school_id, user["id"], json.dumps(payload))
    )
    if not rows or not rows[0].get("data"):
        raise HTTPException(status_code=400, detail="Failed to bulk cancel live classes")
    return {"success": True, "data": rows[0]["data"]}


@router.post("/live-classes/sessions/bulk-delete")
async def bulk_delete_live_classes(
    payload: Dict[str, Any] = Body(...),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Bulk delete multiple live classes via stored procedure."""
    rows = await exec_sql(
        "SELECT public.sp_manage_live_class_crud(%s::UUID, %s::UUID, 'BULK_DELETE', NULL, %s::JSONB) AS data;",
        (school_id, user["id"], json.dumps(payload))
    )
    if not rows or not rows[0].get("data"):
        raise HTTPException(status_code=400, detail="Failed to bulk delete live classes")
    return {"success": True, "data": rows[0]["data"]}


@router.post("/live-classes/sessions/{session_id}/duplicate")
async def duplicate_live_class_session(
    session_id: str,
    user=Depends(require_live_class_host),
    school_id=Depends(require_school_id),
):
    """Duplicate a session for next week schedule."""
    rows = await exec_sql(
        "SELECT public.sp_duplicate_live_class_session(%s::UUID, %s::UUID, %s::UUID) AS data;",
        (school_id, session_id, user["id"])
    )
    if not rows or not rows[0].get("data"):
        raise HTTPException(status_code=500, detail="Failed to duplicate session")
    return {"success": True, "data": rows[0]["data"]}


@router.post("/live-classes/sessions/{session_id}/cancel")
async def cancel_live_class_session(
    session_id: str,
    payload: Dict[str, Any] = Body(default={}),
    user=Depends(require_live_class_host),
    school_id=Depends(require_school_id),
):
    """Cancel a live class session."""
    reason = payload.get("reason", "Cancelled by instructor")
    rows = await exec_sql(
        "SELECT public.sp_cancel_live_class_session(%s::UUID, %s::UUID, %s::UUID, %s::TEXT) AS data;",
        (school_id, session_id, user["id"], reason)
    )
    if not rows or not rows[0].get("data"):
        raise HTTPException(status_code=500, detail="Failed to cancel session")
    return {"success": True, "data": rows[0]["data"]}


# ============================================================================
# 4. SESSION LIFECYCLE: START, END, EVENT (ATTENDANCE HEARTBEAT)
# ============================================================================

@router.post("/live-classes/{live_class_id}/start")
async def start_live_class(
    live_class_id: str,
    background_tasks: BackgroundTasks,
    user=Depends(require_live_class_host),
    school_id=Depends(require_school_id),
):
    """Start an authorized live class session."""
    # 1. Clean up any stale unclosed participant rows from prior runs and start fresh
    await exec_sql(
        """
        UPDATE public.live_class_participants
        SET leave_time = NOW(), last_leave_at = NOW(), updated_at = NOW()
        WHERE live_class_id = %s AND leave_time IS NULL;
        """,
        (live_class_id,),
        fetch=False
    )

    # 2. Update session status via database
    await exec_sql(
        """
        UPDATE public.live_classes
        SET status = 'live', is_live = TRUE, actual_start_at = NOW(),
            meeting_link = COALESCE(meeting_link, %s),
            recording_status = 'IDLE',
            recording_enabled = FALSE,
            viewer_count = 0,
            updated_at = NOW()
        WHERE id = %s AND school_id = %s;
        """,
        (live_class_id, live_class_id, school_id),
        fetch=False
    )

    # 2. Pre-create LiveKit room
    livekit_url = os.environ.get("LIVEKIT_URL", "http://livekit:7880")
    api_key = os.environ.get("LIVEKIT_API_KEY", "devkey")
    api_secret = os.environ.get("LIVEKIT_API_SECRET", "secretkey_edushamiit_livekit_2026_secure")
    now = int(time.time())
    admin_claims = {
        "iss": api_key,
        "sub": "admin_backend",
        "video": {"roomCreate": True, "roomAdmin": True},
        "exp": now + 600
    }
    admin_token = jwt.encode(admin_claims, api_secret, algorithm="HS256")
    try:
        async with httpx.AsyncClient() as client:
            await client.post(
                f"{livekit_url}/twirp/livekit.RoomService/CreateRoom",
                headers={"Authorization": f"Bearer {admin_token}", "Content-Type": "application/json"},
                json={"name": live_class_id, "empty_timeout": 600, "max_participants": 200},
                timeout=5.0
            )
    except Exception as e:
        print(f"[LiveKit] CreateRoom notice: {e}")

    # 3. Recording starts strictly upon manual user trigger via /live-classes/sessions/{id}/recordings/toggle
    return {"success": True, "message": "Class started successfully", "session_id": live_class_id}


@router.post("/live-classes/{live_class_id}/end")
async def end_live_class(
    live_class_id: str,
    background_tasks: BackgroundTasks,
    user=Depends(require_live_class_host),
    school_id=Depends(require_school_id),
):
    """End a live class session, calculate attendance, and finalize egress."""
    # Check recording state & start timestamp before finalizing status
    session_meta = await exec_sql(
        """
        SELECT actual_start_at, scheduled_at, COALESCE(recording_enabled, FALSE) AS recording_enabled,
               COALESCE(recording_status, 'IDLE') AS recording_status
        FROM public.live_classes
        WHERE id = %s AND school_id = %s;
        """,
        (live_class_id, school_id),
    )
    meta_row = session_meta[0] if session_meta else {}
    was_recording = bool(meta_row.get("recording_enabled")) or str(meta_row.get("recording_status", "")).upper() in ("RECORDING", "ACTIVE", "COMPLETED")
    start_ts = meta_row.get("actual_start_at") or meta_row.get("scheduled_at")
    elapsed_sec = 0
    if start_ts:
        try:
            now_utc = datetime.now(timezone.utc)
            if start_ts.tzinfo is None:
                start_ts = start_ts.replace(tzinfo=timezone.utc)
            elapsed_sec = max(60, int((now_utc - start_ts).total_seconds()))
        except Exception:
            elapsed_sec = 60

    # 1. Update session status in DB and reset active viewer_count
    await exec_sql(
        """
        UPDATE public.live_classes
        SET status = 'recorded', is_live = FALSE, actual_end_at = NOW(),
            recording_status = CASE WHEN COALESCE(recording_enabled, FALSE) OR UPPER(COALESCE(recording_status, '')) IN ('RECORDING','ACTIVE') THEN 'COMPLETED' ELSE COALESCE(recording_status, 'IDLE') END,
            viewer_count = 0, updated_at = NOW()
        WHERE id = %s AND school_id = %s;
        """,
        (live_class_id, school_id),
        fetch=False
    )

    # 1b. Close all open live_class_participants rows for this session
    await exec_sql(
        """
        UPDATE public.live_class_participants
        SET leave_time = NOW(), last_leave_at = NOW(), updated_at = NOW()
        WHERE live_class_id = %s AND leave_time IS NULL;
        """,
        (live_class_id,),
        fetch=False
    )

    # 2. Close active connection segments
    await exec_sql(
        """
        UPDATE public.live_class_connection_segments
        SET left_at = NOW(),
            duration_seconds = GREATEST(0, EXTRACT(EPOCH FROM (NOW() - joined_at))::INT)
        WHERE session_id = %s AND left_at IS NULL;
        """,
        (live_class_id,),
        fetch=False
    )

    # 3. Calculate attendance and link to institutional attendance system
    await exec_sql(
        "SELECT public.sp_auto_calculate_live_class_attendance(%s::UUID, %s::UUID);",
        (live_class_id, school_id),
        fetch=False
    )

    # 4. Finalize Egress recording synchronously/safely if recording was enabled or active
    if was_recording:
        await cleanup_room_egress_and_delete(live_class_id, elapsed_sec or 60)
    else:
        background_tasks.add_task(cleanup_room_egress_and_delete, live_class_id, elapsed_sec or 60, False)

    return {"success": True, "message": "Class ended and attendance calculated successfully"}


@router.post("/live-classes/{live_class_id}/leave")
async def student_leave_live_class(
    live_class_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Cleanly disconnect a student from a live session without ending the class for others."""
    rows = await exec_sql(
        "SELECT public.sp_student_leave_live_class(%s::UUID, %s::UUID, %s::UUID) AS data;",
        (live_class_id, user["id"], school_id)
    )
    if not rows or not rows[0].get("data"):
        return {"success": True, "message": "Left session"}
    return rows[0]["data"]


@router.post("/live-classes/watchdog/clean-stale")
async def trigger_stale_classes_watchdog(
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Scan and cleanly conclude abandoned live sessions, automatically aggregating institutional attendance."""
    rows = await exec_sql(
        "SELECT public.sp_auto_close_stale_live_classes(%s::UUID) AS data;",
        (school_id,)
    )
    data = rows[0]["data"] if rows and rows[0].get("data") else {"closed_count": 0}
    return data


@router.post("/live-classes/{live_class_id}/event")
@router.post("/live-classes/{live_class_id}/attendance/mark")
async def record_participant_event(
    live_class_id: str,
    payload: Dict[str, Any],
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """
    Accurately capture join time, leave time, disconnection segments, and heartbeats.
    """
    import json
    action = payload.get("action", "join").upper()
    event_type = "JOIN" if action == "JOIN" else "LEAVE"
    if payload.get("is_rejoin"):
        event_type = "REJOIN"

    rows = await exec_sql(
        "SELECT public.sp_record_participant_connection_event(%s::UUID, %s::UUID, %s::TEXT, NOW(), %s::JSONB) AS data;",
        (live_class_id, user["id"], event_type, json.dumps(payload))
    )
    return {"success": True, "data": rows[0]["data"] if rows else {}}


# ============================================================================
# 5. RECORDINGS MANAGEMENT APIS (UPLOAD, STREAM, DOWNLOAD, CRUD, SHARE, SETTINGS)
# ============================================================================

RECORDINGS_LOCAL_DIR = os.path.join(os.getcwd(), "assets", "recordings")
os.makedirs(RECORDINGS_LOCAL_DIR, exist_ok=True)
ALLOWED_RECORDING_EXTENSIONS = {"mp4", "webm", "mkv", "mov", "avi", "m4v", "ogv", "flv", "wmv", "mp3", "m4a"}
MAX_RECORDING_UPLOAD_BYTES = 500 * 1024 * 1024  # 500 MB


def _safe_uuid(val: Optional[str]) -> Optional[str]:
    if not val:
        return None
    try:
        return str(uuid.UUID(str(val).strip()))
    except Exception:
        return None


def _resolve_local_recording_path(rec: Dict[str, Any]) -> Optional[str]:
    """Find locally stored recording binary if present."""
    storage_key = (rec.get("storage_key") or "").strip().lstrip("/")
    if storage_key:
        candidate = os.path.join(RECORDINGS_LOCAL_DIR, storage_key.replace("/", os.sep))
        if os.path.isfile(candidate):
            return candidate
        # Also support basename in school folder
        school_id = str(rec.get("school_id") or "")
        if school_id:
            candidate2 = os.path.join(RECORDINGS_LOCAL_DIR, school_id, os.path.basename(storage_key))
            if os.path.isfile(candidate2):
                return candidate2
    rec_id = str(rec.get("id") or "")
    school_id = str(rec.get("school_id") or "")
    for ext in ALLOWED_RECORDING_EXTENSIONS:
        p1 = os.path.join(RECORDINGS_LOCAL_DIR, school_id, f"{rec_id}.{ext}")
        if os.path.isfile(p1):
            return p1
        p2 = os.path.join(RECORDINGS_LOCAL_DIR, f"{rec_id}.{ext}")
        if os.path.isfile(p2):
            return p2
    return None


def _resolve_storage_candidate_urls(rec: Dict[str, Any]) -> List[str]:
    """Build internal/public URLs to attempt when streaming/downloading from Supabase Storage."""
    urls: List[str] = []
    storage_key = (rec.get("storage_key") or "").strip().lstrip("/")
    raw_url = (rec.get("recording_url") or "").strip()
    supabase_internal = os.environ.get("SUPABASE_URL", "http://kong:8000").rstrip("/")
    storage_internal = "http://storage:5000"

    if raw_url and "/storage/v1/object/" in raw_url:
        suffix = raw_url.split("/storage/v1/object/", 1)[1].lstrip("/")
        if suffix.startswith("public/"):
            suffix_obj = suffix[len("public/"):]
            urls.append(f"{storage_internal}/object/public/{suffix_obj}")
            urls.append(f"{supabase_internal}/storage/v1/object/public/{suffix_obj}")
        else:
            urls.append(f"{storage_internal}/object/{suffix}")
            urls.append(f"{supabase_internal}/storage/v1/object/{suffix}")

    if storage_key:
        bucket = minio_client.bucket_name or "live-classes"
        urls.append(f"{storage_internal}/object/public/{bucket}/{storage_key}")
        urls.append(f"{supabase_internal}/storage/v1/object/public/{bucket}/{storage_key}")

    if raw_url.startswith("http://") or raw_url.startswith("https://"):
        if "/api/live-classes/recordings/" not in raw_url:
            urls.append(raw_url)
    return urls


async def _fetch_recording_for_school(recording_id: str, school_id: str) -> Dict[str, Any]:
    rows = await exec_sql(
        """
        SELECT r.*, c.school_id AS live_class_school_id, c.title AS live_class_title
        FROM public.live_class_recordings r
        LEFT JOIN public.live_classes c ON c.id = r.live_class_id
        WHERE r.id = %s::UUID AND r.deleted_at IS NULL
          AND COALESCE(r.school_id, c.school_id) = %s::UUID;
        """,
        (recording_id, school_id),
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Recording not found")
    return rows[0]


@router.get("/live-classes/recordings")
async def list_recordings(
    class_id: Optional[str] = Query(None),
    subject_id: Optional[str] = Query(None),
    teacher_id: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    status_filter: Optional[str] = Query(None, alias="status"),
    page: int = Query(1, ge=1),
    page_size: int = Query(8, ge=1, le=50),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Paginated recordings table."""
    rows = await exec_sql(
        "SELECT public.sp_get_live_class_recordings_list(%s::UUID, %s::UUID, %s::UUID, %s::UUID, %s::TEXT, %s::TEXT, %s::INT, %s::INT) AS data;",
        (school_id, _safe_uuid(class_id), _safe_uuid(subject_id), _safe_uuid(teacher_id), search, status_filter, page, page_size)
    )
    if not rows or not rows[0].get("data"):
        return {"success": True, "data": {"items": [], "total_count": 0, "page": page}}
    return {"success": True, "data": rows[0]["data"]}


@router.get("/live-classes/recordings/settings")
async def get_recording_settings(
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Fetch persisted recording & auto-rules settings for the school."""
    rows = await exec_sql(
        """
        SELECT auto_recording, cloud_storage, default_retention_days, recording_quality,
               allow_student_download, COALESCE(auto_rules, '{}'::jsonb) AS auto_rules, updated_at
        FROM public.live_class_recording_settings
        WHERE school_id = %s::UUID;
        """,
        (school_id,),
    )
    if rows:
        return {"success": True, "data": rows[0]}
    return {
        "success": True,
        "data": {
            "auto_recording": True,
            "cloud_storage": True,
            "default_retention_days": 180,
            "recording_quality": "HD (720p)",
            "allow_student_download": True,
            "auto_rules": {},
        },
    }


@router.post("/live-classes/recordings/settings")
@router.put("/live-classes/recordings/settings")
async def save_recording_settings(
    payload: Dict[str, Any] = Body(...),
    user=Depends(require_live_class_host),
    school_id=Depends(require_school_id),
):
    """Persist recording configuration and auto-recording rules for the school."""
    auto_recording = bool(payload.get("auto_recording", True))
    cloud_storage = bool(payload.get("cloud_storage", True))
    default_retention_days = int(payload.get("default_retention_days", 180) or 180)
    recording_quality = str(payload.get("recording_quality", "HD (720p)") or "HD (720p)")
    allow_student_download = bool(payload.get("allow_student_download", True))
    auto_rules = payload.get("auto_rules") if isinstance(payload.get("auto_rules"), dict) else {}

    rows = await exec_sql(
        """
        INSERT INTO public.live_class_recording_settings (
            school_id, auto_recording, cloud_storage, default_retention_days,
            recording_quality, allow_student_download, auto_rules, updated_by, updated_at
        ) VALUES (
            %s::UUID, %s, %s, %s, %s, %s, %s::JSONB, %s::UUID, NOW()
        )
        ON CONFLICT (school_id) DO UPDATE SET
            auto_recording = EXCLUDED.auto_recording,
            cloud_storage = EXCLUDED.cloud_storage,
            default_retention_days = EXCLUDED.default_retention_days,
            recording_quality = EXCLUDED.recording_quality,
            allow_student_download = EXCLUDED.allow_student_download,
            auto_rules = CASE
                WHEN EXCLUDED.auto_rules = '{}'::jsonb AND public.live_class_recording_settings.auto_rules IS NOT NULL
                THEN public.live_class_recording_settings.auto_rules
                ELSE EXCLUDED.auto_rules
            END,
            updated_by = EXCLUDED.updated_by,
            updated_at = NOW()
        RETURNING auto_recording, cloud_storage, default_retention_days, recording_quality,
                  allow_student_download, auto_rules, updated_at;
        """,
        (
            school_id,
            auto_recording,
            cloud_storage,
            default_retention_days,
            recording_quality,
            allow_student_download,
            json.dumps(auto_rules),
            user["id"],
        ),
    )
    return {
        "success": True,
        "message": "Recording settings saved",
        "data": rows[0] if rows else payload,
    }


@router.post("/live-classes/recordings/upload")
async def upload_recording_file(
    file: Optional[UploadFile] = File(None),
    title: str = Form(...),
    description: Optional[str] = Form(None),
    class_id: Optional[str] = Form(None),
    section_id: Optional[str] = Form(None),
    subject_id: Optional[str] = Form(None),
    teacher_id: Optional[str] = Form(None),
    teacher_name: Optional[str] = Form(None),
    live_class_id: Optional[str] = Form(None),
    duration_seconds: int = Form(0),
    duration_minutes: int = Form(0),
    visibility: str = Form("CLASS"),
    recording_type: str = Form("Uploaded Recording"),
    external_url: Optional[str] = Form(None),
    user=Depends(require_live_class_host),
    school_id=Depends(require_school_id),
):
    """Upload a real local video/media recording and persist metadata + storage."""
    clean_title = (title or "").strip()
    if not clean_title:
        raise HTTPException(status_code=400, detail="Recording title is required")

    rec_id = str(uuid.uuid4())
    file_size = 0
    mime_type = "video/mp4"
    storage_key = None
    storage_provider = "local"
    saved_url = f"/api/live-classes/recordings/{rec_id}/stream"

    if file is not None and file.filename:
        safe_name = os.path.basename(file.filename)
        ext = safe_name.rsplit(".", 1)[-1].lower() if "." in safe_name else "mp4"
        if ext not in ALLOWED_RECORDING_EXTENSIONS:
            raise HTTPException(status_code=400, detail=f"Unsupported media format '.{ext}'")

        mime_type = file.content_type or mimetypes.guess_type(safe_name)[0] or "video/mp4"
        rel_key = f"{school_id}/{rec_id}.{ext}"
        school_dir = os.path.join(RECORDINGS_LOCAL_DIR, str(school_id))
        os.makedirs(school_dir, exist_ok=True)
        local_path = os.path.join(school_dir, f"{rec_id}.{ext}")

        total_read = 0
        try:
            with open(local_path, "wb") as out_f:
                while True:
                    chunk = await file.read(1024 * 1024)
                    if not chunk:
                        break
                    total_read += len(chunk)
                    if total_read > MAX_RECORDING_UPLOAD_BYTES:
                        out_f.close()
                        os.remove(local_path)
                        raise HTTPException(status_code=413, detail="Recording exceeds maximum size of 500 MB")
                    out_f.write(chunk)
        except HTTPException:
            raise
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Failed to store video file: {e}")

        if total_read == 0:
            if os.path.exists(local_path):
                os.remove(local_path)
            raise HTTPException(status_code=400, detail="Uploaded video file is empty")

        file_size = total_read
        storage_key = rel_key

        # Mirror to S3 / Supabase Storage best-effort when <= 100 MB
        if total_read <= 100 * 1024 * 1024 and minio_client.s3:
            try:
                minio_client.ensure_bucket_and_public_policy()
                with open(local_path, "rb") as f_in:
                    minio_client.s3.put_object(
                        Bucket=minio_client.bucket_name,
                        Key=rel_key,
                        Body=f_in,
                        ContentType=mime_type,
                    )
                storage_provider = "hybrid"
            except Exception as e:
                print(f"[Recordings] S3 mirror skipped (local stream active): {e}")
    elif external_url and external_url.strip():
        saved_url = external_url.strip()
        storage_provider = "external"
    else:
        raise HTTPException(status_code=400, detail="Please attach a video file or provide a valid video URL")

    final_duration_sec = duration_seconds if duration_seconds > 0 else max(60, (duration_minutes or 1) * 60)
    vis_upper = (visibility or "CLASS").strip().upper()
    if vis_upper not in ("CLASS", "SCHOOL", "SHARED", "PRIVATE"):
        vis_upper = "CLASS"

    tags_list = ["upload"]
    if vis_upper in ("SCHOOL", "SHARED"):
        tags_list.append("shared")
    elif vis_upper == "PRIVATE":
        tags_list.append("private")
    else:
        tags_list.append("class_only")

    resolved_teacher_id = _safe_uuid(teacher_id) or str(user["id"])
    resolved_teacher_name = (teacher_name or user.get("full_name") or "Teacher").strip()

    await exec_sql(
        """
        INSERT INTO public.live_class_recordings (
            id, live_class_id, school_id, class_id, section_id, subject_id,
            teacher_id, teacher_name, title, description, recording_url,
            storage_provider, storage_key, mime_type, duration, file_size,
            processing_status, visibility, recording_type, tags,
            created_by, updated_by, uploaded_by
        ) VALUES (
            %s::UUID, %s::UUID, %s::UUID, %s::UUID, %s::UUID, %s::UUID,
            %s::UUID, %s, %s, %s, %s,
            %s, %s, %s, %s, %s,
            'Processed', %s, %s, %s::JSONB,
            %s::UUID, %s::UUID, %s::UUID
        );
        """,
        (
            rec_id,
            _safe_uuid(live_class_id),
            school_id,
            _safe_uuid(class_id),
            _safe_uuid(section_id),
            _safe_uuid(subject_id),
            resolved_teacher_id,
            resolved_teacher_name,
            clean_title,
            (description or "").strip() or None,
            saved_url,
            storage_provider,
            storage_key,
            mime_type,
            final_duration_sec,
            file_size,
            vis_upper,
            recording_type or "Uploaded Recording",
            json.dumps(tags_list),
            user["id"],
            user["id"],
            user["id"],
        ),
        fetch=False,
    )

    # Fetch rich formatted record back from SP
    rows = await exec_sql(
        "SELECT public.sp_get_live_class_recordings_list(%s::UUID, NULL, NULL, NULL, %s::TEXT, NULL, 1, 10) AS data;",
        (school_id, clean_title),
    )
    items = (rows[0].get("data") or {}).get("items", []) if rows else []
    created_item = next((i for i in items if str(i.get("id")) == rec_id), None)
    return {
        "success": True,
        "message": "Recording uploaded and published successfully",
        "data": created_item or {"id": rec_id, "title": clean_title, "recording_url": saved_url},
    }


@router.post("/live-classes/recordings/bulk-delete")
async def bulk_delete_recordings(
    payload: Dict[str, Any] = Body(...),
    user=Depends(require_live_class_host),
    school_id=Depends(require_school_id),
):
    """Bulk soft-delete recordings for this school."""
    raw_ids = payload.get("recording_ids") or payload.get("ids") or []
    valid_ids = [uid for uid in (_safe_uuid(x) for x in raw_ids) if uid]
    if not valid_ids:
        raise HTTPException(status_code=400, detail="No valid recording IDs supplied")

    rows = await exec_sql(
        """
        SELECT r.id::TEXT AS id, r.storage_key, COALESCE(r.school_id, c.school_id)::TEXT AS school_id
        FROM public.live_class_recordings r
        LEFT JOIN public.live_classes c ON c.id = r.live_class_id
        WHERE r.id = ANY(%s::UUID[]) AND COALESCE(r.school_id, c.school_id) = %s::UUID AND r.deleted_at IS NULL;
        """,
        (valid_ids, school_id),
    )
    await exec_sql(
        """
        UPDATE public.live_class_recordings
        SET deleted_at = NOW(), updated_by = %s::UUID, updated_at = NOW()
        WHERE id = ANY(%s::UUID[]) AND COALESCE(school_id, %s::UUID) = %s::UUID;
        """,
        (user["id"], valid_ids, school_id, school_id),
        fetch=False,
    )
    for row in rows:
        local_path = _resolve_local_recording_path(row)
        if local_path and os.path.isfile(local_path):
            try:
                os.remove(local_path)
            except Exception:
                pass
    return {"success": True, "deleted_count": len(rows), "message": f"Deleted {len(rows)} recording(s)"}


@router.get("/live-classes/recordings/{recording_id}")
async def get_recording(
    recording_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Get single recording details."""
    rec = await _fetch_recording_for_school(recording_id, school_id)
    return {"success": True, "data": rec}


@router.patch("/live-classes/recordings/{recording_id}")
@router.put("/live-classes/recordings/{recording_id}")
async def update_recording(
    recording_id: str,
    payload: Dict[str, Any] = Body(...),
    user=Depends(require_live_class_host),
    school_id=Depends(require_school_id),
):
    """Update recording title, description, class/section/subject mapping, and audience visibility."""
    rec = await _fetch_recording_for_school(recording_id, school_id)

    new_title = (payload.get("title") if "title" in payload else rec.get("title") or "").strip()
    if not new_title:
        raise HTTPException(status_code=400, detail="Recording title cannot be empty")

    new_desc = payload.get("description") if "description" in payload else rec.get("description")
    new_class_id = _safe_uuid(payload.get("class_id")) if "class_id" in payload else (str(rec["class_id"]) if rec.get("class_id") else None)
    new_section_id = _safe_uuid(payload.get("section_id")) if "section_id" in payload else (str(rec["section_id"]) if rec.get("section_id") else None)
    new_subject_id = _safe_uuid(payload.get("subject_id")) if "subject_id" in payload else (str(rec["subject_id"]) if rec.get("subject_id") else None)
    new_teacher_name = (payload.get("teacher_name") if "teacher_name" in payload else rec.get("teacher_name"))
    new_vis = str(payload.get("visibility") if "visibility" in payload else rec.get("visibility") or "CLASS").upper()
    if new_vis not in ("CLASS", "SCHOOL", "SHARED", "PRIVATE"):
        new_vis = "CLASS"

    new_duration = rec.get("duration") or 0
    if "duration_minutes" in payload and payload["duration_minutes"] is not None:
        new_duration = max(60, int(payload["duration_minutes"]) * 60)
    elif "duration_seconds" in payload and payload["duration_seconds"] is not None:
        new_duration = max(1, int(payload["duration_seconds"]))

    existing_tags = rec.get("tags") if isinstance(rec.get("tags"), list) else []
    cleaned_tags = [t for t in existing_tags if t not in ("shared", "class_only", "private")]
    if new_vis in ("SCHOOL", "SHARED"):
        cleaned_tags.append("shared")
    elif new_vis == "PRIVATE":
        cleaned_tags.append("private")
    else:
        cleaned_tags.append("class_only")

    await exec_sql(
        """
        UPDATE public.live_class_recordings
        SET title = %s,
            description = %s,
            class_id = %s::UUID,
            section_id = %s::UUID,
            subject_id = %s::UUID,
            teacher_name = %s,
            visibility = %s,
            duration = %s,
            tags = %s::JSONB,
            updated_by = %s::UUID,
            updated_at = NOW()
        WHERE id = %s::UUID;
        """,
        (
            new_title,
            new_desc,
            new_class_id,
            new_section_id,
            new_subject_id,
            new_teacher_name,
            new_vis,
            new_duration,
            json.dumps(cleaned_tags),
            user["id"],
            recording_id,
        ),
        fetch=False,
    )

    updated = await _fetch_recording_for_school(recording_id, school_id)
    return {"success": True, "message": "Recording updated successfully", "data": updated}


@router.get("/live-classes/recordings/{recording_id}/stream")
async def stream_recording(
    recording_id: str,
    request: Request,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Stream recording with HTTP 206 Partial Content Range support for HTML5 playback & seeking."""
    rec = await _fetch_recording_for_school(recording_id, school_id)
    mime = rec.get("mime_type") or "video/mp4"
    local_path = _resolve_local_recording_path(rec)

    if local_path and os.path.isfile(local_path):
        file_size = os.path.getsize(local_path)
        range_header = request.headers.get("range")
        if range_header:
            match = re.match(r"bytes=(\d+)-(\d*)", range_header.strip())
            if match:
                start = int(match.group(1))
                end = int(match.group(2)) if match.group(2) else min(start + (2 * 1024 * 1024) - 1, file_size - 1)
                end = min(end, file_size - 1)
                if start >= file_size or start > end:
                    return Response(status_code=416, headers={"Content-Range": f"bytes */{file_size}"})
                chunk_len = end - start + 1

                def _iter_range():
                    with open(local_path, "rb") as f:
                        f.seek(start)
                        remaining = chunk_len
                        while remaining > 0:
                            data = f.read(min(262144, remaining))
                            if not data:
                                break
                            remaining -= len(data)
                            yield data

                return StreamingResponse(
                    _iter_range(),
                    status_code=206,
                    media_type=mime,
                    headers={
                        "Content-Range": f"bytes {start}-{end}/{file_size}",
                        "Accept-Ranges": "bytes",
                        "Content-Length": str(chunk_len),
                        "Access-Control-Expose-Headers": "Content-Range, Accept-Ranges, Content-Length",
                        "Cache-Control": "no-cache",
                    },
                )

        def _iter_full():
            with open(local_path, "rb") as f:
                while True:
                    data = f.read(524288)
                    if not data:
                        break
                    yield data

        return StreamingResponse(
            _iter_full(),
            status_code=200,
            media_type=mime,
            headers={
                "Accept-Ranges": "bytes",
                "Content-Length": str(file_size),
                "Access-Control-Expose-Headers": "Content-Range, Accept-Ranges, Content-Length",
            },
        )

    # Proxy from storage service or redirect if external URL
    for target_url in _resolve_storage_candidate_urls(rec):
        if target_url.startswith("http") and "storage" in target_url:
            fwd_headers = {}
            if request.headers.get("range"):
                fwd_headers["Range"] = request.headers["range"]
            try:
                async with httpx.AsyncClient(timeout=15.0) as client:
                    upstream = await client.get(target_url, headers=fwd_headers)
                    if upstream.status_code in (200, 206):
                        resp_headers = {"Accept-Ranges": "bytes"}
                        for h in ("Content-Range", "Content-Length", "Content-Type"):
                            if h in upstream.headers:
                                resp_headers[h] = upstream.headers[h]
                        resp_headers["Access-Control-Expose-Headers"] = "Content-Range, Accept-Ranges, Content-Length"
                        return Response(
                            content=upstream.content,
                            status_code=upstream.status_code,
                            media_type=upstream.headers.get("content-type", mime),
                            headers=resp_headers,
                        )
            except Exception:
                continue
        elif target_url.startswith("http://") or target_url.startswith("https://"):
            return RedirectResponse(url=target_url, status_code=307)

    raise HTTPException(status_code=404, detail="Video binary is not available for this recording")


@router.get("/live-classes/recordings/{recording_id}/download")
async def download_recording(
    recording_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Download recording file, enforce student policy, increment downloads_count, and log event."""
    rec = await _fetch_recording_for_school(recording_id, school_id)

    if str(user.get("role", "")).lower() == "student":
        cfg_rows = await exec_sql(
            "SELECT allow_student_download FROM public.live_class_recording_settings WHERE school_id = %s::UUID;",
            (school_id,),
        )
        if cfg_rows and cfg_rows[0].get("allow_student_download") is False:
            raise HTTPException(status_code=403, detail="Downloads are currently disabled for students by administrator policy")

    raw_title = (rec.get("title") or "recording").strip()
    safe_base = re.sub(r'[^a-zA-Z0-9_\-\s\.]+', '', raw_title).strip().replace(" ", "_") or "recording"
    mime = rec.get("mime_type") or "video/mp4"
    storage_key = rec.get("storage_key") or ""
    ext = storage_key.rsplit(".", 1)[-1].lower() if "." in storage_key else "mp4"
    filename = f"{safe_base}.{ext}" if not safe_base.lower().endswith(f".{ext}") else safe_base

    local_path = _resolve_local_recording_path(rec)
    content_bytes: Optional[bytes] = None
    if local_path and os.path.isfile(local_path):
        await exec_sql(
            "UPDATE public.live_class_recordings SET downloads_count = COALESCE(downloads_count, 0) + 1, updated_at = NOW() WHERE id = %s::UUID;",
            (recording_id,),
            fetch=False,
        )
        await exec_sql(
            "INSERT INTO public.live_class_recording_events (recording_id, school_id, user_id, event_type) VALUES (%s::UUID, %s::UUID, %s::UUID, 'download');",
            (recording_id, school_id, user["id"]),
            fetch=False,
        )
        return FileResponse(
            path=local_path,
            media_type=mime,
            filename=filename,
            headers={"Access-Control-Expose-Headers": "Content-Disposition"},
        )

    for target_url in _resolve_storage_candidate_urls(rec):
        try:
            async with httpx.AsyncClient(timeout=20.0) as client:
                upstream = await client.get(target_url)
                if upstream.status_code == 200:
                    content_bytes = upstream.content
                    break
        except Exception:
            continue

    if content_bytes is not None:
        await exec_sql(
            "UPDATE public.live_class_recordings SET downloads_count = COALESCE(downloads_count, 0) + 1, updated_at = NOW() WHERE id = %s::UUID;",
            (recording_id,),
            fetch=False,
        )
        await exec_sql(
            "INSERT INTO public.live_class_recording_events (recording_id, school_id, user_id, event_type) VALUES (%s::UUID, %s::UUID, %s::UUID, 'download');",
            (recording_id, school_id, user["id"]),
            fetch=False,
        )
        return Response(
            content=content_bytes,
            media_type=mime,
            headers={
                "Content-Disposition": f'attachment; filename="{filename}"',
                "Access-Control-Expose-Headers": "Content-Disposition",
            },
        )

    raise HTTPException(status_code=404, detail="No downloadable video file found for this recording")


@router.post("/live-classes/recordings/{recording_id}/view")
async def record_recording_view(
    recording_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Increment views_count and log analytics event when a recording is played."""
    await _fetch_recording_for_school(recording_id, school_id)
    rows = await exec_sql(
        """
        UPDATE public.live_class_recordings
        SET views_count = COALESCE(views_count, 0) + 1, updated_at = NOW()
        WHERE id = %s::UUID
        RETURNING views_count;
        """,
        (recording_id,),
    )
    await exec_sql(
        "INSERT INTO public.live_class_recording_events (recording_id, school_id, user_id, event_type) VALUES (%s::UUID, %s::UUID, %s::UUID, 'view');",
        (recording_id, school_id, user["id"]),
        fetch=False,
    )
    return {"success": True, "views": rows[0]["views_count"] if rows else 1}


@router.delete("/live-classes/recordings/{recording_id}")
async def delete_recording(
    recording_id: str,
    user=Depends(require_live_class_host),
    school_id=Depends(require_school_id),
):
    """Soft delete recording record and remove local binary if present."""
    rec = await _fetch_recording_for_school(recording_id, school_id)
    await exec_sql(
        "UPDATE public.live_class_recordings SET deleted_at = NOW(), updated_by = %s::UUID, updated_at = NOW() WHERE id = %s::UUID;",
        (user["id"], recording_id),
        fetch=False,
    )
    local_path = _resolve_local_recording_path(rec)
    if local_path and os.path.isfile(local_path):
        try:
            os.remove(local_path)
        except Exception:
            pass
    if rec.get("storage_key") and minio_client.s3:
        try:
            minio_client.delete_file(rec["storage_key"])
        except Exception:
            pass
    return {"success": True, "message": "Recording deleted successfully"}


@router.get("/live-classes/recordings/{recording_id}/shares")
async def list_recording_shares(
    recording_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """List all active Class/Section/Individual shares for a recording."""
    await _fetch_recording_for_school(recording_id, school_id)
    rows = await exec_sql(
        """
        SELECT id::TEXT AS id, recording_id::TEXT AS recording_id, target_type,
               target_id::TEXT AS target_id, target_label, access_level,
               capabilities, created_at, expires_at
        FROM public.live_class_recording_shares
        WHERE recording_id = %s::UUID AND school_id = %s::UUID
        ORDER BY created_at DESC;
        """,
        (recording_id, school_id),
    )
    return {"success": True, "data": rows}


@router.delete("/live-classes/recordings/{recording_id}/shares/{share_id}")
async def revoke_recording_share(
    recording_id: str,
    share_id: str,
    user=Depends(require_live_class_host),
    school_id=Depends(require_school_id),
):
    """Revoke a specific recording share entry and refresh shared_count."""
    await _fetch_recording_for_school(recording_id, school_id)
    await exec_sql(
        "DELETE FROM public.live_class_recording_shares WHERE id = %s::UUID AND recording_id = %s::UUID AND school_id = %s::UUID;",
        (share_id, recording_id, school_id),
        fetch=False,
    )
    cnt_rows = await exec_sql(
        "SELECT COUNT(*)::INT AS cnt FROM public.live_class_recording_shares WHERE recording_id = %s::UUID;",
        (recording_id,),
    )
    cnt = cnt_rows[0]["cnt"] if cnt_rows else 0
    await exec_sql(
        "UPDATE public.live_class_recordings SET shared_count = %s, updated_at = NOW() WHERE id = %s::UUID;",
        (cnt, recording_id),
        fetch=False,
    )
    return {"success": True, "shared_count": cnt, "message": "Share revoked"}


@router.post("/live-classes/recordings/{recording_id}/share/batch")
async def share_recording_batch(
    recording_id: str,
    payload: Dict[str, Any] = Body(...),
    user=Depends(require_live_class_host),
    school_id=Depends(require_school_id),
):
    """Share recording with Class/Multiple Sections (Students/Teachers) OR Multiple Searched Individuals."""
    rec = await _fetch_recording_for_school(recording_id, school_id)

    mode = str(payload.get("mode", "individual")).lower()
    access_level = str(payload.get("access_level", "VIEW")).upper()
    if access_level not in ("VIEW", "DOWNLOAD", "MANAGE"):
        access_level = "VIEW"
    capabilities = payload.get("capabilities") if isinstance(payload.get("capabilities"), dict) else {}
    expires_at = payload.get("expires_at")

    created_shares: List[Dict[str, Any]] = []
    granted_user_ids: set = set()

    async def _upsert_share(target_type: str, target_id: Optional[str], target_label: str):
        rows = await exec_sql(
            """
            INSERT INTO public.live_class_recording_shares (
                recording_id, school_id, shared_by, target_type, target_id,
                target_label, access_level, capabilities, expires_at
            ) VALUES (
                %s::UUID, %s::UUID, %s::UUID, %s, %s::UUID, %s, %s, %s::JSONB, %s::TIMESTAMPTZ
            )
            ON CONFLICT (recording_id, target_type, COALESCE(target_id, '00000000-0000-0000-0000-000000000000'::uuid), target_label)
            DO UPDATE SET
                access_level = EXCLUDED.access_level,
                capabilities = EXCLUDED.capabilities,
                expires_at = EXCLUDED.expires_at,
                shared_by = EXCLUDED.shared_by,
                updated_at = NOW()
            RETURNING id::TEXT AS id, recording_id::TEXT AS recording_id, target_type,
                      target_id::TEXT AS target_id, target_label, access_level, capabilities, created_at;
            """,
            (
                recording_id,
                school_id,
                user["id"],
                target_type,
                _safe_uuid(target_id),
                target_label,
                access_level,
                json.dumps(capabilities),
                expires_at,
            ),
        )
        if rows:
            created_shares.append(rows[0])

    if mode == "class_sections":
        class_id = _safe_uuid(payload.get("class_id"))
        class_name = (payload.get("class_name") or "Class").strip()
        sections = payload.get("sections") or []
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
                sec_id = _safe_uuid(sec.get("id"))
                sec_name = (sec.get("name") or "Section").strip()
                label = f"{class_name} - {sec_name}{audience_suffix}"
                await _upsert_share("section", sec_id, label)
        elif class_id:
            await _upsert_share("class", class_id, f"{class_name} (All Sections){audience_suffix}")
        else:
            raise HTTPException(status_code=400, detail="Select at least one Class or Section")

        for u in explicit_users:
            uid = _safe_uuid(u.get("id"))
            if uid:
                granted_user_ids.add(uid)
                if payload.get("persist_individual_rows"):
                    u_label = (u.get("full_name") or "User").strip()
                    await _upsert_share("user", uid, u_label)

        if not granted_user_ids and class_id:
            sec_ids = [s for s in (_safe_uuid(sec.get("id")) for sec in sections) if s]
            if include_students:
                stu_sql = """
                    SELECT DISTINCT student_id::TEXT AS uid
                    FROM public.student_class_assignments
                    WHERE school_id = %s::UUID AND class_id = %s::UUID AND UPPER(COALESCE(status, 'ACTIVE')) = 'ACTIVE'
                """
                stu_params: List[Any] = [school_id, class_id]
                if sec_ids:
                    stu_sql += " AND section_id = ANY(%s::UUID[])"
                    stu_params.append(sec_ids)
                for r in await exec_sql(stu_sql + ";", tuple(stu_params)):
                    if r.get("uid"):
                        granted_user_ids.add(r["uid"])
            if include_teachers:
                no_sec = len(sec_ids) == 0
                for r in await exec_sql(
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
                    (school_id, class_id, no_sec, sec_ids, school_id, class_id, no_sec, sec_ids),
                ):
                    if r.get("uid"):
                        granted_user_ids.add(r["uid"])
    elif mode == "individual":
        users_list = payload.get("users") or []
        if not users_list:
            raise HTTPException(status_code=400, detail="Select at least one student or teacher")
        for u in users_list:
            uid = _safe_uuid(u.get("id"))
            u_name = (u.get("full_name") or "Member").strip()
            u_role = (u.get("role") or "").strip()
            label = f"{u_name} ({u_role})" if u_role else u_name
            if uid:
                granted_user_ids.add(uid)
            await _upsert_share("user", uid, label)
    else:
        target_label = (payload.get("target_label") or "Shared Audience").strip()
        await _upsert_share(mode, _safe_uuid(payload.get("target_id")), target_label)

    # Mark recording shared & update count so 'Shared' scope immediately reflects it
    cnt_rows = await exec_sql(
        "SELECT COUNT(*)::INT AS cnt FROM public.live_class_recording_shares WHERE recording_id = %s::UUID;",
        (recording_id,),
    )
    cnt = cnt_rows[0]["cnt"] if cnt_rows else len(created_shares)
    existing_tags = rec.get("tags") if isinstance(rec.get("tags"), list) else []
    if "shared" not in existing_tags:
        existing_tags = [*existing_tags, "shared"]
    new_vis = "SCHOOL" if (rec.get("visibility") == "PRIVATE") else (rec.get("visibility") or "SHARED")

    await exec_sql(
        """
        UPDATE public.live_class_recordings
        SET shared_count = %s,
            tags = %s::JSONB,
            visibility = %s,
            updated_at = NOW()
        WHERE id = %s::UUID;
        """,
        (cnt, json.dumps(existing_tags), new_vis, recording_id),
        fetch=False,
    )

    return {
        "success": True,
        "message": f"Shared with {len(created_shares)} target(s) ({len(granted_user_ids)} member(s))",
        "data": {
            "shares": created_shares,
            "shared_count": cnt,
            "granted_member_count": len(granted_user_ids),
        },
    }


@router.post("/live-classes/{live_class_id}/share")
@router.post("/live-classes/recordings/{recording_id}/share")
async def share_recording(
    live_class_id: Optional[str] = None,
    recording_id: Optional[str] = None,
    payload: Optional[Dict[str, Any]] = None,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Legacy compatible share endpoint routed cleanly into live_class_recording_shares."""
    target_rec_id = _safe_uuid(recording_id)
    if not target_rec_id and _safe_uuid(live_class_id):
        r = await exec_sql(
            "SELECT id::TEXT AS id FROM public.live_class_recordings WHERE live_class_id = %s::UUID AND deleted_at IS NULL LIMIT 1;",
            (_safe_uuid(live_class_id),),
        )
        if r:
            target_rec_id = r[0]["id"]
    if target_rec_id:
        shared_to = (payload or {}).get("shared_to_id") or "All Students"
        access_level = str((payload or {}).get("access_level") or "VIEW").upper()
        await share_recording_batch(
            recording_id=target_rec_id,
            payload={
                "mode": "individual" if _safe_uuid(shared_to) else "role",
                "target_label": shared_to,
                "access_level": access_level,
                "users": [{"id": shared_to, "full_name": shared_to}] if _safe_uuid(shared_to) else [],
            },
            user=user,
            school_id=school_id,
        )
    return {"success": True, "message": "Recording shared successfully"}


# ============================================================================
# 6. ATTENDANCE MANAGEMENT & MANUAL OVERRIDE
# ============================================================================

@router.get("/live-classes/attendance")
@router.get("/live-classes/{live_class_id}/attendance")
async def list_live_class_attendance(
    live_class_id: Optional[str] = None,
    session_id: Optional[str] = Query(None),
    status_filter: Optional[str] = Query(None, alias="status"),
    search: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Paginated attendance table with status chips and search matching Image 3."""
    target_id = live_class_id or session_id
    rows = await exec_sql(
        "SELECT public.sp_get_live_class_attendance_list(%s::UUID, %s::UUID, %s::TEXT, %s::TEXT, %s::INT, %s::INT) AS data;",
        (school_id, target_id, status_filter, search, page, page_size)
    )
    if not rows or not rows[0].get("data"):
        return {"success": True, "data": {"items": [], "total_count": 0, "counts": {}}}
    return {"success": True, "data": rows[0]["data"]}


@router.post("/live-classes/attendance/{attendance_id}/override")
async def override_attendance_status(
    attendance_id: str,
    payload: Dict[str, Any],
    user=Depends(require_live_class_host),
    school_id=Depends(require_school_id),
):
    """Teacher/Admin manual attendance correction with reason and audit trail."""
    new_status = payload.get("new_status")
    reason = payload.get("reason", "Teacher manual verification")
    if not new_status:
        raise HTTPException(status_code=400, detail="new_status is required")

    rows = await exec_sql(
        "SELECT public.sp_manual_override_live_attendance(%s::UUID, %s::UUID, %s::TEXT, %s::TEXT, %s::UUID) AS data;",
        (school_id, attendance_id, new_status, reason, user["id"])
    )
    return {"success": True, "data": rows[0]["data"] if rows else {}}


@router.post("/live-classes/{live_class_id}/attendance/calculate")
async def recalculate_attendance(
    live_class_id: str,
    user=Depends(require_live_class_host),
    school_id=Depends(require_school_id),
):
    """Recalculate attendance from connection segments."""
    rows = await exec_sql(
        "SELECT public.sp_auto_calculate_live_class_attendance(%s::UUID, %s::UUID) AS data;",
        (live_class_id, school_id)
    )
    return {"success": True, "data": rows[0]["data"] if rows else {}}


@router.get("/live-classes/attendance/export")
async def export_attendance_csv(
    session_id: Optional[str] = Query(None),
    user=Depends(require_live_class_host),
    school_id=Depends(require_school_id),
):
    """Export attendance data to CSV."""
    rows = await exec_sql(
        "SELECT public.sp_get_live_class_attendance_list(%s::UUID, %s::UUID, NULL, NULL, 1, 1000) AS data;",
        (school_id, session_id)
    )
    items = rows[0]["data"].get("items", []) if rows and rows[0].get("data") else []

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["Roll No", "Student Name", "Status", "Join Time", "Leave Time", "Duration", "Participation %", "Remarks"])
    for it in items:
        writer.writerow([
            it.get("roll_no"), it.get("student_name"), it.get("status"),
            it.get("join_time"), it.get("leave_time"), it.get("duration"),
            f"{it.get('participation_pct')}%", it.get("remarks")
        ])

    output.seek(0)
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename=live_class_attendance_{session_id or 'export'}.csv"}
    )


# ============================================================================
# 7. CHAT & Q&A
# ============================================================================

@router.post("/live-classes/{live_class_id}/chat")
async def send_chat_message(
    live_class_id: str,
    payload: Dict[str, Any],
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    message = payload.get("message")
    if not message:
        raise HTTPException(status_code=400, detail="message is required")

    await exec_sql(
        "INSERT INTO public.live_class_chats (live_class_id, sender_id, message) VALUES (%s, %s, %s);",
        (live_class_id, user["id"], message),
        fetch=False
    )
    return {"success": True, "message": "Chat sent"}


@router.get("/live-classes/{live_class_id}/chat")
async def get_chat_history(
    live_class_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    rows = await exec_sql(
        """
        SELECT c.id, c.live_class_id, c.sender_id, c.message, c.created_at,
               p.full_name as sender_name, p.role as sender_role
        FROM public.live_class_chats c
        JOIN public.profiles p ON p.id = c.sender_id
        WHERE c.live_class_id = %s
        ORDER BY c.created_at ASC;
        """,
        (live_class_id,)
    )
    return {"success": True, "data": {"chats": rows}}


# ============================================================================
# 8. EGRESS RECORDING BACKGROUND HELPERS
# ============================================================================

async def initiate_room_egress(room_name: str):
    livekit_url = os.environ.get("LIVEKIT_URL", "http://livekit:7880")
    api_key = os.environ.get("LIVEKIT_API_KEY", "devkey")
    api_secret = os.environ.get("LIVEKIT_API_SECRET", "secretkey_edushamiit_livekit_2026_secure")
    
    print(f"[Egress] Starting room composite egress for room: {room_name}")
    await asyncio.sleep(8)
    
    now = int(time.time())
    admin_claims = {
        "iss": api_key,
        "sub": "admin_backend",
        "video": {"roomRecord": True, "roomAdmin": True},
        "exp": now + 600
    }
    admin_token = jwt.encode(admin_claims, api_secret, algorithm="HS256")
    payload = {
        "room_name": room_name,
        "layout": "speaker",
        "audio_only": False,
        "video_only": False,
        "file": {
            "filepath": f"{room_name}.mp4",
            "output": {"s3": {}},
            "disable_manifest": True
        },
        "advanced": {
            "width": 1280,
            "height": 720,
            "framerate": 30,
            "audio_bitrate": 128,
            "video_bitrate": 3000,
            "video_codec": "H264"
        }
    }
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"{livekit_url}/twirp/livekit.Egress/StartRoomCompositeEgress",
                headers={"Authorization": f"Bearer {admin_token}", "Content-Type": "application/json"},
                json=payload,
                timeout=15.0
            )
            print(f"[Egress] Start egress status: {resp.status_code}")
    except Exception as e:
        print(f"[Egress] Exception starting egress: {e}")


async def cleanup_room_egress_and_delete(
    live_class_id: str,
    actual_duration_seconds: int,
    create_recording: bool = True,
    delete_room: bool = True,
):
    livekit_url = os.environ.get("LIVEKIT_URL", "http://livekit:7880")
    api_key = os.environ.get("LIVEKIT_API_KEY", "devkey")
    api_secret = os.environ.get("LIVEKIT_API_SECRET", "secretkey_edushamiit_livekit_2026_secure")
    
    now = int(time.time())
    admin_claims = {
        "iss": api_key,
        "sub": "admin_backend",
        "video": {"roomCreate": True, "roomAdmin": True, "roomRecord": True},
        "exp": now + 600
    }
    admin_token = jwt.encode(admin_claims, api_secret, algorithm="HS256")
    headers = {"Authorization": f"Bearer {admin_token}", "Content-Type": "application/json"}
    
    try:
        async with httpx.AsyncClient() as client:
            # Stop egress
            list_resp = await client.post(
                f"{livekit_url}/twirp/livekit.Egress/ListEgress",
                headers=headers,
                json={"room_name": live_class_id},
                timeout=5.0
            )
            if list_resp.status_code == 200:
                for eg in list_resp.json().get("items", []):
                    eg_id = eg.get("egress_id")
                    if eg_id:
                        await client.post(
                            f"{livekit_url}/twirp/livekit.Egress/StopEgress",
                            headers=headers,
                            json={"egress_id": eg_id},
                            timeout=5.0
                        )
            # Delete room only when ending the live class
            if delete_room:
                await client.post(
                    f"{livekit_url}/twirp/livekit.RoomService/DeleteRoom",
                    headers=headers,
                    json={"room": live_class_id},
                    timeout=5.0
                )
    except Exception as e:
        print(f"[LiveKit] Cleanup error: {e}")

    if not create_recording:
        return

    # Resolve rich live class metadata so the recording reflects the REAL Class / Subject / Session Title
    class_rows = await exec_sql(
        """
        SELECT c.id::TEXT AS id,
               c.school_id::TEXT AS school_id,
               c.class_id::TEXT AS class_id,
               c.section_id::TEXT AS section_id,
               c.subject_id::TEXT AS subject_id,
               c.teacher_id::TEXT AS teacher_id,
               c.created_by::TEXT AS created_by,
               c.title AS session_title,
               c.description,
               c.target_class,
               c.actual_start_at,
               c.actual_end_at,
               c.scheduled_at,
               ac.name AS class_name,
               sec.name AS section_name,
               s.name AS subject_name,
               p.full_name AS teacher_name
        FROM public.live_classes c
        LEFT JOIN public.academic_classes ac ON ac.id = c.class_id
        LEFT JOIN public.academic_sections sec ON sec.id = c.section_id
        LEFT JOIN public.subjects s ON s.id = c.subject_id
        LEFT JOIN public.profiles p ON p.id = c.teacher_id
        WHERE c.id = %s::UUID;
        """,
        (live_class_id,),
    )
    meta = class_rows[0] if class_rows else {}
    class_section = " - ".join([x for x in [meta.get("class_name"), meta.get("section_name")] if x]) or meta.get("target_class") or ""
    subject_name = (meta.get("subject_name") or "").strip()
    raw_session_title = (meta.get("session_title") or "").strip()

    if raw_session_title and raw_session_title.lower() not in ("live class", "live class recording"):
        if class_section and class_section.lower() not in raw_session_title.lower():
            resolved_title = f"{raw_session_title} ({class_section})"
        else:
            resolved_title = raw_session_title
    elif class_section and subject_name:
        resolved_title = f"{class_section} • {subject_name} Lecture"
    elif class_section:
        resolved_title = f"{class_section} Lecture"
    else:
        resolved_title = "Recorded Class Session"

    # Compute actual duration if start timestamp available
    computed_dur = actual_duration_seconds
    start_ts = meta.get("actual_start_at") or meta.get("scheduled_at")
    end_ts = meta.get("actual_end_at") or datetime.now(timezone.utc)
    if start_ts:
        try:
            if start_ts.tzinfo is None:
                start_ts = start_ts.replace(tzinfo=timezone.utc)
            if end_ts.tzinfo is None:
                end_ts = end_ts.replace(tzinfo=timezone.utc)
            diff_sec = int((end_ts - start_ts).total_seconds())
            if diff_sec > 0:
                computed_dur = max(60, diff_sec)
        except Exception:
            pass
    if computed_dur <= 0:
        computed_dur = 60

    exists, real_size = minio_client.check_file_exists_and_get_size(live_class_id)
    storage_base = os.environ.get("STORAGE_PUBLIC_URL", "http://localhost:8000/storage/v1/object/public").rstrip("/")
    storage_key = f"{live_class_id}.mp4" if exists else None
    file_size = real_size if (exists and real_size > 0) else 0

    existing_rec = await exec_sql(
        "SELECT id::TEXT AS id FROM public.live_class_recordings WHERE live_class_id = %s::UUID AND deleted_at IS NULL ORDER BY created_at DESC LIMIT 1;",
        (live_class_id,),
    )
    if existing_rec:
        rec_id = existing_rec[0]["id"]
        recording_url = f"/api/live-classes/recordings/{rec_id}/stream" if exists else f"{storage_base}/live-classes/{live_class_id}.mp4"
        await exec_sql(
            """
            UPDATE public.live_class_recordings
            SET title = %s,
                duration = %s,
                file_size = CASE WHEN %s > 0 THEN %s ELSE file_size END,
                storage_key = COALESCE(storage_key, %s),
                recording_url = %s,
                processing_status = 'Processed',
                updated_at = NOW()
            WHERE id = %s::UUID;
            """,
            (resolved_title, computed_dur, file_size, file_size, storage_key, recording_url, rec_id),
            fetch=False,
        )
    else:
        rec_id = str(uuid.uuid4())
        recording_url = f"/api/live-classes/recordings/{rec_id}/stream" if exists else f"{storage_base}/live-classes/{live_class_id}.mp4"
        await exec_sql(
            """
            INSERT INTO public.live_class_recordings (
                id, live_class_id, school_id, class_id, section_id, subject_id,
                teacher_id, teacher_name, recording_url, storage_key, duration, file_size,
                title, description, processing_status, recording_type, visibility,
                tags, created_by, updated_by, uploaded_by
            ) VALUES (
                %s::UUID, %s::UUID, %s::UUID, %s::UUID, %s::UUID, %s::UUID,
                %s::UUID, %s, %s, %s, %s, %s,
                %s, %s, 'Processed', 'Live Class', 'CLASS',
                '["class_only"]'::jsonb, %s::UUID, %s::UUID, %s::UUID
            );
            """,
            (
                rec_id,
                live_class_id,
                meta.get("school_id"),
                meta.get("class_id"),
                meta.get("section_id"),
                meta.get("subject_id"),
                meta.get("teacher_id"),
                meta.get("teacher_name"),
                recording_url,
                storage_key,
                computed_dur,
                file_size,
                resolved_title,
                meta.get("description") or f"Recorded live class session for {class_section}".strip(),
                meta.get("created_by") or meta.get("teacher_id"),
                meta.get("created_by") or meta.get("teacher_id"),
                meta.get("teacher_id"),
            ),
            fetch=False,
        )


# ============================================================================
# 9. REAL-TIME WEBSOCKET FOR CLASSROOM CHAT, HAND RAISE, AND REACTIONS
# ============================================================================

_active_connections: Dict[str, List[WebSocket]] = {}

@router.websocket("/live-classes/{session_id}/ws")
async def live_class_websocket(websocket: WebSocket, session_id: str):
    await websocket.accept()
    if session_id not in _active_connections:
        _active_connections[session_id] = []
    _active_connections[session_id].append(websocket)
    try:
        while True:
            data = await websocket.receive_json()
            # Broadcast to peers in the same session
            dead = []
            for peer in _active_connections[session_id]:
                if peer != websocket:
                    try:
                        await peer.send_json(data)
                    except Exception:
                        dead.append(peer)
            for d in dead:
                _active_connections[session_id].remove(d)
    except WebSocketDisconnect:
        if session_id in _active_connections and websocket in _active_connections[session_id]:
            _active_connections[session_id].remove(websocket)


# ============================================================================
# 10. JOIN VIA CODE, RECENT CODES, AND GUEST JOIN ENDPOINTS
# ============================================================================

@router.post("/live-classes/join-code/validate")
async def validate_join_code(
    payload: Dict[str, Any] = Body(...),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Validate a meeting room code for authenticated ERP users and save to recents."""
    code = payload.get("code", "")
    if not code:
        raise HTTPException(status_code=400, detail="Meeting code is required")
    rows = await exec_sql(
        "SELECT public.sp_validate_live_class_code(%s::UUID, %s::UUID, %s::VARCHAR) AS data;",
        (school_id, user["id"], code)
    )
    if not rows or not rows[0].get("data"):
        raise HTTPException(status_code=400, detail="Failed to validate meeting code")
    res = rows[0]["data"]
    if not res.get("success"):
        raise HTTPException(status_code=404, detail=res.get("message", "Invalid meeting code"))
    return {"success": True, "data": res}


# ============================================================================
# 11. CONDUCT CLASS DYNAMIC INTERACTION APIS (Q&A, POLLS, WHITEBOARD, BREAKOUT)
# ============================================================================

@router.get("/live-classes/conduct")
@router.get("/live-classes/sessions/{session_id}/conduct")
async def get_conduct_session_data(
    session_id: Optional[str] = None,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """
    Fetch comprehensive dynamic Conduct Class session state:
    active session, real-time participants, upcoming today's classes,
    Q&A questions, active poll, whiteboard canvas, and engagement metrics.
    """
    rows = await exec_sql(
        "SELECT public.sp_get_live_class_conduct_session(%s::UUID, %s::UUID, %s::UUID) AS data;",
        (school_id, user["id"], session_id)
    )
    if not rows or not rows[0].get("data"):
        raise HTTPException(status_code=404, detail="Session data could not be retrieved")
    
    return {"success": True, "data": rows[0]["data"]}


@router.post("/live-classes/sessions/{session_id}/questions")
async def submit_question(
    session_id: str,
    payload: Dict[str, Any] = Body(...),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Students or participants submit a question in the Q&A panel."""
    question_text = payload.get("question", "").strip()
    if not question_text:
        raise HTTPException(status_code=400, detail="Question text cannot be empty")
    
    author_name = user.get("full_name") or payload.get("author_name", "Student")
    author_role = user.get("role", "student")
    is_anon = payload.get("is_anonymous", False)

    rows = await exec_sql(
        "SELECT public.sp_submit_live_class_question(%s::UUID, %s::UUID, %s::UUID, %s::TEXT, %s::TEXT, %s::TEXT, %s::BOOLEAN) AS data;",
        (session_id, school_id, user["id"], author_name, author_role, question_text, is_anon)
    )
    if not rows or not rows[0].get("data"):
        raise HTTPException(status_code=400, detail="Failed to submit question")
    
    data = rows[0]["data"]
    # Broadcast to room WebSocket peers
    if session_id in _active_connections:
        event = {"type": "question.created", "question": data}
        for peer in _active_connections[session_id]:
            try:
                await peer.send_json(event)
            except Exception:
                pass

    return {"success": True, "data": data}


@router.post("/live-classes/questions/{question_id}/answer")
async def answer_question(
    question_id: str,
    payload: Dict[str, Any] = Body(...),
    user=Depends(get_current_user),
):
    """Teacher, host, or students answer / reply to a submitted question."""
    answer_text = payload.get("answer", "").strip()
    if not answer_text:
        raise HTTPException(status_code=400, detail="Answer text cannot be empty")

    author_name = user.get("full_name") or payload.get("author_name")
    author_role = user.get("role", "student")

    rows = await exec_sql(
        "SELECT public.sp_answer_live_class_question(%s::UUID, %s::UUID, %s::TEXT, %s::TEXT, %s::TEXT) AS data;",
        (question_id, user["id"], answer_text, author_name, author_role)
    )
    if not rows or not rows[0].get("data"):
        raise HTTPException(status_code=400, detail="Failed to answer question")

    data = rows[0]["data"]
    session_id = payload.get("session_id")
    if session_id and session_id in _active_connections:
        event = {"type": "question.answered", "question_id": question_id, "reply": data.get("reply")}
        for peer in _active_connections[session_id]:
            try:
                await peer.send_json(event)
            except Exception:
                pass

    return {"success": True, "data": data}


@router.post("/live-classes/questions/{question_id}/upvote")
async def upvote_question(
    question_id: str,
    user=Depends(get_current_user),
):
    """Students upvote a question."""
    rows = await exec_sql(
        "SELECT public.sp_upvote_live_class_question(%s::UUID, %s::UUID) AS data;",
        (question_id, user["id"])
    )
    if not rows or not rows[0].get("data"):
        raise HTTPException(status_code=400, detail="Failed to upvote question")

    return {"success": True, "data": rows[0]["data"]}


@router.post("/live-classes/sessions/{session_id}/polls")
async def create_and_launch_poll(
    session_id: str,
    payload: Dict[str, Any] = Body(...),
    user=Depends(require_live_class_host),
    school_id=Depends(require_school_id),
):
    """Teacher creates and launches a new live poll/quiz."""
    title = payload.get("title", "Live Class Poll")
    question = payload.get("question", "")
    options = payload.get("options", [])
    correct_opt = payload.get("correct_option_id")

    rows = await exec_sql(
        "SELECT public.sp_create_and_launch_poll(%s::UUID, %s::UUID, %s::UUID, %s::TEXT, %s::TEXT, %s::JSONB, %s::TEXT) AS data;",
        (session_id, school_id, user["id"], title, question, json.dumps(options), correct_opt)
    )
    res = rows[0]["data"] if rows else {"poll_id": str(uuid.uuid4())}

    # Broadcast to room WebSocket peers only for genuinely new polls
    if session_id in _active_connections and not res.get("is_duplicate_suppressed"):
        event = {"type": "poll.launched", "poll": payload}
        for peer in _active_connections[session_id]:
            try:
                await peer.send_json(event)
            except Exception:
                pass

    return {"success": True, "data": res}


@router.post("/live-classes/polls/{poll_id}/respond")
async def respond_to_poll(
    poll_id: str,
    payload: Dict[str, Any] = Body(...),
    user=Depends(get_current_user),
):
    """Students vote/respond on an active poll."""
    session_id = payload.get("session_id")
    option_id = payload.get("option_id")
    if not session_id or not option_id:
        raise HTTPException(status_code=400, detail="session_id and option_id are required")

    rows = await exec_sql(
        "SELECT public.sp_respond_to_poll(%s::UUID, %s::UUID, %s::UUID, %s::TEXT) AS data;",
        (poll_id, session_id, user["id"], option_id)
    )
    if not rows or not rows[0].get("data"):
        raise HTTPException(status_code=400, detail="Failed to record poll response")

    data = rows[0]["data"]
    # Broadcast updated poll tallies
    if session_id in _active_connections:
        event = {"type": "poll.updated", "poll_id": poll_id, "data": data}
        for peer in _active_connections[session_id]:
            try:
                await peer.send_json(event)
            except Exception:
                pass

    return {"success": True, "data": data}


@router.post("/live-classes/sessions/{session_id}/whiteboard")
async def save_whiteboard(
    session_id: str,
    payload: Dict[str, Any] = Body(...),
    user=Depends(require_live_class_host),
    school_id=Depends(require_school_id),
):
    """Saves collaborative whiteboard elements and syncs state."""
    canvas_data = payload.get("canvas_data", {})
    teacher_only = payload.get("teacher_only_mode", True)
    rows = await exec_sql(
        "SELECT public.sp_save_whiteboard_canvas(%s::UUID, %s::UUID, %s::UUID, %s::JSONB, %s::BOOLEAN) AS data;",
        (session_id, school_id, user["id"], json.dumps(canvas_data), teacher_only)
    )
    wb_data = rows[0]["data"] if rows and rows[0].get("data") else {"session_id": session_id, "teacher_only_mode": teacher_only}

    if session_id in _active_connections:
        event = {"type": "whiteboard.updated", "canvas_data": canvas_data}
        for peer in _active_connections[session_id]:
            try:
                await peer.send_json(event)
            except Exception:
                pass

    return {"success": True, "data": wb_data}


@router.post("/live-classes/sessions/{session_id}/participants/{participant_id}/mute")
async def mute_participant(
    session_id: str,
    participant_id: str,
    payload: Dict[str, Any] = Body(...),
    user=Depends(require_live_class_host),
):
    """Host mutes a participant remotely."""
    is_muted = payload.get("is_muted", True)
    await exec_sql(
        "UPDATE public.live_class_participants SET is_mic_muted = %s, updated_at = NOW() WHERE live_class_id = %s::UUID AND (user_id::TEXT = %s OR id::TEXT = %s);",
        (is_muted, session_id, participant_id, participant_id)
    )
    # Also update guest participants if participant_id is a guest
    await exec_sql(
        "UPDATE public.live_class_guest_participants SET is_mic_muted = %s, updated_at = NOW() WHERE session_id = %s::UUID AND (id::TEXT = %s OR guest_reference = %s);",
        (is_muted, session_id, participant_id, participant_id)
    )
    if session_id in _active_connections:
        event = {
            "type": "participant.muted",
            "participant_id": participant_id,
            "target_user_id": participant_id,
            "is_muted": is_muted
        }
        event2 = {
            "type": "participant_control",
            "action": "mute" if is_muted else "unmute",
            "targetUserId": participant_id
        }
        for peer in _active_connections[session_id]:
            try:
                await peer.send_json(event)
                await peer.send_json(event2)
            except Exception:
                pass
    return {"success": True, "message": f"Participant {'muted' if is_muted else 'unmuted'}"}


@router.post("/live-classes/sessions/{session_id}/participants/{participant_id}/remove")
async def remove_participant(
    session_id: str,
    participant_id: str,
    user=Depends(require_live_class_host),
):
    """Host removes an unruly participant from the live session."""
    await exec_sql(
        "UPDATE public.live_class_participants SET leave_time = NOW(), updated_at = NOW() WHERE live_class_id = %s::UUID AND (user_id::TEXT = %s OR id::TEXT = %s);",
        (session_id, participant_id, participant_id)
    )
    # Also update guest participant if guest
    await exec_sql(
        "UPDATE public.live_class_guest_participants SET last_leave_at = NOW(), approval_status = 'REMOVED', updated_at = NOW() WHERE session_id = %s::UUID AND (id::TEXT = %s OR guest_reference = %s);",
        (session_id, participant_id, participant_id)
    )
    if session_id in _active_connections:
        event = {
            "type": "participant.removed",
            "participant_id": participant_id,
            "target_user_id": participant_id
        }
        event2 = {
            "type": "participant_control",
            "action": "remove_participant",
            "targetUserId": participant_id
        }
        for peer in _active_connections[session_id]:
            try:
                await peer.send_json(event)
                await peer.send_json(event2)
            except Exception:
                pass
    return {"success": True, "message": "Participant removed from live class"}


@router.post("/live-classes/sessions/{session_id}/recordings/toggle")
async def toggle_recording(
    session_id: str,
    background_tasks: BackgroundTasks,
    user=Depends(require_live_class_host),
):
    """Toggle Egress recording on or off during active class."""
    rows = await exec_sql(
        "SELECT recording_status, actual_start_at, updated_at FROM public.live_classes WHERE id = %s;",
        (session_id,),
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Session not found")

    current_status = rows[0].get("recording_status", "IDLE")
    if current_status in ("RECORDING", "ACTIVE"):
        new_status = "COMPLETED"
        start_ts = rows[0].get("updated_at") or rows[0].get("actual_start_at")
        elapsed_sec = 60
        if start_ts:
            try:
                now_utc = datetime.now(timezone.utc)
                if start_ts.tzinfo is None:
                    start_ts = start_ts.replace(tzinfo=timezone.utc)
                elapsed_sec = max(60, int((now_utc - start_ts).total_seconds()))
            except Exception:
                elapsed_sec = 60
        await exec_sql("UPDATE public.live_classes SET recording_status = 'COMPLETED', updated_at = NOW() WHERE id = %s;", (session_id,))
        await cleanup_room_egress_and_delete(session_id, elapsed_sec, create_recording=True, delete_room=False)
    else:
        new_status = "RECORDING"
        await exec_sql("UPDATE public.live_classes SET recording_status = 'RECORDING', recording_enabled = TRUE, updated_at = NOW() WHERE id = %s;", (session_id,))
        background_tasks.add_task(initiate_room_egress, session_id)

    if session_id in _active_connections:
        event = {"type": "recording.status_changed", "recording_status": new_status}
        for peer in _active_connections[session_id]:
            try:
                await peer.send_json(event)
            except Exception:
                pass

    return {
        "success": True,
        "recording_status": new_status,
        "data": {
            "recording_status": new_status,
            "is_recording": new_status == "RECORDING"
        }
    }



@router.get("/live-classes/join-code/{code}/preview")
async def preview_join_code(
    code: str,
    school_id: Optional[str] = None,
):
    """Public or student preview of meeting information prior to joining."""
    target_school = school_id or "11111111-1111-1111-1111-111111111111"
    rows = await exec_sql(
        "SELECT public.sp_validate_live_class_code(%s::UUID, NULL, %s::VARCHAR) AS data;",
        (target_school, code)
    )
    if not rows or not rows[0].get("data"):
        raise HTTPException(status_code=404, detail="Meeting code not found")
    res = rows[0]["data"]
    if not res.get("success"):
        raise HTTPException(status_code=404, detail=res.get("message", "Invalid meeting code"))
    return {"success": True, "data": res}



@router.get("/live-classes/recent-codes")
async def get_recent_meeting_codes(
    user=Depends(get_current_user),
):
    """Fetch recent and starred meeting codes for authenticated user."""
    rows = await exec_sql(
        "SELECT public.sp_get_recent_saved_meeting_codes(%s::UUID) AS data;",
        (user["id"],)
    )
    if not rows or not rows[0].get("data"):
        return {"success": True, "data": {"items": []}}
    return {"success": True, "data": rows[0]["data"]}


@router.post("/live-classes/recent-codes/toggle-star")
async def toggle_starred_code(
    payload: Dict[str, Any] = Body(...),
    user=Depends(get_current_user),
):
    """Toggle star bookmark status for a recent meeting code."""
    code = payload.get("code", "")
    is_starred = payload.get("is_starred", True)
    rows = await exec_sql(
        "SELECT public.sp_toggle_saved_meeting_code(%s::UUID, %s::VARCHAR, %s::BOOLEAN) AS data;",
        (user["id"], code, is_starred)
    )
    return {"success": True, "data": rows[0]["data"] if rows else {}}


@router.delete("/live-classes/recent-codes/clear")
async def clear_recent_codes(
    user=Depends(get_current_user),
):
    """Clear all unstarred recent meeting codes."""
    rows = await exec_sql(
        "SELECT public.sp_clear_recent_meeting_codes(%s::UUID) AS data;",
        (user["id"],)
    )
    return {"success": True, "data": rows[0]["data"] if rows else {}}


@router.post("/live-classes/guest/request")
async def request_guest_join(
    payload: Dict[str, Any] = Body(...),
):
    """Submit external guest join request with temporary identity."""
    code = payload.get("code", "")
    display_name = payload.get("display_name", "")
    email = payload.get("email")
    purpose = payload.get("purpose", "Guest Speaker")
    organization = payload.get("organization")
    options = payload.get("options", {})
    school_id = payload.get("school_id", "11111111-1111-1111-1111-111111111111")

    if not code or not display_name:
        raise HTTPException(status_code=400, detail="Meeting code and guest name are required")

    rows = await exec_sql(
        """
        SELECT public.sp_request_guest_join(
            %s::UUID, %s::VARCHAR, %s::VARCHAR, %s::VARCHAR, %s::VARCHAR, %s::VARCHAR, %s::JSONB
        ) AS data;
        """,
        (school_id, code, display_name, email, purpose, organization, json.dumps(options))
    )
    if not rows or not rows[0].get("data"):
        raise HTTPException(status_code=400, detail="Failed to process guest join request")
    res = rows[0]["data"]
    if not res.get("success"):
        raise HTTPException(status_code=400, detail=res.get("message", "Guest join denied"))

    # Real-time WebSocket notification to host in session
    session_id = res.get("session_id")
    if session_id and session_id in _active_connections:
        event_payload = {
            "type": "guest.approval.pending",
            "request_id": res.get("request_id"),
            "display_name": display_name,
            "purpose": purpose,
            "organization": organization,
            "guest_reference": res.get("guest_reference"),
        }
        for peer in _active_connections[session_id]:
            try:
                await peer.send_json(event_payload)
            except Exception:
                pass

    return {"success": True, "data": res}



@router.get("/live-classes/guest/upcoming-sessions")
async def get_upcoming_guest_sessions(
    school_id: Optional[str] = None,
):
    """Fetch scheduled guest-accessible upcoming lectures and expert talks."""
    target_school = school_id or "11111111-1111-1111-1111-111111111111"
    rows = await exec_sql(
        "SELECT public.sp_get_upcoming_guest_sessions(%s::UUID) AS data;",
        (target_school,)
    )
    if not rows or not rows[0].get("data"):
        return {"success": True, "data": {"sessions": []}}
    return {"success": True, "data": rows[0]["data"]}


@router.get("/live-classes/sessions/{session_id}/waiting-room")
async def get_waiting_room_guests(
    session_id: str,
    user=Depends(require_live_class_host),
):
    """Fetch pending guest join requests for host waiting room management."""
    rows = await exec_sql(
        "SELECT public.sp_get_waiting_room_guests(%s::UUID) AS data;",
        (session_id,)
    )
    if not rows or not rows[0].get("data"):
        return {"success": True, "data": {"waiting_count": 0, "guests": []}}
    return {"success": True, "data": rows[0]["data"]}


@router.post("/live-classes/sessions/{session_id}/guests/{request_id}/review")
async def review_guest_request(
    session_id: str,
    request_id: str,
    payload: Dict[str, Any] = Body(...),
    user=Depends(require_live_class_host),
):
    """Host action to admit or reject an external guest in the waiting room."""
    decision = payload.get("decision", "ADMIT").upper()
    reason = payload.get("reason")
    rows = await exec_sql(
        "SELECT public.sp_review_guest_request(%s::UUID, %s::UUID, %s::UUID, %s::VARCHAR, %s::TEXT) AS data;",
        (session_id, request_id, user["id"], decision, reason)
    )
    if not rows or not rows[0].get("data"):
        raise HTTPException(status_code=400, detail="Failed to review guest request")
    res = rows[0]["data"]

    # Real-time WebSocket notification to all room peers (including waiting guests)
    if session_id in _active_connections:
        event_type = "guest.approved" if decision == "ADMIT" else "guest.rejected"
        event_payload = {
            "type": event_type,
            "request_id": request_id,
            "guest_id": res.get("guest_id"),
            "decision": res.get("decision"),
        }
        for peer in _active_connections[session_id]:
            try:
                await peer.send_json(event_payload)
            except Exception:
                pass

    return {"success": True, "data": res}


@router.get("/live-classes/guest/status/{request_id}")
async def check_guest_admission_status(request_id: str):
    """Check approval status of a guest waiting room request."""
    rows = await exec_sql(
        """
        SELECT gr.id AS request_id, gr.session_id, gr.guest_id, gr.request_status,
               gp.approval_status, gp.display_name, gp.guest_reference,
               lc.title AS session_title, lc.room_code
        FROM public.live_class_guest_requests gr
        JOIN public.live_class_guest_participants gp ON gp.id = gr.guest_id
        JOIN public.live_classes lc ON lc.id = gr.session_id
        WHERE gr.id = %s::UUID;
        """,
        (request_id,)
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Guest request not found")
    row = rows[0]
    return {
        "success": True,
        "data": {
            "request_id": str(row["request_id"]),
            "session_id": str(row["session_id"]),
            "guest_id": str(row["guest_id"]),
            "request_status": row["request_status"],
            "approval_status": row["approval_status"],
            "display_name": row["display_name"],
            "guest_reference": row.get("guest_reference", ""),
            "is_approved": (row["approval_status"] == "APPROVED" or row["request_status"] == "APPROVED"),
            "is_rejected": (row["approval_status"] == "REJECTED" or row["request_status"] == "REJECTED"),
            "session_title": row["session_title"],
            "room_code": row["room_code"]
        }
    }


@router.get("/livekit/guest-token")
@router.post("/livekit/guest-token")
async def generate_guest_livekit_token(
    request: Request,
    request_id: str = Query(..., description="Approved guest request ID"),
):
    """Issue LiveKit WebRTC access token for an approved external guest."""
    rows = await exec_sql(
        """
        SELECT gr.id AS request_id, gr.session_id, gr.guest_id, gr.request_status,
               gp.approval_status, gp.display_name, gp.guest_reference,
               lc.title AS session_title, lc.room_code
        FROM public.live_class_guest_requests gr
        JOIN public.live_class_guest_participants gp ON gp.id = gr.guest_id
        JOIN public.live_classes lc ON lc.id = gr.session_id
        WHERE gr.id = %s::UUID;
        """,
        (request_id,)
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Guest request not found")
    row = rows[0]
    if row["request_status"] != "APPROVED" and row["approval_status"] != "APPROVED":
        raise HTTPException(status_code=403, detail="Guest has not been admitted yet by host")

    api_key = os.environ.get("LIVEKIT_API_KEY", "devkey")
    api_secret = os.environ.get("LIVEKIT_API_SECRET", "secretkey_edushamiit_livekit_2026_secure")
    
    identity = str(row["guest_id"])
    name = row["display_name"]
    room = str(row["session_id"])
    now = int(time.time())
    claims = {
        "iss": api_key,
        "sub": identity,
        "name": f"{name} (Guest)",
        "video": {
            "roomJoin": True,
            "room": room,
            "canPublish": True,
            "canSubscribe": True,
            "canPublishData": True,
            "canPublishSources": ["camera", "microphone"],
            "canUpdateOwnMetadata": True,
            "roomAdmin": False,
            "roomCreate": False
        },
        "metadata": "guest",
        "nbf": now - 10,
        "exp": now + 4 * 3600
    }
    token = jwt.encode(claims, api_secret, algorithm="HS256")
    livekit_ws_url = resolve_browser_livekit_url(request)
    return {
        "success": True,
        "token": token,
        "livekit_url": livekit_ws_url,
        "room": room,
        "identity": identity,
        "name": name,
    }


# ============================================================================
# 12. ENROLLED STUDENTS, BREAKOUT ROOMS, HOST REASSIGNMENT AND SESSION SETTINGS
# ============================================================================

@router.get("/live-classes/students")
async def get_enrolled_students(
    class_id: Optional[str] = None,
    section_id: Optional[str] = None,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Fetch enrolled students for dynamic session participant lists and attendance."""
    rows = await exec_sql(
        "SELECT public.sp_get_enrolled_students_for_class_section(%s::UUID, %s::UUID, %s::UUID) AS data;",
        (school_id, class_id if class_id else None, section_id if section_id else None)
    )
    if not rows or not rows[0].get("data"):
        return {"success": True, "data": {"students": [], "count": 0}}
    return {"success": True, "data": rows[0]["data"]}


@router.get("/live-classes/sessions/{session_id}/breakout")
async def get_breakout_rooms(
    session_id: str,
    user=Depends(get_current_user),
):
    """Fetch active breakout rooms for the live session."""
    rows = await exec_sql(
        "SELECT public.sp_get_live_class_breakout_rooms(%s::UUID) AS data;",
        (session_id,)
    )
    if not rows or not rows[0].get("data"):
        return {"success": True, "data": {"rooms": []}}
    return {"success": True, "data": rows[0]["data"]}


@router.post("/live-classes/sessions/{session_id}/breakout")
async def create_breakout_room(
    session_id: str,
    payload: Dict[str, Any] = Body(...),
    user=Depends(require_live_class_host),
    school_id=Depends(require_school_id),
):
    """Create a breakout room within an active session."""
    name = payload.get("name", "Breakout Room")
    capacity = payload.get("capacity", 8)
    rows = await exec_sql(
        "SELECT public.sp_create_live_class_breakout_room(%s::UUID, %s::UUID, %s::UUID, %s::VARCHAR, %s::INTEGER) AS data;",
        (school_id, user["id"], session_id, name, capacity)
    )
    if not rows or not rows[0].get("data"):
        raise HTTPException(status_code=400, detail="Failed to create breakout room")
    res = rows[0]["data"]

    if session_id in _active_connections:
        event = {"type": "breakout.created", "room": res.get("room")}
        for peer in _active_connections[session_id]:
            try:
                await peer.send_json(event)
            except Exception:
                pass

    return {"success": True, "data": res}


@router.post("/live-classes/sessions/{session_id}/breakout/{room_id}/close")
async def close_breakout_room(
    session_id: str,
    room_id: str,
    user=Depends(require_live_class_host),
):
    """Close an active breakout room."""
    rows = await exec_sql(
        "SELECT public.sp_close_live_class_breakout_room(%s::UUID) AS data;",
        (room_id,)
    )
    if session_id in _active_connections:
        event = {"type": "breakout.closed", "room_id": room_id}
        for peer in _active_connections[session_id]:
            try:
                await peer.send_json(event)
            except Exception:
                pass

    return {"success": True, "message": "Breakout room closed successfully"}


@router.get("/live-classes/sessions/{session_id}/settings")
async def get_session_settings(
    session_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Fetch active or scheduled session settings and permissions."""
    rows = await exec_sql(
        "SELECT public.sp_get_live_class_session_settings(%s::UUID, %s::UUID) AS data;",
        (school_id, session_id)
    )
    if not rows or not rows[0].get("data"):
        raise HTTPException(status_code=404, detail="Session settings not found")
    return {"success": True, "data": rows[0]["data"]}


@router.post("/live-classes/sessions/{session_id}/settings")
async def update_session_settings(
    session_id: str,
    payload: Dict[str, Any] = Body(...),
    user=Depends(require_live_class_host),
    school_id=Depends(require_school_id),
):
    """Update session live controls and permissions."""
    rows = await exec_sql(
        "SELECT public.sp_update_live_class_session_settings(%s::UUID, %s::UUID, %s::UUID, %s::JSONB) AS data;",
        (school_id, user["id"], session_id, json.dumps(payload))
    )
    if not rows or not rows[0].get("data"):
        raise HTTPException(status_code=400, detail="Failed to update session settings")
    res = rows[0]["data"]
    updated_settings = res.get("settings", payload)

    # Real-time WebRTC and signaling broadcast
    if session_id in _active_connections:
        event = {"type": "session.settings_updated", "settings": updated_settings}
        for peer in _active_connections[session_id]:
            try:
                await peer.send_json(event)
            except Exception:
                pass

        # If microphone disabled, broadcast mute enforcement to all peers
        if updated_settings.get("allow_student_mic") is False:
            mute_event = {"type": "participant_control", "action": "mute", "targetUserId": "all"}
            for peer in _active_connections[session_id]:
                try:
                    await peer.send_json(mute_event)
                except Exception:
                    pass

        # If camera disabled, broadcast camera_off enforcement to all peers
        if updated_settings.get("allow_student_cam") is False:
            cam_event = {"type": "participant_control", "action": "camera_off", "targetUserId": "all"}
            for peer in _active_connections[session_id]:
                try:
                    await peer.send_json(cam_event)
                except Exception:
                    pass

    return {"success": True, "data": updated_settings, "message": "Session settings updated successfully"}


@router.post("/live-classes/sessions/{session_id}/host")
async def reassign_session_host(
    session_id: str,
    payload: Dict[str, Any] = Body(...),
    user=Depends(require_live_class_host),
    school_id=Depends(require_school_id),
):
    """Reassign Host or Co-Host permissions to another meeting participant."""
    target_user_id = payload.get("target_user_id")
    role = payload.get("role", "host").lower()
    if not target_user_id:
        raise HTTPException(status_code=400, detail="target_user_id is required")

    rows = await exec_sql(
        "SELECT public.sp_reassign_live_class_host(%s::UUID, %s::UUID, %s::UUID, %s::UUID, %s::VARCHAR) AS data;",
        (school_id, user["id"], session_id, target_user_id, role)
    )
    if not rows or not rows[0].get("data"):
        raise HTTPException(status_code=400, detail="Failed to reassign host role")
    res = rows[0]["data"]

    if session_id in _active_connections:
        event = {"type": "session.host_reassigned", "target_user_id": target_user_id, "role": role}
        for peer in _active_connections[session_id]:
            try:
                await peer.send_json(event)
            except Exception:
                pass

    return {"success": True, "data": res}
