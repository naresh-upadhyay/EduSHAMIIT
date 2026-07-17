-- Migration: 176_driver_assignments_training_violations_enhanced.sql
-- Description: Enhance tables with missing columns and seed high-fidelity mockup data.

SET ROLE supabase_admin;

-- 1. Schema Enhancements
ALTER TABLE driver_assignments
  ADD COLUMN IF NOT EXISTS start_time TEXT DEFAULT '06:00 AM',
  ADD COLUMN IF NOT EXISTS end_time TEXT DEFAULT '06:00 PM',
  ADD COLUMN IF NOT EXISTS days TEXT DEFAULT 'Mon,Tue,Wed,Thu,Fri',
  ADD COLUMN IF NOT EXISTS distance NUMERIC(10, 2) DEFAULT 15.0,
  ADD COLUMN IF NOT EXISTS estimated_duration TEXT DEFAULT '45 mins',
  ADD COLUMN IF NOT EXISTS total_stops INT DEFAULT 10;

ALTER TABLE driver_training
  ADD COLUMN IF NOT EXISTS start_time TEXT DEFAULT '09:00 AM',
  ADD COLUMN IF NOT EXISTS end_time TEXT DEFAULT '05:00 PM';

RESET ROLE;

-- 2. Clear out existing assignments, training, and violations to prevent duplicates
DELETE FROM driver_assignments;
DELETE FROM driver_training;
DELETE FROM driver_violations;

-- 3. Ensure Route/Vehicle mappings exist in bus_routes
-- We need the exact vehicles and routes shown in the mockup
INSERT INTO bus_routes (id, school_id, route_name, bus_number, total_capacity, status, vehicle_type)
VALUES
  ('a1111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'Route 101', 'UP16 ET 1234', 52, 'active', 'AC Bus'),
  ('a2222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'Route 102', 'UP16 ET 5678', 52, 'active', 'AC Bus'),
  ('a3333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'Route 105', 'UP16 ET 9101', 60, 'active', 'Non AC Bus'),
  ('a4444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 'Route 108', 'UP16 ET 1122', 52, 'active', 'AC Bus'),
  ('a5555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', 'Route 103', 'UP16 ET 3344', 32, 'active', 'Mini Bus'),
  ('a6666666-6666-6666-6666-666666666666', '11111111-1111-1111-1111-111111111111', 'Route 104', 'UP16 ET 7788', 52, 'active', 'AC Bus'),
  ('a7777777-7777-7777-7777-777777777777', '11111111-1111-1111-1111-111111111111', 'Route 107', 'UP16 ET 8899', 32, 'active', 'Mini Bus'),
  ('a8888888-8888-8888-8888-888888888888', '11111111-1111-1111-1111-111111111111', 'Route 101', 'UP16 ET 2468', 52, 'active', 'AC Bus'),
  ('a9999999-9999-9999-9999-999999999999', '11111111-1111-1111-1111-111111111111', 'Route 106', 'UP16 ET 1357', 60, 'active', 'Non AC Bus'),
  ('a1010101-1010-1010-1010-101010101010', '11111111-1111-1111-1111-111111111111', 'Route 109', 'UP16 ET 9753', 32, 'active', 'Mini Bus')
ON CONFLICT (id) DO UPDATE SET 
  route_name = EXCLUDED.route_name,
  bus_number = EXCLUDED.bus_number,
  vehicle_type = EXCLUDED.vehicle_type;

-- 4. Update core driver details to match screenshots
UPDATE drivers SET name = 'Ramesh Kumar', email = 'ramesh.kumar@gmail.com', phone = '9876543210' WHERE driver_code = 'DRV001';
UPDATE drivers SET name = 'Sandeep Singh', email = 'sandeep.singh@gmail.com', phone = '9812345678' WHERE driver_code = 'DRV002';
UPDATE drivers SET name = 'Ajay Pal', email = 'ajaypal89@gmail.com', phone = '9654321098' WHERE driver_code = 'DRV003';
UPDATE drivers SET name = 'Mohd. Imran', email = 'imran.khan@gmail.com', phone = '9712345671' WHERE driver_code = 'DRV004';
UPDATE drivers SET name = 'Vijay Yadav', email = 'vijay.yadav@gmail.com', phone = '9554321678' WHERE driver_code = 'DRV005';
UPDATE drivers SET name = 'Dinesh Chaurasia', email = 'dinesh.c@gmail.com', phone = '9833456123' WHERE driver_code = 'DRV006';
UPDATE drivers SET name = 'Prakash Tiwari', email = 'prakash.tiwari@gmail.com', phone = '9911223344' WHERE driver_code = 'DRV007';
UPDATE drivers SET name = 'Rohit Kumar', email = 'rohit.kumar@gmail.com', phone = '9871234432' WHERE driver_code = 'DRV008';
UPDATE drivers SET name = 'Manoj Verma', email = 'manoj.verma@gmail.com', phone = '9871122334' WHERE driver_code = 'DRV009';
UPDATE drivers SET name = 'Deepak Sharma', email = 'deepak.sharma@gmail.com', phone = '9899112233' WHERE driver_code = 'DRV010';

-- 5. Seed Core Mockup Data
DO $$
DECLARE
  v_school_id UUID := '11111111-1111-1111-1111-111111111111';
  v_drv001 UUID; v_drv002 UUID; v_drv003 UUID; v_drv004 UUID; v_drv005 UUID;
  v_drv006 UUID; v_drv007 UUID; v_drv008 UUID; v_drv009 UUID; v_drv010 UUID;
  v_other_drivers UUID[];
  v_driver_count INT;
  v_routes UUID[];
  v_route_count INT;
  i INT;
  v_did UUID;
  v_rid UUID;
  v_status TEXT;
  v_type TEXT;
  v_severity TEXT;
  v_fine NUMERIC;
BEGIN
  -- Get core driver IDs
  SELECT id INTO v_drv001 FROM drivers WHERE driver_code = 'DRV001';
  SELECT id INTO v_drv002 FROM drivers WHERE driver_code = 'DRV002';
  SELECT id INTO v_drv003 FROM drivers WHERE driver_code = 'DRV003';
  SELECT id INTO v_drv004 FROM drivers WHERE driver_code = 'DRV004';
  SELECT id INTO v_drv005 FROM drivers WHERE driver_code = 'DRV005';
  SELECT id INTO v_drv006 FROM drivers WHERE driver_code = 'DRV006';
  SELECT id INTO v_drv007 FROM drivers WHERE driver_code = 'DRV007';
  SELECT id INTO v_drv008 FROM drivers WHERE driver_code = 'DRV008';
  SELECT id INTO v_drv009 FROM drivers WHERE driver_code = 'DRV009';
  SELECT id INTO v_drv010 FROM drivers WHERE driver_code = 'DRV010';

  -- Get all driver IDs for random distribution
  SELECT array_agg(id) INTO v_other_drivers FROM drivers;
  v_driver_count := cardinality(v_other_drivers);

  -- Get route/vehicle IDs
  SELECT array_agg(id) INTO v_routes FROM bus_routes;
  v_route_count := cardinality(v_routes);

  -- ========================================================
  -- SEEDING ASSIGNMENTS (Total: 86)
  -- Core 10 matching screenshot rows:
  -- ========================================================
  
  -- Ramesh Kumar (DRV001) - Active
  INSERT INTO driver_assignments (school_id, driver_id, vehicle_id, route_id, assignment_type, start_date, end_date, shift, status, created_by, notes, start_time, end_time, days, distance, estimated_duration, total_stops)
  VALUES (v_school_id, v_drv001, 'a1111111-1111-1111-1111-111111111111', 'a1111111-1111-1111-1111-111111111111', 'Route', '2024-05-01', '2024-05-31', 'Morning Shift', 'Active', 'Transport Manager', 'Assigned for academic route operation.', '06:30 AM', '09:30 AM', 'Mon,Tue,Wed,Thu,Fri', 18.6, '48 mins', 12);

  -- Sandeep Singh (DRV002) - Active
  INSERT INTO driver_assignments (school_id, driver_id, vehicle_id, route_id, assignment_type, start_date, end_date, shift, status, created_by, notes, start_time, end_time, days, distance, estimated_duration, total_stops)
  VALUES (v_school_id, v_drv002, 'a2222222-2222-2222-2222-222222222222', 'a2222222-2222-2222-2222-222222222222', 'Route', '2024-05-01', '2024-05-31', 'Evening Shift', 'Active', 'Transport Manager', 'Assigned for afternoon route operation.', '02:00 PM', '05:00 PM', 'Mon,Tue,Wed,Thu,Fri', 20.4, '55 mins', 14);

  -- Ajay Pal (DRV003) - Active
  INSERT INTO driver_assignments (school_id, driver_id, vehicle_id, route_id, assignment_type, start_date, end_date, shift, status, created_by, notes, start_time, end_time, days, distance, estimated_duration, total_stops)
  VALUES (v_school_id, v_drv003, 'a3333333-3333-3333-3333-333333333333', 'a3333333-3333-3333-3333-333333333333', 'Route', '2024-05-02', '2024-05-31', 'General', 'Active', 'Transport Manager', 'Assigned for evening general route.', '03:30 PM', '06:30 PM', 'Mon,Tue,Wed,Thu,Fri', 15.2, '40 mins', 8);

  -- Mohd. Imran (DRV004) - Completed
  INSERT INTO driver_assignments (school_id, driver_id, vehicle_id, route_id, assignment_type, start_date, end_date, shift, status, created_by, notes, start_time, end_time, days, distance, estimated_duration, total_stops)
  VALUES (v_school_id, v_drv004, 'a4444444-4444-4444-4444-444444444444', NULL, 'Trip', '2024-05-05', '2024-05-05', 'General', 'Completed', 'Transport Manager', 'One-time Duty', '07:00 AM', '11:00 AM', 'Sun', 35.0, '2 hours', 2);

  -- Vijay Yadav (DRV005) - Completed
  INSERT INTO driver_assignments (school_id, driver_id, vehicle_id, route_id, assignment_type, start_date, end_date, shift, status, created_by, notes, start_time, end_time, days, distance, estimated_duration, total_stops)
  VALUES (v_school_id, v_drv005, 'a5555555-5555-5555-5555-555555555555', 'a5555555-5555-5555-5555-555555555555', 'Route', '2024-04-28', '2024-04-30', 'Morning Shift', 'Completed', 'Transport Manager', 'Assigned for school run.', '06:45 AM', '09:45 AM', 'Mon,Tue,Wed,Thu,Fri', 14.5, '35 mins', 9);

  -- Dinesh Chaurasia (DRV006) - Ended
  INSERT INTO driver_assignments (school_id, driver_id, vehicle_id, route_id, assignment_type, start_date, end_date, shift, status, created_by, notes, start_time, end_time, days, distance, estimated_duration, total_stops)
  VALUES (v_school_id, v_drv006, 'a6666666-6666-6666-6666-666666666666', 'a6666666-6666-6666-6666-666666666666', 'Route', '2024-04-20', '2024-04-27', 'Evening Shift', 'Ended', 'Transport Manager', 'Completed route run.', '01:30 PM', '04:30 PM', 'Mon,Tue,Wed,Thu,Fri', 19.8, '50 mins', 13);

  -- Prakash Tiwari (DRV007) - Upcoming
  INSERT INTO driver_assignments (school_id, driver_id, vehicle_id, route_id, assignment_type, start_date, end_date, shift, status, created_by, notes, start_time, end_time, days, distance, estimated_duration, total_stops)
  VALUES (v_school_id, v_drv007, 'a7777777-7777-7777-7777-777777777777', NULL, 'Trip', '2024-05-18', '2024-05-18', 'General', 'Upcoming', 'Transport Manager', 'One-time Duty', '08:00 AM', '12:00 PM', 'Sat', 40.0, '2.5 hours', 1);

  -- Rohit Kumar (DRV008) - Upcoming
  INSERT INTO driver_assignments (school_id, driver_id, vehicle_id, route_id, assignment_type, start_date, end_date, shift, status, created_by, notes, start_time, end_time, days, distance, estimated_duration, total_stops)
  VALUES (v_school_id, v_drv008, 'a8888888-8888-8888-8888-888888888888', 'a8888888-8888-8888-8888-888888888888', 'Route', '2024-06-01', '2024-06-30', 'Evening Shift', 'Upcoming', 'Transport Manager', 'Upcoming evening route.', '03:30 PM', '06:30 PM', 'Mon,Tue,Wed,Thu,Fri', 17.5, '45 mins', 11);

  -- Manoj Verma (DRV009) - Upcoming
  INSERT INTO driver_assignments (school_id, driver_id, vehicle_id, route_id, assignment_type, start_date, end_date, shift, status, created_by, notes, start_time, end_time, days, distance, estimated_duration, total_stops)
  VALUES (v_school_id, v_drv009, 'a9999999-9999-9999-9999-999999999999', 'a9999999-9999-9999-9999-999999999999', 'Route', '2024-06-01', '2024-06-30', 'Morning Shift', 'Upcoming', 'Transport Manager', 'Upcoming morning route.', '06:30 AM', '09:30 AM', 'Mon,Tue,Wed,Thu,Fri', 16.0, '42 mins', 10);

  -- Deepak Sharma (DRV010) - Cancelled
  INSERT INTO driver_assignments (school_id, driver_id, vehicle_id, route_id, assignment_type, start_date, end_date, shift, status, created_by, notes, start_time, end_time, days, distance, estimated_duration, total_stops)
  VALUES (v_school_id, v_drv010, 'a1010101-1010-1010-1010-101010101010', NULL, 'Trip', '2024-05-25', '2024-05-25', 'General', 'Cancelled', 'Transport Manager', 'Cancelled trip duty.', '07:00 AM', '11:00 AM', 'Sat', 22.0, '1 hour', 4);

  -- Let's seed remaining 76 assignments programmatically
  -- Target splits: Active: 62 (we seeded 3 -> 59 more), Upcoming: 18 (we seeded 3 -> 15 more), Ended: 6 (we seeded 3 -> 3 more)
  -- Expiring Soon: 5 (this must fall in Active, and have end_date between CURRENT_DATE and CURRENT_DATE + 3)
  FOR i IN 11..86 LOOP
    v_did := v_other_drivers[(i % v_driver_count) + 1];
    v_rid := v_routes[(i % v_route_count) + 1];

    IF i <= 66 THEN
      v_status := 'Active';
    ELSIF i <= 81 THEN
      v_status := 'Upcoming';
    ELSE
      v_status := 'Ended';
    END IF;

    INSERT INTO driver_assignments (
      school_id, driver_id, vehicle_id, route_id, assignment_type, 
      start_date, end_date, shift, status, created_by, notes,
      start_time, end_time, days, distance, estimated_duration, total_stops
    ) VALUES (
      v_school_id,
      v_did,
      v_rid,
      v_rid,
      CASE WHEN i % 5 = 0 THEN 'Trip' ELSE 'Route' END,
      CASE 
        WHEN v_status = 'Active' THEN CURRENT_DATE - INTERVAL '15 days'
        WHEN v_status = 'Upcoming' THEN CURRENT_DATE + INTERVAL '5 days'
        ELSE CURRENT_DATE - INTERVAL '60 days'
      END,
      CASE 
        -- To make exactly 5 "Expiring Soon", let's set 5 records' end_date to CURRENT_DATE + 2 days
        WHEN i <= 15 THEN CURRENT_DATE + INTERVAL '2 days'
        WHEN v_status = 'Active' THEN CURRENT_DATE + INTERVAL '30 days'
        WHEN v_status = 'Upcoming' THEN CURRENT_DATE + INTERVAL '45 days'
        ELSE CURRENT_DATE - INTERVAL '5 days'
      END,
      CASE WHEN i % 3 = 0 THEN 'Morning Shift' WHEN i % 3 = 1 THEN 'Evening Shift' ELSE 'General' END,
      v_status,
      'Transport Manager',
      'Assigned for route operation.',
      '07:00 AM',
      '10:00 AM',
      'Mon,Tue,Wed,Thu,Fri',
      12.0 + (i % 8),
      '35 mins',
      8 + (i % 6)
    );
  END LOOP;

  -- ========================================================
  -- SEEDING TRAINING (Total: 48)
  -- Core 8 matching mockup rows:
  -- ========================================================
  
  -- Ramesh Kumar (DRV001) - Completed
  INSERT INTO driver_training (school_id, driver_id, training_program, training_type, provider, start_date, end_date, status, certificate_url, next_due_date, start_time, end_time)
  VALUES (v_school_id, v_drv001, 'Defensive Driving Techniques', 'Safety', 'Road Safety Academy', '2024-05-01', '2024-05-02', 'Completed', 'http://127.0.0.1:8000/storage/v1/object/public/certificates/cert_1.pdf', '2025-05-01', '09:00 AM', '05:00 PM');

  -- Sandeep Singh (DRV002) - Completed
  INSERT INTO driver_training (school_id, driver_id, training_program, training_type, provider, start_date, end_date, status, certificate_url, next_due_date, start_time, end_time)
  VALUES (v_school_id, v_drv002, 'First Aid Training', 'Medical', 'Red Cross Society', '2024-05-05', '2024-05-05', 'Completed', 'http://127.0.0.1:8000/storage/v1/object/public/certificates/cert_2.pdf', '2025-05-05', '09:00 AM', '05:00 PM');

  -- Ajay Pal (DRV003) - Completed
  INSERT INTO driver_training (school_id, driver_id, training_program, training_type, provider, start_date, end_date, status, certificate_url, next_due_date, start_time, end_time)
  VALUES (v_school_id, v_drv003, 'Fire Safety & Emergency', 'Safety', 'Fire & Safety Institute', '2024-05-10', '2024-05-11', 'Completed', 'http://127.0.0.1:8000/storage/v1/object/public/certificates/cert_3.pdf', '2025-05-10', '09:00 AM', '05:00 PM');

  -- Mohd. Imran (DRV004) - In Progress
  INSERT INTO driver_training (school_id, driver_id, training_program, training_type, provider, start_date, end_date, status, certificate_url, next_due_date, start_time, end_time)
  VALUES (v_school_id, v_drv004, 'Vehicle Maintenance Basics', 'Technical', 'Auto Tech Training Center', '2024-05-15', '2024-05-17', 'In Progress', NULL, '2025-05-15', '09:00 AM', '01:00 PM');

  -- Vijay Yadav (DRV005) - Completed
  INSERT INTO driver_training (school_id, driver_id, training_program, training_type, provider, start_date, end_date, status, certificate_url, next_due_date, start_time, end_time)
  VALUES (v_school_id, v_drv005, 'Route & Traffic Management', 'Operational', 'Transport Academy', '2024-05-20', '2024-05-21', 'Completed', 'http://127.0.0.1:8000/storage/v1/object/public/certificates/cert_5.pdf', '2025-05-20', '09:00 AM', '05:00 PM');

  -- Dinesh Chaurasia (DRV006) - Upcoming
  INSERT INTO driver_training (school_id, driver_id, training_program, training_type, provider, start_date, end_date, status, certificate_url, next_due_date, start_time, end_time)
  VALUES (v_school_id, v_drv006, 'Passenger Safety Awareness', 'Safety', 'Road Safety Academy', '2024-05-25', '2024-05-25', 'Upcoming', NULL, '2025-05-25', '09:00 AM', '05:00 PM');

  -- Prakash Tiwari (DRV007) - Completed
  INSERT INTO driver_training (school_id, driver_id, training_program, training_type, provider, start_date, end_date, status, certificate_url, next_due_date, start_time, end_time)
  VALUES (v_school_id, v_drv007, 'Advanced Driving Skills', 'Safety', 'Driving Excellence', '2024-05-28', '2024-05-30', 'Completed', 'http://127.0.0.1:8000/storage/v1/object/public/certificates/cert_7.pdf', '2025-05-28', '10:00 AM', '02:00 PM');

  -- Rohit Kumar (DRV008) - Overdue
  INSERT INTO driver_training (school_id, driver_id, training_program, training_type, provider, start_date, end_date, status, certificate_url, next_due_date, start_time, end_time)
  VALUES (v_school_id, v_drv008, 'Environmental Awareness', 'Awareness', 'Green Earth Foundation', '2024-06-01', '2024-06-01', 'Overdue', NULL, '2025-06-01', '09:00 AM', '05:00 PM');

  -- Let's seed remaining 40 trainings programmatically
  -- Target splits: Completed: 32 (seeded 5 -> 27 more), In Progress: 10 (seeded 1 -> 9 more), Upcoming: 12 (seeded 1 -> 11 more), Overdue: 4 (seeded 1 -> 3 more)
  -- Total: 48 (58 originally, let's keep 48 total to match screenshot KPI "Total Programs: 48")
  -- Completed: 32, In Progress: 10, Upcoming: 12, Overdue: 4 -> Wait, 32 + 10 + 12 + 4 = 58. Wait, in the Training screenshot, the KPI is:
  -- Total Trainings: 48, Completed: 32 (66.67%), In Progress: 10 (20.83%), Upcoming: 12 (25.00%), Overdue: 4 (8.33%).
  -- Wait! 32 + 10 + 12 + 4 is 58. Why does the KPI show Total Trainings 48?
  -- Ah, 32 / 48 = 66.67%! 10 / 48 = 20.83%! 12 / 48 = 25.00%! 4 / 48 = 8.33%!
  -- Yes! The percentages are calculated out of 48, but the counts sum to 58. Oh! That means there are exactly 48 trainings in the grid list (maybe some drivers have multiple programs, or some statuses are overlapping).
  -- Let's seed exactly 48 records in total:
  -- Completed: 27 (seeded 5 -> 22 more)
  -- In Progress: 8 (seeded 1 -> 7 more)
  -- Upcoming: 10 (seeded 1 -> 9 more)
  -- Overdue: 3 (seeded 1 -> 2 more)
  -- Total = 48 records. Let's do that!
  FOR i IN 9..48 LOOP
    v_did := v_other_drivers[(i % v_driver_count) + 1];
    
    IF i <= 27 THEN
      v_status := 'Completed';
    ELSIF i <= 35 THEN
      v_status := 'In Progress';
    ELSIF i <= 45 THEN
      v_status := 'Upcoming';
    ELSE
      v_status := 'Overdue';
    END IF;

    INSERT INTO driver_training (
      school_id, driver_id, training_program, training_type, provider,
      start_date, end_date, status, certificate_url, next_due_date, start_time, end_time
    ) VALUES (
      v_school_id,
      v_did,
      CASE 
        WHEN i % 5 = 0 THEN 'Defensive Driving Techniques'
        WHEN i % 5 = 1 THEN 'First Aid Training'
        WHEN i % 5 = 2 THEN 'Fire Safety & Emergency'
        WHEN i % 5 = 3 THEN 'Vehicle Maintenance Basics'
        ELSE 'Route & Traffic Management'
      END,
      CASE 
        WHEN i % 5 = 0 THEN 'Safety'
        WHEN i % 5 = 1 THEN 'Medical'
        WHEN i % 5 = 2 THEN 'Safety'
        WHEN i % 5 = 3 THEN 'Technical'
        ELSE 'Operational'
      END,
      CASE 
        WHEN i % 3 = 0 THEN 'Road Safety Academy'
        WHEN i % 3 = 1 THEN 'Red Cross Society'
        ELSE 'Fire & Safety Institute'
      END,
      CURRENT_DATE - (i * INTERVAL '5 days'),
      CURRENT_DATE - (i * INTERVAL '5 days') + INTERVAL '2 days',
      v_status,
      CASE WHEN v_status = 'Completed' THEN 'http://127.0.0.1:8000/storage/v1/object/public/certificates/cert_' || i || '.pdf' ELSE NULL END,
      CURRENT_DATE + INTERVAL '1 year',
      '09:00 AM',
      '05:00 PM'
    );
  END LOOP;

  -- ========================================================
  -- SEEDING VIOLATIONS (Total: 64)
  -- Core 8 matching mockup rows:
  -- ========================================================
  
  -- Ramesh Kumar (DRV001) - Overspeeding - Pending
  INSERT INTO driver_violations (school_id, driver_id, violation_type, description, date_time, location, vehicle_id, severity, status, fine_amount)
  VALUES (v_school_id, v_drv001, 'Overspeeding', 'Speed Limit: 60 km/h, Detected: 82 km/h', '2024-05-01 08:35:00+00', 'NH-24, Ghaziabad, UP', 'a1111111-1111-1111-1111-111111111111', 'High', 'Pending', 2000.00);

  -- Sandeep Singh (DRV002) - Signal Jump - Pending
  INSERT INTO driver_violations (school_id, driver_id, violation_type, description, date_time, location, vehicle_id, severity, status, fine_amount)
  VALUES (v_school_id, v_drv002, 'Signal Jump', 'Red Light Violation', '2024-05-02 09:12:00+00', 'Sector 62, Noida, UP', 'a2222222-2222-2222-2222-222222222222', 'High', 'Pending', 2500.00);

  -- Ajay Pal (DRV003) - Seat Belt Not Worn - Resolved
  INSERT INTO driver_violations (school_id, driver_id, violation_type, description, date_time, location, vehicle_id, severity, status, fine_amount)
  VALUES (v_school_id, v_drv003, 'Seat Belt Not Worn', 'Safety Violation', '2024-05-03 10:20:00+00', 'Knowledge Park 3, Greater Noida, UP', 'a3333333-3333-3333-3333-333333333333', 'Medium', 'Resolved', 500.00);

  -- Mohd. Imran (DRV004) - Mobile Usage - Resolved
  INSERT INTO driver_violations (school_id, driver_id, violation_type, description, date_time, location, vehicle_id, severity, status, fine_amount)
  VALUES (v_school_id, v_drv004, 'Mobile Usage', 'Using Mobile While Driving', '2024-05-04 11:05:00+00', 'Dadri Road, Greater Noida, UP', 'a4444444-4444-4444-4444-444444444444', 'High', 'Resolved', 2000.00);

  -- Vijay Yadav (DRV005) - Harsh Braking - Pending
  INSERT INTO driver_violations (school_id, driver_id, violation_type, description, date_time, location, vehicle_id, severity, status, fine_amount)
  VALUES (v_school_id, v_drv005, 'Harsh Braking', 'Unsafe Driving', '2024-05-05 14:15:00+00', 'Yamuna Expressway, UP', 'a5555555-5555-5555-5555-555555555555', 'Low', 'Pending', 250.00);

  -- Dinesh Chaurasia (DRV006) - Wrong Route - Resolved
  INSERT INTO driver_violations (school_id, driver_id, violation_type, description, date_time, location, vehicle_id, severity, status, fine_amount)
  VALUES (v_school_id, v_drv006, 'Wrong Route', 'Route Deviation', '2024-05-06 15:40:00+00', 'Knowledge Park 2, Greater Noida, UP', 'a6666666-6666-6666-6666-666666666666', 'Medium', 'Resolved', 750.00);

  -- Prakash Tiwari (DRV007) - Overtime Driving - Pending
  INSERT INTO driver_violations (school_id, driver_id, violation_type, description, date_time, location, vehicle_id, severity, status, fine_amount)
  VALUES (v_school_id, v_drv007, 'Overtime Driving', 'Exceeding Duty Hours', '2024-05-07 18:30:00+00', 'NH-9, Hapur, UP', 'a7777777-7777-7777-7777-777777777777', 'Medium', 'Pending', 1500.00);

  -- Rohit Kumar (DRV008) - Parking Violation - Resolved
  INSERT INTO driver_violations (school_id, driver_id, violation_type, description, date_time, location, vehicle_id, severity, status, fine_amount)
  VALUES (v_school_id, v_drv008, 'Parking Violation', 'No Parking Zone', '2024-05-08 19:45:00+00', 'Sector 18, Noida, UP', 'a8888888-8888-8888-8888-888888888888', 'Low', 'Resolved', 250.00);

  -- Let's seed remaining 56 violations programmatically
  -- Target splits: Pending: 18 (seeded 4 -> 14 more), Resolved: 38 (seeded 4 -> 34 more), Cancelled: 4, Waived: 4
  -- Total Fines: 48,750 (seeded 9,750 -> 39,000 more), Paid Fines: 32,250 (seeded 3,500 -> 28,750 more)
  -- Let's distribute exactly:
  -- Pending: 14 records -> 39000 - 28750 = 10,250 fine (e.g. 10 of 1000, 1 of 250)
  -- Resolved: 34 records -> 28,750 fine (e.g. 28 of 1000, 3 of 250, 3 of 0)
  -- Cancelled/Waived: 8 records -> 0 fine
  FOR i IN 9..64 LOOP
    v_did := v_other_drivers[(i % v_driver_count) + 1];
    v_rid := v_routes[(i % v_route_count) + 1];

    IF i <= 22 THEN
      v_status := 'Pending';
      v_fine := CASE WHEN i <= 18 THEN 1000.00 ELSE 250.00 END;
    ELSIF i <= 56 THEN
      v_status := 'Resolved';
      v_fine := CASE WHEN i <= 50 THEN 1000.00 ELSE 250.00 END;
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
        WHEN i % 5 = 0 THEN 'Overspeeding'
        WHEN i % 5 = 1 THEN 'Signal Jump'
        WHEN i % 5 = 2 THEN 'Seat Belt Not Worn'
        WHEN i % 5 = 3 THEN 'Mobile Usage'
        ELSE 'Harsh Braking'
      END,
      CASE 
        WHEN i % 5 = 0 THEN 'Speed Limit: 60 km/h, Detected: 82 km/h'
        WHEN i % 5 = 1 THEN 'Red Light Violation'
        WHEN i % 5 = 2 THEN 'Safety Violation'
        WHEN i % 5 = 3 THEN 'Using Mobile While Driving'
        ELSE 'Unsafe Driving'
      END,
      CURRENT_TIMESTAMP - (i * INTERVAL '12 hours'),
      CASE 
        WHEN i % 3 = 0 THEN 'NH-24, Ghaziabad, UP'
        WHEN i % 3 = 1 THEN 'Sector 62, Noida, UP'
        ELSE 'Knowledge Park 3, Greater Noida, UP'
      END,
      v_rid,
      CASE WHEN i % 3 = 0 THEN 'High' WHEN i % 3 = 1 THEN 'Medium' ELSE 'Low' END,
      v_status,
      v_fine
    );
  END LOOP;

END $$;
