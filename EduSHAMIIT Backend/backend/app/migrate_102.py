import psycopg2
import sys
import os

print("==============================================================")
print("  DDL MIGRATION RUNNER INSIDE DOCKER CONTAINER")
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
-- Migration 102: Create blocked_users table for Contact Blocking Feature
-- EduSHAMIIT — Shami Innovation and Technologies LLP

CREATE TABLE IF NOT EXISTS blocked_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blocker_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT blocked_users_uniq UNIQUE (blocker_id, blocked_id),
    CONSTRAINT blocked_users_self_check CHECK (blocker_id <> blocked_id)
);

CREATE INDEX IF NOT EXISTS idx_blocked_users_blocker ON blocked_users(blocker_id);
CREATE INDEX IF NOT EXISTS idx_blocked_users_blocked ON blocked_users(blocked_id);
"""

try:
    with conn.cursor() as cursor:
        print("Executing migration 102 DDL SQL...")
        cursor.execute(sql_migration)
        conn.commit()
        print("  [SUCCESS] Table 'blocked_users' and indexes created successfully!")
except Exception as e:
    conn.rollback()
    print(f"  [ERROR] Migration failed: {e}")
    sys.exit(1)
finally:
    conn.close()
