-- ============================================================================
-- Migration: 309_insert_calendar_category_lookup_values.sql
-- Description:
--   Inserts requested lookup values (TASK, CLASS, TRAINING, TRIP, LEAVE, GENERAL)
--   for CALENDAR_CATEGORY key in lookup_values table across all schools.
-- ============================================================================

DO $$
DECLARE
    k RECORD;
    admin_id UUID;
    v_max_sort INT;
BEGIN
    FOR k IN SELECT id, school_id FROM public.lookup_keys WHERE key_code = 'CALENDAR_CATEGORY' AND deleted_at IS NULL LOOP
        SELECT id INTO admin_id FROM public.profiles WHERE school_id = k.school_id LIMIT 1;
        IF admin_id IS NULL THEN
            SELECT id INTO admin_id FROM public.profiles LIMIT 1;
        END IF;

        SELECT COALESCE(MAX(sort_order), 0) INTO v_max_sort FROM public.lookup_values WHERE lookup_key_id = k.id AND deleted_at IS NULL;

        INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, status, sort_order, created_by)
        VALUES
            (k.id, k.school_id, 'Task', 'TASK', 'ACTIVE', v_max_sort + 1, admin_id),
            (k.id, k.school_id, 'Class', 'CLASS', 'ACTIVE', v_max_sort + 2, admin_id),
            (k.id, k.school_id, 'Training', 'TRAINING', 'ACTIVE', v_max_sort + 3, admin_id),
            (k.id, k.school_id, 'Trip', 'TRIP', 'ACTIVE', v_max_sort + 4, admin_id),
            (k.id, k.school_id, 'Leave', 'LEAVE', 'ACTIVE', v_max_sort + 5, admin_id),
            (k.id, k.school_id, 'General', 'GENERAL', 'ACTIVE', v_max_sort + 6, admin_id)
        ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL 
        DO UPDATE SET value_name = EXCLUDED.value_name, status = 'ACTIVE';
    END LOOP;
END $$;
