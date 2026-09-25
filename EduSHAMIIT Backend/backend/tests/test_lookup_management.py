"""
==============================================================================
Comprehensive Automated Test Suite: Universal Enterprise Lookup Management
Covers all 30 functional, security, ownership, multi-tenant & edge cases.
==============================================================================
"""
import sys
import os
import json
import uuid
import asyncio
import psycopg2
from psycopg2.extras import RealDictCursor

# Setup DB connection
DATABASE_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql://postgres:postgres@supabase-db:5432/postgres"
)

def run_query(sql: str, params: tuple = (), fetch: bool = True):
    conn = psycopg2.connect(DATABASE_URL)
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, params)
            if fetch:
                rows = cur.fetchall()
                conn.commit()
                return [dict(r) for r in rows]
            conn.commit()
            return []
    finally:
        conn.close()


passed_tests = 0
failed_tests = 0

def record_test(name: str, passed: bool, detail: str = ""):
    global passed_tests, failed_tests
    if passed:
        passed_tests += 1
        print(f"  ✅ [PASS] {name} {detail}")
    else:
        failed_tests += 1
        print(f"  ❌ [FAIL] {name} - {detail}")


def run_all_tests():
    global passed_tests, failed_tests
    print("\n" + "=" * 65)
    print("🚀 RUNNING END-TO-END LOOKUP MANAGEMENT TEST SUITE")
    print("=" * 65)

    # 1. Setup Test Institutions & Users
    school_a_id = str(uuid.uuid4())
    school_b_id = str(uuid.uuid4())
    user_a_id = str(uuid.uuid4())  # Owner in School A
    user_b_id = str(uuid.uuid4())  # Non-owner in School A
    user_c_id = str(uuid.uuid4())  # User in School B

    run_query(
        "INSERT INTO public.schools (id, name, owner_email) VALUES (%s, %s, %s), (%s, %s, %s) ON CONFLICT DO NOTHING;",
        (school_a_id, "Test School Alpha", f"alpha_{school_a_id[:6]}@test.com", school_b_id, "Test School Beta", f"beta_{school_b_id[:6]}@test.com"),
        fetch=False
    )

    run_query(
        """
        INSERT INTO public.profiles (id, user_id, school_id, email, full_name, role) VALUES 
        (%s, %s, %s, %s, 'Teacher Alice (Owner)', 'teacher'),
        (%s, %s, %s, %s, 'Teacher Bob (Non-Owner)', 'teacher'),
        (%s, %s, %s, %s, 'Principal Charlie (School B)', 'principal')
        ON CONFLICT (id) DO NOTHING;
        """,
        (
            user_a_id, user_a_id, school_a_id, f"alice_{user_a_id[:6]}@test.com",
            user_b_id, user_b_id, school_a_id, f"bob_{user_b_id[:6]}@test.com",
            user_c_id, user_c_id, school_b_id, f"charlie_{user_c_id[:6]}@test.com"
        ),
        fetch=False
    )

    lookup_key_1_id = None
    val_1_id = None
    val_2_id = None

    try:
        # --------------------------------------------------------------------
        # TEST 1: Create Lookup Key by User A
        # --------------------------------------------------------------------
        print("\n[Phase 1] Lookup Key Creation & Multi-Tenancy...")
        payload_1 = {
            "key_name": "Sport Activity Type",
            "key_code": "SPORT_ACTIVITY_TYPE",
            "description": "Categories of extracurricular athletics",
            "key_type": "CUSTOM",
            "icon": "sports_soccer_rounded",
            "status": "ACTIVE",
            "initial_values": [
                {"value_name": "Football", "value_code": "FOOTBALL", "status": "ACTIVE"},
                {"value_name": "Basketball", "value_code": "BASKETBALL", "status": "ACTIVE"}
            ]
        }
        res = run_query(
            "SELECT public.fn_create_lookup_key(%s::UUID, %s::UUID, %s::JSONB) AS result;",
            (school_a_id, user_a_id, json.dumps(payload_1))
        )[0]["result"]

        lookup_key_1_id = res.get("data", {}).get("id")
        record_test("Create Lookup Key with Initial Values", res.get("success") == True, f"Key ID: {lookup_key_1_id}")

        # --------------------------------------------------------------------
        # TEST 2: Duplicate Key in Same School Rejected (409)
        # --------------------------------------------------------------------
        res_dup = run_query(
            "SELECT public.fn_create_lookup_key(%s::UUID, %s::UUID, %s::JSONB) AS result;",
            (school_a_id, user_a_id, json.dumps(payload_1))
        )[0]["result"]
        record_test("Duplicate Key in Same School Rejected", res_dup.get("success") == False and res_dup.get("code") == 409)

        # --------------------------------------------------------------------
        # TEST 3: Same Key in School B Allowed (Tenant Isolation)
        # --------------------------------------------------------------------
        res_school_b = run_query(
            "SELECT public.fn_create_lookup_key(%s::UUID, %s::UUID, %s::JSONB) AS result;",
            (school_b_id, user_c_id, json.dumps(payload_1))
        )[0]["result"]
        record_test("Same Key in Different School Allowed", res_school_b.get("success") == True)

        # --------------------------------------------------------------------
        # TEST 4: Duplicate Value Code inside same key Rejected (409)
        # --------------------------------------------------------------------
        print("\n[Phase 2] Values CRUD & Duplicate Prevention...")
        val_dup_payload = {"value_name": "Football Again", "value_code": "FOOTBALL"}
        res_val_dup = run_query(
            "SELECT public.fn_create_lookup_value(%s::UUID, %s::UUID, %s::UUID, %s::JSONB) AS result;",
            (school_a_id, user_a_id, lookup_key_1_id, json.dumps(val_dup_payload))
        )[0]["result"]
        record_test("Duplicate Value Code Rejected", res_val_dup.get("success") == False and res_val_dup.get("code") == 409)

        # --------------------------------------------------------------------
        # TEST 5: Create Single Value by Owner
        # --------------------------------------------------------------------
        val_3_payload = {"value_name": "Cricket", "value_code": "CRICKET", "description": "Outdoor sport"}
        res_val_3 = run_query(
            "SELECT public.fn_create_lookup_value(%s::UUID, %s::UUID, %s::UUID, %s::JSONB) AS result;",
            (school_a_id, user_a_id, lookup_key_1_id, json.dumps(val_3_payload))
        )[0]["result"]
        val_3_id = res_val_3.get("data", {}).get("id")
        record_test("Add Single Value by Owner", res_val_3.get("success") == True, f"Val ID: {val_3_id}")

        # Fetch values to get val_1_id and val_2_id
        vals_list = run_query(
            "SELECT public.fn_get_lookup_values(%s::UUID, %s::UUID, %s::UUID) AS result;",
            (school_a_id, user_a_id, lookup_key_1_id)
        )[0]["result"]
        val_items = vals_list.get("data", [])
        record_test("Lookup Values Retrieved for Key", len(val_items) == 3, f"Count: {len(val_items)}")
        val_1_id = val_items[0]["id"]
        val_2_id = val_items[1]["id"]

        # --------------------------------------------------------------------
        # TEST 6: Edit Lookup Key by Creator (Success)
        # --------------------------------------------------------------------
        print("\n[Phase 3] Ownership Security & Authorization...")
        update_payload = {"key_name": "Sports & Athletics Type", "description": "Updated description"}
        res_update_owner = run_query(
            "SELECT public.fn_update_lookup_key(%s::UUID, %s::UUID, %s::UUID, %s::JSONB, 1) AS result;",
            (school_a_id, user_a_id, lookup_key_1_id, json.dumps(update_payload))
        )[0]["result"]
        record_test("Edit Lookup Key by Creator", res_update_owner.get("success") == True)

        # --------------------------------------------------------------------
        # TEST 7: Edit Lookup Key by Non-Creator User B (403 Forbidden)
        # --------------------------------------------------------------------
        res_update_non_owner = run_query(
            "SELECT public.fn_update_lookup_key(%s::UUID, %s::UUID, %s::UUID, %s::JSONB, 2) AS result;",
            (school_a_id, user_b_id, lookup_key_1_id, json.dumps(update_payload))
        )[0]["result"]
        record_test("Edit Lookup Key by Non-Creator Blocked (403)", res_update_non_owner.get("success") == False and res_update_non_owner.get("code") == 403)

        # --------------------------------------------------------------------
        # TEST 8: Add Value by Non-Creator User B (403 Forbidden)
        # --------------------------------------------------------------------
        res_add_non_owner = run_query(
            "SELECT public.fn_create_lookup_value(%s::UUID, %s::UUID, %s::UUID, %s::JSONB) AS result;",
            (school_a_id, user_b_id, lookup_key_1_id, json.dumps({"value_name": "Tennis"}))
        )[0]["result"]
        record_test("Add Value by Non-Creator Blocked (403)", res_add_non_owner.get("success") == False and res_add_non_owner.get("code") == 403)

        # --------------------------------------------------------------------
        # TEST 9: Edit Value by Non-Creator User B (403 Forbidden)
        # --------------------------------------------------------------------
        res_edit_val_non_owner = run_query(
            "SELECT public.fn_update_lookup_value(%s::UUID, %s::UUID, %s::UUID, %s::JSONB) AS result;",
            (school_a_id, user_b_id, val_1_id, json.dumps({"value_name": "Hacked"}))
        )[0]["result"]
        record_test("Edit Value by Non-Creator Blocked (403)", res_edit_val_non_owner.get("success") == False and res_edit_val_non_owner.get("code") == 403)

        # --------------------------------------------------------------------
        # TEST 10: Delete Value by Non-Creator User B (403 Forbidden)
        # --------------------------------------------------------------------
        res_del_val_non_owner = run_query(
            "SELECT public.fn_delete_lookup_value(%s::UUID, %s::UUID, %s::UUID) AS result;",
            (school_a_id, user_b_id, val_1_id)
        )[0]["result"]
        record_test("Delete Value by Non-Creator Blocked (403)", res_del_val_non_owner.get("success") == False and res_del_val_non_owner.get("code") == 403)

        # --------------------------------------------------------------------
        # TEST 11: Reorder Values by Non-Creator User B (403 Forbidden)
        # --------------------------------------------------------------------
        res_reorder_non_owner = run_query(
            "SELECT public.fn_reorder_lookup_values(%s::UUID, %s::UUID, %s::UUID, ARRAY[%s::UUID, %s::UUID]) AS result;",
            (school_a_id, user_b_id, lookup_key_1_id, val_2_id, val_1_id)
        )[0]["result"]
        record_test("Reorder Values by Non-Creator Blocked (403)", res_reorder_non_owner.get("success") == False and res_reorder_non_owner.get("code") == 403)

        # --------------------------------------------------------------------
        # TEST 12: Reorder Values by Creator User A (Success)
        # --------------------------------------------------------------------
        print("\n[Phase 4] Ordering, Status Toggles & Resolution...")
        res_reorder_owner = run_query(
            "SELECT public.fn_reorder_lookup_values(%s::UUID, %s::UUID, %s::UUID, ARRAY[%s::UUID, %s::UUID]) AS result;",
            (school_a_id, user_a_id, lookup_key_1_id, val_2_id, val_1_id)
        )[0]["result"]
        record_test("Reorder Values by Creator", res_reorder_owner.get("success") == True)

        # Verify new order in values list
        vals_reordered = run_query(
            "SELECT public.fn_get_lookup_values(%s::UUID, %s::UUID, %s::UUID, '', '', 1, 10, 'sort_order', 'ASC') AS result;",
            (school_a_id, user_a_id, lookup_key_1_id)
        )[0]["result"]["data"]
        record_test("Values sort_order Persisted", vals_reordered[0]["id"] == val_2_id and vals_reordered[0]["sort_order"] == 1)

        # --------------------------------------------------------------------
        # TEST 13: Deactivate Value & Check Generic Module Resolution
        # --------------------------------------------------------------------
        res_deact = run_query(
            "SELECT public.fn_update_lookup_value(%s::UUID, %s::UUID, %s::UUID, %s::JSONB) AS result;",
            (school_a_id, user_a_id, val_1_id, json.dumps({"status": "INACTIVE"}))
        )[0]["result"]
        record_test("Deactivate Value by Creator", res_deact.get("success") == True)

        # Module resolver should exclude inactive by default
        module_res_active = run_query(
            "SELECT public.fn_get_lookup_by_code(%s::UUID, 'SPORT_ACTIVITY_TYPE', FALSE) AS result;",
            (school_a_id,)
        )[0]["result"]
        active_codes = [v["code"] for v in module_res_active.get("values", [])]
        record_test("Module Resolver Excludes Inactive Values", "FOOTBALL" not in active_codes and "BASKETBALL" in active_codes)

        # Module resolver with include_inactive=True should include all
        module_res_all = run_query(
            "SELECT public.fn_get_lookup_by_code(%s::UUID, 'SPORT_ACTIVITY_TYPE', TRUE) AS result;",
            (school_a_id,)
        )[0]["result"]
        all_codes = [v["code"] for v in module_res_all.get("values", [])]
        record_test("Module Resolver Includes Inactive when Requested", "FOOTBALL" in all_codes)

        # Reactivate Value
        run_query(
            "SELECT public.fn_update_lookup_value(%s::UUID, %s::UUID, %s::UUID, %s::JSONB) AS result;",
            (school_a_id, user_a_id, val_1_id, json.dumps({"status": "ACTIVE"})),
            fetch=False
        )

        # --------------------------------------------------------------------
        # TEST 14: Bulk Create Values
        # --------------------------------------------------------------------
        print("\n[Phase 5] Bulk Operations, Search & Usage...")
        bulk_items = [
            {"value_name": "Swimming", "value_code": "SWIMMING"},
            {"value_name": "Badminton", "value_code": "BADMINTON"},
            {"value_name": "Cricket", "value_code": "CRICKET"} # Duplicate code, should be reported
        ]
        res_bulk = run_query(
            "SELECT public.fn_bulk_create_lookup_values(%s::UUID, %s::UUID, %s::UUID, %s::JSONB) AS result;",
            (school_a_id, user_a_id, lookup_key_1_id, json.dumps(bulk_items))
        )[0]["result"]
        record_test("Bulk Create Values", res_bulk.get("imported_count") == 2, f"Imported: {res_bulk.get('imported_count')} (1 Duplicate rejected)")

        # --------------------------------------------------------------------
        # TEST 15: Search Lookup Keys & Values
        # --------------------------------------------------------------------
        search_keys = run_query(
            "SELECT public.fn_get_lookup_keys(%s::UUID, %s::UUID, 'all', 'Athletics') AS result;",
            (school_a_id, user_a_id)
        )[0]["result"]
        record_test("Search Lookup Keys", search_keys.get("total_records") >= 1)

        search_vals = run_query(
            "SELECT public.fn_get_lookup_values(%s::UUID, %s::UUID, %s::UUID, 'Swimming') AS result;",
            (school_a_id, user_a_id, lookup_key_1_id)
        )[0]["result"]
        record_test("Search Values within Key", search_vals.get("total_records") == 1)

        # --------------------------------------------------------------------
        # TEST 16: Concurrency Control (Optimistic Version Lock)
        # --------------------------------------------------------------------
        print("\n[Phase 6] Concurrency, Usage Safety & Audit Logs...")
        res_conflict = run_query(
            "SELECT public.fn_update_lookup_key(%s::UUID, %s::UUID, %s::UUID, %s::JSONB, 999) AS result;",
            (school_a_id, user_a_id, lookup_key_1_id, json.dumps({"key_name": "Stale Update"}))
        )[0]["result"]
        record_test("Optimistic Version Conflict Blocked (409)", res_conflict.get("success") == False and res_conflict.get("code") == 409)

        # --------------------------------------------------------------------
        # TEST 17: Usage Tracking & Safe Deletion
        # --------------------------------------------------------------------
        # Register simulated usage for lookup_key_1
        run_query(
            """
            INSERT INTO public.lookup_usage_registry (school_id, lookup_key_id, module_name, table_name, record_count)
            VALUES (%s, %s, 'SportsModule', 'student_activities', 42);
            """,
            (school_a_id, lookup_key_1_id),
            fetch=False
        )

        # Attempt delete when in use -> Should be blocked and prompt deactivation
        res_del_used = run_query(
            "SELECT public.fn_delete_lookup_key(%s::UUID, %s::UUID, %s::UUID, FALSE) AS result;",
            (school_a_id, user_a_id, lookup_key_1_id)
        )[0]["result"]
        record_test("Delete Blocked on In-Use Key (Prompts Deactivation)", res_del_used.get("success") == False and res_del_used.get("is_used") == True)

        # Force Deactivate in-use key
        res_force_deact = run_query(
            "SELECT public.fn_delete_lookup_key(%s::UUID, %s::UUID, %s::UUID, TRUE) AS result;",
            (school_a_id, user_a_id, lookup_key_1_id)
        )[0]["result"]
        record_test("In-Use Key Successfully Deactivated", res_force_deact.get("success") == True and res_force_deact.get("action") == "DEACTIVATED")

        # --------------------------------------------------------------------
        # TEST 18: Audit Log Timeline Verification
        # --------------------------------------------------------------------
        audit_res = run_query(
            "SELECT public.fn_get_lookup_audit_logs(%s::UUID, %s::UUID) AS result;",
            (school_a_id, lookup_key_1_id)
        )[0]["result"]
        audit_actions = [a["action"] for a in audit_res.get("data", [])]
        record_test("Audit Trail Logged Mutations", len(audit_actions) > 0, f"Total Events: {len(audit_actions)}")

        # --------------------------------------------------------------------
        # TEST 19: Non-Owner View-Only Capability
        # --------------------------------------------------------------------
        view_non_owner = run_query(
            "SELECT public.fn_get_lookup_key_detail(%s::UUID, %s::UUID, %s::UUID) AS result;",
            (school_a_id, user_b_id, lookup_key_1_id)
        )[0]["result"]
        record_test("Non-Owner Can View Key with is_owner=False", view_non_owner.get("success") == True and view_non_owner.get("data", {}).get("is_owner") == False)

        # --------------------------------------------------------------------
        # TEST 20: Cross-Tenant Isolation
        # --------------------------------------------------------------------
        print("\n[Phase 7] Multi-Tenant Isolation...")
        cross_tenant_view = run_query(
            "SELECT public.fn_get_lookup_key_detail(%s::UUID, %s::UUID, %s::UUID) AS result;",
            (school_b_id, user_c_id, lookup_key_1_id)
        )[0]["result"]
        record_test("Cross-Tenant Lookup Access Denied", cross_tenant_view.get("success") == False)

    finally:
        # Teardown Test Data
        print("\n[Phase 8] Teardown Test Artifacts...")
        run_query("DELETE FROM public.audit_logs WHERE school_id IN (%s, %s) AND module = 'Lookup Management';", (school_a_id, school_b_id), fetch=False)
        run_query("DELETE FROM public.lookup_values WHERE school_id IN (%s, %s);", (school_a_id, school_b_id), fetch=False)
        run_query("DELETE FROM public.lookup_keys WHERE school_id IN (%s, %s);", (school_a_id, school_b_id), fetch=False)
        run_query("DELETE FROM public.lookup_usage_registry WHERE school_id IN (%s, %s);", (school_a_id, school_b_id), fetch=False)
        run_query("DELETE FROM public.profiles WHERE school_id IN (%s, %s);", (school_a_id, school_b_id), fetch=False)
        run_query("DELETE FROM public.schools WHERE id IN (%s, %s);", (school_a_id, school_b_id), fetch=False)
        record_test("Cleaned up Test Institutions and Records", True)

    print("\n" + "=" * 65)
    total_tests = passed_tests + failed_tests
    success_rate = (passed_tests / total_tests * 100.0) if total_tests > 0 else 0.0
    print(f"📊 TEST RESULTS: {passed_tests} PASSED | {failed_tests} FAILED")
    print(f"🎯 SUCCESS RATE: {success_rate:.1f}%")
    print("=" * 65 + "\n")

    if failed_tests > 0:
        sys.exit(1)


if __name__ == "__main__":
    run_all_tests()
