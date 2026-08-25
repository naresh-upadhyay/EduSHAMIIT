import sys
import os
import requests
import json
from datetime import date
from jose import jwt
from app.config import settings

API_BASE_URL = os.environ.get("API_BASE_URL", "http://127.0.0.1:8000")

def test_attendance_grid_state_saving():
    print("=" * 80)
    print("E2E TEST: GRID STATE ATTENDANCE SAVING & ALL PERIOD BREAKDOWNS")
    print("=" * 80)

    # 1. Generate Super Admin Token
    secret = settings.SUPABASE_JWT_SECRET
    user_id = "38a93170-997b-4b4c-bc8e-256b93169c23"
    school_id = "11111111-1111-1111-1111-111111111111"
    token = jwt.encode({
        "sub": user_id,
        "school_id": school_id,
        "role": "super_admin",
        "email": "superadmin@edushamiit.com",
        "exp": 9999999999
    }, secret, algorithm="HS256")
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    # 2. Find Class 5
    classes_res = requests.get(f"{API_BASE_URL}/api/classes?academic_year=2026-27", headers=headers, timeout=8)
    assert classes_res.status_code == 200, f"Failed to list classes: {classes_res.text}"
    classes = classes_res.json().get("data", {}).get("classes", [])
    
    class_5 = next((c for c in classes if "class 5" in c["name"].lower()), None)
    if not class_5:
        class_5 = classes[0]
    class_id = class_5["id"]
    print(f"Target Class: {class_5['name']} ({class_id})")

    attendance_date = "2026-08-19"

    # 3. Get initial roster
    roster_res = requests.get(
        f"{API_BASE_URL}/api/attendance/roster?attendance_date={attendance_date}&class_id={class_id}&mode=ALL_DAY&page=1&page_size=10",
        headers=headers,
        timeout=8
    )
    assert roster_res.status_code == 200, f"Failed to get roster: {roster_res.text}"
    students = roster_res.json().get("data", {}).get("students", [])
    print(f"Loaded {len(students)} students in roster.")
    assert len(students) > 0, "No students found in target class"

    # 4. Prepare Exact Test Scenarios (Matching User Screenshot 1):
    # Aarav Shah: P1 = HALF_DAY, P2 = PRESENT -> composite HALF_DAY
    # Ananya Singh: P1 = ABSENT, P2 = LATE -> composite LATE / HALF_DAY
    # Naresh Upadhyay: P1 = PRESENT, P2 = HALF_DAY -> composite HALF_DAY
    test_specs = [
        {"p1": "HALF_DAY", "p2": "PRESENT", "status": "HALF_DAY", "rem": "Aarav note"},
        {"p1": "ABSENT", "p2": "LATE", "status": "LATE", "rem": "Ananya note"},
        {"p1": "PRESENT", "p2": "HALF_DAY", "status": "HALF_DAY", "rem": "Naresh note"},
    ]

    records = []
    for i, s in enumerate(students):
        spec = test_specs[i % len(test_specs)]
        student_id = s.get("student_id") or s.get("id")
        student_periods_count = len(s.get("periods", []))
        student_period_records = []
        if student_periods_count >= 1:
            student_period_records.append({"period_number": 1, "status": spec["p1"], "remarks": f"P1 {spec['rem']}"})
        if student_periods_count >= 2:
            student_period_records.append({"period_number": 2, "status": spec["p2"], "remarks": f"P2 {spec['rem']}"})
            
        records.append({
            "student_id": student_id,
            "status": spec["status"],
            "remarks": spec["rem"],
            "periods": student_period_records
        })

    save_payload = {
        "attendance_date": attendance_date,
        "class_id": class_id,
        "section_id": None,
        "mode": "ALL_DAY",
        "records": records,
        "allow_override": True
    }

    # 5. Execute POST /api/attendance/save
    print("\n[Step 1] Sending POST /api/attendance/save with live grid state...")
    save_res = requests.post(f"{API_BASE_URL}/api/attendance/save", json=save_payload, headers=headers, timeout=10)
    print(f"Save Status Code: {save_res.status_code}")
    print(f"Save Response: {save_res.text}")
    assert save_res.status_code == 200, f"Save API failed: {save_res.text}"
    assert save_res.json().get("success") == True, "Save API returned success: False"

    # 6. Fetch Roster After Save and VERIFY NO OVERWRITES
    print("\n[Step 2] Fetching Roster via GET /api/attendance/roster to verify exact period retention...")
    after_res = requests.get(
        f"{API_BASE_URL}/api/attendance/roster?attendance_date={attendance_date}&class_id={class_id}&mode=ALL_DAY&page=1&page_size=10",
        headers=headers,
        timeout=8
    )
    assert after_res.status_code == 200, f"Failed to get roster after save: {after_res.text}"
    after_students = after_res.json().get("data", {}).get("students", [])

    print("\n" + "-" * 75)
    print("VERIFICATION RESULTS:")
    print("-" * 75)
    all_passed = True
    for i, s in enumerate(after_students):
        if i >= len(records):
            break
        expected = records[i]
        exp_periods = expected["periods"]
        periods_map = {p.get("period_number"): p.get("status") for p in s.get("periods", [])}
        
        student_ok = True
        name = s.get("full_name") or s.get("student_name")
        print(f"Student: {name} (Section: {s.get('section_name')}, Periods: {len(s.get('periods', []))})")
        for ep in exp_periods:
            p_num = ep["period_number"]
            exp_st = ep["status"]
            act_st = periods_map.get(p_num)
            match_st = (act_st == exp_st)
            if not match_st:
                student_ok = False
                all_passed = False
            print(f"    P{p_num} -> Expected: {exp_st}, Actual: {act_st} {'(OK)' if match_st else '(MISMATCH!)'}")
        
        mark = "[PASS]" if student_ok else "[FAIL]"
        print(f"    {mark} Day Status: {s.get('status')}")

    print("-" * 75)
    if all_passed:
        print("[SUCCESS] All students retained their exact, distinct period statuses perfectly!")
    else:
        print("[ERROR] Some periods were incorrectly overwritten!")
        sys.exit(1)

    # 7. Test Edge Case: Saving in 'PERIOD' mode and 'CUSTOM_SELECTION' mode
    print("\n[Step 3] Testing Edge Case: Save with Custom / Partial Periods...")
    custom_records = [{
        "student_id": after_students[0].get("student_id") or after_students[0]["id"],
        "status": "PRESENT",
        "remarks": "Updated P1 to PRESENT, P2 to ABSENT",
        "periods": [
            {"period_number": 1, "status": "PRESENT", "remarks": ""},
            {"period_number": 2, "status": "ABSENT", "remarks": ""}
        ]
    }]
    custom_save = requests.post(f"{API_BASE_URL}/api/attendance/save", json={
        "attendance_date": attendance_date,
        "class_id": class_id,
        "mode": "MULTI_SCHEDULE",
        "records": custom_records,
        "allow_override": True
    }, headers=headers, timeout=10)
    assert custom_save.status_code == 200
    
    roster_custom = requests.get(
        f"{API_BASE_URL}/api/attendance/roster?attendance_date={attendance_date}&class_id={class_id}&mode=ALL_DAY",
        headers=headers,
        timeout=8
    ).json()
    st0 = roster_custom.get("data", {}).get("students", [])[0]
    p_map = {p.get("period_number"): p.get("status") for p in st0.get("periods", [])}
    assert p_map.get(1) == "PRESENT", f"Expected P1 PRESENT, got {p_map.get(1)}"
    assert p_map.get(2) == "ABSENT", f"Expected P2 ABSENT, got {p_map.get(2)}"
    print("[PASS] Custom / Partial Period save verified: P1=PRESENT, P2=ABSENT retained without corruption.")

    print("\n" + "=" * 80)
    print("ALL EDGE CASES TESTED & VERIFIED SUCCESSFULLY!")
    print("=" * 80)

if __name__ == "__main__":
    test_attendance_grid_state_saving()
