-- ============================================================================
-- Migration: 358_hr_policy_reviewer_and_audience.sql
-- Module: HR Management -> Policies & Documents
-- Description: Add reviewer and audience tracking columns to hr_policies
--              and update audience type check constraint to include 'Role'.
-- ============================================================================

-- 1. Add reviewer and approval tracking columns
ALTER TABLE public.hr_policies
    ADD COLUMN IF NOT EXISTS reviewer_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS reviewer_name TEXT,
    ADD COLUMN IF NOT EXISTS reviewer_role TEXT,
    ADD COLUMN IF NOT EXISTS audience_target TEXT,
    ADD COLUMN IF NOT EXISTS submitted_for_review_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS approved_by_name TEXT;

-- 2. Update audience_type check constraint to permit 'Role' alongside 'Designation'
ALTER TABLE public.hr_policies DROP CONSTRAINT IF EXISTS hr_policies_audience_type_check;

ALTER TABLE public.hr_policies
    ADD CONSTRAINT hr_policies_audience_type_check CHECK (
        audience_type IN (
            'Entire Institute',
            'Specific Branch',
            'Department',
            'Role',
            'Designation',
            'Employment Type',
            'Selected Users'
        )
    );

-- 3. Create index for fast visibility querying (status, created_by, reviewer_id)
CREATE INDEX IF NOT EXISTS idx_hr_policies_visibility 
    ON public.hr_policies(school_id, status, created_by, reviewer_id);
