import asyncio
import time
import logging
from app.api.attendance import exec_sql, get_leave_balances

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("TestSchoolScopedDedup")

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

async def run_school_scoped_dedup_tests():
    logger.info("================================================================================")
    logger.info("🚀 STARTING SCHOOL-SCOPED LEAVE BALANCES DEDUPLICATION & SPEED TEST SUITE")
    logger.info("================================================================================")

    school_id = "11111111-1111-1111-1111-111111111111"
    admin_user = {
        "id": "20000000-0000-0000-0000-000000000001",
        "role": "super_admin",
        "school_id": school_id,
        "permissions": ["*"]
    }

    # --------------------------------------------------------------------------
    # SCENARIO 1: Verify School Scoping (Only Users from Current School)
    # --------------------------------------------------------------------------
    logger.info("\n--- SCENARIO 1: School Scoping ---")
    start_time = time.time()
    res = await get_leave_balances(
        academic_year="2026-2027",
        department="ALL",
        role="ALL",
        search="",
        page=1,
        page_size=10,
        current_user=admin_user
    )
    elapsed_ms = (time.time() - start_time) * 1000.0

    data = res.get("data", {})
    total_count = data.get("total_count", 0)
    employees = data.get("employees", [])
    balances = data.get("balances", [])

    assert_test(
        "Leave Balances scoped strictly to user's school",
        total_count in (79, 80),
        f"(Found {total_count} active employees in school {school_id})"
    )

    # Warm-up call done in Scenario 1. Now benchmark 5 repeated calls:
    latencies = []
    for _ in range(5):
        t0 = time.time()
        await get_leave_balances(
            academic_year="2026-2027",
            department="ALL",
            role="ALL",
            search="",
            page=1,
            page_size=10,
            current_user=admin_user
        )
        latencies.append((time.time() - t0) * 1000.0)
    avg_latency_ms = sum(latencies) / len(latencies)

    assert_test(
        "Average query response time is ultra-fast (< 120ms)",
        avg_latency_ms < 120.0,
        f"(Average latency over 5 runs: {avg_latency_ms:.2f}ms, min: {min(latencies):.2f}ms)"
    )

    # --------------------------------------------------------------------------
    # SCENARIO 3: Zero Redundant / Duplicate Leave Types Per User
    # --------------------------------------------------------------------------
    logger.info("\n--- SCENARIO 3: Zero Redundant Data & Deduplication ---")
    duplicates_found = 0
    duplicate_details = []

    for emp in employees:
        emp_name = emp.get("full_name")
        emp_id = emp.get("user_id")
        emp_balances = emp.get("balances", [])
        
        seen_codes = set()
        for b in emp_balances:
            code = b.get("leave_type_code")
            if code in seen_codes:
                duplicates_found += 1
                duplicate_details.append(f"{emp_name} ({code})")
            seen_codes.add(code)

    assert_test(
        "Every employee has unique, non-duplicated leave types in balances array",
        duplicates_found == 0,
        f"(Duplicates found: {duplicates_found} {duplicate_details[:3]})"
    )

    # Verify flat_balances deduplication
    seen_flat = set()
    flat_duplicates = 0
    for b in balances:
        key = (b.get("user_id"), b.get("leave_type_code"))
        if key in seen_flat:
            flat_duplicates += 1
        seen_flat.add(key)

    assert_test(
        "Flat balances table dataset has zero redundant/duplicate rows",
        flat_duplicates == 0,
        f"(Total flat rows: {len(balances)}, Unique: {len(seen_flat)}, Duplicate rows: {flat_duplicates})"
    )

    # --------------------------------------------------------------------------
    # SCENARIO 4: Check Specific User (Aarav Shah)
    # --------------------------------------------------------------------------
    logger.info("\n--- SCENARIO 4: Targeted Verification for Aarav Shah ---")
    aarav_res = await get_leave_balances(
        academic_year="2026-2027",
        department="ALL",
        role="ALL",
        search="Aarav Shah",
        page=1,
        page_size=10,
        current_user=admin_user
    )
    aarav_emps = aarav_res.get("data", {}).get("employees", [])
    if aarav_emps:
        aarav = aarav_emps[0]
        aarav_bals = aarav.get("balances", [])
        codes = [b.get("leave_type_code") for b in aarav_bals]
        names = [b.get("leave_type_name") for b in aarav_bals]
        assert_test(
            "Aarav Shah has exactly one row per leave type without repeated Earned Leave",
            len(codes) == len(set(codes)) and codes.count("EL") <= 1,
            f"Leave codes for Aarav Shah: {codes}"
        )

    # --------------------------------------------------------------------------
    # SCENARIO 5: Department and Role Filters
    # --------------------------------------------------------------------------
    logger.info("\n--- SCENARIO 5: Filter Tests ---")
    teacher_res = await get_leave_balances(
        academic_year="2026-2027",
        department="ALL",
        role="TEACHER",
        search="",
        page=1,
        page_size=10,
        current_user=admin_user
    )
    teacher_emps = teacher_res.get("data", {}).get("employees", [])
    assert_test(
        "Role filter strictly filters employees by role",
        all(e.get("role").lower() == "teacher" for e in teacher_emps),
        f"Found {len(teacher_emps)} teachers"
    )

    logger.info("================================================================================")
    logger.info(f"🏁 DEDUPLICATION & SCHOOL-SCOPED SUITE: {passed_count} PASSED | {failed_count} FAILED")
    logger.info("================================================================================")

if __name__ == "__main__":
    asyncio.run(run_school_scoped_dedup_tests())
