-- Expand role check constraint on profiles table to allow all 14 admin/staff roles
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_role_check CHECK (
  role IN (
    'student', 
    'parent', 
    'teacher', 
    'admin', 
    'student_admin', 
    'teacher_admin',
    'super_admin', 
    'director', 
    'principal', 
    'finance', 
    'hr', 
    'transport', 
    'library', 
    'security', 
    'sports', 
    'support', 
    'driver', 
    'hostel', 
    'exam_ctrl'
  )
);
