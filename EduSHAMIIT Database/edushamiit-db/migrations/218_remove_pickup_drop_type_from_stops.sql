-- Migration 218: Remove redundant pickup_drop_type column from transport_route_stops
ALTER TABLE public.transport_route_stops DROP COLUMN IF EXISTS pickup_drop_type;
