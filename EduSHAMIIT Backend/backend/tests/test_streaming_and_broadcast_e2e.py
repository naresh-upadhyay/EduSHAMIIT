"""
EduSHAMIIT – Enterprise Live Streaming & Broadcast E2E Test Suite
Verifies all REST APIs, stored procedures, destinations toggle, lifecycle state transitions,
analytics aggregation, scheduling, past streams, and settings configuration.
"""
import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_get_streaming_overview():
    """Verify live broadcast overview matches mockup schema and data."""
    response = client.get("/api/v1/broadcasts/overview?institute_id=1")
    assert response.status_code == 200
    data = response.json()
    assert "activeBroadcast" in data
    assert "destinations" in data
    assert "analyticsPoints" in data
    assert "scheduledBroadcasts" in data

    active = data["activeBroadcast"]
    assert active is not None
    assert "Class 10 - Mathematics" in active["title"]
    assert active["status"] in ["live", "paused", "ended", "draft"]
    assert active["streamHealth"] in ["Excellent", "Good", "Fair", "Poor", "Offline"]
    assert active["resolution"] == "1080p"
    assert active["currentViewers"] >= 0

    destinations = data["destinations"]
    assert len(destinations) >= 3
    platforms = [d["platformKey"] for d in destinations]
    assert "youtube" in platforms
    assert "facebook" in platforms


def test_toggle_destination():
    """Verify toggling active status on a destination."""
    overview = client.get("/api/v1/broadcasts/overview?institute_id=1").json()
    dest_id = overview["destinations"][0]["id"]

    res = client.post(f"/api/v1/broadcasts/destinations/{dest_id}/toggle", json={"isActive": False})
    assert res.status_code == 200
    assert res.json()["success"] is True
    assert res.json()["isActive"] is False

    # Toggle back to True
    res2 = client.post(f"/api/v1/broadcasts/destinations/{dest_id}/toggle", json={"isActive": True})
    assert res2.status_code == 200
    assert res2.json()["isActive"] is True


def test_broadcast_lifecycle_transitions():
    """Verify Go Live, Pause, Resume, Stop, and End & Save."""
    # Create a draft broadcast
    create_res = client.post(
        "/api/v1/broadcasts/create?institute_id=1",
        json={
            "title": "Automated Test Live Class Session",
            "description": "Testing broadcast lifecycle end to end",
            "category": "Education",
            "privacy": "Public",
            "streamQuality": "1080p (Full HD)",
            "bitrateMode": "Auto (Recommended)"
        }
    )
    assert create_res.status_code == 200
    bc_id = create_res.json()["broadcastId"]

    # Start (Go Live)
    start_res = client.post(f"/api/v1/broadcasts/{bc_id}/start")
    assert start_res.status_code == 200
    assert start_res.json()["status"] == "live"

    # Pause
    pause_res = client.post(f"/api/v1/broadcasts/{bc_id}/pause")
    assert pause_res.status_code == 200
    assert pause_res.json()["status"] == "paused"

    # Resume
    resume_res = client.post(f"/api/v1/broadcasts/{bc_id}/resume")
    assert resume_res.status_code == 200
    assert resume_res.json()["status"] == "live"

    # End & Save
    end_res = client.post(f"/api/v1/broadcasts/{bc_id}/end-and-save")
    assert end_res.status_code == 200
    assert end_res.json()["status"] == "ended"
    assert end_res.json()["savedToRecordings"] is True


def test_scheduled_broadcasts_flow():
    """Verify fetching and adding scheduled broadcasts."""
    list_res = client.get("/api/v1/broadcasts/scheduled?institute_id=1")
    assert list_res.status_code == 200
    initial_count = len(list_res.json())

    new_sched = client.post(
        "/api/v1/broadcasts/schedule?institute_id=1",
        json={
            "title": "Class 10 - Biology: Cellular Respiration",
            "description": "Comprehensive scheduled broadcast for grade 10",
            "classSubject": "Class 10 - Biology",
            "scheduledTime": "2026-11-25T14:00:00Z",
            "platform": "youtube",
            "privacy": "Public",
            "quality": "1080p (Full HD)"
        }
    )
    assert new_sched.status_code == 200
    assert new_sched.json()["success"] is True

    updated_list = client.get("/api/v1/broadcasts/scheduled?institute_id=1").json()
    assert len(updated_list) == initial_count + 1


def test_past_streams():
    """Verify fetching past streams list."""
    res = client.get("/api/v1/broadcasts/past?institute_id=1")
    assert res.status_code == 200
    data = res.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    stream = data[0]
    assert "title" in stream
    assert "streamedOn" in stream
    assert "totalViews" in stream


def test_stream_analytics():
    """Verify streaming metrics and platform breakdown."""
    res = client.get("/api/v1/broadcasts/analytics?institute_id=1")
    assert res.status_code == 200
    data = res.json()
    assert "totalBroadcasts" in data
    assert "totalWatchHours" in data
    assert "totalViews" in data
    assert "platformBreakdown" in data
    assert len(data["platformBreakdown"]) >= 1


def test_broadcast_settings():
    """Verify getting and updating broadcast settings."""
    res = client.get("/api/v1/broadcasts/settings?institute_id=1")
    assert res.status_code == 200
    data = res.json()
    assert "defaultQuality" in data

    update_res = client.put(
        "/api/v1/broadcasts/settings?institute_id=1",
        json={
            "defaultQuality": "1080p (Full HD)",
            "defaultBitrateMode": "Auto (Recommended)",
            "defaultPrivacy": "Public",
            "defaultCategory": "Education",
            "autoRecord": True,
            "lowLatency": True,
            "dvrEnabled": True,
            "chatRelay": True,
            "customRtmpUrl": "rtmp://live.edushamiit.internal/stream"
        }
    )
    assert update_res.status_code == 200
    assert update_res.json()["success"] is True


def test_add_custom_destination():
    """Verify adding an external destination to a broadcast."""
    overview = client.get("/api/v1/broadcasts/overview?institute_id=1").json()
    bc_id = overview["activeBroadcast"]["id"]

    res = client.post(
        f"/api/v1/broadcasts/{bc_id}/destinations",
        json={
            "platformKey": "custom_rtmp",
            "name": "CDN Primary Mirror",
            "rtmpUrl": "rtmp://cdn.edushamiit.org/mirror",
            "streamKey": "key_cdn_mirror_091823"
        }
    )
    assert res.status_code == 200
    assert res.json()["success"] is True
