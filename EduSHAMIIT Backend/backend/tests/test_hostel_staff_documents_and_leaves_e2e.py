import pytest
import httpx
import uuid
import datetime

from jose import jwt

BASE_URL = "http://127.0.0.1:8082/api"
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


@pytest.mark.asyncio
async def test_hostel_staff_documents_and_leaves_e2e():
    token = create_test_token(school_id=DEFAULT_SCHOOL_ID)
    headers = {"Authorization": f"Bearer {token}", "X-School-ID": DEFAULT_SCHOOL_ID}

    async with httpx.AsyncClient(timeout=15.0) as client:
        # 1. Fetch staff roster to get Deepak Verma
        roster_res = await client.get(f"{BASE_URL}/hostel/staff?page=1&page_size=10", headers=headers)
        assert roster_res.status_code == 200
        roster = roster_res.json().get("data", [])
        assert len(roster) > 0
        deepak = next((s for s in roster if "deepak" in s.get("name", "").lower()), roster[0])
        staff_id = deepak.get("assignment_id")

        # 2. Get Staff 360 Detail
        detail_res = await client.get(f"{BASE_URL}/hostel/staff/{staff_id}", headers=headers)
        assert detail_res.status_code == 200
        detail = detail_res.json().get("data", {})
        assert "documents" in detail
        assert "leaves" in detail
        assert isinstance(detail["documents"], list)
        assert isinstance(detail["leaves"], list)
        assert len(detail["documents"]) >= 4

        # 3. Upload a new compliance document
        upload_payload = {
            "document_name": "Warden Night Safety Certification",
            "document_type": "SAFETY_UNDERTAKING",
            "file_url": "https://documents.edushamiit.edu/staff/night_safety.pdf",
            "file_size_bytes": 524288,
            "mime_type": "application/pdf",
            "verification_status": "PENDING",
            "notes": "Submitted for annual campus safety audit"
        }
        up_res = await client.post(f"{BASE_URL}/hostel/staff/{staff_id}/documents", json=upload_payload, headers=headers)
        assert up_res.status_code == 200
        up_data = up_res.json()
        assert up_data.get("success") is True
        doc_id = up_data.get("data", {}).get("id")
        assert doc_id is not None

        # 4. Verify document endpoint
        verify_payload = {
            "verification_status": "VERIFIED",
            "notes": "Verified by Chief Campus Proctor"
        }
        ver_res = await client.patch(f"{BASE_URL}/hostel/staff/documents/{doc_id}/verify", json=verify_payload, headers=headers)
        assert ver_res.status_code == 200
        assert ver_res.json().get("success") is True

        # 5. Fetch documents list
        docs_res = await client.get(f"{BASE_URL}/hostel/staff/{staff_id}/documents", headers=headers)
        assert docs_res.status_code == 200
        docs_list = docs_res.json().get("data", [])
        verified_doc = next((d for d in docs_list if d["id"] == doc_id), None)
        assert verified_doc is not None
        assert verified_doc["verification_status"] == "VERIFIED"

        # 6. Delete document
        del_res = await client.delete(f"{BASE_URL}/hostel/staff/documents/{doc_id}", headers=headers)
        assert del_res.status_code == 200
        assert del_res.json().get("success") is True

        # 7. Record Staff Leave
        leave_payload = {
            "leave_type": "Casual Leave",
            "start_date": datetime.date.today().isoformat(),
            "end_date": (datetime.date.today() + datetime.timedelta(days=2)).isoformat(),
            "reason": "Personal family engagement with pre-approved backup coverage",
            "substitute_staff_name": "Rajesh Sharma (Backup Warden)",
            "emergency_contact": "+91 98765 43210"
        }
        leave_res = await client.post(f"{BASE_URL}/hostel/staff/{staff_id}/leaves", json=leave_payload, headers=headers)
        assert leave_res.status_code == 200
        assert leave_res.json().get("success") is True

        # 8. Fetch Leaves List
        leaves_res = await client.get(f"{BASE_URL}/hostel/staff/{staff_id}/leaves", headers=headers)
        assert leaves_res.status_code == 200
        leaves_list = leaves_res.json().get("data", [])
        assert len(leaves_list) > 0

        # 9. Return Staff to Duty
        return_res = await client.post(f"{BASE_URL}/hostel/staff/{staff_id}/return-duty", headers=headers)
        assert return_res.status_code == 200
        assert return_res.json().get("success") is True
