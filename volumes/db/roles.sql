-- NOTE: change to your own passwords for production environments
\set pgpass 'eduSHAMIIT2026_pg'
\getenv pgpass POSTGRES_PASSWORD
SET my.password = :'pgpass';

-- Safe block to configure passwords
DO $$
DECLARE
  db_password text := current_setting('my.password', true);
BEGIN
  -- Fallback default if setting is empty or undefined
  IF db_password IS NULL OR db_password = '' THEN
    db_password := 'eduSHAMIIT2026_pg';
  END IF;

  -- Configure authenticator
  BEGIN
    EXECUTE 'ALTER USER authenticator WITH PASSWORD ' || quote_literal(db_password);
  EXCEPTION WHEN others THEN
    RAISE NOTICE 'Could not alter user authenticator';
  END;

  -- Configure pgbouncer
  BEGIN
    EXECUTE 'ALTER USER pgbouncer WITH PASSWORD ' || quote_literal(db_password);
  EXCEPTION WHEN others THEN
    RAISE NOTICE 'Could not alter user pgbouncer';
  END;

  -- Configure supabase_auth_admin
  BEGIN
    EXECUTE 'ALTER USER supabase_auth_admin WITH PASSWORD ' || quote_literal(db_password);
    ALTER ROLE supabase_auth_admin SET search_path TO auth, public;
    GRANT ALL ON SCHEMA auth TO supabase_auth_admin;
    -- Ensure it can manage functions in auth
    ALTER SCHEMA auth OWNER TO supabase_auth_admin;
  EXCEPTION WHEN others THEN
    RAISE NOTICE 'Could not alter user supabase_auth_admin';
  END;

  -- Configure supabase_functions_admin
  BEGIN
    EXECUTE 'ALTER USER supabase_functions_admin WITH PASSWORD ' || quote_literal(db_password);
  EXCEPTION WHEN others THEN
    RAISE NOTICE 'Could not alter user supabase_functions_admin';
  END;

  -- Configure supabase_storage_admin
  BEGIN
    EXECUTE 'ALTER USER supabase_storage_admin WITH PASSWORD ' || quote_literal(db_password);
    GRANT ALL ON SCHEMA storage TO supabase_storage_admin;
    ALTER SCHEMA storage OWNER TO supabase_storage_admin;
  EXCEPTION WHEN others THEN
    RAISE NOTICE 'Could not alter user supabase_storage_admin';
  END;

  -- Configure admin search paths
  BEGIN
    ALTER ROLE supabase_admin SET search_path TO "$user", public, auth, extensions, storage;
  EXCEPTION WHEN others THEN
    RAISE NOTICE 'Could not configure search path for supabase_admin';
  END;

  BEGIN
    ALTER ROLE postgres SET search_path TO "$user", public, extensions;
  EXCEPTION WHEN others THEN
    RAISE NOTICE 'Could not configure search path for postgres';
  END;
END $$;
