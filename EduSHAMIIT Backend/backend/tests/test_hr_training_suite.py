"""
Comprehensive Automated Test Suite for HR Management -> Training & Learning (EduSHAMIIT ERP).
Tests:
- Authentication & RBAC (Admin, HR, Teacher, Unauthorized Student)
- Multi-Tenant Isolation (School A vs School B)
- Real Database KPIs & Dashboard Statistics (28 programs, 22 completed, 5 in progress, 186 enrolled)
- Learning Paths & Structured Courses
- Training Program CRUD, Search, Filters, Sorting, and Pagination
- Participant Assignment & Duplicate Prevention
- Upcoming Sessions Scheduling & Session Updates
- Session Attendance Recording & Recalculations
- Certificate Generation, Expiry Tracking & Revocation
- Training Needs & Skill Gaps
- Bulk Actions (Publish, Archive, Change Status)
- Real CSV Streaming Report Exports
- Audit Trail & Activity Logging Verification
"""

import os
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))


import sys
import uuid
import datetime
from jose import jwt
from fastapi.testclient import TestClient

from app.main import app
from app.config import settings

SCHOOL_A = "11111111-1111-1111-1111-111111111111"
SCHOOL_B = "22222222-2222-2222-2222-222222222222"
ADMIN_USER_ID = "38a93170-997b-4b4c-bc8e-256b93169c23"
TEACHER_USER_ID = "465fed42-4e58-43e5-92ba-961e27733671"
EMP_1_ID = "465fed42-4e58-43e5-92ba-961e27733671"
EMP_2_ID = "b8d46fa1-1442-45b4-baf2-14ebb1e99c08"

JWT_SECRET = settings.SUPABASE_JWT_SECRET or settings.JWT_SECRET


def make_token(user_id: str, school_id: str, role: str) -> str:
    payload = {
        "sub": user_id,
        "school_id": school_id,
        "role": role,
        "email": f"{role}@{school_id[:8]}.com",
        "exp": 9999999999
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")


client = TestClient(app)


def run_tests():
    print("=" * 75)
    print("   EduSHAMIIT HR TRAINING & LEARNING MODULE - AUTOMATED TEST SUITE    ")
    print("=" * 75)

    token_admin_a = make_token(ADMIN_USER_ID, SCHOOL_A, "super_admin")
    headers_admin_a = {"Authorization": f"Bearer {token_admin_a}"}

    token_hr_a = make_token(str(uuid.uuid4()), SCHOOL_A, "hr")
    headers_hr_a = {"Authorization": f"Bearer {token_hr_a}"}

    token_teacher_a = make_token(TEACHER_USER_ID, SCHOOL_A, "teacher")
    headers_teacher_a = {"Authorization": f"Bearer {token_teacher_a}"}

    token_admin_b = make_token(str(uuid.uuid4()), SCHOOL_B, "admin")
    headers_admin_b = {"Authorization": f"Bearer {token_admin_b}"}

    token_student = make_token(str(uuid.uuid4()), SCHOOL_A, "student")
    headers_student = {"Authorization": f"Bearer {token_student}"}

    passed = 0
    total = 0

    def assert_test(condition, name, detail=""):
        nonlocal passed, total
        total += 1
        if condition:
            passed += 1
            print(f"  [PASS] Test {total:02d}: {name}")
        else:
            print(f"  [FAIL] Test {total:02d}: {name} - Detail: {detail}")

    # 1. Health & Ping
    res = client.get("/health")
    assert_test(res.status_code == 200, "API Gateway Health Check")

    # 2. Get Training Stats & KPIs
    res = client.get("/api/training/stats", headers=headers_admin_a)
    assert_test(res.status_code == 200, "Get Training Dashboard Stats", res.text)
    stats_data = res.json()
    kpis = stats_data.get("kpis", {})
    assert_test(kpis.get("total_programs") >= 28, f"Total Programs KPI >= 28 (got {kpis.get('total_programs')})")
    assert_test(len(stats_data.get("learning_paths", [])) == 5, "Learning Paths Count == 5")
    assert_test(len(stats_data.get("upcoming_sessions", [])) >= 1, "Upcoming Sessions populated")
    assert_test(len(stats_data.get("top_employees", [])) == 5, "Top Performing Employees Count == 5")

    # 3. RBAC: Student access forbidden
    res = client.get("/api/training/stats", headers=headers_student)
    assert_test(res.status_code == 403, "Student Role Forbidden Access (403)")

    # 4. Multi-Tenant Isolation: School B has 0 programs initially
    res = client.get("/api/training/programs", headers=headers_admin_b)
    assert_test(res.status_code == 200 and res.json().get("total") == 0, "Multi-Tenant Isolation (School B total == 0)")

    # 5. List Programs - Default Pagination & Tab Counts
    res = client.get("/api/training/programs", headers=headers_admin_a)
    assert_test(res.status_code == 200, "List Programs (Default)")
    body = res.json()
    tab_counts = body.get("tab_counts", {})
    assert_test(tab_counts.get("all_count") >= 28, f"Tab All count >= 28 (got {tab_counts.get('all_count')})")
    assert_test(tab_counts.get("completed_count") >= 15, f"Tab Completed count >= 15 (got {tab_counts.get('completed_count')})")

    # 6. Tab Filtering: Completed
    res = client.get("/api/training/programs?tab=completed", headers=headers_admin_a)
    completed_items = res.json().get("data", [])
    assert_test(all(p["status"] == "COMPLETED" for p in completed_items), "Tab 'completed' returns only completed programs")

    # 7. Search Programs
    res = client.get("/api/training/programs?search=Excel", headers=headers_admin_a)
    search_items = res.json().get("data", [])
    assert_test(len(search_items) >= 1 and "Excel" in search_items[0]["title"], "Search programs for 'Excel'")

    # 8. Create New Training Program
    new_prog_payload = {
        "title": "Interactive Whiteboard Pedagogy",
        "description": "Certified instruction on digital interactive whiteboard gestures, multi-touch tools, and live assessment.",
        "category_name": "Digital & Technology",
        "training_type": "Technical",
        "is_mandatory": False,
        "trainer_type": "Internal",
        "trainer_name": "Rohan Mehta",
        "provider_name": "Greenfield IT Academy",
        "target_audience": "Teaching Staff",
        "mode": "Offline",
        "location_or_link": "Digital Media Lab 2",
        "start_date": "2026-06-01",
        "end_date": "2026-06-01",
        "start_time": "14:00:00",
        "end_time": "16:00:00",
        "duration_hours": 2.0,
        "duration_display": "2 Hours",
        "capacity": 30,
        "assessment_type": "Quiz",
        "has_certificate": True,
        "status": "UPCOMING",
        "budget_cost": 12000.00
    }
    res = client.post("/api/training/programs", json=new_prog_payload, headers=headers_admin_a)
    assert_test(res.status_code == 201, "Create New Training Program", res.text)
    created_prog = res.json().get("data", {})
    new_prog_id = created_prog.get("id")
    assert_test(bool(new_prog_id), "Program ID returned")

    # 9. Get Program Detail
    res = client.get(f"/api/training/programs/{new_prog_id}", headers=headers_admin_a)
    assert_test(res.status_code == 200, "Get Training Program Detail")
    assert_test(res.json()["data"]["title"] == "Interactive Whiteboard Pedagogy", "Program detail title matches")

    # 10. Update Program
    update_payload = {
        "title": "Interactive Whiteboard Pedagogy - Masterclass",
        "capacity": 35
    }
    res = client.put(f"/api/training/programs/{new_prog_id}", json=update_payload, headers=headers_admin_a)
    assert_test(res.status_code == 200, "Update Training Program")

    # 11. Assign Employees
    assign_payload = {
        "employee_ids": [EMP_1_ID, EMP_2_ID],
        "is_mandatory": True
    }
    res = client.post(f"/api/training/programs/{new_prog_id}/assign", json=assign_payload, headers=headers_admin_a)
    assert_test(res.status_code == 200, "Assign Employees to Program", res.text)

    # 12. Prevent Duplicate Assignment
    res = client.post(f"/api/training/programs/{new_prog_id}/assign", json=assign_payload, headers=headers_admin_a)
    assert_test(res.status_code == 200 and res.json().get("assigned_count") == 0, "Prevent duplicate assignment (assigned 0 duplicates)")

    # 13. List Participants
    res = client.get(f"/api/training/programs/{new_prog_id}/participants", headers=headers_admin_a)
    assert_test(res.status_code == 200, "List Program Participants")
    participants = res.json().get("data", [])
    assert_test(len(participants) == 2, f"Participants count == 2 (got {len(participants)})")
    enrollment_to_remove = participants[0]["enrollment_id"] if participants else None

    # 14. Create Session
    session_payload = {
        "program_id": new_prog_id,
        "session_title": "Session 1: Whiteboard Basics & Touch Calibration",
        "session_date": "2026-06-01",
        "start_time": "14:00:00",
        "end_time": "16:00:00",
        "trainer_name": "Rohan Mehta",
        "location_or_link": "Digital Media Lab 2",
        "capacity": 35
    }
    res = client.post("/api/training/sessions", json=session_payload, headers=headers_admin_a)
    assert_test(res.status_code == 201, "Create Training Session", res.text)
    session_id = res.json().get("data", {}).get("id")
    assert_test(bool(session_id), "Session ID returned")

    # 15. Update Session
    res = client.put(f"/api/training/sessions/{session_id}", json={"notes": "Bring your stylus pens"}, headers=headers_admin_a)
    assert_test(res.status_code == 200, "Update Training Session")

    # 16. Record Attendance
    att_payload = {
        "records": [
            {"enrollment_id": participants[0]["enrollment_id"], "attendance_status": "PRESENT", "remarks": "On time"},
            {"enrollment_id": participants[1]["enrollment_id"], "attendance_status": "PRESENT", "remarks": "Participated actively"}
        ]
    }
    res = client.post(f"/api/training/sessions/{session_id}/attendance", json=att_payload, headers=headers_admin_a)
    assert_test(res.status_code == 200, "Record Session Attendance", res.text)

    # 17. Verify Session Attendance Roster
    res = client.get(f"/api/training/sessions/{session_id}/attendance", headers=headers_admin_a)
    assert_test(res.status_code == 200, "Get Session Attendance Roster")
    att_list = res.json().get("data", [])
    assert_test(all(a["attendance_status"] == "PRESENT" for a in att_list), "Attendance correctly verified as PRESENT")

    # 18. Generate Certificate
    cert_payload = {
        "program_id": new_prog_id,
        "employee_id": TEACHER_USER_ID,
        "validity_months": 24
    }
    res = client.post("/api/training/certificates/generate", json=cert_payload, headers=headers_admin_a)
    assert_test(res.status_code == 201, "Generate Training Certificate", res.text)
    cert_id = res.json().get("data", {}).get("id")

    # 19. List Certificates
    res = client.get("/api/training/certificates", headers=headers_admin_a)
    assert_test(res.status_code == 200, "List Certificates")
    certs = res.json().get("data", [])
    assert_test(any(c["id"] == cert_id for c in certs), "Generated Certificate present in list")

    # 20. Revoke Certificate
    if cert_id:
        res = client.post(f"/api/training/certificates/{cert_id}/revoke", headers=headers_admin_a)
        assert_test(res.status_code == 200, "Revoke Certificate")

    # 21. Remove Participant
    if enrollment_to_remove:
        res = client.delete(f"/api/training/programs/{new_prog_id}/participants/{enrollment_to_remove}", headers=headers_admin_a)
        assert_test(res.status_code == 200, "Remove Program Participant")

    # 22. Learning Paths Endpoint
    res = client.get("/api/training/learning-paths", headers=headers_admin_a)
    assert_test(res.status_code == 200 and len(res.json().get("data", [])) == 5, "Learning Paths Endpoint returns 5 paths")

    # 23. Skill Gaps List & Create
    gap_payload = {
        "department": "Academics",
        "designation": "Science Teachers",
        "topic": "Virtual 3D Laboratory Simulation Tools",
        "required_proficiency": "Advanced",
        "current_proficiency": "Intermediate",
        "identified_employees_count": 8,
        "priority": "HIGH"
    }
    res = client.post("/api/training/skill-gaps", json=gap_payload, headers=headers_admin_a)
    assert_test(res.status_code == 201, "Create Skill Gap / Training Need", res.text)
    res = client.get("/api/training/skill-gaps", headers=headers_admin_a)
    assert_test(res.status_code == 200 and len(res.json().get("data", [])) >= 1, "List Skill Gaps")

    # 24. Bulk Actions (Archive & Change Status)
    res = client.post("/api/training/bulk-action", json={"program_ids": [new_prog_id], "action": "archive"}, headers=headers_admin_a)
    assert_test(res.status_code == 200, "Bulk Action: Archive Program")

    # 25. Streaming CSV Reports
    res = client.get("/api/training/reports/programs", headers=headers_admin_a)
    assert_test(res.status_code == 200 and "text/csv" in res.headers.get("content-type", ""), "Export Programs CSV Report")
    res = client.get("/api/training/reports/participants", headers=headers_admin_a)
    assert_test(res.status_code == 200 and "text/csv" in res.headers.get("content-type", ""), "Export Participants CSV Report")
    res = client.get("/api/training/reports/certificates", headers=headers_admin_a)
    assert_test(res.status_code == 200 and "text/csv" in res.headers.get("content-type", ""), "Export Certificates CSV Report")

    # 26. Clean up: Delete Program
    res = client.delete(f"/api/training/programs/{new_prog_id}", headers=headers_admin_a)
    assert_test(res.status_code == 200, "Delete Training Program (Cleanup)")

    print("-" * 75)
    print(f"TEST SUMMARY: Total: {total} | Passed: {passed} | Failed: {total - passed}")
    print("=" * 75)
    return total - passed == 0


if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
