-- ============================================================================
-- Migration: 350_employee_onboarding_system.sql
-- Module: HR Management -> Onboarding Module (Production Ready)
-- Description: Complete schema enhancement for Employee Onboarding,
--              Onboarding Documents, Onboarding Tasks, Activity Logs,
--              Configurable Templates, and Data Seeding.
-- ============================================================================

-- 1. ENHANCE EMPLOYEE ONBOARDING TABLE
ALTER TABLE public.employee_onboarding
    ADD COLUMN IF NOT EXISTS onboarding_code TEXT,
    ADD COLUMN IF NOT EXISTS department TEXT DEFAULT 'Academics',
    ADD COLUMN IF NOT EXISTS designation TEXT DEFAULT 'Teacher',
    ADD COLUMN IF NOT EXISTS employment_type TEXT DEFAULT 'Full-time',
    ADD COLUMN IF NOT EXISTS stage TEXT DEFAULT 'Offer Accepted',
    ADD COLUMN IF NOT EXISTS expected_joining_date DATE,
    ADD COLUMN IF NOT EXISTS actual_joining_date DATE,
    ADD COLUMN IF NOT EXISTS reporting_time TEXT DEFAULT '09:00 AM',
    ADD COLUMN IF NOT EXISTS reporting_location TEXT DEFAULT 'Main Campus - HR Dept',
    ADD COLUMN IF NOT EXISTS reporting_manager_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS hr_owner_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS probation_period_months INT DEFAULT 6,
    ADD COLUMN IF NOT EXISTS work_location TEXT DEFAULT 'Main Campus',
    ADD COLUMN IF NOT EXISTS shift TEXT DEFAULT 'General Shift',
    ADD COLUMN IF NOT EXISTS joining_status TEXT DEFAULT 'Expected',
    ADD COLUMN IF NOT EXISTS reschedule_reason TEXT,
    ADD COLUMN IF NOT EXISTS no_show_reason TEXT,
    ADD COLUMN IF NOT EXISTS satisfaction_score NUMERIC(4, 1) DEFAULT 92.0,
    ADD COLUMN IF NOT EXISTS template_name TEXT DEFAULT 'General Staff',
    ADD COLUMN IF NOT EXISTS notes TEXT,
    ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS completion_override_reason TEXT;

-- Enforce stage check if not present
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_employee_onboarding_stage'
    ) THEN
        ALTER TABLE public.employee_onboarding
            ADD CONSTRAINT chk_employee_onboarding_stage
            CHECK (stage IN ('Offer Accepted', 'Document Collection', 'Orientation', 'IT Setup', 'Training', 'Completed', 'On Hold', 'Cancelled'));
    END IF;
END $$;

-- 2. ONBOARDING DOCUMENTS TABLE
CREATE TABLE IF NOT EXISTS public.onboarding_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    onboarding_id UUID NOT NULL REFERENCES public.employee_onboarding(id) ON DELETE CASCADE,
    document_name TEXT NOT NULL,
    required_for TEXT DEFAULT 'All Employees',
    is_mandatory BOOLEAN DEFAULT true,
    status TEXT DEFAULT 'Pending' CHECK (status IN ('Not Requested', 'Requested', 'Pending', 'Uploaded', 'Under Review', 'Verified', 'Rejected')),
    file_url TEXT,
    file_name TEXT,
    file_size_bytes BIGINT,
    uploaded_at TIMESTAMPTZ,
    verified_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    verified_at TIMESTAMPTZ,
    rejection_reason TEXT,
    remarks TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 3. ONBOARDING TASKS TABLE
CREATE TABLE IF NOT EXISTS public.onboarding_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    onboarding_id UUID NOT NULL REFERENCES public.employee_onboarding(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    category TEXT DEFAULT 'HR' CHECK (category IN ('HR', 'IT', 'Administration', 'Department', 'Security')),
    assigned_to_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    assigned_team TEXT DEFAULT 'HR Team',
    due_date DATE,
    priority TEXT DEFAULT 'Medium' CHECK (priority IN ('Low', 'Medium', 'High', 'Urgent')),
    status TEXT DEFAULT 'Pending' CHECK (status IN ('To Do', 'Pending', 'In Progress', 'Completed', 'Blocked', 'Cancelled', 'Overdue')),
    is_mandatory BOOLEAN DEFAULT true,
    completed_at TIMESTAMPTZ,
    completed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 4. ONBOARDING ACTIVITIES TABLE (AUDIT TRAIL)
CREATE TABLE IF NOT EXISTS public.onboarding_activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    onboarding_id UUID NOT NULL REFERENCES public.employee_onboarding(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    description TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 5. ONBOARDING TEMPLATES TABLE
CREATE TABLE IF NOT EXISTS public.onboarding_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    department TEXT DEFAULT 'General',
    description TEXT,
    default_tasks JSONB DEFAULT '[]'::jsonb,
    default_documents JSONB DEFAULT '[]'::jsonb,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 6. INDEXES FOR HIGH-SPEED QUERYING
CREATE INDEX IF NOT EXISTS idx_emp_onb_school_stage ON public.employee_onboarding(school_id, stage) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_emp_onb_school_status ON public.employee_onboarding(school_id, status) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_emp_onb_candidate ON public.employee_onboarding(school_id, candidate_id);
CREATE INDEX IF NOT EXISTS idx_emp_onb_dept ON public.employee_onboarding(school_id, department);
CREATE INDEX IF NOT EXISTS idx_onb_docs_onb ON public.onboarding_documents(onboarding_id, status);
CREATE INDEX IF NOT EXISTS idx_onb_tasks_onb ON public.onboarding_tasks(onboarding_id, status);
CREATE INDEX IF NOT EXISTS idx_onb_act_onb ON public.onboarding_activities(onboarding_id, created_at DESC);

-- 7. ENABLE ROW LEVEL SECURITY
ALTER TABLE public.employee_onboarding ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.onboarding_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.onboarding_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.onboarding_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.onboarding_templates ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'onboarding_tenant_isolation_emp') THEN
        CREATE POLICY onboarding_tenant_isolation_emp ON public.employee_onboarding
            FOR ALL USING (school_id = CURRENT_SETTING('app.current_school_id', true)::uuid);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'onboarding_tenant_isolation_docs') THEN
        CREATE POLICY onboarding_tenant_isolation_docs ON public.onboarding_documents
            FOR ALL USING (school_id = CURRENT_SETTING('app.current_school_id', true)::uuid);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'onboarding_tenant_isolation_tasks') THEN
        CREATE POLICY onboarding_tenant_isolation_tasks ON public.onboarding_tasks
            FOR ALL USING (school_id = CURRENT_SETTING('app.current_school_id', true)::uuid);
    END IF;
END $$;
