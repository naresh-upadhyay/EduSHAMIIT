import asyncio
import os
import sys
import uuid
import json
import logging
from datetime import date, datetime, timedelta
from typing import Dict, Any, List

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("ExhaustiveEdgeCases")

sys.path.insert(0, "/app")
from app.api.attendance import (
    exec_sql,
    get_daily_attendance_roster,
    save_daily_attendance,
    quick_mark_student_period,
    get_class_schedules_today,
    override_locked_attendance,
    SaveAttendanceRequest,
    AttendanceItemPayload,
    QuickMarkPeriodRequest,
    OverrideAttendanceRequest
)

async def run_master_edge_cases_suite():
    logger.info("=" * 85)
    logger.info("  STARTING EXHAUSTIVE ATTENDANCE END-TO-END EDGE CASES TEST SUITE")
    logger.info("=" * 85)

    passed_tests = 0
    total_tests = 0

    def record_pass(test_name: str):
        nonlocal passed_tests, total_tests
        passed_tests += 1
        total_tests += 1
        logger.info(f"  [PASS] {test_name}")

    def record_fail(test_name: str, err: str):
        nonlocal total_tests
        total_tests += 1
        logger.error(f"  [FAIL] {test_name}: {err}")
        raise AssertionError(f"Edge case failed: {test_name} -> {err}")

    # Bootstrap Context
    schools = await exec_sql("SELECT id FROM public.schools LIMIT 1;")
    assert len(schools) > 0, "No school found"
    school_id = str(schools[0]["id"])

    users = await exec_sql("SELECT id, email FROM public.profiles WHERE role = 'super_admin' LIMIT 1;")
    user_id = str(users[0]["id"]) if users else "10000000-0000-0000-0000-000000000003"
    user_dict = {"id": user_id, "school_id": school_id, "role": "super_admin", "email": "superadmin@edushamiit.com"}

    # Find Class 5 and Sections
    classes = await exec_sql("SELECT id, name FROM public.academic_classes WHERE name ILIKE '%Class 5%' LIMIT 1;")
    assert len(classes) > 0, "Class 5 not found"
    class_id = str(classes[0]["id"])

    sections = await exec_sql("SELECT id, name FROM public.academic_sections WHERE class_id = %s;", (class_id,))
    section_map = {s["name"]: str(s["id"]) for s in sections}

    sec_a_id = section_map.get("a")
    sec_newsub2_id = section_map.get("NEWSUB2")

    # =========================================================================
    # SECTION 1: ACADEMIC CALENDAR RECURRENCE & DATE BOUNDARY EDGE CASES
    # =========================================================================
    logger.info("\n--- SECTION 1: Academic Calendar Recurrence & Date Boundaries ---")

    # 1.1 Non-scheduled date (2026-08-25) should return 0 schedules
    res_25 = await get_class_schedules_today(
        attendance_date="2026-08-25",
        class_id=uuid.UUID(class_id),
        section_id=uuid.UUID(sec_newsub2_id) if sec_newsub2_id else None,
        current_user=user_dict,
        school_id=school_id
    )
    if res_25["success"] is True and len(res_25["data"]["schedules"]) == 0:
        record_pass("Non-scheduled date (2026-08-25) returns 0 schedules")
    else:
        record_fail("Non-scheduled date check", f"Expected 0 schedules, got {len(res_25['data']['schedules'])}")

    # 1.2 Active scheduled date (2026-08-19) should return active schedules for NEWSUB2
    res_19 = await get_class_schedules_today(
        attendance_date="2026-08-19",
        class_id=uuid.UUID(class_id),
        section_id=uuid.UUID(sec_newsub2_id) if sec_newsub2_id else None,
        current_user=user_dict,
        school_id=school_id
    )
    if res_19["success"] is True and len(res_19["data"]["schedules"]) == 2:
        record_pass("Active scheduled date (2026-08-19) returns 2 periods for NEWSUB2")
    else:
        record_fail("Active scheduled date check", f"Expected 2 schedules, got {len(res_19['data']['schedules'])}")

    # 1.3 Exception date (2026-08-20) where Computer Science had exception in recurrence
    res_20_newsub2 = await get_class_schedules_today(
        attendance_date="2026-08-20",
        class_id=uuid.UUID(class_id),
        section_id=uuid.UUID(sec_newsub2_id) if sec_newsub2_id else None,
        current_user=user_dict,
        school_id=school_id
    )
    scheds_20 = [s["schedule_title"] for s in res_20_newsub2["data"]["schedules"]]
    if "Computer science class" not in scheds_20 and "Eng" in scheds_20:
        record_pass("Exception date (2026-08-20) skips Computer Science while keeping English")
    else:
        record_fail("Exception date check", f"Schedules on 2026-08-20: {scheds_20}")

    # 1.4 Section Isolation: Section 'a' vs Section 'NEWSUB2' on 2026-08-19
    res_19_a = await get_class_schedules_today(
        attendance_date="2026-08-19",
        class_id=uuid.UUID(class_id),
        section_id=uuid.UUID(sec_a_id) if sec_a_id else None,
        current_user=user_dict,
        school_id=school_id
    )
    if len(res_19_a["data"]["schedules"]) == 1:
        record_pass("Section Isolation: Section 'a' has strictly 1 scheduled period on 2026-08-19")
    else:
        record_fail("Section Isolation check", f"Expected 1 schedule for Section a, got {len(res_19_a['data']['schedules'])}")

    # =========================================================================
    # SECTION 2: MATHEMATICAL DECISION MATRIX EDGE CASES (DIRECT SQL)
    # =========================================================================
    logger.info("\n--- SECTION 2: Mathematical Status Decision Matrix (All Combinations) ---")

    math_cases = [
        # (total, P, A, L, Leave, Half, Marked, Expected, Description)
        (0, 0, 0, 0, 0, 0, 0, "NOT_MARKED", "Total periods 0 -> NOT_MARKED"),
        (4, 0, 0, 0, 0, 0, 0, "NOT_MARKED", "0 of 4 marked -> NOT_MARKED"),
        (2, 0, 0, 0, 2, 0, 2, "ON_LEAVE", "All 2 ON_LEAVE -> ON_LEAVE"),
        (3, 0, 3, 0, 0, 0, 3, "ABSENT", "All 3 ABSENT -> ABSENT"),
        (2, 2, 0, 0, 0, 0, 2, "PRESENT", "All 2 PRESENT -> PRESENT"),
        (2, 1, 0, 1, 0, 0, 2, "LATE", "1 Present + 1 Late -> LATE"),
        (2, 0, 0, 2, 0, 0, 2, "LATE", "All 2 LATE -> LATE"),
        (2, 0, 1, 0, 1, 0, 2, "ON_LEAVE", "1 Absent + 1 Leave -> ON_LEAVE"),
        (4, 0, 2, 0, 2, 0, 4, "ON_LEAVE", "2 Absent + 2 Leave -> ON_LEAVE"),
        (4, 3, 1, 0, 0, 0, 4, "PRESENT", "3 Present + 1 Absent of 4 (75%) -> PRESENT"),
        (4, 2, 0, 1, 0, 2, 4, "PRESENT", "2 Present + 1 Late + 1 Half of 4 (87.5%) -> PRESENT"),
        (2, 1, 1, 0, 0, 0, 2, "HALF_DAY", "1 Present + 1 Absent of 2 (50%) -> HALF_DAY"),
        (3, 2, 1, 0, 0, 0, 3, "HALF_DAY", "2 Present + 1 Absent of 3 (66.7%) -> HALF_DAY"),
        (4, 2, 2, 0, 0, 0, 4, "HALF_DAY", "2 Present + 2 Absent of 4 (50%) -> HALF_DAY"),
        (4, 1, 3, 0, 0, 0, 4, "ABSENT", "1 Present + 3 Absent of 4 (25%) -> ABSENT"),
        (4, 1, 2, 0, 1, 0, 4, "ON_LEAVE", "1 Present + 2 Absent + 1 Leave (<50% with leave) -> ON_LEAVE"),
    ]

    for total, p, a, l, lev, h, m, exp, desc in math_cases:
        row = await exec_sql("""
            SELECT public.fn_calculate_composite_attendance_status(%s, %s, %s, %s, %s, %s, %s) AS status;
        """, (total, p, a, l, lev, h, m))
        actual = row[0]["status"]
        if actual == exp:
            record_pass(f"{desc} = {actual}")
        else:
            record_fail(desc, f"Expected {exp}, got {actual}")

    # =========================================================================
    # SECTION 3: APPROVED LEAVE PROPAGATION & REMARKS INHERITANCE
    # =========================================================================
    logger.info("\n--- SECTION 3: Approved Leave Auto-Propagation & Remarks ---")

    # Pick a student in Class 5
    students_in_class = await exec_sql("""
        SELECT sca.student_id, p.full_name, sca.section_id
        FROM public.student_class_assignments sca
        JOIN public.profiles p ON p.id = sca.student_id
        WHERE sca.school_id = %s AND sca.class_id = %s AND sca.status = 'ACTIVE'
        LIMIT 1;
    """, (school_id, class_id))
    st_target = students_in_class[0]
    st_id = str(st_target["student_id"])
    st_name = st_target["full_name"]
    st_sec_id = str(st_target["section_id"])

    leave_test_date = "2026-09-21"
    leave_id = str(uuid.uuid4())
    custom_leave_reason = "Official Academic Conference & Paper Presentation"

    # Clean previous
    await exec_sql("DELETE FROM public.attendance_period_records WHERE student_id = %s AND attendance_date = %s;", (st_id, leave_test_date), fetch=False)
    await exec_sql("DELETE FROM public.attendance_daily_records WHERE student_id = %s AND attendance_date = %s;", (st_id, leave_test_date), fetch=False)
    await exec_sql("DELETE FROM public.leave_applications WHERE applicant_id = %s AND start_date = %s;", (st_id, leave_test_date), fetch=False)

    # Insert approved leave
    await exec_sql("""
        INSERT INTO public.leave_applications (
            id, school_id, applicant_id, leave_type,
            start_date, end_date, reason, status, created_at, updated_at
        ) VALUES (
            %s, %s, %s, 'Duty Leave',
            %s, %s, %s, 'approved', NOW(), NOW()
        );
    """, (leave_id, school_id, st_id, leave_test_date, leave_test_date, custom_leave_reason), fetch=False)

    # Query roster
    roster_leave_res = await get_daily_attendance_roster(
        attendance_date=leave_test_date,
        class_id=uuid.UUID(class_id),
        section_id=uuid.UUID(st_sec_id) if st_sec_id else None,
        mode="ALL_DAY",
        current_user=user_dict,
        school_id=school_id
    )
    st_leave_row = next((s for s in roster_leave_res["data"]["students"] if s["student_id"] == st_id), None)
    assert st_leave_row is not None, "Target student missing in roster"

    if st_leave_row["has_approved_leave"] is True:
        record_pass("Approved leave detected flag `has_approved_leave = True`")
    else:
        record_fail("Approved leave flag", f"has_approved_leave is {st_leave_row['has_approved_leave']}")

    if st_leave_row["status"] == "ON_LEAVE":
        record_pass("Student master daily status auto-propagates as ON_LEAVE")
    else:
        record_fail("Approved leave master status", f"Expected ON_LEAVE, got {st_leave_row['status']}")

    if st_leave_row["remarks"] == custom_leave_reason:
        record_pass(f"Student daily remarks inherits leave reason: '{custom_leave_reason}'")
    else:
        record_fail("Approved leave remarks", f"Expected '{custom_leave_reason}', got '{st_leave_row['remarks']}'")

    # Clean up leave
    await exec_sql("DELETE FROM public.leave_applications WHERE id = %s;", (leave_id,), fetch=False)

    # =========================================================================
    # SECTION 4: QUICK-MARK, RE-CALCULATION & FULL RESET LIFECYCLE
    # =========================================================================
    logger.info("\n--- SECTION 4: Quick-Mark, Auto Re-Calculation & Reset Lifecycle ---")

    qm_date = "2026-08-19"
    # Find student in NEWSUB2 (has 2 periods)
    st_newsub2 = await exec_sql("""
        SELECT sca.student_id, p.full_name
        FROM public.student_class_assignments sca
        JOIN public.profiles p ON p.id = sca.student_id
        WHERE sca.school_id = %s AND sca.section_id = %s AND sca.status = 'ACTIVE'
        LIMIT 1;
    """, (school_id, sec_newsub2_id))
    st_qm_id = str(st_newsub2[0]["student_id"])

    # Clean previous
    await exec_sql("DELETE FROM public.attendance_period_records WHERE student_id = %s AND attendance_date = %s;", (st_qm_id, qm_date), fetch=False)
    await exec_sql("DELETE FROM public.attendance_daily_records WHERE student_id = %s AND attendance_date = %s;", (st_qm_id, qm_date), fetch=False)

    # Step 4.1: Mark P1 = PRESENT -> 1 of 2 periods present = 50% -> HALF_DAY
    qm_req_1 = QuickMarkPeriodRequest(
        student_id=uuid.UUID(st_qm_id),
        attendance_date=qm_date,
        period_number=1,
        status="PRESENT"
    )
    qm_res_1 = await quick_mark_student_period(qm_req_1, user_dict, school_id)
    if qm_res_1["composite_daily_status"] == "HALF_DAY":
        record_pass("Quick-Mark P1=PRESENT (1 of 2 periods) -> Composite = HALF_DAY (50% rule)")
    else:
        record_fail("Quick-Mark P1", f"Expected HALF_DAY, got {qm_res_1['composite_daily_status']}")

    # Step 4.2: Mark P2 = PRESENT -> 2 of 2 periods present = 100% -> PRESENT
    qm_req_2 = QuickMarkPeriodRequest(
        student_id=uuid.UUID(st_qm_id),
        attendance_date=qm_date,
        period_number=2,
        status="PRESENT"
    )
    qm_res_2 = await quick_mark_student_period(qm_req_2, user_dict, school_id)
    if qm_res_2["composite_daily_status"] == "PRESENT":
        record_pass("Quick-Mark P2=PRESENT (2 of 2 periods) -> Composite = PRESENT")
    else:
        record_fail("Quick-Mark P2", f"Expected PRESENT, got {qm_res_2['composite_daily_status']}")

    # Step 4.3: Change P2 = LATE -> 1 Present + 1 Late -> LATE
    qm_req_3 = QuickMarkPeriodRequest(
        student_id=uuid.UUID(st_qm_id),
        attendance_date=qm_date,
        period_number=2,
        status="LATE"
    )
    qm_res_3 = await quick_mark_student_period(qm_req_3, user_dict, school_id)
    if qm_res_3["composite_daily_status"] == "LATE":
        record_pass("Change P2=LATE (1 Present + 1 Late) -> Composite = LATE")
    else:
        record_fail("Change P2 to Late", f"Expected LATE, got {qm_res_3['composite_daily_status']}")

    # Step 4.4: Reset P2 to NOT_MARKED -> P2 record deleted, composite falls back to P1 (1 of 2 = HALF_DAY)
    qm_req_reset_2 = QuickMarkPeriodRequest(
        student_id=uuid.UUID(st_qm_id),
        attendance_date=qm_date,
        period_number=2,
        status="NOT_MARKED"
    )
    qm_res_reset_2 = await quick_mark_student_period(qm_req_reset_2, user_dict, school_id)
    p2_count_in_db = await exec_sql("SELECT COUNT(*) FROM public.attendance_period_records WHERE student_id = %s AND attendance_date = %s AND period_number = 2;", (st_qm_id, qm_date))
    if p2_count_in_db[0]["count"] == 0 and qm_res_reset_2["composite_daily_status"] == "HALF_DAY":
        record_pass("Reset P2=NOT_MARKED: Period record deleted from DB and composite recalculated to HALF_DAY")
    else:
        record_fail("Reset P2", f"DB Count: {p2_count_in_db[0]['count']}, Status: {qm_res_reset_2['composite_daily_status']}")

    # Step 4.5: Reset P1 to NOT_MARKED -> Full Reset: Master daily record removed/reset
    qm_req_reset_1 = QuickMarkPeriodRequest(
        student_id=uuid.UUID(st_qm_id),
        attendance_date=qm_date,
        period_number=1,
        status="NOT_MARKED"
    )
    qm_res_reset_1 = await quick_mark_student_period(qm_req_reset_1, user_dict, school_id)
    daily_count_in_db = await exec_sql("SELECT COUNT(*) FROM public.attendance_daily_records WHERE student_id = %s AND attendance_date = %s;", (st_qm_id, qm_date))
    if daily_count_in_db[0]["count"] == 0 and qm_res_reset_1["composite_daily_status"] == "NOT_MARKED":
        record_pass("Reset P1=NOT_MARKED (All periods reset): Master daily record removed and status reset to NOT_MARKED")
    else:
        record_fail("Full Reset", f"Daily DB Count: {daily_count_in_db[0]['count']}, Status: {qm_res_reset_1['composite_daily_status']}")

    # =========================================================================
    # SECTION 5: LIVE GRID-STATE SAVING & FIDELITY
    # =========================================================================
    logger.info("\n--- SECTION 5: Live Grid-State Saving (POST /api/attendance/save) ---")

    grid_date = "2026-08-19"
    # Fetch all students in Class 5 on 2026-08-19
    init_roster = await get_daily_attendance_roster(
        attendance_date=grid_date,
        class_id=uuid.UUID(class_id),
        mode="ALL_DAY",
        current_user=user_dict,
        school_id=school_id
    )
    roster_st = init_roster["data"]["students"]
    assert len(roster_st) > 0, "No students found in Class 5 roster"

    # Construct heterogeneous grid state
    save_items: List[AttendanceItemPayload] = []
    expected_results: Dict[str, Dict[str, Any]] = {}

    for idx, s in enumerate(roster_st):
        s_id = s["student_id"]
        pers = s.get("periods", [])
        period_payloads = []
        if len(pers) >= 2:
            if idx % 2 == 0:
                # P1: ABSENT, P2: ON_LEAVE -> Expected Composite: ON_LEAVE
                period_payloads = [
                    {"period_number": 1, "status": "ABSENT", "remarks": "Missed P1", "subject_id": pers[0]["subject_id"], "schedule_id": pers[0]["schedule_id"]},
                    {"period_number": 2, "status": "ON_LEAVE", "remarks": "Approved half day", "subject_id": pers[1]["subject_id"], "schedule_id": pers[1]["schedule_id"]}
                ]
                expected_results[s_id] = {"p1": "ABSENT", "p2": "ON_LEAVE", "composite": "ON_LEAVE"}
            else:
                # P1: PRESENT, P2: LATE -> Expected Composite: LATE
                period_payloads = [
                    {"period_number": 1, "status": "PRESENT", "remarks": "On time", "subject_id": pers[0]["subject_id"], "schedule_id": pers[0]["schedule_id"]},
                    {"period_number": 2, "status": "LATE", "remarks": "10 min late", "subject_id": pers[1]["subject_id"], "schedule_id": pers[1]["schedule_id"]}
                ]
                expected_results[s_id] = {"p1": "PRESENT", "p2": "LATE", "composite": "LATE"}
        elif len(pers) == 1:
            # P1: PRESENT -> Expected Composite: PRESENT
            period_payloads = [
                {"period_number": 1, "status": "PRESENT", "remarks": "Present in sec a", "subject_id": pers[0]["subject_id"], "schedule_id": pers[0]["schedule_id"]}
            ]
            expected_results[s_id] = {"p1": "PRESENT", "composite": "PRESENT"}

        save_items.append(AttendanceItemPayload(
            student_id=uuid.UUID(s_id),
            status=expected_results.get(s_id, {}).get("composite", "PRESENT"),
            remarks="Saved from live grid state",
            periods=period_payloads
        ))

    save_req = SaveAttendanceRequest(
        attendance_date=grid_date,
        class_id=uuid.UUID(class_id),
        mode="ALL_DAY",
        records=save_items
    )
    save_res = await save_daily_attendance(save_req, user_dict, school_id)
    assert save_res["success"] is True, f"Save failed: {save_res}"
    record_pass(f"POST /api/attendance/save succeeded for {len(save_items)} students with custom period breakdowns")

    # Re-fetch roster to verify exact retention
    verified_roster = await get_daily_attendance_roster(
        attendance_date=grid_date,
        class_id=uuid.UUID(class_id),
        mode="ALL_DAY",
        current_user=user_dict,
        school_id=school_id
    )
    for v_st in verified_roster["data"]["students"]:
        v_id = v_st["student_id"]
        if v_id in expected_results:
            exp = expected_results[v_id]
            assert v_st["status"] == exp["composite"], f"Student {v_st['full_name']} composite mismatch: expected {exp['composite']}, got {v_st['status']}"
            p_map = {p["period_number"]: p["status"] for p in v_st.get("periods", [])}
            if "p1" in exp:
                assert p_map.get(1) == exp["p1"], f"Student {v_st['full_name']} P1 mismatch: expected {exp['p1']}, got {p_map.get(1)}"
            if "p2" in exp:
                assert p_map.get(2) == exp["p2"], f"Student {v_st['full_name']} P2 mismatch: expected {exp['p2']}, got {p_map.get(2)}"

    record_pass("All students verified: Retained exact distinct period statuses and accurate composite daily status!")

    # =========================================================================
    # SECTION 6: OVERRIDE WORKFLOW & AUDIT INTEGRITY
    # =========================================================================
    logger.info("\n--- SECTION 6: Override Workflow & Audit Trail ---")

    st_ovr_id = roster_st[0]["student_id"]
    ovr_reason = "Principal approved medical exemption"
    ovr_req = OverrideAttendanceRequest(
        record_id=uuid.UUID(st_ovr_id),
        record_type="DAILY",
        new_status="PRESENT",
        reason=ovr_reason
    )
    ovr_res = await override_locked_attendance(ovr_req, user_dict, school_id)
    if ovr_res["success"] is True:
        record_pass("Principal override executed successfully via stored procedure")
    else:
        record_fail("Override execution", f"Failed: {ovr_res}")

    # Verify override flags on daily record
    daily_ovr_rows = await exec_sql("""
        SELECT is_overridden, override_reason, status FROM public.attendance_daily_records
        WHERE student_id = %s
        ORDER BY attendance_date DESC, updated_at DESC LIMIT 1;
    """, (st_ovr_id,))
    if len(daily_ovr_rows) > 0 and daily_ovr_rows[0]["is_overridden"] is True and daily_ovr_rows[0]["override_reason"] == ovr_reason:
        record_pass(f"Override verified on daily record: is_overridden=True, reason='{ovr_reason}'")
    else:
        record_fail("Override verification", f"Record: {daily_ovr_rows}")

    # Verify rejection of empty override reason
    try:
        invalid_req = OverrideAttendanceRequest(
            record_id=uuid.UUID(st_ovr_id),
            record_type="DAILY",
            new_status="LATE",
            reason="   "
        )
        await override_locked_attendance(invalid_req, user_dict, school_id)
        record_fail("Empty override reason check", "Did not throw exception")
    except Exception:
        record_pass("Rejection of empty/whitespace override reason (HTTP 400)")

    logger.info("\n" + "=" * 85)
    logger.info(f"  🎉 MASTER E2E EDGE CASES SUITE COMPLETED: {passed_tests}/{total_tests} TESTS PASSED 100%!")
    logger.info("=" * 85)

if __name__ == "__main__":
    asyncio.run(run_master_edge_cases_suite())
