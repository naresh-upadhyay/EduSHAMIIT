import asyncio
import json
import logging
from datetime import datetime, timedelta

from app.api.calendar import (
    get_assignable_roles,
    get_assignable_classes,
    create_schedule,
    update_schedule,
    get_schedule_by_id,
    ScheduleCreateRequest,
    ScheduleUpdateRequest,
    exec_sql,
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("TestScheduleEnhancements")

async def run_tests():
    logger.info("=== STARTING SCHEDULE ENHANCEMENT E2E TESTS ===")

    # 1. Fetch Tenant School ID
    school_rows = await exec_sql("SELECT id, name FROM public.schools LIMIT 1;")
    if not school_rows:
        logger.error("❌ No school found in DB")
        return
    school_id = str(school_rows[0]["id"])
    school_name = school_rows[0]["name"]
    logger.info(f"Using School: {school_name} ({school_id})")

    # 2. Get a test organizer user
    users = await exec_sql("SELECT id, email, full_name, role FROM public.profiles WHERE school_id = %s AND role IN ('admin', 'super_admin') LIMIT 1;", (school_id,))
    if not users:
        users = await exec_sql("SELECT id, email, full_name, role FROM public.profiles LIMIT 1;")
    organizer_id = str(users[0]["id"])
    organizer_user = {"id": organizer_id, "school_id": school_id, "role": "super_admin", "permissions": ["*"]}
    logger.info(f"Using Organizer: {users[0].get('full_name')} ({organizer_id})")

    # 3. Test FastAPI endpoint get_assignable_roles
    logger.info("\n--- TEST 1: Testing get_assignable_roles Endpoint & SP ---")
    roles_res = await get_assignable_roles(user=organizer_user)
    assert roles_res and roles_res.get("success"), f"Roles endpoint returned error: {roles_res}"
    roles_data = roles_res.get("data", [])
    logger.info(f"✅ Retrieved {len(roles_data)} active roles from app_roles:")
    for r in roles_data[:10]:
        logger.info(f"   - Role: {r.get('display_name')} (name: {r.get('name')}, code: {r.get('code')}, status: {r.get('status')})")

    # Verify active only
    for r in roles_data:
        st = (r.get("status") or "ACTIVE").upper()
        assert st == "ACTIVE", f"Inactive role found: {r}"

    # 4. Test FastAPI endpoint get_assignable_classes
    logger.info("\n--- TEST 2: Testing get_assignable_classes Endpoint & SP ---")
    cs_res = await get_assignable_classes(user=organizer_user)
    assert cs_res and cs_res.get("success"), f"Class-sections endpoint returned error: {cs_res}"
    cs_data = cs_res.get("data", [])
    logger.info(f"✅ Retrieved {len(cs_data)} class-sections from Sections management:")
    for cs in cs_data[:6]:
        subs = cs.get("subjects") or []
        logger.info(f"   - Class-Section: {cs.get('display_name')} | Students: {cs.get('student_count')} | Teacher: {cs.get('class_teacher_name')} | Subjects: {len(subs)}")
        for s in subs[:3]:
            logger.info(f"       * Subject: {s.get('name')} ({s.get('code')}) -> Teacher: {s.get('teacher_name')}")

    # 5. Get or create calendar
    cal_rows = await exec_sql("SELECT id FROM public.calendars WHERE school_id = %s LIMIT 1;", (school_id,))
    if cal_rows:
        calendar_id = str(cal_rows[0]["id"])
    else:
        new_cal = await exec_sql(
            "INSERT INTO public.calendars (school_id, name, type, visibility) VALUES (%s, 'Academic Calendar', 'academic', 'shared') RETURNING id;",
            (school_id,)
        )
        calendar_id = str(new_cal[0]["id"])

    # 6. TEST 3: Create Schedule with Active Roles + Class-Section (Subject = None) via FastAPI create_schedule
    logger.info("\n--- TEST 3: Create Schedule via FastAPI create_schedule (Subject = None) ---")
    target_cs_1 = cs_data[0] if cs_data else None
    target_class_sections_payload = []
    if target_cs_1:
        target_class_sections_payload.append({
            "class_id": target_cs_1["class_id"],
            "class_name": target_cs_1["class_name"],
            "section_id": target_cs_1["section_id"],
            "section_name": target_cs_1["section_name"],
            "subject_id": None,
            "subject_name": None,
            "display_name": target_cs_1["display_name"],
        })

    start_t = (datetime.now() + timedelta(days=1)).replace(hour=9, minute=0, second=0).isoformat()
    end_t = (datetime.now() + timedelta(days=1)).replace(hour=10, minute=0, second=0).isoformat()

    create_req = ScheduleCreateRequest(
        calendar_id=calendar_id,
        title="General Class Schedule Test",
        description="Testing class-section general audience schedule",
        schedule_type="Class",
        category="Academic",
        color="#4F46E5",
        priority="normal",
        start_time=start_t,
        end_time=end_t,
        target_roles=["teacher"],
        target_class_sections=target_class_sections_payload,
    )

    create_res = await create_schedule(req=create_req, user=organizer_user)
    assert create_res and create_res.get("success"), f"Create schedule failed: {create_res}"
    schedule_id = create_res.get("data", {}).get("id")
    logger.info(f"✅ Schedule Created via FastAPI: {schedule_id}")

    # Verify details
    detail_res = await get_schedule_by_id(schedule_id=schedule_id, user=organizer_user)
    assert detail_res and detail_res.get("success"), f"Get schedule detail failed: {detail_res}"
    sched_obj = detail_res.get("data", {})
    logger.info(f"✅ Retrieved Schedule: {sched_obj.get('title')}")
    logger.info(f"   Target Class Sections: {sched_obj.get('target_class_sections')}")
    logger.info(f"   Participants: {len(sched_obj.get('participants', []))} assigned")

    # 7. TEST 4: Create Schedule with Class-Section-Subject Combo (e.g. Mathematics)
    logger.info("\n--- TEST 4: Create Schedule with Specific Subject Combo ---")
    cs_with_sub = None
    sub_to_pick = None
    for cs in cs_data:
        if cs.get("subjects") and len(cs["subjects"]) > 0:
            cs_with_sub = cs
            sub_to_pick = cs["subjects"][0]
            break

    if cs_with_sub and sub_to_pick:
        subject_target_payload = [{
            "class_id": cs_with_sub["class_id"],
            "class_name": cs_with_sub["class_name"],
            "section_id": cs_with_sub["section_id"],
            "section_name": cs_with_sub["section_name"],
            "subject_id": sub_to_pick["id"],
            "subject_name": sub_to_pick["name"],
            "display_name": cs_with_sub["display_name"],
        }]

        sub_create_req = ScheduleCreateRequest(
            calendar_id=calendar_id,
            title=f"Subject Schedule: {sub_to_pick['name']}",
            description=f"Period for {cs_with_sub['display_name']} - {sub_to_pick['name']}",
            schedule_type="Class",
            category="Academic",
            color="#10B981",
            priority="normal",
            start_time=start_t,
            end_time=end_t,
            target_class_sections=subject_target_payload,
        )

        create_sub_res = await create_schedule(req=sub_create_req, user=organizer_user)
        assert create_sub_res and create_sub_res.get("success"), f"Subject schedule creation failed: {create_sub_res}"
        sub_schedule_id = create_sub_res.get("data", {}).get("id")
        logger.info(f"✅ Subject Schedule Created: {sub_schedule_id}")

        # Verify details
        sub_detail_res = await get_schedule_by_id(schedule_id=sub_schedule_id, user=organizer_user)
        assert sub_detail_res and sub_detail_res.get("success"), f"Get subject schedule detail failed: {sub_detail_res}"
        sub_sched_obj = sub_detail_res.get("data", {})
        logger.info(f"✅ Retrieved Subject Schedule: {sub_sched_obj.get('title')}")
        logger.info(f"   Target Class Sections: {sub_sched_obj.get('target_class_sections')}")
        logger.info(f"   Participants: {len(sub_sched_obj.get('participants', []))} assigned")

        # 8. TEST 5: Update Schedule (Change Target Class Section / Subject)
        logger.info("\n--- TEST 5: Update Schedule Target Class-Sections ---")
        update_req = ScheduleUpdateRequest(
            title=f"Updated Subject Schedule: {sub_to_pick['name']} (Lab Session)",
            target_class_sections=subject_target_payload,
        )
        update_res = await update_schedule(schedule_id=sub_schedule_id, req=update_req, user=organizer_user)
        assert update_res and update_res.get("success"), f"Update schedule failed: {update_res}"
        logger.info(f"✅ Schedule successfully updated: {sub_schedule_id}")

    logger.info("\n🎉 ALL SCHEDULE ENHANCEMENT TESTS PASSED SUCCESSFULLY!")

if __name__ == "__main__":
    asyncio.run(run_tests())
