-- Migration: 173_driver_management.sql
-- Description: Create drivers table and seed 68 drivers.

CREATE TABLE IF NOT EXISTS drivers (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id           UUID REFERENCES schools(id) ON DELETE CASCADE,
  driver_code         TEXT NOT NULL UNIQUE,
  name                TEXT NOT NULL,
  email               TEXT,
  phone               TEXT NOT NULL,
  photo_url           TEXT,
  license_no          TEXT NOT NULL,
  license_type        TEXT NOT NULL DEFAULT 'LMV', -- 'LMV', 'HMV'
  license_issue_date  DATE,
  license_expiry_date DATE,
  issuing_authority   TEXT,
  experience_years    INT DEFAULT 0,
  status              TEXT NOT NULL DEFAULT 'Inactive', -- 'On Duty', 'On Leave', 'Inactive'
  assigned_vehicle_id UUID REFERENCES bus_routes(id) ON DELETE SET NULL,
  date_of_birth       DATE,
  blood_group         TEXT,
  aadhar_no           TEXT,
  address             TEXT,
  joined_date         DATE,
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- Ensure columns exist if table was already created in a post-206 schema
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS name TEXT;
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS photo_url TEXT;
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS date_of_birth DATE;
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS blood_group TEXT;
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS address TEXT;

-- Index
CREATE INDEX IF NOT EXISTS idx_drivers_school ON drivers(school_id);
CREATE INDEX IF NOT EXISTS idx_drivers_vehicle ON drivers(assigned_vehicle_id);

-- Clean old data if any
DELETE FROM drivers;

-- Seed the specific 8 drivers from the mockup dynamically
DO $$
DECLARE
  v_school_id UUID;
  v_v1 UUID; v_v2 UUID; v_v3 UUID; v_v4 UUID; v_v5 UUID;
  v_route_ids UUID[] := ARRAY[]::UUID[];
  v_route_count INT;
  i INT;
  v_status TEXT;
  v_veh_id UUID;
  v_license_type TEXT;
BEGIN
  SELECT id INTO v_school_id FROM public.schools ORDER BY created_at ASC LIMIT 1;
  IF v_school_id IS NULL THEN
    RETURN;
  END IF;

  -- Get some vehicle/route IDs
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'bus_routes') THEN
    SELECT array_agg(id) INTO v_route_ids FROM bus_routes;
  ELSIF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'vehicles') THEN
    SELECT array_agg(id) INTO v_route_ids FROM vehicles;
  END IF;
  v_route_count := COALESCE(array_length(v_route_ids, 1), 0);

  -- 1. Ramesh Kumar (DRV001)
  INSERT INTO drivers (school_id, driver_code, name, email, phone, license_no, license_type, license_issue_date, license_expiry_date, issuing_authority, experience_years, status, assigned_vehicle_id, date_of_birth, blood_group, aadhar_no, address, joined_date)
  VALUES (v_school_id, 'DRV001', 'Ramesh Kumar', 'ramesh.kumar@gmail.com', '9876543210', 'UP16 20210012345', 'LMV', '2021-01-10', '2031-01-09', 'RTO, Noida, UP', 8, 'On Duty', CASE WHEN v_route_count >= 1 THEN v_route_ids[1] ELSE NULL END, '1987-03-12', 'B+', 'XXXX XXXX 5678', 'Sector 62, Noida, UP', '2018-01-15');

  -- 2. Sandeep Singh (DRV002)
  INSERT INTO drivers (school_id, driver_code, name, email, phone, license_no, license_type, license_issue_date, license_expiry_date, issuing_authority, experience_years, status, assigned_vehicle_id, date_of_birth, blood_group, aadhar_no, address, joined_date)
  VALUES (v_school_id, 'DRV002', 'Sandeep Singh', 'sandeep.singh@gmail.com', '9812345678', 'UP16 20180098765', 'HMV', '2018-05-20', '2028-05-19', 'RTO, Noida, UP', 10, 'On Duty', v_route_ids[2], '1985-08-22', 'O+', 'XXXX XXXX 9876', 'Sector 63, Noida, UP', '2019-02-10');

  -- 3. Ajay Pal (DRV003)
  INSERT INTO drivers (school_id, driver_code, name, email, phone, license_no, license_type, license_issue_date, license_expiry_date, issuing_authority, experience_years, status, assigned_vehicle_id, date_of_birth, blood_group, aadhar_no, address, joined_date)
  VALUES (v_school_id, 'DRV003', 'Ajay Pal', 'ajaypal89@gmail.com', '9654321098', 'UP14 20190045678', 'LMV', '2019-11-15', '2029-11-14', 'RTO, Ghaziabad, UP', 6, 'On Leave', NULL, '1991-12-05', 'A+', 'XXXX XXXX 4321', 'Sector 15, Vasundhara, Ghaziabad', '2020-05-01');

  -- 4. Mohd. Imran (DRV004)
  INSERT INTO drivers (school_id, driver_code, name, email, phone, license_no, license_type, license_issue_date, license_expiry_date, issuing_authority, experience_years, status, assigned_vehicle_id, date_of_birth, blood_group, aadhar_no, address, joined_date)
  VALUES (v_school_id, 'DRV004', 'Mohd. Imran', 'imran.khan@gmail.com', '9712345671', 'UP16 20170033456', 'LMV', '2017-06-10', '2027-06-09', 'RTO, Noida, UP', 12, 'On Duty', v_route_ids[3], '1983-04-18', 'AB+', 'XXXX XXXX 1111', 'Sector 22, Noida, UP', '2017-08-15');

  -- 5. Vijay Yadav (DRV005)
  INSERT INTO drivers (school_id, driver_code, name, email, phone, license_no, license_type, license_issue_date, license_expiry_date, issuing_authority, experience_years, status, assigned_vehicle_id, date_of_birth, blood_group, aadhar_no, address, joined_date)
  VALUES (v_school_id, 'DRV005', 'Vijay Yadav', 'vijay.yadav@gmail.com', '9554321678', 'UP16 20220077889', 'HMV', '2022-09-05', '2032-09-04', 'RTO, Noida, UP', 7, 'On Duty', v_route_ids[4], '1990-10-15', 'O-', 'XXXX XXXX 2222', 'Indirapuram, Ghaziabad, UP', '2022-10-01');

  -- 6. Dinesh Chaurasia (DRV006)
  INSERT INTO drivers (school_id, driver_code, name, email, phone, license_no, license_type, license_issue_date, license_expiry_date, issuing_authority, experience_years, status, assigned_vehicle_id, date_of_birth, blood_group, aadhar_no, address, joined_date)
  VALUES (v_school_id, 'DRV006', 'Dinesh Chaurasia', 'dinesh.c@gmail.com', '9833456123', 'UP16 20160011223', 'HMV', '2016-04-12', '2026-04-11', 'RTO, Noida, UP', 15, 'Inactive', NULL, '1979-01-20', 'B-', 'XXXX XXXX 3333', 'Sector 50, Noida, UP', '2016-05-01');

  -- 7. Prakash Tiwari (DRV007)
  INSERT INTO drivers (school_id, driver_code, name, email, phone, license_no, license_type, license_issue_date, license_expiry_date, issuing_authority, experience_years, status, assigned_vehicle_id, date_of_birth, blood_group, aadhar_no, address, joined_date)
  VALUES (v_school_id, 'DRV007', 'Prakash Tiwari', 'prakash.tiwari@gmail.com', '9911223344', 'UP16 20210055667', 'LMV', '2021-03-25', '2031-03-24', 'RTO, Noida, UP', 9, 'On Duty', v_route_ids[5], '1986-11-30', 'A-', 'XXXX XXXX 4444', 'Sector 45, Noida, UP', '2021-04-01');

  -- 8. Rohit Kumar (DRV008)
  INSERT INTO drivers (school_id, driver_code, name, email, phone, license_no, license_type, license_issue_date, license_expiry_date, issuing_authority, experience_years, status, assigned_vehicle_id, date_of_birth, blood_group, aadhar_no, address, joined_date)
  VALUES (v_school_id, 'DRV008', 'Rohit Kumar', 'rohit.kumar@gmail.com', '9871234432', 'UP16 20230088990', 'LMV', '2023-08-01', '2033-08-01', 'RTO, Noida, UP', 3, 'On Leave', NULL, '1994-06-15', 'AB-', 'XXXX XXXX 5555', 'Sector 12, Noida, UP', '2023-09-10');

  -- Seed the remaining 60 drivers programmatically to reach exactly 68 drivers
  -- On Duty count needed: 42 - 5 = 37 more
  -- On Leave count needed: 6 - 2 = 4 more
  -- Inactive count needed: 4 - 1 = 3 more
  -- Remaining 16 will be status 'Active' (but not on duty/leave) to make total active = 58
  FOR i IN 9..68 LOOP
    IF i <= 45 THEN
      v_status := 'On Duty';
      v_veh_id := CASE WHEN v_route_count IS NOT NULL AND v_route_count > 0 THEN v_route_ids[(i % v_route_count) + 1] ELSE NULL END;
    ELSIF i <= 49 THEN
      v_status := 'On Leave';
      v_veh_id := NULL;
    ELSIF i <= 52 THEN
      v_status := 'Inactive';
      v_veh_id := NULL;
    ELSE
      v_status := 'Active'; -- Active but unassigned
      v_veh_id := NULL;
    END IF;

    IF i % 2 = 0 THEN
      v_license_type := 'HMV';
    ELSE
      v_license_type := 'LMV';
    END IF;

    INSERT INTO drivers (
      school_id,
      driver_code,
      name,
      email,
      phone,
      license_no,
      license_type,
      license_issue_date,
      license_expiry_date,
      issuing_authority,
      experience_years,
      status,
      assigned_vehicle_id,
      date_of_birth,
      blood_group,
      aadhar_no,
      address,
      joined_date
    ) VALUES (
      v_school_id,
      'DRV' || lpad(i::text, 3, '0'),
      'Driver ' || i::text,
      'driver' || i::text || '@gmail.com',
      '+91987654' || lpad(i::text, 4, '0'),
      'UP16 ' || (2010 + (i % 14))::text || '00' || lpad(i::text, 5, '0'),
      v_license_type,
      (CURRENT_DATE - INTERVAL '5 years')::date,
      (CURRENT_DATE + INTERVAL '5 years')::date,
      'RTO, Noida, UP',
      (i % 15) + 2,
      v_status,
      v_veh_id,
      (CURRENT_DATE - INTERVAL '35 years' - (i * INTERVAL '2 months'))::date,
      (ARRAY['A+', 'B+', 'O+', 'AB+'])[floor(random()*4)::int + 1],
      'XXXX XXXX ' || lpad(i::text, 4, '0'),
      'Sector ' || (10 + (i % 80))::text || ', Noida, UP',
      (CURRENT_DATE - INTERVAL '4 years' + (i * INTERVAL '15 days'))::date
    );
  END LOOP;
END $$;
