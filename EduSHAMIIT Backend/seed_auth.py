import requests
import json

SUPABASE_URL = "http://localhost:8000"
ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE"

USERS = [
    {"email": "naresh.king88898@gmail.com", "password": "naresh@1A"},
    {"email": "nehaupadhyay9119@gmail.com", "password": "naresh@1A"}
]

def seed():
    headers = {
        "apikey": ANON_KEY,
        "Content-Type": "application/json"
    }
    
    for user in USERS:
        print(f"Creating user: {user['email']}...")
        resp = requests.post(f"{SUPABASE_URL}/auth/v1/signup", headers=headers, json=user)
        if resp.status_code in [200, 201]:
            print(f"  [SUCCESS] User created or already exists.")
        else:
            print(f"  [ERROR] {resp.status_code}: {resp.text}")

if __name__ == "__main__":
    seed()
