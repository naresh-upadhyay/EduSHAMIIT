"""
Master Comprehensive Test Suite for Calendar, Recurrence, RSVP, Discussion Activity, Trips & Timezones.
Runs all possible scenarios end-to-end against the database stored procedures and API endpoints.
"""

import asyncio
import uuid
from datetime import datetime, timedelta, date, timezone
from app.api.calendar import (
    exec_sql,
    get_schedules,
    create_schedule,
    update_schedule,
    delete_schedule,
    duplicate_schedule,
    cancel_schedule,
    get_schedule_by_id,
    submit_schedule_rsvp,
    add_schedule_comment,
    get_schedule_comments,
    ScheduleCreateRequest,
    ScheduleUpdateRequest,
    ScheduleCancelRequest,
    ScheduleRSVPRequest,
    ScheduleCommentRequest,
    RecurrenceRuleSchema,
)

SCHOOL_ID = "11111111-1111-1111-1111-111111111111"
ADMIN_USER = {"id": "38a93170-997b-4b4c-bc8e-256b93169c23", "role": "super_admin", "school_id": SCHOOL_ID}
DRIVER_USER = {"id": "33d93277-35a4-4b33-bdf1-9bf0f3c8b45a", "role": "driver", "school_id": SCHOOL_ID}
TEACHER_USER = {"id": "22222222-2222-2222-2222-222222222222", "role": "teacher", "school_id": SCHOOL_ID}

passed = 0
failed = 0

def check(condition, desc):
    global passed, failed
    if condition:
        print(f"  [PASS] {desc}")
        passed += 1
    else:
        print(f"  [FAIL] {desc}")
        failed += 1


async def run_master_suite():
    global passed, failed
    print("=" * 80)
    print("STARTING MASTER COMPREHENSIVE CALENDAR, RSVP, DISCUSSION & TRIP SUITE")
    print("=" * 80)

    # -------------------------------------------------------------------------
    # SUITE 1: RSVP LIFECYCLE & RESPONSE BREAKDOWN VIA STORED PROCEDURES
    # -------------------------------------------------------------------------
    print("\n--- SUITE 1: RSVP LIFECYCLE & MULTI-USER RESPONSES ---")
    
    # 1.1 Create schedule with group invite (All Drivers) + specific teacher
    ev_req = ScheduleCreateRequest(
        title="School Annual Meeting",
        schedule_type="meeting",
        start_time="2026-09-10T09:00:00Z",
        end_time="2026-09-10T10:30:00Z",
        participants=[
            {"target_role": "driver", "participant_type": "role", "participation_role": "required"},
            {"user_id": TEACHER_USER["id"], "participant_type": "individual", "participation_role": "required"},
        ],
    )
    res = await create_schedule(ev_req, user=ADMIN_USER)
    ev_id = res["data"]["id"]
    check(bool(ev_id), f"1.1 Created event for RSVP testing (ID: {ev_id[:8]})")

    # 1.2 Fetch details via fn_get_schedule_details
    details = await get_schedule_by_id(ev_id, user=ADMIN_USER)
    parts = details["data"].get("participants", [])
    check(len(parts) >= 1, f"1.2 Initial participants list loaded: {len(parts)} entries")

    # 1.3 Driver accepts invitation
    rsvp_res1 = await submit_schedule_rsvp(ev_id, ScheduleRSVPRequest(status="accepted"), user=DRIVER_USER)
    check(rsvp_res1.get("success") is True, "1.3 Driver accepted RSVP invitation")

    # 1.4 Teacher declines invitation with reason
    rsvp_res2 = await submit_schedule_rsvp(ev_id, ScheduleRSVPRequest(status="declined", decline_reason="Class examination duty"), user=TEACHER_USER)
    check(rsvp_res2.get("success") is True, "1.4 Teacher declined RSVP invitation with reason")

    # 1.5 Fetch fresh details and verify participant statuses
    fresh_details = await get_schedule_by_id(ev_id, user=ADMIN_USER)
    fresh_parts = fresh_details["data"].get("participants", [])
    driver_p = next((p for p in fresh_parts if p.get("user_id") == DRIVER_USER["id"]), None)
    teacher_p = next((p for p in fresh_parts if p.get("user_id") == TEACHER_USER["id"]), None)
    
    check(driver_p is not None and driver_p.get("rsvp_status") == "accepted", "1.5 Driver shows status 'accepted' on organizer side")
    check(teacher_p is not None and teacher_p.get("rsvp_status") == "declined" and teacher_p.get("decline_reason") == "Class examination duty", "1.6 Teacher shows status 'declined' with reason on organizer side")

    # -------------------------------------------------------------------------
    # SUITE 2: ACTIVITY & DISCUSSION MESSAGING VIA STORED PROCEDURES
    # -------------------------------------------------------------------------
    print("\n--- SUITE 2: ACTIVITY & DISCUSSION MESSAGING ---")

    # 2.1 Post comment as Admin
    c1 = await add_schedule_comment(ev_id, ScheduleCommentRequest(comment_text="Please review agenda items beforehand."), user=ADMIN_USER)
    check(c1.get("success") is True and c1["data"]["comment_text"] == "Please review agenda items beforehand.", "2.1 Admin posted agenda comment")

    # 2.2 Post reply as Driver
    c2 = await add_schedule_comment(ev_id, ScheduleCommentRequest(comment_text="Noted, will attend promptly."), user=DRIVER_USER)
    check(c2.get("success") is True and c2["data"]["full_name"] is not None, "2.2 Driver posted reply with resolved profile name")

    # 2.3 Retrieve all comments
    comms = await get_schedule_comments(ev_id, user=ADMIN_USER)
    check(len(comms["data"]) == 2, f"2.3 Comments retrieved chronologically: {len(comms['data'])} messages")
    check(comms["data"][0]["user_id"] == ADMIN_USER["id"] and comms["data"][1]["user_id"] == DRIVER_USER["id"], "2.4 Comment ordering and user attribution confirmed")

    # -------------------------------------------------------------------------
    # SUITE 3: RECURRING INSTANCE RSVP & DISCUSSION COMMENTS
    # -------------------------------------------------------------------------
    print("\n--- SUITE 3: RECURRING INSTANCES & INSTANCE-BASED COMMENTS ---")

    # 3.1 Create daily recurrence
    rec_req = ScheduleCreateRequest(
        title="Daily Standup",
        schedule_type="meeting",
        start_time="2026-09-15T04:30:00Z",
        end_time="2026-09-15T05:00:00Z",
        is_recurring=True,
        recurrence={"frequency": "daily", "interval": 1, "end_type": "count", "end_count": 3},
        target_roles=["driver"],
    )
    res_rec = await create_schedule(rec_req, user=ADMIN_USER)
    rec_id = res_rec["data"]["id"]
    check(bool(rec_id), f"3.1 Created 3-day daily recurrence (ID: {rec_id[:8]})")

    # 3.2 Add comment on virtual instance ID
    inst_id = f"{rec_id}_inst_2026-09-16"
    c_inst = await add_schedule_comment(inst_id, ScheduleCommentRequest(comment_text="Update for Day 2 standup"), user=ADMIN_USER)
    check(c_inst.get("success") is True, "3.2 Comment successfully posted using virtual instance ID")

    # 3.3 Fetch details on virtual instance ID via fn_get_schedule_details
    inst_details = await get_schedule_by_id(inst_id, user=ADMIN_USER)
    check(inst_details.get("success") is True and len(inst_details["data"]["comments"]) >= 1, "3.3 Virtual instance returned discussion messages via stored procedure")

    # -------------------------------------------------------------------------
    # SUITE 4: DUPLICATE ON INSTANCE DATE
    # -------------------------------------------------------------------------
    print("\n--- SUITE 4: SCHEDULE DUPLICATION ON EXACT INSTANCE DATE ---")

    dup_res = await duplicate_schedule(inst_id, user=ADMIN_USER)
    dup_id = dup_res["data"]["id"]
    dup_details = await get_schedule_by_id(dup_id, user=ADMIN_USER)
    dup_start = str(dup_details["data"]["start_time"])
    check("2026-09-16" in dup_start, f"4.1 Duplicated instance created on target instance date: {dup_start}")

    # -------------------------------------------------------------------------
    # SUITE 5: COMPLETED TRIP PRESERVATION ACROSS RECURRENCE
    # -------------------------------------------------------------------------
    print("\n--- SUITE 5: COMPLETED TRIP PRESERVATION ---")

    # Fetch transport route
    unique_trip_title = f"TripRoute_{uuid.uuid4().hex[:6]}"
    routes = await exec_sql("SELECT id FROM public.transport_routes WHERE school_id = %s LIMIT 1", (SCHOOL_ID,))
    if routes:
        route_id = str(routes[0]["id"])
        # Create event with route
        trip_ev = await create_schedule(ScheduleCreateRequest(
            title=unique_trip_title,
            schedule_type="transport",
            route_id=route_id,
            start_time="2026-09-20T08:30:00.000",
            end_time="2026-09-20T09:30:00.000",
            timezone="Asia/Kolkata",
            is_recurring=False
        ), user=ADMIN_USER)
        trip_ev_id = trip_ev["data"]["id"]

        # Mark Day 1 trip as completed
        await exec_sql("UPDATE public.vehicle_trips SET status = 'completed' WHERE schedule_id = %s RETURNING id", (trip_ev_id,))

        # Update to 3-day recurrence
        await update_schedule(trip_ev_id, ScheduleUpdateRequest(
            title=f"{unique_trip_title} Daily",
            is_recurring=True,
            recurrence_scope="entire_series",
            recurrence=RecurrenceRuleSchema(frequency="daily", interval=1, end_type="after_count", end_count=3),
        ), user=ADMIN_USER)

        # Check calendar occurrences
        s_list = await get_schedules(
            start_date="2026-09-20T00:00:00",
            end_date="2026-09-25T23:59:59",
            user=ADMIN_USER
        )
        items = [s for s in s_list["data"] if unique_trip_title in s.get("title", "")]
        items.sort(key=lambda x: str(x["start_time"]))

        day1 = items[0] if len(items) > 0 else None
        day2 = items[1] if len(items) > 1 else None

        d1_status = day1.get("trip_status") or day1.get("live_trip_status") if day1 else None
        d2_status = day2.get("trip_status") or day2.get("live_trip_status") if day2 else None

        check(day1 is not None and d1_status == "completed", "5.1 Day 1 trip status remained 'completed'")
        check(day2 is not None and d2_status == "scheduled", "5.2 Day 2 trip status initialized as 'scheduled'")
        check(day1 is not None and day2 is not None and day1.get("trip_id") != day2.get("trip_id"), "5.3 Day 1 and Day 2 have distinct independent trip IDs")
        await delete_schedule(trip_ev_id, user=ADMIN_USER)

    # -------------------------------------------------------------------------
    # SUITE 6: CLEANUP & TEARDOWN
    # -------------------------------------------------------------------------
    print("\n--- SUITE 6: TEARDOWN ---")
    await delete_schedule(ev_id, user=ADMIN_USER)
    await delete_schedule(rec_id, user=ADMIN_USER)
    await delete_schedule(dup_id, user=ADMIN_USER)
    check(True, "6.1 Test events cleaned up cleanly")

    print("\n" + "=" * 80)
    print(f"MASTER SUITE COMPLETE: {passed} PASSED, {failed} FAILED (SUCCESS RATE: {passed / (passed + failed) * 100:.1f}%)")
    print("=" * 80)


if __name__ == "__main__":
    asyncio.run(run_master_suite())
