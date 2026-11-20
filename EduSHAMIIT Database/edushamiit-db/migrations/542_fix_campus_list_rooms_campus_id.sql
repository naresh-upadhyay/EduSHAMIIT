-- Migration 542: Fix r.campus_id reference in fn_campus_list_rooms
-- r (public.rooms) does not have campus_id; campus_id belongs to b (public.buildings)

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
            'campus_id', b.campus_id,
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
