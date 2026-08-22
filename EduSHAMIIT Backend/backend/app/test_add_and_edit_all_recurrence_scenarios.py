import asyncio
import json
import logging
from datetime import datetime, timedelta
from typing import Dict, Any, List

from app.api.calendar import (
    create_schedule,
    update_schedule,
    get_schedule_by_id,
    get_schedules,
    ScheduleCreateRequest,
    ScheduleUpdateRequest,
    RecurrenceRuleSchema,
    exec_sql,
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("TestAddAndEditRecurrence")

async def run_all_add_and_edit_tests():
    logger.info("==========================================================================")
    logger.info("  STARTING COMPREHENSIVE ADD & EDIT MULTI-FREQUENCY RECURRENCE TEST SUITE ")
    logger.info("==========================================================================")

    # 1. Setup School and User
    school_rows = await exec_sql("SELECT id FROM public.schools LIMIT 1")
    school_id = str(school_rows[0]["id"])
    
    user_rows = await exec_sql("SELECT id, role, full_name FROM public.profiles WHERE school_id = %s LIMIT 1", (school_id,))
    user_id = str(user_rows[0]["id"])
    user_dict = {"id": user_id, "school_id": school_id, "role": user_rows[0]["role"]}
    
    logger.info(f"Connected to Tenant: {school_id}, User: {user_rows[0]['full_name']} ({user_id})")

    created_schedule_ids = []

    try:
        # =====================================================================
        # PART 1: TESTING ALL "ADD" (CREATE) RECURRENCE SCENARIOS
        # =====================================================================
        logger.info("\n==================================================")
        logger.info("       PART 1: TESTING ALL 'ADD' SCENARIOS        ")
        logger.info("==================================================")

        # ADD 1: Daily with 3 occurrences (after_count: 3)
        logger.info("\n--- [ADD 1] Daily with 3 occurrences (interval: 1, end_type: after_count, end_count: 3) ---")
        req_add_1 = ScheduleCreateRequest(
            title="Add Test - Daily 3 Occurrences",
            schedule_type="Meeting",
            category="General",
            start_time="2026-08-22T09:00:00.000",
            end_time="2026-08-22T10:00:00.000",
            is_recurring=True,
            recurrence=RecurrenceRuleSchema(
                frequency="daily",
                interval=1,
                end_type="after_count",
                end_count=3
            )
        )
        res_add_1 = await create_schedule(req=req_add_1, user=user_dict)
        s_id_1 = res_add_1["data"]["id"]
        created_schedule_ids.append(s_id_1)
        
        # Verify in DB
        rec_1 = await exec_sql("SELECT * FROM public.schedule_recurrence WHERE schedule_id = %s", (s_id_1,))
        assert len(rec_1) == 1 and rec_1[0]["frequency"] == "daily" and rec_1[0]["end_count"] == 3
        # Verify calendar projection
        proj_1 = await get_schedules(start_date="2026-08-20T00:00:00", end_date="2026-09-05T23:59:59", user=user_dict)
        matching_1 = [s for s in proj_1["data"] if s.get("id") == s_id_1 or s.get("parent_schedule_id") == s_id_1]
        assert len(matching_1) == 3, f"Expected 3 occurrences, got {len(matching_1)}"
        dates_1 = [str(s["start_time"])[:10] for s in matching_1]
        logger.info(f"✅ [ADD 1] PASSED: Generated occurrences: {dates_1}")

        # ADD 2: Daily every 2 days with 4 occurrences (interval: 2, after_count: 4)
        logger.info("\n--- [ADD 2] Daily Every 2 Days (interval: 2, end_type: after_count, end_count: 4) ---")
        req_add_2 = ScheduleCreateRequest(
            title="Add Test - Alternate Days (Interval 2)",
            schedule_type="Training",
            category="General",
            start_time="2026-08-22T10:00:00.000",
            end_time="2026-08-22T11:00:00.000",
            is_recurring=True,
            recurrence=RecurrenceRuleSchema(
                frequency="daily",
                interval=2,
                end_type="after_count",
                end_count=4
            )
        )
        res_add_2 = await create_schedule(req=req_add_2, user=user_dict)
        s_id_2 = res_add_2["data"]["id"]
        created_schedule_ids.append(s_id_2)
        
        proj_2 = await get_schedules(start_date="2026-08-20T00:00:00", end_date="2026-09-05T23:59:59", user=user_dict)
        matching_2 = [s for s in proj_2["data"] if s.get("id") == s_id_2 or s.get("parent_schedule_id") == s_id_2]
        assert len(matching_2) == 4, f"Expected 4 occurrences, got {len(matching_2)}"
        dates_2 = sorted([str(s["start_time"])[:10] for s in matching_2])
        logger.info(f"✅ [ADD 2] PASSED: Generated every 2 days: {dates_2}")
        assert dates_2 == ["2026-08-22", "2026-08-24", "2026-08-26", "2026-08-28"]

        # ADD 3: Daily until Date (until_date: '2026-08-26')
        logger.info("\n--- [ADD 3] Daily with End Date (end_type: until_date, end_date: '2026-08-26') ---")
        req_add_3 = ScheduleCreateRequest(
            title="Add Test - Until Date 2026-08-26",
            schedule_type="Task",
            category="General",
            start_time="2026-08-22T11:00:00.000",
            end_time="2026-08-22T12:00:00.000",
            is_recurring=True,
            recurrence=RecurrenceRuleSchema(
                frequency="daily",
                interval=1,
                end_type="until_date",
                end_date="2026-08-26"
            )
        )
        res_add_3 = await create_schedule(req=req_add_3, user=user_dict)
        s_id_3 = res_add_3["data"]["id"]
        created_schedule_ids.append(s_id_3)
        
        proj_3 = await get_schedules(start_date="2026-08-20T00:00:00", end_date="2026-09-05T23:59:59", user=user_dict)
        matching_3 = [s for s in proj_3["data"] if s.get("id") == s_id_3 or s.get("parent_schedule_id") == s_id_3]
        dates_3 = sorted([str(s["start_time"])[:10] for s in matching_3])
        logger.info(f"✅ [ADD 3] PASSED: Generated until Aug 26: {dates_3}")
        assert dates_3 == ["2026-08-22", "2026-08-23", "2026-08-24", "2026-08-25", "2026-08-26"]

        # ADD 4: Weekdays (Mon-Fri) with 5 occurrences
        logger.info("\n--- [ADD 4] Weekdays (Mon-Fri, after_count: 5) ---")
        req_add_4 = ScheduleCreateRequest(
            title="Add Test - Weekdays (Friday start)",
            schedule_type="Class",
            category="Academics",
            start_time="2026-08-21T09:00:00.000", # Friday
            end_time="2026-08-21T10:00:00.000",
            is_recurring=True,
            recurrence=RecurrenceRuleSchema(
                frequency="weekdays",
                interval=1,
                end_type="after_count",
                end_count=5
            )
        )
        res_add_4 = await create_schedule(req=req_add_4, user=user_dict)
        s_id_4 = res_add_4["data"]["id"]
        created_schedule_ids.append(s_id_4)
        
        proj_4 = await get_schedules(start_date="2026-08-20T00:00:00", end_date="2026-09-05T23:59:59", user=user_dict)
        matching_4 = [s for s in proj_4["data"] if s.get("id") == s_id_4 or s.get("parent_schedule_id") == s_id_4]
        dates_4 = sorted([str(s["start_time"])[:10] for s in matching_4])
        logger.info(f"✅ [ADD 4] PASSED: Weekdays skipping weekend: {dates_4}")
        # Friday Aug 21, Mon Aug 24, Tue Aug 25, Wed Aug 26, Thu Aug 27
        assert dates_4 == ["2026-08-21", "2026-08-24", "2026-08-25", "2026-08-26", "2026-08-27"]

        # ADD 5: Weekly on Mon, Wed, Fri with 6 occurrences
        logger.info("\n--- [ADD 5] Weekly on Mon, Wed, Fri (days_of_week: ['MO', 'WE', 'FR'], after_count: 6) ---")
        req_add_5 = ScheduleCreateRequest(
            title="Add Test - Weekly MWF",
            schedule_type="Meeting",
            category="General",
            start_time="2026-08-24T09:00:00.000", # Monday
            end_time="2026-08-24T10:00:00.000",
            is_recurring=True,
            recurrence=RecurrenceRuleSchema(
                frequency="weekly",
                interval=1,
                days_of_week=["MO", "WE", "FR"],
                end_type="after_count",
                end_count=6
            )
        )
        res_add_5 = await create_schedule(req=req_add_5, user=user_dict)
        s_id_5 = res_add_5["data"]["id"]
        created_schedule_ids.append(s_id_5)
        
        proj_5 = await get_schedules(start_date="2026-08-20T00:00:00", end_date="2026-09-10T23:59:59", user=user_dict)
        matching_5 = [s for s in proj_5["data"] if s.get("id") == s_id_5 or s.get("parent_schedule_id") == s_id_5]
        dates_5 = sorted([str(s["start_time"])[:10] for s in matching_5])
        logger.info(f"✅ [ADD 5] PASSED: Weekly MWF 6 occurrences: {dates_5}")
        assert dates_5 == ["2026-08-24", "2026-08-26", "2026-08-28", "2026-08-31", "2026-09-02", "2026-09-04"]

        # ADD 6: Monthly with 3 occurrences
        logger.info("\n--- [ADD 6] Monthly (after_count: 3) ---")
        req_add_6 = ScheduleCreateRequest(
            title="Add Test - Monthly Review",
            schedule_type="Meeting",
            category="General",
            start_time="2026-08-22T14:00:00.000",
            end_time="2026-08-22T15:00:00.000",
            is_recurring=True,
            recurrence=RecurrenceRuleSchema(
                frequency="monthly",
                interval=1,
                end_type="after_count",
                end_count=3
            )
        )
        res_add_6 = await create_schedule(req=req_add_6, user=user_dict)
        s_id_6 = res_add_6["data"]["id"]
        created_schedule_ids.append(s_id_6)
        
        proj_6 = await get_schedules(start_date="2026-08-01T00:00:00", end_date="2026-11-30T23:59:59", user=user_dict)
        matching_6 = [s for s in proj_6["data"] if s.get("id") == s_id_6 or s.get("parent_schedule_id") == s_id_6]
        dates_6 = sorted([str(s["start_time"])[:10] for s in matching_6])
        logger.info(f"✅ [ADD 6] PASSED: Monthly 3 occurrences: {dates_6}")
        assert dates_6 == ["2026-08-22", "2026-09-22", "2026-10-22"]

        # ADD 7: Yearly (Annual)
        logger.info("\n--- [ADD 7] Yearly (Annual, after_count: 2) ---")
        req_add_7 = ScheduleCreateRequest(
            title="Add Test - Annual Celebration",
            schedule_type="Event",
            category="General",
            start_time="2026-08-22T10:00:00.000",
            end_time="2026-08-22T12:00:00.000",
            is_recurring=True,
            recurrence=RecurrenceRuleSchema(
                frequency="yearly",
                interval=1,
                end_type="after_count",
                end_count=2
            )
        )
        res_add_7 = await create_schedule(req=req_add_7, user=user_dict)
        s_id_7 = res_add_7["data"]["id"]
        created_schedule_ids.append(s_id_7)
        
        proj_7 = await get_schedules(start_date="2026-01-01T00:00:00", end_date="2028-01-01T23:59:59", user=user_dict)
        matching_7 = [s for s in proj_7["data"] if s.get("id") == s_id_7 or s.get("parent_schedule_id") == s_id_7]
        dates_7 = sorted([str(s["start_time"])[:10] for s in matching_7])
        logger.info(f"✅ [ADD 7] PASSED: Yearly 2 occurrences: {dates_7}")
        assert dates_7 == ["2026-08-22", "2027-08-22"]


        # =====================================================================
        # PART 2: TESTING ALL "EDIT" (UPDATE) RECURRENCE SCENARIOS
        # =====================================================================
        logger.info("\n==================================================")
        logger.info("       PART 2: TESTING ALL 'EDIT' SCENARIOS       ")
        logger.info("==================================================")

        # EDIT 1: Edit entire_series changing occurrence count (3 -> 7 occurrences)
        logger.info("\n--- [EDIT 1] Scope 'entire_series': Change occurrence count (3 -> 7) ---")
        req_edit_1 = ScheduleUpdateRequest(
            title="Add Test - Daily 7 Occurrences (Updated)",
            is_recurring=True,
            recurrence=RecurrenceRuleSchema(
                frequency="daily",
                interval=1,
                end_type="after_count",
                end_count=7
            )
        )
        await update_schedule(
            schedule_id=s_id_1,
            req=req_edit_1,
            recurrence_scope="entire_series",
            user=user_dict
        )
        
        # Verify in DB
        rec_edit_1 = await exec_sql("SELECT * FROM public.schedule_recurrence WHERE schedule_id = %s", (s_id_1,))
        assert rec_edit_1[0]["end_count"] == 7, f"Expected end_count 7 in DB, got {rec_edit_1[0]['end_count']}"
        # Verify projection
        proj_edit_1 = await get_schedules(start_date="2026-08-20T00:00:00", end_date="2026-09-10T23:59:59", user=user_dict)
        matching_edit_1 = [s for s in proj_edit_1["data"] if s.get("id") == s_id_1 or s.get("parent_schedule_id") == s_id_1]
        assert len(matching_edit_1) == 7, f"Expected 7 occurrences projected, got {len(matching_edit_1)}"
        dates_edit_1 = sorted([str(s["start_time"])[:10] for s in matching_edit_1])
        logger.info(f"✅ [EDIT 1] PASSED: Occurrence count changed to 7: {dates_edit_1}")
        assert dates_edit_1 == ["2026-08-22", "2026-08-23", "2026-08-24", "2026-08-25", "2026-08-26", "2026-08-27", "2026-08-28"]

        # EDIT 2: Edit entire_series changing repeat interval (from 1 day to 3 days)
        logger.info("\n--- [EDIT 2] Scope 'entire_series': Change repeat interval (1 day -> 3 days) ---")
        req_edit_2 = ScheduleUpdateRequest(
            title="Daily Every 3 Days (Updated)",
            is_recurring=True,
            recurrence=RecurrenceRuleSchema(
                frequency="daily",
                interval=3,
                end_type="after_count",
                end_count=4
            )
        )
        await update_schedule(
            schedule_id=s_id_1,
            req=req_edit_2,
            recurrence_scope="entire_series",
            user=user_dict
        )
        rec_edit_2 = await exec_sql("SELECT * FROM public.schedule_recurrence WHERE schedule_id = %s", (s_id_1,))
        assert rec_edit_2[0]["interval"] == 3 and rec_edit_2[0]["end_count"] == 4
        proj_edit_2 = await get_schedules(start_date="2026-08-20T00:00:00", end_date="2026-09-10T23:59:59", user=user_dict)
        matching_edit_2 = [s for s in proj_edit_2["data"] if s.get("id") == s_id_1 or s.get("parent_schedule_id") == s_id_1]
        dates_edit_2 = sorted([str(s["start_time"])[:10] for s in matching_edit_2])
        logger.info(f"✅ [EDIT 2] PASSED: Repeat interval changed to every 3 days: {dates_edit_2}")
        assert dates_edit_2 == ["2026-08-22", "2026-08-25", "2026-08-28", "2026-08-31"]

        # EDIT 3: Edit entire_series changing frequency from Daily to Weekly on Tue/Thu
        logger.info("\n--- [EDIT 3] Scope 'entire_series': Change frequency from Daily to Weekly on ['TU', 'TH'] ---")
        req_edit_3 = ScheduleUpdateRequest(
            title="Changed to Weekly Tue/Thu",
            start_time="2026-08-25T09:00:00.000", # Tuesday
            end_time="2026-08-25T10:00:00.000",
            is_recurring=True,
            recurrence=RecurrenceRuleSchema(
                frequency="weekly",
                interval=1,
                days_of_week=["TU", "TH"],
                end_type="after_count",
                end_count=4
            )
        )
        await update_schedule(
            schedule_id=s_id_1,
            req=req_edit_3,
            recurrence_scope="entire_series",
            user=user_dict
        )
        rec_edit_3 = await exec_sql("SELECT * FROM public.schedule_recurrence WHERE schedule_id = %s", (s_id_1,))
        assert rec_edit_3[0]["frequency"] == "weekly" and rec_edit_3[0]["end_count"] == 4
        proj_edit_3 = await get_schedules(start_date="2026-08-20T00:00:00", end_date="2026-09-15T23:59:59", user=user_dict)
        matching_edit_3 = [s for s in proj_edit_3["data"] if s.get("id") == s_id_1 or s.get("parent_schedule_id") == s_id_1]
        dates_edit_3 = sorted([str(s["start_time"])[:10] for s in matching_edit_3])
        logger.info(f"✅ [EDIT 3] PASSED: Frequency changed to Weekly Tue/Thu 4 occurrences: {dates_edit_3}")
        assert dates_edit_3 == ["2026-08-25", "2026-08-27", "2026-09-01", "2026-09-03"]

        # EDIT 4: Edit this_event (Override single occurrence)
        logger.info("\n--- [EDIT 4] Scope 'this_event': Override single occurrence on Day 2 (2026-08-27) ---")
        req_edit_4 = ScheduleUpdateRequest(
            title="Overridden Thursday Class (Moved to 2 PM)",
            start_time="2026-08-27T14:00:00.000",
            end_time="2026-08-27T15:00:00.000",
            is_recurring=False
        )
        res_edit_4 = await update_schedule(
            schedule_id=f"{s_id_1}_inst_2026-08-27",
            req=req_edit_4,
            recurrence_scope="this_event",
            target_instance_date="2026-08-27",
            user=user_dict
        )
        override_id = res_edit_4["data"]["id"]
        created_schedule_ids.append(override_id)
        
        # Verify master exceptions
        rec_parent_4 = await exec_sql("SELECT * FROM public.schedule_recurrence WHERE schedule_id = %s", (s_id_1,))
        exc = rec_parent_4[0]["exceptions"]
        if isinstance(exc, str): exc = json.loads(exc)
        assert "2026-08-27" in exc
        
        # Verify projection: still exactly 4 events, with Aug 27 having the overridden title and time
        proj_edit_4 = await get_schedules(start_date="2026-08-20T00:00:00", end_date="2026-09-15T23:59:59", user=user_dict)
        matching_edit_4 = [
            s for s in proj_edit_4["data"] 
            if s.get("id") == s_id_1 or s.get("parent_schedule_id") == s_id_1 or s.get("id") == override_id
        ]
        assert len(matching_edit_4) == 4, f"Expected 4 items, got {len(matching_edit_4)}"
        aug27_event = next(s for s in matching_edit_4 if "2026-08-27" in str(s["start_time"]))
        assert aug27_event["title"] == "Overridden Thursday Class (Moved to 2 PM)"
        logger.info("✅ [EDIT 4] PASSED: this_event isolated override cleanly on 2026-08-27 with 0 duplicates!")

        # EDIT 5: Edit following_events (Split series from 2026-09-01 onwards)
        logger.info("\n--- [EDIT 5] Scope 'following_events': Split series from 2026-09-01 onwards ---")
        req_edit_5 = ScheduleUpdateRequest(
            title="Split Following Events Series (Morning 8 AM)",
            start_time="2026-09-01T08:00:00.000",
            end_time="2026-09-01T09:00:00.000",
            is_recurring=True,
            recurrence=RecurrenceRuleSchema(
                frequency="daily",
                interval=1,
                end_type="after_count",
                end_count=3
            )
        )
        res_edit_5 = await update_schedule(
            schedule_id=f"{s_id_1}_inst_2026-09-01",
            req=req_edit_5,
            recurrence_scope="following_events",
            target_instance_date="2026-09-01",
            user=user_dict
        )
        split_id = res_edit_5["data"]["id"]
        created_schedule_ids.append(split_id)
        
        # Verify old series was capped before 2026-09-01
        rec_old = await exec_sql("SELECT * FROM public.schedule_recurrence WHERE schedule_id = %s", (s_id_1,))
        assert str(rec_old[0]["end_date"]) == "2026-08-31" or rec_old[0]["end_type"] == "until_date"
        # Verify new series exists with 3 occurrences
        rec_new = await exec_sql("SELECT * FROM public.schedule_recurrence WHERE schedule_id = %s", (split_id,))
        assert len(rec_new) == 1 and rec_new[0]["end_count"] == 3
        logger.info(f"✅ [EDIT 5] PASSED: following_events cleanly split series into new recurring series ({split_id})!")

        # EDIT 6: Turn recurring schedule back into a single event (frequency = 'none')
        logger.info("\n--- [EDIT 6] Scope 'entire_series': Convert recurring series to single event (frequency: none) ---")
        req_edit_6 = ScheduleUpdateRequest(
            title="Single Standalone Event",
            is_recurring=False,
            recurrence=RecurrenceRuleSchema(
                frequency="none"
            )
        )
        await update_schedule(
            schedule_id=s_id_2,
            req=req_edit_6,
            recurrence_scope="entire_series",
            user=user_dict
        )
        rec_deleted = await exec_sql("SELECT * FROM public.schedule_recurrence WHERE schedule_id = %s", (s_id_2,))
        assert len(rec_deleted) == 0, "schedule_recurrence row should be removed when frequency is none!"
        proj_edit_6 = await get_schedules(start_date="2026-08-20T00:00:00", end_date="2026-09-10T23:59:59", user=user_dict)
        matching_edit_6 = [s for s in proj_edit_6["data"] if s.get("id") == s_id_2 or s.get("parent_schedule_id") == s_id_2]
        assert len(matching_edit_6) == 1, f"Expected only 1 event, got {len(matching_edit_6)}"
        logger.info("✅ [EDIT 6] PASSED: Recurring series converted back to single event!")

        # EDIT 7: Turn single event into recurring schedule (frequency = 'daily', after_count: 5)
        logger.info("\n--- [EDIT 7] Scope 'entire_series': Convert single event to recurring daily (after_count: 5) ---")
        req_edit_7 = ScheduleUpdateRequest(
            title="Now Recurring Daily",
            is_recurring=True,
            recurrence=RecurrenceRuleSchema(
                frequency="daily",
                interval=1,
                end_type="after_count",
                end_count=5
            )
        )
        await update_schedule(
            schedule_id=s_id_2,
            req=req_edit_7,
            recurrence_scope="entire_series",
            user=user_dict
        )
        rec_created = await exec_sql("SELECT * FROM public.schedule_recurrence WHERE schedule_id = %s", (s_id_2,))
        assert len(rec_created) == 1 and rec_created[0]["end_count"] == 5
        proj_edit_7 = await get_schedules(start_date="2026-08-20T00:00:00", end_date="2026-09-10T23:59:59", user=user_dict)
        matching_edit_7 = [s for s in proj_edit_7["data"] if s.get("id") == s_id_2 or s.get("parent_schedule_id") == s_id_2]
        assert len(matching_edit_7) == 5, f"Expected 5 events, got {len(matching_edit_7)}"
        logger.info("✅ [EDIT 7] PASSED: Single event successfully converted to recurring schedule with 5 occurrences!")

        logger.info("\n==========================================================================")
        logger.info("  🎉 ALL 14 ADD & EDIT RECURRENCE SCENARIOS COMPLETED WITH 100% SUCCESS!  ")
        logger.info("==========================================================================")

    finally:
        if created_schedule_ids:
            logger.info(f"\nCleaning up {len(created_schedule_ids)} test schedules...")
            for sid in created_schedule_ids:
                await exec_sql("DELETE FROM public.schedule_participants WHERE schedule_id = %s RETURNING id", (sid,))
                await exec_sql("DELETE FROM public.schedule_recurrence WHERE schedule_id = %s RETURNING id", (sid,))
                await exec_sql("DELETE FROM public.schedules WHERE id = %s RETURNING id", (sid,))
            logger.info("Cleanup complete.")

if __name__ == "__main__":
    asyncio.run(run_all_add_and_edit_tests())
