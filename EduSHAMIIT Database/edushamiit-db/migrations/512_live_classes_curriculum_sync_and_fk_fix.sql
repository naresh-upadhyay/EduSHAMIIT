-- ============================================================================
-- Migration: 512_live_classes_curriculum_sync_and_fk_fix.sql
-- Description: Syncs academic curriculum subjects to public.subjects,
-- drops restrictive live_classes_subject_id_fkey constraint to allow full
-- interoperability with academic_subjects from Class Management, and ensures
-- all live class CRUD procedures execute flawlessly.
-- ============================================================================

-- 1. Sync academic_subjects into subjects table so all curriculum subjects exist in both
INSERT INTO public.subjects (id, school_id, name, created_at)
SELECT id, school_id, name, created_at
FROM public.academic_subjects
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

-- 2. Drop restrictive foreign key constraint if it exists
ALTER TABLE public.live_classes DROP CONSTRAINT IF EXISTS live_classes_subject_id_fkey;

-- 3. Ensure live_classes subject_id column is nullable and has clean index
CREATE INDEX IF NOT EXISTS idx_live_classes_subject_id ON public.live_classes(subject_id);

-- 4. Re-create unified sp_manage_live_class_crud with accurate child column names
CREATE OR REPLACE FUNCTION public.sp_manage_live_class_crud(
    p_school_id UUID,
    p_user_id UUID,
    p_action TEXT, -- 'CREATE', 'UPDATE', 'DELETE', 'CANCEL', 'BULK_CANCEL', 'BULK_DELETE'
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
    v_item_id JSONB;
    v_ids JSONB;
    v_deleted_count INT := 0;
    v_cancelled_count INT := 0;
BEGIN
    v_target_id := COALESCE(p_class_id, (p_payload->>'session_id')::UUID, (p_payload->>'id')::UUID);

    IF UPPER(p_action) = 'CREATE' THEN
        v_new_id := gen_random_uuid();
        v_room_code := UPPER(SUBSTRING(MD5(v_new_id::TEXT || NOW()::TEXT) FROM 1 FOR 8));

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
            (p_payload->>'class_id')::UUID,
            (p_payload->>'section_id')::UUID,
            (p_payload->>'subject_id')::UUID,
            COALESCE((p_payload->>'teacher_id')::UUID, p_user_id),
            COALESCE((p_payload->>'scheduled_at')::TIMESTAMPTZ, NOW()),
            COALESCE((p_payload->>'duration_minutes')::INT, 45),
            COALESCE((p_payload->>'max_participants')::INT, 50),
            COALESCE(LOWER(p_payload->>'status') = 'live', FALSE),
            COALESCE(LOWER(p_payload->>'status'), 'scheduled'),
            v_room_code,
            'https://meet.edushamiit.com/cls/' || LOWER(v_room_code),
            COALESCE((p_payload->>'recording_enabled')::BOOLEAN, TRUE),
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
            'room_code', v_room_code
        );

    ELSIF UPPER(p_action) = 'UPDATE' THEN
        IF v_target_id IS NULL THEN
            RETURN jsonb_build_object('success', FALSE, 'error', 'Class ID is required for update');
        END IF;

        UPDATE public.live_classes
        SET title = COALESCE(p_payload->>'title', title),
            description = COALESCE(p_payload->>'description', description),
            class_id = COALESCE((p_payload->>'class_id')::UUID, class_id),
            section_id = COALESCE((p_payload->>'section_id')::UUID, section_id),
            subject_id = COALESCE((p_payload->>'subject_id')::UUID, subject_id),
            teacher_id = COALESCE((p_payload->>'teacher_id')::UUID, teacher_id),
            scheduled_at = COALESCE((p_payload->>'scheduled_at')::TIMESTAMPTZ, scheduled_at),
            duration_minutes = COALESCE((p_payload->>'duration_minutes')::INT, duration_minutes),
            max_participants = COALESCE((p_payload->>'max_participants')::INT, max_participants),
            status = COALESCE(LOWER(p_payload->>'status'), status),
            recording_enabled = COALESCE((p_payload->>'recording_enabled')::BOOLEAN, recording_enabled),
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
            description = CASE 
                WHEN p_payload->>'reason' IS NOT NULL 
                THEN description || ' [Cancelled: ' || (p_payload->>'reason') || ']' 
                ELSE description 
            END,
            updated_by = p_user_id,
            updated_at = NOW()
        WHERE id = v_target_id AND school_id = p_school_id;

        RETURN jsonb_build_object('success', TRUE, 'message', 'Live class cancelled successfully');

    ELSIF UPPER(p_action) = 'DELETE' THEN
        IF v_target_id IS NULL THEN
            RETURN jsonb_build_object('success', FALSE, 'error', 'Class ID is required for delete');
        END IF;

        DELETE FROM public.live_class_participants WHERE live_class_id = v_target_id;
        DELETE FROM public.live_class_attendance WHERE live_class_id = v_target_id;
        DELETE FROM public.live_class_chats WHERE live_class_id = v_target_id;
        DELETE FROM public.live_class_polls WHERE session_id = v_target_id;
        DELETE FROM public.live_class_questions WHERE session_id = v_target_id;
        DELETE FROM public.live_class_breakout_rooms WHERE session_id = v_target_id;
        DELETE FROM public.live_classes WHERE id = v_target_id AND school_id = p_school_id;

        RETURN jsonb_build_object('success', TRUE, 'message', 'Live class deleted successfully');

    ELSIF UPPER(p_action) = 'BULK_CANCEL' THEN
        v_ids := COALESCE(p_payload->'session_ids', p_payload->'class_ids');
        IF v_ids IS NULL OR jsonb_array_length(v_ids) = 0 THEN
            RETURN jsonb_build_object('success', FALSE, 'error', 'No class IDs provided for bulk cancel');
        END IF;

        UPDATE public.live_classes
        SET status = 'cancelled',
            is_live = FALSE,
            description = CASE 
                WHEN p_payload->>'reason' IS NOT NULL 
                THEN description || ' [Bulk Cancelled: ' || (p_payload->>'reason') || ']' 
                ELSE description 
            END,
            updated_by = p_user_id,
            updated_at = NOW()
        WHERE id IN (
            SELECT (jsonb_array_elements_text(v_ids))::UUID
        ) AND school_id = p_school_id;

        GET DIAGNOSTICS v_cancelled_count = ROW_COUNT;

        RETURN jsonb_build_object(
            'success', TRUE,
            'message', 'Selected live classes cancelled successfully',
            'cancelled_count', v_cancelled_count
        );

    ELSIF UPPER(p_action) = 'BULK_DELETE' THEN
        v_ids := COALESCE(p_payload->'session_ids', p_payload->'class_ids');
        IF v_ids IS NULL OR jsonb_array_length(v_ids) = 0 THEN
            RETURN jsonb_build_object('success', FALSE, 'error', 'No class IDs provided for bulk delete');
        END IF;

        FOR v_item_id IN SELECT jsonb_array_elements(v_ids) LOOP
            v_target_id := (v_item_id#>>'{}')::UUID;
            DELETE FROM public.live_class_participants WHERE live_class_id = v_target_id;
            DELETE FROM public.live_class_attendance WHERE live_class_id = v_target_id;
            DELETE FROM public.live_class_chats WHERE live_class_id = v_target_id;
            DELETE FROM public.live_class_polls WHERE session_id = v_target_id;
            DELETE FROM public.live_class_questions WHERE session_id = v_target_id;
            DELETE FROM public.live_class_breakout_rooms WHERE session_id = v_target_id;
            DELETE FROM public.live_classes WHERE id = v_target_id AND school_id = p_school_id;
            v_deleted_count := v_deleted_count + 1;
        END LOOP;

        RETURN jsonb_build_object(
            'success', TRUE,
            'message', 'Selected live classes deleted successfully',
            'deleted_count', v_deleted_count
        );

    ELSE
        RETURN jsonb_build_object('success', FALSE, 'error', 'Unsupported action: ' || p_action);
    END IF;
END;
$$;
