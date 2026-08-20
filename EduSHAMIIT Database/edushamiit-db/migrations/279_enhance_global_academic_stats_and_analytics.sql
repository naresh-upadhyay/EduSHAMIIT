-- ============================================================================
-- Migration 279: Enhanced Global Academic Stats & Dynamic Analytics
-- 1. Canonical fn_get_academic_stats with case-insensitive wildcard matching,
--    dynamic subject_types_breakdown, subjects_by_class, language_subjects,
--    and 100% mathematical consistency across global statistics.
-- 2. Canonical fn_get_academic_classes with subjects_count included.
-- ============================================================================

-- 1. Enhanced fn_get_academic_stats
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
    v_inactive_classes INT := 0;
    v_total_sections INT := 0;
    v_active_sections INT := 0;
    v_inactive_sections INT := 0;
    v_total_students INT := 0;
    v_avg_students_per_section NUMERIC := 0.0;
    
    v_total_subjects INT := 0;
    v_core_subjects INT := 0;
    v_elective_subjects INT := 0;
    v_practical_subjects INT := 0;
    v_language_subjects INT := 0;
    v_inactive_subjects INT := 0;

    v_total_rooms INT := 0;
    v_available_rooms INT := 0;
    v_in_use_rooms INT := 0;
    v_maintenance_rooms INT := 0;
    v_total_room_capacity INT := 0;
    
    v_subject_types_breakdown JSONB := '[]'::JSONB;
    v_subjects_by_class JSONB := '[]'::JSONB;
    v_room_types_breakdown JSONB := '[]'::JSONB;
    v_buildings_breakdown JSONB := '[]'::JSONB;
    v_sections_by_class JSONB := '[]'::JSONB;
BEGIN
    -- 1. Classes stats
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE c.status = 'ACTIVE'),
        COUNT(*) FILTER (WHERE c.status != 'ACTIVE')
    INTO v_total_classes, v_active_classes, v_inactive_classes
    FROM public.academic_classes c
    WHERE c.school_id = p_school_id 
      AND c.academic_year = p_academic_year
      AND c.deleted_at IS NULL
      AND (
          p_teacher_id IS NULL
          OR EXISTS (
              SELECT 1 FROM public.class_teacher_assignments cta 
              WHERE cta.class_id = c.id AND cta.teacher_id = p_teacher_id
          )
          OR EXISTS (
              SELECT 1 FROM public.section_subject_teachers sst
              WHERE sst.class_id = c.id AND sst.teacher_id = p_teacher_id
          )
      );

    -- 2. Sections stats
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE s.status = 'ACTIVE'),
        COUNT(*) FILTER (WHERE s.status != 'ACTIVE')
    INTO v_total_sections, v_active_sections, v_inactive_sections
    FROM public.academic_sections s
    JOIN public.academic_classes c ON c.id = s.class_id
    WHERE s.school_id = p_school_id 
      AND s.academic_year = p_academic_year
      AND s.deleted_at IS NULL
      AND c.deleted_at IS NULL
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

    -- 3. Students stats
    SELECT COUNT(DISTINCT sca.student_id)
    INTO v_total_students
    FROM public.student_class_assignments sca
    JOIN public.academic_classes c ON c.id = sca.class_id
    WHERE sca.school_id = p_school_id 
      AND sca.academic_year = p_academic_year
      AND sca.status = 'ACTIVE'
      AND c.deleted_at IS NULL
      AND (
          p_teacher_id IS NULL
          OR EXISTS (
              SELECT 1 FROM public.class_teacher_assignments cta 
              WHERE (cta.section_id = sca.section_id OR (cta.class_id = sca.class_id AND cta.section_id IS NULL))
                AND cta.teacher_id = p_teacher_id
          )
          OR EXISTS (
              SELECT 1 FROM public.section_subject_teachers sst
              WHERE sst.section_id = sca.section_id AND sst.teacher_id = p_teacher_id
          )
      );

    IF v_total_sections > 0 THEN
        v_avg_students_per_section := ROUND((v_total_students::NUMERIC / v_total_sections::NUMERIC), 2);
    ELSE
        v_avg_students_per_section := 0.0;
    END IF;

    -- 4. Subjects stats (Robust case-insensitive pattern matching)
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE sub.type ILIKE '%core%'),
        COUNT(*) FILTER (WHERE sub.type ILIKE '%elec%' OR sub.type ILIKE '%opt%'),
        COUNT(*) FILTER (WHERE sub.type ILIKE '%prac%' OR sub.type ILIKE '%lab%'),
        COUNT(*) FILTER (WHERE sub.type ILIKE '%lang%'),
        COUNT(*) FILTER (WHERE UPPER(TRIM(sub.status)) != 'ACTIVE')
    INTO v_total_subjects, v_core_subjects, v_elective_subjects, v_practical_subjects, v_language_subjects, v_inactive_subjects
    FROM public.academic_subjects sub
    WHERE sub.school_id = p_school_id 
      AND sub.deleted_at IS NULL
      AND (
          p_teacher_id IS NULL
          OR EXISTS (
              SELECT 1 FROM public.section_subject_teachers sst
              WHERE sst.subject_id = sub.id AND sst.teacher_id = p_teacher_id AND sst.status = 'ACTIVE'
          )
      );

    -- 5. Dynamic Subject Types Breakdown (Grouped with normalized standard labels)
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'type', st_grp.type_label,
                'count', st_grp.cnt,
                'percentage', ROUND((st_grp.cnt::NUMERIC / GREATEST(v_total_subjects, 1)::NUMERIC) * 100, 2)
            ) ORDER BY st_grp.cnt DESC, st_grp.type_label ASC
        ),
        '[]'::JSONB
    ) INTO v_subject_types_breakdown
    FROM (
        SELECT 
            CASE 
                WHEN sub.type ILIKE '%core%' THEN 'Core'
                WHEN sub.type ILIKE '%elec%' OR sub.type ILIKE '%opt%' THEN 'Elective'
                WHEN sub.type ILIKE '%prac%' OR sub.type ILIKE '%lab%' THEN 'Practical'
                WHEN sub.type ILIKE '%lang%' THEN 'Language'
                ELSE COALESCE(NULLIF(TRIM(sub.type), ''), 'Other')
            END AS type_label,
            COUNT(*) as cnt
        FROM public.academic_subjects sub
        WHERE sub.school_id = p_school_id 
          AND sub.deleted_at IS NULL
          AND (
              p_teacher_id IS NULL
              OR EXISTS (
                  SELECT 1 FROM public.section_subject_teachers sst
                  WHERE sst.subject_id = sub.id AND sst.teacher_id = p_teacher_id AND sst.status = 'ACTIVE'
              )
          )
        GROUP BY 1
    ) st_grp;

    -- 6. Dynamic Subjects by Class Breakdown (Dynamic & Accurate from DB)
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'class_id', s_grp.id,
                'class_name', s_grp.name,
                'class_code', s_grp.code,
                'subjects_count', s_grp.sub_cnt
            ) ORDER BY s_grp.display_order ASC, s_grp.name ASC
        ),
        '[]'::JSONB
    ) INTO v_subjects_by_class
    FROM (
        SELECT c.id, c.name, c.code, c.display_order,
               COUNT(DISTINCT csa.subject_id) as sub_cnt
        FROM public.academic_classes c
        LEFT JOIN public.class_subject_assignments csa ON csa.class_id = c.id AND csa.school_id = p_school_id
        LEFT JOIN public.academic_subjects sub ON sub.id = csa.subject_id AND sub.deleted_at IS NULL
        WHERE c.school_id = p_school_id 
          AND c.academic_year = p_academic_year 
          AND c.deleted_at IS NULL
          AND (
              p_teacher_id IS NULL
              OR EXISTS (
                  SELECT 1 FROM public.class_teacher_assignments cta 
                  WHERE cta.class_id = c.id AND cta.teacher_id = p_teacher_id
              )
              OR EXISTS (
                  SELECT 1 FROM public.section_subject_teachers sst
                  WHERE sst.class_id = c.id AND sst.teacher_id = p_teacher_id
              )
          )
        GROUP BY c.id, c.name, c.code, c.display_order
    ) s_grp;

    -- 7. Rooms stats
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE r.status = 'AVAILABLE'),
        COUNT(*) FILTER (WHERE r.status = 'OCCUPIED' OR r.status = 'IN_USE'),
        COUNT(*) FILTER (WHERE r.status = 'MAINTENANCE'),
        COALESCE(SUM(r.capacity), 0)
    INTO v_total_rooms, v_available_rooms, v_in_use_rooms, v_maintenance_rooms, v_total_room_capacity
    FROM public.academic_rooms r
    WHERE r.school_id = p_school_id 
      AND r.deleted_at IS NULL;

    IF v_available_rooms = 0 AND v_in_use_rooms = 0 AND v_total_rooms > 0 THEN
        v_available_rooms := v_total_rooms - v_maintenance_rooms;
    END IF;

    -- 8. Room Types Breakdown
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'type', r_grp.type,
                'count', r_grp.cnt,
                'percentage', ROUND((r_grp.cnt::NUMERIC / GREATEST(v_total_rooms, 1)::NUMERIC) * 100, 2)
            ) ORDER BY r_grp.cnt DESC
        ),
        '[]'::JSONB
    ) INTO v_room_types_breakdown
    FROM (
        SELECT type, COUNT(*) as cnt
        FROM public.academic_rooms
        WHERE school_id = p_school_id AND deleted_at IS NULL
        GROUP BY type
    ) r_grp;

    -- 9. Buildings Breakdown
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'building', b_grp.building,
                'count', b_grp.cnt,
                'percentage', ROUND((b_grp.cnt::NUMERIC / GREATEST(v_total_rooms, 1)::NUMERIC) * 100, 2)
            ) ORDER BY b_grp.cnt DESC
        ),
        '[]'::JSONB
    ) INTO v_buildings_breakdown
    FROM (
        SELECT building, COUNT(*) as cnt
        FROM public.academic_rooms
        WHERE school_id = p_school_id AND deleted_at IS NULL
        GROUP BY building
    ) b_grp;

    -- 10. Sections by Class Breakdown
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'class_name', c_grp.name,
                'sections_count', c_grp.sec_cnt,
                'students_count', c_grp.stu_cnt,
                'percentage', ROUND((c_grp.sec_cnt::NUMERIC / GREATEST(v_total_sections, 1)::NUMERIC) * 100, 2)
            ) ORDER BY c_grp.display_order ASC
        ),
        '[]'::JSONB
    ) INTO v_sections_by_class
    FROM (
        SELECT c.id, c.name, c.display_order,
               COUNT(DISTINCT s.id) as sec_cnt,
               COUNT(DISTINCT sca.student_id) as stu_cnt
        FROM public.academic_classes c
        LEFT JOIN public.academic_sections s ON s.class_id = c.id AND s.deleted_at IS NULL
        LEFT JOIN public.student_class_assignments sca ON sca.class_id = c.id AND sca.status = 'ACTIVE'
        WHERE c.school_id = p_school_id AND c.academic_year = p_academic_year AND c.deleted_at IS NULL
        GROUP BY c.id, c.name, c.display_order
    ) c_grp;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'total_classes', v_total_classes,
            'active_classes', v_active_classes,
            'inactive_classes', v_inactive_classes,
            'total_sections', v_total_sections,
            'active_sections', v_active_sections,
            'inactive_sections', v_inactive_sections,
            'total_students', v_total_students,
            'avg_students_per_section', v_avg_students_per_section,
            'total_subjects', v_total_subjects,
            'core_subjects', v_core_subjects,
            'elective_subjects', v_elective_subjects,
            'practical_subjects', v_practical_subjects,
            'language_subjects', v_language_subjects,
            'inactive_subjects', v_inactive_subjects,
            'subject_types_breakdown', v_subject_types_breakdown,
            'subjects_by_class', v_subjects_by_class,
            'total_rooms', v_total_rooms,
            'available_rooms', v_available_rooms,
            'in_use_rooms', v_in_use_rooms,
            'maintenance_rooms', v_maintenance_rooms,
            'total_room_capacity', v_total_room_capacity,
            'room_types_breakdown', v_room_types_breakdown,
            'buildings_breakdown', v_buildings_breakdown,
            'sections_by_class', v_sections_by_class
        )
    );
END;
$$;


-- 2. Canonical fn_get_academic_classes (Enriched with subjects_count)
CREATE OR REPLACE FUNCTION public.fn_get_academic_classes(
    p_school_id UUID,
    p_search VARCHAR DEFAULT '',
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
      AND c.deleted_at IS NULL
      AND (p_status = 'ALL' OR c.status = p_status)
      AND (p_search = '' OR c.name ILIKE '%' || p_search || '%' OR c.code ILIKE '%' || p_search || '%')
      AND (
          p_teacher_id IS NULL 
          OR EXISTS (
              SELECT 1 FROM public.class_teacher_assignments cta 
              WHERE cta.class_id = c.id AND cta.teacher_id = p_teacher_id
          )
          OR EXISTS (
              SELECT 1 FROM public.section_subject_teachers sst
              WHERE sst.class_id = c.id AND sst.teacher_id = p_teacher_id
          )
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
                'sections_count', (SELECT COUNT(*) FROM public.academic_sections s WHERE s.class_id = c.id AND s.deleted_at IS NULL),
                'students_count', (SELECT COUNT(DISTINCT sca.student_id) FROM public.student_class_assignments sca WHERE sca.class_id = c.id AND sca.status = 'ACTIVE'),
                'subjects_count', (
                    SELECT COUNT(DISTINCT csa.subject_id)
                    FROM public.class_subject_assignments csa
                    JOIN public.academic_subjects sub ON sub.id = csa.subject_id
                    WHERE csa.class_id = c.id 
                      AND csa.school_id = p_school_id
                      AND sub.deleted_at IS NULL
                ),
                'sections', (
                    SELECT COALESCE(
                        jsonb_agg(
                            jsonb_build_object(
                                'id', s.id,
                                'name', s.name,
                                'code', s.code,
                                'capacity', s.capacity,
                                'status', s.status,
                                'room_number', s.room_number,
                                'room_id', s.room_id,
                                'room_name', (SELECT name FROM public.academic_rooms r WHERE r.id = s.room_id),
                                'building', s.building,
                                'students_count', (
                                    SELECT COUNT(DISTINCT sca.student_id) 
                                    FROM public.student_class_assignments sca 
                                    WHERE sca.section_id = s.id AND sca.status = 'ACTIVE'
                                ),
                                'subjects_count', (
                                    SELECT COUNT(DISTINCT csa.subject_id)
                                    FROM public.class_subject_assignments csa
                                    JOIN public.academic_subjects sub ON sub.id = csa.subject_id
                                    WHERE csa.section_id = s.id 
                                      AND csa.school_id = p_school_id
                                      AND sub.deleted_at IS NULL
                                ),
                                'class_teacher', (
                                    SELECT jsonb_build_object(
                                        'id', p.id,
                                        'first_name', p.first_name,
                                        'last_name', p.last_name,
                                        'email', p.email,
                                        'avatar_url', p.avatar_url,
                                        'designation', p.designation,
                                        'employee_id', p.employee_id
                                    )
                                    FROM public.class_teacher_assignments cta
                                    JOIN public.profiles p ON p.id = cta.teacher_id
                                    WHERE cta.section_id = s.id AND cta.is_primary = TRUE
                                    LIMIT 1
                                )
                            ) ORDER BY s.name ASC
                        ),
                        '[]'::JSONB
                    )
                    FROM public.academic_sections s
                    WHERE s.class_id = c.id AND s.deleted_at IS NULL
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
          AND c.deleted_at IS NULL
          AND (p_status = 'ALL' OR c.status = p_status)
          AND (p_search = '' OR c.name ILIKE '%' || p_search || '%' OR c.code ILIKE '%' || p_search || '%')
          AND (
              p_teacher_id IS NULL 
              OR EXISTS (
                  SELECT 1 FROM public.class_teacher_assignments cta 
                  WHERE cta.class_id = c.id AND cta.teacher_id = p_teacher_id
              )
              OR EXISTS (
                  SELECT 1 FROM public.section_subject_teachers sst
                  WHERE sst.class_id = c.id AND sst.teacher_id = p_teacher_id
              )
          )
        ORDER BY 
            CASE WHEN LOWER(p_sort_by) = 'name' AND UPPER(p_sort_order) = 'ASC' THEN c.name END ASC,
            CASE WHEN LOWER(p_sort_by) = 'name' AND UPPER(p_sort_order) = 'DESC' THEN c.name END DESC,
            CASE WHEN LOWER(p_sort_by) = 'code' AND UPPER(p_sort_order) = 'ASC' THEN c.code END ASC,
            CASE WHEN LOWER(p_sort_by) = 'code' AND UPPER(p_sort_order) = 'DESC' THEN c.code END DESC,
            c.display_order ASC, c.created_at ASC
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


-- 3. Canonical fn_get_academic_subjects (Flexible Pattern-Matching Filters)
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
      AND (
          p_type = 'ALL' 
          OR p_type = '' 
          OR UPPER(TRIM(s.type)) = UPPER(TRIM(p_type))
          OR (p_type ILIKE '%core%' AND s.type ILIKE '%core%')
          OR ((p_type ILIKE '%elec%' OR p_type ILIKE '%opt%') AND (s.type ILIKE '%elec%' OR s.type ILIKE '%opt%'))
          OR ((p_type ILIKE '%prac%' OR p_type ILIKE '%lab%') AND (s.type ILIKE '%prac%' OR s.type ILIKE '%lab%'))
          OR (p_type ILIKE '%lang%' AND s.type ILIKE '%lang%')
      )
      AND (
          p_class_id IS NULL
          OR EXISTS (
              SELECT 1 FROM public.class_subject_assignments csa
              WHERE csa.subject_id = s.id AND csa.class_id = p_class_id AND csa.school_id = p_school_id
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
                'is_optional', COALESCE(s_item.is_optional, (s_item.type ILIKE '%elec%' OR s_item.type ILIKE '%opt%')),
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
          AND (
              p_type = 'ALL' 
              OR p_type = '' 
              OR UPPER(TRIM(s.type)) = UPPER(TRIM(p_type))
              OR (p_type ILIKE '%core%' AND s.type ILIKE '%core%')
              OR ((p_type ILIKE '%elec%' OR p_type ILIKE '%opt%') AND (s.type ILIKE '%elec%' OR s.type ILIKE '%opt%'))
              OR ((p_type ILIKE '%prac%' OR p_type ILIKE '%lab%') AND (s.type ILIKE '%prac%' OR s.type ILIKE '%lab%'))
              OR (p_type ILIKE '%lang%' AND s.type ILIKE '%lang%')
          )
          AND (
              p_class_id IS NULL
              OR EXISTS (
                  SELECT 1 FROM public.class_subject_assignments csa
                  WHERE csa.subject_id = s.id AND csa.class_id = p_class_id AND csa.school_id = p_school_id
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

-- 4. 9-param overload
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
        p_school_id := p_school_id,
        p_search := p_search,
        p_type := p_type,
        p_status := p_status,
        p_class_id := NULL,
        p_page := p_page,
        p_page_size := p_page_size,
        p_sort_by := p_sort_by,
        p_sort_order := p_sort_order,
        p_teacher_id := p_teacher_id
    );
END;
$$;

