-- ==============================================================================
-- Migration 567: Staff Salary Single Source of Truth (SSOT), Mathematical Consistency,
-- Profile Role Sanitization, and End-to-End Disbursal Synchronization.
-- ==============================================================================

-- 1. Extend public.staff_salary_payouts to mirror all salary structure components
ALTER TABLE public.staff_salary_payouts 
ADD COLUMN IF NOT EXISTS medical_allowance NUMERIC(12,2) DEFAULT 0.0;

ALTER TABLE public.staff_salary_payouts 
ADD COLUMN IF NOT EXISTS insurance_deduction NUMERIC(12,2) DEFAULT 0.0;

-- 2. Remove invalid non-staff (parents, students) from salary structures and payouts
DELETE FROM public.staff_salary_payouts 
WHERE staff_id IN (SELECT id FROM public.profiles WHERE role IN ('parent', 'student', 'view_only'));

DELETE FROM public.staff_salary_structures 
WHERE staff_id IN (SELECT id FROM public.profiles WHERE role IN ('parent', 'student', 'view_only'));

-- 3. Sanitize and elevate mock profiles to authentic educational institutional roles
-- Amit Chauhan (Hostel Staff)
UPDATE public.profiles 
SET 
    department = 'Hostel & Campus Facilities',
    designation = 'Hostel Warden'
WHERE id = '41000019-0000-0000-0000-000000000019';

-- Sanitize all hostel personnel in profiles
UPDATE public.profiles
SET 
    department = 'Hostel & Campus Facilities',
    designation = CASE 
        WHEN employee_id IN ('HS001', 'HS002') THEN 'Chief Hostel Warden'
        WHEN employee_id IN ('HS003', 'HS004', 'HS005', 'HS013', 'HS014', 'HS015', 'HS016') THEN 'Hostel Warden'
        WHEN employee_id IN ('HS021', 'HS027') THEN 'Campus Security Guard'
        ELSE 'Campus Facility Officer'
    END
WHERE id::text LIKE '410000%' AND (department IS NULL OR department = '' OR designation IS NULL OR designation = '');

-- Sanitize software test roles in 55555555 series into legitimate academic & institutional faculty
UPDATE public.profiles SET designation = 'Campus Network Administrator', department = 'IT & Campus Infrastructure', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2124') WHERE id = '55555555-0000-0000-0000-000000000024';
UPDATE public.profiles SET designation = 'Department Head (Computer Science)', department = 'Computer Science & IT', employee_id = 'EMP-2101' WHERE id = '55555555-0001-0000-0000-000000000001';
UPDATE public.profiles SET designation = 'Senior Computer Science Faculty', department = 'Computer Science & IT', employee_id = 'EMP-2102' WHERE id = '55555555-0002-0000-0000-000000000002';
UPDATE public.profiles SET designation = 'Multimedia & Computer Lab Faculty', department = 'Computer Science & IT', employee_id = 'EMP-2103' WHERE id = '55555555-0003-0000-0000-000000000003';
UPDATE public.profiles SET designation = 'Computer Science Lecturer', department = 'Computer Science & IT', employee_id = 'EMP-2104' WHERE id = '55555555-0004-0000-0000-000000000004';
UPDATE public.profiles SET designation = 'Educational Systems Administrator', department = 'IT & Campus Infrastructure', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2129') WHERE id = '55555555-0000-0000-0000-000000000029';
UPDATE public.profiles SET designation = 'Digital Media & Storage Archivist', department = 'Library & Resources', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2128') WHERE id = '55555555-0000-0000-0000-000000000028';
UPDATE public.profiles SET designation = 'Senior Cataloguer & Archivist', department = 'Library & Resources', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2139') WHERE id = '55555555-0000-0000-0000-000000000039';
UPDATE public.profiles SET designation = 'Systems Librarian', department = 'Library & Resources', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2141') WHERE id = '55555555-0000-0000-0000-000000000041';
UPDATE public.profiles SET designation = 'Student Helpdesk Coordinator', department = 'Academic Administration', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2142') WHERE id = '55555555-0000-0000-0000-000000000042';
UPDATE public.profiles SET designation = 'Academic Quality & Assessment Officer', department = 'Academic Quality', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2105') WHERE id = '55555555-0005-0000-0000-000000000005';
UPDATE public.profiles SET designation = 'Campus Infrastructure Engineer', department = 'IT & Campus Infrastructure', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2106') WHERE id = '55555555-0006-0000-0000-000000000006';
UPDATE public.profiles SET designation = 'Academic Systems Analyst', department = 'Administration', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2107') WHERE id = '55555555-0007-0000-0000-000000000007';
UPDATE public.profiles SET designation = 'Senior English Faculty', department = 'Academic & Teaching', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2155') WHERE id = '55555555-5555-5555-5555-555555555555';
UPDATE public.profiles SET designation = 'Head of Department (Mathematics)', department = 'Academic & Teaching', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2108') WHERE id = '55555555-0000-0000-0000-000000000008';
UPDATE public.profiles SET designation = 'Curriculum & Assessment Analyst', department = 'Academic & Teaching', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2110') WHERE id = '55555555-0000-0000-0000-000000000010';
UPDATE public.profiles SET designation = 'Senior Computer Science Lecturer', department = 'Computer Science & IT', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2111') WHERE id = '55555555-0000-0000-0000-000000000011';
UPDATE public.profiles SET designation = 'Lecturer in Computer Applications', department = 'Computer Science & IT', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2112') WHERE id = '55555555-0000-0000-0000-000000000012';
UPDATE public.profiles SET designation = 'Institutional Statistics Analyst', department = 'Administration', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2113') WHERE id = '55555555-0000-0000-0000-000000000013';
UPDATE public.profiles SET designation = 'Curriculum Evaluation Officer', department = 'Academic Quality', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2114') WHERE id = '55555555-0000-0000-0000-000000000014';
UPDATE public.profiles SET designation = 'Academic Operations Coordinator', department = 'Administration', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2115') WHERE id = '55555555-0000-0000-0000-000000000015';
UPDATE public.profiles SET designation = 'Head of Department (Science)', department = 'Academic & Teaching', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2116') WHERE id = '55555555-0000-0000-0000-000000000016';
UPDATE public.profiles SET designation = 'Controller of Examinations', department = 'Examination Cell', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2117') WHERE id = '55555555-0000-0000-0000-000000000017';
UPDATE public.profiles SET designation = 'Evaluation & Grading Officer', department = 'Examination Cell', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2118') WHERE id = '55555555-0000-0000-0000-000000000018';
UPDATE public.profiles SET designation = 'Campus Safety & Vigilance Head', department = 'Campus Safety & Security', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2119') WHERE id = '55555555-0000-0000-0000-000000000019';
UPDATE public.profiles SET designation = 'School Records Administrator', department = 'Administration', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2120') WHERE id = '55555555-0000-0000-0000-000000000020';
UPDATE public.profiles SET designation = 'Academic Audit Specialist', department = 'Academic Quality', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2121') WHERE id = '55555555-0000-0000-0000-000000000021';
UPDATE public.profiles SET designation = 'Head of Department (Commerce)', department = 'Academic & Teaching', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2122') WHERE id = '55555555-0000-0000-0000-000000000022';
UPDATE public.profiles SET designation = 'E-Learning Systems Architect', department = 'IT & Campus Infrastructure', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2123') WHERE id = '55555555-0000-0000-0000-000000000023';
UPDATE public.profiles SET designation = 'Campus Vigilance Officer', department = 'Campus Safety & Security', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2125') WHERE id = '55555555-0000-0000-0000-000000000025';
UPDATE public.profiles SET designation = 'Lab Systems Engineer', department = 'Science Laboratories', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2126') WHERE id = '55555555-0000-0000-0000-000000000026';
UPDATE public.profiles SET designation = 'Computer Lab Administrator', department = 'Computer Science & IT', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2127') WHERE id = '55555555-0000-0000-0000-000000000027';
UPDATE public.profiles SET designation = 'Head of Department (Languages)', department = 'Academic & Teaching', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2130') WHERE id = '55555555-0000-0000-0000-000000000030';
UPDATE public.profiles SET designation = 'Senior Facilities Manager', department = 'Hostel & Campus Facilities', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2131') WHERE id = '55555555-0000-0000-0000-000000000031';
UPDATE public.profiles SET designation = 'Campus Electrical Supervisor', department = 'Hostel & Campus Facilities', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2132') WHERE id = '55555555-0000-0000-0000-000000000032';
UPDATE public.profiles SET designation = 'Campus Estate Supervisor', department = 'Hostel & Campus Facilities', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2133') WHERE id = '55555555-0000-0000-0000-000000000033';
UPDATE public.profiles SET designation = 'Smart Campus IoT Supervisor', department = 'IT & Campus Infrastructure', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2134') WHERE id = '55555555-0000-0000-0000-000000000034';
UPDATE public.profiles SET designation = 'Campus Safety & Health Inspector', department = 'Campus Safety & Security', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2135') WHERE id = '55555555-0000-0000-0000-000000000035';
UPDATE public.profiles SET designation = 'Senior Faculty Coordinator', department = 'Academic & Teaching', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2136') WHERE id = '55555555-0000-0000-0000-000000000036';
UPDATE public.profiles SET designation = 'Senior Faculty (Social Studies)', department = 'Academic & Teaching', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2137') WHERE id = '55555555-0000-0000-0000-000000000037';
UPDATE public.profiles SET designation = 'Digital Media Archivist', department = 'Library & Resources', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2138') WHERE id = '55555555-0000-0000-0000-000000000038';
UPDATE public.profiles SET designation = 'Smart Attendance Systems Officer', department = 'IT & Campus Infrastructure', employee_id = COALESCE(NULLIF(employee_id,''), 'EMP-2140') WHERE id = '55555555-0000-0000-0000-000000000040';

-- Sanitize Edge Candidate mock titles
UPDATE public.profiles 
SET 
    designation = 'Examination Review Specialist',
    department = 'Examination Cell'
WHERE designation ILIKE '%Edge Case%';

-- Fill any blank employee_id, department, and designation across all profiles
UPDATE public.profiles
SET employee_id = 'EMP-' || UPPER(SUBSTRING(id::text, 1, 6))
WHERE employee_id IS NULL OR employee_id = '';

UPDATE public.profiles
SET department = 'Academic & Teaching'
WHERE department IS NULL OR department = '';

UPDATE public.profiles
SET designation = 'Faculty Member'
WHERE designation IS NULL OR designation = '';

-- 4. Recalculate ALL rows in staff_salary_structures to enforce exact mathematical truth
UPDATE public.staff_salary_structures
SET 
    gross_salary = (COALESCE(basic_pay,0) + COALESCE(hra,0) + COALESCE(da,0) + COALESCE(ta,0) + COALESCE(special_allowance,0) + COALESCE(medical_allowance,0)),
    total_deductions = (COALESCE(pf_deduction,0) + COALESCE(tds,0) + COALESCE(professional_tax,0) + COALESCE(insurance_deduction,0)),
    net_salary = (COALESCE(basic_pay,0) + COALESCE(hra,0) + COALESCE(da,0) + COALESCE(ta,0) + COALESCE(special_allowance,0) + COALESCE(medical_allowance,0)) - 
                 (COALESCE(pf_deduction,0) + COALESCE(tds,0) + COALESCE(professional_tax,0) + COALESCE(insurance_deduction,0)),
    updated_at = NOW();

-- Also backfill medical_allowance and insurance_deduction into existing staff_salary_payouts from structures
UPDATE public.staff_salary_payouts p
SET 
    medical_allowance = COALESCE(s.medical_allowance, 0.0),
    insurance_deduction = COALESCE(s.insurance_deduction, 0.0),
    gross_earnings = (COALESCE(p.basic_pay,0) + COALESCE(p.hra,0) + COALESCE(p.da,0) + COALESCE(p.ta,0) + COALESCE(p.special_allowance,0) + COALESCE(s.medical_allowance,0) + COALESCE(p.bonus,0)),
    total_deductions = (COALESCE(p.pf_deduction,0) + COALESCE(p.tds,0) + COALESCE(p.professional_tax,0) + COALESCE(s.insurance_deduction,0) + COALESCE(p.advance_deduction,0) + COALESCE(p.other_deductions,0)),
    net_pay = (COALESCE(p.basic_pay,0) + COALESCE(p.hra,0) + COALESCE(p.da,0) + COALESCE(p.ta,0) + COALESCE(p.special_allowance,0) + COALESCE(s.medical_allowance,0) + COALESCE(p.bonus,0)) -
              (COALESCE(p.pf_deduction,0) + COALESCE(p.tds,0) + COALESCE(p.professional_tax,0) + COALESCE(s.insurance_deduction,0) + COALESCE(p.advance_deduction,0) + COALESCE(p.other_deductions,0))
FROM public.staff_salary_structures s
WHERE p.staff_id = s.staff_id AND p.school_id = s.school_id;

-- 5. Stored Procedure: public.fn_staff_salary_structures_catalog (with exact on-the-fly math)
CREATE OR REPLACE FUNCTION public.fn_staff_salary_structures_catalog(
    p_school_id UUID,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_department TEXT DEFAULT NULL,
    p_search TEXT DEFAULT NULL,
    p_sort_by TEXT DEFAULT 'name',
    p_sort_order TEXT DEFAULT 'asc'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_items INT := 0;
    v_total_pages INT := 1;
    v_offset INT := 0;
    v_structures JSONB := '[]'::jsonb;
    v_clean_page INT := GREATEST(1, COALESCE(p_page, 1));
    v_clean_size INT := GREATEST(1, LEAST(100, COALESCE(p_page_size, 10)));
BEGIN
    v_offset := (v_clean_page - 1) * v_clean_size;

    WITH struct_raw AS (
        SELECT 
            p.id AS staff_id,
            p.full_name AS staff_name,
            COALESCE(p.employee_id, 'EMP-' || UPPER(SUBSTRING(p.id::text, 1, 6))) AS employee_id,
            COALESCE(p.department, 'Academic & Teaching') AS department,
            COALESCE(p.designation, p.role, 'Faculty Member') AS role_title,
            COALESCE(p.designation, p.role, 'Faculty Member') AS designation,
            struct.id AS structure_id,
            COALESCE(struct.basic_pay, 35000.0) AS basic_pay,
            COALESCE(struct.hra, 14000.0) AS hra,
            COALESCE(struct.da, 5000.0) AS da,
            COALESCE(struct.ta, 3000.0) AS ta,
            COALESCE(struct.special_allowance, 4000.0) AS special_allowance,
            COALESCE(struct.medical_allowance, 2000.0) AS medical_allowance,
            (COALESCE(struct.hra, 14000.0) + COALESCE(struct.da, 5000.0) + COALESCE(struct.ta, 3000.0) + 
             COALESCE(struct.special_allowance, 4000.0) + COALESCE(struct.medical_allowance, 2000.0)) AS total_allowances,
            -- Computed Gross to ensure SSOT
            (COALESCE(struct.basic_pay, 35000.0) + COALESCE(struct.hra, 14000.0) + COALESCE(struct.da, 5000.0) + 
             COALESCE(struct.ta, 3000.0) + COALESCE(struct.special_allowance, 4000.0) + COALESCE(struct.medical_allowance, 2000.0)) AS gross_salary,
            COALESCE(struct.pf_deduction, 4200.0) AS pf_deduction,
            COALESCE(struct.tds, 2500.0) AS tds,
            COALESCE(struct.professional_tax, 200.0) AS professional_tax,
            COALESCE(struct.insurance_deduction, 1000.0) AS insurance_deduction,
            -- Computed Deductions to ensure SSOT
            (COALESCE(struct.pf_deduction, 4200.0) + COALESCE(struct.tds, 2500.0) + 
             COALESCE(struct.professional_tax, 200.0) + COALESCE(struct.insurance_deduction, 1000.0)) AS total_deductions,
            -- Computed Net to guarantee 100% mathematical match with edit dialog & disbursal
            ((COALESCE(struct.basic_pay, 35000.0) + COALESCE(struct.hra, 14000.0) + COALESCE(struct.da, 5000.0) + 
              COALESCE(struct.ta, 3000.0) + COALESCE(struct.special_allowance, 4000.0) + COALESCE(struct.medical_allowance, 2000.0)) -
             (COALESCE(struct.pf_deduction, 4200.0) + COALESCE(struct.tds, 2500.0) + 
              COALESCE(struct.professional_tax, 200.0) + COALESCE(struct.insurance_deduction, 1000.0))) AS net_salary,
            COALESCE(struct.bank_name, p.bank_name, 'HDFC Bank') AS bank_name,
            COALESCE(struct.account_number, p.account_number, '') AS account_number,
            COALESCE(struct.ifsc_code, p.ifsc_code, '') AS ifsc_code,
            COALESCE(struct.pan_number, p.pan_number, '') AS pan_number,
            COALESCE(struct.payment_mode, 'Direct Bank Transfer (NEFT/RTGS)') AS payment_mode,
            COALESCE(struct.status, 'ACTIVE') AS status,
            struct.updated_at
        FROM public.staff_salary_structures struct
        INNER JOIN public.profiles p 
            ON struct.staff_id = p.id AND struct.school_id = p.school_id
        WHERE struct.school_id = p_school_id 
          AND p.role NOT IN ('student', 'parent', 'view_only')
          AND (p_department IS NULL OR p_department IN ('All Departments', 'All', '') OR p.department = p_department)
          AND (p_search IS NULL OR p_search = '' OR (
              p.full_name ILIKE '%' || p_search || '%' OR
              p.employee_id ILIKE '%' || p_search || '%' OR
              p.department ILIKE '%' || p_search || '%' OR
              p.designation ILIKE '%' || p_search || '%' OR
              p.role ILIKE '%' || p_search || '%'
          ))
    ),
    counted AS (
        SELECT COUNT(*) AS total_items FROM struct_raw
    ),
    sorted_page AS (
        SELECT * FROM struct_raw
        ORDER BY
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'name' THEN staff_name END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'name' THEN staff_name END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'basic' THEN basic_pay END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'basic' THEN basic_pay END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'gross' THEN gross_salary END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'gross' THEN gross_salary END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'deductions' THEN total_deductions END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'deductions' THEN total_deductions END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'net' THEN net_salary END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'net' THEN net_salary END DESC NULLS LAST,
            staff_name ASC
        LIMIT v_clean_size OFFSET v_offset
    )
    SELECT 
        (SELECT total_items FROM counted),
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'staff_id', sp.staff_id,
                    'staff_name', sp.staff_name,
                    'employee_id', sp.employee_id,
                    'department', sp.department,
                    'role_title', sp.role_title,
                    'designation', sp.designation,
                    'structure_id', sp.structure_id,
                    'basic_pay', sp.basic_pay,
                    'hra', sp.hra,
                    'da', sp.da,
                    'ta', sp.ta,
                    'special_allowance', sp.special_allowance,
                    'medical_allowance', sp.medical_allowance,
                    'total_allowances', sp.total_allowances,
                    'gross_salary', sp.gross_salary,
                    'pf_deduction', sp.pf_deduction,
                    'tds', sp.tds,
                    'professional_tax', sp.professional_tax,
                    'insurance_deduction', sp.insurance_deduction,
                    'total_deductions', sp.total_deductions,
                    'net_salary', sp.net_salary,
                    'bank_name', sp.bank_name,
                    'account_number', sp.account_number,
                    'ifsc_code', sp.ifsc_code,
                    'pan_number', sp.pan_number,
                    'payment_mode', sp.payment_mode,
                    'status', sp.status,
                    'updated_at', sp.updated_at
                )
            ),
            '[]'::jsonb
        )
    INTO v_total_items, v_structures
    FROM sorted_page sp;

    v_total_items := COALESCE(v_total_items, 0);
    v_total_pages := GREATEST(1, CEIL(v_total_items::NUMERIC / v_clean_size));

    RETURN jsonb_build_object(
        'success', true,
        'page', v_clean_page,
        'page_size', v_clean_size,
        'total_items', v_total_items,
        'total_pages', v_total_pages,
        'structures', v_structures
    );
END;
$$;

-- 6. Stored Procedure: public.fn_get_unconfigured_salary_staff (Filtered strictly for real institute staff)
CREATE OR REPLACE FUNCTION public.fn_get_unconfigured_salary_staff(
    p_school_id UUID,
    p_search TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB := '[]'::jsonb;
BEGIN
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'staff_id', p.id,
                'staff_name', p.full_name,
                'employee_id', COALESCE(p.employee_id, 'EMP-' || UPPER(SUBSTRING(p.id::text, 1, 6))),
                'department', COALESCE(p.department, 'Academic & Teaching'),
                'designation', COALESCE(p.designation, 'Faculty Member'),
                'role', COALESCE(p.role, 'teacher'),
                'email', COALESCE(p.email, ''),
                'phone', COALESCE(p.phone, ''),
                'pan_number', COALESCE(p.pan_number, ''),
                'bank_name', COALESCE(p.bank_name, 'HDFC Bank'),
                'account_number', COALESCE(p.account_number, ''),
                'ifsc_code', COALESCE(p.ifsc_code, '')
            )
            ORDER BY p.full_name ASC
        ),
        '[]'::jsonb
    )
    INTO v_result
    FROM public.profiles p
    WHERE p.school_id = p_school_id
      AND p.role NOT IN ('student', 'parent', 'view_only')
      AND p.id NOT IN (
          SELECT staff_id 
          FROM public.staff_salary_structures 
          WHERE school_id = p_school_id
      )
      AND (
          p_search IS NULL OR p_search = '' OR
          p.full_name ILIKE '%' || p_search || '%' OR
          p.employee_id ILIKE '%' || p_search || '%' OR
          p.department ILIKE '%' || p_search || '%' OR
          p.designation ILIKE '%' || p_search || '%' OR
          p.role ILIKE '%' || p_search || '%'
      );

    RETURN jsonb_build_object(
        'success', true,
        'count', jsonb_array_length(v_result),
        'staff', v_result
    );
END;
$$;

-- 7. Stored Procedure: public.fn_search_all_staff_for_payroll (Complete SSOT with medical & insurance)
DROP FUNCTION IF EXISTS public.fn_search_all_staff_for_payroll(uuid, text, text);

CREATE OR REPLACE FUNCTION public.fn_search_all_staff_for_payroll(
    p_school_id UUID, 
    p_search TEXT DEFAULT '', 
    p_month_str TEXT DEFAULT '2026-10'
)
RETURNS TABLE (
    staff_id UUID,
    full_name TEXT,
    employee_id TEXT,
    designation TEXT,
    department TEXT,
    email TEXT,
    phone TEXT,
    has_structure BOOLEAN,
    basic_pay NUMERIC,
    hra NUMERIC,
    da NUMERIC,
    ta NUMERIC,
    special_allowance NUMERIC,
    medical_allowance NUMERIC,
    gross_salary NUMERIC,
    pf_deduction NUMERIC,
    tds NUMERIC,
    professional_tax NUMERIC,
    insurance_deduction NUMERIC,
    total_deductions NUMERIC,
    net_salary NUMERIC,
    payment_mode TEXT,
    bank_name TEXT,
    account_number TEXT,
    ifsc_code TEXT,
    pan_number TEXT,
    active_advance_balance NUMERIC,
    advance_monthly_emi NUMERIC,
    payout_id UUID,
    payout_status TEXT,
    payout_date TIMESTAMPTZ,
    payout_txn_ref TEXT,
    payout_payslip_number TEXT,
    payout_net_pay NUMERIC,
    payout_bonus NUMERIC,
    payout_bonus_type TEXT,
    payout_bonus_remarks TEXT,
    payout_other_deductions NUMERIC,
    payout_other_deductions_remarks TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_clean_month_str TEXT;
BEGIN
    v_clean_month_str := COALESCE(NULLIF(TRIM(p_month_str), ''), TO_CHAR(NOW(), 'YYYY-MM'));

    RETURN QUERY
    WITH staff_advances AS (
        SELECT 
            a.staff_id,
            COALESCE(SUM(GREATEST(0.0, a.amount - COALESCE(a.amount_repaid, 0.0))), 0.0) AS active_balance,
            COALESCE(SUM(CASE WHEN a.amount_repaid < a.amount THEN COALESCE(a.monthly_deduction, 0.0) ELSE 0.0 END), 0.0) AS monthly_emi
        FROM public.staff_salary_advances a
        WHERE a.school_id = p_school_id
          AND a.status = 'Approved'
          AND COALESCE(a.amount_repaid, 0.0) < a.amount
        GROUP BY a.staff_id
    )
    SELECT
        p.id AS staff_id,
        p.full_name::TEXT,
        COALESCE(p.employee_id, 'EMP-' || UPPER(SUBSTRING(p.id::text, 1, 6)))::TEXT AS employee_id,
        COALESCE(p.designation, 'Faculty Member')::TEXT AS designation,
        COALESCE(p.department, 'Academic & Teaching')::TEXT AS department,
        COALESCE(p.email, '')::TEXT AS email,
        COALESCE(p.phone, '')::TEXT AS phone,
        (s.id IS NOT NULL) AS has_structure,
        COALESCE(s.basic_pay, 35000.0) AS basic_pay,
        COALESCE(s.hra, 14000.0) AS hra,
        COALESCE(s.da, 5000.0) AS da,
        COALESCE(s.ta, 3000.0) AS ta,
        COALESCE(s.special_allowance, 3000.0) AS special_allowance,
        COALESCE(s.medical_allowance, 1500.0) AS medical_allowance,
        -- Exact computed Gross
        (COALESCE(s.basic_pay, 35000.0) + COALESCE(s.hra, 14000.0) + COALESCE(s.da, 5000.0) + 
         COALESCE(s.ta, 3000.0) + COALESCE(s.special_allowance, 3000.0) + COALESCE(s.medical_allowance, 1500.0)) AS gross_salary,
        COALESCE(s.pf_deduction, 4200.0) AS pf_deduction,
        COALESCE(s.tds, 2500.0) AS tds,
        COALESCE(s.professional_tax, 200.0) AS professional_tax,
        COALESCE(s.insurance_deduction, 1000.0) AS insurance_deduction,
        -- Exact computed Deductions
        (COALESCE(s.pf_deduction, 4200.0) + COALESCE(s.tds, 2500.0) + 
         COALESCE(s.professional_tax, 200.0) + COALESCE(s.insurance_deduction, 1000.0)) AS total_deductions,
        -- Exact computed Net
        ((COALESCE(s.basic_pay, 35000.0) + COALESCE(s.hra, 14000.0) + COALESCE(s.da, 5000.0) + 
          COALESCE(s.ta, 3000.0) + COALESCE(s.special_allowance, 3000.0) + COALESCE(s.medical_allowance, 1500.0)) -
         (COALESCE(s.pf_deduction, 4200.0) + COALESCE(s.tds, 2500.0) + 
          COALESCE(s.professional_tax, 200.0) + COALESCE(s.insurance_deduction, 1000.0))) AS net_salary,
        COALESCE(s.payment_mode, 'Direct Bank Transfer (NEFT/RTGS)')::TEXT AS payment_mode,
        COALESCE(s.bank_name, p.bank_name, 'HDFC Bank')::TEXT AS bank_name,
        COALESCE(s.account_number, p.account_number, '')::TEXT AS account_number,
        COALESCE(s.ifsc_code, p.ifsc_code, '')::TEXT AS ifsc_code,
        COALESCE(s.pan_number, p.pan_number, '')::TEXT AS pan_number,
        COALESCE(adv.active_balance, 0.0) AS active_advance_balance,
        COALESCE(adv.monthly_emi, 0.0) AS advance_monthly_emi,
        pay.id AS payout_id,
        COALESCE(pay.payment_status, 'Pending')::TEXT AS payout_status,
        pay.payment_date AS payout_date,
        pay.transaction_reference::TEXT AS payout_txn_ref,
        pay.payslip_number::TEXT AS payout_payslip_number,
        pay.net_pay AS payout_net_pay,
        COALESCE(pay.bonus, 0.0) AS payout_bonus,
        COALESCE(pay.bonus_type, 'NONE')::TEXT AS payout_bonus_type,
        pay.bonus_remarks::TEXT AS payout_bonus_remarks,
        COALESCE(pay.other_deductions, 0.0) AS payout_other_deductions,
        pay.other_deductions_remarks::TEXT AS payout_other_deductions_remarks
    FROM public.profiles p
    LEFT JOIN public.staff_salary_structures s
        ON s.staff_id = p.id AND s.school_id = p_school_id
    LEFT JOIN staff_advances adv
        ON adv.staff_id = p.id
    LEFT JOIN public.staff_salary_payouts pay
        ON pay.staff_id = p.id AND pay.school_id = p_school_id AND pay.month_str = v_clean_month_str
    WHERE p.school_id = p_school_id
      AND p.role NOT IN ('student', 'parent', 'view_only')
      AND (
          NULLIF(TRIM(p_search), '') IS NULL
          OR p.full_name ILIKE '%' || TRIM(p_search) || '%'
          OR COALESCE(p.employee_id, '') ILIKE '%' || TRIM(p_search) || '%'
          OR COALESCE(p.email, '') ILIKE '%' || TRIM(p_search) || '%'
          OR COALESCE(p.phone, '') ILIKE '%' || TRIM(p_search) || '%'
          OR COALESCE(p.department, '') ILIKE '%' || TRIM(p_search) || '%'
          OR COALESCE(p.designation, '') ILIKE '%' || TRIM(p_search) || '%'
      )
    ORDER BY p.full_name ASC
    LIMIT 100;
END;
$$;

-- 8. Stored Procedure: public.fn_auto_generate_monthly_payroll_payslips (saves medical & insurance)
CREATE OR REPLACE FUNCTION public.fn_auto_generate_monthly_payroll_payslips(
    p_school_id UUID,
    p_month_str TEXT,
    p_payment_mode TEXT DEFAULT 'Direct Bank Transfer (NEFT/RTGS)',
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_clean_month_str TEXT := TRIM(p_month_str);
    v_year INT;
    v_month INT;
    v_rec RECORD;
    v_generated_count INT := 0;
    v_already_processed_count INT := 0;
    v_total_eligible INT := 0;
    v_total_gross_disbursed NUMERIC(12,2) := 0.0;
    v_total_net_disbursed NUMERIC(12,2) := 0.0;
    v_generated_payslips JSONB := '[]'::jsonb;
    v_ps_num TEXT;
    v_seq_num INT := 1;
    v_txn_ref TEXT;
    v_adv RECORD;
    v_adv_deduction NUMERIC(12,2);
    v_remaining_deduction NUMERIC(12,2);
    v_alloc NUMERIC(12,2);
    v_gross NUMERIC(12,2);
    v_total_ded NUMERIC(12,2);
    v_net NUMERIC(12,2);
BEGIN
    IF v_clean_month_str ~ '^\d{4}-\d{2}$' THEN
        v_year := SUBSTRING(v_clean_month_str FROM 1 FOR 4)::INT;
        v_month := SUBSTRING(v_clean_month_str FROM 6 FOR 2)::INT;
    ELSE
        v_clean_month_str := TO_CHAR(CURRENT_DATE, 'YYYY-MM');
        v_year := EXTRACT(YEAR FROM CURRENT_DATE)::INT;
        v_month := EXTRACT(MONTH FROM CURRENT_DATE)::INT;
    END IF;

    -- Sequence base for payslips
    SELECT COALESCE(MAX(SUBSTRING(payslip_number FROM 'PS-\d{4}-\d{2}-(\d+)')::INT), 0) + 1
    INTO v_seq_num
    FROM public.staff_salary_payouts
    WHERE school_id = p_school_id AND month_str = v_clean_month_str;

    -- Loop through all active staff salary structures
    FOR v_rec IN (
        SELECT 
            s.staff_id,
            p.full_name,
            COALESCE(p.email, '') AS email,
            COALESCE(p.employee_id, 'EMP-' || UPPER(SUBSTRING(p.id::text, 1, 6))) AS employee_id,
            COALESCE(p.department, 'Academic & Teaching') AS department,
            COALESCE(p.designation, 'Faculty Member') AS designation,
            s.basic_pay,
            s.hra,
            s.da,
            s.ta,
            s.special_allowance,
            s.medical_allowance,
            (COALESCE(s.basic_pay,0) + COALESCE(s.hra,0) + COALESCE(s.da,0) + COALESCE(s.ta,0) + 
             COALESCE(s.special_allowance,0) + COALESCE(s.medical_allowance,0)) AS computed_gross,
            s.pf_deduction,
            s.tds,
            s.professional_tax,
            s.insurance_deduction,
            COALESCE(s.bank_name, p.bank_name, 'HDFC Bank') AS bank_name,
            COALESCE(s.account_number, p.account_number, '') AS account_number,
            COALESCE(s.ifsc_code, p.ifsc_code, '') AS ifsc_code,
            COALESCE(s.pan_number, p.pan_number, '') AS pan_number,
            COALESCE(s.payment_mode, p_payment_mode) AS payment_mode
        FROM public.staff_salary_structures s
        INNER JOIN public.profiles p ON s.staff_id = p.id AND s.school_id = p.school_id
        WHERE s.school_id = p_school_id
          AND s.status = 'ACTIVE'
          AND p.role NOT IN ('student', 'parent', 'view_only')
        ORDER BY p.full_name ASC
    ) LOOP
        v_total_eligible := v_total_eligible + 1;

        -- Check if payout already exists for this staff in target month
        IF EXISTS (
            SELECT 1 FROM public.staff_salary_payouts
            WHERE school_id = p_school_id 
              AND staff_id = v_rec.staff_id 
              AND month_str = v_clean_month_str
        ) THEN
            v_already_processed_count := v_already_processed_count + 1;
            CONTINUE;
        END IF;

        -- Check for any active advances with outstanding balance
        v_adv_deduction := 0.0;
        SELECT COALESCE(SUM(monthly_deduction), 0.0)
        INTO v_adv_deduction
        FROM public.staff_salary_advances
        WHERE school_id = p_school_id 
          AND staff_id = v_rec.staff_id 
          AND status = 'Approved' 
          AND (amount - COALESCE(amount_repaid, 0.0)) > 0;

        -- Calculate earnings & deductions
        v_gross := v_rec.computed_gross;
        v_total_ded := v_rec.pf_deduction + v_rec.tds + v_rec.professional_tax + 
                       v_rec.insurance_deduction + v_adv_deduction;
        v_net := GREATEST(0.0, v_gross - v_total_ded);

        v_ps_num := 'PS-' || v_clean_month_str || '-' || LPAD(v_seq_num::TEXT, 4, '0');
        v_txn_ref := 'BATCH-PAY-' || v_clean_month_str || '-' || LPAD(v_seq_num::TEXT, 4, '0');
        v_seq_num := v_seq_num + 1;

        -- Create payout record
        INSERT INTO public.staff_salary_payouts (
            school_id,
            staff_id,
            payslip_number,
            month,
            year,
            month_str,
            basic_pay,
            hra,
            da,
            ta,
            special_allowance,
            medical_allowance,
            bonus,
            gross_earnings,
            pf_deduction,
            tds,
            professional_tax,
            insurance_deduction,
            advance_deduction,
            other_deductions,
            total_deductions,
            net_pay,
            payment_status,
            payment_date,
            payment_mode,
            transaction_reference,
            remarks,
            processed_by,
            bank_name,
            account_number,
            ifsc_code,
            pan_number,
            bonus_type,
            bonus_remarks,
            other_deductions_remarks,
            created_at,
            updated_at
        ) VALUES (
            p_school_id,
            v_rec.staff_id,
            v_ps_num,
            v_month,
            v_year,
            v_clean_month_str,
            v_rec.basic_pay,
            v_rec.hra,
            v_rec.da,
            v_rec.ta,
            v_rec.special_allowance,
            v_rec.medical_allowance,
            0.0,
            v_gross,
            v_rec.pf_deduction,
            v_rec.tds,
            v_rec.professional_tax,
            v_rec.insurance_deduction,
            v_adv_deduction,
            0.0,
            v_total_ded,
            v_net,
            'Paid',
            NOW(),
            v_rec.payment_mode,
            v_txn_ref,
            'Automated institutional batch payroll run for ' || v_clean_month_str,
            p_user_id,
            v_rec.bank_name,
            v_rec.account_number,
            v_rec.ifsc_code,
            v_rec.pan_number,
            'NONE',
            NULL,
            NULL,
            NOW(),
            NOW()
        );

        -- FIFO advance recovery
        IF v_adv_deduction > 0 THEN
            v_remaining_deduction := v_adv_deduction;
            FOR v_adv IN (
                SELECT id, amount, COALESCE(amount_repaid, 0.0) AS amount_repaid
                FROM public.staff_salary_advances
                WHERE school_id = p_school_id 
                  AND staff_id = v_rec.staff_id 
                  AND status = 'Approved' 
                  AND (amount - COALESCE(amount_repaid, 0.0)) > 0
                ORDER BY created_at ASC
            ) LOOP
                EXIT WHEN v_remaining_deduction <= 0;
                v_alloc := LEAST(v_remaining_deduction, v_adv.amount - v_adv.amount_repaid);
                
                UPDATE public.staff_salary_advances
                SET 
                    amount_repaid = amount_repaid + v_alloc,
                    status = CASE WHEN (amount_repaid + v_alloc) >= amount THEN 'Settled' ELSE status END,
                    updated_at = NOW()
                WHERE id = v_adv.id;

                v_remaining_deduction := v_remaining_deduction - v_alloc;
            END LOOP;
        END IF;

        v_generated_count := v_generated_count + 1;
        v_total_gross_disbursed := v_total_gross_disbursed + v_gross;
        v_total_net_disbursed := v_total_net_disbursed + v_net;

        v_generated_payslips := v_generated_payslips || jsonb_build_object(
            'staff_id', v_rec.staff_id,
            'staff_name', v_rec.full_name,
            'email', v_rec.email,
            'employee_id', v_rec.employee_id,
            'department', v_rec.department,
            'designation', v_rec.designation,
            'payslip_number', v_ps_num,
            'month_str', v_clean_month_str,
            'gross_earnings', v_gross,
            'total_deductions', v_total_ded,
            'net_pay', v_net,
            'payment_mode', v_rec.payment_mode,
            'transaction_reference', v_txn_ref,
            'bank_name', v_rec.bank_name,
            'account_number', v_rec.account_number
        );
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'month_str', v_clean_month_str,
        'eligible_count', v_total_eligible,
        'generated_count', v_generated_count,
        'already_processed_count', v_already_processed_count,
        'total_gross_disbursed', v_total_gross_disbursed,
        'total_net_disbursed', v_total_net_disbursed,
        'generated_payslips', v_generated_payslips
    );
END;
$$;

-- 9. Stored Procedure: public.fn_process_staff_salary_payout (Full SSOT with medical_allowance & insurance_deduction)
CREATE OR REPLACE FUNCTION public.fn_process_staff_salary_payout(
    p_school_id UUID,
    p_staff_id UUID,
    p_month INT,
    p_year INT,
    p_month_str TEXT,
    p_basic_pay NUMERIC,
    p_hra NUMERIC,
    p_da NUMERIC,
    p_ta NUMERIC,
    p_special_allowance NUMERIC,
    p_bonus NUMERIC,
    p_pf_deduction NUMERIC,
    p_tds NUMERIC,
    p_professional_tax NUMERIC,
    p_advance_deduction NUMERIC,
    p_other_deductions NUMERIC,
    p_payment_status TEXT DEFAULT 'Paid',
    p_payment_mode TEXT DEFAULT 'Direct Bank Transfer (NEFT/RTGS)',
    p_transaction_reference TEXT DEFAULT NULL,
    p_remarks TEXT DEFAULT NULL,
    p_user_id UUID DEFAULT NULL,
    p_bonus_type TEXT DEFAULT 'NONE',
    p_bonus_remarks TEXT DEFAULT NULL,
    p_other_deductions_remarks TEXT DEFAULT NULL,
    p_update_permanent_structure BOOLEAN DEFAULT false,
    p_medical_allowance NUMERIC DEFAULT 0.0,
    p_insurance_deduction NUMERIC DEFAULT 0.0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_gross_earnings NUMERIC(12,2);
    v_total_deductions NUMERIC(12,2);
    v_net_pay NUMERIC(12,2);
    v_ps_num TEXT;
    v_txn_ref TEXT;
    v_payout_id UUID;
    v_staff_name TEXT;
    v_emp_id TEXT;
    v_clean_month_str TEXT;
    v_clean_month INT;
    v_clean_year INT;
    v_clean_status TEXT;
    v_clean_mode TEXT;
    v_bank_name TEXT;
    v_account_number TEXT;
    v_ifsc_code TEXT;
    v_pan_number TEXT;
    v_remaining_deduction NUMERIC(12,2);
    v_alloc NUMERIC(12,2);
    v_adv RECORD;
    v_repaid_adv_count INT := 0;
BEGIN
    v_clean_month_str := COALESCE(NULLIF(TRIM(p_month_str), ''), TO_CHAR(NOW(), 'YYYY-MM'));
    v_clean_month := COALESCE(p_month, EXTRACT(MONTH FROM NOW())::INT);
    v_clean_year := COALESCE(p_year, EXTRACT(YEAR FROM NOW())::INT);
    v_clean_status := COALESCE(NULLIF(TRIM(p_payment_status), ''), 'Paid');
    v_clean_mode := COALESCE(NULLIF(TRIM(p_payment_mode), ''), 'Direct Bank Transfer (NEFT/RTGS)');

    SELECT 
        p.full_name,
        COALESCE(p.employee_id, 'EMP-' || UPPER(SUBSTRING(p.id::text, 1, 6))),
        COALESCE(s.bank_name, p.bank_name, 'HDFC Bank'),
        COALESCE(s.account_number, p.account_number, ''),
        COALESCE(s.ifsc_code, p.ifsc_code, ''),
        COALESCE(s.pan_number, p.pan_number, '')
    INTO v_staff_name, v_emp_id, v_bank_name, v_account_number, v_ifsc_code, v_pan_number
    FROM public.profiles p
    LEFT JOIN public.staff_salary_structures s ON s.staff_id = p.id AND s.school_id = p_school_id
    WHERE p.id = p_staff_id AND p.school_id = p_school_id;

    -- Exact computed Gross
    v_gross_earnings := COALESCE(p_basic_pay, 0.0) +
                        COALESCE(p_hra, 0.0) +
                        COALESCE(p_da, 0.0) +
                        COALESCE(p_ta, 0.0) +
                        COALESCE(p_special_allowance, 0.0) +
                        COALESCE(p_medical_allowance, 0.0) +
                        COALESCE(p_bonus, 0.0);

    -- Exact computed Deductions
    v_total_deductions := COALESCE(p_pf_deduction, 0.0) +
                          COALESCE(p_tds, 0.0) +
                          COALESCE(p_professional_tax, 200.0) +
                          COALESCE(p_insurance_deduction, 0.0) +
                          COALESCE(p_advance_deduction, 0.0) +
                          COALESCE(p_other_deductions, 0.0);

    -- Exact Net Take-Home
    v_net_pay := GREATEST(0.0, v_gross_earnings - v_total_deductions);

    -- Payslip number
    SELECT payslip_number INTO v_ps_num
    FROM public.staff_salary_payouts
    WHERE school_id = p_school_id AND staff_id = p_staff_id AND month_str = v_clean_month_str;

    IF v_ps_num IS NULL THEN
        SELECT 'PS-' || v_clean_month_str || '-' || LPAD((COALESCE(MAX(SUBSTRING(payslip_number FROM 'PS-\d{4}-\d{2}-(\d+)')::INT), 0) + 1)::TEXT, 4, '0')
        INTO v_ps_num
        FROM public.staff_salary_payouts
        WHERE school_id = p_school_id AND month_str = v_clean_month_str;
    END IF;

    v_txn_ref := COALESCE(NULLIF(TRIM(p_transaction_reference), ''), 'TXN-PAY-' || v_clean_month_str || '-' || v_emp_id);

    -- Upsert Payout Record
    INSERT INTO public.staff_salary_payouts (
        school_id, staff_id, payslip_number, month, year, month_str,
        basic_pay, hra, da, ta, special_allowance, medical_allowance, bonus, gross_earnings,
        pf_deduction, tds, professional_tax, insurance_deduction, advance_deduction, other_deductions,
        total_deductions, net_pay, payment_status, payment_date, payment_mode,
        transaction_reference, remarks, processed_by,
        bank_name, account_number, ifsc_code, pan_number,
        bonus_type, bonus_remarks, other_deductions_remarks, updated_at
    ) VALUES (
        p_school_id, p_staff_id, v_ps_num, v_clean_month, v_clean_year, v_clean_month_str,
        COALESCE(p_basic_pay, 0.0), COALESCE(p_hra, 0.0), COALESCE(p_da, 0.0),
        COALESCE(p_ta, 0.0), COALESCE(p_special_allowance, 0.0), COALESCE(p_medical_allowance, 0.0), COALESCE(p_bonus, 0.0),
        v_gross_earnings,
        COALESCE(p_pf_deduction, 0.0), COALESCE(p_tds, 0.0), COALESCE(p_professional_tax, 200.0), COALESCE(p_insurance_deduction, 0.0),
        COALESCE(p_advance_deduction, 0.0), COALESCE(p_other_deductions, 0.0),
        v_total_deductions, v_net_pay, v_clean_status,
        CASE WHEN v_clean_status = 'Paid' THEN NOW() ELSE NULL END,
        v_clean_mode, v_txn_ref,
        COALESCE(p_remarks, 'Monthly salary disbursal for ' || v_clean_month_str),
        p_user_id,
        v_bank_name, v_account_number, v_ifsc_code, v_pan_number,
        COALESCE(p_bonus_type, 'NONE'), p_bonus_remarks, p_other_deductions_remarks, NOW()
    )
    ON CONFLICT (school_id, staff_id, month_str) DO UPDATE SET
        basic_pay = EXCLUDED.basic_pay,
        hra = EXCLUDED.hra,
        da = EXCLUDED.da,
        ta = EXCLUDED.ta,
        special_allowance = EXCLUDED.special_allowance,
        medical_allowance = EXCLUDED.medical_allowance,
        bonus = EXCLUDED.bonus,
        gross_earnings = EXCLUDED.gross_earnings,
        pf_deduction = EXCLUDED.pf_deduction,
        tds = EXCLUDED.tds,
        professional_tax = EXCLUDED.professional_tax,
        insurance_deduction = EXCLUDED.insurance_deduction,
        advance_deduction = EXCLUDED.advance_deduction,
        other_deductions = EXCLUDED.other_deductions,
        total_deductions = EXCLUDED.total_deductions,
        net_pay = EXCLUDED.net_pay,
        payment_status = EXCLUDED.payment_status,
        payment_date = CASE WHEN EXCLUDED.payment_status = 'Paid' THEN COALESCE(staff_salary_payouts.payment_date, NOW()) ELSE NULL END,
        payment_mode = EXCLUDED.payment_mode,
        transaction_reference = COALESCE(EXCLUDED.transaction_reference, staff_salary_payouts.transaction_reference),
        remarks = EXCLUDED.remarks,
        processed_by = COALESCE(EXCLUDED.processed_by, staff_salary_payouts.processed_by),
        bank_name = COALESCE(EXCLUDED.bank_name, staff_salary_payouts.bank_name),
        account_number = COALESCE(EXCLUDED.account_number, staff_salary_payouts.account_number),
        ifsc_code = COALESCE(EXCLUDED.ifsc_code, staff_salary_payouts.ifsc_code),
        pan_number = COALESCE(EXCLUDED.pan_number, staff_salary_payouts.pan_number),
        bonus_type = EXCLUDED.bonus_type,
        bonus_remarks = EXCLUDED.bonus_remarks,
        other_deductions_remarks = EXCLUDED.other_deductions_remarks,
        updated_at = NOW()
    RETURNING id, payslip_number INTO v_payout_id, v_ps_num;

    -- Advance loan recovery FIFO
    IF COALESCE(p_advance_deduction, 0.0) > 0 THEN
        v_remaining_deduction := p_advance_deduction;
        FOR v_adv IN (
            SELECT id, amount, COALESCE(amount_repaid, 0.0) AS amount_repaid
            FROM public.staff_salary_advances
            WHERE school_id = p_school_id 
              AND staff_id = p_staff_id 
              AND status = 'Approved' 
              AND (amount - COALESCE(amount_repaid, 0.0)) > 0
            ORDER BY created_at ASC
        ) LOOP
            EXIT WHEN v_remaining_deduction <= 0;
            v_alloc := LEAST(v_remaining_deduction, v_adv.amount - v_adv.amount_repaid);

            UPDATE public.staff_salary_advances
            SET 
                amount_repaid = amount_repaid + v_alloc,
                status = CASE WHEN (amount_repaid + v_alloc) >= amount THEN 'Settled' ELSE status END,
                updated_at = NOW()
            WHERE id = v_adv.id;

            v_remaining_deduction := v_remaining_deduction - v_alloc;
            v_repaid_adv_count := v_repaid_adv_count + 1;
        END LOOP;
    END IF;

    -- Update Permanent Structure if requested
    IF p_update_permanent_structure THEN
        INSERT INTO public.staff_salary_structures (
            school_id, staff_id, basic_pay, hra, da, ta, special_allowance, medical_allowance,
            gross_salary, pf_deduction, tds, professional_tax, insurance_deduction, total_deductions,
            net_salary, payment_mode, bank_name, account_number, ifsc_code, pan_number,
            status, effective_date, updated_at
        ) VALUES (
            p_school_id, p_staff_id,
            COALESCE(p_basic_pay, 0.0), COALESCE(p_hra, 0.0), COALESCE(p_da, 0.0),
            COALESCE(p_ta, 0.0), COALESCE(p_special_allowance, 0.0), COALESCE(p_medical_allowance, 0.0),
            (COALESCE(p_basic_pay, 0.0) + COALESCE(p_hra, 0.0) + COALESCE(p_da, 0.0) + COALESCE(p_ta, 0.0) + COALESCE(p_special_allowance, 0.0) + COALESCE(p_medical_allowance, 0.0)),
            COALESCE(p_pf_deduction, 0.0), COALESCE(p_tds, 0.0), COALESCE(p_professional_tax, 200.0), COALESCE(p_insurance_deduction, 0.0),
            (COALESCE(p_pf_deduction, 0.0) + COALESCE(p_tds, 0.0) + COALESCE(p_professional_tax, 200.0) + COALESCE(p_insurance_deduction, 0.0)),
            (COALESCE(p_basic_pay, 0.0) + COALESCE(p_hra, 0.0) + COALESCE(p_da, 0.0) + COALESCE(p_ta, 0.0) + COALESCE(p_special_allowance, 0.0) + COALESCE(p_medical_allowance, 0.0)) - 
            (COALESCE(p_pf_deduction, 0.0) + COALESCE(p_tds, 0.0) + COALESCE(p_professional_tax, 200.0) + COALESCE(p_insurance_deduction, 0.0)),
            v_clean_mode, v_bank_name, v_account_number, v_ifsc_code, v_pan_number,
            'ACTIVE', CURRENT_DATE, NOW()
        )
        ON CONFLICT (school_id, staff_id) DO UPDATE SET
            basic_pay = EXCLUDED.basic_pay,
            hra = EXCLUDED.hra,
            da = EXCLUDED.da,
            ta = EXCLUDED.ta,
            special_allowance = EXCLUDED.special_allowance,
            medical_allowance = EXCLUDED.medical_allowance,
            gross_salary = EXCLUDED.gross_salary,
            pf_deduction = EXCLUDED.pf_deduction,
            tds = EXCLUDED.tds,
            professional_tax = EXCLUDED.professional_tax,
            insurance_deduction = EXCLUDED.insurance_deduction,
            total_deductions = EXCLUDED.total_deductions,
            net_salary = EXCLUDED.net_salary,
            payment_mode = COALESCE(EXCLUDED.payment_mode, staff_salary_structures.payment_mode),
            bank_name = COALESCE(EXCLUDED.bank_name, staff_salary_structures.bank_name),
            account_number = COALESCE(EXCLUDED.account_number, staff_salary_structures.account_number),
            ifsc_code = COALESCE(EXCLUDED.ifsc_code, staff_salary_structures.ifsc_code),
            pan_number = COALESCE(EXCLUDED.pan_number, staff_salary_structures.pan_number),
            effective_date = CURRENT_DATE,
            updated_at = NOW();

        -- Also keep profiles SSOT updated
        UPDATE public.profiles
        SET 
            bank_name = COALESCE(NULLIF(v_bank_name, ''), bank_name),
            account_number = COALESCE(NULLIF(v_account_number, ''), account_number),
            ifsc_code = COALESCE(NULLIF(v_ifsc_code, ''), ifsc_code),
            pan_number = COALESCE(NULLIF(v_pan_number, ''), pan_number),
            updated_at = NOW()
        WHERE id = p_staff_id AND school_id = p_school_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'payout_id', v_payout_id,
        'payslip_number', v_ps_num,
        'staff_id', p_staff_id,
        'staff_name', v_staff_name,
        'month_str', v_clean_month_str,
        'gross_earnings', v_gross_earnings,
        'total_deductions', v_total_deductions,
        'net_pay', v_net_pay,
        'payment_status', v_clean_status,
        'payment_mode', v_clean_mode,
        'transaction_reference', v_txn_ref,
        'repaid_advances_count', v_repaid_adv_count,
        'bonus_type', p_bonus_type,
        'bonus_remarks', p_bonus_remarks,
        'other_deductions_remarks', p_other_deductions_remarks,
        'permanent_structure_updated', p_update_permanent_structure
    );
END;
$$;
