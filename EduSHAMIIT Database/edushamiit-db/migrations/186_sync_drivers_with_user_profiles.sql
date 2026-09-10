-- Migration: 186_sync_drivers_with_user_profiles.sql
-- Description: Link drivers table to profiles (SSOT), sync existing driver profiles, purge unlinked fake drivers, and set up automatic trigger sync.

-- 1. Add profile_id column to drivers table if not exists
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS profile_id UUID UNIQUE REFERENCES profiles(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_drivers_profile_id ON drivers(profile_id);

-- 2. First, link any existing drivers to profiles by email if drivers table still has legacy email column
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'drivers' AND column_name = 'email'
  ) THEN
    EXECUTE '
      UPDATE public.drivers d
      SET profile_id = p.id
      FROM public.profiles p
      WHERE d.profile_id IS NULL
        AND LOWER(p.role) IN (''driver'', ''bus_driver'')
        AND p.email IS NOT NULL
        AND LOWER(d.email) = LOWER(p.email)
    ';
  END IF;
END $$;

-- 3. Insert drivers for profiles with role driver/bus_driver that don't have a drivers entry yet
-- (SSOT: personal info like name, email, phone, photo, dob, address resides exclusively in profiles)
INSERT INTO drivers (
  id,
  school_id,
  driver_code,
  license_no,
  license_type,
  license_issue_date,
  license_expiry_date,
  issuing_authority,
  experience_years,
  status,
  joined_date,
  profile_id
)
SELECT
  gen_random_uuid(),
  p.school_id,
  COALESCE(p.user_id, 'DRV' || UPPER(SUBSTRING(REPLACE(p.id::text, '-', ''), 1, 6))),
  'UP16 ' || TO_CHAR(CURRENT_DATE, 'YYYY') || LPAD((FLOOR(RANDOM() * 89999 + 10000))::INT::text, 5, '0'),
  'LMV',
  CURRENT_DATE - INTERVAL '3 years',
  CURRENT_DATE + INTERVAL '7 years',
  'RTO, Noida, UP',
  8,
  CASE WHEN p.status = 'Inactive' THEN 'Inactive' ELSE 'Active' END,
  COALESCE(p.created_at::date, CURRENT_DATE),
  p.id
FROM profiles p
WHERE LOWER(p.role) IN ('driver', 'bus_driver')
  AND NOT EXISTS (
    SELECT 1 FROM drivers d WHERE d.profile_id = p.id
  );

-- 4. Clean up mock/fake drivers that have no profile_id (i.e. not in user management)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'driver_documents') THEN
    DELETE FROM driver_documents WHERE driver_id IN (SELECT id FROM drivers WHERE profile_id IS NULL);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'driver_performance') THEN
    DELETE FROM driver_performance WHERE driver_id IN (SELECT id FROM drivers WHERE profile_id IS NULL);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'driver_assignments') THEN
    DELETE FROM driver_assignments WHERE driver_id IN (SELECT id FROM drivers WHERE profile_id IS NULL);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'driver_training') THEN
    DELETE FROM driver_training WHERE driver_id IN (SELECT id FROM drivers WHERE profile_id IS NULL);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'driver_violations') THEN
    DELETE FROM driver_violations WHERE driver_id IN (SELECT id FROM drivers WHERE profile_id IS NULL);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'transport_routes') THEN
    UPDATE transport_routes SET driver_id = NULL WHERE driver_id IN (SELECT id FROM drivers WHERE profile_id IS NULL);
  END IF;
END $$;

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
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'driver_documents') THEN
      IF NOT EXISTS (SELECT 1 FROM driver_documents WHERE driver_id = r.id) THEN
        INSERT INTO driver_documents (school_id, driver_id, document_type, document_no, issued_date, expiry_date, status, issuing_authority)
        VALUES 
          (r.school_id, r.id, 'Driving License', r.license_no, CURRENT_DATE - INTERVAL '3 years', CURRENT_DATE + INTERVAL '7 years', 'Valid', 'RTO, Noida, UP'),
          (r.school_id, r.id, 'Police Verification', 'PV-' || UPPER(SUBSTRING(REPLACE(r.id::text, '-', ''), 1, 6)), CURRENT_DATE - INTERVAL '1 year', CURRENT_DATE + INTERVAL '2 years', 'Valid', 'UP Police Dept');
      END IF;
    END IF;

    -- Ensure driver performance
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'driver_performance') THEN
      IF NOT EXISTS (SELECT 1 FROM driver_performance WHERE driver_id = r.id) THEN
        INSERT INTO driver_performance (school_id, driver_id, attendance_score, safety_score, route_adherence_score, vehicle_care_score, feedback_score, trips_completed, recent_feedback)
        VALUES (r.school_id, r.id, 4.8, 4.9, 4.7, 4.8, 4.9, 120, 'Excellent punctuality and safe driving habits.');
      END IF;
    END IF;

    -- Ensure driver training
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'driver_training') THEN
      IF NOT EXISTS (SELECT 1 FROM driver_training WHERE driver_id = r.id) THEN
        INSERT INTO driver_training (school_id, driver_id, training_program, training_type, provider, start_date, end_date, status)
        VALUES (r.school_id, r.id, 'Defensive Driving & Road Safety', 'Safety', 'National Safety Council', CURRENT_DATE - INTERVAL '6 months', CURRENT_DATE - INTERVAL '5 months', 'Completed');
      END IF;
    END IF;
  END LOOP;
END $$;

-- 6. Trigger Function to automatically sync profiles table with drivers table (SSOT normalized)
CREATE OR REPLACE FUNCTION sync_profile_to_driver()
RETURNS TRIGGER AS $$
DECLARE
  v_driver_code TEXT;
BEGIN
  IF (TG_OP = 'INSERT') THEN
    IF LOWER(COALESCE(NEW.role, '')) IN ('driver', 'bus_driver') THEN
      v_driver_code := COALESCE(NEW.user_id, 'DRV' || UPPER(SUBSTRING(REPLACE(NEW.id::text, '-', ''), 1, 6)));
      
      INSERT INTO drivers (
        id,
        school_id,
        driver_code,
        license_no,
        license_type,
        license_issue_date,
        license_expiry_date,
        issuing_authority,
        experience_years,
        status,
        joined_date,
        profile_id
      ) VALUES (
        gen_random_uuid(),
        NEW.school_id,
        v_driver_code,
        'UP16 ' || TO_CHAR(CURRENT_DATE, 'YYYY') || LPAD((FLOOR(RANDOM() * 89999 + 10000))::INT::text, 5, '0'),
        'LMV',
        CURRENT_DATE - INTERVAL '3 years',
        CURRENT_DATE + INTERVAL '7 years',
        'RTO, Noida, UP',
        5,
        CASE WHEN NEW.status = 'Inactive' THEN 'Inactive' ELSE 'Active' END,
        COALESCE(NEW.created_at::date, CURRENT_DATE),
        NEW.id
      )
      ON CONFLICT (profile_id) DO UPDATE SET
        school_id = EXCLUDED.school_id,
        status = EXCLUDED.status,
        updated_at = NOW();
    END IF;
    RETURN NEW;

  ELSIF (TG_OP = 'UPDATE') THEN
    -- If role changed away from driver, delete driver record
    IF LOWER(COALESCE(OLD.role, '')) IN ('driver', 'bus_driver') AND LOWER(COALESCE(NEW.role, '')) NOT IN ('driver', 'bus_driver') THEN
      DELETE FROM drivers WHERE profile_id = OLD.id;
    -- If role changed to driver, or driver fields updated
    ELSIF LOWER(COALESCE(NEW.role, '')) IN ('driver', 'bus_driver') THEN
      v_driver_code := COALESCE(NEW.user_id, 'DRV' || UPPER(SUBSTRING(REPLACE(NEW.id::text, '-', ''), 1, 6)));
      
      IF EXISTS (SELECT 1 FROM drivers WHERE profile_id = NEW.id) THEN
        UPDATE drivers SET
          school_id = NEW.school_id,
          status = CASE WHEN NEW.status = 'Inactive' THEN 'Inactive' ELSE status END,
          updated_at = NOW()
        WHERE profile_id = NEW.id;
      ELSE
        INSERT INTO drivers (
          id,
          school_id,
          driver_code,
          license_no,
          license_type,
          license_issue_date,
          license_expiry_date,
          issuing_authority,
          experience_years,
          status,
          joined_date,
          profile_id
        ) VALUES (
          gen_random_uuid(),
          NEW.school_id,
          v_driver_code,
          'UP16 ' || TO_CHAR(CURRENT_DATE, 'YYYY') || LPAD((FLOOR(RANDOM() * 89999 + 10000))::INT::text, 5, '0'),
          'LMV',
          CURRENT_DATE - INTERVAL '3 years',
          CURRENT_DATE + INTERVAL '7 years',
          'RTO, Noida, UP',
          5,
          CASE WHEN NEW.status = 'Inactive' THEN 'Inactive' ELSE 'Active' END,
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Attach Trigger to profiles table
DROP TRIGGER IF EXISTS trg_sync_profile_to_driver ON profiles;
CREATE TRIGGER trg_sync_profile_to_driver
AFTER INSERT OR UPDATE OR DELETE ON profiles
FOR EACH ROW EXECUTE FUNCTION sync_profile_to_driver();
