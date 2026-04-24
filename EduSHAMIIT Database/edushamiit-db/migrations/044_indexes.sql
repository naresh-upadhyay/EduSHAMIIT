-- Schools indexes  
CREATE INDEX IF NOT EXISTS idx_schools_name ON schools(name);  
  
-- Profiles indexes  
CREATE INDEX IF NOT EXISTS idx_profiles_school ON profiles(school_id);  
CREATE INDEX IF NOT EXISTS idx_profiles_class ON profiles(school_id, class);  
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(school_id, role);  
CREATE INDEX IF NOT EXISTS idx_profiles_xp ON profiles(school_id, xp_points DESC); 
  
-- Subjects indexes  
CREATE INDEX IF NOT EXISTS idx_subjects_school ON subjects(school_id);  
CREATE INDEX IF NOT EXISTS idx_subjects_teacher ON subjects(teacher_id);  
CREATE INDEX IF NOT EXISTS idx_subjects_class ON subjects(school_id, class);  
  
-- Timetable indexes  
CREATE INDEX IF NOT EXISTS idx_timetable_school_class ON timetable(school_id, class);  
CREATE INDEX IF NOT EXISTS idx_timetable_teacher ON timetable(teacher_id);  
CREATE INDEX IF NOT EXISTS idx_timetable_day ON timetable(school_id, day_of_week); 
  
-- Courses indexes  
CREATE INDEX IF NOT EXISTS idx_courses_school ON courses(school_id);  
  
-- Results indexes  
CREATE INDEX IF NOT EXISTS idx_results_student ON results(student_id);  
CREATE INDEX IF NOT EXISTS idx_results_school ON results(school_id);  
CREATE INDEX IF NOT EXISTS idx_results_subject ON results(subject_id);  
  
-- Exams indexes  
CREATE INDEX IF NOT EXISTS idx_exams_school ON exams(school_id);  
CREATE INDEX IF NOT EXISTS idx_exams_status ON exams(school_id, status);  
  
-- Exam questions indexes  
CREATE INDEX IF NOT EXISTS idx_exam_questions_exam ON exam_questions(exam_id);  
  
-- Exam submissions indexes  
CREATE INDEX IF NOT EXISTS idx_exam_submissions_exam ON exam_submissions(exam_id);  
CREATE INDEX IF NOT EXISTS idx_exam_submissions_student ON exam_submissions(student_id);  
  
-- Exam sessions indexes  
CREATE INDEX IF NOT EXISTS idx_exam_sessions_exam ON exam_sessions(exam_id);  
CREATE INDEX IF NOT EXISTS idx_exam_sessions_student ON exam_sessions(student_id);  
  
-- Attendance indexes  
CREATE INDEX IF NOT EXISTS idx_attendance_student ON attendance(student_id);  
CREATE INDEX IF NOT EXISTS idx_attendance_school ON attendance(school_id);  
CREATE INDEX IF NOT EXISTS idx_attendance_date ON attendance(school_id, date);  
CREATE INDEX IF NOT EXISTS idx_attendance_student_date ON attendance(student_id, date); 
  
-- Fees indexes  
CREATE INDEX IF NOT EXISTS idx_fees_student ON fees(student_id);  
CREATE INDEX IF NOT EXISTS idx_fees_school ON fees(school_id);  
CREATE INDEX IF NOT EXISTS idx_fees_status ON fees(school_id, status);  
CREATE INDEX IF NOT EXISTS idx_fees_due ON fees(school_id, due_date);  
  
-- Payments indexes  
CREATE INDEX IF NOT EXISTS idx_payments_student ON payments(student_id);  
CREATE INDEX IF NOT EXISTS idx_payments_fee ON payments(fee_id);  
-- idx_payments_status removed as payments lacks school_id in early migrations
  
-- Salary indexes  
CREATE INDEX IF NOT EXISTS idx_salary_teacher ON salary(teacher_id);  
CREATE INDEX IF NOT EXISTS idx_salary_school ON salary(school_id);  
CREATE INDEX IF NOT EXISTS idx_salary_month ON salary(school_id, month);  
  
-- Homework indexes  
CREATE INDEX IF NOT EXISTS idx_homework_school ON homework(school_id);  
CREATE INDEX IF NOT EXISTS idx_homework_teacher ON homework(teacher_id);  
CREATE INDEX IF NOT EXISTS idx_homework_class ON homework(school_id, class);  
CREATE INDEX IF NOT EXISTS idx_homework_due ON homework(school_id, due_date); 
  
-- Homework submissions indexes  
CREATE INDEX IF NOT EXISTS idx_homework_sub_hw ON homework_submissions(homework_id);  
CREATE INDEX IF NOT EXISTS idx_homework_sub_student ON homework_submissions(student_id);  
CREATE INDEX IF NOT EXISTS idx_homework_sub_status ON homework_submissions(school_id, status); 
  
-- Notices indexes  
CREATE INDEX IF NOT EXISTS idx_notices_school ON notices(school_id);  
CREATE INDEX IF NOT EXISTS idx_notices_category ON notices(school_id, category);  
CREATE INDEX IF NOT EXISTS idx_notices_status ON notices(school_id, status);  
CREATE INDEX IF NOT EXISTS idx_notices_published ON notices(school_id, published_at DESC);  
  
-- Events indexes  
CREATE INDEX IF NOT EXISTS idx_events_school ON events(school_id);  
  
-- Event registrations indexes  
CREATE INDEX IF NOT EXISTS idx_event_reg_event ON event_registrations(event_id);  
CREATE INDEX IF NOT EXISTS idx_event_reg_student ON event_registrations(student_id); 
  
-- Messages indexes  
CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_id);  
CREATE INDEX IF NOT EXISTS idx_messages_receiver ON messages(receiver_id);  
CREATE INDEX IF NOT EXISTS idx_messages_school ON messages(school_id);  
CREATE INDEX IF NOT EXISTS idx_messages_created ON messages(school_id, created_at DESC);  
  
-- Notifications indexes  
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);  
CREATE INDEX IF NOT EXISTS idx_notifications_school ON notifications(school_id);  
CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(school_id, is_read);  
CREATE INDEX IF NOT EXISTS idx_notifications_created ON notifications(school_id, created_at DESC); 
  
-- Leave applications indexes  
CREATE INDEX IF NOT EXISTS idx_leave_applicant ON leave_applications(applicant_id);  
CREATE INDEX IF NOT EXISTS idx_leave_school ON leave_applications(school_id);  
CREATE INDEX IF NOT EXISTS idx_leave_status ON leave_applications(school_id, status);  
  
-- Achievements indexes  
CREATE INDEX IF NOT EXISTS idx_achievements_school ON achievements(school_id); 
  
-- Student achievements indexes  
CREATE INDEX IF NOT EXISTS idx_student_ach_student ON student_achievements(student_id);  
  
-- Library books indexes  
CREATE INDEX IF NOT EXISTS idx_library_books_school ON library_books(school_id);  
CREATE INDEX IF NOT EXISTS idx_library_books_title ON library_books(school_id, title); 
  
-- Library borrows indexes  
CREATE INDEX IF NOT EXISTS idx_library_borrows_student ON library_borrows(student_id);  
CREATE INDEX IF NOT EXISTS idx_library_borrows_school ON library_borrows(school_id);  
CREATE INDEX IF NOT EXISTS idx_library_borrows_status ON library_borrows(school_id, status); 
  
-- Bus routes indexes  
CREATE INDEX IF NOT EXISTS idx_bus_routes_school ON bus_routes(school_id);  
  
-- Bus stops indexes  
CREATE INDEX IF NOT EXISTS idx_bus_stops_route ON bus_stops(route_id);  
  
-- Bus locations indexes  
CREATE INDEX IF NOT EXISTS idx_bus_locations_route ON bus_locations(route_id);  
CREATE INDEX IF NOT EXISTS idx_bus_locations_time ON bus_locations(school_id, recorded_at DESC); 
  
-- Live classes indexes  
CREATE INDEX IF NOT EXISTS idx_live_classes_school ON live_classes(school_id);  
CREATE INDEX IF NOT EXISTS idx_live_classes_teacher ON live_classes(teacher_id);  
CREATE INDEX IF NOT EXISTS idx_live_classes_status ON live_classes(school_id, status);  
  
-- Live class comments indexes  
CREATE INDEX IF NOT EXISTS idx_live_comments_class ON live_class_comments(live_class_id);  
  
-- Study materials indexes  
CREATE INDEX IF NOT EXISTS idx_materials_school ON study_materials(school_id);  
CREATE INDEX IF NOT EXISTS idx_materials_teacher ON study_materials(teacher_id);  
CREATE INDEX IF NOT EXISTS idx_materials_class ON study_materials(school_id, target_class);  
  
-- User settings indexes  
-- CREATE INDEX IF NOT EXISTS idx_user_settings_school ON user_settings(school_id);  
  
-- Documents indexes  
CREATE INDEX IF NOT EXISTS idx_documents_user ON documents(user_id);  
  
-- Grading policies indexes  
CREATE INDEX IF NOT EXISTS idx_grading_teacher ON grading_policies(teacher_id);  
CREATE INDEX IF NOT EXISTS idx_grading_school ON grading_policies(school_id);  
  
-- AI chat history indexes  
CREATE INDEX IF NOT EXISTS idx_ai_chat_user ON ai_chat_history(user_id);  
CREATE INDEX IF NOT EXISTS idx_ai_chat_school ON ai_chat_history(school_id);  
CREATE INDEX IF NOT EXISTS idx_ai_chat_created ON ai_chat_history(school_id, created_at DESC); 
  
-- Student transport indexes  
CREATE INDEX IF NOT EXISTS idx_student_transport_student ON student_transport(student_id);  
CREATE INDEX IF NOT EXISTS idx_student_transport_route ON student_transport(route_id);  
  
-- Knowledge base indexes (vector index)  
-- CREATE INDEX IF NOT EXISTS idx_kb_school ON knowledge_base(school_id);  
CREATE INDEX IF NOT EXISTS idx_kb_subject ON knowledge_base(subject);  
CREATE INDEX IF NOT EXISTS idx_kb_grade ON knowledge_base(grade);  
  
-- IoT indexes  
CREATE INDEX IF NOT EXISTS idx_iot_devices_school ON iot_devices(school_id);  
CREATE INDEX IF NOT EXISTS idx_iot_log_school ON iot_control_log(school_id);  
CREATE INDEX IF NOT EXISTS idx_iot_scheduled_school ON iot_scheduled_actions(school_id); 
