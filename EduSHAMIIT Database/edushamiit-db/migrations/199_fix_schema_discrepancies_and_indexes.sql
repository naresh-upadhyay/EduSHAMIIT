-- Migration: 199_fix_schema_discrepancies_and_indexes.sql
-- Description: Unify transport & fleet references, clean up duplicate indexes, mark RLS functions STABLE, and prevent trigger recursion.

-- 1. Create a dedicated vehicles table if not exists, and align fleet references
CREATE TABLE IF NOT EXISTS public.vehicles (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id       UUID REFERENCES schools(id) ON DELETE CASCADE,
  vehicle_no      TEXT NOT NULL,
  category_id     UUID REFERENCES vehicle_categories(id) ON DELETE SET NULL,
  make_model      TEXT,
  year            INT,
  chassis_no      TEXT,
  engine_no       TEXT,
  fuel_type       TEXT DEFAULT 'Diesel',
  seating_capacity INT DEFAULT 52,
  status          TEXT NOT NULL DEFAULT 'Active', -- 'Active', 'Maintenance', 'Inactive'
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(school_id, vehicle_no)
);

CREATE INDEX IF NOT EXISTS idx_vehicles_school ON public.vehicles(school_id);
CREATE INDEX IF NOT EXISTS idx_vehicles_status ON public.vehicles(status);

-- Seed vehicles from bus_routes if vehicles table is empty
INSERT INTO public.vehicles (id, school_id, vehicle_no, seating_capacity, status)
SELECT 
  id, 
  school_id, 
  bus_number, 
  capacity, 
  COALESCE(status, 'Active')
FROM public.bus_routes
ON CONFLICT (school_id, vehicle_no) DO UPDATE 
SET seating_capacity = EXCLUDED.seating_capacity;

-- 2. Drop duplicate indexes safely to save write IOPS and disk space
DROP INDEX IF EXISTS public.idx_leave_status;
DROP INDEX IF EXISTS public.idx_library_borrows_school;
DROP INDEX IF EXISTS public.idx_call_sessions_caller;

-- Re-create clean singular indexes
CREATE INDEX IF NOT EXISTS idx_leave_applications_status ON public.leave_applications(status);
CREATE INDEX IF NOT EXISTS idx_lib_borrows_school ON public.library_borrows(school_id);
CREATE INDEX IF NOT EXISTS idx_call_sess_caller ON public.call_sessions(caller_id);

-- 3. Optimize RLS Helper Function to be STABLE and PARALLEL SAFE
CREATE OR REPLACE FUNCTION public.get_user_school_id(user_id_param UUID)
RETURNS UUID
LANGUAGE sql
STABLE
PARALLEL SAFE
SECURITY DEFINER
AS $$
  SELECT school_id FROM public.profiles WHERE id = user_id_param LIMIT 1;
$$;

-- 4. Prevent Trigger Recursion Loop between driver_assignments and vehicle_trips
CREATE OR REPLACE FUNCTION public.sync_driver_assignment_to_trip()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Prevent infinite trigger execution recursion
  IF pg_trigger_depth() > 1 THEN
    RETURN NEW;
  END IF;

  IF NEW.status IS NOT NULL THEN
    UPDATE public.vehicle_trips
    SET status = CASE 
        WHEN LOWER(NEW.status) = 'active' THEN 'in_progress'
        WHEN LOWER(NEW.status) = 'upcoming' THEN 'scheduled'
        WHEN LOWER(NEW.status) IN ('ended', 'completed') THEN 'completed'
        WHEN LOWER(NEW.status) = 'cancelled' THEN 'cancelled'
        ELSE status
      END,
      updated_at = NOW()
    WHERE driver_id = NEW.driver_id
      AND DATE(start_time) = CURRENT_DATE;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_trip_to_driver_assignment()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Prevent infinite trigger execution recursion
  IF pg_trigger_depth() > 1 THEN
    RETURN NEW;
  END IF;

  IF NEW.driver_id IS NOT NULL AND NEW.status IS NOT NULL THEN
    UPDATE public.driver_assignments
    SET status = CASE 
        WHEN LOWER(NEW.status) = 'in_progress' THEN 'Active'
        WHEN LOWER(NEW.status) = 'scheduled' THEN 'Upcoming'
        WHEN LOWER(NEW.status) = 'completed' THEN 'Completed'
        WHEN LOWER(NEW.status) = 'cancelled' THEN 'Cancelled'
        ELSE status
      END,
      updated_at = NOW()
    WHERE driver_id = NEW.driver_id
      AND DATE(start_date) <= CURRENT_DATE 
      AND (end_date IS NULL OR DATE(end_date) >= CURRENT_DATE);
  END IF;

  RETURN NEW;
END;
$$;
