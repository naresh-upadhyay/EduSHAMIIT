-- ============================================================================
-- Migration: 261_fix_class_level_schedule_assignments_and_summary.sql
-- Description:
--   1. Enhances fn_get_calendar_summary to correctly include schedules
--      assigned to user's class (e.g. 10A, Class 10A) and role in assigned_to_me
--      and summary counts.
--   2. Ensures schedule audience matching supports robust class normalization
--      (handling 'Class' prefixes, spaces, hyphens, and roman numerals).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_get_calendar_summary(
    p_school_id UUID,
    p_user_id UUID
) RETURNS JSONB AS $$
DECLARE
    v_today_count INT;
    v_week_count INT;
    v_now TIMESTAMPTZ := NOW();
    v_monday TIMESTAMPTZ := date_trunc('week', NOW());
    v_sunday TIMESTAMPTZ := v_monday + INTERVAL '6 days 23 hours 59 minutes 59 seconds';
    v_categories JSONB;
    v_assigned_to_me JSONB;
    v_pending_invitations JSONB;
    v_result JSONB;
    v_user_role TEXT := '';
    v_user_class TEXT := '';
    v_clean_user_class TEXT := '';
BEGIN
    -- Fetch user role and class for audience expansion
    SELECT COALESCE(role, ''), COALESCE(class, '')
    INTO v_user_role, v_user_class
    FROM public.profiles
    WHERE id = p_user_id;

    v_clean_user_class := replace(replace(replace(replace(lower(v_user_class), 'class', ''), 'grade', ''), ' ', ''), '-', '');
    v_clean_user_class := replace(replace(v_clean_user_class, 'x', '10'), 'ix', '9');

    -- 1. Today's schedules count (institution wide, created by me, or assigned to me/my role/my class)
    SELECT COUNT(DISTINCT s.id) INTO v_today_count
    FROM public.schedules s
    WHERE (s.school_id = p_school_id OR s.school_id IS NULL)
      AND s.deleted_at IS NULL
      AND s.status NOT IN ('cancelled', 'declined')
      AND DATE(s.start_time AT TIME ZONE COALESCE(NULLIF(s.timezone, ''), 'Asia/Kolkata')) = CURRENT_DATE
      AND (
          s.visibility = 'institution_wide'
          OR s.created_by = p_user_id
          OR s.organizer_id = p_user_id
          OR s.id IN (
              SELECT sp.schedule_id
              FROM public.schedule_participants sp
              WHERE sp.user_id = p_user_id
                 OR (sp.user_id IS NULL AND sp.target_role IS NOT NULL AND sp.target_role ILIKE '%' || v_user_role || '%')
                 OR (sp.user_id IS NULL AND sp.target_class IS NOT NULL AND v_user_class != '' AND (
                     sp.target_class ILIKE v_user_class
                     OR v_user_class ILIKE sp.target_class
                     OR replace(replace(replace(replace(lower(sp.target_class), 'class', ''), 'grade', ''), ' ', ''), '-', '') = replace(replace(replace(replace(lower(v_user_class), 'class', ''), 'grade', ''), ' ', ''), '-', '')
                     OR replace(replace(replace(replace(replace(replace(lower(sp.target_class), 'class', ''), 'grade', ''), ' ', ''), '-', ''), 'x', '10'), 'ix', '9') = v_clean_user_class
                 ))
          )
      );

    -- 2. This week's schedules count
    SELECT COUNT(DISTINCT s.id) INTO v_week_count
    FROM public.schedules s
    WHERE (s.school_id = p_school_id OR s.school_id IS NULL)
      AND s.deleted_at IS NULL
      AND s.status NOT IN ('cancelled', 'declined')
      AND s.start_time >= v_monday
      AND s.start_time <= v_sunday
      AND (
          s.visibility = 'institution_wide'
          OR s.created_by = p_user_id
          OR s.organizer_id = p_user_id
          OR s.id IN (
              SELECT sp.schedule_id
              FROM public.schedule_participants sp
              WHERE sp.user_id = p_user_id
                 OR (sp.user_id IS NULL AND sp.target_role IS NOT NULL AND sp.target_role ILIKE '%' || v_user_role || '%')
                 OR (sp.user_id IS NULL AND sp.target_class IS NOT NULL AND v_user_class != '' AND (
                     sp.target_class ILIKE v_user_class
                     OR v_user_class ILIKE sp.target_class
                     OR replace(replace(replace(replace(lower(sp.target_class), 'class', ''), 'grade', ''), ' ', ''), '-', '') = replace(replace(replace(replace(lower(v_user_class), 'class', ''), 'grade', ''), ' ', ''), '-', '')
                     OR replace(replace(replace(replace(replace(replace(lower(sp.target_class), 'class', ''), 'grade', ''), ' ', ''), '-', ''), 'x', '10'), 'ix', '9') = v_clean_user_class
                 ))
          )
      );

    -- 3. Category breakdown
    SELECT jsonb_object_agg(COALESCE(category, 'General'), count_val)
    INTO v_categories
    FROM (
        SELECT s.category, COUNT(DISTINCT s.id) AS count_val
        FROM public.schedules s
        WHERE (s.school_id = p_school_id OR s.school_id IS NULL)
          AND s.deleted_at IS NULL
          AND s.status NOT IN ('cancelled', 'declined')
          AND (
              s.visibility = 'institution_wide'
              OR s.created_by = p_user_id
              OR s.organizer_id = p_user_id
              OR s.id IN (
                  SELECT sp.schedule_id
                  FROM public.schedule_participants sp
                  WHERE sp.user_id = p_user_id
                     OR (sp.user_id IS NULL AND sp.target_role IS NOT NULL AND sp.target_role ILIKE '%' || v_user_role || '%')
                     OR (sp.user_id IS NULL AND sp.target_class IS NOT NULL AND v_user_class != '' AND (
                         sp.target_class ILIKE v_user_class
                         OR v_user_class ILIKE sp.target_class
                         OR replace(replace(replace(replace(lower(sp.target_class), 'class', ''), 'grade', ''), ' ', ''), '-', '') = replace(replace(replace(replace(lower(v_user_class), 'class', ''), 'grade', ''), ' ', ''), '-', '')
                         OR replace(replace(replace(replace(replace(replace(lower(sp.target_class), 'class', ''), 'grade', ''), ' ', ''), '-', ''), 'x', '10'), 'ix', '9') = v_clean_user_class
                     ))
              )
          )
        GROUP BY s.category
    ) sub;

    IF v_categories IS NULL THEN
        v_categories := '{"Meetings": 0, "Tasks": 0, "Events": 0, "Reminders": 0}'::jsonb;
    END IF;

    -- 4. Assigned to me & Pending invitations (including personal, role-based, and class-based assignments)
    SELECT jsonb_agg(sub.item)
    INTO v_assigned_to_me
    FROM (
        SELECT jsonb_build_object(
            'id', s.id,
            'title', s.title,
            'description', s.description,
            'schedule_type', s.schedule_type,
            'category', s.category,
            'color', s.color,
            'priority', s.priority,
            'status', s.status,
            'start_time', s.start_time,
            'end_time', s.end_time,
            'location_name', s.location_name,
            'room', s.room,
            'assigner_name', p.full_name,
            'rsvp_status', COALESCE(sp.rsvp_status, 'pending')
        ) AS item
        FROM public.schedules s
        LEFT JOIN public.profiles p ON p.id = s.created_by
        JOIN public.schedule_participants sp ON sp.schedule_id = s.id AND (
            sp.user_id = p_user_id
            OR (sp.user_id IS NULL AND sp.target_role IS NOT NULL AND sp.target_role ILIKE '%' || v_user_role || '%')
            OR (sp.user_id IS NULL AND sp.target_class IS NOT NULL AND v_user_class != '' AND (
                sp.target_class ILIKE v_user_class
                OR v_user_class ILIKE sp.target_class
                OR replace(replace(replace(replace(lower(sp.target_class), 'class', ''), 'grade', ''), ' ', ''), '-', '') = replace(replace(replace(replace(lower(v_user_class), 'class', ''), 'grade', ''), ' ', ''), '-', '')
                OR replace(replace(replace(replace(replace(replace(lower(sp.target_class), 'class', ''), 'grade', ''), ' ', ''), '-', ''), 'x', '10'), 'ix', '9') = v_clean_user_class
            ))
        )
        WHERE (s.school_id = p_school_id OR s.school_id IS NULL)
          AND s.deleted_at IS NULL
          AND s.status NOT IN ('cancelled', 'declined')
          AND s.end_time >= NOW()
        ORDER BY s.start_time ASC
        LIMIT 10
    ) sub;

    IF v_assigned_to_me IS NULL THEN
        v_assigned_to_me := '[]'::jsonb;
    END IF;

    SELECT jsonb_agg(elem)
    INTO v_pending_invitations
    FROM jsonb_array_elements(v_assigned_to_me) AS elem
    WHERE elem->>'rsvp_status' = 'pending';

    IF v_pending_invitations IS NULL THEN
        v_pending_invitations := '[]'::jsonb;
    END IF;

    v_result := jsonb_build_object(
        'today_count', v_today_count,
        'week_count', v_week_count,
        'categories', v_categories,
        'assigned_to_me', v_assigned_to_me,
        'pending_invitations', v_pending_invitations,
        'timezone', 'Asia/Kolkata (IST)'
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
