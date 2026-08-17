-- ============================================================================
-- Migration: 267_teacher_scoped_classes.sql
-- Description: Scopes academic classes, sections, subjects & stats to assigned teachers
-- ============================================================================

-- 1. Function: Get Academic Statistics (Scoped to Teacher if p_teacher_id provided)
CREATE OR REPLACE FUNCTION public.fn_get_academic_stats(
    p_school_id UUID,
    p_academic_year VARCHAR DEFAULT '2026-27',
    p_teacher_id UUID DEFAULT NULL
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
    -- Classes count
    SELECT COUNT(*), COUNT(*) FILTER (WHERE c.status = 'ACTIVE')
    INTO v_total_classes, v_active_classes
    FROM public.academic_classes c
    WHERE c.school_id = p_school_id 
      AND c.academic_year = p_academic_year 
      AND c.deleted_at IS NULL
      AND (
          p_teacher_id IS NULL
          OR EXISTS (
              SELECT 1 FROM public.class_teacher_assignments cta
              WHERE cta.teacher_id = p_teacher_id
                AND cta.class_id = c.id
                AND cta.academic_year = p_academic_year
          )
      );

    -- Sections count
    SELECT COUNT(*)
    INTO v_total_sections
    FROM public.academic_sections s
    JOIN public.academic_classes c ON c.id = s.class_id
    WHERE s.school_id = p_school_id 
      AND s.academic_year = p_academic_year 
      AND s.deleted_at IS NULL
      AND (
          p_teacher_id IS NULL
          OR EXISTS (
              SELECT 1 FROM public.class_teacher_assignments cta
              WHERE cta.teacher_id = p_teacher_id
                AND (cta.section_id = s.id OR (cta.class_id = s.class_id AND cta.section_id IS NULL))
                AND cta.academic_year = p_academic_year
          )
      );

    -- Subjects count
    SELECT COUNT(DISTINCT s.id)
    INTO v_total_subjects
    FROM public.academic_subjects s
    WHERE s.school_id = p_school_id 
      AND s.deleted_at IS NULL
      AND (
          p_teacher_id IS NULL
          OR EXISTS (
              SELECT 1 FROM public.class_subject_assignments csa
              JOIN public.class_teacher_assignments cta ON cta.class_id = csa.class_id
              WHERE cta.teacher_id = p_teacher_id
                AND csa.subject_id = s.id
                AND cta.academic_year = p_academic_year
          )
      );

    -- Students count
    SELECT COUNT(DISTINCT sca.student_id)
    INTO v_total_students
    FROM public.student_class_assignments sca
    WHERE sca.school_id = p_school_id 
      AND sca.academic_year = p_academic_year 
      AND sca.status = 'ACTIVE'
      AND (
          p_teacher_id IS NULL
          OR EXISTS (
              SELECT 1 FROM public.class_teacher_assignments cta
              WHERE cta.teacher_id = p_teacher_id
                AND (
                    (cta.section_id IS NOT NULL AND cta.section_id = sca.section_id)
                    OR (cta.section_id IS NULL AND cta.class_id = sca.class_id)
                )
                AND cta.academic_year = p_academic_year
          )
      );

    -- Teachers count
    IF p_teacher_id IS NOT NULL THEN
        v_total_teachers := 1;
    ELSE
        SELECT COUNT(DISTINCT teacher_id)
        INTO v_total_teachers
        FROM public.class_teacher_assignments
        WHERE school_id = p_school_id 
          AND academic_year = p_academic_year;
    END IF;

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


-- 2. Function: Get Paginated Academic Classes (Scoped to Teacher if p_teacher_id provided)
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
                      AND (
                          p_teacher_id IS NULL
                          OR EXISTS (
                              SELECT 1 FROM public.class_teacher_assignments cta
                              WHERE cta.teacher_id = p_teacher_id
                                AND (
                                    (cta.section_id IS NOT NULL AND cta.section_id = sca.section_id)
                                    OR (cta.section_id IS NULL AND cta.class_id = sca.class_id)
                                )
                                AND cta.academic_year = p_academic_year
                          )
                      )
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


-- 3. Function: Get Full Details of a Specific Class (Teacher Guarded)
CREATE OR REPLACE FUNCTION public.fn_get_academic_class_detail(
    p_school_id UUID,
    p_class_id UUID,
    p_teacher_id UUID DEFAULT NULL
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
    v_is_assigned BOOLEAN := TRUE;
BEGIN
    SELECT * INTO v_class
    FROM public.academic_classes
    WHERE id = p_class_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Class not found', 'code', 404);
    END IF;

    -- If teacher_id is provided, verify that the teacher is assigned to this class
    IF p_teacher_id IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1 FROM public.class_teacher_assignments cta
            WHERE cta.teacher_id = p_teacher_id
              AND cta.class_id = p_class_id
        ) INTO v_is_assigned;

        IF NOT v_is_assigned THEN
            RETURN jsonb_build_object('success', FALSE, 'error', 'Unauthorized: You are not assigned to this class', 'code', 403);
        END IF;
    END IF;

    -- Fetch Sections (filtered if teacher has specific section assignment)
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
    WHERE s.class_id = p_class_id
      AND (
          p_teacher_id IS NULL
          OR EXISTS (
              SELECT 1 FROM public.class_teacher_assignments cta
              WHERE cta.teacher_id = p_teacher_id
                AND (cta.section_id = s.id OR (cta.class_id = s.class_id AND cta.section_id IS NULL))
          )
      );

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
    WHERE csa.class_id = p_class_id;

    -- Fetch Teachers assigned directly to class
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', p.id,
                'full_name', p.full_name,
                'email', p.email,
                'avatar_url', p.avatar_url,
                'employee_id', p.employee_id,
                'is_primary', cta.is_primary
            ) ORDER BY cta.is_primary DESC, cta.created_at ASC
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


-- 4. Function: Get Paginated Sections Across Classes (Scoped to Teacher if p_teacher_id provided)
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
    v_offset := (p_page - 1) * p_page_size;

    SELECT COUNT(*)
    INTO v_total_count
    FROM public.academic_sections s
    JOIN public.academic_classes c ON c.id = s.class_id
    WHERE s.school_id = p_school_id
      AND s.academic_year = p_academic_year
      AND (p_class_id IS NULL OR s.class_id = p_class_id)
      AND (
          (p_status = 'ALL' AND s.deleted_at IS NULL AND s.status != 'ARCHIVED')
          OR (p_status = 'ACTIVE' AND s.status = 'ACTIVE' AND s.deleted_at IS NULL)
          OR (p_status = 'INACTIVE' AND s.status = 'INACTIVE' AND s.deleted_at IS NULL)
          OR (p_status = 'ARCHIVED' AND (s.status = 'ARCHIVED' OR s.deleted_at IS NOT NULL))
      )
      AND (
          p_teacher_id IS NULL
          OR EXISTS (
              SELECT 1 FROM public.class_teacher_assignments cta
              WHERE cta.teacher_id = p_teacher_id
                AND (cta.section_id = s.id OR (cta.class_id = s.class_id AND cta.section_id IS NULL))
                AND cta.academic_year = p_academic_year
          )
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
          AND (p_class_id IS NULL OR s.class_id = p_class_id)
          AND (
              (p_status = 'ALL' AND s.deleted_at IS NULL AND s.status != 'ARCHIVED')
              OR (p_status = 'ACTIVE' AND s.status = 'ACTIVE' AND s.deleted_at IS NULL)
              OR (p_status = 'INACTIVE' AND s.status = 'INACTIVE' AND s.deleted_at IS NULL)
              OR (p_status = 'ARCHIVED' AND (s.status = 'ARCHIVED' OR s.deleted_at IS NOT NULL))
          )
          AND (
              p_teacher_id IS NULL
              OR EXISTS (
                  SELECT 1 FROM public.class_teacher_assignments cta
                  WHERE cta.teacher_id = p_teacher_id
                    AND (cta.section_id = s.id OR (cta.class_id = s.class_id AND cta.section_id IS NULL))
                    AND cta.academic_year = p_academic_year
              )
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


-- 5. Function: Get Paginated Subjects Catalog (Scoped to Teacher if p_teacher_id provided)
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
      AND (p_type = 'ALL' OR s.type = p_type)
      AND (
          (p_status = 'ALL' AND s.deleted_at IS NULL AND s.status != 'ARCHIVED')
          OR (p_status = 'ACTIVE' AND s.status = 'ACTIVE' AND s.deleted_at IS NULL)
          OR (p_status = 'INACTIVE' AND s.status = 'INACTIVE' AND s.deleted_at IS NULL)
          OR (p_status = 'ARCHIVED' AND (s.status = 'ARCHIVED' OR s.deleted_at IS NOT NULL))
      )
      AND (
          p_teacher_id IS NULL
          OR EXISTS (
              SELECT 1 FROM public.class_subject_assignments csa
              JOIN public.class_teacher_assignments cta ON cta.class_id = csa.class_id
              WHERE cta.teacher_id = p_teacher_id
                AND csa.subject_id = s.id
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
                      AND (
                          p_teacher_id IS NULL
                          OR EXISTS (
                              SELECT 1 FROM public.class_teacher_assignments cta
                              WHERE cta.teacher_id = p_teacher_id
                                AND cta.class_id = csa.class_id
                          )
                      )
                ),
                'sections_count', (
                    SELECT COUNT(DISTINCT csa.section_id)
                    FROM public.class_subject_assignments csa
                    WHERE csa.subject_id = s.id AND csa.section_id IS NOT NULL
                      AND (
                          p_teacher_id IS NULL
                          OR EXISTS (
                              SELECT 1 FROM public.class_teacher_assignments cta
                              WHERE cta.teacher_id = p_teacher_id
                                AND (cta.section_id = csa.section_id OR (cta.class_id = csa.class_id AND cta.section_id IS NULL))
                          )
                      )
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
          AND (p_type = 'ALL' OR s.type = p_type)
          AND (
              (p_status = 'ALL' AND s.deleted_at IS NULL AND s.status != 'ARCHIVED')
              OR (p_status = 'ACTIVE' AND s.status = 'ACTIVE' AND s.deleted_at IS NULL)
              OR (p_status = 'INACTIVE' AND s.status = 'INACTIVE' AND s.deleted_at IS NULL)
              OR (p_status = 'ARCHIVED' AND (s.status = 'ARCHIVED' OR s.deleted_at IS NOT NULL))
          )
          AND (
              p_teacher_id IS NULL
              OR EXISTS (
                  SELECT 1 FROM public.class_subject_assignments csa
                  JOIN public.class_teacher_assignments cta ON cta.class_id = csa.class_id
                  WHERE cta.teacher_id = p_teacher_id
                    AND csa.subject_id = s.id
              )
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
