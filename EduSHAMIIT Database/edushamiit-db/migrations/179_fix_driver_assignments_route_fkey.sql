-- Migration: 179_fix_driver_assignments_route_fkey.sql
-- Description: Correct route_id foreign key constraint in driver_assignments to point to transport_routes(id) instead of bus_routes(id) and re-seed clean mockup data.

-- 1. Drop old constraint
ALTER TABLE driver_assignments 
  DROP CONSTRAINT IF EXISTS driver_assignments_route_id_fkey;

-- 2. Clear out existing assignments to prevent foreign key violations on migration run
DELETE FROM driver_assignments;

-- 3. Add the corrected constraint pointing to transport_routes
ALTER TABLE driver_assignments
  ADD CONSTRAINT driver_assignments_route_id_fkey 
  FOREIGN KEY (route_id) 
  REFERENCES transport_routes(id) 
  ON DELETE SET NULL;

-- 4. Re-seed active assignments from transport_routes
INSERT INTO driver_assignments (school_id, driver_id, vehicle_id, route_id, assignment_type, start_date, shift, status, created_by, notes, start_time, end_time, days, distance, estimated_duration, total_stops)
SELECT 
  school_id, 
  driver_id, 
  vehicle_id, 
  id, 
  'Route', 
  '2024-05-01', 
  'General', 
  'Active', 
  'Transport Manager', 
  'Assigned for route operation',
  '06:30 AM',
  '09:30 AM',
  'Mon,Tue,Wed,Thu,Fri',
  distance_km,
  '45 mins',
  10
FROM transport_routes
WHERE vehicle_id IS NOT NULL AND driver_id IS NOT NULL;
