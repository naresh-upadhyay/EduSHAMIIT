-- Migration: 177_route_management.sql
-- Description: Create transport_routes and transport_route_stops tables, and seed mockup data.

-- 1. Create transport_routes table
CREATE TABLE IF NOT EXISTS transport_routes (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id     UUID REFERENCES schools(id) ON DELETE CASCADE,
  route_code    TEXT NOT NULL,
  route_name    TEXT NOT NULL,
  area_zone     TEXT,
  distance_km   NUMERIC(6, 2) DEFAULT 0.0,
  start_time    TIME,
  end_time      TIME,
  vehicle_id    UUID REFERENCES bus_routes(id) ON DELETE SET NULL,
  driver_id     UUID REFERENCES drivers(id) ON DELETE SET NULL,
  status        TEXT NOT NULL DEFAULT 'Active', -- 'Active', 'Inactive', 'Draft'
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(school_id, route_code)
);

CREATE INDEX IF NOT EXISTS idx_trans_routes_school ON transport_routes(school_id);
CREATE INDEX IF NOT EXISTS idx_trans_routes_vehicle ON transport_routes(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_trans_routes_driver ON transport_routes(driver_id);

-- 2. Create transport_route_stops table
CREATE TABLE IF NOT EXISTS transport_route_stops (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id          UUID REFERENCES schools(id) ON DELETE CASCADE,
  route_id           UUID REFERENCES transport_routes(id) ON DELETE CASCADE,
  stop_name          TEXT NOT NULL,
  latitude           DECIMAL(10, 8) NOT NULL,
  longitude          DECIMAL(11, 8) NOT NULL,
  stop_order         INT NOT NULL,
  estimated_arrival  TIME,
  created_at         TIMESTAMPTZ DEFAULT NOW(),
  updated_at         TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_trans_stops_school ON transport_route_stops(school_id);
CREATE INDEX IF NOT EXISTS idx_trans_stops_route ON transport_route_stops(route_id);

-- 3. Seeding Mockup Data
DELETE FROM transport_route_stops;
DELETE FROM transport_routes;

DO $$
DECLARE
  v_school_id UUID := '11111111-1111-1111-1111-111111111111';
  v_driver_id_1 UUID;
  v_driver_id_2 UUID;
  v_driver_id_3 UUID;
  v_driver_id_4 UUID;
  v_driver_id_5 UUID;
  v_driver_id_6 UUID;
  v_driver_id_7 UUID;
  v_driver_id_8 UUID;

  v_veh_id_1 UUID;
  v_veh_id_2 UUID;
  v_veh_id_3 UUID;
  v_veh_id_4 UUID;
  v_veh_id_5 UUID;
  v_veh_id_6 UUID;
  v_veh_id_7 UUID;
  v_veh_id_8 UUID;

  v_r1_id UUID;
  v_r2_id UUID;
  v_r3_id UUID;
  v_r4_id UUID;
  v_r5_id UUID;
  v_r6_id UUID;
  v_r7_id UUID;
  v_r8_id UUID;
  v_temp_id UUID;
  
  i INT;
  j INT;
  v_dist NUMERIC;
BEGIN
  -- Get Driver IDs dynamically
  SELECT id INTO v_driver_id_1 FROM drivers WHERE driver_code = 'DRV001' LIMIT 1;
  SELECT id INTO v_driver_id_2 FROM drivers WHERE driver_code = 'DRV002' LIMIT 1;
  SELECT id INTO v_driver_id_3 FROM drivers WHERE driver_code = 'DRV003' LIMIT 1;
  SELECT id INTO v_driver_id_4 FROM drivers WHERE driver_code = 'DRV004' LIMIT 1;
  SELECT id INTO v_driver_id_5 FROM drivers WHERE driver_code = 'DRV005' LIMIT 1;
  SELECT id INTO v_driver_id_6 FROM drivers WHERE driver_code = 'DRV006' LIMIT 1;
  SELECT id INTO v_driver_id_7 FROM drivers WHERE driver_code = 'DRV007' LIMIT 1;
  SELECT id INTO v_driver_id_8 FROM drivers WHERE driver_code = 'DRV008' LIMIT 1;

  -- Get Vehicle IDs dynamically
  SELECT id INTO v_veh_id_1 FROM bus_routes WHERE bus_number = 'UP16 ET 1234' LIMIT 1;
  SELECT id INTO v_veh_id_2 FROM bus_routes WHERE bus_number = 'UP16 ET 5678' LIMIT 1;
  SELECT id INTO v_veh_id_3 FROM bus_routes WHERE bus_number = 'UP16 ET 9101' LIMIT 1;
  SELECT id INTO v_veh_id_4 FROM bus_routes WHERE bus_number = 'UP16 ET 1122' LIMIT 1;
  SELECT id INTO v_veh_id_5 FROM bus_routes WHERE bus_number = 'UP16 ET 3344' LIMIT 1;
  SELECT id INTO v_veh_id_6 FROM bus_routes WHERE bus_number = 'UP16 ET 7788' LIMIT 1;
  SELECT id INTO v_veh_id_7 FROM bus_routes WHERE bus_number = 'UP16 ET 8899' LIMIT 1;
  SELECT id INTO v_veh_id_8 FROM bus_routes WHERE bus_number = 'UP16 ET 2468' LIMIT 1;

  -- Insert first 8 routes exactly as shown in mockup
  INSERT INTO transport_routes (school_id, route_code, route_name, area_zone, distance_km, start_time, end_time, vehicle_id, driver_id, status)
  VALUES (v_school_id, 'RT-001', 'Route 101 (Morning)', 'Noida Sector 62', 18.6, '06:30:00', '07:22:00', v_veh_id_1, v_driver_id_1, 'Active')
  RETURNING id INTO v_r1_id;

  INSERT INTO transport_routes (school_id, route_code, route_name, area_zone, distance_km, start_time, end_time, vehicle_id, driver_id, status)
  VALUES (v_school_id, 'RT-002', 'Route 102 (Morning)', 'Noida Sector 122', 21.3, '06:30:00', '07:22:00', v_veh_id_2, v_driver_id_2, 'Active')
  RETURNING id INTO v_r2_id;

  INSERT INTO transport_routes (school_id, route_code, route_name, area_zone, distance_km, start_time, end_time, vehicle_id, driver_id, status)
  VALUES (v_school_id, 'RT-003', 'Route 103 (Morning)', 'Greater Noida West', 24.7, '06:30:00', '07:22:00', v_veh_id_3, v_driver_id_3, 'Active')
  RETURNING id INTO v_r3_id;

  INSERT INTO transport_routes (school_id, route_code, route_name, area_zone, distance_km, start_time, end_time, vehicle_id, driver_id, status)
  VALUES (v_school_id, 'RT-004', 'Route 104 (Morning)', 'Yamuna Expressway', 28.1, '06:30:00', '07:22:00', v_veh_id_4, v_driver_id_4, 'Active')
  RETURNING id INTO v_r4_id;

  INSERT INTO transport_routes (school_id, route_code, route_name, area_zone, distance_km, start_time, end_time, vehicle_id, driver_id, status)
  VALUES (v_school_id, 'RT-005', 'Route 105 (Afternoon)', 'Noida Sector 62', 18.6, '14:00:00', '14:52:00', v_veh_id_5, v_driver_id_5, 'Active')
  RETURNING id INTO v_r5_id;

  INSERT INTO transport_routes (school_id, route_code, route_name, area_zone, distance_km, start_time, end_time, vehicle_id, driver_id, status)
  VALUES (v_school_id, 'RT-006', 'Route 106 (Afternoon)', 'Noida Sector 122', 21.3, '14:00:00', '14:52:00', v_veh_id_6, v_driver_id_6, 'Inactive')
  RETURNING id INTO v_r6_id;

  INSERT INTO transport_routes (school_id, route_code, route_name, area_zone, distance_km, start_time, end_time, vehicle_id, driver_id, status)
  VALUES (v_school_id, 'RT-007', 'Route 107 (Morning)', 'Dadri', 19.2, '06:30:00', '07:22:00', v_veh_id_7, v_driver_id_7, 'Inactive')
  RETURNING id INTO v_r7_id;

  INSERT INTO transport_routes (school_id, route_code, route_name, area_zone, distance_km, start_time, end_time, vehicle_id, driver_id, status)
  VALUES (v_school_id, 'RT-008', 'Route 108 (Morning)', 'Knowledge Park 3', 20.5, '06:30:00', '07:22:00', v_veh_id_8, v_driver_id_8, 'Draft')
  RETURNING id INTO v_r8_id;

  -- 4. Seed stops for Route 101 & 105 (14 stops, distance: 18.6 km)
  -- Stop locations around Noida Sector 62
  FOR j IN 1..14 LOOP
    INSERT INTO transport_route_stops (school_id, route_id, stop_name, latitude, longitude, stop_order, estimated_arrival)
    VALUES (
      v_school_id, 
      v_r1_id, 
      CASE 
        WHEN j = 1 THEN 'Sector 62, Near Community Center'
        WHEN j = 2 THEN 'Fortune Residency, Sector 62'
        WHEN j = 3 THEN 'Sector 63 Bus Stop'
        WHEN j = 4 THEN 'Sector 71 Crossing'
        WHEN j = 5 THEN 'Sector 72 Metro Station'
        ELSE 'Stop ' || j || ' (Sector 62 Route)'
      END,
      28.62000000 + (j * 0.0003), 
      77.36000000 + (j * 0.00025), 
      j, 
      CAST(('06:30:00'::TIME + (j - 1) * INTERVAL '4 minutes') AS TIME)
    );
    
    INSERT INTO transport_route_stops (school_id, route_id, stop_name, latitude, longitude, stop_order, estimated_arrival)
    VALUES (
      v_school_id, 
      v_r5_id, 
      CASE 
        WHEN j = 1 THEN 'Sector 62, Near Community Center'
        WHEN j = 2 THEN 'Fortune Residency, Sector 62'
        WHEN j = 3 THEN 'Sector 63 Bus Stop'
        WHEN j = 4 THEN 'Sector 71 Crossing'
        WHEN j = 5 THEN 'Sector 72 Metro Station'
        ELSE 'Stop ' || j || ' (Sector 62 Route)'
      END,
      28.62000000 + (j * 0.0003), 
      77.36000000 + (j * 0.00025), 
      j, 
      CAST(('14:00:00'::TIME + (j - 1) * INTERVAL '4 minutes') AS TIME)
    );
  END LOOP;

  -- Seed stops for Route 102 & 106 (16 stops, distance: 21.3 km)
  FOR j IN 1..16 LOOP
    INSERT INTO transport_route_stops (school_id, route_id, stop_name, latitude, longitude, stop_order, estimated_arrival)
    VALUES (v_school_id, v_r2_id, 'Stop ' || j || ' (Sector 122 Route)', 28.61000000 + (j * 0.00025), 77.38000000 + (j * 0.0002), j, CAST(('06:30:00'::TIME + (j - 1) * INTERVAL '3 minutes') AS TIME));
    INSERT INTO transport_route_stops (school_id, route_id, stop_name, latitude, longitude, stop_order, estimated_arrival)
    VALUES (v_school_id, v_r6_id, 'Stop ' || j || ' (Sector 122 Route)', 28.61000000 + (j * 0.00025), 77.38000000 + (j * 0.0002), j, CAST(('14:00:00'::TIME + (j - 1) * INTERVAL '3 minutes') AS TIME));
  END LOOP;

  -- Seed stops for Route 103 (18 stops, distance: 24.7 km)
  FOR j IN 1..18 LOOP
    INSERT INTO transport_route_stops (school_id, route_id, stop_name, latitude, longitude, stop_order, estimated_arrival)
    VALUES (v_school_id, v_r3_id, 'Stop ' || j || ' (Greater Noida West Route)', 28.58000000 + (j * 0.0004), 77.42000000 + (j * 0.0003), j, CAST(('06:30:00'::TIME + (j - 1) * INTERVAL '3 minutes') AS TIME));
  END LOOP;

  -- Seed stops for Route 104 (20 stops, distance: 28.1 km)
  FOR j IN 1..20 LOOP
    INSERT INTO transport_route_stops (school_id, route_id, stop_name, latitude, longitude, stop_order, estimated_arrival)
    VALUES (v_school_id, v_r4_id, 'Stop ' || j || ' (Yamuna Exp Route)', 28.50000000 + (j * 0.0005), 77.48000000 + (j * 0.0002), j, CAST(('06:30:00'::TIME + (j - 1) * INTERVAL '2.5 minutes') AS TIME));
  END LOOP;

  -- Seed stops for Route 107 (13 stops, distance: 19.2 km)
  FOR j IN 1..13 LOOP
    INSERT INTO transport_route_stops (school_id, route_id, stop_name, latitude, longitude, stop_order, estimated_arrival)
    VALUES (v_school_id, v_r7_id, 'Stop ' || j || ' (Dadri Route)', 28.55000000 + (j * 0.00035), 77.52000000 + (j * 0.0003), j, CAST(('06:30:00'::TIME + (j - 1) * INTERVAL '4 minutes') AS TIME));
  END LOOP;

  -- Seed stops for Route 108 (15 stops, distance: 20.5 km)
  FOR j IN 1..15 LOOP
    INSERT INTO transport_route_stops (school_id, route_id, stop_name, latitude, longitude, stop_order, estimated_arrival)
    VALUES (v_school_id, v_r8_id, 'Stop ' || j || ' (KP3 Route)', 28.46000000 + (j * 0.00038), 77.50000000 + (j * 0.00025), j, CAST(('06:30:00'::TIME + (j - 1) * INTERVAL '3.5 minutes') AS TIME));
  END LOOP;

  -- Currently stop count sum is: 14 + 14 + 16 + 16 + 18 + 20 + 13 + 15 = 126 stops.
  -- Current distance sum is: 18.6 + 18.6 + 21.3 + 21.3 + 24.7 + 28.1 + 19.2 + 20.5 = 172.3 km.
  
  -- Insert remaining 20 routes to reach 28 total routes
  -- Need exactly 22 Active, 4 Inactive, 2 Draft.
  -- We already have:
  -- Active: RT-001 to RT-005 (5 routes) -> need 17 more
  -- Inactive: RT-006, RT-007 (2 routes) -> need 2 more
  -- Draft: RT-008 (1 route) -> need 1 more
  -- Total stops needed: 186 - 126 = 60 stops (average 3 stops per route)
  -- Total distance needed: 1254.8 - 172.3 = 1082.5 km (average 54.125 km per route)
  
  FOR i IN 9..28 LOOP
    -- Determine status
    IF i <= 25 THEN -- Active (RT-009 to RT-025 = 17 routes)
      v_dist := 54.125 + (i % 5) - 2.5; -- vary distances
      INSERT INTO transport_routes (school_id, route_code, route_name, area_zone, distance_km, start_time, end_time, status)
      VALUES (v_school_id, 'RT-' || lpad(i::text, 3, '0'), 'Route ' || (100 + i) || ' (Morning)', 'Noida Sector ' || (10 + i), v_dist, '06:30:00', '07:22:00', 'Active')
      RETURNING id INTO v_temp_id;
    ELSIF i <= 27 THEN -- Inactive (RT-026, RT-027 = 2 routes)
      v_dist := 54.125 + (i % 3) - 1.0;
      INSERT INTO transport_routes (school_id, route_code, route_name, area_zone, distance_km, start_time, end_time, status)
      VALUES (v_school_id, 'RT-' || lpad(i::text, 3, '0'), 'Route ' || (100 + i) || ' (Evening)', 'Noida Sector ' || (10 + i), v_dist, '15:30:00', '16:22:00', 'Inactive')
      RETURNING id INTO v_temp_id;
    ELSE -- Draft (RT-028 = 1 route)
      v_dist := 54.125;
      INSERT INTO transport_routes (school_id, route_code, route_name, area_zone, distance_km, start_time, end_time, status)
      VALUES (v_school_id, 'RT-' || lpad(i::text, 3, '0'), 'Route ' || (100 + i) || ' (Morning)', 'Noida Sector ' || (10 + i), v_dist, '07:30:00', '08:22:00', 'Draft')
      RETURNING id INTO v_temp_id;
    END IF;
    
    -- Insert 3 stops for each of these 20 routes
    FOR j IN 1..3 LOOP
      INSERT INTO transport_route_stops (school_id, route_id, stop_name, latitude, longitude, stop_order, estimated_arrival)
      VALUES (
        v_school_id, 
        v_temp_id, 
        'Stop ' || j || ' (RT-' || lpad(i::text, 3, '0') || ')', 
        28.60000000 + (i * 0.0005) + (j * 0.0004), 
        77.30000000 + (i * 0.0005) + (j * 0.0003), 
        j, 
        CAST(('06:30:00'::TIME + (j - 1) * INTERVAL '15 minutes') AS TIME)
      );
    END LOOP;
  END LOOP;

  -- Ensure we hit exactly 1254.8 km.
  -- Sum up current distances and adjust the last route (RT-028)
  SELECT SUM(distance_km) INTO v_dist FROM transport_routes;
  UPDATE transport_routes 
  SET distance_km = distance_km + (1254.8 - v_dist)
  WHERE route_code = 'RT-028';
  
END $$;
