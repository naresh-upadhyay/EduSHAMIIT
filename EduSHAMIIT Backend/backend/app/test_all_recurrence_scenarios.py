import asyncio
import json
import logging
from datetime import datetime, timedelta
from typing import Dict, Any, List
from app.api.calendar import exec_sql

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("TestAllRecurrenceScenarios")

async def run_all_tests():
    logger.info("=== STARTING COMPREHENSIVE RECURRENCE SCENARIOS TEST SUITE ===")
    
    # 1. Setup School and User
    school_rows = await exec_sql("SELECT id FROM public.schools LIMIT 1")
    if not school_rows:
        logger.error("No school found in database")
        return
    school_id = str(school_rows[0]["id"])
    
    user_rows = await exec_sql("SELECT id, full_name, role FROM public.profiles WHERE school_id = %s LIMIT 1", (school_id,))
    if not user_rows:
        logger.error("No user found in database")
        return
    user_id = str(user_rows[0]["id"])
    user_name = user_rows[0]["full_name"]
    logger.info(f"Testing with School: {school_id}, User: {user_name} ({user_id})")
    
    created_schedule_ids = []

    try:
        # -------------------------------------------------------------
        # SCENARIO 1: Daily with 3 Occurrences (after_count = 3)
        # -------------------------------------------------------------
        logger.info("\n--- SCENARIO 1: Daily with 3 Occurrences (after_count = 3) ---")
        start_time_iso = "2026-08-22T09:00:00.000"
        end_time_iso = "2026-08-22T10:00:00.000"
        
        payload_1 = {
            "title": "Recurrence Test - Daily 3 Occurrences",
            "schedule_type": "Meeting",
            "category": "General",
            "start_time": start_time_iso,
            "end_time": end_time_iso,
            "is_recurring": True,
            "frequency": "daily",
            "interval": 1,
            "end_type": "after_count",
            "end_count": 3,
            "end_date": None,
            "recurrence": {
                "frequency": "daily",
                "interval": 1,
                "end_type": "after_count",
                "end_count": 3,
                "end_date": None
            }
        }
        
        res_1 = await exec_sql(
            "SELECT public.fn_create_schedule(%s::uuid, %s::uuid, %s::jsonb) as res",
            (school_id, user_id, json.dumps(payload_1))
        )
        data_1 = res_1[0]["res"]["data"]
        s_id_1 = data_1["id"]
        created_schedule_ids.append(s_id_1)
        
        # Verify schedule_recurrence in DB
        rec_db_1 = await exec_sql("SELECT * FROM public.schedule_recurrence WHERE schedule_id = %s", (s_id_1,))
        assert len(rec_db_1) == 1, "schedule_recurrence record not created!"
        assert rec_db_1[0]["frequency"] == "daily", f"Wrong frequency: {rec_db_1[0]['frequency']}"
        assert rec_db_1[0]["interval"] == 1, f"Wrong interval: {rec_db_1[0]['interval']}"
        assert rec_db_1[0]["end_type"] == "after_count", f"Wrong end_type: {rec_db_1[0]['end_type']}"
        assert rec_db_1[0]["end_count"] == 3, f"Wrong end_count: {rec_db_1[0]['end_count']}"
        logger.info(f"✅ SCENARIO 1: Created Daily 3 Occurrences schedule ({s_id_1}). DB recurrence verified: {rec_db_1[0]['frequency']}, interval {rec_db_1[0]['interval']}, {rec_db_1[0]['end_type']} {rec_db_1[0]['end_count']}")

        # Verify fn_get_schedule_details returns recurrence
        details_1 = await exec_sql("SELECT public.fn_get_schedule_details(%s::uuid, %s::uuid) as res", (school_id, s_id_1))
        ret_rec_1 = details_1[0]["res"]["data"]["recurrence"]
        assert ret_rec_1 is not None, "fn_get_schedule_details did not return recurrence!"
        assert ret_rec_1["end_type"] == "after_count" and ret_rec_1["end_count"] == 3
        logger.info("✅ SCENARIO 1: fn_get_schedule_details returns complete recurrence rule.")

        # -------------------------------------------------------------
        # SCENARIO 2: Update Schedule Recurrence from 3 to 5 Occurrences
        # -------------------------------------------------------------
        logger.info("\n--- SCENARIO 2: Update Schedule Recurrence (3 -> 5 Occurrences) ---")
        update_payload_2 = {
            "title": "Recurrence Test - Daily 5 Occurrences (Updated)",
            "start_time": start_time_iso,
            "end_time": end_time_iso,
            "is_recurring": True,
            "frequency": "daily",
            "interval": 1,
            "end_type": "after_count",
            "end_count": 5,
            "end_date": None,
            "recurrence": {
                "frequency": "daily",
                "interval": 1,
                "end_type": "after_count",
                "end_count": 5,
                "end_date": None
            }
        }
        res_2 = await exec_sql(
            "SELECT public.fn_update_schedule(%s::uuid, %s::uuid, %s::uuid, %s::jsonb, %s, %s::date) as res",
            (s_id_1, school_id, user_id, json.dumps(update_payload_2), "entire_series", None)
        )
        assert res_2[0]["res"]["success"] is True, f"fn_update_schedule failed: {res_2}"
        
        # Verify in DB
        rec_db_2 = await exec_sql("SELECT * FROM public.schedule_recurrence WHERE schedule_id = %s", (s_id_1,))
        assert rec_db_2[0]["end_count"] == 5, f"end_count was not updated: {rec_db_2[0]['end_count']}"
        logger.info(f"✅ SCENARIO 2: Recurrence successfully updated to end_count = 5 in DB!")

        # -------------------------------------------------------------
        # SCENARIO 3: Daily with End Date (until_date)
        # -------------------------------------------------------------
        logger.info("\n--- SCENARIO 3: Daily with End Date (until_date: 2026-08-25) ---")
        until_payload_3 = {
            "title": "Recurrence Test - Until Aug 25",
            "start_time": start_time_iso,
            "end_time": end_time_iso,
            "is_recurring": True,
            "frequency": "daily",
            "interval": 1,
            "end_type": "until_date",
            "end_count": None,
            "end_date": "2026-08-25",
            "recurrence": {
                "frequency": "daily",
                "interval": 1,
                "end_type": "until_date",
                "end_count": None,
                "end_date": "2026-08-25"
            }
        }
        res_3 = await exec_sql(
            "SELECT public.fn_update_schedule(%s::uuid, %s::uuid, %s::uuid, %s::jsonb, %s, %s::date) as res",
            (s_id_1, school_id, user_id, json.dumps(until_payload_3), "entire_series", None)
        )
        rec_db_3 = await exec_sql("SELECT * FROM public.schedule_recurrence WHERE schedule_id = %s", (s_id_1,))
        assert rec_db_3[0]["end_type"] == "until_date"
        assert str(rec_db_3[0]["end_date"]) == "2026-08-25", f"Wrong end_date: {rec_db_3[0]['end_date']}"
        logger.info("✅ SCENARIO 3: Recurrence successfully updated to until_date 2026-08-25!")

        # -------------------------------------------------------------
        # SCENARIO 4: Weekdays Frequency (Mon-Fri)
        # -------------------------------------------------------------
        logger.info("\n--- SCENARIO 4: Weekdays Frequency (Mon-Fri) ---")
        weekdays_payload = {
            "title": "Recurrence Test - Weekdays",
            "start_time": "2026-08-24T09:00:00.000",
            "end_time": "2026-08-24T10:00:00.000",
            "is_recurring": True,
            "frequency": "weekdays",
            "interval": 1,
            "days_of_week": ["MO", "TU", "WE", "TH", "FR"],
            "end_type": "never",
            "recurrence": {
                "frequency": "weekdays",
                "interval": 1,
                "days_of_week": ["MO", "TU", "WE", "TH", "FR"],
                "end_type": "never"
            }
        }
        res_4 = await exec_sql(
            "SELECT public.fn_create_schedule(%s::uuid, %s::uuid, %s::jsonb) as res",
            (school_id, user_id, json.dumps(weekdays_payload))
        )
        s_id_4 = res_4[0]["res"]["data"]["id"]
        created_schedule_ids.append(s_id_4)
        rec_db_4 = await exec_sql("SELECT * FROM public.schedule_recurrence WHERE schedule_id = %s", (s_id_4,))
        assert rec_db_4[0]["frequency"] == "weekdays"
        logger.info(f"✅ SCENARIO 4: Weekdays recurrence created ({s_id_4}): {rec_db_4[0]['frequency']}, days: {rec_db_4[0]['days_of_week']}")

        # -------------------------------------------------------------
        # SCENARIO 5: Weekly on Chosen Days (MO, WE, FR with Interval = 2)
        # -------------------------------------------------------------
        logger.info("\n--- SCENARIO 5: Weekly on Chosen Days (MO, WE, FR; Interval = 2) ---")
        weekly_payload = {
            "title": "Recurrence Test - Bi-Weekly Mon, Wed, Fri",
            "start_time": "2026-08-24T09:00:00.000",
            "end_time": "2026-08-24T10:00:00.000",
            "is_recurring": True,
            "frequency": "weekly",
            "interval": 2,
            "days_of_week": ["MO", "WE", "FR"],
            "end_type": "after_count",
            "end_count": 6,
            "recurrence": {
                "frequency": "weekly",
                "interval": 2,
                "days_of_week": ["MO", "WE", "FR"],
                "end_type": "after_count",
                "end_count": 6
            }
        }
        res_5 = await exec_sql(
            "SELECT public.fn_create_schedule(%s::uuid, %s::uuid, %s::jsonb) as res",
            (school_id, user_id, json.dumps(weekly_payload))
        )
        s_id_5 = res_5[0]["res"]["data"]["id"]
        created_schedule_ids.append(s_id_5)
        rec_db_5 = await exec_sql("SELECT * FROM public.schedule_recurrence WHERE schedule_id = %s", (s_id_5,))
        assert rec_db_5[0]["frequency"] == "weekly"
        assert rec_db_5[0]["interval"] == 2
        assert json.loads(rec_db_5[0]["days_of_week"] if isinstance(rec_db_5[0]["days_of_week"], str) else json.dumps(rec_db_5[0]["days_of_week"])) == ["MO", "WE", "FR"]
        assert rec_db_5[0]["end_count"] == 6
        logger.info(f"✅ SCENARIO 5: Weekly interval 2 on MO, WE, FR with 6 occurrences created ({s_id_5})!")

        # -------------------------------------------------------------
        # SCENARIO 6: Monthly Recurrence
        # -------------------------------------------------------------
        logger.info("\n--- SCENARIO 6: Monthly Recurrence (Every 1 month) ---")
        monthly_payload = {
            "title": "Recurrence Test - Monthly",
            "start_time": "2026-08-22T14:00:00.000",
            "end_time": "2026-08-22T15:00:00.000",
            "is_recurring": True,
            "frequency": "monthly",
            "interval": 1,
            "end_type": "never",
            "recurrence": {
                "frequency": "monthly",
                "interval": 1,
                "end_type": "never"
            }
        }
        res_6 = await exec_sql(
            "SELECT public.fn_create_schedule(%s::uuid, %s::uuid, %s::jsonb) as res",
            (school_id, user_id, json.dumps(monthly_payload))
        )
        s_id_6 = res_6[0]["res"]["data"]["id"]
        created_schedule_ids.append(s_id_6)
        rec_db_6 = await exec_sql("SELECT * FROM public.schedule_recurrence WHERE schedule_id = %s", (s_id_6,))
        assert rec_db_6[0]["frequency"] == "monthly"
        logger.info(f"✅ SCENARIO 6: Monthly recurrence created ({s_id_6})!")

        # -------------------------------------------------------------
        # SCENARIO 7: Yearly Recurrence
        # -------------------------------------------------------------
        logger.info("\n--- SCENARIO 7: Yearly Recurrence (Annually) ---")
        yearly_payload = {
            "title": "Recurrence Test - Annual Anniversary",
            "start_time": "2026-08-22T10:00:00.000",
            "end_time": "2026-08-22T11:00:00.000",
            "is_recurring": True,
            "frequency": "yearly",
            "interval": 1,
            "end_type": "never",
            "recurrence": {
                "frequency": "yearly",
                "interval": 1,
                "end_type": "never"
            }
        }
        res_7 = await exec_sql(
            "SELECT public.fn_create_schedule(%s::uuid, %s::uuid, %s::jsonb) as res",
            (school_id, user_id, json.dumps(yearly_payload))
        )
        s_id_7 = res_7[0]["res"]["data"]["id"]
        created_schedule_ids.append(s_id_7)
        rec_db_7 = await exec_sql("SELECT * FROM public.schedule_recurrence WHERE schedule_id = %s", (s_id_7,))
        assert rec_db_7[0]["frequency"] == "yearly"
        logger.info(f"✅ SCENARIO 7: Yearly recurrence created ({s_id_7})!")

        # -------------------------------------------------------------
        # SCENARIO 8: Recurrence Scope: this_event (Override on Day 2)
        # -------------------------------------------------------------
        logger.info("\n--- SCENARIO 8: Recurrence Scope: this_event (Override on Day 2: 2026-08-23) ---")
        override_payload = {
            "title": "Day 2 Overridden Meeting",
            "start_time": "2026-08-23T11:00:00.000",
            "end_time": "2026-08-23T12:00:00.000",
            "is_recurring": False,
            "frequency": "none"
        }
        res_8 = await exec_sql(
            "SELECT public.fn_update_schedule(%s::uuid, %s::uuid, %s::uuid, %s::jsonb, %s, %s::date) as res",
            (s_id_1, school_id, user_id, json.dumps(override_payload), "this_event", "2026-08-23")
        )
        assert res_8[0]["res"]["success"] is True
        override_data = res_8[0]["res"]["data"]
        override_id = override_data["id"]
        created_schedule_ids.append(override_id)
        
        # Verify master series excluded 2026-08-23
        rec_db_parent = await exec_sql("SELECT * FROM public.schedule_recurrence WHERE schedule_id = %s", (s_id_1,))
        exc_list = rec_db_parent[0]["exceptions"]
        if isinstance(exc_list, str):
            exc_list = json.loads(exc_list)
        assert "2026-08-23" in exc_list, f"2026-08-23 was not added to exceptions: {exc_list}"
        logger.info(f"✅ SCENARIO 8: this_event created override {override_id} and added 2026-08-23 to master exceptions: {exc_list}")

        # -------------------------------------------------------------
        # SCENARIO 9: Turn Recurring Schedule into Single Event (frequency = none)
        # -------------------------------------------------------------
        logger.info("\n--- SCENARIO 9: Turn Recurring Schedule into Single Event (frequency = none) ---")
        none_payload = {
            "title": "Turned into Single Event",
            "start_time": start_time_iso,
            "end_time": end_time_iso,
            "is_recurring": False,
            "frequency": "none",
            "recurrence": None
        }
        res_9 = await exec_sql(
            "SELECT public.fn_update_schedule(%s::uuid, %s::uuid, %s::uuid, %s::jsonb, %s, %s::date) as res",
            (s_id_1, school_id, user_id, json.dumps(none_payload), "entire_series", None)
        )
        assert res_9[0]["res"]["success"] is True
        sched_9 = await exec_sql("SELECT is_recurring FROM public.schedules WHERE id = %s", (s_id_1,))
        assert sched_9[0]["is_recurring"] is False
        rec_db_9 = await exec_sql("SELECT * FROM public.schedule_recurrence WHERE schedule_id = %s", (s_id_1,))
        assert len(rec_db_9) == 0, "schedule_recurrence should be deleted when non-recurring!"
        logger.info(f"✅ SCENARIO 9: Successfully converted recurring schedule back to non-recurring, schedule_recurrence row cleaned up!")

        # -------------------------------------------------------------
        # SCENARIO 10: Turn Single Event into Recurring Schedule
        # -------------------------------------------------------------
        logger.info("\n--- SCENARIO 10: Turn Single Event into Recurring Schedule (Daily 4 Occurrences) ---")
        turn_rec_payload = {
            "title": "Turned into Recurring Daily 4 Occurrences",
            "start_time": start_time_iso,
            "end_time": end_time_iso,
            "is_recurring": True,
            "frequency": "daily",
            "interval": 1,
            "end_type": "after_count",
            "end_count": 4,
            "recurrence": {
                "frequency": "daily",
                "interval": 1,
                "end_type": "after_count",
                "end_count": 4
            }
        }
        res_10 = await exec_sql(
            "SELECT public.fn_update_schedule(%s::uuid, %s::uuid, %s::uuid, %s::jsonb, %s, %s::date) as res",
            (s_id_1, school_id, user_id, json.dumps(turn_rec_payload), "entire_series", None)
        )
        assert res_10[0]["res"]["success"] is True
        sched_10 = await exec_sql("SELECT is_recurring FROM public.schedules WHERE id = %s", (s_id_1,))
        assert sched_10[0]["is_recurring"] is True
        rec_db_10 = await exec_sql("SELECT * FROM public.schedule_recurrence WHERE schedule_id = %s", (s_id_1,))
        assert len(rec_db_10) == 1 and rec_db_10[0]["end_count"] == 4
        logger.info(f"✅ SCENARIO 10: Successfully converted single event to recurring with end_count = 4!")

        logger.info("\n🎉 ALL 10 RECURRENCE SCENARIOS TESTED AND PASSED WITH 100% INTEGRITY!")

    finally:
        # Cleanup test schedules
        if created_schedule_ids:
            logger.info(f"\nCleaning up {len(created_schedule_ids)} test schedules...")
            for sid in created_schedule_ids:
                await exec_sql("DELETE FROM public.schedule_participants WHERE schedule_id = %s RETURNING id", (sid,))
                await exec_sql("DELETE FROM public.schedule_recurrence WHERE schedule_id = %s RETURNING id", (sid,))
                await exec_sql("DELETE FROM public.schedules WHERE id = %s RETURNING id", (sid,))
            logger.info("Clean up complete.")

if __name__ == "__main__":
    asyncio.run(run_all_tests())
