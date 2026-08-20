-- ============================================================================
-- Migration: 273_enhance_academic_uniqueness_and_views.sql
-- Description: Strict Unique Code Constraints (Class, Section, Subject),
--              Composite Offering Uniqueness (Class Code + Section Code + Subject Code),
--              and High-Performance Enriched Views for Master-Detail Screens.
-- Scoped: Multi-tenant (school_id), Academic Year, RBAC & Audit-Ready
-- ============================================================================

-- 1. Ensure Unique Constraints on Individual Entity Codes
CREATE UNIQUE INDEX IF NOT EXISTS uq_academic_classes_school_code 
    ON public.academic_classes (school_id, academic_year, UPPER(code)) 
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_academic_sections_school_class_code 
    ON public.academic_sections (school_id, class_id, academic_year, UPPER(code)) 
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_academic_subjects_school_code 
    ON public.academic_subjects (school_id, UPPER(code)) 
    WHERE deleted_at IS NULL;

-- 2. Composite Uniqueness for Class + Section + Subject Offerings
CREATE UNIQUE INDEX IF NOT EXISTS uq_class_section_subject_offering
    ON public.class_subject_assignments (
        school_id, 
        academic_year, 
        class_id, 
        COALESCE(section_id, '00000000-0000-0000-0000-000000000000'::UUID), 
        subject_id
    );

-- 3. Composite Uniqueness for Section Subject Faculty Assignment
CREATE UNIQUE INDEX IF NOT EXISTS uq_section_subject_faculty_assignment
    ON public.section_subject_teachers (
        school_id, 
        academic_year, 
        section_id, 
        subject_id, 
        teacher_id
    );

-- 4. Composite Uniqueness for Student Class + Section + Subject Enrollment
CREATE UNIQUE INDEX IF NOT EXISTS uq_student_section_subject_enrollment
    ON public.student_subject_enrollments (
        school_id, 
        academic_year, 
        section_id, 
        subject_id, 
        student_id
    );


-- ============================================================================
-- 5. FUNCTION: Get Enriched Class Full Detail (For Master-Detail View)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_get_class_full_detail(
    p_school_id UUID,
    p_class_id UUID,
    p_academic_year VARCHAR DEFAULT '2026-27'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_class RECORD;
    v_sections JSONB := '[]'::JSONB;
    v_subjects JSONB := '[]'::JSONB;
    v_class_teacher JSONB := NULL;
    v_total_capacity INT := 0;
    v_total_students INT := 0;
    v_core_count INT := 0;
    v_optional_count INT := 0;
BEGIN
    -- Fetch Class Info
    SELECT * INTO v_class
    FROM public.academic_classes
    WHERE id = p_class_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Class not found');
    END IF;

    -- Class Teacher
    SELECT jsonb_build_object(
        'id', p.id,
        'full_name', p.full_name,
        'email', p.email,
        'avatar_url', p.avatar_url,
        'subject', COALESCE(p.department, 'Class Teacher')
    ) INTO v_class_teacher
    FROM public.class_teacher_assignments cta
    JOIN public.profiles p ON p.id = cta.teacher_id
    WHERE cta.class_id = p_class_id 
      AND cta.section_id IS NULL 
      AND cta.academic_year = p_academic_year
    LIMIT 1;

    -- Sections in this Class
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', s.id,
                'name', s.name,
                'code', s.code,
                'capacity', s.capacity,
                'students_count', (
                    SELECT COUNT(*) 
                    FROM public.student_class_assignments sca 
                    WHERE sca.section_id = s.id AND sca.academic_year = p_academic_year AND sca.status = 'ACTIVE'
                ),
                'class_teacher', (
                    SELECT jsonb_build_object(
                        'id', p.id,
                        'full_name', p.full_name,
                        'avatar_url', p.avatar_url,
                        'subject', COALESCE(p.department, 'Teacher')
                    )
                    FROM public.class_teacher_assignments cta2
                    JOIN public.profiles p ON p.id = cta2.teacher_id
                    WHERE cta2.section_id = s.id AND cta2.academic_year = p_academic_year
                    LIMIT 1
                ),
                'optional_subjects_count', (
                    SELECT COUNT(DISTINCT csa.subject_id)
                    FROM public.class_subject_assignments csa
                    JOIN public.academic_subjects sub ON sub.id = csa.subject_id
                    WHERE (csa.section_id = s.id OR (csa.class_id = p_class_id AND csa.section_id IS NULL))
                      AND sub.type IN ('Elective', 'Optional')
                      AND sub.deleted_at IS NULL
                ),
                'status', s.status
            ) ORDER BY s.display_order ASC, s.name ASC
        ),
        '[]'::JSONB
    ) INTO v_sections
    FROM public.academic_sections s
    WHERE s.class_id = p_class_id AND s.school_id = p_school_id AND s.deleted_at IS NULL;

    -- Total Capacity and Students Count
    SELECT 
        COALESCE(SUM(s.capacity), 0),
        (
            SELECT COUNT(*) 
            FROM public.student_class_assignments sca 
            WHERE sca.class_id = p_class_id AND sca.academic_year = p_academic_year AND sca.status = 'ACTIVE'
        )
    INTO v_total_capacity, v_total_students
    FROM public.academic_sections s
    WHERE s.class_id = p_class_id AND s.school_id = p_school_id AND s.deleted_at IS NULL;

    -- Subjects in this Class with Teachers by Section
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', sub.id,
                'name', sub.name,
                'code', sub.code,
                'type', sub.type,
                'offered_as', CASE WHEN sub.type IN ('Elective', 'Optional') THEN 'Offered by Section' ELSE 'All Sections' END,
                'periods_per_week', sub.periods_per_week,
                'status', sub.status,
                'assigned_sections_count', (
                    SELECT COUNT(*)
                    FROM public.academic_sections s
                    WHERE s.class_id = p_class_id AND s.deleted_at IS NULL
                ),
                'assigned_teachers', (
                    SELECT COALESCE(
                        jsonb_agg(
                            jsonb_build_object(
                                'id', p.id,
                                'full_name', p.full_name,
                                'avatar_url', p.avatar_url,
                                'section_id', sst.section_id,
                                'section_name', sec.name
                            )
                        ),
                        '[]'::JSONB
                    )
                    FROM public.section_subject_teachers sst
                    JOIN public.profiles p ON p.id = sst.teacher_id
                    JOIN public.academic_sections sec ON sec.id = sst.section_id
                    WHERE sst.class_id = p_class_id 
                      AND sst.subject_id = sub.id 
                      AND sst.academic_year = p_academic_year
                )
            ) ORDER BY sub.type ASC, sub.name ASC
        ),
        '[]'::JSONB
    ) INTO v_subjects
    FROM public.academic_subjects sub
    WHERE sub.deleted_at IS NULL
      AND (
          EXISTS (
              SELECT 1 FROM public.class_subject_assignments csa
              WHERE csa.class_id = p_class_id AND csa.subject_id = sub.id AND csa.academic_year = p_academic_year
          )
          OR sub.school_id = p_school_id
      );

    -- Subject Counts
    SELECT 
        COUNT(*) FILTER (WHERE sub.type NOT IN ('Elective', 'Optional')),
        COUNT(*) FILTER (WHERE sub.type IN ('Elective', 'Optional'))
    INTO v_core_count, v_optional_count
    FROM public.academic_subjects sub
    WHERE sub.deleted_at IS NULL
      AND (
          EXISTS (
              SELECT 1 FROM public.class_subject_assignments csa
              WHERE csa.class_id = p_class_id AND csa.subject_id = sub.id AND csa.academic_year = p_academic_year
          )
          OR sub.school_id = p_school_id
      );

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'id', v_class.id,
            'name', v_class.name,
            'code', v_class.code,
            'stage', v_class.stage,
            'academic_year', v_class.academic_year,
            'status', v_class.status,
            'total_sections', jsonb_array_length(v_sections),
            'total_students', v_total_students,
            'total_capacity', v_total_capacity,
            'core_subjects_count', v_core_count,
            'optional_subjects_count', v_optional_count,
            'total_subjects_count', (v_core_count + v_optional_count),
            'class_teacher', v_class_teacher,
            'sections', v_sections,
            'subjects', v_subjects
        )
    );
END;
$$;


-- ============================================================================
-- 6. FUNCTION: Get Sections Overview & Analytics (For Sections Management Tab)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_get_sections_overview_stats(
    p_school_id UUID,
    p_academic_year VARCHAR DEFAULT '2026-27'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_sections INT := 0;
    v_active_sections INT := 0;
    v_inactive_sections INT := 0;
    v_total_students INT := 0;
    v_avg_students_per_section NUMERIC := 0.0;
    v_sections_by_class JSONB := '[]'::JSONB;
    v_buildings_overview JSONB := '[]'::JSONB;
BEGIN
    -- Section Counts
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE s.status = 'ACTIVE'),
        COUNT(*) FILTER (WHERE s.status != 'ACTIVE')
    INTO v_total_sections, v_active_sections, v_inactive_sections
    FROM public.academic_sections s
    WHERE s.school_id = p_school_id 
      AND s.academic_year = p_academic_year 
      AND s.deleted_at IS NULL;

    -- Total Students
    SELECT COUNT(*) INTO v_total_students
    FROM public.student_class_assignments sca
    WHERE sca.school_id = p_school_id 
      AND sca.academic_year = p_academic_year 
      AND sca.status = 'ACTIVE';

    IF v_total_sections > 0 THEN
        v_avg_students_per_section := ROUND((v_total_students::NUMERIC / v_total_sections::NUMERIC), 2);
    END IF;

    -- Sections by Class Breakdown (For Donut Chart)
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'class_id', c.id,
                'class_name', c.name,
                'sections_count', COUNT(s.id),
                'percentage', CASE WHEN v_total_sections > 0 THEN ROUND((COUNT(s.id)::NUMERIC / v_total_sections::NUMERIC * 100), 2) ELSE 0 END
            ) ORDER BY c.display_order ASC, c.name ASC
        ),
        '[]'::JSONB
    ) INTO v_sections_by_class
    FROM public.academic_classes c
    LEFT JOIN public.academic_sections s ON s.class_id = c.id AND s.deleted_at IS NULL AND s.academic_year = p_academic_year
    WHERE c.school_id = p_school_id AND c.deleted_at IS NULL AND c.academic_year = p_academic_year
    GROUP BY c.id, c.name, c.display_order;

    -- Buildings Overview (For Bar List)
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'building_name', COALESCE(r.building, 'Academic Block A'),
                'sections_count', COUNT(s.id)
            ) ORDER BY COUNT(s.id) DESC
        ),
        '[]'::JSONB
    ) INTO v_buildings_overview
    FROM public.academic_sections s
    LEFT JOIN public.academic_rooms r ON r.id = s.room_id AND r.deleted_at IS NULL
    WHERE s.school_id = p_school_id AND s.academic_year = p_academic_year AND s.deleted_at IS NULL
    GROUP BY COALESCE(r.building, 'Academic Block A');

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'total_sections', v_total_sections,
            'active_sections', v_active_sections,
            'inactive_sections', v_inactive_sections,
            'total_students', v_total_students,
            'avg_students_per_section', v_avg_students_per_section,
            'sections_by_class', v_sections_by_class,
            'buildings_overview', v_buildings_overview
        )
    );
END;
$$;
