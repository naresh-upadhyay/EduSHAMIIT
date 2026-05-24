"""Voice API - Audio upload, transcription via Whisper, and SSE streaming response."""
import uuid
import json
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from fastapi.responses import StreamingResponse
from app.middleware.auth import get_current_user
from app.services.whisper_service import transcribe
from app.services.langchain_agent import process_message

router = APIRouter()

SUPPORTED_AUDIO_TYPES = [
    "audio/mpeg", "audio/mp3", "audio/mp4", "audio/m4a",
    "audio/wav", "audio/webm", "audio/ogg", "audio/flac",
    "audio/x-m4a", "audio/x-wav",
]


@router.post("/voice")
async def voice_chat(
    audio: UploadFile = File(...),
    session_id: str = Form(""),
    user: dict = Depends(get_current_user),
):
    """Upload audio, transcribe via Whisper, and stream AI response via SSE."""
    if not audio.content_type:
        raise HTTPException(status_code=400, detail="Could not determine audio content type")
    if audio.content_type not in SUPPORTED_AUDIO_TYPES:
        raise HTTPException(status_code=400, detail=f"Unsupported audio type: {audio.content_type}")
    audio_bytes = await audio.read()
    if len(audio_bytes) == 0:
        raise HTTPException(status_code=400, detail="Empty audio file")
    if len(audio_bytes) > 25 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Audio too large. Max 25MB.")
    if not session_id:
        session_id = str(uuid.uuid4())
    school_id = user.get("school_id", "")
    transcript = await transcribe(audio_bytes, audio.filename or "audio.m4a", audio.content_type)
    if transcript.startswith("Transcription error:"):
        raise HTTPException(status_code=500, detail=transcript)

    async def event_generator():
        """Generate SSE events."""
        try:
            yield "data: " + json.dumps({"type": "transcript", "content": transcript}) + "\n\n"
            async for chunk in process_message(text=transcript, user=user, session_id=session_id, school_id=school_id):
                yield "data: " + json.dumps(chunk) + "\n\n"
        except Exception as e:
            yield "data: " + json.dumps({"type": "error", "content": str(e)}) + "\n\n"
            yield "data: " + json.dumps({"type": "done"}) + "\n\n"

    return StreamingResponse(
        event_generator(), media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Session-Id": session_id,
        },
    )
