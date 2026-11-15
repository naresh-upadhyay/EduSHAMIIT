import sys
import json
import httpx
import pytest
from jose import jwt

BASE_URL = "http://127.0.0.1:8082/api"
DEFAULT_SCHOOL_ID = "11111111-1111-1111-1111-111111111111"
ADMIN_USER_ID = "5198c4b0-f1cb-45db-9649-41688d0438ba"
JWT_SECRET = "super-secret-jwt-token-with-at-least-32-characters-long"

def create_test_token(school_id: str, role: str = "super_admin", user_id: str = None) -> str:
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
async def test_hostel_students_kpis():
    token = create_test_token(school_id=DEFAULT_SCHOOL_ID)
    headers = {"Authorization": f"Bearer {token}", "X-School-ID": DEFAULT_SCHOOL_ID}
    async with httpx.AsyncClient(timeout=15.0) as client:
        res = await client.get(f"{BASE_URL}/hostel/students/kpis", headers=headers)
        assert res.status_code == 200
        data = res.json()
        assert data.get("success") is True
        kpis = data.get("data", {})
        assert kpis.get("total_students", 0) > 0
        assert "boys_count" in kpis
        assert "girls_count" in kpis

@pytest.mark.asyncio
async def test_hostel_students_roster_and_search():
    token = create_test_token(school_id=DEFAULT_SCHOOL_ID)
    headers = {"Authorization": f"Bearer {token}", "X-School-ID": DEFAULT_SCHOOL_ID}
    async with httpx.AsyncClient(timeout=15.0) as client:
        # 1. Roster
        res = await client.get(f"{BASE_URL}/hostel/students?page=1&page_size=10", headers=headers)
        assert res.status_code == 200
        data = res.json()
        assert data.get("success") is True
        roster = data.get("data", [])
        assert len(roster) > 0

        # 2. Search
        res_search = await client.get(f"{BASE_URL}/hostel/students?search=Rahul", headers=headers)
        assert res_search.status_code == 200
        search_data = res_search.json().get("data", [])
        assert len(search_data) > 0
        assert "rahul" in search_data[0].get("student_name", "").lower()

@pytest.mark.asyncio
async def test_hostel_student_360_detail():
    token = create_test_token(school_id=DEFAULT_SCHOOL_ID)
    headers = {"Authorization": f"Bearer {token}", "X-School-ID": DEFAULT_SCHOOL_ID}
    async with httpx.AsyncClient(timeout=15.0) as client:
        res = await client.get(f"{BASE_URL}/hostel/students?search=Rahul", headers=headers)
        roster = res.json().get("data", [])
        assert len(roster) > 0
        adm_id = roster[0].get("admission_id")

        detail_res = await client.get(f"{BASE_URL}/hostel/students/{adm_id}", headers=headers)
        assert detail_res.status_code == 200
        detail = detail_res.json().get("data", {})
        assert detail.get("student_name") == "Rahul Sharma"
        assert "room_and_bed" in detail
        assert "fee_plan" in detail
        assert "activities" in detail

@pytest.mark.asyncio
async def test_hostel_eligible_students():
    token = create_test_token(school_id=DEFAULT_SCHOOL_ID)
    headers = {"Authorization": f"Bearer {token}", "X-School-ID": DEFAULT_SCHOOL_ID}
    async with httpx.AsyncClient(timeout=15.0) as client:
        res = await client.get(f"{BASE_URL}/hostel/eligible-students?limit=5", headers=headers)
        assert res.status_code == 200
        candidates = res.json().get("data", [])
        assert len(candidates) > 0

@pytest.mark.asyncio
async def test_hostel_student_documents_and_leave_dynamic():
    token = create_test_token(school_id=DEFAULT_SCHOOL_ID)
    headers = {"Authorization": f"Bearer {token}", "X-School-ID": DEFAULT_SCHOOL_ID}
    async with httpx.AsyncClient(timeout=15.0) as client:
        # Find a student
        res = await client.get(f"{BASE_URL}/hostel/students?page=1&page_size=5", headers=headers)
        roster = res.json().get("data", [])
        assert len(roster) > 0
        student_id = roster[0]["student_id"]
        adm_id = roster[0]["admission_id"]

        # 1. Check student detail includes dynamic documents and leaves
        detail_res = await client.get(f"{BASE_URL}/hostel/students/{adm_id}", headers=headers)
        assert detail_res.status_code == 200
        detail = detail_res.json().get("data", {})
        assert "documents" in detail
        assert "leaves" in detail
        assert isinstance(detail["documents"], list)
        assert isinstance(detail["leaves"], list)

        # 2. Upload a new document
        upload_payload = {
            "document_name": "E2E Test Guardian Consent",
            "document_type": "GUARDIAN_CONSENT",
            "file_url": "https://documents.edushamiit.edu/test.pdf",
            "file_size_bytes": 102400,
            "mime_type": "application/pdf",
            "admission_id": adm_id
        }
        up_res = await client.post(f"{BASE_URL}/hostel/students/{student_id}/documents", json=upload_payload, headers=headers)
        assert up_res.status_code == 200
        up_data = up_res.json()
        assert up_data.get("success") is True
        doc_id = up_data.get("data", {}).get("id") or up_data.get("id")
        assert doc_id is not None

        # 3. Fetch documents
        docs_res = await client.get(f"{BASE_URL}/hostel/students/{student_id}/documents", headers=headers)
        assert docs_res.status_code == 200
        docs_list = docs_res.json().get("data", [])
        assert any(d["id"] == doc_id for d in docs_list)

        # 4. Delete uploaded document
        del_res = await client.delete(f"{BASE_URL}/hostel/students/documents/{doc_id}", headers=headers)
        assert del_res.status_code == 200
        assert del_res.json().get("success") is True

        # 5. Check gate passes endpoint
        gp_res = await client.get(f"{BASE_URL}/hostel/leave-outing/gate-passes?academic_year=2026 - 2027", headers=headers)
        assert gp_res.status_code == 200
        gp_data = gp_res.json().get("data", {})
        assert "items" in gp_data
        assert gp_data.get("total", 0) > 0

        # 6. Check leave outing requests and KPIs
        kpi_res = await client.get(f"{BASE_URL}/hostel/leave-outing/kpis?academic_year=2026 - 2027", headers=headers)
        assert kpi_res.status_code == 200
        assert kpi_res.json().get("success") is True

        req_res = await client.get(f"{BASE_URL}/hostel/leave-outing?academic_year=2026 - 2027&page=1&page_size=10", headers=headers)
        assert req_res.status_code == 200
        assert len(req_res.json().get("data", [])) > 0


@pytest.mark.asyncio
async def test_hostel_student_room_transfer():
    token = create_test_token(school_id=DEFAULT_SCHOOL_ID)
    headers = {"Authorization": f"Bearer {token}", "X-School-ID": DEFAULT_SCHOOL_ID}
    async with httpx.AsyncClient(timeout=15.0) as client:
        # 1. Fetch active students
        st_res = await client.get(f"{BASE_URL}/hostel/students?page=1&page_size=5", headers=headers)
        roster = st_res.json().get("data", [])
        assert len(roster) > 0
        student = roster[0]
        cur_room = student.get("room_number")
        building_id = student.get("hostel_id")

        # 2. Fetch rooms with vacant beds
        rooms_res = await client.get(f"{BASE_URL}/hostel/rooms?building_id={building_id}&page_size=50", headers=headers)
        rooms = rooms_res.json().get("data", [])
        candidate_rooms = [
            r for r in rooms 
            if ((r.get("available_beds") or 0) > 0 or ((r.get("capacity") or 0) - (r.get("occupied") or 0)) > 0) 
            and r.get("room_number") != cur_room
        ]
        if not candidate_rooms:
            all_r_res = await client.get(f"{BASE_URL}/hostel/rooms?page_size=50", headers=headers)
            candidate_rooms = [
                r for r in all_r_res.json().get("data", []) 
                if ((r.get("available_beds") or 0) > 0 or ((r.get("capacity") or 0) - (r.get("occupied") or 0)) > 0) 
                and r.get("room_number") != cur_room
            ]
        
        assert len(candidate_rooms) > 0
        target_room = candidate_rooms[0]

        # 3. Perform room transfer
        payload = {
            "admission_id": student.get("admission_id"),
            "student_id": student.get("student_id"),
            "target_room_id": target_room.get("id"),
            "target_building_id": target_room.get("building_id"),
            "target_bed_number": "1",
            "reason": "E2E Room Transfer Verification Test"
        }
        transfer_res = await client.post(f"{BASE_URL}/hostel/students/transfer", json=payload, headers=headers)
        assert transfer_res.status_code == 200
        data = transfer_res.json()
        assert data.get("success") is True


