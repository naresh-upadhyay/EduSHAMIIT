-- ============================================================================
-- Migration 444: Exam Class Management (academic_classes/sections) & Targeted Users
-- EduSHAMIIT Enterprise School & College ERP
-- ============================================================================

-- 1. Ensure columns on exams table support optional classes/sections and targeted users
ALTER TABLE public.exams
    ALTER COLUMN target_classes SET DEFAULT '[]'::jsonb,
    ALTER COLUMN applicable_sections SET DEFAULT '[]'::jsonb,
    ALTER COLUMN target_students SET DEFAULT '[]'::jsonb;

-- 2. Stored Procedure: Get Academic Classes and Sections for Exams
-- Sourced directly from academic_classes and academic_sections (Class Management SSOT)
CREATE OR REPLACE FUNCTION public.sp_get_exam_classes_and_sections(
    p_school_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_classes JSONB;
BEGIN
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', c.id,
                'name', c.name,
                'code', c.code,
                'stage', c.stage,
                'academic_year', c.academic_year,
                'display_order', c.display_order,
                'sections', COALESCE(
                    (
                        SELECT jsonb_agg(
                            jsonb_build_object(
                                'id', s.id,
                                'class_id', s.class_id,
                                'name', s.name,
                                'code', s.code,
                                'display_order', s.display_order
                            ) ORDER BY s.display_order, s.name
                        )
                        FROM public.academic_sections s
                        WHERE s.class_id = c.id
                          AND s.deleted_at IS NULL
                          AND s.status = 'ACTIVE'
                    ),
                    '[]'::jsonb
                )
            ) ORDER BY c.display_order, c.name
        ),
        '[]'::jsonb
    )
    INTO v_classes
    FROM public.academic_classes c
    WHERE (p_school_id IS NULL OR c.school_id = p_school_id)
      AND c.deleted_at IS NULL
      AND c.status = 'ACTIVE';

    RETURN jsonb_build_object(
        'success', TRUE,
        'school_id', p_school_id,
        'classes', v_classes
    );
END;
$$;

-- 3. Stored Procedure: Search Users for Targeted Exam Scheduling
-- Searches profiles across all roles (staff, teachers, students, new joiners) within the school
CREATE OR REPLACE FUNCTION public.sp_search_exam_target_users(
    p_school_id UUID,
    p_search TEXT DEFAULT '',
    p_role TEXT DEFAULT NULL,
    p_limit INT DEFAULT 30
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_query TEXT := LOWER(BTRIM(COALESCE(p_search, '')));
    v_role_filter TEXT := LOWER(BTRIM(COALESCE(p_role, '')));
    v_users JSONB;
BEGIN
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', p.id,
                'full_name', p.full_name,
                'email', p.email,
                'role', p.role,
                'class', p.class,
                'department', p.department,
                'designation', p.designation,
                'roll_number', p.roll_number,
                'employee_id', p.employee_id,
                'admission_number', p.admission_number,
                'avatar_url', p.avatar_url,
                'status', p.status
            ) ORDER BY p.full_name ASC
        ),
        '[]'::jsonb
    )
    INTO v_users
    FROM (
        SELECT p.*
        FROM public.profiles p
        WHERE (p_school_id IS NULL OR p.school_id = p_school_id)
          AND (
              v_role_filter = '' OR v_role_filter = 'all'
              OR LOWER(p.role) = v_role_filter
          )
          AND (
              v_query = ''
              OR LOWER(p.full_name) LIKE '%' || v_query || '%'
              OR LOWER(COALESCE(p.email, '')) LIKE '%' || v_query || '%'
              OR LOWER(COALESCE(p.employee_id, '')) LIKE '%' || v_query || '%'
              OR LOWER(COALESCE(p.admission_number, '')) LIKE '%' || v_query || '%'
              OR LOWER(COALESCE(p.department, '')) LIKE '%' || v_query || '%'
              OR LOWER(COALESCE(p.designation, '')) LIKE '%' || v_query || '%'
              OR LOWER(COALESCE(p.class, '')) LIKE '%' || v_query || '%'
              OR LOWER(p.role) LIKE '%' || v_query || '%'
          )
        ORDER BY p.full_name ASC
        LIMIT LEAST(GREATEST(p_limit, 1), 100)
    ) p;

    RETURN jsonb_build_object(
        'success', TRUE,
        'school_id', p_school_id,
        'users', v_users
    );
END;
$$;

-- 4. Stored Procedure: Fetch Target Users By List of IDs (for loading chips on edit)
CREATE OR REPLACE FUNCTION public.sp_get_exam_target_users_by_ids(
    p_school_id UUID,
    p_user_ids UUID[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_users JSONB;
BEGIN
    IF p_user_ids IS NULL OR ARRAY_LENGTH(p_user_ids, 1) = 0 THEN
        RETURN jsonb_build_object('success', TRUE, 'school_id', p_school_id, 'users', '[]'::jsonb);
    END IF;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', p.id,
                'full_name', p.full_name,
                'email', p.email,
                'role', p.role,
                'class', p.class,
                'department', p.department,
                'designation', p.designation,
                'roll_number', p.roll_number,
                'employee_id', p.employee_id,
                'admission_number', p.admission_number,
                'avatar_url', p.avatar_url,
                'status', p.status
            )
        ),
        '[]'::jsonb
    )
    INTO v_users
    FROM public.profiles p
    WHERE p.id = ANY(p_user_ids)
      AND (p_school_id IS NULL OR p.school_id = p_school_id);

    RETURN jsonb_build_object(
        'success', TRUE,
        'school_id', p_school_id,
        'users', v_users
    );
END;
$$;

-- 5. Update rpc_get_exam_monitoring_candidates to fully honor:
--    - Targeted Users (Staff, Teachers, Students)
--    - Optional Target Classes
--    - Optional Applicable Sections
CREATE OR REPLACE FUNCTION public.rpc_get_exam_monitoring_candidates(
    p_school_id UUID,
    p_exam_id UUID,
    p_actor_id UUID,
    p_actor_role TEXT,
    p_status TEXT DEFAULT 'ALL',
    p_search TEXT DEFAULT '',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 12
)
RETURNS TABLE (
    candidate_id UUID,
    full_name TEXT,
    role TEXT,
    class_name TEXT,
    roll_number TEXT,
    session_id UUID,
    monitoring_status TEXT,
    warnings_count INT,
    camera_active BOOLEAN,
    camera_permission TEXT,
    mic_active BOOLEAN,
    mic_permission TEXT,
    screen_share_active BOOLEAN,
    screen_share_state TEXT,
    network_status TEXT,
    latency_ms INT,
    answered_count INT,
    total_questions INT,
    remaining_seconds INT,
    extra_minutes INT,
    is_paused BOOLEAN,
    browser_info TEXT,
    reentry_count INT,
    max_reentry_attempts INT,
    last_activity_label TEXT,
    total_candidates_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_auth RECORD;
    v_exam RECORD;
    v_has_target_students BOOLEAN := FALSE;
    v_has_target_classes BOOLEAN := FALSE;
    v_has_target_sections BOOLEAN := FALSE;
    v_target_classes TEXT[] := ARRAY[]::TEXT[];
    v_target_sections TEXT[] := ARRAY[]::TEXT[];
    v_purpose TEXT;
    v_total_q INT := 0;
    v_offset INT;
BEGIN
    SELECT * INTO v_auth FROM public._can_monitor_exam(p_school_id, p_exam_id, p_actor_id, p_actor_role);
    IF NOT v_auth.allowed THEN
        RETURN;
    END IF;

    SELECT * INTO v_exam
    FROM public.exams
    WHERE id = p_exam_id
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    -- 1. Check targeted students / examinees
    IF v_exam.target_students IS NOT NULL AND jsonb_typeof(v_exam.target_students) = 'array'
       AND jsonb_array_length(v_exam.target_students) > 0 THEN
        v_has_target_students := TRUE;
    END IF;

    -- 2. Check targeted classes
    IF v_exam.target_classes IS NOT NULL AND jsonb_typeof(v_exam.target_classes) = 'array'
       AND jsonb_array_length(v_exam.target_classes) > 0 THEN
        SELECT COALESCE(ARRAY_AGG(DISTINCT LOWER(BTRIM(val))), ARRAY[]::TEXT[])
        INTO v_target_classes
        FROM (
            SELECT CASE
                WHEN jsonb_typeof(elem) = 'string' THEN elem #>> '{}'
                ELSE COALESCE(elem->>'name', elem->>'class', elem->>'class_name', '')
            END AS val
            FROM jsonb_array_elements(v_exam.target_classes) elem
        ) s
        WHERE BTRIM(val) <> '';

        IF ARRAY_LENGTH(v_target_classes, 1) > 0 THEN
            v_has_target_classes := TRUE;
        END IF;
    END IF;

    -- 3. Check applicable sections
    IF v_exam.applicable_sections IS NOT NULL AND jsonb_typeof(v_exam.applicable_sections) = 'array'
       AND jsonb_array_length(v_exam.applicable_sections) > 0 THEN
        SELECT COALESCE(ARRAY_AGG(DISTINCT LOWER(BTRIM(val))), ARRAY[]::TEXT[])
        INTO v_target_sections
        FROM (
            SELECT CASE
                WHEN jsonb_typeof(elem) = 'string' THEN elem #>> '{}'
                ELSE COALESCE(elem->>'name', elem->>'section', elem->>'code', '')
            END AS val
            FROM jsonb_array_elements(v_exam.applicable_sections) elem
        ) s
        WHERE BTRIM(val) <> '';

        IF ARRAY_LENGTH(v_target_sections, 1) > 0 THEN
            v_has_target_sections := TRUE;
        END IF;
    END IF;

    SELECT COUNT(*)::INT INTO v_total_q
    FROM public.exam_questions
    WHERE exam_id = p_exam_id;
    IF v_total_q = 0 THEN
        v_total_q := COALESCE(v_exam.total_questions_count, 0);
    END IF;

    v_purpose := LOWER(COALESCE(v_exam.exam_purpose, '') || ' ' || COALESCE(v_exam.scope, ''));
    v_offset := GREATEST(0, (COALESCE(p_page, 1) - 1) * GREATEST(1, COALESCE(p_page_size, 12)));

    RETURN QUERY
    WITH explicit_targets AS (
        SELECT DISTINCT elem::UUID AS uid
        FROM jsonb_array_elements_text(COALESCE(v_exam.target_students, '[]'::jsonb)) elem
        WHERE v_has_target_students
          AND elem ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    ),
    section_assigned_students AS (
        SELECT DISTINCT sca.student_id AS uid
        FROM public.student_class_assignments sca
        JOIN public.academic_sections asec ON asec.id = sca.section_id
        WHERE v_has_target_sections
          AND (
              LOWER(BTRIM(asec.name)) = ANY(v_target_sections)
              OR LOWER(BTRIM(asec.code)) = ANY(v_target_sections)
          )
          AND sca.status = 'ACTIVE'
    ),
    participant_ids AS (
        SELECT uid FROM explicit_targets
        UNION
        SELECT es.student_id FROM public.exam_sessions es WHERE es.exam_id = p_exam_id AND es.student_id IS NOT NULL
        UNION
        SELECT ep.student_id FROM public.exam_prestart_sessions ep WHERE ep.exam_id = p_exam_id AND ep.student_id IS NOT NULL
        UNION
        SELECT sub.student_id FROM public.exam_submissions sub WHERE sub.exam_id = p_exam_id AND sub.student_id IS NOT NULL
        UNION
        SELECT p.id
        FROM public.profiles p
        WHERE p.school_id = COALESCE(v_exam.school_id, p_school_id)
          AND (
              -- Case A: Class matching
              (v_has_target_classes AND (
                  LOWER(BTRIM(COALESCE(p.class, ''))) = ANY(v_target_classes)
                  OR ('class ' || LOWER(BTRIM(COALESCE(p.class, '')))) = ANY(v_target_classes)
                  OR (p.id IN (
                      SELECT sca.student_id
                      FROM public.student_class_assignments sca
                      JOIN public.academic_classes acls ON acls.id = sca.class_id
                      WHERE LOWER(BTRIM(acls.name)) = ANY(v_target_classes)
                         OR LOWER(BTRIM(acls.code)) = ANY(v_target_classes)
                  ))
              ) AND (NOT v_has_target_sections OR p.id IN (SELECT uid FROM section_assigned_students)))
              -- Case B: No classes and no explicit target users -> all regular students
              OR (NOT v_has_target_students AND NOT v_has_target_classes AND LOWER(COALESCE(p.role, '')) = 'student'
                  AND v_purpose NOT LIKE '%onboarding%' AND v_purpose NOT LIKE '%teacher%')
          )
    ),
    roster AS (
        SELECT DISTINCT ON (p.id)
            p.id AS candidate_id,
            COALESCE(NULLIF(BTRIM(p.full_name), ''), p.email, 'Candidate') AS full_name,
            COALESCE(p.role, 'student') AS role,
            COALESCE(p.class, p.department, 'Staff / General') AS class_name,
            COALESCE(p.roll_number::TEXT, p.admission_number, p.employee_id, '—') AS roll_number,
            COALESCE(es.id, ep.id) AS session_id,
            COALESCE(es.monitoring_status, ep.monitoring_status, 'NOT_STARTED') AS monitoring_status,
            COALESCE(es.warnings_count, ep.warnings_count, 0) AS warnings_count,
            COALESCE(es.camera_active, ep.camera_active, FALSE) AS camera_active,
            COALESCE(es.camera_permission, ep.camera_permission, 'pending') AS camera_permission,
            COALESCE(es.mic_active, ep.mic_active, FALSE) AS mic_active,
            COALESCE(es.mic_permission, ep.mic_permission, 'pending') AS mic_permission,
            COALESCE(es.screen_share_active, ep.screen_share_active, FALSE) AS screen_share_active,
            COALESCE(es.screen_share_state, ep.screen_share_state, 'pending') AS screen_share_state,
            COALESCE(es.network_status, ep.network_status, 'GOOD') AS network_status,
            COALESCE(es.latency_ms, ep.latency_ms, 0) AS latency_ms,
            COALESCE(
                (SELECT COUNT(*)::INT FROM jsonb_object_keys(COALESCE(sub.answers, '{}'::jsonb))),
                es.answered_count,
                0
            ) AS answered_count,
            v_total_q AS total_questions,
            COALESCE(es.remaining_seconds, 0) AS remaining_seconds,
            COALESCE(es.extra_minutes, 0) AS extra_minutes,
            COALESCE(es.is_paused, FALSE) AS is_paused,
            COALESCE(es.browser_info, ep.device_info->>'browser', 'Web Browser') AS browser_info,
            COALESCE(es.reentry_count, 0) AS reentry_count,
            COALESCE(es.max_reentry_attempts, 2) AS max_reentry_attempts,
            CASE
                WHEN sub.id IS NOT NULL AND sub.status IN ('submitted', 'auto_submitted', 'graded', 'evaluated') THEN 'Submitted'
                WHEN es.status = 'active' THEN 'Active'
                WHEN es.status = 'paused' THEN 'Paused'
                WHEN ep.id IS NOT NULL THEN 'System Checks Passed'
                ELSE 'Not Started Yet'
            END AS last_activity_label
        FROM participant_ids pids
        JOIN public.profiles p ON p.id = pids.uid
        LEFT JOIN public.exam_sessions es ON es.exam_id = p_exam_id AND es.student_id = p.id
        LEFT JOIN public.exam_prestart_sessions ep ON ep.exam_id = p_exam_id AND ep.student_id = p.id
        LEFT JOIN public.exam_submissions sub ON sub.exam_id = p_exam_id AND sub.student_id = p.id
    ),
    filtered AS (
        SELECT r.*
        FROM roster r
        WHERE (
            p_status = 'ALL'
            OR (p_status = 'ACTIVE' AND r.monitoring_status IN ('ACTIVE', 'WARNING', 'VIOLATION'))
            OR (p_status = 'WARNING' AND r.monitoring_status = 'WARNING')
            OR (p_status = 'VIOLATION' AND r.monitoring_status = 'VIOLATION')
            OR (p_status = 'PAUSED' AND (r.monitoring_status = 'PAUSED' OR r.is_paused))
            OR (p_status = 'DISCONNECTED' AND r.monitoring_status = 'DISCONNECTED')
            OR (p_status = 'RECONNECTING' AND r.monitoring_status = 'RECONNECTING')
            OR (p_status = 'SUBMITTED' AND r.monitoring_status IN ('SUBMITTED', 'AUTO_SUBMITTED'))
            OR (p_status = 'TERMINATED' AND r.monitoring_status = 'TERMINATED')
            OR (p_status = 'NOT_STARTED' AND r.monitoring_status = 'NOT_STARTED')
        )
        AND (
            p_search = ''
            OR LOWER(r.full_name) LIKE '%' || LOWER(BTRIM(p_search)) || '%'
            OR LOWER(r.roll_number) LIKE '%' || LOWER(BTRIM(p_search)) || '%'
            OR LOWER(r.class_name) LIKE '%' || LOWER(BTRIM(p_search)) || '%'
        )
    ),
    counted AS (
        SELECT COUNT(*)::BIGINT AS total_count FROM filtered
    )
    SELECT
        f.candidate_id,
        f.full_name,
        f.role,
        f.class_name,
        f.roll_number,
        f.session_id,
        f.monitoring_status,
        f.warnings_count,
        f.camera_active,
        f.camera_permission,
        f.mic_active,
        f.mic_permission,
        f.screen_share_active,
        f.screen_share_state,
        f.network_status,
        f.latency_ms,
        f.answered_count,
        f.total_questions,
        f.remaining_seconds,
        f.extra_minutes,
        f.is_paused,
        f.browser_info,
        f.reentry_count,
        f.max_reentry_attempts,
        f.last_activity_label,
        c.total_count AS total_candidates_count
    FROM filtered f
    CROSS JOIN counted c
    ORDER BY
        CASE f.monitoring_status
            WHEN 'VIOLATION' THEN 1
            WHEN 'WARNING' THEN 2
            WHEN 'DISCONNECTED' THEN 3
            WHEN 'ACTIVE' THEN 4
            WHEN 'PAUSED' THEN 5
            WHEN 'RECONNECTING' THEN 6
            WHEN 'SUBMITTED' THEN 7
            WHEN 'AUTO_SUBMITTED' THEN 8
            WHEN 'TERMINATED' THEN 9
            ELSE 10
        END,
        f.full_name ASC
    LIMIT GREATEST(1, COALESCE(p_page_size, 12))
    OFFSET v_offset;
END;
$$;

