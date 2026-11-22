-- ============================================================================
-- Migration: 555_add_live_classes_subject_id_fkey.sql
-- Description:
--   Add foreign key constraint from live_classes.subject_id to subjects.id
--   to enable PostgREST embedded joins and prevent PGRST200 schema cache failures.
-- ============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'live_classes_subject_id_fkey'
          AND table_name = 'live_classes'
    ) THEN
        ALTER TABLE public.live_classes
        ADD CONSTRAINT live_classes_subject_id_fkey
        FOREIGN KEY (subject_id) REFERENCES public.subjects(id) ON DELETE SET NULL;
    END IF;
END $$;

NOTIFY pgrst, 'reload schema';
