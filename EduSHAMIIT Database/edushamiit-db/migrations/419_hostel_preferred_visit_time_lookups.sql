-- ============================================================================
-- Migration 419: Seed Hostel Preferred Visit Time Lookup Key & Values
-- ============================================================================

DO $$
DECLARE
    r_school RECORD;
    v_key_id UUID;
BEGIN
    FOR r_school IN SELECT id FROM public.schools LOOP

        -- 1. HOSTEL_PREFERRED_VISIT_TIME
        SELECT id INTO v_key_id 
        FROM public.lookup_keys 
        WHERE school_id = r_school.id AND key_code = 'HOSTEL_PREFERRED_VISIT_TIME' AND deleted_at IS NULL;

        IF v_key_id IS NULL THEN
            INSERT INTO public.lookup_keys (
                id, school_id, key_name, key_code, description, 
                key_type, icon, status, version, created_at, updated_at
            ) VALUES (
                gen_random_uuid(), r_school.id, 'Hostel Preferred Visit Time', 'HOSTEL_PREFERRED_VISIT_TIME', 
                'Preferred time slots for hostel maintenance technician visits', 'SYSTEM', 'schedule', 
                'ACTIVE', 1, NOW(), NOW()
            ) RETURNING id INTO v_key_id;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'ANY_TIME' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Any Time (Next Available Slot)', 'ANY_TIME', 'Technician may visit at any available working hour', 'ACTIVE', 1, NOW(), NOW());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'MORNING_SLOT' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Morning (09:00 AM - 12:00 PM)', 'MORNING_SLOT', 'Morning maintenance inspection slot', 'ACTIVE', 2, NOW(), NOW());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'AFTERNOON_SLOT' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Afternoon (12:00 PM - 04:00 PM)', 'AFTERNOON_SLOT', 'Afternoon maintenance inspection slot', 'ACTIVE', 3, NOW(), NOW());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'EVENING_SLOT' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Evening (04:00 PM - 07:00 PM)', 'EVENING_SLOT', 'Evening maintenance inspection slot', 'ACTIVE', 4, NOW(), NOW());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'IMMEDIATE' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Immediate / Emergency (Within 1 Hour)', 'IMMEDIATE', 'Urgent maintenance attention required immediately', 'ACTIVE', 5, NOW(), NOW());
        END IF;

    END LOOP;
END $$;

