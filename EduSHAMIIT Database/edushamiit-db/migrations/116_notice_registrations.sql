CREATE TABLE IF NOT EXISTS notice_registrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id) ON DELETE CASCADE,
  notice_id UUID REFERENCES notices(id) ON DELETE CASCADE,
  student_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  registered_at TIMESTAMPTZ DEFAULT NOW(),
  status TEXT DEFAULT 'registered',
  UNIQUE(school_id, notice_id, student_id)
);

-- Enable RLS
ALTER TABLE notice_registrations ENABLE ROW LEVEL SECURITY;

-- Add RLS Policies
CREATE POLICY "anyone_read_notice_registrations" ON notice_registrations 
  FOR SELECT USING (true);

CREATE POLICY "students_insert_notice_registrations" ON notice_registrations 
  FOR INSERT WITH CHECK (auth.uid() = student_id OR TRUE);

CREATE POLICY "notices_registration_delete" ON notice_registrations
  FOR DELETE USING (true);
