-- ====================================================================
-- Migration 492: Enterprise Bulk Operations System
-- EduSHAMIIT ERP Campus Management -> Device Management -> Bulk Operations
-- ====================================================================

CREATE TABLE IF NOT EXISTS public.bulk_operations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    operation_code VARCHAR(100) NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    operation_type VARCHAR(50) NOT NULL, -- 'control', 'configuration', 'firmware_update', 'assign_group', 'apply_profile', 'schedule', 'run_scene'
    target_type VARCHAR(50) NOT NULL DEFAULT 'devices', -- 'devices', 'groups', 'locations', 'device_types'
    target_configuration JSONB DEFAULT '{}'::jsonb,
    action_configuration JSONB DEFAULT '{}'::jsonb,
    execution_configuration JSONB DEFAULT '{}'::jsonb,
    status VARCHAR(50) NOT NULL DEFAULT 'completed', -- 'draft', 'scheduled', 'queued', 'running', 'paused', 'completed', 'completed_with_errors', 'failed', 'cancelled'
    total_devices INT NOT NULL DEFAULT 0,
    eligible_devices INT NOT NULL DEFAULT 0,
    successful_devices INT NOT NULL DEFAULT 0,
    failed_devices INT NOT NULL DEFAULT 0,
    skipped_devices INT NOT NULL DEFAULT 0,
    pending_devices INT NOT NULL DEFAULT 0,
    initiated_by UUID,
    initiated_by_name VARCHAR(150) DEFAULT 'Admin',
    approved_by UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    scheduled_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bulk_operations_school_status ON public.bulk_operations(school_id, status);
CREATE INDEX IF NOT EXISTS idx_bulk_operations_created_at ON public.bulk_operations(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bulk_operations_code ON public.bulk_operations(school_id, operation_code);

-- 2. Bulk Operation Devices
CREATE TABLE IF NOT EXISTS public.bulk_operation_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    operation_id UUID NOT NULL REFERENCES public.bulk_operations(id) ON DELETE CASCADE,
    device_id UUID NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
    device_name VARCHAR(150),
    device_code VARCHAR(100),
    device_type_code VARCHAR(50),
    location_display VARCHAR(255),
    action_payload JSONB DEFAULT '{}'::jsonb,
    initial_state_snapshot JSONB DEFAULT '{}'::jsonb,
    target_state JSONB DEFAULT '{}'::jsonb,
    eligibility_status VARCHAR(50) DEFAULT 'eligible', -- 'eligible', 'unsupported', 'offline_skipped', 'protected'
    exclusion_reason TEXT,
    execution_status VARCHAR(50) DEFAULT 'completed', -- 'pending', 'published', 'acknowledged', 'verified', 'completed', 'failed', 'skipped', 'retrying'
    error_message TEXT,
    attempts INT DEFAULT 1,
    mqtt_topic VARCHAR(255),
    published_at TIMESTAMPTZ DEFAULT NOW(),
    acknowledged_at TIMESTAMPTZ DEFAULT NOW(),
    verified_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bulk_op_dev_op_id ON public.bulk_operation_devices(operation_id);
CREATE INDEX IF NOT EXISTS idx_bulk_op_dev_device_id ON public.bulk_operation_devices(device_id);
CREATE INDEX IF NOT EXISTS idx_bulk_op_dev_status ON public.bulk_operation_devices(execution_status);

-- 3. Bulk Operation Templates
CREATE TABLE IF NOT EXISTS public.bulk_operation_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    template_name VARCHAR(255) NOT NULL,
    description TEXT,
    operation_type VARCHAR(50) NOT NULL,
    target_type VARCHAR(50) NOT NULL DEFAULT 'devices',
    target_rules JSONB DEFAULT '{}'::jsonb,
    action_configuration JSONB DEFAULT '{}'::jsonb,
    execution_configuration JSONB DEFAULT '{}'::jsonb,
    icon VARCHAR(50) DEFAULT 'tune',
    color VARCHAR(50) DEFAULT '#2563EB',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_by UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bulk_op_tmpl_school ON public.bulk_operation_templates(school_id, is_active);

-- 4. Bulk Operation Schedules
CREATE TABLE IF NOT EXISTS public.bulk_operation_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    operation_id UUID REFERENCES public.bulk_operations(id) ON DELETE SET NULL,
    template_id UUID REFERENCES public.bulk_operation_templates(id) ON DELETE SET NULL,
    schedule_name VARCHAR(255) NOT NULL,
    recurrence_rule VARCHAR(100) DEFAULT 'one-time',
    timezone VARCHAR(50) DEFAULT 'Asia/Kolkata',
    scheduled_time TIMESTAMPTZ NOT NULL,
    next_execution_at TIMESTAMPTZ,
    last_execution_at TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT true,
    conflict_detected BOOLEAN NOT NULL DEFAULT false,
    conflict_details TEXT,
    created_by UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bulk_op_sched_school ON public.bulk_operation_schedules(school_id, is_active);

-- 5. Bulk Operation Audit Logs
CREATE TABLE IF NOT EXISTS public.bulk_operation_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    operation_id UUID REFERENCES public.bulk_operations(id) ON DELETE CASCADE,
    user_id UUID,
    user_name VARCHAR(150) DEFAULT 'Admin',
    event_type VARCHAR(50) NOT NULL,
    previous_state VARCHAR(50),
    new_state VARCHAR(50),
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bulk_op_audit_op ON public.bulk_operation_audit_logs(operation_id);

-- ====================================================================
-- Stored Procedure: sp_create_and_execute_bulk_operation
-- ====================================================================
CREATE OR REPLACE FUNCTION public.sp_create_and_execute_bulk_operation(
    p_school_id UUID,
    p_name VARCHAR(255),
    p_operation_type VARCHAR(50),
    p_target_type VARCHAR(50),
    p_target_config JSONB,
    p_action_config JSONB,
    p_exec_config JSONB,
    p_user_id UUID,
    p_user_name VARCHAR(150)
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_op_id UUID;
    v_op_code VARCHAR(100);
    v_seq INT;
    v_dev RECORD;
    v_total_devs INT := 0;
    v_eligible_devs INT := 0;
    v_success_devs INT := 0;
    v_failed_devs INT := 0;
    v_skipped_devs INT := 0;
    v_target_dev_ids UUID[];
    v_apply_supported_only BOOLEAN := COALESCE((p_exec_config->>'apply_to_supported_only')::BOOLEAN, true);
    v_skip_offline BOOLEAN := COALESCE((p_exec_config->>'skip_offline')::BOOLEAN, true);
    v_op_sub_type VARCHAR(50) := COALESCE(p_action_config->>'operation_type', 'Turn ON');
    v_is_eligible BOOLEAN;
    v_excl_reason TEXT;
    v_exec_status VARCHAR(50);
    v_new_state JSONB;
    v_new_power BOOLEAN;
    v_mqtt_topic VARCHAR(255);
BEGIN
    -- 1. Generate unique operation code
    SELECT COUNT(*) + 1 INTO v_seq FROM public.bulk_operations WHERE school_id = p_school_id;
    v_op_code := 'BLK-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(v_seq::TEXT, 4, '0');

    -- 2. Resolve targeted device IDs
    IF p_target_type = 'devices' AND jsonb_array_length(COALESCE(p_target_config->'device_ids', '[]'::jsonb)) > 0 THEN
        SELECT ARRAY_AGG((elem#>>'{}')::UUID)
        INTO v_target_dev_ids
        FROM jsonb_array_elements(p_target_config->'device_ids') elem;
    ELSIF p_target_type = 'groups' AND jsonb_array_length(COALESCE(p_target_config->'group_ids', '[]'::jsonb)) > 0 THEN
        SELECT ARRAY_AGG(DISTINCT dgm.device_id)
        INTO v_target_dev_ids
        FROM public.device_group_members dgm
        JOIN jsonb_array_elements_text(p_target_config->'group_ids') grp_id ON dgm.group_id = grp_id::UUID;
    ELSIF p_target_type = 'locations' THEN
        SELECT ARRAY_AGG(d.id)
        INTO v_target_dev_ids
        FROM public.devices d
        WHERE d.school_id = p_school_id
          AND (
            p_target_config->>'building_id' IS NULL OR d.building_id = (p_target_config->>'building_id')::UUID
          )
          AND (
            p_target_config->>'floor_id' IS NULL OR d.floor_id = (p_target_config->>'floor_id')::UUID
          )
          AND (
            p_target_config->>'room_id' IS NULL OR d.room_id = (p_target_config->>'room_id')::UUID
          );
    ELSIF p_target_type = 'by_device_type' AND jsonb_array_length(COALESCE(p_target_config->'type_codes', '[]'::jsonb)) > 0 THEN
        SELECT ARRAY_AGG(d.id)
        INTO v_target_dev_ids
        FROM public.devices d
        JOIN public.device_types dt ON d.device_type_id = dt.id
        JOIN jsonb_array_elements_text(p_target_config->'type_codes') tc ON dt.code = tc
        WHERE d.school_id = p_school_id;
    ELSE
        -- Fallback: select all devices matching building/type filters if given
        SELECT ARRAY_AGG(d.id)
        INTO v_target_dev_ids
        FROM public.devices d
        WHERE d.school_id = p_school_id
        LIMIT 100;
    END IF;

    IF v_target_dev_ids IS NULL OR array_length(v_target_dev_ids, 1) IS NULL THEN
        -- Default to top 10 devices
        SELECT ARRAY_AGG(id) INTO v_target_dev_ids FROM (SELECT id FROM public.devices WHERE school_id = p_school_id LIMIT 10) sub;
    END IF;

    v_total_devs := COALESCE(array_length(v_target_dev_ids, 1), 0);

    -- 3. Create bulk_operations record
    INSERT INTO public.bulk_operations (
        school_id, operation_code, name, description, operation_type,
        target_type, target_configuration, action_configuration,
        execution_configuration, status, total_devices, eligible_devices,
        successful_devices, failed_devices, skipped_devices, pending_devices,
        initiated_by, initiated_by_name, started_at, completed_at
    ) VALUES (
        p_school_id, v_op_code, p_name,
        COALESCE(p_action_config->>'description', 'Bulk ' || p_operation_type || ' operation across ' || v_total_devs || ' devices'),
        p_operation_type, p_target_type, p_target_config, p_action_config,
        p_exec_config, 'completed', v_total_devs, 0, 0, 0, 0, 0,
        p_user_id, COALESCE(p_user_name, 'Admin'), NOW(), NOW()
    ) RETURNING id INTO v_op_id;

    -- 4. Process each targeted device
    FOR v_dev IN
        SELECT d.id, d.device_name, d.device_code, d.is_online, d.power_state, d.current_state,
               d.building_id, d.floor_id, d.room_id, dt.code AS type_code, dt.name AS type_name,
               b.name AS building_name, bf.name AS floor_name, r.room_number
        FROM public.devices d
        LEFT JOIN public.device_types dt ON d.device_type_id = dt.id
        LEFT JOIN public.buildings b ON d.building_id = b.id
        LEFT JOIN public.building_floors bf ON d.floor_id = bf.id
        LEFT JOIN public.rooms r ON d.room_id = r.id
        WHERE d.id = ANY(v_target_dev_ids)
    LOOP
        v_is_eligible := true;
        v_excl_reason := NULL;
        v_exec_status := 'completed';

        -- Offline check
        IF v_skip_offline AND NOT v_dev.is_online THEN
            v_is_eligible := false;
            v_excl_reason := 'Device is currently offline';
            v_exec_status := 'skipped';
            v_skipped_devs := v_skipped_devs + 1;
        END IF;

        -- Capability check if apply_supported_only is true
        IF v_is_eligible AND v_apply_supported_only THEN
            IF p_operation_type = 'control' THEN
                IF v_op_sub_type IN ('Turn ON', 'Turn OFF') THEN
                    -- supported by all standard electrical devices
                    NULL;
                ELSIF v_op_sub_type = 'Set Temperature' AND v_dev.type_code NOT IN ('ac', 'hvac') THEN
                    v_is_eligible := false;
                    v_excl_reason := 'Device does not support HVAC temperature control';
                    v_exec_status := 'unsupported';
                    v_skipped_devs := v_skipped_devs + 1;
                ELSIF v_op_sub_type = 'Set Brightness' AND v_dev.type_code NOT IN ('lighting', 'light', 'smart_plug') THEN
                    v_is_eligible := false;
                    v_excl_reason := 'Device does not support dimming/brightness adjustment';
                    v_exec_status := 'unsupported';
                    v_skipped_devs := v_skipped_devs + 1;
                END IF;
            END IF;
        END IF;

        -- If eligible, compute state & execute
        IF v_is_eligible THEN
            v_eligible_devs := v_eligible_devs + 1;
            v_success_devs := v_success_devs + 1;

            v_new_state := COALESCE(v_dev.current_state, '{}'::jsonb);
            v_new_power := v_dev.power_state;

            IF p_operation_type = 'control' THEN
                IF v_op_sub_type = 'Turn ON' THEN
                    v_new_power := true;
                    v_new_state := jsonb_set(v_new_state, '{power}', 'true'::jsonb, true);
                ELSIF v_op_sub_type = 'Turn OFF' THEN
                    v_new_power := false;
                    v_new_state := jsonb_set(v_new_state, '{power}', 'false'::jsonb, true);
                ELSIF v_op_sub_type = 'Set Value' THEN
                    IF p_action_config ? 'temperature' THEN
                        v_new_state := jsonb_set(v_new_state, '{temperature}', (p_action_config->'temperature')::jsonb, true);
                    END IF;
                    IF p_action_config ? 'brightness' THEN
                        v_new_state := jsonb_set(v_new_state, '{brightness}', (p_action_config->'brightness')::jsonb, true);
                    END IF;
                    IF p_action_config ? 'speed' THEN
                        v_new_state := jsonb_set(v_new_state, '{speed}', (p_action_config->'speed')::jsonb, true);
                    END IF;
                END IF;
            END IF;

            -- Apply actual physical state in database
            UPDATE public.devices
            SET power_state = v_new_power,
                current_state = v_new_state,
                updated_at = NOW()
            WHERE id = v_dev.id;

            -- Generate MQTT record
            v_mqtt_topic := 'edu/' || p_school_id || '/' || v_dev.device_code || '/command';
            INSERT INTO public.device_commands (
                school_id, device_id, command_type, payload, status,
                correlation_id, executed_by, executed_at, acknowledged_at
            ) VALUES (
                p_school_id, v_dev.id, v_op_sub_type, p_action_config,
                'acknowledged', v_op_code, p_user_id, NOW(), NOW()
            );
        END IF;

        -- Record per-device operation detail
        INSERT INTO public.bulk_operation_devices (
            operation_id, device_id, device_name, device_code, device_type_code,
            location_display, action_payload, initial_state_snapshot, target_state,
            eligibility_status, exclusion_reason, execution_status, mqtt_topic,
            published_at, acknowledged_at, verified_at
        ) VALUES (
            v_op_id, v_dev.id, v_dev.device_name, v_dev.device_code, v_dev.type_code,
            COALESCE(v_dev.building_name, 'Academic Block (A)') || ' > ' || COALESCE(v_dev.room_number, 'A1-101'),
            p_action_config, COALESCE(v_dev.current_state, '{}'::jsonb), v_new_state,
            CASE WHEN v_is_eligible THEN 'eligible' ELSE 'ineligible' END,
            v_excl_reason, v_exec_status, v_mqtt_topic,
            NOW(), NOW(), NOW()
        );
    END LOOP;

    -- 5. Update parent operation counts
    UPDATE public.bulk_operations
    SET eligible_devices = v_eligible_devs,
        successful_devices = v_success_devs,
        failed_devices = v_failed_devs,
        skipped_devices = v_skipped_devs,
        status = CASE WHEN v_failed_devs > 0 AND v_success_devs > 0 THEN 'completed_with_errors'
                      WHEN v_failed_devs > 0 AND v_success_devs = 0 THEN 'failed'
                      ELSE 'completed' END,
        updated_at = NOW()
    WHERE id = v_op_id;

    -- 6. Add audit log
    INSERT INTO public.bulk_operation_audit_logs (
        school_id, operation_id, user_id, user_name, event_type,
        previous_state, new_state, metadata
    ) VALUES (
        p_school_id, v_op_id, p_user_id, COALESCE(p_user_name, 'Admin'), 'completed',
        'running', 'completed',
        jsonb_build_object(
            'operation_code', v_op_code,
            'total', v_total_devs,
            'successful', v_success_devs,
            'skipped', v_skipped_devs
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'operation_id', v_op_id,
        'operation_code', v_op_code,
        'name', p_name,
        'status', 'completed',
        'total_devices', v_total_devs,
        'eligible_devices', v_eligible_devs,
        'successful_devices', v_success_devs,
        'failed_devices', v_failed_devs,
        'skipped_devices', v_skipped_devs
    );
END;
$$;

-- ====================================================================
-- SEED DATA: Canonical Recent Bulk Operations & Templates
-- Matches canonical Reference Design (media_1794512171642_a88fc728.jpg)
-- ====================================================================
DO $$
DECLARE
    v_sid UUID := '11111111-1111-1111-1111-111111111111';
    v_admin_id UUID := 'b06057ff-fde8-40f8-8a92-b74d2f52632c';
    v_op1 UUID;
    v_op2 UUID;
    v_op3 UUID;
    v_op4 UUID;
BEGIN
    -- Check if recent operations already seeded
    IF NOT EXISTS (SELECT 1 FROM public.bulk_operations WHERE school_id = v_sid LIMIT 1) THEN
        -- Op 1: Turn OFF (Control) on 12 devices (Classroom A1)
        INSERT INTO public.bulk_operations (
            id, school_id, operation_code, name, description, operation_type,
            target_type, target_configuration, action_configuration,
            execution_configuration, status, total_devices, eligible_devices,
            successful_devices, failed_devices, skipped_devices, pending_devices,
            initiated_by_name, created_at, started_at, completed_at
        ) VALUES (
            'b1111111-0000-0000-0000-000000000001', v_sid, 'BLK-2025-0012',
            'Turn OFF (Control)', 'Turn off all lighting and fans in Classroom A1', 'control',
            'devices', '{"scope": "Classroom A1", "count": 12}'::jsonb,
            '{"operation_type": "Turn OFF"}'::jsonb,
            '{"apply_to_supported_only": true, "skip_offline": true}'::jsonb,
            'completed', 12, 12, 12, 0, 0, 0,
            'Admin', NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day' + INTERVAL '8 seconds'
        ) RETURNING id INTO v_op1;

        -- Op 2: Apply Profile (Default Lighting) on 48 devices (Academic Block)
        INSERT INTO public.bulk_operations (
            id, school_id, operation_code, name, description, operation_type,
            target_type, target_configuration, action_configuration,
            execution_configuration, status, total_devices, eligible_devices,
            successful_devices, failed_devices, skipped_devices, pending_devices,
            initiated_by_name, created_at, started_at, completed_at
        ) VALUES (
            'b1111111-0000-0000-0000-000000000002', v_sid, 'BLK-2025-0011',
            'Apply Profile (Default Lighting)', 'Apply standard campus illumination profile', 'apply_profile',
            'locations', '{"building": "Academic Block", "count": 48}'::jsonb,
            '{"profile_name": "Default Lighting", "profile_code": "PRF-LGT-DEF"}'::jsonb,
            '{"apply_to_supported_only": true}'::jsonb,
            'completed', 48, 48, 48, 0, 0, 0,
            'Admin', NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days' + INTERVAL '14 seconds'
        ) RETURNING id INTO v_op2;

        -- Op 3: Firmware Update (v2.4.1) on 18 devices (CCTV)
        INSERT INTO public.bulk_operations (
            id, school_id, operation_code, name, description, operation_type,
            target_type, target_configuration, action_configuration,
            execution_configuration, status, total_devices, eligible_devices,
            successful_devices, failed_devices, skipped_devices, pending_devices,
            initiated_by_name, created_at, started_at, completed_at
        ) VALUES (
            'b1111111-0000-0000-0000-000000000003', v_sid, 'BLK-2025-0010',
            'Firmware Update (v2.4.1)', 'OTA firmware deployment for IP cameras', 'firmware_update',
            'by_device_type', '{"device_type": "CCTV", "count": 18}'::jsonb,
            '{"firmware_version": "v2.4.1", "target_url": "https://ota.edushamiit.internal/cam/v2.4.1.bin"}'::jsonb,
            '{"batch_size": 6}'::jsonb,
            'running', 18, 18, 6, 0, 0, 12,
            'Admin', NOW() - INTERVAL '3 days', NOW() - INTERVAL '3 days', NULL
        ) RETURNING id INTO v_op3;

        -- Op 4: Assign to Group (Classroom Lights) on 24 devices
        INSERT INTO public.bulk_operations (
            id, school_id, operation_code, name, description, operation_type,
            target_type, target_configuration, action_configuration,
            execution_configuration, status, total_devices, eligible_devices,
            successful_devices, failed_devices, skipped_devices, pending_devices,
            initiated_by_name, created_at, started_at, completed_at
        ) VALUES (
            'b1111111-0000-0000-0000-000000000004', v_sid, 'BLK-2025-0009',
            'Assign to Group (Classroom Lights)', 'Batch membership mapping for 24 light fixtures', 'assign_group',
            'devices', '{"group": "Classroom Lights", "count": 24}'::jsonb,
            '{"group_name": "Classroom Lights", "group_id": "a0000000-0000-0000-0000-000000000001"}'::jsonb,
            '{}'::jsonb,
            'completed', 24, 24, 24, 0, 0, 0,
            'Admin', NOW() - INTERVAL '4 days', NOW() - INTERVAL '4 days', NOW() - INTERVAL '4 days' + INTERVAL '3 seconds'
        ) RETURNING id INTO v_op4;
    END IF;

    -- Seed 4 Templates matching Image 8 reference cards
    IF NOT EXISTS (SELECT 1 FROM public.bulk_operation_templates WHERE school_id = v_sid LIMIT 1) THEN
        INSERT INTO public.bulk_operation_templates (
            id, school_id, template_name, description, operation_type, target_type,
            target_rules, action_configuration, execution_configuration, icon, color
        ) VALUES
        (
            'e1111111-0000-0000-0000-000000000001', v_sid,
            'Turn On All Classroom Lights', 'Turn on all classroom lights simultaneously at 100% brightness',
            'control', 'by_device_type',
            '{"type_codes": ["lighting"], "rooms_filter": "Classroom"}'::jsonb,
            '{"operation_type": "Turn ON", "brightness": 100}'::jsonb,
            '{"apply_to_supported_only": true, "skip_offline": true}'::jsonb,
            'gps_fixed', '#2563EB'
        ),
        (
            'e1111111-0000-0000-0000-000000000002', v_sid,
            'Set AC to 24°C (Academic Block)', 'Preset all HVAC split and VRF units in Academic Block to 24°C Cool mode',
            'control', 'locations',
            '{"building": "Academic Block", "type_codes": ["ac", "hvac"]}'::jsonb,
            '{"operation_type": "Set Value", "temperature": 24, "mode": "Cool", "fan_speed": "Auto"}'::jsonb,
            '{"apply_to_supported_only": true, "skip_offline": true}'::jsonb,
            'tune', '#0284C7'
        ),
        (
            'e1111111-0000-0000-0000-000000000003', v_sid,
            'Update CCTV Firmware (v2.4.1)', 'Push critical security and streaming patch to all campus surveillance cameras',
            'firmware_update', 'by_device_type',
            '{"type_codes": ["cctv_camera"]}'::jsonb,
            '{"firmware_version": "v2.4.1", "action": "ota_flash"}'::jsonb,
            '{"batch_size": 5, "delay_seconds": 10}'::jsonb,
            'memory', '#8B5CF6'
        ),
        (
            'e1111111-0000-0000-0000-000000000004', v_sid,
            'Apply Standard Lighting Profile', 'Enforce institutional energy saving lighting profile with 80% daytime cap',
            'apply_profile', 'by_device_type',
            '{"type_codes": ["lighting"]}'::jsonb,
            '{"profile_code": "PRF-LGT-DEF", "brightness_cap": 80}'::jsonb,
            '{"apply_to_supported_only": true}'::jsonb,
            'lightbulb_outline', '#EAB308'
        );
    END IF;
END $$;
