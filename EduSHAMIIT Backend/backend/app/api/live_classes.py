"""
EduSHAMIIT – Enterprise Live Class & LiveKit Integration API
Orchestrates Join & Conduct, Recordings, Attendance Tracking, LiveKit tokens,
Egress recordings, stored procedure execution, and real-time WebSockets.
"""
import os
import io
import csv
import json
import time
import uuid
import httpx
from datetime import datetime, timezone
from typing import Optional, List, Dict, Any
import asyncio
from fastapi import APIRouter, Depends, HTTPException, Query, BackgroundTasks, Request, WebSocket, WebSocketDisconnect, status, Body
from fastapi.responses import StreamingResponse
from jose import jwt
import psycopg2
from psycopg2.extras import RealDictCursor, register_uuid

register_uuid()

from app.middleware.auth import get_current_user, require_school_id, require_teacher, require_student, require_any_role
from app.services.supabase_client import get_supabase
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
    # 1. Update session status via database
    await exec_sql(
        """
        UPDATE public.live_classes
        SET status = 'live', is_live = TRUE, actual_start_at = NOW(),
            meeting_link = COALESCE(meeting_link, %s),
            recording_status = CASE WHEN recording_enabled = TRUE THEN 'ACTIVE' ELSE 'IDLE' END,
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

    # 3. Check if recording is enabled and auto-trigger Egress
    rows = await exec_sql("SELECT recording_enabled FROM public.live_classes WHERE id = %s;", (live_class_id,))
    if rows and rows[0].get("recording_enabled"):
        background_tasks.add_task(initiate_room_egress, live_class_id)

    return {"success": True, "message": "Class started successfully", "session_id": live_class_id}


@router.post("/live-classes/{live_class_id}/end")
async def end_live_class(
    live_class_id: str,
    background_tasks: BackgroundTasks,
    user=Depends(require_live_class_host),
    school_id=Depends(require_school_id),
):
    """End a live class session, calculate attendance, and finalize egress."""
    # 1. Update session status in DB
    await exec_sql(
        """
        UPDATE public.live_classes
        SET status = 'recorded', is_live = FALSE, actual_end_at = NOW(),
            recording_status = 'COMPLETED', updated_at = NOW()
        WHERE id = %s AND school_id = %s;
        """,
        (live_class_id, school_id),
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

    # 4. Stop Egress and delete room in background
    background_tasks.add_task(cleanup_room_egress_and_delete, live_class_id, 2700)

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
# 5. RECORDINGS MANAGEMENT APIS
# ============================================================================

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
    """Paginated recordings table matching Image 2."""
    rows = await exec_sql(
        "SELECT public.sp_get_live_class_recordings_list(%s::UUID, %s::UUID, %s::UUID, %s::UUID, %s::TEXT, %s::TEXT, %s::INT, %s::INT) AS data;",
        (school_id, class_id, subject_id, teacher_id, search, status_filter, page, page_size)
    )
    if not rows or not rows[0].get("data"):
        return {"success": True, "data": {"items": [], "total_count": 0, "page": page}}
    return {"success": True, "data": rows[0]["data"]}


@router.get("/live-classes/recordings/{recording_id}")
async def get_recording(
    recording_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Get single recording details."""
    rows = await exec_sql("SELECT * FROM public.live_class_recordings WHERE id = %s;", (recording_id,))
    if not rows:
        raise HTTPException(status_code=404, detail="Recording not found")
    return {"success": True, "data": rows[0]}


@router.delete("/live-classes/recordings/{recording_id}")
async def delete_recording(
    recording_id: str,
    user=Depends(require_live_class_host),
    school_id=Depends(require_school_id),
):
    """Soft delete or remove recording record."""
    await exec_sql(
        "UPDATE public.live_class_recordings SET deleted_at = NOW() WHERE id = %s;",
        (recording_id,),
        fetch=False
    )
    return {"success": True, "message": "Recording deleted successfully"}


@router.post("/live-classes/{live_class_id}/share")
@router.post("/live-classes/recordings/{recording_id}/share")
async def share_recording(
    live_class_id: Optional[str] = None,
    recording_id: Optional[str] = None,
    payload: Optional[Dict[str, Any]] = None,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Share recording with specified user or class."""
    shared_to_id = payload.get("shared_to_id") if payload else None
    doc_id = str(uuid.uuid4())
    doc_title = payload.get("title", "Live Class Lecture Recording") if payload else "Live Class Lecture Recording"

    await exec_sql(
        """
        INSERT INTO public.user_documents (
            id, school_id, owner_id, shared_with_id, shared_by_id,
            title, description, category, file_url, file_name, file_size, mime_type
        ) VALUES (
            %s, %s, %s, %s, %s,
            %s, 'Shared live lecture recording', 'recording_shared',
            %s, 'lecture.mp4', 0, 'video/mp4'
        ) ON CONFLICT DO NOTHING;
        """,
        (doc_id, school_id, shared_to_id, shared_to_id, user["id"], doc_title, f"/student/live-classes/play/{live_class_id}"),
        fetch=False
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


async def cleanup_room_egress_and_delete(live_class_id: str, actual_duration_seconds: int):
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
            # Delete room
            await client.post(
                f"{livekit_url}/twirp/livekit.RoomService/DeleteRoom",
                headers=headers,
                json={"room": live_class_id},
                timeout=5.0
            )
    except Exception as e:
        print(f"[LiveKit] Cleanup error: {e}")

    # Upsert recording record
    storage_base = os.environ.get("STORAGE_PUBLIC_URL", "http://localhost:8000/storage/v1/object/public").rstrip("/")
    recording_url = f"{storage_base}/live-classes/{live_class_id}.mp4"
    await exec_sql(
        """
        INSERT INTO public.live_class_recordings (
            live_class_id, recording_url, duration, file_size, title, processing_status
        ) VALUES (
            %s, %s, %s, %s, 'Live Class Recording', 'Processed'
        ) ON CONFLICT DO NOTHING;
        """,
        (live_class_id, recording_url, actual_duration_seconds, 282 * 1024 * 1024),
        fetch=False
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
    rows = await exec_sql("SELECT recording_status FROM public.live_classes WHERE id = %s;", (session_id,))
    if not rows:
        raise HTTPException(status_code=404, detail="Session not found")
    
    current_status = rows[0].get("recording_status", "IDLE")
    if current_status in ("RECORDING", "ACTIVE"):
        new_status = "STOPPING"
        await exec_sql("UPDATE public.live_classes SET recording_status = 'COMPLETED', updated_at = NOW() WHERE id = %s;", (session_id,))
        background_tasks.add_task(cleanup_room_egress_and_delete, session_id, 1800)
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
