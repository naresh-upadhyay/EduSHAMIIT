import asyncio
import os
import sys
import uuid
import httpx
from app.services.supabase_client import get_supabase

BASE_URL = "http://localhost:8000" # Internal container port or localhost:80 (via nginx). Let's use localhost:8000 inside the container since the app runs on uvicorn at 8000.

async def test_flow():
    print("--- Starting Egress Flow Test ---")
    sb = get_supabase()
    
    # 1. Reset class in DB
    class_id = "73000000-0000-0000-0000-000000000001"
    print(f"Resetting class {class_id} in database...")
    await sb.table("live_classes").update({
        "status": "scheduled",
        "is_live": False,
        "meeting_link": None,
        "recording_url": None,
        "ended_at": None
    }).eq("id", class_id).aexecute()
    
    # Also clean up any existing recording logs for this class
    await sb.table("live_class_recordings").delete().eq("live_class_id", class_id).aexecute()
    await sb.table("live_class_participants").delete().eq("live_class_id", class_id).aexecute()
    await sb.table("live_class_attendance").delete().eq("live_class_id", class_id).aexecute()
    
    # 2. Register/Login teacher
    email = f"teacher_egress_{uuid.uuid4().hex[:6]}@example.com"
    password = "Password123!"
    school_id = "11111111-1111-1111-1111-111111111111"
    
    print(f"Registering test teacher: {email}...")
    async with httpx.AsyncClient() as client:
        # Register
        reg_resp = await client.post(f"{BASE_URL}/api/auth/register", json={
            "email": email,
            "password": password,
            "full_name": "Egress Test Teacher",
            "role": "teacher",
            "school_id": school_id
        }, timeout=10.0)
        print(f"Registration response: {reg_resp.status_code} - {reg_resp.text}")
        
        # Login
        login_resp = await client.post(f"{BASE_URL}/api/auth/login", json={
            "email": email,
            "password": password,
            "role": "teacher"
        }, timeout=10.0)
        print(f"Login response: {login_resp.status_code}")
        token = login_resp.json()["data"]["token"]
        headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
        
        # 3. Create LiveKit Room
        print(f"Creating LiveKit room: {class_id}...")
        room_resp = await client.post(f"{BASE_URL}/api/livekit/rooms", headers=headers, json={
            "room_name": class_id,
            "max_participants": 50
        }, timeout=10.0)
        print(f"Create room response: {room_resp.status_code} - {room_resp.text}")
        
        # 4. Start Live Class (triggers initiate_room_egress)
        print(f"Starting live class {class_id}...")
        start_resp = await client.post(f"{BASE_URL}/api/live-classes/{class_id}/start", headers=headers, timeout=10.0)
        print(f"Start live class response: {start_resp.status_code} - {start_resp.text}")
        
        # 5. Wait for Egress to connect
        print("Waiting 35 seconds for Egress to initialize and connect to LiveKit...")
        await asyncio.sleep(35)
        
        # 6. End Live Class
        print(f"Ending live class {class_id} (will stop egress)...")
        end_resp = await client.post(f"{BASE_URL}/api/live-classes/{class_id}/end", headers=headers, timeout=15.0)
        print(f"End live class response: {end_resp.status_code} - {end_resp.text}")
        
        # 7. Wait and check database updates
        print("Waiting 10 seconds for finalization task and metadata database updates...")
        await asyncio.sleep(10)
        
        # 8. Check recordings table
        rec_res = await sb.table("live_class_recordings").select("*").eq("live_class_id", class_id).aexecute()
        print("\nRecordings in DB:")
        print(rec_res.data)
        
        class_res = await sb.table("live_classes").select("status, is_live, recording_url").eq("id", class_id).maybe_single().aexecute()
        print("\nLive Class Status in DB:")
        print(class_res.data)

if __name__ == "__main__":
    asyncio.run(test_flow())
