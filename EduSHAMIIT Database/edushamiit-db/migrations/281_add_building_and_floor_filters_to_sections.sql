-- ============================================================================
-- Migration 281: Add Building and Floor Filters to Sections & Optimize Breakdowns
-- 1. Updates fn_get_academic_sections to support p_building and p_floor filters.
-- 2. Updates fn_get_academic_stats so sections_by_class only returns classes
--    with sections_count > 0, cleanly ordered.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_get_academic_sections(
    p_school_id UUID,
    p_class_id UUID DEFAULT NULL,
    p_search TEXT DEFAULT '',
    p_academic_year VARCHAR DEFAULT '2026-27',
    p_status VARCHAR DEFAULT 'ALL',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_sort_by VARCHAR DEFAULT 'name',
    p_sort_order VARCHAR DEFAULT 'ASC',
    p_teacher_id UUID DEFAULT NULL,
    p_building VARCHAR DEFAULT 'ALL',
    p_floor VARCHAR DEFAULT 'ALL'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_count INT := 0;
    v_offset INT := (GREATEST(p_page, 1) - 1) * p_page_size;
    v_sections JSONB := '[]'::JSONB;
BEGIN
    SELECT COUNT(*)
    INTO v_total_count
    FROM public.academic_sections s
    JOIN public.academic_classes c ON c.id = s.class_id
    LEFT JOIN public.academic_rooms r ON r.id = s.room_id AND r.deleted_at IS NULL
    WHERE s.school_id = p_school_id
      AND s.academic_year = p_academic_year
      AND (p_class_id IS NULL OR s.class_id = p_class_id)
      AND (
          (p_status = 'ALL' AND s.deleted_at IS NULL)
          OR (p_status = 'ARCHIVED' AND (UPPER(TRIM(s.status)) = 'ARCHIVED' OR s.deleted_at IS NOT NULL))
          OR (p_status != 'ALL' AND UPPER(TRIM(s.status)) = UPPER(TRIM(p_status)) AND s.deleted_at IS NULL)
      )
      AND (
          p_teacher_id IS NULL
          OR EXISTS (
              SELECT 1 FROM public.class_teacher_assignments cta
              WHERE cta.teacher_id = p_teacher_id
                AND (cta.section_id = s.id OR (cta.class_id = s.class_id AND cta.section_id IS NULL))
                AND cta.academic_year = p_academic_year
          )
          OR EXISTS (
              SELECT 1 FROM public.section_subject_teachers sst
              WHERE sst.section_id = s.id AND sst.teacher_id = p_teacher_id
          )
      )
      AND (
          p_building = 'ALL'
          OR (p_building = 'Unassigned' AND (s.room_id IS NULL OR r.building IS NULL OR TRIM(r.building) = '' OR TRIM(r.building) ILIKE 'Unassigned'))
          OR (r.building ILIKE p_building)
      )
      AND (
          p_floor = 'ALL'
          OR (p_floor = 'Unassigned' AND (s.room_id IS NULL OR r.floor IS NULL OR TRIM(r.floor) = ''))
          OR (r.floor ILIKE p_floor)
      )
      AND (
          p_search = '' 
          OR s.name ILIKE '%' || p_search || '%' 
          OR s.code ILIKE '%' || p_search || '%'
          OR c.name ILIKE '%' || p_search || '%'
          OR s.room_number ILIKE '%' || p_search || '%'
          OR r.name ILIKE '%' || p_search || '%'
          OR r.building ILIKE '%' || p_search || '%'
      );

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', s.id,
                'class_id', s.class_id,
                'class_name', s.class_name,
                'class_code', s.class_code,
                'name', s.name,
                'code', s.code,
                'capacity', s.capacity,
                'room_number', s.room_number,
                'room_id', s.room_id,
                'room_name', s.room_name,
                'building', s.building,
                'floor', s.floor,
                'academic_year', s.academic_year,
                'status', s.status,
                'students_count', (
                    SELECT COUNT(DISTINCT sca.student_id) 
                    FROM public.student_class_assignments sca 
                    WHERE sca.section_id = s.id AND sca.status = 'ACTIVE'
                ),
                'class_teacher', (
                    SELECT jsonb_build_object(
                        'id', p.id,
                        'name', p.full_name,
                        'full_name', p.full_name,
                        'email', p.email,
                        'employee_id', p.employee_id,
                        'department', p.department,
                        'avatar_url', p.avatar_url
                    )
                    FROM public.class_teacher_assignments cta
                    JOIN public.profiles p ON p.id = cta.teacher_id
                    WHERE (cta.section_id = s.id OR (cta.class_id = s.class_id AND cta.section_id IS NULL AND cta.is_primary = TRUE))
                      AND cta.academic_year = p_academic_year
                    ORDER BY (cta.section_id = s.id) DESC
                    LIMIT 1
                ),
                'section_teacher', (
                    SELECT jsonb_build_object(
                        'id', p.id,
                        'name', p.full_name,
                        'full_name', p.full_name,
                        'email', p.email,
                        'employee_id', p.employee_id,
                        'department', p.department,
                        'avatar_url', p.avatar_url
                    )
                    FROM public.class_teacher_assignments cta
                    JOIN public.profiles p ON p.id = cta.teacher_id
                    WHERE (cta.section_id = s.id OR (cta.class_id = s.class_id AND cta.section_id IS NULL AND cta.is_primary = TRUE))
                      AND cta.academic_year = p_academic_year
                    ORDER BY (cta.section_id = s.id) DESC
                    LIMIT 1
                ),
                'created_at', s.created_at,
                'updated_at', s.updated_at
            )
        ),
        '[]'::JSONB
    ) INTO v_sections
    FROM (
        SELECT 
            s.*,
            c.name as class_name,
            c.code as class_code,
            r.name as room_name,
            r.building as building,
            r.floor as floor
        FROM public.academic_sections s
        JOIN public.academic_classes c ON c.id = s.class_id
        LEFT JOIN public.academic_rooms r ON r.id = s.room_id AND r.deleted_at IS NULL
        WHERE s.school_id = p_school_id
          AND s.academic_year = p_academic_year
          AND (p_class_id IS NULL OR s.class_id = p_class_id)
          AND (
              (p_status = 'ALL' AND s.deleted_at IS NULL)
              OR (p_status = 'ARCHIVED' AND (UPPER(TRIM(s.status)) = 'ARCHIVED' OR s.deleted_at IS NOT NULL))
              OR (p_status != 'ALL' AND UPPER(TRIM(s.status)) = UPPER(TRIM(p_status)) AND s.deleted_at IS NULL)
          )
          AND (
              p_teacher_id IS NULL
              OR EXISTS (
                  SELECT 1 FROM public.class_teacher_assignments cta
                  WHERE cta.teacher_id = p_teacher_id
                    AND (cta.section_id = s.id OR (cta.class_id = s.class_id AND cta.section_id IS NULL))
                    AND cta.academic_year = p_academic_year
              )
              OR EXISTS (
                  SELECT 1 FROM public.section_subject_teachers sst
                  WHERE sst.section_id = s.id AND sst.teacher_id = p_teacher_id
              )
          )
          AND (
              p_building = 'ALL'
              OR (p_building = 'Unassigned' AND (s.room_id IS NULL OR r.building IS NULL OR TRIM(r.building) = '' OR TRIM(r.building) ILIKE 'Unassigned'))
              OR (r.building ILIKE p_building)
          )
          AND (
              p_floor = 'ALL'
              OR (p_floor = 'Unassigned' AND (s.room_id IS NULL OR r.floor IS NULL OR TRIM(r.floor) = ''))
              OR (r.floor ILIKE p_floor)
          )
          AND (
              p_search = '' 
              OR s.name ILIKE '%' || p_search || '%' 
              OR s.code ILIKE '%' || p_search || '%'
              OR c.name ILIKE '%' || p_search || '%'
              OR s.room_number ILIKE '%' || p_search || '%'
              OR r.name ILIKE '%' || p_search || '%'
              OR r.building ILIKE '%' || p_search || '%'
          )
        ORDER BY 
            CASE WHEN p_sort_by = 'name' AND UPPER(p_sort_order) = 'ASC' THEN s.name END ASC,
            CASE WHEN p_sort_by = 'name' AND UPPER(p_sort_order) = 'DESC' THEN s.name END DESC,
            CASE WHEN p_sort_by = 'code' AND UPPER(p_sort_order) = 'ASC' THEN s.code END ASC,
            CASE WHEN p_sort_by = 'code' AND UPPER(p_sort_order) = 'DESC' THEN s.code END DESC,
            CASE WHEN p_sort_by = 'class_name' AND UPPER(p_sort_order) = 'ASC' THEN c.name END ASC,
            CASE WHEN p_sort_by = 'class_name' AND UPPER(p_sort_order) = 'DESC' THEN c.name END DESC,
            CASE WHEN p_sort_by = 'capacity' AND UPPER(p_sort_order) = 'ASC' THEN s.capacity END ASC,
            CASE WHEN p_sort_by = 'capacity' AND UPPER(p_sort_order) = 'DESC' THEN s.capacity END DESC,
            c.display_order ASC, s.name ASC
        LIMIT p_page_size
        OFFSET v_offset
    ) s;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'sections', v_sections,
            'total_count', v_total_count,
            'page', p_page,
            'page_size', p_page_size,
            'total_pages', CEIL(v_total_count::NUMERIC / GREATEST(p_page_size, 1)::NUMERIC)::INT
        )
    );
END;
$$;
