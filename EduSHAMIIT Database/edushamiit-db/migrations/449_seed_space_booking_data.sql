-- ============================================================================
-- Migration: 449_seed_space_booking_data.sql
-- Description: Seeds space bookings for Greenwood High School matching exact UI
-- ============================================================================

DO $$
DECLARE
    v_school_id UUID := '11111111-1111-1111-1111-111111111111';
    v_admin_id UUID;
    v_building_id UUID;
    v_floor_id UUID;
    v_room_g101 UUID;
    v_room_g102 UUID;
    v_room_seminar UUID;
    v_room_conf UUID;
    v_room_complab UUID;
    v_date DATE := '2026-03-15';
    i INT;
    v_rand_room UUID;
    v_rooms_list UUID[];
BEGIN
    -- 1. Get or verify Admin Profile
    SELECT id INTO v_admin_id FROM public.profiles WHERE school_id = v_school_id LIMIT 1;
    IF v_admin_id IS NULL THEN
        SELECT id INTO v_admin_id FROM public.profiles LIMIT 1;
    END IF;

    -- 2. Ensure Academic Block building exists
    SELECT id INTO v_building_id 
    FROM public.buildings 
    WHERE school_id = v_school_id AND (code = 'B1' OR name ILIKE '%Academic Block%')
    LIMIT 1;

    IF v_building_id IS NULL THEN
        SELECT id INTO v_building_id FROM public.buildings WHERE school_id = v_school_id LIMIT 1;
    END IF;

    -- 3. Ensure Ground Floor exists
    SELECT id INTO v_floor_id 
    FROM public.building_floors 
    WHERE building_id = v_building_id 
    ORDER BY floor_level ASC 
    LIMIT 1;

    -- 4. Find or Create the specific rooms shown on the screenshot
    -- Room G-101 (Classroom, cap 40)
    SELECT id INTO v_room_g101 FROM public.rooms 
    WHERE school_id = v_school_id AND (room_number = 'G-101' OR name = 'G-101') LIMIT 1;
    IF v_room_g101 IS NULL THEN
        INSERT INTO public.rooms (
            school_id, building_id, floor_id, name, room_number, room_code, 
            room_type, max_capacity, operational_status, is_bookable, created_by
        ) VALUES (
            v_school_id, v_building_id, v_floor_id, 'G-101', 'G-101', 'B1-G101',
            'Classroom', 40, 'Active', TRUE, v_admin_id
        ) RETURNING id INTO v_room_g101;
    ELSE
        UPDATE public.rooms SET max_capacity = 40, room_type = 'Classroom', is_bookable = TRUE WHERE id = v_room_g101;
    END IF;

    -- Room G-102 (Classroom, cap 40)
    SELECT id INTO v_room_g102 FROM public.rooms 
    WHERE school_id = v_school_id AND (room_number = 'G-102' OR name = 'G-102') LIMIT 1;
    IF v_room_g102 IS NULL THEN
        INSERT INTO public.rooms (
            school_id, building_id, floor_id, name, room_number, room_code, 
            room_type, max_capacity, operational_status, is_bookable, created_by
        ) VALUES (
            v_school_id, v_building_id, v_floor_id, 'G-102', 'G-102', 'B1-G102',
            'Classroom', 40, 'Active', TRUE, v_admin_id
        ) RETURNING id INTO v_room_g102;
    ELSE
        UPDATE public.rooms SET max_capacity = 40, room_type = 'Classroom', is_bookable = TRUE WHERE id = v_room_g102;
    END IF;

    -- Seminar Hall (Auditorium, cap 200)
    SELECT id INTO v_room_seminar FROM public.rooms 
    WHERE school_id = v_school_id AND (name ILIKE '%Seminar Hall%' OR room_number = 'SH-1') LIMIT 1;
    IF v_room_seminar IS NULL THEN
        INSERT INTO public.rooms (
            school_id, building_id, floor_id, name, room_number, room_code, 
            room_type, max_capacity, operational_status, is_bookable, created_by
        ) VALUES (
            v_school_id, v_building_id, v_floor_id, 'Seminar Hall', 'SH-1', 'B1-SH1',
            'Auditorium', 200, 'Active', TRUE, v_admin_id
        ) RETURNING id INTO v_room_seminar;
    ELSE
        UPDATE public.rooms SET max_capacity = 200, room_type = 'Auditorium', is_bookable = TRUE WHERE id = v_room_seminar;
    END IF;

    -- Conference Room (Meeting Room, cap 20)
    SELECT id INTO v_room_conf FROM public.rooms 
    WHERE school_id = v_school_id AND (name ILIKE '%Conference Room%' OR room_number = 'CR-1') LIMIT 1;
    IF v_room_conf IS NULL THEN
        INSERT INTO public.rooms (
            school_id, building_id, floor_id, name, room_number, room_code, 
            room_type, max_capacity, operational_status, is_bookable, created_by
        ) VALUES (
            v_school_id, v_building_id, v_floor_id, 'Conference Room', 'CR-1', 'B1-CR1',
            'Meeting Room', 20, 'Active', TRUE, v_admin_id
        ) RETURNING id INTO v_room_conf;
    ELSE
        UPDATE public.rooms SET max_capacity = 20, room_type = 'Meeting Room', is_bookable = TRUE WHERE id = v_room_conf;
    END IF;

    -- Computer Lab - 1 (Lab, cap 30)
    SELECT id INTO v_room_complab FROM public.rooms 
    WHERE school_id = v_school_id AND (name ILIKE '%Computer Lab - 1%' OR room_number = 'CL-1') LIMIT 1;
    IF v_room_complab IS NULL THEN
        INSERT INTO public.rooms (
            school_id, building_id, floor_id, name, room_number, room_code, 
            room_type, max_capacity, operational_status, is_bookable, created_by
        ) VALUES (
            v_school_id, v_building_id, v_floor_id, 'Computer Lab - 1', 'CL-1', 'B1-CL1',
            'Lab', 30, 'Active', TRUE, v_admin_id
        ) RETURNING id INTO v_room_complab;
    ELSE
        UPDATE public.rooms SET max_capacity = 30, room_type = 'Lab', is_bookable = TRUE WHERE id = v_room_complab;
    END IF;

    -- 5. Clear existing seeded space bookings for this school to start clean
    DELETE FROM public.space_bookings WHERE school_id = v_school_id;

    -- 6. Insert Timeline Bookings for Mon 15 Mar 2026 (exact screenshot events)
    -- G-101 Events:
    -- Math Lecture: 8:00 AM - 9:30 AM
    INSERT INTO public.space_bookings (
        school_id, booking_ref, title, purpose, category, building_id, floor_id, room_id,
        booking_date, start_time, end_time, start_datetime, end_datetime,
        buffer_start_datetime, buffer_end_datetime, duration_minutes,
        organizer_name, organizer_role, status, is_approved, created_by
    ) VALUES (
        v_school_id, 'BK-2026-0101', 'Math Lecture', 'Lecture', 'Academic', v_building_id, v_floor_id, v_room_g101,
        '2026-03-15', '08:00:00', '09:30:00', '2026-03-15 08:00:00+05:30', '2026-03-15 09:30:00+05:30',
        '2026-03-15 07:50:00+05:30', '2026-03-15 09:40:00+05:30', 90,
        'Prof. Ramanathan', 'Faculty', 'Confirmed', TRUE, v_admin_id
    );

    -- Physics Practical: 10:00 AM - 12:00 PM
    INSERT INTO public.space_bookings (
        school_id, booking_ref, title, purpose, category, building_id, floor_id, room_id,
        booking_date, start_time, end_time, start_datetime, end_datetime,
        buffer_start_datetime, buffer_end_datetime, duration_minutes,
        organizer_name, organizer_role, status, is_approved, created_by
    ) VALUES (
        v_school_id, 'BK-2026-0102', 'Physics Practical', 'Practical', 'Academic', v_building_id, v_floor_id, v_room_g101,
        '2026-03-15', '10:00:00', '12:00:00', '2026-03-15 10:00:00+05:30', '2026-03-15 12:00:00+05:30',
        '2026-03-15 09:50:00+05:30', '2026-03-15 12:10:00+05:30', 120,
        'Dr. V. Rao', 'Faculty', 'Confirmed', TRUE, v_admin_id
    );

    -- Club Meeting: 2:00 PM - 4:00 PM
    INSERT INTO public.space_bookings (
        school_id, booking_ref, title, purpose, category, building_id, floor_id, room_id,
        booking_date, start_time, end_time, start_datetime, end_datetime,
        buffer_start_datetime, buffer_end_datetime, duration_minutes,
        organizer_name, organizer_role, status, is_approved, created_by
    ) VALUES (
        v_school_id, 'BK-2026-0103', 'Club Meeting', 'Club Activity', 'Extra-curricular', v_building_id, v_floor_id, v_room_g101,
        '2026-03-15', '14:00:00', '16:00:00', '2026-03-15 14:00:00+05:30', '2026-03-15 16:00:00+05:30',
        '2026-03-15 13:50:00+05:30', '2026-03-15 16:10:00+05:30', 120,
        'Science Club Committee', 'Student', 'Confirmed', TRUE, v_admin_id
    );

    -- G-102 Events:
    -- English Class: 8:00 AM - 9:00 AM
    INSERT INTO public.space_bookings (
        school_id, booking_ref, title, purpose, category, building_id, floor_id, room_id,
        booking_date, start_time, end_time, start_datetime, end_datetime,
        buffer_start_datetime, buffer_end_datetime, duration_minutes,
        organizer_name, organizer_role, status, is_approved, created_by
    ) VALUES (
        v_school_id, 'BK-2026-0104', 'English Class', 'Lecture', 'Academic', v_building_id, v_floor_id, v_room_g102,
        '2026-03-15', '08:00:00', '09:00:00', '2026-03-15 08:00:00+05:30', '2026-03-15 09:00:00+05:30',
        '2026-03-15 07:50:00+05:30', '2026-03-15 09:10:00+05:30', 60,
        'Ms. Kavitha', 'Faculty', 'Confirmed', TRUE, v_admin_id
    );

    -- Workshop: 11:00 AM - 1:00 PM
    INSERT INTO public.space_bookings (
        school_id, booking_ref, title, purpose, category, building_id, floor_id, room_id,
        booking_date, start_time, end_time, start_datetime, end_datetime,
        buffer_start_datetime, buffer_end_datetime, duration_minutes,
        organizer_name, organizer_role, status, is_approved, created_by
    ) VALUES (
        v_school_id, 'BK-2026-0105', 'Workshop', 'Workshop', 'Academic', v_building_id, v_floor_id, v_room_g102,
        '2026-03-15', '11:00:00', '13:00:00', '2026-03-15 11:00:00+05:30', '2026-03-15 13:00:00+05:30',
        '2026-03-15 10:50:00+05:30', '2026-03-15 13:10:00+05:30', 120,
        'Literary Club', 'Faculty', 'Confirmed', TRUE, v_admin_id
    );

    -- Exam Setup: 3:00 PM - 5:00 PM
    INSERT INTO public.space_bookings (
        school_id, booking_ref, title, purpose, category, building_id, floor_id, room_id,
        booking_date, start_time, end_time, start_datetime, end_datetime,
        buffer_start_datetime, buffer_end_datetime, duration_minutes,
        organizer_name, organizer_role, status, is_approved, created_by
    ) VALUES (
        v_school_id, 'BK-2026-0106', 'Exam Setup', 'Exam', 'Administrative', v_building_id, v_floor_id, v_room_g102,
        '2026-03-15', '15:00:00', '17:00:00', '2026-03-15 15:00:00+05:30', '2026-03-15 17:00:00+05:30',
        '2026-03-15 14:50:00+05:30', '2026-03-15 17:10:00+05:30', 120,
        'Exam Cell', 'Admin Office', 'Confirmed', TRUE, v_admin_id
    );

    -- Seminar Hall Events:
    -- Guest Lecture - AI in Education: 10:00 AM - 12:30 PM
    INSERT INTO public.space_bookings (
        school_id, booking_ref, title, purpose, category, building_id, floor_id, room_id,
        booking_date, start_time, end_time, start_datetime, end_datetime,
        buffer_start_datetime, buffer_end_datetime, duration_minutes,
        organizer_name, organizer_role, status, is_approved, created_by
    ) VALUES (
        v_school_id, 'BK-2026-0107', 'Guest Lecture - AI in Education', 'Lecture', 'Academic', v_building_id, v_floor_id, v_room_seminar,
        '2026-03-15', '10:00:00', '12:30:00', '2026-03-15 10:00:00+05:30', '2026-03-15 12:30:00+05:30',
        '2026-03-15 09:45:00+05:30', '2026-03-15 12:45:00+05:30', 150,
        'CS Department', 'Faculty', 'Confirmed', TRUE, v_admin_id
    );

    -- Cultural Practice: 2:30 PM - 4:30 PM
    INSERT INTO public.space_bookings (
        school_id, booking_ref, title, purpose, category, building_id, floor_id, room_id,
        booking_date, start_time, end_time, start_datetime, end_datetime,
        buffer_start_datetime, buffer_end_datetime, duration_minutes,
        organizer_name, organizer_role, status, is_approved, created_by
    ) VALUES (
        v_school_id, 'BK-2026-0108', 'Cultural Practice', 'Practice', 'Cultural', v_building_id, v_floor_id, v_room_seminar,
        '2026-03-15', '14:30:00', '16:30:00', '2026-03-15 14:30:00+05:30', '2026-03-15 16:30:00+05:30',
        '2026-03-15 14:20:00+05:30', '2026-03-15 16:40:00+05:30', 120,
        'Cultural Committee', 'Student', 'Confirmed', TRUE, v_admin_id
    );

    -- Conference Room Events:
    -- Dept. Meeting: 9:00 AM - 10:00 AM
    INSERT INTO public.space_bookings (
        school_id, booking_ref, title, purpose, category, building_id, floor_id, room_id,
        booking_date, start_time, end_time, start_datetime, end_datetime,
        buffer_start_datetime, buffer_end_datetime, duration_minutes,
        organizer_name, organizer_role, status, is_approved, created_by
    ) VALUES (
        v_school_id, 'BK-2026-0109', 'Dept. Meeting', 'Meeting', 'Administrative', v_building_id, v_floor_id, v_room_conf,
        '2026-03-15', '09:00:00', '10:00:00', '2026-03-15 09:00:00+05:30', '2026-03-15 10:00:00+05:30',
        '2026-03-15 08:50:00+05:30', '2026-03-15 10:10:00+05:30', 60,
        'Principal Office', 'Admin Office', 'Confirmed', TRUE, v_admin_id
    );

    -- Planning Session: 1:00 PM - 2:00 PM
    INSERT INTO public.space_bookings (
        school_id, booking_ref, title, purpose, category, building_id, floor_id, room_id,
        booking_date, start_time, end_time, start_datetime, end_datetime,
        buffer_start_datetime, buffer_end_datetime, duration_minutes,
        organizer_name, organizer_role, status, is_approved, created_by
    ) VALUES (
        v_school_id, 'BK-2026-0110', 'Planning Session', 'Meeting', 'Administrative', v_building_id, v_floor_id, v_room_conf,
        '2026-03-15', '13:00:00', '14:00:00', '2026-03-15 13:00:00+05:30', '2026-03-15 14:00:00+05:30',
        '2026-03-15 12:50:00+05:30', '2026-03-15 14:10:00+05:30', 60,
        'Academic Council', 'Admin Office', 'Confirmed', TRUE, v_admin_id
    );

    -- Computer Lab - 1 Events:
    -- Lab Session (CS): 8:00 AM - 10:00 AM
    INSERT INTO public.space_bookings (
        school_id, booking_ref, title, purpose, category, building_id, floor_id, room_id,
        booking_date, start_time, end_time, start_datetime, end_datetime,
        buffer_start_datetime, buffer_end_datetime, duration_minutes,
        organizer_name, organizer_role, status, is_approved, created_by
    ) VALUES (
        v_school_id, 'BK-2026-0111', 'Lab Session (CS)', 'Practical', 'Academic', v_building_id, v_floor_id, v_room_complab,
        '2026-03-15', '08:00:00', '10:00:00', '2026-03-15 08:00:00+05:30', '2026-03-15 10:00:00+05:30',
        '2026-03-15 07:50:00+05:30', '2026-03-15 10:10:00+05:30', 120,
        'IT Department', 'Faculty', 'Confirmed', TRUE, v_admin_id
    );

    -- Student Training: 2:00 PM - 4:00 PM
    INSERT INTO public.space_bookings (
        school_id, booking_ref, title, purpose, category, building_id, floor_id, room_id,
        booking_date, start_time, end_time, start_datetime, end_datetime,
        buffer_start_datetime, buffer_end_datetime, duration_minutes,
        organizer_name, organizer_role, status, is_approved, created_by
    ) VALUES (
        v_school_id, 'BK-2026-0112', 'Student Training', 'Workshop', 'Training', v_building_id, v_floor_id, v_room_complab,
        '2026-03-15', '14:00:00', '16:00:00', '2026-03-15 14:00:00+05:30', '2026-03-15 16:00:00+05:30',
        '2026-03-15 13:50:00+05:30', '2026-03-15 16:10:00+05:30', 120,
        'Coding Club Mentor', 'Student', 'Confirmed', TRUE, v_admin_id
    );

    -- 7. Insert the 5 Specific Booking Requests matching Table from Screenshot
    -- Request 1: CS Club Meeting
    INSERT INTO public.space_bookings (
        school_id, booking_ref, title, purpose, category, building_id, floor_id, room_id,
        booking_date, start_time, end_time, start_datetime, end_datetime,
        buffer_start_datetime, buffer_end_datetime, duration_minutes,
        organizer_name, organizer_role, status, is_approved, created_by
    ) VALUES (
        v_school_id, 'BK-2026-0201', 'CS Club Meeting', 'Club Activity', 'Club Activity', v_building_id, v_floor_id, v_room_g101,
        '2026-03-20', '14:00:00', '16:00:00', '2026-03-20 14:00:00+05:30', '2026-03-20 16:00:00+05:30',
        '2026-03-20 13:50:00+05:30', '2026-03-20 16:10:00+05:30', 120,
        'Rohan Verma', 'Student', 'Pending', FALSE, v_admin_id
    );

    -- Request 2: Faculty Workshop
    INSERT INTO public.space_bookings (
        school_id, booking_ref, title, purpose, category, building_id, floor_id, room_id,
        booking_date, start_time, end_time, start_datetime, end_datetime,
        buffer_start_datetime, buffer_end_datetime, duration_minutes,
        organizer_name, organizer_role, status, is_approved, created_by
    ) VALUES (
        v_school_id, 'BK-2026-0202', 'Faculty Workshop', 'Workshop', 'Workshop', v_building_id, v_floor_id, v_room_seminar,
        '2026-03-21', '10:00:00', '13:00:00', '2026-03-21 10:00:00+05:30', '2026-03-21 13:00:00+05:30',
        '2026-03-21 09:50:00+05:30', '2026-03-21 13:10:00+05:30', 180,
        'Dr. Ananya Sharma', 'Faculty', 'Pending', FALSE, v_admin_id
    );

    -- Request 3: Parent Interaction
    INSERT INTO public.space_bookings (
        school_id, booking_ref, title, purpose, category, building_id, floor_id, room_id,
        booking_date, start_time, end_time, start_datetime, end_datetime,
        buffer_start_datetime, buffer_end_datetime, duration_minutes,
        organizer_name, organizer_role, status, is_approved, created_by
    ) VALUES (
        v_school_id, 'BK-2026-0203', 'Parent Interaction', 'Meeting', 'Meeting', v_building_id, v_floor_id, v_room_conf,
        '2026-03-22', '15:00:00', '16:00:00', '2026-03-22 15:00:00+05:30', '2026-03-22 16:00:00+05:30',
        '2026-03-22 14:50:00+05:30', '2026-03-22 16:10:00+05:30', 60,
        'Admin Office', 'Admin Office', 'Pending', FALSE, v_admin_id
    );

    -- Request 4: Lab Extension
    INSERT INTO public.space_bookings (
        school_id, booking_ref, title, purpose, category, building_id, floor_id, room_id,
        booking_date, start_time, end_time, start_datetime, end_datetime,
        buffer_start_datetime, buffer_end_datetime, duration_minutes,
        organizer_name, organizer_role, status, is_approved, created_by
    ) VALUES (
        v_school_id, 'BK-2026-0204', 'Lab Extension', 'Practical', 'Practical', v_building_id, v_floor_id, v_room_complab,
        '2026-03-20', '16:00:00', '18:00:00', '2026-03-20 16:00:00+05:30', '2026-03-20 18:00:00+05:30',
        '2026-03-20 15:50:00+05:30', '2026-03-20 18:10:00+05:30', 120,
        'IT Department', 'IT Department', 'Pending', FALSE, v_admin_id
    );

    -- Request 5: Cultural Practice
    INSERT INTO public.space_bookings (
        school_id, booking_ref, title, purpose, category, building_id, floor_id, room_id,
        booking_date, start_time, end_time, start_datetime, end_datetime,
        buffer_start_datetime, buffer_end_datetime, duration_minutes,
        organizer_name, organizer_role, status, is_approved, created_by
    ) VALUES (
        v_school_id, 'BK-2026-0205', 'Cultural Practice', 'Practice', 'Practice', v_building_id, v_floor_id, v_room_seminar,
        '2026-03-19', '14:00:00', '17:00:00', '2026-03-19 14:00:00+05:30', '2026-03-19 17:00:00+05:30',
        '2026-03-19 13:50:00+05:30', '2026-03-19 17:10:00+05:30', 180,
        'Cultural Committee', 'Cultural Committee', 'Pending', FALSE, v_admin_id
    );

    -- 8. Seed additional records to total 246 bookings:
    -- 198 Confirmed (12 already inserted, need 186)
    -- 28 Pending (5 already inserted, need 23)
    -- 9 Rejected (9 need to be inserted)
    -- Total: 246 bookings
    SELECT array_agg(id) INTO v_rooms_list FROM public.rooms WHERE school_id = v_school_id;

    -- Seed 23 more Pending requests
    FOR i IN 6..28 LOOP
        v_rand_room := v_rooms_list[(i % array_length(v_rooms_list, 1)) + 1];
        INSERT INTO public.space_bookings (
            school_id, booking_ref, title, purpose, category, building_id, floor_id, room_id,
            booking_date, start_time, end_time, start_datetime, end_datetime,
            buffer_start_datetime, buffer_end_datetime, duration_minutes,
            organizer_name, organizer_role, status, is_approved, created_by
        ) VALUES (
            v_school_id, 'BK-2026-P' || LPAD(i::TEXT, 3, '0'),
            CASE (i % 5)
                WHEN 0 THEN 'Robotics Workshop Prep'
                WHEN 1 THEN 'Debate Society Rehearsal'
                WHEN 2 THEN 'Guest Speaker Orientation'
                WHEN 3 THEN 'Math Olympiad Practice'
                ELSE 'Drama Club Audition'
            END,
            'Academic', 'Academic', v_building_id, v_floor_id, v_rand_room,
            '2026-03-23'::DATE + (i % 7), '10:00:00', '12:00:00',
            ('2026-03-23'::DATE + (i % 7) || ' 10:00:00+05:30')::TIMESTAMPTZ,
            ('2026-03-23'::DATE + (i % 7) || ' 12:00:00+05:30')::TIMESTAMPTZ,
            ('2026-03-23'::DATE + (i % 7) || ' 09:50:00+05:30')::TIMESTAMPTZ,
            ('2026-03-23'::DATE + (i % 7) || ' 12:10:00+05:30')::TIMESTAMPTZ,
            120, 'Faculty Lead ' || i, 'Faculty', 'Pending', FALSE, v_admin_id
        );
    END LOOP;

    -- Seed 9 Rejected bookings
    FOR i IN 1..9 LOOP
        v_rand_room := v_rooms_list[(i % array_length(v_rooms_list, 1)) + 1];
        INSERT INTO public.space_bookings (
            school_id, booking_ref, title, purpose, category, building_id, floor_id, room_id,
            booking_date, start_time, end_time, start_datetime, end_datetime,
            buffer_start_datetime, buffer_end_datetime, duration_minutes,
            organizer_name, organizer_role, status, is_approved, rejection_reason, created_by
        ) VALUES (
            v_school_id, 'BK-2026-R' || LPAD(i::TEXT, 3, '0'),
            'Special Session ' || i, 'Event', 'Event', v_building_id, v_floor_id, v_rand_room,
            '2026-03-10'::DATE + i, '14:00:00', '16:00:00',
            ('2026-03-10'::DATE + i || ' 14:00:00+05:30')::TIMESTAMPTZ,
            ('2026-03-10'::DATE + i || ' 16:00:00+05:30')::TIMESTAMPTZ,
            ('2026-03-10'::DATE + i || ' 13:50:00+05:30')::TIMESTAMPTZ,
            ('2026-03-10'::DATE + i || ' 16:10:00+05:30')::TIMESTAMPTZ,
            120, 'External Organizer ' || i, 'External', 'Rejected', FALSE, 'Schedule conflict with university examinations', v_admin_id
        );
    END LOOP;

    -- Seed 11 Cancelled bookings (to match 246 total = 198 confirmed + 28 pending + 9 rejected + 11 cancelled)
    FOR i IN 1..11 LOOP
        v_rand_room := v_rooms_list[(i % array_length(v_rooms_list, 1)) + 1];
        INSERT INTO public.space_bookings (
            school_id, booking_ref, title, purpose, category, building_id, floor_id, room_id,
            booking_date, start_time, end_time, start_datetime, end_datetime,
            buffer_start_datetime, buffer_end_datetime, duration_minutes,
            organizer_name, organizer_role, status, is_approved, cancellation_reason, created_by
        ) VALUES (
            v_school_id, 'BK-2026-X' || LPAD(i::TEXT, 3, '0'),
            'Cancelled Event ' || i, 'Event', 'Event', v_building_id, v_floor_id, v_rand_room,
            '2026-03-05'::DATE + i, '11:00:00', '13:00:00',
            ('2026-03-05'::DATE + i || ' 11:00:00+05:30')::TIMESTAMPTZ,
            ('2026-03-05'::DATE + i || ' 13:00:00+05:30')::TIMESTAMPTZ,
            ('2026-03-05'::DATE + i || ' 10:50:00+05:30')::TIMESTAMPTZ,
            ('2026-03-05'::DATE + i || ' 13:10:00+05:30')::TIMESTAMPTZ,
            120, 'Department Lead ' || i, 'Faculty', 'Cancelled', FALSE, 'Rescheduled by department', v_admin_id
        );
    END LOOP;

    -- Update rooms to match utilization breakdown (6 Under Maintenance, 3 Not Bookable)
    UPDATE public.rooms SET operational_status = 'Maintenance'
    WHERE id IN (
        SELECT id FROM public.rooms 
        WHERE school_id = v_school_id AND id NOT IN (v_room_g101, v_room_g102, v_room_seminar, v_room_conf, v_room_complab)
        LIMIT 6
    );

    UPDATE public.rooms SET is_bookable = FALSE
    WHERE id IN (
        SELECT id FROM public.rooms 
        WHERE school_id = v_school_id AND operational_status <> 'Maintenance'
          AND id NOT IN (v_room_g101, v_room_g102, v_room_seminar, v_room_conf, v_room_complab)
        LIMIT 3
    );

    -- Seed remaining 186 Confirmed bookings across past and future weeks
    -- First 29 of these are on 2026-03-15 across distinct rooms to give exactly 34 active spaces on 2026-03-15
    FOR i IN 13..198 LOOP
        IF i <= 41 AND (i - 12) <= array_length(v_rooms_list, 1) THEN
            v_rand_room := v_rooms_list[i - 12];
            INSERT INTO public.space_bookings (
                school_id, booking_ref, title, purpose, category, building_id, floor_id, room_id,
                booking_date, start_time, end_time, start_datetime, end_datetime,
                buffer_start_datetime, buffer_end_datetime, duration_minutes,
                organizer_name, organizer_role, status, is_approved, created_by
            ) VALUES (
                v_school_id, 'BK-2026-C' || LPAD(i::TEXT, 4, '0'),
                'Academic Session ' || i, 'Lecture', 'Academic', v_building_id, v_floor_id, v_rand_room,
                '2026-03-15', '10:00:00', '11:30:00',
                '2026-03-15 10:00:00+05:30'::TIMESTAMPTZ, '2026-03-15 11:30:00+05:30'::TIMESTAMPTZ,
                '2026-03-15 09:50:00+05:30'::TIMESTAMPTZ, '2026-03-15 11:40:00+05:30'::TIMESTAMPTZ,
                90, 'Staff Instructor ' || (i % 20 + 1), 'Faculty', 'Confirmed', TRUE, v_admin_id
            );
        ELSE
            v_rand_room := v_rooms_list[(i % array_length(v_rooms_list, 1)) + 1];
            INSERT INTO public.space_bookings (
                school_id, booking_ref, title, purpose, category, building_id, floor_id, room_id,
                booking_date, start_time, end_time, start_datetime, end_datetime,
                buffer_start_datetime, buffer_end_datetime, duration_minutes,
                organizer_name, organizer_role, status, is_approved, created_by
            ) VALUES (
                v_school_id, 'BK-2026-C' || LPAD(i::TEXT, 4, '0'),
                'Curricular Session ' || i, 'Lecture', 'Academic', v_building_id, v_floor_id, v_rand_room,
                '2026-03-01'::DATE + (i % 25), '09:00:00', '10:30:00',
                ('2026-03-01'::DATE + (i % 25) || ' 09:00:00+05:30')::TIMESTAMPTZ,
                ('2026-03-01'::DATE + (i % 25) || ' 10:30:00+05:30')::TIMESTAMPTZ,
                ('2026-03-01'::DATE + (i % 25) || ' 08:50:00+05:30')::TIMESTAMPTZ,
                ('2026-03-01'::DATE + (i % 25) || ' 10:40:00+05:30')::TIMESTAMPTZ,
                90, 'Staff Instructor ' || (i % 20 + 1), 'Faculty', 'Confirmed', TRUE, v_admin_id
            );
        END IF;
    END LOOP;

    RAISE NOTICE 'Space booking seeds executed successfully. Total bookings: %', (SELECT COUNT(*) FROM public.space_bookings WHERE school_id = v_school_id);
END $$;
