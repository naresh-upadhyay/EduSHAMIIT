-- ============================================================================
-- Migration 278: Pure Class-Section Subject Management & Exact Statistical Integrity
-- ============================================================================

-- 1. Schema Adjustments
ALTER TABLE public.section_subject_teachers ALTER COLUMN section_id DROP NOT NULL;
ALTER TABLE public.student_subject_enrollments ALTER COLUMN section_id DROP NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_sec_sub_teacher_composite 
ON public.section_subject_teachers (school_id, academic_year, class_id, COALESCE(section_id, '00000000-0000-0000-0000-000000000000'::UUID), subject_id, teacher_id);

CREATE UNIQUE INDEX IF NOT EXISTS uq_stu_sub_enr_composite 
ON public.student_subject_enrollments (school_id, academic_year, class_id, COALESCE(section_id, '00000000-0000-0000-0000-000000000000'::UUID), subject_id, student_id);

-- 2. Data Cleanup: Convert legacy section_id IS NULL assignments into real section offerings
INSERT INTO public.class_subject_assignments (school_id, class_id, section_id, subject_id, academic_year)
SELECT csa.school_id, csa.class_id, sec.id, csa.subject_id, csa.academic_year
FROM public.class_subject_assignments csa
JOIN public.academic_sections sec ON sec.class_id = csa.class_id AND sec.school_id = csa.school_id AND sec.deleted_at IS NULL
WHERE csa.section_id IS NULL
ON CONFLICT DO NOTHING;

DELETE FROM public.class_subject_assignments WHERE section_id IS NULL;
DELETE FROM public.student_subject_enrollments WHERE section_id IS NULL;
DELETE FROM public.section_subject_teachers WHERE section_id IS NULL;


-- 3. Canonical fn_create_academic_subject (Assigns to all active sections of selected classes)
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
    v_sec_id UUID;
    v_valid_user_id UUID;
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

    IF EXISTS (
        SELECT 1 FROM public.academic_subjects 
        WHERE school_id = p_school_id AND UPPER(code) = v_code AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Subject code already exists in your school catalog', 'code', 409);
    END IF;

    IF EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id) THEN
        v_valid_user_id := p_user_id;
    ELSE
        SELECT id INTO v_valid_user_id FROM public.profiles WHERE school_id = p_school_id LIMIT 1;
        IF v_valid_user_id IS NULL THEN
            SELECT id INTO v_valid_user_id FROM public.profiles LIMIT 1;
        END IF;
    END IF;

    INSERT INTO public.academic_subjects (
        school_id, name, code, type, description, periods_per_week, color, icon, status, is_optional, created_by, updated_by
    ) VALUES (
        p_school_id, v_name, v_code, v_type, v_description, v_periods_per_week, v_color, v_icon, v_status, v_is_optional, v_valid_user_id, v_valid_user_id
    ) RETURNING id INTO v_id;

    -- Assign to sections of selected classes
    IF v_class_ids IS NOT NULL AND jsonb_array_length(v_class_ids) > 0 THEN
        FOR v_cls_id IN SELECT (jsonb_array_elements_text(v_class_ids))::UUID LOOP
            FOR v_sec_id IN SELECT id FROM public.academic_sections WHERE class_id = v_cls_id AND school_id = p_school_id AND deleted_at IS NULL LOOP
                INSERT INTO public.class_subject_assignments (
                    school_id, class_id, section_id, subject_id, academic_year
                ) VALUES (
                    p_school_id, v_cls_id, v_sec_id, v_id, '2026-27'
                ) ON CONFLICT DO NOTHING;

                IF NOT v_is_optional THEN
                    INSERT INTO public.student_subject_enrollments (
                        school_id, class_id, section_id, subject_id, student_id, academic_year, status, enrolled_at, updated_at
                    )
                    SELECT 
                        p_school_id, v_cls_id, v_sec_id, v_id, sca.student_id, '2026-27', 'ACTIVE', NOW(), NOW()
                    FROM public.student_class_assignments sca
                    WHERE sca.section_id = v_sec_id 
                      AND sca.school_id = p_school_id 
                      AND sca.academic_year = '2026-27'
                      AND sca.status = 'ACTIVE'
                    ON CONFLICT (school_id, academic_year, class_id, COALESCE(section_id, '00000000-0000-0000-0000-000000000000'::UUID), subject_id, student_id)
                    DO UPDATE SET section_id = v_sec_id, status = 'ACTIVE', updated_at = NOW();
                END IF;
            END LOOP;
        END LOOP;
    END IF;

    PERFORM public.fn_record_class_audit(
        p_school_id, p_user_id, 'Create', 'Created Subject in Catalog', v_id::TEXT, 'SUBJECT', v_id,
        jsonb_build_object('name', v_name, 'code', v_code, 'type', v_type, 'is_optional', v_is_optional, 'status', v_status)
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Subject created successfully',
        'data', jsonb_build_object('id', v_id)
    );
END;
$$;


-- 4. Canonical fn_update_academic_subject (Synchronizes class sections cleanly)
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
    v_sec_id UUID;
    v_valid_user_id UUID;
BEGIN
    SELECT * INTO v_existing FROM public.academic_subjects 
    WHERE id = p_subject_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Subject not found', 'code', 404);
    END IF;

    IF EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id) THEN
        v_valid_user_id := p_user_id;
    ELSE
        v_valid_user_id := v_existing.updated_by;
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
        updated_by = v_valid_user_id,
        updated_at = NOW()
    WHERE id = p_subject_id;

    -- Synchronize assigned classes
    v_class_ids := p_payload->'class_ids';
    IF v_class_ids IS NOT NULL THEN
        -- 1. Remove assignments for classes not in v_class_ids
        DELETE FROM public.class_subject_assignments
        WHERE school_id = p_school_id 
          AND subject_id = p_subject_id
          AND NOT (class_id = ANY(SELECT jsonb_array_elements_text(v_class_ids)::UUID));

        DELETE FROM public.section_subject_teachers
        WHERE school_id = p_school_id 
          AND subject_id = p_subject_id
          AND NOT (class_id = ANY(SELECT jsonb_array_elements_text(v_class_ids)::UUID));

        DELETE FROM public.student_subject_enrollments
        WHERE school_id = p_school_id 
          AND subject_id = p_subject_id
          AND NOT (class_id = ANY(SELECT jsonb_array_elements_text(v_class_ids)::UUID));

        -- 2. Insert assignments for active sections of assigned classes
        FOR v_cls_id IN SELECT (jsonb_array_elements_text(v_class_ids))::UUID LOOP
            FOR v_sec_id IN SELECT id FROM public.academic_sections WHERE class_id = v_cls_id AND school_id = p_school_id AND deleted_at IS NULL LOOP
                INSERT INTO public.class_subject_assignments (
                    school_id, class_id, section_id, subject_id, academic_year
                ) VALUES (
                    p_school_id, v_cls_id, v_sec_id, p_subject_id, '2026-27'
                ) ON CONFLICT DO NOTHING;

                IF NOT v_is_optional THEN
                    INSERT INTO public.student_subject_enrollments (
                        school_id, class_id, section_id, subject_id, student_id, academic_year, status, enrolled_at, updated_at
                    )
                    SELECT 
                        p_school_id, v_cls_id, v_sec_id, p_subject_id, sca.student_id, '2026-27', 'ACTIVE', NOW(), NOW()
                    FROM public.student_class_assignments sca
                    WHERE sca.section_id = v_sec_id 
                      AND sca.school_id = p_school_id 
                      AND sca.academic_year = '2026-27'
                      AND sca.status = 'ACTIVE'
                    ON CONFLICT (school_id, academic_year, class_id, COALESCE(section_id, '00000000-0000-0000-0000-000000000000'::UUID), subject_id, student_id)
                    DO UPDATE SET section_id = v_sec_id, status = 'ACTIVE', updated_at = NOW();
                END IF;
            END LOOP;
        END LOOP;
    END IF;

    PERFORM public.fn_record_class_audit(
        p_school_id, v_valid_user_id, 'Update', 'Updated Subject in Catalog', p_subject_id::TEXT, 'SUBJECT', p_subject_id,
        jsonb_build_object('name', v_name, 'code', v_code, 'type', v_type, 'is_optional', v_is_optional, 'status', v_status)
    );

    RETURN jsonb_build_object('success', TRUE, 'message', 'Subject updated successfully');
END;
$$;


-- 5. Canonical fn_assign_subject_to_sections (Section-Specific Assignment & Auto-Enrollment)
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
    v_sec_id UUID;
    v_subject public.academic_subjects%ROWTYPE;
    v_is_optional BOOLEAN;
    v_target_sections UUID[];
    v_assigned_count INT := 0;
BEGIN
    SELECT * INTO v_subject 
    FROM public.academic_subjects 
    WHERE id = p_subject_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Subject not found', 'code', 404);
    END IF;

    v_is_optional := COALESCE(v_subject.is_optional, (v_subject.type ILIKE 'Elective' OR v_subject.type ILIKE 'Optional'));

    IF p_section_ids IS NOT NULL AND array_length(p_section_ids, 1) > 0 THEN
        v_target_sections := p_section_ids;
    ELSE
        SELECT ARRAY_AGG(id) INTO v_target_sections
        FROM public.academic_sections
        WHERE class_id = p_class_id AND school_id = p_school_id AND deleted_at IS NULL;
    END IF;

    IF v_target_sections IS NULL OR array_length(v_target_sections, 1) IS NULL OR array_length(v_target_sections, 1) = 0 THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'No active sections found for the selected class', 'code', 400);
    END IF;

    FOREACH v_sec_id IN ARRAY v_target_sections LOOP
        INSERT INTO public.class_subject_assignments (
            school_id, class_id, section_id, subject_id, academic_year
        ) VALUES (
            p_school_id, p_class_id, v_sec_id, p_subject_id, p_academic_year
        ) ON CONFLICT DO NOTHING;

        -- Auto-enroll all section students if Mandatory
        IF NOT v_is_optional THEN
            INSERT INTO public.student_subject_enrollments (
                school_id, class_id, section_id, subject_id, student_id, academic_year, status, enrolled_at, updated_at
            )
            SELECT 
                p_school_id, p_class_id, v_sec_id, p_subject_id, sca.student_id, p_academic_year, 'ACTIVE', NOW(), NOW()
            FROM public.student_class_assignments sca
            WHERE sca.section_id = v_sec_id 
              AND sca.school_id = p_school_id 
              AND sca.academic_year = p_academic_year
              AND sca.status = 'ACTIVE'
            ON CONFLICT (school_id, academic_year, class_id, COALESCE(section_id, '00000000-0000-0000-0000-000000000000'::UUID), subject_id, student_id)
            DO UPDATE SET section_id = v_sec_id, status = 'ACTIVE', updated_at = NOW();
        END IF;

        -- Link teacher if provided
        IF p_teacher_id IS NOT NULL THEN
            INSERT INTO public.section_subject_teachers (
                school_id, class_id, section_id, subject_id, teacher_id, academic_year, status, created_at, updated_at
            ) VALUES (
                p_school_id, p_class_id, v_sec_id, p_subject_id, p_teacher_id, p_academic_year, 'ACTIVE', NOW(), NOW()
            ) ON CONFLICT (school_id, academic_year, class_id, COALESCE(section_id, '00000000-0000-0000-0000-000000000000'::UUID), subject_id, teacher_id)
            DO UPDATE SET status = 'ACTIVE', updated_at = NOW();
        END IF;

        v_assigned_count := v_assigned_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Subject successfully assigned to section(s)',
        'data', jsonb_build_object('assigned_count', v_assigned_count, 'is_optional', v_is_optional)
    );
END;
$$;


-- 6. Canonical fn_unassign_subject_from_section
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
    DELETE FROM public.class_subject_assignments
    WHERE school_id = p_school_id 
      AND class_id = p_class_id 
      AND (p_section_id IS NULL OR section_id = p_section_id)
      AND subject_id = p_subject_id
      AND academic_year = p_academic_year;

    DELETE FROM public.section_subject_teachers
    WHERE school_id = p_school_id
      AND class_id = p_class_id
      AND (p_section_id IS NULL OR section_id = p_section_id)
      AND subject_id = p_subject_id
      AND academic_year = p_academic_year;

    DELETE FROM public.student_subject_enrollments
    WHERE school_id = p_school_id
      AND class_id = p_class_id
      AND (p_section_id IS NULL OR section_id = p_section_id)
      AND subject_id = p_subject_id
      AND academic_year = p_academic_year;

    RETURN jsonb_build_object('success', TRUE, 'message', 'Subject successfully unassigned from section');
END;
$$;


-- 7. Canonical fn_get_subject_section_mappings (Returns Pure Section-Level Offerings)
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
                'section_id', sec.id,
                'section_name', sec.name,
                'section_code', sec.code,
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


-- 8. Canonical fn_get_academic_subjects (10-parameter primary signature)
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
    WHERE s.school_id = p_school_id
      AND (
          (p_status = 'ALL' AND s.deleted_at IS NULL)
          OR (p_status = 'ARCHIVED' AND (UPPER(TRIM(s.status)) = 'ARCHIVED' OR s.deleted_at IS NOT NULL))
          OR (p_status != 'ALL' AND UPPER(TRIM(s.status)) = UPPER(TRIM(p_status)) AND s.deleted_at IS NULL)
      )
      AND (p_type = 'ALL' OR p_type = '' OR UPPER(TRIM(s.type)) = UPPER(TRIM(p_type)))
      AND (
          p_class_id IS NULL
          OR EXISTS (
              SELECT 1 FROM public.class_subject_assignments csa
              WHERE csa.subject_id = s.id AND csa.class_id = p_class_id
          )
      )
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
        SELECT s.*
        FROM public.academic_subjects s
        WHERE s.school_id = p_school_id
          AND (
              (p_status = 'ALL' AND s.deleted_at IS NULL)
              OR (p_status = 'ARCHIVED' AND (UPPER(TRIM(s.status)) = 'ARCHIVED' OR s.deleted_at IS NOT NULL))
              OR (p_status != 'ALL' AND UPPER(TRIM(s.status)) = UPPER(TRIM(p_status)) AND s.deleted_at IS NULL)
          )
          AND (p_type = 'ALL' OR p_type = '' OR UPPER(TRIM(s.type)) = UPPER(TRIM(p_type)))
          AND (
              p_class_id IS NULL
              OR EXISTS (
                  SELECT 1 FROM public.class_subject_assignments csa
                  WHERE csa.subject_id = s.id AND csa.class_id = p_class_id
              )
          )
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
            CASE WHEN LOWER(p_sort_by) = 'name' AND UPPER(p_sort_order) = 'ASC' THEN s.name END ASC NULLS LAST,
            CASE WHEN LOWER(p_sort_by) = 'name' AND UPPER(p_sort_order) = 'DESC' THEN s.name END DESC NULLS LAST,
            CASE WHEN LOWER(p_sort_by) = 'code' AND UPPER(p_sort_order) = 'ASC' THEN s.code END ASC NULLS LAST,
            CASE WHEN LOWER(p_sort_by) = 'code' AND UPPER(p_sort_order) = 'DESC' THEN s.code END DESC NULLS LAST,
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
            'total_pages', CEIL(v_total_count::FLOAT / GREATEST(p_page_size, 1))
        )
    );
END;
$$;

-- 9. Canonical fn_get_academic_subjects (9-parameter overload)
CREATE OR REPLACE FUNCTION public.fn_get_academic_subjects(
    p_school_id UUID,
    p_search TEXT DEFAULT '',
    p_type VARCHAR DEFAULT 'ALL',
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
BEGIN
    RETURN public.fn_get_academic_subjects(
        p_school_id, p_search, p_type, p_status, NULL::UUID, p_page, p_page_size, p_sort_by, p_sort_order, p_teacher_id
    );
END;
$$;


-- 10. Canonical fn_manage_student_subject_enrollments
CREATE OR REPLACE FUNCTION public.fn_manage_student_subject_enrollments(
    p_school_id UUID,
    p_user_id UUID,
    p_class_id UUID,
    p_section_id UUID,
    p_subject_id UUID,
    p_student_ids UUID[],
    p_academic_year VARCHAR DEFAULT '2026-27'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_stu_id UUID;
BEGIN
    -- Mark students not in array as DROPPED
    UPDATE public.student_subject_enrollments
    SET status = 'DROPPED', updated_at = NOW()
    WHERE school_id = p_school_id
      AND academic_year = p_academic_year
      AND class_id = p_class_id
      AND section_id = p_section_id
      AND subject_id = p_subject_id
      AND NOT (student_id = ANY(p_student_ids));

    -- Insert or reactivate selected students
    IF p_student_ids IS NOT NULL AND array_length(p_student_ids, 1) > 0 THEN
        FOREACH v_stu_id IN ARRAY p_student_ids LOOP
            INSERT INTO public.student_subject_enrollments (
                school_id, academic_year, class_id, section_id, subject_id, student_id, status, enrolled_at, updated_at
            ) VALUES (
                p_school_id, p_academic_year, p_class_id, p_section_id, p_subject_id, v_stu_id, 'ACTIVE', NOW(), NOW()
            )
            ON CONFLICT (school_id, academic_year, class_id, COALESCE(section_id, '00000000-0000-0000-0000-000000000000'::UUID), subject_id, student_id)
            DO UPDATE SET section_id = p_section_id, status = 'ACTIVE', updated_at = NOW();
        END LOOP;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Student optional subject enrollments updated successfully.',
        'enrolled_count', COALESCE(array_length(p_student_ids, 1), 0)
    );
END;
$$;


-- 11. Canonical fn_archive_academic_subject (Cleans up assignments & enrollments safely)
CREATE OR REPLACE FUNCTION public.fn_archive_academic_subject(
    p_school_id UUID,
    p_user_id UUID,
    p_subject_id UUID,
    p_force_archive BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_curr RECORD;
    v_classes_count INT := 0;
    v_valid_user_id UUID;
BEGIN
    SELECT * INTO v_curr
    FROM public.academic_subjects
    WHERE id = p_subject_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Subject not found', 'code', 404);
    END IF;

    IF EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id) THEN
        v_valid_user_id := p_user_id;
    ELSE
        SELECT id INTO v_valid_user_id FROM public.profiles WHERE school_id = p_school_id LIMIT 1;
        IF v_valid_user_id IS NULL THEN
            SELECT id INTO v_valid_user_id FROM public.profiles LIMIT 1;
        END IF;
    END IF;

    SELECT COUNT(DISTINCT class_id) INTO v_classes_count
    FROM public.class_subject_assignments
    WHERE subject_id = p_subject_id;

    IF v_classes_count > 0 AND NOT p_force_archive THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'has_dependencies', TRUE,
            'error', 'This subject is assigned to ' || v_classes_count::TEXT || ' class(es). Please confirm archiving.',
            'classes_count', v_classes_count,
            'code', 400
        );
    END IF;

    UPDATE public.academic_subjects SET
        status = 'ARCHIVED',
        deleted_at = NOW(),
        deleted_by = v_valid_user_id,
        updated_at = NOW()
    WHERE id = p_subject_id;

    DELETE FROM public.class_subject_assignments WHERE subject_id = p_subject_id;
    DELETE FROM public.section_subject_teachers WHERE subject_id = p_subject_id;
    DELETE FROM public.student_subject_enrollments WHERE subject_id = p_subject_id;

    PERFORM public.fn_record_class_audit(
        p_school_id, v_valid_user_id, 'Archive', 'Archived Academic Subject', v_curr.name, 'SUBJECT', p_subject_id,
        jsonb_build_object('classes_unlinked', v_classes_count)
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Subject archived successfully'
    );
END;
$$;


-- 12. Canonical fn_restore_academic_subject
CREATE OR REPLACE FUNCTION public.fn_restore_academic_subject(
    p_school_id UUID,
    p_user_id UUID,
    p_subject_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_curr RECORD;
    v_valid_user_id UUID;
BEGIN
    SELECT * INTO v_curr
    FROM public.academic_subjects
    WHERE id = p_subject_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Subject not found', 'code', 404);
    END IF;

    IF EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id) THEN
        v_valid_user_id := p_user_id;
    ELSE
        SELECT id INTO v_valid_user_id FROM public.profiles WHERE school_id = p_school_id LIMIT 1;
        IF v_valid_user_id IS NULL THEN
            SELECT id INTO v_valid_user_id FROM public.profiles LIMIT 1;
        END IF;
    END IF;

    UPDATE public.academic_subjects SET
        status = 'ACTIVE',
        deleted_at = NULL,
        deleted_by = NULL,
        updated_at = NOW()
    WHERE id = p_subject_id;

    PERFORM public.fn_record_class_audit(
        p_school_id, v_valid_user_id, 'Restore', 'Restored Academic Subject', v_curr.name, 'SUBJECT', p_subject_id,
        jsonb_build_object('status', 'ACTIVE')
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Subject restored successfully'
    );
END;
$$;


-- 13. Canonical fn_get_academic_classes (Includes sections array with live students_count)
CREATE OR REPLACE FUNCTION public.fn_get_academic_classes(
    p_school_id UUID,
    p_search TEXT DEFAULT '',
    p_academic_year VARCHAR DEFAULT '2026-27',
    p_status VARCHAR DEFAULT 'ALL',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_sort_by VARCHAR DEFAULT 'display_order',
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
    v_classes JSONB := '[]'::JSONB;
BEGIN
    SELECT COUNT(*)
    INTO v_total_count
    FROM public.academic_classes c
    WHERE c.school_id = p_school_id
      AND c.academic_year = p_academic_year
      AND (
          (p_status = 'ALL' AND c.deleted_at IS NULL)
          OR (p_status = 'ARCHIVED' AND (UPPER(TRIM(c.status)) = 'ARCHIVED' OR c.deleted_at IS NOT NULL))
          OR (p_status != 'ALL' AND UPPER(TRIM(c.status)) = UPPER(TRIM(p_status)) AND c.deleted_at IS NULL)
      )
      AND (
          p_teacher_id IS NULL
          OR EXISTS (
              SELECT 1 FROM public.class_teacher_assignments cta
              WHERE cta.teacher_id = p_teacher_id
                AND cta.class_id = c.id
                AND cta.academic_year = p_academic_year
          )
      )
      AND (
          p_search = '' 
          OR c.name ILIKE '%' || p_search || '%' 
          OR c.code ILIKE '%' || p_search || '%'
          OR c.stage ILIKE '%' || p_search || '%'
      );

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', c.id,
                'name', c.name,
                'code', c.code,
                'stage', c.stage,
                'academic_year', c.academic_year,
                'display_order', c.display_order,
                'status', c.status,
                'sections_count', (
                    SELECT COUNT(*) 
                    FROM public.academic_sections s 
                    WHERE s.class_id = c.id
                      AND s.deleted_at IS NULL
                      AND (
                          p_teacher_id IS NULL
                          OR EXISTS (
                              SELECT 1 FROM public.class_teacher_assignments cta
                              WHERE cta.teacher_id = p_teacher_id
                                AND (cta.section_id = s.id OR (cta.class_id = s.class_id AND cta.section_id IS NULL))
                                AND cta.academic_year = p_academic_year
                          )
                      )
                ),
                'students_count', (
                    SELECT COUNT(DISTINCT sca.student_id) 
                    FROM public.student_class_assignments sca 
                    WHERE sca.class_id = c.id AND sca.status = 'ACTIVE'
                ),
                'sections', (
                    SELECT COALESCE(
                        jsonb_agg(
                            jsonb_build_object(
                                'id', s.id,
                                'class_id', s.class_id,
                                'class_name', c.name,
                                'class_code', c.code,
                                'name', s.name,
                                'code', s.code,
                                'capacity', COALESCE(s.capacity, 40),
                                'status', s.status,
                                'students_count', (
                                    SELECT COUNT(*) 
                                    FROM public.student_class_assignments sca 
                                    WHERE sca.section_id = s.id 
                                      AND sca.school_id = p_school_id 
                                      AND sca.academic_year = p_academic_year 
                                      AND sca.status = 'ACTIVE'
                                )
                            ) ORDER BY s.name ASC
                        ),
                        '[]'::JSONB
                    )
                    FROM public.academic_sections s
                    WHERE s.class_id = c.id AND s.deleted_at IS NULL
                ),
                'class_teacher', (
                    SELECT jsonb_build_object(
                        'id', p.id,
                        'name', p.full_name,
                        'email', p.email,
                        'avatar_url', p.avatar_url
                    )
                    FROM public.class_teacher_assignments cta
                    JOIN public.profiles p ON p.id = cta.teacher_id
                    WHERE cta.class_id = c.id 
                      AND cta.section_id IS NULL
                      AND cta.academic_year = p_academic_year
                    LIMIT 1
                ),
                'created_at', c.created_at,
                'updated_at', c.updated_at
            )
        ),
        '[]'::JSONB
    ) INTO v_classes
    FROM (
        SELECT c.*
        FROM public.academic_classes c
        WHERE c.school_id = p_school_id
          AND c.academic_year = p_academic_year
          AND (
              (p_status = 'ALL' AND c.deleted_at IS NULL)
              OR (p_status = 'ARCHIVED' AND (UPPER(TRIM(c.status)) = 'ARCHIVED' OR c.deleted_at IS NOT NULL))
              OR (p_status != 'ALL' AND UPPER(TRIM(c.status)) = UPPER(TRIM(p_status)) AND c.deleted_at IS NULL)
          )
          AND (
              p_teacher_id IS NULL
              OR EXISTS (
                  SELECT 1 FROM public.class_teacher_assignments cta
                  WHERE cta.teacher_id = p_teacher_id
                    AND cta.class_id = c.id
                    AND cta.academic_year = p_academic_year
              )
          )
          AND (
              p_search = '' 
              OR c.name ILIKE '%' || p_search || '%' 
              OR c.code ILIKE '%' || p_search || '%'
              OR c.stage ILIKE '%' || p_search || '%'
          )
        ORDER BY 
            CASE WHEN p_sort_by = 'display_order' AND p_sort_order ILIKE 'ASC' THEN c.display_order END ASC,
            CASE WHEN p_sort_by = 'display_order' AND p_sort_order ILIKE 'DESC' THEN c.display_order END DESC,
            CASE WHEN p_sort_by = 'name' AND p_sort_order ILIKE 'ASC' THEN c.name END ASC,
            CASE WHEN p_sort_by = 'name' AND p_sort_order ILIKE 'DESC' THEN c.name END DESC,
            c.created_at DESC
        LIMIT p_page_size OFFSET v_offset
    ) c;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'classes', v_classes,
            'total_count', v_total_count,
            'page', p_page,
            'page_size', p_page_size,
            'total_pages', CEIL(v_total_count::NUMERIC / GREATEST(p_page_size, 1)::NUMERIC)
        )
    );
END;
$$;


-- 14. Canonical fn_manage_section_subject_teachers (Supports Assignment, Replacement & Unassignment)
CREATE OR REPLACE FUNCTION public.fn_manage_section_subject_teachers(
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
    v_sec_id UUID;
    v_valid_user_id UUID;
BEGIN
    IF p_subject_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Subject ID is required', 'code', 400);
    END IF;

    IF EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id) THEN
        v_valid_user_id := p_user_id;
    ELSE
        SELECT id INTO v_valid_user_id FROM public.profiles WHERE school_id = p_school_id LIMIT 1;
        IF v_valid_user_id IS NULL THEN
            SELECT id INTO v_valid_user_id FROM public.profiles LIMIT 1;
        END IF;
    END IF;

    -- Unassign / Remove Teacher mode
    IF p_teacher_id IS NULL THEN
        FOREACH v_sec_id IN ARRAY p_section_ids LOOP
            DELETE FROM public.section_subject_teachers 
            WHERE school_id = p_school_id 
              AND academic_year = p_academic_year 
              AND section_id = v_sec_id 
              AND subject_id = p_subject_id;
        END LOOP;

        PERFORM public.fn_record_class_audit(
            p_school_id, v_valid_user_id, 'TEACHER_UNASSIGNED_FROM_SECTION_SUBJECT', 'UNASSIGN', 'Subject Teacher Unassignment', 'section_subject_teachers', p_subject_id,
            jsonb_build_object('section_ids', p_section_ids, 'subject_id', p_subject_id)
        );

        RETURN jsonb_build_object('success', TRUE, 'message', 'Teacher successfully unassigned from selected sections.');
    END IF;

    -- Assign / Replace Teacher mode
    FOREACH v_sec_id IN ARRAY p_section_ids LOOP
        -- Remove any other teacher assigned to this section + subject
        DELETE FROM public.section_subject_teachers 
        WHERE school_id = p_school_id 
          AND academic_year = p_academic_year 
          AND section_id = v_sec_id 
          AND subject_id = p_subject_id 
          AND teacher_id != p_teacher_id;

        -- Insert or activate the new teacher
        INSERT INTO public.section_subject_teachers (
            school_id, academic_year, class_id, section_id, subject_id, teacher_id, is_primary, status
        ) VALUES (
            p_school_id, p_academic_year, p_class_id, v_sec_id, p_subject_id, p_teacher_id, TRUE, 'ACTIVE'
        )
        ON CONFLICT (school_id, academic_year, section_id, subject_id, teacher_id) 
        DO UPDATE SET status = 'ACTIVE', updated_at = NOW();

        -- Also ensure class_subject_assignments exists for this section
        INSERT INTO public.class_subject_assignments (
            school_id, class_id, section_id, subject_id, academic_year
        ) VALUES (
            p_school_id, p_class_id, v_sec_id, p_subject_id, p_academic_year
        )
        ON CONFLICT DO NOTHING;
    END LOOP;

    PERFORM public.fn_record_class_audit(
        p_school_id, v_valid_user_id, 'TEACHER_ASSIGNED_TO_SECTION_SUBJECT', 'ASSIGN', 'Subject Teacher Assignment', 'section_subject_teachers', p_subject_id,
        jsonb_build_object('teacher_id', p_teacher_id, 'section_ids', p_section_ids, 'subject_id', p_subject_id)
    );

    RETURN jsonb_build_object('success', TRUE, 'message', 'Teacher successfully assigned to selected sections for this subject.');
END;
$$;



