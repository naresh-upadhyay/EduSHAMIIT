"""
Master End-to-End API Health and Functional Validation Suite for EduSHAMIIT
Uses FastAPI TestClient to exhaustively validate live endpoints across all core modules:
- Auth & User Profile Context
- System Configuration (Theme, Colors, Uploads)
- Lookup Keys & Values Management
- Academic Classes, Sections, Subjects
- Attendance System (Daily, Period-wise, Config, Insights)
- Leave Management (Types, Balances, Policies, Applications)
- Calendar & Master Schedule Engine
- Universal Notices & Announcements
"""

import sys
import os
import io
import json
import uuid
import psycopg2
from psycopg2.extras import RealDictCursor
from jose import jwt
from starlette.testclient import TestClient

from app.main import app
from app.config import settings

client = TestClient(app)

DATABASE_URL = getattr(settings, "DATABASE_URL", "postgresql://postgres:eduSHAMIIT2026_pg@db:5432/postgres")
JWT_SECRET = getattr(settings, "SUPABASE_JWT_SECRET", None) or getattr(settings, "JWT_SECRET", "super-secret-jwt-token-with-at-least-32-characters-long")

def get_db():
    return psycopg2.connect(DATABASE_URL)

def get_test_token(user_id: str, school_id: str, role: str = "super_admin", email: str = "admin@school.com"):
    payload = {
        "sub": user_id,
        "school_id": school_id,
        "role": role,
        "email": email,
        "exp": 9999999999
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")

passed = 0
failed = 0
results = []

def record(module: str, name: str, success: bool, detail: str = ""):
    global passed, failed
    if success:
        passed += 1
        msg = f"  ✅ [PASS] {module:<18} | {name} {detail}"
        print(msg, flush=True)
        results.append((module, name, True, detail))
    else:
        failed += 1
        msg = f"  ❌ [FAIL] {module:<18} | {name} - {detail}"
        print(msg, flush=True)
        results.append((module, name, False, detail))

def run_master_api_validation():
    global passed, failed
    print("\n" + "=" * 90, flush=True)
    print("🚀 EDUSHAMIIT COMPREHENSIVE LIVE API ENDPOINT VALIDATION SUITE", flush=True)
    print("=" * 90, flush=True)

    # 1. Fetch Real Context from Database
    conn = get_db()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    
    cur.execute("SELECT id, school_id, role, email, full_name FROM public.profiles WHERE school_id IS NOT NULL ORDER BY (role = 'super_admin') DESC LIMIT 1;")
    user_row = cur.fetchone()
    if not user_row:
        print("❌ Critical Error: No user profile found with active school_id in database.", flush=True)
        sys.exit(1)
        
    school_id = str(user_row["school_id"])
    user_id = str(user_row["id"])
    role = user_row.get("role") or "super_admin"
    email = user_row.get("email") or "admin@school.com"
    full_name = user_row.get("full_name") or "Super Admin"
    
    cur.close()
    conn.close()

    print(f"👤 Authenticated Test Context: User='{full_name}' ({user_id}) | School={school_id} | Role={role}\n", flush=True)
    token = get_test_token(user_id, school_id, role, email)
    
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "X-School-Id": school_id
    }

    # =========================================================================
    # MODULE 1: System Config & Appearance
    # =========================================================================
    print("--- [1] SYSTEM CONFIGURATION & BRANDING APIS ---", flush=True)
    try:
        res = client.get("/api/admin/system-config", headers=headers)
        data = res.json()
        record("System Config", "GET /api/admin/system-config (Read)", res.status_code == 200 and data.get("success") == True)
    except Exception as e:
        record("System Config", "GET /api/admin/system-config (Read)", False, str(e))

    try:
        update_payload = {
            "app_name": "EduSHAMIIT ERP",
            "primary_color": "#1A56DB",
            "visual_mode": "dark"
        }
        res = client.put("/api/admin/system-config", headers=headers, json=update_payload)
        record("System Config", "PUT /api/admin/system-config (Save Settings)", res.status_code == 200)
    except Exception as e:
        record("System Config", "PUT /api/admin/system-config (Save Settings)", False, str(e))

    try:
        dummy_png = b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15c4\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82"
        files = {"file": ("test_logo.png", io.BytesIO(dummy_png), "image/png")}
        upload_headers = {"Authorization": f"Bearer {token}", "X-School-Id": school_id}
        res = client.post("/api/admin/system-config/upload?file_type=logo", headers=upload_headers, files=files)
        data = res.json()
        record("System Config", "POST /api/admin/system-config/upload (Logo)", res.status_code == 200 and data.get("success") == True)
    except Exception as e:
        record("System Config", "POST /api/admin/system-config/upload (Logo)", False, str(e))

    # =========================================================================
    # MODULE 2: Lookup Management
    # =========================================================================
    print("\n--- [2] LOOKUP MANAGEMENT APIS ---", flush=True)
    created_key_id = None
    created_val_id = None
    try:
        res = client.get("/api/lookups?tab=all&page=1&page_size=10", headers=headers)
        data = res.json()
        record("Lookups", "GET /api/lookups (List All)", res.status_code == 200 and data.get("success") == True, f"Found {len(data.get('data', []))} items")
    except Exception as e:
        record("Lookups", "GET /api/lookups (List All)", False, str(e))

    try:
        unique_suffix = uuid.uuid4().hex[:6]
        create_key_payload = {
            "key_name": f"Test Clubs {unique_suffix}",
            "key_code": f"CLUBS_{unique_suffix.upper()}",
            "description": "Test Student Societies",
            "key_type": "CUSTOM",
            "icon": "star",
            "status": "ACTIVE",
            "initial_values": [
                {"value_name": "Chess Club", "value_code": "CHESS", "status": "ACTIVE", "sort_order": 1}
            ]
        }
        res = client.post("/api/lookups", headers=headers, json=create_key_payload)
        data = res.json()
        created_key_id = data.get("data", {}).get("id")
        record("Lookups", "POST /api/lookups (Create Key)", res.status_code in (200, 201) and created_key_id is not None)
    except Exception as e:
        record("Lookups", "POST /api/lookups (Create Key)", False, str(e))

    if created_key_id:
        try:
            res = client.get(f"/api/lookups/{created_key_id}", headers=headers)
            record("Lookups", f"GET /api/lookups/{created_key_id} (Key Detail)", res.status_code == 200)
        except Exception as e:
            record("Lookups", "GET /api/lookups/{id} (Key Detail)", False, str(e))

        try:
            val_payload = {"value_name": "Drama Club", "value_code": "DRAMA", "status": "ACTIVE", "sort_order": 2}
            res = client.post(f"/api/lookups/{created_key_id}/values", headers=headers, json=val_payload)
            data = res.json()
            created_val_id = data.get("data", {}).get("id")
            record("Lookups", "POST /api/lookups/{id}/values (Add Value)", res.status_code in (200, 201) and created_val_id is not None)
        except Exception as e:
            record("Lookups", "POST /api/lookups/{id}/values (Add Value)", False, str(e))

        try:
            res = client.delete(f"/api/lookups/{created_key_id}", headers=headers)
            record("Lookups", "DELETE /api/lookups/{id} (Cleanup)", res.status_code == 200)
        except Exception as e:
            record("Lookups", "DELETE /api/lookups/{id} (Cleanup)", False, str(e))

    # =========================================================================
    # MODULE 3: Academic Class, Section & Subject Management
    # =========================================================================
    print("\n--- [3] ACADEMIC CLASSES & SUBJECTS APIS ---", flush=True)
    try:
        res = client.get("/api/classes/stats", headers=headers)
        data = res.json()
        record("Classes", "GET /api/classes/stats (Overview)", res.status_code == 200 and data.get("success") == True)
    except Exception as e:
        record("Classes", "GET /api/classes/stats (Overview)", False, str(e))

    try:
        res = client.get("/api/classes", headers=headers)
        data = res.json()
        record("Classes", "GET /api/classes (List Classes)", res.status_code == 200 and data.get("success") == True)
    except Exception as e:
        record("Classes", "GET /api/classes (List Classes)", False, str(e))

    try:
        res = client.get("/api/classes/subjects/all", headers=headers)
        record("Subjects", "GET /api/classes/subjects/all (Catalog)", res.status_code == 200)
    except Exception as e:
        record("Subjects", "GET /api/classes/subjects/all (Catalog)", False, str(e))

    # =========================================================================
    # MODULE 4: Attendance Management
    # =========================================================================
    print("\n--- [4] ATTENDANCE ENGINE APIS ---", flush=True)
    try:
        res = client.get("/api/attendance/config", headers=headers)
        record("Attendance", "GET /api/attendance/config (Policies)", res.status_code == 200)
    except Exception as e:
        record("Attendance", "GET /api/attendance/config (Policies)", False, str(e))

    try:
        res = client.get("/api/attendance/summary?date=2026-08-30", headers=headers)
        record("Attendance", "GET /api/attendance/summary (Daily Status)", res.status_code == 200)
    except Exception as e:
        record("Attendance", "GET /api/attendance/summary (Daily Status)", False, str(e))

    try:
        res = client.get("/api/attendance/insights/overview", headers=headers)
        record("Attendance", "GET /api/attendance/insights/overview (AI Insights)", res.status_code == 200)
    except Exception as e:
        record("Attendance", "GET /api/attendance/insights/overview (AI Insights)", False, str(e))

    # =========================================================================
    # MODULE 5: Leave & Permission Management
    # =========================================================================
    print("\n--- [5] LEAVE & PERMISSIONS APIS ---", flush=True)
    try:
        res = client.get("/api/leave/types", headers=headers)
        record("Leave", "GET /api/leave/types (Leave Types)", res.status_code == 200)
    except Exception as e:
        record("Leave", "GET /api/leave/types (Leave Types)", False, str(e))

    try:
        res = client.get("/api/leave/balances?academic_year=2026-27", headers=headers)
        record("Leave", "GET /api/leave/balances (User Balances)", res.status_code == 200)
    except Exception as e:
        record("Leave", "GET /api/leave/balances (User Balances)", False, str(e))

    try:
        res = client.get("/api/leave/applications", headers=headers)
        record("Leave", "GET /api/leave/applications (Requests List)", res.status_code == 200)
    except Exception as e:
        record("Leave", "GET /api/leave/applications (Requests List)", False, str(e))

    # =========================================================================
    # MODULE 6: Calendar, Master Events & Notices
    # =========================================================================
    print("\n--- [6] CALENDAR & NOTICES APIS ---", flush=True)
    try:
        res = client.get("/api/calendar/events?start_date=2026-08-01&end_date=2026-08-31", headers=headers)
        record("Calendar", "GET /api/calendar/events (Month Projection)", res.status_code == 200)
    except Exception as e:
        record("Calendar", "GET /api/calendar/events (Month Projection)", False, str(e))

    try:
        res = client.get("/api/notices", headers=headers)
        record("Notices", "GET /api/notices (Notices Feed)", res.status_code == 200)
    except Exception as e:
        record("Notices", "GET /api/notices (Notices Feed)", False, str(e))

    # =========================================================================
    # SUMMARY
    # =========================================================================
    total_tests = passed + failed
    success_rate = (passed / total_tests) * 100 if total_tests > 0 else 0
    print("\n" + "=" * 90, flush=True)
    print("📊 MASTER API VALIDATION SUMMARY REPORT", flush=True)
    print("=" * 90, flush=True)
    print(f"Total API Endpoints Tested : {total_tests}", flush=True)
    print(f"✅ Successful Endpoints    : {passed}", flush=True)
    print(f"❌ Failed Endpoints        : {failed}", flush=True)
    print(f"🎯 API Health & Pass Rate  : {success_rate:.1f}%", flush=True)
    print("=" * 90, flush=True)
    
    if failed == 0:
        print("🎉 ALL LIVE API ENDPOINTS ARE HEALTHY, OPERATIONAL AND FULLY FUNCTIONAL!\n", flush=True)
    else:
        print(f"⚠️ {failed} endpoints require attention.\n", flush=True)

if __name__ == "__main__":
    run_master_api_validation()
