-- ============================================================================
-- Migration 277: Enhance Subject Management, Optional/Mandatory Logic & Dynamic Section Assignments
-- ============================================================================

-- 1. Ensure is_optional column exists on public.academic_subjects
ALTER TABLE public.academic_subjects 
ADD COLUMN IF NOT EXISTS is_optional BOOLEAN NOT NULL DEFAULT FALSE;

-- Update existing elective/optional subjects
UPDATE public.academic_subjects
SET is_optional = TRUE
WHERE type ILIKE 'Elective' OR type ILIKE 'Optional' OR name ILIKE '%Elective%' OR name ILIKE '%Optional%';


-- 2. Stored Procedure: Create Academic Subject (Supporting is_optional & status)
CREATE OR REPLACE FUNCTION public.fn_create_academic_subject(
    p_school_id UUID,
    p_user_id UUID,
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_id UUID;
    v_name VARCHAR(150);
    v_code VARCHAR(50);
    v_type VARCHAR(50);
    v_description TEXT;
    v_periods_per_week INT;
    v_color VARCHAR(50);
    v_icon VARCHAR(100);
    v_status VARCHAR(20);
    v_is_optional BOOLEAN;
    v_class_ids JSONB;
    v_cls_id UUID;
BEGIN
    v_name := TRIM(COALESCE((p_payload->>'name')::VARCHAR, ''));
    v_code := UPPER(TRIM(COALESCE((p_payload->>'code')::VARCHAR, '')));
    v_type := COALESCE((p_payload->>'type')::VARCHAR, 'Core');
    v_description := (p_payload->>'description')::TEXT;
    v_periods_per_week := COALESCE((p_payload->>'periods_per_week')::INT, 5);
    v_color := COALESCE((p_payload->>'color')::VARCHAR, '#4F46E5');
    v_icon := COALESCE((p_payload->>'icon')::VARCHAR, 'book');
    v_status := UPPER(TRIM(COALESCE((p_payload->>'status')::VARCHAR, 'ACTIVE')));
    v_is_optional := COALESCE((p_payload->>'is_optional')::BOOLEAN, (v_type ILIKE 'Elective' OR v_type ILIKE 'Optional'));
    v_class_ids := p_payload->'class_ids';

    IF v_name = '' THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Subject name is required', 'code', 400);
    END IF;

    IF v_code = '' THEN
        v_code := UPPER(SUBSTRING(REGEXP_REPLACE(v_name, '[^a-zA-Z0-9]', '', 'g') FROM 1 FOR 6));
    END IF;

    -- Check unique code in school
    IF EXISTS (
        SELECT 1 FROM public.academic_subjects 
        WHERE school_id = p_school_id AND UPPER(code) = v_code AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Subject code already exists in your school catalog', 'code', 409);
    END IF;

    INSERT INTO public.academic_subjects (
        school_id, name, code, type, description, periods_per_week, color, icon, status, is_optional, created_by, updated_by
    ) VALUES (
        p_school_id, v_name, v_code, v_type, v_description, v_periods_per_week, v_color, v_icon, v_status, v_is_optional, p_user_id, p_user_id
    ) RETURNING id INTO v_id;

    -- Assign to classes if provided
    IF v_class_ids IS NOT NULL AND jsonb_array_length(v_class_ids) > 0 THEN
        FOR v_cls_id IN SELECT (jsonb_array_elements_text(v_class_ids))::UUID LOOP
            INSERT INTO public.class_subject_assignments (
                school_id, class_id, subject_id, academic_year
            ) VALUES (
                p_school_id, v_cls_id, v_id, '2026-27'
            ) ON CONFLICT DO NOTHING;
        END LOOP;
    END IF;

    PERFORM public.fn_record_class_audit(
        p_school_id, p_user_id, 'Create', 'Created Subject in Catalog', v_id::TEXT, 'SUBJECT', v_id,
        jsonb_build_object('name', v_name, 'code', v_code, 'type', v_type, 'is_optional', v_is_optional, 'status', v_status)
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Subject created successfully',
        'data', jsonb_build_object('id', v_id, 'name', v_name, 'code', v_code, 'type', v_type, 'is_optional', v_is_optional, 'status', v_status)
    );
END;
$$;


-- 3. Stored Procedure: Update Academic Subject (Supporting is_optional & status)
CREATE OR REPLACE FUNCTION public.fn_update_academic_subject(
    p_school_id UUID,
    p_user_id UUID,
    p_subject_id UUID,
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_existing public.academic_subjects%ROWTYPE;
    v_name VARCHAR(150);
    v_code VARCHAR(50);
    v_type VARCHAR(50);
    v_description TEXT;
    v_periods_per_week INT;
    v_color VARCHAR(50);
    v_icon VARCHAR(100);
    v_status VARCHAR(20);
    v_is_optional BOOLEAN;
    v_class_ids JSONB;
    v_cls_id UUID;
BEGIN
    SELECT * INTO v_existing FROM public.academic_subjects 
    WHERE id = p_subject_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Subject not found', 'code', 404);
    END IF;

    v_name := COALESCE(NULLIF(TRIM((p_payload->>'name')::VARCHAR), ''), v_existing.name);
    v_code := UPPER(COALESCE(NULLIF(TRIM((p_payload->>'code')::VARCHAR), ''), v_existing.code));
    v_type := COALESCE((p_payload->>'type')::VARCHAR, v_existing.type);
    v_description := COALESCE((p_payload->>'description')::TEXT, v_existing.description);
    v_periods_per_week := COALESCE((p_payload->>'periods_per_week')::INT, v_existing.periods_per_week);
    v_color := COALESCE((p_payload->>'color')::VARCHAR, v_existing.color);
    v_icon := COALESCE((p_payload->>'icon')::VARCHAR, v_existing.icon);
    v_status := UPPER(COALESCE((p_payload->>'status')::VARCHAR, v_existing.status));
    
    IF p_payload ? 'is_optional' THEN
        v_is_optional := (p_payload->>'is_optional')::BOOLEAN;
    ELSE
        v_is_optional := COALESCE(v_existing.is_optional, (v_type ILIKE 'Elective' OR v_type ILIKE 'Optional'));
    END IF;

    -- Check unique code
    IF v_code != v_existing.code AND EXISTS (
        SELECT 1 FROM public.academic_subjects 
        WHERE school_id = p_school_id AND UPPER(code) = v_code AND id != p_subject_id AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Subject code already exists in your school', 'code', 409);
    END IF;

    UPDATE public.academic_subjects SET
        name = v_name,
        code = v_code,
        type = v_type,
        description = v_description,
        periods_per_week = v_periods_per_week,
        color = v_color,
        icon = v_icon,
        status = v_status,
        is_optional = v_is_optional,
        updated_by = p_user_id,
        updated_at = NOW()
    WHERE id = p_subject_id;

    v_class_ids := p_payload->'class_ids';
    IF v_class_ids IS NOT NULL THEN
        DELETE FROM public.class_subject_assignments 
        WHERE school_id = p_school_id AND subject_id = p_subject_id AND section_id IS NULL;

        FOR v_cls_id IN SELECT (jsonb_array_elements_text(v_class_ids))::UUID LOOP
            INSERT INTO public.class_subject_assignments (
                school_id, class_id, subject_id, academic_year
            ) VALUES (
                p_school_id, v_cls_id, p_subject_id, '2026-27'
            ) ON CONFLICT DO NOTHING;
        END LOOP;
    END IF;

    PERFORM public.fn_record_class_audit(
        p_school_id, p_user_id, 'Update', 'Updated Subject in Catalog', p_subject_id::TEXT, 'SUBJECT', p_subject_id,
        jsonb_build_object('name', v_name, 'code', v_code, 'type', v_type, 'is_optional', v_is_optional, 'status', v_status)
    );

    RETURN jsonb_build_object('success', TRUE, 'message', 'Subject updated successfully');
END;
$$;


-- 4. Stored Procedure: Get Academic Subjects (Enriched with accurate counts & is_optional)
CREATE OR REPLACE FUNCTION public.fn_get_academic_subjects(
    p_school_id UUID,
    p_search TEXT DEFAULT '',
    p_type VARCHAR DEFAULT 'ALL',
    p_status VARCHAR DEFAULT 'ALL',
    p_class_id UUID DEFAULT NULL,
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
    v_subjects JSONB := '[]'::JSONB;
BEGIN
    SELECT COUNT(DISTINCT s.id)
    INTO v_total_count
    FROM public.academic_subjects s
    LEFT JOIN public.class_subject_assignments csa ON csa.subject_id = s.id
    WHERE s.school_id = p_school_id
      AND (
          (p_status = 'ALL' AND s.deleted_at IS NULL)
          OR (p_status = 'ARCHIVED' AND (UPPER(TRIM(s.status)) = 'ARCHIVED' OR s.deleted_at IS NOT NULL))
          OR (p_status != 'ALL' AND UPPER(TRIM(s.status)) = UPPER(TRIM(p_status)) AND s.deleted_at IS NULL)
      )
      AND (p_type = 'ALL' OR p_type = '' OR UPPER(TRIM(s.type)) = UPPER(TRIM(p_type)))
      AND (p_class_id IS NULL OR csa.class_id = p_class_id)
      AND (
          p_teacher_id IS NULL
          OR EXISTS (
              SELECT 1 FROM public.section_subject_teachers sst
              WHERE sst.subject_id = s.id AND sst.teacher_id = p_teacher_id AND sst.status = 'ACTIVE'
          )
      )
      AND (
          p_search = '' 
          OR s.name ILIKE '%' || p_search || '%' 
          OR s.code ILIKE '%' || p_search || '%'
          OR s.type ILIKE '%' || p_search || '%'
      );

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', s_item.id,
                'name', s_item.name,
                'code', s_item.code,
                'type', s_item.type,
                'description', s_item.description,
                'periods_per_week', s_item.periods_per_week,
                'color', s_item.color,
                'icon', s_item.icon,
                'status', s_item.status,
                'is_optional', COALESCE(s_item.is_optional, (s_item.type ILIKE 'Elective' OR s_item.type ILIKE 'Optional')),
                'classes_count', (
                    SELECT COUNT(DISTINCT csa.class_id) 
                    FROM public.class_subject_assignments csa 
                    WHERE csa.subject_id = s_item.id AND csa.school_id = p_school_id
                ),
                'assigned_sections_count', (
                    SELECT COUNT(DISTINCT csa.section_id) 
                    FROM public.class_subject_assignments csa 
                    WHERE csa.subject_id = s_item.id AND csa.school_id = p_school_id AND csa.section_id IS NOT NULL
                ),
                'teachers_count', (
                    SELECT COUNT(DISTINCT sst.teacher_id) 
                    FROM public.section_subject_teachers sst 
                    WHERE sst.subject_id = s_item.id AND sst.school_id = p_school_id AND sst.status = 'ACTIVE'
                ),
                'assigned_classes', (
                    SELECT COALESCE(
                        jsonb_agg(
                            DISTINCT jsonb_build_object(
                                'class_id', c.id,
                                'class_name', c.name,
                                'class_code', c.code
                            )
                        ),
                        '[]'::JSONB
                    )
                    FROM public.class_subject_assignments csa2
                    JOIN public.academic_classes c ON c.id = csa2.class_id
                    WHERE csa2.subject_id = s_item.id AND c.deleted_at IS NULL AND csa2.school_id = p_school_id
                ),
                'created_at', s_item.created_at,
                'updated_at', s_item.updated_at
            )
        ),
        '[]'::JSONB
    ) INTO v_subjects
    FROM (
        SELECT DISTINCT s.*
        FROM public.academic_subjects s
        LEFT JOIN public.class_subject_assignments csa ON csa.subject_id = s.id
        WHERE s.school_id = p_school_id
          AND (
              (p_status = 'ALL' AND s.deleted_at IS NULL)
              OR (p_status = 'ARCHIVED' AND (UPPER(TRIM(s.status)) = 'ARCHIVED' OR s.deleted_at IS NOT NULL))
              OR (p_status != 'ALL' AND UPPER(TRIM(s.status)) = UPPER(TRIM(p_status)) AND s.deleted_at IS NULL)
          )
          AND (p_type = 'ALL' OR p_type = '' OR UPPER(TRIM(s.type)) = UPPER(TRIM(p_type)))
          AND (p_class_id IS NULL OR csa.class_id = p_class_id)
          AND (
              p_teacher_id IS NULL
              OR EXISTS (
                  SELECT 1 FROM public.section_subject_teachers sst
                  WHERE sst.subject_id = s.id AND sst.teacher_id = p_teacher_id AND sst.status = 'ACTIVE'
              )
          )
          AND (
              p_search = '' 
              OR s.name ILIKE '%' || p_search || '%' 
              OR s.code ILIKE '%' || p_search || '%'
              OR s.type ILIKE '%' || p_search || '%'
          )
        ORDER BY 
            CASE WHEN p_sort_by = 'name' AND p_sort_order ILIKE 'ASC' THEN s.name END ASC,
            CASE WHEN p_sort_by = 'name' AND p_sort_order ILIKE 'DESC' THEN s.name END DESC,
            s.created_at DESC
        LIMIT p_page_size OFFSET v_offset
    ) s_item;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'subjects', v_subjects,
            'total_count', v_total_count,
            'page', p_page,
            'page_size', p_page_size,
            'total_pages', CEIL(v_total_count::NUMERIC / GREATEST(p_page_size, 1))
        )
    );
END;
$$;


-- 5. Stored Procedure: Get Subject Section Mappings (ONLY Showing Assigned Sections)
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
                'section_id', s.id,
                'section_name', s.name,
                'section_code', s.code,
                'subject_id', sub.id,
                'subject_name', sub.name,
                'subject_code', sub.code,
                'subject_type', sub.type,
                'is_offered', TRUE,
                'is_optional', COALESCE(sub.is_optional, (sub.type ILIKE 'Elective' OR sub.type ILIKE 'Optional')),
                'total_section_students', (
                    SELECT COUNT(*) 
                    FROM public.student_class_assignments sca 
                    WHERE sca.section_id = s.id AND sca.status = 'ACTIVE' AND sca.school_id = p_school_id
                ),
                'enrolled_students_count', (
                    SELECT COUNT(*) 
                    FROM public.student_subject_enrollments sse 
                    WHERE sse.section_id = s.id AND sse.subject_id = sub.id AND sse.status = 'ACTIVE' AND sse.school_id = p_school_id
                ),
                'assigned_teachers', (
                    SELECT COALESCE(
                        jsonb_agg(
                            jsonb_build_object(
                                'id', p.id,
                                'full_name', p.full_name,
                                'email', p.email,
                                'employee_id', p.employee_id,
                                'avatar_url', p.avatar_url,
                                'is_primary', sst.is_primary
                            )
                        ),
                        '[]'::JSONB
                    )
                    FROM public.section_subject_teachers sst
                    JOIN public.profiles p ON p.id = sst.teacher_id
                    WHERE sst.section_id = s.id AND sst.subject_id = sub.id AND sst.status = 'ACTIVE' AND sst.school_id = p_school_id
                ),
                'status', 'ACTIVE'
            ) ORDER BY c.display_order ASC, s.name ASC
        ),
        '[]'::JSONB
    ) INTO v_mappings
    FROM public.class_subject_assignments csa
    JOIN public.academic_classes c ON c.id = csa.class_id AND c.deleted_at IS NULL
    JOIN public.academic_sections s ON s.id = csa.section_id AND s.deleted_at IS NULL
    JOIN public.academic_subjects sub ON sub.id = csa.subject_id AND sub.deleted_at IS NULL
    WHERE csa.school_id = p_school_id
      AND csa.academic_year = p_academic_year
      AND (p_subject_id IS NULL OR csa.subject_id = p_subject_id);

    RETURN jsonb_build_object('success', TRUE, 'data', v_mappings);
END;
$$;


-- 6. Stored Procedure: Assign Subject to Class & Sections (Auto-enrolls students if Mandatory)
CREATE OR REPLACE FUNCTION public.fn_assign_subject_to_sections(
    p_school_id UUID,
    p_user_id UUID,
    p_class_id UUID,
    p_section_ids UUID[],
    p_subject_id UUID,
    p_teacher_id UUID DEFAULT NULL,
    p_academic_year VARCHAR DEFAULT '2026-27'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_subject public.academic_subjects%ROWTYPE;
    v_sec_id UUID;
    v_is_optional BOOLEAN;
    v_assigned_count INT := 0;
BEGIN
    SELECT * INTO v_subject 
    FROM public.academic_subjects 
    WHERE id = p_subject_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Subject not found', 'code', 404);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.academic_classes 
        WHERE id = p_class_id AND school_id = p_school_id AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Class not found', 'code', 404);
    END IF;

    v_is_optional := COALESCE(v_subject.is_optional, (v_subject.type ILIKE 'Elective' OR v_subject.type ILIKE 'Optional'));

    FOREACH v_sec_id IN ARRAY p_section_ids LOOP
        -- 1. Insert into class_subject_assignments
        INSERT INTO public.class_subject_assignments (
            school_id, class_id, section_id, subject_id, academic_year
        ) VALUES (
            p_school_id, p_class_id, v_sec_id, p_subject_id, p_academic_year
        ) ON CONFLICT DO NOTHING;

        -- 2. If Teacher provided, assign teacher
        IF p_teacher_id IS NOT NULL THEN
            INSERT INTO public.section_subject_teachers (
                school_id, academic_year, class_id, section_id, subject_id, teacher_id, is_primary, status
            ) VALUES (
                p_school_id, p_academic_year, p_class_id, v_sec_id, p_subject_id, p_teacher_id, TRUE, 'ACTIVE'
            )
            ON CONFLICT (school_id, academic_year, section_id, subject_id, teacher_id)
            DO UPDATE SET status = 'ACTIVE', updated_at = NOW();
        END IF;

        -- 3. If Mandatory, automatically enroll all active students of this section!
        IF NOT v_is_optional THEN
            INSERT INTO public.student_subject_enrollments (
                school_id, academic_year, class_id, section_id, subject_id, student_id, status
            )
            SELECT p_school_id, p_academic_year, p_class_id, v_sec_id, p_subject_id, sca.student_id, 'ACTIVE'
            FROM public.student_class_assignments sca
            WHERE sca.school_id = p_school_id
              AND sca.section_id = v_sec_id
              AND sca.academic_year = p_academic_year
              AND sca.status = 'ACTIVE'
            ON CONFLICT (school_id, academic_year, section_id, subject_id, student_id)
            DO UPDATE SET status = 'ACTIVE', updated_at = NOW();
        END IF;

        v_assigned_count := v_assigned_count + 1;
    END LOOP;

    PERFORM public.fn_record_class_audit(
        p_school_id, p_user_id, 'ASSIGN_SUBJECT_TO_SECTIONS', 'ASSIGN', 'Subject Section Assignment', 'class_subject_assignments', p_subject_id,
        jsonb_build_object('subject_id', p_subject_id, 'class_id', p_class_id, 'section_count', v_assigned_count, 'is_optional', v_is_optional)
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Subject assigned to section(s) successfully',
        'assigned_count', v_assigned_count,
        'is_optional', v_is_optional
    );
END;
$$;


-- 7. Stored Procedure: Unassign Subject from Section
CREATE OR REPLACE FUNCTION public.fn_unassign_subject_from_section(
    p_school_id UUID,
    p_user_id UUID,
    p_class_id UUID,
    p_section_id UUID,
    p_subject_id UUID,
    p_academic_year VARCHAR DEFAULT '2026-27'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Delete assignment
    DELETE FROM public.class_subject_assignments 
    WHERE school_id = p_school_id 
      AND section_id = p_section_id 
      AND subject_id = p_subject_id 
      AND academic_year = p_academic_year;

    -- Deactivate teachers
    UPDATE public.section_subject_teachers
    SET status = 'INACTIVE', updated_at = NOW()
    WHERE school_id = p_school_id 
      AND section_id = p_section_id 
      AND subject_id = p_subject_id 
      AND academic_year = p_academic_year;

    -- Drop student enrollments
    UPDATE public.student_subject_enrollments
    SET status = 'DROPPED', updated_at = NOW()
    WHERE school_id = p_school_id 
      AND section_id = p_section_id 
      AND subject_id = p_subject_id 
      AND academic_year = p_academic_year;

    PERFORM public.fn_record_class_audit(
        p_school_id, p_user_id, 'UNASSIGN_SUBJECT_FROM_SECTION', 'UNASSIGN', 'Unassign Subject', 'class_subject_assignments', p_subject_id,
        jsonb_build_object('subject_id', p_subject_id, 'class_id', p_class_id, 'section_id', p_section_id)
    );

    RETURN jsonb_build_object('success', TRUE, 'message', 'Subject unassigned from section successfully');
END;
$$;
