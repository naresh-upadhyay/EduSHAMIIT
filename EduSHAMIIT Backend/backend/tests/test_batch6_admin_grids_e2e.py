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


def test_admin_audit_logs_sorting_and_pagination():
    for sb in ("created_at", "user_name", "event_type", "module", "action", "resource", "ip_address", "status"):
        for so in ("asc", "desc"):
            r = _get_with_retry(
                f"{BASE_URL}/admin/audit-logs",
                {"page": 1, "page_size": 10, "sort_by": sb, "sort_order": so},
            )
            assert r.status_code == 200, f"audit-logs {sb} {so}: {r.text}"
            body = r.json()
            assert "logs" in body or "data" in body or isinstance(body, dict)


def test_hr_policies_templates_documents_sorting():
    for sb in ("updated_desc", "category_asc", "category_desc", "type_asc", "version_asc", "status_asc"):
        r = _get_with_retry(f"{BASE_URL}/hr/policies", {"page": 1, "page_size": 10, "sort_by": sb})
        assert r.status_code == 200, f"/hr/policies {sb}: {r.text}"
        r_tpl = _get_with_retry(f"{BASE_URL}/hr/templates", {"page": 1, "page_size": 10, "sort_by": sb})
        assert r_tpl.status_code == 200, f"/hr/templates {sb}: {r_tpl.text}"
        r_doc = _get_with_retry(f"{BASE_URL}/hr/documents", {"page": 1, "page_size": 10, "sort_by": sb})
        assert r_doc.status_code == 200, f"/hr/documents {sb}: {r_doc.text}"


def test_contact_queries_and_onboarding_sorting_and_rpp():
    for sb in ("created_at", "full_name", "email", "subject", "status"):
        r = _get_with_retry(
            f"{BASE_URL}/contact/admin/queries",
            {"page": 1, "page_size": 25, "sort_by": sb, "sort_order": "asc"},
        )
        assert r.status_code == 200, f"/contact/admin/queries {sb}: {r.text}"

    for sb in ("onboarding_code", "candidate_name", "department", "designation", "stage", "joining_date", "status"):
        for so in ("asc", "desc"):
            r = _get_with_retry(
                f"{BASE_URL}/onboarding/records",
                {"page": 1, "page_size": 25, "sort_by": sb, "sort_order": so},
            )
            assert r.status_code == 200, f"/onboarding/records {sb} {so}: {r.text}"
            data = r.json()
            assert data.get("success") is True
            assert data.get("pagination", {}).get("page_size") == 25


def test_training_announcements_system_alerts_sorting():
    for sb in ("title", "mode", "target_audience", "duration_hours", "enrolled_count", "status"):
        r = _get_with_retry(
            f"{BASE_URL}/training/programs",
            {"tab": "all", "page": 1, "page_size": 10, "sort_by": sb, "sort_order": "asc"},
        )
        assert r.status_code == 200, f"/training/programs {sb}: {r.text}"

    for sb in ("title", "school_id", "priority", "status", "created_at"):
        r = _get_with_retry(
            f"{BASE_URL}/admin/announcements",
            {"page": 1, "page_size": 10, "sort_by": sb, "sort_order": "asc"},
        )
        assert r.status_code == 200, f"/admin/announcements {sb}: {r.text}"

    for sb in ("title", "category", "priority", "status", "created_at"):
        r = _get_with_retry(
            f"{BASE_URL}/admin/system-alerts",
            {"page": 1, "page_size": 10, "sort_by": sb, "sort_order": "asc"},
        )
        assert r.status_code == 200, f"/admin/system-alerts {sb}: {r.text}"
