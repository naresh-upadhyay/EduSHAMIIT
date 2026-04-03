import os
import uuid


async def synthesize_speech(text: str, language_code: str = "hi-IN") -> str:
    """Convert text to speech audio URL. Returns URL to the generated audio file."""
    try:
        from google.cloud import texttospeech

        client = texttospeech.TextToSpeechClient()

        input_text = texttospeech.SynthesisInput(text=text)
        voice = texttospeech.VoiceSelectionParams(
            language_code=language_code,
            ssml_gender=texttospeech.SsmlVoiceGender.NEUTRAL
        )
        audio_config = texttospeech.AudioConfig(
            audio_encoding=texttospeech.AudioEncoding.MP3
        )

        response = client.synthesize_speech(
            input=input_text, voice=voice, audio_config=audio_config
        )

        # Save to local file
        os.makedirs("static/tts", exist_ok=True)
        filename = f"static/tts/{uuid.uuid4()}.mp3"
        with open(filename, "wb") as out:
            out.write(response.audio_content)

        return f"/{filename}"
    except Exception as e:
        print(f"TTS error: {e}")
        return ""