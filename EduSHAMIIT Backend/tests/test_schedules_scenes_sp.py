import unittest
import psycopg2
import json

DB_CONFIG = {
    'dbname': 'postgres',
    'user': 'postgres',
    'password': 'eduSHAMIIT2026_pg',
    'host': 'localhost',
    'port': 5432
}

SCHOOL_ID = '11111111-1111-1111-1111-111111111111'

class TestSchedulesAndScenesSP(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.conn = psycopg2.connect(**DB_CONFIG)
        cls.conn.autocommit = True
        cls.cur = cls.conn.cursor()

    @classmethod
    def tearDownClass(cls):
        cls.cur.close()
        cls.conn.close()

    def test_01_schedules_kpis(self):
        self.cur.execute("SELECT public.fn_device_schedules_kpis(%s::UUID);", (SCHOOL_ID,))
        res = self.cur.fetchone()[0]
        self.assertIsInstance(res, dict)
        self.assertIn("total_schedules", res)
        self.assertIn("active_schedules", res)
        self.assertIn("paused_schedules", res)
        print(f"Test 1 Passed: Schedules KPIs: {res['total_schedules']} total, {res['active_schedules']} active")

    def test_02_schedules_listing_and_filtering(self):
        self.cur.execute(
            "SELECT public.fn_list_device_schedules(%s::UUID, %s, %s, %s, %s, %s, %s, %s, %s);",
            (SCHOOL_ID, None, None, None, None, "created_at", "desc", 1, 10)
        )
        res = self.cur.fetchone()[0]
        self.assertIn("total", res)
        self.assertIn("items", res)
        self.assertTrue(len(res["items"]) >= 1)
        print(f"Test 2 Passed: Schedules Listing returned {len(res['items'])} of {res['total']} items")

    def test_03_schedules_crud_and_bulk(self):
        # Create
        self.cur.execute(
            """SELECT public.sp_create_device_schedule(
                %s::UUID, %s, %s, %s, %s::JSONB, %s, %s, %s, %s::UUID[], %s, %s, %s, %s, %s::TIME, %s::TIME, %s::INT[], %s
            );""",
            (
                SCHOOL_ID, "Test Schedule Alpha", "Description", "turn_on_off",
                json.dumps({"command": "ON"}), "devices", "Test Devices", 2, [],
                "daily", "Daily", "08:00 AM - 05:00 PM", "01 Jan 2026 - No End Date",
                "08:00:00", "17:00:00", [1, 2, 3, 4, 5], "Tester"
            )
        )
        create_res = self.cur.fetchone()[0]
        self.assertTrue(create_res["success"])
        sched_id = create_res.get("id") or create_res.get("schedule", {}).get("id")
        self.assertIsNotNone(sched_id)

        # Bulk Pause
        self.cur.execute(
            "SELECT public.sp_bulk_device_schedules_action(%s::UUID, %s::UUID[], %s, %s);",
            (SCHOOL_ID, [sched_id], "pause", "Tester")
        )
        pause_res = self.cur.fetchone()[0]
        self.assertTrue(pause_res["success"])
        self.assertEqual(pause_res["affected_count"], 1)

        # Bulk Activate
        self.cur.execute(
            "SELECT public.sp_bulk_device_schedules_action(%s::UUID, %s::UUID[], %s, %s);",
            (SCHOOL_ID, [sched_id], "activate", "Tester")
        )
        act_res = self.cur.fetchone()[0]
        self.assertTrue(act_res["success"])

        # Bulk Run Now
        self.cur.execute(
            "SELECT public.sp_bulk_device_schedules_action(%s::UUID, %s::UUID[], %s, %s);",
            (SCHOOL_ID, [sched_id], "run_now", "Tester")
        )
        run_res = self.cur.fetchone()[0]
        self.assertTrue(run_res["success"])

        # Delete
        self.cur.execute(
            "SELECT public.sp_delete_device_schedule(%s::UUID, %s::UUID);",
            (SCHOOL_ID, sched_id)
        )
        del_res = self.cur.fetchone()[0]
        self.assertTrue(del_res["success"])
        print("Test 3 Passed: Schedule CRUD & Bulk Operations verified")

    def test_04_scenes_kpis(self):
        self.cur.execute("SELECT public.fn_device_scenes_kpis(%s::UUID);", (SCHOOL_ID,))
        res = self.cur.fetchone()[0]
        self.assertIsInstance(res, dict)
        self.assertIn("total_scenes", res)
        self.assertIn("active_scenes", res)
        self.assertIn("total_presets", res)
        print(f"Test 4 Passed: Scenes KPIs: {res['total_scenes']} scenes, {res['total_presets']} presets")

    def test_05_scenes_listing_and_filtering(self):
        self.cur.execute(
            "SELECT public.fn_list_device_scenes(%s::UUID, %s, %s, %s, %s, %s, %s, %s, %s);",
            (SCHOOL_ID, "all", None, None, None, "created_at", "desc", 1, 10)
        )
        res = self.cur.fetchone()[0]
        self.assertIn("total", res)
        self.assertIn("items", res)
        self.assertTrue(len(res["items"]) >= 1)
        print(f"Test 5 Passed: Scenes Listing returned {len(res['items'])} of {res['total']} items")

    def test_06_scenes_crud_and_bulk(self):
        # Create
        self.cur.execute(
            """SELECT public.sp_create_device_scene(
                %s::UUID, %s, %s, %s, %s, %s, %s, %s, %s::UUID[], %s, %s::TEXT[], %s, %s, %s::JSONB, %s
            );""",
            (
                SCHOOL_ID, "Test Scene Beta", "Scene desc", "academic", "scene",
                "devices", "4 devices", 4, [], "Lab / Academic Block",
                ["Test", "Classroom"], "wb_sunny_rounded", "#2563EB", json.dumps([]), "Tester"
            )
        )
        create_res = self.cur.fetchone()[0]
        self.assertTrue(create_res["success"])
        scene_id = create_res.get("id") or create_res.get("scene", {}).get("id")
        self.assertIsNotNone(scene_id)

        # Bulk Deactivate
        self.cur.execute(
            "SELECT public.sp_bulk_device_scenes_action(%s::UUID, %s::UUID[], %s, %s);",
            (SCHOOL_ID, [scene_id], "deactivate", "Tester")
        )
        deact_res = self.cur.fetchone()[0]
        self.assertTrue(deact_res["success"])
        self.assertEqual(deact_res["affected_count"], 1)

        # Bulk Activate
        self.cur.execute(
            "SELECT public.sp_bulk_device_scenes_action(%s::UUID, %s::UUID[], %s, %s);",
            (SCHOOL_ID, [scene_id], "activate", "Tester")
        )
        act_res = self.cur.fetchone()[0]
        self.assertTrue(act_res["success"])

        # Bulk Run Now / Trigger All
        self.cur.execute(
            "SELECT public.sp_bulk_device_scenes_action(%s::UUID, %s::UUID[], %s, %s);",
            (SCHOOL_ID, [scene_id], "run_now", "Tester")
        )
        run_res = self.cur.fetchone()[0]
        self.assertTrue(run_res["success"])

        # Delete
        self.cur.execute(
            "SELECT public.sp_delete_device_scene(%s::UUID, %s::UUID);",
            (SCHOOL_ID, scene_id)
        )
        del_res = self.cur.fetchone()[0]
        self.assertTrue(del_res["success"])
        print("Test 6 Passed: Scene CRUD & Bulk Operations verified")

if __name__ == '__main__':
    unittest.main()
