SET ROLE supabase_admin;

-- Drop old insecure policies
DROP POLICY IF EXISTS "teachers_view_results" ON results;
DROP POLICY IF EXISTS "teachers_insert_results" ON results;
DROP POLICY IF EXISTS "teachers_update_results" ON results;
DROP POLICY IF EXISTS "teachers_view_attendance" ON attendance;
DROP POLICY IF EXISTS "teachers_insert_attendance" ON attendance;
DROP POLICY IF EXISTS "teachers_view_submissions" ON homework_submissions;
DROP POLICY IF EXISTS "teachers_grade_submissions" ON homework_submissions;
DROP POLICY IF EXISTS "teachers_view_exam_submissions" ON exam_submissions;
DROP POLICY IF EXISTS "teachers_grade_exams" ON exam_submissions;
DROP POLICY IF EXISTS "teachers_approve_leaves" ON leave_applications;
DROP POLICY IF EXISTS "manage_grading" ON grading_policies;

-- Recreate with role verification checks (only staff roles allowed: 'teacher', 'admin', 'student_admin', 'teacher_admin')
CREATE POLICY "teachers_view_results" ON results FOR SELECT 
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('teacher', 'admin', 'student_admin', 'teacher_admin')));

CREATE POLICY "teachers_insert_results" ON results FOR INSERT 
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('teacher', 'admin', 'student_admin', 'teacher_admin')));

CREATE POLICY "teachers_update_results" ON results FOR UPDATE 
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('teacher', 'admin', 'student_admin', 'teacher_admin')));

CREATE POLICY "teachers_view_attendance" ON attendance FOR SELECT 
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('teacher', 'admin', 'student_admin', 'teacher_admin')));

CREATE POLICY "teachers_insert_attendance" ON attendance FOR INSERT 
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('teacher', 'admin', 'student_admin', 'teacher_admin')));

CREATE POLICY "teachers_view_submissions" ON homework_submissions FOR SELECT 
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('teacher', 'admin', 'student_admin', 'teacher_admin')));

CREATE POLICY "teachers_grade_submissions" ON homework_submissions FOR UPDATE 
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('teacher', 'admin', 'student_admin', 'teacher_admin')));

CREATE POLICY "teachers_view_exam_submissions" ON exam_submissions FOR SELECT 
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('teacher', 'admin', 'student_admin', 'teacher_admin')));

CREATE POLICY "teachers_grade_exams" ON exam_submissions FOR UPDATE 
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('teacher', 'admin', 'student_admin', 'teacher_admin')));

CREATE POLICY "teachers_approve_leaves" ON leave_applications FOR UPDATE 
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('teacher', 'admin', 'student_admin', 'teacher_admin')));

CREATE POLICY "manage_grading" ON grading_policies FOR ALL 
  USING (auth.uid() = teacher_id AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('teacher', 'admin', 'teacher_admin')));

RESET ROLE;
