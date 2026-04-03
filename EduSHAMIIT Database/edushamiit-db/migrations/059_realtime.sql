CREATE OR REPLACE FUNCTION notify_table_change() RETURNS TRIGGER AS $$ BEGIN PERFORM pg_notify('table_change', json_build_object('table', TG_TABLE_NAME, 'operation', TG_OP, 'record_id', COALESCE(NEW.id, OLD.id), 'school_id', COALESCE(NEW.school_id, OLD.school_id))::text); RETURN NEW; END; $$ LANGUAGE plpgsql;
CREATE TRIGGER realtime_bus_locations AFTER INSERT OR UPDATE ON bus_locations FOR EACH ROW EXECUTE FUNCTION notify_table_change();
CREATE TRIGGER realtime_messages AFTER INSERT ON messages FOR EACH ROW EXECUTE FUNCTION notify_table_change();
CREATE TRIGGER realtime_notifications AFTER INSERT ON notifications FOR EACH ROW EXECUTE FUNCTION notify_table_change();
CREATE TRIGGER realtime_exam_sessions AFTER UPDATE ON exam_sessions FOR EACH ROW EXECUTE FUNCTION notify_table_change();
