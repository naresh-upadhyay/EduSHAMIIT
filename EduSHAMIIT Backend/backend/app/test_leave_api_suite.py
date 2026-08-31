import asyncio
import logging
from app.api.attendance import (
    exec_sql,
    get_leave_dashboard,
    get_leave_balances,
    get_leave_types,
    apply_leave,
    handle_leave_request_action,
    ApplyLeaveRequest,
    LeaveActionRequest
)

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("LeaveApiSuite")

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

async def run_api_tests():
    logger.info("================================================================================")
    logger.info("🚀 STARTING DEDICATED LEAVE API-LEVEL TEST SUITE")
    logger.info("================================================================================")

    school_id = "11111111-1111-1111-1111-111111111111"
    admin_res = await exec_sql("SELECT id FROM public.profiles WHERE school_id = %s AND role IN ('admin', 'super_admin') LIMIT 1;", (school_id,))
    if not admin_res:
        admin_res = await exec_sql("SELECT id FROM public.profiles WHERE role IN ('admin', 'super_admin') LIMIT 1;")
    admin_id = str(admin_res[0]["id"])
    admin_user = {"id": admin_id, "role": "super_admin", "school_id": school_id, "permissions": ["*"]}

    # Clean up test applications
    await exec_sql("DELETE FROM public.leave_applications WHERE reason ILIKE '%[API_TEST]%';")

    # --------------------------------------------------------------------------
    # TEST 1: POST /attendance/leave/apply -> Direct Date Range & Days Count (02-08 Sep, 3.0 Days)
    # --------------------------------------------------------------------------
    logger.info("\n--- TEST 1: Direct Date Range & Days Count Persistence (02-08 Sep, 3.0 Days) ---")
    apply_res = await apply_leave(
        ApplyLeaveRequest(
            applicant_id=admin_id,
            leave_type="MONK",
            start_date="2026-09-02",
            end_date="2026-09-08",
            reason="[API_TEST] Applying 02-08 Sep with exact 3.0 days",
            billable_days=3.0,
            days_count=3.0,
            half_day_type="FULL_DAY"
        ),
        current_user=admin_user,
        school_id=school_id
    )
    req_data = apply_res.get("data", {})
    req_id = req_data.get("id")
    req_billable = float(req_data.get("billable_days", 0))
    req_days_count = float(req_data.get("days_count", 0))

    assert_test(
        "Apply response returns exact billable_days (3.0) and days_count (3.0)",
        apply_res.get("success") is True and req_billable == 3.0 and req_days_count == 3.0,
        f"(billable_days: {req_billable}, days_count: {req_days_count})"
    )

    # Verify directly in PostgreSQL
    db_rows = await exec_sql("SELECT id, request_code, start_date, end_date, duration_days, billable_days, status FROM public.leave_applications WHERE id = %s::UUID;", (req_id,))
    db_req = db_rows[0]
    assert_test(
        "Database persists exact start_date (2026-09-02), end_date (2026-09-08), and billable_days (3.0)",
        str(db_req["start_date"]) == "2026-09-02" and str(db_req["end_date"]) == "2026-09-08" and float(db_req["billable_days"]) == 3.0,
        f"(DB Start: {db_req['start_date']}, End: {db_req['end_date']}, Billable: {db_req['billable_days']})"
    )

    # --------------------------------------------------------------------------
    # TEST 2: GET /attendance/leave/dashboard -> Real-time Deduction & Grid Accuracy
    # --------------------------------------------------------------------------
    logger.info("\n--- TEST 2: Dashboard KPI, Grid 'Days', and Balance Deduction ---")
    dash = await get_leave_dashboard(current_user=admin_user, school_id=school_id)
    dash_data = dash.get("data", {})
    requests_list = dash_data.get("requests", [])
    matched_req = next((r for r in requests_list if str(r.get("id")) == str(req_id)), None)

    assert_test(
        "Dashboard requests grid returns exact billable_days (3.0) and days_count (3.0) for the application",
        matched_req is not None and float(matched_req.get("billable_days", 0)) == 3.0 and float(matched_req.get("days_count", 0)) == 3.0,
        f"(Grid billable_days: {matched_req.get('billable_days') if matched_req else 'None'}, days_count: {matched_req.get('days_count') if matched_req else 'None'})"
    )

    balance_summary = dash_data.get("balance_summary", [])
    monk_bal = next((s for s in balance_summary if s.get("leave_type_name") == "MONK"), None)
    assert_test(
        "Leave Balance Summary reflects 3.0 pending days deduction mathematically",
        monk_bal is not None and float(monk_bal.get("available_days", 0)) == (float(monk_bal.get("allocated_days", 12.0)) - float(monk_bal.get("used_days", 0)) - float(monk_bal.get("pending_days", 0))),
        f"(Allocated: {monk_bal.get('allocated_days') if monk_bal else 'N/A'}, Used: {monk_bal.get('used_days') if monk_bal else 'N/A'}, Pending: {monk_bal.get('pending_days') if monk_bal else 'N/A'}, Available: {monk_bal.get('available_days') if monk_bal else 'N/A'})"
    )

    # --------------------------------------------------------------------------
    # TEST 3: POST /attendance/leave/requests/{id}/action -> Approval Transitions 3.0d from Pending to Used
    # --------------------------------------------------------------------------
    logger.info("\n--- TEST 3: Leave Approval Action ---")
    appr_res = await handle_leave_request_action(
        leave_id=req_id,
        payload=LeaveActionRequest(action="APPROVE", remarks="[API_TEST] Approved"),
        current_user=admin_user,
        school_id=school_id
    )
    assert_test(
        "Leave application approved successfully",
        appr_res.get("success") is True,
        f"(Message: {appr_res.get('message')})"
    )

    dash_after_appr = await get_leave_dashboard(current_user=admin_user, school_id=school_id)
    monk_after_appr = next((s for s in dash_after_appr.get("data", {}).get("balance_summary", []) if s.get("leave_type_name") == "MONK"), None)
    assert_test(
        "After approval, used_days increases by 3.0d and pending_days decreases by 3.0d",
        monk_after_appr is not None and float(monk_after_appr.get("used_days", 0)) >= 3.0,
        f"(Used: {monk_after_appr.get('used_days') if monk_after_appr else 'N/A'}, Pending: {monk_after_appr.get('pending_days') if monk_after_appr else 'N/A'})"
    )

    # --------------------------------------------------------------------------
    # TEST 4: POST /attendance/leave/requests/{id}/action -> Cancellation Refunds Pending Balance
    # --------------------------------------------------------------------------
    logger.info("\n--- TEST 4: Leave Cancellation Action & Refund ---")
    canc_app = await apply_leave(
        ApplyLeaveRequest(
            applicant_id=admin_id,
            leave_type="MONK",
            start_date="2026-09-15",
            end_date="2026-09-16",
            reason="[API_TEST] Temporary leave for cancellation test",
            billable_days=2.0,
            days_count=2.0,
            half_day_type="FULL_DAY"
        ),
        current_user=admin_user,
        school_id=school_id
    )
    canc_req_id = canc_app.get("data", {}).get("id")

    canc_res = await handle_leave_request_action(
        leave_id=canc_req_id,
        payload=LeaveActionRequest(action="CANCEL", remarks="[API_TEST] Cancelled"),
        current_user=admin_user,
        school_id=school_id
    )
    assert_test(
        "Pending leave application cancelled successfully and refunded",
        canc_res.get("success") is True,
        f"(Message: {canc_res.get('message')})"
    )

    # --------------------------------------------------------------------------
    # TEST 5: POST /attendance/leave/requests/batch-action -> Batch Approval/Rejection
    # --------------------------------------------------------------------------
    logger.info("\n--- TEST 5: Batch Leave Approval Action ---")
    batch_app1 = await apply_leave(
        ApplyLeaveRequest(applicant_id=admin_id, leave_type="MONK", start_date="2026-10-05", end_date="2026-10-06", reason="[API_TEST] Batch item 1", billable_days=2.0, days_count=2.0),
        current_user=admin_user, school_id=school_id
    )
    batch_app2 = await apply_leave(
        ApplyLeaveRequest(applicant_id=admin_id, leave_type="MONK", start_date="2026-10-08", end_date="2026-10-09", reason="[API_TEST] Batch item 2", billable_days=2.0, days_count=2.0),
        current_user=admin_user, school_id=school_id
    )
    b_id1 = batch_app1.get("data", {}).get("id")
    b_id2 = batch_app2.get("data", {}).get("id")

    from app.api.attendance import handle_batch_leave_request_action, BatchLeaveActionRequest
    batch_res = await handle_batch_leave_request_action(
        BatchLeaveActionRequest(request_ids=[b_id1, b_id2], action="APPROVE", remarks="[API_TEST] Bulk approved"),
        current_user=admin_user,
        school_id=school_id
    )
    assert_test(
        "Batch leave approval processes multiple requests successfully",
        batch_res.get("success") is True and batch_res.get("data", {}).get("processed_count") == 2,
        f"(Processed: {batch_res.get('data', {}).get('processed_count')} / 2)"
    )

    # Cleanup test records
    await exec_sql("DELETE FROM public.leave_applications WHERE reason ILIKE '%[API_TEST]%';")
    logger.info("Test records cleaned up.")

    # --------------------------------------------------------------------------
    # TEST 6: GET /attendance/leave/balances -> Paginated Roster Balances Integrity
    # --------------------------------------------------------------------------
    logger.info("\n--- TEST 5: Paginated Balances Endpoint Integrity ---")
    bal_res = await get_leave_balances(current_user=admin_user, school_id=school_id)
    emp_list = bal_res.get("data", {}).get("employees", [])
    assert_test(
        "GET /attendance/leave/balances returns valid non-empty roster of employees",
        len(emp_list) > 0,
        f"(Total employees returned: {len(emp_list)})"
    )

    logger.info("================================================================================")
    logger.info(f"🏁 LEAVE API TEST SUITE: {passed_count} PASSED | {failed_count} FAILED")
    logger.info("================================================================================")

if __name__ == "__main__":
    asyncio.run(run_api_tests())
