CREATE OR REPLACE FUNCTION trigger_homework_xp() RETURNS TRIGGER AS $$ BEGIN PERFORM update_student_xp(NEW.school_id, NEW.student_id, 50, 'homework_submission'); RETURN NEW; END; $$ LANGUAGE plpgsql;
CREATE TRIGGER homework_submission_xp AFTER INSERT ON homework_submissions FOR EACH ROW EXECUTE FUNCTION trigger_homework_xp();
CREATE OR REPLACE FUNCTION trigger_exam_xp() RETURNS TRIGGER AS $$ BEGIN IF NEW.status = 'submitted' THEN PERFORM update_student_xp(NEW.school_id, NEW.student_id, 100, 'exam_submission'); END IF; RETURN NEW; END; $$ LANGUAGE plpgsql;
CREATE TRIGGER exam_session_xp AFTER UPDATE ON exam_sessions FOR EACH ROW WHEN (NEW.status = 'submitted' AND OLD.status = 'in_progress') EXECUTE FUNCTION trigger_exam_xp();
CREATE OR REPLACE FUNCTION trigger_update_timestamp() RETURNS TRIGGER AS $$ BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$ LANGUAGE plpgsql;
CREATE TRIGGER profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION trigger_update_timestamp();
CREATE TRIGGER grading_policies_updated_at BEFORE UPDATE ON grading_policies FOR EACH ROW EXECUTE FUNCTION trigger_update_timestamp();
CREATE TRIGGER user_settings_updated_at BEFORE UPDATE ON user_settings FOR EACH ROW EXECUTE FUNCTION trigger_update_timestamp();
CREATE TRIGGER school_partition_trigger AFTER INSERT ON schools FOR EACH ROW EXECUTE FUNCTION trigger_create_partitions();
