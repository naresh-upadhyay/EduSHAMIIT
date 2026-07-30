-- Migration: 190_enhance_vehicle_trips_timing.sql
-- Description: Add start_time, end_time, start_date, and end_date columns to vehicle_trips with pg_trigger_depth recursion guard

-- 1. Add missing columns to vehicle_trips
ALTER TABLE public.vehicle_trips
  ADD COLUMN IF NOT EXISTS start_time text DEFAULT '06:30 AM',
  ADD COLUMN IF NOT EXISTS end_time text DEFAULT '09:30 AM',
  ADD COLUMN IF NOT EXISTS start_date text,
  ADD COLUMN IF NOT EXISTS end_date text,
  ADD COLUMN IF NOT EXISTS days text DEFAULT 'Mon,Tue,Wed,Thu,Fri,Sat';

-- 2. Update trigger function sync_driver_assignment_to_trip with pg_trigger_depth guard
CREATE OR REPLACE FUNCTION sync_driver_assignment_to_trip()
RETURNS TRIGGER AS $$
BEGIN
  IF pg_trigger_depth() > 1 THEN
    RETURN NEW;
  END IF;

  IF (TG_OP = 'DELETE') THEN
    DELETE FROM public.vehicle_trips 
    WHERE driver_assignment_id = OLD.id 
       OR (OLD.trip_id IS NOT NULL AND id = OLD.trip_id);
    RETURN OLD;
  ELSIF (TG_OP = 'INSERT') THEN
    INSERT INTO public.vehicle_trips (
      id, school_id, driver_id, vehicle_id, route_id, driver_assignment_id,
      trip_type, status, start_time, end_time, start_date, end_date, days,
      scheduled_start, distance_km, notes, created_at
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
      COALESCE(NEW.start_time, '06:30 AM'),
      COALESCE(NEW.end_time, '09:30 AM'),
      NEW.start_date,
      NEW.end_date,
      COALESCE(NEW.days, 'Mon,Tue,Wed,Thu,Fri,Sat'),
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
      start_time = EXCLUDED.start_time,
      end_time = EXCLUDED.end_time,
      start_date = EXCLUDED.start_date,
      end_date = EXCLUDED.end_date,
      days = EXCLUDED.days,
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
      start_time = COALESCE(NEW.start_time, '06:30 AM'),
      end_time = COALESCE(NEW.end_time, '09:30 AM'),
      start_date = NEW.start_date,
      end_date = NEW.end_date,
      days = COALESCE(NEW.days, 'Mon,Tue,Wed,Thu,Fri,Sat'),
      notes = NEW.notes
    WHERE driver_assignment_id = NEW.id OR (NEW.trip_id IS NOT NULL AND id = NEW.trip_id);
    RETURN NEW;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 3. Update trigger function sync_trip_to_driver_assignment with pg_trigger_depth guard
CREATE OR REPLACE FUNCTION sync_trip_to_driver_assignment()
RETURNS TRIGGER AS $$
BEGIN
  IF pg_trigger_depth() > 1 THEN
    RETURN NEW;
  END IF;

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

-- 4. Backfill timing and date columns from driver_assignments into vehicle_trips
UPDATE public.vehicle_trips vt
SET 
  start_time = COALESCE(da.start_time, '06:30 AM'),
  end_time = COALESCE(da.end_time, '09:30 AM'),
  start_date = da.start_date,
  end_date = da.end_date,
  days = COALESCE(da.days, 'Mon,Tue,Wed,Thu,Fri,Sat')
FROM public.driver_assignments da
WHERE vt.driver_assignment_id = da.id OR vt.id = da.trip_id;
