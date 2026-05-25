import requests
import wave
import io
import json

BASE_URL = "http://127.0.0.1:80"
STUDENT_CREDS = {"email": "naresh.king88898@gmail.com", "password": "naresh@1A"}

def get_harvard_wav():
    with open("E:\\EduSHAMIIT\\EduSHAMIIT Backend\\scratch\\harvard.wav", "rb") as f:
        return f.read()

def main():
    # 1. Login to get token
    print("Logging in...")
    resp = requests.post(f"{BASE_URL}/api/auth/login", json=STUDENT_CREDS)
    if resp.status_code != 200:
        print(f"Login failed: {resp.status_code} - {resp.text}")
        return
    
    token = resp.json()["data"]["token"]
    headers = {"Authorization": f"Bearer {token}"}
    
    # 2. Read harvard.wav data
    print("Reading harvard.wav...")
    wav_bytes = get_harvard_wav()
    
    # 3. Call /api/chat/voice
    print("Calling /api/chat/voice...")
    files = {"audio": ("audio.wav", wav_bytes, "audio/wav")}
    data = {"session_id": "test-session-voice"}
    
    resp_voice = requests.post(f"{BASE_URL}/api/chat/voice", headers=headers, files=files, data=data, stream=True)
    print(f"Status Code: {resp_voice.status_code}")
    
    if resp_voice.status_code == 200:
        print("Success! Reading stream chunks:")
        for line in resp_voice.iter_lines():
            if line:
                print(line.decode('utf-8'))
    else:
        print(f"Failed: {resp_voice.text}")

if __name__ == "__main__":
    main()
