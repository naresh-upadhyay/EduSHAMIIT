-- Migration: 186_sync_drivers_with_user_profiles.sql
-- Description: Link drivers table to profiles, sync existing driver profiles, purge unlinked fake drivers, and set up automatic trigger sync.

-- 1. Add profile_id column to drivers table if not exists
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS profile_id UUID UNIQUE REFERENCES profiles(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_drivers_profile_id ON drivers(profile_id);
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS name TEXT;
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS phone TEXT;

-- 2. First, link any existing drivers to profiles by email if matching
UPDATE drivers d
SET profile_id = p.id
FROM profiles p
WHERE d.profile_id IS NULL
  AND LOWER(p.role) IN ('driver', 'bus_driver')
  AND p.email IS NOT NULL
  AND LOWER(d.email) = LOWER(p.email);

-- 3. Insert drivers for profiles with role driver/bus_driver that don't have a drivers entry yet
INSERT INTO drivers (
  id,
  school_id,
  driver_code,
  name,
  email,
  phone,
  photo_url,
  license_no,
  license_type,
  license_issue_date,
  license_expiry_date,
  issuing_authority,
  experience_years,
  status,
  date_of_birth,
  blood_group,
  address,
  joined_date,
  profile_id
)
SELECT
  gen_random_uuid(),
  p.school_id,
  COALESCE(p.user_id, 'DRV' || UPPER(SUBSTRING(REPLACE(p.id::text, '-', ''), 1, 6))),
  p.full_name,
  p.email,
  COALESCE(p.phone, '9876543210'),
  p.avatar_url,
  'UP16 ' || TO_CHAR(CURRENT_DATE, 'YYYY') || LPAD((FLOOR(RANDOM() * 89999 + 10000))::INT::text, 5, '0'),
  'LMV',
  CURRENT_DATE - INTERVAL '3 years',
  CURRENT_DATE + INTERVAL '7 years',
  'RTO, Noida, UP',
  8,
  CASE WHEN p.status = 'Inactive' THEN 'Inactive' ELSE 'Active' END,
  p.date_of_birth,
  COALESCE(p.blood_group, 'B+'),
  p.address,
  COALESCE(p.created_at::date, CURRENT_DATE),
  p.id
FROM profiles p
WHERE LOWER(p.role) IN ('driver', 'bus_driver')
  AND NOT EXISTS (
    SELECT 1 FROM drivers d WHERE d.profile_id = p.id
  );

-- 4. Clean up mock/fake drivers that have no profile_id (i.e. not in user management)
-- Clean child tables for mock drivers first
DELETE FROM driver_documents WHERE driver_id IN (SELECT id FROM drivers WHERE profile_id IS NULL);
DELETE FROM driver_performance WHERE driver_id IN (SELECT id FROM drivers WHERE profile_id IS NULL);
DELETE FROM driver_assignments WHERE driver_id IN (SELECT id FROM drivers WHERE profile_id IS NULL);
DELETE FROM driver_training WHERE driver_id IN (SELECT id FROM drivers WHERE profile_id IS NULL);
DELETE FROM driver_violations WHERE driver_id IN (SELECT id FROM drivers WHERE profile_id IS NULL);
UPDATE transport_routes SET driver_id = NULL WHERE driver_id IN (SELECT id FROM drivers WHERE profile_id IS NULL);

-- Now delete orphan mock drivers
DELETE FROM drivers WHERE profile_id IS NULL;

-- 5. Seed sample driver_documents, performance, assignments, training, violations for synced drivers if missing
DO $$
DECLARE
  r RECORD;
  v_route_id UUID;
  v_bus_id UUID;
BEGIN
  -- Get sample route & vehicle ID if exists
  SELECT id INTO v_route_id FROM transport_routes LIMIT 1;
  SELECT id INTO v_bus_id FROM bus_routes LIMIT 1;

  FOR r IN SELECT * FROM drivers LOOP
    -- Ensure driver documents
    IF NOT EXISTS (SELECT 1 FROM driver_documents WHERE driver_id = r.id) THEN
      INSERT INTO driver_documents (school_id, driver_id, document_type, document_no, issued_date, expiry_date, status, issuing_authority)
      VALUES 
        (r.school_id, r.id, 'Driving License', r.license_no, CURRENT_DATE - INTERVAL '3 years', CURRENT_DATE + INTERVAL '7 years', 'Valid', 'RTO, Noida, UP'),
        (r.school_id, r.id, 'Police Verification', 'PV-' || UPPER(SUBSTRING(REPLACE(r.id::text, '-', ''), 1, 6)), CURRENT_DATE - INTERVAL '1 year', CURRENT_DATE + INTERVAL '2 years', 'Valid', 'UP Police Dept');
    END IF;

    -- Ensure driver performance
    IF NOT EXISTS (SELECT 1 FROM driver_performance WHERE driver_id = r.id) THEN
      INSERT INTO driver_performance (school_id, driver_id, attendance_score, safety_score, route_adherence_score, vehicle_care_score, feedback_score, trips_completed, recent_feedback)
      VALUES (r.school_id, r.id, 4.8, 4.9, 4.7, 4.8, 4.9, 120, 'Excellent punctuality and safe driving habits.');
    END IF;

    -- Ensure driver training
    IF NOT EXISTS (SELECT 1 FROM driver_training WHERE driver_id = r.id) THEN
      INSERT INTO driver_training (school_id, driver_id, training_program, training_type, provider, start_date, end_date, status)
      VALUES (r.school_id, r.id, 'Defensive Driving & Road Safety', 'Safety', 'National Safety Council', CURRENT_DATE - INTERVAL '6 months', CURRENT_DATE - INTERVAL '5 months', 'Completed');
    END IF;
  END LOOP;
END $$;

-- 6. Trigger Function to automatically sync profiles table with drivers table
CREATE OR REPLACE FUNCTION sync_profile_to_driver()
RETURNS TRIGGER AS $$
DECLARE
  v_driver_code TEXT;
BEGIN
  IF (TG_OP = 'INSERT') THEN
    IF LOWER(NEW.role) IN ('driver', 'bus_driver') THEN
      v_driver_code := COALESCE(NEW.user_id, 'DRV' || UPPER(SUBSTRING(REPLACE(NEW.id::text, '-', ''), 1, 6)));
      
      INSERT INTO drivers (
        id,
        school_id,
        driver_code,
        name,
        email,
        phone,
        photo_url,
        license_no,
        license_type,
        license_issue_date,
        license_expiry_date,
        issuing_authority,
        experience_years,
        status,
        date_of_birth,
        blood_group,
        address,
        joined_date,
        profile_id
      ) VALUES (
        gen_random_uuid(),
        NEW.school_id,
        v_driver_code,
        NEW.full_name,
        NEW.email,
        COALESCE(NEW.phone, '9876543210'),
        NEW.avatar_url,
        'UP16 ' || TO_CHAR(CURRENT_DATE, 'YYYY') || LPAD((FLOOR(RANDOM() * 89999 + 10000))::INT::text, 5, '0'),
        'LMV',
        CURRENT_DATE - INTERVAL '3 years',
        CURRENT_DATE + INTERVAL '7 years',
        'RTO, Noida, UP',
        5,
        CASE WHEN NEW.status = 'Inactive' THEN 'Inactive' ELSE 'Active' END,
        NEW.date_of_birth,
        COALESCE(NEW.blood_group, 'B+'),
        NEW.address,
        COALESCE(NEW.created_at::date, CURRENT_DATE),
        NEW.id
      )
      ON CONFLICT (profile_id) DO UPDATE SET
        name = EXCLUDED.name,
        email = EXCLUDED.email,
        phone = EXCLUDED.phone,
        photo_url = EXCLUDED.photo_url,
        school_id = EXCLUDED.school_id,
        status = EXCLUDED.status,
        updated_at = NOW();
    END IF;
    RETURN NEW;

  ELSIF (TG_OP = 'UPDATE') THEN
    -- If role changed away from driver, delete driver record
    IF LOWER(OLD.role) IN ('driver', 'bus_driver') AND LOWER(NEW.role) NOT IN ('driver', 'bus_driver') THEN
      DELETE FROM drivers WHERE profile_id = OLD.id;
    -- If role changed to driver, or driver fields updated
    ELSIF LOWER(NEW.role) IN ('driver', 'bus_driver') THEN
      v_driver_code := COALESCE(NEW.user_id, 'DRV' || UPPER(SUBSTRING(REPLACE(NEW.id::text, '-', ''), 1, 6)));
      
      IF EXISTS (SELECT 1 FROM drivers WHERE profile_id = NEW.id) THEN
        UPDATE drivers SET
          name = NEW.full_name,
          email = NEW.email,
          phone = COALESCE(NEW.phone, phone),
          photo_url = NEW.avatar_url,
          school_id = NEW.school_id,
          date_of_birth = NEW.date_of_birth,
          address = NEW.address,
          status = CASE WHEN NEW.status = 'Inactive' THEN 'Inactive' ELSE status END,
          updated_at = NOW()
        WHERE profile_id = NEW.id;
      ELSE
        INSERT INTO drivers (
          id,
          school_id,
          driver_code,
          name,
          email,
          phone,
          photo_url,
          license_no,
          license_type,
          license_issue_date,
          license_expiry_date,
          issuing_authority,
          experience_years,
          status,
          date_of_birth,
          blood_group,
          address,
          joined_date,
          profile_id
        ) VALUES (
          gen_random_uuid(),
          NEW.school_id,
          v_driver_code,
          NEW.full_name,
          NEW.email,
          COALESCE(NEW.phone, '9876543210'),
          NEW.avatar_url,
          'UP16 ' || TO_CHAR(CURRENT_DATE, 'YYYY') || LPAD((FLOOR(RANDOM() * 89999 + 10000))::INT::text, 5, '0'),
          'LMV',
          CURRENT_DATE - INTERVAL '3 years',
          CURRENT_DATE + INTERVAL '7 years',
          'RTO, Noida, UP',
          5,
          CASE WHEN NEW.status = 'Inactive' THEN 'Inactive' ELSE 'Active' END,
          NEW.date_of_birth,
          COALESCE(NEW.blood_group, 'B+'),
          NEW.address,
          COALESCE(NEW.created_at::date, CURRENT_DATE),
          NEW.id
        );
      END IF;
    END IF;
    RETURN NEW;

  ELSIF (TG_OP = 'DELETE') THEN
    DELETE FROM drivers WHERE profile_id = OLD.id;
    RETURN OLD;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 7. Attach Trigger to profiles table
DROP TRIGGER IF EXISTS trg_sync_profile_to_driver ON profiles;
CREATE TRIGGER trg_sync_profile_to_driver
AFTER INSERT OR UPDATE OR DELETE ON profiles
FOR EACH ROW EXECUTE FUNCTION sync_profile_to_driver();
