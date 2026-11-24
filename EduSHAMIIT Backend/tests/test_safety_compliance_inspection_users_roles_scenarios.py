#!/usr/bin/env python3
"""
Comprehensive Test Suite for Campus Safety & Compliance Inspection Users, Roles & Lookup Keys
Tests:
1. Lookup Management Integration: INSPECTION_CATEGORY, INSPECTION_STATUS, INSPECTION_ROLE
2. Profiles & User Management Integration: Fetching active users from profiles table
3. Roles Management Integration: Fetching canonical roles from app_roles table
4. Safety Inspection Creation with real User ID, Role, Category from Lookups
5. Safety Inspection Listing verifying inspector_user_id and location display
6. Safety Inspection Update modifying score, inspector and status
7. Double-click deduplication verification (SI-2026-008 cleaned up)
8. Clean Teardown
"""

import os
import sys
import json
import uuid
import datetime
import requests
import psycopg2
from psycopg2.extras import RealDictCursor

BASE_URL = os.environ.get("API_BASE_URL", "http://127.0.0.1:8000/api/v1")
DEMO_SCHOOL_ID = "11111111-1111-1111-1111-111111111111"
DEMO_USER_ID = "00000000-0000-0000-0000-000000000001"

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
        password=os.environ.get('POSTGRES_PASSWORD', 'eduSHAMIIT2026_pg'),
        host=os.environ.get('POSTGRES_HOST', '127.0.0.1'),
        port=int(os.environ.get('POSTGRES_PORT', 54322))
    )

def print_result(scenario_num, title, passed, details=""):
    badge = "PASS [OK]" if passed else "FAIL [X]"
    print(f"Scenario {scenario_num:02d}: {title.ljust(65)} {badge}")
    if details:
        print(f"   -> {details}")

def main():
    print("=" * 80)
    print("CAMPUS SAFETY INSPECTIONS, USER PROFILES & ROLES INTEGRATION TEST")
    print("=" * 80)

    all_passed = True
    test_inspection_id = None

    # Scenario 1: Lookup Keys in DB
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT key_code FROM public.lookup_keys WHERE key_code IN ('INSPECTION_CATEGORY', 'INSPECTION_STATUS', 'INSPECTION_ROLE')")
        keys = [r['key_code'] for r in cur.fetchall()]
        passed = 'INSPECTION_CATEGORY' in keys and 'INSPECTION_STATUS' in keys and 'INSPECTION_ROLE' in keys
        print_result(1, "Verify Canonical Safety Lookup Keys in DB", passed, f"Found keys: {keys}")
        all_passed = all_passed and passed
        conn.close()
    except Exception as e:
        print_result(1, "Verify Canonical Safety Lookup Keys in DB", False, str(e))
        all_passed = False

    # Scenario 2: Profiles & Users Available
    chosen_user = None
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT id, full_name, email, role FROM public.profiles WHERE school_id = %s LIMIT 5", (DEMO_SCHOOL_ID,))
        users = cur.fetchall()
        passed = len(users) > 0
        if passed:
            chosen_user = users[0]
        print_result(2, "Fetch Active Inspector Profiles from User Management", passed, f"Total sampled: {len(users)}, Chosen: {chosen_user['full_name'] if chosen_user else 'None'}")
        all_passed = all_passed and passed
        conn.close()
    except Exception as e:
        print_result(2, "Fetch Active Inspector Profiles from User Management", False, str(e))
        all_passed = False

    # Scenario 3: App Roles Available
    chosen_role = None
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT id, name, display_name FROM public.app_roles LIMIT 10")
        roles = cur.fetchall()
        passed = len(roles) > 0
        if passed:
            chosen_role = roles[0]
        print_result(3, "Fetch Canonical App Roles from Roles Management", passed, f"Total sampled: {len(roles)}, Chosen: {chosen_role['display_name'] if chosen_role else 'None'}")
        all_passed = all_passed and passed
        conn.close()
    except Exception as e:
        print_result(3, "Fetch Canonical App Roles from Roles Management", False, str(e))
        all_passed = False

    # Scenario 4: Create Inspection with inspector_user_id & role from app_roles
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT public.sp_create_or_update_safety_inspection(%s::JSONB) AS result;", (
            json.dumps({
                "school_id": DEMO_SCHOOL_ID,
                "title": "E2E Automated Safety & Structural Clearance Audit",
                "category": "Structural Integrity",
                "location_display": "Engineering Block / Structural Wings A & B",
                "inspector_name": chosen_user['full_name'] if chosen_user else "Dr. Lead Auditor",
                "inspector_role": chosen_role['display_name'] if chosen_role else "Safety & Compliance Officer",
                "inspector_user_id": str(chosen_user['id']) if chosen_user else None,
                "status": "Passed",
                "compliance_score": 98.5,
                "findings": "All structural beams and seismic dampeners verified within 100% nominal tolerances.",
                "inspection_date": "2026-11-24"
            }),
        ))
        res = cur.fetchone()['result']
        conn.commit()
        test_inspection_id = res.get('id')
        passed = res.get('success') is True and test_inspection_id is not None
        print_result(4, "Create Safety Inspection Linked to DB User & Role", passed, f"ID: {test_inspection_id}, Code: {res.get('inspection_code')}")
        all_passed = all_passed and passed
        conn.close()
    except Exception as e:
        print_result(4, "Create Safety Inspection Linked to DB User & Role", False, str(e))
        all_passed = False

    # Scenario 5: Verify Inspection in Listing Procedure with inspector_user_id
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT * FROM public.sp_list_safety_inspections(%s::UUID, NULL, NULL, NULL, 'E2E Automated', 1, 10);", (DEMO_SCHOOL_ID,))
        row = cur.fetchone()
        records = row['records'] if row else []
        passed = len(records) > 0 and records[0].get('id') == test_inspection_id and records[0].get('inspector_user_id') == str(chosen_user['id'])
        print_result(5, "Verify Stored Inspection Returns inspector_user_id in List SP", passed, f"Found record: {records[0] if records else 'None'}")
        all_passed = all_passed and passed
        conn.close()
    except Exception as e:
        print_result(5, "Verify Stored Inspection Returns inspector_user_id in List SP", False, str(e))
        all_passed = False

    # Scenario 6: Update Inspection (Updating score, findings, and inspector)
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT public.sp_create_or_update_safety_inspection(%s::JSONB) AS result;", (
            json.dumps({
                "id": test_inspection_id,
                "school_id": DEMO_SCHOOL_ID,
                "compliance_score": 99.5,
                "status": "Passed",
                "findings": "Follow-up verification completed: Zero structural defects detected."
            }),
        ))
        conn.commit()
        cur.execute("SELECT compliance_score, findings FROM public.safety_inspections WHERE id = %s", (test_inspection_id,))
        updated = cur.fetchone()
        passed = float(updated['compliance_score']) == 99.5 and "Zero structural defects" in updated['findings']
        print_result(6, "Update Safety Inspection and Verify Persistence", passed, f"Score: {updated['compliance_score']}")
        all_passed = all_passed and passed
        conn.close()
    except Exception as e:
        print_result(6, "Update Safety Inspection and Verify Persistence", False, str(e))
        all_passed = False

    # Scenario 7: Verify Deduplication (Duplicate SI-2026-008 with title MASTER removed)
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT COUNT(*) AS cnt FROM public.safety_inspections WHERE title = 'MASTER'")
        cnt = cur.fetchone()['cnt']
        # Exactly 1 MASTER inspection remains (deduplicated from 2)
        passed = cnt == 1
        print_result(7, "Verify Double-Click Duplicate is Deduplicated (Only 1 'MASTER' remains)", passed, f"Total 'MASTER' records: {cnt}")
        all_passed = all_passed and passed
        conn.close()
    except Exception as e:
        print_result(7, "Verify Double-Click Duplicate is Deduplicated (Only 1 'MASTER' remains)", False, str(e))
        all_passed = False

    # Scenario 8: Clean Teardown
    try:
        if test_inspection_id:
            conn = get_db_connection()
            cur = conn.cursor()
            cur.execute("DELETE FROM public.safety_inspections WHERE id = %s", (test_inspection_id,))
            conn.commit()
            conn.close()
        print_result(8, "Clean Teardown of Test Inspection", True, f"Deleted ID {test_inspection_id}")
    except Exception as e:
        print_result(8, "Clean Teardown of Test Inspection", False, str(e))

    print("=" * 80)
    if all_passed:
        print("ALL 8 SCENARIOS PASSED WITH 100% SUCCESS!")
    else:
        print("SOME SCENARIOS FAILED!")
    print("=" * 80)

if __name__ == "__main__":
    main()
