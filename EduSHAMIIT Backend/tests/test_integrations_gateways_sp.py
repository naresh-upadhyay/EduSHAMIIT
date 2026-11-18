# ============================================================================
# Backend Stored Procedures & Functions Test Suite
# Integrations & Gateways Module - EduSHAMIIT
# ============================================================================

import psycopg2
import json

DB_URL = "postgresql://postgres:eduSHAMIIT2026_pg@localhost:5432/postgres"
SCHOOL_ID = "11111111-1111-1111-1111-111111111111"

def get_connection():
    conn = psycopg2.connect(DB_URL)
    conn.autocommit = True
    return conn

def test_fn_integrations_gateways_dashboard():
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("SELECT public.fn_integrations_gateways_dashboard(%s);", (SCHOOL_ID,))
    res = cur.fetchone()[0]
    assert res["success"] is True, "fn_integrations_gateways_dashboard failed"
    kpis = res["kpis"]
    assert kpis["total_gateways"] >= 8, f"Expected at least 8 gateways, got {kpis['total_gateways']}"
    assert "online_gateways" in kpis
    assert "data_throughput" in kpis
    assert len(res["protocols"]) >= 6, "Expected at least 6 protocols"
    assert len(res["integration_health_items"]) >= 6, "Expected at least 6 health items"
    print("test_fn_integrations_gateways_dashboard PASSED")
    conn.close()

def test_fn_integrations_gateways_filter_options():
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("SELECT public.fn_integrations_gateways_filter_options(%s);", (SCHOOL_ID,))
    res = cur.fetchone()[0]
    assert res["success"] is True
    assert len(res["buildings"]) >= 1, "Expected buildings"
    assert len(res["protocols"]) >= 5, "Expected protocols"
    assert len(res["statuses"]) >= 3, "Expected statuses"

    # Test cascading with first building
    b_id = res["buildings"][0]["id"]
    cur.execute("SELECT public.fn_integrations_gateways_filter_options(%s, %s);", (SCHOOL_ID, b_id))
    cascaded = cur.fetchone()[0]
    assert cascaded["success"] is True
    for f in cascaded["floors"]:
        assert f["building_id"] == b_id, "Floor building_id must match cascaded building"
    print("test_fn_integrations_gateways_filter_options PASSED")
    conn.close()

def test_fn_list_campus_gateways_pagination_and_sorting():
    conn = get_connection()
    cur = conn.cursor()

    # Page 1 with limit 5, sort ASC by gateway_name
    cur.execute(
        "SELECT public.fn_list_campus_gateways(%s, NULL, NULL, NULL, NULL, NULL, NULL, NULL, %s, %s, %s, %s);",
        (SCHOOL_ID, "gateway_name", "ASC", 5, 0)
    )
    p1 = cur.fetchone()[0]
    assert p1["success"] is True
    assert p1["total"] >= 8
    assert len(p1["gateways"]) == 5

    # Page 2
    cur.execute(
        "SELECT public.fn_list_campus_gateways(%s, NULL, NULL, NULL, NULL, NULL, NULL, NULL, %s, %s, %s, %s);",
        (SCHOOL_ID, "gateway_name", "ASC", 5, 5)
    )
    p2 = cur.fetchone()[0]
    assert p2["success"] is True
    assert len(p2["gateways"]) >= 1
    assert p1["gateways"][0]["id"] != p2["gateways"][0]["id"]

    # Filter by search
    cur.execute(
        "SELECT public.fn_list_campus_gateways(%s, %s, NULL, NULL, NULL, NULL, NULL, NULL, %s, %s, %s, %s);",
        (SCHOOL_ID, "Main Block", "gateway_name", "ASC", 10, 0)
    )
    filtered = cur.fetchone()[0]
    assert filtered["success"] is True
    assert filtered["total"] >= 1
    for gw in filtered["gateways"]:
        assert "main block" in gw["gateway_name"].lower() or "main block" in gw["location_path"].lower()

    print("test_fn_list_campus_gateways_pagination_and_sorting PASSED")
    conn.close()

def test_sp_register_update_delete_gateway():
    conn = get_connection()
    cur = conn.cursor()

    # Register
    cur.execute(
        "SELECT public.sp_register_campus_gateway(%s, %s, %s, %s, %s, %s, NULL, NULL, NULL, %s, '{}'::jsonb);",
        (SCHOOL_ID, "Test QA Gateway", "edge_router", "192.168.10.99", "00:1A:2B:3C:4D:99", "MQTT, Zigbee", "Test Block > Server Room")
    )
    reg = cur.fetchone()[0]
    assert reg["success"] is True
    gw_id = reg["gateway"]["id"]

    # Profile
    cur.execute("SELECT public.fn_get_gateway_profile(%s, %s);", (SCHOOL_ID, gw_id))
    prof = cur.fetchone()[0]
    assert prof["success"] is True
    assert prof["gateway"]["gateway_name"] == "Test QA Gateway"

    # Update
    cur.execute(
        "SELECT public.sp_update_campus_gateway(%s, %s, %s, %s, %s, %s, %s, %s, %s, '{}'::jsonb);",
        (SCHOOL_ID, gw_id, "Test QA Gateway Updated", "edge_router", "192.168.10.100", "00:1A:2B:3C:4D:99", "MQTT", "Test Block > Rack 2", "v2.5.0")
    )
    upd = cur.fetchone()[0]
    assert upd["success"] is True
    assert upd["gateway"]["gateway_name"] == "Test QA Gateway Updated"

    # Delete
    cur.execute("SELECT public.sp_delete_campus_gateway(%s, %s);", (SCHOOL_ID, gw_id))
    del_res = cur.fetchone()[0]
    assert del_res["success"] is True

    print("test_sp_register_update_delete_gateway PASSED")
    conn.close()

def test_sp_bulk_gateway_action():
    conn = get_connection()
    cur = conn.cursor()

    # Fetch 2 gateways to test bulk restart and firmware update
    cur.execute("SELECT id FROM public.campus_iot_gateways WHERE school_id = %s LIMIT 2;", (SCHOOL_ID,))
    rows = cur.fetchall()
    g_ids = [r[0] for r in rows]
    assert len(g_ids) == 2

    # Bulk restart
    cur.execute(
        "SELECT public.sp_bulk_gateway_action(%s, %s, %s::uuid[], '{}'::jsonb);",
        (SCHOOL_ID, "restart", g_ids)
    )
    b_res = cur.fetchone()[0]
    assert b_res["success"] is True
    assert b_res["affected_count"] == 2

    # Bulk firmware update
    cur.execute(
        "SELECT public.sp_bulk_gateway_action(%s, %s, %s::uuid[], '{\"target_version\": \"v2.5.1\"}'::jsonb);",
        (SCHOOL_ID, "update_firmware", g_ids)
    )
    fw_res = cur.fetchone()[0]
    assert fw_res["success"] is True
    assert fw_res["affected_count"] == 2

    print("test_sp_bulk_gateway_action PASSED")
    conn.close()

def test_fn_list_iot_integrations_and_test():
    conn = get_connection()
    cur = conn.cursor()

    # List integrations
    cur.execute("SELECT public.fn_list_iot_integrations(%s, NULL, NULL, NULL, NULL, %s, %s, %s, %s);", (SCHOOL_ID, "name", "ASC", 10, 0))
    res = cur.fetchone()[0]
    assert res["success"] is True
    assert res["total"] >= 6
    first_integ_id = res["integrations"][0]["id"]

    # Test integration connection
    cur.execute("SELECT public.sp_test_iot_integration(%s, %s);", (SCHOOL_ID, first_integ_id))
    t_res = cur.fetchone()[0]
    assert t_res["success"] is True
    assert t_res["response_code"] == 200

    print("test_fn_list_iot_integrations_and_test PASSED")
    conn.close()

if __name__ == "__main__":
    test_fn_integrations_gateways_dashboard()
    test_fn_integrations_gateways_filter_options()
    test_fn_list_campus_gateways_pagination_and_sorting()
    test_sp_register_update_delete_gateway()
    test_sp_bulk_gateway_action()
    test_fn_list_iot_integrations_and_test()
    print("\nALL 6 BACKEND TESTS PASSED SUCCESSFULLY!")
