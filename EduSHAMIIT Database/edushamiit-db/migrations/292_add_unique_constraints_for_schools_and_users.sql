-- ============================================================================
-- Migration: 292_add_unique_constraints_for_schools_and_users.sql
-- Description: Enforces uniqueness for school names and user emails in PostgreSQL
--              to prevent duplicate records across the entire system.
-- ============================================================================

-- 1. Unique index on school names (case-insensitive)
CREATE UNIQUE INDEX IF NOT EXISTS uq_schools_lower_name 
ON public.schools (LOWER(TRIM(name)));

-- 2. Unique index on profile emails (case-insensitive)
CREATE UNIQUE INDEX IF NOT EXISTS uq_profiles_lower_email 
ON public.profiles (LOWER(TRIM(email)));

-- 3. Unique index on custom user_id
CREATE UNIQUE INDEX IF NOT EXISTS uq_profiles_user_id 
ON public.profiles (user_id) 
WHERE user_id IS NOT NULL;
