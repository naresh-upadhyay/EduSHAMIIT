CREATE OR REPLACE FUNCTION public.sync_profile_to_driver()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_driver_code text;
BEGIN
  IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
    IF LOWER(COALESCE(NEW.role, '')) IN ('driver', 'bus_driver') THEN
      v_driver_code := COALESCE(NEW.user_id, 'DRV' || UPPER(SUBSTRING(REPLACE(NEW.id::text, '-', ''), 1, 6)));

      IF EXISTS (SELECT 1 FROM public.drivers WHERE profile_id = NEW.id) THEN
        UPDATE public.drivers SET
          school_id = NEW.school_id,
          status = CASE WHEN NEW.status = 'Inactive' THEN 'Inactive' ELSE status END,
          updated_at = NOW()
        WHERE profile_id = NEW.id;
      ELSE
        INSERT INTO public.drivers (
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
    END IF;
    RETURN NEW;
  ELSIF (TG_OP = 'DELETE') THEN
    DELETE FROM public.drivers WHERE profile_id = OLD.id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$function$;

-- Seed test fixture profiles
INSERT INTO public.schools (id, name, subscription_status)
VALUES ('11111111-1111-1111-1111-111111111111', 'Shami Innovation Academy', 'active')
ON CONFLICT (id) DO UPDATE SET subscription_status = 'active';

INSERT INTO public.profiles (id, user_id, school_id, email, full_name, role)
VALUES 
('38a93170-997b-4b4c-bc8e-256b93169c23', '38a93170-997b-4b4c-bc8e-256b93169c23', '11111111-1111-1111-1111-111111111111', 'mathematicsking888@gmail.com', 'King Doe', 'super_admin'),
('33d93277-35a4-4b33-bdf1-9bf0f3c8b45a', '33d93277-35a4-4b33-bdf1-9bf0f3c8b45a', '11111111-1111-1111-1111-111111111111', 'driver.rajesh@school.com', 'Rajesh Kumar', 'driver'),
('22222222-2222-2222-2222-222222222222', '22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'teacher.priya@school.com', 'Priya Sharma', 'teacher'),
('44444444-4444-4444-4444-444444444444', '44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 'student.aarav@school.com', 'Aarav Patel', 'student'),
('55555555-5555-5555-5555-555555555555', '55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', 'student.diya@school.com', 'Diya Sharma', 'student'),
('66666666-6666-6666-6666-666666666666', '66666666-6666-6666-6666-666666666666', '11111111-1111-1111-1111-111111111111', 'student.kabir@school.com', 'Kabir Khan', 'student'),
('77777777-7777-7777-7777-777777777777', '77777777-7777-7777-7777-777777777777', '11111111-1111-1111-1111-111111111111', 'student.ananya@school.com', 'Ananya Verma', 'student')
ON CONFLICT (id) DO UPDATE SET 
    school_id = EXCLUDED.school_id,
    email = EXCLUDED.email,
    full_name = EXCLUDED.full_name,
    role = EXCLUDED.role;
