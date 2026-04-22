"""
apply_missing_migrations.py
----------------------------
Runs the missing migration files against the local Supabase Postgres instance.

Usage:
    cd "E:\\EduSHAMIIT\\EduSHAMIIT Backend"
    python apply_missing_migrations.py

The script connects using the DATABASE_URL (or falls back to individual
POSTGRES_* vars) from the .env file, then executes each SQL file listed
in MIGRATIONS_TO_RUN in order.
"""
import os
import sys
import psycopg2
from pathlib import Path
from dotenv import load_dotenv

# ── Load env ────────────────────────────────────────────────────────────────
ENV_PATH = Path(__file__).parent / ".env"
load_dotenv(ENV_PATH)

DB_CONFIG = {
    "host":     os.getenv("POSTGRES_HOST", "127.0.0.1"),
    "port":     int(os.getenv("POSTGRES_PORT", 54322)),
    "dbname":   os.getenv("POSTGRES_DB", "postgres"),
    "user":     os.getenv("POSTGRES_USER", "postgres"),
    "password": os.getenv("POSTGRES_PASSWORD", "postgres"),
}

MIGRATIONS_DIR = Path(__file__).parent.parent / "EduSHAMIIT Database" / "edushamiit-db" / "migrations"

# ── List every migration that is NEW / previously un-applied ─────────────────
# Add more filenames here whenever you create additional migrations.
MIGRATIONS_TO_RUN = [
    "081_groups.sql",
    "082_sample_groups.sql",
    "083_realistic_profiles.sql",
    "084_realistic_academic.sql",
    "085_realistic_school_life.sql",
    "086_extended_sample_data.sql",
]


def run_sql_file(cur, filepath: Path):
    print(f"  Running: {filepath.name} ...", end=" ")
    sql = filepath.read_text(encoding="utf-8")
    cur.execute(sql)
    print("OK")


def main():
    print(f"Connecting to {DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['dbname']} ...")
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        conn.autocommit = True
        cur = conn.cursor()
    except psycopg2.OperationalError as e:
        print(f"[ERROR] Cannot connect: {e}")
        print("Make sure `supabase start` is running (npx supabase start).")
        sys.exit(1)

    print(f"Connected. Applying {len(MIGRATIONS_TO_RUN)} migration(s)...\n")

    failed = []
    for filename in MIGRATIONS_TO_RUN:
        filepath = MIGRATIONS_DIR / filename
        if not filepath.exists():
            print(f"  [SKIP] {filename} — file not found")
            continue
        try:
            run_sql_file(cur, filepath)
        except Exception as e:
            print(f"FAILED\n  [ERROR] {e}")
            failed.append(filename)

    cur.close()
    conn.close()

    print()
    if failed:
        print(f"⚠️  {len(failed)} migration(s) FAILED: {', '.join(failed)}")
        sys.exit(1)
    else:
        print("✅  All migrations applied successfully!")
        print("\nVerifying tables exist:")
        verify_tables()


def verify_tables():
    """Quick sanity-check: list the newly-created tables."""
    tables_to_check = ["groups", "group_members"]
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        for table in tables_to_check:
            cur.execute(
                "SELECT COUNT(*) FROM information_schema.tables "
                "WHERE table_schema='public' AND table_name=%s",
                (table,)
            )
            exists = cur.fetchone()[0] == 1
            status = "✅" if exists else "❌"
            print(f"  {status}  public.{table}")
        cur.close()
        conn.close()
    except Exception as e:
        print(f"  [WARN] Could not verify: {e}")


if __name__ == "__main__":
    main()
