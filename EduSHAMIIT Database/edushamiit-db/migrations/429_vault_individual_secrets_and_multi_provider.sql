-- Database Migration: 429_vault_individual_secrets_and_multi_provider.sql
-- Enables individual vs global scoped secrets in Supabase Vault and adds smart credential routing.

-- 1. Enhance vault_secret_metadata with scope and user_id
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'vault_secret_metadata' 
        AND column_name = 'scope'
    ) THEN
        ALTER TABLE public.vault_secret_metadata 
        ADD COLUMN scope TEXT NOT NULL DEFAULT 'global' CHECK (scope IN ('global', 'individual'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'vault_secret_metadata' 
        AND column_name = 'user_id'
    ) THEN
        ALTER TABLE public.vault_secret_metadata 
        ADD COLUMN user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'vault_secret_metadata' 
        AND column_name = 'secret_key_name'
    ) THEN
        ALTER TABLE public.vault_secret_metadata 
        ADD COLUMN secret_key_name TEXT;
    END IF;
END $$;

-- 2. Populate secret_key_name from vault.secrets for existing rows
UPDATE public.vault_secret_metadata m
SET secret_key_name = s.name
FROM vault.secrets s
WHERE m.secret_id = s.id AND m.secret_key_name IS NULL;

-- Create index on user_id and scope for fast retrieval
CREATE INDEX IF NOT EXISTS idx_vault_metadata_user_scope 
ON public.vault_secret_metadata(user_id, scope, secret_key_name);

-- 3. Update get_vault_secrets to return scope, user_id, and secret_key_name
DROP FUNCTION IF EXISTS public.get_vault_secrets();
CREATE OR REPLACE FUNCTION public.get_vault_secrets(p_user_id uuid DEFAULT NULL)
RETURNS TABLE (
    id uuid,
    name text,
    description text,
    created_at timestamptz,
    updated_at timestamptz,
    path text,
    secret_type text,
    next_rotation timestamptz,
    status text,
    created_by text,
    modified_by text,
    version int,
    scope text,
    user_id uuid,
    secret_key_name text
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        s.id, 
        s.name, 
        s.description, 
        s.created_at, 
        s.updated_at,
        COALESCE(m.path, 'secret/data/' || LOWER(s.name)),
        COALESCE(m.secret_type, 'API Key'),
        m.next_rotation,
        COALESCE(m.status, 'Active'),
        COALESCE(m.created_by, 'Super Admin'),
        COALESCE(m.modified_by, 'System'),
        COALESCE(m.version, 1),
        COALESCE(m.scope, 'global'),
        m.user_id,
        COALESCE(m.secret_key_name, s.name)
    FROM vault.secrets s
    LEFT JOIN public.vault_secret_metadata m ON s.id = m.secret_id
    WHERE (
        p_user_id IS NULL 
        OR m.scope = 'global' 
        OR m.user_id = p_user_id
    )
    ORDER BY 
        CASE WHEN m.scope = 'individual' THEN 0 ELSE 1 END,
        s.name ASC;
END;
$$;

-- 4. Update create_vault_secret_v2 to support scope and user_id
CREATE OR REPLACE FUNCTION public.create_vault_secret_v2(
    p_secret_name text,
    p_secret_value text,
    p_secret_desc text,
    p_secret_path text,
    p_secret_type text,
    p_next_rotation timestamptz DEFAULT NULL,
    p_created_by text DEFAULT 'Super Admin',
    p_scope text DEFAULT 'global',
    p_user_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_id uuid;
    internal_name text;
BEGIN
    -- For individual secrets, qualify the internal name to ensure uniqueness in vault.secrets
    IF p_scope = 'individual' AND p_user_id IS NOT NULL THEN
        internal_name := 'USER_' || REPLACE(p_user_id::text, '-', '') || '_' || p_secret_name;
    ELSE
        internal_name := p_secret_name;
    END IF;

    -- Delete existing secret with same internal name if any
    DELETE FROM vault.secrets WHERE name = internal_name;
    
    -- Create vault secret
    new_id := vault.create_secret(p_secret_value, internal_name, p_secret_desc);
    
    -- Create metadata with scope and user_id
    INSERT INTO public.vault_secret_metadata (
        secret_id, path, secret_type, next_rotation, status, created_by, modified_by, version, scope, user_id, secret_key_name
    ) VALUES (
        new_id, 
        p_secret_path, 
        p_secret_type, 
        p_next_rotation, 
        'Active', 
        p_created_by, 
        p_created_by, 
        1,
        COALESCE(p_scope, 'global'),
        p_user_id,
        p_secret_name
    );
    
    -- Create version 1
    INSERT INTO public.vault_secret_versions (
        secret_id, version, secret_value, created_by
    ) VALUES (
        new_id, 1, p_secret_value, p_created_by
    );
    
    RETURN new_id;
END;
$$;

-- 5. Helper function to retrieve a specific secret with smart individual-over-global precedence
CREATE OR REPLACE FUNCTION public.get_smart_secret_value(p_secret_name text, p_user_id uuid DEFAULT NULL)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    sec_val text;
BEGIN
    -- 1. Check if individual credential exists for this user
    IF p_user_id IS NOT NULL THEN
        SELECT ds.decrypted_secret INTO sec_val
        FROM vault.decrypted_secrets ds
        JOIN public.vault_secret_metadata m ON ds.id = m.secret_id
        WHERE m.user_id = p_user_id 
          AND m.scope = 'individual'
          AND (m.secret_key_name = p_secret_name OR ds.name = p_secret_name)
          AND m.status = 'Active'
        LIMIT 1;

        IF sec_val IS NOT NULL AND sec_val <> '' THEN
            RETURN sec_val;
        END IF;
    END IF;

    -- 2. Fall back to global credential
    SELECT ds.decrypted_secret INTO sec_val
    FROM vault.decrypted_secrets ds
    JOIN public.vault_secret_metadata m ON ds.id = m.secret_id
    WHERE m.scope = 'global'
      AND (m.secret_key_name = p_secret_name OR ds.name = p_secret_name)
      AND m.status = 'Active'
    LIMIT 1;

    -- If not in metadata, check raw vault.decrypted_secrets by name
    IF sec_val IS NULL THEN
        SELECT decrypted_secret INTO sec_val
        FROM vault.decrypted_secrets
        WHERE name = p_secret_name
        LIMIT 1;
    END IF;

    RETURN sec_val;
END;
$$;

-- 6. Helper function to return all decrypted secrets with their metadata and scope
DROP FUNCTION IF EXISTS public.get_all_decrypted_secrets();
CREATE OR REPLACE FUNCTION public.get_all_decrypted_secrets()
RETURNS TABLE (
    secret_id uuid,
    name text,
    secret_key_name text,
    decrypted_value text,
    scope text,
    user_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ds.id AS secret_id,
        ds.name,
        COALESCE(m.secret_key_name, ds.name) AS secret_key_name,
        ds.decrypted_secret AS decrypted_value,
        COALESCE(m.scope, 'global') AS scope,
        m.user_id
    FROM vault.decrypted_secrets ds
    LEFT JOIN public.vault_secret_metadata m ON ds.id = m.secret_id;
END;
$$;
