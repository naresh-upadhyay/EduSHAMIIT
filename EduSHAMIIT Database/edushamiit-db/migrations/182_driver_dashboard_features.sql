SET ROLE supabase_admin;

-- 1. Alter student_transport to support transport_routes and transport_route_stops
ALTER TABLE student_transport
  ADD COLUMN IF NOT EXISTS transport_route_id UUID REFERENCES transport_routes(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS transport_stop_id UUID REFERENCES transport_route_stops(id) ON DELETE SET NULL;

RESET ROLE;

-- 2. Create student_trip_logs table
CREATE TABLE IF NOT EXISTS student_trip_logs (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id   UUID REFERENCES schools(id) ON DELETE CASCADE,
  trip_id     UUID REFERENCES vehicle_trips(id) ON DELETE CASCADE,
  student_id  UUID REFERENCES profiles(id) ON DELETE CASCADE,
  stop_id     UUID REFERENCES transport_route_stops(id) ON DELETE CASCADE,
  status      TEXT NOT NULL DEFAULT 'yet_to_pick' CHECK (status IN ('yet_to_pick', 'picked', 'dropped', 'absent')),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_student_trip_logs_trip ON student_trip_logs(trip_id);
CREATE INDEX IF NOT EXISTS idx_student_trip_logs_student ON student_trip_logs(student_id);

-- 3. Create trip_stop_logs table
CREATE TABLE IF NOT EXISTS trip_stop_logs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id       UUID REFERENCES schools(id) ON DELETE CASCADE,
  trip_id         UUID REFERENCES vehicle_trips(id) ON DELETE CASCADE,
  stop_id         UUID REFERENCES transport_route_stops(id) ON DELETE CASCADE,
  status          TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('completed', 'skipped', 'pending')),
  actual_arrival  TIMESTAMPTZ,
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_trip_stop_logs_trip ON trip_stop_logs(trip_id);

-- 4. Seed students for Noida Route 101
DO $$
DECLARE
  v_school_id UUID := '11111111-1111-1111-1111-111111111111';
  v_route_id UUID;
  r_student RECORD;
  v_stops UUID[];
  v_stop_count INT;
  i INT := 1;
  v_selected_stop UUID;
BEGIN
  -- Get the route ID of Noida Route 101 (Morning)
  SELECT id INTO v_route_id FROM transport_routes WHERE route_code = 'RT-001' LIMIT 1;
  
  IF v_route_id IS NOT NULL THEN
    -- Get stops of Noida Route 101 sorted by order
    SELECT array_agg(id ORDER BY stop_order) INTO v_stops FROM transport_route_stops WHERE route_id = v_route_id;
    v_stop_count := cardinality(v_stops);
    
    IF v_stop_count > 0 THEN
      -- Clean old student transport assignments for Route 101 first
      DELETE FROM student_transport WHERE transport_route_id = v_route_id;

      -- Assign up to 35 students to Route 101 stops
      FOR r_student IN (
        SELECT id FROM profiles 
        WHERE role = 'student' AND school_id = v_school_id
        LIMIT 35
      ) LOOP
        -- Select a stop cyclically (excluding the first stop which is Start Point and last stop which is End Point, if possible, to be realistic)
        -- Route has 14 stops. Let's distribute across stops 2 to 13.
        v_selected_stop := v_stops[((i % (v_stop_count - 2)) + 2)];
        
        INSERT INTO student_transport (school_id, student_id, transport_route_id, transport_stop_id, seat_no)
        VALUES (
          v_school_id,
          r_student.id,
          v_route_id,
          v_selected_stop,
          'Seat ' || i
        );
        
        i := i + 1;
      END LOOP;
    END IF;
  END IF;
END $$;
