-- ============================================================================
-- Migration: 351_hr_policies_and_documents_system.sql
-- Module: HR Management -> Policies & Documents (Production Enterprise)
-- Description: Complete schema for Policy Management, Policy Versions, 
--              Audience & Applicability, Version-Tied Acknowledgements,
--              Approvals & Lifecycle Workflow, Document Library, Document Versions,
--              Access Control, Templates, and Comprehensive Audit Trail.
-- ============================================================================

-- 1. HR DOCUMENT & POLICY CATEGORIES
CREATE TABLE IF NOT EXISTS public.hr_document_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    code TEXT NOT NULL,
    description TEXT,
    icon TEXT DEFAULT 'folder_outlined',
    color_hex TEXT DEFAULT '#4F46E5',
    bg_color_hex TEXT DEFAULT '#EEF2FF',
    sort_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    is_system BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    CONSTRAINT uq_hr_cat_school_code UNIQUE (school_id, code)
);

-- 2. HR POLICIES TABLE
CREATE TABLE IF NOT EXISTS public.hr_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    policy_code TEXT NOT NULL,
    title TEXT NOT NULL,
    category_id UUID REFERENCES public.hr_document_categories(id) ON DELETE SET NULL,
    category_name TEXT NOT NULL DEFAULT 'General',
    description TEXT,
    department TEXT DEFAULT 'All Departments',
    policy_owner_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    policy_owner_name TEXT,
    current_version TEXT NOT NULL DEFAULT '1.0',
    status TEXT NOT NULL DEFAULT 'DRAFT' CHECK (
        status IN ('DRAFT', 'PENDING_REVIEW', 'APPROVED', 'PUBLISHED', 'ACTIVE', 'SCHEDULED', 'EXPIRED', 'ARCHIVED', 'REJECTED')
    ),
    rejection_reason TEXT,
    effective_date DATE,
    review_date DATE,
    expiry_date DATE,
    review_frequency_months INT DEFAULT 12,
    
    -- Applicability
    audience_type TEXT DEFAULT 'Entire Institute' CHECK (
        audience_type IN ('Entire Institute', 'Specific Branch', 'Department', 'Designation', 'Employment Type', 'Selected Users')
    ),
    
    -- Acknowledgement configuration
    acknowledgement_required BOOLEAN DEFAULT false,
    acknowledgement_mandatory BOOLEAN DEFAULT false,
    acknowledgement_deadline DATE,
    allow_digital_acknowledgement BOOLEAN DEFAULT true,
    
    -- Lifecycle timestamps
    published_at TIMESTAMPTZ,
    scheduled_publish_at TIMESTAMPTZ,
    archived_at TIMESTAMPTZ,
    is_deleted BOOLEAN DEFAULT false,
    deleted_at TIMESTAMPTZ,
    
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    CONSTRAINT uq_hr_policy_school_code UNIQUE (school_id, policy_code)
);

-- 3. HR POLICY VERSIONS TABLE (Immutable version history)
CREATE TABLE IF NOT EXISTS public.hr_policy_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    policy_id UUID NOT NULL REFERENCES public.hr_policies(id) ON DELETE CASCADE,
    version_number TEXT NOT NULL, -- e.g. '1.0', '1.1', '2.0'
    title TEXT NOT NULL,
    description TEXT,
    content_html TEXT, -- Rich text content
    content_json JSONB DEFAULT '{}'::jsonb,
    change_summary TEXT,
    status TEXT NOT NULL DEFAULT 'DRAFT',
    effective_date DATE,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_by_name TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    CONSTRAINT uq_hr_policy_version UNIQUE (policy_id, version_number)
);

-- 4. HR POLICY ATTACHMENTS TABLE
CREATE TABLE IF NOT EXISTS public.hr_policy_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    policy_id UUID NOT NULL REFERENCES public.hr_policies(id) ON DELETE CASCADE,
    version_id UUID REFERENCES public.hr_policy_versions(id) ON DELETE CASCADE,
    file_name TEXT NOT NULL,
    file_type TEXT NOT NULL DEFAULT 'PDF',
    file_size_bytes BIGINT DEFAULT 0,
    storage_path TEXT NOT NULL,
    download_url TEXT,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 5. HR POLICY AUDIENCE TABLE (Detailed targeting mapping)
CREATE TABLE IF NOT EXISTS public.hr_policy_audience (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    policy_id UUID NOT NULL REFERENCES public.hr_policies(id) ON DELETE CASCADE,
    target_type TEXT NOT NULL, -- 'INSTITUTE', 'BRANCH', 'DEPARTMENT', 'DESIGNATION', 'EMPLOYMENT_TYPE', 'USER'
    target_value TEXT NOT NULL, -- e.g. 'Academics', 'Teacher', 'Full-time', or profile UUID
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 6. HR POLICY ACKNOWLEDGEMENTS TABLE (Version-Tied Sign-Off)
CREATE TABLE IF NOT EXISTS public.hr_policy_acknowledgements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    policy_id UUID NOT NULL REFERENCES public.hr_policies(id) ON DELETE CASCADE,
    version_number TEXT NOT NULL,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    user_name TEXT,
    user_email TEXT,
    user_role TEXT,
    department TEXT,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    deadline DATE,
    status TEXT NOT NULL DEFAULT 'PENDING' CHECK (
        status IN ('PENDING', 'VIEWED', 'ACKNOWLEDGED', 'OVERDUE', 'DECLINED')
    ),
    is_mandatory BOOLEAN DEFAULT true,
    viewed_at TIMESTAMPTZ,
    acknowledged_at TIMESTAMPTZ,
    signature_text TEXT,
    ip_address TEXT,
    user_agent TEXT,
    comment TEXT,
    reminder_count INT DEFAULT 0,
    last_reminder_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    CONSTRAINT uq_policy_version_user_ack UNIQUE (policy_id, version_number, user_id)
);

-- 7. HR POLICY APPROVALS / WORKFLOW AUDIT
CREATE TABLE IF NOT EXISTS public.hr_policy_approvals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    policy_id UUID NOT NULL REFERENCES public.hr_policies(id) ON DELETE CASCADE,
    version_number TEXT NOT NULL,
    from_status TEXT NOT NULL,
    to_status TEXT NOT NULL,
    performed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    performer_name TEXT,
    performer_role TEXT,
    comments TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 8. HR DOCUMENTS TABLE (Document Management Library)
CREATE TABLE IF NOT EXISTS public.hr_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    document_name TEXT NOT NULL,
    document_code TEXT,
    document_type TEXT NOT NULL DEFAULT 'HR Document' CHECK (
        document_type IN (
            'Employee Document', 'HR Document', 'Compliance Document', 'Certificate',
            'Contract', 'Joining Document', 'Identity/Verification', 'Training Certificate',
            'Medical/Fitness', 'Legal Document', 'Template', 'Other'
        )
    ),
    category_id UUID REFERENCES public.hr_document_categories(id) ON DELETE SET NULL,
    category_name TEXT NOT NULL DEFAULT 'General',
    description TEXT,
    owner_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    owner_name TEXT,
    department TEXT DEFAULT 'All Departments',
    linked_employee_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    linked_employee_name TEXT,
    linked_policy_id UUID REFERENCES public.hr_policies(id) ON DELETE SET NULL,
    
    -- File specifics of active version
    current_version TEXT NOT NULL DEFAULT '1.0',
    file_name TEXT,
    file_extension TEXT,
    file_type TEXT DEFAULT 'PDF',
    file_size_bytes BIGINT DEFAULT 0,
    storage_path TEXT,
    download_url TEXT,
    
    -- Access control & tags
    access_level TEXT NOT NULL DEFAULT 'INSTITUTE_WIDE' CHECK (
        access_level IN ('PRIVATE', 'HR_ONLY', 'MANAGEMENT', 'DEPARTMENT', 'SELECTED_USERS', 'INSTITUTE_WIDE')
    ),
    tags TEXT[] DEFAULT '{}',
    
    -- Expiry & Review lifecycle
    issue_date DATE,
    expiry_date DATE,
    review_date DATE,
    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (
        status IN ('ACTIVE', 'EXPIRING_SOON', 'EXPIRED', 'REVIEW_DUE', 'ARCHIVED')
    ),
    
    is_archived BOOLEAN DEFAULT false,
    archived_at TIMESTAMPTZ,
    is_deleted BOOLEAN DEFAULT false,
    deleted_at TIMESTAMPTZ,
    
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 9. HR DOCUMENT VERSIONS TABLE
CREATE TABLE IF NOT EXISTS public.hr_document_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    document_id UUID NOT NULL REFERENCES public.hr_documents(id) ON DELETE CASCADE,
    version_number TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_extension TEXT,
    file_size_bytes BIGINT DEFAULT 0,
    storage_path TEXT NOT NULL,
    change_summary TEXT,
    uploaded_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    uploaded_by_name TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    CONSTRAINT uq_hr_doc_version UNIQUE (document_id, version_number)
);

-- 10. HR DOCUMENT ACCESS PERMISSIONS (Restricted documents)
CREATE TABLE IF NOT EXISTS public.hr_document_access (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    document_id UUID NOT NULL REFERENCES public.hr_documents(id) ON DELETE CASCADE,
    grantee_type TEXT NOT NULL CHECK (grantee_type IN ('USER', 'ROLE', 'DEPARTMENT')),
    grantee_id TEXT NOT NULL, -- user profile UUID, role name (e.g. 'hr', 'teacher'), or department name
    can_view BOOLEAN DEFAULT true,
    can_download BOOLEAN DEFAULT true,
    can_edit BOOLEAN DEFAULT false,
    granted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 11. HR DOCUMENT & LETTER TEMPLATES
CREATE TABLE IF NOT EXISTS public.hr_document_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    template_code TEXT NOT NULL,
    template_name TEXT NOT NULL,
    template_type TEXT NOT NULL DEFAULT 'Offer Letter' CHECK (
        template_type IN (
            'Offer Letter', 'Appointment Letter', 'Warning Letter', 'Experience Letter',
            'Relieving Letter', 'NDA', 'Code of Conduct', 'Joining Checklist', 'HR Forms', 'Custom'
        )
    ),
    description TEXT,
    category_id UUID REFERENCES public.hr_document_categories(id) ON DELETE SET NULL,
    category_name TEXT DEFAULT 'General',
    content_html TEXT,
    variables JSONB DEFAULT '[]'::jsonb, -- e.g. ["employee_name", "employee_id", "designation", "department", "joining_date", "institution_name"]
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    CONSTRAINT uq_hr_template_school_code UNIQUE (school_id, template_code)
);

-- 12. HR POLICIES & DOCUMENTS ACTIVITY / AUDIT LOG
CREATE TABLE IF NOT EXISTS public.hr_document_activity (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    entity_type TEXT NOT NULL CHECK (entity_type IN ('POLICY', 'DOCUMENT', 'ACKNOWLEDGEMENT', 'TEMPLATE', 'CATEGORY')),
    entity_id UUID NOT NULL,
    action TEXT NOT NULL, -- 'Created', 'Updated', 'Published', 'Approved', 'Rejected', 'Archived', 'Uploaded', 'Downloaded', 'Replaced', 'Acknowledged', 'Reminded'
    old_value JSONB,
    new_value JSONB,
    performed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    performer_name TEXT,
    performer_role TEXT,
    ip_address TEXT,
    user_agent TEXT,
    summary TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- ============================================================================
-- INDEXES FOR HIGH-PERFORMANCE SEARCH, FILTERS, AND PAGINATION
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_hr_policies_school_status ON public.hr_policies(school_id, status);
CREATE INDEX IF NOT EXISTS idx_hr_policies_category ON public.hr_policies(school_id, category_id);
CREATE INDEX IF NOT EXISTS idx_hr_policies_owner ON public.hr_policies(school_id, policy_owner_id);
CREATE INDEX IF NOT EXISTS idx_hr_policies_dates ON public.hr_policies(effective_date, review_date, expiry_date);

CREATE INDEX IF NOT EXISTS idx_hr_docs_school_status ON public.hr_documents(school_id, status);
CREATE INDEX IF NOT EXISTS idx_hr_docs_category ON public.hr_documents(school_id, category_id);
CREATE INDEX IF NOT EXISTS idx_hr_docs_employee ON public.hr_documents(school_id, linked_employee_id);
CREATE INDEX IF NOT EXISTS idx_hr_docs_dates ON public.hr_documents(expiry_date, review_date);
CREATE INDEX IF NOT EXISTS idx_hr_docs_access ON public.hr_documents(school_id, access_level);

CREATE INDEX IF NOT EXISTS idx_hr_acks_policy_ver ON public.hr_policy_acknowledgements(policy_id, version_number);
CREATE INDEX IF NOT EXISTS idx_hr_acks_user_status ON public.hr_policy_acknowledgements(school_id, user_id, status);
CREATE INDEX IF NOT EXISTS idx_hr_acks_deadline ON public.hr_policy_acknowledgements(deadline, status);

CREATE INDEX IF NOT EXISTS idx_hr_act_entity ON public.hr_document_activity(school_id, entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_hr_act_created ON public.hr_document_activity(created_at DESC);
