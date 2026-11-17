import psycopg2

def run():
    print("Connecting to postgres...")
    conn = psycopg2.connect('postgresql://postgres:eduSHAMIIT2026_pg@localhost:54322/postgres')
    conn.autocommit = True
    cur = conn.cursor()

    migration_file = 'EduSHAMIIT Database/edushamiit-db/migrations/519_device_groups_stored_procedures.sql'
    with open(migration_file, 'r', encoding='utf-8') as f:
        sql = f.read()

    print(f"Applying {migration_file}...")
    cur.execute(sql)
    print("Migration 519 applied successfully!")

    # Verify functions exist
    cur.execute("""
        SELECT proname, proargnames 
        FROM pg_proc 
        WHERE proname IN (
            'fn_device_groups_kpis',
            'fn_device_groups_list',
            'fn_get_device_groups_filter_options',
            'sp_create_device_group',
            'sp_update_device_group',
            'sp_delete_device_group',
            'sp_bulk_delete_device_groups',
            'sp_bulk_toggle_device_groups_status'
        );
    """)
    rows = cur.fetchall()
    print(f"Verified {len(rows)} procedures:")
    for r in rows:
        print(" -", r[0])

if __name__ == '__main__':
    run()
