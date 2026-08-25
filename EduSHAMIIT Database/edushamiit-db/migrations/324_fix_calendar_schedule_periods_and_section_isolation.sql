-- ============================================================================
-- Migration: 324_fix_calendar_schedule_periods_and_section_isolation.sql
-- Description:
--   1. Ensures periods are ONLY visible when an Academic Calendar schedule
--      is present for that specific date (removes artificial fallbacks).
--   2. Enforces strict Section-Level Isolation for periods when "All Sections"
--      is selected, ensuring students only see periods assigned to their section.
--   3. Provides accurate section_period_number and section_period_label.
-- ============================================================================

-- 1. FUNCTION: fn_get_class_academic_periods_for_date
CREATE OR REPLACE FUNCTION public.fn_get_class_academic_periods_for_date(
    p_school_id UUID,
    p_date DATE,
    p_class_id UUID,
    p_section_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_class_name TEXT;
    v_section_name TEXT;
    v_periods JSONB := '[]'::jsonb;
    v_sched_count INT := 0;
BEGIN
    SELECT name INTO v_class_name FROM public.academic_classes WHERE id = p_class_id;
    IF p_section_id IS NOT NULL THEN
        SELECT name INTO v_section_name FROM public.academic_sections WHERE id = p_section_id;
    END IF;

    -- Query schedules linked to Academic Calendar with Class-Section-Subject offerings
    WITH academic_schedules AS (
        SELECT DISTINCT ON (
            s.id, 
            COALESCE(sp.target_subject_id, sub_tcs.id, '00000000-0000-0000-0000-000000000000'::UUID),
            COALESCE(sp.section_id, sub_tcs.section_id, '00000000-0000-0000-0000-000000000000'::UUID)
        )
            s.id AS schedule_id,
            s.title AS schedule_title,
            s.description AS schedule_description,
            s.color AS schedule_color,
            s.start_time,
            s.end_time,
            s.timezone,
            s.organizer_id,
            p_org.full_name AS teacher_name,
            p_org.avatar_url AS teacher_avatar,
            COALESCE(sp.target_subject_id, sub_tcs.id, sub_direct.id) AS subject_id,
            COALESCE(sub_sp.name, sub_tcs.name, sp.target_subject, sub_direct.name, s.title) AS subject_name,
            COALESCE(sub_sp.code, sub_tcs.code, sub_direct.code, '') AS subject_code,
            COALESCE(sub_sp.color, sub_tcs.color, s.color, '#4F46E5') AS subject_color,
            COALESCE(sp.section_id, sub_tcs.section_id) AS section_id,
            COALESCE(sec_sp.name, sub_tcs.section_name, sp.target_section, '') AS section_name,
            (s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata'))::TIME AS local_start_time,
            (s.end_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata'))::TIME AS local_end_time
        FROM public.schedules s
        JOIN public.calendars c ON c.id = s.calendar_id
        LEFT JOIN public.profiles p_org ON p_org.id = s.organizer_id
        LEFT JOIN public.schedule_recurrence rec ON rec.schedule_id = COALESCE(s.recurring_parent_id, s.id)
        -- Left join participants targeting class/section/subject
        LEFT JOIN public.schedule_participants sp ON sp.schedule_id = s.id 
             AND (
                 sp.class_id = p_class_id 
                 OR (v_class_name IS NOT NULL AND sp.target_class ILIKE v_class_name)
             )
             AND (
                 p_section_id IS NULL 
                 OR sp.section_id = p_section_id 
                 OR sp.section_id IS NULL 
                 OR (v_section_name IS NOT NULL AND sp.target_section ILIKE v_section_name)
             )
        LEFT JOIN public.academic_sections sec_sp ON sec_sp.id = sp.section_id
        LEFT JOIN public.academic_subjects sub_sp ON sub_sp.id = sp.target_subject_id
        -- Lateral join target_class_sections JSON array
        LEFT JOIN LATERAL (
            SELECT 
                (elem->>'subject_id')::UUID AS id,
                elem->>'subject_name' AS name,
                (elem->>'section_id')::UUID AS section_id,
                elem->>'section_name' AS section_name,
                '' AS code,
                NULL::TEXT AS color
            FROM jsonb_array_elements(COALESCE(s.target_class_sections, '[]'::jsonb)) elem
            WHERE (elem->>'class_id')::UUID = p_class_id
              AND (p_section_id IS NULL OR elem->>'section_id' IS NULL OR (elem->>'section_id')::UUID = p_section_id)
            LIMIT 1
        ) sub_tcs ON TRUE
        -- Direct subject lookup if title matches
        LEFT JOIN public.academic_subjects sub_direct ON (
            s.title ILIKE '%' || sub_direct.name || '%'
            AND sub_direct.school_id = p_school_id
        )
        WHERE s.school_id = p_school_id
          AND s.deleted_at IS NULL
          AND s.status NOT IN ('cancelled')
          -- Match Academic Calendar (case-insensitive name or type)
          AND (
              LOWER(TRIM(c.name)) LIKE '%academic%'
              OR LOWER(TRIM(c.type)) = 'academic'
              OR c.id = '52c2bc44-add3-4f10-9b43-51fa32570cf0'::UUID
          )
          -- Match Class & Section
          AND (
              sp.id IS NOT NULL
              OR EXISTS (
                  SELECT 1 FROM jsonb_array_elements(COALESCE(s.target_class_sections, '[]'::jsonb)) elem
                  WHERE (elem->>'class_id')::UUID = p_class_id
                    AND (p_section_id IS NULL OR elem->>'section_id' IS NULL OR (elem->>'section_id')::UUID = p_section_id)
              )
              OR (
                  v_class_name IS NOT NULL 
                  AND EXISTS (
                      SELECT 1 FROM jsonb_array_elements_text(COALESCE(s.target_classes, '[]'::jsonb)) tc
                      WHERE tc ILIKE v_class_name
                  )
              )
          )
          -- Date Active Check
          AND (
              (
                  (s.is_recurring = FALSE OR s.is_recurring IS NULL)
                  AND DATE(s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata')) = p_date
              )
              OR (
                  s.is_recurring = TRUE
                  AND p_date >= DATE(s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata'))
                  AND (rec.end_date IS NULL OR p_date <= rec.end_date)
                  AND NOT (COALESCE(rec.exceptions, '[]'::jsonb) ? to_char(p_date, 'YYYY-MM-DD'))
                  AND (
                      rec.frequency = 'daily' AND (p_date - DATE(s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata'))) % GREATEST(COALESCE(rec.interval, 1), 1) = 0
                      OR (rec.frequency = 'weekdays' AND EXTRACT(ISODOW FROM p_date) BETWEEN 1 AND 5)
                      OR (
                          rec.frequency = 'weekly' 
                          AND (p_date - DATE(s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata')))/7 % GREATEST(COALESCE(rec.interval, 1), 1) = 0
                          AND (
                              COALESCE(rec.days_of_week, '[]'::jsonb) = '[]'::jsonb
                              OR rec.days_of_week ? UPPER(SUBSTRING(to_char(p_date, 'Day') FROM 1 FOR 2))
                          )
                      )
                      OR (
                          rec.frequency = 'monthly' 
                          AND EXTRACT(DAY FROM p_date) = EXTRACT(DAY FROM (s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata')))
                      )
                      OR (
                          rec.frequency = 'yearly'
                          AND EXTRACT(MONTH FROM p_date) = EXTRACT(MONTH FROM (s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata')))
                          AND EXTRACT(DAY FROM p_date) = EXTRACT(DAY FROM (s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata')))
                      )
                  )
                  -- Exclude if an explicit override exists on this date
                  AND NOT EXISTS (
                      SELECT 1 FROM public.schedules ovr
                      WHERE ovr.recurring_parent_id = s.id
                        AND ovr.original_instance_date = p_date
                        AND ovr.deleted_at IS NULL
                  )
              )
          )
        ORDER BY 
            s.id, 
            COALESCE(sp.target_subject_id, sub_tcs.id, '00000000-0000-0000-0000-000000000000'::UUID),
            COALESCE(sp.section_id, sub_tcs.section_id, '00000000-0000-0000-0000-000000000000'::UUID),
            s.start_time ASC
    ),
    ordered_schedules AS (
        SELECT 
            ROW_NUMBER() OVER (
                PARTITION BY COALESCE(section_id, '00000000-0000-0000-0000-000000000000'::UUID)
                ORDER BY local_start_time ASC, schedule_title ASC
            ) AS section_period_num,
            ROW_NUMBER() OVER (ORDER BY local_start_time ASC, schedule_title ASC) AS global_period_num,
            academic_schedules.*
        FROM academic_schedules
    ),
    period_aggregates AS (
        SELECT 
            os.schedule_id,
            CASE WHEN p_section_id IS NOT NULL THEN os.section_period_num ELSE os.global_period_num END AS period_number,
            'P' || (CASE WHEN p_section_id IS NOT NULL THEN os.section_period_num ELSE os.global_period_num END) AS period_label,
            os.section_period_num AS section_period_number,
            'P' || os.section_period_num AS section_period_label,
            os.section_id,
            os.section_name,
            to_char(os.local_start_time, 'HH12:MI AM') || ' - ' || to_char(os.local_end_time, 'HH12:MI AM') AS time_range,
            COALESCE(os.subject_id, gen_random_uuid()) AS subject_id,
            os.subject_name,
            os.subject_code,
            os.subject_color,
            os.teacher_name,
            os.teacher_avatar,
            os.schedule_title,
            EXISTS (
                SELECT 1 FROM public.attendance_period_records apr
                WHERE apr.school_id = p_school_id
                  AND apr.class_id = p_class_id
                  AND (p_section_id IS NULL OR apr.section_id = p_section_id OR apr.section_id IS NULL)
                  AND apr.attendance_date = p_date
                  AND (
                      apr.schedule_id = os.schedule_id
                      OR (os.subject_id IS NOT NULL AND apr.subject_id = os.subject_id)
                      OR apr.period_number = os.global_period_num
                      OR apr.period_number = os.section_period_num
                  )
                  AND apr.is_locked = TRUE
            ) AS is_locked,
            EXISTS (
                SELECT 1 FROM public.attendance_period_records apr
                WHERE apr.school_id = p_school_id
                  AND apr.class_id = p_class_id
                  AND (p_section_id IS NULL OR apr.section_id = p_section_id OR apr.section_id IS NULL)
                  AND apr.attendance_date = p_date
                  AND (
                      apr.schedule_id = os.schedule_id
                      OR (os.subject_id IS NOT NULL AND apr.subject_id = os.subject_id)
                      OR apr.period_number = os.global_period_num
                      OR apr.period_number = os.section_period_num
                  )
            ) AS is_completed,
            COALESCE(
                (
                    SELECT COUNT(*) FROM public.attendance_period_records apr
                    WHERE apr.school_id = p_school_id
                      AND apr.class_id = p_class_id
                      AND (p_section_id IS NULL OR apr.section_id = p_section_id OR apr.section_id IS NULL)
                      AND apr.attendance_date = p_date
                      AND (
                          apr.schedule_id = os.schedule_id
                          OR (os.subject_id IS NOT NULL AND apr.subject_id = os.subject_id)
                          OR apr.period_number = os.global_period_num
                          OR apr.period_number = os.section_period_num
                      )
                      AND apr.status = 'PRESENT'
                ), 0
            ) AS present_count,
            COALESCE(
                (
                    SELECT COUNT(*) FROM public.attendance_period_records apr
                    WHERE apr.school_id = p_school_id
                      AND apr.class_id = p_class_id
                      AND (p_section_id IS NULL OR apr.section_id = p_section_id OR apr.section_id IS NULL)
                      AND apr.attendance_date = p_date
                      AND (
                          apr.schedule_id = os.schedule_id
                          OR (os.subject_id IS NOT NULL AND apr.subject_id = os.subject_id)
                          OR apr.period_number = os.global_period_num
                          OR apr.period_number = os.section_period_num
                      )
                      AND apr.status = 'ABSENT'
                ), 0
            ) AS absent_count,
            COALESCE(
                (
                    SELECT COUNT(*) FROM public.attendance_period_records apr
                    WHERE apr.school_id = p_school_id
                      AND apr.class_id = p_class_id
                      AND (p_section_id IS NULL OR apr.section_id = p_section_id OR apr.section_id IS NULL)
                      AND apr.attendance_date = p_date
                      AND (
                          apr.schedule_id = os.schedule_id
                          OR (os.subject_id IS NOT NULL AND apr.subject_id = os.subject_id)
                          OR apr.period_number = os.global_period_num
                          OR apr.period_number = os.section_period_num
                      )
                      AND apr.status = 'LATE'
                ), 0
            ) AS late_count
        FROM ordered_schedules os
    )
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', schedule_id,
                'schedule_id', schedule_id,
                'schedule_title', schedule_title,
                'period_number', period_number,
                'period_label', period_label,
                'section_period_number', section_period_number,
                'section_period_label', section_period_label,
                'section_id', section_id,
                'section_name', section_name,
                'time_range', time_range,
                'subject_id', subject_id,
                'subject_name', subject_name,
                'subject_code', subject_code,
                'subject_color', subject_color,
                'teacher_name', teacher_name,
                'teacher_avatar', teacher_avatar,
                'is_locked', is_locked,
                'is_completed', is_completed,
                'status', CASE WHEN is_locked THEN 'LOCKED' WHEN is_completed THEN 'COMPLETED' ELSE 'NOT_STARTED' END,
                'present_count', present_count,
                'absent_count', absent_count,
                'late_count', late_count
            ) ORDER BY period_number ASC
        ),
        '[]'::jsonb
    ) INTO v_periods
    FROM period_aggregates;

    v_sched_count := jsonb_array_length(v_periods);

    -- NOTE: If no calendar schedules found for this class/section on this date,
    -- return empty list []. Do NOT generate fake fallback periods.

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'schedules', v_periods,
            'count', v_sched_count,
            'source', CASE WHEN v_sched_count > 0 THEN 'academic_calendar' ELSE 'empty' END
        )
    );
END;
$$;


-- 2. FUNCTION: fn_get_daily_attendance_roster (Enhanced with Strict Section Isolation)
CREATE OR REPLACE FUNCTION public.fn_get_daily_attendance_roster(
    p_school_id UUID,
    p_date DATE,
    p_class_id UUID,
    p_section_id UUID DEFAULT NULL,
    p_mode VARCHAR DEFAULT 'ALL_DAY',
    p_period_number INT DEFAULT NULL,
    p_subject_id UUID DEFAULT NULL,
    p_search TEXT DEFAULT '',
    p_status_filter VARCHAR DEFAULT 'ALL',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_teacher_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_count INT := 0;
    v_offset INT;
    v_students JSONB;
    v_is_locked_all_day BOOLEAN := FALSE;
    v_locked_at TIMESTAMPTZ := NULL;
    v_locked_by_name TEXT := NULL;
    v_mode_norm VARCHAR := UPPER(COALESCE(p_mode, 'ALL_DAY'));
    v_schedules_json JSONB;
BEGIN
    v_offset := (p_page - 1) * p_page_size;

    -- Fetch scheduled periods metadata for this class/section/date
    SELECT COALESCE(public.fn_get_class_academic_periods_for_date(p_school_id, p_date, p_class_id, p_section_id)->'data'->'schedules', '[]'::JSONB)
    INTO v_schedules_json;

    -- Check if all-day attendance for this class/section/date is locked
    SELECT 
        COALESCE(BOOL_OR(a.is_locked), FALSE),
        MAX(a.locked_at),
        (
            SELECT p_sub.full_name 
            FROM public.attendance_daily_records a2 
            JOIN public.profiles p_sub ON p_sub.id = a2.locked_by 
            WHERE a2.school_id = p_school_id 
              AND a2.attendance_date = p_date 
              AND a2.class_id = p_class_id 
              AND (p_section_id IS NULL OR a2.section_id = p_section_id) 
              AND a2.is_locked = TRUE 
            LIMIT 1
        )
    INTO v_is_locked_all_day, v_locked_at, v_locked_by_name
    FROM public.attendance_daily_records a
    WHERE a.school_id = p_school_id
      AND a.attendance_date = p_date
      AND a.class_id = p_class_id
      AND (p_section_id IS NULL OR a.section_id = p_section_id);

    -- 1. Calculate Total Count
    WITH eligible_students AS (
        SELECT DISTINCT ON (sca.student_id)
            sca.student_id,
            sca.roll_number,
            sca.class_id,
            sca.section_id,
            p.full_name,
            p.admission_number,
            p.email
        FROM public.student_class_assignments sca
        JOIN public.profiles p ON p.id = sca.student_id AND (p.status IS NULL OR p.status != 'Deleted')
        WHERE sca.school_id = p_school_id
          AND sca.status = 'ACTIVE'
          AND sca.class_id = p_class_id
          AND (p_section_id IS NULL OR sca.section_id = p_section_id)
          AND (
              p_teacher_id IS NULL
              OR EXISTS (
                  SELECT 1 FROM public.class_teacher_assignments cta
                  WHERE cta.teacher_id = p_teacher_id
                    AND cta.class_id = sca.class_id
                    AND (cta.section_id = sca.section_id OR cta.section_id IS NULL)
              )
          )
          AND (
              p_search = '' 
              OR p.full_name ILIKE '%' || p_search || '%' 
              OR p.email ILIKE '%' || p_search || '%'
              OR sca.roll_number ILIKE '%' || p_search || '%'
              OR p.admission_number ILIKE '%' || p_search || '%'
          )
    ),
    filtered_roster AS (
        SELECT es.student_id
        FROM eligible_students es
        LEFT JOIN public.attendance_daily_records adr ON adr.school_id = p_school_id 
             AND adr.student_id = es.student_id 
             AND adr.attendance_date = p_date
        LEFT JOIN LATERAL (
            SELECT * FROM public.attendance_period_records 
            WHERE school_id = p_school_id 
              AND student_id = es.student_id 
              AND attendance_date = p_date 
              AND (p_period_number IS NULL OR period_number = p_period_number)
              AND (p_subject_id IS NULL OR subject_id = p_subject_id)
            ORDER BY updated_at DESC 
            LIMIT 1
        ) apr ON v_mode_norm != 'ALL_DAY'
        WHERE (
            p_status_filter = 'ALL'
            OR (v_mode_norm = 'ALL_DAY' AND UPPER(COALESCE(adr.status, 'NOT_MARKED')) = UPPER(p_status_filter))
            OR (v_mode_norm != 'ALL_DAY' AND UPPER(COALESCE(apr.status, CASE WHEN adr.is_locked = TRUE THEN adr.status ELSE 'NOT_MARKED' END)) = UPPER(p_status_filter))
        )
    )
    SELECT COUNT(*) INTO v_total_count FROM filtered_roster;

    -- 2. Build Paginated Roster with Strict Section Isolation for Periods
    WITH eligible_students AS (
        SELECT DISTINCT ON (sca.student_id)
            sca.student_id,
            sca.roll_number,
            p.admission_number,
            sca.class_id,
            sca.section_id,
            p.full_name,
            p.avatar_url,
            p.email
        FROM public.student_class_assignments sca
        JOIN public.profiles p ON p.id = sca.student_id AND (p.status IS NULL OR p.status != 'Deleted')
        WHERE sca.school_id = p_school_id
          AND sca.status = 'ACTIVE'
          AND sca.class_id = p_class_id
          AND (p_section_id IS NULL OR sca.section_id = p_section_id)
          AND (
              p_teacher_id IS NULL
              OR EXISTS (
                  SELECT 1 FROM public.class_teacher_assignments cta
                  WHERE cta.teacher_id = p_teacher_id
                    AND cta.class_id = sca.class_id
                    AND (cta.section_id = sca.section_id OR cta.section_id IS NULL)
              )
          )
          AND (
              p_search = '' 
              OR p.full_name ILIKE '%' || p_search || '%' 
              OR p.email ILIKE '%' || p_search || '%'
              OR sca.roll_number ILIKE '%' || p_search || '%'
              OR p.admission_number ILIKE '%' || p_search || '%'
          )
        ORDER BY sca.student_id, sca.assigned_at DESC NULLS LAST
    ),
    paginated_base AS (
        SELECT 
            es.student_id,
            es.roll_number,
            es.admission_number,
            es.full_name,
            es.avatar_url,
            es.class_id,
            COALESCE(c.name, '') AS class_name,
            es.section_id,
            COALESCE(s.name, '') AS section_name,
            adr.id AS daily_record_id,
            adr.status AS daily_status,
            adr.remarks AS daily_remarks,
            COALESCE(adr.is_locked, FALSE) AS daily_is_locked,
            COALESCE(adr.is_overridden, FALSE) AS daily_is_overridden,
            adr.override_reason AS daily_override_reason,
            adr.updated_at AS daily_updated_at,
            (SELECT prof.full_name FROM public.profiles prof WHERE prof.id = adr.updated_by) AS daily_updated_by_name,
            EXISTS (
                SELECT 1 FROM public.leave_applications la
                WHERE la.applicant_id = es.student_id
                  AND la.status = 'approved'
                  AND p_date BETWEEN la.start_date AND la.end_date
            ) AS has_approved_leave,
            (
                SELECT la.reason FROM public.leave_applications la
                WHERE la.applicant_id = es.student_id
                  AND la.status = 'approved'
                  AND p_date BETWEEN la.start_date AND la.end_date
                LIMIT 1
            ) AS leave_reason
        FROM eligible_students es
        LEFT JOIN public.academic_classes c ON c.id = es.class_id
        LEFT JOIN public.academic_sections s ON s.id = es.section_id
        LEFT JOIN public.attendance_daily_records adr ON adr.school_id = p_school_id 
             AND adr.student_id = es.student_id 
             AND adr.attendance_date = p_date
        ORDER BY 
            CASE WHEN es.roll_number ~ '^[0-9]+$' THEN es.roll_number::INT ELSE 9999 END ASC,
            es.full_name ASC
        LIMIT p_page_size
        OFFSET v_offset
    ),
    student_periods_computed AS (
        SELECT 
            pb.*,
            -- Construct array of period objects strictly isolated to this student's section
            (
                SELECT COALESCE(
                    jsonb_agg(
                        jsonb_build_object(
                            'period_number', COALESCE((s_elem->>'section_period_number')::INT, (s_elem->>'period_number')::INT),
                            'period_label', COALESCE(s_elem->>'section_period_label', s_elem->>'period_label', 'P' || (s_elem->>'period_number')),
                            'subject_id', s_elem->>'subject_id',
                            'subject_name', s_elem->>'subject_name',
                            'subject_code', s_elem->>'subject_code',
                            'subject_color', s_elem->>'subject_color',
                            'schedule_id', s_elem->>'schedule_id',
                            'section_id', s_elem->>'section_id',
                            'section_name', s_elem->>'section_name',
                            'time_range', s_elem->>'time_range',
                            'teacher_name', s_elem->>'teacher_name',
                            'teacher_avatar', s_elem->>'teacher_avatar',
                            'status', CASE 
                                WHEN apr.id IS NOT NULL THEN UPPER(apr.status)
                                WHEN pb.daily_is_locked = TRUE THEN UPPER(pb.daily_status)
                                ELSE 'NOT_MARKED'
                            END,
                            'remarks', CASE 
                                WHEN apr.id IS NOT NULL THEN COALESCE(apr.remarks, '')
                                WHEN pb.daily_is_locked = TRUE THEN COALESCE(pb.daily_remarks, '')
                                ELSE ''
                            END,
                            'is_locked', (COALESCE(apr.is_locked, FALSE) OR pb.daily_is_locked),
                            'locked_by_all_day', (COALESCE(apr.locked_by_all_day, FALSE) OR (apr.id IS NULL AND pb.daily_is_locked)),
                            'is_overridden', (COALESCE(apr.is_overridden, FALSE) OR pb.daily_is_overridden),
                            'override_reason', COALESCE(apr.override_reason, pb.daily_override_reason),
                            'last_updated_at', COALESCE(apr.updated_at, pb.daily_updated_at),
                            'updated_by_name', COALESCE(
                                (SELECT prof.full_name FROM public.profiles prof WHERE prof.id = apr.updated_by),
                                pb.daily_updated_by_name
                            )
                        ) ORDER BY COALESCE((s_elem->>'section_period_number')::INT, (s_elem->>'period_number')::INT) ASC
                    ),
                    '[]'::JSONB
                )
                FROM jsonb_array_elements(v_schedules_json) s_elem
                LEFT JOIN LATERAL (
                    SELECT * FROM public.attendance_period_records a
                    WHERE a.school_id = p_school_id
                      AND a.student_id = pb.student_id
                      AND a.attendance_date = p_date
                      AND (
                          (s_elem->>'schedule_id' IS NOT NULL AND a.schedule_id = (s_elem->>'schedule_id')::UUID)
                          OR (s_elem->>'subject_id' IS NOT NULL AND a.subject_id = (s_elem->>'subject_id')::UUID)
                          OR a.period_number = COALESCE((s_elem->>'section_period_number')::INT, (s_elem->>'period_number')::INT)
                      )
                    ORDER BY a.updated_at DESC
                    LIMIT 1
                ) apr ON TRUE
                WHERE (
                    -- STRICT SECTION ISOLATION:
                    -- If schedule targets a section, match only if it matches this student's section!
                    s_elem->>'section_id' IS NULL 
                    OR pb.section_id IS NULL
                    OR (s_elem->>'section_id')::UUID = pb.section_id
                )
            ) AS periods_list
        FROM paginated_base pb
    ),
    student_enriched AS (
        SELECT 
            sp.*,
            (SELECT COUNT(*) FROM jsonb_array_elements(sp.periods_list)) AS total_periods,
            (SELECT COUNT(*) FROM jsonb_array_elements(sp.periods_list) p WHERE p->>'status' != 'NOT_MARKED') AS marked_periods,
            (SELECT COUNT(*) FROM jsonb_array_elements(sp.periods_list) p WHERE p->>'status' = 'PRESENT') AS present_count,
            (SELECT COUNT(*) FROM jsonb_array_elements(sp.periods_list) p WHERE p->>'status' = 'ABSENT') AS absent_count,
            (SELECT COUNT(*) FROM jsonb_array_elements(sp.periods_list) p WHERE p->>'status' = 'LATE') AS late_count,
            (SELECT COUNT(*) FROM jsonb_array_elements(sp.periods_list) p WHERE p->>'status' = 'ON_LEAVE') AS on_leave_count,
            (SELECT COUNT(*) FROM jsonb_array_elements(sp.periods_list) p WHERE p->>'status' = 'HALF_DAY') AS half_day_count
        FROM student_periods_computed sp
    ),
    final_roster AS (
        SELECT 
            se.student_id,
            se.roll_number,
            se.admission_number,
            se.full_name,
            se.avatar_url,
            se.class_id,
            se.class_name,
            se.section_id,
            se.section_name,
            se.daily_record_id AS attendance_record_id,
            CASE 
                WHEN v_mode_norm = 'ALL_DAY' THEN
                    CASE 
                        WHEN se.daily_is_locked = TRUE AND se.daily_status IS NOT NULL THEN se.daily_status
                        WHEN se.total_periods > 0 AND se.marked_periods > 0 AND se.marked_periods = se.total_periods THEN
                            CASE 
                                WHEN se.absent_count = se.total_periods THEN 'ABSENT'
                                WHEN se.present_count = se.total_periods THEN 'PRESENT'
                                WHEN se.on_leave_count = se.total_periods THEN 'ON_LEAVE'
                                WHEN se.present_count > 0 AND (se.absent_count > 0 OR se.on_leave_count > 0 OR se.half_day_count > 0) THEN 'HALF_DAY'
                                WHEN se.half_day_count > 0 THEN 'HALF_DAY'
                                WHEN se.late_count > 0 THEN 'LATE'
                                ELSE 'PRESENT'
                            END
                        WHEN se.total_periods > 0 AND se.marked_periods > 0 AND se.marked_periods < se.total_periods THEN 'PARTIAL_PERIODS'
                        ELSE COALESCE(se.daily_status, 'NOT_MARKED')
                    END
                WHEN v_mode_norm = 'PERIOD' THEN
                    COALESCE(
                        (
                            SELECT p->>'status' 
                            FROM jsonb_array_elements(se.periods_list) p 
                            WHERE (p->>'period_number')::INT = COALESCE(p_period_number, 1) 
                            LIMIT 1
                        ),
                        'NOT_MARKED'
                    )
                ELSE -- MULTI_SCHEDULE / CUSTOM_SELECTION
                    CASE 
                        WHEN se.total_periods > 0 AND se.marked_periods > 0 AND se.marked_periods = se.total_periods THEN
                            CASE 
                                WHEN se.absent_count = se.total_periods THEN 'ABSENT'
                                WHEN se.present_count = se.total_periods THEN 'PRESENT'
                                WHEN se.on_leave_count = se.total_periods THEN 'ON_LEAVE'
                                WHEN se.present_count > 0 AND (se.absent_count > 0 OR se.on_leave_count > 0 OR se.half_day_count > 0) THEN 'HALF_DAY'
                                WHEN se.half_day_count > 0 THEN 'HALF_DAY'
                                WHEN se.late_count > 0 THEN 'LATE'
                                ELSE 'PRESENT'
                            END
                        WHEN se.total_periods > 0 AND se.marked_periods > 0 AND se.marked_periods < se.total_periods THEN 'PARTIAL_PERIODS'
                        ELSE COALESCE(se.daily_status, 'NOT_MARKED')
                    END
            END AS status,
            COALESCE(se.daily_remarks, '') AS remarks,
            se.daily_is_locked AS is_locked,
            se.daily_is_locked AS locked_by_all_day,
            se.daily_is_overridden AS is_overridden,
            se.daily_override_reason AS override_reason,
            se.has_approved_leave,
            se.leave_reason,
            se.daily_updated_at AS last_updated_at,
            se.daily_updated_by_name AS updated_by_name,
            se.periods_list AS periods,
            jsonb_build_object(
                'total_periods', se.total_periods,
                'marked_periods', se.marked_periods,
                'not_marked_count', (se.total_periods - se.marked_periods),
                'present_count', se.present_count,
                'absent_count', se.absent_count,
                'late_count', se.late_count,
                'on_leave_count', se.on_leave_count,
                'half_day_count', se.half_day_count
            ) AS periods_summary
        FROM student_enriched se
    )
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', student_id,
                'student_id', student_id,
                'roll_number', roll_number,
                'admission_number', admission_number,
                'full_name', full_name,
                'avatar_url', avatar_url,
                'class_id', class_id,
                'class_name', class_name,
                'section_id', section_id,
                'section_name', section_name,
                'attendance_record_id', attendance_record_id,
                'status', status,
                'remarks', remarks,
                'is_locked', is_locked,
                'locked_by_all_day', locked_by_all_day,
                'is_overridden', is_overridden,
                'override_reason', override_reason,
                'has_approved_leave', has_approved_leave,
                'leave_reason', leave_reason,
                'last_updated_at', last_updated_at,
                'updated_by_name', updated_by_name,
                'periods', periods,
                'periods_summary', periods_summary
            ) ORDER BY 
                CASE WHEN roll_number ~ '^[0-9]+$' THEN roll_number::INT ELSE 9999 END ASC,
                full_name ASC
        ),
        '[]'::JSONB
    ) INTO v_students
    FROM final_roster;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'students', v_students,
            'total_count', v_total_count,
            'page', p_page,
            'page_size', p_page_size,
            'total_pages', CEIL(v_total_count::NUMERIC / GREATEST(p_page_size, 1)),
            'is_locked_all_day', v_is_locked_all_day,
            'locked_at', v_locked_at,
            'locked_by_name', v_locked_by_name,
            'schedules', v_schedules_json
        )
    );
END;
$$;
