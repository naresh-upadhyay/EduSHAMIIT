-- ============================================================================
-- Migration: 246_sync_calendar_deletion_and_clean_orphans.sql
-- Description:
--   1. Clean up orphaned schedules whose parent calendar is soft-deleted
--   2. Add trigger to automatically cascade soft-deletion from calendars to schedules
--   3. Ensure consistency between calendar and schedules
-- ============================================================================

-- 1. Clean up existing orphaned schedules belonging to deleted calendars
UPDATE public.schedules
SET deleted_at = NOW(),
    updated_at = NOW()
WHERE calendar_id IN (
    SELECT id FROM public.calendars WHERE deleted_at IS NOT NULL
) AND deleted_at IS NULL;

-- 2. Trigger function to sync calendar deletion to schedules
CREATE OR REPLACE FUNCTION public.fn_trg_sync_calendar_deletion_to_schedules()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF NEW.deleted_at IS NOT NULL AND (OLD.deleted_at IS NULL OR OLD.deleted_at != NEW.deleted_at) THEN
        -- Soft delete all schedules belonging to this calendar
        UPDATE public.schedules
        SET deleted_at = NEW.deleted_at,
            updated_at = NOW()
        WHERE calendar_id = NEW.id
          AND deleted_at IS NULL;
    ELSIF NEW.deleted_at IS NULL AND OLD.deleted_at IS NOT NULL THEN
        -- Restore schedules if calendar is restored
        UPDATE public.schedules
        SET deleted_at = NULL,
            updated_at = NOW()
        WHERE calendar_id = NEW.id
          AND deleted_at = OLD.deleted_at;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_calendar_deletion_to_schedules ON public.calendars;
CREATE TRIGGER trg_sync_calendar_deletion_to_schedules
AFTER UPDATE OF deleted_at ON public.calendars
FOR EACH ROW
EXECUTE FUNCTION public.fn_trg_sync_calendar_deletion_to_schedules();

-- 3. Trigger for hard delete (if any)
CREATE OR REPLACE FUNCTION public.fn_trg_sync_calendar_hard_deletion()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    DELETE FROM public.schedules WHERE calendar_id = OLD.id;
    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_calendar_hard_deletion ON public.calendars;
CREATE TRIGGER trg_sync_calendar_hard_deletion
AFTER DELETE ON public.calendars
FOR EACH ROW
EXECUTE FUNCTION public.fn_trg_sync_calendar_hard_deletion();
