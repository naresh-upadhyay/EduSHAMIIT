-- Migration 546: Fix column references in fn_campus_list_floors
-- public.building_floors uses 'area' (not 'total_area') and 'floor_plan_url' (not 'blueprint_url').

DROP FUNCTION IF EXISTS public.fn_campus_list_floors(UUID, UUID, INT, INT);
DROP FUNCTION IF EXISTS public.fn_campus_list_floors(UUID, UUID, INT, INT, JSONB);

CREATE OR REPLACE FUNCTION public.fn_campus_list_floors(
    p_school_id UUID,
    p_building_id UUID,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_filters JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total INT := 0;
    v_offset INT;
    v_floors JSONB := '[]'::JSONB;
    v_sort_by TEXT := LOWER(TRIM(COALESCE(p_filters->>'sort_by', 'floor_level')));
    v_sort_order TEXT := LOWER(TRIM(COALESCE(p_filters->>'sort_order', 'asc')));
BEGIN
    v_offset := GREATEST(0, (COALESCE(p_page, 1) - 1) * COALESCE(p_page_size, 10));

    SELECT COUNT(*) INTO v_total
    FROM public.building_floors
    WHERE building_id = p_building_id
      AND school_id = p_school_id
      AND deleted_at IS NULL;

    SELECT jsonb_agg(sub.f_obj)
    INTO v_floors
    FROM (
        SELECT jsonb_build_object(
            'id', f.id,
            'school_id', f.school_id,
            'building_id', f.building_id,
            'name', f.name,
            'floor_code', f.floor_code,
            'floor_level', f.floor_level,
            'floor_order', f.floor_order,
            'floor_type', f.floor_type,
            'area', COALESCE(f.area, 0),
            'total_area', COALESCE(f.area, 0),
            'area_unit', 'sq ft',
            'floor_plan_url', f.floor_plan_url,
            'blueprint_url', f.floor_plan_url,
            'description', f.description,
            'status', f.status,
            'notes', f.notes,
            'total_rooms', COALESCE(r_cnt.room_cnt, 0),
            'capacity', COALESCE(r_cnt.cap, 0),
            'occupancy', COALESCE(r_cnt.occ, 0),
            'under_maintenance_count', COALESCE(r_cnt.maint_cnt, 0),
            'room_types_summary', COALESCE(r_types.summary_str, 'None'),
            'created_at', f.created_at,
            'updated_at', f.updated_at
        ) AS f_obj
        FROM public.building_floors f
        LEFT JOIN LATERAL (
            SELECT 
                COUNT(*) AS room_cnt,
                SUM(r.max_capacity) AS cap,
                SUM(r.current_occupancy) AS occ,
                COUNT(CASE WHEN r.operational_status = 'Under Maintenance' THEN 1 END) AS maint_cnt
            FROM public.rooms r
            WHERE r.floor_id = f.id AND r.deleted_at IS NULL
        ) r_cnt ON TRUE
        LEFT JOIN LATERAL (
            SELECT string_agg(t.t_entry, ', ') AS summary_str
            FROM (
                SELECT r.room_type || ' (' || COUNT(*) || ')' AS t_entry
                FROM public.rooms r
                WHERE r.floor_id = f.id AND r.deleted_at IS NULL
                GROUP BY r.room_type
                ORDER BY COUNT(*) DESC
            ) t
        ) r_types ON TRUE
        WHERE f.building_id = p_building_id
          AND f.school_id = p_school_id
          AND f.deleted_at IS NULL
        ORDER BY
            CASE WHEN v_sort_by = 'floor_level' AND v_sort_order = 'asc' THEN f.floor_level END ASC,
            CASE WHEN v_sort_by = 'floor_level' AND v_sort_order = 'desc' THEN f.floor_level END DESC,
            CASE WHEN v_sort_by = 'name' AND v_sort_order = 'asc' THEN f.name END ASC,
            CASE WHEN v_sort_by = 'name' AND v_sort_order = 'desc' THEN f.name END DESC,
            CASE WHEN v_sort_by = 'floor_code' AND v_sort_order = 'asc' THEN f.floor_code END ASC,
            CASE WHEN v_sort_by = 'floor_code' AND v_sort_order = 'desc' THEN f.floor_code END DESC,
            CASE WHEN v_sort_by = 'total_rooms' AND v_sort_order = 'asc' THEN r_cnt.room_cnt END ASC,
            CASE WHEN v_sort_by = 'total_rooms' AND v_sort_order = 'desc' THEN r_cnt.room_cnt END DESC,
            CASE WHEN v_sort_by = 'capacity' AND v_sort_order = 'asc' THEN r_cnt.cap END ASC,
            CASE WHEN v_sort_by = 'capacity' AND v_sort_order = 'desc' THEN r_cnt.cap END DESC,
            CASE WHEN v_sort_by = 'occupancy' AND v_sort_order = 'asc' THEN r_cnt.occ END ASC,
            CASE WHEN v_sort_by = 'occupancy' AND v_sort_order = 'desc' THEN r_cnt.occ END DESC,
            f.floor_level ASC, f.floor_order ASC
        LIMIT COALESCE(p_page_size, 10)
        OFFSET v_offset
    ) sub;

    RETURN jsonb_build_object(
        'success', TRUE,
        'total_count', v_total,
        'page', COALESCE(p_page, 1),
        'page_size', COALESCE(p_page_size, 10),
        'data', COALESCE(v_floors, '[]'::JSONB)
    );
END;
$$;

-- Grant execution permissions
GRANT EXECUTE ON FUNCTION public.fn_campus_list_floors(UUID, UUID, INT, INT, JSONB) TO authenticated, service_role;
