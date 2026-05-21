-- ============================================================
-- Migration 097: Sample Parent Profiles and Relations
-- Links parents to existing students from migration 083
-- School: 11111111-1111-1111-1111-111111111111
-- ============================================================

-- ── PARENT PROFILES ──────────────────────────────────────────
INSERT INTO profiles (id, school_id, user_id, full_name, email, role, phone,
                      gender, address, avatar_url)
VALUES
  -- Ramesh Kumar — Father of Arjun Kumar (bb000001)
  ('cc000001-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111',
   'PAR-2024-0001', 'Ramesh Kumar', 'ramesh.kumar@parent.eduverse.school',
   'parent', '+91-9100000001', 'Male',
   '42, MG Road, Bengaluru, Karnataka', NULL),

  -- Sunita Devi — Mother of Priya Singh (bb000002)
  ('cc000002-0000-0000-0000-000000000002',
   '11111111-1111-1111-1111-111111111111',
   'PAR-2024-0002', 'Sunita Devi', 'sunita.devi@parent.eduverse.school',
   'parent', '+91-9100000002', 'Female',
   '15, Park Street, Kolkata, West Bengal', NULL),

  -- Anil Mehta — Father of Rohan Mehta (bb000003)
  ('cc000003-0000-0000-0000-000000000003',
   '11111111-1111-1111-1111-111111111111',
   'PAR-2024-0003', 'Anil Mehta', 'anil.mehta@parent.eduverse.school',
   'parent', '+91-9100000003', 'Male',
   '78, Sector 15, Chandigarh', NULL),

  -- Lakshmi Iyer — Mother of Ananya Iyer (bb000004)
  ('cc000004-0000-0000-0000-000000000004',
   '11111111-1111-1111-1111-111111111111',
   'PAR-2024-0004', 'Lakshmi Iyer', 'lakshmi.iyer@parent.eduverse.school',
   'parent', '+91-9100000004', 'Female',
   '23, Anna Nagar, Chennai, Tamil Nadu', NULL),

  -- Deepak Sharma — Father of Vikram Sharma (bb000005)
  ('cc000005-0000-0000-0000-000000000005',
   '11111111-1111-1111-1111-111111111111',
   'PAR-2024-0005', 'Deepak Sharma', 'deepak.sharma@parent.eduverse.school',
   'parent', '+91-9100000005', 'Male',
   '56, Connaught Place, New Delhi', NULL),

  -- Meera Nair — Mother of both Kavya Nair (bb000006) and Aditya Nair (bb000007)
  ('cc000006-0000-0000-0000-000000000006',
   '11111111-1111-1111-1111-111111111111',
   'PAR-2024-0006', 'Meera Nair', 'meera.nair@parent.eduverse.school',
   'parent', '+91-9100000006', 'Female',
   '12, Marine Drive, Kochi, Kerala', NULL)
ON CONFLICT (id) DO NOTHING;


-- ── PARENT-STUDENT RELATIONS ────────────────────────────────
INSERT INTO parent_student_relations (school_id, parent_id, student_id, relationship, is_primary, can_pickup, approved, approved_by, approved_at)
VALUES
  -- Ramesh Kumar → Arjun Kumar (father)
  ('11111111-1111-1111-1111-111111111111',
   'cc000001-0000-0000-0000-000000000001',
   'bb000001-0000-0000-0000-000000000001',
   'father', TRUE, TRUE, TRUE,
   'aa000001-0000-0000-0000-000000000001', NOW()),

  -- Sunita Devi → Priya Singh (mother)
  ('11111111-1111-1111-1111-111111111111',
   'cc000002-0000-0000-0000-000000000002',
   'bb000002-0000-0000-0000-000000000002',
   'mother', TRUE, TRUE, TRUE,
   'aa000001-0000-0000-0000-000000000001', NOW()),

  -- Anil Mehta → Rohan Mehta (father)
  ('11111111-1111-1111-1111-111111111111',
   'cc000003-0000-0000-0000-000000000003',
   'bb000003-0000-0000-0000-000000000003',
   'father', TRUE, TRUE, TRUE,
   'aa000001-0000-0000-0000-000000000001', NOW()),

  -- Lakshmi Iyer → Ananya Iyer (mother)
  ('11111111-1111-1111-1111-111111111111',
   'cc000004-0000-0000-0000-000000000004',
   'bb000004-0000-0000-0000-000000000004',
   'mother', TRUE, TRUE, TRUE,
   'aa000001-0000-0000-0000-000000000001', NOW()),

  -- Deepak Sharma → Vikram Sharma (father)
  ('11111111-1111-1111-1111-111111111111',
   'cc000005-0000-0000-0000-000000000005',
   'bb000005-0000-0000-0000-000000000005',
   'father', TRUE, TRUE, TRUE,
   'aa000001-0000-0000-0000-000000000001', NOW()),

  -- Meera Nair → Kavya Nair (mother) — first child
  ('11111111-1111-1111-1111-111111111111',
   'cc000006-0000-0000-0000-000000000006',
   'bb000006-0000-0000-0000-000000000006',
   'mother', TRUE, TRUE, TRUE,
   'aa000001-0000-0000-0000-000000000001', NOW()),

  -- Meera Nair → Aditya Nair (mother) — second child (multi-child parent)
  ('11111111-1111-1111-1111-111111111111',
   'cc000006-0000-0000-0000-000000000006',
   'bb000007-0000-0000-0000-000000000007',
   'mother', TRUE, TRUE, TRUE,
   'aa000001-0000-0000-0000-000000000001', NOW())
ON CONFLICT (parent_id, student_id) DO NOTHING;


-- ── AUTH USERS FOR PARENTS ──────────────────────────────────
-- These would normally be created via Supabase auth.users.
-- For testing, we insert directly so login works with the backend.
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
VALUES
  ('cc000001-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'ramesh.kumar@parent.eduverse.school', crypt('Parent@123', gen_salt('bf')), NOW(), NOW(), NOW()),
  ('cc000002-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'sunita.devi@parent.eduverse.school', crypt('Parent@123', gen_salt('bf')), NOW(), NOW(), NOW()),
  ('cc000003-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'anil.mehta@parent.eduverse.school', crypt('Parent@123', gen_salt('bf')), NOW(), NOW(), NOW()),
  ('cc000004-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'lakshmi.iyer@parent.eduverse.school', crypt('Parent@123', gen_salt('bf')), NOW(), NOW(), NOW()),
  ('cc000005-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'deepak.sharma@parent.eduverse.school', crypt('Parent@123', gen_salt('bf')), NOW(), NOW(), NOW()),
  ('cc000006-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'meera.nair@parent.eduverse.school', crypt('Parent@123', gen_salt('bf')), NOW(), NOW(), NOW())
ON CONFLICT (id) DO NOTHING;
