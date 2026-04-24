import requests
import json
import uuid

SUPABASE_URL = "http://localhost:8000"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJzZXJ2aWNlX3JvbGUiLAogICAgImlzcyI6ICJzdXBhYmFzZS1kZW1vIiwKICAgICJpYXQiOiAxNjQxNzY5MjAwLAogICAgImV4cCI6IDE3OTk1MzU2MDAKfQ.DaYlNEoUrrEn2Ig7tqibS-PHK5vgusbcbo7X36XVt4Q"
ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE"

def seed():
    headers_service = {
        "apikey": SERVICE_KEY,
        "Authorization": f"Bearer {SERVICE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "return=representation"
    }
    
    headers_anon = {
        "apikey": ANON_KEY,
        "Content-Type": "application/json"
    }

    # 1. Create School
    print("Creating school...")
    school_data = {"name": "EduSHAMIIT Test Academy", "address": "Delhi, India"}
    resp = requests.post(f"{SUPABASE_URL}/rest/v1/schools", headers=headers_service, json=school_data)
    if resp.status_code in [200, 201]:
        school = resp.json()[0]
        school_id = school["id"]
        print(f"  [SUCCESS] School created: {school_id}")
    else:
        # Try to get existing
        resp = requests.get(f"{SUPABASE_URL}/rest/v1/schools?limit=1", headers=headers_service)
        if resp.status_code == 200 and resp.json():
            school_id = resp.json()[0]["id"]
            print(f"  [INFO] Using existing school: {school_id}")
        else:
            print(f"  [ERROR] Failed to create/get school: {resp.text}")
            return

    # 2. Users to create
    USERS = [
        {
            "email": "naresh.king88898@gmail.com", 
            "password": "naresh@1A", 
            "role": "student", 
            "full_name": "Naresh Student",
            "user_id": "STU-001"
        },
        {
            "email": "nehaupadhyay9119@gmail.com", 
            "password": "naresh@1A", 
            "role": "teacher", 
            "full_name": "Neha Teacher",
            "user_id": "TEA-001"
        }
    ]

    for u in USERS:
        print(f"Processing user: {u['email']}...")
        # Signup
        signup_data = {"email": u["email"], "password": u["password"]}
        resp = requests.post(f"{SUPABASE_URL}/auth/v1/signup", headers=headers_anon, json=signup_data)
        
        auth_id = None
        if resp.status_code in [200, 201]:
            auth_id = resp.json().get("id") or resp.json().get("user", {}).get("id")
            print(f"  [SUCCESS] Auth user created: {auth_id}")
        elif resp.status_code == 400 and "already registered" in resp.text:
            # Get existing ID is hard via anon signup, but let's try login to get ID
            login_resp = requests.post(f"{SUPABASE_URL}/auth/v1/token?grant_type=password", headers=headers_anon, json=signup_data)
            if login_resp.status_code == 200:
                auth_id = login_resp.json()["user"]["id"]
                print(f"  [INFO] User already exists, got ID: {auth_id}")
            else:
                print(f"  [ERROR] Could not get existing user ID: {login_resp.text}")
                continue
        else:
            print(f"  [ERROR] Signup failed: {resp.text}")
            continue

        # 3. Create Profile
        if auth_id:
            profile_data = {
                "id": auth_id,
                "school_id": school_id,
                "user_id": u["user_id"],
                "full_name": u["full_name"],
                "role": u["role"],
                "email": u["email"]
            }
            # Upsert profile
            resp = requests.post(f"{SUPABASE_URL}/rest/v1/profiles", headers=headers_service, json=profile_data)
            if resp.status_code in [200, 201]:
                print(f"  [SUCCESS] Profile created for {u['role']}")
            else:
                # Try patch
                resp = requests.patch(f"{SUPABASE_URL}/rest/v1/profiles?id=eq.{auth_id}", headers=headers_service, json=profile_data)
                if resp.status_code in [200, 204]:
                    print(f"  [SUCCESS] Profile updated for {u['role']}")
                else:
                    print(f"  [ERROR] Profile failed: {resp.text}")

if __name__ == "__main__":
    seed()
