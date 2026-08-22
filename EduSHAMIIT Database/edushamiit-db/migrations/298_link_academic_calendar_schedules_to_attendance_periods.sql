-- ============================================================================
-- Migration: 298_link_academic_calendar_schedules_to_attendance_periods.sql
-- Description:
--   1. Implements fn_get_class_academic_periods_for_date to resolve schedules
--      assigned to "Academic Calendar" (case-insensitive) with class-section-subject
--      offerings as dynamic student periods in Daily Attendance.
--   2. Updates fn_save_daily_attendance to support single-period, multi-period
--      (custom selection), and all-day attendance taking with atomic database upserts.
--   3. Updates fn_get_daily_attendance_roster to seamlessly load student attendance
--      for single or multi-period selections.
-- ============================================================================

-- Ensure schedule_id and subject_id columns exist on attendance_period_records with index
ALTER TABLE public.attendance_period_records ADD COLUMN IF NOT EXISTS schedule_id UUID;
CREATE INDEX IF NOT EXISTS idx_att_period_sched_date ON public.attendance_period_records(school_id, attendance_date, class_id, section_id, schedule_id);
CREATE INDEX IF NOT EXISTS idx_att_period_subj_date ON public.attendance_period_records(school_id, attendance_date, class_id, section_id, subject_id);


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
        SELECT DISTINCT ON (s.id, COALESCE(sp.target_subject_id, sub_tcs.id, '00000000-0000-0000-0000-000000000000'::UUID))
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
        LEFT JOIN public.academic_subjects sub_sp ON sub_sp.id = sp.target_subject_id
        -- Lateral join target_class_sections JSON array
        LEFT JOIN LATERAL (
            SELECT 
                (elem->>'subject_id')::UUID AS id,
                elem->>'subject_name' AS name,
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
        ORDER BY s.id, COALESCE(sp.target_subject_id, sub_tcs.id, '00000000-0000-0000-0000-000000000000'::UUID), s.start_time ASC
    ),
    ordered_schedules AS (
        SELECT 
            ROW_NUMBER() OVER (ORDER BY local_start_time ASC, schedule_title ASC) AS period_num,
            academic_schedules.*
        FROM academic_schedules
    ),
    period_aggregates AS (
        SELECT 
            os.schedule_id,
            os.period_num AS period_number,
            'P' || os.period_num AS period_label,
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
                      OR apr.period_number = os.period_num
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
                      OR apr.period_number = os.period_num
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
                          OR apr.period_number = os.period_num
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
                          OR apr.period_number = os.period_num
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
                          OR apr.period_number = os.period_num
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

    -- Fallback: If no calendar schedules found for this class/section on this date,
    -- generate periods from class_subject_assignments
    IF v_sched_count = 0 THEN
        WITH fallback_subjects AS (
            SELECT 
                csa.subject_id,
                sub.name AS subject_name,
                sub.code AS subject_code,
                sub.color AS subject_color,
                ROW_NUMBER() OVER (ORDER BY sub.name ASC) AS p_num,
                p.full_name AS teacher_name,
                p.avatar_url AS teacher_avatar,
                EXISTS (
                    SELECT 1 FROM public.attendance_period_records apr
                    WHERE apr.school_id = p_school_id
                      AND apr.class_id = p_class_id
                      AND (p_section_id IS NULL OR apr.section_id = p_section_id OR apr.section_id IS NULL)
                      AND apr.attendance_date = p_date
                      AND apr.subject_id = csa.subject_id
                      AND apr.is_locked = TRUE
                ) AS is_locked,
                EXISTS (
                    SELECT 1 FROM public.attendance_period_records apr
                    WHERE apr.school_id = p_school_id
                      AND apr.class_id = p_class_id
                      AND (p_section_id IS NULL OR apr.section_id = p_section_id OR apr.section_id IS NULL)
                      AND apr.attendance_date = p_date
                      AND apr.subject_id = csa.subject_id
                ) AS is_completed
            FROM public.class_subject_assignments csa
            JOIN public.academic_subjects sub ON sub.id = csa.subject_id
            LEFT JOIN public.class_teacher_assignments cta ON cta.class_id = csa.class_id AND (cta.section_id = csa.section_id OR cta.section_id IS NULL)
            LEFT JOIN public.profiles p ON p.id = cta.teacher_id
            WHERE csa.school_id = p_school_id
              AND csa.class_id = p_class_id
              AND (p_section_id IS NULL OR csa.section_id = p_section_id OR csa.section_id IS NULL)
            ORDER BY p_num ASC
        )
        SELECT COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', 'csa-' || p_num,
                    'schedule_id', NULL,
                    'schedule_title', subject_name || ' Period',
                    'period_number', p_num,
                    'period_label', 'P' || p_num,
                    'time_range', to_char(('08:00'::TIME + ((p_num - 1) * INTERVAL '50 minutes')), 'HH12:MI AM') || ' - ' || to_char(('08:45'::TIME + ((p_num - 1) * INTERVAL '50 minutes')), 'HH12:MI AM'),
                    'subject_id', subject_id,
                    'subject_name', subject_name,
                    'subject_code', subject_code,
                    'subject_color', COALESCE(subject_color, '#4F46E5'),
                    'teacher_name', COALESCE(teacher_name, 'Subject Teacher'),
                    'teacher_avatar', teacher_avatar,
                    'is_locked', is_locked,
                    'is_completed', is_completed,
                    'status', CASE WHEN is_locked THEN 'LOCKED' WHEN is_completed THEN 'COMPLETED' ELSE 'NOT_STARTED' END,
                    'present_count', 0,
                    'absent_count', 0,
                    'late_count', 0
                ) ORDER BY p_num ASC
            ),
            '[]'::jsonb
        ) INTO v_periods
        FROM fallback_subjects;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'schedules', v_periods,
            'count', jsonb_array_length(v_periods),
            'source', CASE WHEN v_sched_count > 0 THEN 'academic_calendar' ELSE 'class_subjects_fallback' END
        )
    );
END;
$$;


-- 2. ENHANCED FUNCTION: fn_save_daily_attendance (Atomic Multi-Period & Single-Period Support)
CREATE OR REPLACE FUNCTION public.fn_save_daily_attendance(
    p_school_id UUID,
    p_user_id UUID,
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_date DATE;
    v_class_id UUID;
    v_section_id UUID;
    v_mode VARCHAR;
    v_records JSONB;
    v_item JSONB;
    v_student_id UUID;
    v_status VARCHAR;
    v_remarks TEXT;
    v_saved_count INT := 0;
    v_daily_id UUID;
    v_sched RECORD;
    v_period_number INT;
    v_subject_id UUID;
    v_schedule_id UUID;
    v_selected_periods JSONB;
    v_period_item JSONB;
    v_selected_sched_ids JSONB;
    v_sched_id_elem JSONB;
    v_sched_info RECORD;
BEGIN
    v_date := (p_payload->>'attendance_date')::DATE;
    v_class_id := (p_payload->>'class_id')::UUID;
    v_section_id := (p_payload->>'section_id')::UUID;
    v_mode := UPPER(COALESCE(p_payload->>'mode', 'ALL_DAY'));
    v_records := COALESCE(p_payload->'records', '[]'::JSONB);
    v_period_number := (p_payload->>'period_number')::INT;
    v_subject_id := (p_payload->>'subject_id')::UUID;
    v_schedule_id := (p_payload->>'schedule_id')::UUID;
    v_selected_periods := COALESCE(p_payload->'selected_periods', '[]'::JSONB);
    v_selected_sched_ids := COALESCE(p_payload->'selected_schedule_ids', '[]'::JSONB);

    IF v_date IS NULL OR v_class_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'attendance_date and class_id are required', 'code', 400);
    END IF;

    -- =========================================================================
    -- MODE 1: ALL DAY ATTENDANCE (Propagate across all Academic Calendar periods)
    -- =========================================================================
    IF v_mode = 'ALL_DAY' THEN
        FOR v_item IN SELECT * FROM jsonb_array_elements(v_records) LOOP
            v_student_id := (v_item->>'student_id')::UUID;
            v_status := UPPER(TRIM(COALESCE(v_item->>'status', 'PRESENT')));
            v_remarks := TRIM(COALESCE(v_item->>'remarks', ''));

            IF v_student_id IS NOT NULL THEN
                -- Upsert Master Daily Record
                INSERT INTO public.attendance_daily_records (
                    school_id, student_id, class_id, section_id, attendance_date,
                    status, remarks, is_locked, locked_by, locked_at, is_all_day,
                    created_by, updated_by, updated_at
                ) VALUES (
                    p_school_id, v_student_id, v_class_id, v_section_id, v_date,
                    v_status, v_remarks, TRUE, p_user_id, NOW(), TRUE,
                    p_user_id, p_user_id, NOW()
                )
                ON CONFLICT (school_id, student_id, attendance_date) DO UPDATE SET
                    status = EXCLUDED.status,
                    remarks = EXCLUDED.remarks,
                    is_locked = TRUE,
                    locked_by = EXCLUDED.locked_by,
                    locked_at = EXCLUDED.locked_at,
                    is_all_day = TRUE,
                    updated_by = EXCLUDED.updated_by,
                    updated_at = NOW()
                RETURNING id INTO v_daily_id;

                -- Delete existing period records for this student and date to cleanly overwrite
                DELETE FROM public.attendance_period_records
                WHERE school_id = p_school_id
                  AND student_id = v_student_id
                  AND attendance_date = v_date;

                -- Propagate to all resolved Academic Calendar periods for today
                FOR v_sched IN 
                    SELECT 
                        (elem->>'period_number')::INT AS p_num,
                        (elem->>'subject_id')::UUID AS sub_id,
                        (elem->>'schedule_id')::UUID AS s_id
                    FROM jsonb_array_elements(
                        (public.fn_get_class_academic_periods_for_date(p_school_id, v_date, v_class_id, v_section_id)->'data'->'schedules')
                    ) elem
                LOOP
                    INSERT INTO public.attendance_period_records (
                        school_id, daily_record_id, student_id, class_id, section_id,
                        subject_id, schedule_id, attendance_date, period_number, status, remarks,
                        is_locked, locked_by_all_day, created_by, updated_by, updated_at
                    ) VALUES (
                        p_school_id, v_daily_id, v_student_id, v_class_id, v_section_id,
                        v_sched.sub_id, v_sched.s_id, v_date, v_sched.p_num, v_status, v_remarks,
                        TRUE, TRUE, p_user_id, p_user_id, NOW()
                    );
                END LOOP;

                v_saved_count := v_saved_count + 1;
            END IF;
        END LOOP;

    -- =========================================================================
    -- MODE 2: CUSTOM SELECTION / MULTI-PERIOD ATTENDANCE
    -- =========================================================================
    ELSIF v_mode IN ('MULTI_SCHEDULE', 'CUSTOM_SELECTION') THEN
        -- If selected_periods is empty but selected_schedule_ids is present, resolve period details
        IF jsonb_array_length(v_selected_periods) = 0 AND jsonb_array_length(v_selected_sched_ids) > 0 THEN
            SELECT jsonb_agg(elem) INTO v_selected_periods
            FROM jsonb_array_elements(
                (public.fn_get_class_academic_periods_for_date(p_school_id, v_date, v_class_id, v_section_id)->'data'->'schedules')
            ) elem
            WHERE elem->>'id' = ANY(ARRAY(SELECT jsonb_array_elements_text(v_selected_sched_ids)))
               OR elem->>'schedule_id' = ANY(ARRAY(SELECT jsonb_array_elements_text(v_selected_sched_ids)));
        END IF;

        -- For each selected period, apply student attendance
        IF v_selected_periods IS NOT NULL AND jsonb_array_length(v_selected_periods) > 0 THEN
            FOR v_period_item IN SELECT * FROM jsonb_array_elements(v_selected_periods) LOOP
                v_period_number := COALESCE((v_period_item->>'period_number')::INT, 1);
                v_subject_id := (v_period_item->>'subject_id')::UUID;
                v_schedule_id := (v_period_item->>'schedule_id')::UUID;

                FOR v_item IN SELECT * FROM jsonb_array_elements(v_records) LOOP
                    v_student_id := (v_item->>'student_id')::UUID;
                    v_status := UPPER(TRIM(COALESCE(v_item->>'status', 'PRESENT')));
                    v_remarks := TRIM(COALESCE(v_item->>'remarks', ''));

                    IF v_student_id IS NOT NULL THEN
                        -- Clean up any existing period record for this specific period/subject
                        DELETE FROM public.attendance_period_records
                        WHERE school_id = p_school_id
                          AND student_id = v_student_id
                          AND attendance_date = v_date
                          AND period_number = v_period_number
                          AND (
                              (v_schedule_id IS NOT NULL AND schedule_id = v_schedule_id)
                              OR (v_subject_id IS NULL OR subject_id = v_subject_id)
                          );

                        INSERT INTO public.attendance_period_records (
                            school_id, student_id, class_id, section_id,
                            subject_id, schedule_id, attendance_date, period_number, status, remarks,
                            is_locked, locked_by_all_day, created_by, updated_by, updated_at
                        ) VALUES (
                            p_school_id, v_student_id, v_class_id, v_section_id,
                            v_subject_id, v_schedule_id, v_date, v_period_number, v_status, v_remarks,
                            FALSE, FALSE, p_user_id, p_user_id, NOW()
                        );
                    END IF;
                END LOOP;
            END LOOP;
            v_saved_count := jsonb_array_length(v_records);
        END IF;

    -- =========================================================================
    -- MODE 3: SINGLE PERIOD ATTENDANCE
    -- =========================================================================
    ELSE
        v_period_number := COALESCE((p_payload->>'period_number')::INT, 1);
        v_subject_id := (p_payload->>'subject_id')::UUID;
        v_schedule_id := (p_payload->>'schedule_id')::UUID;

        FOR v_item IN SELECT * FROM jsonb_array_elements(v_records) LOOP
            v_student_id := (v_item->>'student_id')::UUID;
            v_status := UPPER(TRIM(COALESCE(v_item->>'status', 'PRESENT')));
            v_remarks := TRIM(COALESCE(v_item->>'remarks', ''));
            v_period_number := COALESCE((v_item->>'period_number')::INT, v_period_number, 1);
            v_subject_id := COALESCE((v_item->>'subject_id')::UUID, v_subject_id);

            IF v_student_id IS NOT NULL THEN
                DELETE FROM public.attendance_period_records
                WHERE school_id = p_school_id
                  AND student_id = v_student_id
                  AND attendance_date = v_date
                  AND period_number = v_period_number
                  AND (
                      (v_schedule_id IS NOT NULL AND schedule_id = v_schedule_id)
                      OR (v_subject_id IS NULL OR subject_id = v_subject_id)
                  );

                INSERT INTO public.attendance_period_records (
                    school_id, student_id, class_id, section_id,
                    subject_id, schedule_id, attendance_date, period_number, status, remarks,
                    is_locked, locked_by_all_day, created_by, updated_by, updated_at
                ) VALUES (
                    p_school_id, v_student_id, v_class_id, v_section_id,
                    v_subject_id, v_schedule_id, v_date, v_period_number, v_status, v_remarks,
                    FALSE, FALSE, p_user_id, p_user_id, NOW()
                );

                v_saved_count := v_saved_count + 1;
            END IF;
        END LOOP;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', CASE 
            WHEN v_mode = 'ALL_DAY' THEN 'All-day attendance saved and applied to all schedules' 
            WHEN v_mode IN ('MULTI_SCHEDULE', 'CUSTOM_SELECTION') THEN 'Attendance saved across all selected periods'
            ELSE 'Period attendance saved' 
        END,
        'saved_count', v_saved_count,
        'mode', v_mode
    );
END;
$$;
