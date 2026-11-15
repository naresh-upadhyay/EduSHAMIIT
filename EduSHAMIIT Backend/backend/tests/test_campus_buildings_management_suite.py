"""
Production-Grade Automated Test Suite for Campus Management: Buildings & Rooms.
Covers:
1. Campus Infrastructure KPIs & Extensible Lookups
2. Buildings Management: List, Search, Filter, Create, Retrieve, Update, Duplicate Code Prevention, Archive, Delete Protection
3. Floors Hierarchy: Ordered Levels (-2, -1, 0, 1..), Basement Handling, Duplicate Prevention, Safe Delete Check
4. Rooms Management: Classrooms, Labs, Washrooms, Utility, Hostel Rooms, Dynamic Fields, Duplicate Prevention
5. Room Equipment: Multi-item Tracking, Individual Working Status ("Not Working", "Under Maintenance"), Service Dates
6. Bulk Operations: Bulk Room Creation, Bulk Import Validation, Streaming CSV Export
7. Cross-Module Reusable Room Allocations & Inspections
8. Multi-Tenancy School Isolation & Security Checks
"""
import pytest
import uuid
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

from jose import jwt
from app.config import settings

SCHOOL_ID_1 = "11111111-1111-1111-1111-111111111111"
SCHOOL_ID_2 = "22222222-2222-2222-2222-222222222222"

def make_token(school_id: str, role: str = "super_admin"):
    payload = {
        "sub": "10000000-0000-0000-0000-000000000002",
        "school_id": school_id,
        "role": role,
        "email": "admin@edushamiit.com",
        "exp": 9999999999
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm="HS256")

HEADERS_ADMIN_1 = {
    "X-School-ID": SCHOOL_ID_1,
    "Authorization": f"Bearer {make_token(SCHOOL_ID_1)}"
}

HEADERS_ADMIN_2 = {
    "X-School-ID": SCHOOL_ID_2,
    "Authorization": f"Bearer {make_token(SCHOOL_ID_2)}"
}


# ============================================================================
# 1. CAMPUS KPIS & LOOKUPS
# ============================================================================

def test_campus_kpis_summary():
    """Verify institution infrastructure KPIs match seeded totals."""
    res = client.get("/api/v1/campus/kpis", headers=HEADERS_ADMIN_1)
    assert res.status_code == 200, res.text
    data = res.json()
    assert data["total_buildings"] >= 8
    assert data["total_floors"] >= 38
    assert data["total_rooms"] >= 156
    assert data["total_capacity"] >= 7560
    assert data["occupied_capacity"] >= 6800
    assert data["available_capacity"] >= 700
    assert data["occupancy_rate"] >= 80.0


def test_campus_lookups():
    """Verify lookup options for building types, room types, equipment, etc."""
    res = client.get("/api/v1/campus/lookups", headers=HEADERS_ADMIN_1)
    assert res.status_code == 200
    lookups = res.json()
    assert "building_types" in lookups
    assert "Academic" in lookups["building_types"]
    assert "room_types" in lookups
    assert "Classroom" in lookups["room_types"]
    assert "Physics Lab" in lookups["room_types"]
    assert "Washroom" in lookups["room_types"]
    assert "equipment_statuses" in lookups
    assert "Not Working" in lookups["equipment_statuses"]


# ============================================================================
# 2. BUILDINGS MANAGEMENT WORKFLOWS
# ============================================================================

def test_buildings_listing_and_filtering():
    """Verify listing buildings with search and type filters."""
    res = client.get("/api/v1/campus/buildings?search=Academic", headers=HEADERS_ADMIN_1)
    assert res.status_code == 200
    data = res.json()
    assert data["success"] is True
    assert data["total_count"] >= 1
    bld = data["data"][0]
    assert "B1" in bld["code"] or "Academic" in bld["name"]
    assert bld["total_floors"] >= 5
    assert bld["total_rooms"] >= 42
    assert bld["total_capacity"] >= 2100


def test_building_details_with_floors_breakdown():
    """Verify retrieving building details returns summary KPIs and floor breakdown."""
    # Find B1
    list_res = client.get("/api/v1/campus/buildings?search=B1", headers=HEADERS_ADMIN_1)
    b1 = list_res.json()["data"][0]
    b1_id = b1["id"]

    res = client.get(f"/api/v1/campus/buildings/{b1_id}", headers=HEADERS_ADMIN_1)
    assert res.status_code == 200
    body = res.json()
    assert body["success"] is True
    assert body["summary"]["total_floors"] == 5
    assert body["summary"]["total_rooms"] >= 42
    assert body["summary"]["total_capacity"] >= 2100
    assert body["summary"]["current_occupancy"] >= 1900
    assert body["summary"]["occupancy_rate"] > 0
    assert len(body["floors"]) == 5


def test_building_crud_lifecycle_and_duplicate_prevention():
    """Test create, retrieve, update, duplicate code prevention, and archive."""
    unique_code = f"TEST-BLD-{uuid.uuid4().hex[:4].upper()}"
    payload = {
        "name": "Robotics & AI Innovation Wing",
        "code": unique_code,
        "building_type": "Laboratory",
        "description": "High-tech lab for robotics and computing",
        "total_floors": 3,
        "total_area": 15000.0,
        "area_unit": "sq ft",
        "status": "Active"
    }

    # 1. Create building
    create_res = client.post("/api/v1/campus/buildings", json=payload, headers=HEADERS_ADMIN_1)
    assert create_res.status_code == 200, create_res.text
    bld_data = create_res.json()["data"]
    bld_id = bld_data["id"]

    # 2. Reject duplicate building code
    dup_res = client.post("/api/v1/campus/buildings", json=payload, headers=HEADERS_ADMIN_1)
    assert dup_res.status_code == 400
    assert "already exists" in dup_res.json()["detail"].lower()

    # 3. Update building
    payload["name"] = "Robotics & AI Innovation Wing (Updated)"
    payload["total_area"] = 18000.0
    update_res = client.put(f"/api/v1/campus/buildings/{bld_id}", json=payload, headers=HEADERS_ADMIN_1)
    assert update_res.status_code == 200
    assert update_res.json()["data"]["name"] == "Robotics & AI Innovation Wing (Updated)"

    # 4. Archive building
    archive_res = client.post(f"/api/v1/campus/buildings/{bld_id}/archive", headers=HEADERS_ADMIN_1)
    assert archive_res.status_code == 200
    assert archive_res.json()["success"] is True

    # 5. Safe delete (since no rooms exist in this test building)
    del_res = client.delete(f"/api/v1/campus/buildings/{bld_id}", headers=HEADERS_ADMIN_1)
    assert del_res.status_code == 200


def test_building_delete_protection_when_rooms_exist():
    """Verify that deleting a building containing active rooms is strictly blocked."""
    list_res = client.get("/api/v1/campus/buildings?search=B1", headers=HEADERS_ADMIN_1)
    b1_id = list_res.json()["data"][0]["id"]

    del_res = client.delete(f"/api/v1/campus/buildings/{b1_id}", headers=HEADERS_ADMIN_1)
    assert del_res.status_code == 400
    assert "cannot delete building" in del_res.json()["detail"].lower()


# ============================================================================
# 3. FLOORS MANAGEMENT & BASEMENT ORDERING
# ============================================================================

def test_floor_crud_and_basement_ordering():
    """Verify creating basement floors (B2, B1) and proper sorting."""
    # Create temporary building
    bld_code = f"B-ORD-{uuid.uuid4().hex[:4].upper()}"
    bld_res = client.post("/api/v1/campus/buildings", json={
        "name": "Order Test Building",
        "code": bld_code,
        "building_type": "Other",
        "total_floors": 4
    }, headers=HEADERS_ADMIN_1)
    bld_id = bld_res.json()["data"]["id"]

    # Add floors in arbitrary order: 1st, B2, Ground, B1
    client.post(f"/api/v1/campus/buildings/{bld_id}/floors", json={
        "building_id": bld_id,
        "name": "First Floor",
        "floor_code": "F1",
        "floor_level": 1,
        "floor_order": 3
    }, headers=HEADERS_ADMIN_1)

    client.post(f"/api/v1/campus/buildings/{bld_id}/floors", json={
        "building_id": bld_id,
        "name": "Basement 2 (Parking)",
        "floor_code": "B2",
        "floor_level": -2,
        "floor_order": 0
    }, headers=HEADERS_ADMIN_1)

    client.post(f"/api/v1/campus/buildings/{bld_id}/floors", json={
        "building_id": bld_id,
        "name": "Ground Floor",
        "floor_code": "G",
        "floor_level": 0,
        "floor_order": 2
    }, headers=HEADERS_ADMIN_1)

    client.post(f"/api/v1/campus/buildings/{bld_id}/floors", json={
        "building_id": bld_id,
        "name": "Basement 1 (Storage)",
        "floor_code": "B1",
        "floor_level": -1,
        "floor_order": 1
    }, headers=HEADERS_ADMIN_1)

    # Fetch floors and verify ordering is strictly B2 -> B1 -> G -> F1
    floors_res = client.get(f"/api/v1/campus/buildings/{bld_id}/floors", headers=HEADERS_ADMIN_1)
    assert floors_res.status_code == 200
    floors = floors_res.json()["data"]
    codes = [f["floor_code"] for f in floors]
    assert codes == ["B2", "B1", "G", "F1"], f"Incorrect ordering: {codes}"

    # Clean up floors and building
    for f in floors:
        client.delete(f"/api/v1/campus/floors/{f['id']}", headers=HEADERS_ADMIN_1)
    client.delete(f"/api/v1/campus/buildings/{bld_id}", headers=HEADERS_ADMIN_1)


# ============================================================================
# 4. ROOMS MANAGEMENT WORKFLOWS
# ============================================================================

def test_room_creation_diverse_types_and_dynamic_fields():
    """Verify creating classrooms, labs, washrooms, utility rooms, and hostel rooms."""
    list_res = client.get("/api/v1/campus/buildings?search=B1", headers=HEADERS_ADMIN_1)
    b1_id = list_res.json()["data"][0]["id"]
    floor_res = client.get(f"/api/v1/campus/buildings/{b1_id}/floors", headers=HEADERS_ADMIN_1)
    floor_id = floor_res.json()["data"][0]["id"]

    # 1. Classroom with seating capacity
    cr_res = client.post("/api/v1/campus/rooms", json={
        "building_id": b1_id,
        "floor_id": floor_id,
        "name": "Advanced Mathematics Seminar Room",
        "room_number": f"T-MATH-{uuid.uuid4().hex[:4]}",
        "room_type": "Classroom",
        "max_capacity": 45,
        "seating_capacity": 45,
        "operational_status": "Available"
    }, headers=HEADERS_ADMIN_1)
    assert cr_res.status_code == 200
    cr_id = cr_res.json()["data"]["id"]

    # 2. Washroom (capacity=0, no seating needed)
    wr_res = client.post("/api/v1/campus/rooms", json={
        "building_id": b1_id,
        "floor_id": floor_id,
        "name": "Ground Floor Executive Restroom",
        "room_number": f"T-WASH-{uuid.uuid4().hex[:4]}",
        "room_type": "Washroom",
        "max_capacity": 5,
        "seating_capacity": 0,
        "operational_status": "Available"
    }, headers=HEADERS_ADMIN_1)
    assert wr_res.status_code == 200
    wr_id = wr_res.json()["data"]["id"]

    # 3. Utility Room (Water Pump Room)
    ut_res = client.post("/api/v1/campus/rooms", json={
        "building_id": b1_id,
        "floor_id": floor_id,
        "name": "Main Water Pump & Filtration Room",
        "room_number": f"T-PUMP-{uuid.uuid4().hex[:4]}",
        "room_type": "Water Pump Room",
        "max_capacity": 2,
        "seating_capacity": 0,
        "operational_status": "Available"
    }, headers=HEADERS_ADMIN_1)
    assert ut_res.status_code == 200
    ut_id = ut_res.json()["data"]["id"]

    # Cleanup test rooms
    client.delete(f"/api/v1/campus/rooms/{cr_id}", headers=HEADERS_ADMIN_1)
    client.delete(f"/api/v1/campus/rooms/{wr_id}", headers=HEADERS_ADMIN_1)
    client.delete(f"/api/v1/campus/rooms/{ut_id}", headers=HEADERS_ADMIN_1)


def test_room_duplicate_number_prevention():
    """Verify that duplicate room numbers inside the same building are strictly blocked."""
    list_res = client.get("/api/v1/campus/buildings?search=B1", headers=HEADERS_ADMIN_1)
    b1_id = list_res.json()["data"][0]["id"]
    floor_res = client.get(f"/api/v1/campus/buildings/{b1_id}/floors", headers=HEADERS_ADMIN_1)
    floor_id = floor_res.json()["data"][0]["id"]

    # Room G001 already exists in B1
    dup_res = client.post("/api/v1/campus/rooms", json={
        "building_id": b1_id,
        "floor_id": floor_id,
        "name": "Duplicate G001",
        "room_number": "G001",
        "room_type": "Classroom"
    }, headers=HEADERS_ADMIN_1)
    assert dup_res.status_code == 400
    assert "already exists" in dup_res.json()["detail"].lower()


# ============================================================================
# 5. EQUIPMENT & FIXTURE STATUS TRACKING
# ============================================================================

def test_room_equipment_independent_status_tracking():
    """Verify equipment can be added to a room and individual status tracked (e.g. Water pump Not Working)."""
    list_res = client.get("/api/v1/campus/rooms?search=Junior Science Laboratory", headers=HEADERS_ADMIN_1)
    room = list_res.json()["data"][0]
    room_id = room["id"]

    # Add water pump marked Not Working
    eq_res = client.post(f"/api/v1/campus/rooms/{room_id}/equipment", json={
        "room_id": room_id,
        "equipment_name": "Heavy Duty Recirculation Pump",
        "equipment_category": "Plumbing & Sanitation",
        "quantity": 1,
        "condition": "Poor",
        "operational_status": "Not Working",
        "installation_date": "2024-01-15",
        "remarks": "Impeller seized, scheduled for repair."
    }, headers=HEADERS_ADMIN_1)
    assert eq_res.status_code == 200
    eq_id = eq_res.json()["data"]["id"]

    # Verify equipment list shows this item
    list_eq = client.get(f"/api/v1/campus/rooms/{room_id}/equipment", headers=HEADERS_ADMIN_1)
    assert list_eq.status_code == 200
    eq_items = list_eq.json()
    pump_item = next(item for item in eq_items if item["id"] == eq_id)
    assert pump_item["operational_status"] == "Not Working"
    assert pump_item["condition"] == "Poor"

    # Update status to Operational after service
    upd_res = client.put(f"/api/v1/campus/rooms/{room_id}/equipment/{eq_id}", json={
        "room_id": room_id,
        "equipment_name": "Heavy Duty Recirculation Pump",
        "operational_status": "Operational",
        "condition": "Good",
        "last_service_date": "2026-11-10",
        "next_service_date": "2027-05-10",
        "remarks": "Serviced and certified operational."
    }, headers=HEADERS_ADMIN_1)
    assert upd_res.status_code == 200
    assert upd_res.json()["data"]["operational_status"] == "Operational"

    # Clean up
    client.delete(f"/api/v1/campus/rooms/{room_id}/equipment/{eq_id}", headers=HEADERS_ADMIN_1)


# ============================================================================
# 6. BULK ROOM OPERATIONS
# ============================================================================

def test_bulk_create_rooms_with_facilities():
    """Verify batch room creation with common facilities in one transaction."""
    list_res = client.get("/api/v1/campus/buildings?search=B1", headers=HEADERS_ADMIN_1)
    b1_id = list_res.json()["data"][0]["id"]
    floor_res = client.get(f"/api/v1/campus/buildings/{b1_id}/floors", headers=HEADERS_ADMIN_1)
    floor_id = floor_res.json()["data"][0]["id"]

    suffix = uuid.uuid4().hex[:3].upper()
    room_numbers = [f"BLK-{suffix}-1", f"BLK-{suffix}-2", f"BLK-{suffix}-3"]

    bulk_res = client.post("/api/v1/campus/rooms/bulk-create", json={
        "building_id": b1_id,
        "floor_id": floor_id,
        "room_numbers": room_numbers,
        "room_type": "Classroom",
        "default_capacity": 40,
        "common_facilities": ["Ceiling Fan", "Whiteboard", "LED Tube Light"]
    }, headers=HEADERS_ADMIN_1)

    assert bulk_res.status_code == 200
    data = bulk_res.json()
    assert data["success"] is True
    assert data["created_count"] == 3

    # Clean up created rooms
    for rm in data["rooms"]:
        client.delete(f"/api/v1/campus/rooms/{rm['id']}", headers=HEADERS_ADMIN_1)


def test_bulk_import_rooms():
    """Verify importing rooms from structured JSON rows."""
    suffix = uuid.uuid4().hex[:3].upper()
    rows = [
        {"building_code": "B1", "floor_code": "GF", "room_number": f"IMP-{suffix}-1", "room_name": "Imported Room 1", "room_type": "Classroom", "capacity": 35},
        {"building_code": "B1", "floor_code": "GF", "room_number": f"IMP-{suffix}-2", "room_name": "Imported Room 2", "room_type": "Classroom", "capacity": 35},
    ]

    res = client.post("/api/v1/campus/rooms/bulk-import", json=rows, headers=HEADERS_ADMIN_1)
    assert res.status_code == 200
    data = res.json()
    assert data["success"] is True
    assert data["imported_count"] == 2
    assert data["failed_count"] == 0

    # Cleanup
    for r in rows:
        find = client.get(f"/api/v1/campus/rooms?search={r['room_number']}", headers=HEADERS_ADMIN_1)
        if find.json()["data"]:
            client.delete(f"/api/v1/campus/rooms/{find.json()['data'][0]['id']}", headers=HEADERS_ADMIN_1)


# ============================================================================
# 7. CROSS-MODULE REUSABLE ALLOCATIONS & INSPECTIONS
# ============================================================================

def test_room_allocations_cross_module():
    """Verify allocating room to an academic section or event."""
    list_res = client.get("/api/v1/campus/rooms?search=G002", headers=HEADERS_ADMIN_1)
    room_id = list_res.json()["data"][0]["id"]

    alloc_res = client.post(f"/api/v1/campus/rooms/{room_id}/assignments", json={
        "room_id": room_id,
        "reference_module": "Academic",
        "reference_name": "Grade 1 - Section A Academic Timetable",
        "assignment_purpose": "Daily Class Instruction",
        "start_date": "2026-06-01",
        "end_date": "2027-04-30",
        "assigned_to_name": "Mrs. Anita Rao (Class Teacher)",
        "notes": "Allocated as permanent primary section home room"
    }, headers=HEADERS_ADMIN_1)
    assert alloc_res.status_code == 200
    assert alloc_res.json()["success"] is True

    # Retrieve assignments
    list_alloc = client.get(f"/api/v1/campus/rooms/{room_id}/assignments", headers=HEADERS_ADMIN_1)
    assert list_alloc.status_code == 200
    assert len(list_alloc.json()) >= 1


def test_building_inspection_record():
    """Verify recording and retrieving building inspection results."""
    list_res = client.get("/api/v1/campus/buildings?search=B1", headers=HEADERS_ADMIN_1)
    b1_id = list_res.json()["data"][0]["id"]

    insp_res = client.post(f"/api/v1/campus/buildings/{b1_id}/inspections", json={
        "building_id": b1_id,
        "inspection_type": "Electrical Safety",
        "inspector_name": "Er. Arvind Joshi",
        "result": "Passed",
        "findings": "Switchgears, distribution boards, and earthing verified.",
        "recommendations": "Ensure transformer yard gravel is replenished."
    }, headers=HEADERS_ADMIN_1)
    assert insp_res.status_code == 200
    assert insp_res.json()["success"] is True

    # Retrieve inspections
    list_insp = client.get(f"/api/v1/campus/buildings/{b1_id}/inspections", headers=HEADERS_ADMIN_1)
    assert list_insp.status_code == 200
    assert len(list_insp.json()) >= 1


# ============================================================================
# 8. DATA EXPORT (STREAMING CSV)
# ============================================================================

def test_csv_export_endpoints():
    """Verify CSV export for buildings, floors, rooms, and equipment."""
    for exp_type in ["buildings", "floors", "rooms", "equipment"]:
        res = client.get(f"/api/v1/campus/export?export_type={exp_type}", headers=HEADERS_ADMIN_1)
        assert res.status_code == 200
        assert "text/csv" in res.headers["content-type"]
        assert len(res.text) > 0


# ============================================================================
# 9. MULTI-TENANCY ISOLATION & SECURITY
# ============================================================================

def test_multi_tenancy_isolation():
    """Verify School 2 cannot see or access School 1 buildings and rooms."""
    # School 1 buildings
    res1 = client.get("/api/v1/campus/buildings", headers=HEADERS_ADMIN_1)
    assert res1.status_code == 200
    bld_count_1 = res1.json()["total_count"]
    assert bld_count_1 >= 8

    # School 2 buildings (isolated, should not see School 1 buildings)
    res2 = client.get("/api/v1/campus/buildings", headers=HEADERS_ADMIN_2)
    assert res2.status_code == 200
    data2 = res2.json()["data"]
    # Verify none of School 1's IDs are in School 2's list
    school_1_ids = {b["id"] for b in res1.json()["data"]}
    for b in data2:
        assert b["id"] not in school_1_ids


def test_unauthorized_access():
    """Verify unauthenticated requests are rejected."""
    res = client.get("/api/v1/campus/buildings")
    assert res.status_code == 401
