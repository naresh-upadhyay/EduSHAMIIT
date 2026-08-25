import asyncio
import json
import logging
import uuid
from datetime import date

from app.api.attendance import (
    get_class_schedules_today,
    save_daily_attendance,
    get_daily_attendance_roster,
    get_attendance_stats,
    SaveAttendanceRequest,
    AttendanceItemPayload,
    exec_sql,
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("TestAcademicPeriodsAttendance")

async def run_tests():
    logger.info("==========================================================================")
    logger.info("   TESTING ACADEMIC CALENDAR & PERIOD-WISE ATTENDANCE BIDIRECTIONAL SYNC  ")
    logger.info("==========================================================================")

    school_id = "11111111-1111-1111-1111-111111111111"
    user_dict = {
        "id": "10000000-0000-0000-0000-000000000003",
        "school_id": school_id,
        "role": "Super Admin",
        "permissions": ["attendance.view", "attendance.take", "attendance.override_locked"]
    }

    # 1. Fetch Class 5 ID and Section ID
    classes = await exec_sql("SELECT id, name FROM public.academic_classes WHERE school_id = %s AND name ILIKE 'Class 5' LIMIT 1;", (school_id,))
    assert classes, "Class 5 not found!"
    class_id = classes[0]["id"]
    class_name = classes[0]["name"]

    # Fetch section with active student in Class 5
    students = await exec_sql("""
        SELECT sca.student_id, p.full_name, sca.roll_number, sca.section_id, s.name as section_name
        FROM public.student_class_assignments sca
        JOIN public.profiles p ON p.id = sca.student_id
        LEFT JOIN public.academic_sections s ON s.id = sca.section_id
        WHERE sca.school_id = %s AND sca.class_id = %s AND sca.status = 'ACTIVE'
        ORDER BY sca.assigned_at DESC LIMIT 1;
    """, (school_id, str(class_id)))
    assert len(students) > 0, "No students found in Class 5"
    student_id = str(students[0]["student_id"])
    student_name = students[0]["full_name"]
    section_id = str(students[0]["section_id"]) if students[0].get("section_id") else None
    section_name = students[0]["section_name"] or "Default"
    logger.info(f"Using Class: {class_name} ({class_id}), Section: {section_name} ({section_id})")
    logger.info(f"Testing with Student: {student_name} ({student_id})")

    test_date = "2026-08-19"

    # Clean up previous test attendance for this date
    await exec_sql("DELETE FROM public.attendance_period_records WHERE school_id = %s AND attendance_date = %s;", (school_id, test_date), fetch=False)
    await exec_sql("DELETE FROM public.attendance_daily_records WHERE school_id = %s AND attendance_date = %s;", (school_id, test_date), fetch=False)

    # -------------------------------------------------------------------------
    # TEST 1: Mark Period Attendance & Verify Roster & Custom Selection Mode
    # -------------------------------------------------------------------------
    logger.info("\n--- TEST 1: Mark Attendance in PERIOD / CUSTOM SELECTION Mode ---")
    schedules_res = await get_class_schedules_today(
        attendance_date=test_date,
        class_id=uuid.UUID(str(class_id)),
        section_id=uuid.UUID(str(section_id)) if section_id else None,
        current_user=user_dict,
        school_id=school_id
    )
    assert schedules_res["success"] is True
    schedules = schedules_res["data"]["schedules"]
    assert len(schedules) > 0, "Expected at least 1 schedule"
    p1 = schedules[0]
    p1_num = p1["period_number"]
    p1_sub_id = uuid.UUID(p1["subject_id"])
    p1_sched_id = uuid.UUID(p1["schedule_id"]) if p1.get("schedule_id") else None

    # Mark Period 1 as PRESENT
    req_p1 = SaveAttendanceRequest(
        attendance_date=test_date,
        class_id=uuid.UUID(str(class_id)),
        section_id=uuid.UUID(str(section_id)) if section_id else None,
        mode="PERIOD",
        period_number=p1_num,
        subject_id=p1_sub_id,
        schedule_id=p1_sched_id,
        records=[
            AttendanceItemPayload(
                student_id=uuid.UUID(student_id),
                status="PRESENT",
                remarks="Attended period 1"
            )
        ]
    )
    save_res = await save_daily_attendance(payload=req_p1, current_user=user_dict, school_id=school_id)
    assert save_res["success"] is True

    # Query roster in PERIOD mode
    roster_p1 = await get_daily_attendance_roster(
        attendance_date=test_date,
        class_id=uuid.UUID(str(class_id)),
        section_id=uuid.UUID(str(section_id)) if section_id else None,
        mode="PERIOD",
        period_number=p1_num,
        subject_id=p1_sub_id,
        current_user=user_dict,
        school_id=school_id
    )
    student_row_p1 = next((s for s in roster_p1["data"]["students"] if s["student_id"] == student_id), None)
    assert student_row_p1 is not None
    assert student_row_p1["status"] == "PRESENT", f"Expected PRESENT, got {student_row_p1['status']}"
    logger.info(f"✅ Verified Roster in PERIOD mode: Status={student_row_p1['status']}, remarks='{student_row_p1['remarks']}'")

    # Query roster in CUSTOM_SELECTION mode
    roster_custom = await get_daily_attendance_roster(
        attendance_date=test_date,
        class_id=uuid.UUID(str(class_id)),
        section_id=uuid.UUID(str(section_id)) if section_id else None,
        mode="MULTI_SCHEDULE",
        period_number=p1_num,
        subject_id=p1_sub_id,
        current_user=user_dict,
        school_id=school_id
    )
    student_row_custom = next((s for s in roster_custom["data"]["students"] if s["student_id"] == student_id), None)
    assert student_row_custom is not None
    assert student_row_custom["status"] == "PRESENT", f"Expected PRESENT, got {student_row_custom['status']}"
    logger.info(f"✅ Verified Roster in CUSTOM_SELECTION mode: Status={student_row_custom['status']}")

    # -------------------------------------------------------------------------
    # TEST 2: Mark WHOLE DAY Attendance -> Verify Periods are Auto-Marked & Locked
    # -------------------------------------------------------------------------
    logger.info("\n--- TEST 2: Mark Whole-Day Attendance -> Check Period-Wise Auto-Lock ---")
    req_all_day = SaveAttendanceRequest(
        attendance_date=test_date,
        class_id=uuid.UUID(str(class_id)),
        section_id=uuid.UUID(str(section_id)) if section_id else None,
        mode="ALL_DAY",
        records=[
            AttendanceItemPayload(
                student_id=uuid.UUID(student_id),
                status="PRESENT",
                remarks="Full day present"
            )
        ]
    )
    save_all_res = await save_daily_attendance(payload=req_all_day, current_user=user_dict, school_id=school_id)
    assert save_all_res["success"] is True

    # Now check in PERIOD mode: should be PRESENT and LOCKED
    roster_p1_after_all_day = await get_daily_attendance_roster(
        attendance_date=test_date,
        class_id=uuid.UUID(str(class_id)),
        section_id=uuid.UUID(str(section_id)) if section_id else None,
        mode="PERIOD",
        period_number=p1_num,
        subject_id=p1_sub_id,
        current_user=user_dict,
        school_id=school_id
    )
    student_row_locked = next((s for s in roster_p1_after_all_day["data"]["students"] if s["student_id"] == student_id), None)
    assert student_row_locked is not None
    assert student_row_locked["status"] == "PRESENT"
    assert student_row_locked["is_locked"] is True, "Period should be locked by all-day attendance"
    assert student_row_locked["locked_by_all_day"] is True
    logger.info(f"✅ Verified Period-Wise View after Whole-Day: Status={student_row_locked['status']}, is_locked={student_row_locked['is_locked']}, locked_by_all_day={student_row_locked['locked_by_all_day']}")

    # -------------------------------------------------------------------------
    # TEST 3: Dashboard Stats reflects Attendance
    # -------------------------------------------------------------------------
    logger.info("\n--- TEST 3: Check Dashboard Stats ---")
    stats_res = await get_attendance_stats(
        attendance_date=test_date,
        class_id=uuid.UUID(str(class_id)),
        section_id=uuid.UUID(str(section_id)) if section_id else None,
        current_user=user_dict,
        school_id=school_id
    )
    assert stats_res["success"] is True
    stats = stats_res["data"]
    logger.info(f"✅ Dashboard Stats: Overall={stats.get('overall_attendance_pct')}%, Total={stats.get('total_students')}, Present={stats.get('students_present')}")
    assert stats.get("students_present", 0) >= 1

    logger.info("\n==========================================================================")
    logger.info("  🎉 ALL 3 WHOLE-DAY AND PERIOD-WISE ATTENDANCE SCENARIOS PASSED 100%!     ")
    logger.info("==========================================================================")

if __name__ == "__main__":
    asyncio.run(run_tests())
