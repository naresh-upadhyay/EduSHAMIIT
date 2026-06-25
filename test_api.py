import httpx
import json

BASE = "https://edushamiit-api-xi3m4tapoa-uc.a.run.app"

# 1. Test health
r = httpx.get(f"{BASE}/health")
print(f"Health: {r.status_code} - {r.json()}")

# 2. Test register
payload = {
    "class_name": "10A",
    "email": "naresh.king88898@gmail.com",
    "full_name": "Naresh Upadhyay",
    "password": "moti@1KJDKF",
    "role": "student",
    "school_id": "11111111-1111-1111-1111-111111111111"
}

r = httpx.post(f"{BASE}/api/auth/register", json=payload)
print(f"Register: {r.status_code}")
print(f"Response: {r.text[:200]}")