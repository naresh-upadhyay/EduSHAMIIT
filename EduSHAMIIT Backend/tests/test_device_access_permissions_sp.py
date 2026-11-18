import pytest
import psycopg2
import json

def get_db_connection():
    return psycopg2.connect(
        dbname="postgres",
        user="postgres",
        password="eduSHAMIIT2026_pg",
        host="localhost",
        port=5432
    )

def test_device_access_dashboard():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT public.fn_device_access_permissions_dashboard(NULL);")
    res = cur.fetchone()[0]
    conn.close()

    assert res["success"] is True
    kpis = res["kpis"]
    assert "total_users" in kpis
    assert "total_roles" in kpis
    assert kpis["total_users"] > 0
    assert kpis["total_roles"] > 0
    assert isinstance(res["role_distribution"], list)

def test_device_access_dropdown_options():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT public.fn_device_access_dropdown_options(NULL);")
    res = cur.fetchone()[0]
    conn.close()

    assert res["success"] is True
    roles = res["roles"]
    users = res["users"]
    locations = res["locations"]
    assert len(roles) > 0
    assert len(users) > 0
    # Verify user contains canonical profile fields
    user0 = users[0]
    assert "id" in user0
    assert "full_name" in user0
    assert "role" in user0
    assert "email" in user0

def test_list_device_roles():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT public.fn_list_device_roles(NULL, NULL, NULL, 'priority', false, 1, 10);")
    res = cur.fetchone()[0]
    conn.close()

    assert res["success"] is True
    assert res["total_count"] > 0
    roles = res["roles"]
    assert len(roles) > 0
    first_role = roles[0]
    assert "role_name" in first_role
    assert "users_count" in first_role
    assert "key_permissions" in first_role

def test_list_device_user_access():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT public.fn_list_device_user_access(NULL, NULL, NULL, NULL, NULL, 'user_name', true, 1, 10);")
    res = cur.fetchone()[0]
    conn.close()

    assert res["success"] is True
    assert res["total_count"] > 0
    users = res["users"]
    assert len(users) > 0
    first_user = users[0]
    assert "user_name" in first_user
    assert "role_name" in first_user
    assert "location_scope" in first_user
    assert "status" in first_user

def test_assign_and_revoke_user_access():
    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute("SELECT public.fn_device_access_dropdown_options(NULL);")
    opts = cur.fetchone()[0]
    user_id = opts["users"][0]["id"]
    role_id = opts["roles"][0]["id"]

    # Assign
    cur.execute(
        "SELECT public.sp_assign_device_user_access(%s::UUID, %s::UUID, %s, NULL, %s, %s::JSONB, %s);",
        (user_id, role_id, "Academic Block (A)", "Full Control", json.dumps([]), "Active")
    )
    assign_res = cur.fetchone()[0]
    assert assign_res["success"] is True
    assert assign_res["user_id"] == user_id

    # Revoke
    cur.execute("SELECT public.sp_revoke_device_user_access(%s::UUID);", (user_id,))
    revoke_res = cur.fetchone()[0]
    assert revoke_res["success"] is True

    conn.close()

def test_bulk_device_user_access_action():
    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute("SELECT public.fn_device_access_dropdown_options(NULL);")
    opts = cur.fetchone()[0]
    user_id = opts["users"][0]["id"]

    cur.execute(
        "SELECT public.sp_bulk_device_user_access_action(%s, %s::UUID[], NULL, %s);",
        ("activate", [user_id], "All Locations")
    )
    bulk_res = cur.fetchone()[0]
    conn.close()

    assert bulk_res["success"] is True
    assert bulk_res["action"] == "activate"

if __name__ == "__main__":
    test_device_access_dashboard()
    test_device_access_dropdown_options()
    test_list_device_roles()
    test_list_device_user_access()
    test_assign_and_revoke_user_access()
    test_bulk_device_user_access_action()
    print("All 6 backend tests passed successfully!")
