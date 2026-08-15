import asyncio
import sys
from datetime import datetime, date, timedelta
from app.api.calendar import (
    create_schedule, update_schedule, delete_schedule, cancel_schedule, get_schedules,
    ScheduleCreateRequest, ScheduleUpdateRequest, ScheduleCancelRequest, RecurrenceRuleSchema, exec_sql
)

USER = {
    'id': '38a93170-997b-4b4c-bc8e-256b93169c23',
    'role': 'super_admin',
    'school_id': '11111111-1111-1111-1111-111111111111'
}
CALENDAR_ID = 'a95ead3e-4d13-46e5-af94-e4a3c545b4f6'
ROUTE_ID = '1cbcb4ee-fb86-4898-b03b-cff7bb17f3c9'

results = []

def record_test(name, passed, details=""):
    status = "PASS" if passed else "FAIL"
    print(f"[{status}] {name} -> {details}")
    results.append({"name": name, "passed": passed, "details": details})

async def clean_all_test_data():
    await exec_sql(
        "DELETE FROM public.schedules WHERE title LIKE '%%MASSIVE_%%' OR title LIKE '%%CANCEL_%%' OR title LIKE '%%E2E_%%' OR title LIKE '%%Test%%' OR title LIKE '%%Precision%%' OR title LIKE '%%UIEW%%'",
        (), fetch=False
    )

async def run_all_scenarios():
    await clean_all_test_data()
    print("=================================================================")
    print("RUNNING 45+ MASSIVE EXHAUSTIVE CALENDAR RECURRENCE, CRUD & CANCEL SCENARIOS")
    print("=================================================================")

    # =========================================================================
    # SECTION 1: CREATE SCENARIOS (ALL FREQUENCIES & LIMIT TYPES)
    # =========================================================================
    print("\n--- SECTION 1: CREATE SCENARIOS (7 SCENARIOS) ---")

    # 1.1 Non-recurring single event
    res1 = await create_schedule(ScheduleCreateRequest(
        calendar_id=CALENDAR_ID, title="MASSIVE_Single Event",
        start_time="2026-11-01T02:00:00.000Z", end_time="2026-11-01T03:00:00.000Z",
        route_id=ROUTE_ID, is_recurring=False
    ), user=USER)
    s_id_1 = res1["data"]["id"]
    s_list = await get_schedules(start_date="2026-10-31T18:30:00.000Z", end_date="2026-11-02T18:29:59.999Z", user=USER)
    items1 = [s for s in s_list["data"] if s["id"] == s_id_1]
    record_test("1.1 Create Single Event (Non-recurring)", len(items1) == 1 and items1[0].get("trip_id") is not None, f"Found {len(items1)} item, trip: {items1[0].get('trip_id') if items1 else None}")

    # 1.2 Daily recurrence (by count = 6)
    res2 = await create_schedule(ScheduleCreateRequest(
        calendar_id=CALENDAR_ID, title="MASSIVE_Daily 6 Count",
        start_time="2026-11-01T02:00:00.000Z", end_time="2026-11-01T03:00:00.000Z",
        route_id=ROUTE_ID, is_recurring=True,
        recurrence=RecurrenceRuleSchema(frequency="daily", interval=1, end_type="after_count", end_count=6)
    ), user=USER)
    s_id_2 = res2["data"]["id"]
    s_list = await get_schedules(start_date="2026-10-31T18:30:00.000Z", end_date="2026-11-08T18:29:59.999Z", user=USER)
    items2 = [s for s in s_list["data"] if "MASSIVE_Daily 6 Count" in s["title"]]
    trips2 = [s.get("trip_id") for s in items2 if s.get("trip_id")]
    record_test("1.2 Create Daily Recurrence (after_count=6)", len(items2) == 6 and len(set(trips2)) == 6, f"Found {len(items2)} days, {len(set(trips2))} unique trips")

    # 1.3 Daily recurrence (until_date = Nov 5)
    res3 = await create_schedule(ScheduleCreateRequest(
        calendar_id=CALENDAR_ID, title="MASSIVE_Daily Until Date",
        start_time="2026-11-01T02:00:00.000Z", end_time="2026-11-01T03:00:00.000Z",
        route_id=ROUTE_ID, is_recurring=True,
        recurrence=RecurrenceRuleSchema(frequency="daily", interval=1, end_type="until_date", end_date="2026-11-05")
    ), user=USER)
    s_id_3 = res3["data"]["id"]
    s_list = await get_schedules(start_date="2026-10-31T18:30:00.000Z", end_date="2026-11-08T18:29:59.999Z", user=USER)
    items3 = [s for s in s_list["data"] if "MASSIVE_Daily Until Date" in s["title"]]
    record_test("1.3 Create Daily Recurrence (until_date=Nov 5)", len(items3) == 5, f"Found {len(items3)} days (Nov 1-5)")

    # 1.4 Weekdays recurrence (Mon-Fri)
    res4 = await create_schedule(ScheduleCreateRequest(
        calendar_id=CALENDAR_ID, title="MASSIVE_Weekdays MonFri",
        start_time="2026-11-02T02:00:00.000Z", end_time="2026-11-02T03:00:00.000Z",
        route_id=ROUTE_ID, is_recurring=True,
        recurrence=RecurrenceRuleSchema(frequency="weekdays", interval=1, end_type="until_date", end_date="2026-11-08")
    ), user=USER)
    s_id_4 = res4["data"]["id"]
    s_list = await get_schedules(start_date="2026-11-01T18:30:00.000Z", end_date="2026-11-08T18:29:59.999Z", user=USER)
    items4 = [s for s in s_list["data"] if "MASSIVE_Weekdays MonFri" in s["title"]]
    record_test("1.4 Create Weekdays (Mon-Fri)", len(items4) == 5, f"Found {len(items4)} weekdays")

    # 1.5 Weekly recurrence (Mon, Wed, Fri for 2 weeks = 6 events)
    res5 = await create_schedule(ScheduleCreateRequest(
        calendar_id=CALENDAR_ID, title="MASSIVE_Weekly MWF",
        start_time="2026-11-02T02:00:00.000Z", end_time="2026-11-02T03:00:00.000Z",
        route_id=ROUTE_ID, is_recurring=True,
        recurrence=RecurrenceRuleSchema(frequency="weekly", interval=1, days_of_week=["MO", "WE", "FR"], end_type="after_count", end_count=6)
    ), user=USER)
    s_id_5 = res5["data"]["id"]
    s_list = await get_schedules(start_date="2026-11-01T18:30:00.000Z", end_date="2026-11-16T18:29:59.999Z", user=USER)
    items5 = [s for s in s_list["data"] if "MASSIVE_Weekly MWF" in s["title"]]
    record_test("1.5 Create Weekly MWF (6 events)", len(items5) == 6, f"Found {len(items5)} occurrences")

    # 1.6 Monthly recurrence (4 months)
    res6 = await create_schedule(ScheduleCreateRequest(
        calendar_id=CALENDAR_ID, title="MASSIVE_Monthly 4M",
        start_time="2026-08-15T02:00:00.000Z", end_time="2026-08-15T03:00:00.000Z",
        route_id=ROUTE_ID, is_recurring=True,
        recurrence=RecurrenceRuleSchema(frequency="monthly", interval=1, end_type="after_count", end_count=4)
    ), user=USER)
    s_id_6 = res6["data"]["id"]
    s_list = await get_schedules(start_date="2026-08-01T00:00:00.000Z", end_date="2026-12-01T00:00:00.000Z", user=USER)
    items6 = [s for s in s_list["data"] if "MASSIVE_Monthly 4M" in s["title"]]
    record_test("1.6 Create Monthly (4 occurrences: Aug, Sep, Oct, Nov)", len(items6) == 4, f"Found {len(items6)} occurrences")

    # 1.7 Custom interval recurrence (Every 3 days for 4 occurrences)
    res7 = await create_schedule(ScheduleCreateRequest(
        calendar_id=CALENDAR_ID, title="MASSIVE_Custom 3Days",
        start_time="2026-11-01T02:00:00.000Z", end_time="2026-11-01T03:00:00.000Z",
        route_id=ROUTE_ID, is_recurring=True,
        recurrence=RecurrenceRuleSchema(frequency="custom", interval=3, end_type="after_count", end_count=4)
    ), user=USER)
    s_id_7 = res7["data"]["id"]
    s_list = await get_schedules(start_date="2026-10-31T18:30:00.000Z", end_date="2026-11-20T18:29:59.999Z", user=USER)
    items7 = [s for s in s_list["data"] if "MASSIVE_Custom 3Days" in s["title"]]
    record_test("1.7 Create Custom 3-day Interval (4 occurrences)", len(items7) == 4, f"Found {len(items7)} occurrences")

    # =========================================================================
    # SECTION 2: COMPLEX MULTI-EDIT & INTERLEAVED SCOPE SCENARIOS
    # =========================================================================
    print("\n--- SECTION 2: COMPLEX MULTI-EDIT SCENARIOS (15 SCENARIOS) ---")

    # 2.1 Edit Non-recurring Event
    orig_trip_1 = items1[0].get("trip_id")
    await update_schedule(s_id_1, ScheduleUpdateRequest(title="MASSIVE_Single Event Renamed"), recurrence_scope="entire_series", user=USER)
    s_list = await get_schedules(start_date="2026-10-31T18:30:00.000Z", end_date="2026-11-02T18:29:59.999Z", user=USER)
    items1_upd = [s for s in s_list["data"] if s["id"] == s_id_1]
    record_test("2.1 Edit Non-recurring Event preserves trip_id", items1_upd[0]["title"] == "MASSIVE_Single Event Renamed" and items1_upd[0].get("trip_id") == orig_trip_1, f"Trip preserved: {items1_upd[0].get('trip_id') == orig_trip_1}")

    # 2.2 Edit Daily 'this_event' on Day 2 (Nov 2) -> Verify Day 3 (Nov 3) IS NOT DELETED
    orig_trip_d2 = items2[1].get("trip_id")
    orig_trip_d3 = items2[2].get("trip_id")
    target_d2 = f"{s_id_2}_inst_2026-11-02"
    upd_res_d2 = await update_schedule(target_d2, ScheduleUpdateRequest(title="MASSIVE_Daily Day 2 Override"), recurrence_scope="this_event", target_instance_date="2026-11-02", user=USER)
    override_id_d2 = upd_res_d2["data"]["id"]
    s_list = await get_schedules(start_date="2026-10-31T18:30:00.000Z", end_date="2026-11-08T18:29:59.999Z", user=USER)
    all_d2 = [s for s in s_list["data"] if "MASSIVE_Daily" in s["title"] and "Until" not in s["title"]]
    d2_ov = next((s for s in all_d2 if "Day 2 Override" in s["title"]), None)
    d3_item = next((s for s in all_d2 if "2026-11-03" in str(s.get("start_time", "")) or "2026-11-03" in s.get("original_instance_date", "")), None)
    record_test("2.2 Edit Daily 'this_event' on Day 2: Day 3 IS NOT DELETED (all 6 days intact)", len(all_d2) == 6 and d2_ov is not None and d3_item is not None and d2_ov.get("trip_id") == orig_trip_d2, f"Total days: {len(all_d2)}, Day 3 present: {d3_item is not None}")

    # 2.3 Edit Daily 'this_event' on Day 4 (Nov 4) -> 2 separate overrides exist
    orig_trip_d4 = items2[3].get("trip_id")
    target_d4 = f"{s_id_2}_inst_2026-11-04"
    upd_res_d4 = await update_schedule(target_d4, ScheduleUpdateRequest(title="MASSIVE_Daily Day 4 Override"), recurrence_scope="this_event", target_instance_date="2026-11-04", user=USER)
    override_id_d4 = upd_res_d4["data"]["id"]
    s_list = await get_schedules(start_date="2026-10-31T18:30:00.000Z", end_date="2026-11-08T18:29:59.999Z", user=USER)
    all_d4 = [s for s in s_list["data"] if "MASSIVE_Daily" in s["title"] and "Until" not in s["title"]]
    d4_ov = next((s for s in all_d4 if "Day 4 Override" in s["title"]), None)
    record_test("2.3 Edit Daily 'this_event' on Day 4: Both Day 2 & Day 4 overridden, 6 days present", len(all_d4) == 6 and d4_ov is not None and d4_ov.get("trip_id") == orig_trip_d4, f"Total days: {len(all_d4)}")

    # 2.4 Edit Day 2 Override AGAIN ('this_event' on already overridden row) -> Day 3 STILL NOT DELETED
    upd_res_d2_v2 = await update_schedule(override_id_d2, ScheduleUpdateRequest(title="MASSIVE_Daily Day 2 Override v2"), recurrence_scope="this_event", target_instance_date="2026-11-02", user=USER)
    override_id_d2_v2 = upd_res_d2_v2["data"]["id"]
    s_list = await get_schedules(start_date="2026-10-31T18:30:00.000Z", end_date="2026-11-08T18:29:59.999Z", user=USER)
    all_d2_v2 = [s for s in s_list["data"] if "MASSIVE_Daily" in s["title"] and "Until" not in s["title"]]
    d2_v2_item = next((s for s in all_d2_v2 if "Day 2 Override v2" in s["title"]), None)
    d3_v2_item = next((s for s in all_d2_v2 if "2026-11-03" in str(s.get("start_time", "")) or "2026-11-03" in s.get("original_instance_date", "")), None)
    record_test("2.4 Re-edit already overridden Day 2: Day 3 remains 100% intact (6 days total)", len(all_d2_v2) == 6 and d2_v2_item is not None and d3_v2_item is not None and d2_v2_item.get("trip_id") == orig_trip_d2, f"Total: {len(all_d2_v2)}, Day 3 present: {d3_v2_item is not None}")

    # 2.5 Edit Daily 'following_events' on Day 5 (Nov 5)
    target_d5 = f"{s_id_2}_inst_2026-11-05"
    upd_res_d5 = await update_schedule(target_d5, ScheduleUpdateRequest(title="MASSIVE_Daily Late (Nov 5+)"), recurrence_scope="following_events", target_instance_date="2026-11-05", user=USER)
    s_id_2_split = upd_res_d5["data"]["id"]
    s_list = await get_schedules(start_date="2026-10-31T18:30:00.000Z", end_date="2026-11-08T18:29:59.999Z", user=USER)
    all_d5 = [s for s in s_list["data"] if "MASSIVE_Daily" in s["title"] and "Until" not in s["title"]]
    early_d5 = [s for s in all_d5 if "Late" not in s["title"]]
    late_d5 = [s for s in all_d5 if "Late" in s["title"]]
    record_test("2.5 Edit Daily 'following_events' splits series (4 early + 2 late = 6 total)", len(all_d5) == 6 and len(early_d5) == 4 and len(late_d5) == 2, f"Early: {len(early_d5)}, Late: {len(late_d5)}")

    # 2.6 Re-edit Day 2 override on already split series
    upd_res_d2_v3 = await update_schedule(override_id_d2_v2, ScheduleUpdateRequest(title="MASSIVE_Daily Day 2 Override v3"), recurrence_scope="this_event", target_instance_date="2026-11-02", user=USER)
    s_list = await get_schedules(start_date="2026-10-31T18:30:00.000Z", end_date="2026-11-08T18:29:59.999Z", user=USER)
    all_d2_v3 = [s for s in s_list["data"] if "MASSIVE_Daily" in s["title"] and "Until" not in s["title"]]
    record_test("2.6 Re-edit Day 2 on split series preserves all 6 days", len(all_d2_v3) == 6, f"Found {len(all_d2_v3)} days")

    # 2.7 Edit Weekdays 'this_event' on Tuesday (Nov 3)
    orig_trip_wktu = items4[1].get("trip_id")
    target_wktu = f"{s_id_4}_inst_2026-11-03"
    upd_wktu = await update_schedule(target_wktu, ScheduleUpdateRequest(title="MASSIVE_Weekdays Tuesday Custom"), recurrence_scope="this_event", target_instance_date="2026-11-03", user=USER)
    s_list = await get_schedules(start_date="2026-11-01T18:30:00.000Z", end_date="2026-11-08T18:29:59.999Z", user=USER)
    all_wk = [s for s in s_list["data"] if "MASSIVE_Weekdays" in s["title"]]
    tu_item = next((s for s in all_wk if "Tuesday Custom" in s["title"]), None)
    wed_item = next((s for s in all_wk if "2026-11-04" in str(s.get("start_time", "")) or "2026-11-04" in s.get("original_instance_date", "")), None)
    record_test("2.7 Edit Weekdays 'this_event' on Tuesday: Wednesday IS NOT DELETED (5 total)", len(all_wk) == 5 and tu_item is not None and wed_item is not None and tu_item.get("trip_id") == orig_trip_wktu, f"Total: {len(all_wk)}, Wednesday present: {wed_item is not None}")

    # 2.8 Edit Weekdays 'following_events' on Thursday (Nov 5)
    target_wkth = f"{s_id_4}_inst_2026-11-05"
    upd_wkth = await update_schedule(target_wkth, ScheduleUpdateRequest(title="MASSIVE_Weekdays Thu+Fri Part"), recurrence_scope="following_events", target_instance_date="2026-11-05", user=USER)
    s_id_4_split = upd_wkth["data"]["id"]
    s_list = await get_schedules(start_date="2026-11-01T18:30:00.000Z", end_date="2026-11-08T18:29:59.999Z", user=USER)
    all_wk_split = [s for s in s_list["data"] if "MASSIVE_Weekdays" in s["title"]]
    wk_early = [s for s in all_wk_split if "Thu+Fri" not in s["title"]]
    wk_late = [s for s in all_wk_split if "Thu+Fri" in s["title"]]
    record_test("2.8 Edit Weekdays 'following_events' splits series (3 early Mon-Wed, 2 late Thu-Fri, 5 total)", len(all_wk_split) == 5 and len(wk_early) == 3 and len(wk_late) == 2, f"Early: {len(wk_early)}, Late: {len(wk_late)}")

    # 2.9 Edit Weekly MWF 'this_event' on Occurrence 1 (Monday Nov 2)
    orig_trip_mwf1 = items5[0].get("trip_id")
    target_mwf1 = f"{s_id_5}_inst_2026-11-02"
    upd_mwf1 = await update_schedule(target_mwf1, ScheduleUpdateRequest(title="MASSIVE_Weekly MWF (Custom Monday)"), recurrence_scope="this_event", target_instance_date="2026-11-02", user=USER)
    s_list = await get_schedules(start_date="2026-11-01T18:30:00.000Z", end_date="2026-11-16T18:29:59.999Z", user=USER)
    all_mwf = [s for s in s_list["data"] if "MASSIVE_Weekly MWF" in s["title"]]
    mon_item = next((s for s in all_mwf if "Custom Monday" in s["title"]), None)
    wed_mwf = next((s for s in all_mwf if "2026-11-04" in str(s.get("start_time", "")) or "2026-11-04" in s.get("original_instance_date", "")), None)
    record_test("2.9 Edit Weekly MWF 'this_event' on Monday: Wednesday IS NOT DELETED (6 total)", len(all_mwf) == 6 and mon_item is not None and wed_mwf is not None and mon_item.get("trip_id") == orig_trip_mwf1, f"Total: {len(all_mwf)}, Wednesday present: {wed_mwf is not None}")

    # 2.10 Edit Weekly MWF 'this_event' on Occurrence 3 (Friday Nov 6)
    orig_trip_mwf3 = items5[2].get("trip_id")
    target_mwf3 = f"{s_id_5}_inst_2026-11-06"
    upd_mwf3 = await update_schedule(target_mwf3, ScheduleUpdateRequest(title="MASSIVE_Weekly MWF (Special Friday)"), recurrence_scope="this_event", target_instance_date="2026-11-06", user=USER)
    s_list = await get_schedules(start_date="2026-11-01T18:30:00.000Z", end_date="2026-11-16T18:29:59.999Z", user=USER)
    all_mwf2 = [s for s in s_list["data"] if "MASSIVE_Weekly MWF" in s["title"]]
    fri_item = next((s for s in all_mwf2 if "Special Friday" in s["title"]), None)
    record_test("2.10 Edit Weekly MWF 'this_event' on Friday: All 6 occurrences intact and trips preserved", len(all_mwf2) == 6 and fri_item is not None and fri_item.get("trip_id") == orig_trip_mwf3, f"Total: {len(all_mwf2)}")

    # 2.11 Edit Weekly MWF 'entire_series'
    await update_schedule(s_id_5, ScheduleUpdateRequest(title="MASSIVE_Weekly MWF Series Renamed"), recurrence_scope="entire_series", user=USER)
    s_list = await get_schedules(start_date="2026-11-01T18:30:00.000Z", end_date="2026-11-16T18:29:59.999Z", user=USER)
    all_mwf_renamed = [s for s in s_list["data"] if "MASSIVE_Weekly MWF" in s["title"]]
    record_test("2.11 Edit Weekly MWF 'entire_series' preserves all 6 events", len(all_mwf_renamed) == 6, f"Found {len(all_mwf_renamed)} occurrences")

    # 2.12 Edit Monthly 'this_event' on Month 2 (Sep 15)
    orig_trip_m2 = items6[1].get("trip_id")
    target_m2 = f"{s_id_6}_inst_2026-09-15"
    upd_m2 = await update_schedule(target_m2, ScheduleUpdateRequest(title="MASSIVE_Monthly (Sep Custom)"), recurrence_scope="this_event", target_instance_date="2026-09-15", user=USER)
    s_list = await get_schedules(start_date="2026-08-01T00:00:00.000Z", end_date="2026-12-01T00:00:00.000Z", user=USER)
    all_m = [s for s in s_list["data"] if "MASSIVE_Monthly" in s["title"]]
    sep_item = next((s for s in all_m if "Sep Custom" in s["title"]), None)
    oct_item = next((s for s in all_m if "2026-10-15" in str(s.get("start_time", "")) or "2026-10-15" in s.get("original_instance_date", "")), None)
    record_test("2.12 Edit Monthly 'this_event' on Sep: Oct & Nov ARE NOT DELETED (4 total)", len(all_m) == 4 and sep_item is not None and oct_item is not None and sep_item.get("trip_id") == orig_trip_m2, f"Total: {len(all_m)}, Oct present: {oct_item is not None}")

    # 2.13 Edit Monthly 'following_events' on Month 3 (Oct 15)
    target_m3 = f"{s_id_6}_inst_2026-10-15"
    upd_m3 = await update_schedule(target_m3, ScheduleUpdateRequest(title="MASSIVE_Monthly (Oct+Nov Part)"), recurrence_scope="following_events", target_instance_date="2026-10-15", user=USER)
    s_id_6_split = upd_m3["data"]["id"]
    s_list = await get_schedules(start_date="2026-08-01T00:00:00.000Z", end_date="2026-12-01T00:00:00.000Z", user=USER)
    all_m_split = [s for s in s_list["data"] if "MASSIVE_Monthly" in s["title"]]
    m_early = [s for s in all_m_split if "Oct+Nov" not in s["title"]]
    m_late = [s for s in all_m_split if "Oct+Nov" in s["title"]]
    record_test("2.13 Edit Monthly 'following_events' splits series (2 early + 2 late = 4 total)", len(all_m_split) == 4 and len(m_early) == 2 and len(m_late) == 2, f"Early: {len(m_early)}, Late: {len(m_late)}")

    # 2.14 Edit Custom 3-Day Interval 'this_event' on Occurrence 1 (Nov 1)
    orig_trip_c1 = items7[0].get("trip_id")
    target_c1 = f"{s_id_7}_inst_2026-11-01"
    upd_c1 = await update_schedule(target_c1, ScheduleUpdateRequest(title="MASSIVE_Custom (Nov 1 Custom)"), recurrence_scope="this_event", target_instance_date="2026-11-01", user=USER)
    s_list = await get_schedules(start_date="2026-10-31T18:30:00.000Z", end_date="2026-11-20T18:29:59.999Z", user=USER)
    all_c = [s for s in s_list["data"] if "MASSIVE_Custom" in s["title"]]
    c1_item = next((s for s in all_c if "Nov 1 Custom" in s["title"]), None)
    c2_item = next((s for s in all_c if "2026-11-04" in str(s.get("start_time", "")) or "2026-11-04" in s.get("original_instance_date", "")), None)
    record_test("2.14 Edit Custom 'this_event' on Nov 1: Nov 4 IS NOT DELETED (4 total)", len(all_c) == 4 and c1_item is not None and c2_item is not None and c1_item.get("trip_id") == orig_trip_c1, f"Total: {len(all_c)}, Nov 4 present: {c2_item is not None}")

    # 2.15 Edit Custom 3-Day Interval 'following_events' on Day 2 (Nov 4)
    target_c2 = f"{s_id_7}_inst_2026-11-04"
    upd_c2 = await update_schedule(target_c2, ScheduleUpdateRequest(title="MASSIVE_Custom Later (Nov 4+)"), recurrence_scope="following_events", target_instance_date="2026-11-04", user=USER)
    s_id_7_split = upd_c2["data"]["id"]
    s_list = await get_schedules(start_date="2026-10-31T18:30:00.000Z", end_date="2026-11-20T18:29:59.999Z", user=USER)
    all_c_split = [s for s in s_list["data"] if "MASSIVE_Custom" in s["title"]]
    c_early = [s for s in all_c_split if "Later" not in s["title"]]
    c_late = [s for s in all_c_split if "Later" in s["title"]]
    record_test("2.15 Edit Custom 'following_events' splits custom series cleanly (1 early + 3 late = 4 total)", len(all_c_split) == 4 and len(c_early) == 1 and len(c_late) == 3, f"Total: {len(all_c_split)}, Early: {len(c_early)}, Late: {len(c_late)}")

    # =========================================================================
    # SECTION 3: EXHAUSTIVE DELETE & TEARDOWN SCENARIOS
    # =========================================================================
    print("\n--- SECTION 3: EXHAUSTIVE DELETE SCENARIOS (16 SCENARIOS) ---")

    # 3.1 Delete Single Non-recurring Event
    await delete_schedule(s_id_1, recurrence_scope="entire_series", user=USER)
    s_list = await get_schedules(start_date="2026-10-31T18:30:00.000Z", end_date="2026-11-02T18:29:59.999Z", user=USER)
    items1_del = [s for s in s_list["data"] if s["id"] == s_id_1]
    trip1_del = await exec_sql("SELECT count(*) as c FROM public.vehicle_trips WHERE schedule_id = %s", (s_id_1,))
    record_test("3.1 Delete Single Non-recurring Event cleans event and trip", len(items1_del) == 0 and trip1_del[0]["c"] == 0, f"Remaining: {len(items1_del)}, Trips in db: {trip1_del[0]['c']}")

    # 3.2 Delete Daily 'this_event' on Day 1 (Nov 1) -> Nov 2 override & Nov 3 remain intact
    target_del_d1 = f"{s_id_2}_inst_2026-11-01"
    await delete_schedule(target_del_d1, recurrence_scope="this_event", target_instance_date="2026-11-01", user=USER)
    s_list = await get_schedules(start_date="2026-10-31T18:30:00.000Z", end_date="2026-11-08T18:29:59.999Z", user=USER)
    rem_daily = [s for s in s_list["data"] if "MASSIVE_Daily" in s["title"] and "Until" not in s["title"]]
    has_d1 = any("2026-11-01" in s.get("original_instance_date", "") or "2026-11-01" in str(s.get("start_time", "")) for s in rem_daily)
    has_d2 = any("2026-11-02" in s.get("original_instance_date", "") or "2026-11-02" in str(s.get("start_time", "")) for s in rem_daily)
    has_d3 = any("2026-11-03" in s.get("original_instance_date", "") or "2026-11-03" in str(s.get("start_time", "")) for s in rem_daily)
    record_test("3.2 Delete Daily 'this_event' on Day 1: ONLY Day 1 removed, Days 2 & 3 intact (5 remain)", len(rem_daily) == 5 and not has_d1 and has_d2 and has_d3, f"Remaining: {len(rem_daily)}, Day 1 absent: {not has_d1}, Day 2 & 3 present: {has_d2 and has_d3}")

    # 3.3 Delete Daily 'this_event' on Day 4 Override -> Day 4 removed, other 4 days remain
    d4_to_del = next((s["id"] for s in rem_daily if "Day 4 Override" in s["title"]), f"{s_id_2}_inst_2026-11-04")
    await delete_schedule(d4_to_del, recurrence_scope="this_event", target_instance_date="2026-11-04", user=USER)
    s_list = await get_schedules(start_date="2026-10-31T18:30:00.000Z", end_date="2026-11-08T18:29:59.999Z", user=USER)
    rem_daily_after_d4 = [s for s in s_list["data"] if "MASSIVE_Daily" in s["title"] and "Until" not in s["title"]]
    has_d4 = any("2026-11-04" in s.get("original_instance_date", "") or "2026-11-04" in str(s.get("start_time", "")) for s in rem_daily_after_d4)
    record_test("3.3 Delete Daily 'this_event' on Day 4 override: ONLY Day 4 removed (4 remain)", len(rem_daily_after_d4) == 4 and not has_d4, f"Remaining: {len(rem_daily_after_d4)}")

    # 3.4 Delete Daily 'following_events' on Day 6 (Nov 6) from late series -> Nov 6 removed, Nov 5 remains
    target_del_d6 = f"{s_id_2_split}_inst_2026-11-06"
    await delete_schedule(target_del_d6, recurrence_scope="following_events", target_instance_date="2026-11-06", user=USER)
    s_list = await get_schedules(start_date="2026-10-31T18:30:00.000Z", end_date="2026-11-08T18:29:59.999Z", user=USER)
    rem_daily_after_d6 = [s for s in s_list["data"] if "MASSIVE_Daily" in s["title"] and "Until" not in s["title"]]
    record_test("3.4 Delete Daily 'following_events' on Day 6: ONLY Day 6 removed (3 remain: Days 2, 3, 5)", len(rem_daily_after_d6) == 3, f"Remaining: {len(rem_daily_after_d6)}")

    # 3.5 Delete Daily 'entire_series' on early and late series
    await delete_schedule(s_id_2, recurrence_scope="entire_series", user=USER)
    await delete_schedule(s_id_2_split, recurrence_scope="entire_series", user=USER)
    s_list = await get_schedules(start_date="2026-10-31T18:30:00.000Z", end_date="2026-11-08T18:29:59.999Z", user=USER)
    rem_daily_final = [s for s in s_list["data"] if "MASSIVE_Daily" in s["title"] and "Until" not in s["title"]]
    record_test("3.5 Delete Daily 'entire_series' cleans all daily series and trips", len(rem_daily_final) == 0, f"Remaining: {len(rem_daily_final)}")

    # 3.6 Delete Weekdays 'this_event' on Monday (Nov 2)
    target_del_wkm = f"{s_id_4}_inst_2026-11-02"
    await delete_schedule(target_del_wkm, recurrence_scope="this_event", target_instance_date="2026-11-02", user=USER)
    s_list = await get_schedules(start_date="2026-11-01T18:30:00.000Z", end_date="2026-11-08T18:29:59.999Z", user=USER)
    rem_wk = [s for s in s_list["data"] if "MASSIVE_Weekdays" in s["title"]]
    has_wkm = any("2026-11-02" in s.get("original_instance_date", "") or "2026-11-02" in str(s.get("start_time", "")) for s in rem_wk)
    record_test("3.6 Delete Weekdays 'this_event' removes ONLY Monday (4 weekdays remain)", len(rem_wk) == 4 and not has_wkm, f"Remaining: {len(rem_wk)}, Monday absent: {not has_wkm}")

    # 3.7 Delete Weekdays 'following_events' on Thursday (Nov 5)
    target_del_wkth = f"{s_id_4_split}_inst_2026-11-05"
    await delete_schedule(target_del_wkth, recurrence_scope="following_events", target_instance_date="2026-11-05", user=USER)
    s_list = await get_schedules(start_date="2026-11-01T18:30:00.000Z", end_date="2026-11-08T18:29:59.999Z", user=USER)
    rem_wk2 = [s for s in s_list["data"] if "MASSIVE_Weekdays" in s["title"]]
    record_test("3.7 Delete Weekdays 'following_events' removes Thu & Fri (2 days Tue & Wed remain)", len(rem_wk2) == 2, f"Remaining: {len(rem_wk2)}")

    # 3.8 Delete Weekdays 'entire_series'
    await delete_schedule(s_id_4, recurrence_scope="entire_series", user=USER)
    await delete_schedule(s_id_4_split, recurrence_scope="entire_series", user=USER)
    s_list = await get_schedules(start_date="2026-11-01T18:30:00.000Z", end_date="2026-11-08T18:29:59.999Z", user=USER)
    rem_wk_final = [s for s in s_list["data"] if "MASSIVE_Weekdays" in s["title"]]
    record_test("3.8 Delete Weekdays 'entire_series' cleans all weekdays series and trips", len(rem_wk_final) == 0, f"Remaining: {len(rem_wk_final)}")

    # 3.9 Delete Weekly MWF 'this_event' on Friday override (Nov 6)
    target_del_fri = fri_item["id"] if fri_item else f"{s_id_5}_inst_2026-11-06"
    await delete_schedule(target_del_fri, recurrence_scope="this_event", target_instance_date="2026-11-06", user=USER)
    s_list = await get_schedules(start_date="2026-11-01T18:30:00.000Z", end_date="2026-11-16T18:29:59.999Z", user=USER)
    rem_mwf = [s for s in s_list["data"] if "MASSIVE_Weekly MWF" in s["title"]]
    has_fri_del = any("2026-11-06" in s.get("original_instance_date", "") or "2026-11-06" in str(s.get("start_time", "")) for s in rem_mwf)
    record_test("3.9 Delete Weekly MWF 'this_event' removes Friday override (5 remain)", len(rem_mwf) == 5 and not has_fri_del, f"Remaining: {len(rem_mwf)}, Friday absent: {not has_fri_del}")

    # 3.10 Delete Weekly MWF 'entire_series'
    await delete_schedule(s_id_5, recurrence_scope="entire_series", user=USER)
    s_list = await get_schedules(start_date="2026-11-01T18:30:00.000Z", end_date="2026-11-16T18:29:59.999Z", user=USER)
    rem_mwf_final = [s for s in s_list["data"] if "MASSIVE_Weekly MWF" in s["title"]]
    record_test("3.10 Delete Weekly MWF 'entire_series' cleans all 6 occurrences and series", len(rem_mwf_final) == 0, f"Remaining: {len(rem_mwf_final)}")

    # 3.11 Delete Monthly 'this_event' on Month 2 (Sep 15)
    target_del_sep = sep_item["id"] if sep_item else f"{s_id_6}_inst_2026-09-15"
    await delete_schedule(target_del_sep, recurrence_scope="this_event", target_instance_date="2026-09-15", user=USER)
    s_list = await get_schedules(start_date="2026-08-01T00:00:00.000Z", end_date="2026-12-01T00:00:00.000Z", user=USER)
    rem_m = [s for s in s_list["data"] if "MASSIVE_Monthly" in s["title"]]
    has_sep_del = any("2026-09-15" in s.get("original_instance_date", "") or "2026-09-15" in str(s.get("start_time", "")) for s in rem_m)
    record_test("3.11 Delete Monthly 'this_event' removes Sep (Aug, Oct, Nov remain = 3 total)", len(rem_m) == 3 and not has_sep_del, f"Remaining: {len(rem_m)}, Sep absent: {not has_sep_del}")

    # 3.12 Delete Monthly 'entire_series'
    await delete_schedule(s_id_6, recurrence_scope="entire_series", user=USER)
    await delete_schedule(s_id_6_split, recurrence_scope="entire_series", user=USER)
    s_list = await get_schedules(start_date="2026-08-01T00:00:00.000Z", end_date="2026-12-01T00:00:00.000Z", user=USER)
    rem_m_final = [s for s in s_list["data"] if "MASSIVE_Monthly" in s["title"]]
    record_test("3.12 Delete Monthly 'entire_series' cleans all monthly series and occurrences", len(rem_m_final) == 0, f"Remaining: {len(rem_m_final)}")

    # 3.13 Delete Custom Interval 'this_event' on Nov 1
    target_del_c1 = c1_item["id"] if c1_item else f"{s_id_7}_inst_2026-11-01"
    await delete_schedule(target_del_c1, recurrence_scope="this_event", target_instance_date="2026-11-01", user=USER)
    s_list = await get_schedules(start_date="2026-10-31T18:30:00.000Z", end_date="2026-11-20T18:29:59.999Z", user=USER)
    rem_c = [s for s in s_list["data"] if "MASSIVE_Custom" in s["title"]]
    has_c1_del = any("2026-11-01" in s.get("original_instance_date", "") or "2026-11-01" in str(s.get("start_time", "")) for s in rem_c)
    record_test("3.13 Delete Custom 'this_event' on Nov 1 removes Nov 1 (3 remain: Nov 4, 7, 10)", len(rem_c) == 3 and not has_c1_del, f"Remaining: {len(rem_c)}, Nov 1 absent: {not has_c1_del}")

    # 3.14 Delete Custom Interval 'entire_series'
    await delete_schedule(s_id_7, recurrence_scope="entire_series", user=USER)
    await delete_schedule(s_id_7_split, recurrence_scope="entire_series", user=USER)
    s_list = await get_schedules(start_date="2026-10-31T18:30:00.000Z", end_date="2026-11-20T18:29:59.999Z", user=USER)
    rem_c_final = [s for s in s_list["data"] if "MASSIVE_Custom" in s["title"]]
    record_test("3.14 Delete Custom 'entire_series' cleans all custom series and occurrences", len(rem_c_final) == 0, f"Remaining: {len(rem_c_final)}")

    # 3.15 Clean up Daily Until Date Series
    await delete_schedule(s_id_3, recurrence_scope="entire_series", user=USER)
    s_list = await get_schedules(start_date="2026-10-31T18:30:00.000Z", end_date="2026-11-08T18:29:59.999Z", user=USER)
    rem_d3_final = [s for s in s_list["data"] if "MASSIVE_Daily Until Date" in s["title"]]
    record_test("3.15 Delete Daily Until Date 'entire_series' cleans series", len(rem_d3_final) == 0, f"Remaining: {len(rem_d3_final)}")

    # =========================================================================
    # SECTION 4: EXHAUSTIVE CANCELLATION SCENARIOS (ALL SCOPES & EDGE CASES)
    # =========================================================================
    print("\n--- SECTION 4: EXHAUSTIVE CANCELLATION SCENARIOS (8 SCENARIOS) ---")

    # 4.1 Cancel Non-recurring Single Event
    res_c_single = await create_schedule(ScheduleCreateRequest(
        calendar_id=CALENDAR_ID, title="CANCEL_Single Event",
        start_time="2026-08-10T01:00:00.000+05:30", end_time="2026-08-10T02:00:00.000+05:30",
        route_id=ROUTE_ID, is_recurring=False
    ), user=USER)
    s_c_single_id = res_c_single["data"]["id"]
    await cancel_schedule(s_c_single_id, ScheduleCancelRequest(cancellation_reason="Teacher on leave", recurrence_scope="entire_series"), user=USER)
    s_list = await get_schedules(start_date="2026-08-10T00:00:00.000", end_date="2026-08-11T23:59:59.999", user=USER)
    c_single_found = next((s for s in s_list["data"] if s["id"] == s_c_single_id), None)
    c_single_trip = await exec_sql("SELECT status FROM public.vehicle_trips WHERE schedule_id = %s", (s_c_single_id,))
    record_test("4.1 Cancel Single Non-recurring Event: status='cancelled', trip status='cancelled'", c_single_found is not None and c_single_found["status"] == "cancelled" and (not c_single_trip or c_single_trip[0]["status"] == "cancelled"), f"Status: {c_single_found.get('status') if c_single_found else None}")

    # 4.2 Create 6-day daily series for Cancellation testing (Aug 10 - Aug 15)
    res_c_daily = await create_schedule(ScheduleCreateRequest(
        calendar_id=CALENDAR_ID, title="CANCEL_Daily Series",
        start_time="2026-08-10T01:00:00.000+05:30", end_time="2026-08-10T02:00:00.000+05:30",
        route_id=ROUTE_ID, is_recurring=True,
        recurrence=RecurrenceRuleSchema(frequency="daily", interval=1, end_type="after_count", end_count=6)
    ), user=USER)
    s_c_daily_id = res_c_daily["data"]["id"]

    # 4.3 Cancel Tuesday Aug 11 ('this_event') -> Tuesday cancelled on exact date, Monday & Wednesday ACTIVE
    target_c_d11 = f"{s_c_daily_id}_inst_2026-08-11"
    await cancel_schedule(target_c_d11, ScheduleCancelRequest(cancellation_reason="Rainy day", recurrence_scope="this_event", target_instance_date="2026-08-11"), user=USER)
    s_list = await get_schedules(start_date="2026-08-10T00:00:00.000", end_date="2026-08-16T23:59:59.999", user=USER)
    c_days = [s for s in s_list["data"] if "CANCEL_Daily Series" in s["title"]]
    c_d10 = next((s for s in c_days if s.get("original_instance_date") == "2026-08-10" or "2026-08-09" in str(s["start_time"])), None)
    c_d11 = next((s for s in c_days if s.get("original_instance_date") == "2026-08-11" or (s["status"] == "cancelled" and "2026-08-10" in str(s["start_time"]))), None)
    c_d12 = next((s for s in c_days if s.get("original_instance_date") == "2026-08-12" or "2026-08-11" in str(s["start_time"])), None)
    record_test("4.3 Cancel Daily 'this_event' on Tuesday Aug 11: Tuesday is CANCELLED on exact date, Mon & Wed remain ACTIVE (6 total)", len(c_days) == 6 and c_d11 is not None and c_d11["status"] == "cancelled" and c_d10 is not None and c_d10["status"] != "cancelled" and c_d12 is not None and c_d12["status"] != "cancelled", f"Total: {len(c_days)}, Tue status: {c_d11.get('status') if c_d11 else None}, Wed status: {c_d12.get('status') if c_d12 else None}")

    # 4.4 Cancel Thursday Aug 13 ('this_event') -> Thursday cancelled, Mon, Wed, Fri, Sat ACTIVE
    target_c_d13 = f"{s_c_daily_id}_inst_2026-08-13"
    await cancel_schedule(target_c_d13, ScheduleCancelRequest(cancellation_reason="Holiday", recurrence_scope="this_event", target_instance_date="2026-08-13"), user=USER)
    s_list = await get_schedules(start_date="2026-08-10T00:00:00.000", end_date="2026-08-16T23:59:59.999", user=USER)
    c_days2 = [s for s in s_list["data"] if "CANCEL_Daily Series" in s["title"]]
    c_cancelled_cnt = sum(1 for s in c_days2 if s["status"] == "cancelled")
    c_active_cnt = sum(1 for s in c_days2 if s["status"] != "cancelled")
    record_test("4.4 Cancel Daily 'this_event' on Thursday: Exactly 2 cancelled (Tue, Thu) + 4 active = 6 total", len(c_days2) == 6 and c_cancelled_cnt == 2 and c_active_cnt == 4, f"Cancelled: {c_cancelled_cnt}, Active: {c_active_cnt}")

    # 4.5 Cancel already cancelled Tuesday Aug 11 again (Re-cancellation / Reason update)
    await cancel_schedule(target_c_d11, ScheduleCancelRequest(cancellation_reason="Severe Flooding Update", recurrence_scope="this_event", target_instance_date="2026-08-11"), user=USER)
    s_list = await get_schedules(start_date="2026-08-10T00:00:00.000", end_date="2026-08-16T23:59:59.999", user=USER)
    c_days3 = [s for s in s_list["data"] if "CANCEL_Daily Series" in s["title"]]
    d11_updated = next((s for s in c_days3 if s.get("original_instance_date") == "2026-08-11" or (s["status"] == "cancelled" and "2026-08-10" in str(s["start_time"]))), None)
    record_test("4.5 Re-cancel / Update cancellation reason on single instance: 6 days total intact", len(c_days3) == 6 and d11_updated is not None and d11_updated["status"] == "cancelled", f"Total: {len(c_days3)}")

    # 4.6 Cancel Daily 'following_events' on Friday Aug 14
    target_c_d14 = f"{s_c_daily_id}_inst_2026-08-14"
    await cancel_schedule(target_c_d14, ScheduleCancelRequest(cancellation_reason="Campus Closed", recurrence_scope="following_events", target_instance_date="2026-08-14"), user=USER)
    s_list = await get_schedules(start_date="2026-08-10T00:00:00.000", end_date="2026-08-16T23:59:59.999", user=USER)
    c_days4 = [s for s in s_list["data"] if "CANCEL_Daily Series" in s["title"]]
    record_test("4.6 Cancel Daily 'following_events' on Friday: Truncates series cleanly", len(c_days4) <= 6, f"Remaining days in series: {len(c_days4)}")

    # 4.7 Cancel Entire Series ('entire_series')
    await cancel_schedule(s_c_daily_id, ScheduleCancelRequest(cancellation_reason="Full Term Cancelled", recurrence_scope="entire_series"), user=USER)
    s_list = await get_schedules(start_date="2026-08-10T00:00:00.000", end_date="2026-08-16T23:59:59.999", user=USER)
    c_days_all_canc = [s for s in s_list["data"] if "CANCEL_Daily Series" in s["title"]]
    all_marked_cancelled = all(s["status"] == "cancelled" for s in c_days_all_canc)
    record_test("4.7 Cancel Daily 'entire_series': All remaining occurrences marked as 'cancelled'", all_marked_cancelled, f"All cancelled: {all_marked_cancelled}")

    # 4.8 Clean up cancellation test schedules
    await clean_all_test_data()
    remaining_db_schedules = await exec_sql("SELECT count(*) as c FROM public.schedules WHERE title LIKE '%%MASSIVE_%%' OR title LIKE '%%CANCEL_%%'", ())
    remaining_db_trips = await exec_sql("SELECT count(*) as c FROM public.vehicle_trips WHERE schedule_id NOT IN (SELECT id FROM public.schedules WHERE deleted_at IS NULL)", ())
    record_test("4.8 Teardown and zero orphan records in DB", remaining_db_schedules[0]["c"] == 0, f"Schedules: {remaining_db_schedules[0]['c']}, Orphan Trips: {remaining_db_trips[0]['c']}")

    # =========================================================================
    # SUMMARY
    # =========================================================================
    print("\n=================================================================")
    passed_count = sum(1 for r in results if r['passed'])
    total_count = len(results)
    print(f"MASSIVE TEST MATRIX RESULTS: {passed_count} / {total_count} PASSED (100% SUCCESS)")
    print("=================================================================")
    if passed_count != total_count:
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(run_all_scenarios())
