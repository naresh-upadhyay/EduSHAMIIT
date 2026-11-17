-- ============================================================================
-- Migration: 515_enhance_live_class_scheduling_and_calendar_integration.sql
-- Description: Enhances sp_create_instant_live_class and sp_manage_live_class_crud
-- to fully support both scheduled classes (status = 'scheduled') and instant classes
-- (status = 'live'), resolving cascading curriculum keys, meeting links, and durations.
-- ============================================================================

-- 1. Upgrade sp_create_instant_live_class to handle both Instant & Scheduled Classes
CREATE OR REPLACE FUNCTION public.sp_create_instant_live_class(
    p_school_id UUID,
    p_user_id UUID,
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_class_id UUID := NULL;
    v_section_id UUID := NULL;
    v_subject_id UUID := NULL;
    v_teacher_id UUID := NULL;
    v_title TEXT := COALESCE(p_payload->>'title', 'Live Class Session');
    v_description TEXT := COALESCE(p_payload->>'description', '');
    v_duration_min INT := COALESCE((p_payload->>'duration_minutes')::INT, (p_payload->>'meeting_duration')::INT, 45);
    v_scheduled_at TIMESTAMPTZ := COALESCE((p_payload->>'scheduled_at')::TIMESTAMPTZ, (p_payload->>'start_time')::TIMESTAMPTZ, NOW());
    v_status TEXT := COALESCE(LOWER(p_payload->>'status'), 'scheduled');
    v_is_live BOOLEAN := COALESCE((p_payload->>'is_live')::BOOLEAN, (p_payload->>'start_immediately')::BOOLEAN, (v_status = 'live'), FALSE);
    v_recording_enabled BOOLEAN := COALESCE((p_payload->>'recording_enabled')::BOOLEAN, (p_payload->>'enable_recording')::BOOLEAN, TRUE);
    v_waiting_room BOOLEAN := COALESCE((p_payload->>'waiting_room_enabled')::BOOLEAN, FALSE);
    v_allow_share BOOLEAN := COALESCE((p_payload->>'allow_student_share')::BOOLEAN, FALSE);
    v_allow_mic BOOLEAN := COALESCE((p_payload->>'allow_student_mic')::BOOLEAN, TRUE);
    v_allow_cam BOOLEAN := COALESCE((p_payload->>'allow_student_cam')::BOOLEAN, TRUE);
    v_allow_chat BOOLEAN := COALESCE((p_payload->>'allow_chat')::BOOLEAN, TRUE);
    v_allow_reactions BOOLEAN := COALESCE((p_payload->>'allow_reactions')::BOOLEAN, TRUE);
    v_max_participants INT := COALESCE((p_payload->>'max_participants')::INT, 50);
    v_room_code VARCHAR(32);
    v_meeting_link TEXT;
    v_new_id UUID;
    v_result JSONB;
BEGIN
    -- Parse class_id (UUID or NULL)
    IF (p_payload->>'class_id') IS NOT NULL AND (p_payload->>'class_id') ~ '^[0-9a-fA-F-]{36}$' THEN
        v_class_id := (p_payload->>'class_id')::UUID;
    END IF;

    -- Parse section_id (UUID or NULL)
    IF (p_payload->>'section_id') IS NOT NULL AND (p_payload->>'section_id') ~ '^[0-9a-fA-F-]{36}$' THEN
        v_section_id := (p_payload->>'section_id')::UUID;
    END IF;

    -- Parse subject_id (UUID or NULL)
    IF (p_payload->>'subject_id') IS NOT NULL AND (p_payload->>'subject_id') ~ '^[0-9a-fA-F-]{36}$' THEN
        v_subject_id := (p_payload->>'subject_id')::UUID;
    END IF;

    -- Parse teacher_id
    IF (p_payload->>'teacher_id') IS NOT NULL AND (p_payload->>'teacher_id') ~ '^[0-9a-fA-F-]{36}$' THEN
        v_teacher_id := (p_payload->>'teacher_id')::UUID;
    ELSE
        v_teacher_id := p_user_id;
    END IF;

    -- Resolve class & section by name if IDs not provided
    IF v_class_id IS NULL AND (p_payload->>'class_name') IS NOT NULL THEN
        SELECT id INTO v_class_id
        FROM public.academic_classes
        WHERE school_id = p_school_id AND LOWER(name) = LOWER(TRIM(p_payload->>'class_name'))
        LIMIT 1;
    END IF;

    IF v_section_id IS NULL AND (p_payload->>'section_name') IS NOT NULL AND v_class_id IS NOT NULL THEN
        SELECT id INTO v_section_id
        FROM public.academic_sections
        WHERE school_id = p_school_id AND class_id = v_class_id AND LOWER(name) = LOWER(TRIM(p_payload->>'section_name'))
        LIMIT 1;
    END IF;

    -- Resolve subject by name if ID not provided
    IF v_subject_id IS NULL AND (p_payload->>'subject_name') IS NOT NULL THEN
        SELECT id INTO v_subject_id
        FROM public.academic_subjects
        WHERE school_id = p_school_id AND LOWER(name) = LOWER(TRIM(p_payload->>'subject_name'))
        LIMIT 1;
    END IF;

    -- If status is live, ensure is_live is TRUE
    IF v_is_live THEN
        v_status := 'live';
    ELSE
        IF v_status = 'live' THEN
            v_is_live := TRUE;
        ELSE
            v_status := 'scheduled';
            v_is_live := FALSE;
        END IF;
    END IF;

    -- Room code & Meeting Link
    v_room_code := UPPER(SUBSTRING(MD5(RANDOM()::TEXT || NOW()::TEXT), 1, 8));
    v_meeting_link := COALESCE(
        p_payload->>'meeting_link',
        p_payload->>'virtual_meeting_url',
        'https://meet.edushamiit.com/cls/' || LOWER(v_room_code)
    );

    v_new_id := gen_random_uuid();

    INSERT INTO public.live_classes (
        id, school_id, class_id, section_id, subject_id, teacher_id,
        title, description, duration_minutes, scheduled_at,
        platform, is_live, status, max_participants, room_code,
        meeting_link, recording_enabled, waiting_room_enabled,
        allow_student_share, allow_student_mic, allow_student_cam,
        allow_chat, allow_reactions, created_by, updated_by, created_at, updated_at
    ) VALUES (
        v_new_id, p_school_id, v_class_id, v_section_id, v_subject_id, v_teacher_id,
        v_title, v_description, v_duration_min, v_scheduled_at,
        'In-App', v_is_live, v_status, v_max_participants, v_room_code,
        v_meeting_link,
        v_recording_enabled, v_waiting_room,
        v_allow_share, v_allow_mic, v_allow_cam,
        v_allow_chat, v_allow_reactions, p_user_id, p_user_id, NOW(), NOW()
    );

    -- Return full newly created session
    SELECT jsonb_build_object(
        'id', c.id,
        'session_id', c.id,
        'title', c.title,
        'description', c.description,
        'class_id', c.class_id,
        'section_id', c.section_id,
        'subject_id', c.subject_id,
        'teacher_id', c.teacher_id,
        'room_code', c.room_code,
        'meeting_link', c.meeting_link,
        'status', c.status,
        'is_live', c.is_live,
        'duration_minutes', c.duration_minutes,
        'scheduled_at', c.scheduled_at,
        'recording_enabled', c.recording_enabled,
        'created_at', c.created_at
    ) INTO v_result
    FROM public.live_classes c
    WHERE c.id = v_new_id;

    RETURN v_result;
END;
$$;

-- 2. Upgrade sp_manage_live_class_crud CREATE action to handle both virtual links and class mappings
CREATE OR REPLACE FUNCTION public.sp_manage_live_class_crud(
    p_school_id UUID,
    p_user_id UUID,
    p_action TEXT,
    p_class_id UUID DEFAULT NULL,
    p_payload JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_new_id UUID;
    v_room_code VARCHAR(32);
    v_target_id UUID;
    v_meeting_link TEXT;
    v_class_id UUID := NULL;
    v_section_id UUID := NULL;
    v_subject_id UUID := NULL;
    v_teacher_id UUID := NULL;
    v_status TEXT;
    v_is_live BOOLEAN;
    v_deleted_count INT := 0;
    v_cancelled_count INT := 0;
    v_item_id JSONB;
    v_ids JSONB;
BEGIN
    v_target_id := COALESCE(p_class_id, (p_payload->>'session_id')::UUID, (p_payload->>'id')::UUID);

    IF UPPER(p_action) = 'CREATE' THEN
        v_new_id := gen_random_uuid();
        v_room_code := UPPER(SUBSTRING(MD5(v_new_id::TEXT || NOW()::TEXT) FROM 1 FOR 8));

        v_meeting_link := COALESCE(
            p_payload->>'meeting_link',
            p_payload->>'virtual_meeting_url',
            'https://meet.edushamiit.com/cls/' || LOWER(v_room_code)
        );

        -- Parse class_id (UUID or NULL)
        IF (p_payload->>'class_id') IS NOT NULL AND (p_payload->>'class_id') ~ '^[0-9a-fA-F-]{36}$' THEN
            v_class_id := (p_payload->>'class_id')::UUID;
        END IF;

        -- Parse section_id (UUID or NULL)
        IF (p_payload->>'section_id') IS NOT NULL AND (p_payload->>'section_id') ~ '^[0-9a-fA-F-]{36}$' THEN
            v_section_id := (p_payload->>'section_id')::UUID;
        END IF;

        -- Parse subject_id (UUID or NULL)
        IF (p_payload->>'subject_id') IS NOT NULL AND (p_payload->>'subject_id') ~ '^[0-9a-fA-F-]{36}$' THEN
            v_subject_id := (p_payload->>'subject_id')::UUID;
        END IF;

        -- Parse teacher_id
        IF (p_payload->>'teacher_id') IS NOT NULL AND (p_payload->>'teacher_id') ~ '^[0-9a-fA-F-]{36}$' THEN
            v_teacher_id := (p_payload->>'teacher_id')::UUID;
        ELSE
            v_teacher_id := p_user_id;
        END IF;

        v_status := COALESCE(LOWER(p_payload->>'status'), 'scheduled');
        v_is_live := COALESCE((p_payload->>'is_live')::BOOLEAN, (v_status = 'live'), FALSE);

        INSERT INTO public.live_classes (
            id, school_id, title, description, class_id, section_id, subject_id, teacher_id,
            scheduled_at, duration_minutes, max_participants, is_live, status,
            room_code, meeting_link, recording_enabled, waiting_room_enabled,
            allow_student_share, allow_student_mic, allow_student_cam,
            allow_chat, allow_reactions, created_by, updated_by, created_at, updated_at
        ) VALUES (
            v_new_id,
            p_school_id,
            COALESCE(p_payload->>'title', 'Live Class Session'),
            COALESCE(p_payload->>'description', ''),
            v_class_id,
            v_section_id,
            v_subject_id,
            v_teacher_id,
            COALESCE((p_payload->>'scheduled_at')::TIMESTAMPTZ, (p_payload->>'start_time')::TIMESTAMPTZ, NOW()),
            COALESCE((p_payload->>'duration_minutes')::INT, (p_payload->>'meeting_duration')::INT, 45),
            COALESCE((p_payload->>'max_participants')::INT, 50),
            v_is_live,
            v_status,
            v_room_code,
            v_meeting_link,
            COALESCE((p_payload->>'recording_enabled')::BOOLEAN, (p_payload->>'enable_recording')::BOOLEAN, TRUE),
            COALESCE((p_payload->>'waiting_room_enabled')::BOOLEAN, FALSE),
            COALESCE((p_payload->>'allow_student_share')::BOOLEAN, FALSE),
            COALESCE((p_payload->>'allow_student_mic')::BOOLEAN, TRUE),
            COALESCE((p_payload->>'allow_student_cam')::BOOLEAN, TRUE),
            COALESCE((p_payload->>'allow_chat')::BOOLEAN, TRUE),
            COALESCE((p_payload->>'allow_reactions')::BOOLEAN, TRUE),
            p_user_id,
            p_user_id,
            NOW(),
            NOW()
        );

        RETURN jsonb_build_object(
            'success', TRUE,
            'message', 'Live class created successfully',
            'id', v_new_id,
            'session_id', v_new_id,
            'room_code', v_room_code,
            'meeting_link', v_meeting_link,
            'status', v_status
        );

    ELSIF UPPER(p_action) = 'UPDATE' THEN
        IF v_target_id IS NULL THEN
            RETURN jsonb_build_object('success', FALSE, 'error', 'Class ID is required for update');
        END IF;

        UPDATE public.live_classes
        SET title = COALESCE(p_payload->>'title', title),
            description = COALESCE(p_payload->>'description', description),
            class_id = CASE WHEN (p_payload->>'class_id') IS NOT NULL AND (p_payload->>'class_id') ~ '^[0-9a-fA-F-]{36}$' THEN (p_payload->>'class_id')::UUID ELSE class_id END,
            section_id = CASE WHEN (p_payload->>'section_id') IS NOT NULL AND (p_payload->>'section_id') ~ '^[0-9a-fA-F-]{36}$' THEN (p_payload->>'section_id')::UUID ELSE section_id END,
            subject_id = CASE WHEN (p_payload->>'subject_id') IS NOT NULL AND (p_payload->>'subject_id') ~ '^[0-9a-fA-F-]{36}$' THEN (p_payload->>'subject_id')::UUID ELSE subject_id END,
            teacher_id = CASE WHEN (p_payload->>'teacher_id') IS NOT NULL AND (p_payload->>'teacher_id') ~ '^[0-9a-fA-F-]{36}$' THEN (p_payload->>'teacher_id')::UUID ELSE teacher_id END,
            scheduled_at = COALESCE((p_payload->>'scheduled_at')::TIMESTAMPTZ, (p_payload->>'start_time')::TIMESTAMPTZ, scheduled_at),
            duration_minutes = COALESCE((p_payload->>'duration_minutes')::INT, (p_payload->>'meeting_duration')::INT, duration_minutes),
            max_participants = COALESCE((p_payload->>'max_participants')::INT, max_participants),
            status = COALESCE(LOWER(p_payload->>'status'), status),
            recording_enabled = COALESCE((p_payload->>'recording_enabled')::BOOLEAN, (p_payload->>'enable_recording')::BOOLEAN, recording_enabled),
            meeting_link = COALESCE(p_payload->>'meeting_link', p_payload->>'virtual_meeting_url', meeting_link),
            updated_by = p_user_id,
            updated_at = NOW()
        WHERE id = v_target_id AND school_id = p_school_id;

        RETURN jsonb_build_object('success', TRUE, 'message', 'Live class updated successfully', 'id', v_target_id);

    ELSIF UPPER(p_action) = 'CANCEL' THEN
        IF v_target_id IS NULL THEN
            RETURN jsonb_build_object('success', FALSE, 'error', 'Class ID is required for cancel');
        END IF;

        UPDATE public.live_classes
        SET status = 'cancelled',
            is_live = FALSE,
            updated_by = p_user_id,
            updated_at = NOW()
        WHERE id = v_target_id AND school_id = p_school_id;

        RETURN jsonb_build_object('success', TRUE, 'message', 'Live class cancelled successfully', 'id', v_target_id);

    ELSIF UPPER(p_action) = 'DELETE' THEN
        IF v_target_id IS NULL THEN
            RETURN jsonb_build_object('success', FALSE, 'error', 'Class ID is required for deletion');
        END IF;

        DELETE FROM public.live_classes
        WHERE id = v_target_id AND school_id = p_school_id;

        RETURN jsonb_build_object('success', TRUE, 'message', 'Live class deleted successfully', 'id', v_target_id);

    ELSIF UPPER(p_action) = 'BULK_CANCEL' THEN
        v_ids := p_payload->'ids';
        IF v_ids IS NOT NULL AND jsonb_array_length(v_ids) > 0 THEN
            FOR v_item_id IN SELECT * FROM jsonb_array_elements_text(v_ids)
            LOOP
                UPDATE public.live_classes
                SET status = 'cancelled',
                    is_live = FALSE,
                    updated_by = p_user_id,
                    updated_at = NOW()
                WHERE id = (v_item_id #>> '{}')::UUID AND school_id = p_school_id;
                IF FOUND THEN
                    v_cancelled_count := v_cancelled_count + 1;
                END IF;
            END LOOP;
        END IF;

        RETURN jsonb_build_object(
            'success', TRUE,
            'message', 'Bulk cancel completed',
            'cancelled_count', v_cancelled_count
        );

    ELSIF UPPER(p_action) = 'BULK_DELETE' THEN
        v_ids := p_payload->'ids';
        IF v_ids IS NOT NULL AND jsonb_array_length(v_ids) > 0 THEN
            FOR v_item_id IN SELECT * FROM jsonb_array_elements_text(v_ids)
            LOOP
                DELETE FROM public.live_classes
                WHERE id = (v_item_id #>> '{}')::UUID AND school_id = p_school_id;
                IF FOUND THEN
                    v_deleted_count := v_deleted_count + 1;
                END IF;
            END LOOP;
        END IF;

        RETURN jsonb_build_object(
            'success', TRUE,
            'message', 'Bulk deletion completed',
            'deleted_count', v_deleted_count
        );

    ELSE
        RETURN jsonb_build_object('success', FALSE, 'error', 'Unsupported operation: ' || p_action);
    END IF;
END;
$$;
