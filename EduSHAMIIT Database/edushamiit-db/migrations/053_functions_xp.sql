CREATE OR REPLACE FUNCTION update_student_xp(p_school_id UUID, p_student_id UUID, p_xp_to_add INT, p_action TEXT) RETURNS VOID AS $$
DECLARE v_last_login DATE; v_current_streak INT;
BEGIN SELECT last_login, learning_streak INTO v_last_login, v_current_streak FROM profiles WHERE id = p_student_id AND school_id = p_school_id;
IF v_last_login = CURRENT_DATE - INTERVAL '1 day' THEN UPDATE profiles SET learning_streak = v_current_streak + 1, best_streak = GREATEST(v_current_streak + 1, best_streak), last_login = CURRENT_DATE, xp_points = xp_points + p_xp_to_add WHERE id = p_student_id AND school_id = p_school_id;
ELSIF v_last_login < CURRENT_DATE - INTERVAL '1 day' THEN UPDATE profiles SET learning_streak = 1, last_login = CURRENT_DATE, xp_points = xp_points + p_xp_to_add WHERE id = p_student_id AND school_id = p_school_id;
ELSE UPDATE profiles SET xp_points = xp_points + p_xp_to_add WHERE id = p_student_id AND school_id = p_school_id; END IF; END; $$ LANGUAGE plpgsql;
