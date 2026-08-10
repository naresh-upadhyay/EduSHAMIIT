import asyncio
import os
import sys
import psycopg2

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def get_connection():
    # Try common local connection strings
    candidates = [
        "postgresql://postgres:eduSHAMIIT2026_pg@localhost:5432/postgres",
        "postgresql://postgres:postgres_password_2026@localhost:5432/edushamiit",
        "postgresql://postgres:postgres@localhost:5432/postgres",
        "postgresql://postgres:postgres_password_2026@localhost:5432/postgres",
        "postgresql://postgres:eduSHAMIIT2026_pg@127.0.0.1:5432/postgres"
    ]
    for url in candidates:
        try:
            conn = psycopg2.connect(url, connect_timeout=3)
            print(f"[CONNECTED] Connected with: {url}")
            return conn
        except Exception as e:
            pass
    raise Exception("Could not connect to local PostgreSQL instance")

def run_migration_228_sync():
    print("=== EXECUTING MIGRATION 228: LINK SCHEDULES TO TRANSPORT ROUTES & VEHICLE TRIPS ===")
    conn = get_connection()
    conn.autocommit = True
    cur = conn.cursor()

    # 1. Add route_id to public.schedules
    print("[ACTION] Adding route_id to public.schedules...")
    cur.execute("""
        ALTER TABLE IF EXISTS public.schedules
          ADD COLUMN IF NOT EXISTS route_id UUID REFERENCES public.transport_routes(id) ON DELETE SET NULL;
    """)
    cur.execute("CREATE INDEX IF NOT EXISTS idx_schedules_route ON public.schedules(route_id);")
    print("[SUCCESS] route_id added to public.schedules.")

    # 2. Add schedule_id, schedule_instance_date to public.vehicle_trips
    print("[ACTION] Adding schedule_id & schedule_instance_date to public.vehicle_trips...")
    cur.execute("""
        ALTER TABLE IF EXISTS public.vehicle_trips
          ADD COLUMN IF NOT EXISTS schedule_id UUID REFERENCES public.schedules(id) ON DELETE CASCADE,
          ADD COLUMN IF NOT EXISTS schedule_instance_date DATE,
          ADD COLUMN IF NOT EXISTS start_date DATE,
          ADD COLUMN IF NOT EXISTS start_time TIME,
          ADD COLUMN IF NOT EXISTS end_date DATE,
          ADD COLUMN IF NOT EXISTS end_time TIME,
          ADD COLUMN IF NOT EXISTS driver_id UUID REFERENCES public.drivers(id) ON DELETE SET NULL;
    """)

    cur.execute("CREATE INDEX IF NOT EXISTS idx_vehicle_trips_schedule_id ON public.vehicle_trips(schedule_id);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_vehicle_trips_schedule_date ON public.vehicle_trips(schedule_id, start_date);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_vehicle_trips_route_date ON public.vehicle_trips(route_id, start_date);")
    print("[SUCCESS] Columns & indexes added to public.vehicle_trips.")

    cur.close()
    conn.close()
    print("=== MIGRATION 228 APPLIED SUCCESSFULLY ===")

if __name__ == "__main__":
    run_migration_228_sync()
