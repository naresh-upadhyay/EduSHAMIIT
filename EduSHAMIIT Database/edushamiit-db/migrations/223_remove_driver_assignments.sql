-- Migration: 223_remove_driver_assignments.sql
-- Description: Complete removal of driver_assignments table, triggers, functions, and redundant columns

-- 1. Drop triggers
DROP TRIGGER IF EXISTS trg_sync_trip_to_driver_assignment ON public.vehicle_trips;
DROP TRIGGER IF EXISTS trg_sync_driver_assignment_to_trip ON public.driver_assignments;

-- 2. Drop sync functions
DROP FUNCTION IF EXISTS sync_trip_to_driver_assignment();
DROP FUNCTION IF EXISTS sync_driver_assignment_to_trip();

-- 3. Drop driver_assignment_id column from vehicle_trips if exists
ALTER TABLE IF EXISTS public.vehicle_trips 
  DROP COLUMN IF EXISTS driver_assignment_id;

-- 4. Drop driver_assignments table and all its constraints/indexes
DROP TABLE IF EXISTS public.driver_assignments CASCADE;
