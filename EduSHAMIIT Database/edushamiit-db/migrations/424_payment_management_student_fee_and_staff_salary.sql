-- ============================================================================
-- Migration 424: Universal Payment Management System:
--                1. Student Fee & Billing Management
--                2. Staff Salary & Payroll Management
-- Multi-Tenant, Dynamic Lookups, Full Ledger, and Complete Auditing
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. SEED UNIVERSAL LOOKUP KEYS & VALUES FOR PAYMENT MANAGEMENT
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    r_school RECORD;
    v_key_id UUID;
BEGIN
    FOR r_school IN SELECT id FROM public.schools LOOP

        -- A. STUDENT_FEE_TYPE
        SELECT id INTO v_key_id 
        FROM public.lookup_keys 
        WHERE school_id = r_school.id AND key_code = 'STUDENT_FEE_TYPE' AND deleted_at IS NULL;

        IF v_key_id IS NULL THEN
            INSERT INTO public.lookup_keys (
                id, school_id, key_name, key_code, description, 
                key_type, icon, status, version, created_at, updated_at
            ) VALUES (
                gen_random_uuid(), r_school.id, 'Student Fee Type', 'STUDENT_FEE_TYPE', 
                'Categories of school academic and extracurricular fees', 'SYSTEM', 'receipt_long_outlined', 
                'ACTIVE', 1, NOW(), NOW()
            ) RETURNING id INTO v_key_id;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'TUITION' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Tuition Fee', 'TUITION', 'Core academic instructional fee', 'ACTIVE', 1, NOW(), NOW());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'ADMISSION' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Admission Fee', 'ADMISSION', 'One-time admission and enrollment fee', 'ACTIVE', 2, NOW(), NOW());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'EXAM' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Examination Fee', 'EXAM', 'Semester and board exam assessment fee', 'ACTIVE', 3, NOW(), NOW());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'LAB' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Science & Computer Lab Fee', 'LAB', 'Practical lab equipment and consumables fee', 'ACTIVE', 4, NOW(), NOW());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'LIBRARY' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Library & Digital Resources Fee', 'LIBRARY', 'Library subscription and digital portal access', 'ACTIVE', 5, NOW(), NOW());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'SPORTS' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Sports & Fitness Fee', 'SPORTS', 'Athletics, tournaments, and fitness facilities', 'ACTIVE', 6, NOW(), NOW());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'DEVELOPMENT' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Annual Campus Development Fee', 'DEVELOPMENT', 'Campus infrastructure maintenance and upgrade', 'ACTIVE', 7, NOW(), NOW());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'TRANSPORT' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Transportation Fee', 'TRANSPORT', 'School bus and transit shuttle fee', 'ACTIVE', 8, NOW(), NOW());
        END IF;


        -- B. STUDENT_FEE_BILLING_CYCLE
        SELECT id INTO v_key_id 
        FROM public.lookup_keys 
        WHERE school_id = r_school.id AND key_code = 'STUDENT_FEE_BILLING_CYCLE' AND deleted_at IS NULL;

        IF v_key_id IS NULL THEN
            INSERT INTO public.lookup_keys (
                id, school_id, key_name, key_code, description, 
                key_type, icon, status, version, created_at, updated_at
            ) VALUES (
                gen_random_uuid(), r_school.id, 'Student Fee Billing Cycle', 'STUDENT_FEE_BILLING_CYCLE', 
                'Invoicing schedules and billing intervals', 'SYSTEM', 'date_range_outlined', 
                'ACTIVE', 1, NOW(), NOW()
            ) RETURNING id INTO v_key_id;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'MONTHLY' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Monthly', 'MONTHLY', 'Billed every month', 'ACTIVE', 1, NOW(), NOW());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'QUARTERLY' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Quarterly', 'QUARTERLY', 'Billed every 3 months', 'ACTIVE', 2, NOW(), NOW());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'TERM_WISE' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Term-Wise', 'TERM_WISE', 'Billed per academic term (3 terms/year)', 'ACTIVE', 3, NOW(), NOW());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'ANNUAL' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Annual', 'ANNUAL', 'Billed once per academic session', 'ACTIVE', 4, NOW(), NOW());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'ONE_TIME' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'One-Time', 'ONE_TIME', 'Single non-recurring charge', 'ACTIVE', 5, NOW(), NOW());
        END IF;


        -- C. STUDENT_FEE_PAYMENT_STATUS
        SELECT id INTO v_key_id 
        FROM public.lookup_keys 
        WHERE school_id = r_school.id AND key_code = 'STUDENT_FEE_PAYMENT_STATUS' AND deleted_at IS NULL;

        IF v_key_id IS NULL THEN
            INSERT INTO public.lookup_keys (
                id, school_id, key_name, key_code, description, 
                key_type, icon, status, version, created_at, updated_at
            ) VALUES (
                gen_random_uuid(), r_school.id, 'Student Fee Payment Status', 'STUDENT_FEE_PAYMENT_STATUS', 
                'Payment lifecycle status for invoices and accounts', 'SYSTEM', 'check_circle_outline', 
                'ACTIVE', 1, NOW(), NOW()
            ) RETURNING id INTO v_key_id;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'PAID' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Paid', 'PAID', 'Fully settled with zero dues', 'ACTIVE', 1, NOW(), NOW());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'PARTIAL' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Partial', 'PARTIAL', 'Partially paid with remaining balance', 'ACTIVE', 2, NOW(), NOW());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'PENDING' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Pending', 'PENDING', 'Awaiting payment before due date', 'ACTIVE', 3, NOW(), NOW());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'OVERDUE' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Overdue', 'OVERDUE', 'Payment past scheduled due date', 'ACTIVE', 4, NOW(), NOW());
        END IF;


        -- D. STUDENT_FEE_PAYMENT_MODE
        SELECT id INTO v_key_id 
        FROM public.lookup_keys 
        WHERE school_id = r_school.id AND key_code = 'STUDENT_FEE_PAYMENT_MODE' AND deleted_at IS NULL;

        IF v_key_id IS NULL THEN
            INSERT INTO public.lookup_keys (
                id, school_id, key_name, key_code, description, 
                key_type, icon, status, version, created_at, updated_at
            ) VALUES (
                gen_random_uuid(), r_school.id, 'Student Fee Payment Mode', 'STUDENT_FEE_PAYMENT_MODE', 
                'Payment tender methods supported at counter & online', 'SYSTEM', 'payment_outlined', 
                'ACTIVE', 1, NOW(), NOW()
            ) RETURNING id INTO v_key_id;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'UPI' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'UPI', 'UPI', 'Google Pay, PhonePe, Paytm, BHIM', 'ACTIVE', 1, NOW(), NOW());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'CASH' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Cash', 'CASH', 'Physical cash payment at school counter', 'ACTIVE', 2, NOW(), NOW());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'BANK_TRANSFER' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Bank Transfer (NEFT/RTGS)', 'BANK_TRANSFER', 'Direct electronic funds transfer', 'ACTIVE', 3, NOW(), NOW());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'CARD' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Credit / Debit Card', 'CARD', 'POS card swipe or online card payment', 'ACTIVE', 4, NOW(), NOW());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'CHEQUE' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Cheque / DD', 'CHEQUE', 'Bank crossed cheque or demand draft', 'ACTIVE', 5, NOW(), NOW());
        END IF;


        -- E. STUDENT_FEE_CONCESSION_TYPE
        SELECT id INTO v_key_id 
        FROM public.lookup_keys 
        WHERE school_id = r_school.id AND key_code = 'STUDENT_FEE_CONCESSION_TYPE' AND deleted_at IS NULL;

        IF v_key_id IS NULL THEN
            INSERT INTO public.lookup_keys (
                id, school_id, key_name, key_code, description, 
                key_type, icon, status, version, created_at, updated_at
            ) VALUES (
                gen_random_uuid(), r_school.id, 'Student Fee Concession Type', 'STUDENT_FEE_CONCESSION_TYPE', 
                'Scholarships, fee waivers, and concession brackets', 'SYSTEM', 'local_offer_outlined', 
                'ACTIVE', 1, NOW(), NOW()
            ) RETURNING id INTO v_key_id;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'MERIT_SCHOLARSHIP' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Academic Merit Scholarship', 'MERIT_SCHOLARSHIP', 'Merit performance award (up to 50%)', 'ACTIVE', 1, NOW(), NOW());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'SIBLING_DISCOUNT' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Sibling Concession', 'SIBLING_DISCOUNT', 'Discount for families with 2+ children', 'ACTIVE', 2, NOW(), NOW());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'STAFF_CHILD' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Staff Ward Concession', 'STAFF_CHILD', 'Children of active school faculty/staff', 'ACTIVE', 3, NOW(), NOW());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'SPORTS_QUOTA' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Sports Excellence Quota', 'SPORTS_QUOTA', 'State or national level sports achievement', 'ACTIVE', 4, NOW(), NOW());
        END IF;


        -- F. STAFF_SALARY_PAYMENT_STATUS
        SELECT id INTO v_key_id 
        FROM public.lookup_keys 
        WHERE school_id = r_school.id AND key_code = 'STAFF_SALARY_PAYMENT_STATUS' AND deleted_at IS NULL;

        IF v_key_id IS NULL THEN
            INSERT INTO public.lookup_keys (
                id, school_id, key_name, key_code, description, 
                key_type, icon, status, version, created_at, updated_at
            ) VALUES (
                gen_random_uuid(), r_school.id, 'Staff Salary Payment Status', 'STAFF_SALARY_PAYMENT_STATUS', 
                'Monthly payroll disbursal lifecycle status', 'SYSTEM', 'price_check_outlined', 
                'ACTIVE', 1, NOW(), NOW()
            ) RETURNING id INTO v_key_id;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'PAID' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Paid', 'PAID', 'Disbursed and credited to employee bank', 'ACTIVE', 1, NOW(), NOW());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'PROCESSED' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Processed', 'PROCESSED', 'Approved by finance, sent for bank clearance', 'ACTIVE', 2, NOW(), NOW());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'PENDING' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Pending', 'PENDING', 'Generated, awaiting approval & disbursal', 'ACTIVE', 3, NOW(), NOW());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'ON_HOLD' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'On Hold', 'ON_HOLD', 'Disbursal paused pending review or notice period', 'ACTIVE', 4, NOW(), NOW());
        END IF;


        -- G. STAFF_SALARY_PAYMENT_MODE
        SELECT id INTO v_key_id 
        FROM public.lookup_keys 
        WHERE school_id = r_school.id AND key_code = 'STAFF_SALARY_PAYMENT_MODE' AND deleted_at IS NULL;

        IF v_key_id IS NULL THEN
            INSERT INTO public.lookup_keys (
                id, school_id, key_name, key_code, description, 
                key_type, icon, status, version, created_at, updated_at
            ) VALUES (
                gen_random_uuid(), r_school.id, 'Staff Salary Payment Mode', 'STAFF_SALARY_PAYMENT_MODE', 
                'Payment channels for staff payroll transfers', 'SYSTEM', 'account_balance_outlined', 
                'ACTIVE', 1, NOW(), NOW()
            ) RETURNING id INTO v_key_id;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'BANK_TRANSFER' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Direct Bank Transfer (NEFT/RTGS)', 'BANK_TRANSFER', 'Direct salary credit to employee bank account', 'ACTIVE', 1, NOW(), NOW());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'UPI' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Corporate UPI', 'UPI', 'Corporate bulk UPI payout transfer', 'ACTIVE', 2, NOW(), NOW());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'CHEQUE' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Cheque', 'CHEQUE', 'Paper cheque issuance', 'ACTIVE', 3, NOW(), NOW());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.lookup_values WHERE lookup_key_id = v_key_id AND value_code = 'CASH' AND deleted_at IS NULL) THEN
            INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
            VALUES (gen_random_uuid(), v_key_id, r_school.id, 'Cash', 'CASH', 'Cash payout at cash office', 'ACTIVE', 4, NOW(), NOW());
        END IF;

    END LOOP;
END $$;


-- ----------------------------------------------------------------------------
-- 2. SCHEMA TABLES CREATION FOR STUDENT FEES & STAFF SALARY
-- ----------------------------------------------------------------------------

-- A. Student Fee Structures (Fee Templates by Class / Cycle)
CREATE TABLE IF NOT EXISTS public.student_fee_structures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    fee_name VARCHAR(150) NOT NULL,
    fee_type VARCHAR(100) NOT NULL DEFAULT 'Tuition Fee',
    class_grade VARCHAR(50) DEFAULT 'All Classes',
    billing_cycle VARCHAR(50) NOT NULL DEFAULT 'Monthly',
    amount NUMERIC(12,2) NOT NULL DEFAULT 0.0,
    description TEXT,
    is_mandatory BOOLEAN DEFAULT TRUE,
    status VARCHAR(20) DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_student_fee_struct_school ON public.student_fee_structures(school_id, status);

-- B. Student Fee Invoices (Master Invoice Records)
CREATE TABLE IF NOT EXISTS public.student_fee_invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    invoice_number VARCHAR(100) NOT NULL,
    title VARCHAR(200) NOT NULL,
    fee_type VARCHAR(100) NOT NULL DEFAULT 'Tuition Fee',
    fee_plan VARCHAR(100) DEFAULT 'Monthly',
    academic_year VARCHAR(50) DEFAULT '2026 - 2027',
    billing_date DATE DEFAULT CURRENT_DATE,
    due_date DATE NOT NULL,
    subtotal NUMERIC(12,2) NOT NULL DEFAULT 0.0,
    concession_amount NUMERIC(12,2) NOT NULL DEFAULT 0.0,
    penalty_amount NUMERIC(12,2) NOT NULL DEFAULT 0.0,
    total_billed NUMERIC(12,2) NOT NULL DEFAULT 0.0,
    paid_amount NUMERIC(12,2) NOT NULL DEFAULT 0.0,
    balance_amount NUMERIC(12,2) NOT NULL DEFAULT 0.0,
    status VARCHAR(50) NOT NULL DEFAULT 'Pending',
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_student_invoice_num ON public.student_fee_invoices(school_id, invoice_number);
CREATE INDEX IF NOT EXISTS idx_student_fee_invoices_student ON public.student_fee_invoices(school_id, student_id, status);
CREATE INDEX IF NOT EXISTS idx_student_fee_invoices_due ON public.student_fee_invoices(school_id, due_date, status);

-- C. Student Fee Payments (Payment Receipts)
CREATE TABLE IF NOT EXISTS public.student_fee_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    invoice_id UUID REFERENCES public.student_fee_invoices(id) ON DELETE SET NULL,
    receipt_number VARCHAR(100) NOT NULL,
    amount_paid NUMERIC(12,2) NOT NULL,
    payment_method VARCHAR(50) NOT NULL DEFAULT 'UPI',
    transaction_reference VARCHAR(150),
    payment_date TIMESTAMPTZ DEFAULT NOW(),
    status VARCHAR(50) DEFAULT 'COMPLETED',
    remarks TEXT,
    recorded_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_student_payment_receipt ON public.student_fee_payments(school_id, receipt_number);
CREATE INDEX IF NOT EXISTS idx_student_fee_payments_student ON public.student_fee_payments(school_id, student_id);

-- D. Student Fee Concessions
CREATE TABLE IF NOT EXISTS public.student_fee_concessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    invoice_id UUID REFERENCES public.student_fee_invoices(id) ON DELETE CASCADE,
    concession_type VARCHAR(100) NOT NULL,
    amount NUMERIC(12,2) NOT NULL,
    reason TEXT,
    approved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- E. Student Fee Penalties
CREATE TABLE IF NOT EXISTS public.student_fee_penalties (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    invoice_id UUID REFERENCES public.student_fee_invoices(id) ON DELETE CASCADE,
    penalty_type VARCHAR(100) NOT NULL DEFAULT 'Late Payment Fine',
    amount NUMERIC(12,2) NOT NULL,
    reason TEXT,
    applied_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);


-- F. Staff Salary Structures (Base Salary Master per Staff Member)
CREATE TABLE IF NOT EXISTS public.staff_salary_structures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    staff_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    basic_pay NUMERIC(12,2) NOT NULL DEFAULT 35000.0,
    hra NUMERIC(12,2) NOT NULL DEFAULT 14000.0,
    da NUMERIC(12,2) NOT NULL DEFAULT 5000.0,
    ta NUMERIC(12,2) NOT NULL DEFAULT 3000.0,
    special_allowance NUMERIC(12,2) NOT NULL DEFAULT 4000.0,
    medical_allowance NUMERIC(12,2) NOT NULL DEFAULT 2000.0,
    gross_salary NUMERIC(12,2) NOT NULL DEFAULT 63000.0,
    pf_deduction NUMERIC(12,2) NOT NULL DEFAULT 4200.0,
    tds NUMERIC(12,2) NOT NULL DEFAULT 2500.0,
    professional_tax NUMERIC(12,2) NOT NULL DEFAULT 200.0,
    insurance_deduction NUMERIC(12,2) NOT NULL DEFAULT 1000.0,
    total_deductions NUMERIC(12,2) NOT NULL DEFAULT 7900.0,
    net_salary NUMERIC(12,2) NOT NULL DEFAULT 55100.0,
    payment_mode VARCHAR(50) DEFAULT 'Direct Bank Transfer (NEFT/RTGS)',
    bank_name VARCHAR(150) DEFAULT 'State Bank of India',
    account_number VARCHAR(100) DEFAULT '30982348912',
    ifsc_code VARCHAR(50) DEFAULT 'SBIN0001234',
    pan_number VARCHAR(50) DEFAULT 'ABCDE1234F',
    status VARCHAR(20) DEFAULT 'ACTIVE',
    effective_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_staff_salary_struct UNIQUE(school_id, staff_id)
);

CREATE INDEX IF NOT EXISTS idx_staff_salary_struct_school ON public.staff_salary_structures(school_id, status);

-- G. Staff Salary Payouts (Monthly Disbursals & Payslips)
CREATE TABLE IF NOT EXISTS public.staff_salary_payouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    staff_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    payslip_number VARCHAR(100) NOT NULL,
    month INT NOT NULL CHECK (month BETWEEN 1 AND 12),
    year INT NOT NULL,
    month_str VARCHAR(20) NOT NULL,
    basic_pay NUMERIC(12,2) NOT NULL DEFAULT 0.0,
    hra NUMERIC(12,2) NOT NULL DEFAULT 0.0,
    da NUMERIC(12,2) NOT NULL DEFAULT 0.0,
    ta NUMERIC(12,2) NOT NULL DEFAULT 0.0,
    special_allowance NUMERIC(12,2) NOT NULL DEFAULT 0.0,
    bonus NUMERIC(12,2) NOT NULL DEFAULT 0.0,
    gross_earnings NUMERIC(12,2) NOT NULL DEFAULT 0.0,
    pf_deduction NUMERIC(12,2) NOT NULL DEFAULT 0.0,
    tds NUMERIC(12,2) NOT NULL DEFAULT 0.0,
    professional_tax NUMERIC(12,2) NOT NULL DEFAULT 0.0,
    advance_deduction NUMERIC(12,2) NOT NULL DEFAULT 0.0,
    other_deductions NUMERIC(12,2) NOT NULL DEFAULT 0.0,
    total_deductions NUMERIC(12,2) NOT NULL DEFAULT 0.0,
    net_pay NUMERIC(12,2) NOT NULL DEFAULT 0.0,
    payment_status VARCHAR(50) NOT NULL DEFAULT 'Paid',
    payment_date TIMESTAMPTZ,
    payment_mode VARCHAR(50) DEFAULT 'Direct Bank Transfer (NEFT/RTGS)',
    transaction_reference VARCHAR(150),
    remarks TEXT,
    processed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_staff_salary_month UNIQUE(school_id, staff_id, month_str)
);

CREATE INDEX IF NOT EXISTS idx_staff_payouts_school_month ON public.staff_salary_payouts(school_id, month_str, payment_status);

-- H. Staff Salary Advances
CREATE TABLE IF NOT EXISTS public.staff_salary_advances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    staff_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    amount NUMERIC(12,2) NOT NULL,
    purpose_type VARCHAR(100) NOT NULL DEFAULT 'Medical Emergency',
    reason TEXT,
    repayment_months INT DEFAULT 3,
    monthly_deduction NUMERIC(12,2) NOT NULL,
    amount_repaid NUMERIC(12,2) DEFAULT 0.0,
    status VARCHAR(50) DEFAULT 'Approved',
    disbursed_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);


-- ----------------------------------------------------------------------------
-- 3. SEED RICH REALISTIC SAMPLE DATA FOR STUDENTS & STAFF
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    r_school RECORD;
    r_student RECORD;
    r_staff RECORD;
    v_inv_id UUID;
    v_count INT := 0;
    v_staff_count INT := 0;
    v_seq INT := 1000;
    v_subtotal NUMERIC(12,2);
    v_paid NUMERIC(12,2);
    v_bal NUMERIC(12,2);
    v_stat VARCHAR(50);
    v_plan VARCHAR(50);
    v_bpay NUMERIC(12,2);
    v_hra NUMERIC(12,2);
    v_da NUMERIC(12,2);
    v_ta NUMERIC(12,2);
    v_gross NUMERIC(12,2);
    v_pf NUMERIC(12,2);
    v_tds NUMERIC(12,2);
    v_ptax NUMERIC(12,2);
    v_totded NUMERIC(12,2);
    v_net NUMERIC(12,2);
BEGIN
    FOR r_school IN SELECT id FROM public.schools LOOP

        -- 1. Default Student Fee Structures
        IF NOT EXISTS (SELECT 1 FROM public.student_fee_structures WHERE school_id = r_school.id) THEN
            INSERT INTO public.student_fee_structures (school_id, fee_name, fee_type, class_grade, billing_cycle, amount, description) VALUES
            (r_school.id, 'Standard Tuition Fee (Monthly)', 'Tuition Fee', 'All Classes', 'Monthly', 4500.00, 'Monthly classroom teaching and instructional curriculum'),
            (r_school.id, 'Science & Computer Lab Fee', 'Science & Computer Lab Fee', 'Class 9 - 12', 'Quarterly', 2500.00, 'Practical lab software, STEM robotics and laboratory reagents'),
            (r_school.id, 'Library & Digital Portal', 'Library & Digital Resources Fee', 'All Classes', 'Annual', 1800.00, 'Library book lending and AI smart tutoring access'),
            (r_school.id, 'Campus Sports & Games', 'Sports & Fitness Fee', 'All Classes', 'Annual', 2200.00, 'Athletics, grounds maintenance, sports equipment'),
            (r_school.id, 'Term Examination Fee', 'Examination Fee', 'All Classes', 'Term-Wise', 1500.00, 'Mid-term and final examination papers and certifications'),
            (r_school.id, 'School Transit Bus (Zone A)', 'Transportation Fee', 'All Classes', 'Monthly', 2800.00, 'Daily home-to-school transit pick up and drop');
        END IF;

        -- 2. Populate Invoices and Payments for Student Profiles
        FOR r_student IN 
            SELECT id, full_name, roll_number, class 
            FROM public.profiles 
            WHERE school_id = r_school.id AND role = 'student'
            ORDER BY created_at ASC
        LOOP
            v_count := v_count + 1;
            v_seq := v_seq + 1;

            -- Alternate status & plans for realistic diversity
            IF (v_count % 4 = 1) THEN
                v_plan := 'Monthly';
                v_subtotal := 18500.00;
                v_paid := 18500.00;
                v_bal := 0.00;
                v_stat := 'Paid';
            ELSIF (v_count % 4 = 2) THEN
                v_plan := 'Quarterly';
                v_subtotal := 24000.00;
                v_paid := 15000.00;
                v_bal := 9000.00;
                v_stat := 'Partial';
            ELSIF (v_count % 4 = 3) THEN
                v_plan := 'Annual';
                v_subtotal := 45000.00;
                v_paid := 0.00;
                v_bal := 45000.00;
                v_stat := 'Overdue';
            ELSE
                v_plan := 'Monthly';
                v_subtotal := 12500.00;
                v_paid := 0.00;
                v_bal := 12500.00;
                v_stat := 'Pending';
            END IF;

            -- Insert Invoice
            IF NOT EXISTS (SELECT 1 FROM public.student_fee_invoices WHERE school_id = r_school.id AND student_id = r_student.id) THEN
                INSERT INTO public.student_fee_invoices (
                    id, school_id, student_id, invoice_number, title, fee_type, fee_plan, 
                    academic_year, billing_date, due_date, subtotal, concession_amount, 
                    penalty_amount, total_billed, paid_amount, balance_amount, status, notes
                ) VALUES (
                    gen_random_uuid(), r_school.id, r_student.id, 'INV-2026-' || LPAD(v_seq::text, 5, '0'),
                    'Term Tuition & Academic Amenities - ' || v_plan, 'Tuition Fee', v_plan,
                    '2026 - 2027', CURRENT_DATE - INTERVAL '15 days',
                    CASE WHEN v_stat = 'Overdue' THEN CURRENT_DATE - INTERVAL '5 days' ELSE CURRENT_DATE + INTERVAL '15 days' END,
                    v_subtotal, 0.00,
                    CASE WHEN v_stat = 'Overdue' THEN 500.00 ELSE 0.00 END,
                    v_subtotal + CASE WHEN v_stat = 'Overdue' THEN 500.00 ELSE 0.00 END,
                    v_paid,
                    (v_subtotal + CASE WHEN v_stat = 'Overdue' THEN 500.00 ELSE 0.00 END) - v_paid,
                    v_stat, 'Academic Year 2026-2027 invoice for ' || r_student.full_name
                ) RETURNING id INTO v_inv_id;

                -- If paid or partial, add payment receipt record
                IF v_paid > 0 THEN
                    INSERT INTO public.student_fee_payments (
                        school_id, student_id, invoice_id, receipt_number, amount_paid,
                        payment_method, transaction_reference, payment_date, remarks
                    ) VALUES (
                        r_school.id, r_student.id, v_inv_id, 'REC-2026-' || LPAD(v_seq::text, 5, '0'),
                        v_paid, CASE WHEN (v_count % 2 = 0) THEN 'UPI' ELSE 'Bank Transfer (NEFT/RTGS)' END,
                        'TXN' || LPAD(v_seq::text, 8, '0'), NOW() - INTERVAL '5 days',
                        'Payment processed successfully for ' || r_student.full_name
                    );
                END IF;

                -- If overdue, add penalty record
                IF v_stat = 'Overdue' THEN
                    INSERT INTO public.student_fee_penalties (
                        school_id, student_id, invoice_id, penalty_type, amount, reason
                    ) VALUES (
                        r_school.id, r_student.id, v_inv_id, 'Late Payment Fine', 500.00,
                        'Standard grace period expired 5 days ago'
                    );
                END IF;
            END IF;
        END LOOP;


        -- 3. Populate Staff Salary Structures & Payouts for Non-Student Profiles
        FOR r_staff IN 
            SELECT id, full_name, email, role, department, designation, employee_id 
            FROM public.profiles 
            WHERE school_id = r_school.id AND role != 'student'
            ORDER BY created_at ASC
        LOOP
            v_staff_count := v_staff_count + 1;
            
            -- Dynamic salary tier based on role
            IF r_staff.role IN ('super_admin', 'admin') THEN
                v_bpay := 65000.00;
                v_hra  := 26000.00;
                v_da   := 10000.00;
                v_ta   := 6000.00;
            ELSIF r_staff.role = 'teacher' THEN
                v_bpay := 45000.00;
                v_hra  := 18000.00;
                v_da   := 7000.00;
                v_ta   := 4000.00;
            ELSIF r_staff.role IN ('hostel', 'library', 'hr', 'finance') THEN
                v_bpay := 38000.00;
                v_hra  := 15000.00;
                v_da   := 6000.00;
                v_ta   := 3500.00;
            ELSE
                v_bpay := 25000.00;
                v_hra  := 10000.00;
                v_da   := 4000.00;
                v_ta   := 2500.00;
            END IF;

            v_gross := v_bpay + v_hra + v_da + v_ta + 3000.00 + 1500.00; -- special + med
            v_pf    := ROUND(v_bpay * 0.12, 2);
            v_tds   := ROUND(v_gross * 0.05, 2);
            v_ptax  := 200.00;
            v_totded := v_pf + v_tds + v_ptax + 1000.00; -- insurance
            v_net   := v_gross - v_totded;

            -- Upsert Salary Structure
            INSERT INTO public.staff_salary_structures (
                school_id, staff_id, basic_pay, hra, da, ta, special_allowance, 
                medical_allowance, gross_salary, pf_deduction, tds, professional_tax, 
                insurance_deduction, total_deductions, net_salary, payment_mode, 
                bank_name, account_number, ifsc_code, pan_number, status
            ) VALUES (
                r_school.id, r_staff.id, v_bpay, v_hra, v_da, v_ta, 3000.00,
                1500.00, v_gross, v_pf, v_tds, v_ptax, 1000.00, v_totded, v_net,
                'Direct Bank Transfer (NEFT/RTGS)', 'HDFC Bank', '50100234' || LPAD(v_staff_count::text, 4, '0'),
                'HDFC0001824', 'PAN' || LPAD(v_staff_count::text, 6, '0') || 'X', 'ACTIVE'
            ) ON CONFLICT (school_id, staff_id) DO UPDATE SET
                basic_pay = EXCLUDED.basic_pay,
                gross_salary = EXCLUDED.gross_salary,
                net_salary = EXCLUDED.net_salary;

            -- Seed October 2026 Payslip & Disbursal
            INSERT INTO public.staff_salary_payouts (
                school_id, staff_id, payslip_number, month, year, month_str,
                basic_pay, hra, da, ta, special_allowance, bonus, gross_earnings,
                pf_deduction, tds, professional_tax, advance_deduction, other_deductions,
                total_deductions, net_pay, payment_status, payment_date, payment_mode,
                transaction_reference, remarks
            ) VALUES (
                r_school.id, r_staff.id, 'PS-2026-10-' || LPAD(v_staff_count::text, 4, '0'),
                10, 2026, '2026-10',
                v_bpay, v_hra, v_da, v_ta, 3000.00, 0.00, v_gross,
                v_pf, v_tds, v_ptax, 0.00, 1000.00,
                v_totded, v_net,
                CASE WHEN (v_staff_count % 6 = 0) THEN 'Pending' 
                     WHEN (v_staff_count % 11 = 0) THEN 'On Hold' 
                     ELSE 'Paid' END,
                CASE WHEN (v_staff_count % 6 = 0 OR v_staff_count % 11 = 0) THEN NULL ELSE NOW() - INTERVAL '6 days' END,
                'Direct Bank Transfer (NEFT/RTGS)',
                'NEFT' || LPAD(v_staff_count::text, 8, '0'),
                'Monthly salary disbursement for October 2026'
            ) ON CONFLICT (school_id, staff_id, month_str) DO NOTHING;

        END LOOP;

    END LOOP;
END $$;
