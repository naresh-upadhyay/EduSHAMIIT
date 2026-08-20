-- ============================================================================
-- Migration 286: Add Status to class_subject_assignments & Toggle Function
-- Description:
-- 1. Adds `status` column to public.class_subject_assignments (default 'ACTIVE').
-- 2. Creates public.fn_toggle_class_subject_status to toggle ACTIVE/INACTIVE.
-- 3. Updates public.fn_get_subject_section_mappings to include `status`.
-- ============================================================================

-- 1. Add status column if not exists
ALTER TABLE public.class_subject_assignments 
ADD COLUMN IF NOT EXISTS status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE';

-- 2. Create toggle function
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
BEGIN
    IF v_new_status NOT IN ('ACTIVE', 'INACTIVE', 'ARCHIVED') THEN
        v_new_status := 'ACTIVE';
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
        RETURN jsonb_build_object('success', FALSE, 'error', 'Offering record not found', 'code', 404);
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Subject offering status updated to ' || v_new_status,
        'status', v_new_status
    );
END;
$$;

-- 3. Update fn_get_subject_section_mappings to return status
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
                'status', COALESCE(csa.status, 'ACTIVE'),
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
