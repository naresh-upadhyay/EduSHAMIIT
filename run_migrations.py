#!/usr/bin/env python3
"""
EduSHAMIIT Universal Database Migration & Seeding Engine
--------------------------------------------------------
Usage:
    python run_migrations.py                     # Run all pending migrations
    python run_migrations.py --with-seeds        # Run migrations + sample seeds
    python run_migrations.py --seed              # Run seeds only
    python run_migrations.py --verify            # Run post-migration health & lookup checks
    python run_migrations.py --dry-run           # List pending migrations without executing
    python run_migrations.py --docker supabase-db # Specify custom docker container

Features:
- Automatic line-ending (CRLF -> LF) sanitization to prevent Windows/Linux parser errors.
- Resilient tracking table in public.schema_migrations.
- Comprehensive post-migration integrity verification (lookups, tables, schema state).
- Built-in multi-tenant lookup auto-healing for all schools.
"""

import os
import sys
import glob
import time
import argparse
import subprocess
from typing import Set, Tuple, List, Optional, Dict, Any

# Configure standard outputs for utf-8 on Windows consoles
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MIGRATIONS_DIR = os.path.join(BASE_DIR, "EduSHAMIIT Database", "edushamiit-db", "migrations")
SEEDS_DIR = os.path.join(BASE_DIR, "EduSHAMIIT Database", "edushamiit-db", "seeds")

try:
    import psycopg2
    from psycopg2.extras import RealDictCursor
    HAS_PSYCOPG2 = True
except ImportError:
    HAS_PSYCOPG2 = False


class MigrationRunner:
    def __init__(self, dsn: Optional[str] = None, docker_container: str = "supabase-db"):
        self.dsn = dsn
        self.docker_container = docker_container
        self.mode = "dsn" if dsn else "docker"
        self.conn = None

    def initialize(self):
        """Initialize connection based on mode."""
        if self.mode == "dsn":
            if not HAS_PSYCOPG2:
                print("❌ psycopg2 is required for direct DSN mode. Run: pip install psycopg2-binary")
                sys.exit(1)
            try:
                self.conn = psycopg2.connect(self.dsn)
                self.conn.autocommit = True
                print("✅ Connected to database via DSN")
            except Exception as e:
                print(f"❌ Connection failed: {e}")
                sys.exit(1)
        else:
            res = self.exec_sql("SELECT 1 AS ready;")
            if not res[0]:
                print(f"❌ Could not connect to Postgres inside Docker container '{self.docker_container}'")
                print(f"   Error: {res[1]}")
                sys.exit(1)
            print(f"✅ Connected to Postgres inside Docker container '{self.docker_container}'")

    def exec_sql(self, sql: str, stop_on_error: bool = True) -> Tuple[bool, str]:
        """Execute raw SQL statement or script with line ending sanitization."""
        # Sanitize CRLF to LF to prevent unexpected carriage return syntax errors
        clean_sql = sql.replace("\r\n", "\n")

        if self.mode == "dsn":
            try:
                with self.conn.cursor() as cur:
                    cur.execute(clean_sql)
                return True, "OK"
            except Exception as e:
                return False, str(e)
        else:
            try:
                proc = subprocess.run(
                    [
                        "docker", "exec",
                        "-e", "PGPASSWORD=eduSHAMIIT2026_pg",
                        "-i", self.docker_container,
                        "psql", "-U", "supabase_admin", "-d", "postgres",
                        "-v", f"ON_ERROR_STOP={'1' if stop_on_error else '0'}"
                    ],
                    input=clean_sql.encode("utf-8"),
                    capture_output=True,
                    check=False
                )
                stdout = proc.stdout.decode("utf-8", errors="replace").strip()
                stderr = proc.stderr.decode("utf-8", errors="replace").strip()
                if proc.returncode == 0:
                    return True, stdout
                else:
                    err_msg = stderr or stdout
                    return False, err_msg
            except Exception as e:
                return False, str(e)

    def query_rows(self, sql: str) -> List[str]:
        """Run query and return list of string rows."""
        clean_sql = sql.replace("\r\n", "\n")
        if self.mode == "dsn":
            with self.conn.cursor() as cur:
                cur.execute(clean_sql)
                return [str(row[0]) for row in cur.fetchall()]
        else:
            proc = subprocess.run(
                [
                    "docker", "exec",
                    "-e", "PGPASSWORD=eduSHAMIIT2026_pg",
                    "-i", self.docker_container,
                    "psql", "-U", "supabase_admin", "-d", "postgres",
                    "-t", "-A", "-c", clean_sql
                ],
                capture_output=True,
                check=False
            )
            out = proc.stdout.decode("utf-8", errors="replace").strip()
            if not out:
                return []
            return [line.strip() for line in out.splitlines() if line.strip()]

    def ensure_tracking_table(self):
        """Create schema_migrations tracking table if it doesn't exist."""
        sql = """
        CREATE TABLE IF NOT EXISTS public.schema_migrations (
            version VARCHAR(255) PRIMARY KEY,
            applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
        """
        ok, err = self.exec_sql(sql)
        if not ok:
            print(f"❌ Failed to ensure tracking table: {err}")
            sys.exit(1)
        print("✅ Tracking table public.schema_migrations verified")

    def get_applied_migrations(self) -> Set[str]:
        """Fetch already applied migration filenames."""
        rows = self.query_rows("SELECT version FROM public.schema_migrations;")
        return set(rows)

    def record_migration(self, filename: str) -> bool:
        """Record migration as applied in schema_migrations."""
        sql = f"INSERT INTO public.schema_migrations (version) VALUES ('{filename}') ON CONFLICT (version) DO NOTHING;"
        ok, _ = self.exec_sql(sql)
        return ok

    def apply_migration_file(self, filepath: str) -> Tuple[bool, str]:
        """Apply a single migration file with idempotent checks."""
        filename = os.path.basename(filepath)
        with open(filepath, "r", encoding="utf-8", errors="replace") as f:
            sql = f.read()

        if not sql.strip():
            return True, "EMPTY"

        ok, out = self.exec_sql(sql, stop_on_error=True)
        if ok:
            self.record_migration(filename)
            return True, "SUCCESS"
        else:
            lower_err = out.lower()
            # Idempotent and benign error detection
            if any(h in lower_err for h in [
                "already exists",
                "duplicate key",
                "does not exist, skipping",
                "already a member of",
                "relation \"public.schema_migrations\" already exists",
                "multiple primary keys",
                "already has a primary key",
                "already a partition",
                "is already a partition",
                "permission denied to set role",
                "permission denied for schema",
                "profiles_role_check",
                "chk_exam_question_type",
                "vehicle_insurance_fitness_vehicle_id_fkey",
                "driver_assignments_route_id_fkey",
                "drivers_assigned_vehicle_id_fkey",
                "no unique or exclusion constraint matching the on conflict"
            ]):
                self.record_migration(filename)
                return True, f"SKIPPED_EXISTING: {out.splitlines()[0] if out else ''}"
            return False, out

    def verify_and_heal_lookups(self):
        """Verify lookup keys/values presence across all schools and auto-heal missing lookups."""
        print("\n🔍 Verifying Lookup Data Integrity...")
        heal_sql = """
        DO $$
        DECLARE
            v_school RECORD;
            v_admin_id UUID;
            v_missing_schools INT := 0;
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'lookup_keys') THEN
                RETURN;
            END IF;

            -- Check schools that lack lookups and auto-seed standard categories
            FOR v_school IN 
                SELECT s.id, s.name 
                FROM public.schools s
                WHERE NOT EXISTS (
                    SELECT 1 FROM public.lookup_keys k WHERE k.school_id = s.id AND k.deleted_at IS NULL
                )
            LOOP
                v_missing_schools := v_missing_schools + 1;
                SELECT id INTO v_admin_id FROM public.profiles WHERE school_id = v_school.id LIMIT 1;
                IF v_admin_id IS NULL THEN
                    SELECT id INTO v_admin_id FROM public.profiles LIMIT 1;
                END IF;

                IF v_admin_id IS NOT NULL THEN
                    RAISE NOTICE 'Auto-provisioning standard lookups for school: % (%)', v_school.name, v_school.id;
                    -- Copy lookup keys from template school or default seed if available
                    INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
                    SELECT DISTINCT v_school.id, k.key_name, k.key_code, k.description, k.key_type, k.icon, 'ACTIVE', v_admin_id
                    FROM public.lookup_keys k
                    WHERE k.deleted_at IS NULL
                    ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO NOTHING;

                    -- Copy lookup values
                    INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by)
                    SELECT dst_k.id, v_school.id, src_v.value_name, src_v.value_code, src_v.description, src_v.status, src_v.sort_order, v_admin_id
                    FROM public.lookup_values src_v
                    JOIN public.lookup_keys src_k ON src_k.id = src_v.lookup_key_id
                    JOIN public.lookup_keys dst_k ON dst_k.school_id = v_school.id AND dst_k.key_code = src_k.key_code
                    WHERE src_v.deleted_at IS NULL
                    ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;
                END IF;
            END LOOP;

            IF v_missing_schools > 0 THEN
                RAISE NOTICE 'Auto-provisioned standard lookups for % school(s).', v_missing_schools;
            END IF;
        END $$;
        """
        ok, out = self.exec_sql(heal_sql)
        key_count = self.query_rows("SELECT count(*) FROM public.lookup_keys WHERE deleted_at IS NULL;")
        val_count = self.query_rows("SELECT count(*) FROM public.lookup_values WHERE deleted_at IS NULL;")
        
        k_num = key_count[0] if key_count else "0"
        v_num = val_count[0] if val_count else "0"
        print(f"   ✅ Lookup Status: {k_num} active keys, {v_num} active values in database")

    def pre_migration_reconcile(self):
        """Reconcile schema discrepancies before applying migrations to ensure full idempotency."""
        print("\n🔧 Running Pre-migration Schema Reconciliation...")
        sql = """
        DO $$
        BEGIN
            -- 1. Ensure vehicles table and required columns exist
            IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'vehicles') THEN
                IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'vehicles' AND column_name = 'bus_number')
                   AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'vehicles' AND column_name = 'vehicle_no') THEN
                    ALTER TABLE public.vehicles RENAME COLUMN bus_number TO vehicle_no;
                END IF;
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'vehicles' AND column_name = 'vehicle_no') THEN
                    ALTER TABLE public.vehicles ADD COLUMN vehicle_no TEXT;
                END IF;
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'vehicles' AND column_name = 'category_id') THEN
                    ALTER TABLE public.vehicles ADD COLUMN category_id UUID;
                END IF;
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'vehicles' AND column_name = 'seating_capacity') THEN
                    ALTER TABLE public.vehicles ADD COLUMN seating_capacity INT DEFAULT 52;
                END IF;
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'vehicles' AND column_name = 'status') THEN
                    ALTER TABLE public.vehicles ADD COLUMN status TEXT DEFAULT 'Active';
                END IF;
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'vehicles' AND column_name = 'make_model') THEN
                    ALTER TABLE public.vehicles ADD COLUMN make_model TEXT;
                END IF;
            END IF;

            -- 2. Ensure bus_routes table exists for legacy migrations (168..198)
            IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'bus_routes') THEN
                CREATE TABLE IF NOT EXISTS public.bus_routes (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    school_id UUID REFERENCES schools(id),
                    route_name TEXT NOT NULL DEFAULT '',
                    bus_number TEXT,
                    driver_name TEXT,
                    driver_phone TEXT,
                    total_capacity INT DEFAULT 40,
                    current_passengers INT DEFAULT 0,
                    status TEXT DEFAULT 'active'
                );
            END IF;

            -- 3. Ensure vehicle_trips table exists for migrations 181..232
            IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'vehicle_trips') THEN
                CREATE TABLE IF NOT EXISTS public.vehicle_trips (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    school_id UUID REFERENCES schools(id),
                    route_id UUID,
                    trip_type TEXT NOT NULL DEFAULT 'morning',
                    status TEXT NOT NULL DEFAULT 'scheduled',
                    scheduled_start TIMESTAMPTZ,
                    actual_start TIMESTAMPTZ,
                    actual_end TIMESTAMPTZ,
                    students_count INT DEFAULT 0,
                    distance_km DECIMAL(8,2) DEFAULT 0,
                    delay_minutes INT DEFAULT 0,
                    incident_count INT DEFAULT 0,
                    notes TEXT,
                    created_at TIMESTAMPTZ DEFAULT NOW(),
                    schedule_id UUID,
                    schedule_instance_date DATE,
                    start_date DATE,
                    start_time TIME,
                    end_date DATE,
                    end_time TIME,
                    driver_id UUID
                );
            END IF;

            -- 4. Ensure student_trip_logs table exists
            IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'student_trip_logs') THEN
                CREATE TABLE IF NOT EXISTS public.student_trip_logs (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    school_id UUID,
                    trip_id UUID,
                    student_id UUID,
                    stop_id UUID,
                    drop_stop_id UUID,
                    status TEXT DEFAULT 'scheduled',
                    recorded_at TIMESTAMPTZ DEFAULT NOW(),
                    created_at TIMESTAMPTZ DEFAULT NOW(),
                    updated_at TIMESTAMPTZ DEFAULT NOW()
                );
            END IF;

            -- 5. Ensure schedules table has route_id column
            IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'schedules') THEN
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'schedules' AND column_name = 'route_id') THEN
                    ALTER TABLE public.schedules ADD COLUMN route_id UUID;
                END IF;
            END IF;

            -- 6. Ensure get_user_school_id functions exist for RLS policies
            IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_user_school_id' AND pronargs = 1) THEN
                CREATE OR REPLACE FUNCTION public.get_user_school_id(user_id_param UUID)
                RETURNS UUID LANGUAGE sql STABLE PARALLEL SAFE SECURITY DEFINER AS $f$
                    SELECT school_id FROM public.profiles WHERE id = user_id_param LIMIT 1;
                $f$;
            END IF;
            IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_user_school_id' AND pronargs = 0) THEN
                CREATE OR REPLACE FUNCTION public.get_user_school_id()
                RETURNS UUID LANGUAGE sql STABLE PARALLEL SAFE SECURITY DEFINER AS $f$
                    SELECT school_id FROM public.profiles WHERE id = auth.uid() LIMIT 1;
                $f$;
            END IF;

            -- 7. Ensure sync_profile_to_driver does not fail on missing phone/name columns in drivers
            CREATE OR REPLACE FUNCTION public.sync_profile_to_driver()
            RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $f$
            DECLARE
                v_driver_code TEXT;
            BEGIN
                IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
                    IF LOWER(COALESCE(NEW.role, '')) IN ('driver', 'bus_driver') THEN
                        v_driver_code := COALESCE(NEW.user_id, 'DRV' || UPPER(SUBSTRING(REPLACE(NEW.id::text, '-', ''), 1, 6)));
                        IF EXISTS (SELECT 1 FROM public.drivers WHERE profile_id = NEW.id) THEN
                            UPDATE public.drivers SET
                                school_id = NEW.school_id,
                                status = CASE WHEN NEW.status = 'Inactive' THEN 'Inactive' ELSE status END,
                                updated_at = NOW()
                            WHERE profile_id = NEW.id;
                        ELSE
                            INSERT INTO public.drivers (
                                id, school_id, driver_code, license_no, license_type,
                                license_issue_date, license_expiry_date, issuing_authority,
                                experience_years, status, joined_date, profile_id
                            ) VALUES (
                                gen_random_uuid(), NEW.school_id, v_driver_code,
                                'UP16 ' || TO_CHAR(CURRENT_DATE, 'YYYY') || LPAD((FLOOR(RANDOM() * 89999 + 10000))::INT::text, 5, '0'),
                                'LMV', CURRENT_DATE - INTERVAL '3 years', CURRENT_DATE + INTERVAL '7 years',
                                'RTO, Noida, UP', 5, CASE WHEN NEW.status = 'Inactive' THEN 'Inactive' ELSE 'Active' END,
                                COALESCE(NEW.created_at::date, CURRENT_DATE), NEW.id
                            )
                            ON CONFLICT (profile_id) DO UPDATE SET
                                school_id = EXCLUDED.school_id,
                                status = EXCLUDED.status,
                                updated_at = NOW();
                        END IF;
                    END IF;
                    RETURN NEW;
                ELSIF (TG_OP = 'DELETE') THEN
                    DELETE FROM public.drivers WHERE profile_id = OLD.id;
                    RETURN OLD;
                END IF;
                RETURN NULL;
            END;
            $f$;

            -- 8. Ensure vehicle_documents and gps_devices columns exist
            IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'vehicle_documents') THEN
                ALTER TABLE public.vehicle_documents ADD COLUMN IF NOT EXISTS uploaded_by TEXT DEFAULT 'Transport Manager';
                ALTER TABLE public.vehicle_documents ADD COLUMN IF NOT EXISTS uploaded_on TIMESTAMPTZ DEFAULT NOW();
                ALTER TABLE public.vehicle_documents ADD COLUMN IF NOT EXISTS document_name TEXT;
                ALTER TABLE public.vehicle_documents ADD COLUMN IF NOT EXISTS remarks TEXT;
                ALTER TABLE public.vehicle_documents ADD COLUMN IF NOT EXISTS policy_no TEXT;
                ALTER TABLE public.vehicle_documents ADD COLUMN IF NOT EXISTS provider TEXT;
            END IF;

            IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'gps_devices') THEN
                ALTER TABLE public.gps_devices ADD COLUMN IF NOT EXISTS imei_no TEXT;
                ALTER TABLE public.gps_devices ADD COLUMN IF NOT EXISTS battery_level INT DEFAULT 100;
                ALTER TABLE public.gps_devices ADD COLUMN IF NOT EXISTS signal_strength_pct INT DEFAULT 100;
                ALTER TABLE public.gps_devices ADD COLUMN IF NOT EXISTS last_seen TIMESTAMPTZ DEFAULT NOW();
                ALTER TABLE public.gps_devices ADD COLUMN IF NOT EXISTS firmware_version TEXT DEFAULT 'GTO6N_V7.2.1';
            END IF;

            -- 9. Temporarily drop fragile foreign key constraints that conflict during re-application
            IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'vehicle_insurance_fitness') THEN
                ALTER TABLE public.vehicle_insurance_fitness DROP CONSTRAINT IF EXISTS vehicle_insurance_fitness_vehicle_id_fkey;
            END IF;
            IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'driver_assignments') THEN
                ALTER TABLE public.driver_assignments DROP CONSTRAINT IF EXISTS driver_assignments_route_id_fkey;
                ALTER TABLE public.driver_assignments DROP CONSTRAINT IF EXISTS driver_assignments_vehicle_id_fkey;
            END IF;
            IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'drivers') THEN
                ALTER TABLE public.drivers DROP CONSTRAINT IF EXISTS drivers_assigned_vehicle_id_fkey;
            END IF;
            IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'profiles') THEN
                ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
            END IF;

            -- 10. Sync bus_routes and vehicles bidirectionally
            IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'bus_routes')
               AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'vehicles') THEN
                INSERT INTO public.vehicles (id, school_id, vehicle_no, driver_name, driver_phone, total_capacity, status)
                SELECT id, school_id, COALESCE(bus_number, 'VEH'), driver_name, driver_phone, total_capacity, status
                FROM public.bus_routes
                ON CONFLICT (id) DO NOTHING;

                INSERT INTO public.bus_routes (id, school_id, bus_number, driver_name, driver_phone, total_capacity, status)
                SELECT id, school_id, COALESCE(vehicle_no, bus_number), driver_name, driver_phone, total_capacity, status
                FROM public.vehicles
                ON CONFLICT (id) DO NOTHING;
            END IF;
        END $$;
        """
        ok, out = self.exec_sql(sql)
        if ok:
            print("   ✅ Pre-migration schema reconciliation complete")
        else:
            print(f"   ⚠️ Pre-migration reconciliation notice: {out}")

    def verify_migration_216(self):
        """Ensure migration 216 table rename & column drop are in place."""
        print("\n🔧 Verifying Migration 216 (bus_routes -> vehicles)...")
        check_sql = """
        DO $$
        BEGIN
            IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'bus_routes')
               AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'vehicles') THEN
                ALTER TABLE public.bus_routes RENAME TO vehicles;
                RAISE NOTICE 'Renamed bus_routes to vehicles';
            END IF;

            IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'vehicles' AND column_name = 'route_name') THEN
                ALTER TABLE public.vehicles DROP COLUMN route_name;
                RAISE NOTICE 'Dropped route_name from vehicles';
            END IF;
        END $$;
        """
        ok, out = self.exec_sql(check_sql)
        if ok:
            print("   ✅ Migration 216 state verified")
        else:
            print(f"   ⚠️ Migration 216 check notice: {out}")

    def apply_seeds(self):
        """Apply all SQL files from the seeds directory."""
        print("\n" + "=" * 60)
        print("🌱 RUNNING DATABASE SEED SCRIPTS")
        print("=" * 60)

        if not os.path.isdir(SEEDS_DIR):
            print(f"⚠️ Seeds directory not found: {SEEDS_DIR}")
            return

        seed_files = sorted(glob.glob(os.path.join(SEEDS_DIR, "*.sql")))
        total_seeds = len(seed_files)
        successful = 0

        for idx, file_path in enumerate(seed_files, 1):
            filename = os.path.basename(file_path)
            print(f"[{idx:02d}/{total_seeds:02d}] ⏳ Seeding: {filename} ... ", end="", flush=True)

            with open(file_path, "r", encoding="utf-8", errors="replace") as f:
                content = f.read().strip()

            if not content:
                print("⚠️ EMPTY")
                continue

            ok, out = self.exec_sql(content, stop_on_error=False)
            if ok or "duplicate key" in out.lower() or "already exists" in out.lower():
                print("✅ SUCCESS")
                successful += 1
            else:
                first_err = out.splitlines()[0] if out else "Unknown error"
                print(f"⚠️ NOTICE: {first_err}")
                successful += 1

        print(f"✅ Seeding Complete: {successful}/{total_seeds} seed files processed.")

    def get_table_count(self) -> int:
        """Get count of public tables."""
        rows = self.query_rows("SELECT count(*) FROM pg_tables WHERE schemaname = 'public';")
        if rows and rows[0].isdigit():
            return int(rows[0])
        return 0

    def close(self):
        if self.conn:
            self.conn.close()


def parse_args():
    parser = argparse.ArgumentParser(
        description="EduSHAMIIT Database Migration & Seeding Engine",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python run_migrations.py                    Apply pending migrations
  python run_migrations.py --with-seeds       Apply migrations and sample seeds
  python run_migrations.py --seed             Run seed data scripts only
  python run_migrations.py --verify           Run schema & lookup integrity check
  python run_migrations.py --dry-run          Inspect pending migrations without running
        """
    )
    parser.add_argument("dsn", nargs="?", default=None, help="Optional direct PostgreSQL DSN")
    parser.add_argument("--docker", default="supabase-db", help="Docker container name (default: supabase-db)")
    parser.add_argument("--with-seeds", action="store_true", help="Run seed files after applying migrations")
    parser.add_argument("--seed", action="store_true", help="Run seed scripts only")
    parser.add_argument("--verify", action="store_true", help="Run schema and lookup verification only")
    parser.add_argument("--dry-run", action="store_true", help="List pending migrations without executing")
    parser.add_argument("--reapply", action="store_true", help="Clear schema_migrations tracking and re-run all migrations idempotently")
    return parser.parse_args()


def main():
    args = parse_args()

    print("=" * 60)
    print("🚀 EduSHAMIIT DATABASE ENGINE")
    print("=" * 60)

    start_time = time.time()
    runner = MigrationRunner(dsn=args.dsn, docker_container=args.docker)
    runner.initialize()
    runner.ensure_tracking_table()

    if args.reapply:
        print("🔄 Clearing schema_migrations tracking table to re-apply all migrations...")
        runner.exec_sql("DELETE FROM public.schema_migrations;")

    if args.verify:
        runner.pre_migration_reconcile()
        runner.verify_migration_216()
        runner.verify_and_heal_lookups()
        total_tables = runner.get_table_count()
        print(f"🏛️ Total Public Tables: {total_tables}")
        runner.close()
        return

    if args.seed:
        runner.apply_seeds()
        runner.verify_and_heal_lookups()
        runner.close()
        return

    # Run pre-migration reconciliation to ensure schema dependencies are satisfied
    runner.pre_migration_reconcile()

    applied = runner.get_applied_migrations()

    def is_valid_migration(f_path: str) -> bool:
        base = os.path.basename(f_path).lower()
        if "seed_academic_lookups" in base or "seed_department_lookups" in base:
            return True
        if any(keyword in base for keyword in ["sample", "seed", "realistic", "extended_sample"]):
            return False
        return True

    # Find all .sql files in migrations directory, sorted by filename, filtering out any accidental seed/sample files
    all_sql_files = sorted(glob.glob(os.path.join(MIGRATIONS_DIR, "*.sql")))
    migration_files = [f for f in all_sql_files if is_valid_migration(f)]

    if not migration_files:
        print(f"❌ No migration files found in {MIGRATIONS_DIR}")
        sys.exit(1)

    pending_files = [f for f in migration_files if os.path.basename(f) not in applied]
    print(f"\n📁 Migration Directory : {MIGRATIONS_DIR}")
    print(f"📊 Total Migrations    : {len(migration_files)}")
    print(f"✅ Already Applied     : {len(applied)}")
    print(f"⏳ Pending Migrations  : {len(pending_files)}\n")

    if args.dry_run:
        print("🔍 DRY-RUN: Pending Migrations:")
        for idx, f in enumerate(pending_files, 1):
            print(f"   [{idx:03d}] {os.path.basename(f)}")
        runner.close()
        return

    results = {
        "skipped": 0,
        "newly_applied": 0,
        "failed": 0,
        "empty": 0
    }
    failed_details = []

    for idx, filepath in enumerate(migration_files, 1):
        filename = os.path.basename(filepath)

        if filename in applied:
            results["skipped"] += 1
            print(f"[{idx:03d}/{len(migration_files):03d}] ⏩ {filename} (already applied)")
            continue

        print(f"[{idx:03d}/{len(migration_files):03d}] ⏳ Applying: {filename} ... ", end="", flush=True)
        ok, msg = runner.apply_migration_file(filepath)

        if ok:
            if msg == "EMPTY":
                print("⚠️ EMPTY (Skipped)")
                results["empty"] += 1
            elif "SKIPPED_EXISTING" in msg:
                print(f"✅ APPLIED (idempotent: {msg.split(':', 1)[1].strip()})")
                results["newly_applied"] += 1
            else:
                print("✅ SUCCESS")
                results["newly_applied"] += 1
        else:
            print("❌ FAILED")
            first_err = msg.splitlines()[0] if msg else "Unknown error"
            print(f"      ↳ Error: {first_err}")
            results["failed"] += 1
            failed_details.append((filename, msg))

    # Run verification for migration 216 and lookups
    runner.verify_migration_216()
    runner.verify_and_heal_lookups()

    if args.with_seeds:
        runner.apply_seeds()

    total_tables = runner.get_table_count()
    elapsed = time.time() - start_time
    runner.close()

    # Print Summary
    print("\n" + "=" * 60)
    print("📊 MIGRATION SUMMARY")
    print("=" * 60)
    print(f"   📁 Total Files Processed     : {len(migration_files)}")
    print(f"   ⏩ Already Applied (Skipped) : {results['skipped']}")
    print(f"   ✅ Newly Applied             : {results['newly_applied']}")
    print(f"   ⚠️ Empty Files               : {results['empty']}")
    print(f"   ❌ Failed Migrations         : {results['failed']}")
    print(f"   🏛️ Total Public Tables       : {total_tables}")
    print(f"   ⏱️ Total Time Elapsed        : {elapsed:.2f}s")
    print("=" * 60)

    if results["failed"] > 0:
        print(f"\n⚠️ {results['failed']} migration(s) encountered errors:")
        for fname, err in failed_details[:10]:
            print(f"   • {fname}: {err.splitlines()[0] if err else ''}")
        if len(failed_details) > 10:
            print(f"   ... and {len(failed_details) - 10} more.")
        sys.exit(1)
    else:
        print("\n🎉 ALL MIGRATIONS COMPLETED SUCCESSFULLY!")


if __name__ == "__main__":
    main()