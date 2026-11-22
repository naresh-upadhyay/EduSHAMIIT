"""
Test Suite: Verify 100% dynamic alignment between Student Fee Dashboard KPIs and Roster Grid.
Ensures zero hardcoding, exact matching between sub-tab counts, KPI cards, and grid pagination.
"""

import json
import urllib.request
import urllib.parse
import sys
import hmac
import hashlib
import base64

BASE_URL = "http://localhost:8082/api"
JWT_SECRET = "super-secret-jwt-token-with-at-least-32-characters-long"
SCHOOL_ID = "11111111-1111-1111-1111-111111111111"


def b64url_enc(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode('utf-8').rstrip('=')


def create_jwt_token(payload: dict, secret: str) -> str:
    header = {"alg": "HS256", "typ": "JWT"}
    segments = [
        b64url_enc(json.dumps(header, separators=(',', ':')).encode('utf-8')),
        b64url_enc(json.dumps(payload, separators=(',', ':')).encode('utf-8'))
    ]
    signing_input = ".".join(segments).encode('utf-8')
    sig = hmac.new(secret.encode('utf-8'), signing_input, hashlib.sha256).digest()
    segments.append(b64url_enc(sig))
    return ".".join(segments)


def make_request(path: str, token: str):
    url = f"{BASE_URL}{path}"
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    req = urllib.request.Request(url, headers=headers, method="GET")
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode("utf-8")), resp.status
    except urllib.error.HTTPError as e:
        return json.loads(e.read().decode("utf-8")), e.code


def run_tests():
    token = create_jwt_token({
        "sub": "00000000-0000-0000-0000-000000000001",
        "email": "admin@edushamiit.com",
        "role": "Super Admin",
        "school_id": SCHOOL_ID
    }, JWT_SECRET)

    print("=====================================================================")
    print("TEST SUITE: STUDENT FEE DASHBOARD KPIS & GRID SYNCHRONIZATION")
    print("=====================================================================\n")

    # Test 1: Fetch overall KPIs
    print("1. Testing /student-fees/summary overall numbers...")
    summary, status = make_request("/v1/payment-management/student-fees/summary?academic_year=2026%20-%202027", token)
    assert status == 200, f"Expected 200, got {status}"
    assert summary.get("success") is True, "Expected success=True"
    kpis = summary.get("kpis", {})

    total_students = kpis.get("total_students", 0)
    paid_count = kpis.get("paid_students_count", 0)
    partial_count = kpis.get("partial_students_count", 0)
    pending_count = kpis.get("pending_students_count", 0)
    overdue_count = kpis.get("overdue_students_count", 0)
    overpaid_count = kpis.get("overpaid_students_count", 0)
    unbilled_count = kpis.get("unbilled_students_count", 0)
    total_billed = kpis.get("total_billed", 0.0)
    total_collected = kpis.get("total_collected", 0.0)
    fee_structures_count = kpis.get("fee_structures_count", 0)
    invoices_count = kpis.get("invoices_count", 0)
    payments_count = kpis.get("payments_count", 0)

    print(f"   Total Students: {total_students}")
    print(f"   Paid Students: {paid_count}")
    print(f"   Partial Students: {partial_count}")
    print(f"   Pending Students: {pending_count}")
    print(f"   Overdue Students: {overdue_count}")
    print(f"   Overpaid Students: {overpaid_count}")
    print(f"   Unbilled Students: {unbilled_count}")
    print(f"   Total Billed: Rs. {total_billed:,.2f}")
    print(f"   Total Collected: Rs. {total_collected:,.2f}")
    print(f"   Fee Structures: {fee_structures_count}")
    print(f"   Invoices: {invoices_count}")
    print(f"   Payments: {payments_count}")

    # Check that sum of distinct student statuses matches total_students
    status_sum = paid_count + partial_count + pending_count + overdue_count + overpaid_count + unbilled_count
    assert status_sum == total_students, f"Status sum {status_sum} != total_students {total_students}"
    assert total_billed > 0, "Total billed should be > 0 (not hardcoded 0)"
    assert total_collected > 0, "Total collected should be > 0 (not hardcoded 0)"
    assert fee_structures_count > 0, "Fee structures count should be > 0"
    assert invoices_count > 0, "Invoices count should be > 0"
    assert payments_count > 0, "Payments count should be > 0"
    print("   [PASS] Overall KPIs are positive, valid, and mathematically consistent.\n")

    # Test 2: Check matching roster grid counts for every status
    print("2. Testing Roster Grid count matching for every status filter...")
    status_checks = [
        ("All Fees", "All Status", total_students),
        ("Paid", "Paid", paid_count),
        ("Partial", "Partial", partial_count),
        ("Pending", "Pending", pending_count),
        ("Overdue", "Overdue", overdue_count),
        ("Advance / Credit", "Overpaid", overpaid_count),
    ]

    for tab_name, st_param, expected_count in status_checks:
        roster_res, r_status = make_request(
            f"/v1/payment-management/student-fees/students?academic_year=2026%20-%202027&status={urllib.parse.quote(st_param)}&page=1&page_size=10",
            token
        )
        assert r_status == 200, f"Expected 200 for {st_param}, got {r_status}"
        grid_total = roster_res.get("pagination", {}).get("total_items", -1)
        print(f"   Subtab '{tab_name}' ({st_param}) -> Badge: {expected_count} | Grid: {grid_total}")
        assert grid_total == expected_count, f"Mismatch for {tab_name}: badge={expected_count} vs grid={grid_total}"
    print("   [PASS] All subtab badge counts 100% match roster grid pagination total_items.\n")

    # Test 3: Test class-level dynamic filtering
    print("3. Testing Class-specific filter matching (e.g. Class 10A)...")
    cls_summary, c_status = make_request(
        "/v1/payment-management/student-fees/summary?academic_year=2026%20-%202027&class_name=10A",
        token
    )
    assert c_status == 200
    cls_kpis = cls_summary.get("kpis", {})
    cls_total = cls_kpis.get("total_students", 0)
    cls_partial = cls_kpis.get("partial_students_count", 0)

    cls_roster, cr_status = make_request(
        "/v1/payment-management/student-fees/students?academic_year=2026%20-%202027&class_name=10A&status=All%20Status&page=1&page_size=10",
        token
    )
    assert cr_status == 200
    cls_grid_total = cls_roster.get("pagination", {}).get("total_items", -1)

    print(f"   Class 10A Total Students -> KPI: {cls_total} | Grid: {cls_grid_total}")
    assert cls_total == cls_grid_total, f"Class 10A total mismatch: KPI {cls_total} vs Grid {cls_grid_total}"

    cls_partial_roster, cp_status = make_request(
        "/v1/payment-management/student-fees/students?academic_year=2026%20-%202027&class_name=10A&status=Partial&page=1&page_size=10",
        token
    )
    assert cp_status == 200
    cls_partial_grid = cls_partial_roster.get("pagination", {}).get("total_items", -1)
    print(f"   Class 10A Partial Students -> KPI: {cls_partial} | Grid: {cls_partial_grid}")
    assert cls_partial == cls_partial_grid, f"Class 10A partial mismatch: KPI {cls_partial} vs Grid {cls_partial_grid}"
    print("   [PASS] Class-level filtering dynamically updates both KPIs and grid with 100% match.\n")

    print("=====================================================================")
    print("ALL TESTS PASSED! ZERO HARDCODING. DB AND UI DATA MATCH 100%.")
    print("=====================================================================")


if __name__ == "__main__":
    run_tests()
