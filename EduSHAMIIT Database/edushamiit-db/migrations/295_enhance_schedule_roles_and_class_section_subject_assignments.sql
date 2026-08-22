-- ============================================================================
-- Migration: 295_enhance_schedule_roles_and_class_section_subject_assignments.sql
-- Description:
--   1. Adds schema support (class_id, section_id, target_subject_id, target_subject)
--      to schedule_participants and target_class_sections to schedules.
--   2. Stored procedure fn_get_schedule_assignable_roles: returns only Active
--      roles from public.app_roles with exact display names and codes.
--   3. Stored procedure fn_get_schedule_assignable_class_sections: returns active
--      classes & sections joined with their assigned subjects and teachers.
--   4. Stored procedure fn_resolve_schedule_audience: resolves students and
--      teachers for role, class-section, and class-section-subject combinations.
--   5. Enhances fn_create_schedule and fn_update_schedule to support class-section-subject
--      mappings and audience resolution.
--   6. Enhances fn_get_schedules, fn_get_schedule_details, and fn_get_calendar_summary.
-- ============================================================================

-- 1. Schema Enhancements
ALTER TABLE public.schedule_participants
    ADD COLUMN IF NOT EXISTS class_id UUID,
    ADD COLUMN IF NOT EXISTS section_id UUID,
    ADD COLUMN IF NOT EXISTS target_subject_id UUID,
    ADD COLUMN IF NOT EXISTS target_subject TEXT;

ALTER TABLE public.schedules
    ADD COLUMN IF NOT EXISTS target_class_sections JSONB DEFAULT '[]'::jsonb;

CREATE INDEX IF NOT EXISTS idx_sched_part_class_sec_subj
    ON public.schedule_participants (class_id, section_id, target_subject_id);

CREATE INDEX IF NOT EXISTS idx_sched_part_target_role
    ON public.schedule_participants (target_role);

-- 2. Stored Procedure: fn_get_schedule_assignable_roles
CREATE OR REPLACE FUNCTION public.fn_get_schedule_assignable_roles(
    p_school_id UUID
) RETURNS JSONB AS $$
DECLARE
    v_roles JSONB;
BEGIN
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', ar.id,
            'name', ar.name,
            'code', ar.code,
            'display_name', COALESCE(NULLIF(ar.display_name, ''), initcap(replace(ar.name, '_', ' '))),
            'description', ar.description,
            'role_type', ar.role_type,
            'status', ar.status
        ) ORDER BY ar.display_order ASC, ar.name ASC
    )
    INTO v_roles
    FROM public.app_roles ar
    WHERE (ar.school_id = p_school_id OR ar.school_id IS NULL)
      AND (UPPER(COALESCE(ar.status, 'ACTIVE')) = 'ACTIVE');

    IF v_roles IS NULL THEN
        v_roles := '[]'::jsonb;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', v_roles
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3. Stored Procedure: fn_get_schedule_assignable_class_sections
CREATE OR REPLACE FUNCTION public.fn_get_schedule_assignable_class_sections(
    p_school_id UUID
) RETURNS JSONB AS $$
DECLARE
    v_data JSONB;
BEGIN
    SELECT jsonb_agg(
        jsonb_build_object(
            'class_id', c.id,
            'class_name', c.name,
            'class_code', c.code,
            'section_id', s.id,
            'section_name', s.name,
            'section_code', s.code,
            'display_name', c.name || ' - ' || s.name,
            'room_number', s.room_number,
            'capacity', s.capacity,
            'class_teacher_name', (
                SELECT p.full_name
                FROM public.class_teacher_assignments cta
                JOIN public.profiles p ON p.id = cta.teacher_id
                WHERE cta.section_id = s.id
                ORDER BY cta.created_at DESC
                LIMIT 1
            ),
            'student_count', (
                SELECT COUNT(DISTINCT sca.student_id)
                FROM public.student_class_assignments sca
                WHERE sca.section_id = s.id
                  AND (sca.status = 'ACTIVE' OR sca.status IS NULL)
            ),
            'subjects', COALESCE((
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'id', sub.id,
                        'name', sub.name,
                        'code', sub.code,
                        'color', sub.color,
                        'teacher_id', sst.teacher_id,
                        'teacher_name', tp.full_name
                    ) ORDER BY sub.name ASC
                )
                FROM public.class_subject_assignments csa
                JOIN public.academic_subjects sub ON sub.id = csa.subject_id
                LEFT JOIN public.section_subject_teachers sst ON sst.section_id = s.id AND sst.subject_id = sub.id
                LEFT JOIN public.profiles tp ON tp.id = sst.teacher_id
                WHERE (csa.section_id = s.id OR (csa.class_id = c.id AND csa.section_id IS NULL))
                  AND sub.deleted_at IS NULL
                  AND (UPPER(COALESCE(sub.status, 'ACTIVE')) = 'ACTIVE')
                  AND (UPPER(COALESCE(csa.status, 'ACTIVE')) = 'ACTIVE')
            ), '[]'::jsonb)
        ) ORDER BY c.display_order ASC, c.name ASC, s.name ASC
    )
    INTO v_data
    FROM public.academic_sections s
    JOIN public.academic_classes c ON c.id = s.class_id
    WHERE (s.school_id = p_school_id OR s.school_id IS NULL)
      AND s.deleted_at IS NULL
      AND c.deleted_at IS NULL
      AND (UPPER(COALESCE(s.status, 'ACTIVE')) = 'ACTIVE')
      AND (UPPER(COALESCE(c.status, 'ACTIVE')) = 'ACTIVE');

    IF v_data IS NULL THEN
        v_data := '[]'::jsonb;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', v_data
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 4. Stored Procedure: fn_resolve_schedule_audience
-- Automatically links students, class teachers, and subject teachers to schedule_participants
CREATE OR REPLACE FUNCTION public.fn_resolve_schedule_audience(
    p_school_id UUID,
    p_schedule_id UUID,
    p_target_roles JSONB,
    p_target_classes JSONB,
    p_target_class_sections JSONB,
    p_target_user_ids JSONB
) RETURNS VOID AS $$
DECLARE
    v_role_elem TEXT;
    v_class_elem TEXT;
    v_cs_elem JSONB;
    v_uid_elem TEXT;
    v_cid UUID;
    v_sid UUID;
    v_sub_id UUID;
    v_cname TEXT;
    v_sname TEXT;
    v_subname TEXT;
    v_stud_rec RECORD;
    v_teach_rec RECORD;
BEGIN
    -- 1. Insert explicit user IDs
    IF p_target_user_ids IS NOT NULL AND jsonb_typeof(p_target_user_ids) = 'array' THEN
        FOR v_uid_elem IN SELECT jsonb_array_elements_text(p_target_user_ids) LOOP
            IF v_uid_elem IS NOT NULL AND v_uid_elem != '' THEN
                INSERT INTO public.schedule_participants (
                    id, schedule_id, user_id, participant_type, participation_role, permission, rsvp_status, created_at
                ) VALUES (
                    gen_random_uuid(), p_schedule_id, v_uid_elem::UUID, 'individual', 'required', 'can_view', 'pending', NOW()
                ) ON CONFLICT DO NOTHING;
            END IF;
        END LOOP;
    END IF;

    -- 2. Insert Role broadcasts
    IF p_target_roles IS NOT NULL AND jsonb_typeof(p_target_roles) = 'array' THEN
        FOR v_role_elem IN SELECT jsonb_array_elements_text(p_target_roles) LOOP
            IF v_role_elem IS NOT NULL AND v_role_elem != '' THEN
                INSERT INTO public.schedule_participants (
                    id, schedule_id, user_id, target_role, participant_type, participation_role, permission, rsvp_status, created_at
                ) VALUES (
                    gen_random_uuid(), p_schedule_id, NULL, lower(trim(v_role_elem)), 'role', 'required', 'can_view', 'pending', NOW()
                );
            END IF;
        END LOOP;
    END IF;

    -- 3. Insert Legacy/Simple Class broadcasts
    IF p_target_classes IS NOT NULL AND jsonb_typeof(p_target_classes) = 'array' THEN
        FOR v_class_elem IN SELECT jsonb_array_elements_text(p_target_classes) LOOP
            IF v_class_elem IS NOT NULL AND v_class_elem != '' THEN
                INSERT INTO public.schedule_participants (
                    id, schedule_id, user_id, target_class, participant_type, participation_role, permission, rsvp_status, created_at
                ) VALUES (
                    gen_random_uuid(), p_schedule_id, NULL, trim(v_class_elem), 'class_section', 'required', 'can_view', 'pending', NOW()
                );
            END IF;
        END LOOP;
    END IF;

    -- 4. Process Detailed Class-Section & Subject Mappings
    IF p_target_class_sections IS NOT NULL AND jsonb_typeof(p_target_class_sections) = 'array' THEN
        FOR v_cs_elem IN SELECT * FROM jsonb_array_elements(p_target_class_sections) LOOP
            v_cid := NULLIF(v_cs_elem->>'class_id', '')::UUID;
            v_sid := NULLIF(v_cs_elem->>'section_id', '')::UUID;
            v_sub_id := NULLIF(v_cs_elem->>'subject_id', '')::UUID;
            v_cname := v_cs_elem->>'class_name';
            v_sname := v_cs_elem->>'section_name';
            v_subname := v_cs_elem->>'subject_name';

            -- Add broadcast entry for this class-section-subject combo
            INSERT INTO public.schedule_participants (
                id, schedule_id, user_id, class_id, section_id, target_class, target_section,
                target_subject_id, target_subject, participant_type, participation_role, permission, rsvp_status, created_at
            ) VALUES (
                gen_random_uuid(), p_schedule_id, NULL, v_cid, v_sid, v_cname, v_sname,
                v_sub_id, v_subname, 'class_section', 'required', 'can_view', 'pending', NOW()
            );

            -- Automatically resolve Enrolled Students
            FOR v_stud_rec IN
                SELECT DISTINCT sca.student_id
                FROM public.student_class_assignments sca
                WHERE (v_sid IS NOT NULL AND sca.section_id = v_sid)
                   OR (v_sid IS NULL AND v_cid IS NOT NULL AND sca.class_id = v_cid)
            LOOP
                IF v_stud_rec.student_id IS NOT NULL THEN
                    INSERT INTO public.schedule_participants (
                        id, schedule_id, user_id, class_id, section_id, target_class, target_section,
                        target_subject_id, target_subject, participant_type, participation_role, permission, rsvp_status, created_at
                    ) VALUES (
                        gen_random_uuid(), p_schedule_id, v_stud_rec.student_id, v_cid, v_sid, v_cname, v_sname,
                        v_sub_id, v_subname, 'individual', 'required', 'can_view', 'pending', NOW()
                    ) ON CONFLICT DO NOTHING;
                END IF;
            END LOOP;

            -- Automatically resolve Teachers
            IF v_sub_id IS NOT NULL THEN
                -- Subject is specified: Target specific subject teacher(s)
                FOR v_teach_rec IN
                    SELECT DISTINCT sst.teacher_id
                    FROM public.section_subject_teachers sst
                    WHERE sst.subject_id = v_sub_id
                      AND ((v_sid IS NOT NULL AND sst.section_id = v_sid) OR (v_sid IS NULL AND v_cid IS NOT NULL AND sst.class_id = v_cid))
                LOOP
                    IF v_teach_rec.teacher_id IS NOT NULL THEN
                        INSERT INTO public.schedule_participants (
                            id, schedule_id, user_id, class_id, section_id, target_class, target_section,
                            target_subject_id, target_subject, participant_type, participation_role, permission, rsvp_status, created_at
                        ) VALUES (
                            gen_random_uuid(), p_schedule_id, v_teach_rec.teacher_id, v_cid, v_sid, v_cname, v_sname,
                            v_sub_id, v_subname, 'individual', 'required', 'can_view', 'pending', NOW()
                        ) ON CONFLICT DO NOTHING;
                    END IF;
                END LOOP;
            ELSE
                -- None subject (General Class Schedule): Target Class Teacher AND all Section Teachers
                FOR v_teach_rec IN
                    SELECT DISTINCT cta.teacher_id
                    FROM public.class_teacher_assignments cta
                    WHERE (v_sid IS NOT NULL AND cta.section_id = v_sid)
                       OR (v_sid IS NULL AND v_cid IS NOT NULL AND cta.class_id = v_cid)
                    UNION
                    SELECT DISTINCT sst.teacher_id
                    FROM public.section_subject_teachers sst
                    WHERE (v_sid IS NOT NULL AND sst.section_id = v_sid)
                       OR (v_sid IS NULL AND v_cid IS NOT NULL AND sst.class_id = v_cid)
                LOOP
                    IF v_teach_rec.teacher_id IS NOT NULL THEN
                        INSERT INTO public.schedule_participants (
                            id, schedule_id, user_id, class_id, section_id, target_class, target_section,
                            target_subject_id, target_subject, participant_type, participation_role, permission, rsvp_status, created_at
                        ) VALUES (
                            gen_random_uuid(), p_schedule_id, v_teach_rec.teacher_id, v_cid, v_sid, v_cname, v_sname,
                            NULL, NULL, 'individual', 'required', 'can_view', 'pending', NOW()
                        ) ON CONFLICT DO NOTHING;
                    END IF;
                END LOOP;
            END IF;
        END LOOP;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 5. Stored Procedure: fn_create_schedule (Updated with Class-Section-Subject resolution)
CREATE OR REPLACE FUNCTION public.fn_create_schedule(
    p_school_id UUID,
    p_user_id UUID,
    p_data JSONB
) RETURNS JSONB AS $$
DECLARE
    v_cal_id UUID;
    v_sched_id UUID := gen_random_uuid();
    v_start_time TIMESTAMPTZ;
    v_end_time TIMESTAMPTZ;
    v_force_override BOOLEAN;
    v_conflicts JSONB := '[]'::jsonb;
    v_res_conflict RECORD;
    v_usr_conflict RECORD;
    v_route_id UUID;
    v_aud_type TEXT := 'individual';
    v_target_roles JSONB := '[]'::jsonb;
    v_target_classes JSONB := '[]'::jsonb;
    v_target_class_sections JSONB := '[]'::jsonb;
    v_target_users JSONB := '[]'::jsonb;
    v_p_elem JSONB;
    v_r_elem JSONB;
    v_rem_elem JSONB;
    v_sched_rec public.schedules%ROWTYPE;
BEGIN
    v_start_time := public.parse_tz_timestamp(p_data->>'start_time', COALESCE(p_data->>'timezone', 'Asia/Kolkata'));
    v_end_time := public.parse_tz_timestamp(p_data->>'end_time', COALESCE(p_data->>'timezone', 'Asia/Kolkata'));
    v_force_override := COALESCE((p_data->>'force_override_conflicts')::BOOLEAN, FALSE);

    -- 1. Calendar resolution
    IF p_data->>'calendar_id' IS NOT NULL AND (p_data->>'calendar_id') != '' THEN
        v_cal_id := (p_data->>'calendar_id')::UUID;
    ELSE
        SELECT id INTO v_cal_id
        FROM public.calendars
        WHERE school_id = p_school_id AND (owner_id = p_user_id OR is_default = TRUE)
        LIMIT 1;

        IF v_cal_id IS NULL THEN
            v_cal_id := gen_random_uuid();
            INSERT INTO public.calendars (id, school_id, name, color, type, is_default, owner_id, created_at)
            VALUES (v_cal_id, p_school_id, 'My Calendar', '#4F46E5', 'personal', TRUE, p_user_id, NOW());
        END IF;
    END IF;

    -- 2. Smart Conflict Detection
    IF NOT v_force_override THEN
        -- Resource collisions
        IF jsonb_array_length(COALESCE(p_data->'resources', '[]'::jsonb)) > 0 THEN
            FOR v_r_elem IN SELECT * FROM jsonb_array_elements(p_data->'resources') LOOP
                SELECT rb.*, s.title AS sched_title, cr.name AS resource_name
                INTO v_res_conflict
                FROM public.resource_bookings rb
                JOIN public.schedules s ON s.id = rb.schedule_id
                JOIN public.calendar_resources cr ON cr.id = rb.resource_id
                WHERE rb.resource_id = (v_r_elem->>'resource_id')::UUID
                  AND cr.is_exclusive = TRUE
                  AND s.deleted_at IS NULL
                  AND s.status NOT IN ('cancelled', 'declined')
                  AND s.start_time < v_end_time AND s.end_time > v_start_time
                LIMIT 1;

                IF v_res_conflict.schedule_id IS NOT NULL THEN
                    v_conflicts := v_conflicts || jsonb_build_object(
                        'type', 'resource',
                        'resource_id', v_r_elem->>'resource_id',
                        'resource_name', v_res_conflict.resource_name,
                        'conflicting_title', v_res_conflict.sched_title,
                        'start_time', v_res_conflict.start_time,
                        'end_time', v_res_conflict.end_time,
                        'message', 'Resource ''' || v_res_conflict.resource_name || ''' is already booked for ''' || v_res_conflict.sched_title || '''.'
                    );
                END IF;
            END LOOP;
        END IF;

        -- Participant collisions
        IF jsonb_array_length(COALESCE(p_data->'participants', '[]'::jsonb)) > 0 THEN
            FOR v_p_elem IN SELECT * FROM jsonb_array_elements(p_data->'participants') LOOP
                IF v_p_elem->>'user_id' IS NOT NULL THEN
                    SELECT s.title AS sched_title, s.start_time, s.end_time, prof.full_name
                    INTO v_usr_conflict
                    FROM public.schedule_participants sp
                    JOIN public.schedules s ON s.id = sp.schedule_id
                    JOIN public.profiles prof ON prof.id = sp.user_id
                    WHERE sp.user_id = (v_p_elem->>'user_id')::UUID
                      AND s.deleted_at IS NULL
                      AND s.status NOT IN ('cancelled', 'declined')
                      AND sp.rsvp_status != 'declined'
                      AND s.start_time < v_end_time AND s.end_time > v_start_time
                    LIMIT 1;

                    IF v_usr_conflict.sched_title IS NOT NULL THEN
                        v_conflicts := v_conflicts || jsonb_build_object(
                            'type', 'user',
                            'user_id', v_p_elem->>'user_id',
                            'user_name', v_usr_conflict.full_name,
                            'conflicting_title', v_usr_conflict.sched_title,
                            'start_time', v_usr_conflict.start_time,
                            'end_time', v_usr_conflict.end_time,
                            'message', 'User ''' || v_usr_conflict.full_name || ''' already has schedule ''' || v_usr_conflict.sched_title || ''' during this time.'
                        );
                    END IF;
                END IF;
            END LOOP;
        END IF;

        IF jsonb_array_length(v_conflicts) > 0 THEN
            RETURN jsonb_build_object(
                'success', FALSE,
                'error', jsonb_build_object(
                    'code', 'SCHEDULE_CONFLICT',
                    'message', 'Scheduling conflict detected. Another schedule or resource is booked during this time.',
                    'conflicts', v_conflicts
                )
            );
        END IF;
    END IF;

    -- 3. Target audience extraction
    IF p_data->'target_roles' IS NOT NULL AND jsonb_typeof(p_data->'target_roles') = 'array' THEN
        v_target_roles := p_data->'target_roles';
    END IF;
    IF p_data->'target_classes' IS NOT NULL AND jsonb_typeof(p_data->'target_classes') = 'array' THEN
        v_target_classes := p_data->'target_classes';
    END IF;
    IF p_data->'target_class_sections' IS NOT NULL AND jsonb_typeof(p_data->'target_class_sections') = 'array' THEN
        v_target_class_sections := p_data->'target_class_sections';
    END IF;
    IF p_data->'target_user_ids' IS NOT NULL AND jsonb_typeof(p_data->'target_user_ids') = 'array' THEN
        v_target_users := p_data->'target_user_ids';
    END IF;

    IF jsonb_array_length(v_target_roles) > 0 THEN
        v_aud_type := 'role';
    ELSIF jsonb_array_length(v_target_class_sections) > 0 OR jsonb_array_length(v_target_classes) > 0 THEN
        v_aud_type := 'class_section';
    ELSIF (p_data->>'visibility') = 'institution_wide' THEN
        v_aud_type := 'all';
    END IF;

    IF p_data->>'route_id' IS NOT NULL AND (p_data->>'route_id') != '' THEN
        v_route_id := (p_data->>'route_id')::UUID;
    END IF;

    -- 4. Insert Schedule Master
    INSERT INTO public.schedules (
        id, school_id, calendar_id, title, description, schedule_type, category, color, priority,
        status, approval_status, start_time, end_time, is_all_day, timezone,
        location_name, location_address, building, room, landmark, latitude, longitude,
        virtual_meeting_url, virtual_meeting_provider, organizer_id, created_by, visibility,
        is_recurring, route_id, audience_type, target_roles, target_classes, target_class_sections, target_user_ids,
        metadata, created_at, updated_at
    ) VALUES (
        v_sched_id, p_school_id, v_cal_id,
        p_data->>'title',
        p_data->>'description',
        COALESCE(p_data->>'schedule_type', 'Meeting'),
        COALESCE(p_data->>'category', 'General'),
        COALESCE(p_data->>'color', '#4F46E5'),
        COALESCE(p_data->>'priority', 'normal'),
        'confirmed', 'approved',
        v_start_time, v_end_time,
        COALESCE((p_data->>'is_all_day')::BOOLEAN, FALSE),
        COALESCE(p_data->>'timezone', 'Asia/Kolkata'),
        p_data->>'location_name',
        p_data->>'location_address',
        p_data->>'building',
        p_data->>'room',
        p_data->>'landmark',
        (p_data->>'latitude')::DOUBLE PRECISION,
        (p_data->>'longitude')::DOUBLE PRECISION,
        p_data->>'virtual_meeting_url',
        p_data->>'virtual_meeting_provider',
        p_user_id, p_user_id,
        COALESCE(p_data->>'visibility', 'shared'),
        COALESCE((p_data->>'is_recurring')::BOOLEAN, FALSE),
        v_route_id,
        v_aud_type,
        v_target_roles,
        v_target_classes,
        v_target_class_sections,
        v_target_users,
        COALESCE(p_data->'metadata', '{}'::jsonb),
        NOW(), NOW()
    ) RETURNING * INTO v_sched_rec;

    -- 5. Insert Manual Participants (if any explicitly given)
    IF jsonb_array_length(COALESCE(p_data->'participants', '[]'::jsonb)) > 0 THEN
        FOR v_p_elem IN SELECT * FROM jsonb_array_elements(p_data->'participants') LOOP
            INSERT INTO public.schedule_participants (
                id, schedule_id, user_id, target_role, target_department, target_class, target_section,
                participant_type, participation_role, permission, rsvp_status, created_at
            ) VALUES (
                gen_random_uuid(), v_sched_id,
                CASE WHEN v_p_elem->>'user_id' IS NOT NULL AND (v_p_elem->>'user_id') != '' THEN (v_p_elem->>'user_id')::UUID ELSE NULL END,
                v_p_elem->>'target_role',
                v_p_elem->>'target_department',
                v_p_elem->>'target_class',
                v_p_elem->>'target_section',
                COALESCE(v_p_elem->>'participant_type', 'individual'),
                COALESCE(v_p_elem->>'participation_role', 'required'),
                COALESCE(v_p_elem->>'permission', 'can_view'),
                'pending', NOW()
            );
        END LOOP;
    END IF;

    -- 6. Resolve Audience Dynamically (Roles, Class-Sections, Subjects, Students, Teachers)
    PERFORM public.fn_resolve_schedule_audience(
        p_school_id,
        v_sched_id,
        v_target_roles,
        v_target_classes,
        v_target_class_sections,
        v_target_users
    );

    -- 7. Insert Resource Bookings
    IF jsonb_array_length(COALESCE(p_data->'resources', '[]'::jsonb)) > 0 THEN
        FOR v_r_elem IN SELECT * FROM jsonb_array_elements(p_data->'resources') LOOP
            INSERT INTO public.resource_bookings (
                id, schedule_id, resource_id, start_time, end_time, status, created_at
            ) VALUES (
                gen_random_uuid(), v_sched_id,
                (v_r_elem->>'resource_id')::UUID,
                v_start_time, v_end_time,
                'confirmed', NOW()
            );
        END LOOP;
    END IF;

    -- 8. Insert Reminders
    IF jsonb_array_length(COALESCE(p_data->'reminders', '[]'::jsonb)) > 0 THEN
        FOR v_rem_elem IN SELECT * FROM jsonb_array_elements(p_data->'reminders') LOOP
            INSERT INTO public.schedule_reminders (
                id, schedule_id, user_id, minutes_before, channel, is_sent, created_at
            ) VALUES (
                gen_random_uuid(), v_sched_id, p_user_id,
                COALESCE((v_rem_elem->>'minutes_before')::INT, 15),
                COALESCE(v_rem_elem->>'channel', 'in_app'),
                FALSE, NOW()
            );
        END LOOP;
    END IF;

    -- 9. Insert Recurrence Rule if recurring
    IF COALESCE((p_data->>'is_recurring')::BOOLEAN, FALSE) AND (p_data->>'frequency') IS NOT NULL AND (p_data->>'frequency') != 'none' THEN
        INSERT INTO public.schedule_recurrence (
            id, schedule_id, frequency, interval, days_of_week, day_of_month, month_of_year,
            end_type, end_count, end_date, exceptions, created_at
        ) VALUES (
            gen_random_uuid(), v_sched_id,
            p_data->>'frequency',
            COALESCE((p_data->>'interval')::INT, 1),
            COALESCE(p_data->'days_of_week', '[]'::jsonb),
            (p_data->>'day_of_month')::INT,
            (p_data->>'month_of_year')::INT,
            COALESCE(p_data->>'end_type', 'never'),
            (p_data->>'end_count')::INT,
            CASE WHEN p_data->>'end_date' IS NOT NULL AND (p_data->>'end_date') != '' THEN (p_data->>'end_date')::TIMESTAMPTZ ELSE NULL END,
            '[]'::jsonb,
            NOW()
        );
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Schedule created successfully.',
        'data', to_jsonb(v_sched_rec)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 6. Stored Procedure: fn_update_schedule (Updated with Class-Section-Subject resolution)
CREATE OR REPLACE FUNCTION public.fn_update_schedule(
    p_schedule_id UUID,
    p_school_id UUID,
    p_user_id UUID,
    p_data JSONB,
    p_recurrence_scope TEXT DEFAULT 'entire_series',
    p_target_instance_date DATE DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_sched public.schedules%ROWTYPE;
    v_start_time TIMESTAMPTZ;
    v_end_time TIMESTAMPTZ;
    v_target_roles JSONB;
    v_target_classes JSONB;
    v_target_class_sections JSONB;
    v_target_users JSONB;
    v_p_elem JSONB;
    v_r_elem JSONB;
    v_rem_elem JSONB;
    v_route_id UUID;
    v_aud_type TEXT;
BEGIN
    SELECT * INTO v_sched
    FROM public.schedules
    WHERE id = p_schedule_id AND (school_id = p_school_id OR school_id IS NULL) AND deleted_at IS NULL;

    IF v_sched.id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Schedule not found');
    END IF;

    v_start_time := CASE WHEN p_data->>'start_time' IS NOT NULL THEN public.parse_tz_timestamp(p_data->>'start_time', COALESCE(p_data->>'timezone', v_sched.timezone)) ELSE v_sched.start_time END;
    v_end_time := CASE WHEN p_data->>'end_time' IS NOT NULL THEN public.parse_tz_timestamp(p_data->>'end_time', COALESCE(p_data->>'timezone', v_sched.timezone)) ELSE v_sched.end_time END;

    v_target_roles := COALESCE(p_data->'target_roles', v_sched.target_roles);
    v_target_classes := COALESCE(p_data->'target_classes', v_sched.target_classes);
    v_target_class_sections := COALESCE(p_data->'target_class_sections', v_sched.target_class_sections);
    v_target_users := COALESCE(p_data->'target_user_ids', v_sched.target_user_ids);

    v_aud_type := v_sched.audience_type;
    IF jsonb_array_length(v_target_roles) > 0 THEN
        v_aud_type := 'role';
    ELSIF jsonb_array_length(v_target_class_sections) > 0 OR jsonb_array_length(v_target_classes) > 0 THEN
        v_aud_type := 'class_section';
    ELSIF (COALESCE(p_data->>'visibility', v_sched.visibility)) = 'institution_wide' THEN
        v_aud_type := 'all';
    END IF;

    IF p_data->>'route_id' IS NOT NULL THEN
        v_route_id := NULLIF(p_data->>'route_id', '')::UUID;
    ELSE
        v_route_id := v_sched.route_id;
    END IF;

    -- Update Master Record
    UPDATE public.schedules SET
        calendar_id = COALESCE(NULLIF(p_data->>'calendar_id', '')::UUID, calendar_id),
        title = COALESCE(p_data->>'title', title),
        description = COALESCE(p_data->>'description', description),
        schedule_type = COALESCE(p_data->>'schedule_type', schedule_type),
        category = COALESCE(p_data->>'category', category),
        color = COALESCE(p_data->>'color', color),
        priority = COALESCE(p_data->>'priority', priority),
        start_time = v_start_time,
        end_time = v_end_time,
        is_all_day = COALESCE((p_data->>'is_all_day')::BOOLEAN, is_all_day),
        timezone = COALESCE(p_data->>'timezone', timezone),
        location_name = COALESCE(p_data->>'location_name', location_name),
        location_address = COALESCE(p_data->>'location_address', location_address),
        building = COALESCE(p_data->>'building', building),
        room = COALESCE(p_data->>'room', room),
        virtual_meeting_url = COALESCE(p_data->>'virtual_meeting_url', virtual_meeting_url),
        virtual_meeting_provider = COALESCE(p_data->>'virtual_meeting_provider', virtual_meeting_provider),
        visibility = COALESCE(p_data->>'visibility', visibility),
        is_recurring = COALESCE((p_data->>'is_recurring')::BOOLEAN, is_recurring),
        route_id = v_route_id,
        audience_type = v_aud_type,
        target_roles = v_target_roles,
        target_classes = v_target_classes,
        target_class_sections = v_target_class_sections,
        target_user_ids = v_target_users,
        metadata = COALESCE(p_data->'metadata', metadata),
        updated_at = NOW()
    WHERE id = p_schedule_id;

    -- Refresh Participants if provided
    IF p_data->'participants' IS NOT NULL OR p_data->'target_class_sections' IS NOT NULL OR p_data->'target_roles' IS NOT NULL THEN
        DELETE FROM public.schedule_participants WHERE schedule_id = p_schedule_id;

        IF jsonb_array_length(COALESCE(p_data->'participants', '[]'::jsonb)) > 0 THEN
            FOR v_p_elem IN SELECT * FROM jsonb_array_elements(p_data->'participants') LOOP
                INSERT INTO public.schedule_participants (
                    id, schedule_id, user_id, target_role, target_department, target_class, target_section,
                    participant_type, participation_role, permission, rsvp_status, created_at
                ) VALUES (
                    gen_random_uuid(), p_schedule_id,
                    CASE WHEN v_p_elem->>'user_id' IS NOT NULL AND (v_p_elem->>'user_id') != '' THEN (v_p_elem->>'user_id')::UUID ELSE NULL END,
                    v_p_elem->>'target_role',
                    v_p_elem->>'target_department',
                    v_p_elem->>'target_class',
                    v_p_elem->>'target_section',
                    COALESCE(v_p_elem->>'participant_type', 'individual'),
                    COALESCE(v_p_elem->>'participation_role', 'required'),
                    COALESCE(v_p_elem->>'permission', 'can_view'),
                    'pending', NOW()
                );
            END LOOP;
        END IF;

        PERFORM public.fn_resolve_schedule_audience(
            p_school_id,
            p_schedule_id,
            v_target_roles,
            v_target_classes,
            v_target_class_sections,
            v_target_users
        );
    END IF;

    -- Refresh Resource Bookings if provided
    IF p_data->'resources' IS NOT NULL THEN
        DELETE FROM public.resource_bookings WHERE schedule_id = p_schedule_id;
        IF jsonb_array_length(p_data->'resources') > 0 THEN
            FOR v_r_elem IN SELECT * FROM jsonb_array_elements(p_data->'resources') LOOP
                INSERT INTO public.resource_bookings (
                    id, schedule_id, resource_id, start_time, end_time, status, created_at
                ) VALUES (
                    gen_random_uuid(), p_schedule_id,
                    (v_r_elem->>'resource_id')::UUID,
                    v_start_time, v_end_time,
                    'confirmed', NOW()
                );
            END LOOP;
        END IF;
    END IF;

    -- Refresh Reminders if provided
    IF p_data->'reminders' IS NOT NULL THEN
        DELETE FROM public.schedule_reminders WHERE schedule_id = p_schedule_id;
        IF jsonb_array_length(p_data->'reminders') > 0 THEN
            FOR v_rem_elem IN SELECT * FROM jsonb_array_elements(p_data->'reminders') LOOP
                INSERT INTO public.schedule_reminders (
                    id, schedule_id, user_id, minutes_before, channel, is_sent, created_at
                ) VALUES (
                    gen_random_uuid(), p_schedule_id, p_user_id,
                    COALESCE((v_rem_elem->>'minutes_before')::INT, 15),
                    COALESCE(v_rem_elem->>'channel', 'in_app'),
                    FALSE, NOW()
                );
            END LOOP;
        END IF;
    END IF;

    SELECT * INTO v_sched FROM public.schedules WHERE id = p_schedule_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Schedule updated successfully.',
        'data', to_jsonb(v_sched)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 7. Stored Procedure: fn_get_schedule_details (Enhanced to return class-section-subjects & enriched participants)
CREATE OR REPLACE FUNCTION public.fn_get_schedule_details(
    p_school_id UUID,
    p_schedule_id UUID,
    p_target_instance_date DATE DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_sched public.schedules%ROWTYPE;
    v_cal public.calendars%ROWTYPE;
    v_org public.profiles%ROWTYPE;
    v_participants JSONB;
    v_resources JSONB;
    v_reminders JSONB;
    v_recurrence JSONB;
    v_trip_id UUID;
    v_trip_status TEXT;
    v_res JSONB;
BEGIN
    SELECT * INTO v_sched
    FROM public.schedules
    WHERE id = p_schedule_id AND (school_id = p_school_id OR school_id IS NULL) AND deleted_at IS NULL;

    IF v_sched.id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Schedule not found');
    END IF;

    SELECT * INTO v_cal FROM public.calendars WHERE id = v_sched.calendar_id;
    SELECT * INTO v_org FROM public.profiles WHERE id = v_sched.organizer_id;

    -- Participants aggregation
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', sp.id,
            'user_id', sp.user_id,
            'target_role', sp.target_role,
            'target_class', sp.target_class,
            'target_section', sp.target_section,
            'target_subject_id', sp.target_subject_id,
            'target_subject', sp.target_subject,
            'class_id', sp.class_id,
            'section_id', sp.section_id,
            'participant_type', sp.participant_type,
            'participation_role', sp.participation_role,
            'permission', sp.permission,
            'rsvp_status', sp.rsvp_status,
            'decline_reason', sp.decline_reason,
            'rsvp_at', sp.rsvp_at,
            'full_name', COALESCE(p.full_name,
                CASE 
                    WHEN sp.target_subject IS NOT NULL THEN sp.target_class || ' - ' || sp.target_section || ' (' || sp.target_subject || ')'
                    WHEN sp.target_section IS NOT NULL THEN sp.target_class || ' - ' || sp.target_section
                    WHEN sp.target_class IS NOT NULL THEN sp.target_class
                    WHEN sp.target_role IS NOT NULL THEN 'All ' || initcap(sp.target_role)
                    ELSE 'Participant'
                END
            ),
            'email', p.email,
            'avatar_url', p.avatar_url,
            'role', COALESCE(p.role, sp.target_role)
        )
    ), '[]'::jsonb)
    INTO v_participants
    FROM public.schedule_participants sp
    LEFT JOIN public.profiles p ON p.id = sp.user_id
    WHERE sp.schedule_id = p_schedule_id;

    -- Resources aggregation
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', rb.id,
            'resource_id', rb.resource_id,
            'name', cr.name,
            'code', cr.code,
            'type', cr.type,
            'building', cr.building,
            'room_number', cr.room_number,
            'status', rb.status
        )
    ), '[]'::jsonb)
    INTO v_resources
    FROM public.resource_bookings rb
    JOIN public.calendar_resources cr ON cr.id = rb.resource_id
    WHERE rb.schedule_id = p_schedule_id;

    -- Reminders aggregation
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', sr.id,
            'minutes_before', sr.minutes_before,
            'channel', sr.channel,
            'is_sent', sr.is_sent
        )
    ), '[]'::jsonb)
    INTO v_reminders
    FROM public.schedule_reminders sr
    WHERE sr.schedule_id = p_schedule_id;

    -- Recurrence
    SELECT jsonb_build_object(
        'id', rec.id,
        'frequency', rec.frequency,
        'interval', rec.interval,
        'days_of_week', rec.days_of_week,
        'day_of_month', rec.day_of_month,
        'month_of_year', rec.month_of_year,
        'end_type', rec.end_type,
        'end_count', rec.end_count,
        'end_date', rec.end_date,
        'exceptions', rec.exceptions
    )
    INTO v_recurrence
    FROM public.schedule_recurrence rec
    WHERE rec.schedule_id = p_schedule_id;

    -- Real-time trip status if route linked
    IF v_sched.route_id IS NOT NULL THEN
        SELECT vt.id, vt.status INTO v_trip_id, v_trip_status
        FROM public.vehicle_trips vt
        WHERE (vt.schedule_id = p_schedule_id OR (v_sched.recurring_parent_id IS NOT NULL AND vt.schedule_id = v_sched.recurring_parent_id) OR vt.route_id = v_sched.route_id)
          AND (
              p_target_instance_date IS NULL
              OR vt.schedule_instance_date = p_target_instance_date
              OR vt.start_date = p_target_instance_date::TEXT
          )
        ORDER BY CASE WHEN vt.status IN ('in_progress', 'paused') THEN 1 WHEN vt.status = 'completed' THEN 2 ELSE 3 END, vt.updated_at DESC
        LIMIT 1;
    END IF;

    v_res := to_jsonb(v_sched);
    v_res := v_res || jsonb_build_object(
        'calendar_name', v_cal.name,
        'calendar_color', v_cal.color,
        'calendar_type', v_cal.type,
        'organizer_name', v_org.full_name,
        'organizer_avatar', v_org.avatar_url,
        'participants', v_participants,
        'resources', v_resources,
        'reminders', v_reminders,
        'recurrence', v_recurrence,
        'trip_id', v_trip_id,
        'trip_status', v_trip_status
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', v_res
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
