-- Migration 114: Library System Enhancements

-- 1. Create library_requests table
CREATE TABLE IF NOT EXISTS library_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id) ON DELETE CASCADE,
  student_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  author TEXT NOT NULL,
  isbn TEXT,
  reason TEXT,
  status TEXT DEFAULT 'pending', -- pending, approved, rejected
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on library_requests
ALTER TABLE library_requests ENABLE ROW LEVEL SECURITY;

-- 2. Add school isolation policy for library_requests
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'library_requests' AND policyname = 'school_isolation_library_requests'
  ) THEN
    CREATE POLICY "school_isolation_library_requests" ON library_requests 
      USING (school_id = get_user_school_id());
  END IF;
END
$$;

-- 3. Add own library_requests access policy for students
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'library_requests' AND policyname = 'own_library_requests'
  ) THEN
    CREATE POLICY "own_library_requests" ON library_requests FOR SELECT 
      USING (auth.uid() = student_id);
  END IF;
END
$$;

-- 4. Add insert policy for library_requests for students
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'library_requests' AND policyname = 'insert_library_requests'
  ) THEN
    CREATE POLICY "insert_library_requests" ON library_requests FOR INSERT 
      WITH CHECK (auth.uid() = student_id);
  END IF;
END
$$;

-- 5. RLS policies for library_borrows
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'library_borrows' AND policyname = 'own_library_borrows'
  ) THEN
    CREATE POLICY "own_library_borrows" ON library_borrows FOR SELECT 
      USING (auth.uid() = student_id);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'library_borrows' AND policyname = 'request_library_borrow'
  ) THEN
    CREATE POLICY "request_library_borrow" ON library_borrows FOR INSERT 
      WITH CHECK (auth.uid() = student_id);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'library_borrows' AND policyname = 'update_own_library_borrow'
  ) THEN
    CREATE POLICY "update_own_library_borrow" ON library_borrows FOR UPDATE 
      USING (auth.uid() = student_id);
  END IF;
END
$$;
