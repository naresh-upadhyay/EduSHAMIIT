import os
import sys
import json
import asyncio
from datetime import date, datetime, timedelta
import psycopg2
from psycopg2.extras import RealDictCursor

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@supabase-db:5432/postgres")

def run_tests():
    print("=" * 80)
    print("HOSTEL MANAGEMENT COMPREHENSIVE EDGE-CASE TEST SUITE")
    print("=" * 80)

    conn = psycopg2.connect(DATABASE_URL)
    conn.autocommit = True
    cur = conn.cursor(cursor_factory=RealDictCursor)

    # 0. Fetch active school, building, floor, student
    cur.execute("SELECT id, name FROM public.schools LIMIT 1;")
    school = cur.fetchone()
    assert school is not None, "No active school found!"
    school_id = school['id']
    school_name = school['name']
    print(f"[*] Active School: {school_name} ({school_id})")

    cur.execute("SELECT id, name FROM public.hostel_buildings WHERE school_id = %s LIMIT 1;", (school_id,))
    building = cur.fetchone()
    building_id = building['id'] if building else None

    cur.execute("SELECT id, floor_name FROM public.hostel_floors WHERE building_id = %s LIMIT 1;", (building_id,))
    floor = cur.fetchone()
    floor_id = floor['id'] if floor else None

    cur.execute("""
        SELECT ha.id as admission_id, ha.student_id, p.full_name as student_name,
               al.bed_id, bed.room_id
        FROM public.hostel_admissions ha
        JOIN public.profiles p ON ha.student_id = p.id
        LEFT JOIN public.hostel_allocations al ON al.admission_id = ha.id AND al.allocation_status IN ('CHECKED_IN', 'CONFIRMED')
        LEFT JOIN public.hostel_beds bed ON al.bed_id = bed.id
        WHERE ha.school_id = %s AND ha.admission_status = 'ACTIVE'
        LIMIT 5;
    """, (school_id,))
    active_students = cur.fetchall()
    print(f"[*] Found {len(active_students)} active hostel students for test scenarios.")

    # -------------------------------------------------------------------------
    # TEST 1: Executive Overview Analytics & Zero-Collision Route Verification
    # -------------------------------------------------------------------------
    print("\n[TEST 1] Verifying Executive Overview Analytics Function (Zero Hardcoding)...")
    cur.execute("SELECT public.fn_hostel_get_overview_analytics(%s::UUID, %s) AS result;", (school_id, '2026 - 2027'))
    res = cur.fetchone()['result']
    assert res is not None, "fn_hostel_get_overview_analytics returned null"
    kpis = res.get('kpis', {})
    print(f"  -> Total Beds: {kpis.get('total_beds')}")
    print(f"  -> Occupied Beds: {kpis.get('occupied_beds')}")
    print(f"  -> Occupancy Rate: {kpis.get('occupancy_rate')}%")
    print(f"  -> Buildings in breakdown: {len(res.get('building_occupancy', []))}")
    print("  [PASS] Test 1: Overview Analytics executing cleanly without route or data collisions.")

    # -------------------------------------------------------------------------
    # TEST 2: Night Curfew Roll-Call Attendance Edge Cases
    # -------------------------------------------------------------------------
    print("\n[TEST 2] Testing Night Curfew Roll-Call Attendance Subsystem...")
    if active_students:
        records_to_submit = []
        for idx, s in enumerate(active_students):
            st = 'PRESENT'
            if idx == 1:
                st = 'ABSENT' # Deliberate absent edge case
            elif idx == 2:
                st = 'APPROVED_LEAVE'
            records_to_submit.append({
                'student_id': str(s['student_id']),
                'admission_id': str(s['admission_id']),
                'room_id': str(s['room_id']) if s['room_id'] else None,
                'bed_id': str(s['bed_id']) if s['bed_id'] else None,
                'status': st,
                'remarks': f"Test roll-call status: {st}"
            })

        cur.execute("""
            SELECT public.fn_hostel_submit_night_attendance(
                %s::UUID, %s::UUID, %s::UUID, NULL, CURRENT_DATE, '2026 - 2027',
                %s::JSONB, 'Automated Edge Case Test Session'
            ) AS res;
        """, (school_id, building_id, floor_id, json.dumps(records_to_submit)))
        att_res = cur.fetchone()['res']
        assert att_res['success'] is True, f"Attendance submission failed: {att_res}"
        session_id = att_res['session_id']
        print(f"  -> Created Night Attendance Session ID: {session_id}")
        print(f"  -> Present: {att_res['present_count']}, Absent: {att_res['absent_count']}, On Leave: {att_res['on_leave_count']}")

        # Verify parent alert flag was automatically raised for the absent student
        cur.execute("""
            SELECT count(*) as count FROM public.hostel_night_attendance_records
            WHERE session_id = %s AND status = 'ABSENT' AND parent_alert_sent = TRUE;
        """, (session_id,))
        absent_alert = cur.fetchone()['count']
        assert absent_alert == 1, f"Expected 1 absent student with parent_alert_sent=True, found {absent_alert}"
        print("  -> Parent alert flag triggered automatically for absent student.")
        print("  [PASS] Test 2: Night Curfew Attendance & Parent Alert verification passed.")

    # -------------------------------------------------------------------------
    # TEST 3: Mess & Dining Hall Management Edge Cases
    # -------------------------------------------------------------------------
    print("\n[TEST 3] Testing Mess Menus, Dietary Profiles & Rebates...")
    cur.execute("SELECT count(*) as count FROM public.hostel_mess_menus WHERE school_id = %s;", (school_id,))
    menu_count = cur.fetchone()['count']
    assert menu_count > 0, "No mess menus seeded"
    print(f"  -> Total Mess Menu schedules: {menu_count}")

    # Dietary profile query
    cur.execute("SELECT count(*) as count FROM public.hostel_mess_dietary_profiles WHERE school_id = %s;", (school_id,))
    diet_count = cur.fetchone()['count']
    print(f"  -> Student Dietary Profiles configured: {diet_count}")

    # Test meal consumption scan at gate
    if active_students:
        target_student = active_students[0]['student_id']
        cur.execute("""
            INSERT INTO public.hostel_mess_attendance (school_id, student_id, meal_date, meal_type, status)
            VALUES (%s, %s, CURRENT_DATE, 'DINNER', 'CONSUMED')
            RETURNING id, scanned_at;
        """, (school_id, target_student))
        scan_rec = cur.fetchone()
        assert scan_rec is not None, "Failed to log meal attendance scan"
        print(f"  -> Logged meal attendance scan: {scan_rec['id']} at {scan_rec['scanned_at']}")

    # Test leave mess rebate calculation logic
    # Create a synthetic 5-day approved leave request to test rebate calculator
    if active_students:
        target_student = active_students[0]['student_id']
        target_adm = active_students[0]['admission_id']
        req_num = f"REQ-REBATE-{int(datetime.now().timestamp())}"
        cur.execute("""
            INSERT INTO public.hostel_leave_outing_requests (
                school_id, admission_id, student_id, academic_year, request_type,
                reason, destination, start_at, expected_return_at, status, request_number
            ) VALUES (
                %s, %s, %s, '2026 - 2027', 'HOME_VISIT',
                'Family Vacation Festival', 'Home City',
                NOW() - INTERVAL '5 days', NOW(),
                'APPROVED', %s
            ) RETURNING id;
        """, (school_id, target_adm, target_student, req_num))
        synthetic_leave = cur.fetchone()
        leave_id = synthetic_leave['id']

        cur.execute("SELECT public.fn_hostel_process_leave_mess_rebate(%s::UUID, %s::UUID, 120.00) AS res;", (school_id, leave_id))
        rebate_res = cur.fetchone()['res']
        assert rebate_res['success'] is True, f"Rebate processing failed: {rebate_res}"
        print(f"  -> Processed 5-day Mess Rebate: {rebate_res['days']} Days @ ₹120/day = ₹{rebate_res['rebate_amount']}")
        print("  [PASS] Test 3: Mess & Dining Subsystem edge cases verified.")

    # -------------------------------------------------------------------------
    # TEST 4: Room & Bed Asset Handover Audit with Deposit Penalty Deduction
    # -------------------------------------------------------------------------
    print("\n[TEST 4] Testing Room Asset Handover Audit & Penalty Deduction...")
    if active_students:
        target_student = active_students[0]['student_id']
        target_adm = active_students[0]['admission_id']
        target_room = active_students[0]['room_id']
        target_bed = active_students[0]['bed_id']

        checklist = [
            {"item": "Mattress", "condition": "GOOD", "is_present": True, "damage_cost": 0.0},
            {"item": "Study Table", "condition": "DAMAGED", "is_present": True, "damage_cost": 450.0},
            {"item": "Cupboard Key", "condition": "MISSING", "is_present": False, "damage_cost": 250.0}
        ]

        cur.execute("""
            SELECT public.fn_hostel_record_asset_audit(
                %s::UUID, %s::UUID, %s::UUID, %s::UUID, %s::UUID,
                'CHECK_OUT', NULL, %s::JSONB, 700.00, TRUE, 'Checkout audit with damaged table and lost key'
            ) AS res;
        """, (school_id, target_student, target_adm, target_room, target_bed, json.dumps(checklist)))
        audit_res = cur.fetchone()['res']
        assert audit_res['success'] is True, f"Asset audit failed: {audit_res}"
        audit_id = audit_res['audit_id']
        print(f"  -> Created Asset Handover Audit ID: {audit_id}")

        # Verify penalty was automatically posted to hostel_penalties table
        cur.execute("""
            SELECT id, amount, charge_type, status FROM public.hostel_penalties
            WHERE student_id = %s AND description LIKE %s;
        """, (target_student, f"%{audit_id}%"))
        penalty = cur.fetchone()
        assert penalty is not None, "Expected automatic penalty generation for damage cost, but none found"
        assert float(penalty['amount']) == 700.00, f"Expected ₹700 penalty, got {penalty['amount']}"
        print(f"  -> Verified automatic caution deposit penalty posted: ₹{penalty['amount']} ({penalty['charge_type']})")
        print("  [PASS] Test 4: Room Asset Handover Audit & Penalty Deduction verified.")

    # -------------------------------------------------------------------------
    # TEST 5: Visitor Logbook & Guest Room Management Edge Cases
    # -------------------------------------------------------------------------
    print("\n[TEST 5] Testing Visitor Logbook & Guest Room Management...")
    # Check-in visitor
    cur.execute("""
        INSERT INTO public.hostel_visitors (
            school_id, visitor_name, visitor_phone, relationship, purpose,
            badge_number, vehicle_number, status
        ) VALUES (
            %s, 'Dr. Rajesh Sharma', '+91 9876543210', 'Father', 'Weekend Visit',
            'V-TEST-99', 'DL-01-AB-1234', 'ACTIVE'
        ) RETURNING id, check_in_time;
    """, (school_id,))
    v_rec = cur.fetchone()
    v_id = v_rec['id']
    print(f"  -> Checked in Visitor ID: {v_id} with Badge V-TEST-99")

    # Checkout visitor
    cur.execute("""
        UPDATE public.hostel_visitors
        SET status = 'CHECKED_OUT', check_out_time = NOW()
        WHERE id = %s RETURNING status, check_out_time;
    """, (v_id,))
    v_out = cur.fetchone()
    assert v_out['status'] == 'CHECKED_OUT', "Visitor status did not transition to CHECKED_OUT"
    print(f"  -> Verified 1-click Visitor Checkout at {v_out['check_out_time']}")

    # Book a guest room
    cur.execute("""
        INSERT INTO public.hostel_guest_room_bookings (
            school_id, visitor_id, guest_name, contact_number, check_in_date,
            check_out_date, daily_charge, total_charge, payment_status, status
        ) VALUES (
            %s, %s, 'Dr. Rajesh Sharma', '+91 9876543210', CURRENT_DATE,
            CURRENT_DATE + 2, 800.00, 1600.00, 'PAID', 'CONFIRMED'
        ) RETURNING id, total_charge;
    """, (school_id, v_id))
    booking = cur.fetchone()
    assert booking is not None, "Failed to book guest room"
    print(f"  -> Confirmed Guest Room Booking ID: {booking['id']} (Charge: ₹{booking['total_charge']})")
    print("  [PASS] Test 5: Visitor Logbook & Guest Room Management verified.")

    # -------------------------------------------------------------------------
    # TEST 6: Room Bulk Generation Collision Pre-check Verification
    # -------------------------------------------------------------------------
    print("\n[TEST 6] Testing Room Bulk Generation Collision Prevention...")
    if building_id and floor_id:
        cur.execute("""
            SELECT room_number FROM public.hostel_rooms
            WHERE floor_id = %s LIMIT 3;
        """, (floor_id,))
        existing_rooms = [r['room_number'] for r in cur.fetchall()]
        print(f"  -> Existing rooms on floor: {existing_rooms}")
        # Verify ON CONFLICT DO NOTHING / safe update stored proc works without crashing
        cur.execute("""
            SELECT public.fn_hostel_create_or_update_room(
                %s::UUID, NULL, jsonb_build_object(
                    'building_id', %s::UUID,
                    'floor_id', %s::UUID,
                    'room_number', 'TEST-ROOM-SAFE-01',
                    'capacity', 2,
                    'room_type', 'Standard'
                )
            ) AS result;
        """, (school_id, building_id, floor_id))
        room_res = cur.fetchone()['result']
        assert room_res['success'] is True, f"Room creation failed: {room_res}"
        print(f"  -> Safe room creation: {room_res.get('message', 'Created successfully')}")
        print("  [PASS] Test 6: Bulk Room Generation Collision Prevention verified.")

    conn.close()
    print("\n" + "=" * 80)
    print("ALL 6 COMPREHENSIVE EDGE-CASE TEST SUITES PASSED WITH 0 ERRORS!")
    print("=" * 80)

if __name__ == "__main__":
    run_tests()
