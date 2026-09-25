"""
Automated Test Suite for HR Management -> Overview & Command Center (EduSHAMIIT ERP).
Validates:
1. Service Health Check
2. Unified HR Command Center Stats API
3. Workforce & Staffing Consolidation
4. Recruitment Pipeline Funnel
5. Onboarding Pipeline & Progress
6. Training & Professional Development KPIs
7. Policies & Compliance Status
8. Actionable Pending Alerts & Recommendations
9. Consolidated Cross-Module Activity Stream
10. Role-Based Access Control (Admin full access, Staff view access, Student 403)
11. Multi-Tenant School Isolation (Tenant A vs Tenant B)
12. Executive Summary CSV Export
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
STUDENT_USER_ID = "99999999-9999-9999-9999-999999999999"

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
    print("      EduSHAMIIT HR OVERVIEW & COMMAND CENTER - AUTOMATED TEST SUITE     ")
    print("=" * 75)

    token_admin_a = make_token(ADMIN_USER_ID, SCHOOL_A, "super_admin")
    headers_admin_a = {"Authorization": f"Bearer {token_admin_a}"}

    token_teacher_a = make_token(TEACHER_USER_ID, SCHOOL_A, "teacher")
    headers_teacher_a = {"Authorization": f"Bearer {token_teacher_a}"}

    token_student_a = make_token(STUDENT_USER_ID, SCHOOL_A, "student")
    headers_student_a = {"Authorization": f"Bearer {token_student_a}"}

    token_admin_b = make_token(str(uuid.uuid4()), SCHOOL_B, "admin")
    headers_admin_b = {"Authorization": f"Bearer {token_admin_b}"}

    passed = 0
    failed = 0

    def record(name: str, cond: bool, extra: str = ""):
        nonlocal passed, failed
        if cond:
            passed += 1
            print(f"  [PASS] {name}")
        else:
            failed += 1
            print(f"  [FAIL] {name} - {extra}")

    # Test 01: Service Health Check
    res = client.get("/api/v1/hr/overview/health")
    record("Test 01: HR Overview Health Check",
           res.status_code == 200 and res.json().get("status") == "healthy",
           f"Got {res.status_code}")

    # Test 02: Admin Can Access Consolidated Stats
    res = client.get("/api/v1/hr/overview/stats", headers=headers_admin_a)
    record("Test 02: Admin Access to Overview Stats",
           res.status_code == 200 and res.json().get("success") is True,
           f"Got {res.status_code}: {res.text}")

    data = res.json().get("data", {}) if res.status_code == 200 else {}

    # Test 03: Workforce KPIs Consolidated
    wf = data.get("workforce", {})
    record("Test 03: Workforce KPIs (Total Employees >= 50)",
           wf.get("total_employees", 0) >= 50 and wf.get("active_employees", 0) > 0,
           f"Got total: {wf.get('total_employees')}, active: {wf.get('active_employees')}")

    # Test 04: Workforce Department Breakdown
    depts = wf.get("department_breakdown", [])
    record("Test 04: Department Breakdown populated",
           len(depts) >= 1 and all("department" in d and "count" in d for d in depts),
           f"Got {len(depts)} departments")

    # Test 05: Recruitment Funnel Consolidated
    rec = data.get("recruitment", {})
    record("Test 05: Recruitment Funnel & Open Positions",
           rec.get("open_positions", 0) > 0 and len(rec.get("pipeline", [])) >= 4,
           f"Got open_positions: {rec.get('open_positions')}, pipeline stages: {len(rec.get('pipeline', []))}")

    # Test 06: Onboarding Pipeline Consolidated
    onb = data.get("onboarding", {})
    record("Test 06: Onboarding Pipeline & Active Count",
           onb.get("active_onboardings", 0) > 0 and len(onb.get("pipeline", [])) >= 5,
           f"Got active: {onb.get('active_onboardings')}, pipeline stages: {len(onb.get('pipeline', []))}")

    # Test 07: Training & Learning KPIs Consolidated
    trn = data.get("training", {})
    record("Test 07: Training Programs & Completion Rate",
           trn.get("total_programs", 0) >= 28 and trn.get("completion_rate", 0) > 0,
           f"Got total_programs: {trn.get('total_programs')}, rate: {trn.get('completion_rate')}")

    # Test 08: Policies & Compliance Consolidated
    pol = data.get("policies", {})
    record("Test 08: Active Policies & Compliance Rate",
           pol.get("active_policies", 0) >= 5 and pol.get("compliance_rate", 0) > 0,
           f"Got active_policies: {pol.get('active_policies')}, rate: {pol.get('compliance_rate')}")

    # Test 09: Actionable Pending Alerts
    alerts = data.get("pending_alerts", [])
    record("Test 09: Actionable Pending HR Alerts populated",
           len(alerts) >= 3 and all("title" in a and "target_route" in a and "severity" in a for a in alerts),
           f"Got {len(alerts)} alerts")

    # Test 10: Alert Target Routes Valid
    target_routes = [a["target_route"] for a in alerts]
    valid_routes = {"/admin/hr/recruitment", "/admin/hr/onboarding", "/admin/hr/training", "/admin/hr/policies"}
    record("Test 10: Alert target routes point to valid HR tabs",
           any(r in valid_routes for r in target_routes),
           f"Routes: {target_routes}")

    # Test 11: Cross-Module Unified Recent Activities
    activities = data.get("recent_activities", [])
    record("Test 11: Cross-Module Unified Activity Feed",
           len(activities) >= 4 and all("module" in a and "action" in a and "actor_name" in a for a in activities),
           f"Got {len(activities)} activities")

    # Test 12: Teacher / Staff Role Allowed to View Overview
    res_teacher = client.get("/api/v1/hr/overview/stats", headers=headers_teacher_a)
    record("Test 12: Staff / Teacher Role Can View Overview",
           res_teacher.status_code == 200,
           f"Got {res_teacher.status_code}")

    # Test 13: Student Role Forbidden Access (403)
    res_student = client.get("/api/v1/hr/overview/stats", headers=headers_student_a)
    record("Test 13: Student Role Forbidden (403)",
           res_student.status_code == 403,
           f"Got {res_student.status_code}")

    # Test 14: Multi-Tenant Data Isolation (School B has isolated counts)
    res_b = client.get("/api/v1/hr/overview/stats", headers=headers_admin_b)
    data_b = res_b.json().get("data", {}) if res_b.status_code == 200 else {}
    record("Test 14: Multi-Tenant Isolation (School B isolated)",
           res_b.status_code == 200 and data_b.get("workforce", {}).get("total_employees", 0) != wf.get("total_employees", 0),
           f"Got School B total: {data_b.get('workforce', {}).get('total_employees')}")

    # Test 15: Executive Summary CSV Export
    res_csv = client.get("/api/v1/hr/overview/export", headers=headers_admin_a)
    record("Test 15: Executive Summary CSV Export",
           res_csv.status_code == 200 and "text/csv" in res_csv.headers.get("content-type", "") and "HR MANAGEMENT EXECUTIVE SUMMARY" in res_csv.text,
           f"Got {res_csv.status_code}, content-type: {res_csv.headers.get('content-type')}")

    # Test 16: Executive CSV contains all 5 module sections
    csv_text = res_csv.text if res_csv.status_code == 200 else ""
    has_all_sections = (
        "WORKFORCE" in csv_text and
        "RECRUITMENT" in csv_text and
        "ONBOARDING" in csv_text and
        "TRAINING" in csv_text and
        "POLICIES" in csv_text
    )
    record("Test 16: CSV Export includes all 5 HR Module Sections",
           has_all_sections,
           "Missing one or more module sections in CSV")

    print("-" * 75)
    print(f"OVERVIEW TEST SUMMARY: Total: {passed + failed} | Passed: {passed} | Failed: {failed}")
    print("=" * 75)

    if failed > 0:
        sys.exit(1)


if __name__ == "__main__":
    run_tests()
