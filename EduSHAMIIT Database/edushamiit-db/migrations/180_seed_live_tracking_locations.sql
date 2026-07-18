-- Migration: 180_seed_live_tracking_locations.sql
-- Description: Seed high-fidelity locations for all vehicles to enable real-time tracking on the map.

SET ROLE supabase_admin;

-- Delete old locations
DELETE FROM bus_locations;

-- Seed locations for vehicles assigned to active routes
INSERT INTO bus_locations (school_id, route_id, latitude, longitude, speed, heading, eta_minutes, recorded_at)
SELECT 
  r.school_id, 
  r.vehicle_id, -- Note: in bus_locations table, route_id actually references bus_routes(id), which represents vehicles!
  COALESCE(s.latitude, 28.62000000), 
  COALESCE(s.longitude, 77.36000000), 
  35.00, 
  90.00, 
  5, 
  NOW()
FROM transport_routes r
LEFT JOIN LATERAL (
  SELECT latitude, longitude 
  FROM transport_route_stops 
  WHERE route_id = r.id 
  ORDER BY stop_order ASC 
  LIMIT 1
) s ON TRUE
WHERE r.vehicle_id IS NOT NULL;

-- Seed default locations for any unassigned vehicles so they are also trackable
INSERT INTO bus_locations (school_id, route_id, latitude, longitude, speed, heading, eta_minutes, recorded_at)
SELECT 
  school_id, 
  id, 
  28.62000000 + (floor(random()*100)::numeric * 0.0001), 
  77.36000000 + (floor(random()*100)::numeric * 0.0001), 
  0.00, 
  0.00, 
  0, 
  NOW()
FROM bus_routes
WHERE id NOT IN (SELECT DISTINCT vehicle_id FROM transport_routes WHERE vehicle_id IS NOT NULL);

RESET ROLE;
