import asyncio
import json
import hmac
import hashlib
import base64
import time
import httpx

BASE_URL = "http://localhost:8082/api/v1/payment-management"
JWT_SECRET = "super-secret-jwt-token-with-at-least-32-characters-long"
SCHOOL_ID = "11111111-1111-1111-1111-111111111111"

def b64url_enc(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode('utf-8').rstrip('=')

def create_jwt_token(payload: dict, secret: str) -> str:
    header = {"alg": "HS256", "typ": "JWT"}
    segments = [
        b64url_enc(json.dumps(header, separators=(',', ':')).encode('utf-8')),
        b64url_enc(json.dumps(payload, separators=(',', ':')).encode('utf-8'))
    ]
    signing_input = ".".join(segments).encode('utf-8')
    sig = hmac.new(secret.encode('utf-8'), signing_input, hashlib.sha256).digest()
    segments.append(b64url_enc(sig))
    return ".".join(segments)

async def run_tests():
    print("=== STARTING CLASS & SECTION FEE STRUCTURE ENGINE E2E TEST ===")
    token_payload = {
        "sub": "00000000-0000-0000-0000-000000000001",
        "id": "00000000-0000-0000-0000-000000000001",
        "school_id": SCHOOL_ID,
        "role": "Super Admin",
        "full_name": "King Doe",
        "email": "king@edushamiit.com",
        "exp": int(time.time()) + 3600
    }
    token = create_jwt_token(token_payload, JWT_SECRET)
    headers = {"Authorization": f"Bearer {token}"}

    async with httpx.AsyncClient(timeout=30.0) as client:
        # 1. Test listing fee structures with summary
        print("\n1. Testing GET /student-fees/fee-structures with cohort summary...")
        res = await client.get(f"{BASE_URL}/student-fees/fee-structures", headers=headers)
        assert res.status_code == 200, f"Failed: {res.status_code} - {res.text}"
        data = res.json()
        assert data.get("success") is True, "Expected success: true"
        structures = data.get("structures", [])
        summary = data.get("summary", {})
        print(f"Retrieved {len(structures)} fee heads. Cohort summary: {json.dumps(summary, indent=2)}")
        assert "total_annual_liability" in summary, "Expected total_annual_liability in summary"

        # 2. Test creating dedicated fee structure head with Class, Section, Frequency, and Due Fine rules
        print("\n2. Testing POST /student-fees/fee-structures with dedicated cohort parameters...")
        head_payload = {
            "fee_name": "E2E Advanced Robotics & AI Practical",
            "fee_type": "Science & Computer Lab Fee",
            "class_grade": "Class 10",
            "section_name": "10-B",
            "billing_cycle": "Quarterly",
            "frequency_type": "Quarterly",
            "amount": 3200.0,
            "due_day_of_cycle": 10,
            "grace_period_days": 5,
            "late_fine_amount": 100.0,
            "late_fine_type": "FLAT",
            "is_mandatory": True,
            "is_refundable": False,
            "description": "Robotics hardware kit and microcontrollers for Class 10-B",
            "academic_year": "2026 - 2027"
        }
        create_res = await client.post(f"{BASE_URL}/student-fees/fee-structures", json=head_payload, headers=headers)
        assert create_res.status_code == 201, f"Failed to create: {create_res.status_code} - {create_res.text}"
        create_data = create_res.json()
        assert create_data.get("success") is True, "Create returned success: false"
        created_id = create_data.get("structure_id")
        print(f"Created fee structure head ID: {created_id}")

        # 3. Test filtering by cohort Class 10 & Section 10-B
        print("\n3. Testing GET /student-fees/fee-structures?class_grade=Class 10&section_name=10-B...")
        filter_res = await client.get(
            f"{BASE_URL}/student-fees/fee-structures?class_grade=Class 10&section_name=10-B",
            headers=headers
        )
        assert filter_res.status_code == 200
        filtered_heads = filter_res.json().get("structures", [])
        matching_created = next((h for h in filtered_heads if h.get("id") == created_id), None)
        assert matching_created is not None, "Created fee head was not found in filtered results"
        assert matching_created.get("section_name") == "10-B"
        assert matching_created.get("frequency_type") == "Quarterly"
        assert matching_created.get("late_fine_amount") == 100.0
        assert matching_created.get("annual_liability") == 12800.0, f"Expected 3200*4=12800, got {matching_created.get('annual_liability')}"
        print(f"Verified created head: {matching_created['fee_name']} - Annual Liability: ₹{matching_created['annual_liability']}")

        # 4. Test 1-Click Fee Structure Cloning
        print("\n4. Testing POST /student-fees/fee-structures/clone...")
        clone_payload = {
            "source_class": "Class 10",
            "source_section": "All Sections",
            "target_class": "Class 8",
            "target_section": "8-A",
            "markup_percent": 5.0
        }
        clone_res = await client.post(f"{BASE_URL}/student-fees/fee-structures/clone", json=clone_payload, headers=headers)
        assert clone_res.status_code == 201, f"Clone failed: {clone_res.status_code} - {clone_res.text}"
        clone_data = clone_res.json()
        print(f"Clone result: {clone_data.get('message')}, Cloned Count: {clone_data.get('cloned_count')}")
        assert clone_data.get("success") is True

        # 5. Test Student-Applicable Fee Structure Resolution
        print("\n5. Testing GET /student-fees/students/{student_id}/applicable-fee-structure...")
        roster_res = await client.get(f"{BASE_URL}/student-fees/students?page_size=5", headers=headers)
        assert roster_res.status_code == 200, f"Roster failed: {roster_res.status_code} - {roster_res.text}"
        students = roster_res.json().get("students", [])
        assert len(students) > 0, "No students found in roster to test"
        test_student_id = students[0].get("id") or students[0].get("student_id")
        test_student_name = students[0].get("name") or students[0].get("student_name")

        app_res = await client.get(f"{BASE_URL}/student-fees/students/{test_student_id}/applicable-fee-structure", headers=headers)
        assert app_res.status_code == 200, f"Applicable fee struct failed: {app_res.status_code} - {app_res.text}"
        app_data = app_res.json()
        assert app_data.get("success") is True
        print(f"Student: {test_student_name} (ID: {test_student_id})")
        print(f"Applicable Fee Heads Count: {len(app_data.get('applicable_heads', []))}")
        print(f"Totals: {json.dumps(app_data.get('totals', {}), indent=2)}")

        # 6. Cleanup test fee structure head
        print("\n6. Cleaning up test fee head...")
        del_res = await client.delete(f"{BASE_URL}/student-fees/fee-structures/{created_id}", headers=headers)
        assert del_res.status_code == 200
        print("Cleanup successful.")

    print("\n=== ALL CLASS & SECTION FEE STRUCTURE ENGINE TESTS PASSED (100%) ===")

if __name__ == "__main__":
    asyncio.run(run_tests())
