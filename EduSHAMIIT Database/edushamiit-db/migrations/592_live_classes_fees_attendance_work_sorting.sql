-- Migration 592: Live Classes, Payment Management, Attendance & Work Management DB sorting + tie-breakers

CREATE OR REPLACE FUNCTION public.sp_get_live_class_my_classes_list(p_school_id uuid, p_user_id uuid DEFAULT NULL::uuid, p_date_filter text DEFAULT 'today'::text, p_session_name text DEFAULT NULL::text, p_class_id uuid DEFAULT NULL::uuid, p_subject_id uuid DEFAULT NULL::uuid, p_status text DEFAULT NULL::text, p_search text DEFAULT NULL::text, p_page integer DEFAULT 1, p_page_size integer DEFAULT 5, p_section_id uuid DEFAULT NULL::uuid, p_sort_by text DEFAULT 'scheduled_at'::text, p_sort_order text DEFAULT 'ASC'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_date_filter TEXT := LOWER(TRIM(COALESCE(p_date_filter, 'today')));
    v_status TEXT := LOWER(TRIM(COALESCE(p_status, 'all')));
    v_offset INT;
    v_total_count INT;
    v_items JSONB := '[]'::JSONB;
BEGIN
    v_offset := (GREATEST(p_page, 1) - 1) * GREATEST(p_page_size, 1);

    -- 1. Count Total
    SELECT COUNT(*) INTO v_total_count
    FROM public.live_classes c
    LEFT JOIN public.academic_classes ac ON ac.id = c.class_id
    LEFT JOIN public.academic_sections sec ON sec.id = c.section_id
    LEFT JOIN public.subjects s ON s.id = c.subject_id
    LEFT JOIN public.profiles p ON p.id = c.teacher_id
    WHERE (p_school_id IS NULL OR c.school_id = p_school_id)
      AND (p_user_id IS NULL OR c.teacher_id = p_user_id OR c.co_host_id = p_user_id)
      AND (p_class_id IS NULL OR c.class_id = p_class_id)
      AND (p_section_id IS NULL OR c.section_id = p_section_id)
      AND (p_subject_id IS NULL OR c.subject_id = p_subject_id)
      AND (
          v_status = 'all' OR v_status = ''
          OR (v_status = 'live' AND (c.status = 'live' OR c.is_live = TRUE))
          OR (v_status = 'upcoming' AND c.status IN ('upcoming', 'scheduled') AND c.status != 'live' AND c.is_live = FALSE)
          OR (v_status = 'completed' AND (c.status IN ('completed', 'recorded') OR c.ended_at IS NOT NULL))
          OR (v_status = 'scheduled' AND c.status = 'scheduled')
          OR (v_status = 'cancelled' AND c.status = 'cancelled')
          OR LOWER(c.status) = v_status
      )
      AND (
          v_date_filter = 'all'
          OR (v_date_filter = 'today' AND (c.scheduled_at::DATE = CURRENT_DATE OR c.created_at::DATE = CURRENT_DATE))
          OR (v_date_filter IN ('this week', 'week') AND c.scheduled_at >= DATE_TRUNC('week', CURRENT_DATE))
          OR (v_date_filter IN ('this month', 'month') AND c.scheduled_at >= DATE_TRUNC('month', CURRENT_DATE))
      )
      AND (
          p_search IS NULL OR p_search = ''
          OR c.title ILIKE '%' || p_search || '%'
          OR COALESCE(s.name, '') ILIKE '%' || p_search || '%'
          OR COALESCE(ac.name, '') ILIKE '%' || p_search || '%'
          OR COALESCE(c.target_class, '') ILIKE '%' || p_search || '%'
          OR COALESCE(p.full_name, '') ILIKE '%' || p_search || '%'
          OR COALESCE(c.room_code, '') ILIKE '%' || p_search || '%'
      );

    -- 2. Fetch Records
    SELECT COALESCE(jsonb_agg(item), '[]'::JSONB) INTO v_items
    FROM (
        SELECT jsonb_build_object(
            'id', c.id,
            'class_section', COALESCE(ac.name || ' - ' || sec.name, c.target_class, 'Class 10 - A'),
            'class_id', c.class_id,
            'section_id', c.section_id,
            'subject_id', c.subject_id,
            'subject_name', COALESCE(s.name, 'Mathematics'),
            'subject_icon', COALESCE(s.icon, CASE 
                WHEN s.name ILIKE '%math%' THEN '📐'
                WHEN s.name ILIKE '%phys%' THEN '⚛️'
                WHEN s.name ILIKE '%chem%' THEN '🧪'
                WHEN s.name ILIKE '%bio%' OR s.name ILIKE '%sci%' THEN '🔬'
                WHEN s.name ILIKE '%eng%' THEN '📖'
                ELSE '📚'
            END),
            'topic', COALESCE(c.title, 'Class Session'),
            'description', COALESCE(c.description, ''),
            'teacher_id', c.teacher_id,
            'teacher_name', COALESCE(p.full_name, 'Aarav Sharma'),
            'co_teacher_name', COALESCE(co.full_name, 'Teacher'),
            'scheduled_date_str', TO_CHAR(COALESCE(c.scheduled_at, NOW()), 'Dy, DD Mon YYYY'),
            'scheduled_time_str', TO_CHAR(COALESCE(c.scheduled_at, NOW()), 'HH12:MI AM') || ' - ' ||
                                 TO_CHAR(COALESCE(c.scheduled_at + (COALESCE(c.duration_minutes, 45) || ' minutes')::INTERVAL, NOW() + INTERVAL '45 minutes'), 'HH12:MI AM') ||
                                 ' (' || COALESCE(c.duration_minutes, 45) || ' min)',
            'start_time', TO_CHAR(COALESCE(c.scheduled_at, NOW()), 'HH12:MI AM'),
            'end_time', TO_CHAR(COALESCE(c.scheduled_at + (COALESCE(c.duration_minutes, 45) || ' minutes')::INTERVAL, NOW() + INTERVAL '45 minutes'), 'HH12:MI AM'),
            'duration_minutes', COALESCE(c.duration_minutes, 45),
            'status', CASE 
                WHEN c.status = 'live' OR c.is_live = TRUE THEN 'Live'
                WHEN c.status IN ('completed', 'recorded') OR c.ended_at IS NOT NULL THEN 'Completed'
                WHEN c.status = 'cancelled' THEN 'Cancelled'
                ELSE 'Upcoming'
            END,
            'viewer_count', COALESCE(c.viewer_count, 0),
            'max_participants', COALESCE(c.max_participants, 45),
            'student_count_str', COALESCE(c.viewer_count, 0)::TEXT || ' / ' || COALESCE(c.max_participants, 45)::TEXT,
            'attendance_percentage', CASE WHEN c.status = 'live' OR c.is_live = TRUE THEN 93 WHEN c.status IN ('completed', 'recorded') THEN 95 ELSE 0 END,
            'room_code', COALESCE(c.room_code, '10A-MATH'),
            'meeting_link', COALESCE(c.meeting_link, 'https://meet.edushamiit.com/cls/' || LOWER(COALESCE(c.room_code, 'live'))),
            'recording_status', COALESCE(c.recording_status, 'RECORDING'),
            'recording_enabled', COALESCE(c.recording_enabled, TRUE)
        ) AS item
        FROM public.live_classes c
        LEFT JOIN public.academic_classes ac ON ac.id = c.class_id
        LEFT JOIN public.academic_sections sec ON sec.id = c.section_id
        LEFT JOIN public.subjects s ON s.id = c.subject_id
        LEFT JOIN public.profiles p ON p.id = c.teacher_id
        LEFT JOIN public.profiles co ON co.id = c.co_host_id
        WHERE (p_school_id IS NULL OR c.school_id = p_school_id)
          AND (p_user_id IS NULL OR c.teacher_id = p_user_id OR c.co_host_id = p_user_id)
          AND (p_class_id IS NULL OR c.class_id = p_class_id)
          AND (p_section_id IS NULL OR c.section_id = p_section_id)
          AND (p_subject_id IS NULL OR c.subject_id = p_subject_id)
          AND (
              v_status = 'all' OR v_status = ''
              OR (v_status = 'live' AND (c.status = 'live' OR c.is_live = TRUE))
              OR (v_status = 'upcoming' AND c.status IN ('upcoming', 'scheduled') AND c.status != 'live' AND c.is_live = FALSE)
              OR (v_status = 'completed' AND (c.status IN ('completed', 'recorded') OR c.ended_at IS NOT NULL))
              OR (v_status = 'scheduled' AND c.status = 'scheduled')
              OR (v_status = 'cancelled' AND c.status = 'cancelled')
              OR LOWER(c.status) = v_status
          )
          AND (
              v_date_filter = 'all'
              OR (v_date_filter = 'today' AND (c.scheduled_at::DATE = CURRENT_DATE OR c.created_at::DATE = CURRENT_DATE))
              OR (v_date_filter IN ('this week', 'week') AND c.scheduled_at >= DATE_TRUNC('week', CURRENT_DATE))
              OR (v_date_filter IN ('this month', 'month') AND c.scheduled_at >= DATE_TRUNC('month', CURRENT_DATE))
          )
          AND (
              p_search IS NULL OR p_search = ''
              OR c.title ILIKE '%' || p_search || '%'
              OR COALESCE(s.name, '') ILIKE '%' || p_search || '%'
              OR COALESCE(ac.name, '') ILIKE '%' || p_search || '%'
              OR COALESCE(c.target_class, '') ILIKE '%' || p_search || '%'
              OR COALESCE(p.full_name, '') ILIKE '%' || p_search || '%'
              OR COALESCE(c.room_code, '') ILIKE '%' || p_search || '%'
          )
        ORDER BY 
            CASE WHEN LOWER(COALESCE(p_sort_by, 'scheduled_at')) = 'class_name' AND UPPER(COALESCE(p_sort_order, 'ASC')) = 'ASC' THEN LOWER(COALESCE(NULLIF(TRIM(CONCAT_WS(' - ', ac.name, sec.name)), ''), c.target_class, '')) END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'scheduled_at')) = 'class_name' AND UPPER(COALESCE(p_sort_order, 'ASC')) = 'DESC' THEN LOWER(COALESCE(NULLIF(TRIM(CONCAT_WS(' - ', ac.name, sec.name)), ''), c.target_class, '')) END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'scheduled_at')) = 'subject_name' AND UPPER(COALESCE(p_sort_order, 'ASC')) = 'ASC' THEN LOWER(COALESCE(s.name, '')) END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'scheduled_at')) = 'subject_name' AND UPPER(COALESCE(p_sort_order, 'ASC')) = 'DESC' THEN LOWER(COALESCE(s.name, '')) END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'scheduled_at')) = 'title' AND UPPER(COALESCE(p_sort_order, 'ASC')) = 'ASC' THEN LOWER(COALESCE(c.title, '')) END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'scheduled_at')) = 'title' AND UPPER(COALESCE(p_sort_order, 'ASC')) = 'DESC' THEN LOWER(COALESCE(c.title, '')) END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'scheduled_at')) = 'status' AND UPPER(COALESCE(p_sort_order, 'ASC')) = 'ASC' THEN LOWER(COALESCE(c.status, '')) END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'scheduled_at')) = 'status' AND UPPER(COALESCE(p_sort_order, 'ASC')) = 'DESC' THEN LOWER(COALESCE(c.status, '')) END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'scheduled_at')) = 'viewer_count' AND UPPER(COALESCE(p_sort_order, 'ASC')) = 'ASC' THEN COALESCE(c.viewer_count, 0) END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'scheduled_at')) = 'viewer_count' AND UPPER(COALESCE(p_sort_order, 'ASC')) = 'DESC' THEN COALESCE(c.viewer_count, 0) END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'scheduled_at')) = 'scheduled_at' AND UPPER(COALESCE(p_sort_order, 'ASC')) = 'DESC' THEN COALESCE(c.scheduled_at, c.created_at) END DESC NULLS LAST,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'scheduled_at')) = 'scheduled_at' AND UPPER(COALESCE(p_sort_order, 'ASC')) <> 'DESC' THEN COALESCE(c.scheduled_at, c.created_at) END ASC NULLS LAST,
            c.scheduled_at ASC, c.id ASC
        LIMIT p_page_size
        OFFSET v_offset
    ) sub;

    RETURN jsonb_build_object(
        'items', v_items,
        'total_count', v_total_count,
        'page', p_page,
        'page_size', p_page_size,
        'total_pages', GREATEST(CEIL(v_total_count::NUMERIC / GREATEST(p_page_size, 1)::NUMERIC)::INT, 1)
    );
END;
$function$
;

DROP FUNCTION IF EXISTS public.sp_get_live_class_recordings_list(uuid, uuid, uuid, uuid, text, text, integer, integer);
CREATE OR REPLACE FUNCTION public.sp_get_live_class_recordings_list(p_school_id uuid, p_class_id uuid DEFAULT NULL::uuid, p_subject_id uuid DEFAULT NULL::uuid, p_teacher_id uuid DEFAULT NULL::uuid, p_search text DEFAULT NULL::text, p_status text DEFAULT NULL::text, p_page integer DEFAULT 1, p_page_size integer DEFAULT 8, p_sort_by text DEFAULT 'created_at', p_sort_order text DEFAULT 'DESC')
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_offset INT := (GREATEST(1, p_page) - 1) * GREATEST(1, p_page_size);
    v_total INT := 0;
    v_items JSONB := '[]'::jsonb;
BEGIN
    SELECT COUNT(*) INTO v_total
    FROM public.live_class_recordings r
    LEFT JOIN public.live_classes c ON c.id = r.live_class_id
    WHERE (p_school_id IS NULL OR COALESCE(r.school_id, c.school_id) = p_school_id)
      AND r.deleted_at IS NULL
      AND (p_class_id IS NULL OR COALESCE(r.class_id, c.class_id) = p_class_id)
      AND (p_subject_id IS NULL OR COALESCE(r.subject_id, c.subject_id) = p_subject_id)
      AND (p_teacher_id IS NULL OR COALESCE(r.teacher_id, c.teacher_id) = p_teacher_id)
      AND (p_status IS NULL OR p_status = 'All' OR r.processing_status ILIKE p_status)
      AND (
          p_search IS NULL
          OR r.title ILIKE '%' || p_search || '%'
          OR COALESCE(c.title, '') ILIKE '%' || p_search || '%'
          OR COALESCE(r.description, '') ILIKE '%' || p_search || '%'
      );

    SELECT COALESCE(jsonb_agg(item), '[]'::jsonb) INTO v_items
    FROM (
        SELECT
            r.id,
            COALESCE(r.live_class_id::TEXT, '') AS live_class_id,
            COALESCE(NULLIF(TRIM(r.title), ''), NULLIF(TRIM(c.title), ''), 'Recorded Lecture') AS title,
            r.description,
            r.recording_url,
            r.storage_key,
            COALESCE(r.mime_type, 'video/mp4') AS mime_type,
            COALESCE(r.class_id, c.class_id)::TEXT AS class_id,
            COALESCE(r.section_id, c.section_id)::TEXT AS section_id,
            COALESCE(r.subject_id, c.subject_id)::TEXT AS subject_id,
            COALESCE(r.teacher_id, c.teacher_id)::TEXT AS teacher_id,
            COALESCE(
                NULLIF(TRIM(CONCAT_WS(' - ', ac.name, sec.name)), ''),
                NULLIF(TRIM(c.target_class), ''),
                'Class'
            ) AS class_section,
            COALESCE(s.name, 'General') AS subject_name,
            COALESCE(NULLIF(TRIM(r.teacher_name), ''), p.full_name, 'Teacher') AS teacher_name,
            TO_CHAR(COALESCE(r.created_at, c.scheduled_at, NOW()), 'DD Mon YYYY, HH12:MI AM') AS date_time_str,
            CASE
                WHEN COALESCE(r.duration, 0) < 60 THEN GREATEST(1, ROUND(COALESCE(r.duration, 60) / 60.0)::INT) || ' min'
                ELSE ROUND(r.duration / 60.0)::INT || ' min'
            END AS duration_str,
            COALESCE(r.duration, 0) AS duration_seconds,
            COALESCE(r.views_count, 0) AS views,
            COALESCE(r.downloads_count, 0) AS downloads_count,
            COALESCE(r.file_size, 0) AS file_size,
            CASE
                WHEN COALESCE(r.file_size, 0) >= 1048576 THEN ROUND((r.file_size::NUMERIC / 1048576.0), 1)::TEXT || ' MB'
                WHEN COALESCE(r.file_size, 0) >= 1024 THEN ROUND((r.file_size::NUMERIC / 1024.0), 1)::TEXT || ' KB'
                ELSE COALESCE(r.file_size, 0)::TEXT || ' B'
            END AS size_str,
            COALESCE(r.processing_status, 'Processed') AS status,
            COALESCE(r.visibility, 'CLASS') AS visibility,
            COALESCE(
                NULLIF(TRIM(r.recording_type), ''),
                CASE WHEN r.live_class_id IS NULL THEN 'Uploaded Recording' ELSE 'Live Class' END
            ) AS type,
            COALESCE(
                (SELECT jsonb_agg(t) FROM jsonb_array_elements_text(COALESCE(r.tags, '[]'::jsonb)) t),
                '[]'::jsonb
            ) AS tags,
            GREATEST(
                COALESCE(r.shared_count, 0),
                (SELECT COUNT(*)::INT FROM public.live_class_recording_shares rs WHERE rs.recording_id = r.id)
            ) AS shared_count,
            r.uploaded_by::TEXT AS uploaded_by,
            r.created_at
        FROM public.live_class_recordings r
        LEFT JOIN public.live_classes c ON c.id = r.live_class_id
        LEFT JOIN public.subjects s ON s.id = COALESCE(r.subject_id, c.subject_id)
        LEFT JOIN public.academic_classes ac ON ac.id = COALESCE(r.class_id, c.class_id)
        LEFT JOIN public.academic_sections sec ON sec.id = COALESCE(r.section_id, c.section_id)
        LEFT JOIN public.profiles p ON p.id = COALESCE(r.teacher_id, c.teacher_id)
        WHERE (p_school_id IS NULL OR COALESCE(r.school_id, c.school_id) = p_school_id)
          AND r.deleted_at IS NULL
          AND (p_class_id IS NULL OR COALESCE(r.class_id, c.class_id) = p_class_id)
          AND (p_subject_id IS NULL OR COALESCE(r.subject_id, c.subject_id) = p_subject_id)
          AND (p_teacher_id IS NULL OR COALESCE(r.teacher_id, c.teacher_id) = p_teacher_id)
          AND (p_status IS NULL OR p_status = 'All' OR r.processing_status ILIKE p_status)
          AND (
              p_search IS NULL
              OR r.title ILIKE '%' || p_search || '%'
              OR COALESCE(c.title, '') ILIKE '%' || p_search || '%'
              OR COALESCE(r.description, '') ILIKE '%' || p_search || '%'
          )
        ORDER BY
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'title' AND UPPER(COALESCE(p_sort_order, 'DESC')) = 'ASC' THEN LOWER(COALESCE(NULLIF(TRIM(r.title), ''), NULLIF(TRIM(c.title), ''), 'Recorded Lecture')) END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'title' AND UPPER(COALESCE(p_sort_order, 'DESC')) <> 'ASC' THEN LOWER(COALESCE(NULLIF(TRIM(r.title), ''), NULLIF(TRIM(c.title), ''), 'Recorded Lecture')) END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) IN ('class_section', 'class_name') AND UPPER(COALESCE(p_sort_order, 'DESC')) = 'ASC' THEN LOWER(COALESCE(NULLIF(TRIM(CONCAT_WS(' - ', ac.name, sec.name)), ''), NULLIF(TRIM(c.target_class), ''), 'Class')) END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) IN ('class_section', 'class_name') AND UPPER(COALESCE(p_sort_order, 'DESC')) <> 'ASC' THEN LOWER(COALESCE(NULLIF(TRIM(CONCAT_WS(' - ', ac.name, sec.name)), ''), NULLIF(TRIM(c.target_class), ''), 'Class')) END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'subject_name' AND UPPER(COALESCE(p_sort_order, 'DESC')) = 'ASC' THEN LOWER(COALESCE(s.name, 'General')) END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'subject_name' AND UPPER(COALESCE(p_sort_order, 'DESC')) <> 'ASC' THEN LOWER(COALESCE(s.name, 'General')) END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) IN ('duration', 'duration_seconds') AND UPPER(COALESCE(p_sort_order, 'DESC')) = 'ASC' THEN COALESCE(r.duration, 0) END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) IN ('duration', 'duration_seconds') AND UPPER(COALESCE(p_sort_order, 'DESC')) <> 'ASC' THEN COALESCE(r.duration, 0) END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) IN ('views', 'view_count') AND UPPER(COALESCE(p_sort_order, 'DESC')) = 'ASC' THEN COALESCE(r.views_count, 0) END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) IN ('views', 'view_count') AND UPPER(COALESCE(p_sort_order, 'DESC')) <> 'ASC' THEN COALESCE(r.views_count, 0) END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) IN ('file_size', 'size') AND UPPER(COALESCE(p_sort_order, 'DESC')) = 'ASC' THEN COALESCE(r.file_size, 0) END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) IN ('file_size', 'size') AND UPPER(COALESCE(p_sort_order, 'DESC')) <> 'ASC' THEN COALESCE(r.file_size, 0) END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'visibility' AND UPPER(COALESCE(p_sort_order, 'DESC')) = 'ASC' THEN LOWER(COALESCE(r.visibility, 'CLASS')) END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'visibility' AND UPPER(COALESCE(p_sort_order, 'DESC')) <> 'ASC' THEN LOWER(COALESCE(r.visibility, 'CLASS')) END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'status' AND UPPER(COALESCE(p_sort_order, 'DESC')) = 'ASC' THEN LOWER(COALESCE(r.processing_status, 'Processed')) END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'status' AND UPPER(COALESCE(p_sort_order, 'DESC')) <> 'ASC' THEN LOWER(COALESCE(r.processing_status, 'Processed')) END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'created_at' AND UPPER(COALESCE(p_sort_order, 'DESC')) = 'ASC' THEN COALESCE(r.created_at, c.scheduled_at) END ASC NULLS LAST,
            COALESCE(r.created_at, c.scheduled_at) DESC NULLS LAST, r.id ASC
        LIMIT GREATEST(1, p_page_size) OFFSET v_offset
    ) item;

    RETURN jsonb_build_object(
        'total_count', v_total,
        'page', p_page,
        'page_size', p_page_size,
        'total_pages', GREATEST(1, CEIL(v_total::NUMERIC / GREATEST(1, p_page_size)::NUMERIC))::INT,
        'items', v_items
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.fn_staff_payslips_master(p_school_id uuid, p_month_str text DEFAULT '2026-10'::text, p_department text DEFAULT NULL::text, p_search text DEFAULT NULL::text, p_sort_by text DEFAULT 'payslip_number'::text, p_sort_order text DEFAULT 'DESC'::text, p_page integer DEFAULT 1, p_page_size integer DEFAULT 10)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_total_items INT := 0;
    v_total_pages INT := 1;
    v_offset INT := 0;
    v_payslips JSONB := '[]'::jsonb;
    v_clean_page INT := GREATEST(1, COALESCE(p_page, 1));
    v_clean_size INT := GREATEST(1, LEAST(100, COALESCE(p_page_size, 10)));
BEGIN
    v_offset := (v_clean_page - 1) * v_clean_size;

    WITH ps_raw AS (
        SELECT 
            payout.id,
            payout.payslip_number,
            payout.staff_id,
            p.full_name AS staff_name,
            COALESCE(p.employee_id, 'EMP-' || SUBSTRING(p.id::text, 1, 6)) AS employee_id,
            COALESCE(p.department, 'Academic & Teaching') AS department,
            COALESCE(p.role, 'Teacher') AS role_title,
            COALESCE(p.designation, 'Faculty Member') AS designation,
            COALESCE(p.email, '') AS email,
            COALESCE(p.phone, '') AS phone,
            payout.month,
            payout.year,
            payout.month_str,
            payout.basic_pay,
            payout.hra,
            payout.da,
            payout.ta,
            payout.special_allowance,
            COALESCE(payout.medical_allowance, 0.0) AS medical_allowance,
            payout.bonus,
            (COALESCE(payout.basic_pay,0) + COALESCE(payout.hra,0) + COALESCE(payout.da,0) + 
             COALESCE(payout.ta,0) + COALESCE(payout.special_allowance,0) + 
             COALESCE(payout.medical_allowance,0) + COALESCE(payout.bonus,0)) AS gross_earnings,
            payout.pf_deduction,
            payout.tds,
            payout.professional_tax,
            COALESCE(payout.insurance_deduction, 0.0) AS insurance_deduction,
            COALESCE(payout.advance_deduction, 0.0) AS advance_deduction,
            COALESCE(payout.other_deductions, 0.0) AS other_deductions,
            (COALESCE(payout.pf_deduction,0) + COALESCE(payout.tds,0) + COALESCE(payout.professional_tax,0) + 
             COALESCE(payout.insurance_deduction,0) + COALESCE(payout.advance_deduction,0) + 
             COALESCE(payout.other_deductions,0)) AS total_deductions,
            ((COALESCE(payout.basic_pay,0) + COALESCE(payout.hra,0) + COALESCE(payout.da,0) + 
              COALESCE(payout.ta,0) + COALESCE(payout.special_allowance,0) + 
              COALESCE(payout.medical_allowance,0) + COALESCE(payout.bonus,0)) -
             (COALESCE(payout.pf_deduction,0) + COALESCE(payout.tds,0) + COALESCE(payout.professional_tax,0) + 
              COALESCE(payout.insurance_deduction,0) + COALESCE(payout.advance_deduction,0) + 
              COALESCE(payout.other_deductions,0))) AS net_pay,
            payout.payment_status,
            payout.payment_date,
            payout.payment_mode,
            payout.transaction_reference,
            COALESCE(struct.bank_name, p.bank_name, 'HDFC Bank') AS bank_name,
            COALESCE(struct.account_number, p.account_number, '') AS account_number,
            COALESCE(struct.ifsc_code, p.ifsc_code, '') AS ifsc_code,
            COALESCE(struct.pan_number, p.pan_number, '') AS pan_number
        FROM public.staff_salary_payouts payout
        INNER JOIN public.profiles p ON payout.staff_id = p.id AND payout.school_id = p.school_id
        LEFT JOIN public.staff_salary_structures struct ON payout.staff_id = struct.staff_id AND payout.school_id = struct.school_id
        WHERE payout.school_id = p_school_id 
          AND payout.month_str = p_month_str
          AND p.role NOT IN ('student', 'parent', 'view_only')
          AND (p_department IS NULL OR p_department IN ('All Departments', 'All', '') OR p.department = p_department)
          AND (p_search IS NULL OR p_search = '' OR (
              p.full_name ILIKE '%' || p_search || '%' OR
              COALESCE(p.employee_id, '') ILIKE '%' || p_search || '%' OR
              payout.payslip_number ILIKE '%' || p_search || '%'
          ))
    ),
    counted AS (
        SELECT COUNT(*) AS total_items FROM ps_raw
    ),
    sorted_page AS (
        SELECT * FROM ps_raw
        ORDER BY
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'payslip_number' THEN payslip_number END ASC,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'payslip_number' THEN payslip_number END DESC,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'name' THEN staff_name END ASC,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'name' THEN staff_name END DESC,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'gross' THEN gross_earnings END ASC,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'gross' THEN gross_earnings END DESC,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'deductions' THEN total_deductions END ASC,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'deductions' THEN total_deductions END DESC,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'net' THEN net_pay END ASC,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'net' THEN net_pay END DESC,
            payslip_number DESC, id ASC
        LIMIT v_clean_size OFFSET v_offset
    )
    SELECT 
        (SELECT total_items FROM counted),
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', sp.id,
                    'payslip_number', sp.payslip_number,
                    'staff_id', sp.staff_id,
                    'staff_name', sp.staff_name,
                    'employee_id', sp.employee_id,
                    'department', sp.department,
                    'role', sp.role_title,
                    'designation', sp.designation,
                    'email', sp.email,
                    'phone', sp.phone,
                    'month', sp.month,
                    'year', sp.year,
                    'month_str', sp.month_str,
                    'basic_pay', sp.basic_pay,
                    'hra', sp.hra,
                    'da', sp.da,
                    'ta', sp.ta,
                    'special_allowance', sp.special_allowance,
                    'medical_allowance', sp.medical_allowance,
                    'bonus', sp.bonus,
                    'gross_earnings', sp.gross_earnings,
                    'pf_deduction', sp.pf_deduction,
                    'tds', sp.tds,
                    'professional_tax', sp.professional_tax,
                    'insurance_deduction', sp.insurance_deduction,
                    'advance_deduction', sp.advance_deduction,
                    'other_deductions', sp.other_deductions,
                    'total_deductions', sp.total_deductions,
                    'net_pay', sp.net_pay,
                    'gross_formatted', '₹ ' || TO_CHAR(sp.gross_earnings, 'FM99,99,990.00'),
                    'total_deductions_formatted', '₹ ' || TO_CHAR(sp.total_deductions, 'FM99,99,990.00'),
                    'net_formatted', '₹ ' || TO_CHAR(sp.net_pay, 'FM99,99,990.00'),
                    'payment_status', sp.payment_status,
                    'payment_date', sp.payment_date,
                    'payment_mode', sp.payment_mode,
                    'transaction_reference', sp.transaction_reference,
                    'bank_name', sp.bank_name,
                    'account_number', sp.account_number,
                    'ifsc_code', sp.ifsc_code,
                    'pan_number', sp.pan_number
                )
            ),
            '[]'::jsonb
        )
    INTO v_total_items, v_payslips
    FROM sorted_page sp;

    v_total_pages := GREATEST(1, CEIL(v_total_items::NUMERIC / v_clean_size)::INT);

    RETURN jsonb_build_object(
        'success', true,
        'page', v_clean_page,
        'page_size', v_clean_size,
        'total_items', v_total_items,
        'total_pages', v_total_pages,
        'payslips', v_payslips
    );
END;
$function$
;

DROP FUNCTION IF EXISTS public.fn_list_all_student_invoices(uuid, text, text, integer, integer);
CREATE OR REPLACE FUNCTION public.fn_list_all_student_invoices(p_school_id uuid, p_search text DEFAULT NULL::text, p_status text DEFAULT NULL::text, p_page integer DEFAULT 1, p_page_size integer DEFAULT 15, p_sort_by text DEFAULT 'created_at', p_sort_order text DEFAULT 'DESC')
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_clean_page INT := GREATEST(1, COALESCE(p_page, 1));
    v_clean_size INT := GREATEST(1, LEAST(100, COALESCE(p_page_size, 15)));
    v_offset INT := (v_clean_page - 1) * v_clean_size;
    v_total_items INT := 0;
    v_total_pages INT := 1;
    v_invoices JSONB := '[]'::jsonb;
BEGIN
    WITH filtered AS (
        SELECT 
            i.id, i.invoice_number, i.title, i.fee_type, i.fee_plan, i.due_date,
            i.total_billed, i.paid_amount, i.balance_amount, i.status,
            i.student_id, p.full_name AS student_name, p.roll_number, p.class AS class_name,
            i.created_at,
            GREATEST(0.0, 
                COALESCE((
                    SELECT SUM(pay.amount_paid) 
                    FROM public.student_fee_payments pay 
                    WHERE pay.student_id = i.student_id AND pay.school_id = p_school_id 
                      AND pay.invoice_id IS NULL
                      AND (pay.status IS NULL OR pay.status IN ('SUCCESS', 'COMPLETED', 'VERIFIED_SUCCESS'))
                ), 0.0) +
                COALESCE((
                    SELECT SUM(inv2.paid_amount) 
                    FROM public.student_fee_invoices inv2 
                    WHERE inv2.student_id = i.student_id AND inv2.school_id = p_school_id
                ), 0.0) -
                COALESCE((
                    SELECT SUM(inv3.total_billed) 
                    FROM public.student_fee_invoices inv3 
                    WHERE inv3.student_id = i.student_id AND inv3.school_id = p_school_id
                ), 0.0)
            ) AS student_advance_balance
        FROM public.student_fee_invoices i
        JOIN public.profiles p ON i.student_id = p.id
        WHERE i.school_id = p_school_id
          AND (p_status IS NULL OR p_status = 'All Status' OR p_status = 'All' OR i.status = p_status)
          AND (
              p_search IS NULL OR p_search = '' OR (
                  i.invoice_number ILIKE '%' || p_search || '%' OR
                  p.full_name ILIKE '%' || p_search || '%' OR
                  p.roll_number::text ILIKE '%' || p_search || '%' OR
                  i.title ILIKE '%' || p_search || '%'
              )
          )
    ),
    counted AS (
        SELECT COUNT(*) AS total_count FROM filtered
    ),
    sorted_page AS (
        SELECT f.*, c.total_count
        FROM filtered f
        CROSS JOIN counted c
        ORDER BY
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'invoice_number' AND UPPER(COALESCE(p_sort_order, 'DESC')) = 'ASC' THEN LOWER(COALESCE(f.invoice_number, '')) END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'invoice_number' AND UPPER(COALESCE(p_sort_order, 'DESC')) <> 'ASC' THEN LOWER(COALESCE(f.invoice_number, '')) END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'student_name' AND UPPER(COALESCE(p_sort_order, 'DESC')) = 'ASC' THEN LOWER(COALESCE(f.student_name, '')) END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'student_name' AND UPPER(COALESCE(p_sort_order, 'DESC')) <> 'ASC' THEN LOWER(COALESCE(f.student_name, '')) END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'title' AND UPPER(COALESCE(p_sort_order, 'DESC')) = 'ASC' THEN LOWER(COALESCE(f.title, '')) END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'title' AND UPPER(COALESCE(p_sort_order, 'DESC')) <> 'ASC' THEN LOWER(COALESCE(f.title, '')) END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'due_date' AND UPPER(COALESCE(p_sort_order, 'DESC')) = 'ASC' THEN f.due_date END ASC NULLS LAST,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'due_date' AND UPPER(COALESCE(p_sort_order, 'DESC')) <> 'ASC' THEN f.due_date END DESC NULLS LAST,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'total_billed' AND UPPER(COALESCE(p_sort_order, 'DESC')) = 'ASC' THEN COALESCE(f.total_billed, 0) END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'total_billed' AND UPPER(COALESCE(p_sort_order, 'DESC')) <> 'ASC' THEN COALESCE(f.total_billed, 0) END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'status' AND UPPER(COALESCE(p_sort_order, 'DESC')) = 'ASC' THEN LOWER(COALESCE(f.status, '')) END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'status' AND UPPER(COALESCE(p_sort_order, 'DESC')) <> 'ASC' THEN LOWER(COALESCE(f.status, '')) END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'created_at' AND UPPER(COALESCE(p_sort_order, 'DESC')) = 'ASC' THEN f.created_at END ASC,
            f.created_at DESC, f.id ASC
        LIMIT v_clean_size OFFSET v_offset
    )
    SELECT 
        MAX(sp.total_count),
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', sp.id,
                    'invoice_number', sp.invoice_number,
                    'title', sp.title,
                    'fee_type', sp.fee_type,
                    'fee_plan', sp.fee_plan,
                    'due_date', sp.due_date,
                    'total_billed', sp.total_billed,
                    'paid_amount', sp.paid_amount,
                    'balance_amount', sp.balance_amount,
                    'status', sp.status,
                    'student_id', sp.student_id,
                    'student_name', sp.student_name,
                    'roll_number', sp.roll_number,
                    'class_name', sp.class_name,
                    'created_at', sp.created_at,
                    'student_advance_balance', sp.student_advance_balance
                )
            ), '[]'::jsonb
        ) INTO v_total_items, v_invoices
    FROM sorted_page sp;

    v_total_items := COALESCE(v_total_items, 0);
    IF v_total_items > 0 THEN
        v_total_pages := CEIL(v_total_items::numeric / v_clean_size);
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'invoices', v_invoices,
        'pagination', jsonb_build_object(
            'page', v_clean_page,
            'page_size', v_clean_size,
            'total_items', v_total_items,
            'total_pages', v_total_pages
        )
    );
END;
$function$

;

DROP FUNCTION IF EXISTS public.fn_get_staff_attendance_roster(uuid, date, character varying, character varying, character varying, text, integer, integer, uuid);
CREATE OR REPLACE FUNCTION public.fn_get_staff_attendance_roster(p_school_id uuid, p_date date, p_department character varying DEFAULT 'ALL'::character varying, p_role character varying DEFAULT 'ALL'::character varying, p_status character varying DEFAULT 'ALL'::character varying, p_search text DEFAULT ''::text, p_page integer DEFAULT 1, p_page_size integer DEFAULT 10, p_manager_id uuid DEFAULT NULL::uuid, p_sort_by text DEFAULT 'full_name', p_sort_order text DEFAULT 'ASC')
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_total_count INT := 0;
    v_offset INT;
    v_staff JSONB;
BEGIN
    v_offset := (p_page - 1) * p_page_size;

    SELECT COUNT(*)
    INTO v_total_count
    FROM public.profiles p
    LEFT JOIN public.attendance_staff_records asr ON asr.employee_id = p.id AND asr.attendance_date = p_date AND asr.school_id = p_school_id
    WHERE p.school_id = p_school_id
      AND p.role IN ('teacher', 'faculty', 'instructor', 'staff', 'admin', 'principal', 'driver', 'librarian', 'accountant', 'security', 'hr', 'finance', 'transport', 'support', 'director', 'exam_ctrl')
      AND (p.status IS NULL OR p.status != 'Deleted')
      AND (p_department = 'ALL' OR p.department = p_department)
      AND (p_role = 'ALL' OR p.role = p_role)
      AND (p_status = 'ALL' OR UPPER(COALESCE(asr.status, 'NOT_MARKED')) = UPPER(p_status))
      AND (p_manager_id IS NULL OR p.manager_id = p_manager_id)
      AND (
          p_search = '' 
          OR p.full_name ILIKE '%' || p_search || '%' 
          OR p.email ILIKE '%' || p_search || '%'
          OR p.employee_id ILIKE '%' || p_search || '%'
      );

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', p.id,
                'employee_id', p.id,
                'employee_code', COALESCE(p.employee_id, ''),
                'full_name', p.full_name,
                'email', p.email,
                'avatar_url', p.avatar_url,
                'role', p.role,
                'department', COALESCE(p.department, 'General'),
                'designation', COALESCE(p.designation, p.role),
                'status', COALESCE(asr.status, 'NOT_MARKED'),
                'check_in_time', asr.check_in_time,
                'check_out_time', asr.check_out_time,
                'is_wfh', COALESCE(asr.is_wfh, FALSE),
                'remarks', COALESCE(asr.remarks, ''),
                'manager_name', (SELECT full_name FROM public.profiles WHERE id = p.manager_id),
                'last_updated_at', asr.updated_at,
                'updated_by_name', (SELECT full_name FROM public.profiles WHERE id = asr.updated_by)
            ) ORDER BY p.sort_rn ASC
        ),
        '[]'::JSONB
    ) INTO v_staff
    FROM (
        SELECT p.*, ROW_NUMBER() OVER (
            ORDER BY
                CASE WHEN LOWER(COALESCE(p_sort_by, 'full_name')) = 'employee_code' AND UPPER(COALESCE(p_sort_order, 'ASC')) = 'ASC' THEN LOWER(COALESCE(p.employee_id, '')) END ASC,
                CASE WHEN LOWER(COALESCE(p_sort_by, 'full_name')) = 'employee_code' AND UPPER(COALESCE(p_sort_order, 'ASC')) = 'DESC' THEN LOWER(COALESCE(p.employee_id, '')) END DESC,
                CASE WHEN LOWER(COALESCE(p_sort_by, 'full_name')) = 'department' AND UPPER(COALESCE(p_sort_order, 'ASC')) = 'ASC' THEN LOWER(COALESCE(p.department, 'General')) END ASC,
                CASE WHEN LOWER(COALESCE(p_sort_by, 'full_name')) = 'department' AND UPPER(COALESCE(p_sort_order, 'ASC')) = 'DESC' THEN LOWER(COALESCE(p.department, 'General')) END DESC,
                CASE WHEN LOWER(COALESCE(p_sort_by, 'full_name')) = 'status' AND UPPER(COALESCE(p_sort_order, 'ASC')) = 'ASC' THEN LOWER(COALESCE(asr.status, 'NOT_MARKED')) END ASC,
                CASE WHEN LOWER(COALESCE(p_sort_by, 'full_name')) = 'status' AND UPPER(COALESCE(p_sort_order, 'ASC')) = 'DESC' THEN LOWER(COALESCE(asr.status, 'NOT_MARKED')) END DESC,
                CASE WHEN LOWER(COALESCE(p_sort_by, 'full_name')) = 'check_in' AND UPPER(COALESCE(p_sort_order, 'ASC')) = 'ASC' THEN asr.check_in_time END ASC NULLS LAST,
                CASE WHEN LOWER(COALESCE(p_sort_by, 'full_name')) = 'check_in' AND UPPER(COALESCE(p_sort_order, 'ASC')) = 'DESC' THEN asr.check_in_time END DESC NULLS LAST,
                CASE WHEN LOWER(COALESCE(p_sort_by, 'full_name')) = 'check_out' AND UPPER(COALESCE(p_sort_order, 'ASC')) = 'ASC' THEN asr.check_out_time END ASC NULLS LAST,
                CASE WHEN LOWER(COALESCE(p_sort_by, 'full_name')) = 'check_out' AND UPPER(COALESCE(p_sort_order, 'ASC')) = 'DESC' THEN asr.check_out_time END DESC NULLS LAST,
                CASE WHEN LOWER(COALESCE(p_sort_by, 'full_name')) = 'full_name' AND UPPER(COALESCE(p_sort_order, 'ASC')) = 'DESC' THEN LOWER(COALESCE(p.full_name, '')) END DESC,
                LOWER(COALESCE(p.full_name, '')) ASC,
                p.id ASC
        ) AS sort_rn
        FROM public.profiles p
        LEFT JOIN public.attendance_staff_records asr ON asr.employee_id = p.id AND asr.attendance_date = p_date AND asr.school_id = p_school_id
        WHERE p.school_id = p_school_id
          AND p.role IN ('teacher', 'faculty', 'instructor', 'staff', 'admin', 'principal', 'driver', 'librarian', 'accountant', 'security', 'hr', 'finance', 'transport', 'support', 'director', 'exam_ctrl')
          AND (p.status IS NULL OR p.status != 'Deleted')
          AND (p_department = 'ALL' OR p.department = p_department)
          AND (p_role = 'ALL' OR p.role = p_role)
          AND (p_status = 'ALL' OR UPPER(COALESCE(asr.status, 'NOT_MARKED')) = UPPER(p_status))
          AND (p_manager_id IS NULL OR p.manager_id = p_manager_id)
          AND (
              p_search = '' 
              OR p.full_name ILIKE '%' || p_search || '%' 
              OR p.email ILIKE '%' || p_search || '%'
              OR p.employee_id ILIKE '%' || p_search || '%'
          )
        ORDER BY
            CASE WHEN LOWER(COALESCE(p_sort_by, 'full_name')) = 'employee_code' AND UPPER(COALESCE(p_sort_order, 'ASC')) = 'ASC' THEN LOWER(COALESCE(p.employee_id, '')) END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'full_name')) = 'employee_code' AND UPPER(COALESCE(p_sort_order, 'ASC')) = 'DESC' THEN LOWER(COALESCE(p.employee_id, '')) END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'full_name')) = 'department' AND UPPER(COALESCE(p_sort_order, 'ASC')) = 'ASC' THEN LOWER(COALESCE(p.department, 'General')) END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'full_name')) = 'department' AND UPPER(COALESCE(p_sort_order, 'ASC')) = 'DESC' THEN LOWER(COALESCE(p.department, 'General')) END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'full_name')) = 'status' AND UPPER(COALESCE(p_sort_order, 'ASC')) = 'ASC' THEN LOWER(COALESCE(asr.status, 'NOT_MARKED')) END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'full_name')) = 'status' AND UPPER(COALESCE(p_sort_order, 'ASC')) = 'DESC' THEN LOWER(COALESCE(asr.status, 'NOT_MARKED')) END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'full_name')) = 'check_in' AND UPPER(COALESCE(p_sort_order, 'ASC')) = 'ASC' THEN asr.check_in_time END ASC NULLS LAST,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'full_name')) = 'check_in' AND UPPER(COALESCE(p_sort_order, 'ASC')) = 'DESC' THEN asr.check_in_time END DESC NULLS LAST,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'full_name')) = 'check_out' AND UPPER(COALESCE(p_sort_order, 'ASC')) = 'ASC' THEN asr.check_out_time END ASC NULLS LAST,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'full_name')) = 'check_out' AND UPPER(COALESCE(p_sort_order, 'ASC')) = 'DESC' THEN asr.check_out_time END DESC NULLS LAST,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'full_name')) = 'full_name' AND UPPER(COALESCE(p_sort_order, 'ASC')) = 'DESC' THEN LOWER(COALESCE(p.full_name, '')) END DESC,
            LOWER(COALESCE(p.full_name, '')) ASC,
            p.id ASC
        LIMIT p_page_size OFFSET v_offset
    ) p
    LEFT JOIN public.attendance_staff_records asr ON asr.employee_id = p.id AND asr.attendance_date = p_date AND asr.school_id = p_school_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'staff', v_staff,
            'total_count', v_total_count,
            'page', p_page,
            'page_size', p_page_size,
            'total_pages', CEIL(v_total_count::FLOAT / GREATEST(p_page_size, 1))
        )
    );
END;
$function$

;

DROP FUNCTION IF EXISTS public.sp_get_sprint_capacity_dashboard(uuid, uuid, character varying, character varying, integer, integer, character varying, character varying, character varying, character varying);
CREATE OR REPLACE FUNCTION public.sp_get_sprint_capacity_dashboard(p_school_id uuid, p_sprint_id uuid DEFAULT NULL::uuid, p_team_name character varying DEFAULT 'Digital Campus Team'::character varying, p_search character varying DEFAULT NULL::character varying, p_page integer DEFAULT 1, p_limit integer DEFAULT 10, p_sort_by character varying DEFAULT 'NAME_ASC'::character varying, p_sort_order character varying DEFAULT 'ASC'::character varying, p_role_filter character varying DEFAULT 'ALL'::character varying, p_status_filter character varying DEFAULT 'ALL'::character varying)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$

DECLARE
    v_sprint_id UUID := p_sprint_id;
    v_sprint_row RECORD;
    v_team_name VARCHAR := COALESCE(NULLIF(TRIM(p_team_name), ''), 'All Teams');
    v_is_all_teams BOOLEAN := (LOWER(v_team_name) IN ('all', 'all teams', 'none', '*'));
    v_team_id UUID := NULL;
    v_sprint_days INT := 14;
    v_working_days INT := 10;
    v_total_capacity NUMERIC(10,2) := 0.0;
    v_planned_work NUMERIC(10,2) := 0.0;
    v_actual_work NUMERIC(10,2) := 0.0;
    v_remaining_capacity NUMERIC(10,2) := 0.0;
    v_utilization_pct NUMERIC(5,2) := 0.0;
    v_over_allocation NUMERIC(10,2) := 0.0;
    v_team_members_count INT := 0;
    v_total_filtered_count INT := 0;
    v_overloaded_count INT := 0;
    v_members_list JSONB := '[]'::jsonb;
    v_daily_chart JSONB := '[]'::jsonb;
    v_burndown_chart JSONB := '[]'::jsonb;
    v_teams_list JSONB := '[]'::jsonb;
    v_all_sprints_list JSONB := '[]'::jsonb;
    v_available_roles JSONB := '[]'::jsonb;
    v_insights JSONB := '[]'::jsonb;
    v_page INT := GREATEST(COALESCE(p_page, 1), 1);
    v_limit INT := p_limit;
    v_offset INT := 0;
    v_total_pages INT := 1;
    v_day_idx INT;
    v_curr_date DATE;
    v_date_fmt VARCHAR;
    v_ideal_remain NUMERIC(10,2);
    v_actual_remain NUMERIC(10,2);
    v_cum_completed NUMERIC(10,2);
    v_daily_cap NUMERIC(10,2);
BEGIN
    -- 1. Identify Target Sprint (default to latest ACTIVE sprint)
    IF v_sprint_id IS NULL THEN
        SELECT id INTO v_sprint_id
        FROM public.work_sprints
        WHERE school_id = p_school_id AND status = 'ACTIVE'
        ORDER BY start_date DESC LIMIT 1;

        IF v_sprint_id IS NULL THEN
            SELECT id INTO v_sprint_id
            FROM public.work_sprints
            WHERE school_id = p_school_id
            ORDER BY start_date DESC LIMIT 1;
        END IF;
    END IF;

    -- Fetch Sprint Details
    SELECT s.*,
           to_char(s.start_date, 'Mon DD, YYYY') AS start_date_fmt,
           to_char(s.end_date, 'Mon DD, YYYY') AS end_date_fmt,
           COALESCE(GREATEST(1, (s.end_date - s.start_date + 1)), 14) AS calc_duration_days,
           b.name AS board_name
    INTO v_sprint_row
    FROM public.work_sprints s
    LEFT JOIN public.work_boards b ON b.id = s.board_id
    WHERE s.id = v_sprint_id AND s.school_id = p_school_id;

    IF v_sprint_row.calc_duration_days IS NOT NULL THEN
        v_sprint_days := v_sprint_row.calc_duration_days;
        v_working_days := GREATEST(1, ROUND(v_sprint_days * 5.0 / 7.0)::INT);
    END IF;

    -- Resolve selected team ID if specific team requested
    IF NOT v_is_all_teams THEN
        SELECT id, name INTO v_team_id, v_team_name
        FROM public.work_teams
        WHERE school_id = p_school_id
          AND (id::text = v_team_name OR name ILIKE v_team_name)
          AND COALESCE(status, 'ACTIVE') NOT IN ('ARCHIVED', 'DELETED')
          AND COALESCE(is_active, TRUE) = TRUE
        LIMIT 1;
    END IF;

    -- 2. Fetch Teams List from work_teams table
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', t.id,
            'name', t.name,
            'department', t.department,
            'icon', t.icon,
            'status', UPPER(COALESCE(t.status, 'ACTIVE')),
            'is_active', COALESCE(t.is_active, TRUE),
            'member_count', (SELECT COUNT(*) FROM public.work_team_members wtm WHERE wtm.team_id = t.id),
            'is_selected', (v_team_id IS NOT NULL AND t.id = v_team_id) OR (v_is_all_teams AND t.name = v_team_name)
        ) ORDER BY t.name ASC
    ) INTO v_teams_list
    FROM public.work_teams t
    WHERE t.school_id = p_school_id 
      AND COALESCE(t.status, 'ACTIVE') NOT IN ('ARCHIVED', 'DELETED')
      AND COALESCE(t.is_active, TRUE) = TRUE;

    IF v_teams_list IS NULL THEN
        v_teams_list := '[]'::jsonb;
    END IF;

    -- Fetch Sprints List for Quick Sprint Filter Dropdown
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', s.id,
            'name', s.name,
            'status', s.status,
            'start_date', to_char(s.start_date, 'Mon DD, YYYY'),
            'end_date', to_char(s.end_date, 'Mon DD, YYYY'),
            'duration_days', COALESCE(GREATEST(1, (s.end_date - s.start_date + 1)), 14),
            'is_selected', (s.id = v_sprint_id)
        ) ORDER BY s.start_date DESC
    ) INTO v_all_sprints_list
    FROM public.work_sprints s
    WHERE s.school_id = p_school_id;

    IF v_all_sprints_list IS NULL THEN
        v_all_sprints_list := '[]'::jsonb;
    END IF;

    -- Fetch Roles
    SELECT jsonb_agg(
        jsonb_build_object('id', r.id, 'role_name', COALESCE(r.display_name, r.name))
        ORDER BY COALESCE(r.display_name, r.name) ASC
    ) INTO v_available_roles
    FROM public.app_roles r
    WHERE LOWER(r.status) = 'active';

    IF v_available_roles IS NULL THEN
        v_available_roles := '[]'::jsonb;
    END IF;

    -- 3. Dynamic Member Workload & Capacity Aggregation CTE
    WITH base_members AS (
        SELECT DISTINCT ON (wtm.user_id, CASE WHEN v_is_all_teams THEN NULL ELSE wtm.team_id END)
            wtm.user_id,
            wtm.team_id,
            t.name AS team_name,
            p.full_name,
            p.email,
            p.avatar_url,
            COALESCE(p.department, t.department, 'Academics') AS department,
            COALESCE(smc.role, wtm.role, 'Member') AS member_role,
            COALESCE(smc.daily_working_hours, wtm.daily_hours, 8.0) AS daily_hours,
            COALESCE(smc.working_days, v_working_days) AS working_days,
            COALESCE(smc.days_off, 0.0) AS days_off,
            COALESCE(
                smc.override_value,
                smc.available_hours,
                GREATEST(0.0, (COALESCE(smc.working_days, v_working_days) - COALESCE(smc.days_off, 0.0)) * COALESCE(smc.daily_working_hours, wtm.daily_hours, 8.0)),
                wtm.capacity_hours,
                80.0
            ) AS capacity_hours,
            smc.override_value,
            smc.override_reason,
            smc.notes,
            -- Live work item metrics for this sprint & user
            COALESCE((
                SELECT COUNT(DISTINCT wi.id)
                FROM public.work_items wi
                JOIN public.work_item_assignees wia ON wia.work_item_id = wi.id
                WHERE wi.sprint_id = v_sprint_id
                  AND wia.user_id = wtm.user_id
                  AND COALESCE(wi.is_archived, FALSE) = FALSE
            ), 0) AS work_items_count,
            COALESCE((
                SELECT SUM(COALESCE(wi.estimated_hours, 0.0))
                FROM public.work_items wi
                JOIN public.work_item_assignees wia ON wia.work_item_id = wi.id
                WHERE wi.sprint_id = v_sprint_id
                  AND wia.user_id = wtm.user_id
                  AND COALESCE(wi.is_archived, FALSE) = FALSE
            ), 0.0) AS planned_hours,
            COALESCE((
                SELECT SUM(COALESCE(wi.actual_hours, 0.0))
                FROM public.work_items wi
                JOIN public.work_item_assignees wia ON wia.work_item_id = wi.id
                WHERE wi.sprint_id = v_sprint_id
                  AND wia.user_id = wtm.user_id
                  AND COALESCE(wi.is_archived, FALSE) = FALSE
            ), 0.0) AS actual_hours
        FROM public.work_team_members wtm
        JOIN public.work_teams t ON t.id = wtm.team_id
        JOIN public.profiles p ON p.id = wtm.user_id
        LEFT JOIN public.sprint_member_capacities smc
               ON smc.sprint_id = v_sprint_id
              AND (smc.team_id = wtm.team_id OR smc.team_id IS NULL)
              AND smc.user_id = wtm.user_id
        WHERE t.school_id = p_school_id
          AND COALESCE(t.status, 'ACTIVE') NOT IN ('ARCHIVED', 'DELETED')
          AND COALESCE(t.is_active, TRUE) = TRUE
          AND (v_is_all_teams OR (v_team_id IS NOT NULL AND wtm.team_id = v_team_id) OR t.name = v_team_name)
    ),
    computed_members AS (
        SELECT
            bm.*,
            GREATEST(0.0, bm.capacity_hours - bm.planned_hours) AS remaining_hours,
            CASE
                WHEN bm.capacity_hours > 0 THEN ROUND((bm.planned_hours / bm.capacity_hours) * 100.0, 1)
                ELSE 0.0
            END AS utilization_pct,
            CASE
                WHEN bm.capacity_hours <= 0 THEN 'Balanced'
                WHEN bm.planned_hours > bm.capacity_hours THEN 'Overloaded'
                WHEN bm.planned_hours >= (bm.capacity_hours * 0.8) THEN 'Balanced'
                WHEN bm.planned_hours > 0 THEN 'Underallocated'
                ELSE 'Available'
            END AS workload_status
        FROM base_members bm
    )
    SELECT
        COUNT(*),
        COALESCE(SUM(capacity_hours), 0.0),
        COALESCE(SUM(planned_hours), 0.0),
        COALESCE(SUM(actual_hours), 0.0),
        COUNT(*) FILTER (WHERE workload_status = 'Overloaded')
    INTO
        v_team_members_count,
        v_total_capacity,
        v_planned_work,
        v_actual_work,
        v_overloaded_count
    FROM computed_members;

    v_remaining_capacity := GREATEST(0.0, v_total_capacity - v_planned_work);

    IF v_total_capacity > 0 THEN
        v_utilization_pct := ROUND((v_planned_work / v_total_capacity) * 100.0, 1);
        v_over_allocation := GREATEST(v_planned_work - v_total_capacity, 0.0);
    ELSE
        v_utilization_pct := 0.0;
        v_over_allocation := 0.0;
    END IF;

    -- 4. Count Filtered Members for Pagination
    WITH base_members AS (
        SELECT DISTINCT ON (wtm.user_id, CASE WHEN v_is_all_teams THEN NULL ELSE wtm.team_id END)
            wtm.user_id,
            p.full_name,
            COALESCE(smc.role, wtm.role, 'Member') AS member_role,
            COALESCE(
                smc.override_value,
                smc.available_hours,
                GREATEST(0.0, (COALESCE(smc.working_days, v_working_days) - COALESCE(smc.days_off, 0.0)) * COALESCE(smc.daily_working_hours, wtm.daily_hours, 8.0)),
                wtm.capacity_hours,
                80.0
            ) AS capacity_hours,
            COALESCE((
                SELECT SUM(COALESCE(wi.estimated_hours, 0.0))
                FROM public.work_items wi
                JOIN public.work_item_assignees wia ON wia.work_item_id = wi.id
                WHERE wi.sprint_id = v_sprint_id
                  AND wia.user_id = wtm.user_id
                  AND COALESCE(wi.is_archived, FALSE) = FALSE
            ), 0.0) AS planned_hours
        FROM public.work_team_members wtm
        JOIN public.work_teams t ON t.id = wtm.team_id
        JOIN public.profiles p ON p.id = wtm.user_id
        LEFT JOIN public.sprint_member_capacities smc
               ON smc.sprint_id = v_sprint_id
              AND (smc.team_id = wtm.team_id OR smc.team_id IS NULL)
              AND smc.user_id = wtm.user_id
        WHERE t.school_id = p_school_id
          AND COALESCE(t.status, 'ACTIVE') NOT IN ('ARCHIVED', 'DELETED')
          AND COALESCE(t.is_active, TRUE) = TRUE
          AND (v_is_all_teams OR (v_team_id IS NOT NULL AND wtm.team_id = v_team_id) OR t.name = v_team_name)
    ),
    computed_members AS (
        SELECT
            bm.*,
            CASE
                WHEN bm.capacity_hours <= 0 THEN 'Balanced'
                WHEN bm.planned_hours > bm.capacity_hours THEN 'Overloaded'
                WHEN bm.planned_hours >= (bm.capacity_hours * 0.8) THEN 'Balanced'
                WHEN bm.planned_hours > 0 THEN 'Underallocated'
                ELSE 'Available'
            END AS workload_status
        FROM base_members bm
    )
    SELECT COUNT(*) INTO v_total_filtered_count
    FROM computed_members c
    WHERE (p_search IS NULL OR p_search = '' OR c.full_name ILIKE '%' || p_search || '%' OR c.member_role ILIKE '%' || p_search || '%')
      AND (p_role_filter IS NULL OR p_role_filter = 'All' OR c.member_role ILIKE '%' || p_role_filter || '%')
      AND (p_status_filter IS NULL OR p_status_filter = 'All' OR c.workload_status ILIKE p_status_filter);

    IF v_limit IS NOT NULL AND v_limit > 0 THEN
        v_total_pages := GREATEST(1, CEIL(v_total_filtered_count::NUMERIC / v_limit::NUMERIC)::INT);
        v_offset := (v_page - 1) * v_limit;
    ELSE
        v_limit := 500;
        v_offset := 0;
        v_total_pages := 1;
    END IF;

    -- 5. Paginated & Sorted Members List
    WITH base_members AS (
        SELECT DISTINCT ON (wtm.user_id, CASE WHEN v_is_all_teams THEN NULL ELSE wtm.team_id END)
            wtm.id AS member_id,
            wtm.user_id,
            wtm.team_id,
            t.name AS team_name,
            p.full_name,
            p.email,
            p.avatar_url,
            COALESCE(p.department, t.department, 'Academics') AS department,
            COALESCE(smc.role, wtm.role, 'Member') AS member_role,
            COALESCE(smc.daily_working_hours, wtm.daily_hours, 8.0) AS daily_hours,
            COALESCE(smc.working_days, v_working_days) AS working_days,
            COALESCE(smc.days_off, 0.0) AS days_off,
            COALESCE(
                smc.override_value,
                smc.available_hours,
                GREATEST(0.0, (COALESCE(smc.working_days, v_working_days) - COALESCE(smc.days_off, 0.0)) * COALESCE(smc.daily_working_hours, wtm.daily_hours, 8.0)),
                wtm.capacity_hours,
                80.0
            ) AS capacity_hours,
            smc.override_value,
            smc.override_reason,
            smc.notes,
            COALESCE((
                SELECT COUNT(DISTINCT wi.id)
                FROM public.work_items wi
                JOIN public.work_item_assignees wia ON wia.work_item_id = wi.id
                WHERE wi.sprint_id = v_sprint_id
                  AND wia.user_id = wtm.user_id
                  AND COALESCE(wi.is_archived, FALSE) = FALSE
            ), 0) AS work_items_count,
            COALESCE((
                SELECT SUM(COALESCE(wi.estimated_hours, 0.0))
                FROM public.work_items wi
                JOIN public.work_item_assignees wia ON wia.work_item_id = wi.id
                WHERE wi.sprint_id = v_sprint_id
                  AND wia.user_id = wtm.user_id
                  AND COALESCE(wi.is_archived, FALSE) = FALSE
            ), 0.0) AS planned_hours,
            COALESCE((
                SELECT SUM(COALESCE(wi.actual_hours, 0.0))
                FROM public.work_items wi
                JOIN public.work_item_assignees wia ON wia.work_item_id = wi.id
                WHERE wi.sprint_id = v_sprint_id
                  AND wia.user_id = wtm.user_id
                  AND COALESCE(wi.is_archived, FALSE) = FALSE
            ), 0.0) AS actual_hours
        FROM public.work_team_members wtm
        JOIN public.work_teams t ON t.id = wtm.team_id
        JOIN public.profiles p ON p.id = wtm.user_id
        LEFT JOIN public.sprint_member_capacities smc
               ON smc.sprint_id = v_sprint_id
              AND (smc.team_id = wtm.team_id OR smc.team_id IS NULL)
              AND smc.user_id = wtm.user_id
        WHERE t.school_id = p_school_id
          AND COALESCE(t.status, 'ACTIVE') NOT IN ('ARCHIVED', 'DELETED')
          AND COALESCE(t.is_active, TRUE) = TRUE
          AND (v_is_all_teams OR (v_team_id IS NOT NULL AND wtm.team_id = v_team_id) OR t.name = v_team_name)
    ),
    computed_members AS (
        SELECT
            bm.*,
            GREATEST(0.0, bm.capacity_hours - bm.planned_hours) AS remaining_hours,
            CASE
                WHEN bm.capacity_hours > 0 THEN ROUND((bm.planned_hours / bm.capacity_hours) * 100.0, 1)
                ELSE 0.0
            END AS utilization_pct,
            CASE
                WHEN bm.capacity_hours <= 0 THEN 'Balanced'
                WHEN bm.planned_hours > bm.capacity_hours THEN 'Overloaded'
                WHEN bm.planned_hours >= (bm.capacity_hours * 0.8) THEN 'Balanced'
                WHEN bm.planned_hours > 0 THEN 'Underallocated'
                ELSE 'Available'
            END AS workload_status
        FROM base_members bm
    )
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', sub.member_id,
            'user_id', sub.user_id,
            'full_name', sub.full_name,
            'email', sub.email,
            'avatar_url', sub.avatar_url,
            'department', sub.department,
            'team_id', sub.team_id,
            'team_name', sub.team_name,
            'role', sub.member_role,
            'daily_working_hours', sub.daily_hours,
            'working_days', sub.working_days,
            'days_off', sub.days_off,
            'capacity_hours', sub.capacity_hours,
            'planned_hours', sub.planned_hours,
            'actual_hours', sub.actual_hours,
            'remaining_hours', sub.remaining_hours,
            'utilization_pct', sub.utilization_pct,
            'work_items_count', sub.work_items_count,
            'workload_status', sub.workload_status,
            'override_value', sub.override_value,
            'override_reason', sub.override_reason,
            'notes', sub.notes
        )
    ), '[]'::jsonb) INTO v_members_list
    FROM (
        SELECT * FROM computed_members c
        WHERE (p_search IS NULL OR p_search = '' OR c.full_name ILIKE '%' || p_search || '%' OR c.member_role ILIKE '%' || p_search || '%')
          AND (p_role_filter IS NULL OR p_role_filter = 'All' OR c.member_role ILIKE '%' || p_role_filter || '%')
          AND (p_status_filter IS NULL OR p_status_filter = 'All' OR c.workload_status ILIKE p_status_filter)
        ORDER BY
            CASE WHEN LOWER(p_sort_by) = 'name' AND LOWER(p_sort_order) = 'desc' THEN c.full_name END DESC,
            CASE WHEN LOWER(p_sort_by) = 'name' AND LOWER(p_sort_order) != 'desc' THEN c.full_name END ASC,
            CASE WHEN LOWER(p_sort_by) = 'role' AND LOWER(p_sort_order) = 'desc' THEN c.member_role END DESC,
            CASE WHEN LOWER(p_sort_by) = 'role' AND LOWER(p_sort_order) != 'desc' THEN c.member_role END ASC,
            CASE WHEN LOWER(p_sort_by) = 'capacity' AND LOWER(p_sort_order) = 'desc' THEN c.capacity_hours END DESC,
            CASE WHEN LOWER(p_sort_by) = 'capacity' AND LOWER(p_sort_order) != 'desc' THEN c.capacity_hours END ASC,
            CASE WHEN LOWER(p_sort_by) = 'planned' AND LOWER(p_sort_order) = 'desc' THEN c.planned_hours END DESC,
            CASE WHEN LOWER(p_sort_by) = 'planned' AND LOWER(p_sort_order) != 'desc' THEN c.planned_hours END ASC,
            CASE WHEN LOWER(p_sort_by) = 'actual' AND LOWER(p_sort_order) = 'desc' THEN c.actual_hours END DESC,
            CASE WHEN LOWER(p_sort_by) = 'actual' AND LOWER(p_sort_order) != 'desc' THEN c.actual_hours END ASC,
            CASE WHEN LOWER(p_sort_by) = 'remaining' AND LOWER(p_sort_order) = 'desc' THEN c.remaining_hours END DESC,
            CASE WHEN LOWER(p_sort_by) = 'remaining' AND LOWER(p_sort_order) != 'desc' THEN c.remaining_hours END ASC,
            CASE WHEN LOWER(p_sort_by) = 'utilization' AND LOWER(p_sort_order) = 'desc' THEN c.utilization_pct END DESC,
            CASE WHEN LOWER(p_sort_by) = 'utilization' AND LOWER(p_sort_order) != 'desc' THEN c.utilization_pct END ASC,
            CASE WHEN LOWER(p_sort_by) = 'work_items' AND LOWER(p_sort_order) = 'desc' THEN c.work_items_count END DESC,
            CASE WHEN LOWER(p_sort_by) = 'work_items' AND LOWER(p_sort_order) != 'desc' THEN c.work_items_count END ASC,
            CASE WHEN LOWER(p_sort_by) = 'status' AND LOWER(p_sort_order) = 'desc' THEN c.workload_status END DESC,
            CASE WHEN LOWER(p_sort_by) = 'status' AND LOWER(p_sort_order) != 'desc' THEN c.workload_status END ASC,
            c.full_name ASC, c.user_id ASC
        LIMIT v_limit OFFSET v_offset
    ) sub;

    IF v_members_list IS NULL THEN
        v_members_list := '[]'::jsonb;
    END IF;

    -- 6. Dynamic Sprint Burndown
    v_daily_cap := ROUND(v_total_capacity / GREATEST(1, v_working_days), 1);
    v_burndown_chart := '[]'::jsonb;

    FOR v_day_idx IN 1..v_sprint_days LOOP
        v_curr_date := (v_sprint_row.start_date + (v_day_idx - 1) * INTERVAL '1 day')::DATE;
        v_date_fmt := to_char(v_curr_date, 'Mon DD');
        v_ideal_remain := ROUND(GREATEST(0.0, v_planned_work * (1.0 - ((v_day_idx - 1)::NUMERIC / GREATEST(1, v_sprint_days - 1)))), 1);

        IF v_day_idx <= GREATEST(1, (CURRENT_DATE - v_sprint_row.start_date + 1)) THEN
            v_cum_completed := ROUND(LEAST(v_actual_work, (v_actual_work / GREATEST(1, (CURRENT_DATE - v_sprint_row.start_date + 1))) * v_day_idx), 1);
            v_actual_remain := ROUND(GREATEST(0.0, v_planned_work - v_cum_completed), 1);
        ELSE
            v_cum_completed := v_actual_work;
            v_actual_remain := v_remaining_capacity;
        END IF;

        v_burndown_chart := v_burndown_chart || jsonb_build_array(
            jsonb_build_object(
                'day_index', v_day_idx,
                'date_fmt', v_date_fmt,
                'full_date', to_char(v_curr_date, 'YYYY-MM-DD'),
                'capacity_hours', v_daily_cap,
                'ideal_remaining', v_ideal_remain,
                'remaining_hours', v_actual_remain,
                'completed_hours', v_cum_completed,
                'planned_hours', ROUND(v_planned_work / GREATEST(1, v_working_days), 1),
                'actual_hours', ROUND(v_actual_work / GREATEST(1, v_sprint_days), 1)
            )
        );
    END LOOP;

    v_daily_chart := v_burndown_chart;

    -- 7. Construct Smart Recommendation Insights
    v_insights := jsonb_build_array(
        jsonb_build_object(
            'type', 'SUCCESS',
            'icon', 'check_circle',
            'text', 'Team is operating at ' || COALESCE(v_utilization_pct, 0.0)::TEXT || '% planned utilization.'
        ),
        jsonb_build_object(
            'type', CASE WHEN v_overloaded_count > 0 THEN 'WARNING' ELSE 'INFO' END,
            'icon', CASE WHEN v_overloaded_count > 0 THEN 'warning' ELSE 'info' END,
            'text', COALESCE(v_overloaded_count, 0)::TEXT || ' member(s) currently over-allocated for this sprint.'
        ),
        jsonb_build_object(
            'type', 'INFO',
            'icon', 'info',
            'text', COALESCE(v_sprint_row.name, 'Sprint') || ' (' || v_sprint_days::TEXT || ' days) with ' || v_team_members_count::TEXT || ' team member(s).'
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'sprint_id', v_sprint_id,
        'sprint_name', COALESCE(v_sprint_row.name, 'Sprint 103'),
        'sprint_duration', COALESCE(v_sprint_row.start_date_fmt || ' - ' || v_sprint_row.end_date_fmt, 'Nov 15, 2026 - Nov 28, 2026'),
        'sprint_days', v_sprint_days,
        'working_days', v_working_days,
        'board_name', COALESCE(v_sprint_row.board_name, 'Institute Work Board'),
        'selected_team', v_team_name,
        'selected_team_id', v_team_id,
        'pagination', jsonb_build_object(
            'page', v_page,
            'limit', v_limit,
            'total_count', v_total_filtered_count,
            'total_pages', v_total_pages,
            'has_next_page', (v_page < v_total_pages),
            'has_prev_page', (v_page > 1)
        ),
        'kpis', jsonb_build_object(
            'team_members', v_team_members_count,
            'team_members_count', v_team_members_count,
            'total_capacity_hours', v_total_capacity,
            'planned_work_hours', v_planned_work,
            'actual_work_hours', v_actual_work,
            'remaining_capacity_hours', v_remaining_capacity,
            'utilization_pct', v_utilization_pct,
            'over_allocation_hours', v_over_allocation,
            'overloaded_members_count', v_overloaded_count
        ),
        'teams', v_teams_list,
        'all_sprints', v_all_sprints_list,
        'available_roles', v_available_roles,
        'daily_chart', v_daily_chart,
        'burndown_chart', v_burndown_chart,
        'members', v_members_list,
        'insights', v_insights
    );
END;

$function$
;

CREATE OR REPLACE FUNCTION public.sp_get_teams_directory(p_school_id uuid, p_sprint_id uuid DEFAULT NULL::uuid, p_status character varying DEFAULT 'ALL'::character varying, p_department character varying DEFAULT 'ALL'::character varying, p_search character varying DEFAULT NULL::character varying, p_sort_by character varying DEFAULT 'NAME_ASC'::character varying, p_limit integer DEFAULT 10, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_sprint UUID := p_sprint_id;
    v_sprint_row RECORD;
    v_sprint_days INT := 14;
    v_working_days INT := 10;
    v_total_teams INT := 0;
    v_total_members INT := 0;
    v_total_capacity NUMERIC(10,2) := 0.0;
    v_total_allocated NUMERIC(10,2) := 0.0;
    v_avg_utilization NUMERIC(5,2) := 0.0;
    v_active_teams INT := 0;
    v_inactive_teams INT := 0;
    v_teams_json JSONB := '[]'::jsonb;
    v_kpis_json JSONB;
    v_total_filtered INT := 0;
BEGIN
    -- Resolve to latest ACTIVE sprint if not specified
    IF v_sprint IS NULL THEN
        SELECT id INTO v_sprint FROM public.work_sprints
        WHERE school_id = p_school_id AND status = 'ACTIVE'
        ORDER BY start_date DESC LIMIT 1;

        IF v_sprint IS NULL THEN
            SELECT id INTO v_sprint FROM public.work_sprints
            WHERE school_id = p_school_id
            ORDER BY start_date DESC LIMIT 1;
        END IF;
    END IF;

    -- Fetch Sprint Details
    SELECT s.*,
           COALESCE(GREATEST(1, (s.end_date - s.start_date + 1)), 14) AS calc_duration_days
    INTO v_sprint_row
    FROM public.work_sprints s
    WHERE s.id = v_sprint;

    IF v_sprint_row.calc_duration_days IS NOT NULL THEN
        v_sprint_days := v_sprint_row.calc_duration_days;
        v_working_days := GREATEST(1, ROUND(v_sprint_days * 5.0 / 7.0)::INT);
    END IF;

    -- Aggregate Global KPIs for non-archived teams
    SELECT
        COUNT(t.id),
        COALESCE(COUNT(t.id) FILTER (WHERE t.is_active = TRUE AND t.status = 'ACTIVE'), 0),
        COALESCE(COUNT(t.id) FILTER (WHERE t.is_active = FALSE OR t.status != 'ACTIVE'), 0)
    INTO v_total_teams, v_active_teams, v_inactive_teams
    FROM public.work_teams t
    WHERE t.school_id = p_school_id AND t.status != 'ARCHIVED';

    SELECT COUNT(wtm.id) INTO v_total_members
    FROM public.work_team_members wtm
    JOIN public.work_teams t ON t.id = wtm.team_id
    WHERE t.school_id = p_school_id AND t.status != 'ARCHIVED';

    -- Dynamic Capacity calculation per team for v_sprint
    WITH team_calc AS (
        SELECT
            t.id AS team_id,
            COALESCE(SUM(
                COALESCE(
                    smc.override_value,
                    smc.available_hours,
                    GREATEST(0.0, (COALESCE(smc.working_days, v_working_days) - COALESCE(smc.days_off, 0.0)) * COALESCE(smc.daily_working_hours, wtm.daily_hours, 8.0)),
                    wtm.capacity_hours,
                    80.0
                )
            ), t.default_capacity_hours, 0.0) AS team_cap,
            COALESCE((
                SELECT SUM(COALESCE(wi.estimated_hours, 0.0))
                FROM public.work_items wi
                JOIN public.work_item_assignees wia ON wia.work_item_id = wi.id
                JOIN public.work_team_members wtm2 ON wtm2.user_id = wia.user_id AND wtm2.team_id = t.id
                WHERE wi.sprint_id = v_sprint
                  AND COALESCE(wi.is_archived, FALSE) = FALSE
            ), 0.0) AS team_plan
        FROM public.work_teams t
        LEFT JOIN public.work_team_members wtm ON wtm.team_id = t.id
        LEFT JOIN public.sprint_member_capacities smc
               ON smc.sprint_id = v_sprint
              AND (smc.team_id = t.id OR smc.team_id IS NULL)
              AND smc.user_id = wtm.user_id
        WHERE t.school_id = p_school_id AND t.is_active = TRUE AND t.status = 'ACTIVE'
        GROUP BY t.id, t.default_capacity_hours
    )
    SELECT
        COALESCE(SUM(team_cap), 0.0),
        COALESCE(SUM(team_plan), 0.0)
    INTO v_total_capacity, v_total_allocated
    FROM team_calc;

    IF v_total_capacity > 0 THEN
        v_avg_utilization := ROUND((v_total_allocated / v_total_capacity) * 100.0, 1);
    ELSE
        v_avg_utilization := 0.0;
    END IF;

    v_kpis_json := jsonb_build_object(
        'total_teams', v_total_teams,
        'total_members', v_total_members,
        'total_capacity_hours', v_total_capacity,
        'allocated_work_hours', v_total_allocated,
        'capacity_utilization_pct', v_avg_utilization,
        'active_teams', v_active_teams,
        'inactive_teams', v_inactive_teams
    );

    -- Count total filtered teams for pagination
    SELECT COUNT(*) INTO v_total_filtered
    FROM public.work_teams t
    LEFT JOIN public.profiles p ON p.id = t.lead_id
    WHERE t.school_id = p_school_id
      AND t.status != 'ARCHIVED'
      AND (p_status IS NULL OR p_status = 'ALL' OR (p_status = 'ACTIVE' AND t.is_active = TRUE AND t.status = 'ACTIVE') OR (p_status = 'INACTIVE' AND (t.is_active = FALSE OR t.status = 'INACTIVE')))
      AND (p_department IS NULL OR p_department = 'ALL' OR t.department ILIKE '%' || p_department || '%')
      AND (p_search IS NULL OR p_search = '' OR (
          t.name ILIKE '%' || p_search || '%' OR
          t.team_key ILIKE '%' || p_search || '%' OR
          t.department ILIKE '%' || p_search || '%' OR
          p.full_name ILIKE '%' || p_search || '%' OR
          p.email ILIKE '%' || p_search || '%'
      ));

    -- Build Filtered & Sorted Teams List with dynamic capacity matching Capacity Screen
    WITH filtered_teams AS (
        SELECT
            t.id,
            t.name,
            t.team_key,
            t.department,
            t.description,
            t.icon,
            t.color,
            t.is_active,
            t.status,
            t.tags,
            t.goal,
            t.created_at,
            t.updated_at,
            p.id AS lead_id,
            p.full_name AS lead_name,
            p.email AS lead_email,
            p.avatar_url AS lead_avatar,
            COALESCE(SUM(
                COALESCE(
                    smc.override_value,
                    smc.available_hours,
                    GREATEST(0.0, (COALESCE(smc.working_days, v_working_days) - COALESCE(smc.days_off, 0.0)) * COALESCE(smc.daily_working_hours, wtm.daily_hours, 8.0)),
                    wtm.capacity_hours,
                    80.0
                )
            ), t.default_capacity_hours, 0.0) AS capacity_hours,
            COALESCE((
                SELECT SUM(COALESCE(wi.estimated_hours, 0.0))
                FROM public.work_items wi
                JOIN public.work_item_assignees wia ON wia.work_item_id = wi.id
                JOIN public.work_team_members wtm2 ON wtm2.user_id = wia.user_id AND wtm2.team_id = t.id
                WHERE wi.sprint_id = v_sprint
                  AND COALESCE(wi.is_archived, FALSE) = FALSE
            ), 0.0) AS planned_hours,
            COUNT(wtm.id) AS member_count,
            (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'id', mem_p.id,
                        'name', mem_p.full_name,
                        'email', mem_p.email,
                        'avatar_url', mem_p.avatar_url,
                        'role', COALESCE(mem_m.role, mem_p.role, 'Member'),
                        'is_lead', COALESCE(mem_m.is_lead, FALSE)
                    ) ORDER BY mem_m.is_lead DESC, mem_p.full_name ASC
                )
                FROM public.work_team_members mem_m
                JOIN public.profiles mem_p ON mem_p.id = mem_m.user_id
                WHERE mem_m.team_id = t.id
            ) AS members_json
        FROM public.work_teams t
        LEFT JOIN public.profiles p ON p.id = t.lead_id
        LEFT JOIN public.work_team_members wtm ON wtm.team_id = t.id
        LEFT JOIN public.sprint_member_capacities smc
               ON smc.sprint_id = v_sprint
              AND (smc.team_id = t.id OR smc.team_id IS NULL)
              AND smc.user_id = wtm.user_id
        WHERE t.school_id = p_school_id
          AND t.status != 'ARCHIVED'
          AND (p_status IS NULL OR p_status = 'ALL' OR (p_status = 'ACTIVE' AND t.is_active = TRUE AND t.status = 'ACTIVE') OR (p_status = 'INACTIVE' AND (t.is_active = FALSE OR t.status = 'INACTIVE')))
          AND (p_department IS NULL OR p_department = 'ALL' OR t.department ILIKE '%' || p_department || '%')
          AND (p_search IS NULL OR p_search = '' OR (
              t.name ILIKE '%' || p_search || '%' OR
              t.team_key ILIKE '%' || p_search || '%' OR
              t.department ILIKE '%' || p_search || '%' OR
              p.full_name ILIKE '%' || p_search || '%' OR
              p.email ILIKE '%' || p_search || '%'
          ))
        GROUP BY t.id, p.id, p.full_name, p.email, p.avatar_url
        ORDER BY
            CASE WHEN p_sort_by = 'NAME_ASC' THEN LOWER(t.name) END ASC,
            CASE WHEN p_sort_by = 'NAME_DESC' THEN LOWER(t.name) END DESC,
            CASE WHEN p_sort_by = 'CODE_ASC' THEN LOWER(COALESCE(t.team_key, '')) END ASC,
            CASE WHEN p_sort_by = 'CODE_DESC' THEN LOWER(COALESCE(t.team_key, '')) END DESC,
            CASE WHEN p_sort_by = 'DEPT_ASC' THEN LOWER(COALESCE(t.department, '')) END ASC,
            CASE WHEN p_sort_by = 'DEPT_DESC' THEN LOWER(COALESCE(t.department, '')) END DESC,
            CASE WHEN p_sort_by = 'MEMBERS_ASC' THEN COUNT(wtm.id) END ASC,
            CASE WHEN p_sort_by = 'MEMBERS_DESC' THEN COUNT(wtm.id) END DESC,
            CASE WHEN p_sort_by = 'STATUS_ASC' THEN LOWER(COALESCE(t.status, 'ACTIVE')) END ASC,
            CASE WHEN p_sort_by = 'STATUS_DESC' THEN LOWER(COALESCE(t.status, 'ACTIVE')) END DESC,
            CASE WHEN p_sort_by = 'CREATED_DESC' THEN t.created_at END DESC,
            t.created_at DESC, t.id ASC
        LIMIT p_limit OFFSET p_offset
    )
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', ft.id,
            'name', ft.name,
            'team_key', ft.team_key,
            'department', ft.department,
            'description', ft.description,
            'icon', ft.icon,
            'color', ft.color,
            'is_active', ft.is_active,
            'status', ft.status,
            'tags', COALESCE(ft.tags, ARRAY[]::TEXT[]),
            'goal', COALESCE(ft.goal, ''),
            'created_at', ft.created_at,
            'updated_at', ft.updated_at,
            'lead', jsonb_build_object(
                'id', ft.lead_id,
                'name', COALESCE(ft.lead_name, 'Unassigned'),
                'email', ft.lead_email,
                'avatar_url', ft.lead_avatar
            ),
            'member_count', ft.member_count,
            'members', COALESCE(ft.members_json, '[]'::jsonb),
            'capacity_hours', ft.capacity_hours,
            'planned_hours', ft.planned_hours,
            'remaining_hours', GREATEST(0.0, ft.capacity_hours - ft.planned_hours),
            'utilization_pct', CASE WHEN ft.capacity_hours > 0 THEN ROUND((ft.planned_hours / ft.capacity_hours) * 100.0, 1) ELSE 0.0 END
        )
    ), '[]'::jsonb) INTO v_teams_json
    FROM filtered_teams ft;

    RETURN jsonb_build_object(
        'success', TRUE,
        'sprint_id', v_sprint,
        'sprint_name', v_sprint_row.name,
        'kpis', v_kpis_json,
        'total_count', v_total_filtered,
        'teams', v_teams_json
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.sp_list_work_items_paged(p_school_id uuid, p_board_id uuid DEFAULT NULL::uuid, p_sprint_id uuid DEFAULT NULL::uuid, p_type character varying DEFAULT 'All'::character varying, p_status character varying DEFAULT 'All'::character varying, p_assignee_id uuid DEFAULT NULL::uuid, p_priority character varying DEFAULT 'All'::character varying, p_search character varying DEFAULT NULL::character varying, p_sort_col character varying DEFAULT 'created_at'::character varying, p_sort_dir character varying DEFAULT 'DESC'::character varying, p_page integer DEFAULT 1, p_page_size integer DEFAULT 100)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_total_count INT := 0;
    v_offset INT := 0;
    v_items JSONB := '[]'::jsonb;
    v_kpis JSONB := '{}'::jsonb;
    v_clean_type VARCHAR := NULLIF(TRIM(p_type), '');
    v_clean_status VARCHAR := NULLIF(TRIM(p_status), '');
    v_clean_priority VARCHAR := NULLIF(TRIM(p_priority), '');
    v_clean_search VARCHAR := NULLIF(TRIM(p_search), '');
BEGIN
    v_offset := GREATEST(0, (COALESCE(p_page, 1) - 1) * COALESCE(p_page_size, 100));

    -- Total count & KPI counts with full status normalization
    SELECT
        COUNT(*),
        jsonb_build_object(
            'total', COUNT(*),
            'new', COUNT(*) FILTER (WHERE UPPER(w.status) IN ('NEW', 'OPEN', 'PLANNED', 'NOT STARTED', 'NOT_STARTED', 'TODO')),
            'active', COUNT(*) FILTER (WHERE UPPER(w.status) IN ('ACTIVE', 'IN_PROGRESS', 'IN PROGRESS', 'DOING', 'CRITICAL')),
            'resolved', COUNT(*) FILTER (WHERE UPPER(w.status) IN ('RESOLVED', 'TESTING', 'QA', 'CODE REVIEW')),
            'completed', COUNT(*) FILTER (WHERE UPPER(w.status) IN ('COMPLETED', 'CLOSED', 'DONE')),
            'overdue', COUNT(*) FILTER (WHERE w.due_date IS NOT NULL AND w.due_date < CURRENT_DATE AND UPPER(w.status) NOT IN ('COMPLETED', 'RESOLVED', 'CLOSED', 'DONE'))
        )
    INTO v_total_count, v_kpis
    FROM public.work_items w
    WHERE w.school_id = p_school_id
      AND w.is_archived = FALSE
      AND (p_board_id IS NULL OR w.board_id = p_board_id)
      AND (p_sprint_id IS NULL OR w.sprint_id = p_sprint_id)
      AND (v_clean_type IS NULL OR LOWER(v_clean_type) = 'all' OR UPPER(w.work_type) = UPPER(v_clean_type))
      AND (
          v_clean_status IS NULL OR LOWER(v_clean_status) = 'all'
          OR (UPPER(v_clean_status) = 'NEW' AND UPPER(w.status) IN ('NEW', 'OPEN', 'PLANNED', 'NOT STARTED', 'NOT_STARTED', 'TODO'))
          OR (UPPER(v_clean_status) IN ('ACTIVE', 'IN_PROGRESS', 'IN PROGRESS') AND UPPER(w.status) IN ('ACTIVE', 'IN_PROGRESS', 'IN PROGRESS', 'DOING', 'CRITICAL'))
          OR (UPPER(v_clean_status) = 'RESOLVED' AND UPPER(w.status) IN ('RESOLVED', 'TESTING', 'QA', 'CODE REVIEW'))
          OR (UPPER(v_clean_status) = 'COMPLETED' AND UPPER(w.status) IN ('COMPLETED', 'CLOSED', 'DONE'))
          OR UPPER(w.status) = UPPER(v_clean_status)
      )
      AND (v_clean_priority IS NULL OR LOWER(v_clean_priority) = 'all' OR UPPER(w.priority) = UPPER(v_clean_priority))
      AND (p_assignee_id IS NULL OR EXISTS (
          SELECT 1 FROM public.work_item_assignees a WHERE a.work_item_id = w.id AND a.user_id = p_assignee_id
      ))
      AND (v_clean_search IS NULL OR (w.title ILIKE '%' || v_clean_search || '%' OR w.item_number ILIKE '%' || v_clean_search || '%'));

    -- Fetch Paginated Items with resolved board, team, assignees
    SELECT COALESCE(jsonb_agg(item_obj), '[]'::jsonb) INTO v_items
    FROM (
        SELECT jsonb_build_object(
            'id', w.id,
            'item_number', w.item_number,
            'title', w.title,
            'description', w.description,
            'work_type', w.work_type,
            'status', w.status,
            'priority', w.priority,
            'category', w.category,
            'board_id', w.board_id,
            'board_name', COALESCE(b.name, 'Institute Work Board'),
            'team_id', w.team_id,
            'team_name', COALESCE(w.team_name, wt.name, 'No Team'),
            'sprint_id', w.sprint_id,
            'sprint_name', s.name,
            'parent_id', w.parent_id,
            'parent_number', p.item_number,
            'parent_title', p.title,
            'parent_type', p.work_type,
            'story_points', w.story_points,
            'estimated_hours', w.estimated_hours,
            'actual_hours', w.actual_hours,
            'remaining_hours', w.remaining_hours,
            'progress_percentage', w.progress_percentage,
            'start_date', w.start_date,
            'due_date', w.due_date,
            'is_overdue', (w.due_date IS NOT NULL AND w.due_date < CURRENT_DATE AND UPPER(w.status) NOT IN ('COMPLETED', 'RESOLVED', 'CLOSED', 'DONE')),
            'class_id', w.class_id,
            'section_id', w.section_id,
            'created_at', w.created_at,
            'updated_at', w.updated_at,
            'assignees', COALESCE((
                SELECT jsonb_agg(jsonb_build_object(
                    'user_id', pr.id,
                    'full_name', pr.full_name,
                    'role', pr.role,
                    'avatar_url', pr.avatar_url,
                    'department', pr.department,
                    'role_type', wia.role_type,
                    'class_name', cl.name,
                    'section_name', sec.name,
                    'roll_number', sca.roll_number
                ))
                FROM public.work_item_assignees wia
                JOIN public.profiles pr ON pr.id = wia.user_id
                LEFT JOIN LATERAL (
                    SELECT sca_in.class_id, sca_in.section_id, sca_in.roll_number
                    FROM public.student_class_assignments sca_in
                    WHERE sca_in.student_id = pr.id AND (sca_in.status = 'ACTIVE' OR sca_in.status IS NULL)
                    ORDER BY sca_in.assigned_at DESC NULLS LAST
                    LIMIT 1
                ) sca ON TRUE
                LEFT JOIN public.academic_classes cl ON cl.id = sca.class_id
                LEFT JOIN public.academic_sections sec ON sec.id = sca.section_id
                WHERE wia.work_item_id = w.id
            ), '[]'::jsonb),
            'comments_count', (SELECT COUNT(*) FROM public.work_item_comments c WHERE c.work_item_id = w.id)
        ) AS item_obj
        FROM public.work_items w
        LEFT JOIN public.work_boards b ON b.id = w.board_id
        LEFT JOIN public.work_teams wt ON wt.id = w.team_id
        LEFT JOIN public.work_sprints s ON s.id = w.sprint_id
        LEFT JOIN public.work_items p ON p.id = w.parent_id
        WHERE w.school_id = p_school_id
          AND w.is_archived = FALSE
          AND (p_board_id IS NULL OR w.board_id = p_board_id)
          AND (p_sprint_id IS NULL OR w.sprint_id = p_sprint_id)
          AND (v_clean_type IS NULL OR LOWER(v_clean_type) = 'all' OR UPPER(w.work_type) = UPPER(v_clean_type))
          AND (
              v_clean_status IS NULL OR LOWER(v_clean_status) = 'all'
              OR (UPPER(v_clean_status) = 'NEW' AND UPPER(w.status) IN ('NEW', 'OPEN', 'PLANNED', 'NOT STARTED', 'NOT_STARTED', 'TODO'))
              OR (UPPER(v_clean_status) IN ('ACTIVE', 'IN_PROGRESS', 'IN PROGRESS') AND UPPER(w.status) IN ('ACTIVE', 'IN_PROGRESS', 'IN PROGRESS', 'DOING', 'CRITICAL'))
              OR (UPPER(v_clean_status) = 'RESOLVED' AND UPPER(w.status) IN ('RESOLVED', 'TESTING', 'QA', 'CODE REVIEW'))
              OR (UPPER(v_clean_status) = 'COMPLETED' AND UPPER(w.status) IN ('COMPLETED', 'CLOSED', 'DONE'))
              OR UPPER(w.status) = UPPER(v_clean_status)
          )
          AND (v_clean_priority IS NULL OR LOWER(v_clean_priority) = 'all' OR UPPER(w.priority) = UPPER(v_clean_priority))
          AND (p_assignee_id IS NULL OR EXISTS (
              SELECT 1 FROM public.work_item_assignees a WHERE a.work_item_id = w.id AND a.user_id = p_assignee_id
          ))
          AND (v_clean_search IS NULL OR (w.title ILIKE '%' || v_clean_search || '%' OR w.item_number ILIKE '%' || v_clean_search || '%'))
        ORDER BY
            CASE WHEN LOWER(p_sort_col) = 'title' AND UPPER(p_sort_dir) = 'ASC' THEN w.title END ASC,
            CASE WHEN LOWER(p_sort_col) = 'title' AND UPPER(p_sort_dir) != 'ASC' THEN w.title END DESC,
            CASE WHEN LOWER(p_sort_col) = 'item_number' AND UPPER(p_sort_dir) = 'ASC' THEN w.item_number END ASC,
            CASE WHEN LOWER(p_sort_col) = 'item_number' AND UPPER(p_sort_dir) != 'ASC' THEN w.item_number END DESC,
            CASE WHEN LOWER(p_sort_col) = 'priority' AND UPPER(p_sort_dir) = 'ASC' THEN w.priority END ASC,
            CASE WHEN LOWER(p_sort_col) = 'priority' AND UPPER(p_sort_dir) != 'ASC' THEN w.priority END DESC,
            CASE WHEN LOWER(p_sort_col) IN ('work_type', 'type') AND UPPER(p_sort_dir) = 'ASC' THEN LOWER(COALESCE(w.work_type, '')) END ASC,
            CASE WHEN LOWER(p_sort_col) IN ('work_type', 'type') AND UPPER(p_sort_dir) != 'ASC' THEN LOWER(COALESCE(w.work_type, '')) END DESC,
            CASE WHEN LOWER(p_sort_col) = 'due_date' AND UPPER(p_sort_dir) = 'ASC' THEN w.due_date END ASC NULLS LAST,
            CASE WHEN LOWER(p_sort_col) = 'due_date' AND UPPER(p_sort_dir) != 'ASC' THEN w.due_date END DESC NULLS LAST,
            CASE WHEN LOWER(p_sort_col) = 'progress' AND UPPER(p_sort_dir) = 'ASC' THEN COALESCE(w.progress_percentage, 0) END ASC,
            CASE WHEN LOWER(p_sort_col) = 'progress' AND UPPER(p_sort_dir) != 'ASC' THEN COALESCE(w.progress_percentage, 0) END DESC,
            CASE WHEN LOWER(p_sort_col) = 'status' AND UPPER(p_sort_dir) = 'ASC' THEN w.status END ASC,
            CASE WHEN LOWER(p_sort_col) = 'status' AND UPPER(p_sort_dir) != 'ASC' THEN w.status END DESC,
            CASE WHEN LOWER(p_sort_col) = 'created_at' AND UPPER(p_sort_dir) = 'ASC' THEN w.created_at END ASC,
            w.created_at DESC, w.id ASC
        LIMIT COALESCE(p_page_size, 100)
        OFFSET v_offset
    ) sub;

    RETURN jsonb_build_object(
        'success', TRUE,
        'total', v_total_count,
        'page', COALESCE(p_page, 1),
        'page_size', COALESCE(p_page_size, 100),
        'kpis', v_kpis,
        'items', v_items
    );
END;
$function$

;

DROP FUNCTION IF EXISTS public.fn_list_all_student_payments(uuid, text, integer, integer);
CREATE OR REPLACE FUNCTION public.fn_list_all_student_payments(
    p_school_id uuid,
    p_search text DEFAULT NULL::text,
    p_page integer DEFAULT 1,
    p_page_size integer DEFAULT 15,
    p_sort_by text DEFAULT 'created_at'::text,
    p_sort_order text DEFAULT 'DESC'::text
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_clean_page INT := GREATEST(1, COALESCE(p_page, 1));
    v_clean_size INT := GREATEST(1, LEAST(100, COALESCE(p_page_size, 15)));
    v_offset INT := (v_clean_page - 1) * v_clean_size;
    v_total_items INT := 0;
    v_total_pages INT := 1;
    v_payments JSONB := '[]'::jsonb;
BEGIN
    WITH filtered AS (
        SELECT 
            pay.id, pay.receipt_number, pay.amount_paid, pay.payment_method,
            pay.transaction_reference, pay.payment_date, pay.status, pay.remarks,
            pay.created_at, p.full_name AS student_name, p.roll_number, p.class AS class_name,
            i.invoice_number
        FROM public.student_fee_payments pay
        JOIN public.profiles p ON pay.student_id = p.id
        LEFT JOIN public.student_fee_invoices i ON pay.invoice_id = i.id
        WHERE pay.school_id = p_school_id
          AND (p_search IS NULL OR p_search = '' OR (
              pay.receipt_number ILIKE '%' || p_search || '%' OR
              p.full_name ILIKE '%' || p_search || '%' OR
              pay.transaction_reference ILIKE '%' || p_search || '%' OR
              i.invoice_number ILIKE '%' || p_search || '%'
          ))
    ),
    counted AS (
        SELECT COUNT(*) AS total_items FROM filtered
    ),
    sorted_page AS (
        SELECT * FROM filtered
        ORDER BY
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'receipt_number' AND UPPER(COALESCE(p_sort_order, 'DESC')) = 'ASC' THEN LOWER(COALESCE(receipt_number, '')) END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'receipt_number' AND UPPER(COALESCE(p_sort_order, 'DESC')) <> 'ASC' THEN LOWER(COALESCE(receipt_number, '')) END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'student_name' AND UPPER(COALESCE(p_sort_order, 'DESC')) = 'ASC' THEN LOWER(COALESCE(student_name, '')) END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'student_name' AND UPPER(COALESCE(p_sort_order, 'DESC')) <> 'ASC' THEN LOWER(COALESCE(student_name, '')) END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'payment_date' AND UPPER(COALESCE(p_sort_order, 'DESC')) = 'ASC' THEN payment_date END ASC NULLS LAST,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'payment_date' AND UPPER(COALESCE(p_sort_order, 'DESC')) <> 'ASC' THEN payment_date END DESC NULLS LAST,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'payment_method' AND UPPER(COALESCE(p_sort_order, 'DESC')) = 'ASC' THEN LOWER(COALESCE(payment_method, '')) END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'payment_method' AND UPPER(COALESCE(p_sort_order, 'DESC')) <> 'ASC' THEN LOWER(COALESCE(payment_method, '')) END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'amount_paid' AND UPPER(COALESCE(p_sort_order, 'DESC')) = 'ASC' THEN COALESCE(amount_paid, 0) END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'amount_paid' AND UPPER(COALESCE(p_sort_order, 'DESC')) <> 'ASC' THEN COALESCE(amount_paid, 0) END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'status' AND UPPER(COALESCE(p_sort_order, 'DESC')) = 'ASC' THEN LOWER(COALESCE(status, '')) END ASC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'status' AND UPPER(COALESCE(p_sort_order, 'DESC')) <> 'ASC' THEN LOWER(COALESCE(status, '')) END DESC,
            CASE WHEN LOWER(COALESCE(p_sort_by, 'created_at')) = 'created_at' AND UPPER(COALESCE(p_sort_order, 'DESC')) = 'ASC' THEN created_at END ASC,
            created_at DESC, id ASC
        LIMIT v_clean_size OFFSET v_offset
    )
    SELECT 
        (SELECT total_items FROM counted),
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', sp.id,
                    'receipt_number', sp.receipt_number,
                    'amount_paid', sp.amount_paid,
                    'payment_method', sp.payment_method,
                    'transaction_reference', sp.transaction_reference,
                    'payment_date', sp.payment_date,
                    'status', sp.status,
                    'remarks', sp.remarks,
                    'created_at', sp.created_at,
                    'student_name', sp.student_name,
                    'roll_number', sp.roll_number,
                    'class_name', sp.class_name,
                    'invoice_number', sp.invoice_number
                )
            ), '[]'::jsonb
        ) INTO v_total_items, v_payments
    FROM sorted_page sp;

    v_total_items := COALESCE(v_total_items, 0);
    IF v_total_items > 0 THEN
        v_total_pages := CEIL(v_total_items::numeric / v_clean_size);
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'payments', v_payments,
        'pagination', jsonb_build_object(
            'page', v_clean_page,
            'page_size', v_clean_size,
            'total_items', v_total_items,
            'total_pages', v_total_pages
        )
    );
END;
$function$;
