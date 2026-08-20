-- ============================================================================
-- Migration 283: Fix Class Detail Consistency & Section-Subject Teacher Assignments
-- 1. Updates fn_get_academic_class_detail to return accurate total_students,
--    total_capacity, total_sections, core_subjects_count, optional_subjects_count,
--    total_subjects_count, and real class_teacher.
-- 2. Integrates section_subject_teachers to provide live assigned_teachers and
--    assigned_sections_count for every subject in the class.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_get_academic_class_detail(
    p_school_id UUID,
    p_class_id UUID,
    p_teacher_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_class RECORD;
    v_sections JSONB;
    v_subjects JSONB;
    v_teachers JSONB;
    v_students_count INT := 0;
    v_total_capacity INT := 0;
    v_total_sections INT := 0;
    v_core_subs INT := 0;
    v_opt_subs INT := 0;
    v_total_subs INT := 0;
    v_is_assigned BOOLEAN := TRUE;
    v_primary_teacher JSONB := NULL;
BEGIN
    SELECT * INTO v_class
    FROM public.academic_classes
    WHERE id = p_class_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Class not found', 'code', 404);
    END IF;

    -- If teacher_id is provided, verify that the teacher is assigned to this class
    IF p_teacher_id IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1 FROM public.class_teacher_assignments cta
            WHERE cta.teacher_id = p_teacher_id
              AND cta.class_id = p_class_id
        ) INTO v_is_assigned;

        IF NOT v_is_assigned THEN
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
                    LIMIT 1
                ),
                'subjects_count', (
                    SELECT COUNT(DISTINCT csa.subject_id)
                    FROM public.class_subject_assignments csa
                    WHERE (csa.section_id = s.id OR (csa.class_id = p_class_id AND csa.section_id IS NULL))
                      AND csa.school_id = p_school_id
                ),
                'optional_subjects_count', (
                    SELECT COUNT(DISTINCT csa.subject_id)
                    FROM public.class_subject_assignments csa
                    JOIN public.academic_subjects sub ON sub.id = csa.subject_id
                    WHERE (csa.section_id = s.id OR (csa.class_id = p_class_id AND csa.section_id IS NULL))
                      AND sub.deleted_at IS NULL
                      AND (sub.type ILIKE '%opt%' OR sub.type ILIKE '%elec%' OR sub.is_optional = TRUE)
                ),
                'assigned_subject_ids', (
                    SELECT COALESCE(jsonb_agg(DISTINCT csa.subject_id), '[]'::JSONB)
                    FROM public.class_subject_assignments csa
                    WHERE (csa.section_id = s.id OR (csa.class_id = p_class_id AND csa.section_id IS NULL))
                      AND csa.school_id = p_school_id
                )
            ) ORDER BY s.display_order ASC, s.name ASC
        ),
        '[]'::JSONB
    ) INTO v_sections
    FROM public.academic_sections s
    WHERE s.class_id = p_class_id
      AND s.deleted_at IS NULL
      AND (
          p_teacher_id IS NULL
          OR EXISTS (
              SELECT 1 FROM public.class_teacher_assignments cta
              WHERE cta.teacher_id = p_teacher_id
                AND (cta.section_id = s.id OR (cta.class_id = s.class_id AND cta.section_id IS NULL))
          )
      );

    -- Fetch Subjects assigned to this class with live section_subject_teachers
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
                'is_class_wide', s_agg.is_class_wide,
                'section_names', s_agg.section_names,
                'section_count', s_agg.section_count,
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
                                'section_name', COALESCE(sec_t.name, 'All Sections')
                            ) ORDER BY sec_t.name ASC, p.full_name ASC
                        ),
                        '[]'::JSONB
                    )
                    FROM public.section_subject_teachers sst
                    JOIN public.profiles p ON p.id = sst.teacher_id
                    LEFT JOIN public.academic_sections sec_t ON sec_t.id = sst.section_id
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
            BOOL_OR(csa.section_id IS NULL) AS is_class_wide,
            CASE 
                WHEN BOOL_OR(csa.section_id IS NULL) THEN 'All Sections'
                ELSE COALESCE(string_agg(DISTINCT sec.name, ', ' ORDER BY sec.name), 'All Sections')
            END AS section_names,
            COUNT(DISTINCT csa.section_id) AS section_count
        FROM public.class_subject_assignments csa
        JOIN public.academic_subjects sub ON sub.id = csa.subject_id
        LEFT JOIN public.academic_sections sec ON sec.id = csa.section_id AND sec.deleted_at IS NULL
        WHERE csa.class_id = p_class_id 
          AND csa.school_id = p_school_id
          AND sub.deleted_at IS NULL
        GROUP BY sub.id, sub.name, sub.code, sub.type, sub.description, sub.status, sub.color, sub.icon
    ) s_agg;

    -- Fetch Teachers assigned directly to class
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', p.id,
                'full_name', p.full_name,
                'email', p.email,
                'avatar_url', p.avatar_url,
                'employee_id', p.employee_id,
                'department', p.department,
                'is_primary', cta.is_primary
            ) ORDER BY cta.is_primary DESC, cta.created_at ASC
        ),
        '[]'::JSONB
    ) INTO v_teachers
    FROM public.class_teacher_assignments cta
    JOIN public.profiles p ON p.id = cta.teacher_id
    WHERE cta.class_id = p_class_id AND cta.section_id IS NULL;

    -- Primary class teacher
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
    WHERE cta.class_id = p_class_id AND cta.section_id IS NULL
    ORDER BY cta.is_primary DESC, cta.created_at ASC
    LIMIT 1;

    -- Aggregated Counts
    SELECT COUNT(DISTINCT student_id) INTO v_students_count
    FROM public.student_class_assignments
    WHERE class_id = p_class_id AND status = 'ACTIVE';

    SELECT COUNT(*), COALESCE(SUM(capacity), 0)
    INTO v_total_sections, v_total_capacity
    FROM public.academic_sections
    WHERE class_id = p_class_id AND deleted_at IS NULL;

    SELECT 
        COUNT(DISTINCT CASE WHEN (sub.type ILIKE '%core%' OR sub.type IS NULL) THEN sub.id END),
        COUNT(DISTINCT CASE WHEN (sub.type ILIKE '%opt%' OR sub.type ILIKE '%elec%' OR sub.is_optional = TRUE) THEN sub.id END),
        COUNT(DISTINCT sub.id)
    INTO v_core_subs, v_opt_subs, v_total_subs
    FROM public.class_subject_assignments csa
    JOIN public.academic_subjects sub ON sub.id = csa.subject_id
    WHERE csa.class_id = p_class_id 
      AND csa.school_id = p_school_id
      AND sub.deleted_at IS NULL;

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
            'students_count', v_students_count,
            'total_students', v_students_count,
            'total_capacity', v_total_capacity,
            'total_sections', v_total_sections,
            'core_subjects_count', v_core_subs,
            'optional_subjects_count', v_opt_subs,
            'total_subjects_count', v_total_subs,
            'class_teacher', v_primary_teacher,
            'class_teachers', v_teachers,
            'sections', v_sections,
            'subjects', v_subjects,
            'created_at', v_class.created_at,
            'updated_at', v_class.updated_at
        )
    );
END;
$$;
