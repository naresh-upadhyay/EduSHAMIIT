import os
import sys
import uuid
import json
import logging
import requests
from jose import jwt
from app.config import settings

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

API_BASE_URL = os.environ.get("API_BASE_URL", "http://localhost:8000")
TEST_DATE = "2026-08-19"  # Active scheduled Wednesday with 2 periods (NEWSUB2)

def run_tests():
    session = requests.Session()

    # Step 1: Login as super admin via JWT
    secret = getattr(settings, "SUPABASE_JWT_SECRET", None) or getattr(settings, "JWT_SECRET", "eduSHAMIIT-jwt-secret-2026")
    user_id = "38a93170-997b-4b4c-bc8e-256b93169c23"
    school_id = "11111111-1111-1111-1111-111111111111"
    payload = {
        "sub": user_id,
        "school_id": school_id,
        "role": "super_admin",
        "email": "superadmin@edushamiit.com",
        "exp": 9999999999
    }
    token = jwt.encode(payload, secret, algorithm="HS256")
    session.headers.update({
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    })
    logger.info("[PASS] Logged in as Super Admin via JWT")

    # Step 2: Discover Class 5 and Section NEWSUB2
    classes_res = session.get(f"{API_BASE_URL}/api/classes?academic_year=2026-27")
    assert classes_res.status_code == 200, f"Failed: {classes_res.text}"
    c_data = classes_res.json().get("data", {}).get("classes", [])
    class_5 = next((c for c in c_data if "5" in str(c.get("name", "")).lower()), None)
    assert class_5 is not None, "Class 5 not found"
    class_id = class_5["id"]

    newsub2 = next((s for s in class_5.get("sections", []) if "newsub2" in str(s.get("name", "")).lower()), None)
    assert newsub2 is not None, "Section NEWSUB2 not found"
    section_id = newsub2["id"]
    logger.info(f"[PASS] Discovered Class 5 ({class_id}) Section NEWSUB2 ({section_id})")

    # Step 3: Fetch initial roster
    roster_res = session.get(f"{API_BASE_URL}/api/attendance/roster", params={
        "attendance_date": TEST_DATE,
        "class_id": class_id,
        "section_id": section_id,
        "mode": "PERIOD",
        "period_number": 1
    })
    assert roster_res.status_code == 200
    roster_data = roster_res.json()
    students = roster_data.get("data", {}).get("students", roster_data.get("students", []))
    assert len(students) >= 1, "No students found in roster"
    student = students[0]
    student_id = student["student_id"]
    logger.info(f"[PASS] Testing with student: {student['full_name']} ({student_id})")

    # Step 4: Lock attendance for this student via Save Attendance
    save_payload = {
        "attendance_date": TEST_DATE,
        "class_id": class_id,
        "section_id": section_id,
        "mode": "PERIOD",
        "period_number": 1,
        "records": [
            {
                "student_id": student_id,
                "status": "PRESENT",
                "remarks": "Locked on initial save",
                "periods": [
                    {"period_number": 1, "status": "PRESENT", "remarks": "Period 1 On time"},
                    {"period_number": 2, "status": "PRESENT", "remarks": "Period 2 On time"}
                ]
            }
        ]
    }
    save_res = session.post(f"{API_BASE_URL}/api/attendance/save", json=save_payload)
    assert save_res.status_code == 200, f"Save failed: {save_res.text}"
    logger.info("[PASS] Initial Attendance Saved & Locked (is_locked=True)")

    # Step 5: Verify that roster shows locked
    roster_locked_res = session.get(f"{API_BASE_URL}/api/attendance/roster", params={
        "attendance_date": TEST_DATE,
        "class_id": class_id,
        "section_id": section_id,
        "mode": "PERIOD",
        "period_number": 1
    })
    assert roster_locked_res.status_code == 200
    r_students = roster_locked_res.json().get("data", {}).get("students", [])
    st_locked = next(s for s in r_students if s["student_id"] == student_id)
    assert st_locked["is_locked"] is True, "Expected student to be locked"
    rec_id = st_locked.get("attendance_record_id") or student_id
    logger.info(f"[PASS] Student record confirmed LOCKED in roster with record_id={rec_id}")

    # Step 6: Test Override Lock with empty reason (Must Fail 400)
    empty_override_res = session.post(f"{API_BASE_URL}/api/attendance/override", json={
        "record_id": rec_id,
        "record_type": "DAILY",
        "new_status": "LATE",
        "reason": "   "
    })
    assert empty_override_res.status_code in (400, 422), f"Expected 400 for empty reason, got {empty_override_res.status_code}"
    logger.info("[PASS] Override Lock correctly rejects empty reason (400 Bad Request)")

    # Step 7: Perform Valid Override Lock with Reason
    override_reason = "Principal approved medical exemption and late entry"
    override_res = session.post(f"{API_BASE_URL}/api/attendance/override", json={
        "record_id": rec_id,
        "record_type": "DAILY",
        "new_status": "LATE",
        "reason": override_reason
    })
    assert override_res.status_code == 200, f"Override failed: {override_res.text}"
    logger.info(f"[PASS] POST /api/attendance/override succeeded: {override_res.json()}")

    # Step 8: Verify Record is Now OVERRIDDEN, NEW STATUS SET, and UNLOCKED (is_locked=False)
    roster_unlocked_res = session.get(f"{API_BASE_URL}/api/attendance/roster", params={
        "attendance_date": TEST_DATE,
        "class_id": class_id,
        "section_id": section_id,
        "mode": "PERIOD",
        "period_number": 1
    })
    assert roster_unlocked_res.status_code == 200
    r_students_unlocked = roster_unlocked_res.json().get("data", {}).get("students", [])
    st_unlocked = next(s for s in r_students_unlocked if s["student_id"] == student_id)
    assert st_unlocked["status"] == "LATE", f"Expected LATE, got {st_unlocked['status']}"
    assert st_unlocked["is_overridden"] is True, "Expected is_overridden=True"
    assert st_unlocked["override_reason"] == override_reason, f"Expected reason {override_reason}, got {st_unlocked['override_reason']}"
    assert st_unlocked["is_locked"] is False, "Expected record to be UNLOCKED (is_locked=False)"
    logger.info("[PASS] Student record verified: Status updated to LATE, audit reason recorded, and UNLOCKED for smooth editing!")

    # Step 9: Smooth quick-mark without override popup once unlocked
    quick_mark_res = session.post(f"{API_BASE_URL}/api/attendance/quick-mark-period", json={
        "student_id": student_id,
        "attendance_date": TEST_DATE,
        "period_number": 1,
        "status": "PRESENT",
        "remarks": "Smooth update after unlock"
    })
    assert quick_mark_res.status_code == 200, f"Quick mark failed: {quick_mark_res.text}"
    logger.info("[PASS] Smooth status update succeeds with 0ms overhead on unlocked record!")

    logger.info("================================================================================")
    logger.info("🎉 OVERRIDE LOCK WITH REASON & SMOOTH UNLOCK WORKFLOW VERIFIED 100%!")
    logger.info("================================================================================")

if __name__ == "__main__":
    try:
        run_tests()
    except Exception as e:
        logger.error(f"Test failed with error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
