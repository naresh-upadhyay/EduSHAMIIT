import asyncio
import json
import uuid
import asyncpg

DB_URL = "postgresql://postgres:eduSHAMIIT2026_pg@localhost:54322/postgres"

async def test_control_dashboard_stored_procedures():
    print("Connecting to PostgreSQL at localhost:54322...")
    conn = await asyncpg.connect(DB_URL)
    school_id = uuid.UUID("11111111-1111-1111-1111-111111111111")

    try:
        print("\n--- Test 1: fn_device_management_get_overview (Dynamic KPIs & Breakdowns) ---")
        row = await conn.fetchval("SELECT public.fn_device_management_get_overview($1::uuid);", school_id)
        ov = json.loads(row) if isinstance(row, str) else row
        assert "kpis" in ov, "KPIs missing from overview"
        kpis = ov["kpis"]
        print(f"  [PASS] KPIs: Total={kpis['total_devices']}, Online={kpis['online']}, Offline={kpis['offline']}, "
              f"Types={kpis['device_types']}, Locations={kpis['locations_summary']}, "
              f"Automations={kpis['automations_active']}, Schedules={kpis['schedules_count']}, Alerts={kpis['alerts_count']}")
        assert kpis["total_devices"] > 0, "Total devices should be > 0"
        assert len(ov["buildings_breakdown"]) > 0, "Buildings breakdown should not be empty"
        assert len(ov["devices_by_type"]) > 0, "Devices by type should not be empty"
        print(f"  [PASS] Buildings in breakdown: {len(ov['buildings_breakdown'])}, Types in donut: {len(ov['devices_by_type'])}")

        print("\n--- Test 2: sp_get_location_tree (Hierarchy & Live Counts) ---")
        tree_raw = await conn.fetchval("SELECT public.sp_get_location_tree($1::uuid);", school_id)
        tree = json.loads(tree_raw) if isinstance(tree_raw, str) else tree_raw
        assert tree["name"] == "Entire Campus"
        assert tree["total_devices"] > 0
        b1 = next((b for b in tree["buildings"] if b["code"] == "B1"), None)
        assert b1 is not None, "B1 building must exist"
        print(f"  [PASS] Entire Campus Total: {tree['total_devices']}, B1 Device Count: {b1['device_count']}")
        gf = next((f for f in b1["floors"] if f["code"] == "GF"), None)
        assert gf is not None, "Ground Floor must exist"
        print(f"  [PASS] Ground Floor Count: {gf['device_count']}, Rooms count: {len(gf['rooms'])}")
        cr1 = next((r for r in gf["rooms"] if r["room_number"] == "CR-1"), None)
        assert cr1 is not None, "CR-1 room must exist"
        print(f"  [PASS] Room CR-1 Count: {cr1['device_count']}")
        assert cr1["device_count"] > 0, "Room CR-1 should now have devices!"

        print("\n--- Test 3: sp_list_devices with location filtering and database sorting ---")
        # 3.1 All devices with sorting by device_name ASC
        res_raw = await conn.fetchval("SELECT public.sp_list_devices($1, '', NULL, NULL, NULL, 'All', 'All', 1, 10, 'device_name', 'asc');", school_id)
        res = json.loads(res_raw) if isinstance(res_raw, str) else res_raw
        assert res["total"] > 0
        assert len(res["devices"]) > 0
        print(f"  [PASS] All devices page 1: total={res['total']}, returned={len(res['devices'])}")

        # 3.2 Filter by Building B1
        res_bld = json.loads(await conn.fetchval("SELECT public.sp_list_devices($1, '', 'B1', NULL, NULL, 'All', 'All', 1, 10, 'device_name', 'asc');", school_id))
        assert res_bld["total"] > 0
        print(f"  [PASS] Filter Building 'B1': total={res_bld['total']}")

        # 3.3 Filter by Ground Floor GF
        res_gf = json.loads(await conn.fetchval("SELECT public.sp_list_devices($1, '', 'B1', 'GF', NULL, 'All', 'All', 1, 10, 'device_name', 'asc');", school_id))
        assert res_gf["total"] > 0
        print(f"  [PASS] Filter Floor 'GF': total={res_gf['total']}")

        # 3.4 Filter by Room CR-1
        res_cr1 = json.loads(await conn.fetchval("SELECT public.sp_list_devices($1, '', 'B1', 'GF', 'CR-1', 'All', 'All', 1, 10, 'device_name', 'asc');", school_id))
        assert res_cr1["total"] > 0, "CR-1 must have devices!"
        print(f"  [PASS] Filter Room 'CR-1': total={res_cr1['total']}, devices={[d['device_name'] for d in res_cr1['devices']]}")

        # 3.5 Sorting DESC by device_name
        res_desc = json.loads(await conn.fetchval("SELECT public.sp_list_devices($1, '', NULL, NULL, NULL, 'All', 'All', 1, 10, 'device_name', 'desc');", school_id))
        assert res_desc["devices"][0]["device_name"] >= res_desc["devices"][-1]["device_name"]
        print(f"  [PASS] Sort DESC verified: first='{res_desc['devices'][0]['device_name']}' >= last='{res_desc['devices'][-1]['device_name']}'")

        print("\n--- Test 4: CRUD Operations (Create, Read Detail, Update, Delete) ---")
        # 4.1 Create Device
        test_code = f"TEST-DEV-{uuid.uuid4().hex[:6].upper()}"
        create_res = json.loads(await conn.fetchval(
            "SELECT public.sp_create_device($1, 'Automated Test Light', $2, 'lighting', 'B1', 'GF', 'CR-1', '192.168.1.99', '00:11:22:33:44:55', 85, 'Test notes', NULL);",
            school_id, test_code
        ))
        assert create_res["success"] is True
        new_dev_id = uuid.UUID(create_res["device"]["id"])
        print(f"  [PASS] sp_create_device created device ID: {new_dev_id} ({test_code})")

        # 4.2 Read Detail
        detail_res = json.loads(await conn.fetchval("SELECT public.sp_get_device_detail($1, $2);", school_id, new_dev_id))
        assert detail_res["success"] is True
        assert detail_res["device"]["device_code"] == test_code
        assert detail_res["device"]["room_number"] == "CR-1"
        print(f"  [PASS] sp_get_device_detail verified location: {detail_res['device']['location_display']}")

        # 4.3 Update Device
        update_res = json.loads(await conn.fetchval(
            "SELECT public.sp_update_device($1, $2, 'Updated Test Light', NULL, NULL, NULL, NULL, '192.168.1.100', NULL, 120, 'Updated notes');",
            school_id, new_dev_id
        ))
        assert update_res["success"] is True
        assert update_res["device"]["device_name"] == "Updated Test Light"
        print(f"  [PASS] sp_update_device updated device name: {update_res['device']['device_name']}")

        # 4.4 Delete Device
        delete_res = json.loads(await conn.fetchval("SELECT public.sp_delete_device($1, $2);", school_id, new_dev_id))
        assert delete_res["success"] is True
        print(f"  [PASS] sp_delete_device soft-deleted device ID: {new_dev_id}")

        # Verify device is not returned in active list
        res_after = json.loads(await conn.fetchval("SELECT public.sp_list_devices($1, $2, NULL, NULL, NULL, 'All', 'All', 1, 10);", school_id, test_code))
        assert res_after["total"] == 0, "Deleted device should not appear in list"
        print(f"  [PASS] Verified device {test_code} is excluded after deletion")

        # 4.5 Bulk Delete Test
        test_code_a = f"TEST-DEV-{uuid.uuid4().hex[:6].upper()}"
        test_code_b = f"TEST-DEV-{uuid.uuid4().hex[:6].upper()}"
        dev_a = json.loads(await conn.fetchval("SELECT public.sp_create_device($1, 'Bulk Dev A', $2, 'lighting');", school_id, test_code_a))
        dev_b = json.loads(await conn.fetchval("SELECT public.sp_create_device($1, 'Bulk Dev B', $2, 'fan');", school_id, test_code_b))
        bulk_del_res = json.loads(await conn.fetchval(
            "SELECT public.sp_bulk_delete_devices($1, $2::UUID[]);",
            school_id, [uuid.UUID(dev_a["device"]["id"]), uuid.UUID(dev_b["device"]["id"])]
        ))
        assert bulk_del_res["success"] is True
        assert bulk_del_res["deleted_count"] == 2
        print(f"  [PASS] sp_bulk_delete_devices deleted {bulk_del_res['deleted_count']} devices")

        print("\n=======================================================")
        print("ALL 4 CONTROL DASHBOARD TEST SUITES PASSED PERFECTLY!")
        print("=======================================================")

    finally:
        await conn.close()

if __name__ == "__main__":
    asyncio.run(test_control_dashboard_stored_procedures())
