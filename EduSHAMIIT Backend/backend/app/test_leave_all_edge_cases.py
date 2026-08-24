"""
==============================================================================
Comprehensive Test Suite for Leave Management, Balance Deductions & Edge Cases
EduSHAMIIT Backend - Attendance & Leave Module
==============================================================================
"""

import sys
import json
import time
import uuid
import datetime
from decimal import Decimal
import psycopg2
from psycopg2.extras import RealDictCursor
from jose import jwt
import httpx
from app.config import settings

BASE_URL = "http://127.0.0.1:8000/api"

def get_db_connection():
    return psycopg2.connect(settings.DATABASE_URL)

def print_header(title):
    print("\n" + "=" * 80)
    print(f"  {title.upper()}")
    print("=" * 80)

def print_result(test_name, passed, details=""):
    mark = " [PASS] " if passed else " [FAIL] "
    print(f"{mark:<8} | {test_name}")
    if details:
        print(f"         └─> {details}")
    if not passed:
        sys.exit(1)

def run_tests():
    print_header("Initializing Leave Management Edge-Case Test Suite")
    
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    # 1. Fetch test school and test user (Lakshmi Nair teacher or admin)
    cur.execute("SELECT id, school_id, full_name, email, role FROM public.profiles WHERE full_name ILIKE '%Lakshmi Nair%' LIMIT 1;")
    user = cur.fetchone()
    if not user:
        cur.execute("SELECT id, school_id, full_name, email, role FROM public.profiles WHERE school_id IS NOT NULL LIMIT 1;")
        user = cur.fetchone()
    
    school_id = str(user['school_id'])
    user_id = str(user['id'])
    user_name = user['full_name']
    user_role = user.get('role', 'super_admin')
    print(f"Test User: {user_name} ({user_id}) | Role: {user_role} | School ID: {school_id}")

    # Generate valid signed JWT token
    token_payload = {
        "sub": user_id,
        "id": user_id,
        "school_id": school_id,
        "role": user_role,
        "email": user.get("email", "admin@edushamiit.com"),
        "exp": int(time.time()) + 7200
    }
    jwt_secret = settings.SUPABASE_JWT_SECRET or settings.JWT_SECRET or "super-secret-jwt-token-with-at-least-32-characters-long"
    auth_token = jwt.encode(token_payload, jwt_secret, algorithm="HS256")

    headers = {
        "x-school-id": school_id,
        "Authorization": f"Bearer {auth_token}"
    }

    # Fetch Casual Leave type ID
    cur.execute("SELECT id, name, annual_entitlement FROM public.leave_types WHERE (school_id = %s OR school_id IS NULL) AND name ILIKE 'Casual Leave' LIMIT 1;", (school_id,))
    lt = cur.fetchone()
    casual_lt_id = str(lt['id'])
    print(f"Leave Type: {lt['name']} (ID: {casual_lt_id}, Entitlement: {lt['annual_entitlement']})")

    # Clean up test leaves from prior test runs
    cur.execute("DELETE FROM public.leave_applications WHERE reason ILIKE '[TEST_EDGE_CASE]%';")
    cur.execute("UPDATE public.leave_balances SET used_days = 0.0, pending_days = 0.0 WHERE user_id = %s AND leave_type_id = %s;", (user_id, casual_lt_id))
    conn.commit()
    print_result("Test Environment Reset & Cleanup", True, "Cleaned up any previous test applications")

    # Fetch baseline balance for Casual Leave
    cur.execute("""
        SELECT allocated_days, used_days, pending_days, 
               (allocated_days + carried_forward_days - used_days - pending_days) as available_days
        FROM public.leave_balances
        WHERE user_id = %s AND leave_type_id = %s AND academic_year = '2026-2027';
    """, (user_id, casual_lt_id))
    base_bal = cur.fetchone()
    base_alloc = float(base_bal['allocated_days'])
    base_used = float(base_bal['used_days'])
    base_pending = float(base_bal['pending_days'])
    base_avail = float(base_bal['available_days'])
    print(f"Baseline Balance: Allocated={base_alloc}, Used={base_used}, Pending={base_pending}, Available={base_avail}")

    client = httpx.Client(base_url=BASE_URL, headers=headers, timeout=15.0)

    # --------------------------------------------------------------------------
    # TEST 1: Leave Spanning Official Gazetted Holiday (2026-10-01 to 2026-10-04)
    # 2026-10-02 is Gandhi Jayanti, 2026-10-04 is Sunday Leave.
    # 01 Oct, 02 Oct (Holiday), 03 Oct, 04 Oct (Sunday) = 4 calendar days, 2 holidays -> 2 billable days
    # --------------------------------------------------------------------------
    print_header("Test 1: Full-Day Leave Spanning Official Gandhi Jayanti & Sunday Holidays")
    payload1 = {
        "applicant_id": user_id,
        "leave_type": "Casual Leave",
        "start_date": "2026-10-01",
        "end_date": "2026-10-04",
        "reason": "[TEST_EDGE_CASE] Autumn long weekend",
        "half_day_type": "FULL_DAY"
    }
    r1 = client.post("/attendance/leave/apply", json=payload1)
    if r1.status_code != 200:
        print(f"DEBUG: r1 returned {r1.status_code}: {r1.text}")
    res1 = r1.json()
    passed1 = res1.get("success") is True and res1.get("data", {}).get("billable_days") == 2.0
    app1_id = res1.get("data", {}).get("id")
    print_result("Holiday Exclusion in Apply Leave", passed1, f"Calendar: 4d, Holiday Excluded: {res1.get('data', {}).get('holidays_excluded')}d, Net Billable: {res1.get('data', {}).get('billable_days')}d")

    # Check pending_days updated by EXACTLY 2.0
    cur.execute("SELECT pending_days, used_days FROM public.leave_balances WHERE user_id = %s AND leave_type_id = %s AND academic_year = '2026-2027';", (user_id, casual_lt_id))
    bal1 = cur.fetchone()
    expected_pending1 = base_pending + 2.0
    passed1_bal = float(bal1['pending_days']) == expected_pending1
    print_result("Pending Days Deduction Accuracy", passed1_bal, f"Expected pending: {expected_pending1}, Actual: {bal1['pending_days']}")

    # --------------------------------------------------------------------------
    # TEST 2: Overlapping Leave (2026-10-01 to 2026-10-06)
    # Range: 01 Oct to 06 Oct (6 calendar days).
    # 01-04 Oct -> Already applied in Test 1 (2 working days overlapping: 01, 03 Oct; 2 holidays: 02, 04 Oct)
    # 05 Oct (Mon) -> 1 new working day
    # 06 Oct (Tue) -> 1 new working day
    # Net new billable days = 6 - 2 holidays - 2 overlaps = 2.0 billable days!
    # --------------------------------------------------------------------------
    print_header("Test 2: Overlapping Leave Application Across Existing Leave & Gandhi Jayanti Holiday")
    payload2 = {
        "applicant_id": user_id,
        "leave_type": "Casual Leave",
        "start_date": "2026-10-01",
        "end_date": "2026-10-06",
        "reason": "[TEST_EDGE_CASE] Extended Autumn trip",
        "half_day_type": "FULL_DAY"
    }
    r2 = client.post("/attendance/leave/apply", json=payload2)
    res2 = r2.json()
    passed2 = res2.get("success") is True and res2.get("data", {}).get("billable_days") == 2.0
    app2_id = res2.get("data", {}).get("id")
    print_result("Overlap & Holiday Exclusion in Apply Leave", passed2, f"Calendar: 6d, Overlap Excluded: {res2.get('data', {}).get('overlap_days_excluded')}d, Holidays Excluded: {res2.get('data', {}).get('holidays_excluded')}d, Net Billable: {res2.get('data', {}).get('billable_days')}d")

    # Check pending_days updated by +2.0 more
    cur.execute("SELECT pending_days FROM public.leave_balances WHERE user_id = %s AND leave_type_id = %s AND academic_year = '2026-2027';", (user_id, casual_lt_id))
    bal2 = cur.fetchone()
    expected_pending2 = base_pending + 2.0 + 2.0
    passed2_bal = float(bal2['pending_days']) == expected_pending2
    print_result("Pending Days Accumulation After Overlap", passed2_bal, f"Expected pending: {expected_pending2}, Actual: {bal2['pending_days']}")

    # --------------------------------------------------------------------------
    # TEST 3: 100% Redundant Leave Application (Must be Rejected)
    # 2026-10-01 to 2026-10-03 is completely covered by existing applications
    # --------------------------------------------------------------------------
    print_header("Test 3: Redundant Leave Rejection (All Dates Already Covered)")
    payload3 = {
        "applicant_id": user_id,
        "leave_type": "Casual Leave",
        "start_date": "2026-10-01",
        "end_date": "2026-10-03",
        "reason": "[TEST_EDGE_CASE] Duplicate request",
        "half_day_type": "FULL_DAY"
    }
    r3 = client.post("/attendance/leave/apply", json=payload3)
    passed3 = r3.status_code == 400 or (r3.status_code == 200 and r3.json().get("success") is False)
    print_result("Zero Net Days Rejection Guard", passed3, f"Status: {r3.status_code}, Detail: {r3.text}")

    # --------------------------------------------------------------------------
    # TEST 4: Half-Day Leave on Gandhi Jayanti Holiday (Must be Rejected)
    # --------------------------------------------------------------------------
    print_header("Test 4: Half-Day Leave on Official Gandhi Jayanti Holiday")
    payload4 = {
        "applicant_id": user_id,
        "leave_type": "Casual Leave",
        "start_date": "2026-10-02",
        "end_date": "2026-10-02",
        "reason": "[TEST_EDGE_CASE] Gandhi Jayanti half day",
        "half_day_type": "FIRST_HALF"
    }
    r4 = client.post("/attendance/leave/apply", json=payload4)
    passed4 = r4.status_code == 400 or (r4.status_code == 200 and r4.json().get("success") is False)
    print_result("Half-Day on Holiday Rejection Guard", passed4, f"Status: {r4.status_code}, Response: {r4.text}")

    # --------------------------------------------------------------------------
    # TEST 5: Insufficient Balance Guard (Available Balance is 0.0d -> Must be Blocked)
    # --------------------------------------------------------------------------
    print_header("Test 5: Insufficient Balance Guard")
    payload5 = {
        "applicant_id": user_id,
        "leave_type": "Casual Leave",
        "start_date": "2026-11-02",
        "end_date": "2026-11-14",
        "reason": "[TEST_EDGE_CASE] Exceeding balance request",
        "half_day_type": "FULL_DAY"
    }
    r5 = client.post("/attendance/leave/apply", json=payload5)
    passed5 = r5.status_code == 400 or (r5.status_code == 200 and r5.json().get("success") is False)
    print_result("Insufficient Balance Protection Guard", passed5, f"Status: {r5.status_code}, Response: {r5.text}")

    # --------------------------------------------------------------------------
    # TEST 6: Rejection Workflow Restores Pending Days (2.0d) with zero leak
    # --------------------------------------------------------------------------
    print_header("Test 6: Leave Rejection Balance Rollback")
    cur.execute("SELECT used_days, pending_days FROM public.leave_balances WHERE user_id = %s AND leave_type_id = %s AND academic_year = '2026-2027';", (user_id, casual_lt_id))
    pre_rej = cur.fetchone()

    r6 = client.post(f"/attendance/leave/requests/{app2_id}/action", json={"action": "REJECT", "remarks": "Staff needed on those dates"})
    passed6_api = r6.status_code == 200 and r6.json().get("success") is True

    cur.execute("SELECT used_days, pending_days FROM public.leave_balances WHERE user_id = %s AND leave_type_id = %s AND academic_year = '2026-2027';", (user_id, casual_lt_id))
    post_rej = cur.fetchone()
    used_rej_diff = float(post_rej['used_days']) - float(pre_rej['used_days'])
    pending_rej_diff = float(pre_rej['pending_days']) - float(post_rej['pending_days'])
    passed6 = passed6_api and used_rej_diff == 0.0 and pending_rej_diff == 2.0
    print_result("Pending Days Refund on Rejection", passed6, f"Used unchanged: {used_rej_diff}d, Pending restored: {pending_rej_diff}d (Expected 2.0d)")

    # --------------------------------------------------------------------------
    # TEST 7: Half-Day Leave on Normal Working Day (2026-11-04 Wednesday with restored balance)
    # --------------------------------------------------------------------------
    print_header("Test 7: Half-Day Leave on Working Day")
    payload7 = {
        "applicant_id": user_id,
        "leave_type": "Casual Leave",
        "start_date": "2026-11-04",
        "end_date": "2026-11-04",
        "reason": "[TEST_EDGE_CASE] Half day doctor visit",
        "half_day_type": "FIRST_HALF"
    }
    r7 = client.post("/attendance/leave/apply", json=payload7)
    res7 = r7.json()
    passed7 = res7.get("success") is True and res7.get("data", {}).get("billable_days") == 0.5
    app7_id = res7.get("data", {}).get("id")
    print_result("Half-Day Deduction of 0.5 Days", passed7, f"Net Billable: {res7.get('data', {}).get('billable_days')}d")

    # --------------------------------------------------------------------------
    # TEST 8: Approval Workflow Moves EXACT Billable Days (2.0d) to used_days
    # --------------------------------------------------------------------------
    print_header("Test 8: Leave Approval Balance Transition")
    cur.execute("SELECT used_days, pending_days FROM public.leave_balances WHERE user_id = %s AND leave_type_id = %s AND academic_year = '2026-2027';", (user_id, casual_lt_id))
    pre_app = cur.fetchone()
    
    r8 = client.post(f"/attendance/leave/requests/{app1_id}/action", json={"action": "APPROVE", "remarks": "Approved autumn trip"})
    passed8_api = r8.status_code == 200 and r8.json().get("success") is True

    cur.execute("SELECT used_days, pending_days FROM public.leave_balances WHERE user_id = %s AND leave_type_id = %s AND academic_year = '2026-2027';", (user_id, casual_lt_id))
    post_app = cur.fetchone()
    used_diff = float(post_app['used_days']) - float(pre_app['used_days'])
    pending_diff = float(pre_app['pending_days']) - float(post_app['pending_days'])
    passed8 = passed8_api and used_diff == 2.0 and pending_diff == 2.0
    print_result("Exact Billable Days Transition on Approval", passed8, f"Used increased by: {used_diff}d (Expected 2.0d), Pending decreased by: {pending_diff}d (Expected 2.0d)")

    # --------------------------------------------------------------------------
    # TEST 9: Dashboard API & Balance Summary Accuracy
    # --------------------------------------------------------------------------
    print_header("Test 9: Dashboard Endpoint & Balance Summary Verification")
    r9 = client.get(f"/attendance/leave/dashboard?user_type=ALL&department=ALL")
    passed9_api = r9.status_code == 200 and r9.json().get("success") is True
    dash_data = r9.json().get("data", {})
    balance_summaries = dash_data.get("balance_summary", [])
    casual_summary = next((b for b in balance_summaries if b.get("leave_type_name") == "Casual Leave"), None)
    
    cur.execute("SELECT allocated_days, used_days, pending_days, (allocated_days + carried_forward_days - used_days - pending_days) as avail FROM public.leave_balances WHERE user_id = %s AND leave_type_id = %s AND academic_year = '2026-2027';", (user_id, casual_lt_id))
    actual_db = cur.fetchone()
    
    passed9_bal = False
    if casual_summary:
        dash_avail = float(casual_summary.get("available_days", -1))
        db_avail = float(actual_db['avail'])
        passed9_bal = dash_avail == db_avail
    
    print_result("Dashboard Balance Summary Consistency", passed9_api and passed9_bal, f"Dashboard available: {casual_summary.get('available_days')}, DB available: {actual_db['avail']}")

    # --------------------------------------------------------------------------
    # Cleanup test records
    # --------------------------------------------------------------------------
    print_header("Cleaning Up Test Artifacts & Resyncing")
    cur.execute("DELETE FROM public.leave_applications WHERE reason ILIKE '[TEST_EDGE_CASE]%';")
    cur.execute("SELECT public.fn_sync_all_leave_balances();")
    conn.commit()
    print_result("Cleaned Test Records & Resynchronized All Balances", True)

    print("\n" + "=" * 80)
    print("  ALL 9 EDGE-CASE TESTS PASSED WITH 100% SUCCESS!")
    print("=" * 80 + "\n")

    cur.close()
    conn.close()

if __name__ == "__main__":
    run_tests()
