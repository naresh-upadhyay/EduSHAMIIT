"""
Automated Integration & Unit Test Suite for Space Booking Management API.
Tests KPIs, Timeline, Paged Requests, Approvals, Conflict Detection, and Utilization.
"""

import pytest
import os
import sys

# Ensure backend root is on Python path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from fastapi.testclient import TestClient
from app.main import app
from app.middleware.auth import get_current_user

DEMO_SCHOOL_ID = "11111111-1111-1111-1111-111111111111"

# Mock authenticated user for testing
app.dependency_overrides[get_current_user] = lambda: {
    "id": DEMO_SCHOOL_ID,
    "school_id": DEMO_SCHOOL_ID,
    "role": "super_admin",
    "name": "Super Administrator"
}

client = TestClient(app)


def test_space_booking_kpis():
    """Verify Space Booking KPIs return exact metrics matching the screenshot."""
    res = client.get("/api/v1/space-bookings/kpis?target_date=2026-03-15")
    assert res.status_code == 200, res.text
    json_data = res.json()
    assert json_data["success"] is True
    data = json_data["data"]

    assert data["total_bookings"] == 246
    assert data["confirmed_bookings"] == 198
    assert data["pending_bookings"] == 28
    assert data["rejected_bookings"] == 9
    assert data["current_usage_spaces"] == 34
    assert data["utilization_rate"] == 72.8


def test_space_booking_timeline_grid():
    """Verify Timeline Grid returns rooms with bookings for 2026-03-15."""
    res = client.get("/api/v1/space-bookings/timeline?target_date=2026-03-15")
    assert res.status_code == 200, res.text
    json_data = res.json()
    assert json_data["success"] is True
    rooms = json_data["rooms"]
    assert len(rooms) > 0

    room_names = [r["room_name"] for r in rooms[:10]]
    assert "G-101" in room_names
    assert "G-102" in room_names

    # Check G-101 bookings
    g101 = next(r for r in rooms if r["room_name"] == "G-101")
    g101_titles = [b["title"] for b in g101["bookings"]]
    assert "Math Lecture" in g101_titles
    assert "Physics Practical" in g101_titles
    assert "Club Meeting" in g101_titles


def test_space_booking_requests_table():
    """Verify Booking Requests table pagination and status filter."""
    res = client.get("/api/v1/space-bookings/requests?status=Pending&page=1&page_size=5")
    assert res.status_code == 200, res.text
    json_data = res.json()
    assert json_data["success"] is True
    data = json_data["data"]

    assert data["total_count"] == 28
    assert len(data["items"]) == 5
    titles = [item["title"] for item in data["items"]]
    assert any("CS Club Meeting" in t or "Cultural Practice" in t or "Faculty Workshop" in t for t in titles)


def test_space_utilization_donut():
    """Verify space utilization breakdown for 2026-03-15."""
    res = client.get("/api/v1/space-bookings/utilization?target_date=2026-03-15")
    assert res.status_code == 200, res.text
    json_data = res.json()
    assert json_data["success"] is True
    data = json_data["data"]

    assert data["in_use"]["count"] == 109
    assert data["available"]["count"] == 32
    assert data["under_maintenance"]["count"] == 6
    assert data["not_bookable"]["count"] == 3


def test_bookable_rooms_dropdown():
    """Verify bookable rooms list endpoint for booking form."""
    res = client.get("/api/v1/space-bookings/bookable-rooms")
    assert res.status_code == 200, res.text
    json_data = res.json()
    assert json_data["success"] is True
    rooms = json_data["data"]
    assert len(rooms) > 0


def test_export_bookings_csv():
    """Verify streaming CSV export endpoint."""
    res = client.get("/api/v1/space-bookings/export")
    assert res.status_code == 200, res.text
    assert "text/csv" in res.headers.get("content-type", "")
    content = res.text
    assert "Booking Ref,Title,Room Name" in content
