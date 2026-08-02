-- Migration: 212_fk_cascade_fixes_and_fts_indexes.sql
-- Description: Fix remaining foreign key deletion behaviors and add GIN Full-Text Search (FTS) indexes for instant global searching.

-- ──────────────────────────────────────────────
-- 1. FOREIGN KEY DELETION CASCADE FIXES
-- ──────────────────────────────────────────────

-- Ensure driver_assignments.route_id has ON DELETE SET NULL
DO $$
BEGIN
  ALTER TABLE public.driver_assignments 
    DROP CONSTRAINT IF EXISTS driver_assignments_route_id_fkey;
  
  ALTER TABLE public.driver_assignments 
    ADD CONSTRAINT driver_assignments_route_id_fkey 
    FOREIGN KEY (route_id) REFERENCES public.transport_routes(id) ON DELETE SET NULL;
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;


-- ──────────────────────────────────────────────
-- 2. GIN FULL-TEXT SEARCH (FTS) INDEXES FOR SEARCH ENDPOINTS
-- ──────────────────────────────────────────────

-- Fast GIN index for Profile search (Name, Email, Role, Student ID)
CREATE INDEX IF NOT EXISTS idx_fts_profiles_search 
ON public.profiles 
USING gin(to_tsvector('english', COALESCE(full_name, '') || ' ' || COALESCE(email, '') || ' ' || COALESCE(role, '')));

-- Fast GIN index for Library Books search (Title, Author, ISBN)
CREATE INDEX IF NOT EXISTS idx_fts_library_books_search 
ON public.library_books 
USING gin(to_tsvector('english', COALESCE(title, '') || ' ' || COALESCE(author, '') || ' ' || COALESCE(isbn, '')));

-- Fast GIN index for Knowledge Base search (Title, Category, Content)
CREATE INDEX IF NOT EXISTS idx_fts_knowledge_base_search 
ON public.knowledge_base 
USING gin(to_tsvector('english', COALESCE(title, '') || ' ' || COALESCE(category, '') || ' ' || COALESCE(content, '')));

-- Fast GIN index for Notices search (Title, Message)
CREATE INDEX IF NOT EXISTS idx_fts_notices_search 
ON public.notices 
USING gin(to_tsvector('english', COALESCE(title, '') || ' ' || COALESCE(message, '')));

-- Fast GIN index for Courses search (Title, Description)
CREATE INDEX IF NOT EXISTS idx_fts_courses_search 
ON public.courses 
USING gin(to_tsvector('english', COALESCE(title, '') || ' ' || COALESCE(description, '')));
