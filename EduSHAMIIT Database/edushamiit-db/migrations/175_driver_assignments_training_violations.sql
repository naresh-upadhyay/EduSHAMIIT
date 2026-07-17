-- Create driver_assignments table
CREATE TABLE IF NOT EXISTS driver_assignments (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id           UUID REFERENCES schools(id) ON DELETE CASCADE,
  driver_id           UUID REFERENCES drivers(id) ON DELETE CASCADE,
  vehicle_id          UUID REFERENCES bus_routes(id) ON DELETE SET NULL,
  route_id            UUID REFERENCES bus_routes(id) ON DELETE SET NULL,
  assignment_type     TEXT NOT NULL, -- 'Route', 'Trip'
  start_date          DATE NOT NULL,
  end_date            DATE,
  shift               TEXT NOT NULL, -- 'Morning Shift', 'Evening Shift', 'General'
  status              TEXT NOT NULL DEFAULT 'Active', -- 'Active', 'Completed', 'Ended', 'Upcoming', 'Cancelled'
  created_by          TEXT,
  notes               TEXT,
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_driver_assign_school ON driver_assignments(school_id);
CREATE INDEX IF NOT EXISTS idx_driver_assign_driver ON driver_assignments(driver_id);

-- Create driver_training table
CREATE TABLE IF NOT EXISTS driver_training (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id           UUID REFERENCES schools(id) ON DELETE CASCADE,
  driver_id           UUID REFERENCES drivers(id) ON DELETE CASCADE,
  training_program    TEXT NOT NULL,
  training_type       TEXT NOT NULL, -- 'Safety', 'Medical', 'Technical', 'Operational', 'Awareness'
  provider            TEXT NOT NULL,
  start_date          DATE NOT NULL,
  end_date            DATE,
  status              TEXT NOT NULL DEFAULT 'In Progress', -- 'Completed', 'In Progress', 'Upcoming', 'Overdue'
  certificate_url     TEXT,
  next_due_date       DATE,
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_driver_train_school ON driver_training(school_id);
CREATE INDEX IF NOT EXISTS idx_driver_train_driver ON driver_training(driver_id);

-- Create driver_violations table
CREATE TABLE IF NOT EXISTS driver_violations (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id           UUID REFERENCES schools(id) ON DELETE CASCADE,
  driver_id           UUID REFERENCES drivers(id) ON DELETE CASCADE,
  violation_type      TEXT NOT NULL, -- 'Overspeeding', 'Signal Jump', 'Seat Belt Not Worn', 'Mobile Usage', 'Harsh Braking', 'Wrong Route', 'Overtime Driving', 'Parking Violation'
  description         TEXT,
  date_time           TIMESTAMPTZ NOT NULL,
  location            TEXT,
  vehicle_id          UUID REFERENCES bus_routes(id) ON DELETE SET NULL,
  severity            TEXT NOT NULL, -- 'High', 'Medium', 'Low'
  status              TEXT NOT NULL DEFAULT 'Pending', -- 'Pending', 'Resolved', 'Cancelled', 'Waived'
  fine_amount         NUMERIC(10, 2) DEFAULT 0.0,
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_driver_viol_school ON driver_violations(school_id);
CREATE INDEX IF NOT EXISTS idx_driver_viol_driver ON driver_violations(driver_id);

-- Seeding
DELETE FROM driver_assignments;
DELETE FROM driver_training;
DELETE FROM driver_violations;

DO $$
DECLARE
  v_school_id UUID := '11111111-1111-1111-1111-111111111111';
  v_driver RECORD;
  v_route RECORD;
  v_driver_ids UUID[] := '{}';
  v_route_ids UUID[] := '{}';
  v_driver_count INT := 0;
  v_route_count INT := 0;
  i INT := 0;
  
  -- Seed counters
  v_assign_count INT := 0;
  v_train_count INT := 0;
  v_viol_count INT := 0;
  
  -- Temporary variables
  v_did UUID;
  v_rid UUID;
  v_status TEXT;
  v_type TEXT;
  v_severity TEXT;
  v_fine NUMERIC;
BEGIN
  -- Gather all drivers and routes
  FOR v_driver IN SELECT id FROM drivers LOOP
    v_driver_ids := array_append(v_driver_ids, v_driver.id);
  END LOOP;
  v_driver_count := cardinality(v_driver_ids);
  
  FOR v_route IN SELECT id FROM bus_routes LOOP
    v_route_ids := array_append(v_route_ids, v_route.id);
  END LOOP;
  v_route_count := cardinality(v_route_ids);

  IF v_driver_count = 0 OR v_route_count = 0 THEN
    RETURN;
  END IF;

  -- ========================================================
  -- 1. SEED ASSIGNMENTS (Target: 86 total assignments)
  -- ========================================================
  -- Seed the first few with specific values matching mockup screenshots:
  -- DRV001: Ramesh Kumar
  -- DRV002: Sandeep Singh
  -- DRV003: Ajay Pal
  -- DRV004: Mohd. Imran
  -- DRV005: Vijay Yadav
  -- DRV006: Dinesh Chaurasia
  -- DRV007: Prakash Tiwari
  -- DRV008: Rohit Kumar
  -- DRV009: Manoj Verma
  -- DRV010: Deepak Sharma

  -- We loop through drivers and create assignments
  FOR i IN 1..86 LOOP
    v_did := v_driver_ids[((i - 1) % v_driver_count) + 1];
    v_rid := v_route_ids[((i - 1) % v_route_count) + 1];
    
    -- Status distribution: 62 Active, 18 Upcoming, 6 Expired/Ended
    IF i <= 62 THEN
      v_status := 'Active';
    ELSIF i <= 80 THEN
      v_status := 'Upcoming';
    ELSE
      v_status := 'Ended';
    END IF;
    
    INSERT INTO driver_assignments (
      school_id, driver_id, vehicle_id, route_id, assignment_type, 
      start_date, end_date, shift, status, created_by, notes
    ) VALUES (
      v_school_id,
      v_did,
      v_rid,
      v_rid,
      CASE WHEN i % 4 = 0 THEN 'Trip' ELSE 'Route' END,
      CASE 
        WHEN v_status = 'Active' THEN CURRENT_DATE - INTERVAL '15 days'
        WHEN v_status = 'Upcoming' THEN CURRENT_DATE + INTERVAL '5 days'
        ELSE CURRENT_DATE - INTERVAL '60 days'
      END,
      CASE 
        WHEN v_status = 'Active' THEN CURRENT_DATE + INTERVAL '15 days'
        WHEN v_status = 'Upcoming' THEN CURRENT_DATE + INTERVAL '35 days'
        ELSE CURRENT_DATE - INTERVAL '5 days'
      END,
      CASE WHEN i % 3 = 1 THEN 'Morning Shift' WHEN i % 3 = 2 THEN 'Evening Shift' ELSE 'General' END,
      v_status,
      'Transport Manager',
      'Assigned for academic route operation.'
    );
  END LOOP;

  -- ========================================================
  -- 2. SEED TRAINING (Target: 48 total trainings)
  -- ========================================================
  -- Mockup: Completed 32, In Progress 10, Upcoming 12, Overdue 4 (Total = 58 for labels, let's seed 58)
  FOR i IN 1..58 LOOP
    v_did := v_driver_ids[((i - 1) % v_driver_count) + 1];
    
    IF i <= 32 THEN
      v_status := 'Completed';
    ELSIF i <= 42 THEN
      v_status := 'In Progress';
    ELSIF i <= 54 THEN
      v_status := 'Upcoming';
    ELSE
      v_status := 'Overdue';
    END IF;
    
    INSERT INTO driver_training (
      school_id, driver_id, training_program, training_type, provider,
      start_date, end_date, status, certificate_url, next_due_date
    ) VALUES (
      v_school_id,
      v_did,
      CASE 
        WHEN i % 5 = 1 THEN 'Defensive Driving Techniques'
        WHEN i % 5 = 2 THEN 'First Aid Training'
        WHEN i % 5 = 3 THEN 'Fire Safety & Emergency'
        WHEN i % 5 = 4 THEN 'Vehicle Maintenance Basics'
        ELSE 'Route & Traffic Management'
      END,
      CASE 
        WHEN i % 5 = 1 THEN 'Safety'
        WHEN i % 5 = 2 THEN 'Medical'
        WHEN i % 5 = 3 THEN 'Safety'
        WHEN i % 5 = 4 THEN 'Technical'
        ELSE 'Operational'
      END,
      CASE 
        WHEN i % 3 = 1 THEN 'Road Safety Academy'
        WHEN i % 3 = 2 THEN 'Red Cross Society'
        ELSE 'Fire & Safety Institute'
      END,
      CASE 
        WHEN v_status = 'Completed' THEN CURRENT_DATE - INTERVAL '6 months'
        WHEN v_status = 'In Progress' THEN CURRENT_DATE - INTERVAL '5 days'
        WHEN v_status = 'Upcoming' THEN CURRENT_DATE + INTERVAL '10 days'
        ELSE CURRENT_DATE - INTERVAL '1 year'
      END,
      CASE 
        WHEN v_status = 'Completed' THEN CURRENT_DATE - INTERVAL '5 months'
        WHEN v_status = 'In Progress' THEN CURRENT_DATE + INTERVAL '5 days'
        WHEN v_status = 'Upcoming' THEN CURRENT_DATE + INTERVAL '15 days'
        ELSE CURRENT_DATE - INTERVAL '11 months'
      END,
      v_status,
      CASE WHEN v_status = 'Completed' THEN 'http://127.0.0.1:8000/storage/v1/object/public/certificates/cert_' || i || '.pdf' ELSE NULL END,
      CASE WHEN v_status = 'Completed' THEN CURRENT_DATE + INTERVAL '6 months' ELSE NULL END
    );
  END LOOP;

  -- ========================================================
  -- 3. SEED VIOLATIONS (Target: 64 total violations)
  -- ========================================================
  -- Mockup: Pending 18, Resolved 38, Cancelled 4, Waived 4 (Total = 64)
  -- Total Fine: 48,750. Paid: 32,250
  -- Let's distribute exactly:
  -- Resolved: 38 (Paid) -> 38 * 850 = 32,250 (Wait, 32,250 / 38 is about 848.68. Let's make 32 have 1000 fine and 6 have 0, or just random values summing to 32,250)
  -- Pending: 18 -> total fine 16,500
  -- Cancelled/Waived: 8 -> fine 0
  FOR i IN 1..64 LOOP
    v_did := v_driver_ids[((i - 1) % v_driver_count) + 1];
    v_rid := v_route_ids[((i - 1) % v_route_count) + 1];
    
    IF i <= 18 THEN
      v_status := 'Pending';
      v_fine := CASE WHEN i <= 10 THEN 1000.00 WHEN i <= 15 THEN 500.00 ELSE 2000.00 END;
    ELSIF i <= 56 THEN
      v_status := 'Resolved';
      -- We need the sum of Resolved fines to equal 32250.00
      -- 38 records. Let's do 30 records of 1000.00 and 8 records of 281.25, or similar.
      v_fine := CASE WHEN i <= 48 THEN 1000.00 ELSE 281.25 END;
    ELSIF i <= 60 THEN
      v_status := 'Cancelled';
      v_fine := 0.00;
    ELSE
      v_status := 'Waived';
      v_fine := 0.00;
    END IF;
    
    INSERT INTO driver_violations (
      school_id, driver_id, violation_type, description, date_time, 
      location, vehicle_id, severity, status, fine_amount
    ) VALUES (
      v_school_id,
      v_did,
      CASE 
        WHEN i % 5 = 1 THEN 'Overspeeding'
        WHEN i % 5 = 2 THEN 'Signal Jump'
        WHEN i % 5 = 3 THEN 'Seat Belt Not Worn'
        WHEN i % 5 = 4 THEN 'Mobile Usage'
        ELSE 'Harsh Braking'
      END,
      CASE 
        WHEN i % 5 = 1 THEN 'Speed Limit: 60 km/h, Detected: 82 km/h'
        WHEN i % 5 = 2 THEN 'Red Light Violation'
        WHEN i % 5 = 3 THEN 'Safety Violation'
        WHEN i % 5 = 4 THEN 'Using Mobile While Driving'
        ELSE 'Unsafe Driving'
      END,
      CURRENT_TIMESTAMP - (i * INTERVAL '6 hours'),
      CASE 
        WHEN i % 3 = 1 THEN 'NH-24, Ghaziabad, UP'
        WHEN i % 3 = 2 THEN 'Sector 62, Noida, UP'
        ELSE 'Knowledge Park 3, Greater Noida, UP'
      END,
      v_rid,
      CASE WHEN i % 3 = 1 THEN 'High' WHEN i % 3 = 2 THEN 'Medium' ELSE 'Low' END,
      v_status,
      v_fine
    );
  END LOOP;

END $$;
