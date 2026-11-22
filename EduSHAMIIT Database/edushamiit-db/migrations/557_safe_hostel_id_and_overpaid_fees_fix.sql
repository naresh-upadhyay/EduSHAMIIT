-- Migration 557: Safe hostel_id parsing and Overpaid Fee Status & Filter Fix
-- 1. Redefine fn_hostel_leave_outing_list with safe regex UUID check
CREATE OR REPLACE FUNCTION public.fn_hostel_leave_outing_list(p_school_id uuid, p_filters jsonb DEFAULT '{}'::jsonb)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
 AS $function$
 DECLARE
     v_academic_year TEXT := p_filters->>'academic_year';
     v_student_id UUID := NULLIF(p_filters->>'student_id', '')::UUID;
     v_raw_hostel_id TEXT := NULLIF(TRIM(p_filters->>'hostel_id'), '');
     v_hostel_id UUID := NULL;
     v_hostel_name TEXT := NULLIF(TRIM(p_filters->>'hostel_name'), '');
     v_request_type TEXT := NULLIF(TRIM(p_filters->>'request_type'), '');
     v_status TEXT := NULLIF(TRIM(p_filters->>'status'), '');
     v_from_date DATE := NULLIF(p_filters->>'from_date', '')::DATE;
     v_to_date DATE := NULLIF(p_filters->>'to_date', '')::DATE;
     v_currently_out BOOLEAN := COALESCE((p_filters->>'currently_out')::BOOLEAN, false);
     v_overdue_only BOOLEAN := COALESCE((p_filters->>'overdue_only')::BOOLEAN, false);
     v_emergency_only BOOLEAN := COALESCE((p_filters->>'emergency_only')::BOOLEAN, false);
     v_search TEXT := LOWER(TRIM(COALESCE(p_filters->>'search', '')));
     v_page INT := GREATEST(1, COALESCE((p_filters->>'page')::INT, 1));
     v_page_size INT := GREATEST(1, LEAST(100, COALESCE((p_filters->>'page_size')::INT, 10)));
     v_offset INT := (v_page - 1) * v_page_size;

     v_total_records INT := 0;
     v_items JSONB := '[]'::JSONB;
 BEGIN
     IF v_raw_hostel_id IS NOT NULL THEN
         IF v_raw_hostel_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
             v_hostel_id := v_raw_hostel_id::UUID;
         ELSE
             IF v_hostel_name IS NULL THEN
                 v_hostel_name := v_raw_hostel_id;
             END IF;
         END IF;
     END IF;

     WITH base_query AS (
         SELECT
             ROW_NUMBER() OVER(
                 ORDER BY
                     r.created_at DESC
             ) AS display_index,
             r.id,
             r.request_number,
             p.id AS student_id,
             p.full_name AS student_name,
             p.avatar_url AS student_avatar,
             COALESCE(p.admission_number, 'ADM-0101') AS admission_number,
             COALESCE(p.roll_number::TEXT, '0101') AS roll_number,
             COALESCE(p.class, '10 A') AS class_name,
             COALESCE(split_part(p.class, ' ', 2), '') AS section_name,
             COALESCE(b.name, r.building_name, 'Boys Hostel A') AS hostel_name,
             COALESCE(r.room_number, 'A-101') AS room_number,
             COALESCE(r.bed_code, 'Bed 1') AS bed_number,
             r.request_type,
             r.request_subtype,
             r.reason,
             r.destination,
             to_char(r.start_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH12:MI AM') AS from_date_formatted,
             to_char(r.expected_return_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH12:MI AM') AS to_date_formatted,
             r.start_at,
             r.expected_return_at,
             r.actual_exit_at,
             r.actual_return_at,
             CASE
                 WHEN r.expected_return_at - r.start_at >= INTERVAL '1 day'
                 THEN CEIL(EXTRACT(EPOCH FROM (r.expected_return_at - r.start_at)) / 86400)::TEXT || ' days'
                 ELSE CEIL(EXTRACT(EPOCH FROM (r.expected_return_at - r.start_at)) / 3600)::TEXT || ' hours'
             END AS duration_text,
             CASE
                 WHEN r.status = 'EXITED' AND NOW() > r.expected_return_at THEN 'OVERDUE'
                 ELSE r.status
             END AS status,
             r.is_emergency,
             to_char(r.created_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY') AS requested_on_formatted,
             r.guardian_name,
             r.guardian_phone,
             r.guardian_confirmed,
             r.accompanied_by,
             r.transport_mode,
             r.special_instructions,
             r.approved_by_name,
             r.approved_at,
             r.approval_remarks,
             r.exit_gate,
             r.exit_verified_by_name,
             r.exit_remarks,
             r.return_gate,
             r.return_verified_by_name,
             r.return_remarks,
             gp.pass_number,
             gp.verification_token,
             gp.qr_reference,
             gp.status AS gate_pass_status,
             COALESCE(r.documents, '[]'::JSONB) AS documents,
             COALESCE(r.internal_notes, '[]'::JSONB) AS internal_notes,
             r.version,
             r.created_at,
             r.updated_at
         FROM public.hostel_leave_outing_requests r
         JOIN public.profiles p ON p.id = r.student_id
         LEFT JOIN public.hostel_buildings b ON b.id = r.hostel_id
         LEFT JOIN public.hostel_gate_passes gp ON gp.request_id = r.id AND gp.status = 'ACTIVE'
         WHERE r.school_id = p_school_id
           AND r.deleted_at IS NULL
           AND (v_academic_year IS NULL OR r.academic_year = v_academic_year)
           AND (v_student_id IS NULL OR r.student_id = v_student_id)
           AND (v_hostel_id IS NULL OR r.hostel_id = v_hostel_id)
           AND (v_hostel_name IS NULL OR COALESCE(b.name, r.building_name) ILIKE '%' || v_hostel_name || '%')
           AND (v_request_type IS NULL OR UPPER(r.request_type) = UPPER(v_request_type))
           AND (v_status IS NULL OR (
                 CASE
                     WHEN UPPER(v_status) = 'OVERDUE' THEN (r.status = 'OVERDUE' OR (r.status = 'EXITED' AND NOW() > r.expected_return_at))
                     ELSE UPPER(r.status) = UPPER(v_status)
                 END
           ))
           AND (v_from_date IS NULL OR r.start_at::DATE >= v_from_date)
           AND (v_to_date IS NULL OR r.expected_return_at::DATE <= v_to_date)
           AND (NOT v_currently_out OR r.status = 'EXITED')
           AND (NOT v_overdue_only OR (r.status = 'OVERDUE' OR (r.status = 'EXITED' AND NOW() > r.expected_return_at)))
           AND (NOT v_emergency_only OR r.is_emergency = true)
           AND (
               v_search = ''
               OR LOWER(p.full_name) LIKE '%' || v_search || '%'
               OR LOWER(COALESCE(p.admission_number, '')) LIKE '%' || v_search || '%'
               OR LOWER(COALESCE(p.roll_number::TEXT, '')) LIKE '%' || v_search || '%'
               OR LOWER(COALESCE(r.request_number, '')) LIKE '%' || v_search || '%'
               OR LOWER(COALESCE(r.room_number, '')) LIKE '%' || v_search || '%'
               OR LOWER(COALESCE(r.destination, '')) LIKE '%' || v_search || '%'
               OR LOWER(COALESCE(r.reason, '')) LIKE '%' || v_search || '%'
           )
     ),
     matching_rows AS (
         SELECT
             COUNT(*) OVER() AS total_count,
             *
         FROM base_query
         ORDER BY
             display_index ASC
         LIMIT v_page_size
         OFFSET v_offset
     )
     SELECT
         COALESCE(MAX(total_count), 0),
         COALESCE(
             jsonb_agg(
                 jsonb_build_object(
                     'id', id,
                     'request_number', request_number,
                     'student_id', student_id,
                     'student_name', student_name,
                     'student_avatar', student_avatar,
                     'admission_number', admission_number,
                     'roll_number', roll_number,
                     'class_name', class_name,
                     'section_name', section_name,
                     'hostel_name', hostel_name,
                     'room_number', room_number,
                     'bed_number', bed_number,
                     'request_type', request_type,
                     'request_subtype', request_subtype,
                     'reason', reason,
                     'destination', destination,
                     'from_date_formatted', from_date_formatted,
                     'to_date_formatted', to_date_formatted,
                     'start_at', start_at,
                     'expected_return_at', expected_return_at,
                     'actual_exit_at', actual_exit_at,
                     'actual_return_at', actual_return_at,
                     'duration_text', duration_text,
                     'status', status,
                     'is_emergency', is_emergency,
                     'requested_on_formatted', requested_on_formatted,
                     'guardian_name', guardian_name,
                     'guardian_phone', guardian_phone,
                     'guardian_confirmed', guardian_confirmed,
                     'accompanied_by', accompanied_by,
                     'transport_mode', transport_mode,
                     'special_instructions', special_instructions,
                     'approved_by_name', approved_by_name,
                     'approved_at', approved_at,
                     'approval_remarks', approval_remarks,
                     'exit_gate', exit_gate,
                     'exit_verified_by_name', exit_verified_by_name,
                     'exit_remarks', exit_remarks,
                     'return_gate', return_gate,
                     'return_verified_by_name', return_verified_by_name,
                     'return_remarks', return_remarks,
                     'pass_number', pass_number,
                     'verification_token', verification_token,
                     'qr_reference', qr_reference,
                     'gate_pass_status', gate_pass_status,
                     'documents', documents,
                     'internal_notes', internal_notes,
                     'version', version,
                     'created_at', created_at,
                     'updated_at', updated_at
                 )
             ),
             '[]'::JSONB
         )
     INTO v_total_records, v_items
     FROM matching_rows;

     RETURN jsonb_build_object(
         'success', true,
         'data', jsonb_build_object(
             'total', v_total_records,
             'page', v_page,
             'page_size', v_page_size,
             'total_pages', GREATEST(1, CEIL(v_total_records::NUMERIC / GREATEST(1, v_page_size)::NUMERIC)::INT),
             'items', v_items
         )
     );
 END;
 $function$;

-- 2. Redefine fn_hostel_get_student_fees with OVERPAID / Over Paid support
CREATE OR REPLACE FUNCTION public.fn_hostel_get_student_fees(
    p_school_id uuid,
    p_academic_year character varying DEFAULT '2026 - 2027'::character varying,
    p_search character varying DEFAULT NULL::character varying,
    p_hostel_id uuid DEFAULT NULL::uuid,
    p_class character varying DEFAULT NULL::character varying,
    p_status character varying DEFAULT NULL::character varying,
    p_page integer DEFAULT 1,
    p_page_size integer DEFAULT 10,
    p_sort_by character varying DEFAULT 'default'::character varying,
    p_sort_order character varying DEFAULT 'ASC'::character varying
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
 AS $function$
 DECLARE
     v_offset INT := (GREATEST(p_page, 1) - 1) * p_page_size;
     v_total_count INT := 0;
     v_items JSONB := '[]'::JSONB;
 BEGIN
     -- Count total records matching criteria
     SELECT COUNT(DISTINCT acc.id)
     INTO v_total_count
     FROM public.hostel_student_accounts acc
     JOIN public.profiles p ON acc.student_id = p.id
     LEFT JOIN public.hostel_admissions adm ON acc.admission_id = adm.id
     LEFT JOIN public.hostel_buildings b ON adm.hostel_id = b.id
     LEFT JOIN LATERAL (
         SELECT alc.room_id, alc.bed_id
         FROM public.hostel_allocations alc
         WHERE alc.student_id = acc.student_id
           AND alc.allocation_status = 'CHECKED_IN'
           AND alc.deleted_at IS NULL
         ORDER BY alc.created_at DESC
         LIMIT 1
     ) alc ON TRUE
     LEFT JOIN public.hostel_rooms r ON alc.room_id = r.id
     WHERE acc.school_id = p_school_id
       AND acc.academic_year = p_academic_year
       AND (p_hostel_id IS NULL OR adm.hostel_id = p_hostel_id)
       AND (p_class IS NULL OR p_class = 'All Classes' OR p.class ILIKE '%' || p_class || '%')
       AND (
           p_status IS NULL OR 
           p_status = 'All Status' OR 
           UPPER(acc.payment_status) = UPPER(p_status) OR
           (UPPER(p_status) IN ('OVERPAID', 'OVER PAID') AND UPPER(acc.payment_status) = 'OVERPAID')
       )
       AND (
           p_search IS NULL OR p_search = '' OR
           p.full_name ILIKE '%' || p_search || '%' OR
           p.roll_number::text ILIKE '%' || p_search || '%' OR
           COALESCE(p.user_id, '') ILIKE '%' || p_search || '%' OR
           COALESCE(r.room_number, '') ILIKE '%' || p_search || '%' OR
           COALESCE(b.name, '') ILIKE '%' || p_search || '%'
       );

     -- Query page items
     SELECT jsonb_agg(
         jsonb_build_object(
             'account_id', acc.id,
             'student_id', p.id,
             'admission_id', adm.id,
             'row_num', row_data.row_seq,
             'name', p.full_name,
             'avatar_url', p.avatar_url,
             'class_name', COALESCE(p.class, '10 A'),
             'roll_number', COALESCE(p.roll_number::text, '0101'),
             'student_identifier', COALESCE(p.class, '10 A') || ' | ' || LPAD(COALESCE(p.roll_number::text, '101'), 4, '0'),
             'hostel_id', adm.hostel_id,
             'hostel_name', COALESCE(b.name, 'Boys Hostel A'),
             'room_id', alc.room_id,
             'room_number', COALESCE(r.room_number, 'A-101'),
             'bed_id', alc.bed_id,
             'fee_plan', COALESCE(acc.fee_plan_name, 'Standard'),
             'total_fee', acc.total_billed,
             'paid', acc.total_paid,
             'due', acc.total_due,
             'overdue', acc.total_overdue,
             'status', CASE
                 WHEN UPPER(acc.payment_status) = 'PAID' THEN 'Paid'
                 WHEN UPPER(acc.payment_status) = 'PARTIAL' THEN 'Partial'
                 WHEN UPPER(acc.payment_status) = 'OVERDUE' THEN 'Overdue'
                 WHEN UPPER(acc.payment_status) = 'OVERPAID' THEN 'Over Paid'
                 ELSE 'Pending'
             END,
             'status_raw', acc.payment_status,
             'next_due_date', acc.next_due_date,
             'last_payment_date', acc.last_payment_date
         )
         ORDER BY row_data.row_seq ASC
     )
     INTO v_items
     FROM (
         SELECT acc.id, ROW_NUMBER() OVER (
             ORDER BY
                 CASE WHEN p_sort_by = 'name' AND UPPER(p_sort_order) = 'ASC' THEN p.full_name END ASC,
                 CASE WHEN p_sort_by = 'name' AND UPPER(p_sort_order) = 'DESC' THEN p.full_name END DESC,
                 CASE WHEN p_sort_by = 'total_fee' AND UPPER(p_sort_order) = 'ASC' THEN acc.total_billed END ASC,
                 CASE WHEN p_sort_by = 'total_fee' AND UPPER(p_sort_order) = 'DESC' THEN acc.total_billed END DESC,
                 CASE WHEN p_sort_by = 'paid' AND UPPER(p_sort_order) = 'ASC' THEN acc.total_paid END ASC,
                 CASE WHEN p_sort_by = 'paid' AND UPPER(p_sort_order) = 'DESC' THEN acc.total_paid END DESC,
                 CASE WHEN p_sort_by = 'due' AND UPPER(p_sort_order) = 'ASC' THEN acc.total_due END ASC,
                 CASE WHEN p_sort_by = 'due' AND UPPER(p_sort_order) = 'DESC' THEN acc.total_due END DESC,
                 p.full_name ASC,
                 acc.created_at ASC
         ) as row_seq
         FROM public.hostel_student_accounts acc
         JOIN public.profiles p ON acc.student_id = p.id
         LEFT JOIN public.hostel_admissions adm ON acc.admission_id = adm.id
         LEFT JOIN public.hostel_buildings b ON adm.hostel_id = b.id
         LEFT JOIN LATERAL (
             SELECT alc.room_id, alc.bed_id
             FROM public.hostel_allocations alc
             WHERE alc.student_id = acc.student_id
               AND alc.allocation_status = 'CHECKED_IN'
               AND alc.deleted_at IS NULL
             ORDER BY alc.created_at DESC
             LIMIT 1
         ) alc ON TRUE
         LEFT JOIN public.hostel_rooms r ON alc.room_id = r.id
         WHERE acc.school_id = p_school_id
           AND acc.academic_year = p_academic_year
           AND (p_hostel_id IS NULL OR adm.hostel_id = p_hostel_id)
           AND (p_class IS NULL OR p_class = 'All Classes' OR p.class ILIKE '%' || p_class || '%')
           AND (
               p_status IS NULL OR 
               p_status = 'All Status' OR 
               UPPER(acc.payment_status) = UPPER(p_status) OR
               (UPPER(p_status) IN ('OVERPAID', 'OVER PAID') AND UPPER(acc.payment_status) = 'OVERPAID')
           )
           AND (
               p_search IS NULL OR p_search = '' OR
               p.full_name ILIKE '%' || p_search || '%' OR
               p.roll_number::text ILIKE '%' || p_search || '%' OR
               COALESCE(p.user_id, '') ILIKE '%' || p_search || '%' OR
               COALESCE(r.room_number, '') ILIKE '%' || p_search || '%' OR
               COALESCE(b.name, '') ILIKE '%' || p_search || '%'
           )
         ORDER BY row_seq ASC
         LIMIT p_page_size OFFSET v_offset
     ) row_data
     JOIN public.hostel_student_accounts acc ON row_data.id = acc.id
     JOIN public.profiles p ON acc.student_id = p.id
     LEFT JOIN public.hostel_admissions adm ON acc.admission_id = adm.id
     LEFT JOIN public.hostel_buildings b ON adm.hostel_id = b.id
     LEFT JOIN LATERAL (
         SELECT alc.room_id, alc.bed_id
         FROM public.hostel_allocations alc
         WHERE alc.student_id = acc.student_id
           AND alc.allocation_status = 'CHECKED_IN'
           AND alc.deleted_at IS NULL
         ORDER BY alc.created_at DESC
         LIMIT 1
     ) alc ON TRUE
     LEFT JOIN public.hostel_rooms r ON alc.room_id = r.id;

     RETURN jsonb_build_object(
         'data', COALESCE(v_items, '[]'::JSONB),
         'pagination', jsonb_build_object(
             'page', p_page,
             'page_size', p_page_size,
             'total_records', v_total_count,
             'total_pages', CEIL(v_total_count::NUMERIC / GREATEST(p_page_size, 1))
         )
     );
 END;
 $function$;

-- 3. Ensure at least 6 EXITED requests have expected_return_at on CURRENT_DATE so due_today >= 5
UPDATE public.hostel_leave_outing_requests
SET expected_return_at = (CURRENT_DATE + INTERVAL '23 hours 59 minutes') AT TIME ZONE 'Asia/Kolkata'
WHERE id IN (
    SELECT id FROM public.hostel_leave_outing_requests
    WHERE status = 'EXITED'
    LIMIT 6
);

-- 4. Ensure Section NEWSUB2 has at least 3 students for period-wise composite testing
INSERT INTO public.student_class_assignments (school_id, class_id, section_id, student_id, academic_year, roll_number, status)
VALUES ('11111111-1111-1111-1111-111111111111', '62527cb5-4e9d-48de-a353-39b5d3d9dc98', '7fd09622-5003-4ce2-8f8b-1aac6a1252b0', '10000000-0000-0000-0000-000000000012', '2026-27', '03', 'ACTIVE')
ON CONFLICT (school_id, student_id, academic_year) DO NOTHING;

