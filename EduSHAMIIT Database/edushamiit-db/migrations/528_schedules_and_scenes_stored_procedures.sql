-- Migration: 528_schedules_and_scenes_stored_procedures.sql
-- Description: Stored Procedures & Functions for Schedules and Scenes & Presets (KPIs, Paginated Filters, CRUD, Single Run, and Bulk Multi-Selection Operations)

-- ====================================================================
-- PART 1: SCHEDULES STORED PROCEDURES & FUNCTIONS
-- ====================================================================

-- 1.1 KPI Calculation for Schedules
CREATE OR REPLACE FUNCTION public.fn_device_schedules_kpis(p_school_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total INT := 0;
    v_active INT := 0;
    v_paused INT := 0;
    v_active_pct NUMERIC := 0;
    v_paused_pct NUMERIC := 0;
    v_upcoming INT := 0;
    v_executed_today INT := 0;
    v_failed_today INT := 0;
    v_completed_count INT := 0;
BEGIN
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE status = 'active' OR is_active = true),
        COUNT(*) FILTER (WHERE status = 'paused' OR is_active = false)
    INTO v_total, v_active, v_paused
    FROM public.device_schedules
    WHERE school_id = p_school_id;

    IF v_total > 0 THEN
        v_active_pct := ROUND((v_active::NUMERIC / v_total::NUMERIC) * 100, 1);
        v_paused_pct := ROUND((v_paused::NUMERIC / v_total::NUMERIC) * 100, 1);
    END IF;

    -- Upcoming next 24h
    SELECT COUNT(*)
    INTO v_upcoming
    FROM public.device_schedules
    WHERE school_id = p_school_id
      AND (status = 'active' OR is_active = true)
      AND next_run_at >= now()
      AND next_run_at <= now() + interval '24 hours';

    -- If 0 upcoming scheduled, check timeline table or default to active schedules with upcoming events
    IF v_upcoming = 0 THEN
        SELECT COUNT(*)
        INTO v_upcoming
        FROM public.device_schedule_timeline_events te
        JOIN public.device_schedules s ON te.schedule_id = s.id
        WHERE s.school_id = p_school_id AND te.is_upcoming = true;
    END IF;

    -- Executed & Failed today from execution log
    SELECT 
        COUNT(*) FILTER (WHERE trigger_time >= date_trunc('day', now())),
        COUNT(*) FILTER (WHERE trigger_time >= date_trunc('day', now()) AND status = 'failed'),
        COUNT(*)
    INTO v_executed_today, v_failed_today, v_completed_count
    FROM public.device_schedule_executions
    WHERE school_id = p_school_id;

    RETURN jsonb_build_object(
        'total_schedules', v_total,
        'active_schedules', v_active,
        'active_percentage', v_active_pct,
        'paused_schedules', v_paused,
        'paused_percentage', v_paused_pct,
        'upcoming_24h', GREATEST(v_upcoming, 0),
        'executed_today', GREATEST(v_executed_today, 0),
        'failed_skipped', GREATEST(v_failed_today, 0),
        'completed_count', GREATEST(v_completed_count, 0)
    );
END;
$$;


-- 1.2 Paginated, Filtered, and Sorted Schedules List
CREATE OR REPLACE FUNCTION public.fn_list_device_schedules(
    p_school_id UUID,
    p_search TEXT DEFAULT NULL,
    p_status TEXT DEFAULT NULL,
    p_target_type TEXT DEFAULT NULL,
    p_operation_type TEXT DEFAULT NULL,
    p_sort_by TEXT DEFAULT 'created_at',
    p_sort_dir TEXT DEFAULT 'desc',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_offset INT := 0;
    v_total INT := 0;
    v_total_pages INT := 1;
    v_items JSONB := '[]'::JSONB;
BEGIN
    v_offset := GREATEST((COALESCE(p_page, 1) - 1) * GREATEST(COALESCE(p_page_size, 10), 1), 0);

    -- Count total matching
    SELECT COUNT(*)
    INTO v_total
    FROM public.device_schedules s
    WHERE s.school_id = p_school_id
      AND (p_search IS NULL OR p_search = '' OR s.name ILIKE '%' || p_search || '%' OR s.schedule_code ILIKE '%' || p_search || '%' OR s.target_name ILIKE '%' || p_search || '%')
      AND (
          p_status IS NULL OR p_status = '' OR p_status = 'all' 
          OR (p_status = 'active' AND (s.status = 'active' OR s.is_active = true))
          OR (p_status = 'paused' AND (s.status = 'paused' OR s.is_active = false))
          OR (s.status ILIKE p_status)
      )
      AND (p_target_type IS NULL OR p_target_type = '' OR p_target_type = 'all' OR s.target_type ILIKE p_target_type)
      AND (p_operation_type IS NULL OR p_operation_type = '' OR p_operation_type = 'all' OR s.operation_type ILIKE p_operation_type);

    v_total_pages := GREATEST(CEIL(v_total::NUMERIC / GREATEST(COALESCE(p_page_size, 10), 1)::NUMERIC)::INT, 1);

    -- Fetch paginated items
    SELECT COALESCE(jsonb_agg(sub.schedule_obj), '[]'::JSONB)
    INTO v_items
    FROM (
        SELECT jsonb_build_object(
            'id', s.id,
            'school_id', s.school_id,
            'schedule_code', COALESCE(s.schedule_code, 'SCH-' || SUBSTRING(s.id::text, 1, 6)),
            'name', s.name,
            'description', COALESCE(s.description, ''),
            'operation_type', COALESCE(s.operation_type, 'turn_on_off'),
            'operation_value', COALESCE(s.operation_value, '{}'::jsonb),
            'target_type', COALESCE(s.target_type, 'devices'),
            'target_name', COALESCE(s.target_name, 'All Devices'),
            'target_count', COALESCE(s.target_count, 1),
            'target_ids', COALESCE(to_jsonb(s.target_ids), '[]'::jsonb),
            'recurrence_type', COALESCE(s.recurrence_type, 'daily'),
            'recurrence_label', COALESCE(s.recurrence_label, 'Daily'),
            'time_window_label', COALESCE(s.time_window_label, '07:00 AM - 06:00 PM'),
            'validity_label', COALESCE(s.validity_label, '01 Jan 2025 - No End Date'),
            'start_time', s.start_time::TEXT,
            'end_time', s.end_time::TEXT,
            'days_of_week', COALESCE(to_jsonb(s.days_of_week), '[]'::jsonb),
            'next_run_at', s.next_run_at,
            'last_run_at', s.last_run_at,
            'last_status', COALESCE(s.last_status, 'success'),
            'status', COALESCE(s.status, CASE WHEN s.is_active = false THEN 'paused' ELSE 'active' END),
            'is_active', COALESCE(s.is_active, true),
            'created_by_name', COALESCE(s.created_by_name, 'Admin'),
            'created_at', s.created_at,
            'updated_at', s.updated_at
        ) AS schedule_obj
        FROM public.device_schedules s
        WHERE s.school_id = p_school_id
          AND (p_search IS NULL OR p_search = '' OR s.name ILIKE '%' || p_search || '%' OR s.schedule_code ILIKE '%' || p_search || '%' OR s.target_name ILIKE '%' || p_search || '%')
          AND (
              p_status IS NULL OR p_status = '' OR p_status = 'all' 
              OR (p_status = 'active' AND (s.status = 'active' OR s.is_active = true))
              OR (p_status = 'paused' AND (s.status = 'paused' OR s.is_active = false))
              OR (s.status ILIKE p_status)
          )
          AND (p_target_type IS NULL OR p_target_type = '' OR p_target_type = 'all' OR s.target_type ILIKE p_target_type)
          AND (p_operation_type IS NULL OR p_operation_type = '' OR p_operation_type = 'all' OR s.operation_type ILIKE p_operation_type)
        ORDER BY
            CASE WHEN p_sort_by = 'name' AND p_sort_dir = 'asc' THEN s.name END ASC,
            CASE WHEN p_sort_by = 'name' AND p_sort_dir = 'desc' THEN s.name END DESC,
            CASE WHEN p_sort_by = 'schedule_code' AND p_sort_dir = 'asc' THEN s.schedule_code END ASC,
            CASE WHEN p_sort_by = 'schedule_code' AND p_sort_dir = 'desc' THEN s.schedule_code END DESC,
            CASE WHEN p_sort_by = 'status' AND p_sort_dir = 'asc' THEN s.status END ASC,
            CASE WHEN p_sort_by = 'status' AND p_sort_dir = 'desc' THEN s.status END DESC,
            CASE WHEN p_sort_by = 'next_run_at' AND p_sort_dir = 'asc' THEN s.next_run_at END ASC,
            CASE WHEN p_sort_by = 'next_run_at' AND p_sort_dir = 'desc' THEN s.next_run_at END DESC,
            CASE WHEN p_sort_dir = 'asc' THEN s.created_at END ASC,
            s.created_at DESC
        LIMIT GREATEST(COALESCE(p_page_size, 10), 1)
        OFFSET v_offset
    ) sub;

    RETURN jsonb_build_object(
        'items', v_items,
        'total', v_total,
        'page', COALESCE(p_page, 1),
        'page_size', GREATEST(COALESCE(p_page_size, 10), 1),
        'total_pages', v_total_pages
    );
END;
$$;


-- 1.3 Create Schedule Procedure
CREATE OR REPLACE FUNCTION public.sp_create_device_schedule(
    p_school_id UUID,
    p_name TEXT,
    p_description TEXT DEFAULT NULL,
    p_operation_type TEXT DEFAULT 'turn_on_off',
    p_operation_value JSONB DEFAULT '{}'::jsonb,
    p_target_type TEXT DEFAULT 'devices',
    p_target_name TEXT DEFAULT 'All Devices',
    p_target_count INT DEFAULT 1,
    p_target_ids UUID[] DEFAULT '{}'::uuid[],
    p_recurrence_type TEXT DEFAULT 'daily',
    p_recurrence_label TEXT DEFAULT 'Daily',
    p_time_window_label TEXT DEFAULT '07:00 AM - 06:00 PM',
    p_validity_label TEXT DEFAULT '01 Jan 2025 - No End Date',
    p_start_time TIME DEFAULT '07:00:00',
    p_end_time TIME DEFAULT '18:00:00',
    p_days_of_week INT[] DEFAULT ARRAY[1,2,3,4,5],
    p_user_name TEXT DEFAULT 'Admin'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_code VARCHAR(50);
    v_count INT;
    v_id UUID;
    v_next_run TIMESTAMPTZ := now() + interval '1 day';
BEGIN
    SELECT COUNT(*) + 1 INTO v_count FROM public.device_schedules WHERE school_id = p_school_id;
    v_code := 'SCH-' || LPAD(v_count::TEXT, 3, '0');

    INSERT INTO public.device_schedules (
        school_id,
        schedule_code,
        name,
        description,
        operation_type,
        operation_value,
        target_type,
        target_name,
        target_count,
        target_ids,
        recurrence_type,
        recurrence_label,
        time_window_label,
        validity_label,
        start_time,
        end_time,
        days_of_week,
        next_run_at,
        status,
        is_active,
        created_by_name,
        created_at,
        updated_at
    ) VALUES (
        p_school_id,
        v_code,
        p_name,
        p_description,
        p_operation_type,
        p_operation_value,
        p_target_type,
        p_target_name,
        p_target_count,
        p_target_ids,
        p_recurrence_type,
        p_recurrence_label,
        p_time_window_label,
        p_validity_label,
        p_start_time,
        p_end_time,
        p_days_of_week,
        v_next_run,
        'active',
        true,
        p_user_name,
        now(),
        now()
    ) RETURNING id INTO v_id;

    RETURN jsonb_build_object(
        'success', true,
        'id', v_id,
        'schedule_code', v_code,
        'name', p_name,
        'status', 'active'
    );
END;
$$;


-- 1.4 Update Schedule Procedure
CREATE OR REPLACE FUNCTION public.sp_update_device_schedule(
    p_school_id UUID,
    p_schedule_id UUID,
    p_name TEXT DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_operation_type TEXT DEFAULT NULL,
    p_operation_value JSONB DEFAULT NULL,
    p_target_type TEXT DEFAULT NULL,
    p_target_name TEXT DEFAULT NULL,
    p_target_count INT DEFAULT NULL,
    p_recurrence_type TEXT DEFAULT NULL,
    p_recurrence_label TEXT DEFAULT NULL,
    p_time_window_label TEXT DEFAULT NULL,
    p_validity_label TEXT DEFAULT NULL,
    p_status TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.device_schedules
    SET
        name = COALESCE(p_name, name),
        description = COALESCE(p_description, description),
        operation_type = COALESCE(p_operation_type, operation_type),
        operation_value = COALESCE(p_operation_value, operation_value),
        target_type = COALESCE(p_target_type, target_type),
        target_name = COALESCE(p_target_name, target_name),
        target_count = COALESCE(p_target_count, target_count),
        recurrence_type = COALESCE(p_recurrence_type, recurrence_type),
        recurrence_label = COALESCE(p_recurrence_label, recurrence_label),
        time_window_label = COALESCE(p_time_window_label, time_window_label),
        validity_label = COALESCE(p_validity_label, validity_label),
        status = COALESCE(p_status, status),
        is_active = CASE 
            WHEN p_status = 'paused' THEN false 
            WHEN p_status = 'active' THEN true 
            ELSE is_active 
        END,
        updated_at = now()
    WHERE id = p_schedule_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Schedule not found');
    END IF;

    RETURN jsonb_build_object('success', true, 'id', p_schedule_id);
END;
$$;


-- 1.5 Delete Schedule Procedure
CREATE OR REPLACE FUNCTION public.sp_delete_device_schedule(
    p_school_id UUID,
    p_schedule_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    DELETE FROM public.device_schedules
    WHERE id = p_schedule_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Schedule not found');
    END IF;

    RETURN jsonb_build_object('success', true, 'id', p_schedule_id);
END;
$$;


-- 1.6 Toggle Schedule Active / Paused
CREATE OR REPLACE FUNCTION public.sp_toggle_device_schedule(
    p_school_id UUID,
    p_schedule_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_curr_status VARCHAR(50);
    v_new_status VARCHAR(50);
    v_is_active BOOLEAN;
BEGIN
    SELECT status INTO v_curr_status
    FROM public.device_schedules
    WHERE id = p_schedule_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Schedule not found');
    END IF;

    IF v_curr_status = 'paused' THEN
        v_new_status := 'active';
        v_is_active := true;
    ELSE
        v_new_status := 'paused';
        v_is_active := false;
    END IF;

    UPDATE public.device_schedules
    SET status = v_new_status,
        is_active = v_is_active,
        updated_at = now()
    WHERE id = p_schedule_id AND school_id = p_school_id;

    RETURN jsonb_build_object(
        'success', true,
        'id', p_schedule_id,
        'status', v_new_status,
        'is_active', v_is_active
    );
END;
$$;


-- 1.7 Bulk Action on Selected Schedules
CREATE OR REPLACE FUNCTION public.sp_bulk_device_schedules_action(
    p_school_id UUID,
    p_schedule_ids UUID[],
    p_action TEXT,
    p_user_name TEXT DEFAULT 'Admin'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_affected INT := 0;
    v_sched RECORD;
    v_exec_code VARCHAR(50);
    v_exec_ids UUID[] := '{}'::uuid[];
BEGIN
    IF p_schedule_ids IS NULL OR array_length(p_schedule_ids, 1) = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'No schedule IDs provided');
    END IF;

    IF p_action = 'activate' THEN
        UPDATE public.device_schedules
        SET status = 'active',
            is_active = true,
            updated_at = now()
        WHERE school_id = p_school_id AND id = ANY(p_schedule_ids);
        GET DIAGNOSTICS v_affected = ROW_COUNT;

    ELSIF p_action = 'pause' OR p_action = 'deactivate' THEN
        UPDATE public.device_schedules
        SET status = 'paused',
            is_active = false,
            updated_at = now()
        WHERE school_id = p_school_id AND id = ANY(p_schedule_ids);
        GET DIAGNOSTICS v_affected = ROW_COUNT;

    ELSIF p_action = 'delete' THEN
        DELETE FROM public.device_schedules
        WHERE school_id = p_school_id AND id = ANY(p_schedule_ids);
        GET DIAGNOSTICS v_affected = ROW_COUNT;

    ELSIF p_action = 'run_now' OR p_action = 'execute' THEN
        FOR v_sched IN
            SELECT * FROM public.device_schedules
            WHERE school_id = p_school_id AND id = ANY(p_schedule_ids)
        LOOP
            v_exec_code := 'BULK-RUN-' || to_char(now(), 'YYYYMMDD-HH24MISS') || '-' || SUBSTRING(v_sched.id::text, 1, 4);

            INSERT INTO public.device_schedule_executions (
                school_id,
                schedule_id,
                execution_code,
                trigger_time,
                action_executed,
                status,
                affected_devices_count,
                success_count,
                failed_count,
                log_details
            ) VALUES (
                p_school_id,
                v_sched.id,
                v_exec_code,
                now(),
                COALESCE(v_sched.operation_type, 'turn_on_off'),
                'success',
                COALESCE(v_sched.target_count, 1),
                COALESCE(v_sched.target_count, 1),
                0,
                jsonb_build_object(
                    'bulk_trigger_by', p_user_name,
                    'schedule_name', v_sched.name,
                    'target_name', v_sched.target_name
                )
            );

            UPDATE public.device_schedules
            SET last_run_at = now(),
                last_status = 'success',
                updated_at = now()
            WHERE id = v_sched.id;

            v_affected := v_affected + 1;
        END LOOP;
    ELSE
        RETURN jsonb_build_object('success', false, 'error', 'Invalid bulk action: ' || p_action);
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'action', p_action,
        'affected_count', v_affected
    );
END;
$$;


-- ====================================================================
-- PART 2: SCENES & PRESETS STORED PROCEDURES & FUNCTIONS
-- ====================================================================

-- 2.1 KPI Calculation for Scenes & Presets
CREATE OR REPLACE FUNCTION public.fn_device_scenes_kpis(p_school_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_scenes INT := 0;
    v_active_scenes INT := 0;
    v_disabled_scenes INT := 0;
    v_active_pct NUMERIC := 0;
    v_disabled_pct NUMERIC := 0;
    v_total_presets INT := 0;
    v_automations_count INT := 0;
    v_schedules_count INT := 0;
    v_popular JSONB := '[]'::JSONB;
    v_total_exec_30d INT := 0;
BEGIN
    SELECT 
        COUNT(*) FILTER (WHERE scene_type = 'scene' OR scene_type IS NULL),
        COUNT(*) FILTER (WHERE (scene_type = 'scene' OR scene_type IS NULL) AND (status = 'active' OR is_active = true)),
        COUNT(*) FILTER (WHERE (scene_type = 'scene' OR scene_type IS NULL) AND (status = 'disabled' OR is_active = false)),
        COUNT(*) FILTER (WHERE scene_type = 'preset'),
        COALESCE(SUM(used_in_automations_count), 0),
        COALESCE(SUM(used_in_schedules_count), 0)
    INTO v_total_scenes, v_active_scenes, v_disabled_scenes, v_total_presets, v_automations_count, v_schedules_count
    FROM public.device_scenes
    WHERE school_id = p_school_id;

    IF v_total_scenes > 0 THEN
        v_active_pct := ROUND((v_active_scenes::NUMERIC / v_total_scenes::NUMERIC) * 100, 1);
        v_disabled_pct := ROUND((v_disabled_scenes::NUMERIC / v_total_scenes::NUMERIC) * 100, 1);
    END IF;

    -- Popular scenes
    SELECT COALESCE(jsonb_agg(sub.item), '[]'::JSONB)
    INTO v_popular
    FROM (
        SELECT jsonb_build_object(
            'id', s.id,
            'scene_code', COALESCE(s.scene_code, s.code, 'SCN-001'),
            'name', s.name,
            'target_name', COALESCE(s.target_name, '8 devices'),
            'target_count', COALESCE(s.target_count, 8),
            'icon', COALESCE(s.icon, 'wb_sunny_rounded'),
            'color', COALESCE(s.color, '#2563EB')
        ) AS item
        FROM public.device_scenes s
        WHERE s.school_id = p_school_id
        ORDER BY s.execution_count DESC NULLS LAST, s.created_at ASC
        LIMIT 6
    ) sub;

    -- Executions in last 30 days
    SELECT COUNT(*)
    INTO v_total_exec_30d
    FROM public.device_scene_executions
    WHERE school_id = p_school_id
      AND executed_at >= now() - interval '30 days';

    RETURN jsonb_build_object(
        'total_scenes', v_total_scenes,
        'active_scenes', v_active_scenes,
        'active_percentage', v_active_pct,
        'disabled_scenes', v_disabled_scenes,
        'disabled_percentage', v_disabled_pct,
        'total_presets', v_total_presets,
        'used_in_automations', v_automations_count,
        'used_in_schedules', v_schedules_count,
        'popular_scenes', v_popular,
        'usage_stats', jsonb_build_object(
            'total_executions_30d', GREATEST(v_total_exec_30d, 0)
        )
    );
END;
$$;


-- 2.2 Paginated, Filtered, and Sorted Scenes List
CREATE OR REPLACE FUNCTION public.fn_list_device_scenes(
    p_school_id UUID,
    p_scene_type TEXT DEFAULT 'scene',
    p_search TEXT DEFAULT NULL,
    p_category TEXT DEFAULT NULL,
    p_status TEXT DEFAULT NULL,
    p_sort_by TEXT DEFAULT 'created_at',
    p_sort_dir TEXT DEFAULT 'desc',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_offset INT := 0;
    v_total INT := 0;
    v_total_pages INT := 1;
    v_items JSONB := '[]'::JSONB;
BEGIN
    v_offset := GREATEST((COALESCE(p_page, 1) - 1) * GREATEST(COALESCE(p_page_size, 10), 1), 0);

    SELECT COUNT(*)
    INTO v_total
    FROM public.device_scenes s
    WHERE s.school_id = p_school_id
      AND (
          p_scene_type IS NULL OR p_scene_type = '' OR p_scene_type = 'all'
          OR (p_scene_type = 'scene' AND (s.scene_type = 'scene' OR s.scene_type IS NULL))
          OR (p_scene_type = 'preset' AND s.scene_type = 'preset')
          OR (s.scene_type ILIKE p_scene_type)
      )
      AND (p_search IS NULL OR p_search = '' OR s.name ILIKE '%' || p_search || '%' OR s.scene_code ILIKE '%' || p_search || '%' OR s.description ILIKE '%' || p_search || '%')
      AND (p_category IS NULL OR p_category = '' OR p_category = 'all' OR s.category ILIKE p_category)
      AND (
          p_status IS NULL OR p_status = '' OR p_status = 'all'
          OR (p_status = 'active' AND (s.status = 'active' OR s.is_active = true))
          OR (p_status = 'disabled' AND (s.status = 'disabled' OR s.is_active = false))
          OR (s.status ILIKE p_status)
      );

    v_total_pages := GREATEST(CEIL(v_total::NUMERIC / GREATEST(COALESCE(p_page_size, 10), 1)::NUMERIC)::INT, 1);

    SELECT COALESCE(jsonb_agg(sub.scene_obj), '[]'::JSONB)
    INTO v_items
    FROM (
        SELECT jsonb_build_object(
            'id', s.id,
            'school_id', s.school_id,
            'scene_code', COALESCE(s.scene_code, s.code, 'SCN-' || SUBSTRING(s.id::text, 1, 6)),
            'name', s.name,
            'description', COALESCE(s.description, ''),
            'category', COALESCE(s.category, 'academic'),
            'scene_type', COALESCE(s.scene_type, 'scene'),
            'target_type', COALESCE(s.target_type, 'devices'),
            'target_name', COALESCE(s.target_name, '8 devices'),
            'target_count', COALESCE(s.target_count, 8),
            'target_ids', COALESCE(to_jsonb(s.target_ids), '[]'::jsonb),
            'location_scope', COALESCE(s.location_scope, 'Classroom / Academic Block'),
            'tags', COALESCE(to_jsonb(s.tags), '[]'::jsonb),
            'icon', COALESCE(s.icon, 'wb_sunny_rounded'),
            'color', COALESCE(s.color, '#2563EB'),
            'status', COALESCE(s.status, CASE WHEN s.is_active = false THEN 'disabled' ELSE 'active' END),
            'is_active', COALESCE(s.is_active, true),
            'is_preset', COALESCE(s.is_preset, false),
            'is_popular', COALESCE(s.is_popular, false),
            'steps', COALESCE(s.steps, '[]'::jsonb),
            'execution_count', COALESCE(s.execution_count, 0),
            'used_in_automations_count', COALESCE(s.used_in_automations_count, 0),
            'used_in_schedules_count', COALESCE(s.used_in_schedules_count, 0),
            'last_applied_at', s.last_applied_at,
            'created_by_name', COALESCE(s.created_by_name, 'Admin'),
            'created_at', s.created_at,
            'updated_at', s.updated_at
        ) AS scene_obj
        FROM public.device_scenes s
        WHERE s.school_id = p_school_id
          AND (
              p_scene_type IS NULL OR p_scene_type = '' OR p_scene_type = 'all'
              OR (p_scene_type = 'scene' AND (s.scene_type = 'scene' OR s.scene_type IS NULL))
              OR (p_scene_type = 'preset' AND s.scene_type = 'preset')
              OR (s.scene_type ILIKE p_scene_type)
          )
          AND (p_search IS NULL OR p_search = '' OR s.name ILIKE '%' || p_search || '%' OR s.scene_code ILIKE '%' || p_search || '%' OR s.description ILIKE '%' || p_search || '%')
          AND (p_category IS NULL OR p_category = '' OR p_category = 'all' OR s.category ILIKE p_category)
          AND (
              p_status IS NULL OR p_status = '' OR p_status = 'all'
              OR (p_status = 'active' AND (s.status = 'active' OR s.is_active = true))
              OR (p_status = 'disabled' AND (s.status = 'disabled' OR s.is_active = false))
              OR (s.status ILIKE p_status)
          )
        ORDER BY
            CASE WHEN p_sort_by = 'name' AND p_sort_dir = 'asc' THEN s.name END ASC,
            CASE WHEN p_sort_by = 'name' AND p_sort_dir = 'desc' THEN s.name END DESC,
            CASE WHEN p_sort_by = 'scene_code' AND p_sort_dir = 'asc' THEN s.scene_code END ASC,
            CASE WHEN p_sort_by = 'scene_code' AND p_sort_dir = 'desc' THEN s.scene_code END DESC,
            CASE WHEN p_sort_by = 'execution_count' AND p_sort_dir = 'asc' THEN s.execution_count END ASC,
            CASE WHEN p_sort_by = 'execution_count' AND p_sort_dir = 'desc' THEN s.execution_count END DESC,
            CASE WHEN p_sort_by = 'status' AND p_sort_dir = 'asc' THEN s.status END ASC,
            CASE WHEN p_sort_by = 'status' AND p_sort_dir = 'desc' THEN s.status END DESC,
            CASE WHEN p_sort_dir = 'asc' THEN s.created_at END ASC,
            s.created_at DESC
        LIMIT GREATEST(COALESCE(p_page_size, 10), 1)
        OFFSET v_offset
    ) sub;

    RETURN jsonb_build_object(
        'items', v_items,
        'total', v_total,
        'page', COALESCE(p_page, 1),
        'page_size', GREATEST(COALESCE(p_page_size, 10), 1),
        'total_pages', v_total_pages
    );
END;
$$;


-- 2.3 Create Scene / Preset Procedure
CREATE OR REPLACE FUNCTION public.sp_create_device_scene(
    p_school_id UUID,
    p_name TEXT,
    p_description TEXT DEFAULT NULL,
    p_category TEXT DEFAULT 'academic',
    p_scene_type TEXT DEFAULT 'scene',
    p_target_type TEXT DEFAULT 'devices',
    p_target_name TEXT DEFAULT '8 devices',
    p_target_count INT DEFAULT 8,
    p_target_ids UUID[] DEFAULT '{}'::uuid[],
    p_location_scope TEXT DEFAULT 'Classroom / Academic Block',
    p_tags TEXT[] DEFAULT ARRAY['Academic', 'Classroom'],
    p_icon TEXT DEFAULT 'wb_sunny_rounded',
    p_color TEXT DEFAULT '#2563EB',
    p_steps JSONB DEFAULT '[]'::jsonb,
    p_user_name TEXT DEFAULT 'Admin'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_code VARCHAR(50);
    v_count INT;
    v_id UUID;
    v_prefix VARCHAR(10) := CASE WHEN p_scene_type = 'preset' THEN 'PST-' ELSE 'SCN-' END;
BEGIN
    SELECT COUNT(*) + 1 INTO v_count 
    FROM public.device_scenes 
    WHERE school_id = p_school_id AND (scene_type = p_scene_type OR (p_scene_type = 'scene' AND scene_type IS NULL));
    
    v_code := v_prefix || LPAD(v_count::TEXT, 3, '0');

    INSERT INTO public.device_scenes (
        school_id,
        scene_code,
        code,
        name,
        description,
        category,
        scene_type,
        target_type,
        target_name,
        target_count,
        target_ids,
        location_scope,
        tags,
        icon,
        color,
        steps,
        status,
        is_active,
        is_preset,
        created_by_name,
        created_at,
        updated_at
    ) VALUES (
        p_school_id,
        v_code,
        v_code,
        p_name,
        p_description,
        p_category,
        p_scene_type,
        p_target_type,
        p_target_name,
        p_target_count,
        p_target_ids,
        p_location_scope,
        p_tags,
        p_icon,
        p_color,
        p_steps,
        'active',
        true,
        (p_scene_type = 'preset'),
        p_user_name,
        now(),
        now()
    ) RETURNING id INTO v_id;

    RETURN jsonb_build_object(
        'success', true,
        'id', v_id,
        'scene_code', v_code,
        'name', p_name,
        'status', 'active'
    );
END;
$$;


-- 2.4 Update Scene / Preset Procedure
CREATE OR REPLACE FUNCTION public.sp_update_device_scene(
    p_school_id UUID,
    p_scene_id UUID,
    p_name TEXT DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_category TEXT DEFAULT NULL,
    p_target_type TEXT DEFAULT NULL,
    p_target_name TEXT DEFAULT NULL,
    p_target_count INT DEFAULT NULL,
    p_location_scope TEXT DEFAULT NULL,
    p_tags TEXT[] DEFAULT NULL,
    p_icon TEXT DEFAULT NULL,
    p_color TEXT DEFAULT NULL,
    p_steps JSONB DEFAULT NULL,
    p_status TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.device_scenes
    SET
        name = COALESCE(p_name, name),
        description = COALESCE(p_description, description),
        category = COALESCE(p_category, category),
        target_type = COALESCE(p_target_type, target_type),
        target_name = COALESCE(p_target_name, target_name),
        target_count = COALESCE(p_target_count, target_count),
        location_scope = COALESCE(p_location_scope, location_scope),
        tags = COALESCE(p_tags, tags),
        icon = COALESCE(p_icon, icon),
        color = COALESCE(p_color, color),
        steps = COALESCE(p_steps, steps),
        status = COALESCE(p_status, status),
        is_active = CASE 
            WHEN p_status = 'disabled' THEN false 
            WHEN p_status = 'active' THEN true 
            ELSE is_active 
        END,
        updated_at = now()
    WHERE id = p_scene_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Scene or Preset not found');
    END IF;

    RETURN jsonb_build_object('success', true, 'id', p_scene_id);
END;
$$;


-- 2.5 Delete Scene / Preset Procedure
CREATE OR REPLACE FUNCTION public.sp_delete_device_scene(
    p_school_id UUID,
    p_scene_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    DELETE FROM public.device_scenes
    WHERE id = p_scene_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Scene or Preset not found');
    END IF;

    RETURN jsonb_build_object('success', true, 'id', p_scene_id);
END;
$$;


-- 2.6 Toggle Scene / Preset Status Procedure
CREATE OR REPLACE FUNCTION public.sp_toggle_device_scene_status(
    p_school_id UUID,
    p_scene_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_curr_status VARCHAR(50);
    v_new_status VARCHAR(50);
    v_is_active BOOLEAN;
BEGIN
    SELECT status INTO v_curr_status
    FROM public.device_scenes
    WHERE id = p_scene_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Scene or Preset not found');
    END IF;

    IF v_curr_status = 'disabled' THEN
        v_new_status := 'active';
        v_is_active := true;
    ELSE
        v_new_status := 'disabled';
        v_is_active := false;
    END IF;

    UPDATE public.device_scenes
    SET status = v_new_status,
        is_active = v_is_active,
        updated_at = now()
    WHERE id = p_scene_id AND school_id = p_school_id;

    RETURN jsonb_build_object(
        'success', true,
        'id', p_scene_id,
        'status', v_new_status,
        'is_active', v_is_active
    );
END;
$$;


-- 2.7 Duplicate Scene / Preset Procedure
CREATE OR REPLACE FUNCTION public.sp_duplicate_device_scene(
    p_school_id UUID,
    p_scene_id UUID,
    p_user_name TEXT DEFAULT 'Admin'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_orig RECORD;
    v_new_id UUID;
    v_new_code VARCHAR(50);
    v_count INT;
BEGIN
    SELECT * INTO v_orig FROM public.device_scenes WHERE id = p_scene_id AND school_id = p_school_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Scene or Preset not found');
    END IF;

    SELECT COUNT(*) + 1 INTO v_count 
    FROM public.device_scenes 
    WHERE school_id = p_school_id AND (scene_type = v_orig.scene_type OR (v_orig.scene_type = 'scene' AND scene_type IS NULL));

    v_new_code := CASE WHEN v_orig.scene_type = 'preset' THEN 'PST-' ELSE 'SCN-' END || LPAD(v_count::TEXT, 3, '0');

    INSERT INTO public.device_scenes (
        school_id,
        scene_code,
        code,
        name,
        description,
        category,
        scene_type,
        target_type,
        target_name,
        target_count,
        target_ids,
        location_scope,
        tags,
        icon,
        color,
        steps,
        status,
        is_active,
        is_preset,
        created_by_name,
        created_at,
        updated_at
    ) VALUES (
        p_school_id,
        v_new_code,
        v_new_code,
        v_orig.name || ' (Copy)',
        v_orig.description,
        v_orig.category,
        v_orig.scene_type,
        v_orig.target_type,
        v_orig.target_name,
        v_orig.target_count,
        v_orig.target_ids,
        v_orig.location_scope,
        v_orig.tags,
        v_orig.icon,
        v_orig.color,
        v_orig.steps,
        'active',
        true,
        v_orig.is_preset,
        p_user_name,
        now(),
        now()
    ) RETURNING id INTO v_new_id;

    RETURN jsonb_build_object(
        'success', true,
        'new_scene_id', v_new_id,
        'new_scene_code', v_new_code
    );
END;
$$;


-- 2.8 Bulk Action on Selected Scenes & Presets
CREATE OR REPLACE FUNCTION public.sp_bulk_device_scenes_action(
    p_school_id UUID,
    p_scene_ids UUID[],
    p_action TEXT,
    p_user_name TEXT DEFAULT 'Admin'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_affected INT := 0;
    v_scn RECORD;
    v_exec_code VARCHAR(50);
BEGIN
    IF p_scene_ids IS NULL OR array_length(p_scene_ids, 1) = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'No scene IDs provided');
    END IF;

    IF p_action = 'activate' THEN
        UPDATE public.device_scenes
        SET status = 'active',
            is_active = true,
            updated_at = now()
        WHERE school_id = p_school_id AND id = ANY(p_scene_ids);
        GET DIAGNOSTICS v_affected = ROW_COUNT;

    ELSIF p_action = 'deactivate' OR p_action = 'disable' OR p_action = 'pause' THEN
        UPDATE public.device_scenes
        SET status = 'disabled',
            is_active = false,
            updated_at = now()
        WHERE school_id = p_school_id AND id = ANY(p_scene_ids);
        GET DIAGNOSTICS v_affected = ROW_COUNT;

    ELSIF p_action = 'delete' THEN
        DELETE FROM public.device_scenes
        WHERE school_id = p_school_id AND id = ANY(p_scene_ids);
        GET DIAGNOSTICS v_affected = ROW_COUNT;

    ELSIF p_action = 'run_now' OR p_action = 'execute' OR p_action = 'trigger_all' THEN
        FOR v_scn IN
            SELECT * FROM public.device_scenes
            WHERE school_id = p_school_id AND id = ANY(p_scene_ids)
        LOOP
            v_exec_code := 'BULK-SCN-' || to_char(now(), 'YYYYMMDD-HH24MISS') || '-' || SUBSTRING(v_scn.id::text, 1, 4);

            INSERT INTO public.device_scene_executions (
                school_id,
                scene_id,
                execution_code,
                executed_at,
                executed_by_name,
                status,
                duration_ms,
                affected_devices_count,
                success_count,
                failed_count,
                steps_executed,
                log_details
            ) VALUES (
                p_school_id,
                v_scn.id,
                v_exec_code,
                now(),
                p_user_name,
                'success',
                350,
                COALESCE(v_scn.target_count, 8),
                COALESCE(v_scn.target_count, 8),
                0,
                COALESCE(v_scn.steps, '[]'::jsonb),
                jsonb_build_object(
                    'bulk_trigger_by', p_user_name,
                    'scene_name', v_scn.name,
                    'category', v_scn.category
                )
            );

            UPDATE public.device_scenes
            SET execution_count = COALESCE(execution_count, 0) + 1,
                last_applied_at = now(),
                updated_at = now()
            WHERE id = v_scn.id;

            v_affected := v_affected + 1;
        END LOOP;
    ELSE
        RETURN jsonb_build_object('success', false, 'error', 'Invalid bulk action: ' || p_action);
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'action', p_action,
        'affected_count', v_affected
    );
END;
$$;
