import requests
import json

BASE_URL = "http://127.0.0.1:80"
STUDENT_CREDS = {"email": "naresh.king88898@gmail.com", "password": "naresh@1A"}

# Log in to get token
resp_login = requests.post(f"{BASE_URL}/api/auth/login", json=STUDENT_CREDS)
print("Login Response Status:", resp_login.status_code)
login_data = resp_login.json()
print("Login Response JSON:", login_data)

token = None
data_val = login_data.get("data", {})
if data_val:
    if "session" in data_val and data_val["session"]:
        token = data_val["session"]["access_token"]
    elif "access_token" in data_val:
        token = data_val["access_token"]

if not token:
    token = login_data.get("access_token") or data_val.get("token")

headers = {"Authorization": f"Bearer {token}"}

audio_file = {'audio': ('audio.mp3', b'dummy_audio_bytes', 'audio/mpeg')}
voice_payload = {'session_id': '12345678-1234-5678-1234-567812345678'}

print("Calling voice chat endpoint...")
resp = requests.post(f"{BASE_URL}/api/chat/voice", headers=headers, files=audio_file, data=voice_payload)

print(f"Status Code: {resp.status_code}")
try:
    print("Response Body:")
    print(json.dumps(resp.json(), indent=2))
except Exception:
    print("Response Text:", resp.text)
