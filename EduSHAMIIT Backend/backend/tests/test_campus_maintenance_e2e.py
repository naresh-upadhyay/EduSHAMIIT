import os
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import pytest
from fastapi.testclient import TestClient
from datetime import date, datetime
from app.main import app
from app.middleware.auth import get_current_user

# Setup test auth override
app.dependency_overrides[get_current_user] = lambda: {
    "id": "11111111-1111-1111-1111-111111111111",
    "school_id": "11111111-1111-1111-1111-111111111111",
    "full_name": "Admin Tester",
    "role": "Super Admin"
}

client = TestClient(app)

def test_maintenance_kpis_endpoint():
    """Verify live maintenance KPIs match the Greenwood High School target figures."""
    resp = client.get("/api/v1/maintenance/kpis")
    assert resp.status_code == 200
    data = resp.json()
    assert data["total_requests"] == 312
    assert data["resolved"] == 254
    assert data["resolved_pct"] == 81.4
    assert data["in_progress"] == 34
    assert data["in_progress_pct"] == 10.9
    assert data["overdue"] == 12
    assert data["overdue_pct"] == 3.8
    assert data["scheduled"] == 28
    assert data["avg_resolution_days"] == 1.8

def test_maintenance_requests_listing():
    """Verify paginated requests table returns 10 rows and Row 1 is MT-0568 AC not cooling."""
    resp = client.get("/api/v1/maintenance/requests?page=1&page_size=10")
    assert resp.status_code == 200
    data = resp.json()
    assert data["total_count"] == 312
    assert len(data["records"]) == 10
    
    row1 = data["records"][0]
    assert row1["request_code"] == "MT-0568"
    assert row1["title"] == "AC not cooling"
    assert row1["location_display"] == "B1 / G-101"
    assert row1["request_type"] == "HVAC"
    assert row1["priority"] == "High"
    assert row1["status"] == "In Progress"

def test_maintenance_requests_filtering():
    """Verify filtering by type=HVAC works accurately."""
    resp = client.get("/api/v1/maintenance/requests?type=HVAC&page=1&page_size=10")
    assert resp.status_code == 200
    data = resp.json()
    assert data["total_count"] > 0
    for r in data["records"]:
        assert "HVAC" in r["request_type"]

def test_maintenance_analytics_endpoint():
    """Verify monthly trends, category donut breakdown, and SLA metrics."""
    resp = client.get("/api/v1/maintenance/analytics")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["trends"]) == 7
    assert data["trends"][0]["month"] == "Sep"
    assert data["trends"][-1]["month"] == "Mar"
    
    assert len(data["categories"]) >= 5
    assert data["categories"][0]["type"] == "HVAC (AC)"
    assert data["categories"][0]["pct"] == 26.9
    
    assert data["sla"]["resolution_within_sla_pct"] == 81.4
    assert data["sla"]["avg_resolution_days"] == 1.8
    assert data["sla"]["overdue_rate_pct"] == 3.8

def test_maintenance_create_and_status_transition():
    """Verify end-to-end work order creation, status update, and detail retrieval."""
    # 1. Create request
    create_payload = {
        "title": "Lab 2 Fume Hood Exhaust Fan Vibration",
        "description": "High pitch vibration during chemistry lab experiment.",
        "request_type": "HVAC",
        "priority": "High",
        "location_display": "B1 / Lab-2",
        "reported_by_name": "Dr. Chemistry",
        "reported_by_role": "Teacher"
    }
    resp = client.post("/api/v1/maintenance/requests", json=create_payload)
    assert resp.status_code == 201
    created = resp.json()
    assert created["success"] is True
    req_id = created["id"]
    code = created["request_code"]
    assert code.startswith("MT-")

    # 2. Assign technician
    assign_payload = {
        "assigned_to_name": "Suresh Electrician",
        "instructions": "Inspect fan motor bearings and mounting bolts."
    }
    resp_assign = client.post(f"/api/v1/maintenance/requests/{req_id}/assign", json=assign_payload)
    assert resp_assign.status_code == 200
    assert resp_assign.json()["status"] == "Assigned"

    # 3. Update status to In Progress
    status_payload = {
        "new_status": "In Progress",
        "remarks": "Technician started motor inspection"
    }
    resp_status = client.post(f"/api/v1/maintenance/requests/{req_id}/status", json=status_payload)
    assert resp_status.status_code == 200
    assert resp_status.json()["new_status"] == "In Progress"

    # 4. Fetch detail
    resp_detail = client.get(f"/api/v1/maintenance/requests/{req_id}")
    assert resp_detail.status_code == 200
    detail = resp_detail.json()
    assert detail["title"] == "Lab 2 Fume Hood Exhaust Fan Vibration"
    assert detail["status"] == "In Progress"
    assert len(detail["status_history"]) >= 2
    print("\n✓ All 5 E2E tests executed and passed!")

if __name__ == "__main__":
    test_maintenance_kpis_endpoint()
    test_maintenance_requests_listing()
    test_maintenance_requests_filtering()
    test_maintenance_analytics_endpoint()
    test_maintenance_create_and_status_transition()
    print("ALL TESTS PASSED!")
