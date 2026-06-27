#!/usr/bin/env python3
"""
EduSHAMIIT Database Migration Runner
------------------------------------
Usage: python run_migrations.py "postgresql://user:pass@host:5432/db"

Scans, applies, and tracks SQL migration files in order.
"""

import os
import sys
import glob

try:
    import psycopg2
except ImportError:
    print("❌ psycopg2 not installed. Run: pip install psycopg2-binary")
    sys.exit(1)


MIGRATIONS_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "EduSHAMIIT Database",
    "edushamiit-db",
    "migrations",
)


def get_connection(dsn: str):
    """Connect to PostgreSQL."""
    try:
        conn = psycopg2.connect(dsn)
        conn.autocommit = True
        print(f"✅ Connected to database")
        return conn
    except Exception as e:
        print(f"❌ Connection failed: {e}")
        sys.exit(1)


def ensure_tracking_table(conn):
    """Create schema_migrations table if it doesn't exist."""
    with conn.cursor() as cur:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS public.schema_migrations (
                version VARCHAR(255) PRIMARY KEY,
                applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            );
        """)
    print("✅ schema_migrations tracking table ready")


def get_applied_migrations(conn):
    """Return set of already-applied migration filenames."""
    with conn.cursor() as cur:
        cur.execute("SELECT version FROM public.schema_migrations")
        return {row[0] for row in cur.fetchall()}


def apply_migration(conn, filepath: str, record: bool = True) -> bool:
    """Apply a single migration file. Returns True on success."""
    filename = os.path.basename(filepath)
    with open(filepath, "r", encoding="utf-8") as f:
        sql = f.read()

    if not sql.strip():
        print(f"   ⚠️  {filename} is empty, skipping")
        return True

    try:
        with conn.cursor() as cur:
            cur.execute(sql)
        # Record the migration only if requested
        if record:
            with conn.cursor() as cur:
                cur.execute(
                    "INSERT INTO public.schema_migrations (version) VALUES (%s)",
                    (filename,),
                )
        return True
    except Exception as e:
        print(f"   ❌ ERROR: {e}")
        return False


def main():
    if len(sys.argv) < 2:
        print("Usage: python run_migrations.py <DATABASE_URL>")
        print("Example: python run_migrations.py 'postgresql://user:pass@host:5432/db'")
        sys.exit(1)

    dsn = sys.argv[1]
    conn = get_connection(dsn)

    ensure_tracking_table(conn)
    applied = get_applied_migrations(conn)

    # Find all .sql files in migrations directory, sorted by filename
    migration_files = sorted(
        glob.glob(os.path.join(MIGRATIONS_DIR, "*.sql"))
    )

    if not migration_files:
        print(f"❌ No migration files found in {MIGRATIONS_DIR}")
        sys.exit(1)

    print(f"\n📁 Found {len(migration_files)} migration files")
    print(f"✅ Already applied: {len(applied)}")
    print(f"⏳ Pending: {len(migration_files) - len(applied)}\n")

    # The 10 fixed files that need re-apply
    fixed_files = {
        "091_optimize_endpoints.sql",
        "092_profile_session_and_stats.sql",
        "100_enhance_live_classes_with_recording_data.sql",
        "112_salary_advances.sql",
        "115_enhance_attendance_module.sql",
        "129_fix_rls_policies_roles.sql",
        "135_rule_based_badges.sql",
        "136_enhance_teacher_dashboard.sql",
        "137_align_student_teacher_averages.sql",
        "138_add_performance_indexes.sql",
    }

    results = {"skipped": 0, "applied": 0, "failed": 0, "reapplied": 0}

    for filepath in migration_files:
        filename = os.path.basename(filepath)

        if filename in applied:
            if filename in fixed_files:
                print(f"🔄  Re-applying (fixed): {filename}")
                # Don't record in schema_migrations since already tracked
                if apply_migration(conn, filepath, record=False):
                    print(f"   ✅ Re-applied successfully")
                    results["reapplied"] += 1
                else:
                    results["failed"] += 1
            else:
                print(f"   ✅ {filename} (already applied)")
                results["skipped"] += 1
        else:
            print(f"   ⏳ Applying: {filename}... ", end="", flush=True)
            if apply_migration(conn, filepath):
                print(f"   ✅ Done")
                results["applied"] += 1
            else:
                print(f"   ❌ Failed")
                results["failed"] += 1

    # Summary
    print(f"\n{'='*50}")
    print(f"📊 MIGRATION SUMMARY")
    print(f"   ✅ Total migrations: {len(migration_files)}")
    print(f"   ⏩ Skipped (already applied): {results['skipped']}")
    print(f"   ✅ Newly applied: {results['applied']}")
    print(f"   🔄 Re-applied (fixed): {results['reapplied']}")
    print(f"   ❌ Failed: {results['failed']}")
    print(f"{'='*50}")

    conn.close()

    if results["failed"] > 0:
        print("\n⚠️  Some migrations failed. Review errors above.")
        sys.exit(1)
    else:
        print("\n✅ All migrations completed successfully!")


if __name__ == "__main__":
    main()