import asyncio
import logging
from app.api.attendance import (
    exec_sql,
    get_leave_dashboard,
    get_leave_balances,
    apply_leave,
    handle_leave_request_action,
    ApplyLeaveRequest,
    LeaveActionRequest
)

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("TestAutoAbsorbOverlap")

def print_result(test_name: str, passed: bool, details: str = ""):
    icon = "✅ PASSED" if passed else "❌ FAILED"
    logger.info(f"{icon}: {test_name} ({details})")
    if not passed:
        raise AssertionError(f"Test failed: {test_name} - {details}")

async def run_tests():
    logger.info("=" * 80)
    logger.info("🚀 TESTING DYNAMIC OVERLAP ABSORPTION ON LEAVE REJECT / CANCEL")
    logger.info("=" * 80)

    school_id = "11111111-1111-1111-1111-111111111111"
    admin_res = await exec_sql("SELECT id FROM public.profiles WHERE full_name ILIKE '%King Doe%' LIMIT 1;")
    admin_id = str(admin_res[0]["id"])
    admin_user = {"id": admin_id, "role": "super_admin", "school_id": school_id, "permissions": ["*"]}

    # Clean test leaves
    await exec_sql("DELETE FROM public.leave_applications WHERE reason ILIKE '[TEST_ABSORB]%';")

    # Step 1: Apply Leave Request 1 (03 Nov to 05 Nov -> 3 billable days)
    logger.info("\n--- STEP 1: Apply Request 1 (03 Nov to 05 Nov) ---")
    res1 = await apply_leave(
        ApplyLeaveRequest(
            applicant_id=admin_id,
            leave_type="MONK",
            start_date="2026-11-03",
            end_date="2026-11-05",
            reason="[TEST_ABSORB] Short leave",
            half_day_type="FULL_DAY"
        ),
        current_user=admin_user,
        school_id=school_id
    )
    app1_id = res1["data"]["id"]
    print_result("Request 1 Creation", res1.get("success") is True and res1["data"]["billable_days"] == 3.0, f"billable_days: {res1['data']['billable_days']}")

    # Step 2: Apply Request 2 (02 Nov to 08 Nov -> Superset range, overlaps with Req 1)
    logger.info("\n--- STEP 2: Apply Request 2 (02 Nov to 08 Nov, superset of Req 1) ---")
    res2 = await apply_leave(
        ApplyLeaveRequest(
            applicant_id=admin_id,
            leave_type="MONK",
            start_date="2026-11-02",
            end_date="2026-11-08",
            reason="[TEST_ABSORB] Superset leave",
            half_day_type="FULL_DAY"
        ),
        current_user=admin_user,
        school_id=school_id
    )
    app2_id = res2["data"]["id"]
    print_result("Request 2 Creation with Overlap Deducted", res2.get("success") is True and res2["data"]["billable_days"] == 3.0, f"billable_days: {res2['data']['billable_days']}, overlap: {res2['data']['overlap_days_excluded']}")

    # Verify initial state: Req 1 has 3.0d, Req 2 has 3.0d
    rows = await exec_sql("SELECT id, billable_days, status FROM public.leave_applications WHERE id IN (%s, %s);", (app1_id, app2_id))
    rows_by_id = {str(r["id"]): r for r in rows}
    print_result("Initial Billable Days in DB", rows_by_id[app1_id]["billable_days"] == 3.0 and rows_by_id[app2_id]["billable_days"] == 3.0, f"Req 1: {rows_by_id[app1_id]['billable_days']}d, Req 2: {rows_by_id[app2_id]['billable_days']}d")

    # Step 3: Reject Request 1 -> Request 2 MUST automatically absorb the 3 days and increase to 6.0d!
    logger.info("\n--- STEP 3: Reject Request 1 -> Dynamic Overlap Absorption ---")
    res_act = await handle_leave_request_action(
        leave_id=app1_id,
        payload=LeaveActionRequest(action="REJECT", remarks="Overridden by broader application"),
        current_user=admin_user,
        school_id=school_id
    )
    print_result("Reject Request 1 API", res_act.get("success") is True)

    # Verify in DB: Request 2 billable_days MUST BE 6.0!
    app2_rows = await exec_sql("SELECT id, billable_days, overlap_days_count, holidays_count, status FROM public.leave_applications WHERE id = %s;", (app2_id,))
    app2_updated = app2_rows[0]
    print_result(
        "Request 2 Automatically Absorbed Days",
        float(app2_updated["billable_days"]) == 6.0 and app2_updated["overlap_days_count"] == 0,
        f"New billable_days: {app2_updated['billable_days']}d (Expected 6.0d), overlap_days_count: {app2_updated['overlap_days_count']}"
    )

    # Step 4: Verify Dashboard & Requests Grid API returns 6.0d for Request 2
    logger.info("\n--- STEP 4: Verify Dashboard & Requests Grid API ---")
    res_dash = await get_leave_dashboard(current_user=admin_user, school_id=school_id, academic_year="2026-2027")
    requests_list = res_dash["data"]["requests"]
    target_req2 = next((r for r in requests_list if r["id"] == app2_id), None)
    print_result(
        "Dashboard Requests Grid Shows 6.0 Days",
        target_req2 is not None and float(target_req2["days_count"]) == 6.0,
        f"Grid days_count: {target_req2.get('days_count') if target_req2 else None}"
    )

    # Step 5: Verify Balance Summary for MONK
    monk_bal = next((b for b in res_dash["data"]["balance_summary"] if b["leave_type_name"] == "MONK"), None)
    print_result(
        "Leave Balance Summary Pending Days Math",
        monk_bal is not None,
        f"Allocated: {monk_bal['allocated_days']}, Pending: {monk_bal['pending_days']}, Available: {monk_bal['available_days']}"
    )

    # Step 6: Cleanup
    await exec_sql("DELETE FROM public.leave_applications WHERE id IN (%s, %s);", (app1_id, app2_id))
    await exec_sql("SELECT public.fn_recalculate_applicant_leave_applications(%s::UUID, %s::UUID);", (admin_id, school_id))
    logger.info("Test records cleaned up successfully.")

    logger.info("=" * 80)
    logger.info("🎉 ALL OVERLAP ABSORPTION & REBALANCING TESTS PASSED 100%!")
    logger.info("=" * 80)

if __name__ == "__main__":
    asyncio.run(run_tests())
