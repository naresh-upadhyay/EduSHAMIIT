import asyncio
import json
import logging
from datetime import datetime, timedelta
from typing import Dict, Any, List
from app.api.calendar import (
    get_schedules,
    exec_sql,
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("TestCalendarApiProjectionScenarios")

class DummyUser:
    def __init__(self, id, school_id, role):
        self.id = id
        self.school_id = school_id
        self.role = role

async def run_api_projection_tests():
    logger.info("=== STARTING CALENDAR API RECURRENCE PROJECTION TEST SUITE ===")
    
    # 1. Setup School and User
    school_rows = await exec_sql("SELECT id FROM public.schools LIMIT 1")
    school_id = str(school_rows[0]["id"])
    
    user_rows = await exec_sql("SELECT id, role FROM public.profiles WHERE school_id = %s LIMIT 1", (school_id,))
    user_id = str(user_rows[0]["id"])
    user_dict = {"id": user_id, "school_id": school_id, "role": user_rows[0]["role"]}
    
    created_schedule_ids = []

    try:
        # -------------------------------------------------------------
        # PROJECTION TEST 1: Daily with 3 Occurrences (after_count = 3)
        # -------------------------------------------------------------
        logger.info("\n--- PROJECTION TEST 1: Daily with 3 Occurrences (after_count = 3) ---")
        start_time_iso = "2026-08-22T09:00:00.000"
        end_time_iso = "2026-08-22T10:00:00.000"
        
        payload_1 = {
            "title": "Daily 3 Occurrences Projection Test",
            "schedule_type": "Meeting",
            "category": "General",
            "start_time": start_time_iso,
            "end_time": end_time_iso,
            "is_recurring": True,
            "frequency": "daily",
            "interval": 1,
            "end_type": "after_count",
            "end_count": 3,
            "recurrence": {
                "frequency": "daily",
                "interval": 1,
                "end_type": "after_count",
                "end_count": 3
            }
        }
        
        res_1 = await exec_sql(
            "SELECT public.fn_create_schedule(%s::uuid, %s::uuid, %s::jsonb) as res",
            (school_id, user_id, json.dumps(payload_1))
        )
        s_id_1 = res_1[0]["res"]["data"]["id"]
        created_schedule_ids.append(s_id_1)
        
        # Query 14-day window (2026-08-20 to 2026-09-03)
        schedules_res = await get_schedules(
            start_date="2026-08-20T00:00:00",
            end_date="2026-09-03T23:59:59",
            user=user_dict
        )
        
        # Filter for this schedule series
        matching = [
            s for s in schedules_res["data"] 
            if s.get("id") == s_id_1 
            or s.get("parent_schedule_id") == s_id_1 
            or s.get("recurring_parent_id") == s_id_1
        ]
        
        logger.info(f"Generated {len(matching)} occurrences across query window for after_count = 3.")
        assert len(matching) == 3, f"Expected exactly 3 occurrences, got {len(matching)}!"
        dates = [str(s["start_time"])[:10] for s in matching]
        logger.info(f"Occurrence dates: {dates}")
        assert "2026-08-22" in dates and "2026-08-23" in dates and "2026-08-24" in dates
        logger.info("✅ PROJECTION TEST 1: Exactly 3 occurrences projected correctly!")

        # -------------------------------------------------------------
        # PROJECTION TEST 2: Daily with 5 Occurrences after Update
        # -------------------------------------------------------------
        logger.info("\n--- PROJECTION TEST 2: Daily with 5 Occurrences after Update ---")
        update_payload_2 = {
            "title": "Daily 5 Occurrences Projection Test",
            "start_time": start_time_iso,
            "end_time": end_time_iso,
            "is_recurring": True,
            "frequency": "daily",
            "interval": 1,
            "end_type": "after_count",
            "end_count": 5,
            "recurrence": {
                "frequency": "daily",
                "interval": 1,
                "end_type": "after_count",
                "end_count": 5
            }
        }
        await exec_sql(
            "SELECT public.fn_update_schedule(%s::uuid, %s::uuid, %s::uuid, %s::jsonb, %s, %s::date) as res",
            (s_id_1, school_id, user_id, json.dumps(update_payload_2), "entire_series", None)
        )
        
        schedules_res_2 = await get_schedules(
            start_date="2026-08-20T00:00:00",
            end_date="2026-09-03T23:59:59",
            user=user_dict
        )
        matching_2 = [
            s for s in schedules_res_2["data"] 
            if s.get("id") == s_id_1 
            or s.get("parent_schedule_id") == s_id_1 
            or s.get("recurring_parent_id") == s_id_1
        ]
        logger.info(f"Generated {len(matching_2)} occurrences across query window for after_count = 5.")
        assert len(matching_2) == 5, f"Expected exactly 5 occurrences, got {len(matching_2)}!"
        logger.info("✅ PROJECTION TEST 2: Exactly 5 occurrences projected correctly after update!")

        # -------------------------------------------------------------
        # PROJECTION TEST 3: Weekdays (Mon-Fri) Only
        # -------------------------------------------------------------
        logger.info("\n--- PROJECTION TEST 3: Weekdays (Mon-Fri) Only ---")
        weekdays_payload = {
            "title": "Weekdays Projection Test",
            "start_time": "2026-08-21T09:00:00.000", # Friday
            "end_time": "2026-08-21T10:00:00.000",
            "is_recurring": True,
            "frequency": "weekdays",
            "interval": 1,
            "end_type": "after_count",
            "end_count": 5,
            "recurrence": {
                "frequency": "weekdays",
                "interval": 1,
                "end_type": "after_count",
                "end_count": 5
            }
        }
        res_3 = await exec_sql(
            "SELECT public.fn_create_schedule(%s::uuid, %s::uuid, %s::jsonb) as res",
            (school_id, user_id, json.dumps(weekdays_payload))
        )
        s_id_3 = res_3[0]["res"]["data"]["id"]
        created_schedule_ids.append(s_id_3)

        schedules_res_3 = await get_schedules(
            start_date="2026-08-20T00:00:00",
            end_date="2026-09-03T23:59:59",
            user=user_dict
        )
        matching_3 = [
            s for s in schedules_res_3["data"] 
            if s.get("id") == s_id_3 
            or s.get("parent_schedule_id") == s_id_3 
            or s.get("recurring_parent_id") == s_id_3
        ]
        dates_3 = [str(s["start_time"])[:10] for s in matching_3]
        logger.info(f"Weekdays occurrence dates: {dates_3}")
        # Friday Aug 21, Mon Aug 24, Tue Aug 25, Wed Aug 26, Thu Aug 27 (skips Sat Aug 22, Sun Aug 23)
        assert len(matching_3) == 5
        assert "2026-08-22" not in dates_3 and "2026-08-23" not in dates_3
        assert "2026-08-21" in dates_3 and "2026-08-24" in dates_3
        logger.info("✅ PROJECTION TEST 3: Weekdays accurately skipped weekend and projected 5 weekdays!")

        # -------------------------------------------------------------
        # PROJECTION TEST 4: Override isolation on single instance (this_event)
        # -------------------------------------------------------------
        logger.info("\n--- PROJECTION TEST 4: Override isolation on single instance (this_event) ---")
        override_payload = {
            "title": "Overridden Monday Class",
            "start_time": "2026-08-24T14:00:00.000",
            "end_time": "2026-08-24T15:00:00.000",
            "is_recurring": False,
            "frequency": "none"
        }
        res_4 = await exec_sql(
            "SELECT public.fn_update_schedule(%s::uuid, %s::uuid, %s::uuid, %s::jsonb, %s, %s::date) as res",
            (s_id_3, school_id, user_id, json.dumps(override_payload), "this_event", "2026-08-24")
        )
        override_id = res_4[0]["res"]["data"]["id"]
        created_schedule_ids.append(override_id)

        schedules_res_4 = await get_schedules(
            start_date="2026-08-20T00:00:00",
            end_date="2026-09-03T23:59:59",
            user=user_dict
        )
        matching_4 = [
            s for s in schedules_res_4["data"] 
            if s.get("id") == s_id_3 
            or s.get("parent_schedule_id") == s_id_3 
            or s.get("recurring_parent_id") == s_id_3
            or s.get("id") == override_id
        ]
        logger.info(f"Total matching items including override: {len(matching_4)}")
        assert len(matching_4) == 5, f"Should still be 5 total (4 series + 1 override), got {len(matching_4)}"
        override_event = next(s for s in matching_4 if s["id"] == override_id)
        assert override_event["title"] == "Overridden Monday Class"
        logger.info("✅ PROJECTION TEST 4: Override row cleanly replaced recurring virtual instance with 0 duplicates!")

        logger.info("\n🎉 ALL CALENDAR API RECURRENCE PROJECTION TESTS PASSED WITH 100% SUCCESS!")

    finally:
        if created_schedule_ids:
            logger.info(f"\nCleaning up {len(created_schedule_ids)} test schedules...")
            for sid in created_schedule_ids:
                await exec_sql("DELETE FROM public.schedule_participants WHERE schedule_id = %s RETURNING id", (sid,))
                await exec_sql("DELETE FROM public.schedule_recurrence WHERE schedule_id = %s RETURNING id", (sid,))
                await exec_sql("DELETE FROM public.schedules WHERE id = %s RETURNING id", (sid,))
            logger.info("Clean up complete.")

if __name__ == "__main__":
    asyncio.run(run_api_projection_tests())
