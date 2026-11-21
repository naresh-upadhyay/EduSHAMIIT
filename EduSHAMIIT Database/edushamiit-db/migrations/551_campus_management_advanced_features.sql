-- ============================================================================
-- Migration 551: Campus Management Advanced Features & Automated Workflows
-- 1. Preventive Maintenance Automated Work Order Generator
-- 2. Safety & Compliance -> IoT Emergency Evacuation Interlock
-- 3. Utility Anomaly Detection & Auto-Ticket Generation
-- ============================================================================

-- 1. PREVENTIVE MAINTENANCE AUTOMATED WORK ORDER GENERATOR
CREATE OR REPLACE FUNCTION public.sp_generate_due_preventive_maintenance_tickets(p_school_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
AS $function$
DECLARE
    v_plan RECORD;
    v_generated_count INT := 0;
    v_new_req_id UUID;
    v_req_code VARCHAR(50);
    v_seq INT;
    v_next_due DATE;
    v_generated_records JSONB := '[]'::JSONB;
BEGIN
    FOR v_plan IN 
        SELECT mp.*, b.name AS building_name, r.room_number, re.equipment_name
        FROM public.maintenance_plans mp
        LEFT JOIN public.buildings b ON b.id = mp.building_id
        LEFT JOIN public.rooms r ON r.id = mp.room_id
        LEFT JOIN public.room_equipment re ON re.id = mp.equipment_id
        WHERE mp.school_id = p_school_id
          AND mp.is_active = TRUE
          AND mp.next_due_date <= CURRENT_DATE
    LOOP
        -- Check if an active open ticket for this plan already exists (avoid duplicates)
        IF NOT EXISTS (
            SELECT 1 FROM public.maintenance_requests
            WHERE school_id = p_school_id
              AND plan_id = v_plan.id
              AND status IN ('Pending', 'Assigned', 'In Progress', 'Scheduled')
              AND deleted_at IS NULL
        ) THEN
            SELECT COUNT(*) + 1 INTO v_seq FROM public.maintenance_requests WHERE school_id = p_school_id;
            v_req_code := 'MT-PRV-' || TO_CHAR(CURRENT_DATE, 'YYMM') || '-' || LPAD(v_seq::TEXT, 4, '0');
            v_new_req_id := gen_random_uuid();

            INSERT INTO public.maintenance_requests (
                id,
                school_id,
                request_code,
                title,
                description,
                request_type,
                priority,
                status,
                building_id,
                room_id,
                equipment_id,
                location_display,
                reported_by_name,
                reported_by_role,
                reported_by_user_id,
                reported_at,
                due_date,
                is_preventive,
                plan_id,
                assigned_to_name,
                assigned_to_user_id,
                estimated_cost,
                scheduled_at
            ) VALUES (
                v_new_req_id,
                p_school_id,
                v_req_code,
                v_plan.title,
                'Auto-generated scheduled preventive maintenance for ' || v_plan.title || '. Frequency: ' || v_plan.frequency,
                v_plan.category,
                'Medium',
                'Scheduled',
                v_plan.building_id,
                v_plan.room_id,
                v_plan.equipment_id,
                COALESCE(v_plan.building_name || ' / Room ' || v_plan.room_number, v_plan.building_name, 'Campus Infrastructure'),
                'Automated Plan Scheduler',
                'System Admin',
                '00000000-0000-0000-0000-000000000001'::UUID,
                NOW(),
                CURRENT_DATE + INTERVAL '7 days',
                TRUE,
                v_plan.id,
                v_plan.assigned_technician_name,
                v_plan.assigned_technician_id,
                v_plan.estimated_cost,
                NOW()
            );

            v_generated_count := v_generated_count + 1;
            v_generated_records := v_generated_records || jsonb_build_object(
                'id', v_new_req_id,
                'request_code', v_req_code,
                'plan_code', v_plan.plan_code,
                'title', v_plan.title
            );
        END IF;

        -- Calculate next due date according to frequency
        v_next_due := CASE LOWER(v_plan.frequency)
            WHEN 'daily' THEN CURRENT_DATE + INTERVAL '1 day'
            WHEN 'weekly' THEN CURRENT_DATE + INTERVAL '7 days'
            WHEN 'biweekly' THEN CURRENT_DATE + INTERVAL '14 days'
            WHEN 'bi-weekly' THEN CURRENT_DATE + INTERVAL '14 days'
            WHEN 'monthly' THEN CURRENT_DATE + INTERVAL '1 month'
            WHEN 'bi-monthly' THEN CURRENT_DATE + INTERVAL '2 months'
            WHEN 'bimonthly' THEN CURRENT_DATE + INTERVAL '2 months'
            WHEN 'quarterly' THEN CURRENT_DATE + INTERVAL '3 months'
            WHEN 'biannually' THEN CURRENT_DATE + INTERVAL '6 months'
            WHEN 'annually' THEN CURRENT_DATE + INTERVAL '1 year'
            ELSE CURRENT_DATE + INTERVAL '1 month'
        END;

        UPDATE public.maintenance_plans
        SET last_run_date = CURRENT_DATE,
            next_due_date = v_next_due,
            updated_at = NOW()
        WHERE id = v_plan.id;
    END LOOP;

    RETURN jsonb_build_object(
        'success', TRUE,
        'generated_count', v_generated_count,
        'records', v_generated_records
    );
END;
$function$;


-- 2. SAFETY INCIDENT -> IOT EMERGENCY OVERRIDE INTERLOCK
-- Ensure Emergency Evacuation Scene exists in device_scenes
INSERT INTO public.device_scenes (
    id, school_id, name, code, scene_code, description, icon, color, is_preset, is_active, category, scene_type
) VALUES (
    '88888888-8888-8888-8888-888888888888',
    '11111111-1111-1111-1111-111111111111',
    'Emergency Evacuation',
    'scn_emergency_evacuation',
    'SCN-EMG-01',
    'Automated Life Safety Override: Disables magnetic door locks, opens exit gates, trips HVAC dampers, enables emergency lighting and campus sirens.',
    'emergency_share',
    '#EF4444',
    TRUE,
    TRUE,
    'emergency',
    'safety_override'
)
ON CONFLICT (school_id, code) DO NOTHING;

CREATE OR REPLACE FUNCTION public.sp_trigger_emergency_safety_interlock(
    p_school_id UUID,
    p_incident_id UUID,
    p_triggered_by TEXT DEFAULT 'Safety Officer'
)
RETURNS JSONB
LANGUAGE plpgsql
AS $function$
DECLARE
    v_incident RECORD;
    v_doors_unlocked INT := 0;
    v_hvac_stopped INT := 0;
    v_alarms_triggered INT := 0;
    v_audit_id UUID;
BEGIN
    SELECT * INTO v_incident
    FROM public.safety_incidents
    WHERE id = p_incident_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Safety incident not found.');
    END IF;

    -- Update smart doors to unlocked for safe evacuation
    UPDATE public.devices
    SET state = 'unlocked', is_online = TRUE, updated_at = NOW()
    WHERE school_id = p_school_id
      AND device_type IN ('Smart Door Lock', 'Access Control', 'Turnstile', 'Barrier Gate');
    GET DIAGNOSTICS v_doors_unlocked = ROW_COUNT;

    -- Cut/stop non-essential ventilation & HVAC fans to prevent smoke propagation
    UPDATE public.devices
    SET state = 'off', updated_at = NOW()
    WHERE school_id = p_school_id
      AND device_type IN ('HVAC Controller', 'Exhaust Fan', 'Air Conditioner');
    GET DIAGNOSTICS v_hvac_stopped = ROW_COUNT;

    -- Trip sirens and emergency beacon strobes
    UPDATE public.devices
    SET state = 'active', updated_at = NOW()
    WHERE school_id = p_school_id
      AND device_type IN ('Emergency Siren', 'Alarm Strobe', 'Campus PA System');
    GET DIAGNOSTICS v_alarms_triggered = ROW_COUNT;

    -- Record in device audit logs if table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'device_audit_logs') THEN
        INSERT INTO public.device_audit_logs (
            school_id, action, target_type, target_name, details, actor_name, severity
        ) VALUES (
            p_school_id,
            'EMERGENCY_SAFETY_OVERRIDE_TRIGGERED',
            'Campus-Wide IoT Infrastructure',
            'Life Safety Interlock',
            jsonb_build_object(
                'incident_code', v_incident.incident_code,
                'incident_type', v_incident.incident_type,
                'doors_unlocked', v_doors_unlocked,
                'hvac_stopped', v_hvac_stopped,
                'alarms_triggered', v_alarms_triggered
            ),
            p_triggered_by,
            'Critical'
        );
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Emergency Life Safety Interlock Dispatched Successfully',
        'doors_unlocked', v_doors_unlocked,
        'hvac_units_stopped', v_hvac_stopped,
        'alarm_beacons_active', v_alarms_triggered,
        'incident_code', v_incident.incident_code
    );
END;
$function$;


-- 3. UTILITY ANOMALY DETECTION & AUTOMATED WORK ORDER ESCALATION
CREATE OR REPLACE FUNCTION public.sp_check_utility_anomalies(
    p_school_id UUID,
    p_reading_id UUID DEFAULT NULL::UUID
)
RETURNS JSONB
LANGUAGE plpgsql
AS $function$
DECLARE
    v_reading RECORD;
    v_numeric_val NUMERIC;
    v_avg_val NUMERIC;
    v_is_anomaly BOOLEAN := FALSE;
    v_auto_ticket_created BOOLEAN := FALSE;
    v_ticket_code VARCHAR(50);
    v_ticket_id UUID;
    v_seq INT;
BEGIN
    SELECT * INTO v_reading
    FROM public.campus_utility_readings
    WHERE (p_reading_id IS NULL OR id = p_reading_id)
      AND school_id = p_school_id
      AND deleted_at IS NULL
    ORDER BY recorded_at DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'No utility reading found.');
    END IF;

    -- Extract numeric digits from reading_value (e.g., "45,210 kWh" -> 45210)
    BEGIN
        v_numeric_val := (REGEXP_REPLACE(v_reading.reading_value, '[^0-9\.]', '', 'g'))::NUMERIC;
    EXCEPTION WHEN OTHERS THEN
        v_numeric_val := 0;
    END;

    -- Calculate average of previous readings for this utility type
    SELECT AVG((REGEXP_REPLACE(reading_value, '[^0-9\.]', '', 'g'))::NUMERIC)
    INTO v_avg_val
    FROM public.campus_utility_readings
    WHERE school_id = p_school_id
      AND utility_type = v_reading.utility_type
      AND id <> v_reading.id
      AND deleted_at IS NULL;

    -- Anomaly flag: if current reading > 1.5x previous average
    IF v_avg_val > 0 AND v_numeric_val > (v_avg_val * 1.5) THEN
        v_is_anomaly := TRUE;

        -- Auto-raise maintenance investigation ticket
        SELECT COUNT(*) + 1 INTO v_seq FROM public.maintenance_requests WHERE school_id = p_school_id;
        v_ticket_code := 'MT-UTL-' || TO_CHAR(CURRENT_DATE, 'YYMM') || '-' || LPAD(v_seq::TEXT, 4, '0');
        v_ticket_id := gen_random_uuid();

        INSERT INTO public.maintenance_requests (
            id,
            school_id,
            request_code,
            title,
            description,
            request_type,
            priority,
            status,
            location_display,
            reported_by_name,
            reported_by_role,
            reported_by_user_id,
            reported_at,
            due_date
        ) VALUES (
            v_ticket_id,
            p_school_id,
            v_ticket_code,
            'Abnormal Utility Spike Investigation: ' || v_reading.utility_name,
            'Automated IoT Alert: Detected sudden consumption spike (' || v_reading.reading_value || 
            ' vs baseline avg ' || ROUND(v_avg_val, 1)::TEXT || '). Investigate for leaks or grid fault.',
            'Plumbing & Water',
            'High',
            'Pending',
            v_reading.location,
            'Automated Utility Monitor',
            'System',
            '00000000-0000-0000-0000-000000000001'::UUID,
            NOW(),
            CURRENT_DATE + INTERVAL '2 days'
        );

        v_auto_ticket_created := TRUE;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'reading_id', v_reading.id,
        'utility_name', v_reading.utility_name,
        'current_value', v_numeric_val,
        'baseline_average', COALESCE(ROUND(v_avg_val, 1), 0),
        'is_anomaly', v_is_anomaly,
        'ticket_created', v_auto_ticket_created,
        'ticket_code', v_ticket_code
    );
END;
$function$;
