CREATE TABLE IF NOT EXISTS public.room_allocations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    room_id UUID NOT NULL REFERENCES public.academic_rooms(id) ON DELETE CASCADE,
    academic_year VARCHAR(20) NOT NULL DEFAULT '2026-27',
    class_id UUID REFERENCES public.academic_classes(id) ON DELETE SET NULL,
    section_id UUID REFERENCES public.academic_sections(id) ON DELETE SET NULL,
    subject_id UUID REFERENCES public.academic_subjects(id) ON DELETE SET NULL,
    teacher_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    day_of_week INTEGER NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    title TEXT,
    allocation_type VARCHAR(50) DEFAULT 'TIMETABLE',
    status VARCHAR(50) DEFAULT 'ACTIVE',
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_room_allocations_lookup ON public.room_allocations(school_id, room_id, academic_year, day_of_week, status);

CREATE OR REPLACE FUNCTION public.fn_allocate_room(
    p_school_id UUID,
    p_user_id UUID,
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_room_id UUID := (p_payload->>'room_id')::UUID;
    v_academic_year VARCHAR := COALESCE(p_payload->>'academic_year', '2026-27');
    v_class_id UUID := NULLIF(p_payload->>'class_id', '')::UUID;
    v_section_id UUID := NULLIF(p_payload->>'section_id', '')::UUID;
    v_subject_id UUID := NULLIF(p_payload->>'subject_id', '')::UUID;
    v_teacher_id UUID := NULLIF(p_payload->>'teacher_id', '')::UUID;
    v_day_of_week INT := (p_payload->>'day_of_week')::INT;
    v_start_time TIME := (p_payload->>'start_time')::TIME;
    v_end_time TIME := (p_payload->>'end_time')::TIME;
    v_title TEXT := COALESCE(p_payload->>'title', 'Room Allocation');
    v_allocation_type TEXT := COALESCE(p_payload->>'allocation_type', 'TIMETABLE');
    v_conflict JSONB;
    v_new_id UUID;
BEGIN
    -- Check conflicts
    v_conflict := public.fn_check_room_conflicts(
        p_school_id, v_room_id, v_day_of_week, v_start_time, v_end_time,
        v_academic_year, v_teacher_id, v_section_id, NULL
    );

    IF (v_conflict->>'has_conflict')::BOOLEAN THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'code', 409,
            'error', v_conflict->>'message',
            'conflict', v_conflict
        );
    END IF;

    INSERT INTO public.room_allocations (
        school_id, room_id, academic_year, class_id, section_id,
        subject_id, teacher_id, day_of_week, start_time, end_time,
        title, allocation_type, status, created_by, updated_by
    ) VALUES (
        p_school_id, v_room_id, v_academic_year, v_class_id, v_section_id,
        v_subject_id, v_teacher_id, v_day_of_week, v_start_time, v_end_time,
        v_title, v_allocation_type, 'ACTIVE', p_user_id, p_user_id
    ) RETURNING id INTO v_new_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Room allocated successfully',
        'data', jsonb_build_object('id', v_new_id)
    );
END;
$function$;
