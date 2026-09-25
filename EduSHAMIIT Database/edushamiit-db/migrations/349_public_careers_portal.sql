-- ============================================================================
-- Migration: 349_public_careers_portal.sql
-- Module: HR Management -> Public Careers Portal Integration
-- Description: Extends recruitment_jobs and recruitment_applications tables
--              with public portal fields, slugs, work mode, featured flags,
--              application reference numbering, and duplicate protection.
-- ============================================================================

-- 1. Add public fields to recruitment_jobs
ALTER TABLE public.recruitment_jobs
ADD COLUMN IF NOT EXISTS is_public BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN IF NOT EXISTS slug TEXT,
ADD COLUMN IF NOT EXISTS work_mode TEXT NOT NULL DEFAULT 'On-site' CHECK (work_mode IN ('On-site', 'Hybrid', 'Remote')),
ADD COLUMN IF NOT EXISTS is_salary_public BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS is_openings_public BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN IF NOT EXISTS is_featured BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS custom_questions JSONB DEFAULT '[]'::jsonb;

-- Create unique index on school_id + slug for active jobs
CREATE UNIQUE INDEX IF NOT EXISTS uq_recruitment_jobs_slug
ON public.recruitment_jobs(school_id, slug)
WHERE is_deleted = false;

-- Create index on public job discovery queries
CREATE INDEX IF NOT EXISTS idx_recruitment_jobs_public_discovery
ON public.recruitment_jobs(school_id, is_public, publishing_status, application_deadline)
WHERE is_deleted = false;

-- Ensure Draft jobs can never be marked as public
ALTER TABLE public.recruitment_jobs
DROP CONSTRAINT IF EXISTS chk_recruitment_jobs_draft_not_public;

ALTER TABLE public.recruitment_jobs
ADD CONSTRAINT chk_recruitment_jobs_draft_not_public
CHECK (publishing_status != 'Draft' OR is_public = false);

-- 2. Add public application fields to recruitment_applications
ALTER TABLE public.recruitment_applications
ADD COLUMN IF NOT EXISTS application_reference TEXT,
ADD COLUMN IF NOT EXISTS custom_answers JSONB DEFAULT '{}'::jsonb,
ADD COLUMN IF NOT EXISTS cover_letter TEXT,
ADD COLUMN IF NOT EXISTS why_join_us TEXT,
ADD COLUMN IF NOT EXISTS linkedin_url TEXT,
ADD COLUMN IF NOT EXISTS portfolio_url TEXT,
ADD COLUMN IF NOT EXISTS work_mode_preference TEXT,
ADD COLUMN IF NOT EXISTS notice_period_days INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS current_salary NUMERIC(12, 2),
ADD COLUMN IF NOT EXISTS expected_salary NUMERIC(12, 2);

-- Unique constraint / index on application_reference
CREATE UNIQUE INDEX IF NOT EXISTS uq_recruitment_applications_ref
ON public.recruitment_applications(application_reference)
WHERE application_reference IS NOT NULL;

-- 3. Backfill slugs for existing jobs
UPDATE public.recruitment_jobs
SET slug = LOWER(REGEXP_REPLACE(job_title || '-' || SUBSTRING(id::text, 1, 8), '[^a-zA-Z0-9]+', '-', 'g'))
WHERE slug IS NULL;

-- Make sure slug is not null going forward
ALTER TABLE public.recruitment_jobs
ALTER COLUMN slug SET NOT NULL;

-- Mark select jobs as featured to match design screenshot
UPDATE public.recruitment_jobs
SET is_featured = true
WHERE job_title ILIKE '%Mathematics Teacher%'
   OR job_title ILIKE '%Marketing Coordinator%'
   OR job_title ILIKE '%Head of Chemistry%';

-- 4. Create sequence for application reference generation
CREATE SEQUENCE IF NOT EXISTS public.recruitment_app_ref_seq START WITH 101;

-- Backfill application_reference for existing applications
DO $$
DECLARE
    app_rec RECORD;
    seq_val INT := 101;
BEGIN
    FOR app_rec IN (SELECT id FROM public.recruitment_applications WHERE application_reference IS NULL ORDER BY created_at ASC) LOOP
        UPDATE public.recruitment_applications
        SET application_reference = 'APP-2026-' || LPAD(seq_val::text, 6, '0')
        WHERE id = app_rec.id;
        seq_val := seq_val + 1;
    END LOOP;
    PERFORM setval('public.recruitment_app_ref_seq', seq_val);
END $$;

