-- ============================================================================
-- Migration: 248_allow_custom_calendar_deletion_cascade.sql
-- Description:
--   1. Updates fn_delete_calendar to allow deleting any custom calendar
--      and automatically cascading soft-deletion to all its schedules.
--   2. Ensures vehicle_trips and resource_bookings are automatically cleaned up.
--   3. Keeps system/default calendars protected.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_delete_calendar(
    p_calendar_id UUID,
    p_school_id UUID,
    p_user_id UUID,
    p_user_role TEXT DEFAULT 'admin'
) RETURNS JSONB AS $$
DECLARE
    v_cal public.calendars%ROWTYPE;
    v_sched_count INT := 0;
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
            'error', FORMAT('Core system or default calendar "%s" cannot be deleted.', v_cal.name),
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
            'error', 'Permission denied: You do not have permission to delete this calendar.',
            'code', 'PERMISSION_DENIED'
        );
    END IF;

    -- 4. Count active schedules
    SELECT COUNT(*) INTO v_sched_count
    FROM public.schedules
    WHERE calendar_id = p_calendar_id
      AND deleted_at IS NULL;

    -- 5. Cascade soft delete to all schedules in this calendar
    UPDATE public.schedules
    SET deleted_at = NOW(),
        updated_at = NOW(),
        status = 'cancelled'
    WHERE calendar_id = p_calendar_id
      AND deleted_at IS NULL;

    -- 6. Delete associated vehicle_trips
    DELETE FROM public.vehicle_trips
    WHERE schedule_id IN (
        SELECT id FROM public.schedules WHERE calendar_id = p_calendar_id
    );

    -- 7. Release resource bookings
    UPDATE public.resource_bookings
    SET status = 'released'
    WHERE schedule_id IN (
        SELECT id FROM public.schedules WHERE calendar_id = p_calendar_id
    );

    -- 8. Soft delete the calendar
    UPDATE public.calendars
    SET deleted_at = NOW(),
        updated_at = NOW()
    WHERE id = p_calendar_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', FORMAT('Calendar "%s" and its %s schedule(s) were deleted successfully.', v_cal.name, v_sched_count),
        'deleted_calendar_id', p_calendar_id,
        'deleted_schedules_count', v_sched_count
    );
END;
$$ LANGUAGE plpgsql;
