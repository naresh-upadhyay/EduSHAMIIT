CREATE TABLE IF NOT EXISTS messages (  
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),  
  school_id UUID REFERENCES schools(id),  
  sender_id UUID REFERENCES profiles(id) ON DELETE CASCADE,  
  receiver_id UUID REFERENCES profiles(id),  
  group_id UUID,  
  content TEXT NOT NULL,  
  attachment_url TEXT,  
  is_read BOOLEAN DEFAULT FALSE,  
  read_at TIMESTAMPTZ,  
  created_at TIMESTAMPTZ DEFAULT NOW()  
); 
