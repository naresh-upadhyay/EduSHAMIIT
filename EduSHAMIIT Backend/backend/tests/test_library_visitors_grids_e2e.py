import time
import jwt
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


def _extract_rows(body: dict, list_key: str):
    raw = body.get(list_key)
    if isinstance(raw, list):
        return raw
    if isinstance(raw, dict):
        for k in ("items", "records", "data"):
            if isinstance(raw.get(k), list):
                return raw[k]
    return body.get("data") or body.get("items") or body.get("records") or []


def _get_with_retry(url: str, params: dict):
    for attempt in range(4):
        res = requests.get(url, params=params, headers=HEADERS, timeout=20)
        if res.status_code != 503:
            return res
        time.sleep(0.5 * (attempt + 1))
    return res


def _assert_multipage_sort(
    endpoint: str,
    sort_by: str,
    sort_order: str = "ASC",
    list_key: str = "data",
    extra_params: dict | None = None,
):
    params_all = {"page": 1, "page_size": 100, "sort_by": sort_by, "sort_order": sort_order}
    params_p1 = {"page": 1, "page_size": 2, "sort_by": sort_by, "sort_order": sort_order}
    if extra_params:
        params_all.update(extra_params)
        params_p1.update(extra_params)

    res_all = _get_with_retry(f"{BASE_URL}{endpoint}", params_all)
    assert res_all.status_code == 200, f"{endpoint} sort_by={sort_by}: {res_all.text}"
    rows_all = _extract_rows(res_all.json(), list_key)

    res_p1 = _get_with_retry(f"{BASE_URL}{endpoint}", params_p1)
    assert res_p1.status_code == 200, f"{endpoint} page1 sort_by={sort_by}: {res_p1.text}"
    rows_p1 = _extract_rows(res_p1.json(), list_key)

    assert len(rows_p1) == min(2, len(rows_all))
    if rows_all:
        assert [r.get("id") for r in rows_p1] == [
            r.get("id") for r in rows_all[: len(rows_p1)]
        ], f"{endpoint} sort_by={sort_by} order={sort_order} page 1 mismatch"


def test_library_books_sorting_and_bulk_validation():
    for col in ["title", "author", "category", "total_copies", "available_copies", "created_at"]:
        _assert_multipage_sort("/library/books", col, "ASC")
        _assert_multipage_sort("/library/books", col, "DESC")

    bad = requests.post(
        f"{BASE_URL}/library/books/bulk",
        json={"book_ids": [], "action": "ARCHIVE"},
        headers=HEADERS,
        timeout=15,
    )
    assert bad.status_code == 400


def test_library_members_sorting_and_bulk_validation():
    for col in [
        "member_code",
        "member_name",
        "member_type",
        "class",
        "books_issued",
        "outstanding_fine",
        "status",
    ]:
        _assert_multipage_sort("/library/members", col, "ASC")
        _assert_multipage_sort("/library/members", col, "DESC")

    bad = requests.post(
        f"{BASE_URL}/library/members/bulk-action",
        json={"member_ids": [], "action": "ACTIVATE"},
        headers=HEADERS,
        timeout=15,
    )
    assert bad.status_code == 400


def test_library_transactions_joined_sorting_and_bulk():
    # Previously crashed with SQL column error on member_name and book_title
    for col in [
        "transaction_code",
        "member_name",
        "book_title",
        "issue_date",
        "due_date",
        "return_date",
        "status",
        "fine_amount",
        "transaction_type",
        "created_at",
    ]:
        _assert_multipage_sort("/library/transactions", col, "ASC")
        _assert_multipage_sort("/library/transactions", col, "DESC")

    bad = requests.post(
        f"{BASE_URL}/library/transactions/bulk-action",
        json={"borrow_ids": [], "action": "SEND_REMINDER"},
        headers=HEADERS,
        timeout=15,
    )
    assert bad.status_code == 400

    res = requests.get(
        f"{BASE_URL}/library/transactions",
        params={"page": 1, "page_size": 1},
        headers=HEADERS,
        timeout=15,
    )
    assert res.status_code == 200
    items = _extract_rows(res.json(), "data")
    if items:
        tx_id = items[0]["id"]
        ok = requests.post(
            f"{BASE_URL}/library/transactions/bulk-action",
            json={"borrow_ids": [tx_id], "action": "SEND_REMINDER"},
            headers=HEADERS,
            timeout=15,
        )
        assert ok.status_code == 200, ok.text
        assert ok.json().get("success") is True


def test_library_requests_all_columns_sorting():
    for col in [
        "request_number",
        "title",
        "request_type",
        "requester_name",
        "priority",
        "status",
        "created_at",
        "updated_at",
    ]:
        _assert_multipage_sort("/library/requests", col, "ASC")
        _assert_multipage_sort("/library/requests", col, "DESC")


def test_visitors_all_tabs_aligned_sorting():
    for col in [
        "visitor_name",
        "visitor_type",
        "purpose",
        "destination",
        "host_name",
        "check_in_at",
        "expected_out_at",
        "status",
    ]:
        _assert_multipage_sort("/visitors/visits", col, "ASC", list_key="records")
        _assert_multipage_sort("/visitors/visits", col, "DESC", list_key="records")

    for col in [
        "visitor_name",
        "visitor_type",
        "purpose",
        "destination",
        "host_name",
        "scheduled_start_at",
        "status",
    ]:
        _assert_multipage_sort("/visitors/appointments", col, "ASC", list_key="records")
        _assert_multipage_sort("/visitors/appointments", col, "DESC", list_key="records")

    for col in [
        "visitor_name",
        "id_number_masked",
        "phone",
        "reason_category",
        "scope_name",
        "blocked_on",
        "valid_till",
        "status",
    ]:
        _assert_multipage_sort("/visitors/restrictions", col, "ASC", list_key="records")
        _assert_multipage_sort("/visitors/restrictions", col, "DESC", list_key="records")
