-- Run as postgres, temporarily set role to supabase_admin to alter tables
SET ROLE supabase_admin;

ALTER TABLE bus_routes
  ADD COLUMN IF NOT EXISTS vehicle_type        TEXT DEFAULT 'Bus',
  ADD COLUMN IF NOT EXISTS registration_no     TEXT,
  ADD COLUMN IF NOT EXISTS model               TEXT,
  ADD COLUMN IF NOT EXISTS year_of_mfg         INT,
  ADD COLUMN IF NOT EXISTS fuel_type           TEXT DEFAULT 'Diesel',
  ADD COLUMN IF NOT EXISTS last_service_date   DATE,
  ADD COLUMN IF NOT EXISTS insurance_expiry    DATE,
  ADD COLUMN IF NOT EXISTS fitness_expiry      DATE,
  ADD COLUMN IF NOT EXISTS gps_device_id       TEXT,
  ADD COLUMN IF NOT EXISTS live_status         TEXT DEFAULT 'offline',
  ADD COLUMN IF NOT EXISTS delay_minutes       INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS students_on_board   INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS driver_license_no   TEXT,
  ADD COLUMN IF NOT EXISTS driver_photo_url    TEXT,
  ADD COLUMN IF NOT EXISTS assistant_name      TEXT,
  ADD COLUMN IF NOT EXISTS assistant_phone     TEXT,
  ADD COLUMN IF NOT EXISTS notes               TEXT,
  ADD COLUMN IF NOT EXISTS updated_at          TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE bus_locations
  ADD COLUMN IF NOT EXISTS accuracy_m      DECIMAL(8,2),
  ADD COLUMN IF NOT EXISTS engine_on       BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS odometer_km     DECIMAL(10,2),
  ADD COLUMN IF NOT EXISTS altitude_m      DECIMAL(8,2),
  ADD COLUMN IF NOT EXISTS signal_strength TEXT DEFAULT 'good';

RESET ROLE;

-- Now create tables and function as postgres (they don't have ownership restrictions)
CREATE TABLE IF NOT EXISTS vehicle_trips (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id       UUID REFERENCES schools(id),
  route_id        UUID REFERENCES bus_routes(id) ON DELETE CASCADE,
  trip_type       TEXT NOT NULL DEFAULT 'morning',
  status          TEXT NOT NULL DEFAULT 'scheduled',
  scheduled_start TIMESTAMPTZ,
  actual_start    TIMESTAMPTZ,
  actual_end      TIMESTAMPTZ,
  students_count  INT DEFAULT 0,
  distance_km     DECIMAL(8,2) DEFAULT 0,
  delay_minutes   INT DEFAULT 0,
  incident_count  INT DEFAULT 0,
  notes           TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS vehicle_live_alerts (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id    UUID REFERENCES schools(id),
  route_id     UUID REFERENCES bus_routes(id) ON DELETE SET NULL,
  trip_id      UUID REFERENCES vehicle_trips(id) ON DELETE SET NULL,
  alert_type   TEXT NOT NULL,
  severity     TEXT NOT NULL DEFAULT 'info',
  title        TEXT NOT NULL,
  message      TEXT,
  is_resolved  BOOLEAN DEFAULT FALSE,
  resolved_at  TIMESTAMPTZ,
  resolved_by  TEXT,
  latitude     DECIMAL(10,8),
  longitude    DECIMAL(11,8),
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vehicle_trips_school_id   ON vehicle_trips(school_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_trips_route_id    ON vehicle_trips(route_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_trips_status      ON vehicle_trips(status);
CREATE INDEX IF NOT EXISTS idx_vehicle_trips_created_at  ON vehicle_trips(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_vehicle_alerts_school_id  ON vehicle_live_alerts(school_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_alerts_route_id   ON vehicle_live_alerts(route_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_alerts_severity   ON vehicle_live_alerts(severity);
CREATE INDEX IF NOT EXISTS idx_vehicle_alerts_created_at ON vehicle_live_alerts(created_at DESC);

CREATE OR REPLACE FUNCTION public.get_vehicle_dashboard_summary(p_school_id UUID DEFAULT NULL)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total           INT;
  v_on_route        INT;
  v_at_school       INT;
  v_returning       INT;
  v_delayed         INT;
  v_offline         INT;
  v_idle            INT;
  v_students        INT;
  v_active_trips    INT;
  v_completed_trips INT;
  v_alerts_crit     INT;
  v_alerts_warn     INT;
BEGIN
  IF p_school_id IS NOT NULL THEN
    SELECT COUNT(*) INTO v_total        FROM bus_routes WHERE school_id = p_school_id;
    SELECT COUNT(*) INTO v_on_route     FROM bus_routes WHERE school_id = p_school_id AND live_status = 'on_route';
    SELECT COUNT(*) INTO v_at_school    FROM bus_routes WHERE school_id = p_school_id AND live_status = 'at_school';
    SELECT COUNT(*) INTO v_returning    FROM bus_routes WHERE school_id = p_school_id AND live_status = 'returning';
    SELECT COUNT(*) INTO v_delayed      FROM bus_routes WHERE school_id = p_school_id AND live_status = 'delayed';
    SELECT COUNT(*) INTO v_offline      FROM bus_routes WHERE school_id = p_school_id AND live_status = 'offline';
    SELECT COUNT(*) INTO v_idle         FROM bus_routes WHERE school_id = p_school_id AND live_status = 'idle';
    SELECT COALESCE(SUM(students_on_board),0) INTO v_students FROM bus_routes WHERE school_id = p_school_id;
    SELECT COUNT(*) INTO v_active_trips    FROM vehicle_trips WHERE school_id = p_school_id AND status = 'in_progress';
    SELECT COUNT(*) INTO v_completed_trips FROM vehicle_trips WHERE school_id = p_school_id AND status = 'completed' AND created_at >= CURRENT_DATE;
    SELECT COUNT(*) INTO v_alerts_crit FROM vehicle_live_alerts WHERE school_id = p_school_id AND is_resolved = FALSE AND severity = 'critical';
    SELECT COUNT(*) INTO v_alerts_warn FROM vehicle_live_alerts WHERE school_id = p_school_id AND is_resolved = FALSE AND severity = 'warning';
  ELSE
    SELECT COUNT(*) INTO v_total        FROM bus_routes;
    SELECT COUNT(*) INTO v_on_route     FROM bus_routes WHERE live_status = 'on_route';
    SELECT COUNT(*) INTO v_at_school    FROM bus_routes WHERE live_status = 'at_school';
    SELECT COUNT(*) INTO v_returning    FROM bus_routes WHERE live_status = 'returning';
    SELECT COUNT(*) INTO v_delayed      FROM bus_routes WHERE live_status = 'delayed';
    SELECT COUNT(*) INTO v_offline      FROM bus_routes WHERE live_status = 'offline';
    SELECT COUNT(*) INTO v_idle         FROM bus_routes WHERE live_status = 'idle';
    SELECT COALESCE(SUM(students_on_board),0) INTO v_students FROM bus_routes;
    SELECT COUNT(*) INTO v_active_trips    FROM vehicle_trips WHERE status = 'in_progress';
    SELECT COUNT(*) INTO v_completed_trips FROM vehicle_trips WHERE status = 'completed' AND created_at >= CURRENT_DATE;
    SELECT COUNT(*) INTO v_alerts_crit FROM vehicle_live_alerts WHERE is_resolved = FALSE AND severity = 'critical';
    SELECT COUNT(*) INTO v_alerts_warn FROM vehicle_live_alerts WHERE is_resolved = FALSE AND severity = 'warning';
  END IF;

  RETURN json_build_object(
    'total_vehicles',      v_total,
    'on_route',            v_on_route,
    'at_school',           v_at_school,
    'returning',           v_returning,
    'delayed',             v_delayed,
    'offline',             v_offline,
    'idle',                v_idle,
    'students_on_board',   v_students,
    'active_trips',        v_active_trips,
    'completed_trips_today', v_completed_trips,
    'critical_alerts',     v_alerts_crit,
    'warning_alerts',      v_alerts_warn
  );
END;
$$;

-- Sample data: update bus_routes (now as supabase_admin)
SET ROLE supabase_admin;
UPDATE bus_routes SET
  live_status        = (ARRAY['on_route','at_school','returning','delayed','offline','idle'])[floor(random()*6)::int + 1],
  vehicle_type       = 'Bus',
  fuel_type          = 'Diesel',
  students_on_board  = floor(random()*35)::int,
  delay_minutes      = floor(random()*15)::int,
  registration_no    = 'UP-' || lpad(floor(random()*9999)::text, 4, '0') || '-BUS',
  model              = (ARRAY['Tata Starbus','Ashok Leyland Eagle','Force Traveller','Mahindra Supro'])[floor(random()*4)::int + 1],
  updated_at         = NOW() - (random()*interval '10 minutes');

RESET ROLE;

-- Sample trips (as postgres since vehicle_trips is owned by postgres)
INSERT INTO vehicle_trips (id, school_id, route_id, trip_type, status, scheduled_start, actual_start, students_count, distance_km, delay_minutes)
SELECT
  gen_random_uuid(),
  r.school_id,
  r.id,
  'morning',
  CASE WHEN random() < 0.4 THEN 'completed' WHEN random() < 0.7 THEN 'in_progress' ELSE 'scheduled' END,
  NOW()::date + interval '7 hours',
  NOW()::date + interval '7 hours 5 minutes',
  COALESCE(r.students_on_board, floor(random()*30)::int),
  round((random()*20 + 5)::numeric, 2),
  floor(random()*10)::int
FROM bus_routes r
WHERE r.school_id IS NOT NULL
ON CONFLICT DO NOTHING;

-- Sample alerts
INSERT INTO vehicle_live_alerts (id, school_id, route_id, alert_type, severity, title, message, is_resolved, created_at)
SELECT
  gen_random_uuid(),
  r.school_id,
  r.id,
  (ARRAY['delay','speeding','idle','breakdown','geofence'])[floor(random()*5)::int + 1],
  (ARRAY['critical','warning','info'])[floor(random()*3)::int + 1],
  (ARRAY[
    'Vehicle delayed by 12 min',
    'Speed exceeded 60 km/h',
    'Engine idle for 15+ min',
    'GPS signal lost',
    'Geofence boundary crossed'
  ])[floor(random()*5)::int + 1],
  'Auto-detected by tracking system.',
  (random() < 0.3),
  NOW() - (random()*interval '2 hours')
FROM bus_routes r
WHERE r.school_id IS NOT NULL
LIMIT 20
ON CONFLICT DO NOTHING;
