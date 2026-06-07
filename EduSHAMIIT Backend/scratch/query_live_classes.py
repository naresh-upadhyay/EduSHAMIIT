import psycopg2

conn = psycopg2.connect(
    host='db',
    port=5432,
    dbname='postgres',
    user='postgres',
    password='eduSHAMIIT2026_pg'
)

try:
    with conn.cursor() as cursor:
        cursor.execute("SELECT id, title, status, stream_url, recording_url, platform, class FROM live_classes;")
        rows = cursor.fetchall()
        for row in rows:
            print(dict(zip([
                "id", "title", "status", "stream_url", "recording_url", "platform", "class"
            ], row)))
finally:
    conn.close()
