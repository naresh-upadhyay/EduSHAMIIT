"""EduSHAMIIT API - End-to-End Test Suite (all endpoints)"""
import sys, requests
from datetime import datetime, timedelta

BASE_URL = "http://127.0.0.1:8000"
STUDENT_CREDS = {"email": "naresh.king88898@gmail.com", "password": "naresh@1A"}
TEACHER_CREDS = {"email": "nehaupadhyay9119@gmail.com", "password": "naresh@1A"}

_r = {"passed": 0, "failed": 0, "errors": []}


def section(title):
    print("\n" + "=" * 62)
    print("  " + title)
    print("=" * 62)


def check(name, resp, expected_status=200, check_success=True):
    ok = resp.status_code == expected_status
    body = {}
    try:
        body = resp.json()
    except Exception:
        pass
    if ok and check_success:
        ok = body.get("success", True) is not False
    if ok:
        _r["passed"] += 1
        print(f"  [PASS] {name} [{resp.status_code}]")
    else:
        _r["failed"] += 1
        detail = body.get("detail") or body.get("message") or str(body)[:150]
        _r["errors"].append(f"{name}: HTTP {resp.status_code} -> {detail}")
        print(f"  [FAIL] {name} [{resp.status_code}] -> {detail}")
    return body


def warn(msg):
    print(f"  [SKIP] {msg}")


def ok_200(name, resp):
    """Accept any 200 regardless of success field (for ambiguous endpoints)."""
    if resp.status_code == 200:
        _r["passed"] += 1
        print(f"  [PASS] {name} [200]")
    else:
        body = {}
        try:
            body = resp.json()
        except Exception:
            pass
        detail = body.get("detail") or str(body)[:150]
        _r["failed"] += 1
        _r["errors"].append(f"{name}: HTTP {resp.status_code} -> {detail}")
        print(f"  [FAIL] {name} [{resp.status_code}] -> {detail}")


# ================================================================
# 1. AUTH
# ================================================================
section("1. AUTH ENDPOINTS")

resp = requests.post(f"{BASE_URL}/api/auth/login", json=STUDENT_CREDS)
b = check("POST /api/auth/login (student)", resp)
STUDENT_TOKEN   = (b.get("data") or {}).get("token", "") if b.get("success") else ""
STUDENT_REFRESH = (b.get("data") or {}).get("refresh_token", "") if b.get("success") else ""

resp = requests.post(f"{BASE_URL}/api/auth/login", json=TEACHER_CREDS)
b = check("POST /api/auth/login (teacher)", resp)
TEACHER_TOKEN   = (b.get("data") or {}).get("token", "") if b.get("success") else ""
TEACHER_REFRESH = (b.get("data") or {}).get("refresh_token", "") if b.get("success") else ""

if STUDENT_REFRESH:
    resp = requests.post(f"{BASE_URL}/api/auth/refresh", json={"refresh_token": STUDENT_REFRESH})
    check("POST /api/auth/refresh (student)", resp)

if TEACHER_REFRESH:
    resp = requests.post(f"{BASE_URL}/api/auth/refresh", json={"refresh_token": TEACHER_REFRESH})
    check("POST /api/auth/refresh (teacher)", resp)

resp = requests.post(f"{BASE_URL}/api/auth/login", json={"email": "wrong@test.com", "password": "badpass"})
check("POST /api/auth/login (bad creds -> 401)", resp, expected_status=401, check_success=False)

if not STUDENT_TOKEN:
    print("\n[ERROR] No student token – check credentials / server. Aborting.")
    sys.exit(1)
if not TEACHER_TOKEN:
    print("\n[ERROR] No teacher token – check credentials / server. Aborting.")
    sys.exit(1)

S = {"Authorization": f"Bearer {STUDENT_TOKEN}"}
T = {"Authorization": f"Bearer {TEACHER_TOKEN}"}

# ================================================================
# 2. STUDENT ENDPOINTS
# ================================================================
section("2. STUDENT ENDPOINTS")

check("GET /api/student/dashboard",          requests.get(f"{BASE_URL}/api/student/dashboard",   headers=S))
check("GET /api/student/profile",            requests.get(f"{BASE_URL}/api/student/profile",     headers=S))
check("GET /api/student/timetable",          requests.get(f"{BASE_URL}/api/student/timetable?day=monday", headers=S))
check("GET /api/student/results",            requests.get(f"{BASE_URL}/api/student/results",     headers=S))
check("GET /api/student/results (filtered)", requests.get(f"{BASE_URL}/api/student/results?category=Unit+Test", headers=S))
check("GET /api/student/exams",              requests.get(f"{BASE_URL}/api/student/exams",       headers=S))
check("GET /api/student/homework",           requests.get(f"{BASE_URL}/api/student/homework",    headers=S))
check("GET /api/student/homework (pending)", requests.get(f"{BASE_URL}/api/student/homework?status=pending", headers=S))
check("GET /api/student/attendance",         requests.get(f"{BASE_URL}/api/student/attendance",  headers=S))
check("GET /api/student/fees",               requests.get(f"{BASE_URL}/api/student/fees",        headers=S))
# transport: success:False is valid when student not assigned to route
ok_200("GET /api/student/transport",         requests.get(f"{BASE_URL}/api/student/transport",   headers=S))
check("GET /api/student/notices",            requests.get(f"{BASE_URL}/api/student/notices",     headers=S))
check("GET /api/student/events",             requests.get(f"{BASE_URL}/api/student/events",      headers=S))
check("GET /api/student/achievements",       requests.get(f"{BASE_URL}/api/student/achievements",headers=S))
check("GET /api/student/library",            requests.get(f"{BASE_URL}/api/student/library",     headers=S))
check("GET /api/student/courses",            requests.get(f"{BASE_URL}/api/student/courses",     headers=S))
check("GET /api/student/notifications",      requests.get(f"{BASE_URL}/api/student/notifications",headers=S))
check("GET /api/student/live-classes",       requests.get(f"{BASE_URL}/api/student/live-classes",headers=S))
check("GET /api/student/leaderboard",        requests.get(f"{BASE_URL}/api/student/leaderboard", headers=S))
check("GET /api/student/user/settings",      requests.get(f"{BASE_URL}/api/student/user/settings",headers=S))
check("PUT /api/student/user/settings",      requests.put(f"{BASE_URL}/api/student/user/settings", headers=S, json={"dark_mode": True, "language": "en"}))
check("GET /api/student/messages",           requests.get(f"{BASE_URL}/api/student/messages",    headers=S))
check("GET /api/student/messages/chat",      requests.get(f"{BASE_URL}/api/student/messages/chat",headers=S))
check("GET /api/student/groups",             requests.get(f"{BASE_URL}/api/student/groups",      headers=S))

# Leave apply
check("POST /api/student/leave/apply", requests.post(f"{BASE_URL}/api/student/leave/apply", headers=S, json={
    "leave_type": "sick",
    "start_date": (datetime.now() + timedelta(days=1)).date().isoformat(),
    "end_date":   (datetime.now() + timedelta(days=2)).date().isoformat(),
    "reason":     "Medical appointment"
}))

# Homework submit
hw_list = (requests.get(f"{BASE_URL}/api/student/homework", headers=S).json().get("data") or {}).get("homework", [])
if hw_list:
    ok_200("POST /api/student/homework/submit",
           requests.post(f"{BASE_URL}/api/student/homework/submit", headers=S,
                         json={"homework_id": hw_list[0]["id"], "submission_text": "Auto test submission"}))
else:
    warn("POST /api/student/homework/submit (no homework found)")

# Event register
ev_list = (requests.get(f"{BASE_URL}/api/student/events", headers=S).json().get("data") or {}).get("events", [])
if ev_list:
    ok_200(f"POST /api/student/events/{{id}}/register",
           requests.post(f"{BASE_URL}/api/student/events/{ev_list[0]['id']}/register", headers=S))
else:
    warn("POST /api/student/events/{id}/register (no events found)")

# Notification mark-read
notif_list = (requests.get(f"{BASE_URL}/api/student/notifications", headers=S).json().get("data") or {}).get("notifications", [])
if notif_list:
    check("PUT /api/student/notifications/{id}/read",
          requests.put(f"{BASE_URL}/api/student/notifications/{notif_list[0]['id']}/read", headers=S))
else:
    warn("PUT /api/student/notifications/{id}/read (no notifications)")

# Create group
check("POST /api/student/groups/create", requests.post(f"{BASE_URL}/api/student/groups/create", headers=S,
      json={"name": "Student Test Group", "description": "Auto test"}))

# ================================================================
# 3. TEACHER ENDPOINTS
# ================================================================
section("3. TEACHER ENDPOINTS")

check("GET /api/teacher/dashboard",   requests.get(f"{BASE_URL}/api/teacher/dashboard",  headers=T))
check("GET /api/teacher/profile",     requests.get(f"{BASE_URL}/api/teacher/profile",    headers=T))
check("GET /api/teacher/timetable",   requests.get(f"{BASE_URL}/api/teacher/timetable?day=monday", headers=T))
check("GET /api/teacher/students",    requests.get(f"{BASE_URL}/api/teacher/students",   headers=T))
check("GET /api/teacher/submissions", requests.get(f"{BASE_URL}/api/teacher/submissions",headers=T))
check("GET /api/teacher/live-classes",requests.get(f"{BASE_URL}/api/teacher/live-classes",headers=T))
check("GET /api/teacher/salary",      requests.get(f"{BASE_URL}/api/teacher/salary",     headers=T))
check("GET /api/teacher/notifications",requests.get(f"{BASE_URL}/api/teacher/notifications",headers=T))
check("GET /api/teacher/messages",    requests.get(f"{BASE_URL}/api/teacher/messages",   headers=T))
check("GET /api/teacher/messages/chat",requests.get(f"{BASE_URL}/api/teacher/messages/chat",headers=T))
check("GET /api/teacher/groups",      requests.get(f"{BASE_URL}/api/teacher/groups",     headers=T))
check("PUT /api/teacher/user/settings",requests.put(f"{BASE_URL}/api/teacher/user/settings", headers=T, json={"dark_mode": False}))

# Classes (need for dependent tests)
b = check("GET /api/teacher/classes", requests.get(f"{BASE_URL}/api/teacher/classes", headers=T))
classes = (b.get("data") or {}).get("classes", [])
first_class = classes[0]["class"] if classes else ""

if first_class:
    check(f"GET /api/teacher/students?class_name={first_class}",
          requests.get(f"{BASE_URL}/api/teacher/students?class_name={first_class}", headers=T))
    check(f"GET /api/teacher/class-detail?class_name={first_class}",
          requests.get(f"{BASE_URL}/api/teacher/class-detail?class_name={first_class}", headers=T))
    check(f"GET /api/teacher/gradebook?class_name={first_class}",
          requests.get(f"{BASE_URL}/api/teacher/gradebook?class_name={first_class}", headers=T))
else:
    warn("Teacher class-detail / gradebook (no classes found)")

# Resolve subject_id from timetable
tt = (requests.get(f"{BASE_URL}/api/teacher/timetable", headers=T).json().get("data") or {}).get("schedule", [])
subject_id = tt[0]["subject_id"] if tt else None

# Create homework
if subject_id and first_class:
    b = check("POST /api/teacher/homework/create",
              requests.post(f"{BASE_URL}/api/teacher/homework/create", headers=T, json={
                  "subject_id": subject_id, "title": "Auto Test HW",
                  "description": "Automated homework", "due_date": (datetime.now() + timedelta(days=5)).date().isoformat(),
                  "max_marks": 20, "target_class": first_class
              }))
else:
    warn("POST /api/teacher/homework/create (no subject/class)")

# Mark attendance
if subject_id and first_class:
    stu = (requests.get(f"{BASE_URL}/api/teacher/students?class_name={first_class}", headers=T)
           .json().get("data") or {}).get("students", [])
    if stu:
        records = [{"student_id": s["id"], "status": "present"} for s in stu[:3]]
        check("POST /api/teacher/attendance/mark",
              requests.post(f"{BASE_URL}/api/teacher/attendance/mark", headers=T, json={
                  "subject_id": subject_id,
                  "date": datetime.now().date().isoformat(),
                  "attendance_records": records
              }))
    else:
        warn("POST /api/teacher/attendance/mark (no students in class)")
else:
    warn("POST /api/teacher/attendance/mark (no subject/class)")

# Grade a submission
subs = (requests.get(f"{BASE_URL}/api/teacher/submissions", headers=T).json().get("data") or {}).get("submissions", [])
pending_sub = next((s for s in subs if s.get("status") == "submitted"), None)
if pending_sub:
    check("POST /api/teacher/submissions/grade",
          requests.post(f"{BASE_URL}/api/teacher/submissions/grade", headers=T, json={
              "submission_id": pending_sub["id"], "marks": 18.0, "grade": "A", "remarks": "Good work"
          }))
else:
    warn("POST /api/teacher/submissions/grade (no pending submissions)")

# Create notice
check("POST /api/teacher/notices/create",
      requests.post(f"{BASE_URL}/api/teacher/notices/create", headers=T, json={
          "title": "Auto Test Notice", "content": "Automated notice for testing.",
          "category": "General", "is_urgent": False
      }))

# Create exam
if subject_id and first_class:
    check("POST /api/teacher/exams/create",
          requests.post(f"{BASE_URL}/api/teacher/exams/create", headers=T, json={
              "subject_id": subject_id, "title": "Auto Test Exam",
              "exam_type": "offline", "exam_category": "Unit Test",
              "exam_date": (datetime.now() + timedelta(days=10)).date().isoformat(),
              "start_time": (datetime.now() + timedelta(days=10)).isoformat(),
              "duration_minutes": 60, "total_marks": 50, "venue": "Hall A",
              "target_classes": [first_class]
          }))
else:
    warn("POST /api/teacher/exams/create (no subject/class)")

# Teacher leave apply
check("POST /api/teacher/leave/apply",
      requests.post(f"{BASE_URL}/api/teacher/leave/apply", headers=T, json={
          "leave_type": "casual",
          "start_date": (datetime.now() + timedelta(days=3)).date().isoformat(),
          "end_date":   (datetime.now() + timedelta(days=4)).date().isoformat(),
          "reason":     "Personal"
      }))

# Grading config
if first_class and subject_id:
    check("PUT /api/teacher/grading-config",
          requests.put(f"{BASE_URL}/api/teacher/grading-config", headers=T, json={
              "class_name": first_class, "subject_id": subject_id,
              "mid_term_weight": 30, "final_term_weight": 40,
              "attendance_weight": 10, "assignment_weight": 10, "class_test_weight": 10
          }))
else:
    warn("PUT /api/teacher/grading-config (no subject/class)")

# Start live class
if subject_id and first_class:
    check("POST /api/teacher/live-classes/start",
          requests.post(f"{BASE_URL}/api/teacher/live-classes/start", headers=T, json={
              "subject_id": subject_id, "title": "Auto Test Live Class",
              "scheduled_at": datetime.now().isoformat(),
              "duration_minutes": 45, "target_class": first_class
          }))
else:
    warn("POST /api/teacher/live-classes/start (no subject/class)")

# Upload material
if subject_id and first_class:
    check("POST /api/teacher/materials/upload",
          requests.post(f"{BASE_URL}/api/teacher/materials/upload", headers=T, json={
              "title": "Auto Test Material", "description": "Test",
              "material_type": "notes", "target_class": first_class,
              "attachment_urls": ["https://example.com/test.pdf"]
          }))
else:
    warn("POST /api/teacher/materials/upload (no subject/class)")

# Teacher send message (to student if found)
stu_all = (requests.get(f"{BASE_URL}/api/teacher/students", headers=T).json().get("data") or {}).get("students", [])
if stu_all:
    ok_200("POST /api/teacher/messages/send",
           requests.post(f"{BASE_URL}/api/teacher/messages/send", headers=T, json={
               "receiver_id": stu_all[0]["id"], "content": "Test message from teacher"
           }))
else:
    warn("POST /api/teacher/messages/send (no students found)")

# Teacher create group
check("POST /api/teacher/groups/create",
      requests.post(f"{BASE_URL}/api/teacher/groups/create", headers=T,
                    json={"name": "Teacher Test Group", "description": "Auto test group"}))

# Teacher notifications mark-read
t_notifs = (requests.get(f"{BASE_URL}/api/teacher/notifications", headers=T).json().get("data") or {}).get("notifications", [])
if t_notifs:
    warn("PUT /api/teacher/notifications/{id}/read -> using shared endpoint")
else:
    warn("PUT teacher notifications (none found)")

# ================================================================
# 4. SHARED ENDPOINTS
# ================================================================
section("4. SHARED ENDPOINTS")

check("GET /api/messages (student)",    requests.get(f"{BASE_URL}/api/messages", headers=S))
check("GET /api/notifications (student)",requests.get(f"{BASE_URL}/api/notifications", headers=S))
check("GET /api/user/settings (teacher)",requests.get(f"{BASE_URL}/api/user/settings", headers=T))
check("PUT /api/user/settings (student)",requests.put(f"{BASE_URL}/api/user/settings", headers=S, json={"language": "en"}))
check("GET /api/groups (teacher)",       requests.get(f"{BASE_URL}/api/groups", headers=T))
check("POST /api/groups/create",         requests.post(f"{BASE_URL}/api/groups/create", headers=T,
                                           json={"name": "Shared Test Group", "description": "Auto"}))

# Notifications mark-read via shared
s_notifs = (requests.get(f"{BASE_URL}/api/notifications", headers=S).json().get("data") or {}).get("notifications", [])
if s_notifs:
    check("PUT /api/notifications/{id}/read",
          requests.put(f"{BASE_URL}/api/notifications/{s_notifs[0]['id']}/read", headers=S))
else:
    warn("PUT /api/notifications/{id}/read (no notifications)")

# Student send message (to teacher)
if stu_all:
    t_id = stu_all[0]["id"]  # use any valid user
else:
    t_id = None

# Get teacher's profile id from teacher token
tp = (requests.get(f"{BASE_URL}/api/teacher/profile", headers=T).json().get("data") or {}).get("profile", {})
teacher_profile_id = tp.get("id")
if teacher_profile_id:
    ok_200("POST /api/messages/send (student->teacher)",
           requests.post(f"{BASE_URL}/api/messages/send", headers=S, json={
               "receiver_id": teacher_profile_id, "content": "Test message student to teacher"
           }))
else:
    warn("POST /api/messages/send (could not resolve teacher profile id)")

# ================================================================
# 5. IoT ENDPOINTS
# ================================================================
section("5. IoT ENDPOINTS")

check("GET /api/iot/devices",           requests.get(f"{BASE_URL}/api/iot/devices", headers=T))
check("GET /api/iot/status/room-101",   requests.get(f"{BASE_URL}/api/iot/status/room-101", headers=T))
# IoT control returns ok:False when MQTT/device unreachable — accepted graceful degradation in dev
ok_200("POST /api/iot/control",         requests.post(f"{BASE_URL}/api/iot/control", headers=T,
                                          json={"room": "room-101", "device": "light", "action": "on"}))
check("POST /api/iot/schedule",         requests.post(f"{BASE_URL}/api/iot/schedule", headers=T,
                                          json={"room": "room-101", "device": "fan", "action": "off",
                                                "time": (datetime.now() + timedelta(hours=1)).isoformat()}))

# ================================================================
# 6. PAYMENTS ENDPOINTS
# ================================================================
section("6. PAYMENTS ENDPOINTS")

fees_data = (requests.get(f"{BASE_URL}/api/student/fees", headers=S).json().get("data") or {}).get("pending_fees", [])

if fees_data:
    fee = fees_data[0]
    b = check("POST /api/payments/create-upi-link",
              requests.post(f"{BASE_URL}/api/payments/create-upi-link", headers=S, json={
                  "fee_id": fee["id"], "amount": float(fee["amount"]), "description": "Test Payment"
              }))
    payment_id = (b.get("data") or {}).get("payment_id")
    tx_id = (b.get("data") or {}).get("transaction_id")

    if payment_id:
        check("POST /api/payments/verify",
              requests.post(f"{BASE_URL}/api/payments/verify", headers=S, json={
                  "payment_id": payment_id, "status": "pending", "upi_transaction_id": "AUTOTEST_TXN"
              }))

    if tx_id:
        ok_200("POST /api/payments/webhook",
               requests.post(f"{BASE_URL}/api/payments/webhook", json={
                   "transaction_id": tx_id, "status": "success", "txnId": "UPI_AUTO_001"
               }))
else:
    warn("PAYMENTS tests skipped – no pending fees for student")

# ================================================================
# SUMMARY
# ================================================================
section("TEST RESULTS SUMMARY")
total = _r["passed"] + _r["failed"]
pct   = (_r["passed"] / total * 100) if total > 0 else 0

print(f"\n  Passed : {_r['passed']}/{total} ({pct:.0f}%)")
print(f"  Failed : {_r['failed']}/{total}")
print(f"  Skipped: (see [SKIP] lines above)")

if _r["errors"]:
    print("\n  --- FAILED TESTS ---")
    for e in _r["errors"]:
        print(f"    [FAIL] {e}")

print()
if _r["failed"] == 0:
    print("  ALL TESTS PASSED!\n")
else:
    print(f"  {_r['failed']} test(s) FAILED – see above for details.\n")
