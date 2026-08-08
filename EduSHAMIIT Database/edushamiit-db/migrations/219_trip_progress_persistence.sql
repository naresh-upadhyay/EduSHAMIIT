-- Migration: 219_trip_progress_persistence.sql
-- Description: Add route progress persistence columns to vehicle_trips and unique constraints for student_trip_logs & trip_stop_logs upserts

ALTER TABLE public.vehicle_trips
  ADD COLUMN IF NOT EXISTS bus_position_ratio NUMERIC(6, 4) DEFAULT 0.0,
  ADD COLUMN IF NOT EXISTS current_stop_index INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS elapsed_seconds INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS distance_km NUMERIC(8, 2) DEFAULT 0.0,
  ADD COLUMN IF NOT EXISTS current_lat NUMERIC(10, 6),
  ADD COLUMN IF NOT EXISTS current_lng NUMERIC(10, 6);

ALTER TABLE public.transport_routes
  ADD COLUMN IF NOT EXISTS live_status TEXT DEFAULT 'offline',
  ADD COLUMN IF NOT EXISTS is_visible BOOLEAN DEFAULT false;

ALTER TABLE public.vehicles
  ADD COLUMN IF NOT EXISTS is_visible BOOLEAN DEFAULT false;

-- Add Unique Constraints to enable UPSERT on student_trip_logs and trip_stop_logs
ALTER TABLE public.student_trip_logs
  DROP CONSTRAINT IF EXISTS uq_student_trip_logs_trip_student;
ALTER TABLE public.student_trip_logs
  ADD CONSTRAINT uq_student_trip_logs_trip_student UNIQUE (trip_id, student_id);

ALTER TABLE public.trip_stop_logs
  DROP CONSTRAINT IF EXISTS uq_trip_stop_logs_trip_stop;
ALTER TABLE public.trip_stop_logs
  ADD CONSTRAINT uq_trip_stop_logs_trip_stop UNIQUE (trip_id, stop_id);

CREATE INDEX IF NOT EXISTS idx_vehicle_trips_route_status ON public.vehicle_trips(route_id, status);
CREATE INDEX IF NOT EXISTS idx_transport_routes_live_status ON public.transport_routes(live_status);
