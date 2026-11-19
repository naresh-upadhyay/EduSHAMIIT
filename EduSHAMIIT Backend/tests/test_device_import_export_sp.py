import pytest
import psycopg2
from psycopg2.extras import RealDictCursor
import json
import uuid

DB_URL = "postgresql://postgres:eduSHAMIIT2026_pg@localhost:54322/postgres"

def get_db():
    conn = psycopg2.connect(DB_URL)
    conn.autocommit = True
    return conn

def test_fn_get_import_export_dashboard():
    conn = get_db()
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute("SELECT public.fn_get_import_export_dashboard() AS res;")
        row = cur.fetchone()
        assert row is not None
        res = row["res"]
        assert res["success"] is True
        assert "metrics" in res
        metrics = res["metrics"]
        assert metrics["total_operations"] >= 10
        assert "imports_count" in metrics
        assert "exports_count" in metrics
        assert "trends" in res
        assert len(res["trends"]) > 0
        assert "templates" in res
        assert "supported_operations" in res
        assert "file_formats" in res
    conn.close()

def test_fn_list_import_export_history_pagination_and_filter():
    conn = get_db()
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        # Default query
        cur.execute("SELECT public.fn_list_import_export_history() AS res;")
        res = cur.fetchone()["res"]
        assert res["success"] is True
        assert res["total_count"] >= 10
        assert len(res["operations"]) <= 10

        # Filter by Import
        cur.execute("SELECT public.fn_list_import_export_history(p_operation_type => 'Import') AS res;")
        res_import = cur.fetchone()["res"]
        assert res_import["success"] is True
        for op in res_import["operations"]:
            assert op["type"] == "Import"

        # Filter by Export
        cur.execute("SELECT public.fn_list_import_export_history(p_operation_type => 'Export') AS res;")
        res_export = cur.fetchone()["res"]
        assert res_export["success"] is True
        for op in res_export["operations"]:
            assert op["type"] == "Export"
    conn.close()

def test_fn_list_import_export_history_sorting():
    conn = get_db()
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        # Sort by records asc
        cur.execute("SELECT public.fn_list_import_export_history(p_sort_by => 'records', p_sort_asc => true) AS res;")
        res_asc = cur.fetchone()["res"]
        ops_asc = res_asc["operations"]
        if len(ops_asc) >= 2:
            assert ops_asc[0]["records"] <= ops_asc[-1]["records"]

        # Sort by records desc
        cur.execute("SELECT public.fn_list_import_export_history(p_sort_by => 'records', p_sort_asc => false) AS res;")
        res_desc = cur.fetchone()["res"]
        ops_desc = res_desc["operations"]
        if len(ops_desc) >= 2:
            assert ops_desc[0]["records"] >= ops_desc[-1]["records"]
    conn.close()

def test_fn_list_import_export_templates_and_schedules():
    conn = get_db()
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute("SELECT public.fn_list_import_export_templates() AS res;")
        res = cur.fetchone()["res"]
        assert res["success"] is True
        assert isinstance(res["templates"], list)

        cur.execute("SELECT public.fn_list_import_export_schedules() AS res;")
        res_sch = cur.fetchone()["res"]
        assert res_sch["success"] is True
        assert isinstance(res_sch["schedules"], list)
    conn.close()

def test_sp_execute_and_delete_import_export_operation():
    conn = get_db()
    test_op_id = f"TEST-EXP-{uuid.uuid4().hex[:6].upper()}"
    school_id = "11111111-1111-1111-1111-111111111111"

    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        # Insert via stored procedure
        cur.execute(
            """
            CALL public.sp_execute_import_export_operation(
                %s::UUID, %s, 'Export', 'Device Registry', 'test_export.xlsx', 'XLSX',
                50, 50, 0, 'PyTest User', NULL, 'Completed', '/api/v1/download/test', '{"test": true}'::jsonb
            );
            """,
            (school_id, test_op_id)
        )

        # Verify operation is listed
        cur.execute("SELECT public.fn_list_import_export_history(p_search => %s) AS res;", (test_op_id,))
        res = cur.fetchone()["res"]
        assert res["total_count"] >= 1
        found = any(o["operation_id"] == test_op_id for o in res["operations"])
        assert found is True

        # Delete via stored procedure
        cur.execute(
            "CALL public.sp_delete_import_export_operation(%s::UUID, %s);",
            (school_id, test_op_id)
        )

        # Verify deleted
        cur.execute("SELECT public.fn_list_import_export_history(p_search => %s) AS res;", (test_op_id,))
        res_after = cur.fetchone()["res"]
        found_after = any(o["operation_id"] == test_op_id for o in res_after["operations"])
        assert found_after is False
    conn.close()

def test_sp_bulk_import_export_action():
    conn = get_db()
    school_id = "11111111-1111-1111-1111-111111111111"
    op1 = f"BULK-1-{uuid.uuid4().hex[:4].upper()}"
    op2 = f"BULK-2-{uuid.uuid4().hex[:4].upper()}"

    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        for op in [op1, op2]:
            cur.execute(
                """
                CALL public.sp_execute_import_export_operation(
                    %s::UUID, %s, 'Import', 'Devices', 'test_bulk.csv', 'CSV',
                    10, 10, 0, 'Bulk Tester', NULL, 'Completed', NULL, '{}'::jsonb
                );
                """,
                (school_id, op)
            )

        # Bulk delete
        cur.execute(
            "CALL public.sp_bulk_import_export_action(%s::UUID, 'delete', %s::text[]);",
            (school_id, [op1, op2])
        )

        # Verify deleted
        cur.execute("SELECT public.fn_list_import_export_history(p_search => %s) AS res;", ("BULK-",))
        res = cur.fetchone()["res"]
        assert not any(o["operation_id"] in [op1, op2] for o in res["operations"])
    conn.close()

def test_sp_create_and_toggle_schedule():
    conn = get_db()
    school_id = "11111111-1111-1111-1111-111111111111"
    sch_name = f"Pytest Schedule {uuid.uuid4().hex[:4]}"

    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        # Create schedule
        cur.execute(
            """
            CALL public.sp_create_import_export_schedule(
                %s::UUID, %s, 'Device Registry', 'XLSX', 'Weekly', '0 3 * * 1', 'Storage & Email', 'qa@edushamiit.edu'
            );
            """,
            (school_id, sch_name)
        )

        # Fetch schedule id
        cur.execute("SELECT public.fn_list_import_export_schedules() AS res;")
        schedules = cur.fetchone()["res"]["schedules"]
        target = next((s for s in schedules if s["name"] == sch_name), None)
        assert target is not None
        assert target["is_enabled"] is True

        # Toggle schedule to false
        cur.execute(
            "CALL public.sp_toggle_import_export_schedule(%s::UUID, %s::UUID, false);",
            (school_id, target["id"])
        )

        # Verify toggled
        cur.execute("SELECT public.fn_list_import_export_schedules() AS res;")
        schedules_after = cur.fetchone()["res"]["schedules"]
        target_after = next((s for s in schedules_after if s["id"] == target["id"]), None)
        assert target_after is not None
        assert target_after["is_enabled"] is False

        # Cleanup
        cur.execute("DELETE FROM public.enterprise_scheduled_exports WHERE id = %s::UUID;", (target["id"],))
    conn.close()
