import os
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.middleware.auth import get_current_user

# Mock super admin user for testing
app.dependency_overrides[get_current_user] = lambda: {
    "id": "11111111-1111-1111-1111-111111111111",
    "school_id": "11111111-1111-1111-1111-111111111111",
    "full_name": "Admin Tester",
    "role": "super_admin"
}

client = TestClient(app)

def test_join_conduct_dashboard():
    resp = client.get("/api/live-classes/dashboard/join-conduct")
    assert resp.status_code == 200
    data = resp.json()
    assert "data" in data
    d = data["data"]
    assert "kpis" in d
    assert "live_now" in d["kpis"]
    assert "todays_classes" in d["kpis"]
    assert "active_session" in d
    assert "participants" in d

def test_recordings_dashboard():
    resp = client.get("/api/live-classes/dashboard/recordings")
    assert resp.status_code == 200
    data = resp.json()
    assert "data" in data
    d = data["data"]
    assert "kpis" in d
    assert "total_recordings" in d["kpis"]
    assert "storage_used_gb" in d["kpis"]

def test_attendance_dashboard():
    resp = client.get("/api/live-classes/dashboard/attendance")
    assert resp.status_code == 200
    data = resp.json()
    assert "data" in data
    d = data["data"]
    assert "kpis" in d
    assert "total_sessions" in d["kpis"]
    assert "attendance_marked" in d["kpis"]

def test_recordings_list():
    resp = client.get("/api/live-classes/recordings?page=1&page_size=10")
    assert resp.status_code == 200
    data = resp.json()
    assert "data" in data
    assert "total_count" in data["data"]
    assert "items" in data["data"]

def test_attendance_list():
    resp = client.get("/api/live-classes/attendance?page=1&page_size=10")
    assert resp.status_code == 200
    data = resp.json()
    assert "data" in data
    assert "items" in data["data"]

def test_meta_dropdowns():
    resp = client.get("/api/live-classes/meta/dropdowns")
    assert resp.status_code == 200
    data = resp.json()
    assert "data" in data
    d = data["data"]
    assert "classes" in d
    assert "teachers" in d

def test_attendance_csv_export():
    resp = client.get("/api/live-classes/attendance/export")
    assert resp.status_code == 200
    assert "text/csv" in resp.headers["content-type"]
    assert "Roll No,Student Name,Status,Join Time,Leave Time" in resp.text

def test_create_instant_class_and_lifecycle():
    # 1. Create class
    create_payload = {
        "title": "Automated Test Instant Class",
        "class_section": "Class 10 - A",
        "subject": "Mathematics",
        "meeting_duration": 45,
        "enable_recording": True
    }
    resp = client.post("/api/live-classes/sessions/instant", json=create_payload)
    assert resp.status_code == 200
    data = resp.json()
    assert "data" in data
    session_id = data["data"]["id"]
    assert session_id is not None

    # 2. Record participant joined event
    join_event = {
        "user_id": "11111111-1111-1111-1111-111111111111",
        "event_type": "joined",
        "user_agent": "Mozilla/5.0 Test Suite",
        "ip_address": "127.0.0.1"
    }
    resp_event = client.post(f"/api/live-classes/{session_id}/event", json=join_event)
    assert resp_event.status_code == 200

    # 3. Record participant left event
    leave_event = {
        "user_id": "11111111-1111-1111-1111-111111111111",
        "event_type": "left",
        "user_agent": "Mozilla/5.0 Test Suite",
        "ip_address": "127.0.0.1"
    }
    resp_leave = client.post(f"/api/live-classes/{session_id}/event", json=leave_event)
    assert resp_leave.status_code == 200

    # 4. End class (triggers automatic stored procedure attendance calculation)
    resp_end = client.post(f"/api/live-classes/{session_id}/end")
    assert resp_end.status_code == 200


def test_my_classes_dashboard_and_listing():
    # 1. My Classes Dashboard
    resp = client.get("/api/live-classes/my-classes/dashboard?date_filter=today")
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert "kpis" in data
    assert "my_classes_today" in data["kpis"]
    assert "ongoing_live" in data["kpis"]
    assert "upcoming" in data["kpis"]
    assert "completed" in data["kpis"]
    assert "total_students" in data["kpis"]
    assert "teaching_duration_today" in data["kpis"]
    assert "today_progress" in data
    assert "teaching_summary" in data
    assert "class_trend_week" in data

    # 2. My Classes Paginated & Filtered Listing
    resp_list = client.get("/api/live-classes/my-classes?date_filter=today&page=1&page_size=5")
    assert resp_list.status_code == 200
    data_list = resp_list.json()["data"]
    assert "items" in data_list
    assert len(data_list["items"]) > 0
    first_item = data_list["items"][0]
    assert "class_section" in first_item
    assert "subject_name" in first_item
    assert "topic" in first_item
    assert "status" in first_item

    # 3. Session details for right panel
    session_id = first_item["id"]
    resp_details = client.get(f"/api/live-classes/sessions/{session_id}/details")
    assert resp_details.status_code == 200
    details = resp_details.json()["data"]
    assert details["id"] == session_id
    assert "topic" in details
    assert "class_section" in details

    # 4. Duplicate session
    resp_dup = client.post(f"/api/live-classes/sessions/{session_id}/duplicate")
    assert resp_dup.status_code == 200
    dup_data = resp_dup.json()["data"]
    assert dup_data["success"] is True
    dup_session_id = dup_data.get("new_session_id") or dup_data.get("session_id") or session_id

    # 5. Cancel the newly duplicated test session
    resp_cancel = client.post(f"/api/live-classes/sessions/{dup_session_id}/cancel", json={"reason": "Testing cancellation"})
    assert resp_cancel.status_code == 200
    assert resp_cancel.json()["data"]["success"] is True


def test_join_via_code_and_guest_join_lifecycle():
    # 1. Validate Join Code using 11A-PHY
    resp_val = client.post("/api/live-classes/join-code/validate", json={"code": "11A-PHY"})
    assert resp_val.status_code == 200
    val_data = resp_val.json()["data"]
    assert val_data["success"] is True
    assert val_data["status_code"] == "CAN_JOIN"
    assert val_data["session"]["room_code"] == "11A-PHY"
    assert "class_section" in val_data["session"]

    # 2. Public Preview
    resp_prev = client.get("/api/live-classes/join-code/11A-PHY/preview")
    assert resp_prev.status_code == 200
    prev_data = resp_prev.json()["data"]
    assert prev_data["success"] is True
    assert prev_data["session"]["title"] is not None

    # 3. Get Recent Codes
    resp_rec = client.get("/api/live-classes/recent-codes")
    assert resp_rec.status_code == 200
    rec_items = resp_rec.json()["data"]["items"]
    assert len(rec_items) > 0
    assert any(x["meeting_code"] == "11A-PHY" for x in rec_items)

    # 4. Toggle Star
    resp_star = client.post("/api/live-classes/recent-codes/toggle-star", json={"code": "11A-PHY", "is_starred": True})
    assert resp_star.status_code == 200

    # 5. Submit Guest Join Request
    guest_payload = {
        "code": "11A-PHY",
        "display_name": "Prof. Ada Lovelace",
        "email": "ada@computing.org",
        "purpose": "Guest Speaker",
        "organization": "Analytical Engines Corp",
        "options": {"is_mic_muted": False, "is_cam_off": False}
    }
    resp_guest = client.post("/api/live-classes/guest/request", json=guest_payload)
    assert resp_guest.status_code == 200
    g_res = resp_guest.json()["data"]
    assert g_res["success"] is True
    assert "GST-" in g_res["guest_reference"]
    session_id = g_res["session_id"]
    request_id = g_res["request_id"]

    # 6. Upcoming Guest Sessions
    resp_up = client.get("/api/live-classes/guest/upcoming-sessions")
    assert resp_up.status_code == 200
    assert len(resp_up.json()["data"]["sessions"]) > 0

    # 7. Host Views Waiting Room
    resp_wait = client.get(f"/api/live-classes/sessions/{session_id}/waiting-room")
    assert resp_wait.status_code == 200
    w_data = resp_wait.json()["data"]
    assert w_data["waiting_count"] >= 1
    assert any(g["request_id"] == request_id for g in w_data["guests"])

    # 8. Host Admits Guest
    resp_adm = client.post(
        f"/api/live-classes/sessions/{session_id}/guests/{request_id}/review",
        json={"decision": "ADMIT"}
    )
    assert resp_adm.status_code == 200
    assert resp_adm.json()["data"]["decision"] == "APPROVED"


def test_conduct_class_full_interactive_lifecycle():
    # 1. Fetch Conduct Class data for math class or default
    # First find session for 10A-MATH if possible
    resp_val = client.post("/api/live-classes/join-code/validate", json={"code": "10A-MATH"})
    target_session_id = None
    if resp_val.status_code == 200 and resp_val.json().get("data", {}).get("session"):
        target_session_id = resp_val.json()["data"]["session"]["id"]

    url = f"/api/live-classes/conduct?session_id={target_session_id}" if target_session_id else "/api/live-classes/conduct"
    resp = client.get(url)
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert "active_session" in data
    assert "stats" in data
    assert "participants" in data
    assert "upcoming_classes" in data
    assert "questions" in data
    assert "active_poll" in data
    assert "whiteboard" in data
    assert "engagement" in data

    active_session = data["active_session"]
    session_id = active_session["id"]
    assert session_id is not None
    assert "subject" in active_session
    assert "class_section" in active_session

    # Verify participants
    participants = data["participants"]
    assert isinstance(participants, list)

    # 2. Submit a new question
    q_payload = {
        "question": "Can we solve this using completing the square method?",
        "is_anonymous": False
    }
    resp_q = client.post(f"/api/live-classes/sessions/{session_id}/questions", json=q_payload)
    assert resp_q.status_code == 200
    q_data = resp_q.json()["data"]
    question_id = q_data["id"]
    assert q_data["question"] == q_payload["question"]

    # 3. Upvote the question
    resp_up = client.post(f"/api/live-classes/questions/{question_id}/upvote")
    assert resp_up.status_code == 200
    assert resp_up.json()["data"]["success"] is True

    # 4. Answer the question
    ans_payload = {
        "answer": "Yes, completing the square is the foundation of deriving the quadratic formula!"
    }
    resp_ans = client.post(f"/api/live-classes/questions/{question_id}/answer", json=ans_payload)
    assert resp_ans.status_code == 200
    assert resp_ans.json()["data"]["answer"] == ans_payload["answer"]

    # 5. Create a new poll
    poll_payload = {
        "title": "Quick Concept Check",
        "question": "If b² - 4ac = 0, how many distinct real roots are there?",
        "poll_type": "single_choice",
        "options": [
            {"id": "opt_1", "text": "Two distinct real roots"},
            {"id": "opt_2", "text": "Exactly one real root (repeated)"},
            {"id": "opt_3", "text": "No real roots"}
        ],
        "correct_option_id": "opt_2"
    }
    resp_poll = client.post(f"/api/live-classes/sessions/{session_id}/polls", json=poll_payload)
    assert resp_poll.status_code == 200
    poll_id = resp_poll.json()["data"]["id"]
    assert poll_id is not None

    # 6. Respond to the poll
    resp_vote = client.post(
        f"/api/live-classes/polls/{poll_id}/respond",
        json={"session_id": session_id, "option_id": "opt_2"}
    )
    assert resp_vote.status_code == 200
    assert resp_vote.json()["data"]["success"] is True

    # 7. Update whiteboard canvas
    wb_payload = {
        "canvas_data": {
            "strokes": [{"type": "line", "points": [10, 20, 100, 200]}],
            "formula": "ax^2 + bx + c = 0"
        },
        "teacher_only_mode": True
    }
    resp_wb = client.post(f"/api/live-classes/sessions/{session_id}/whiteboard", json=wb_payload)
    assert resp_wb.status_code == 200
    assert resp_wb.json()["data"]["teacher_only_mode"] is True

    # 8. Toggle recording
    resp_rec = client.post(f"/api/live-classes/sessions/{session_id}/recordings/toggle")
    assert resp_rec.status_code == 200
    assert "is_recording" in resp_rec.json()["data"]



