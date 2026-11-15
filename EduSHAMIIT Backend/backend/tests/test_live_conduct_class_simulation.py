"""
EduSHAMIIT - Live Conduct Class End-to-End Simulation Test Script
Simulates conducting a full live class session from start to finish:
- Token generation for Host & Students
- Conduct session retrieval
- Live chat message flow
- Q&A question submission, upvoting, and teacher answering
- Live Concept Poll creation and student response aggregation
- Participant management (mute/unmute)
- Embedded Whiteboard snapshot synchronization
- LiveKit Egress recording toggle
- Participant join/leave attendance tracking and auto-calculation
- Live class session conclusion
"""
import os
import sys
import uuid
try:
    import pytest
except ImportError:
    pytest = None
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))
sys.path.insert(0, "/app")
from app.main import app
from app.middleware.auth import get_current_user

# Mock teacher user for test execution
app.dependency_overrides[get_current_user] = lambda: {
    "id": "11111111-1111-1111-1111-111111111111",
    "school_id": "11111111-1111-1111-1111-111111111111",
    "full_name": "R. Kumar (Teacher)",
    "role": "teacher"
}

client = TestClient(app)

def test_full_live_conduct_class_simulation():
    print("\n--- STEP 1: Fetching Active Conduct Session ---")
    resp = client.get("/api/live-classes/conduct")
    assert resp.status_code == 200, f"Failed conduct GET: {resp.text}"
    conduct_data = resp.json()["data"]
    assert "active_session" in conduct_data
    session_id = conduct_data["active_session"]["id"]
    room_code = conduct_data["active_session"].get("room_code", "10A-MATH")
    print(f"Active Session ID: {session_id}, Room Code: {room_code}")

    print("\n--- STEP 2: Generate LiveKit Tokens for Host and Students ---")
    # Host token
    resp_token_host = client.get(f"/api/livekit/token?room={room_code}&name=R.+Kumar+(Teacher)")
    assert resp_token_host.status_code == 200
    host_token = resp_token_host.json()["token"]
    assert len(host_token) > 20
    print("Host token generated successfully.")

    # Student tokens
    students = [
        {"id": "22222222-2222-2222-2222-222222222222", "name": "Ananya Sharma"},
        {"id": "33333333-3333-3333-3333-333333333333", "name": "Rohan Verma"},
        {"id": "44444444-4444-4444-4444-444444444444", "name": "Priya Desai"},
        {"id": "55555555-5555-5555-5555-555555555555", "name": "Mohit Singh"},
    ]
    for s in students:
        resp_tok = client.get(f"/api/livekit/token?room={room_code}&identity={s['id']}&name={s['name']}")
        assert resp_tok.status_code == 200
        assert "token" in resp_tok.json()
    print(f"Generated tokens for {len(students)} student participants.")

    print("\n--- STEP 3: Toggle Live Class Recording ---")
    rec_resp = client.post(f"/api/live-classes/sessions/{session_id}/recordings/toggle")
    assert rec_resp.status_code == 200
    rec_status = rec_resp.json().get("status")
    print(f"Recording toggle response status: {rec_status}")

    print("\n--- STEP 4: Live Chat Messaging Stream ---")
    # Teacher message
    chat_teacher = client.post(
        f"/api/live-classes/{session_id}/chat",
        json={"message": "Good morning class! Today we delve into Quadratic Equations derivation."}
    )
    assert chat_teacher.status_code == 200

    # Student message
    chat_student = client.post(
        f"/api/live-classes/{session_id}/chat",
        json={"message": "Good morning sir! Can we also review the discriminant test conditions?"}
    )
    assert chat_student.status_code == 200
    print("Chat messages sent and recorded successfully.")

    print("\n--- STEP 5: Interactive Q&A Workflow ---")
    # Student submits a question
    qa_post = client.post(
        f"/api/live-classes/sessions/{session_id}/questions",
        json={"question": "Does the quadratic formula apply when coefficients a, b, or c are fractions or decimals?"}
    )
    assert qa_post.status_code == 200
    q_data = qa_post.json().get("data", {})
    question_id = q_data.get("id", str(uuid.uuid4()))
    print(f"Question posted with ID: {question_id}")

    # Another student upvotes the question
    upvote_resp = client.post(f"/api/live-classes/questions/{question_id}/upvote")
    assert upvote_resp.status_code == 200
    print("Question upvoted successfully.")

    # Teacher answers the question
    answer_resp = client.post(
        f"/api/live-classes/questions/{question_id}/answer",
        json={"answer": "Yes, absolutely! The quadratic formula holds for any real or complex coefficients as long as a != 0."}
    )
    assert answer_resp.status_code == 200
    print("Teacher answer submitted successfully.")

    print("\n--- STEP 6: Live Concept Poll Workflow ---")
    # Teacher launches a poll
    poll_payload = {
        "title": "Roots Discriminant Condition",
        "question": "What is the nature of the roots if the discriminant b^2 - 4ac < 0?",
        "options": [
            {"id": "opt_1", "text": "Two distinct real roots"},
            {"id": "opt_2", "text": "Two equal real roots"},
            {"id": "opt_3", "text": "Complex conjugate non-real roots"},
            {"id": "opt_4", "text": "Infinite real roots"}
        ],
        "correct_option_id": "opt_3"
    }
    poll_resp = client.post(f"/api/live-classes/sessions/{session_id}/polls", json=poll_payload)
    assert poll_resp.status_code == 200
    poll_data = poll_resp.json().get("data", {})
    poll_id = poll_data.get("id") or poll_data.get("poll_id", "poll_mock_1")
    print(f"Poll created with ID: {poll_id}")

    # Students vote on poll
    vote_resp = client.post(
        f"/api/live-classes/polls/{poll_id}/respond",
        json={"session_id": session_id, "option_id": "opt_3"}
    )
    assert vote_resp.status_code == 200
    print("Student poll vote recorded.")

    print("\n--- STEP 7: Embedded Whiteboard State Synchronization ---")
    wb_payload = {
        "snapshot_url": "https://storage.edushamiit.com/whiteboard/session_10a_math_snap1.png",
        "strokes_count": 48,
        "topic": "Derivation of x = (-b +- sqrt(b^2 - 4ac)) / 2a"
    }
    wb_resp = client.post(f"/api/live-classes/sessions/{session_id}/whiteboard", json=wb_payload)
    assert wb_resp.status_code == 200
    print("Whiteboard state persisted.")

    print("\n--- STEP 8: Participant Audio & Presence Management ---")
    student_to_mute = students[1]["id"]
    mute_resp = client.post(
        f"/api/live-classes/sessions/{session_id}/participants/{student_to_mute}/mute",
        json={"mute": True}
    )
    assert mute_resp.status_code == 200
    print(f"Participant {student_to_mute} muted by host.")

    print("\n--- STEP 9: Student Attendance Events ---")
    for s in students:
        event_resp = client.post(
            f"/api/live-classes/{session_id}/event",
            json={
                "student_id": s["id"],
                "event_type": "join",
                "timestamp": "2025-01-21T08:00:00Z"
            }
        )
        assert event_resp.status_code == 200
    print(f"Logged join attendance events for {len(students)} students.")

    print("\n--- STEP 10: Attendance Auto-Calculation ---")
    calc_resp = client.post(f"/api/live-classes/{session_id}/attendance/calculate")
    assert calc_resp.status_code == 200
    print("Automated attendance metrics calculated.")

    print("\n--- STEP 11: End Live Class Session ---")
    end_resp = client.post(f"/api/live-classes/{session_id}/end")
    assert end_resp.status_code == 200
    print("Live class session ended successfully.")

    print("\n=== LIVE CONDUCT CLASS SIMULATION PASSED WITH 100% SUCCESS ===")

if __name__ == "__main__":
    if pytest:
        pytest.main(["-v", "-s", __file__])
    else:
        test_full_live_conduct_class_simulation()
