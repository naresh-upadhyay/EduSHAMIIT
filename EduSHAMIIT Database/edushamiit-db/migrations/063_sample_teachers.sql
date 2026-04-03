-- Sample Teachers for School 1
INSERT INTO profiles (id, school_id, user_id, full_name, role, department, designation, employee_id, qualification, experience_years, rating, email, phone) VALUES
  ('20000000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'TCH-001', 'Mrs. Priya Sharma', 'teacher', 'Mathematics', 'Senior Teacher', 'TCH-2024-0042', 'M.Sc Mathematics, B.Ed', 12, 4.8, 'priya.sharma@school.com', '+91-9876543101'),
  ('20000000-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'TCH-002', 'Mr. Amit Gupta', 'teacher', 'Physics', 'Teacher', 'TCH-2024-0043', 'M.Sc Physics, B.Ed', 8, 4.6, 'amit.gupta@school.com', '+91-9876543102'),
  ('20000000-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', 'TCH-003', 'Mrs. Sunita Reddy', 'teacher', 'Chemistry', 'Head of Department', 'TCH-2024-0044', 'M.Sc Chemistry, M.Ed', 15, 4.9, 'sunita.reddy@school.com', '+91-9876543103'),
  ('20000000-0000-0000-0000-000000000005', '11111111-1111-1111-1111-111111111111', 'TCH-004', 'Mr. Rajesh Kumar', 'teacher', 'English', 'Teacher', 'TCH-2024-0045', 'M.A English, B.Ed', 6, 4.5, 'rajesh.kumar@school.com', '+91-9876543104'),
  ('20000000-0000-0000-0000-000000000006', '11111111-1111-1111-1111-111111111111', 'TCH-005', 'Mrs. Lakshmi Nair', 'teacher', 'Computer Science', 'Senior Teacher', 'TCH-2024-0046', 'M.Tech CS, B.Ed', 10, 4.7, 'lakshmi.nair@school.com', '+91-9876543105')
ON CONFLICT (id) DO NOTHING;

-- Update subjects with teacher assignments
UPDATE subjects SET teacher_id = '20000000-0000-0000-0000-000000000002' WHERE name = 'Mathematics' AND school_id = '11111111-1111-1111-1111-111111111111';
UPDATE subjects SET teacher_id = '20000000-0000-0000-0000-000000000003' WHERE name = 'Physics' AND school_id = '11111111-1111-1111-1111-111111111111';
UPDATE subjects SET teacher_id = '20000000-0000-0000-0000-000000000004' WHERE name = 'Chemistry' AND school_id = '11111111-1111-1111-1111-111111111111';
UPDATE subjects SET teacher_id = '20000000-0000-0000-0000-000000000005' WHERE name = 'English' AND school_id = '11111111-1111-1111-1111-111111111111';
UPDATE subjects SET teacher_id = '20000000-0000-0000-0000-000000000006' WHERE name = 'Computer Science' AND school_id = '11111111-1111-1111-1111-111111111111';