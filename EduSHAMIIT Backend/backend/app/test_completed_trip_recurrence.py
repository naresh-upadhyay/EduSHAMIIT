import asyncio
from app.api.calendar import create_schedule, update_schedule, get_schedules, ScheduleCreateRequest, ScheduleUpdateRequest, RecurrenceRuleSchema, exec_sql

user = {
    'id': '38a93170-997b-4b4c-bc8e-256b93169c23',
    'role': 'super_admin',
    'school_id': '11111111-1111-1111-1111-111111111111'
}

async def run():
    print("--- STARTING COMPLETED TRIP + RECURRENCE TEST ---")
    # 1. Clean
    await exec_sql("DELETE FROM public.schedules WHERE title LIKE %s", ('%TEST_TRIP_RECUR%',), fetch=False)

    # 2. Get route and calendar
    routes = await exec_sql("SELECT id FROM public.transport_routes LIMIT 1", ())
    route_id = str(routes[0]['id']) if routes else None
    print("Using Transport Route ID:", route_id)

    cals = await exec_sql("SELECT id FROM public.calendars WHERE school_id = %s LIMIT 1", (user['school_id'],))
    cal_id = str(cals[0]['id']) if cals else None
    if not cal_id:
        cals_any = await exec_sql("SELECT id FROM public.calendars LIMIT 1", ())
        cal_id = str(cals_any[0]['id']) if cals_any else 'a95ead3e-4d13-46e5-af94-e4a3c545b4f6'

    # 3. Create single schedule with route
    req = ScheduleCreateRequest(
        calendar_id=cal_id,
        title='TEST_TRIP_RECUR_Event',
        start_time='2026-08-10T03:00:00.000',
        end_time='2026-08-10T04:00:00.000',
        timezone='Asia/Kolkata',
        route_id=route_id,
        is_recurring=False
    )
    res1 = await create_schedule(req, user=user)
    s_id = res1['data']['id']
    print(f"Created single event ID: {s_id}")

    # Check initial trip
    t1 = await exec_sql("SELECT id, status, schedule_instance_date FROM public.vehicle_trips WHERE schedule_id = %s", (s_id,))
    t1_id = str(t1[0]['id'])
    print(f"Initial Day 1 Trip: ID={t1_id}, Date={t1[0]['schedule_instance_date']}, Status={t1[0]['status']}")

    # Mark Day 1 trip as completed
    await exec_sql("UPDATE public.vehicle_trips SET status = 'completed' WHERE id = %s", (t1_id,), fetch=False)
    print("Marked Day 1 Trip as COMPLETED")

    # 4. Update schedule to 3-day recurrence
    upd_req = ScheduleUpdateRequest(
        is_recurring=True,
        recurrence=RecurrenceRuleSchema(frequency='daily', interval=1, end_type='after_count', end_count=3)
    )
    res2 = await update_schedule(s_id, upd_req, recurrence_scope='entire_series', user=user)
    print("Updated schedule to 3-day recurrence")

    # 5. Fetch all schedules via get_schedules
    s_res = await get_schedules(start_date='2026-08-10T00:00:00', end_date='2026-08-16T23:59:59', user=user)
    items = [x for x in s_res['data'] if 'TEST_TRIP_RECUR' in x['title']]
    items.sort(key=lambda x: str(x['start_time']))

    print(f"Retrieved {len(items)} occurrences on calendar:")
    trip_ids = set()
    for it in items:
        sid = it['id']
        dt = str(it['start_time'])[:10]
        tid = it.get('trip_id')
        tst = it.get('trip_status')
        print(f"  -> Schedule ID: {sid} | Date: {dt} | trip_id: {tid} | trip_status: {tst}")
        assert tid is not None, "trip_id should not be None"
        trip_ids.add(tid)

    # Assertions
    assert len(items) == 3, f"Expected 3 occurrences, got {len(items)}"
    assert len(trip_ids) == 3, f"Expected 3 unique trip IDs, got {len(trip_ids)}"
    assert items[0]['trip_id'] == t1_id, f"Day 1 trip_id should be original completed trip {t1_id}, got {items[0]['trip_id']}"
    assert items[0]['trip_status'] == 'completed', f"Day 1 trip_status should be completed, got {items[0]['trip_status']}"
    assert items[1]['trip_status'] == 'scheduled', f"Day 2 trip_status should be scheduled, got {items[1]['trip_status']}"
    assert items[2]['trip_status'] == 'scheduled', f"Day 3 trip_status should be scheduled, got {items[2]['trip_status']}"

    print("--- [PASSED] ALL 3 DAYS HAVE INDIVIDUAL UNIQUE SCHEDULE & TRIP IDS, DAY 1 COMPLETED STATUS FULLY PRESERVED! ---")

    # Clean
    await exec_sql("DELETE FROM public.schedules WHERE title LIKE %s", ('%TEST_TRIP_RECUR%',), fetch=False)

if __name__ == '__main__':
    asyncio.run(run())
