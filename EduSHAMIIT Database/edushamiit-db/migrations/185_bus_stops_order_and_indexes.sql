-- Migration: 185_bus_stops_order_and_indexes.sql
-- Description: Ensure stop_order, estimated_arrival, and indexes exist on bus_stops and transport_route_stops tables.
-- EduSHAMIIT — Shami Innovation and Technologies LLP

ALTER TABLE bus_stops ADD COLUMN IF NOT EXISTS stop_order INT DEFAULT 1;
ALTER TABLE bus_stops ADD COLUMN IF NOT EXISTS estimated_arrival TEXT;
ALTER TABLE bus_stops ADD COLUMN IF NOT EXISTS is_student_stop BOOLEAN DEFAULT TRUE;

CREATE INDEX IF NOT EXISTS idx_bus_stops_route_order ON bus_stops(route_id, stop_order);

ALTER TABLE transport_route_stops ADD COLUMN IF NOT EXISTS stop_order INT DEFAULT 1;
ALTER TABLE transport_route_stops ADD COLUMN IF NOT EXISTS estimated_arrival TEXT;

CREATE INDEX IF NOT EXISTS idx_transport_route_stops_route_order ON transport_route_stops(route_id, stop_order);
