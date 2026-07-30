-- Migration: 191_automatic_trip_status_and_cancellation_reasons.sql
-- Description: Add cancellation_reason to vehicle_trips, auto update status based on trip date (today=in_progress, future=scheduled, past=completed)

ALTER TABLE public.vehicle_trips
  ADD COLUMN IF NOT EXISTS cancellation_reason text;

-- Function to auto-update trip statuses based on date
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

-- Execute initial status synchronization
SELECT auto_update_vehicle_trip_statuses();
