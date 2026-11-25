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


def test_device_live_control_and_import_export_sorting():
    for sb, so in [("power", "asc"), ("power_state", "desc"), ("device_name", "asc"), ("status", "desc")]:
        r = _get_with_retry(
            f"{BASE_URL}/v1/devices/live-control/devices",
            {"page": 1, "page_size": 10, "sort_by": sb, "sort_order": so},
        )
        assert r.status_code == 200, f"live-control {sb}: {r.text}"

    for sb, sa in [("file_name", True), ("success", False), ("failed", False), ("duration", True), ("started_at", False)]:
        r = _get_with_retry(
            f"{BASE_URL}/v1/devices/import-export/history",
            {"page": 1, "page_size": 10, "sort_by": sb, "sort_asc": sa},
        )
        assert r.status_code == 200, f"import-export {sb}: {r.text}"


def test_device_gateways_schedules_scenes_audit_logs_sorting():
    for sb, sd in [("connected_devices_count", "desc"), ("connected_devices_count", "asc"), ("protocols", "asc"), ("gateway_name", "asc")]:
        r = _get_with_retry(
            f"{BASE_URL}/v1/devices/integrations-gateways/gateways",
            {"limit": 10, "offset": 0, "sort_by": sb, "sort_dir": sd},
        )
        assert r.status_code == 200, f"gateways {sb}: {r.text}"

    for sb, sd in [("name", "asc"), ("target", "asc"), ("operation", "asc"), ("status", "desc")]:
        r = _get_with_retry(
            f"{BASE_URL}/v1/devices/schedules",
            {"limit": 10, "offset": 0, "sort_by": sb, "sort_dir": sd},
        )
        assert r.status_code == 200, f"schedules {sb}: {r.text}"

    for sb, sd in [("name", "asc"), ("type", "asc"), ("targets", "desc"), ("status", "asc")]:
        r = _get_with_retry(
            f"{BASE_URL}/v1/devices/scenes-presets",
            {"page": 1, "page_size": 10, "sort_by": sb, "sort_dir": sd},
        )
        assert r.status_code == 200, f"scenes {sb}: {r.text}"

    for sb, so in [("occurred_at", "desc"), ("actor_name", "asc"), ("event_type", "asc"), ("result", "desc")]:
        r = _get_with_retry(
            f"{BASE_URL}/v1/devices/audit-logs",
            {"page": 1, "page_size": 10, "sort_by": sb, "sort_order": so},
        )
        assert r.status_code == 200, f"audit-logs {sb}: {r.text}"


def test_campus_facilities_and_utilities_sorting():
    for sb, so in [("name", "asc"), ("category", "asc"), ("capacity", "desc"), ("status", "asc")]:
        r = _get_with_retry(
            f"{BASE_URL}/v1/campus/facilities",
            {"page": 1, "page_size": 10, "sort_by": sb, "sort_order": so},
        )
        assert r.status_code == 200, f"facilities {sb}: {r.text}"

    for sb, so in [("recorded_at", "desc"), ("utility_name", "asc"), ("reading_value", "desc"), ("status", "asc")]:
        r = _get_with_retry(
            f"{BASE_URL}/v1/campus/utilities/readings",
            {"page": 1, "page_size": 10, "sort_by": sb, "sort_order": so},
        )
        assert r.status_code == 200, f"utilities {sb}: {r.text}"
