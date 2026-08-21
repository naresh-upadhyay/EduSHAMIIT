-- ============================================================================
-- Migration: 293_role_hierarchy_system_and_relationships.sql
-- Description: Sets up Role Hierarchy schema and canonical parent-child relations.
-- ============================================================================

-- 1. Hierarchy columns in app_roles
ALTER TABLE public.app_roles
ADD COLUMN IF NOT EXISTS display_name VARCHAR(150),
ADD COLUMN IF NOT EXISTS parent_role_id UUID REFERENCES public.app_roles(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS level INT DEFAULT 1,
ADD COLUMN IF NOT EXISTS role_type VARCHAR(30) DEFAULT 'SYSTEM',
ADD COLUMN IF NOT EXISTS inherit_permissions BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS display_order INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

-- 2. Indexes
CREATE INDEX IF NOT EXISTS idx_app_roles_parent ON public.app_roles (parent_role_id);
CREATE INDEX IF NOT EXISTS idx_app_roles_level ON public.app_roles (level);
CREATE INDEX IF NOT EXISTS idx_app_roles_school_id ON public.app_roles (school_id);
CREATE INDEX IF NOT EXISTS idx_app_roles_role_type ON public.app_roles (role_type);

-- 3. Upsert specialized roles that might not exist yet
INSERT INTO public.app_roles (name, display_name, code, description, is_custom, role_type, level, status, permissions)
VALUES
('class_teacher', 'Class Teacher', 'CLASS_TEACHER', 'Designated class teacher managing classroom attendance and students', true, 'CUSTOM', 4, 'Active', ARRAY['view_courses', 'grade_assignments', 'view_attendance', 'manage_classes']),
('subject_teacher', 'Subject Teacher', 'SUBJECT_TEACHER', 'Subject instructor delivering curriculum lectures and assignments', true, 'CUSTOM', 4, 'Active', ARRAY['view_courses', 'grade_assignments']),
('student_self', 'Student (Self)', 'STUDENT_SELF', 'Student self portal for courses and assignment submissions', true, 'CUSTOM', 4, 'Active', ARRAY['view_courses', 'submit_assignments', 'view_grades', 'view_attendance'])
ON CONFLICT (name) DO NOTHING;

-- 4. Establish exact parent-child hierarchy linkages
DO $$
DECLARE
    v_super_id UUID;
    v_admin_id UUID;
    v_principal_id UUID;
    v_teacher_id UUID;
    v_student_id UUID;
    v_transport_id UUID;
BEGIN
    SELECT id INTO v_super_id FROM public.app_roles WHERE name = 'super_admin';
    SELECT id INTO v_admin_id FROM public.app_roles WHERE name = 'admin';
    SELECT id INTO v_principal_id FROM public.app_roles WHERE name = 'principal';
    SELECT id INTO v_teacher_id FROM public.app_roles WHERE name = 'teacher';
    SELECT id INTO v_student_id FROM public.app_roles WHERE name = 'student';
    SELECT id INTO v_transport_id FROM public.app_roles WHERE name = 'transport';

    -- Level 1: Super Admin
    UPDATE public.app_roles
    SET level = 1, parent_role_id = NULL, role_type = 'SYSTEM', display_name = 'Super Admin', code = 'SUPER_ADMIN', description = 'Full system access with all platform permissions'
    WHERE name = 'super_admin';

    -- Level 2: Institution Admin & Academic Admin (under Super Admin)
    UPDATE public.app_roles
    SET level = 2, parent_role_id = v_super_id, role_type = 'SYSTEM', display_name = 'Institution Admin', code = 'INSTITUTION_ADMIN', description = 'Institutional administrator managing school operations and staff'
    WHERE name = 'admin';

    UPDATE public.app_roles
    SET level = 2, parent_role_id = v_super_id, role_type = 'SYSTEM', display_name = 'Academic Admin', code = 'ACADEMIC_ADMIN', description = 'Academic administrator supervising curriculum, teachers, and exams'
    WHERE name = 'principal';

    UPDATE public.app_roles
    SET level = 2, parent_role_id = v_super_id, role_type = 'SYSTEM', display_name = 'Director', code = 'DIRECTOR', description = 'Institutional executive director overseeing campus institutions'
    WHERE name = 'director';

    -- Level 3: Under Institution Admin (Teacher, Finance, HR, Transport, Hostel, Security)
    UPDATE public.app_roles
    SET level = 3, parent_role_id = v_admin_id, role_type = 'SYSTEM', display_name = 'Teacher', code = 'TEACHER', description = 'Academic educator delivering curriculum and evaluations'
    WHERE name = 'teacher';

    UPDATE public.app_roles
    SET level = 3, parent_role_id = v_admin_id, role_type = 'CUSTOM', display_name = 'Accountant', code = 'ACCOUNTANT', description = 'Financial accountant managing fees, billing, and accounting'
    WHERE name = 'finance';

    UPDATE public.app_roles
    SET level = 3, parent_role_id = v_admin_id, role_type = 'CUSTOM', display_name = 'HR Manager', code = 'HR_MANAGER', description = 'HR manager managing staff payroll and recruitments'
    WHERE name = 'hr';

    UPDATE public.app_roles
    SET level = 3, parent_role_id = v_admin_id, role_type = 'CUSTOM', display_name = 'Transport Manager', code = 'TRANSPORT_MANAGER', description = 'Transport manager coordinating bus routes and fleet'
    WHERE name = 'transport';

    UPDATE public.app_roles
    SET level = 3, parent_role_id = v_admin_id, role_type = 'CUSTOM', display_name = 'Hostel Warden', code = 'HOSTEL_WARDEN', description = 'Hostel warden managing student boarding and accommodations'
    WHERE name = 'hostel';

    UPDATE public.app_roles
    SET level = 3, parent_role_id = v_admin_id, role_type = 'CUSTOM', display_name = 'Campus Security', code = 'CAMPUS_SECURITY', description = 'Campus security chief managing physical safety and logs'
    WHERE name = 'security';

    -- Level 3: Under Academic Admin (Library, Student, Front Office / Support, Exam Controller)
    UPDATE public.app_roles
    SET level = 3, parent_role_id = v_principal_id, role_type = 'CUSTOM', display_name = 'Librarian', code = 'LIBRARIAN', description = 'Head librarian managing catalog, book borrowings, and digital media'
    WHERE name = 'library';

    UPDATE public.app_roles
    SET level = 3, parent_role_id = v_principal_id, role_type = 'SYSTEM', display_name = 'Student', code = 'STUDENT', description = 'Student enrolled in active classes and exams'
    WHERE name = 'student';

    UPDATE public.app_roles
    SET level = 3, parent_role_id = v_principal_id, role_type = 'CUSTOM', display_name = 'Front Office', code = 'FRONT_OFFICE', description = 'Front office desk managing inquiries and admissions visitor log'
    WHERE name = 'support';

    UPDATE public.app_roles
    SET level = 3, parent_role_id = v_principal_id, role_type = 'CUSTOM', display_name = 'Examination Controller', code = 'EXAM_CTRL', description = 'Examination controller handling grade approvals and schedules'
    WHERE name = 'exam_ctrl';

    -- Level 4: Under Teacher (Class Teacher, Subject Teacher, Sports)
    UPDATE public.app_roles
    SET level = 4, parent_role_id = v_teacher_id, role_type = 'CUSTOM', display_name = 'Class Teacher', code = 'CLASS_TEACHER', description = 'Assigned class teacher managing daily section registers'
    WHERE name = 'class_teacher';

    UPDATE public.app_roles
    SET level = 4, parent_role_id = v_teacher_id, role_type = 'CUSTOM', display_name = 'Subject Teacher', code = 'SUBJECT_TEACHER', description = 'Subject teacher managing specific subject lectures and grades'
    WHERE name = 'subject_teacher';

    UPDATE public.app_roles
    SET level = 4, parent_role_id = v_teacher_id, role_type = 'CUSTOM', display_name = 'Sports Coach', code = 'SPORTS_COACH', description = 'Sports instructor managing athletic training and sports teams'
    WHERE name = 'sports';

    -- Level 4: Under Student (Parent, Student Self)
    UPDATE public.app_roles
    SET level = 4, parent_role_id = v_student_id, role_type = 'CUSTOM', display_name = 'Student (Parent)', code = 'STUDENT_PARENT', description = 'Guardian portal for tracking student attendance and results'
    WHERE name = 'parent';

    UPDATE public.app_roles
    SET level = 4, parent_role_id = v_student_id, role_type = 'CUSTOM', display_name = 'Student (Self)', code = 'STUDENT_SELF', description = 'Student direct access for online submissions and coursework'
    WHERE name = 'student_self';

    -- Level 4: Under Transport (Driver)
    UPDATE public.app_roles
    SET level = 4, parent_role_id = v_transport_id, role_type = 'CUSTOM', display_name = 'Driver', code = 'DRIVER', description = 'School bus driver managing bus route pickups and dropoffs'
    WHERE name = 'driver';

    -- Owner
    UPDATE public.app_roles
    SET level = 1, parent_role_id = NULL, role_type = 'SYSTEM', display_name = 'Owner', code = 'OWNER', description = 'School system owner with full tenant control'
    WHERE name = 'owner';
END $$;
