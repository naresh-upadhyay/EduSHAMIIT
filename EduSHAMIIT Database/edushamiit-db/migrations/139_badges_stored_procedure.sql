-- Migration 139: Badges Stored Procedure
-- Natively implements rule-based badge evaluations inside PostgreSQL to resolve API N+1 queries.

CREATE OR REPLACE FUNCTION public.fn_calculate_subject_average(
    p_school_id UUID,
    p_student_id UUID,
    p_subject_name TEXT
) RETURNS NUMERIC AS $$
DECLARE
    v_subject_ids UUID[];
    v_exam_score_sum NUMERIC := 0.0;
    v_exam_max_sum NUMERIC := 0.0;
    v_legacy_score_sum NUMERIC := 0.0;
    v_legacy_max_sum NUMERIC := 0.0;
    v_hw_score_sum NUMERIC := 0.0;
    v_hw_max_sum NUMERIC := 0.0;
    v_exam_avg NUMERIC := 0.0;
    v_hw_avg NUMERIC := 0.0;
BEGIN
    -- 1. Resolve subject IDs by name
    SELECT array_agg(id) INTO v_subject_ids
    FROM public.subjects
    WHERE school_id = p_school_id AND LOWER(TRIM(name)) = LOWER(TRIM(p_subject_name));

    IF v_subject_ids IS NULL OR cardinality(v_subject_ids) = 0 THEN
        RETURN 0.0;
    END IF;

    -- 2. Fetch exam submissions
    SELECT COALESCE(SUM(es.score), 0.0), COALESCE(SUM(e.total_marks), 0.0)
    INTO v_exam_score_sum, v_exam_max_sum
    FROM public.exam_submissions es
    JOIN public.exams e ON es.exam_id = e.id
    WHERE es.student_id = p_student_id AND es.status = 'graded' AND e.subject_id = ANY(v_subject_ids);

    -- 3. Fetch legacy results
    SELECT COALESCE(SUM(r.marks_obtained), 0.0), COALESCE(SUM(r.total_marks), 0.0)
    INTO v_legacy_score_sum, v_legacy_max_sum
    FROM public.results r
    WHERE r.school_id = p_school_id AND r.student_id = p_student_id AND r.subject_id = ANY(v_subject_ids);

    v_exam_score_sum := v_exam_score_sum + v_legacy_score_sum;
    v_exam_max_sum := v_exam_max_sum + v_legacy_max_sum;

    -- 4. Fetch homework submissions
    SELECT COALESCE(SUM(hs.marks), 0.0), COALESCE(SUM(h.max_marks), 0.0)
    INTO v_hw_score_sum, v_hw_max_sum
    FROM public.homework_submissions hs
    JOIN public.homework h ON hs.homework_id = h.id
    WHERE hs.student_id = p_student_id AND hs.status = 'graded' AND h.subject_id = ANY(v_subject_ids);

    IF v_exam_max_sum > 0 THEN
        v_exam_avg := (v_exam_score_sum / v_exam_max_sum) * 100.0;
    END IF;

    IF v_hw_max_sum > 0 THEN
        v_hw_avg := (v_hw_score_sum / v_hw_max_sum) * 100.0;
    END IF;

    IF v_exam_max_sum > 0 AND v_hw_max_sum > 0 THEN
        RETURN (v_exam_avg * 0.6) + (v_hw_avg * 0.4);
    ELSIF v_exam_max_sum > 0 THEN
        RETURN v_exam_avg;
    ELSIF v_hw_max_sum > 0 THEN
        RETURN v_hw_avg;
    ELSE
        RETURN 0.0;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.fn_evaluate_and_update_student_badges(
    p_school_id UUID,
    p_student_id UUID
) RETURNS VOID AS $$
DECLARE
    v_rec RECORD;
    v_existing_id UUID;
    v_existing_progress NUMERIC;
    v_calculated_progress NUMERIC;
    v_subject_name TEXT;
    v_min_average NUMERIC;
    v_min_days INT;
    v_target_count INT;
    v_min_percentage NUMERIC;
    v_min_subjects INT;
    v_class_name TEXT;
    v_student_avg NUMERIC;
    v_topper_avg NUMERIC;
    v_hw_count INT;
    v_streak INT;
    v_borrows_count INT;
    v_stem_avg_count INT;
    v_stem_rec RECORD;
    v_unlocked_xp INT := 0;
    v_current_xp INT := 0;
    v_has_changes BOOLEAN := FALSE;
    v_attendance_pct NUMERIC;
BEGIN
    -- Loop through all achievements defined for the school with rules configured
    FOR v_rec IN 
        SELECT id, name, rule_type, rule_params, xp_reward
        FROM public.achievements 
        WHERE school_id = p_school_id AND rule_type IS NOT NULL
    LOOP
        -- Check if student already has earned this badge at 100.0%
        SELECT id, progress INTO v_existing_id, v_existing_progress
        FROM public.student_achievements
        WHERE school_id = p_school_id AND student_id = p_student_id AND achievement_id = v_rec.id;

        IF v_existing_progress >= 100.0 THEN
            CONTINUE;
        END IF;

        v_calculated_progress := 0.0;

        -- Evaluate progress based on rule_type
        IF v_rec.rule_type = 'subject_average' THEN
            v_subject_name := v_rec.rule_params->>'subject_name';
            v_min_average := COALESCE((v_rec.rule_params->>'min_average')::NUMERIC, 90.0);

            IF v_subject_name IS NOT NULL AND v_subject_name <> '' THEN
                v_calculated_progress := (public.fn_calculate_subject_average(p_school_id, p_student_id, v_subject_name) / v_min_average) * 100.0;
            ELSE
                -- Any exam score >= 90% (max exam pct)
                DECLARE
                    v_max_exam_pct NUMERIC := 0.0;
                    v_exam_pct NUMERIC;
                    v_sub_rec RECORD;
                BEGIN
                    FOR v_sub_rec IN 
                        SELECT es.score, e.total_marks
                        FROM public.exam_submissions es
                        JOIN public.exams e ON es.exam_id = e.id
                        WHERE es.student_id = p_student_id AND es.status = 'graded' AND e.total_marks > 0
                    LOOP
                        v_exam_pct := (v_sub_rec.score / v_sub_rec.total_marks) * 100.0;
                        IF v_exam_pct > v_max_exam_pct THEN
                            v_max_exam_pct := v_exam_pct;
                        END IF;
                    END LOOP;

                    FOR v_sub_rec IN 
                        SELECT r.marks_obtained, r.total_marks
                        FROM public.results r
                        WHERE r.school_id = p_school_id AND r.student_id = p_student_id AND r.total_marks > 0
                    LOOP
                        v_exam_pct := (v_sub_rec.marks_obtained / v_sub_rec.total_marks) * 100.0;
                        IF v_exam_pct > v_max_exam_pct THEN
                            v_max_exam_pct := v_exam_pct;
                        END IF;
                    END LOOP;

                    v_calculated_progress := (v_max_exam_pct / v_min_average) * 100.0;
                END;
            END IF;

        ELSIF v_rec.rule_type = 'class_topper' THEN
            SELECT class INTO v_class_name FROM public.profiles WHERE id = p_student_id;
            IF v_class_name IS NOT NULL AND v_class_name <> '' THEN
                SELECT COALESCE(avg_score, 0.0) INTO v_student_avg FROM public.student_profile_stats WHERE student_id = p_student_id;
                SELECT COALESCE(MAX(avg_score), 0.0) INTO v_topper_avg FROM public.student_profile_stats WHERE school_id = p_school_id AND class = v_class_name;
                
                IF v_topper_avg > 0.0 THEN
                    IF v_student_avg >= v_topper_avg THEN
                        v_calculated_progress := 100.0;
                    ELSE
                        v_calculated_progress := (v_student_avg / v_topper_avg) * 100.0;
                    END IF;
                END IF;
            END IF;

        ELSIF v_rec.rule_type = 'attendance_pct' THEN
            v_min_percentage := COALESCE((v_rec.rule_params->>'min_percentage')::NUMERIC, 100.0);
            SELECT COALESCE(attendance_pct, 0.0) INTO v_attendance_pct FROM public.student_profile_stats WHERE student_id = p_student_id;
            
            v_calculated_progress := (v_attendance_pct / v_min_percentage) * 100.0;

        ELSIF v_rec.rule_type = 'homework_submissions' THEN
            v_target_count := COALESCE((v_rec.rule_params->>'count')::INT, 5);
            SELECT COUNT(*) INTO v_hw_count FROM public.homework_submissions WHERE student_id = p_student_id AND status = 'graded';
            
            v_calculated_progress := (v_hw_count::NUMERIC / v_target_count::NUMERIC) * 100.0;

        ELSIF v_rec.rule_type = 'streak_days' THEN
            v_min_days := COALESCE((v_rec.rule_params->>'min_days')::INT, 18);
            SELECT COALESCE(learning_streak, 0) INTO v_streak FROM public.profiles WHERE id = p_student_id;
            
            v_calculated_progress := (v_streak::NUMERIC / v_min_days::NUMERIC) * 100.0;

        ELSIF v_rec.rule_type = 'library_borrows' THEN
            v_target_count := COALESCE((v_rec.rule_params->>'count')::INT, 10);
            SELECT COUNT(*) INTO v_borrows_count FROM public.library_borrows WHERE student_id = p_student_id;
            
            v_calculated_progress := (v_borrows_count::NUMERIC / v_target_count::NUMERIC) * 100.0;

        ELSIF v_rec.rule_type = 'science_prodigy' THEN
            v_min_average := COALESCE((v_rec.rule_params->>'min_average')::NUMERIC, 90.0);
            v_min_subjects := COALESCE((v_rec.rule_params->>'min_subjects')::INT, 2);
            v_stem_avg_count := 0;

            -- Check Mathematics, Physics, Chemistry, Biology, Computer Science
            FOR v_stem_rec IN 
                SELECT s.name
                FROM public.subjects s
                WHERE s.school_id = p_school_id 
                  AND LOWER(TRIM(s.name)) IN ('mathematics', 'physics', 'chemistry', 'biology', 'computer science')
            LOOP
                IF public.fn_calculate_subject_average(p_school_id, p_student_id, v_stem_rec.name) >= v_min_average THEN
                    v_stem_avg_count := v_stem_avg_count + 1;
                END IF;
            END LOOP;

            v_calculated_progress := (v_stem_avg_count::NUMERIC / v_min_subjects::NUMERIC) * 100.0;
        END IF;

        v_calculated_progress := ROUND(LEAST(100.0, GREATEST(0.0, v_calculated_progress)), 1);

        -- If progress didn't change, do nothing
        IF COALESCE(v_existing_progress, 0.0) = v_calculated_progress THEN
            CONTINUE;
        END IF;

        v_has_changes := TRUE;

        IF v_calculated_progress >= 100.0 THEN
            -- Unlock achievement!
            IF v_existing_id IS NOT NULL THEN
                UPDATE public.student_achievements 
                SET progress = 100.0, earned_at = NOW() 
                WHERE id = v_existing_id;
            ELSE
                INSERT INTO public.student_achievements (school_id, student_id, achievement_id, progress, earned_at)
                VALUES (p_school_id, p_student_id, v_rec.id, 100.0, NOW());
            END IF;

            -- Accumulate XP
            v_unlocked_xp := v_unlocked_xp + v_rec.xp_reward;

            -- Write XP transaction record
            INSERT INTO public.xp_transactions (school_id, student_id, amount, source_type, source_id, description)
            VALUES (p_school_id, p_student_id, v_rec.xp_reward, 'achievement', v_rec.id, 'Achievement unlocked: ' || v_rec.name);

            -- Send notification
            INSERT INTO public.notifications (school_id, user_id, title, body, type, reference_id)
            VALUES (p_school_id, p_student_id, '🏆 Achievement Unlocked: ' || v_rec.name, 'You earned ' || v_rec.xp_reward || ' XP! Keep it up! 🎉', 'achievement', v_rec.id);
        ELSE
            -- Update progress < 100.0
            IF v_existing_id IS NOT NULL THEN
                UPDATE public.student_achievements 
                SET progress = v_calculated_progress, earned_at = NULL 
                WHERE id = v_existing_id;
            ELSE
                INSERT INTO public.student_achievements (school_id, student_id, achievement_id, progress, earned_at)
                VALUES (p_school_id, p_student_id, v_rec.id, v_calculated_progress, NULL);
            END IF;
        END IF;
    END LOOP;

    -- Update profiles.xp_points in one write if new badges unlocked
    IF v_unlocked_xp > 0 THEN
        SELECT COALESCE(xp_points, 0) INTO v_current_xp FROM public.profiles WHERE id = p_student_id;
        UPDATE public.profiles SET xp_points = v_current_xp + v_unlocked_xp WHERE id = p_student_id;
    END IF;
END;
$$ LANGUAGE plpgsql;
