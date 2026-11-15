-- Migration 472: Work Management Bulk Role & Class/Section Assignment Engine
-- Enables assigning work items to individual users, all users of a role, or all students of a class & section

-- 1. Add assignment mode and target role columns to work_items
ALTER TABLE public.work_items
  ADD COLUMN IF NOT EXISTS target_role VARCHAR(50),
  ADD COLUMN IF NOT EXISTS assignment_mode VARCHAR(30) DEFAULT 'INDIVIDUAL';

-- 2. Stored Procedure to resolve target assignees dynamically
CREATE OR REPLACE FUNCTION public.sp_resolve_target_assignees(
    p_school_id UUID,
    p_assignment_mode VARCHAR,
    p_target_role VARCHAR DEFAULT NULL,
    p_class_id UUID DEFAULT NULL,
    p_class_name VARCHAR DEFAULT NULL,
    p_section_id UUID DEFAULT NULL,
    p_section_name VARCHAR DEFAULT NULL,
    p_department VARCHAR DEFAULT NULL,
    p_search_query VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    full_name VARCHAR,
    role VARCHAR,
    email VARCHAR,
    avatar_url TEXT,
    department VARCHAR,
    class_name VARCHAR,
    roll_number VARCHAR
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_clean_class VARCHAR;
    v_clean_sec VARCHAR;
BEGIN
    -- Extract clean number/code for class matching (e.g. 'Class 10' -> '10', 'Grade 10' -> '10')
    IF p_class_name IS NOT NULL THEN
        v_clean_class := TRIM(REGEXP_REPLACE(p_class_name, '^(Class|Grade)\s*', '', 'i'));
    END IF;

    IF p_section_name IS NOT NULL THEN
        v_clean_sec := TRIM(REGEXP_REPLACE(p_section_name, '^.*\s*-\s*', ''));
        IF v_clean_sec ILIKE '%All%' THEN
            v_clean_sec := NULL;
        END IF;
    END IF;

    IF UPPER(p_assignment_mode) = 'ROLE' THEN
        RETURN QUERY
        SELECT
            p.id,
            p.full_name::VARCHAR,
            p.role::VARCHAR,
            p.email::VARCHAR,
            p.avatar_url,
            p.department::VARCHAR,
            p.class::VARCHAR as class_name,
            p.roll_number::VARCHAR
        FROM public.profiles p
        WHERE p.school_id = p_school_id
          AND (p_target_role IS NULL OR p_target_role = 'All' OR LOWER(p.role) = LOWER(p_target_role))
          AND (p_department IS NULL OR p_department = 'All' OR p.department ILIKE '%' || p_department || '%')
          AND (
            p_search_query IS NULL 
            OR p.full_name ILIKE '%' || p_search_query || '%'
            OR p.email ILIKE '%' || p_search_query || '%'
            OR p.roll_number::TEXT ILIKE '%' || p_search_query || '%'
          )
        ORDER BY p.role ASC, p.full_name ASC;

    ELSIF UPPER(p_assignment_mode) = 'CLASS_SECTION' THEN
        RETURN QUERY
        SELECT DISTINCT
            p.id,
            p.full_name::VARCHAR,
            p.role::VARCHAR,
            p.email::VARCHAR,
            p.avatar_url,
            p.department::VARCHAR,
            COALESCE(p.class, p_class_name)::VARCHAR as class_name,
            p.roll_number::VARCHAR
        FROM public.profiles p
        WHERE p.school_id = p_school_id
          AND (
            -- Either matched via student_class_assignments
            p.id IN (
                SELECT sca.student_id 
                FROM public.student_class_assignments sca
                WHERE sca.school_id = p_school_id
                  AND (p_class_id IS NULL OR sca.class_id = p_class_id)
                  AND (p_section_id IS NULL OR sca.section_id = p_section_id)
            )
            -- Or matched via profiles.class text
            OR (
                (p_target_role IS NULL OR LOWER(p.role) = LOWER(p_target_role))
                AND (
                    (v_clean_class IS NOT NULL AND p.class ILIKE '%' || v_clean_class || '%')
                    OR (p_class_name IS NOT NULL AND p.class ILIKE '%' || p_class_name || '%')
                )
                AND (
                    v_clean_sec IS NULL 
                    OR p.class ILIKE '%' || v_clean_sec || '%'
                    OR (p_section_name IS NOT NULL AND p.class ILIKE '%' || p_section_name || '%')
                )
            )
          )
          AND (
            p_search_query IS NULL 
            OR p.full_name ILIKE '%' || p_search_query || '%'
            OR p.email ILIKE '%' || p_search_query || '%'
            OR p.roll_number::TEXT ILIKE '%' || p_search_query || '%'
          )
        ORDER BY 2 ASC;

    ELSE -- 'INDIVIDUAL'
        RETURN QUERY
        SELECT
            p.id,
            p.full_name::VARCHAR,
            p.role::VARCHAR,
            p.email::VARCHAR,
            p.avatar_url,
            p.department::VARCHAR,
            p.class::VARCHAR as class_name,
            p.roll_number::VARCHAR
        FROM public.profiles p
        WHERE p.school_id = p_school_id
          AND (p_target_role IS NULL OR p_target_role = 'All' OR LOWER(p.role) = LOWER(p_target_role))
          AND (p_department IS NULL OR p_department = 'All' OR p.department ILIKE '%' || p_department || '%')
          AND (
            p_search_query IS NULL 
            OR p.full_name ILIKE '%' || p_search_query || '%'
            OR p.email ILIKE '%' || p_search_query || '%'
            OR p.roll_number::TEXT ILIKE '%' || p_search_query || '%'
          )
        ORDER BY 
            CASE 
                WHEN LOWER(p.role) = 'admin' OR LOWER(p.role) = 'super_admin' THEN 1
                WHEN LOWER(p.role) = 'teacher' THEN 2
                WHEN LOWER(p.role) = 'staff' OR LOWER(p.role) = 'support' THEN 3
                WHEN LOWER(p.role) = 'student' THEN 4
                ELSE 5
            END,
            p.full_name ASC;
    END IF;
END;
$$;

-- 3. Enhanced sp_create_work_item with bulk role and class/section resolution
CREATE OR REPLACE FUNCTION public.sp_create_work_item(
    p_school_id UUID,
    p_board_id UUID,
    p_title VARCHAR,
    p_description TEXT,
    p_work_type VARCHAR,
    p_priority VARCHAR,
    p_status VARCHAR,
    p_category VARCHAR,
    p_parent_id UUID DEFAULT NULL,
    p_sprint_id UUID DEFAULT NULL,
    p_due_date DATE DEFAULT NULL,
    p_start_date DATE DEFAULT NULL,
    p_estimated_hours NUMERIC DEFAULT 0,
    p_story_points NUMERIC DEFAULT 0,
    p_assignee_ids UUID[] DEFAULT NULL,
    p_labels TEXT[] DEFAULT NULL,
    p_reporter_id UUID DEFAULT NULL,
    p_assignment_mode VARCHAR DEFAULT 'INDIVIDUAL',
    p_target_role VARCHAR DEFAULT NULL,
    p_class_id UUID DEFAULT NULL,
    p_section_id UUID DEFAULT NULL,
    p_subject_id UUID DEFAULT NULL,
    p_is_class_wide BOOLEAN DEFAULT FALSE,
    p_max_marks NUMERIC DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_item_id UUID := uuid_generate_v4();
    v_seq INT;
    v_prefix VARCHAR(10);
    v_item_number VARCHAR(30);
    v_uid UUID;
    v_lbl TEXT;
    v_actual_reporter UUID;
    v_resolved_assignees UUID[] := COALESCE(p_assignee_ids, '{}'::UUID[]);
    v_auto_count INT := 0;
BEGIN
    IF p_reporter_id IS NOT NULL AND EXISTS (SELECT 1 FROM public.profiles WHERE id = p_reporter_id) THEN
        v_actual_reporter := p_reporter_id;
    ELSE
        v_actual_reporter := NULL;
    END IF;

    -- Determine item prefix based on work_type
    IF UPPER(p_work_type) = 'EPIC' THEN
        v_prefix := 'EP';
    ELSIF UPPER(p_work_type) = 'STORY' THEN
        v_prefix := 'ST';
    ELSIF UPPER(p_work_type) = 'TASK' THEN
        v_prefix := 'TK';
    ELSIF UPPER(p_work_type) = 'BUG' THEN
        v_prefix := 'BUG';
    ELSE
        v_prefix := 'WM';
    END IF;

    SELECT COALESCE(MAX(SUBSTRING(item_number FROM '[0-9]+')::int), 1000) + 1 INTO v_seq
    FROM public.work_items
    WHERE school_id = p_school_id AND item_number LIKE v_prefix || '-%';

    v_item_number := v_prefix || '-' || v_seq::text;

    -- If no explicit assignees provided, auto-resolve based on mode
    IF array_length(v_resolved_assignees, 1) IS NULL OR array_length(v_resolved_assignees, 1) = 0 THEN
        IF UPPER(p_assignment_mode) = 'ROLE' AND p_target_role IS NOT NULL THEN
            SELECT array_agg(id) INTO v_resolved_assignees
            FROM public.profiles
            WHERE school_id = p_school_id AND LOWER(role) = LOWER(p_target_role);
        ELSIF UPPER(p_assignment_mode) = 'CLASS_SECTION' AND p_class_id IS NOT NULL THEN
            SELECT array_agg(id) INTO v_resolved_assignees
            FROM public.sp_resolve_target_assignees(
                p_school_id, 'CLASS_SECTION', COALESCE(p_target_role, 'student'),
                p_class_id, NULL, p_section_id, NULL, NULL, NULL
            );
        END IF;
    END IF;

    v_resolved_assignees := COALESCE(v_resolved_assignees, '{}'::UUID[]);
    v_auto_count := COALESCE(array_length(v_resolved_assignees, 1), 0);

    INSERT INTO public.work_items (
        id, school_id, board_id, sprint_id, item_number, title, description,
        work_type, priority, status, category, parent_id,
        estimated_hours, story_points, start_date, due_date,
        reporter_id, created_by, rank, created_at, updated_at,
        assignment_mode, target_role, class_id, section_id, subject_id,
        is_class_wide, max_marks
    ) VALUES (
        v_item_id, p_school_id, p_board_id, p_sprint_id, v_item_number, p_title, p_description,
        UPPER(p_work_type), UPPER(p_priority), UPPER(p_status), COALESCE(p_category, 'General'), p_parent_id,
        p_estimated_hours, p_story_points, p_start_date, p_due_date,
        v_actual_reporter, v_actual_reporter, (v_seq * 10)::numeric, NOW(), NOW(),
        UPPER(p_assignment_mode), p_target_role, p_class_id, p_section_id, p_subject_id,
        (p_is_class_wide OR UPPER(p_assignment_mode) = 'CLASS_SECTION'), p_max_marks
    );

    -- Insert assignees into public.work_item_assignees
    IF v_auto_count > 0 THEN
        FOREACH v_uid IN ARRAY v_resolved_assignees LOOP
            IF v_uid IS NOT NULL THEN
                INSERT INTO public.work_item_assignees (work_item_id, user_id, role_type)
                VALUES (v_item_id, v_uid, 'PRIMARY')
                ON CONFLICT DO NOTHING;
            END IF;
        END LOOP;
    END IF;

    -- Insert labels
    IF p_labels IS NOT NULL THEN
        FOREACH v_lbl IN ARRAY p_labels LOOP
            IF TRIM(v_lbl) <> '' THEN
                INSERT INTO public.work_item_labels (work_item_id, label)
                VALUES (v_item_id, TRIM(v_lbl))
                ON CONFLICT DO NOTHING;
            END IF;
        END LOOP;
    END IF;

    -- Log activity
    INSERT INTO public.work_item_activity_logs (
        work_item_id, school_id, actor_id, action_type, message
    ) VALUES (
        v_item_id, p_school_id, p_reporter_id, 'CREATED',
        'Created work item ' || v_item_number || 
        CASE 
            WHEN v_auto_count > 0 THEN ' and assigned to ' || v_auto_count || ' member(s)'
            ELSE ' without assignees'
        END
    );

    RETURN jsonb_build_object(
        'success', true,
        'item_id', v_item_id,
        'item_number', v_item_number,
        'title', p_title,
        'assignee_count', v_auto_count
    );
END;
$$;
