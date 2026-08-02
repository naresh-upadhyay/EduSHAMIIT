-- Migration: 181_seed_vehicle_trips_history.sql
-- Description: Seed 30-day historical log of pickup and drop trips for Noida Sector 62 vehicles.

DELETE FROM vehicle_trips WHERE school_id = '11111111-1111-1111-1111-111111111111';

DO $$
DECLARE
  v_school_id UUID := '11111111-1111-1111-1111-111111111111';
  r_veh RECORD;
  v_date DATE;
  v_status TEXT;
  v_delay INT;
  v_distance DECIMAL(8,2);
  v_students INT;
  v_trip_type TEXT;
  v_created TIMESTAMPTZ;
  d INT;
BEGIN
  -- For each vehicle
  FOR r_veh IN (SELECT id, route_name FROM bus_routes WHERE school_id = v_school_id) LOOP
    -- For each day in the last 30 days
    FOR d IN 0..29 LOOP
      v_date := CURRENT_DATE - d;
      
      -- 1. Morning Trip (Pickup)
      v_trip_type := 'pickup';
      -- Status distribution: 96% completed, 4% cancelled
      IF random() < 0.04 THEN
        v_status := 'cancelled';
        v_delay := 0;
        v_distance := 0.00;
        v_students := 0;
      ELSE
        v_status := 'completed';
        -- Delay distribution: 12% delayed, 88% on time
        IF random() < 0.12 THEN
          v_delay := floor(random() * 15 + 6)::int; -- 6 to 20 mins delay
        ELSE
          v_delay := floor(random() * 5)::int; -- 0 to 4 mins delay
        END IF;
        v_distance := CAST((12.5 + random() * 12.0) AS DECIMAL(8,2));
        v_students := floor(random() * 25 + 20)::int; -- 20 to 44 students
      END IF;
      
      v_created := v_date::TIMESTAMPTZ + '06:30:00'::INTERVAL;
      
      INSERT INTO vehicle_trips (school_id, route_id, trip_type, status, scheduled_start, actual_start, actual_end, students_count, distance_km, delay_minutes, created_at)
      VALUES (
        v_school_id,
        r_veh.id,
        v_trip_type,
        v_status,
        v_created,
        CASE WHEN v_status = 'completed' THEN v_created + (random() * 2 * INTERVAL '1 minute') ELSE NULL END,
        CASE WHEN v_status = 'completed' THEN v_created + (45 * INTERVAL '1 minute') + (v_delay * INTERVAL '1 minute') ELSE NULL END,
        v_students,
        v_distance,
        v_delay,
        v_created
      );
      
      -- 2. Afternoon Trip (Drop)
      v_trip_type := 'drop';
      IF random() < 0.03 THEN
        v_status := 'cancelled';
        v_delay := 0;
        v_distance := 0.00;
        v_students := 0;
      ELSE
        v_status := 'completed';
        IF random() < 0.10 THEN
          v_delay := floor(random() * 15 + 6)::int;
        ELSE
          v_delay := floor(random() * 5)::int;
        END IF;
        v_distance := CAST((12.5 + random() * 12.0) AS DECIMAL(8,2));
        v_students := floor(random() * 25 + 20)::int;
      END IF;
      
      v_created := v_date::TIMESTAMPTZ + '14:00:00'::INTERVAL;
      
      INSERT INTO vehicle_trips (school_id, route_id, trip_type, status, scheduled_start, actual_start, actual_end, students_count, distance_km, delay_minutes, created_at)
      VALUES (
        v_school_id,
        r_veh.id,
        v_trip_type,
        v_status,
        v_created,
        CASE WHEN v_status = 'completed' THEN v_created + (random() * 2 * INTERVAL '1 minute') ELSE NULL END,
        CASE WHEN v_status = 'completed' THEN v_created + (45 * INTERVAL '1 minute') + (v_delay * INTERVAL '1 minute') ELSE NULL END,
        v_students,
        v_distance,
        v_delay,
        v_created
      );
      
    END LOOP;
  END LOOP;
END $$;
