-- ============================================================================
-- EduSHAMIIT ERP - Migration 225: Recurrence Scopes, Overrides & Exceptions
-- Adds support for Google Calendar-grade recurrence exception handling:
-- 1. "This event only" (single occurrence override / exception date exclusion)
-- 2. "This and following events" (series split and cutoff adjustment)
-- 3. "All events" (full series update / delete)
-- ============================================================================

-- 1. Add recurring parent and instance tracking columns to schedules
ALTER TABLE public.schedules 
ADD COLUMN IF NOT EXISTS recurring_parent_id UUID REFERENCES public.schedules(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS original_instance_date DATE,
ADD COLUMN IF NOT EXISTS recurrence_exception_type VARCHAR(30) DEFAULT 'none';

-- 2. Ensure exceptions column in schedule_recurrence has proper GIN and JSONB defaults
ALTER TABLE public.schedule_recurrence
ALTER COLUMN exceptions SET DEFAULT '[]'::jsonb;

UPDATE public.schedule_recurrence
SET exceptions = '[]'::jsonb
WHERE exceptions IS NULL;

-- 3. Create high-performance indexing for parent-child schedule traversal
CREATE INDEX IF NOT EXISTS idx_schedules_recurring_parent 
ON public.schedules(recurring_parent_id) 
WHERE recurring_parent_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_schedules_orig_instance_date 
ON public.schedules(original_instance_date) 
WHERE original_instance_date IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_schedule_recurrence_exceptions 
ON public.schedule_recurrence USING GIN (exceptions);

-- 4. Stored procedure to exclude a single recurring occurrence
CREATE OR REPLACE FUNCTION public.exclude_recurring_occurrence(
    p_schedule_id UUID,
    p_instance_date DATE
) RETURNS VOID AS $$
BEGIN
    UPDATE public.schedule_recurrence
    SET exceptions = (
        SELECT jsonb_agg(DISTINCT elem)
        FROM (
            SELECT jsonb_array_elements_text(COALESCE(exceptions, '[]'::jsonb)) AS elem
            UNION
            SELECT p_instance_date::TEXT
        ) sub
    )
    WHERE schedule_id = p_schedule_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Stored procedure to split recurring series at given date
CREATE OR REPLACE FUNCTION public.split_recurring_series(
    p_schedule_id UUID,
    p_split_date DATE
) RETURNS VOID AS $$
BEGIN
    UPDATE public.schedule_recurrence
    SET end_type = 'until_date',
        end_date = (p_split_date - INTERVAL '1 day')::TIMESTAMP WITH TIME ZONE,
        updated_at = NOW()
    WHERE schedule_id = p_schedule_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
