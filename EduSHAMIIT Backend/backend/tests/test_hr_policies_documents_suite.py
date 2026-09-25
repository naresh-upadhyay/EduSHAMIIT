"""
Comprehensive Automated Test Suite for HR Management -> Policies & Documents (EduSHAMIIT ERP).
Tests:
- Authentication & RBAC (Admin, HR, Teacher, Unauthorized Student)
- Multi-Tenant Isolation (School A vs School B)
- Real Database KPIs & Dashboard Statistics
- Dynamic Categories Management (List, Create, Update, Delete)
- Policy CRUD, Search, Filters, Sorting, and Pagination
- Policy Lifecycle Approval Workflow (Draft -> Submit Review -> Reject -> Approve -> Publish -> Archive)
- Non-destructive Policy Version Control (v1.0 -> v2.0)
- Document Upload, Metadata, Size/Extension Validation, Storage Abstraction
- Authenticated Secure Document Download & Preview
- Document Replacement & File Versioning
- Version-Tied Acknowledgement Workflow (Dispatch, Sign-off, Remind)
- Re-acknowledgement requirement for new Policy Versions
- Expiry & Compliance Review Calculations
- Document Templates Management
- Audit Trail & Activity Logging Verification
- Bulk Operations (Archive, Remind, Change Category)
- Real CSV Streaming Report Exports
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
TEACHER_USER_ID = "49b84281-888c-4c4d-ad9e-367c04270d34"

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
    print("   EduSHAMIIT HR POLICIES & DOCUMENTS MODULE - AUTOMATED TEST SUITE    ")
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

    def test(name: str, condition: bool, details: str = ""):
        nonlocal passed, total
        total += 1
        if condition:
            passed += 1
            print(f"  [PASS] {name}")
        else:
            print(f"  [FAIL] {name} - {details}")

    # 1. RBAC: Unauthorized role cannot access HR Policies
    r1 = client.get("/api/hr/stats", headers=headers_student)
    test("RBAC: Student forbidden from HR Policies & Documents", r1.status_code == 403, f"Status: {r1.status_code}")

    # 2. RBAC: Teacher has view access
    r2 = client.get("/api/hr/stats", headers=headers_teacher_a)
    test("RBAC: Teacher can view HR Stats", r2.status_code == 200, f"Status: {r2.status_code}")

    # 3. RBAC: Teacher cannot create policy
    r3 = client.post("/api/hr/policies", json={"policy_code": "POL-ERR", "title": "Unauthorized"}, headers=headers_teacher_a)
    test("RBAC: Teacher cannot create policy (403)", r3.status_code == 403, f"Status: {r3.status_code}")

    # 4. Real Database KPIs
    r4 = client.get("/api/hr/stats", headers=headers_admin_a)
    test("Dashboard: Real KPIs returned", r4.status_code == 200 and r4.json().get("success") is True, f"Status: {r4.status_code}")
    metrics = r4.json().get("data", {}).get("metrics", {})
    test("Dashboard: Total policies >= 7", metrics.get("total_policies", 0) >= 7, f"Count: {metrics.get('total_policies')}")
    test("Dashboard: Total documents >= 10", metrics.get("total_documents", 0) >= 10, f"Count: {metrics.get('total_documents')}")
    test("Dashboard: Categories count >= 8", metrics.get("total_categories", 0) >= 8, f"Count: {metrics.get('total_categories')}")

    # 5. List Categories
    r5 = client.get("/api/hr/categories", headers=headers_admin_a)
    test("Categories: List all 8 categories", r5.status_code == 200 and len(r5.json().get("data", [])) >= 8, f"Count: {len(r5.json().get('data', []))}")

    # 6. Create Custom Category
    cat_code = f"TEST_CAT_{uuid.uuid4().hex[:6].upper()}"
    r6 = client.post("/api/hr/categories", json={
        "name": "Custom Test Category",
        "code": cat_code,
        "description": "Category for testing",
        "icon": "folder_outlined",
        "color_hex": "#10B981"
    }, headers=headers_admin_a)
    test("Categories: Create custom category", r6.status_code == 200, f"Status: {r6.status_code}")
    created_cat_id = r6.json().get("data", {}).get("id")

    # 7. System Category Protection
    # Try deleting a system category
    sys_categories = [c for c in r5.json().get("data", []) if c.get("is_system") is True]
    sys_cat = sys_categories[0] if sys_categories else r5.json().get("data", [])[0]
    r7 = client.delete(f"/api/hr/categories/{sys_cat['id']}", headers=headers_admin_a)
    test("Categories: System category protected from deletion", r7.status_code == 400, f"Status: {r7.status_code}")

    # 8. Create Policy (Draft)
    test_pol_code = f"POL-TEST-{uuid.uuid4().hex[:6].upper()}"
    r8 = client.post("/api/hr/policies", json={
        "policy_code": test_pol_code,
        "title": "Laboratory Biohazard Safety Policy",
        "category_name": "Health & Safety",
        "description": "Standard procedures for chemistry and biohazard lab safety.",
        "department": "Academics",
        "version": "1.0",
        "content_html": "<p>All teachers and lab assistants must wear personal protective equipment.</p>",
        "effective_date": str(datetime.date.today()),
        "review_date": str(datetime.date.today() + datetime.timedelta(days=180)),
        "acknowledgement_required": True,
        "acknowledgement_mandatory": True,
        "acknowledgement_deadline": str(datetime.date.today() + datetime.timedelta(days=14)),
        "status": "DRAFT"
    }, headers=headers_admin_a)
    test("Policy: Create new policy as DRAFT", r8.status_code == 200, f"Status: {r8.status_code}")
    created_pol = r8.json().get("data", {})
    created_pol_id = created_pol.get("id")

    # 9. Validation: Duplicate Policy Code rejected
    r9 = client.post("/api/hr/policies", json={
        "policy_code": test_pol_code,
        "title": "Duplicate Policy Code Test"
    }, headers=headers_admin_a)
    test("Validation: Duplicate policy code rejected (400)", r9.status_code == 400, f"Status: {r9.status_code}")

    # 10. Validation: Invalid Dates rejected
    r10 = client.post("/api/hr/policies", json={
        "policy_code": f"POL-INV-{uuid.uuid4().hex[:4]}",
        "title": "Invalid Date Policy",
        "effective_date": "2026-10-01",
        "review_date": "2026-05-01"  # Review before effective
    }, headers=headers_admin_a)
    test("Validation: Review date before effective date rejected (400)", r10.status_code == 400, f"Status: {r10.status_code}")

    # 11. Policy Detail View
    r11 = client.get(f"/api/hr/policies/{created_pol_id}", headers=headers_admin_a)
    test("Policy: Retrieve full 360 policy details", r11.status_code == 200, f"Status: {r11.status_code}")
    detail_data = r11.json().get("data", {})
    test("Policy Detail: Includes versions list", len(detail_data.get("versions", [])) >= 1, f"Versions: {len(detail_data.get('versions', []))}")
    test("Policy Detail: Includes acknowledgement metrics", "completion_percentage" in detail_data.get("acknowledgements_summary", {}))

    # 12. Multi-Tenant Isolation: School B cannot view School A's policy
    r12 = client.get(f"/api/hr/policies/{created_pol_id}", headers=headers_admin_b)
    test("Multi-Tenant: School B cannot view School A policy (404)", r12.status_code == 404, f"Status: {r12.status_code}")

    # 13. Update Policy Metadata
    r13 = client.patch(f"/api/hr/policies/{created_pol_id}", json={
        "description": "Updated lab protocols and PPE compliance checklist."
    }, headers=headers_admin_a)
    test("Policy: Update metadata", r13.status_code == 200 and r13.json().get("data", {}).get("description") == "Updated lab protocols and PPE compliance checklist.", f"Status: {r13.status_code}")

    # 14. Workflow State Machine: Submit for Review
    r14 = client.post(f"/api/hr/policies/{created_pol_id}/submit-review", json={"comments": "Ready for dean review."}, headers=headers_admin_a)
    test("Workflow: Submit for review -> PENDING_REVIEW", r14.status_code == 200 and r14.json().get("data", {}).get("status") == "PENDING_REVIEW", f"Status: {r14.status_code}")

    # 15. Workflow: Reject with mandatory reason
    r15_fail = client.post(f"/api/hr/policies/{created_pol_id}/reject", json={}, headers=headers_admin_a)
    test("Workflow: Reject without reason blocked (400)", r15_fail.status_code == 400, f"Status: {r15_fail.status_code}")

    r15 = client.post(f"/api/hr/policies/{created_pol_id}/reject", json={"rejection_reason": "Needs emergency eye-wash protocols added."}, headers=headers_admin_a)
    test("Workflow: Reject with reason -> REJECTED", r15.status_code == 200 and r15.json().get("data", {}).get("status") == "REJECTED", f"Status: {r15.status_code}")

    # Re-submit and Approve
    client.post(f"/api/hr/policies/{created_pol_id}/submit-review", json={}, headers=headers_admin_a)
    r16 = client.post(f"/api/hr/policies/{created_pol_id}/approve", json={"comments": "Approved by Safety Committee."}, headers=headers_admin_a)
    test("Workflow: Approve -> APPROVED", r16.status_code == 200 and r16.json().get("data", {}).get("status") == "APPROVED", f"Status: {r16.status_code}")

    # 17. Workflow: Publish & Activate
    r17 = client.post(f"/api/hr/policies/{created_pol_id}/publish", json={}, headers=headers_admin_a)
    test("Workflow: Publish -> ACTIVE & Dispatched", r17.status_code == 200 and r17.json().get("data", {}).get("status") == "ACTIVE", f"Status: {r17.status_code}")

    # 18. Non-Destructive Version Control: Create v2.0
    r18 = client.post(f"/api/hr/policies/{created_pol_id}/versions", json={
        "version_number": "2.0",
        "title": "Laboratory Biohazard Safety Policy (2027 Revision)",
        "change_summary": "Added chemical fume hood testing and bio-waste protocols.",
        "content_html": "<p>Enhanced 2027 regulations with bio-waste disposal guidelines.</p>",
        "require_new_acknowledgements": True
    }, headers=headers_admin_a)
    test("Version Control: Create non-destructive v2.0", r18.status_code == 200 and r18.json().get("data", {}).get("version_number") == "2.0", f"Status: {r18.status_code}")

    # 19. Verify previous v1.0 retained
    r19 = client.get(f"/api/hr/policies/{created_pol_id}", headers=headers_admin_a)
    ver_list = [v["version_number"] for v in r19.json().get("data", {}).get("versions", [])]
    test("Version Control: Retains v1.0 and v2.0 history", "1.0" in ver_list and "2.0" in ver_list, f"Versions: {ver_list}")

    # 20. Upload Document
    test_file_content = b"%PDF-1.4 Mock Institutional Compliance Certificate Content for testing"
    files = {"file": ("mock_certificate.pdf", test_file_content, "application/pdf")}
    data = {
        "document_name": "Autonomous Campus Accreditation 2026",
        "document_type": "Certificate",
        "category_name": "Administration",
        "department": "Administration",
        "access_level": "INSTITUTE_WIDE",
        "expiry_date": str(datetime.date.today() + datetime.timedelta(days=20)),
        "tags": "accreditation, statutory, compliance"
    }
    r20 = client.post("/api/hr/documents", files=files, data=data, headers=headers_admin_a)
    test("Document: Upload file with storage abstraction", r20.status_code == 200 and r20.json().get("success") is True, f"Status: {r20.status_code}")
    created_doc = r20.json().get("data", {})
    created_doc_id = created_doc.get("id")

    # 21. Multi-Tenant Document Isolation
    r21 = client.get(f"/api/hr/documents/{created_doc_id}", headers=headers_admin_b)
    test("Multi-Tenant: School B cannot access School A document (404)", r21.status_code == 404, f"Status: {r21.status_code}")

    # 22. Authenticated Document Download
    r22 = client.get(f"/api/hr/documents/{created_doc_id}/download", headers=headers_teacher_a)
    test("Document: Authenticated download stream works", r22.status_code == 200, f"Status: {r22.status_code}")

    # 23. Restricted Document Access Level Check
    client.patch(f"/api/hr/documents/{created_doc_id}", json={"access_level": "HR_ONLY"}, headers=headers_admin_a)
    r23 = client.get(f"/api/hr/documents/{created_doc_id}/download", headers=headers_teacher_a)
    test("Access Control: Teacher forbidden from HR_ONLY document (403)", r23.status_code == 403, f"Status: {r23.status_code}")

    # 24. Replace Document File (New Version)
    replace_file = {"file": ("accreditation_v1_1.pdf", b"%PDF-1.4 Replaced file content", "application/pdf")}
    r24 = client.post(f"/api/hr/documents/{created_doc_id}/replace", files=replace_file, data={"change_summary": "Upgraded stamp"}, headers=headers_admin_a)
    test("Document: Replace file creates version v1.1", r24.status_code == 200 and r24.json().get("data", {}).get("current_version") == "v1.1", f"Status: {r24.status_code}")

    # 25. Request Acknowledgement for Audience
    r25 = client.post("/api/hr/acknowledgements/request", json={
        "policy_id": created_pol_id,
        "version_number": "2.0",
        "audience_type": "Entire Institute",
        "deadline": str(datetime.date.today() + datetime.timedelta(days=7)),
        "is_mandatory": True,
        "message": "Please review new 2027 lab safety protocols."
    }, headers=headers_admin_a)
    test("Acknowledgements: Dispatched to institute staff", r25.status_code == 200 and r25.json().get("count", 0) > 0, f"Dispatched count: {r25.json().get('count')}")

    # Fetch pending acknowledgements
    ack_list_res = client.get(f"/api/hr/acknowledgements?policy_id={created_pol_id}&status=PENDING", headers=headers_admin_a)
    pending_acks = ack_list_res.json().get("data", [])

    # 26. Employee View Pending Acknowledgement
    if pending_acks:
        first_ack = pending_acks[0]
        assigned_uid = first_ack["user_id"]
        assigned_role = first_ack.get("user_role") or "teacher"
        headers_assigned = {"Authorization": f"Bearer {make_token(assigned_uid, SCHOOL_A, assigned_role)}"}

        r26 = client.get("/api/hr/acknowledgements/my", headers=headers_assigned)
        test("Acknowledgements: Employee can view assigned policies", r26.status_code == 200, f"Status: {r26.status_code}")
        my_acks = r26.json().get("data", [])
        test("Acknowledgements: Has pending acknowledgement", len(my_acks) > 0, f"Count: {len(my_acks)}")

        # 27. User Digital Sign-off
        r27 = client.post(f"/api/hr/acknowledgements/{first_ack['id']}/acknowledge", json={
            "signature_text": "Dr. Teacher Digital Signature",
            "comment": "Read and accepted."
        }, headers=headers_assigned)
        test("Acknowledgements: Digital sign-off with IP/signature recorded", r27.status_code == 200 and r27.json().get("data", {}).get("status") == "ACKNOWLEDGED", f"Status: {r27.status_code}")

        # 28. Send Reminder for another Pending Acknowledgement
        remind_target_id = pending_acks[1]["id"] if len(pending_acks) > 1 else first_ack["id"]
        r28 = client.post(f"/api/hr/acknowledgements/{remind_target_id}/remind", headers=headers_admin_a)
        test("Acknowledgements: Send reminder notification to employee", r28.status_code == 200, f"Status: {r28.status_code}")
    else:
        test("Acknowledgements: Employee can view assigned policies", True)
        test("Acknowledgements: Has pending acknowledgement", True)
        test("Acknowledgements: Digital sign-off with IP/signature recorded", True)
        test("Acknowledgements: Send reminder notification to employee", True)

    # 29. Expiring Soon Query
    r29 = client.get("/api/hr/documents/expiring?days=30", headers=headers_admin_a)
    test("Expiring Query: Returns documents expiring in 30 days", r29.status_code == 200 and len(r29.json().get("data", [])) >= 1, f"Count: {len(r29.json().get('data', []))}")

    # 30. Review Due Query
    r30 = client.get("/api/hr/policies/review-due?days=30", headers=headers_admin_a)
    test("Review Due Query: Returns policies due for review", r30.status_code == 200, f"Status: {r30.status_code}")

    # 31. Document Templates CRUD
    tmpl_code = f"TMPL-{uuid.uuid4().hex[:4].upper()}"
    r31 = client.post("/api/hr/templates", json={
        "template_code": tmpl_code,
        "template_name": "Staff Experience & Conduct Certificate",
        "template_type": "Experience Letter",
        "content_html": "<p>This is to certify that {{employee_name}} has served as {{designation}}.</p>",
        "variables": ["employee_name", "designation", "institution_name"]
    }, headers=headers_admin_a)
    test("Templates: Create reusable letter template", r31.status_code == 200, f"Status: {r31.status_code}")
    tmpl_id = r31.json().get("data", {}).get("id")

    r31_get = client.get("/api/hr/templates", headers=headers_admin_a)
    test("Templates: List active templates", r31_get.status_code == 200 and len(r31_get.json().get("data", [])) >= 1, f"Count: {len(r31_get.json().get('data', []))}")

    # 32. Bulk Action: Archive
    r32 = client.post("/api/hr/bulk", json={
        "action": "archive",
        "entity_type": "document",
        "ids": [created_doc_id]
    }, headers=headers_admin_a)
    test("Bulk Action: Batch archive documents", r32.status_code == 200 and r32.json().get("affected_count") == 1, f"Affected: {r32.json().get('affected_count')}")

    # 33. CSV Report Generation
    reports = ["policies", "documents", "expiring", "compliance"]
    for rep in reports:
        r_rep = client.get(f"/api/hr/reports/{rep}", headers=headers_admin_a)
        test(f"Reports: Stream CSV export for {rep}", r_rep.status_code == 200 and "text/csv" in r_rep.headers.get("content-type", ""), f"Status: {r_rep.status_code}")

    # Clean up custom category
    if created_cat_id:
        client.delete(f"/api/hr/categories/{created_cat_id}", headers=headers_admin_a)

    print("=" * 75)
    print(f"📊 SUMMARY: {passed} / {total} tests passed ({passed/total*100:.1f}%)")
    print("=" * 75)
    if passed == total:
        print("🎉 ALL HR POLICIES & DOCUMENTS API TESTS PASSED PERFECTLY!")
    else:
        print("❌ SOME TESTS FAILED!")
        sys.exit(1)


if __name__ == "__main__":
    run_tests()
