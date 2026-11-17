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

class TestLiveControlApi(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.conn = psycopg2.connect(**DB_CONFIG)
        cls.conn.autocommit = True
        cls.cur = cls.conn.cursor()

    @classmethod
    def tearDownClass(cls):
        cls.cur.close()
        cls.conn.close()

    def test_01_live_control_kpis(self):
        self.cur.execute("SELECT fn_live_control_kpis(%s::UUID);", (SCHOOL_ID,))
        row = self.cur.fetchone()
        self.assertIsNotNone(row)
        kpis = row[0]
        self.assertIn('online_devices', kpis)
        self.assertIn('online_percentage', kpis)
        self.assertIn('offline_devices', kpis)
        self.assertIn('offline_percentage', kpis)
        self.assertIn('controllable_now', kpis)
        self.assertIn('active_groups', kpis)
        self.assertIn('running_automations', kpis)
        self.assertIn('active_schedules', kpis)
        self.assertGreaterEqual(kpis['online_devices'], 0)
        self.assertGreaterEqual(kpis['active_groups'], 0)

    def test_02_live_control_devices_pagination(self):
        self.cur.execute(
            "SELECT fn_live_control_devices(%s::UUID, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'device_name', 'asc', 1, 5);",
            (SCHOOL_ID,)
        )
        row = self.cur.fetchone()
        self.assertIsNotNone(row)
        res = row[0]
        self.assertIn('devices', res)
        self.assertIn('total', res)
        self.assertEqual(res['page'], 1)
        self.assertEqual(res['page_size'], 5)
        self.assertLessEqual(len(res['devices']), 5)
        self.assertGreaterEqual(res['total'], 1)

    def test_03_live_control_devices_sorting(self):
        # Ascending
        self.cur.execute(
            "SELECT fn_live_control_devices(%s::UUID, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'device_name', 'asc', 1, 10);",
            (SCHOOL_ID,)
        )
        devs_asc = self.cur.fetchone()[0]['devices']
        names_asc = [d['device_name'].lower() for d in devs_asc]

        # Descending
        self.cur.execute(
            "SELECT fn_live_control_devices(%s::UUID, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'device_name', 'desc', 1, 10);",
            (SCHOOL_ID,)
        )
        devs_desc = self.cur.fetchone()[0]['devices']
        names_desc = [d['device_name'].lower() for d in devs_desc]

        if len(names_asc) > 1 and len(names_desc) > 1:
            self.assertNotEqual(names_asc[0], names_desc[0])

    def test_04_live_control_devices_filtering(self):
        # Filter by status: online
        self.cur.execute(
            "SELECT fn_live_control_devices(%s::UUID, NULL, NULL, NULL, NULL, NULL, 'online', NULL, 'device_name', 'asc', 1, 10);",
            (SCHOOL_ID,)
        )
        res_online = self.cur.fetchone()[0]
        for d in res_online['devices']:
            self.assertTrue(d['is_online'])

        # Filter by search
        self.cur.execute(
            "SELECT fn_live_control_devices(%s::UUID, NULL, NULL, NULL, NULL, NULL, NULL, 'LIGHT', 'device_name', 'asc', 1, 10);",
            (SCHOOL_ID,)
        )
        res_search = self.cur.fetchone()[0]
        self.assertGreater(res_search['total'], 0)

    def test_05_execute_live_control_command(self):
        # Fetch first device
        self.cur.execute("SELECT id FROM devices WHERE school_id = %s AND deleted_at IS NULL LIMIT 1;", (SCHOOL_ID,))
        dev_id = self.cur.fetchone()[0]

        # Execute set_brightness
        self.cur.execute(
            "CALL sp_execute_live_control_command(%s::UUID, %s::UUID, 'set_brightness', %s::JSONB, NULL, NULL, NULL, NULL, NULL, NULL);",
            (SCHOOL_ID, dev_id, json.dumps({'brightness': 92}))
        )
        res = self.cur.fetchone()
        self.assertTrue(res[0]) # p_success
        self.assertTrue(res[3]) # p_power_state should be true for set_brightness
        self.assertEqual(res[4].get('brightness'), 92)

    def test_06_bulk_execute_live_control_commands(self):
        self.cur.execute("SELECT id FROM devices WHERE school_id = %s AND deleted_at IS NULL LIMIT 3;", (SCHOOL_ID,))
        rows = self.cur.fetchall()
        dev_ids = [r[0] for r in rows]

        self.cur.execute(
            "CALL sp_bulk_execute_live_control_commands(%s::UUID, %s::UUID[], 'turn_on', %s::JSONB, NULL, NULL, NULL, NULL);",
            (SCHOOL_ID, dev_ids, json.dumps({'power': True}))
        )
        res = self.cur.fetchone()
        self.assertTrue(res[0])
        self.assertEqual(res[1], len(dev_ids))

    def test_07_get_live_control_device_details(self):
        self.cur.execute("SELECT id FROM devices WHERE school_id = %s AND deleted_at IS NULL LIMIT 1;", (SCHOOL_ID,))
        dev_id = self.cur.fetchone()[0]

        self.cur.execute("SELECT fn_get_live_control_device_details(%s::UUID, %s::UUID);", (SCHOOL_ID, dev_id))
        row = self.cur.fetchone()
        self.assertIsNotNone(row)
        det = row[0]
        self.assertIn('device', det)
        self.assertIn('recent_logs', det)
        self.assertEqual(det['device']['id'], str(dev_id))

if __name__ == '__main__':
    unittest.main()
