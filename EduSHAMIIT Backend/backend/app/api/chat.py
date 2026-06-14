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
                          doc_b64: Optional[str], doc_name: Optional[str],
                          user: dict, session_id: str, school_id: str):
    """Generate SSE events from the langchain agent process_message stream."""
    try:
        # Yield an immediate warming connection event to prevent browser/Nginx disconnects
        yield f"event: info\ndata: {json.dumps({'type': 'info', 'content': 'connected'})}\n\n"
        
        async for chunk in process_message(
            text=text,
            image_b64=image_b64,
            audio_path=audio_path,
            doc_b64=doc_b64,
            doc_name=doc_name,
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
    image_b64 = request.get("image_b64", None)
    doc_b64 = request.get("doc_b64", None)
    doc_name = request.get("doc_name", None)

    if not message and not image_b64 and not doc_b64:
        raise HTTPException(status_code=400, detail="Message, image, or document is required")

    return StreamingResponse(
        _sse_generator(
            text=message,
            image_b64=image_b64,
            audio_path=None,
            doc_b64=doc_b64,
            doc_name=doc_name,
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


@router.get("/download/{file_name}")
async def download_file(file_name: str):
    """Download a generated document."""
    import os
    from fastapi.responses import FileResponse
    
    assets_dir = os.path.abspath(os.path.join(os.getcwd(), "assets"))
    file_path = os.path.abspath(os.path.join(assets_dir, file_name))
    
    # Check for path traversal vulnerability
    if not file_path.startswith(assets_dir):
        raise HTTPException(status_code=403, detail="Access denied: Invalid file path")
        
    if not os.path.exists(file_path):
        # Case-insensitive fallback lookup
        lower_name = file_name.lower()
        matched_name = None
        if os.path.exists(assets_dir):
            for name in os.listdir(assets_dir):
                if name.lower() == lower_name:
                    matched_name = name
                    break
        if matched_name:
            file_path = os.path.join(assets_dir, matched_name)
            file_name = matched_name
        else:
            raise HTTPException(status_code=404, detail="File not found")
        
    return FileResponse(
        file_path,
        media_type="application/octet-stream",
        filename=file_name
    )


@router.get("/image-proxy")
async def image_proxy(url: str, filename: Optional[str] = None):
    """Proxy image requests to bypass CORS with robust model fallback retries."""
    import httpx
    import urllib.parse
    from fastapi.responses import Response
    
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }
    
    # Cycle through models sequentially if the default one fails
    urls_to_try = [url]
    if "pollinations.ai" in url:
        try:
            parsed = urllib.parse.urlparse(url)
            path_parts = parsed.path.split("/")
            prompt_part = path_parts[-1] if path_parts else "image"
            
            base_fallback = f"https://image.pollinations.ai/prompt/{prompt_part}?width=1024&height=1024&nologo=true&enhance=false"
            
            if "model=turbo" not in url:
                urls_to_try.append(f"{base_fallback}&model=turbo")
            if "model=sana" not in url:
                urls_to_try.append(f"{base_fallback}&model=sana")
            urls_to_try.append(f"{base_fallback}&model=flux-realism")
            urls_to_try.append(f"{base_fallback}&model=flux")
        except Exception:
            pass

    async with httpx.AsyncClient() as client:
        last_error = None
        for current_url in urls_to_try:
            try:
                resp = await client.get(current_url, headers=headers, timeout=15.0)
                if resp.status_code == 200:
                    resp_headers = {}
                    if filename:
                        resp_headers["Content-Disposition"] = f"attachment; filename={filename}"
                    return Response(
                        content=resp.content,
                        status_code=200,
                        media_type=resp.headers.get("content-type", "image/jpeg"),
                        headers=resp_headers
                    )
                else:
                    last_error = f"HTTP {resp.status_code} for {current_url}"
            except Exception as e:
                last_error = str(e)
                
        raise HTTPException(status_code=500, detail=f"Image proxy failed: {last_error}")


@router.get("/history/{session_id}")
async def get_chat_history(
    session_id: str,
    limit: int = 20,
    offset: int = 0,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Get chat history for a session with pagination (limit and offset)."""
    sb = get_supabase()

    # Query descending to get the latest messages first, then slice using offset/limit
    messages = (await sb.table("ai_chat_history") \
        .select("*") \
        .eq("school_id", school_id) \
        .eq("user_id", user["id"]) \
        .eq("session_id", session_id) \
        .order("created_at", ascending=False) \
        .limit(limit) \
        .offset(offset) \
        .aexecute()).data

    # Reverse to return the chronological ascending order (oldest first)
    messages.reverse()

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