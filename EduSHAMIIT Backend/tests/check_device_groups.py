import psycopg2

DB_URL = "postgresql://postgres:eduSHAMIIT2026_pg@localhost:54322/postgres"

def main():
    conn = psycopg2.connect(DB_URL)
    cur = conn.cursor()

    cur.execute("SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_name LIKE '%group%';")
    print("Group tables:", cur.fetchall())

    cur.execute("SELECT count(*) FROM device_groups;")
    print("device_groups count:", cur.fetchone())

    cur.execute("SELECT school_id, count(*) FROM device_groups GROUP BY school_id;")
    print("groups by school:", cur.fetchall())

    cur.execute("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'device_groups';")
    print("\ndevice_groups columns:")
    for col in cur.fetchall():
        print(f"  {col[0]}: {col[1]}")

    cur.execute("SELECT id, name, group_type, is_active, school_id FROM device_groups LIMIT 5;")
    print("\nSample device_groups:")
    for row in cur.fetchall():
        print(f"  {row}")

    cur.close()
    conn.close()

if __name__ == "__main__":
    main()
