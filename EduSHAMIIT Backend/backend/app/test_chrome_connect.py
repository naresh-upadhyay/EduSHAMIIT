import asyncio
import os
import time
import subprocess
import httpx
from jose import jwt

def generate_livekit_tokens(room_name: str):
    api_key = "devkey"
    api_secret = "secretkey_edushamiit_livekit_2026_secure"
    now = int(time.time())
    
    # 1. Admin token for room creation
    admin_claims = {
        "iss": api_key,
        "sub": "admin_backend",
        "video": {
            "roomCreate": True,
            "roomAdmin": True
        },
        "exp": now + 600
    }
    admin_token = jwt.encode(admin_claims, api_secret, algorithm="HS256")
    
    # 2. Egress participant token
    egress_claims = {
        "iss": api_key,
        "nbf": now - 10,
        "exp": now + 600,
        "sub": "EG_debug_test",
        "video": {
            "roomJoin": True,
            "room": room_name,
            "canPublish": False,
            "canPublishData": False,
            "canSubscribe": True,
            "hidden": True,
            "recorder": True
        }
    }
    egress_token = jwt.encode(egress_claims, api_secret, algorithm="HS256")
    
    return admin_token, egress_token

async def run_chrome_debug():
    room_name = "73000000-0000-0000-0000-000000000001"
    admin_token, egress_token = generate_livekit_tokens(room_name)
    
    # 1. Create Room via LiveKit Twirp API
    livekit_url = "http://livekit:7880"
    print(f"Creating LiveKit room {room_name}...")
    async with httpx.AsyncClient() as client:
        headers = {
            "Authorization": f"Bearer {admin_token}",
            "Content-Type": "application/json"
        }
        payload = {
            "name": room_name,
            "empty_timeout": 300,
            "max_participants": 50
        }
        resp = await client.post(
            f"{livekit_url}/twirp/livekit.RoomService/CreateRoom",
            headers=headers,
            json=payload,
            timeout=10.0
        )
        print(f"Twirp CreateRoom Response: {resp.status_code} - {resp.text}")
    
    # 2. Launch Chrome inside egress container
    url = f"http://localhost:7980?layout=grid&token={egress_token}&url=ws://livekit:7880"
    print(f"Launching Chrome inside egress container to load: {url}")
    
    cmd = [
        "docker", "exec", "edushamiit-egress",
        "google-chrome",
        "--headless",
        "--no-sandbox",
        "--disable-gpu",
        "--enable-logging=stderr",
        "--v=1",
        url
    ]
    
    try:
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        
        print("Chrome started. Waiting 15 seconds for WebRTC/WebSocket logs...")
        await asyncio.sleep(15)
        
        try:
            proc.terminate()
        except:
            pass
            
        stdout, stderr = await proc.communicate()
        print("\n=== CHROME STDOUT ===")
        print(stdout.decode(errors='ignore'))
        print("\n=== CHROME STDERR ===")
        print(stderr.decode(errors='ignore'))
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    asyncio.run(run_chrome_debug())
