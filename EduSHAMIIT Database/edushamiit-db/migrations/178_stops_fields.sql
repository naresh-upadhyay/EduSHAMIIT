-- Migration: 178_stops_fields.sql
-- Description: Add fields to transport_route_stops to support Stops screen design, and populate them.

-- 1. Add new columns
ALTER TABLE transport_route_stops 
  ADD COLUMN IF NOT EXISTS stop_code TEXT,
  ADD COLUMN IF NOT EXISTS stop_type TEXT DEFAULT 'Pickup',
  ADD COLUMN IF NOT EXISTS pickup_drop_type TEXT DEFAULT 'Pickup Only',
  ADD COLUMN IF NOT EXISTS landmark TEXT,
  ADD COLUMN IF NOT EXISTS radius_meters INT DEFAULT 200,
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Active',
  ADD COLUMN IF NOT EXISTS created_by TEXT DEFAULT 'Transport Manager';

-- 2. Populate stop_code for existing stops sequentially
DO $$
DECLARE
  r RECORD;
  v_counter INT := 1;
BEGIN
  FOR r IN SELECT id FROM transport_route_stops ORDER BY route_id, stop_order, created_at LOOP
    UPDATE transport_route_stops 
    SET stop_code = 'ST-' || lpad(v_counter::text, 3, '0')
    WHERE id = r.id;
    v_counter := v_counter + 1;
  END LOOP;
END $$;

-- 3. Mark some stops as Drop / Pickup & Drop to match mockup
UPDATE transport_route_stops
SET stop_type = 'Pickup & Drop', pickup_drop_type = 'Pickup & Drop'
WHERE stop_order % 5 = 0;

UPDATE transport_route_stops
SET stop_type = 'Drop', pickup_drop_type = 'Drop Only'
WHERE stop_order % 6 = 0;

-- 4. Set status for some stops
UPDATE transport_route_stops
SET status = 'Inactive'
WHERE stop_order % 15 = 0;

UPDATE transport_route_stops
SET status = 'Deleted'
WHERE stop_order % 40 = 0;
