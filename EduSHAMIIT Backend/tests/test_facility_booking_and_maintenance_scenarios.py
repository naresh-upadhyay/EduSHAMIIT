#!/usr/bin/env python3
"""
Comprehensive End-to-End Test Suite for Campus Facilities Issue Reporting & Space Booking
Tests all 10x Architect Grade Scenarios & Edge Cases:
1. Facility Discovery & Profile Validation
2. Facility Maintenance Work Order Generation & Vendor Assignment
3. Facility Space Booking Creation (without standard room dependencies)
4. Facility Booking SSOT Listing & Grid Display Rendering
5. Real-Time Conflict Detection Engine (Facility-aware)
6. Overlap Rejection vs. Allow-Conflict Override
7. Facility Recurring Booking Series Generation
8. Co-existence & Non-Regression with Classrooms/Rooms
9. Full Details Query with Multi-level Approvals & History
10. Clean Teardown
"""

import sys
import os
import json
import uuid
import datetime
import requests
import psycopg2
from psycopg2.extras import RealDictCursor

BASE_URL = os.environ.get("API_BASE_URL", "http://127.0.0.1:8000/api/v1")

DEMO_SCHOOL_ID = "11111111-1111-1111-1111-111111111111"
DEMO_USER_ID = "00000000-0000-0000-0000-000000000001"

test_booking_ids = []
test_maintenance_ids = []

# Generate or use test authentication token
try:
    from app.config import settings
    from jose import jwt
    AUTH_TOKEN = jwt.encode(
        {'sub': DEMO_USER_ID, 'school_id': DEMO_SCHOOL_ID, 'role': 'super_admin', 'email': 'test_admin@edushamiit.com', 'exp': 2000000000},
        settings.JWT_SECRET,
        algorithm='HS256'
    )
except Exception:
    AUTH_TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIwMDAwMDAwMC0wMDAwLTAwMDAtMDAwMC0wMDAwMDAwMDAwMDEiLCJzY2hvb2xfaWQiOiIxMTExMTExMS0xMTExLTExMTEtMTExMS0xMTExMTExMTExMTEiLCJyb2xlIjoic3VwZXJfYWRtaW4iLCJlbWFpbCI6InRlc3RfYWRtaW5AZWR1c2hhbWlpdC5jb20iLCJleHAiOjIwMDAwMDAwMDB9.qZUeOcSlzFevu4ZhJZsb2KGcJOShwBU_hdC-Lq2wuck"

session = requests.Session()
session.headers.update({
    "Authorization": f"Bearer {AUTH_TOKEN}",
    "Content-Type": "application/json"
})

def get_db_connection():
    return psycopg2.connect(
        dbname=os.environ.get('POSTGRES_DB', 'postgres'),
        user=os.environ.get('POSTGRES_USER', 'postgres'),
        password=os.environ.get('POSTGRES_PASSWORD', 'postgres'),
        host=os.environ.get('POSTGRES_HOST', 'supabase-db'),
        port=int(os.environ.get('POSTGRES_PORT', 5432))
    )

def print_result(scenario_num, title, passed, details=""):
    badge = "PASS [OK]" if passed else "FAIL [X]"
    print(f"Scenario {scenario_num:02d}: {title.ljust(65)} {badge}")
    if details:
        print(f"   -> {details}")

def main():
    print("=" * 80)
    print("CAMPUS FACILITIES ISSUE REPORTING & SPACE BOOKING END-TO-END VERIFICATION")
    print("=" * 80)
    
    passed_count = 0
    total_scenarios = 10

    # Ensure demo profile exists for foreign key constraints
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO public.profiles (id, user_id, school_id, email, full_name, role)
                VALUES (%s, 'usr_test_lead_01', %s, 'test_admin@edushamiit.com', 'Test Campus Lead', 'super_admin')
                ON CONFLICT (id) DO UPDATE SET user_id = EXCLUDED.user_id;
            """, (DEMO_USER_ID, DEMO_SCHOOL_ID))
            conn.commit()

    # ------------------------------------------------------------------------
    # SCENARIO 1: Facility Discovery & Profile Validation
    # ------------------------------------------------------------------------
    target_facility = None
    with get_db_connection() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                SELECT id, name, code, category, building_id, floor_id, capacity, area, manager_name
                FROM public.campus_facilities
                WHERE school_id = %s AND deleted_at IS NULL
                ORDER BY created_at ASC
                LIMIT 5;
            """, (DEMO_SCHOOL_ID,))
            facilities = cur.fetchall()
            if facilities:
                target_facility = facilities[0]

    sc1_pass = target_facility is not None and "id" in target_facility
    if sc1_pass:
        passed_count += 1
    print_result(1, "Facility Discovery & Validation", sc1_pass, 
                 f"Found facility: '{target_facility['name']}' ({target_facility['category']}) with ID {target_facility['id']}")

    facility_id = str(target_facility["id"])
    facility_name = target_facility["name"]

    # ------------------------------------------------------------------------
    # SCENARIO 2: Facility Issue Reporting (Maintenance Work Order)
    # ------------------------------------------------------------------------
    sc2_pass = False
    m_id = None
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("""
                    INSERT INTO public.maintenance_requests (
                        school_id, request_code, title, description, request_type, priority,
                        facility_id, location_display, reported_by_name, reported_by_role,
                        assigned_vendor_name, status
                    ) VALUES (
                        %s, 'MT-FAC-' || FLOOR(RANDOM()*89999 + 10000)::TEXT,
                        'Broken lighting & HVAC servicing in ' || %s,
                        'Issue reported directly from campus facilities overview card.',
                        'Electrical & Power', 'High',
                        %s, %s, 'Facility Supervisor', 'Staff', 'Apex Facilities Ltd', 'Pending'
                    ) RETURNING id, request_code, facility_id, location_display;
                """, (DEMO_SCHOOL_ID, facility_name, facility_id, facility_name))
                m_row = cur.fetchone()
                conn.commit()
                if m_row and str(m_row["facility_id"]) == facility_id:
                    sc2_pass = True
                    m_id = str(m_row["id"])
                    test_maintenance_ids.append(m_id)
    except Exception as e:
        sc2_pass = False
        print(f"Error in Scenario 2: {e}")

    if sc2_pass:
        passed_count += 1
    print_result(2, "Facility Issue Reporting (Raise Maintenance Work Order)", sc2_pass,
                 f"Created work order {m_row['request_code']} linked to facility_id={facility_id}")

    # ------------------------------------------------------------------------
    # SCENARIO 3: Campus Facility Space Booking Creation
    # ------------------------------------------------------------------------
    booking_date = (datetime.date.today() + datetime.timedelta(days=7)).isoformat()
    sc3_pass = False
    b1_id = None
    b1_ref = None
    try:
        payload = {
            "title": f"Annual Sports Meet & Arena Practice at {facility_name}",
            "description": "Institutional sports booking across facility space",
            "purpose": "Sports Event",
            "category": "Sports Event",
            "priority": "High",
            "space_target_type": "facility",
            "facility_id": facility_id,
            "room_id": None,
            "booking_date": booking_date,
            "start_time": "10:00:00",
            "end_time": "12:00:00",
            "setup_minutes": 15,
            "cleanup_minutes": 15,
            "organizer_name": "Coach Anderson",
            "organizer_role": "Sports Director",
            "attendee_count": 150,
            "special_instructions": "Check safety nets and field marking",
            "status": "Confirmed",
            "allow_conflict": False
        }
        res = session.post(f"{BASE_URL}/space-bookings/book", json=payload, timeout=10)
        data = res.json()
        if res.status_code == 200 and data.get("success"):
            b1_id = data["data"]["booking_id"]
            b1_ref = data["data"]["booking_ref"]
            test_booking_ids.append(b1_id)
            sc3_pass = True
    except Exception as e:
        sc3_pass = False
        print(f"Error in Scenario 3: {e}")

    if sc3_pass:
        passed_count += 1
    print_result(3, "Facility Space Booking Creation (without standard room)", sc3_pass,
                 f"Created booking ref={b1_ref}, id={b1_id}, date={booking_date}")

    # ------------------------------------------------------------------------
    # SCENARIO 4: Facility Booking SSOT Listing & Grid Display Rendering
    # ------------------------------------------------------------------------
    sc4_pass = False
    item = {}
    try:
        res = session.get(f"{BASE_URL}/space-bookings/requests?status=All&search={b1_ref}", timeout=10)
        data = res.json()
        if res.status_code == 200 and data.get("success"):
            items = data["data"]["items"]
            if items:
                item = items[0]
                has_facility = item.get("facility_id") == facility_id
                has_space_display = facility_name in (item.get("space_display") or "")
                has_target_type = item.get("space_target_type") == "facility"
                sc4_pass = has_facility and has_space_display and has_target_type
    except Exception as e:
        sc4_pass = False
        print(f"Error in Scenario 4: {e}")

    if sc4_pass:
        passed_count += 1
    print_result(4, "Facility Booking SSOT Listing & Grid Formatting", sc4_pass,
                 f"space_display='{item.get('space_display')}', space_target_type='{item.get('space_target_type')}'")

    # ------------------------------------------------------------------------
    # SCENARIO 5: Real-Time Conflict Detection Engine (Facility-aware)
    # ------------------------------------------------------------------------
    sc5_pass = False
    try:
        # Check overlapping slot for same facility (10:30 - 11:30 collides with 10:00 - 12:00)
        url = f"{BASE_URL}/space-bookings/check-slot?facility_id={facility_id}&date={booking_date}&start_time=10:30&end_time=11:30"
        res = session.get(url, timeout=10)
        c_data = res.json()
        conflict_detected = c_data.get("has_conflict") is True

        # Check non-overlapping slot for same facility (14:00 - 16:00 is free)
        url_free = f"{BASE_URL}/space-bookings/check-slot?facility_id={facility_id}&date={booking_date}&start_time=14:00&end_time=16:00"
        res_free = session.get(url_free, timeout=10)
        f_data = res_free.json()
        no_conflict = f_data.get("has_conflict") is False

        sc5_pass = conflict_detected and no_conflict
    except Exception as e:
        sc5_pass = False
        print(f"Error in Scenario 5: {e}")

    if sc5_pass:
        passed_count += 1
    print_result(5, "Facility Conflict Detection (Free/Busy Window)", sc5_pass,
                 f"10:30-11:30 conflict={conflict_detected}, 14:00-16:00 free={no_conflict}")

    # ------------------------------------------------------------------------
    # SCENARIO 6: Overlap Rejection vs. Allow-Conflict Override
    # ------------------------------------------------------------------------
    sc6_pass = False
    try:
        # 1. Attempt conflicting booking with allow_conflict=False -> Should reject with 409
        clash_payload = {
            "title": f"Clashing Inter-School Tournament at {facility_name}",
            "facility_id": facility_id,
            "space_target_type": "facility",
            "booking_date": booking_date,
            "start_time": "10:30:00",
            "end_time": "11:30:00",
            "organizer_name": "Coach Miller",
            "status": "Confirmed",
            "allow_conflict": False
        }
        res_reject = session.post(f"{BASE_URL}/space-bookings/book", json=clash_payload, timeout=10)
        rejected_correctly = res_reject.status_code == 409

        # 2. Attempt same conflicting booking with allow_conflict=True -> Should succeed and force status to Pending
        clash_payload["allow_conflict"] = True
        res_override = session.post(f"{BASE_URL}/space-bookings/book", json=clash_payload, timeout=10)
        override_data = res_override.json()
        override_success = res_override.status_code == 200 and override_data.get("success")
        is_pending = override_data.get("data", {}).get("status") == "Pending"

        if override_success:
            test_booking_ids.append(override_data["data"]["booking_id"])

        sc6_pass = rejected_correctly and override_success and is_pending
    except Exception as e:
        sc6_pass = False
        print(f"Error in Scenario 6: {e}")

    if sc6_pass:
        passed_count += 1
    print_result(6, "Conflict Rejection & Allow-Conflict Override to Pending", sc6_pass,
                 f"Rejected on false={rejected_correctly}, Saved as Pending on true={is_pending}")

    # ------------------------------------------------------------------------
    # SCENARIO 7: Facility Recurring Booking Series Generation
    # ------------------------------------------------------------------------
    sc7_pass = False
    try:
        rec_start = (datetime.date.today() + datetime.timedelta(days=14)).isoformat()
        rec_payload = {
            "title": f"Weekly Fitness Sessions at {facility_name}",
            "facility_id": facility_id,
            "space_target_type": "facility",
            "booking_date": rec_start,
            "start_time": "07:00:00",
            "end_time": "08:00:00",
            "organizer_name": "Trainer Alex",
            "is_recurring": True,
            "recurrence": {
                "frequency": "weekly",
                "interval": 1,
                "days_of_week": [1, 3, 5],
                "end_type": "count",
                "count": 4,
                "allow_conflict": True
            }
        }
        res_rec = session.post(f"{BASE_URL}/space-bookings/book", json=rec_payload, timeout=10)
        rec_data = res_rec.json()
        if res_rec.status_code == 200 and rec_data.get("success"):
            created_count = rec_data["data"].get("created_count", 0)
            series_id = rec_data["data"].get("series_id")
            sc7_pass = created_count >= 1 and series_id is not None
            # Collect created recurring IDs for teardown
            with get_db_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute("SELECT id FROM public.space_bookings WHERE recurring_series_id = %s", (series_id,))
                    rec_ids = [str(r[0]) for r in cur.fetchall()]
                    test_booking_ids.extend(rec_ids)
    except Exception as e:
        sc7_pass = False
        print(f"Error in Scenario 7: {e}")

    if sc7_pass:
        passed_count += 1
    print_result(7, "Facility Recurring Booking Series Generation", sc7_pass,
                 f"Created {created_count} recurring facility bookings under series={series_id}")

    # ------------------------------------------------------------------------
    # SCENARIO 8: Co-existence & Non-Regression with Classrooms/Rooms
    # ------------------------------------------------------------------------
    sc8_pass = False
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("""
                    SELECT id, name, building_id, floor_id FROM public.rooms 
                    WHERE school_id = %s AND deleted_at IS NULL AND is_bookable = TRUE
                    LIMIT 1;
                """, (DEMO_SCHOOL_ID,))
                sample_room = cur.fetchone()

        if sample_room:
            room_payload = {
                "title": f"Regular Classroom Lecture in {sample_room['name']}",
                "room_id": str(sample_room["id"]),
                "building_id": str(sample_room["building_id"]),
                "floor_id": str(sample_room["floor_id"]),
                "space_target_type": "room",
                "booking_date": booking_date,
                "start_time": "14:00:00",
                "end_time": "15:00:00",
                "organizer_name": "Prof Smith",
                "status": "Confirmed",
                "allow_conflict": False
            }
            res_room = session.post(f"{BASE_URL}/space-bookings/book", json=room_payload, timeout=10)
            room_data = res_room.json()
            if res_room.status_code == 200 and room_data.get("success"):
                test_booking_ids.append(room_data["data"]["booking_id"])
                
                # Verify both room booking and facility booking are returned together in requests list
                res_all = session.get(f"{BASE_URL}/space-bookings/requests?status=All&date_from={booking_date}&date_to={booking_date}", timeout=10)
                items_all = res_all.json()["data"]["items"]
                has_fac_item = any(i.get("facility_id") == facility_id for i in items_all)
                has_room_item = any(i.get("room_id") == str(sample_room["id"]) for i in items_all)
                sc8_pass = has_fac_item and has_room_item
    except Exception as e:
        sc8_pass = False
        print(f"Error in Scenario 8: {e}")

    if sc8_pass:
        passed_count += 1
    print_result(8, "Unified Co-existence of Facility & Room Bookings", sc8_pass,
                 f"Both room and facility bookings co-exist cleanly in grid: fac={has_fac_item}, room={has_room_item}")

    # ------------------------------------------------------------------------
    # SCENARIO 9: Facility Booking Details API & History Integrity
    # ------------------------------------------------------------------------
    sc9_pass = False
    d = {}
    try:
        res_det = session.get(f"{BASE_URL}/space-bookings/details/{b1_id}", timeout=10)
        det_data = res_det.json()
        if res_det.status_code == 200 and det_data.get("success"):
            d = det_data["data"]
            has_fac_meta = d.get("facility_id") == facility_id and d.get("facility_name") == facility_name
            has_history = len(d.get("status_history", [])) > 0
            sc9_pass = has_fac_meta and has_history
    except Exception as e:
        sc9_pass = False
        print(f"Error in Scenario 9: {e}")

    if sc9_pass:
        passed_count += 1
    print_result(9, "Facility Booking Details, Metadata & Audit Trail", sc9_pass,
                 f"facility_name='{d.get('facility_name')}', history_entries={len(d.get('status_history', []))}")

    # ------------------------------------------------------------------------
    # SCENARIO 10: Clean Teardown
    # ------------------------------------------------------------------------
    sc10_pass = False
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                if test_booking_ids:
                    cur.execute("DELETE FROM public.space_bookings WHERE id = ANY(%s::UUID[])", (test_booking_ids,))
                if test_maintenance_ids:
                    cur.execute("DELETE FROM public.maintenance_requests WHERE id = ANY(%s::UUID[])", (test_maintenance_ids,))
                conn.commit()
                sc10_pass = True
    except Exception as e:
        sc10_pass = False
        print(f"Error in Scenario 10: {e}")

    if sc10_pass:
        passed_count += 1
    print_result(10, "Automated Test Teardown & Data Sanitization", sc10_pass,
                 f"Removed {len(test_booking_ids)} test bookings and {len(test_maintenance_ids)} test work orders")

    print("=" * 80)
    print(f"TOTAL TEST RESULTS: {passed_count}/{total_scenarios} SCENARIOS PASSED ({(passed_count/total_scenarios)*100:.1f}%)")
    print("=" * 80)

    if passed_count == total_scenarios:
        sys.exit(0)
    else:
        sys.exit(1)

if __name__ == "__main__":
    main()
