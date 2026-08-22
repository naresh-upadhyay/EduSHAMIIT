-- ============================================================================
-- Migration: 296_fix_schedule_deduplication_and_audience_integrity.sql
-- Description:
--   1. Cleans existing duplicate records in schedule_participants.
--   2. Adds unique index on (schedule_id, user_id) WHERE user_id IS NOT NULL.
--   3. Rewrites fn_resolve_schedule_audience with strict deduplication and precise
--      teacher/student resolution for class-section vs class-section-subject combos.
--   4. Rewrites fn_create_schedule, fn_update_schedule, and fn_get_schedule_details.
-- ============================================================================

-- 1. Deduplicate existing schedule_participants rows
DELETE FROM public.schedule_participants a
USING public.schedule_participants b
WHERE a.id > b.id
  AND a.schedule_id = b.schedule_id
  AND (
      (a.user_id IS NOT NULL AND a.user_id = b.user_id)
      OR (a.user_id IS NULL AND b.user_id IS NULL 
          AND COALESCE(a.class_id, '00000000-0000-0000-0000-000000000000'::uuid) = COALESCE(b.class_id, '00000000-0000-0000-0000-000000000000'::uuid)
          AND COALESCE(a.section_id, '00000000-0000-0000-0000-000000000000'::uuid) = COALESCE(b.section_id, '00000000-0000-0000-0000-000000000000'::uuid)
          AND COALESCE(a.target_subject_id, '00000000-0000-0000-0000-000000000000'::uuid) = COALESCE(b.target_subject_id, '00000000-0000-0000-0000-000000000000'::uuid)
          AND COALESCE(a.target_role, '') = COALESCE(b.target_role, ''))
  );

-- 2. Create Unique Index for Individual Participants (One row per user per schedule)
CREATE UNIQUE INDEX IF NOT EXISTS idx_sched_part_unique_user
    ON public.schedule_participants (schedule_id, user_id)
    WHERE user_id IS NOT NULL;

-- 3. Stored Procedure: fn_resolve_schedule_audience (Strict Deduplication & Clear Offerings)
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
    v_role_user RECORD;
BEGIN
    -- 1. Insert explicit manual user IDs (from search box)
    IF p_target_user_ids IS NOT NULL AND jsonb_typeof(p_target_user_ids) = 'array' THEN
        FOR v_uid_elem IN SELECT jsonb_array_elements_text(p_target_user_ids) LOOP
            IF v_uid_elem IS NOT NULL AND v_uid_elem != '' THEN
                IF NOT EXISTS (
                    SELECT 1 FROM public.schedule_participants
                    WHERE schedule_id = p_schedule_id AND user_id = v_uid_elem::UUID
                ) THEN
                    INSERT INTO public.schedule_participants (
                        id, schedule_id, user_id, participant_type, participation_role, permission, rsvp_status, created_at
                    ) VALUES (
                        gen_random_uuid(), p_schedule_id, v_uid_elem::UUID, 'individual', 'required', 'can_view', 'pending', NOW()
                    );
                END IF;
            END IF;
        END LOOP;
    END IF;

    -- 2. Process Role broadcasts
    IF p_target_roles IS NOT NULL AND jsonb_typeof(p_target_roles) = 'array' THEN
        FOR v_role_elem IN SELECT jsonb_array_elements_text(p_target_roles) LOOP
            IF v_role_elem IS NOT NULL AND trim(v_role_elem) != '' THEN
                -- Insert Role Group Broadcast Marker (if not exists)
                IF NOT EXISTS (
                    SELECT 1 FROM public.schedule_participants
                    WHERE schedule_id = p_schedule_id AND user_id IS NULL AND lower(target_role) = lower(trim(v_role_elem))
                ) THEN
                    INSERT INTO public.schedule_participants (
                        id, schedule_id, user_id, target_role, participant_type, participation_role, permission, rsvp_status, created_at
                    ) VALUES (
                        gen_random_uuid(), p_schedule_id, NULL, lower(trim(v_role_elem)), 'role', 'required', 'can_view', 'pending', NOW()
                    );
                END IF;

                -- Resolve all active users having this role
                FOR v_role_user IN
                    SELECT DISTINCT p.id AS user_id
                    FROM public.profiles p
                    WHERE (p.school_id = p_school_id OR p_school_id IS NULL)
                      AND lower(COALESCE(p.role, '')) = lower(trim(v_role_elem))
                LOOP
                    IF NOT EXISTS (
                        SELECT 1 FROM public.schedule_participants
                        WHERE schedule_id = p_schedule_id AND user_id = v_role_user.user_id
                    ) THEN
                        INSERT INTO public.schedule_participants (
                            id, schedule_id, user_id, target_role, participant_type, participation_role, permission, rsvp_status, created_at
                        ) VALUES (
                            gen_random_uuid(), p_schedule_id, v_role_user.user_id, lower(trim(v_role_elem)), 'individual', 'required', 'can_view', 'pending', NOW()
                        );
                    END IF;
                END LOOP;
            END IF;
        END LOOP;
    END IF;

    -- 3. Process Legacy/Simple Class broadcasts (if any)
    IF p_target_classes IS NOT NULL AND jsonb_typeof(p_target_classes) = 'array' THEN
        FOR v_class_elem IN SELECT jsonb_array_elements_text(p_target_classes) LOOP
            IF v_class_elem IS NOT NULL AND trim(v_class_elem) != '' THEN
                IF NOT EXISTS (
                    SELECT 1 FROM public.schedule_participants
                    WHERE schedule_id = p_schedule_id AND user_id IS NULL AND target_class = trim(v_class_elem)
                ) THEN
                    INSERT INTO public.schedule_participants (
                        id, schedule_id, user_id, target_class, participant_type, participation_role, permission, rsvp_status, created_at
                    ) VALUES (
                        gen_random_uuid(), p_schedule_id, NULL, trim(v_class_elem), 'class_section', 'required', 'can_view', 'pending', NOW()
                    );
                END IF;
            END IF;
        END LOOP;
    END IF;

    -- 4. Process Detailed Class-Section & Subject Offerings
    IF p_target_class_sections IS NOT NULL AND jsonb_typeof(p_target_class_sections) = 'array' THEN
        FOR v_cs_elem IN SELECT * FROM jsonb_array_elements(p_target_class_sections) LOOP
            v_cid := NULLIF(v_cs_elem->>'class_id', '')::UUID;
            v_sid := NULLIF(v_cs_elem->>'section_id', '')::UUID;
            v_sub_id := NULLIF(v_cs_elem->>'subject_id', '')::UUID;
            v_cname := v_cs_elem->>'class_name';
            v_sname := v_cs_elem->>'section_name';
            v_subname := v_cs_elem->>'subject_name';

            -- Fill names from DB if missing
            IF v_cname IS NULL AND v_cid IS NOT NULL THEN
                SELECT name INTO v_cname FROM public.academic_classes WHERE id = v_cid;
            END IF;
            IF v_sname IS NULL AND v_sid IS NOT NULL THEN
                SELECT name INTO v_sname FROM public.academic_sections WHERE id = v_sid;
            END IF;
            IF v_subname IS NULL AND v_sub_id IS NOT NULL THEN
                SELECT name INTO v_subname FROM public.academic_subjects WHERE id = v_sub_id;
            END IF;

            -- A. Insert 1 Group Marker for this Class-Section / Class-Section-Subject offering
            IF NOT EXISTS (
                SELECT 1 FROM public.schedule_participants
                WHERE schedule_id = p_schedule_id
                  AND user_id IS NULL
                  AND COALESCE(class_id, '00000000-0000-0000-0000-000000000000'::uuid) = COALESCE(v_cid, '00000000-0000-0000-0000-000000000000'::uuid)
                  AND COALESCE(section_id, '00000000-0000-0000-0000-000000000000'::uuid) = COALESCE(v_sid, '00000000-0000-0000-0000-000000000000'::uuid)
                  AND COALESCE(target_subject_id, '00000000-0000-0000-0000-000000000000'::uuid) = COALESCE(v_sub_id, '00000000-0000-0000-0000-000000000000'::uuid)
            ) THEN
                INSERT INTO public.schedule_participants (
                    id, schedule_id, user_id, class_id, section_id, target_class, target_section,
                    target_subject_id, target_subject, participant_type, participation_role, permission, rsvp_status, created_at
                ) VALUES (
                    gen_random_uuid(), p_schedule_id, NULL, v_cid, v_sid, v_cname, v_sname,
                    v_sub_id, v_subname, 'class_section', 'required', 'can_view', 'pending', NOW()
                );
            END IF;

            -- B. Resolve Enrolled Students in this section
            FOR v_stud_rec IN
                SELECT DISTINCT sca.student_id
                FROM public.student_class_assignments sca
                WHERE (v_sid IS NOT NULL AND sca.section_id = v_sid)
                   OR (v_sid IS NULL AND v_cid IS NOT NULL AND sca.class_id = v_cid)
            LOOP
                IF v_stud_rec.student_id IS NOT NULL THEN
                    IF NOT EXISTS (
                        SELECT 1 FROM public.schedule_participants
                        WHERE schedule_id = p_schedule_id AND user_id = v_stud_rec.student_id
                    ) THEN
                        INSERT INTO public.schedule_participants (
                            id, schedule_id, user_id, class_id, section_id, target_class, target_section,
                            target_subject_id, target_subject, participant_type, participation_role, permission, rsvp_status, created_at
                        ) VALUES (
                            gen_random_uuid(), p_schedule_id, v_stud_rec.student_id, v_cid, v_sid, v_cname, v_sname,
                            v_sub_id, v_subname, 'individual', 'required', 'can_view', 'pending', NOW()
                        );
                    END IF;
                END IF;
            END LOOP;

            -- C. Resolve Teachers:
            IF v_sub_id IS NOT NULL THEN
                -- CASE 1: Specific Class-Section-Subject combo -> Only teacher(s) assigned to THIS subject in this section
                FOR v_teach_rec IN
                    SELECT DISTINCT sst.teacher_id
                    FROM public.section_subject_teachers sst
                    WHERE sst.subject_id = v_sub_id
                      AND ((v_sid IS NOT NULL AND sst.section_id = v_sid) OR (v_sid IS NULL AND v_cid IS NOT NULL AND sst.class_id = v_cid))
                LOOP
                    IF v_teach_rec.teacher_id IS NOT NULL THEN
                        IF NOT EXISTS (
                            SELECT 1 FROM public.schedule_participants
                            WHERE schedule_id = p_schedule_id AND user_id = v_teach_rec.teacher_id
                        ) THEN
                            INSERT INTO public.schedule_participants (
                                id, schedule_id, user_id, class_id, section_id, target_class, target_section,
                                target_subject_id, target_subject, participant_type, participation_role, permission, rsvp_status, created_at
                            ) VALUES (
                                gen_random_uuid(), p_schedule_id, v_teach_rec.teacher_id, v_cid, v_sid, v_cname, v_sname,
                                v_sub_id, v_subname, 'individual', 'required', 'can_view', 'pending', NOW()
                            );
                        END IF;
                    END IF;
                END LOOP;
            ELSE
                -- CASE 2: General Class-Section combo (None subject) -> Class Teacher + all Section Subject Teachers
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
                        IF NOT EXISTS (
                            SELECT 1 FROM public.schedule_participants
                            WHERE schedule_id = p_schedule_id AND user_id = v_teach_rec.teacher_id
                        ) THEN
                            INSERT INTO public.schedule_participants (
                                id, schedule_id, user_id, class_id, section_id, target_class, target_section,
                                target_subject_id, target_subject, participant_type, participation_role, permission, rsvp_status, created_at
                            ) VALUES (
                                gen_random_uuid(), p_schedule_id, v_teach_rec.teacher_id, v_cid, v_sid, v_cname, v_sname,
                                NULL, NULL, 'individual', 'required', 'can_view', 'pending', NOW()
                            );
                        END IF;
                    END IF;
                END LOOP;
            END IF;
        END LOOP;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 4. Stored Procedure: fn_create_schedule (Clean, Atomic, Non-Duplicating)
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

    -- 3. Extract targeting parameters
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

    -- 5. Resolve & Insert Participants atomically with deduplication
    PERFORM public.fn_resolve_schedule_audience(
        p_school_id,
        v_sched_id,
        v_target_roles,
        v_target_classes,
        v_target_class_sections,
        v_target_users
    );

    -- 6. Insert Resource Bookings
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

    -- 7. Insert Reminders
    IF jsonb_array_length(COALESCE(p_data->'reminders', '[]'::jsonb)) > 0 THEN
        FOR v_rem_elem IN SELECT * FROM jsonb_array_elements(p_data->'reminders') LOOP
            INSERT INTO public.schedule_reminders (
                id, schedule_id, minutes_before, channel, is_sent, created_at
            ) VALUES (
                gen_random_uuid(), v_sched_id,
                (v_rem_elem->>'minutes_before')::INT,
                COALESCE(v_rem_elem->>'channel', 'in_app'),
                FALSE, NOW()
            );
        END LOOP;
    END IF;

    -- 8. Recurrence Rule setup
    IF COALESCE((p_data->>'is_recurring')::BOOLEAN, FALSE) = TRUE THEN
        INSERT INTO public.schedule_recurrence (
            id, schedule_id, frequency, interval, days_of_week, day_of_month, month_of_year,
            end_type, end_count, end_date, exceptions, created_at
        ) VALUES (
            gen_random_uuid(), v_sched_id,
            COALESCE(p_data->>'frequency', 'daily'),
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


-- 5. Stored Procedure: fn_update_schedule (Clean Replacement, Non-Duplicating)
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

    -- Atomically refresh Participants without duplication
    IF p_data->'target_class_sections' IS NOT NULL OR p_data->'target_roles' IS NOT NULL OR p_data->'target_user_ids' IS NOT NULL OR p_data->'participants' IS NOT NULL THEN
        DELETE FROM public.schedule_participants WHERE schedule_id = p_schedule_id;

        PERFORM public.fn_resolve_schedule_audience(
            p_school_id,
            p_schedule_id,
            v_target_roles,
            v_target_classes,
            v_target_class_sections,
            v_target_users
        );
    END IF;

    -- Refresh Resource Bookings
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

    -- Refresh Reminders
    IF p_data->'reminders' IS NOT NULL THEN
        DELETE FROM public.schedule_reminders WHERE schedule_id = p_schedule_id;
        IF jsonb_array_length(p_data->'reminders') > 0 THEN
            FOR v_rem_elem IN SELECT * FROM jsonb_array_elements(p_data->'reminders') LOOP
                INSERT INTO public.schedule_reminders (
                    id, schedule_id, minutes_before, channel, is_sent, created_at
                ) VALUES (
                    gen_random_uuid(), p_schedule_id,
                    (v_rem_elem->>'minutes_before')::INT,
                    COALESCE(v_rem_elem->>'channel', 'in_app'),
                    FALSE, NOW()
                );
            END LOOP;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Schedule updated successfully.'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 6. Stored Procedure: fn_get_schedule_details (Deduplicated Participant Output)
DROP FUNCTION IF EXISTS public.fn_get_schedule_details(UUID, UUID, DATE);
CREATE OR REPLACE FUNCTION public.fn_get_schedule_details(
    p_school_id UUID,
    p_schedule_id UUID,
    p_target_instance_date DATE DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_sched public.schedules%ROWTYPE;
    v_cal public.calendars%ROWTYPE;
    v_org public.profiles%ROWTYPE;
    v_participants JSONB := '[]'::jsonb;
    v_resources JSONB := '[]'::jsonb;
    v_reminders JSONB := '[]'::jsonb;
    v_recurrence JSONB := NULL;
    v_res JSONB;
    v_trip_id UUID;
    v_trip_status TEXT;
BEGIN
    SELECT * INTO v_sched
    FROM public.schedules
    WHERE id = p_schedule_id AND (school_id = p_school_id OR school_id IS NULL) AND deleted_at IS NULL;

    IF v_sched.id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Schedule not found');
    END IF;

    SELECT * INTO v_cal FROM public.calendars WHERE id = v_sched.calendar_id;
    SELECT * INTO v_org FROM public.profiles WHERE id = v_sched.organizer_id;

    -- Participants aggregation: Deduplicated, with clear full_name for group and individual items
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
            'full_name', COALESCE(
                p.full_name,
                CASE 
                    WHEN sp.target_subject IS NOT NULL THEN (sp.target_class || ' - ' || sp.target_section || ' • ' || sp.target_subject)
                    WHEN sp.target_section IS NOT NULL THEN (sp.target_class || ' - ' || sp.target_section)
                    WHEN sp.target_class IS NOT NULL THEN sp.target_class
                    WHEN sp.target_role IS NOT NULL THEN ('All ' || initcap(replace(sp.target_role, '_', ' ')))
                    ELSE 'Participant'
                END
            ),
            'email', p.email,
            'avatar_url', p.avatar_url,
            'role', COALESCE(p.role, sp.target_role, (
                CASE 
                    WHEN sp.target_subject IS NOT NULL THEN 'Subject Offering'
                    WHEN sp.target_section IS NOT NULL THEN 'Class-Section'
                    ELSE 'Group'
                END
            ))
        )
    ), '[]'::jsonb)
    INTO v_participants
    FROM (
        -- Select only distinct participants: for users, 1 row per user_id; for groups, 1 row per target definition
        SELECT DISTINCT ON (COALESCE(sp_inner.user_id, sp_inner.id))
            sp_inner.*
        FROM public.schedule_participants sp_inner
        WHERE sp_inner.schedule_id = p_schedule_id
        ORDER BY COALESCE(sp_inner.user_id, sp_inner.id), sp_inner.created_at ASC
    ) sp
    LEFT JOIN public.profiles p ON p.id = sp.user_id;

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
