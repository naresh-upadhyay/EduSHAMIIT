import os
import sys
import json
import asyncio
from datetime import datetime, timedelta
from jose import jwt
import httpx

# Add parent directory to path so app is importable
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

# 1. Load single root .env from root directory
from dotenv import load_dotenv
load_dotenv(dotenv_path=os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../.env")))

# 2. Override container hostnames with localhost for execution from the host
os.environ["DATABASE_URL"] = "postgresql://postgres:eduSHAMIIT2026_pg@localhost:5432/postgres"
os.environ["SUPABASE_URL"] = "http://localhost:8000"
os.environ["REDIS_URL"] = "redis://:redis_password_2026@localhost:6379"
os.environ["REDIS_HOST"] = "localhost"

from app.services.supabase_client import get_supabase

# Target server URL
BASE_URL = "http://127.0.0.1/api"

# Helper to sign token
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
    
    # 3. Retrieve database records for testing
    print("Fetching profiles from db...")
    teachers_res = await sb.table("profiles").select("*").eq("role", "teacher").limit(5).aexecute()
    students_res = await sb.table("profiles").select("*").eq("role", "student").limit(5).aexecute()
    
    teachers = teachers_res.data or []
    students = students_res.data or []
    
    if not teachers or not students:
        print("Error: Could not find teachers or students in database.")
        sys.exit(1)
        
    teacher = teachers[0]
    student = students[0]
    
    teacher_id = teacher["id"]
    school_id = teacher["school_id"]
    student_id = student["id"]
    student_class = student["class"] or "X-A"
    
    print(f"Testing with Teacher ID: {teacher_id}, Student ID: {student_id}, Student Class: {student_class}")
    
    # Get classes assigned to this teacher from timetable
    tt_res = await sb.table("timetable").select("class").eq("school_id", school_id).eq("teacher_id", teacher_id).aexecute()
    assigned_classes = list({row["class"] for row in (tt_res.data or []) if row.get("class")})
    
    print(f"Teacher assigned classes from timetable: {assigned_classes}")
    if not assigned_classes:
        print("Warning: Teacher has no assigned classes in timetable. Let's insert one for testing.")
        # Insert a dummy timetable slot to assign a class to the teacher
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
        print("Inserted dummy timetable slot for X-A.")
        
    assigned_class = assigned_classes[0]
    unassigned_class = "IX-Z" if "IX-Z" not in assigned_classes else "VIII-Y"
    
    # Sign JWT tokens
    teacher_token = make_token(teacher_id, school_id, "teacher", email=teacher.get("email"))
    student_token = make_token(student_id, school_id, "student", class_name=student_class, email=student.get("email"))
    
    teacher_headers = {"Authorization": f"Bearer {teacher_token}"}
    student_headers = {"Authorization": f"Bearer {student_token}"}
    
    async with httpx.AsyncClient(timeout=30.0) as http_client:
        print("\n--- Test 1: GET /api/teacher/classes ---")
        response = await http_client.get(f"{BASE_URL}/teacher/classes", headers=teacher_headers)
        print(f"Status code: {response.status_code}")
        print(f"Response: {response.text}")
        assert response.status_code == 200
        
        print("\n--- Test 2: POST /api/teacher/exams/create (Assigned Class) ---")
        exam_payload = {
            "title": "E2E Test Exam Assigned",
            "subject": "Mathematics",
            "target_classes": [assigned_class],
            "exam_date": (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d"),
            "duration": "90",
            "total_marks": 100,
            "exam_type": "online",
            "status": "draft",
            "syllabus": "Algebra",
            "instructions": "No cheating"
        }
        response = await http_client.post(f"{BASE_URL}/teacher/exams/create", headers=teacher_headers, json=exam_payload)
        print(f"Status code: {response.status_code}")
        print(f"Response: {response.text}")
        assert response.status_code == 200
        exam_id = response.json()["data"]["exam_id"]
        print(f"Created Exam ID: {exam_id}")
        
        print("\n--- Test 3: POST /api/teacher/exams/create (Unassigned Class - Should Fail) ---")
        bad_exam_payload = dict(exam_payload)
        bad_exam_payload["title"] = "E2E Test Exam Unassigned"
        bad_exam_payload["target_classes"] = [unassigned_class]
        response = await http_client.post(f"{BASE_URL}/teacher/exams/create", headers=teacher_headers, json=bad_exam_payload)
        print(f"Status code: {response.status_code}")
        print(f"Response: {response.text}")
        assert response.status_code == 403
        assert "not authorized" in response.json()["detail"].lower()
        
        print("\n--- Test 4: POST /api/teacher/timetable (Assigned Class) ---")
        timetable_payload = {
            "date": (datetime.now() + timedelta(days=2)).strftime("%Y-%m-%d"),
            "slot_type": "Live Class",
            "custom_subject": "Test Live Class",
            "class": assigned_class,
            "start_time": "11:00:00",
            "end_time": "12:00:00",
            "room": "Room 102"
        }
        response = await http_client.post(f"{BASE_URL}/teacher/timetable", headers=teacher_headers, json=timetable_payload)
        print(f"Status code: {response.status_code}")
        print(f"Response: {response.text}")
        assert response.status_code == 200
        
        print("\n--- Test 5: POST /api/teacher/timetable (Unassigned Class - Should Fail) ---")
        bad_timetable_payload = dict(timetable_payload)
        bad_timetable_payload["class"] = unassigned_class
        response = await http_client.post(f"{BASE_URL}/teacher/timetable", headers=teacher_headers, json=bad_timetable_payload)
        print(f"Status code: {response.status_code}")
        print(f"Response: {response.text}")
        assert response.status_code == 403
        assert "not authorized" in response.json()["detail"].lower()
        
        print("\n--- Test 6: PUT /api/teacher/exams/{exam_id} (Assigned Class) ---")
        update_payload = {
            "target_classes": [assigned_class],
            "status": "published"
        }
        response = await http_client.put(f"{BASE_URL}/teacher/exams/{exam_id}", headers=teacher_headers, json=update_payload)
        print(f"Status code: {response.status_code}")
        print(f"Response: {response.text}")
        assert response.status_code == 200
        
        print("\n--- Test 7: PUT /api/teacher/exams/{exam_id} (Unassigned Class - Should Fail) ---")
        bad_update_payload = {
            "target_classes": [unassigned_class]
        }
        response = await http_client.put(f"{BASE_URL}/teacher/exams/{exam_id}", headers=teacher_headers, json=bad_update_payload)
        print(f"Status code: {response.status_code}")
        print(f"Response: {response.text}")
        assert response.status_code == 403
        assert "not authorized" in response.json()["detail"].lower()
        
        print("\n--- Test 8: GET /api/student/exams (Dashboard Visibility Check) ---")
        # Set the student's class to the assigned class to check visibility
        print(f"Temporary matching student class to {assigned_class} for visibility check...")
        await sb.table("profiles").update({"class": assigned_class}).eq("id", student_id).aexecute()
        
        # Re-sign student token with matched class
        student_token_matched = make_token(student_id, school_id, "student", class_name=assigned_class, email=student.get("email"))
        student_headers_matched = {"Authorization": f"Bearer {student_token_matched}"}
        
        response = await http_client.get(f"{BASE_URL}/student/exams", headers=student_headers_matched)
        print(f"Status code: {response.status_code}")
        exams_list = response.json()["data"]["exams"]
        print(f"Number of student exams returned: {len(exams_list)}")
        
        # Check if the created and published exam is present in the student's list
        found = False
        for e in exams_list:
            if e["id"] == exam_id:
                found = True
                print(f"Found created exam {exam_id} in student dashboard. Status: {e.get('status')}")
                break
        
        assert found == True, "Published exam was not found on the student dashboard!"
        
        # Clean up test exam
        print("\nCleaning up test exam...")
        await sb.table("exams").delete().eq("id", exam_id).aexecute()
        
        # Restore student class
        await sb.table("profiles").update({"class": student["class"]}).eq("id", student_id).aexecute()
        
        print("\n*** ALL BACKEND E2E EXAM/TIMETABLE TESTS PASSED SUCCESSFULLY! ***")

if __name__ == "__main__":
    asyncio.run(run_tests())
