import asyncio
import os
import sys
import httpx
import json
from jose import jwt

BASE_URL = os.getenv("API_URL", "http://127.0.0.1:8082/api")
STAFF_ID = "51000001-0000-0000-0000-000000000001"
DEFAULT_SCHOOL_ID = "11111111-1111-1111-1111-111111111111"
ADMIN_USER_ID = "5198c4b0-f1cb-45db-9649-41688d0438ba"
JWT_SECRET = "super-secret-jwt-token-with-at-least-32-characters-long"

def create_test_token(school_id: str = DEFAULT_SCHOOL_ID, role: str = "super_admin", user_id: str = None) -> str:
    user_id = user_id or ADMIN_USER_ID
    payload = {
        "sub": user_id,
        "id": user_id,
        "school_id": school_id,
        "role": role,
        "exp": 9999999999
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")

async def test_staff_leaves_and_document_upload():
    token = create_test_token()
    headers = {"Authorization": f"Bearer {token}", "X-School-ID": DEFAULT_SCHOOL_ID}

    async with httpx.AsyncClient(timeout=30.0) as client:
        # 1. Fetch Staff Detail & verify monthly_leaves_taken
        print("[TEST 1] Fetching staff detail...")
        res = await client.get(f"{BASE_URL}/hostel/staff/{STAFF_ID}", headers=headers)
        assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
        data = res.json()
        assert data.get("success") is True, f"Response not successful: {data}"
        staff = data["data"]
        print(f"  Staff Name: {staff.get('full_name')}")
        print(f"  Monthly Leaves Taken: {staff.get('monthly_leaves_taken')}")
        assert staff.get("monthly_leaves_taken") == 3.0, f"Expected 3.0, got {staff.get('monthly_leaves_taken')}"
        leaves = staff.get("leaves", [])
        print(f"  Total Leaves count: {len(leaves)}")
        # Verify deduplicated leaves
        dates = [f"{l['start_date']}-{l['end_date']}" for l in leaves]
        assert len(dates) == len(set(dates)), f"Duplicate leave dates found: {dates}"
        print("  [PASS] Monthly leaves taken is 3.0 and no duplicates exist.")

        # 2. Test Overlap Prevention on Leave Recording
        print("\n[TEST 2] Testing overlapping leave rejection...")
        overlap_payload = {
            "leave_type": "Casual Leave",
            "start_date": "2026-11-03",
            "end_date": "2026-11-05",
            "reason": "Overlapping request should fail",
            "substitute_staff_name": "Backup Warden",
        }
        res_overlap = await client.post(f"{BASE_URL}/hostel/staff/{STAFF_ID}/leaves", json=overlap_payload, headers=headers)
        print(f"  Status code: {res_overlap.status_code}")
        print(f"  Response: {res_overlap.text}")
        assert res_overlap.status_code == 400, f"Expected 400, got {res_overlap.status_code}"
        assert "overlapping" in res_overlap.text.lower(), f"Expected overlap message, got: {res_overlap.text}"
        print("  [PASS] Overlapping leave properly rejected with 400 error.")

        # 3. Test Real Document Upload (Multipart)
        print("\n[TEST 3] Testing real multipart document upload...")
        dummy_pdf_bytes = b"%PDF-1.4\n1 0 obj\n<< /Title (Hostel Compliance Certificate) >>\nendobj\ntrailer\n<< >>\n%%EOF"
        files = {
            "file": ("safety_compliance_cert.pdf", dummy_pdf_bytes, "application/pdf")
        }
        form_data = {
            "document_name": "Hostel Safety Compliance Certificate",
            "document_type": "SAFETY_UNDERTAKING",
            "verification_status": "VERIFIED",
            "notes": "E2E Verified via Real File Upload"
        }
        res_upload = await client.post(
            f"{BASE_URL}/hostel/staff/{STAFF_ID}/documents/upload",
            files=files,
            data=form_data,
            headers=headers
        )
        print(f"  Status code: {res_upload.status_code}")
        print(f"  Response: {res_upload.text}")
        assert res_upload.status_code == 200, f"Expected 200, got {res_upload.status_code}: {res_upload.text}"
        upload_json = res_upload.json()
        assert upload_json.get("success") is True, f"Upload not successful: {upload_json}"
        doc_id = upload_json.get("data", {}).get("id")
        print(f"  Uploaded Doc ID: {doc_id}")
        print("  [PASS] Real multipart document uploaded successfully.")

        # 4. Verify Document appears in staff details
        print("\n[TEST 4] Verifying document in staff details...")
        res_after = await client.get(f"{BASE_URL}/hostel/staff/{STAFF_ID}", headers=headers)
        staff_after = res_after.json()["data"]
        docs = staff_after.get("documents", [])
        uploaded_doc = next((d for d in docs if d["id"] == doc_id), None)
        assert uploaded_doc is not None, f"Uploaded document {doc_id} not found in documents list"
        print(f"  Found doc: {uploaded_doc['document_name']} ({uploaded_doc['file_size_bytes']} bytes, status: {uploaded_doc['verification_status']})")
        print("  [PASS] Document verified in staff details.")

        # 5. Clean up the test document
        if doc_id:
            res_del = await client.delete(f"{BASE_URL}/hostel/staff/documents/{doc_id}", headers=headers)
            print(f"  Cleaned up test document: {res_del.status_code}")

    print("\nALL E2E STAFF LEAVE & DOCUMENT TESTS PASSED SUCCESSFULLY!")

if __name__ == "__main__":
    asyncio.run(test_staff_leaves_and_document_upload())
