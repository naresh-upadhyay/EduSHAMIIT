import psycopg2
import json
import uuid

def test_device_groups():
    conn = psycopg2.connect('postgresql://postgres:eduSHAMIIT2026_pg@localhost:54322/postgres')
    conn.autocommit = True
    cur = conn.cursor()
    school_id = '11111111-1111-1111-1111-111111111111'

    print("--- 1. Testing fn_device_groups_kpis ---")
    cur.execute("SELECT fn_device_groups_kpis(%s::UUID);", (school_id,))
    kpis = cur.fetchone()[0]
    print("KPIs:", json.dumps(kpis, indent=2))
    assert kpis["total_groups"] == 128, f"Expected 128 total groups, got {kpis['total_groups']}"
    assert kpis["active_groups"] == 118, f"Expected 118 active groups, got {kpis['active_groups']}"
    assert kpis["inactive_groups"] == 10, f"Expected 10 inactive groups, got {kpis['inactive_groups']}"
    assert kpis["active_percentage"] == 92.2, f"Expected 92.2% active, got {kpis['active_percentage']}"

    print("--- 2. Testing fn_device_groups_list with various status strings ---")
    # All groups (128)
    cur.execute("SELECT fn_device_groups_list(%s::UUID, %s, NULL, NULL, NULL, NULL, 1, 10, 'created_at', 'DESC');", (school_id, 'All Groups (128)'))
    res_all = cur.fetchone()[0]
    print(f"Status 'All Groups (128)': total={res_all['total']}, items={len(res_all['groups'])}")
    assert res_all["total"] == 128, f"Expected 128, got {res_all['total']}"
    assert len(res_all["groups"]) == 10, f"Expected 10 items on page 1, got {len(res_all['groups'])}"

    # Active (118)
    cur.execute("SELECT fn_device_groups_list(%s::UUID, %s, NULL, NULL, NULL, NULL, 1, 10, 'created_at', 'DESC');", (school_id, 'Active (118)'))
    res_act = cur.fetchone()[0]
    print(f"Status 'Active (118)': total={res_act['total']}, items={len(res_act['groups'])}")
    assert res_act["total"] == 118, f"Expected 118, got {res_act['total']}"

    # Inactive (10)
    cur.execute("SELECT fn_device_groups_list(%s::UUID, %s, NULL, NULL, NULL, NULL, 1, 10, 'created_at', 'DESC');", (school_id, 'Inactive (10)'))
    res_inact = cur.fetchone()[0]
    print(f"Status 'Inactive (10)': total={res_inact['total']}, items={len(res_inact['groups'])}")
    assert res_inact["total"] == 10, f"Expected 10, got {res_inact['total']}"

    print("--- 3. Testing sorting ---")
    # Sort by name ASC
    cur.execute("SELECT fn_device_groups_list(%s::UUID, NULL, NULL, NULL, NULL, NULL, 1, 5, 'name', 'ASC');", (school_id,))
    res_name_asc = cur.fetchone()[0]
    names_asc = [g["name"] for g in res_name_asc["groups"]]
    print("Names ASC:", names_asc)
    assert names_asc == sorted(names_asc, key=lambda x: x.lower()), "Names should be sorted ASC"

    # Sort by devices DESC
    cur.execute("SELECT fn_device_groups_list(%s::UUID, NULL, NULL, NULL, NULL, NULL, 1, 5, 'devices', 'DESC');", (school_id,))
    res_dev_desc = cur.fetchone()[0]
    counts_desc = [g["member_count"] for g in res_dev_desc["groups"]]
    print("Devices DESC:", counts_desc)
    assert counts_desc == sorted(counts_desc, reverse=True), "Devices should be sorted DESC"

    print("--- 4. Testing fn_get_device_groups_filter_options ---")
    cur.execute("SELECT fn_get_device_groups_filter_options(%s::UUID);", (school_id,))
    filters = cur.fetchone()[0]
    print(f"Locations ({len(filters['locations'])}): {filters['locations'][:3]}...")
    print(f"Group types ({len(filters['group_types'])}): {filters['group_types']}")
    print(f"Profiles ({len(filters['profiles'])}): {filters['profiles'][:3]}...")
    assert len(filters["locations"]) > 0, "Locations should not be empty"
    assert len(filters["group_types"]) > 0, "Group types should not be empty"
    assert len(filters["profiles"]) > 0, "Profiles should not be empty"

    print("--- 5. Testing CRUD stored procedures ---")
    test_name = f"Test Group {uuid.uuid4().hex[:6]}"
    cur.execute("""
        SELECT sp_create_device_group(
            %s::UUID, %s, NULL, 'Test Description', 'Lighting', 'Academic Block', 'Default Lighting', '#10B981', 'lightbulb', 'active', NULL
        );
    """, (school_id, test_name))
    created = cur.fetchone()[0]
    print("Created group:", created)
    assert created["success"] is True
    created_id = created["group"]["id"]

    # Update group
    updated_name = test_name + " Updated"
    cur.execute("""
        SELECT sp_update_device_group(
            p_group_id := %s::UUID,
            p_school_id := %s::UUID,
            p_name := %s,
            p_description := 'Updated Description',
            p_group_type := 'Security',
            p_status := 'inactive'
        );
    """, (created_id, school_id, updated_name))
    updated = cur.fetchone()[0]
    print("Updated group:", updated)
    assert updated["success"] is True
    assert updated["group"]["name"] == updated_name
    assert updated["group"]["status"] == "inactive"

    # Bulk status toggle
    cur.execute("""
        SELECT sp_bulk_toggle_device_groups_status(
            %s::UUID, ARRAY[%s::UUID], 'active'
        );
    """, (school_id, created_id))
    toggled = cur.fetchone()[0]
    print("Bulk toggle:", toggled)
    assert toggled["success"] is True
    assert toggled["updated_count"] == 1

    # Delete group
    cur.execute("""
        SELECT sp_delete_device_group(%s::UUID, %s::UUID);
    """, (created_id, school_id))
    deleted = cur.fetchone()[0]
    print("Deleted group:", deleted)
    assert deleted["success"] is True

    print("\n>>> ALL STORED PROCEDURE TESTS PASSED SUCCESSFULLY! <<<")

if __name__ == '__main__':
    test_device_groups()
