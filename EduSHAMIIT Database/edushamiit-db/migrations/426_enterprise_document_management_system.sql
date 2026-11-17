-- ============================================================================
-- Migration 426: Complete Enterprise Document Management System
-- EduSHAMIIT — Shami Innovation and Technologies LLP
-- ============================================================================

-- 1. Create document_folders table
CREATE TABLE IF NOT EXISTS document_folders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id TEXT NOT NULL,
    parent_id UUID REFERENCES document_folders(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    category TEXT,
    color TEXT DEFAULT '#2563EB',
    icon TEXT DEFAULT 'folder',
    owner_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    is_system BOOLEAN DEFAULT FALSE,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_document_folders_school_parent ON document_folders(school_id, parent_id);
CREATE INDEX IF NOT EXISTS idx_document_folders_is_deleted ON document_folders(school_id, is_deleted);

-- 2. Alter user_documents table safely
-- Drop restrictive category check constraint if it exists
DO $$
BEGIN
    ALTER TABLE user_documents DROP CONSTRAINT IF EXISTS user_documents_category_check;
EXCEPTION
    WHEN OTHERS THEN NULL;
END $$;

ALTER TABLE user_documents ADD COLUMN IF NOT EXISTS folder_id UUID REFERENCES document_folders(id) ON DELETE SET NULL;
ALTER TABLE user_documents ADD COLUMN IF NOT EXISTS department TEXT DEFAULT 'All';
ALTER TABLE user_documents ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}';
ALTER TABLE user_documents ADD COLUMN IF NOT EXISTS file_type TEXT DEFAULT 'PDF';
ALTER TABLE user_documents ADD COLUMN IF NOT EXISTS access_type TEXT DEFAULT 'Viewer';
ALTER TABLE user_documents ADD COLUMN IF NOT EXISTS approval_status TEXT DEFAULT 'Approved';
ALTER TABLE user_documents ADD COLUMN IF NOT EXISTS approval_notes TEXT;
ALTER TABLE user_documents ADD COLUMN IF NOT EXISTS version_number INT DEFAULT 1;
ALTER TABLE user_documents ADD COLUMN IF NOT EXISTS current_version_id UUID;
ALTER TABLE user_documents ADD COLUMN IF NOT EXISTS is_starred BOOLEAN DEFAULT FALSE;
ALTER TABLE user_documents ADD COLUMN IF NOT EXISTS is_archived BOOLEAN DEFAULT FALSE;
ALTER TABLE user_documents ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT FALSE;
ALTER TABLE user_documents ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE user_documents ADD COLUMN IF NOT EXISTS deleted_by_id UUID REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE user_documents ADD COLUMN IF NOT EXISTS expiry_date DATE;
ALTER TABLE user_documents ADD COLUMN IF NOT EXISTS responsible_person_id UUID REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE user_documents ADD COLUMN IF NOT EXISTS module_key TEXT;
ALTER TABLE user_documents ADD COLUMN IF NOT EXISTS entity_type TEXT;
ALTER TABLE user_documents ADD COLUMN IF NOT EXISTS entity_id TEXT;
ALTER TABLE user_documents ADD COLUMN IF NOT EXISTS download_count INT DEFAULT 0;
ALTER TABLE user_documents ADD COLUMN IF NOT EXISTS preview_count INT DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_user_documents_school_folder ON user_documents(school_id, folder_id);
CREATE INDEX IF NOT EXISTS idx_user_documents_school_deleted ON user_documents(school_id, is_deleted);
CREATE INDEX IF NOT EXISTS idx_user_documents_school_approval ON user_documents(school_id, approval_status);
CREATE INDEX IF NOT EXISTS idx_user_documents_school_category ON user_documents(school_id, category);

-- 3. Create document_shares table
CREATE TABLE IF NOT EXISTS document_shares (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID REFERENCES user_documents(id) ON DELETE CASCADE,
    folder_id UUID REFERENCES document_folders(id) ON DELETE CASCADE,
    school_id TEXT NOT NULL,
    shared_by_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    share_type TEXT NOT NULL DEFAULT 'user' CHECK (share_type IN ('user', 'role', 'department', 'class', 'public')),
    target_id TEXT,
    target_name TEXT,
    permission_level TEXT NOT NULL DEFAULT 'Viewer' CHECK (permission_level IN ('Viewer', 'Commenter', 'Editor', 'Manager')),
    allow_download BOOLEAN DEFAULT TRUE,
    allow_print BOOLEAN DEFAULT TRUE,
    expiry_date TIMESTAMPTZ,
    access_token TEXT,
    password_hash TEXT,
    message TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_document_shares_doc ON document_shares(document_id);
CREATE INDEX IF NOT EXISTS idx_document_shares_target ON document_shares(school_id, share_type, target_id);

-- 4. Create document_versions table
CREATE TABLE IF NOT EXISTS document_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL REFERENCES user_documents(id) ON DELETE CASCADE,
    version_number INT NOT NULL,
    file_url TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_size BIGINT DEFAULT 0,
    mime_type TEXT,
    storage_path TEXT,
    checksum TEXT,
    change_summary TEXT,
    uploaded_by_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_document_versions_doc ON document_versions(document_id, version_number DESC);

-- 5. Create document_approvals table
CREATE TABLE IF NOT EXISTS document_approvals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL REFERENCES user_documents(id) ON DELETE CASCADE,
    school_id TEXT NOT NULL,
    requester_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    approver_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    approver_role TEXT,
    status TEXT NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending', 'In Review', 'Approved', 'Rejected', 'Changes Requested')),
    comments TEXT,
    rejection_reason TEXT,
    submitted_at TIMESTAMPTZ DEFAULT now(),
    reviewed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_document_approvals_school ON document_approvals(school_id, status);

-- 6. Create document_requests table
CREATE TABLE IF NOT EXISTS document_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id TEXT NOT NULL,
    requester_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    assigned_to_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT,
    category TEXT NOT NULL,
    priority TEXT DEFAULT 'Medium' CHECK (priority IN ('Low', 'Medium', 'High', 'Urgent')),
    required_by_date DATE,
    status TEXT NOT NULL DEFAULT 'New' CHECK (status IN ('New', 'In Progress', 'Awaiting Information', 'Fulfilled', 'Rejected', 'Cancelled')),
    fulfilled_document_id UUID REFERENCES user_documents(id) ON DELETE SET NULL,
    response_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_document_requests_school ON document_requests(school_id, status);

-- 7. Create document_activity_logs table
CREATE TABLE IF NOT EXISTS document_activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id TEXT NOT NULL,
    document_id UUID REFERENCES user_documents(id) ON DELETE CASCADE,
    folder_id UUID REFERENCES document_folders(id) ON DELETE CASCADE,
    user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    action_details JSONB DEFAULT '{}'::jsonb,
    ip_address TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_document_activity_logs_doc ON document_activity_logs(document_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_document_activity_logs_school ON document_activity_logs(school_id, created_at DESC);

-- 8. Create document_favorites table (per-user starred documents)
CREATE TABLE IF NOT EXISTS document_favorites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id TEXT NOT NULL,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    document_id UUID NOT NULL REFERENCES user_documents(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT uq_document_favorite UNIQUE(user_id, document_id)
);

CREATE INDEX IF NOT EXISTS idx_document_favorites_user ON document_favorites(user_id, school_id);

-- 9. Create document_recent_activity table
CREATE TABLE IF NOT EXISTS document_recent_activity (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id TEXT NOT NULL,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    document_id UUID NOT NULL REFERENCES user_documents(id) ON DELETE CASCADE,
    activity_type TEXT NOT NULL DEFAULT 'viewed',
    accessed_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT uq_document_recent UNIQUE(user_id, document_id)
);

CREATE INDEX IF NOT EXISTS idx_document_recent_user ON document_recent_activity(user_id, accessed_at DESC);

-- ============================================================================
-- SEED INSTITUTIONAL FOLDERS & SAMPLE DOCUMENTS
-- ============================================================================

DO $$
DECLARE
    v_school_id TEXT := '11111111-1111-1111-1111-111111111111';
    v_admin_id UUID := '5198c4b0-f1cb-45db-9649-41688d0438ba';
    
    -- Root folder IDs
    v_f_academic UUID := 'f0000001-0000-0000-0000-000000000001';
    v_f_admin UUID    := 'f0000002-0000-0000-0000-000000000002';
    v_f_student UUID  := 'f0000003-0000-0000-0000-000000000003';
    v_f_fee UUID      := 'f0000004-0000-0000-0000-000000000004';
    v_f_library UUID  := 'f0000005-0000-0000-0000-000000000005';
    v_f_transport UUID:= 'f0000006-0000-0000-0000-000000000006';
    v_f_others UUID   := 'f0000007-0000-0000-0000-000000000007';

    -- Subfolder IDs
    v_sub_syllabus UUID   := 'f0000011-0000-0000-0000-000000000011';
    v_sub_qpapers UUID    := 'f0000012-0000-0000-0000-000000000012';
    v_sub_results UUID    := 'f0000013-0000-0000-0000-000000000013';

    v_sub_circulars UUID  := 'f0000021-0000-0000-0000-000000000021';
    v_sub_notices UUID    := 'f0000022-0000-0000-0000-000000000022';
    v_sub_forms UUID      := 'f0000023-0000-0000-0000-000000000023';

    v_sub_idcards UUID    := 'f0000031-0000-0000-0000-000000000031';
    v_sub_certs UUID      := 'f0000032-0000-0000-0000-000000000032';
    v_sub_other_std UUID  := 'f0000033-0000-0000-0000-000000000033';
BEGIN
    SELECT id INTO v_admin_id FROM profiles WHERE school_id::text = v_school_id LIMIT 1;
    IF v_admin_id IS NULL THEN
        SELECT id INTO v_admin_id FROM profiles LIMIT 1;
    END IF;

    -- Insert root folders
    INSERT INTO document_folders (id, school_id, parent_id, name, description, category, color, icon, owner_id, is_system)
    VALUES
        (v_f_academic, v_school_id, NULL, 'Academic Documents', 'Curriculum, syllabi, exam questions and results', 'Academic', '#2563EB', 'school', v_admin_id, TRUE),
        (v_f_admin,    v_school_id, NULL, 'Administration', 'Official circulars, notices and forms', 'Administration', '#059669', 'business', v_admin_id, TRUE),
        (v_f_student,  v_school_id, NULL, 'Student Related', 'ID cards, certificates and personal records', 'Students', '#7C3AED', 'groups', v_admin_id, TRUE),
        (v_f_fee,      v_school_id, NULL, 'Fee & Accounts', 'Invoices, fee structures and ledger receipts', 'Finance', '#D97706', 'receipt_long', v_admin_id, TRUE),
        (v_f_library,  v_school_id, NULL, 'Library', 'Catalogues, book policies and digital resources', 'Library', '#0891B2', 'menu_book', v_admin_id, TRUE),
        (v_f_transport,v_school_id, NULL, 'Transport', 'Vehicle permits, driver documents and route maps', 'Transport', '#EA580C', 'directions_bus', v_admin_id, TRUE),
        (v_f_others,   v_school_id, NULL, 'Others', 'Miscellaneous institutional assets and archives', 'Others', '#64748B', 'folder', v_admin_id, TRUE)
    ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, category = EXCLUDED.category;

    -- Insert nested subfolders
    INSERT INTO document_folders (id, school_id, parent_id, name, description, category, color, icon, owner_id)
    VALUES
        (v_sub_syllabus,  v_school_id, v_f_academic, 'Syllabus', 'Annual academic syllabi', 'Academic', '#3B82F6', 'book', v_admin_id),
        (v_sub_qpapers,   v_school_id, v_f_academic, 'Question Papers', 'Term tests and final exam archives', 'Academic', '#3B82F6', 'quiz', v_admin_id),
        (v_sub_results,   v_school_id, v_f_academic, 'Results', 'Published student scores and marks', 'Academic', '#3B82F6', 'grade', v_admin_id),

        (v_sub_circulars, v_school_id, v_f_admin, 'Circulars', 'General school policy circulars', 'Administration', '#10B981', 'campaign', v_admin_id),
        (v_sub_notices,   v_school_id, v_f_admin, 'Notices', 'Urgent institutional notices', 'Administration', '#10B981', 'notifications', v_admin_id),
        (v_sub_forms,     v_school_id, v_f_admin, 'Forms', 'Official forms and applications', 'Administration', '#10B981', 'assignment', v_admin_id),

        (v_sub_idcards,   v_school_id, v_f_student, 'ID Cards', 'Digitized identity documents', 'Students', '#8B5CF6', 'badge', v_admin_id),
        (v_sub_certs,     v_school_id, v_f_student, 'Certificates', 'Transfer, character and bonafide certificates', 'Students', '#8B5CF6', 'verified', v_admin_id),
        (v_sub_other_std, v_school_id, v_f_student, 'Other Documents', 'Supporting student records', 'Students', '#8B5CF6', 'folder_shared', v_admin_id)
    ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, parent_id = EXCLUDED.parent_id;

    -- Seed sample documents matching Image 1
    INSERT INTO user_documents (
        id, school_id, owner_id, folder_id, title, file_name, file_size, mime_type, file_type, category, department,
        approval_status, version_number, is_starred, file_url, storage_path, description, created_at, updated_at
    ) VALUES
    (
        'a0000001-0000-0000-0000-000000000001', v_school_id, v_admin_id, v_f_academic,
        'Academic Calendar 2025-26', 'Academic_Calendar_2025-26.pdf', 2516582, 'application/pdf', 'PDF', 'Academic', 'Academics',
        'Approved', 1, TRUE, 'http://localhost:8082/storage/v1/object/public/documents/assets/test.pdf',
        'documents/assets/test.pdf', 'Complete annual academic calendar, schedule of terms, exam cycles and major institutional events.',
        NOW() - INTERVAL '3 days', NOW() - INTERVAL '3 days'
    ),
    (
        'a0000002-0000-0000-0000-000000000002', v_school_id, v_admin_id, v_f_fee,
        'Fee Structure 2025-26', 'Fee_Structure_2025-26.docx', 1153433, 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'DOCX', 'Finance', 'Finance & Accounts',
        'Approved', 1, FALSE, 'http://localhost:8082/storage/v1/object/public/documents/assets/sample.docx',
        'documents/assets/sample.docx', 'Detailed tuition, transport and lab fees schedule for primary and secondary classes.',
        NOW() - INTERVAL '5 days', NOW() - INTERVAL '5 days'
    ),
    (
        'a0000003-0000-0000-0000-000000000003', v_school_id, v_admin_id, v_f_admin,
        'Student List (Class 10-A)', 'Student_List_Class_10A.xlsx', 364544, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'XLSX', 'Administration', 'Examination',
        'Approved', 1, TRUE, 'http://localhost:8082/storage/v1/object/public/documents/assets/Attendance_Tracker_Template.xlsx',
        'documents/assets/Attendance_Tracker_Template.xlsx', 'Official registered student strength list and roll numbers for Class 10-A.',
        NOW() - INTERVAL '8 days', NOW() - INTERVAL '8 days'
    ),
    (
        'a0000004-0000-0000-0000-000000000004', v_school_id, v_admin_id, v_f_others,
        'School Photos', 'Greenwood_Campus_HighRes.jpg', 2936012, 'image/jpeg', 'JPG', 'Others', 'General',
        'Approved', 1, FALSE, 'http://localhost:8082/storage/v1/object/public/documents/assets/boy_student.png',
        'documents/assets/boy_student.png', 'Official campus photographs, infrastructure views and sports ground snapshots.',
        NOW() - INTERVAL '12 days', NOW() - INTERVAL '12 days'
    ),
    (
        'a0000005-0000-0000-0000-000000000005', v_school_id, v_admin_id, v_f_transport,
        'Transport Routes', 'Route_Schedule_Map_2025.pdf', 1258291, 'application/pdf', 'PDF', 'Transport', 'Transport',
        'Approved', 1, FALSE, 'http://localhost:8082/storage/v1/object/public/documents/assets/test.pdf',
        'documents/assets/test.pdf', 'Designated morning and afternoon bus stop timings and bus driver contact sheets.',
        NOW() - INTERVAL '15 days', NOW() - INTERVAL '15 days'
    ),
    (
        'a0000006-0000-0000-0000-000000000006', v_school_id, v_admin_id, v_f_library,
        'Library Rules', 'Institutional_Library_Guidelines.docx', 913408, 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'DOCX', 'Library', 'Library',
        'Approved', 1, FALSE, 'http://localhost:8082/storage/v1/object/public/documents/assets/sample.docx',
        'documents/assets/sample.docx', 'Book loan duration, membership policies, code of silence and digital catalogue instructions.',
        NOW() - INTERVAL '18 days', NOW() - INTERVAL '18 days'
    ),
    (
        'a0000007-0000-0000-0000-000000000007', v_school_id, v_admin_id, v_f_academic,
        'Exam Guidelines', 'General_Examination_Rules_2025.pdf', 1677721, 'application/pdf', 'PDF', 'Academic', 'Examination',
        'Approved', 1, TRUE, 'http://localhost:8082/storage/v1/object/public/documents/assets/test.pdf',
        'documents/assets/test.pdf', 'Instructions for hall tickets, seating arrangements, permitted stationery and marking rubrics.',
        NOW() - INTERVAL '22 days', NOW() - INTERVAL '22 days'
    ),
    (
        'a0000008-0000-0000-0000-000000000008', v_school_id, v_admin_id, v_f_fee,
        'Fee Payment Report', 'Consolidated_Fee_Collection_Q1.xlsx', 749568, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'XLSX', 'Finance', 'Finance & Accounts',
        'Approved', 1, FALSE, 'http://localhost:8082/storage/v1/object/public/documents/assets/Attendance_Tracker_Template.xlsx',
        'documents/assets/Attendance_Tracker_Template.xlsx', 'Quarterly collection summary, concession approvals and outstanding dues report.',
        NOW() - INTERVAL '24 days', NOW() - INTERVAL '24 days'
    ),
    (
        'a0000009-0000-0000-0000-000000000009', v_school_id, v_admin_id, v_f_admin,
        'Parent Meeting Presentation', 'Annual_PTM_Keynote_2025.pptx', 4300000, 'application/vnd.openxmlformats-officedocument.presentationml.presentation', 'PPTX', 'Administration', 'Management',
        'Approved', 1, FALSE, 'http://localhost:8082/storage/v1/object/public/documents/assets/sample.pptx',
        'documents/assets/sample.pptx', 'Principal keynote slides highlighting academic achievements and technology initiatives.',
        NOW() - INTERVAL '28 days', NOW() - INTERVAL '28 days'
    ),
    (
        'a0000010-0000-0000-0000-000000000010', v_school_id, v_admin_id, v_f_admin,
        'Holiday List', 'Gazetted_Holidays_List_2025.pdf', 215040, 'application/pdf', 'PDF', 'Administration', 'HR Management',
        'Approved', 1, FALSE, 'http://localhost:8082/storage/v1/object/public/documents/assets/test.pdf',
        'documents/assets/test.pdf', 'Official approved list of national, regional and winter vacation dates.',
        NOW() - INTERVAL '30 days', NOW() - INTERVAL '30 days'
    ),
    (
        'a0000011-0000-0000-0000-000000000011', v_school_id, v_admin_id, v_f_academic,
        'Result Declaration Notice', 'Term_1_Result_Circular.docx', 1003520, 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'DOCX', 'Academic', 'Academics',
        'Approved', 1, FALSE, 'http://localhost:8082/storage/v1/object/public/documents/assets/sample.docx',
        'documents/assets/sample.docx', 'Parent notification regarding report card publication and online grade access.',
        NOW() - INTERVAL '33 days', NOW() - INTERVAL '33 days'
    ),
    (
        'a0000012-0000-0000-0000-000000000012', v_school_id, v_admin_id, v_f_admin,
        'Class Wise Strength', 'Enrollment_Statistics_2025.xlsx', 419840, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'XLSX', 'Administration', 'Admissions',
        'Approved', 1, TRUE, 'http://localhost:8082/storage/v1/object/public/documents/assets/Attendance_Tracker_Template.xlsx',
        'documents/assets/Attendance_Tracker_Template.xlsx', 'Section-by-section male/female enrollment statistics and capacity ratios.',
        NOW() - INTERVAL '38 days', NOW() - INTERVAL '38 days'
    )
    ON CONFLICT (id) DO UPDATE SET 
        title = EXCLUDED.title,
        file_name = EXCLUDED.file_name,
        category = EXCLUDED.category,
        file_type = EXCLUDED.file_type;

    -- Add favorites for the admin user
    INSERT INTO document_favorites (school_id, user_id, document_id)
    VALUES
        (v_school_id, v_admin_id, 'a0000001-0000-0000-0000-000000000001'),
        (v_school_id, v_admin_id, 'a0000003-0000-0000-0000-000000000003'),
        (v_school_id, v_admin_id, 'a0000007-0000-0000-0000-000000000007'),
        (v_school_id, v_admin_id, 'a0000012-0000-0000-0000-000000000012')
    ON CONFLICT DO NOTHING;

    -- Add recent activity records for the admin user
    INSERT INTO document_recent_activity (school_id, user_id, document_id, activity_type, accessed_at)
    VALUES
        (v_school_id, v_admin_id, 'a0000001-0000-0000-0000-000000000001', 'viewed', NOW() - INTERVAL '10 minutes'),
        (v_school_id, v_admin_id, 'a0000002-0000-0000-0000-000000000002', 'downloaded', NOW() - INTERVAL '2 hours'),
        (v_school_id, v_admin_id, 'a0000003-0000-0000-0000-000000000003', 'viewed', NOW() - INTERVAL '5 hours')
    ON CONFLICT (user_id, document_id) DO UPDATE SET accessed_at = EXCLUDED.accessed_at;

    -- Add activity log entries
    INSERT INTO document_activity_logs (school_id, document_id, user_id, action, action_details, ip_address)
    VALUES
        (v_school_id, 'a0000001-0000-0000-0000-000000000001', v_admin_id, 'upload', '{"note": "Initial version published"}'::jsonb, '127.0.0.1'),
        (v_school_id, 'a0000001-0000-0000-0000-000000000001', v_admin_id, 'view', '{"duration_sec": 45}'::jsonb, '127.0.0.1')
    ON CONFLICT DO NOTHING;

END $$;
