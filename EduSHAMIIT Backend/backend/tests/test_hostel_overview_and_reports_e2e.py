import sys
import json
import httpx
import pytest
from jose import jwt

BASE_URL = "http://127.0.0.1:8082/api"
DEFAULT_SCHOOL_ID = "11111111-1111-1111-1111-111111111111"
ADMIN_USER_ID = "5198c4b0-f1cb-45db-9649-41688d0438ba"
JWT_SECRET = "super-secret-jwt-token-with-at-least-32-characters-long"

def create_test_token(school_id: str = DEFAULT_SCHOOL_ID, role: str = "super_admin", user_id: str = None) -> str:
    user_id = user_id or ADMIN_USER_ID
    payload = {
        "sub": user_id,
        "id": user_id,
        "school_id": school_id,
        "role": role,
        "exp": 9999999999
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")

@pytest.mark.asyncio
async def test_hostel_overview_analytics_endpoint():
    """Verify Tab 0 Executive Dashboard overview analytics returns complete aggregated KPIs."""
    token = create_test_token()
    headers = {"Authorization": f"Bearer {token}", "X-School-ID": DEFAULT_SCHOOL_ID}
    async with httpx.AsyncClient(timeout=15.0) as client:
        res = await client.get(f"{BASE_URL}/hostel/overview?academic_year=2024%20-%202025", headers=headers)
        assert res.status_code == 200, f"Overview endpoint failed: {res.text}"
        data = res.json()
        assert data.get("success") is True
        payload = data.get("data", {})
        assert "kpis" in payload
        assert "building_occupancy" in payload
        assert "room_types" in payload
        assert "recent_movements" in payload
        assert "priority_complaints" in payload

        kpis = payload["kpis"]
        assert kpis.get("total_buildings", 0) > 0
        assert kpis.get("total_rooms", 0) > 0
        assert "occupancy_rate" in kpis
        assert "recovery_rate" in kpis

@pytest.mark.asyncio
async def test_hostel_reports_all_categories_endpoints():
    """Verify Tab 8 Universal Reports returns tabular data for all 5 operational reports."""
    token = create_test_token()
    headers = {"Authorization": f"Bearer {token}", "X-School-ID": DEFAULT_SCHOOL_ID}
    report_types = ["occupancy", "residents", "fee_defaulters", "movement", "complaints"]

    async with httpx.AsyncClient(timeout=15.0) as client:
        for rtype in report_types:
            res = await client.get(
                f"{BASE_URL}/hostel/reports?report_type={rtype}&academic_year=2024%20-%202025",
                headers=headers
            )
            assert res.status_code == 200, f"Report {rtype} failed: {res.text}"
            data = res.json()
            assert data.get("success") is True
            rep = data.get("data", {})
            assert rep.get("report_type") == rtype
            assert "record_count" in rep
            assert isinstance(rep.get("records"), list)
