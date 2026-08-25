-- Migration 322: Support Grid-State Saving in Daily Attendance
-- Ensures that when saving daily attendance, the exact current status of all students and their
-- respective periods as displayed in the grid are saved directly to the database.

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
    v_total_sched_count INT := 0;
    v_student_marked_periods INT := 0;
    v_distinct_statuses TEXT[];
    v_composite_daily_status VARCHAR;
    v_student_periods JSONB;
    v_p_item JSONB;
    v_p_num INT;
    v_p_status VARCHAR;
    v_p_remarks TEXT;
    v_p_sub_id UUID;
    v_p_sched_id UUID;
    v_has_grid_periods BOOLEAN := FALSE;
    v_schedules_meta JSONB;
BEGIN
    v_date := (p_payload->>'attendance_date')::DATE;
    v_class_id := (p_payload->>'class_id')::UUID;
    v_section_id := (p_payload->>'section_id')::UUID;
    v_mode := UPPER(COALESCE(p_payload->>'mode', 'ALL_DAY'));
    v_records := COALESCE(p_payload->'records', '[]'::JSONB);
    v_period_number := (p_payload->>'period_number')::INT;
    v_subject_id := NULLIF(TRIM(p_payload->>'subject_id'), '')::UUID;
    v_schedule_id := NULLIF(TRIM(p_payload->>'schedule_id'), '')::UUID;
    v_selected_periods := COALESCE(p_payload->'selected_periods', '[]'::JSONB);
    v_selected_sched_ids := COALESCE(p_payload->'selected_schedule_ids', '[]'::JSONB);

    IF v_date IS NULL OR v_class_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'attendance_date and class_id are required', 'code', 400);
    END IF;

    -- Fetch schedules metadata for date/class/section
    SELECT COALESCE(public.fn_get_class_academic_periods_for_date(p_school_id, v_date, v_class_id, v_section_id)->'data'->'schedules', '[]'::JSONB)
    INTO v_schedules_meta;
    v_total_sched_count := COALESCE(jsonb_array_length(v_schedules_meta), 0);

    -- Check safely if records contain per-student period breakdowns from the grid
    SELECT EXISTS (
        SELECT 1 FROM jsonb_array_elements(v_records) elem
        WHERE elem ? 'periods' 
          AND elem->'periods' IS NOT NULL
          AND jsonb_typeof(elem->'periods') = 'array' 
          AND (SELECT COUNT(*) FROM jsonb_array_elements(elem->'periods')) > 0
    ) INTO v_has_grid_periods;

    -- =========================================================================
    -- BRANCH A: GRID-STATE SAVING (Saves exact grid state of all students & periods)
    -- =========================================================================
    IF v_has_grid_periods THEN
        FOR v_item IN SELECT * FROM jsonb_array_elements(v_records) LOOP
            v_student_id := NULLIF(TRIM(v_item->>'student_id'), '')::UUID;
            v_status := UPPER(TRIM(COALESCE(v_item->>'status', 'PRESENT')));
            v_remarks := TRIM(COALESCE(v_item->>'remarks', ''));
            v_student_periods := v_item->'periods';

            IF v_student_id IS NOT NULL THEN
                -- 1. Upsert Master Daily Record with student's current status & remarks
                INSERT INTO public.attendance_daily_records (
                    school_id, student_id, class_id, section_id, attendance_date,
                    status, remarks, is_locked, locked_by, locked_at, is_all_day,
                    created_by, updated_by, updated_at
                ) VALUES (
                    p_school_id, v_student_id, v_class_id, v_section_id, v_date,
                    v_status, v_remarks, TRUE, p_user_id, NOW(), (v_mode = 'ALL_DAY'),
                    p_user_id, p_user_id, NOW()
                )
                ON CONFLICT (school_id, student_id, attendance_date) DO UPDATE SET
                    status = EXCLUDED.status,
                    remarks = EXCLUDED.remarks,
                    is_locked = TRUE,
                    locked_by = EXCLUDED.locked_by,
                    locked_at = EXCLUDED.locked_at,
                    is_all_day = (v_mode = 'ALL_DAY'),
                    updated_by = EXCLUDED.updated_by,
                    updated_at = NOW()
                RETURNING id INTO v_daily_id;

                -- 2. If periods array is provided for this student, save each period record
                IF v_student_periods IS NOT NULL 
                   AND jsonb_typeof(v_student_periods) = 'array' 
                   AND (SELECT COUNT(*) FROM jsonb_array_elements(v_student_periods)) > 0 THEN
                    
                    -- Clean up existing period records for this student and date
                    DELETE FROM public.attendance_period_records
                    WHERE school_id = p_school_id
                      AND student_id = v_student_id
                      AND attendance_date = v_date;

                    FOR v_p_item IN SELECT * FROM jsonb_array_elements(v_student_periods) LOOP
                        v_p_num := (v_p_item->>'period_number')::INT;
                        v_p_status := UPPER(TRIM(COALESCE(v_p_item->>'status', 'PRESENT')));
                        v_p_remarks := TRIM(COALESCE(v_p_item->>'remarks', ''));
                        v_p_sub_id := NULLIF(TRIM(v_p_item->>'subject_id'), '')::UUID;
                        v_p_sched_id := NULLIF(TRIM(v_p_item->>'schedule_id'), '')::UUID;

                        -- Auto-resolve subject_id and schedule_id from schedule metadata if missing
                        IF v_p_num IS NOT NULL AND (v_p_sub_id IS NULL OR v_p_sched_id IS NULL) THEN
                            SELECT 
                                COALESCE(v_p_sub_id, NULLIF(TRIM(s_elem->>'subject_id'), '')::UUID),
                                COALESCE(v_p_sched_id, NULLIF(TRIM(s_elem->>'schedule_id'), '')::UUID)
                            INTO v_p_sub_id, v_p_sched_id
                            FROM jsonb_array_elements(v_schedules_meta) s_elem
                            WHERE (s_elem->>'period_number')::INT = v_p_num
                            LIMIT 1;
                        END IF;

                        IF v_p_num IS NOT NULL THEN
                            INSERT INTO public.attendance_period_records (
                                school_id, daily_record_id, student_id, class_id, section_id,
                                subject_id, schedule_id, attendance_date, period_number, status, remarks,
                                is_locked, locked_by_all_day, created_by, updated_by, updated_at
                            ) VALUES (
                                p_school_id, v_daily_id, v_student_id, v_class_id, v_section_id,
                                v_p_sub_id, v_p_sched_id, v_date, v_p_num, v_p_status, v_p_remarks,
                                TRUE, (v_mode = 'ALL_DAY'), p_user_id, p_user_id, NOW()
                            );
                        END IF;
                    END LOOP;
                END IF;

                v_saved_count := v_saved_count + 1;
            END IF;
        END LOOP;

    -- =========================================================================
    -- BRANCH B: LEGACY ALL DAY ATTENDANCE (When no per-student periods provided)
    -- =========================================================================
    ELSIF v_mode = 'ALL_DAY' THEN
        FOR v_item IN SELECT * FROM jsonb_array_elements(v_records) LOOP
            v_student_id := NULLIF(TRIM(v_item->>'student_id'), '')::UUID;
            v_status := UPPER(TRIM(COALESCE(v_item->>'status', 'PRESENT')));
            v_remarks := TRIM(COALESCE(v_item->>'remarks', ''));

            IF v_student_id IS NOT NULL THEN
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

                DELETE FROM public.attendance_period_records
                WHERE school_id = p_school_id
                  AND student_id = v_student_id
                  AND attendance_date = v_date;

                FOR v_sched IN 
                    SELECT 
                        (elem->>'period_number')::INT AS p_num,
                        NULLIF(TRIM(elem->>'subject_id'), '')::UUID AS sub_id,
                        NULLIF(TRIM(elem->>'schedule_id'), '')::UUID AS s_id
                    FROM jsonb_array_elements(v_schedules_meta) elem
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
    -- BRANCH C: LEGACY CUSTOM SELECTION (Multi-Period Attendance)
    -- =========================================================================
    ELSIF v_mode IN ('MULTI_SCHEDULE', 'CUSTOM_SELECTION') THEN
        IF jsonb_array_length(v_selected_periods) = 0 AND jsonb_array_length(v_selected_sched_ids) > 0 THEN
            SELECT jsonb_agg(elem) INTO v_selected_periods
            FROM jsonb_array_elements(v_schedules_meta) elem
            WHERE elem->>'id' = ANY(ARRAY(SELECT jsonb_array_elements_text(v_selected_sched_ids)))
               OR elem->>'schedule_id' = ANY(ARRAY(SELECT jsonb_array_elements_text(v_selected_sched_ids)));
        END IF;

        IF v_selected_periods IS NOT NULL AND jsonb_array_length(v_selected_periods) > 0 THEN
            FOR v_period_item IN SELECT * FROM jsonb_array_elements(v_selected_periods) LOOP
                v_period_number := COALESCE((v_period_item->>'period_number')::INT, 1);
                v_subject_id := NULLIF(TRIM(v_period_item->>'subject_id'), '')::UUID;
                v_schedule_id := NULLIF(TRIM(v_period_item->>'schedule_id'), '')::UUID;

                FOR v_item IN SELECT * FROM jsonb_array_elements(v_records) LOOP
                    v_student_id := NULLIF(TRIM(v_item->>'student_id'), '')::UUID;
                    v_status := UPPER(TRIM(COALESCE(v_item->>'status', 'PRESENT')));
                    v_remarks := TRIM(COALESCE(v_item->>'remarks', ''));

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
                    END IF;
                END LOOP;
            END LOOP;
            v_saved_count := jsonb_array_length(v_records);
        END IF;

    -- =========================================================================
    -- BRANCH D: LEGACY SINGLE PERIOD ATTENDANCE
    -- =========================================================================
    ELSE
        v_period_number := COALESCE((p_payload->>'period_number')::INT, 1);
        v_subject_id := NULLIF(TRIM(p_payload->>'subject_id'), '')::UUID;
        v_schedule_id := NULLIF(TRIM(p_payload->>'schedule_id'), '')::UUID;

        FOR v_item IN SELECT * FROM jsonb_array_elements(v_records) LOOP
            v_student_id := NULLIF(TRIM(v_item->>'student_id'), '')::UUID;
            v_status := UPPER(TRIM(COALESCE(v_item->>'status', 'PRESENT')));
            v_remarks := TRIM(COALESCE(v_item->>'remarks', ''));
            v_period_number := COALESCE((v_item->>'period_number')::INT, v_period_number, 1);
            v_subject_id := COALESCE(NULLIF(TRIM(v_item->>'subject_id'), '')::UUID, v_subject_id);

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
        'message', 'Attendance saved successfully',
        'saved_count', v_saved_count,
        'mode', v_mode
    );
END;
$$;
