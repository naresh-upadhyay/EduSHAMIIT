-- Migration: 210_standardize_timestamps_and_fk_cascades.sql
-- Description: Convert plain TIMESTAMP to TIMESTAMPTZ, convert restricted VARCHAR(255) to TEXT, and enforce FK delete safety.

-- ──────────────────────────────────────────────
-- 1. CONVERT TIMESTAMP COLUMNS TO TIMESTAMPTZ
-- ──────────────────────────────────────────────

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'user_active_sessions' AND column_name = 'ended_at') THEN
    ALTER TABLE public.user_active_sessions ALTER COLUMN ended_at TYPE TIMESTAMPTZ USING ended_at AT TIME ZONE 'UTC';
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'app_roles' AND column_name = 'updated_at') THEN
    ALTER TABLE public.app_roles ALTER COLUMN updated_at TYPE TIMESTAMPTZ USING updated_at AT TIME ZONE 'UTC';
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'lockout') THEN
    ALTER TABLE public.profiles ALTER COLUMN lockout TYPE TIMESTAMPTZ USING lockout AT TIME ZONE 'UTC';
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'last_failed_login') THEN
    ALTER TABLE public.profiles ALTER COLUMN last_failed_login TYPE TIMESTAMPTZ USING last_failed_login AT TIME ZONE 'UTC';
  END IF;
END $$;


-- ──────────────────────────────────────────────
-- 2. CONVERT RESTRICTIVE VARCHAR(255) COLUMNS TO TEXT
-- ──────────────────────────────────────────────

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'alternative_email') THEN
    ALTER TABLE public.profiles ALTER COLUMN alternative_email TYPE TEXT;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'emergency_contact_name') THEN
    ALTER TABLE public.profiles ALTER COLUMN emergency_contact_name TYPE TEXT;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'title') THEN
    ALTER TABLE public.notifications ALTER COLUMN title TYPE TEXT;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'vehicle_maintenance') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'vehicle_maintenance' AND column_name = 'service_type') THEN
      ALTER TABLE public.vehicle_maintenance ALTER COLUMN service_type TYPE TEXT;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'vehicle_maintenance' AND column_name = 'vendor_workshop') THEN
      ALTER TABLE public.vehicle_maintenance ALTER COLUMN vendor_workshop TYPE TEXT;
    END IF;
  END IF;
END $$;


-- ──────────────────────────────────────────────
-- 3. AUTOMATED ARCHIVE PROCEDURE FOR LOG TABLES
-- ──────────────────────────────────────────────

DROP FUNCTION IF EXISTS public.archive_old_audit_logs(INT) CASCADE;
CREATE OR REPLACE FUNCTION public.archive_old_audit_logs(p_retention_days INT DEFAULT 90)
RETURNS INT
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
AS $$
DECLARE
  v_deleted_count INT := 0;
BEGIN
  DELETE FROM public.audit_logs
  WHERE created_at < (NOW() - (p_retention_days || ' days')::INTERVAL);

  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

  RETURN v_deleted_count;
END;
$$;
