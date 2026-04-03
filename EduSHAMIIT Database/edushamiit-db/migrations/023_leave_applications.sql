CREATE TABLE IF NOT EXISTS leave_applications (  
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),  
  school_id UUID REFERENCES schools(id),  
  applicant_id UUID REFERENCES profiles(id) ON DELETE CASCADE,  
  applicant_role TEXT CHECK (applicant_role IN ('student','teacher')),  
  leave_type TEXT NOT NULL,  
  start_date DATE NOT NULL,  
  end_date DATE NOT NULL,  
  reason TEXT NOT NULL,  
  attachment_url TEXT,  
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','cancelled')),  
  approved_by UUID REFERENCES profiles(id),  
  approved_at TIMESTAMPTZ,  
  remarks TEXT,  
  created_at TIMESTAMPTZ DEFAULT NOW(),  
  updated_at TIMESTAMPTZ DEFAULT NOW()  
); 
