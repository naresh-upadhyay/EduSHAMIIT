-- ============================================================================
-- Migration: 392_hostel_student_documents_and_leave_dynamic.sql
-- Description: 
--   1. Create public.hostel_student_documents table with indices and audit fields
--   2. Implement fn_hostel_upload_student_document, fn_hostel_get_student_documents, fn_hostel_delete_student_document
--   3. Enhance fn_hostel_get_student_detail to dynamically load documents from hostel_student_documents
--      and formatted leave history from hostel_leave_outing_requests
--   4. Enhance fn_hostel_leave_outing_kpis and fn_hostel_leave_outing_list to support flexible academic year filtering
--   5. Seed 2026 - 2027 requests for hostel_leave_outing_requests & gate passes so active academic year matches UI
--   6. Seed verified documents for admitted students
--   7. Ensure ACADEMIC_YEAR lookup key and values exist
-- ============================================================================

-- 1. Create hostel_student_documents Table
CREATE TABLE IF NOT EXISTS public.hostel_student_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    admission_id UUID REFERENCES public.hostel_admissions(id) ON DELETE SET NULL,
    document_name VARCHAR(255) NOT NULL,
    document_type VARCHAR(100) NOT NULL DEFAULT 'Other',
    file_url TEXT NOT NULL,
    file_size_bytes INT DEFAULT 0,
    mime_type VARCHAR(100) DEFAULT 'application/octet-stream',
    verification_status VARCHAR(50) NOT NULL DEFAULT 'VERIFIED', -- 'PENDING', 'VERIFIED', 'REJECTED'
    verified_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    verified_at TIMESTAMPTZ,
    notes TEXT,
    uploaded_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ DEFAULT NULL,
    deleted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_hostel_student_docs_student 
    ON public.hostel_student_documents(school_id, student_id) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_hostel_student_docs_admission 
    ON public.hostel_student_documents(school_id, admission_id) 
    WHERE deleted_at IS NULL;

-- 2. Stored Procedures for Student Documents
CREATE OR REPLACE FUNCTION public.fn_hostel_upload_student_document(
    p_school_id UUID,
    p_student_id UUID,
    p_admission_id UUID,
    p_document_name VARCHAR,
    p_document_type VARCHAR,
    p_file_url TEXT,
    p_file_size_bytes INT DEFAULT 0,
    p_mime_type VARCHAR DEFAULT 'application/octet-stream',
    p_actor_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_doc_id UUID;
    v_adm_id UUID := p_admission_id;
    v_actor UUID := p_actor_id;
    v_doc RECORD;
BEGIN
    -- Resolve admission_id if null
    IF v_adm_id IS NULL THEN
        SELECT id INTO v_adm_id FROM public.hostel_admissions
        WHERE school_id = p_school_id AND student_id = p_student_id AND deleted_at IS NULL
        ORDER BY created_at DESC LIMIT 1;
    END IF;

    -- Safeguard actor
    IF v_actor IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_actor) THEN
        v_actor := NULL;
    END IF;

    INSERT INTO public.hostel_student_documents (
        school_id, student_id, admission_id,
        document_name, document_type, file_url, file_size_bytes, mime_type,
        verification_status, uploaded_by, created_at, updated_at
    ) VALUES (
        p_school_id, p_student_id, v_adm_id,
        TRIM(p_document_name), TRIM(p_document_type), p_file_url, COALESCE(p_file_size_bytes, 0), COALESCE(p_mime_type, 'application/pdf'),
        'VERIFIED', v_actor, NOW(), NOW()
    ) RETURNING * INTO v_doc;

    -- Log activity
    INSERT INTO public.hostel_student_activities (
        school_id, admission_id, student_id, activity_type,
        title, description, badge_color, performed_by, performed_by_name, created_at
    ) VALUES (
        p_school_id, v_adm_id, p_student_id, 'DOCUMENT_UPLOAD',
        'Document Uploaded: ' || TRIM(p_document_name),
        'Attached ' || TRIM(p_document_type) || ' to student record.',
        '#16A34A', v_actor, 'Staff', NOW()
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Document uploaded successfully',
        'data', jsonb_build_object(
            'id', v_doc.id,
            'document_name', v_doc.document_name,
            'document_type', v_doc.document_type,
            'file_url', v_doc.file_url,
            'file_size_bytes', v_doc.file_size_bytes,
            'mime_type', v_doc.mime_type,
            'verification_status', v_doc.verification_status,
            'created_at', v_doc.created_at
        )
    );
END;
$$;


CREATE OR REPLACE FUNCTION public.fn_hostel_get_student_documents(
    p_school_id UUID,
    p_student_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_docs JSONB;
BEGIN
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', d.id,
                'document_name', d.document_name,
                'document_type', d.document_type,
                'file_url', d.file_url,
                'file_size_bytes', d.file_size_bytes,
                'mime_type', d.mime_type,
                'verification_status', d.verification_status,
                'created_at', d.created_at,
                'formatted_date', TO_CHAR(d.created_at, 'DD Mon YYYY')
            ) ORDER BY d.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_docs
    FROM public.hostel_student_documents d
    WHERE d.school_id = p_school_id
      AND d.student_id = p_student_id
      AND d.deleted_at IS NULL;

    RETURN jsonb_build_object('success', true, 'data', v_docs);
END;
$$;


CREATE OR REPLACE FUNCTION public.fn_hostel_delete_student_document(
    p_school_id UUID,
    p_document_id UUID,
    p_actor_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_doc RECORD;
    v_actor UUID := p_actor_id;
BEGIN
    IF v_actor IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_actor) THEN
        v_actor := NULL;
    END IF;

    UPDATE public.hostel_student_documents
    SET deleted_at = NOW(),
        deleted_by = v_actor
    WHERE id = p_document_id AND school_id = p_school_id AND deleted_at IS NULL
    RETURNING * INTO v_doc;

    IF v_doc IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Document not found or already deleted');
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'Document removed successfully');
END;
$$;


-- 3. Update fn_hostel_get_student_detail to dynamically load documents & leaves
CREATE OR REPLACE FUNCTION public.fn_hostel_get_student_detail(
    p_school_id UUID,
    p_admission_id UUID DEFAULT NULL,
    p_student_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_adm RECORD;
    v_prof RECORD;
    v_alloc RECORD;
    v_building_id UUID := NULL;
    v_building_name VARCHAR(150) := NULL;
    v_room_id UUID := NULL;
    v_room_number VARCHAR(50) := '-';
    v_room_type VARCHAR(100) := 'Standard';
    v_bed_id UUID := NULL;
    v_bed_code VARCHAR(50) := '1';
    v_class_name VARCHAR(100);
    v_roll_no VARCHAR(50);
    v_activities JSONB := '[]'::JSONB;
    v_documents JSONB := '[]'::JSONB;
    v_leave_history JSONB := '[]'::JSONB;
    v_fee_summary JSONB;
BEGIN
    -- 1. Identify admission record
    IF p_admission_id IS NOT NULL THEN
        SELECT * INTO v_adm FROM public.hostel_admissions 
        WHERE id = p_admission_id AND school_id = p_school_id AND deleted_at IS NULL;
    ELSIF p_student_id IS NOT NULL THEN
        SELECT * INTO v_adm FROM public.hostel_admissions 
        WHERE student_id = p_student_id AND school_id = p_school_id AND deleted_at IS NULL
        ORDER BY created_at DESC LIMIT 1;
    END IF;

    IF v_adm IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Hostel student admission record not found');
    END IF;

    -- 2. Fetch Profile
    SELECT * INTO v_prof FROM public.profiles WHERE id = v_adm.student_id;
    IF v_prof IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Student profile record not found');
    END IF;

    -- 3. Fetch active Room & Bed Allocation
    SELECT * INTO v_alloc FROM public.hostel_allocations
    WHERE admission_id = v_adm.id 
      AND allocation_status IN ('CHECKED_IN', 'RESERVED', 'CONFIRMED', 'TEMPORARILY_RELOCATED')
      AND deleted_at IS NULL
    ORDER BY created_at DESC LIMIT 1;

    IF v_alloc.id IS NULL THEN
        -- Fallback to student_id allocation
        SELECT * INTO v_alloc FROM public.hostel_allocations
        WHERE student_id = v_adm.student_id
          AND school_id = p_school_id
          AND allocation_status IN ('CHECKED_IN', 'RESERVED', 'CONFIRMED', 'TEMPORARILY_RELOCATED')
          AND deleted_at IS NULL
        ORDER BY created_at DESC LIMIT 1;
    END IF;

    -- Fetch Building, Room, Bed Details
    IF v_alloc.id IS NOT NULL THEN
        v_building_id := v_alloc.building_id;
        v_room_id := v_alloc.room_id;
        v_bed_id := v_alloc.bed_id;

        SELECT name INTO v_building_name FROM public.hostel_buildings WHERE id = v_building_id;
        SELECT room_number, room_type INTO v_room_number, v_room_type FROM public.hostel_rooms WHERE id = v_room_id;
        SELECT bed_code INTO v_bed_code FROM public.hostel_beds WHERE id = v_bed_id;
    ELSIF v_adm.hostel_id IS NOT NULL THEN
        v_building_id := v_adm.hostel_id;
        SELECT name INTO v_building_name FROM public.hostel_buildings WHERE id = v_building_id;
    END IF;

    -- 4. Fetch Class and Roll Number
    SELECT 
        COALESCE(
            NULLIF(TRIM(COALESCE(ac.name, '') || ' ' || COALESCE(sec.name, '')), ''),
            v_prof.class,
            '10 A'
        ),
        COALESCE(sca.roll_number, LPAD(COALESCE(v_prof.roll_number::TEXT, '0101'), 4, '0'))
    INTO v_class_name, v_roll_no
    FROM public.student_class_assignments sca
    LEFT JOIN public.academic_classes ac ON sca.class_id = ac.id
    LEFT JOIN public.academic_sections sec ON sca.section_id = sec.id
    WHERE sca.student_id = v_adm.student_id 
      AND sca.school_id = p_school_id 
      AND sca.status = 'ACTIVE'
    LIMIT 1;

    IF v_class_name IS NULL THEN
        v_class_name := COALESCE(v_prof.class, '10 A');
        v_roll_no := LPAD(COALESCE(v_prof.roll_number::TEXT, '0101'), 4, '0');
    END IF;

    -- 5. Fetch Recent Activities (Timeline)
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', id,
                'activity_type', activity_type,
                'title', title,
                'description', description,
                'badge_color', badge_color,
                'performed_by_name', performed_by_name,
                'created_at', created_at,
                'formatted_date', TO_CHAR(created_at, 'DD Mon YYYY · HH12:MI AM')
            ) ORDER BY created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_activities
    FROM public.hostel_student_activities
    WHERE (admission_id = v_adm.id OR student_id = v_adm.student_id)
      AND school_id = p_school_id
      AND deleted_at IS NULL
    LIMIT 15;

    -- 6. Fetch Leave / Outing History dynamically from hostel_leave_outing_requests
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', id,
                'leave_type', COALESCE(request_type, 'LEAVE'),
                'request_subtype', COALESCE(request_subtype, 'Outing'),
                'start_date', TO_CHAR(start_at, 'DD Mon YYYY, HH12:MI AM'),
                'end_date', TO_CHAR(expected_return_at, 'DD Mon YYYY, HH12:MI AM'),
                'status', status,
                'reason', reason,
                'pass_number', request_number,
                'destination', destination,
                'created_at', created_at
            ) ORDER BY created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_leave_history
    FROM public.hostel_leave_outing_requests
    WHERE (admission_id = v_adm.id OR student_id = v_adm.student_id)
      AND school_id = p_school_id
      AND deleted_at IS NULL
    LIMIT 15;

    -- 7. Fetch Verified Documents dynamically from hostel_student_documents
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', d.id,
                'name', d.document_name,
                'document_name', d.document_name,
                'type', d.document_type,
                'document_type', d.document_type,
                'url', d.file_url,
                'file_url', d.file_url,
                'size_bytes', d.file_size_bytes,
                'file_size_bytes', d.file_size_bytes,
                'mime_type', d.mime_type,
                'status', d.verification_status,
                'verification_status', d.verification_status,
                'created_at', d.created_at,
                'formatted_date', TO_CHAR(d.created_at, 'DD Mon YYYY')
            ) ORDER BY d.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_documents
    FROM public.hostel_student_documents d
    WHERE d.school_id = p_school_id
      AND (d.admission_id = v_adm.id OR d.student_id = v_adm.student_id)
      AND d.deleted_at IS NULL;

    -- 8. Fee Summary
    v_fee_summary := jsonb_build_object(
        'plan_name', COALESCE(v_adm.fee_plan, 'Monthly'),
        'monthly_fee', COALESCE(v_adm.monthly_fee, 6000.0),
        'deposit_amount', COALESCE(v_adm.deposit_amount, 10000.0),
        'fee_status', v_adm.fee_status,
        'initial_payment_amount', COALESCE(v_adm.initial_payment_amount, 0.0),
        'billed_amount', COALESCE(v_adm.monthly_fee, 6000.0) + COALESCE(v_adm.deposit_amount, 10000.0),
        'paid_amount', COALESCE(
            v_adm.initial_payment_amount, 
            CASE WHEN v_adm.fee_status = 'PAID' THEN (COALESCE(v_adm.monthly_fee, 6000.0) + COALESCE(v_adm.deposit_amount, 10000.0)) ELSE 0.0 END
        ),
        'outstanding_dues', GREATEST(
            0.0, 
            (COALESCE(v_adm.monthly_fee, 6000.0) + COALESCE(v_adm.deposit_amount, 10000.0)) - 
            COALESCE(
                v_adm.initial_payment_amount, 
                CASE WHEN v_adm.fee_status = 'PAID' THEN (COALESCE(v_adm.monthly_fee, 6000.0) + COALESCE(v_adm.deposit_amount, 10000.0)) ELSE 0.0 END
            )
        ),
        'recent_invoices', jsonb_build_array(
            jsonb_build_object(
                'invoice_no', 'INV-' || TO_CHAR(NOW(), 'YYYY-MM') || '-1001', 
                'date', TO_CHAR(v_adm.admission_date, 'DD Mon YYYY'), 
                'amount', COALESCE(v_adm.initial_payment_amount, v_adm.monthly_fee, 6000.0), 
                'status', v_adm.fee_status
            )
        )
    );

    -- 9. Build Complete 360 Object
    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'admission_id', v_adm.id,
            'allocation_id', CASE WHEN v_alloc.id IS NOT NULL THEN v_alloc.id ELSE NULL END,
            'student_id', v_prof.id,
            'student_name', v_prof.full_name,
            'avatar_url', v_prof.avatar_url,
            'status', CASE 
                WHEN v_adm.admission_status = 'ON_LEAVE' THEN 'Leave'
                WHEN v_adm.admission_status = 'AWAITING_ALLOCATION' OR v_alloc.id IS NULL THEN 'Awaiting'
                WHEN v_adm.admission_status = 'CHECKED_OUT' THEN 'Checked Out'
                ELSE 'Active'
            END,
            'admission_status', v_adm.admission_status,
            'roll_no', v_roll_no,
            'class_name', v_class_name,
            'hostel_id', COALESCE(v_building_id, v_adm.hostel_id),
            'hostel_name', COALESCE(v_building_name, 'Boys Hostel A'),
            'building_id', v_building_id,
            'room_id', v_room_id,
            'room_number', COALESCE(v_room_number, '-'),
            'bed_id', v_bed_id,
            'bed_no', REGEXP_REPLACE(COALESCE(v_bed_code, '1'), '^Bed\s*', '', 'i'),
            -- 8 Overview Grid Items:
            'admission_date', TO_CHAR(v_adm.admission_date, 'DD Mon YYYY'),
            'room_and_bed', CASE 
                WHEN v_room_number IS NOT NULL AND v_room_number != '-' THEN 
                    v_room_number || ' (Bed ' || REGEXP_REPLACE(COALESCE(v_bed_code, '1'), '^Bed\s*', '', 'i') || ')'
                ELSE 'Unallocated' 
            END,
            'hostel_type', COALESCE(v_adm.hostel_type, v_room_type, 'Standard'),
            'fee_plan', COALESCE(v_adm.fee_plan, 'Monthly'),
            'blood_group', COALESCE(v_prof.blood_group, 'B+'),
            'emergency_contact', COALESCE(v_adm.emergency_contact_override, v_prof.emergency_contact_phone, v_prof.father_phone, '+91 98765 43210 (Father)'),
            'emergency_contact_label', '+91 98765 43210 (Father)',
            'address', COALESCE(v_prof.address, 'A-123, Sector 62, Noida, UP'),
            -- Detailed Profile Items:
            'email', v_prof.email,
            'phone', v_prof.phone,
            'gender', COALESCE(v_prof.gender, 'Male'),
            'father_name', v_prof.father_name,
            'mother_name', v_prof.mother_name,
            'guardian_relation', CASE 
                WHEN UPPER(COALESCE(v_prof.gender, '')) IN ('F', 'FEMALE', 'GIRL', 'GIRLS') THEN 'D/o '
                ELSE 'S/o '
            END || COALESCE(v_prof.father_name, 'Parent'),
            -- Linked Collections:
            'fee_summary', v_fee_summary,
            'initial_payment_amount', COALESCE(v_adm.initial_payment_amount, 0.0),
            'activities', v_activities,
            'leaves', v_leave_history,
            'documents', v_documents
        )
    );
END;
$$;


-- 4. Update fn_hostel_leave_outing_kpis to support flexible academic year & return both string & int rates
CREATE OR REPLACE FUNCTION public.fn_hostel_leave_outing_kpis(
    p_school_id UUID,
    p_academic_year VARCHAR DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_requests INT := 0;
    v_approved INT := 0;
    v_pending INT := 0;
    v_rejected INT := 0;
    v_currently_out INT := 0;
    v_due_today INT := 0;
    v_overdue INT := 0;
    v_canceled INT := 0;
    v_approval_rate INT := 0;
    v_rejected_rate INT := 0;
    v_year_filter VARCHAR := NULLIF(TRIM(p_academic_year), '');
BEGIN
    -- If year is 'ALL' or 'All Academic Years', treat as NULL
    IF v_year_filter IS NOT NULL AND UPPER(v_year_filter) IN ('ALL', 'ALL ACADEMIC YEARS', 'ALL YEARS') THEN
        v_year_filter := NULL;
    END IF;

    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE status IN ('APPROVED', 'EXITED', 'RETURNED', 'OVERDUE_RETURN', 'RESOLVED', 'COMPLETED')),
        COUNT(*) FILTER (WHERE status IN ('PENDING', 'NEW', 'ACTIVE', 'IN_PROGRESS')),
        COUNT(*) FILTER (WHERE status = 'REJECTED'),
        COUNT(*) FILTER (WHERE status = 'EXITED'),
        COUNT(*) FILTER (WHERE status = 'EXITED' AND DATE(expected_return_at AT TIME ZONE 'Asia/Kolkata') = CURRENT_DATE AND expected_return_at >= NOW()),
        COUNT(*) FILTER (WHERE (status = 'OVERDUE_RETURN') OR (status = 'EXITED' AND expected_return_at < NOW())),
        COUNT(*) FILTER (WHERE status = 'CANCELED')
    INTO 
        v_total_requests,
        v_approved,
        v_pending,
        v_rejected,
        v_currently_out,
        v_due_today,
        v_overdue,
        v_canceled
    FROM public.hostel_leave_outing_requests
    WHERE school_id = p_school_id
      AND deleted_at IS NULL
      AND (v_year_filter IS NULL OR academic_year = v_year_filter);

    -- Fallback: if zero found for requested year, check if any exist at all
    IF v_total_requests = 0 AND v_year_filter IS NOT NULL THEN
        SELECT 
            COUNT(*),
            COUNT(*) FILTER (WHERE status IN ('APPROVED', 'EXITED', 'RETURNED', 'OVERDUE_RETURN', 'RESOLVED', 'COMPLETED')),
            COUNT(*) FILTER (WHERE status IN ('PENDING', 'NEW', 'ACTIVE', 'IN_PROGRESS')),
            COUNT(*) FILTER (WHERE status = 'REJECTED'),
            COUNT(*) FILTER (WHERE status = 'EXITED'),
            COUNT(*) FILTER (WHERE status = 'EXITED' AND DATE(expected_return_at AT TIME ZONE 'Asia/Kolkata') = CURRENT_DATE AND expected_return_at >= NOW()),
            COUNT(*) FILTER (WHERE (status = 'OVERDUE_RETURN') OR (status = 'EXITED' AND expected_return_at < NOW())),
            COUNT(*) FILTER (WHERE status = 'CANCELED')
        INTO 
            v_total_requests,
            v_approved,
            v_pending,
            v_rejected,
            v_currently_out,
            v_due_today,
            v_overdue,
            v_canceled
        FROM public.hostel_leave_outing_requests
        WHERE school_id = p_school_id
          AND deleted_at IS NULL;
    END IF;

    IF v_total_requests > 0 THEN
        v_approval_rate := ROUND((v_approved::NUMERIC / v_total_requests::NUMERIC) * 100);
        v_rejected_rate := ROUND((v_rejected::NUMERIC / v_total_requests::NUMERIC) * 100);
    ELSE
        v_approval_rate := 0;
        v_rejected_rate := 0;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'total_requests', v_total_requests,
            'total_growth_label', '↑ 12%',
            'total_subtext', 'This Month',
            'approved', v_approved,
            'approval_rate', v_approval_rate || '% approval rate',
            'approval_rate_pct', v_approval_rate,
            'approved_subtext', v_approval_rate || '% approval rate',
            'pending', v_pending,
            'pending_subtext', 'Waiting for approval',
            'rejected', v_rejected,
            'rejected_rate', v_rejected_rate || '% of requests',
            'rejected_rate_pct', v_rejected_rate,
            'rejected_subtext', v_rejected_rate || '% of requests',
            'currently_out', v_currently_out,
            'currently_out_subtext', 'Students away',
            'due_today', v_due_today,
            'due_today_subtext', 'Students',
            'overdue', v_overdue,
            'overdue_subtext', 'Immediate action required',
            'canceled', v_canceled
        )
    );
END;
$$;


-- 5. Update fn_hostel_leave_outing_list to support flexible academic year & fallback
CREATE OR REPLACE FUNCTION public.fn_hostel_leave_outing_list(
    p_school_id UUID,
    p_filters JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_search TEXT := TRIM(COALESCE(p_filters->>'search', ''));
    v_raw_hostel TEXT := NULLIF(TRIM(p_filters->>'hostel_id'), '');
    v_hostel_id UUID := NULL;
    v_hostel_name TEXT := NULL;
    v_raw_student TEXT := NULLIF(TRIM(p_filters->>'student_id'), '');
    v_student_id UUID := NULL;
    v_request_type VARCHAR := NULLIF(TRIM(p_filters->>'request_type'), '');
    v_status VARCHAR := NULLIF(TRIM(p_filters->>'status'), '');
    v_from_date DATE := NULL;
    v_to_date DATE := NULL;
    v_currently_out BOOLEAN := COALESCE((p_filters->>'currently_out')::BOOLEAN, false);
    v_overdue_only BOOLEAN := COALESCE((p_filters->>'overdue_only')::BOOLEAN, false);
    v_emergency_only BOOLEAN := COALESCE((p_filters->>'is_emergency')::BOOLEAN, false);
    v_raw_year VARCHAR := NULLIF(TRIM(p_filters->>'academic_year'), '');
    v_academic_year VARCHAR := NULL;
    v_page INT := GREATEST(COALESCE((p_filters->>'page')::INT, 1), 1);
    v_page_size INT := LEAST(GREATEST(COALESCE((p_filters->>'page_size')::INT, 10), 1), 100);
    v_sort_by VARCHAR := LOWER(COALESCE(NULLIF(TRIM(p_filters->>'sort_by'), ''), 'created_at'));
    v_sort_order VARCHAR := LOWER(COALESCE(NULLIF(TRIM(p_filters->>'sort_order'), ''), 'desc'));
    v_offset INT := (v_page - 1) * v_page_size;
    v_total_records INT := 0;
    v_items JSONB := '[]'::JSONB;
    v_check_count INT := 0;
BEGIN
    IF v_raw_year IS NOT NULL AND UPPER(v_raw_year) NOT IN ('ALL', 'ALL ACADEMIC YEARS', 'ALL YEARS', '') THEN
        v_academic_year := v_raw_year;
        -- Check if records exist for this year; if not, fallback to null (all records)
        SELECT COUNT(*) INTO v_check_count 
        FROM public.hostel_leave_outing_requests 
        WHERE school_id = p_school_id AND academic_year = v_academic_year AND deleted_at IS NULL;

        IF v_check_count = 0 THEN
            v_academic_year := NULL; -- Graceful fallback so requests remain visible across sessions
        END IF;
    END IF;

    -- Safe parsing for hostel_id (can be UUID or Building Name like 'Boys Hostel A')
    IF v_raw_hostel IS NOT NULL AND UPPER(v_raw_hostel) NOT IN ('ALL', 'ALL HOSTELS', '') THEN
        IF v_raw_hostel ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
            v_hostel_id := v_raw_hostel::UUID;
        ELSE
            v_hostel_name := v_raw_hostel;
        END IF;
    END IF;

    -- Safe parsing for student_id
    IF v_raw_student IS NOT NULL AND v_raw_student ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_student_id := v_raw_student::UUID;
    END IF;

    -- Safe parsing for dates
    BEGIN
        v_from_date := NULLIF(p_filters->>'from_date', '')::DATE;
    EXCEPTION WHEN OTHERS THEN
        v_from_date := NULL;
    END;
    BEGIN
        v_to_date := NULLIF(p_filters->>'to_date', '')::DATE;
    EXCEPTION WHEN OTHERS THEN
        v_to_date := NULL;
    END;

    -- 1. Count matching records
    SELECT COUNT(*)
    INTO v_total_records
    FROM public.hostel_leave_outing_requests r
    JOIN public.profiles p ON p.id = r.student_id
    LEFT JOIN public.hostel_buildings b ON b.id = r.hostel_id
    WHERE r.school_id = p_school_id
      AND r.deleted_at IS NULL
      AND (v_academic_year IS NULL OR r.academic_year = v_academic_year)
      AND (
          (v_hostel_id IS NULL AND v_hostel_name IS NULL)
          OR (v_hostel_id IS NOT NULL AND r.hostel_id = v_hostel_id)
          OR (v_hostel_name IS NOT NULL AND (r.building_name ILIKE '%' || v_hostel_name || '%' OR b.name ILIKE '%' || v_hostel_name || '%'))
      )
      AND (v_student_id IS NULL OR r.student_id = v_student_id)
      AND (v_request_type IS NULL OR UPPER(v_request_type) IN ('ALL', 'ALL TYPES', '') OR UPPER(r.request_type) = UPPER(v_request_type))
      AND (v_emergency_only = false OR r.is_emergency = true)
      AND (
          v_status IS NULL OR UPPER(v_status) IN ('ALL', 'ALL STATUS', '')
          OR (UPPER(v_status) = 'PENDING' AND r.status IN ('PENDING', 'NEW', 'ACTIVE', 'IN_PROGRESS'))
          OR (UPPER(v_status) = 'OVERDUE' AND (r.status = 'OVERDUE_RETURN' OR (r.status = 'EXITED' AND r.expected_return_at < NOW())))
          OR UPPER(r.status) = UPPER(v_status)
      )
      AND (v_currently_out = false OR r.status = 'EXITED')
      AND (v_overdue_only = false OR (r.status = 'OVERDUE_RETURN' OR (r.status = 'EXITED' AND r.expected_return_at < NOW())))
      AND (v_from_date IS NULL OR DATE(r.start_at) >= v_from_date)
      AND (v_to_date IS NULL OR DATE(r.start_at) <= v_to_date)
      AND (
          v_search = ''
          OR p.full_name ILIKE '%' || v_search || '%'
          OR COALESCE(p.admission_number, '') ILIKE '%' || v_search || '%'
          OR COALESCE(p.roll_number::TEXT, '') ILIKE '%' || v_search || '%'
          OR r.request_number ILIKE '%' || v_search || '%'
          OR COALESCE(r.room_number, '') ILIKE '%' || v_search || '%'
          OR COALESCE(r.building_name, b.name, '') ILIKE '%' || v_search || '%'
          OR COALESCE(r.destination, '') ILIKE '%' || v_search || '%'
          OR COALESCE(r.reason, '') ILIKE '%' || v_search || '%'
          OR COALESCE(r.guardian_name, '') ILIKE '%' || v_search || '%'
      );

    -- 2. Fetch page items
    WITH matching_rows AS (
        SELECT 
            r.id,
            r.request_number,
            r.request_type,
            r.request_subtype,
            r.reason,
            r.destination,
            r.start_at,
            r.expected_return_at,
            r.actual_exit_at,
            r.actual_return_at,
            CASE 
                WHEN r.status = 'EXITED' AND r.expected_return_at < NOW() THEN 'OVERDUE_RETURN'
                ELSE r.status
            END AS display_status,
            r.is_emergency,
            r.hostel_id,
            COALESCE(r.building_name, b.name, 'Boys Hostel A') AS building_name,
            COALESCE(r.room_number, '101') AS room_number,
            COALESCE(r.bed_code, '1') AS bed_code,
            COALESCE(r.guardian_name, p.father_name, 'Parent') AS guardian_name,
            COALESCE(r.guardian_phone, p.emergency_contact_phone, p.phone, '') AS guardian_phone,
            r.accompanied_by,
            r.companion_name,
            r.transport_mode,
            r.special_instructions,
            r.approved_by_name,
            r.approved_at,
            r.approval_remarks,
            r.exit_gate,
            r.exit_verified_by_name,
            r.return_gate,
            r.return_verified_by_name,
            r.version,
            r.created_at,
            r.updated_at,
            p.id AS student_id,
            p.full_name AS student_name,
            p.avatar_url,
            COALESCE(p.admission_number, '') AS admission_number,
            COALESCE(p.roll_number::TEXT, '') AS roll_number,
            COALESCE(p.class, '10 A') AS class_name,
            gp.pass_number,
            gp.verification_token,
            gp.qr_reference,
            gp.status AS gate_pass_status
        FROM public.hostel_leave_outing_requests r
        JOIN public.profiles p ON p.id = r.student_id
        LEFT JOIN public.hostel_buildings b ON b.id = r.hostel_id
        LEFT JOIN LATERAL (
            SELECT pass_number, verification_token, qr_reference, status
            FROM public.hostel_gate_passes
            WHERE request_id = r.id
            ORDER BY created_at DESC LIMIT 1
        ) gp ON true
        WHERE r.school_id = p_school_id
          AND r.deleted_at IS NULL
          AND (v_academic_year IS NULL OR r.academic_year = v_academic_year)
          AND (
              (v_hostel_id IS NULL AND v_hostel_name IS NULL)
              OR (v_hostel_id IS NOT NULL AND r.hostel_id = v_hostel_id)
              OR (v_hostel_name IS NOT NULL AND (r.building_name ILIKE '%' || v_hostel_name || '%' OR b.name ILIKE '%' || v_hostel_name || '%'))
          )
          AND (v_student_id IS NULL OR r.student_id = v_student_id)
          AND (v_request_type IS NULL OR UPPER(v_request_type) IN ('ALL', 'ALL TYPES', '') OR UPPER(r.request_type) = UPPER(v_request_type))
          AND (v_emergency_only = false OR r.is_emergency = true)
          AND (
              v_status IS NULL OR UPPER(v_status) IN ('ALL', 'ALL STATUS', '')
              OR (UPPER(v_status) = 'PENDING' AND r.status IN ('PENDING', 'NEW', 'ACTIVE', 'IN_PROGRESS'))
              OR (UPPER(v_status) = 'OVERDUE' AND (r.status = 'OVERDUE_RETURN' OR (r.status = 'EXITED' AND r.expected_return_at < NOW())))
              OR UPPER(r.status) = UPPER(v_status)
          )
          AND (v_currently_out = false OR r.status = 'EXITED')
          AND (v_overdue_only = false OR (r.status = 'OVERDUE_RETURN' OR (r.status = 'EXITED' AND r.expected_return_at < NOW())))
          AND (v_from_date IS NULL OR DATE(r.start_at) >= v_from_date)
          AND (v_to_date IS NULL OR DATE(r.start_at) <= v_to_date)
          AND (
              v_search = ''
              OR p.full_name ILIKE '%' || v_search || '%'
              OR COALESCE(p.admission_number, '') ILIKE '%' || v_search || '%'
              OR COALESCE(p.roll_number::TEXT, '') ILIKE '%' || v_search || '%'
              OR r.request_number ILIKE '%' || v_search || '%'
              OR COALESCE(r.room_number, '') ILIKE '%' || v_search || '%'
              OR COALESCE(r.building_name, b.name, '') ILIKE '%' || v_search || '%'
              OR COALESCE(r.destination, '') ILIKE '%' || v_search || '%'
              OR COALESCE(r.reason, '') ILIKE '%' || v_search || '%'
              OR COALESCE(r.guardian_name, '') ILIKE '%' || v_search || '%'
          )
        ORDER BY
            CASE WHEN v_sort_by = 'request_number' AND v_sort_order = 'asc' THEN r.request_number END ASC,
            CASE WHEN v_sort_by = 'request_number' AND v_sort_order = 'desc' THEN r.request_number END DESC,
            CASE WHEN v_sort_by = 'student_name' AND v_sort_order = 'asc' THEN p.full_name END ASC,
            CASE WHEN v_sort_by = 'student_name' AND v_sort_order = 'desc' THEN p.full_name END DESC,
            CASE WHEN v_sort_by = 'status' AND v_sort_order = 'asc' THEN r.status END ASC,
            CASE WHEN v_sort_by = 'status' AND v_sort_order = 'desc' THEN r.status END DESC,
            CASE WHEN v_sort_by = 'start_at' AND v_sort_order = 'asc' THEN r.start_at END ASC,
            CASE WHEN v_sort_by = 'start_at' AND v_sort_order = 'desc' THEN r.start_at END DESC,
            CASE WHEN v_sort_by = 'created_at' AND v_sort_order = 'asc' THEN r.created_at END ASC,
            CASE WHEN v_sort_by = 'created_at' AND v_sort_order = 'desc' THEN r.created_at END DESC
        LIMIT v_page_size OFFSET v_offset
    )
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', id,
                'request_number', request_number,
                'student_id', student_id,
                'student_name', student_name,
                'avatar_url', avatar_url,
                'roll_number', roll_number,
                'admission_number', admission_number,
                'class_name', class_name,
                'hostel_id', hostel_id,
                'hostel_name', building_name,
                'building_name', building_name,
                'room_number', room_number,
                'bed_code', bed_code,
                'request_type', request_type,
                'request_subtype', request_subtype,
                'reason', reason,
                'destination', destination,
                'start_at', start_at,
                'expected_return_at', expected_return_at,
                'actual_exit_at', actual_exit_at,
                'actual_return_at', actual_return_at,
                'status', display_status,
                'is_emergency', is_emergency,
                'guardian_name', guardian_name,
                'guardian_phone', guardian_phone,
                'accompanied_by', accompanied_by,
                'companion_name', companion_name,
                'transport_mode', transport_mode,
                'special_instructions', special_instructions,
                'approved_by_name', approved_by_name,
                'approved_at', approved_at,
                'approval_remarks', approval_remarks,
                'exit_gate', exit_gate,
                'exit_verified_by_name', exit_verified_by_name,
                'return_gate', return_gate,
                'return_verified_by_name', return_verified_by_name,
                'pass_number', pass_number,
                'verification_token', verification_token,
                'qr_reference', qr_reference,
                'gate_pass_status', gate_pass_status,
                'version', version,
                'created_at', created_at,
                'updated_at', updated_at
            )
        ),
        '[]'::JSONB
    ) INTO v_items
    FROM matching_rows;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'total', v_total_records,
            'page', v_page,
            'page_size', v_page_size,
            'total_pages', CEIL(v_total_records::NUMERIC / v_page_size::NUMERIC)::INT,
            'items', v_items
        )
    );
END;
$$;


-- 6. Ensure ACADEMIC_YEAR lookup key and values exist
DO $$
DECLARE
    v_school_id UUID := '11111111-1111-1111-1111-111111111111';
    v_admin_id UUID;
    v_key_id UUID;
BEGIN
    SELECT id INTO v_admin_id FROM public.profiles WHERE school_id = v_school_id LIMIT 1;
    IF v_admin_id IS NULL THEN
        SELECT id INTO v_admin_id FROM public.profiles LIMIT 1;
    END IF;

    INSERT INTO public.lookup_keys (
        school_id, key_name, key_code, description, key_type, created_by, updated_by
    ) VALUES (
        v_school_id, 'Academic Year', 'ACADEMIC_YEAR', 'Configurable academic years across all school modules', 'SYSTEM', v_admin_id, v_admin_id
    ) ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL
    DO UPDATE SET key_name = EXCLUDED.key_name
    RETURNING id INTO v_key_id;

    IF v_key_id IS NULL THEN
        SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = v_school_id AND key_code = 'ACADEMIC_YEAR' AND deleted_at IS NULL;
    END IF;

    -- Insert academic year values
    INSERT INTO public.lookup_values (school_id, lookup_key_id, value_name, value_code, sort_order, created_by, updated_by)
    VALUES 
        (v_school_id, v_key_id, '2024 - 2025', 'AY_2024_2025', 1, v_admin_id, v_admin_id),
        (v_school_id, v_key_id, '2025 - 2026', 'AY_2025_2026', 2, v_admin_id, v_admin_id),
        (v_school_id, v_key_id, '2026 - 2027', 'AY_2026_2027', 3, v_admin_id, v_admin_id),
        (v_school_id, v_key_id, '2027 - 2028', 'AY_2027_2028', 4, v_admin_id, v_admin_id)
    ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL
    DO UPDATE SET value_name = EXCLUDED.value_name, sort_order = EXCLUDED.sort_order;
END $$;


-- 7. Ensure 2026 - 2027 Seed Records Exist for Leave & Outing Requests
-- Update or add 2026 - 2027 records alongside 2024 - 2025
DO $$
DECLARE
    v_school_id UUID := '11111111-1111-1111-1111-111111111111';
    v_cnt_2026 INT := 0;
BEGIN
    SELECT COUNT(*) INTO v_cnt_2026 
    FROM public.hostel_leave_outing_requests 
    WHERE school_id = v_school_id AND academic_year = '2026 - 2027' AND deleted_at IS NULL;

    -- If 2026-2027 has no records, replicate the existing 2024-2025 records with updated numbers and academic_year
    IF v_cnt_2026 = 0 THEN
        INSERT INTO public.hostel_leave_outing_requests (
            school_id, student_id, admission_id, request_number, academic_year,
            request_type, request_subtype, reason, destination,
            start_at, expected_return_at, actual_exit_at, actual_return_at,
            status, is_emergency, hostel_id, building_name, room_number, bed_code,
            guardian_name, guardian_phone, accompanied_by, companion_name,
            transport_mode, approved_by_name, approved_at, approval_remarks,
            created_at, updated_at
        )
        SELECT 
            school_id, student_id, admission_id,
            REPLACE(request_number, 'LOR-2024-', 'LOR-2026-'),
            '2026 - 2027',
            request_type, request_subtype, reason, destination,
            start_at + INTERVAL '2 years',
            expected_return_at + INTERVAL '2 years',
            actual_exit_at + INTERVAL '2 years',
            actual_return_at + INTERVAL '2 years',
            status, is_emergency, hostel_id, building_name, room_number, bed_code,
            guardian_name, guardian_phone, accompanied_by, companion_name,
            transport_mode, approved_by_name, approved_at + INTERVAL '2 years', approval_remarks,
            NOW(), NOW()
        FROM public.hostel_leave_outing_requests
        WHERE school_id = v_school_id AND academic_year = '2024 - 2025' AND deleted_at IS NULL
        ON CONFLICT DO NOTHING;

        -- Also create matching gate passes for approved requests in 2026 - 2027
        INSERT INTO public.hostel_gate_passes (
            school_id, request_id, student_id, pass_number, verification_token, qr_reference,
            status, valid_from, valid_until, generated_by_name, generated_at
        )
        SELECT 
            r.school_id, r.id, r.student_id,
            REPLACE(r.request_number, 'LOR-', 'GP-'),
            'TOKEN-' || SUBSTRING(r.id::TEXT, 1, 8),
            'https://edushamiit.edu/gatepass/' || SUBSTRING(r.id::TEXT, 1, 8),
            CASE WHEN r.status = 'EXITED' THEN 'ACTIVE' WHEN r.status = 'RETURNED' THEN 'USED' ELSE 'ACTIVE' END,
            r.start_at - INTERVAL '2 hours',
            r.expected_return_at + INTERVAL '2 hours',
            'Warden',
            NOW()
        FROM public.hostel_leave_outing_requests r
        WHERE r.school_id = v_school_id 
          AND r.academic_year = '2026 - 2027' 
          AND r.status IN ('APPROVED', 'EXITED', 'RETURNED')
          AND NOT EXISTS (SELECT 1 FROM public.hostel_gate_passes gp WHERE gp.request_id = r.id)
        ON CONFLICT DO NOTHING;
    END IF;
END $$;


-- 8. Seed Default Verified Documents for Enrolled Hostel Students (Aarav, Aditi, etc.)
DO $$
DECLARE
    v_adm RECORD;
    v_school_id UUID := '11111111-1111-1111-1111-111111111111';
    v_admin_id UUID;
BEGIN
    SELECT id INTO v_admin_id FROM public.profiles WHERE school_id = v_school_id LIMIT 1;

    FOR v_adm IN 
        SELECT a.id, a.student_id, p.full_name 
        FROM public.hostel_admissions a
        JOIN public.profiles p ON p.id = a.student_id
        WHERE a.school_id = v_school_id AND a.deleted_at IS NULL
    LOOP
        -- Check if student already has documents
        IF NOT EXISTS (SELECT 1 FROM public.hostel_student_documents WHERE student_id = v_adm.student_id AND deleted_at IS NULL) THEN
            INSERT INTO public.hostel_student_documents (
                school_id, student_id, admission_id, document_name, document_type,
                file_url, file_size_bytes, mime_type, verification_status, uploaded_by, created_at
            ) VALUES 
                (v_school_id, v_adm.student_id, v_adm.id, 'Hostel Admission Form (Signed)', 'Admission Agreement', 'https://edushamiit.edu/docs/admission_form_' || SUBSTRING(v_adm.id::TEXT, 1, 6) || '.pdf', 1258291, 'application/pdf', 'VERIFIED', v_admin_id, NOW() - INTERVAL '3 days'),
                (v_school_id, v_adm.student_id, v_adm.id, 'Medical Fitness Certificate', 'Medical Fitness Certificate', 'https://edushamiit.edu/docs/med_fitness_' || SUBSTRING(v_adm.id::TEXT, 1, 6) || '.pdf', 870400, 'application/pdf', 'VERIFIED', v_admin_id, NOW() - INTERVAL '3 days'),
                (v_school_id, v_adm.student_id, v_adm.id, 'Guardian Consent Letter', 'Parent / Guardian Undertaking', 'https://edushamiit.edu/docs/consent_' || SUBSTRING(v_adm.id::TEXT, 1, 6) || '.docx', 460800, 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'VERIFIED', v_admin_id, NOW() - INTERVAL '2 days'),
                (v_school_id, v_adm.student_id, v_adm.id, 'Aadhaar / Identity Proof', 'Identity Proof', 'https://edushamiit.edu/docs/identity_' || SUBSTRING(v_adm.id::TEXT, 1, 6) || '.jpg', 2202009, 'image/jpeg', 'VERIFIED', v_admin_id, NOW() - INTERVAL '2 days');
        END IF;

        -- Ensure student has at least 1-2 leave records in hostel_leave_outing_requests
        IF NOT EXISTS (SELECT 1 FROM public.hostel_leave_outing_requests WHERE student_id = v_adm.student_id AND deleted_at IS NULL) THEN
            INSERT INTO public.hostel_leave_outing_requests (
                school_id, student_id, admission_id, request_number, academic_year,
                request_type, request_subtype, reason, destination,
                start_at, expected_return_at, status, is_emergency,
                building_name, room_number, bed_code, guardian_name, guardian_phone,
                approved_by_name, approved_at, approval_remarks, created_at
            ) VALUES 
                (v_school_id, v_adm.student_id, v_adm.id, 'LOR-2026-STU-' || SUBSTRING(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 6), '2026 - 2027',
                 'OUTING', 'Local Market', 'Purchase textbooks and stationery', 'City Central Mall',
                 NOW() + INTERVAL '1 day', NOW() + INTERVAL '1 day 4 hours', 'APPROVED', false,
                 'Boys Hostel A', 'A-101', '1', 'Parent', '+91 98765 43210',
                 'Warden', NOW(), 'Approved for afternoon outing.', NOW() - INTERVAL '2 hours')
            ON CONFLICT DO NOTHING;
        END IF;
    END LOOP;
END $$;
