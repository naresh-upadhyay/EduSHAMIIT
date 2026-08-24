import asyncio
import json
import logging
import uuid
from app.api.attendance import (
    exec_sql,
    get_leave_dashboard,
    apply_leave,
    ApplyLeaveRequest,
    handle_leave_request_action,
    LeaveActionRequest,
    get_leave_types,
    upsert_leave_type,
    LeaveTypePayload,
    get_leave_balances,
    adjust_leave_balance,
    BalanceAdjustmentPayload,
    get_permission_requests,
    apply_permission,
    ApplyPermissionPayload,
    handle_permission_action,
    PermissionActionPayload,
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("TestLeaveAndPermissions")

async def run_tests():
    logger.info("==========================================================================")
    logger.info("  TESTING COMPLETE ENTERPRISE LEAVE & PERMISSIONS SYSTEM (E2E)            ")
    logger.info("==========================================================================")

    # 1. Fetch school and profiles
    schools = await exec_sql("SELECT id FROM public.schools LIMIT 1;")
    school_id = str(schools[0]["id"])

    admin_profile = await exec_sql("SELECT id, full_name, email, role FROM public.profiles WHERE role = 'super_admin' LIMIT 1;")
    admin_id = str(admin_profile[0]["id"])
    admin_dict = {"id": admin_id, "role": "super_admin", "email": admin_profile[0]["email"], "school_id": school_id}

    teacher_profile = await exec_sql("SELECT id, full_name, email, role FROM public.profiles WHERE full_name ILIKE '%Lakshmi Nair%' LIMIT 1;")
    teacher_id = str(teacher_profile[0]["id"])
    teacher_name = teacher_profile[0]["full_name"]
    teacher_dict = {"id": teacher_id, "role": "teacher", "email": teacher_profile[0]["email"], "school_id": school_id}

    logger.info(f"Using School: {school_id}")
    logger.info(f"Using Admin: {admin_profile[0]['full_name']} ({admin_id})")
    logger.info(f"Using Teacher: {teacher_name} ({teacher_id})")

    # -------------------------------------------------------------------------
    # TEST 1: Dashboard API with KPIs, Requests, Balances, Upcoming Leaves
    # -------------------------------------------------------------------------
    logger.info("\n--- TEST 1: Fetching Leave & Permissions Dashboard ---")
    dash = await get_leave_dashboard(
        user_type="ALL",
        department="ALL",
        status="ALL",
        leave_type="ALL",
        search="",
        from_date=None,
        to_date=None,
        page=1,
        page_size=10,
        manager_id=None,
        current_user=admin_dict,
        school_id=school_id
    )
    assert dash["success"] is True
    kpi = dash["data"]["kpi"]
    requests = dash["data"]["requests"]
    balance_summary = dash["data"]["balance_summary"]
    upcoming = dash["data"]["upcoming_leaves"]

    pending_reqs = kpi.get('pending_approvals', kpi.get('pending_requests', 0))
    logger.info(f"KPI Totals -> Total: {kpi.get('total_requests')}, Approved: {kpi.get('approved_leaves')}, Pending: {pending_reqs}, Rejected: {kpi.get('rejected_leaves')}")
    logger.info(f"Leave Requests Count on Page 1: {len(requests)}")
    logger.info(f"Balance Summary Categories: {len(balance_summary)}")
    logger.info(f"Upcoming Leaves Count: {len(upcoming)}")
    assert len(balance_summary) > 0
    logger.info("✅ Dashboard API successfully aggregated all metrics and components!")

    # -------------------------------------------------------------------------
    # TEST 2: Leave Types List & Policy Upsert
    # -------------------------------------------------------------------------
    logger.info("\n--- TEST 2: Fetching & Creating Custom Leave Type ---")
    types_res = await get_leave_types(current_user=admin_dict, school_id=school_id)
    assert types_res["success"] is True
    existing_types = types_res["data"]["leave_types"]
    logger.info(f"Existing Leave Types in System: {[t['name'] for t in existing_types]}")

    # Upsert a new special type "Sabbatical Leave"
    upsert_res = await upsert_leave_type(
        payload=LeaveTypePayload(
            name="Sabbatical Research Leave",
            code="SAB",
            category="SPECIAL",
            annual_entitlement=30.0,
            allow_half_day=False,
            color_hex="#6366F1",
            is_active=True
        ),
        current_user=admin_dict,
        school_id=school_id
    )
    assert upsert_res["success"] is True
    sab_id = upsert_res["data"]["id"]
    logger.info(f"✅ Upserted Leave Type 'Sabbatical Research Leave' (ID: {sab_id})")

    # -------------------------------------------------------------------------
    # TEST 3: Apply for Leave Request (Full Day & Half Day Validation)
    # -------------------------------------------------------------------------
    logger.info("\n--- TEST 3: Submitting Leave Application ---")
    test_start = "2026-09-01"
    test_end = "2026-09-03"

    # Clean previous test record if exists
    await exec_sql("DELETE FROM public.leave_applications WHERE applicant_id = %s::UUID AND start_date = %s::DATE;", (teacher_id, test_start))

    apply_res = await apply_leave(
        payload=ApplyLeaveRequest(
            applicant_id=uuid.UUID(teacher_id),
            leave_type="Casual Leave",
            start_date=test_start,
            end_date=test_end,
            reason="Attending academic conference in New Delhi",
            half_day_type="FULL_DAY",
            contact_number="+91 9876543210"
        ),
        current_user=teacher_dict,
        school_id=school_id
    )
    assert apply_res["success"] is True
    leave_id = apply_res["data"]["id"]
    req_code = apply_res["data"]["request_code"]
    days_count = apply_res["data"]["days_count"]
    logger.info(f"✅ Leave Applied! Request Code: {req_code}, Days: {days_count}, Leave ID: {leave_id}")
    assert float(days_count) == 3.0

    # -------------------------------------------------------------------------
    # TEST 4: Approve Leave & Verify Attendance Auto-Sync (ON_LEAVE)
    # -------------------------------------------------------------------------
    logger.info("\n--- TEST 4: Approving Leave Request & Verifying Attendance Synchronization ---")
    action_res = await handle_leave_request_action(
        leave_id=uuid.UUID(leave_id),
        payload=LeaveActionRequest(action="APPROVE", remarks="Approved for international presentation"),
        current_user=admin_dict,
        school_id=school_id
    )
    assert action_res["success"] is True
    logger.info(f"✅ Leave Action Result: {action_res['message']}")

    # Check attendance_staff_records for ON_LEAVE on 2026-09-01
    staff_att_rows = await exec_sql(
        "SELECT status, remarks FROM public.attendance_staff_records WHERE employee_id = %s::UUID AND attendance_date = %s::DATE;",
        (teacher_id, test_start)
    )
    assert len(staff_att_rows) > 0
    assert staff_att_rows[0]["status"] == "ON_LEAVE"
    logger.info(f"✅ Verified Attendance Synchronization: {teacher_name} is marked 'ON_LEAVE' on {test_start} ({staff_att_rows[0]['remarks']})")

    # -------------------------------------------------------------------------
    # TEST 5: Leave Balances & Manual Adjustment with Audit Log
    # -------------------------------------------------------------------------
    logger.info("\n--- TEST 5: Balance Query & Manual Balance Adjustment ---")
    bal_res = await get_leave_balances(
        academic_year="2026-2027",
        department="ALL",
        role="ALL",
        search="Lakshmi",
        current_user=admin_dict,
        school_id=school_id
    )
    logger.info(f"DEBUG bal_res: {bal_res}")
    flat_bals = bal_res.get("data", {}).get("flat_balances", [])
    logger.info(f"DEBUG flat_bals: {flat_bals}")
    user_bals = [b for b in flat_bals if str(b.get("user_id")) == teacher_id or str(b.get("employee_id")) == teacher_id]
    logger.info(f"Teacher Balances Count: {len(user_bals)}")

    cl_bal = next(b for b in user_bals if b["leave_type_name"] == "Casual Leave")
    cl_type_id = cl_bal["leave_type_id"]

    # Adjust balance by +2.0 days credit
    adj_res = await adjust_leave_balance(
        payload=BalanceAdjustmentPayload(
            user_id=uuid.UUID(teacher_id),
            leave_type_id=uuid.UUID(cl_type_id),
            adjustment_days=2.0,
            reason="Compensatory credit for Sunday symposium coordination",
            academic_year="2026-2027"
        ),
        current_user=admin_dict,
        school_id=school_id
    )
    assert adj_res["success"] is True
    logger.info(f"✅ Balance Adjusted: {adj_res['data']}")

    # Verify audit log was recorded
    audit_rows = await exec_sql(
        "SELECT action, old_value, new_value, reason FROM public.leave_audit_logs WHERE user_id = %s::UUID ORDER BY created_at DESC LIMIT 1;",
        (teacher_id,)
    )
    assert len(audit_rows) > 0
    assert audit_rows[0]["action"] == "BALANCE_ADJUST"
    logger.info(f"✅ Verified Immutable Audit Log: Action={audit_rows[0]['action']}, Reason='{audit_rows[0]['reason']}'")

    # -------------------------------------------------------------------------
    # TEST 6: Short Permission / Hourly Leave Request & Approval
    # -------------------------------------------------------------------------
    logger.info("\n--- TEST 6: Submitting and Approving Short Permission Request ---")
    perm_res = await apply_permission(
        payload=ApplyPermissionPayload(
            applicant_id=uuid.UUID(teacher_id),
            permission_type="EARLY_DEPARTURE",
            permission_date="2026-08-25",
            start_time="15:00:00",
            end_time="16:30:00",
            duration_hours=1.5,
            reason="Parent-teacher health checkup consultation"
        ),
        current_user=teacher_dict,
        school_id=school_id
    )
    assert perm_res["success"] is True
    perm_id = perm_res["data"]["id"]
    perm_code = perm_res["data"]["request_code"]
    logger.info(f"✅ Permission Request Created! Code: {perm_code}, ID: {perm_id}")

    # Approve Permission
    perm_act_res = await handle_permission_action(
        permission_id=uuid.UUID(perm_id),
        payload=PermissionActionPayload(action="APPROVE", remarks="Approved with class cover arranged"),
        current_user=admin_dict,
        school_id=school_id
    )
    assert perm_act_res["success"] is True
    assert perm_act_res["data"]["status"] == "APPROVED"
    logger.info(f"✅ Permission Request Approved: {perm_act_res['data']['status']}")

    logger.info("\n==========================================================================")
    logger.info("  🎉 ALL LEAVE, BALANCES, PERMISSIONS & DASHBOARD TESTS PASSED 100%!       ")
    logger.info("==========================================================================")

if __name__ == "__main__":
    asyncio.run(run_tests())
