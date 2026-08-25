-- ============================================================================
-- Migration: 320_seed_department_lookups.sql
-- Description:
--   Seeds universal DEPARTMENT lookup key and standard enterprise department
--   lookup values across all schools.
--   Enhances fn_calculate_lookup_usage to track DEPARTMENT usage in public.profiles.
-- ============================================================================

DO $$
DECLARE
    s RECORD;
    admin_id UUID;
    v_key_id UUID;
    v_max_sort INT;
BEGIN
    FOR s IN SELECT id FROM public.schools LOOP
        SELECT id INTO admin_id FROM public.profiles WHERE school_id = s.id LIMIT 1;
        IF admin_id IS NULL THEN
            SELECT id INTO admin_id FROM public.profiles LIMIT 1;
        END IF;

        IF admin_id IS NOT NULL THEN
            -- 1. Insert or update the DEPARTMENT lookup key for the school
            INSERT INTO public.lookup_keys (
                school_id, key_name, key_code, description, key_type, icon, status, created_by
            )
            VALUES (
                s.id,
                'Department',
                'DEPARTMENT',
                'Institutional and academic departments across campus.',
                'SYSTEM',
                'corporate_fare_rounded',
                'ACTIVE',
                admin_id
            )
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL 
            DO UPDATE SET 
                key_name = EXCLUDED.key_name,
                description = EXCLUDED.description,
                icon = EXCLUDED.icon
            RETURNING id INTO v_key_id;

            IF v_key_id IS NULL THEN
                SELECT id INTO v_key_id 
                FROM public.lookup_keys 
                WHERE school_id = s.id AND key_code = 'DEPARTMENT' AND deleted_at IS NULL 
                LIMIT 1;
            END IF;

            IF v_key_id IS NOT NULL THEN
                -- 2. Seed standard enterprise department lookup values
                INSERT INTO public.lookup_values (
                    lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by
                ) VALUES
                    (v_key_id, s.id, 'Academic / Teaching', 'ACADEMIC', 'Instructional faculty and academic curriculum staff.', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Administration', 'ADMINISTRATION', 'Executive leadership and general school administration.', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Mathematics', 'MATHEMATICS', 'Mathematics faculty and numeric sciences.', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Science', 'SCIENCE', 'Physics, Chemistry, Biology and scientific laboratories.', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, 'English / Languages', 'LANGUAGES', 'Language arts, literature and linguistic studies.', 'ACTIVE', 5, admin_id),
                    (v_key_id, s.id, 'Social Studies & Humanities', 'SOCIAL_STUDIES', 'History, Geography, Civics, and Social Sciences.', 'ACTIVE', 6, admin_id),
                    (v_key_id, s.id, 'Computer Science & IT', 'COMPUTER_SCIENCE', 'Information technology, programming, and computer labs.', 'ACTIVE', 7, admin_id),
                    (v_key_id, s.id, 'Finance & Accounts', 'FINANCE', 'Institutional accounting, tuition billing, and payroll.', 'ACTIVE', 8, admin_id),
                    (v_key_id, s.id, 'Human Resources', 'HR', 'Staff recruitment, employee welfare, and personnel records.', 'ACTIVE', 9, admin_id),
                    (v_key_id, s.id, 'Library & Information', 'LIBRARY', 'Learning resources center, book circulation, and digital media.', 'ACTIVE', 10, admin_id),
                    (v_key_id, s.id, 'Physical Education & Sports', 'SPORTS', 'Athletics, physical education, gymnasiums, and teams.', 'ACTIVE', 11, admin_id),
                    (v_key_id, s.id, 'Arts & Performing Arts', 'ARTS', 'Fine arts, music, dance, and creative drama studios.', 'ACTIVE', 12, admin_id),
                    (v_key_id, s.id, 'Transport & Fleet', 'TRANSPORT', 'Buses, vans, fleet routing, and driver coordination.', 'ACTIVE', 13, admin_id),
                    (v_key_id, s.id, 'Hostel & Residential', 'HOSTEL', 'Boarding facilities, wardens, and student residential care.', 'ACTIVE', 14, admin_id),
                    (v_key_id, s.id, 'Security & Safety', 'SECURITY', 'Campus surveillance, security guards, and emergency protocols.', 'ACTIVE', 15, admin_id),
                    (v_key_id, s.id, 'Medical & Health Clinic', 'HEALTH_CLINIC', 'Infirmary, campus medical staff, and student healthcare.', 'ACTIVE', 16, admin_id),
                    (v_key_id, s.id, 'Maintenance & Facilities', 'MAINTENANCE', 'Campus repairs, electricals, sanitation, and physical upkeep.', 'ACTIVE', 17, admin_id),
                    (v_key_id, s.id, 'Examination & Assessment', 'EXAMINATION', 'Standardized grading, test scheduling, and report cards.', 'ACTIVE', 18, admin_id),
                    (v_key_id, s.id, 'Student Affairs & Admissions', 'STUDENT_AFFAIRS', 'Enrollment, student counseling, and co-curriculars.', 'ACTIVE', 19, admin_id),
                    (v_key_id, s.id, 'General / Unassigned', 'GENERAL', 'Non-departmental staff or unassigned profiles.', 'ACTIVE', 20, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL 
                DO UPDATE SET 
                    value_name = EXCLUDED.value_name,
                    description = EXCLUDED.description,
                    status = 'ACTIVE';
            END IF;
        END IF;
    END LOOP;
END $$;


-- 3. Update fn_calculate_lookup_usage to safely count profiles by DEPARTMENT
CREATE OR REPLACE FUNCTION public.fn_calculate_lookup_usage(
    p_school_id UUID,
    p_lookup_key_id UUID,
    p_lookup_value_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_key_code VARCHAR(150);
    v_val_code VARCHAR(150);
    v_val_name VARCHAR(150);
    v_usage_list JSONB := '[]'::JSONB;
    v_total_records INT := 0;
    v_modules_count INT := 0;
    v_cnt INT := 0;
BEGIN
    SELECT key_code INTO v_key_code 
    FROM public.lookup_keys 
    WHERE id = p_lookup_key_id AND school_id = p_school_id;

    IF p_lookup_value_id IS NOT NULL THEN
        SELECT value_code, value_name INTO v_val_code, v_val_name 
        FROM public.lookup_values 
        WHERE id = p_lookup_value_id AND lookup_key_id = p_lookup_key_id;
    END IF;

    -- Check Calendar / Events module usage safely
    IF (v_key_code = 'CALENDAR_CATEGORY' OR v_key_code = 'EVENT_CATEGORY') AND to_regclass('public.events') IS NOT NULL THEN
        BEGIN
            IF v_val_code IS NOT NULL THEN
                EXECUTE 'SELECT COUNT(*) FROM public.events WHERE school_id = $1 AND (category_code = $2 OR category = $2)' 
                INTO v_cnt USING p_school_id, v_val_code;
            ELSE
                EXECUTE 'SELECT COUNT(*) FROM public.events WHERE school_id = $1 AND (category IS NOT NULL OR category_code IS NOT NULL)' 
                INTO v_cnt USING p_school_id;
            END IF;
            IF v_cnt > 0 THEN
                v_usage_list := v_usage_list || jsonb_build_object('module', 'Calendar', 'records', v_cnt, 'table', 'events');
                v_total_records := v_total_records + v_cnt;
                v_modules_count := v_modules_count + 1;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            -- ignore
        END;
    END IF;

    -- Check Notice module usage safely
    IF (v_key_code = 'NOTICE_CATEGORY' OR v_key_code = 'CATEGORY') AND to_regclass('public.notices') IS NOT NULL THEN
        BEGIN
            IF v_val_code IS NOT NULL THEN
                EXECUTE 'SELECT COUNT(*) FROM public.notices WHERE school_id = $1 AND category = $2' 
                INTO v_cnt USING p_school_id, v_val_code;
            ELSE
                EXECUTE 'SELECT COUNT(*) FROM public.notices WHERE school_id = $1 AND category IS NOT NULL' 
                INTO v_cnt USING p_school_id;
            END IF;
            IF v_cnt > 0 THEN
                v_usage_list := v_usage_list || jsonb_build_object('module', 'Notices', 'records', v_cnt, 'table', 'notices');
                v_total_records := v_total_records + v_cnt;
                v_modules_count := v_modules_count + 1;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            -- ignore
        END;
    END IF;

    -- Check Vehicle / Transport module usage safely
    IF v_key_code = 'VEHICLE_CATEGORY' AND to_regclass('public.vehicles') IS NOT NULL THEN
        BEGIN
            IF v_val_code IS NOT NULL THEN
                EXECUTE 'SELECT COUNT(*) FROM public.vehicles WHERE school_id = $1 AND type = $2' 
                INTO v_cnt USING p_school_id, v_val_code;
            ELSE
                EXECUTE 'SELECT COUNT(*) FROM public.vehicles WHERE school_id = $1' 
                INTO v_cnt USING p_school_id;
            END IF;
            IF v_cnt > 0 THEN
                v_usage_list := v_usage_list || jsonb_build_object('module', 'Transport', 'records', v_cnt, 'table', 'vehicles');
                v_total_records := v_total_records + v_cnt;
                v_modules_count := v_modules_count + 1;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            -- ignore
        END;
    END IF;

    -- Check User Category usage safely
    IF v_key_code = 'USER_CATEGORY' AND to_regclass('public.profiles') IS NOT NULL THEN
        BEGIN
            IF v_val_code IS NOT NULL THEN
                EXECUTE 'SELECT COUNT(*) FROM public.profiles WHERE school_id = $1 AND role ILIKE $2' 
                INTO v_cnt USING p_school_id, v_val_code;
            ELSE
                EXECUTE 'SELECT COUNT(*) FROM public.profiles WHERE school_id = $1' 
                INTO v_cnt USING p_school_id;
            END IF;
            IF v_cnt > 0 THEN
                v_usage_list := v_usage_list || jsonb_build_object('module', 'Users', 'records', v_cnt, 'table', 'profiles');
                v_total_records := v_total_records + v_cnt;
                v_modules_count := v_modules_count + 1;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            -- ignore
        END;
    END IF;

    -- Check Department usage in profiles safely
    IF (v_key_code = 'DEPARTMENT' OR v_key_code = 'DEPARTMENTS') AND to_regclass('public.profiles') IS NOT NULL THEN
        BEGIN
            IF v_val_code IS NOT NULL OR v_val_name IS NOT NULL THEN
                EXECUTE 'SELECT COUNT(*) FROM public.profiles WHERE school_id = $1 AND (UPPER(department) = UPPER($2) OR UPPER(department) = UPPER($3))' 
                INTO v_cnt USING p_school_id, COALESCE(v_val_code, ''), COALESCE(v_val_name, '');
            ELSE
                EXECUTE 'SELECT COUNT(*) FROM public.profiles WHERE school_id = $1 AND department IS NOT NULL AND department <> ''''' 
                INTO v_cnt USING p_school_id;
            END IF;
            IF v_cnt > 0 THEN
                v_usage_list := v_usage_list || jsonb_build_object('module', 'User Management (Departments)', 'records', v_cnt, 'table', 'profiles');
                v_total_records := v_total_records + v_cnt;
                v_modules_count := v_modules_count + 1;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            -- ignore
        END;
    END IF;

    -- Include any custom entries in lookup_usage_registry
    IF to_regclass('public.lookup_usage_registry') IS NOT NULL THEN
        FOR v_cnt, v_key_code IN 
            SELECT record_count, module_name 
            FROM public.lookup_usage_registry 
            WHERE school_id = p_school_id 
              AND lookup_key_id = p_lookup_key_id 
              AND (p_lookup_value_id IS NULL OR lookup_value_id = p_lookup_value_id)
        LOOP
            v_usage_list := v_usage_list || jsonb_build_object('module', v_key_code, 'records', v_cnt);
            v_total_records := v_total_records + v_cnt;
            v_modules_count := v_modules_count + 1;
        END LOOP;
    END IF;

    RETURN jsonb_build_object(
        'total_records', v_total_records,
        'modules_count', v_modules_count,
        'modules_summary', CASE 
            WHEN v_modules_count = 0 THEN '0 Modules'
            WHEN v_modules_count = 1 THEN (v_usage_list->0->>'module') || ' (1 Module)'
            ELSE (v_usage_list->0->>'module') || ' +' || (v_modules_count - 1)::TEXT || ' more (' || v_modules_count::TEXT || ' Modules)'
        END,
        'breakdown', v_usage_list
    );
END;
$$;
