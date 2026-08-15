-- ============================================================================
-- EduSHAMIIT ERP - Migration 243: Fix Calendar Active Schedule Count in fn_delete_calendar
-- Description: Robust active schedule counting for fn_delete_calendar using
--              COUNT(DISTINCT COALESCE(recurring_parent_id, id)) to correctly
--              account for all active standalone schedules, recurring series,
--              and child override instances while ignoring soft-deleted and
--              cancelled/declined schedules.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_delete_calendar(
    p_calendar_id UUID,
    p_school_id UUID,
    p_user_id UUID,
    p_user_role TEXT DEFAULT 'admin'
) RETURNS JSONB AS $$
DECLARE
    v_cal public.calendars%ROWTYPE;
    v_sched_count INT;
    v_clean_role TEXT;
    v_is_authorized BOOLEAN := FALSE;
BEGIN
    v_clean_role := lower(replace(replace(COALESCE(p_user_role, ''), '_', ''), ' ', ''));

    -- 1. Check if calendar exists and is not deleted
    SELECT * INTO v_cal
    FROM public.calendars
    WHERE id = p_calendar_id
      AND (school_id = p_school_id OR school_id IS NULL)
      AND deleted_at IS NULL;

    IF v_cal.id IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Calendar not found or already deleted.',
            'code', 'CALENDAR_NOT_FOUND'
        );
    END IF;

    -- 2. Prevent deleting system or default calendars
    IF COALESCE(v_cal.is_system, FALSE) OR COALESCE(v_cal.is_default, FALSE) THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Core system or default calendars cannot be deleted.',
            'code', 'SYSTEM_CALENDAR'
        );
    END IF;

    -- 3. Verify user authorization (owner or admin)
    IF v_cal.owner_id = p_user_id OR v_clean_role IN ('superadmin', 'admin', 'owner', 'principal', 'director') THEN
        v_is_authorized := TRUE;
    ELSE
        SELECT EXISTS (
            SELECT 1 FROM public.calendar_members
            WHERE calendar_id = p_calendar_id AND user_id = p_user_id AND lower(permission) = 'manage_calendar'
        ) INTO v_is_authorized;
    END IF;

    IF NOT v_is_authorized THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Permission denied: You do not have manage permission for this calendar.',
            'code', 'PERMISSION_DENIED'
        );
    END IF;

    -- 4. Check active schedule count assigned to this calendar
    -- Uses COUNT(DISTINCT COALESCE(recurring_parent_id, id)) to count distinct schedule series/items
    SELECT COUNT(DISTINCT COALESCE(recurring_parent_id, id)) INTO v_sched_count
    FROM public.schedules
    WHERE calendar_id = p_calendar_id
      AND deleted_at IS NULL
      AND status NOT IN ('cancelled', 'declined');

    IF v_sched_count > 0 THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', FORMAT('Cannot delete calendar "%s" because it has %s active schedule(s) assigned. Please delete or reassign all schedules first.', v_cal.name, v_sched_count),
            'code', 'CALENDAR_HAS_SCHEDULES',
            'schedule_count', v_sched_count
        );
    END IF;

    -- 5. Perform soft deletion on calendar and any residual override/cancelled rows
    UPDATE public.schedules
    SET deleted_at = NOW(),
        updated_at = NOW()
    WHERE calendar_id = p_calendar_id
      AND deleted_at IS NULL;

    UPDATE public.calendars
    SET deleted_at = NOW(),
        updated_at = NOW()
    WHERE id = p_calendar_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', FORMAT('Calendar "%s" was deleted successfully.', v_cal.name),
        'deleted_calendar_id', p_calendar_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
