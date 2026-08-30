#!/usr/bin/env python3
"""
EduSHAMIIT Database Seed Runner
--------------------------------
Usage:
    python run_seeds.py
    python run_seeds.py --docker supabase-db

Scans and applies all sample data seed files into the database.
"""

import os
import sys
import glob
import time
import subprocess
from typing import Tuple, Optional

# Configure standard outputs for utf-8 on Windows consoles
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

SEEDS_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "EduSHAMIIT Database",
    "edushamiit-db",
    "seeds",
)

try:
    import psycopg2
    HAS_PSYCOPG2 = True
except ImportError:
    HAS_PSYCOPG2 = False


class SeedRunner:
    def __init__(self, dsn: Optional[str] = None, docker_container: str = "supabase-db"):
        self.dsn = dsn
        self.docker_container = docker_container
        self.mode = "dsn" if dsn else "docker"
        self.conn = None

    def initialize(self):
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

    def exec_sql(self, sql: str) -> Tuple[bool, str]:
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
                        "-v", "ON_ERROR_STOP=0"
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
                    return False, f"{stderr}\n{stdout}".strip()
            except Exception as e:
                return False, str(e)

    def run(self):
        print("=" * 60)
        print("🌱 EduSHAMIIT DATABASE SEED RUNNER")
        print("=" * 60)
        self.initialize()

        if not os.path.isdir(SEEDS_DIR):
            print(f"❌ Seeds directory not found: {SEEDS_DIR}")
            sys.exit(1)

        seed_files = sorted(glob.glob(os.path.join(SEEDS_DIR, "*.sql")))
        total_seeds = len(seed_files)

        print(f"\n📁 Seeds Directory  : {SEEDS_DIR}")
        print(f"📊 Total Seed Files : {total_seeds}\n")

        successful = 0
        failed = 0
        failed_files = []

        start_time = time.time()

        for idx, file_path in enumerate(seed_files, 1):
            filename = os.path.basename(file_path)
            print(f"[{idx:02d}/{total_seeds:02d}] ⏳ Seeding: {filename} ... ", end="", flush=True)

            try:
                with open(file_path, "r", encoding="utf-8") as f:
                    content = f.read().strip()
            except Exception as e:
                print(f"❌ READ ERROR: {e}")
                failed += 1
                failed_files.append((filename, str(e)))
                continue

            if not content:
                print("⚠️ EMPTY FILE")
                continue

            success, output = self.exec_sql(content)

            if success:
                print("✅ SUCCESS")
                successful += 1
            else:
                # Check if it's just duplicate key warning/notice or real error
                if "duplicate key value violates unique constraint" in output or "already exists" in output:
                    print("✅ APPLIED (idempotent duplicate skipped)")
                    successful += 1
                else:
                    print(f"❌ FAILED\n      ↳ Error: {output.splitlines()[0] if output else 'Unknown error'}")
                    failed += 1
                    failed_files.append((filename, output))

        elapsed = time.time() - start_time
        print("\n" + "=" * 60)
        print("📊 SEEDING SUMMARY")
        print("=" * 60)
        print(f"   📁 Total Files Processed : {total_seeds}")
        print(f"   ✅ Successfully Applied  : {successful}")
        print(f"   ❌ Failed Seed Files     : {failed}")
        print(f"   ⏱️ Total Time Elapsed    : {elapsed:.2f}s")
        print("=" * 60)

        if failed > 0:
            print(f"\n⚠️ {failed} seed file(s) encountered errors:")
            for fname, err in failed_files:
                first_line = err.splitlines()[0] if err else "Unknown error"
                print(f"   • {fname}: {first_line}")
        else:
            print("\n🎉 ALL SEED DATA APPLIED SUCCESSFULLY!")


if __name__ == "__main__":
    runner = SeedRunner()
    runner.run()
