-- Migration: 194_fix_auto_update_trip_statuses.sql
-- Description: Fix auto_update_vehicle_trip_statuses procedure so newly created trips are NEVER automatically cancelled

CREATE OR REPLACE FUNCTION auto_update_vehicle_trip_statuses()
RETURNS void AS $$
BEGIN
  -- 1. Today trips: mark in_progress (Ongoing) if not cancelled or completed
  UPDATE public.vehicle_trips
  SET status = 'in_progress'
  WHERE (start_date = CURRENT_DATE::text OR scheduled_start::date = CURRENT_DATE)
    AND LOWER(status) NOT IN ('cancelled', 'completed');

  -- 2. Future trips: mark scheduled if not cancelled
  UPDATE public.vehicle_trips
  SET status = 'scheduled'
  WHERE (
    (start_date IS NOT NULL AND start_date::date > CURRENT_DATE) OR
    (scheduled_start IS NOT NULL AND scheduled_start::date > CURRENT_DATE)
  ) AND LOWER(status) NOT IN ('cancelled');

  -- 3. Past trips: mark completed if was scheduled or in_progress
  UPDATE public.vehicle_trips
  SET status = 'completed'
  WHERE (
    (start_date IS NOT NULL AND start_date::date < CURRENT_DATE) OR
    (scheduled_start IS NOT NULL AND scheduled_start::date < CURRENT_DATE)
  ) AND LOWER(status) IN ('scheduled', 'in_progress');
END;
$$ LANGUAGE plpgsql;

-- Reset any incorrectly cancelled trips back to active status
UPDATE public.vehicle_trips
SET status = 'scheduled', cancellation_reason = NULL
WHERE cancellation_reason = 'Driver on Leave'
  AND (cancelled_dates IS NULL OR array_length(cancelled_dates, 1) IS NULL OR array_length(cancelled_dates, 1) = 0);

SELECT auto_update_vehicle_trip_statuses();
