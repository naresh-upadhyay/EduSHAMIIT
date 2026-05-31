"""
EduSHAMIIT – WebRTC Call Sessions API
Provides ICE server credentials, call session management, and call history.
"""
import os
import hmac
import hashlib
import time
import math
from fastapi import APIRouter, Depends, HTTPException

from app.middleware.auth import get_current_user, require_school_id
from app.services.supabase_client import get_supabase

router = APIRouter()

# ---------------------------------------------------------------------------
# TURN credential helper
# RFC 5766 time-limited credential format
# username = "<timestamp>:<user_id>"
# password  = HMAC-SHA1(secret, username)
# ---------------------------------------------------------------------------
def _generate_turn_credentials(user_id: str) -> dict:
    coturn_secret = os.environ.get("COTURN_SECRET", "")
    coturn_host   = os.environ.get("COTURN_HOST", "127.0.0.1")

    expiry   = math.floor(time.time()) + 86400  # 24 hours
    username = f"{expiry}:{user_id}"
    password = hmac.new(
        coturn_secret.encode("utf-8"),
        username.encode("utf-8"),
        hashlib.sha1,
    ).digest()
    import base64
    credential = base64.b64encode(password).decode("utf-8")

    return {
        "iceServers": [
            # Google public STUN (fallback)
            {"urls": "stun:stun.l.google.com:19302"},
            {"urls": "stun:stun1.l.google.com:19302"},
            # Self-hosted coturn STUN
            {"urls": f"stun:{coturn_host}:3478"},
            # Self-hosted coturn TURN (UDP + TCP relay for strict NATs)
            {
                "urls": [
                    f"turn:{coturn_host}:3478?transport=udp",
                    f"turn:{coturn_host}:3479?transport=tcp",
                ],
                "username": username,
                "credential": credential,
            },
        ]
    }


# ---------------------------------------------------------------------------
# POST /calls/initiate — Start a new call session
# ---------------------------------------------------------------------------
@router.post("/calls/initiate")
async def initiate_call(
    request: dict,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    callee_id = request.get("callee_id")
    call_type  = request.get("call_type", "audio")

    if not callee_id:
        raise HTTPException(status_code=400, detail="callee_id is required")
    if call_type not in ("audio", "video"):
        raise HTTPException(status_code=400, detail="call_type must be 'audio' or 'video'")

    # Check block relationship
    try:
        blocks = await sb.table("blocked_users").select("blocker_id, blocked_id").or_(
            f"blocker_id.eq.{user['id']},blocked_id.eq.{user['id']}"
        ).aexecute()
        if blocks.data:
            blocked_ids = {r["blocker_id"] for r in blocks.data} | {r["blocked_id"] for r in blocks.data}
            if callee_id in blocked_ids:
                raise HTTPException(status_code=403, detail="Cannot call this user")
    except HTTPException:
        raise
    except Exception:
        pass  # don't block on non-critical check failure

    # Create call session record
    session_res = await sb.table("call_sessions").insert({
        "school_id": school_id,
        "caller_id": user["id"],
        "callee_id": callee_id,
        "call_type": call_type,
        "status":    "ringing",
    }).aexecute()

    if not session_res.data:
        raise HTTPException(status_code=500, detail="Failed to create call session")

    session_id = session_res.data[0]["id"]
    ice_config = _generate_turn_credentials(user["id"])

    return {
        "success":    True,
        "session_id": session_id,
        "ice_config": ice_config,
    }


# ---------------------------------------------------------------------------
# PUT /calls/{session_id}/status — Update call status
# ---------------------------------------------------------------------------
@router.put("/calls/{session_id}/status")
async def update_call_status(
    session_id: str,
    request: dict,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    new_status = request.get("status")
    valid = ("answered", "ended", "rejected", "missed")
    if new_status not in valid:
        raise HTTPException(status_code=400, detail=f"status must be one of {valid}")

    # Fetch session to validate caller/callee
    sess_res = await sb.table("call_sessions").select("*").eq("id", session_id).maybe_single().aexecute()
    if not sess_res.data:
        raise HTTPException(status_code=404, detail="Call session not found")

    session = sess_res.data
    if user["id"] not in (session["caller_id"], session["callee_id"]):
        raise HTTPException(status_code=403, detail="Not authorized to update this call session")

    from datetime import datetime, timezone
    patch: dict = {"status": new_status}
    now_iso = datetime.now(timezone.utc).isoformat()

    if new_status == "answered":
        patch["answered_at"] = now_iso
    elif new_status in ("ended", "rejected", "missed"):
        patch["ended_at"] = now_iso
        if new_status == "ended" and session.get("answered_at") is None:
            patch["status"] = "missed"

    await sb.table("call_sessions").update(patch).eq("id", session_id).aexecute()

    return {"success": True, "session_id": session_id, "status": new_status}


# ---------------------------------------------------------------------------
# GET /calls/history — Paginated call history for current user
# ---------------------------------------------------------------------------
@router.get("/calls/history")
async def get_call_history(
    limit: int = 50,
    offset: int = 0,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()

    res = await sb.table("call_sessions").select(
        "*, "
        "caller:profiles!caller_id(id, full_name, avatar_url), "
        "callee:profiles!callee_id(id, full_name, avatar_url)"
    ).eq("school_id", school_id).or_(
        f"caller_id.eq.{user['id']},callee_id.eq.{user['id']}"
    ).order("started_at", ascending=False).limit(limit).offset(offset).aexecute()

    sessions = []
    for s in (res.data or []):
        caller = s.get("caller") or {}
        callee = s.get("callee") or {}
        is_outgoing = s["caller_id"] == user["id"]
        peer = callee if is_outgoing else caller
        sessions.append({
            "id":               s["id"],
            "call_type":        s["call_type"],
            "status":           s["status"],
            "direction":        "outgoing" if is_outgoing else "incoming",
            "peer_id":          peer.get("id"),
            "peer_name":        peer.get("full_name", "Unknown"),
            "peer_avatar":      peer.get("avatar_url"),
            "started_at":       s["started_at"],
            "answered_at":      s.get("answered_at"),
            "ended_at":         s.get("ended_at"),
            "duration_seconds": s.get("duration_seconds"),
        })

    return {
        "success": True,
        "school_id": school_id,
        "data": {"calls": sessions, "total": len(sessions)},
    }


# ---------------------------------------------------------------------------
# GET /calls/ice-config — Get fresh ICE credentials (for reconnect)
# ---------------------------------------------------------------------------
@router.get("/calls/ice-config")
async def get_ice_config(user=Depends(get_current_user)):
    return {
        "success": True,
        "ice_config": _generate_turn_credentials(user["id"]),
    }
