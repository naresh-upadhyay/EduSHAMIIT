"""
Voice transcription using Google Gemini 1.5 Flash multimodal API.
Supports Hindi + English (auto-detected), MP3, WAV, OGG, WEBM, M4A.
No OpenAI key needed — 100% Gemini-powered.
"""
import base64
import os
import httpx

GEMINI_API_KEY = os.getenv("GOOGLE_API_KEY", "AIza-placeholder-google-key")
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-1.5-flash")
GEMINI_AUDIO_URL = (
    f"https://generativelanguage.googleapis.com/v1beta/models/"
    f"{GEMINI_MODEL}:generateContent?key=" + GEMINI_API_KEY
)

# Map common MIME types to the Gemini-supported subset
_MIME_MAP = {
    "audio/mpeg": "audio/mpeg",
    "audio/mp3": "audio/mpeg",
    "audio/mp4": "audio/mp4",
    "audio/m4a": "audio/mp4",
    "audio/x-m4a": "audio/mp4",
    "audio/wav": "audio/wav",
    "audio/x-wav": "audio/wav",
    "audio/webm": "audio/webm",
    "audio/ogg": "audio/ogg",
    "audio/flac": "audio/flac",
}


async def transcribe(audio_bytes: bytes, filename: str, content_type: str) -> str:
    """Transcribe audio bytes to text using Gemini 1.5 Flash.
    Handles Hindi + English mixed speech automatically.
    Returns the transcript string or a 'Transcription error: ...' message on failure.
    """
    mime = _MIME_MAP.get(content_type, "audio/mpeg")
    audio_b64 = base64.b64encode(audio_bytes).decode("utf-8")

    payload = {
        "contents": [
            {
                "parts": [
                    {
                        "inline_data": {
                            "mime_type": mime,
                            "data": audio_b64,
                        }
                    },
                    {
                        "text": (
                            "Please transcribe this audio accurately. "
                            "The speaker may use Hindi, English, or Hinglish (mixed Hindi-English). "
                            "Return ONLY the transcribed text with no extra commentary."
                        )
                    },
                ]
            }
        ],
        "generationConfig": {
            "temperature": 0.0,
            "maxOutputTokens": 2048,
        },
    }

    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            resp = await client.post(GEMINI_AUDIO_URL, json=payload)
            resp.raise_for_status()
            data = resp.json()
            candidates = data.get("candidates", [])
            if not candidates:
                return "Transcription error: No candidates returned by Gemini"
            parts = candidates[0].get("content", {}).get("parts", [])
            transcript = " ".join(p.get("text", "") for p in parts).strip()
            return transcript if transcript else "Transcription error: Empty transcript"
    except httpx.HTTPStatusError as e:
        return f"Transcription error: HTTP {e.response.status_code} — {e.response.text[:200]}"
    except Exception as e:
        return f"Transcription error: {str(e)}"


async def transcribe_file(file_path: str) -> str:
    """Transcribe an audio file on disk to text using Gemini."""
    with open(file_path, "rb") as f:
        audio_bytes = f.read()
    return await transcribe(audio_bytes, "audio.m4a", "audio/mp4")