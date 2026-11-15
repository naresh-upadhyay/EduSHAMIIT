-- ============================================================================
-- MIGRATION 357: HR TRAINING & LEARNING STORED PROCEDURES AND FUNCTIONS
-- Description: High-performance PostgreSQL PL/pgSQL stored procedures and functions
--              for Training Programs, Assessments, Certificates, Feedback, Sessions,
--              Attendance, and Audit Logging. Replaces raw API SQL queries.
-- ============================================================================

-- Ensure passing_score column exists on hr_training_programs
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'hr_training_programs' 
          AND column_name = 'passing_score'
    ) THEN
        ALTER TABLE public.hr_training_programs ADD COLUMN passing_score NUMERIC(5,2) DEFAULT 70.0;
    END IF;
END $$;

ALTER TABLE public.hr_training_enrollments
    ADD COLUMN IF NOT EXISTS progress_percentage NUMERIC DEFAULT 0.0,
    ADD COLUMN IF NOT EXISTS is_mandatory BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS enrolled_at TIMESTAMPTZ DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS attendance_status TEXT DEFAULT 'PENDING',
    ADD COLUMN IF NOT EXISTS certificate_status TEXT DEFAULT 'NOT_ISSUED';

ALTER TABLE public.hr_training_attendance
    ADD COLUMN IF NOT EXISTS attendance_status TEXT,
    ADD COLUMN IF NOT EXISTS recorded_by UUID,
    ADD COLUMN IF NOT EXISTS recorded_at TIMESTAMPTZ DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS remarks TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS uq_hr_training_session_enrollment
    ON public.hr_training_attendance (session_id, enrollment_id);

CREATE UNIQUE INDEX IF NOT EXISTS uq_hr_training_cert_program_employee
    ON public.hr_training_certificates (program_id, employee_id);


-- ============================================================================
-- 1. PROGRAM DETAIL & TAB DATA AGGREGATION
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_hr_training_get_program_detail(
    p_program_id UUID,
    p_school_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_prog RECORD;
    v_sessions JSONB;
    v_materials JSONB;
    v_attendance_summary JSONB;
    v_total_records INT := 0;
    v_present_cnt INT := 0;
    v_absent_cnt INT := 0;
    v_late_cnt INT := 0;
    v_comp_rate NUMERIC(5,1) := 0.0;
    v_abs_rate NUMERIC(5,1) := 0.0;
    v_has_records BOOLEAN := FALSE;
BEGIN
    -- 1. Fetch program row
    SELECT * INTO v_prog
    FROM public.hr_training_programs
    WHERE id = p_program_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    -- 2. Fetch sessions with attendance stats
    SELECT COALESCE(jsonb_agg(to_jsonb(s_obj) ORDER BY s_obj.session_date ASC, s_obj.start_time ASC), '[]'::jsonb)
    INTO v_sessions
    FROM (
        SELECT 
            s.id,
            s.program_id,
            s.session_title,
            s.session_date::text as session_date,
            s.start_time::text as start_time,
            s.end_time::text as end_time,
            s.trainer_name,
            s.location_or_link,
            s.mode,
            s.capacity,
            s.enrolled_count,
            s.status,
            s.notes,
            (COUNT(a.id) > 0) as attendance_marked,
            COUNT(a.id)::int as attendance_recorded_count,
            COUNT(a.id) FILTER (WHERE UPPER(a.attendance_status) = 'PRESENT')::int as attendance_present_count,
            CASE 
                WHEN COUNT(a.id) > 0 THEN 'Marked (' || COUNT(a.id) FILTER (WHERE UPPER(a.attendance_status) = 'PRESENT')::text || ' Present)'
                ELSE 'Pending'
            END as attendance_display_status
        FROM public.hr_training_sessions s
        LEFT JOIN public.hr_training_attendance a ON a.session_id = s.id AND a.school_id = p_school_id
        WHERE s.program_id = p_program_id AND s.school_id = p_school_id
        GROUP BY s.id, s.program_id, s.session_title, s.session_date, s.start_time, s.end_time,
                 s.trainer_name, s.location_or_link, s.mode, s.capacity, s.enrolled_count, s.status, s.notes
    ) s_obj;

    -- 3. Fetch materials
    SELECT COALESCE(jsonb_agg(to_jsonb(m_obj) ORDER BY m_obj.created_at DESC), '[]'::jsonb)
    INTO v_materials
    FROM (
        SELECT 
            id,
            program_id,
            title,
            material_type,
            file_url,
            external_link,
            file_size_display,
            created_at::text as created_at
        FROM public.hr_training_materials
        WHERE program_id = p_program_id AND school_id = p_school_id
    ) m_obj;

    -- 4. Calculate attendance summary
    SELECT 
        COUNT(a.id)::int,
        COUNT(a.id) FILTER (WHERE UPPER(a.attendance_status) = 'PRESENT')::int,
        COUNT(a.id) FILTER (WHERE UPPER(a.attendance_status) = 'ABSENT')::int,
        COUNT(a.id) FILTER (WHERE UPPER(a.attendance_status) = 'LATE')::int
    INTO v_total_records, v_present_cnt, v_absent_cnt, v_late_cnt
    FROM public.hr_training_attendance a
    JOIN public.hr_training_sessions s ON s.id = a.session_id
    WHERE s.program_id = p_program_id AND a.school_id = p_school_id;

    IF v_total_records > 0 THEN
        v_comp_rate := ROUND(((v_present_cnt + (v_late_cnt * 0.5)) / v_total_records::numeric) * 100, 1);
        v_abs_rate := ROUND((v_absent_cnt / v_total_records::numeric) * 100, 1);
        v_has_records := TRUE;
    ELSE
        -- Fallback to enrollment-level attendance if any
        SELECT 
            (COUNT(*) FILTER (WHERE UPPER(COALESCE(attendance_status, '')) = 'PRESENT') +
             COUNT(*) FILTER (WHERE UPPER(COALESCE(attendance_status, '')) = 'ABSENT'))::int,
            COUNT(*) FILTER (WHERE UPPER(COALESCE(attendance_status, '')) = 'PRESENT')::int,
            COUNT(*) FILTER (WHERE UPPER(COALESCE(attendance_status, '')) = 'ABSENT')::int
        INTO v_total_records, v_present_cnt, v_absent_cnt
        FROM public.hr_training_enrollments
        WHERE program_id = p_program_id AND school_id = p_school_id;

        IF v_total_records > 0 THEN
            v_comp_rate := ROUND((v_present_cnt / v_total_records::numeric) * 100, 1);
            v_abs_rate := ROUND((v_absent_cnt / v_total_records::numeric) * 100, 1);
            v_has_records := TRUE;
        END IF;
    END IF;

    v_attendance_summary := jsonb_build_object(
        'total_records', v_total_records,
        'present_count', v_present_cnt,
        'absent_count', v_absent_cnt,
        'late_count', v_late_cnt,
        'compliance_rate', v_comp_rate,
        'absence_rate', v_abs_rate,
        'has_records', v_has_records
    );

    -- 5. Build full program detail JSON
    RETURN jsonb_build_object(
        'id', v_prog.id,
        'school_id', v_prog.school_id,
        'program_code', v_prog.program_code,
        'title', v_prog.title,
        'category_id', v_prog.category_id,
        'category_name', v_prog.category_name,
        'training_type', v_prog.training_type,
        'description', v_prog.description,
        'is_mandatory', v_prog.is_mandatory,
        'trainer_type', v_prog.trainer_type,
        'trainer_name', v_prog.trainer_name,
        'provider_name', v_prog.provider_name,
        'target_audience', v_prog.target_audience,
        'target_departments', v_prog.target_departments,
        'target_designations', v_prog.target_designations,
        'mode', v_prog.mode,
        'location_or_link', v_prog.location_or_link,
        'start_date', v_prog.start_date::text,
        'end_date', v_prog.end_date::text,
        'start_time', v_prog.start_time::text,
        'end_time', v_prog.end_time::text,
        'duration_hours', v_prog.duration_hours,
        'duration_display', v_prog.duration_display,
        'capacity', v_prog.capacity,
        'enrolled_count', v_prog.enrolled_count,
        'completed_count', v_prog.completed_count,
        'completion_rate', v_prog.completion_rate,
        'assessment_type', COALESCE(v_prog.assessment_type, 'None'),
        'passing_score', COALESCE(v_prog.passing_score, 70.0),
        'has_certificate', v_prog.has_certificate,
        'certificate_validity_type', v_prog.certificate_validity_type,
        'certificate_validity_months', v_prog.certificate_validity_months,
        'budget_cost', v_prog.budget_cost,
        'budget_category', v_prog.budget_category,
        'status', v_prog.status,
        'notes', v_prog.notes,
        'created_at', v_prog.created_at::text,
        'updated_at', v_prog.updated_at::text,
        'sessions', v_sessions,
        'materials', v_materials,
        'attendance_summary', v_attendance_summary
    );
END;
$$;


-- ============================================================================
-- 2. ASSESSMENT & EVALUATION STORED PROCEDURES & FUNCTIONS
-- ============================================================================

-- 2.1 Get Assessment Tab Data (Real Dynamic KPIs and Participant Roster)
CREATE OR REPLACE FUNCTION public.fn_hr_training_get_assessment_data(
    p_program_id UUID,
    p_school_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_prog RECORD;
    v_total_enrolled INT := 0;
    v_passed_cnt INT := 0;
    v_failed_cnt INT := 0;
    v_pending_cnt INT := 0;
    v_avg_score NUMERIC(5,1) := 0.0;
    v_passing_score NUMERIC(5,1) := 70.0;
    v_participants JSONB;
BEGIN
    SELECT assessment_type, passing_score INTO v_prog
    FROM public.hr_training_programs
    WHERE id = p_program_id AND school_id = p_school_id;

    IF FOUND AND v_prog.passing_score IS NOT NULL THEN
        v_passing_score := v_prog.passing_score;
    END IF;

    -- Aggregate participants assessment statistics
    SELECT 
        COUNT(*)::int,
        COUNT(*) FILTER (WHERE UPPER(COALESCE(assessment_status, '')) = 'PASSED')::int,
        COUNT(*) FILTER (WHERE UPPER(COALESCE(assessment_status, '')) = 'FAILED')::int,
        COUNT(*) FILTER (WHERE UPPER(COALESCE(assessment_status, '')) NOT IN ('PASSED', 'FAILED'))::int,
        COALESCE(ROUND(AVG(assessment_score) FILTER (WHERE assessment_score IS NOT NULL), 1), 0.0)
    INTO v_total_enrolled, v_passed_cnt, v_failed_cnt, v_pending_cnt, v_avg_score
    FROM public.hr_training_enrollments
    WHERE program_id = p_program_id AND school_id = p_school_id;

    -- Fetch participants list
    SELECT COALESCE(jsonb_agg(to_jsonb(p_obj) ORDER BY p_obj.employee_name ASC), '[]'::jsonb)
    INTO v_participants
    FROM (
        SELECT 
            e.id as enrollment_id,
            e.employee_id,
            COALESCE(p.full_name, e.employee_name, 'Staff Member') as employee_name,
            COALESCE(p.employee_id, e.employee_code, 'Emp' || SUBSTRING(e.employee_id::text, 1, 4)) as employee_code,
            COALESCE(p.department, e.department, 'Academics') as department,
            COALESCE(p.designation, e.designation, 'Staff') as designation,
            COALESCE(p.avatar_url, '') as avatar_url,
            e.status,
            e.progress_percentage,
            e.attendance_status,
            e.assessment_status,
            e.assessment_score,
            e.certificate_status,
            e.is_mandatory,
            e.enrolled_at::text as enrolled_at,
            e.completed_at::text as completed_at
        FROM public.hr_training_enrollments e
        LEFT JOIN public.profiles p ON p.id = e.employee_id
        WHERE e.program_id = p_program_id AND e.school_id = p_school_id
    ) p_obj;

    RETURN jsonb_build_object(
        'kpis', jsonb_build_object(
            'assessment_type', COALESCE(v_prog.assessment_type, 'None'),
            'passing_score', v_passing_score,
            'total_participants', v_total_enrolled,
            'passed_count', v_passed_cnt,
            'failed_count', v_failed_cnt,
            'pending_count', v_pending_cnt,
            'average_score', v_avg_score
        ),
        'participants', v_participants
    );
END;
$$;


-- 2.2 Configure Assessment Settings Procedure
CREATE OR REPLACE FUNCTION public.fn_hr_training_update_assessment_settings(
    p_program_id UUID,
    p_school_id UUID,
    p_assessment_type TEXT,
    p_passing_score NUMERIC,
    p_user_id UUID DEFAULT NULL,
    p_user_name TEXT DEFAULT 'Admin'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_updated RECORD;
BEGIN
    UPDATE public.hr_training_programs
    SET assessment_type = p_assessment_type,
        passing_score = p_passing_score,
        updated_at = NOW()
    WHERE id = p_program_id AND school_id = p_school_id
    RETURNING id, title, assessment_type, passing_score INTO v_updated;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Training program not found.');
    END IF;

    -- Audit activity
    INSERT INTO public.hr_training_activity (
        school_id, entity_type, entity_id, action, summary, performed_by, performer_name, performer_role, created_at
    ) VALUES (
        p_school_id, 'training_program', p_program_id::text, 'ASSESSMENT_SETTINGS_UPDATED',
        'Configured assessment: ' || p_assessment_type || ' (Passing threshold: ' || p_passing_score::text || '%)',
        p_user_id, p_user_name, 'Admin', NOW()
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Assessment settings updated successfully.',
        'data', row_to_json(v_updated)
    );
END;
$$;


-- 2.3 Record Participant Assessment Score Procedure
CREATE OR REPLACE FUNCTION public.fn_hr_training_record_score(
    p_program_id UUID,
    p_enrollment_id UUID,
    p_school_id UUID,
    p_score NUMERIC,
    p_status TEXT,
    p_progress NUMERIC DEFAULT NULL,
    p_user_id UUID DEFAULT NULL,
    p_user_name TEXT DEFAULT 'Admin'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_enr RECORD;
    v_new_prog NUMERIC(5,2);
    v_new_status TEXT;
    v_updated RECORD;
    v_enrolled_cnt INT;
    v_completed_cnt INT;
    v_comp_rate NUMERIC(5,1);
BEGIN
    SELECT * INTO v_enr
    FROM public.hr_training_enrollments
    WHERE id = p_enrollment_id AND program_id = p_program_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Participant enrollment not found.');
    END IF;

    v_new_prog := COALESCE(p_progress, CASE WHEN UPPER(p_status) = 'PASSED' THEN 100.0 ELSE COALESCE(v_enr.progress_percentage, 0.0) END);
    v_new_status := CASE WHEN UPPER(p_status) = 'PASSED' THEN 'COMPLETED' ELSE v_enr.status END;

    UPDATE public.hr_training_enrollments
    SET assessment_score = p_score,
        assessment_status = UPPER(p_status),
        progress_percentage = v_new_prog,
        status = v_new_status,
        completed_at = CASE WHEN UPPER(p_status) = 'PASSED' THEN NOW() ELSE completed_at END,
        updated_at = NOW()
    WHERE id = p_enrollment_id AND program_id = p_program_id AND school_id = p_school_id
    RETURNING id, employee_name, assessment_score, assessment_status, status, progress_percentage INTO v_updated;

    -- Recalculate program completed_count and completion_rate
    SELECT COUNT(*)::int, COUNT(*) FILTER (WHERE status = 'COMPLETED')::int
    INTO v_enrolled_cnt, v_completed_cnt
    FROM public.hr_training_enrollments
    WHERE program_id = p_program_id AND school_id = p_school_id;

    v_comp_rate := CASE WHEN v_enrolled_cnt > 0 THEN ROUND((v_completed_cnt::numeric / v_enrolled_cnt::numeric) * 100, 1) ELSE 0.0 END;

    UPDATE public.hr_training_programs
    SET completed_count = v_completed_cnt,
        completion_rate = v_comp_rate,
        updated_at = NOW()
    WHERE id = p_program_id AND school_id = p_school_id;

    -- Audit log
    INSERT INTO public.hr_training_activity (
        school_id, entity_type, entity_id, action, summary, performed_by, performer_name, performer_role, created_at
    ) VALUES (
        p_school_id, 'training_program', p_program_id::text, 'ASSESSMENT_RECORDED',
        'Recorded assessment for ' || v_enr.employee_name || ': ' || UPPER(p_status) || ' (' || p_score::text || '%)',
        p_user_id, p_user_name, 'Admin', NOW()
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Assessment recorded for ' || v_enr.employee_name || '.',
        'data', row_to_json(v_updated)
    );
END;
$$;


-- 2.4 Bulk Evaluate Assessment Procedure
CREATE OR REPLACE FUNCTION public.fn_hr_training_bulk_evaluate(
    p_program_id UUID,
    p_school_id UUID,
    p_score NUMERIC,
    p_status TEXT,
    p_enrollment_ids UUID[] DEFAULT NULL,
    p_user_id UUID DEFAULT NULL,
    p_user_name TEXT DEFAULT 'Admin'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_affected_cnt INT := 0;
    v_enrolled_cnt INT;
    v_completed_cnt INT;
    v_comp_rate NUMERIC(5,1);
    v_status_clean TEXT := UPPER(p_status);
BEGIN
    IF p_enrollment_ids IS NOT NULL AND array_length(p_enrollment_ids, 1) > 0 THEN
        UPDATE public.hr_training_enrollments
        SET assessment_score = p_score,
            assessment_status = v_status_clean,
            progress_percentage = CASE WHEN v_status_clean = 'PASSED' THEN 100.0 ELSE progress_percentage END,
            status = CASE WHEN v_status_clean = 'PASSED' THEN 'COMPLETED' ELSE status END,
            completed_at = CASE WHEN v_status_clean = 'PASSED' THEN NOW() ELSE completed_at END,
            updated_at = NOW()
        WHERE program_id = p_program_id AND school_id = p_school_id AND id = ANY(p_enrollment_ids);
        GET DIAGNOSTICS v_affected_cnt = ROW_COUNT;
    ELSE
        UPDATE public.hr_training_enrollments
        SET assessment_score = p_score,
            assessment_status = v_status_clean,
            progress_percentage = CASE WHEN v_status_clean = 'PASSED' THEN 100.0 ELSE progress_percentage END,
            status = CASE WHEN v_status_clean = 'PASSED' THEN 'COMPLETED' ELSE status END,
            completed_at = CASE WHEN v_status_clean = 'PASSED' THEN NOW() ELSE completed_at END,
            updated_at = NOW()
        WHERE program_id = p_program_id AND school_id = p_school_id;
        GET DIAGNOSTICS v_affected_cnt = ROW_COUNT;
    END IF;

    -- Recalculate program completed_count and completion_rate
    SELECT COUNT(*)::int, COUNT(*) FILTER (WHERE status = 'COMPLETED')::int
    INTO v_enrolled_cnt, v_completed_cnt
    FROM public.hr_training_enrollments
    WHERE program_id = p_program_id AND school_id = p_school_id;

    v_comp_rate := CASE WHEN v_enrolled_cnt > 0 THEN ROUND((v_completed_cnt::numeric / v_enrolled_cnt::numeric) * 100, 1) ELSE 0.0 END;

    UPDATE public.hr_training_programs
    SET completed_count = v_completed_cnt,
        completion_rate = v_comp_rate,
        updated_at = NOW()
    WHERE id = p_program_id AND school_id = p_school_id;

    -- Audit log
    INSERT INTO public.hr_training_activity (
        school_id, entity_type, entity_id, action, summary, performed_by, performer_name, performer_role, created_at
    ) VALUES (
        p_school_id, 'training_program', p_program_id::text, 'BULK_ASSESSMENT_RECORDED',
        'Bulk evaluated ' || v_affected_cnt::text || ' participants with status ' || v_status_clean || ' (' || p_score::text || '%)',
        p_user_id, p_user_name, 'Admin', NOW()
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Bulk assessment recorded for ' || v_affected_cnt::text || ' participants.',
        'affected_count', v_affected_cnt
    );
END;
$$;


-- ============================================================================
-- 3. CERTIFICATE MANAGEMENT STORED PROCEDURES & FUNCTIONS
-- ============================================================================

-- 3.1 Get Certificates Tab Data with Real KPIs
CREATE OR REPLACE FUNCTION public.fn_hr_training_get_certificates(
    p_program_id UUID,
    p_school_id UUID,
    p_status TEXT DEFAULT NULL,
    p_search TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_issued INT := 0;
    v_valid_cnt INT := 0;
    v_expiring_cnt INT := 0;
    v_expired_revoked_cnt INT := 0;
    v_eligible_cnt INT := 0;
    v_certs JSONB;
BEGIN
    -- Aggregate certificate KPIs for this program (or school-wide if program_id is NULL)
    SELECT 
        COUNT(*)::int,
        COUNT(*) FILTER (WHERE UPPER(c.status) = 'VALID')::int,
        COUNT(*) FILTER (WHERE UPPER(c.status) = 'EXPIRING_SOON')::int,
        COUNT(*) FILTER (WHERE UPPER(c.status) IN ('EXPIRED', 'REVOKED'))::int
    INTO v_total_issued, v_valid_cnt, v_expiring_cnt, v_expired_revoked_cnt
    FROM public.hr_training_certificates c
    WHERE c.school_id = p_school_id
      AND (p_program_id IS NULL OR c.program_id = p_program_id);

    -- Eligible count: participants with status 'COMPLETED' or assessment_status 'PASSED' who have no certificate yet
    IF p_program_id IS NOT NULL THEN
        SELECT COUNT(*)::int INTO v_eligible_cnt
        FROM public.hr_training_enrollments e
        WHERE e.program_id = p_program_id 
          AND e.school_id = p_school_id
          AND (UPPER(e.status) = 'COMPLETED' OR UPPER(COALESCE(e.assessment_status, '')) = 'PASSED')
          AND NOT EXISTS (
              SELECT 1 FROM public.hr_training_certificates c
              WHERE c.program_id = e.program_id 
                AND c.employee_id = e.employee_id 
                AND c.school_id = e.school_id
                AND UPPER(c.status) = 'VALID'
          );
    END IF;

    -- Fetch certificates list
    SELECT COALESCE(jsonb_agg(to_jsonb(c_obj) ORDER BY c_obj.issue_date DESC), '[]'::jsonb)
    INTO v_certs
    FROM (
        SELECT 
            c.id,
            c.certificate_number,
            c.issue_date::text as issue_date,
            c.expiry_date::text as expiry_date,
            c.status,
            c.certificate_url as download_url,
            c.employee_id,
            COALESCE(p.full_name, c.employee_name, 'Staff Member') as employee_name,
            COALESCE(p.employee_id, 'Emp' || SUBSTRING(c.employee_id::text, 1, 4)) as employee_code,
            COALESCE(p.department, 'Academics') as department,
            tp.id as program_id,
            tp.title as program_title,
            tp.category_name
        FROM public.hr_training_certificates c
        LEFT JOIN public.profiles p ON p.id = c.employee_id
        JOIN public.hr_training_programs tp ON tp.id = c.program_id
        WHERE c.school_id = p_school_id
          AND (p_program_id IS NULL OR c.program_id = p_program_id)
          AND (p_status IS NULL OR UPPER(c.status) = UPPER(p_status))
          AND (
              p_search IS NULL OR p_search = '' OR
              p.full_name ILIKE '%' || p_search || '%' OR
              c.employee_name ILIKE '%' || p_search || '%' OR
              c.certificate_number ILIKE '%' || p_search || '%' OR
              tp.title ILIKE '%' || p_search || '%'
          )
    ) c_obj;

    RETURN jsonb_build_object(
        'kpis', jsonb_build_object(
            'total_issued', v_total_issued,
            'valid_count', v_valid_cnt,
            'expiring_count', v_expiring_cnt,
            'expired_revoked_count', v_expired_revoked_cnt,
            'eligible_to_issue', v_eligible_cnt
        ),
        'certificates', v_certs
    );
END;
$$;


-- 3.2 Issue / Generate Certificate Procedure
CREATE OR REPLACE FUNCTION public.fn_hr_training_issue_certificate(
    p_program_id UUID,
    p_employee_id UUID,
    p_school_id UUID,
    p_certificate_number TEXT DEFAULT NULL,
    p_validity_months INT DEFAULT 12,
    p_user_id UUID DEFAULT NULL,
    p_user_name TEXT DEFAULT 'Admin'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_emp_name TEXT;
    v_prog_title TEXT;
    v_cert_no TEXT;
    v_expiry DATE;
    v_cert RECORD;
BEGIN
    SELECT full_name INTO v_emp_name FROM public.profiles WHERE id = p_employee_id;
    v_emp_name := COALESCE(v_emp_name, 'Staff Member');

    SELECT title INTO v_prog_title FROM public.hr_training_programs WHERE id = p_program_id;
    v_prog_title := COALESCE(v_prog_title, 'Training Program');

    v_cert_no := COALESCE(p_certificate_number, 'CERT-TRN-' || UPPER(SUBSTRING(gen_random_uuid()::text, 1, 8)));
    v_expiry := CURRENT_DATE + (p_validity_months * 30);

    INSERT INTO public.hr_training_certificates (
        school_id, program_id, employee_id, employee_name, program_title, certificate_number, issue_date, expiry_date,
        status, issued_by
    ) VALUES (
        p_school_id, p_program_id, p_employee_id, v_emp_name, v_prog_title, v_cert_no, CURRENT_DATE, v_expiry, 'VALID', p_user_id
    )
    ON CONFLICT (program_id, employee_id)
    DO UPDATE SET
        certificate_number = EXCLUDED.certificate_number,
        issue_date = CURRENT_DATE,
        expiry_date = EXCLUDED.expiry_date,
        status = 'VALID',
        issued_by = EXCLUDED.issued_by
    RETURNING id, certificate_number, issue_date, expiry_date, status INTO v_cert;

    -- Update enrollment record
    UPDATE public.hr_training_enrollments
    SET certificate_status = 'ISSUED',
        certificate_id = v_cert.id,
        status = 'COMPLETED',
        progress_percentage = 100.0,
        completed_at = NOW(),
        updated_at = NOW()
    WHERE program_id = p_program_id AND employee_id = p_employee_id AND school_id = p_school_id;

    -- Audit log
    INSERT INTO public.hr_training_activity (
        school_id, entity_type, entity_id, action, summary, performed_by, performer_name, performer_role, created_at
    ) VALUES (
        p_school_id, 'certificate', v_cert.id::text, 'CERTIFICATE_ISSUED',
        'Issued Certificate ' || v_cert_no || ' to ' || v_emp_name || ' for ' || v_prog_title,
        p_user_id, p_user_name, 'Admin', NOW()
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Certificate issued successfully.',
        'data', row_to_json(v_cert)
    );
END;
$$;


-- 3.3 Revoke Certificate Procedure
CREATE OR REPLACE FUNCTION public.fn_hr_training_revoke_certificate(
    p_certificate_id UUID,
    p_school_id UUID,
    p_user_id UUID DEFAULT NULL,
    p_user_name TEXT DEFAULT 'Admin'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_cert RECORD;
BEGIN
    UPDATE public.hr_training_certificates
    SET status = 'EXPIRED',
        updated_at = NOW()
    WHERE id = p_certificate_id AND school_id = p_school_id
    RETURNING id, certificate_number, employee_id, program_id INTO v_cert;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Certificate not found.');
    END IF;

    -- Update enrollment
    UPDATE public.hr_training_enrollments
    SET certificate_status = 'EXPIRED',
        updated_at = NOW()
    WHERE program_id = v_cert.program_id AND employee_id = v_cert.employee_id AND school_id = p_school_id;

    -- Audit log
    INSERT INTO public.hr_training_activity (
        school_id, entity_type, entity_id, action, summary, performed_by, performer_name, performer_role, created_at
    ) VALUES (
        p_school_id, 'certificate', p_certificate_id::text, 'CERTIFICATE_REVOKED',
        'Revoked Certificate ' || v_cert.certificate_number,
        p_user_id, p_user_name, 'Admin', NOW()
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Certificate status updated to revoked/expired.'
    );
END;
$$;


-- 3.4 Get Certificate Details for PDF Rendering
CREATE OR REPLACE FUNCTION public.fn_hr_training_get_certificate_pdf_data(
    p_certificate_id UUID,
    p_school_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_res RECORD;
BEGIN
    SELECT 
        c.id, 
        c.certificate_number, 
        c.issue_date::text as issue_date, 
        c.expiry_date::text as expiry_date, 
        c.status,
        c.employee_name, 
        c.program_title, 
        c.employee_id, 
        c.program_id,
        s.name as school_name, 
        p.title as program_name, 
        p.duration_display,
        prof.employee_id as employee_code, 
        prof.department
    INTO v_res
    FROM public.hr_training_certificates c
    JOIN public.schools s ON s.id = c.school_id
    LEFT JOIN public.hr_training_programs p ON p.id = c.program_id
    LEFT JOIN public.profiles prof ON prof.id = c.employee_id
    WHERE c.id = p_certificate_id AND c.school_id = p_school_id;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    RETURN row_to_json(v_res);
END;
$$;


-- ============================================================================
-- 4. FEEDBACK & REVIEWS STORED PROCEDURES & FUNCTIONS
-- ============================================================================

-- 4.1 Get Program Feedback with Real Computed Metrics (0.0 when 0 reviews)
CREATE OR REPLACE FUNCTION public.fn_hr_training_get_feedback(
    p_program_id UUID,
    p_school_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_reviews JSONB;
    v_total INT := 0;
    v_avg_rating NUMERIC(5,1) := 0.0;
    v_avg_trainer NUMERIC(5,1) := 0.0;
    v_avg_content NUMERIC(5,1) := 0.0;
    v_star_5 INT := 0;
    v_star_4 INT := 0;
    v_star_3 INT := 0;
    v_star_2 INT := 0;
    v_star_1 INT := 0;
BEGIN
    SELECT COALESCE(jsonb_agg(to_jsonb(r_obj) ORDER BY r_obj.created_at DESC), '[]'::jsonb)
    INTO v_reviews
    FROM (
        SELECT 
            id,
            program_id,
            employee_id,
            employee_name,
            rating,
            trainer_rating,
            content_rating,
            feedback_text,
            created_at::text as created_at
        FROM public.hr_training_feedback
        WHERE program_id = p_program_id AND school_id = p_school_id
    ) r_obj;

    SELECT 
        COUNT(*)::int,
        COALESCE(ROUND(AVG(rating), 1), 0.0),
        COALESCE(ROUND(AVG(trainer_rating), 1), 0.0),
        COALESCE(ROUND(AVG(content_rating), 1), 0.0),
        COUNT(*) FILTER (WHERE rating = 5)::int,
        COUNT(*) FILTER (WHERE rating = 4)::int,
        COUNT(*) FILTER (WHERE rating = 3)::int,
        COUNT(*) FILTER (WHERE rating = 2)::int,
        COUNT(*) FILTER (WHERE rating = 1)::int
    INTO v_total, v_avg_rating, v_avg_trainer, v_avg_content,
         v_star_5, v_star_4, v_star_3, v_star_2, v_star_1
    FROM public.hr_training_feedback
    WHERE program_id = p_program_id AND school_id = p_school_id;

    RETURN jsonb_build_object(
        'reviews', v_reviews,
        'total_reviews', v_total,
        'avg_rating', v_avg_rating,
        'avg_trainer_rating', v_avg_trainer,
        'avg_content_rating', v_avg_content,
        'star_counts', jsonb_build_object(
            '5', v_star_5,
            '4', v_star_4,
            '3', v_star_3,
            '2', v_star_2,
            '1', v_star_1
        )
    );
END;
$$;


-- 4.2 Submit Feedback Procedure
CREATE OR REPLACE FUNCTION public.fn_hr_training_submit_feedback(
    p_program_id UUID,
    p_school_id UUID,
    p_employee_id UUID,
    p_employee_name TEXT,
    p_rating INT,
    p_trainer_rating INT,
    p_content_rating INT,
    p_feedback_text TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_created RECORD;
BEGIN
    INSERT INTO public.hr_training_feedback (
        school_id, program_id, employee_id, employee_name, rating, trainer_rating, content_rating, feedback_text, created_at
    ) VALUES (
        p_school_id, p_program_id, p_employee_id, p_employee_name, p_rating, p_trainer_rating, p_content_rating, p_feedback_text, NOW()
    )
    RETURNING id, program_id, employee_name, rating, created_at::text as created_at INTO v_created;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Feedback submitted successfully.',
        'data', row_to_json(v_created)
    );
END;
$$;


-- ============================================================================
-- 5. ATTENDANCE & PARTICIPANTS STORED PROCEDURES
-- ============================================================================

-- 5.1 Bulk Record Session Attendance Procedure
CREATE OR REPLACE FUNCTION public.fn_hr_training_record_session_attendance(
    p_session_id UUID,
    p_school_id UUID,
    p_records JSONB,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    rec JSONB;
    v_enr_id UUID;
    v_emp_id UUID;
    v_att_status TEXT;
    v_remarks TEXT;
    v_count INT := 0;
BEGIN
    FOR rec IN SELECT * FROM jsonb_array_elements(p_records)
    LOOP
        v_enr_id := (rec->>'enrollment_id')::UUID;
        v_att_status := UPPER(COALESCE(rec->>'attendance_status', 'PRESENT'));
        v_remarks := rec->>'remarks';

        SELECT employee_id INTO v_emp_id FROM public.hr_training_enrollments WHERE id = v_enr_id;

        INSERT INTO public.hr_training_attendance (
            school_id, session_id, enrollment_id, employee_id, status, attendance_status, recorded_by, recorded_at, remarks
        ) VALUES (
            p_school_id, p_session_id, v_enr_id, v_emp_id, INITCAP(v_att_status), v_att_status, p_user_id, NOW(), v_remarks
        )
        ON CONFLICT (session_id, enrollment_id)
        DO UPDATE SET
            status = EXCLUDED.status,
            attendance_status = EXCLUDED.attendance_status,
            recorded_by = EXCLUDED.recorded_by,
            recorded_at = NOW(),
            remarks = EXCLUDED.remarks;

        -- Update enrollment attendance_status
        UPDATE public.hr_training_enrollments
        SET attendance_status = v_att_status,
            status = CASE WHEN v_att_status = 'PRESENT' AND status = 'ASSIGNED' THEN 'IN_PROGRESS' ELSE status END,
            updated_at = NOW()
        WHERE id = v_enr_id AND school_id = p_school_id;

        v_count := v_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Updated attendance for ' || v_count::text || ' participant(s).',
        'updated_count', v_count
    );
END;
$$;


-- 5.2 Bulk Assign Participants Procedure
CREATE OR REPLACE FUNCTION public.fn_hr_training_assign_participants(
    p_program_id UUID,
    p_school_id UUID,
    p_employee_ids UUID[],
    p_is_mandatory BOOLEAN DEFAULT FALSE,
    p_assigned_by UUID DEFAULT NULL,
    p_user_name TEXT DEFAULT 'Admin'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_emp_id UUID;
    v_p RECORD;
    v_count INT := 0;
    v_prog_title TEXT;
BEGIN
    SELECT title INTO v_prog_title FROM public.hr_training_programs WHERE id = p_program_id AND school_id = p_school_id;

    FOREACH v_emp_id IN ARRAY p_employee_ids
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM public.hr_training_enrollments 
            WHERE program_id = p_program_id AND employee_id = v_emp_id AND school_id = p_school_id
        ) THEN
            SELECT full_name, employee_id as emp_code, department, designation
            INTO v_p
            FROM public.profiles
            WHERE id = v_emp_id;

            INSERT INTO public.hr_training_enrollments (
                school_id, program_id, employee_id, employee_name, employee_code, department, designation,
                status, progress_percentage, is_mandatory, enrolled_at
            ) VALUES (
                p_school_id, p_program_id, v_emp_id,
                COALESCE(v_p.full_name, 'Staff Member'),
                COALESCE(v_p.emp_code, 'Emp' || SUBSTRING(v_emp_id::text, 1, 4)),
                COALESCE(v_p.department, 'Academics'),
                COALESCE(v_p.designation, 'Staff'),
                'ASSIGNED', 0.0, p_is_mandatory, NOW()
            );

            v_count := v_count + 1;
        END IF;
    END LOOP;

    -- Update enrolled_count on program
    UPDATE public.hr_training_programs
    SET enrolled_count = (SELECT COUNT(*) FROM public.hr_training_enrollments WHERE program_id = p_program_id AND school_id = p_school_id),
        updated_at = NOW()
    WHERE id = p_program_id AND school_id = p_school_id;

    -- Audit activity
    IF v_count > 0 THEN
        INSERT INTO public.hr_training_activity (
            school_id, entity_type, entity_id, action, summary, performed_by, performer_name, performer_role, created_at
        ) VALUES (
            p_school_id, 'training_program', p_program_id::text, 'PARTICIPANTS_ASSIGNED',
            'Assigned ' || v_count::text || ' employee(s) to ' || COALESCE(v_prog_title, 'Training Program'),
            p_assigned_by, p_user_name, 'Admin', NOW()
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Successfully assigned ' || v_count::text || ' employee(s).',
        'assigned_count', v_count
    );
END;
$$;
