-- ============================================================================
-- Migration 520: Enterprise Floor Plan Spatial Stored Procedures & Seed Data
-- 1. Creates fn_get_floor_plan_and_markers for dynamic architectural room layout,
--    sub-grid marker placement with collision prevention, boundary clamping,
--    available floors list for fast switching, and 100% synchronized legend counts.
-- 2. Creates sp_save_floor_plan_marker and sp_delete_floor_plan_marker.
-- 3. Seeds realistic IoT devices for Academic Block floors (F1, F2) with proper
--    room assignments, device types, and ensures legend matches exactly.
-- ============================================================================

-- Function: Retrieve Floor Plan Blueprint, Dynamic Rooms, Markers, and Synchronized Legend
CREATE OR REPLACE FUNCTION fn_get_floor_plan_and_markers(
    p_floor_id UUID,
    p_school_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_school_id UUID := COALESCE(p_school_id, '11111111-1111-1111-1111-111111111111'::UUID);
    v_building_id UUID;
    v_building_name VARCHAR := 'Academic Block';
    v_floor_name VARCHAR := 'First Floor';
    v_floor_number INT := 1;
    v_plan_id UUID;
    v_title VARCHAR;
    v_dimensions_width NUMERIC := 1200.0;
    v_dimensions_height NUMERIC := 750.0;
    v_scale NUMERIC := 25.0;
    v_rooms_layout JSONB := '[]'::JSONB;
    v_available_floors JSONB := '[]'::JSONB;
    v_markers JSONB := '[]'::JSONB;
    v_legend JSONB;
    v_cctv INT := 0;
    v_lighting INT := 0;
    v_hvac INT := 0;
    v_projector INT := 0;
    v_access_point INT := 0;
    v_audio INT := 0;
    v_fan INT := 0;
    v_total_markers INT := 0;
    v_has_custom_asset BOOLEAN := FALSE;
    
    -- Room geometry calculation helpers
    v_room_count INT := 0;
    v_k1 INT;
    v_k2 INT;
    v_w1 NUMERIC;
    v_w2 NUMERIC;
    v_idx INT := 0;
    r_rec RECORD;
    d_rec RECORD;
    
    -- Sub-grid collision avoidance map
    v_room_pos_map JSONB := '{}'::JSONB;
    v_curr_count INT := 0;
    v_pos_x NUMERIC;
    v_pos_y NUMERIC;
    v_rm_x NUMERIC;
    v_rm_y NUMERIC;
    v_rm_w NUMERIC;
    v_rm_h NUMERIC;
    v_type_normalized VARCHAR;
    v_slot_col INT;
    v_slot_row INT;
    v_marker_item JSONB;
BEGIN
    -- 1. Fetch floor and building information
    SELECT f.building_id, b.name, f.name, COALESCE(f.floor_level, f.floor_order, 1)
    INTO v_building_id, v_building_name, v_floor_name, v_floor_number
    FROM building_floors f
    JOIN buildings b ON b.id = f.building_id
    WHERE f.id = p_floor_id;

    -- Return safe failure structure if floor does not exist
    IF v_building_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Floor not found'
        );
    END IF;

    -- 2. Fetch all sibling floors for building (for fast floor switching dropdown)
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', sf.id,
            'name', sf.name,
            'floor_level', COALESCE(sf.floor_level, sf.floor_order, 0),
            'is_current', (sf.id = p_floor_id)
        ) ORDER BY COALESCE(sf.floor_level, sf.floor_order, 0) ASC, sf.name ASC
    ), '[]'::JSONB)
    INTO v_available_floors
    FROM building_floors sf
    WHERE sf.building_id = v_building_id;

    -- 3. Check for existing custom floor plan asset
    SELECT id, title, dimensions_width, dimensions_height, scale_pixels_per_meter, rooms_layout
    INTO v_plan_id, v_title, v_dimensions_width, v_dimensions_height, v_scale, v_rooms_layout
    FROM floor_plan_assets
    WHERE floor_id = p_floor_id AND is_active = TRUE
    ORDER BY updated_at DESC
    LIMIT 1;

    IF v_plan_id IS NOT NULL AND v_rooms_layout IS NOT NULL AND jsonb_array_length(v_rooms_layout) > 0 THEN
        v_has_custom_asset := TRUE;
    ELSE
        -- Generate dynamic room layout from `rooms` table
        SELECT COUNT(*) INTO v_room_count
        FROM rooms
        WHERE floor_id = p_floor_id AND deleted_at IS NULL;

        v_rooms_layout := '[]'::JSONB;

        IF v_room_count > 0 THEN
            IF v_room_count <= 4 THEN
                v_w1 := round((0.92 - (v_room_count - 1) * 0.02) / GREATEST(v_room_count, 1), 3);
                v_idx := 0;
                FOR r_rec IN 
                    SELECT id, room_number, name, room_type
                    FROM rooms
                    WHERE floor_id = p_floor_id AND deleted_at IS NULL
                    ORDER BY room_number ASC
                LOOP
                    v_rm_x := round(0.04 + v_idx * (v_w1 + 0.02), 3);
                    v_rooms_layout := v_rooms_layout || jsonb_build_object(
                        'room_id', r_rec.id,
                        'code', r_rec.room_number,
                        'name', r_rec.name,
                        'room_type', COALESCE(r_rec.room_type, 'Classroom'),
                        'x', v_rm_x,
                        'y', 0.08,
                        'w', v_w1,
                        'h', 0.36
                    );
                    v_idx := v_idx + 1;
                END LOOP;

                -- Central Corridor
                v_rooms_layout := v_rooms_layout || jsonb_build_object(
                    'room_id', 'corridor',
                    'code', 'Corridor',
                    'name', 'Corridor',
                    'room_type', 'Corridor',
                    'x', 0.04,
                    'y', 0.48,
                    'w', 0.92,
                    'h', 0.12
                );
            ELSE
                v_k1 := (v_room_count + 1) / 2;
                v_k2 := v_room_count - v_k1;
                v_w1 := round((0.92 - (v_k1 - 1) * 0.02) / GREATEST(v_k1, 1), 3);
                v_w2 := round((0.92 - (v_k2 - 1) * 0.02) / GREATEST(v_k2, 1), 3);

                v_idx := 0;
                FOR r_rec IN 
                    SELECT id, room_number, name, room_type
                    FROM rooms
                    WHERE floor_id = p_floor_id AND deleted_at IS NULL
                    ORDER BY room_number ASC
                LOOP
                    IF v_idx < v_k1 THEN
                        v_rm_x := round(0.04 + v_idx * (v_w1 + 0.02), 3);
                        v_rooms_layout := v_rooms_layout || jsonb_build_object(
                            'room_id', r_rec.id,
                            'code', r_rec.room_number,
                            'name', r_rec.name,
                            'room_type', COALESCE(r_rec.room_type, 'Classroom'),
                            'x', v_rm_x,
                            'y', 0.06,
                            'w', v_w1,
                            'h', 0.38
                        );
                    ELSE
                        v_rm_x := round(0.04 + (v_idx - v_k1) * (v_w2 + 0.02), 3);
                        v_rooms_layout := v_rooms_layout || jsonb_build_object(
                            'room_id', r_rec.id,
                            'code', r_rec.room_number,
                            'name', r_rec.name,
                            'room_type', COALESCE(r_rec.room_type, 'Classroom'),
                            'x', v_rm_x,
                            'y', 0.58,
                            'w', v_w2,
                            'h', 0.38
                        );
                    END IF;
                    v_idx := v_idx + 1;
                END LOOP;

                -- Central Corridor
                v_rooms_layout := v_rooms_layout || jsonb_build_object(
                    'room_id', 'corridor',
                    'code', 'Corridor',
                    'name', 'Corridor',
                    'room_type', 'Corridor',
                    'x', 0.04,
                    'y', 0.46,
                    'w', 0.92,
                    'h', 0.10
                );
            END IF;
        ELSE
            -- Standard fallback 7-room template
            v_rooms_layout := jsonb_build_array(
                jsonb_build_object('room_id', 'r1', 'code', '101', 'name', 'Classroom', 'room_type', 'Classroom', 'x', 0.04, 'y', 0.06, 'w', 0.21, 'h', 0.38),
                jsonb_build_object('room_id', 'r2', 'code', '102', 'name', 'Classroom', 'room_type', 'Classroom', 'x', 0.27, 'y', 0.06, 'w', 0.21, 'h', 0.38),
                jsonb_build_object('room_id', 'r3', 'code', '103', 'name', 'Classroom', 'room_type', 'Classroom', 'x', 0.50, 'y', 0.06, 'w', 0.21, 'h', 0.38),
                jsonb_build_object('room_id', 'r4', 'code', '104', 'name', 'Classroom', 'room_type', 'Classroom', 'x', 0.73, 'y', 0.06, 'w', 0.23, 'h', 0.38),
                jsonb_build_object('room_id', 'corridor', 'code', 'Corridor', 'name', 'Corridor', 'room_type', 'Corridor', 'x', 0.04, 'y', 0.46, 'w', 0.92, 'h', 0.10),
                jsonb_build_object('room_id', 'r5', 'code', '105', 'name', 'Lab', 'room_type', 'Laboratory', 'x', 0.04, 'y', 0.58, 'w', 0.29, 'h', 0.38),
                jsonb_build_object('room_id', 'r6', 'code', '106', 'name', 'Lab', 'room_type', 'Laboratory', 'x', 0.35, 'y', 0.58, 'w', 0.29, 'h', 0.38),
                jsonb_build_object('room_id', 'r7', 'code', '107', 'name', 'Smart Class', 'room_type', 'Classroom', 'x', 0.66, 'y', 0.58, 'w', 0.30, 'h', 0.38)
            );
        END IF;

        v_title := v_building_name || ' – ' || v_floor_name || ' Architectural Blueprint';
    END IF;

    -- 4. Load or generate markers
    SELECT COUNT(*) INTO v_curr_count
    FROM floor_plan_markers
    WHERE floor_id = p_floor_id AND is_active = TRUE;

    v_markers := '[]'::JSONB;

    IF v_curr_count > 0 THEN
        FOR d_rec IN
            SELECT m.id AS marker_id, m.device_id, m.pos_x, m.pos_y, m.rotation_degrees, m.marker_label,
                   d.device_name, d.device_code, d.is_online, d.power_state, d.current_state,
                   COALESCE(m.room_id, d.room_id) AS room_id,
                   dt.name AS device_type_name, dt.code AS device_type_code, dt.icon AS device_type_icon,
                   r.room_number, r.name AS room_name
            FROM floor_plan_markers m
            JOIN devices d ON d.id = m.device_id
            LEFT JOIN device_types dt ON dt.id = d.device_type_id
            LEFT JOIN rooms r ON r.id = COALESCE(m.room_id, d.room_id)
            WHERE m.floor_id = p_floor_id AND m.is_active = TRUE
        LOOP
            -- Normalize type
            v_type_normalized := CASE
                WHEN lower(COALESCE(d_rec.device_type_code, d_rec.device_type_name, '')) ~* 'cctv|cam' THEN 'CCTV'
                WHEN lower(COALESCE(d_rec.device_type_code, d_rec.device_type_name, '')) ~* 'light' THEN 'Lighting'
                WHEN lower(COALESCE(d_rec.device_type_code, d_rec.device_type_name, '')) ~* 'ac|hvac|air_cond' THEN 'HVAC'
                WHEN lower(COALESCE(d_rec.device_type_code, d_rec.device_type_name, '')) ~* 'proj|disp' THEN 'Projector'
                WHEN lower(COALESCE(d_rec.device_type_code, d_rec.device_type_name, '')) ~* 'access|wifi|ap|point' THEN 'Access Point'
                WHEN lower(COALESCE(d_rec.device_type_code, d_rec.device_type_name, '')) ~* 'audio|speaker|sound|mic' THEN 'Audio'
                WHEN lower(COALESCE(d_rec.device_type_code, d_rec.device_type_name, '')) ~* 'fan' THEN 'Fan'
                ELSE COALESCE(d_rec.device_type_name, 'Device')
            END;

            -- Bound clamping to prevent any marker from going outside or behind legend overlay
            v_pos_x := GREATEST(0.06, LEAST(round(d_rec.pos_x::NUMERIC, 3), 0.76));
            v_pos_y := GREATEST(0.08, LEAST(round(d_rec.pos_y::NUMERIC, 3), 0.90));

            -- Category tally
            IF v_type_normalized = 'CCTV' THEN v_cctv := v_cctv + 1;
            ELSIF v_type_normalized = 'Lighting' THEN v_lighting := v_lighting + 1;
            ELSIF v_type_normalized = 'HVAC' THEN v_hvac := v_hvac + 1;
            ELSIF v_type_normalized = 'Projector' THEN v_projector := v_projector + 1;
            ELSIF v_type_normalized = 'Access Point' THEN v_access_point := v_access_point + 1;
            ELSIF v_type_normalized = 'Audio' THEN v_audio := v_audio + 1;
            ELSIF v_type_normalized = 'Fan' THEN v_fan := v_fan + 1;
            END IF;
            v_total_markers := v_total_markers + 1;

            v_marker_item := jsonb_build_object(
                'id', d_rec.marker_id,
                'device_id', d_rec.device_id,
                'device_name', d_rec.device_name,
                'device_code', d_rec.device_code,
                'marker_label', COALESCE(d_rec.marker_label, d_rec.device_code),
                'device_type', v_type_normalized,
                'device_type_code', d_rec.device_type_code,
                'pos_x', v_pos_x,
                'pos_y', v_pos_y,
                'rotation', round(COALESCE(d_rec.rotation_degrees, 0)::NUMERIC, 1),
                'is_online', COALESCE(d_rec.is_online, TRUE),
                'power_state', COALESCE(d_rec.power_state, TRUE),
                'current_state', COALESCE(d_rec.current_state, '{}'::JSONB),
                'is_mapped', TRUE,
                'room_id', d_rec.room_id,
                'room_number', d_rec.room_number,
                'room_name', d_rec.room_name
            );
            v_markers := v_markers || jsonb_build_array(v_marker_item);
        END LOOP;
    ELSE
        -- Auto-generate markers from devices on this floor with sub-grid collision avoidance
        v_idx := 0;
        FOR d_rec IN
            SELECT d.id AS device_id, d.device_name, d.device_code, d.is_online, d.power_state, d.current_state,
                   d.room_id,
                   dt.name AS device_type_name, dt.code AS device_type_code, dt.icon AS device_type_icon,
                   r.room_number, r.name AS room_name
            FROM devices d
            LEFT JOIN device_types dt ON dt.id = d.device_type_id
            LEFT JOIN rooms r ON r.id = d.room_id
            WHERE d.floor_id = p_floor_id AND d.deleted_at IS NULL
            ORDER BY d.room_id NULLS LAST, d.device_code ASC
        LOOP
            -- Normalize type
            v_type_normalized := CASE
                WHEN lower(COALESCE(d_rec.device_type_code, d_rec.device_type_name, '')) ~* 'cctv|cam' THEN 'CCTV'
                WHEN lower(COALESCE(d_rec.device_type_code, d_rec.device_type_name, '')) ~* 'light' THEN 'Lighting'
                WHEN lower(COALESCE(d_rec.device_type_code, d_rec.device_type_name, '')) ~* 'ac|hvac|air_cond' THEN 'HVAC'
                WHEN lower(COALESCE(d_rec.device_type_code, d_rec.device_type_name, '')) ~* 'proj|disp' THEN 'Projector'
                WHEN lower(COALESCE(d_rec.device_type_code, d_rec.device_type_name, '')) ~* 'access|wifi|ap|point' THEN 'Access Point'
                WHEN lower(COALESCE(d_rec.device_type_code, d_rec.device_type_name, '')) ~* 'audio|speaker|sound|mic' THEN 'Audio'
                WHEN lower(COALESCE(d_rec.device_type_code, d_rec.device_type_name, '')) ~* 'fan' THEN 'Fan'
                ELSE COALESCE(d_rec.device_type_name, 'Device')
            END;

            -- Find room geometry in v_rooms_layout
            v_rm_x := NULL;
            IF d_rec.room_id IS NOT NULL THEN
                SELECT (rm->>'x')::NUMERIC, (rm->>'y')::NUMERIC, (rm->>'w')::NUMERIC, (rm->>'h')::NUMERIC
                INTO v_rm_x, v_rm_y, v_rm_w, v_rm_h
                FROM jsonb_array_elements(v_rooms_layout) rm
                WHERE (rm->>'room_id') = d_rec.room_id::TEXT
                LIMIT 1;
            END IF;

            IF v_rm_x IS NOT NULL THEN
                -- Sub-grid inside room
                v_curr_count := COALESCE((v_room_pos_map->>(d_rec.room_id::TEXT))::INT, 0);
                v_room_pos_map := jsonb_set(v_room_pos_map, ARRAY[d_rec.room_id::TEXT], to_jsonb(v_curr_count + 1));

                -- Grid of 2 cols x 3 rows
                v_slot_col := v_curr_count % 2;
                v_slot_row := (v_curr_count / 2) % 3;

                v_pos_x := round(v_rm_x + 0.28 * v_rm_w + v_slot_col * 0.44 * v_rm_w, 3);
                v_pos_y := round(v_rm_y + 0.28 * v_rm_h + v_slot_row * 0.36 * v_rm_h, 3);
            ELSE
                -- Corridor or hallway placement (safe horizontal corridor between rooms)
                v_pos_x := round(0.08 + (v_idx % 6) * 0.11, 3);
                v_pos_y := 0.51;
                v_idx := v_idx + 1;
            END IF;

            -- Clamp to safe area (x <= 0.76 ensures never overlapping with the right legend overlay)
            v_pos_x := GREATEST(0.06, LEAST(v_pos_x, 0.76));
            v_pos_y := GREATEST(0.08, LEAST(v_pos_y, 0.90));

            -- Category tally
            IF v_type_normalized = 'CCTV' THEN v_cctv := v_cctv + 1;
            ELSIF v_type_normalized = 'Lighting' THEN v_lighting := v_lighting + 1;
            ELSIF v_type_normalized = 'HVAC' THEN v_hvac := v_hvac + 1;
            ELSIF v_type_normalized = 'Projector' THEN v_projector := v_projector + 1;
            ELSIF v_type_normalized = 'Access Point' THEN v_access_point := v_access_point + 1;
            ELSIF v_type_normalized = 'Audio' THEN v_audio := v_audio + 1;
            ELSIF v_type_normalized = 'Fan' THEN v_fan := v_fan + 1;
            END IF;
            v_total_markers := v_total_markers + 1;

            v_marker_item := jsonb_build_object(
                'id', 'marker-' || d_rec.device_id,
                'device_id', d_rec.device_id,
                'device_name', d_rec.device_name,
                'device_code', d_rec.device_code,
                'marker_label', d_rec.device_code,
                'device_type', v_type_normalized,
                'device_type_code', d_rec.device_type_code,
                'pos_x', v_pos_x,
                'pos_y', v_pos_y,
                'rotation', 0.0,
                'is_online', COALESCE(d_rec.is_online, TRUE),
                'power_state', COALESCE(d_rec.power_state, TRUE),
                'current_state', COALESCE(d_rec.current_state, '{}'::JSONB),
                'is_mapped', TRUE,
                'room_id', d_rec.room_id,
                'room_number', d_rec.room_number,
                'room_name', d_rec.room_name
            );
            v_markers := v_markers || jsonb_build_array(v_marker_item);
        END LOOP;
    END IF;

    -- 5. Build dynamic Legend metrics (100% synchronized with actual markers)
    v_legend := jsonb_build_object(
        'cctv', v_cctv,
        'lighting', v_lighting,
        'hvac', v_hvac,
        'projector', v_projector,
        'access_point', v_access_point,
        'audio', v_audio,
        'fan', v_fan,
        'total', v_total_markers
    );

    -- 6. Construct full payload
    RETURN jsonb_build_object(
        'success', TRUE,
        'floor_plan', jsonb_build_object(
            'id', COALESCE(v_plan_id::TEXT, 'fp-' || p_floor_id::TEXT),
            'floor_id', p_floor_id,
            'building_id', v_building_id,
            'building_name', v_building_name,
            'floor_name', v_floor_name,
            'floor_number', v_floor_number,
            'title', v_title,
            'dimensions_width', v_dimensions_width,
            'dimensions_height', v_dimensions_height,
            'scale_pixels_per_meter', v_scale,
            'rooms_layout', v_rooms_layout,
            'available_floors', v_available_floors
        ),
        'markers', v_markers,
        'legend', v_legend
    );
END;
$$;


-- Procedure: Save or Update Floor Plan Marker
CREATE OR REPLACE PROCEDURE sp_save_floor_plan_marker(
    p_floor_id UUID,
    p_device_id UUID,
    p_pos_x NUMERIC,
    p_pos_y NUMERIC,
    p_rotation NUMERIC DEFAULT 0,
    p_label VARCHAR DEFAULT NULL,
    p_room_id UUID DEFAULT NULL,
    p_floor_plan_id UUID DEFAULT NULL,
    p_school_id UUID DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_school_id UUID := COALESCE(p_school_id, '11111111-1111-1111-1111-111111111111'::UUID);
    v_fp_id UUID := p_floor_plan_id;
    v_marker_id UUID;
    v_clamped_x NUMERIC;
    v_clamped_y NUMERIC;
BEGIN
    v_clamped_x := GREATEST(0.06, LEAST(round(p_pos_x::NUMERIC, 3), 0.76));
    v_clamped_y := GREATEST(0.08, LEAST(round(p_pos_y::NUMERIC, 3), 0.90));

    IF v_fp_id IS NULL THEN
        SELECT id INTO v_fp_id
        FROM floor_plan_assets
        WHERE floor_id = p_floor_id AND is_active = TRUE
        LIMIT 1;
        
        IF v_fp_id IS NULL THEN
            INSERT INTO floor_plan_assets (
                id, school_id, building_id, floor_id, title, version,
                dimensions_width, dimensions_height, scale_pixels_per_meter, is_active,
                created_at, updated_at
            )
            SELECT 
                gen_random_uuid(), v_school_id, f.building_id, f.id,
                b.name || ' – ' || f.name || ' Architectural Plan', 'v1.0',
                1200.0, 750.0, 25.0, TRUE,
                NOW(), NOW()
            FROM building_floors f
            JOIN buildings b ON b.id = f.building_id
            WHERE f.id = p_floor_id
            RETURNING id INTO v_fp_id;
        END IF;
    END IF;

    SELECT id INTO v_marker_id
    FROM floor_plan_markers
    WHERE floor_id = p_floor_id AND device_id = p_device_id;

    IF v_marker_id IS NOT NULL THEN
        UPDATE floor_plan_markers
        SET pos_x = v_clamped_x,
            pos_y = v_clamped_y,
            rotation_degrees = COALESCE(p_rotation, 0),
            marker_label = p_label,
            room_id = p_room_id,
            floor_plan_id = COALESCE(v_fp_id, floor_plan_id),
            is_active = TRUE,
            updated_at = NOW()
        WHERE id = v_marker_id;
    ELSE
        INSERT INTO floor_plan_markers (
            id, school_id, floor_plan_id, floor_id, room_id, device_id,
            pos_x, pos_y, rotation_degrees, marker_label, is_active,
            created_at, updated_at
        ) VALUES (
            gen_random_uuid(), v_school_id, v_fp_id, p_floor_id, p_room_id, p_device_id,
            v_clamped_x, v_clamped_y, COALESCE(p_rotation, 0), p_label, TRUE,
            NOW(), NOW()
        );
    END IF;

    UPDATE devices
    SET floor_id = p_floor_id,
        room_id = COALESCE(p_room_id, room_id),
        updated_at = NOW()
    WHERE id = p_device_id;
END;
$$;


-- Procedure: Delete Floor Plan Marker
CREATE OR REPLACE PROCEDURE sp_delete_floor_plan_marker(
    p_floor_id UUID,
    p_marker_id UUID
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE floor_plan_markers
    SET is_active = FALSE,
        updated_at = NOW()
    WHERE (id = p_marker_id OR device_id = p_marker_id)
      AND floor_id = p_floor_id;
END;
$$;


-- ============================================================================
-- Seed / Align Devices for Academic Block Second Floor (F2) & First Floor (F1)
-- ============================================================================
DO $$
DECLARE
    v_bldg_academic UUID := 'd4b547da-ca46-4976-af82-c1b89ac6f0a7'::UUID;
    v_floor_f1 UUID := '8770a0e6-8aa9-4e65-9a85-539eabd5f9a6'::UUID;
    v_floor_f2 UUID := 'b88cf8d5-d000-40ea-b1c5-be7534ca74ab'::UUID;

    -- Rooms for F2
    v_r201 UUID := '16f48335-60db-45cf-b05a-794d9311bc9a'::UUID;
    v_r202 UUID := '870be465-d370-4f33-b252-b1fe154109a7'::UUID;
    v_r203 UUID := '982203e1-9dff-4a9f-add3-f3d8f91c3e17'::UUID;
    v_r204 UUID := '81bc6d94-208b-404a-a0b1-70178668cbf2'::UUID;
    v_r205 UUID := 'f669be5d-965c-4b4f-960b-5eba5931bfa5'::UUID;
    v_r207 UUID := 'e0d00326-e75f-436a-af16-08c8bdcc45b4'::UUID;

    -- Device Types
    v_dt_cctv UUID := 'aefc4364-6c53-4754-b135-22d3941b9a91'::UUID;
    v_dt_light UUID := '7df1efc1-e7c6-407b-b157-991d98d549cc'::UUID;
    v_dt_hvac UUID := '179e1352-b2ce-45e5-9c08-54c5fc6a8dfb'::UUID;
    v_dt_proj UUID := '08b4c919-25df-4c05-b17a-476c9c199ca0'::UUID;
    v_dt_ap UUID := 'bc351c93-f767-4900-ad9d-a6054fd78085'::UUID;
    v_dt_audio UUID := '151bb56a-f8b3-414b-b109-2f4dd2c88010'::UUID;
    v_dt_fan UUID := 'cef1e745-3dfa-442a-a36d-b8b218cdb6e3'::UUID;
BEGIN
    -- 1. Ensure First Floor (F1) has CCTV and Audio devices
    -- Assign Corridor CCTV
    UPDATE devices
    SET building_id = v_bldg_academic,
        floor_id = v_floor_f1,
        room_id = NULL,
        device_type_id = v_dt_cctv,
        is_online = TRUE,
        power_state = TRUE
    WHERE id = 'e86ae85b-06a7-42c9-81aa-b05f6c85c61e'::UUID;

    -- Assign Gate Controller to F1 Corridor
    UPDATE devices
    SET building_id = v_bldg_academic,
        floor_id = v_floor_f1,
        room_id = NULL,
        is_online = TRUE,
        power_state = TRUE
    WHERE id = 'd58c9d42-bbc0-4826-90a4-776664c3efa6'::UUID;

    -- 2. Populate Second Floor (F2) with 10 real devices across diverse categories
    -- Device 1: CCTV in Chem Lab 207
    UPDATE devices
    SET building_id = v_bldg_academic,
        floor_id = v_floor_f2,
        room_id = v_r207,
        device_type_id = v_dt_cctv,
        is_online = TRUE,
        power_state = TRUE
    WHERE id = '0f07bd75-ad54-448e-adfe-e78fe64e7201'::UUID;

    -- Device 2: CCTV in Corridor F2
    UPDATE devices
    SET building_id = v_bldg_academic,
        floor_id = v_floor_f2,
        room_id = NULL,
        device_type_id = v_dt_cctv,
        is_online = TRUE,
        power_state = TRUE
    WHERE id = 'ad2bb546-1894-4473-9a89-b69265edd374'::UUID;

    -- Device 3: Lighting in Room 201
    UPDATE devices
    SET building_id = v_bldg_academic,
        floor_id = v_floor_f2,
        room_id = v_r201,
        device_type_id = v_dt_light,
        is_online = TRUE,
        power_state = TRUE
    WHERE id = 'c117f889-9271-4502-b42a-f911a8ea07d1'::UUID;

    -- Device 4: Lighting in Room 202
    UPDATE devices
    SET building_id = v_bldg_academic,
        floor_id = v_floor_f2,
        room_id = v_r202,
        device_type_id = v_dt_light,
        is_online = TRUE,
        power_state = TRUE
    WHERE id = '0ee29679-bf39-4cc9-bb50-2b1fb7377fc7'::UUID;

    -- Device 5: HVAC in Room 201
    UPDATE devices
    SET building_id = v_bldg_academic,
        floor_id = v_floor_f2,
        room_id = v_r201,
        device_type_id = v_dt_hvac,
        is_online = TRUE,
        power_state = TRUE
    WHERE id = 'a9c0710b-fd83-4292-a9c5-636b29f44bdf'::UUID;

    -- Device 6: HVAC in Room 207 (Chemistry Lab)
    UPDATE devices
    SET building_id = v_bldg_academic,
        floor_id = v_floor_f2,
        room_id = v_r207,
        device_type_id = v_dt_hvac,
        is_online = TRUE,
        power_state = TRUE
    WHERE id = 'd069b871-8679-4fe0-98cc-131f3a783ed9'::UUID;

    -- Device 7: Projector in Room 201
    UPDATE devices
    SET building_id = v_bldg_academic,
        floor_id = v_floor_f2,
        room_id = v_r201,
        device_type_id = v_dt_proj,
        is_online = TRUE,
        power_state = TRUE
    WHERE id = '9bbb8881-3603-4e94-b587-41f0f84e89b2'::UUID;

    -- Device 8: Access Point in Room 203
    UPDATE devices
    SET building_id = v_bldg_academic,
        floor_id = v_floor_f2,
        room_id = v_r203,
        device_type_id = v_dt_ap,
        is_online = TRUE,
        power_state = TRUE
    WHERE id = '7e661ab4-8e1c-4ee0-a7ff-1c83b33aaa12'::UUID;

    -- Device 9: Audio / Speaker in Room 202
    UPDATE devices
    SET building_id = v_bldg_academic,
        floor_id = v_floor_f2,
        room_id = v_r202,
        device_type_id = v_dt_audio,
        is_online = TRUE,
        power_state = TRUE
    WHERE id = '0422f91a-82f2-4b8f-8fe1-48cad677fc86'::UUID;

    -- Device 10: Fan in Room 203
    UPDATE devices
    SET building_id = v_bldg_academic,
        floor_id = v_floor_f2,
        room_id = v_r203,
        device_type_id = v_dt_fan,
        is_online = TRUE,
        power_state = TRUE
    WHERE id = '561e5b28-e725-4ffc-9c3e-9bf20781bb3e'::UUID;
END;
$$;
