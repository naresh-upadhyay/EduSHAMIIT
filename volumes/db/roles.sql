-- NOTE: change to your own passwords for production environments
\set pgpass `echo "$POSTGRES_PASSWORD"`

ALTER USER authenticator      WITH PASSWORD :'pgpass';
ALTER USER pgbouncer          WITH PASSWORD :'pgpass';
ALTER USER supabase_auth_admin WITH PASSWORD :'pgpass';

-- Optional roles that might not exist in all Supabase versions yet
DO $$ 
BEGIN 
  -- Set search paths to ensure services can find schemas
  ALTER ROLE supabase_admin SET search_path TO "$user", public, auth, extensions, storage;
  ALTER ROLE postgres SET search_path TO "$user", public, extensions;
  
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'supabase_auth_admin') THEN
    ALTER USER supabase_auth_admin WITH PASSWORD 'eduSHAMIIT2026_pg';
    ALTER ROLE supabase_auth_admin SET search_path TO auth, public;
    GRANT ALL ON SCHEMA auth TO supabase_auth_admin;
    -- Ensure it can manage functions in auth
    ALTER SCHEMA auth OWNER TO supabase_auth_admin;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'supabase_functions_admin') THEN
    ALTER USER supabase_functions_admin WITH PASSWORD 'eduSHAMIIT2026_pg';
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'supabase_storage_admin') THEN
    ALTER USER supabase_storage_admin WITH PASSWORD 'eduSHAMIIT2026_pg';
    GRANT ALL ON SCHEMA storage TO supabase_storage_admin;
    ALTER SCHEMA storage OWNER TO supabase_storage_admin;
  END IF;
  
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'authenticator') THEN
    ALTER USER authenticator WITH PASSWORD 'eduSHAMIIT2026_pg';
  END IF;
END $$;
