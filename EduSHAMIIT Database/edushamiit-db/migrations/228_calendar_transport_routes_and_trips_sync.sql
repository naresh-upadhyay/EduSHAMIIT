-- ============================================================================
-- Migration 228: Universal Calendar Transport Routes & Vehicle Trips Sync
-- Description:
-- 1. Links schedules to transport_routes via route_id.
-- 2. Links vehicle_trips to schedules via schedule_id and schedule_instance_date.
-- 3. Adds indexes for fast lookup and cascade integrity.
-- ============================================================================

-- 1. Add route_id to public.schedules
ALTER TABLE IF EXISTS public.schedules
  ADD COLUMN IF NOT EXISTS route_id UUID REFERENCES public.transport_routes(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_schedules_route ON public.schedules(route_id);

-- 2. Add schedule_id and schedule_instance_date to public.vehicle_trips
ALTER TABLE IF EXISTS public.vehicle_trips
  ADD COLUMN IF NOT EXISTS schedule_id UUID REFERENCES public.schedules(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS schedule_instance_date DATE;

CREATE INDEX IF NOT EXISTS idx_vehicle_trips_schedule_id ON public.vehicle_trips(schedule_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_trips_schedule_date ON public.vehicle_trips(schedule_id, start_date);
CREATE INDEX IF NOT EXISTS idx_vehicle_trips_route_date ON public.vehicle_trips(route_id, start_date);

-- 3. Ensure start_date and start_time columns exist on vehicle_trips
ALTER TABLE IF EXISTS public.vehicle_trips
  ADD COLUMN IF NOT EXISTS start_date DATE,
  ADD COLUMN IF NOT EXISTS start_time TIME,
  ADD COLUMN IF NOT EXISTS end_date DATE,
  ADD COLUMN IF NOT EXISTS end_time TIME,
  ADD COLUMN IF NOT EXISTS driver_id UUID REFERENCES public.drivers(id) ON DELETE SET NULL;
