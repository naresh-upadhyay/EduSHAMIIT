-- ============================================================================
-- Migration 526: Normalize Student Class Names and Ensure Distinct Roll Numbers
-- ============================================================================

-- 1. Normalize legacy hyphenated class labels in profiles to match actual curriculum classes (e.g., 'Class 10-A' -> '10A')
UPDATE public.profiles
SET class = '10A'
WHERE class IN ('Class 10-A', 'Class 10 - A');

UPDATE public.profiles
SET class = '10B'
WHERE class IN ('Class 10-B', 'Class 10 - B');

UPDATE public.profiles
SET class = '11A'
WHERE class IN ('Class 11-A', 'Class 11 - A');

UPDATE public.profiles
SET class = '12C'
WHERE class IN ('Class 12-C', 'Class 12 - C');

-- 2. Assign unique sequential roll numbers for students with NULL roll numbers to prevent collisions
WITH numbered_students AS (
    SELECT id, school_id, class,
           ROW_NUMBER() OVER (PARTITION BY school_id, class ORDER BY full_name, email) + 1000 AS new_roll
    FROM public.profiles
    WHERE role = 'student' AND (roll_number IS NULL OR roll_number = 0)
)
UPDATE public.profiles p
SET roll_number = ns.new_roll
FROM numbered_students ns
WHERE p.id = ns.id;

-- 3. Update existing audit log descriptions that have corrupt UTF-8 currency symbols
UPDATE public.student_fee_audit_logs
SET description = REPLACE(description, 'â‚¹', '₹')
WHERE description LIKE '%â‚¹%';
