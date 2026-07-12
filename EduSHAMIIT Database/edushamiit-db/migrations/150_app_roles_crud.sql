-- Database migration: 150_app_roles_crud.sql
-- Create App Roles Schema & Seed Standard Roles

-- 1. Create App Roles Table
CREATE TABLE IF NOT EXISTS public.app_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    permissions TEXT[] NOT NULL DEFAULT '{}'::text[],
    is_custom BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now())
);

-- Enable RLS and permissions
ALTER TABLE public.app_roles ENABLE ROW LEVEL SECURITY;
GRANT ALL ON public.app_roles TO anon, authenticated, service_role;
CREATE POLICY "Allow read/write access for all on app_roles" ON public.app_roles FOR ALL USING (true) WITH CHECK (true);

-- Seed standard roles
INSERT INTO public.app_roles (name, description, permissions, is_custom) VALUES
('student', 'Standard student role with access to courses and assignments', ARRAY['view_courses', 'submit_assignments'], false),
('parent', 'Parent/guardian role to monitor student performance', ARRAY['view_grades', 'view_attendance'], false),
('teacher', 'Teacher role to manage classes, grades, and schedules', ARRAY['view_courses', 'grade_assignments', 'manage_classes'], false),
('admin', 'General school administrator', ARRAY['manage_users', 'view_reports'], false),
('student_admin', 'Administrator for managing student directory and admissions', ARRAY['manage_users', 'manage_admissions'], false),
('teacher_admin', 'Administrator for managing teacher profiles and class assignments', ARRAY['manage_users', 'manage_classes'], false),
('super_admin', 'Global system administrator with infrastructure and role controls', ARRAY['manage_users', 'manage_infra', 'manage_roles', 'view_reports'], false),
('director', 'School director with oversight metrics', ARRAY['view_reports'], false),
('principal', 'Principal role with academic oversight', ARRAY['view_reports', 'manage_classes'], false),
('finance', 'Financial officer with payroll and fee collection access', ARRAY['manage_finance', 'view_reports'], false),
('hr', 'Human resources manager for staff and payroll policies', ARRAY['manage_staff', 'manage_payroll'], false),
('transport', 'Transportation administrator', ARRAY['manage_transport'], false),
('library', 'Librarian role for book tracking', ARRAY['manage_library'], false),
('security', 'Campus security officer', ARRAY['view_logs'], false),
('sports', 'Sports department administrator', ARRAY['manage_sports'], false),
('support', 'IT support staff', ARRAY['view_logs', 'manage_support'], false),
('driver', 'Bus/vehicle driver', ARRAY['view_transport'], false),
('hostel', 'Hostel/dormitory warden', ARRAY['manage_hostel'], false),
('exam_ctrl', 'Exam controller for assessments and scheduling', ARRAY['manage_exams'], false)
ON CONFLICT (name) DO NOTHING;

-- Drop profiles check constraint
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;

-- Add foreign key constraint to profiles referencing unique app_roles(name)
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_fkey;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_fkey FOREIGN KEY (role) REFERENCES public.app_roles(name) ON UPDATE CASCADE;
