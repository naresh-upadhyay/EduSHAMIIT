-- Migration: 192_driver_leave_auto_cancel_trips.sql
-- Description: Automatically mark trips as cancelled if assigned driver has approved/pending leave in leave_applications

ALTER TABLE public.vehicle_trips ADD COLUMN IF NOT EXISTS cancellation_reason text;

CREATE OR REPLACE FUNCTION auto_update_vehicle_trip_statuses()
RETURNS void AS $$
BEGIN
  -- 1. Check leave_applications for driver leave and mark matching trips as cancelled (Driver on Leave)
  UPDATE public.vehicle_trips vt
  SET 
    status = 'cancelled',
    cancellation_reason = 'Driver on Leave',
    notes = CASE 
      WHEN vt.notes IS NULL OR vt.notes = '' THEN 'Cancelled: Driver on Leave'
      WHEN vt.notes NOT LIKE '%Cancelled: Driver on Leave%' THEN vt.notes || ' | Cancelled: Driver on Leave'
      ELSE vt.notes
    END
  FROM public.leave_applications la
  JOIN public.drivers d ON (d.profile_id = la.applicant_id OR d.id = la.applicant_id)
  WHERE vt.driver_id = d.id
    AND LOWER(la.status) IN ('approved', 'pending')
    AND (
      (vt.start_date IS NOT NULL AND vt.start_date::date BETWEEN la.start_date AND la.end_date) OR
      (vt.scheduled_start IS NOT NULL AND vt.scheduled_start::date BETWEEN la.start_date AND la.end_date)
    )
    AND LOWER(vt.status) != 'cancelled';

  -- 2. Sync driver_assignments status to Cancelled for driver on leave trips
  UPDATE public.driver_assignments da
  SET 
    status = 'Cancelled',
    notes = CASE 
      WHEN da.notes IS NULL OR da.notes = '' THEN 'Cancelled: Driver on Leave'
      WHEN da.notes NOT LIKE '%Cancelled: Driver on Leave%' THEN da.notes || ' | Cancelled: Driver on Leave'
      ELSE da.notes
    END
  FROM public.vehicle_trips vt
  WHERE (da.trip_id = vt.id OR da.id = vt.driver_assignment_id)
    AND LOWER(vt.status) = 'cancelled'
    AND vt.cancellation_reason = 'Driver on Leave'
    AND LOWER(da.status) != 'cancelled';

  -- 3. Today trips: mark in_progress (Ongoing) if not cancelled or completed
  UPDATE public.vehicle_trips
  SET status = 'in_progress'
  WHERE (start_date = CURRENT_DATE::text OR scheduled_start::date = CURRENT_DATE)
    AND LOWER(status) NOT IN ('cancelled', 'completed');

  -- 4. Future trips: mark scheduled if not cancelled
  UPDATE public.vehicle_trips
  SET status = 'scheduled'
  WHERE (
    (start_date IS NOT NULL AND start_date::date > CURRENT_DATE) OR
    (scheduled_start IS NOT NULL AND scheduled_start::date > CURRENT_DATE)
  ) AND LOWER(status) NOT IN ('cancelled');

  -- 5. Past trips: mark completed if was scheduled or in_progress
  UPDATE public.vehicle_trips
  SET status = 'completed'
  WHERE (
    (start_date IS NOT NULL AND start_date::date < CURRENT_DATE) OR
    (scheduled_start IS NOT NULL AND scheduled_start::date < CURRENT_DATE)
  ) AND LOWER(status) IN ('scheduled', 'in_progress');
END;
$$ LANGUAGE plpgsql;

-- Execute initial status & driver leave synchronization
SELECT auto_update_vehicle_trip_statuses();
