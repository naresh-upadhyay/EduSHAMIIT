import psycopg2
from psycopg2.extras import RealDictCursor

conn = psycopg2.connect('postgresql://postgres:eduSHAMIIT2026_pg@127.0.0.1:5432/postgres')
cur = conn.cursor(cursor_factory=RealDictCursor)
cur.execute("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name LIKE '%migrat%';")
print("Migration tables:", cur.fetchall())
cur.execute("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';")
all_tables = [r['table_name'] for r in cur.fetchall()]
print(f"Total public tables: {len(all_tables)}")
print("Has device_types:", 'device_types' in all_tables)
print("Has device_groups:", 'device_groups' in all_tables)
conn.close()
