-- ==============================================================================
-- Migration: 406_sync_hostel_room_and_bed_availability.sql
-- Description: Unify Single Source of Truth for room capacity, occupied beds,
--              and available beds. Eliminate any mismatch between room dropdowns
--              and bed selection lists. Automatically assign orphaned allocations,
--              keep bed status and room occupancy synchronized via triggers.
-- ==============================================================================

-- 1. Assign orphaned allocations (where bed_id IS NULL) to available beds in their room
DO $$
DECLARE
    r_alloc RECORD;
    v_target_bed_id UUID;
BEGIN
    FOR r_alloc IN 
        SELECT a.id, a.room_id, a.student_id 
        FROM public.hostel_allocations a
        WHERE a.bed_id IS NULL 
          AND a.room_id IS NOT NULL 
          AND a.deleted_at IS NULL 
          AND a.allocation_status IN ('RESERVED', 'CONFIRMED', 'CHECKED_IN', 'TEMPORARILY_RELOCATED')
        ORDER BY a.created_at ASC
    LOOP
        -- Find the first available bed in that room
        SELECT b.id INTO v_target_bed_id
        FROM public.hostel_beds b
        WHERE b.room_id = r_alloc.room_id
          AND b.deleted_at IS NULL
          AND b.status = 'AVAILABLE'
          AND NOT EXISTS (
              SELECT 1 FROM public.hostel_allocations alc
              WHERE alc.bed_id = b.id
                AND alc.deleted_at IS NULL
                AND alc.allocation_status IN ('RESERVED', 'CONFIRMED', 'CHECKED_IN', 'TEMPORARILY_RELOCATED')
          )
        ORDER BY b.bed_code ASC
        LIMIT 1;

        IF v_target_bed_id IS NOT NULL THEN
            UPDATE public.hostel_allocations
            SET bed_id = v_target_bed_id,
                updated_at = NOW()
            WHERE id = r_alloc.id;

            UPDATE public.hostel_beds
            SET status = 'OCCUPIED',
                updated_at = NOW()
            WHERE id = v_target_bed_id;
        END IF;
    END LOOP;
END;
$$;

-- 2. Synchronize all bed statuses based on actual active allocations
-- Mark beds as OCCUPIED if there is an active allocation
UPDATE public.hostel_beds b
SET status = 'OCCUPIED',
    updated_at = NOW()
WHERE b.deleted_at IS NULL
  AND b.status <> 'OCCUPIED'
  AND EXISTS (
      SELECT 1 FROM public.hostel_allocations a
      WHERE a.bed_id = b.id
        AND a.deleted_at IS NULL
        AND a.allocation_status IN ('RESERVED', 'CONFIRMED', 'CHECKED_IN', 'TEMPORARILY_RELOCATED')
  );

-- Mark beds as AVAILABLE if they were marked OCCUPIED but have NO active allocations
UPDATE public.hostel_beds b
SET status = 'AVAILABLE',
    updated_at = NOW()
WHERE b.deleted_at IS NULL
  AND b.status = 'OCCUPIED'
  AND NOT EXISTS (
      SELECT 1 FROM public.hostel_allocations a
      WHERE a.bed_id = b.id
        AND a.deleted_at IS NULL
        AND a.allocation_status IN ('RESERVED', 'CONFIRMED', 'CHECKED_IN', 'TEMPORARILY_RELOCATED')
  );

-- 3. Robust Trigger Function to maintain bed status and room occupancy on allocation changes
CREATE OR REPLACE FUNCTION public.fn_hostel_sync_bed_and_room_occupancy()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_room_id UUID;
    v_old_room_id UUID;
    v_free_bed_id UUID;
BEGIN
    -- Handle INSERT or UPDATE
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        v_room_id := NEW.room_id;

        -- If allocation has room_id but bed_id is NULL, auto-assign an available bed
        IF NEW.room_id IS NOT NULL AND NEW.bed_id IS NULL AND NEW.deleted_at IS NULL 
           AND NEW.allocation_status IN ('RESERVED', 'CONFIRMED', 'CHECKED_IN', 'TEMPORARILY_RELOCATED') THEN
            SELECT b.id INTO v_free_bed_id
            FROM public.hostel_beds b
            WHERE b.room_id = NEW.room_id
              AND b.deleted_at IS NULL
              AND b.status = 'AVAILABLE'
              AND NOT EXISTS (
                  SELECT 1 FROM public.hostel_allocations alc
                  WHERE alc.bed_id = b.id
                    AND alc.id <> COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::UUID)
                    AND alc.deleted_at IS NULL
                    AND alc.allocation_status IN ('RESERVED', 'CONFIRMED', 'CHECKED_IN', 'TEMPORARILY_RELOCATED')
              )
            ORDER BY b.bed_code ASC
            LIMIT 1;

            IF v_free_bed_id IS NOT NULL THEN
                NEW.bed_id := v_free_bed_id;
            END IF;
        END IF;

        -- If active allocation has bed_id, mark that bed as OCCUPIED
        IF NEW.bed_id IS NOT NULL AND NEW.deleted_at IS NULL 
           AND NEW.allocation_status IN ('RESERVED', 'CONFIRMED', 'CHECKED_IN', 'TEMPORARILY_RELOCATED') THEN
            UPDATE public.hostel_beds
            SET status = 'OCCUPIED', updated_at = NOW()
            WHERE id = NEW.bed_id AND status <> 'OCCUPIED';
        END IF;

        -- If checked out, expired, cancelled, or soft deleted, free the bed
        IF (NEW.deleted_at IS NOT NULL OR NEW.allocation_status IN ('CHECKED_OUT', 'CANCELLED', 'EXPIRED')) 
           AND NEW.bed_id IS NOT NULL THEN
            IF NOT EXISTS (
                SELECT 1 FROM public.hostel_allocations alc
                WHERE alc.bed_id = NEW.bed_id
                  AND alc.id <> NEW.id
                  AND alc.deleted_at IS NULL
                  AND alc.allocation_status IN ('RESERVED', 'CONFIRMED', 'CHECKED_IN', 'TEMPORARILY_RELOCATED')
            ) THEN
                UPDATE public.hostel_beds
                SET status = 'AVAILABLE', updated_at = NOW()
                WHERE id = NEW.bed_id AND status <> 'AVAILABLE';
            END IF;
        END IF;

        -- If bed changed on UPDATE, release the old bed
        IF TG_OP = 'UPDATE' AND OLD.bed_id IS NOT NULL AND OLD.bed_id <> NEW.bed_id THEN
            IF NOT EXISTS (
                SELECT 1 FROM public.hostel_allocations alc
                WHERE alc.bed_id = OLD.bed_id
                  AND alc.id <> NEW.id
                  AND alc.deleted_at IS NULL
                  AND alc.allocation_status IN ('RESERVED', 'CONFIRMED', 'CHECKED_IN', 'TEMPORARILY_RELOCATED')
            ) THEN
                UPDATE public.hostel_beds
                SET status = 'AVAILABLE', updated_at = NOW()
                WHERE id = OLD.bed_id AND status <> 'AVAILABLE';
            END IF;
        END IF;

        -- Recalculate occupancy for current room
        IF v_room_id IS NOT NULL THEN
            PERFORM public.fn_hostel_recalculate_room_occupancy(v_room_id);
        END IF;

        -- If room changed, recalculate for old room too
        IF TG_OP = 'UPDATE' AND OLD.room_id IS NOT NULL AND OLD.room_id <> NEW.room_id THEN
            PERFORM public.fn_hostel_recalculate_room_occupancy(OLD.room_id);
        END IF;

        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        -- Release the bed if no other active allocation uses it
        IF OLD.bed_id IS NOT NULL THEN
            IF NOT EXISTS (
                SELECT 1 FROM public.hostel_allocations alc
                WHERE alc.bed_id = OLD.bed_id
                  AND alc.id <> OLD.id
                  AND alc.deleted_at IS NULL
                  AND alc.allocation_status IN ('RESERVED', 'CONFIRMED', 'CHECKED_IN', 'TEMPORARILY_RELOCATED')
            ) THEN
                UPDATE public.hostel_beds
                SET status = 'AVAILABLE', updated_at = NOW()
                WHERE id = OLD.bed_id AND status <> 'AVAILABLE';
            END IF;
        END IF;

        IF OLD.room_id IS NOT NULL THEN
            PERFORM public.fn_hostel_recalculate_room_occupancy(OLD.room_id);
        END IF;

        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_hostel_sync_bed_and_room_occupancy ON public.hostel_allocations;
CREATE TRIGGER trg_hostel_sync_bed_and_room_occupancy
BEFORE INSERT OR UPDATE OR DELETE ON public.hostel_allocations
FOR EACH ROW
EXECUTE FUNCTION public.fn_hostel_sync_bed_and_room_occupancy();


-- 4. Update fn_hostel_recalculate_room_occupancy
CREATE OR REPLACE FUNCTION public.fn_hostel_recalculate_room_occupancy(p_room_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_is_residential BOOLEAN;
    v_target_capacity INT;
    v_active_beds INT := 0;
    v_active_allocations INT := 0;
    v_maint_count INT := 0;
    v_room_status VARCHAR(30) := 'AVAILABLE';
BEGIN
    SELECT is_residential, target_capacity INTO v_is_residential, v_target_capacity
    FROM public.hostel_rooms
    WHERE id = p_room_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    -- Count open maintenance tickets that block allocation
    SELECT COUNT(*) INTO v_maint_count
    FROM public.hostel_maintenance_tickets
    WHERE room_id = p_room_id AND deleted_at IS NULL AND blocks_allocation = TRUE 
      AND status NOT IN ('RESOLVED', 'CLOSED', 'CANCELLED');

    IF NOT v_is_residential THEN
        IF v_maint_count > 0 THEN
            v_room_status := 'MAINTENANCE';
        ELSE
            v_room_status := 'OPERATIONAL';
        END IF;

        UPDATE public.hostel_rooms
        SET target_capacity = 0,
            current_occupancy = 0,
            operational_status = v_room_status,
            updated_at = NOW()
        WHERE id = p_room_id;
        RETURN;
    END IF;

    -- Residential room: count active beds
    SELECT COUNT(*) INTO v_active_beds
    FROM public.hostel_beds
    WHERE room_id = p_room_id AND deleted_at IS NULL AND status NOT IN ('RETIRED', 'OUT_OF_SERVICE');

    -- Count active allocations
    SELECT COUNT(*) INTO v_active_allocations
    FROM public.hostel_allocations
    WHERE room_id = p_room_id 
      AND deleted_at IS NULL 
      AND allocation_status IN ('RESERVED', 'CONFIRMED', 'CHECKED_IN', 'TEMPORARILY_RELOCATED');

    IF v_maint_count > 0 THEN
        v_room_status := 'MAINTENANCE';
    ELSIF v_active_allocations >= GREATEST(v_active_beds, v_target_capacity) AND GREATEST(v_active_beds, v_target_capacity) > 0 THEN
        v_room_status := 'OCCUPIED';
    ELSIF v_active_allocations > 0 THEN
        v_room_status := 'AVAILABLE';
    ELSE
        v_room_status := 'AVAILABLE';
    END IF;

    UPDATE public.hostel_rooms
    SET target_capacity = GREATEST(v_active_beds, target_capacity),
        current_occupancy = v_active_allocations,
        operational_status = v_room_status,
        updated_at = NOW()
    WHERE id = p_room_id;
END;
$$;


-- 5. Update fn_hostel_get_rooms to compute capacity, occupied, and available_beds 
--    strictly from public.hostel_beds and active allocations
CREATE OR REPLACE FUNCTION public.fn_hostel_get_rooms(
    p_school_id UUID,
    p_search VARCHAR DEFAULT '',
    p_building_id UUID DEFAULT NULL,
    p_floor_id UUID DEFAULT NULL,
    p_room_type VARCHAR DEFAULT 'ALL',
    p_status VARCHAR DEFAULT 'ALL',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_sort_by VARCHAR DEFAULT 'room_number',
    p_sort_order VARCHAR DEFAULT 'ASC'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_offset INT := (GREATEST(p_page, 1) - 1) * p_page_size;
    v_total_records INT := 0;
    v_rooms JSONB := '[]'::JSONB;
    v_selected_context TEXT := 'All Rooms';
BEGIN
    IF p_floor_id IS NOT NULL THEN
        SELECT (f.floor_name || ', ' || b.name) INTO v_selected_context
        FROM public.hostel_floors f
        JOIN public.hostel_buildings b ON f.building_id = b.id
        WHERE f.id = p_floor_id;
    ELSIF p_building_id IS NOT NULL THEN
        SELECT b.name INTO v_selected_context
        FROM public.hostel_buildings b
        WHERE b.id = p_building_id;
    END IF;

    SELECT COUNT(*) INTO v_total_records
    FROM public.hostel_rooms r
    JOIN public.hostel_buildings b ON r.building_id = b.id
    JOIN public.hostel_floors f ON r.floor_id = f.id
    WHERE r.school_id = p_school_id
      AND r.deleted_at IS NULL
      AND (p_building_id IS NULL OR r.building_id = p_building_id)
      AND (p_floor_id IS NULL OR r.floor_id = p_floor_id)
      AND (
          p_search = '' 
          OR r.room_number ILIKE '%' || p_search || '%'
          OR r.room_code ILIKE '%' || p_search || '%'
          OR r.room_type ILIKE '%' || p_search || '%'
          OR b.name ILIKE '%' || p_search || '%'
          OR f.floor_name ILIKE '%' || p_search || '%'
      )
      AND (p_room_type = 'ALL' OR p_room_type = '' OR UPPER(TRIM(r.room_type)) = UPPER(TRIM(p_room_type)))
      AND (p_status = 'ALL' OR p_status = '' OR UPPER(TRIM(r.operational_status)) = UPPER(TRIM(p_status)));

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', r.id,
                'building_id', r.building_id,
                'building_name', b.name,
                'floor_id', r.floor_id,
                'floor_name', f.floor_name,
                'room_number', r.room_number,
                'room_code', r.room_code,
                'room_name', r.room_name,
                'room_type', r.room_type,
                'is_residential', r.is_residential,
                'capacity', CASE 
                    WHEN r.is_residential THEN GREATEST(r.target_capacity, COALESCE((SELECT COUNT(*) FROM public.hostel_beds bd WHERE bd.room_id = r.id AND bd.deleted_at IS NULL), 0))
                    ELSE NULL 
                END,
                'occupied', CASE 
                    WHEN r.is_residential THEN (
                        SELECT COUNT(*) FROM public.hostel_beds bd
                        WHERE bd.room_id = r.id AND bd.deleted_at IS NULL
                          AND (bd.status = 'OCCUPIED' OR EXISTS (
                              SELECT 1 FROM public.hostel_allocations alc
                              WHERE alc.bed_id = bd.id AND alc.deleted_at IS NULL
                                AND alc.allocation_status IN ('RESERVED', 'CONFIRMED', 'CHECKED_IN', 'TEMPORARILY_RELOCATED')
                          ))
                    )
                    ELSE NULL 
                END,
                'available_beds', CASE 
                    WHEN r.is_residential THEN (
                        SELECT COUNT(*) FROM public.hostel_beds bd
                        WHERE bd.room_id = r.id AND bd.deleted_at IS NULL
                          AND bd.status = 'AVAILABLE'
                          AND NOT EXISTS (
                              SELECT 1 FROM public.hostel_allocations alc
                              WHERE alc.bed_id = bd.id AND alc.deleted_at IS NULL
                                AND alc.allocation_status IN ('RESERVED', 'CONFIRMED', 'CHECKED_IN', 'TEMPORARILY_RELOCATED')
                          )
                    )
                    ELSE NULL 
                END,
                'capacity_label', CASE 
                    WHEN r.is_residential THEN GREATEST(r.target_capacity, COALESCE((SELECT COUNT(*) FROM public.hostel_beds bd WHERE bd.room_id = r.id AND bd.deleted_at IS NULL), 0))::TEXT
                    ELSE '-' 
                END,
                'occupied_label', CASE 
                    WHEN r.is_residential THEN (
                        SELECT COUNT(*) FROM public.hostel_beds bd
                        WHERE bd.room_id = r.id AND bd.deleted_at IS NULL
                          AND (bd.status = 'OCCUPIED' OR EXISTS (
                              SELECT 1 FROM public.hostel_allocations alc
                              WHERE alc.bed_id = bd.id AND alc.deleted_at IS NULL
                                AND alc.allocation_status IN ('RESERVED', 'CONFIRMED', 'CHECKED_IN', 'TEMPORARILY_RELOCATED')
                          ))
                    )::TEXT
                    ELSE '-' 
                END,
                'status', r.operational_status,
                'cleanliness_status', r.cleanliness_status,
                'condition_status', r.condition_status,
                'room_size_sqm', r.room_size_sqm,
                'monthly_fee', r.monthly_fee,
                'gender_restriction', r.gender_restriction,
                'photos_count', jsonb_array_length(r.photos),
                'photos', r.photos,
                'facilities_summary', (
                    SELECT COALESCE(
                        jsonb_agg(
                            jsonb_build_object(
                                'name', eq.equipment_name,
                                'status', eq.status,
                                'quantity', eq.quantity
                            )
                        ),
                        '[]'::JSONB
                    )
                    FROM public.hostel_room_equipment eq
                    WHERE eq.room_id = r.id AND eq.deleted_at IS NULL
                )
            )
        ),
        '[]'::JSONB
    ) INTO v_rooms
    FROM (
        SELECT r.*
        FROM public.hostel_rooms r
        JOIN public.hostel_buildings b ON r.building_id = b.id
        JOIN public.hostel_floors f ON r.floor_id = f.id
        WHERE r.school_id = p_school_id
          AND r.deleted_at IS NULL
          AND (p_building_id IS NULL OR r.building_id = p_building_id)
          AND (p_floor_id IS NULL OR r.floor_id = p_floor_id)
          AND (
              p_search = '' 
              OR r.room_number ILIKE '%' || p_search || '%'
              OR r.room_code ILIKE '%' || p_search || '%'
              OR r.room_type ILIKE '%' || p_search || '%'
              OR b.name ILIKE '%' || p_search || '%'
              OR f.floor_name ILIKE '%' || p_search || '%'
          )
          AND (p_room_type = 'ALL' OR p_room_type = '' OR UPPER(TRIM(r.room_type)) = UPPER(TRIM(p_room_type)))
          AND (p_status = 'ALL' OR p_status = '' OR UPPER(TRIM(r.operational_status)) = UPPER(TRIM(p_status)))
        ORDER BY 
            CASE WHEN p_sort_by = 'room_number' AND UPPER(p_sort_order) = 'ASC' THEN r.room_number END ASC,
            CASE WHEN p_sort_by = 'room_number' AND UPPER(p_sort_order) = 'DESC' THEN r.room_number END DESC,
            CASE WHEN p_sort_by = 'room_type' AND UPPER(p_sort_order) = 'ASC' THEN r.room_type END ASC,
            CASE WHEN p_sort_by = 'room_type' AND UPPER(p_sort_order) = 'DESC' THEN r.room_type END DESC,
            r.room_number ASC
        LIMIT p_page_size
        OFFSET v_offset
    ) r
    JOIN public.hostel_buildings b ON r.building_id = b.id
    JOIN public.hostel_floors f ON r.floor_id = f.id;

    RETURN jsonb_build_object(
        'data', v_rooms,
        'pagination', jsonb_build_object(
            'page', p_page,
            'page_size', p_page_size,
            'total_records', v_total_records,
            'total_pages', CEIL(v_total_records::FLOAT / p_page_size)
        ),
        'context_title', v_selected_context
    );
END;
$$;


-- 6. Update fn_hostel_get_room_detail to guarantee bed status reflects active allocations
CREATE OR REPLACE FUNCTION public.fn_hostel_get_room_detail(
    p_school_id UUID,
    p_room_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_room RECORD;
    v_beds JSONB := '[]'::JSONB;
    v_facilities JSONB := '[]'::JSONB;
    v_students JSONB := '[]'::JSONB;
    v_maintenance JSONB := '[]'::JSONB;
    v_history JSONB := '[]'::JSONB;
    v_existing_bed_count INT;
    i INT;
    v_bed_code VARCHAR(50);
BEGIN
    SELECT 
        r.*, 
        b.name AS building_name,
        b.hostel_name,
        f.floor_name
    INTO v_room
    FROM public.hostel_rooms r
    JOIN public.hostel_buildings b ON r.building_id = b.id
    JOIN public.hostel_floors f ON r.floor_id = f.id
    WHERE r.id = p_room_id AND r.school_id = p_school_id AND r.deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Room not found');
    END IF;

    -- Ensure beds exist if residential and target_capacity > 0
    IF v_room.is_residential AND v_room.target_capacity > 0 THEN
        SELECT COUNT(*) INTO v_existing_bed_count
        FROM public.hostel_beds
        WHERE room_id = p_room_id AND deleted_at IS NULL;

        IF v_existing_bed_count = 0 THEN
            FOR i IN 1..v_room.target_capacity LOOP
                v_bed_code := 'Bed ' || i;
                INSERT INTO public.hostel_beds (
                    school_id, building_id, floor_id, room_id, bed_code, bed_type,
                    condition, status, monthly_fee
                ) VALUES (
                    p_school_id, v_room.building_id, v_room.floor_id, p_room_id,
                    v_bed_code, 'Single', 'GOOD', 'AVAILABLE', COALESCE(v_room.monthly_fee, 6000.0)
                )
                ON CONFLICT (room_id, UPPER(bed_code)) WHERE deleted_at IS NULL DO NOTHING;
            END LOOP;
        END IF;
    END IF;

    -- Fetch Beds with accurate live status
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', bd.id,
                'bed_code', bd.bed_code,
                'bed_type', bd.bed_type,
                'condition', bd.condition,
                'status', CASE 
                    WHEN EXISTS (
                        SELECT 1 FROM public.hostel_allocations a 
                        WHERE a.bed_id = bd.id 
                          AND a.deleted_at IS NULL 
                          AND a.allocation_status IN ('RESERVED', 'CONFIRMED', 'CHECKED_IN', 'TEMPORARILY_RELOCATED')
                    ) THEN 'OCCUPIED'
                    ELSE bd.status 
                END,
                'monthly_fee', bd.monthly_fee,
                'occupant', (
                    SELECT jsonb_build_object(
                        'student_id', p.id,
                        'full_name', p.full_name,
                        'email', p.email,
                        'avatar_url', p.avatar_url,
                        'check_in_date', a.check_in_date,
                        'allocation_id', a.id
                    )
                    FROM public.hostel_allocations a
                    JOIN public.profiles p ON a.student_id = p.id
                    WHERE a.bed_id = bd.id 
                      AND a.deleted_at IS NULL 
                      AND a.allocation_status IN ('RESERVED', 'CONFIRMED', 'CHECKED_IN', 'TEMPORARILY_RELOCATED')
                    LIMIT 1
                )
            ) ORDER BY bd.bed_code ASC
        ),
        '[]'::JSONB
    ) INTO v_beds
    FROM public.hostel_beds bd
    WHERE bd.room_id = p_room_id AND bd.deleted_at IS NULL;

    -- Fetch Facilities / Equipment
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', eq.id,
                'name', eq.equipment_name,
                'category', eq.equipment_category,
                'quantity', eq.quantity,
                'status', eq.status,
                'is_critical', eq.is_critical,
                'notes', eq.notes
            ) ORDER BY eq.equipment_name ASC
        ),
        '[]'::JSONB
    ) INTO v_facilities
    FROM public.hostel_room_equipment eq
    WHERE eq.room_id = p_room_id AND eq.deleted_at IS NULL;

    -- Fetch Students Allocated
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'student_id', p.id,
                'full_name', p.full_name,
                'admission_number', p.admission_number,
                'class_name', COALESCE(p.class, '10 A'),
                'bed_code', bd.bed_code,
                'check_in_date', a.check_in_date,
                'status', a.allocation_status
            ) ORDER BY bd.bed_code ASC
        ),
        '[]'::JSONB
    ) INTO v_students
    FROM public.hostel_allocations a
    JOIN public.profiles p ON a.student_id = p.id
    LEFT JOIN public.hostel_beds bd ON a.bed_id = bd.id
    WHERE a.room_id = p_room_id 
      AND a.deleted_at IS NULL 
      AND a.allocation_status IN ('RESERVED', 'CONFIRMED', 'CHECKED_IN', 'TEMPORARILY_RELOCATED');

    -- Fetch Open Maintenance Tickets
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', mt.id,
                'ticket_number', mt.ticket_number,
                'category', 'Maintenance',
                'title', mt.title,
                'priority', mt.priority,
                'status', mt.status,
                'assigned_to_name', p.full_name,
                'created_at', mt.created_at
            ) ORDER BY mt.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_maintenance
    FROM public.hostel_maintenance_tickets mt
    LEFT JOIN public.profiles p ON mt.assigned_to = p.id
    WHERE mt.room_id = p_room_id AND mt.deleted_at IS NULL AND mt.status NOT IN ('RESOLVED', 'CLOSED', 'CANCELLED');

    -- Fetch Recent Allocation History Events
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', ev.id,
                'event_type', ev.event_type,
                'student_name', p.full_name,
                'from_bed', b_from.bed_code,
                'to_bed', b_to.bed_code,
                'event_date', ev.created_at,
                'reason', ev.reason
            ) ORDER BY ev.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_history
    FROM public.hostel_allocation_events ev
    JOIN public.profiles p ON ev.student_id = p.id
    LEFT JOIN public.hostel_beds b_from ON ev.from_bed_id = b_from.id
    LEFT JOIN public.hostel_beds b_to ON ev.to_bed_id = b_to.id
    WHERE (ev.room_id = p_room_id OR ev.from_room_id = p_room_id OR ev.to_room_id = p_room_id)
    LIMIT 10;

    -- Recalculate room occupancy & status
    PERFORM public.fn_hostel_recalculate_room_occupancy(p_room_id);

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'room', jsonb_build_object(
                'id', v_room.id,
                'building_id', v_room.building_id,
                'building_name', v_room.building_name,
                'floor_id', v_room.floor_id,
                'floor_name', v_room.floor_name,
                'room_number', v_room.room_number,
                'room_code', v_room.room_code,
                'room_name', v_room.room_name,
                'room_type', v_room.room_type,
                'is_residential', v_room.is_residential,
                'capacity', v_room.target_capacity,
                'current_occupancy', (
                    SELECT COUNT(*) FROM public.hostel_beds bd
                    WHERE bd.room_id = p_room_id AND bd.deleted_at IS NULL
                      AND (bd.status = 'OCCUPIED' OR EXISTS (
                          SELECT 1 FROM public.hostel_allocations alc
                          WHERE alc.bed_id = bd.id AND alc.deleted_at IS NULL
                            AND alc.allocation_status IN ('RESERVED', 'CONFIRMED', 'CHECKED_IN', 'TEMPORARILY_RELOCATED')
                      ))
                ),
                'available_beds', (
                    SELECT COUNT(*) FROM public.hostel_beds bd
                    WHERE bd.room_id = p_room_id AND bd.deleted_at IS NULL
                      AND bd.status = 'AVAILABLE'
                      AND NOT EXISTS (
                          SELECT 1 FROM public.hostel_allocations alc
                          WHERE alc.bed_id = bd.id AND alc.deleted_at IS NULL
                            AND alc.allocation_status IN ('RESERVED', 'CONFIRMED', 'CHECKED_IN', 'TEMPORARILY_RELOCATED')
                      )
                ),
                'operational_status', v_room.operational_status,
                'cleanliness_status', v_room.cleanliness_status,
                'condition_status', v_room.condition_status,
                'room_size_sqm', v_room.room_size_sqm,
                'monthly_fee', v_room.monthly_fee,
                'gender_restriction', v_room.gender_restriction,
                'photos', v_room.photos,
                'map_coordinates', v_room.map_coordinates,
                'inspection_schedule', v_room.inspection_schedule,
                'maintenance_rules', v_room.maintenance_rules
            ),
            'beds', v_beds,
            'facilities', v_facilities,
            'students', v_students,
            'open_maintenance_tickets', v_maintenance,
            'allocation_history', v_history
        )
    );
END;
$$;

-- 7. Trigger a recalculation for all residential rooms right now
DO $$
DECLARE
    r_room RECORD;
BEGIN
    FOR r_room IN SELECT id FROM public.hostel_rooms WHERE is_residential = TRUE AND deleted_at IS NULL LOOP
        PERFORM public.fn_hostel_recalculate_room_occupancy(r_room.id);
    END LOOP;
END;
$$;
