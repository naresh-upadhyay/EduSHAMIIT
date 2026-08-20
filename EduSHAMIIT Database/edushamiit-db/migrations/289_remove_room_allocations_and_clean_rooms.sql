-- ============================================================================
-- Migration 289: Remove Room Allocations & Scheduling from Rooms module
-- ============================================================================

-- 1. Drop unused room allocation & conflict functions
DROP FUNCTION IF EXISTS public.fn_allocate_room(UUID, UUID, JSONB);
DROP FUNCTION IF EXISTS public.fn_check_room_conflicts(UUID, UUID, INT, TIME, TIME, VARCHAR);
DROP FUNCTION IF EXISTS public.fn_check_room_conflicts(UUID, INT, TIME, TIME, VARCHAR);

-- 2. Drop room_allocations table
DROP TABLE IF EXISTS public.room_allocations CASCADE;

-- 3. Update fn_get_academic_rooms to use assigned academic sections for in_use_by
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
                WHERE s.room_id = r.id AND s.deleted_at IS NULL
            ) AS assigned_sections_count,
            COALESCE(
                (
                    SELECT 'Class ' || c.name || ' (' || s.name || ')'
                    FROM public.academic_sections s
                    JOIN public.academic_classes c ON c.id = s.class_id
                    WHERE s.room_id = r.id AND s.deleted_at IS NULL
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
