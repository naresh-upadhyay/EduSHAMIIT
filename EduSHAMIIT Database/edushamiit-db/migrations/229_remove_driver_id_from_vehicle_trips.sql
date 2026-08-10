-- Migration 229: Remove driver_id from vehicle_trips table
-- Driver is now always referenced via transport_routes table (transport_routes.driver_id).

ALTER TABLE IF EXISTS public.vehicle_trips
  DROP COLUMN IF EXISTS driver_id CASCADE;
