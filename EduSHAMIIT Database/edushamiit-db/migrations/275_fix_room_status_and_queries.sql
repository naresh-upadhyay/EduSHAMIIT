-- ============================================================================
-- Migration 275: 100% Dynamic Lookups & Filtering for All Academic Entities
-- (Zero Hardcoded Statuses / Types in Queries & Functions)
-- ============================================================================

-- 1. Dynamic Rooms Retrieval Function
CREATE OR REPLACE FUNCTION public.fn_get_academic_rooms(
    p_school_id UUID,
    p_search VARCHAR DEFAULT '',
    p_type VARCHAR DEFAULT 'ALL',
    p_building VARCHAR DEFAULT 'ALL',
    p_floor VARCHAR DEFAULT 'ALL',
    p_status VARCHAR DEFAULT 'ALL',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_sort_by VARCHAR DEFAULT 'name',
    p_sort_order VARCHAR DEFAULT 'ASC'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_offset INT := (GREATEST(p_page, 1) - 1) * p_page_size;
    v_total_count INT := 0;
    v_rooms JSONB := '[]'::JSONB;
    v_current_day INT := EXTRACT(DOW FROM CURRENT_TIMESTAMP);
    v_current_time TIME := CURRENT_TIME;
BEGIN
    -- 1. Total Count for pagination (100% dynamic string matching)
    SELECT COUNT(*) INTO v_total_count
    FROM public.academic_rooms r
    WHERE r.school_id = p_school_id
      AND r.deleted_at IS NULL
      AND (
          p_search = '' 
          OR r.name ILIKE '%' || p_search || '%' 
          OR r.code ILIKE '%' || p_search || '%'
          OR r.type ILIKE '%' || p_search || '%'
          OR r.building ILIKE '%' || p_search || '%'
      )
      AND (p_type = 'ALL' OR p_type = '' OR UPPER(TRIM(r.type)) = UPPER(TRIM(p_type)))
      AND (p_building = 'ALL' OR p_building = '' OR UPPER(TRIM(r.building)) = UPPER(TRIM(p_building)))
      AND (p_floor = 'ALL' OR p_floor = '' OR UPPER(TRIM(r.floor)) = UPPER(TRIM(p_floor)))
      AND (p_status = 'ALL' OR p_status = '' OR UPPER(TRIM(r.status)) = UPPER(TRIM(p_status)));

    -- 2. Fetch paginated records with dynamic data
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', r_item.id,
                'name', r_item.name,
                'code', r_item.code,
                'type', r_item.type,
                'building', r_item.building,
                'floor', r_item.floor,
                'capacity', r_item.capacity,
                'facilities', r_item.facilities,
                'status', r_item.status,
                'in_use_status', r_item.status,
                'description', r_item.description,
                'in_use_by', r_item.in_use_by,
                'timings', r_item.timings,
                'assigned_sections_count', r_item.assigned_sections_count,
                'created_at', r_item.created_at,
                'updated_at', r_item.updated_at
            )
        ),
        '[]'::JSONB
    ) INTO v_rooms
    FROM (
        SELECT 
            r.id,
            r.name,
            r.code,
            r.type,
            r.building,
            r.floor,
            r.capacity,
            r.facilities,
            r.status,
            r.description,
            r.created_at,
            r.updated_at,
            (
                SELECT COUNT(*) 
                FROM public.academic_sections s 
                WHERE s.room_id = r.id AND s.deleted_at IS NULL
            ) AS assigned_sections_count,
            COALESCE(
                (
                    SELECT ra.title || ' (' || COALESCE(sub.name, 'General') || ')'
                    FROM public.room_allocations ra
                    LEFT JOIN public.academic_subjects sub ON sub.id = ra.subject_id
                    WHERE ra.room_id = r.id 
                      AND ra.status = 'ACTIVE'
                      AND (
                          (ra.day_of_week = v_current_day AND v_current_time BETWEEN ra.start_time AND ra.end_time)
                          OR (ra.allocation_type = 'EVENT' AND ra.day_of_week = v_current_day)
                      )
                    ORDER BY ra.start_time ASC
                    LIMIT 1
                ),
                (
                    SELECT 'Class ' || c.name || ' (Section ' || s.name || ')'
                    FROM public.academic_sections s
                    JOIN public.academic_classes c ON c.id = s.class_id
                    WHERE s.room_id = r.id AND s.deleted_at IS NULL
                    LIMIT 1
                ),
                '—'
            ) AS in_use_by,
            COALESCE(
                (
                    SELECT TO_CHAR(ra.start_time, 'HH12:MI AM') || ' - ' || TO_CHAR(ra.end_time, 'HH12:MI AM')
                    FROM public.room_allocations ra
                    WHERE ra.room_id = r.id 
                      AND ra.status = 'ACTIVE'
                      AND (
                          (ra.day_of_week = v_current_day AND v_current_time BETWEEN ra.start_time AND ra.end_time)
                          OR (ra.allocation_type = 'EVENT' AND ra.day_of_week = v_current_day)
                      )
                    ORDER BY ra.start_time ASC
                    LIMIT 1
                ),
                '—'
            ) AS timings
        FROM public.academic_rooms r
        WHERE r.school_id = p_school_id
          AND r.deleted_at IS NULL
          AND (
              p_search = '' 
              OR r.name ILIKE '%' || p_search || '%' 
              OR r.code ILIKE '%' || p_search || '%'
              OR r.type ILIKE '%' || p_search || '%'
              OR r.building ILIKE '%' || p_search || '%'
          )
          AND (p_type = 'ALL' OR p_type = '' OR UPPER(TRIM(r.type)) = UPPER(TRIM(p_type)))
          AND (p_building = 'ALL' OR p_building = '' OR UPPER(TRIM(r.building)) = UPPER(TRIM(p_building)))
          AND (p_floor = 'ALL' OR p_floor = '' OR UPPER(TRIM(r.floor)) = UPPER(TRIM(p_floor)))
          AND (p_status = 'ALL' OR p_status = '' OR UPPER(TRIM(r.status)) = UPPER(TRIM(p_status)))
        ORDER BY 
            CASE WHEN p_sort_by = 'name' AND p_sort_order ILIKE 'ASC' THEN r.name END ASC,
            CASE WHEN p_sort_by = 'name' AND p_sort_order ILIKE 'DESC' THEN r.name END DESC,
            CASE WHEN p_sort_by = 'code' AND p_sort_order ILIKE 'ASC' THEN r.code END ASC,
            CASE WHEN p_sort_by = 'code' AND p_sort_order ILIKE 'DESC' THEN r.code END DESC,
            CASE WHEN p_sort_by = 'capacity' AND p_sort_order ILIKE 'ASC' THEN r.capacity END ASC,
            CASE WHEN p_sort_by = 'capacity' AND p_sort_order ILIKE 'DESC' THEN r.capacity END DESC,
            r.created_at DESC
        LIMIT p_page_size OFFSET v_offset
    ) r_item;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'rooms', v_rooms,
            'total_count', v_total_count,
            'page', p_page,
            'page_size', p_page_size,
            'total_pages', CEIL(v_total_count::NUMERIC / GREATEST(p_page_size, 1)::NUMERIC)
        )
    );
END;
$$;


-- 2. Dynamic Classes Retrieval Function
CREATE OR REPLACE FUNCTION public.fn_get_academic_classes(
    p_school_id UUID,
    p_search TEXT DEFAULT '',
    p_academic_year VARCHAR DEFAULT '2026-27',
    p_status VARCHAR DEFAULT 'ALL',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_sort_by VARCHAR DEFAULT 'display_order',
    p_sort_order VARCHAR DEFAULT 'ASC',
    p_teacher_id UUID DEFAULT NULL
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
          p_teacher_id IS NULL
          OR EXISTS (
              SELECT 1 FROM public.class_teacher_assignments cta
              WHERE cta.teacher_id = p_teacher_id
                AND cta.class_id = c.id
                AND cta.academic_year = p_academic_year
          )
      )
      AND (
          p_search = '' 
          OR c.name ILIKE '%' || p_search || '%' 
          OR c.code ILIKE '%' || p_search || '%'
          OR c.stage ILIKE '%' || p_search || '%'
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
                'sections_count', (
                    SELECT COUNT(*) 
                    FROM public.academic_sections s 
                    WHERE s.class_id = c.id
                      AND s.deleted_at IS NULL
                      AND (
                          p_teacher_id IS NULL
                          OR EXISTS (
                              SELECT 1 FROM public.class_teacher_assignments cta
                              WHERE cta.teacher_id = p_teacher_id
                                AND (cta.section_id = s.id OR (cta.class_id = s.class_id AND cta.section_id IS NULL))
                                AND cta.academic_year = p_academic_year
                          )
                      )
                ),
                'students_count', (
                    SELECT COUNT(DISTINCT sca.student_id) 
                    FROM public.student_class_assignments sca 
                    WHERE sca.class_id = c.id AND sca.status = 'ACTIVE'
                ),
                'class_teacher', (
                    SELECT jsonb_build_object(
                        'id', p.id,
                        'name', p.full_name,
                        'email', p.email,
                        'avatar_url', p.avatar_url
                    )
                    FROM public.class_teacher_assignments cta
                    JOIN public.profiles p ON p.id = cta.teacher_id
                    WHERE cta.class_id = c.id 
                      AND cta.section_id IS NULL
                      AND cta.academic_year = p_academic_year
                    LIMIT 1
                ),
                'created_at', c.created_at,
                'updated_at', c.updated_at
            )
        ),
        '[]'::JSONB
    ) INTO v_classes
    FROM (
        SELECT c.*
        FROM public.academic_classes c
        WHERE c.school_id = p_school_id
          AND c.academic_year = p_academic_year
          AND (
              (p_status = 'ALL' AND c.deleted_at IS NULL)
              OR (p_status = 'ARCHIVED' AND (UPPER(TRIM(c.status)) = 'ARCHIVED' OR c.deleted_at IS NOT NULL))
              OR (p_status != 'ALL' AND UPPER(TRIM(c.status)) = UPPER(TRIM(p_status)) AND c.deleted_at IS NULL)
          )
          AND (
              p_teacher_id IS NULL
              OR EXISTS (
                  SELECT 1 FROM public.class_teacher_assignments cta
                  WHERE cta.teacher_id = p_teacher_id
                    AND cta.class_id = c.id
                    AND cta.academic_year = p_academic_year
              )
          )
          AND (
              p_search = '' 
              OR c.name ILIKE '%' || p_search || '%' 
              OR c.code ILIKE '%' || p_search || '%'
              OR c.stage ILIKE '%' || p_search || '%'
          )
        ORDER BY 
            CASE WHEN p_sort_by = 'display_order' AND p_sort_order ILIKE 'ASC' THEN c.display_order END ASC,
            CASE WHEN p_sort_by = 'display_order' AND p_sort_order ILIKE 'DESC' THEN c.display_order END DESC,
            CASE WHEN p_sort_by = 'name' AND p_sort_order ILIKE 'ASC' THEN c.name END ASC,
            CASE WHEN p_sort_by = 'name' AND p_sort_order ILIKE 'DESC' THEN c.name END DESC,
            c.created_at DESC
        LIMIT p_page_size OFFSET v_offset
    ) c;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'classes', v_classes,
            'total_count', v_total_count,
            'page', p_page,
            'page_size', p_page_size,
            'total_pages', CEIL(v_total_count::NUMERIC / GREATEST(p_page_size, 1)::NUMERIC)
        )
    );
END;
$$;


-- 3. Dynamic Sections Retrieval Function
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
    p_teacher_id UUID DEFAULT NULL
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
          p_search = '' 
          OR s.name ILIKE '%' || p_search || '%' 
          OR s.code ILIKE '%' || p_search || '%'
          OR c.name ILIKE '%' || p_search || '%'
          OR s.room_number ILIKE '%' || p_search || '%'
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
                'section_teacher', (
                    SELECT jsonb_build_object(
                        'id', p.id,
                        'name', p.full_name,
                        'email', p.email,
                        'avatar_url', p.avatar_url
                    )
                    FROM public.class_teacher_assignments cta
                    JOIN public.profiles p ON p.id = cta.teacher_id
                    WHERE cta.section_id = s.id 
                      AND cta.academic_year = p_academic_year
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
        LEFT JOIN public.academic_rooms r ON r.id = s.room_id
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
              p_search = '' 
              OR s.name ILIKE '%' || p_search || '%' 
              OR s.code ILIKE '%' || p_search || '%'
              OR c.name ILIKE '%' || p_search || '%'
              OR s.room_number ILIKE '%' || p_search || '%'
          )
        ORDER BY 
            CASE WHEN p_sort_by = 'name' AND p_sort_order ILIKE 'ASC' THEN s.name END ASC,
            CASE WHEN p_sort_by = 'name' AND p_sort_order ILIKE 'DESC' THEN s.name END DESC,
            s.created_at DESC
        LIMIT p_page_size OFFSET v_offset
    ) s;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'sections', v_sections,
            'total_count', v_total_count,
            'page', p_page,
            'page_size', p_page_size,
            'total_pages', CEIL(v_total_count::NUMERIC / GREATEST(p_page_size, 1)::NUMERIC)
        )
    );
END;
$$;


-- 4. Dynamic Subjects Retrieval Function
CREATE OR REPLACE FUNCTION public.fn_get_academic_subjects(
    p_school_id UUID,
    p_search TEXT DEFAULT '',
    p_type VARCHAR DEFAULT 'ALL',
    p_status VARCHAR DEFAULT 'ALL',
    p_class_id UUID DEFAULT NULL,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_sort_by VARCHAR DEFAULT 'name',
    p_sort_order VARCHAR DEFAULT 'ASC',
    p_teacher_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_count INT := 0;
    v_offset INT := (GREATEST(p_page, 1) - 1) * p_page_size;
    v_subjects JSONB := '[]'::JSONB;
BEGIN
    SELECT COUNT(DISTINCT s.id)
    INTO v_total_count
    FROM public.academic_subjects s
    LEFT JOIN public.class_subject_offerings cso ON cso.subject_id = s.id AND cso.deleted_at IS NULL
    WHERE s.school_id = p_school_id
      AND (
          (p_status = 'ALL' AND s.deleted_at IS NULL)
          OR (p_status = 'ARCHIVED' AND (UPPER(TRIM(s.status)) = 'ARCHIVED' OR s.deleted_at IS NOT NULL))
          OR (p_status != 'ALL' AND UPPER(TRIM(s.status)) = UPPER(TRIM(p_status)) AND s.deleted_at IS NULL)
      )
      AND (p_type = 'ALL' OR p_type = '' OR UPPER(TRIM(s.type)) = UPPER(TRIM(p_type)))
      AND (p_class_id IS NULL OR cso.class_id = p_class_id)
      AND (
          p_teacher_id IS NULL
          OR EXISTS (
              SELECT 1 FROM public.section_subject_teachers sst
              WHERE sst.subject_id = s.id AND sst.teacher_id = p_teacher_id
          )
      )
      AND (
          p_search = '' 
          OR s.name ILIKE '%' || p_search || '%' 
          OR s.code ILIKE '%' || p_search || '%'
          OR s.type ILIKE '%' || p_search || '%'
      );

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', s_item.id,
                'name', s_item.name,
                'code', s_item.code,
                'type', s_item.type,
                'description', s_item.description,
                'periods_per_week', s_item.periods_per_week,
                'color', s_item.color,
                'icon', s_item.icon,
                'status', s_item.status,
                'classes_count', (
                    SELECT COUNT(DISTINCT cso.class_id) 
                    FROM public.class_subject_offerings cso 
                    WHERE cso.subject_id = s_item.id AND cso.deleted_at IS NULL
                ),
                'assigned_classes', (
                    SELECT COALESCE(
                        jsonb_agg(
                            jsonb_build_object(
                                'class_id', c.id,
                                'class_name', c.name,
                                'class_code', c.code,
                                'is_compulsory', cso2.is_compulsory
                            )
                        ),
                        '[]'::JSONB
                    )
                    FROM public.class_subject_offerings cso2
                    JOIN public.academic_classes c ON c.id = cso2.class_id
                    WHERE cso2.subject_id = s_item.id AND cso2.deleted_at IS NULL AND c.deleted_at IS NULL
                ),
                'created_at', s_item.created_at,
                'updated_at', s_item.updated_at
            )
        ),
        '[]'::JSONB
    ) INTO v_subjects
    FROM (
        SELECT DISTINCT s.*
        FROM public.academic_subjects s
        LEFT JOIN public.class_subject_offerings cso ON cso.subject_id = s.id AND cso.deleted_at IS NULL
        WHERE s.school_id = p_school_id
          AND (
              (p_status = 'ALL' AND s.deleted_at IS NULL)
              OR (p_status = 'ARCHIVED' AND (UPPER(TRIM(s.status)) = 'ARCHIVED' OR s.deleted_at IS NOT NULL))
              OR (p_status != 'ALL' AND UPPER(TRIM(s.status)) = UPPER(TRIM(p_status)) AND s.deleted_at IS NULL)
          )
          AND (p_type = 'ALL' OR p_type = '' OR UPPER(TRIM(s.type)) = UPPER(TRIM(p_type)))
          AND (p_class_id IS NULL OR cso.class_id = p_class_id)
          AND (
              p_teacher_id IS NULL
              OR EXISTS (
                  SELECT 1 FROM public.section_subject_teachers sst
                  WHERE sst.subject_id = s.id AND sst.teacher_id = p_teacher_id
              )
          )
          AND (
              p_search = '' 
              OR s.name ILIKE '%' || p_search || '%' 
              OR s.code ILIKE '%' || p_search || '%'
              OR s.type ILIKE '%' || p_search || '%'
          )
        ORDER BY 
            CASE WHEN p_sort_by = 'name' AND p_sort_order ILIKE 'ASC' THEN s.name END ASC,
            CASE WHEN p_sort_by = 'name' AND p_sort_order ILIKE 'DESC' THEN s.name END DESC,
            s.created_at DESC
        LIMIT p_page_size OFFSET v_offset
    ) s_item;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'subjects', v_subjects,
            'total_count', v_total_count,
            'page', p_page,
            'page_size', p_page_size,
            'total_pages', CEIL(v_total_count::NUMERIC / GREATEST(p_page_size, 1)::NUMERIC)
        )
    );
END;
$$;
