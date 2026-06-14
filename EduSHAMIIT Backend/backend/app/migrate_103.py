import psycopg2
import sys
import os

print("==============================================================")
print("  DDL MIGRATION RUNNER - ADD EXAMS PASSCODE & TARGET STUDENTS")
print("==============================================================")

# Read environment variables inside container
dbname = os.environ.get("POSTGRES_DB", "postgres")
user = os.environ.get("POSTGRES_USER", "postgres")
password = os.environ.get("POSTGRES_PASSWORD", "eduSHAMIIT2026_pg")
host = os.environ.get("POSTGRES_HOST", "db")
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

sql_migration = """
-- Migration 103: Add passcode and target_students columns to exams table
-- EduSHAMIIT — Shami Innovation and Technologies LLP

ALTER TABLE exams ADD COLUMN IF NOT EXISTS passcode TEXT;
ALTER TABLE exams ADD COLUMN IF NOT EXISTS target_students JSONB;
ALTER TABLE exams ADD COLUMN IF NOT EXISTS scope TEXT DEFAULT 'All Students';
"""

try:
    with conn.cursor() as cursor:
        print("Executing migration 103 DDL SQL...")
        cursor.execute(sql_migration)
        conn.commit()
        print("  [SUCCESS] Columns 'passcode' and 'target_students' added successfully!")
except Exception as e:
    conn.rollback()
    print(f"  [ERROR] Migration failed: {e}")
    sys.exit(1)
finally:
    conn.close()
