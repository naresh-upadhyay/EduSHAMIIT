-- Database migration: 146_vault_secrets_management.sql
-- Create secure wrapper functions in public schema to manage vault secrets securely from service-role API clients.

-- 1. List vault secrets (names, descriptions, created_at, updated_at - no decrypted values)
CREATE OR REPLACE FUNCTION public.get_vault_secrets()
RETURNS TABLE (
    id uuid,
    name text,
    description text,
    created_at timestamptz,
    updated_at timestamptz
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY 
    SELECT s.id, s.name, s.description, s.created_at, s.updated_at 
    FROM vault.secrets s
    ORDER BY s.name ASC;
END;
$$;

-- 2. Reveal/get decrypted secret value
CREATE OR REPLACE FUNCTION public.get_vault_secret_value(secret_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    val text;
BEGIN
    SELECT decrypted_secret INTO val 
    FROM vault.decrypted_secrets 
    WHERE id = secret_id;
    
    RETURN val;
END;
$$;

-- 3. Create secret
CREATE OR REPLACE FUNCTION public.create_vault_secret(
    secret_name text,
    secret_value text,
    secret_desc text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_id uuid;
BEGIN
    new_id := vault.create_secret(secret_value, secret_name, secret_desc);
    RETURN new_id;
END;
$$;

-- 4. Update secret
CREATE OR REPLACE FUNCTION public.update_vault_secret(
    secret_id uuid,
    secret_value text DEFAULT NULL,
    secret_name text DEFAULT NULL,
    secret_desc text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    PERFORM vault.update_secret(secret_id, secret_value, secret_name, secret_desc);
END;
$$;

-- 5. Delete secret
CREATE OR REPLACE FUNCTION public.delete_vault_secret(secret_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    DELETE FROM vault.secrets WHERE id = secret_id;
END;
$$;

-- 6. Fetch all decrypted secrets at once for backend settings injection
CREATE OR REPLACE FUNCTION public.get_all_decrypted_secrets()
RETURNS TABLE (
    secret_name text,
    secret_value text
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY 
    SELECT s.name::text, s.decrypted_secret::text
    FROM vault.decrypted_secrets s;
END;
$$;
