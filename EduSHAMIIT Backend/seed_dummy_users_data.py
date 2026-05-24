"""
EduSHAMIIT Seeding Script
=========================
Seeding rich, realistic, and complete dummy data for:
  - Student: naresh.king88898@gmail.com
  - Teacher: nehaupadhyay9119@gmail.com
Using newly created API endpoints (and direct SQL fallbacks where APIs don't exist).
"""

import sys
import requests
import uuid
import subprocess
from datetime import datetime, timedelta

BASE_URL = "http://127.0.0.1:80"

# Target user profiles
STUDENT_EMAIL = "naresh.king88898@gmail.com"
STUDENT_ID = "073cf4b4-7678-4a9d-bca8-a186d4e3bf5e"
STUDENT_CLASS = "10A"
STUDENT_CREDS = {"email": STUDENT_EMAIL, "password": "naresh@1A"}

TEACHER_EMAIL = "nehaupadhyay9119@gmail.com"
TEACHER_ID = "b5128fea-eb06-4322-a9f8-1ca162f266b2"
TEACHER_CREDS = {"email": TEACHER_EMAIL, "password": "naresh@1A"}

SCHOOL_ID = "11111111-1111-1111-1111-111111111111"

def run_sql(sql_cmd):
    cmd = [
        "docker", "exec", "-e", "PGPASSWORD=eduSHAMIIT2026_pg",
        "supabase-db", "psql", "-U", "supabase_admin", "-d", "postgres", "-c", sql_cmd
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    return res

def upload_avatar(user_id, image_path=None):
    print(f"📷 Seeding avatar image for user {user_id}...")
    try:
        if image_path is None:
            # Query role and gender dynamically from DB to choose correct avatar
            res = run_sql(f"SELECT role, gender FROM profiles WHERE id = '{user_id}';")
            role = "student"
            gender = "Male"
            if res.stdout:
                out = res.stdout.lower()
                if "teacher" in out:
                    role = "teacher"
                if "female" in out:
                    gender = "Female"
            
            if role == "student":
                image_path = "assets/boy_student.png" if gender == "Male" else "assets/girl_student.png"
            else:
                image_path = "assets/male_teacher.png" if gender == "Male" else "assets/female_teacher.png"
                
            print(f"  -> Dynamically resolved profile: role={role}, gender={gender} -> asset={image_path}")

        env_vars = {}
        with open("../.env", "r", encoding="utf-8") as f:
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
            run_sql(f"UPDATE profiles SET avatar_url = '{public_url}' WHERE id = '{user_id}';")
            print(f"  [OK] Profile avatar uploaded and mapped for {user_id}")
        else:
            print(f"  [FAIL] Avatar upload failed: {r.status_code} - {r.text}")
    except Exception as e:
        print(f"  [FAIL] Avatar upload exception: {str(e)}")

def clean_existing_data():
    print("🧹 Cleaning existing dummy/seeded data...")
    sqls = [
        f"DELETE FROM results WHERE student_id = '{STUDENT_ID}';",
        f"DELETE FROM homework_submissions WHERE student_id = '{STUDENT_ID}';",
        f"DELETE FROM attendance WHERE student_id = '{STUDENT_ID}';",
        f"DELETE FROM fees WHERE student_id = '{STUDENT_ID}';",
        f"DELETE FROM student_transport WHERE student_id = '{STUDENT_ID}';",
        f"DELETE FROM student_achievements WHERE student_id = '{STUDENT_ID}';",
        f"DELETE FROM library_borrows WHERE student_id = '{STUDENT_ID}';",
        f"DELETE FROM leave_applications WHERE applicant_id IN ('{STUDENT_ID}', '{TEACHER_ID}');",
        f"DELETE FROM salary WHERE teacher_id = '{TEACHER_ID}';",
        f"DELETE FROM timetable WHERE class = '{STUDENT_CLASS}' OR teacher_id = '{TEACHER_ID}';",
        f"DELETE FROM courses WHERE subject_id IN (SELECT id FROM subjects WHERE class = '{STUDENT_CLASS}');",
        f"DELETE FROM exams WHERE subject_id IN (SELECT id FROM subjects WHERE class = '{STUDENT_CLASS}') OR teacher_id = '{TEACHER_ID}';",
        f"DELETE FROM homework WHERE class = '{STUDENT_CLASS}' OR teacher_id = '{TEACHER_ID}';",
        f"DELETE FROM live_classes WHERE target_class = '{STUDENT_CLASS}' OR teacher_id = '{TEACHER_ID}';",
        f"DELETE FROM study_materials WHERE target_class = '{STUDENT_CLASS}' OR teacher_id = '{TEACHER_ID}';",
        f"DELETE FROM grading_policies WHERE class_name = '{STUDENT_CLASS}' OR teacher_id = '{TEACHER_ID}';",
        f"DELETE FROM subjects WHERE class = '{STUDENT_CLASS}';",
        f"DELETE FROM notices WHERE title LIKE 'Dummy:%' OR title LIKE 'Auto %';",
        f"DELETE FROM events WHERE title LIKE 'Dummy:%' OR title LIKE 'Auto %';",
        f"DELETE FROM notifications WHERE user_id IN ('{STUDENT_ID}', '{TEACHER_ID}');"
    ]
    for sql in sqls:
        run_sql(sql)
    print("✅ Cleanup complete.")

def main():
    # 1. Database Cleanup
    clean_existing_data()

    # 2. Login targeted student & teacher to get their tokens
    print("\n🔑 Logging in targeted student and teacher...")
    resp = requests.post(f"{BASE_URL}/api/auth/login", json=STUDENT_CREDS)
    if resp.status_code != 200 or not resp.json().get("success"):
        print(f"❌ Student login failed! Code {resp.status_code}: {resp.text}")
        sys.exit(1)
    STUDENT_TOKEN = resp.json()["data"]["token"]
    S = {"Authorization": f"Bearer {STUDENT_TOKEN}"}

    resp = requests.post(f"{BASE_URL}/api/auth/login", json=TEACHER_CREDS)
    if resp.status_code != 200 or not resp.json().get("success"):
        print(f"❌ Teacher login failed! Code {resp.status_code}: {resp.text}")
        sys.exit(1)
    TEACHER_TOKEN = resp.json()["data"]["token"]
    T = {"Authorization": f"Bearer {TEACHER_TOKEN}"}

    # 3. Setup temporary admins and elevate them, then log in
    print("\n🔑 Creating temporary student and teacher admins...")
    sa_email = "temp_seeder_student_admin@gmail.com"
    ta_email = "temp_seeder_teacher_admin@gmail.com"

    # Pre-cleanup in case previous run crashed
    requests.delete(f"{BASE_URL}/api/auth/user/{sa_email}")
    requests.delete(f"{BASE_URL}/api/auth/user/{ta_email}")

    # Register student admin
    sa_reg = requests.post(f"{BASE_URL}/api/auth/register", json={
        "email": sa_email, "password": "TempPassword1A", "school_id": SCHOOL_ID,
        "full_name": "Seeder Student Admin", "role": "student", "class_name": STUDENT_CLASS
    })
    if sa_reg.status_code != 200:
        print(f"❌ Student Admin registration failed: {sa_reg.text}")
        sys.exit(1)
    run_sql(f"UPDATE profiles SET role = 'student_admin' WHERE email = '{sa_email}';")

    # Register teacher admin
    ta_reg = requests.post(f"{BASE_URL}/api/auth/register", json={
        "email": ta_email, "password": "TempPassword1A", "school_id": SCHOOL_ID,
        "full_name": "Seeder Teacher Admin", "role": "teacher", "class_name": STUDENT_CLASS
    })
    if ta_reg.status_code != 200:
        print(f"❌ Teacher Admin registration failed: {ta_reg.text}")
        sys.exit(1)
    run_sql(f"UPDATE profiles SET role = 'teacher_admin' WHERE email = '{ta_email}';")

    # Login admins
    resp_sa = requests.post(f"{BASE_URL}/api/auth/login", json={"email": sa_email, "password": "TempPassword1A"})
    SA_TOKEN = resp_sa.json()["data"]["token"]
    SA = {"Authorization": f"Bearer {SA_TOKEN}"}

    resp_ta = requests.post(f"{BASE_URL}/api/auth/login", json={"email": ta_email, "password": "TempPassword1A"})
    TA_TOKEN = resp_ta.json()["data"]["token"]
    TA = {"Authorization": f"Bearer {TA_TOKEN}"}

    print("✅ Admins created and authenticated successfully.")

    # 4. Create Subjects
    print("\n📚 Creating subjects for classes 10A, 10B, and 11A...")
    subjects = [
        # Class 10A (Naresh)
        {"name": "Mathematics", "class": STUDENT_CLASS, "icon": "📐", "color": "#4F46E5", "teacher_id": TEACHER_ID},
        {"name": "Physics", "class": STUDENT_CLASS, "icon": "⚡", "color": "#EC4899", "teacher_id": TEACHER_ID},
        {"name": "Chemistry", "class": STUDENT_CLASS, "icon": "🧪", "color": "#10B981", "teacher_id": TEACHER_ID},
        {"name": "English", "class": STUDENT_CLASS, "icon": "📖", "color": "#F59E0B", "teacher_id": TEACHER_ID},
        # Class 10B
        {"name": "Mathematics", "class": "10B", "icon": "📐", "color": "#3B82F6", "teacher_id": TEACHER_ID},
        {"name": "Physics", "class": "10B", "icon": "⚡", "color": "#F43F5E", "teacher_id": TEACHER_ID},
        # Class 11A
        {"name": "Chemistry", "class": "11A", "icon": "🧪", "color": "#06B6D4", "teacher_id": TEACHER_ID}
    ]
    subject_ids = {}
    for sub in subjects:
        r = requests.post(f"{BASE_URL}/api/admin/students/subjects", headers=SA, json=sub)
        if r.status_code == 200:
            subj_id = r.json()["data"]["id"]
            subject_ids[(sub["name"], sub["class"])] = subj_id
            print(f"  [OK] Created subject: {sub['name']} for class {sub['class']} ({subj_id})")
        else:
            print(f"  [FAIL] Subject {sub['name']} for class {sub['class']}: {r.text}")

    # 5. Create Courses
    print("\n🎓 Creating courses...")
    for (name, cls_name), s_id in subject_ids.items():
        course_payload = {
            "subject_id": s_id,
            "title": f"Comprehensive {name} Course for {cls_name}",
            "description": f"Detailed academic course covering the entire {name} curriculum for class {cls_name}.",
            "is_published": True
        }
        r = requests.post(f"{BASE_URL}/api/admin/students/courses", headers=SA, json=course_payload)
        if r.status_code == 200:
            c_id = r.json()["data"]["id"]
            print(f"  [OK] Created course for {name} - {cls_name} ({c_id})")
        else:
            print(f"  [FAIL] Course {name} - {cls_name}: {r.text}")

    # 6. Create Timetable Slots
    print("\n🗓️ Creating timetable slots for multiple classes (10A, 10B, 11A)...")
    # Day mapping: Monday=0, Tuesday=1, Wednesday=2, Thursday=3, Friday=4, Saturday=5
    schedule_plan = [
        # Monday
        {"day": 0, "slots": [
            ("Mathematics", "10A", "08:30", "09:15", "Room 101"),
            ("Physics", "10A", "09:20", "10:05", "Room 101"),
            ("Chemistry", "10A", "10:10", "10:55", "Room 101"),
            ("English", "10A", "11:00", "11:45", "Room 101"),
            ("Mathematics", "10B", "12:00", "12:45", "Room 102"),
            ("Chemistry", "11A", "13:00", "13:45", "Room 201")
        ]},
        # Tuesday
        {"day": 1, "slots": [
            ("Physics", "10A", "08:30", "09:15", "Room 101"),
            ("Chemistry", "10A", "09:20", "10:05", "Room 101"),
            ("Mathematics", "10A", "10:10", "10:55", "Room 101"),
            ("English", "10A", "11:00", "11:45", "Room 101"),
            ("Physics", "10B", "12:00", "12:45", "Room 102")
        ]},
        # Wednesday
        {"day": 2, "slots": [
            ("Chemistry", "10A", "08:30", "09:15", "Room 101"),
            ("Mathematics", "10A", "09:20", "10:05", "Room 101"),
            ("Physics", "10A", "10:10", "10:55", "Room 101"),
            ("English", "10A", "11:00", "11:45", "Room 101"),
            ("Chemistry", "10B", "12:00", "12:45", "Room 102"),
            ("Chemistry", "11A", "13:00", "13:45", "Room 201")
        ]},
        # Thursday
        {"day": 3, "slots": [
            ("English", "10A", "08:30", "09:15", "Room 101"),
            ("Physics", "10A", "09:20", "10:05", "Room 101"),
            ("Chemistry", "10A", "10:10", "10:55", "Room 101"),
            ("Mathematics", "10A", "11:00", "11:45", "Room 101"),
            ("Mathematics", "10B", "12:00", "12:45", "Room 102")
        ]},
        # Friday
        {"day": 4, "slots": [
            ("Mathematics", "10A", "08:30", "09:15", "Room 101"),
            ("Chemistry", "10A", "09:20", "10:05", "Room 101"),
            ("Physics", "10A", "10:10", "10:55", "Room 101"),
            ("English", "10A", "11:00", "11:45", "Room 101"),
            ("Physics", "10B", "12:00", "12:45", "Room 102")
        ]},
        # Saturday
        {"day": 5, "slots": [
            ("Physics", "10A", "08:30", "09:15", "Room 101"),
            ("Mathematics", "10A", "09:20", "10:05", "Room 101"),
            ("English", "10A", "10:10", "10:55", "Room 101"),
            ("Chemistry", "11A", "11:00", "11:45", "Room 201")
        ]}
    ]
    for plan in schedule_plan:
        d = plan["day"]
        for sub_name, cls_name, start, end, room in plan["slots"]:
            s_id = subject_ids.get((sub_name, cls_name))
            if not s_id:
                continue
            payload = {
                "class": cls_name,
                "subject_id": s_id,
                "teacher_id": TEACHER_ID,
                "day_of_week": d,
                "start_time": start,
                "end_time": end,
                "room": room
            }
            r = requests.post(f"{BASE_URL}/api/admin/students/timetable", headers=SA, json=payload)
            if r.status_code != 200:
                print(f"  [FAIL] Slot for {sub_name} - {cls_name} on day {d}: {r.text}")
    print("✅ Timetable slots seeded.")

    # 7. Create Homeworks
    print("\n📝 Creating homeworks...")
    hws = [
        {"subject_name": "Mathematics", "title": "Calculus: Intermediate Limits", "desc": "Solve problems 1-10 on page 42.", "due_days": 3, "max": 20},
        {"subject_name": "Physics", "title": "Electromagnetic Induction Lab", "desc": "Write a lab report analyzing induction phenomena.", "due_days": 5, "max": 100},
        {"subject_name": "Chemistry", "title": "Organic Reactions Mechanism", "desc": "Detail the mechanisms of nucleophilic substitution reactions.", "due_days": 7, "max": 50}
    ]
    math_hw_id = None
    for hw in hws:
        s_id = subject_ids.get((hw["subject_name"], STUDENT_CLASS))
        if not s_id:
            continue
        due = (datetime.now() + timedelta(days=hw["due_days"])).date().isoformat()
        payload = {
            "subject_id": s_id,
            "title": hw["title"],
            "description": hw["desc"],
            "due_date": due,
            "max_marks": hw["max"],
            "target_class": STUDENT_CLASS,
            "teacher_id": TEACHER_ID
        }
        r = requests.post(f"{BASE_URL}/api/admin/teachers/homework", headers=TA, json=payload)
        if r.status_code == 200:
            hw_id = r.json()["data"]["homework_id"]
            print(f"  [OK] Created homework: {hw['title']} ({hw_id})")
            if hw["subject_name"] == "Mathematics":
                math_hw_id = hw_id
        else:
            print(f"  [FAIL] Homework {hw['title']}: {r.text}")

    # 8. Submit homework as student Naresh
    if math_hw_id:
        print("\n📝 Submitting Mathematics homework as student Naresh...")
        r = requests.post(f"{BASE_URL}/api/student/homework/submit", headers=S, json={
            "homework_id": math_hw_id,
            "submission_text": "I solved all the limit equations using L'Hopital's rule where applicable. Please find my detailed steps attached."
        })
        if r.status_code == 200:
            print("  [OK] Homework submitted successfully.")
            
            # Grade the submission as teacher Neha
            # Fetch the submission ID first
            sub_res = requests.get(f"{BASE_URL}/api/teacher/submissions", headers=T)
            submissions = (sub_res.json().get("data") or {}).get("submissions", [])
            pending_sub = next((s for s in submissions if s["homework_id"] == math_hw_id and s["student_id"] == STUDENT_ID), None)
            
            if pending_sub:
                print("📝 Grading the Mathematics submission as teacher Neha...")
                grade_r = requests.post(f"{BASE_URL}/api/teacher/submissions/grade", headers=T, json={
                    "submission_id": pending_sub["id"],
                    "marks": 18.0,
                    "grade": "A",
                    "remarks": "Excellent mathematical rigor and clear derivation steps! Keep it up."
                })
                if grade_r.status_code == 200:
                    print("  [OK] Submission graded successfully.")
                else:
                    print(f"  [FAIL] Grading failed: {grade_r.text}")
            else:
                print("  [WARN] Could not find submission to grade.")
        else:
            print(f"  [FAIL] Submission failed: {r.text}")

    # 9. Mark Attendance (Realistic history: 14 days)
    print("\n📋 Seeding attendance records (overall 86% percentage)...")
    for offset_days in range(1, 15):
        date_str = (datetime.now() - timedelta(days=offset_days)).date().isoformat()
        # Status pattern: 12 present, 1 late, 1 absent
        if offset_days == 4:
            status = "absent"
        elif offset_days == 8:
            status = "late"
        else:
            status = "present"
            
        for (name, cls_name), s_id in subject_ids.items():
            if cls_name != STUDENT_CLASS:
                continue
            payload = {
                "subject_id": s_id,
                "class_name": STUDENT_CLASS,
                "date": date_str,
                "attendance_records": [{"student_id": STUDENT_ID, "status": status}]
            }
            # Use teacher token or admin token to mark attendance
            requests.post(f"{BASE_URL}/api/teacher/attendance/mark", headers=T, json=payload)
    print("✅ Attendance marked for the past 14 days.")

    # 10. Exams & Results
    print("\n✍️ Seeding exams and results...")
    # Math exam (past -> result entered)
    math_exam_date = (datetime.now() - timedelta(days=5)).date().isoformat()
    r = requests.post(f"{BASE_URL}/api/admin/students/exams", headers=SA, json={
        "subject_id": subject_ids.get(("Mathematics", STUDENT_CLASS)),
        "title": "First Term Mathematics Examination",
        "exam_type": "offline",
        "exam_category": "Unit Test",
        "exam_date": math_exam_date,
        "start_time": f"{math_exam_date}T09:00:00",
        "duration_minutes": 120,
        "total_marks": 100,
        "venue": "Hall A",
        "target_classes": [STUDENT_CLASS]
    })
    if r.status_code == 200:
        exam_id = r.json()["data"]["exam_id"]
        print(f"  [OK] Created Mathematics Exam ({exam_id})")
        # Enter Result
        res_r = requests.post(f"{BASE_URL}/api/admin/students/results", headers=SA, json={
            "student_id": STUDENT_ID,
            "subject_id": subject_ids.get(("Mathematics", STUDENT_CLASS)),
            "marks_obtained": 92.0,
            "total_marks": 100.0,
            "remarks": "Outstanding performance! Showed deep conceptual understanding.",
            "exam_type": "Unit Test"
        })
        if res_r.status_code == 200:
            print("  [OK] Result entered for Mathematics (92/100).")
        else:
            print(f"  [FAIL] Mathematics Result: {res_r.text}")

    # Physics exam (upcoming)
    phys_exam_date = (datetime.now() + timedelta(days=10)).date().isoformat()
    r = requests.post(f"{BASE_URL}/api/admin/students/exams", headers=SA, json={
        "subject_id": subject_ids.get(("Physics", STUDENT_CLASS)),
        "title": "Mid-Term Physics Assessment",
        "exam_type": "offline",
        "exam_category": "Mid Term",
        "exam_date": phys_exam_date,
        "start_time": f"{phys_exam_date}T10:30:00",
        "duration_minutes": 90,
        "total_marks": 50,
        "venue": "Lab 2",
        "target_classes": [STUDENT_CLASS]
    })
    if r.status_code == 200:
        print("  [OK] Created upcoming Physics Exam.")

    # 11. Fees
    print("\n💳 Seeding fees and payments...")
    fees = [
        {"type": "Tuition Fee - Q1", "amount": 5000.0, "due": (datetime.now() - timedelta(days=30)).date().isoformat(), "pay": True},
        {"type": "Transport Fee - Q1", "amount": 1200.0, "due": (datetime.now() - timedelta(days=30)).date().isoformat(), "pay": True},
        {"type": "Laboratory Deposit", "amount": 1500.0, "due": (datetime.now() - timedelta(days=10)).date().isoformat(), "pay": True},
        {"type": "Tuition Fee - Q2", "amount": 5000.0, "due": (datetime.now() + timedelta(days=20)).date().isoformat(), "pay": False}
    ]
    for fee in fees:
        payload = {
            "fee_type": fee["type"],
            "amount": fee["amount"],
            "due_date": fee["due"],
            "target_class": STUDENT_CLASS
        }
        r = requests.post(f"{BASE_URL}/api/admin/students/fees", headers=SA, json=payload)
        if r.status_code == 200:
            # The API might create fee records for all students in the class.
            # Let's find our specific fee record for Naresh
            fees_res = requests.get(f"{BASE_URL}/api/admin/students/fees?student_id={STUDENT_ID}", headers=SA)
            fees_list = (fees_res.json().get("data") or {}).get("fees") or []
            my_fee = next((f for f in fees_list if f["fee_type"] == fee["type"] and f["student_id"] == STUDENT_ID), None)
            if my_fee:
                f_id = my_fee["id"]
                print(f"  [OK] Fee record created: {fee['type']} ({f_id})")
                if fee["pay"]:
                    pay_r = requests.put(f"{BASE_URL}/api/admin/students/fees/{f_id}", headers=SA, json={
                        "status": "paid", "amount_paid": fee["amount"]
                    })
                    if pay_r.status_code == 200:
                        print(f"    [PAID] Fee {fee['type']} marked as paid.")
            else:
                # If class creation didn't auto-bind, create a specific one
                # Note: /api/admin/students/fees creates for all students in class, so it should exist
                pass
        else:
            print(f"  [FAIL] Fee {fee['type']}: {r.text}")

    # 12. Transport
    print("\n🚌 Seeding bus route, stops, and assignment...")
    route_payload = {
        "route_name": "Route 10 - North Express Line",
        "bus_number": "DL-1PC-8898",
        "driver_name": "Sukhwinder Singh",
        "driver_phone": "9812345670",
        "total_capacity": 40
    }
    r = requests.post(f"{BASE_URL}/api/admin/students/transport/routes", headers=SA, json=route_payload)
    if r.status_code == 200:
        r_id = r.json()["data"]["id"]
        print(f"  [OK] Created transport route: {route_payload['route_name']} ({r_id})")
        
        # Insert bus stop and telemetry via SQL directly
        stop_id = str(uuid.uuid4())
        run_sql(f"INSERT INTO bus_stops (id, school_id, route_id, stop_name, latitude, longitude, stop_order, estimated_arrival) VALUES ('{stop_id}', '{SCHOOL_ID}', '{r_id}', 'Greenwood Apartments Gate', 28.6139, 77.2090, 1, '07:40:00');")
        run_sql(f"INSERT INTO bus_locations (id, school_id, route_id, latitude, longitude, speed, recorded_at) VALUES ('{str(uuid.uuid4())}', '{SCHOOL_ID}', '{r_id}', 28.6139, 77.2090, 35.5, NOW());")
        
        # Assign transport to Naresh
        assign_r = requests.post(f"{BASE_URL}/api/admin/students/transport/assign", headers=SA, json={
            "student_id": STUDENT_ID,
            "route_id": r_id,
            "stop_id": stop_id
        })
        if assign_r.status_code == 200:
            print("  [OK] Transport route & stop successfully assigned to student Naresh.")
        else:
            print(f"  [FAIL] Assignment: {assign_r.text}")
    else:
        print(f"  [FAIL] Route: {r.text}")

    # 13. Library Book and Borrow
    print("\n📚 Seeding library catalog and borrow...")
    book_r = requests.post(f"{BASE_URL}/api/admin/students/library/books", headers=SA, json={
        "title": "A Brief History of Time",
        "author": "Stephen Hawking",
        "isbn": "978-0553380163",
        "category": "Cosmology",
        "total_copies": 3
    })
    if book_r.status_code == 200:
        b_id = book_r.json()["data"]["id"]
        print(f"  [OK] Library book added: {book_r.json()['data']['title']} ({b_id})")
        
        # Issue book to Naresh
        due = (datetime.now() + timedelta(days=14)).date().isoformat()
        borrow_r = requests.post(f"{BASE_URL}/api/admin/students/library/borrows", headers=SA, json={
            "student_id": STUDENT_ID,
            "book_id": b_id,
            "due_date": due
        })
        if borrow_r.status_code == 200:
            print("  [OK] Book issued to Naresh successfully.")
        else:
            print(f"  [FAIL] Borrow: {borrow_r.text}")
    else:
        print(f"  [FAIL] Book addition: {book_r.text}")

    # 14. Achievements & Leaderboard gamification
    print("\n🏆 Seeding achievements & leaderboard stats...")
    ach_r = requests.post(f"{BASE_URL}/api/admin/students/achievements", headers=SA, json={
        "name": "Science Prodigy",
        "description": "Scored over 90% in multiple STEM subjects",
        "icon": "🧬",
        "rarity": "rare",
        "xp_reward": 500
    })
    if ach_r.status_code == 200:
        ach_id = ach_r.json()["data"]["id"]
        print(f"  [OK] Achievement created: Science Prodigy ({ach_id})")
        
        # Award to Naresh
        award_r = requests.post(f"{BASE_URL}/api/admin/students/achievements/award", headers=SA, json={
            "achievement_id": ach_id,
            "student_ids": [STUDENT_ID]
        })
        if award_r.status_code == 200:
            print("  [OK] Achievement awarded to Naresh successfully.")
            
            # Boost profile stats directly to place Naresh at the top of class leaderboard
            run_sql(f"UPDATE profiles SET xp_points = 2450, learning_streak = 18, best_streak = 25, roll_number = 7, session = '2025-2026', admission_number = 'ADM-10-2025' WHERE id = '{STUDENT_ID}';")
            print("  [OK] Leaderboard XP and streaks boosted in profiles database.")
            
            # Seed profile avatars
            upload_avatar(STUDENT_ID)
            upload_avatar(TEACHER_ID)
        else:
            print(f"  [FAIL] Award: {award_r.text}")
    else:
        print(f"  [FAIL] Achievement: {ach_r.text}")

    # 15. Teacher salary payslips
    print("\n💵 Seeding teacher payslips (Neha)...")
    payslips = [
        {"month": "2026-03", "basic": 70000.0, "allow": 15000.0, "deduct": 5000.0, "net": 80000.0, "status": "paid"},
        {"month": "2026-04", "basic": 70000.0, "allow": 15000.0, "deduct": 5000.0, "net": 80000.0, "status": "paid"},
        {"month": "2026-05", "basic": 70000.0, "allow": 15000.0, "deduct": 5000.0, "net": 80000.0, "status": "paid"}
    ]
    for slip in payslips:
        # Note: the endpoint is POST /api/admin/teachers/salary which bulk-creates payslips for teacher_ids
        payload = {
            "teacher_ids": [TEACHER_ID],
            "month": slip["month"],
            "basic_pay": slip["basic"],
            "allowances": slip["allow"],
            "deductions": slip["deduct"],
            "net_pay": slip["net"],
            "status": slip["status"],
            "remarks": f"Payslip for the month of {slip['month']}"
        }
        r = requests.post(f"{BASE_URL}/api/admin/teachers/salary", headers=TA, json=payload)
        if r.status_code == 200:
            print(f"  [OK] Payslip for {slip['month']} created successfully.")
        else:
            print(f"  [FAIL] Payslip {slip['month']}: {r.text}")

    # 16. Live classes
    print("\n🔴 Seeding live classes scheduled for class 10A...")
    live_scheds = [
        {"title": "Limits & Derivatives In-Depth", "sub": "Mathematics", "min": 45, "offset_hours": 1},
        {"title": "Electromagnetic Waves and Induction Discussion", "sub": "Physics", "min": 60, "offset_hours": 24}
    ]
    for ls in live_scheds:
        s_id = subject_ids.get(ls["sub"])
        if not s_id:
            continue
        start_t = (datetime.now() + timedelta(hours=ls["offset_hours"])).isoformat()
        payload = {
            "subject_id": s_id,
            "title": ls["title"],
            "scheduled_at": start_t,
            "duration_minutes": ls["min"],
            "target_class": STUDENT_CLASS,
            "teacher_id": TEACHER_ID
        }
        # Mark the first one live directly via start endpoint
        if ls["offset_hours"] == 1:
            r = requests.post(f"{BASE_URL}/api/teacher/live-classes/start", headers=T, json=payload)
        else:
            # Or use admin to schedule
            r = requests.post(f"{BASE_URL}/api/admin/teachers/live-classes", headers=TA, json=payload)
            
        if r.status_code == 200:
            print(f"  [OK] Live class seeded: {ls['title']}")
        else:
            print(f"  [FAIL] Live class: {r.text}")

    # 17. Shared Notices & Events
    print("\n📢 Seeding student notices & academic events...")
    notices_data = [
        {"title": "Dummy: Annual Science Fair 2026 Registration Open", "content": "All students of class 10A are requested to register their science models before May 30th. Exciting awards to be won!"},
        {"title": "Dummy: Summer Vacation Announcement", "content": "The school will remain closed for summer vacation from June 1st to June 30th. Homework projects have been uploaded."}
    ]
    for notice in notices_data:
        r = requests.post(f"{BASE_URL}/api/admin/students/notices", headers=SA, json={
            "title": notice["title"],
            "content": notice["content"],
            "category": "Academic",
            "is_urgent": False,
            "target_classes": [STUDENT_CLASS],
            "target_student_ids": [STUDENT_ID]
        })
        if r.status_code == 200:
            print(f"  [OK] Notice posted: {notice['title']}")
        else:
            print(f"  [FAIL] Notice: {r.text}")

    events_data = [
        {"title": "Dummy: Parent-Teacher Meeting (PTM)", "desc": "PTM scheduled to discuss the First Term performance and feedback.", "date_offset": 3, "venue": "Main School Auditorium"},
        {"title": "Dummy: Inter-School Coding Hackathon", "desc": "Coding hackathon open for classes 9-12. Registration is free.", "date_offset": 12, "venue": "Computer Science Lab 3"}
    ]
    for ev in events_data:
        ev_date = (datetime.now() + timedelta(days=ev["date_offset"])).date().isoformat()
        r = requests.post(f"{BASE_URL}/api/admin/students/events", headers=SA, json={
            "title": ev["title"],
            "description": ev["desc"],
            "event_date": ev_date,
            "start_time": f"{ev_date}T10:00:00",
            "venue": ev["venue"]
        })
        if r.status_code == 200:
            print(f"  [OK] Event posted: {ev['title']}")
        else:
            print(f"  [FAIL] Event: {r.text}")

    # 18. Shared User Settings
    print("\n⚙️ Seeding user settings...")
    requests.put(f"{BASE_URL}/api/student/settings", headers=S, json={"dark_mode": True, "language": "en"})
    requests.put(f"{BASE_URL}/api/teacher/user/settings", headers=T, json={"dark_mode": False})
    print("  [OK] Student set to Dark Mode, Teacher set to Light Mode.")

    # 19. Cleanup Temp Seeder Admins
    print("\n🧹 Cleaning up temporary administrative accounts...")
    requests.delete(f"{BASE_URL}/api/auth/user/{sa_email}")
    requests.delete(f"{BASE_URL}/api/auth/user/{ta_email}")
    print("✅ Cleanup finished.")

    print("\n🎉 ==========================================================")
    print("🎉   DUMMY DATA SEEDING COMPLETE FOR NARESH & NEHA!")
    print("🎉 ==========================================================\n")

if __name__ == "__main__":
    main()
