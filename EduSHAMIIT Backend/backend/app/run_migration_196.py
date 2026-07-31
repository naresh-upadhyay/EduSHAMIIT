import psycopg2
import sys
import os

print("==============================================================")
print("  EXECUTING MIGRATION 196: VEHICLE TECH SPECS COLUMNS")
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

sql_migration = """
-- Migration 196: Add Technical & Vehicle Specs Columns to bus_routes
ALTER TABLE bus_routes ADD COLUMN IF NOT EXISTS luggage_capacity VARCHAR(100) DEFAULT '500 L';
ALTER TABLE bus_routes ADD COLUMN IF NOT EXISTS fuel_tank_capacity VARCHAR(100) DEFAULT '150 Liters';
ALTER TABLE bus_routes ADD COLUMN IF NOT EXISTS transmission VARCHAR(50) DEFAULT 'Manual';
ALTER TABLE bus_routes ADD COLUMN IF NOT EXISTS odometer_km INTEGER DEFAULT 45280;
ALTER TABLE bus_routes ADD COLUMN IF NOT EXISTS speed_governor VARCHAR(100) DEFAULT 'Fitted (Max 60 km/h)';
ALTER TABLE bus_routes ADD COLUMN IF NOT EXISTS cctv_installed VARCHAR(100) DEFAULT '4 HD Cameras (Active)';
ALTER TABLE bus_routes ADD COLUMN IF NOT EXISTS panic_button VARCHAR(100) DEFAULT 'Installed & Working';
ALTER TABLE bus_routes ADD COLUMN IF NOT EXISTS first_aid_expiry VARCHAR(50);
ALTER TABLE bus_routes ADD COLUMN IF NOT EXISTS fire_extinguisher_expiry VARCHAR(50);
ALTER TABLE bus_routes ADD COLUMN IF NOT EXISTS last_serviced_date VARCHAR(50);
ALTER TABLE bus_routes ADD COLUMN IF NOT EXISTS ownership_type VARCHAR(100) DEFAULT 'School Owned';
"""

try:
    with conn.cursor() as cursor:
        print("Executing migration 196 DDL SQL...")
        cursor.execute(sql_migration)
        conn.commit()
        print("  [SUCCESS] Vehicle Tech Specs columns added to 'bus_routes' table!")
except Exception as e:
    conn.rollback()
    print(f"  [ERROR] Migration failed: {e}")
    sys.exit(1)
finally:
    conn.close()
