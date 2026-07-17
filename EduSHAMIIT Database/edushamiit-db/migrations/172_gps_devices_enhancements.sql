-- Migration: 172_gps_devices_enhancements.sql
-- Description: Add missing columns and seed 56 GPS devices matching the mockup stats.

ALTER TABLE gps_devices
  ADD COLUMN IF NOT EXISTS expiry_date DATE,
  ADD COLUMN IF NOT EXISTS installed_by TEXT DEFAULT 'Transport Manager',
  ADD COLUMN IF NOT EXISTS current_location TEXT DEFAULT 'Sector 62, Noida, UP';

DELETE FROM gps_devices;

-- Seeding loop for 56 devices
DO $$
DECLARE
  i INT := 1;
  v_status TEXT;
  v_expiry DATE;
  v_battery INT;
  v_signal INT;
  v_last_seen TIMESTAMPTZ;
  v_route_ids UUID[] := ARRAY[]::UUID[];
  v_route_count INT;
BEGIN
  -- Collect all route IDs
  SELECT array_agg(id) INTO v_route_ids FROM bus_routes;
  v_route_count := array_length(v_route_ids, 1);

  FOR i IN 1..56 LOOP
    -- Status distribution: 42 Online (Active), 11 Offline, 3 Faulty (Issue)
    IF i <= 42 THEN
      v_status := 'Active';
      v_battery := floor(random()*30 + 70)::int; -- 70-100%
      v_signal := floor(random()*40 + 60)::int;  -- 60-100%
      v_last_seen := NOW() - (random() * interval '10 minutes');
    ELSIF i <= 53 THEN
      v_status := 'Offline';
      v_battery := floor(random()*40)::int;      -- 0-40%
      v_signal := 0;
      v_last_seen := NOW() - (random() * interval '5 days' + interval '2 hours');
    ELSE
      v_status := 'Faulty';
      v_battery := floor(random()*50 + 10)::int;
      v_signal := floor(random()*30)::int;
      v_last_seen := NOW() - (random() * interval '1 hour');
    END IF;

    -- Expiry date distribution: 6 due for renewal (expiring in < 30 days)
    IF i <= 6 THEN
      -- 6 devices expiring in 5 to 28 days
      v_expiry := CURRENT_DATE + (5 + i * 3)::int;
    ELSIF i <= 10 THEN
      -- Already expired
      v_expiry := CURRENT_DATE - (10 + i * 2)::int;
    ELSE
      -- Expiring in 100 to 300 days
      v_expiry := CURRENT_DATE + (100 + i * 3)::int;
    END IF;

    INSERT INTO gps_devices (
      id,
      school_id,
      device_id,
      model,
      sim_no,
      operator,
      status,
      installation_date,
      vehicle_id,
      imei_no,
      battery_level,
      signal_strength_pct,
      last_seen,
      firmware_version,
      expiry_date,
      installed_by,
      current_location
    ) VALUES (
      gen_random_uuid(),
      '11111111-1111-1111-1111-111111111111',
      'GPSD-' || (1000 + i)::text,
      (ARRAY['GT06N', 'GV57', 'GV300'])[floor(random()*3)::int + 1],
      '+91987654' || lpad((3210 + i)::text, 4, '0'),
      (ARRAY['Jio', 'Airtel', 'Vi'])[floor(random()*3)::int + 1],
      v_status,
      CURRENT_DATE - INTERVAL '1 year',
      v_route_ids[(i % v_route_count) + 1],
      '862345065432' || lpad((100 + i)::text, 3, '0'),
      v_battery,
      v_signal,
      v_last_seen,
      'GTO6N_V7.2.1',
      v_expiry,
      'Transport Manager',
      'Sector 62, Noida, UP \n 28.6129° N, 77.3910° E'
    );
  END LOOP;
END $$;
