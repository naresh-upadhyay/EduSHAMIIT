-- Migration: 189_bidirectional_delete_sync_triggers.sql
-- Description: Implement complete bi-directional deletion & update triggers between driver_assignments and vehicle_trips

-- 1. Clean orphan records from vehicle_trips and driver_assignments so both have exact 1:1 match
DELETE FROM public.vehicle_trips 
WHERE driver_assignment_id IS NOT NULL 
  AND driver_assignment_id NOT IN (SELECT id FROM public.driver_assignments);

DELETE FROM public.vehicle_trips 
WHERE driver_assignment_id IS NULL 
  AND id NOT IN (SELECT trip_id FROM public.driver_assignments WHERE trip_id IS NOT NULL);

-- 2. Trigger function for driver_assignments -> vehicle_trips
CREATE OR REPLACE FUNCTION sync_driver_assignment_to_trip()
RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'DELETE') THEN
    DELETE FROM public.vehicle_trips 
    WHERE driver_assignment_id = OLD.id 
       OR (OLD.trip_id IS NOT NULL AND id = OLD.trip_id);
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

DROP TRIGGER IF EXISTS trg_sync_driver_assignment_to_trip ON public.driver_assignments;
CREATE TRIGGER trg_sync_driver_assignment_to_trip
  AFTER INSERT OR UPDATE OR DELETE ON public.driver_assignments
  FOR EACH ROW EXECUTE FUNCTION sync_driver_assignment_to_trip();

-- 3. Trigger function for vehicle_trips -> driver_assignments
CREATE OR REPLACE FUNCTION sync_trip_to_driver_assignment()
RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'DELETE') THEN
    DELETE FROM public.driver_assignments 
    WHERE trip_id = OLD.id 
       OR (OLD.driver_assignment_id IS NOT NULL AND id = OLD.driver_assignment_id);
    RETURN OLD;
  ELSIF (TG_OP = 'UPDATE') THEN
    IF OLD.driver_assignment_id IS NOT NULL OR OLD.id IS NOT NULL THEN
      UPDATE public.driver_assignments SET
        notes = NEW.notes,
        status = CASE 
          WHEN LOWER(NEW.status) = 'in_progress' THEN 'Active'
          WHEN LOWER(NEW.status) = 'scheduled' THEN 'Upcoming'
          WHEN LOWER(NEW.status) = 'completed' THEN 'Completed'
          WHEN LOWER(NEW.status) = 'cancelled' THEN 'Cancelled'
          ELSE 'Active'
        END
      WHERE id = NEW.driver_assignment_id OR trip_id = NEW.id;
    END IF;
    RETURN NEW;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_trip_to_driver_assignment ON public.vehicle_trips;
CREATE TRIGGER trg_sync_trip_to_driver_assignment
  AFTER UPDATE OR DELETE ON public.vehicle_trips
  FOR EACH ROW EXECUTE FUNCTION sync_trip_to_driver_assignment();
