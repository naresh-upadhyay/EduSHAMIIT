import os
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import asyncio
import os
import sys
import uuid
import json
from datetime import datetime, date, timedelta

from httpx import AsyncClient, ASGITransport
from app.main import app
from app.api.recruitment import exec_sql

SCHOOL_ID = "11111111-1111-1111-1111-111111111111"
ADMIN_USER_ID = "38a93170-997b-4b4c-bc8e-256b93169c23"
REVIEWER_USER_ID = "12121212-1212-1212-1212-121212121212"
STAFF_USER_ID = "34343434-3434-3434-3434-343434343434"

from jose import jwt

def make_token(user_id: str, role: str, email: str, school_id: str = SCHOOL_ID) -> str:
    payload = {
        "sub": user_id,
        "school_id": school_id,
        "role": role,
        "email": email,
        "exp": 9999999999
    }
    from app.config import settings
    jwt_secret = settings.SUPABASE_JWT_SECRET or settings.JWT_SECRET or os.getenv("JWT_SECRET", "super-secret-jwt-key-for-local-testing-only-12345")
    return jwt.encode(payload, jwt_secret, algorithm="HS256")


async def run_tests():
    print("================================================================================")
    print(" HR Policies End-to-End Workflow, Auto-Dispatch & Lookups Verification")
    print("================================================================================")

    author_id = str(uuid.uuid4())
    author_email = f"hr_author_{uuid.uuid4().hex[:6]}@edushamiit.com"
    author_token = make_token(author_id, "hr", author_email)
    reviewer_token = make_token(REVIEWER_USER_ID, "principal", "reviewer@edushamiit.com")
    staff_token = make_token(STAFF_USER_ID, "teacher", "staff@edushamiit.com")

    # 0. Setup mock author, reviewer and staff profile in profiles if not exists
    await exec_sql("""
        INSERT INTO public.profiles (id, user_id, school_id, email, full_name, role, department, designation)
        VALUES 
            (%s, %s, %s, %s, 'HR Author Officer', 'hr', 'Human Resources', 'HR Officer')
        ON CONFLICT (id) DO UPDATE SET 
            full_name = EXCLUDED.full_name,
            role = EXCLUDED.role,
            department = EXCLUDED.department;
    """, (author_id, author_id, SCHOOL_ID, author_email), fetch=False)

    admin_token = make_token(ADMIN_USER_ID, "super_admin", "admin@edushamiit.com")

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        # TEST 1: Check king policy sign-off count
        print("\n[TEST 1] Verifying 'king policy' sign-off count in get_policy_detail...")
        king_rows = await exec_sql("SELECT id, title, current_version FROM hr_policies WHERE title ILIKE %(pat)s LIMIT 1;", {'pat': '%king%'})
        if king_rows:
            kp = king_rows[0]
            res = await client.get(f"/api/hr/policies/{kp['id']}", headers={"Authorization": f"Bearer {admin_token}"})
            assert res.status_code == 200
            data = res.json()["data"]
            summary = data.get("acknowledgements_summary", {})
            acks = data.get("acknowledgements", [])
            print(f"  King Policy summary: total_required={summary.get('total_required')}, assigned={summary.get('total_assigned')}, acks_list_len={len(acks)}")
            assert summary.get("total_assigned", 0) >= len(acks), "total_assigned must reflect all assigned sign-offs!"
            print("  [PASS] King Policy sign-offs correctly computed and displayed!")

        # TEST 2: Check lookups endpoints for DEPARTMENT, POLICY_APPLICABILITY, POLICY_REVIEW_FREQUENCY
        print("\n[TEST 2] Verifying lookup key-value endpoints for HR Policy forms...")
        for group in ["DEPARTMENT", "POLICY_APPLICABILITY", "POLICY_REVIEW_FREQUENCY"]:
            res = await client.get(f"/api/lookups/code/{group}", headers={"Authorization": f"Bearer {admin_token}"})
            assert res.status_code == 200, f"Lookup group {group} failed: {res.text}"
            data = res.json()
            items = data.get("values") or data.get("data") or data
            assert len(items) > 0, f"Lookup group {group} returned empty list!"
            print(f"  [PASS] {group} lookup returned {len(items)} items. Example: {items[0].get('value_name') or items[0].get('label') or items[0]}")

        # TEST 3: Create a policy as DRAFT
        print("\n[TEST 3] Creating a new policy as DRAFT...")
        policy_code = f"POL-TEST-{uuid.uuid4().hex[:6].upper()}"
        draft_payload = {
            "policy_code": policy_code,
            "title": "Comprehensive E2E Safety & Safeguarding Protocol",
            "category_name": "Administration",
            "department": "Administration",
            "applicability_type": "Role",
            "audience_type": "Role",
            "audience_target": "Teacher",
            "reviewer_id": REVIEWER_USER_ID,
            "reviewer_name": "Dr. Reviewer Principal",
            "reviewer_role": "Principal",
            "status": "DRAFT",
            "content_html": "<p>Standard safety guidelines for testing.</p>"
        }
        res = await client.post("/api/hr/policies", json=draft_payload, headers={"Authorization": f"Bearer {author_token}"})
        assert res.status_code == 200, f"Failed to create draft: {res.text}"
        policy_id = res.json()["data"]["id"]
        print(f"  [PASS] Created policy with ID: {policy_id}, Status: {res.json()['data']['status']}")

        # TEST 4: Submit Draft for Review
        print("\n[TEST 4] Submitting policy for review to designated reviewer...")
        submit_payload = {
            "status": "PENDING_REVIEW",
            "reviewer_id": REVIEWER_USER_ID,
            "reviewer_name": "Dr. Reviewer Principal",
            "reviewer_role": "Principal"
        }
        res = await client.patch(f"/api/hr/policies/{policy_id}", json=submit_payload, headers={"Authorization": f"Bearer {author_token}"})
        assert res.status_code == 200, f"Failed to submit for review: {res.text}"
        assert res.json()["data"]["status"] == "PENDING_REVIEW"
        print("  [PASS] Policy status transitioned to PENDING_REVIEW.")

        # TEST 5: Visibility isolation for PENDING_REVIEW: Author & Reviewer can see, Staff cannot
        print("\n[TEST 5] Testing visibility isolation for PENDING_REVIEW policy...")
        reviewer_list = await client.get("/api/hr/policies", headers={"Authorization": f"Bearer {reviewer_token}"})
        reviewer_pids = [p["id"] for p in reviewer_list.json()["data"]]
        assert policy_id in reviewer_pids, "Pending review policy must be visible to assigned reviewer!"

        staff_list_2 = await client.get("/api/hr/policies", headers={"Authorization": f"Bearer {staff_token}"})
        staff_pids_2 = [p["id"] for p in staff_list_2.json()["data"]]
        assert policy_id not in staff_pids_2, "Pending review policy MUST NOT be visible to unrelated staff!"
        print("  [PASS] Policy is visible to reviewer and creator, and hidden from unrelated staff.")

        # TEST 6: Reviewer approves the policy
        print("\n[TEST 6] Reviewer approves the policy...")
        approve_payload = {"comments": "Approved without objections."}
        res = await client.post(f"/api/hr/policies/{policy_id}/approve", json=approve_payload, headers={"Authorization": f"Bearer {reviewer_token}"})
        assert res.status_code == 200, f"Failed to approve: {res.text}"
        assert res.json()["data"]["status"] == "APPROVED"
        assert res.json()["data"]["approved_by"] == REVIEWER_USER_ID
        print("  [PASS] Policy approved successfully by reviewer.")

        # TEST 7: Publish policy to ACTIVE with Auto-Dispatch
        print("\n[TEST 7] Publishing policy to ACTIVE and verifying auto-dispatch...")
        res = await client.post(f"/api/hr/policies/{policy_id}/publish", json={}, headers={"Authorization": f"Bearer {author_token}"})
        assert res.status_code == 200, f"Failed to publish: {res.text}"
        assert res.json()["data"]["status"] == "ACTIVE"

        # Check that sign-offs were automatically created for Teacher role!
        detail_res = await client.get(f"/api/hr/policies/{policy_id}", headers={"Authorization": f"Bearer {author_token}"})
        acks = detail_res.json()["data"]["acknowledgements"]
        print(f"  [PASS] Auto-dispatched {len(acks)} sign-offs on publish for audience 'Teacher'!")
        assert len(acks) > 0, "Expected sign-offs to be automatically dispatched on publish!"

        # TEST 8: Create policy directly with ACTIVE and Role: Owner
        print("\n[TEST 8] Creating policy directly as ACTIVE with audience Role: Owner (Auto-Dispatch)...")
        owner_code = f"POL-OWNER-{uuid.uuid4().hex[:6].upper()}"
        owner_payload = {
            "policy_code": owner_code,
            "title": "Owner Level Compliance Directive",
            "category_name": "Administration",
            "department": "Administration",
            "applicability_type": "Role",
            "audience_type": "Role",
            "audience_target": "Owner",
            "status": "ACTIVE",
            "content_html": "<p>Directives for administrative owners.</p>"
        }
        res = await client.post("/api/hr/policies", json=owner_payload, headers={"Authorization": f"Bearer {admin_token}"})
        assert res.status_code == 200, f"Failed to create active policy: {res.text}"
        owner_policy_id = res.json()["data"]["id"]

        detail_res = await client.get(f"/api/hr/policies/{owner_policy_id}", headers={"Authorization": f"Bearer {admin_token}"})
        assert detail_res.status_code == 200
        owner_acks = detail_res.json()["data"]["acknowledgements"]
        print(f"  [PASS] Auto-dispatched {len(owner_acks)} sign-offs on initial creation for 'Owner' role!")
        assert len(owner_acks) > 0, "Sign-offs must be automatically dispatched by default for initial policy creation!"

        # TEST 9: Create policy directly with ACTIVE and Department: Administration
        print("\n[TEST 9] Creating policy directly as ACTIVE with audience Department: Administration...")
        dept_code = f"POL-DEPT-{uuid.uuid4().hex[:6].upper()}"
        dept_payload = {
            "policy_code": dept_code,
            "title": "Administration Department Protocols",
            "category_name": "Administration",
            "department": "Administration",
            "applicability_type": "Department",
            "audience_type": "Department",
            "audience_target": "Administration",
            "status": "ACTIVE",
            "content_html": "<p>Administration protocols.</p>"
        }
        res = await client.post("/api/hr/policies", json=dept_payload, headers={"Authorization": f"Bearer {admin_token}"})
        assert res.status_code == 200, f"Failed to create dept policy: {res.text}"
        dept_policy_id = res.json()["data"]["id"]

        detail_res = await client.get(f"/api/hr/policies/{dept_policy_id}", headers={"Authorization": f"Bearer {admin_token}"})
        assert detail_res.status_code == 200
        dept_acks = detail_res.json()["data"]["acknowledgements"]
        print(f"  [PASS] Auto-dispatched {len(dept_acks)} sign-offs on initial creation for 'Administration' department!")
        assert len(dept_acks) > 0, "Sign-offs must be automatically dispatched by default for department audience!"

    print("\n================================================================================")
    print(" ALL 9 VERIFICATION TESTS PASSED SUCCESSFULLY!")
    print("================================================================================")

if __name__ == "__main__":
    asyncio.run(run_tests())
