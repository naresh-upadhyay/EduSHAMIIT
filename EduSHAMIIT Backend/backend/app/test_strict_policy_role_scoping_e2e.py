import asyncio
import logging
from app.api.attendance import (
    exec_sql,
    get_leave_dashboard,
    apply_leave,
    ApplyLeaveRequest
)

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("TestStrictPolicyRoleScoping")

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

async def run_strict_role_scoping_tests():
    logger.info("================================================================================")
    logger.info("🚀 STARTING STRICT LEAVE POLICY ROLE-SCOPING VERIFICATION SUITE")
    logger.info("================================================================================")

    school_id = "11111111-1111-1111-1111-111111111111"

    # Fetch users of different roles
    admin_res = await exec_sql("SELECT id, full_name, role FROM public.profiles WHERE school_id = %s AND role IN ('admin', 'super_admin') LIMIT 1;", (school_id,))
    admin_id = str(admin_res[0]["id"])
    admin_user = {"id": admin_id, "role": "super_admin", "school_id": school_id, "permissions": ["*"]}

    driver_res = await exec_sql("SELECT id, full_name, role FROM public.profiles WHERE school_id = %s AND role = 'driver' LIMIT 1;", (school_id,))
    if not driver_res:
        driver_res = await exec_sql("SELECT id, full_name, role FROM public.profiles WHERE role = 'driver' LIMIT 1;")
    driver_id = str(driver_res[0]["id"])
    driver_user = {"id": driver_id, "role": "driver", "school_id": school_id, "permissions": ["attendance.leave.view"]}

    teacher_res = await exec_sql("SELECT id, full_name, role FROM public.profiles WHERE school_id = %s AND role = 'teacher' LIMIT 1;", (school_id,))
    if not teacher_res:
        teacher_res = await exec_sql("SELECT id, full_name, role FROM public.profiles WHERE role = 'teacher' LIMIT 1;")
    teacher_id = str(teacher_res[0]["id"])
    teacher_user = {"id": teacher_id, "role": "teacher", "school_id": school_id, "permissions": ["attendance.leave.view"]}

    logger.info(f"Admin: {admin_res[0]['full_name']} ({admin_id}) - Role: super_admin")
    logger.info(f"Driver: {driver_res[0]['full_name']} ({driver_id}) - Role: driver")
    logger.info(f"Teacher: {teacher_res[0]['full_name']} ({teacher_id}) - Role: teacher")

    # --------------------------------------------------------------------------
    # SCENARIO 1: King Doe (super_admin) personal Leave Balance Summary
    # --------------------------------------------------------------------------
    logger.info("\n--- SCENARIO 1: Super Admin Personal Balance Summary ---")
    admin_dash = await get_leave_dashboard(current_user=admin_user, school_id=school_id)
    admin_summary = admin_dash.get("data", {}).get("balance_summary", [])
    admin_leave_names = [b.get("leave_type_name") for b in admin_summary]

    assert_test(
        "King Doe (super_admin) does NOT have kop (teacher-restricted) in Leave Balance Summary",
        "kop" not in admin_leave_names,
        f"(Admin summary policies: {admin_leave_names})"
    )

    # --------------------------------------------------------------------------
    # SCENARIO 2: Bus Driver (driver) personal Leave Balance Summary
    # --------------------------------------------------------------------------
    logger.info("\n--- SCENARIO 2: Driver Personal Balance Summary ---")
    driver_dash = await get_leave_dashboard(current_user=driver_user, school_id=school_id)
    driver_summary = driver_dash.get("data", {}).get("balance_summary", [])
    driver_leave_names = [b.get("leave_type_name") for b in driver_summary]

    assert_test(
        "Driver does NOT have kop in Leave Balance Summary",
        "kop" not in driver_leave_names,
        f"(Driver summary policies: {driver_leave_names})"
    )
    assert_test(
        "Driver does NOT have TEST OP (super_admin-restricted) in Leave Balance Summary",
        "TEST OP" not in driver_leave_names,
        f"(Driver summary policies: {driver_leave_names})"
    )

    # --------------------------------------------------------------------------
    # SCENARIO 3: Lakshmi Nair (teacher) personal Leave Balance Summary
    # --------------------------------------------------------------------------
    logger.info("\n--- SCENARIO 3: Teacher Personal Balance Summary ---")
    teacher_dash = await get_leave_dashboard(current_user=teacher_user, school_id=school_id)
    teacher_summary = teacher_dash.get("data", {}).get("balance_summary", [])
    teacher_leave_names = [b.get("leave_type_name") for b in teacher_summary]

    assert_test(
        "Teacher DOES have kop in Leave Balance Summary",
        "kop" in teacher_leave_names,
        f"(Teacher summary policies: {teacher_leave_names})"
    )
    assert_test(
        "Teacher does NOT have TEST OP (super_admin-restricted) in Leave Balance Summary",
        "TEST OP" not in teacher_leave_names,
        f"(Teacher summary policies: {teacher_leave_names})"
    )

    # --------------------------------------------------------------------------
    # SCENARIO 4: Application Guard - Driver Blocked from Applying for kop
    # --------------------------------------------------------------------------
    logger.info("\n--- SCENARIO 4: Application Guard for Non-Applicable Roles ---")
    try:
        driver_apply_res = await apply_leave(
            ApplyLeaveRequest(
                applicant_id=driver_id,
                leave_type="kop",
                start_date="2026-11-05",
                end_date="2026-11-05",
                reason="Unauthorized driver application test",
                half_day_type="FULL_DAY"
            ),
            current_user=driver_user,
            school_id=school_id
        )
        assert_test("Driver blocked from applying for kop", False, f"Unexpected response: {driver_apply_res}")
    except Exception as e:
        err_msg = str(e)
        assert_test(
            "Driver correctly blocked with role mismatch error",
            "not applicable for your role" in err_msg or "400" in err_msg,
            f"(Exception caught: {err_msg})"
        )

    # --------------------------------------------------------------------------
    # SCENARIO 5: Application Execution for Authorized Role ---
    # --------------------------------------------------------------------------
    logger.info("\n--- SCENARIO 5: Application Execution for Authorized Role ---")
    teacher_apply_res = await apply_leave(
        ApplyLeaveRequest(
            applicant_id=teacher_id,
            leave_type="kop",
            start_date="2026-11-05",
            end_date="2026-11-05",
            reason="[TEST_ROLE_SCOPING] Valid teacher application",
            half_day_type="FULL_DAY"
        ),
        current_user=teacher_user,
        school_id=school_id
    )
    assert_test("Teacher successfully applied for kop", teacher_apply_res.get("success") is True)
    test_app_id = teacher_apply_res.get("data", {}).get("id")

    # Cleanup test application
    if test_app_id:
        await exec_sql("DELETE FROM public.leave_applications WHERE id = %s::UUID;", (test_app_id,))
        logger.info("Cleaned up test application.")

    logger.info("================================================================================")
    logger.info(f"🏁 STRICT ROLE-SCOPING SUITE: {passed_count} PASSED | {failed_count} FAILED")
    logger.info("================================================================================")

if __name__ == "__main__":
    asyncio.run(run_strict_role_scoping_tests())
