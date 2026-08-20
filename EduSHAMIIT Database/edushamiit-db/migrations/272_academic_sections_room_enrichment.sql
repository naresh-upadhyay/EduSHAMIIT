-- Migration 272: Academic Sections Room Enrichment and Details
-- Enrich fn_get_academic_sections and section CRUD to seamlessly support room_id and room building/name

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
    p_teacher_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_count INT := 0;
    v_offset INT;
    v_sections JSONB;
BEGIN
    v_offset := (GREATEST(p_page, 1) - 1) * p_page_size;

    SELECT COUNT(*)
    INTO v_total_count
    FROM public.academic_sections s
    JOIN public.academic_classes c ON c.id = s.class_id
    WHERE s.school_id = p_school_id
      AND s.academic_year = p_academic_year
      AND s.deleted_at IS NULL
      AND (p_class_id IS NULL OR s.class_id = p_class_id)
      AND (
          p_status = 'ALL' 
          OR (p_status = 'ACTIVE' AND s.status = 'ACTIVE')
          OR (p_status = 'INACTIVE' AND s.status = 'INACTIVE')
          OR (p_status = 'ARCHIVED' AND s.status = 'ARCHIVED')
      )
      AND (
          p_search = '' 
          OR s.name ILIKE '%' || p_search || '%' 
          OR s.code ILIKE '%' || p_search || '%'
          OR c.name ILIKE '%' || p_search || '%'
      )
      AND (
          p_teacher_id IS NULL
          OR EXISTS (
              SELECT 1 FROM public.class_teacher_assignments cta 
              WHERE (cta.section_id = s.id OR (cta.class_id = s.class_id AND cta.section_id IS NULL))
                AND cta.teacher_id = p_teacher_id
          )
          OR EXISTS (
              SELECT 1 FROM public.section_subject_teachers sst
              WHERE sst.section_id = s.id AND sst.teacher_id = p_teacher_id
          )
      );

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', s_item.id,
                'name', s_item.name,
                'code', s_item.code,
                'class_id', s_item.class_id,
                'class_name', s_item.class_name,
                'class_code', s_item.class_code,
                'capacity', s_item.capacity,
                'room_number', s_item.room_number,
                'room_id', s_item.room_id,
                'room_name', s_item.room_name,
                'building', s_item.building,
                'academic_year', s_item.academic_year,
                'status', s_item.status,
                'students_count', (
                    SELECT COUNT(*) 
                    FROM public.student_class_assignments sca 
                    WHERE sca.section_id = s_item.id AND sca.status = 'ACTIVE'
                ),
                'class_teacher', (
                    SELECT jsonb_build_object(
                        'id', p.id,
                        'full_name', p.full_name,
                        'email', p.email,
                        'avatar_url', p.avatar_url,
                        'employee_id', p.employee_id
                    )
                    FROM public.class_teacher_assignments cta
                    JOIN public.profiles p ON p.id = cta.teacher_id
                    WHERE cta.section_id = s_item.id
                    LIMIT 1
                ),
                'subjects_count', (
                    SELECT COUNT(DISTINCT csa.subject_id)
                    FROM public.class_subject_assignments csa
                    WHERE csa.section_id = s_item.id OR (csa.class_id = s_item.class_id AND csa.section_id IS NULL)
                ),
                'optional_subjects_count', (
                    SELECT COUNT(DISTINCT sub.id)
                    FROM public.class_subject_assignments csa
                    JOIN public.academic_subjects sub ON sub.id = csa.subject_id
                    WHERE (csa.section_id = s_item.id OR (csa.class_id = s_item.class_id AND csa.section_id IS NULL))
                      AND (sub.type ILIKE 'Elective' OR sub.type ILIKE 'Optional')
                ),
                'assigned_subject_ids', (
                    SELECT COALESCE(jsonb_agg(DISTINCT csa.subject_id), '[]'::JSONB)
                    FROM public.class_subject_assignments csa
                    WHERE csa.section_id = s_item.id OR (csa.class_id = s_item.class_id AND csa.section_id IS NULL)
                ),
                'created_at', s_item.created_at,
                'updated_at', s_item.updated_at
            ) ORDER BY 
                CASE WHEN LOWER(p_sort_by) = 'name' AND UPPER(p_sort_order) = 'ASC' THEN s_item.name END ASC,
                CASE WHEN LOWER(p_sort_by) = 'name' AND UPPER(p_sort_order) = 'DESC' THEN s_item.name END DESC,
                CASE WHEN LOWER(p_sort_by) = 'class_name' AND UPPER(p_sort_order) = 'DESC' THEN s_item.class_name END DESC,
                s_item.class_order ASC,
                s_item.display_order ASC,
                s_item.name ASC
        ),
        '[]'::JSONB
    ) INTO v_sections
    FROM (
        SELECT 
            s.*, 
            c.name as class_name, 
            c.code as class_code, 
            c.display_order as class_order,
            COALESCE(r.name, s.room_number) as room_name,
            COALESCE(r.building, 'Academic Block') as building
        FROM public.academic_sections s
        JOIN public.academic_classes c ON c.id = s.class_id
        LEFT JOIN public.academic_rooms r ON r.id = s.room_id
        WHERE s.school_id = p_school_id
          AND s.academic_year = p_academic_year
          AND s.deleted_at IS NULL
          AND (p_class_id IS NULL OR s.class_id = p_class_id)
          AND (
              p_status = 'ALL' 
              OR (p_status = 'ACTIVE' AND s.status = 'ACTIVE')
              OR (p_status = 'INACTIVE' AND s.status = 'INACTIVE')
              OR (p_status = 'ARCHIVED' AND s.status = 'ARCHIVED')
          )
          AND (
              p_search = '' 
              OR s.name ILIKE '%' || p_search || '%' 
              OR s.code ILIKE '%' || p_search || '%'
              OR c.name ILIKE '%' || p_search || '%'
          )
          AND (
              p_teacher_id IS NULL
              OR EXISTS (
                  SELECT 1 FROM public.class_teacher_assignments cta 
                  WHERE (cta.section_id = s.id OR (cta.class_id = s.class_id AND cta.section_id IS NULL))
                    AND cta.teacher_id = p_teacher_id
              )
              OR EXISTS (
                  SELECT 1 FROM public.section_subject_teachers sst
                  WHERE sst.section_id = s.id AND sst.teacher_id = p_teacher_id
              )
          )
        LIMIT p_page_size OFFSET v_offset
    ) s_item;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'sections', v_sections,
            'total_count', v_total_count,
            'page', p_page,
            'page_size', p_page_size,
            'total_pages', CEIL(v_total_count::FLOAT / GREATEST(p_page_size, 1))
        )
    );
END;
$$;


-- Create or update section functions to save room_id
CREATE OR REPLACE FUNCTION public.fn_create_academic_section(
    p_school_id UUID,
    p_user_id UUID,
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_class_id UUID;
    v_name VARCHAR(50);
    v_code VARCHAR(50);
    v_capacity INT;
    v_room_number VARCHAR(50);
    v_room_id UUID;
    v_academic_year VARCHAR(50);
    v_status VARCHAR(20);
    v_display_order INT;
    v_new_id UUID;
BEGIN
    v_class_id := (p_payload->>'class_id')::UUID;
    v_name := TRIM(COALESCE(p_payload->>'name', ''));
    v_code := UPPER(TRIM(COALESCE(p_payload->>'code', '')));
    v_capacity := COALESCE((p_payload->>'capacity')::INT, 40);
    v_room_number := p_payload->>'room_number';
    v_room_id := (p_payload->>'room_id')::UUID;
    v_academic_year := TRIM(COALESCE(p_payload->>'academic_year', '2026-27'));
    v_status := UPPER(TRIM(COALESCE(p_payload->>'status', 'ACTIVE')));
    v_display_order := COALESCE((p_payload->>'display_order')::INT, 1);

    IF v_class_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Class ID is required', 'code', 400);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.academic_classes WHERE id = v_class_id AND school_id = p_school_id AND deleted_at IS NULL) THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Class not found', 'code', 404);
    END IF;

    IF v_name = '' THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Section name is required', 'code', 400);
    END IF;

    IF v_code = '' THEN
        v_code := UPPER(REGEXP_REPLACE(v_name, '[^a-zA-Z0-9]+', '', 'g'));
    END IF;

    -- Check duplicate section code within same class
    IF EXISTS (
        SELECT 1 FROM public.academic_sections 
        WHERE school_id = p_school_id 
          AND class_id = v_class_id 
          AND academic_year = v_academic_year 
          AND UPPER(code) = v_code 
          AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Section with code "' || v_code || '" already exists in this class', 'code', 409);
    END IF;

    -- If room_id provided, fetch room name as room_number
    IF v_room_id IS NOT NULL AND (v_room_number IS NULL OR v_room_number = '') THEN
        SELECT name INTO v_room_number FROM public.academic_rooms WHERE id = v_room_id;
    END IF;

    INSERT INTO public.academic_sections (
        school_id, class_id, name, code, capacity, room_number, room_id, academic_year, display_order, status, created_by, updated_by
    ) VALUES (
        p_school_id, v_class_id, v_name, v_code, v_capacity, v_room_number, v_room_id, v_academic_year, v_display_order, v_status, p_user_id, p_user_id
    ) RETURNING id INTO v_new_id;

    PERFORM public.fn_record_class_audit(
        p_school_id, p_user_id, 'Create', 'Created Academic Section', v_name, 'SECTION', v_new_id,
        jsonb_build_object('name', v_name, 'code', v_code, 'class_id', v_class_id)
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Section created successfully',
        'data', jsonb_build_object(
            'id', v_new_id,
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

    PERFORM public.fn_record_class_audit(
        p_school_id, p_user_id, 'Update', 'Updated Academic Section', v_name, 'SECTION', p_section_id,
        jsonb_build_object('name', v_name, 'code', v_code, 'room_number', v_room_number, 'room_id', v_room_id)
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
