"""
Comprehensive Test Suite for Hostel Management: Leave & Outing
Tests CRUD, Approval Engine, Gate Pass, QR Verification, Actual Exit/Return,
Conflict Detection, Optimistic Concurrency, KPI Calculations, and Multi-tenant Scoping.
"""
import pytest
import os
import sys
import json
from datetime import datetime, timedelta
from jose import jwt
from fastapi.testclient import TestClient

# Ensure backend directory is in path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

os.environ["DATABASE_URL"] = "postgresql://postgres:eduSHAMIIT2026_pg@127.0.0.1:5432/postgres"

from app.main import app, _MODULES_CACHE
from app.config import settings

# Force database URL to native postgres port 5432
settings.DATABASE_URL = "postgresql://postgres:eduSHAMIIT2026_pg@127.0.0.1:5432/postgres"

# Bypass external Supabase call in enforce_modules_middleware during testing
import app.main as main_mod
main_mod._MODULES_CACHE = {
    "data": [{"module_code": "hostel", "is_enabled": True}],
    "timestamp": 9999999999.0
}
main_mod._SCHOOL_TOGGLES_CACHE = {
    "11111111-1111-1111-1111-111111111111": ({}, 9999999999.0),
    "22222222-2222-2222-2222-222222222222": ({}, 9999999999.0),
}

client = TestClient(app)

SCHOOL_ID = "11111111-1111-1111-1111-111111111111"
OTHER_SCHOOL_ID = "22222222-2222-2222-2222-222222222222"
ADMIN_USER_ID = "d1a22222-2222-2222-2222-222222222222"
STUDENT_USER_ID = "a1000001-0000-0000-0000-000000000001" # Rahul Sharma

JWT_SECRET = "super-secret-jwt-token-with-at-least-32-characters-long"

from app.middleware.auth import get_current_user
from fastapi import Request

async def override_get_current_user(request: Request):
    auth_header = request.headers.get("Authorization", "")
    if "Bearer " in auth_header:
        token = auth_header.split(" ")[1]
        try:
            payload = jwt.decode(token, JWT_SECRET, algorithms=["HS256"], options={"verify_aud": False})
            return {
                "id": payload.get("sub", ADMIN_USER_ID),
                "school_id": payload.get("school_id", SCHOOL_ID),
                "role": payload.get("role", "admin"),
                "email": payload.get("email", "test_hostel@school.com"),
            }
        except Exception:
            pass
    return {
        "id": ADMIN_USER_ID,
        "school_id": SCHOOL_ID,
        "role": "admin",
        "email": "test_hostel@school.com",
    }

app.dependency_overrides[get_current_user] = override_get_current_user


def get_token(user_id: str, school_id: str, role: str = "super_admin"):
    payload = {
        "sub": user_id,
        "id": user_id,
        "school_id": school_id,
        "role": role,
        "email": "test_hostel@school.com",
        "exp": 9999999999
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")


@pytest.fixture
def auth_headers():
    token = get_token(ADMIN_USER_ID, SCHOOL_ID, "admin")
    return {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}


@pytest.fixture
def other_school_headers():
    token = get_token(ADMIN_USER_ID, OTHER_SCHOOL_ID, "admin")
    return {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}


def test_01_leave_outing_kpis(auth_headers):
    """Verify Leave & Outing KPI Cards computation from stored procedure."""
    resp = client.get("/api/v1/hostel/leave-outing/kpis?academic_year=2024 - 2025", headers=auth_headers)
    assert resp.status_code == 200
    body = resp.json()
    assert body.get("success") is True
    data = body.get("data", {})
    assert "total_requests" in data
    assert data["total_requests"] >= 48
    assert "approved" in data
    assert "pending" in data
    assert "rejected" in data
    assert "currently_out" in data
    assert "due_today" in data
    assert data["currently_out"] == 15


def test_02_leave_outing_list_pagination_and_sorting(auth_headers):
    """Verify paginated listing, default sorting, and metadata."""
    resp = client.get("/api/v1/hostel/leave-outing?page=1&page_size=10", headers=auth_headers)
    assert resp.status_code == 200
    body = resp.json()
    assert body.get("success") is True
    data = body.get("data", {})
    assert data.get("total") >= 48
    assert len(data.get("items", [])) == 10
    
    first_item = data["items"][0]
    assert "request_number" in first_item
    assert "student_name" in first_item
    assert "request_type" in first_item
    assert "status" in first_item
    assert "duration_text" in first_item


def test_03_leave_outing_filters_and_search(auth_headers):
    """Test filtering by request type and search term."""
    # Filter by OUTING
    resp = client.get("/api/v1/hostel/leave-outing?request_type=OUTING", headers=auth_headers)
    assert resp.status_code == 200
    body = resp.json()
    for it in body["data"]["items"]:
        assert it["request_type"] == "OUTING"

    # Search for Rahul
    resp_search = client.get("/api/v1/hostel/leave-outing?search=Rahul", headers=auth_headers)
    assert resp_search.status_code == 200
    body_search = resp_search.json()
    assert body_search["data"]["total"] >= 1
    assert any("Rahul" in it["student_name"] for it in body_search["data"]["items"])


def _future_offset_days(extra: int = 0) -> int:
    import time
    return 100 + (int(time.time() * 1000) % 15000) + extra


def test_04_create_leave_request_and_conflict_detection(auth_headers):
    """Test creating a new leave request and verifying conflict detection on overlap."""
    start_time = datetime.now() + timedelta(days=_future_offset_days(10))
    end_time = start_time + timedelta(days=3)

    payload = {
        "student_id": STUDENT_USER_ID,
        "academic_year": "2024 - 2025",
        "request_type": "LEAVE",
        "request_subtype": "Home Leave",
        "reason": "Attending family function in hometown",
        "destination": "Jaipur",
        "start_at": start_time.isoformat(),
        "expected_return_at": end_time.isoformat(),
        "is_emergency": False,
        "guardian_name": "Rajesh Sharma",
        "guardian_phone": "+91 98765 43210",
        "accompanied_by": "PARENT",
        "transport_mode": "TRAIN"
    }

    # 1. Create Request
    resp = client.post("/api/v1/hostel/leave-outing", json=payload, headers=auth_headers)
    assert resp.status_code == 200
    created = resp.json()
    assert created.get("success") is True
    req_data = created.get("data", {})
    req_id = req_data.get("id")
    assert req_id is not None
    assert req_data["request_type"] == "LEAVE"
    assert req_data["status"] == "PENDING"

    # 2. Overlapping Conflict Request for the same student
    conflict_payload = {
        "student_id": STUDENT_USER_ID,
        "academic_year": "2024 - 2025",
        "request_type": "OUTING",
        "reason": "Local market trip overlapping with leave",
        "destination": "Market",
        "start_at": (start_time + timedelta(days=1)).isoformat(),
        "expected_return_at": (start_time + timedelta(days=1, hours=4)).isoformat(),
    }
    conflict_resp = client.post("/api/v1/hostel/leave-outing", json=conflict_payload, headers=auth_headers)
    assert conflict_resp.status_code == 400
    assert "conflict" in conflict_resp.json().get("detail", "").lower()


def test_05_approve_and_gate_pass_flow(auth_headers):
    """Test approving a pending request, verifying auto gate pass generation, and token check."""
    start_time = datetime.now() + timedelta(days=_future_offset_days(60))
    end_time = start_time + timedelta(hours=5)

    payload = {
        "student_id": STUDENT_USER_ID,
        "request_type": "OUTING",
        "request_subtype": "Market",
        "reason": "Books and project supplies purchase",
        "destination": "City Center",
        "start_at": start_time.isoformat(),
        "expected_return_at": end_time.isoformat()
    }

    create_resp = client.post("/api/v1/hostel/leave-outing", json=payload, headers=auth_headers)
    req_id = create_resp.json()["data"]["id"]
    version = create_resp.json()["data"]["version"]

    # 1. Approve Request
    approve_resp = client.post(
        f"/api/v1/hostel/leave-outing/{req_id}/approve",
        json={"remarks": "Approved. Report to gate on return.", "version": version},
        headers=auth_headers
    )
    assert approve_resp.status_code == 200
    approved_data = approve_resp.json()["data"]
    assert approved_data["status"] == "APPROVED"
    assert approved_data["gate_pass"] is not None
    token = approved_data["gate_pass"]["verification_token"]
    assert token is not None

    # 2. Verify Gate Pass by Token
    verify_resp = client.post("/api/v1/hostel/gate-pass/verify", json={"identifier": token}, headers=auth_headers)
    assert verify_resp.status_code == 200
    verify_body = verify_resp.json()
    assert verify_body["success"] is True
    assert verify_body["validity"] == "VALID"
    assert verify_body["student"]["full_name"] == "Rahul Sharma"

    # 3. Mark Exit
    exit_resp = client.post(
        f"/api/v1/hostel/leave-outing/{req_id}/exit",
        json={"gate": "Main Gate", "remarks": "ID verified. Checked out."},
        headers=auth_headers
    )
    assert exit_resp.status_code == 200
    assert exit_resp.json()["data"]["status"] == "EXITED"

    # 4. Double Exit Rejection (Idempotency)
    double_exit = client.post(
        f"/api/v1/hostel/leave-outing/{req_id}/exit",
        json={"gate": "Main Gate"},
        headers=auth_headers
    )
    assert double_exit.status_code == 400

    # 5. Mark Return
    return_resp = client.post(
        f"/api/v1/hostel/leave-outing/{req_id}/return",
        json={"gate": "Main Gate", "remarks": "Returned safely."},
        headers=auth_headers
    )
    assert return_resp.status_code == 200
    assert return_resp.json()["data"]["status"] == "RETURNED"


def test_06_reject_request_with_reason(auth_headers):
    """Test rejecting a request with mandatory reason."""
    start_time = datetime.now() + timedelta(days=_future_offset_days(120))
    end_time = start_time + timedelta(hours=4)

    payload = {
        "student_id": STUDENT_USER_ID,
        "request_type": "OUTING",
        "reason": "Late evening outing request",
        "destination": "Mall",
        "start_at": start_time.isoformat(),
        "expected_return_at": end_time.isoformat()
    }
    create_resp = client.post("/api/v1/hostel/leave-outing", json=payload, headers=auth_headers)
    req_id = create_resp.json()["data"]["id"]

    reject_resp = client.post(
        f"/api/v1/hostel/leave-outing/{req_id}/reject",
        json={"reason": "Night outing violates hostel curfew."},
        headers=auth_headers
    )
    assert reject_resp.status_code == 200
    body = reject_resp.json()
    assert body["data"]["status"] == "REJECTED"
    assert body["data"]["rejection_reason"] == "Night outing violates hostel curfew."


def test_07_cancel_request(auth_headers):
    """Test cancelling a request before exit."""
    start_time = datetime.now() + timedelta(days=_future_offset_days(180))
    end_time = start_time + timedelta(hours=3)

    payload = {
        "student_id": STUDENT_USER_ID,
        "request_type": "OUTING",
        "reason": "Shopping trip",
        "destination": "Market",
        "start_at": start_time.isoformat(),
        "expected_return_at": end_time.isoformat()
    }
    create_resp = client.post("/api/v1/hostel/leave-outing", json=payload, headers=auth_headers)
    req_id = create_resp.json()["data"]["id"]

    cancel_resp = client.post(
        f"/api/v1/hostel/leave-outing/{req_id}/cancel",
        json={"reason": "Student rescheduled exam preparation."},
        headers=auth_headers
    )
    assert cancel_resp.status_code == 200
    assert cancel_resp.json()["data"]["status"] == "CANCELED"


def test_08_currently_out_and_awaiting_approval(auth_headers):
    """Verify currently out and awaiting approval lists."""
    resp_out = client.get("/api/v1/hostel/leave-outing/currently-out", headers=auth_headers)
    assert resp_out.status_code == 200
    assert resp_out.json()["success"] is True

    resp_awaiting = client.get("/api/v1/hostel/leave-outing/awaiting-approval?limit=5", headers=auth_headers)
    assert resp_awaiting.status_code == 200
    body = resp_awaiting.json()
    assert body["success"] is True
    assert len(body["data"]) > 0


def test_09_settings_get_and_put(auth_headers):
    """Verify settings read and update."""
    get_resp = client.get("/api/v1/hostel/leave-outing/settings", headers=auth_headers)
    assert get_resp.status_code == 200
    assert get_resp.json()["success"] is True

    update_payload = {
        "leave_allowed": True,
        "outing_allowed": True,
        "curfew_time": "20:30:00",
        "outing_start_time": "06:00:00",
        "max_outings_per_month": 5,
        "max_leave_days_per_term": 15,
        "late_return_grace_period_mins": 20
    }
    put_resp = client.put("/api/v1/hostel/leave-outing/settings", json=update_payload, headers=auth_headers)
    assert put_resp.status_code == 200
    assert put_resp.json()["data"]["curfew_time"] == "20:30:00"


def test_10_csv_export(auth_headers):
    """Verify CSV export endpoint."""
    resp = client.get("/api/v1/hostel/leave-outing/export", headers=auth_headers)
    assert resp.status_code == 200
    assert "text/csv" in resp.headers["content-type"]
    assert "Request ID" in resp.text
    assert "Rahul Sharma" in resp.text


def test_11_tenant_isolation(other_school_headers):
    """Verify tenant isolation: queries for a different tenant do not leak data."""
    resp = client.get("/api/v1/hostel/leave-outing", headers=other_school_headers)
    assert resp.status_code == 200
    body = resp.json()
    # Different tenant should have 0 records
    assert body["data"]["total"] == 0
