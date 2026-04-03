-- Helper function: Get current user's school_id  
CREATE OR REPLACE FUNCTION get_user_school_id() RETURNS UUID AS $$  
  SELECT school_id FROM profiles WHERE id = auth.uid();  
$$ LANGUAGE SQL STABLE; 
  
-- School isolation policies  
CREATE POLICY "school_isolation_profiles" ON profiles USING (school_id = get_user_school_id());  
CREATE POLICY "school_isolation_results" ON results USING (school_id = get_user_school_id());  
CREATE POLICY "school_isolation_attendance" ON attendance USING (school_id = get_user_school_id());  
CREATE POLICY "school_isolation_fees" ON fees USING (school_id = get_user_school_id());  
CREATE POLICY "school_isolation_homework" ON homework USING (school_id = get_user_school_id());  
CREATE POLICY "school_isolation_messages" ON messages USING (school_id = get_user_school_id());  
CREATE POLICY "school_isolation_notifications" ON notifications USING (school_id = get_user_school_id());  
CREATE POLICY "school_isolation_ai_chat" ON ai_chat_history USING (school_id = get_user_school_id()); 
  
-- Own profile access policies  
CREATE POLICY "own_profile_view" ON profiles FOR SELECT USING (auth.uid() = id);  
CREATE POLICY "own_profile_update" ON profiles FOR UPDATE USING (auth.uid() = id); 
  
-- Student own data access  
CREATE POLICY "own_results" ON results FOR SELECT USING (auth.uid() = student_id);  
CREATE POLICY "own_attendance" ON attendance FOR SELECT USING (auth.uid() = student_id);  
CREATE POLICY "own_fees" ON fees FOR SELECT USING (auth.uid() = student_id);  
CREATE POLICY "own_salary" ON salary FOR SELECT USING (auth.uid() = teacher_id);  
CREATE POLICY "own_leave" ON leave_applications FOR SELECT USING (auth.uid() = applicant_id);  
CREATE POLICY "own_notifications" ON notifications FOR SELECT USING (auth.uid() = user_id);  
CREATE POLICY "own_ai_chats" ON ai_chat_history FOR SELECT USING (auth.uid() = user_id); 
  
-- Student submit data  
CREATE POLICY "submit_homework" ON homework_submissions FOR INSERT WITH CHECK (auth.uid() = student_id);  
CREATE POLICY "view_own_submissions" ON homework_submissions FOR SELECT USING (auth.uid() = student_id); 
  
-- Teacher policies  
CREATE POLICY "teachers_view_results" ON results FOR SELECT USING (true);  
CREATE POLICY "teachers_insert_results" ON results FOR INSERT WITH CHECK (true);  
CREATE POLICY "teachers_update_results" ON results FOR UPDATE USING (true);  
CREATE POLICY "teachers_view_attendance" ON attendance FOR SELECT USING (true);  
CREATE POLICY "teachers_insert_attendance" ON attendance FOR INSERT WITH CHECK (true);  
CREATE POLICY "teachers_view_submissions" ON homework_submissions FOR SELECT USING (true);  
CREATE POLICY "teachers_grade_submissions" ON homework_submissions FOR UPDATE USING (true);  
CREATE POLICY "teachers_view_exam_submissions" ON exam_submissions FOR SELECT USING (true);  
CREATE POLICY "teachers_grade_exams" ON exam_submissions FOR UPDATE USING (true);  
CREATE POLICY "teachers_approve_leaves" ON leave_applications FOR UPDATE USING (true); 
  
-- Message policies  
CREATE POLICY "send_messages" ON messages FOR INSERT WITH CHECK (auth.uid() = sender_id);  
CREATE POLICY "view_own_messages" ON messages FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id); 
  
-- Leave policies  
CREATE POLICY "apply_leave" ON leave_applications FOR INSERT WITH CHECK (auth.uid() = applicant_id);  
  
-- Grading policy  
CREATE POLICY "manage_grading" ON grading_policies FOR ALL USING (auth.uid() = teacher_id);  
  
-- Materials  
CREATE POLICY "manage_materials" ON study_materials FOR ALL USING (auth.uid() = teacher_id); 
  
-- Public read policies  
CREATE POLICY "anyone_read_subjects" ON subjects FOR SELECT USING (true);  
CREATE POLICY "anyone_read_timetable" ON timetable FOR SELECT USING (true);  
CREATE POLICY "anyone_read_notices" ON notices FOR SELECT USING (true);  
CREATE POLICY "anyone_read_events" ON events FOR SELECT USING (true);  
CREATE POLICY "anyone_read_homework" ON homework FOR SELECT USING (true);  
CREATE POLICY "anyone_read_exams" ON exams FOR SELECT USING (true);  
CREATE POLICY "anyone_read_achievements" ON achievements FOR SELECT USING (true);  
CREATE POLICY "anyone_read_library" ON library_books FOR SELECT USING (true);  
CREATE POLICY "anyone_read_bus_routes" ON bus_routes FOR SELECT USING (true);  
CREATE POLICY "anyone_read_bus_stops" ON bus_stops FOR SELECT USING (true);  
CREATE POLICY "anyone_read_live_classes" ON live_classes FOR SELECT USING (true);  
CREATE POLICY "anyone_read_materials" ON study_materials FOR SELECT USING (true);  
CREATE POLICY "anyone_read_courses" ON courses FOR SELECT USING (true); 
