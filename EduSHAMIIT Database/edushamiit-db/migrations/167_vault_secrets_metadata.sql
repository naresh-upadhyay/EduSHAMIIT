-- Database migration: 167_vault_secrets_metadata.sql
-- Create metadata and version tracking tables for Vault Secrets, and update wrapper RPC functions.

-- 1. Create metadata table
CREATE TABLE IF NOT EXISTS public.vault_secret_metadata (
    secret_id UUID PRIMARY KEY REFERENCES vault.secrets(id) ON DELETE CASCADE,
    path TEXT NOT NULL,
    secret_type TEXT NOT NULL,
    next_rotation TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'Active',
    created_by TEXT NOT NULL DEFAULT 'Super Admin',
    modified_by TEXT NOT NULL DEFAULT 'System',
    version INT NOT NULL DEFAULT 1
);

-- 2. Create version tracking table
CREATE TABLE IF NOT EXISTS public.vault_secret_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    secret_id UUID REFERENCES vault.secrets(id) ON DELETE CASCADE,
    version INT NOT NULL,
    secret_value TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by TEXT NOT NULL DEFAULT 'Super Admin'
);

-- 3. Redefine get_vault_secrets to return metadata
DROP FUNCTION IF EXISTS public.get_vault_secrets();
CREATE OR REPLACE FUNCTION public.get_vault_secrets()
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
    version int
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
        COALESCE(m.version, 1)
    FROM vault.secrets s
    LEFT JOIN public.vault_secret_metadata m ON s.id = m.secret_id
    ORDER BY s.name ASC;
END;
$$;

-- 4. Create V2 helper for secret creation
DROP FUNCTION IF EXISTS public.create_vault_secret_v2(text,text,text,text,text,timestamptz,text);
CREATE OR REPLACE FUNCTION public.create_vault_secret_v2(
    p_secret_name text,
    p_secret_value text,
    p_secret_desc text,
    p_secret_path text,
    p_secret_type text,
    p_next_rotation timestamptz DEFAULT NULL,
    p_created_by text DEFAULT 'Super Admin'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_id uuid;
BEGIN
    -- Create vault secret
    new_id := vault.create_secret(p_secret_value, p_secret_name, p_secret_desc);
    
    -- Create metadata
    INSERT INTO public.vault_secret_metadata (
        secret_id, path, secret_type, next_rotation, status, created_by, modified_by, version
    ) VALUES (
        new_id, p_secret_path, p_secret_type, p_next_rotation, 'Active', p_created_by, p_created_by, 1
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

-- 5. Create V2 helper for secret update / rotation
DROP FUNCTION IF EXISTS public.update_vault_secret_v2(uuid,text,text,text,text,text,timestamptz,text,text);
CREATE OR REPLACE FUNCTION public.update_vault_secret_v2(
    p_secret_id uuid,
    p_secret_value text DEFAULT NULL,
    p_secret_name text DEFAULT NULL,
    p_secret_desc text DEFAULT NULL,
    p_secret_path text DEFAULT NULL,
    p_secret_type text DEFAULT NULL,
    p_secret_next_rotation timestamptz DEFAULT NULL,
    p_secret_status text DEFAULT NULL,
    p_modified_by text DEFAULT 'System'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    curr_version int;
BEGIN
    -- Update vault secret
    PERFORM vault.update_secret(p_secret_id, p_secret_value, p_secret_name, p_secret_desc);
    
    -- Get current version
    SELECT version INTO curr_version FROM public.vault_secret_metadata WHERE secret_id = p_secret_id;
    IF curr_version IS NULL THEN
        curr_version := 1;
    END IF;

    -- If value changed, insert version
    IF p_secret_value IS NOT NULL AND p_secret_value <> '' THEN
        curr_version := curr_version + 1;
        INSERT INTO public.vault_secret_versions (
            secret_id, version, secret_value, created_by
        ) VALUES (
            p_secret_id, curr_version, p_secret_value, p_modified_by
        );
    END IF;
    
    -- Update or insert metadata
    INSERT INTO public.vault_secret_metadata (
        secret_id, path, secret_type, next_rotation, status, created_by, modified_by, version
    ) VALUES (
        p_secret_id, 
        COALESCE(p_secret_path, 'secret/data'), 
        COALESCE(p_secret_type, 'API Key'), 
        p_secret_next_rotation, 
        COALESCE(p_secret_status, 'Active'), 
        p_modified_by, 
        p_modified_by, 
        curr_version
    )
    ON CONFLICT (secret_id) DO UPDATE SET
        path = COALESCE(p_secret_path, public.vault_secret_metadata.path),
        secret_type = COALESCE(p_secret_type, public.vault_secret_metadata.secret_type),
        next_rotation = COALESCE(p_secret_next_rotation, public.vault_secret_metadata.next_rotation),
        status = COALESCE(p_secret_status, public.vault_secret_metadata.status),
        modified_by = p_modified_by,
        version = curr_version;
END;
$$;

-- 6. Helper to list versions for a secret
CREATE OR REPLACE FUNCTION public.get_vault_secret_versions(secret_id uuid)
RETURNS TABLE (
    id uuid,
    version int,
    created_at timestamptz,
    created_by text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT v.id, v.version, v.created_at, v.created_by
    FROM public.vault_secret_versions v
    WHERE v.secret_id = get_vault_secret_versions.secret_id
    ORDER BY v.version DESC;
END;
$$;

-- 7. Helper to get a specific secret version value
CREATE OR REPLACE FUNCTION public.get_vault_secret_version_value(version_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    val text;
BEGIN
    SELECT secret_value INTO val
    FROM public.vault_secret_versions
    WHERE id = version_id;
    RETURN val;
END;
$$;

-- 8. Seed sample data to match high-fidelity mockup
DO $$
DECLARE
    sec_id UUID;
BEGIN
    -- Only seed if metadata table is empty
    IF NOT EXISTS (SELECT 1 FROM public.vault_secret_metadata) THEN
        -- DB Connection String
        sec_id := vault.create_secret('postgresql://admin:super-secure-pass-2026@db.edushamiit.prod:5432/main_db', 'DB Connection String', 'Primary database connection string for production environment.');
        INSERT INTO public.vault_secret_metadata (secret_id, path, secret_type, next_rotation, status, created_by, modified_by, version)
        VALUES (sec_id, 'secret/data/database/prod', 'Password', NOW() + INTERVAL '30 days', 'Active', 'Super Admin', 'System', 3);
        INSERT INTO public.vault_secret_versions (secret_id, version, secret_value, created_by)
        VALUES (sec_id, 1, 'postgresql://admin:old-pass@db.edushamiit.prod:5432/main_db', 'Super Admin'),
               (sec_id, 2, 'postgresql://admin:sec-pass@db.edushamiit.prod:5432/main_db', 'System'),
               (sec_id, 3, 'postgresql://admin:super-secure-pass-2026@db.edushamiit.prod:5432/main_db', 'System');

        -- AWS Access Key
        sec_id := vault.create_secret('AKIAIOSFODNN7EXAMPLE', 'AWS Access Key', 'Cloud storage key for assets bucket.');
        INSERT INTO public.vault_secret_metadata (secret_id, path, secret_type, next_rotation, status, created_by, modified_by, version)
        VALUES (sec_id, 'secret/data/aws/production', 'API Key', NOW() + INTERVAL '45 days', 'Active', 'Super Admin', 'System', 1);
        INSERT INTO public.vault_secret_versions (secret_id, version, secret_value, created_by)
        VALUES (sec_id, 1, 'AKIAIOSFODNN7EXAMPLE', 'Super Admin');

        -- Google OAuth Client
        sec_id := vault.create_secret('123456789-googleoauthclientid.apps.googleusercontent.com', 'Google OAuth Client', 'OAuth client id for social login.');
        INSERT INTO public.vault_secret_metadata (secret_id, path, secret_type, next_rotation, status, created_by, modified_by, version)
        VALUES (sec_id, 'secret/data/google/oauth', 'Key / Secret', NOW() + INTERVAL '90 days', 'Active', 'Super Admin', 'System', 1);
        INSERT INTO public.vault_secret_versions (secret_id, version, secret_value, created_by)
        VALUES (sec_id, 1, '123456789-googleoauthclientid.apps.googleusercontent.com', 'Super Admin');

        -- SMTP Credential
        sec_id := vault.create_secret('smtp_user_production@smtp.mailgun.org:strong_password_xyz', 'SMTP Credential', 'SMTP configuration for email microservice.');
        INSERT INTO public.vault_secret_metadata (secret_id, path, secret_type, next_rotation, status, created_by, modified_by, version)
        VALUES (sec_id, 'secret/data/email/smtp', 'Username / Pass', NOW() + INTERVAL '30 days', 'Active', 'Super Admin', 'System', 1);
        INSERT INTO public.vault_secret_versions (secret_id, version, secret_value, created_by)
        VALUES (sec_id, 1, 'smtp_user_production@smtp.mailgun.org:strong_password_xyz', 'Super Admin');

        -- GitHub Token
        sec_id := vault.create_secret('ghp_securegithubdeveloperpersonaltoken12345', 'GitHub Token', 'GitHub personal access token for deployment workflows.');
        INSERT INTO public.vault_secret_metadata (secret_id, path, secret_type, next_rotation, status, created_by, modified_by, version)
        VALUES (sec_id, 'secret/data/github/token', 'Token', NOW() + INTERVAL '30 days', 'Active', 'Super Admin', 'System', 1);
        INSERT INTO public.vault_secret_versions (secret_id, version, secret_value, created_by)
        VALUES (sec_id, 1, 'ghp_securegithubdeveloperpersonaltoken12345', 'Super Admin');

        -- JWT Signing Key
        sec_id := vault.create_secret('super-secret-jwt-signing-key-256-bits-edushamiit', 'JWT Signing Key', 'Secret key used to sign and verify user authentication tokens.');
        INSERT INTO public.vault_secret_metadata (secret_id, path, secret_type, next_rotation, status, created_by, modified_by, version)
        VALUES (sec_id, 'secret/data/security/jwt', 'Private Key', NOW() + INTERVAL '25 days', 'Expiring Soon', 'Super Admin', 'System', 1);
        INSERT INTO public.vault_secret_versions (secret_id, version, secret_value, created_by)
        VALUES (sec_id, 1, 'super-secret-jwt-signing-key-256-bits-edushamiit', 'Super Admin');

        -- Azure Storage Key
        sec_id := vault.create_secret('azure_storage_account_key_secret_string', 'Azure Storage Key', 'Storage account key for backup files.');
        INSERT INTO public.vault_secret_metadata (secret_id, path, secret_type, next_rotation, status, created_by, modified_by, version)
        VALUES (sec_id, 'secret/data/azure/storage', 'Connection String', NOW() - INTERVAL '5 days', 'Expired', 'Super Admin', 'System', 1);
        INSERT INTO public.vault_secret_versions (secret_id, version, secret_value, created_by)
        VALUES (sec_id, 1, 'azure_storage_account_key_secret_string', 'Super Admin');

        -- Slack Webhook URL
        sec_id := vault.create_secret('https://hooks.slack.com/services/YOUR_WORKSPACE_ID/YOUR_CHANNEL_ID/YOUR_TOKEN_HERE', 'Slack Webhook URL', 'Incoming webhook for system alerts channel.');
        INSERT INTO public.vault_secret_metadata (secret_id, path, secret_type, next_rotation, status, created_by, modified_by, version)
        VALUES (sec_id, 'secret/data/slack/webhook', 'URL', NULL, 'Active', 'Super Admin', 'System', 1);
        INSERT INTO public.vault_secret_versions (secret_id, version, secret_value, created_by)
        VALUES (sec_id, 1, 'https://hooks.slack.com/services/YOUR_WORKSPACE_ID/YOUR_CHANNEL_ID/YOUR_TOKEN_HERE', 'Super Admin');
    END IF;
END;
$$;
