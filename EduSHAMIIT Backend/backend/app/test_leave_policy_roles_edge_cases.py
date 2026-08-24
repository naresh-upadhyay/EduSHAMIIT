import asyncio
import uuid
import sys
import logging
from datetime import date, timedelta
from app.api.attendance import exec_sql, get_active_roles, get_leave_types, upsert_leave_type, apply_leave, LeaveTypePayload, ApplyLeaveRequest

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("TestLeavePolicyRoles")

passed_count = 0
failed_count = 0

def assert_test(name: str, condition: bool, details: str = ""):
    global passed_count, failed_count
    if condition:
        passed_count += 1
        logger.info(f"✅ PASSED: {name} {details}")
    else:
        failed_count += 1
        logger.error(f"❌ FAILED: {name} {details}")


async def run_edge_case_tests():
    logger.info("================================================================================")
    logger.info("🚀 STARTING COMPREHENSIVE LEAVE POLICY ROLE-SCOPING EDGE-CASE TEST SUITE")
    logger.info("================================================================================")

    # 1. Obtain school_id and real profiles for testing
    schools = await exec_sql("SELECT id FROM public.schools LIMIT 1;")
    if not schools:
        logger.error("No schools found in database.")
        return
    school_id = str(schools[0]["id"])
    logger.info(f"Using School ID: {school_id}")

    # Find or create a teacher profile
    teachers = await exec_sql(
        "SELECT id, full_name, role FROM public.profiles WHERE (school_id = %s::UUID OR school_id IS NULL) AND LOWER(role) = 'teacher' LIMIT 1;",
        (school_id,)
    )
    if not teachers:
        # Fallback to any teacher
        teachers = await exec_sql("SELECT id, full_name, role FROM public.profiles WHERE LOWER(role) = 'teacher' LIMIT 1;")
    teacher_id = str(teachers[0]["id"]) if teachers else None
    teacher_name = teachers[0]["full_name"] if teachers else "Teacher Test"
    logger.info(f"Teacher user: {teacher_name} ({teacher_id})")

    # Find or create a driver profile
    drivers = await exec_sql(
        "SELECT id, full_name, role FROM public.profiles WHERE (school_id = %s::UUID OR school_id IS NULL) AND LOWER(role) = 'driver' LIMIT 1;",
        (school_id,)
    )
    if not drivers:
        drivers = await exec_sql("SELECT id, full_name, role FROM public.profiles WHERE LOWER(role) = 'driver' LIMIT 1;")
    
    if not drivers:
        # Create temporary driver profile for testing if none exists
        driver_uid = str(uuid.uuid4())
        await exec_sql(
            """
            INSERT INTO public.profiles (id, school_id, full_name, role, email)
            VALUES (%s::UUID, %s::UUID, 'Test Driver User', 'driver', 'testdriver@edushamiit.com')
            ON CONFLICT (id) DO NOTHING;
            """,
            (driver_uid, school_id)
        )
        driver_id = driver_uid
        driver_name = "Test Driver User"
    else:
        driver_id = str(drivers[0]["id"])
        driver_name = drivers[0]["full_name"]
    logger.info(f"Driver user: {driver_name} ({driver_id})")

    # Mock admin current_user
    admin_user = {
        "id": teacher_id or str(uuid.uuid4()),
        "role": "super_admin",
        "school_id": school_id,
        "permissions": ["*"],
    }
    teacher_user = {
        "id": teacher_id,
        "role": "teacher",
        "school_id": school_id,
        "permissions": ["attendance.leave.apply", "attendance.leave.view"],
    }
    driver_user = {
        "id": driver_id,
        "role": "driver",
        "school_id": school_id,
        "permissions": ["attendance.leave.apply", "attendance.leave.view"],
    }

    # --------------------------------------------------------------------------
    # SCENARIO 1: Dynamic Active Roles Discovery from app_roles
    # --------------------------------------------------------------------------
    logger.info("\n--- SCENARIO 1: Dynamic Active Roles Discovery ---")
    roles_res = await get_active_roles(current_user=admin_user, school_id=school_id)
    roles_list = roles_res.get("data", {}).get("roles", [])
    role_names = [r["name"].lower() for r in roles_list]
    
    assert_test(
        "Active Roles retrieved from app_roles",
        len(roles_list) >= 5,
        f"Found {len(roles_list)} active roles: {role_names}"
    )
    assert_test(
        "Standard roles present in active roles list",
        "teacher" in role_names and "driver" in role_names and "admin" in role_names,
        f"Role presence verified"
    )

    # --------------------------------------------------------------------------
    # SCENARIO 2: Create Role-Restricted Policy (Teacher Sabbatical -> ['teacher'])
    # --------------------------------------------------------------------------
    logger.info("\n--- SCENARIO 2: Create Role-Restricted Leave Policy ---")
    test_sabbatical_code = "TEST_SABBATICAL"
    test_sabbatical_name = "Test Teacher Sabbatical"

    # Cleanup if previously existed
    await exec_sql("DELETE FROM public.leave_types WHERE code = %s AND (school_id = %s::UUID OR school_id IS NULL);", (test_sabbatical_code, school_id))

    sabbatical_payload = LeaveTypePayload(
        name=test_sabbatical_name,
        code=test_sabbatical_code,
        category="SPECIAL",
        annual_entitlement=15.0,
        applicable_roles=["teacher"],
        color_hex="#8B5CF6",
        is_active=True
    )

    create_res = await upsert_leave_type(payload=sabbatical_payload, current_user=admin_user, school_id=school_id)
    sabbatical_data = create_res.get("data", {})
    sabbatical_id = sabbatical_data.get("id")

    assert_test(
        "Teacher Sabbatical policy created",
        create_res.get("success") is True and sabbatical_id is not None,
        f"ID: {sabbatical_id}"
    )

    # Verify DB persistence of applicable_roles
    db_type = await exec_sql("SELECT applicable_roles FROM public.leave_types WHERE id = %s::UUID;", (sabbatical_id,))
    saved_roles = db_type[0]["applicable_roles"] if db_type else []
    assert_test(
        "DB stores exact applicable_roles array",
        "teacher" in saved_roles and len(saved_roles) == 1,
        f"Saved roles in DB: {saved_roles}"
    )

    # --------------------------------------------------------------------------
    # SCENARIO 3: Create Multi-Role Policy (Operations Transit -> ['driver', 'staff'])
    # --------------------------------------------------------------------------
    logger.info("\n--- SCENARIO 3: Create Multi-Role Leave Policy ---")
    test_transit_code = "TEST_TRANSIT"
    test_transit_name = "Test Driver Logistics Leave"

    await exec_sql("DELETE FROM public.leave_types WHERE code = %s AND (school_id = %s::UUID OR school_id IS NULL);", (test_transit_code, school_id))

    transit_payload = LeaveTypePayload(
        name=test_transit_name,
        code=test_transit_code,
        category="PAID",
        annual_entitlement=8.0,
        applicable_roles=["driver", "staff", "transport"],
        color_hex="#10B981",
        is_active=True
    )

    create_transit_res = await upsert_leave_type(payload=transit_payload, current_user=admin_user, school_id=school_id)
    transit_id = create_transit_res.get("data", {}).get("id")

    assert_test(
        "Multi-role Transit policy created",
        create_transit_res.get("success") is True and transit_id is not None,
        f"ID: {transit_id}"
    )

    # --------------------------------------------------------------------------
    # SCENARIO 4: Filter Leave Types by Role via API
    # --------------------------------------------------------------------------
    logger.info("\n--- SCENARIO 4: Query Leave Types Filtered by Role ---")
    teacher_types_res = await get_leave_types(role="teacher", current_user=teacher_user, school_id=school_id)
    teacher_types = teacher_types_res.get("data", {}).get("leave_types", [])
    teacher_type_codes = [t["code"] for t in teacher_types]

    driver_types_res = await get_leave_types(role="driver", current_user=driver_user, school_id=school_id)
    driver_types = driver_types_res.get("data", {}).get("leave_types", [])
    driver_type_codes = [t["code"] for t in driver_types]

    all_types_res = await get_leave_types(role="ALL", current_user=admin_user, school_id=school_id)
    all_types = all_types_res.get("data", {}).get("leave_types", [])
    all_type_codes = [t["code"] for t in all_types]

    assert_test(
        "Teacher query includes Teacher Sabbatical",
        test_sabbatical_code in teacher_type_codes,
        f"Teacher codes: {teacher_type_codes}"
    )
    assert_test(
        "Teacher query EXCLUDES Driver Logistics Leave",
        test_transit_code not in teacher_type_codes,
        f"Correctly filtered out non-applicable driver leave"
    )
    assert_test(
        "Driver query includes Driver Logistics Leave",
        test_transit_code in driver_type_codes,
        f"Driver codes: {driver_type_codes}"
    )
    assert_test(
        "Driver query EXCLUDES Teacher Sabbatical",
        test_sabbatical_code not in driver_type_codes,
        f"Correctly filtered out non-applicable teacher leave"
    )
    assert_test(
        "Admin ALL query returns both policies",
        test_sabbatical_code in all_type_codes and test_transit_code in all_type_codes,
        f"All codes contains both: {all_type_codes}"
    )

    # --------------------------------------------------------------------------
    # SCENARIO 5: Eligible Role Applies for Policy (Teacher -> Sabbatical) -> 200 OK
    # --------------------------------------------------------------------------
    logger.info("\n--- SCENARIO 5: Eligible Role Applies for Leave ---")
    # Initialize teacher balance for Sabbatical
    await exec_sql(
        """
        INSERT INTO public.leave_balances (school_id, user_id, leave_type_id, academic_year, allocated_days, carried_forward_days, used_days, pending_days)
        VALUES (%s::UUID, %s::UUID, %s::UUID, '2026-2027', 15.0, 0.0, 0.0, 0.0)
        ON CONFLICT (school_id, user_id, leave_type_id, academic_year) DO UPDATE SET allocated_days = 15.0, used_days = 0.0, pending_days = 0.0;
        """,
        (school_id, teacher_id, sabbatical_id)
    )

    apply_date_start = (date.today() + timedelta(days=60)).isoformat()
    apply_date_end = (date.today() + timedelta(days=61)).isoformat()

    teacher_apply_payload = ApplyLeaveRequest(
        applicant_id=uuid.UUID(teacher_id),
        leave_type=test_sabbatical_name,
        start_date=apply_date_start,
        end_date=apply_date_end,
        reason="Academic research & curriculum preparation"
    )

    teacher_apply_res = await apply_leave(payload=teacher_apply_payload, current_user=teacher_user, school_id=school_id)
    assert_test(
        "Teacher successfully applied for Teacher Sabbatical",
        teacher_apply_res.get("success") is True,
        f"Response: {teacher_apply_res.get('message')}"
    )

    # --------------------------------------------------------------------------
    # SCENARIO 6: Non-Eligible Role Blocked from Applying -> 400 REJECTED
    # --------------------------------------------------------------------------
    logger.info("\n--- SCENARIO 6: Non-Eligible Role Blocked from Applying ---")
    # Give driver balance if any
    await exec_sql(
        """
        INSERT INTO public.leave_balances (school_id, user_id, leave_type_id, academic_year, allocated_days, carried_forward_days, used_days, pending_days)
        VALUES (%s::UUID, %s::UUID, %s::UUID, '2026-2027', 15.0, 0.0, 0.0, 0.0)
        ON CONFLICT (school_id, user_id, leave_type_id, academic_year) DO UPDATE SET allocated_days = 15.0, used_days = 0.0, pending_days = 0.0;
        """,
        (school_id, driver_id, sabbatical_id)
    )

    driver_apply_payload = ApplyLeaveRequest(
        applicant_id=uuid.UUID(driver_id),
        leave_type=test_sabbatical_name,
        start_date=apply_date_start,
        end_date=apply_date_end,
        reason="Trying to apply for sabbatical as a driver"
    )

    from fastapi import HTTPException
    driver_rejected = False
    rejection_msg = ""
    try:
        driver_apply_res = await apply_leave(payload=driver_apply_payload, current_user=driver_user, school_id=school_id)
        if not driver_apply_res.get("success"):
            driver_rejected = True
            rejection_msg = driver_apply_res.get("error", "")
    except HTTPException as e:
        driver_rejected = True
        rejection_msg = str(e.detail)
    except Exception as e:
        driver_rejected = True
        rejection_msg = str(e)

    assert_test(
        "Driver blocked from applying for Teacher Sabbatical with role mismatch error",
        driver_rejected and ("not applicable for your role" in rejection_msg.lower() or "not applicable" in rejection_msg.lower()),
        f"Rejection Message: {rejection_msg}"
    )

    # --------------------------------------------------------------------------
    # SCENARIO 7: Update Policy to include Driver (['teacher', 'driver']), Re-Apply
    # --------------------------------------------------------------------------
    logger.info("\n--- SCENARIO 7: Expand Policy Roles & Re-apply ---")
    update_payload = LeaveTypePayload(
        id=uuid.UUID(sabbatical_id),
        name=test_sabbatical_name,
        code=test_sabbatical_code,
        category="SPECIAL",
        annual_entitlement=15.0,
        applicable_roles=["teacher", "driver"],
        color_hex="#8B5CF6",
        is_active=True
    )

    update_res = await upsert_leave_type(payload=update_payload, current_user=admin_user, school_id=school_id)
    assert_test(
        "Policy updated to include driver role",
        update_res.get("success") is True,
        f"Update message: {update_res.get('message')}"
    )

    # Now driver applies again
    driver_reapply_res = await apply_leave(payload=driver_apply_payload, current_user=driver_user, school_id=school_id)
    assert_test(
        "Driver successfully applies after policy was expanded to driver role",
        driver_reapply_res.get("success") is True,
        f"Success response: {driver_reapply_res.get('message')}"
    )

    # --------------------------------------------------------------------------
    # SCENARIO 8: Clean up Test Records
    # --------------------------------------------------------------------------
    logger.info("\n--- SCENARIO 8: Cleanup Test Artifacts ---")
    await exec_sql("DELETE FROM public.leave_applications WHERE leave_type IN (%s, %s);", (test_sabbatical_name, test_transit_name))
    await exec_sql("DELETE FROM public.leave_balances WHERE leave_type_id IN (%s::UUID, %s::UUID);", (sabbatical_id, transit_id))
    await exec_sql("DELETE FROM public.leave_types WHERE id IN (%s::UUID, %s::UUID);", (sabbatical_id, transit_id))
    logger.info("Cleanup completed cleanly.")

    logger.info("================================================================================")
    logger.info(f"🏁 TEST SUITE COMPLETE: {passed_count} PASSED | {failed_count} FAILED")
    logger.info("================================================================================")


if __name__ == "__main__":
    asyncio.run(run_edge_case_tests())
