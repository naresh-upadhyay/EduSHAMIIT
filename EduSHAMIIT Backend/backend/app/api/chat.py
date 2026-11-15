import os
import json
import uuid
from typing import Optional, List, Dict, Any
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File, Form
from fastapi.responses import StreamingResponse, JSONResponse, FileResponse

from app.middleware.auth import get_current_user, require_school_id
from app.services.langchain_agent import process_message, load_history
from app.services.supabase_client import get_supabase
from app.services.ai_assistant_service import (
    AIConversationService,
    AIMessageService,
    AIUsageService,
    AISuggestionsService
)
from app.tools import get_all_tools, filter_tools_by_role

router = APIRouter()


async def _sse_generator(text: str, image_b64: Optional[str], audio_path: Optional[str],
                          doc_b64: Optional[str], doc_name: Optional[str],
                          user: dict, session_id: str, school_id: str,
                          launched_from: Optional[str] = None):
    """Generate SSE events from the langchain agent process_message stream."""
    start_time = datetime.utcnow()
    total_token_estimate = 0
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
            launched_from=launched_from,
        ):
            if "session_id" not in chunk or not chunk["session_id"]:
                chunk["session_id"] = session_id
            event_type = chunk.get("type", "text")
            data = json.dumps(chunk, ensure_ascii=False)
            
            # Approximate token count for usage logging
            if event_type == "text":
                total_token_estimate += max(1, len(chunk.get("content", "")) // 4)
                
            yield f"event: {event_type}\ndata: {data}\n\n"

        # Log AI usage on completion
        duration_ms = int((datetime.utcnow() - start_time).total_seconds() * 1000)
        user_id = user.get("id") if user else ""
        prompt_tokens = max(10, len(text) // 4)
        active_provider = "groq" if os.environ.get("GROQ_API_KEY") else ("google" if os.environ.get("GEMINI_API_KEY") else "openai")
        active_model = "llama-3.3-70b-versatile" if active_provider == "groq" else ("gemini-1.5-flash" if active_provider == "google" else "gpt-4o")
        await AIUsageService.log_usage(
            school_id=school_id,
            user_id=user_id,
            session_id=session_id,
            provider=active_provider,
            model=active_model,
            prompt_tokens=prompt_tokens,
            completion_tokens=total_token_estimate,
            duration_ms=duration_ms,
            status="success"
        )
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
    """
    message = request.get("message", "")
    session_id = request.get("session_id", str(uuid.uuid4()))
    image_b64 = request.get("image_b64", None)
    doc_b64 = request.get("doc_b64", None)
    doc_name = request.get("doc_name", None)
    context_from = request.get("context", None)

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
            launched_from=context_from,
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

    ext = os.path.splitext(file_name)[1].lower()
    mime_map = {
        ".pdf": "application/pdf",
        ".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        ".doc": "application/msword",
        ".xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        ".xls": "application/vnd.ms-excel",
        ".pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
        ".ppt": "application/vnd.ms-powerpoint",
        ".csv": "text/csv",
        ".txt": "text/plain; charset=utf-8",
    }
    content_type = mime_map.get(ext, "application/octet-stream")

    return FileResponse(
        file_path,
        media_type=content_type,
        filename=file_name,
        headers={
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, OPTIONS",
            "Access-Control-Allow-Headers": "*",
            "Content-Disposition": f"attachment; filename=\"{file_name}\""
        }
    )


@router.get("/media/{file_name}")
async def get_chat_media(file_name: str):
    """Serve locally generated images and diagrams with direct browser caching and zero CORS restrictions."""
    media_dirs = [
        os.path.abspath(os.path.join(os.getcwd(), "assets", "generated_images")),
        os.path.abspath(os.path.join(os.getcwd(), "assets", "uploads")),
        os.path.abspath(os.path.join(os.getcwd(), "assets"))
    ]
    target_path = None
    for d in media_dirs:
        candidate = os.path.abspath(os.path.join(d, file_name))
        if candidate.startswith(d) and os.path.exists(candidate) and os.path.isfile(candidate):
            target_path = candidate
            break

    if not target_path:
        raise HTTPException(status_code=404, detail="Media not found")

    ext = os.path.splitext(file_name)[1].lower()
    media_types = {
        ".png": "image/png",
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".webp": "image/webp",
        ".svg": "image/svg+xml",
        ".gif": "image/gif"
    }
    content_type = media_types.get(ext, "image/png")

    return FileResponse(
        target_path,
        media_type=content_type,
        headers={
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, OPTIONS",
            "Access-Control-Allow-Headers": "*",
            "Cache-Control": "public, max-age=604800"
        }
    )


@router.get("/image-proxy")
async def image_proxy(url: str, filename: Optional[str] = None):
    """Proxy image requests to bypass CORS with robust model fallback retries."""
    import httpx
    import urllib.parse
    from fastapi.responses import Response
    
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept": "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8"
    }
    
    urls_to_try = []
    prompt_part = "image"
    if "pollinations.ai" in url:
        try:
            parsed = urllib.parse.urlparse(url)
            path_parts = parsed.path.split("/")
            raw_prompt = path_parts[-1] if path_parts else "image"
            clean_prompt = urllib.parse.quote(urllib.parse.unquote(raw_prompt))
            prompt_part = clean_prompt
            
            # 1. Clean, free URL with no model restriction and fast 800x800 resolution
            urls_to_try.append(f"https://image.pollinations.ai/prompt/{clean_prompt}?width=800&height=800&nologo=true")
            # 2. Simple clean URL
            urls_to_try.append(f"https://image.pollinations.ai/prompt/{clean_prompt}?nologo=true")
            # 3. Model fallbacks
            urls_to_try.append(f"https://image.pollinations.ai/prompt/{clean_prompt}?model=flux&nologo=true")
            # 4. Original URL requested
            if url not in urls_to_try:
                urls_to_try.append(url)
        except Exception:
            urls_to_try = [url]
    else:
        urls_to_try = [url]

    async with httpx.AsyncClient(follow_redirects=True) as client:
        for current_url in urls_to_try:
            try:
                resp = await client.get(current_url, headers=headers, timeout=20.0)
                if resp.status_code == 200 and len(resp.content) > 500:
                    resp_headers = {
                        "Access-Control-Allow-Origin": "*",
                        "Access-Control-Allow-Methods": "GET, OPTIONS",
                        "Access-Control-Allow-Headers": "*",
                        "Cache-Control": "public, max-age=86400"
                    }
                    if filename:
                        resp_headers["Content-Disposition"] = f"attachment; filename={filename}"
                    return Response(
                        content=resp.content,
                        status_code=200,
                        media_type=resp.headers.get("content-type", "image/jpeg"),
                        headers=resp_headers
                    )
            except Exception:
                continue

    # Graceful fallback: return a generated SVG placeholder if remote generation is temporarily unavailable
    clean_label = urllib.parse.unquote(prompt_part).replace("<", "").replace(">", "").strip()[:50]
    svg_content = f'''<svg xmlns="http://www.w3.org/2000/svg" width="800" height="500" viewBox="0 0 800 500">
      <defs>
        <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" style="stop-color:#0f172a;stop-opacity:1" />
          <stop offset="50%" style="stop-color:#1e293b;stop-opacity:1" />
          <stop offset="100%" style="stop-color:#0f172a;stop-opacity:1" />
        </linearGradient>
      </defs>
      <rect width="100%" height="100%" fill="url(#bg)" rx="16"/>
      <circle cx="400" cy="190" r="54" fill="#2563eb" fill-opacity="0.18"/>
      <circle cx="400" cy="190" r="42" fill="#3b82f6" fill-opacity="0.25"/>
      <path d="M380 205 L395 185 L405 197 L415 178 L430 205 Z" fill="#60a5fa"/>
      <circle cx="388" cy="172" r="4" fill="#93c5fd"/>
      <text x="400" y="285" fill="#f8fafc" font-family="-apple-system, BlinkMacSystemFont, Segoe UI, Roboto, Helvetica, Arial, sans-serif" font-size="18" font-weight="700" text-anchor="middle">Generated AI Artwork</text>
      <text x="400" y="318" fill="#94a3b8" font-family="-apple-system, BlinkMacSystemFont, Segoe UI, Roboto, Helvetica, Arial, sans-serif" font-size="13" text-anchor="middle">{clean_label}</text>
      <text x="400" y="360" fill="#38bdf8" font-family="-apple-system, BlinkMacSystemFont, Segoe UI, Roboto, Helvetica, Arial, sans-serif" font-size="11" font-weight="600" text-anchor="middle">EduSHAMIIT Creative AI Studio</text>
    </svg>'''

    return Response(
        content=svg_content.encode("utf-8"),
        status_code=200,
        media_type="image/svg+xml",
        headers={
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, OPTIONS",
            "Access-Control-Allow-Headers": "*",
            "Cache-Control": "public, max-age=300"
        }
    )


@router.get("/history/{session_id}")
async def get_chat_history(
    session_id: str,
    limit: int = 50,
    offset: int = 0,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Get chat history for a session with pagination."""
    sb = get_supabase()

    messages = (await sb.table("ai_chat_history") \
        .select("*") \
        .eq("school_id", school_id) \
        .eq("user_id", user["id"]) \
        .eq("session_id", session_id) \
        .order("created_at", ascending=False) \
        .limit(limit) \
        .offset(offset) \
        .aexecute()).data or []

    # Chronological order
    messages.reverse()

    return {"success": True, "school_id": school_id, "data": {"messages": messages}}


# ══════════════════════════════════════════════════════════════════════════════
#  Conversations Management (CRUD, Search, Pin, Archive, Export)
# ══════════════════════════════════════════════════════════════════════════════

@router.get("/sessions")
@router.get("/conversations")
async def get_chat_conversations(
    search: Optional[str] = None,
    archived: bool = False,
    limit: int = 50,
    offset: int = 0,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Get all conversations for the logged in user with search and filters."""
    try:
        user_id = user["id"]
        conversations = await AIConversationService.list_conversations(
            user_id=user_id,
            school_id=school_id,
            search=search,
            is_archived=archived,
            limit=limit,
            offset=offset
        )

        # Backwards compatibility session format
        sessions = [
            {
                "session_id": c["id"],
                "title": c.get("title", "New Chat"),
                "last_message_at": c.get("last_message_at") or c.get("updated_at"),
                "last_message": c.get("last_message", ""),
                "is_pinned": c.get("is_pinned", False),
                "is_archived": c.get("is_archived", False),
                "context_module": c.get("context_module", "general"),
            }
            for c in conversations
        ]

        return {
            "success": True,
            "school_id": school_id,
            "data": {
                "sessions": sessions,
                "conversations": conversations,
            }
        }
    except Exception as e:
        return {"success": False, "message": f"Error fetching conversations: {str(e)}", "data": {"sessions": [], "conversations": []}}


@router.post("/conversations")
async def create_chat_conversation(
    payload: dict,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Create a new conversation session."""
    title = payload.get("title", "New Chat")
    context_module = payload.get("context_module", "general")
    model = payload.get("model", "gemini-1.5-flash")

    conv = await AIConversationService.create_conversation(
        user_id=user["id"],
        school_id=school_id,
        title=title,
        context_module=context_module,
        model=model
    )
    return {"success": True, "data": conv}


@router.get("/conversations/{conv_id}")
async def get_single_conversation(
    conv_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Get single conversation metadata."""
    conv = await AIConversationService.get_conversation(conv_id, user["id"], school_id)
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")
    return {"success": True, "data": conv}


@router.patch("/conversations/{conv_id}")
async def update_conversation(
    conv_id: str,
    payload: dict,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Rename, pin/unpin, archive/restore a conversation."""
    title = payload.get("title")
    is_pinned = payload.get("is_pinned")
    is_archived = payload.get("is_archived")
    context_module = payload.get("context_module")

    updated = await AIConversationService.update_conversation(
        conv_id=conv_id,
        user_id=user["id"],
        school_id=school_id,
        title=title,
        is_pinned=is_pinned,
        is_archived=is_archived,
        context_module=context_module
    )
    if not updated:
        raise HTTPException(status_code=404, detail="Conversation not found or failed to update")
    return {"success": True, "data": updated}


@router.delete("/conversations/{conv_id}")
@router.delete("/session/{session_id}")
async def delete_conversation(
    conv_id: Optional[str] = None,
    session_id: Optional[str] = None,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Delete all messages and metadata for a specific session."""
    target_id = conv_id or session_id
    if not target_id:
        raise HTTPException(status_code=400, detail="Conversation ID is required")
        
    await AIConversationService.delete_conversation(target_id, user["id"], school_id)
    return {"success": True, "message": "Conversation deleted successfully"}


@router.get("/conversations/{conv_id}/export")
async def export_conversation(
    conv_id: str,
    format: str = Query("json", pattern="^(json|text)$"),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Export conversation content in JSON or Text format."""
    try:
        data = await AIConversationService.export_conversation(conv_id, user["id"], school_id, format_type=format)
        return {"success": True, "data": data}
    except Exception as e:
        raise HTTPException(status_code=404, detail=str(e))


# ══════════════════════════════════════════════════════════════════════════════
#  Message Feedback, Suggestions, Tools & Usage
# ══════════════════════════════════════════════════════════════════════════════

@router.post("/messages/{message_id}/feedback")
async def submit_message_feedback(
    message_id: str,
    payload: dict,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Submit rating and feedback for an AI response."""
    rating = payload.get("rating", 1) # 1 or -1
    comment = payload.get("comment") or payload.get("feedback_text")
    category = payload.get("category")

    res = await AIMessageService.submit_feedback(
        message_id=message_id,
        user_id=user["id"],
        school_id=school_id,
        rating=rating,
        feedback_text=comment,
        category=category
    )
    return res


@router.get("/suggestions")
async def get_smart_suggestions(
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Get contextual quick actions and suggested questions based on user's role and past activity."""
    role = user.get("role", "admin")
    user_id = user.get("id", "")
    context_data = await AISuggestionsService.get_dynamic_suggestions(role, user_id, school_id)
    return {"success": True, "data": context_data}


@router.get("/models")
async def get_available_models():
    """List supported AI models and current defaults."""
    sb = get_supabase()
    res = await sb.table("ai_provider_configs").select("*").eq("is_enabled", True).aexecute()
    models = res.data or []
    return {"success": True, "data": {"models": models, "default": "gemini-1.5-flash"}}


@router.get("/usage")
async def get_ai_usage_stats(
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Get AI usage metrics and token totals."""
    stats = await AIUsageService.get_usage_summary(school_id, user.get("id"))
    return stats


@router.get("/tools")
async def list_available_tools(
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """List available ERP tools permitted for current user role."""
    role = user.get("role", "guest")
    all_tools = get_all_tools(school_id)
    permitted = filter_tools_by_role(all_tools, role, school_id)

    tools_info = [
        {
            "name": t.name,
            "description": t.description,
            "args_schema": str(getattr(t, "args_schema", ""))
        }
        for t in permitted
    ]
    return {"success": True, "data": {"tools": tools_info}}


@router.post("/upload")
async def upload_chat_attachment(
    file: UploadFile = File(...),
    session_id: Optional[str] = Form(None),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Upload an attachment (image, pdf, xlsx, doc, etc.) for AI Chat and return public URL."""
    try:
        content = await file.read()
        file_ext = os.path.splitext(file.filename)[1].lower() if file.filename else ".bin"
        safe_name = f"{uuid.uuid4().hex[:12]}_{os.path.basename(file.filename or 'upload' + file_ext)}"

        # Save locally to assets/uploads
        upload_dir = os.path.join(os.getcwd(), "assets", "uploads")
        os.makedirs(upload_dir, exist_ok=True)
        local_path = os.path.join(upload_dir, safe_name)
        with open(local_path, "wb") as f:
            f.write(content)

        file_url = f"/api/chat/media/{safe_name}"

        # Try uploading to Supabase Storage bucket 'ai-chat-attachments'
        try:
            sb = get_supabase()
            storage_path = f"{school_id}/{user['id']}/{safe_name}"
            sb.storage.from_("ai-chat-attachments").upload(
                path=storage_path,
                file=content,
                file_options={"content-type": file.content_type or "application/octet-stream"}
            )
            public_url_resp = sb.storage.from_("ai-chat-attachments").get_public_url(storage_path)
            if public_url_resp:
                file_url = public_url_resp
        except Exception as storage_err:
            print(f"[Upload] Supabase Storage upload fallback: {storage_err}")

        return {
            "success": True,
            "data": {
                "file_name": file.filename,
                "safe_name": safe_name,
                "file_url": file_url,
                "file_size": len(content),
                "content_type": file.content_type
            }
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Attachment upload failed: {str(e)}")
