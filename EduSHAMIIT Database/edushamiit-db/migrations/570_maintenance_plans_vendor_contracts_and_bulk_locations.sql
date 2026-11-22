-- ============================================================================
-- Migration 570: Maintenance Plans, Vendor Contracts & Multi-Location Enhancements
-- Description:
--   1. Adds vendor contract metadata (value, ref no, document attachments, notes)
--   2. Adds maintenance plan multi-location targets, vendor communication (phone, email, automated dispatch)
--      and recurrence intervals (e.g. 6-month AC servicing).
--   3. Adds facility_id and vendor contact fields to maintenance requests.
--   4. Upgrades sp_list_maintenance_requests with sort_by & sort_order and facility joins.
-- ============================================================================

ALTER TABLE public.maintenance_vendors 
    ADD COLUMN IF NOT EXISTS contract_ref_no VARCHAR(100),
    ADD COLUMN IF NOT EXISTS contract_value NUMERIC(12, 2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS agreement_url TEXT,
    ADD COLUMN IF NOT EXISTS contract_document_name VARCHAR(255),
    ADD COLUMN IF NOT EXISTS attachments JSONB DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS notes TEXT,
    ADD COLUMN IF NOT EXISTS address TEXT,
    ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

ALTER TABLE public.maintenance_plans
    ADD COLUMN IF NOT EXISTS facility_id UUID,
    ADD COLUMN IF NOT EXISTS floor_id UUID,
    ADD COLUMN IF NOT EXISTS target_locations JSONB DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS vendor_id UUID,
    ADD COLUMN IF NOT EXISTS vendor_name VARCHAR(150),
    ADD COLUMN IF NOT EXISTS vendor_phone VARCHAR(50),
    ADD COLUMN IF NOT EXISTS vendor_email VARCHAR(150),
    ADD COLUMN IF NOT EXISTS send_vendor_email BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS recurrence_interval_months INTEGER DEFAULT 1,
    ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

ALTER TABLE public.maintenance_requests
    ADD COLUMN IF NOT EXISTS facility_id UUID,
    ADD COLUMN IF NOT EXISTS vendor_phone VARCHAR(50),
    ADD COLUMN IF NOT EXISTS vendor_email VARCHAR(150),
    ADD COLUMN IF NOT EXISTS send_vendor_email BOOLEAN DEFAULT FALSE;

CREATE OR REPLACE FUNCTION public.sp_list_maintenance_requests(
    p_school_id UUID,
    p_view VARCHAR DEFAULT 'all',
    p_user_id UUID DEFAULT NULL,
    p_building_id UUID DEFAULT NULL,
    p_location VARCHAR DEFAULT NULL,
    p_type VARCHAR DEFAULT NULL,
    p_status VARCHAR DEFAULT NULL,
    p_priority VARCHAR DEFAULT NULL,
    p_search VARCHAR DEFAULT NULL,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_sort_by VARCHAR DEFAULT 'reported_at',
    p_sort_order VARCHAR DEFAULT 'DESC'
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
    v_eff_user_id UUID;
BEGIN
    v_offset := GREATEST(0, (p_page - 1) * p_page_size);
    v_eff_user_id := COALESCE(p_user_id, '00000000-0000-0000-0000-000000000001'::UUID);

    -- Compute filtered count
    SELECT COUNT(*)
    INTO v_total
    FROM public.maintenance_requests mr
    WHERE mr.school_id = p_school_id
      AND mr.deleted_at IS NULL
      -- View filters
      AND (
          p_view = 'all' OR
          (p_view = 'my_requests' AND mr.reported_by_user_id = v_eff_user_id) OR
          (p_view = 'assigned_to_me' AND mr.assigned_to_user_id = v_eff_user_id) OR
          (p_view = 'overdue' AND (mr.is_overdue = TRUE OR (mr.status NOT IN ('Resolved', 'Closed', 'Cancelled') AND mr.due_date < NOW()))) OR
          (p_view = 'high_priority' AND mr.priority IN ('High', 'Critical')) OR
          (p_view = 'scheduled' AND mr.status = 'Scheduled') OR
          (p_view = 'preventive' AND mr.is_preventive = TRUE) OR
          (p_view = 'plans' AND (mr.plan_id IS NOT NULL OR mr.is_preventive = TRUE)) OR
          (p_view = 'assets' AND (mr.equipment_id IS NOT NULL OR mr.asset_id IS NOT NULL)) OR
          (p_view = 'vendors' AND (mr.assigned_vendor_id IS NOT NULL OR mr.assigned_vendor_name IS NOT NULL)) OR
          (p_view NOT IN ('my_requests', 'assigned_to_me', 'overdue', 'high_priority', 'scheduled', 'preventive', 'plans', 'assets', 'vendors'))
      )
      AND (p_building_id IS NULL OR mr.building_id = p_building_id)
      AND (p_location IS NULL OR p_location = '' OR p_location = 'All' OR mr.location_display ILIKE '%' || p_location || '%')
      AND (p_type IS NULL OR p_type = '' OR p_type = 'All' OR mr.request_type ILIKE p_type || '%')
      AND (p_status IS NULL OR p_status = '' OR p_status = 'All' OR mr.status ILIKE p_status)
      AND (p_priority IS NULL OR p_priority = '' OR p_priority = 'All' OR mr.priority ILIKE p_priority)
      AND (p_start_date IS NULL OR mr.reported_at >= p_start_date::TIMESTAMPTZ)
      AND (p_end_date IS NULL OR mr.reported_at <= (p_end_date + INTERVAL '1 day')::TIMESTAMPTZ)
      AND (
          p_search IS NULL OR p_search = '' OR
          mr.request_code ILIKE '%' || p_search || '%' OR
          mr.title ILIKE '%' || p_search || '%' OR
          mr.location_display ILIKE '%' || p_search || '%' OR
          mr.reported_by_name ILIKE '%' || p_search || '%'
      );

    -- Fetch paginated records with dynamic sorting
    SELECT COALESCE(jsonb_agg(to_jsonb(sub)), '[]'::JSONB)
    INTO v_records
    FROM (
        SELECT 
            mr.id,
            mr.request_code,
            mr.title,
            mr.description,
            mr.request_type,
            mr.priority,
            mr.status,
            mr.location_display,
            mr.building_id,
            b.name AS building_name,
            mr.floor_id,
            mr.room_id,
            r.room_number,
            mr.facility_id,
            cf.name AS facility_name,
            mr.equipment_id,
            re.equipment_name AS equipment_name,
            mr.reported_by_name,
            mr.reported_by_role,
            mr.reported_by_user_id,
            mr.reported_at,
            mr.preferred_date,
            mr.preferred_time,
            mr.due_date,
            mr.sla_hours,
            mr.is_overdue,
            mr.assigned_to_name,
            mr.assigned_to_user_id,
            mr.assigned_vendor_name,
            mr.vendor_phone,
            mr.vendor_email,
            mr.scheduled_at,
            mr.started_at,
            mr.resolved_at,
            mr.closed_at,
            mr.resolution_notes,
            mr.is_preventive,
            mr.estimated_cost,
            mr.actual_cost,
            mr.created_at
        FROM public.maintenance_requests mr
        LEFT JOIN public.buildings b ON b.id = mr.building_id
        LEFT JOIN public.rooms r ON r.id = mr.room_id
        LEFT JOIN public.campus_facilities cf ON cf.id = mr.facility_id
        LEFT JOIN public.room_equipment re ON re.id = mr.equipment_id
        WHERE mr.school_id = p_school_id
          AND mr.deleted_at IS NULL
          AND (
              p_view = 'all' OR
              (p_view = 'my_requests' AND mr.reported_by_user_id = v_eff_user_id) OR
              (p_view = 'assigned_to_me' AND mr.assigned_to_user_id = v_eff_user_id) OR
              (p_view = 'overdue' AND (mr.is_overdue = TRUE OR (mr.status NOT IN ('Resolved', 'Closed', 'Cancelled') AND mr.due_date < NOW()))) OR
              (p_view = 'high_priority' AND mr.priority IN ('High', 'Critical')) OR
              (p_view = 'scheduled' AND mr.status = 'Scheduled') OR
              (p_view = 'preventive' AND mr.is_preventive = TRUE) OR
              (p_view = 'plans' AND (mr.plan_id IS NOT NULL OR mr.is_preventive = TRUE)) OR
              (p_view = 'assets' AND (mr.equipment_id IS NOT NULL OR mr.asset_id IS NOT NULL)) OR
              (p_view = 'vendors' AND (mr.assigned_vendor_id IS NOT NULL OR mr.assigned_vendor_name IS NOT NULL)) OR
              (p_view NOT IN ('my_requests', 'assigned_to_me', 'overdue', 'high_priority', 'scheduled', 'preventive', 'plans', 'assets', 'vendors'))
          )
          AND (p_building_id IS NULL OR mr.building_id = p_building_id)
          AND (p_location IS NULL OR p_location = '' OR p_location = 'All' OR mr.location_display ILIKE '%' || p_location || '%')
          AND (p_type IS NULL OR p_type = '' OR p_type = 'All' OR mr.request_type ILIKE p_type || '%')
          AND (p_status IS NULL OR p_status = '' OR p_status = 'All' OR mr.status ILIKE p_status)
          AND (p_priority IS NULL OR p_priority = '' OR p_priority = 'All' OR mr.priority ILIKE p_priority)
          AND (p_start_date IS NULL OR mr.reported_at >= p_start_date::TIMESTAMPTZ)
          AND (p_end_date IS NULL OR mr.reported_at <= (p_end_date + INTERVAL '1 day')::TIMESTAMPTZ)
          AND (
              p_search IS NULL OR p_search = '' OR
              mr.request_code ILIKE '%' || p_search || '%' OR
              mr.title ILIKE '%' || p_search || '%' OR
              mr.location_display ILIKE '%' || p_search || '%' OR
              mr.reported_by_name ILIKE '%' || p_search || '%'
          )
        ORDER BY 
            CASE WHEN p_sort_by = 'request_code' AND p_sort_order ILIKE 'ASC' THEN mr.request_code END ASC,
            CASE WHEN p_sort_by = 'request_code' AND p_sort_order ILIKE 'DESC' THEN mr.request_code END DESC,
            CASE WHEN p_sort_by = 'title' AND p_sort_order ILIKE 'ASC' THEN mr.title END ASC,
            CASE WHEN p_sort_by = 'title' AND p_sort_order ILIKE 'DESC' THEN mr.title END DESC,
            CASE WHEN p_sort_by = 'location_display' AND p_sort_order ILIKE 'ASC' THEN mr.location_display END ASC,
            CASE WHEN p_sort_by = 'location_display' AND p_sort_order ILIKE 'DESC' THEN mr.location_display END DESC,
            CASE WHEN p_sort_by = 'request_type' AND p_sort_order ILIKE 'ASC' THEN mr.request_type END ASC,
            CASE WHEN p_sort_by = 'request_type' AND p_sort_order ILIKE 'DESC' THEN mr.request_type END DESC,
            CASE WHEN p_sort_by = 'priority' AND p_sort_order ILIKE 'ASC' THEN mr.priority END ASC,
            CASE WHEN p_sort_by = 'priority' AND p_sort_order ILIKE 'DESC' THEN mr.priority END DESC,
            CASE WHEN p_sort_by = 'status' AND p_sort_order ILIKE 'ASC' THEN mr.status END ASC,
            CASE WHEN p_sort_by = 'status' AND p_sort_order ILIKE 'DESC' THEN mr.status END DESC,
            CASE WHEN p_sort_by = 'reported_by_name' AND p_sort_order ILIKE 'ASC' THEN mr.reported_by_name END ASC,
            CASE WHEN p_sort_by = 'reported_by_name' AND p_sort_order ILIKE 'DESC' THEN mr.reported_by_name END DESC,
            CASE WHEN (p_sort_by = 'reported_at' OR p_sort_by IS NULL OR p_sort_by = '') AND p_sort_order ILIKE 'ASC' THEN mr.reported_at END ASC,
            CASE WHEN (p_sort_by = 'reported_at' OR p_sort_by IS NULL OR p_sort_by = '') AND (p_sort_order ILIKE 'DESC' OR p_sort_order IS NULL OR p_sort_order = '') THEN mr.reported_at END DESC,
            mr.created_at DESC
        LIMIT p_page_size OFFSET v_offset
    ) sub;

    RETURN QUERY SELECT v_total, v_records;
END;
$$;
