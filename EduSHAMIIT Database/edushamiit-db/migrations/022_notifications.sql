CREATE TABLE IF NOT EXISTS notifications (  
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),  
  school_id UUID REFERENCES schools(id),  
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,  
  title TEXT NOT NULL,  
  body TEXT NOT NULL,  
  type TEXT NOT NULL,  
  reference_id UUID,  
  reference_type TEXT,  
  is_read BOOLEAN DEFAULT FALSE,  
  priority TEXT DEFAULT 'normal',  
  created_at TIMESTAMPTZ DEFAULT NOW()  
); 
