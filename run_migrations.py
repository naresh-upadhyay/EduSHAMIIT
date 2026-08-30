#!/usr/bin/env python3
"""
EduSHAMIIT Database Migration Runner
------------------------------------
Usage:
    python run_migrations.py
    python run_migrations.py "postgresql://user:pass@host:5432/db"
    python run_migrations.py --docker supabase-db

Scans, applies, and tracks all SQL migration files in order.
"""

import os
import sys
import glob
import time
import subprocess
from typing import Set, Tuple, Optional

# Configure standard outputs for utf-8 on Windows consoles
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

# Default migrations directory
MIGRATIONS_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "EduSHAMIIT Database",
    "edushamiit-db",
    "migrations",
)

# Optional psycopg2 import for direct DSN mode
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
            # Check if docker container is accessible
            res = self.exec_sql("SELECT 1 AS ready;")
            if not res[0]:
                print(f"❌ Could not connect to Postgres inside Docker container '{self.docker_container}'")
                print(f"   Error: {res[1]}")
                sys.exit(1)
            print(f"✅ Connected to Postgres inside Docker container '{self.docker_container}'")

    def exec_sql(self, sql: str) -> Tuple[bool, str]:
        """Execute raw SQL statement or script. Returns (success, output/error)."""
        if self.mode == "dsn":
            try:
                with self.conn.cursor() as cur:
                    cur.execute(sql)
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
                        "-v", "ON_ERROR_STOP=1"
                    ],
                    input=sql.encode("utf-8"),
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

    def query_rows(self, sql: str) -> list:
        """Run query and return list of string rows."""
        if self.mode == "dsn":
            with self.conn.cursor() as cur:
                cur.execute(sql)
                return [row[0] for row in cur.fetchall()]
        else:
            proc = subprocess.run(
                [
                    "docker", "exec",
                    "-e", "PGPASSWORD=eduSHAMIIT2026_pg",
                    "-i", self.docker_container,
                    "psql", "-U", "supabase_admin", "-d", "postgres",
                    "-t", "-A", "-c", sql
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
        """Apply a single migration file."""
        filename = os.path.basename(filepath)
        with open(filepath, "r", encoding="utf-8") as f:
            sql = f.read()

        if not sql.strip():
            return True, "EMPTY"

        ok, out = self.exec_sql(sql)
        if ok:
            self.record_migration(filename)
            return True, "SUCCESS"
        else:
            # Check if error is harmless / idempotent
            lower_err = out.lower()
            if any(h in lower_err for h in ["already exists", "duplicate key", "does not exist, skipping", "already a member of"]):
                self.record_migration(filename)
                return True, f"SKIPPED_EXISTING: {out.splitlines()[0] if out else ''}"
            return False, out

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

    def get_table_count(self) -> int:
        """Get count of public tables."""
        rows = self.query_rows("SELECT count(*) FROM pg_tables WHERE schemaname = 'public';")
        if rows and rows[0].isdigit():
            return int(rows[0])
        return 0

    def close(self):
        if self.conn:
            self.conn.close()


def main():
    dsn = None
    docker_container = "supabase-db"

    # Argument parsing
    if len(sys.argv) > 1:
        arg = sys.argv[1]
        if arg.startswith("postgresql://") or arg.startswith("postgres://"):
            dsn = arg
        elif arg == "--docker" and len(sys.argv) > 2:
            docker_container = sys.argv[2]
        elif arg in ["-h", "--help"]:
            print("Usage: python run_migrations.py [DATABASE_URL | --docker <container_name>]")
            sys.exit(0)
        else:
            dsn = arg

    print("=" * 60)
    print("🚀 EduSHAMIIT DATABASE MIGRATION ENGINE")
    print("=" * 60)

    start_time = time.time()
    runner = MigrationRunner(dsn=dsn, docker_container=docker_container)
    runner.initialize()
    runner.ensure_tracking_table()

    applied = runner.get_applied_migrations()

    # Find all .sql files in migrations directory, sorted by filename
    migration_files = sorted(glob.glob(os.path.join(MIGRATIONS_DIR, "*.sql")))

    if not migration_files:
        print(f"❌ No migration files found in {MIGRATIONS_DIR}")
        sys.exit(1)

    pending_count = len(migration_files) - len(applied)
    print(f"\n📁 Migration Directory : {MIGRATIONS_DIR}")
    print(f"📊 Total Migrations    : {len(migration_files)}")
    print(f"✅ Already Applied     : {len(applied)}")
    print(f"⏳ Pending Migrations  : {max(0, pending_count)}\n")

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

    # Run verification for migration 216
    runner.verify_migration_216()

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