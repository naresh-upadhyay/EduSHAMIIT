CREATE TABLE IF NOT EXISTS student_achievements (  
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),  
  school_id UUID REFERENCES schools(id),  
  student_id UUID REFERENCES profiles(id) ON DELETE CASCADE,  
  achievement_id UUID REFERENCES achievements(id) ON DELETE CASCADE,  
  earned_at TIMESTAMPTZ DEFAULT NOW(),  
  progress DECIMAL(5,2) DEFAULT 100,  
  UNIQUE(school_id, student_id, achievement_id)  
); 
