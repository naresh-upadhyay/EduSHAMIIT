import json
import uuid
from typing import Optional
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from fastapi.responses import StreamingResponse

from app.middleware.auth import get_current_user, require_school_id
from app.services.langchain_agent import process_message, load_history
from app.services.supabase_client import get_supabase

router = APIRouter()


async def _sse_generator(text: str, image_b64: Optional[str], audio_path: Optional[str],
                          user: dict, session_id: str, school_id: str):
    """Generate SSE events from the langchain agent process_message stream."""
    try:
        async for chunk in process_message(
            text=text,
            image_b64=image_b64,
            audio_path=audio_path,
            user=user,
            session_id=session_id,
            school_id=school_id,
        ):
            event_type = chunk.get("type", "text")
            data = json.dumps(chunk, ensure_ascii=False)
            yield f"event: {event_type}\ndata: {data}\n\n"
    except Exception as e:
        error_data = json.dumps({"type": "error", "content": str(e)})
        yield f"event: error\ndata: {error_data}\n\n"


@router.post("/message")
async def chat_message(
    request: dict,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """
    Send message to Shami AI and stream response via SSE.

    Request:
    {
        "message": "What classes do I have today?",
        "session_id": "uuid-session-1"
    }

    SSE Response:
    data: {"type":"text","content":"Your Monday Schedule:"}
    data: {"type":"tool_result","tool":"get_timetable","data":{...}}
    data: {"type":"done"}
    """
    message = request.get("message", "")
    session_id = request.get("session_id", str(uuid.uuid4()))

    if not message:
        raise HTTPException(status_code=400, detail="Message is required")

    return StreamingResponse(
        _sse_generator(
            text=message,
            image_b64=None,
            audio_path=None,
            user=user,
            session_id=session_id,
            school_id=school_id,
        ),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


@router.get("/history/{session_id}")
async def get_chat_history(
    session_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Get chat history for a session."""
    sb = get_supabase()

    messages = (await sb.table("ai_chat_history") \
        .select("*") \
        .eq("school_id", school_id) \
        .eq("user_id", user["id"]) \
        .eq("session_id", session_id) \
        .order("created_at") \
        .aexecute()).data

    return {"success": True, "school_id": school_id, "data": {"messages": messages}}


@router.get("/sessions")
async def get_chat_sessions(
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Get all unique chat sessions for the logged in user."""
    sb = get_supabase()

    try:
        messages = (await sb.table("ai_chat_history") \
            .select("session_id, role, content, created_at") \
            .eq("school_id", school_id) \
            .eq("user_id", user["id"]) \
            .order("created_at", ascending=False) \
            .aexecute()).data

        sessions_map = {}
        for msg in messages:
            sid = str(msg["session_id"])
            created_at = msg["created_at"]
            content = msg["content"]
            role = msg["role"]

            if sid not in sessions_map:
                sessions_map[sid] = {
                    "session_id": sid,
                    "last_message_at": created_at,
                    "title": "New Chat",
                    "messages_count": 0
                }

            sessions_map[sid]["messages_count"] += 1

            if role == "user":
                sessions_map[sid]["title"] = content[:60] + ("..." if len(content) > 60 else "")

        sessions_list = list(sessions_map.values())
        sessions_list.sort(key=lambda x: x["last_message_at"], reverse=True)

        return {"success": True, "school_id": school_id, "data": {"sessions": sessions_list}}
    except Exception as e:
        return {"success": False, "message": f"Error fetching sessions: {str(e)}", "data": {"sessions": []}}


@router.delete("/session/{session_id}")
async def delete_chat_session(
    session_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Delete all messages for a specific session."""
    sb = get_supabase()
    try:
        await sb.table("ai_chat_history") \
            .delete() \
            .eq("school_id", school_id) \
            .eq("user_id", user["id"]) \
            .eq("session_id", session_id) \
            .aexecute()
        return {"success": True, "message": "Session deleted successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete session: {str(e)}")