-- Migration 417: Fix Hostel Complaints Subtab KPI Sync and Date Range Filtering
-- Ensures all 6 KPI cards (Total, Resolved, Pending, Overdue, High Priority, Maintenance)
-- exactly match grid counts, and implements date range filtering (from_date / to_date).

CREATE OR REPLACE FUNCTION public.fn_hostel_complaints_list(
    p_school_id UUID,
    p_filters JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_search TEXT := TRIM(COALESCE(p_filters->>'search', ''));
    v_hostel_filter TEXT := TRIM(COALESCE(p_filters->>'hostel', 'All Hostels'));
    v_category_filter TEXT := TRIM(COALESCE(p_filters->>'category', 'All Categories'));
    v_priority_filter TEXT := TRIM(COALESCE(p_filters->>'priority', 'All Priorities'));
    v_status_filter TEXT := TRIM(COALESCE(p_filters->>'status', 'All Status'));
    v_subtab_filter TEXT := TRIM(COALESCE(p_filters->>'subtab', 'All Complaints'));
    v_from_date TEXT := TRIM(COALESCE(p_filters->>'from_date', ''));
    v_to_date TEXT := TRIM(COALESCE(p_filters->>'to_date', ''));
    v_user_id TEXT := TRIM(COALESCE(p_filters->>'user_id', ''));
    v_page INT := GREATEST(COALESCE((p_filters->>'page')::INT, 1), 1);
    v_page_size INT := LEAST(GREATEST(COALESCE((p_filters->>'page_size')::INT, 10), 1), 100);
    v_sort_by TEXT := COALESCE(p_filters->>'sort_by', 'created_at');
    v_sort_order TEXT := UPPER(COALESCE(p_filters->>'sort_order', 'DESC'));
    v_academic_year TEXT := COALESCE(p_filters->>'academic_year', '2024 - 2025');
    v_offset INT := (v_page - 1) * v_page_size;
    v_total_records INT := 0;
    v_total_pages INT := 1;
    v_records JSONB := '[]'::JSONB;
BEGIN
    DROP TABLE IF EXISTS tmp_complaint_results;

    -- Temporary table for filtering
    CREATE TEMP TABLE tmp_complaint_results ON COMMIT DROP AS
    SELECT 
        c.id,
        c.complaint_number,
        c.title,
        c.description,
        c.category,
        c.subcategory,
        c.priority,
        c.status,
        c.reported_by_user_id,
        c.reported_by_name,
        c.reported_by_role,
        c.reported_by_class,
        c.reported_by_phone,
        c.reported_by_email,
        c.reported_by_avatar,
        c.hostel_id,
        c.hostel_name,
        c.building_name,
        c.floor_name,
        c.room_id,
        c.room_number,
        c.bed_code,
        c.facility_type,
        c.equipment_id,
        c.equipment_name,
        c.location_text,
        c.primary_assignee_user_id,
        c.primary_assignee_name,
        c.primary_assignee_role,
        c.source,
        c.response_due_at,
        c.resolution_due_at,
        c.first_response_at,
        c.resolved_at,
        c.completed_at,
        c.resolution_summary,
        c.resolution_type,
        c.rejection_reason,
        c.cancellation_reason,
        c.parts_used,
        c.resolution_cost,
        c.equipment_status_after,
        c.room_entry_permission,
        c.is_reopened,
        c.reopen_count,
        c.sla_status,
        c.escalation_level,
        c.thumbnail_url,
        c.attachments,
        c.version,
        c.created_at,
        c.updated_at,
        -- Calculated dynamic remaining SLA string
        CASE 
            WHEN c.status IN ('RESOLVED', 'COMPLETED') THEN 'Resolved'
            WHEN c.status = 'REJECTED' THEN 'Rejected'
            WHEN c.status = 'CANCELED' THEN 'Canceled'
            WHEN c.resolution_due_at IS NULL THEN 'No SLA'
            WHEN c.resolution_due_at < NOW() THEN 
                CONCAT('Overdue by ', 
                       EXTRACT(DAY FROM (NOW() - c.resolution_due_at))::INT, 'd ', 
                       EXTRACT(HOUR FROM (NOW() - c.resolution_due_at))::INT, 'h')
            ELSE 
                CONCAT(EXTRACT(HOUR FROM (c.resolution_due_at - NOW()))::INT, 'h remaining')
        END AS sla_display
    FROM public.hostel_complaints c
    WHERE c.school_id = p_school_id
      AND c.deleted_at IS NULL
      AND (v_academic_year = 'ALL' OR c.academic_year = v_academic_year)
      -- Date Range Filter
      AND (v_from_date = '' OR c.created_at >= v_from_date::TIMESTAMP)
      AND (v_to_date = '' OR c.created_at < (v_to_date::DATE + INTERVAL '1 day'))
      -- Search Filter
      AND (
          v_search = '' 
          OR c.complaint_number ILIKE '%' || v_search || '%'
          OR c.title ILIKE '%' || v_search || '%'
          OR c.description ILIKE '%' || v_search || '%'
          OR c.reported_by_name ILIKE '%' || v_search || '%'
          OR c.reported_by_class ILIKE '%' || v_search || '%'
          OR c.room_number ILIKE '%' || v_search || '%'
          OR c.hostel_name ILIKE '%' || v_search || '%'
          OR c.category ILIKE '%' || v_search || '%'
          OR c.primary_assignee_name ILIKE '%' || v_search || '%'
          OR c.equipment_name ILIKE '%' || v_search || '%'
      )
      -- Hostel Filter
      AND (v_hostel_filter IN ('All Hostels', 'ALL', '') OR c.hostel_name = v_hostel_filter)
      -- Category Filter
      AND (v_category_filter IN ('All Categories', 'ALL', '') OR c.category ILIKE v_category_filter)
      -- Priority Filter
      AND (v_priority_filter IN ('All Priorities', 'ALL', '') OR c.priority = UPPER(v_priority_filter))
      -- Status Filter
      AND (
          v_status_filter IN ('All Status', 'ALL', '')
          OR (v_status_filter = 'Open' AND c.status IN ('NEW', 'ACTIVE'))
          OR (v_status_filter = 'In Progress' AND c.status = 'IN_PROGRESS')
          OR (v_status_filter = 'Pending' AND c.status IN ('NEW', 'ACTIVE', 'IN_PROGRESS', 'ON_HOLD'))
          OR (c.status = UPPER(v_status_filter))
      )
      -- Subtab Filter (Fully aligned with fn_hostel_complaints_get_overview KPI metrics)
      AND (
          v_subtab_filter IN ('All Complaints', 'Total Complaints', 'ALL', '')
          OR (v_subtab_filter = 'My Complaints' AND (v_user_id = '' OR c.reported_by_user_id::TEXT = v_user_id OR c.primary_assignee_user_id::TEXT = v_user_id))
          OR (v_subtab_filter = 'Pending' AND c.status IN ('NEW', 'ACTIVE', 'IN_PROGRESS', 'ON_HOLD'))
          OR (v_subtab_filter = 'Overdue' AND c.status IN ('NEW', 'ACTIVE', 'IN_PROGRESS', 'ON_HOLD') AND (c.resolution_due_at IS NOT NULL AND c.resolution_due_at < NOW() OR c.sla_status = 'OVERDUE'))
          OR (v_subtab_filter = 'Resolved' AND c.status IN ('RESOLVED', 'COMPLETED'))
          OR (v_subtab_filter IN ('High Priority', 'HIGH_PRIORITY') AND c.priority IN ('HIGH', 'URGENT', 'CRITICAL') AND c.status NOT IN ('RESOLVED', 'COMPLETED', 'REJECTED', 'CANCELED'))
          OR (v_subtab_filter IN ('Maintenance', 'Maintenance Related') AND c.category IN ('Plumbing', 'Electrical', 'Housekeeping', 'Furniture', 'AC/Heating', 'Pest Control', 'Maintenance', 'Equipment'))
          OR (v_subtab_filter = 'Room Related' AND c.room_number IS NOT NULL AND c.room_number != '' AND c.room_number NOT ILIKE '%gate%' AND c.room_number NOT ILIKE '%mess%')
          OR (v_subtab_filter = 'Facility Related' AND (c.facility_type != 'Room' OR c.room_number ILIKE '%gate%' OR c.room_number ILIKE '%mess%'))
      );

    -- Count total matching rows
    SELECT COUNT(*) INTO v_total_records FROM tmp_complaint_results;
    v_total_pages := GREATEST(CEIL(v_total_records::NUMERIC / v_page_size::NUMERIC)::INT, 1);

    -- Select Paginated Result JSON
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', r.id,
            'complaint_number', r.complaint_number,
            'title', r.title,
            'description', r.description,
            'category', r.category,
            'subcategory', r.subcategory,
            'priority', r.priority,
            'status', r.status,
            'reported_by_user_id', r.reported_by_user_id,
            'reported_by_name', r.reported_by_name,
            'reported_by_role', r.reported_by_role,
            'reported_by_class', r.reported_by_class,
            'reported_by_phone', r.reported_by_phone,
            'reported_by_avatar', r.reported_by_avatar,
            'hostel_id', r.hostel_id,
            'hostel_name', r.hostel_name,
            'building_name', r.building_name,
            'floor_name', r.floor_name,
            'room_id', r.room_id,
            'room_number', r.room_number,
            'bed_code', r.bed_code,
            'facility_type', r.facility_type,
            'equipment_id', r.equipment_id,
            'equipment_name', r.equipment_name,
            'location_text', r.location_text,
            'primary_assignee_user_id', r.primary_assignee_user_id,
            'primary_assignee_name', r.primary_assignee_name,
            'primary_assignee_role', r.primary_assignee_role,
            'source', r.source,
            'response_due_at', r.response_due_at,
            'resolution_due_at', r.resolution_due_at,
            'resolved_at', r.resolved_at,
            'completed_at', r.completed_at,
            'resolution_summary', r.resolution_summary,
            'resolution_type', r.resolution_type,
            'rejection_reason', r.rejection_reason,
            'cancellation_reason', r.cancellation_reason,
            'sla_status', r.sla_status,
            'sla_display', r.sla_display,
            'thumbnail_url', r.thumbnail_url,
            'attachments', r.attachments,
            'version', r.version,
            'created_at', r.created_at,
            'updated_at', r.updated_at
        )
    ) INTO v_records
    FROM (
        SELECT * FROM tmp_complaint_results
        ORDER BY
            CASE WHEN v_sort_by = 'priority' AND v_sort_order = 'ASC' THEN 
                CASE priority WHEN 'CRITICAL' THEN 1 WHEN 'URGENT' THEN 2 WHEN 'HIGH' THEN 3 WHEN 'MEDIUM' THEN 4 ELSE 5 END END ASC,
            CASE WHEN v_sort_by = 'priority' AND v_sort_order = 'DESC' THEN 
                CASE priority WHEN 'CRITICAL' THEN 1 WHEN 'URGENT' THEN 2 WHEN 'HIGH' THEN 3 WHEN 'MEDIUM' THEN 4 ELSE 5 END END DESC,
            CASE WHEN v_sort_by = 'title' AND v_sort_order = 'ASC' THEN title END ASC,
            CASE WHEN v_sort_by = 'title' AND v_sort_order = 'DESC' THEN title END DESC,
            CASE WHEN v_sort_by = 'status' AND v_sort_order = 'ASC' THEN status END ASC,
            CASE WHEN v_sort_by = 'status' AND v_sort_order = 'DESC' THEN status END DESC,
            CASE WHEN v_sort_by = 'created_at' AND v_sort_order = 'ASC' THEN created_at END ASC,
            CASE WHEN v_sort_by = 'created_at' AND v_sort_order = 'DESC' THEN created_at END DESC,
            created_at DESC
        LIMIT v_page_size OFFSET v_offset
    ) r;

    RETURN jsonb_build_object(
        'success', true,
        'records', COALESCE(v_records, '[]'::JSONB),
        'pagination', jsonb_build_object(
            'total_records', v_total_records,
            'page', v_page,
            'page_size', v_page_size,
            'total_pages', v_total_pages,
            'has_next', v_page < v_total_pages,
            'has_prev', v_page > 1
        )
    );
END;
$$;
