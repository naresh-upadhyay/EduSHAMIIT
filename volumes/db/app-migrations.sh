#!/bin/bash
set -e

echo ">>> Checking internal Supabase database..."
PGPASSWORD="$POSTGRES_PASSWORD" psql -v ON_ERROR_STOP=0 --username "supabase_admin" --dbname "postgres" <<EOSQL
  CREATE DATABASE _supabase;
EOSQL

echo ">>> Ensuring public schema and search_path..."
PGPASSWORD="$POSTGRES_PASSWORD" psql -v ON_ERROR_STOP=0 --username "supabase_admin" --dbname "$POSTGRES_DB" <<EOSQL
  CREATE SCHEMA IF NOT EXISTS public;
  GRANT ALL ON SCHEMA public TO postgres;
  GRANT ALL ON SCHEMA public TO anon;
  GRANT ALL ON SCHEMA public TO authenticated;
  GRANT ALL ON SCHEMA public TO service_role;
  ALTER ROLE supabase_admin SET search_path TO "\$user", public, auth, extensions, storage;
EOSQL

echo ">>> Running EduSHAMIIT app migrations (001-091)..."

if [ -d "/docker-entrypoint-initdb.d/app-migrations" ]; then
    for f in $(ls /docker-entrypoint-initdb.d/app-migrations/*.sql | sort); do
        echo ">>> Executing $f..."
        PGPASSWORD="$POSTGRES_PASSWORD" psql -v ON_ERROR_STOP=1 --username "supabase_admin" --dbname "$POSTGRES_DB" -f "$f"
    done
else
    echo ">>> No app-migrations directory found, skipping."
fi

echo ">>> App migrations completed."
