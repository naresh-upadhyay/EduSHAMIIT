import asyncio
import logging
from app.api.attendance import exec_sql, get_leave_dashboard, get_leave_balances, apply_leave, handle_leave_request_action, ApplyLeaveRequest, LeaveActionRequest

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("TestMultiAcademicYears")

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

async def run_multi_academic_years_tests():
    logger.info("================================================================================")
    logger.info("🚀 STARTING MULTI-ACADEMIC-YEAR DYNAMIC LEAVE BALANCES TEST SUITE")
    logger.info("================================================================================")

    school_id = "11111111-1111-1111-1111-111111111111"
    user_res = await exec_sql("SELECT id, full_name, role FROM public.profiles WHERE full_name ILIKE '%Lakshmi Nair%' LIMIT 1;")
    user_id = str(user_res[0]["id"])
    current_user = {
        "id": user_id,
        "role": "teacher",
        "school_id": school_id,
        "permissions": ["*"]
    }
    admin_user = {
        "id": "0b34bfcc-108b-4825-a9b7-80bfa5494dad",
        "role": "super_admin",
        "school_id": school_id,
        "permissions": ["*"]
    }

    # --------------------------------------------------------------------------
    # SCENARIO 1: Helper Functions Resolution & Normalization Testing
    # --------------------------------------------------------------------------
    logger.info("\n--- SCENARIO 1: Dynamic Academic Year Resolution & Normalization ---")
    norm_res = await exec_sql("""
        SELECT 
            public.fn_resolve_academic_year('2026-08-15'::DATE) AS yr_2026_aug,
            public.fn_resolve_academic_year('2027-02-10'::DATE) AS yr_2027_feb,
            public.fn_resolve_academic_year('2025-11-20'::DATE) AS yr_2025_nov,
            public.fn_resolve_academic_year('2024-05-10'::DATE) AS yr_2024_may,
            public.fn_resolve_academic_year('2027-06-01'::DATE) AS yr_2027_jun,
            public.fn_normalize_academic_year('2026-27') AS norm_short,
            public.fn_normalize_academic_year('2025/26') AS norm_slash,
            public.fn_normalize_academic_year('2026-2027') AS norm_full;
    """)
    n = norm_res[0]
    assert_test("August 2026 resolves to 2026-2027", n["yr_2026_aug"] == "2026-2027")
    assert_test("February 2027 resolves to 2026-2027", n["yr_2027_feb"] == "2026-2027")
    assert_test("November 2025 resolves to 2025-2026", n["yr_2025_nov"] == "2025-2026")
    assert_test("May 2024 resolves to 2024-2025", n["yr_2024_may"] == "2024-2025")
    assert_test("June 2027 resolves to 2027-2028", n["yr_2027_jun"] == "2027-2028")
    assert_test("Normalizer normalizes 2026-27 to 2026-2027", n["norm_short"] == "2026-2027")
    assert_test("Normalizer normalizes 2025/26 to 2025-2026", n["norm_slash"] == "2025-2026")

    # --------------------------------------------------------------------------
    # SCENARIO 2: Apply Leave in Past Academic Year (2025-2026)
    # --------------------------------------------------------------------------
    logger.info("\n--- SCENARIO 2: Apply Leave in Past Academic Year (2025-2026) ---")
    req_past = ApplyLeaveRequest(
        applicant_id=user_id,
        leave_type="Casual Leave",
        start_date="2025-10-14",
        end_date="2025-10-15",
        reason="[TEST_ACAD_YR] Past academic year conference",
        half_day_type="FULL_DAY"
    )
    res_past = await apply_leave(req_past, current_user=current_user, school_id=school_id)
    assert_test("Past leave application submitted successfully", res_past.get("success") is True)
    past_req_id = res_past.get("data", {}).get("id")

    # Verify 2025-2026 balance in DB
    bal_past_db = await exec_sql("""
        SELECT allocated_days, used_days, pending_days, (allocated_days - used_days - pending_days) as available_days
        FROM public.leave_balances
        WHERE user_id = %s::UUID AND academic_year = '2025-2026'
          AND leave_type_id = (SELECT id FROM public.leave_types WHERE name = 'Casual Leave' LIMIT 1);
    """, (user_id,))
    assert_test(
        "2025-2026 balance record automatically created with 2.0 pending days",
        len(bal_past_db) > 0 and float(bal_past_db[0]["pending_days"]) == 2.0,
        f"(2025-2026: {bal_past_db})"
    )

    # --------------------------------------------------------------------------
    # SCENARIO 3: Apply Leave in Future Academic Year (2027-2028)
    # --------------------------------------------------------------------------
    logger.info("\n--- SCENARIO 3: Apply Leave in Future Academic Year (2027-2028) ---")
    req_fut = ApplyLeaveRequest(
        applicant_id=user_id,
        leave_type="Casual Leave",
        start_date="2027-08-10",
        end_date="2027-08-11",
        reason="[TEST_ACAD_YR] Future academic year workshop",
        half_day_type="FULL_DAY"
    )
    res_fut = await apply_leave(req_fut, current_user=current_user, school_id=school_id)
    assert_test("Future leave application submitted successfully", res_fut.get("success") is True)
    fut_req_id = res_fut.get("data", {}).get("id")

    # Verify 2027-2028 balance in DB
    bal_fut_db = await exec_sql("""
        SELECT allocated_days, used_days, pending_days, (allocated_days - used_days - pending_days) as available_days
        FROM public.leave_balances
        WHERE user_id = %s::UUID AND academic_year = '2027-2028'
          AND leave_type_id = (SELECT id FROM public.leave_types WHERE name = 'Casual Leave' LIMIT 1);
    """, (user_id,))
    assert_test(
        "2027-2028 balance record automatically created with 2.0 pending days",
        len(bal_fut_db) > 0 and float(bal_fut_db[0]["pending_days"]) == 2.0,
        f"(2027-2028: {bal_fut_db})"
    )

    # --------------------------------------------------------------------------
    # SCENARIO 4: Dashboard & Balance API Queries for Different Academic Years
    # --------------------------------------------------------------------------
    logger.info("\n--- SCENARIO 4: API Verification across Academic Years ---")
    dash_2025 = await get_leave_dashboard(academic_year="2025-2026", current_user=current_user, school_id=school_id)
    summary_2025 = dash_2025.get("data", {}).get("balance_summary", [])
    cl_2025 = next((b for b in summary_2025 if b.get("leave_type_name") == "Casual Leave"), {})
    assert_test(
        "GET /attendance/leave/dashboard for 2025-2026 reflects 2.0 pending days",
        cl_2025.get("pending_days") == 2.0 and cl_2025.get("available_days") == 10.0,
        f"(2025-2026 Summary: {cl_2025})"
    )

    dash_2027 = await get_leave_dashboard(academic_year="2027-2028", current_user=current_user, school_id=school_id)
    summary_2027 = dash_2027.get("data", {}).get("balance_summary", [])
    cl_2027 = next((b for b in summary_2027 if b.get("leave_type_name") == "Casual Leave"), {})
    assert_test(
        "GET /attendance/leave/dashboard for 2027-2028 reflects 2.0 pending days",
        cl_2027.get("pending_days") == 2.0 and cl_2027.get("available_days") == 10.0,
        f"(2027-2028 Summary: {cl_2027})"
    )

    # Test short academic year format in GET /attendance/leave/balances
    bals_short = await get_leave_balances(
        academic_year="2026-27",
        department="ALL",
        role="ALL",
        search="Lakshmi",
        current_user=admin_user,
        school_id=school_id
    )
    assert_test("GET /attendance/leave/balances with 2026-27 normalizes and returns successfully", bals_short.get("success") is True)

    # --------------------------------------------------------------------------
    # SCENARIO 5: Approve & Reject Multi-Year Leaves & Zero Leak Cleanup
    # --------------------------------------------------------------------------
    logger.info("\n--- SCENARIO 5: Approve & Reject Multi-Year Leaves ---")
    # Approve 2025-2026 leave
    appr_past = await handle_leave_request_action(past_req_id, LeaveActionRequest(action="APPROVE", remarks="Approved past leave"), current_user=admin_user, school_id=school_id)
    assert_test("Past leave approved successfully", appr_past.get("success") is True)

    bal_past_appr = await exec_sql("""
        SELECT used_days, pending_days FROM public.leave_balances 
        WHERE user_id = %s::UUID AND academic_year = '2025-2026' 
          AND leave_type_id = (SELECT id FROM public.leave_types WHERE name = 'Casual Leave' LIMIT 1);
    """, (user_id,))
    assert_test(
        "2025-2026 balance transitioned to 2.0 used and 0.0 pending upon approval",
        float(bal_past_appr[0]["used_days"]) == 2.0 and float(bal_past_appr[0]["pending_days"]) == 0.0,
        f"(2025-2026 after approval: {bal_past_appr})"
    )

    # Reject 2027-2028 leave
    rej_fut = await handle_leave_request_action(fut_req_id, LeaveActionRequest(action="REJECT", remarks="Rejected future leave"), current_user=admin_user, school_id=school_id)
    assert_test("Future leave rejected successfully", rej_fut.get("success") is True)

    bal_fut_rej = await exec_sql("""
        SELECT used_days, pending_days FROM public.leave_balances 
        WHERE user_id = %s::UUID AND academic_year = '2027-2028' 
          AND leave_type_id = (SELECT id FROM public.leave_types WHERE name = 'Casual Leave' LIMIT 1);
    """, (user_id,))
    assert_test(
        "2027-2028 balance refunded to 0.0 used and 0.0 pending upon rejection",
        float(bal_fut_rej[0]["used_days"]) == 0.0 and float(bal_fut_rej[0]["pending_days"]) == 0.0,
        f"(2027-2028 after rejection: {bal_fut_rej})"
    )

    # Cleanup test records
    await exec_sql("DELETE FROM public.leave_applications WHERE id IN (%s::UUID, %s::UUID);", (past_req_id, fut_req_id))
    logger.info("Cleanup completed.")

    logger.info("================================================================================")
    logger.info(f"🏁 MULTI-ACADEMIC-YEAR SUITE: {passed_count} PASSED | {failed_count} FAILED")
    logger.info("================================================================================")

if __name__ == "__main__":
    asyncio.run(run_multi_academic_years_tests())
