CREATE TABLE IF NOT EXISTS library_books (  
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),  
  school_id UUID REFERENCES schools(id),  
  title TEXT NOT NULL,  
  author TEXT,  
  isbn TEXT,  
  category TEXT,  
  shelf_location TEXT,  
  total_copies INT DEFAULT 1,  
  available_copies INT DEFAULT 1,  
  cover_url TEXT,  
  is_digital BOOLEAN DEFAULT FALSE,  
  digital_url TEXT,  
  created_at TIMESTAMPTZ DEFAULT NOW()  
); 
