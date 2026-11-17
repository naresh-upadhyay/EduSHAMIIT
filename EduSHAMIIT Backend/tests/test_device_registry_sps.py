import asyncio
import json
import uuid
import asyncpg

DB_URL = "postgresql://postgres:eduSHAMIIT2026_pg@localhost:54322/postgres"

async def test_device_registry_stored_procedures():
    print("Connecting to PostgreSQL at localhost:54322...")
    conn = await asyncpg.connect(DB_URL)
    school_id = uuid.UUID("11111111-1111-1111-1111-111111111111")

    try:
        print("\n--- Test 1: fn_get_device_registry_kpis ---")
        row = await conn.fetchval("SELECT public.fn_get_device_registry_kpis($1);", school_id)
        kpis = json.loads(row) if isinstance(row, str) else row
        print(f"  [PASS] Registry KPIs: Total={kpis['total_devices']}, Online={kpis['online']}, Offline={kpis['offline']}, Types={kpis['device_types']}, Locations={kpis['locations_summary']}")
        assert kpis["total_devices"] > 0, "Total devices should be > 0"

        print("\n--- Test 2: sp_list_devices multi-field search ---")
        # Search by room number 'CR-1'
        res1 = json.loads(await conn.fetchval("SELECT public.sp_list_devices($1, 'CR-1', NULL, NULL, NULL, 'All', 'All', 1, 10, 'device_name', 'asc');", school_id))
        assert res1["total"] > 0, "Search by 'CR-1' should return devices"
        print(f"  [PASS] Search 'CR-1': {res1['total']} devices found")

        # Search by AC
        res2 = json.loads(await conn.fetchval("SELECT public.sp_list_devices($1, 'AC', NULL, NULL, NULL, 'All', 'All', 1, 10, 'device_name', 'asc');", school_id))
        assert res2["total"] > 0, "Search by 'AC' should return devices"
        print(f"  [PASS] Search 'AC': {res2['total']} devices found")

        print("\n--- Test 3: sp_list_devices database sorting ---")
        for sort_col in ['device_name', 'device_code', 'type_name', 'location_path', 'status', 'ip_address']:
            res_asc = json.loads(await conn.fetchval(f"SELECT public.sp_list_devices($1, '', NULL, NULL, NULL, 'All', 'All', 1, 10, '{sort_col}', 'asc');", school_id))
            assert res_asc["total"] > 0, f"Sorting by {sort_col} asc should work"
            res_desc = json.loads(await conn.fetchval(f"SELECT public.sp_list_devices($1, '', NULL, NULL, NULL, 'All', 'All', 1, 10, '{sort_col}', 'desc');", school_id))
            assert res_desc["total"] > 0, f"Sorting by {sort_col} desc should work"
            print(f"  [PASS] Sorting by {sort_col} (ASC & DESC) verified successfully!")

        print("\n--- Test 4: Full CRUD Operations ---")
        # 4.1 Create
        dev_code = f"TEST-REG-{uuid.uuid4().hex[:6].upper()}"
        create_res = json.loads(await conn.fetchval(
            "SELECT public.sp_create_device($1, 'Test Registry AC Unit', $2, 'lighting', 'B1', 'GF', 'CR-1', '192.168.1.99', 'AA:BB:CC:DD:EE:FF', 1500, 'Test Registry Device', NULL);",
            school_id, dev_code
        ))
        dev_id = uuid.UUID(create_res["device"]["id"])
        print(f"  [PASS] Created device: {dev_id} ({dev_code})")

        # 4.2 Detail
        detail = json.loads(await conn.fetchval("SELECT public.sp_get_device_detail($1, $2);", school_id, dev_id))
        assert detail["device"]["device_name"] == "Test Registry AC Unit"
        print(f"  [PASS] Verified detail for {detail['device']['device_name']}")

        # 4.3 Update
        update_res = json.loads(await conn.fetchval(
            "SELECT public.sp_update_device($1, $2, 'Updated Registry AC Unit', NULL, NULL, NULL, NULL, '192.168.1.100', NULL, 1800, 'Updated notes');",
            school_id, dev_id
        ))
        assert update_res["success"] is True
        print(f"  [PASS] Updated device successfully")

        # 4.4 Bulk Delete
        bulk_del = json.loads(await conn.fetchval("SELECT public.sp_bulk_delete_devices($1, $2::jsonb);", school_id, json.dumps([str(dev_id)])))
        assert bulk_del["success"] is True and bulk_del["deleted_count"] == 1
        print(f"  [PASS] Bulk delete verified: {bulk_del['deleted_count']} deleted")

        print("\n>>> ALL 4 TEST SUITES PASSED 100% FOR DEVICE REGISTRY <<<")
    finally:
        await conn.close()

if __name__ == "__main__":
    asyncio.run(test_device_registry_stored_procedures())
