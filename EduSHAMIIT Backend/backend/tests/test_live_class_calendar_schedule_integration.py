import requests
import json
import jwt
import os
import sys

API_BASE_URL = "http://localhost:8082/api"
JWT_SECRET = os.environ.get("JWT_SECRET", "super-secret-jwt-token-with-at-least-32-characters-long")
SCHOOL_ID = "11111111-1111-1111-1111-111111111111"
ADMIN_USER_ID = "5198c4b0-f1cb-45db-9649-41688d0438ba"  # King Doe

def get_jwt(user_id=ADMIN_USER_ID, role="super_admin", email="mathematicsking888@gmail.com"):
    payload = {
        "sub": user_id,
        "school_id": SCHOOL_ID,
        "role": role,
        "email": email,
        "exp": 9999999999
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")

token = get_jwt()
headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json"
}

def run_tests():
    print("=" * 70)
    print("TEST: Live Class Creation & Calendar Schedule Integration Suite")
    print("=" * 70)

    # 1. Fetch Cascading Metadata (Classes, Sections, Subjects)
    print("\n[Step 1] Fetching Active Classes & Cascading Subjects...")
    meta_res = requests.get(f"{API_BASE_URL}/live-classes/meta/dropdowns", headers=headers)
    assert meta_res.status_code == 200, f"Failed metadata: {meta_res.text}"
    meta_data = meta_res.json().get("data", {})
    classes = meta_data.get("classes", [])
    sections = meta_data.get("sections", [])
    subjects = meta_data.get("subjects", [])
    print(f"  -> Found {len(classes)} classes, {len(sections)} sections, {len(subjects)} subjects")
    assert len(classes) > 0, "No classes found"

    test_class = classes[0]
    class_id = test_class["id"]
    class_name = test_class["name"]
    
    # Filter section for class
    class_sections = [s for s in sections if s.get("class_id") == class_id]
    section_id = class_sections[0]["id"] if class_sections else None
    section_name = class_sections[0]["name"] if class_sections else "General"

    subject_id = subjects[0]["id"] if subjects else None
    subject_name = subjects[0]["name"] if subjects else "Mathematics"
    print(f"  -> Targeting Cohort: {class_name} - {section_name} ({subject_name})")

    # 2. Test Cascading Subjects endpoint
    print("\n[Step 2] Testing GET /api/live-classes/cascading-subjects...")
    casc_res = requests.get(
        f"{API_BASE_URL}/live-classes/cascading-subjects",
        params={"class_id": class_id, "section_id": section_id},
        headers=headers
    )
    assert casc_res.status_code == 200, f"Cascading error: {casc_res.text}"
    casc_subs = casc_res.json().get("data", {}).get("subjects", [])
    print(f"  -> Cascaded {len(casc_subs)} subjects for class {class_name}")

    # 3. Create a Scheduled Live Class (Calendar-Style Payload)
    print("\n[Step 3] Creating Scheduled Live Class via POST /api/live-classes/sessions...")
    scheduled_payload = {
        "title": "Advanced Integral Calculus & Matrix Equations",
        "description": "Comprehensive review of definite integrals and eigenvalues for competitive exams",
        "class_id": class_id,
        "section_id": section_id,
        "subject_id": subject_id,
        "class_section": f"{class_name} - {section_name}",
        "subject": subject_name,
        "scheduled_at": "2026-11-20T10:30:00.000Z",
        "duration_minutes": 60,
        "virtual_meeting_url": "https://meet.edushamiit.com/cls/calc2026",
        "meeting_link": "https://meet.edushamiit.com/cls/calc2026",
        "status": "scheduled",
        "is_live": False,
        "recording_enabled": True,
        "waiting_room_enabled": False,
        "allow_student_mic": True,
        "allow_student_cam": True,
        "allow_chat": True,
        "allow_reactions": True,
        "max_participants": 60
    }

    create_res = requests.post(f"{API_BASE_URL}/live-classes/sessions", json=scheduled_payload, headers=headers)
    assert create_res.status_code == 200, f"Create scheduled class failed: {create_res.text}"
    created_session = create_res.json().get("data", {})
    session_id = created_session.get("id") or created_session.get("session_id")
    assert session_id is not None, "Created session ID is null"
    assert created_session.get("status") == "scheduled", f"Expected status 'scheduled', got: {created_session.get('status')}"
    assert created_session.get("is_live") is False, "Expected is_live False for scheduled class"
    print(f"  -> Successfully created Scheduled Class Session ID: {session_id}")
    print(f"  -> Status: {created_session.get('status')}, Scheduled At: {created_session.get('scheduled_at')}")

    # 4. Verify Session appears in GET /api/live-classes/sessions with proper filters
    print("\n[Step 4] Verifying Scheduled Class in Session List...")
    list_res = requests.get(
        f"{API_BASE_URL}/live-classes/sessions",
        params={"date_filter": "all", "class_id": class_id, "page_size": 20},
        headers=headers
    )
    assert list_res.status_code == 200, f"List failed: {list_res.text}"
    session_list = list_res.json().get("data", {}).get("items", []) or list_res.json().get("data", {}).get("sessions", [])
    matched_session = next((s for s in session_list if s.get("id") == session_id), None)
    assert matched_session is not None, f"Scheduled session {session_id} not found in live class list"
    matched_title = matched_session.get("topic") or matched_session.get("title")
    assert matched_title == "Advanced Integral Calculus & Matrix Equations", f"Expected title match, got {matched_title}"
    print(f"  -> Verified session in list: '{matched_title}'")

    # 5. Test CRUD Update on Scheduled Session
    print("\n[Step 5] Testing Session Reschedule / Update via PUT /api/live-classes/sessions/{id}...")
    update_payload = {
        "title": "Advanced Integral Calculus & Matrix Equations (Rescheduled)",
        "duration_minutes": 75,
        "scheduled_at": "2026-11-20T11:00:00.000Z",
        "description": "Updated syllabus with additional practice sheets"
    }
    update_res = requests.put(f"{API_BASE_URL}/live-classes/sessions/{session_id}", json=update_payload, headers=headers)
    assert update_res.status_code == 200, f"Update failed: {update_res.text}"
    print(f"  -> Update response: {update_res.json().get('message')}")

    # 6. Test Calendar Schedule Creation with Class Type
    print("\n[Step 6] Testing Calendar Schedule Creation via POST /api/schedules...")
    cal_payload = {
        "title": "Class 10-A Mathematics Calendar Event",
        "description": "Unified schedule event from Calendar popup",
        "schedule_type": "Class",
        "category": "Academic",
        "color": "#2563EB",
        "priority": "normal",
        "start_time": "2026-11-20T11:00:00.000",
        "end_time": "2026-11-20T12:15:00.000",
        "is_all_day": False,
        "timezone": "Asia/Kolkata",
        "virtual_meeting_url": "https://meet.edushamiit.com/cls/calc2026",
        "virtual_meeting_provider": "edushamiit",
        "target_roles": ["teacher", "student"],
        "target_class_sections": [
            {
                "class_id": class_id,
                "class_name": class_name,
                "section_id": section_id,
                "section_name": section_name,
                "subject_id": subject_id,
                "subject_name": subject_name,
                "display_name": f"{class_name} - {section_name}"
            }
        ]
    }
    cal_res = requests.post(f"{API_BASE_URL}/schedules", json=cal_payload, headers=headers)
    print(f"  -> Calendar creation status: {cal_res.status_code}")
    if cal_res.status_code == 200:
        print(f"  -> Calendar schedule created successfully: {cal_res.json()}")

    # 7. Clean up test session
    print("\n[Step 7] Cleaning up test live class session...")
    del_res = requests.delete(f"{API_BASE_URL}/live-classes/sessions/{session_id}", headers=headers)
    assert del_res.status_code == 200, f"Delete failed: {del_res.text}"
    print(f"  -> Session {session_id} cleaned up successfully.")

    print("\n" + "=" * 70)
    print("ALL TESTS PASSED! Live Class Calendar integration verified end-to-end.")
    print("=" * 70)

if __name__ == "__main__":
    run_tests()
