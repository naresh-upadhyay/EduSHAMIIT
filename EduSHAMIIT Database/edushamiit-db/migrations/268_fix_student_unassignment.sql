-- Migration 268: Fix Student Assignment, Unassignment, and Target-Aware Conflict Detection

-- 1. Resilient audit log recording
CREATE OR REPLACE FUNCTION public.fn_record_class_audit(
    p_school_id UUID,
    p_user_id UUID,
    p_event_type VARCHAR,
    p_action VARCHAR,
    p_resource VARCHAR,
    p_resource_type VARCHAR,
    p_resource_id UUID,
    p_details JSONB DEFAULT '{}'::JSONB,
    p_before_state JSONB DEFAULT NULL,
    p_after_state JSONB DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_valid_user_id UUID := NULL;
    v_user_email VARCHAR(255) := 'system@edushamiit.internal';
    v_user_name VARCHAR(255) := 'System User';
    v_user_role VARCHAR(50) := 'super_admin';
BEGIN
    IF p_user_id IS NOT NULL THEN
        SELECT id, email, full_name, role 
        INTO v_valid_user_id, v_user_email, v_user_name, v_user_role
        FROM public.profiles 
        WHERE id = p_user_id;
    END IF;

    INSERT INTO public.audit_logs (
        school_id,
        user_id,
        user_email,
        user_name,
        user_role,
        event_type,
        module,
        action,
        resource,
        resource_type,
        status,
        changes,
        created_at
    ) VALUES (
        p_school_id,
        v_valid_user_id,
        COALESCE(v_user_email, 'system@edushamiit.internal'),
        COALESCE(v_user_name, 'System User'),
        COALESCE(v_user_role, 'super_admin'),
        p_event_type,
        'Class Management',
        p_action,
        p_resource,
        p_resource_type,
        'Success',
        jsonb_build_object(
            'class_id', p_resource_id,
            'details', p_details,
            'before_state', p_before_state,
            'after_state', p_after_state
        ),
        NOW()
    );
END;
$$;


-- 2. Update fn_check_student_assignments with target class/section awareness
CREATE OR REPLACE FUNCTION public.fn_check_student_assignments(
    p_school_id UUID,
    p_student_ids UUID[],
    p_academic_year VARCHAR DEFAULT '2026-27',
    p_target_class_id UUID DEFAULT NULL,
    p_target_section_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_conflicts JSONB;
BEGIN
    IF p_student_ids IS NULL OR array_length(p_student_ids, 1) = 0 THEN
        RETURN jsonb_build_object(
            'success', TRUE,
            'has_conflicts', FALSE,
            'conflicts', '[]'::JSONB
        );
    END IF;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'student_id', sca.student_id,
                'student_name', p.full_name,
                'admission_number', p.admission_number,
                'roll_number', sca.roll_number,
                'current_class_id', c.id,
                'current_class_name', c.name,
                'current_section_id', s.id,
                'current_section_name', s.name
            )
        ),
        '[]'::JSONB
    ) INTO v_conflicts
    FROM public.student_class_assignments sca
    JOIN public.profiles p ON p.id = sca.student_id
    JOIN public.academic_classes c ON c.id = sca.class_id
    LEFT JOIN public.academic_sections s ON s.id = sca.section_id
    WHERE sca.school_id = p_school_id
      AND sca.academic_year = p_academic_year
      AND sca.student_id = ANY(p_student_ids)
      AND sca.status = 'ACTIVE'
      -- Exclude students who are already in the target class and section (not a conflict move)
      AND NOT (
          (p_target_section_id IS NOT NULL AND sca.class_id = p_target_class_id AND sca.section_id = p_target_section_id)
          OR
          (p_target_section_id IS NULL AND p_target_class_id IS NOT NULL AND sca.class_id = p_target_class_id AND sca.section_id IS NULL)
      );

    RETURN jsonb_build_object(
        'success', TRUE,
        'has_conflicts', (jsonb_array_length(v_conflicts) > 0),
        'conflicts', v_conflicts
    );
END;
$$;


-- 3. Update fn_assign_class_students with full unassignment / reconciliation support
CREATE OR REPLACE FUNCTION public.fn_assign_class_students(
    p_school_id UUID,
    p_user_id UUID,
    p_class_id UUID,
    p_section_id UUID,
    p_student_ids UUID[],
    p_academic_year VARCHAR DEFAULT '2026-27',
    p_confirm_move BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_conflicts JSONB;
    v_std_id UUID;
    v_assigned_count INT := 0;
BEGIN
    -- Verify Class Exists
    IF NOT EXISTS (
        SELECT 1 FROM public.academic_classes 
        WHERE id = p_class_id AND school_id = p_school_id AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Class not found', 'code', 404);
    END IF;

    -- If section is specified, verify section exists in this class
    IF p_section_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.academic_sections 
        WHERE id = p_section_id AND class_id = p_class_id AND school_id = p_school_id AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Section not found in class', 'code', 404);
    END IF;

    -- Check if selected students have conflicting assignments in other classes/sections
    IF p_student_ids IS NOT NULL AND array_length(p_student_ids, 1) > 0 AND NOT p_confirm_move THEN
        SELECT (public.fn_check_student_assignments(p_school_id, p_student_ids, p_academic_year, p_class_id, p_section_id))->'conflicts' 
        INTO v_conflicts;

        IF jsonb_array_length(v_conflicts) > 0 THEN
            RETURN jsonb_build_object(
                'success', FALSE,
                'requires_confirmation', TRUE,
                'error', 'Some selected students are already assigned to other classes/sections.',
                'conflicts', v_conflicts,
                'code', 409
            );
        END IF;
    END IF;

    -- 1. Clear existing student assignments for this target class/section scope
    IF p_section_id IS NOT NULL THEN
        DELETE FROM public.student_class_assignments
        WHERE school_id = p_school_id
          AND class_id = p_class_id
          AND section_id = p_section_id
          AND academic_year = p_academic_year;
    ELSE
        DELETE FROM public.student_class_assignments
        WHERE school_id = p_school_id
          AND class_id = p_class_id
          AND section_id IS NULL
          AND academic_year = p_academic_year;
    END IF;

    -- 2. Insert new student assignments
    IF p_student_ids IS NOT NULL AND array_length(p_student_ids, 1) > 0 THEN
        FOREACH v_std_id IN ARRAY p_student_ids LOOP
            -- Delete any old assignment for this student in other classes/sections in same academic year
            DELETE FROM public.student_class_assignments
            WHERE school_id = p_school_id
              AND student_id = v_std_id
              AND academic_year = p_academic_year;

            -- Insert new assignment
            INSERT INTO public.student_class_assignments (
                school_id, class_id, section_id, student_id, academic_year, status
            ) VALUES (
                p_school_id, p_class_id, p_section_id, v_std_id, p_academic_year, 'ACTIVE'
            );

            v_assigned_count := v_assigned_count + 1;
        END LOOP;
    END IF;

    PERFORM public.fn_record_class_audit(
        p_school_id, p_user_id, 'Update', 'Assigned Students', p_class_id::TEXT, 'CLASS', p_class_id,
        jsonb_build_object('section_id', p_section_id, 'students_assigned', v_assigned_count)
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', v_assigned_count::TEXT || ' students assigned successfully.',
        'assigned_count', v_assigned_count
    );
END;
$$;


-- 4. Function: Update Academic Section (Returning complete metadata)
CREATE OR REPLACE FUNCTION public.fn_update_academic_section(
    p_school_id UUID,
    p_user_id UUID,
    p_section_id UUID,
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_curr RECORD;
    v_name VARCHAR(50);
    v_code VARCHAR(50);
    v_capacity INT;
    v_room_number VARCHAR(50);
    v_status VARCHAR(20);
BEGIN
    SELECT * INTO v_curr
    FROM public.academic_sections
    WHERE id = p_section_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Section not found', 'code', 404);
    END IF;

    v_name := TRIM(COALESCE(p_payload->>'name', v_curr.name));
    v_code := UPPER(TRIM(COALESCE(p_payload->>'code', v_curr.code)));
    v_capacity := COALESCE((p_payload->>'capacity')::INT, v_curr.capacity);
    v_room_number := TRIM(COALESCE(p_payload->>'room_number', v_curr.room_number));
    v_status := UPPER(TRIM(COALESCE(p_payload->>'status', v_curr.status)));

    IF v_name != v_curr.name AND EXISTS (
        SELECT 1 FROM public.academic_sections
        WHERE school_id = p_school_id
          AND class_id = v_curr.class_id
          AND academic_year = v_curr.academic_year
          AND UPPER(name) = UPPER(v_name)
          AND id != p_section_id
          AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Section "' || v_name || '" already exists in this class', 'code', 409);
    END IF;

    UPDATE public.academic_sections SET
        name = v_name,
        code = v_code,
        capacity = v_capacity,
        room_number = v_room_number,
        status = v_status,
        updated_by = p_user_id,
        updated_at = NOW()
    WHERE id = p_section_id;

    PERFORM public.fn_record_class_audit(
        p_school_id, p_user_id, 'Update', 'Updated Academic Section', v_name, 'SECTION', p_section_id,
        jsonb_build_object('name', v_name, 'code', v_code, 'status', v_status),
        to_jsonb(v_curr),
        jsonb_build_object('name', v_name, 'code', v_code, 'status', v_status)
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Section updated successfully',
        'data', jsonb_build_object(
            'id', p_section_id,
            'name', v_name,
            'code', v_code,
            'capacity', v_capacity,
            'room_number', v_room_number,
            'status', v_status
        )
    );
END;
$$;


-- 5. Function: Search Students from User Management (profiles) with Assignment Info & Filters
CREATE OR REPLACE FUNCTION public.fn_search_academic_students(
    p_school_id UUID,
    p_search TEXT DEFAULT '',
    p_academic_year VARCHAR DEFAULT '2026-27',
    p_class_id UUID DEFAULT NULL,
    p_section_id UUID DEFAULT NULL,
    p_limit INT DEFAULT 50
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_students JSONB;
BEGIN
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', p.id,
                'full_name', p.full_name,
                'email', p.email,
                'admission_number', COALESCE(p.admission_number, 'ADM' || SUBSTRING(p.id::TEXT FROM 1 FOR 4)),
                'roll_number', COALESCE(sca.roll_number, p.roll_number::TEXT),
                'avatar_url', p.avatar_url,
                'status', COALESCE(p.status, 'ACTIVE'),
                'current_class_id', sca.class_id,
                'current_class_name', c.name,
                'current_section_id', sca.section_id,
                'current_section_name', s.name,
                'is_assigned', (sca.id IS NOT NULL)
            ) ORDER BY p.full_name ASC
        ),
        '[]'::JSONB
    ) INTO v_students
    FROM (
        SELECT p.*
        FROM public.profiles p
        WHERE p.school_id = p_school_id
          AND LOWER(p.role) = 'student'
          AND (
              p_search = '' 
              OR p.full_name ILIKE '%' || p_search || '%' 
              OR p.email ILIKE '%' || p_search || '%'
              OR p.admission_number ILIKE '%' || p_search || '%'
          )
        LIMIT p_limit
    ) p
    LEFT JOIN public.student_class_assignments sca 
        ON sca.student_id = p.id 
       AND sca.school_id = p_school_id 
       AND sca.academic_year = p_academic_year 
       AND sca.status = 'ACTIVE'
    LEFT JOIN public.academic_classes c ON c.id = sca.class_id
    LEFT JOIN public.academic_sections s ON s.id = sca.section_id
    WHERE (p_class_id IS NULL OR sca.class_id = p_class_id)
      AND (p_section_id IS NULL OR sca.section_id = p_section_id);

    RETURN jsonb_build_object('success', TRUE, 'data', v_students);
END;
$$;


