-- Migration 567: Fix sp_resolve_target_assignees to return complete class & section rosters accurately
-- 1. For STUDENT audience in CLASS_SECTION mode:
--    When section has enrollments in student_class_assignments, return all enrolled students.
--    Avoid filtering out enrolled students whose profile role might be auxiliary or unupdated.
--    Return dynamic class_name with section (e.g. 'Class 5 (5-B)') instead of stale profile text (e.g. 'Class 10').
-- 2. For TEACHER audience in CLASS_SECTION mode:
--    Return assigned teachers via class_teacher_assignments or section_subject_teachers.
--    If none assigned, return empty set.

CREATE OR REPLACE FUNCTION public.sp_resolve_target_assignees(
    p_school_id UUID,
    p_assignment_mode VARCHAR,
    p_target_role VARCHAR DEFAULT NULL,
    p_class_id UUID DEFAULT NULL,
    p_class_name VARCHAR DEFAULT NULL,
    p_section_id UUID DEFAULT NULL,
    p_section_name VARCHAR DEFAULT NULL,
    p_department VARCHAR DEFAULT NULL,
    p_search_query VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    full_name VARCHAR,
    role VARCHAR,
    email VARCHAR,
    avatar_url TEXT,
    department VARCHAR,
    class_name VARCHAR,
    roll_number VARCHAR
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_clean_class VARCHAR;
    v_clean_sec VARCHAR;
    v_is_teacher BOOLEAN;
    v_has_sca BOOLEAN := FALSE;
BEGIN
    -- Extract clean number/code for class matching (e.g. 'Class 10' -> '10', 'Grade 10' -> '10')
    IF p_class_name IS NOT NULL THEN
        v_clean_class := TRIM(REGEXP_REPLACE(p_class_name, '^(Class|Grade)\s*', '', 'i'));
    END IF;

    IF p_section_name IS NOT NULL THEN
        v_clean_sec := TRIM(REGEXP_REPLACE(p_section_name, '^.*\s*-\s*', ''));
        IF v_clean_sec ILIKE '%All%' THEN
            v_clean_sec := NULL;
        END IF;
    END IF;

    v_is_teacher := (p_target_role IS NOT NULL AND LOWER(p_target_role) = 'teacher');

    IF UPPER(p_assignment_mode) = 'ROLE' THEN
        RETURN QUERY
        SELECT
            p.id,
            p.full_name::VARCHAR,
            p.role::VARCHAR,
            p.email::VARCHAR,
            p.avatar_url,
            p.department::VARCHAR,
            p.class::VARCHAR as class_name,
            p.roll_number::VARCHAR
        FROM public.profiles p
        WHERE p.school_id = p_school_id
          AND (p_target_role IS NULL OR p_target_role = 'All' OR LOWER(p.role) = LOWER(p_target_role))
          AND (p_department IS NULL OR p_department = 'All' OR p.department ILIKE '%' || p_department || '%')
          AND (
            p_search_query IS NULL 
            OR p.full_name ILIKE '%' || p_search_query || '%'
            OR p.email ILIKE '%' || p_search_query || '%'
            OR p.roll_number::TEXT ILIKE '%' || p_search_query || '%'
          )
        ORDER BY p.role ASC, p.full_name ASC;

    ELSIF UPPER(p_assignment_mode) = 'CLASS_SECTION' THEN
        IF v_is_teacher THEN
            -- TEACHER AUDIENCE: ONLY return teachers assigned to this class and section
            RETURN QUERY
            SELECT DISTINCT
                p.id,
                p.full_name::VARCHAR,
                'TEACHER'::VARCHAR AS role,
                p.email::VARCHAR,
                p.avatar_url,
                p.department::VARCHAR,
                COALESCE(c.name || ' (' || s.name || ')', p_class_name, p.class, '')::VARCHAR as class_name,
                p.roll_number::VARCHAR
            FROM public.profiles p
            LEFT JOIN public.academic_classes c ON c.id = p_class_id
            LEFT JOIN public.academic_sections s ON s.id = p_section_id
            WHERE p.school_id = p_school_id
              AND LOWER(p.role) = 'teacher'
              AND (
                -- Class/Section Teacher Assignments
                p.id IN (
                    SELECT cta.teacher_id 
                    FROM public.class_teacher_assignments cta
                    WHERE cta.school_id = p_school_id
                      AND (p_class_id IS NULL OR cta.class_id = p_class_id)
                      AND (
                        p_section_id IS NULL 
                        OR cta.section_id = p_section_id 
                        OR (cta.section_id IS NULL AND NOT EXISTS (
                            SELECT 1 FROM public.class_teacher_assignments cta2 
                            WHERE cta2.school_id = p_school_id AND cta2.section_id = p_section_id
                        ))
                      )
                )
                -- Section Subject Teachers
                OR p.id IN (
                    SELECT sst.teacher_id 
                    FROM public.section_subject_teachers sst
                    WHERE sst.school_id = p_school_id
                      AND (p_class_id IS NULL OR sst.class_id = p_class_id)
                      AND (p_section_id IS NULL OR sst.section_id = p_section_id OR sst.section_id IS NULL)
                )
              )
              AND (
                p_search_query IS NULL 
                OR p.full_name ILIKE '%' || p_search_query || '%'
                OR p.email ILIKE '%' || p_search_query || '%'
              )
            ORDER BY 2 ASC;
        ELSE
            -- STUDENT AUDIENCE: Return all enrolled students for the specific class and section
            SELECT EXISTS (
                SELECT 1 FROM public.student_class_assignments sca_chk
                WHERE sca_chk.school_id = p_school_id
                  AND (p_class_id IS NULL OR sca_chk.class_id = p_class_id)
                  AND (p_section_id IS NULL OR sca_chk.section_id = p_section_id)
                  AND (sca_chk.status = 'ACTIVE' OR sca_chk.status IS NULL)
            ) INTO v_has_sca;

            IF v_has_sca THEN
                RETURN QUERY
                SELECT DISTINCT
                    p.id,
                    p.full_name::VARCHAR,
                    'STUDENT'::VARCHAR AS role,
                    p.email::VARCHAR,
                    p.avatar_url,
                    p.department::VARCHAR,
                    COALESCE(c.name || ' (' || s.name || ')', p_class_name, p.class, '')::VARCHAR as class_name,
                    COALESCE(sca.roll_number::VARCHAR, p.roll_number::TEXT, '')::VARCHAR as roll_number
                FROM public.student_class_assignments sca
                JOIN public.profiles p ON p.id = sca.student_id
                LEFT JOIN public.academic_classes c ON c.id = sca.class_id
                LEFT JOIN public.academic_sections s ON s.id = sca.section_id
                WHERE sca.school_id = p_school_id
                  AND (p_class_id IS NULL OR sca.class_id = p_class_id)
                  AND (p_section_id IS NULL OR sca.section_id = p_section_id)
                  AND (sca.status = 'ACTIVE' OR sca.status IS NULL)
                  AND (
                    p_search_query IS NULL 
                    OR p.full_name ILIKE '%' || p_search_query || '%'
                    OR p.email ILIKE '%' || p_search_query || '%'
                    OR p.roll_number::TEXT ILIKE '%' || p_search_query || '%'
                    OR sca.roll_number::TEXT ILIKE '%' || p_search_query || '%'
                  )
                ORDER BY 2 ASC;
            ELSE
                -- Fallback for legacy setups where enrollments are tracked via profiles.class text
                RETURN QUERY
                SELECT DISTINCT
                    p.id,
                    p.full_name::VARCHAR,
                    'STUDENT'::VARCHAR AS role,
                    p.email::VARCHAR,
                    p.avatar_url,
                    p.department::VARCHAR,
                    COALESCE(p_class_name, p.class, '')::VARCHAR as class_name,
                    COALESCE(p.roll_number::TEXT, '')::VARCHAR as roll_number
                FROM public.profiles p
                WHERE p.school_id = p_school_id
                  AND LOWER(p.role) = 'student'
                  AND (
                    (
                        (v_clean_class IS NOT NULL AND p.class ILIKE '%' || v_clean_class || '%')
                        OR (p_class_name IS NOT NULL AND p.class ILIKE '%' || p_class_name || '%')
                    )
                    AND (
                        v_clean_sec IS NULL 
                        OR p.class ILIKE '%' || v_clean_sec || '%'
                        OR (p_section_name IS NOT NULL AND p.class ILIKE '%' || p_section_name || '%')
                    )
                  )
                  AND (
                    p_search_query IS NULL 
                    OR p.full_name ILIKE '%' || p_search_query || '%'
                    OR p.email ILIKE '%' || p_search_query || '%'
                    OR p.roll_number::TEXT ILIKE '%' || p_search_query || '%'
                  )
                ORDER BY 2 ASC;
            END IF;
        END IF;

    ELSE -- 'INDIVIDUAL'
        RETURN QUERY
        SELECT
            p.id,
            p.full_name::VARCHAR,
            p.role::VARCHAR,
            p.email::VARCHAR,
            p.avatar_url,
            p.department::VARCHAR,
            p.class::VARCHAR as class_name,
            p.roll_number::VARCHAR
        FROM public.profiles p
        WHERE p.school_id = p_school_id
          AND (p_target_role IS NULL OR p_target_role = 'All' OR LOWER(p.role) = LOWER(p_target_role))
          AND (p_department IS NULL OR p_department = 'All' OR p.department ILIKE '%' || p_department || '%')
          AND (
            p_search_query IS NULL 
            OR p.full_name ILIKE '%' || p_search_query || '%'
            OR p.email ILIKE '%' || p_search_query || '%'
            OR p.roll_number::TEXT ILIKE '%' || p_search_query || '%'
          )
        ORDER BY 
            CASE 
                WHEN LOWER(p.role) = 'admin' OR LOWER(p.role) = 'super_admin' THEN 1
                WHEN LOWER(p.role) = 'teacher' THEN 2
                WHEN LOWER(p.role) = 'student' THEN 3
                ELSE 4
            END,
            p.full_name ASC;
    END IF;
END;
$$;
