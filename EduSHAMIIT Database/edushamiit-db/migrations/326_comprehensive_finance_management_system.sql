-- ============================================================
-- Migration 326: Comprehensive Finance & Fees Management System
-- Robust PostgreSQL Schema for EduSHAMIIT ERP
-- ============================================================

-- 1. Fee Structures Table
CREATE TABLE IF NOT EXISTS public.fee_structures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    academic_year VARCHAR(50) NOT NULL,
    class_id UUID REFERENCES public.classes(id) ON DELETE SET NULL,
    section_id UUID,
    applicable_from DATE,
    applicable_to DATE,
    total_amount NUMERIC(12,2) DEFAULT 0,
    status VARCHAR(50) DEFAULT 'active',
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Fee Structure Head Items
CREATE TABLE IF NOT EXISTS public.fee_structure_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fee_structure_id UUID NOT NULL REFERENCES public.fee_structures(id) ON DELETE CASCADE,
    fee_head VARCHAR(100) NOT NULL, -- Tuition, Transport, Hostel, Exam, Lab, Library, Development, Activity, Miscellaneous
    amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    frequency VARCHAR(50) NOT NULL DEFAULT 'annual', -- One Time, Monthly, Quarterly, Half-Yearly, Annual
    due_date DATE,
    is_optional BOOLEAN DEFAULT FALSE,
    is_refundable BOOLEAN DEFAULT FALSE,
    late_fee_rule JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Fee Structure Installments
CREATE TABLE IF NOT EXISTS public.fee_installments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fee_structure_id UUID NOT NULL REFERENCES public.fee_structures(id) ON DELETE CASCADE,
    installment_name VARCHAR(100) NOT NULL,
    due_date DATE NOT NULL,
    amount NUMERIC(12,2) NOT NULL,
    grace_period_days INT DEFAULT 7,
    late_fee_amount NUMERIC(10,2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Fee Assignments (Linking Fee Demands to Students)
CREATE TABLE IF NOT EXISTS public.fee_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    fee_structure_id UUID REFERENCES public.fee_structures(id) ON DELETE SET NULL,
    academic_year VARCHAR(50) NOT NULL,
    total_demand NUMERIC(12,2) NOT NULL DEFAULT 0,
    total_concession NUMERIC(12,2) DEFAULT 0,
    total_payable NUMERIC(12,2) DEFAULT 0,
    total_paid NUMERIC(12,2) DEFAULT 0,
    total_balance NUMERIC(12,2) DEFAULT 0,
    status VARCHAR(50) DEFAULT 'unpaid', -- unpaid, partial, paid, waived
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.fee_assignments ADD COLUMN IF NOT EXISTS total_payable NUMERIC(12,2) DEFAULT 0;


-- 5. Fee Invoices (Itemized Demands per Fee Head / Installment)
CREATE TABLE IF NOT EXISTS public.fee_invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    invoice_number VARCHAR(100) NOT NULL,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    fee_assignment_id UUID REFERENCES public.fee_assignments(id) ON DELETE CASCADE,
    fee_head VARCHAR(100) NOT NULL,
    academic_year VARCHAR(50) NOT NULL,
    amount_demand NUMERIC(12,2) NOT NULL DEFAULT 0,
    amount_concession NUMERIC(12,2) DEFAULT 0,
    amount_late_fee NUMERIC(12,2) DEFAULT 0,
    amount_payable NUMERIC(12,2) NOT NULL DEFAULT 0,
    amount_paid NUMERIC(12,2) DEFAULT 0,
    amount_balance NUMERIC(12,2) NOT NULL DEFAULT 0,
    due_date DATE NOT NULL,
    status VARCHAR(50) DEFAULT 'unpaid', -- unpaid, partial, paid, overdue, waived, cancelled
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Fee Payments & Transactions
CREATE TABLE IF NOT EXISTS public.fee_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    receipt_number VARCHAR(100) NOT NULL,
    transaction_id VARCHAR(100) NOT NULL,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    amount_paid NUMERIC(12,2) NOT NULL,
    payment_mode VARCHAR(50) NOT NULL, -- cash, upi, card, netbanking, cheque, dd, bank_transfer, gateway
    payment_gateway VARCHAR(50),
    gateway_ref_id VARCHAR(255),
    bank_name VARCHAR(100),
    cheque_dd_no VARCHAR(100),
    cheque_date DATE,
    status VARCHAR(50) DEFAULT 'success', -- pending, success, failed, refunded, cancelled
    collected_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    remarks TEXT,
    paid_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Payment Allocations across Fee Invoices
CREATE TABLE IF NOT EXISTS public.fee_payment_allocations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id UUID NOT NULL REFERENCES public.fee_payments(id) ON DELETE CASCADE,
    invoice_id UUID NOT NULL REFERENCES public.fee_invoices(id) ON DELETE CASCADE,
    allocated_amount NUMERIC(12,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. Concessions & Scholarships
CREATE TABLE IF NOT EXISTS public.fee_concessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    invoice_id UUID REFERENCES public.fee_invoices(id) ON DELETE SET NULL,
    concession_type VARCHAR(100) NOT NULL, -- percentage, fixed, scholarship, sibling, staff_child, merit
    reason TEXT NOT NULL,
    discount_value NUMERIC(12,2) NOT NULL,
    applied_amount NUMERIC(12,2) NOT NULL,
    approved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    status VARCHAR(50) DEFAULT 'approved', -- pending, approved, rejected
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. Fee Refunds
CREATE TABLE IF NOT EXISTS public.fee_refunds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    payment_id UUID REFERENCES public.fee_payments(id) ON DELETE SET NULL,
    refund_number VARCHAR(100) NOT NULL,
    amount NUMERIC(12,2) NOT NULL,
    reason TEXT NOT NULL,
    refund_mode VARCHAR(50) NOT NULL,
    bank_account_details JSONB DEFAULT '{}'::jsonb,
    requested_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    approved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    status VARCHAR(50) DEFAULT 'pending', -- pending, approved, rejected, processed
    processed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 10. Fee Payment Reminders History
CREATE TABLE IF NOT EXISTS public.fee_reminders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    invoice_id UUID REFERENCES public.fee_invoices(id) ON DELETE SET NULL,
    reminder_type VARCHAR(50) NOT NULL, -- upcoming, due_today, overdue, severe
    channel VARCHAR(50) NOT NULL, -- sms, email, whatsapp, push
    status VARCHAR(50) DEFAULT 'sent',
    sent_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    sent_at TIMESTAMPTZ DEFAULT NOW()
);

-- 11. Financial Audit Logs
CREATE TABLE IF NOT EXISTS public.finance_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(100) NOT NULL,
    entity_id VARCHAR(100) NOT NULL,
    previous_value JSONB,
    new_value JSONB,
    reason TEXT,
    ip_address VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 12. Payment Gateway & Bank Reconciliation Records
CREATE TABLE IF NOT EXISTS public.payment_reconciliation_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    transaction_id VARCHAR(100) NOT NULL,
    gateway_ref_id VARCHAR(255),
    erp_amount NUMERIC(12,2) NOT NULL,
    gateway_amount NUMERIC(12,2) NOT NULL,
    bank_amount NUMERIC(12,2),
    status VARCHAR(50) DEFAULT 'matched', -- matched, unmatched, disputed, duplicate
    reconciled_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    reconciled_at TIMESTAMPTZ DEFAULT NOW()
);

-- Essential Performance Indexes
CREATE INDEX IF NOT EXISTS idx_fee_structures_school ON public.fee_structures(school_id, academic_year);
CREATE INDEX IF NOT EXISTS idx_fee_invoices_student ON public.fee_invoices(school_id, student_id, status);
CREATE INDEX IF NOT EXISTS idx_fee_invoices_due_date ON public.fee_invoices(due_date);
CREATE INDEX IF NOT EXISTS idx_fee_invoices_number ON public.fee_invoices(invoice_number);
CREATE INDEX IF NOT EXISTS idx_fee_payments_student ON public.fee_payments(school_id, student_id);
CREATE INDEX IF NOT EXISTS idx_fee_payments_receipt ON public.fee_payments(receipt_number);
CREATE INDEX IF NOT EXISTS idx_fee_payments_txn ON public.fee_payments(transaction_id);
CREATE INDEX IF NOT EXISTS idx_fee_assignments_student ON public.fee_assignments(school_id, student_id);
CREATE INDEX IF NOT EXISTS idx_fee_concessions_student ON public.fee_concessions(school_id, student_id);
CREATE INDEX IF NOT EXISTS idx_fee_refunds_student ON public.fee_refunds(school_id, student_id);
