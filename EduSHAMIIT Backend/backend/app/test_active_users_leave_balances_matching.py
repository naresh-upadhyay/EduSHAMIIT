import asyncio
import logging
from app.api.attendance import exec_sql, get_leave_balances

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("TestActiveUsersBalancesMatch")

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

async def run_matching_verification():
    logger.info("================================================================================")
    logger.info("🚀 VERIFYING ACTIVE USERS MATCHING BETWEEN ROLES/USERS AND LEAVE BALANCES")
    logger.info("================================================================================")

    # 1. Total Active Profiles in DB
    profiles_count = await exec_sql(
        "SELECT COUNT(*)::INT as total, COUNT(*) FILTER (WHERE LOWER(COALESCE(status, 'active')) = 'active')::INT as active, COUNT(*) FILTER (WHERE LOWER(status) = 'inactive')::INT as inactive FROM public.profiles;"
    )
    total_profiles = profiles_count[0]["total"]
    active_profiles = profiles_count[0]["active"]
    inactive_profiles = profiles_count[0]["inactive"]

    assert_test(
        "Active Profiles Count matches 108",
        active_profiles == 108 and total_profiles == 109,
        f"(Total: {total_profiles}, Active: {active_profiles}, Inactive: {inactive_profiles})"
    )

    # 1. Active Profiles Count in School
    school_id = "11111111-1111-1111-1111-111111111111"
    school_active_res = await exec_sql(
        """SELECT count(*) as count FROM public.profiles p
           WHERE (
               (p.school_id = %s::UUID)
               OR (p.school_id IS NULL AND p.role IN ('super_admin', 'director', 'owner', 'admin'))
           )
           AND LOWER(COALESCE(p.status, 'active')) = 'active';""",
        (school_id,)
    )
    school_active_count = school_active_res[0]["count"] if school_active_res else 0

    # 2. Stored Procedure with School Filter
    proc_res = await exec_sql(
        "SELECT (public.fn_get_leave_balances_paginated(%s::UUID, '2026-2027', 'ALL', 'ALL', '', 1, 10))->'data'->>'total_count' AS total_count;",
        (school_id,)
    )
    proc_total = int(proc_res[0]["total_count"]) if proc_res else 0
    assert_test(
        f"Stored Procedure fn_get_leave_balances_paginated returns exact active count ({school_active_count})",
        proc_total == school_active_count,
        f"(Returned: {proc_total}, Expected: {school_active_count})"
    )

    # 3. Backend API Endpoint for Super Admin (Strict School Scoping)
    super_admin_user = {
        "id": "20000000-0000-0000-0000-000000000001",
        "role": "super_admin",
        "school_id": school_id,
        "permissions": ["*"]
    }
    api_school_res = await get_leave_balances(
        academic_year="2026-2027",
        department="ALL",
        role="ALL",
        search="",
        school_id=school_id,
        page=1,
        page_size=10,
        current_user=super_admin_user
    )
    api_school_count = api_school_res.get("data", {}).get("total_count", 0)
    assert_test(
        f"GET /attendance/leave/balances returns exact school active count ({school_active_count})",
        api_school_count == school_active_count,
        f"(Returned: {api_school_count}, Expected: {school_active_count})"
    )

    # 5. Inactive Profiles excluded from Leave Balances
    inactive_user_res = await exec_sql(
        "SELECT id, full_name, status FROM public.profiles WHERE LOWER(status) = 'inactive' LIMIT 1;"
    )
    if inactive_user_res:
        inactive_id = str(inactive_user_res[0]["id"])
        inactive_name = inactive_user_res[0]["full_name"]
        # Search specifically for the inactive user in leave balances
        inactive_search = await get_leave_balances(
            academic_year="2026-2027",
            department="ALL",
            role="ALL",
            search=inactive_name,
            school_id=None,
            page=1,
            page_size=10,
            current_user=super_admin_user
        )
        found_count = inactive_search.get("data", {}).get("total_count", 0)
        assert_test(
            f"Inactive profile '{inactive_name}' is cleanly excluded from active leave balances",
            found_count == 0,
            f"(Found {found_count} matching active balances for inactive user)"
        )

    logger.info("================================================================================")
    logger.info(f"🏁 ACTIVE USERS BALANCES MATCHING SUITE: {passed_count} PASSED | {failed_count} FAILED")
    logger.info("================================================================================")

if __name__ == "__main__":
    asyncio.run(run_matching_verification())
