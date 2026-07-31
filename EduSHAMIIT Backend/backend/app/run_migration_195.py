import psycopg2
import sys
import os

print("==============================================================")
print("  EXECUTING MIGRATION 195: VEHICLE MAINTENANCE")
print("==============================================================")

dbname = os.environ.get("POSTGRES_DB", "postgres")
user = os.environ.get("POSTGRES_USER", "postgres")
password = os.environ.get("POSTGRES_PASSWORD", "eduSHAMIIT2026_pg")
host = os.environ.get("POSTGRES_HOST", "localhost")
port = os.environ.get("POSTGRES_PORT", "5432")

print(f"Connecting to database '{dbname}' at host '{host}:{port}' as user '{user}'...")

try:
    conn = psycopg2.connect(
        host=host,
        port=port,
        dbname=dbname,
        user=user,
        password=password,
        connect_timeout=5
    )
    print("  [SUCCESS] Connected to PostgreSQL!")
except Exception as e:
    print(f"  [ERROR] Connection failed: {e}")
    sys.exit(1)

with open(r"e:\EduSHAMIIT\EduSHAMIIT Database\edushamiit-db\migrations\195_vehicle_maintenance.sql", "r") as f:
    sql_migration = f.read()

try:
    with conn.cursor() as cursor:
        print("Executing migration 195 DDL SQL...")
        cursor.execute(sql_migration)
        conn.commit()
        print("  [SUCCESS] 'vehicle_maintenance' table created and seeded!")
except Exception as e:
    conn.rollback()
    print(f"  [ERROR] Migration failed: {e}")
    sys.exit(1)
finally:
    conn.close()
