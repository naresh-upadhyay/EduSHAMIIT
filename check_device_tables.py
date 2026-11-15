import psycopg2
from psycopg2.extras import RealDictCursor

conn = psycopg2.connect('postgresql://postgres:eduSHAMIIT2026_pg@127.0.0.1:5432/postgres')
cur = conn.cursor(cursor_factory=RealDictCursor)
cur.execute("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name LIKE '%device%';")
rows = cur.fetchall()
print("Device tables:")
for r in rows:
    print(r['table_name'])
conn.close()
