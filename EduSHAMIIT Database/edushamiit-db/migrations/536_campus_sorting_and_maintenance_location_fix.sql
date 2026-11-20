-- Migration 536: Campus DB sorting & maintenance location_display fix
-- Fixes not-null constraint on location_display and adds multi-column sorting to room and floor listing procedures

-- 1. Ensure maintenance_requests location_display is robust and nullable with safe default
ALTER TABLE public.maintenance_requests 
    ALTER COLUMN location_display SET DEFAULT 'Entire Building / Common';

ALTER TABLE public.maintenance_requests 
    ALTER COLUMN location_display DROP NOT NULL;

-- 2. Enhanced fn_campus_list_rooms with DB-level column sorting
CREATE OR REPLACE FUNCTION public.fn_campus_list_rooms(
    p_school_id UUID,
    p_filters JSONB DEFAULT '{}'::JSONB,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_search TEXT := TRIM(COALESCE(p_filters->>'search', ''));
    v_bld_id_txt TEXT := TRIM(COALESCE(p_filters->>'building_id', ''));
    v_bld_id UUID := NULL;
    v_floor_id_txt TEXT := TRIM(COALESCE(p_filters->>'floor_id', ''));
    v_floor_id UUID := NULL;
    v_room_type TEXT := TRIM(COALESCE(p_filters->>'room_type', ''));
    v_op_status TEXT := TRIM(COALESCE(p_filters->>'operational_status', ''));
    v_assign_status TEXT := TRIM(COALESCE(p_filters->>'assignment_status', ''));
    v_min_cap INT := COALESCE((p_filters->>'min_capacity')::INT, 0);
    v_max_cap INT := COALESCE((p_filters->>'max_capacity')::INT, 999999);
    v_sort_by TEXT := LOWER(TRIM(COALESCE(p_filters->>'sort_by', 'room_number')));
    v_sort_order TEXT := LOWER(TRIM(COALESCE(p_filters->>'sort_order', 'asc')));
    v_offset INT;
    v_total INT := 0;
    v_rooms JSONB := '[]'::JSONB;
BEGIN
    IF v_bld_id_txt <> '' THEN v_bld_id := v_bld_id_txt::UUID; END IF;
    IF v_floor_id_txt <> '' THEN v_floor_id := v_floor_id_txt::UUID; END IF;

    v_offset := GREATEST(0, (COALESCE(p_page, 1) - 1) * COALESCE(p_page_size, 10));

    SELECT COUNT(*) INTO v_total
    FROM public.rooms r
    LEFT JOIN public.buildings b ON r.building_id = b.id
    LEFT JOIN public.building_floors f ON r.floor_id = f.id
    WHERE r.school_id = p_school_id
      AND r.deleted_at IS NULL
      AND (v_bld_id IS NULL OR r.building_id = v_bld_id)
      AND (v_floor_id IS NULL OR r.floor_id = v_floor_id)
      AND (v_room_type = '' OR LOWER(r.room_type) = LOWER(v_room_type))
      AND (v_op_status = '' OR LOWER(r.operational_status) = LOWER(v_op_status))
      AND (v_assign_status = '' OR LOWER(r.assignment_status) = LOWER(v_assign_status))
      AND (r.max_capacity BETWEEN v_min_cap AND v_max_cap)
      AND (
          v_search = '' OR
          r.name ILIKE '%' || v_search || '%' OR
          r.room_number ILIKE '%' || v_search || '%' OR
          r.room_code ILIKE '%' || v_search || '%' OR
          b.name ILIKE '%' || v_search || '%' OR
          f.name ILIKE '%' || v_search || '%'
      );

    SELECT jsonb_agg(sub.r_obj)
    INTO v_rooms
    FROM (
        SELECT jsonb_build_object(
            'id', r.id,
            'school_id', r.school_id,
            'campus_id', r.campus_id,
            'building_id', r.building_id,
            'building_name', b.name,
            'building_code', b.code,
            'floor_id', r.floor_id,
            'floor_name', f.name,
            'floor_level', f.floor_level,
            'name', r.name,
            'room_number', r.room_number,
            'room_code', r.room_code,
            'room_type', r.room_type,
            'description', r.description,
            'purpose', r.purpose,
            'area', r.area,
            'area_unit', r.area_unit,
            'length', r.length,
            'width', r.width,
            'height', r.height,
            'max_capacity', r.max_capacity,
            'recommended_capacity', r.recommended_capacity,
            'current_occupancy', r.current_occupancy,
            'bed_count', r.bed_count,
            'seating_capacity', r.seating_capacity,
            'workstation_count', r.workstation_count,
            'num_doors', r.num_doors,
            'num_windows', r.num_windows,
            'operational_status', r.operational_status,
            'assignment_status', r.assignment_status,
            'is_differently_abled_accessible', r.is_differently_abled_accessible,
            'lift_proximity', r.lift_proximity,
            'emergency_exit_proximity', r.emergency_exit_proximity,
            'location_notes', r.location_notes,
            'image_url', r.image_url,
            'responsible_department', r.responsible_department,
            'responsible_person_name', r.responsible_person_name,
            'equipment_count', COALESCE(eq_cnt.cnt, 0),
            'active_assignments_count', COALESCE(asgn_cnt.cnt, 0),
            'created_at', r.created_at,
            'updated_at', r.updated_at
        ) AS r_obj
        FROM public.rooms r
        LEFT JOIN public.buildings b ON r.building_id = b.id
        LEFT JOIN public.building_floors f ON r.floor_id = f.id
        LEFT JOIN LATERAL (
            SELECT COUNT(*) AS cnt
            FROM public.room_equipment eq
            WHERE eq.room_id = r.id AND eq.deleted_at IS NULL
        ) eq_cnt ON TRUE
        LEFT JOIN LATERAL (
            SELECT COUNT(*) AS cnt
            FROM public.room_assignments ra
            WHERE ra.room_id = r.id AND ra.deleted_at IS NULL
        ) asgn_cnt ON TRUE
        WHERE r.school_id = p_school_id
          AND r.deleted_at IS NULL
          AND (v_bld_id IS NULL OR r.building_id = v_bld_id)
          AND (v_floor_id IS NULL OR r.floor_id = v_floor_id)
          AND (v_room_type = '' OR LOWER(r.room_type) = LOWER(v_room_type))
          AND (v_op_status = '' OR LOWER(r.operational_status) = LOWER(v_op_status))
          AND (v_assign_status = '' OR LOWER(r.assignment_status) = LOWER(v_assign_status))
          AND (r.max_capacity BETWEEN v_min_cap AND v_max_cap)
          AND (
              v_search = '' OR
              r.name ILIKE '%' || v_search || '%' OR
              r.room_number ILIKE '%' || v_search || '%' OR
              r.room_code ILIKE '%' || v_search || '%' OR
              b.name ILIKE '%' || v_search || '%' OR
              f.name ILIKE '%' || v_search || '%'
          )
        ORDER BY
            CASE WHEN v_sort_by = 'room_number' AND v_sort_order = 'asc' THEN r.room_number END ASC,
            CASE WHEN v_sort_by = 'room_number' AND v_sort_order = 'desc' THEN r.room_number END DESC,
            CASE WHEN v_sort_by = 'name' AND v_sort_order = 'asc' THEN r.name END ASC,
            CASE WHEN v_sort_by = 'name' AND v_sort_order = 'desc' THEN r.name END DESC,
            CASE WHEN v_sort_by = 'room_type' AND v_sort_order = 'asc' THEN r.room_type END ASC,
            CASE WHEN v_sort_by = 'room_type' AND v_sort_order = 'desc' THEN r.room_type END DESC,
            CASE WHEN v_sort_by = 'floor_name' AND v_sort_order = 'asc' THEN f.name END ASC,
            CASE WHEN v_sort_by = 'floor_name' AND v_sort_order = 'desc' THEN f.name END DESC,
            CASE WHEN v_sort_by = 'max_capacity' AND v_sort_order = 'asc' THEN r.max_capacity END ASC,
            CASE WHEN v_sort_by = 'max_capacity' AND v_sort_order = 'desc' THEN r.max_capacity END DESC,
            CASE WHEN v_sort_by = 'current_occupancy' AND v_sort_order = 'asc' THEN r.current_occupancy END ASC,
            CASE WHEN v_sort_by = 'current_occupancy' AND v_sort_order = 'desc' THEN r.current_occupancy END DESC,
            CASE WHEN v_sort_by = 'assignment_status' AND v_sort_order = 'asc' THEN r.assignment_status END ASC,
            CASE WHEN v_sort_by = 'assignment_status' AND v_sort_order = 'desc' THEN r.assignment_status END DESC,
            CASE WHEN v_sort_by = 'operational_status' AND v_sort_order = 'asc' THEN r.operational_status END ASC,
            CASE WHEN v_sort_by = 'operational_status' AND v_sort_order = 'desc' THEN r.operational_status END DESC,
            CASE WHEN v_sort_by = 'created_at' AND v_sort_order = 'asc' THEN r.created_at END ASC,
            CASE WHEN v_sort_by = 'created_at' AND v_sort_order = 'desc' THEN r.created_at END DESC,
            r.room_number ASC, r.name ASC
        LIMIT COALESCE(p_page_size, 10)
        OFFSET v_offset
    ) sub;

    RETURN jsonb_build_object(
        'success', TRUE,
        'total_count', v_total,
        'page', COALESCE(p_page, 1),
        'page_size', COALESCE(p_page_size, 10),
        'data', COALESCE(v_rooms, '[]'::JSONB)
    );
END;
$$;

-- 3. Enhanced fn_campus_list_floors with DB-level column sorting
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
            'total_area', f.total_area,
            'area_unit', f.area_unit,
            'blueprint_url', f.blueprint_url,
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
