-- Migration: 188_sync_driver_assignments_and_vehicle_trips.sql
-- Description: Add driver_id & vehicle_id to vehicle_trips and set up bi-directional automatic sync triggers

-- 1. Add missing columns to vehicle_trips
ALTER TABLE public.vehicle_trips
  ADD COLUMN IF NOT EXISTS driver_id uuid REFERENCES public.drivers(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS vehicle_id uuid REFERENCES public.bus_routes(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS driver_assignment_id uuid REFERENCES public.driver_assignments(id) ON DELETE SET NULL;

-- 2. Add trip_id column to driver_assignments for tracking matching trip
ALTER TABLE public.driver_assignments
  ADD COLUMN IF NOT EXISTS trip_id uuid REFERENCES public.vehicle_trips(id) ON DELETE SET NULL;

-- 3. Function to sync driver_assignments -> vehicle_trips
CREATE OR REPLACE FUNCTION sync_driver_assignment_to_trip()
RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'DELETE') THEN
    DELETE FROM public.vehicle_trips WHERE driver_assignment_id = OLD.id OR (OLD.trip_id IS NOT NULL AND id = OLD.trip_id);
    RETURN OLD;
  ELSIF (TG_OP = 'INSERT') THEN
    INSERT INTO public.vehicle_trips (
      id, school_id, driver_id, vehicle_id, route_id, driver_assignment_id,
      trip_type, status, scheduled_start, distance_km, notes, created_at
    ) VALUES (
      COALESCE(NEW.trip_id, gen_random_uuid()),
      NEW.school_id,
      NEW.driver_id,
      NEW.vehicle_id,
      NEW.vehicle_id,
      NEW.id,
      LOWER(COALESCE(NEW.shift, 'morning')),
      CASE 
        WHEN LOWER(NEW.status) = 'active' THEN 'in_progress'
        WHEN LOWER(NEW.status) = 'upcoming' THEN 'scheduled'
        WHEN LOWER(NEW.status) = 'ended' THEN 'completed'
        WHEN LOWER(NEW.status) = 'completed' THEN 'completed'
        ELSE 'scheduled'
      END,
      COALESCE(NEW.start_date::timestamp, NOW()),
      COALESCE(NEW.distance, 15.0),
      NEW.notes,
      NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
      school_id = EXCLUDED.school_id,
      driver_id = EXCLUDED.driver_id,
      vehicle_id = EXCLUDED.vehicle_id,
      status = EXCLUDED.status,
      trip_type = EXCLUDED.trip_type,
      notes = EXCLUDED.notes;
    RETURN NEW;
  ELSIF (TG_OP = 'UPDATE') THEN
    UPDATE public.vehicle_trips SET
      school_id = NEW.school_id,
      driver_id = NEW.driver_id,
      vehicle_id = NEW.vehicle_id,
      route_id = NEW.vehicle_id,
      trip_type = LOWER(COALESCE(NEW.shift, 'morning')),
      status = CASE 
        WHEN LOWER(NEW.status) = 'active' THEN 'in_progress'
        WHEN LOWER(NEW.status) = 'upcoming' THEN 'scheduled'
        WHEN LOWER(NEW.status) = 'ended' THEN 'completed'
        WHEN LOWER(NEW.status) = 'completed' THEN 'completed'
        ELSE 'scheduled'
      END,
      notes = NEW.notes
    WHERE driver_assignment_id = NEW.id OR (NEW.trip_id IS NOT NULL AND id = NEW.trip_id);
    RETURN NEW;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 4. Create trigger on driver_assignments
DROP TRIGGER IF EXISTS trg_sync_driver_assignment_to_trip ON public.driver_assignments;
CREATE TRIGGER trg_sync_driver_assignment_to_trip
  AFTER INSERT OR UPDATE OR DELETE ON public.driver_assignments
  FOR EACH ROW EXECUTE FUNCTION sync_driver_assignment_to_trip();

-- 5. Backfill existing driver_assignments into vehicle_trips so all existing assignments sync immediately
INSERT INTO public.vehicle_trips (
  id, school_id, driver_id, vehicle_id, route_id, driver_assignment_id,
  trip_type, status, scheduled_start, distance_km, notes, created_at
)
SELECT 
  gen_random_uuid(),
  da.school_id,
  da.driver_id,
  da.vehicle_id,
  da.vehicle_id,
  da.id,
  LOWER(COALESCE(da.shift, 'morning')),
  CASE 
    WHEN LOWER(da.status) = 'active' THEN 'in_progress'
    WHEN LOWER(da.status) = 'upcoming' THEN 'scheduled'
    WHEN LOWER(da.status) = 'ended' THEN 'completed'
    WHEN LOWER(da.status) = 'completed' THEN 'completed'
    ELSE 'scheduled'
  END,
  COALESCE(da.start_date::timestamp, NOW()),
  COALESCE(da.distance, 15.0),
  da.notes,
  NOW()
FROM public.driver_assignments da
WHERE NOT EXISTS (
  SELECT 1 FROM public.vehicle_trips vt WHERE vt.driver_assignment_id = da.id
);
