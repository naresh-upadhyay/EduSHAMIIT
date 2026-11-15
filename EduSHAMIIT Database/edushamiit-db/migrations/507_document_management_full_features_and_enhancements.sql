-- ============================================================================
-- Migration: 507_document_management_full_features_and_enhancements.sql
-- Description:
--   1. Ensure all columns, constraints, and defaults on user_documents,
--      document_folders, document_shares, document_versions, document_requests,
--      document_approvals, and document_recent_activity.
--   2. High-performance composite indexes for instant searching, filtering,
--      and multi-tenant isolation.
--   3. Stored procedures for emptying trash and bulk document restoration.
-- ============================================================================

-- 1. Ensure user_documents schema integrity
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_documents' AND column_name = 'approval_status') THEN
        ALTER TABLE public.user_documents ADD COLUMN approval_status TEXT DEFAULT 'Approved';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_documents' AND column_name = 'approval_notes') THEN
        ALTER TABLE public.user_documents ADD COLUMN approval_notes TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_documents' AND column_name = 'expiry_date') THEN
        ALTER TABLE public.user_documents ADD COLUMN expiry_date DATE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_documents' AND column_name = 'department') THEN
        ALTER TABLE public.user_documents ADD COLUMN department TEXT DEFAULT 'All';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_documents' AND column_name = 'tags') THEN
        ALTER TABLE public.user_documents ADD COLUMN tags TEXT[] DEFAULT ARRAY[]::TEXT[];
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_documents' AND column_name = 'is_starred') THEN
        ALTER TABLE public.user_documents ADD COLUMN is_starred BOOLEAN DEFAULT FALSE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_documents' AND column_name = 'is_deleted') THEN
        ALTER TABLE public.user_documents ADD COLUMN is_deleted BOOLEAN DEFAULT FALSE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_documents' AND column_name = 'deleted_at') THEN
        ALTER TABLE public.user_documents ADD COLUMN deleted_at TIMESTAMPTZ;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_documents' AND column_name = 'is_archived') THEN
        ALTER TABLE public.user_documents ADD COLUMN is_archived BOOLEAN DEFAULT FALSE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_documents' AND column_name = 'version_number') THEN
        ALTER TABLE public.user_documents ADD COLUMN version_number INT DEFAULT 1;
    END IF;
END $$;

-- 2. Ensure document_requests table integrity
CREATE TABLE IF NOT EXISTS public.document_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id TEXT NOT NULL,
    requester_id UUID,
    assigned_to_id UUID,
    title TEXT NOT NULL,
    description TEXT,
    category TEXT DEFAULT 'General',
    priority TEXT DEFAULT 'Medium',
    required_by_date DATE,
    status TEXT DEFAULT 'Pending',
    fulfilled_document_id UUID,
    response_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Ensure document_approvals table integrity
CREATE TABLE IF NOT EXISTS public.document_approvals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL,
    school_id TEXT NOT NULL,
    requester_id UUID,
    approver_id UUID,
    approver_role TEXT,
    status TEXT DEFAULT 'Pending',
    comments TEXT,
    rejection_reason TEXT,
    submitted_at TIMESTAMPTZ DEFAULT NOW(),
    reviewed_at TIMESTAMPTZ
);

-- 4. High-performance composite indexes
CREATE INDEX IF NOT EXISTS idx_user_docs_school_deleted_created 
    ON public.user_documents(school_id, is_deleted, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_docs_school_owner 
    ON public.user_documents(school_id, owner_id) 
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_user_docs_school_folder 
    ON public.user_documents(school_id, folder_id) 
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_user_docs_school_starred 
    ON public.user_documents(school_id, is_starred) 
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_user_docs_school_approval 
    ON public.user_documents(school_id, approval_status) 
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_doc_shares_doc_target 
    ON public.document_shares(document_id, target_id);

CREATE INDEX IF NOT EXISTS idx_doc_shares_school_target 
    ON public.document_shares(school_id, target_id);

CREATE INDEX IF NOT EXISTS idx_doc_recent_user_accessed 
    ON public.document_recent_activity(user_id, accessed_at DESC);

CREATE INDEX IF NOT EXISTS idx_doc_requests_school_status 
    ON public.document_requests(school_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_doc_approvals_school_status 
    ON public.document_approvals(school_id, status, submitted_at DESC);

-- 5. Helper Function: Restore Trashed Document
CREATE OR REPLACE FUNCTION public.rpc_restore_trashed_document(
    p_document_id UUID,
    p_school_id TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.user_documents
    SET is_deleted = FALSE,
        deleted_at = NULL,
        updated_at = NOW()
    WHERE id = p_document_id 
      AND school_id = p_school_id 
      AND is_deleted = TRUE;

    RETURN FOUND;
END;
$$;

-- 6. Helper Function: Empty Trashed Documents for a School
CREATE OR REPLACE FUNCTION public.rpc_empty_school_trash(
    p_school_id TEXT
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_deleted_count INT := 0;
BEGIN
    DELETE FROM public.user_documents
    WHERE school_id = p_school_id AND is_deleted = TRUE;

    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    RETURN v_deleted_count;
END;
$$;

-- Permissions and reload schema
GRANT EXECUTE ON FUNCTION public.rpc_restore_trashed_document(UUID, TEXT) TO anon, authenticated, service_role, postgres;
GRANT EXECUTE ON FUNCTION public.rpc_empty_school_trash(TEXT) TO anon, authenticated, service_role, postgres;
NOTIFY pgrst, 'reload schema';

