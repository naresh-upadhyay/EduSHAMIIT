-- Migration: 212_fk_cascade_fixes_and_fts_indexes.sql
-- Description: Fix remaining foreign key deletion behaviors and add GIN Full-Text Search (FTS) indexes for instant global searching.

-- ──────────────────────────────────────────────
-- 1. FOREIGN KEY DELETION CASCADE FIXES
-- ──────────────────────────────────────────────

-- Ensure driver_assignments.route_id has ON DELETE SET NULL
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'driver_assignments') THEN
    ALTER TABLE public.driver_assignments 
      DROP CONSTRAINT IF EXISTS driver_assignments_route_id_fkey;
    
    ALTER TABLE public.driver_assignments 
      ADD CONSTRAINT driver_assignments_route_id_fkey 
      FOREIGN KEY (route_id) REFERENCES public.transport_routes(id) ON DELETE SET NULL;
  END IF;
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;


-- ──────────────────────────────────────────────
-- 2. GIN FULL-TEXT SEARCH (FTS) INDEXES FOR SEARCH ENDPOINTS
-- ──────────────────────────────────────────────

-- Fast GIN index for Profile search (Name, Email, Role, Student ID)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'profiles') THEN
    CREATE INDEX IF NOT EXISTS idx_fts_profiles_search 
    ON public.profiles 
    USING gin(to_tsvector('english', COALESCE(full_name, '') || ' ' || COALESCE(email, '') || ' ' || COALESCE(role, '')));
  END IF;

  -- Fast GIN index for Library Books search (Title, Author, ISBN)
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'library_books') THEN
    CREATE INDEX IF NOT EXISTS idx_fts_library_books_search 
    ON public.library_books 
    USING gin(to_tsvector('english', COALESCE(title, '') || ' ' || COALESCE(author, '') || ' ' || COALESCE(isbn, '')));
  END IF;

  -- Fast GIN index for Knowledge Base search (Subject, Grade, Source, Content)
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'knowledge_base') THEN
    CREATE INDEX IF NOT EXISTS idx_fts_knowledge_base_search 
    ON public.knowledge_base 
    USING gin(to_tsvector('english', COALESCE(subject, '') || ' ' || COALESCE(grade, '') || ' ' || COALESCE(source, '') || ' ' || COALESCE(content, '')));
  END IF;

  -- Fast GIN index for Notices search (Title, Content)
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notices') THEN
    CREATE INDEX IF NOT EXISTS idx_fts_notices_search 
    ON public.notices 
    USING gin(to_tsvector('english', COALESCE(title, '') || ' ' || COALESCE(content, '')));
  END IF;

  -- Fast GIN index for Courses search (Title, Description)
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'courses') THEN
    CREATE INDEX IF NOT EXISTS idx_fts_courses_search 
    ON public.courses 
    USING gin(to_tsvector('english', COALESCE(title, '') || ' ' || COALESCE(description, '')));
  END IF;
END $$;
