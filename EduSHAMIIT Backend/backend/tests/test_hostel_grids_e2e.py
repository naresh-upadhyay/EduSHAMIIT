import time
import jwt
import pytest
import requests

BASE_URL = "http://127.0.0.1:8082/api"
DEFAULT_SCHOOL_ID = "11111111-1111-1111-1111-111111111111"
ADMIN_USER_ID = "5198c4b0-f1cb-45db-9649-41688d0438ba"
JWT_SECRET = "super-secret-jwt-token-with-at-least-32-characters-long"


def _auth_headers() -> dict:
    payload = {
        "sub": ADMIN_USER_ID,
        "role": "super_admin",
        "school_id": DEFAULT_SCHOOL_ID,
        "exp": int(time.time()) + 3600,
    }
    token = jwt.encode(payload, JWT_SECRET, algorithm="HS256")
    return {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }


HEADERS = _auth_headers()


def _assert_multipage_sort(
    endpoint: str,
    sort_by: str,
    value_extractor,
    extra_params: dict | None = None,
    list_key: str = "data",
    sort_order: str = "ASC",
):
    params_all = {"page": 1, "page_size": 100, "sort_by": sort_by, "sort_order": sort_order}
    params_p1 = {"page": 1, "page_size": 2, "sort_by": sort_by, "sort_order": sort_order}
    if extra_params:
        params_all.update(extra_params)
        params_p1.update(extra_params)

    res_all = requests.get(f"{BASE_URL}{endpoint}", params=params_all, headers=HEADERS, timeout=20)
    assert res_all.status_code == 200, f"{endpoint} sort_by={sort_by}: {res_all.text}"
    body_all = res_all.json()
    assert body_all.get("success") is True
    raw_all = body_all.get(list_key) or []
    rows_all = raw_all.get("items", []) if isinstance(raw_all, dict) else raw_all

    res_p1 = requests.get(f"{BASE_URL}{endpoint}", params=params_p1, headers=HEADERS, timeout=20)
    assert res_p1.status_code == 200
    raw_p1 = res_p1.json().get(list_key) or []
    rows_p1 = raw_p1.get("items", []) if isinstance(raw_p1, dict) else raw_p1
    assert len(rows_p1) == min(2, len(rows_all))

    if rows_all:
        assert [value_extractor(r) for r in rows_p1] == [
            value_extractor(r) for r in rows_all[: len(rows_p1)]
        ], f"{endpoint} sort_by={sort_by} page 1 does not match sorted dataset prefix"
    return rows_all


def test_hostel_rooms_sorting_and_pagination():
    for col in ["room_number", "room_type", "capacity", "occupied", "status", "facilities"]:
        _assert_multipage_sort("/hostel/rooms", col, lambda r: r.get("id"), sort_order="ASC")
        _assert_multipage_sort("/hostel/rooms", col, lambda r: r.get("id"), sort_order="DESC")


def test_hostel_students_sorting_pagination_export_and_bulk_action():
    for col in [
        "student_name",
        "roll_no",
        "class",
        "hostel",
        "room",
        "bed_no",
        "status",
        "fee_status",
    ]:
        _assert_multipage_sort(
            "/hostel/students",
            col,
            lambda r: r.get("admission_id") or r.get("id") or r.get("student_id"),
            sort_order="ASC",
        )
        _assert_multipage_sort(
            "/hostel/students",
            col,
            lambda r: r.get("admission_id") or r.get("id") or r.get("student_id"),
            sort_order="DESC",
        )

    # Bad bulk payloads -> 400
    bad_empty = requests.post(
        f"{BASE_URL}/hostel/students/bulk-action",
        json={"admission_ids": [], "action": "MARK_ON_LEAVE"},
        headers=HEADERS,
        timeout=15,
    )
    assert bad_empty.status_code == 400

    bad_action = requests.post(
        f"{BASE_URL}/hostel/students/bulk-action",
        json={"admission_ids": ["11111111-1111-1111-1111-111111111111"], "action": "INVALID"},
        headers=HEADERS,
        timeout=15,
    )
    assert bad_action.status_code == 400

    # Find an active student admission to test MARK_ON_LEAVE -> restore MARK_ACTIVE
    res = requests.get(
        f"{BASE_URL}/hostel/students",
        params={"page": 1, "page_size": 20, "status": "Active"},
        headers=HEADERS,
        timeout=15,
    )
    assert res.status_code == 200
    students = res.json().get("data") or []
    active = next((s for s in students if s.get("admission_id")), None)
    if active:
        adm_id = str(active["admission_id"])
        # Filtered export
        exp = requests.get(
            f"{BASE_URL}/hostel/students/export",
            params={"admission_ids": adm_id},
            headers=HEADERS,
            timeout=15,
        )
        assert exp.status_code == 200
        lines = [ln for ln in exp.text.strip().splitlines() if ln.strip()]
        assert len(lines) == 2  # header + 1 selected row

        try:
            r1 = requests.post(
                f"{BASE_URL}/hostel/students/bulk-action",
                json={"admission_ids": [adm_id], "action": "MARK_ON_LEAVE"},
                headers=HEADERS,
                timeout=15,
            )
            assert r1.status_code == 200, r1.text
            assert r1.json().get("affected_count") == 1
        finally:
            r2 = requests.post(
                f"{BASE_URL}/hostel/students/bulk-action",
                json={"admission_ids": [adm_id], "action": "MARK_ACTIVE"},
                headers=HEADERS,
                timeout=15,
            )
            assert r2.status_code == 200, r2.text
            assert r2.json().get("affected_count") == 1


def test_hostel_staff_sorting_and_pagination():
    for col in ["assigned_area", "contact"]:
        _assert_multipage_sort("/hostel/staff", col, lambda r: r.get("id"), sort_order="ASC")
        _assert_multipage_sort("/hostel/staff", col, lambda r: r.get("id"), sort_order="DESC")


def test_hostel_fees_and_subtabs_sorting_and_pagination():
    for col in [
        "student_name",
        "room_number",
        "plan_name",
        "total_billed",
        "total_paid",
        "balance_due",
        "fee_status",
    ]:
        _assert_multipage_sort(
            "/hostel/fees/students",
            col,
            lambda r: r.get("student_id") or r.get("id"),
            sort_order="ASC",
        )

    for col in ["code", "name", "room_type", "billing_cycle", "total_annual_amount", "status"]:
        _assert_multipage_sort("/hostel/fees/structures", col, lambda r: r.get("id"), sort_order="ASC")

    for col in [
        "invoice_number",
        "student_name",
        "billing_period",
        "net_amount",
        "paid_amount",
        "balance_amount",
        "status",
    ]:
        _assert_multipage_sort("/hostel/fees/invoices", col, lambda r: r.get("id"), sort_order="DESC")

    for col in ["receipt_number", "student_name", "amount", "payment_method", "payment_date", "status"]:
        _assert_multipage_sort("/hostel/fees/payments", col, lambda r: r.get("id"), sort_order="DESC")

    for col in ["student_name", "amount", "reason", "created_at", "status"]:
        _assert_multipage_sort("/hostel/fees/refunds", col, lambda r: r.get("id"), sort_order="DESC")


def test_hostel_leave_gate_passes_and_complaints_sorting():
    for col in [
        "request_number",
        "student_name",
        "hostel",
        "room_number",
        "request_type",
        "departure_date",
        "expected_return",
        "duration",
        "status",
        "created_at",
    ]:
        _assert_multipage_sort("/hostel/leave-outing", col, lambda r: r.get("id"), sort_order="ASC")

    for col in [
        "pass_number",
        "student_name",
        "hostel_name",
        "request_type",
        "valid_from",
        "valid_until",
        "status",
        "generated_at",
    ]:
        _assert_multipage_sort(
            "/hostel/leave-outing/gate-passes",
            col,
            lambda r: r.get("id"),
            sort_order="DESC",
        )

    for col in ["category", "hostel", "room_number", "reported_by"]:
        _assert_multipage_sort("/hostel/complaints", col, lambda r: r.get("id"), sort_order="ASC")
