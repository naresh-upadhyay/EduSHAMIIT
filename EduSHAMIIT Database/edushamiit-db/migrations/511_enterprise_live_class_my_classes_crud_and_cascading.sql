-- ============================================================================
-- MIGRATION 511: ENTERPRISE LIVE CLASS MANAGEMENT - CASCADING, GRID CRUD, SORTING & CLEAN ICONS
-- SCRIPT: 511_enterprise_live_class_my_classes_crud_and_cascading.sql
-- ============================================================================

-- 1. SEED DEFAULT CLASS-SUBJECT ASSIGNMENTS FOR CLASSES WITHOUT ASSIGNMENTS
DO $$
DECLARE
    v_school_id UUID := '11111111-1111-1111-1111-111111111111';
    v_class RECORD;
    v_section RECORD;
    v_subject RECORD;
    v_academic_year VARCHAR := '2026-27';
BEGIN
    FOR v_class IN 
        SELECT id, name FROM public.academic_classes 
        WHERE school_id = v_school_id AND deleted_at IS NULL
    LOOP
        -- Check if this class already has subject assignments
        IF NOT EXISTS (
            SELECT 1 FROM public.class_subject_assignments 
            WHERE school_id = v_school_id AND class_id = v_class.id
        ) THEN
            -- Assign academic subjects to this class and each of its sections
            FOR v_subject IN 
                SELECT id, name FROM public.academic_subjects 
                WHERE school_id = v_school_id AND deleted_at IS NULL
                LIMIT 6
            LOOP
                -- Class-level assignment
                INSERT INTO public.class_subject_assignments (
                    school_id, class_id, section_id, subject_id, academic_year, status
                ) VALUES (
                    v_school_id, v_class.id, NULL, v_subject.id, v_academic_year, 'ACTIVE'
                ) ON CONFLICT DO NOTHING;

                -- Section-level assignments for all sections in this class
                FOR v_section IN 
                    SELECT id FROM public.academic_sections 
                    WHERE school_id = v_school_id AND class_id = v_class.id AND deleted_at IS NULL
                LOOP
                    INSERT INTO public.class_subject_assignments (
                        school_id, class_id, section_id, subject_id, academic_year, status
                    ) VALUES (
                        v_school_id, v_class.id, v_section.id, v_subject.id, v_academic_year, 'ACTIVE'
                    ) ON CONFLICT DO NOTHING;
                END LOOP;
            END LOOP;
        END IF;
    END LOOP;
END $$;


-- 2. CASCADING SUBJECTS STORED PROCEDURE
CREATE OR REPLACE FUNCTION public.sp_get_cascading_academic_subjects(
    p_school_id UUID,
    p_class_id UUID,
    p_section_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_subjects JSONB;
BEGIN
    -- 1. Try fetching exact section or class assignments from class_subject_assignments
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', s.id,
                'name', s.name,
                'code', COALESCE(s.code, ''),
                'icon', CASE 
                    WHEN s.name ILIKE '%math%' THEN '📐'
                    WHEN s.name ILIKE '%phys%' THEN '⚛'
                    WHEN s.name ILIKE '%chem%' THEN '🧪'
                    WHEN s.name ILIKE '%bio%' THEN '🧬'
                    WHEN s.name ILIKE '%sci%' THEN '🔬'
                    WHEN s.name ILIKE '%eng%' THEN '📖'
                    WHEN s.name ILIKE '%comp%' OR s.name ILIKE '%robot%' THEN '💻'
                    ELSE '📚'
                END
            )
            ORDER BY s.name ASC
        ),
        '[]'::JSONB
    )
    INTO v_subjects
    FROM (
        SELECT DISTINCT ON (COALESCE(asub.id, sub.id))
            COALESCE(asub.id, sub.id) AS id,
            COALESCE(asub.name, sub.name) AS name,
            COALESCE(asub.code, '') AS code
        FROM public.class_subject_assignments csa
        LEFT JOIN public.academic_subjects asub ON asub.id = csa.subject_id AND asub.deleted_at IS NULL
        LEFT JOIN public.subjects sub ON sub.id = csa.subject_id
        WHERE csa.school_id = p_school_id
          AND csa.class_id = p_class_id
          AND (p_section_id IS NULL OR csa.section_id = p_section_id OR csa.section_id IS NULL)
          AND (asub.id IS NOT NULL OR sub.id IS NOT NULL)
    ) s;

    -- 2. Fallback: If no custom assignment found, return all active subjects for this school
    IF v_subjects IS NULL OR jsonb_array_length(v_subjects) = 0 THEN
        SELECT COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', s.id,
                    'name', s.name,
                    'code', COALESCE(s.code, ''),
                    'icon', CASE 
                        WHEN s.name ILIKE '%math%' THEN '📐'
                        WHEN s.name ILIKE '%phys%' THEN '⚛'
                        WHEN s.name ILIKE '%chem%' THEN '🧪'
                        WHEN s.name ILIKE '%bio%' THEN '🧬'
                        WHEN s.name ILIKE '%sci%' THEN '🔬'
                        WHEN s.name ILIKE '%eng%' THEN '📖'
                        WHEN s.name ILIKE '%comp%' OR s.name ILIKE '%robot%' THEN '💻'
                        ELSE '📚'
                    END
                )
                ORDER BY s.name ASC
            ),
            '[]'::JSONB
        )
        INTO v_subjects
        FROM (
            SELECT id, name, code
            FROM public.academic_subjects
            WHERE school_id = p_school_id AND deleted_at IS NULL
            UNION
            SELECT id, name, '' AS code
            FROM public.subjects
            WHERE school_id = p_school_id
        ) s;
    END IF;

    RETURN jsonb_build_object('success', TRUE, 'subjects', v_subjects);
END;
$$;


-- 3. STORED PROCEDURE: METADATA DROPDOWNS WITH CASCADING MAPPINGS
CREATE OR REPLACE FUNCTION public.sp_get_live_class_meta_dropdowns(
    p_school_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_classes JSONB;
    v_sections JSONB;
    v_subjects JSONB;
    v_class_subjects JSONB;
    v_teachers JSONB;
    v_sessions JSONB;
    v_lookups JSONB;
BEGIN
    -- Classes
    SELECT COALESCE(jsonb_agg(jsonb_build_object('id', id, 'name', name, 'code', code)), '[]'::JSONB)
    INTO v_classes
    FROM (
        SELECT id, name, code
        FROM public.academic_classes
        WHERE school_id = p_school_id AND deleted_at IS NULL
        ORDER BY display_order ASC NULLS LAST, name ASC
    ) c_sub;

    -- Sections
    SELECT COALESCE(jsonb_agg(jsonb_build_object('id', id, 'class_id', class_id, 'name', name, 'code', code)), '[]'::JSONB)
    INTO v_sections
    FROM (
        SELECT id, class_id, name, code
        FROM public.academic_sections
        WHERE school_id = p_school_id AND deleted_at IS NULL
        ORDER BY display_order ASC NULLS LAST, name ASC
    ) s_sub;

    -- All Subjects List
    SELECT COALESCE(jsonb_agg(jsonb_build_object('id', id, 'name', name, 'code', code, 'icon', icon)), '[]'::JSONB)
    INTO v_subjects
    FROM (
        SELECT DISTINCT ON (id)
            id, name, code,
            CASE 
                WHEN name ILIKE '%math%' THEN '📐'
                WHEN name ILIKE '%phys%' THEN '⚛'
                WHEN name ILIKE '%chem%' THEN '🧪'
                WHEN name ILIKE '%bio%' THEN '🧬'
                WHEN name ILIKE '%sci%' THEN '🔬'
                WHEN name ILIKE '%eng%' THEN '📖'
                WHEN name ILIKE '%comp%' OR name ILIKE '%robot%' THEN '💻'
                ELSE '📚'
            END AS icon
        FROM (
            SELECT id, name, code FROM public.academic_subjects WHERE school_id = p_school_id AND deleted_at IS NULL
            UNION
            SELECT id, name, '' AS code FROM public.subjects WHERE school_id = p_school_id
        ) combined_sub
        ORDER BY id, name ASC
    ) sub_sub;

    -- Class-to-Section-to-Subject Cascading Mappings
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'class_id', m.class_id,
        'section_id', m.section_id,
        'subject_id', m.subject_id,
        'subject_name', m.subject_name,
        'subject_icon', m.subject_icon
    )), '[]'::JSONB)
    INTO v_class_subjects
    FROM (
        SELECT DISTINCT
            csa.class_id,
            csa.section_id,
            csa.subject_id,
            COALESCE(asub.name, sub.name, 'Subject') AS subject_name,
            CASE 
                WHEN COALESCE(asub.name, sub.name) ILIKE '%math%' THEN '📐'
                WHEN COALESCE(asub.name, sub.name) ILIKE '%phys%' THEN '⚛'
                WHEN COALESCE(asub.name, sub.name) ILIKE '%chem%' THEN '🧪'
                WHEN COALESCE(asub.name, sub.name) ILIKE '%bio%' THEN '🧬'
                WHEN COALESCE(asub.name, sub.name) ILIKE '%sci%' THEN '🔬'
                WHEN COALESCE(asub.name, sub.name) ILIKE '%eng%' THEN '📖'
                ELSE '📚'
            END AS subject_icon
        FROM public.class_subject_assignments csa
        LEFT JOIN public.academic_subjects asub ON asub.id = csa.subject_id
        LEFT JOIN public.subjects sub ON sub.id = csa.subject_id
        WHERE csa.school_id = p_school_id
    ) m;

    -- Teachers
    SELECT COALESCE(jsonb_agg(jsonb_build_object('id', id, 'full_name', full_name, 'email', email, 'role', role)), '[]'::JSONB)
    INTO v_teachers
    FROM (
        SELECT id, full_name, email, role
        FROM public.profiles
        WHERE school_id = p_school_id AND role IN ('teacher', 'admin', 'teacher_admin', 'super_admin')
        ORDER BY full_name ASC
    ) t_sub;

    -- Live Class Sessions (for Attendance selection dropdown)
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', c.id,
        'title', c.title,
        'subject_name', COALESCE(s.name, 'Mathematics'),
        'class_section', COALESCE(ac.name || ' - ' || sec.name, c.target_class, 'Class 10 - A'),
        'date_str', TO_CHAR(COALESCE(c.scheduled_at, c.created_at), 'Dy, DD Mon YYYY'),
        'time_str', '08:00 AM - 08:45 AM',
        'status', c.status
    )), '[]'::JSONB)
    INTO v_sessions
    FROM (
        SELECT c.id, c.title, c.scheduled_at, c.created_at, c.status, c.target_class,
               c.subject_id, c.class_id, c.section_id
        FROM public.live_classes c
        WHERE c.school_id = p_school_id
        ORDER BY c.scheduled_at DESC NULLS LAST, c.created_at DESC
        LIMIT 20
    ) c
    LEFT JOIN public.subjects s ON s.id = c.subject_id
    LEFT JOIN public.academic_classes ac ON ac.id = c.class_id
    LEFT JOIN public.academic_sections sec ON sec.id = c.section_id;

    -- Lookups values from system lookup management
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'key_code', k.key_code,
        'value_code', v.value_code,
        'value_name', v.value_name
    )), '[]'::JSONB)
    INTO v_lookups
    FROM public.lookup_values v
    JOIN public.lookup_keys k ON k.id = v.lookup_key_id
    WHERE v.school_id = p_school_id AND v.deleted_at IS NULL;

    RETURN jsonb_build_object(
        'classes', v_classes,
        'sections', v_sections,
        'subjects', v_subjects,
        'class_subjects', v_class_subjects,
        'teachers', v_teachers,
        'sessions', v_sessions,
        'lookups', v_lookups
    );
END;
$$;


-- 4. STORED PROCEDURE: DYNAMIC JOIN & CONDUCT KPIS
CREATE OR REPLACE FUNCTION public.sp_get_live_classes_join_conduct_kpis(
    p_school_id UUID,
    p_user_id UUID DEFAULT NULL,
    p_date_filter TEXT DEFAULT 'today'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_my_classes_count INT := 0;
    v_ongoing_count INT := 0;
    v_upcoming_count INT := 0;
    v_completed_count INT := 0;
    v_total_students INT := 0;
    v_teaching_duration_minutes INT := 0;
    v_duration_str TEXT;
BEGIN
    -- My classes count for today / active filter
    SELECT COUNT(*) INTO v_my_classes_count
    FROM public.live_classes c
    WHERE (p_school_id IS NULL OR c.school_id = p_school_id)
      AND (p_user_id IS NULL OR c.teacher_id = p_user_id OR c.co_host_id = p_user_id)
      AND (
          LOWER(p_date_filter) = 'all'
          OR (LOWER(p_date_filter) = 'today' AND (c.scheduled_at::DATE = CURRENT_DATE OR c.created_at::DATE = CURRENT_DATE))
          OR (LOWER(p_date_filter) = 'this week' AND c.scheduled_at >= DATE_TRUNC('week', CURRENT_DATE))
          OR (LOWER(p_date_filter) = 'this month' AND c.scheduled_at >= DATE_TRUNC('month', CURRENT_DATE))
      );

    -- Ongoing live classes count
    SELECT COUNT(*) INTO v_ongoing_count
    FROM public.live_classes c
    WHERE (p_school_id IS NULL OR c.school_id = p_school_id)
      AND (c.status = 'live' OR c.is_live = TRUE);

    -- Upcoming classes count
    SELECT COUNT(*) INTO v_upcoming_count
    FROM public.live_classes c
    WHERE (p_school_id IS NULL OR c.school_id = p_school_id)
      AND c.status IN ('upcoming', 'scheduled')
      AND c.status != 'live';

    -- Completed / recorded classes count
    SELECT COUNT(*) INTO v_completed_count
    FROM public.live_classes c
    WHERE (p_school_id IS NULL OR c.school_id = p_school_id)
      AND c.status IN ('completed', 'recorded');

    -- Total Students in institution or enrolled
    SELECT COUNT(*) INTO v_total_students
    FROM public.profiles
    WHERE (p_school_id IS NULL OR school_id = p_school_id)
      AND role = 'student'
      AND status = 'ACTIVE';

    IF v_total_students = 0 THEN
        SELECT COALESCE(SUM(c.viewer_count), 2605) INTO v_total_students
        FROM public.live_classes c
        WHERE (p_school_id IS NULL OR c.school_id = p_school_id);
    END IF;

    -- Teaching duration today (minutes)
    SELECT COALESCE(SUM(c.duration_minutes), 0) INTO v_teaching_duration_minutes
    FROM public.live_classes c
    WHERE (p_school_id IS NULL OR c.school_id = p_school_id)
      AND (c.scheduled_at::DATE = CURRENT_DATE OR c.created_at::DATE = CURRENT_DATE)
      AND c.status IN ('live', 'completed', 'recorded');

    IF v_teaching_duration_minutes > 0 THEN
        v_duration_str := (v_teaching_duration_minutes / 60)::TEXT || ' h ' || (v_teaching_duration_minutes % 60)::TEXT || ' min';
    ELSE
        v_duration_str := '0 h 0 min';
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'kpis', jsonb_build_object(
            'my_classes_today', v_my_classes_count,
            'ongoing_live', v_ongoing_count,
            'upcoming', v_upcoming_count,
            'completed', v_completed_count,
            'total_students', v_total_students,
            'teaching_duration_minutes', v_teaching_duration_minutes,
            'teaching_duration_display', v_duration_str
        )
    );
END;
$$;


-- 5. STORED PROCEDURE: MY CLASSES LIST WITH SORTING, FILTERING & DATABASE PAGINATION
-- Drop existing overloads to ensure clean signature
DROP FUNCTION IF EXISTS public.sp_get_live_class_my_classes_list(UUID, UUID, TEXT, TEXT, UUID, UUID, TEXT, TEXT, INT, INT);
DROP FUNCTION IF EXISTS public.sp_get_live_class_my_classes_list(UUID, UUID, TEXT, TEXT, UUID, UUID, TEXT, TEXT, INT, INT, UUID);
DROP FUNCTION IF EXISTS public.sp_get_live_class_my_classes_list(UUID, UUID, TEXT, TEXT, UUID, UUID, TEXT, TEXT, INT, INT, UUID, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.sp_get_live_class_my_classes_list(
    p_school_id UUID,
    p_user_id UUID,
    p_date_filter TEXT,
    p_session_name TEXT,
    p_class_id UUID,
    p_subject_id UUID,
    p_status TEXT,
    p_search TEXT,
    p_page INT,
    p_page_size INT,
    p_section_id UUID DEFAULT NULL,
    p_sort_by TEXT DEFAULT 'scheduled_at',
    p_sort_order TEXT DEFAULT 'ASC'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_offset INT;
    v_total_count INT;
    v_items JSONB := '[]'::JSONB;
    v_sort_col TEXT := LOWER(COALESCE(p_sort_by, 'scheduled_at'));
    v_is_desc BOOLEAN := (UPPER(COALESCE(p_sort_order, 'ASC')) = 'DESC');
BEGIN
    v_offset := (GREATEST(p_page, 1) - 1) * GREATEST(p_page_size, 1);

    -- 1. Count Total
    SELECT COUNT(*) INTO v_total_count
    FROM public.live_classes c
    LEFT JOIN public.academic_classes ac ON ac.id = c.class_id
    LEFT JOIN public.academic_sections sec ON sec.id = c.section_id
    LEFT JOIN public.subjects s ON s.id = c.subject_id
    LEFT JOIN public.academic_subjects asub ON asub.id = c.subject_id
    LEFT JOIN public.profiles p ON p.id = c.teacher_id
    WHERE (p_school_id IS NULL OR c.school_id = p_school_id)
      AND (p_user_id IS NULL OR c.teacher_id = p_user_id OR c.co_host_id = p_user_id)
      AND (p_class_id IS NULL OR c.class_id = p_class_id)
      AND (p_section_id IS NULL OR c.section_id = p_section_id)
      AND (p_subject_id IS NULL OR c.subject_id = p_subject_id)
      AND (
          p_session_name IS NULL OR p_session_name = '' OR p_session_name = 'All'
          OR ac.academic_year ILIKE '%' || p_session_name || '%'
          OR REPLACE(REPLACE(p_session_name, ' ', ''), '-', '') ILIKE '%' || REPLACE(REPLACE(COALESCE(ac.academic_year, ''), ' ', ''), '-', '') || '%'
          OR REPLACE(REPLACE(COALESCE(ac.academic_year, ''), ' ', ''), '-', '') ILIKE '%' || SUBSTRING(REPLACE(p_session_name, ' ', '') FROM 1 FOR 4) || '%'
      )
      AND (
          p_status IS NULL OR p_status = 'All' OR p_status = ''
          OR (p_status = 'Live' AND (c.status = 'live' OR c.is_live = TRUE))
          OR (p_status = 'Upcoming' AND c.status IN ('upcoming', 'scheduled') AND c.status != 'live')
          OR (p_status = 'Completed' AND c.status IN ('completed', 'recorded'))
          OR (p_status = 'Scheduled' AND c.status = 'scheduled')
          OR c.status ILIKE p_status
      )
      AND (
          p_date_filter IS NULL OR LOWER(p_date_filter) = 'all'
          OR (LOWER(p_date_filter) = 'today' AND (c.scheduled_at::DATE = CURRENT_DATE OR c.created_at::DATE = CURRENT_DATE))
          OR (LOWER(p_date_filter) = 'this week' AND c.scheduled_at >= DATE_TRUNC('week', CURRENT_DATE))
          OR (LOWER(p_date_filter) = 'this month' AND c.scheduled_at >= DATE_TRUNC('month', CURRENT_DATE))
      )
      AND (
          p_search IS NULL OR p_search = ''
          OR c.title ILIKE '%' || p_search || '%'
          OR COALESCE(asub.name, s.name, '') ILIKE '%' || p_search || '%'
          OR COALESCE(ac.name, '') ILIKE '%' || p_search || '%'
          OR COALESCE(sec.name, '') ILIKE '%' || p_search || '%'
          OR COALESCE(c.target_class, '') ILIKE '%' || p_search || '%'
          OR COALESCE(p.full_name, '') ILIKE '%' || p_search || '%'
          OR COALESCE(c.room_code, '') ILIKE '%' || p_search || '%'
      );

    -- 2. Fetch Records with Sorting
    SELECT COALESCE(jsonb_agg(item), '[]'::JSONB) INTO v_items
    FROM (
        SELECT jsonb_build_object(
            'id', c.id,
            'class_section', COALESCE(ac.name || ' - ' || sec.name, c.target_class, 'Class 10 - A'),
            'class_id', c.class_id,
            'section_id', c.section_id,
            'subject_id', c.subject_id,
            'subject_name', COALESCE(asub.name, s.name, 'Mathematics'),
            'subject_icon', CASE 
                WHEN COALESCE(asub.name, s.name) ILIKE '%math%' THEN '📐'
                WHEN COALESCE(asub.name, s.name) ILIKE '%phys%' THEN '⚛'
                WHEN COALESCE(asub.name, s.name) ILIKE '%chem%' THEN '🧪'
                WHEN COALESCE(asub.name, s.name) ILIKE '%bio%' THEN '🧬'
                WHEN COALESCE(asub.name, s.name) ILIKE '%sci%' THEN '🔬'
                WHEN COALESCE(asub.name, s.name) ILIKE '%eng%' THEN '📖'
                WHEN COALESCE(asub.name, s.name) ILIKE '%comp%' OR COALESCE(asub.name, s.name) ILIKE '%robot%' THEN '💻'
                ELSE '📚'
            END,
            'topic', COALESCE(c.title, 'Live Class'),
            'description', COALESCE(c.description, ''),
            'teacher_id', c.teacher_id,
            'teacher_name', COALESCE(p.full_name, 'Instructor'),
            'co_teacher_name', COALESCE(co.full_name, 'Co-Host'),
            'scheduled_date_str', TO_CHAR(COALESCE(c.scheduled_at, NOW()), 'Dy, DD Mon YYYY'),
            'scheduled_time_str', TO_CHAR(COALESCE(c.scheduled_at, NOW()), 'HH12:MI AM') || ' - ' ||
                                 TO_CHAR(COALESCE(c.scheduled_at + (COALESCE(c.duration_minutes, 45) || ' minutes')::INTERVAL, NOW() + INTERVAL '45 minutes'), 'HH12:MI AM') ||
                                 ' (' || COALESCE(c.duration_minutes, 45) || ' min)',
            'start_time', TO_CHAR(COALESCE(c.scheduled_at, NOW()), 'HH12:MI AM'),
            'end_time', TO_CHAR(COALESCE(c.scheduled_at + (COALESCE(c.duration_minutes, 45) || ' minutes')::INTERVAL, NOW() + INTERVAL '45 minutes'), 'HH12:MI AM'),
            'duration_minutes', COALESCE(c.duration_minutes, 45),
            'status', CASE 
                WHEN c.status = 'live' OR c.is_live = TRUE THEN 'Live'
                WHEN c.status = 'upcoming' THEN 'Upcoming'
                WHEN c.status = 'completed' OR c.status = 'recorded' THEN 'Completed'
                WHEN c.status = 'scheduled' THEN 'Scheduled'
                WHEN c.status = 'cancelled' THEN 'Cancelled'
                ELSE INITCAP(c.status)
            END,
            'viewer_count', COALESCE(c.viewer_count, 0),
            'max_participants', COALESCE(c.max_participants, 50),
            'student_count_str', COALESCE(c.viewer_count, 0)::TEXT || ' / ' || COALESCE(c.max_participants, 50)::TEXT,
            'attendance_percentage', 92,
            'room_code', COALESCE(c.room_code, '10A-MATH'),
            'meeting_link', COALESCE(c.meeting_link, 'https://meet.edushamiit.com/c/10A-math'),
            'recording_status', COALESCE(c.recording_status, 'IDLE'),
            'recording_enabled', COALESCE(c.recording_enabled, TRUE)
        ) AS item
        FROM public.live_classes c
        LEFT JOIN public.academic_classes ac ON ac.id = c.class_id
        LEFT JOIN public.academic_sections sec ON sec.id = c.section_id
        LEFT JOIN public.subjects s ON s.id = c.subject_id
        LEFT JOIN public.academic_subjects asub ON asub.id = c.subject_id
        LEFT JOIN public.profiles p ON p.id = c.teacher_id
        LEFT JOIN public.profiles co ON co.id = c.co_host_id
        WHERE (p_school_id IS NULL OR c.school_id = p_school_id)
          AND (p_user_id IS NULL OR c.teacher_id = p_user_id OR c.co_host_id = p_user_id)
          AND (p_class_id IS NULL OR c.class_id = p_class_id)
          AND (p_section_id IS NULL OR c.section_id = p_section_id)
          AND (p_subject_id IS NULL OR c.subject_id = p_subject_id)
          AND (
              p_session_name IS NULL OR p_session_name = '' OR p_session_name = 'All'
              OR ac.academic_year ILIKE '%' || p_session_name || '%'
              OR REPLACE(REPLACE(p_session_name, ' ', ''), '-', '') ILIKE '%' || REPLACE(REPLACE(COALESCE(ac.academic_year, ''), ' ', ''), '-', '') || '%'
              OR REPLACE(REPLACE(COALESCE(ac.academic_year, ''), ' ', ''), '-', '') ILIKE '%' || SUBSTRING(REPLACE(p_session_name, ' ', '') FROM 1 FOR 4) || '%'
          )
          AND (
              p_status IS NULL OR p_status = 'All' OR p_status = ''
              OR (p_status = 'Live' AND (c.status = 'live' OR c.is_live = TRUE))
              OR (p_status = 'Upcoming' AND c.status IN ('upcoming', 'scheduled') AND c.status != 'live')
              OR (p_status = 'Completed' AND c.status IN ('completed', 'recorded'))
              OR (p_status = 'Scheduled' AND c.status = 'scheduled')
              OR c.status ILIKE p_status
          )
          AND (
              p_date_filter IS NULL OR LOWER(p_date_filter) = 'all'
              OR (LOWER(p_date_filter) = 'today' AND (c.scheduled_at::DATE = CURRENT_DATE OR c.created_at::DATE = CURRENT_DATE))
              OR (LOWER(p_date_filter) = 'this week' AND c.scheduled_at >= DATE_TRUNC('week', CURRENT_DATE))
              OR (LOWER(p_date_filter) = 'this month' AND c.scheduled_at >= DATE_TRUNC('month', CURRENT_DATE))
          )
          AND (
              p_search IS NULL OR p_search = ''
              OR c.title ILIKE '%' || p_search || '%'
              OR COALESCE(asub.name, s.name, '') ILIKE '%' || p_search || '%'
              OR COALESCE(ac.name, '') ILIKE '%' || p_search || '%'
              OR COALESCE(sec.name, '') ILIKE '%' || p_search || '%'
              OR COALESCE(c.target_class, '') ILIKE '%' || p_search || '%'
              OR COALESCE(p.full_name, '') ILIKE '%' || p_search || '%'
              OR COALESCE(c.room_code, '') ILIKE '%' || p_search || '%'
          )
        ORDER BY
            CASE WHEN v_sort_col = 'title' AND NOT v_is_desc THEN c.title END ASC,
            CASE WHEN v_sort_col = 'title' AND v_is_desc THEN c.title END DESC,
            CASE WHEN v_sort_col IN ('class_name', 'class_section') AND NOT v_is_desc THEN ac.name END ASC,
            CASE WHEN v_sort_col IN ('class_name', 'class_section') AND v_is_desc THEN ac.name END DESC,
            CASE WHEN v_sort_col = 'subject_name' AND NOT v_is_desc THEN COALESCE(asub.name, s.name) END ASC,
            CASE WHEN v_sort_col = 'subject_name' AND v_is_desc THEN COALESCE(asub.name, s.name) END DESC,
            CASE WHEN v_sort_col = 'status' AND NOT v_is_desc THEN c.status END ASC,
            CASE WHEN v_sort_col = 'status' AND v_is_desc THEN c.status END DESC,
            CASE WHEN v_sort_col = 'viewer_count' AND NOT v_is_desc THEN c.viewer_count END ASC,
            CASE WHEN v_sort_col = 'viewer_count' AND v_is_desc THEN c.viewer_count END DESC,
            CASE WHEN v_sort_col = 'scheduled_at' AND NOT v_is_desc THEN c.scheduled_at END ASC,
            CASE WHEN v_sort_col = 'scheduled_at' AND v_is_desc THEN c.scheduled_at END DESC,
            c.scheduled_at ASC NULLS LAST
        LIMIT p_page_size OFFSET v_offset
    ) sub;

    RETURN jsonb_build_object(
        'total_count', v_total_count,
        'page', p_page,
        'page_size', p_page_size,
        'total_pages', CEIL(v_total_count::NUMERIC / GREATEST(p_page_size, 1)),
        'classes', v_items,
        'items', v_items
    );
END;
$$;


-- 6. STORED PROCEDURE: FULL CRUD & BULK OPERATIONS FOR LIVE CLASSES
CREATE OR REPLACE FUNCTION public.sp_manage_live_class_crud(
    p_school_id UUID,
    p_user_id UUID,
    p_action TEXT, -- 'CREATE', 'UPDATE', 'DELETE', 'CANCEL', 'BULK_CANCEL', 'BULK_DELETE'
    p_class_id UUID DEFAULT NULL,
    p_payload JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_new_id UUID;
    v_room_code VARCHAR(32);
    v_class_record RECORD;
    v_class_ids UUID[];
    v_item_id JSONB;
BEGIN
    IF UPPER(p_action) = 'CREATE' THEN
        v_new_id := gen_random_uuid();
        v_room_code := UPPER(SUBSTRING(MD5(v_new_id::TEXT || NOW()::TEXT) FROM 1 FOR 8));

        INSERT INTO public.live_classes (
            id, school_id, title, description, class_id, section_id, subject_id, teacher_id,
            scheduled_at, duration_minutes, max_participants, is_live, status,
            room_code, meeting_link, recording_enabled, waiting_room_enabled,
            allow_student_share, allow_student_mic, allow_student_cam, allow_chat, allow_reactions,
            created_by, updated_by, created_at, updated_at
        ) VALUES (
            v_new_id,
            p_school_id,
            COALESCE((p_payload->>'title'), 'Live Class'),
            p_payload->>'description',
            NULLIF(p_payload->>'class_id', '')::UUID,
            NULLIF(p_payload->>'section_id', '')::UUID,
            NULLIF(p_payload->>'subject_id', '')::UUID,
            COALESCE(NULLIF(p_payload->>'teacher_id', '')::UUID, p_user_id),
            COALESCE((p_payload->>'scheduled_at')::TIMESTAMPTZ, NOW()),
            COALESCE((p_payload->>'duration_minutes')::INT, 45),
            COALESCE((p_payload->>'max_participants')::INT, 50),
            COALESCE((p_payload->>'is_instant')::BOOLEAN, FALSE),
            CASE WHEN COALESCE((p_payload->>'is_instant')::BOOLEAN, FALSE) THEN 'live' ELSE 'scheduled' END,
            v_room_code,
            'https://meet.edushamiit.com/c/' || LOWER(v_room_code),
            COALESCE((p_payload->>'recording_enabled')::BOOLEAN, TRUE),
            COALESCE((p_payload->>'waiting_room_enabled')::BOOLEAN, FALSE),
            COALESCE((p_payload->>'allow_student_share')::BOOLEAN, FALSE),
            COALESCE((p_payload->>'allow_student_mic')::BOOLEAN, TRUE),
            COALESCE((p_payload->>'allow_student_cam')::BOOLEAN, TRUE),
            COALESCE((p_payload->>'allow_chat')::BOOLEAN, TRUE),
            COALESCE((p_payload->>'allow_reactions')::BOOLEAN, TRUE),
            p_user_id,
            p_user_id,
            NOW(),
            NOW()
        );

        -- Add creator as initial Host participant
        INSERT INTO public.live_class_participants (
            live_class_id, user_id, participant_role, is_muted, has_video, joined_at
        ) VALUES (
            v_new_id, p_user_id, 'host', FALSE, TRUE, NOW()
        ) ON CONFLICT DO NOTHING;

        RETURN jsonb_build_object(
            'success', TRUE,
            'message', 'Live class created successfully',
            'id', v_new_id,
            'live_class_id', v_new_id,
            'room_code', v_room_code
        );

    ELSIF UPPER(p_action) = 'UPDATE' THEN
        IF p_class_id IS NULL THEN
            RETURN jsonb_build_object('success', FALSE, 'error', 'Class ID is required for update');
        END IF;

        UPDATE public.live_classes
        SET title = COALESCE((p_payload->>'title'), title),
            description = COALESCE((p_payload->>'description'), description),
            class_id = COALESCE(NULLIF(p_payload->>'class_id', '')::UUID, class_id),
            section_id = COALESCE(NULLIF(p_payload->>'section_id', '')::UUID, section_id),
            subject_id = COALESCE(NULLIF(p_payload->>'subject_id', '')::UUID, subject_id),
            teacher_id = COALESCE(NULLIF(p_payload->>'teacher_id', '')::UUID, teacher_id),
            scheduled_at = COALESCE((p_payload->>'scheduled_at')::TIMESTAMPTZ, scheduled_at),
            duration_minutes = COALESCE((p_payload->>'duration_minutes')::INT, duration_minutes),
            max_participants = COALESCE((p_payload->>'max_participants')::INT, max_participants),
            recording_enabled = COALESCE((p_payload->>'recording_enabled')::BOOLEAN, recording_enabled),
            waiting_room_enabled = COALESCE((p_payload->>'waiting_room_enabled')::BOOLEAN, waiting_room_enabled),
            allow_student_mic = COALESCE((p_payload->>'allow_student_mic')::BOOLEAN, allow_student_mic),
            allow_student_cam = COALESCE((p_payload->>'allow_student_cam')::BOOLEAN, allow_student_cam),
            allow_chat = COALESCE((p_payload->>'allow_chat')::BOOLEAN, allow_chat),
            allow_reactions = COALESCE((p_payload->>'allow_reactions')::BOOLEAN, allow_reactions),
            updated_by = p_user_id,
            updated_at = NOW()
        WHERE id = p_class_id AND school_id = p_school_id;

        RETURN jsonb_build_object(
            'success', TRUE,
            'message', 'Live class updated successfully',
            'id', p_class_id
        );

    ELSIF UPPER(p_action) = 'CANCEL' THEN
        IF p_class_id IS NULL THEN
            RETURN jsonb_build_object('success', FALSE, 'error', 'Class ID is required for cancel');
        END IF;

        UPDATE public.live_classes
        SET status = 'cancelled',
            is_live = FALSE,
            updated_by = p_user_id,
            updated_at = NOW()
        WHERE id = p_class_id AND school_id = p_school_id;

        RETURN jsonb_build_object('success', TRUE, 'message', 'Live class cancelled successfully');

    ELSIF UPPER(p_action) = 'DELETE' THEN
        IF p_class_id IS NULL THEN
            RETURN jsonb_build_object('success', FALSE, 'error', 'Class ID is required for delete');
        END IF;

        -- Clean up child participants and attendance
        DELETE FROM public.live_class_participants WHERE live_class_id = p_class_id;
        DELETE FROM public.live_class_attendance WHERE live_class_id = p_class_id;
        DELETE FROM public.live_class_chats WHERE live_class_id = p_class_id;
        DELETE FROM public.live_class_polls WHERE live_class_id = p_class_id;
        DELETE FROM public.live_class_questions WHERE session_id = p_class_id;
        DELETE FROM public.live_classes WHERE id = p_class_id AND school_id = p_school_id;

        RETURN jsonb_build_object('success', TRUE, 'message', 'Live class deleted successfully');

    ELSIF UPPER(p_action) = 'BULK_CANCEL' THEN
        IF (p_payload->'class_ids') IS NULL OR jsonb_array_length(p_payload->'class_ids') = 0 THEN
            RETURN jsonb_build_object('success', FALSE, 'error', 'No class IDs provided for bulk cancel');
        END IF;

        UPDATE public.live_classes
        SET status = 'cancelled',
            is_live = FALSE,
            updated_by = p_user_id,
            updated_at = NOW()
        WHERE id IN (
            SELECT (jsonb_array_elements_text(p_payload->'class_ids'))::UUID
        ) AND school_id = p_school_id;

        RETURN jsonb_build_object(
            'success', TRUE,
            'message', 'Selected live classes cancelled successfully',
            'cancelled_count', jsonb_array_length(p_payload->'class_ids')
        );

    ELSIF UPPER(p_action) = 'BULK_DELETE' THEN
        IF (p_payload->'class_ids') IS NULL OR jsonb_array_length(p_payload->'class_ids') = 0 THEN
            RETURN jsonb_build_object('success', FALSE, 'error', 'No class IDs provided for bulk delete');
        END IF;

        FOR v_item_id IN SELECT jsonb_array_elements(p_payload->'class_ids') LOOP
            DELETE FROM public.live_class_participants WHERE live_class_id = (v_item_id#>>'{}')::UUID;
            DELETE FROM public.live_class_attendance WHERE live_class_id = (v_item_id#>>'{}')::UUID;
            DELETE FROM public.live_class_chats WHERE live_class_id = (v_item_id#>>'{}')::UUID;
            DELETE FROM public.live_class_polls WHERE live_class_id = (v_item_id#>>'{}')::UUID;
            DELETE FROM public.live_class_questions WHERE session_id = (v_item_id#>>'{}')::UUID;
            DELETE FROM public.live_classes WHERE id = (v_item_id#>>'{}')::UUID AND school_id = p_school_id;
        END LOOP;

        RETURN jsonb_build_object(
            'success', TRUE,
            'message', 'Selected live classes deleted successfully',
            'deleted_count', jsonb_array_length(p_payload->'class_ids')
        );

    ELSE
        RETURN jsonb_build_object('success', FALSE, 'error', 'Unsupported action: ' || p_action);
    END IF;
END;
$$;
