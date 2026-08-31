-- PROFILES (extends auth.users, supports students, parents, teachers, and admins)
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  user_id TEXT NOT NULL,
  full_name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'student',
  class TEXT,
  department TEXT,
  designation TEXT,
  roll_number INT,
  employee_id TEXT,
  gender TEXT CHECK (gender IN ('Male', 'Female', 'Other')),
  date_of_birth DATE,
  blood_group TEXT,
  email TEXT,
  phone TEXT,
  admission_number TEXT,
  nationality TEXT DEFAULT 'Indian',
  religion TEXT,
  category TEXT,
  address TEXT,
  house TEXT,
  avatar_url TEXT,
  father_name TEXT,
  father_occupation TEXT,
  father_phone TEXT,
  mother_name TEXT,
  mother_occupation TEXT,
  mother_phone TEXT,
  local_guardian TEXT,
  qualification TEXT,
  experience_years INT DEFAULT 0,
  rating DECIMAL(2,1) DEFAULT 0.0,
  xp_points INT DEFAULT 0,
  learning_streak INT DEFAULT 0,
  best_streak INT DEFAULT 0,
  last_login DATE DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(school_id, user_id)
);

-- Seed Super Admin user profile for shamiitltd@gmail.com attached to the primary institute
DO $$
DECLARE
  v_admin_id UUID := '00000000-0000-0000-0000-000000000001';
  v_school_id UUID := '11111111-1111-1111-1111-111111111111';
BEGIN
  -- If user exists in auth.users, sync ID
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'auth' AND table_name = 'users') THEN
    SELECT id INTO v_admin_id FROM auth.users WHERE email = 'shamiitltd@gmail.com' LIMIT 1;
    IF v_admin_id IS NULL THEN
      v_admin_id := '00000000-0000-0000-0000-000000000001';
      -- Insert into auth.users if possible
      BEGIN
        INSERT INTO auth.users (
          id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
          raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
          confirmation_token, recovery_token, email_change_token_new, email_change,
          email_change_token_current, phone_change, phone_change_token, reauthentication_token
        ) VALUES (
          v_admin_id,
          '00000000-0000-0000-0000-000000000000',
          'authenticated',
          'authenticated',
          'shamiitltd@gmail.com',
          crypt('Admin@12345', gen_salt('bf')),
          NOW(),
          '{"provider":"email","providers":["email"]}'::jsonb,
          '{"role":"super_admin","full_name":"EduSHAMIIT Super Admin"}'::jsonb,
          NOW(),
          NOW(),
          '', '', '', '', '', '', '', ''
        ) ON CONFLICT (id) DO UPDATE SET
          confirmation_token = COALESCE(auth.users.confirmation_token, ''),
          recovery_token = COALESCE(auth.users.recovery_token, ''),
          email_change_token_new = COALESCE(auth.users.email_change_token_new, ''),
          email_change = COALESCE(auth.users.email_change, ''),
          phone_change = COALESCE(auth.users.phone_change, ''),
          phone_change_token = COALESCE(auth.users.phone_change_token, ''),
          reauthentication_token = COALESCE(auth.users.reauthentication_token, '');
      EXCEPTION WHEN OTHERS THEN
        NULL;
      END;
    END IF;
  END IF;

  INSERT INTO public.profiles (
    id, school_id, user_id, full_name, role, designation, department,
    email, phone, created_at, updated_at
  ) VALUES (
    v_admin_id,
    v_school_id,
    'shamiitltd@gmail.com',
    'EduSHAMIIT Super Admin',
    'super_admin',
    'Executive Director & Super Admin',
    'Administration',
    'shamiitltd@gmail.com',
    '+91 98765 43210',
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    role = 'super_admin',
    school_id = EXCLUDED.school_id,
    email = EXCLUDED.email,
    full_name = EXCLUDED.full_name;

  -- Seed Core Teachers and Students under the primary institute
  INSERT INTO public.profiles (id, school_id, user_id, full_name, email, role, class, designation, department, xp_points)
  VALUES
    ('aa000001-0000-0000-0000-000000000001', v_school_id, 'aa000001-0000-0000-0000-000000000001', 'Mrs. Priya Sharma', 'priya.sharma@demo.school.com', 'teacher', '10A', 'Head of Mathematics', 'Science', 5000),
    ('aa000002-0000-0000-0000-000000000002', v_school_id, 'aa000002-0000-0000-0000-000000000002', 'Dr. Arjun Verma', 'arjun.verma@demo.school.com', 'teacher', '10A', 'Senior Physics Lecturer', 'Science', 5200),
    ('20000000-0000-0000-0000-000000000002', v_school_id, '20000000-0000-0000-0000-000000000002', 'Senior Academic Teacher', 'teacher@demo.school.com', 'teacher', '10A', 'Senior Faculty', 'Academics', 4500),
    ('10000000-0000-0000-0000-000000000002', v_school_id, '10000000-0000-0000-0000-000000000002', 'Aarav Sharma', 'aarav.student@demo.school.com', 'student', '10A', 'Student', 'Academics', 3500),
    ('bb000001-0000-0000-0000-000000000001', v_school_id, 'bb000001-0000-0000-0000-000000000001', 'Arjun Kumar', 'arjun.k@demo.school.com', 'student', '10A', 'Student', 'Academics', 3800),
    ('073cf4b4-7678-4a9d-bca8-a186d4e3bf5e', v_school_id, '073cf4b4-7678-4a9d-bca8-a186d4e3bf5e', 'Naresh Upadhyay', 'naresh@demo.school.com', 'student', '10A', 'Student', 'Academics', 3200)
  ON CONFLICT (id) DO NOTHING;

END $$;
