-- ============================================================================
-- MIGRATION 582: Dynamic Lookups & Space Timeline Integration for Campus Facilities
-- 1. Inserts canonical BOOKING_PURPOSE, BOOKING_STATUS, SPACE_TYPE lookups into lookup_keys & lookup_values
-- 2. Enhances fn_space_booking_get_availability_timeline to support both Rooms & Campus Facilities
-- ============================================================================

DO $$
DECLARE
    v_school_id UUID;
    v_admin_id UUID;
    v_key_id UUID;
BEGIN
    SELECT id INTO v_school_id
    FROM public.schools
    ORDER BY (id = '11111111-1111-1111-1111-111111111111') DESC, created_at ASC
    LIMIT 1;

    IF v_school_id IS NULL THEN
        RETURN;
    END IF;

    SELECT id INTO v_admin_id
    FROM public.profiles
    ORDER BY (id = '10000000-0000-0000-0000-000000000001') DESC,
             (role = 'super_admin') DESC,
             created_at ASC
    LIMIT 1;
    -- 1. BOOKING_PURPOSE
    SELECT id INTO v_key_id FROM public.lookup_keys WHERE key_code = 'BOOKING_PURPOSE' AND school_id = v_school_id;
    IF v_key_id IS NULL THEN
        v_key_id := gen_random_uuid();
        INSERT INTO public.lookup_keys (id, school_id, key_name, key_code, description, key_type, icon, status, created_by)
        VALUES (v_key_id, v_school_id, 'Booking Purpose', 'BOOKING_PURPOSE', 'Permitted purposes and categories for space and facility bookings.', 'SYSTEM', 'calendar_today_rounded', 'ACTIVE', v_admin_id);

        INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, sort_order, status, created_by) VALUES
        (gen_random_uuid(), v_key_id, v_school_id, 'Academic', 'ACADEMIC', 1, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Class / Lecture Instruction', 'CLASS_LECTURE', 2, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Practical / Lab Session', 'PRACTICAL_LAB', 3, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Examination / Assessment', 'EXAMINATION', 4, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Staff / Faculty Meeting', 'STAFF_MEETING', 5, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Workshop / Seminar / Conference', 'WORKSHOP', 6, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Cultural & Club Activity', 'CULTURAL_CLUB', 7, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Sports & Athletic Training', 'SPORTS_ATHLETICS', 8, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Parent-Teacher Orientation', 'PARENT_TEACHER', 9, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Scheduled Maintenance Downtime', 'MAINTENANCE_DOWNTIME', 10, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Other Special Event', 'OTHER_EVENT', 11, 'ACTIVE', v_admin_id);
    END IF;

    -- 2. BOOKING_STATUS
    SELECT id INTO v_key_id FROM public.lookup_keys WHERE key_code = 'BOOKING_STATUS' AND school_id = v_school_id;
    IF v_key_id IS NULL THEN
        v_key_id := gen_random_uuid();
        INSERT INTO public.lookup_keys (id, school_id, key_name, key_code, description, key_type, icon, status, created_by)
        VALUES (v_key_id, v_school_id, 'Booking Status', 'BOOKING_STATUS', 'Workflow statuses for campus space reservation requests.', 'SYSTEM', 'verified_rounded', 'ACTIVE', v_admin_id);

        INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, sort_order, status, created_by) VALUES
        (gen_random_uuid(), v_key_id, v_school_id, 'Confirmed', 'CONFIRMED', 1, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Pending', 'PENDING', 2, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'In Use', 'IN_USE', 3, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Approved', 'APPROVED', 4, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Rejected', 'REJECTED', 5, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Cancelled', 'CANCELLED', 6, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Conflict', 'CONFLICT', 7, 'ACTIVE', v_admin_id);
    END IF;

    -- 3. SPACE_TYPE (combining Room Types and Facility Categories)
    SELECT id INTO v_key_id FROM public.lookup_keys WHERE key_code = 'SPACE_TYPE' AND school_id = v_school_id;
    IF v_key_id IS NULL THEN
        v_key_id := gen_random_uuid();
        INSERT INTO public.lookup_keys (id, school_id, key_name, key_code, description, key_type, icon, status, created_by)
        VALUES (v_key_id, v_school_id, 'Space Type', 'SPACE_TYPE', 'Classification of classrooms, halls, labs and outdoor facilities.', 'SYSTEM', 'meeting_room_rounded', 'ACTIVE', v_admin_id);

        INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, sort_order, status, created_by) VALUES
        (gen_random_uuid(), v_key_id, v_school_id, 'Classroom', 'CLASSROOM', 1, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Smart Classroom', 'SMART_CLASSROOM', 2, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Auditorium', 'AUDITORIUM', 3, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Meeting Room', 'MEETING_ROOM', 4, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Computer Lab', 'COMPUTER_LAB', 5, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Physics Lab', 'PHYSICS_LAB', 6, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Chemistry Lab', 'CHEMISTRY_LAB', 7, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Biology Lab', 'BIOLOGY_LAB', 8, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Sports Facility', 'SPORTS_FACILITY', 9, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Gymnasium', 'GYMNASIUM', 10, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Library Hall', 'LIBRARY_HALL', 11, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Cafeteria Hub', 'CAFETERIA_HUB', 12, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Health Center & Clinic', 'HEALTH_CENTER', 13, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Robotics & FabLab', 'ROBOTICS_LAB', 14, 'ACTIVE', v_admin_id);
    END IF;

END $$;

-- 4. Update fn_space_booking_get_availability_timeline to include both Rooms and Facilities
CREATE OR REPLACE FUNCTION public.fn_space_booking_get_availability_timeline(
    p_school_id UUID,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL,
    p_building_id UUID DEFAULT NULL,
    p_room_type VARCHAR DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_start_date DATE := COALESCE(p_start_date, CURRENT_DATE);
    v_end_date DATE := COALESCE(p_end_date, v_start_date);
    v_result JSONB;
BEGIN
    WITH room_data AS (
        -- Standard Classrooms and Rooms
        SELECT
            r.id AS room_id,
            r.name AS room_name,
            r.room_number,
            r.room_code,
            r.room_type,
            r.max_capacity,
            b.id AS building_id,
            b.name AS building_name,
            b.code AS building_code,
            f.id AS floor_id,
            f.name AS floor_name,
            'room'::TEXT AS space_domain,
            COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'id', sb.id,
                        'booking_ref', sb.booking_ref,
                        'title', sb.title,
                        'purpose', sb.purpose,
                        'start_time', TO_CHAR(sb.start_time, 'HH12:MI AM'),
                        'end_time', TO_CHAR(sb.end_time, 'HH12:MI AM'),
                        'start_datetime', sb.start_datetime,
                        'end_datetime', sb.end_datetime,
                        'booking_date', TO_CHAR(sb.booking_date, 'YYYY-MM-DD'),
                        'duration_minutes', sb.duration_minutes,
                        'organizer_name', sb.organizer_name,
                        'organizer_role', sb.organizer_role,
                        'status', sb.status,
                        'is_approved', sb.is_approved
                    ) ORDER BY sb.start_datetime ASC
                ) FILTER (WHERE sb.id IS NOT NULL),
                '[]'::JSONB
            ) AS bookings
        FROM public.rooms r
        JOIN public.buildings b ON r.building_id = b.id
        LEFT JOIN public.building_floors f ON r.floor_id = f.id
        LEFT JOIN public.space_bookings sb
            ON (sb.room_id = r.id OR sb.facility_id = r.id)
            AND sb.booking_date >= v_start_date
            AND sb.booking_date <= v_end_date
            AND sb.deleted_at IS NULL
            AND sb.is_approved = TRUE
            AND sb.status IN ('Approved', 'Confirmed', 'Checked In', 'In Use')
        WHERE (r.school_id = p_school_id OR p_school_id IS NULL)
          AND r.deleted_at IS NULL
          AND r.is_bookable = TRUE
          AND (p_building_id IS NULL OR r.building_id = p_building_id)
          AND (p_room_type IS NULL OR p_room_type = 'All' OR r.room_type ILIKE p_room_type)
        GROUP BY r.id, r.name, r.room_number, r.room_code, r.room_type, r.max_capacity,
                 b.id, b.name, b.code, f.id, f.name

        UNION ALL

        -- Campus Facilities & Grounds (Gym, Auditorium, Swimming Pool, Labs, etc.)
        SELECT
            cf.id AS room_id,
            cf.name AS room_name,
            cf.code AS room_number,
            cf.code AS room_code,
            COALESCE(cf.category, 'Campus Facility') AS room_type,
            COALESCE(cf.capacity, 100) AS max_capacity,
            COALESCE(b.id, '00000000-0000-0000-0000-000000000000'::UUID) AS building_id,
            COALESCE(b.name, 'Campus Facilities & Grounds') AS building_name,
            COALESCE(b.code, 'FAC') AS building_code,
            cf.floor_id AS floor_id,
            COALESCE(f.name, 'Ground Level') AS floor_name,
            'facility'::TEXT AS space_domain,
            COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'id', sb.id,
                        'booking_ref', sb.booking_ref,
                        'title', sb.title,
                        'purpose', sb.purpose,
                        'start_time', TO_CHAR(sb.start_time, 'HH12:MI AM'),
                        'end_time', TO_CHAR(sb.end_time, 'HH12:MI AM'),
                        'start_datetime', sb.start_datetime,
                        'end_datetime', sb.end_datetime,
                        'booking_date', TO_CHAR(sb.booking_date, 'YYYY-MM-DD'),
                        'duration_minutes', sb.duration_minutes,
                        'organizer_name', sb.organizer_name,
                        'organizer_role', sb.organizer_role,
                        'status', sb.status,
                        'is_approved', sb.is_approved
                    ) ORDER BY sb.start_datetime ASC
                ) FILTER (WHERE sb.id IS NOT NULL),
                '[]'::JSONB
            ) AS bookings
        FROM public.campus_facilities cf
        LEFT JOIN public.buildings b ON cf.building_id = b.id
        LEFT JOIN public.building_floors f ON cf.floor_id = f.id
        LEFT JOIN public.space_bookings sb
            ON (sb.facility_id = cf.id OR sb.room_id = cf.id)
            AND sb.booking_date >= v_start_date
            AND sb.booking_date <= v_end_date
            AND sb.deleted_at IS NULL
            AND sb.is_approved = TRUE
            AND sb.status IN ('Approved', 'Confirmed', 'Checked In', 'In Use')
        WHERE (cf.school_id = p_school_id OR p_school_id IS NULL)
          AND cf.deleted_at IS NULL
          AND (p_building_id IS NULL OR cf.building_id = p_building_id)
          AND (p_room_type IS NULL OR p_room_type = 'All' OR cf.category ILIKE p_room_type)
        GROUP BY cf.id, cf.name, cf.code, cf.category, cf.capacity,
                 b.id, b.name, b.code, f.id, f.name
        ORDER BY
            CASE
                WHEN room_name ILIKE '%Grade 4%' OR room_number = '201' THEN 0
                WHEN room_name ILIKE '%Classroom%' THEN 1
                WHEN room_name ILIKE '%Lab%' THEN 2
                ELSE 3
            END ASC,
            max_capacity DESC
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'room_id', rd.room_id,
            'room_name', rd.room_name,
            'room_number', rd.room_number,
            'room_code', rd.room_code,
            'room_type', rd.room_type,
            'capacity', rd.max_capacity,
            'building_id', rd.building_id,
            'building_name', rd.building_name,
            'building_code', rd.building_code,
            'floor_id', rd.floor_id,
            'floor_name', rd.floor_name,
            'space_domain', rd.space_domain,
            'bookings', rd.bookings
        )
    ) INTO v_result
    FROM room_data rd;

    RETURN COALESCE(v_result, '[]'::JSONB);
END;
$$;
