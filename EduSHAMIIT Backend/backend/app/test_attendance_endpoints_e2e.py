"""
==============================================================================
Exhaustive E2E HTTP API Test Suite: Attendance Management Module
==============================================================================
Tests all scenarios across all Attendance endpoints and stored procedures:
1. Super Admin Authentication & Live Session Token
2. Active Class & Section Context Resolution with Real Student
3. Attendance Dashboard Stats (GET /api/attendance/stats)
4. Today's Academic Timetable & Schedules (GET /api/attendance/schedules)
5. Daily Attendance Roster & Pagination (GET /api/attendance/roster)
6. All-Day Attendance Save (POST /api/attendance/save)
7. Stored Procedure Override Workflow (POST /api/attendance/override - fn_override_locked_attendance)
8. In-Depth Student Attendance & 30-Day Metrics (GET /api/attendance/student-detail/{id})
9. Manager Status & Hierarchy (GET /api/attendance/manager-status)
10. Staff Attendance Management (GET /api/attendance/staff & POST /api/attendance/staff/save)
11. Leave Requests Integration (GET /api/attendance/leave-requests)
12. Bulk Operations (POST /api/attendance/bulk)
13. Attendance Insights & Analytics (GET /api/attendance/insights)
14. Attendance School Settings (GET /api/attendance/settings & PUT /api/attendance/settings)
15. CSV Attendance Report Export (GET /api/attendance/export)
16. Attendance Audit Logs (GET /api/attendance/audit)
17. Security & Boundary Validations (Empty reason rejection, unauthenticated rejection)
==============================================================================
"""

import sys
import os
import requests
import json
import uuid
from datetime import date, datetime, timedelta
from jose import jwt
from app.config import settings

API_BASE_URL = os.environ.get("API_BASE_URL", "http://localhost:8082")

test_results = []
passed_count = 0
failed_count = 0

def log_test(name: str, passed: bool, details: str = ""):
    global passed_count, failed_count
    status = "[PASS]" if passed else "[FAIL]"
    if passed:
        passed_count += 1
    else:
        failed_count += 1
    test_results.append((name, passed, details))
    print(f"  {status} {name} {details}")
    if not passed:
        print(f"      DETAILS: {details}")


def run_all_scenarios():
    global passed_count, failed_count
    print("\n" + "=" * 75)
    print("RUNNING EXHAUSTIVE ATTENDANCE ENDPOINTS & STORED PROCEDURES TEST SUITE")
    print("=" * 75)

    today_str = date.today().isoformat()
    past_month_str = (date.today() - timedelta(days=30)).isoformat()

    # ------------------------------------------------------------------------
    # 1. AUTHENTICATION & SUPER ADMIN TOKEN SETUP
    # ------------------------------------------------------------------------
    print("\n[Phase 1] Authenticating with Live Backend API as Super Admin...")
    try:
        secret = getattr(settings, "SUPABASE_JWT_SECRET", None) or getattr(settings, "JWT_SECRET", "eduSHAMIIT-jwt-secret-2026")
        user_id = "38a93170-997b-4b4c-bc8e-256b93169c23"
        school_id = "11111111-1111-1111-1111-111111111111"
        payload = {
            "sub": user_id,
            "school_id": school_id,
            "role": "super_admin",
            "email": "superadmin@edushamiit.com",
            "exp": 9999999999
        }
        token = jwt.encode(payload, secret, algorithm="HS256")
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        }
        log_test("Super Admin JWT Session Initialized", True, f"User ID: {user_id}")
    except Exception as e:
        log_test("Super Admin JWT Session Initialized", False, str(e))
        return

    # ------------------------------------------------------------------------
    # 2. DISCOVER ACTIVE CLASSES & REAL ENROLLED STUDENTS
    # ------------------------------------------------------------------------
    print("\n[Phase 2] Discovering Active Classes, Sections, and Students...")
    class_id = None
    section_id = None
    test_student_id = None
    student_name = ""
    try:
        classes_res = requests.get(f"{API_BASE_URL}/api/classes?academic_year=2026-27", headers=headers, timeout=8)
        if classes_res.status_code == 200:
            c_data = classes_res.json().get("data", {}).get("classes", [])
            for c in c_data:
                for s in c.get("sections", []):
                    r = requests.get(f"{API_BASE_URL}/api/attendance/roster?attendance_date={today_str}&class_id={c['id']}&section_id={s['id']}", headers=headers, timeout=8).json()
                    stus = r.get("data", {}).get("students", [])
                    if stus:
                        class_id = c["id"]
                        section_id = s["id"]
                        test_student_id = stus[0].get("student_id") or stus[0].get("id")
                        student_name = stus[0].get("full_name") or "Test Student"
                        break
                if class_id:
                    break
        log_test("Discovered Active Class & Enrolled Student Context", class_id is not None and test_student_id is not None, f"Class ID: {class_id}, Section ID: {section_id}, Student: {student_name} ({test_student_id})")
    except Exception as e:
        log_test("Discovered Active Class Context", False, str(e))

    # Fallback IDs if no class/student populated
    if not class_id:
        class_id = "6a4068a1-c2e8-473a-99a4-675257ba95fa"
        section_id = "50243c6c-5641-4275-90ea-94450402fbf5"
        test_student_id = "10000000-0000-0000-0000-000000000013"

    # ------------------------------------------------------------------------
    # 3. GET /api/attendance/stats
    # ------------------------------------------------------------------------
    print("\n[Phase 3] Testing Dashboard Statistics & KPI Metrics...")
    try:
        url = f"{API_BASE_URL}/api/attendance/stats?attendance_date={today_str}&class_id={class_id}&section_id={section_id}"
        res = requests.get(url, headers=headers, timeout=8)
        log_test("GET /api/attendance/stats (Status 200)", res.status_code == 200)
        data = res.json()
        log_test("GET /api/attendance/stats (Payload contains day_summary)", "day_summary" in data.get("data", {}))
    except Exception as e:
        log_test("GET /api/attendance/stats", False, str(e))

    # ------------------------------------------------------------------------
    # 4. GET /api/attendance/schedules
    # ------------------------------------------------------------------------
    print("\n[Phase 4] Testing Timetable & Class Schedules...")
    try:
        url = f"{API_BASE_URL}/api/attendance/schedules?attendance_date={today_str}&class_id={class_id}&section_id={section_id}"
        res = requests.get(url, headers=headers, timeout=8)
        log_test("GET /api/attendance/schedules (Status 200)", res.status_code == 200)
        data = res.json()
        log_test("GET /api/attendance/schedules (Returns schedules array)", isinstance(data.get("data", {}).get("schedules"), list))
    except Exception as e:
        log_test("GET /api/attendance/schedules", False, str(e))

    # ------------------------------------------------------------------------
    # 5. GET /api/attendance/roster
    # ------------------------------------------------------------------------
    print("\n[Phase 5] Testing Daily Attendance Roster & Pagination...")
    try:
        url = f"{API_BASE_URL}/api/attendance/roster?attendance_date={today_str}&class_id={class_id}&section_id={section_id}&mode=ALL_DAY&page=1&page_size=10"
        res = requests.get(url, headers=headers, timeout=8)
        log_test("GET /api/attendance/roster (Status 200)", res.status_code == 200)
        data = res.json()
        discovered_students = data.get("data", {}).get("students", [])
        total_count = data.get("data", {}).get("total_count", 0)
        log_test("GET /api/attendance/roster (Returns paginated structure)", "students" in data.get("data", {}), f"Count: {len(discovered_students)}, Total: {total_count}")

        # Search Filter Test
        search_res = requests.get(f"{url}&search=Ishita", headers=headers, timeout=8)
        log_test("GET /api/attendance/roster with Search query", search_res.status_code == 200)

        # Status Filter Test
        status_res = requests.get(f"{url}&status_filter=PRESENT", headers=headers, timeout=8)
        log_test("GET /api/attendance/roster with Status Filter", status_res.status_code == 200)
    except Exception as e:
        log_test("GET /api/attendance/roster", False, str(e))

    # ------------------------------------------------------------------------
    # 6. POST /api/attendance/save
    # ------------------------------------------------------------------------
    print("\n[Phase 6] Testing Save Daily Attendance...")
    try:
        save_payload = {
            "attendance_date": today_str,
            "class_id": class_id,
            "section_id": section_id,
            "mode": "ALL_DAY",
            "records": [
                {
                    "student_id": test_student_id,
                    "status": "PRESENT",
                    "remarks": "Marked via E2E test"
                }
            ],
            "allow_override": True
        }
        res = requests.post(f"{API_BASE_URL}/api/attendance/save", json=save_payload, headers=headers, timeout=8)
        log_test("POST /api/attendance/save (Status 200 & Success)", res.status_code in (200, 201) and res.json().get("success") == True, f"Response: {res.text[:120]}")
    except Exception as e:
        log_test("POST /api/attendance/save", False, str(e))

    # ------------------------------------------------------------------------
    # 7. POST /api/attendance/override (Stored Procedure fn_override_locked_attendance)
    # ------------------------------------------------------------------------
    print("\n[Phase 7] Testing Stored Procedure Override Workflow...")
    try:
        # Scenario 7a: Valid Override with student_id and justification
        override_payload = {
            "record_id": test_student_id,
            "record_type": "DAILY",
            "new_status": "PRESENT",
            "reason": "Parent verified student was attending clinic appointment in the morning"
        }
        res_ovr = requests.post(f"{API_BASE_URL}/api/attendance/override", json=override_payload, headers=headers, timeout=8)
        log_test("POST /api/attendance/override via Stored Procedure (Status 200 & Success)", res_ovr.status_code == 200 and res_ovr.json().get("success") == True, f"Response: {res_ovr.text[:120]}")

        # Scenario 7b: Reject empty or whitespace reason
        invalid_ovr_payload = {
            "record_id": test_student_id,
            "record_type": "DAILY",
            "new_status": "LATE",
            "reason": "   "
        }
        res_inv = requests.post(f"{API_BASE_URL}/api/attendance/override", json=invalid_ovr_payload, headers=headers, timeout=8)
        log_test("POST /api/attendance/override (Rejects empty reason with 400/422)", res_inv.status_code in (400, 422))
    except Exception as e:
        log_test("POST /api/attendance/override", False, str(e))

    # ------------------------------------------------------------------------
    # 8. GET /api/attendance/student-detail/{student_id}
    # ------------------------------------------------------------------------
    print("\n[Phase 8] Testing Student Attendance Detail & Past 30 Days Summary...")
    try:
        res_det = requests.get(f"{API_BASE_URL}/api/attendance/student-detail/{test_student_id}?attendance_date={today_str}", headers=headers, timeout=8)
        log_test("GET /api/attendance/student-detail/{id} (Status 200)", res_det.status_code == 200)
        if res_det.status_code == 200:
            data = res_det.json().get("data", {})
            log_test("GET /api/attendance/student-detail (Contains profile and 30-day stats)", "monthly_metrics" in data)
    except Exception as e:
        log_test("GET /api/attendance/student-detail", False, str(e))

    # ------------------------------------------------------------------------
    # 9. GET /api/attendance/manager-status & /api/attendance/staff
    # ------------------------------------------------------------------------
    print("\n[Phase 9] Testing Staff Attendance & Manager Hierarchy...")
    try:
        res_mgr = requests.get(f"{API_BASE_URL}/api/attendance/manager-status", headers=headers, timeout=8)
        log_test("GET /api/attendance/manager-status (Status 200)", res_mgr.status_code == 200)

        res_staff = requests.get(f"{API_BASE_URL}/api/attendance/staff?attendance_date={today_str}&department=ALL&role=ALL&page=1&page_size=10", headers=headers, timeout=8)
        log_test("GET /api/attendance/staff (Status 200 & Returns staff roster)", res_staff.status_code == 200 and ("staff" in res_staff.json().get("data", {}) or "employees" in res_staff.json().get("data", {})))
    except Exception as e:
        log_test("Staff & Manager Attendance", False, str(e))

    # ------------------------------------------------------------------------
    # 10. POST /api/attendance/staff/save
    # ------------------------------------------------------------------------
    print("\n[Phase 10] Testing Staff Attendance Save...")
    try:
        staff_payload = {
            "attendance_date": today_str,
            "records": [
                {
                    "employee_id": user_id,
                    "status": "PRESENT",
                    "check_in_time": "09:00:00",
                    "check_out_time": "17:00:00",
                    "is_wfh": False,
                    "remarks": "Admin check-in via E2E test"
                }
            ]
        }
        res_st_save = requests.post(f"{API_BASE_URL}/api/attendance/staff/save", json=staff_payload, headers=headers, timeout=8)
        log_test("POST /api/attendance/staff/save (Status 200 & Success)", res_st_save.status_code == 200 and res_st_save.json().get("success") == True)
    except Exception as e:
        log_test("POST /api/attendance/staff/save", False, str(e))

    # ------------------------------------------------------------------------
    # 11. GET /api/attendance/leave-requests
    # ------------------------------------------------------------------------
    print("\n[Phase 11] Testing Leave Applications & Approvals...")
    try:
        res_leaves = requests.get(f"{API_BASE_URL}/api/attendance/leave-requests?status=ALL", headers=headers, timeout=8)
        log_test("GET /api/attendance/leave-requests (Status 200 & Lists leaves)", res_leaves.status_code == 200 and "leave_requests" in res_leaves.json().get("data", {}))
    except Exception as e:
        log_test("GET /api/attendance/leave-requests", False, str(e))

    # ------------------------------------------------------------------------
    # 12. POST /api/attendance/bulk
    # ------------------------------------------------------------------------
    print("\n[Phase 12] Testing Bulk Attendance Operations...")
    try:
        bulk_payload = {
            "operation": "PRESENT",
            "attendance_date": today_str,
            "class_id": class_id,
            "section_id": section_id,
            "student_ids": [test_student_id],
            "remarks": "Bulk verified present"
        }
        res_bulk = requests.post(f"{API_BASE_URL}/api/attendance/bulk", json=bulk_payload, headers=headers, timeout=8)
        log_test("POST /api/attendance/bulk (Status 200 & Success)", res_bulk.status_code == 200 and res_bulk.json().get("success") == True)
    except Exception as e:
        log_test("POST /api/attendance/bulk", False, str(e))

    # ------------------------------------------------------------------------
    # 13. GET /api/attendance/insights
    # ------------------------------------------------------------------------
    print("\n[Phase 13] Testing Attendance Analytics & Insights...")
    try:
        res_ins = requests.get(f"{API_BASE_URL}/api/attendance/insights?start_date={past_month_str}&end_date={today_str}&class_id={class_id}", headers=headers, timeout=8)
        log_test("GET /api/attendance/insights (Status 200 & Analytics)", res_ins.status_code == 200 and "data" in res_ins.json())
    except Exception as e:
        log_test("GET /api/attendance/insights", False, str(e))

    # ------------------------------------------------------------------------
    # 14. GET /api/attendance/settings & PUT /api/attendance/settings
    # ------------------------------------------------------------------------
    print("\n[Phase 14] Testing Attendance Settings Configuration...")
    try:
        res_sett = requests.get(f"{API_BASE_URL}/api/attendance/settings", headers=headers, timeout=8)
        log_test("GET /api/attendance/settings (Status 200)", res_sett.status_code == 200)

        update_sett = {
            "allow_late": True,
            "late_cutoff_minutes": 15,
            "require_absent_remark": False,
            "auto_mark_approved_leave": True,
            "lock_after_hours": 24
        }
        res_upd_sett = requests.put(f"{API_BASE_URL}/api/attendance/settings", json=update_sett, headers=headers, timeout=8)
        log_test("PUT /api/attendance/settings (Status 200 & Saved)", res_upd_sett.status_code == 200 and res_upd_sett.json().get("success") == True)
    except Exception as e:
        log_test("Attendance Settings", False, str(e))

    # ------------------------------------------------------------------------
    # 15. GET /api/attendance/export
    # ------------------------------------------------------------------------
    print("\n[Phase 15] Testing CSV Attendance Export...")
    try:
        url = f"{API_BASE_URL}/api/attendance/export?attendance_date={today_str}&class_id={class_id}&section_id={section_id}"
        res_exp = requests.get(url, headers=headers, timeout=8)
        log_test("GET /api/attendance/export (Status 200 & CSV Header)", res_exp.status_code == 200 and "text/csv" in res_exp.headers.get("Content-Type", ""))
    except Exception as e:
        log_test("GET /api/attendance/export", False, str(e))

    # ------------------------------------------------------------------------
    # 16. GET /api/attendance/audit
    # ------------------------------------------------------------------------
    print("\n[Phase 16] Testing Attendance Audit Trail Logs...")
    try:
        res_aud = requests.get(f"{API_BASE_URL}/api/attendance/audit?limit=10", headers=headers, timeout=8)
        log_test("GET /api/attendance/audit (Status 200 & Logs)", res_aud.status_code == 200 and "audit_logs" in res_aud.json().get("data", {}))
    except Exception as e:
        log_test("GET /api/attendance/audit", False, str(e))

    # ------------------------------------------------------------------------
    # 17. Security Check: Unauthenticated Request Rejection
    # ------------------------------------------------------------------------
    print("\n[Phase 17] Testing Security & Unauthenticated Access Rejection...")
    try:
        res_unauth = requests.get(f"{API_BASE_URL}/api/attendance/stats?attendance_date={today_str}", timeout=8)
        log_test("Security Check: Unauthenticated request rejected (401)", res_unauth.status_code == 401)
    except Exception as e:
        log_test("Security Check", False, str(e))

    print("\n" + "=" * 75)
    print(f"TEST RESULTS SUMMARY: {passed_count} PASSED, {failed_count} FAILED out of {len(test_results)} Tests")
    print("=" * 75 + "\n")

    if failed_count > 0:
        sys.exit(1)


if __name__ == "__main__":
    run_all_scenarios()
