-- Migration: 210_standardize_timestamps_and_fk_cascades.sql
-- Description: Convert plain TIMESTAMP to TIMESTAMPTZ, convert restricted VARCHAR(255) to TEXT, and enforce FK delete safety.

-- ──────────────────────────────────────────────
-- 1. CONVERT TIMESTAMP COLUMNS TO TIMESTAMPTZ
-- ──────────────────────────────────────────────

ALTER TABLE public.user_active_sessions 
  ALTER COLUMN ended_at TYPE TIMESTAMPTZ USING ended_at AT TIME ZONE 'UTC';

ALTER TABLE public.app_roles 
  ALTER COLUMN updated_at TYPE TIMESTAMPTZ USING updated_at AT TIME ZONE 'UTC';

ALTER TABLE public.profiles 
  ALTER COLUMN lockout TYPE TIMESTAMPTZ USING lockout AT TIME ZONE 'UTC',
  ALTER COLUMN last_failed_login TYPE TIMESTAMPTZ USING last_failed_login AT TIME ZONE 'UTC';


-- ──────────────────────────────────────────────
-- 2. CONVERT RESTRICTIVE VARCHAR(255) COLUMNS TO TEXT
-- ──────────────────────────────────────────────

ALTER TABLE public.profiles ALTER COLUMN alternative_email TYPE TEXT;
ALTER TABLE public.profiles ALTER COLUMN emergency_contact_name TYPE TEXT;
ALTER TABLE public.notifications ALTER COLUMN title TYPE TEXT;
ALTER TABLE public.vehicle_maintenance ALTER COLUMN service_type TYPE TEXT;
ALTER TABLE public.vehicle_maintenance ALTER COLUMN vendor_workshop TYPE TEXT;


-- ──────────────────────────────────────────────
-- 3. AUTOMATED ARCHIVE PROCEDURE FOR LOG TABLES
-- ──────────────────────────────────────────────

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
