-- ============================================================================
-- Migration 428: Synchronize All Cross-Module Documents Across EduSHAMIIT
-- EduSHAMIIT — Shami Innovation and Technologies LLP
-- ============================================================================

-- 1. Allow institutional documents without single personal owner
ALTER TABLE user_documents ALTER COLUMN owner_id DROP NOT NULL;
ALTER TABLE user_documents DROP CONSTRAINT IF EXISTS user_documents_owner_id_fkey;
ALTER TABLE document_folders DROP CONSTRAINT IF EXISTS document_folders_owner_id_fkey;

-- 2. Create partial unique index on user_documents for idempotent cross-module syncing
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_docs_entity_sync 
ON user_documents(school_id, entity_type, entity_id) 
WHERE entity_id IS NOT NULL AND is_deleted = FALSE;

-- 3. Ensure standard module folders exist for all schools
DO $$
DECLARE
    sch RECORD;
    v_staff_hr_id UUID;
    v_admin_id UUID;
    v_student_id UUID;
    v_transport_id UUID;
BEGIN
    FOR sch IN SELECT DISTINCT id FROM schools LOOP
        -- Root: Staff & HR
        SELECT id INTO v_staff_hr_id FROM document_folders 
        WHERE school_id = sch.id::text AND parent_id IS NULL AND LOWER(name) IN ('staff & hr', 'staff and hr', 'hr management') LIMIT 1;
        
        IF v_staff_hr_id IS NULL THEN
            INSERT INTO document_folders (id, school_id, parent_id, name, description, category, color, icon, is_system)
            VALUES (gen_random_uuid(), sch.id::text, NULL, 'Staff & HR', 'Faculty, staff, employee contracts and HR policies', 'staff_hr', '#059669', 'badge', TRUE)
            RETURNING id INTO v_staff_hr_id;
        END IF;

        -- Subfolders under Staff & HR
        IF NOT EXISTS (SELECT 1 FROM document_folders WHERE school_id = sch.id::text AND parent_id = v_staff_hr_id AND name = 'HR Policies & Contracts') THEN
            INSERT INTO document_folders (id, school_id, parent_id, name, description, category, color, icon, is_system)
            VALUES (gen_random_uuid(), sch.id::text, v_staff_hr_id, 'HR Policies & Contracts', 'Official employee policies, agreements and contracts', 'policies', '#059669', 'policy', TRUE);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM document_folders WHERE school_id = sch.id::text AND parent_id = v_staff_hr_id AND name = 'Employee Onboarding') THEN
            INSERT INTO document_folders (id, school_id, parent_id, name, description, category, color, icon, is_system)
            VALUES (gen_random_uuid(), sch.id::text, v_staff_hr_id, 'Employee Onboarding', 'Employee onboarding submissions, identity and tax docs', 'staff_hr', '#059669', 'person_add', TRUE);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM document_folders WHERE school_id = sch.id::text AND parent_id = v_staff_hr_id AND name = 'Recruitment') THEN
            INSERT INTO document_folders (id, school_id, parent_id, name, description, category, color, icon, is_system)
            VALUES (gen_random_uuid(), sch.id::text, v_staff_hr_id, 'Recruitment', 'Job candidate resumes, evaluation reports and offer letters', 'staff_hr', '#059669', 'work_outline', TRUE);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM document_folders WHERE school_id = sch.id::text AND parent_id = v_staff_hr_id AND name = 'Hostel Staff Documents') THEN
            INSERT INTO document_folders (id, school_id, parent_id, name, description, category, color, icon, is_system)
            VALUES (gen_random_uuid(), sch.id::text, v_staff_hr_id, 'Hostel Staff Documents', 'Wardens, caretakers and hostel staff verifications', 'hostel', '#059669', 'home_work', TRUE);
        END IF;

        -- Subfolders under Student Related
        SELECT id INTO v_student_id FROM document_folders 
        WHERE school_id = sch.id::text AND parent_id IS NULL AND LOWER(name) IN ('student related', 'students') LIMIT 1;

        IF v_student_id IS NOT NULL THEN
            IF NOT EXISTS (SELECT 1 FROM document_folders WHERE school_id = sch.id::text AND parent_id = v_student_id AND name = 'Hostel Student Documents') THEN
                INSERT INTO document_folders (id, school_id, parent_id, name, description, category, color, icon, is_system)
                VALUES (gen_random_uuid(), sch.id::text, v_student_id, 'Hostel Student Documents', 'Hostel admission forms, undertaking letters and medical records', 'student_records', '#9333EA', 'meeting_room', TRUE);
            END IF;
        END IF;

        -- Subfolders under Administration
        SELECT id INTO v_admin_id FROM document_folders 
        WHERE school_id = sch.id::text AND parent_id IS NULL AND LOWER(name) IN ('administration', 'admin') LIMIT 1;

        IF v_admin_id IS NOT NULL THEN
            IF NOT EXISTS (SELECT 1 FROM document_folders WHERE school_id = sch.id::text AND parent_id = v_admin_id AND name = 'Visitors') THEN
                INSERT INTO document_folders (id, school_id, parent_id, name, description, category, color, icon, is_system)
                VALUES (gen_random_uuid(), sch.id::text, v_admin_id, 'Visitors', 'Visitor gate passes, digital badges and identity proofs', 'administration', '#2563EB', 'badge', TRUE);
            END IF;
        END IF;

        -- Subfolders under Transport
        SELECT id INTO v_transport_id FROM document_folders 
        WHERE school_id = sch.id::text AND parent_id IS NULL AND LOWER(name) IN ('transport') LIMIT 1;

        IF v_transport_id IS NOT NULL THEN
            IF NOT EXISTS (SELECT 1 FROM document_folders WHERE school_id = sch.id::text AND parent_id = v_transport_id AND name = 'Vehicle Documents') THEN
                INSERT INTO document_folders (id, school_id, parent_id, name, description, category, color, icon, is_system)
                VALUES (gen_random_uuid(), sch.id::text, v_transport_id, 'Vehicle Documents', 'Bus insurance, pollution, RC and fitness certificates', 'transport', '#EA580C', 'directions_bus', TRUE);
            END IF;
            IF NOT EXISTS (SELECT 1 FROM document_folders WHERE school_id = sch.id::text AND parent_id = v_transport_id AND name = 'Driver Records') THEN
                INSERT INTO document_folders (id, school_id, parent_id, name, description, category, color, icon, is_system)
                VALUES (gen_random_uuid(), sch.id::text, v_transport_id, 'Driver Records', 'Driver licenses, commercial permits and medical clearances', 'transport', '#EA580C', 'airline_seat_recline_normal', TRUE);
            END IF;
        END IF;

    END LOOP;
END $$;

-- 4. Stored Procedure to synchronize all cross-module documents
CREATE OR REPLACE FUNCTION sync_all_cross_module_documents(target_school_id TEXT DEFAULT NULL)
RETURNS INT AS $$
DECLARE
    v_synced_count INT := 0;
    v_curr_count INT := 0;
BEGIN
    -- 4.1 Synchronize Hostel Student Documents
    INSERT INTO user_documents (
        id, school_id, folder_id, title, description, file_name, file_size, 
        file_type, mime_type, file_url, category, department, module_key, 
        entity_type, entity_id, owner_id, approval_status, created_at, updated_at
    )
    SELECT 
        gen_random_uuid(),
        h.school_id::text,
        (SELECT id FROM document_folders WHERE school_id = h.school_id::text AND name = 'Hostel Student Documents' LIMIT 1),
        COALESCE(h.document_name, 'Hostel Student Document'),
        COALESCE(h.notes, 'Uploaded via Hostel Management module'),
        COALESCE(h.document_name || '.pdf', 'hostel_document.pdf'),
        COALESCE(h.file_size_bytes, 1024 * 1024),
        CASE 
            WHEN h.mime_type ILIKE '%pdf%' THEN 'PDF'
            WHEN h.mime_type ILIKE '%image%' THEN 'JPG'
            WHEN h.mime_type ILIKE '%sheet%' OR h.mime_type ILIKE '%excel%' THEN 'XLSX'
            WHEN h.mime_type ILIKE '%word%' THEN 'DOCX'
            ELSE 'PDF'
        END,
        COALESCE(h.mime_type, 'application/pdf'),
        h.file_url,
        'student_records',
        'Hostel',
        'hostel',
        'hostel_student_document',
        h.id::text,
        COALESCE(h.student_id, h.uploaded_by),
        CASE WHEN h.verification_status = 'VERIFIED' THEN 'Approved' ELSE 'Pending' END,
        COALESCE(h.created_at, NOW()),
        COALESCE(h.updated_at, NOW())
    FROM hostel_student_documents h
    WHERE (target_school_id IS NULL OR h.school_id::text = target_school_id)
      AND h.deleted_at IS NULL
      AND h.file_url IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM user_documents u 
          WHERE u.school_id = h.school_id::text AND u.entity_type = 'hostel_student_document' AND u.entity_id = h.id::text
      );
    GET DIAGNOSTICS v_curr_count = ROW_COUNT;
    v_synced_count := v_synced_count + v_curr_count;

    -- 4.2 Synchronize Employee Onboarding Documents
    INSERT INTO user_documents (
        id, school_id, folder_id, title, description, file_name, file_size, 
        file_type, mime_type, file_url, category, department, module_key, 
        entity_type, entity_id, owner_id, approval_status, created_at, updated_at
    )
    SELECT 
        gen_random_uuid(),
        o.school_id::text,
        (SELECT id FROM document_folders WHERE school_id = o.school_id::text AND name = 'Employee Onboarding' LIMIT 1),
        COALESCE(o.document_name, 'Onboarding Document'),
        COALESCE(o.remarks, 'Employee onboarding submission'),
        COALESCE(o.file_name, o.document_name || '.pdf'),
        COALESCE(o.file_size_bytes, 512 * 1024),
        'PDF',
        'application/pdf',
        o.file_url,
        'administration',
        'HR Management',
        'onboarding',
        'onboarding_document',
        o.id::text,
        (SELECT id FROM profiles WHERE school_id = o.school_id::text LIMIT 1),
        CASE WHEN o.status = 'Verified' THEN 'Approved' ELSE 'Pending' END,
        COALESCE(o.created_at, NOW()),
        COALESCE(o.updated_at, NOW())
    FROM onboarding_documents o
    WHERE (target_school_id IS NULL OR o.school_id::text = target_school_id)
      AND o.file_url IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM user_documents u 
          WHERE u.school_id = o.school_id::text AND u.entity_type = 'onboarding_document' AND u.entity_id = o.id::text
      );
    GET DIAGNOSTICS v_curr_count = ROW_COUNT;
    v_synced_count := v_synced_count + v_curr_count;

    -- 4.3 Synchronize HR Documents & Policies
    INSERT INTO user_documents (
        id, school_id, folder_id, title, description, file_name, file_size, 
        file_type, storage_path, file_url, category, department, module_key, 
        entity_type, entity_id, owner_id, approval_status, created_at, updated_at
    )
    SELECT 
        gen_random_uuid(),
        hr.school_id::text,
        (SELECT id FROM document_folders WHERE school_id = hr.school_id::text AND name = 'HR Policies & Contracts' LIMIT 1),
        COALESCE(hr.document_name, 'HR Policy Document'),
        COALESCE(hr.description, 'Official institute policy and HR record'),
        COALESCE(hr.file_name, hr.document_name || '.pdf'),
        COALESCE(hr.file_size_bytes, 1024 * 1024),
        COALESCE(hr.file_type, 'PDF'),
        hr.storage_path,
        COALESCE(hr.download_url, hr.storage_path),
        'policies',
        COALESCE(hr.department, 'HR Management'),
        'hr',
        'hr_document',
        hr.id::text,
        COALESCE(hr.owner_id, (SELECT id FROM profiles WHERE school_id = hr.school_id::text LIMIT 1)),
        'Approved',
        COALESCE(hr.created_at, NOW()),
        COALESCE(hr.updated_at, NOW())
    FROM hr_documents hr
    WHERE (target_school_id IS NULL OR hr.school_id::text = target_school_id)
      AND hr.is_deleted = FALSE
      AND NOT EXISTS (
          SELECT 1 FROM user_documents u 
          WHERE u.school_id = hr.school_id::text AND u.entity_type = 'hr_document' AND u.entity_id = hr.id::text
      );
    GET DIAGNOSTICS v_curr_count = ROW_COUNT;
    v_synced_count := v_synced_count + v_curr_count;

    -- 4.4 Synchronize Visitor Documents
    INSERT INTO user_documents (
        id, school_id, folder_id, title, description, file_name, file_size, 
        file_type, file_url, category, department, module_key, 
        entity_type, entity_id, owner_id, approval_status, created_at, updated_at
    )
    SELECT 
        gen_random_uuid(),
        v.school_id::text,
        (SELECT id FROM document_folders WHERE school_id = v.school_id::text AND name = 'Visitors' LIMIT 1),
        COALESCE(v.document_name, 'Visitor Verification Proof'),
        'Visitor identity proof submitted at campus security desk',
        COALESCE(v.document_name, 'visitor_proof.pdf'),
        COALESCE(v.file_size_bytes, 256 * 1024),
        'PDF',
        v.file_url,
        'administration',
        'Administration',
        'visitor',
        'visitor_document',
        v.id::text,
        (SELECT id FROM profiles WHERE school_id = v.school_id::text LIMIT 1),
        CASE WHEN v.verification_status = 'VERIFIED' THEN 'Approved' ELSE 'Pending' END,
        COALESCE(v.created_at, NOW()),
        COALESCE(v.created_at, NOW())
    FROM visitor_documents v
    WHERE (target_school_id IS NULL OR v.school_id::text = target_school_id)
      AND v.file_url IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM user_documents u 
          WHERE u.school_id = v.school_id::text AND u.entity_type = 'visitor_document' AND u.entity_id = v.id::text
      );
    GET DIAGNOSTICS v_curr_count = ROW_COUNT;
    v_synced_count := v_synced_count + v_curr_count;

    -- 4.5 Synchronize Hostel Staff Documents
    INSERT INTO user_documents (
        id, school_id, folder_id, title, description, file_name, file_size, 
        file_type, file_url, category, department, module_key, 
        entity_type, entity_id, owner_id, approval_status, created_at, updated_at
    )
    SELECT 
        gen_random_uuid(),
        hs.school_id::text,
        (SELECT id FROM document_folders WHERE school_id = hs.school_id::text AND name = 'Hostel Staff Documents' LIMIT 1),
        COALESCE(hs.document_name, 'Hostel Staff Compliance'),
        COALESCE(hs.notes, 'Hostel staff certificate and verification'),
        COALESCE(hs.document_name || '.pdf', 'hostel_staff_cert.pdf'),
        COALESCE(hs.file_size_bytes, 128 * 1024),
        'PDF',
        hs.file_url,
        'administration',
        'Hostel',
        'hostel_staff',
        'hostel_staff_document',
        hs.id::text,
        COALESCE(hs.profile_id, hs.uploaded_by),
        CASE WHEN hs.verification_status = 'VERIFIED' THEN 'Approved' ELSE 'Pending' END,
        COALESCE(hs.created_at, NOW()),
        COALESCE(hs.updated_at, NOW())
    FROM hostel_staff_documents hs
    WHERE (target_school_id IS NULL OR hs.school_id::text = target_school_id)
      AND hs.deleted_at IS NULL
      AND hs.file_url IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM user_documents u 
          WHERE u.school_id = hs.school_id::text AND u.entity_type = 'hostel_staff_document' AND u.entity_id = hs.id::text
      );
    GET DIAGNOSTICS v_curr_count = ROW_COUNT;
    v_synced_count := v_synced_count + v_curr_count;

    -- 4.6 Synchronize Recruitment Candidate Documents
    INSERT INTO user_documents (
        id, school_id, folder_id, title, description, file_name, file_size, 
        file_type, file_url, category, department, module_key, 
        entity_type, entity_id, owner_id, approval_status, created_at, updated_at
    )
    SELECT 
        gen_random_uuid(),
        rc.school_id::text,
        (SELECT id FROM document_folders WHERE school_id = rc.school_id::text AND name = 'Recruitment' LIMIT 1),
        COALESCE(rc.title, 'Candidate Document'),
        'Resume / credential submitted for job opening',
        COALESCE(rc.title || '.pdf', 'candidate_doc.pdf'),
        COALESCE(rc.file_size_bytes, 512 * 1024),
        'PDF',
        rc.file_url,
        'administration',
        'HR Management',
        'recruitment',
        'recruitment_candidate_document',
        rc.id::text,
        (SELECT id FROM profiles WHERE school_id = rc.school_id::text LIMIT 1),
        'Approved',
        COALESCE(rc.uploaded_at, NOW()),
        COALESCE(rc.uploaded_at, NOW())
    FROM recruitment_candidate_documents rc
    WHERE (target_school_id IS NULL OR rc.school_id::text = target_school_id)
      AND rc.file_url IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM user_documents u 
          WHERE u.school_id = rc.school_id::text AND u.entity_type = 'recruitment_candidate_document' AND u.entity_id = rc.id::text
      );
    GET DIAGNOSTICS v_curr_count = ROW_COUNT;
    v_synced_count := v_synced_count + v_curr_count;

    -- 4.7 Synchronize Vehicle Documents
    INSERT INTO user_documents (
        id, school_id, folder_id, title, description, file_name, file_size, 
        file_type, file_url, category, department, module_key, 
        entity_type, entity_id, owner_id, approval_status, created_at, updated_at
    )
    SELECT 
        gen_random_uuid(),
        vd.school_id::text,
        (SELECT id FROM document_folders WHERE school_id = vd.school_id::text AND name = 'Vehicle Documents' LIMIT 1),
        COALESCE(vd.document_name, 'Vehicle Certificate'),
        COALESCE(vd.remarks, 'Vehicle compliance & insurance document'),
        COALESCE(vd.document_name || '.pdf', 'vehicle_doc.pdf'),
        1024 * 1024,
        'PDF',
        vd.document_url,
        'transport',
        'Transport',
        'transport',
        'vehicle_document',
        vd.id::text,
        (SELECT id FROM profiles WHERE school_id = vd.school_id::text LIMIT 1),
        'Approved',
        COALESCE(vd.created_at, NOW()),
        COALESCE(vd.updated_at, NOW())
    FROM vehicle_documents vd
    WHERE (target_school_id IS NULL OR vd.school_id::text = target_school_id)
      AND vd.document_url IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM user_documents u 
          WHERE u.school_id = vd.school_id::text AND u.entity_type = 'vehicle_document' AND u.entity_id = vd.id::text
      );
    GET DIAGNOSTICS v_curr_count = ROW_COUNT;
    v_synced_count := v_synced_count + v_curr_count;

    -- 4.8 Synchronize Driver Documents
    INSERT INTO user_documents (
        id, school_id, folder_id, title, description, file_name, file_size, 
        file_type, file_url, category, department, module_key, 
        entity_type, entity_id, owner_id, approval_status, created_at, updated_at
    )
    SELECT 
        gen_random_uuid(),
        dd.school_id::text,
        (SELECT id FROM document_folders WHERE school_id = dd.school_id::text AND name = 'Driver Records' LIMIT 1),
        COALESCE(dd.document_type || ' - ' || dd.document_no, 'Driver License/Clearance'),
        'Driver statutory compliance record',
        COALESCE(dd.file_name, 'driver_document.pdf'),
        COALESCE(dd.file_size, 512 * 1024),
        'PDF',
        dd.file_url,
        'transport',
        'Transport',
        'transport',
        'driver_document',
        dd.id::text,
        COALESCE(dd.driver_id, (SELECT id FROM profiles WHERE school_id = dd.school_id::text LIMIT 1)),
        'Approved',
        COALESCE(dd.created_at, NOW()),
        COALESCE(dd.updated_at, NOW())
    FROM driver_documents dd
    WHERE (target_school_id IS NULL OR dd.school_id::text = target_school_id)
      AND dd.file_url IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM user_documents u 
          WHERE u.school_id = dd.school_id::text AND u.entity_type = 'driver_document' AND u.entity_id = dd.id::text
      );
    GET DIAGNOSTICS v_curr_count = ROW_COUNT;
    v_synced_count := v_synced_count + v_curr_count;

    -- 4.9 Synchronize Notices Attachments
    INSERT INTO user_documents (
        id, school_id, folder_id, title, description, file_name, file_size, 
        file_type, file_url, category, department, module_key, 
        entity_type, entity_id, owner_id, approval_status, created_at, updated_at
    )
    SELECT 
        gen_random_uuid(),
        n.school_id::text,
        (SELECT id FROM document_folders WHERE school_id = n.school_id::text AND name = 'Circulars' LIMIT 1),
        COALESCE(n.title, 'Official Notice'),
        COALESCE(n.content, 'Notice circular and administrative announcement'),
        'notice_attachment.pdf',
        512 * 1024,
        'PDF',
        n.attachment_url,
        'administration',
        'Administration',
        'notices',
        'notice_attachment',
        n.id::text,
        (SELECT id FROM profiles WHERE school_id = n.school_id::text LIMIT 1),
        'Approved',
        COALESCE(n.created_at, NOW()),
        COALESCE(n.created_at, NOW())
    FROM notices n
    WHERE (target_school_id IS NULL OR n.school_id::text = target_school_id)
      AND n.attachment_url IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM user_documents u 
          WHERE u.school_id = n.school_id::text AND u.entity_type = 'notice_attachment' AND u.entity_id = n.id::text
      );
    GET DIAGNOSTICS v_curr_count = ROW_COUNT;
    v_synced_count := v_synced_count + v_curr_count;

    RETURN v_synced_count;
END;
$$ LANGUAGE plpgsql;

-- 5. Execute the sync immediately for all schools
SELECT sync_all_cross_module_documents();
