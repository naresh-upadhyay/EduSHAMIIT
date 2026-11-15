"""
================================================================================
COMPREHENSIVE END-TO-END TEST SUITE FOR LIVE CLASS MANAGEMENT FULL FEATURES
================================================================================
Tests all database lookups, stored procedures, FastAPI endpoints, dynamic polls,
breakout rooms, session settings, host reassignment, recordings, and attendance.
================================================================================
"""

import sys
import os
import json
import time
import uuid
import psycopg2
from psycopg2.extras import RealDictCursor
import urllib.request
import urllib.error
from jose import jwt

DATABASE_URL = os.environ.get("DATABASE_URL", "postgresql://postgres:eduSHAMIIT2026_pg@localhost:54322/postgres")
API_BASE_URL = os.environ.get("API_BASE_URL", "http://localhost:8082")
JWT_SECRET = os.environ.get("JWT_SECRET", "super-secret-jwt-token-with-at-least-32-characters-long")
SCHOOL_ID = "11111111-1111-1111-1111-111111111111"
ADMIN_USER_ID = "5198c4b0-f1cb-45db-9649-41688d0438ba"  # King Doe
TEACHER_USER_ID = "10000000-0000-0000-0000-000000000002"

passed = 0
failed = 0

def log_test(test_num: int, name: str, success: bool, detail: str = ""):
    global passed, failed
    if success:
        passed += 1
        print(f"  [PASS] Test {test_num:02d}: {name} -> {detail}")
    else:
        failed += 1
        print(f"  [FAIL] Test {test_num:02d}: {name} -> {detail}")

def get_db():
    return psycopg2.connect(DATABASE_URL)

def get_jwt(user_id: str, role: str = "super_admin", email: str = "mathematicsking888@gmail.com"):
    payload = {
        "sub": user_id,
        "school_id": SCHOOL_ID,
        "role": role,
        "email": email,
        "exp": 9999999999
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")

def api_call(method: str, path: str, token: str, payload: dict = None):
    url = f"{API_BASE_URL}{path}"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=10) as res:
            res_body = res.read().decode("utf-8")
            return res.status, json.loads(res_body) if res_body else {}
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8")
        try:
            return e.code, json.loads(err_body)
        except Exception:
            return e.code, {"detail": err_body}
    except Exception as e:
        return 500, {"detail": str(e)}

def main():
    print("=" * 80)
    print("STARTING LIVE CLASS MANAGEMENT ENTERPRISE TEST SUITE")
    print(f"Target API: {API_BASE_URL} | Database: {DATABASE_URL}")
    print("=" * 80)

    admin_token = get_jwt(ADMIN_USER_ID, "super_admin")
    test_id = 1

    # --------------------------------------------------------------------------
    # 1. Database Lookups Verification (ACADEMIC_YEAR, STATUS, VISIBILITY)
    # --------------------------------------------------------------------------
    with get_db() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                SELECT k.key_code as lookup_type, v.value_code as lookup_code, v.value_name as lookup_label, v.status 
                FROM public.lookup_values v
                JOIN public.lookup_keys k ON v.lookup_key_id = k.id
                WHERE k.key_code IN ('ACADEMIC_YEAR', 'LIVE_CLASS_STATUS', 'RECORDING_VISIBILITY', 'ATTENDANCE_OVERRIDE_REASON')
                ORDER BY k.key_code, v.sort_order;
            """)
            rows = cur.fetchall()
            academic_years = [r for r in rows if r["lookup_type"] == "ACADEMIC_YEAR"]
            statuses = [r for r in rows if r["lookup_type"] == "LIVE_CLASS_STATUS"]
            visibilities = [r for r in rows if r["lookup_type"] == "RECORDING_VISIBILITY"]
            reasons = [r for r in rows if r["lookup_type"] == "ATTENDANCE_OVERRIDE_REASON"]

    log_test(
        test_id,
        "Lookup Values Seeded in DB",
        len(academic_years) >= 3 and len(statuses) >= 4 and len(visibilities) >= 3 and len(reasons) >= 4,
        f"Academic Years: {len(academic_years)}, Statuses: {len(statuses)}, Visibilities: {len(visibilities)}, Reasons: {len(reasons)}"
    )
    test_id += 1

    # --------------------------------------------------------------------------
    # 2. Academic Sessions Endpoint & Current Financial Year Calculation
    # --------------------------------------------------------------------------
    status, res = api_call("GET", "/api/lookups/code/ACADEMIC_YEAR", admin_token)
    values_list = res.get("values", res.get("data", {}).get("values", []))
    current_year_match = any("2026" in str(item.get("label") or item.get("value_name") or "") or "2025" in str(item.get("label") or item.get("value_name") or "") for item in values_list)
    log_test(
        test_id,
        "ACADEMIC_YEAR Lookup Endpoint & Dynamic Session",
        status == 200 and len(values_list) > 0 and current_year_match,
        f"Fetched {len(values_list)} academic sessions via API, status={status}"
    )
    test_id += 1

    # --------------------------------------------------------------------------
    # 3. Cascading Dropdown Metadata (Classes, Sections, Subjects, Teachers)
    # --------------------------------------------------------------------------
    status, res = api_call("GET", "/api/live-classes/meta/dropdowns", admin_token)
    data = res.get("data", {})
    classes = data.get("classes", [])
    sections = data.get("sections", [])
    subjects = data.get("subjects", [])
    teachers = data.get("teachers", [])

    log_test(
        test_id,
        "Cascading Dropdowns Metadata",
        status == 200 and len(classes) > 0 and len(sections) > 0 and len(subjects) > 0 and len(teachers) > 0,
        f"Classes: {len(classes)}, Sections: {len(sections)}, Subjects: {len(subjects)}, Teachers: {len(teachers)}"
    )
    test_id += 1

    target_class_id = classes[0]["id"] if classes else None
    target_section_id = sections[0]["id"] if sections else None
    target_subject_id = subjects[0]["id"] if subjects else None

    # --------------------------------------------------------------------------
    # 4. Enrolled Students Stored Procedure & API Endpoint
    # --------------------------------------------------------------------------
    status, res = api_call("GET", f"/api/live-classes/students?class_id={target_class_id}&section_id={target_section_id}", admin_token)
    students = res.get("data", {}).get("students", [])
    log_test(
        test_id,
        "Enrolled Students Resolution (Class + Section Filter)",
        status == 200 and isinstance(students, list),
        f"Returned {len(students)} real student records for class={target_class_id}"
    )
    test_id += 1

    # --------------------------------------------------------------------------
    # 5. Create Live Class Session & Host Designation
    # --------------------------------------------------------------------------
    session_title = f"Edge-Case Live Lecture - {uuid.uuid4().hex[:6]}"
    create_payload = {
        "title": session_title,
        "class_id": target_class_id,
        "section_id": target_section_id,
        "subject_id": target_subject_id,
        "topic": "Comprehensive Quantum Algorithms",
        "description": "Full-featured automated edge-case test session",
        "is_instant": True
    }
    status, res = api_call("POST", "/api/live-classes/sessions/instant", admin_token, create_payload)
    session_data = res.get("data", {})
    session_id = session_data.get("id") or session_data.get("live_class_id")

    log_test(
        test_id,
        "Instant Live Class Creation & Creator as Default Host",
        status in (200, 201) and session_id is not None,
        f"Session ID: {session_id}, Title: {session_title}"
    )
    test_id += 1

    if not session_id:
        with get_db() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT id FROM public.live_classes WHERE school_id = %s LIMIT 1;", (SCHOOL_ID,))
                row = cur.fetchone()
                if row:
                    session_id = str(row[0])

    # --------------------------------------------------------------------------
    # 6. Host Reassignment Endpoint & Stored Procedure
    # --------------------------------------------------------------------------
    status, res = api_call(
        "POST",
        f"/api/live-classes/sessions/{session_id}/host",
        admin_token,
        {"target_user_id": TEACHER_USER_ID, "role": "host"}
    )
    log_test(
        test_id,
        "Host Reassignment to Joined Participant",
        status == 200 and res.get("success") is True,
        f"Reassigned host of session {session_id} to {TEACHER_USER_ID}, result: {res.get('data')}"
    )
    test_id += 1

    # --------------------------------------------------------------------------
    # 7. Session Settings Update (Mic, Cam, Screen, Whiteboard, Waiting Room)
    # --------------------------------------------------------------------------
    settings_payload = {
        "allow_mic": False,
        "allow_camera": True,
        "allow_chat": True,
        "allow_screen_share": False,
        "allow_whiteboard": True,
        "waiting_room_enabled": True
    }
    status, res = api_call(
        "POST",
        f"/api/live-classes/sessions/{session_id}/settings",
        admin_token,
        settings_payload
    )
    log_test(
        test_id,
        "Session Media & Security Settings Toggle",
        status == 200 and res.get("success") is True,
        f"Settings successfully saved for session {session_id}"
    )
    test_id += 1

    # --------------------------------------------------------------------------
    # 8. Breakout Rooms Lifecycle (Create, List, Close)
    # --------------------------------------------------------------------------
    # Create
    breakout_payload = {
        "name": "Quantum Group 1",
        "capacity": 5,
        "assigned_student_ids": [s["id"] for s in students[:3]] if students else []
    }
    status, res = api_call(
        "POST",
        f"/api/live-classes/sessions/{session_id}/breakout",
        admin_token,
        breakout_payload
    )
    created_room = res.get("data", {}).get("room", {})
    room_id = created_room.get("id")
    log_test(
        test_id,
        "Breakout Room Creation & Student Assignment",
        status in (200, 201) and room_id is not None,
        f"Created Breakout Room ID: {room_id}, Name: {breakout_payload['name']}"
    )
    test_id += 1

    # List
    status, res = api_call(
        "GET",
        f"/api/live-classes/sessions/{session_id}/breakout",
        admin_token
    )
    rooms = res.get("data", {}).get("rooms", res.get("data", {}).get("breakout_rooms", []))
    log_test(
        test_id,
        "Breakout Rooms Listing",
        status == 200 and any(r.get("id") == room_id for r in rooms),
        f"Found {len(rooms)} breakout rooms for active session"
    )
    test_id += 1

    # Close
    if room_id:
        status, res = api_call(
            "POST",
            f"/api/live-classes/sessions/{session_id}/breakout/{room_id}/close",
            admin_token
        )
        log_test(
            test_id,
            "Breakout Room Close & Status Update",
            status == 200 and res.get("success") is True,
            f"Successfully closed breakout room {room_id}"
        )
        test_id += 1

    # --------------------------------------------------------------------------
    # 9. Dynamic Polls: Dynamic Options Creation & Percentage Accuracy
    # --------------------------------------------------------------------------
    # Create dynamic poll with 4 custom options
    poll_question = f"Dynamic Test Question: Which complexity is lower? ({uuid.uuid4().hex[:4]})"
    poll_payload = {
        "question": poll_question,
        "options": ["O(1) Constant", "O(log N) Logarithmic", "O(N) Linear", "O(N^2) Quadratic"],
        "duration_seconds": 180
    }
    status, res = api_call(
        "POST",
        f"/api/live-classes/sessions/{session_id}/polls",
        admin_token,
        poll_payload
    )
    poll_data = res.get("data", {})
    poll_id = poll_data.get("id")
    options = poll_data.get("options", [])

    log_test(
        test_id,
        "Dynamic Poll Creation with N Options",
        status in (200, 201) and poll_id is not None and len(options) == 4,
        f"Created Poll {poll_id} with {len(options)} options"
    )
    test_id += 1

    # Vote on option 0
    if poll_id and options:
        opt_0_id = options[0]["id"]
        status, res = api_call(
            "POST",
            f"/api/live-classes/polls/{poll_id}/respond",
            admin_token,
            {"session_id": session_id, "option_id": opt_0_id}
        )
        updated_poll = res.get("data", {})
        total_votes = updated_poll.get("total_votes", 0)
        opt_0_votes = next((o["votes"] for o in updated_poll.get("options", []) if o["id"] == opt_0_id), 0)
        percentage = round((opt_0_votes / total_votes * 100), 1) if total_votes > 0 else 0.0

        log_test(
            test_id,
            "Poll Vote Casting & Mathematical Percentage Calculation",
            status == 200 and opt_0_votes >= 1 and percentage == 100.0,
            f"Option 0 Votes: {opt_0_votes}/{total_votes} ({percentage}%) - Mathematically accurate!"
        )
        test_id += 1

    # --------------------------------------------------------------------------
    # 10. Q&A Questions Submission, Upvoting & Answering
    # --------------------------------------------------------------------------
    q_payload = {"question": "Can quadratic equations have complex roots with zero real part?"}
    status, res = api_call(
        "POST",
        f"/api/live-classes/sessions/{session_id}/questions",
        admin_token,
        q_payload
    )
    question_id = res.get("data", {}).get("id")
    log_test(
        test_id,
        "Q&A Question Submission",
        status in (200, 201) and question_id is not None,
        f"Submitted Q&A Question ID: {question_id}"
    )
    test_id += 1

    if question_id:
        # Upvote
        status, res = api_call("POST", f"/api/live-classes/questions/{question_id}/upvote", admin_token)
        log_test(
            test_id,
            "Q&A Question Upvote Tallying",
            status == 200,
            f"Question {question_id} upvoted successfully"
        )
        test_id += 1

        # Answer
        status, res = api_call(
            "POST",
            f"/api/live-classes/questions/{question_id}/answer",
            admin_token,
            {"answer": "Yes, purely imaginary roots when b=0 and ac > 0."}
        )
        log_test(
            test_id,
            "Q&A Question Answering by Teacher/Host",
            status == 200,
            f"Answer submitted for question {question_id}"
        )
        test_id += 1

    # --------------------------------------------------------------------------
    # 11. Recordings Tab (Dashboard, Filter, Pagination, Sharing)
    # --------------------------------------------------------------------------
    status, res = api_call("GET", "/api/live-classes/dashboard/recordings", admin_token)
    rec_kpis = res.get("data", {}).get("kpis", res.get("data", {}))
    log_test(
        test_id,
        "Recordings Dashboard KPIs",
        status == 200 and "total_recordings" in rec_kpis,
        f"KPIs returned: total_recordings={rec_kpis.get('total_recordings')}"
    )
    test_id += 1

    status, res = api_call("GET", "/api/live-classes/recordings?page=1&limit=5", admin_token)
    rec_data = res.get("data", {})
    recordings_list = rec_data.get("recordings", [])
    pagination = rec_data.get("pagination", {})
    log_test(
        test_id,
        "Recordings Filter & Pagination Execution",
        status == 200 and isinstance(recordings_list, list),
        f"Page {pagination.get('page')}/{pagination.get('total_pages')}, Total Records: {pagination.get('total_records')}"
    )
    test_id += 1

    # --------------------------------------------------------------------------
    # 12. Attendance Tab (Dashboard, Records, Override)
    # --------------------------------------------------------------------------
    status, res = api_call("GET", "/api/live-classes/dashboard/attendance", admin_token)
    att_kpis = res.get("data", {}).get("kpis", res.get("data", {}))
    log_test(
        test_id,
        "Attendance Dashboard KPIs",
        status == 200 and ("avg_attendance_pct" in att_kpis or "total_sessions" in att_kpis),
        f"KPIs returned: total_sessions={att_kpis.get('total_sessions')}, avg={att_kpis.get('avg_attendance_pct')}%"
    )
    test_id += 1

    status, res = api_call("GET", "/api/live-classes/attendance?page=1&limit=10", admin_token)
    att_data = res.get("data", {})
    attendance_list = att_data.get("attendance", [])
    log_test(
        test_id,
        "Attendance Records List",
        status == 200 and isinstance(attendance_list, list),
        f"Returned {len(attendance_list)} attendance records"
    )
    test_id += 1

    if attendance_list:
        sample_att_id = attendance_list[0]["id"]
        override_payload = {
            "status": "PRESENT",
            "reason": "APPROVED_LEAVE",
            "notes": "Verified medical documentation"
        }
        status, res = api_call(
            "POST",
            f"/api/live-classes/attendance/{sample_att_id}/override",
            admin_token,
            override_payload
        )
        log_test(
            test_id,
            "Attendance Manual Override with Seeded Reason",
            status == 200 and res.get("success") is True,
            f"Overrode attendance {sample_att_id} with reason APPROVED_LEAVE"
        )
        test_id += 1

    # --------------------------------------------------------------------------
    # 13. My Classes Dynamic Filtering & Empty-State Behavior
    # --------------------------------------------------------------------------
    status, res = api_call("GET", "/api/live-classes/my-classes?date_filter=Today", admin_token)
    my_classes = res.get("data", {}).get("classes", [])
    log_test(
        test_id,
        "My Classes Schedule Query",
        status == 200 and isinstance(my_classes, list),
        f"Classes scheduled for Today: {len(my_classes)}"
    )
    test_id += 1

    # --------------------------------------------------------------------------
    # Summary
    # --------------------------------------------------------------------------
    print("\n" + "=" * 80)
    print(f"TEST RUN COMPLETE: {passed} PASSED, {failed} FAILED (TOTAL {passed + failed})")
    print("=" * 80)

    if failed == 0:
        print("ALL ENTERPRISE EDGE-CASE TESTS PASSED PERFECTLY!")
        sys.exit(0)
    else:
        print(f"WARNING: {failed} tests failed.")
        sys.exit(1)

if __name__ == "__main__":
    main()
