import asyncio
import uuid
import datetime
from datetime import timezone, timedelta
import psycopg2
from psycopg2.extras import RealDictCursor
from app.config import settings
from app.api.transport import get_upcoming_driver_trip, exec_sql
from app.api.calendar import create_schedule, update_schedule, delete_schedule, ScheduleCreateRequest, ScheduleUpdateRequest

DRIVER_USER = {
    "id": "33d93277-35a4-4b33-bdf1-9bf0f3c8b45a",
    "email": "ramesh.kumar@gmail.com",
    "school_id": "11111111-1111-1111-1111-111111111111",
    "role": "driver"
}

ADMIN_USER = {
    "id": "11111111-1111-1111-1111-111111111111",
    "email": "admin@school.com",
    "school_id": "11111111-1111-1111-1111-111111111111",
    "role": "admin"
}

ROUTE_108_ID = "46cd7317-b093-4b5e-a150-d55f53885731"
ROUTE_126_ID = "a4cd4f83-dad4-495b-86fd-6bd2de8f3389"

async def run_e2e_tests():
    print("=" * 70)
    print("STARTING DRIVER DASHBOARD & SCHEDULE E2E VERIFICATION TEST")
    print("=" * 70)

    # Clean previous test entries
    await exec_sql("DELETE FROM public.schedules WHERE title LIKE %s;", ('%Test Run%',), fetch=False)
    await exec_sql("DELETE FROM public.vehicle_trips WHERE status = 'scheduled';", fetch=False)

    # 1. Test Scenario 1: Currently NO future or ongoing schedule exists
    print("\n--- SCENARIO 1: Driver has NO future/ongoing schedule ---")
    res1 = await get_upcoming_driver_trip(DRIVER_USER)
    data1 = res1.get("data")
    print(f"Result: {data1}")
    assert data1 is None, f"Expected None (Waiting state), but got {data1}"
    print(">>> PASS: Waiting Standby State verified (data: None)")

    # 2. Test Scenario 2: Create a future schedule for tomorrow on Route 108
    print("\n--- SCENARIO 2: Create a schedule for tomorrow on Route 108 ---")
    tomorrow = (datetime.datetime.now(timezone.utc) + timedelta(days=1)).replace(hour=8, minute=0, second=0, microsecond=0)
    tomorrow_end = tomorrow + timedelta(hours=1)

    create_req = ScheduleCreateRequest(
        title="Morning Route 108 Test Run",
        description="E2E Test Run",
        event_type="event",
        start_time=tomorrow.isoformat(),
        end_time=tomorrow_end.isoformat(),
        route_id=ROUTE_108_ID
    )

    create_res = await create_schedule(create_req, ADMIN_USER)
    sched_id = create_res["data"]["id"]
    print(f"Created Schedule ID: {sched_id} on {tomorrow.date().isoformat()}")

    # Verify upcoming trip endpoint returns this newly created schedule
    res2 = await get_upcoming_driver_trip(DRIVER_USER)
    data2 = res2.get("data")
    assert data2 is not None, "Expected upcoming trip data, but got None!"
    trip2 = data2["trip"]
    route2 = data2["route"]
    print(f"Upcoming Trip Found: Trip ID={trip2['id']}, Route={route2.get('route_name')}, Bus={route2.get('assigned_bus')}, Date={trip2.get('schedule_instance_date')}")
    assert str(trip2["route_id"]) == ROUTE_108_ID, f"Expected Route {ROUTE_108_ID}, got {trip2['route_id']}"
    print(">>> PASS: Future schedule accurately resolved on driver dashboard!")

    # 3. Test Scenario 3: Update schedule to Route 126
    print("\n--- SCENARIO 3: Update schedule to Route 126 ---")
    upd_req = ScheduleUpdateRequest(
        title="Evening Route 126 Test Run",
        route_id=ROUTE_126_ID
    )
    upd_res = await update_schedule(sched_id, upd_req, recurrence_scope="entire_series", target_instance_date=None, user=ADMIN_USER)
    print(f"Updated Schedule ID: {sched_id} to Route 126")

    res3 = await get_upcoming_driver_trip(DRIVER_USER)
    data3 = res3.get("data")
    assert data3 is not None, "Expected upcoming trip data after update, but got None!"
    trip3 = data3["trip"]
    route3 = data3["route"]
    print(f"Upcoming Trip Found After Update: Trip ID={trip3['id']}, Route={route3.get('route_name')}, Bus={route3.get('assigned_bus')}")
    assert str(trip3["route_id"]) == ROUTE_126_ID, f"Expected Route {ROUTE_126_ID}, got {trip3['route_id']}"
    print(">>> PASS: Route update synchronized seamlessly!")

    # 4. Test Scenario 4: Delete / Cancel the schedule in calendar
    print("\n--- SCENARIO 4: Delete schedule in calendar ---")
    del_res = await delete_schedule(sched_id, recurrence_scope="entire_series", target_instance_date=None, user=ADMIN_USER)
    print(f"Deleted Schedule ID: {sched_id}")

    # Verify that driver dashboard IMMEDIATELY returns None (Waiting State)
    res4 = await get_upcoming_driver_trip(DRIVER_USER)
    data4 = res4.get("data")
    print(f"Result after deletion: {data4}")
    assert data4 is None, f"Expected None (Waiting state) after deletion, but got {data4}"
    print(">>> PASS: Deletion instantly returned driver dashboard to Waiting Standby State!")

    print("\n" + "=" * 70)
    print("ALL 4 E2E SCENARIOS PASSED WITH 100% SUCCESS!")
    print("=" * 70)

if __name__ == "__main__":
    asyncio.run(run_e2e_tests())
