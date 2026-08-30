-- Migration: 211_enable_pg_cron_automated_archiving.sql
-- Description: Enable PostgreSQL pg_cron extension and schedule nightly automated execution of archive_old_audit_logs.

-- 1. Enable pg_cron extension if available on PostgreSQL server / Supabase
DO $$
BEGIN
  CREATE EXTENSION IF NOT EXISTS pg_cron;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pg_cron cannot be created in this database: %', SQLERRM;
END $$;

-- 2. Schedule Nightly Automated Cleanup at 2:00 AM UTC
DO $do$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    -- Unschedule existing job if present to avoid duplication
    PERFORM cron.unschedule('nightly_audit_log_cleanup');
    
    -- Schedule nightly execution of archive_old_audit_logs(90)
    PERFORM cron.schedule(
      'nightly_audit_log_cleanup',
      '0 2 * * *', -- Every night at 2:00 AM UTC
      $cron_cmd$SELECT public.archive_old_audit_logs(90);$cron_cmd$
    );
  END IF;
EXCEPTION WHEN OTHERS THEN
  -- Graceful fallback if pg_cron is restricted by cloud host permissions
  RAISE NOTICE 'pg_cron extension not supported on host; background scheduler will handle archiving.';
END $do$;
