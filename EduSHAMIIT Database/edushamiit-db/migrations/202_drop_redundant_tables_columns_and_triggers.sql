-- Migration: 202_drop_redundant_tables_columns_and_triggers.sql
-- Description: Drop redundant columns, obsolete triggers, and fix foreign key references to unify database entities cleanly.

-- ──────────────────────────────────────────────
-- 1. FOREIGN KEY ALIGNMENT (Fleet & Vehicles)
-- ──────────────────────────────────────────────

-- Ensure vehicles table has records for all bus_routes before switching FKs
INSERT INTO public.vehicles (id, school_id, vehicle_no, seating_capacity, status)
SELECT id, school_id, bus_number, capacity, COALESCE(status, 'Active')
FROM public.bus_routes
ON CONFLICT (school_id, vehicle_no) DO NOTHING;

-- Drop legacy FK constraints pointing to bus_routes
ALTER TABLE public.vehicle_documents DROP CONSTRAINT IF EXISTS vehicle_documents_vehicle_id_fkey;
ALTER TABLE public.vehicle_insurance_fitness DROP CONSTRAINT IF EXISTS vehicle_insurance_fitness_vehicle_id_fkey;
ALTER TABLE public.gps_devices DROP CONSTRAINT IF EXISTS gps_devices_vehicle_id_fkey;
ALTER TABLE public.transport_routes DROP CONSTRAINT IF EXISTS transport_routes_vehicle_id_fkey;

-- Add updated FK constraints pointing to public.vehicles(id)
ALTER TABLE public.vehicle_documents 
  ADD CONSTRAINT vehicle_documents_vehicle_id_fkey 
  FOREIGN KEY (vehicle_id) REFERENCES public.vehicles(id) ON DELETE CASCADE;

ALTER TABLE public.vehicle_insurance_fitness 
  ADD CONSTRAINT vehicle_insurance_fitness_vehicle_id_fkey 
  FOREIGN KEY (vehicle_id) REFERENCES public.vehicles(id) ON DELETE CASCADE;

ALTER TABLE public.gps_devices 
  ADD CONSTRAINT gps_devices_vehicle_id_fkey 
  FOREIGN KEY (vehicle_id) REFERENCES public.vehicles(id) ON DELETE SET NULL;

ALTER TABLE public.transport_routes 
  ADD CONSTRAINT transport_routes_vehicle_id_fkey 
  FOREIGN KEY (vehicle_id) REFERENCES public.vehicles(id) ON DELETE SET NULL;


-- ──────────────────────────────────────────────
-- 2. DROP OBSOLETE RECURSIVE & REDUNDANT TRIGGERS
-- ──────────────────────────────────────────────

-- Drop old recursive triggers between driver_assignments and vehicle_trips
DROP TRIGGER IF EXISTS trg_sync_driver_assignment_to_trip ON public.driver_assignments;
DROP TRIGGER IF EXISTS trg_sync_trip_to_driver_assignment ON public.vehicle_trips;

-- Re-attach sanitized non-recursive triggers
CREATE TRIGGER trg_sync_driver_assignment_to_trip
AFTER INSERT OR UPDATE ON public.driver_assignments
FOR EACH ROW EXECUTE FUNCTION public.sync_driver_assignment_to_trip();

CREATE TRIGGER trg_sync_trip_to_driver_assignment
AFTER INSERT OR UPDATE ON public.vehicle_trips
FOR EACH ROW EXECUTE FUNCTION public.sync_trip_to_driver_assignment();

-- Drop redundant profile-driver sync triggers if present
DROP TRIGGER IF EXISTS trg_sync_driver_to_profile ON public.drivers;


-- ──────────────────────────────────────────────
-- 3. UNIFIED DRIVERS VIEW FOR BACKWARD COMPATIBILITY
-- ──────────────────────────────────────────────

-- Create a consolidated view combining drivers metadata with profiles identity info
CREATE OR REPLACE VIEW public.vw_drivers AS
SELECT 
  d.id AS driver_id,
  d.profile_id,
  d.school_id,
  d.driver_code,
  COALESCE(p.full_name, d.name) AS full_name,
  COALESCE(p.email, d.email) AS email,
  COALESCE(p.phone, d.phone) AS phone,
  COALESCE(p.avatar_url, d.photo_url) AS photo_url,
  d.license_no,
  d.license_type,
  d.license_expiry_date,
  d.experience_years,
  COALESCE(d.status, p.status, 'Active') AS status,
  d.created_at,
  d.updated_at
FROM public.drivers d
LEFT JOIN public.profiles p ON d.profile_id = p.id;


-- ──────────────────────────────────────────────
-- 4. CONSOLIDATED UNREAD NOTIFICATIONS VIEW
-- ──────────────────────────────────────────────

CREATE OR REPLACE VIEW public.vw_all_user_notifications AS
SELECT 
  id,
  school_id,
  user_id,
  title,
  message,
  COALESCE(category, 'General') AS category,
  COALESCE(is_read, FALSE) AS is_read,
  created_at
FROM public.notifications
UNION ALL
SELECT 
  id,
  school_id,
  NULL AS user_id,
  title,
  content AS message,
  'Announcement' AS category,
  FALSE AS is_read,
  created_at
FROM public.announcements
WHERE LOWER(status) = 'published';


-- ──────────────────────────────────────────────
-- 5. CLEANUP DUPLICATE & OBSOLETE INDEXES
-- ──────────────────────────────────────────────

DROP INDEX IF EXISTS public.idx_vehicle_docs_vehicle;
DROP INDEX IF EXISTS public.idx_vehicle_insurance_vehicle;
DROP INDEX IF EXISTS public.idx_gps_devices_vehicle;

CREATE INDEX IF NOT EXISTS idx_veh_docs_vehicle ON public.vehicle_documents(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_veh_ins_vehicle ON public.vehicle_insurance_fitness(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_gps_dev_vehicle ON public.gps_devices(vehicle_id);
