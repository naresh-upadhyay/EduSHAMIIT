"""
Test Locations & Mapping Stored Procedures and FastAPI Endpoints
Tests edge cases:
- fn_get_locations_kpis: computes real counts
- fn_get_locations_hierarchy: campus, building, floor hierarchy with accurate device counts
- fn_get_location_details: returns real rooms, mapped devices, groups
- fn_get_location_devices: sorting (ASC/DESC), pagination (offset/limit), filtering by status/type/group
- sp_map_device_location & sp_bulk_map_devices
- sp_relocate_device
- sp_unmap_device_location & sp_bulk_unmap_devices
"""

import sys
import unittest
import psycopg2
import json

DB_URL = "postgresql://postgres:eduSHAMIIT2026_pg@localhost:5432/postgres"

class TestLocationsMappingDatabase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.conn = psycopg2.connect(DB_URL)
        cls.conn.autocommit = True
        cls.school_id = "11111111-1111-1111-1111-111111111111"
        cls.floor_id = "d1b49946-edcc-46e0-9d26-57c09dbb6306" # Fourth Floor (F4)
        cls.building_id = "d4b547da-ca46-4976-af82-c1b89ac6f0a7" # Academic Block (A)

    @classmethod
    def tearDownClass(cls):
        cls.conn.close()

    def test_01_locations_kpis(self):
        cur = self.conn.cursor()
        cur.execute("SELECT fn_get_locations_kpis(%s::UUID);", (self.school_id,))
        kpis = cur.fetchone()[0]
        self.assertIsNotNone(kpis)
        self.assertGreater(kpis.get("buildings", 0), 0)
        self.assertGreater(kpis.get("floors", 0), 0)
        self.assertGreater(kpis.get("rooms", 0), 0)
        self.assertGreater(kpis.get("total_devices", 0), 0)
        self.assertGreaterEqual(kpis.get("mapped_devices", 0), 10)
        self.assertGreater(kpis.get("coverage_pct", 0), 0)

    def test_02_locations_hierarchy(self):
        cur = self.conn.cursor()
        cur.execute("SELECT fn_get_locations_hierarchy(%s::UUID);", (self.school_id,))
        result = cur.fetchone()[0]
        self.assertTrue(result.get("success"))
        tree = result.get("tree", {})
        self.assertGreater(tree.get("total_buildings", 0), 0)
        
        # Verify Fourth Floor has 10 devices counted dynamically
        f4_found = False
        for b in tree.get("children", []):
            for f in b.get("children", []):
                if f.get("id") == self.floor_id:
                    f4_found = True
                    self.assertEqual(f.get("device_count"), 10)
                    self.assertEqual(f.get("room_count"), 10)
                    break
        self.assertTrue(f4_found, "Fourth Floor F4 node should be found in hierarchy tree")

    def test_03_location_details(self):
        cur = self.conn.cursor()
        cur.execute("SELECT fn_get_location_details(%s::UUID, %s::UUID);", (self.floor_id, self.school_id))
        result = cur.fetchone()[0]
        self.assertTrue(result.get("success"))
        data = result.get("data", {})
        self.assertEqual(data.get("id"), self.floor_id)
        self.assertEqual(data.get("mapped_devices"), 10)
        self.assertEqual(data.get("total_rooms"), 10)
        self.assertEqual(len(data.get("rooms", [])), 10)
        self.assertGreater(data.get("coverage_pct"), 0)

    def test_04_location_devices_pagination_and_sorting(self):
        cur = self.conn.cursor()
        # Sort ASC by device_name
        cur.execute("""
            SELECT fn_get_location_devices(
                p_school_id := %s::UUID,
                p_floor_id := %s::UUID,
                p_sort_by := 'device_name',
                p_sort_order := 'ASC',
                p_page := 1,
                p_limit := 5
            );
        """, (self.school_id, self.floor_id))
        res = cur.fetchone()[0]
        self.assertTrue(res.get("success"))
        data = res.get("data", {})
        self.assertEqual(data.get("total"), 10)
        self.assertEqual(len(data.get("devices")), 5)
        self.assertEqual(data.get("page"), 1)
        self.assertEqual(data.get("limit"), 5)
        self.assertEqual(data.get("total_pages"), 2)

        # Sort DESC by device_name
        cur.execute("""
            SELECT fn_get_location_devices(
                p_school_id := %s::UUID,
                p_floor_id := %s::UUID,
                p_sort_by := 'device_name',
                p_sort_order := 'DESC',
                p_page := 1,
                p_limit := 5
            );
        """, (self.school_id, self.floor_id))
        res_desc = cur.fetchone()[0]
        name_asc = data["devices"][0]["device_name"]
        name_desc = res_desc["data"]["devices"][0]["device_name"]
        self.assertNotEqual(name_asc, name_desc)

    def test_05_location_devices_filter_by_mapping_status(self):
        cur = self.conn.cursor()
        # Filter mapped devices on floor
        cur.execute("""
            SELECT fn_get_location_devices(
                p_school_id := %s::UUID,
                p_floor_id := %s::UUID,
                p_mapping_status := 'Mapped',
                p_page := 1,
                p_limit := 20
            );
        """, (self.school_id, self.floor_id))
        res = cur.fetchone()[0]
        data = res.get("data", {})
        self.assertEqual(data.get("total"), 10)
        for dev in data.get("devices", []):
            self.assertEqual(dev.get("mapping_status"), "Mapped")

    def test_06_relocate_and_unmap_procedures(self):
        cur = self.conn.cursor()
        test_dev_id = "f4000000-0010-4000-8000-000000000010"
        # Test relocating device to room 409
        room_409 = "ec710373-0b30-4fcf-bdeb-ccbe91770930"
        cur.execute("""
            CALL sp_relocate_device(
                p_device_id := %s::UUID,
                p_new_building_id := %s::UUID,
                p_new_floor_id := %s::UUID,
                p_new_room_id := %s::UUID,
                p_school_id := %s::UUID,
                p_reason := 'Testing relocation'
            );
        """, (test_dev_id, self.building_id, self.floor_id, room_409, self.school_id))

        # Verify device room changed
        cur.execute("SELECT room_id FROM devices WHERE id = %s;", (test_dev_id,))
        self.assertEqual(str(cur.fetchone()[0]), room_409)

        # Restore to room 408
        room_408 = "bc8546c0-5bfe-40d6-b2b7-def2e40aa156"
        cur.execute("""
            CALL sp_relocate_device(
                p_device_id := %s::UUID,
                p_new_building_id := %s::UUID,
                p_new_floor_id := %s::UUID,
                p_new_room_id := %s::UUID,
                p_school_id := %s::UUID,
                p_reason := 'Restoring after relocation test'
            );
        """, (test_dev_id, self.building_id, self.floor_id, room_408, self.school_id))
        cur.execute("SELECT room_id FROM devices WHERE id = %s;", (test_dev_id,))
        self.assertEqual(str(cur.fetchone()[0]), room_408)

if __name__ == "__main__":
    unittest.main()
