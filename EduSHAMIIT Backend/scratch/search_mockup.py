import psycopg2

try:
    conn = psycopg2.connect(
        host='127.0.0.1',
        port=5432,
        dbname='postgres',
        user='supabase_admin',
        password='eduSHAMIIT2026_pg'
    )
    print("SUCCESS: Connected to DB 'postgres' with user 'supabase_admin'")
except Exception as e:
    print("ERROR: Could not connect:", e)
    import sys
    sys.exit(1)

with conn.cursor() as cur:
    # Query profiles (teachers)
    cur.execute("SELECT id, role, full_name, email FROM profiles WHERE role IN ('teacher', 'admin', 'student_admin') LIMIT 20;")
    print("\nPROFILES:")
    for row in cur.fetchall():
        print(row)

    # Query subjects
    cur.execute("SELECT id, name, class, color, icon FROM subjects LIMIT 20;")
    print("\nSUBJECTS:")
    for row in cur.fetchall():
        print(row)

conn.close()
