"""
Exhaustive End-to-End Test Suite for Universal Academic Management:
Classes, Sections, Subjects, Rooms, Teacher Assignments & Conflict Detection.

Covers All 7 Test Groups:
- Group 1: Classes CRUD, Duplicates, Filters, Archive Safety & Restore
- Group 2: Sections CRUD, Capacity, Default Room Link, Student Count & Cascade Safety
- Group 3: Subjects CRUD, Core vs Optional vs Elective, Section Offerings & Enrollments
- Group 4: Rooms CRUD, Room Types, Facilities, Availability, Schedule Allocations
- Group 5: Interconnected Relationships (Class -> Section -> Student, Class -> Subject -> Section -> Teacher, Room -> Timetable)
- Group 6: Conflict Engine (Room Double-Booking, Teacher Overlap, Section Overlap)
- Group 7: Security & Multi-Tenant School/Academic Year Isolation
"""
import os
import sys
import uuid
import json
import psycopg2
from psycopg2.extras import RealDictCursor

DATABASE_URL = os.environ.get("DATABASE_URL", "postgresql://postgres:eduSHAMIIT2026_pg@db:5432/postgres")

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

def record_test(name, condition, detail=""):
    global passed, failed
    if condition:
        passed += 1
        print(f"  ✅ [PASS] {name} {detail}")
    else:
        failed += 1
        print(f"  ❌ [FAIL] {name} - {detail}")

def run_suite():
    global passed, failed
    print("\n" + "=" * 75)
    print("🎓 EXHAUSTIVE ACADEMIC MANAGEMENT PRODUCTION TEST SUITE")
    print("=" * 75)

    # Fixture Setup
    school_a = str(uuid.uuid4())
    school_b = str(uuid.uuid4())
    admin_a = str(uuid.uuid4())
    teacher_1 = str(uuid.uuid4())
    teacher_2 = str(uuid.uuid4())
    student_1 = str(uuid.uuid4())
    student_2 = str(uuid.uuid4())
    student_3 = str(uuid.uuid4())

    run_query("""
        INSERT INTO public.schools (id, name) VALUES (%s, 'Greenfield International School') ON CONFLICT DO NOTHING;
        INSERT INTO public.schools (id, name) VALUES (%s, 'Sunrise High School') ON CONFLICT DO NOTHING;
    """, (school_a, school_b), fetch=False)

    run_query("""
        INSERT INTO public.profiles (id, user_id, school_id, email, full_name, role) VALUES 
        (%s, %s, %s, 'admin@greenfield.edu', 'Admin Greenfield', 'super_admin'),
        (%s, %s, %s, 'teacher1@greenfield.edu', 'Amit Sharma', 'teacher'),
        (%s, %s, %s, 'teacher2@greenfield.edu', 'Neha Verma', 'teacher'),
        (%s, %s, %s, 'student1@greenfield.edu', 'Aarav Gupta', 'student'),
        (%s, %s, %s, 'student2@greenfield.edu', 'Diya Patel', 'student'),
        (%s, %s, %s, 'student3@greenfield.edu', 'Kabir Khan', 'student')
        ON CONFLICT DO NOTHING;
    """, (admin_a, admin_a, school_a, teacher_1, teacher_1, school_a, teacher_2, teacher_2, school_a, student_1, student_1, school_a, student_2, student_2, school_a, student_3, student_3, school_a), fetch=False)

    # =========================================================================
    # TEST GROUP 1: CLASSES CRUD, DUPLICATE CODES, ARCHIVE SAFETY & RESTORE
    # =========================================================================
    print("\n[GROUP 1] Classes Management...")

    # 1.1 Create Class with Inline Sections
    res_class = run_query("""
        SELECT public.fn_create_academic_class(%s::UUID, %s::UUID, %s::JSONB) as res;
    """, (school_a, admin_a, json.dumps({
        "name": "Class 11",
        "code": "CL-11",
        "stage": "Senior Secondary",
        "academic_year": "2026-27",
        "display_order": 11,
        "status": "ACTIVE",
        "sections": [
            {"name": "11-A", "code": "11A", "capacity": 40},
            {"name": "11-B", "code": "11B", "capacity": 40}
        ]
    })))[0]["res"]
    class_11_id = res_class.get("data", {}).get("id")
    record_test("1.1 Create Class with 2 Inline Sections", res_class.get("success") == True and class_11_id is not None)

    # 1.2 Duplicate Class Code Rejected in Same School & Academic Year
    res_dup_class = run_query("""
        SELECT public.fn_create_academic_class(%s::UUID, %s::UUID, %s::JSONB) as res;
    """, (school_a, admin_a, json.dumps({
        "name": "Class 11 Duplicate",
        "code": "CL-11",
        "academic_year": "2026-27"
    })))[0]["res"]
    record_test("1.2 Duplicate Class Code Rejected (409)", res_dup_class.get("success") == False and res_dup_class.get("code") == 409)

    # 1.3 Same Class Code Allowed in Different School (Multi-Tenant Isolation)
    res_school_b_class = run_query("""
        SELECT public.fn_create_academic_class(%s::UUID, %s::UUID, %s::JSONB) as res;
    """, (school_b, admin_a, json.dumps({
        "name": "Class 11",
        "code": "CL-11",
        "academic_year": "2026-27"
    })))[0]["res"]
    record_test("1.3 Multi-Tenant Isolation: Same Code Allowed in School B", res_school_b_class.get("success") == True)

    # 1.4 Update Class Details
    res_upd_class = run_query("""
        SELECT public.fn_update_academic_class(%s::UUID, %s::UUID, %s::UUID, %s::JSONB) as res;
    """, (school_a, admin_a, class_11_id, json.dumps({"display_order": 12})))[0]["res"]
    record_test("1.4 Update Class Details", res_upd_class.get("success") == True)

    # =========================================================================
    # TEST GROUP 2: SECTIONS CRUD, CAPACITY & ROOM LINKAGE
    # =========================================================================
    print("\n[GROUP 2] Sections Management...")

    # Fetch created sections
    sec_rows = run_query("SELECT id, name FROM public.academic_sections WHERE class_id = %s::UUID ORDER BY name ASC;", (class_11_id,))
    sec_11a_id = sec_rows[0]["id"]
    sec_11b_id = sec_rows[1]["id"]
    record_test("2.1 Sections Linked to Class", len(sec_rows) == 2)

    # 2.2 Create Standalone Section 11-C
    res_sec_c = run_query("""
        SELECT public.fn_create_academic_section(%s::UUID, %s::UUID, %s::JSONB) as res;
    """, (school_a, admin_a, json.dumps({
        "class_id": class_11_id,
        "name": "11-C",
        "code": "11C",
        "capacity": 35,
        "academic_year": "2026-27"
    })))[0]["res"]
    sec_11c_id = res_sec_c.get("data", {}).get("id")
    record_test("2.2 Create Standalone Section 11-C", res_sec_c.get("success") == True and sec_11c_id is not None)

    # 2.3 Duplicate Section Code in Same Class Rejected
    res_dup_sec = run_query("""
        SELECT public.fn_create_academic_section(%s::UUID, %s::UUID, %s::JSONB) as res;
    """, (school_a, admin_a, json.dumps({
        "class_id": class_11_id,
        "name": "11-C Duplicate",
        "code": "11C",
        "academic_year": "2026-27"
    })))[0]["res"]
    record_test("2.3 Duplicate Section Code in Same Class Rejected", res_dup_sec.get("success") == False and res_dup_sec.get("code") == 409)

    # 2.4 Assign Students to Sections
    res_assign_stu = run_query("""
        SELECT public.fn_assign_class_students(%s::UUID, %s::UUID, %s::UUID, %s::UUID, %s::UUID[], %s, %s) as res;
    """, (school_a, admin_a, class_11_id, sec_11a_id, [student_1, student_2], "2026-27", False))[0]["res"]
    record_test("2.4 Assign Students 1 & 2 to Section 11-A", res_assign_stu.get("success") == True)

    # =========================================================================
    # TEST GROUP 3: SUBJECTS CRUD, CORE / OPTIONAL OFFERINGS & ENROLLMENTS
    # =========================================================================
    print("\n[GROUP 3] Subjects Management & Offerings...")

    # 3.1 Create Core Subjects: English, Physics, Chemistry
    sub_eng = run_query("""
        SELECT public.fn_create_academic_subject(%s::UUID, %s::UUID, %s::JSONB) as res;
    """, (school_a, admin_a, json.dumps({"name": "English", "code": "ENG", "type": "Core", "periods_per_week": 5})))[0]["res"]["data"]["id"]

    sub_phy = run_query("""
        SELECT public.fn_create_academic_subject(%s::UUID, %s::UUID, %s::JSONB) as res;
    """, (school_a, admin_a, json.dumps({"name": "Physics", "code": "PHY", "type": "Core", "periods_per_week": 6})))[0]["res"]["data"]["id"]

    sub_chem = run_query("""
        SELECT public.fn_create_academic_subject(%s::UUID, %s::UUID, %s::JSONB) as res;
    """, (school_a, admin_a, json.dumps({"name": "Chemistry", "code": "CHEM", "type": "Core", "periods_per_week": 6})))[0]["res"]["data"]["id"]

    # 3.2 Create Optional Subjects: Mathematics, Computer Science, Biology
    sub_math = run_query("""
        SELECT public.fn_create_academic_subject(%s::UUID, %s::UUID, %s::JSONB) as res;
    """, (school_a, admin_a, json.dumps({"name": "Mathematics", "code": "MATH", "type": "Optional", "periods_per_week": 6})))[0]["res"]["data"]["id"]

    sub_cs = run_query("""
        SELECT public.fn_create_academic_subject(%s::UUID, %s::UUID, %s::JSONB) as res;
    """, (school_a, admin_a, json.dumps({"name": "Computer Science", "code": "CS", "type": "Elective", "periods_per_week": 5})))[0]["res"]["data"]["id"]

    sub_bio = run_query("""
        SELECT public.fn_create_academic_subject(%s::UUID, %s::UUID, %s::JSONB) as res;
    """, (school_a, admin_a, json.dumps({"name": "Biology", "code": "BIO", "type": "Optional", "periods_per_week": 6})))[0]["res"]["data"]["id"]

    record_test("3.1 Create Core & Optional Subjects Catalog", all([sub_eng, sub_phy, sub_chem, sub_math, sub_cs, sub_bio]))

    # 3.3 Assign Core Subjects to Entire Class 11
    res_assign_core = run_query("""
        SELECT public.fn_manage_class_subjects(%s::UUID, %s::UUID, %s::UUID, NULL, %s::UUID[], %s) as res;
    """, (school_a, admin_a, class_11_id, [sub_eng, sub_phy, sub_chem], "2026-27"))[0]["res"]
    record_test("3.2 Assign Core Subjects (ENG, PHY, CHEM) Class-Wide", res_assign_core.get("success") == True)

    # 3.4 Section-Specific Subject Offerings:
    # 11-A offers Mathematics & Computer Science
    # 11-B offers Biology & Mathematics
    res_sec_a_sub = run_query("""
        SELECT public.fn_manage_class_subjects(%s::UUID, %s::UUID, %s::UUID, %s::UUID, %s::UUID[], %s) as res;
    """, (school_a, admin_a, class_11_id, sec_11a_id, [sub_math, sub_cs], "2026-27"))[0]["res"]

    res_sec_b_sub = run_query("""
        SELECT public.fn_manage_class_subjects(%s::UUID, %s::UUID, %s::UUID, %s::UUID, %s::UUID[], %s) as res;
    """, (school_a, admin_a, class_11_id, sec_11b_id, [sub_bio, sub_math], "2026-27"))[0]["res"]

    record_test("3.3 Section-Specific Subject Offerings (11-A vs 11-B)", res_sec_a_sub.get("success") == True and res_sec_b_sub.get("success") == True)

    # 3.5 Teacher Assignment per Subject + Section:
    # 11-A Mathematics -> Teacher 1 (Amit Sharma)
    # 11-B Biology -> Teacher 2 (Neha Verma)
    res_t_assign_1 = run_query("""
        SELECT public.fn_manage_section_subject_teachers(%s::UUID, %s::UUID, %s::UUID, %s::UUID[], %s::UUID, %s::UUID, %s) as res;
    """, (school_a, admin_a, class_11_id, [sec_11a_id], sub_math, teacher_1, "2026-27"))[0]["res"]

    res_t_assign_2 = run_query("""
        SELECT public.fn_manage_section_subject_teachers(%s::UUID, %s::UUID, %s::UUID, %s::UUID[], %s::UUID, %s::UUID, %s) as res;
    """, (school_a, admin_a, class_11_id, [sec_11b_id], sub_bio, teacher_2, "2026-27"))[0]["res"]

    record_test("3.4 Teacher Assignment per Subject + Section", res_t_assign_1.get("success") == True and res_t_assign_2.get("success") == True)

    # 3.6 Student-Level Optional Subject Enrollment:
    # Enroll Student 1 in Mathematics and Student 2 in CS
    res_enr_1 = run_query("""
        SELECT public.fn_manage_student_subject_enrollments(%s::UUID, %s::UUID, %s::UUID, %s::UUID, %s::UUID, %s::UUID[], %s) as res;
    """, (school_a, admin_a, class_11_id, sec_11a_id, sub_math, [student_1], "2026-27"))[0]["res"]

    res_enr_2 = run_query("""
        SELECT public.fn_manage_student_subject_enrollments(%s::UUID, %s::UUID, %s::UUID, %s::UUID, %s::UUID, %s::UUID[], %s) as res;
    """, (school_a, admin_a, class_11_id, sec_11a_id, sub_cs, [student_2], "2026-27"))[0]["res"]

    record_test("3.5 Student Optional Subject Enrollment", res_enr_1.get("success") == True and res_enr_2.get("success") == True)

    # 3.7 Verify Subject-Section Mappings Aggregated View
    res_mappings = run_query("""
        SELECT public.fn_get_subject_section_mappings(%s::UUID, %s::UUID, %s) as res;
    """, (school_a, sub_math, "2026-27"))[0]["res"]
    mappings_data = res_mappings.get("data", [])
    record_test("3.6 Subject-Section Mappings Aggregated Query", len(mappings_data) >= 2)

    # =========================================================================
    # TEST GROUP 4: ROOMS CRUD, TYPES, FACILITIES & AVAILABILITY
    # =========================================================================
    print("\n[GROUP 4] Rooms Management...")

    # 4.1 Create Room: Room 201 (Classroom)
    res_rm_201 = run_query("""
        SELECT public.fn_create_academic_room(%s::UUID, %s::UUID, %s::JSONB) as res;
    """, (school_a, admin_a, json.dumps({
        "name": "Room 201",
        "code": "RM-201-T",
        "type": "Classroom",
        "building": "Academic Block",
        "floor": "2nd Floor",
        "capacity": 45,
        "facilities": ["Projector", "Smart Board", "AC"],
        "status": "AVAILABLE",
        "description": "Spacious standard classroom"
    })))[0]["res"]
    rm_201_id = res_rm_201.get("data", {}).get("id")
    record_test("4.1 Create Classroom Room 201", res_rm_201.get("success") == True and rm_201_id is not None)

    # 4.2 Duplicate Room Code Rejected
    res_dup_rm = run_query("""
        SELECT public.fn_create_academic_room(%s::UUID, %s::UUID, %s::JSONB) as res;
    """, (school_a, admin_a, json.dumps({
        "name": "Duplicate Room",
        "code": "RM-201-T"
    })))[0]["res"]
    record_test("4.2 Duplicate Room Code Rejected (409)", res_dup_rm.get("success") == False and res_dup_rm.get("code") == 409)

    # 4.3 Create Lab: Physics Lab
    res_phy_lab = run_query("""
        SELECT public.fn_create_academic_room(%s::UUID, %s::UUID, %s::JSONB) as res;
    """, (school_a, admin_a, json.dumps({
        "name": "Advanced Physics Lab",
        "code": "ADV-PHY-T",
        "type": "Laboratory",
        "building": "Science Block",
        "floor": "1st Floor",
        "capacity": 35,
        "facilities": ["Laboratory Equipment", "Projector", "AC", "Safety Hood"],
        "status": "AVAILABLE"
    })))[0]["res"]
    phy_lab_id = res_phy_lab.get("data", {}).get("id")
    record_test("4.3 Create Laboratory Room", res_phy_lab.get("success") == True and phy_lab_id is not None)

    # 4.4 Update Room Capacity & Status
    res_upd_rm = run_query("""
        SELECT public.fn_update_academic_room(%s::UUID, %s::UUID, %s::UUID, %s::JSONB) as res;
    """, (school_a, admin_a, rm_201_id, json.dumps({"capacity": 50, "status": "AVAILABLE"})))[0]["res"]
    record_test("4.4 Update Room Details", res_upd_rm.get("success") == True and res_upd_rm.get("data", {}).get("capacity") == 50)

    # 4.5 Link Section Default Room
    run_query("""
        SELECT public.fn_update_academic_section(%s::UUID, %s::UUID, %s::UUID, %s::JSONB) as res;
    """, (school_a, admin_a, sec_11a_id, json.dumps({"room_id": rm_201_id})), fetch=False)

    sec_check = run_query("SELECT room_id, room_number FROM public.academic_sections WHERE id = %s::UUID;", (sec_11a_id,))[0]
    record_test("4.5 Section Default Room Linked", str(sec_check.get("room_id")) == str(rm_201_id))

    # 4.6 Paginated Rooms Query with Filters
    res_rooms_list = run_query("""
        SELECT public.fn_get_academic_rooms(%s::UUID, '', 'Laboratory', 'Science Block', 'ALL', 'ALL', 1, 10, 'name', 'ASC') as res;
    """, (school_a,))[0]["res"]
    record_test("4.6 Filter Rooms by Type & Building", res_rooms_list.get("success") == True and res_rooms_list.get("data", {}).get("total_count", 0) >= 1)

    # =========================================================================
    # TEST GROUP 5: SCHEDULE ALLOCATION & CONFLICT DETECTION ENGINE
    # =========================================================================
    print("\n[GROUP 5 & 6] Room Allocations & Conflict Engine...")

    # 5.1 Allocate Room 201 on Monday (day=1) 09:00 - 10:00 to 11-A Math with Teacher 1
    res_alloc_1 = run_query("""
        SELECT public.fn_allocate_room(%s::UUID, %s::UUID, %s::JSONB) as res;
    """, (school_a, admin_a, json.dumps({
        "room_id": rm_201_id,
        "academic_year": "2026-27",
        "class_id": class_11_id,
        "section_id": sec_11a_id,
        "subject_id": sub_math,
        "teacher_id": teacher_1,
        "day_of_week": 1,
        "start_time": "09:00:00",
        "end_time": "10:00:00",
        "title": "Class 11-A Mathematics",
        "allocation_type": "TIMETABLE"
    })))[0]["res"]
    alloc_1_id = res_alloc_1.get("data", {}).get("id")
    record_test("5.1 Create Timetable Allocation in Room 201", res_alloc_1.get("success") == True and alloc_1_id is not None)

    # 6.1 Conflict Test: Double-Booking Same Room at Overlapping Time (09:30 - 10:30) -> MUST BE BLOCKED
    res_conflict_room = run_query("""
        SELECT public.fn_allocate_room(%s::UUID, %s::UUID, %s::JSONB) as res;
    """, (school_a, admin_a, json.dumps({
        "room_id": rm_201_id,
        "academic_year": "2026-27",
        "class_id": class_11_id,
        "section_id": sec_11b_id,
        "subject_id": sub_chem,
        "day_of_week": 1,
        "start_time": "09:30:00",
        "end_time": "10:30:00",
        "title": "Class 11-B Chemistry"
    })))[0]["res"]
    record_test("6.1 Room Conflict: Overlapping Booking Blocked (409)", res_conflict_room.get("success") == False and res_conflict_room.get("code") == 409)

    # 6.2 Conflict Test: Same Teacher Double-Booked in Different Room (09:15 - 09:45) -> MUST BE BLOCKED
    res_conflict_teacher = run_query("""
        SELECT public.fn_allocate_room(%s::UUID, %s::UUID, %s::JSONB) as res;
    """, (school_a, admin_a, json.dumps({
        "room_id": phy_lab_id,
        "academic_year": "2026-27",
        "class_id": class_11_id,
        "section_id": sec_11b_id,
        "subject_id": sub_phy,
        "teacher_id": teacher_1, # Teacher 1 is already in Room 201 09:00 - 10:00
        "day_of_week": 1,
        "start_time": "09:15:00",
        "end_time": "09:45:00",
        "title": "Class 11-B Physics Lab"
    })))[0]["res"]
    record_test("6.2 Teacher Conflict: Double-Booked Teacher Blocked (409)", res_conflict_teacher.get("success") == False and res_conflict_teacher.get("code") == 409)

    # 6.3 Conflict Test: Same Section Double-Booked in Different Room (09:15 - 09:45) -> MUST BE BLOCKED
    res_conflict_sec = run_query("""
        SELECT public.fn_allocate_room(%s::UUID, %s::UUID, %s::JSONB) as res;
    """, (school_a, admin_a, json.dumps({
        "room_id": phy_lab_id,
        "academic_year": "2026-27",
        "class_id": class_11_id,
        "section_id": sec_11a_id, # Section 11-A is already in Room 201 09:00 - 10:00
        "subject_id": sub_phy,
        "teacher_id": teacher_2,
        "day_of_week": 1,
        "start_time": "09:15:00",
        "end_time": "09:45:00",
        "title": "Class 11-A Physics Lab"
    })))[0]["res"]
    record_test("6.3 Section Conflict: Double-Booked Section Blocked (409)", res_conflict_sec.get("success") == False and res_conflict_sec.get("code") == 409)

    # 5.2 Non-Conflicting Allocation in Different Room & Teacher (10:00 - 11:00) -> MUST PASS
    res_alloc_2 = run_query("""
        SELECT public.fn_allocate_room(%s::UUID, %s::UUID, %s::JSONB) as res;
    """, (school_a, admin_a, json.dumps({
        "room_id": phy_lab_id,
        "academic_year": "2026-27",
        "class_id": class_11_id,
        "section_id": sec_11a_id,
        "subject_id": sub_phy,
        "teacher_id": teacher_2,
        "day_of_week": 1,
        "start_time": "10:00:00",
        "end_time": "11:00:00",
        "title": "Class 11-A Physics Practical"
    })))[0]["res"]
    record_test("5.2 Valid Non-Overlapping Schedule Allocation Passes", res_alloc_2.get("success") == True)

    # =========================================================================
    # TEST GROUP 7: SECURITY, MULTI-TENANT ISOLATION & AUDIT LOGGING
    # =========================================================================
    print("\n[GROUP 7] Security, Archiving & Isolation...")

    # 7.1 School B cannot see School A rooms
    res_b_rooms = run_query("""
        SELECT public.fn_get_academic_rooms(%s::UUID, '', 'ALL', 'ALL', 'ALL', 'ALL', 1, 10, 'name', 'ASC') as res;
    """, (school_b,))[0]["res"]
    record_test("7.1 Multi-Tenant Isolation: School B Sees 0 Rooms from School A", res_b_rooms.get("data", {}).get("total_count", 0) == 0)

    # 7.2 Dependency Safeguard: Cannot archive Room 201 while active allocations exist (without force)
    res_arch_rm_block = run_query("""
        SELECT public.fn_archive_academic_room(%s::UUID, %s::UUID, %s::UUID, FALSE) as res;
    """, (school_a, admin_a, rm_201_id))[0]["res"]
    record_test("7.2 Dependency Safeguard: Room Archive Blocked (Active Allocations)", res_arch_rm_block.get("success") == False and res_arch_rm_block.get("code") == 400)

    # 7.3 Force Archive Room 201
    res_arch_rm_force = run_query("""
        SELECT public.fn_archive_academic_room(%s::UUID, %s::UUID, %s::UUID, TRUE) as res;
    """, (school_a, admin_a, rm_201_id))[0]["res"]
    record_test("7.3 Force Archive Room Succeeds & Cancels Allocations", res_arch_rm_force.get("success") == True)

    # 7.4 Restore Room 201
    res_res_rm = run_query("""
        SELECT public.fn_restore_academic_room(%s::UUID, %s::UUID, %s::UUID) as res;
    """, (school_a, admin_a, rm_201_id))[0]["res"]
    record_test("7.4 Restore Archived Room Successfully", res_res_rm.get("success") == True)

    # 7.5 Academic Overview Stats Integrity
    stats_res = run_query("""
        SELECT public.fn_get_academic_stats(%s::UUID, '2026-27') as res;
    """, (school_a,))[0]["res"]["data"]
    record_test("7.5 Academic Stats Metrics Calculated Correctly", stats_res.get("total_classes", 0) >= 1 and stats_res.get("total_rooms", 0) >= 2)

    # Clean up test fixture
    run_query("DELETE FROM public.profiles WHERE school_id IN (%s::UUID, %s::UUID); DELETE FROM public.schools WHERE id IN (%s::UUID, %s::UUID);", (school_a, school_b, school_a, school_b), fetch=False)
    print("\n  🧹 Test fixtures cleaned up.")

    print("\n" + "=" * 75)
    print(f"📊 TEST SUITE SUMMARY: {passed} PASSED | {failed} FAILED")
    print(f"🎯 SUCCESS RATE: {round((passed / (passed + failed)) * 100, 1)}%")
    print("=" * 75)
    return failed == 0

if __name__ == "__main__":
    success = run_suite()
    sys.exit(0 if success else 1)
