-- ============================================================================
-- Migration: 355_hr_management_overview_and_refinements.sql
-- Module: HR Management -> Overview & Core Cross-Module Refinements
-- Description: Updates check constraints, adds compound performance indexes,
--              and optimizes queries for HR Overview command center.
-- ============================================================================

-- 1. FIX CHECK CONSTRAINT ON EMPLOYEE ONBOARDING STATUS
DO $$
BEGIN
    ALTER TABLE public.employee_onboarding
        DROP CONSTRAINT IF EXISTS employee_onboarding_status_check;
        
    ALTER TABLE public.employee_onboarding
        ADD CONSTRAINT employee_onboarding_status_check
        CHECK (status = ANY (ARRAY['Pending'::text, 'In Progress'::text, 'Completed'::text, 'On Hold'::text, 'Cancelled'::text]));
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Constraint update skipped or already applied: %', SQLERRM;
END $$;

-- 2. ENSURE OPTIMAL PERFORMANCE INDEXES FOR HR OVERVIEW & WORKFORCE QUERIES
CREATE INDEX IF NOT EXISTS idx_profiles_school_role_status
    ON public.profiles(school_id, role, status);

CREATE INDEX IF NOT EXISTS idx_profiles_school_dept
    ON public.profiles(school_id, department);

CREATE INDEX IF NOT EXISTS idx_recruitment_apps_school_stage
    ON public.recruitment_applications(school_id, current_stage)
    WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_recruitment_jobs_school_status
    ON public.recruitment_jobs(school_id, publishing_status)
    WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_recruitment_interviews_date_status
    ON public.recruitment_interviews(school_id, scheduled_date, status)
    WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_employee_onboarding_joining
    ON public.employee_onboarding(school_id, expected_joining_date, joining_status)
    WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_onboarding_tasks_pending
    ON public.onboarding_tasks(school_id, status, is_mandatory);

CREATE INDEX IF NOT EXISTS idx_onboarding_docs_status
    ON public.onboarding_documents(school_id, status, is_mandatory);

CREATE INDEX IF NOT EXISTS idx_hr_training_programs_school_status
    ON public.hr_training_programs(school_id, status);

CREATE INDEX IF NOT EXISTS idx_hr_training_sessions_school_date
    ON public.hr_training_sessions(school_id, session_date, status);

CREATE INDEX IF NOT EXISTS idx_hr_policies_school_status
    ON public.hr_policies(school_id, status)
    WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_hr_documents_school_expiring
    ON public.hr_documents(school_id, expiry_date, is_archived)
    WHERE expiry_date IS NOT NULL;
