-- Migration 390: Optimize fn_hostel_get_eligible_students with LIMIT and Subquery Pagination
-- Prevents unbounded full-table scans, reducing network payload and eliminating UI thread frame freezes.

CREATE OR REPLACE FUNCTION public.fn_hostel_get_eligible_students(
    p_school_id UUID,
    p_academic_year VARCHAR DEFAULT '2024 - 2025',
    p_search VARCHAR DEFAULT '',
    p_limit INT DEFAULT 25
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_results JSONB := '[]'::JSONB;
BEGIN
    SELECT COALESCE(
        jsonb_agg(sub.item),
        '[]'::JSONB
    ) INTO v_results
    FROM (
        SELECT jsonb_build_object(
            'id', p.id,
            'full_name', p.full_name,
            'avatar_url', p.avatar_url,
            'roll_no', COALESCE(sca.roll_number, p.roll_number::TEXT, '0101'),
            'admission_number', p.admission_number,
            'class_name', COALESCE(
                NULLIF(TRIM(COALESCE(ac.name, '') || ' ' || COALESCE(sec.name, '')), ''),
                p.class,
                'Class 10 A'
            ),
            'gender', COALESCE(p.gender, 'Male'),
            'father_name', p.father_name,
            'emergency_contact', COALESCE(p.emergency_contact_phone, p.father_phone, p.phone),
            'blood_group', p.blood_group,
            'address', p.address
        ) AS item
        FROM public.profiles p
        LEFT JOIN public.student_class_assignments sca ON (
            sca.student_id = p.id AND sca.school_id = p_school_id AND sca.status = 'ACTIVE'
        )
        LEFT JOIN public.academic_classes ac ON sca.class_id = ac.id
        LEFT JOIN public.academic_sections sec ON sca.section_id = sec.id
        WHERE p.school_id = p_school_id
          AND p.role = 'student'
          AND NOT EXISTS (
              SELECT 1 FROM public.hostel_admissions a 
              WHERE a.student_id = p.id 
                AND a.school_id = p_school_id 
                AND a.academic_year = p_academic_year 
                AND a.deleted_at IS NULL
                AND a.admission_status IN ('ACTIVE', 'AWAITING_ALLOCATION', 'ON_LEAVE')
          )
          AND (
              p_search = ''
              OR p.full_name ILIKE '%' || p_search || '%'
              OR COALESCE(p.roll_number::TEXT, sca.roll_number, '') ILIKE '%' || p_search || '%'
              OR COALESCE(p.admission_number, '') ILIKE '%' || p_search || '%'
          )
        ORDER BY p.full_name ASC
        LIMIT COALESCE(p_limit, 25)
    ) sub;

    RETURN v_results;
END;
$$;

