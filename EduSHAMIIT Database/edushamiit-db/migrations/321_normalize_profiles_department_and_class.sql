-- ============================================================================
-- Migration: 321_normalize_profiles_department_and_class.sql
-- Description:
--   Normalizes existing department and class data in public.profiles.
--   - Department: Ensures all profile departments strictly match canonical 
--     value_name from public.lookup_values (under key_code = 'DEPARTMENT').
--     Maps legacy, unstandardized, and role-based staff departments to valid lookups.
--   - Class: Ensures all profile class strings strictly match active Class Management
--     records from public.academic_sections (e.g. '10A', '9B') or public.academic_classes
--     (e.g. 'Class 10', 'Class 9').
-- ============================================================================

DO $$
DECLARE
    r RECORD;
    v_school_id UUID;
    v_admin_id UUID;
    v_dept_key_id UUID;
    v_target_dept VARCHAR(150);
    v_clean_dept VARCHAR(150);
    v_target_class VARCHAR(150);
    v_clean_class VARCHAR(150);
    v_class_match VARCHAR(150);
    v_section_match VARCHAR(150);
    v_default_class VARCHAR(150);
    v_role_lower VARCHAR(100);
    v_num_part VARCHAR(50);
    v_letter_part VARCHAR(50);
    v_updated_dept_count INT := 0;
    v_updated_class_count INT := 0;
BEGIN
    -- ────────────────────────────────────────────────────────────────────────
    -- Step 1: Ensure DEPARTMENT lookup key & standard values exist per school
    -- ────────────────────────────────────────────────────────────────────────
    FOR r IN SELECT id FROM public.schools LOOP
        SELECT id INTO v_admin_id FROM public.profiles WHERE school_id = r.id LIMIT 1;
        IF v_admin_id IS NULL THEN
            SELECT id INTO v_admin_id FROM public.profiles LIMIT 1;
        END IF;

        IF v_admin_id IS NOT NULL THEN
            INSERT INTO public.lookup_keys (
                school_id, key_name, key_code, description, key_type, icon, status, created_by
            )
            VALUES (
                r.id,
                'Department',
                'DEPARTMENT',
                'Institutional and academic departments across campus.',
                'SYSTEM',
                'corporate_fare_rounded',
                'ACTIVE',
                v_admin_id
            )
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL 
            DO NOTHING;

            SELECT id INTO v_dept_key_id 
            FROM public.lookup_keys 
            WHERE school_id = r.id AND key_code = 'DEPARTMENT' AND deleted_at IS NULL 
            LIMIT 1;

            IF v_dept_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (
                    lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by
                ) VALUES
                    (v_dept_key_id, r.id, 'Academic / Teaching', 'ACADEMIC', 'Instructional faculty and academic curriculum staff.', 'ACTIVE', 1, v_admin_id),
                    (v_dept_key_id, r.id, 'Administration', 'ADMINISTRATION', 'Executive leadership and general school administration.', 'ACTIVE', 2, v_admin_id),
                    (v_dept_key_id, r.id, 'Mathematics', 'MATHEMATICS', 'Mathematics faculty and numeric sciences.', 'ACTIVE', 3, v_admin_id),
                    (v_dept_key_id, r.id, 'Science', 'SCIENCE', 'Physics, Chemistry, Biology and scientific laboratories.', 'ACTIVE', 4, v_admin_id),
                    (v_dept_key_id, r.id, 'English / Languages', 'LANGUAGES', 'Language arts, literature and linguistic studies.', 'ACTIVE', 5, v_admin_id),
                    (v_dept_key_id, r.id, 'Social Studies & Humanities', 'SOCIAL_STUDIES', 'History, Geography, Civics, and Social Sciences.', 'ACTIVE', 6, v_admin_id),
                    (v_dept_key_id, r.id, 'Computer Science & IT', 'COMPUTER_SCIENCE', 'Information technology, programming, and computer labs.', 'ACTIVE', 7, v_admin_id),
                    (v_dept_key_id, r.id, 'Finance & Accounts', 'FINANCE', 'Institutional accounting, tuition billing, and payroll.', 'ACTIVE', 8, v_admin_id),
                    (v_dept_key_id, r.id, 'Human Resources', 'HR', 'Staff recruitment, employee welfare, and personnel records.', 'ACTIVE', 9, v_admin_id),
                    (v_dept_key_id, r.id, 'Library & Information', 'LIBRARY', 'Learning resources center, book circulation, and digital media.', 'ACTIVE', 10, v_admin_id),
                    (v_dept_key_id, r.id, 'Physical Education & Sports', 'SPORTS', 'Athletics, physical education, gymnasiums, and teams.', 'ACTIVE', 11, v_admin_id),
                    (v_dept_key_id, r.id, 'Arts & Performing Arts', 'ARTS', 'Fine arts, music, dance, and creative drama studios.', 'ACTIVE', 12, v_admin_id),
                    (v_dept_key_id, r.id, 'Transport & Fleet', 'TRANSPORT', 'Buses, vans, fleet routing, and driver coordination.', 'ACTIVE', 13, v_admin_id),
                    (v_dept_key_id, r.id, 'Hostel & Residential', 'HOSTEL', 'Boarding facilities, wardens, and student residential care.', 'ACTIVE', 14, v_admin_id),
                    (v_dept_key_id, r.id, 'Security & Safety', 'SECURITY', 'Campus surveillance, security guards, and emergency protocols.', 'ACTIVE', 15, v_admin_id),
                    (v_dept_key_id, r.id, 'Medical & Health Clinic', 'HEALTH_CLINIC', 'Infirmary, campus medical staff, and student healthcare.', 'ACTIVE', 16, v_admin_id),
                    (v_dept_key_id, r.id, 'Maintenance & Facilities', 'MAINTENANCE', 'Campus repairs, electricals, sanitation, and physical upkeep.', 'ACTIVE', 17, v_admin_id),
                    (v_dept_key_id, r.id, 'Examination & Assessment', 'EXAMINATION', 'Standardized grading, test scheduling, and report cards.', 'ACTIVE', 18, v_admin_id),
                    (v_dept_key_id, r.id, 'Student Affairs & Admissions', 'STUDENT_AFFAIRS', 'Enrollment, student counseling, and co-curriculars.', 'ACTIVE', 19, v_admin_id),
                    (v_dept_key_id, r.id, 'General / Unassigned', 'GENERAL', 'Non-departmental staff or unassigned profiles.', 'ACTIVE', 20, v_admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL 
                DO NOTHING;
            END IF;
        END IF;
    END LOOP;

    -- ────────────────────────────────────────────────────────────────────────
    -- Step 2: Iterate through all profiles to normalize DEPARTMENT & CLASS
    -- ────────────────────────────────────────────────────────────────────────
    FOR r IN SELECT id, school_id, role, department, class, full_name, email FROM public.profiles LOOP
        v_school_id := r.school_id;
        v_role_lower := LOWER(COALESCE(r.role, ''));
        v_clean_dept := TRIM(COALESCE(r.department, ''));
        v_clean_class := TRIM(COALESCE(r.class, ''));
        v_target_dept := NULL;
        v_target_class := NULL;

        -- ────────────────────────────────────────────────────────────────────
        -- A. Normalize DEPARTMENT from Lookup Key-Value Table
        -- ────────────────────────────────────────────────────────────────────
        IF v_clean_dept <> '' AND v_clean_dept <> 'None' AND v_clean_dept <> 'null' AND v_clean_dept <> '-' THEN
            -- 1. Try exact match on value_name in lookup_values
            SELECT lv.value_name INTO v_target_dept
            FROM public.lookup_values lv
            JOIN public.lookup_keys lk ON lk.id = lv.lookup_key_id
            WHERE lk.key_code = 'DEPARTMENT'
              AND (v_school_id IS NULL OR lv.school_id = v_school_id)
              AND lv.deleted_at IS NULL
              AND LOWER(TRIM(lv.value_name)) = LOWER(v_clean_dept)
            LIMIT 1;

            -- 2. Try exact match on value_code in lookup_values
            IF v_target_dept IS NULL THEN
                SELECT lv.value_name INTO v_target_dept
                FROM public.lookup_values lv
                JOIN public.lookup_keys lk ON lk.id = lv.lookup_key_id
                WHERE lk.key_code = 'DEPARTMENT'
                  AND (v_school_id IS NULL OR lv.school_id = v_school_id)
                  AND lv.deleted_at IS NULL
                  AND LOWER(TRIM(lv.value_code)) = LOWER(v_clean_dept)
                LIMIT 1;
            END IF;

            -- 3. Pattern / Semantic Matching to Canonical Department Values
            IF v_target_dept IS NULL THEN
                IF v_clean_dept ILIKE '%math%' THEN
                    v_target_dept := 'Mathematics';
                ELSIF v_clean_dept ILIKE '%sci%' OR v_clean_dept ILIKE '%physic%' OR v_clean_dept ILIKE '%chem%' OR v_clean_dept ILIKE '%bio%' THEN
                    v_target_dept := 'Science';
                ELSIF v_clean_dept ILIKE '%eng%' OR v_clean_dept ILIKE '%lang%' OR v_clean_dept ILIKE '%hindi%' OR v_clean_dept ILIKE '%french%' OR v_clean_dept ILIKE '%spanish%' THEN
                    v_target_dept := 'English / Languages';
                ELSIF v_clean_dept ILIKE '%social%' OR v_clean_dept ILIKE '%hist%' OR v_clean_dept ILIKE '%geo%' OR v_clean_dept ILIKE '%civic%' OR v_clean_dept ILIKE '%humanit%' THEN
                    v_target_dept := 'Social Studies & Humanities';
                ELSIF v_clean_dept ILIKE '%comp%' OR v_clean_dept ILIKE '%cs%' OR v_clean_dept ILIKE '%it%' OR v_clean_dept ILIKE '%tech%' OR v_clean_dept ILIKE '%software%' THEN
                    v_target_dept := 'Computer Science & IT';
                ELSIF v_clean_dept ILIKE '%fin%' OR v_clean_dept ILIKE '%acc%' OR v_clean_dept ILIKE '%bill%' OR v_clean_dept ILIKE '%pay%' OR v_clean_dept ILIKE '%fee%' THEN
                    v_target_dept := 'Finance & Accounts';
                ELSIF v_clean_dept ILIKE '%hr%' OR v_clean_dept ILIKE '%human res%' OR v_clean_dept ILIKE '%personnel%' THEN
                    v_target_dept := 'Human Resources';
                ELSIF v_clean_dept ILIKE '%lib%' OR v_clean_dept ILIKE '%book%' THEN
                    v_target_dept := 'Library & Information';
                ELSIF v_clean_dept ILIKE '%sport%' OR v_clean_dept ILIKE '%pe%' OR v_clean_dept ILIKE '%phys% ed%' OR v_clean_dept ILIKE '%coach%' OR v_clean_dept ILIKE '%gym%' THEN
                    v_target_dept := 'Physical Education & Sports';
                ELSIF v_clean_dept ILIKE '%art%' OR v_clean_dept ILIKE '%music%' OR v_clean_dept ILIKE '%dance%' OR v_clean_dept ILIKE '%drama%' THEN
                    v_target_dept := 'Arts & Performing Arts';
                ELSIF v_clean_dept ILIKE '%trans%' OR v_clean_dept ILIKE '%bus%' OR v_clean_dept ILIKE '%driver%' OR v_clean_dept ILIKE '%fleet%' THEN
                    v_target_dept := 'Transport & Fleet';
                ELSIF v_clean_dept ILIKE '%hostel%' OR v_clean_dept ILIKE '%warden%' OR v_clean_dept ILIKE '%dorm%' OR v_clean_dept ILIKE '%resident%' THEN
                    v_target_dept := 'Hostel & Residential';
                ELSIF v_clean_dept ILIKE '%sec%' OR v_clean_dept ILIKE '%guard%' OR v_clean_dept ILIKE '%safety%' THEN
                    v_target_dept := 'Security & Safety';
                ELSIF v_clean_dept ILIKE '%med%' OR v_clean_dept ILIKE '%health%' OR v_clean_dept ILIKE '%clinic%' OR v_clean_dept ILIKE '%nurse%' OR v_clean_dept ILIKE '%doctor%' THEN
                    v_target_dept := 'Medical & Health Clinic';
                ELSIF v_clean_dept ILIKE '%maint%' OR v_clean_dept ILIKE '%facil%' OR v_clean_dept ILIKE '%clean%' OR v_clean_dept ILIKE '%electr%' THEN
                    v_target_dept := 'Maintenance & Facilities';
                ELSIF v_clean_dept ILIKE '%exam%' OR v_clean_dept ILIKE '%assess%' OR v_clean_dept ILIKE '%test%' THEN
                    v_target_dept := 'Examination & Assessment';
                ELSIF v_clean_dept ILIKE '%student affair%' OR v_clean_dept ILIKE '%admiss%' OR v_clean_dept ILIKE '%counsel%' THEN
                    v_target_dept := 'Student Affairs & Admissions';
                ELSIF v_clean_dept ILIKE '%admin%' OR v_clean_dept ILIKE '%mgmt%' OR v_clean_dept ILIKE '%manage%' OR v_clean_dept ILIKE '%office%' OR v_clean_dept ILIKE '%principal%' OR v_clean_dept ILIKE '%director%' THEN
                    v_target_dept := 'Administration';
                ELSIF v_clean_dept ILIKE '%teach%' OR v_clean_dept ILIKE '%academ%' OR v_clean_dept ILIKE '%faculty%' THEN
                    v_target_dept := 'Academic / Teaching';
                ELSE
                    v_target_dept := 'General / Unassigned';
                END IF;
            END IF;
        ELSE
            -- If department is missing / empty on staff profiles, assign appropriate default based on role
            IF v_role_lower IN ('teacher', 'class_teacher', 'subject_teacher', 'teacher_admin') THEN
                v_target_dept := 'Academic / Teaching';
            ELSIF v_role_lower IN ('admin', 'director', 'principal', 'owner', 'super_admin') THEN
                v_target_dept := 'Administration';
            ELSIF v_role_lower IN ('finance') THEN
                v_target_dept := 'Finance & Accounts';
            ELSIF v_role_lower IN ('hr') THEN
                v_target_dept := 'Human Resources';
            ELSIF v_role_lower IN ('library', 'librarian') THEN
                v_target_dept := 'Library & Information';
            ELSIF v_role_lower IN ('sports', 'coach') THEN
                v_target_dept := 'Physical Education & Sports';
            ELSIF v_role_lower IN ('transport', 'driver') THEN
                v_target_dept := 'Transport & Fleet';
            ELSIF v_role_lower IN ('hostel', 'warden') THEN
                v_target_dept := 'Hostel & Residential';
            ELSIF v_role_lower IN ('security') THEN
                v_target_dept := 'Security & Safety';
            ELSIF v_role_lower IN ('exam_ctrl') THEN
                v_target_dept := 'Examination & Assessment';
            ELSIF v_role_lower IN ('support') THEN
                v_target_dept := 'Maintenance & Facilities';
            ELSE
                v_target_dept := NULL; -- Students / Parents remain without department
            END IF;
        END IF;

        -- ────────────────────────────────────────────────────────────────────
        -- B. Normalize CLASS from Class Management (academic_classes & sections)
        -- ────────────────────────────────────────────────────────────────────
        IF v_clean_class <> '' AND v_clean_class <> 'None' AND v_clean_class <> 'null' AND v_clean_class <> 'undefined' AND v_clean_class <> 'N/A' AND v_clean_class <> 'NA' AND v_clean_class <> '-' THEN
            v_section_match := NULL;
            v_class_match := NULL;

            -- 1. Check exact match in academic_sections.code (e.g. '10A', '9B', '12A')
            SELECT s.code INTO v_section_match
            FROM public.academic_sections s
            WHERE (v_school_id IS NULL OR s.school_id = v_school_id)
              AND s.deleted_at IS NULL
              AND LOWER(TRIM(s.code)) = LOWER(v_clean_class)
            LIMIT 1;

            -- 2. Check exact match in academic_classes.name (e.g. 'Class 10', 'Class 9')
            IF v_section_match IS NULL THEN
                SELECT c.name INTO v_class_match
                FROM public.academic_classes c
                WHERE (v_school_id IS NULL OR c.school_id = v_school_id)
                  AND c.deleted_at IS NULL
                  AND LOWER(TRIM(c.name)) = LOWER(v_clean_class)
                LIMIT 1;
            END IF;

            -- 3. Check exact match in academic_classes.code (e.g. 'CL-10' or '10')
            IF v_section_match IS NULL AND v_class_match IS NULL THEN
                SELECT c.name INTO v_class_match
                FROM public.academic_classes c
                WHERE (v_school_id IS NULL OR c.school_id = v_school_id)
                  AND c.deleted_at IS NULL
                  AND (LOWER(TRIM(c.code)) = LOWER(v_clean_class) OR LOWER(TRIM(c.code)) = LOWER('CL-' || v_clean_class))
                LIMIT 1;
            END IF;

            -- 4. Pattern matching: extract numeric and alphabetic parts (e.g. '10-A', 'Class 10 A', 'Grade 10A', '10th A')
            IF v_section_match IS NULL AND v_class_match IS NULL THEN
                v_num_part := substring(v_clean_class from '([0-9]{1,2})');
                v_letter_part := substring(v_clean_class from '(?i)([A-F])');

                IF v_num_part IS NOT NULL AND v_letter_part IS NOT NULL THEN
                    -- Check if combined section code exists (e.g. '10A')
                    SELECT s.code INTO v_section_match
                    FROM public.academic_sections s
                    JOIN public.academic_classes c ON c.id = s.class_id
                    WHERE (v_school_id IS NULL OR s.school_id = v_school_id)
                      AND s.deleted_at IS NULL
                      AND (
                          LOWER(s.code) = LOWER(v_num_part || v_letter_part)
                          OR (c.name ILIKE '%' || v_num_part || '%' AND s.name ILIKE '%' || v_letter_part || '%')
                      )
                    LIMIT 1;
                END IF;

                IF v_section_match IS NULL AND v_num_part IS NOT NULL THEN
                    -- Match class name containing the number (e.g. 'Class 10')
                    SELECT c.name INTO v_class_match
                    FROM public.academic_classes c
                    WHERE (v_school_id IS NULL OR c.school_id = v_school_id)
                      AND c.deleted_at IS NULL
                      AND (c.name ILIKE '% ' || v_num_part OR c.code ILIKE '%' || v_num_part)
                    ORDER BY c.display_order ASC
                    LIMIT 1;
                END IF;
            END IF;

            IF v_section_match IS NOT NULL THEN
                v_target_class := v_section_match;
            ELSIF v_class_match IS NOT NULL THEN
                v_target_class := v_class_match;
            ELSE
                -- If not found in class management and user is not a student, clear invalid class text
                IF v_role_lower <> 'student' THEN
                    v_target_class := NULL;
                ELSE
                    -- For student, fallback to closest active class in school if available
                    SELECT c.name INTO v_target_class
                    FROM public.academic_classes c
                    WHERE (v_school_id IS NULL OR c.school_id = v_school_id)
                      AND c.deleted_at IS NULL AND c.status = 'ACTIVE'
                    ORDER BY c.display_order ASC
                    LIMIT 1;
                END IF;
            END IF;
        ELSE
            -- If user is NOT a student, class should be NULL
            IF v_role_lower <> 'student' THEN
                v_target_class := NULL;
            ELSE
                -- Student without class: preserve as NULL or assign primary active class if needed
                v_target_class := NULL;
            END IF;
        END IF;

        -- ────────────────────────────────────────────────────────────────────
        -- C. Apply Updates to public.profiles
        -- ────────────────────────────────────────────────────────────────────
        IF (v_target_dept IS DISTINCT FROM r.department) OR (v_target_class IS DISTINCT FROM r.class) THEN
            UPDATE public.profiles
            SET 
                department = v_target_dept,
                class = v_target_class,
                updated_at = NOW()
            WHERE id = r.id;

            IF v_target_dept IS DISTINCT FROM r.department THEN
                v_updated_dept_count := v_updated_dept_count + 1;
            END IF;
            IF v_target_class IS DISTINCT FROM r.class THEN
                v_updated_class_count := v_updated_class_count + 1;
            END IF;
        END IF;
    END LOOP;

    RAISE NOTICE 'Normalization Complete: % department fields updated, % class fields updated in public.profiles.',
        v_updated_dept_count, v_updated_class_count;
END $$;
