-- ============================================================================
-- Migration 285: Support Fetching Archived Class Detail in fn_get_academic_class_detail
-- Description:
-- 1. Removes the `AND deleted_at IS NULL` check in fn_get_academic_class_detail
--    so archived classes can be viewed by school admins in full detail.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_get_academic_class_detail(
    p_school_id UUID,
    p_class_id UUID,
    p_requesting_user_id UUID,
    p_requesting_role TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_class RECORD;
    v_sections JSONB := '[]'::JSONB;
    v_subjects JSONB := '[]'::JSONB;
    v_teachers JSONB := '[]'::JSONB;
    v_primary_teacher JSONB := NULL;
    v_students_count INT := 0;
    v_total_sections INT := 0;
    v_total_capacity INT := 0;
    v_core_subs INT := 0;
    v_opt_subs INT := 0;
    v_total_subs INT := 0;
    v_is_teacher_assigned BOOLEAN := FALSE;
BEGIN
    -- Validate School and Class existence (allow archived/soft-deleted classes for details inspection)
    SELECT * INTO v_class
    FROM public.academic_classes
    WHERE id = p_class_id AND school_id = p_school_id;

    IF v_class.id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Academic class not found', 'code', 404);
    END IF;

    -- Security check for Teacher role
    IF p_requesting_role = 'Teacher' THEN
        SELECT EXISTS(
            SELECT 1 FROM public.class_teacher_assignments
            WHERE class_id = p_class_id AND teacher_id = p_requesting_user_id
            UNION
            SELECT 1 FROM public.section_subject_teachers
            WHERE class_id = p_class_id AND teacher_id = p_requesting_user_id AND status = 'ACTIVE'
        ) INTO v_is_teacher_assigned;

        IF NOT v_is_teacher_assigned THEN
            RETURN jsonb_build_object('success', FALSE, 'error', 'Unauthorized: You are not assigned to this class', 'code', 403);
        END IF;
    END IF;

    -- Fetch Sections
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', s.id,
                'name', s.name,
                'code', s.code,
                'class_id', p_class_id,
                'class_name', v_class.name,
                'class_code', v_class.code,
                'capacity', s.capacity,
                'room_number', s.room_number,
                'status', s.status,
                'students_count', (
                    SELECT COUNT(DISTINCT sca.student_id) 
                    FROM public.student_class_assignments sca 
                    WHERE sca.section_id = s.id AND sca.status = 'ACTIVE'
                ),
                'class_teacher', (
                    SELECT jsonb_build_object(
                        'id', p.id,
                        'full_name', p.full_name,
                        'email', p.email,
                        'avatar_url', p.avatar_url,
                        'employee_id', p.employee_id,
                        'department', p.department
                    )
                    FROM public.class_teacher_assignments cta
                    JOIN public.profiles p ON p.id = cta.teacher_id
                    WHERE cta.section_id = s.id
                    ORDER BY cta.is_primary DESC, cta.created_at DESC
                    LIMIT 1
                ),
                'subjects_count', (
                    SELECT COUNT(DISTINCT csa.subject_id)
                    FROM public.class_subject_assignments csa
                    WHERE (csa.section_id = s.id OR (csa.class_id = p_class_id AND csa.section_id IS NULL))
                      AND csa.school_id = p_school_id
                )
            ) ORDER BY s.name ASC
        ),
        '[]'::JSONB
    ) INTO v_sections
    FROM public.academic_sections s
    WHERE s.class_id = p_class_id AND (v_class.status = 'ARCHIVED' OR s.deleted_at IS NULL);

    -- Fetch Subjects with assigned teachers and section metrics
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', s_agg.id,
                'name', s_agg.name,
                'code', s_agg.code,
                'type', s_agg.type,
                'description', s_agg.description,
                'status', s_agg.status,
                'color', s_agg.color,
                'icon', s_agg.icon,
                'is_optional', (s_agg.type ILIKE '%opt%' OR s_agg.type ILIKE '%elec%' OR s_agg.is_optional = TRUE),
                'section_names', s_agg.section_names,
                'assigned_sections_count', (
                    SELECT COUNT(DISTINCT sst.section_id)
                    FROM public.section_subject_teachers sst
                    WHERE sst.class_id = p_class_id 
                      AND sst.subject_id = s_agg.id
                      AND sst.status = 'ACTIVE'
                ),
                'assigned_teachers', (
                    SELECT COALESCE(
                        jsonb_agg(
                            jsonb_build_object(
                                'id', p.id,
                                'full_name', p.full_name,
                                'email', p.email,
                                'avatar_url', p.avatar_url,
                                'employee_id', p.employee_id,
                                'department', p.department,
                                'section_id', sst.section_id,
                                'section_name', sec.name
                            ) ORDER BY sec.name ASC, p.full_name ASC
                        ),
                        '[]'::JSONB
                    )
                    FROM public.section_subject_teachers sst
                    JOIN public.profiles p ON p.id = sst.teacher_id
                    LEFT JOIN public.academic_sections sec ON sec.id = sst.section_id
                    WHERE sst.class_id = p_class_id 
                      AND sst.subject_id = s_agg.id
                      AND sst.status = 'ACTIVE'
                )
            ) ORDER BY s_agg.name ASC
        ),
        '[]'::JSONB
    ) INTO v_subjects
    FROM (
        SELECT 
            sub.id,
            sub.name,
            sub.code,
            sub.type,
            sub.description,
            sub.status,
            sub.color,
            sub.icon,
            sub.is_optional,
            COALESCE(
                array_to_string(
                    array_agg(DISTINCT sec.name) FILTER (WHERE sec.name IS NOT NULL),
                    ', '
                ),
                'All Sections'
            ) AS section_names
        FROM public.class_subject_assignments csa
        JOIN public.academic_subjects sub ON sub.id = csa.subject_id
        LEFT JOIN public.academic_sections sec ON sec.id = csa.section_id
        WHERE csa.class_id = p_class_id 
          AND csa.school_id = p_school_id
          AND (v_class.status = 'ARCHIVED' OR sub.deleted_at IS NULL)
        GROUP BY sub.id, sub.name, sub.code, sub.type, sub.description, sub.status, sub.color, sub.icon, sub.is_optional
    ) s_agg;

    -- Fetch Teachers assigned to class or section
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', p.id,
                'full_name', p.full_name,
                'email', p.email,
                'avatar_url', p.avatar_url,
                'employee_id', p.employee_id,
                'department', p.department,
                'is_primary', cta.is_primary,
                'section_id', cta.section_id
            ) ORDER BY cta.is_primary DESC, cta.created_at ASC
        ),
        '[]'::JSONB
    ) INTO v_teachers
    FROM public.class_teacher_assignments cta
    JOIN public.profiles p ON p.id = cta.teacher_id
    WHERE cta.class_id = p_class_id;

    -- Primary class teacher (prioritizes section teacher when sections exist)
    SELECT jsonb_build_object(
        'id', p.id,
        'full_name', p.full_name,
        'email', p.email,
        'avatar_url', p.avatar_url,
        'employee_id', p.employee_id,
        'department', p.department,
        'is_primary', cta.is_primary
    ) INTO v_primary_teacher
    FROM public.class_teacher_assignments cta
    JOIN public.profiles p ON p.id = cta.teacher_id
    WHERE cta.class_id = p_class_id
    ORDER BY 
        (cta.section_id IS NOT NULL) DESC,
        cta.is_primary DESC, 
        cta.created_at DESC
    LIMIT 1;

    -- Aggregated Counts
    SELECT COUNT(DISTINCT student_id) INTO v_students_count
    FROM public.student_class_assignments
    WHERE class_id = p_class_id AND status = 'ACTIVE';

    SELECT COUNT(*), COALESCE(SUM(capacity), 0)
    INTO v_total_sections, v_total_capacity
    FROM public.academic_sections
    WHERE class_id = p_class_id AND (v_class.status = 'ARCHIVED' OR deleted_at IS NULL);

    SELECT 
        COUNT(DISTINCT CASE WHEN (sub.type ILIKE '%core%' OR sub.type IS NULL) THEN sub.id END),
        COUNT(DISTINCT CASE WHEN (sub.type ILIKE '%opt%' OR sub.type ILIKE '%elec%' OR sub.is_optional = TRUE) THEN sub.id END),
        COUNT(DISTINCT sub.id)
    INTO v_core_subs, v_opt_subs, v_total_subs
    FROM public.class_subject_assignments csa
    JOIN public.academic_subjects sub ON sub.id = csa.subject_id
    WHERE csa.class_id = p_class_id 
      AND csa.school_id = p_school_id
      AND (v_class.status = 'ARCHIVED' OR sub.deleted_at IS NULL);

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'id', v_class.id,
            'name', v_class.name,
            'code', v_class.code,
            'stage', v_class.stage,
            'academic_year', v_class.academic_year,
            'display_order', v_class.display_order,
            'status', v_class.status,
            'total_sections', v_total_sections,
            'total_students', v_students_count,
            'total_capacity', v_total_capacity,
            'core_subjects_count', v_core_subs,
            'optional_subjects_count', v_opt_subs,
            'total_subjects_count', v_total_subs,
            'class_teacher', v_primary_teacher,
            'sections', v_sections,
            'subjects', v_subjects,
            'teachers', v_teachers
        )
    );
END;
$$;
