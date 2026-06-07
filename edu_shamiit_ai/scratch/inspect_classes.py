import psycopg2

try:
    conn = psycopg2.connect(
        host="db",
        port=5432,
        user="postgres",
        password="eduSHAMIIT2026_pg",
        database="postgres"
    )
    cur = conn.cursor()
    cur.execute("SELECT id, title, scheduled_at, duration_minutes, status, platform, meeting_link, teacher_id FROM live_classes ORDER BY scheduled_at DESC;")
    rows = cur.fetchall()
    print("Live Classes in Database:")
    for row in rows:
        print(f"ID: {row[0]}")
        print(f"  Title: {row[1]}")
        print(f"  Scheduled At: {row[2]}")
        print(f"  Duration: {row[3]}")
        print(f"  Status: {row[4]}")
        print(f"  Platform: {row[5]}")
        print(f"  Meeting Link: {row[6]}")
        print(f"  Teacher ID: {row[7]}")
        print("-" * 50)
    cur.close()
    conn.close()
except Exception as e:
    print(f"Error: {e}")
