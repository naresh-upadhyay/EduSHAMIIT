import asyncio
import logging
import uuid
from app.api.attendance import exec_sql

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("TestZeroRedundancySSOT")

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

async def run_ssot_integrity_tests():
    logger.info("================================================================================")
    logger.info("🚀 STARTING ZERO-REDUNDANCY & SINGLE SOURCE OF TRUTH (SSOT) TEST SUITE")
    logger.info("================================================================================")

    school_id = "11111111-1111-1111-1111-111111111111"
    # Use dedicated test user
    user_res = await exec_sql("SELECT id, full_name, role FROM public.profiles WHERE full_name ILIKE '%Lakshmi Nair%' LIMIT 1;")
    user_id = str(user_res[0]["id"])
    
    # Fetch Casual Leave and Medical Leave IDs
    cl_res = await exec_sql("SELECT id FROM public.leave_types WHERE name = 'Casual Leave' LIMIT 1;")
    cl_id = str(cl_res[0]["id"])

    ml_res = await exec_sql("SELECT id FROM public.leave_types WHERE name = 'Medical Leave' LIMIT 1;")
    ml_id = str(ml_res[0]["id"])

    # --------------------------------------------------------------------------
    # SCENARIO 1: No Redundant User Profile Fields in Balance and Application Tables
    # --------------------------------------------------------------------------
    logger.info("\n--- SCENARIO 1: Database Normalization Audit ---")
    bal_cols_res = await exec_sql("""
        SELECT column_name FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'leave_balances';
    """)
    bal_cols = [r["column_name"] for r in bal_cols_res]
    
    redundant_bal_cols = [c for c in ["full_name", "user_name", "email", "role", "avatar_url", "department", "designation"] if c in bal_cols]
    assert_test(
        "leave_balances contains zero redundant user profile columns",
        len(redundant_bal_cols) == 0,
        f"(Columns in leave_balances: {bal_cols})"
    )

    # --------------------------------------------------------------------------
    # SCENARIO 2: Automatic Trigger Sync on Direct SQL INSERT (SSOT)
    # --------------------------------------------------------------------------
    logger.info("\n--- SCENARIO 2: Automatic SSOT Trigger Sync on INSERT ---")
    await exec_sql("DELETE FROM public.leave_applications WHERE reason ILIKE '%[SSOT_TEST]%';")

    # Read initial Casual Leave baseline from SSOT ledger
    cl_app_res = await exec_sql("SELECT COALESCE(SUM(billable_days), 0.0) as used FROM public.leave_applications WHERE applicant_id = %s::UUID AND leave_type_id = %s::UUID AND status = 'approved';", (user_id, cl_id))
    init_used = float(cl_app_res[0]["used"]) if cl_app_res else 0.0

    cl_pend_res = await exec_sql("SELECT COALESCE(SUM(billable_days), 0.0) as pending FROM public.leave_applications WHERE applicant_id = %s::UUID AND leave_type_id = %s::UUID AND status = 'pending';", (user_id, cl_id))
    init_pending = float(cl_pend_res[0]["pending"]) if cl_pend_res else 0.0

    test_app_id = str(uuid.uuid4())
    # Insert application directly via SQL WITHOUT manually touching leave_balances
    await exec_sql("""
        INSERT INTO public.leave_applications (
            id, school_id, applicant_id, leave_type_id, leave_type,
            start_date, end_date, reason, status, billable_days
        ) VALUES (
            %s::UUID, %s::UUID, %s::UUID, %s::UUID, 'Casual Leave',
            '2026-11-20', '2026-11-21', '[SSOT_TEST] Direct SQL Insert', 'pending', 2.0
        );
    """, (test_app_id, school_id, user_id, cl_id))

    # Read updated balance
    bal1_res = await exec_sql("SELECT used_days, pending_days FROM public.leave_balances WHERE user_id = %s::UUID AND leave_type_id = %s::UUID AND academic_year = '2026-2027';", (user_id, cl_id))
    new_pending = float(bal1_res[0]["pending_days"])
    assert_test(
        "Database trigger automatically synchronized pending_days (+2.0d) without manual table update",
        new_pending == init_pending + 2.0,
        f"(Initial Pending: {init_pending}, New Pending: {new_pending})"
    )

    # --------------------------------------------------------------------------
    # SCENARIO 3: Automatic Trigger Sync on Direct Status UPDATE (Pending -> Approved)
    # --------------------------------------------------------------------------
    logger.info("\n--- SCENARIO 3: Automatic SSOT Trigger Sync on Status UPDATE ---")
    await exec_sql("""
        UPDATE public.leave_applications 
        SET status = 'approved' 
        WHERE id = %s::UUID;
    """, (test_app_id,))

    bal2_res = await exec_sql("SELECT used_days, pending_days FROM public.leave_balances WHERE user_id = %s::UUID AND leave_type_id = %s::UUID AND academic_year = '2026-2027';", (user_id, cl_id))
    approved_used = float(bal2_res[0]["used_days"])
    approved_pending = float(bal2_res[0]["pending_days"])
    assert_test(
        "Database trigger automatically transitioned 2.0d from pending to used on status change",
        approved_used == init_used + 2.0 and approved_pending == init_pending,
        f"(Used: {approved_used} (Expected: {init_used + 2.0}), Pending: {approved_pending} (Expected: {init_pending}))"
    )

    # --------------------------------------------------------------------------
    # SCENARIO 4: Cross-Policy Modification (Casual Leave -> Medical Leave)
    # --------------------------------------------------------------------------
    logger.info("\n--- SCENARIO 4: Cross-Policy Modification Trigger Sync ---")
    ml_bal0 = await exec_sql("SELECT used_days, pending_days FROM public.leave_balances WHERE user_id = %s::UUID AND leave_type_id = %s::UUID AND academic_year = '2026-2027';", (user_id, ml_id))
    init_ml_used = float(ml_bal0[0]["used_days"]) if ml_bal0 else 0.0

    # Change leave type of application to Medical Leave
    await exec_sql("""
        UPDATE public.leave_applications 
        SET leave_type_id = %s::UUID, leave_type = 'Medical Leave' 
        WHERE id = %s::UUID;
    """, (ml_id, test_app_id))

    cl_bal_after = await exec_sql("SELECT used_days, pending_days FROM public.leave_balances WHERE user_id = %s::UUID AND leave_type_id = %s::UUID AND academic_year = '2026-2027';", (user_id, cl_id))
    ml_bal_after = await exec_sql("SELECT used_days, pending_days FROM public.leave_balances WHERE user_id = %s::UUID AND leave_type_id = %s::UUID AND academic_year = '2026-2027';", (user_id, ml_id))
    
    cl_refunded = float(cl_bal_after[0]["used_days"]) == init_used
    ml_debited = float(ml_bal_after[0]["used_days"]) == init_ml_used + 2.0

    assert_test(
        "Cross-policy update synchronized BOTH old and new leave balances simultaneously",
        cl_refunded and ml_debited,
        f"(CL used restored: {cl_bal_after[0]['used_days']}, ML used credited: {ml_bal_after[0]['used_days']})"
    )

    # --------------------------------------------------------------------------
    # SCENARIO 5: Automatic Trigger Sync on Direct SQL DELETE (Clean Zero-Leak Refund)
    # --------------------------------------------------------------------------
    logger.info("\n--- SCENARIO 5: Automatic SSOT Trigger Sync on DELETE ---")
    await exec_sql("DELETE FROM public.leave_applications WHERE id = %s::UUID;", (test_app_id,))

    ml_bal_final = await exec_sql("SELECT used_days, pending_days FROM public.leave_balances WHERE user_id = %s::UUID AND leave_type_id = %s::UUID AND academic_year = '2026-2027';", (user_id, ml_id))
    final_ml_used = float(ml_bal_final[0]["used_days"])
    assert_test(
        "Database trigger refunded balance immediately upon application deletion with zero leak",
        final_ml_used == init_ml_used,
        f"(Final ML Used: {final_ml_used}, Expected: {init_ml_used})"
    )

    logger.info("================================================================================")
    logger.info(f"🏁 ZERO-REDUNDANCY & SSOT SUITE: {passed_count} PASSED | {failed_count} FAILED")
    logger.info("================================================================================")

if __name__ == "__main__":
    asyncio.run(run_ssot_integrity_tests())
