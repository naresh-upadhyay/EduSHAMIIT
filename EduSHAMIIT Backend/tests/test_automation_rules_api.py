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

class TestAutomationRulesDatabase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.conn = psycopg2.connect(**DB_CONFIG)
        cls.conn.autocommit = True
        cls.cur = cls.conn.cursor()

    @classmethod
    def tearDownClass(cls):
        cls.cur.close()
        cls.conn.close()

    def test_01_automation_kpis(self):
        """Verify dynamic KPIs returned without any hardcoding."""
        self.cur.execute("SELECT fn_automation_rules_kpis(%s::UUID);", (SCHOOL_ID,))
        row = self.cur.fetchone()
        self.assertIsNotNone(row)
        kpis = row[0]
        self.assertIn('total_rules', kpis)
        self.assertIn('active_rules', kpis)
        self.assertIn('inactive_rules', kpis)
        self.assertIn('triggers_today', kpis)
        self.assertIn('total_executions', kpis)
        self.assertIn('devices_governed', kpis)
        self.assertIn('health_percentage', kpis)
        self.assertGreaterEqual(kpis['total_rules'], 8)
        self.assertGreater(kpis['devices_governed'], 0)

    def test_02_cascading_options(self):
        """Verify cascading options from live database tables."""
        self.cur.execute("SELECT fn_automation_cascading_options(%s::UUID, NULL, NULL);", (SCHOOL_ID,))
        row = self.cur.fetchone()
        self.assertIsNotNone(row)
        opts = row[0]
        self.assertIn('buildings', opts)
        self.assertIn('floors', opts)
        self.assertIn('rooms', opts)
        self.assertIn('device_types', opts)
        self.assertIn('device_groups', opts)
        self.assertIn('devices', opts)
        self.assertIn('scenes', opts)
        self.assertIn('condition_attributes', opts)
        self.assertIn('action_commands', opts)
        self.assertGreater(len(opts['buildings']), 0)
        self.assertGreater(len(opts['device_types']), 0)

        # Test cascading with first building
        first_bld_id = opts['buildings'][0]['id']
        self.cur.execute("SELECT fn_automation_cascading_options(%s::UUID, %s::UUID, NULL);", (SCHOOL_ID, first_bld_id))
        cascaded = self.cur.fetchone()[0]
        self.assertTrue(all(f['building_id'] == first_bld_id for f in cascaded['floors']))

    def test_03_list_automation_rules(self):
        """Verify database search, filtering, pagination, and sorting."""
        self.cur.execute(
            "SELECT fn_list_automation_rules(%s::UUID, NULL, NULL, NULL, NULL, NULL, 'created_at', 'DESC', 1, 10);",
            (SCHOOL_ID,)
        )
        res = self.cur.fetchone()[0]
        self.assertIn('total', res)
        self.assertIn('page', res)
        self.assertIn('page_size', res)
        self.assertIn('rules', res)
        self.assertGreaterEqual(res['total'], 8)
        self.assertLessEqual(len(res['rules']), 10)

        # Test search
        self.cur.execute(
            "SELECT fn_list_automation_rules(%s::UUID, 'Lights', NULL, NULL, NULL, NULL, 'name', 'ASC', 1, 5);",
            (SCHOOL_ID,)
        )
        search_res = self.cur.fetchone()[0]
        self.assertGreaterEqual(search_res['total'], 1)
        self.assertTrue(any('light' in r['name'].lower() or 'light' in r['description'].lower() for r in search_res['rules']))

    def test_04_create_and_delete_rule(self):
        """Verify sp_create_automation_rule and sp_delete_automation_rule."""
        self.cur.execute("""
            DO $$
            DECLARE
                v_id UUID;
                v_rule JSONB;
                v_del_success BOOLEAN;
            BEGIN
                CALL sp_create_automation_rule(
                    '11111111-1111-1111-1111-111111111111'::UUID,
                    'Automated Integration Test Rule',
                    'Created during integration testing',
                    'smart',
                    'Smart Rule',
                    '{"location_name": "Test Lab"}'::jsonb,
                    '{"target_type": "all"}'::jsonb,
                    '{"combinator": "AND", "conditions": [{"attribute": "Occupancy", "operator": "is equal to", "value": "0"}]}'::jsonb,
                    '{"execution_mode": "In Sequence", "actions": [{"target": "Lights", "action": "Turn OFF"}]}'::jsonb,
                    TRUE,
                    v_id,
                    v_rule
                );
                IF v_id IS NULL THEN
                    RAISE EXCEPTION 'Rule creation failed: null ID';
                END IF;

                -- Delete rule
                CALL sp_delete_automation_rule(
                    '11111111-1111-1111-1111-111111111111'::UUID,
                    v_id,
                    v_del_success
                );
                IF NOT v_del_success THEN
                    RAISE EXCEPTION 'Rule deletion failed';
                END IF;
            END $$;
        """)

    def test_05_update_and_toggle_rule(self):
        """Verify sp_update_automation_rule and sp_toggle_automation_rule."""
        self.cur.execute("""
            DO $$
            DECLARE
                v_id UUID;
                v_rule JSONB;
                v_upd_success BOOLEAN;
                v_upd_rule JSONB;
                v_tog_success BOOLEAN;
                v_is_active BOOLEAN;
                v_del_success BOOLEAN;
            BEGIN
                -- 1. Create rule
                CALL sp_create_automation_rule(
                    '11111111-1111-1111-1111-111111111111'::UUID,
                    'Update Test Rule',
                    'Initial description',
                    'threshold',
                    'Threshold Rule',
                    '{}'::jsonb,
                    '{}'::jsonb,
                    '{}'::jsonb,
                    '{}'::jsonb,
                    TRUE,
                    v_id,
                    v_rule
                );

                -- 2. Update rule
                CALL sp_update_automation_rule(
                    '11111111-1111-1111-1111-111111111111'::UUID,
                    v_id,
                    'Updated Rule Name',
                    'Updated description',
                    'threshold',
                    'Threshold Rule',
                    '{}'::jsonb,
                    '{}'::jsonb,
                    '{}'::jsonb,
                    '{}'::jsonb,
                    TRUE,
                    v_upd_success,
                    v_upd_rule
                );
                IF NOT v_upd_success OR (v_upd_rule->>'name') != 'Updated Rule Name' THEN
                    RAISE EXCEPTION 'Update failed';
                END IF;

                -- 3. Toggle rule
                CALL sp_toggle_automation_rule(
                    '11111111-1111-1111-1111-111111111111'::UUID,
                    v_id,
                    v_tog_success,
                    v_is_active
                );
                IF NOT v_tog_success OR v_is_active != FALSE THEN
                    RAISE EXCEPTION 'Toggle failed';
                END IF;

                -- 4. Clean up
                CALL sp_delete_automation_rule(
                    '11111111-1111-1111-1111-111111111111'::UUID,
                    v_id,
                    v_del_success
                );
            END $$;
        """)

    def test_06_duplicate_rule(self):
        """Verify sp_duplicate_automation_rule."""
        self.cur.execute("""
            DO $$
            DECLARE
                v_id UUID;
                v_rule JSONB;
                v_dup_id UUID;
                v_dup_rule JSONB;
                v_del_success BOOLEAN;
            BEGIN
                -- 1. Create rule
                CALL sp_create_automation_rule(
                    '11111111-1111-1111-1111-111111111111'::UUID,
                    'Duplicate Source Rule',
                    'Source description',
                    'smart',
                    'Smart Rule',
                    '{}'::jsonb,
                    '{}'::jsonb,
                    '{}'::jsonb,
                    '{}'::jsonb,
                    TRUE,
                    v_id,
                    v_rule
                );

                -- 2. Duplicate rule
                CALL sp_duplicate_automation_rule(
                    '11111111-1111-1111-1111-111111111111'::UUID,
                    v_id,
                    v_dup_id,
                    v_dup_rule
                );
                IF v_dup_id IS NULL OR (v_dup_rule->>'name') != 'Copy of Duplicate Source Rule' THEN
                    RAISE EXCEPTION 'Duplication failed';
                END IF;

                -- 3. Clean up both
                CALL sp_delete_automation_rule('11111111-1111-1111-1111-111111111111'::UUID, v_id, v_del_success);
                CALL sp_delete_automation_rule('11111111-1111-1111-1111-111111111111'::UUID, v_dup_id, v_del_success);
            END $$;
        """)

    def test_07_bulk_actions(self):
        """Verify sp_bulk_automation_rules_action for enable, disable, run."""
        self.cur.execute("""
            SELECT id FROM public.device_automation_rules
            WHERE school_id = %s::UUID
            LIMIT 2;
        """, (SCHOOL_ID,))
        rows = self.cur.fetchall()
        rule_ids = [str(r[0]) for r in rows]
        self.assertEqual(len(rule_ids), 2)

        self.cur.execute("""
            DO $$
            DECLARE
                v_success BOOLEAN;
                v_affected INT;
            BEGIN
                CALL sp_bulk_automation_rules_action(
                    '11111111-1111-1111-1111-111111111111'::UUID,
                    ARRAY[%s::UUID, %s::UUID],
                    'disable',
                    v_success,
                    v_affected
                );
                IF NOT v_success OR v_affected != 2 THEN
                    RAISE EXCEPTION 'Bulk disable failed';
                END IF;

                CALL sp_bulk_automation_rules_action(
                    '11111111-1111-1111-1111-111111111111'::UUID,
                    ARRAY[%s::UUID, %s::UUID],
                    'enable',
                    v_success,
                    v_affected
                );
                IF NOT v_success OR v_affected != 2 THEN
                    RAISE EXCEPTION 'Bulk enable failed';
                END IF;
            END $$;
        """, (rule_ids[0], rule_ids[1], rule_ids[0], rule_ids[1]))

    def test_08_test_rule_evaluation(self):
        """Verify fn_test_automation_rule real device evaluation."""
        self.cur.execute("""
            SELECT fn_test_automation_rule(
                %s::UUID,
                NULL,
                '{"location_name": "Campus"}'::jsonb,
                '{"target_type": "all"}'::jsonb,
                '{"combinator": "AND", "conditions": [{"attribute": "Occupancy", "operator": "is equal to", "value": "0"}]}'::jsonb,
                '{"execution_mode": "In Sequence", "actions": [{"target": "All Lights", "action": "Turn OFF"}]}'::jsonb
            );
        """, (SCHOOL_ID,))
        row = self.cur.fetchone()
        self.assertIsNotNone(row)
        res = row[0]
        self.assertTrue(res['condition_met'])
        self.assertGreater(res['matching_devices_count'], 0)
        self.assertIn('live devices', res['evaluation'])
        self.assertEqual(len(res['simulated_actions']), 1)
        self.assertEqual(res['simulated_actions'][0]['action'], 'Turn OFF')

    def test_09_execute_automation_rule(self):
        """Verify sp_execute_automation_rule execution and audit logging."""
        self.cur.execute("""
            SELECT id FROM public.device_automation_rules
            WHERE school_id = %s::UUID
            LIMIT 1;
        """, (SCHOOL_ID,))
        rule_id = str(self.cur.fetchone()[0])

        self.cur.execute("""
            DO $$
            DECLARE
                v_success BOOLEAN;
                v_summary JSONB;
            BEGIN
                CALL sp_execute_automation_rule(
                    '11111111-1111-1111-1111-111111111111'::UUID,
                    %s::UUID,
                    v_success,
                    v_summary
                );
                IF NOT v_success THEN
                    RAISE EXCEPTION 'Execution failed';
                END IF;
            END $$;
        """, (rule_id,))


if __name__ == '__main__':
    unittest.main()
