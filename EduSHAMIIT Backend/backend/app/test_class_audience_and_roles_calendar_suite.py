import asyncio
import sys
from datetime import datetime, date, timedelta
from app.api.calendar import (
    create_schedule,
    update_schedule,
    delete_schedule,
    get_schedules,
    get_calendar_summary,
    ScheduleCreateRequest,
    ScheduleUpdateRequest,
    RecurrenceRuleSchema,
    ParticipantAssignmentSchema,
    exec_sql,
)

# Test Users
ADMIN_USER = {
    "id": "38a93170-997b-4b4c-bc8e-256b93169c23",
    "role": "super_admin",
    "school_id": "11111111-1111-1111-1111-111111111111",
}

STUDENT_10A_USER = {
    "id": "073cf4b4-7678-4a9d-bca8-a186d4e3bf5e", # naresh@demo.school.com, class: 10A
    "role": "student",
    "school_id": "11111111-1111-1111-1111-111111111111",
}

STUDENT_XB_USER = {
    "id": "10000000-0000-0000-0000-000000000012", # arjun@school.com, class: X-B (Section B)
    "role": "student",
    "school_id": "11111111-1111-1111-1111-111111111111",
}

STUDENT_IXA_USER = {
    "id": "bb000014-0000-0000-0000-000000000014", # kunal.bose@student.eduverse.school, class: IX-A (Grade 9)
    "role": "student",
    "school_id": "11111111-1111-1111-1111-111111111111",
}

STUDENT_XA_ROMAN_USER = {
    "id": "10000000-0000-0000-0000-000000000004", # amit@school.com, class: X-A (Roman equivalent to 10A)
    "role": "student",
    "school_id": "11111111-1111-1111-1111-111111111111",
}

TEACHER_USER = {
    "id": "20000000-0000-0000-0000-000000000001",
    "role": "teacher",
    "school_id": "11111111-1111-1111-1111-111111111111",
}

CAL_ID = "a95ead3e-4d13-46e5-af94-e4a3c545b4f6"

PASSED = 0
FAILED = 0


def log_pass(msg):
    global PASSED
    PASSED += 1
    print(f"  [PASS] {msg}")


def log_fail(msg, err=None):
    global FAILED
    FAILED += 1
    print(f"  [FAIL] {msg} -> Error: {err}")


async def cleanup_test_data():
    await exec_sql(
        "DELETE FROM public.schedules WHERE title LIKE '%%CLASS_TEST_%%';",
        (),
        fetch=False,
    )


async def run_class_audience_tests():
    global PASSED, FAILED, CAL_ID
    print("=" * 80)
    print("STARTING CLASS & ROLE AUDIENCE TARGETING AND ISOLATION TEST MATRIX")
    print("=" * 80)

    # Ensure profile test fixtures have distinct test classes
    await exec_sql("UPDATE public.profiles SET class = '10A' WHERE id = %s;", (STUDENT_10A_USER["id"],), fetch=False)
    await exec_sql("UPDATE public.profiles SET class = 'X-A' WHERE id = %s;", (STUDENT_XA_ROMAN_USER["id"],), fetch=False)
    await exec_sql("UPDATE public.profiles SET class = 'X-B' WHERE id = %s;", (STUDENT_XB_USER["id"],), fetch=False)
    await exec_sql("UPDATE public.profiles SET class = 'IX-A' WHERE id = %s;", (STUDENT_IXA_USER["id"],), fetch=False)

    cals = await exec_sql("SELECT id FROM public.calendars WHERE school_id = %s LIMIT 1", (ADMIN_USER['school_id'],))
    if not cals:
        cals = await exec_sql("SELECT id FROM public.calendars LIMIT 1", ())
    if cals:
        CAL_ID = str(cals[0]['id'])

    await cleanup_test_data()

    # =========================================================================
    # SCENARIO 1: SINGLE NON-RECURRING EVENT ASSIGNED TO CLASS 10A
    # =========================================================================
    print("\n--- SCENARIO 1: SINGLE EVENT ASSIGNED TO CLASS 10A ---")
    try:
        req = ScheduleCreateRequest(
            calendar_id=CAL_ID,
            title="CLASS_TEST_Single_10A",
            start_time="2026-08-10T09:00:00.000",
            end_time="2026-08-10T10:00:00.000",
            timezone="Asia/Kolkata",
            visibility="shared",
            is_recurring=False,
            participants=[
                ParticipantAssignmentSchema(
                    target_class="10A",
                    participant_type="class_section",
                    participation_role="required",
                    permission="can_view",
                )
            ],
        )
        res = await create_schedule(req, user=ADMIN_USER)
        s_id = res["data"]["id"]
        log_pass(f"1.1 Single event created with target_class='10A' (ID: {s_id[:8]})")

        # Student in 10A queries schedules
        schedules_10a = await get_schedules(
            start_date="2026-08-10T00:00:00.000Z",
            end_date="2026-08-10T23:59:59.000Z",
            user=STUDENT_10A_USER,
        )
        ids_10a = [s["id"].split("_inst_")[0] for s in schedules_10a["data"]]
        assert s_id in ids_10a, f"Schedule {s_id} not found for 10A student"
        log_pass("1.2 Student in Class 10A successfully retrieved the single event")

        # Student in X-A (Roman numeral 10A) queries schedules
        schedules_xa_roman = await get_schedules(
            start_date="2026-08-10T00:00:00.000Z",
            end_date="2026-08-10T23:59:59.000Z",
            user=STUDENT_XA_ROMAN_USER,
        )
        ids_xa_roman = [s["id"].split("_inst_")[0] for s in schedules_xa_roman["data"]]
        assert s_id in ids_xa_roman, f"Schedule {s_id} not found for X-A (Roman 10A) student"
        log_pass("1.3 Roman numeral equivalence verified: Student in 'X-A' retrieved '10A' event")

        # Student in X-B (Section B) queries schedules -> MUST NOT SEE IT
        schedules_xb = await get_schedules(
            start_date="2026-08-10T00:00:00.000Z",
            end_date="2026-08-10T23:59:59.000Z",
            user=STUDENT_XB_USER,
        )
        ids_xb = [s["id"].split("_inst_")[0] for s in schedules_xb["data"]]
        assert s_id not in ids_xb, f"Schedule {s_id} leaked to X-B (Section B) student!"
        log_pass("1.4 Student in Class X-B does NOT see the 10A single event (Section Isolation Verified)")

        # Student in IX-A (Grade 9) queries schedules -> MUST NOT SEE IT
        schedules_ixa = await get_schedules(
            start_date="2026-08-10T00:00:00.000Z",
            end_date="2026-08-10T23:59:59.000Z",
            user=STUDENT_IXA_USER,
        )
        ids_ixa = [s["id"].split("_inst_")[0] for s in schedules_ixa["data"]]
        assert s_id not in ids_ixa, f"Schedule {s_id} leaked to IX-A (Grade 9) student!"
        log_pass("1.5 Student in Class IX-A does NOT see the 10A single event (Grade Isolation Verified)")

    except Exception as e:
        log_fail("Scenario 1 failed", e)

    # =========================================================================
    # SCENARIO 2: RECURRING EVENT ASSIGNED TO CLASS 10A (DAILY 4-DAYS)
    # =========================================================================
    print("\n--- SCENARIO 2: RECURRING EVENT ASSIGNED TO CLASS 10A ---")
    try:
        req_rec = ScheduleCreateRequest(
            calendar_id=CAL_ID,
            title="CLASS_TEST_Daily_10A",
            start_time="2026-08-10T11:00:00.000",
            end_time="2026-08-10T12:00:00.000",
            timezone="Asia/Kolkata",
            visibility="shared",
            is_recurring=True,
            recurrence=RecurrenceRuleSchema(
                frequency="daily",
                interval=1,
                end_type="after_count",
                end_count=4,
            ),
            participants=[
                ParticipantAssignmentSchema(
                    target_class="10A",
                    participant_type="class_section",
                    participation_role="required",
                    permission="can_view",
                )
            ],
        )
        res_rec = await create_schedule(req_rec, user=ADMIN_USER)
        rec_s_id = res_rec["data"]["id"]
        log_pass(f"2.1 Recurring daily 4-day event created for Class 10A (ID: {rec_s_id[:8]})")

        # Student in 10A queries full week
        week_10a = await get_schedules(
            start_date="2026-08-10T00:00:00.000Z",
            end_date="2026-08-16T23:59:59.000Z",
            user=STUDENT_10A_USER,
        )
        matched_rec = [s for s in week_10a["data"] if s.get("title") == "CLASS_TEST_Daily_10A"]
        assert len(matched_rec) == 4, f"Expected 4 recurring instances for 10A student, got {len(matched_rec)}"
        log_pass(f"2.2 Student in Class 10A retrieved all 4 daily recurring occurrences")

        # Student in X-B queries full week -> MUST BE 0
        week_xb = await get_schedules(
            start_date="2026-08-10T00:00:00.000Z",
            end_date="2026-08-16T23:59:59.000Z",
            user=STUDENT_XB_USER,
        )
        matched_xb = [s for s in week_xb["data"] if s.get("title") == "CLASS_TEST_Daily_10A"]
        assert len(matched_xb) == 0, f"Expected 0 instances for X-B student, got {len(matched_xb)}"
        log_pass("2.3 Student in Class X-B received 0 instances (Recurring Section Isolation Verified)")

        # Student in IX-A queries full week -> MUST BE 0
        week_ixa = await get_schedules(
            start_date="2026-08-10T00:00:00.000Z",
            end_date="2026-08-16T23:59:59.000Z",
            user=STUDENT_IXA_USER,
        )
        matched_ixa = [s for s in week_ixa["data"] if s.get("title") == "CLASS_TEST_Daily_10A"]
        assert len(matched_ixa) == 0, f"Expected 0 instances for IX-A student, got {len(matched_ixa)}"
        log_pass("2.4 Student in Class IX-A received 0 instances (Recurring Grade Isolation Verified)")

    except Exception as e:
        log_fail("Scenario 2 failed", e)

    # =========================================================================
    # SCENARIO 3: CLASS NAME NORMALIZATION ('Class 10A' vs '10A')
    # =========================================================================
    print("\n--- SCENARIO 3: CLASS NAME NORMALIZATION ('Class 10A' vs '10A') ---")
    try:
        req_norm = ScheduleCreateRequest(
            calendar_id=CAL_ID,
            title="CLASS_TEST_Prefix_Class_10A",
            start_time="2026-08-11T14:00:00.000",
            end_time="2026-08-11T15:00:00.000",
            timezone="Asia/Kolkata",
            visibility="shared",
            is_recurring=False,
            participants=[
                ParticipantAssignmentSchema(
                    target_class="Class 10A",  # With 'Class ' prefix
                    participant_type="class_section",
                    participation_role="required",
                    permission="can_view",
                )
            ],
        )
        res_norm = await create_schedule(req_norm, user=ADMIN_USER)
        norm_s_id = res_norm["data"]["id"]
        log_pass("3.1 Created schedule with target_class='Class 10A'")

        # Student profile class is '10A'
        scheds_norm = await get_schedules(
            start_date="2026-08-11T00:00:00.000Z",
            end_date="2026-08-11T23:59:59.000Z",
            user=STUDENT_10A_USER,
        )
        norm_ids = [s["id"].split("_inst_")[0] for s in scheds_norm["data"]]
        assert norm_s_id in norm_ids, "Prefix normalization failed: 'Class 10A' did not match student class '10A'"
        log_pass("3.2 Prefix normalization verified: 'Class 10A' perfectly matches student with '10A'")

    except Exception as e:
        log_fail("Scenario 3 failed", e)

    # =========================================================================
    # SCENARIO 4: MULTI-CLASS BROADCAST (Class 10A + Class IX-A)
    # =========================================================================
    print("\n--- SCENARIO 4: MULTI-CLASS BROADCAST (Class 10A + Class IX-A) ---")
    try:
        req_multi = ScheduleCreateRequest(
            calendar_id=CAL_ID,
            title="CLASS_TEST_Multi_Class",
            start_time="2026-08-12T10:00:00.000",
            end_time="2026-08-12T11:00:00.000",
            timezone="Asia/Kolkata",
            visibility="shared",
            is_recurring=False,
            participants=[
                ParticipantAssignmentSchema(
                    target_class="10A",
                    participant_type="class_section",
                    participation_role="required",
                ),
                ParticipantAssignmentSchema(
                    target_class="IX-A",
                    participant_type="class_section",
                    participation_role="required",
                ),
            ],
        )
        res_multi = await create_schedule(req_multi, user=ADMIN_USER)
        multi_id = res_multi["data"]["id"]
        log_pass("4.1 Created schedule with 2 class targets (10A and IX-A)")

        # 10A student should see it
        res_10a = await get_schedules(
            start_date="2026-08-12T00:00:00.000Z",
            end_date="2026-08-12T23:59:59.000Z",
            user=STUDENT_10A_USER,
        )
        assert multi_id in [s["id"].split("_inst_")[0] for s in res_10a["data"]]
        log_pass("4.2 Class 10A student retrieved the multi-class schedule")

        # IX-A student should also see it
        res_ixa = await get_schedules(
            start_date="2026-08-12T00:00:00.000Z",
            end_date="2026-08-12T23:59:59.000Z",
            user=STUDENT_IXA_USER,
        )
        assert multi_id in [s["id"].split("_inst_")[0] for s in res_ixa["data"]]
        log_pass("4.3 Class IX-A student retrieved the multi-class schedule")

        # X-B student should NOT see it
        res_xb = await get_schedules(
            start_date="2026-08-12T00:00:00.000Z",
            end_date="2026-08-12T23:59:59.000Z",
            user=STUDENT_XB_USER,
        )
        assert multi_id not in [s["id"].split("_inst_")[0] for s in res_xb["data"]]
        log_pass("4.4 Class X-B student did NOT receive unassigned multi-class schedule (Isolation Verified)")

    except Exception as e:
        log_fail("Scenario 4 failed", e)

    # =========================================================================
    # SCENARIO 5: ROLE-LEVEL BROADCAST (All Students vs All Teachers)
    # =========================================================================
    print("\n--- SCENARIO 5: ROLE-LEVEL BROADCAST (Students vs Teachers) ---")
    try:
        req_role = ScheduleCreateRequest(
            calendar_id=CAL_ID,
            title="CLASS_TEST_All_Students",
            start_time="2026-08-13T15:00:00.000",
            end_time="2026-08-13T16:00:00.000",
            timezone="Asia/Kolkata",
            visibility="shared",
            is_recurring=False,
            participants=[
                ParticipantAssignmentSchema(
                    target_role="student",
                    participant_type="role",
                    participation_role="required",
                )
            ],
        )
        res_role = await create_schedule(req_role, user=ADMIN_USER)
        role_id = res_role["data"]["id"]
        log_pass("5.1 Created schedule for target_role='student'")

        # Both 10A, X-B, and IX-A students should see it
        res_s1 = await get_schedules(start_date="2026-08-13T00:00:00.000Z", end_date="2026-08-13T23:59:59.000Z", user=STUDENT_10A_USER)
        res_s2 = await get_schedules(start_date="2026-08-13T00:00:00.000Z", end_date="2026-08-13T23:59:59.000Z", user=STUDENT_XB_USER)
        res_s3 = await get_schedules(start_date="2026-08-13T00:00:00.000Z", end_date="2026-08-13T23:59:59.000Z", user=STUDENT_IXA_USER)
        assert role_id in [s["id"].split("_inst_")[0] for s in res_s1["data"]]
        assert role_id in [s["id"].split("_inst_")[0] for s in res_s2["data"]]
        assert role_id in [s["id"].split("_inst_")[0] for s in res_s3["data"]]
        log_pass("5.2 All student accounts across different classes received 'All Students' broadcast")

    except Exception as e:
        log_fail("Scenario 5 failed", e)

    # =========================================================================
    # SCENARIO 6: 'ASSIGNED_TO_ME' FILTER FOR CLASS ASSIGNMENTS
    # =========================================================================
    print("\n--- SCENARIO 6: 'ASSIGNED_TO_ME' FILTER FOR CLASS ASSIGNMENTS ---")
    try:
        atm_res = await get_schedules(
            start_date="2026-08-10T00:00:00.000Z",
            end_date="2026-08-16T23:59:59.000Z",
            assigned_to_me=True,
            user=STUDENT_10A_USER,
        )
        atm_titles = [s.get("title") for s in atm_res["data"]]
        assert "CLASS_TEST_Single_10A" in atm_titles
        assert "CLASS_TEST_Multi_Class" in atm_titles
        log_pass("6.1 'assigned_to_me=True' query successfully returned class-assigned schedules")

    except Exception as e:
        log_fail("Scenario 6 failed", e)

    # =========================================================================
    # SCENARIO 7: CALENDAR SUMMARY STORED PROCEDURE FOR CLASS AUDIENCE
    # =========================================================================
    print("\n--- SCENARIO 7: CALENDAR SUMMARY STORED PROCEDURE ---")
    try:
        summary = await get_calendar_summary(user=STUDENT_10A_USER)
        assert summary["success"] is True
        log_pass("7.1 fn_get_calendar_summary executed cleanly with class-audience resolution")

    except Exception as e:
        log_fail("Scenario 7 failed", e)

    # =========================================================================
    # CLEANUP & FINAL REPORT
    # =========================================================================
    await cleanup_test_data()

    print("\n" + "=" * 80)
    print(f"CLASS & ROLE AUDIENCE TEST MATRIX: {PASSED} PASSED, {FAILED} FAILED (SUCCESS RATE: {PASSED / (PASSED + FAILED) * 100:.1f}%)")
    print("=" * 80)

    if FAILED > 0:
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(run_class_audience_tests())
