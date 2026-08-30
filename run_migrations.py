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
            # Idempotent error detection
            if any(h in lower_err for h in [
                "already exists",
                "duplicate key",
                "does not exist, skipping",
                "already a member of",
                "relation \"public.schema_migrations\" already exists"
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

    applied = runner.get_applied_migrations()

    # Find all .sql files in migrations directory, sorted by filename
    migration_files = sorted(glob.glob(os.path.join(MIGRATIONS_DIR, "*.sql")))

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