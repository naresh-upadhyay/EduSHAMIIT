import os
import time
import httpx
from jose import jwt

def test_start_egress(room_name: str):
    api_key = "devkey"
    api_secret = "secretkey"
    livekit_url = "http://livekit:7880"
    
    now = int(time.time())
    admin_claims = {
        "iss": api_key,
        "sub": "admin_backend",
        "video": {
            "roomRecord": True,
            "roomAdmin": True
        },
        "exp": now + 600
    }
    admin_token = jwt.encode(admin_claims, api_secret, algorithm="HS256")
    
    payload = {
        "room_name": room_name,
        "layout": "grid",
        "file": {
            "filepath": f"live-classes/{room_name}.mp4",
            "s3": {
                "access_key": "minio_admin",
                "secret": "minio_password_2026",
                "region": "us-east-1",
                "endpoint": "http://minio:9000",
                "bucket": "live-classes",
                "force_path_style": True
            }
        }
    }
    
    headers = {
        "Authorization": f"Bearer {admin_token}",
        "Content-Type": "application/json"
    }
    
    url = f"{livekit_url}/twirp/livekit.Egress/StartRoomCompositeEgress"
    print(f"POSTing to {url} with headers {headers} and json {payload}")
    
    resp = httpx.post(url, headers=headers, json=payload, timeout=10.0)
    print("Response Status:", resp.status_code)
    print("Response Body:", resp.text)

if __name__ == "__main__":
    test_start_egress("test_room_123")
