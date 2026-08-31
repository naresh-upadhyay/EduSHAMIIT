-- ============================================================================
-- Migration: 290_fix_academic_year_filtering_for_subjects_and_rooms.sql
-- Description: Ensures fn_get_academic_subjects and fn_get_academic_rooms
--              properly filter assigned classes, assigned sections, and teachers
--              by the active academic_year.
-- ============================================================================

-- Drop old overloads cleanly
DROP FUNCTION IF EXISTS public.fn_get_academic_subjects(UUID, TEXT, VARCHAR, VARCHAR, UUID, INT, INT, VARCHAR, VARCHAR, UUID, VARCHAR);
DROP FUNCTION IF EXISTS public.fn_get_academic_subjects(UUID, TEXT, VARCHAR, VARCHAR, UUID, INT, INT, VARCHAR, VARCHAR, UUID);
DROP FUNCTION IF EXISTS public.fn_get_academic_subjects(UUID, TEXT, VARCHAR, VARCHAR, INT, INT, VARCHAR, VARCHAR, UUID);
DROP FUNCTION IF EXISTS public.fn_get_academic_subjects(UUID, TEXT, VARCHAR, VARCHAR, INT, INT, VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS public.fn_get_academic_rooms(UUID, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, INT, INT, VARCHAR, VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS public.fn_get_academic_rooms(UUID, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, INT, INT, VARCHAR, VARCHAR);

-- 1. Canonical fn_get_academic_subjects with p_academic_year filter
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
    p_teacher_id UUID DEFAULT NULL,
    p_academic_year VARCHAR DEFAULT '2026-27'
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
    WHERE s.school_id = p_school_id
      AND (
          (p_status = 'ALL' AND s.deleted_at IS NULL)
          OR (p_status = 'ARCHIVED' AND (UPPER(TRIM(s.status)) = 'ARCHIVED' OR s.deleted_at IS NOT NULL))
          OR (p_status != 'ALL' AND UPPER(TRIM(s.status)) = UPPER(TRIM(p_status)) AND s.deleted_at IS NULL)
      )
      AND (
          p_type = 'ALL' 
          OR p_type = '' 
          OR UPPER(TRIM(s.type)) = UPPER(TRIM(p_type))
          OR (p_type ILIKE '%core%' AND s.type ILIKE '%core%')
          OR ((p_type ILIKE '%elec%' OR p_type ILIKE '%opt%') AND (s.type ILIKE '%elec%' OR s.type ILIKE '%opt%'))
          OR ((p_type ILIKE '%prac%' OR p_type ILIKE '%lab%') AND (s.type ILIKE '%prac%' OR s.type ILIKE '%lab%'))
          OR (p_type ILIKE '%lang%' AND s.type ILIKE '%lang%')
      )
      AND (
          p_class_id IS NULL
          OR EXISTS (
              SELECT 1 FROM public.class_subject_assignments csa
              JOIN public.academic_classes c ON c.id = csa.class_id AND c.deleted_at IS NULL
              WHERE csa.subject_id = s.id 
                AND csa.class_id = p_class_id 
                AND csa.school_id = p_school_id
                AND (p_academic_year IS NULL OR p_academic_year = '' OR csa.academic_year = p_academic_year)
                AND (p_academic_year IS NULL OR p_academic_year = '' OR c.academic_year = p_academic_year)
          )
      )
      AND (
          p_teacher_id IS NULL
          OR EXISTS (
              SELECT 1 FROM public.section_subject_teachers sst
              WHERE sst.subject_id = s.id 
                AND sst.teacher_id = p_teacher_id 
                AND sst.status = 'ACTIVE'
                AND (p_academic_year IS NULL OR p_academic_year = '' OR sst.academic_year = p_academic_year)
          )
          OR EXISTS (
              SELECT 1 FROM public.class_teacher_assignments cta
              JOIN public.class_subject_assignments csa ON csa.class_id = cta.class_id
              WHERE csa.subject_id = s.id
                AND cta.teacher_id = p_teacher_id
                AND (p_academic_year IS NULL OR p_academic_year = '' OR cta.academic_year = p_academic_year)
                AND (p_academic_year IS NULL OR p_academic_year = '' OR csa.academic_year = p_academic_year)
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
                'is_optional', COALESCE(s_item.is_optional, (s_item.type ILIKE '%elec%' OR s_item.type ILIKE '%opt%')),
                'classes_count', (
                    SELECT COUNT(DISTINCT csa.class_id) 
                    FROM public.class_subject_assignments csa 
                    JOIN public.academic_classes c ON c.id = csa.class_id AND c.deleted_at IS NULL
                    WHERE csa.subject_id = s_item.id 
                      AND csa.school_id = p_school_id
                      AND (p_academic_year IS NULL OR p_academic_year = '' OR csa.academic_year = p_academic_year)
                      AND (p_academic_year IS NULL OR p_academic_year = '' OR c.academic_year = p_academic_year)
                ),
                'assigned_sections_count', (
                    SELECT COUNT(DISTINCT csa.section_id) 
                    FROM public.class_subject_assignments csa 
                    JOIN public.academic_sections sec ON sec.id = csa.section_id AND sec.deleted_at IS NULL
                    WHERE csa.subject_id = s_item.id 
                      AND csa.school_id = p_school_id 
                      AND csa.section_id IS NOT NULL
                      AND (p_academic_year IS NULL OR p_academic_year = '' OR csa.academic_year = p_academic_year)
                      AND (p_academic_year IS NULL OR p_academic_year = '' OR sec.academic_year = p_academic_year)
                ),
                'teachers_count', (
                    SELECT COUNT(DISTINCT sst.teacher_id) 
                    FROM public.section_subject_teachers sst 
                    WHERE sst.subject_id = s_item.id 
                      AND sst.school_id = p_school_id 
                      AND sst.status = 'ACTIVE'
                      AND (p_academic_year IS NULL OR p_academic_year = '' OR sst.academic_year = p_academic_year)
                ),
                'assigned_classes', (
                    SELECT COALESCE(
                        jsonb_agg(
                            DISTINCT jsonb_build_object(
                                'class_id', c.id,
                                'class_name', c.name,
                                'class_code', c.code
                            )
                        ),
                        '[]'::JSONB
                    )
                    FROM public.class_subject_assignments csa2
                    JOIN public.academic_classes c ON c.id = csa2.class_id
                    WHERE csa2.subject_id = s_item.id 
                      AND c.deleted_at IS NULL 
                      AND csa2.school_id = p_school_id
                      AND (p_academic_year IS NULL OR p_academic_year = '' OR csa2.academic_year = p_academic_year)
                      AND (p_academic_year IS NULL OR p_academic_year = '' OR c.academic_year = p_academic_year)
                ),
                'created_at', s_item.created_at,
                'updated_at', s_item.updated_at
            )
        ),
        '[]'::JSONB
    ) INTO v_subjects
    FROM (
        SELECT s.*
        FROM public.academic_subjects s
        WHERE s.school_id = p_school_id
          AND (
              (p_status = 'ALL' AND s.deleted_at IS NULL)
              OR (p_status = 'ARCHIVED' AND (UPPER(TRIM(s.status)) = 'ARCHIVED' OR s.deleted_at IS NOT NULL))
              OR (p_status != 'ALL' AND UPPER(TRIM(s.status)) = UPPER(TRIM(p_status)) AND s.deleted_at IS NULL)
          )
          AND (
              p_type = 'ALL' 
              OR p_type = '' 
              OR UPPER(TRIM(s.type)) = UPPER(TRIM(p_type))
              OR (p_type ILIKE '%core%' AND s.type ILIKE '%core%')
              OR ((p_type ILIKE '%elec%' OR p_type ILIKE '%opt%') AND (s.type ILIKE '%elec%' OR s.type ILIKE '%opt%'))
              OR ((p_type ILIKE '%prac%' OR p_type ILIKE '%lab%') AND (s.type ILIKE '%prac%' OR s.type ILIKE '%lab%'))
              OR (p_type ILIKE '%lang%' AND s.type ILIKE '%lang%')
          )
          AND (
              p_class_id IS NULL
              OR EXISTS (
                  SELECT 1 FROM public.class_subject_assignments csa
                  JOIN public.academic_classes c ON c.id = csa.class_id AND c.deleted_at IS NULL
                  WHERE csa.subject_id = s.id 
                    AND csa.class_id = p_class_id 
                    AND csa.school_id = p_school_id
                    AND (p_academic_year IS NULL OR p_academic_year = '' OR csa.academic_year = p_academic_year)
                    AND (p_academic_year IS NULL OR p_academic_year = '' OR c.academic_year = p_academic_year)
              )
          )
          AND (
              p_teacher_id IS NULL
              OR EXISTS (
                  SELECT 1 FROM public.section_subject_teachers sst
                  WHERE sst.subject_id = s.id 
                    AND sst.teacher_id = p_teacher_id 
                    AND sst.status = 'ACTIVE'
                    AND (p_academic_year IS NULL OR p_academic_year = '' OR sst.academic_year = p_academic_year)
              )
              OR EXISTS (
                  SELECT 1 FROM public.class_teacher_assignments cta
                  JOIN public.class_subject_assignments csa ON csa.class_id = cta.class_id
                  WHERE csa.subject_id = s.id
                    AND cta.teacher_id = p_teacher_id
                    AND (p_academic_year IS NULL OR p_academic_year = '' OR cta.academic_year = p_academic_year)
                    AND (p_academic_year IS NULL OR p_academic_year = '' OR csa.academic_year = p_academic_year)
              )
          )
          AND (
              p_search = '' 
              OR s.name ILIKE '%' || p_search || '%' 
              OR s.code ILIKE '%' || p_search || '%'
              OR s.type ILIKE '%' || p_search || '%'
          )
        ORDER BY
            CASE WHEN p_sort_by = 'name' AND UPPER(p_sort_order) = 'ASC' THEN s.name END ASC,
            CASE WHEN p_sort_by = 'name' AND UPPER(p_sort_order) = 'DESC' THEN s.name END DESC,
            CASE WHEN p_sort_by = 'code' AND UPPER(p_sort_order) = 'ASC' THEN s.code END ASC,
            CASE WHEN p_sort_by = 'code' AND UPPER(p_sort_order) = 'DESC' THEN s.code END DESC,
            CASE WHEN p_sort_by = 'type' AND UPPER(p_sort_order) = 'ASC' THEN s.type END ASC,
            CASE WHEN p_sort_by = 'type' AND UPPER(p_sort_order) = 'DESC' THEN s.type END DESC,
            s.created_at DESC
        LIMIT p_page_size
        OFFSET v_offset
    ) s_item;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'subjects', v_subjects,
            'total_count', v_total_count,
            'page', p_page,
            'page_size', p_page_size,
            'total_pages', CEIL(v_total_count::NUMERIC / GREATEST(p_page_size, 1))::INT
        )
    );
END;
$$;

-- 2. Backwards-compatible 10-parameter overload
CREATE OR REPLACE FUNCTION public.fn_get_academic_subjects(
    p_school_id UUID,
    p_search TEXT,
    p_type VARCHAR,
    p_status VARCHAR,
    p_class_id UUID,
    p_page INT,
    p_page_size INT,
    p_sort_by VARCHAR,
    p_sort_order VARCHAR,
    p_teacher_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN public.fn_get_academic_subjects(
        p_school_id, p_search, p_type, p_status, p_class_id,
        p_page, p_page_size, p_sort_by, p_sort_order, p_teacher_id, '2026-27'::VARCHAR
    );
END;
$$;

-- 2B. Backwards-compatible 9-parameter overload
CREATE OR REPLACE FUNCTION public.fn_get_academic_subjects(
    p_school_id UUID,
    p_search TEXT,
    p_type VARCHAR,
    p_status VARCHAR,
    p_page INT,
    p_page_size INT,
    p_sort_by VARCHAR,
    p_sort_order VARCHAR,
    p_teacher_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN public.fn_get_academic_subjects(
        p_school_id, p_search, p_type, p_status, NULL::UUID,
        p_page, p_page_size, p_sort_by, p_sort_order, p_teacher_id, '2026-27'::VARCHAR
    );
END;
$$;


-- 3. Canonical fn_get_academic_rooms with p_academic_year filter
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
    p_sort_order VARCHAR DEFAULT 'ASC',
    p_academic_year VARCHAR DEFAULT '2026-27'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_offset INT := (GREATEST(p_page, 1) - 1) * p_page_size;
    v_total_count INT := 0;
    v_rooms JSONB := '[]'::JSONB;
BEGIN
    -- 1. Total Count for pagination
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
                WHERE s.room_id = r.id 
                  AND s.deleted_at IS NULL
                  AND (p_academic_year IS NULL OR p_academic_year = '' OR s.academic_year = p_academic_year)
            ) AS assigned_sections_count,
            COALESCE(
                (
                    SELECT 'Class ' || c.name || ' (' || s.name || ')'
                    FROM public.academic_sections s
                    JOIN public.academic_classes c ON c.id = s.class_id
                    WHERE s.room_id = r.id 
                      AND s.deleted_at IS NULL
                      AND (p_academic_year IS NULL OR p_academic_year = '' OR s.academic_year = p_academic_year)
                      AND (p_academic_year IS NULL OR p_academic_year = '' OR c.academic_year = p_academic_year)
                    LIMIT 1
                ),
                '—'
            ) AS in_use_by,
            '—' AS timings
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
            CASE WHEN p_sort_by = 'name' AND UPPER(p_sort_order) = 'ASC' THEN r.name END ASC,
            CASE WHEN p_sort_by = 'name' AND UPPER(p_sort_order) = 'DESC' THEN r.name END DESC,
            CASE WHEN p_sort_by = 'code' AND UPPER(p_sort_order) = 'ASC' THEN r.code END ASC,
            CASE WHEN p_sort_by = 'code' AND UPPER(p_sort_order) = 'DESC' THEN r.code END DESC,
            CASE WHEN p_sort_by = 'capacity' AND UPPER(p_sort_order) = 'ASC' THEN r.capacity END ASC,
            CASE WHEN p_sort_by = 'capacity' AND UPPER(p_sort_order) = 'DESC' THEN r.capacity END DESC,
            r.building ASC, r.floor ASC, r.name ASC
        LIMIT p_page_size
        OFFSET v_offset
    ) r_item;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'rooms', v_rooms,
            'total_count', v_total_count,
            'page', p_page,
            'page_size', p_page_size,
            'total_pages', CEIL(v_total_count::NUMERIC / GREATEST(p_page_size, 1))::INT
        )
    );
END;
$$;

-- 4. Backwards-compatible 10-parameter overload for rooms
CREATE OR REPLACE FUNCTION public.fn_get_academic_rooms(
    p_school_id UUID,
    p_search VARCHAR,
    p_type VARCHAR,
    p_building VARCHAR,
    p_floor VARCHAR,
    p_status VARCHAR,
    p_page INT,
    p_page_size INT,
    p_sort_by VARCHAR,
    p_sort_order VARCHAR
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN public.fn_get_academic_rooms(
        p_school_id, p_search, p_type, p_building, p_floor, p_status,
        p_page, p_page_size, p_sort_by, p_sort_order, '2026-27'
    );
END;
$$;
