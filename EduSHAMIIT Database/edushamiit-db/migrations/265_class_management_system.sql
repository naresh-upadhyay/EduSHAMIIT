-- ============================================================================
-- Migration: 265_class_management_system.sql
-- Description: Universal Academic Class, Section & Subject Management System
-- Scoped: Multi-tenant (school_id), Academic Year, RBAC & Audit-Ready
-- ============================================================================

-- 1. Academic Classes Table
CREATE TABLE IF NOT EXISTS public.academic_classes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    code VARCHAR(50) NOT NULL,
    stage VARCHAR(50) DEFAULT 'Secondary', -- Pre-Primary, Primary, Middle School, Secondary, Senior Secondary
    academic_year VARCHAR(50) NOT NULL DEFAULT '2026-27',
    display_order INT DEFAULT 1,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, INACTIVE, ARCHIVED
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_academic_classes_school_code 
    ON public.academic_classes (school_id, academic_year, UPPER(code)) 
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_academic_classes_school_name 
    ON public.academic_classes (school_id, academic_year, UPPER(name)) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_academic_classes_school_status 
    ON public.academic_classes (school_id, status) 
    WHERE deleted_at IS NULL;


-- 2. Academic Sections Table
CREATE TABLE IF NOT EXISTS public.academic_sections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    class_id UUID NOT NULL REFERENCES public.academic_classes(id) ON DELETE CASCADE,
    name VARCHAR(50) NOT NULL, -- e.g., "9-A", "A"
    code VARCHAR(50) NOT NULL, -- e.g., "9A", "A"
    capacity INT NOT NULL DEFAULT 40,
    room_number VARCHAR(50),
    academic_year VARCHAR(50) NOT NULL DEFAULT '2026-27',
    display_order INT DEFAULT 1,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, INACTIVE, ARCHIVED
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_academic_sections_code 
    ON public.academic_sections (school_id, class_id, academic_year, UPPER(code)) 
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_academic_sections_name 
    ON public.academic_sections (school_id, class_id, academic_year, UPPER(name)) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_academic_sections_class 
    ON public.academic_sections (class_id, status) 
    WHERE deleted_at IS NULL;


-- 3. Academic Subjects Catalog Table
CREATE TABLE IF NOT EXISTS public.academic_subjects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    name VARCHAR(150) NOT NULL,
    code VARCHAR(50) NOT NULL,
    type VARCHAR(50) NOT NULL DEFAULT 'Core', -- Core, Elective, Language, Practical, Activity, Other
    description TEXT,
    periods_per_week INT NOT NULL DEFAULT 5,
    color VARCHAR(50) DEFAULT '#4F46E5',
    icon VARCHAR(100) DEFAULT 'book',
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, INACTIVE, ARCHIVED
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_academic_subjects_code 
    ON public.academic_subjects (school_id, UPPER(code)) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_academic_subjects_school 
    ON public.academic_subjects (school_id, status) 
    WHERE deleted_at IS NULL;


-- 4. Class & Section Subject Assignments Table
CREATE TABLE IF NOT EXISTS public.class_subject_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    class_id UUID NOT NULL REFERENCES public.academic_classes(id) ON DELETE CASCADE,
    section_id UUID REFERENCES public.academic_sections(id) ON DELETE CASCADE, -- NULL means entire class
    subject_id UUID NOT NULL REFERENCES public.academic_subjects(id) ON DELETE CASCADE,
    academic_year VARCHAR(50) NOT NULL DEFAULT '2026-27',
    periods_per_week INT DEFAULT 5,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_class_subject_assignment 
    ON public.class_subject_assignments (
        school_id, 
        class_id, 
        COALESCE(section_id, '00000000-0000-0000-0000-000000000000'::UUID), 
        subject_id, 
        academic_year
    );

CREATE INDEX IF NOT EXISTS idx_class_subject_class ON public.class_subject_assignments(class_id);
CREATE INDEX IF NOT EXISTS idx_class_subject_section ON public.class_subject_assignments(section_id);


-- 5. Class & Section Teacher Assignments Table
CREATE TABLE IF NOT EXISTS public.class_teacher_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    class_id UUID NOT NULL REFERENCES public.academic_classes(id) ON DELETE CASCADE,
    section_id UUID REFERENCES public.academic_sections(id) ON DELETE CASCADE, -- NULL means direct class teacher
    teacher_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    academic_year VARCHAR(50) NOT NULL DEFAULT '2026-27',
    is_primary BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_class_teacher_assignment 
    ON public.class_teacher_assignments (
        school_id, 
        class_id, 
        COALESCE(section_id, '00000000-0000-0000-0000-000000000000'::UUID), 
        teacher_id, 
        academic_year
    );

CREATE INDEX IF NOT EXISTS idx_class_teacher_class ON public.class_teacher_assignments(class_id);
CREATE INDEX IF NOT EXISTS idx_class_teacher_teacher ON public.class_teacher_assignments(teacher_id);


-- 6. Student Class & Section Assignments Table
CREATE TABLE IF NOT EXISTS public.student_class_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    class_id UUID NOT NULL REFERENCES public.academic_classes(id) ON DELETE CASCADE,
    section_id UUID REFERENCES public.academic_sections(id) ON DELETE SET NULL, -- NULL allowed for classes without sections
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    academic_year VARCHAR(50) NOT NULL DEFAULT '2026-27',
    roll_number VARCHAR(50),
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_student_academic_assignment 
    ON public.student_class_assignments (school_id, student_id, academic_year);

CREATE INDEX IF NOT EXISTS idx_student_class_class ON public.student_class_assignments(class_id);
CREATE INDEX IF NOT EXISTS idx_student_class_section ON public.student_class_assignments(section_id);
CREATE INDEX IF NOT EXISTS idx_student_class_student ON public.student_class_assignments(student_id);


-- ============================================================================
-- STORED PROCEDURES & BUSINESS LOGIC
-- ============================================================================

-- Centralized Helper for Class Management Audit Logging
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
    v_user_email VARCHAR(255);
    v_user_name VARCHAR(255);
    v_user_role VARCHAR(50);
BEGIN
    IF p_user_id IS NOT NULL THEN
        SELECT email, full_name, role 
        INTO v_user_email, v_user_name, v_user_role
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
        p_user_id,
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


-- Function: Get Academic Statistics
CREATE OR REPLACE FUNCTION public.fn_get_academic_stats(
    p_school_id UUID,
    p_academic_year VARCHAR DEFAULT '2026-27'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_classes INT := 0;
    v_active_classes INT := 0;
    v_total_sections INT := 0;
    v_total_subjects INT := 0;
    v_total_students INT := 0;
    v_total_teachers INT := 0;
BEGIN
    SELECT COUNT(*), COUNT(*) FILTER (WHERE status = 'ACTIVE')
    INTO v_total_classes, v_active_classes
    FROM public.academic_classes
    WHERE school_id = p_school_id 
      AND academic_year = p_academic_year 
      AND deleted_at IS NULL;

    SELECT COUNT(*)
    INTO v_total_sections
    FROM public.academic_sections
    WHERE school_id = p_school_id 
      AND academic_year = p_academic_year 
      AND deleted_at IS NULL;

    SELECT COUNT(*)
    INTO v_total_subjects
    FROM public.academic_subjects
    WHERE school_id = p_school_id 
      AND deleted_at IS NULL;

    SELECT COUNT(DISTINCT student_id)
    INTO v_total_students
    FROM public.student_class_assignments
    WHERE school_id = p_school_id 
      AND academic_year = p_academic_year 
      AND status = 'ACTIVE';

    SELECT COUNT(DISTINCT teacher_id)
    INTO v_total_teachers
    FROM public.class_teacher_assignments
    WHERE school_id = p_school_id 
      AND academic_year = p_academic_year;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'total_classes', v_total_classes,
            'active_classes', v_active_classes,
            'total_sections', v_total_sections,
            'total_subjects', v_total_subjects,
            'total_students', v_total_students,
            'total_teachers', v_total_teachers,
            'academic_year', p_academic_year
        )
    );
END;
$$;


-- Function: Get Paginated Academic Classes with Counts & Primary Teachers
CREATE OR REPLACE FUNCTION public.fn_get_academic_classes(
    p_school_id UUID,
    p_search TEXT DEFAULT '',
    p_academic_year VARCHAR DEFAULT '2026-27',
    p_status VARCHAR DEFAULT 'ALL',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_sort_by VARCHAR DEFAULT 'display_order',
    p_sort_order VARCHAR DEFAULT 'ASC'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_count INT := 0;
    v_offset INT;
    v_classes JSONB;
BEGIN
    v_offset := (p_page - 1) * p_page_size;

    SELECT COUNT(*)
    INTO v_total_count
    FROM public.academic_classes c
    WHERE c.school_id = p_school_id
      AND c.academic_year = p_academic_year
      AND (
          (p_status = 'ALL' AND c.deleted_at IS NULL AND c.status != 'ARCHIVED')
          OR (p_status = 'ACTIVE' AND c.status = 'ACTIVE' AND c.deleted_at IS NULL)
          OR (p_status = 'INACTIVE' AND c.status = 'INACTIVE' AND c.deleted_at IS NULL)
          OR (p_status = 'ARCHIVED' AND (c.status = 'ARCHIVED' OR c.deleted_at IS NOT NULL))
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
                ),
                'students_count', (
                    SELECT COUNT(DISTINCT sca.student_id) 
                    FROM public.student_class_assignments sca 
                    WHERE sca.class_id = c.id AND sca.status = 'ACTIVE'
                ),
                'subjects_count', (
                    SELECT COUNT(DISTINCT csa.subject_id) 
                    FROM public.class_subject_assignments csa 
                    WHERE csa.class_id = c.id
                ),
                'class_teachers_count', (
                    SELECT COUNT(DISTINCT cta.teacher_id) 
                    FROM public.class_teacher_assignments cta 
                    WHERE cta.class_id = c.id AND cta.section_id IS NULL
                ),
                'primary_teacher', (
                    SELECT jsonb_build_object(
                        'id', p.id,
                        'full_name', p.full_name,
                        'email', p.email,
                        'avatar_url', p.avatar_url,
                        'employee_id', p.employee_id
                    )
                    FROM public.class_teacher_assignments cta
                    JOIN public.profiles p ON p.id = cta.teacher_id
                    WHERE cta.class_id = c.id AND cta.section_id IS NULL
                    ORDER BY cta.is_primary DESC, cta.created_at ASC
                    LIMIT 1
                ),
                'created_at', c.created_at,
                'updated_at', c.updated_at
            ) ORDER BY 
                CASE WHEN LOWER(p_sort_by) = 'name' AND UPPER(p_sort_order) = 'ASC' THEN c.name END ASC,
                CASE WHEN LOWER(p_sort_by) = 'name' AND UPPER(p_sort_order) = 'DESC' THEN c.name END DESC,
                CASE WHEN LOWER(p_sort_by) = 'code' AND UPPER(p_sort_order) = 'ASC' THEN c.code END ASC,
                CASE WHEN LOWER(p_sort_by) = 'code' AND UPPER(p_sort_order) = 'DESC' THEN c.code END DESC,
                CASE WHEN LOWER(p_sort_by) = 'display_order' AND UPPER(p_sort_order) = 'DESC' THEN c.display_order END DESC,
                c.display_order ASC,
                c.created_at ASC
        ),
        '[]'::JSONB
    ) INTO v_classes
    FROM (
        SELECT *
        FROM public.academic_classes c
        WHERE c.school_id = p_school_id
          AND c.academic_year = p_academic_year
          AND (
              (p_status = 'ALL' AND c.deleted_at IS NULL AND c.status != 'ARCHIVED')
              OR (p_status = 'ACTIVE' AND c.status = 'ACTIVE' AND c.deleted_at IS NULL)
              OR (p_status = 'INACTIVE' AND c.status = 'INACTIVE' AND c.deleted_at IS NULL)
              OR (p_status = 'ARCHIVED' AND (c.status = 'ARCHIVED' OR c.deleted_at IS NOT NULL))
          )
          AND (
              p_search = '' 
              OR c.name ILIKE '%' || p_search || '%' 
              OR c.code ILIKE '%' || p_search || '%'
              OR c.stage ILIKE '%' || p_search || '%'
          )
        ORDER BY c.display_order ASC, c.created_at ASC
        LIMIT p_page_size OFFSET v_offset
    ) c;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'classes', v_classes,
            'total_count', v_total_count,
            'page', p_page,
            'page_size', p_page_size,
            'total_pages', CEIL(v_total_count::FLOAT / GREATEST(p_page_size, 1))
        )
    );
END;
$$;


-- Function: Get Full Details of a Specific Class
CREATE OR REPLACE FUNCTION public.fn_get_academic_class_detail(
    p_school_id UUID,
    p_class_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_class RECORD;
    v_sections JSONB;
    v_subjects JSONB;
    v_teachers JSONB;
    v_students_count INT := 0;
BEGIN
    SELECT * INTO v_class
    FROM public.academic_classes
    WHERE id = p_class_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Class not found', 'code', 404);
    END IF;

    -- Fetch Sections
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', s.id,
                'name', s.name,
                'code', s.code,
                'capacity', s.capacity,
                'room_number', s.room_number,
                'status', s.status,
                'students_count', (
                    SELECT COUNT(*) 
                    FROM public.student_class_assignments sca 
                    WHERE sca.section_id = s.id AND sca.status = 'ACTIVE'
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
                    WHERE cta.section_id = s.id
                    LIMIT 1
                ),
                'subjects_count', (
                    SELECT COUNT(*)
                    FROM public.class_subject_assignments csa
                    WHERE csa.section_id = s.id
                )
            ) ORDER BY s.display_order ASC, s.name ASC
        ),
        '[]'::JSONB
    ) INTO v_sections
    FROM public.academic_sections s
    WHERE s.class_id = p_class_id AND s.deleted_at IS NULL;

    -- Fetch Subjects assigned to this class
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', sub.id,
                'name', sub.name,
                'code', sub.code,
                'type', sub.type,
                'periods_per_week', COALESCE(csa.periods_per_week, sub.periods_per_week),
                'status', sub.status,
                'color', sub.color,
                'is_class_wide', (csa.section_id IS NULL),
                'section_id', csa.section_id
            ) ORDER BY sub.name ASC
        ),
        '[]'::JSONB
    ) INTO v_subjects
    FROM public.class_subject_assignments csa
    JOIN public.academic_subjects sub ON sub.id = csa.subject_id
    WHERE csa.class_id = p_class_id AND sub.deleted_at IS NULL;

    -- Fetch Direct Class Teachers
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', p.id,
                'full_name', p.full_name,
                'email', p.email,
                'avatar_url', p.avatar_url,
                'employee_id', p.employee_id,
                'department', p.department,
                'is_primary', cta.is_primary
            ) ORDER BY cta.is_primary DESC, p.full_name ASC
        ),
        '[]'::JSONB
    ) INTO v_teachers
    FROM public.class_teacher_assignments cta
    JOIN public.profiles p ON p.id = cta.teacher_id
    WHERE cta.class_id = p_class_id AND cta.section_id IS NULL;

    SELECT COUNT(DISTINCT student_id) INTO v_students_count
    FROM public.student_class_assignments
    WHERE class_id = p_class_id AND status = 'ACTIVE';

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
            'students_count', v_students_count,
            'sections', v_sections,
            'subjects', v_subjects,
            'class_teachers', v_teachers,
            'created_at', v_class.created_at,
            'updated_at', v_class.updated_at
        )
    );
END;
$$;


-- Function: Create Academic Class (with optional inline sections creation)
CREATE OR REPLACE FUNCTION public.fn_create_academic_class(
    p_school_id UUID,
    p_user_id UUID,
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_name VARCHAR(100);
    v_code VARCHAR(50);
    v_stage VARCHAR(50);
    v_academic_year VARCHAR(50);
    v_display_order INT;
    v_status VARCHAR(20);
    v_new_class_id UUID;
    v_sections_array JSONB;
    v_sec JSONB;
    v_sec_name VARCHAR(50);
    v_sec_code VARCHAR(50);
    v_sec_capacity INT;
    v_sec_status VARCHAR(20);
    v_sec_id UUID;
    v_created_sections JSONB := '[]'::JSONB;
    v_idx INT := 1;
BEGIN
    v_name := TRIM(COALESCE(p_payload->>'name', ''));
    v_code := UPPER(TRIM(COALESCE(p_payload->>'code', '')));
    v_stage := TRIM(COALESCE(p_payload->>'stage', 'Secondary'));
    v_academic_year := TRIM(COALESCE(p_payload->>'academic_year', '2026-27'));
    v_display_order := COALESCE((p_payload->>'display_order')::INT, 1);
    v_status := UPPER(TRIM(COALESCE(p_payload->>'status', 'ACTIVE')));

    IF v_name = '' THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Class name is required', 'code', 400);
    END IF;

    IF v_code = '' THEN
        v_code := UPPER(REGEXP_REPLACE(v_name, '[^a-zA-Z0-9]+', '', 'g'));
    END IF;

    -- Check duplicate class code
    IF EXISTS (
        SELECT 1 FROM public.academic_classes 
        WHERE school_id = p_school_id 
          AND academic_year = v_academic_year 
          AND UPPER(code) = v_code 
          AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Class with code "' || v_code || '" already exists for academic year ' || v_academic_year, 'code', 409);
    END IF;

    -- Insert Class
    INSERT INTO public.academic_classes (
        school_id, name, code, stage, academic_year, display_order, status, created_by, updated_by
    ) VALUES (
        p_school_id, v_name, v_code, v_stage, v_academic_year, v_display_order, v_status, p_user_id, p_user_id
    ) RETURNING id INTO v_new_class_id;

    -- Process Inline Sections if provided
    v_sections_array := COALESCE(p_payload->'sections', '[]'::JSONB);
    IF jsonb_typeof(v_sections_array) = 'array' AND jsonb_array_length(v_sections_array) > 0 THEN
        FOR v_sec IN SELECT * FROM jsonb_array_elements(v_sections_array) LOOP
            v_sec_name := TRIM(COALESCE(v_sec->>'name', ''));
            v_sec_code := UPPER(TRIM(COALESCE(v_sec->>'code', '')));
            v_sec_capacity := COALESCE((v_sec->>'capacity')::INT, 40);
            v_sec_status := UPPER(TRIM(COALESCE(v_sec->>'status', 'ACTIVE')));

            IF v_sec_name != '' THEN
                IF v_sec_code = '' THEN
                    v_sec_code := UPPER(REGEXP_REPLACE(v_sec_name, '[^a-zA-Z0-9]+', '', 'g'));
                END IF;

                INSERT INTO public.academic_sections (
                    school_id, class_id, name, code, capacity, academic_year, display_order, status, created_by, updated_by
                ) VALUES (
                    p_school_id, v_new_class_id, v_sec_name, v_sec_code, v_sec_capacity, v_academic_year, v_idx, v_sec_status, p_user_id, p_user_id
                ) RETURNING id INTO v_sec_id;

                v_created_sections := v_created_sections || jsonb_build_object(
                    'id', v_sec_id,
                    'name', v_sec_name,
                    'code', v_sec_code,
                    'capacity', v_sec_capacity,
                    'status', v_sec_status
                );

                v_idx := v_idx + 1;
            END IF;
        END LOOP;
    END IF;

    -- Record Audit Log
    PERFORM public.fn_record_class_audit(
        p_school_id, p_user_id, 'Create', 'Created Academic Class', v_name, 'CLASS', v_new_class_id,
        jsonb_build_object('name', v_name, 'code', v_code, 'sections_created', jsonb_array_length(v_created_sections))
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Class created successfully',
        'data', jsonb_build_object(
            'id', v_new_class_id,
            'name', v_name,
            'code', v_code,
            'stage', v_stage,
            'academic_year', v_academic_year,
            'status', v_status,
            'sections', v_created_sections
        )
    );
END;
$$;


-- Function: Update Academic Class
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


-- Function: Archive / Delete Academic Class
CREATE OR REPLACE FUNCTION public.fn_archive_academic_class(
    p_school_id UUID,
    p_user_id UUID,
    p_class_id UUID,
    p_force_archive BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_curr RECORD;
    v_sections_count INT := 0;
    v_students_count INT := 0;
    v_subjects_count INT := 0;
BEGIN
    SELECT * INTO v_curr
    FROM public.academic_classes
    WHERE id = p_class_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Class not found', 'code', 404);
    END IF;

    SELECT COUNT(*) INTO v_sections_count 
    FROM public.academic_sections 
    WHERE class_id = p_class_id AND deleted_at IS NULL;

    SELECT COUNT(*) INTO v_students_count 
    FROM public.student_class_assignments 
    WHERE class_id = p_class_id AND status = 'ACTIVE';

    SELECT COUNT(*) INTO v_subjects_count 
    FROM public.class_subject_assignments 
    WHERE class_id = p_class_id;

    -- If dependencies exist and not forced, return warning with impact
    IF (v_sections_count > 0 OR v_students_count > 0 OR v_subjects_count > 0) AND NOT p_force_archive THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'has_dependencies', TRUE,
            'error', 'This class contains ' || v_sections_count::TEXT || ' sections, ' || v_students_count::TEXT || ' students, and ' || v_subjects_count::TEXT || ' subjects. Please confirm archiving.',
            'impact', jsonb_build_object(
                'sections_count', v_sections_count,
                'students_count', v_students_count,
                'subjects_count', v_subjects_count
            ),
            'code', 400
        );
    END IF;

    -- Archive Class and its Sections
    UPDATE public.academic_classes SET
        status = 'ARCHIVED',
        deleted_at = NOW(),
        deleted_by = p_user_id,
        updated_at = NOW()
    WHERE id = p_class_id;

    UPDATE public.academic_sections SET
        status = 'ARCHIVED',
        deleted_at = NOW(),
        deleted_by = p_user_id,
        updated_at = NOW()
    WHERE class_id = p_class_id AND deleted_at IS NULL;

    PERFORM public.fn_record_class_audit(
        p_school_id, p_user_id, 'Archive', 'Archived Academic Class', v_curr.name, 'CLASS', p_class_id,
        jsonb_build_object('sections_affected', v_sections_count, 'students_affected', v_students_count)
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Class archived successfully'
    );
END;
$$;


-- Function: Get Paginated Sections Across Classes
CREATE OR REPLACE FUNCTION public.fn_get_academic_sections(
    p_school_id UUID,
    p_search TEXT DEFAULT '',
    p_class_id UUID DEFAULT NULL,
    p_academic_year VARCHAR DEFAULT '2026-27',
    p_status VARCHAR DEFAULT 'ALL',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_sort_by VARCHAR DEFAULT 'class_name',
    p_sort_order VARCHAR DEFAULT 'ASC'
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
    v_offset := (p_page - 1) * p_page_size;

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
      );

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', s.id,
                'name', s.name,
                'code', s.code,
                'class_id', c.id,
                'class_name', c.name,
                'class_code', c.code,
                'capacity', s.capacity,
                'room_number', s.room_number,
                'academic_year', s.academic_year,
                'status', s.status,
                'students_count', (
                    SELECT COUNT(*) 
                    FROM public.student_class_assignments sca 
                    WHERE sca.section_id = s.id AND sca.status = 'ACTIVE'
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
                    WHERE cta.section_id = s.id
                    LIMIT 1
                ),
                'subjects_count', (
                    SELECT COUNT(DISTINCT csa.subject_id)
                    FROM public.class_subject_assignments csa
                    WHERE csa.section_id = s.id OR (csa.class_id = c.id AND csa.section_id IS NULL)
                ),
                'created_at', s.created_at,
                'updated_at', s.updated_at
            ) ORDER BY 
                CASE WHEN LOWER(p_sort_by) = 'name' AND UPPER(p_sort_order) = 'ASC' THEN s.name END ASC,
                CASE WHEN LOWER(p_sort_by) = 'name' AND UPPER(p_sort_order) = 'DESC' THEN s.name END DESC,
                CASE WHEN LOWER(p_sort_by) = 'class_name' AND UPPER(p_sort_order) = 'DESC' THEN c.name END DESC,
                c.display_order ASC,
                s.display_order ASC,
                s.name ASC
        ),
        '[]'::JSONB
    ) INTO v_sections
    FROM (
        SELECT s.*, c.name as class_name, c.code as class_code, c.display_order as class_order
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
        ORDER BY c.display_order ASC, s.display_order ASC, s.name ASC
        LIMIT p_page_size OFFSET v_offset
    ) s
    JOIN public.academic_classes c ON c.id = s.class_id;

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


-- Function: Create Standalone Academic Section
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
    v_academic_year VARCHAR(50);
    v_status VARCHAR(20);
    v_new_id UUID;
    v_class RECORD;
BEGIN
    v_class_id := (p_payload->>'class_id')::UUID;
    v_name := TRIM(COALESCE(p_payload->>'name', ''));
    v_code := UPPER(TRIM(COALESCE(p_payload->>'code', '')));
    v_capacity := COALESCE((p_payload->>'capacity')::INT, 40);
    v_room_number := TRIM(COALESCE(p_payload->>'room_number', ''));
    v_academic_year := TRIM(COALESCE(p_payload->>'academic_year', '2026-27'));
    v_status := UPPER(TRIM(COALESCE(p_payload->>'status', 'ACTIVE')));

    IF v_class_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Class is required', 'code', 400);
    END IF;

    IF v_name = '' THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Section name is required', 'code', 400);
    END IF;

    SELECT * INTO v_class
    FROM public.academic_classes
    WHERE id = v_class_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Selected class not found', 'code', 404);
    END IF;

    IF v_code = '' THEN
        v_code := UPPER(REGEXP_REPLACE(v_name, '[^a-zA-Z0-9]+', '', 'g'));
    END IF;

    -- Duplicate Check within same Class + Academic Year
    IF EXISTS (
        SELECT 1 FROM public.academic_sections 
        WHERE school_id = p_school_id 
          AND class_id = v_class_id 
          AND academic_year = v_academic_year 
          AND UPPER(name) = UPPER(v_name) 
          AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Section "' || v_name || '" already exists in ' || v_class.name, 'code', 409);
    END IF;

    INSERT INTO public.academic_sections (
        school_id, class_id, name, code, capacity, room_number, academic_year, status, created_by, updated_by
    ) VALUES (
        p_school_id, v_class_id, v_name, v_code, v_capacity, v_room_number, v_academic_year, v_status, p_user_id, p_user_id
    ) RETURNING id INTO v_new_id;

    PERFORM public.fn_record_class_audit(
        p_school_id, p_user_id, 'Create', 'Created Academic Section', v_name, 'SECTION', v_new_id,
        jsonb_build_object('class_name', v_class.name, 'name', v_name, 'code', v_code)
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Section created successfully',
        'data', jsonb_build_object(
            'id', v_new_id,
            'class_id', v_class_id,
            'name', v_name,
            'code', v_code,
            'capacity', v_capacity,
            'status', v_status
        )
    );
END;
$$;


-- Function: Update Academic Section
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
            'status', v_status
        )
    );
END;
$$;


-- Function: Archive / Delete Academic Section
CREATE OR REPLACE FUNCTION public.fn_archive_academic_section(
    p_school_id UUID,
    p_user_id UUID,
    p_section_id UUID,
    p_force_archive BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_curr RECORD;
    v_students_count INT := 0;
BEGIN
    SELECT * INTO v_curr
    FROM public.academic_sections
    WHERE id = p_section_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Section not found', 'code', 404);
    END IF;

    SELECT COUNT(*) INTO v_students_count
    FROM public.student_class_assignments
    WHERE section_id = p_section_id AND status = 'ACTIVE';

    IF v_students_count > 0 AND NOT p_force_archive THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'has_dependencies', TRUE,
            'error', 'This section contains ' || v_students_count::TEXT || ' active students. Please confirm archiving.',
            'students_count', v_students_count,
            'code', 400
        );
    END IF;

    UPDATE public.academic_sections SET
        status = 'ARCHIVED',
        deleted_at = NOW(),
        deleted_by = p_user_id,
        updated_at = NOW()
    WHERE id = p_section_id;

    PERFORM public.fn_record_class_audit(
        p_school_id, p_user_id, 'Archive', 'Archived Academic Section', v_curr.name, 'SECTION', p_section_id,
        jsonb_build_object('students_affected', v_students_count)
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Section archived successfully'
    );
END;
$$;


-- Function: Get Paginated Academic Subjects Catalog
CREATE OR REPLACE FUNCTION public.fn_get_academic_subjects(
    p_school_id UUID,
    p_search TEXT DEFAULT '',
    p_type VARCHAR DEFAULT 'ALL',
    p_status VARCHAR DEFAULT 'ALL',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_sort_by VARCHAR DEFAULT 'name',
    p_sort_order VARCHAR DEFAULT 'ASC'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_count INT := 0;
    v_offset INT;
    v_subjects JSONB;
BEGIN
    v_offset := (p_page - 1) * p_page_size;

    SELECT COUNT(*)
    INTO v_total_count
    FROM public.academic_subjects s
    WHERE s.school_id = p_school_id
      AND s.deleted_at IS NULL
      AND (p_type = 'ALL' OR s.type = p_type)
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
          OR s.type ILIKE '%' || p_search || '%'
      );

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', s.id,
                'name', s.name,
                'code', s.code,
                'type', s.type,
                'description', s.description,
                'periods_per_week', s.periods_per_week,
                'color', s.color,
                'icon', s.icon,
                'status', s.status,
                'classes_count', (
                    SELECT COUNT(DISTINCT csa.class_id)
                    FROM public.class_subject_assignments csa
                    WHERE csa.subject_id = s.id
                ),
                'sections_count', (
                    SELECT COUNT(DISTINCT csa.section_id)
                    FROM public.class_subject_assignments csa
                    WHERE csa.subject_id = s.id AND csa.section_id IS NOT NULL
                ),
                'created_at', s.created_at,
                'updated_at', s.updated_at
            ) ORDER BY 
                CASE WHEN LOWER(p_sort_by) = 'code' AND UPPER(p_sort_order) = 'ASC' THEN s.code END ASC,
                CASE WHEN LOWER(p_sort_by) = 'code' AND UPPER(p_sort_order) = 'DESC' THEN s.code END DESC,
                CASE WHEN LOWER(p_sort_by) = 'type' AND UPPER(p_sort_order) = 'ASC' THEN s.type END ASC,
                CASE WHEN LOWER(p_sort_by) = 'type' AND UPPER(p_sort_order) = 'DESC' THEN s.type END DESC,
                CASE WHEN LOWER(p_sort_by) = 'name' AND UPPER(p_sort_order) = 'DESC' THEN s.name END DESC,
                s.name ASC
        ),
        '[]'::JSONB
    ) INTO v_subjects
    FROM (
        SELECT *
        FROM public.academic_subjects s
        WHERE s.school_id = p_school_id
          AND s.deleted_at IS NULL
          AND (p_type = 'ALL' OR s.type = p_type)
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
              OR s.type ILIKE '%' || p_search || '%'
          )
        ORDER BY s.name ASC
        LIMIT p_page_size OFFSET v_offset
    ) s;

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


-- Function: Create Academic Subject
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
    v_name VARCHAR(150);
    v_code VARCHAR(50);
    v_type VARCHAR(50);
    v_desc TEXT;
    v_periods INT;
    v_color VARCHAR(50);
    v_icon VARCHAR(100);
    v_status VARCHAR(20);
    v_new_id UUID;
    v_class_ids JSONB;
    v_cls_id UUID;
BEGIN
    v_name := TRIM(COALESCE(p_payload->>'name', ''));
    v_code := UPPER(TRIM(COALESCE(p_payload->>'code', '')));
    v_type := TRIM(COALESCE(p_payload->>'type', 'Core'));
    v_desc := TRIM(COALESCE(p_payload->>'description', ''));
    v_periods := COALESCE((p_payload->>'periods_per_week')::INT, 5);
    v_color := TRIM(COALESCE(p_payload->>'color', '#4F46E5'));
    v_icon := TRIM(COALESCE(p_payload->>'icon', 'book'));
    v_status := UPPER(TRIM(COALESCE(p_payload->>'status', 'ACTIVE')));

    IF v_name = '' THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Subject name is required', 'code', 400);
    END IF;

    IF v_code = '' THEN
        v_code := UPPER(REGEXP_REPLACE(v_name, '[^a-zA-Z0-9]+', '', 'g'));
        IF LENGTH(v_code) > 6 THEN
            v_code := SUBSTRING(v_code FROM 1 FOR 6);
        END IF;
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.academic_subjects
        WHERE school_id = p_school_id AND UPPER(code) = v_code AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'A subject with code "' || v_code || '" already exists.', 'code', 409);
    END IF;

    INSERT INTO public.academic_subjects (
        school_id, name, code, type, description, periods_per_week, color, icon, status, created_by, updated_by
    ) VALUES (
        p_school_id, v_name, v_code, v_type, v_desc, v_periods, v_color, v_icon, v_status, p_user_id, p_user_id
    ) RETURNING id INTO v_new_id;

    -- Optional Assignment to Classes
    v_class_ids := COALESCE(p_payload->'class_ids', '[]'::JSONB);
    IF jsonb_typeof(v_class_ids) = 'array' AND jsonb_array_length(v_class_ids) > 0 THEN
        FOR v_cls_id IN SELECT (value->>0)::UUID FROM jsonb_array_elements(v_class_ids) value LOOP
            INSERT INTO public.class_subject_assignments (
                school_id, class_id, subject_id, periods_per_week
            ) VALUES (
                p_school_id, v_cls_id, v_new_id, v_periods
            ) ON CONFLICT DO NOTHING;
        END LOOP;
    END IF;

    PERFORM public.fn_record_class_audit(
        p_school_id, p_user_id, 'Create', 'Created Academic Subject', v_name, 'SUBJECT', v_new_id,
        jsonb_build_object('name', v_name, 'code', v_code, 'type', v_type)
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Subject created successfully',
        'data', jsonb_build_object(
            'id', v_new_id,
            'name', v_name,
            'code', v_code,
            'type', v_type,
            'status', v_status
        )
    );
END;
$$;


-- Function: Update Academic Subject
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
    v_curr RECORD;
    v_name VARCHAR(150);
    v_code VARCHAR(50);
    v_type VARCHAR(50);
    v_desc TEXT;
    v_periods INT;
    v_color VARCHAR(50);
    v_icon VARCHAR(100);
    v_status VARCHAR(20);
BEGIN
    SELECT * INTO v_curr
    FROM public.academic_subjects
    WHERE id = p_subject_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Subject not found', 'code', 404);
    END IF;

    v_name := TRIM(COALESCE(p_payload->>'name', v_curr.name));
    v_code := UPPER(TRIM(COALESCE(p_payload->>'code', v_curr.code)));
    v_type := TRIM(COALESCE(p_payload->>'type', v_curr.type));
    v_desc := TRIM(COALESCE(p_payload->>'description', v_curr.description));
    v_periods := COALESCE((p_payload->>'periods_per_week')::INT, v_curr.periods_per_week);
    v_color := TRIM(COALESCE(p_payload->>'color', v_curr.color));
    v_icon := TRIM(COALESCE(p_payload->>'icon', v_curr.icon));
    v_status := UPPER(TRIM(COALESCE(p_payload->>'status', v_curr.status)));

    IF v_code != v_curr.code AND EXISTS (
        SELECT 1 FROM public.academic_subjects
        WHERE school_id = p_school_id AND UPPER(code) = v_code AND id != p_subject_id AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Subject code "' || v_code || '" already in use', 'code', 409);
    END IF;

    UPDATE public.academic_subjects SET
        name = v_name,
        code = v_code,
        type = v_type,
        description = v_desc,
        periods_per_week = v_periods,
        color = v_color,
        icon = v_icon,
        status = v_status,
        updated_by = p_user_id,
        updated_at = NOW()
    WHERE id = p_subject_id;

    PERFORM public.fn_record_class_audit(
        p_school_id, p_user_id, 'Update', 'Updated Academic Subject', v_name, 'SUBJECT', p_subject_id,
        jsonb_build_object('name', v_name, 'code', v_code, 'type', v_type),
        to_jsonb(v_curr),
        jsonb_build_object('name', v_name, 'code', v_code, 'type', v_type)
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Subject updated successfully',
        'data', jsonb_build_object(
            'id', p_subject_id,
            'name', v_name,
            'code', v_code,
            'type', v_type,
            'status', v_status
        )
    );
END;
$$;


-- Function: Archive / Delete Academic Subject
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
BEGIN
    SELECT * INTO v_curr
    FROM public.academic_subjects
    WHERE id = p_subject_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Subject not found', 'code', 404);
    END IF;

    SELECT COUNT(DISTINCT class_id) INTO v_classes_count
    FROM public.class_subject_assignments
    WHERE subject_id = p_subject_id;

    IF v_classes_count > 0 AND NOT p_force_archive THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'has_dependencies', TRUE,
            'error', 'This subject is assigned to ' || v_classes_count::TEXT || ' classes. Please confirm archiving.',
            'classes_count', v_classes_count,
            'code', 400
        );
    END IF;

    UPDATE public.academic_subjects SET
        status = 'ARCHIVED',
        deleted_at = NOW(),
        deleted_by = p_user_id,
        updated_at = NOW()
    WHERE id = p_subject_id;

    DELETE FROM public.class_subject_assignments WHERE subject_id = p_subject_id;

    PERFORM public.fn_record_class_audit(
        p_school_id, p_user_id, 'Archive', 'Archived Academic Subject', v_curr.name, 'SUBJECT', p_subject_id,
        jsonb_build_object('classes_unlinked', v_classes_count)
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Subject archived successfully'
    );
END;
$$;


-- Function: Assign / Update Class Teachers (Multi-Teacher Supported)
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
          AND class_id = p_class_id
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
        p_school_id, p_user_id, 'Update', 'Assigned Class Teachers', p_class_id::TEXT, 'CLASS', p_class_id,
        jsonb_build_object('section_id', p_section_id, 'teacher_count', COALESCE(array_length(p_teacher_ids, 1), 0))
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Class teacher assigned successfully',
        'assigned_count', COALESCE(array_length(p_teacher_ids, 1), 0)
    );
END;
$$;


-- Function: Check Student Assignments & Detect Reassignment Conflicts
CREATE OR REPLACE FUNCTION public.fn_check_student_assignments(
    p_school_id UUID,
    p_student_ids UUID[],
    p_academic_year VARCHAR DEFAULT '2026-27'
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
      AND sca.status = 'ACTIVE';

    RETURN jsonb_build_object(
        'success', TRUE,
        'has_conflicts', (jsonb_array_length(v_conflicts) > 0),
        'conflicts', v_conflicts
    );
END;
$$;


-- Function: Assign Students to Class or Section (with Safe Move Support)
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

    -- Check if students have conflicting assignments
    IF NOT p_confirm_move THEN
        SELECT (public.fn_check_student_assignments(p_school_id, p_student_ids, p_academic_year))->'conflicts' 
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

    -- Reassign / Insert Students
    IF p_student_ids IS NOT NULL AND array_length(p_student_ids, 1) > 0 THEN
        FOREACH v_std_id IN ARRAY p_student_ids LOOP
            -- Delete old assignment for same academic year
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


-- Function: Manage Subjects Assigned to Class or Section
CREATE OR REPLACE FUNCTION public.fn_manage_class_subjects(
    p_school_id UUID,
    p_user_id UUID,
    p_class_id UUID,
    p_section_id UUID,
    p_subject_ids UUID[],
    p_academic_year VARCHAR DEFAULT '2026-27'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sub_id UUID;
    v_assigned_count INT := 0;
BEGIN
    -- Verify Class Exists
    IF NOT EXISTS (
        SELECT 1 FROM public.academic_classes 
        WHERE id = p_class_id AND school_id = p_school_id AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Class not found', 'code', 404);
    END IF;

    -- Clear existing subjects for this scope
    IF p_section_id IS NOT NULL THEN
        DELETE FROM public.class_subject_assignments
        WHERE school_id = p_school_id
          AND class_id = p_class_id
          AND section_id = p_section_id
          AND academic_year = p_academic_year;
    ELSE
        DELETE FROM public.class_subject_assignments
        WHERE school_id = p_school_id
          AND class_id = p_class_id
          AND section_id IS NULL
          AND academic_year = p_academic_year;
    END IF;

    -- Insert new subject assignments
    IF p_subject_ids IS NOT NULL AND array_length(p_subject_ids, 1) > 0 THEN
        FOREACH v_sub_id IN ARRAY p_subject_ids LOOP
            INSERT INTO public.class_subject_assignments (
                school_id, class_id, section_id, subject_id, academic_year
            ) VALUES (
                p_school_id, p_class_id, p_section_id, v_sub_id, p_academic_year
            ) ON CONFLICT DO NOTHING;

            v_assigned_count := v_assigned_count + 1;
        END LOOP;
    END IF;

    PERFORM public.fn_record_class_audit(
        p_school_id, p_user_id, 'Update', 'Managed Class Subjects', p_class_id::TEXT, 'CLASS', p_class_id,
        jsonb_build_object('section_id', p_section_id, 'subjects_assigned', v_assigned_count)
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Subjects assigned successfully',
        'assigned_count', v_assigned_count
    );
END;
$$;


-- Function: Search Teachers from User Management (profiles)
CREATE OR REPLACE FUNCTION public.fn_search_academic_teachers(
    p_school_id UUID,
    p_search TEXT DEFAULT '',
    p_limit INT DEFAULT 20
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
          AND LOWER(p.role) IN ('teacher', 'faculty', 'staff')
          AND (
              p_search = '' 
              OR p.full_name ILIKE '%' || p_search || '%' 
              OR p.email ILIKE '%' || p_search || '%'
              OR p.employee_id ILIKE '%' || p_search || '%'
              OR p.department ILIKE '%' || p_search || '%'
          )
        LIMIT p_limit
    ) p;

    RETURN jsonb_build_object('success', TRUE, 'data', v_teachers);
END;
$$;


-- Function: Search Students from User Management (profiles) with Assignment Info
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
    LEFT JOIN public.academic_sections s ON s.id = sca.section_id;

    RETURN jsonb_build_object('success', TRUE, 'data', v_students);
END;
$$;


-- ============================================================================
-- SEED DATA FOR EXISTING SCHOOLS
-- ============================================================================

DO $$
DECLARE
    s RECORD;
    admin_id UUID;
    v_cls_id UUID;
    v_sub_id UUID;
    v_teacher_id UUID;
BEGIN
    FOR s IN SELECT id FROM public.schools LOOP
        SELECT id INTO admin_id FROM public.profiles WHERE school_id = s.id LIMIT 1;
        SELECT id INTO v_teacher_id FROM public.profiles WHERE school_id = s.id AND LOWER(role) = 'teacher' LIMIT 1;

        -- 1. Seed Academic Subjects
        INSERT INTO public.academic_subjects (school_id, name, code, type, periods_per_week, color, created_by)
        VALUES 
            (s.id, 'English', 'ENG', 'Core', 5, '#4F46E5', admin_id),
            (s.id, 'Mathematics', 'MATH', 'Core', 6, '#06B6D4', admin_id),
            (s.id, 'Science', 'SCI', 'Core', 6, '#10B981', admin_id),
            (s.id, 'Social Science', 'SST', 'Core', 5, '#F59E0B', admin_id),
            (s.id, 'Hindi', 'HIN', 'Language', 4, '#EC4899', admin_id),
            (s.id, 'Computer Science', 'COMP', 'Elective', 2, '#8B5CF6', admin_id),
            (s.id, 'Physical Education', 'PE', 'Practical', 2, '#64748B', admin_id)
        ON CONFLICT (school_id, UPPER(code)) WHERE deleted_at IS NULL DO NOTHING;

        -- 2. Seed Academic Classes (Class 5 to Class 12)
        -- Class 9
        INSERT INTO public.academic_classes (school_id, name, code, stage, academic_year, display_order, status, created_by)
        VALUES (s.id, 'Class 9', 'CL-09', 'Secondary', '2026-27', 9, 'ACTIVE', admin_id)
        ON CONFLICT (school_id, academic_year, UPPER(code)) WHERE deleted_at IS NULL DO NOTHING;

        SELECT id INTO v_cls_id FROM public.academic_classes WHERE school_id = s.id AND code = 'CL-09' AND deleted_at IS NULL;
        IF v_cls_id IS NOT NULL THEN
            -- Sections 9-A, 9-B, 9-C, 9-D
            INSERT INTO public.academic_sections (school_id, class_id, name, code, capacity, academic_year, display_order, created_by)
            VALUES 
                (s.id, v_cls_id, '9-A', '9A', 40, '2026-27', 1, admin_id),
                (s.id, v_cls_id, '9-B', '9B', 40, '2026-27', 2, admin_id),
                (s.id, v_cls_id, '9-C', '9C', 40, '2026-27', 3, admin_id),
                (s.id, v_cls_id, '9-D', '9D', 40, '2026-27', 4, admin_id)
            ON CONFLICT DO NOTHING;

            -- Assign Subjects to Class 9
            FOR v_sub_id IN SELECT id FROM public.academic_subjects WHERE school_id = s.id LOOP
                INSERT INTO public.class_subject_assignments (school_id, class_id, subject_id, academic_year)
                VALUES (s.id, v_cls_id, v_sub_id, '2026-27')
                ON CONFLICT DO NOTHING;
            END LOOP;

            -- Assign Class Teacher
            IF v_teacher_id IS NOT NULL THEN
                INSERT INTO public.class_teacher_assignments (school_id, class_id, teacher_id, academic_year, is_primary)
                VALUES (s.id, v_cls_id, v_teacher_id, '2026-27', TRUE)
                ON CONFLICT DO NOTHING;
            END IF;
        END IF;

        -- Class 10
        INSERT INTO public.academic_classes (school_id, name, code, stage, academic_year, display_order, status, created_by)
        VALUES (s.id, 'Class 10', 'CL-10', 'Secondary', '2026-27', 10, 'ACTIVE', admin_id)
        ON CONFLICT (school_id, academic_year, UPPER(code)) WHERE deleted_at IS NULL DO NOTHING;

        SELECT id INTO v_cls_id FROM public.academic_classes WHERE school_id = s.id AND code = 'CL-10' AND deleted_at IS NULL;
        IF v_cls_id IS NOT NULL THEN
            INSERT INTO public.academic_sections (school_id, class_id, name, code, capacity, academic_year, display_order, created_by)
            VALUES 
                (s.id, v_cls_id, '10-A', '10A', 40, '2026-27', 1, admin_id),
                (s.id, v_cls_id, '10-B', '10B', 40, '2026-27', 2, admin_id),
                (s.id, v_cls_id, '10-C', '10C', 40, '2026-27', 3, admin_id),
                (s.id, v_cls_id, '10-D', '10D', 40, '2026-27', 4, admin_id)
            ON CONFLICT DO NOTHING;

            FOR v_sub_id IN SELECT id FROM public.academic_subjects WHERE school_id = s.id LOOP
                INSERT INTO public.class_subject_assignments (school_id, class_id, subject_id, academic_year)
                VALUES (s.id, v_cls_id, v_sub_id, '2026-27')
                ON CONFLICT DO NOTHING;
            END LOOP;
        END IF;

        -- Class 11 & Class 12
        INSERT INTO public.academic_classes (school_id, name, code, stage, academic_year, display_order, status, created_by)
        VALUES 
            (s.id, 'Class 11', 'CL-11', 'Senior Secondary', '2026-27', 11, 'ACTIVE', admin_id),
            (s.id, 'Class 12', 'CL-12', 'Senior Secondary', '2026-27', 12, 'ACTIVE', admin_id),
            (s.id, 'Class 8', 'CL-08', 'Secondary', '2026-27', 8, 'ACTIVE', admin_id),
            (s.id, 'Class 7', 'CL-07', 'Middle School', '2026-27', 7, 'ACTIVE', admin_id),
            (s.id, 'Class 6', 'CL-06', 'Middle School', '2026-27', 6, 'ACTIVE', admin_id),
            (s.id, 'Class 5', 'CL-05', 'Primary', '2026-27', 5, 'ACTIVE', admin_id)
        ON CONFLICT DO NOTHING;
    END LOOP;
END;
$$;
