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


def test_notices_sorting_pagination_and_bulk_action():
    for sort_by, sort_order in [
        ("title", "ASC"),
        ("title", "DESC"),
        ("category", "ASC"),
        ("priority", "DESC"),
        ("published_at", "DESC"),
        ("view_count", "DESC"),
    ]:
        res_all = _get_with_retry(
            f"{BASE_URL}/notices",
            {"page": 1, "page_size": 50, "sort_by": sort_by, "sort_order": sort_order},
        )
        assert res_all.status_code == 200, f"notices sort_by={sort_by}: {res_all.text}"
        body_all = res_all.json()
        rows_all = body_all.get("data") or body_all.get("notices") or []
        if len(rows_all) >= 2:
            res_p1 = _get_with_retry(
                f"{BASE_URL}/notices",
                {"page": 1, "page_size": 2, "sort_by": sort_by, "sort_order": sort_order},
            )
            assert res_p1.status_code == 200
            rows_p1 = res_p1.json().get("data") or res_p1.json().get("notices") or []
            assert [r["id"] for r in rows_p1] == [r["id"] for r in rows_all[:2]]

    # Empty bulk action validation
    res_empty = requests.post(
        f"{BASE_URL}/notices/bulk-action",
        json={"notice_ids": [], "action": "publish"},
        headers=HEADERS,
        timeout=15,
    )
    assert res_empty.status_code in (400, 422)


def test_lookups_keys_and_values_pagination_and_sorting():
    res_keys = _get_with_retry(
        f"{BASE_URL}/lookups",
        {"page": 1, "page_size": 5, "sort_by": "key_name", "sort_order": "ASC"},
    )
    assert res_keys.status_code == 200, res_keys.text
    keys_body = res_keys.json()
    keys_list = keys_body.get("data") or keys_body.get("keys") or []
    assert len(keys_list) <= 5
    if keys_list:
        lookup_id = keys_list[0]["id"]
        for sb, so in [("value_name", "ASC"), ("value_name", "DESC"), ("sort_order", "ASC")]:
            res_vals = _get_with_retry(
                f"{BASE_URL}/lookups/{lookup_id}/values",
                {"page": 1, "page_size": 5, "sort_by": sb, "sort_order": so},
            )
            assert res_vals.status_code == 200, f"lookup values {sb}: {res_vals.text}"


def test_classes_sections_subjects_rooms_sorting():
    res_cls = _get_with_retry(
        f"{BASE_URL}/classes",
        {"page": 1, "page_size": 10, "sort_by": "name", "sort_order": "ASC"},
    )
    assert res_cls.status_code == 200, res_cls.text

    for endpoint, sorts in [
        ("/classes/sections/all", [("name", "ASC"), ("students_count", "DESC"), ("status", "ASC")]),
        ("/classes/subjects/all", [("name", "ASC"), ("type", "DESC"), ("status", "ASC")]),
        ("/classes/rooms", [("name", "ASC"), ("type", "ASC"), ("building", "ASC"), ("status", "DESC")]),
    ]:
        for sb, so in sorts:
            r = _get_with_retry(
                f"{BASE_URL}{endpoint}",
                {"page": 1, "page_size": 10, "sort_by": sb, "sort_order": so},
            )
            assert r.status_code == 200, f"{endpoint} {sb} {so}: {r.text}"


def test_exams_and_question_bank_sorting_and_bulk():
    for sb, so in [("title", "asc"), ("type", "asc"), ("status", "desc")]:
        r = _get_with_retry(
            f"{BASE_URL}/exams",
            {"page": 1, "page_size": 10, "sort_by": sb, "sort_order": so},
        )
        assert r.status_code == 200, f"/exams {sb}: {r.text}"

    for sb, so in [
        ("question_text", "asc"),
        ("subject", "asc"),
        ("difficulty", "desc"),
        ("marks", "desc"),
    ]:
        r = _get_with_retry(
            f"{BASE_URL}/question-bank",
            {"page": 1, "page_size": 10, "sort_by": sb, "sort_order": so},
        )
        assert r.status_code == 200, f"/question-bank {sb}: {r.text}"

    # Create 2 temporary questions -> bulk approve -> verify -> bulk delete
    q_ids = []
    for idx in range(2):
        create_res = requests.post(
            f"{BASE_URL}/question-bank",
            json={
                "question_text": f"Batch3 E2E Temp Q{idx}",
                "question_type": "mcq",
                "difficulty": "easy",
                "marks": 2,
                "class_name": "Class 10",
                "subject": "Mathematics",
                "options": ["A", "B"],
                "correct_answer": "A",
            },
            headers=HEADERS,
            timeout=15,
        )
        assert create_res.status_code == 200, create_res.text
        created = create_res.json().get("data") or {}
        if created.get("id"):
            q_ids.append(created["id"])

    if q_ids:
        try:
            bulk_app = requests.post(
                f"{BASE_URL}/question-bank/bulk-action",
                json={"question_ids": q_ids, "action": "BULK_APPROVE"},
                headers=HEADERS,
                timeout=15,
            )
            assert bulk_app.status_code == 200, bulk_app.text
            assert bulk_app.json().get("affected_count") == len(q_ids)

            bulk_diff = requests.post(
                f"{BASE_URL}/question-bank/bulk-action",
                json={"question_ids": q_ids, "action": "BULK_CHANGE_DIFFICULTY", "difficulty": "medium"},
                headers=HEADERS,
                timeout=15,
            )
            assert bulk_diff.status_code == 200, bulk_diff.text
        finally:
            bulk_del = requests.post(
                f"{BASE_URL}/question-bank/bulk-action",
                json={"question_ids": q_ids, "action": "BULK_DELETE"},
                headers=HEADERS,
                timeout=15,
            )
            assert bulk_del.status_code == 200, bulk_del.text
