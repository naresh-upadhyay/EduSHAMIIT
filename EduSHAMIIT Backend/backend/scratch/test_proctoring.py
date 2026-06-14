import os
import sys
import json
import asyncio
from datetime import datetime, timedelta, timezone
from jose import jwt
import httpx

# Add parent directory to path so app is importable
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from dotenv import load_dotenv
load_dotenv(dotenv_path=os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../.env")))

os.environ["DATABASE_URL"] = "postgresql://postgres:eduSHAMIIT2026_pg@localhost:5432/postgres"
os.environ["SUPABASE_URL"] = "http://localhost:8000"
os.environ["REDIS_URL"] = "redis://:redis_password_2026@localhost:6379"
os.environ["REDIS_HOST"] = "localhost"

from app.services.supabase_client import get_supabase

BASE_URL = "http://127.0.0.1/api"

def make_token(user_id, school_id, role, class_name=None, email="test@edushamiit.com"):
    secret = os.getenv("SUPABASE_JWT_SECRET", "super-secret-jwt-token-with-at-least-32-characters-long")
    payload = {
        "sub": user_id,
        "school_id": school_id,
        "role": role,
        "class": class_name,
        "email": email,
    }
    return jwt.encode(payload, secret, algorithm="HS256")

async def run_tests():
    sb = get_supabase()
    print("Fetching profile data...")
    teachers_res = await sb.table("profiles").select("*").eq("role", "teacher").limit(1).aexecute()
    students_res = await sb.table("profiles").select("*").eq("role", "student").limit(1).aexecute()
    
    if not teachers_res.data or not students_res.data:
        print("Error: Teacher or Student not found in database.")
        sys.exit(1)
        
    teacher = teachers_res.data[0]
    student = students_res.data[0]
    
    teacher_id = teacher["id"]
    school_id = teacher["school_id"]
    student_id = student["id"]
    
    # Get classes assigned to this teacher from timetable
    tt_res = await sb.table("timetable").select("class").eq("school_id", school_id).eq("teacher_id", teacher_id).aexecute()
    assigned_classes = list({row["class"] for row in (tt_res.data or []) if row.get("class")})
    
    if not assigned_classes:
        # Create a dummy timetable slot to assign a class to the teacher
        print("Creating dummy timetable entry...")
        assigned_classes = ["X-A"]
        await sb.table("timetable").insert({
            "school_id": school_id,
            "teacher_id": teacher_id,
            "class": "X-A",
            "day_of_week": 1,
            "start_time": "09:00:00",
            "end_time": "10:00:00",
            "room": "Room 101",
            "custom_subject": "Mathematics"
        }).aexecute()
        
    student_class = assigned_classes[0]
    print(f"Setting student class to: {student_class}")
    # Backup original student class
    orig_student_class = student["class"]
    await sb.table("profiles").update({"class": student_class}).eq("id", student_id).aexecute()
    
    teacher_token = make_token(teacher_id, school_id, "teacher", email=teacher.get("email"))
    student_token = make_token(student_id, school_id, "student", class_name=student_class, email=student.get("email"))
    
    teacher_headers = {"Authorization": f"Bearer {teacher_token}"}
    student_headers = {"Authorization": f"Bearer {student_token}"}
    
    # 1. Create a dummy exam for proctor testing
    print("Creating a dummy online exam...")
    exam_payload = {
        "title": "Proctoring Test Exam",
        "subject": "Mathematics",
        "target_classes": [student_class],
        "exam_date": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
        "duration": "90",
        "total_marks": 100,
        "exam_type": "online",
        "status": "draft",
        "syllabus": "Algebra",
        "instructions": "No cheating"
    }
    
    exam_id = None
    async with httpx.AsyncClient(timeout=30.0) as http_client:
        create_res = await http_client.post(f"{BASE_URL}/teacher/exams/create", headers=teacher_headers, json=exam_payload)
        assert create_res.status_code == 200, f"Failed to create exam: {create_res.text}"
        exam_id = create_res.json()["data"]["exam_id"]
        print(f"Created Exam ID: {exam_id}")
        
        # Add a question to make status 'in_progress' and allow publishing
        q_payload = {
            "question_text": "Solve for x: 2x = 4",
            "question_type": "single_correct",
            "options": ["1", "2", "3", "4"],
            "correct_answer": "2",
            "marks": 5,
            "order_number": 1
        }
        q_res = await http_client.post(f"{BASE_URL}/teacher/exams/{exam_id}/questions", headers=teacher_headers, json=q_payload)
        assert q_res.status_code == 200, f"Failed to add question: {q_res.text}"
        question_id = q_res.json()["data"]["id"]
        print(f"Created Question ID (UUID): {question_id}")
        
        # Publish/schedule the exam
        publish_payload = {
            "status": "published",
            "start_time": (datetime.now(timezone.utc) - timedelta(minutes=5)).isoformat().replace("+00:00", "Z"),
            "end_time": (datetime.now(timezone.utc) + timedelta(minutes=85)).isoformat().replace("+00:00", "Z"),
        }
        pub_res = await http_client.put(f"{BASE_URL}/teacher/exams/{exam_id}", headers=teacher_headers, json=publish_payload)
        assert pub_res.status_code == 200, f"Failed to publish exam: {pub_res.text}"
        print("Exam published and set to start 5 minutes ago.")
        
        try:
            # 2. Get online exam payload from student perspective
            print("\n--- Test: GET /exams/{exam_id}/online ---")
            online_res = await http_client.get(f"{BASE_URL}/student/exams/{exam_id}/online", headers=student_headers)
            assert online_res.status_code == 200, f"Failed to get online details: {online_res.text}"
            data = online_res.json()["data"]
            assert "exam" in data
            assert "questions" in data
            assert "session" in data
            print("Successfully returned online details payload including 'session'.")

            # 3. Start session
            print("\n--- Test: POST /exams/{exam_id}/session/start ---")
            start_res = await http_client.post(f"{BASE_URL}/student/exams/{exam_id}/session/start", headers=student_headers)
            assert start_res.status_code == 200, f"Failed to start session: {start_res.text}"
            session_data = start_res.json()["data"]
            session_id = session_data["id"]
            print(f"Session started successfully. ID: {session_id}, Status: {session_data['status']}")
            
            # Start again (should reuse active session)
            print("Restarting session (should return active existing session)...")
            restart_res = await http_client.post(f"{BASE_URL}/student/exams/{exam_id}/session/start", headers=student_headers)
            assert restart_res.status_code == 200
            assert restart_res.json()["data"]["id"] == session_id
            print("Session reuse verified.")

            # 4. Ping session
            print("\n--- Test: POST /exams/{exam_id}/session/ping ---")
            ping_payload = {
                "warnings_count": 0,
                "active_question": question_id,
                "is_online": True,
                "log_event": "Student focused away"
            }
            ping_res = await http_client.post(f"{BASE_URL}/student/exams/{exam_id}/session/ping", headers=student_headers, json=ping_payload)
            assert ping_res.status_code == 200, f"Failed to ping: {ping_res.text}"
            ping_data = ping_res.json()["data"]
            assert len(ping_data["proctor_logs"]) > 0
            print(f"Ping successful. Logs: {ping_data['proctor_logs']}")

            # 5. Teacher actions: Warn, Pause, Resume, Extend
            print("\n--- Test: Teacher action (warn) ---")
            warn_res = await http_client.post(
                f"{BASE_URL}/teacher/exams/{exam_id}/sessions/{session_id}/action",
                headers=teacher_headers,
                json={"action": "warn", "message": "Stop looking around"}
            )
            assert warn_res.status_code == 200, warn_res.text
            print(f"Warn action response: {warn_res.json()}")

            print("\n--- Test: Teacher action (pause) ---")
            pause_res = await http_client.post(
                f"{BASE_URL}/teacher/exams/{exam_id}/sessions/{session_id}/action",
                headers=teacher_headers,
                json={"action": "pause"}
            )
            assert pause_res.status_code == 200
            assert pause_res.json()["data"]["is_paused"] == True
            print("Pause action verified.")

            print("\n--- Test: Teacher action (resume) ---")
            resume_res = await http_client.post(
                f"{BASE_URL}/teacher/exams/{exam_id}/sessions/{session_id}/action",
                headers=teacher_headers,
                json={"action": "resume"}
            )
            assert resume_res.status_code == 200
            assert resume_res.json()["data"]["is_paused"] == False
            print("Resume action verified.")

            print("\n--- Test: Teacher action (extend) ---")
            extend_res = await http_client.post(
                f"{BASE_URL}/teacher/exams/{exam_id}/sessions/{session_id}/action",
                headers=teacher_headers,
                json={"action": "extend", "extra_minutes": 15}
            )
            assert extend_res.status_code == 200
            assert extend_res.json()["data"]["extra_minutes"] == 15
            print("Extend action (+15) verified.")

            # 6. Submit exam
            print("\n--- Test: Submit exam as student ---")
            submit_payload = {"answers": {question_id: "2"}}
            submit_res = await http_client.post(f"{BASE_URL}/student/exams/{exam_id}/submit", headers=student_headers, json=submit_payload)
            assert submit_res.status_code == 200
            print("Submit exam verified.")

            # 7. Try starting session again (should block as completed)
            print("\n--- Test: Block start on completed session ---")
            block_res = await http_client.post(f"{BASE_URL}/student/exams/{exam_id}/session/start", headers=student_headers)
            assert block_res.status_code == 403
            print(f"Start blocked. Code: {block_res.status_code}, Detail: {block_res.json()['detail']}")

            # 8. Reopen session as teacher
            print("\n--- Test: Teacher action (reopen) ---")
            reopen_res = await http_client.post(
                f"{BASE_URL}/teacher/exams/{exam_id}/sessions/{session_id}/action",
                headers=teacher_headers,
                json={"action": "reopen"}
            )
            assert reopen_res.status_code == 200
            reopen_data = reopen_res.json()["data"]
            assert reopen_data["status"] == "active"
            assert reopen_data["ended_at"] is None
            
            # Check submission status in DB
            sub_res = await sb.table("exam_submissions").select("status").eq("exam_id", exam_id).eq("student_id", student_id).maybe_single().aexecute()
            assert sub_res.data["status"] == "active"
            print("Reopen session verified (session status='active', submission status='active').")

            # 9. Try starting session again (should allow re-entry because session is active now)
            print("\n--- Test: Allow start after reopen ---")
            re_start_res = await http_client.post(f"{BASE_URL}/student/exams/{exam_id}/session/start", headers=student_headers)
            assert re_start_res.status_code == 200
            print("Re-start session after reopen verified.")

        finally:
            print("\nCleaning up test exam and related records...")
            if exam_id:
                # Delete children first
                await sb.table("exam_submissions").delete().eq("exam_id", exam_id).aexecute()
                await sb.table("exam_sessions").delete().eq("exam_id", exam_id).aexecute()
                await sb.table("exam_questions").delete().eq("exam_id", exam_id).aexecute()
                await sb.table("exams").delete().eq("id", exam_id).aexecute()
            # Restore student class
            await sb.table("profiles").update({"class": orig_student_class}).eq("id", student_id).aexecute()
            print("Cleanup completed.")
            
    print("\n*** ALL PROCTORING WORKFLOW BACKEND TESTS COMPLETED SUCCESSFULLY! ***")

if __name__ == "__main__":
    asyncio.run(run_tests())
