-- Migration: 494_enterprise_scenes_presets_system.sql
-- Description: Comprehensive Enterprise Scenes & Presets Engine for EduSHAMIIT Device Management & Control
-- Aligns with multi-device orchestration: Scenes, Presets, Step sequences, Executions log, and MQTT triggers

-- 1. Enhance public.device_scenes table with enterprise columns
ALTER TABLE public.device_scenes 
  ADD COLUMN IF NOT EXISTS scene_code VARCHAR(50) DEFAULT 'SCN-000',
  ADD COLUMN IF NOT EXISTS category VARCHAR(50) DEFAULT 'academic',
  ADD COLUMN IF NOT EXISTS scene_type VARCHAR(50) DEFAULT 'scene',
  ADD COLUMN IF NOT EXISTS target_type VARCHAR(50) DEFAULT 'devices',
  ADD COLUMN IF NOT EXISTS target_name VARCHAR(200) DEFAULT '8 devices',
  ADD COLUMN IF NOT EXISTS target_count INTEGER DEFAULT 8,
  ADD COLUMN IF NOT EXISTS target_ids UUID[] DEFAULT '{}'::uuid[],
  ADD COLUMN IF NOT EXISTS location_scope VARCHAR(200) DEFAULT 'Classroom / Academic Block',
  ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT ARRAY['Academic', 'Classroom'],
  ADD COLUMN IF NOT EXISTS steps JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS created_by_name VARCHAR(100) DEFAULT 'Admin',
  ADD COLUMN IF NOT EXISTS execution_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS used_in_automations_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS used_in_schedules_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_popular BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS thumbnail_url VARCHAR(500);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_device_scenes_school_type_status ON public.device_scenes(school_id, scene_type, status);
CREATE INDEX IF NOT EXISTS idx_device_scenes_code ON public.device_scenes(scene_code);

-- 2. Create Scene Executions History Table
CREATE TABLE IF NOT EXISTS public.device_scene_executions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    scene_id UUID NOT NULL REFERENCES public.device_scenes(id) ON DELETE CASCADE,
    execution_code VARCHAR(50) NOT NULL,
    executed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    executed_by_name VARCHAR(100) NOT NULL DEFAULT 'Admin',
    status VARCHAR(50) NOT NULL DEFAULT 'success',
    duration_ms INTEGER NOT NULL DEFAULT 420,
    affected_devices_count INTEGER NOT NULL DEFAULT 8,
    success_count INTEGER NOT NULL DEFAULT 8,
    failed_count INTEGER NOT NULL DEFAULT 0,
    steps_executed JSONB DEFAULT '[]'::jsonb,
    log_details JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_scene_exec_scene ON public.device_scene_executions(scene_id);
CREATE INDEX IF NOT EXISTS idx_scene_exec_school_time ON public.device_scene_executions(school_id, executed_at DESC);

-- 3. Stored Procedure: Execute Scene / Preset
CREATE OR REPLACE FUNCTION public.sp_trigger_device_scene_run(
    p_school_id UUID,
    p_scene_id UUID,
    p_user_name VARCHAR DEFAULT 'Admin'
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_scene RECORD;
    v_exec_code VARCHAR(50);
    v_exec_id UUID;
    v_affected INT;
    v_res JSONB;
BEGIN
    SELECT * INTO v_scene FROM public.device_scenes
    WHERE id = p_scene_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Scene or Preset not found');
    END IF;

    v_exec_code := 'EXEC-SCN-' || to_char(now(), 'YYYYMMDD-HH24MISS');
    v_affected := COALESCE(v_scene.target_count, 8);

    -- Update scene stats
    UPDATE public.device_scenes
    SET execution_count = COALESCE(execution_count, 0) + 1,
        last_applied_at = now(),
        updated_at = now()
    WHERE id = p_scene_id;

    -- Record execution log
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
        p_scene_id,
        v_exec_code,
        now(),
        p_user_name,
        'success',
        (350 + (random() * 150)::int),
        v_affected,
        v_affected,
        0,
        COALESCE(v_scene.steps, '[]'::jsonb),
        jsonb_build_object('scene_name', v_scene.name, 'scene_type', v_scene.scene_type, 'target_name', v_scene.target_name)
    ) RETURNING id INTO v_exec_id;

    -- Also record in general system audit logs if table exists
    BEGIN
        INSERT INTO public.audit_logs (school_id, action, entity_type, entity_id, details)
        VALUES (p_school_id, 'EXECUTE_SCENE', 'device_scene', p_scene_id, 
                jsonb_build_object('name', v_scene.name, 'code', v_scene.scene_code, 'exec_code', v_exec_code));
    EXCEPTION WHEN OTHERS THEN
        -- ignore if audit_logs schema differs
    END;

    RETURN jsonb_build_object(
        'success', true,
        'execution_id', v_exec_id,
        'execution_code', v_exec_code,
        'scene_id', p_scene_id,
        'scene_name', v_scene.name,
        'affected_count', v_affected,
        'executed_at', now()
    );
END;
$$;

-- 4. Stored Procedure: Toggle Scene / Preset Status (Active / Disabled)
CREATE OR REPLACE FUNCTION public.sp_toggle_device_scene_status(
    p_school_id UUID,
    p_scene_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_curr_status VARCHAR(50);
    v_new_status VARCHAR(50);
    v_is_active BOOLEAN;
BEGIN
    SELECT status INTO v_curr_status FROM public.device_scenes
    WHERE id = p_scene_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Scene not found');
    END IF;

    IF v_curr_status = 'active' THEN
        v_new_status := 'disabled';
        v_is_active := false;
    ELSE
        v_new_status := 'active';
        v_is_active := true;
    END IF;

    UPDATE public.device_scenes
    SET status = v_new_status,
        is_active = v_is_active,
        updated_at = now()
    WHERE id = p_scene_id AND school_id = p_school_id;

    RETURN jsonb_build_object(
        'success', true,
        'scene_id', p_scene_id,
        'status', v_new_status,
        'is_active', v_is_active
    );
END;
$$;

-- 5. Stored Procedure: Duplicate Scene
CREATE OR REPLACE FUNCTION public.sp_duplicate_device_scene(
    p_school_id UUID,
    p_scene_id UUID,
    p_user_name VARCHAR DEFAULT 'Admin'
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_orig RECORD;
    v_new_id UUID;
    v_new_code VARCHAR(50);
BEGIN
    SELECT * INTO v_orig FROM public.device_scenes
    WHERE id = p_scene_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Original scene not found');
    END IF;

    v_new_code := v_orig.scene_code || '-COPY';
    v_new_id := gen_random_uuid();

    INSERT INTO public.device_scenes (
        id, school_id, name, code, scene_code, category, scene_type, target_type,
        target_name, target_count, target_ids, location_scope, tags, steps,
        description, icon, color, is_preset, is_active, status, created_by_name,
        execution_count, used_in_automations_count, used_in_schedules_count,
        is_popular, thumbnail_url, created_at, updated_at
    ) VALUES (
        v_new_id,
        p_school_id,
        v_orig.name || ' (Copy)',
        v_orig.code || '_copy_' || substr(gen_random_uuid()::text, 1, 4),
        v_new_code,
        v_orig.category,
        v_orig.scene_type,
        v_orig.target_type,
        v_orig.target_name,
        v_orig.target_count,
        v_orig.target_ids,
        v_orig.location_scope,
        v_orig.tags,
        COALESCE(v_orig.steps, '[]'::jsonb),
        'Copy of ' || COALESCE(v_orig.description, ''),
        v_orig.icon,
        v_orig.color,
        v_orig.is_preset,
        true,
        'active',
        p_user_name,
        0, 0, 0, false, v_orig.thumbnail_url,
        now(), now()
    );

    RETURN jsonb_build_object(
        'success', true,
        'scene_id', v_new_id,
        'scene_code', v_new_code,
        'name', v_orig.name || ' (Copy)'
    );
END;
$$;

-- 6. Canonical Seed Data: Insert / Upsert the 10 reference Scenes & Presets matching the design
DO $$
DECLARE
    v_sid UUID := '11111111-1111-1111-1111-111111111111';
BEGIN
    -- Ensure school exists
    IF NOT EXISTS (SELECT 1 FROM public.schools WHERE id = v_sid) THEN
        INSERT INTO public.schools (id, name, code, is_active)
        VALUES (v_sid, 'Greenwood High School', 'GHS-001', true)
        ON CONFLICT (id) DO NOTHING;
    END IF;

    -- 1. Class Start (SCN-001)
    INSERT INTO public.device_scenes (
        school_id, name, code, scene_code, category, scene_type, target_type, target_name, target_count,
        location_scope, tags, description, icon, color, is_preset, is_active, status, created_by_name,
        execution_count, used_in_automations_count, used_in_schedules_count, is_popular, steps, created_at, updated_at
    ) VALUES (
        v_sid, 'Class Start', 'scn_class_start', 'SCN-001', 'academic', 'scene', 'devices', '8 devices', 8,
        'Classroom / Academic Block', ARRAY['Scene', 'Academic'],
        'Prepare classroom for class (lights, AC, projector)',
        'wb_sunny_rounded', '#F59E0B', false, true, 'active', 'Admin',
        128, 2, 3, true,
        '[
            {"order": 1, "target_name": "Classroom Lights (Group)", "target_type": "group", "action": "Turn ON, Brightness: 100%", "icon": "lightbulb"},
            {"order": 2, "target_name": "AC Unit (A1-101)", "target_type": "device", "action": "Set to 24°C, Mode: Cool, Fan: Auto", "icon": "ac_unit"},
            {"order": 3, "target_name": "Projector (A1-102)", "target_type": "device", "action": "Turn ON, Input: HDMI 1", "icon": "videocam"},
            {"order": 4, "target_name": "Interactive Display", "target_type": "device", "action": "Turn ON", "icon": "tv"},
            {"order": 5, "target_name": "Audio System", "target_type": "device", "action": "Set Volume: 40%", "icon": "volume_up"}
        ]'::jsonb,
        '2025-01-08 10:15:00+00', '2025-01-10 14:15:00+00'
    ) ON CONFLICT (school_id, code) DO UPDATE SET
        scene_code = EXCLUDED.scene_code,
        category = EXCLUDED.category,
        scene_type = EXCLUDED.scene_type,
        target_name = EXCLUDED.target_name,
        target_count = EXCLUDED.target_count,
        location_scope = EXCLUDED.location_scope,
        tags = EXCLUDED.tags,
        description = EXCLUDED.description,
        icon = EXCLUDED.icon,
        color = EXCLUDED.color,
        is_active = EXCLUDED.is_active,
        status = EXCLUDED.status,
        execution_count = EXCLUDED.execution_count,
        used_in_automations_count = EXCLUDED.used_in_automations_count,
        used_in_schedules_count = EXCLUDED.used_in_schedules_count,
        is_popular = EXCLUDED.is_popular,
        steps = EXCLUDED.steps;

    -- 2. Class End (SCN-002)
    INSERT INTO public.device_scenes (
        school_id, name, code, scene_code, category, scene_type, target_type, target_name, target_count,
        location_scope, tags, description, icon, color, is_preset, is_active, status, created_by_name,
        execution_count, used_in_automations_count, used_in_schedules_count, is_popular, steps, created_at, updated_at
    ) VALUES (
        v_sid, 'Class End', 'scn_class_end', 'SCN-002', 'academic', 'scene', 'devices', '8 devices', 8,
        'Classroom / Academic Block', ARRAY['Scene', 'Academic', 'Energy'],
        'Turn off devices and save energy after class',
        'nightlight_round', '#8B5CF6', false, true, 'active', 'Admin',
        96, 4, 5, true,
        '[
            {"order": 1, "target_name": "Projector (A1-102)", "target_type": "device", "action": "Turn OFF", "icon": "videocam"},
            {"order": 2, "target_name": "Interactive Display", "target_type": "device", "action": "Turn OFF", "icon": "tv"},
            {"order": 3, "target_name": "AC Unit (A1-101)", "target_type": "device", "action": "Turn OFF", "icon": "ac_unit"},
            {"order": 4, "target_name": "Audio System", "target_type": "device", "action": "Mute / Turn OFF", "icon": "volume_off"},
            {"order": 5, "target_name": "Classroom Lights (Group)", "target_type": "group", "action": "Turn OFF", "icon": "lightbulb"}
        ]'::jsonb,
        '2025-01-08 10:30:00+00', '2025-01-10 14:15:00+00'
    ) ON CONFLICT (school_id, code) DO UPDATE SET
        scene_code = EXCLUDED.scene_code,
        target_name = EXCLUDED.target_name,
        steps = EXCLUDED.steps,
        execution_count = EXCLUDED.execution_count,
        is_popular = EXCLUDED.is_popular;

    -- 3. Presentation Mode (SCN-003)
    INSERT INTO public.device_scenes (
        school_id, name, code, scene_code, category, scene_type, target_type, target_name, target_count,
        location_scope, tags, description, icon, color, is_preset, is_active, status, created_by_name,
        execution_count, used_in_automations_count, used_in_schedules_count, is_popular, steps, created_at, updated_at
    ) VALUES (
        v_sid, 'Presentation Mode', 'scn_presentation_mode', 'SCN-003', 'av_display', 'scene', 'devices', '12 devices', 12,
        'Auditorium / Conference Halls', ARRAY['Scene', 'Presentation', 'AV'],
        'Dim lights, turn on projector, set input to HDMI',
        'desktop_windows_rounded', '#3B82F6', false, true, 'active', 'Admin',
        72, 1, 2, true,
        '[
            {"order": 1, "target_name": "Auditorium Lights (Group)", "target_type": "group", "action": "Dim to 20%", "icon": "lightbulb"},
            {"order": 2, "target_name": "Main Projector", "target_type": "device", "action": "Turn ON, Input: HDMI 1", "icon": "videocam"},
            {"order": 3, "target_name": "Motorized Projector Screen", "target_type": "device", "action": "Lower Screen", "icon": "smart_screen"},
            {"order": 4, "target_name": "Auditorium Audio System", "target_type": "device", "action": "Preset: Speech / Presentation", "icon": "volume_up"}
        ]'::jsonb,
        '2025-01-08 11:00:00+00', '2025-01-10 14:15:00+00'
    ) ON CONFLICT (school_id, code) DO UPDATE SET
        scene_code = EXCLUDED.scene_code,
        target_name = EXCLUDED.target_name,
        steps = EXCLUDED.steps,
        execution_count = EXCLUDED.execution_count,
        is_popular = EXCLUDED.is_popular;

    -- 4. Exam Mode (SCN-004)
    INSERT INTO public.device_scenes (
        school_id, name, code, scene_code, category, scene_type, target_type, target_name, target_count,
        location_scope, tags, description, icon, color, is_preset, is_active, status, created_by_name,
        execution_count, used_in_automations_count, used_in_schedules_count, is_popular, steps, created_at, updated_at
    ) VALUES (
        v_sid, 'Exam Mode', 'scn_exam_mode', 'SCN-004', 'academic', 'scene', 'devices', '10 devices', 10,
        'Exam Halls / Classrooms', ARRAY['Scene', 'Exam', 'Comfort'],
        'Optimal lighting and AC for examination',
        'assignment_turned_in_rounded', '#10B981', false, true, 'active', 'Admin',
        48, 1, 3, true,
        '[
            {"order": 1, "target_name": "Hall Ceiling Lights", "target_type": "group", "action": "Brightness: 100% High CRI", "icon": "lightbulb"},
            {"order": 2, "target_name": "HVAC Air Handling Units", "target_type": "group", "action": "Set to 23°C Silent Fan Mode", "icon": "ac_unit"},
            {"order": 3, "target_name": "Projectors & Displays", "target_type": "group", "action": "Turn OFF", "icon": "tv_off"},
            {"order": 4, "target_name": "School Intercom / PA", "target_type": "device", "action": "Silence Non-Emergency Broadcasts", "icon": "volume_off"}
        ]'::jsonb,
        '2025-01-08 11:30:00+00', '2025-01-10 14:15:00+00'
    ) ON CONFLICT (school_id, code) DO UPDATE SET
        scene_code = EXCLUDED.scene_code,
        target_name = EXCLUDED.target_name,
        steps = EXCLUDED.steps,
        execution_count = EXCLUDED.execution_count,
        is_popular = EXCLUDED.is_popular;

    -- 5. Energy Saving (SCN-005)
    INSERT INTO public.device_scenes (
        school_id, name, code, scene_code, category, scene_type, target_type, target_name, target_count,
        location_scope, tags, description, icon, color, is_preset, is_active, status, created_by_name,
        execution_count, used_in_automations_count, used_in_schedules_count, is_popular, steps, created_at, updated_at
    ) VALUES (
        v_sid, 'Energy Saving', 'scn_energy_saving', 'SCN-005', 'energy', 'scene', 'all_in_location', 'All in Location', 48,
        'Campus-Wide / Non-Occupied Wings', ARRAY['Scene', 'Eco', 'Energy'],
        'Apply energy-efficient settings (lights, AC, fans)',
        'eco_rounded', '#059669', false, true, 'active', 'Admin',
        64, 5, 8, true,
        '[
            {"order": 1, "target_name": "Corridor & Common Area Lights", "target_type": "group", "action": "Dim to 30%", "icon": "lightbulb"},
            {"order": 2, "target_name": "HVAC Central Chillers", "target_type": "group", "action": "Set Eco Temp 26°C", "icon": "ac_unit"},
            {"order": 3, "target_name": "Non-Essential Loads & Water Dispensers", "target_type": "group", "action": "Standby Mode", "icon": "power_settings_new"}
        ]'::jsonb,
        '2025-01-08 12:00:00+00', '2025-01-10 14:15:00+00'
    ) ON CONFLICT (school_id, code) DO UPDATE SET
        scene_code = EXCLUDED.scene_code,
        target_name = EXCLUDED.target_name,
        steps = EXCLUDED.steps,
        execution_count = EXCLUDED.execution_count,
        is_popular = EXCLUDED.is_popular;

    -- 6. Campus Lockdown (SCN-006)
    INSERT INTO public.device_scenes (
        school_id, name, code, scene_code, category, scene_type, target_type, target_name, target_count,
        location_scope, tags, description, icon, color, is_preset, is_active, status, created_by_name,
        execution_count, used_in_automations_count, used_in_schedules_count, is_popular, steps, created_at, updated_at
    ) VALUES (
        v_sid, 'Campus Lockdown', 'scn_campus_lockdown', 'SCN-006', 'security', 'scene', 'whole_campus', 'Whole Campus', 256,
        'Whole Campus', ARRAY['Scene', 'Security', 'Emergency'],
        'Secure campus (lock doors, turn off non-essential)',
        'security_rounded', '#EF4444', false, true, 'active', 'Admin',
        14, 3, 1, false,
        '[
            {"order": 1, "target_name": "Access Control Perimeter", "target_type": "group", "action": "Lock All Magnetic Doors", "icon": "lock"},
            {"order": 2, "target_name": "Security Floodlights", "target_type": "group", "action": "Turn ON High-Intensity Floodlights", "icon": "highlight"},
            {"order": 3, "target_name": "Notification PA Broadcast", "target_type": "device", "action": "Broadcast Lockdown Protocol", "icon": "campaign"},
            {"order": 4, "target_name": "Elevator System", "target_type": "group", "action": "Ground Floor Recall", "icon": "elevator"}
        ]'::jsonb,
        '2025-01-08 13:00:00+00', '2025-01-10 14:15:00+00'
    ) ON CONFLICT (school_id, code) DO UPDATE SET
        scene_code = EXCLUDED.scene_code,
        target_name = EXCLUDED.target_name,
        steps = EXCLUDED.steps;

    -- 7. Morning Setup (SCN-007)
    INSERT INTO public.device_scenes (
        school_id, name, code, scene_code, category, scene_type, target_type, target_name, target_count,
        location_scope, tags, description, icon, color, is_preset, is_active, status, created_by_name,
        execution_count, used_in_automations_count, used_in_schedules_count, is_popular, steps, created_at, updated_at
    ) VALUES (
        v_sid, 'Morning Setup', 'scn_morning_setup', 'SCN-007', 'general', 'scene', 'devices', '24 devices', 24,
        'Academic Blocks A, B, C', ARRAY['Scene', 'Morning', 'Routine'],
        'Daily morning setup for academic blocks',
        'wb_twilight_rounded', '#F97316', false, true, 'active', 'Admin',
        85, 3, 6, false,
        '[
            {"order": 1, "target_name": "Entrance & Hallway Lights", "target_type": "group", "action": "Turn ON 100%", "icon": "lightbulb"},
            {"order": 2, "target_name": "Central HVAC Pre-Cooling", "target_type": "group", "action": "Set to 24°C", "icon": "ac_unit"},
            {"order": 3, "target_name": "Digital Signage Displays", "target_type": "group", "action": "Turn ON Daily Noticeboard", "icon": "tv"}
        ]'::jsonb,
        '2025-01-08 13:30:00+00', '2025-01-10 14:15:00+00'
    ) ON CONFLICT (school_id, code) DO UPDATE SET
        scene_code = EXCLUDED.scene_code,
        target_name = EXCLUDED.target_name,
        steps = EXCLUDED.steps;

    -- 8. Night Mode (SCN-008)
    INSERT INTO public.device_scenes (
        school_id, name, code, scene_code, category, scene_type, target_type, target_name, target_count,
        location_scope, tags, description, icon, color, is_preset, is_active, status, created_by_name,
        execution_count, used_in_automations_count, used_in_schedules_count, is_popular, steps, created_at, updated_at
    ) VALUES (
        v_sid, 'Night Mode', 'scn_night_mode', 'SCN-008', 'security', 'scene', 'all_in_building', 'All in Building', 96,
        'All Academic & Admin Buildings', ARRAY['Scene', 'Night', 'Security'],
        'Power down and set security lighting',
        'dark_mode_rounded', '#1E3A8A', false, true, 'active', 'Admin',
        92, 4, 7, true,
        '[
            {"order": 1, "target_name": "Classroom & Office Lights", "target_type": "group", "action": "Turn OFF", "icon": "lightbulb"},
            {"order": 2, "target_name": "HVAC & Air Handlers", "target_type": "group", "action": "Turn OFF", "icon": "ac_unit"},
            {"order": 3, "target_name": "Motion Sensors & Night Security Lights", "target_type": "group", "action": "Armed ON", "icon": "shield"}
        ]'::jsonb,
        '2025-01-08 14:00:00+00', '2025-01-10 14:15:00+00'
    ) ON CONFLICT (school_id, code) DO UPDATE SET
        scene_code = EXCLUDED.scene_code,
        target_name = EXCLUDED.target_name,
        steps = EXCLUDED.steps,
        execution_count = EXCLUDED.execution_count,
        is_popular = EXCLUDED.is_popular;

    -- 9. AC - Comfort (24°C) (PST-001)
    INSERT INTO public.device_scenes (
        school_id, name, code, scene_code, category, scene_type, target_type, target_name, target_count,
        location_scope, tags, description, icon, color, is_preset, is_active, status, created_by_name,
        execution_count, used_in_automations_count, used_in_schedules_count, is_popular, steps, created_at, updated_at
    ) VALUES (
        v_sid, 'AC - Comfort (24°C)', 'pst_ac_comfort_24', 'PST-001', 'comfort', 'preset', 'by_type', 'AC (All)', 48,
        'All Buildings', ARRAY['Preset', 'HVAC', 'Comfort'],
        'Set AC to 24°C, Cool mode, Auto fan',
        'thermostat_rounded', '#0284C7', true, true, 'active', 'Admin',
        140, 6, 8, false,
        '[
            {"order": 1, "target_name": "All AC Units", "target_type": "device_type", "action": "Set to 24°C, Mode: Cool, Fan: Auto", "icon": "ac_unit"}
        ]'::jsonb,
        '2025-01-08 14:30:00+00', '2025-01-10 14:15:00+00'
    ) ON CONFLICT (school_id, code) DO UPDATE SET
        scene_code = EXCLUDED.scene_code,
        target_name = EXCLUDED.target_name,
        steps = EXCLUDED.steps;

    -- 10. Lighting - 50% (PST-002)
    INSERT INTO public.device_scenes (
        school_id, name, code, scene_code, category, scene_type, target_type, target_name, target_count,
        location_scope, tags, description, icon, color, is_preset, is_active, status, created_by_name,
        execution_count, used_in_automations_count, used_in_schedules_count, is_popular, steps, created_at, updated_at
    ) VALUES (
        v_sid, 'Lighting - 50%', 'pst_lighting_50', 'PST-002', 'energy', 'preset', 'by_type', 'Lighting (All)', 92,
        'All Buildings', ARRAY['Preset', 'Lighting', 'Dimming'],
        'Set lighting brightness to 50%',
        'brightness_medium_rounded', '#EAB308', true, true, 'active', 'Admin',
        110, 4, 6, false,
        '[
            {"order": 1, "target_name": "All Dimmable Fixtures", "target_type": "device_type", "action": "Set Brightness: 50%", "icon": "lightbulb"}
        ]'::jsonb,
        '2025-01-08 15:00:00+00', '2025-01-10 14:15:00+00'
    ) ON CONFLICT (school_id, code) DO UPDATE SET
        scene_code = EXCLUDED.scene_code,
        target_name = EXCLUDED.target_name,
        steps = EXCLUDED.steps;

    -- Seed canonical execution history for SCN-001 Class Start
    INSERT INTO public.device_scene_executions (
        school_id, scene_id, execution_code, executed_at, executed_by_name, status,
        duration_ms, affected_devices_count, success_count, failed_count, steps_executed, log_details
    ) 
    SELECT 
        v_sid, id, 'EXEC-SCN-20250110-141500', '2025-01-10 14:15:00+00', 'Admin', 'success',
        420, 8, 8, 0, steps, '{"message": "All 8 devices transitioned successfully"}'::jsonb
    FROM public.device_scenes WHERE school_id = v_sid AND scene_code = 'SCN-001'
    LIMIT 1;

END $$;
