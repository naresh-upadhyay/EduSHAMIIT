import asyncio
import uuid
import httpx
from jose import jwt

import os
BASE_URL = os.environ.get("BASE_URL", "http://127.0.0.1:8082")
JWT_SECRET = "super-secret-jwt-token-with-at-least-32-characters-long"

def create_test_token(school_id: str, role: str = "super_admin", user_id: str = None) -> str:
    user_id = user_id or "5198c4b0-f1cb-45db-9649-41688d0438ba"
    payload = {
        "sub": user_id,
        "id": user_id,
        "school_id": school_id,
        "role": role,
        "exp": 9999999999
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")


import pytest

@pytest.mark.asyncio
async def test_hostel_e2e_full_lifecycle():
    # Use real school that starts with zero hostel data
    school_id = "e1f11111-1111-1111-1111-111111111111"
    token = create_test_token(school_id=school_id)
    headers = {"Authorization": f"Bearer {token}"}

    async with httpx.AsyncClient(base_url=BASE_URL, headers=headers, timeout=30.0) as client:
        # Initial cleanup of any leftover test buildings
        tree_init = await client.get("/api/hostel/structure-tree")
        if tree_init.status_code == 200:
            for b in tree_init.json().get("data", []):
                await client.delete(f"/api/hostel/buildings/{b['id']}")

        print("\n--- 1. Testing Zero-Data Tenant ---")
        res = await client.get("/api/hostel/kpis")
        assert res.status_code == 200, res.text
        data = res.json()["data"]
        assert data["total_buildings"] == 0
        assert data["total_rooms"] == 0

        res = await client.get("/api/hostel/structure-tree")
        assert res.status_code == 200
        assert len(res.json()["data"]) == 0

        res = await client.get("/api/hostel/rooms")
        assert res.status_code == 200
        assert len(res.json()["data"]) == 0

        print("Zero-data tenant verified: structures load without errors.")

        print("\n--- 2. Create Building and Floor ---")
        # Create Building
        b_res = await client.post("/api/hostel/buildings", json={
            "code": "BH-TEST",
            "name": "Boys Hostel Test",
            "hostel_name": "Test Hostel",
            "gender_policy": "BOYS",
            "total_floors": 2,
            "description": "Integration test building",
            "operational_status": "OPERATIONAL"
        })
        assert b_res.status_code == 200, b_res.text
        building_id = b_res.json()["data"]["id"]
        assert building_id is not None

        # Create Floor 1
        f_res = await client.post("/api/hostel/floors", json={
            "building_id": building_id,
            "floor_number": 1,
            "floor_name": "1st Floor",
            "floor_code": "FL-1",
            "wing": "East Wing",
            "status": "ACTIVE"
        })
        assert f_res.status_code == 200, f_res.text
        floor_id = f_res.json()["data"]["id"]

        print(f"Created building {building_id} and floor {floor_id}")

        print("\n--- 3. Create Residential Room & Non-Residential Washroom ---")
        # Residential Room
        r1_res = await client.post("/api/hostel/rooms", json={
            "building_id": building_id,
            "floor_id": floor_id,
            "room_number": "T-101",
            "room_name": "T-101",
            "room_type": "Standard",
            "is_residential": True,
            "capacity": 2,
            "room_size_sqm": 18.0,
            "monthly_fee": 6000.0,
            "gender_restriction": "BOYS",
            "attached_washroom": True,
            "status": "Available"
        })
        assert r1_res.status_code == 200, r1_res.text
        room1_id = r1_res.json()["data"]["id"]

        # Non-Residential Washroom (Capacity must be 0)
        wash_res = await client.post("/api/hostel/rooms", json={
            "building_id": building_id,
            "floor_id": floor_id,
            "room_number": "T-102",
            "room_name": "Common Washroom",
            "room_type": "Toilet/Washroom",
            "is_residential": False,
            "capacity": 0,
            "room_size_sqm": 12.0,
            "monthly_fee": 0.0,
            "status": "Operational"
        })
        assert wash_res.status_code == 200, wash_res.text
        washroom_id = wash_res.json()["data"]["id"]

        print(f"Created residential room {room1_id} and non-residential washroom {washroom_id}")

        print("\n--- 4. Add Beds to Residential Room ---")
        bed1_res = await client.post("/api/hostel/beds", json={
            "room_id": room1_id,
            "bed_number": "Bed 1",
            "bed_code": "B1",
            "bed_type": "Single",
            "monthly_price": 6000.0,
            "status": "Available"
        })
        assert bed1_res.status_code == 200, bed1_res.text
        bed1_id = bed1_res.json()["data"]["id"]

        bed2_res = await client.post("/api/hostel/beds", json={
            "room_id": room1_id,
            "bed_number": "Bed 2",
            "bed_code": "B2",
            "bed_type": "Single",
            "monthly_price": 6000.0,
            "status": "Available"
        })
        assert bed2_res.status_code == 200, bed2_res.text
        bed2_id = bed2_res.json()["data"]["id"]

        print(f"Added Bed 1 ({bed1_id}) and Bed 2 ({bed2_id})")

        print("\n--- 5. Add Equipment & Test Fault Condition ---")
        eq_res = await client.post("/api/hostel/equipment", json={
            "room_id": room1_id,
            "name": "Ceiling Fan",
            "equipment_type": "Fans",
            "quantity": 2,
            "operating_condition": "Good",
            "is_critical": True
        })
        assert eq_res.status_code == 200, eq_res.text

        # Verify room details
        detail_res = await client.get(f"/api/hostel/rooms/{room1_id}")
        assert detail_res.status_code == 200
        detail = detail_res.json()["data"]
        assert len(detail["beds"]) == 2
        assert len(detail["facilities"]) >= 1

        print("\n--- 6. Allocate Student 1 to Bed 1 ---")
        student1_id = "47f40823-8eb5-410d-88cc-37097ce5cf3d"
        assign_res = await client.post("/api/hostel/allocations/assign", json={
            "student_id": student1_id,
            "building_id": building_id,
            "floor_id": floor_id,
            "room_id": room1_id,
            "bed_id": bed1_id,
            "academic_year": "2024 - 2025",
            "check_in_date": "2024-09-01",
            "deposit_amount": 5000.0,
            "monthly_rent": 6000.0
        })
        assert assign_res.status_code == 200, assign_res.text
        alloc1_id = assign_res.json()["data"]["id"]

        # Verify bed status is now Occupied
        detail_res = await client.get(f"/api/hostel/rooms/{room1_id}")
        detail = detail_res.json()["data"]
        b1_obj = next(b for b in detail["beds"] if b["id"] == bed1_id)
        assert b1_obj["status"].upper() == "OCCUPIED"
        assert detail["current_occupancy"] == 1

        print("Student 1 allocated successfully. Bed 1 is Occupied.")

        print("\n--- 7. Test Double-Booking Prevention (Transactional & Constraint Safety) ---")
        student2_id = "0b268f97-2077-4ee3-8400-f1ab01620825"
        # Attempt to assign Student 2 to same Bed 1
        conflict_res = await client.post("/api/hostel/allocations/assign", json={
            "student_id": student2_id,
            "building_id": building_id,
            "floor_id": floor_id,
            "room_id": room1_id,
            "bed_id": bed1_id,
            "academic_year": "2024 - 2025"
        })
        assert conflict_res.status_code == 400
        assert "already occupied" in conflict_res.json()["detail"].lower()
        print("Double-booking prevented correctly with 400 status.")

        print("\n--- 8. Test Student Double-Assignment Prevention ---")
        # Attempt to assign Student 1 to Bed 2 in the same academic year
        dup_student_res = await client.post("/api/hostel/allocations/assign", json={
            "student_id": student1_id,
            "building_id": building_id,
            "floor_id": floor_id,
            "room_id": room1_id,
            "bed_id": bed2_id,
            "academic_year": "2024 - 2025"
        })
        assert dup_student_res.status_code == 400
        assert "already has an active allocation" in dup_student_res.json()["detail"].lower()
        print("Student double-allocation in same session prevented correctly.")

        print("\n--- 9. Transfer Student 1 from Bed 1 to Bed 2 ---")
        transfer_res = await client.post("/api/hostel/allocations/transfer", json={
            "allocation_id": alloc1_id,
            "new_building_id": building_id,
            "new_floor_id": floor_id,
            "new_room_id": room1_id,
            "new_bed_id": bed2_id,
            "reason": "Requested quiet side of the room"
        })
        assert transfer_res.status_code == 200, transfer_res.text
        print("TRANSFER RES:", transfer_res.json())

        # Verify old bed is released and new bed is occupied
        detail_res = await client.get(f"/api/hostel/rooms/{room1_id}")
        detail = detail_res.json()["data"]
        b1_obj = next(b for b in detail["beds"] if b["id"] == bed1_id)
        b2_obj = next(b for b in detail["beds"] if b["id"] == bed2_id)
        assert b1_obj["status"].upper() == "AVAILABLE", f"Expected B1 Available, got {b1_obj['status']}"
        assert b2_obj["status"].upper() == "OCCUPIED", f"Expected B2 Occupied, got {b2_obj['status']}"
        print("Transfer verified: Bed 1 released, Bed 2 occupied.")

        print("\n--- 10. Check Out Student 1 ---")
        active_alloc_id = b2_obj["occupant"]["allocation_id"]
        checkout_res = await client.post("/api/hostel/allocations/check-out", json={
            "allocation_id": active_alloc_id,
            "reason": "Graduated and left hostel"
        })
        assert checkout_res.status_code == 200, checkout_res.text

        # Verify Bed 2 is now Available and room occupancy is 0
        detail_res = await client.get(f"/api/hostel/rooms/{room1_id}")
        detail = detail_res.json()["data"]
        b2_obj = next(b for b in detail["beds"] if b["id"] == bed2_id)
        assert b2_obj["status"].upper() == "AVAILABLE"
        assert detail["current_occupancy"] == 0
        print("Check-out verified: Bed 2 released, occupancy returned to 0.")

        print("\n--- 11. Bulk Generate Rooms ---")
        bulk_res = await client.post("/api/hostel/rooms/bulk-generate", json={
            "building_id": building_id,
            "floor_id": floor_id,
            "prefix": "BULK-",
            "start_number": 201,
            "end_number": 205,
            "room_type": "Standard",
            "capacity": 3,
            "room_size_sqm": 18.0,
            "monthly_fee": 6000.0,
            "auto_create_beds": True
        })
        assert bulk_res.status_code == 200, bulk_res.text
        assert bulk_res.json()["count"] == 5

        # Verify rooms list pagination and count
        rooms_res = await client.get("/api/hostel/rooms", params={"building_id": building_id, "page_size": 20})
        assert rooms_res.status_code == 200, f"Status: {rooms_res.status_code}, error: {rooms_res.text}"
        all_rooms = rooms_res.json()["data"]
        assert len(all_rooms) == 7  # 2 original (T-101, T-102) + 5 bulk (BULK-201 to 205)
        print("Bulk generation of 5 rooms with auto beds verified successfully.")

        print("\n--- 12. Cross-Tenant Isolation Test ---")
        school_b_id = "22222222-2222-2222-2222-222222222222"
        token_b = create_test_token(school_id=school_b_id)
        client_b = httpx.AsyncClient(base_url=BASE_URL, headers={"Authorization": f"Bearer {token_b}"}, timeout=30.0)

        # School B must NOT see School A's buildings
        tree_b = await client_b.get("/api/hostel/structure-tree")
        assert tree_b.status_code == 200
        b_names = [b["id"] for b in tree_b.json()["data"]]
        assert building_id not in b_names

        # Direct access to School A's room by School B must return 404
        access_b = await client_b.get(f"/api/hostel/rooms/{room1_id}")
        assert access_b.status_code == 404
        print("Cross-tenant isolation verified: School B cannot access School A resources.")
        await client_b.aclose()

        print("\n--- 13. Idempotent Cleanup of Test Data ---")
        # Delete test building (cascades to floors, rooms, beds, equipment)
        del_res = await client.delete(f"/api/hostel/buildings/{building_id}")
        assert del_res.status_code == 200
        print("Cleaned up test building and related entities.")

        print("\n==================================================")
        print("ALL 13 TEST PHASES PASSED WITH COMPLETE INTEGRITY!")
        print("==================================================")


if __name__ == "__main__":
    asyncio.run(test_hostel_e2e_full_lifecycle())
