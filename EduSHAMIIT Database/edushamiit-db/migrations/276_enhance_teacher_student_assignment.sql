-- ============================================================================
-- Migration 276: Enhance Teacher & Student Assignment and Section Queries
-- ============================================================================

-- 1. Search Teachers from User Management (profiles)
CREATE OR REPLACE FUNCTION public.fn_search_academic_teachers(
    p_school_id UUID,
    p_search TEXT DEFAULT '',
    p_limit INT DEFAULT 100
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_teachers JSONB;
BEGIN
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', p.id,
                'full_name', p.full_name,
                'name', p.full_name,
                'email', p.email,
                'employee_id', COALESCE(p.employee_id, 'EMP' || SUBSTRING(p.id::TEXT FROM 1 FOR 4)),
                'department', COALESCE(p.department, 'Academic'),
                'avatar_url', p.avatar_url,
                'status', COALESCE(p.status, 'ACTIVE')
            ) ORDER BY p.full_name ASC
        ),
        '[]'::JSONB
    ) INTO v_teachers
    FROM (
        SELECT *
        FROM public.profiles p
        WHERE p.school_id = p_school_id
          AND (
              LOWER(p.role) IN ('teacher', 'faculty', 'instructor', 'staff', 'admin', 'principal', 'headmaster', 'coordinator', 'superadmin', 'super_admin')
              OR p.role IS NULL
          )
          AND (
              p_search = '' 
              OR p.full_name ILIKE '%' || p_search || '%' 
              OR p.email ILIKE '%' || p_search || '%'
              OR p.employee_id ILIKE '%' || p_search || '%'
              OR p.department ILIKE '%' || p_search || '%'
          )
        ORDER BY p.full_name ASC
        LIMIT p_limit
    ) p;

    RETURN jsonb_build_object('success', TRUE, 'data', v_teachers);
END;
$$;


-- 2. Search Students from User Management (profiles) with Live Assignment Info
CREATE OR REPLACE FUNCTION public.fn_search_academic_students(
    p_school_id UUID,
    p_search TEXT DEFAULT '',
    p_academic_year VARCHAR DEFAULT '2026-27',
    p_class_id UUID DEFAULT NULL,
    p_section_id UUID DEFAULT NULL,
    p_limit INT DEFAULT 200
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
                'name', p.full_name,
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
          AND (
              LOWER(p.role) = 'student' 
              OR p.role IS NULL 
              OR LOWER(p.role) NOT IN ('teacher', 'faculty', 'staff', 'admin', 'principal', 'super_admin', 'superadmin', 'driver')
          )
          AND (
              p_search = '' 
              OR p.full_name ILIKE '%' || p_search || '%' 
              OR p.email ILIKE '%' || p_search || '%'
              OR p.admission_number ILIKE '%' || p_search || '%'
          )
        ORDER BY p.full_name ASC
        LIMIT p_limit
    ) p
    LEFT JOIN public.student_class_assignments sca 
        ON sca.student_id = p.id 
       AND sca.school_id = p_school_id 
       AND sca.academic_year = p_academic_year 
       AND sca.status = 'ACTIVE'
    LEFT JOIN public.academic_classes c ON c.id = sca.class_id
    LEFT JOIN public.academic_sections s ON s.id = sca.section_id;

    RETURN jsonb_build_object('success', TRUE, 'data', v_students);
END;
$$;


-- 3. Check Student Move Conflicts
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
      AND NOT (
          p_target_class_id IS NOT NULL 
          AND sca.class_id = p_target_class_id 
          AND (
              (p_target_section_id IS NULL AND sca.section_id IS NULL) 
              OR sca.section_id = p_target_section_id
          )
      );

    RETURN jsonb_build_object(
        'success', TRUE,
        'has_conflicts', (jsonb_array_length(v_conflicts) > 0),
        'conflicts', v_conflicts
    );
END;
$$;


-- 4. Assign / Update Class or Section Teachers
CREATE OR REPLACE FUNCTION public.fn_assign_class_teachers(
    p_school_id UUID,
    p_user_id UUID,
    p_class_id UUID,
    p_section_id UUID,
    p_teacher_ids UUID[],
    p_academic_year VARCHAR DEFAULT '2026-27'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_t_id UUID;
    v_idx INT := 1;
    v_is_primary BOOLEAN;
BEGIN
    -- Verify Class Exists
    IF NOT EXISTS (
        SELECT 1 FROM public.academic_classes 
        WHERE id = p_class_id AND school_id = p_school_id AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Class not found', 'code', 404);
    END IF;

    -- Clear existing assignments for this specific scope
    IF p_section_id IS NOT NULL THEN
        DELETE FROM public.class_teacher_assignments
        WHERE school_id = p_school_id
          AND section_id = p_section_id
          AND academic_year = p_academic_year;
    ELSE
        DELETE FROM public.class_teacher_assignments
        WHERE school_id = p_school_id
          AND class_id = p_class_id
          AND section_id IS NULL
          AND academic_year = p_academic_year;
    END IF;

    -- Insert new teacher assignments
    IF p_teacher_ids IS NOT NULL AND array_length(p_teacher_ids, 1) > 0 THEN
        FOREACH v_t_id IN ARRAY p_teacher_ids LOOP
            v_is_primary := (v_idx = 1);

            INSERT INTO public.class_teacher_assignments (
                school_id, class_id, section_id, teacher_id, academic_year, is_primary
            ) VALUES (
                p_school_id, p_class_id, p_section_id, v_t_id, p_academic_year, v_is_primary
            ) ON CONFLICT DO NOTHING;

            v_idx := v_idx + 1;
        END LOOP;
    END IF;

    PERFORM public.fn_record_class_audit(
        p_school_id, p_user_id, 'Update', 'Assigned Class Teachers', COALESCE(p_section_id, p_class_id)::TEXT, 'CLASS', p_class_id,
        jsonb_build_object('section_id', p_section_id, 'teacher_count', COALESCE(array_length(p_teacher_ids, 1), 0))
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Class teacher assigned successfully',
        'assigned_count', COALESCE(array_length(p_teacher_ids, 1), 0)
    );
END;
$$;


-- 5. Assign Students to Class or Section (with Safe Move Support & Deselection Sync)
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

    -- If section_id is provided, verify section exists
    IF p_section_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.academic_sections
        WHERE id = p_section_id AND school_id = p_school_id AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Section not found', 'code', 404);
    END IF;

    -- If student_ids is empty or null, unassign all students from this section
    IF p_section_id IS NOT NULL AND (p_student_ids IS NULL OR array_length(p_student_ids, 1) IS NULL OR array_length(p_student_ids, 1) = 0) THEN
        DELETE FROM public.student_class_assignments
        WHERE school_id = p_school_id
          AND section_id = p_section_id
          AND academic_year = p_academic_year;

        PERFORM public.fn_record_class_audit(
            p_school_id, p_user_id, 'Update', 'Cleared Section Students', p_section_id::TEXT, 'SECTION', p_class_id,
            jsonb_build_object('section_id', p_section_id, 'student_count', 0)
        );

        RETURN jsonb_build_object(
            'success', TRUE,
            'message', 'Students unassigned successfully',
            'assigned_count', 0
        );
    END IF;

    -- Check if students have conflicting assignments (excluding students already assigned to this target)
    IF NOT p_confirm_move THEN
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
          AND NOT (sca.class_id = p_class_id AND ((p_section_id IS NULL AND sca.section_id IS NULL) OR sca.section_id = p_section_id));

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

    -- Remove students from this section who were deselected
    IF p_section_id IS NOT NULL THEN
        DELETE FROM public.student_class_assignments
        WHERE school_id = p_school_id
          AND section_id = p_section_id
          AND academic_year = p_academic_year
          AND NOT (student_id = ANY(p_student_ids));
    END IF;

    -- Reassign / Insert Students
    IF p_student_ids IS NOT NULL AND array_length(p_student_ids, 1) > 0 THEN
        FOREACH v_std_id IN ARRAY p_student_ids LOOP
            DELETE FROM public.student_class_assignments
            WHERE school_id = p_school_id
              AND student_id = v_std_id
              AND academic_year = p_academic_year;

            INSERT INTO public.student_class_assignments (
                school_id, class_id, section_id, student_id, academic_year, status
            ) VALUES (
                p_school_id, p_class_id, p_section_id, v_std_id, p_academic_year, 'ACTIVE'
            );

            v_assigned_count := v_assigned_count + 1;
        END LOOP;
    END IF;

    PERFORM public.fn_record_class_audit(
        p_school_id, p_user_id, 'Update', 'Assigned Students to Section', COALESCE(p_section_id, p_class_id)::TEXT, 'SECTION', p_class_id,
        jsonb_build_object('section_id', p_section_id, 'student_count', v_assigned_count)
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Students assigned successfully',
        'assigned_count', v_assigned_count
    );
END;
$$;


-- 6. Comprehensive Sections Retrieval with Both class_teacher and section_teacher
CREATE OR REPLACE FUNCTION public.fn_get_academic_sections(
    p_school_id UUID,
    p_class_id UUID DEFAULT NULL,
    p_search TEXT DEFAULT '',
    p_academic_year VARCHAR DEFAULT '2026-27',
    p_status VARCHAR DEFAULT 'ALL',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_sort_by VARCHAR DEFAULT 'name',
    p_sort_order VARCHAR DEFAULT 'ASC',
    p_teacher_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_count INT := 0;
    v_offset INT := (GREATEST(p_page, 1) - 1) * p_page_size;
    v_sections JSONB := '[]'::JSONB;
BEGIN
    SELECT COUNT(*)
    INTO v_total_count
    FROM public.academic_sections s
    JOIN public.academic_classes c ON c.id = s.class_id
    WHERE s.school_id = p_school_id
      AND s.academic_year = p_academic_year
      AND (p_class_id IS NULL OR s.class_id = p_class_id)
      AND (
          (p_status = 'ALL' AND s.deleted_at IS NULL)
          OR (p_status = 'ARCHIVED' AND (UPPER(TRIM(s.status)) = 'ARCHIVED' OR s.deleted_at IS NOT NULL))
          OR (p_status != 'ALL' AND UPPER(TRIM(s.status)) = UPPER(TRIM(p_status)) AND s.deleted_at IS NULL)
      )
      AND (
          p_teacher_id IS NULL
          OR EXISTS (
              SELECT 1 FROM public.class_teacher_assignments cta
              WHERE cta.teacher_id = p_teacher_id
                AND (cta.section_id = s.id OR (cta.class_id = s.class_id AND cta.section_id IS NULL))
                AND cta.academic_year = p_academic_year
          )
          OR EXISTS (
              SELECT 1 FROM public.section_subject_teachers sst
              WHERE sst.section_id = s.id AND sst.teacher_id = p_teacher_id
          )
      )
      AND (
          p_search = '' 
          OR s.name ILIKE '%' || p_search || '%' 
          OR s.code ILIKE '%' || p_search || '%'
          OR c.name ILIKE '%' || p_search || '%'
          OR s.room_number ILIKE '%' || p_search || '%'
      );

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', s.id,
                'class_id', s.class_id,
                'class_name', s.class_name,
                'class_code', s.class_code,
                'name', s.name,
                'code', s.code,
                'capacity', s.capacity,
                'room_number', s.room_number,
                'room_id', s.room_id,
                'room_name', s.room_name,
                'building', s.building,
                'floor', s.floor,
                'academic_year', s.academic_year,
                'status', s.status,
                'students_count', (
                    SELECT COUNT(DISTINCT sca.student_id) 
                    FROM public.student_class_assignments sca 
                    WHERE sca.section_id = s.id AND sca.status = 'ACTIVE'
                ),
                'class_teacher', (
                    SELECT jsonb_build_object(
                        'id', p.id,
                        'name', p.full_name,
                        'full_name', p.full_name,
                        'email', p.email,
                        'employee_id', p.employee_id,
                        'department', p.department,
                        'avatar_url', p.avatar_url
                    )
                    FROM public.class_teacher_assignments cta
                    JOIN public.profiles p ON p.id = cta.teacher_id
                    WHERE (cta.section_id = s.id OR (cta.class_id = s.class_id AND cta.section_id IS NULL AND cta.is_primary = TRUE))
                      AND cta.academic_year = p_academic_year
                    ORDER BY (cta.section_id = s.id) DESC
                    LIMIT 1
                ),
                'section_teacher', (
                    SELECT jsonb_build_object(
                        'id', p.id,
                        'name', p.full_name,
                        'full_name', p.full_name,
                        'email', p.email,
                        'employee_id', p.employee_id,
                        'department', p.department,
                        'avatar_url', p.avatar_url
                    )
                    FROM public.class_teacher_assignments cta
                    JOIN public.profiles p ON p.id = cta.teacher_id
                    WHERE (cta.section_id = s.id OR (cta.class_id = s.class_id AND cta.section_id IS NULL AND cta.is_primary = TRUE))
                      AND cta.academic_year = p_academic_year
                    ORDER BY (cta.section_id = s.id) DESC
                    LIMIT 1
                ),
                'created_at', s.created_at,
                'updated_at', s.updated_at
            )
        ),
        '[]'::JSONB
    ) INTO v_sections
    FROM (
        SELECT 
            s.*,
            c.name as class_name,
            c.code as class_code,
            r.name as room_name,
            r.building as building,
            r.floor as floor
        FROM public.academic_sections s
        JOIN public.academic_classes c ON c.id = s.class_id
        LEFT JOIN public.academic_rooms r ON r.id = s.room_id
        WHERE s.school_id = p_school_id
          AND s.academic_year = p_academic_year
          AND (p_class_id IS NULL OR s.class_id = p_class_id)
          AND (
              (p_status = 'ALL' AND s.deleted_at IS NULL)
              OR (p_status = 'ARCHIVED' AND (UPPER(TRIM(s.status)) = 'ARCHIVED' OR s.deleted_at IS NOT NULL))
              OR (p_status != 'ALL' AND UPPER(TRIM(s.status)) = UPPER(TRIM(p_status)) AND s.deleted_at IS NULL)
          )
          AND (
              p_teacher_id IS NULL
              OR EXISTS (
                  SELECT 1 FROM public.class_teacher_assignments cta
                  WHERE cta.teacher_id = p_teacher_id
                    AND (cta.section_id = s.id OR (cta.class_id = s.class_id AND cta.section_id IS NULL))
                    AND cta.academic_year = p_academic_year
              )
              OR EXISTS (
                  SELECT 1 FROM public.section_subject_teachers sst
                  WHERE sst.section_id = s.id AND sst.teacher_id = p_teacher_id
              )
          )
          AND (
              p_search = '' 
              OR s.name ILIKE '%' || p_search || '%' 
              OR s.code ILIKE '%' || p_search || '%'
              OR c.name ILIKE '%' || p_search || '%'
              OR s.room_number ILIKE '%' || p_search || '%'
          )
        ORDER BY 
            CASE WHEN p_sort_by = 'name' AND p_sort_order ILIKE 'ASC' THEN s.name END ASC,
            CASE WHEN p_sort_by = 'name' AND p_sort_order ILIKE 'DESC' THEN s.name END DESC,
            s.created_at DESC
        LIMIT p_page_size OFFSET v_offset
    ) s;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'sections', v_sections,
            'total_count', v_total_count,
            'page', p_page,
            'page_size', p_page_size,
            'total_pages', CEIL(v_total_count::NUMERIC / GREATEST(p_page_size, 1)::NUMERIC)
        )
    );
END;
$$;
