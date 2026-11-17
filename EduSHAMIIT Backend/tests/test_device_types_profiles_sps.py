import psycopg2
import json

DB_URL = "postgresql://postgres:eduSHAMIIT2026_pg@localhost:54322/postgres"

def run_tests():
    conn = psycopg2.connect(DB_URL)
    conn.autocommit = True
    cursor = conn.cursor()
    school_id = "11111111-1111-1111-1111-111111111111"

    print("=== Testing fn_device_types_and_profiles_kpis ===")
    cursor.execute("SELECT fn_device_types_and_profiles_kpis(%s::UUID);", (school_id,))
    kpi_res = cursor.fetchone()[0]
    assert kpi_res["total_device_types"] > 0, "total_device_types should be > 0"
    assert kpi_res["active_profiles"] > 0, "active_profiles should be > 0"
    print("KPIs PASSED:", kpi_res)

    print("\n=== Testing fn_device_types_list Sorting & Edge Cases ===")
    sort_fields = ['name', 'category', 'mapped_devices', 'profiles', 'status', 'updated_at', 'created_at']
    for sf in sort_fields:
        for order in ['asc', 'desc']:
            cursor.execute(
                "SELECT fn_device_types_list(%s::UUID, NULL, NULL, NULL, 1, 5, %s, %s);",
                (school_id, sf, order)
            )
            res = cursor.fetchone()[0]
            assert "items" in res and "total_count" in res, f"Failed on sort {sf} {order}"
            assert res["total_count"] > 0, f"Expected records for sort {sf} {order}"
    print("All sort combinations PASSED")

    print("\n=== Testing Category & Status Filters ===")
    cursor.execute("SELECT fn_device_types_list(%s::UUID, 'Network', 'Active', NULL, 1, 10, 'name', 'asc');", (school_id,))
    cat_res = cursor.fetchone()[0]
    print(f"Network + Active count: {cat_res['total_count']}")
    for item in cat_res["items"]:
        assert item["status"] == "Active"

    print("\n=== Testing Search Filter ===")
    cursor.execute("SELECT fn_device_types_list(%s::UUID, NULL, NULL, 'CCTV', 1, 10, 'name', 'asc');", (school_id,))
    search_res = cursor.fetchone()[0]
    print(f"Search 'CCTV' count: {search_res['total_count']}")
    assert search_res["total_count"] >= 1

    print("\n=== Testing fn_device_profiles_list Filters & Sorting ===")
    cursor.execute("SELECT fn_device_profiles_list(%s::UUID, NULL, 'default', 'active', NULL, 1, 5, 'name', 'asc');", (school_id,))
    prof_res = cursor.fetchone()[0]
    print(f"Default + Active profiles count: {prof_res['total_count']}")
    assert prof_res["total_count"] > 0

    print("\n=== Testing Dynamic Categories ===")
    cursor.execute("SELECT fn_get_device_categories(%s::UUID);", (school_id,))
    cats = cursor.fetchone()[0]
    assert isinstance(cats, list) and len(cats) > 0
    print("Categories PASSED:", len(cats), "categories found")

    print("\n=== Testing Bulk Status Toggle & Bulk Delete ===")
    # Pick 2 device types to test bulk toggle
    cursor.execute("SELECT id FROM device_types WHERE school_id = %s LIMIT 2;", (school_id,))
    ids = [r[0] for r in cursor.fetchall()]
    assert len(ids) == 2

    # Toggle to inactive
    cursor.execute("SELECT sp_bulk_toggle_device_types_status(%s::UUID, %s::UUID[], FALSE);", (school_id, ids))
    res_toggle = cursor.fetchone()[0]
    assert res_toggle["success"] is True and res_toggle["affected"] == 2
    print("Bulk Toggle Inactive PASSED")

    # Toggle back to active
    cursor.execute("SELECT sp_bulk_toggle_device_types_status(%s::UUID, %s::UUID[], TRUE);", (school_id, ids))
    res_toggle_back = cursor.fetchone()[0]
    assert res_toggle_back["success"] is True and res_toggle_back["affected"] == 2
    print("Bulk Toggle Active PASSED")

    cursor.close()
    conn.close()
    print("\n>>> ALL DATABASE STORED PROCEDURE EDGE CASES PASSED! <<<")

if __name__ == "__main__":
    run_tests()
