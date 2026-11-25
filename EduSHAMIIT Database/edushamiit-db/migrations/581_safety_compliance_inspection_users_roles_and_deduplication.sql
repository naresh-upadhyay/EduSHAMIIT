-- ============================================================================
-- MIGRATION 581: Safety Compliance Inspection Users, Roles & Lookup Keys
-- 1. Deduplicates double-clicked test inspection (SI-2026-008)
-- 2. Inserts canonical safety lookup keys & values into lookup_keys & lookup_values
-- 3. Updates sp_create_or_update_safety_inspection to support inspector_user_id on update
-- 4. Updates sp_list_safety_inspections to return inspector_user_id
-- ============================================================================

-- Step 1: Clean duplicate record created by double-click
DELETE FROM public.safety_inspections 
WHERE inspection_code = 'SI-2026-008' AND title = 'MASTER';

-- Step 2: Ensure canonical Safety & Compliance Lookup Keys exist in public.lookup_keys
DO $$
DECLARE
    v_school_id UUID;
    v_admin_id UUID;
    v_key_id UUID;
BEGIN
    SELECT id INTO v_school_id
    FROM public.schools
    ORDER BY (id = '11111111-1111-1111-1111-111111111111') DESC, created_at ASC
    LIMIT 1;

    IF v_school_id IS NULL THEN
        RETURN;
    END IF;

    SELECT id INTO v_admin_id
    FROM public.profiles
    ORDER BY (id = '10000000-0000-0000-0000-000000000001') DESC,
             (role = 'super_admin') DESC,
             created_at ASC
    LIMIT 1;
    -- 1. INSPECTION_CATEGORY
    SELECT id INTO v_key_id FROM public.lookup_keys WHERE key_code = 'INSPECTION_CATEGORY' AND school_id = v_school_id;
    IF v_key_id IS NULL THEN
        v_key_id := gen_random_uuid();
        INSERT INTO public.lookup_keys (id, school_id, key_name, key_code, description, key_type, icon, status, created_by)
        VALUES (v_key_id, v_school_id, 'Inspection Category', 'INSPECTION_CATEGORY', 'Standard safety, quality and structural inspection categories.', 'SYSTEM', 'fact_check_rounded', 'ACTIVE', v_admin_id);

        INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, sort_order, status, created_by) VALUES
        (gen_random_uuid(), v_key_id, v_school_id, 'Fire Safety', 'FIRE_SAFETY', 1, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Electrical Safety', 'ELECTRICAL_SAFETY', 2, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Lab & Chemical Safety', 'LAB_CHEMICAL_SAFETY', 3, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Structural Integrity', 'STRUCTURAL_INTEGRITY', 4, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Sanitation & Hygiene', 'SANITATION_HYGIENE', 5, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'CCTV & Physical Security', 'CCTV_PHYSICAL_SECURITY', 6, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Sports & Playground', 'SPORTS_PLAYGROUND', 7, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Food & Water Safety', 'FOOD_WATER_SAFETY', 8, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Air Quality & HVAC', 'AIR_QUALITY_HVAC', 9, 'ACTIVE', v_admin_id);
    END IF;

    -- 2. INSPECTION_STATUS
    SELECT id INTO v_key_id FROM public.lookup_keys WHERE key_code = 'INSPECTION_STATUS' AND school_id = v_school_id;
    IF v_key_id IS NULL THEN
        v_key_id := gen_random_uuid();
        INSERT INTO public.lookup_keys (id, school_id, key_name, key_code, description, key_type, icon, status, created_by)
        VALUES (v_key_id, v_school_id, 'Inspection Status', 'INSPECTION_STATUS', 'Lifecycle statuses for safety audits and quality inspections.', 'SYSTEM', 'verified_rounded', 'ACTIVE', v_admin_id);

        INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, sort_order, status, created_by) VALUES
        (gen_random_uuid(), v_key_id, v_school_id, 'Scheduled', 'SCHEDULED', 1, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Passed', 'PASSED', 2, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Needs Attention', 'NEEDS_ATTENTION', 3, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Critical Action', 'CRITICAL_ACTION', 4, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'In Progress', 'IN_PROGRESS', 5, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Closed', 'CLOSED', 6, 'ACTIVE', v_admin_id);
    END IF;

    -- 3. INSPECTION_ROLE
    SELECT id INTO v_key_id FROM public.lookup_keys WHERE key_code = 'INSPECTION_ROLE' AND school_id = v_school_id;
    IF v_key_id IS NULL THEN
        v_key_id := gen_random_uuid();
        INSERT INTO public.lookup_keys (id, school_id, key_name, key_code, description, key_type, icon, status, created_by)
        VALUES (v_key_id, v_school_id, 'Inspection Inspector Role', 'INSPECTION_ROLE', 'Authorized safety auditor and inspection roles.', 'SYSTEM', 'badge_rounded', 'ACTIVE', v_admin_id);

        INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, sort_order, status, created_by) VALUES
        (gen_random_uuid(), v_key_id, v_school_id, 'Safety Officer', 'SAFETY_OFFICER', 1, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Fire Marshal', 'FIRE_MARSHAL', 2, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Facilities Head', 'FACILITIES_HEAD', 3, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'External Auditor', 'EXTERNAL_AUDITOR', 4, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Chief Security Officer', 'CHIEF_SECURITY_OFFICER', 5, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Senior Electrical Engineer', 'SENIOR_ELECTRICAL_ENGINEER', 6, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Campus Administrator', 'CAMPUS_ADMIN', 7, 'ACTIVE', v_admin_id);
    END IF;

    -- 4. INCIDENT_SEVERITY
    SELECT id INTO v_key_id FROM public.lookup_keys WHERE key_code = 'INCIDENT_SEVERITY' AND school_id = v_school_id;
    IF v_key_id IS NULL THEN
        v_key_id := gen_random_uuid();
        INSERT INTO public.lookup_keys (id, school_id, key_name, key_code, description, key_type, icon, status, created_by)
        VALUES (v_key_id, v_school_id, 'Incident Severity', 'INCIDENT_SEVERITY', 'Severity classifications for campus incidents.', 'SYSTEM', 'report_problem_rounded', 'ACTIVE', v_admin_id);

        INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, sort_order, status, created_by) VALUES
        (gen_random_uuid(), v_key_id, v_school_id, 'Low', 'LOW', 1, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Medium', 'MEDIUM', 2, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'High', 'HIGH', 3, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Critical', 'CRITICAL', 4, 'ACTIVE', v_admin_id);
    END IF;

    -- 5. INCIDENT_STATUS
    SELECT id INTO v_key_id FROM public.lookup_keys WHERE key_code = 'INCIDENT_STATUS' AND school_id = v_school_id;
    IF v_key_id IS NULL THEN
        v_key_id := gen_random_uuid();
        INSERT INTO public.lookup_keys (id, school_id, key_name, key_code, description, key_type, icon, status, created_by)
        VALUES (v_key_id, v_school_id, 'Incident Status', 'INCIDENT_STATUS', 'Workflow statuses for reported security & safety incidents.', 'SYSTEM', 'pending_actions_rounded', 'ACTIVE', v_admin_id);

        INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, sort_order, status, created_by) VALUES
        (gen_random_uuid(), v_key_id, v_school_id, 'Reported', 'REPORTED', 1, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Under Investigation', 'UNDER_INVESTIGATION', 2, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Action Taken', 'ACTION_TAKEN', 3, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Resolved', 'RESOLVED', 4, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Closed', 'CLOSED', 5, 'ACTIVE', v_admin_id);
    END IF;

    -- 6. CERTIFICATE_TYPE
    SELECT id INTO v_key_id FROM public.lookup_keys WHERE key_code = 'CERTIFICATE_TYPE' AND school_id = v_school_id;
    IF v_key_id IS NULL THEN
        v_key_id := gen_random_uuid();
        INSERT INTO public.lookup_keys (id, school_id, key_name, key_code, description, key_type, icon, status, created_by)
        VALUES (v_key_id, v_school_id, 'Compliance Certificate Type', 'CERTIFICATE_TYPE', 'Statutory NOC, health & safety compliance certificates.', 'SYSTEM', 'card_membership_rounded', 'ACTIVE', v_admin_id);

        INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, sort_order, status, created_by) VALUES
        (gen_random_uuid(), v_key_id, v_school_id, 'Fire Safety NOC & Clearance', 'FIRE_SAFETY_NOC', 1, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Building Structural Safety Certificate', 'STRUCTURAL_SAFETY', 2, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Electrical Installation Fitness Certificate', 'ELECTRICAL_FITNESS', 3, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Elevator / Lift Operating License', 'ELEVATOR_LICENSE', 4, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Sanitation & Public Hygiene Certificate', 'SANITATION_HYGIENE', 5, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Potable Drinking Water Quality Certificate', 'DRINKING_WATER', 6, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Pollution Control / DG Set Clearance', 'POLLUTION_CONTROL', 7, 'ACTIVE', v_admin_id);
    END IF;

    -- 7. DRILL_TYPE
    SELECT id INTO v_key_id FROM public.lookup_keys WHERE key_code = 'DRILL_TYPE' AND school_id = v_school_id;
    IF v_key_id IS NULL THEN
        v_key_id := gen_random_uuid();
        INSERT INTO public.lookup_keys (id, school_id, key_name, key_code, description, key_type, icon, status, created_by)
        VALUES (v_key_id, v_school_id, 'Safety Drill Type', 'DRILL_TYPE', 'Emergency drill and evacuation exercise classifications.', 'SYSTEM', 'campaign_rounded', 'ACTIVE', v_admin_id);

        INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, sort_order, status, created_by) VALUES
        (gen_random_uuid(), v_key_id, v_school_id, 'Fire Evacuation & Alarm Response Drill', 'FIRE_EVACUATION', 1, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Earthquake Preparedness & Drop-Cover Drill', 'EARTHQUAKE_PREPAREDNESS', 2, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Lockdown / Active Intruder Simulation', 'LOCKDOWN_INTRUDER', 3, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Medical Emergency & First Aid Response Drill', 'MEDICAL_TRIAGE', 4, 'ACTIVE', v_admin_id),
        (gen_random_uuid(), v_key_id, v_school_id, 'Severe Weather / Storm Shelter Drill', 'SEVERE_WEATHER', 5, 'ACTIVE', v_admin_id);
    END IF;

END $$;

-- Step 3: Upgrade sp_create_or_update_safety_inspection
CREATE OR REPLACE FUNCTION public.sp_create_or_update_safety_inspection(p_payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_id UUID;
    v_school_id UUID;
    v_inspection_code VARCHAR(50);
    v_seq INT;
BEGIN
    v_school_id := (p_payload->>'school_id')::UUID;
    v_id := NULLIF(p_payload->>'id', '')::UUID;

    IF v_id IS NOT NULL AND EXISTS(SELECT 1 FROM public.safety_inspections WHERE id = v_id AND school_id = v_school_id) THEN
        UPDATE public.safety_inspections
        SET title = COALESCE(p_payload->>'title', title),
            category = COALESCE(p_payload->>'category', category),
            building_id = NULLIF(p_payload->>'building_id', '')::UUID,
            floor_id = NULLIF(p_payload->>'floor_id', '')::UUID,
            room_id = NULLIF(p_payload->>'room_id', '')::UUID,
            location_display = COALESCE(p_payload->>'location_display', location_display),
            inspector_name = COALESCE(p_payload->>'inspector_name', inspector_name),
            inspector_role = COALESCE(p_payload->>'inspector_role', inspector_role),
            inspector_user_id = COALESCE(NULLIF(p_payload->>'inspector_user_id', '')::UUID, inspector_user_id),
            inspection_date = COALESCE(NULLIF(p_payload->>'inspection_date', '')::DATE, inspection_date),
            status = COALESCE(p_payload->>'status', status),
            compliance_score = COALESCE((p_payload->>'compliance_score')::NUMERIC, compliance_score),
            findings = COALESCE(p_payload->>'findings', findings),
            action_items = COALESCE(p_payload->'action_items', action_items),
            next_inspection_date = NULLIF(p_payload->>'next_inspection_date', '')::DATE,
            updated_at = NOW()
        WHERE id = v_id AND school_id = v_school_id;

        SELECT inspection_code INTO v_inspection_code FROM public.safety_inspections WHERE id = v_id;
    ELSE
        v_id := COALESCE(v_id, gen_random_uuid());
        SELECT COUNT(*) + 1 INTO v_seq FROM public.safety_inspections WHERE school_id = v_school_id;
        v_inspection_code := 'SI-' || TO_CHAR(CURRENT_DATE, 'YYYY') || '-' || LPAD(v_seq::TEXT, 3, '0');

        INSERT INTO public.safety_inspections (
            id, school_id, inspection_code, title, category,
            building_id, floor_id, room_id, location_display,
            inspector_name, inspector_role, inspector_user_id,
            inspection_date, status, compliance_score, findings,
            action_items, next_inspection_date
        ) VALUES (
            v_id, v_school_id, v_inspection_code,
            COALESCE(p_payload->>'title', 'Routine Safety Inspection'),
            COALESCE(p_payload->>'category', 'Fire Safety'),
            NULLIF(p_payload->>'building_id', '')::UUID,
            NULLIF(p_payload->>'floor_id', '')::UUID,
            NULLIF(p_payload->>'room_id', '')::UUID,
            COALESCE(p_payload->>'location_display', 'Main Campus'),
            COALESCE(p_payload->>'inspector_name', 'Campus Safety Inspector'),
            COALESCE(p_payload->>'inspector_role', 'Safety Officer'),
            NULLIF(p_payload->>'inspector_user_id', '')::UUID,
            COALESCE(NULLIF(p_payload->>'inspection_date', '')::DATE, CURRENT_DATE),
            COALESCE(p_payload->>'status', 'Passed'),
            COALESCE((p_payload->>'compliance_score')::NUMERIC, 95.0),
            p_payload->>'findings',
            COALESCE(p_payload->'action_items', '[]'::JSONB),
            NULLIF(p_payload->>'next_inspection_date', '')::DATE
        );
    END IF;

    RETURN jsonb_build_object('success', TRUE, 'id', v_id, 'inspection_code', v_inspection_code);
END;
$$;

-- Step 4: Upgrade sp_list_safety_inspections to return inspector_user_id
CREATE OR REPLACE FUNCTION public.sp_list_safety_inspections(
    p_school_id UUID,
    p_category VARCHAR DEFAULT NULL,
    p_status VARCHAR DEFAULT NULL,
    p_building_id UUID DEFAULT NULL,
    p_search VARCHAR DEFAULT NULL,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10
)
RETURNS TABLE (
    total_count BIGINT,
    records JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_offset INT;
    v_total BIGINT;
    v_records JSONB;
BEGIN
    v_offset := (GREATEST(p_page, 1) - 1) * GREATEST(p_page_size, 1);

    SELECT COUNT(*)
    INTO v_total
    FROM public.safety_inspections si
    WHERE si.school_id = p_school_id
      AND si.deleted_at IS NULL
      AND (p_category IS NULL OR p_category = '' OR p_category ILIKE 'All%' OR si.category ILIKE p_category)
      AND (p_status IS NULL OR p_status = '' OR p_status ILIKE 'All%' OR si.status ILIKE p_status)
      AND (p_building_id IS NULL OR si.building_id = p_building_id)
      AND (p_search IS NULL OR p_search = '' OR 
           si.inspection_code ILIKE '%' || p_search || '%' OR
           si.title ILIKE '%' || p_search || '%' OR
           si.location_display ILIKE '%' || p_search || '%' OR
           si.inspector_name ILIKE '%' || p_search || '%');

    SELECT COALESCE(jsonb_agg(sub.r), '[]'::JSONB)
    INTO v_records
    FROM (
        SELECT jsonb_build_object(
            'id', si.id,
            'inspection_code', si.inspection_code,
            'title', si.title,
            'category', si.category,
            'building_id', si.building_id,
            'building_name', b.name,
            'location_display', si.location_display,
            'inspector_name', si.inspector_name,
            'inspector_role', si.inspector_role,
            'inspector_user_id', si.inspector_user_id,
            'inspection_date', si.inspection_date,
            'status', si.status,
            'compliance_score', si.compliance_score,
            'findings', si.findings,
            'action_items', si.action_items,
            'next_inspection_date', si.next_inspection_date,
            'created_at', si.created_at
        ) AS r
        FROM public.safety_inspections si
        LEFT JOIN public.buildings b ON si.building_id = b.id
        WHERE si.school_id = p_school_id
          AND si.deleted_at IS NULL
          AND (p_category IS NULL OR p_category = '' OR p_category ILIKE 'All%' OR si.category ILIKE p_category)
          AND (p_status IS NULL OR p_status = '' OR p_status ILIKE 'All%' OR si.status ILIKE p_status)
          AND (p_building_id IS NULL OR si.building_id = p_building_id)
          AND (p_search IS NULL OR p_search = '' OR 
               si.inspection_code ILIKE '%' || p_search || '%' OR
               si.title ILIKE '%' || p_search || '%' OR
               si.location_display ILIKE '%' || p_search || '%' OR
               si.inspector_name ILIKE '%' || p_search || '%')
        ORDER BY si.inspection_date DESC, si.created_at DESC
        LIMIT p_page_size OFFSET v_offset
    ) sub;

    RETURN QUERY SELECT v_total, v_records;
END;
$$;
