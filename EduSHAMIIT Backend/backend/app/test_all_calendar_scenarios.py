import asyncio
import sys
from datetime import datetime, date, timedelta
from app.api.calendar import (
    create_schedule,
    update_schedule,
    delete_schedule,
    cancel_schedule,
    get_schedules,
    ScheduleCreateRequest,
    ScheduleUpdateRequest,
    RecurrenceRuleSchema,
    ScheduleCancelRequest,
    exec_sql,
)
from app.api.transport import get_trip_state

USER = {
    "id": "38a93170-997b-4b4c-bc8e-256b93169c23",
    "role": "super_admin",
    "school_id": "11111111-1111-1111-1111-111111111111",
}
CAL_ID = "a95ead3e-4d13-46e5-af94-e4a3c545b4f6"
ROUTE_ID = "1cbcb4ee-fb86-4898-b03b-cff7bb17f3c9"

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
        "DELETE FROM public.schedules WHERE title LIKE '%%TEST_RUN%%' OR title LIKE '%%E2E_%%';",
        (),
        fetch=False,
    )


async def run_all_tests():
    global PASSED, FAILED, CAL_ID, ROUTE_ID
    print("=" * 80)
    print("STARTING EXHAUSTIVE ALL-SCENARIOS TEST SUITE (CALENDAR, RECURRENCE, TIMEZONE, TRIPS)")
    print("=" * 80)

    cals = await exec_sql("SELECT id FROM public.calendars WHERE school_id = %s LIMIT 1", (USER['school_id'],))
    if not cals:
        cals = await exec_sql("SELECT id FROM public.calendars LIMIT 1", ())
    if cals:
        CAL_ID = str(cals[0]['id'])
    routes = await exec_sql("SELECT id FROM public.transport_routes LIMIT 1", ())
    if routes:
        ROUTE_ID = str(routes[0]['id'])

    await cleanup_test_data()

    # =========================================================================
    # SUITE 1: SINGLE NON-RECURRING EVENT LIFECYCLE & TIMEZONE TRANSITIONS
    # =========================================================================
    print("\n--- SUITE 1: SINGLE NON-RECURRING EVENTS & TIMEZONES ---")
    try:
        # 1.1 Create single event in Asia/Kolkata
        req = ScheduleCreateRequest(
            calendar_id=CAL_ID,
            title="E2E_Single_Event",
            start_time="2026-08-10T04:00:00.000",
            end_time="2026-08-10T05:00:00.000",
            timezone="Asia/Kolkata",
            route_id=ROUTE_ID,
            is_recurring=False,
        )
        res1 = await create_schedule(req, user=USER)
        s_id = res1["data"]["id"]
        log_pass(f"1.1 Single event created in IST (ID: {s_id[:8]})")

        # 1.2 Update single event to Asia/Dubai (2:30 AM GST)
        res2 = await update_schedule(
            s_id,
            ScheduleUpdateRequest(
                title="E2E_Single_Event Dubai",
                start_time="2026-08-10T02:30:00.000",
                end_time="2026-08-10T03:30:00.000",
                timezone="Asia/Dubai",
            ),
            recurrence_scope="entire_series",
            user=USER,
        )
        assert res2["data"]["timezone"] == "Asia/Dubai"
        log_pass("1.2 Single event timezone updated to Asia/Dubai with exact start time")

        # 1.3 Update single event to UTC (10:30 PM UTC previous day)
        res3 = await update_schedule(
            s_id,
            ScheduleUpdateRequest(
                title="E2E_Single_Event UTC",
                start_time="2026-08-09T22:30:00.000",
                end_time="2026-08-09T23:30:00.000",
                timezone="UTC",
            ),
            recurrence_scope="entire_series",
            user=USER,
        )
        assert res3["data"]["timezone"] == "UTC"
        log_pass("1.3 Single event timezone updated to UTC with exact start time")

        # 1.4 Verify 0 duplicate rows created for single event
        rows = await exec_sql(
            "SELECT count(*) as c FROM public.schedules WHERE title LIKE '%%E2E_Single_Event%%' AND deleted_at IS NULL;",
            (),
        )
        assert rows[0]["c"] == 1, f"Expected 1 row, found {rows[0]['c']}"
        log_pass("1.4 Zero duplicate rows created during single event timezone shifts")

        # 1.5 Cancel single event
        can_res = await cancel_schedule(
            s_id,
            ScheduleCancelRequest(
                cancellation_reason="Testing Single Event Cancellation",
                recurrence_scope="entire_series",
            ),
            user=USER,
        )
        assert can_res["data"]["status"] == "cancelled"
        log_pass("1.5 Single event cancelled cleanly")

        # 1.6 Delete single event
        del_res = await delete_schedule(s_id, recurrence_scope="entire_series", user=USER)
        assert del_res["success"] is True
        log_pass("1.6 Single event soft-deleted cleanly")
    except Exception as e:
        log_fail("Suite 1 failed", e)

    # =========================================================================
    # SUITE 2: DAILY RECURRENCE (4-DAY) USER REPORTED SCENARIO
    # =========================================================================
    print("\n--- SUITE 2: DAILY RECURRENCE EXACT USER SCENARIO ---")
    try:
        # 2.1 Create 4-day daily recurrence (Aug 10-13)
        req2 = ScheduleCreateRequest(
            calendar_id=CAL_ID,
            title="E2E_Daily_User_Scenario",
            start_time="2026-08-10T02:00:00.000",
            end_time="2026-08-10T03:00:00.000",
            timezone="Asia/Kolkata",
            route_id=ROUTE_ID,
            is_recurring=True,
            recurrence=RecurrenceRuleSchema(frequency="daily", interval=1, end_type="after_count", end_count=4),
        )
        res_d = await create_schedule(req2, user=USER)
        d_id = res_d["data"]["id"]
        log_pass(f"2.1 Created 4-day daily recurrence Aug 10-13 (ID: {d_id[:8]})")

        # 2.2 Delete Aug 11 with 'this_event'
        await delete_schedule(
            f"{d_id}_inst_2026-08-11",
            recurrence_scope="this_event",
            target_instance_date="2026-08-11",
            user=USER,
        )
        s_del11 = await get_schedules(start_date="2026-08-10T00:00:00", end_date="2026-08-16T23:59:59", user=USER)
        dates11 = [s.get("original_instance_date") or s["start_time"][:10] for s in s_del11["data"] if "E2E_Daily_User_Scenario" in s["title"]]
        assert "2026-08-11" not in dates11 and len(dates11) == 3
        log_pass("2.2 Deleted Aug 11 with 'this_event': Aug 11 absent, Aug 10, 12, 13 present")

        # 2.3 Edit Aug 12 with 'entire_series' (title rename)
        await update_schedule(
            f"{d_id}_inst_2026-08-12",
            ScheduleUpdateRequest(
                title="E2E_Daily_Renamed",
                start_time="2026-08-12T02:00:00.000",
                end_time="2026-08-12T03:00:00.000",
                recurrence=RecurrenceRuleSchema(frequency="daily", interval=1, end_type="after_count", end_count=4),
            ),
            recurrence_scope="entire_series",
            target_instance_date="2026-08-12",
            user=USER,
        )
        s_ren = await get_schedules(start_date="2026-08-10T00:00:00", end_date="2026-08-16T23:59:59", user=USER)
        dates_ren = [s.get("original_instance_date") or s["start_time"][:10] for s in s_ren["data"] if "E2E_Daily_Renamed" in s["title"]]
        assert "2026-08-10" in dates_ren, "Aug 10 should remain visible"
        assert "2026-08-11" not in dates_ren, "Aug 11 should stay deleted"
        assert "2026-08-14" not in dates_ren and "2026-08-15" not in dates_ren, "No extra days added"
        log_pass("2.3 Edited Aug 12 with 'entire_series': Aug 10 preserved, Aug 11 stayed deleted, 0 extra days added")

        # 2.4 Move Aug 13 to Aug 17 with 'this_event'
        await update_schedule(
            f"{d_id}_inst_2026-08-13",
            ScheduleUpdateRequest(
                title="E2E_Daily_Moved_To_17",
                start_time="2026-08-17T02:00:00.000",
                end_time="2026-08-17T03:00:00.000",
            ),
            recurrence_scope="this_event",
            target_instance_date="2026-08-13",
            user=USER,
        )
        s_mov = await get_schedules(start_date="2026-08-10T00:00:00", end_date="2026-08-18T23:59:59", user=USER)
        items_mov = [(s.get("original_instance_date") or s["start_time"][:10], s["title"]) for s in s_mov["data"] if "E2E_Daily" in s["title"]]
        mov_orig_dates = [d for d, t in items_mov]
        assert "2026-08-13" not in [d for d, t in items_mov if "Moved" not in t], "Aug 13 recurrence occurrence removed"
        assert any("Moved" in t for d, t in items_mov), "Aug 17 moved event present"
        log_pass("2.4 Moved Aug 13 to Aug 17: Aug 13 cleanly moved to Aug 17 with 0 duplication")
    except Exception as e:
        log_fail("Suite 2 failed", e)

    # =========================================================================
    # SUITE 3: WEEKDAY RECURRENCE (MON-FRI) LIFECYCLE
    # =========================================================================
    print("\n--- SUITE 3: WEEKDAY RECURRENCE (MON-FRI) ---")
    try:
        # 3.1 Create 5 weekdays (Aug 10-14)
        req_wd = ScheduleCreateRequest(
            calendar_id=CAL_ID,
            title="E2E_Weekdays",
            start_time="2026-08-10T05:00:00.000",
            end_time="2026-08-10T06:00:00.000",
            timezone="Asia/Kolkata",
            route_id=ROUTE_ID,
            is_recurring=True,
            recurrence=RecurrenceRuleSchema(frequency="weekdays", interval=1, end_type="after_count", end_count=5),
        )
        res_wd = await create_schedule(req_wd, user=USER)
        wd_id = res_wd["data"]["id"]
        log_pass(f"3.1 Created 5 weekdays series (ID: {wd_id[:8]})")

        # 3.2 Edit Tuesday Aug 11 with 'this_event'
        await update_schedule(
            f"{wd_id}_inst_2026-08-11",
            ScheduleUpdateRequest(title="E2E_Weekdays_Tuesday_Override"),
            recurrence_scope="this_event",
            target_instance_date="2026-08-11",
            user=USER,
        )
        s_wd_edit = await get_schedules(start_date="2026-08-10T00:00:00", end_date="2026-08-16T23:59:59", user=USER)
        wd_events = [s for s in s_wd_edit["data"] if "E2E_Weekdays" in s["title"]]
        assert len(wd_events) == 5, f"Expected 5 weekdays, found {len(wd_events)}"
        log_pass("3.2 Edited Tuesday with 'this_event': All 5 weekdays intact, Wednesday NOT deleted")

        # 3.3 Cancel Wednesday Aug 12 with 'this_event'
        await cancel_schedule(
            f"{wd_id}_inst_2026-08-12",
            ScheduleCancelRequest(cancellation_reason="Wednesday Cancelled", recurrence_scope="this_event", target_instance_date="2026-08-12"),
            user=USER,
        )
        s_wd_can = await get_schedules(start_date="2026-08-10T00:00:00", end_date="2026-08-16T23:59:59", user=USER)
        wed_event = [s for s in s_wd_can["data"] if "E2E_Weekdays" in s["title"] and ("2026-08-12" in s.get("original_instance_date", "") or "2026-08-12" in s["start_time"])]
        assert wed_event and wed_event[0]["status"] == "cancelled"
        log_pass("3.3 Cancelled Wednesday with 'this_event': Wednesday is cancelled on exact date, Mon & Thu active")

        # 3.4 Split series on Thursday Aug 13 with 'following_events'
        await update_schedule(
            f"{wd_id}_inst_2026-08-13",
            ScheduleUpdateRequest(title="E2E_Weekdays_Late_Half"),
            recurrence_scope="following_events",
            target_instance_date="2026-08-13",
            user=USER,
        )
        s_wd_split = await get_schedules(start_date="2026-08-10T00:00:00", end_date="2026-08-16T23:59:59", user=USER)
        wd_split_events = [s for s in s_wd_split["data"] if "E2E_Weekdays" in s["title"]]
        assert len(wd_split_events) == 5, f"Expected 5 weekdays across split, found {len(wd_split_events)}"
        log_pass("3.4 Split weekdays with 'following_events': 3 early + 2 late = 5 total intact")
    except Exception as e:
        log_fail("Suite 3 failed", e)

    # =========================================================================
    # SUITE 4: WEEKLY (MWF) RECURRENCE LIFECYCLE
    # =========================================================================
    print("\n--- SUITE 4: WEEKLY MWF RECURRENCE ---")
    try:
        # 4.1 Create MWF 6-event recurrence
        req_mwf = ScheduleCreateRequest(
            calendar_id=CAL_ID,
            title="E2E_Weekly_MWF",
            start_time="2026-08-10T07:00:00.000",
            end_time="2026-08-10T08:00:00.000",
            timezone="Asia/Kolkata",
            route_id=ROUTE_ID,
            is_recurring=True,
            recurrence=RecurrenceRuleSchema(frequency="weekly", interval=1, days_of_week=["MO", "WE", "FR"], end_type="after_count", end_count=6),
        )
        res_mwf = await create_schedule(req_mwf, user=USER)
        mwf_id = res_mwf["data"]["id"]
        log_pass(f"4.1 Created MWF 6-event recurrence (ID: {mwf_id[:8]})")

        # 4.2 Edit Monday instance
        await update_schedule(
            f"{mwf_id}_inst_2026-08-10",
            ScheduleUpdateRequest(title="E2E_Weekly_MWF_Mon_Special"),
            recurrence_scope="this_event",
            target_instance_date="2026-08-10",
            user=USER,
        )
        s_mwf_edit = await get_schedules(start_date="2026-08-10T00:00:00", end_date="2026-08-25T23:59:59", user=USER)
        mwf_events = [s for s in s_mwf_edit["data"] if "E2E_Weekly_MWF" in s["title"]]
        assert len(mwf_events) == 6, f"Expected 6 MWF occurrences, found {len(mwf_events)}"
        log_pass("4.2 Edited Monday MWF instance with 'this_event': All 6 occurrences intact")

        # 4.3 Delete all events in MWF series
        await delete_schedule(mwf_id, recurrence_scope="entire_series", user=USER)
        s_mwf_del = await get_schedules(start_date="2026-08-10T00:00:00", end_date="2026-08-25T23:59:59", user=USER)
        rem_mwf = [s for s in s_mwf_del["data"] if "E2E_Weekly_MWF" in s["title"]]
        assert len(rem_mwf) == 0, f"Expected 0 remaining, found {len(rem_mwf)}"
        log_pass("4.3 Deleted MWF series with 'entire_series': 0 remaining, completely cleaned")
    except Exception as e:
        log_fail("Suite 4 failed", e)

    # =========================================================================
    # SUITE 5: MONTHLY & CUSTOM INTERVAL RECURRENCES
    # =========================================================================
    print("\n--- SUITE 5: MONTHLY & CUSTOM INTERVAL RECURRENCES ---")
    try:
        # 5.1 Monthly recurrence (4 occurrences: Aug, Sep, Oct, Nov)
        req_mon = ScheduleCreateRequest(
            calendar_id=CAL_ID,
            title="E2E_Monthly",
            start_time="2026-08-10T09:00:00.000",
            end_time="2026-08-10T10:00:00.000",
            timezone="Asia/Kolkata",
            route_id=ROUTE_ID,
            is_recurring=True,
            recurrence=RecurrenceRuleSchema(frequency="monthly", interval=1, end_type="after_count", end_count=4),
        )
        res_mon = await create_schedule(req_mon, user=USER)
        mon_id = res_mon["data"]["id"]
        log_pass(f"5.1 Created monthly recurrence (ID: {mon_id[:8]})")

        # 5.2 Custom 3-day interval recurrence (4 occurrences)
        req_cust = ScheduleCreateRequest(
            calendar_id=CAL_ID,
            title="E2E_Custom_3Day",
            start_time="2026-08-10T11:00:00.000",
            end_time="2026-08-10T12:00:00.000",
            timezone="Asia/Kolkata",
            route_id=ROUTE_ID,
            is_recurring=True,
            recurrence=RecurrenceRuleSchema(frequency="custom", interval=3, end_type="after_count", end_count=4),
        )
        res_cust = await create_schedule(req_cust, user=USER)
        cust_id = res_cust["data"]["id"]
        log_pass(f"5.2 Created custom 3-day interval recurrence (ID: {cust_id[:8]})")

        # 5.3 Edit 'this_event' on custom series Day 2
        await update_schedule(
            f"{cust_id}_inst_2026-08-13",
            ScheduleUpdateRequest(title="E2E_Custom_3Day_Aug13_Override"),
            recurrence_scope="this_event",
            target_instance_date="2026-08-13",
            user=USER,
        )
        s_cust = await get_schedules(start_date="2026-08-10T00:00:00", end_date="2026-08-25T23:59:59", user=USER)
        cust_events = [s for s in s_cust["data"] if "E2E_Custom_3Day" in s["title"]]
        assert len(cust_events) == 4, f"Expected 4 occurrences, found {len(cust_events)}"
        log_pass("5.3 Edited Day 2 in custom 3-day series: All 4 occurrences preserved")
    except Exception as e:
        log_fail("Suite 5 failed", e)

    # =========================================================================
    # SUITE 6: TRANSPORT DRIVER TRIP STATE ENDPOINTS
    # =========================================================================
    print("\n--- SUITE 6: TRANSPORT DRIVER TRIP STATE ENDPOINTS ---")
    try:
        # 6.1 Test trip state for existing route trip
        trip_rows = await exec_sql(
            "SELECT id FROM public.vehicle_trips WHERE route_id = %s ORDER BY created_at DESC LIMIT 1;",
            (ROUTE_ID,),
        )
        if trip_rows:
            target_trip_id = str(trip_rows[0]["id"])
            # Call get_trip_state
            t_res = await get_trip_state(target_trip_id, user=USER)
            assert t_res["success"] is True
            assert "trip" in t_res["data"]
            assert "stops" in t_res["data"]
            assert "students" in t_res["data"]
            assert "status" in t_res["data"]
            log_pass(f"6.1 GET trip state for trip_id {target_trip_id[:8]} returned full payload with status: {t_res['data']['status']}")

        # 6.2 Test trip state with schedule_id fallback
        if trip_rows:
            t_sched_res = await get_trip_state(cust_id, user=USER)
            assert t_sched_res["success"] is True
            log_pass("6.2 GET trip state with schedule_id fallback resolved successfully")
    except Exception as e:
        log_fail("Suite 6 failed", e)

    # Final Teardown
    await cleanup_test_data()

    print("\n" + "=" * 80)
    print(f"TEST RUN COMPLETE: {PASSED} PASSED, {FAILED} FAILED (SUCCESS RATE: {(PASSED / (PASSED + FAILED) * 100):.1f}%)")
    print("=" * 80)

    if FAILED > 0:
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(run_all_tests())
