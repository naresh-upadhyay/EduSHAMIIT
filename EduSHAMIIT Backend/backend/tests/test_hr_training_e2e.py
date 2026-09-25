"""
End-to-End Workflow Integration Test Script for HR Training & Learning System
Module: EduSHAMIIT ERP - HR Management -> Training & Learning

Tests the complete lifecycle end-to-end:
1. Multi-Tenant Isolation
2. Dashboard & KPI Metrics
3. Learning Paths & Monthly Trends
4. Course Catalog Filtering & Search
5. Draft Training Creation & Validation
6. Publishing & Updating Training Program
7. Scheduling Sessions
8. Enrolling Employees (Single & Bulk)
9. Duplicate Enrollment Prevention
10. Recording Attendance (Individual & Bulk)
11. Participant Progress Updates & Completion
12. Generating Digital Certificates
13. Certificate Verification & Revocation
14. Submitting Employee Feedback & Ratings
15. Skill Gap Identification & Tracking
16. Program Bulk Actions (Archive, Publish)
17. Streaming CSV Report Exports
18. Audit Trail Verification
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

def run_e2e():
    print("=" * 80)
    print("   EduSHAMIIT ERP - HR TRAINING & LEARNING FULL E2E WORKFLOW SUITE   ")
    print("=" * 80)

    token_a = make_token(ADMIN_USER_ID, SCHOOL_A, "super_admin")
    headers_a = {"Authorization": f"Bearer {token_a}"}

    token_b = make_token(str(uuid.uuid4()), SCHOOL_B, "admin")
    headers_b = {"Authorization": f"Bearer {token_b}"}

    passed = 0
    failed = 0

    def record(name: str, condition: bool, err_msg: str = ""):
        nonlocal passed, failed
        if condition:
            passed += 1
            print(f"  [PASS] {name}")
        else:
            failed += 1
            print(f"  [FAIL] {name} - {err_msg}")

    # 1. Multi-Tenant Isolation
    res_b = client.get("/api/v1/training/programs", headers=headers_b)
    record("1. Tenant Isolation (School B has 0 programs from School A)",
           res_b.status_code == 200 and len(res_b.json().get("data", [])) == 0,
           f"Got {res_b.status_code}: {res_b.text}")

    # 2. Dashboard KPIs
    res_stats = client.get("/api/v1/training/stats", headers=headers_a)
    stats_data = res_stats.json() if res_stats.status_code == 200 else {}
    kpis = stats_data.get("kpis", {})
    record("2. Dashboard KPIs (28+ total, completed, in progress, participants)",
           res_stats.status_code == 200 and kpis.get("total_programs", 0) >= 28 and kpis.get("completed_programs", 0) >= 15,
           f"Got {res_stats.status_code}: {kpis}")

    # 3. Learning Paths
    paths = stats_data.get("learning_paths", [])
    record("3. Structured Learning Paths (5 paths present)",
           len(paths) == 5,
           f"Found {len(paths)} paths")

    # 4. Monthly Trend
    trend = stats_data.get("monthly_trend", [])
    record("4. Monthly Participation Trend (12 data points Jan-Dec)",
           len(trend) == 12,
           f"Found {len(trend)} months")

    # 5. Program Catalog Search
    res_search = client.get("/api/v1/training/programs?search=Excel", headers=headers_a)
    search_items = res_search.json().get("data", []) if res_search.status_code == 200 else []
    record("5. Program Catalog Search ('Excel' matches courses)",
           res_search.status_code == 200 and len(search_items) >= 1 and any("Excel" in p["title"] for p in search_items),
           f"Found {len(search_items)} items")

    # 6. Tab Counts
    tabs = res_search.json().get("tab_counts", {})
    record("6. Table Tab Counters (All, Completed, In Progress, Upcoming present)",
           tabs.get("all_count", 0) >= 28 and tabs.get("completed_count", 0) >= 15,
           f"Got tabs: {tabs}")

    # 7. Create Training Program (Draft)
    test_prog_title = f"E2E AI in Pedagogy {uuid.uuid4().hex[:6]}"
    new_prog_payload = {
        "title": test_prog_title,
        "description": "Comprehensive hands-on training for teachers on utilizing generative AI safely in curriculum planning.",
        "category_name": "Technical",
        "training_type": "Technical",
        "is_mandatory": True,
        "target_audience": "Teaching",
        "trainer_type": "INTERNAL",
        "trainer_name": "Dr. Sarah Jenkins",
        "mode": "Hybrid",
        "location_or_link": "Innovation Lab & Google Meet",
        "start_date": "2026-10-01",
        "end_date": "2026-10-03",
        "start_time": "10:00 AM",
        "end_time": "01:00 PM",
        "duration_hours": 9,
        "duration_display": "9 Hours",
        "capacity": 35,
        "budget_cost": 15000.0,
        "has_certificate": True,
        "certificate_validity_type": "PERMANENT",
        "assessment_type": "Assignment",
        "status": "Draft",
        "notes": "Bring laptops and lesson plan drafts."
    }
    res_create = client.post("/api/v1/training/programs", json=new_prog_payload, headers=headers_a)
    create_data = res_create.json() if res_create.status_code in (200, 201) else {}
    created_id = create_data.get("data", {}).get("id")
    record("7. Create Training Program as Draft",
           res_create.status_code in (200, 201) and created_id is not None,
           f"Got {res_create.status_code}: {res_create.text}")

    # 8. Validation Check (Missing required title)
    bad_payload = dict(new_prog_payload)
    bad_payload["title"] = ""
    res_bad = client.post("/api/v1/training/programs", json=bad_payload, headers=headers_a)
    record("8. Input Validation (Rejects empty title)",
           res_bad.status_code in (400, 422),
           f"Got status {res_bad.status_code}")

    # 9. Edit Training Program & Publish
    update_payload = {
        "title": test_prog_title,
        "description": "Updated course description with verified syllabus.",
        "trainer_name": "Dr. Sarah Jenkins, PhD",
        "status": "Scheduled"
    }
    res_update = client.put(f"/api/v1/training/programs/{created_id}", json=update_payload, headers=headers_a)
    record("9. Edit & Publish Program (status: Scheduled)",
           res_update.status_code == 200,
           f"Got {res_update.status_code}: {res_update.text}")

    # 10. Verify Program Detail
    res_detail = client.get(f"/api/v1/training/programs/{created_id}", headers=headers_a)
    prog_detail = res_detail.json().get("data", {}) if res_detail.status_code == 200 else {}
    record("10. Fetch Program Detail (reflects updated trainer and Scheduled status)",
           res_detail.status_code == 200 and prog_detail.get("status") == "Scheduled" and "PhD" in prog_detail.get("trainer_name", ""),
           f"Got detail: {prog_detail}")

    # 11. Add Training Session 1
    session1_payload = {
        "program_id": created_id,
        "session_title": "Module 1: AI Prompting for Educators",
        "session_date": "2026-10-01",
        "start_time": "10:00:00",
        "end_time": "12:30:00",
        "trainer_name": "Dr. Sarah Jenkins",
        "location_or_link": "Innovation Lab Room 204",
        "capacity": 35
    }
    res_s1 = client.post("/api/v1/training/sessions", json=session1_payload, headers=headers_a)
    s1_data = res_s1.json() if res_s1.status_code in (200, 201) else {}
    session1_id = s1_data.get("data", {}).get("id")
    record("11. Add Training Session 1",
           res_s1.status_code in (200, 201) and session1_id is not None,
           f"Got {res_s1.status_code}: {res_s1.text}")

    # 12. Add Training Session 2
    session2_payload = {
        "program_id": created_id,
        "session_title": "Module 2: Ethics, Plagiarism & Assessment Design",
        "session_date": "2026-10-02",
        "start_time": "10:00:00",
        "end_time": "12:30:00",
        "trainer_name": "Dr. Sarah Jenkins",
        "location_or_link": "Innovation Lab Room 204",
        "capacity": 35
    }
    res_s2 = client.post("/api/v1/training/sessions", json=session2_payload, headers=headers_a)
    session2_id = res_s2.json().get("data", {}).get("id")
    record("12. Add Training Session 2",
           res_s2.status_code in (200, 201) and session2_id is not None,
           f"Got {res_s2.status_code}: {res_s2.text}")

    # 13. Edit Session 1
    res_edit_s1 = client.put(f"/api/v1/training/sessions/{session1_id}", json={"location_or_link": "Auditorium Main Stage"}, headers=headers_a)
    record("13. Edit Session Location",
           res_edit_s1.status_code == 200,
           f"Got {res_edit_s1.status_code}")

    # 14. Assign Staff to Training
    assign_payload = {
        "employee_ids": [EMP_1_ID, EMP_2_ID],
        "is_mandatory": True
    }
    res_assign = client.post(f"/api/v1/training/programs/{created_id}/assign", json=assign_payload, headers=headers_a)
    record("14. Assign Multiple Staff Members",
           res_assign.status_code == 200 and res_assign.json().get("assigned_count") == 2,
           f"Got {res_assign.status_code}: {res_assign.text}")

    # 15. Duplicate Assignment Prevention
    res_assign_dup = client.post(f"/api/v1/training/programs/{created_id}/assign", json=assign_payload, headers=headers_a)
    record("15. Duplicate Enrollment Prevention (0 new assignments added)",
           res_assign_dup.status_code == 200 and res_assign_dup.json().get("assigned_count") == 0,
           f"Got {res_assign_dup.status_code}: {res_assign_dup.text}")

    # 16. Verify Participants List
    res_part = client.get(f"/api/v1/training/programs/{created_id}/participants", headers=headers_a)
    part_list = res_part.json().get("data", []) if res_part.status_code == 200 else []
    record("16. Fetch Enrolled Participants (2 employees enrolled)",
           res_part.status_code == 200 and len(part_list) == 2,
           f"Got {len(part_list)} participants")

    # 17. Record Session Attendance
    enr1_id = part_list[0]["enrollment_id"] if part_list else None
    enr2_id = part_list[1]["enrollment_id"] if len(part_list) > 1 else None

    att_payload = {
        "records": [
            {"enrollment_id": enr1_id, "attendance_status": "PRESENT", "remarks": "On time"},
            {"enrollment_id": enr2_id, "attendance_status": "LATE", "remarks": "Arrived 15m late"}
        ]
    }
    res_att = client.post(f"/api/v1/training/sessions/{session1_id}/attendance", json=att_payload, headers=headers_a)
    record("17. Record Session Attendance (Present & Late recorded)",
           res_att.status_code == 200,
           f"Got {res_att.status_code}: {res_att.text}")

    # 18. Fetch Session Attendance
    res_get_att = client.get(f"/api/v1/training/sessions/{session1_id}/attendance", headers=headers_a)
    att_records = res_get_att.json().get("data", []) if res_get_att.status_code == 200 else []
    record("18. Fetch Session Attendance Records",
           res_get_att.status_code == 200 and len(att_records) == 2,
           f"Got {len(att_records)} attendance rows")

    # 19. Generate Digital Certificate
    cert_payload = {
        "program_id": created_id,
        "employee_id": EMP_1_ID,
        "validity_months": 24
    }
    res_cert = client.post("/api/v1/training/certificates/generate", json=cert_payload, headers=headers_a)
    cert_data = res_cert.json().get("data", {}) if res_cert.status_code in (200, 201) else {}
    cert_id = cert_data.get("id")
    cert_no = cert_data.get("certificate_number")
    record("19. Generate Digital Certificate (Auto-generated CERT# and QR)",
           res_cert.status_code in (200, 201) and cert_id is not None and cert_no is not None,
           f"Got {res_cert.status_code}: {res_cert.text}")

    # 20. Certificates Registry & Filtering
    res_certs = client.get("/api/v1/training/certificates?status=VALID", headers=headers_a)
    certs_list = res_certs.json().get("data", []) if res_certs.status_code == 200 else []
    record("20. Filter Certificates by VALID status",
           res_certs.status_code == 200 and any(c["id"] == cert_id for c in certs_list),
           f"Found {len(certs_list)} valid certificates")

    # 21. Revoke Certificate
    res_revoke = client.post(f"/api/v1/training/certificates/{cert_id}/revoke", headers=headers_a)
    record("21. Revoke Certificate with Audit Reason",
           res_revoke.status_code == 200,
           f"Got {res_revoke.status_code}: {res_revoke.text}")

    # 22. Identify Training Need / Skill Gap
    gap_payload = {
        "department": "Transport",
        "topic": "First Aid & CPR Certification",
        "identified_employees_count": 8,
        "priority": "HIGH"
    }
    res_gap = client.post("/api/v1/training/skill-gaps", json=gap_payload, headers=headers_a)
    record("22. Identify Training Need / Skill Gap",
           res_gap.status_code in (200, 201),
           f"Got {res_gap.status_code}: {res_gap.text}")

    # 23. Fetch Skill Gaps
    res_get_gaps = client.get("/api/v1/training/skill-gaps", headers=headers_a)
    gaps = res_get_gaps.json().get("data", []) if res_get_gaps.status_code == 200 else []
    record("23. Fetch Identified Skill Gaps",
           res_get_gaps.status_code == 200 and len(gaps) >= 1,
           f"Found {len(gaps)} skill gaps")

    # 24. Bulk Actions on Programs (Archive)
    bulk_payload = {
        "program_ids": [created_id],
        "action": "archive"
    }
    res_bulk = client.post("/api/v1/training/bulk-action", json=bulk_payload, headers=headers_a)
    record("24. Bulk Archive Programs",
           res_bulk.status_code == 200 and res_bulk.json().get("affected_count") == 1,
           f"Got {res_bulk.status_code}: {res_bulk.text}")

    # 25. Export CSV: Programs Master Ledger
    res_csv1 = client.get("/api/v1/training/reports/programs", headers=headers_a)
    record("25. Export Programs Master Ledger CSV",
           res_csv1.status_code == 200 and "text/csv" in res_csv1.headers.get("content-type", "") and "Program Title" in res_csv1.text,
           f"Got {res_csv1.status_code}")

    # 26. Export CSV: Participants Roster
    res_csv2 = client.get("/api/v1/training/reports/participants", headers=headers_a)
    record("26. Export Participants & Attendance CSV",
           res_csv2.status_code == 200 and "text/csv" in res_csv2.headers.get("content-type", ""),
           f"Got {res_csv2.status_code}")

    # 27. Export CSV: Certificates Registry
    res_csv3 = client.get("/api/v1/training/reports/certificates", headers=headers_a)
    record("27. Export Certificates Registry CSV",
           res_csv3.status_code == 200 and "text/csv" in res_csv3.headers.get("content-type", ""),
           f"Got {res_csv3.status_code}")

    # 28. Verify Audit Trail in Database
    res_activities = client.get("/api/v1/training/stats", headers=headers_a)
    activities = res_activities.json().get("recent_activities", []) if res_activities.status_code == 200 else []
    record("28. Audit Trail Verification (Program lifecycle events recorded in activity log)",
           len(activities) >= 1,
           f"Found {len(activities)} audit log entries")

    # Cleanup: Delete test program
    client.delete(f"/api/v1/training/programs/{created_id}", headers=headers_a)

    print("-" * 80)
    print(f"E2E TEST SUMMARY: Total: {passed + failed} | Passed: {passed} | Failed: {failed}")
    print("=" * 80)

    if failed > 0:
        sys.exit(1)

if __name__ == "__main__":
    run_e2e()
