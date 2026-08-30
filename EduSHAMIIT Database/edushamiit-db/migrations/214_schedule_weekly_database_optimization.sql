-- Migration: 214_schedule_weekly_database_optimization.sql
-- Description: Schedule weekly automated execution of optimize_database_bloat_and_stats via pg_cron.

DO $migration$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    -- Unschedule existing job if present
    PERFORM cron.unschedule('weekly_db_optimization');
    
    -- Schedule weekly execution every Sunday at 3:00 AM UTC
    PERFORM cron.schedule(
      'weekly_db_optimization',
      '0 3 * * 0', -- Sunday at 3:00 AM UTC
      'SELECT public.optimize_database_bloat_and_stats();'
    );
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pg_cron extension not supported on host; background scheduler will handle weekly optimization.';
END $migration$;
