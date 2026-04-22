-- ============================================================
-- Migration 083: Realistic Profiles (Teachers + Students)
-- Data matches EduVerse teacher & student portal mockups
-- School: 11111111-1111-1111-1111-111111111111
-- ============================================================

-- ── TEACHERS ────────────────────────────────────────────────
INSERT INTO profiles (id, school_id, user_id, full_name, email, role, phone,
                      xp_points, learning_streak, best_streak)
VALUES
  -- Mrs. Priya Sharma — Mathematics HOD (primary teacher user)
  ('aa000001-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111',
   'TCH-2024-0042', 'Mrs. Priya Sharma', 'priya.sharma@eduverse.school',
   'teacher', '+91-9876543201', 0, 0, 0),

  -- Dr. Arjun Verma — Physics
  ('aa000002-0000-0000-0000-000000000002',
   '11111111-1111-1111-1111-111111111111',
   'TCH-2024-0043', 'Dr. Arjun Verma', 'arjun.verma@eduverse.school',
   'teacher', '+91-9876543202', 0, 0, 0),

  -- Ms. Preethi Gupta — English
  ('aa000003-0000-0000-0000-000000000003',
   '11111111-1111-1111-1111-111111111111',
   'TCH-2024-0044', 'Ms. Preethi Gupta', 'preethi.gupta@eduverse.school',
   'teacher', '+91-9876543203', 0, 0, 0),

  -- Dr. Suresh Mehta — Chemistry
  ('aa000004-0000-0000-0000-000000000004',
   '11111111-1111-1111-1111-111111111111',
   'TCH-2024-0045', 'Dr. Suresh Mehta', 'suresh.mehta@eduverse.school',
   'teacher', '+91-9876543204', 0, 0, 0),

  -- Mrs. Kavitha Rao — History
  ('aa000005-0000-0000-0000-000000000005',
   '11111111-1111-1111-1111-111111111111',
   'TCH-2024-0046', 'Mrs. Kavitha Rao', 'kavitha.rao@eduverse.school',
   'teacher', '+91-9876543205', 0, 0, 0),

  -- Mr. Vijay Jain — Computer Science
  ('aa000006-0000-0000-0000-000000000006',
   '11111111-1111-1111-1111-111111111111',
   'TCH-2024-0047', 'Mr. Vijay Jain', 'vijay.jain@eduverse.school',
   'teacher', '+91-9876543206', 0, 0, 0)

ON CONFLICT (id) DO NOTHING;


-- ── STUDENTS — Class X-A ────────────────────────────────────
INSERT INTO profiles (id, school_id, user_id, full_name, email, role, class,
                      roll_number, phone, father_name, father_phone,
                      xp_points, learning_streak, best_streak)
VALUES
  -- Arjun Kumar — Rank 2, 96% attendance, star performer
  ('bb000001-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111',
   'STU-2024-1082', 'Arjun Kumar', 'arjun.kumar@student.eduverse.school',
   'student', 'X-A', '1', '+91-9000000001',
   'Ramesh Kumar', '+91-9100000001', 2450, 18, 22),

  -- Riya Gupta — Rank 5, 94% attendance
  ('bb000002-0000-0000-0000-000000000002',
   '11111111-1111-1111-1111-111111111111',
   'STU-2024-1083', 'Riya Gupta', 'riya.gupta@student.eduverse.school',
   'student', 'X-A', '2', '+91-9000000002',
   'Rajesh Gupta', '+91-9100000002', 1980, 12, 18),

  -- Sanjay Mehta — Rank 38, 72% attendance, at risk
  ('bb000003-0000-0000-0000-000000000003',
   '11111111-1111-1111-1111-111111111111',
   'STU-2024-1084', 'Sanjay Mehta', 'sanjay.mehta@student.eduverse.school',
   'student', 'X-A', '3', '+91-9000000003',
   'Sunil Mehta', '+91-9100000003', 620, 3, 7),

  -- Neha Patel — Rank 8, 98% attendance, top performer
  ('bb000004-0000-0000-0000-000000000004',
   '11111111-1111-1111-1111-111111111111',
   'STU-2024-1085', 'Neha Patel', 'neha.patel@student.eduverse.school',
   'student', 'X-A', '4', '+91-9000000004',
   'Nitin Patel', '+91-9100000004', 3100, 25, 30),

  -- Vikram Joshi — Rank 42, 68% attendance, at risk
  ('bb000005-0000-0000-0000-000000000005',
   '11111111-1111-1111-1111-111111111111',
   'STU-2024-1086', 'Vikram Joshi', 'vikram.joshi@student.eduverse.school',
   'student', 'X-A', '5', '+91-9000000005',
   'Vinod Joshi', '+91-9100000005', 450, 2, 5),

  -- Ananya Singh — Roll 6
  ('bb000006-0000-0000-0000-000000000006',
   '11111111-1111-1111-1111-111111111111',
   'STU-2024-1087', 'Ananya Singh', 'ananya.singh@student.eduverse.school',
   'student', 'X-A', '6', '+91-9000000006',
   'Anil Singh', '+91-9100000006', 1750, 10, 14),

  -- Rohit Verma — Roll 7
  ('bb000007-0000-0000-0000-000000000007',
   '11111111-1111-1111-1111-111111111111',
   'STU-2024-1088', 'Rohit Verma', 'rohit.verma@student.eduverse.school',
   'student', 'X-A', '7', '+91-9000000007',
   'Rakesh Verma', '+91-9100000007', 1320, 8, 11),

  -- Kavya Sharma — Roll 8
  ('bb000008-0000-0000-0000-000000000008',
   '11111111-1111-1111-1111-111111111111',
   'STU-2024-1089', 'Kavya Sharma', 'kavya.sharma@student.eduverse.school',
   'student', 'X-A', '8', '+91-9000000008',
   'Kiran Sharma', '+91-9100000008', 2100, 15, 19)

ON CONFLICT (id) DO NOTHING;


-- ── STUDENTS — Class X-B ────────────────────────────────────
INSERT INTO profiles (id, school_id, user_id, full_name, email, role, class,
                      roll_number, phone, father_name, father_phone,
                      xp_points, learning_streak, best_streak)
VALUES
  ('bb000009-0000-0000-0000-000000000009',
   '11111111-1111-1111-1111-111111111111',
   'STU-2024-1090', 'Priya Nair', 'priya.nair@student.eduverse.school',
   'student', 'X-B', '1', '+91-9000000009',
   'Prakash Nair', '+91-9100000009', 1650, 9, 13),

  ('bb000010-0000-0000-0000-000000000010',
   '11111111-1111-1111-1111-111111111111',
   'STU-2024-1091', 'Deepak Yadav', 'deepak.yadav@student.eduverse.school',
   'student', 'X-B', '2', '+91-9000000010',
   'Dinesh Yadav', '+91-9100000010', 980, 5, 9),

  ('bb000011-0000-0000-0000-000000000011',
   '11111111-1111-1111-1111-111111111111',
   'STU-2024-1092', 'Shreya Iyer', 'shreya.iyer@student.eduverse.school',
   'student', 'X-B', '3', '+91-9000000011',
   'Sriram Iyer', '+91-9100000011', 2200, 14, 20)

ON CONFLICT (id) DO NOTHING;


-- ── STUDENTS — Class IX-A ───────────────────────────────────
INSERT INTO profiles (id, school_id, user_id, full_name, email, role, class,
                      roll_number, phone, father_name, father_phone,
                      xp_points, learning_streak, best_streak)
VALUES
  ('bb000012-0000-0000-0000-000000000012',
   '11111111-1111-1111-1111-111111111111',
   'STU-2024-1093', 'Aarav Shah', 'aarav.shah@student.eduverse.school',
   'student', 'IX-A', '1', '+91-9000000012',
   'Amit Shah', '+91-9100000012', 1890, 11, 16),

  ('bb000013-0000-0000-0000-000000000013',
   '11111111-1111-1111-1111-111111111111',
   'STU-2024-1094', 'Pooja Reddy', 'pooja.reddy@student.eduverse.school',
   'student', 'IX-A', '2', '+91-9000000013',
   'Pawan Reddy', '+91-9100000013', 1540, 7, 12),

  ('bb000014-0000-0000-0000-000000000014',
   '11111111-1111-1111-1111-111111111111',
   'STU-2024-1095', 'Kunal Bose', 'kunal.bose@student.eduverse.school',
   'student', 'IX-A', '3', '+91-9000000014',
   'Kamal Bose', '+91-9100000014', 760, 4, 8)

ON CONFLICT (id) DO NOTHING;
