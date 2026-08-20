-- ============================================================================
-- Migration 288: Enforce Class -> Section -> Subject Assignment Hierarchy Integrity
-- Hierarchy: Grandparent (Class) -> Parent (Section) -> Child (Subject Offering)
-- Rules:
-- 1. If Class is INACTIVE -> all its Sections and Subject Assignments must be INACTIVE.
-- 2. If Section is INACTIVE -> all its Subject Assignments must be INACTIVE.
-- 3. Cannot activate Section if parent Class is INACTIVE (Returns 400 with actionable error).
-- 4. Cannot activate Subject Assignment if parent Class OR Section is INACTIVE (Returns 400 with actionable error).
-- 5. If Parent is ACTIVE, Child CAN be INACTIVE (Downward independence).
-- ============================================================================

-- Step 1: Clean up and synchronize all existing out-of-sync data
UPDATE public.academic_sections s
SET status = 'INACTIVE', updated_at = NOW()
FROM public.academic_classes c
WHERE s.class_id = c.id
  AND c.status != 'ACTIVE'
  AND s.status = 'ACTIVE'
  AND s.deleted_at IS NULL;

UPDATE public.class_subject_assignments csa
SET status = 'INACTIVE'
FROM public.academic_classes c
WHERE csa.class_id = c.id
  AND c.status != 'ACTIVE'
  AND csa.status = 'ACTIVE';

UPDATE public.class_subject_assignments csa
SET status = 'INACTIVE'
FROM public.academic_sections s
WHERE csa.section_id = s.id
  AND s.status != 'ACTIVE'
  AND csa.status = 'ACTIVE';


-- Step 2: Function - Toggle Class Subject Offering Status with Upward Hierarchy Validation
CREATE OR REPLACE FUNCTION public.fn_toggle_class_subject_status(
    p_school_id UUID,
    p_user_id UUID,
    p_class_id UUID,
    p_section_id UUID,
    p_subject_id UUID,
    p_status VARCHAR,
    p_academic_year VARCHAR DEFAULT '2026-27'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_new_status VARCHAR := UPPER(TRIM(p_status));
    v_class RECORD;
    v_sec RECORD;
BEGIN
    IF v_new_status NOT IN ('ACTIVE', 'INACTIVE', 'ARCHIVED') THEN
        v_new_status := 'ACTIVE';
    END IF;

    -- Validate Grandparent Class
    SELECT * INTO v_class
    FROM public.academic_classes
    WHERE id = p_class_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF v_class.id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Class not found', 'code', 404);
    END IF;

    -- Validate Parent Section if section_id is specified
    IF p_section_id IS NOT NULL THEN
        SELECT * INTO v_sec
        FROM public.academic_sections
        WHERE id = p_section_id AND school_id = p_school_id AND deleted_at IS NULL;

        IF v_sec.id IS NULL THEN
            RETURN jsonb_build_object('success', FALSE, 'error', 'Section not found', 'code', 404);
        END IF;
    END IF;

    -- Upward Hierarchy Guard: If trying to ACTIVATE, ensure Parent and Grandparent are ACTIVE
    IF v_new_status = 'ACTIVE' THEN
        IF v_class.status != 'ACTIVE' THEN
            RETURN jsonb_build_object(
                'success', FALSE,
                'error', 'Cannot activate Subject offering. The Class "' || v_class.name || '" is currently Inactive. Please activate the Class first.',
                'code', 400
            );
        END IF;

        IF p_section_id IS NOT NULL AND v_sec.status != 'ACTIVE' THEN
            RETURN jsonb_build_object(
                'success', FALSE,
                'error', 'Cannot activate Subject offering. The Section "' || v_sec.name || '" is currently Inactive. Please activate the Section first.',
                'code', 400
            );
        END IF;
    END IF;

    UPDATE public.class_subject_assignments
    SET status = v_new_status
    WHERE school_id = p_school_id
      AND class_id = p_class_id
      AND (
          (p_section_id IS NULL AND section_id IS NULL)
          OR section_id = p_section_id
      )
      AND subject_id = p_subject_id
      AND academic_year = p_academic_year;

    IF NOT FOUND THEN
        -- If not found, create assignment record with given status
        INSERT INTO public.class_subject_assignments (
            school_id, class_id, section_id, subject_id, academic_year, status
        ) VALUES (
            p_school_id, p_class_id, p_section_id, p_subject_id, p_academic_year, v_new_status
        );
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Subject offering status updated to ' || v_new_status,
        'status', v_new_status
    );
END;
$$;


-- Step 3: Function - Update Section with Hierarchy Validation & Downward Cascading
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
    v_class RECORD;
    v_name VARCHAR(50);
    v_code VARCHAR(50);
    v_capacity INT;
    v_room_number VARCHAR(50);
    v_room_id UUID;
    v_status VARCHAR(20);
    v_display_order INT;
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
    v_room_number := COALESCE(p_payload->>'room_number', v_curr.room_number);
    v_room_id := CASE 
        WHEN p_payload ? 'room_id' THEN (p_payload->>'room_id')::UUID 
        ELSE v_curr.room_id 
    END;
    v_status := UPPER(TRIM(COALESCE(p_payload->>'status', v_curr.status)));
    v_display_order := COALESCE((p_payload->>'display_order')::INT, v_curr.display_order);

    -- Upward Hierarchy Guard: If setting Section to ACTIVE, check parent Class
    IF v_status = 'ACTIVE' THEN
        SELECT * INTO v_class
        FROM public.academic_classes
        WHERE id = v_curr.class_id AND school_id = p_school_id AND deleted_at IS NULL;

        IF v_class.id IS NOT NULL AND v_class.status != 'ACTIVE' THEN
            RETURN jsonb_build_object(
                'success', FALSE,
                'error', 'Cannot activate Section "' || v_name || '". The parent Class "' || v_class.name || '" is currently Inactive. Please activate the Class first.',
                'code', 400
            );
        END IF;
    END IF;

    IF v_code != v_curr.code AND EXISTS (
        SELECT 1 FROM public.academic_sections 
        WHERE school_id = p_school_id 
          AND class_id = v_curr.class_id 
          AND academic_year = v_curr.academic_year 
          AND UPPER(code) = v_code 
          AND id != p_section_id
          AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Section with code "' || v_code || '" already exists in this class', 'code', 409);
    END IF;

    IF v_room_id IS NOT NULL THEN
        SELECT name INTO v_room_number FROM public.academic_rooms WHERE id = v_room_id;
    END IF;

    UPDATE public.academic_sections SET
        name = v_name,
        code = v_code,
        capacity = v_capacity,
        room_number = v_room_number,
        room_id = v_room_id,
        status = v_status,
        display_order = v_display_order,
        updated_by = p_user_id,
        updated_at = NOW()
    WHERE id = p_section_id;

    -- Downward Cascade: If Section became INACTIVE, deactivate all its Subject Assignments
    IF v_status = 'INACTIVE' THEN
        UPDATE public.class_subject_assignments
        SET status = 'INACTIVE'
        WHERE section_id = p_section_id;
    END IF;

    PERFORM public.fn_record_class_audit(
        p_school_id, p_user_id, 'Update', 'Updated Academic Section', v_name, 'SECTION', p_section_id,
        jsonb_build_object('name', v_name, 'code', v_code, 'status', v_status, 'room_number', v_room_number, 'room_id', v_room_id)
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
            'room_id', v_room_id,
            'status', v_status
        )
    );
END;
$$;


-- Step 4: Function - Update Class with Downward Cascade to Sections and Subject Assignments
CREATE OR REPLACE FUNCTION public.fn_update_academic_class(
    p_school_id UUID,
    p_user_id UUID,
    p_class_id UUID,
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_curr RECORD;
    v_name VARCHAR(100);
    v_code VARCHAR(50);
    v_stage VARCHAR(50);
    v_academic_year VARCHAR(50);
    v_display_order INT;
    v_status VARCHAR(20);
BEGIN
    SELECT * INTO v_curr
    FROM public.academic_classes
    WHERE id = p_class_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Class not found', 'code', 404);
    END IF;

    v_name := TRIM(COALESCE(p_payload->>'name', v_curr.name));
    v_code := UPPER(TRIM(COALESCE(p_payload->>'code', v_curr.code)));
    v_stage := TRIM(COALESCE(p_payload->>'stage', v_curr.stage));
    v_academic_year := TRIM(COALESCE(p_payload->>'academic_year', v_curr.academic_year));
    v_display_order := COALESCE((p_payload->>'display_order')::INT, v_curr.display_order);
    v_status := UPPER(TRIM(COALESCE(p_payload->>'status', v_curr.status)));

    -- Duplicate Check if code modified
    IF v_code != v_curr.code AND EXISTS (
        SELECT 1 FROM public.academic_classes
        WHERE school_id = p_school_id
          AND academic_year = v_academic_year
          AND UPPER(code) = v_code
          AND id != p_class_id
          AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Class with code "' || v_code || '" already exists', 'code', 409);
    END IF;

    UPDATE public.academic_classes SET
        name = v_name,
        code = v_code,
        stage = v_stage,
        academic_year = v_academic_year,
        display_order = v_display_order,
        status = v_status,
        updated_by = p_user_id,
        updated_at = NOW()
    WHERE id = p_class_id;

    -- Downward Hierarchy Cascade: When Class is marked INACTIVE, cascade to Sections & Subject Assignments
    IF v_status = 'INACTIVE' THEN
        -- Cascade to Sections
        UPDATE public.academic_sections SET
            status = 'INACTIVE',
            updated_at = NOW()
        WHERE class_id = p_class_id AND deleted_at IS NULL;

        -- Cascade to Class + Section Subject Assignments
        UPDATE public.class_subject_assignments SET
            status = 'INACTIVE'
        WHERE class_id = p_class_id;
    END IF;

    -- Audit Log
    PERFORM public.fn_record_class_audit(
        p_school_id, p_user_id, 'Update', 'Updated Academic Class', v_name, 'CLASS', p_class_id,
        jsonb_build_object('name', v_name, 'code', v_code, 'status', v_status),
        to_jsonb(v_curr),
        jsonb_build_object('name', v_name, 'code', v_code, 'status', v_status)
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Class updated successfully',
        'data', jsonb_build_object(
            'id', p_class_id,
            'name', v_name,
            'code', v_code,
            'stage', v_stage,
            'academic_year', v_academic_year,
            'status', v_status
        )
    );
END;
$$;


-- Step 5: Function - Get Subject Section Mappings with Strict Hierarchical Status
CREATE OR REPLACE FUNCTION public.fn_get_subject_section_mappings(
    p_school_id UUID,
    p_subject_id UUID DEFAULT NULL,
    p_academic_year VARCHAR DEFAULT '2026-27'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_mappings JSONB := '[]'::JSONB;
BEGIN
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'mapping_id', csa.id,
                'class_id', c.id,
                'class_name', c.name,
                'class_code', c.code,
                'class_status', c.status,
                'section_id', sec.id,
                'section_name', sec.name,
                'section_code', sec.code,
                'section_status', sec.status,
                'is_class_wide', FALSE,
                'total_capacity', COALESCE(sec.capacity, 40),
                'total_section_students', COALESCE(
                    (SELECT COUNT(*) FROM public.student_class_assignments sca 
                     WHERE sca.section_id = sec.id
                       AND sca.school_id = p_school_id
                       AND sca.academic_year = p_academic_year
                       AND sca.status = 'ACTIVE'),
                    0
                ),
                'enrolled_students_count', (
                    SELECT COUNT(*) 
                    FROM public.student_subject_enrollments sse
                    WHERE sse.subject_id = s.id 
                      AND sse.section_id = sec.id
                      AND sse.school_id = p_school_id 
                      AND sse.academic_year = p_academic_year
                      AND sse.status = 'ACTIVE'
                ),
                'is_offered_as_optional', COALESCE(s.is_optional, (s.type ILIKE 'Elective' OR s.type ILIKE 'Optional')),
                'status', (
                    CASE 
                        WHEN c.status != 'ACTIVE' THEN 'INACTIVE'
                        WHEN sec.status != 'ACTIVE' THEN 'INACTIVE'
                        ELSE COALESCE(csa.status, 'ACTIVE')
                    END
                ),
                'assigned_teachers', (
                    SELECT COALESCE(
                        jsonb_agg(
                            jsonb_build_object(
                                'id', p.id,
                                'full_name', p.full_name,
                                'email', p.email,
                                'avatar_url', p.avatar_url,
                                'department', p.department
                            )
                        ),
                        '[]'::JSONB
                    )
                    FROM public.section_subject_teachers sst
                    JOIN public.profiles p ON p.id = sst.teacher_id
                    WHERE sst.section_id = sec.id
                      AND sst.subject_id = s.id 
                      AND sst.school_id = p_school_id
                      AND sst.academic_year = p_academic_year
                      AND sst.status = 'ACTIVE'
                )
            )
            ORDER BY c.display_order ASC, sec.name ASC
        ),
        '[]'::JSONB
    ) INTO v_mappings
    FROM public.class_subject_assignments csa
    JOIN public.academic_classes c ON c.id = csa.class_id
    JOIN public.academic_subjects s ON s.id = csa.subject_id
    JOIN public.academic_sections sec ON sec.id = csa.section_id
    WHERE csa.school_id = p_school_id
      AND csa.academic_year = p_academic_year
      AND c.deleted_at IS NULL
      AND s.deleted_at IS NULL
      AND sec.deleted_at IS NULL
      AND (p_subject_id IS NULL OR csa.subject_id = p_subject_id);

    RETURN jsonb_build_object('success', TRUE, 'data', v_mappings);
END;
$$;


-- Step 6: Function - Get Academic Class Detail with Hierarchy-Synced Statuses
CREATE OR REPLACE FUNCTION public.fn_get_academic_class_detail(
    p_school_id UUID,
    p_class_id UUID,
    p_requesting_user_id UUID,
    p_requesting_role TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_class RECORD;
    v_sections JSONB := '[]'::JSONB;
    v_subjects JSONB := '[]'::JSONB;
    v_teachers JSONB := '[]'::JSONB;
    v_primary_teacher JSONB := NULL;
    v_students_count INT := 0;
    v_total_sections INT := 0;
    v_total_capacity INT := 0;
    v_core_subs INT := 0;
    v_opt_subs INT := 0;
    v_total_subs INT := 0;
    v_is_teacher_assigned BOOLEAN := FALSE;
BEGIN
    SELECT * INTO v_class
    FROM public.academic_classes
    WHERE id = p_class_id AND school_id = p_school_id;

    IF v_class.id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Academic class not found', 'code', 404);
    END IF;

    -- Security check for Teacher role
    IF p_requesting_role = 'Teacher' THEN
        SELECT EXISTS(
            SELECT 1 FROM public.class_teacher_assignments
            WHERE class_id = p_class_id AND teacher_id = p_requesting_user_id
            UNION
            SELECT 1 FROM public.section_subject_teachers
            WHERE class_id = p_class_id AND teacher_id = p_requesting_user_id AND status = 'ACTIVE'
        ) INTO v_is_teacher_assigned;

        IF NOT v_is_teacher_assigned THEN
            RETURN jsonb_build_object('success', FALSE, 'error', 'Unauthorized: You are not assigned to this class', 'code', 403);
        END IF;
    END IF;

    -- Fetch Sections with Hierarchical Status
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', s.id,
                'name', s.name,
                'code', s.code,
                'class_id', p_class_id,
                'class_name', v_class.name,
                'class_code', v_class.code,
                'capacity', s.capacity,
                'room_number', s.room_number,
                'status', (
                    CASE 
                        WHEN v_class.status != 'ACTIVE' THEN 'INACTIVE'
                        ELSE s.status
                    END
                ),
                'students_count', (
                    SELECT COUNT(DISTINCT sca.student_id) 
                    FROM public.student_class_assignments sca 
                    WHERE sca.section_id = s.id AND sca.status = 'ACTIVE'
                ),
                'class_teacher', (
                    SELECT jsonb_build_object(
                        'id', p.id,
                        'full_name', p.full_name,
                        'email', p.email,
                        'avatar_url', p.avatar_url,
                        'employee_id', p.employee_id,
                        'department', p.department
                    )
                    FROM public.class_teacher_assignments cta
                    JOIN public.profiles p ON p.id = cta.teacher_id
                    WHERE cta.section_id = s.id
                    ORDER BY cta.is_primary DESC, cta.created_at DESC
                    LIMIT 1
                ),
                'subjects_count', (
                    SELECT COUNT(DISTINCT csa.subject_id)
                    FROM public.class_subject_assignments csa
                    WHERE (csa.section_id = s.id OR (csa.class_id = p_class_id AND csa.section_id IS NULL))
                      AND csa.school_id = p_school_id
                )
            ) ORDER BY s.name ASC
        ),
        '[]'::JSONB
    ) INTO v_sections
    FROM public.academic_sections s
    WHERE s.class_id = p_class_id AND (v_class.status = 'ARCHIVED' OR s.deleted_at IS NULL);

    -- Fetch Subjects with Hierarchical Status
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', s_agg.id,
                'name', s_agg.name,
                'code', s_agg.code,
                'type', s_agg.type,
                'description', s_agg.description,
                'status', (
                    CASE 
                        WHEN v_class.status != 'ACTIVE' THEN 'INACTIVE'
                        ELSE s_agg.assignment_status
                    END
                ),
                'color', s_agg.color,
                'icon', s_agg.icon,
                'is_optional', (s_agg.type ILIKE '%opt%' OR s_agg.type ILIKE '%elec%' OR s_agg.is_optional = TRUE),
                'section_names', s_agg.section_names,
                'assigned_sections_count', (
                    SELECT COUNT(DISTINCT sst.section_id)
                    FROM public.section_subject_teachers sst
                    WHERE sst.class_id = p_class_id 
                      AND sst.subject_id = s_agg.id
                      AND sst.status = 'ACTIVE'
                ),
                'assigned_teachers', (
                    SELECT COALESCE(
                        jsonb_agg(
                            jsonb_build_object(
                                'id', p.id,
                                'full_name', p.full_name,
                                'email', p.email,
                                'avatar_url', p.avatar_url,
                                'employee_id', p.employee_id,
                                'department', p.department,
                                'section_id', sst.section_id,
                                'section_name', sec.name
                            ) ORDER BY sec.name ASC, p.full_name ASC
                        ),
                        '[]'::JSONB
                    )
                    FROM public.section_subject_teachers sst
                    JOIN public.profiles p ON p.id = sst.teacher_id
                    LEFT JOIN public.academic_sections sec ON sec.id = sst.section_id
                    WHERE sst.class_id = p_class_id 
                      AND sst.subject_id = s_agg.id
                      AND sst.status = 'ACTIVE'
                )
            ) ORDER BY s_agg.name ASC
        ),
        '[]'::JSONB
    ) INTO v_subjects
    FROM (
        SELECT 
            sub.id,
            sub.name,
            sub.code,
            sub.type,
            sub.description,
            sub.color,
            sub.icon,
            sub.is_optional,
            CASE 
                WHEN bool_or(csa.status = 'ACTIVE') THEN 'ACTIVE'
                ELSE 'INACTIVE'
            END AS assignment_status,
            COALESCE(
                array_to_string(
                    array_agg(DISTINCT sec.name) FILTER (WHERE sec.name IS NOT NULL),
                    ', '
                ),
                'All Sections'
            ) AS section_names
        FROM public.class_subject_assignments csa
        JOIN public.academic_subjects sub ON sub.id = csa.subject_id
        LEFT JOIN public.academic_sections sec ON sec.id = csa.section_id
        WHERE csa.class_id = p_class_id 
          AND csa.school_id = p_school_id
          AND (v_class.status = 'ARCHIVED' OR sub.deleted_at IS NULL)
        GROUP BY sub.id, sub.name, sub.code, sub.type, sub.description, sub.color, sub.icon, sub.is_optional
    ) s_agg;

    -- Fetch Teachers assigned to class or section
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', p.id,
                'full_name', p.full_name,
                'email', p.email,
                'avatar_url', p.avatar_url,
                'employee_id', p.employee_id,
                'department', p.department,
                'is_primary', cta.is_primary,
                'section_id', cta.section_id
            ) ORDER BY cta.is_primary DESC, cta.created_at ASC
        ),
        '[]'::JSONB
    ) INTO v_teachers
    FROM public.class_teacher_assignments cta
    JOIN public.profiles p ON p.id = cta.teacher_id
    WHERE cta.class_id = p_class_id;

    -- Primary class teacher
    SELECT jsonb_build_object(
        'id', p.id,
        'full_name', p.full_name,
        'email', p.email,
        'avatar_url', p.avatar_url,
        'employee_id', p.employee_id,
        'department', p.department,
        'is_primary', cta.is_primary
    ) INTO v_primary_teacher
    FROM public.class_teacher_assignments cta
    JOIN public.profiles p ON p.id = cta.teacher_id
    WHERE cta.class_id = p_class_id
    ORDER BY 
        (cta.section_id IS NOT NULL) DESC,
        cta.is_primary DESC, 
        cta.created_at DESC
    LIMIT 1;

    -- Aggregated Counts
    SELECT COUNT(DISTINCT student_id) INTO v_students_count
    FROM public.student_class_assignments
    WHERE class_id = p_class_id AND status = 'ACTIVE';

    SELECT COUNT(*), COALESCE(SUM(capacity), 0)
    INTO v_total_sections, v_total_capacity
    FROM public.academic_sections
    WHERE class_id = p_class_id AND (v_class.status = 'ARCHIVED' OR deleted_at IS NULL);

    SELECT 
        COUNT(DISTINCT CASE WHEN (sub.type ILIKE '%core%' OR sub.type IS NULL) THEN sub.id END),
        COUNT(DISTINCT CASE WHEN (sub.type ILIKE '%opt%' OR sub.type ILIKE '%elec%' OR sub.is_optional = TRUE) THEN sub.id END),
        COUNT(DISTINCT sub.id)
    INTO v_core_subs, v_opt_subs, v_total_subs
    FROM public.class_subject_assignments csa
    JOIN public.academic_subjects sub ON sub.id = csa.subject_id
    WHERE csa.class_id = p_class_id 
      AND csa.school_id = p_school_id
      AND (v_class.status = 'ARCHIVED' OR sub.deleted_at IS NULL);

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'id', v_class.id,
            'name', v_class.name,
            'code', v_class.code,
            'stage', v_class.stage,
            'academic_year', v_class.academic_year,
            'display_order', v_class.display_order,
            'status', v_class.status,
            'total_sections', v_total_sections,
            'total_students', v_students_count,
            'total_capacity', v_total_capacity,
            'core_subjects_count', v_core_subs,
            'optional_subjects_count', v_opt_subs,
            'total_subjects_count', v_total_subs,
            'class_teacher', v_primary_teacher,
            'sections', v_sections,
            'subjects', v_subjects,
            'teachers', v_teachers
        )
    );
END;
$$;


-- Step 7: Function - Get Paginated Sections Across Classes (Strict Hierarchy Status)
CREATE OR REPLACE FUNCTION public.fn_get_academic_sections(
    p_school_id UUID,
    p_search TEXT DEFAULT '',
    p_class_id UUID DEFAULT NULL,
    p_academic_year VARCHAR DEFAULT '2026-27',
    p_status VARCHAR DEFAULT 'ALL',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_sort_by VARCHAR DEFAULT 'class_name',
    p_sort_order VARCHAR DEFAULT 'ASC',
    p_building VARCHAR DEFAULT 'ALL',
    p_floor VARCHAR DEFAULT 'ALL'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_count INT := 0;
    v_total_pages INT := 1;
    v_offset INT := 0;
    v_sections JSONB := '[]'::JSONB;
    v_clean_search TEXT := TRIM(COALESCE(p_search, ''));
    v_clean_status VARCHAR := UPPER(TRIM(COALESCE(p_status, 'ALL')));
    v_clean_building VARCHAR := UPPER(TRIM(COALESCE(p_building, 'ALL')));
    v_clean_floor VARCHAR := UPPER(TRIM(COALESCE(p_floor, 'ALL')));
    v_clean_sort_by VARCHAR := LOWER(TRIM(COALESCE(p_sort_by, 'class_name')));
    v_clean_sort_order VARCHAR := UPPER(TRIM(COALESCE(p_sort_order, 'ASC')));
BEGIN
    v_offset := (p_page - 1) * p_page_size;

    -- Count total matching sections
    SELECT COUNT(*) INTO v_total_count
    FROM public.academic_sections s
    JOIN public.academic_classes c ON c.id = s.class_id
    LEFT JOIN public.academic_rooms r ON r.id = s.room_id
    WHERE s.school_id = p_school_id
      AND s.academic_year = p_academic_year
      AND s.deleted_at IS NULL
      AND c.deleted_at IS NULL
      AND (p_class_id IS NULL OR s.class_id = p_class_id)
      AND (
          v_clean_status = 'ALL' 
          OR (v_clean_status = 'ACTIVE' AND c.status = 'ACTIVE' AND s.status = 'ACTIVE')
          OR (v_clean_status = 'INACTIVE' AND (c.status != 'ACTIVE' OR s.status != 'ACTIVE'))
          OR (v_clean_status = 'ARCHIVED' AND (c.status = 'ARCHIVED' OR s.status = 'ARCHIVED'))
      )
      AND (v_clean_building = 'ALL' OR (r.building IS NOT NULL AND UPPER(r.building) = v_clean_building))
      AND (v_clean_floor = 'ALL' OR (r.floor IS NOT NULL AND UPPER(r.floor) = v_clean_floor))
      AND (
          v_clean_search = '' 
          OR s.name ILIKE '%' || v_clean_search || '%'
          OR s.code ILIKE '%' || v_clean_search || '%'
          OR c.name ILIKE '%' || v_clean_search || '%'
          OR c.code ILIKE '%' || v_clean_search || '%'
          OR (r.name IS NOT NULL AND r.name ILIKE '%' || v_clean_search || '%')
      );

    v_total_pages := GREATEST(1, CEIL(v_total_count::FLOAT / p_page_size::FLOAT)::INT);

    -- Fetch Paginated Sections with Effective Hierarchical Status
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', s.id,
                'name', s.name,
                'code', s.code,
                'class_id', c.id,
                'class_name', c.name,
                'class_code', c.code,
                'class_stage', c.stage,
                'class_status', c.status,
                'capacity', s.capacity,
                'room_number', COALESCE(r.name, s.room_number),
                'room_id', s.room_id,
                'room_type', r.type,
                'building', r.building,
                'floor', r.floor,
                'status', (
                    CASE 
                        WHEN c.status != 'ACTIVE' THEN 'INACTIVE'
                        ELSE s.status
                    END
                ),
                'academic_year', s.academic_year,
                'display_order', s.display_order,
                'students_count', (
                    SELECT COUNT(DISTINCT sca.student_id) 
                    FROM public.student_class_assignments sca 
                    WHERE sca.section_id = s.id 
                      AND sca.school_id = p_school_id
                      AND sca.status = 'ACTIVE'
                ),
                'subjects_count', (
                    SELECT COUNT(DISTINCT csa.subject_id)
                    FROM public.class_subject_assignments csa
                    WHERE (csa.section_id = s.id OR (csa.class_id = c.id AND csa.section_id IS NULL))
                      AND csa.school_id = p_school_id
                ),
                'class_teacher', (
                    SELECT jsonb_build_object(
                        'id', p.id,
                        'full_name', p.full_name,
                        'email', p.email,
                        'avatar_url', p.avatar_url,
                        'employee_id', p.employee_id,
                        'department', p.department
                    )
                    FROM public.class_teacher_assignments cta
                    JOIN public.profiles p ON p.id = cta.teacher_id
                    WHERE cta.section_id = s.id
                    ORDER BY cta.is_primary DESC, cta.created_at DESC
                    LIMIT 1
                )
            ) ORDER BY
                CASE WHEN v_clean_sort_by = 'name' AND v_clean_sort_order = 'ASC' THEN s.name END ASC,
                CASE WHEN v_clean_sort_by = 'name' AND v_clean_sort_order = 'DESC' THEN s.name END DESC,
                CASE WHEN v_clean_sort_by = 'code' AND v_clean_sort_order = 'ASC' THEN s.code END ASC,
                CASE WHEN v_clean_sort_by = 'code' AND v_clean_sort_order = 'DESC' THEN s.code END DESC,
                CASE WHEN v_clean_sort_by = 'class_name' AND v_clean_sort_order = 'ASC' THEN c.name END ASC,
                CASE WHEN v_clean_sort_by = 'class_name' AND v_clean_sort_order = 'DESC' THEN c.name END DESC,
                c.display_order ASC, s.display_order ASC, s.name ASC
        ),
        '[]'::JSONB
    ) INTO v_sections
    FROM (
        SELECT s.*, c.display_order AS class_display_order
        FROM public.academic_sections s
        JOIN public.academic_classes c ON c.id = s.class_id
        LEFT JOIN public.academic_rooms r ON r.id = s.room_id
        WHERE s.school_id = p_school_id
          AND s.academic_year = p_academic_year
          AND s.deleted_at IS NULL
          AND c.deleted_at IS NULL
          AND (p_class_id IS NULL OR s.class_id = p_class_id)
          AND (
              v_clean_status = 'ALL' 
              OR (v_clean_status = 'ACTIVE' AND c.status = 'ACTIVE' AND s.status = 'ACTIVE')
              OR (v_clean_status = 'INACTIVE' AND (c.status != 'ACTIVE' OR s.status != 'ACTIVE'))
              OR (v_clean_status = 'ARCHIVED' AND (c.status = 'ARCHIVED' OR s.status = 'ARCHIVED'))
          )
          AND (v_clean_building = 'ALL' OR (r.building IS NOT NULL AND UPPER(r.building) = v_clean_building))
          AND (v_clean_floor = 'ALL' OR (r.floor IS NOT NULL AND UPPER(r.floor) = v_clean_floor))
          AND (
              v_clean_search = '' 
              OR s.name ILIKE '%' || v_clean_search || '%'
              OR s.code ILIKE '%' || v_clean_search || '%'
              OR c.name ILIKE '%' || v_clean_search || '%'
              OR c.code ILIKE '%' || v_clean_search || '%'
              OR (r.name IS NOT NULL AND r.name ILIKE '%' || v_clean_search || '%')
          )
        ORDER BY c.display_order ASC, s.display_order ASC, s.name ASC
        LIMIT p_page_size OFFSET v_offset
    ) sub_sec
    JOIN public.academic_sections s ON s.id = sub_sec.id
    JOIN public.academic_classes c ON c.id = s.class_id
    LEFT JOIN public.academic_rooms r ON r.id = s.room_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'sections', v_sections,
            'total_count', v_total_count,
            'page', p_page,
            'page_size', p_page_size,
            'total_pages', v_total_pages
        )
    );
END;
$$;
