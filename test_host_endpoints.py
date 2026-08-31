import sys
import os
import requests
import json
import base64
import hmac
import hashlib

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

API_BASE_URL = "http://127.0.0.1:8082"
JWT_SECRET = "super-secret-jwt-token-with-at-least-32-characters-long"
ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNjAwMDAwMDAwLCJleHAiOjIwMDAwMDAwMDB9.V-Nq7_uazFUYvZFXyq_whGnFkWy4W_3o4k6m04sGc5Q"

def b64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("utf-8")

def generate_jwt(payload: dict, secret: str) -> str:
    header = {"typ": "JWT", "alg": "HS256"}
    header_b64 = b64url_encode(json.dumps(header).encode("utf-8"))
    payload_b64 = b64url_encode(json.dumps(payload).encode("utf-8"))
    signing_input = f"{header_b64}.{payload_b64}".encode("utf-8")
    signature = hmac.new(secret.encode("utf-8"), signing_input, hashlib.sha256).digest()
    sig_b64 = b64url_encode(signature)
    return f"{header_b64}.{payload_b64}.{sig_b64}"

def main():
    print("=" * 90)
    print("🚀 LIVE HTTP API ENDPOINT HEALTH & FUNCTIONALITY AUDIT VIA KONG (PORT 8000)")
    print("=" * 90)

    user_id = "cd2b56cb-1961-4180-9431-c7ab6c33589b"
    school_id = "11111111-1111-1111-1111-111111111111"
    role = "super_admin"
    email = "nareshkumarupadhyay48@gmail.com"
    full_name = "Vinay Upadhyay Ji"

    print(f"👤 Auth Context   : {full_name} ({user_id})")
    print(f"🏫 School ID      : {school_id}")
    print(f"🔑 Role & Email   : {role} | {email}\n")

    payload = {"sub": user_id, "school_id": school_id, "role": role, "email": email, "exp": 9999999999}
    token = generate_jwt(payload, JWT_SECRET)
    
    headers = {
        "apikey": ANON_KEY,
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "X-School-Id": school_id
    }

    endpoints = [
        ("GET", "/api/lookups?tab=all&page=1&page_size=10", "Lookup Keys Catalog"),
        ("GET", "/api/classes/stats", "Academic Classes Overview Stats"),
        ("GET", "/api/classes", "Academic Classes List"),
        ("GET", "/api/classes/subjects/all", "Subjects Catalog"),
        ("GET", "/api/attendance/config", "Attendance Configuration & Policies"),
        ("GET", "/api/attendance/summary?date=2026-08-30", "Daily Attendance Summary"),
        ("GET", "/api/attendance/insights/overview", "Attendance AI Insights Overview"),
        ("GET", "/api/leave/types", "Leave Types"),
        ("GET", "/api/leave/balances?academic_year=2026-27", "Leave Balances for Academic Year"),
        ("GET", "/api/leave/applications", "Leave Applications List"),
        ("GET", "/api/calendar/events?start_date=2026-08-01&end_date=2026-08-31", "Calendar Events Projection"),
        ("GET", "/api/notices", "Notices & Announcements Feed"),
        ("GET", "/api/admin/system-config", "System Configuration (Theme & Branding)"),
    ]

    passed = 0
    failed = 0

    for method, path, description in endpoints:
        url = f"{API_BASE_URL}{path}"
        try:
            r = requests.request(method, url, headers=headers, timeout=10)
            if r.status_code == 200:
                passed += 1
                try:
                    data = r.json()
                    item_count = len(data.get("data", [])) if isinstance(data.get("data"), list) else "OK"
                    print(f"  ✅ [200 OK] {method:<5} {path:<62} | {description} ({item_count})", flush=True)
                except Exception:
                    print(f"  ✅ [200 OK] {method:<5} {path:<62} | {description}", flush=True)
            else:
                failed += 1
                print(f"  ❌ [{r.status_code}] {method:<5} {path:<62} | {description} -> {r.text[:80]}", flush=True)
        except Exception as e:
            failed += 1
            print(f"  ❌ [ERR]    {method:<5} {path:<62} | {description} -> {e}", flush=True)

    print("\n" + "=" * 90)
    print(f"📊 LIVE API TEST RESULTS : {passed} PASSED | {failed} FAILED (Total: {len(endpoints)})")
    print(f"🎯 SUCCESS RATE          : {(passed / len(endpoints)) * 100:.1f}%")
    print("=" * 90)

if __name__ == "__main__":
    main()
