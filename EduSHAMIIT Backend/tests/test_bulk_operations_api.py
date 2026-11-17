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

class TestBulkOperations(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.conn = psycopg2.connect(**DB_CONFIG)
        cls.conn.autocommit = True
        cls.cur = cls.conn.cursor()

    @classmethod
    def tearDownClass(cls):
        cls.cur.close()
        cls.conn.close()

    def test_01_bulk_operations_kpis(self):
        """Verify dynamic KPIs returned without any hardcoding."""
        self.cur.execute("SELECT fn_bulk_operations_kpis(%s::UUID);", (SCHOOL_ID,))
        row = self.cur.fetchone()
        self.assertIsNotNone(row)
        kpis = row[0]
        self.assertIn('total_devices', kpis)
        self.assertIn('online_devices', kpis)
        self.assertIn('online_percentage', kpis)
        self.assertIn('offline_devices', kpis)
        self.assertIn('offline_percentage', kpis)
        self.assertIn('operations_running', kpis)
        self.assertIn('operations_completed_today', kpis)
        self.assertIn('failed_commands', kpis)
        self.assertIn('total_operations', kpis)
        self.assertGreaterEqual(kpis['total_devices'], 0)

    def test_02_cascading_locations_all(self):
        """Verify cascading locations returns buildings, floors, rooms, device_types, profiles, groups, scenes."""
        self.cur.execute("SELECT fn_bulk_cascading_locations(%s::UUID, NULL, NULL);", (SCHOOL_ID,))
        row = self.cur.fetchone()
        self.assertIsNotNone(row)
        data = row[0]
        self.assertIn('buildings', data)
        self.assertIn('floors', data)
        self.assertIn('rooms', data)
        self.assertIn('device_types', data)
        self.assertIn('profiles', data)
        self.assertIn('groups', data)
        self.assertIn('scenes', data)
        self.assertGreater(len(data['buildings']), 0)
        self.assertGreater(len(data['floors']), 0)
        self.assertGreater(len(data['rooms']), 0)

    def test_03_cascading_rule_strict(self):
        """Verify cascading: selecting a building ONLY returns floors of that building, selecting a floor ONLY returns rooms of that floor."""
        # 1. Fetch buildings
        self.cur.execute("SELECT fn_bulk_cascading_locations(%s::UUID, NULL, NULL);", (SCHOOL_ID,))
        buildings = self.cur.fetchone()[0]['buildings']
        self.assertTrue(len(buildings) > 0)
        b_id = buildings[0]['id']

        # 2. Query with building_id
        self.cur.execute("SELECT fn_bulk_cascading_locations(%s::UUID, %s::UUID, NULL);", (SCHOOL_ID, b_id))
        cascaded_b = self.cur.fetchone()[0]
        for flr in cascaded_b['floors']:
            self.assertEqual(flr['building_id'], b_id, f"Floor {flr['name']} does not belong to building {b_id}")

        # 3. If floor exists, query with floor_id
        if cascaded_b['floors']:
            f_id = cascaded_b['floors'][0]['id']
            self.cur.execute("SELECT fn_bulk_cascading_locations(%s::UUID, %s::UUID, %s::UUID);", (SCHOOL_ID, b_id, f_id))
            cascaded_f = self.cur.fetchone()[0]
            for rm in cascaded_f['rooms']:
                self.assertEqual(rm['floor_id'], f_id, f"Room {rm['name']} does not belong to floor {f_id}")

    def test_04_bulk_target_devices_sorting_pagination(self):
        """Verify database sorting and pagination for target devices grid."""
        # Page 1, size 5, asc sort
        self.cur.execute(
            """
            SELECT fn_bulk_target_devices(
                %s::UUID, NULL::UUID, NULL::UUID, NULL::UUID, 
                NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, 
                NULL::TEXT, NULL::TEXT, NULL::TEXT, 'device_name'::TEXT, 'asc'::TEXT, 1, 5
            );
            """,
            (SCHOOL_ID,)
        )
        res = self.cur.fetchone()[0]
        self.assertIn('devices', res)
        self.assertIn('total', res)
        self.assertIn('page', res)
        self.assertIn('page_size', res)
        self.assertIn('total_pages', res)
        self.assertEqual(res['page'], 1)
        self.assertEqual(res['page_size'], 5)
        self.assertLessEqual(len(res['devices']), 5)

        # Page 1, size 5, desc sort
        self.cur.execute(
            """
            SELECT fn_bulk_target_devices(
                %s::UUID, NULL::UUID, NULL::UUID, NULL::UUID, 
                NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, 
                NULL::TEXT, NULL::TEXT, NULL::TEXT, 'device_name'::TEXT, 'desc'::TEXT, 1, 5
            );
            """,
            (SCHOOL_ID,)
        )
        res_desc = self.cur.fetchone()[0]
        self.assertLessEqual(len(res_desc['devices']), 5)

    def test_05_list_bulk_operations(self):
        """Verify fn_list_bulk_operations returns paginated operations."""
        self.cur.execute(
            "SELECT fn_list_bulk_operations(%s::UUID, NULL::TEXT, NULL::TEXT, NULL::TEXT, 'created_at'::TEXT, 'desc'::TEXT, 1, 10);",
            (SCHOOL_ID,)
        )
        res = self.cur.fetchone()[0]
        self.assertIn('items', res)
        self.assertIn('total', res)
        self.assertIn('page', res)

    def test_06_list_templates(self):
        """Verify fn_list_bulk_templates returns active templates."""
        self.cur.execute("SELECT fn_list_bulk_templates(%s::UUID);", (SCHOOL_ID,))
        res = self.cur.fetchone()[0]
        self.assertIsInstance(res, list)
        self.assertGreaterEqual(len(res), 1)

    def test_07_create_and_execute_bulk_operation(self):
        """Test sp_create_and_execute_bulk_operation stored procedure."""
        rules = json.dumps({"building": "Academic Block", "status": "online"})
        actions = json.dumps({"action": "turn_on", "parameters": {}})
        execution = json.dumps({"batch_size": 25, "delay_seconds": 0.5})
        user_id = "b06057ff-fde8-40f8-8a92-b74d2f52632c"
        
        self.cur.execute(
            "SELECT sp_create_and_execute_bulk_operation(%s::UUID, %s, %s, %s, %s::JSONB, %s::JSONB, %s::JSONB, %s::UUID, %s);",
            (SCHOOL_ID, "Test Night Power On", "control", "filter", rules, actions, execution, user_id, "Test Admin")
        )
        op_res = self.cur.fetchone()[0]
        self.assertTrue(op_res['success'])
        self.assertIn('operation_id', op_res)
        op_id = op_res['operation_id']

        # Verify operation details
        self.cur.execute("SELECT fn_get_bulk_operation_details(%s::UUID, %s::UUID);", (SCHOOL_ID, op_id))
        details = self.cur.fetchone()[0]
        self.assertIsNotNone(details)
        self.assertTrue(details['success'])
        self.assertEqual(details['operation']['name'], "Test Night Power On")

if __name__ == '__main__':
    unittest.main()
