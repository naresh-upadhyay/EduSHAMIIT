-- ============================================================================
-- Migration 217: Add Average Speed & Route Telemetry Columns
-- ============================================================================

-- 1. Add avg_speed_kmh to transport_routes table
ALTER TABLE IF EXISTS public.transport_routes 
ADD COLUMN IF NOT EXISTS avg_speed_kmh NUMERIC DEFAULT 30;

-- 2. Add distance_from_prev_km and travel_time_mins to transport_route_stops table
ALTER TABLE IF EXISTS public.transport_route_stops 
ADD COLUMN IF NOT EXISTS distance_from_prev_km NUMERIC DEFAULT 0;

ALTER TABLE IF EXISTS public.transport_route_stops 
ADD COLUMN IF NOT EXISTS travel_time_mins NUMERIC DEFAULT 0;
