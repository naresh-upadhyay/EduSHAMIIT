-- Migration 327: Enterprise Accounting, Payroll, Expenses, Banking & Financial Management System
-- Schema for Double-Entry Bookkeeping, Chart of Accounts, Journal Entries, Payroll, Expenses, Vendors, Bank Accounts, Assets, Budgets, Financial Years.

-- 1. Financial Years
CREATE TABLE IF NOT EXISTS financial_years (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL,
    year_name VARCHAR(20) NOT NULL, -- e.g. '2026-27'
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_current BOOLEAN DEFAULT FALSE,
    is_closed BOOLEAN DEFAULT FALSE,
    closed_at TIMESTAMP WITH TIME ZONE,
    closed_by UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_fin_year_school ON financial_years(school_id, is_current);

-- 2. Chart of Accounts
CREATE TABLE IF NOT EXISTS chart_of_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL,
    account_code VARCHAR(50) NOT NULL,
    account_name VARCHAR(255) NOT NULL,
    account_type VARCHAR(50) NOT NULL, -- 'ASSET', 'LIABILITY', 'EQUITY', 'INCOME', 'EXPENSE'
    parent_id UUID REFERENCES chart_of_accounts(id) ON DELETE SET NULL,
    is_active BOOLEAN DEFAULT TRUE,
    is_system_account BOOLEAN DEFAULT FALSE,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_school_account_code UNIQUE (school_id, account_code)
);

CREATE INDEX IF NOT EXISTS idx_coa_school_type ON chart_of_accounts(school_id, account_type);

-- 3. Accounting Journal Entries & Items (Double-Entry Engine)
CREATE TABLE IF NOT EXISTS accounting_journal_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL,
    entry_number VARCHAR(100) NOT NULL,
    entry_date DATE NOT NULL,
    financial_year VARCHAR(20) NOT NULL DEFAULT '2026-27',
    source_module VARCHAR(50) NOT NULL, -- 'FEES', 'EXPENSE', 'PAYROLL', 'INCOME', 'BANK_TRANSFER', 'MANUAL'
    source_reference_id VARCHAR(255),
    description TEXT,
    total_debit NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    total_credit NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    status VARCHAR(30) DEFAULT 'POSTED', -- 'POSTED', 'DRAFT', 'REVERSED', 'CANCELLED'
    created_by UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_debit_equals_credit CHECK (total_debit = total_credit)
);

CREATE INDEX IF NOT EXISTS idx_journal_school_date ON accounting_journal_entries(school_id, entry_date);
CREATE INDEX IF NOT EXISTS idx_journal_source ON accounting_journal_entries(school_id, source_module, source_reference_id);

CREATE TABLE IF NOT EXISTS accounting_journal_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    journal_entry_id UUID NOT NULL REFERENCES accounting_journal_entries(id) ON DELETE CASCADE,
    account_id UUID NOT NULL REFERENCES chart_of_accounts(id),
    debit_amount NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    credit_amount NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    narration TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_journal_items_account ON accounting_journal_items(account_id);

-- 4. Staff Salary Structures & Monthly Payroll
CREATE TABLE IF NOT EXISTS staff_salary_structures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL,
    staff_id UUID NOT NULL,
    basic_salary NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    hra NUMERIC(15, 2) DEFAULT 0.00,
    special_allowance NUMERIC(15, 2) DEFAULT 0.00,
    conveyance_allowance NUMERIC(15, 2) DEFAULT 0.00,
    pf_deduction NUMERIC(15, 2) DEFAULT 0.00,
    esi_deduction NUMERIC(15, 2) DEFAULT 0.00,
    tds_deduction NUMERIC(15, 2) DEFAULT 0.00,
    other_deductions NUMERIC(15, 2) DEFAULT 0.00,
    net_salary NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    effective_from DATE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_staff_salary UNIQUE (school_id, staff_id)
);

CREATE TABLE IF NOT EXISTS payroll_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL,
    payroll_month VARCHAR(20) NOT NULL, -- e.g. '2026-08'
    total_staff INT DEFAULT 0,
    total_gross NUMERIC(15, 2) DEFAULT 0.00,
    total_deductions NUMERIC(15, 2) DEFAULT 0.00,
    total_net NUMERIC(15, 2) DEFAULT 0.00,
    status VARCHAR(30) DEFAULT 'DRAFT', -- 'DRAFT', 'APPROVED', 'PROCESSED', 'PAID'
    processed_at TIMESTAMP WITH TIME ZONE,
    processed_by UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_payroll_school_month ON payroll_runs(school_id, payroll_month);

CREATE TABLE IF NOT EXISTS payslips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payroll_run_id UUID NOT NULL REFERENCES payroll_runs(id) ON DELETE CASCADE,
    school_id UUID NOT NULL,
    staff_id UUID NOT NULL,
    payslip_number VARCHAR(100) NOT NULL,
    basic_salary NUMERIC(15, 2) DEFAULT 0.00,
    allowances NUMERIC(15, 2) DEFAULT 0.00,
    deductions NUMERIC(15, 2) DEFAULT 0.00,
    net_payable NUMERIC(15, 2) DEFAULT 0.00,
    payment_mode VARCHAR(30) DEFAULT 'BANK_TRANSFER',
    payment_status VARCHAR(30) DEFAULT 'UNPAID', -- 'UNPAID', 'PAID'
    paid_at TIMESTAMP WITH TIME ZONE,
    transaction_reference VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_payslips_staff ON payslips(school_id, staff_id);

-- 5. Vendors & Supplier Payables
CREATE TABLE IF NOT EXISTS vendors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL,
    vendor_name VARCHAR(255) NOT NULL,
    category VARCHAR(100) DEFAULT 'General Supplier',
    contact_person VARCHAR(150),
    phone VARCHAR(50),
    email VARCHAR(150),
    gst_number VARCHAR(50),
    bank_name VARCHAR(100),
    bank_account_number VARCHAR(100),
    ifsc_code VARCHAR(50),
    address TEXT,
    outstanding_payable NUMERIC(15, 2) DEFAULT 0.00,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_vendors_school ON vendors(school_id);

-- 6. Expense Categories & Expenses (with Approval Flow)
CREATE TABLE IF NOT EXISTS expense_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL,
    category_name VARCHAR(100) NOT NULL,
    code VARCHAR(50),
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL,
    expense_number VARCHAR(100) NOT NULL,
    category_id UUID REFERENCES expense_categories(id),
    vendor_id UUID REFERENCES vendors(id),
    title VARCHAR(255) NOT NULL,
    amount NUMERIC(15, 2) NOT NULL,
    tax_amount NUMERIC(15, 2) DEFAULT 0.00,
    total_amount NUMERIC(15, 2) NOT NULL,
    expense_date DATE NOT NULL,
    payment_mode VARCHAR(30) DEFAULT 'CASH', -- 'CASH', 'BANK_TRANSFER', 'CHEQUE', 'CARD', 'UPI'
    status VARCHAR(30) DEFAULT 'SUBMITTED', -- 'DRAFT', 'SUBMITTED', 'APPROVED', 'PAID', 'REJECTED', 'CANCELLED'
    submitted_by UUID,
    approved_by UUID,
    approved_at TIMESTAMP WITH TIME ZONE,
    paid_at TIMESTAMP WITH TIME ZONE,
    attachment_url TEXT,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_expenses_school_date ON expenses(school_id, expense_date);
CREATE INDEX IF NOT EXISTS idx_expenses_status ON expenses(school_id, status);

-- 7. Non-Fee Institutional Income
CREATE TABLE IF NOT EXISTS income_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL,
    income_number VARCHAR(100) NOT NULL,
    income_category VARCHAR(100) NOT NULL, -- 'Transport', 'Hostel', 'Rental', 'Donation', 'Grant', 'Event', 'Misc'
    title VARCHAR(255) NOT NULL,
    amount NUMERIC(15, 2) NOT NULL,
    income_date DATE NOT NULL,
    payment_mode VARCHAR(30) DEFAULT 'BANK_TRANSFER',
    received_from VARCHAR(255),
    reference_number VARCHAR(100),
    description TEXT,
    received_by UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_income_school_date ON income_records(school_id, income_date);

-- 8. Banking & Cash Accounts
CREATE TABLE IF NOT EXISTS bank_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL,
    account_name VARCHAR(150) NOT NULL,
    bank_name VARCHAR(150) NOT NULL,
    account_number VARCHAR(100) NOT NULL,
    ifsc_code VARCHAR(50),
    branch VARCHAR(100),
    account_type VARCHAR(50) DEFAULT 'SAVINGS', -- 'SAVINGS', 'CURRENT', 'CASH_DRAWER'
    opening_balance NUMERIC(15, 2) DEFAULT 0.00,
    current_balance NUMERIC(15, 2) DEFAULT 0.00,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_bank_accounts_school ON bank_accounts(school_id);

CREATE TABLE IF NOT EXISTS bank_transfers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL,
    transfer_number VARCHAR(100) NOT NULL,
    from_account_id UUID NOT NULL REFERENCES bank_accounts(id),
    to_account_id UUID NOT NULL REFERENCES bank_accounts(id),
    amount NUMERIC(15, 2) NOT NULL,
    transfer_date DATE NOT NULL,
    reference_number VARCHAR(100),
    remarks TEXT,
    initiated_by UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 9. Fixed Assets & Depreciation
CREATE TABLE IF NOT EXISTS fixed_assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL,
    asset_code VARCHAR(50) NOT NULL,
    asset_name VARCHAR(255) NOT NULL,
    category VARCHAR(100) DEFAULT 'Equipment',
    purchase_date DATE NOT NULL,
    purchase_cost NUMERIC(15, 2) NOT NULL,
    vendor_id UUID REFERENCES vendors(id),
    depreciation_rate NUMERIC(5, 2) DEFAULT 10.00, -- percentage per year
    current_value NUMERIC(15, 2) NOT NULL,
    department VARCHAR(100),
    status VARCHAR(30) DEFAULT 'ACTIVE', -- 'ACTIVE', 'TRANSFERRED', 'DISPOSED'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_assets_school ON fixed_assets(school_id);

-- 10. Departmental Budgets
CREATE TABLE IF NOT EXISTS budgets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL,
    financial_year VARCHAR(20) NOT NULL DEFAULT '2026-27',
    department VARCHAR(100) NOT NULL,
    category_name VARCHAR(100) NOT NULL,
    allocated_amount NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    spent_amount NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_budget_dept_cat UNIQUE (school_id, financial_year, department, category_name)
);

CREATE INDEX IF NOT EXISTS idx_budgets_school_year ON budgets(school_id, financial_year);
