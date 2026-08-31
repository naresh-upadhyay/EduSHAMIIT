import sys
import os
import requests
import json
import uuid
from jose import jwt

BASE_URL = os.environ.get("CLASSES_API_URL", "http://localhost:8000/api/classes")
JWT_SECRET = "super-secret-jwt-token-with-at-least-32-characters-long"
SCHOOL_ID = "11111111-1111-1111-1111-111111111111"
USER_ID = "38a93170-997b-4b4c-bc8e-256b93169c23"

def get_auth_headers():
    token = jwt.encode({
        "sub": USER_ID,
        "school_id": SCHOOL_ID,
        "role": "Super Admin",
        "permissions": ["*"]
    }, JWT_SECRET, algorithm="HS256")
    return {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

def run_tests():
    headers = get_auth_headers()
    passed = 0
    total = 0

    def assert_eq(a, b, desc):
        nonlocal passed, total
        total += 1
        if a == b:
            passed += 1
            print(f"[PASS] {desc}")
        else:
            print(f"[FAIL] {desc} (Expected: {b}, Got: {a})")
            sys.exit(1)

    def assert_true(cond, desc):
        nonlocal passed, total
        total += 1
        if cond:
            passed += 1
            print(f"[PASS] {desc}")
        else:
            print(f"[FAIL] {desc}")
            sys.exit(1)

    print("=" * 80)
    print("STARTING EXHAUSTIVE SECTIONS ANALYTICS & STATS TEST SUITE")
    print("=" * 80)

    # 1. Test GET /api/classes/sections/stats
    r = requests.get(f"{BASE_URL}/sections/stats", headers=headers)
    assert_eq(r.status_code, 200, "GET /sections/stats status is 200")
    data = r.json().get("data", {})

    total_sections = data.get("total_sections", 0)
    active_sections = data.get("active_sections", 0)
    inactive_sections = data.get("inactive_sections", 0)
    total_students = data.get("total_students", 0)
    avg_students = data.get("avg_students_per_section", 0.0)

    assert_true(total_sections >= 0, f"total_sections is non-negative ({total_sections})")
    assert_eq(active_sections + inactive_sections, total_sections, "active + inactive == total_sections")
    
    if total_sections > 0:
        expected_avg = round(total_students / total_sections, 2)
        assert_eq(avg_students, expected_avg, f"avg_students_per_section is mathematically correct ({avg_students})")

    # 2. Test sections_by_class breakdown
    sections_by_class = data.get("sections_by_class", [])
    assert_true(isinstance(sections_by_class, list), "sections_by_class is a list")
    
    total_sec_in_breakdown = sum(c.get("sections_count", 0) for c in sections_by_class)
    assert_eq(total_sec_in_breakdown, total_sections, f"Sum of sections across classes ({total_sec_in_breakdown}) == total_sections ({total_sections})")

    # 3. Test buildings_overview breakdown
    buildings_overview = data.get("buildings_overview", [])
    assert_true(isinstance(buildings_overview, list), "buildings_overview is a list")
    
    total_sec_in_buildings = sum(b.get("sections_count", 0) for b in buildings_overview)
    assert_eq(total_sec_in_buildings, total_sections, f"Sum of sections across buildings ({total_sec_in_buildings}) == total_sections ({total_sections})")

    # 4. Check sorting order
    for i in range(len(sections_by_class) - 1):
        assert_true(
            sections_by_class[i].get("sections_count", 0) >= sections_by_class[i+1].get("sections_count", 0),
            "sections_by_class is ordered descending by section count"
        )

    print("=" * 80)
    print(f"CONGRATULATIONS: ALL {passed}/{total} SECTIONS ANALYTICS TESTS PASSED 100%!")
    print("=" * 80)

if __name__ == "__main__":
    run_tests()
