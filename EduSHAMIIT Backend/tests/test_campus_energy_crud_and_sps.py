import asyncio
import json
import uuid
import asyncpg

DB_URL = "postgresql://postgres:eduSHAMIIT2026_pg@localhost:54322/postgres"

async def test_energy_stored_procedures():
    print("Connecting to PostgreSQL at localhost:54322...")
    conn = await asyncpg.connect(DB_URL)
    school_id = uuid.UUID("11111111-1111-1111-1111-111111111111")

    try:
        print("\n--- Test 1: sp_get_device_energy_metrics with various filters & sorting ---")
        # 1. Default call
        row = await conn.fetchval("SELECT public.sp_get_device_energy_metrics($1, NULL, NULL, NULL, NULL, NULL, 'energy_kwh', 'desc', 5, 0);", school_id)
        res = json.loads(row) if isinstance(row, str) else row
        assert res["success"] is True, f"Failed: {res}"
        assert res["total"] > 0, "Total count should be > 0"
        print(f"  [PASS] Default pagination: total={res['total']}, returned={len(res['devices'])}")

        # 2. Search filter
        row = await conn.fetchval("SELECT public.sp_get_device_energy_metrics($1, 'AC', NULL, NULL, NULL, NULL, 'device_name', 'asc', 10, 0);", school_id)
        res = json.loads(row) if isinstance(row, str) else row
        assert res["success"] is True
        print(f"  [PASS] Search 'AC' (sorted by device_name asc): found={res['total']}")

        # 3. Usage tier filter (high)
        row = await conn.fetchval("SELECT public.sp_get_device_energy_metrics($1, NULL, NULL, NULL, NULL, 'high', 'energy_kwh', 'desc', 10, 0);", school_id)
        res = json.loads(row) if isinstance(row, str) else row
        assert res["success"] is True
        print(f"  [PASS] Usage tier 'high' (>=100 kWh): found={res['total']}")

        # 4. Invalid sort column fallback check (SQL injection protection)
        row = await conn.fetchval("SELECT public.sp_get_device_energy_metrics($1, NULL, NULL, NULL, NULL, NULL, 'non_existent_col; DROP TABLE test', 'desc', 5, 0);", school_id)
        res = json.loads(row) if isinstance(row, str) else row
        assert res["success"] is True
        print("  [PASS] SQL Injection / invalid sort fallback handled safely.")

        print("\n--- Test 2: sp_get_energy_by_locations ---")
        row = await conn.fetchval("SELECT public.sp_get_energy_by_locations($1, '30d');", school_id)
        res = json.loads(row) if isinstance(row, str) else row
        assert res["success"] is True
        assert len(res["locations"]) > 0
        print(f"  [PASS] Locations aggregated: count={len(res['locations'])}, total_kwh={res['total_campus_kwh']}")

        print("\n--- Test 3: sp_get_energy_by_device_types ---")
        row = await conn.fetchval("SELECT public.sp_get_energy_by_device_types($1, '30d');", school_id)
        res = json.loads(row) if isinstance(row, str) else row
        assert res["success"] is True
        assert len(res["categories"]) > 0
        print(f"  [PASS] Categories aggregated: count={len(res['categories'])}, total_kwh={res['total_kwh']}")

        print("\n--- Test 4: sp_get_energy_trends_comparison ---")
        row = await conn.fetchval("SELECT public.sp_get_energy_trends_comparison($1, 'daily', 'kwh');", school_id)
        res = json.loads(row) if isinstance(row, str) else row
        assert res["success"] is True
        print(f"  [PASS] Trends points returned: {len(res['trend_data'])}")

        print("\n--- Test 5: Tariffs Full CRUD ---")
        # CREATE
        c_row = await conn.fetchval("""
            SELECT public.sp_create_or_update_energy_tariff(
                $1, NULL, 'Solar Provider Inc', 'Campus Green Solar Tariff', 'time_of_use',
                9.5, 12.0, 7.0, '18:00', '22:00', 3000.0, 250.0, 18.0, true
            );
        """, school_id)
        c_res = json.loads(c_row) if isinstance(c_row, str) else c_row
        assert c_res["success"] is True
        tariff_id = uuid.UUID(c_res["tariff_id"])
        print(f"  [PASS] Tariff Created: ID={tariff_id}")

        # UPDATE
        u_row = await conn.fetchval("""
            SELECT public.sp_create_or_update_energy_tariff(
                $1, $2, 'Solar Provider Inc', 'Campus Green Solar Tariff (Updated)', 'time_of_use',
                9.0, 11.5, 6.5, '18:00', '22:00', 3000.0, 250.0, 18.0, true
            );
        """, school_id, tariff_id)
        u_res = json.loads(u_row) if isinstance(u_row, str) else u_row
        assert u_res["success"] is True and u_res["action"] == "updated"
        print("  [PASS] Tariff Updated")

        # DELETE
        d_row = await conn.fetchval("SELECT public.sp_delete_energy_tariff($1, $2);", school_id, tariff_id)
        d_res = json.loads(d_row) if isinstance(d_row, str) else d_row
        assert d_res["success"] is True
        print("  [PASS] Tariff Deleted")

        print("\n--- Test 6: Utility Bills Full CRUD & Reconciliation ---")
        b_num = f"BILL-TEST-{uuid.uuid4().hex[:6]}"
        # CREATE
        b_create = await conn.fetchval("""
            SELECT public.sp_record_or_update_utility_bill(
                $1, NULL, 'BESCOM Test', $2, CURRENT_DATE - 30, CURRENT_DATE,
                15000.0, 180000.0, 15000.0, 5000.0, CURRENT_DATE + 15, 'paid', 'Automated test bill'
            );
        """, school_id, b_num)
        b_res = json.loads(b_create) if isinstance(b_create, str) else b_create
        assert b_res["success"] is True
        bill_id = uuid.UUID(b_res["bill_id"])
        print(f"  [PASS] Utility Bill Created: ID={bill_id}, Variance={b_res['variance_pct']}%")

        # UPDATE
        b_update = await conn.fetchval("""
            SELECT public.sp_record_or_update_utility_bill(
                $1, $2, 'BESCOM Test', $3, CURRENT_DATE - 30, CURRENT_DATE,
                15200.0, 182400.0, 15000.0, 5000.0, CURRENT_DATE + 15, 'paid', 'Re-verified bill'
            );
        """, school_id, bill_id, b_num)
        b_ures = json.loads(b_update) if isinstance(b_update, str) else b_update
        assert b_ures["success"] is True and b_ures["action"] == "updated"
        print("  [PASS] Utility Bill Updated")

        # DELETE
        b_del = await conn.fetchval("SELECT public.sp_delete_utility_bill($1, $2);", school_id, bill_id)
        b_dres = json.loads(b_del) if isinstance(b_del, str) else b_del
        assert b_dres["success"] is True
        print("  [PASS] Utility Bill Deleted")

        print("\n--- Test 7: Smart Energy Meters Full CRUD ---")
        m_code = f"MTR-TEST-{uuid.uuid4().hex[:6]}"
        # REGISTER
        m_reg = await conn.fetchval("""
            SELECT public.sp_register_or_update_energy_meter(
                $1, NULL, 'Test IoT Energy Submeter', $2, 'submeter', 'mqtt',
                'campus/meters/test', '192.168.1.199', 502, 'Academic Block (A)', '2F', 'Lab 201',
                'Academic Block (A) > Second Floor > Lab 201', 1.0, 1.0, 'online'
            );
        """, school_id, m_code)
        m_res = json.loads(m_reg) if isinstance(m_reg, str) else m_reg
        assert m_res["success"] is True
        meter_id = uuid.UUID(m_res["meter_id"])
        print(f"  [PASS] Meter Registered: ID={meter_id}")

        # UPDATE
        m_up = await conn.fetchval("""
            SELECT public.sp_register_or_update_energy_meter(
                $1, $2, 'Test IoT Energy Submeter (Renamed)', $3, 'submeter', 'modbus_tcp',
                'campus/meters/test_up', '192.168.1.200', 502, 'Academic Block (A)', '2F', 'Lab 202',
                'Academic Block (A) > Second Floor > Lab 202', 1.0, 1.0, 'online'
            );
        """, school_id, meter_id, m_code)
        m_ures = json.loads(m_up) if isinstance(m_up, str) else m_up
        assert m_ures["success"] is True and m_ures["action"] == "updated"
        print("  [PASS] Meter Updated")

        # LIST
        m_list = await conn.fetchval("SELECT public.sp_list_energy_meters($1, NULL);", school_id)
        m_lres = json.loads(m_list) if isinstance(m_list, str) else m_list
        assert m_lres["success"] is True and len(m_lres["meters"]) > 0
        print(f"  [PASS] Meters Listed: count={len(m_lres['meters'])}")

        # DELETE
        m_del = await conn.fetchval("SELECT public.sp_delete_energy_meter($1, $2);", school_id, meter_id)
        m_dres = json.loads(m_del) if isinstance(m_del, str) else m_del
        assert m_dres["success"] is True
        print("  [PASS] Meter Deleted")

        print("\n--- Test 8: Energy Reports Full CRUD ---")
        # GENERATE
        r_gen = await conn.fetchval("""
            SELECT public.sp_generate_energy_report(
                $1, 'Test Quarterly Energy Audit', 'quarterly_audit', 'campus', 'All',
                CURRENT_DATE - 90, CURRENT_DATE, 'pdf', 'Test Admin'
            );
        """, school_id)
        r_res = json.loads(r_gen) if isinstance(r_gen, str) else r_gen
        assert r_res["success"] is True
        report_id = uuid.UUID(r_res["report_id"])
        print(f"  [PASS] Energy Report Generated: ID={report_id}")

        # LIST
        r_list = await conn.fetchval("SELECT public.sp_list_energy_reports($1);", school_id)
        r_lres = json.loads(r_list) if isinstance(r_list, str) else r_list
        assert r_lres["success"] is True and len(r_lres["reports"]) > 0
        print(f"  [PASS] Reports Listed: count={len(r_lres['reports'])}")

        # DELETE
        r_del = await conn.fetchval("SELECT public.sp_delete_energy_report($1, $2);", school_id, report_id)
        r_dres = json.loads(r_del) if isinstance(r_del, str) else r_del
        assert r_dres["success"] is True
        print("  [PASS] Energy Report Deleted")

        print("\n--- Test 9: Multi-Device Bulk Energy Actions ---")
        # Fetch 2 device IDs
        d_rows = await conn.fetch("""
            SELECT id FROM public.campus_device_energy_metrics
            WHERE school_id = $1 LIMIT 2;
        """, school_id)
        dev_ids = [r["id"] for r in d_rows]
        assert len(dev_ids) > 0

        # Apply ECO Mode
        eco_act = await conn.fetchval("SELECT public.sp_bulk_apply_device_energy_action($1, $2, 'eco_mode', NULL);", school_id, dev_ids)
        eco_res = json.loads(eco_act) if isinstance(eco_act, str) else eco_act
        assert eco_res["success"] is True and eco_res["affected_count"] == len(dev_ids)
        print(f"  [PASS] Bulk ECO Mode applied to {eco_res['affected_count']} devices")

        # Apply Turn OFF
        off_act = await conn.fetchval("SELECT public.sp_bulk_apply_device_energy_action($1, $2, 'turn_off', NULL);", school_id, dev_ids)
        off_res = json.loads(off_act) if isinstance(off_act, str) else eco_act
        assert off_res["success"] is True and off_res["affected_count"] == len(dev_ids)
        print(f"  [PASS] Bulk Turn OFF applied to {off_res['affected_count']} devices")

        print("\n=======================================================")
        print("ALL 9 STORED PROCEDURES & EDGE CASES PASSED WITH 100% SUCCESS!")
        print("=======================================================")
    finally:
        await conn.close()

if __name__ == "__main__":
    asyncio.run(test_energy_stored_procedures())
