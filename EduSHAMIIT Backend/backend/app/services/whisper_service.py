"""
Voice transcription service for EduSHAMIIT.

Priority order:
  1. Google Gemini (multimodal) – supports M4A / WebM / WAV / OGG
  2. Google Web Speech API (free, no API key) via SpeechRecognition – WAV only

If audio is WAV, fallback always works.
If audio is M4A/WebM, fallback requires ffmpeg (optional).
"""
import base64
import os
import asyncio
import io
import struct
import wave
import httpx

GEMINI_API_KEY = os.getenv("GOOGLE_API_KEY", "")
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-1.5-flash")

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


def _is_wav(data: bytes) -> bool:
    """Check if bytes are a valid WAV/RIFF file."""
    return (
        len(data) >= 12
        and data[0:4] == b"RIFF"
        and data[8:12] == b"WAVE"
    )


def _convert_to_wav_via_ffmpeg(audio_bytes: bytes) -> bytes | None:
    """Try to convert audio to WAV using ffmpeg. Returns None if ffmpeg not available."""
    import subprocess
    import tempfile

    infile_path = None
    outfile_path = None
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".audio") as infile:
            infile.write(audio_bytes)
            infile_path = infile.name

        outfile_path = infile_path + ".wav"
        cmd = [
            "ffmpeg", "-y", "-i", infile_path,
            "-acodec", "pcm_s16le", "-ar", "16000", "-ac", "1",
            outfile_path
        ]
        result = subprocess.run(
            cmd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=30,
        )
        if result.returncode == 0:
            with open(outfile_path, "rb") as f:
                return f.read()
        return None
    except (FileNotFoundError, subprocess.TimeoutExpired, Exception):
        return None
    finally:
        for p in [infile_path, outfile_path]:
            if p:
                try:
                    os.unlink(p)
                except Exception:
                    pass


def _speech_recognition_transcribe(wav_bytes: bytes, locale: str | None = None) -> str | None:
    """
    Transcribe WAV bytes using Google Web Speech API (free, no API key).
    Returns transcript string or None on failure.
    """
    try:
        import speech_recognition as sr
        import tempfile

        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            tmp.write(wav_bytes)
            tmp_path = tmp.name

        try:
            r = sr.Recognizer()
            with sr.AudioFile(tmp_path) as source:
                audio = r.record(source)

            from concurrent.futures import ThreadPoolExecutor

            def run_rec(lang):
                try:
                    return r.recognize_google(audio, language=lang, show_all=True)
                except Exception:
                    return None

            with ThreadPoolExecutor(max_workers=2) as executor:
                future_hi = executor.submit(run_rec, "hi-IN")
                future_en = executor.submit(run_rec, "en-US")

                res_hi = future_hi.result()
                res_en = future_en.result()

            def parse_res(res):
                if not res or not isinstance(res, dict) or 'alternative' not in res or not res['alternative']:
                    return None, 0.0
                top = res['alternative'][0]
                text = top.get('transcript', '')
                conf = top.get('confidence', 0.0)
                if text and conf == 0.0:
                    conf = 0.5
                return text, conf

            text_hi, conf_hi = parse_res(res_hi)
            text_en, conf_en = parse_res(res_en)

            print(f"[WHISPER] Google speech parallel results: hi='{text_hi}' (conf={conf_hi}), en='{text_en}' (conf={conf_en})", flush=True)

            # If user explicitly requested English, strongly prioritize the English transcript
            if locale and locale.lower().startswith("en"):
                if text_en:
                    print(f"[WHISPER] User selected English. Returning en-US transcript: '{text_en}'", flush=True)
                    return text_en
                if text_hi:
                    print(f"[WHISPER] User selected English but only hi-IN got result. Returning hi-IN: '{text_hi}'", flush=True)
                    return text_hi

            # If user explicitly requested Hindi, strongly prioritize the Hindi transcript
            if locale and locale.lower().startswith("hi"):
                if text_hi:
                    print(f"[WHISPER] User selected Hindi. Returning hi-IN transcript: '{text_hi}'", flush=True)
                    return text_hi
                if text_en:
                    print(f"[WHISPER] User selected Hindi but only en-US got result. Returning en-US: '{text_en}'", flush=True)
                    return text_en

            # Automatic bilingual detection logic if no explicit locale is requested
            if text_hi and text_en:
                has_devanagari = any(0x0900 <= ord(c) <= 0x097F for c in text_hi)
                if has_devanagari:
                    # Balanced check: if English is quite confident (>0.82) and performs reasonably well, prefer English
                    if conf_en > 0.82 and conf_en > conf_hi + 0.05:
                        return text_en
                    return text_hi
                else:
                    return text_en
            elif text_hi:
                return text_hi
            elif text_en:
                return text_en
            return None
        except Exception as e:
            print(f"[WHISPER] SpeechRecognition error: {e}", flush=True)
            return None
        finally:
            try:
                os.unlink(tmp_path)
            except Exception:
                pass
    except ImportError:
        print("[WHISPER] SpeechRecognition not installed", flush=True)
        return None


async def _try_gemini(audio_bytes: bytes, content_type: str, locale: str | None = None) -> str | None:
    """
    Try to transcribe via Gemini. Returns transcript or None.
    Won't raise – any failure returns None.
    """
    if not GEMINI_API_KEY or GEMINI_API_KEY == "AIza-placeholder-google-key":
        return None

    mime = _MIME_MAP.get(content_type, "audio/mpeg")
    audio_b64 = base64.b64encode(audio_bytes).decode("utf-8")

    instruction = (
        "Please transcribe this audio accurately. "
        "The speaker may use Hindi, English, or Hinglish (mixed Hindi-English). "
        "Return ONLY the transcribed text with no extra commentary."
    )
    if locale:
        if locale.lower().startswith("hi"):
            instruction += (
                " The speaker wants the transcription in Hindi (using Devanagari script). "
                "Even if they use Hinglish or English words, write it in Devanagari Hindi transliteration if appropriate."
            )
        elif locale.lower().startswith("en"):
            instruction += (
                " The speaker wants the transcription strictly in English (Latin script). "
                "Even if they speak with an accent or use minor Hindi/Hinglish fillers, write the output in English words using English alphabet."
            )

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
                        "text": instruction
                    },
                ]
            }
        ],
        "generationConfig": {
            "temperature": 0.0,
            "maxOutputTokens": 2048,
        },
    }

    models_to_try = [GEMINI_MODEL]
    if GEMINI_MODEL != "gemini-2.0-flash":
        models_to_try.append("gemini-2.0-flash")

    for model in models_to_try:
        url = (
            f"https://generativelanguage.googleapis.com/v1beta/models/"
            f"{model}:generateContent?key={GEMINI_API_KEY}"
        )
        for attempt in range(2):
            try:
                async with httpx.AsyncClient(timeout=45.0) as client:
                    resp = await client.post(url, json=payload)
                    if resp.status_code == 429:
                        if attempt == 0:
                            await asyncio.sleep(2.0)
                            continue
                        break  # give up on this model
                    resp.raise_for_status()
                    data = resp.json()
                    candidates = data.get("candidates", [])
                    if not candidates:
                        break
                    parts = candidates[0].get("content", {}).get("parts", [])
                    transcript = " ".join(p.get("text", "") for p in parts).strip()
                    if transcript:
                        print(f"[WHISPER] Gemini ({model}) success", flush=True)
                        return transcript
                    break
            except Exception as e:
                print(f"[WHISPER] Gemini error ({model}): {e}", flush=True)
                break

    return None


async def transcribe(audio_bytes: bytes, filename: str, content_type: str, locale: str | None = None) -> str:
    """
    Transcribe audio bytes to text.

    Flow:
      1. Try Gemini (multimodal) – handles M4A, WAV, WebM etc.
      2. If WAV → SpeechRecognition (Google Web Speech, free, no key)
      3. If non-WAV → try ffmpeg conversion → SpeechRecognition
      4. If all fail → return error message

    Returns transcript string, or 'Transcription error: ...' on total failure.
    """
    print(
        f"[WHISPER] Transcribing: file={filename}, "
        f"type={content_type}, size={len(audio_bytes)} bytes, locale={locale}",
        flush=True,
    )

    # ── Step 1: Try Gemini ──────────────────────────────────────
    transcript = await _try_gemini(audio_bytes, content_type, locale)
    if transcript:
        return transcript

    print("[WHISPER] Gemini unavailable/failed, trying SpeechRecognition fallback", flush=True)

    # ── Step 2: SpeechRecognition with WAV ─────────────────────
    wav_bytes = audio_bytes if _is_wav(audio_bytes) else None

    # ── Step 3: If not WAV, try ffmpeg conversion ───────────────
    if wav_bytes is None:
        print("[WHISPER] Not WAV, attempting ffmpeg conversion...", flush=True)
        converted = _convert_to_wav_via_ffmpeg(audio_bytes)
        if converted and _is_wav(converted):
            wav_bytes = converted
            print(f"[WHISPER] ffmpeg conversion OK ({len(wav_bytes)} bytes)", flush=True)
        else:
            print("[WHISPER] ffmpeg not available or conversion failed", flush=True)

    if wav_bytes:
        result = _speech_recognition_transcribe(wav_bytes, locale)
        if result:
            print(f"[WHISPER] SpeechRecognition success: {result[:80]}", flush=True)
            return result
        print("[WHISPER] SpeechRecognition returned no result", flush=True)

    # ── Step 4: All failed ──────────────────────────────────────
    if not _is_wav(audio_bytes) and wav_bytes is None:
        return (
            "Transcription error: Audio format not supported without ffmpeg. "
            "Please try again or type your message."
        )
    return "Transcription error: Could not understand the audio. Please speak clearly and try again."


async def transcribe_file(file_path: str, locale: str | None = None) -> str:
    """Transcribe an audio file on disk."""
    with open(file_path, "rb") as f:
        audio_bytes = f.read()
    ext = file_path.rsplit(".", 1)[-1].lower()
    mime_map = {"wav": "audio/wav", "mp3": "audio/mpeg", "m4a": "audio/mp4",
                "webm": "audio/webm", "ogg": "audio/ogg"}
    content_type = mime_map.get(ext, "audio/mpeg")
    return await transcribe(audio_bytes, file_path, content_type, locale)