import psycopg2
import json

DB_URL = "postgresql://postgres:eduSHAMIIT2026_pg@localhost:54322/postgres"

def main():
    conn = psycopg2.connect(DB_URL)
    conn.autocommit = True
    cursor = conn.cursor()

    print("Reading migration 518...")
    with open("EduSHAMIIT Database/edushamiit-db/migrations/518_device_types_and_profiles_stored_procedures.sql", "r", encoding="utf-8") as f:
        sql = f.read()

    print("Applying migration 518...")
    cursor.execute(sql)
    print("Migration 518 applied successfully!")

    school_id = "11111111-1111-1111-1111-111111111111"

    # 1. Test KPIs
    cursor.execute("SELECT fn_device_types_and_profiles_kpis(%s::UUID);", (school_id,))
    kpis = cursor.fetchone()[0]
    print("\n--- 1. KPIs ---")
    print(json.dumps(kpis, indent=2))

    # 2. Test fn_device_types_list with various sorts
    print("\n--- 2. Device Types List (Sort by name ASC) ---")
    cursor.execute("SELECT fn_device_types_list(%s::UUID, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, 1, 5, 'name', 'asc');", (school_id,))
    res_asc = cursor.fetchone()[0]
    print(f"Total count: {res_asc.get('total_count')}, Items returned: {len(res_asc.get('items', []))}")
    for item in res_asc.get('items', []):
        print(f" - {item.get('name')} | Cat: {item.get('category_name')} | Mapped: {item.get('mapped_devices_count')}")

    print("\n--- Device Types List (Sort by mapped_devices DESC) ---")
    cursor.execute("SELECT fn_device_types_list(%s::UUID, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, 1, 5, 'mapped_devices', 'desc');", (school_id,))
    res_desc = cursor.fetchone()[0]
    for item in res_desc.get('items', []):
        print(f" - {item.get('name')} | Mapped: {item.get('mapped_devices_count')}")

    # 3. Test fn_device_profiles_list
    print("\n--- 3. Device Profiles List ---")
    cursor.execute("SELECT fn_device_profiles_list(%s::UUID, NULL::UUID, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, 1, 5, 'name', 'asc');", (school_id,))
    res_prof = cursor.fetchone()[0]
    print(f"Total profiles: {res_prof.get('total_count')}, Items returned: {len(res_prof.get('items', []))}")
    for item in res_prof.get('items', []):
        print(f" - {item.get('name')} | Device Type: {item.get('device_type_name')} | Usage: {item.get('usage_count')}")

    # 4. Test fn_get_device_categories
    print("\n--- 4. Categories ---")
    cursor.execute("SELECT fn_get_device_categories(%s::UUID);", (school_id,))
    categories = cursor.fetchone()[0]
    print(f"Categories returned: {categories}")

    cursor.close()
    conn.close()
    print("\nAll SP tests completed successfully!")

if __name__ == "__main__":
    main()
