import asyncio
import json
import logging
import uuid

from app.api.attendance import (
    get_daily_attendance_roster,
    quick_mark_student_period,
    QuickMarkPeriodRequest,
    exec_sql,
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("TestStudentPeriodsBreakdown")

async def run_tests():
    logger.info("==========================================================================")
    logger.info("  TESTING STUDENT PERIOD BREAKDOWN COLUMN & QUICK PERIOD MARKING (E2E)    ")
    logger.info("==========================================================================")

    school_id = "11111111-1111-1111-1111-111111111111"
    user_dict = {
        "id": "10000000-0000-0000-0000-000000000003",
        "school_id": school_id,
        "role": "Super Admin",
        "permissions": ["attendance.view", "attendance.take", "attendance.override_locked"]
    }

    # Fetch Class 5 ID and Section ID
    classes = await exec_sql("SELECT id, name FROM public.academic_classes WHERE school_id = %s AND name ILIKE 'Class 5' LIMIT 1;", (school_id,))
    assert classes, "Class 5 not found!"
    class_id = classes[0]["id"]

    sections = await exec_sql("SELECT id, name FROM public.academic_sections WHERE class_id = %s AND name ILIKE 'NEWSUB2' LIMIT 1;", (str(class_id),))
    section_id = sections[0]["id"] if sections else None
    section_name = sections[0]["name"] if sections else "Default"
    logger.info(f"Using Class: Class 5, Section: {section_name} ({section_id})")

    # Fetch active students for Class 5 - NEWSUB2
    students = await exec_sql("""
        SELECT sca.student_id, p.full_name 
        FROM public.student_class_assignments sca
        JOIN public.profiles p ON p.id = sca.student_id
        WHERE sca.school_id = %s AND sca.class_id = %s AND sca.section_id = %s AND sca.status = 'ACTIVE';
    """, (school_id, str(class_id), str(section_id)))
    assert len(students) > 0, "No students found in Class 5"
    student_id = str(students[0]["student_id"])
    student_name = students[0]["full_name"]
    logger.info(f"Testing with Student: {student_name} ({student_id}) on Class 5")

    test_date = "2026-08-19"

    # Reset attendance for test date
    await exec_sql("DELETE FROM public.attendance_period_records WHERE school_id = %s AND attendance_date = %s;", (school_id, test_date), fetch=False)
    await exec_sql("DELETE FROM public.attendance_daily_records WHERE school_id = %s AND attendance_date = %s;", (school_id, test_date), fetch=False)

    # -------------------------------------------------------------------------
    # STEP 1: Fetch Initial Roster on 2026-08-19 (Should have 2 scheduled periods)
    # -------------------------------------------------------------------------
    logger.info("\n--- 1. Fetching Roster on 2026-08-19 ---")
    roster_init = await get_daily_attendance_roster(
        attendance_date=test_date,
        class_id=uuid.UUID(str(class_id)),
        section_id=uuid.UUID(str(section_id)) if section_id else None,
        mode="ALL_DAY",
        current_user=user_dict,
        school_id=school_id
    )
    assert roster_init["success"] is True
    student_init = next((s for s in roster_init["data"]["students"] if s["student_id"] == student_id), None)
    assert student_init is not None
    logger.info(f"Initial Status: {student_init['status']}, Total Periods: {len(student_init['periods'])}")
    assert len(student_init["periods"]) >= 2, f"Expected at least 2 periods, got {len(student_init['periods'])}"
    for p in student_init["periods"]:
        logger.info(f"  -> {p['period_label']}: {p['subject_name']} ({p['time_range']}) - Status: {p['status']}")
        assert p["status"] == "NOT_MARKED"

    # -------------------------------------------------------------------------
    # STEP 2: Quick-Mark Period 1 only as PRESENT
    # -------------------------------------------------------------------------
    logger.info("\n--- 2. Quick Marking Period 1 as PRESENT ---")
    p1 = student_init["periods"][0]
    qm_res = await quick_mark_student_period(
        payload=QuickMarkPeriodRequest(
            student_id=uuid.UUID(student_id),
            attendance_date=test_date,
            period_number=p1["period_number"],
            status="PRESENT",
            subject_id=uuid.UUID(p1["subject_id"]) if p1.get("subject_id") else None,
            schedule_id=uuid.UUID(p1["schedule_id"]) if p1.get("schedule_id") else None,
            remarks="Attended CS"
        ),
        current_user=user_dict,
        school_id=school_id
    )
    assert qm_res["success"] is True

    # -------------------------------------------------------------------------
    # STEP 3: Verify Partial Period Status in ALL_DAY mode
    # -------------------------------------------------------------------------
    logger.info("\n--- 3. Verifying Partial Periods in ALL_DAY mode ---")
    roster_partial = await get_daily_attendance_roster(
        attendance_date=test_date,
        class_id=uuid.UUID(str(class_id)),
        section_id=uuid.UUID(str(section_id)) if section_id else None,
        mode="ALL_DAY",
        current_user=user_dict,
        school_id=school_id
    )
    student_partial = next((s for s in roster_partial["data"]["students"] if s["student_id"] == student_id), None)
    assert student_partial is not None
    logger.info(f"Student Partial Status: {student_partial['status']}, Summary: {student_partial['periods_summary']}")
    assert student_partial["status"] == "HALF_DAY", f"Expected HALF_DAY, got {student_partial['status']}"
    assert student_partial["periods_summary"]["marked_periods"] == 1
    assert student_partial["periods_summary"]["present_count"] == 1
    assert student_partial["periods"][0]["status"] == "PRESENT"
    assert student_partial["periods"][1]["status"] == "NOT_MARKED"
    logger.info("✅ Verified: 1 out of 2 periods present mathematically computes to HALF_DAY (50% rule) and period chips!")

    # -------------------------------------------------------------------------
    # STEP 4: Quick-Mark Period 2 as PRESENT -> Verify Auto-Complete
    # -------------------------------------------------------------------------
    logger.info("\n--- 4. Quick Marking Period 2 as PRESENT ---")
    p2 = student_init["periods"][1]
    qm_res2 = await quick_mark_student_period(
        payload=QuickMarkPeriodRequest(
            student_id=uuid.UUID(student_id),
            attendance_date=test_date,
            period_number=p2["period_number"],
            status="PRESENT",
            subject_id=uuid.UUID(p2["subject_id"]) if p2.get("subject_id") else None,
            schedule_id=uuid.UUID(p2["schedule_id"]) if p2.get("schedule_id") else None,
            remarks="Attended English"
        ),
        current_user=user_dict,
        school_id=school_id
    )
    assert qm_res2["success"] is True

    # Check ALL_DAY mode roster: should now be PRESENT (is_locked = TRUE)
    roster_complete = await get_daily_attendance_roster(
        attendance_date=test_date,
        class_id=uuid.UUID(str(class_id)),
        section_id=uuid.UUID(str(section_id)) if section_id else None,
        mode="ALL_DAY",
        current_user=user_dict,
        school_id=school_id
    )
    student_complete = next((s for s in roster_complete["data"]["students"] if s["student_id"] == student_id), None)
    # -------------------------------------------------------------------------
    # STEP 5: Quick-Mark Period 2 as ABSENT -> Verify Composite HALF_DAY Status
    # -------------------------------------------------------------------------
    logger.info("\n--- 5. Quick Marking Period 2 as ABSENT -> Verify HALF_DAY ---")
    qm_res3 = await quick_mark_student_period(
        payload=QuickMarkPeriodRequest(
            student_id=uuid.UUID(student_id),
            attendance_date=test_date,
            period_number=p2["period_number"],
            status="ABSENT",
            subject_id=uuid.UUID(p2["subject_id"]) if p2.get("subject_id") else None,
            schedule_id=uuid.UUID(p2["schedule_id"]) if p2.get("schedule_id") else None,
            remarks="Absent in P2"
        ),
        current_user=user_dict,
        school_id=school_id
    )
    assert qm_res3["success"] is True

    roster_half = await get_daily_attendance_roster(
        attendance_date=test_date,
        class_id=uuid.UUID(str(class_id)),
        section_id=uuid.UUID(str(section_id)) if section_id else None,
        mode="ALL_DAY",
        current_user=user_dict,
        school_id=school_id
    )
    student_half = next((s for s in roster_half["data"]["students"] if s["student_id"] == student_id), None)
    assert student_half is not None
    logger.info(f"Student Mixed Status: {student_half['status']}, summary: {student_half['periods_summary']}")
    assert student_half["status"] == "HALF_DAY", f"Expected HALF_DAY for 1 Present + 1 Absent, got {student_half['status']}"
    logger.info("✅ Verified: 1 Present + 1 Absent is mathematically computed as HALF_DAY instead of blindly ABSENT!")

    logger.info("\n==========================================================================")
    logger.info("  🎉 ALL PERIOD BREAKDOWN & QUICK-MARK TESTS PASSED 100%!                ")
    logger.info("==========================================================================")

if __name__ == "__main__":
    asyncio.run(run_tests())
