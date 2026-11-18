import asyncio
import pytest
import psycopg2
from typing import Dict, Any

DB_URL = "dbname=postgres user=postgres password=eduSHAMIIT2026_pg host=localhost port=5432"
SCHOOL_ID = "11111111-1111-1111-1111-111111111111"

def test_fn_device_health_dashboard():
    conn = psycopg2.connect(DB_URL)
    cur = conn.cursor()
    cur.execute("SELECT public.fn_device_health_dashboard(%s::UUID);", (SCHOOL_ID,))
    res = cur.fetchone()[0]
    conn.close()

    assert res["success"] is True
    assert "kpis" in res
    assert res["kpis"]["total_devices"] > 0
    assert "healthy_count" in res["kpis"]
    assert "warning_count" in res["kpis"]
    assert "critical_count" in res["kpis"]
    assert "offline_count" in res["kpis"]
    assert "avg_uptime_pct" in res["kpis"]
    assert "health_by_type" in res
    assert isinstance(res["health_by_type"], list)
    assert len(res["health_by_type"]) > 0
    # Verify no mock list, actual categories present
    types = [item["type"] for item in res["health_by_type"]]
    assert any("AC" in t or "HVAC" in t or "Lighting" in t for t in types)
    assert "system_status" in res
    assert "gateways" in res["system_status"]
    assert "health_trend_30_days" in res
    print("test_fn_device_health_dashboard PASSED")

def test_fn_list_device_health_pagination_and_sorting():
    conn = psycopg2.connect(DB_URL)
    cur = conn.cursor()
    
    # 1. Default sort by health_status
    cur.execute("""
        SELECT public.fn_list_device_health(
            %s::UUID, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'health_status', 'ASC', 1, 10
        );
    """, (SCHOOL_ID,))
    res = cur.fetchone()[0]
    assert res["success"] is True
    assert res["total"] > 0
    assert len(res["devices"]) <= 10
    first_device = res["devices"][0]
    assert "device_name" in first_device
    assert "device_type" in first_device
    assert "health_status" in first_device
    assert "location_path" in first_device

    # 2. Sort by device_name DESC
    cur.execute("""
        SELECT public.fn_list_device_health(
            %s::UUID, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'device_name', 'DESC', 1, 5
        );
    """, (SCHOOL_ID,))
    res_desc = cur.fetchone()[0]
    assert res_desc["success"] is True
    assert len(res_desc["devices"]) > 0

    # 3. Filter by search
    cur.execute("""
        SELECT public.fn_list_device_health(
            %s::UUID, 'AC', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'device_name', 'ASC', 1, 10
        );
    """, (SCHOOL_ID,))
    res_search = cur.fetchone()[0]
    assert res_search["success"] is True
    for d in res_search["devices"]:
        assert "ac" in d["device_name"].lower() or "ac" in d["device_type"].lower() or "ac" in d["location_path"].lower()

    conn.close()
    print("test_fn_list_device_health_pagination_and_sorting PASSED")

def test_fn_device_health_filter_options_cascading():
    conn = psycopg2.connect(DB_URL)
    cur = conn.cursor()
    cur.execute("SELECT public.fn_device_health_filter_options(%s::UUID);", (SCHOOL_ID,))
    res = cur.fetchone()[0]
    assert res["success"] is True
    assert len(res["buildings"]) > 0
    assert len(res["device_types"]) > 0
    assert len(res["health_statuses"]) == 4

    # Test cascading with first building
    b_id = res["buildings"][0]["id"]
    cur.execute("SELECT public.fn_device_health_filter_options(%s::UUID, %s::UUID);", (SCHOOL_ID, b_id))
    res_cascaded = cur.fetchone()[0]
    assert res_cascaded["success"] is True
    for f in res_cascaded["floors"]:
        assert f["building_id"] == b_id

    conn.close()
    print("test_fn_device_health_filter_options_cascading PASSED")

def test_sp_run_device_diagnostics():
    conn = psycopg2.connect(DB_URL)
    cur = conn.cursor()
    # Find a device id
    cur.execute("SELECT id FROM public.devices WHERE school_id = %s::UUID AND deleted_at IS NULL LIMIT 1;", (SCHOOL_ID,))
    dev_id = cur.fetchone()[0]

    cur.execute("SELECT public.sp_run_device_diagnostics(%s::UUID, %s::UUID, 'TestRunner');", (SCHOOL_ID, dev_id))
    res = cur.fetchone()[0]
    conn.commit()
    conn.close()

    assert res["success"] is True
    assert res["passed_tests"] == 6
    assert res["total_tests"] == 6
    assert "DIAG-" in res["session_code"]
    print("test_sp_run_device_diagnostics PASSED")

def test_sp_bulk_device_health_action():
    conn = psycopg2.connect(DB_URL)
    cur = conn.cursor()
    cur.execute("SELECT id FROM public.devices WHERE school_id = %s::UUID AND deleted_at IS NULL LIMIT 3;", (SCHOOL_ID,))
    dev_ids = [r[0] for r in cur.fetchall()]

    # Bulk diagnostics
    cur.execute("SELECT public.sp_bulk_device_health_action(%s::UUID, %s::UUID[], 'diagnostics', 'TestRunner');", (SCHOOL_ID, dev_ids))
    res_diag = cur.fetchone()[0]
    assert res_diag["success"] is True
    assert res_diag["affected_devices"] == 3

    # Bulk restart
    cur.execute("SELECT public.sp_bulk_device_health_action(%s::UUID, %s::UUID[], 'restart', 'TestRunner');", (SCHOOL_ID, dev_ids))
    res_rst = cur.fetchone()[0]
    assert res_rst["success"] is True
    assert res_rst["affected_devices"] == 3

    # Bulk firmware update
    cur.execute("""
        SELECT public.sp_bulk_device_health_action(
            %s::UUID, %s::UUID[], 'update_firmware', 'TestRunner', '{"target_version": "v2.5.0"}'::JSONB
        );
    """, (SCHOOL_ID, dev_ids))
    res_fw = cur.fetchone()[0]
    assert res_fw["success"] is True
    assert res_fw["affected_devices"] == 3
    assert res_fw["target_version"] == "v2.5.0"

    conn.commit()
    conn.close()
    print("test_sp_bulk_device_health_action PASSED")

if __name__ == "__main__":
    test_fn_device_health_dashboard()
    test_fn_list_device_health_pagination_and_sorting()
    test_fn_device_health_filter_options_cascading()
    test_sp_run_device_diagnostics()
    test_sp_bulk_device_health_action()
    print("\nALL 5 BACKEND TESTS PASSED SUCCESSFULLY!")
