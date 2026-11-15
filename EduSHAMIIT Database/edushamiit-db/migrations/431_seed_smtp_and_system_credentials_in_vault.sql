-- Database Migration: 430_seed_smtp_and_system_credentials_in_vault.sql
-- Seeds real working SMTP, TomTom GIS, LiveKit, MinIO, and JWT credentials into Supabase Vault.

DO $$
BEGIN
    -- 1. SMTP Credential (Compound credential string)
    PERFORM public.create_vault_secret_v2(
        'SMTP Credential',
        'binaftab936@gmail.com:jjbstxbmjcygupzg@smtp.gmail.com:587',
        'Gmail SMTP production credentials for email & OTP dispatch',
        'secret/data/email/smtp',
        'Username / Pass',
        NULL,
        'Super Admin',
        'global',
        NULL
    );

    -- 2. Granular SMTP Keys for direct environment & service binding
    PERFORM public.create_vault_secret_v2(
        'SMTP_USER',
        'binaftab936@gmail.com',
        'SMTP Sender Account Username',
        'secret/data/email/user',
        'Username / Pass',
        NULL,
        'Super Admin',
        'global',
        NULL
    );

    PERFORM public.create_vault_secret_v2(
        'SMTP_PASS',
        'jjbstxbmjcygupzg',
        'SMTP Application Password (16-char Google App Password)',
        'secret/data/email/password',
        'Password',
        NULL,
        'Super Admin',
        'global',
        NULL
    );

    PERFORM public.create_vault_secret_v2(
        'SMTP_HOST',
        'smtp.gmail.com',
        'SMTP Server Hostname',
        'secret/data/email/host',
        'Config',
        NULL,
        'Super Admin',
        'global',
        NULL
    );

    PERFORM public.create_vault_secret_v2(
        'SMTP_PORT',
        '587',
        'SMTP Server TLS Port',
        'secret/data/email/port',
        'Config',
        NULL,
        'Super Admin',
        'global',
        NULL
    );

    PERFORM public.create_vault_secret_v2(
        'EMAIL_FROM',
        'binaftab936@gmail.com',
        'Default System Outgoing From Address',
        'secret/data/email/from',
        'Config',
        NULL,
        'Super Admin',
        'global',
        NULL
    );

    PERFORM public.create_vault_secret_v2(
        'SMTP_SENDER_NAME',
        'EduSHAMIIT',
        'Default System Outgoing Sender Display Name',
        'secret/data/email/sender_name',
        'Config',
        NULL,
        'Super Admin',
        'global',
        NULL
    );

    -- 3. TomTom Maps & Search API Key (GIS / Transport)
    PERFORM public.create_vault_secret_v2(
        'TOMTOM_API_KEY',
        'FyoN32k3iT1vAcmOq91A0uT5L9a1fD3v',
        'TomTom Maps & Search API Key for Transport Tracking & Routing',
        'secret/data/gis/tomtom',
        'API Key',
        NULL,
        'Super Admin',
        'global',
        NULL
    );

    -- 4. LiveKit Streaming Server Credentials
    PERFORM public.create_vault_secret_v2(
        'LIVEKIT_API_KEY',
        'devkey',
        'LiveKit WebRTC Media Server Key',
        'secret/data/livekit/key',
        'API Key',
        NULL,
        'Super Admin',
        'global',
        NULL
    );

    PERFORM public.create_vault_secret_v2(
        'LIVEKIT_API_SECRET',
        'secret_key_for_livekit_stream_secure',
        'LiveKit WebRTC Media Server API Secret',
        'secret/data/livekit/secret',
        'Key / Secret',
        NULL,
        'Super Admin',
        'global',
        NULL
    );

    -- 5. MinIO Object Storage Keys
    PERFORM public.create_vault_secret_v2(
        'MINIO_ACCESS_KEY',
        '6257a030422c1db4e2c9823533be223c',
        'MinIO S3 Compatible Object Storage Access Key',
        'secret/data/storage/minio_access_key',
        'API Key',
        NULL,
        'Super Admin',
        'global',
        NULL
    );

    PERFORM public.create_vault_secret_v2(
        'MINIO_SECRET_KEY',
        '8501257feff8eb34839cf9b62c2f6d0a7905106199aefea425a80e14db8cf907',
        'MinIO S3 Compatible Object Storage Secret Key',
        'secret/data/storage/minio_secret_key',
        'Key / Secret',
        NULL,
        'Super Admin',
        'global',
        NULL
    );

    -- 6. JWT Signing Key (Sync with active JWT_SECRET)
    PERFORM public.create_vault_secret_v2(
        'JWT Signing Key',
        'super-secret-jwt-token-with-at-least-32-characters-long',
        'Primary HMAC-SHA256 Secret for ERP User Authentication Tokens',
        'secret/data/security/jwt',
        'Private Key',
        NULL,
        'Super Admin',
        'global',
        NULL
    );

    -- 7. Database Connection String (Sync with active credentials)
    PERFORM public.create_vault_secret_v2(
        'DB Connection String',
        'postgresql://postgres:eduSHAMIIT2026_pg@supabase-db:5432/postgres',
        'Primary PostgreSQL Database Connection URI',
        'secret/data/database/prod',
        'Connection String',
        NULL,
        'Super Admin',
        'global',
        NULL
    );

END $$;
