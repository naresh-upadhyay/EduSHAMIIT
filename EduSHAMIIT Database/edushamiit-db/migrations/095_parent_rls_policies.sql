-- ============================================================
-- Migration 095: RLS Policies for Parent Role
-- Allows parents to read data for their linked (approved) children
-- ============================================================

-- Helper function: Check if a parent has access to a student
CREATE OR REPLACE FUNCTION parent_has_access(p_parent_id UUID, p_student_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM parent_student_relations
    WHERE parent_id = p_parent_id
      AND student_id = p_student_id
      AND approved = TRUE
  );
$$ LANGUAGE SQL STABLE;

-- Parent can view own relations
CREATE POLICY "parent_view_own_relations" ON parent_student_relations
  FOR SELECT USING (auth.uid() = parent_id);

-- Parent can view their children's relations
CREATE POLICY "parent_view_child_relations" ON parent_student_relations
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM parent_student_relations psr
      WHERE psr.parent_id = auth.uid()
        AND psr.student_id = parent_student_relations.student_id
        AND psr.approved = TRUE
    )
  );

-- School admin can manage relations
CREATE POLICY "admin_manage_relations" ON parent_student_relations
  FOR ALL USING (true);

-- Parent can read attendance for their approved children
CREATE POLICY "parent_read_attendance" ON attendance
  FOR SELECT USING (
    parent_has_access(auth.uid(), student_id)
  );

-- Parent can read results for their approved children
CREATE POLICY "parent_read_results" ON results
  FOR SELECT USING (
    parent_has_access(auth.uid(), student_id)
  );

-- Parent can read fees for their approved children
CREATE POLICY "parent_read_fees" ON fees
  FOR SELECT USING (
    parent_has_access(auth.uid(), student_id)
  );

-- Parent can read payments for their approved children
CREATE POLICY "parent_read_payments" ON payments
  FOR SELECT USING (
    parent_has_access(auth.uid(), student_id)
  );

-- Parent can read homework submissions for their approved children
CREATE POLICY "parent_read_submissions" ON homework_submissions
  FOR SELECT USING (
    parent_has_access(auth.uid(), student_id)
  );

-- Parent can read leave applications for their approved children
CREATE POLICY "parent_read_child_leave" ON leave_applications
  FOR SELECT USING (
    parent_has_access(auth.uid(), applicant_id)
  );

-- Parent can apply leave for their approved children
CREATE POLICY "parent_apply_child_leave" ON leave_applications
  FOR INSERT WITH CHECK (
    parent_has_access(auth.uid(), applicant_id)
  );

-- Parent can read student achievements for their approved children
CREATE POLICY "parent_read_achievements" ON student_achievements
  FOR SELECT USING (
    parent_has_access(auth.uid(), student_id)
  );

-- Parent can read student transport for their approved children
CREATE POLICY "parent_read_transport" ON student_transport
  FOR SELECT USING (
    parent_has_access(auth.uid(), student_id)
  );

-- Parent can read their children's profiles
CREATE POLICY "parent_read_child_profile" ON profiles
  FOR SELECT USING (
    role = 'student' AND parent_has_access(auth.uid(), id)
  );
