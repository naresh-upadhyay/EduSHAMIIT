-- Migration 440: Align Vault LIVEKIT_API_SECRET with the active LiveKit SFU server key configuration
-- Prevents [Vault Sync] from overwriting API runtime secret with stale placeholder secret_key_for_livekit_stream_secure.

DO $$
DECLARE
    v_current TEXT;
BEGIN
    SELECT decrypted_secret
    INTO v_current
    FROM vault.decrypted_secrets
    WHERE name = 'LIVEKIT_API_SECRET'
    LIMIT 1;

    IF v_current IS DISTINCT FROM 'secretkey_edushamiit_livekit_2026_secure' THEN
        PERFORM public.create_vault_secret_v2(
            'LIVEKIT_API_SECRET',
            'secretkey_edushamiit_livekit_2026_secure',
            'LiveKit WebRTC Media Server API Secret',
            'secret/data/livekit/secret',
            'Key / Secret',
            NULL,
            'Super Admin',
            'global',
            NULL
        );
    END IF;
END $$;

