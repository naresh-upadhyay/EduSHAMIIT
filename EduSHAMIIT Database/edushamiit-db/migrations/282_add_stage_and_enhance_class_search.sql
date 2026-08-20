-- ============================================================================
-- Migration 282: Add Stage Filter & Enhance Class Search in fn_get_academic_classes
-- 1. Adds p_stage parameter to fn_get_academic_classes for server-side stage filtering.
-- 2. Enhances search query to match class name, code, and stage.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_get_academic_classes(
    p_school_id UUID,
    p_search VARCHAR DEFAULT '',
    p_academic_year VARCHAR DEFAULT '2026-27',
    p_status VARCHAR DEFAULT 'ALL',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_sort_by VARCHAR DEFAULT 'display_order',
    p_sort_order VARCHAR DEFAULT 'ASC',
    p_teacher_id UUID DEFAULT NULL,
    p_stage VARCHAR DEFAULT 'ALL'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_count INT := 0;
    v_offset INT := (GREATEST(p_page, 1) - 1) * p_page_size;
    v_classes JSONB := '[]'::JSONB;
BEGIN
    SELECT COUNT(*)
    INTO v_total_count
    FROM public.academic_classes c
    WHERE c.school_id = p_school_id 
      AND c.academic_year = p_academic_year
      AND (
          (p_status = 'ALL' AND c.deleted_at IS NULL)
          OR (p_status = 'ARCHIVED' AND (UPPER(TRIM(c.status)) = 'ARCHIVED' OR c.deleted_at IS NOT NULL))
          OR (p_status != 'ALL' AND UPPER(TRIM(c.status)) = UPPER(TRIM(p_status)) AND c.deleted_at IS NULL)
      )
      AND (
          p_stage = 'ALL' 
          OR c.stage ILIKE p_stage
      )
      AND (
          p_search = '' 
          OR c.name ILIKE '%' || p_search || '%' 
          OR c.code ILIKE '%' || p_search || '%'
          OR c.stage ILIKE '%' || p_search || '%'
      )
      AND (
          p_teacher_id IS NULL 
          OR EXISTS (
              SELECT 1 FROM public.class_teacher_assignments cta 
              WHERE cta.class_id = c.id AND cta.teacher_id = p_teacher_id
          )
          OR EXISTS (
              SELECT 1 FROM public.section_subject_teachers sst 
              WHERE sst.class_id = c.id AND sst.teacher_id = p_teacher_id
          )
      );

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', c.id,
                'name', c.name,
                'code', c.code,
                'stage', c.stage,
                'academic_year', c.academic_year,
                'display_order', c.display_order,
                'status', c.status,
                'sections_count', (SELECT COUNT(*) FROM public.academic_sections s WHERE s.class_id = c.id AND s.deleted_at IS NULL),
                'students_count', (SELECT COUNT(DISTINCT sca.student_id) FROM public.student_class_assignments sca WHERE sca.class_id = c.id AND sca.status = 'ACTIVE'),
                'subjects_count', (
                    SELECT COUNT(DISTINCT csa.subject_id)
                    FROM public.class_subject_assignments csa
                    JOIN public.academic_subjects sub ON sub.id = csa.subject_id
                    WHERE csa.class_id = c.id 
                      AND csa.school_id = p_school_id
                      AND sub.deleted_at IS NULL
                ),
                'class_teachers', (
                    SELECT COALESCE(
                        jsonb_agg(
                            jsonb_build_object(
                                'id', p.id,
                                'name', p.full_name,
                                'email', p.email,
                                'employee_id', p.employee_id,
                                'department', p.department,
                                'avatar_url', p.avatar_url,
                                'is_primary', cta.is_primary
                            )
                        ),
                        '[]'::JSONB
                    )
                    FROM public.class_teacher_assignments cta
                    JOIN public.profiles p ON p.id = cta.teacher_id
                    WHERE cta.class_id = c.id 
                      AND cta.section_id IS NULL
                      AND cta.academic_year = p_academic_year
                ),
                'sections', (
                    SELECT COALESCE(
                        jsonb_agg(
                            jsonb_build_object(
                                'id', s.id,
                                'name', s.name,
                                'code', s.code,
                                'capacity', s.capacity,
                                'room_number', s.room_number,
                                'room_id', s.room_id,
                                'status', s.status,
                                'students_count', (
                                    SELECT COUNT(DISTINCT sca.student_id) 
                                    FROM public.student_class_assignments sca 
                                    WHERE sca.section_id = s.id AND sca.status = 'ACTIVE'
                                )
                            )
                            ORDER BY s.name ASC
                        ),
                        '[]'::JSONB
                    )
                    FROM public.academic_sections s
                    WHERE s.class_id = c.id AND s.deleted_at IS NULL
                ),
                'created_at', c.created_at,
                'updated_at', c.updated_at
            )
        ),
        '[]'::JSONB
    ) INTO v_classes
    FROM (
        SELECT *
        FROM public.academic_classes c
        WHERE c.school_id = p_school_id 
          AND c.academic_year = p_academic_year
          AND (
              (p_status = 'ALL' AND c.deleted_at IS NULL)
              OR (p_status = 'ARCHIVED' AND (UPPER(TRIM(c.status)) = 'ARCHIVED' OR c.deleted_at IS NOT NULL))
              OR (p_status != 'ALL' AND UPPER(TRIM(c.status)) = UPPER(TRIM(p_status)) AND c.deleted_at IS NULL)
          )
          AND (
              p_stage = 'ALL' 
              OR c.stage ILIKE p_stage
          )
          AND (
              p_search = '' 
              OR c.name ILIKE '%' || p_search || '%' 
              OR c.code ILIKE '%' || p_search || '%'
              OR c.stage ILIKE '%' || p_search || '%'
          )
          AND (
              p_teacher_id IS NULL 
              OR EXISTS (
                  SELECT 1 FROM public.class_teacher_assignments cta 
                  WHERE cta.class_id = c.id AND cta.teacher_id = p_teacher_id
              )
              OR EXISTS (
                  SELECT 1 FROM public.section_subject_teachers sst 
                  WHERE sst.class_id = c.id AND sst.teacher_id = p_teacher_id
              )
          )
        ORDER BY 
            CASE WHEN p_sort_by = 'display_order' AND UPPER(p_sort_order) = 'ASC' THEN c.display_order END ASC,
            CASE WHEN p_sort_by = 'display_order' AND UPPER(p_sort_order) = 'DESC' THEN c.display_order END DESC,
            CASE WHEN p_sort_by = 'name' AND UPPER(p_sort_order) = 'ASC' THEN c.name END ASC,
            CASE WHEN p_sort_by = 'name' AND UPPER(p_sort_order) = 'DESC' THEN c.name END DESC,
            CASE WHEN p_sort_by = 'code' AND UPPER(p_sort_order) = 'ASC' THEN c.code END ASC,
            CASE WHEN p_sort_by = 'code' AND UPPER(p_sort_order) = 'DESC' THEN c.code END DESC,
            c.display_order ASC, c.name ASC
        LIMIT p_page_size
        OFFSET v_offset
    ) c;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'classes', v_classes,
            'total_count', v_total_count,
            'page', p_page,
            'page_size', p_page_size,
            'total_pages', CEIL(v_total_count::NUMERIC / GREATEST(p_page_size, 1)::NUMERIC)::INT
        )
    );
END;
$$;
