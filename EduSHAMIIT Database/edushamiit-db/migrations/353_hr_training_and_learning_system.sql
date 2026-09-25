-- Migration: 353_hr_training_and_learning_system.sql
-- Description: Enterprise HR Management -> Training & Learning System for EduSHAMIIT ERP
-- Multi-tenant schema supporting programs, learning paths, sessions, assignments, attendance, certificates, feedback, and audit activity.

-- 1. Dynamic Training Categories
CREATE TABLE IF NOT EXISTS public.hr_training_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    code TEXT NOT NULL,
    description TEXT,
    icon TEXT DEFAULT 'school_outlined',
    color_hex TEXT DEFAULT '#4F46E5',
    is_system BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    CONSTRAINT uq_hr_training_category UNIQUE (school_id, code)
);

CREATE INDEX IF NOT EXISTS idx_hr_training_categories_school ON public.hr_training_categories(school_id);

-- 2. Training Programs & Courses
CREATE TABLE IF NOT EXISTS public.hr_training_programs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    program_code TEXT NOT NULL,
    title TEXT NOT NULL,
    category_id UUID REFERENCES public.hr_training_categories(id) ON DELETE SET NULL,
    category_name TEXT,
    training_type TEXT DEFAULT 'Professional Development',
    description TEXT,
    is_mandatory BOOLEAN DEFAULT FALSE,
    trainer_type TEXT DEFAULT 'Internal', -- Internal, External
    trainer_name TEXT,
    trainer_id UUID,
    provider_name TEXT,
    target_audience TEXT DEFAULT 'All Staff',
    target_departments JSONB DEFAULT '[]'::jsonb,
    target_designations JSONB DEFAULT '[]'::jsonb,
    mode TEXT DEFAULT 'Online', -- Online, Offline, Hybrid, Workshop
    location_or_link TEXT,
    start_date DATE NOT NULL,
    end_date DATE,
    start_time TIME,
    end_time TIME,
    duration_hours NUMERIC(5,1) DEFAULT 2.0,
    duration_display TEXT DEFAULT '2 Hours',
    capacity INTEGER DEFAULT 50,
    enrolled_count INTEGER DEFAULT 0,
    completed_count INTEGER DEFAULT 0,
    completion_rate NUMERIC(5,2) DEFAULT 0.0,
    assessment_type TEXT DEFAULT 'None', -- None, Quiz, Assignment, Evaluation
    has_certificate BOOLEAN DEFAULT TRUE,
    certificate_validity_type TEXT DEFAULT 'Permanent',
    certificate_validity_months INTEGER DEFAULT 12,
    budget_cost NUMERIC(12,2) DEFAULT 0.0,
    budget_category TEXT,
    status TEXT DEFAULT 'UPCOMING', -- DRAFT, UPCOMING, IN_PROGRESS, COMPLETED, ARCHIVED, OVERDUE
    notes TEXT,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    CONSTRAINT uq_hr_training_program_code UNIQUE (school_id, program_code)
);

CREATE INDEX IF NOT EXISTS idx_hr_training_programs_school ON public.hr_training_programs(school_id);
CREATE INDEX IF NOT EXISTS idx_hr_training_programs_status ON public.hr_training_programs(school_id, status);
CREATE INDEX IF NOT EXISTS idx_hr_training_programs_dates ON public.hr_training_programs(school_id, start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_hr_training_programs_category ON public.hr_training_programs(school_id, category_name);

-- 3. Structured Learning Paths
CREATE TABLE IF NOT EXISTS public.hr_training_learning_paths (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    subtitle TEXT,
    icon TEXT DEFAULT 'school_outlined',
    color_hex TEXT DEFAULT '#4F46E5',
    target_audience TEXT,
    total_courses INTEGER DEFAULT 20,
    completed_courses INTEGER DEFAULT 15,
    progress_percentage INTEGER DEFAULT 75,
    enrolled_count INTEGER DEFAULT 0,
    status TEXT DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID
);

CREATE INDEX IF NOT EXISTS idx_hr_training_paths_school ON public.hr_training_learning_paths(school_id);

-- 4. Learning Path Course Mapping
CREATE TABLE IF NOT EXISTS public.hr_training_learning_path_courses (
    learning_path_id UUID NOT NULL REFERENCES public.hr_training_learning_paths(id) ON DELETE CASCADE,
    program_id UUID NOT NULL REFERENCES public.hr_training_programs(id) ON DELETE CASCADE,
    sequence_order INTEGER DEFAULT 1,
    PRIMARY KEY (learning_path_id, program_id)
);

-- 5. Training Sessions
CREATE TABLE IF NOT EXISTS public.hr_training_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    program_id UUID NOT NULL REFERENCES public.hr_training_programs(id) ON DELETE CASCADE,
    session_title TEXT NOT NULL,
    session_date DATE NOT NULL,
    start_time TIME,
    end_time TIME,
    time_display TEXT DEFAULT '10:00 AM - 12:00 PM',
    trainer_name TEXT,
    location_or_link TEXT,
    mode TEXT DEFAULT 'Offline',
    capacity INTEGER DEFAULT 50,
    enrolled_count INTEGER DEFAULT 0,
    attendance_count INTEGER DEFAULT 0,
    status TEXT DEFAULT 'Scheduled', -- Scheduled, Upcoming, In Progress, Completed, Cancelled
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID
);

CREATE INDEX IF NOT EXISTS idx_hr_training_sessions_prog ON public.hr_training_sessions(program_id);
CREATE INDEX IF NOT EXISTS idx_hr_training_sessions_school_date ON public.hr_training_sessions(school_id, session_date);

-- 6. Training Participants / Enrollments
CREATE TABLE IF NOT EXISTS public.hr_training_enrollments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    program_id UUID NOT NULL REFERENCES public.hr_training_programs(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL,
    employee_code TEXT,
    employee_name TEXT NOT NULL,
    employee_email TEXT,
    department TEXT,
    designation TEXT,
    avatar_url TEXT,
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    assigned_by UUID,
    assignment_source TEXT DEFAULT 'Manual', -- All, Department, Designation, Manual
    status TEXT DEFAULT 'Assigned', -- Assigned, Registered, In Progress, Completed, Failed, Overdue, Cancelled
    progress_pct NUMERIC(5,2) DEFAULT 0.0,
    attended_sessions_count INTEGER DEFAULT 0,
    assessment_score NUMERIC(5,2),
    assessment_status TEXT DEFAULT 'Pending', -- Pending, Passed, Failed, Exempt
    completed_at TIMESTAMPTZ,
    certificate_id UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_hr_training_enrollment UNIQUE (program_id, employee_id)
);

CREATE INDEX IF NOT EXISTS idx_hr_training_enroll_school ON public.hr_training_enrollments(school_id);
CREATE INDEX IF NOT EXISTS idx_hr_training_enroll_prog ON public.hr_training_enrollments(program_id);
CREATE INDEX IF NOT EXISTS idx_hr_training_enroll_emp ON public.hr_training_enrollments(employee_id);

-- 7. Training Attendance Records
CREATE TABLE IF NOT EXISTS public.hr_training_attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    session_id UUID NOT NULL REFERENCES public.hr_training_sessions(id) ON DELETE CASCADE,
    enrollment_id UUID NOT NULL REFERENCES public.hr_training_enrollments(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL,
    status TEXT NOT NULL DEFAULT 'Present', -- Present, Absent, Late, Excused
    check_in_time TIMESTAMPTZ,
    marked_by UUID,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_hr_training_session_attendance UNIQUE (session_id, employee_id)
);

CREATE INDEX IF NOT EXISTS idx_hr_training_att_session ON public.hr_training_attendance(session_id);
CREATE INDEX IF NOT EXISTS idx_hr_training_att_emp ON public.hr_training_attendance(employee_id);

-- 8. Training Materials & Documents
CREATE TABLE IF NOT EXISTS public.hr_training_materials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    program_id UUID NOT NULL REFERENCES public.hr_training_programs(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    material_type TEXT DEFAULT 'PDF', -- PDF, DOC, PPT, Video, Image, Link
    file_url TEXT NOT NULL,
    external_link TEXT,
    file_size_bytes BIGINT DEFAULT 0,
    file_size_display TEXT DEFAULT '1.5 MB',
    uploaded_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_hr_training_materials_prog ON public.hr_training_materials(program_id);

-- 9. Training Certificates
CREATE TABLE IF NOT EXISTS public.hr_training_certificates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    certificate_number TEXT NOT NULL,
    program_id UUID NOT NULL REFERENCES public.hr_training_programs(id) ON DELETE CASCADE,
    enrollment_id UUID REFERENCES public.hr_training_enrollments(id) ON DELETE SET NULL,
    employee_id UUID NOT NULL,
    employee_name TEXT NOT NULL,
    program_title TEXT NOT NULL,
    issue_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expiry_date DATE,
    status TEXT DEFAULT 'VALID', -- VALID, EXPIRING_SOON, EXPIRED, REVOKED
    certificate_url TEXT,
    issued_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_hr_training_cert_num UNIQUE (school_id, certificate_number)
);

CREATE INDEX IF NOT EXISTS idx_hr_training_certs_school ON public.hr_training_certificates(school_id);
CREATE INDEX IF NOT EXISTS idx_hr_training_certs_emp ON public.hr_training_certificates(employee_id);

-- 10. Training Feedback & Reviews
CREATE TABLE IF NOT EXISTS public.hr_training_feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    program_id UUID NOT NULL REFERENCES public.hr_training_programs(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL,
    employee_name TEXT,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    trainer_rating INTEGER CHECK (trainer_rating >= 1 AND trainer_rating <= 5),
    content_rating INTEGER CHECK (content_rating >= 1 AND content_rating <= 5),
    feedback_text TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_hr_training_feedback_prog ON public.hr_training_feedback(program_id);

-- 11. Training Needs & Skill Gaps
CREATE TABLE IF NOT EXISTS public.hr_training_skill_gaps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    department TEXT NOT NULL,
    designation TEXT DEFAULT 'All',
    skill_area TEXT NOT NULL,
    required_training_title TEXT NOT NULL,
    topic TEXT,
    required_proficiency TEXT DEFAULT 'Intermediate',
    current_proficiency TEXT DEFAULT 'Beginner',
    employees_count INTEGER DEFAULT 1,
    identified_employees_count INTEGER DEFAULT 1,
    urgency TEXT DEFAULT 'Medium', -- High, Medium, Low
    priority TEXT DEFAULT 'MEDIUM',
    status TEXT DEFAULT 'Identified', -- Identified, Training Created, Resolved
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_hr_training_gaps_school ON public.hr_training_skill_gaps(school_id);

-- 12. Training Activity & Audit Logs
CREATE TABLE IF NOT EXISTS public.hr_training_activity (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    entity_type TEXT NOT NULL, -- PROGRAM, SESSION, PARTICIPANT, CERTIFICATE, FEEDBACK, SKILL_GAP
    entity_id TEXT NOT NULL,
    action TEXT NOT NULL, -- Created, Updated, Published, Assigned, Attended, Completed, Certificate Issued
    summary TEXT,
    details TEXT,
    old_value JSONB DEFAULT '{}'::jsonb,
    new_value JSONB DEFAULT '{}'::jsonb,
    performed_by UUID,
    performer_name TEXT,
    performer_role TEXT,
    user_id UUID,
    user_name TEXT,
    user_role TEXT,
    ip_address TEXT,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_hr_training_activity_school ON public.hr_training_activity(school_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_hr_training_activity_entity ON public.hr_training_activity(entity_id);
