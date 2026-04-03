CREATE TABLE IF NOT EXISTS achievements (  
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),  
  school_id UUID REFERENCES schools(id),  
  name TEXT NOT NULL,  
  description TEXT,  
  icon TEXT,  
  badge_color JSONB,  
  xp_reward INT DEFAULT 0,  
  criteria TEXT,  
  rarity TEXT DEFAULT 'common',  
  created_at TIMESTAMPTZ DEFAULT NOW()  
); 
