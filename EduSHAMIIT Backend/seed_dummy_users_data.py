"""
EduSHAMIIT Seeding Script
=========================
Seeding rich, realistic, and complete dummy data for:
  - Student: naresh.king88898@gmail.com
  - Teacher: nehaupadhyay9119@gmail.com
Using API endpoints ONLY (Absolutely no direct SQL/DB insertions).
"""

import os
import sys
import uuid
import requests
import time
from datetime import datetime, timedelta, timezone

BASE_URL = "http://127.0.0.1:80"
DEV_SECRET = "eduSHAMIIT-dev-seed-2026"
SCHOOL_ID = "11111111-1111-1111-1111-111111111111"

STUDENT_EMAIL = "naresh.king88898@gmail.com"
STUDENT_PASS = "naresh@1A"
TEACHER_EMAIL = "nehaupadhyay9119@gmail.com"
TEACHER_PASS = "naresh@1A"

TEMP_STUDENT_ADMIN = "temp_seeder_student_admin@gmail.com"
TEMP_TEACHER_ADMIN = "temp_seeder_teacher_admin@gmail.com"
TEMP_PASS = "TempPassword1A"


def promote_user(email, role):
    print(f"🔧 Promoting {email} to {role}...")
    r = requests.post(f"{BASE_URL}/api/dev/promote", json={
        "secret": DEV_SECRET,
        "email": email,
        "role": role
    })
    if r.status_code != 200:
        print(f"  [FAIL] Failed to promote {email}: {r.text}")
        sys.exit(1)
    print(f"  [OK] Successfully promoted {email} to {role}")


def login_or_register(email, password, role, full_name, class_name=None):
    login_payload = {"email": email, "password": password}
    r = requests.post(f"{BASE_URL}/api/auth/login", json=login_payload)
    if r.status_code == 200 and r.json().get("success"):
        data = r.json()["data"]
        token = data["token"]
        user_id = data["user"]["id"]
        print(f"🔑 Logged in: {email} (ID: {user_id})")
        return token, user_id

    # Register if login failed
    print(f"📝 Registering new account for {email}...")
    reg_payload = {
        "email": email,
        "password": password,
        "school_id": SCHOOL_ID,
        "full_name": full_name,
        "role": role
    }
    if class_name:
        reg_payload["class_name"] = class_name

    reg_r = requests.post(f"{BASE_URL}/api/auth/register", json=reg_payload)
    if reg_r.status_code != 200:
        print(f"  [FAIL] Registration failed for {email}: {reg_r.text}")
        sys.exit(1)

    # Login to get token
    r = requests.post(f"{BASE_URL}/api/auth/login", json=login_payload)
    if r.status_code != 200:
        print(f"  [FAIL] Login failed after registering {email}: {r.text}")
        sys.exit(1)

    data = r.json()["data"]
    token = data["token"]
    user_id = data["user"]["id"]
    print(f"🔑 Registered and logged in: {email} (ID: {user_id})")
    return token, user_id


def upload_avatar(user_id, image_path):
    print(f"📷 Uploading avatar for user {user_id}...")
    try:
        # Load environment variables to resolve Supabase keys
        env_vars = {}
        env_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".env")
        if os.path.exists(env_path):
            with open(env_path, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith("#") and "=" in line:
                        k, v = line.split("=", 1)
                        env_vars[k.strip()] = v.strip()

        service_role_key = env_vars.get("SUPABASE_SERVICE_ROLE_KEY")
        supabase_url = env_vars.get("SUPABASE_URL", "http://127.0.0.1:8000")
        if "kong" in supabase_url:
            supabase_url = supabase_url.replace("kong", "127.0.0.1")

        with open(image_path, "rb") as f:
            image_bytes = f.read()

        storage_path = f"avatars/{user_id}.png"
        storage_url = f"{supabase_url}/storage/v1/object/{storage_path}"

        headers = {
            "apikey": service_role_key,
            "Authorization": f"Bearer {service_role_key}",
            "Content-Type": "image/png",
            "x-upsert": "true"
        }

        r = requests.post(storage_url, headers=headers, data=image_bytes)
        if r.status_code in (200, 201):
            public_url = f"{supabase_url}/storage/v1/object/public/{storage_path}?t={int(datetime.now().timestamp())}"
            # Update via stats dev endpoint instead of SQL
            patch_r = requests.patch(f"{BASE_URL}/api/dev/profiles/{user_id}/stats", json={
                "secret": DEV_SECRET,
                "avatar_url": public_url
            })
            if patch_r.status_code == 200:
                print(f"  [OK] Profile avatar uploaded and mapped for {user_id}")
            else:
                print(f"  [FAIL] Failed to update profile avatar_url: {patch_r.text}")
        else:
            print(f"  [FAIL] Avatar upload to storage failed: {r.status_code} - {r.text}")
    except Exception as e:
        print(f"  [FAIL] Avatar upload exception: {str(e)}")


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    print("🚀 Starting EduSHAMIIT Seeding Script (API-Only)...")

    # 1. Login / Register Student & Teacher
    student_token, student_id = login_or_register(
        STUDENT_EMAIL, STUDENT_PASS, "student", "Naresh Upadhyay", "10A"
    )
    teacher_token, teacher_id = login_or_register(
        TEACHER_EMAIL, TEACHER_PASS, "teacher", "Neha Patel"
    )

    # 2. Force promote them to correct roles (ensuring correct profile role)
    promote_user(STUDENT_EMAIL, "student")
    promote_user(TEACHER_EMAIL, "teacher")

    # Re-login to get tokens reflecting correct roles
    s_login = requests.post(f"{BASE_URL}/api/auth/login", json={"email": STUDENT_EMAIL, "password": STUDENT_PASS}).json()["data"]
    t_login = requests.post(f"{BASE_URL}/api/auth/login", json={"email": TEACHER_EMAIL, "password": TEACHER_PASS}).json()["data"]
    student_token = s_login["token"]
    teacher_token = t_login["token"]

    S = {"Authorization": f"Bearer {student_token}"}
    T = {"Authorization": f"Bearer {teacher_token}"}

    # 3. Create & Elevate Temporary Admins
    _, sa_id = login_or_register(
        TEMP_STUDENT_ADMIN, TEMP_PASS, "student", "Seeder Student Admin", "10A"
    )
    _, ta_id = login_or_register(
        TEMP_TEACHER_ADMIN, TEMP_PASS, "teacher", "Seeder Teacher Admin"
    )

    promote_user(TEMP_STUDENT_ADMIN, "student_admin")
    promote_user(TEMP_TEACHER_ADMIN, "teacher_admin")

    # Login Admins to get elevated tokens
    sa_login = requests.post(f"{BASE_URL}/api/auth/login", json={"email": TEMP_STUDENT_ADMIN, "password": TEMP_PASS}).json()["data"]
    ta_login = requests.post(f"{BASE_URL}/api/auth/login", json={"email": TEMP_TEACHER_ADMIN, "password": TEMP_PASS}).json()["data"]
    sa_token = sa_login["token"]
    ta_token = ta_login["token"]

    SA = {"Authorization": f"Bearer {sa_token}"}
    TA = {"Authorization": f"Bearer {ta_token}"}

    # 4. Clean existing dummy data
    print("🧹 Cleaning up existing seeded data...")
    clean_r = requests.delete(f"{BASE_URL}/api/dev/seed-cleanup", json={
        "secret": DEV_SECRET,
        "school_id": SCHOOL_ID,
        "student_ids": [student_id],
        "teacher_ids": [teacher_id],
        "classes": ["10A", "10B", "11A"]
    })
    if clean_r.status_code == 200:
        print("  [OK] Cleaned up existing database records.")
    else:
        print(f"  [FAIL] Seed cleanup failed: {clean_r.text}")

    # 5. Create Subjects (Multi-Class, Multi-Subject)
    print("\n📚 Creating subjects...")
    subjects = [
        # Class 10A (Naresh)
        {"name": "Mathematics", "class": "10A", "icon": "📐", "color": "#4F46E5", "teacher_id": teacher_id},
        {"name": "Physics", "class": "10A", "icon": "⚡", "color": "#EC4899", "teacher_id": teacher_id},
        {"name": "Chemistry", "class": "10A", "icon": "🧪", "color": "#10B981", "teacher_id": teacher_id},
        {"name": "English", "class": "10A", "icon": "📖", "color": "#F59E0B", "teacher_id": teacher_id},
        # Class 10B
        {"name": "Mathematics", "class": "10B", "icon": "📐", "color": "#3B82F6", "teacher_id": teacher_id},
        {"name": "Physics", "class": "10B", "icon": "⚡", "color": "#F43F5E", "teacher_id": teacher_id},
        # Class 11A
        {"name": "Chemistry", "class": "11A", "icon": "🧪", "color": "#06B6D4", "teacher_id": teacher_id},
        {"name": "Biology", "class": "11A", "icon": "🧬", "color": "#8B5CF6", "teacher_id": teacher_id}
    ]
    subject_ids = {}
    for sub in subjects:
        r = requests.post(f"{BASE_URL}/api/admin/students/subjects", headers=SA, json=sub)
        if r.status_code == 200:
            sub_id = r.json()["data"]["id"]
            subject_ids[(sub["name"], sub["class"])] = sub_id
            print(f"  [OK] Created subject: {sub['name']} for class {sub['class']} ({sub_id})")
        else:
            print(f"  [FAIL] Failed to create subject {sub['name']}: {r.text}")

    # 6. Create Courses (Multi-Course per Subject)
    print("\n🎓 Creating courses...")
    courses = [
        ("Mathematics", "10A", "Calculus & Limits", "Intermediate limits, continuous functions, and basic derivative rules."),
        ("Mathematics", "10A", "Linear Algebra", "Introduction to matrices, determinants, and linear transformations."),
        ("Physics", "10A", "Electromagnetism", "Electric fields, magnetic induction, and Maxwell's equations."),
        ("Physics", "10A", "Thermodynamics", "Laws of thermodynamics, heat engines, and entropy."),
        ("Chemistry", "10A", "Organic Chemistry", "Carbon compounds, functional groups, and basic naming nomenclature."),
        ("Chemistry", "11A", "Chemical Bonding", "Valence shell structures, molecular orbitals, and hybridization theory.")
    ]
    for sub_name, cls, title, desc in courses:
        s_id = subject_ids.get((sub_name, cls))
        if s_id:
            payload = {
                "subject_id": s_id,
                "title": title,
                "description": desc,
                "is_published": True
            }
            r = requests.post(f"{BASE_URL}/api/admin/students/courses", headers=SA, json=payload)
            if r.status_code == 200:
                print(f"  [OK] Course '{title}' created for {sub_name} {cls}")
            else:
                print(f"  [FAIL] Failed to create course '{title}': {r.text}")

    # 7. Create Timetable Slots (Full Week Schedule)
    print("\n🗓️ Creating timetable slots...")
    # Mon-Sat schedule
    slots = [
        # Monday
        (0, "Mathematics", "10A", "08:30", "09:15", "Room 101"),
        (0, "Physics", "10A", "09:20", "10:05", "Room 101"),
        (0, "Chemistry", "10A", "10:10", "10:55", "Room 101"),
        (0, "English", "10A", "11:00", "11:45", "Room 101"),
        (0, "Mathematics", "10B", "12:00", "12:45", "Room 102"),
        (0, "Chemistry", "11A", "13:00", "13:45", "Room 201"),
        # Tuesday
        (1, "Physics", "10A", "08:30", "09:15", "Room 101"),
        (1, "Chemistry", "10A", "09:20", "10:05", "Room 101"),
        (1, "Mathematics", "10A", "10:10", "10:55", "Room 101"),
        (1, "English", "10A", "11:00", "11:45", "Room 101"),
        (1, "Physics", "10B", "12:00", "12:45", "Room 102"),
        # Wednesday
        (2, "Chemistry", "10A", "08:30", "09:15", "Room 101"),
        (2, "Mathematics", "10A", "09:20", "10:05", "Room 101"),
        (2, "Physics", "10A", "10:10", "10:55", "Room 101"),
        (2, "English", "10A", "11:00", "11:45", "Room 101"),
        (2, "Chemistry", "10B", "12:00", "12:45", "Room 102"),
        (2, "Chemistry", "11A", "13:00", "13:45", "Room 201"),
        # Thursday
        (3, "English", "10A", "08:30", "09:15", "Room 101"),
        (3, "Physics", "10A", "09:20", "10:05", "Room 101"),
        (3, "Chemistry", "10A", "10:10", "10:55", "Room 101"),
        (3, "Mathematics", "10A", "11:00", "11:45", "Room 101"),
        (3, "Mathematics", "10B", "12:00", "12:45", "Room 102"),
        # Friday
        (4, "Mathematics", "10A", "08:30", "09:15", "Room 101"),
        (4, "Chemistry", "10A", "09:20", "10:05", "Room 101"),
        (4, "Physics", "10A", "10:10", "10:55", "Room 101"),
        (4, "English", "10A", "11:00", "11:45", "Room 101"),
        (4, "Physics", "10B", "12:00", "12:45", "Room 102"),
        # Saturday
        (5, "Physics", "10A", "08:30", "09:15", "Room 101"),
        (5, "Mathematics", "10A", "09:20", "10:05", "Room 101"),
        (5, "English", "10A", "10:10", "10:55", "Room 101"),
        (5, "Chemistry", "11A", "11:00", "11:45", "Room 201")
    ]
    for day, sub_name, cls, start, end, room in slots:
        s_id = subject_ids.get((sub_name, cls))
        if s_id:
            payload = {
                "class": cls,
                "subject_id": s_id,
                "teacher_id": teacher_id,
                "day_of_week": day,
                "start_time": start,
                "end_time": end,
                "room": room
            }
            requests.post(f"{BASE_URL}/api/admin/students/timetable", headers=SA, json=payload)
            time.sleep(0.01)
    print("  [OK] Timetable slots created successfully.")

    # 8. Create Homeworks & Submissions
    print("\n📝 Seeding homeworks, submissions, and grading...")
    homework_configs = [
        {"sub": "Mathematics", "title": "Calculus Assignment", "desc": "Solve derivatives exercises 1-5.", "max": 20, "score": 18, "remarks": "Excellent work! Clear proofs."},
        {"sub": "Physics", "title": "Electromagnetic Induction Report", "desc": "Write a 500-word essay on Faraday's laws.", "max": 50, "score": 35, "remarks": "Good coverage, check calculations."},
        {"sub": "Chemistry", "title": "Organic Chemistry Lab Report", "desc": "Describe the functional group tests.", "max": 100, "score": None, "remarks": ""}
    ]
    for hw in homework_configs:
        s_id = subject_ids.get((hw["sub"], "10A"))
        if s_id:
            due = (datetime.now() + timedelta(days=5)).date().isoformat()
            hw_payload = {
                "subject_id": s_id,
                "title": hw["title"],
                "description": hw["desc"],
                "due_date": due,
                "max_marks": hw["max"],
                "target_class": "10A",
                "teacher_id": teacher_id
            }
            hw_r = requests.post(f"{BASE_URL}/api/admin/teachers/homework", headers=TA, json=hw_payload)
            if hw_r.status_code == 200:
                hw_id = hw_r.json()["data"]["homework_id"]
                print(f"  [OK] Created homework '{hw['title']}' ({hw_id})")

                # Submit homework as student Naresh
                sub_r = requests.post(f"{BASE_URL}/api/student/homework/submit", headers=S, json={
                    "homework_id": hw_id,
                    "submission_text": f"Submitted response for {hw['title']}."
                })
                if sub_r.status_code == 200:
                    print(f"    [OK] Student submitted homework '{hw['title']}'")
                    # If grading is requested
                    if hw["score"] is not None:
                        # Get submissions
                        sub_res = requests.get(f"{BASE_URL}/api/teacher/submissions", headers=T).json().get("data", {}).get("submissions", [])
                        matching_sub = next((s for s in sub_res if s["homework_id"] == hw_id and s["student_id"] == student_id), None)
                        if matching_sub:
                            grade_r = requests.post(f"{BASE_URL}/api/teacher/submissions/grade", headers=T, json={
                                "submission_id": matching_sub["id"],
                                "marks": hw["score"],
                                "grade": "A" if hw["score"] / hw["max"] >= 0.8 else "B",
                                "remarks": hw["remarks"]
                            })
                            if grade_r.status_code == 200:
                                print(f"    [OK] Teacher graded submission: {hw['score']}/{hw['max']}")

    # 9. Mark Attendance (30 Days History)
    print("\n📋 Marking 30 days of attendance history for student...")
    for offset_days in range(1, 31):
        # Skip Sundays
        date_obj = datetime.now() - timedelta(days=offset_days)
        if date_obj.weekday() == 6:
            continue
        date_str = date_obj.date().isoformat()
        
        # Distribution: 24 Present, 2 Absent, 4 Late
        if offset_days % 15 == 0:
            status = "absent"
        elif offset_days % 7 == 0:
            status = "late"
        else:
            status = "present"
            
        for (sub_name, cls), s_id in subject_ids.items():
            if cls == "10A":
                payload = {
                    "subject_id": s_id,
                    "class_name": "10A",
                    "date": date_str,
                    "attendance_records": [{"student_id": student_id, "status": status}]
                }
                requests.post(f"{BASE_URL}/api/teacher/attendance/mark", headers=T, json=payload)
                time.sleep(0.01)
    print("  [OK] Attendance history seeded.")

    # 10. Seed Question Bank (MCQ, Multi-Select, Subjective)
    print("\n📚 Seeding question bank repository...")
    bank_questions = [
        # Math Single Select
        {"subject": "Mathematics", "question_text": "What is the derivative of x^2 with respect to x?", "question_type": "single_select", "options": ["x", "2x", "2", "x^2"], "correct_answer": "B", "difficulty": "Easy", "marks": 2, "chapter": "Calculus"},
        {"subject": "Mathematics", "question_text": "Find the determinant of a 2x2 identity matrix.", "question_type": "single_select", "options": ["0", "1", "-1", "2"], "correct_answer": "B", "difficulty": "Easy", "marks": 2, "chapter": "Matrices"},
        # Math Multi-Select
        {"subject": "Mathematics", "question_text": "Which of the following are prime numbers?", "question_type": "multi_select", "options": ["2", "4", "5", "9"], "correct_answer": "A,C", "difficulty": "Medium", "marks": 3, "chapter": "Number Theory"},
        {"subject": "Mathematics", "question_text": "Select all functions that are continuous everywhere.", "question_type": "multi_select", "options": ["sin(x)", "cos(x)", "tan(x)", "e^x"], "correct_answer": "A,B,D", "difficulty": "Hard", "marks": 4, "chapter": "Calculus"},
        # Math Subjective
        {"subject": "Mathematics", "question_text": "State and prove the mean value theorem.", "question_type": "subjective", "options": None, "correct_answer": "If f is continuous on [a,b] and differentiable on (a,b), then there exists c in (a,b) such that f'(c) = (f(b)-f(a))/(b-a).", "difficulty": "Hard", "marks": 10, "chapter": "Calculus"},

        # Physics Single Select
        {"subject": "Physics", "question_text": "What is the SI unit of magnetic flux?", "question_type": "single_select", "options": ["Tesla", "Weber", "Henry", "Ampere"], "correct_answer": "B", "difficulty": "Easy", "marks": 2, "chapter": "Electromagnetism"},
        # Physics Multi-Select
        {"subject": "Physics", "question_text": "Which of the following equations are part of Maxwell's Equations?", "question_type": "multi_select", "options": ["Gauss's Law", "Faraday's Law", "Newton's Second Law", "Ampere's Circuital Law"], "correct_answer": "A,B,D", "difficulty": "Medium", "marks": 3, "chapter": "Electromagnetism"},
        # Physics Subjective
        {"subject": "Physics", "question_text": "Explain Lenz's Law and its connection to conservation of energy.", "question_type": "subjective", "options": None, "correct_answer": "The direction of the induced current is such that it opposes the change in magnetic flux that produced it, which represents the conservation of energy.", "difficulty": "Medium", "marks": 5, "chapter": "Electromagnetism"}
    ]
    for q in bank_questions:
        s_id = subject_ids.get((q["subject"], "10A"))
        if s_id:
            payload = {
                "subject_id": s_id,
                "chapter": q["chapter"],
                "question_text": q["question_text"],
                "question_type": q["question_type"],
                "options": q["options"],
                "correct_answer": q["correct_answer"],
                "difficulty": q["difficulty"],
                "marks": q["marks"]
            }
            requests.post(f"{BASE_URL}/api/teacher/question-bank", headers=T, json=payload)
    print("  [OK] Seeded 8 questions to the Question Bank.")

    # 11. Seeding Exams & Results
    print("\n✍️ Seeding exams and workflow submissions...")
    # Past Exam (offline)
    math_exam_date = (datetime.now() - timedelta(days=5)).date().isoformat()
    past_exam_payload = {
        "subject_id": subject_ids.get(("Mathematics", "10A")),
        "title": "Mathematics Unit Test 1",
        "exam_type": "offline",
        "exam_category": "Unit Test",
        "exam_date": math_exam_date,
        "start_time": f"{math_exam_date}T09:00:00",
        "duration_minutes": 60,
        "total_marks": 100,
        "venue": "Room 101",
        "target_classes": ["10A"]
    }
    past_r = requests.post(f"{BASE_URL}/api/admin/students/exams", headers=SA, json=past_exam_payload)
    if past_r.status_code == 200:
        print("  [OK] Created past Mathematics offline exam.")
        # Enter Result for student
        requests.post(f"{BASE_URL}/api/admin/students/results", headers=SA, json={
            "student_id": student_id,
            "subject_id": subject_ids.get(("Mathematics", "10A")),
            "marks_obtained": 92.0,
            "total_marks": 100.0,
            "remarks": "Excellent conceptual understanding!",
            "exam_type": "Unit Test"
        })
        print("  [OK] Offline result entered (92/100).")

    # Upcoming Exam (offline)
    phys_exam_date = (datetime.now() + timedelta(days=10)).date().isoformat()
    upcoming_exam_payload = {
        "subject_id": subject_ids.get(("Physics", "10A")),
        "title": "Physics Mid-Term Exam",
        "exam_type": "offline",
        "exam_category": "Mid Term",
        "exam_date": phys_exam_date,
        "start_time": f"{phys_exam_date}T10:00:00",
        "duration_minutes": 90,
        "total_marks": 50,
        "venue": "Lab 2",
        "target_classes": ["10A"]
    }
    requests.post(f"{BASE_URL}/api/admin/students/exams", headers=SA, json=upcoming_exam_payload)
    print("  [OK] Created upcoming Physics offline exam.")

    # Upcoming Online Quiz (online)
    quiz_exam_date = (datetime.now() + timedelta(days=4)).date().isoformat()
    quiz_exam_payload = {
        "subject_id": subject_ids.get(("Chemistry", "10A")),
        "title": "Chemistry Quiz 1",
        "exam_type": "online",
        "exam_category": "Quiz",
        "exam_date": quiz_exam_date,
        "start_time": f"{quiz_exam_date}T11:00:00",
        "duration_minutes": 30,
        "total_marks": 10,
        "venue": "Online",
        "target_classes": ["10A"]
    }
    requests.post(f"{BASE_URL}/api/admin/students/exams", headers=SA, json=quiz_exam_payload)
    print("  [OK] Created upcoming Chemistry online quiz.")

    # Active Live Online Exam (workflows: start, submit, grade, publish)
    active_exam_date = datetime.now().date().isoformat()
    active_exam_payload = {
        "subject_id": subject_ids.get(("Physics", "10A")),
        "title": "Physics Term Online Exam",
        "exam_type": "online",
        "exam_category": "Term Exam",
        "exam_date": active_exam_date,
        "start_time": f"{active_exam_date}T08:00:00",
        "duration_minutes": 180,
        "total_marks": 50,
        "venue": "Online",
        "target_classes": ["10A"]
    }
    active_r = requests.post(f"{BASE_URL}/api/admin/students/exams", headers=SA, json=active_exam_payload)
    if active_r.status_code == 200:
        exam_id = active_r.json()["data"]["exam_id"]
        print(f"  [OK] Created active online exam ({exam_id})")

        # Add questions (2 Single Select, 1 Multi-Select, 2 Subjective)
        questions_to_add = [
            {"question_text": "Identify SI unit of current.", "question_type": "single_select", "options": ["Weber", "Tesla", "Ampere", "Volt"], "correct_answer": "C", "marks": 5},
            {"question_text": "What is the speed of light in vacuum?", "question_type": "single_select", "options": ["3e8 m/s", "3e6 m/s", "1e8 m/s", "3e10 m/s"], "correct_answer": "A", "marks": 5},
            {"question_text": "Select all magnetic materials.", "question_type": "multi_select", "options": ["Iron", "Cobalt", "Nickel", "Copper"], "correct_answer": "A,B,C", "marks": 10},
            {"question_text": "Explain photoelectric effect.", "question_type": "subjective", "options": None, "correct_answer": "Emission of electrons when light shines on a material.", "marks": 15},
            {"question_text": "State Faraday's first law of electromagnetic induction.", "question_type": "subjective", "options": None, "correct_answer": "Change in magnetic flux induces an electromotive force.", "marks": 15}
        ]
        q_ids = []
        for q in questions_to_add:
            q_res = requests.post(f"{BASE_URL}/api/teacher/exams/{exam_id}/questions", headers=T, json=q).json()
            q_ids.append(q_res["data"]["id"])
        print(f"    [OK] Added {len(q_ids)} questions to exam.")

        # Student starts session
        requests.post(f"{BASE_URL}/api/student/exams/{exam_id}/session/start", headers=S)
        print("    [OK] Student started online exam session.")

        # Student submits answers
        submit_r = requests.post(f"{BASE_URL}/api/student/exams/{exam_id}/submit", headers=S, json={
            "answers": {
                q_ids[0]: "C",       # Correct
                q_ids[1]: "A",       # Correct
                q_ids[2]: "A,B,C",   # Correct
                q_ids[3]: "Electrons are emitted when light hits a metal surface.", # Subjective
                q_ids[4]: "An EMF is induced when magnetic field changes." # Subjective
            }
        })
        if submit_r.status_code == 200:
            sub_id = submit_r.json()["data"]["id"]
            print(f"    [OK] Student submitted online exam. Submission ID: {sub_id}")

            # Teacher grades subjective parts
            grade_r = requests.post(f"{BASE_URL}/api/teacher/exams/{exam_id}/submissions/{sub_id}/grade", headers=T, json={
                "score": 44.0,  # 20 points from MCQ, 24/30 from subjective
                "remarks": "Excellent explanations!"
            })
            if grade_r.status_code == 200:
                print("    [OK] Teacher graded the submission.")

                # Publish Results
                pub_r = requests.post(f"{BASE_URL}/api/teacher/exams/{exam_id}/results/publish", headers=T)
                if pub_r.status_code == 200:
                    print("    [OK] Teacher published online exam results.")

    # 12. Seeding Fees (6+ Fee Types: Paid, Pending, Overdue)
    print("\n💳 Seeding student fees and payments...")
    fee_schedules = [
        {"type": "Tuition Fee - Q1", "amount": 5000.0, "offset": -60, "pay": True},
        {"type": "Tuition Fee - Q2", "amount": 5000.0, "offset": -30, "pay": True},
        {"type": "Transport Fee - Q1", "amount": 1200.0, "offset": -30, "pay": True},
        {"type": "Tuition Fee - Q3", "amount": 5000.0, "offset": 15, "pay": False},  # Pending
        {"type": "Laboratory Deposit", "amount": 1500.0, "offset": -10, "pay": False}, # Overdue
        {"type": "Annual Sports Fee", "amount": 800.0, "offset": -5, "pay": False},    # Overdue
        {"type": "First Term Exam Fee", "amount": 500.0, "offset": 20, "pay": False}    # Pending
    ]
    for fee in fee_schedules:
        due = (datetime.now() + timedelta(days=fee["offset"])).date().isoformat()
        fee_payload = {
            "fee_type": fee["type"],
            "amount": fee["amount"],
            "due_date": due,
            "target_class": "10A"
        }
        requests.post(f"{BASE_URL}/api/admin/students/fees", headers=SA, json=fee_payload)
        
    # Mark paid ones
    fees_res_raw = requests.get(f"{BASE_URL}/api/admin/students/fees?student_id={student_id}", headers=SA)
    if fees_res_raw.status_code != 200:
        print(f"  [FAIL] Failed to retrieve fees: {fees_res_raw.status_code} - {fees_res_raw.text}")
        sys.exit(1)
    fees_res = fees_res_raw.json().get("data", {}).get("fees", [])
    for fee_rec in fees_res:
        match = next((f for f in fee_schedules if f["type"] == fee_rec["fee_type"] and f["pay"]), None)
        if match:
            requests.put(f"{BASE_URL}/api/admin/students/fees/{fee_rec['id']}", headers=SA, json={
                "status": "paid",
                "paid_at": datetime.now(timezone.utc).isoformat()
            })
    print("  [OK] Fees and payments seeded successfully.")

    # 13. Transport
    print("\n🚌 Seeding transport routes, stops, telemetry, and assignments...")
    route_payload = {
        "route_name": "Route 10 - North Express Line",
        "bus_number": "DL-1PC-8898",
        "driver_name": "Sukhwinder Singh",
        "driver_phone": "9812345670",
        "total_capacity": 40
    }
    r = requests.post(f"{BASE_URL}/api/admin/students/transport/routes", headers=SA, json=route_payload)
    if r.status_code == 200:
        route_id = r.json()["data"]["id"]
        print(f"  [OK] Created route: {route_payload['route_name']}")

        # Create Bus Stop (using API)
        stop_r = requests.post(f"{BASE_URL}/api/admin/students/transport/stops", headers=SA, json={
            "route_id": route_id,
            "stop_name": "Greenwood Apartments Gate",
            "latitude": 28.6139,
            "longitude": 77.2090,
            "stop_order": 1,
            "estimated_arrival": "07:40:00"
        })
        if stop_r.status_code == 200:
            stop_id = stop_r.json()["data"]["id"]
            print(f"  [OK] Created bus stop: Greenwood Apartments Gate")

            # Create telemetry location
            loc_r = requests.post(f"{BASE_URL}/api/admin/students/transport/locations", headers=SA, json={
                "route_id": route_id,
                "latitude": 28.6139,
                "longitude": 77.2090,
                "speed": 35.5
            })
            if loc_r.status_code == 200:
                print("  [OK] Recorded bus telemetry location.")

            # Assign to Naresh
            requests.post(f"{BASE_URL}/api/admin/students/transport/assign", headers=SA, json={
                "student_id": student_id,
                "route_id": route_id,
                "stop_id": stop_id
            })
            print("  [OK] Student assigned to route and stop.")

    # 14. Library
    print("\n📚 Seeding library catalogs and borrows...")
    books = [
        {"title": "A Brief History of Time", "author": "Stephen Hawking", "isbn": "978-0553380163", "category": "Cosmology"},
        {"title": "Concepts of Physics", "author": "H.C. Verma", "isbn": "978-8177091878", "category": "Physics"},
        {"title": "Organic Chemistry", "author": "Morrison & Boyd", "isbn": "978-8131704813", "category": "Chemistry"},
        {"title": "Mathematics Exemplar", "author": "NCERT", "isbn": "978-9350711111", "category": "Mathematics"},
        {"title": "The Golden Gate", "author": "Vikram Seth", "isbn": "978-0140105346", "category": "Fiction"}
    ]
    book_ids = []
    for b in books:
        book_r = requests.post(f"{BASE_URL}/api/admin/students/library/books", headers=SA, json={
            "title": b["title"], "author": b["author"], "isbn": b["isbn"], "category": b["category"], "total_copies": 3
        })
        if book_r.status_code == 200:
            book_ids.append(book_r.json()["data"]["id"])
        else:
            print(f"  [FAIL] Failed to create book {b['title']}: {book_r.status_code} - {book_r.text}")
            
    # Borrow 1 (overdue)
    requests.post(f"{BASE_URL}/api/admin/students/library/borrows", headers=SA, json={
        "student_id": student_id, "book_id": book_ids[0], "due_date": (datetime.now() - timedelta(days=5)).date().isoformat()
    })
    # Borrow 2 (active)
    requests.post(f"{BASE_URL}/api/admin/students/library/borrows", headers=SA, json={
        "student_id": student_id, "book_id": book_ids[1], "due_date": (datetime.now() + timedelta(days=10)).date().isoformat()
    })
    # Borrow 3 (requested return -> pending_return)
    b3_r = requests.post(f"{BASE_URL}/api/admin/students/library/borrows", headers=SA, json={
        "student_id": student_id, "book_id": book_ids[2], "due_date": (datetime.now() + timedelta(days=8)).date().isoformat()
    })
    if b3_r.status_code == 200:
        b3_id = b3_r.json()["data"]["id"]
        # Student returns it
        requests.post(f"{BASE_URL}/api/student/library/borrows/{b3_id}/return", headers=S)
    print("  [OK] Catalog and student borrows created successfully.")

    # 15. Achievements
    print("\n🏆 Seeding achievements...")
    achievements = [
        {"name": "Science Prodigy", "description": "Scored over 90% in multiple STEM subjects", "icon": "🧬", "rarity": "rare", "xp_reward": 500},
        {"name": "Perfect Attendance", "description": "100% attendance recorded in a month", "icon": "📅", "rarity": "epic", "xp_reward": 1000},
        {"name": "Library Devotee", "description": "Borrowed and read 10+ books this semester", "icon": "📖", "rarity": "common", "xp_reward": 200}
    ]
    for ach in achievements:
        ach_r = requests.post(f"{BASE_URL}/api/admin/students/achievements", headers=SA, json=ach)
        if ach_r.status_code == 200:
            ach_id = ach_r.json()["data"]["id"]
            requests.post(f"{BASE_URL}/api/admin/students/achievements/award", headers=SA, json={
                "achievement_id": ach_id,
                "student_ids": [student_id]
            })
    print("  [OK] Seeded and awarded achievements.")

    # 16. Profile Stats Boost (Gamification)
    print("\n🎮 Boosting profiles gamification stats...")
    stats_r = requests.patch(f"{BASE_URL}/api/dev/profiles/{student_id}/stats", json={
        "secret": DEV_SECRET,
        "xp_points": 2850,
        "learning_streak": 21,
        "best_streak": 30,
        "roll_number": 7,
        "admission_number": "ADM-10-2025",
        "session": "2025-2026",
        "gender": "Male"
    })
    if stats_r.status_code == 200:
        print("  [OK] Student gamification stats boosted successfully.")
        
    requests.patch(f"{BASE_URL}/api/dev/profiles/{teacher_id}/stats", json={
        "secret": DEV_SECRET,
        "gender": "Female"
    })

    # Upload avatars using local assets
    script_dir = os.path.dirname(os.path.abspath(__file__))
    student_avatar_path = os.path.join(script_dir, "assets", "boy_student.png")
    teacher_avatar_path = os.path.join(script_dir, "assets", "female_teacher.png")
    upload_avatar(student_id, student_avatar_path)
    upload_avatar(teacher_id, teacher_avatar_path)

    # 17. Teacher Payslips
    print("\n💵 Seeding teacher payslips...")
    months = ["2026-01", "2026-02", "2026-03", "2026-04", "2026-05", "2026-06"]
    for i, month in enumerate(months):
        status = "pending" if i == 5 else "paid"
        requests.post(f"{BASE_URL}/api/admin/teachers/salary", headers=TA, json={
            "teacher_ids": [teacher_id],
            "month": month,
            "basic_pay": 70000.0,
            "allowances": 15000.0,
            "deductions": 5000.0,
            "net_pay": 80000.0,
            "status": status,
            "remarks": f"Payslip for the month of {month}"
        })
    print("  [OK] Payslips for 6 months created.")

    # 18. Live Classes
    print("\n🔴 Seeding live classes...")
    # Past
    requests.post(f"{BASE_URL}/api/admin/teachers/live-classes", headers=TA, json={
        "subject_id": subject_ids.get(("Mathematics", "10A")),
        "title": "Calculus In-Depth Discussion",
        "scheduled_at": (datetime.now() - timedelta(hours=3)).isoformat(),
        "duration_minutes": 60,
        "target_class": "10A",
        "status": "completed"
    })
    # Live now
    requests.post(f"{BASE_URL}/api/admin/teachers/live-classes", headers=TA, json={
        "subject_id": subject_ids.get(("Physics", "10A")),
        "title": "Electromagnetic Waves Live Demonstration",
        "scheduled_at": datetime.now().isoformat(),
        "duration_minutes": 90,
        "target_class": "10A",
        "status": "live"
    })
    # Upcoming
    requests.post(f"{BASE_URL}/api/admin/teachers/live-classes", headers=TA, json={
        "subject_id": subject_ids.get(("Chemistry", "10A")),
        "title": "Relativity Intro",
        "scheduled_at": (datetime.now() + timedelta(days=2)).isoformat(),
        "duration_minutes": 45,
        "target_class": "10A",
        "status": "scheduled"
    })
    print("  [OK] Live classes (completed, active, upcoming) scheduled.")

    # 19. Study Materials
    print("\n📖 Seeding study materials...")
    mats = [
        ("Mathematics", "Calculus Notes", "Handwritten formulas and sample proofs."),
        ("Physics", "Induced Current Lab Guide", "Procedure sheet for induction experiments."),
        ("Chemistry", "Periodic Table Trends", "Brief guide detailing periodic table properties.")
    ]
    for sub, title, desc in mats:
        requests.post(f"{BASE_URL}/api/admin/teachers/materials", headers=TA, json={
            "title": title,
            "description": desc,
            "material_type": "Notes",
            "target_class": "10A"
        })
    print("  [OK] Study materials published.")

    # 20. Grading Config
    print("\n⚙️ Seeding grading config...")
    for cls in ["10A", "10B", "11A"]:
        requests.post(f"{BASE_URL}/api/admin/teachers/grading-config", headers=TA, json={
            "class_name": cls,
            "gpa_scale": 4.0,
            "calculation_method": "weighted"
        })
    print("  [OK] Grading configuration applied.")

    # 21. Notices & Events
    print("\n📢 Seeding notices and events...")
    # Notices
    requests.post(f"{BASE_URL}/api/admin/students/notices", headers=SA, json={
        "title": "Urgent Notice: Annual Science Fair Registration",
        "content": "Register your science project teams by next Friday. Mandatory for science streams.",
        "category": "Academic",
        "is_urgent": True,
        "target_classes": ["10A"]
    })
    requests.post(f"{BASE_URL}/api/admin/students/notices", headers=SA, json={
        "title": "Notice: Summer Vacation Dates",
        "content": "Summer vacation starts on June 1st and classes resume on July 1st.",
        "category": "General",
        "is_urgent": False,
        "target_classes": ["10A", "10B", "11A"]
    })
    # Events
    requests.post(f"{BASE_URL}/api/admin/students/events", headers=SA, json={
        "title": "Inter-School Code Hackathon",
        "description": "24-hour coding challenge at auditorium labs.",
        "event_date": (datetime.now() + timedelta(days=12)).date().isoformat(),
        "venue": "Computer Science Lab 3",
        "is_mandatory": False
    })
    requests.post(f"{BASE_URL}/api/admin/students/events", headers=SA, json={
        "title": "Parent Teacher PTM Meeting",
        "description": "Collect feedback on Term 1 offline exams.",
        "event_date": (datetime.now() - timedelta(days=2)).date().isoformat(),
        "venue": "Main School Auditorium",
        "is_mandatory": True
    })
    print("  [OK] Notices and events posted.")

    # 22. Leave Applications
    print("\n✉️ Seeding student & teacher leave applications...")
    # Approved Student Leave
    requests.post(f"{BASE_URL}/api/student/leave/apply", headers=S, json={
        "leave_type": "Sick Leave",
        "start_date": (datetime.now() - timedelta(days=8)).date().isoformat(),
        "end_date": (datetime.now() - timedelta(days=7)).date().isoformat(),
        "reason": "Recovering from severe fever."
    })
    # Fetch student leaves and approve
    leaves_res = requests.get(f"{BASE_URL}/api/admin/students/leave", headers=SA).json().get("data", {}).get("applications", [])
    student_leave = next((l for l in leaves_res if l["applicant_id"] == student_id), None)
    if student_leave:
        requests.put(f"{BASE_URL}/api/admin/students/leave/{student_leave['id']}/approve", headers=SA)
        print("  [OK] Student Sick Leave approved.")

    # Pending Student Leave
    requests.post(f"{BASE_URL}/api/student/leave/apply", headers=S, json={
        "leave_type": "Casual Leave",
        "start_date": (datetime.now() + timedelta(days=15)).date().isoformat(),
        "end_date": (datetime.now() + timedelta(days=17)).date().isoformat(),
        "reason": "Attending family function."
    })
    print("  [OK] Pending Student Casual Leave submitted.")

    # Pending Teacher Leave
    requests.post(f"{BASE_URL}/api/teacher/leave/apply", headers=T, json={
        "leave_type": "Casual Leave",
        "start_date": (datetime.now() + timedelta(days=20)).date().isoformat(),
        "end_date": (datetime.now() + timedelta(days=21)).date().isoformat(),
        "reason": "Urgent personal work."
    })
    print("  [OK] Pending Teacher Leave submitted.")

    # 23. Direct Messages & Groups
    print("\n💬 Seeding chat messages & community groups...")
    # Direct message
    requests.post(f"{BASE_URL}/api/messages/send", headers=S, json={
        "receiver_id": teacher_id,
        "content": "Good evening ma'am, I have submitted the Calculus homework."
    })
    requests.post(f"{BASE_URL}/api/messages/send", headers=T, json={
        "receiver_id": student_id,
        "content": "Thank you Naresh, I will evaluate and grade it shortly."
    })
    print("  [OK] Seeded direct messages between Naresh and Neha.")

    # Create Group: announcements
    g1_r = requests.post(f"{BASE_URL}/api/groups/create", headers=T, json={
        "name": "EduSHAMIIT Announcements",
        "description": "School announcement board.",
        "is_private": False
    })
    # Create Group: class group
    g2_r = requests.post(f"{BASE_URL}/api/groups/create", headers=T, json={
        "name": "Class 10A Study Group",
        "description": "Official study forum for class 10A.",
        "is_private": False
    })
    if g2_r.status_code == 200:
        group_id = g2_r.json()["data"]["group"]["id"]
        # Add Naresh to group
        requests.post(f"{BASE_URL}/api/groups/{group_id}/members", headers=T, json={
            "member_id": student_id
        })
        # Send group message
        requests.post(f"{BASE_URL}/api/messages/send", headers=T, json={
            "group_id": group_id,
            "content": "Welcome students to the Class 10A study board! Post questions here."
        })
        requests.post(f"{BASE_URL}/api/messages/send", headers=S, json={
            "group_id": group_id,
            "content": "Hello ma'am, thanks for creating this study group."
        })
        print("  [OK] Community groups created and populated.")

    # 24. Shared Settings
    requests.put(f"{BASE_URL}/api/student/settings", headers=S, json={"dark_mode": True, "language": "en"})
    requests.put(f"{BASE_URL}/api/teacher/user/settings", headers=T, json={"dark_mode": False})
    print("\n⚙️ Settings seeded (Student: Dark Mode, Teacher: Light Mode)")

    # 25. Cleanup temp seeder admins
    print("\n🧹 Cleaning up temporary administrative accounts...")
    requests.delete(f"{BASE_URL}/api/auth/user/{TEMP_STUDENT_ADMIN}")
    requests.delete(f"{BASE_URL}/api/auth/user/{TEMP_TEACHER_ADMIN}")
    print("✅ Seeder admins deleted successfully.")

    print("\n🎉 ==========================================================")
    print("🎉   DUMMY DATA SEEDING COMPLETE FOR NARESH & NEHA!")
    print("🎉 ==========================================================\n")


if __name__ == "__main__":
    main()
