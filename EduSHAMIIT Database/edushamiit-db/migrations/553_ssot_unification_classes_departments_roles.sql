-- ============================================================================
-- Migration 553: Single Source of Truth (SSOT) Unification
-- Classes, Departments, Roles, and Legacy Cleanup
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. CONSOLIDATE & CLEAN UP ROLES IN public.app_roles & public.profiles
-- ----------------------------------------------------------------------------

-- Update existing profile using 'security_officer' to canonical 'security'
UPDATE public.profiles 
SET role = 'security', updated_at = NOW() 
WHERE role = 'security_officer';

-- Remove device permissions referencing redundant roles
DELETE FROM public.campus_device_role_permissions
WHERE role_id IN (
    SELECT id FROM public.app_roles 
    WHERE name IN ('subject_teacher', 'class_teacher', 'teacher_admin', 'student_self', 'student_admin', 'security_officer')
);

-- Remove device user access referencing redundant roles if any
DELETE FROM public.campus_device_user_access
WHERE role_id IN (
    SELECT id FROM public.app_roles 
    WHERE name IN ('subject_teacher', 'class_teacher', 'teacher_admin', 'student_self', 'student_admin', 'security_officer')
);

-- Delete redundant roles from app_roles
DELETE FROM public.app_roles 
WHERE name IN ('subject_teacher', 'class_teacher', 'teacher_admin', 'student_self', 'student_admin', 'security_officer');

-- Ensure all remaining app_roles have non-empty display names and descriptions
UPDATE public.app_roles
SET display_name = INITCAP(REPLACE(name, '_', ' '))
WHERE display_name IS NULL OR TRIM(display_name) = '';

-- Ensure foreign key constraint on profiles.role -> app_roles.name
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'profiles_role_fkey'
    ) THEN
        ALTER TABLE public.profiles
        ADD CONSTRAINT profiles_role_fkey
        FOREIGN KEY (role) REFERENCES public.app_roles(name) ON UPDATE CASCADE;
    END IF;
END $$;


-- ----------------------------------------------------------------------------
-- 2. SEED MISSING DEPARTMENT LOOKUPS & ENSURE UNIQUE CONSTRAINT
-- ----------------------------------------------------------------------------

-- Ensure DEPARTMENT lookup key exists for every school in schools table
INSERT INTO public.lookup_keys (id, school_id, key_name, key_code, key_type, icon, status, created_at, updated_at)
SELECT 
    gen_random_uuid(),
    s.id,
    'Department',
    'DEPARTMENT',
    'SYSTEM',
    'domain',
    'ACTIVE',
    NOW(),
    NOW()
FROM public.schools s
WHERE NOT EXISTS (
    SELECT 1 FROM public.lookup_keys k 
    WHERE k.school_id = s.id AND k.key_code = 'DEPARTMENT' AND k.deleted_at IS NULL
);

-- Populate all 20 canonical department values for every school lacking them
DO $$
DECLARE
    r RECORD;
    v_dept RECORD;
BEGIN
    FOR r IN (
        SELECT id AS key_id, school_id 
        FROM public.lookup_keys 
        WHERE key_code = 'DEPARTMENT' AND deleted_at IS NULL
    ) LOOP
        FOR v_dept IN (
            SELECT * FROM (VALUES
                ('Academic / Teaching', 'ACADEMIC', 1, 'Core academic and instructional faculty'),
                ('Administration', 'ADMINISTRATION', 2, 'Central institute operations and leadership'),
                ('Mathematics', 'MATHEMATICS', 3, 'Department of Mathematics and Quantitative Sciences'),
                ('Science', 'SCIENCE', 4, 'Department of Physical, Chemical, and Biological Sciences'),
                ('English / Languages', 'LANGUAGES', 5, 'Languages, Linguistics and Literature'),
                ('Social Studies & Humanities', 'SOCIAL_STUDIES', 6, 'History, Civics, Geography and Humanities'),
                ('Computer Science & IT', 'COMPUTER_SCIENCE', 7, 'Information Technology, Computer Science and AI labs'),
                ('Finance & Accounts', 'FINANCE', 8, 'Tuition fees, payroll, billing and accounts'),
                ('Human Resources', 'HR', 9, 'Staff onboarding, attendance, policies and appraisal'),
                ('Library & Information', 'LIBRARY', 10, 'Library services, cataloging and book loans'),
                ('Physical Education & Sports', 'SPORTS', 11, 'Athletics, sports programs and fitness facilities'),
                ('Arts & Performing Arts', 'ARTS', 12, 'Music, theater, fine arts and design'),
                ('Transport & Fleet', 'TRANSPORT', 13, 'School buses, routes, GPS tracking and drivers'),
                ('Hostel & Residential', 'HOSTEL', 14, 'Student dormitories, mess and residential services'),
                ('Security & Safety', 'SECURITY', 15, 'Campus security, CCTV surveillance and guard management'),
                ('Medical & Health Clinic', 'HEALTH_CLINIC', 16, 'First aid, student medical records and nurse office'),
                ('Maintenance & Facilities', 'MAINTENANCE', 17, 'Building upkeep, electrical, plumbing and HVAC'),
                ('Examination & Assessment', 'EXAMINATION', 18, 'Exams control, grading schedules and certifications'),
                ('Student Affairs & Admissions', 'STUDENT_AFFAIRS', 19, 'New admissions, student discipline and counselling'),
                ('General / Unassigned', 'GENERAL', 20, 'Unassigned department or general staff')
            ) AS t(name, code, sort_ord, descr)
        ) LOOP
            IF NOT EXISTS (
                SELECT 1 FROM public.lookup_values
                WHERE lookup_key_id = r.key_id
                  AND UPPER(TRIM(value_name)) = UPPER(TRIM(v_dept.name))
                  AND deleted_at IS NULL
            ) THEN
                INSERT INTO public.lookup_values (
                    id, lookup_key_id, school_id, value_name, value_code, 
                    description, status, sort_order, created_at, updated_at
                ) VALUES (
                    gen_random_uuid(), r.key_id, r.school_id, v_dept.name, v_dept.code,
                    v_dept.descr, 'ACTIVE', v_dept.sort_ord, NOW(), NOW()
                );
            END IF;
        END LOOP;
    END LOOP;
END $$;

-- Enforce unique index on lookup values per key and school
CREATE UNIQUE INDEX IF NOT EXISTS uq_lookup_values_dept_canonical 
ON public.lookup_values (lookup_key_id, school_id, UPPER(TRIM(value_name))) 
WHERE deleted_at IS NULL;

-- ----------------------------------------------------------------------------
-- 3. STORED PROCEDURE: fn_get_standard_departments
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_get_standard_departments(p_school_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_key_id UUID;
    v_departments JSONB;
BEGIN
    -- Locate department lookup key for the given school (or default school)
    SELECT id INTO v_key_id
    FROM public.lookup_keys
    WHERE (school_id = p_school_id OR p_school_id IS NULL)
      AND key_code = 'DEPARTMENT'
      AND deleted_at IS NULL
    LIMIT 1;

    IF v_key_id IS NOT NULL THEN
        SELECT COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', d.id,
                    'code', d.value_code,
                    'name', d.value_name,
                    'description', d.description,
                    'status', d.status,
                    'sort_order', d.sort_order
                ) ORDER BY d.sort_order ASC, d.value_name ASC
            ),
            '[]'::JSONB
        ) INTO v_departments
        FROM (
            SELECT DISTINCT ON (UPPER(TRIM(v.value_name)))
                v.id,
                v.value_code,
                v.value_name,
                v.description,
                v.status,
                v.sort_order
            FROM public.lookup_values v
            WHERE v.lookup_key_id = v_key_id
              AND v.deleted_at IS NULL
              AND v.status = 'ACTIVE'
            ORDER BY UPPER(TRIM(v.value_name)), v.sort_order ASC
        ) d;
    ELSE
        -- Fallback to standard canonical system departments
        v_departments := '[
            {"code": "ACADEMIC", "name": "Academic / Teaching", "sort_order": 1},
            {"code": "ADMINISTRATION", "name": "Administration", "sort_order": 2},
            {"code": "MATHEMATICS", "name": "Mathematics", "sort_order": 3},
            {"code": "SCIENCE", "name": "Science", "sort_order": 4},
            {"code": "LANGUAGES", "name": "English / Languages", "sort_order": 5},
            {"code": "SOCIAL_STUDIES", "name": "Social Studies & Humanities", "sort_order": 6},
            {"code": "COMPUTER_SCIENCE", "name": "Computer Science & IT", "sort_order": 7},
            {"code": "FINANCE", "name": "Finance & Accounts", "sort_order": 8},
            {"code": "HR", "name": "Human Resources", "sort_order": 9},
            {"code": "LIBRARY", "name": "Library & Information", "sort_order": 10},
            {"code": "SPORTS", "name": "Physical Education & Sports", "sort_order": 11},
            {"code": "ARTS", "name": "Arts & Performing Arts", "sort_order": 12},
            {"code": "TRANSPORT", "name": "Transport & Fleet", "sort_order": 13},
            {"code": "HOSTEL", "name": "Hostel & Residential", "sort_order": 14},
            {"code": "SECURITY", "name": "Security & Safety", "sort_order": 15},
            {"code": "HEALTH_CLINIC", "name": "Medical & Health Clinic", "sort_order": 16},
            {"code": "MAINTENANCE", "name": "Maintenance & Facilities", "sort_order": 17},
            {"code": "EXAMINATION", "name": "Examination & Assessment", "sort_order": 18},
            {"code": "STUDENT_AFFAIRS", "name": "Student Affairs & Admissions", "sort_order": 19},
            {"code": "GENERAL", "name": "General / Unassigned", "sort_order": 20}
        ]'::JSONB;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'school_id', p_school_id,
        'data', v_departments
    );
END;
$$;


-- ----------------------------------------------------------------------------
-- 4. CLEAN UP DIRTY DEPARTMENT VALUES IN public.profiles
-- ----------------------------------------------------------------------------
UPDATE public.profiles
SET department = CASE
    WHEN department IN ('IT', 'IT Team', 'Information Tech', 'Computer Apps', 'Computer Science', 'Faculty - ECE') THEN 'Computer Science & IT'
    WHEN department IN ('Teaching', 'Teachers', 'Academics') THEN 'Academic / Teaching'
    WHEN department = 'Teacher - Mathematics' THEN 'Mathematics'
    WHEN department IN ('Maintenance', 'Facility Team') THEN 'Maintenance & Facilities'
    WHEN department = 'Security Team' THEN 'Security & Safety'
    WHEN department = 'Management' THEN 'Administration'
    WHEN department = 'Institute Work Group' THEN 'General / Unassigned'
    ELSE department
END,
updated_at = NOW()
WHERE department IS NOT NULL;


-- ----------------------------------------------------------------------------
-- 5. STANDARDIZE CLASSES IN public.profiles TO MATCH academic_classes
-- ----------------------------------------------------------------------------
-- Ensure higher academic classes exist in academic_classes for each school
DO $$
DECLARE
    s RECORD;
    cls RECORD;
BEGIN
    FOR s IN SELECT id FROM public.schools LOOP
        FOR cls IN (
            SELECT * FROM (VALUES
                ('Class 1', 'CL-01', 'Primary', 1),
                ('Class 2', 'CL-02', 'Primary', 2),
                ('Class 3', 'CL-03', 'Primary', 3),
                ('Class 4', 'CL-04', 'Primary', 4),
                ('Class 5', 'CL-05', 'Primary', 5),
                ('Class 6', 'CL-06', 'Middle School', 6),
                ('Class 7', 'CL-07', 'Middle School', 7),
                ('Class 8', 'CL-08', 'Secondary', 8),
                ('Class 9', 'CL-09', 'Secondary', 9),
                ('Class 10', 'CL-10', 'Secondary', 10),
                ('Class 11', 'CL-11', 'Senior Secondary', 11),
                ('Class 12', 'CL-12', 'Senior Secondary', 12),
                ('B.Tech - CSE', 'BTECH-CSE', 'Higher Education', 13),
                ('B.Tech - IT', 'BTECH-IT', 'Higher Education', 14),
                ('BCA - Semester 4', 'BCA-S4', 'Higher Education', 15),
                ('MBA - Semester 2', 'MBA-S2', 'Higher Education', 16)
            ) AS t(name, code, stage, display_order)
        ) LOOP
            IF NOT EXISTS (
                SELECT 1 FROM public.academic_classes
                WHERE school_id = s.id 
                  AND UPPER(TRIM(name)) = UPPER(TRIM(cls.name))
                  AND deleted_at IS NULL
            ) THEN
                INSERT INTO public.academic_classes (
                    id, school_id, name, code, stage, academic_year, display_order, status, created_at, updated_at
                ) VALUES (
                    gen_random_uuid(), s.id, cls.name, cls.code, cls.stage, '2026-27', cls.display_order, 'ACTIVE', NOW(), NOW()
                );
            END IF;
        END LOOP;
    END LOOP;
END $$;

-- Standardize profile class names
UPDATE public.profiles
SET class = CASE
    WHEN class IN ('10 A', '10A', '10 B', '10B', '10 C') THEN 'Class 10'
    WHEN class IN ('9 A', '9 B', '9 C', 'Class 9-A') THEN 'Class 9'
    WHEN class IN ('11 A', '11A') THEN 'Class 11'
    WHEN class IN ('12 A', '12 B', '12C', '12 C') THEN 'Class 12'
    ELSE class
END,
updated_at = NOW()
WHERE class IS NOT NULL;


-- ----------------------------------------------------------------------------
-- 6. RE-POINT question_bank TO academic_classes & DROP LEGACY classes TABLE
-- ----------------------------------------------------------------------------

-- Drop foreign key constraint referencing legacy classes table if still exists
ALTER TABLE public.question_bank
DROP CONSTRAINT IF EXISTS question_bank_class_id_fkey;

-- Update question_bank.class_id to match academic_classes.id where possible
UPDATE public.question_bank qb
SET class_id = ac.id
FROM public.academic_classes ac
WHERE qb.school_id = ac.school_id
  AND UPPER(TRIM(qb.class_name)) = UPPER(TRIM(ac.name))
  AND ac.deleted_at IS NULL;

-- Nullify dangling class_ids that don't exist in academic_classes
UPDATE public.question_bank
SET class_id = NULL
WHERE class_id IS NOT NULL AND class_id NOT IN (SELECT id FROM public.academic_classes);

-- Add foreign key constraint to academic_classes
ALTER TABLE public.question_bank
ADD CONSTRAINT question_bank_class_id_fkey
FOREIGN KEY (class_id) REFERENCES public.academic_classes(id) ON DELETE SET NULL;

-- Update stored procedure: fn_get_notice_metadata
CREATE OR REPLACE FUNCTION public.fn_get_notice_metadata(p_school_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_roles JSONB;
    v_classes JSONB;
    v_categories JSONB;
BEGIN
    -- 1. Fetch active roles ONLY from app_roles (SSOT)
    SELECT COALESCE(jsonb_agg(sub.name), '[]'::jsonb)
    INTO v_roles
    FROM (
        SELECT name
        FROM public.app_roles
        WHERE UPPER(COALESCE(status, 'ACTIVE')) = 'ACTIVE'
        ORDER BY COALESCE(display_order, 999) ASC, display_name ASC, name ASC
    ) sub;

    -- 2. Fetch active classes ONLY from academic_classes (SSOT)
    SELECT COALESCE(jsonb_agg(sub.name), '[]'::jsonb)
    INTO v_classes
    FROM (
        SELECT DISTINCT name
        FROM public.academic_classes
        WHERE (school_id = p_school_id OR p_school_id IS NULL)
          AND deleted_at IS NULL
          AND UPPER(status) = 'ACTIVE'
        ORDER BY name
    ) sub;

    -- 3. Fetch notice categories
    SELECT COALESCE(jsonb_agg(sub.item), '[]'::jsonb)
    INTO v_categories
    FROM (
        SELECT jsonb_build_object(
            'id', id,
            'name', name,
            'code', code,
            'description', description,
            'icon', icon,
            'color', color,
            'sort_order', sort_order,
            'is_active', is_active
        ) AS item
        FROM public.notice_categories
        WHERE (school_id = p_school_id OR school_id IS NULL) AND is_active = TRUE
        ORDER BY sort_order ASC, name ASC
    ) sub;

    RETURN jsonb_build_object(
        'success', TRUE,
        'roles', v_roles,
        'classes', v_classes,
        'categories', v_categories
    );
END;
$function$;

-- Update stored procedure: fn_library_get_book_filter_options
CREATE OR REPLACE FUNCTION public.fn_library_get_book_filter_options(p_school_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_categories JSONB;
    v_languages JSONB;
    v_book_types JSONB;
    v_conditions JSONB;
    v_acquisition_types JSONB;
    v_authors JSONB;
    v_publishers JSONB;
    v_years JSONB;
    v_racks JSONB;
    v_classes JSONB;
    v_subjects JSONB;
    v_roles JSONB;
BEGIN
    -- Categories from lookup_keys: BOOK_CATEGORY or books
    SELECT COALESCE(jsonb_agg(DISTINCT val ORDER BY val ASC), '[]'::jsonb) INTO v_categories
    FROM (
        SELECT lv.value_name AS val
        FROM public.lookup_values lv
        JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
        WHERE lk.key_code = 'BOOK_CATEGORY' AND (lv.school_id = p_school_id OR lv.school_id IS NULL) AND lv.status = 'ACTIVE'
        UNION
        SELECT DISTINCT category_name AS val FROM public.library_books WHERE school_id = p_school_id AND category_name IS NOT NULL AND category_name != ''
    ) sub;

    -- Languages from lookup_keys: BOOK_LANGUAGE or books
    SELECT COALESCE(jsonb_agg(DISTINCT val ORDER BY val ASC), '[]'::jsonb) INTO v_languages
    FROM (
        SELECT lv.value_name AS val
        FROM public.lookup_values lv
        JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
        WHERE lk.key_code = 'BOOK_LANGUAGE' AND (lv.school_id = p_school_id OR lv.school_id IS NULL) AND lv.status = 'ACTIVE'
        UNION
        SELECT DISTINCT language_name AS val FROM public.library_books WHERE school_id = p_school_id AND language_name IS NOT NULL AND language_name != ''
    ) sub_lang;

    -- Book Types
    SELECT COALESCE(jsonb_agg(DISTINCT val ORDER BY val ASC), '[]'::jsonb) INTO v_book_types
    FROM (
        SELECT lv.value_name AS val
        FROM public.lookup_values lv
        JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
        WHERE lk.key_code = 'BOOK_TYPE' AND (lv.school_id = p_school_id OR lv.school_id IS NULL) AND lv.status = 'ACTIVE'
        UNION
        SELECT DISTINCT book_type_name AS val FROM public.library_books WHERE school_id = p_school_id AND book_type_name IS NOT NULL AND book_type_name != ''
    ) sub_bt;

    -- Physical Conditions
    SELECT COALESCE(jsonb_agg(DISTINCT val ORDER BY val ASC), '[]'::jsonb) INTO v_conditions
    FROM (
        SELECT lv.value_name AS val
        FROM public.lookup_values lv
        JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
        WHERE lk.key_code = 'BOOK_CONDITION' AND (lv.school_id = p_school_id OR lv.school_id IS NULL) AND lv.status = 'ACTIVE'
        UNION
        SELECT DISTINCT condition AS val FROM public.library_book_copies WHERE school_id = p_school_id AND condition IS NOT NULL AND condition != ''
    ) sub_c;

    -- Acquisition Types
    SELECT COALESCE(jsonb_agg(DISTINCT val ORDER BY val ASC), '[]'::jsonb) INTO v_acquisition_types
    FROM (
        SELECT lv.value_name AS val
        FROM public.lookup_values lv
        JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
        WHERE lk.key_code = 'BOOK_ACQUISITION_TYPE' AND (lv.school_id = p_school_id OR lv.school_id IS NULL) AND lv.status = 'ACTIVE'
        UNION
        SELECT DISTINCT acquisition_type AS val FROM public.library_books WHERE school_id = p_school_id AND acquisition_type IS NOT NULL AND acquisition_type != ''
    ) sub_at;

    -- Authors
    SELECT COALESCE(jsonb_agg(DISTINCT author ORDER BY author ASC), '[]'::jsonb) INTO v_authors
    FROM public.library_books WHERE school_id = p_school_id AND author IS NOT NULL AND author != '';

    -- Publishers
    SELECT COALESCE(jsonb_agg(DISTINCT publisher ORDER BY publisher ASC), '[]'::jsonb) INTO v_publishers
    FROM public.library_books WHERE school_id = p_school_id AND publisher IS NOT NULL AND publisher != '';

    -- Publication Years
    SELECT COALESCE(jsonb_agg(DISTINCT publication_year ORDER BY publication_year DESC), '[]'::jsonb) INTO v_years
    FROM public.library_books WHERE school_id = p_school_id AND publication_year IS NOT NULL;

    -- Racks / Locations
    SELECT COALESCE(jsonb_agg(DISTINCT rack ORDER BY rack ASC), '[]'::jsonb) INTO v_racks
    FROM public.library_book_copies WHERE school_id = p_school_id AND rack IS NOT NULL AND rack != '';

    -- Classes from academic_classes (SSOT)
    SELECT COALESCE(jsonb_agg(DISTINCT c.name ORDER BY c.name ASC), '[]'::jsonb) INTO v_classes
    FROM public.academic_classes c
    WHERE (c.school_id = p_school_id OR p_school_id IS NULL)
      AND c.deleted_at IS NULL
      AND c.status = 'ACTIVE';

    -- Subjects from academic_subjects
    SELECT COALESCE(jsonb_agg(DISTINCT val ORDER BY val ASC), '[]'::jsonb) INTO v_subjects
    FROM (
        SELECT DISTINCT name AS val FROM public.academic_subjects WHERE school_id = p_school_id AND deleted_at IS NULL
    ) sub_s;

    -- Dynamic App Roles from app_roles table (SSOT)
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'code', UPPER(code),
            'name', name,
            'display_name', COALESCE(display_name, INITCAP(REPLACE(name, '_', ' ')))
        ) ORDER BY COALESCE(display_order, 999) ASC, display_name ASC
    ), '[]'::jsonb) INTO v_roles
    FROM public.app_roles
    WHERE status = 'Active' AND (school_id = p_school_id OR school_id IS NULL);

    RETURN jsonb_build_object(
        'categories', v_categories,
        'languages', v_languages,
        'book_types', v_book_types,
        'conditions', v_conditions,
        'acquisition_types', v_acquisition_types,
        'authors', v_authors,
        'publishers', v_publishers,
        'publication_years', v_years,
        'years', v_years,
        'racks', v_racks,
        'classes', v_classes,
        'subjects', v_subjects,
        'roles', v_roles
    );
END;
$function$;

-- Update stored procedure: fn_student_fee_metadata
CREATE OR REPLACE FUNCTION public.fn_student_fee_metadata(p_school_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_classes JSONB;
    v_years JSONB;
    v_fee_types JSONB;
    v_payment_modes JSONB;
    v_concession_types JSONB;
    v_penalty_types JSONB;
BEGIN
    -- Classes from academic_classes (SSOT)
    SELECT COALESCE(jsonb_agg(DISTINCT c.name ORDER BY c.name ASC), '[]'::jsonb)
    INTO v_classes
    FROM public.academic_classes c
    WHERE c.school_id = p_school_id
      AND c.deleted_at IS NULL
      AND c.status = 'ACTIVE';

    -- Financial / Academic Years from lookup_values
    SELECT COALESCE(jsonb_agg(v.value_name ORDER BY v.sort_order), '["2025 - 2026", "2026 - 2027", "2027 - 2028"]'::jsonb)
    INTO v_years
    FROM public.lookup_values v
    JOIN public.lookup_keys k ON v.lookup_key_id = k.id
    WHERE k.key_code IN ('FINANCIAL_YEAR', 'ACADEMIC_YEAR') 
      AND v.school_id = p_school_id 
      AND v.status = 'ACTIVE' 
      AND v.deleted_at IS NULL;

    -- Fee Types
    SELECT COALESCE(jsonb_agg(v.value_name ORDER BY v.sort_order), '["Tuition Fee", "Admission Fee", "Exam Fee", "Library Fee", "Transport Fee", "Laboratory Fee", "Sports Fee", "Hostel Fee", "Annual Development Charges"]'::jsonb)
    INTO v_fee_types
    FROM public.lookup_values v
    JOIN public.lookup_keys k ON v.lookup_key_id = k.id
    WHERE k.key_code = 'STUDENT_FEE_TYPE' 
      AND v.school_id = p_school_id 
      AND v.status = 'ACTIVE' 
      AND v.deleted_at IS NULL;

    -- Payment Modes
    SELECT COALESCE(jsonb_agg(v.value_name ORDER BY v.sort_order), '["Cash", "UPI", "Net Banking", "Debit Card", "Credit Card", "Cheque", "Demand Draft"]'::jsonb)
    INTO v_payment_modes
    FROM public.lookup_values v
    JOIN public.lookup_keys k ON v.lookup_key_id = k.id
    WHERE k.key_code = 'PAYMENT_MODE' 
      AND v.school_id = p_school_id 
      AND v.status = 'ACTIVE' 
      AND v.deleted_at IS NULL;

    -- Concession Types
    SELECT COALESCE(jsonb_agg(v.value_name ORDER BY v.sort_order), '["Merit Scholarship", "Staff Ward Concession", "Sibling Discount", "Financial Aid / EWS", "Sports Excellence Waiver"]'::jsonb)
    INTO v_concession_types
    FROM public.lookup_values v
    JOIN public.lookup_keys k ON v.lookup_key_id = k.id
    WHERE k.key_code = 'STUDENT_FEE_CONCESSION_TYPE' 
      AND v.school_id = p_school_id 
      AND v.status = 'ACTIVE' 
      AND v.deleted_at IS NULL;

    -- Penalty Types
    SELECT COALESCE(jsonb_agg(v.value_name ORDER BY v.sort_order), '["Late Fee Surcharge", "Bounced Cheque Penalty", "Library Overdue Fine", "Hostel Property Damage Surcharge"]'::jsonb)
    INTO v_penalty_types
    FROM public.lookup_values v
    JOIN public.lookup_keys k ON v.lookup_key_id = k.id
    WHERE k.key_code = 'STUDENT_FEE_PENALTY_TYPE' 
      AND v.school_id = p_school_id 
      AND v.status = 'ACTIVE' 
      AND v.deleted_at IS NULL;

    RETURN jsonb_build_object(
        'success', true,
        'classes', v_classes,
        'academic_years', v_years,
        'fee_types', v_fee_types,
        'payment_modes', v_payment_modes,
        'concession_types', v_concession_types,
        'penalty_types', v_penalty_types
    );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 7. DROP LEGACY public.classes TABLE
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS public.classes CASCADE;
