from openai import AsyncOpenAI
import os

oai = AsyncOpenAI(api_key=os.getenv("OPENAI_API_KEY", "sk-placeholder-openai-key"))


async def transcribe(audio_bytes: bytes, filename: str, content_type: str) -> str:
    """Transcribe audio to text using OpenAI Whisper. Supports Hindi + English (auto-detected)."""
    try:
        transcript = await oai.audio.transcriptions.create(
            model="whisper-1",
            file=(filename, audio_bytes, content_type),
            language="hi",
            response_format="text"
        )
        return transcript
    except Exception as e:
        return f"Transcription error: {str(e)}"


async def transcribe_file(file_path: str) -> str:
    """Transcribe audio file to text."""
    with open(file_path, "rb") as f:
        audio_bytes = f.read()
    return await transcribe(audio_bytes, "audio.m4a", "audio/m4a")