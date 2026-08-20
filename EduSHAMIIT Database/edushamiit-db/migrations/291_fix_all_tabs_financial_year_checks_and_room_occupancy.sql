-- ============================================================================
-- Migration: 291_fix_all_tabs_financial_year_checks_and_room_occupancy.sql
-- Description: Ensures all 4 tabs (Classes, Sections, Subjects, Rooms) strictly
--              filter all stats, counts, child relations, and occupancies by 
--              the selected academic_year.
-- ============================================================================

-- 1. Canonical fn_get_academic_stats with accurate room occupancy per academic_year
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
        COUNT(*) FILTER (WHERE s.status = 'ACTIVE' AND c.status = 'ACTIVE'),
        COUNT(*) FILTER (WHERE s.status != 'ACTIVE' OR c.status != 'ACTIVE')
    INTO v_total_sections, v_active_sections, v_inactive_sections
    FROM public.academic_sections s
    JOIN public.academic_classes c ON c.id = s.class_id
    WHERE s.school_id = p_school_id 
      AND s.academic_year = p_academic_year
      AND c.academic_year = p_academic_year
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
      AND c.academic_year = p_academic_year
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

    -- 4. Subjects stats
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

    -- 5. Subject Types Breakdown
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'type', t_grp.display_type,
                'count', t_grp.cnt,
                'percentage', ROUND((t_grp.cnt::NUMERIC / GREATEST(v_total_subjects, 1)::NUMERIC) * 100, 2)
            ) ORDER BY t_grp.cnt DESC
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
                WHEN sub.type ILIKE '%voc%' THEN 'Vocational'
                WHEN sub.type ILIKE '%act%' OR sub.type ILIKE '%sport%' THEN 'Activity'
                ELSE COALESCE(NULLIF(TRIM(sub.type), ''), 'Other')
            END AS display_type,
            COUNT(*) as cnt
        FROM public.academic_subjects sub
        WHERE sub.school_id = p_school_id AND sub.deleted_at IS NULL
          AND (
              p_teacher_id IS NULL
              OR EXISTS (
                  SELECT 1 FROM public.section_subject_teachers sst
                  WHERE sst.subject_id = sub.id AND sst.teacher_id = p_teacher_id AND sst.status = 'ACTIVE'
              )
          )
        GROUP BY 1
    ) t_grp;

    -- 6. Subjects by Class Breakdown (strictly filtered by academic_year)
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'class_id', s_grp.id,
                'class_name', s_grp.name,
                'class_code', s_grp.code,
                'subjects_count', s_grp.sub_cnt
            ) ORDER BY s_grp.sub_cnt DESC, s_grp.display_order ASC, s_grp.name ASC
        ),
        '[]'::JSONB
    ) INTO v_subjects_by_class
    FROM (
        SELECT c.id, c.name, c.code, c.display_order,
               COUNT(DISTINCT csa.subject_id) as sub_cnt
        FROM public.academic_classes c
        LEFT JOIN public.class_subject_assignments csa ON csa.class_id = c.id AND csa.school_id = p_school_id AND csa.academic_year = p_academic_year
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

    -- 7. Rooms stats (Occupancy dynamically calculated based on sections in active academic_year)
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (
            WHERE r.status != 'MAINTENANCE' 
              AND NOT EXISTS (
                  SELECT 1 FROM public.academic_sections s 
                  WHERE s.room_id = r.id AND s.deleted_at IS NULL AND s.academic_year = p_academic_year
              )
        ),
        COUNT(*) FILTER (
            WHERE r.status != 'MAINTENANCE' 
              AND EXISTS (
                  SELECT 1 FROM public.academic_sections s 
                  WHERE s.room_id = r.id AND s.deleted_at IS NULL AND s.academic_year = p_academic_year
              )
        ),
        COUNT(*) FILTER (WHERE r.status = 'MAINTENANCE'),
        COALESCE(SUM(r.capacity), 0)
    INTO v_total_rooms, v_available_rooms, v_in_use_rooms, v_maintenance_rooms, v_total_room_capacity
    FROM public.academic_rooms r
    WHERE r.school_id = p_school_id 
      AND r.deleted_at IS NULL;

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

    -- 9. Buildings Breakdown (Sections assigned to rooms strictly in p_academic_year)
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'building', b_grp.building,
                'name', b_grp.building,
                'count', b_grp.sec_cnt,
                'sections_count', b_grp.sec_cnt,
                'rooms_count', b_grp.room_cnt,
                'percentage', ROUND((b_grp.sec_cnt::NUMERIC / GREATEST(v_total_sections, 1)::NUMERIC) * 100, 2)
            ) ORDER BY b_grp.sec_cnt DESC, b_grp.room_cnt DESC, b_grp.building ASC
        ),
        '[]'::JSONB
    ) INTO v_buildings_breakdown
    FROM (
        SELECT 
            COALESCE(NULLIF(TRIM(r.building), ''), 'Unassigned') as building, 
            COUNT(DISTINCT s.id) as sec_cnt,
            COUNT(DISTINCT r.id) as room_cnt
        FROM public.academic_rooms r
        LEFT JOIN public.academic_sections s ON s.room_id = r.id AND s.deleted_at IS NULL AND s.academic_year = p_academic_year
        WHERE r.school_id = p_school_id AND r.deleted_at IS NULL
        GROUP BY COALESCE(NULLIF(TRIM(r.building), ''), 'Unassigned')
        
        UNION
        
        SELECT 
            'Unassigned' as building,
            COUNT(DISTINCT s.id) as sec_cnt,
            0 as room_cnt
        FROM public.academic_sections s
        JOIN public.academic_classes c ON c.id = s.class_id AND c.deleted_at IS NULL
        WHERE s.school_id = p_school_id 
          AND s.academic_year = p_academic_year 
          AND c.academic_year = p_academic_year
          AND s.deleted_at IS NULL 
          AND (s.room_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.academic_rooms ar WHERE ar.id = s.room_id AND ar.deleted_at IS NULL))
        HAVING COUNT(DISTINCT s.id) > 0 AND NOT EXISTS (
            SELECT 1 FROM public.academic_rooms ar WHERE ar.school_id = p_school_id AND ar.deleted_at IS NULL AND ar.building = 'Unassigned'
        )
    ) b_grp;

    -- 10. Sections by Class Breakdown (strictly filtered by academic_year)
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'class_id', c_grp.id,
                'class_name', c_grp.name,
                'class_code', c_grp.code,
                'sections_count', c_grp.sec_cnt,
                'students_count', c_grp.stu_cnt,
                'percentage', ROUND((c_grp.sec_cnt::NUMERIC / GREATEST(v_total_sections, 1)::NUMERIC) * 100, 2)
            ) ORDER BY c_grp.sec_cnt DESC, c_grp.display_order ASC, c_grp.name ASC
        ),
        '[]'::JSONB
    ) INTO v_sections_by_class
    FROM (
        SELECT c.id, c.name, c.code, c.display_order,
               COUNT(DISTINCT s.id) as sec_cnt,
               COUNT(DISTINCT sca.student_id) as stu_cnt
        FROM public.academic_classes c
        LEFT JOIN public.academic_sections s ON s.class_id = c.id AND s.deleted_at IS NULL AND s.academic_year = p_academic_year
        LEFT JOIN public.student_class_assignments sca ON sca.section_id = s.id AND sca.status = 'ACTIVE' AND sca.academic_year = p_academic_year
        WHERE c.school_id = p_school_id 
          AND c.academic_year = p_academic_year 
          AND c.deleted_at IS NULL
          AND (
              p_teacher_id IS NULL
              OR EXISTS (
                  SELECT 1 FROM public.class_teacher_assignments cta 
                  WHERE (cta.section_id = s.id OR (cta.class_id = c.id AND cta.section_id IS NULL))
                    AND cta.teacher_id = p_teacher_id
              )
              OR EXISTS (
                  SELECT 1 FROM public.section_subject_teachers sst
                  WHERE (sst.section_id = s.id OR sst.class_id = c.id)
                    AND sst.teacher_id = p_teacher_id
              )
          )
        GROUP BY c.id, c.name, c.code, c.display_order
        HAVING COUNT(DISTINCT s.id) > 0 OR COUNT(DISTINCT sca.student_id) > 0
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
            'total_rooms', v_total_rooms,
            'available_rooms', v_available_rooms,
            'in_use_rooms', v_in_use_rooms,
            'maintenance_rooms', v_maintenance_rooms,
            'total_room_capacity', v_total_room_capacity,
            'subject_types_breakdown', v_subject_types_breakdown,
            'subjects_by_class', v_subjects_by_class,
            'room_types_breakdown', v_room_types_breakdown,
            'buildings_breakdown', v_buildings_breakdown,
            'sections_by_class', v_sections_by_class
        )
    );
END;
$$;


-- 2. Update fn_get_academic_sections with strict academic_year isolation
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
    p_building VARCHAR DEFAULT 'ALL',
    p_floor VARCHAR DEFAULT 'ALL'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_count INT := 0;
    v_total_pages INT := 1;
    v_offset INT := 0;
    v_sections JSONB := '[]'::JSONB;
    v_clean_search TEXT := TRIM(COALESCE(p_search, ''));
    v_clean_status VARCHAR := UPPER(TRIM(COALESCE(p_status, 'ALL')));
    v_clean_building VARCHAR := UPPER(TRIM(COALESCE(p_building, 'ALL')));
    v_clean_floor VARCHAR := UPPER(TRIM(COALESCE(p_floor, 'ALL')));
    v_clean_sort_by VARCHAR := LOWER(TRIM(COALESCE(p_sort_by, 'class_name')));
    v_clean_sort_order VARCHAR := UPPER(TRIM(COALESCE(p_sort_order, 'ASC')));
BEGIN
    v_offset := (p_page - 1) * p_page_size;

    -- Count total matching sections
    SELECT COUNT(*) INTO v_total_count
    FROM public.academic_sections s
    JOIN public.academic_classes c ON c.id = s.class_id
    LEFT JOIN public.academic_rooms r ON r.id = s.room_id
    WHERE s.school_id = p_school_id
      AND s.academic_year = p_academic_year
      AND c.academic_year = p_academic_year
      AND s.deleted_at IS NULL
      AND c.deleted_at IS NULL
      AND (p_class_id IS NULL OR s.class_id = p_class_id)
      AND (
          v_clean_status = 'ALL' 
          OR (v_clean_status = 'ACTIVE' AND c.status = 'ACTIVE' AND s.status = 'ACTIVE')
          OR (v_clean_status = 'INACTIVE' AND (c.status != 'ACTIVE' OR s.status != 'ACTIVE'))
          OR (v_clean_status = 'ARCHIVED' AND (c.status = 'ARCHIVED' OR s.status = 'ARCHIVED'))
      )
      AND (v_clean_building = 'ALL' OR (r.building IS NOT NULL AND UPPER(r.building) = v_clean_building))
      AND (v_clean_floor = 'ALL' OR (r.floor IS NOT NULL AND UPPER(r.floor) = v_clean_floor))
      AND (
          v_clean_search = '' 
          OR s.name ILIKE '%' || v_clean_search || '%'
          OR s.code ILIKE '%' || v_clean_search || '%'
          OR c.name ILIKE '%' || v_clean_search || '%'
          OR c.code ILIKE '%' || v_clean_search || '%'
          OR (r.name IS NOT NULL AND r.name ILIKE '%' || v_clean_search || '%')
      );

    v_total_pages := GREATEST(1, CEIL(v_total_count::FLOAT / p_page_size::FLOAT)::INT);

    -- Fetch Paginated Sections with Effective Hierarchical Status
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', s.id,
                'name', s.name,
                'code', s.code,
                'class_id', c.id,
                'class_name', c.name,
                'class_code', c.code,
                'class_stage', c.stage,
                'class_status', c.status,
                'capacity', s.capacity,
                'room_number', COALESCE(r.name, s.room_number),
                'room_id', s.room_id,
                'room_type', r.type,
                'building', r.building,
                'floor', r.floor,
                'status', (
                    CASE 
                        WHEN c.status != 'ACTIVE' THEN 'INACTIVE'
                        ELSE s.status
                    END
                ),
                'academic_year', s.academic_year,
                'display_order', s.display_order,
                'students_count', (
                    SELECT COUNT(DISTINCT sca.student_id) 
                    FROM public.student_class_assignments sca 
                    WHERE sca.section_id = s.id 
                      AND sca.school_id = p_school_id
                      AND sca.status = 'ACTIVE'
                      AND (sca.academic_year = p_academic_year OR sca.academic_year IS NULL)
                ),
                'subjects_count', (
                    SELECT COUNT(DISTINCT csa.subject_id)
                    FROM public.class_subject_assignments csa 
                    WHERE (csa.section_id = s.id OR (csa.class_id = c.id AND csa.section_id IS NULL))
                      AND csa.school_id = p_school_id
                      AND (csa.academic_year = p_academic_year OR csa.academic_year IS NULL)
                ),
                'class_teacher', (
                    SELECT jsonb_build_object(
                        'id', p.id,
                        'full_name', p.full_name,
                        'email', p.email,
                        'avatar_url', p.avatar_url,
                        'employee_id', p.employee_id,
                        'department', p.department
                    )
                    FROM public.class_teacher_assignments cta
                    JOIN public.profiles p ON p.id = cta.teacher_id
                    WHERE cta.section_id = s.id
                      AND (cta.academic_year = p_academic_year OR cta.academic_year IS NULL)
                    ORDER BY cta.is_primary DESC, cta.created_at DESC
                    LIMIT 1
                )
            ) ORDER BY
                CASE WHEN v_clean_sort_by = 'name' AND v_clean_sort_order = 'ASC' THEN s.name END ASC,
                CASE WHEN v_clean_sort_by = 'name' AND v_clean_sort_order = 'DESC' THEN s.name END DESC,
                CASE WHEN v_clean_sort_by = 'code' AND v_clean_sort_order = 'ASC' THEN s.code END ASC,
                CASE WHEN v_clean_sort_by = 'code' AND v_clean_sort_order = 'DESC' THEN s.code END DESC,
                CASE WHEN v_clean_sort_by = 'class_name' AND v_clean_sort_order = 'ASC' THEN c.name END ASC,
                CASE WHEN v_clean_sort_by = 'class_name' AND v_clean_sort_order = 'DESC' THEN c.name END DESC,
                c.display_order ASC, s.display_order ASC, s.name ASC
        ),
        '[]'::JSONB
    ) INTO v_sections
    FROM (
        SELECT s.*, c.display_order AS class_display_order
        FROM public.academic_sections s
        JOIN public.academic_classes c ON c.id = s.class_id
        LEFT JOIN public.academic_rooms r ON r.id = s.room_id
        WHERE s.school_id = p_school_id
          AND s.academic_year = p_academic_year
          AND c.academic_year = p_academic_year
          AND s.deleted_at IS NULL
          AND c.deleted_at IS NULL
          AND (p_class_id IS NULL OR s.class_id = p_class_id)
          AND (
              v_clean_status = 'ALL' 
              OR (v_clean_status = 'ACTIVE' AND c.status = 'ACTIVE' AND s.status = 'ACTIVE')
              OR (v_clean_status = 'INACTIVE' AND (c.status != 'ACTIVE' OR s.status != 'ACTIVE'))
              OR (v_clean_status = 'ARCHIVED' AND (c.status = 'ARCHIVED' OR s.status = 'ARCHIVED'))
          )
          AND (v_clean_building = 'ALL' OR (r.building IS NOT NULL AND UPPER(r.building) = v_clean_building))
          AND (v_clean_floor = 'ALL' OR (r.floor IS NOT NULL AND UPPER(r.floor) = v_clean_floor))
          AND (
              v_clean_search = '' 
              OR s.name ILIKE '%' || v_clean_search || '%'
              OR s.code ILIKE '%' || v_clean_search || '%'
              OR c.name ILIKE '%' || v_clean_search || '%'
              OR c.code ILIKE '%' || v_clean_search || '%'
              OR (r.name IS NOT NULL AND r.name ILIKE '%' || v_clean_search || '%')
          )
        LIMIT p_page_size
        OFFSET v_offset
    ) s_sub;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'sections', v_sections,
            'total_count', v_total_count,
            'total_pages', v_total_pages,
            'page', p_page,
            'page_size', p_page_size
        )
    );
END;
$$;
