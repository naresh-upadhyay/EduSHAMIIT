CREATE OR REPLACE FUNCTION get_leaderboard(p_school_id UUID, p_class TEXT, p_limit INT DEFAULT 10)
RETURNS TABLE (rank INT, student_id UUID, full_name TEXT, xp_points INT, learning_streak INT) AS $$
BEGIN RETURN QUERY SELECT ROW_NUMBER() OVER (ORDER BY p.xp_points DESC)::INT AS rank, p.id AS student_id, p.full_name, p.xp_points, p.learning_streak FROM profiles p WHERE p.school_id = p_school_id AND p.class = p_class AND p.role = 'student' ORDER BY p.xp_points DESC LIMIT p_limit; END; $$ LANGUAGE plpgsql;
