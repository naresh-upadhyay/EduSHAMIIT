-- ============================================================================
-- Migration: 271_academic_rooms_and_subject_offerings.sql
-- Description: Academic Rooms Management, Schedule Allocations, Section-Subject
--              Offerings, Section Subject Teachers & Student Optional Enrollments
-- Scoped: Multi-tenant (school_id), Academic Year, RBAC & Audit-Ready
-- ============================================================================

-- 1. Academic Rooms Table
CREATE TABLE IF NOT EXISTS public.academic_rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    name VARCHAR(150) NOT NULL,
    code VARCHAR(50) NOT NULL,
    type VARCHAR(50) NOT NULL DEFAULT 'Classroom', -- Classroom, Laboratory, Computer Lab, Physics Lab, Chemistry Lab, Biology Lab, Library, Auditorium, Seminar Hall, Staff Room, Activity Room, Music Room, Art Room, Sports Room, Medical Room, Conference Room, Other
    building VARCHAR(100) NOT NULL DEFAULT 'Academic Block',
    floor VARCHAR(50) NOT NULL DEFAULT 'Ground Floor',
    capacity INT NOT NULL DEFAULT 40,
    facilities JSONB NOT NULL DEFAULT '[]'::JSONB, -- ["Projector", "Smart Board", "AC", "Computers", "Internet", "CCTV", "Audio System", "Laboratory Equipment", "Accessibility"]
    status VARCHAR(30) NOT NULL DEFAULT 'AVAILABLE', -- AVAILABLE, OCCUPIED, RESERVED, MAINTENANCE, INACTIVE
    description TEXT,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_academic_rooms_school_code 
    ON public.academic_rooms (school_id, UPPER(code)) 
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_academic_rooms_school_name 
    ON public.academic_rooms (school_id, UPPER(name)) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_academic_rooms_school_status 
    ON public.academic_rooms (school_id, status) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_academic_rooms_building_floor 
    ON public.academic_rooms (school_id, building, floor) 
    WHERE deleted_at IS NULL;


-- 2. Enhance Academic Sections with Default Room Link
ALTER TABLE public.academic_sections 
    ADD COLUMN IF NOT EXISTS room_id UUID REFERENCES public.academic_rooms(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_academic_sections_room_id 
    ON public.academic_sections(room_id);


-- 3. Room Allocations & Timetable Schedule Table
CREATE TABLE IF NOT EXISTS public.room_allocations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    room_id UUID NOT NULL REFERENCES public.academic_rooms(id) ON DELETE CASCADE,
    academic_year VARCHAR(50) NOT NULL DEFAULT '2026-27',
    class_id UUID REFERENCES public.academic_classes(id) ON DELETE CASCADE,
    section_id UUID REFERENCES public.academic_sections(id) ON DELETE CASCADE,
    subject_id UUID REFERENCES public.academic_subjects(id) ON DELETE CASCADE,
    teacher_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    day_of_week INT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6), -- 0: Sunday, 1: Monday, ..., 6: Saturday
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    title VARCHAR(200),
    allocation_type VARCHAR(50) DEFAULT 'TIMETABLE', -- TIMETABLE, EXAM, EVENT, MAINTENANCE, RESERVATION
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, CANCELLED, RESCHEDULED
    notes TEXT,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_room_allocations_room_time 
    ON public.room_allocations (school_id, room_id, academic_year, day_of_week, status);

CREATE INDEX IF NOT EXISTS idx_room_allocations_section_time 
    ON public.room_allocations (school_id, section_id, academic_year, day_of_week, status);

CREATE INDEX IF NOT EXISTS idx_room_allocations_teacher_time 
    ON public.room_allocations (school_id, teacher_id, academic_year, day_of_week, status);


-- 4. Section Subject Teachers (Subject + Class + Section Level Assignment)
CREATE TABLE IF NOT EXISTS public.section_subject_teachers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    academic_year VARCHAR(50) NOT NULL DEFAULT '2026-27',
    class_id UUID NOT NULL REFERENCES public.academic_classes(id) ON DELETE CASCADE,
    section_id UUID NOT NULL REFERENCES public.academic_sections(id) ON DELETE CASCADE,
    subject_id UUID NOT NULL REFERENCES public.academic_subjects(id) ON DELETE CASCADE,
    teacher_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    is_primary BOOLEAN NOT NULL DEFAULT TRUE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, INACTIVE, REPLACED
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_section_subject_teacher 
    ON public.section_subject_teachers (school_id, academic_year, section_id, subject_id, teacher_id);

CREATE INDEX IF NOT EXISTS idx_sec_sub_teacher_class ON public.section_subject_teachers(class_id);
CREATE INDEX IF NOT EXISTS idx_sec_sub_teacher_section ON public.section_subject_teachers(section_id);
CREATE INDEX IF NOT EXISTS idx_sec_sub_teacher_subject ON public.section_subject_teachers(subject_id);
CREATE INDEX IF NOT EXISTS idx_sec_sub_teacher_teacher ON public.section_subject_teachers(teacher_id);


-- 5. Student Subject Enrollments (Student-Level Optional / Elective Subject Choices)
CREATE TABLE IF NOT EXISTS public.student_subject_enrollments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    academic_year VARCHAR(50) NOT NULL DEFAULT '2026-27',
    class_id UUID NOT NULL REFERENCES public.academic_classes(id) ON DELETE CASCADE,
    section_id UUID NOT NULL REFERENCES public.academic_sections(id) ON DELETE CASCADE,
    subject_id UUID NOT NULL REFERENCES public.academic_subjects(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, DROPPED, TRANSFERRED
    enrolled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_student_subject_enrollment 
    ON public.student_subject_enrollments (school_id, academic_year, section_id, subject_id, student_id);

CREATE INDEX IF NOT EXISTS idx_stu_sub_enr_section ON public.student_subject_enrollments(section_id, subject_id);
CREATE INDEX IF NOT EXISTS idx_stu_sub_enr_student ON public.student_subject_enrollments(student_id);


-- ============================================================================
-- STORED PROCEDURES & FUNCTIONS
-- ============================================================================

-- A. Enhanced Academic Statistics (Classes, Sections, Subjects, Rooms)
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
    v_active_sections INT := 0;
    v_inactive_sections INT := 0;
    v_total_students INT := 0;
    v_avg_students_per_section NUMERIC := 0.0;
    
    v_total_subjects INT := 0;
    v_core_subjects INT := 0;
    v_elective_subjects INT := 0;
    v_practical_subjects INT := 0;
    v_inactive_subjects INT := 0;

    v_total_rooms INT := 0;
    v_available_rooms INT := 0;
    v_in_use_rooms INT := 0;
    v_maintenance_rooms INT := 0;
    v_total_room_capacity INT := 0;
    
    v_room_types_breakdown JSONB := '[]'::JSONB;
    v_buildings_breakdown JSONB := '[]'::JSONB;
    v_sections_by_class JSONB := '[]'::JSONB;
    v_subjects_by_class JSONB := '[]'::JSONB;
BEGIN
    -- 1. Classes stats
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE c.status = 'ACTIVE')
    INTO v_total_classes, v_active_classes
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

    -- 4. Subjects stats
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE sub.type ILIKE 'Core'),
        COUNT(*) FILTER (WHERE sub.type ILIKE 'Elective' OR sub.type ILIKE 'Optional'),
        COUNT(*) FILTER (WHERE sub.type ILIKE 'Practical' OR sub.type ILIKE 'Lab'),
        COUNT(*) FILTER (WHERE sub.status != 'ACTIVE')
    INTO v_total_subjects, v_core_subjects, v_elective_subjects, v_practical_subjects, v_inactive_subjects
    FROM public.academic_subjects sub
    WHERE sub.school_id = p_school_id 
      AND sub.deleted_at IS NULL;

    -- 5. Rooms stats
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

    -- If no rooms created yet, provide realistic totals or zero
    IF v_available_rooms = 0 AND v_in_use_rooms = 0 AND v_total_rooms > 0 THEN
        v_available_rooms := v_total_rooms - v_maintenance_rooms;
    END IF;

    -- 6. Room Types Breakdown
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

    -- 7. Buildings Breakdown
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

    -- 8. Sections by Class Breakdown (for charts)
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

    -- 9. Subjects by Class Breakdown
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'class_name', s_grp.name,
                'subjects_count', s_grp.sub_cnt
            ) ORDER BY s_grp.display_order ASC
        ),
        '[]'::JSONB
    ) INTO v_subjects_by_class
    FROM (
        SELECT c.id, c.name, c.display_order,
               COUNT(DISTINCT csa.subject_id) as sub_cnt
        FROM public.academic_classes c
        LEFT JOIN public.class_subject_assignments csa ON csa.class_id = c.id
        WHERE c.school_id = p_school_id AND c.academic_year = p_academic_year AND c.deleted_at IS NULL
        GROUP BY c.id, c.name, c.display_order
    ) s_grp;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'total_classes', v_total_classes,
            'active_classes', v_active_classes,
            'total_sections', v_total_sections,
            'active_sections', v_active_sections,
            'inactive_sections', v_inactive_sections,
            'total_students', v_total_students,
            'avg_students_per_section', v_avg_students_per_section,
            'total_subjects', v_total_subjects,
            'core_subjects', v_core_subjects,
            'elective_subjects', v_elective_subjects,
            'practical_subjects', v_practical_subjects,
            'inactive_subjects', v_inactive_subjects,
            'total_rooms', v_total_rooms,
            'available_rooms', v_available_rooms,
            'in_use_rooms', v_in_use_rooms,
            'maintenance_rooms', v_maintenance_rooms,
            'total_room_capacity', v_total_room_capacity,
            'room_types_breakdown', v_room_types_breakdown,
            'buildings_breakdown', v_buildings_breakdown,
            'sections_by_class', v_sections_by_class,
            'subjects_by_class', v_subjects_by_class
        )
    );
END;
$$;


-- B. Function: Get Paginated Rooms List with Filters & Dynamic Current Allocations
DROP FUNCTION IF EXISTS public.fn_get_academic_rooms CASCADE;
CREATE OR REPLACE FUNCTION public.fn_get_academic_rooms(
    p_school_id UUID,
    p_search VARCHAR DEFAULT '',
    p_type VARCHAR DEFAULT 'ALL',
    p_building VARCHAR DEFAULT 'ALL',
    p_floor VARCHAR DEFAULT 'ALL',
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
    v_offset INT := (GREATEST(p_page, 1) - 1) * p_page_size;
    v_total_count INT := 0;
    v_rooms JSONB := '[]'::JSONB;
    v_current_day INT := EXTRACT(DOW FROM CURRENT_TIMESTAMP);
    v_current_time TIME := CURRENT_TIME;
BEGIN
    -- 1. Total Count for pagination
    SELECT COUNT(*) INTO v_total_count
    FROM public.academic_rooms r
    WHERE r.school_id = p_school_id
      AND r.deleted_at IS NULL
      AND (
          p_search = '' 
          OR r.name ILIKE '%' || p_search || '%' 
          OR r.code ILIKE '%' || p_search || '%'
          OR r.type ILIKE '%' || p_search || '%'
          OR r.building ILIKE '%' || p_search || '%'
      )
      AND (p_type = 'ALL' OR r.type = p_type)
      AND (p_building = 'ALL' OR r.building = p_building)
      AND (p_floor = 'ALL' OR r.floor = p_floor)
      AND (
          p_status = 'ALL' 
          OR (p_status = 'AVAILABLE' AND r.status = 'AVAILABLE')
          OR (p_status = 'IN_USE' AND (r.status = 'OCCUPIED' OR r.status = 'IN_USE'))
          OR (p_status = 'MAINTENANCE' AND r.status = 'MAINTENANCE')
          OR (p_status = 'RESERVED' AND r.status = 'RESERVED')
          OR (p_status = r.status)
      );

    -- 2. Fetch paginated records with dynamic in_use_by & timings
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', r_item.id,
                'name', r_item.name,
                'code', r_item.code,
                'type', r_item.type,
                'building', r_item.building,
                'floor', r_item.floor,
                'capacity', r_item.capacity,
                'facilities', r_item.facilities,
                'status', r_item.computed_status,
                'description', r_item.description,
                'in_use_by', r_item.in_use_by,
                'timings', r_item.timings,
                'assigned_sections_count', r_item.assigned_sections_count,
                'created_at', r_item.created_at,
                'updated_at', r_item.updated_at
            )
        ),
        '[]'::JSONB
    ) INTO v_rooms
    FROM (
        SELECT 
            r.id,
            r.name,
            r.code,
            r.type,
            r.building,
            r.floor,
            r.capacity,
            r.facilities,
            r.description,
            r.created_at,
            r.updated_at,
            (
                SELECT COUNT(*) 
                FROM public.academic_sections s 
                WHERE s.room_id = r.id AND s.deleted_at IS NULL
            ) AS assigned_sections_count,
            -- Determine current in-use schedule or section allocation
            COALESCE(
                (
                    SELECT ra.title || ' (' || COALESCE(sub.name, 'General') || ')'
                    FROM public.room_allocations ra
                    LEFT JOIN public.academic_subjects sub ON sub.id = ra.subject_id
                    WHERE ra.room_id = r.id 
                      AND ra.status = 'ACTIVE'
                      AND (
                          (ra.day_of_week = v_current_day AND v_current_time BETWEEN ra.start_time AND ra.end_time)
                          OR (ra.allocation_type = 'EVENT' AND ra.day_of_week = v_current_day)
                      )
                    ORDER BY ra.start_time ASC
                    LIMIT 1
                ),
                (
                    SELECT 'Class ' || c.name || ' (Section ' || s.name || ')'
                    FROM public.academic_sections s
                    JOIN public.academic_classes c ON c.id = s.class_id
                    WHERE s.room_id = r.id AND s.deleted_at IS NULL
                    LIMIT 1
                ),
                '—'
            ) AS in_use_by,
            COALESCE(
                (
                    SELECT TO_CHAR(ra.start_time, 'HH12:MI AM') || ' - ' || TO_CHAR(ra.end_time, 'HH12:MI AM')
                    FROM public.room_allocations ra
                    WHERE ra.room_id = r.id 
                      AND ra.status = 'ACTIVE'
                      AND (
                          (ra.day_of_week = v_current_day AND v_current_time BETWEEN ra.start_time AND ra.end_time)
                          OR (ra.allocation_type = 'EVENT' AND ra.day_of_week = v_current_day)
                      )
                    ORDER BY ra.start_time ASC
                    LIMIT 1
                ),
                '—'
            ) AS timings,
            CASE 
                WHEN r.status = 'MAINTENANCE' THEN 'Under Maintenance'
                WHEN r.status = 'RESERVED' THEN 'Reserved'
                WHEN EXISTS (
                    SELECT 1 FROM public.room_allocations ra
                    WHERE ra.room_id = r.id 
                      AND ra.status = 'ACTIVE'
                      AND ra.day_of_week = v_current_day 
                      AND v_current_time BETWEEN ra.start_time AND ra.end_time
                ) THEN 'In Use'
                WHEN EXISTS (
                    SELECT 1 FROM public.academic_sections s 
                    WHERE s.room_id = r.id AND s.deleted_at IS NULL
                ) THEN 'In Use'
                ELSE 'Available'
            END AS computed_status
        FROM public.academic_rooms r
        WHERE r.school_id = p_school_id
          AND r.deleted_at IS NULL
          AND (
              p_search = '' 
              OR r.name ILIKE '%' || p_search || '%' 
              OR r.code ILIKE '%' || p_search || '%'
              OR r.type ILIKE '%' || p_search || '%'
              OR r.building ILIKE '%' || p_search || '%'
          )
          AND (p_type = 'ALL' OR r.type = p_type)
          AND (p_building = 'ALL' OR r.building = p_building)
          AND (p_floor = 'ALL' OR r.floor = p_floor)
          AND (
              p_status = 'ALL' 
              OR (p_status = 'AVAILABLE' AND r.status = 'AVAILABLE')
              OR (p_status = 'IN_USE' AND (r.status = 'OCCUPIED' OR r.status = 'IN_USE'))
              OR (p_status = 'MAINTENANCE' AND r.status = 'MAINTENANCE')
              OR (p_status = 'RESERVED' AND r.status = 'RESERVED')
              OR (p_status = r.status)
          )
        ORDER BY 
            CASE WHEN p_sort_by = 'name' AND p_sort_order = 'ASC' THEN r.name END ASC,
            CASE WHEN p_sort_by = 'name' AND p_sort_order = 'DESC' THEN r.name END DESC,
            CASE WHEN p_sort_by = 'code' AND p_sort_order = 'ASC' THEN r.code END ASC,
            CASE WHEN p_sort_by = 'code' AND p_sort_order = 'DESC' THEN r.code END DESC,
            CASE WHEN p_sort_by = 'capacity' AND p_sort_order = 'ASC' THEN r.capacity END ASC,
            CASE WHEN p_sort_by = 'capacity' AND p_sort_order = 'DESC' THEN r.capacity END DESC,
            r.building ASC, r.floor ASC, r.name ASC
        LIMIT p_page_size OFFSET v_offset
    ) r_item;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'rooms', v_rooms,
            'total_count', v_total_count,
            'page', p_page,
            'page_size', p_page_size,
            'total_pages', CEIL(v_total_count::NUMERIC / GREATEST(p_page_size, 1)::NUMERIC)
        )
    );
END;
$$;


-- C. Function: Create Academic Room
CREATE OR REPLACE FUNCTION public.fn_create_academic_room(
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
    v_building VARCHAR(100);
    v_floor VARCHAR(50);
    v_capacity INT;
    v_facilities JSONB;
    v_status VARCHAR(30);
    v_description TEXT;
    v_new_id UUID;
    v_exists_code BOOLEAN;
    v_exists_name BOOLEAN;
BEGIN
    v_name := TRIM(p_payload->>'name');
    v_code := UPPER(TRIM(p_payload->>'code'));
    v_type := COALESCE(p_payload->>'type', 'Classroom');
    v_building := COALESCE(p_payload->>'building', 'Academic Block');
    v_floor := COALESCE(p_payload->>'floor', 'Ground Floor');
    v_capacity := COALESCE((p_payload->>'capacity')::INT, 40);
    v_facilities := COALESCE(p_payload->'facilities', '[]'::JSONB);
    v_status := UPPER(COALESCE(p_payload->>'status', 'AVAILABLE'));
    v_description := p_payload->>'description';

    IF v_name IS NULL OR v_name = '' THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Room name is required', 'code', 400);
    END IF;

    IF v_code IS NULL OR v_code = '' THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Room code is required', 'code', 400);
    END IF;

    -- Check duplicate code
    SELECT EXISTS (
        SELECT 1 FROM public.academic_rooms 
        WHERE school_id = p_school_id AND UPPER(code) = v_code AND deleted_at IS NULL
    ) INTO v_exists_code;

    IF v_exists_code THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'A room with code "' || v_code || '" already exists in this school.', 'code', 409);
    END IF;

    -- Check duplicate name
    SELECT EXISTS (
        SELECT 1 FROM public.academic_rooms 
        WHERE school_id = p_school_id AND UPPER(name) = UPPER(v_name) AND deleted_at IS NULL
    ) INTO v_exists_name;

    IF v_exists_name THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'A room with name "' || v_name || '" already exists in this school.', 'code', 409);
    END IF;

    INSERT INTO public.academic_rooms (
        school_id,
        name,
        code,
        type,
        building,
        floor,
        capacity,
        facilities,
        status,
        description,
        created_by,
        updated_by
    ) VALUES (
        p_school_id,
        v_name,
        v_code,
        v_type,
        v_building,
        v_floor,
        v_capacity,
        v_facilities,
        v_status,
        v_description,
        p_user_id,
        p_user_id
    ) RETURNING id INTO v_new_id;

    -- Record Audit Log
    PERFORM public.fn_record_class_audit(
        p_school_id, p_user_id, 'ROOM_CREATED', 'CREATE', 'Room ' || v_name, 'academic_rooms', v_new_id,
        jsonb_build_object('code', v_code, 'type', v_type, 'building', v_building, 'capacity', v_capacity),
        NULL, p_payload
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'id', v_new_id,
            'name', v_name,
            'code', v_code,
            'type', v_type,
            'building', v_building,
            'floor', v_floor,
            'capacity', v_capacity,
            'facilities', v_facilities,
            'status', v_status
        )
    );
END;
$$;


-- D. Function: Update Academic Room
CREATE OR REPLACE FUNCTION public.fn_update_academic_room(
    p_school_id UUID,
    p_user_id UUID,
    p_room_id UUID,
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_room RECORD;
    v_name VARCHAR(150);
    v_code VARCHAR(50);
    v_type VARCHAR(50);
    v_building VARCHAR(100);
    v_floor VARCHAR(50);
    v_capacity INT;
    v_facilities JSONB;
    v_status VARCHAR(30);
    v_description TEXT;
    v_exists BOOLEAN;
BEGIN
    SELECT * INTO v_room
    FROM public.academic_rooms
    WHERE id = p_room_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Room not found', 'code', 404);
    END IF;

    v_name := COALESCE(NULLIF(TRIM(p_payload->>'name'), ''), v_room.name);
    v_code := COALESCE(NULLIF(UPPER(TRIM(p_payload->>'code')), ''), v_room.code);
    v_type := COALESCE(p_payload->>'type', v_room.type);
    v_building := COALESCE(p_payload->>'building', v_room.building);
    v_floor := COALESCE(p_payload->>'floor', v_room.floor);
    v_capacity := COALESCE((p_payload->>'capacity')::INT, v_room.capacity);
    v_facilities := COALESCE(p_payload->'facilities', v_room.facilities);
    v_status := COALESCE(UPPER(p_payload->>'status'), v_room.status);
    v_description := COALESCE(p_payload->>'description', v_room.description);

    -- Check duplicate code if changed
    IF v_code != v_room.code THEN
        SELECT EXISTS (
            SELECT 1 FROM public.academic_rooms 
            WHERE school_id = p_school_id AND UPPER(code) = v_code AND id != p_room_id AND deleted_at IS NULL
        ) INTO v_exists;

        IF v_exists THEN
            RETURN jsonb_build_object('success', FALSE, 'error', 'A room with code "' || v_code || '" already exists.', 'code', 409);
        END IF;
    END IF;

    UPDATE public.academic_rooms SET
        name = v_name,
        code = v_code,
        type = v_type,
        building = v_building,
        floor = v_floor,
        capacity = v_capacity,
        facilities = v_facilities,
        status = v_status,
        description = v_description,
        updated_by = p_user_id,
        updated_at = NOW()
    WHERE id = p_room_id;

    -- Record Audit Log
    PERFORM public.fn_record_class_audit(
        p_school_id, p_user_id, 'ROOM_UPDATED', 'UPDATE', 'Room ' || v_name, 'academic_rooms', p_room_id,
        p_payload, to_jsonb(v_room), p_payload
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'id', p_room_id,
            'name', v_name,
            'code', v_code,
            'type', v_type,
            'building', v_building,
            'floor', v_floor,
            'capacity', v_capacity,
            'facilities', v_facilities,
            'status', v_status
        )
    );
END;
$$;


-- E. Function: Archive Academic Room (Soft Delete with Dependency Checks)
CREATE OR REPLACE FUNCTION public.fn_archive_academic_room(
    p_school_id UUID,
    p_user_id UUID,
    p_room_id UUID,
    p_force BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_room RECORD;
    v_sections_count INT := 0;
    v_allocations_count INT := 0;
BEGIN
    SELECT * INTO v_room
    FROM public.academic_rooms
    WHERE id = p_room_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Room not found', 'code', 404);
    END IF;

    SELECT COUNT(*) INTO v_sections_count
    FROM public.academic_sections
    WHERE room_id = p_room_id AND deleted_at IS NULL;

    SELECT COUNT(*) INTO v_allocations_count
    FROM public.room_allocations
    WHERE room_id = p_room_id AND status = 'ACTIVE';

    IF (v_sections_count > 0 OR v_allocations_count > 0) AND NOT p_force THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Cannot archive room. It is currently assigned as default room to ' || v_sections_count || ' section(s) and has ' || v_allocations_count || ' active schedule allocation(s).',
            'code', 400,
            'impact', jsonb_build_object(
                'sections_count', v_sections_count,
                'allocations_count', v_allocations_count
            )
        );
    END IF;

    -- If force, unassign from sections and cancel allocations
    IF p_force THEN
        UPDATE public.academic_sections 
        SET room_id = NULL, updated_at = NOW() 
        WHERE room_id = p_room_id;

        UPDATE public.room_allocations 
        SET status = 'CANCELLED', updated_at = NOW() 
        WHERE room_id = p_room_id;
    END IF;

    UPDATE public.academic_rooms SET
        status = 'INACTIVE',
        deleted_at = NOW(),
        deleted_by = p_user_id
    WHERE id = p_room_id;

    PERFORM public.fn_record_class_audit(
        p_school_id, p_user_id, 'ROOM_ARCHIVED', 'ARCHIVE', 'Room ' || v_room.name, 'academic_rooms', p_room_id,
        jsonb_build_object('force', p_force, 'unassigned_sections', v_sections_count)
    );

    RETURN jsonb_build_object('success', TRUE, 'message', 'Room archived successfully');
END;
$$;


-- F. Function: Restore Academic Room
CREATE OR REPLACE FUNCTION public.fn_restore_academic_room(
    p_school_id UUID,
    p_user_id UUID,
    p_room_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_room RECORD;
BEGIN
    SELECT * INTO v_room
    FROM public.academic_rooms
    WHERE id = p_room_id AND school_id = p_school_id AND deleted_at IS NOT NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Archived room not found', 'code', 404);
    END IF;

    UPDATE public.academic_rooms SET
        status = 'AVAILABLE',
        deleted_at = NULL,
        deleted_by = NULL,
        updated_at = NOW()
    WHERE id = p_room_id;

    PERFORM public.fn_record_class_audit(
        p_school_id, p_user_id, 'ROOM_RESTORED', 'RESTORE', 'Room ' || v_room.name, 'academic_rooms', p_room_id
    );

    RETURN jsonb_build_object('success', TRUE, 'message', 'Room restored successfully');
END;
$$;


-- G. Function: Check Room & Timetable Conflicts
CREATE OR REPLACE FUNCTION public.fn_check_room_conflicts(
    p_school_id UUID,
    p_room_id UUID,
    p_day_of_week INT,
    p_start_time TIME,
    p_end_time TIME,
    p_academic_year VARCHAR DEFAULT '2026-27',
    p_teacher_id UUID DEFAULT NULL,
    p_section_id UUID DEFAULT NULL,
    p_exclude_allocation_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_room_conflict RECORD;
    v_teacher_conflict RECORD;
    v_section_conflict RECORD;
    v_room_name VARCHAR(150);
BEGIN
    SELECT name INTO v_room_name FROM public.academic_rooms WHERE id = p_room_id;

    -- 1. Check Room Overlap
    SELECT ra.*, c.name as class_name, s.name as section_name, sub.name as subject_name
    INTO v_room_conflict
    FROM public.room_allocations ra
    LEFT JOIN public.academic_classes c ON c.id = ra.class_id
    LEFT JOIN public.academic_sections s ON s.id = ra.section_id
    LEFT JOIN public.academic_subjects sub ON sub.id = ra.subject_id
    WHERE ra.school_id = p_school_id
      AND ra.room_id = p_room_id
      AND ra.academic_year = p_academic_year
      AND ra.day_of_week = p_day_of_week
      AND ra.status = 'ACTIVE'
      AND (p_exclude_allocation_id IS NULL OR ra.id != p_exclude_allocation_id)
      AND (p_start_time < ra.end_time AND p_end_time > ra.start_time)
    LIMIT 1;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'has_conflict', TRUE,
            'conflict_type', 'ROOM',
            'message', 'Room ' || COALESCE(v_room_name, 'selected') || ' is already assigned from ' || 
                       TO_CHAR(v_room_conflict.start_time, 'HH12:MI AM') || ' - ' || TO_CHAR(v_room_conflict.end_time, 'HH12:MI AM') || 
                       ' to Class ' || COALESCE(v_room_conflict.class_name, '') || ' (Section ' || COALESCE(v_room_conflict.section_name, '') || ') for ' || COALESCE(v_room_conflict.subject_name, 'Schedule') || '.',
            'conflicting_details', jsonb_build_object(
                'allocation_id', v_room_conflict.id,
                'class_name', v_room_conflict.class_name,
                'section_name', v_room_conflict.section_name,
                'subject_name', v_room_conflict.subject_name,
                'start_time', v_room_conflict.start_time,
                'end_time', v_room_conflict.end_time
            )
        );
    END IF;

    -- 2. Check Teacher Overlap if teacher specified
    IF p_teacher_id IS NOT NULL THEN
        SELECT ra.*, c.name as class_name, s.name as section_name, sub.name as subject_name, p.full_name as teacher_name
        INTO v_teacher_conflict
        FROM public.room_allocations ra
        JOIN public.profiles p ON p.id = ra.teacher_id
        LEFT JOIN public.academic_classes c ON c.id = ra.class_id
        LEFT JOIN public.academic_sections s ON s.id = ra.section_id
        LEFT JOIN public.academic_subjects sub ON sub.id = ra.subject_id
        WHERE ra.school_id = p_school_id
          AND ra.teacher_id = p_teacher_id
          AND ra.academic_year = p_academic_year
          AND ra.day_of_week = p_day_of_week
          AND ra.status = 'ACTIVE'
          AND (p_exclude_allocation_id IS NULL OR ra.id != p_exclude_allocation_id)
          AND (p_start_time < ra.end_time AND p_end_time > ra.start_time)
        LIMIT 1;

        IF FOUND THEN
            RETURN jsonb_build_object(
                'has_conflict', TRUE,
                'conflict_type', 'TEACHER',
                'message', 'Teacher ' || COALESCE(v_teacher_conflict.teacher_name, 'selected') || ' is already scheduled from ' || 
                           TO_CHAR(v_teacher_conflict.start_time, 'HH12:MI AM') || ' - ' || TO_CHAR(v_teacher_conflict.end_time, 'HH12:MI AM') || 
                           ' with Class ' || COALESCE(v_teacher_conflict.class_name, '') || ' (' || COALESCE(v_teacher_conflict.subject_name, '') || ').',
                'conflicting_details', jsonb_build_object(
                    'teacher_id', p_teacher_id,
                    'teacher_name', v_teacher_conflict.teacher_name,
                    'class_name', v_teacher_conflict.class_name,
                    'start_time', v_teacher_conflict.start_time,
                    'end_time', v_teacher_conflict.end_time
                )
            );
        END IF;
    END IF;

    -- 3. Check Section Overlap if section specified
    IF p_section_id IS NOT NULL THEN
        SELECT ra.*, sub.name as subject_name, r2.name as other_room_name
        INTO v_section_conflict
        FROM public.room_allocations ra
        LEFT JOIN public.academic_subjects sub ON sub.id = ra.subject_id
        LEFT JOIN public.academic_rooms r2 ON r2.id = ra.room_id
        WHERE ra.school_id = p_school_id
          AND ra.section_id = p_section_id
          AND ra.academic_year = p_academic_year
          AND ra.day_of_week = p_day_of_week
          AND ra.status = 'ACTIVE'
          AND (p_exclude_allocation_id IS NULL OR ra.id != p_exclude_allocation_id)
          AND (p_start_time < ra.end_time AND p_end_time > ra.start_time)
        LIMIT 1;

        IF FOUND THEN
            RETURN jsonb_build_object(
                'has_conflict', TRUE,
                'conflict_type', 'SECTION',
                'message', 'This section already has ' || COALESCE(v_section_conflict.subject_name, 'another class') || ' scheduled in ' || COALESCE(v_section_conflict.other_room_name, 'another room') || ' from ' || 
                           TO_CHAR(v_section_conflict.start_time, 'HH12:MI AM') || ' - ' || TO_CHAR(v_section_conflict.end_time, 'HH12:MI AM') || '.',
                'conflicting_details', jsonb_build_object(
                    'section_id', p_section_id,
                    'subject_name', v_section_conflict.subject_name,
                    'other_room_name', v_section_conflict.other_room_name,
                    'start_time', v_section_conflict.start_time,
                    'end_time', v_section_conflict.end_time
                )
            );
        END IF;
    END IF;

    RETURN jsonb_build_object('has_conflict', FALSE, 'message', 'No conflicts detected');
END;
$$;


-- H. Function: Allocate Room / Create Schedule Entry
CREATE OR REPLACE FUNCTION public.fn_allocate_room(
    p_school_id UUID,
    p_user_id UUID,
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_room_id UUID;
    v_academic_year VARCHAR(50);
    v_class_id UUID;
    v_section_id UUID;
    v_subject_id UUID;
    v_teacher_id UUID;
    v_day_of_week INT;
    v_start_time TIME;
    v_end_time TIME;
    v_title VARCHAR(200);
    v_allocation_type VARCHAR(50);
    v_notes TEXT;
    v_conflict_check JSONB;
    v_new_allocation_id UUID;
    v_room_capacity INT;
    v_section_students_count INT;
BEGIN
    v_room_id := (p_payload->>'room_id')::UUID;
    v_academic_year := COALESCE(p_payload->>'academic_year', '2026-27');
    v_class_id := (p_payload->>'class_id')::UUID;
    v_section_id := (p_payload->>'section_id')::UUID;
    v_subject_id := (p_payload->>'subject_id')::UUID;
    v_teacher_id := (p_payload->>'teacher_id')::UUID;
    v_day_of_week := COALESCE((p_payload->>'day_of_week')::INT, 1);
    v_start_time := (p_payload->>'start_time')::TIME;
    v_end_time := (p_payload->>'end_time')::TIME;
    v_title := p_payload->>'title';
    v_allocation_type := COALESCE(p_payload->>'allocation_type', 'TIMETABLE');
    v_notes := p_payload->>'notes';

    IF v_room_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Room ID is required', 'code', 400);
    END IF;

    IF v_start_time >= v_end_time THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'End time must be after start time', 'code', 400);
    END IF;

    -- Check Room Capacity Warning
    SELECT capacity INTO v_room_capacity FROM public.academic_rooms WHERE id = v_room_id;
    IF v_section_id IS NOT NULL THEN
        SELECT COUNT(*) INTO v_section_students_count 
        FROM public.student_class_assignments 
        WHERE section_id = v_section_id AND status = 'ACTIVE';

        IF v_room_capacity IS NOT NULL AND v_section_students_count > v_room_capacity THEN
            -- We can allow with warning in payload or log it
            NULL;
        END IF;
    END IF;

    -- Conflict Check
    v_conflict_check := public.fn_check_room_conflicts(
        p_school_id, v_room_id, v_day_of_week, v_start_time, v_end_time, 
        v_academic_year, v_teacher_id, v_section_id
    );

    IF (v_conflict_check->>'has_conflict')::BOOLEAN THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', v_conflict_check->>'message',
            'code', 409,
            'conflict_details', v_conflict_check->'conflicting_details'
        );
    END IF;

    INSERT INTO public.room_allocations (
        school_id,
        room_id,
        academic_year,
        class_id,
        section_id,
        subject_id,
        teacher_id,
        day_of_week,
        start_time,
        end_time,
        title,
        allocation_type,
        status,
        notes,
        created_by
    ) VALUES (
        p_school_id,
        v_room_id,
        v_academic_year,
        v_class_id,
        v_section_id,
        v_subject_id,
        v_teacher_id,
        v_day_of_week,
        v_start_time,
        v_end_time,
        COALESCE(v_title, 'Room Allocation'),
        v_allocation_type,
        'ACTIVE',
        v_notes,
        p_user_id
    ) RETURNING id INTO v_new_allocation_id;

    PERFORM public.fn_record_class_audit(
        p_school_id, p_user_id, 'ROOM_ALLOCATED', 'ALLOCATE', 'Room Allocation: ' || COALESCE(v_title, 'Schedule'), 'room_allocations', v_new_allocation_id,
        p_payload
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'id', v_new_allocation_id,
            'room_id', v_room_id,
            'title', v_title,
            'day_of_week', v_day_of_week,
            'start_time', v_start_time,
            'end_time', v_end_time
        )
    );
END;
$$;


-- I. Function: Get Subject-Class-Section Mappings (Elective & Optional Offerings Table)
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
                'class_id', c.id,
                'class_name', c.name,
                'class_code', c.code,
                'section_id', s.id,
                'section_name', s.name,
                'section_code', s.code,
                'subject_id', sub.id,
                'subject_name', sub.name,
                'subject_code', sub.code,
                'subject_type', sub.type,
                'is_offered', (csa.id IS NOT NULL),
                'is_optional', (sub.type ILIKE 'Elective' OR sub.type ILIKE 'Optional'),
                'total_section_students', (
                    SELECT COUNT(*) 
                    FROM public.student_class_assignments sca 
                    WHERE sca.section_id = s.id AND sca.status = 'ACTIVE'
                ),
                'enrolled_students_count', (
                    SELECT COUNT(*) 
                    FROM public.student_subject_enrollments sse 
                    WHERE sse.section_id = s.id AND sse.subject_id = sub.id AND sse.status = 'ACTIVE'
                ),
                'assigned_teachers', (
                    SELECT COALESCE(
                        jsonb_agg(
                            jsonb_build_object(
                                'id', p.id,
                                'full_name', p.full_name,
                                'email', p.email,
                                'avatar_url', p.avatar_url,
                                'is_primary', sst.is_primary
                            )
                        ),
                        '[]'::JSONB
                    )
                    FROM public.section_subject_teachers sst
                    JOIN public.profiles p ON p.id = sst.teacher_id
                    WHERE sst.section_id = s.id AND sst.subject_id = sub.id AND sst.status = 'ACTIVE'
                ),
                'status', CASE WHEN csa.id IS NOT NULL THEN 'ACTIVE' ELSE 'NOT_OFFERED' END
            ) ORDER BY c.display_order ASC, s.name ASC
        ),
        '[]'::JSONB
    ) INTO v_mappings
    FROM public.academic_classes c
    JOIN public.academic_sections s ON s.class_id = c.id AND s.deleted_at IS NULL
    CROSS JOIN public.academic_subjects sub
    LEFT JOIN public.class_subject_assignments csa 
        ON (csa.class_id = c.id AND (csa.section_id = s.id OR csa.section_id IS NULL) AND csa.subject_id = sub.id)
    WHERE c.school_id = p_school_id
      AND c.academic_year = p_academic_year
      AND c.deleted_at IS NULL
      AND sub.deleted_at IS NULL
      AND (p_subject_id IS NULL OR sub.id = p_subject_id);

    RETURN jsonb_build_object('success', TRUE, 'data', v_mappings);
END;
$$;


-- J. Function: Manage Section Subject Teachers (Assign specific teacher(s) to Subject + Section)
CREATE OR REPLACE FUNCTION public.fn_manage_section_subject_teachers(
    p_school_id UUID,
    p_user_id UUID,
    p_class_id UUID,
    p_section_ids UUID[],
    p_subject_id UUID,
    p_teacher_id UUID,
    p_academic_year VARCHAR DEFAULT '2026-27'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sec_id UUID;
BEGIN
    IF p_teacher_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Teacher ID is required', 'code', 400);
    END IF;

    IF p_subject_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Subject ID is required', 'code', 400);
    END IF;

    FOREACH v_sec_id IN ARRAY p_section_ids LOOP
        -- Deactivate existing assignments for this section + subject if replacing, or insert
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
        p_school_id, p_user_id, 'TEACHER_ASSIGNED_TO_SECTION_SUBJECT', 'ASSIGN', 'Subject Teacher Assignment', 'section_subject_teachers', p_subject_id,
        jsonb_build_object('teacher_id', p_teacher_id, 'section_ids', p_section_ids, 'subject_id', p_subject_id)
    );

    RETURN jsonb_build_object('success', TRUE, 'message', 'Teacher successfully assigned to selected sections for this subject.');
END;
$$;


-- K. Function: Manage Student Subject Enrollments (Optional Subject Enrollment)
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
    SET status = 'DROPPED'
    WHERE school_id = p_school_id 
      AND academic_year = p_academic_year
      AND section_id = p_section_id
      AND subject_id = p_subject_id
      AND NOT (student_id = ANY(p_student_ids));

    -- Insert or reactivate selected students
    FOREACH v_stu_id IN ARRAY p_student_ids LOOP
        INSERT INTO public.student_subject_enrollments (
            school_id, academic_year, class_id, section_id, subject_id, student_id, status
        ) VALUES (
            p_school_id, p_academic_year, p_class_id, p_section_id, p_subject_id, v_stu_id, 'ACTIVE'
        )
        ON CONFLICT (school_id, academic_year, section_id, subject_id, student_id)
        DO UPDATE SET status = 'ACTIVE';
    END LOOP;

    PERFORM public.fn_record_class_audit(
        p_school_id, p_user_id, 'STUDENTS_ENROLLED_IN_OPTIONAL_SUBJECT', 'ENROLL', 'Student Subject Enrollment', 'student_subject_enrollments', p_subject_id,
        jsonb_build_object('enrolled_count', array_length(p_student_ids, 1), 'section_id', p_section_id, 'subject_id', p_subject_id)
    );

    RETURN jsonb_build_object(
        'success', TRUE, 
        'message', 'Student optional subject enrollments updated successfully.',
        'enrolled_count', COALESCE(array_length(p_student_ids, 1), 0)
    );
END;
$$;
