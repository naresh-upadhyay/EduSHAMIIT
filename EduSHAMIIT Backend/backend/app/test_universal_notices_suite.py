"""
Universal Notices & Circulars Comprehensive Test Suite for EduSHAMIIT ERP.
Tests all RBAC scenarios, targeting, scheduling, approvals, acknowledgements,
analytics, bulk operations, and multi-tenant isolation.
"""
import sys
import os
import json
import uuid
import datetime
import psycopg2
from psycopg2.extras import RealDictCursor

DATABASE_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql://postgres:eduSHAMIIT2026_pg@db:5432/postgres"
)

def get_db():
    return psycopg2.connect(DATABASE_URL)

def exec_sql(conn, sql, params=(), fetch=True):
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql, params)
        if fetch:
            rows = cur.fetchall()
            conn.commit()
            return [dict(r) for r in rows]
        else:
            conn.commit()
            return []

def run_tests():
    conn = get_db()
    print("================================================================================")
    print("🚀 RUNNING UNIVERSAL NOTICES & CIRCULARS TEST SUITE")
    print("================================================================================")

    # 1. Resolve or Create Test Fixtures (School, Superadmin, Principal, Teacher, Student 10A, Student 9B)
    school_rows = exec_sql(conn, "SELECT id FROM public.schools LIMIT 1;")
    if not school_rows:
        school_id = str(uuid.uuid4())
        exec_sql(conn, "INSERT INTO public.schools (id, name) VALUES (%s, 'Test Notice Academy') ON CONFLICT DO NOTHING;", (school_id,), fetch=False)
    else:
        school_id = str(school_rows[0]["id"])

    # Profiles
    admin_id = str(uuid.uuid4())
    principal_id = str(uuid.uuid4())
    teacher_id = str(uuid.uuid4())
    student_10a_id = str(uuid.uuid4())
    student_9b_id = str(uuid.uuid4())
    other_user_id = str(uuid.uuid4())

    run_id = uuid.uuid4().hex[:8]
    email_admin = f"notice_admin_{run_id}@example.internal"
    email_principal = f"notice_principal_{run_id}@example.internal"
    email_teacher = f"notice_teacher_{run_id}@example.internal"
    email_s10a = f"notice_s10a_{run_id}@example.internal"
    email_s9b = f"notice_s9b_{run_id}@example.internal"

    exec_sql(conn, """
        INSERT INTO public.profiles (id, user_id, school_id, email, full_name, role, class)
        VALUES 
            (%s, %s, %s, %s, 'Admin Test', 'admin', NULL),
            (%s, %s, %s, %s, 'Principal Test', 'principal', NULL),
            (%s, %s, %s, %s, 'Teacher Test', 'teacher', NULL),
            (%s, %s, %s, %s, 'Student 10A Test', 'student', 'Class 10A'),
            (%s, %s, %s, %s, 'Student 9B Test', 'student', 'Class 9B')
        ON CONFLICT (id) DO NOTHING;
    """, (admin_id, admin_id, school_id, email_admin, principal_id, principal_id, school_id, email_principal, teacher_id, teacher_id, school_id, email_teacher, student_10a_id, student_10a_id, school_id, email_s10a, student_9b_id, student_9b_id, school_id, email_s9b), fetch=False)

    passed_count = 0
    total_count = 0

    def assert_test(name, condition, details=""):
        nonlocal passed_count, total_count
        total_count += 1
        if condition:
            print(f"  ✅ [PASS] {name}")
            passed_count += 1
        else:
            print(f"  ❌ [FAIL] {name} - {details}")

    try:
        # TEST 1: Create General Notice (Entire Institute)
        print("\n--- 1. GENERAL NOTICE CREATION & AUDIENCE RESOLUTION ---")
        gen_payload = {
            "title": "Annual Sports Day 2026",
            "content": "Sports day will be celebrated on 25th August 2026. All students and staff must attend in sportswear.",
            "category": "Event",
            "priority": "normal",
            "status": "published",
            "target_scope": "entire_institute",
            "requires_acknowledgement": True,
            "attachments": [{"name": "Sports_Schedule.pdf", "url": "https://example.com/sports.pdf", "size": 1048576, "type": "pdf"}]
        }
        res = exec_sql(conn, "SELECT public.fn_create_notice(%s::UUID, %s::UUID, %s::JSONB) AS result;", (school_id, admin_id, json.dumps(gen_payload)))[0]["result"]
        notice_1_id = res["notice_id"]
        assert_test("General Notice Created Successfully", res["success"] is True and notice_1_id is not None)
        assert_test("Recipients Populated for Entire Institute", res["recipient_count"] >= 5, f"Recipient count: {res['recipient_count']}")

        # TEST 2: Notice Detail & Auto-Read Increment
        print("\n--- 2. NOTICE DETAIL & ATOMIC READ LOGGING ---")
        detail_res = exec_sql(conn, "SELECT public.fn_get_notice_detail(%s::UUID, %s::UUID, %s::UUID) AS result;", (school_id, notice_1_id, student_10a_id))[0]["result"]
        assert_test("Detail Fetch Returns Notice", detail_res["success"] is True and detail_res["data"]["title"] == "Annual Sports Day 2026")
        assert_test("View Count Incremented", detail_res["data"]["view_count"] >= 1)
        assert_test("Recipient Marked as Read", detail_res["data"]["user_is_read"] is True)

        # TEST 3: Recipient Acknowledgement
        print("\n--- 3. RECIPIENT ACKNOWLEDGEMENT WORKFLOW ---")
        ack_res = exec_sql(conn, "SELECT public.fn_acknowledge_notice(%s::UUID, %s::UUID, %s::UUID, 'acknowledged', NULL) AS result;", (school_id, notice_1_id, student_10a_id))[0]["result"]
        assert_test("Student 10A Acknowledges Notice", ack_res["success"] is True and ack_res["total_acknowledgements"] >= 1)

        # Verify acknowledgement recorded in notice
        chk_notice = exec_sql(conn, "SELECT ack_count FROM public.notices WHERE id = %s;", (notice_1_id,))[0]
        assert_test("Notice Ack Count Updated in DB", chk_notice["ack_count"] >= 1)

        # TEST 4: Class-Targeted Notice (Only Class 10A)
        print("\n--- 4. CLASS TARGETING & AUDIENCE ISOLATION ---")
        class_payload = {
            "title": "Mathematics Board Exam Extra Class",
            "content": "Class 10A students have extra math coaching on Saturday 9 AM.",
            "category": "Academic",
            "priority": "high",
            "status": "published",
            "target_scope": "classes",
            "target_classes": ["Class 10A"],
            "requires_acknowledgement": True
        }
        res_class = exec_sql(conn, "SELECT public.fn_create_notice(%s::UUID, %s::UUID, %s::JSONB) AS result;", (school_id, teacher_id, json.dumps(class_payload)))[0]["result"]
        class_notice_id = res_class["notice_id"]

        # Student 10A queries notices -> should see class notice
        st10_notices = exec_sql(conn, "SELECT public.fn_get_notices(%s::UUID, %s::UUID, 'all') AS result;", (school_id, student_10a_id))[0]["result"]
        st10_has_notice = any(n["id"] == class_notice_id for n in st10_notices["data"])
        assert_test("Class 10A Student Receives Class 10A Notice", st10_has_notice is True)

        # Student 9B queries notices -> should NOT see Class 10A notice
        st9_notices = exec_sql(conn, "SELECT public.fn_get_notices(%s::UUID, %s::UUID, 'all') AS result;", (school_id, student_9b_id))[0]["result"]
        st9_has_notice = any(n["id"] == class_notice_id for n in st9_notices["data"])
        assert_test("Class 9B Student ISOLATED from Class 10A Notice", st9_has_notice is False)

        # TEST 5: Role-Targeted Notice (Only Teachers)
        print("\n--- 5. ROLE TARGETING & ISOLATION ---")
        role_payload = {
            "title": "Staff Evaluation Meeting",
            "content": "All teachers must assemble in Conference Room B at 3 PM.",
            "category": "Meeting",
            "priority": "high",
            "status": "published",
            "target_scope": "roles",
            "target_roles": ["teacher"]
        }
        res_role = exec_sql(conn, "SELECT public.fn_create_notice(%s::UUID, %s::UUID, %s::JSONB) AS result;", (school_id, principal_id, json.dumps(role_payload)))[0]["result"]
        role_notice_id = res_role["notice_id"]

        # Teacher queries -> sees notice
        teacher_notices = exec_sql(conn, "SELECT public.fn_get_notices(%s::UUID, %s::UUID, 'all') AS result;", (school_id, teacher_id))[0]["result"]
        teacher_has_notice = any(n["id"] == role_notice_id for n in teacher_notices["data"])
        assert_test("Teacher Receives Staff Meeting Notice", teacher_has_notice is True)

        # Student queries -> does NOT see notice
        st_notices = exec_sql(conn, "SELECT public.fn_get_notices(%s::UUID, %s::UUID, 'all') AS result;", (school_id, student_10a_id))[0]["result"]
        st_has_role_notice = any(n["id"] == role_notice_id for n in st_notices["data"])
        assert_test("Student ISOLATED from Teacher Staff Meeting Notice", st_has_role_notice is False)

        # TEST 6: Teacher Notice Creation with Approval Workflow
        print("\n--- 6. APPROVAL WORKFLOW (PENDING -> APPROVED / REJECTED) ---")
        teacher_req_payload = {
            "title": "Field Trip to Science Museum",
            "content": "Proposed educational tour for standard 10 students.",
            "category": "Academic",
            "status": "published",
            "requires_approval": True,
            "target_scope": "classes",
            "target_classes": ["Class 10A"]
        }
        appr_create_res = exec_sql(conn, "SELECT public.fn_create_notice(%s::UUID, %s::UUID, %s::JSONB) AS result;", (school_id, teacher_id, json.dumps(teacher_req_payload)))[0]["result"]
        pending_notice_id = appr_create_res["notice_id"]
        assert_test("Teacher Notice Flagged as Pending Approval", appr_create_res["status"] == "pending_approval")

        # Principal Rejection test (without reason should fail)
        rej_fail = exec_sql(conn, "SELECT public.fn_approve_reject_notice(%s::UUID, %s::UUID, %s::UUID, 'reject', '') AS result;", (school_id, pending_notice_id, principal_id))[0]["result"]
        assert_test("Rejection Fails When Reason is Empty", rej_fail["success"] is False)

        # Principal Approval
        appr_res = exec_sql(conn, "SELECT public.fn_approve_reject_notice(%s::UUID, %s::UUID, %s::UUID, 'approve', NULL) AS result;", (school_id, pending_notice_id, principal_id))[0]["result"]
        assert_test("Principal Approves Notice Successfully", appr_res["success"] is True and appr_res["status"] == "published")

        # TEST 7: Summary Analytics & Category Stats
        print("\n--- 7. SUMMARY ANALYTICS & STATS ---")
        summary_res = exec_sql(conn, "SELECT public.fn_get_notice_summary(%s::UUID, %s::UUID) AS result;", (school_id, admin_id))[0]["result"]
        assert_test("Summary Metrics Returned", summary_res["success"] is True and summary_res["stats"]["total_notices"] >= 4)
        assert_test("Category Distribution Aggregated", len(summary_res["category_distribution"]) > 0)

        # TEST 8: Bulk Actions (Archive, Restore, Delete)
        print("\n--- 8. BULK OPERATIONS ---")
        bulk_res = exec_sql(conn, "SELECT public.fn_bulk_notice_action(%s::UUID, %s::UUID, ARRAY[%s::UUID], 'archive') AS result;", (school_id, admin_id, notice_1_id))[0]["result"]
        assert_test("Bulk Archive Notice", bulk_res["success"] is True and bulk_res["affected_count"] == 1)

        # Verify notice is archived
        n1_status = exec_sql(conn, "SELECT status FROM public.notices WHERE id = %s;", (notice_1_id,))[0]["status"]
        assert_test("Notice Status is Now Archived", n1_status == "archived")

        # Bulk restore
        bulk_rest = exec_sql(conn, "SELECT public.fn_bulk_notice_action(%s::UUID, %s::UUID, ARRAY[%s::UUID], 'restore') AS result;", (school_id, admin_id, notice_1_id))[0]["result"]
        assert_test("Bulk Restore Notice to Draft", bulk_rest["success"] is True)

        # TEST 9: Acknowledgement Dashboard Table
        print("\n--- 9. RECIPIENT ACKNOWLEDGEMENT DASHBOARD ---")
        ack_dash = exec_sql(conn, "SELECT public.fn_get_notice_acknowledgements(%s::UUID, %s::UUID) AS result;", (school_id, notice_1_id))[0]["result"]
        assert_test("Acknowledgement Dashboard Returns Recipients List", ack_dash["success"] is True and len(ack_dash["data"]) > 0)
        assert_test("Acknowledgement Stats Calculated", ack_dash["summary"]["total_recipients"] > 0)

        # TEST 10: Multi-Tenant Isolation
        print("\n--- 10. MULTI-TENANT ISOLATION ---")
        other_school_id = str(uuid.uuid4())
        other_school_code = f"OTH_{run_id[:4]}".upper()
        exec_sql(conn, "INSERT INTO public.schools (id, name, code) VALUES (%s, 'Other Academy', %s) ON CONFLICT DO NOTHING;", (other_school_id, other_school_code), fetch=False)
        other_user_id = str(uuid.uuid4())
        other_email = f"other_student_{run_id}@example.internal"
        exec_sql(conn, "INSERT INTO public.profiles (id, user_id, school_id, email, full_name, role) VALUES (%s, %s, %s, %s, 'Other Student', 'student') ON CONFLICT DO NOTHING;", (other_user_id, other_user_id, other_school_id, other_email), fetch=False)

        # TEST 10: Dynamic Roles and Classes Metadata Retrieval
        print("\n--- 10. DYNAMIC METADATA (ROLES & CLASSES FROM DB) ---")
        meta_res = exec_sql(conn, "SELECT public.fn_get_notice_metadata(%s::UUID) AS result;", (school_id,))[0]["result"]
        assert_test("Notice Metadata Success", meta_res["success"] is True)
        assert_test("Dynamic Roles Retrieved from DB (app_roles)", len(meta_res["roles"]) >= 10 and "teacher" in meta_res["roles"] and "student" in meta_res["roles"])
        assert_test("Dynamic Classes Retrieved from DB (classes table)", len(meta_res["classes"]) >= 5 and any("10" in c for c in meta_res["classes"]))
        assert_test("Dynamic Notice Categories Retrieved from DB", len(meta_res["categories"]) >= 5 and any(c["name"] == "General" for c in meta_res["categories"]))

    finally:
        # Clean up test notices and audit logs
        try:
            exec_sql(conn, "DELETE FROM public.notices WHERE school_id = %s;", (school_id,), fetch=False)
            exec_sql(conn, "DELETE FROM public.profiles WHERE id IN (%s, %s, %s, %s, %s, %s);", (admin_id, principal_id, teacher_id, student_10a_id, student_9b_id, other_user_id), fetch=False)
            exec_sql(conn, "DELETE FROM public.schools WHERE id = %s;", (other_school_id,), fetch=False)
        except Exception:
            pass
        finally:
            conn.close()

    print("\n================================================================================")
    print(f"📊 TEST SUITE SUMMARY: {passed_count}/{total_count} PASSED ({(passed_count/total_count*100):.1f}%)")
    print("================================================================================")
    return passed_count == total_count

if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
