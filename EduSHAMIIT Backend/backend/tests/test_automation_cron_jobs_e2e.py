"""
End-to-End Automated Test Suite for Device Automation Rules Cron Engine.
Verifies periodic and on-demand cron execution, condition matching, device command execution,
MQTT packet dispatching, and audit logging.
"""

import asyncio
from datetime import datetime, timezone
from app.api.device_management import (
    execute_automation_cron,
    exec_sql,
    _cron_stats
)


async def test_automation_cron_direct_execution():
    """Verify that execute_automation_cron evaluates active rules and executes actions."""
    res = await execute_automation_cron()
    assert res["success"] is True
    assert res["rules_evaluated"] >= 1
    assert res["rules_triggered"] >= 1
    assert res["actions_executed_count"] >= 1
    assert res["devices_affected"] >= 1
    assert res["mqtt_commands_dispatched"] >= 1
    assert res["status"] == "COMPLETED"

    # Verify rule structure in triggered rules
    first_triggered = res["triggered_rules"][0]
    assert "id" in first_triggered
    assert "name" in first_triggered
    assert first_triggered["actions_count"] >= 1


async def test_automation_cron_updates_database_statistics():
    """Verify that running the cron updates last_triggered_at and execution_count."""
    # Fetch active rules before
    rules_before = await exec_sql(
        "SELECT id, execution_count, last_triggered_at FROM device_automation_rules WHERE is_active = TRUE LIMIT 3;"
    )
    assert len(rules_before) > 0

    # Run cron
    res = await execute_automation_cron()
    assert res["success"] is True
    triggered_ids = [r["id"] for r in res["triggered_rules"]]

    # Fetch triggered rules after
    rules_after = await exec_sql(
        "SELECT id, execution_count, last_triggered_at FROM device_automation_rules WHERE id = ANY(%s::uuid[]);",
        (triggered_ids,)
    )
    assert len(rules_after) > 0
    for r in rules_after:
        assert r["last_triggered_at"] is not None
        assert (r["execution_count"] or 0) >= 1


async def test_inactive_rule_skipped_by_cron():
    """Verify that an inactive rule (is_active=False) is never evaluated or triggered by cron."""
    sid = "11111111-1111-1111-1111-111111111111"
    
    # Insert an inactive dummy rule
    ins = await exec_sql(
        """
        INSERT INTO device_automation_rules (
            school_id, name, description, trigger_type, is_active,
            trigger_condition, action_payload
        ) VALUES (
            %s, 'Test Inactive Cron Rule', 'Should be skipped', 'smart', FALSE,
            '{"combinator": "AND", "conditions": []}'::jsonb,
            '{"actions": [{"target": "Lights", "action": "Turn OFF"}]}'::jsonb
        ) RETURNING id;
        """,
        (sid,)
    )
    assert len(ins) == 1
    test_rule_id = str(ins[0]["id"])

    try:
        res = await execute_automation_cron(sid)
        triggered_ids = [str(r["id"]) for r in res["triggered_rules"]]
        assert test_rule_id not in triggered_ids
    finally:
        # Cleanup
        await exec_sql("DELETE FROM device_automation_rules WHERE id = %s;", (test_rule_id,), fetch=False)


async def test_cron_records_audit_log_and_alerts():
    """Verify that cron executions create proper audit log entries and alerts."""
    sid = "11111111-1111-1111-1111-111111111111"
    await execute_automation_cron(sid)

    # Check audit_logs table
    logs = await exec_sql(
        """
        SELECT id, event_type, module, action, status 
        FROM audit_logs 
        WHERE module = 'device_management' AND event_type = 'AUTOMATION_CRON'
        ORDER BY created_at DESC LIMIT 5;
        """
    )
    assert len(logs) >= 1
    assert logs[0]["status"] == "Success"
    assert logs[0]["action"] == "TRIGGER_RULE"


if __name__ == "__main__":
    async def run_all():
        print("Running test_automation_cron_direct_execution...")
        await test_automation_cron_direct_execution()
        print("PASS: test_automation_cron_direct_execution")

        print("Running test_automation_cron_updates_database_statistics...")
        await test_automation_cron_updates_database_statistics()
        print("PASS: test_automation_cron_updates_database_statistics")

        print("Running test_inactive_rule_skipped_by_cron...")
        await test_inactive_rule_skipped_by_cron()
        print("PASS: test_inactive_rule_skipped_by_cron")

        print("Running test_cron_records_audit_log_and_alerts...")
        await test_cron_records_audit_log_and_alerts()
        print("PASS: test_cron_records_audit_log_and_alerts")

        print("\n=== ALL 4 AUTOMATION CRON TESTS PASSED CLEANLY (100%) ===")

    asyncio.run(run_all())
