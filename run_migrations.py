#!/usr/bin/env python3
"""
EduSHAMIIT Database Migration Runner
------------------------------------
Usage:
    python run_migrations.py                  # Apply pending migrations using auto-detected DB URL
    python run_migrations.py -reapply         # Remove existing tables/SPs and reapply all migrations from scratch
    python run_migrations.py <DATABASE_URL>   # Specify explicit PostgreSQL connection URL
    python run_migrations.py <DATABASE_URL> -reapply

Scans, applies, and tracks SQL migration files in numerical order.
"""

import os
import sys
import glob
import re
import time

# Ensure standard output doesn't crash on Windows cp1252 encoding
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

try:
    import psycopg2
except ImportError:
    print("[ERROR] psycopg2 not installed. Run: pip install psycopg2-binary")
    sys.exit(1)


MIGRATIONS_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "EduSHAMIIT Database",
    "edushamiit-db",
    "migrations",
)


def load_env_file(filepath: str) -> dict:
    """Parse key-value pairs from a .env file."""
    env = {}
    if not os.path.isfile(filepath):
        return env
    try:
        with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" in line:
                    k, v = line.split("=", 1)
                    k = k.strip()
                    v = v.strip().strip("'\"")
                    env[k] = v
    except Exception:
        pass
    return env


def resolve_database_url() -> str:
    """Determine the database connection URL from CLI, environment, or .env."""
    root_dir = os.path.dirname(os.path.abspath(__file__))
    root_env = load_env_file(os.path.join(root_dir, ".env"))
    backend_env = load_env_file(os.path.join(root_dir, "EduSHAMIIT Backend", ".env"))

    merged_env = {**root_env, **backend_env, **os.environ}

    pg_password = merged_env.get("POSTGRES_PASSWORD", "eduSHAMIIT2026_pg")
    pg_db = merged_env.get("POSTGRES_DB", "postgres")

    # Candidate connection URLs in priority order:
    # 1. Port 54322 (Supabase Docker port avoiding host port 5432 conflict)
    # 2. Port 5432 (Standard PostgreSQL port)
    candidates = [
        merged_env.get("DATABASE_URL"),
        f"postgresql://postgres:{pg_password}@127.0.0.1:54322/{pg_db}",
        f"postgresql://supabase_admin:{pg_password}@127.0.0.1:54322/{pg_db}",
        f"postgresql://postgres:{pg_password}@localhost:54322/{pg_db}",
        f"postgresql://postgres:{pg_password}@127.0.0.1:5432/{pg_db}",
        f"postgresql://supabase_admin:{pg_password}@127.0.0.1:5432/{pg_db}",
    ]

    for dsn in candidates:
        if not dsn:
            continue
        try:
            test_conn = psycopg2.connect(dsn, connect_timeout=3)
            test_conn.close()
            return dsn
        except Exception:
            continue

    # Fallback default
    return f"postgresql://postgres:{pg_password}@127.0.0.1:54322/{pg_db}"


def get_connection(dsn: str, retries: int = 10, delay: float = 3.0):
    """Connect to PostgreSQL with autocommit enabled, retrying if DB is starting up."""
    last_err = None
    for attempt in range(1, retries + 1):
        try:
            conn = psycopg2.connect(dsn, connect_timeout=5)
            conn.autocommit = True
            masked_dsn = re.sub(r":([^@]+)@", r":****@", dsn)
            print(f"[OK] Connected to database: {masked_dsn}")
            return conn
        except Exception as e:
            last_err = e
            if attempt < retries:
                print(f"[WAIT] Waiting for database to be ready (attempt {attempt}/{retries})...")
                time.sleep(delay)
    print(f"[ERROR] Connection failed after {retries} attempts: {last_err}")
    sys.exit(1)


def clean_public_schema(conn):
    """
    Remove all existing user tables, views, materialized views, stored procedures,
    functions, user-defined types, and sequences in schema 'public'.
    Preserves PostgreSQL extensions (e.g. pgvector, uuid-ossp, pgcrypto).
    """
    print("\n" + "=" * 60)
    print("🔄 Removing existing tables, views, and stored procedures/functions...")
    print("=" * 60)

    clean_sql = """
    DO $$
    DECLARE
        r RECORD;
    BEGIN
        -- 1. Drop all Views in public (except those from extensions)
        FOR r IN (
            SELECT v.table_name 
            FROM information_schema.views v
            WHERE v.table_schema = 'public'
              AND NOT EXISTS (
                  SELECT 1 FROM pg_depend d 
                  JOIN pg_extension e ON d.refobjid = e.oid 
                  JOIN pg_class c ON d.objid = c.oid 
                  WHERE c.relname = v.table_name AND d.deptype = 'e'
              )
        ) LOOP
            EXECUTE 'DROP VIEW IF EXISTS public.' || quote_ident(r.table_name) || ' CASCADE';
        END LOOP;

        -- 2. Drop all Materialized Views in public
        FOR r IN (
            SELECT matviewname FROM pg_matviews WHERE schemaname = 'public'
        ) LOOP
            EXECUTE 'DROP MATERIALIZED VIEW IF EXISTS public.' || quote_ident(r.matviewname) || ' CASCADE';
        END LOOP;

        -- 3. Drop all Tables in public (except extension tables)
        FOR r IN (
            SELECT t.tablename 
            FROM pg_tables t
            WHERE t.schemaname = 'public'
              AND NOT EXISTS (
                  SELECT 1 FROM pg_depend d 
                  JOIN pg_extension e ON d.refobjid = e.oid 
                  JOIN pg_class c ON d.objid = c.oid 
                  WHERE c.relname = t.tablename AND d.deptype = 'e'
              )
        ) LOOP
            EXECUTE 'DROP TABLE IF EXISTS public.' || quote_ident(r.tablename) || ' CASCADE';
        END LOOP;

        -- 4. Drop all Routines (Functions & Procedures) in public not owned by extensions
        FOR r IN (
            SELECT p.proname, pg_catalog.pg_get_function_identity_arguments(p.oid) AS args,
                   CASE WHEN p.prokind = 'p' THEN 'PROCEDURE' ELSE 'FUNCTION' END AS kind
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'public'
              AND NOT EXISTS (
                  SELECT 1 FROM pg_depend d 
                  WHERE d.objid = p.oid AND d.deptype = 'e'
              )
        ) LOOP
            EXECUTE 'DROP ' || r.kind || ' IF EXISTS public.' || quote_ident(r.proname) || '(' || r.args || ') CASCADE';
        END LOOP;

        -- 5. Drop all User-defined Types & Enums in public not owned by extensions
        FOR r IN (
            SELECT t.typname
            FROM pg_type t
            JOIN pg_namespace n ON t.typnamespace = n.oid
            WHERE n.nspname = 'public'
              AND t.typtype IN ('e', 'c', 'd')
              AND NOT EXISTS (
                  SELECT 1 FROM pg_depend d 
                  WHERE d.objid = t.oid AND d.deptype = 'e'
              )
        ) LOOP
            EXECUTE 'DROP TYPE IF EXISTS public.' || quote_ident(r.typname) || ' CASCADE';
        END LOOP;

        -- 6. Drop all Sequences in public not owned by extensions
        FOR r IN (
            SELECT sequence_name 
            FROM information_schema.sequences 
            WHERE sequence_schema = 'public'
        ) LOOP
            EXECUTE 'DROP SEQUENCE IF EXISTS public.' || quote_ident(r.sequence_name) || ' CASCADE';
        END LOOP;
    END $$;
    """

    with conn.cursor() as cur:
        cur.execute(clean_sql)
        # Drop tracking table to allow complete re-execution
        cur.execute("DROP TABLE IF EXISTS public.schema_migrations CASCADE;")
        # Clear vault secrets if vault schema is present
        cur.execute("""
            DO $$ 
            BEGIN 
                IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'vault' AND table_name = 'secrets') THEN
                    DELETE FROM vault.secrets;
                END IF;
            END $$;
        """)
        # Clear auth.users if auth schema is present to avoid orphaned auth users
        cur.execute("""
            DO $$ 
            BEGIN 
                IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'auth' AND table_name = 'users') THEN
                    DELETE FROM auth.users;
                END IF;
            END $$;
        """)
        # Ensure schema grants are intact
        cur.execute("""
            GRANT USAGE, CREATE ON SCHEMA public TO postgres;
            GRANT USAGE, CREATE ON SCHEMA public TO anon;
            GRANT USAGE, CREATE ON SCHEMA public TO authenticated;
            GRANT USAGE, CREATE ON SCHEMA public TO service_role;
            GRANT ALL ON SCHEMA public TO supabase_admin;
        """)

    print("[OK] Existing tables, views, and stored procedures/functions cleanly removed.")


def ensure_tracking_table(conn):
    """Ensure public schema permissions and create schema_migrations table if it doesn't exist."""
    with conn.cursor() as cur:
        try:
            cur.execute("""
                CREATE SCHEMA IF NOT EXISTS public;
                GRANT ALL ON SCHEMA public TO postgres;
                GRANT ALL ON SCHEMA public TO anon;
                GRANT ALL ON SCHEMA public TO authenticated;
                GRANT ALL ON SCHEMA public TO service_role;
                GRANT ALL ON SCHEMA public TO supabase_admin;
            """)
        except Exception:
            pass
        cur.execute("""
            CREATE TABLE IF NOT EXISTS public.schema_migrations (
                version VARCHAR(255) PRIMARY KEY,
                applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            );
            GRANT ALL ON TABLE public.schema_migrations TO postgres;
            GRANT ALL ON TABLE public.schema_migrations TO anon;
            GRANT ALL ON TABLE public.schema_migrations TO authenticated;
            GRANT ALL ON TABLE public.schema_migrations TO service_role;
            GRANT ALL ON TABLE public.schema_migrations TO supabase_admin;
        """)
    print("[OK] schema_migrations tracking table ready")


def get_applied_migrations(conn):
    """Return set of already-applied migration filenames."""
    with conn.cursor() as cur:
        cur.execute("SELECT version FROM public.schema_migrations")
        return {row[0] for row in cur.fetchall()}


def apply_migration(conn, filepath: str, record: bool = True) -> tuple:
    """Apply a single migration file. Returns (bool: success, str: error_message)."""
    filename = os.path.basename(filepath)
    with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
        sql = f.read()

    if not sql.strip():
        return True, "empty file"

    try:
        with conn.cursor() as cur:
            cur.execute(sql)
        if record:
            with conn.cursor() as cur:
                cur.execute(
                    "INSERT INTO public.schema_migrations (version) VALUES (%s) ON CONFLICT (version) DO NOTHING",
                    (filename,),
                )
        return True, ""
    except Exception as e:
        err_msg = str(e).strip().split("\n")[0]
        try:
            conn.rollback()
        except Exception:
            pass
        return False, err_msg


def main():
    args = sys.argv[1:]
    reapply = False
    custom_dsn = None

    for arg in args:
        if arg.lower() in ("-reapply", "--reapply", "-r", "--reset", "-clean", "--clean"):
            reapply = True
        elif arg.startswith("postgresql://") or arg.startswith("postgres://"):
            custom_dsn = arg

    if custom_dsn:
        dsn = custom_dsn
    else:
        print("[INFO] Auto-resolving PostgreSQL database connection...")
        dsn = resolve_database_url()

    conn = get_connection(dsn)

    if reapply:
        clean_public_schema(conn)

    ensure_tracking_table(conn)
    applied = get_applied_migrations(conn)

    migration_files = sorted(glob.glob(os.path.join(MIGRATIONS_DIR, "*.sql")))

    if not migration_files:
        print(f"[ERROR] No migration files found in {MIGRATIONS_DIR}")
        sys.exit(1)

    print(f"\n[INFO] Found {len(migration_files)} migration files")
    print(f"[INFO] Already applied: {len(applied)}")
    print(f"[INFO] Pending: {len(migration_files) - len(applied)}\n")

    results = {"skipped": 0, "applied": 0, "failed": 0, "errors": []}

    for filepath in migration_files:
        filename = os.path.basename(filepath)

        if filename in applied and not reapply:
            results["skipped"] += 1
        else:
            print(f"⏳ Applying: {filename}... ", end="", flush=True)
            success, err = apply_migration(conn, filepath)
            if success:
                print("✅ Done")
                results["applied"] += 1
            else:
                print(f"❌ Failed ({err})")
                results["failed"] += 1
                results["errors"].append((filename, err))

    # Summary
    print(f"\n{'='*55}")
    print("📊 MIGRATION SUMMARY")
    print(f"   Total migrations: {len(migration_files)}")
    print(f"   ⏩ Skipped (already applied): {results['skipped']}")
    print(f"   ✅ Successfully applied: {results['applied']}")
    print(f"   ❌ Failed: {results['failed']}")
    if results["errors"]:
        print("\nErrors encountered:")
        for fn, err in results["errors"][:10]:
            print(f"   • {fn}: {err}")
        if len(results["errors"]) > 10:
            print(f"   ... and {len(results['errors']) - 10} more")
    print(f"{'='*55}")

    conn.close()

    if results["failed"] > 0:
        print("\n[WARN] Some migrations encountered errors. Review details above.")
        sys.exit(1)
    else:
        print("\n[OK] All migrations completed successfully!")


if __name__ == "__main__":
    main()