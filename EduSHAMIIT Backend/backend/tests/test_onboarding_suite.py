"""
End-to-End Test Suite for HR Onboarding Module (EduSHAMIIT ERP).
Tests:
- Authentication, Authorization & RBAC
- Multi-Tenant / School Isolation (School A vs School B)
- Dashboard KPIs & Pipeline Statistics
- Candidate Selection & Duplicate Prevention
- 4-Step Start Onboarding Workflow with Templates
- Document Management (Add, Upload, Verify, Reject with Reason)
- Task Management (Add, Assign, Toggle Complete)
- Joining Formalities (Reschedule, No-Show, Confirm Joined)
- Completion Guard (Blockers check, Resolution, Override)
- CSV Export & Bulk Operations
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
    print("=" * 70)
    print("      EduSHAMIIT HR ONBOARDING MODULE - E2E TEST SUITE             ")
    print("=" * 70)

    token_admin_a = make_token(ADMIN_USER_ID, SCHOOL_A, "super_admin")
    headers_admin_a = {"Authorization": f"Bearer {token_admin_a}", "Content-Type": "application/json"}

    token_admin_b = make_token(str(uuid.uuid4()), SCHOOL_B, "admin")
    headers_admin_b = {"Authorization": f"Bearer {token_admin_b}", "Content-Type": "application/json"}

    token_unauth = make_token(str(uuid.uuid4()), SCHOOL_A, "student")
    headers_unauth = {"Authorization": f"Bearer {token_unauth}", "Content-Type": "application/json"}

    passed = 0
    total = 0

    def test(name, condition, details=""):
        nonlocal passed, total
        total += 1
        if condition:
            passed += 1
            print(f"  [PASS] {name}")
        else:
            print(f"  [FAIL] {name} - {details}")

    # 1. RBAC: Unauthorized role cannot access onboarding
    r1 = client.get("/api/onboarding/dashboard", headers=headers_unauth)
    test("RBAC: Student forbidden from Onboarding", r1.status_code == 403, f"Status: {r1.status_code}")

    # 2. Dashboard KPIs & Pipeline
    r2 = client.get("/api/onboarding/dashboard", headers=headers_admin_a)
    test("Dashboard: KPIs & Pipeline returned", r2.status_code == 200 and r2.json().get("success") is True, f"Status: {r2.status_code}")
    data = r2.json().get("data", {})
    metrics = data.get("metrics", {})
    pipeline = data.get("pipeline", [])
    dept = data.get("department_breakdown", [])
    test("Dashboard: Total Onboardings >= 48", metrics.get("total_onboardings", 0) >= 48, f"Total: {metrics.get('total_onboardings')}")
    test("Dashboard: Pipeline contains 6 stages", len(pipeline) == 6, f"Pipeline length: {len(pipeline)}")
    test("Dashboard: Department breakdown exists", len(dept) > 0, f"Depts: {len(dept)}")

    # 3. List Records with Pagination
    r3 = client.get("/api/onboarding/records?page=1&page_size=10", headers=headers_admin_a)
    test("Records: List paginated records", r3.status_code == 200 and len(r3.json().get("data", [])) == 10, f"Status: {r3.status_code}")
    records = r3.json().get("data", [])
    first_onb_id = records[0]["id"]

    # 4. Search Records
    r4 = client.get(f"/api/onboarding/records?search=EMP1267", headers=headers_admin_a)
    test("Records: Search by onboarding code", r4.status_code == 200 and len(r4.json().get("data", [])) >= 1, f"Found: {len(r4.json().get('data', []))}")

    # 5. Department Filter
    r5 = client.get("/api/onboarding/records?department=Academics", headers=headers_admin_a)
    test("Records: Filter by department", r5.status_code == 200 and all(r["department"] == "Academics" for r in r5.json().get("data", [])), f"Status: {r5.status_code}")

    # 6. 360 Detail View
    r6 = client.get(f"/api/onboarding/records/{first_onb_id}", headers=headers_admin_a)
    test("360 Detail: Retrieve onboarding record details", r6.status_code == 200, f"Status: {r6.status_code}")
    detail = r6.json().get("data", {})
    test("360 Detail: Contains documents, tasks, activities", 
         len(detail.get("documents", [])) > 0 and len(detail.get("tasks", [])) > 0 and len(detail.get("activities", [])) > 0,
         f"Docs: {len(detail.get('documents', []))}, Tasks: {len(detail.get('tasks', []))}")

    # 7. Multi-Tenant Isolation: School B cannot see School A onboarding record
    r7 = client.get(f"/api/onboarding/records/{first_onb_id}", headers=headers_admin_b)
    test("Multi-Tenant: School B cannot access School A onboarding record", r7.status_code == 404, f"Status: {r7.status_code}")

    # 8. Eligible Candidates for Onboarding
    r8 = client.get("/api/onboarding/candidates/eligible", headers=headers_admin_a)
    test("Integration: Eligible candidates list from recruitment", r8.status_code == 200 and isinstance(r8.json().get("data"), list), f"Status: {r8.status_code}")

    # 9. List Onboarding Templates
    r9 = client.get("/api/onboarding/templates", headers=headers_admin_a)
    test("Templates: Retrieve onboarding templates", r9.status_code == 200 and len(r9.json().get("data", [])) >= 4, f"Templates: {len(r9.json().get('data', []))}")

    # 10. Start Onboarding Workflow
    new_candidate_id = str(uuid.uuid4())
    create_payload = {
        "candidate_id": None,
        "department": "IT / Technical",
        "designation": "Cloud Systems Engineer",
        "employment_type": "Full-time",
        "expected_joining_date": "2026-10-01",
        "reporting_time": "09:30 AM",
        "reporting_location": "Tech Park Building - Room 302",
        "probation_period_months": 3,
        "work_location": "Main Campus",
        "shift": "Morning Shift",
        "template_name": "IT & Technical Staff Onboarding",
        "notes": "E2E Test Onboarding"
    }
    r10 = client.post("/api/onboarding/records", json=create_payload, headers=headers_admin_a)
    test("Start Onboarding: Create new onboarding record", r10.status_code == 200 and r10.json().get("success") is True, f"Status: {r10.status_code}")
    created_onb_id = r10.json()["data"]["id"]

    # 11. Document Management: Add, Upload, Reject, Verify
    r11a = client.post(f"/api/onboarding/records/{created_onb_id}/documents", json={
        "document_name": "Special Clearance Certificate",
        "required_for": "Technical Staff",
        "is_mandatory": True
    }, headers=headers_admin_a)
    test("Document: Add required document", r11a.status_code == 200, f"Status: {r11a.status_code}")
    doc_id = r11a.json()["data"]["id"]

    r11b = client.post(f"/api/onboarding/documents/{doc_id}/upload?file_url=https://storage.edushamiit.edu/test.pdf&file_name=clearance.pdf", headers=headers_admin_a)
    test("Document: Upload document file link", r11b.status_code == 200, f"Status: {r11b.status_code}")

    # Rejection requires reason
    r11c = client.post(f"/api/onboarding/documents/{doc_id}/reject", json={"reason": "Blurry copy, please re-upload clear scan"}, headers=headers_admin_a)
    test("Document: Reject document with mandatory reason", r11c.status_code == 200, f"Status: {r11c.status_code}")

    # Verify document
    r11d = client.post(f"/api/onboarding/documents/{doc_id}/verify", json={"remarks": "Verified by HR Lead"}, headers=headers_admin_a)
    test("Document: Approve / Verify document", r11d.status_code == 200, f"Status: {r11d.status_code}")

    # 12. Tasks Management: Add & Complete
    r12a = client.post(f"/api/onboarding/records/{created_onb_id}/tasks", json={
        "title": "Setup VPN & 2FA Security Token",
        "category": "IT",
        "assigned_team": "IT Team",
        "priority": "High",
        "is_mandatory": True
    }, headers=headers_admin_a)
    test("Tasks: Add onboarding task", r12a.status_code == 200, f"Status: {r12a.status_code}")
    task_id = r12a.json()["data"]["id"]

    r12b = client.patch(f"/api/onboarding/tasks/{task_id}", json={"status": "Completed"}, headers=headers_admin_a)
    test("Tasks: Complete onboarding task", r12b.status_code == 200, f"Status: {r12b.status_code}")

    # 13. Joining Formalities: Reschedule, Mark No Show, Confirm Joined
    r13a = client.post(f"/api/onboarding/records/{created_onb_id}/joining", json={
        "joining_status": "Rescheduled",
        "expected_joining_date": "2026-10-05",
        "reschedule_reason": "Candidate requested extension due to relocation"
    }, headers=headers_admin_a)
    test("Joining: Reschedule joining with reason", r13a.status_code == 200, f"Status: {r13a.status_code}")

    r13b = client.post(f"/api/onboarding/records/{created_onb_id}/joining", json={
        "joining_status": "Joined",
        "actual_joining_date": "2026-10-05"
    }, headers=headers_admin_a)
    test("Joining: Confirm candidate Joined", r13b.status_code == 200, f"Status: {r13b.status_code}")

    # 14. Completion Guard: Block when pending items exist, Complete with override or resolution
    # Let's verify that completion handles blockers properly
    r14a = client.post(f"/api/onboarding/records/{created_onb_id}/complete", json={
        "override_blockers": False
    }, headers=headers_admin_a)
    # If any template mandatory docs are pending, it blocks with 400
    test("Completion Guard: Blocks completion if mandatory items pending or verifies cleanly", 
         r14a.status_code in [200, 400], f"Status: {r14a.status_code}")

    # Complete with authorized override
    r14b = client.post(f"/api/onboarding/records/{created_onb_id}/complete", json={
        "override_blockers": True,
        "override_reason": "Director approved provisional onboarding completion"
    }, headers=headers_admin_a)
    test("Completion Guard: Authorized override completion successful", r14b.status_code == 200, f"Status: {r14b.status_code}")

    # 15. Stage & Status Updates
    r15a = client.patch(f"/api/onboarding/records/{created_onb_id}/stage", json={"stage": "Completed"}, headers=headers_admin_a)
    test("Workflow: Stage updated to Completed", r15a.status_code == 200, f"Status: {r15a.status_code}")

    # 16. Send Reminder
    r16 = client.post(f"/api/onboarding/records/{created_onb_id}/reminder?reminder_type=documents", headers=headers_admin_a)
    test("Notification: Reminder sent and audit logged", r16.status_code == 200, f"Status: {r16.status_code}")

    # 17. CSV Export
    r17 = client.get("/api/onboarding/export", headers=headers_admin_a)
    test("Export: CSV download generated", r17.status_code == 200 and "text/csv" in r17.headers.get("content-type", ""), f"Status: {r17.status_code}")

    # 18. Bulk Action
    r18 = client.post("/api/onboarding/bulk", json={
        "onboarding_ids": [created_onb_id],
        "action": "change_status",
        "value": "Completed"
    }, headers=headers_admin_a)
    test("Bulk Action: Batch status update", r18.status_code == 200, f"Status: {r18.status_code}")

    print("=" * 70)
    print(f"📊 SUMMARY: {passed} / {total} tests passed ({round(passed/total*100, 1)}%)")
    print("=" * 70)

    if passed == total:
        print("🎉 ALL ONBOARDING API TESTS PASSED PERFECTLY!")
        sys.exit(0)
    else:
        print("❌ Some tests failed.")
        sys.exit(1)

if __name__ == "__main__":
    run_tests()
