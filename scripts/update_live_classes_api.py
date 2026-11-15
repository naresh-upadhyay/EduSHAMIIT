import re
import os

backend_file = r'E:\EduSHAMIIT\EduSHAMIIT Backend\backend\app\api\live_classes.py'

with open(backend_file, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Part 1: up to line 1162 (1-indexed) -> lines[0:1162]
part1 = lines[0:1162]

# Part 2: preview_join_code -> lines[1163:1182]
part2 = lines[1163:1182]

# Part 3: recent_codes & guest request -> lines[1455:1546]
part3 = lines[1455:1546]

# Part 4: upcoming sessions, waiting room, review guest -> lines[1819:1885]
part4 = lines[1819:1885]

new_endpoints = '''

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

    if session_id in _active_connections:
        event = {"type": "session.settings_updated", "settings": payload}
        for peer in _active_connections[session_id]:
            try:
                await peer.send_json(event)
            except Exception:
                pass

    return {"success": True, "data": res}


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
'''

combined = ''.join(part1) + '\n' + ''.join(part2) + '\n' + ''.join(part3) + '\n' + ''.join(part4) + '\n' + new_endpoints

with open(backend_file, 'w', encoding='utf-8') as f:
    f.write(combined)

print('Updated live_classes.py cleanly!')
