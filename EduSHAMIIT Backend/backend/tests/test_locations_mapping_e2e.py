import pytest
import httpx

BASE_URL = "http://localhost:8082/api/v1/devices/locations"
SCHOOL_ID = "11111111-1111-1111-1111-111111111111"
FLOOR_ID = "b8b4c4de-11e1-4d42-b4ad-27b86c8c823a"


@pytest.mark.asyncio
async def test_locations_mapping_kpis():
    async with httpx.AsyncClient() as client:
        res = await client.get(f"{BASE_URL}/kpis?school_id={SCHOOL_ID}")
        assert res.status_code == 200
        data = res.json()
        assert data["success"] is True
        kpis = data["data"]
        assert kpis["buildings"] == 6
        assert kpis["floors"] == 42
        assert kpis["rooms"] == 276
        assert kpis["mapped_devices"] == 8296
        assert kpis["mapped_pct"] == 95.0
        assert kpis["unmapped_devices"] == 446
        assert kpis["unmapped_pct"] == 5.0
        assert kpis["locations_with_devices"] == 268
        assert kpis["coverage_pct"] == 97.1


@pytest.mark.asyncio
async def test_locations_hierarchy():
    async with httpx.AsyncClient() as client:
        res = await client.get(f"{BASE_URL}/hierarchy?school_id={SCHOOL_ID}")
        assert res.status_code == 200
        data = res.json()
        assert data["success"] is True
        tree = data["tree"]
        assert tree["name"] == "Greenwood High School"
        buildings = tree["children"]
        bldg_names = [b["name"] for b in buildings]
        assert any("Admin Block" in n for n in bldg_names)
        assert any("Academic Block (A)" in n for n in bldg_names)
        assert any("Laboratories Block" in n for n in bldg_names)


@pytest.mark.asyncio
async def test_locations_details():
    async with httpx.AsyncClient() as client:
        res = await client.get(f"{BASE_URL}/details?floor_id={FLOOR_ID}&school_id={SCHOOL_ID}")
        assert res.status_code == 200
        data = res.json()
        assert data["success"] is True
        details = data["data"]
        assert "Academic Block (A)" in details["building_name"]
        assert details["floor_no"] == 1
        assert details["location_type"] == "Floor"
        assert details["total_rooms"] >= 14
        assert len(details["rooms"]) >= 14


@pytest.mark.asyncio
async def test_locations_devices_table():
    async with httpx.AsyncClient() as client:
        res = await client.get(f"{BASE_URL}/devices?floor_id={FLOOR_ID}&page=1&limit=6&school_id={SCHOOL_ID}")
        assert res.status_code == 200
        data = res.json()
        assert data["success"] is True
        devices = data["devices"]
        assert len(devices) == 6
        # Check first row
        first_dev = devices[0]
        assert first_dev["device_code"] == "CAM-A1-101"
        assert first_dev["device_type"] == "CCTV"
        assert "A1-101" in first_dev["room_space"]
        assert first_dev["mapping_status"] == "Mapped"


@pytest.mark.asyncio
async def test_locations_floor_plan():
    async with httpx.AsyncClient() as client:
        res = await client.get(f"{BASE_URL}/floor-plan/{FLOOR_ID}?school_id={SCHOOL_ID}")
        assert res.status_code == 200
        data = res.json()
        assert data["success"] is True
        assert "floor_plan" in data
        assert len(data["floor_plan"]["rooms_layout"]) >= 8
        assert len(data["markers"]) >= 14
        assert "legend" in data
        assert data["legend"]["cctv"] >= 2
        assert data["legend"]["lighting"] >= 6
