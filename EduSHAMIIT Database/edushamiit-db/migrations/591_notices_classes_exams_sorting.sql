-- Migration 591: Notices, Academic Classes/Sections/Subjects/Rooms & Exam Monitoring DB sorting + deterministic tie-breakers

CREATE OR REPLACE FUNCTION public.fn_get_notices(p_school_id uuid, p_user_id uuid, p_tab text DEFAULT 'all'::text, p_search text DEFAULT ''::text, p_category text DEFAULT ''::text, p_priority text DEFAULT ''::text, p_status text DEFAULT ''::text, p_audience text DEFAULT ''::text, p_from_date timestamp with time zone DEFAULT NULL::timestamp with time zone, p_to_date timestamp with time zone DEFAULT NULL::timestamp with time zone, p_requires_ack boolean DEFAULT NULL::boolean, p_is_read boolean DEFAULT NULL::boolean, p_has_attachment boolean DEFAULT NULL::boolean, p_sort_by text DEFAULT 'published_at'::text, p_sort_order text DEFAULT 'DESC'::text, p_page integer DEFAULT 1, p_page_size integer DEFAULT 10)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_user_role TEXT := '';
    v_user_class TEXT := '';
    v_clean_user_class TEXT := '';
    v_user_department TEXT := '';
    v_is_admin BOOLEAN := FALSE;
    v_offset INT := 0;
    v_total_records INT := 0;
    v_notices_json JSONB;
    v_result JSONB;
BEGIN
    -- Resolve user profile info
    SELECT COALESCE(role, ''), COALESCE(class, ''), COALESCE(department, '')
    INTO v_user_role, v_user_class, v_user_department
    FROM public.profiles
    WHERE id = p_user_id;

    v_clean_user_class := replace(replace(replace(replace(lower(v_user_class), 'class', ''), 'grade', ''), ' ', ''), '-', '');
    v_clean_user_class := replace(replace(v_clean_user_class, 'x', '10'), 'ix', '9');

    v_is_admin := lower(v_user_role) IN ('super_admin', 'admin', 'principal', 'vice_principal', 'director');
    v_offset := GREATEST(0, (p_page - 1) * p_page_size);

    -- Common CTE to filter notices
    WITH filtered_notices AS (
        SELECT 
            n.id,
            n.school_id,
            n.title,
            n.content,
            n.category,
            n.priority,
            n.status,
            n.author_id,
            n.author_name,
            n.author_role,
            n.target_scope,
            n.target_roles,
            n.target_classes,
            n.target_departments,
            n.target_user_ids,
            n.timezone,
            n.published_at,
            n.scheduled_at,
            n.expires_at,
            n.requires_acknowledgement,
            n.acknowledgement_deadline,
            n.notification_channels,
            n.attachments,
            n.links,
            n.approval_status,
            n.rejection_reason,
            n.is_pinned,
            n.is_urgent,
            n.view_count,
            n.ack_count,
            n.recipient_count,
            n.created_at,
            n.updated_at,
            nr.is_read AS user_is_read,
            nr.read_at AS user_read_at,
            nr.is_acknowledged AS user_is_acknowledged,
            nr.acknowledged_at AS user_acknowledged_at,
            nr.acknowledgement_status AS user_ack_status,
            COUNT(*) OVER() AS full_count
        FROM public.notices n
        LEFT JOIN public.notice_recipients nr ON nr.notice_id = n.id AND nr.user_id = p_user_id
        WHERE (n.school_id = p_school_id OR n.school_id IS NULL)
          -- Soft deletion filter
          AND (
              CASE 
                  WHEN p_tab = 'archived' THEN n.status = 'archived' AND n.deleted_at IS NULL
                  ELSE n.deleted_at IS NULL
              END
          )
          -- Non-admin Audience & RBAC Isolation: Users only see notices intended for them
          AND (
              v_is_admin 
              OR n.author_id = p_user_id 
              OR (
                  n.status = 'published' AND (
                      (n.target_scope = 'entire_institute' 
                          AND (n.target_roles IS NULL OR jsonb_array_length(n.target_roles) = 0) 
                          AND (n.target_classes IS NULL OR jsonb_array_length(n.target_classes) = 0)
                          AND (n.target_user_ids IS NULL OR jsonb_array_length(n.target_user_ids) = 0)
                          AND (n.target_departments IS NULL OR jsonb_array_length(n.target_departments) = 0)
                      )
                      OR (n.target_roles IS NOT NULL AND jsonb_array_length(n.target_roles) > 0 AND n.target_roles ? lower(v_user_role))
                      OR (n.target_classes IS NOT NULL AND jsonb_array_length(n.target_classes) > 0 AND v_user_class != '' AND EXISTS (
                          SELECT 1 FROM jsonb_array_elements_text(n.target_classes) tc
                          WHERE tc ILIKE v_user_class OR v_user_class ILIKE tc
                             OR replace(replace(replace(replace(lower(tc), 'class', ''), 'grade', ''), ' ', ''), '-', '') = replace(replace(replace(replace(lower(v_user_class), 'class', ''), 'grade', ''), ' ', ''), '-', '')
                             OR replace(replace(replace(replace(replace(replace(lower(tc), 'class', ''), 'grade', ''), ' ', ''), '-', ''), 'x', '10'), 'ix', '9') = v_clean_user_class
                      ))
                      OR (n.target_departments IS NOT NULL AND jsonb_array_length(n.target_departments) > 0 AND v_user_department != '' AND n.target_departments ? v_user_department)
                      OR (n.target_user_ids IS NOT NULL AND jsonb_array_length(n.target_user_ids) > 0 AND n.target_user_ids ? (p_user_id::text))
                  )
              )
          )
          -- Tab-based filtering
          AND (
              CASE 
                  WHEN p_tab = 'all' THEN TRUE
                  WHEN p_tab = 'my' THEN n.author_id = p_user_id
                  WHEN p_tab = 'school' THEN n.target_scope = 'entire_institute' AND n.status = 'published'
                  WHEN p_tab = 'department' THEN (
                      (n.target_scope = 'departments' OR (n.target_departments IS NOT NULL AND n.target_departments ? v_user_department))
                      AND n.status = 'published'
                  )
                  WHEN p_tab = 'published' THEN n.status = 'published'
                  WHEN p_tab = 'scheduled' THEN n.status = 'scheduled' AND (v_is_admin OR n.author_id = p_user_id)
                  WHEN p_tab = 'drafts' THEN n.status = 'draft' AND (v_is_admin OR n.author_id = p_user_id)
                  WHEN p_tab = 'pending_approval' THEN (
                      (n.approval_status = 'pending' OR n.status = 'pending_approval')
                      AND (v_is_admin OR n.author_id = p_user_id)
                  )
                  WHEN p_tab = 'expired' THEN (n.status = 'expired' OR (n.expires_at IS NOT NULL AND n.expires_at < NOW()))
                  WHEN p_tab = 'archived' THEN n.status = 'archived' AND (v_is_admin OR n.author_id = p_user_id)
                  ELSE TRUE
              END
          )
          -- Search keyword
          AND (
              p_search = '' 
              OR n.title ILIKE '%' || p_search || '%'
              OR n.content ILIKE '%' || p_search || '%'
              OR n.author_name ILIKE '%' || p_search || '%'
              OR n.category ILIKE '%' || p_search || '%'
          )
          -- Specific Audience filter
          AND (
              p_audience = '' OR p_audience = 'All'
              OR (lower(p_audience) IN ('entire institute', 'entire school', 'entire_institute') AND n.target_scope = 'entire_institute')
              OR (lower(p_audience) IN ('all teachers', 'teacher', 'teachers') AND (n.target_roles ? 'teacher' OR (n.target_scope = 'entire_institute' AND (n.target_roles IS NULL OR jsonb_array_length(n.target_roles) = 0))))
              OR (lower(p_audience) IN ('all students', 'student', 'students') AND (n.target_roles ? 'student' OR (n.target_scope = 'entire_institute' AND (n.target_roles IS NULL OR jsonb_array_length(n.target_roles) = 0)) OR (n.target_classes IS NOT NULL AND jsonb_array_length(n.target_classes) > 0)))
              OR (lower(p_audience) IN ('parents', 'parent') AND (n.target_roles ? 'parent' OR (n.target_scope = 'entire_institute' AND (n.target_roles IS NULL OR jsonb_array_length(n.target_roles) = 0))))
              OR (lower(p_audience) IN ('transport users', 'driver', 'transport') AND (n.target_roles ? 'driver' OR n.target_roles ? 'transport'))
              OR (n.target_roles IS NOT NULL AND n.target_roles ? lower(p_audience))
              OR (n.target_classes IS NOT NULL AND EXISTS (
                  SELECT 1 FROM jsonb_array_elements_text(n.target_classes) tc
                  WHERE tc ILIKE p_audience OR p_audience ILIKE tc
                     OR replace(replace(replace(replace(lower(tc), 'class', ''), 'grade', ''), ' ', ''), '-', '') = replace(replace(replace(replace(lower(p_audience), 'class', ''), 'grade', ''), ' ', ''), '-', '')
              ))
          )
          -- Specific Category filter
          AND (p_category = '' OR p_category = 'All' OR n.category ILIKE p_category)
          -- Specific Priority filter
          AND (p_priority = '' OR p_priority = 'All' OR n.priority ILIKE p_priority)
          -- Specific Status filter
          AND (p_status = '' OR p_status = 'All' OR n.status ILIKE p_status)
          -- Date Range filter
          AND (p_from_date IS NULL OR n.published_at >= p_from_date OR n.created_at >= p_from_date)
          AND (p_to_date IS NULL OR n.published_at <= p_to_date OR n.created_at <= p_to_date)
          -- Requires Ack filter
          AND (p_requires_ack IS NULL OR n.requires_acknowledgement = p_requires_ack)
          -- Has Attachment filter
          AND (
              p_has_attachment IS NULL 
              OR (p_has_attachment = TRUE AND jsonb_array_length(n.attachments) > 0)
              OR (p_has_attachment = FALSE AND (n.attachments IS NULL OR jsonb_array_length(n.attachments) = 0))
          )
          -- Is Read filter
          AND (
              p_is_read IS NULL 
              OR (p_is_read = TRUE AND nr.is_read = TRUE)
              OR (p_is_read = FALSE AND (nr.is_read IS NULL OR nr.is_read = FALSE))
          )
    ),
    paged_notices AS (
        SELECT *
        FROM filtered_notices fn
        ORDER BY 
            fn.is_pinned DESC,
            CASE WHEN p_sort_by = 'published_at' AND UPPER(p_sort_order) = 'DESC' THEN fn.published_at END DESC NULLS LAST,
            CASE WHEN p_sort_by = 'published_at' AND UPPER(p_sort_order) = 'ASC' THEN fn.published_at END ASC NULLS LAST,
            CASE WHEN p_sort_by = 'created_at' AND UPPER(p_sort_order) = 'DESC' THEN fn.created_at END DESC,
            CASE WHEN p_sort_by = 'created_at' AND UPPER(p_sort_order) = 'ASC' THEN fn.created_at END ASC,
            CASE WHEN p_sort_by = 'title' AND UPPER(p_sort_order) = 'ASC' THEN LOWER(fn.title) END ASC,
            CASE WHEN p_sort_by = 'title' AND UPPER(p_sort_order) = 'DESC' THEN LOWER(fn.title) END DESC,
            CASE WHEN p_sort_by = 'category' AND UPPER(p_sort_order) = 'ASC' THEN LOWER(COALESCE(fn.category, '')) END ASC,
            CASE WHEN p_sort_by = 'category' AND UPPER(p_sort_order) = 'DESC' THEN LOWER(COALESCE(fn.category, '')) END DESC,
            CASE WHEN p_sort_by = 'priority' AND UPPER(p_sort_order) = 'ASC' THEN LOWER(COALESCE(fn.priority, '')) END ASC,
            CASE WHEN p_sort_by = 'priority' AND UPPER(p_sort_order) = 'DESC' THEN LOWER(COALESCE(fn.priority, '')) END DESC,
            CASE WHEN p_sort_by = 'status' AND UPPER(p_sort_order) = 'ASC' THEN LOWER(COALESCE(fn.status, '')) END ASC,
            CASE WHEN p_sort_by = 'status' AND UPPER(p_sort_order) = 'DESC' THEN LOWER(COALESCE(fn.status, '')) END DESC,
            CASE WHEN p_sort_by = 'view_count' AND UPPER(p_sort_order) = 'ASC' THEN fn.view_count END ASC,
            CASE WHEN p_sort_by = 'view_count' AND UPPER(p_sort_order) = 'DESC' THEN fn.view_count END DESC,
            CASE WHEN p_sort_by = 'ack_count' AND UPPER(p_sort_order) = 'ASC' THEN fn.ack_count END ASC,
            CASE WHEN p_sort_by = 'ack_count' AND UPPER(p_sort_order) = 'DESC' THEN fn.ack_count END DESC,
            fn.created_at DESC,
            fn.id ASC
        LIMIT p_page_size
        OFFSET v_offset
    )
    SELECT 
        COALESCE((SELECT full_count FROM filtered_notices LIMIT 1), 0),
        COALESCE(jsonb_agg(
            jsonb_build_object(
                'id', pn.id,
                'school_id', pn.school_id,
                'title', pn.title,
                'content', pn.content,
                'category', pn.category,
                'priority', pn.priority,
                'status', pn.status,
                'author_id', pn.author_id,
                'author_name', pn.author_name,
                'author_role', pn.author_role,
                'target_scope', pn.target_scope,
                'target_roles', pn.target_roles,
                'target_classes', pn.target_classes,
                'target_departments', pn.target_departments,
                'target_user_ids', pn.target_user_ids,
                'timezone', pn.timezone,
                'published_at', pn.published_at,
                'scheduled_at', pn.scheduled_at,
                'expires_at', pn.expires_at,
                'requires_acknowledgement', pn.requires_acknowledgement,
                'acknowledgement_deadline', pn.acknowledgement_deadline,
                'notification_channels', pn.notification_channels,
                'attachments', pn.attachments,
                'links', pn.links,
                'notification_channels', pn.notification_channels,
                'attachments', pn.attachments,
                'links', pn.links,
                'approval_status', pn.approval_status,
                'rejection_reason', pn.rejection_reason,
                'is_pinned', pn.is_pinned,
                'is_urgent', pn.is_urgent,
                'view_count', pn.view_count,
                'ack_count', pn.ack_count,
                'recipient_count', pn.recipient_count,
                'created_at', pn.created_at,
                'updated_at', pn.updated_at,
                'user_is_read', COALESCE(pn.user_is_read, FALSE),
                'user_read_at', pn.user_read_at,
                'user_is_acknowledged', COALESCE(pn.user_is_acknowledged, FALSE),
                'user_acknowledged_at', pn.user_acknowledged_at,
                'user_ack_status', COALESCE(pn.user_ack_status, 'pending')
            )
        ), '[]'::jsonb)
    INTO v_total_records, v_notices_json
    FROM paged_notices pn;

    IF v_notices_json IS NULL THEN
        v_notices_json := '[]'::jsonb;
    END IF;

    v_result := jsonb_build_object(
        'success', TRUE,
        'page', p_page,
        'page_size', p_page_size,
        'total_records', v_total_records,
        'total_pages', CEIL(v_total_records::NUMERIC / GREATEST(1, p_page_size)),
        'data', v_notices_json
    );

    RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_get_academic_sections(p_school_id uuid, p_class_id uuid DEFAULT NULL::uuid, p_search text DEFAULT ''::text, p_academic_year character varying DEFAULT '2026-27'::character varying, p_status character varying DEFAULT 'ALL'::character varying, p_page integer DEFAULT 1, p_page_size integer DEFAULT 10, p_sort_by character varying DEFAULT 'name'::character varying, p_sort_order character varying DEFAULT 'ASC'::character varying, p_teacher_id uuid DEFAULT NULL::uuid, p_building character varying DEFAULT 'ALL'::character varying, p_floor character varying DEFAULT 'ALL'::character varying)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_total_count INT := 0;
    v_offset INT := (GREATEST(p_page, 1) - 1) * p_page_size;
    v_sections JSONB := '[]'::JSONB;
BEGIN
    SELECT COUNT(*)
    INTO v_total_count
    FROM public.academic_sections s
    JOIN public.academic_classes c ON c.id = s.class_id
    LEFT JOIN public.academic_rooms r ON r.id = s.room_id AND r.deleted_at IS NULL
    WHERE s.school_id = p_school_id
      AND s.academic_year = p_academic_year
      AND (p_class_id IS NULL OR s.class_id = p_class_id)
      AND (
          (p_status = 'ALL' AND s.deleted_at IS NULL)
          OR (p_status = 'ARCHIVED' AND (UPPER(TRIM(s.status)) = 'ARCHIVED' OR s.deleted_at IS NOT NULL))
          OR (p_status != 'ALL' AND UPPER(TRIM(s.status)) = UPPER(TRIM(p_status)) AND s.deleted_at IS NULL)
      )
      AND (
          p_teacher_id IS NULL
          OR EXISTS (
              SELECT 1 FROM public.class_teacher_assignments cta
              WHERE cta.teacher_id = p_teacher_id
                AND (cta.section_id = s.id OR (cta.class_id = s.class_id AND cta.section_id IS NULL))
                AND cta.academic_year = p_academic_year
          )
          OR EXISTS (
              SELECT 1 FROM public.section_subject_teachers sst
              WHERE sst.section_id = s.id AND sst.teacher_id = p_teacher_id
          )
      )
      AND (
          p_building = 'ALL'
          OR (p_building = 'Unassigned' AND (s.room_id IS NULL OR r.building IS NULL OR TRIM(r.building) = '' OR TRIM(r.building) ILIKE 'Unassigned'))
          OR (r.building ILIKE p_building)
      )
      AND (
          p_floor = 'ALL'
          OR (p_floor = 'Unassigned' AND (s.room_id IS NULL OR r.floor IS NULL OR TRIM(r.floor) = ''))
          OR (r.floor ILIKE p_floor)
      )
      AND (
          p_search = '' 
          OR s.name ILIKE '%' || p_search || '%' 
          OR s.code ILIKE '%' || p_search || '%'
          OR c.name ILIKE '%' || p_search || '%'
          OR s.room_number ILIKE '%' || p_search || '%'
          OR r.name ILIKE '%' || p_search || '%'
          OR r.building ILIKE '%' || p_search || '%'
      );

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', s.id,
                'class_id', s.class_id,
                'class_name', s.class_name,
                'class_code', s.class_code,
                'name', s.name,
                'code', s.code,
                'capacity', s.capacity,
                'room_number', s.room_number,
                'room_id', s.room_id,
                'room_name', s.room_name,
                'building', s.building,
                'floor', s.floor,
                'academic_year', s.academic_year,
                'status', s.status,
                'students_count', (
                    SELECT COUNT(DISTINCT sca.student_id) 
                    FROM public.student_class_assignments sca 
                    WHERE sca.section_id = s.id AND sca.status = 'ACTIVE'
                ),
                'class_teacher', (
                    SELECT jsonb_build_object(
                        'id', p.id,
                        'name', p.full_name,
                        'full_name', p.full_name,
                        'email', p.email,
                        'employee_id', p.employee_id,
                        'department', p.department,
                        'avatar_url', p.avatar_url
                    )
                    FROM public.class_teacher_assignments cta
                    JOIN public.profiles p ON p.id = cta.teacher_id
                    WHERE (cta.section_id = s.id OR (cta.class_id = s.class_id AND cta.section_id IS NULL AND cta.is_primary = TRUE))
                      AND cta.academic_year = p_academic_year
                    ORDER BY (cta.section_id = s.id) DESC
                    LIMIT 1
                ),
                'section_teacher', (
                    SELECT jsonb_build_object(
                        'id', p.id,
                        'name', p.full_name,
                        'full_name', p.full_name,
                        'email', p.email,
                        'employee_id', p.employee_id,
                        'department', p.department,
                        'avatar_url', p.avatar_url
                    )
                    FROM public.class_teacher_assignments cta
                    JOIN public.profiles p ON p.id = cta.teacher_id
                    WHERE (cta.section_id = s.id OR (cta.class_id = s.class_id AND cta.section_id IS NULL AND cta.is_primary = TRUE))
                      AND cta.academic_year = p_academic_year
                    ORDER BY (cta.section_id = s.id) DESC
                    LIMIT 1
                ),
                'created_at', s.created_at,
                'updated_at', s.updated_at
            )
        ),
        '[]'::JSONB
    ) INTO v_sections
    FROM (
        SELECT 
            s.*,
            c.name as class_name,
            c.code as class_code,
            r.name as room_name,
            r.building as building,
            r.floor as floor
        FROM public.academic_sections s
        JOIN public.academic_classes c ON c.id = s.class_id
        LEFT JOIN public.academic_rooms r ON r.id = s.room_id AND r.deleted_at IS NULL
        WHERE s.school_id = p_school_id
          AND s.academic_year = p_academic_year
          AND (p_class_id IS NULL OR s.class_id = p_class_id)
          AND (
              (p_status = 'ALL' AND s.deleted_at IS NULL)
              OR (p_status = 'ARCHIVED' AND (UPPER(TRIM(s.status)) = 'ARCHIVED' OR s.deleted_at IS NOT NULL))
              OR (p_status != 'ALL' AND UPPER(TRIM(s.status)) = UPPER(TRIM(p_status)) AND s.deleted_at IS NULL)
          )
          AND (
              p_teacher_id IS NULL
              OR EXISTS (
                  SELECT 1 FROM public.class_teacher_assignments cta
                  WHERE cta.teacher_id = p_teacher_id
                    AND (cta.section_id = s.id OR (cta.class_id = s.class_id AND cta.section_id IS NULL))
                    AND cta.academic_year = p_academic_year
              )
              OR EXISTS (
                  SELECT 1 FROM public.section_subject_teachers sst
                  WHERE sst.section_id = s.id AND sst.teacher_id = p_teacher_id
              )
          )
          AND (
              p_building = 'ALL'
              OR (p_building = 'Unassigned' AND (s.room_id IS NULL OR r.building IS NULL OR TRIM(r.building) = '' OR TRIM(r.building) ILIKE 'Unassigned'))
              OR (r.building ILIKE p_building)
          )
          AND (
              p_floor = 'ALL'
              OR (p_floor = 'Unassigned' AND (s.room_id IS NULL OR r.floor IS NULL OR TRIM(r.floor) = ''))
              OR (r.floor ILIKE p_floor)
          )
          AND (
              p_search = '' 
              OR s.name ILIKE '%' || p_search || '%' 
              OR s.code ILIKE '%' || p_search || '%'
              OR c.name ILIKE '%' || p_search || '%'
              OR s.room_number ILIKE '%' || p_search || '%'
              OR r.name ILIKE '%' || p_search || '%'
              OR r.building ILIKE '%' || p_search || '%'
          )
        ORDER BY 
            CASE WHEN p_sort_by = 'name' AND UPPER(p_sort_order) = 'ASC' THEN LOWER(s.name) END ASC,
            CASE WHEN p_sort_by = 'name' AND UPPER(p_sort_order) = 'DESC' THEN LOWER(s.name) END DESC,
            CASE WHEN p_sort_by = 'code' AND UPPER(p_sort_order) = 'ASC' THEN LOWER(COALESCE(s.code, '')) END ASC,
            CASE WHEN p_sort_by = 'code' AND UPPER(p_sort_order) = 'DESC' THEN LOWER(COALESCE(s.code, '')) END DESC,
            CASE WHEN p_sort_by = 'class_name' AND UPPER(p_sort_order) = 'ASC' THEN LOWER(COALESCE(c.name, '')) END ASC,
            CASE WHEN p_sort_by = 'class_name' AND UPPER(p_sort_order) = 'DESC' THEN LOWER(COALESCE(c.name, '')) END DESC,
            CASE WHEN p_sort_by = 'capacity' AND UPPER(p_sort_order) = 'ASC' THEN s.capacity END ASC,
            CASE WHEN p_sort_by = 'capacity' AND UPPER(p_sort_order) = 'DESC' THEN s.capacity END DESC,
            CASE WHEN p_sort_by = 'status' AND UPPER(p_sort_order) = 'ASC' THEN LOWER(COALESCE(s.status, '')) END ASC,
            CASE WHEN p_sort_by = 'status' AND UPPER(p_sort_order) = 'DESC' THEN LOWER(COALESCE(s.status, '')) END DESC,
            CASE WHEN p_sort_by = 'students_count' AND UPPER(p_sort_order) = 'ASC' THEN (
                SELECT COUNT(DISTINCT sca.student_id)
                FROM public.student_class_assignments sca
                WHERE sca.section_id = s.id AND sca.status = 'ACTIVE'
            ) END ASC,
            CASE WHEN p_sort_by = 'students_count' AND UPPER(p_sort_order) = 'DESC' THEN (
                SELECT COUNT(DISTINCT sca.student_id)
                FROM public.student_class_assignments sca
                WHERE sca.section_id = s.id AND sca.status = 'ACTIVE'
            ) END DESC,
            c.display_order ASC, s.name ASC, s.id ASC
        LIMIT p_page_size
        OFFSET v_offset
    ) s;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'sections', v_sections,
            'total_count', v_total_count,
            'page', p_page,
            'page_size', p_page_size,
            'total_pages', CEIL(v_total_count::NUMERIC / GREATEST(p_page_size, 1)::NUMERIC)::INT
        )
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_get_academic_subjects(p_school_id uuid, p_search text DEFAULT ''::text, p_type character varying DEFAULT 'ALL'::character varying, p_status character varying DEFAULT 'ALL'::character varying, p_class_id uuid DEFAULT NULL::uuid, p_page integer DEFAULT 1, p_page_size integer DEFAULT 10, p_sort_by character varying DEFAULT 'name'::character varying, p_sort_order character varying DEFAULT 'ASC'::character varying, p_teacher_id uuid DEFAULT NULL::uuid, p_academic_year character varying DEFAULT '2026-27'::character varying)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_subjects JSONB;
    v_total_count INT := 0;
    v_offset INT := (GREATEST(p_page, 1) - 1) * GREATEST(p_page_size, 1);
BEGIN
    SELECT COUNT(*) INTO v_total_count
    FROM public.academic_subjects s
    WHERE s.school_id = p_school_id
      AND (
          (p_status = 'ALL' AND s.deleted_at IS NULL)
          OR (p_status = 'ARCHIVED' AND (UPPER(TRIM(s.status)) = 'ARCHIVED' OR s.deleted_at IS NOT NULL))
          OR (p_status != 'ALL' AND UPPER(TRIM(s.status)) = UPPER(TRIM(p_status)) AND s.deleted_at IS NULL)
      )
      AND (
          p_type = 'ALL' 
          OR p_type = '' 
          OR UPPER(TRIM(s.type)) = UPPER(TRIM(p_type))
          OR (p_type ILIKE '%core%' AND s.type ILIKE '%core%')
          OR ((p_type ILIKE '%elec%' OR p_type ILIKE '%opt%') AND (s.type ILIKE '%elec%' OR s.type ILIKE '%opt%'))
          OR ((p_type ILIKE '%prac%' OR p_type ILIKE '%lab%') AND (s.type ILIKE '%prac%' OR s.type ILIKE '%lab%'))
          OR (p_type ILIKE '%lang%' AND s.type ILIKE '%lang%')
      )
      AND (
          p_class_id IS NULL
          OR EXISTS (
              SELECT 1 FROM public.class_subject_assignments csa
              JOIN public.academic_classes c ON c.id = csa.class_id AND c.deleted_at IS NULL
              WHERE csa.subject_id = s.id 
                AND csa.class_id = p_class_id 
                AND csa.school_id = p_school_id
                AND (p_academic_year IS NULL OR p_academic_year = '' OR csa.academic_year = p_academic_year)
                AND (p_academic_year IS NULL OR p_academic_year = '' OR c.academic_year = p_academic_year)
          )
      )
      AND (
          p_teacher_id IS NULL
          OR EXISTS (
              SELECT 1 FROM public.section_subject_teachers sst
              WHERE sst.subject_id = s.id 
                AND sst.teacher_id = p_teacher_id 
                AND sst.status = 'ACTIVE'
                AND (p_academic_year IS NULL OR p_academic_year = '' OR sst.academic_year = p_academic_year)
          )
          OR EXISTS (
              SELECT 1 FROM public.class_teacher_assignments cta
              JOIN public.class_subject_assignments csa ON csa.class_id = cta.class_id
              WHERE csa.subject_id = s.id
                AND cta.teacher_id = p_teacher_id
                AND (p_academic_year IS NULL OR p_academic_year = '' OR csa.academic_year = p_academic_year)
          )
      )
      AND (
          p_search = '' 
          OR s.name ILIKE '%' || p_search || '%' 
          OR s.code ILIKE '%' || p_search || '%'
          OR s.type ILIKE '%' || p_search || '%'
      );

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', s_item.id,
                'name', s_item.name,
                'code', s_item.code,
                'type', s_item.type,
                'description', s_item.description,
                'periods_per_week', s_item.periods_per_week,
                'color', s_item.color,
                'icon', s_item.icon,
                'status', s_item.status,
                'is_optional', COALESCE(s_item.is_optional, (s_item.type ILIKE '%elec%' OR s_item.type ILIKE '%opt%')),
                'classes_count', (
                    SELECT COUNT(DISTINCT csa.class_id) 
                    FROM public.class_subject_assignments csa 
                    JOIN public.academic_classes c ON c.id = csa.class_id AND c.deleted_at IS NULL
                    WHERE csa.subject_id = s_item.id 
                      AND csa.school_id = p_school_id
                      AND (p_academic_year IS NULL OR p_academic_year = '' OR csa.academic_year = p_academic_year)
                      AND (p_academic_year IS NULL OR p_academic_year = '' OR c.academic_year = p_academic_year)
                ),
                'assigned_sections_count', (
                    SELECT COUNT(DISTINCT csa.section_id) 
                    FROM public.class_subject_assignments csa 
                    JOIN public.academic_sections sec ON sec.id = csa.section_id AND sec.deleted_at IS NULL
                    WHERE csa.subject_id = s_item.id 
                      AND csa.school_id = p_school_id 
                      AND csa.section_id IS NOT NULL
                      AND (p_academic_year IS NULL OR p_academic_year = '' OR csa.academic_year = p_academic_year)
                      AND (p_academic_year IS NULL OR p_academic_year = '' OR sec.academic_year = p_academic_year)
                ),
                'teachers_count', (
                    SELECT COUNT(DISTINCT sst.teacher_id) 
                    FROM public.section_subject_teachers sst 
                    WHERE sst.subject_id = s_item.id 
                      AND sst.school_id = p_school_id 
                      AND sst.status = 'ACTIVE'
                      AND (p_academic_year IS NULL OR p_academic_year = '' OR sst.academic_year = p_academic_year)
                ),
                'assigned_classes', (
                    SELECT COALESCE(
                        jsonb_agg(
                            DISTINCT jsonb_build_object(
                                'class_id', c.id,
                                'class_name', c.name,
                                'class_code', c.code
                            )
                        ),
                        '[]'::JSONB
                    )
                    FROM public.class_subject_assignments csa2
                    JOIN public.academic_classes c ON c.id = csa2.class_id
                    WHERE csa2.subject_id = s_item.id 
                      AND c.deleted_at IS NULL 
                      AND csa2.school_id = p_school_id
                      AND (p_academic_year IS NULL OR p_academic_year = '' OR csa2.academic_year = p_academic_year)
                      AND (p_academic_year IS NULL OR p_academic_year = '' OR c.academic_year = p_academic_year)
                ),
                'created_at', s_item.created_at,
                'updated_at', s_item.updated_at
            )
        ),
        '[]'::JSONB
    ) INTO v_subjects
    FROM (
        SELECT s.*
        FROM public.academic_subjects s
        WHERE s.school_id = p_school_id
          AND (
              (p_status = 'ALL' AND s.deleted_at IS NULL)
              OR (p_status = 'ARCHIVED' AND (UPPER(TRIM(s.status)) = 'ARCHIVED' OR s.deleted_at IS NOT NULL))
              OR (p_status != 'ALL' AND UPPER(TRIM(s.status)) = UPPER(TRIM(p_status)) AND s.deleted_at IS NULL)
          )
          AND (
              p_type = 'ALL' 
              OR p_type = '' 
              OR UPPER(TRIM(s.type)) = UPPER(TRIM(p_type))
              OR (p_type ILIKE '%core%' AND s.type ILIKE '%core%')
              OR ((p_type ILIKE '%elec%' OR p_type ILIKE '%opt%') AND (s.type ILIKE '%elec%' OR s.type ILIKE '%opt%'))
              OR ((p_type ILIKE '%prac%' OR p_type ILIKE '%lab%') AND (s.type ILIKE '%prac%' OR s.type ILIKE '%lab%'))
              OR (p_type ILIKE '%lang%' AND s.type ILIKE '%lang%')
          )
          AND (
              p_class_id IS NULL
              OR EXISTS (
                  SELECT 1 FROM public.class_subject_assignments csa
                  JOIN public.academic_classes c ON c.id = csa.class_id AND c.deleted_at IS NULL
                  WHERE csa.subject_id = s.id 
                    AND csa.class_id = p_class_id 
                    AND csa.school_id = p_school_id
                    AND (p_academic_year IS NULL OR p_academic_year = '' OR csa.academic_year = p_academic_year)
                    AND (p_academic_year IS NULL OR p_academic_year = '' OR c.academic_year = p_academic_year)
              )
          )
          AND (
              p_teacher_id IS NULL
              OR EXISTS (
                  SELECT 1 FROM public.section_subject_teachers sst
                  WHERE sst.subject_id = s.id 
                    AND sst.teacher_id = p_teacher_id 
                    AND sst.status = 'ACTIVE'
                    AND (p_academic_year IS NULL OR p_academic_year = '' OR sst.academic_year = p_academic_year)
              )
              OR EXISTS (
                  SELECT 1 FROM public.class_teacher_assignments cta
                  JOIN public.class_subject_assignments csa ON csa.class_id = cta.class_id
                  WHERE csa.subject_id = s.id
                    AND cta.teacher_id = p_teacher_id
                    AND (p_academic_year IS NULL OR p_academic_year = '' OR csa.academic_year = p_academic_year)
              )
          )
          AND (
              p_search = '' 
              OR s.name ILIKE '%' || p_search || '%' 
              OR s.code ILIKE '%' || p_search || '%'
              OR s.type ILIKE '%' || p_search || '%'
          )
        ORDER BY
            CASE WHEN p_sort_by = 'name' AND UPPER(p_sort_order) = 'ASC' THEN LOWER(s.name) END ASC,
            CASE WHEN p_sort_by = 'name' AND UPPER(p_sort_order) = 'DESC' THEN LOWER(s.name) END DESC,
            CASE WHEN p_sort_by = 'code' AND UPPER(p_sort_order) = 'ASC' THEN LOWER(COALESCE(s.code, '')) END ASC,
            CASE WHEN p_sort_by = 'code' AND UPPER(p_sort_order) = 'DESC' THEN LOWER(COALESCE(s.code, '')) END DESC,
            CASE WHEN p_sort_by = 'type' AND UPPER(p_sort_order) = 'ASC' THEN LOWER(COALESCE(s.type, '')) END ASC,
            CASE WHEN p_sort_by = 'type' AND UPPER(p_sort_order) = 'DESC' THEN LOWER(COALESCE(s.type, '')) END DESC,
            CASE WHEN p_sort_by = 'status' AND UPPER(p_sort_order) = 'ASC' THEN LOWER(COALESCE(s.status, '')) END ASC,
            CASE WHEN p_sort_by = 'status' AND UPPER(p_sort_order) = 'DESC' THEN LOWER(COALESCE(s.status, '')) END DESC,
            CASE WHEN p_sort_by = 'created_at' AND UPPER(p_sort_order) = 'ASC' THEN s.created_at END ASC,
            CASE WHEN p_sort_by = 'created_at' AND UPPER(p_sort_order) = 'DESC' THEN s.created_at END DESC,
            s.created_at DESC, s.id ASC
        LIMIT p_page_size
        OFFSET v_offset
    ) s_item;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'subjects', v_subjects,
            'total_count', v_total_count,
            'page', p_page,
            'page_size', p_page_size,
            'total_pages', CEIL(v_total_count::NUMERIC / GREATEST(p_page_size, 1))::INT
        )
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_get_academic_rooms(p_school_id uuid, p_search character varying DEFAULT ''::character varying, p_type character varying DEFAULT 'ALL'::character varying, p_building character varying DEFAULT 'ALL'::character varying, p_floor character varying DEFAULT 'ALL'::character varying, p_status character varying DEFAULT 'ALL'::character varying, p_page integer DEFAULT 1, p_page_size integer DEFAULT 10, p_sort_by character varying DEFAULT 'name'::character varying, p_sort_order character varying DEFAULT 'ASC'::character varying, p_academic_year character varying DEFAULT '2026-27'::character varying)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_offset INT := (GREATEST(p_page, 1) - 1) * p_page_size;
    v_total_count INT := 0;
    v_rooms JSONB := '[]'::JSONB;
BEGIN
    -- 1. Total Count for pagination
    SELECT COUNT(*) INTO v_total_count
    FROM public.academic_rooms r
    WHERE r.school_id = p_school_id
      AND r.deleted_at IS NULL
      AND (
          p_search = '' 
          OR r.name ILIKE '%' || p_search || '%' 
          OR r.code ILIKE '%' || p_search || '%'
          OR r.type ILIKE '%' || p_search || '%'
          OR r.building ILIKE '%' || p_search || '%'
      )
      AND (p_type = 'ALL' OR p_type = '' OR UPPER(TRIM(r.type)) = UPPER(TRIM(p_type)))
      AND (p_building = 'ALL' OR p_building = '' OR UPPER(TRIM(r.building)) = UPPER(TRIM(p_building)))
      AND (p_floor = 'ALL' OR p_floor = '' OR UPPER(TRIM(r.floor)) = UPPER(TRIM(p_floor)))
      AND (p_status = 'ALL' OR p_status = '' OR UPPER(TRIM(r.status)) = UPPER(TRIM(p_status)));

    -- 2. Fetch paginated records with dynamic data
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', r_item.id,
                'name', r_item.name,
                'code', r_item.code,
                'type', r_item.type,
                'building', r_item.building,
                'floor', r_item.floor,
                'capacity', r_item.capacity,
                'facilities', r_item.facilities,
                'status', r_item.status,
                'in_use_status', r_item.status,
                'description', r_item.description,
                'in_use_by', r_item.in_use_by,
                'timings', r_item.timings,
                'assigned_sections_count', r_item.assigned_sections_count,
                'created_at', r_item.created_at,
                'updated_at', r_item.updated_at
            )
        ),
        '[]'::JSONB
    ) INTO v_rooms
    FROM (
        SELECT 
            r.id,
            r.name,
            r.code,
            r.type,
            r.building,
            r.floor,
            r.capacity,
            r.facilities,
            r.status,
            r.description,
            r.created_at,
            r.updated_at,
            (
                SELECT COUNT(*) 
                FROM public.academic_sections s 
                WHERE s.room_id = r.id 
                  AND s.deleted_at IS NULL
                  AND (p_academic_year IS NULL OR p_academic_year = '' OR s.academic_year = p_academic_year)
            ) AS assigned_sections_count,
            COALESCE(
                (
                    SELECT 'Class ' || c.name || ' (' || s.name || ')'
                    FROM public.academic_sections s
                    JOIN public.academic_classes c ON c.id = s.class_id
                    WHERE s.room_id = r.id 
                      AND s.deleted_at IS NULL
                      AND (p_academic_year IS NULL OR p_academic_year = '' OR s.academic_year = p_academic_year)
                      AND (p_academic_year IS NULL OR p_academic_year = '' OR c.academic_year = p_academic_year)
                    LIMIT 1
                ),
                '—'
            ) AS in_use_by,
            '—' AS timings
        FROM public.academic_rooms r
        WHERE r.school_id = p_school_id
          AND r.deleted_at IS NULL
          AND (
              p_search = '' 
              OR r.name ILIKE '%' || p_search || '%' 
              OR r.code ILIKE '%' || p_search || '%'
              OR r.type ILIKE '%' || p_search || '%'
              OR r.building ILIKE '%' || p_search || '%'
          )
          AND (p_type = 'ALL' OR p_type = '' OR UPPER(TRIM(r.type)) = UPPER(TRIM(p_type)))
          AND (p_building = 'ALL' OR p_building = '' OR UPPER(TRIM(r.building)) = UPPER(TRIM(p_building)))
          AND (p_floor = 'ALL' OR p_floor = '' OR UPPER(TRIM(r.floor)) = UPPER(TRIM(p_floor)))
          AND (p_status = 'ALL' OR p_status = '' OR UPPER(TRIM(r.status)) = UPPER(TRIM(p_status)))
        ORDER BY
            CASE WHEN p_sort_by = 'name' AND UPPER(p_sort_order) = 'ASC' THEN LOWER(r.name) END ASC,
            CASE WHEN p_sort_by = 'name' AND UPPER(p_sort_order) = 'DESC' THEN LOWER(r.name) END DESC,
            CASE WHEN p_sort_by = 'code' AND UPPER(p_sort_order) = 'ASC' THEN LOWER(COALESCE(r.code, '')) END ASC,
            CASE WHEN p_sort_by = 'code' AND UPPER(p_sort_order) = 'DESC' THEN LOWER(COALESCE(r.code, '')) END DESC,
            CASE WHEN p_sort_by = 'type' AND UPPER(p_sort_order) = 'ASC' THEN LOWER(COALESCE(r.type, '')) END ASC,
            CASE WHEN p_sort_by = 'type' AND UPPER(p_sort_order) = 'DESC' THEN LOWER(COALESCE(r.type, '')) END DESC,
            CASE WHEN p_sort_by = 'building' AND UPPER(p_sort_order) = 'ASC' THEN LOWER(COALESCE(r.building, '')) END ASC,
            CASE WHEN p_sort_by = 'building' AND UPPER(p_sort_order) = 'DESC' THEN LOWER(COALESCE(r.building, '')) END DESC,
            CASE WHEN p_sort_by = 'status' AND UPPER(p_sort_order) = 'ASC' THEN LOWER(COALESCE(r.status, '')) END ASC,
            CASE WHEN p_sort_by = 'status' AND UPPER(p_sort_order) = 'DESC' THEN LOWER(COALESCE(r.status, '')) END DESC,
            CASE WHEN p_sort_by = 'capacity' AND UPPER(p_sort_order) = 'ASC' THEN r.capacity END ASC,
            CASE WHEN p_sort_by = 'capacity' AND UPPER(p_sort_order) = 'DESC' THEN r.capacity END DESC,
            r.building ASC, r.floor ASC, r.name ASC, r.id ASC
        LIMIT p_page_size
        OFFSET v_offset
    ) r_item;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'rooms', v_rooms,
            'total_count', v_total_count,
            'page', p_page,
            'page_size', p_page_size,
            'total_pages', CEIL(v_total_count::NUMERIC / GREATEST(p_page_size, 1))::INT
        )
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_get_exam_monitoring_candidates(p_school_id uuid, p_exam_id uuid, p_actor_id uuid, p_actor_role text, p_status text DEFAULT NULL::text, p_violation_filter text DEFAULT NULL::text, p_search text DEFAULT NULL::text, p_class_filter text DEFAULT NULL::text, p_page integer DEFAULT 1, p_page_size integer DEFAULT 8, p_sort_by text DEFAULT 'status_priority'::text, p_sort_dir text DEFAULT 'asc'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_auth RECORD;
    v_exam_duration INT := 60;
    v_total_questions INT := 0;
    v_exam_paused BOOLEAN := FALSE;
    v_exam_paused_at TIMESTAMPTZ;
    v_page INT := GREATEST(1, COALESCE(p_page, 1));
    v_page_size INT := LEAST(100, GREATEST(1, COALESCE(p_page_size, 8)));
    v_offset INT;
    v_total INT := 0;
    v_items JSONB := '[]'::jsonb;
BEGIN
    SELECT * INTO v_auth FROM public._can_monitor_exam(p_school_id, p_exam_id, p_actor_id, p_actor_role);
    IF NOT v_auth.allowed THEN
        RETURN jsonb_build_object('success', FALSE, 'status', v_auth.http_status, 'error', v_auth.denial_reason);
    END IF;

    PERFORM public._sweep_stale_exam_sessions(COALESCE(v_auth.exam_school_id, p_school_id), p_exam_id);

    SELECT COALESCE(duration_minutes, 60) INTO v_exam_duration FROM public.exams WHERE id = p_exam_id;
    SELECT COUNT(*)::INT INTO v_total_questions FROM public.exam_questions WHERE exam_id = p_exam_id;
    SELECT (status = 'PAUSED'), paused_at INTO v_exam_paused, v_exam_paused_at
    FROM public.exam_monitoring_sessions WHERE exam_id = p_exam_id LIMIT 1;

    v_offset := (v_page - 1) * v_page_size;

    WITH roster AS (
        SELECT * FROM public._resolve_exam_roster(COALESCE(v_auth.exam_school_id, p_school_id), p_exam_id)
    ),
    latest_sessions AS (
        SELECT DISTINCT ON (es.student_id) es.*
        FROM public.exam_sessions es
        WHERE es.exam_id = p_exam_id
        ORDER BY es.student_id, es.started_at DESC NULLS LAST, es.created_at DESC
    ),
    latest_prestart AS (
        SELECT DISTINCT ON (ep.student_id) ep.*
        FROM public.exam_prestart_sessions ep
        WHERE ep.exam_id = p_exam_id
        ORDER BY ep.student_id, ep.updated_at DESC
    ),
    sub_stats AS (
        SELECT DISTINCT ON (sub.student_id)
            sub.student_id,
            sub.status AS submission_status,
            sub.submitted_at,
            sub.updated_at AS submission_updated_at,
            CASE
                WHEN jsonb_typeof(sub.answers) = 'object' THEN
                    (SELECT COUNT(*)::INT FROM jsonb_each(sub.answers) kv WHERE kv.value IS NOT NULL AND kv.value::TEXT NOT IN ('""', 'null', '[]', '{}'))
                ELSE 0
            END AS calc_answered_count
        FROM public.exam_submissions sub
        WHERE sub.exam_id = p_exam_id
        ORDER BY sub.student_id, sub.updated_at DESC
    ),
    inc_stats AS (
        SELECT
            ei.candidate_id,
            COUNT(*)::INT AS total_incidents,
            COUNT(*) FILTER (WHERE ei.status IN ('open', 'acknowledged', 'escalated'))::INT AS open_incidents,
            MAX(ei.occurred_at) AS last_incident_at,
            (ARRAY_AGG(ei.title ORDER BY ei.occurred_at DESC))[1] AS last_incident_title,
            (ARRAY_AGG(ei.severity ORDER BY ei.occurred_at DESC))[1] AS last_incident_severity
        FROM public.exam_incidents ei
        WHERE ei.exam_id = p_exam_id
        GROUP BY ei.candidate_id
    ),
    reentry_stats AS (
        SELECT DISTINCT ON (rr.candidate_id)
            rr.candidate_id,
            rr.id AS pending_request_id,
            rr.reason AS reentry_reason,
            rr.requested_at AS reentry_requested_at
        FROM public.candidate_reentry_requests rr
        WHERE rr.exam_id = p_exam_id AND rr.status = 'pending'
        ORDER BY rr.candidate_id, rr.requested_at DESC
    ),
    enriched AS (
        SELECT
            r.candidate_id,
            COALESCE(ls.id::TEXT, '') AS session_id,
            r.full_name,
            r.role,
            r.class_name,
            COALESCE(r.roll_number::TEXT, '') AS roll_number,
            r.email,
            r.avatar_url,
            CASE
                WHEN ls.id IS NULL THEN
                    CASE WHEN UPPER(COALESCE(lp.readiness_status, '')) = 'READY' THEN 'READY' ELSE 'NOT_STARTED' END
                ELSE UPPER(COALESCE(ls.monitoring_status, 'ACTIVE'))
            END AS monitoring_status,
            COALESCE(ls.status, 'not_started') AS session_status,
            COALESCE(ls.is_online, FALSE) AS is_online,
            COALESCE(ls.is_paused, FALSE) AS is_paused,
            ls.paused_reason,
            COALESCE(ls.warnings_count, 0) AS warnings_count,
            COALESCE(inc.total_incidents, 0) AS incidents_count,
            COALESCE(inc.open_incidents, 0) AS open_incidents_count,
            inc.last_incident_title,
            inc.last_incident_severity,
            COALESCE(inc.last_incident_at, ls.last_ping, lp.last_activity_at) AS last_activity_at,
            ls.started_at,
            ls.ended_at,
            ls.last_ping,
            COALESCE(ls.extra_minutes, 0) AS extra_minutes,
            COALESCE(ls.reentry_count, 0) AS reentry_count,
            COALESCE(ls.max_reentry_attempts, 2) AS max_reentry_attempts,
            COALESCE(ls.camera_active, FALSE) AS camera_active,
            COALESCE(ls.camera_permission_state, COALESCE(lp.camera_status, 'NOT_CHECKED')) AS camera_permission_state,
            COALESCE(ls.mic_active, FALSE) AS mic_active,
            COALESCE(ls.mic_permission_state, COALESCE(lp.microphone_status, 'NOT_CHECKED')) AS mic_permission_state,
            COALESCE(ls.screen_share_active, FALSE) AS screen_share_active,
            COALESCE(ls.screen_share_state, COALESCE(lp.screen_share_status, 'NOT_SHARED')) AS screen_share_state,
            COALESCE(ls.livekit_connected, FALSE) AS livekit_connected,
            COALESCE(ls.livekit_identity, 'candidate_' || r.candidate_id::TEXT) AS livekit_identity,
            COALESCE(ls.network_status, 'GOOD') AS network_status,
            ls.latency_ms,
            COALESCE(ls.face_detected_count, 1) AS face_detected_count,
            ls.browser_info,
            COALESCE(ls.device_info, '{}'::jsonb) AS device_info,
            COALESCE(ls.last_answer_sync_at, ss.submission_updated_at) AS last_answer_sync_at,
            GREATEST(COALESCE(ls.answered_count, 0), COALESCE(ss.calc_answered_count, 0)) AS answered_count,
            CASE WHEN COALESCE(ls.total_questions_snapshot, 0) > 0 THEN ls.total_questions_snapshot ELSE v_total_questions END AS total_questions,
            COALESCE(ls.current_question_index, 0) AS current_question_index,
            ls.teacher_message,
            rr.pending_request_id,
            rr.reentry_reason,
            rr.reentry_requested_at,
            public._compute_session_remaining_seconds(
                ls.started_at, v_exam_duration, COALESCE(ls.extra_minutes, 0),
                COALESCE(ls.paused_total_seconds, 0), COALESCE(ls.is_paused, FALSE),
                ls.paused_at, ls.timer_pause_policy,
                COALESCE(ls.monitoring_status, 'NOT_STARTED'),
                v_exam_paused, v_exam_paused_at
            ) AS remaining_seconds,
            CASE UPPER(COALESCE(ls.monitoring_status, 'NOT_STARTED'))
                WHEN 'VIOLATION' THEN 1
                WHEN 'DISCONNECTED' THEN 2
                WHEN 'WARNING' THEN 3
                WHEN 'UNDER_REVIEW' THEN 4
                WHEN 'PAUSED' THEN 5
                WHEN 'RECONNECTING' THEN 6
                WHEN 'ACTIVE' THEN 7
                WHEN 'READY' THEN 8
                WHEN 'NOT_STARTED' THEN 9
                WHEN 'SUBMITTED' THEN 10
                WHEN 'AUTO_SUBMITTED' THEN 11
                WHEN 'TERMINATED' THEN 12
                ELSE 99
            END AS priority_rank
        FROM roster r
        LEFT JOIN latest_sessions ls ON ls.student_id = r.candidate_id
        LEFT JOIN latest_prestart lp ON lp.student_id = r.candidate_id
        LEFT JOIN sub_stats ss ON ss.student_id = r.candidate_id
        LEFT JOIN inc_stats inc ON inc.candidate_id = r.candidate_id
        LEFT JOIN reentry_stats rr ON rr.candidate_id = r.candidate_id
    ),
    filtered AS (
        SELECT *
        FROM enriched e
        WHERE (
            p_status IS NULL OR BTRIM(p_status) = '' OR LOWER(p_status) IN ('all', 'all status')
            OR (LOWER(p_status) = 'in_exam' AND e.monitoring_status IN ('ACTIVE', 'READY'))
            OR (LOWER(p_status) = 'active' AND e.monitoring_status IN ('ACTIVE', 'WARNING', 'VIOLATION'))
            OR (LOWER(p_status) = 'warning' AND e.monitoring_status IN ('WARNING', 'RECONNECTING'))
            OR (LOWER(p_status) = 'violation' AND e.monitoring_status IN ('VIOLATION', 'UNDER_REVIEW'))
            OR (LOWER(p_status) = 'paused' AND e.monitoring_status = 'PAUSED')
            OR (LOWER(p_status) = 'disconnected' AND e.monitoring_status = 'DISCONNECTED')
            OR (LOWER(p_status) = 'not_started' AND e.monitoring_status IN ('NOT_STARTED', 'READY'))
            OR (LOWER(p_status) = 'completed' AND e.monitoring_status IN ('SUBMITTED', 'AUTO_SUBMITTED', 'TERMINATED'))
            OR UPPER(e.monitoring_status) = UPPER(p_status)
        )
        AND (
            p_violation_filter IS NULL OR BTRIM(p_violation_filter) = '' OR LOWER(p_violation_filter) IN ('all', 'all violations')
            OR (LOWER(p_violation_filter) IN ('with_violations', 'flagged') AND (e.warnings_count > 0 OR e.incidents_count > 0))
            OR (LOWER(p_violation_filter) IN ('clean', 'none', '0') AND e.warnings_count = 0 AND e.incidents_count = 0)
            OR (LOWER(p_violation_filter) = 'high' AND e.warnings_count >= 2)
            OR (LOWER(p_violation_filter) = 'pending_reentry' AND e.pending_request_id IS NOT NULL)
        )
        AND (
            p_class_filter IS NULL OR BTRIM(p_class_filter) = '' OR LOWER(p_class_filter) IN ('all', 'all students', 'all classes')
            OR LOWER(e.class_name) = LOWER(p_class_filter)
        )
        AND (
            p_search IS NULL OR BTRIM(p_search) = ''
            OR LOWER(e.full_name) LIKE '%' || LOWER(BTRIM(p_search)) || '%'
            OR LOWER(COALESCE(e.roll_number, '')) LIKE '%' || LOWER(BTRIM(p_search)) || '%'
            OR LOWER(COALESCE(e.email, '')) LIKE '%' || LOWER(BTRIM(p_search)) || '%'
            OR LOWER(COALESCE(e.class_name, '')) LIKE '%' || LOWER(BTRIM(p_search)) || '%'
        )
    ),
    counted AS (
        SELECT COUNT(*)::INT AS total_rows FROM filtered
    ),
    paged AS (
        SELECT f.*
        FROM filtered f
        ORDER BY
            CASE WHEN LOWER(p_sort_by) = 'name' AND LOWER(p_sort_dir) = 'desc' THEN LOWER(f.full_name) END DESC,
            CASE WHEN LOWER(p_sort_by) = 'name' AND LOWER(p_sort_dir) <> 'desc' THEN LOWER(f.full_name) END ASC,
            CASE WHEN LOWER(p_sort_by) = 'violations' AND LOWER(p_sort_dir) = 'asc' THEN f.warnings_count END ASC,
            CASE WHEN LOWER(p_sort_by) = 'violations' AND LOWER(p_sort_dir) <> 'asc' THEN f.warnings_count END DESC,
            CASE WHEN LOWER(p_sort_by) = 'roll' AND LOWER(p_sort_dir) = 'desc' THEN COALESCE(f.roll_number, '') END DESC,
            CASE WHEN LOWER(p_sort_by) = 'roll' AND LOWER(p_sort_dir) <> 'desc' THEN COALESCE(f.roll_number, '') END ASC,
            CASE WHEN LOWER(p_sort_by) = 'status' AND LOWER(p_sort_dir) = 'desc' THEN f.priority_rank END DESC,
            CASE WHEN LOWER(p_sort_by) = 'status' AND LOWER(p_sort_dir) <> 'desc' THEN f.priority_rank END ASC,
            CASE WHEN LOWER(p_sort_by) = 'activity' AND LOWER(p_sort_dir) = 'asc' THEN COALESCE(f.last_ping, f.last_answer_sync_at, f.started_at) END ASC NULLS LAST,
            CASE WHEN LOWER(p_sort_by) = 'activity' AND LOWER(p_sort_dir) <> 'asc' THEN COALESCE(f.last_ping, f.last_answer_sync_at, f.started_at) END DESC NULLS LAST,
            CASE WHEN LOWER(p_sort_by) NOT IN ('name', 'violations', 'roll', 'status', 'activity') THEN f.priority_rank END ASC,
            f.full_name ASC,
            f.candidate_id ASC
        LIMIT v_page_size OFFSET v_offset
    )
    SELECT
        (SELECT total_rows FROM counted),
        COALESCE(jsonb_agg(row_to_json(p)), '[]'::jsonb)
    INTO v_total, v_items
    FROM paged p;

    RETURN jsonb_build_object(
        'success', TRUE,
        'candidates', v_items,
        'pagination', jsonb_build_object(
            'page', v_page,
            'page_size', v_page_size,
            'total', COALESCE(v_total, 0),
            'total_pages', GREATEST(1, CEIL(COALESCE(v_total, 0)::NUMERIC / v_page_size)::INT)
        )
    );
END;
$function$;

