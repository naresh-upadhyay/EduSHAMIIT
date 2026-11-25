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


def _get_with_retry(url: str, params: dict | None = None, attempts: int = 3):
    last_res = None
    for idx in range(attempts):
        last_res = requests.get(url, params=params, headers=HEADERS, timeout=20)
        if last_res.status_code != 503:
            return last_res
        time.sleep(0.4 * (idx + 1))
    return last_res


def test_live_classes_and_recordings_sorting():
    for sb, so in [
        ("scheduled_at", "ASC"),
        ("scheduled_at", "DESC"),
        ("class_name", "ASC"),
        ("subject_name", "ASC"),
        ("title", "DESC"),
        ("status", "ASC"),
        ("viewer_count", "DESC"),
    ]:
        r = _get_with_retry(
            f"{BASE_URL}/live-classes/sessions",
            {"date_filter": "all", "page": 1, "page_size": 10, "sort_by": sb, "sort_order": so},
        )
        assert r.status_code == 200, f"my-classes {sb}: {r.text}"

    for sb, so in [
        ("title", "ASC"),
        ("class_section", "ASC"),
        ("subject_name", "DESC"),
        ("created_at", "DESC"),
        ("duration", "DESC"),
        ("views", "DESC"),
        ("file_size", "DESC"),
        ("visibility", "ASC"),
        ("status", "ASC"),
    ]:
        r = _get_with_retry(
            f"{BASE_URL}/live-classes/recordings",
            {"page": 1, "page_size": 8, "sort_by": sb, "sort_order": so},
        )
        assert r.status_code == 200, f"recordings {sb}: {r.text}"


def test_payment_management_invoices_payments_payslips_sorting():
    for sb, so in [("invoice_number", "ASC"), ("student_name", "ASC"), ("due_date", "DESC"), ("total_billed", "DESC"), ("status", "ASC")]:
        r = _get_with_retry(
            f"{BASE_URL}/payment-management/student-fees/invoices-list",
            {"page": 1, "page_size": 10, "sort_by": sb, "sort_order": so},
        )
        assert r.status_code == 200, f"invoices-list {sb}: {r.text}"

    for sb, so in [("receipt_number", "ASC"), ("student_name", "ASC"), ("payment_date", "DESC"), ("amount_paid", "DESC"), ("status", "ASC")]:
        r = _get_with_retry(
            f"{BASE_URL}/payment-management/student-fees/payments-list",
            {"page": 1, "page_size": 10, "sort_by": sb, "sort_order": so},
        )
        assert r.status_code == 200, f"payments-list {sb}: {r.text}"

    for sb, so in [("payslip_number", "DESC"), ("name", "ASC"), ("gross", "DESC"), ("deductions", "DESC"), ("net", "ASC")]:
        r = _get_with_retry(
            f"{BASE_URL}/payment-management/staff-salary/payslips",
            {"month_str": "2026-10", "page": 1, "page_size": 10, "sort_by": sb, "sort_order": so},
        )
        assert r.status_code == 200, f"payslips {sb}: {r.text}"


def test_staff_attendance_sorting():
    for sb, so in [
        ("employee_code", "ASC"),
        ("full_name", "ASC"),
        ("full_name", "DESC"),
        ("department", "ASC"),
        ("status", "ASC"),
        ("check_in", "DESC"),
        ("check_out", "DESC"),
    ]:
        r = _get_with_retry(
            f"{BASE_URL}/attendance/staff",
            {"attendance_date": "2026-11-25", "page": 1, "page_size": 10, "sort_by": sb, "sort_order": so},
        )
        assert r.status_code == 200, f"staff attendance {sb}: {r.text}"


def test_work_management_items_teams_capacity_sorting():
    for col, d in [
        ("item_number", "ASC"),
        ("title", "ASC"),
        ("work_type", "ASC"),
        ("priority", "DESC"),
        ("status", "ASC"),
        ("due_date", "ASC"),
        ("progress", "DESC"),
    ]:
        r = _get_with_retry(
            f"{BASE_URL}/work/items",
            {"page": 1, "page_size": 10, "sort_col": col, "sort_dir": d},
        )
        assert r.status_code == 200, f"/work/items {col}: {r.text}"

    for sb in ["NAME_ASC", "NAME_DESC", "DEPT_ASC", "DEPT_DESC", "MEMBERS_DESC", "MEMBERS_ASC", "STATUS_ASC", "STATUS_DESC"]:
        r = _get_with_retry(
            f"{BASE_URL}/work/teams",
            {"page": 1, "limit": 10, "sort_by": sb},
        )
        assert r.status_code == 200, f"/work/teams {sb}: {r.text}"

    # Verify sprints capacity sorting
    sprints_res = _get_with_retry(f"{BASE_URL}/work/sprints")
    assert sprints_res.status_code == 200
    sprints = sprints_res.json().get("sprints") or sprints_res.json().get("data") or []
    if sprints:
        sid = sprints[0]["id"]
        for sb, so in [("name", "asc"), ("work_items", "desc"), ("utilization", "desc")]:
            cap_res = _get_with_retry(
                f"{BASE_URL}/work/sprints/{sid}/capacity",
                {"page": 1, "limit": 10, "sort_by": sb, "sort_order": so},
            )
            assert cap_res.status_code == 200, f"capacity {sb}: {cap_res.text}"
