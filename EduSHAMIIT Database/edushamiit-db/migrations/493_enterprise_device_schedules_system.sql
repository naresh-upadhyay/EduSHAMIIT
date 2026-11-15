-- Migration: 493_enterprise_device_schedules_system.sql
-- Description: Comprehensive Enterprise Schedules Engine for EduSHAMIIT Device Management & Control
-- Aligns with high-fidelity schedule management: recurrent rules, time-windows, timeline projections, executions, and MQTT dispatch

-- 1. Enhance public.device_schedules table with enterprise properties
ALTER TABLE public.device_schedules 
  ADD COLUMN IF NOT EXISTS schedule_code VARCHAR(50) DEFAULT 'SCH-000',
  ADD COLUMN IF NOT EXISTS description TEXT,
  ADD COLUMN IF NOT EXISTS operation_type VARCHAR(50) DEFAULT 'turn_on_off',
  ADD COLUMN IF NOT EXISTS operation_value JSONB DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS target_name VARCHAR(200),
  ADD COLUMN IF NOT EXISTS target_ids UUID[] DEFAULT '{}'::uuid[],
  ADD COLUMN IF NOT EXISTS target_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS recurrence_type VARCHAR(50) DEFAULT 'daily',
  ADD COLUMN IF NOT EXISTS recurrence_label VARCHAR(100) DEFAULT 'Daily (Every day)',
  ADD COLUMN IF NOT EXISTS time_window_label VARCHAR(100),
  ADD COLUMN IF NOT EXISTS validity_label VARCHAR(100) DEFAULT '01 Jan 2025 - No End Date',
  ADD COLUMN IF NOT EXISTS next_run_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS last_run_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS last_status VARCHAR(50) DEFAULT 'success',
  ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS created_by_name VARCHAR(100) DEFAULT 'Admin';

-- Create Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_device_schedules_school_status ON public.device_schedules(school_id, status);
CREATE INDEX IF NOT EXISTS idx_device_schedules_next_run ON public.device_schedules(next_run_at);

-- 2. Create Schedule Executions History Table
CREATE TABLE IF NOT EXISTS public.device_schedule_executions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    schedule_id UUID NOT NULL REFERENCES public.device_schedules(id) ON DELETE CASCADE,
    execution_code VARCHAR(50) NOT NULL,
    trigger_time TIMESTAMPTZ NOT NULL DEFAULT now(),
    action_executed VARCHAR(100) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'success',
    affected_devices_count INTEGER NOT NULL DEFAULT 0,
    success_count INTEGER NOT NULL DEFAULT 0,
    failed_count INTEGER NOT NULL DEFAULT 0,
    log_details JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sched_exec_schedule ON public.device_schedule_executions(schedule_id);
CREATE INDEX IF NOT EXISTS idx_sched_exec_school_time ON public.device_schedule_executions(school_id, trigger_time DESC);

-- 3. Create Schedule Timeline Events Table (Projected 7-day upcoming runs)
CREATE TABLE IF NOT EXISTS public.device_schedule_timeline_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schedule_id UUID NOT NULL REFERENCES public.device_schedules(id) ON DELETE CASCADE,
    event_date_label VARCHAR(50) NOT NULL,
    event_time_label VARCHAR(50) NOT NULL,
    action_label VARCHAR(100) NOT NULL,
    is_upcoming BOOLEAN NOT NULL DEFAULT false,
    scheduled_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sched_timeline_schedule ON public.device_schedule_timeline_events(schedule_id);

-- 4. Stored Procedure: Trigger Schedule Run Now
CREATE OR REPLACE FUNCTION public.sp_trigger_device_schedule_run(
    p_schedule_id UUID,
    p_action_override TEXT DEFAULT NULL,
    p_user_name TEXT DEFAULT 'Admin'
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_sched RECORD;
    v_exec_id UUID;
    v_exec_code VARCHAR(50);
    v_action TEXT;
    v_affected INTEGER;
BEGIN
    SELECT * INTO v_sched FROM public.device_schedules WHERE id = p_schedule_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Schedule not found');
    END IF;

    v_action := COALESCE(p_action_override, v_sched.operation_type);
    v_affected := COALESCE(v_sched.target_count, 1);
    v_exec_code := 'RUN-' || to_char(now(), 'YYYYMMDD-HH24MISS');

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
        v_sched.school_id,
        v_sched.id,
        v_exec_code,
        now(),
        v_action,
        'success',
        v_affected,
        v_affected,
        0,
        jsonb_build_object(
            'triggered_by', p_user_name,
            'target_name', v_sched.target_name,
            'target_type', v_sched.target_type,
            'is_override', (p_action_override IS NOT NULL)
        )
    ) RETURNING id INTO v_exec_id;

    -- Update last run time on schedule
    UPDATE public.device_schedules
    SET last_run_at = now(),
        last_status = 'success',
        updated_at = now()
    WHERE id = p_schedule_id;

    RETURN jsonb_build_object(
        'success', true,
        'execution_id', v_exec_id,
        'execution_code', v_exec_code,
        'schedule_id', p_schedule_id,
        'action_executed', v_action,
        'affected_devices', v_affected
    );
END;
$$;

-- 5. Stored Procedure: Toggle Schedule Pause
CREATE OR REPLACE FUNCTION public.sp_toggle_device_schedule_pause(
    p_schedule_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_new_status VARCHAR(50);
    v_is_active BOOLEAN;
BEGIN
    SELECT 
        CASE WHEN status = 'paused' THEN 'active' ELSE 'paused' END,
        CASE WHEN status = 'paused' THEN true ELSE false END
    INTO v_new_status, v_is_active
    FROM public.device_schedules
    WHERE id = p_schedule_id;

    IF v_new_status IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Schedule not found');
    END IF;

    UPDATE public.device_schedules
    SET status = v_new_status,
        is_active = v_is_active,
        updated_at = now()
    WHERE id = p_schedule_id;

    RETURN jsonb_build_object(
        'success', true,
        'schedule_id', p_schedule_id,
        'new_status', v_new_status,
        'is_active', v_is_active
    );
END;
$$;

-- 6. Stored Procedure: Duplicate Device Schedule
CREATE OR REPLACE FUNCTION public.sp_duplicate_device_schedule(
    p_schedule_id UUID,
    p_user_name TEXT DEFAULT 'Admin'
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_orig RECORD;
    v_new_id UUID;
    v_new_code VARCHAR(50);
    v_count INTEGER;
BEGIN
    SELECT * INTO v_orig FROM public.device_schedules WHERE id = p_schedule_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Schedule not found');
    END IF;

    SELECT count(*) + 1 INTO v_count FROM public.device_schedules;
    v_new_code := 'SCH-' || lpad(v_count::text, 3, '0');

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
        created_by_name
    ) VALUES (
        v_orig.school_id,
        v_new_code,
        v_orig.name || ' (Copy)',
        v_orig.description,
        v_orig.operation_type,
        v_orig.operation_value,
        v_orig.target_type,
        v_orig.target_name,
        v_orig.target_count,
        v_orig.recurrence_type,
        v_orig.recurrence_label,
        v_orig.time_window_label,
        v_orig.validity_label,
        v_orig.start_time,
        v_orig.end_time,
        v_orig.days_of_week,
        v_orig.next_run_at + interval '1 day',
        'active',
        true,
        p_user_name
    ) RETURNING id INTO v_new_id;

    RETURN jsonb_build_object(
        'success', true,
        'new_schedule_id', v_new_id,
        'new_schedule_code', v_new_code
    );
END;
$$;

-- 7. Seed Canonical 10 Schedules matching Image 9
DO $$
DECLARE
    v_school UUID := '11111111-1111-1111-1111-111111111111';
    v_id1 UUID := 'c1111111-0000-0000-0000-000000000001';
    v_id2 UUID := 'c1111111-0000-0000-0000-000000000002';
    v_id3 UUID := 'c1111111-0000-0000-0000-000000000003';
    v_id4 UUID := 'c1111111-0000-0000-0000-000000000004';
    v_id5 UUID := 'c1111111-0000-0000-0000-000000000005';
    v_id6 UUID := 'c1111111-0000-0000-0000-000000000006';
    v_id7 UUID := 'c1111111-0000-0000-0000-000000000007';
    v_id8 UUID := 'c1111111-0000-0000-0000-000000000008';
    v_id9 UUID := 'c1111111-0000-0000-0000-000000000009';
    v_id10 UUID := 'c1111111-0000-0000-0000-000000000010';
BEGIN
    -- Delete previous seed records if any
    DELETE FROM public.device_schedules WHERE schedule_code IN (
        'SCH-001', 'SCH-002', 'SCH-003', 'SCH-004', 'SCH-005',
        'SCH-006', 'SCH-007', 'SCH-008', 'SCH-009', 'SCH-010'
    );

    -- 1. Classroom Lights - Auto ON/OFF
    INSERT INTO public.device_schedules (
        id, school_id, schedule_code, name, description, target_type, target_name, target_count,
        operation_type, operation_value, recurrence_type, recurrence_label, time_window_label, validity_label,
        start_time, end_time, days_of_week, next_run_at, status, is_active, created_by_name, created_at
    ) VALUES (
        v_id1, v_school, 'SCH-001', 'Classroom Lights - Auto ON/OFF',
        'Turns on classroom lights in the morning and turns them off in the evening automatically.',
        'group', 'Classroom Lights (A)', 96,
        'turn_on_off', '{"action_morning": "Turn ON", "action_evening": "Turn OFF"}'::jsonb,
        'daily', 'Daily (Every day)', '07:00 AM - 06:00 PM', '01 Jan 2025 - No End Date',
        '07:00:00', '18:00:00', '{1,2,3,4,5,6,7}', '2025-01-13 07:00:00+00', 'active', true, 'Admin', '2025-01-08 10:24:00+00'
    );

    -- 2. AC - Academic Block (Weekdays)
    INSERT INTO public.device_schedules (
        id, school_id, schedule_code, name, description, target_type, target_name, target_count,
        operation_type, operation_value, recurrence_type, recurrence_label, time_window_label, validity_label,
        start_time, end_time, days_of_week, next_run_at, status, is_active, created_by_name, created_at
    ) VALUES (
        v_id2, v_school, 'SCH-002', 'AC - Academic Block (Weekdays)',
        'Central climate control protocol across academic lecture halls and staff cabins.',
        'location', 'Academic Block (A)', 48,
        'set_value', '{"temperature": 24, "mode": "Cool"}'::jsonb,
        'mon_fri', 'Mon - Fri', '08:00 AM - 05:00 PM', '01 Jan 2025 - 31 Dec 2025',
        '08:00:00', '17:00:00', '{1,2,3,4,5}', '2025-01-13 08:00:00+00', 'active', true, 'Admin', '2025-01-08 11:30:00+00'
    );

    -- 3. Projector - Auditorium (Event Days)
    INSERT INTO public.device_schedules (
        id, school_id, schedule_code, name, description, target_type, target_name, target_count,
        operation_type, operation_value, recurrence_type, recurrence_label, time_window_label, validity_label,
        start_time, end_time, days_of_week, next_run_at, status, is_active, created_by_name, created_at
    ) VALUES (
        v_id3, v_school, 'SCH-003', 'Projector - Auditorium (Event Days)',
        'Main stage 4K laser projector and presentation screen warm-up routine.',
        'device', 'Projector (AUD-01)', 1,
        'turn_on', '{"input": "HDMI 1", "resolution": "4K"}'::jsonb,
        'specific_dates', 'Specific Dates', '15, 18, 22 Jan 2025, 09:00 AM', '15 Jan 2025 - 22 Jan 2025',
        '09:00:00', '13:00:00', '{}', '2025-01-15 09:00:00+00', 'active', true, 'Admin', '2025-01-09 14:15:00+00'
    );

    -- 4. Ceiling Fans - Library (Daily)
    INSERT INTO public.device_schedules (
        id, school_id, schedule_code, name, description, target_type, target_name, target_count,
        operation_type, operation_value, recurrence_type, recurrence_label, time_window_label, validity_label,
        start_time, end_time, days_of_week, next_run_at, status, is_active, created_by_name, created_at
    ) VALUES (
        v_id4, v_school, 'SCH-004', 'Ceiling Fans - Library (Daily)',
        'Circulation airflow across general reading areas and reference sections.',
        'group', 'Library Fans', 52,
        'set_speed', '{"speed": "Medium"}'::jsonb,
        'daily', 'Daily', '08:00 AM - 08:00 PM', '01 Jan 2025 - No End Date',
        '08:00:00', '20:00:00', '{1,2,3,4,5,6,7}', '2025-01-13 08:00:00+00', 'active', true, 'Admin', '2025-01-09 16:45:00+00'
    );

    -- 5. Access Doors - Main Block (Secure Hours)
    INSERT INTO public.device_schedules (
        id, school_id, schedule_code, name, description, target_type, target_name, target_count,
        operation_type, operation_value, recurrence_type, recurrence_label, time_window_label, validity_label,
        start_time, end_time, days_of_week, next_run_at, status, is_active, created_by_name, created_at
    ) VALUES (
        v_id5, v_school, 'SCH-005', 'Access Doors - Main Block (Secure Hours)',
        'Enforces perimeter lock and RFID credential requirements during night shifts.',
        'location', 'Main Block', 18,
        'lock', '{"mode": "Night Lockdown"}'::jsonb,
        'daily', 'Daily', '07:00 PM - 06:00 AM', '01 Jan 2025 - No End Date',
        '19:00:00', '06:00:00', '{1,2,3,4,5,6,7}', '2025-01-13 19:00:00+00', 'active', true, 'Admin', '2025-01-10 09:20:00+00'
    );

    -- 6. Corridor Lights - Night Mode
    INSERT INTO public.device_schedules (
        id, school_id, schedule_code, name, description, target_type, target_name, target_count,
        operation_type, operation_value, recurrence_type, recurrence_label, time_window_label, validity_label,
        start_time, end_time, days_of_week, next_run_at, status, is_active, created_by_name, created_at
    ) VALUES (
        v_id6, v_school, 'SCH-006', 'Corridor Lights - Night Mode',
        'Dims hallway fixtures to 30% for night vision and campus energy conservation.',
        'group', 'Corridor Lights', 64,
        'brightness', '{"level": 30}'::jsonb,
        'daily', 'Daily', '06:00 PM - 06:00 AM', '01 Jan 2025 - No End Date',
        '18:00:00', '06:00:00', '{1,2,3,4,5,6,7}', '2025-01-13 18:00:00+00', 'active', true, 'Admin', '2025-01-10 11:10:00+00'
    );

    -- 7. Morning Bell - School Start
    INSERT INTO public.device_schedules (
        id, school_id, schedule_code, name, description, target_type, target_name, target_count,
        operation_type, operation_value, recurrence_type, recurrence_label, time_window_label, validity_label,
        start_time, end_time, days_of_week, next_run_at, status, is_active, created_by_name, created_at
    ) VALUES (
        v_id7, v_school, 'SCH-007', 'Morning Bell - School Start',
        'Chimes campus-wide bell audio tone over IP horn speakers.',
        'device', 'PA System (Main)', 12,
        'play_audio', '{"track": "School Bell", "volume": 85}'::jsonb,
        'daily', 'Daily', '08:00 AM', '01 Jan 2025 - No End Date',
        '08:00:00', '08:01:00', '{1,2,3,4,5}', '2025-01-13 08:00:00+00', 'active', true, 'Admin', '2025-01-10 12:30:00+00'
    );

    -- 8. AC - Labs (Weekend)
    INSERT INTO public.device_schedules (
        id, school_id, schedule_code, name, description, target_type, target_name, target_count,
        operation_type, operation_value, recurrence_type, recurrence_label, time_window_label, validity_label,
        start_time, end_time, days_of_week, next_run_at, status, is_active, created_by_name, created_at
    ) VALUES (
        v_id8, v_school, 'SCH-008', 'AC - Labs (Weekend)',
        'Suspends high-tonnage chiller compressor units in research blocks over weekends.',
        'location', 'Laboratories Block (B)', 36,
        'turn_off', '{"override_allowed": true}'::jsonb,
        'sat_sun', 'Sat - Sun', 'All Day', '01 Jan 2025 - No End Date',
        '00:00:00', '23:59:59', '{6,7}', '2025-01-18 00:00:00+00', 'paused', false, 'Admin', '2025-01-10 14:00:00+00'
    );

    -- 9. Displays - Reception (Working Hours)
    INSERT INTO public.device_schedules (
        id, school_id, schedule_code, name, description, target_type, target_name, target_count,
        operation_type, operation_value, recurrence_type, recurrence_label, time_window_label, validity_label,
        start_time, end_time, days_of_week, next_run_at, status, is_active, created_by_name, created_at
    ) VALUES (
        v_id9, v_school, 'SCH-009', 'Displays - Reception (Working Hours)',
        'Powers on reception touchscreens, digital signage and announcements kiosk.',
        'group', 'Reception Displays', 8,
        'turn_on_off', '{"start": "Power On", "end": "Power Off"}'::jsonb,
        'mon_fri', 'Mon - Fri', '08:00 AM - 06:00 PM', '01 Jan 2025 - No End Date',
        '08:00:00', '18:00:00', '{1,2,3,4,5}', '2025-01-13 08:00:00+00', 'active', true, 'Admin', '2025-01-10 15:45:00+00'
    );

    -- 10. Energy Saving - Non-Academic Hours
    INSERT INTO public.device_schedules (
        id, school_id, schedule_code, name, description, target_type, target_name, target_count,
        operation_type, operation_value, recurrence_type, recurrence_label, time_window_label, validity_label,
        start_time, end_time, days_of_week, next_run_at, status, is_active, created_by_name, created_at
    ) VALUES (
        v_id10, v_school, 'SCH-010', 'Energy Saving - Non-Academic Hours',
        'Applies institution-wide Eco Mode preset across smart classroom relays and smart plugs.',
        'multiple', '(3 Groups)', 24,
        'apply_scene', '{"scene_name": "Eco Mode"}'::jsonb,
        'daily', 'Daily', '06:30 PM', '01 Jan 2025 - No End Date',
        '18:30:00', '23:59:59', '{1,2,3,4,5,6,7}', '2025-01-13 18:30:00+00', 'active', true, 'Admin', '2025-01-10 17:00:00+00'
    );

    -- Seed 7-Day Timeline events for SCH-001 (matches right panel in screenshot)
    DELETE FROM public.device_schedule_timeline_events WHERE schedule_id = v_id1;
    INSERT INTO public.device_schedule_timeline_events (
        schedule_id, event_date_label, event_time_label, action_label, is_upcoming, scheduled_at
    ) VALUES 
        (v_id1, 'Mon, 13 Jan 2025', '07:00 AM', 'Turn ON', true, '2025-01-13 07:00:00+00'),
        (v_id1, 'Mon, 13 Jan 2025', '06:00 PM', 'Turn OFF', false, '2025-01-13 18:00:00+00'),
        (v_id1, 'Tue, 14 Jan 2025', '07:00 AM', 'Turn ON', false, '2025-01-14 07:00:00+00'),
        (v_id1, 'Tue, 14 Jan 2025', '06:00 PM', 'Turn OFF', false, '2025-01-14 18:00:00+00');

    -- Seed Recent Executions
    DELETE FROM public.device_schedule_executions WHERE schedule_id IN (v_id1, v_id2);
    INSERT INTO public.device_schedule_executions (
        school_id, schedule_id, execution_code, trigger_time, action_executed, status, affected_devices_count, success_count, failed_count, log_details
    ) VALUES
        (v_school, v_id1, 'EXEC-2025-0112-1800', '2025-01-12 18:00:00+00', 'Turn OFF', 'success', 96, 96, 0, '{"dispatched": 96, "completed": 96}'::jsonb),
        (v_school, v_id1, 'EXEC-2025-0112-0700', '2025-01-12 07:00:00+00', 'Turn ON', 'success', 96, 96, 0, '{"dispatched": 96, "completed": 96}'::jsonb),
        (v_school, v_id2, 'EXEC-2025-0110-0800', '2025-01-10 08:00:00+00', 'Set to 24°C', 'success', 48, 48, 0, '{"dispatched": 48, "completed": 48}'::jsonb);

END $$;
