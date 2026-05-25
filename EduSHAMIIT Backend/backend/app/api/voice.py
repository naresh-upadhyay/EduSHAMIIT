"""
Voice API — Audio transcription only.

POST /api/chat/voice/transcribe
  Accepts audio upload, returns the transcript as plain JSON.
  The Flutter client then sends the transcript via the normal
  POST /api/chat/message endpoint (SSE streaming).

This keeps voice and chat completely separate, reusing the
battle-tested text message flow for AI responses.
"""
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from app.middleware.auth import get_current_user
from app.services.whisper_service import transcribe

router = APIRouter()

SUPPORTED_AUDIO_TYPES = [
    "audio/mpeg", "audio/mp3", "audio/mp4", "audio/m4a",
    "audio/wav", "audio/webm", "audio/ogg", "audio/flac",
    "audio/x-m4a", "audio/x-wav",
]


@router.post("/voice/transcribe")
async def transcribe_audio(
    audio: UploadFile = File(...),
    locale: str | None = Form(None),
    user: dict = Depends(get_current_user),
):
    """
    Transcribe an audio file and return the text.

    Returns:
        { "success": true, "data": { "transcript": "..." } }
    """
    if not audio.content_type or audio.content_type not in SUPPORTED_AUDIO_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported audio type: {audio.content_type}. "
                   f"Supported: {', '.join(SUPPORTED_AUDIO_TYPES)}",
        )

    audio_bytes = await audio.read()

    if len(audio_bytes) == 0:
        raise HTTPException(status_code=400, detail="Empty audio file received.")
    if len(audio_bytes) > 25 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Audio too large. Max 25MB.")

    print(
        f"[TRANSCRIBE] file={audio.filename}, "
        f"type={audio.content_type}, size={len(audio_bytes)} bytes, locale={locale}",
        flush=True,
    )

    transcript = await transcribe(
        audio_bytes,
        audio.filename or "audio.wav",
        audio.content_type,
        locale=locale,
    )

    print(f"[TRANSCRIBE] result={transcript[:120]}", flush=True)

    if transcript.startswith("Transcription error:"):
        raise HTTPException(status_code=422, detail=transcript)

    return {
        "success": True,
        "data": {"transcript": transcript},
    }


# Keep the old /voice endpoint alive but redirect to the new flow
# (returns a helpful message if someone calls it directly)
@router.post("/voice")
async def voice_chat_deprecated(
    user: dict = Depends(get_current_user),
):
    """Deprecated — use POST /api/chat/voice/transcribe instead."""
    raise HTTPException(
        status_code=410,
        detail=(
            "This endpoint is no longer used. "
            "POST audio to /api/chat/voice/transcribe to get a transcript, "
            "then send the text via /api/chat/message."
        ),
    )
