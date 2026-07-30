-- Migration: 187_enhance_driver_assignments_fields.sql
-- Description: Add comprehensive fields for driver assignments in fleet management

ALTER TABLE public.driver_assignments
  ADD COLUMN IF NOT EXISTS start_time text DEFAULT '06:30 AM',
  ADD COLUMN IF NOT EXISTS end_time text DEFAULT '09:30 AM',
  ADD COLUMN IF NOT EXISTS days text DEFAULT 'Mon,Tue,Wed,Thu,Fri',
  ADD COLUMN IF NOT EXISTS distance numeric(10,2) DEFAULT 15.00,
  ADD COLUMN IF NOT EXISTS estimated_duration text DEFAULT '45 mins',
  ADD COLUMN IF NOT EXISTS total_stops integer DEFAULT 10,
  ADD COLUMN IF NOT EXISTS created_by text DEFAULT 'Transport Manager';

-- Comment on columns
COMMENT ON COLUMN public.driver_assignments.start_time IS 'Assignment shift start time (e.g. 06:30 AM)';
COMMENT ON COLUMN public.driver_assignments.end_time IS 'Assignment shift end time (e.g. 09:30 AM)';
COMMENT ON COLUMN public.driver_assignments.days IS 'Operating days comma separated (e.g. Mon,Tue,Wed,Thu,Fri)';
COMMENT ON COLUMN public.driver_assignments.distance IS 'Route distance in kilometers';
COMMENT ON COLUMN public.driver_assignments.estimated_duration IS 'Estimated route trip duration';
COMMENT ON COLUMN public.driver_assignments.total_stops IS 'Total number of stoppages on route';
COMMENT ON COLUMN public.driver_assignments.created_by IS 'Name of transport manager or admin who created assignment';
