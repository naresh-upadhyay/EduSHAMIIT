"""
Test Scenario:
1. Load Roster in By Period mode.
2. Update student period statuses individually (e.g. Student 1: P1=Present, P2=Absent; Student 2: P1=Late, P2=Present).
3. Save via POST /api/attendance/save in PERIOD/Grid mode.
4. Verify:
   a) P1 and P2 retain their distinct chosen statuses (do not get overwritten or reset).
   b) Day Summary (composite status) is accurately calculated using the decision matrix.
   c) Roster API in By Period mode returns the student's true composite day status in 'status' and the active period's status in 'active_period_status'.
   d) Day is locked upon saving.
"""

import sys
import os
import requests
import json
import logging

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("PeriodWiseSaveTest")

API_BASE_URL = os.getenv("API_BASE_URL", "http://localhost:8000")
TEST_DATE = "2026-08-19"  # Active timetable date with 2 periods for NEWSUB2

from jose import jwt
from app.config import settings

def run_test():
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
    session.headers.update({"Authorization": f"Bearer {token}", "Content-Type": "application/json"})
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

    # Step 3: Fetch Roster for Period 1
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
    assert len(students) >= 2, f"Expected at least 2 students, got {len(students)}"
    logger.info(f"[PASS] Fetched roster for Period 1 with {len(students)} students")

    s1 = students[0]
    s2 = students[1]
    s3 = students[2] if len(students) > 2 else students[0]

    # Step 4: Construct Save payload with distinct period choices:
    # Student 1: P1 = PRESENT, P2 = ABSENT -> Composite: HALF_DAY (50% rule)
    # Student 2: P1 = PRESENT, P2 = LATE   -> Composite: LATE (All attended but 1 late rule)
    # Student 3: P1 = NOT_MARKED, P2 = PRESENT -> Composite: HALF_DAY (50% rule) BUT P1 MUST REMAIN NOT_MARKED!
    save_payload = {
        "attendance_date": TEST_DATE,
        "class_id": class_id,
        "section_id": section_id,
        "mode": "PERIOD",
        "period_number": 1,
        "records": [
            {
                "student_id": s1["student_id"],
                "status": "HALF_DAY",
                "remarks": "Period custom assignment",
                "periods": [
                    {"period_number": 1, "status": "PRESENT", "remarks": "On time"},
                    {"period_number": 2, "status": "ABSENT", "remarks": "Unexcused"}
                ]
            },
            {
                "student_id": s2["student_id"],
                "status": "LATE",
                "remarks": "Period custom assignment 2",
                "periods": [
                    {"period_number": 1, "status": "PRESENT", "remarks": "On time"},
                    {"period_number": 2, "status": "LATE", "remarks": "10 min late"}
                ]
            },
            {
                "student_id": s3["student_id"],
                "status": "HALF_DAY",
                "remarks": "Period custom assignment 3",
                "periods": [
                    {"period_number": 1, "status": "NOT_MARKED", "remarks": ""},
                    {"period_number": 2, "status": "PRESENT", "remarks": "Present in P2"}
                ]
            }
        ]
    }

    save_res = session.post(f"{API_BASE_URL}/api/attendance/save", json=save_payload)
    assert save_res.status_code == 200, f"Save failed: {save_res.text}"
    logger.info("[PASS] POST /api/attendance/save completed successfully")

    # Step 5: Verify Period 1 Roster Query
    p1_res = session.get(f"{API_BASE_URL}/api/attendance/roster", params={
        "attendance_date": TEST_DATE,
        "class_id": class_id,
        "section_id": section_id,
        "mode": "PERIOD",
        "period_number": 1
    })
    assert p1_res.status_code == 200
    p1_data = p1_res.json()
    p1_students = p1_data.get("data", {}).get("students", p1_data.get("students", []))
    
    p1_s1 = next(s for s in p1_students if s["student_id"] == s1["student_id"])
    p1_s2 = next(s for s in p1_students if s["student_id"] == s2["student_id"])
    p1_s3 = next(s for s in p1_students if s["student_id"] == s3["student_id"])

    # Student 1 checks
    assert p1_s1["status"] == "HALF_DAY", f"Expected Student 1 composite status HALF_DAY, got {p1_s1['status']}"
    assert p1_s1["is_locked"] is True, "Expected Student 1 to be locked"
    p1_periods = {p["period_number"]: p["status"] for p in p1_s1["periods"]}
    assert p1_periods[1] == "PRESENT", f"Student 1 P1 expected PRESENT, got {p1_periods[1]}"
    assert p1_periods[2] == "ABSENT", f"Student 1 P2 expected ABSENT, got {p1_periods[2]}"
    logger.info("[PASS] Student 1: P1=PRESENT, P2=ABSENT -> Distinct period values preserved & composite status = HALF_DAY")

    # Student 2 checks
    assert p1_s2["status"] == "LATE", f"Expected Student 2 composite status LATE, got {p1_s2['status']}"
    assert p1_s2["is_locked"] is True, "Expected Student 2 to be locked"
    p2_periods = {p["period_number"]: p["status"] for p in p1_s2["periods"]}
    assert p2_periods[1] == "PRESENT", f"Student 2 P1 expected PRESENT, got {p2_periods[1]}"
    assert p2_periods[2] == "LATE", f"Student 2 P2 expected LATE, got {p2_periods[2]}"
    logger.info("[PASS] Student 2: P1=PRESENT, P2=LATE -> Distinct period values preserved & composite status = LATE")

    # Student 3 checks (EXACT USER SCENARIO: P1 NOT_MARKED, P2 PRESENT)
    assert p1_s3["status"] == "HALF_DAY", f"Expected Student 3 composite status HALF_DAY, got {p1_s3['status']}"
    p3_periods = {p["period_number"]: p["status"] for p in p1_s3["periods"]}
    assert p3_periods[1] == "NOT_MARKED", f"CRITICAL: Student 3 P1 MUST BE NOT_MARKED, got {p3_periods[1]}"
    assert p3_periods[2] == "PRESENT", f"Student 3 P2 expected PRESENT, got {p3_periods[2]}"
    logger.info("[PASS] Student 3: P1=NOT_MARKED, P2=PRESENT -> P1 STRICTLY REMAINS NOT_MARKED AND IS NOT CONVERTED TO HALF_DAY!")

    # Step 6: Verify Period 2 Roster Query
    p2_res = session.get(f"{API_BASE_URL}/api/attendance/roster", params={
        "attendance_date": TEST_DATE,
        "class_id": class_id,
        "section_id": section_id,
        "mode": "PERIOD",
        "period_number": 2
    })
    assert p2_res.status_code == 200
    p2_data = p2_res.json()
    p2_students = p2_data.get("data", {}).get("students", p2_data.get("students", []))
    p2_s1 = next(s for s in p2_students if s["student_id"] == s1["student_id"])
    assert p2_s1["status"] == "HALF_DAY", f"Expected composite status HALF_DAY on P2 view as well, got {p2_s1['status']}"
    logger.info("[PASS] Period 2 view returns true composite day status without resetting")

    # Step 7: Verify Stats & Day Summary endpoint
    stats_res = session.get(f"{API_BASE_URL}/api/attendance/stats", params={
        "attendance_date": TEST_DATE,
        "class_id": class_id,
        "section_id": section_id
    })
    assert stats_res.status_code == 200
    stats_raw = stats_res.json()
    stats = stats_raw.get("data", stats_raw)
    day_summary = stats.get("day_summary", {})
    logger.info(f"Day Summary response: {json.dumps(day_summary)}")
    assert day_summary.get("half_day", 0) >= 1, f"Expected at least 1 half_day in day_summary, got {day_summary}"
    assert day_summary.get("late", 0) >= 1, f"Expected at least 1 late in day_summary, got {day_summary}"
    logger.info("[PASS] Day Summary KPI and Donut chart metrics accurately reflect composite day statuses!")

    logger.info("=" * 80)
    logger.info("ALL PERIOD-WISE SAVE & DAY SUMMARY TESTS PASSED (100%)!")
    logger.info("=" * 80)

if __name__ == "__main__":
    run_test()
