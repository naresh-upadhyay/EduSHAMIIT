-- Migration: 193_add_cancelled_dates_to_vehicle_trips.sql
-- Description: Add cancelled_dates array column to vehicle_trips for granular single-date cancellation tracking without destroying multi-day schedules

ALTER TABLE public.vehicle_trips
  ADD COLUMN IF NOT EXISTS cancelled_dates text[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS cancellation_reason text;

-- Update trigger / auto status function to respect cancelled_dates
CREATE OR REPLACE FUNCTION auto_update_vehicle_trip_statuses()
RETURNS void AS $$
BEGIN
  -- 1. Check leave_applications for driver leave and add leave dates to cancelled_dates
  UPDATE public.vehicle_trips vt
  SET 
    cancellation_reason = 'Driver on Leave',
    cancelled_dates = ARRAY(
      SELECT DISTINCT d
      FROM unnest(COALESCE(vt.cancelled_dates, '{}') || ARRAY(
        SELECT gs::date::text
        FROM public.leave_applications la
        JOIN public.drivers dr ON (dr.profile_id = la.applicant_id OR dr.id = la.applicant_id)
        CROSS JOIN generate_series(la.start_date::timestamp, la.end_date::timestamp, '1 day'::interval) gs
        WHERE vt.driver_id = dr.id
          AND LOWER(la.status) IN ('approved', 'pending')
      )) d
    )
  WHERE vt.driver_id IS NOT NULL;

  -- 2. Today trips: mark in_progress (Ongoing) if not cancelled or completed
  UPDATE public.vehicle_trips
  SET status = 'in_progress'
  WHERE (start_date = CURRENT_DATE::text OR scheduled_start::date = CURRENT_DATE)
    AND LOWER(status) NOT IN ('cancelled', 'completed');

  -- 3. Future trips: mark scheduled if not cancelled
  UPDATE public.vehicle_trips
  SET status = 'scheduled'
  WHERE (
    (start_date IS NOT NULL AND start_date::date > CURRENT_DATE) OR
    (scheduled_start IS NOT NULL AND scheduled_start::date > CURRENT_DATE)
  ) AND LOWER(status) NOT IN ('cancelled');

  -- 4. Past trips: mark completed if was scheduled or in_progress
  UPDATE public.vehicle_trips
  SET status = 'completed'
  WHERE (
    (start_date IS NOT NULL AND start_date::date < CURRENT_DATE) OR
    (scheduled_start IS NOT NULL AND scheduled_start::date < CURRENT_DATE)
  ) AND LOWER(status) IN ('scheduled', 'in_progress');
END;
$$ LANGUAGE plpgsql;

SELECT auto_update_vehicle_trip_statuses();
