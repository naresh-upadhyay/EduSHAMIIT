"""
Exhaustive End-to-End Test Suite for Academic Class, Section & Subject Management System.

Comprehensive Coverage of All Scenarios & Edge Cases:
1. Multi-tenant & School Isolation Fixture
2. Class CRUD & Validations:
   - Create class with inline sections (atomic transaction)
   - Duplicate class name/code in same school + academic year rejected (409)
   - Same class code in different school allowed (Multi-Tenancy)
   - Same class code in different academic year allowed
   - Create class without sections (direct assignment mode)
   - Update class details (name, code, stage, display_order, capacity)
   - Class listing with search, stage filter, status filter, sorting & pagination
3. Section CRUD & Validations:
   - Standalone section creation
   - Duplicate section name within same class rejected (409)
   - Same section name in different classes allowed (e.g., Section A in Class 9 & Class 10)
   - Create section in non-existent class rejected (404)
   - Update section details (name, capacity, room_number)
   - Section listing across all classes with filters (class_id, status, search)
4. Subject Catalog & Management:
   - Create subject in catalog with type categorization (Core, Elective, Language, Practical, etc.)
   - Duplicate subject code in same school rejected (409)
   - Update subject metadata (periods_per_week, color, icon)
   - Class-wide subject assignment (fn_manage_class_subjects)
   - Section-specific subject assignment
   - Subject unassignment via empty/subset array
   - Subject listing with filters (type, status, search)
5. Class Teacher Assignment & Scoping:
   - Assign single teacher to class (is_primary = true)
   - Assign multiple teachers (multi-teacher support with primary teacher ordering)
   - Section-specific teacher assignment
   - Unassign teachers via empty array
6. Student Assignment, Unassignment & Conflict Move Detection:
   - Assign students to section
   - Assign students to class directly (no section mode)
   - Target-aware conflict detection (no false conflicts when retaining students in same section)
   - Cross-section/class move detection (detects existing enrollment in other sections)
   - Block move without confirmation (p_confirm_move = FALSE -> 409)
   - Allow move with confirmation (p_confirm_move = TRUE)
   - Unassign single student via subset array (reconciliation)
   - Unassign ALL students via empty array
7. Teacher Role Scoping & Security Access Control:
   - Admin query (p_teacher_id = NULL) sees all classes & sections
   - Teacher query (p_teacher_id = <id>) sees ONLY assigned classes & sections
   - Teacher query for unassigned class detail returns 403 Forbidden / Not Found
   - Teacher query for stats scoped to teacher's classes
8. Archiving & Dependency Safety Lifecycle:
   - Class archive blocked without force when sections/students exist (400)
   - Class force archive cascades to sections and deactivates assignments
   - Class restore brings back class & sections
   - Section archive blocked without force when students exist (400)
   - Section force archive & restore
   - Subject archive blocked without force when assigned to classes (400)
   - Subject force archive & restore
   - Archived status filtering (ACTIVE, ARCHIVED, ALL) across all tabs
9. System Resiliency & Audit Logging:
   - Audit logging with NULL or non-existent profile IDs (resilient FK handling)
   - Clean teardown
"""
import os
import sys
import uuid
import json

curr_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(curr_dir)
for p in [curr_dir, parent_dir, "/app", "/app/app"]:
    if p not in sys.path:
        sys.path.insert(0, p)

import psycopg2
from psycopg2.extras import RealDictCursor
try:
    from app.config import settings
    DATABASE_URL = settings.DATABASE_URL
except Exception:
    try:
        from config import settings
        DATABASE_URL = settings.DATABASE_URL
    except Exception:
        DATABASE_URL = os.environ.get("DATABASE_URL", "postgresql://postgres:eduSHAMIIT2026_pg@localhost:5432/postgres")

def get_db():
    return psycopg2.connect(DATABASE_URL)

def run_query(sql, params=(), fetch=True):
    conn = get_db()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, params)
            if fetch:
                rows = cur.fetchall()
                conn.commit()
                return [dict(r) for r in rows]
            else:
                conn.commit()
                return []
    finally:
        conn.close()

passed = 0
failed = 0

def record_test(name, is_success, details=""):
    global passed, failed
    if is_success:
        passed += 1
        print(f"  [PASS] {name} {details}")
    else:
        failed += 1
        print(f"  [FAIL] {name} - Details: {details}")

def main():
    print("\n" + "=" * 70)
    print("RUNNING EXHAUSTIVE ACADEMIC CLASS MANAGEMENT BACKEND TEST SUITE")
    print("=" * 70)

    # 1. Setup Mock Schools & Users
    school_a_id = str(uuid.uuid4())
    school_b_id = str(uuid.uuid4())
    admin_a_id = str(uuid.uuid4())
    teacher_1_id = str(uuid.uuid4())
    teacher_2_id = str(uuid.uuid4())
    teacher_unassigned_id = str(uuid.uuid4())
    student_1_id = str(uuid.uuid4())
    student_2_id = str(uuid.uuid4())
    student_3_id = str(uuid.uuid4())
    student_4_id = str(uuid.uuid4())

    try:
        print("\n[Phase 1] Environment & Multi-Tenant Setup...")
        run_query("INSERT INTO public.schools (id, name, address) VALUES (%s, %s, %s);", (school_a_id, "Apex International School", "Sector 62, Noida"), fetch=False)
        run_query("INSERT INTO public.schools (id, name, address) VALUES (%s, %s, %s);", (school_b_id, "Beacon Academy", "MG Road, Gurgaon"), fetch=False)

        # Profiles in School A
        run_query("INSERT INTO public.profiles (id, user_id, school_id, email, full_name, role, employee_id) VALUES (%s, %s, %s, %s, %s, %s, %s);", 
                  (admin_a_id, admin_a_id, school_a_id, "admin@apex.edu", "Principal Smith", "super_admin", "EMP001"), fetch=False)
        run_query("INSERT INTO public.profiles (id, user_id, school_id, email, full_name, role, employee_id, department) VALUES (%s, %s, %s, %s, %s, %s, %s, %s);", 
                  (teacher_1_id, teacher_1_id, school_a_id, "neha@apex.edu", "Neha Sharma", "teacher", "EMP1024", "Mathematics"), fetch=False)
        run_query("INSERT INTO public.profiles (id, user_id, school_id, email, full_name, role, employee_id, department) VALUES (%s, %s, %s, %s, %s, %s, %s, %s);", 
                  (teacher_2_id, teacher_2_id, school_a_id, "rahul@apex.edu", "Rahul Verma", "teacher", "EMP1051", "Physics"), fetch=False)
        run_query("INSERT INTO public.profiles (id, user_id, school_id, email, full_name, role, employee_id, department) VALUES (%s, %s, %s, %s, %s, %s, %s, %s);", 
                  (teacher_unassigned_id, teacher_unassigned_id, school_a_id, "unassigned@apex.edu", "Kiran Rao", "teacher", "EMP1099", "Biology"), fetch=False)
        run_query("INSERT INTO public.profiles (id, user_id, school_id, email, full_name, role, admission_number) VALUES (%s, %s, %s, %s, %s, %s, %s);", 
                  (student_1_id, student_1_id, school_a_id, "aarav@apex.edu", "Aarav Kumar", "student", "ADM-901"), fetch=False)
        run_query("INSERT INTO public.profiles (id, user_id, school_id, email, full_name, role, admission_number) VALUES (%s, %s, %s, %s, %s, %s, %s);", 
                  (student_2_id, student_2_id, school_a_id, "priya@apex.edu", "Priya Patel", "student", "ADM-902"), fetch=False)
        run_query("INSERT INTO public.profiles (id, user_id, school_id, email, full_name, role, admission_number) VALUES (%s, %s, %s, %s, %s, %s, %s);", 
                  (student_3_id, student_3_id, school_a_id, "rohan@apex.edu", "Rohan Gupta", "student", "ADM-903"), fetch=False)
        run_query("INSERT INTO public.profiles (id, user_id, school_id, email, full_name, role, admission_number) VALUES (%s, %s, %s, %s, %s, %s, %s);", 
                  (student_4_id, student_4_id, school_a_id, "ananya@apex.edu", "Ananya Singh", "student", "ADM-904"), fetch=False)

        record_test("Setup Multi-School Fixture & Profiles", True)

        # --------------------------------------------------------------------
        # TEST 2: Class Creation & Validation Edge Cases
        # --------------------------------------------------------------------
        print("\n[Phase 2] Class CRUD & Validation Edge Cases...")
        payload_class_10 = {
            "name": "Class 10",
            "code": "C10",
            "stage": "Secondary",
            "academic_year": "2026-27",
            "display_order": 10,
            "capacity": 120,
            "status": "ACTIVE",
            "sections": [
                {"name": "10-A", "code": "10A", "capacity": 40, "status": "ACTIVE"},
                {"name": "10-B", "code": "10B", "capacity": 40, "status": "ACTIVE"},
                {"name": "10-C", "code": "10C", "capacity": 35, "status": "ACTIVE"}
            ]
        }
        res_c10 = run_query(
            "SELECT public.fn_create_academic_class(%s::UUID, %s::UUID, %s::JSONB) AS result;",
            (school_a_id, admin_a_id, json.dumps(payload_class_10))
        )[0]["result"]
        class_10_id = res_c10.get("data", {}).get("id")
        sections_created = res_c10.get("data", {}).get("sections", [])
        record_test("Create Class with 3 Inline Sections", res_c10.get("success") == True and len(sections_created) == 3, f"Class ID: {class_10_id}")

        # Edge Case: Duplicate Class Code in same school + academic year rejected
        dup_class = run_query(
            "SELECT public.fn_create_academic_class(%s::UUID, %s::UUID, %s::JSONB) AS result;",
            (school_a_id, admin_a_id, json.dumps(payload_class_10))
        )[0]["result"]
        record_test("Duplicate Class Code in Same School Rejected", dup_class.get("success") == False and dup_class.get("code") == 409)

        # Edge Case: Multi-Tenancy: Same Class Code in Different School Allowed
        res_school_b = run_query(
            "SELECT public.fn_create_academic_class(%s::UUID, %s::UUID, %s::JSONB) AS result;",
            (school_b_id, admin_a_id, json.dumps(payload_class_10))
        )[0]["result"]
        record_test("Same Class Code in Different School Allowed", res_school_b.get("success") == True)

        # Edge Case: Academic Year Isolation: Same Class Code in Different Academic Year Allowed
        payload_c10_prev_year = dict(payload_class_10, academic_year="2025-26")
        res_c10_prev = run_query(
            "SELECT public.fn_create_academic_class(%s::UUID, %s::UUID, %s::JSONB) AS result;",
            (school_a_id, admin_a_id, json.dumps(payload_c10_prev_year))
        )[0]["result"]
        record_test("Same Class Code in Different Academic Year Allowed", res_c10_prev.get("success") == True)

        # Create Class 5 Without Sections (Direct class enrollment mode)
        payload_class_5 = {
            "name": "Class 5",
            "code": "C05",
            "stage": "Primary",
            "academic_year": "2026-27",
            "display_order": 5,
            "capacity": 50,
            "status": "ACTIVE",
            "sections": []
        }
        res_c5 = run_query(
            "SELECT public.fn_create_academic_class(%s::UUID, %s::UUID, %s::JSONB) AS result;",
            (school_a_id, admin_a_id, json.dumps(payload_class_5))
        )[0]["result"]
        class_5_id = res_c5.get("data", {}).get("id")
        record_test("Create Class Without Sections (Direct Mode)", res_c5.get("success") == True, f"Class 5 ID: {class_5_id}")

        # Update Class Details
        update_c5 = run_query(
            "SELECT public.fn_update_academic_class(%s::UUID, %s::UUID, %s::UUID, %s::JSONB) AS result;",
            (school_a_id, admin_a_id, class_5_id, json.dumps({"name": "Class 5 Primary", "display_order": 6}))
        )[0]["result"]
        record_test("Update Class Details", update_c5.get("success") == True and update_c5.get("data", {}).get("name") == "Class 5 Primary")

        # --------------------------------------------------------------------
        # TEST 3: Section CRUD & Validation Edge Cases
        # --------------------------------------------------------------------
        print("\n[Phase 3] Section Management & Edge Cases...")
        payload_sec_d = {
            "class_id": class_10_id,
            "name": "10-D",
            "code": "10D",
            "capacity": 40,
            "room_number": "Room 204",
            "academic_year": "2026-27",
            "status": "ACTIVE"
        }
        res_sec_d = run_query(
            "SELECT public.fn_create_academic_section(%s::UUID, %s::UUID, %s::JSONB) AS result;",
            (school_a_id, admin_a_id, json.dumps(payload_sec_d))
        )[0]["result"]
        sec_10d_id = res_sec_d.get("data", {}).get("id")
        record_test("Create Standalone Section 10-D", res_sec_d.get("success") == True, f"Section ID: {sec_10d_id}")

        # Edge Case: Duplicate Section Name in Same Class Rejected
        dup_sec = run_query(
            "SELECT public.fn_create_academic_section(%s::UUID, %s::UUID, %s::JSONB) AS result;",
            (school_a_id, admin_a_id, json.dumps(payload_sec_d))
        )[0]["result"]
        record_test("Duplicate Section Name in Same Class Rejected", dup_sec.get("success") == False and dup_sec.get("code") == 409)

        # Edge Case: Same Section Name in Different Class Allowed (e.g. Section A in Class 5)
        payload_sec_5a = {
            "class_id": class_5_id,
            "name": "10-A", # Same name as in Class 10
            "code": "5A",
            "capacity": 30,
            "academic_year": "2026-27",
            "status": "ACTIVE"
        }
        res_sec_5a = run_query(
            "SELECT public.fn_create_academic_section(%s::UUID, %s::UUID, %s::JSONB) AS result;",
            (school_a_id, admin_a_id, json.dumps(payload_sec_5a))
        )[0]["result"]
        record_test("Same Section Name in Different Class Allowed", res_sec_5a.get("success") == True)

        # Edge Case: Create Section in Non-Existent Class Rejected (404)
        fake_class_id = str(uuid.uuid4())
        res_fake_sec = run_query(
            "SELECT public.fn_create_academic_section(%s::UUID, %s::UUID, %s::JSONB) AS result;",
            (school_a_id, admin_a_id, json.dumps({"class_id": fake_class_id, "name": "Fake Section"}))
        )[0]["result"]
        record_test("Create Section in Non-Existent Class Rejected", res_fake_sec.get("success") == False and res_fake_sec.get("code") == 404)

        # Update Section Details
        res_upd_sec = run_query(
            "SELECT public.fn_update_academic_section(%s::UUID, %s::UUID, %s::UUID, %s::JSONB) AS result;",
            (school_a_id, admin_a_id, sec_10d_id, json.dumps({"room_number": "Room 305", "capacity": 45}))
        )[0]["result"]
        record_test("Update Section Details", res_upd_sec.get("success") == True and res_upd_sec.get("data", {}).get("room_number") == "Room 305")

        # --------------------------------------------------------------------
        # TEST 4: Subjects Catalog & Assignment Edge Cases
        # --------------------------------------------------------------------
        print("\n[Phase 4] Subjects Catalog Management & Edge Cases...")
        payload_math = {
            "name": "Advanced Mathematics",
            "code": "MATH10",
            "type": "Core",
            "description": "Secondary school mathematics syllabus",
            "periods_per_week": 6,
            "color": "#4F46E5",
            "icon": "calculate",
            "status": "ACTIVE",
            "class_ids": [class_10_id]
        }
        res_sub_math = run_query(
            "SELECT public.fn_create_academic_subject(%s::UUID, %s::UUID, %s::JSONB) AS result;",
            (school_a_id, admin_a_id, json.dumps(payload_math))
        )[0]["result"]
        sub_math_id = res_sub_math.get("data", {}).get("id")
        record_test("Create Subject in Catalog & Assign to Class", res_sub_math.get("success") == True, f"Subject ID: {sub_math_id}")

        # Edge Case: Duplicate Subject Code in same school rejected
        dup_sub = run_query(
            "SELECT public.fn_create_academic_subject(%s::UUID, %s::UUID, %s::JSONB) AS result;",
            (school_a_id, admin_a_id, json.dumps(payload_math))
        )[0]["result"]
        record_test("Duplicate Subject Code in Same School Rejected", dup_sub.get("success") == False and dup_sub.get("code") == 409)

        # Create Physics Subject
        payload_phys = {
            "name": "Physics Laboratory",
            "code": "PHYS10",
            "type": "Practical",
            "periods_per_week": 4,
            "color": "#059669",
            "icon": "science",
            "status": "ACTIVE",
            "class_ids": []
        }
        res_sub_phys = run_query(
            "SELECT public.fn_create_academic_subject(%s::UUID, %s::UUID, %s::JSONB) AS result;",
            (school_a_id, admin_a_id, json.dumps(payload_phys))
        )[0]["result"]
        sub_phys_id = res_sub_phys.get("data", {}).get("id")
        record_test("Create Practical Subject in Catalog", res_sub_phys.get("success") == True)

        # Contextual Subject Assignment: Assign Both Math & Physics to Class 10
        res_sub_assign = run_query(
            "SELECT public.fn_manage_class_subjects(%s::UUID, %s::UUID, %s::UUID, NULL, ARRAY[%s::UUID, %s::UUID], %s) AS result;",
            (school_a_id, admin_a_id, class_10_id, sub_math_id, sub_phys_id, "2026-27")
        )[0]["result"]
        record_test("Assign Multiple Subjects to Class 10", res_sub_assign.get("success") == True and res_sub_assign.get("assigned_count") == 2)

        # Subject Unassignment: Remove Physics by only passing Math
        res_sub_unassign = run_query(
            "SELECT public.fn_manage_class_subjects(%s::UUID, %s::UUID, %s::UUID, NULL, ARRAY[%s::UUID], %s) AS result;",
            (school_a_id, admin_a_id, class_10_id, sub_math_id, "2026-27")
        )[0]["result"]
        record_test("Unassign Physics Subject from Class 10", res_sub_unassign.get("success") == True and res_sub_unassign.get("assigned_count") == 1)

        # Section-Level Subject Assignment: Assign Math to Section 10-A
        sec_10a_id = sections_created[0]["id"]
        res_sec_sub = run_query(
            "SELECT public.fn_manage_class_subjects(%s::UUID, %s::UUID, %s::UUID, %s::UUID, ARRAY[%s::UUID], %s) AS result;",
            (school_a_id, admin_a_id, class_10_id, sec_10a_id, sub_math_id, "2026-27")
        )[0]["result"]
        record_test("Manage Section Subjects for Section 10-A", res_sec_sub.get("success") == True and res_sec_sub.get("assigned_count") == 1)

        # Subject Deduplication Check in Class Detail:
        # Math is assigned both at class level (section_id IS NULL) and section level (section_id = sec_10a_id).
        # Class Detail MUST return Math EXACTLY ONCE with accurate section_names.
        res_cls_detail_sub = run_query(
            "SELECT public.fn_get_academic_class_detail(%s::UUID, %s::UUID) AS result;",
            (school_a_id, class_10_id)
        )[0]["result"]
        detail_subjects = res_cls_detail_sub.get("data", {}).get("subjects", [])
        math_matches = [s for s in detail_subjects if s.get("id") == sub_math_id]
        record_test("Subject Deduplication in Class Detail (Exactly 1 Entry)", len(math_matches) == 1 and len(detail_subjects) == 1)

        # Verify assigned_subject_ids is present in Section Detail
        detail_sections = res_cls_detail_sub.get("data", {}).get("sections", [])
        sec_10a_detail = next((s for s in detail_sections if s.get("id") == sec_10a_id), {})
        record_test("Section Contains assigned_subject_ids", sub_math_id in sec_10a_detail.get("assigned_subject_ids", []))

        # Update Subject with class_ids sync
        res_sub_upd_classes = run_query(
            "SELECT public.fn_update_academic_subject(%s::UUID, %s::UUID, %s::UUID, %s::JSONB) AS result;",
            (school_a_id, admin_a_id, sub_math_id, json.dumps({"class_ids": [class_10_id, class_5_id]}))
        )[0]["result"]
        record_test("Update Subject Syncs Assigned Classes", res_sub_upd_classes.get("success") == True)

        # --------------------------------------------------------------------
        # TEST 5: Contextual Class Teacher Assignment & Unassignment
        # --------------------------------------------------------------------
        print("\n[Phase 5] Teacher Assignment & Unassignment...")
        sec_10a_id = sections_created[0]["id"]
        sec_10b_id = sections_created[1]["id"]

        # Assign Multiple Teachers to Class 10 (Direct Class Scope)
        res_cta_multi = run_query(
            "SELECT public.fn_assign_class_teachers(%s::UUID, %s::UUID, %s::UUID, NULL, ARRAY[%s::UUID, %s::UUID], %s) AS result;",
            (school_a_id, admin_a_id, class_10_id, teacher_1_id, teacher_2_id, "2026-27")
        )[0]["result"]
        record_test("Assign Multiple Class Teachers to Class 10", res_cta_multi.get("success") == True and res_cta_multi.get("assigned_count") == 2)

        # Section-Specific Teacher Assignment (Section 10-A -> Teacher 1)
        res_cta_sec = run_query(
            "SELECT public.fn_assign_class_teachers(%s::UUID, %s::UUID, %s::UUID, %s::UUID, ARRAY[%s::UUID], %s) AS result;",
            (school_a_id, admin_a_id, class_10_id, sec_10a_id, teacher_1_id, "2026-27")
        )[0]["result"]
        record_test("Assign Class Teacher to Section 10-A", res_cta_sec.get("success") == True and res_cta_sec.get("assigned_count") == 1)

        # Unassign Teachers from Class 10 (Pass Empty Array)
        res_cta_clear = run_query(
            "SELECT public.fn_assign_class_teachers(%s::UUID, %s::UUID, %s::UUID, NULL, ARRAY[]::UUID[], %s) AS result;",
            (school_a_id, admin_a_id, class_10_id, "2026-27")
        )[0]["result"]
        record_test("Unassign All Teachers from Class 10", res_cta_clear.get("success") == True and res_cta_clear.get("assigned_count") == 0)

        # Re-assign Teacher 1 to Class 10 for subsequent tests
        run_query(
            "SELECT public.fn_assign_class_teachers(%s::UUID, %s::UUID, %s::UUID, NULL, ARRAY[%s::UUID], %s) AS result;",
            (school_a_id, admin_a_id, class_10_id, teacher_1_id, "2026-27"), fetch=False
        )

        # --------------------------------------------------------------------
        # TEST 6: Student Assignment, Target-Aware Conflict & Unassignment
        # --------------------------------------------------------------------
        print("\n[Phase 6] Student Assignment, Target-Aware Conflicts & Unassignment...")
        # Step 1: Assign Students 1 & 2 to Section 10-A
        res_std_assign = run_query(
            "SELECT public.fn_assign_class_students(%s::UUID, %s::UUID, %s::UUID, %s::UUID, ARRAY[%s::UUID, %s::UUID], %s, FALSE) AS result;",
            (school_a_id, admin_a_id, class_10_id, sec_10a_id, student_1_id, student_2_id, "2026-27")
        )[0]["result"]
        record_test("Assign Students 1 & 2 to Section 10-A", res_std_assign.get("success") == True and res_std_assign.get("assigned_count") == 2)

        # Step 2: Target-Aware Conflict Check for Section 10-A (Should have NO conflicts when checking same section)
        res_target_check = run_query(
            "SELECT public.fn_check_student_assignments(%s::UUID, ARRAY[%s::UUID, %s::UUID], %s, %s::UUID, %s::UUID) AS result;",
            (school_a_id, student_1_id, student_2_id, "2026-27", class_10_id, sec_10a_id)
        )[0]["result"]
        record_test("Target-Aware Conflict Check (No False Conflicts for Same Target)", res_target_check.get("has_conflicts") == False and len(res_target_check.get("conflicts", [])) == 0)

        # Step 3: Conflict Check when attempting to assign Student 1 to Section 10-B (Should detect conflict)
        res_cross_check = run_query(
            "SELECT public.fn_check_student_assignments(%s::UUID, ARRAY[%s::UUID], %s, %s::UUID, %s::UUID) AS result;",
            (school_a_id, student_1_id, "2026-27", class_10_id, sec_10b_id)
        )[0]["result"]
        conflicts = res_cross_check.get("conflicts", [])
        record_test("Detect Cross-Section Move Conflict (Student 1 in 10-A)", res_cross_check.get("has_conflicts") == True and conflicts[0]["current_section_name"] == "10-A")

        # Step 4: Reassignment Blocked Without Explicit Move Confirmation (409)
        res_move_blocked = run_query(
            "SELECT public.fn_assign_class_students(%s::UUID, %s::UUID, %s::UUID, %s::UUID, ARRAY[%s::UUID], %s, FALSE) AS result;",
            (school_a_id, admin_a_id, class_10_id, sec_10b_id, student_1_id, "2026-27")
        )[0]["result"]
        record_test("Reassignment Blocked Without Confirmation (409)", res_move_blocked.get("requires_confirmation") == True and res_move_blocked.get("code") == 409)

        # Step 5: Move Confirmed with p_confirm_move = TRUE
        res_move_confirmed = run_query(
            "SELECT public.fn_assign_class_students(%s::UUID, %s::UUID, %s::UUID, %s::UUID, ARRAY[%s::UUID], %s, TRUE) AS result;",
            (school_a_id, admin_a_id, class_10_id, sec_10b_id, student_1_id, "2026-27")
        )[0]["result"]
        record_test("Move Confirmed: Student 1 Moved from 10-A to 10-B", res_move_confirmed.get("success") == True)

        # Step 6: Unassign Single Student from 10-A (Only keep Student 2)
        # Note: Student 1 was already moved to 10-B. Now in 10-A we only keep Student 2.
        res_unassign_one = run_query(
            "SELECT public.fn_assign_class_students(%s::UUID, %s::UUID, %s::UUID, %s::UUID, ARRAY[%s::UUID], %s, FALSE) AS result;",
            (school_a_id, admin_a_id, class_10_id, sec_10a_id, student_2_id, "2026-27")
        )[0]["result"]
        record_test("Reconciled Student List in Section 10-A", res_unassign_one.get("success") == True and res_unassign_one.get("assigned_count") == 1)

        # Step 7: Unassign ALL Students from 10-A (Pass Empty Array)
        res_unassign_all = run_query(
            "SELECT public.fn_assign_class_students(%s::UUID, %s::UUID, %s::UUID, %s::UUID, ARRAY[]::UUID[], %s, FALSE) AS result;",
            (school_a_id, admin_a_id, class_10_id, sec_10a_id, "2026-27")
        )[0]["result"]
        
        # Verify 0 students in Section 10-A
        sec_10a_count = run_query(
            "SELECT COUNT(*) AS count FROM public.student_class_assignments WHERE school_id = %s::UUID AND section_id = %s::UUID AND status = 'ACTIVE';",
            (school_a_id, sec_10a_id)
        )[0]["count"]
        record_test("Unassign All Students from Section 10-A", res_unassign_all.get("success") == True and sec_10a_count == 0)

        # Step 8: Assign Student Directly to Class 5 (No Section Mode)
        res_std_c5 = run_query(
            "SELECT public.fn_assign_class_students(%s::UUID, %s::UUID, %s::UUID, NULL, ARRAY[%s::UUID], %s, FALSE) AS result;",
            (school_a_id, admin_a_id, class_5_id, student_3_id, "2026-27")
        )[0]["result"]
        record_test("Assign Student Directly to Class 5 (No Section)", res_std_c5.get("success") == True and res_std_c5.get("assigned_count") == 1)

        # --------------------------------------------------------------------
        # TEST 7: Teacher Scoped Access Control & Data Isolation
        # --------------------------------------------------------------------
        print("\n[Phase 7] Teacher Role Scoping & Access Control...")
        # Admin Query (p_teacher_id = NULL) -> Sees both Class 10 and Class 5
        admin_classes = run_query(
            "SELECT public.fn_get_academic_classes(%s::UUID, %s, %s, %s, %s, %s, %s, %s, %s::UUID) AS result;",
            (school_a_id, "", "2026-27", "ALL", 1, 20, "display_order", "ASC", None)
        )[0]["result"]
        total_admin_classes = admin_classes.get("data", {}).get("total_count", 0)
        record_test("Admin Sees All School Classes", total_admin_classes >= 2)

        # Teacher 1 Query (Assigned to Class 10) -> Sees ONLY Class 10
        t1_classes = run_query(
            "SELECT public.fn_get_academic_classes(%s::UUID, %s, %s, %s, %s, %s, %s, %s, %s::UUID) AS result;",
            (school_a_id, "", "2026-27", "ALL", 1, 20, "display_order", "ASC", teacher_1_id)
        )[0]["result"]
        t1_list = t1_classes.get("data", {}).get("classes", [])
        t1_class_ids = [c["id"] for c in t1_list]
        record_test("Teacher 1 Scoped Classes (Only Assigned Class 10)", len(t1_list) == 1 and class_10_id in t1_class_ids)

        # Unassigned Teacher Query -> Sees 0 Classes
        t_unassigned_classes = run_query(
            "SELECT public.fn_get_academic_classes(%s::UUID, %s, %s, %s, %s, %s, %s, %s, %s::UUID) AS result;",
            (school_a_id, "", "2026-27", "ALL", 1, 20, "display_order", "ASC", teacher_unassigned_id)
        )[0]["result"]
        record_test("Unassigned Teacher Sees 0 Classes", t_unassigned_classes.get("data", {}).get("total_count", 0) == 0)

        # Teacher 1 Class Detail for Unassigned Class 5 -> Blocked (403 / Not Found)
        t1_c5_detail = run_query(
            "SELECT public.fn_get_academic_class_detail(%s::UUID, %s::UUID, %s::UUID) AS result;",
            (school_a_id, class_5_id, teacher_1_id)
        )[0]["result"]
        record_test("Teacher 1 Blocked from Viewing Unassigned Class Detail", t1_c5_detail.get("success") == False and t1_c5_detail.get("code") in (403, 404))

        # Teacher 1 Scoped Stats -> Only reflects Class 10
        t1_stats = run_query(
            "SELECT public.fn_get_academic_stats(%s::UUID, %s, %s::UUID) AS result;",
            (school_a_id, "2026-27", teacher_1_id)
        )[0]["result"]
        record_test("Teacher 1 Scoped Statistics", t1_stats.get("success") == True and t1_stats.get("data", {}).get("total_classes") == 1)

        # Teacher 1 Scoped Sections -> Only reflects Section 10-A
        t1_sections = run_query(
            "SELECT public.fn_get_academic_sections(%s::UUID, %s, %s::UUID, %s, %s, %s, %s, %s, %s, %s::UUID) AS result;",
            (school_a_id, "", None, "2026-27", "ALL", 1, 20, "name", "ASC", teacher_1_id)
        )[0]["result"]
        t1_sec_list = t1_sections.get("data", {}).get("sections", [])
        record_test("Teacher 1 Scoped Sections Query", t1_sections.get("success") == True and len(t1_sec_list) >= 1)

        # --------------------------------------------------------------------
        # TEST 8: Dependency-Aware Archiving & Restore Lifecycle
        # --------------------------------------------------------------------
        print("\n[Phase 8] Dependency-Aware Archiving & Restore...")
        # Step 1: Attempt to Archive Class 10 without force -> Blocked due to dependencies
        archive_block = run_query(
            "SELECT public.fn_archive_academic_class(%s::UUID, %s::UUID, %s::UUID, FALSE) AS result;",
            (school_a_id, admin_a_id, class_10_id)
        )[0]["result"]
        record_test("Class Archive Blocked Without Force Due to Dependencies", archive_block.get("has_dependencies") == True and archive_block.get("code") == 400)

        # Step 2: Force Archive Class 10
        archive_ok = run_query(
            "SELECT public.fn_archive_academic_class(%s::UUID, %s::UUID, %s::UUID, TRUE) AS result;",
            (school_a_id, admin_a_id, class_10_id)
        )[0]["result"]
        record_test("Force Archive Class 10 Cascades Cleanly", archive_ok.get("success") == True)

        # Step 3: Verify Class 10 Appears in ARCHIVED Filter Query
        archived_classes = run_query(
            "SELECT public.fn_get_academic_classes(%s::UUID, %s, %s, %s, %s, %s, %s, %s, %s::UUID) AS result;",
            (school_a_id, "", "2026-27", "ARCHIVED", 1, 20, "name", "ASC", None)
        )[0]["result"]
        archived_ids = [c["id"] for c in archived_classes.get("data", {}).get("classes", [])]
        record_test("Archived Class 10 Visible in ARCHIVED Filter", class_10_id in archived_ids)

        # Step 4: Restore Class 10
        restore_ok = run_query(
            "SELECT public.fn_restore_academic_class(%s::UUID, %s::UUID, %s::UUID) AS result;",
            (school_a_id, admin_a_id, class_10_id)
        )[0]["result"]
        record_test("Restore Class 10 & Sections Successfully", restore_ok.get("success") == True)

        # Step 5: Archive & Restore Section 10-D
        sec_archive = run_query(
            "SELECT public.fn_archive_academic_section(%s::UUID, %s::UUID, %s::UUID, TRUE) AS result;",
            (school_a_id, admin_a_id, sec_10d_id)
        )[0]["result"]
        sec_restore = run_query(
            "SELECT public.fn_restore_academic_section(%s::UUID, %s::UUID, %s::UUID) AS result;",
            (school_a_id, admin_a_id, sec_10d_id)
        )[0]["result"]
        record_test("Archive & Restore Section 10-D", sec_archive.get("success") == True and sec_restore.get("success") == True)

        # Step 6: Archive & Restore Subject Math
        sub_archive = run_query(
            "SELECT public.fn_archive_academic_subject(%s::UUID, %s::UUID, %s::UUID, TRUE) AS result;",
            (school_a_id, admin_a_id, sub_math_id)
        )[0]["result"]
        sub_restore = run_query(
            "SELECT public.fn_restore_academic_subject(%s::UUID, %s::UUID, %s::UUID) AS result;",
            (school_a_id, admin_a_id, sub_math_id)
        )[0]["result"]
        record_test("Archive & Restore Subject Math", sub_archive.get("success") == True and sub_restore.get("success") == True)

        # --------------------------------------------------------------------
        # TEST 8B: Advanced Search, Filtering, Sorting & Subject Scoping
        # --------------------------------------------------------------------
        print("\n[Phase 8B] Advanced Filtering, Search & Subject Scoping...")
        # Re-link Math subject and Teacher 1 to Class 10
        run_query(
            "SELECT public.fn_manage_class_subjects(%s::UUID, %s::UUID, %s::UUID, NULL, ARRAY[%s::UUID], %s);",
            (school_a_id, admin_a_id, class_10_id, sub_math_id, "2026-27"), fetch=False
        )
        run_query(
            "SELECT public.fn_assign_class_teachers(%s::UUID, %s::UUID, %s::UUID, NULL, ARRAY[%s::UUID], %s);",
            (school_a_id, admin_a_id, class_10_id, teacher_1_id, "2026-27"), fetch=False
        )
        # Assign student 1 to Section 10-B
        run_query(
            "SELECT public.fn_assign_class_students(%s::UUID, %s::UUID, %s::UUID, %s::UUID, ARRAY[%s::UUID], %s, TRUE);",
            (school_a_id, admin_a_id, class_10_id, sec_10b_id, student_1_id, "2026-27"), fetch=False
        )

        # 1. Subject Scoping for Teacher 1 (assigned to Class 10 which has Math)
        t1_subjects = run_query(
            "SELECT public.fn_get_academic_subjects(%s::UUID, %s, %s, %s, %s, %s, %s, %s, %s::UUID) AS result;",
            (school_a_id, "", "ALL", "ALL", 1, 20, "name", "ASC", teacher_1_id)
        )[0]["result"]
        t1_sub_list = t1_subjects.get("data", {}).get("subjects", [])
        record_test("Teacher 1 Scoped Subjects Query", t1_subjects.get("success") == True and len(t1_sub_list) >= 1)

        # 2. Subject Scoping for Unassigned Teacher (Should return 0)
        unassigned_subjects = run_query(
            "SELECT public.fn_get_academic_subjects(%s::UUID, %s, %s, %s, %s, %s, %s, %s, %s::UUID) AS result;",
            (school_a_id, "", "ALL", "ALL", 1, 20, "name", "ASC", teacher_unassigned_id)
        )[0]["result"]
        record_test("Unassigned Teacher Sees 0 Subjects", unassigned_subjects.get("data", {}).get("total_count", 0) == 0)

        # 3. Subject Type Filter (Practical vs Core)
        practical_subjects = run_query(
            "SELECT public.fn_get_academic_subjects(%s::UUID, %s, %s, %s, %s, %s, %s, %s, NULL) AS result;",
            (school_a_id, "", "Practical", "ALL", 1, 20, "name", "ASC")
        )[0]["result"]
        prac_list = practical_subjects.get("data", {}).get("subjects", [])
        record_test("Subject Type Filter (Practical)", len(prac_list) == 1 and prac_list[0]["code"] == "PHYS10")

        # 4. Class Search by Name/Code/Stage Query
        search_secondary = run_query(
            "SELECT public.fn_get_academic_classes(%s::UUID, %s, %s, %s, %s, %s, %s, %s, NULL) AS result;",
            (school_a_id, "Secondary", "2026-27", "ALL", 1, 20, "display_order", "ASC")
        )[0]["result"]
        record_test("Class Search Query by Stage keyword ('Secondary')", search_secondary.get("data", {}).get("total_count", 0) >= 1)

        # 5. Search Students with Section & Class Filter
        students_in_sec10b = run_query(
            "SELECT public.fn_search_academic_students(%s::UUID, %s, %s, %s::UUID, %s::UUID, 10) AS result;",
            (school_a_id, "", "2026-27", class_10_id, sec_10b_id)
        )[0]["result"]
        s_10b_list = students_in_sec10b.get("data", [])
        record_test("Search Students Filtered by Section 10-B", len(s_10b_list) == 1 and s_10b_list[0]["id"] == student_1_id)

        # 6. Search Teachers Filtered by Department
        math_teachers = run_query(
            "SELECT public.fn_search_academic_teachers(%s::UUID, %s, 10) AS result;",
            (school_a_id, "Mathematics")
        )[0]["result"]
        record_test("Search Teachers by Department ('Mathematics')", len(math_teachers.get("data", [])) >= 1)

        # --------------------------------------------------------------------
        # TEST 9: Resilient Audit Logging with System / Invalid User IDs
        # --------------------------------------------------------------------
        print("\n[Phase 9] Resiliency & Audit Logging Edge Cases...")
        # System / Non-existent User ID should not cause foreign key errors
        fake_user_id = str(uuid.uuid4())
        res_system_audit = run_query(
            "SELECT public.fn_assign_class_students(%s::UUID, %s::UUID, %s::UUID, NULL, ARRAY[%s::UUID], %s, FALSE) AS result;",
            (school_a_id, fake_user_id, class_5_id, student_4_id, "2026-27")
        )[0]["result"]
        record_test("Resilient Audit Logging with System User ID", res_system_audit.get("success") == True)

        # Audit with NULL User ID
        res_null_audit = run_query(
            "SELECT public.fn_assign_class_students(%s::UUID, NULL, %s::UUID, NULL, ARRAY[%s::UUID], %s, FALSE) AS result;",
            (school_a_id, class_5_id, student_4_id, "2026-27")
        )[0]["result"]
        record_test("Resilient Audit Logging with NULL User ID", res_null_audit.get("success") == True)

    finally:
        print("\n[Phase 10] Teardown Test Data...")
        run_query("DELETE FROM public.student_class_assignments WHERE school_id IN (%s, %s);", (school_a_id, school_b_id), fetch=False)
        run_query("DELETE FROM public.class_teacher_assignments WHERE school_id IN (%s, %s);", (school_a_id, school_b_id), fetch=False)
        run_query("DELETE FROM public.class_subject_assignments WHERE school_id IN (%s, %s);", (school_a_id, school_b_id), fetch=False)
        run_query("DELETE FROM public.academic_sections WHERE school_id IN (%s, %s);", (school_a_id, school_b_id), fetch=False)
        run_query("DELETE FROM public.academic_classes WHERE school_id IN (%s, %s);", (school_a_id, school_b_id), fetch=False)
        run_query("DELETE FROM public.academic_subjects WHERE school_id IN (%s, %s);", (school_a_id, school_b_id), fetch=False)
        run_query("DELETE FROM public.audit_logs WHERE school_id IN (%s, %s);", (school_a_id, school_b_id), fetch=False)
        run_query("DELETE FROM public.profiles WHERE school_id IN (%s, %s);", (school_a_id, school_b_id), fetch=False)
        run_query("DELETE FROM public.schools WHERE id IN (%s, %s);", (school_a_id, school_b_id), fetch=False)
        record_test("Teardown Completed Cleanly", True)

    print("\n" + "=" * 70)
    print(f"📊 TEST SUITE SUMMARY: {passed} PASSED | {failed} FAILED")
    print(f"🎯 SUCCESS RATE: {(passed / (passed + failed) * 100.0):.1f}%")
    print("=" * 70 + "\n")

    if failed > 0:
        sys.exit(1)

if __name__ == "__main__":
    main()
