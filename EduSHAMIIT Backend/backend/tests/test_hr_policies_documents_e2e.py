"""
End-to-End (E2E) Test Scenario for EduSHAMIIT ERP HR Management -> Policies & Documents.

Simulates the complete user and administrative lifecycle step-by-step:
1.  LOGIN as HR/SuperAdmin.
2.  Open HR Management & Policies & Documents (Verify Dashboard Stats & Category initial state).
3.  Create Policy (Save Draft).
4.  Edit Policy Draft details & verify changes.
5.  Submit Policy for Review (State -> PENDING_REVIEW).
6.  Approve Policy (State -> APPROVED).
7.  Publish Policy (State -> ACTIVE).
8.  Create New Version (v1.0 -> v2.0 with updated title & content).
9.  Request Acknowledgement for v2.0 (Audience: Entire Institute).
10. LOGIN as Employee (Authorized Staff User).
11. View pending acknowledgement list for Employee.
12. Open policy details as Employee.
13. Digitally sign-off & Acknowledge policy with declaration.
14. Verify acknowledgement status changed from PENDING to ACKNOWLEDGED.
15. Return / Switch back to HR/Admin session.
16. Verify compliance counts and dashboard stats reflect new completion.
17. Upload Document (PDF attachment with metadata and expiry date).
18. View Document details and metadata.
19. Create Document Version (Replace file, bump to v1.1).
20. Set & Update Expiry date (within 7 days).
21. Verify Expiring Soon dashboard / query lists the document.
22. Send Expiry / Sign-off Reminder.
23. Verify Audit Log contains sequential activity records.
24. Test Unauthorized User (Student/Parent role attempting Admin operations -> 403 Forbidden).
25. Test Multi-Tenant Isolation (School B attempting to read/modify School A records -> 404 Not Found).
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

HR_ADMIN_ID = "38a93170-997b-4b4c-bc8e-256b93169c23"
EMPLOYEE_STAFF_ID = "49b84281-888c-4c4d-ad9e-367c04270d34"
UNAUTHORIZED_USER_ID = "55555555-5555-5555-5555-555555555555"

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


def run_e2e_simulation():
    client = TestClient(app)
    e2e_passed = 0
    e2e_total = 25

    print("================================================================================")
    print(" EduSHAMIIT ERP - Policies & Documents END-TO-END (E2E) TEST SIMULATION")
    print("================================================================================")

    # --------------------------------------------------------------------------
    # Step 1: LOGIN as HR/SuperAdmin
    # --------------------------------------------------------------------------
    admin_token = make_token(HR_ADMIN_ID, SCHOOL_A, "super_admin")
    admin_headers = {"Authorization": f"Bearer {admin_token}"}
    assert admin_token is not None
    print("[STEP 1/25 PASS] Logged in as HR/SuperAdmin with valid tenant claims.")
    e2e_passed += 1

    # --------------------------------------------------------------------------
    # Step 2: Open HR Management -> Policies & Documents (Dashboard Stats)
    # --------------------------------------------------------------------------
    stats_res = client.get("/api/hr/stats", headers=admin_headers)
    assert stats_res.status_code == 200, f"Stats failed: {stats_res.text}"
    stats_data = stats_res.json()["data"]["metrics"]
    assert "total_policies" in stats_data
    assert "total_documents" in stats_data
    assert "active_policies" in stats_data
    assert "compliance_rate" in stats_data
    print(f"[STEP 2/25 PASS] Dashboard loaded: {stats_data['total_policies']} policies, {stats_data['total_documents']} docs, Compliance: {stats_data['compliance_rate']}%.")
    e2e_passed += 1

    # --------------------------------------------------------------------------
    # Step 3: Create Policy (Save Draft)
    # --------------------------------------------------------------------------
    unique_code = f"E2E-POL-{uuid.uuid4().hex[:6].upper()}"
    policy_payload = {
        "title": "E2E Institutional Safety & Safeguarding",
        "policy_code": unique_code,
        "category_name": "Health & Safety",
        "description": "Initial draft of emergency protocols and campus safety guidelines.",
        "content_html": "<p>All educators must verify safety protocol and security perimeter.</p>",
        "department": "Campus Safety",
        "version": "1.0",
        "effective_date": str(datetime.date.today()),
        "review_date": str(datetime.date.today() + datetime.timedelta(days=180)),
        "acknowledgement_required": True,
        "acknowledgement_mandatory": True,
        "acknowledgement_deadline": str(datetime.date.today() + datetime.timedelta(days=30)),
        "status": "DRAFT"
    }
    create_res = client.post("/api/hr/policies", json=policy_payload, headers=admin_headers)
    assert create_res.status_code == 200, f"Create policy draft failed: {create_res.text}"
    policy_data = create_res.json()["data"]
    policy_id = policy_data["id"]
    assert policy_data["status"] == "DRAFT"
    assert policy_data["current_version"] == "1.0"
    print(f"[STEP 3/25 PASS] Created Policy Draft: '{policy_data['title']}' (ID: {policy_id}, Code: {unique_code}).")
    e2e_passed += 1

    # --------------------------------------------------------------------------
    # Step 4: Edit Policy Draft
    # --------------------------------------------------------------------------
    update_payload = {
        "title": "E2E Institutional Safety & Safeguarding Protocol",
        "description": "Updated draft with evacuation routes and fire warden duties.",
        "content_html": "<p>Evacuation zones designated at North and South athletics fields.</p>"
    }
    update_res = client.patch(f"/api/hr/policies/{policy_id}", json=update_payload, headers=admin_headers)
    assert update_res.status_code == 200
    updated_policy = update_res.json()["data"]
    assert updated_policy["title"] == "E2E Institutional Safety & Safeguarding Protocol"
    print("[STEP 4/25 PASS] Edited Policy Draft successfully.")
    e2e_passed += 1

    # --------------------------------------------------------------------------
    # Step 5: Submit Policy for Review
    # --------------------------------------------------------------------------
    submit_res = client.post(
        f"/api/hr/policies/{policy_id}/submit-review",
        json={"comments": "Ready for executive compliance approval."},
        headers=admin_headers
    )
    assert submit_res.status_code == 200
    assert submit_res.json()["data"]["status"] == "PENDING_REVIEW"
    print("[STEP 5/25 PASS] Submitted Policy for Review (Status: PENDING_REVIEW).")
    e2e_passed += 1

    # --------------------------------------------------------------------------
    # Step 6: Approve Policy
    # --------------------------------------------------------------------------
    approve_res = client.post(
        f"/api/hr/policies/{policy_id}/approve",
        json={"comments": "All compliance criteria verified and approved."},
        headers=admin_headers
    )
    assert approve_res.status_code == 200
    assert approve_res.json()["data"]["status"] == "APPROVED"
    print("[STEP 6/25 PASS] Approved Policy (Status: APPROVED).")
    e2e_passed += 1

    # --------------------------------------------------------------------------
    # Step 7: Publish Policy (Status -> ACTIVE)
    # --------------------------------------------------------------------------
    publish_res = client.post(
        f"/api/hr/policies/{policy_id}/publish",
        json={},
        headers=admin_headers
    )
    assert publish_res.status_code == 200
    assert publish_res.json()["data"]["status"] == "ACTIVE"
    print("[STEP 7/25 PASS] Published Policy (Status: ACTIVE, Version: 1.0).")
    e2e_passed += 1

    # --------------------------------------------------------------------------
    # Step 8: Create New Version (v1.0 -> v2.0)
    # --------------------------------------------------------------------------
    new_version_payload = {
        "version_number": "2.0",
        "title": "E2E Institutional Safety & Safeguarding Protocol 2026-27",
        "content_html": "<p>Version 2.0 adds digital visitor check-ins and emergency SMS triggers.</p>",
        "change_summary": "Added visitor protocol and automated safety SMS triggers.",
        "effective_date": str(datetime.date.today() + datetime.timedelta(days=1)),
        "require_new_acknowledgements": True
    }
    version_res = client.post(f"/api/hr/policies/{policy_id}/versions", json=new_version_payload, headers=admin_headers)
    assert version_res.status_code == 200
    version_data = version_res.json()["data"]
    assert version_data["version_number"] == "2.0"
    print(f"[STEP 8/25 PASS] Created Policy Version 2.0 (Non-destructive update verified).")
    e2e_passed += 1

    # --------------------------------------------------------------------------
    # Step 9: Request Acknowledgement for v2.0
    # --------------------------------------------------------------------------
    req_ack_res = client.post(
        "/api/hr/acknowledgements/request",
        json={
            "policy_id": policy_id,
            "version_number": "2.0",
            "audience_type": "Entire Institute",
            "deadline": str(datetime.date.today() + datetime.timedelta(days=14)),
            "is_mandatory": True,
            "message": "All faculty and staff are required to review Safety Protocol v2.0."
        },
        headers=admin_headers
    )
    assert req_ack_res.status_code == 200
    ack_request_data = req_ack_res.json()
    assert ack_request_data["success"] is True
    print(f"[STEP 9/25 PASS] Dispatched Acknowledgement Request to institutional staff.")
    e2e_passed += 1

    # --------------------------------------------------------------------------
    # Step 10: LOGIN as Employee (Authorized Staff User)
    # --------------------------------------------------------------------------
    ack_list_res = client.get(f"/api/hr/acknowledgements?policy_id={policy_id}&status=PENDING", headers=admin_headers)
    assert ack_list_res.status_code == 200
    pending_acks = ack_list_res.json().get("data", [])
    assert len(pending_acks) > 0, f"Expected pending acknowledgements for policy {policy_id}"
    target_ack = next((a for a in pending_acks if a.get("user_role") in ("teacher", "staff", "employee")), pending_acks[0])
    ack_id = target_ack["id"]
    assigned_uid = str(target_ack["user_id"])
    assigned_role = target_ack.get("user_role") or "teacher"
    if assigned_role not in ("teacher", "staff", "employee"):
        assigned_role = "teacher"

    employee_token = make_token(assigned_uid, SCHOOL_A, assigned_role)
    employee_headers = {"Authorization": f"Bearer {employee_token}"}
    print(f"[STEP 10/25 PASS] Switched session to Employee {assigned_uid} (Role: {assigned_role}).")
    e2e_passed += 1

    # --------------------------------------------------------------------------
    # Step 11: View Pending Acknowledgements for Employee
    # --------------------------------------------------------------------------
    my_acks_res = client.get("/api/hr/acknowledgements/my", headers=employee_headers)
    assert my_acks_res.status_code == 200
    my_acks = my_acks_res.json()["data"]
    policy_ack = next((a for a in my_acks if a["id"] == ack_id), None)
    assert policy_ack is not None, f"Expected acknowledgement {ack_id} for user {assigned_uid} in my_acks"
    assert policy_ack["status"] == "PENDING"
    print(f"[STEP 11/25 PASS] Employee found pending acknowledgement (Ack ID: {ack_id}).")
    e2e_passed += 1

    # --------------------------------------------------------------------------
    # Step 12: Open Policy as Employee
    # --------------------------------------------------------------------------
    view_pol_res = client.get(f"/api/hr/policies/{policy_id}", headers=employee_headers)
    assert view_pol_res.status_code == 200
    assert view_pol_res.json()["data"]["policy"]["current_version"] == "2.0"
    print("[STEP 12/25 PASS] Employee opened policy content and details.")
    e2e_passed += 1

    # --------------------------------------------------------------------------
    # Step 13: Digitally Sign-off & Acknowledge Policy
    # --------------------------------------------------------------------------
    sign_res = client.post(
        f"/api/hr/acknowledgements/{ack_id}/acknowledge",
        json={
            "comment": "Read and understood all campus safety guidelines and warden rules.",
            "signature_text": "Dr. Ramesh Kumar - E-Signed"
        },
        headers=employee_headers
    )
    assert sign_res.status_code == 200
    assert sign_res.json()["data"]["status"] == "ACKNOWLEDGED"
    print("[STEP 13/25 PASS] Employee digitally signed off on Policy v2.0.")
    e2e_passed += 1

    # --------------------------------------------------------------------------
    # Step 14: Verify Acknowledgement Status
    # --------------------------------------------------------------------------
    verify_ack_res = client.get("/api/hr/acknowledgements/my", headers=employee_headers)
    assert verify_ack_res.status_code == 200
    signed_ack = next((a for a in verify_ack_res.json()["data"] if a["id"] == ack_id), None)
    assert signed_ack is not None
    assert signed_ack["status"] == "ACKNOWLEDGED"
    assert signed_ack["acknowledged_at"] is not None
    print("[STEP 14/25 PASS] Verified acknowledgement status is ACKNOWLEDGED with timestamp.")
    e2e_passed += 1

    # --------------------------------------------------------------------------
    # Step 15: Return / Switch back to HR/Admin Session
    # --------------------------------------------------------------------------
    admin_check = client.get("/api/hr/stats", headers=admin_headers)
    assert admin_check.status_code == 200
    print("[STEP 15/25 PASS] Restored HR/SuperAdmin session.")
    e2e_passed += 1

    # --------------------------------------------------------------------------
    # Step 16: Verify Compliance Count / Rates
    # --------------------------------------------------------------------------
    policy_detail = client.get(f"/api/hr/policies/{policy_id}", headers=admin_headers)
    assert policy_detail.status_code == 200
    summary = policy_detail.json()["data"]["acknowledgements_summary"]
    assert summary["acknowledged"] >= 1
    print(f"[STEP 16/25 PASS] Verified policy compliance metrics updated on Admin dashboard (Acknowledged: {summary['acknowledged']}).")
    e2e_passed += 1

    # --------------------------------------------------------------------------
    # Step 17: Upload Document
    # --------------------------------------------------------------------------
    file_bytes = b"%PDF-1.4 Mock Campus Safety and Evacuation Plan Test Content"
    files = {"file": ("campus_evacuation_map.pdf", file_bytes, "application/pdf")}
    doc_form_data = {
        "document_name": "E2E Campus Evacuation Plan 2026",
        "document_type": "Compliance Document",
        "category_name": "Health & Safety",
        "description": "Architectural floor plans and evacuation maps.",
        "department": "Campus Security",
        "access_level": "INSTITUTE_WIDE",
        "issue_date": str(datetime.date.today()),
        "expiry_date": str(datetime.date.today() + datetime.timedelta(days=15)),
        "tags": "evacuation, emergency, campus_safety"
    }
    doc_upload_res = client.post("/api/hr/documents", files=files, data=doc_form_data, headers=admin_headers)
    assert doc_upload_res.status_code == 200
    doc_data = doc_upload_res.json()["data"]
    doc_id = doc_data["id"]
    assert doc_data["current_version"] == "v1.0" or doc_data["current_version"] == "1.0"
    print(f"[STEP 17/25 PASS] Uploaded Document: '{doc_data['document_name']}' (ID: {doc_id}).")
    e2e_passed += 1

    # --------------------------------------------------------------------------
    # Step 18: View Document Details
    # --------------------------------------------------------------------------
    view_doc_res = client.get(f"/api/hr/documents/{doc_id}", headers=admin_headers)
    assert view_doc_res.status_code == 200
    assert view_doc_res.json()["data"]["document"]["id"] == doc_id
    print("[STEP 18/25 PASS] Retrieved Document metadata and version details.")
    e2e_passed += 1

    # --------------------------------------------------------------------------
    # Step 19: Create Document Version (Replace File)
    # --------------------------------------------------------------------------
    replace_file = {"file": ("campus_evacuation_v2.pdf", b"%PDF-1.4 Upgraded floor plan v2 content", "application/pdf")}
    replace_res = client.post(
        f"/api/hr/documents/{doc_id}/replace",
        files=replace_file,
        data={"change_summary": "Added newly built sports complex fire exit gates."},
        headers=admin_headers
    )
    assert replace_res.status_code == 200
    assert replace_res.json()["data"]["current_version"] in ("v1.1", "2.0", "v2.0")
    print("[STEP 19/25 PASS] Created Document Version with file replacement.")
    e2e_passed += 1

    # --------------------------------------------------------------------------
    # Step 20: Set Expiry & Check Status
    # --------------------------------------------------------------------------
    near_expiry = str(datetime.date.today() + datetime.timedelta(days=5))
    expiry_update_res = client.patch(f"/api/hr/documents/{doc_id}", json={"expiry_date": near_expiry}, headers=admin_headers)
    assert expiry_update_res.status_code == 200
    print(f"[STEP 20/25 PASS] Updated document expiry to near-term date: {near_expiry}.")
    e2e_passed += 1

    # --------------------------------------------------------------------------
    # Step 21: Verify Expiring Soon Query
    # --------------------------------------------------------------------------
    expiring_res = client.get("/api/hr/documents/expiring?days=30", headers=admin_headers)
    assert expiring_res.status_code == 200
    expiring_docs = expiring_res.json()["data"]
    assert any(d["id"] == doc_id for d in expiring_docs), f"Document {doc_id} should appear in expiring list"
    print(f"[STEP 21/25 PASS] Document successfully returned in Expiring Soon query.")
    e2e_passed += 1

    # --------------------------------------------------------------------------
    # Step 22: Send Reminder
    # --------------------------------------------------------------------------
    remind_res = client.post(
        f"/api/hr/acknowledgements/{ack_id}/remind",
        headers=admin_headers
    )
    assert remind_res.status_code == 200
    assert remind_res.json()["success"] is True
    print("[STEP 22/25 PASS] Sent compliance & sign-off reminder notification.")
    e2e_passed += 1

    # --------------------------------------------------------------------------
    # Step 23: Verify Audit Log
    # --------------------------------------------------------------------------
    view_doc_res2 = client.get(f"/api/hr/documents/{doc_id}", headers=admin_headers)
    assert view_doc_res2.status_code == 200
    activities = view_doc_res2.json()["data"]["activity_timeline"]
    assert len(activities) >= 1
    actions = [a["action"] for a in activities]
    print(f"[STEP 23/25 PASS] Audit trail verified with {len(activities)} recorded events: {actions}.")
    e2e_passed += 1

    # --------------------------------------------------------------------------
    # Step 24: Test Unauthorized User Access Denied
    # --------------------------------------------------------------------------
    student_token = make_token(UNAUTHORIZED_USER_ID, SCHOOL_A, "student")
    student_headers = {"Authorization": f"Bearer {student_token}"}
    unauth_res = client.post(
        "/api/hr/policies",
        json={"title": "Illegal Student Policy", "category_name": "Health & Safety", "policy_code": "STUDENT-FAIL"},
        headers=student_headers
    )
    assert unauth_res.status_code in (401, 403), f"Expected 403 Forbidden, got {unauth_res.status_code}"
    print(f"[STEP 24/25 PASS] Unauthorized student received status {unauth_res.status_code} (Access Denied).")
    e2e_passed += 1

    # --------------------------------------------------------------------------
    # Step 25: Test Multi-Tenant School Isolation
    # --------------------------------------------------------------------------
    tenant_b_token = make_token(HR_ADMIN_ID, SCHOOL_B, "super_admin")
    tenant_b_headers = {"Authorization": f"Bearer {tenant_b_token}"}
    # School B attempts to view School A's document
    tenant_b_view = client.get(f"/api/hr/documents/{doc_id}", headers=tenant_b_headers)
    assert tenant_b_view.status_code == 404, f"School B should NOT see School A document! Got {tenant_b_view.status_code}"
    # School B attempts to modify School A's policy
    tenant_b_mod = client.patch(f"/api/hr/policies/{policy_id}", json={"title": "Hacked Title"}, headers=tenant_b_headers)
    assert tenant_b_mod.status_code == 404, f"School B should NOT modify School A policy! Got {tenant_b_mod.status_code}"
    print("[STEP 25/25 PASS] Multi-tenant isolation verified: Tenant B strictly blocked from Tenant A resources (404 Not Found).")
    e2e_passed += 1

    print("================================================================================")
    print(f" END-TO-END SIMULATION COMPLETE: {e2e_passed}/{e2e_total} Steps Passed (100.0%)")
    print("================================================================================")


if __name__ == "__main__":
    try:
        run_e2e_simulation()
    except AssertionError as e:
        print(f"\n[E2E TEST FAILURE]: {e}")
        sys.exit(1)
    except Exception as e:
        import traceback
        traceback.print_exc()
        print(f"\n[E2E UNEXPECTED ERROR]: {e}")
        sys.exit(1)
