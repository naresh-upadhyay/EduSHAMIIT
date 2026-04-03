CREATE TABLE IF NOT EXISTS library_borrows (  
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),  
  school_id UUID REFERENCES schools(id),  
  book_id UUID REFERENCES library_books(id) ON DELETE CASCADE,  
  student_id UUID REFERENCES profiles(id) ON DELETE CASCADE,  
  borrowed_at TIMESTAMPTZ DEFAULT NOW(),  
  due_at TIMESTAMPTZ NOT NULL,  
  returned_at TIMESTAMPTZ,  
  renewals_used INT DEFAULT 0,  
  max_renewals INT DEFAULT 2,  
  status TEXT DEFAULT 'borrowed',  
  fine_amount DECIMAL(10,2) DEFAULT 0  
); 
