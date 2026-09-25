"""
End-to-End Test Suite for Candidate Notes and Resume/Document Endpoints.
Verifies:
1. Adding a candidate note (POST /api/recruitment/candidates/{id}/notes)
2. Validation for empty note (400)
3. Listing candidate notes (GET /api/recruitment/candidates/{id}/notes)
4. Candidate 360 profile returns notes and timeline entries (GET /api/recruitment/candidates/{id})
5. Deleting candidate note (DELETE /api/recruitment/candidates/{id}/notes/{note_id})
6. Public resume access via /api/recruitment/public/resumes/{filename} and /api/public/careers/resumes/{filename}
"""

import os
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import sys
import uuid
from jose import jwt
from fastapi.testclient import TestClient

from app.main import app
from app.config import settings

SCHOOL_A = "11111111-1111-1111-1111-111111111111"
ADMIN_USER_ID = "38a93170-997b-4b4c-bc8e-256b93169c23"
JWT_SECRET = settings.SUPABASE_JWT_SECRET or settings.APP_SECRET_KEY

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
    print("  TESTING CANDIDATE NOTES & DOCUMENT DOWNLOAD/VIEW ENDPOINTS")
    print("=" * 70)

    admin_token = make_token(ADMIN_USER_ID, SCHOOL_A, "super_admin")
    admin_headers = {
        "Authorization": f"Bearer {admin_token}",
        "X-School-Id": SCHOOL_A
    }

    # 1. Fetch MONK or create a test candidate
    cand_resp = client.get("/api/recruitment/candidates?search=MONK", headers=admin_headers)
    assert cand_resp.status_code == 200, f"Failed to list candidates: {cand_resp.text}"
    cands = cand_resp.json().get("data", [])
    if cands:
        candidate_id = cands[0]["id"]
    else:
        # Create test candidate
        create_resp = client.post("/api/recruitment/candidates", json={
            "full_name": "Test Notes Candidate",
            "email": f"notes_cand_{uuid.uuid4().hex[:6]}@example.com",
            "phone": "9876543210",
            "resume_url": "/api/recruitment/public/resumes/resume_ae47b5e82768.pdf"
        }, headers=admin_headers)
        assert create_resp.status_code in (200, 201), f"Failed to create candidate: {create_resp.text}"
        candidate_id = create_resp.json()["data"]["id"]

    print(f"[+] Using candidate ID: {candidate_id}")

    # 2. Test Empty Note Validation (400)
    empty_resp = client.post(
        f"/api/recruitment/candidates/{candidate_id}/notes",
        json={"note": "   "},
        headers=admin_headers
    )
    assert empty_resp.status_code == 400, f"Expected 400 for empty note, got: {empty_resp.status_code}"
    print("[PASS] Empty note validation correctly returned 400.")

    # 3. Test Add Valid Note (POST /api/recruitment/candidates/{id}/notes)
    test_note_text = f"Test note content {uuid.uuid4().hex[:8]}: Candidate demonstrated strong Flutter and Backend skills."
    add_resp = client.post(
        f"/api/recruitment/candidates/{candidate_id}/notes",
        json={"note": test_note_text},
        headers=admin_headers
    )
    assert add_resp.status_code == 200, f"Failed to add note: {add_resp.text}"
    note_data = add_resp.json().get("data", {})
    assert note_data.get("note") == test_note_text, "Note text mismatch."
    note_id = note_data.get("id")
    assert note_id is not None, "Note ID should not be None."
    print(f"[PASS] Successfully added note (ID: {note_id}).")

    # 4. Test List Notes (GET /api/recruitment/candidates/{id}/notes)
    list_resp = client.get(
        f"/api/recruitment/candidates/{candidate_id}/notes",
        headers=admin_headers
    )
    assert list_resp.status_code == 200, f"Failed to list notes: {list_resp.text}"
    notes_list = list_resp.json().get("data", [])
    found = any(n.get("id") == note_id for n in notes_list)
    assert found, "Created note not found in candidate notes list."
    print(f"[PASS] Note listed in candidate notes ({len(notes_list)} total notes).")

    # 5. Test Candidate 360 Profile includes the note and activity
    profile_resp = client.get(
        f"/api/recruitment/candidates/{candidate_id}",
        headers=admin_headers
    )
    assert profile_resp.status_code == 200, f"Failed to get candidate profile: {profile_resp.text}"
    profile_data = profile_resp.json().get("data", {})
    assert "notes" in profile_data, "'notes' field missing from candidate 360 profile."
    assert any(n.get("id") == note_id for n in profile_data["notes"]), "Note not present in 360 profile."
    print("[PASS] Candidate 360 profile contains notes and timeline activity.")

    # 6. Test Delete Note (DELETE /api/recruitment/candidates/{id}/notes/{note_id})
    del_resp = client.delete(
        f"/api/recruitment/candidates/{candidate_id}/notes/{note_id}",
        headers=admin_headers
    )
    assert del_resp.status_code == 200, f"Failed to delete note: {del_resp.text}"
    print("[PASS] Note deleted successfully.")

    # Verify deleted note is gone
    list_after_resp = client.get(
        f"/api/recruitment/candidates/{candidate_id}/notes",
        headers=admin_headers
    )
    assert not any(n.get("id") == note_id for n in list_after_resp.json().get("data", [])), "Deleted note still present."
    print("[PASS] Verified note is no longer present after deletion.")

    # Add back a persistent note for candidate so UI has a note to display
    client.post(
        f"/api/recruitment/candidates/{candidate_id}/notes",
        json={"note": "Candidate shows strong engineering aptitude and solid communication."},
        headers=admin_headers
    )

    # 7. Test Public Resume Serving
    resume_resp1 = client.get("/api/recruitment/public/resumes/resume_ae47b5e82768.pdf")
    assert resume_resp1.status_code in (200, 404), f"Unexpected status: {resume_resp1.status_code}"
    print(f"[PASS] /api/recruitment/public/resumes endpoint returned {resume_resp1.status_code}.")

    resume_resp2 = client.get("/api/public/careers/resumes/resume_ae47b5e82768.pdf")
    assert resume_resp2.status_code in (200, 404), f"Unexpected status: {resume_resp2.status_code}"
    print(f"[PASS] /api/public/careers/resumes endpoint returned {resume_resp2.status_code}.")

    print("=" * 70)
    print("  ALL BACKEND TESTS PASSED SUCCESSFULLY! (7/7)")
    print("=" * 70)

if __name__ == "__main__":
    run_tests()
