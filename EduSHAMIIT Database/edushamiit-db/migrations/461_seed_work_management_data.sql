-- ============================================================================
-- Migration 461: Enterprise Work Management Seed Data
-- Realistic institutional data matching all 4 tabs (Board, List, Backlog, Sprints)
-- Reusing existing schools, users/profiles, and dynamic lookups
-- ============================================================================

DO $$
DECLARE
    v_school_id UUID := '11111111-1111-1111-1111-111111111111';
    v_admin_id UUID;
    v_teacher_1 UUID;
    v_teacher_2 UUID;
    v_student_1 UUID;
    v_board_id UUID := uuid_generate_v4();
    v_sprint_8_id UUID := uuid_generate_v4();
    v_sprint_9_id UUID := uuid_generate_v4();
    v_sprint_10_id UUID := uuid_generate_v4();
    
    -- Epic IDs
    v_ep_1 UUID := uuid_generate_v4();
    v_ep_2 UUID := uuid_generate_v4();
    v_ep_3 UUID := uuid_generate_v4();
    v_ep_4 UUID := uuid_generate_v4();
    v_ep_5 UUID := uuid_generate_v4();
    v_ep_6 UUID := uuid_generate_v4();
    v_ep_7 UUID := uuid_generate_v4();
    v_ep_8 UUID := uuid_generate_v4();
    v_ep_9 UUID := uuid_generate_v4();
    v_ep_10 UUID := uuid_generate_v4();
    v_ep_11 UUID := uuid_generate_v4();
    v_ep_12 UUID := uuid_generate_v4();

    -- Story IDs
    v_st_101 UUID := uuid_generate_v4();
    v_st_102 UUID := uuid_generate_v4();
    v_st_103 UUID := uuid_generate_v4();

    -- Task IDs
    v_wm_1050 UUID := uuid_generate_v4();
    v_wm_1045 UUID := uuid_generate_v4();
    v_wm_1048 UUID := uuid_generate_v4();
    v_wm_1038 UUID := uuid_generate_v4();
    v_wm_1042 UUID := uuid_generate_v4();
    v_wm_1051 UUID := uuid_generate_v4();
    v_wm_1032 UUID := uuid_generate_v4();
    v_wm_1035 UUID := uuid_generate_v4();
    v_wm_1027 UUID := uuid_generate_v4();
    v_wm_1028 UUID := uuid_generate_v4();
    v_wm_1041 UUID := uuid_generate_v4();
    v_wm_1031 UUID := uuid_generate_v4();

    -- Backlog Task IDs
    v_tk_1001 UUID := uuid_generate_v4();
    v_tk_1002 UUID := uuid_generate_v4();
    v_tk_1003 UUID := uuid_generate_v4();
    v_tk_1004 UUID := uuid_generate_v4();
    v_tk_1005 UUID := uuid_generate_v4();
    v_tk_1006 UUID := uuid_generate_v4();
    v_tk_1007 UUID := uuid_generate_v4();
    v_tk_1008 UUID := uuid_generate_v4();
    v_tk_1009 UUID := uuid_generate_v4();
    v_tk_1010 UUID := uuid_generate_v4();
    v_tk_1011 UUID := uuid_generate_v4();

BEGIN
    -- Verify school exists or pick first
    IF NOT EXISTS (SELECT 1 FROM public.schools WHERE id = v_school_id) THEN
        SELECT id INTO v_school_id FROM public.schools LIMIT 1;
    END IF;

    -- Pick users from public.profiles
    SELECT id INTO v_admin_id FROM public.profiles WHERE school_id = v_school_id AND role IN ('admin', 'super_admin') LIMIT 1;
    SELECT id INTO v_teacher_1 FROM public.profiles WHERE school_id = v_school_id AND role = 'teacher' LIMIT 1;
    SELECT id INTO v_teacher_2 FROM public.profiles WHERE school_id = v_school_id AND role = 'teacher' AND id != v_teacher_1 LIMIT 1;
    SELECT id INTO v_student_1 FROM public.profiles WHERE school_id = v_school_id AND role = 'student' LIMIT 1;

    IF v_admin_id IS NULL THEN
        SELECT id INTO v_admin_id FROM public.profiles LIMIT 1;
    END IF;
    IF v_teacher_1 IS NULL THEN v_teacher_1 := v_admin_id; END IF;
    IF v_teacher_2 IS NULL THEN v_teacher_2 := v_admin_id; END IF;
    IF v_student_1 IS NULL THEN v_student_1 := v_admin_id; END IF;

    -- ------------------------------------------------------------------------
    -- 1. LOOKUP KEYS & VALUES
    -- ------------------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM public.lookup_keys WHERE key_code = 'WORK_ITEM_TYPE') THEN
        INSERT INTO public.lookup_keys (id, school_id, key_code, key_name, description, key_type, icon, status)
        VALUES (uuid_generate_v4(), v_school_id, 'WORK_ITEM_TYPE', 'Work Item Type', 'Universal work types e.g. Epic, Story, Task, Bug, Homework', 'SYSTEM', 'category', 'ACTIVE');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.lookup_keys WHERE key_code = 'WORK_ITEM_PRIORITY') THEN
        INSERT INTO public.lookup_keys (id, school_id, key_code, key_name, description, key_type, icon, status)
        VALUES (uuid_generate_v4(), v_school_id, 'WORK_ITEM_PRIORITY', 'Work Item Priority', 'Priority scales for tasks and work items', 'SYSTEM', 'flag', 'ACTIVE');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.lookup_keys WHERE key_code = 'WORK_ITEM_STATUS') THEN
        INSERT INTO public.lookup_keys (id, school_id, key_code, key_name, description, key_type, icon, status)
        VALUES (uuid_generate_v4(), v_school_id, 'WORK_ITEM_STATUS', 'Work Item Status', 'Kanban lifecycle statuses', 'SYSTEM', 'swap_horiz', 'ACTIVE');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.lookup_keys WHERE key_code = 'WORK_ITEM_CATEGORY') THEN
        INSERT INTO public.lookup_keys (id, school_id, key_code, key_name, description, key_type, icon, status)
        VALUES (uuid_generate_v4(), v_school_id, 'WORK_ITEM_CATEGORY', 'Work Item Category', 'Departmental and functional categories', 'SYSTEM', 'folder_special', 'ACTIVE');
    END IF;

    -- Insert values
    INSERT INTO public.lookup_values (id, school_id, lookup_key_id, value_code, value_name, sort_order, status)
    SELECT uuid_generate_v4(), v_school_id, k.id, val.code, val.name, val.sort_order, 'ACTIVE'
    FROM public.lookup_keys k
    CROSS JOIN (
        VALUES
            ('WORK_ITEM_TYPE', 'EPIC', 'Epic', 1),
            ('WORK_ITEM_TYPE', 'STORY', 'Story', 2),
            ('WORK_ITEM_TYPE', 'TASK', 'Task', 3),
            ('WORK_ITEM_TYPE', 'SUBTASK', 'Subtask', 4),
            ('WORK_ITEM_TYPE', 'BUG', 'Bug', 5),
            ('WORK_ITEM_TYPE', 'ISSUE', 'Issue', 6),
            ('WORK_ITEM_TYPE', 'HOMEWORK', 'Homework', 7),
            ('WORK_ITEM_TYPE', 'ASSIGNMENT', 'Assignment', 8),
            ('WORK_ITEM_TYPE', 'IMPROVEMENT', 'Improvement', 9),
            ('WORK_ITEM_TYPE', 'REQUEST', 'Request', 10),
            ('WORK_ITEM_TYPE', 'MILESTONE', 'Milestone', 11),
            ('WORK_ITEM_PRIORITY', 'CRITICAL', 'Critical', 1),
            ('WORK_ITEM_PRIORITY', 'URGENT', 'Urgent', 2),
            ('WORK_ITEM_PRIORITY', 'HIGH', 'High', 3),
            ('WORK_ITEM_PRIORITY', 'MEDIUM', 'Medium', 4),
            ('WORK_ITEM_PRIORITY', 'LOW', 'Low', 5),
            ('WORK_ITEM_STATUS', 'NEW', 'New', 1),
            ('WORK_ITEM_STATUS', 'ACTIVE', 'Active', 2),
            ('WORK_ITEM_STATUS', 'RESOLVED', 'Resolved', 3),
            ('WORK_ITEM_STATUS', 'COMPLETED', 'Completed', 4),
            ('WORK_ITEM_CATEGORY', 'ACADEMIC', 'Academic', 1),
            ('WORK_ITEM_CATEGORY', 'IT_SERVICES', 'IT Services', 2),
            ('WORK_ITEM_CATEGORY', 'ADMINISTRATION', 'Administration', 3),
            ('WORK_ITEM_CATEGORY', 'DEPARTMENT', 'Department', 4),
            ('WORK_ITEM_CATEGORY', 'STUDENT_ACTIVITY', 'Student Activity', 5),
            ('WORK_ITEM_CATEGORY', 'EXAMINATION', 'Examination', 6),
            ('WORK_ITEM_CATEGORY', 'FACILITIES', 'Facilities', 7),
            ('WORK_ITEM_CATEGORY', 'OTHER', 'Other', 8)
    ) AS val(key_code, code, name, sort_order)
    WHERE k.key_code = val.key_code
      AND NOT EXISTS (
          SELECT 1 FROM public.lookup_values lv
          WHERE lv.lookup_key_id = k.id AND lv.value_code = val.code
      );

    -- ------------------------------------------------------------------------
    -- 2. WORK BOARDS
    -- ------------------------------------------------------------------------
    INSERT INTO public.work_boards (id, school_id, name, code, description, board_type, is_active, created_by)
    VALUES
        (v_board_id, v_school_id, 'Institute Work Board', 'IWB', 'Unified Institute-Wide Planning, Operations and Academic Work Board', 'KANBAN', TRUE, v_admin_id),
        (uuid_generate_v4(), v_school_id, 'Academic Operations Board', 'AOB', 'Curriculum, homework, quizzes and exam planning board', 'ACADEMIC', TRUE, v_admin_id),
        (uuid_generate_v4(), v_school_id, 'IT & Campus Infrastructure', 'ITB', 'Campus networks, smart classrooms, maintenance and IoT operations', 'SERVICE', TRUE, v_admin_id)
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name;

    SELECT id INTO v_board_id FROM public.work_boards WHERE school_id = v_school_id AND code = 'IWB';

    -- ------------------------------------------------------------------------
    -- 3. SPRINTS
    -- ------------------------------------------------------------------------
    INSERT INTO public.work_sprints (
        id, school_id, board_id, name, sprint_number, goal, status, team_name,
        start_date, end_date, capacity_hours, total_points, owner_id
    ) VALUES
        (v_sprint_8_id, v_school_id, v_board_id, 'Sprint 8', 8, 'Deliver student portal enhancement, examination notifications and key infrastructure fixes.', 'ACTIVE', 'Digital Campus Team', '2025-01-01', '2025-01-14', 160.0, 42.0, v_admin_id),
        (v_sprint_9_id, v_school_id, v_board_id, 'Sprint 9', 9, 'Roll out faculty profile integration and campus maintenance automation.', 'PLANNED', 'Digital Campus Team', '2025-01-15', '2025-01-28', 160.0, 38.0, v_admin_id),
        (v_sprint_10_id, v_school_id, v_board_id, 'Sprint 10', 10, 'Institute Mobile App iOS and Android release staging.', 'PLANNED', 'Digital Campus Team', '2025-01-29', '2025-02-11', 160.0, 45.0, v_admin_id)
    ON CONFLICT DO NOTHING;

    SELECT id INTO v_sprint_8_id FROM public.work_sprints WHERE school_id = v_school_id AND name = 'Sprint 8';

    -- ------------------------------------------------------------------------
    -- 4. BURNDOWN SNAPSHOTS FOR SPRINT 8
    -- ------------------------------------------------------------------------
    INSERT INTO public.work_sprint_daily_snapshots (
        sprint_id, snapshot_date, day_label, ideal_remaining_items, actual_remaining_items, completed_items_count, total_items_count
    ) VALUES
        (v_sprint_8_id, '2025-01-01', 'Jan 01', 42, 42, 0, 42),
        (v_sprint_8_id, '2025-01-03', 'Jan 03', 36, 38, 4, 42),
        (v_sprint_8_id, '2025-01-05', 'Jan 05', 30, 32, 10, 42),
        (v_sprint_8_id, '2025-01-07', 'Jan 07', 24, 26, 16, 42),
        (v_sprint_8_id, '2025-01-09', 'Jan 09', 18, 19, 23, 42),
        (v_sprint_8_id, '2025-01-11', 'Jan 11', 12, 14, 28, 42),
        (v_sprint_8_id, '2025-01-14', 'Jan 14', 0, 13, 29, 42)
    ON CONFLICT (sprint_id, snapshot_date) DO NOTHING;

    -- ------------------------------------------------------------------------
    -- 5. 12 EPICS (BACKLOG LEFT SIDEBAR)
    -- ------------------------------------------------------------------------
    INSERT INTO public.work_items (id, school_id, board_id, item_number, title, description, work_type, priority, status, category, rank, reporter_id)
    VALUES
        (v_ep_1, v_school_id, v_board_id, 'EP-001', 'Campus Digitalization', 'End-to-end digital transformation of campus operations, services and user experience.', 'EPIC', 'HIGH', 'ACTIVE', 'Administration', 10, v_admin_id),
        (v_ep_2, v_school_id, v_board_id, 'EP-002', 'Academic Excellence', 'Academic curriculum enhancements, continuous assessments and teacher enablement.', 'EPIC', 'HIGH', 'ACTIVE', 'Academic', 20, v_admin_id),
        (v_ep_3, v_school_id, v_board_id, 'EP-003', 'Smart Campus Control', 'IoT automation for energy, lighting, HVAC, access and security.', 'EPIC', 'MEDIUM', 'ACTIVE', 'Facilities', 30, v_admin_id),
        (v_ep_4, v_school_id, v_board_id, 'EP-004', 'Student Experience', 'Student life, extracurriculars, feedback, canteen and sports portals.', 'EPIC', 'MEDIUM', 'ACTIVE', 'Student Activity', 40, v_admin_id),
        (v_ep_5, v_school_id, v_board_id, 'EP-005', 'Infrastructure & Facilities', 'Modernization of lecture halls, scientific labs and campus grounds.', 'EPIC', 'HIGH', 'ACTIVE', 'Facilities', 50, v_admin_id),
        (v_ep_6, v_school_id, v_board_id, 'EP-006', 'Administrative Automation', 'Digitization of approvals, documentation, fees and employee records.', 'EPIC', 'MEDIUM', 'ACTIVE', 'Administration', 60, v_admin_id),
        (v_ep_7, v_school_id, v_board_id, 'EP-007', 'Sustainability & Energy', 'Solar generation, water conservation and energy waste reduction initiatives.', 'EPIC', 'LOW', 'ACTIVE', 'Facilities', 70, v_admin_id),
        (v_ep_8, v_school_id, v_board_id, 'EP-008', 'Library & Learning Resources', 'Digital book acquisition, e-journals, reading tracking and cataloguing.', 'EPIC', 'MEDIUM', 'ACTIVE', 'Academic', 80, v_admin_id),
        (v_ep_9, v_school_id, v_board_id, 'EP-009', 'Examination Management', 'Automated question paper generation, exam scheduling and evaluation.', 'EPIC', 'HIGH', 'ACTIVE', 'Examination', 90, v_admin_id),
        (v_ep_10, v_school_id, v_board_id, 'EP-010', 'Safety & Compliance', 'CCTV monitoring, fire drill audits, emergency SOS and regulatory compliance.', 'EPIC', 'CRITICAL', 'ACTIVE', 'Administration', 100, v_admin_id),
        (v_ep_11, v_school_id, v_board_id, 'EP-011', 'Hostels & Residential Life', 'Hostel allocation, room maintenance, mess scheduling and night roll calls.', 'EPIC', 'MEDIUM', 'ACTIVE', 'Facilities', 110, v_admin_id),
        (v_ep_12, v_school_id, v_board_id, 'EP-012', 'Events & Engagement', 'Annual tech fest, cultural symposia, alumni network and sports meets.', 'EPIC', 'LOW', 'ACTIVE', 'Student Activity', 120, v_admin_id)
    ON CONFLICT (school_id, item_number) DO NOTHING;

    SELECT id INTO v_ep_1 FROM public.work_items WHERE school_id = v_school_id AND item_number = 'EP-001';

    -- ------------------------------------------------------------------------
    -- 6. STORIES & CHILD TASKS (BACKLOG & SPRINT)
    -- ------------------------------------------------------------------------
    -- ST-101 Student Portal Enhancement
    INSERT INTO public.work_items (
        id, school_id, board_id, sprint_id, parent_id, item_number, title, description,
        work_type, priority, status, category, estimated_hours, story_points, due_date, rank, reporter_id
    ) VALUES (
        v_st_101, v_school_id, v_board_id, v_sprint_8_id, v_ep_1, 'ST-101', 'Student Portal Enhancement',
        'Enhance the student portal with a modern UI, better assignment submission, real-time notifications and mobile-friendly experience.',
        'STORY', 'MEDIUM', 'COMPLETED', 'Academic', 40.0, 13.0, '2025-01-31', 110, v_admin_id
    ) ON CONFLICT (school_id, item_number) DO NOTHING;

    SELECT id INTO v_st_101 FROM public.work_items WHERE school_id = v_school_id AND item_number = 'ST-101';

    INSERT INTO public.work_items (id, school_id, board_id, sprint_id, parent_id, item_number, title, work_type, priority, status, category, estimated_hours, progress_percentage, rank, reporter_id)
    VALUES
        (v_tk_1001, v_school_id, v_board_id, v_sprint_8_id, v_st_101, 'TK-1001', 'Improve dashboard UI', 'TASK', 'MEDIUM', 'COMPLETED', 'Academic', 8.0, 100, 111, v_admin_id),
        (v_tk_1002, v_school_id, v_board_id, v_sprint_8_id, v_st_101, 'TK-1002', 'Add assignment submission', 'TASK', 'HIGH', 'IN_PROGRESS', 'Academic', 12.0, 70, 112, v_admin_id),
        (v_tk_1003, v_school_id, v_board_id, v_sprint_8_id, v_st_101, 'TK-1003', 'Integrate notifications', 'TASK', 'MEDIUM', 'IN_PROGRESS', 'Academic', 8.0, 50, 113, v_admin_id),
        (v_tk_1004, v_school_id, v_board_id, v_sprint_8_id, v_st_101, 'TK-1004', 'Mobile responsiveness', 'TASK', 'MEDIUM', 'NEW', 'Academic', 12.0, 0, 114, v_admin_id)
    ON CONFLICT (school_id, item_number) DO NOTHING;

    -- ST-102 Faculty Management Module
    INSERT INTO public.work_items (
        id, school_id, board_id, sprint_id, parent_id, item_number, title, description,
        work_type, priority, status, category, estimated_hours, story_points, due_date, rank, reporter_id
    ) VALUES (
        v_st_102, v_school_id, v_board_id, v_sprint_8_id, v_ep_1, 'ST-102', 'Faculty Management Module',
        'Faculty profile, automated workload tracking, digital leave applications and attendance integration.',
        'STORY', 'HIGH', 'ACTIVE', 'Administration', 36.0, 10.0, '2025-01-28', 120, v_admin_id
    ) ON CONFLICT (school_id, item_number) DO NOTHING;

    SELECT id INTO v_st_102 FROM public.work_items WHERE school_id = v_school_id AND item_number = 'ST-102';

    INSERT INTO public.work_items (id, school_id, board_id, sprint_id, parent_id, item_number, title, work_type, priority, status, category, estimated_hours, progress_percentage, rank, reporter_id)
    VALUES
        (v_tk_1005, v_school_id, v_board_id, v_sprint_8_id, v_st_102, 'TK-1005', 'Faculty profile and workload', 'TASK', 'MEDIUM', 'COMPLETED', 'Administration', 8.0, 100, 121, v_admin_id),
        (v_tk_1006, v_school_id, v_board_id, v_sprint_8_id, v_st_102, 'TK-1006', 'Leave and attendance integration', 'TASK', 'MEDIUM', 'IN_PROGRESS', 'Administration', 12.0, 60, 122, v_admin_id),
        (v_tk_1007, v_school_id, v_board_id, v_sprint_8_id, v_st_102, 'TK-1007', 'Reporting and analytics', 'TASK', 'MEDIUM', 'NEW', 'Administration', 8.0, 0, 123, v_admin_id),
        (v_tk_1008, v_school_id, v_board_id, v_sprint_8_id, v_st_102, 'TK-1008', 'User access and permissions', 'TASK', 'HIGH', 'ACTIVE', 'Administration', 8.0, 40, 124, v_admin_id)
    ON CONFLICT (school_id, item_number) DO NOTHING;

    -- ST-103 Institute Mobile App
    INSERT INTO public.work_items (
        id, school_id, board_id, parent_id, item_number, title, description,
        work_type, priority, status, category, estimated_hours, story_points, due_date, rank, reporter_id
    ) VALUES (
        v_st_103, v_school_id, v_board_id, v_ep_1, 'ST-103', 'Institute Mobile App',
        'Cross-platform Flutter application for students, guardians, faculty and administrators.',
        'STORY', 'MEDIUM', 'NEW', 'IT Services', 48.0, 15.0, '2025-02-15', 130, v_admin_id
    ) ON CONFLICT (school_id, item_number) DO NOTHING;

    SELECT id INTO v_st_103 FROM public.work_items WHERE school_id = v_school_id AND item_number = 'ST-103';

    INSERT INTO public.work_items (id, school_id, board_id, parent_id, item_number, title, work_type, priority, status, category, estimated_hours, progress_percentage, rank, reporter_id)
    VALUES
        (v_tk_1009, v_school_id, v_board_id, v_st_103, 'TK-1009', 'Android app - core features', 'TASK', 'MEDIUM', 'NEW', 'IT Services', 16.0, 0, 131, v_admin_id),
        (v_tk_1010, v_school_id, v_board_id, v_st_103, 'TK-1010', 'iOS app - core features', 'TASK', 'MEDIUM', 'NEW', 'IT Services', 16.0, 0, 132, v_admin_id),
        (v_tk_1011, v_school_id, v_board_id, v_st_103, 'TK-1011', 'App testing and release', 'TASK', 'HIGH', 'NEW', 'IT Services', 16.0, 0, 133, v_admin_id)
    ON CONFLICT (school_id, item_number) DO NOTHING;

    -- ------------------------------------------------------------------------
    -- 7. KANBAN & LIST CARDS (EXACT SCREEN MATCH)
    -- ------------------------------------------------------------------------
    -- WM-1050 "Collect and verify student project submissions"
    INSERT INTO public.work_items (
        id, school_id, board_id, sprint_id, item_number, title, description,
        work_type, priority, status, category, progress_percentage, start_date, due_date, rank, reporter_id
    ) VALUES (
        v_wm_1050, v_school_id, v_board_id, v_sprint_8_id, 'WM-1050',
        'Collect and verify student project submissions',
        'Collect project submissions from all assigned students, verify as per the guidelines and update the records in the system.',
        'TASK', 'MEDIUM', 'ACTIVE', 'Academic', 60, '2025-01-03', '2025-01-10', 1, v_teacher_1
    ) ON CONFLICT (school_id, item_number) DO NOTHING;

    -- WM-1045
    INSERT INTO public.work_items (id, school_id, board_id, sprint_id, item_number, title, work_type, priority, status, category, progress_percentage, due_date, rank, reporter_id)
    VALUES (v_wm_1045, v_school_id, v_board_id, v_sprint_8_id, 'WM-1045', 'Prepare and submit Data Structures assignment', 'STORY', 'MEDIUM', 'NEW', 'Academic', 0, '2025-01-10', 2, v_teacher_1)
    ON CONFLICT (school_id, item_number) DO NOTHING;

    -- WM-1048
    INSERT INTO public.work_items (id, school_id, board_id, sprint_id, item_number, title, work_type, priority, status, category, progress_percentage, due_date, rank, reporter_id)
    VALUES (v_wm_1048, v_school_id, v_board_id, v_sprint_8_id, 'WM-1048', 'Library portal login issue for students', 'BUG', 'MEDIUM', 'NEW', 'IT Services', 0, '2025-01-09', 3, v_admin_id)
    ON CONFLICT (school_id, item_number) DO NOTHING;

    -- WM-1038
    INSERT INTO public.work_items (id, school_id, board_id, sprint_id, item_number, title, work_type, priority, status, category, progress_percentage, due_date, rank, reporter_id)
    VALUES (v_wm_1038, v_school_id, v_board_id, v_sprint_8_id, 'WM-1038', 'Design poster for annual tech fest', 'TASK', 'HIGH', 'ACTIVE', 'Student Activity', 70, '2025-01-08', 4, v_admin_id)
    ON CONFLICT (school_id, item_number) DO NOTHING;

    -- WM-1042
    INSERT INTO public.work_items (id, school_id, board_id, sprint_id, item_number, title, work_type, priority, status, category, progress_percentage, due_date, rank, reporter_id)
    VALUES (v_wm_1042, v_school_id, v_board_id, v_sprint_8_id, 'WM-1042', 'Develop online quiz for Unit-2', 'STORY', 'MEDIUM', 'ACTIVE', 'Academic', 45, '2025-01-09', 5, v_teacher_2)
    ON CONFLICT (school_id, item_number) DO NOTHING;

    -- WM-1051
    INSERT INTO public.work_items (id, school_id, board_id, sprint_id, item_number, title, work_type, priority, status, category, progress_percentage, due_date, rank, reporter_id)
    VALUES (v_wm_1051, v_school_id, v_board_id, v_sprint_8_id, 'WM-1051', 'Update laboratory equipment inventory', 'TASK', 'MEDIUM', 'NEW', 'Administration', 0, '2025-01-12', 6, v_admin_id)
    ON CONFLICT (school_id, item_number) DO NOTHING;

    -- WM-1032
    INSERT INTO public.work_items (id, school_id, board_id, sprint_id, item_number, title, work_type, priority, status, category, progress_percentage, due_date, completed_at, rank, reporter_id)
    VALUES (v_wm_1032, v_school_id, v_board_id, v_sprint_8_id, 'WM-1032', 'Projector not working in Room A-203', 'BUG', 'HIGH', 'RESOLVED', 'Facilities', 100, '2025-01-07', '2025-01-07 14:00:00+00', 7, v_admin_id)
    ON CONFLICT (school_id, item_number) DO NOTHING;

    -- WM-1035
    INSERT INTO public.work_items (id, school_id, board_id, sprint_id, item_number, title, work_type, priority, status, category, progress_percentage, due_date, completed_at, rank, reporter_id)
    VALUES (v_wm_1035, v_school_id, v_board_id, v_sprint_8_id, 'WM-1035', 'Update exam timetable and notify students', 'TASK', 'MEDIUM', 'RESOLVED', 'Examination', 100, '2025-01-06', '2025-01-06 11:30:00+00', 8, v_teacher_1)
    ON CONFLICT (school_id, item_number) DO NOTHING;

    -- WM-1027
    INSERT INTO public.work_items (id, school_id, board_id, sprint_id, item_number, title, work_type, priority, status, category, progress_percentage, due_date, completed_at, rank, reporter_id)
    VALUES (v_wm_1027, v_school_id, v_board_id, v_sprint_8_id, 'WM-1027', 'Prepare and publish seminar report', 'TASK', 'MEDIUM', 'COMPLETED', 'Department', 100, '2025-01-05', '2025-01-05 16:00:00+00', 9, v_teacher_1)
    ON CONFLICT (school_id, item_number) DO NOTHING;

    -- WM-1028
    INSERT INTO public.work_items (id, school_id, board_id, sprint_id, item_number, title, work_type, priority, status, category, progress_percentage, due_date, completed_at, rank, reporter_id)
    VALUES (v_wm_1028, v_school_id, v_board_id, v_sprint_8_id, 'WM-1028', 'Install and configure new printers (Admin Block)', 'TASK', 'MEDIUM', 'COMPLETED', 'IT Services', 100, '2025-01-04', '2025-01-04 15:00:00+00', 10, v_admin_id)
    ON CONFLICT (school_id, item_number) DO NOTHING;

    -- WM-1041
    INSERT INTO public.work_items (id, school_id, board_id, sprint_id, item_number, title, work_type, priority, status, category, progress_percentage, due_date, completed_at, rank, reporter_id)
    VALUES (v_wm_1041, v_school_id, v_board_id, v_sprint_8_id, 'WM-1041', 'Upload lectures for Week 3', 'STORY', 'LOW', 'RESOLVED', 'Academic', 100, '2025-01-05', '2025-01-05 12:00:00+00', 11, v_teacher_2)
    ON CONFLICT (school_id, item_number) DO NOTHING;

    -- WM-1031
    INSERT INTO public.work_items (id, school_id, board_id, sprint_id, item_number, title, work_type, priority, status, category, progress_percentage, due_date, completed_at, rank, reporter_id)
    VALUES (v_wm_1031, v_school_id, v_board_id, v_sprint_8_id, 'WM-1031', 'Conduct orientation for new students', 'STORY', 'LOW', 'COMPLETED', 'Student Affairs', 100, '2025-01-03', '2025-01-03 10:00:00+00', 12, v_teacher_1)
    ON CONFLICT (school_id, item_number) DO NOTHING;

    -- Refresh all IDs from DB to ensure foreign key safety on re-seed
    SELECT id INTO v_wm_1050 FROM public.work_items WHERE school_id = v_school_id AND item_number = 'WM-1050';
    SELECT id INTO v_wm_1045 FROM public.work_items WHERE school_id = v_school_id AND item_number = 'WM-1045';
    SELECT id INTO v_wm_1048 FROM public.work_items WHERE school_id = v_school_id AND item_number = 'WM-1048';
    SELECT id INTO v_wm_1038 FROM public.work_items WHERE school_id = v_school_id AND item_number = 'WM-1038';
    SELECT id INTO v_wm_1042 FROM public.work_items WHERE school_id = v_school_id AND item_number = 'WM-1042';
    SELECT id INTO v_wm_1051 FROM public.work_items WHERE school_id = v_school_id AND item_number = 'WM-1051';
    SELECT id INTO v_wm_1032 FROM public.work_items WHERE school_id = v_school_id AND item_number = 'WM-1032';
    SELECT id INTO v_wm_1035 FROM public.work_items WHERE school_id = v_school_id AND item_number = 'WM-1035';
    SELECT id INTO v_wm_1027 FROM public.work_items WHERE school_id = v_school_id AND item_number = 'WM-1027';
    SELECT id INTO v_wm_1028 FROM public.work_items WHERE school_id = v_school_id AND item_number = 'WM-1028';
    SELECT id INTO v_wm_1041 FROM public.work_items WHERE school_id = v_school_id AND item_number = 'WM-1041';
    SELECT id INTO v_wm_1031 FROM public.work_items WHERE school_id = v_school_id AND item_number = 'WM-1031';
    SELECT id INTO v_tk_1001 FROM public.work_items WHERE school_id = v_school_id AND item_number = 'TK-1001';
    SELECT id INTO v_tk_1002 FROM public.work_items WHERE school_id = v_school_id AND item_number = 'TK-1002';
    SELECT id INTO v_tk_1003 FROM public.work_items WHERE school_id = v_school_id AND item_number = 'TK-1003';
    SELECT id INTO v_tk_1004 FROM public.work_items WHERE school_id = v_school_id AND item_number = 'TK-1004';
    SELECT id INTO v_tk_1005 FROM public.work_items WHERE school_id = v_school_id AND item_number = 'TK-1005';
    SELECT id INTO v_tk_1006 FROM public.work_items WHERE school_id = v_school_id AND item_number = 'TK-1006';
    SELECT id INTO v_tk_1007 FROM public.work_items WHERE school_id = v_school_id AND item_number = 'TK-1007';
    SELECT id INTO v_tk_1008 FROM public.work_items WHERE school_id = v_school_id AND item_number = 'TK-1008';

    -- Checklists for WM-1050 (2/3 completed)
    INSERT INTO public.work_item_checklists (work_item_id, title, is_completed, sort_order)
    VALUES
        (v_wm_1050, 'Receive submissions from students', TRUE, 1),
        (v_wm_1050, 'Verify as per evaluation criteria', TRUE, 2),
        (v_wm_1050, 'Update final list in the portal', FALSE, 3)
    ON CONFLICT DO NOTHING;

    -- Attachments for WM-1050
    INSERT INTO public.work_item_attachments (work_item_id, file_name, file_url, file_size_bytes, file_type, uploaded_by)
    VALUES
        (v_wm_1050, 'Project_Guidelines.pdf', 'https://edushamiit.edu/docs/Project_Guidelines.pdf', 1258291, 'pdf', v_teacher_1),
        (v_wm_1050, 'Evaluation_Criteria.docx', 'https://edushamiit.edu/docs/Evaluation_Criteria.docx', 468992, 'docx', v_teacher_1)
    ON CONFLICT DO NOTHING;

    -- Labels for WM-1050
    INSERT INTO public.work_item_labels (work_item_id, label)
    VALUES (v_wm_1050, 'Student Project'), (v_wm_1050, 'Academic')
    ON CONFLICT DO NOTHING;

    -- ------------------------------------------------------------------------
    -- 8. ASSIGNEES FOR CARDS (USING EXISTING PROFILES)
    -- ------------------------------------------------------------------------
    INSERT INTO public.work_item_assignees (work_item_id, user_id, role_type)
    VALUES
        (v_wm_1050, v_teacher_1, 'PRIMARY'),
        (v_wm_1050, v_teacher_2, 'COLLABORATOR'),
        (v_wm_1050, v_admin_id, 'REVIEWER'),
        (v_wm_1045, v_student_1, 'PRIMARY'),
        (v_wm_1048, v_admin_id, 'PRIMARY'),
        (v_wm_1038, v_student_1, 'PRIMARY'),
        (v_wm_1038, v_teacher_1, 'COLLABORATOR'),
        (v_wm_1042, v_teacher_2, 'PRIMARY'),
        (v_wm_1051, v_admin_id, 'PRIMARY'),
        (v_wm_1032, v_admin_id, 'PRIMARY'),
        (v_wm_1035, v_teacher_1, 'PRIMARY'),
        (v_wm_1027, v_teacher_1, 'PRIMARY'),
        (v_wm_1028, v_admin_id, 'PRIMARY'),
        (v_wm_1041, v_teacher_2, 'PRIMARY'),
        (v_wm_1031, v_teacher_1, 'PRIMARY'),
        (v_st_101, v_teacher_1, 'PRIMARY'),
        (v_st_101, v_teacher_2, 'COLLABORATOR'),
        (v_tk_1001, v_teacher_1, 'PRIMARY'),
        (v_tk_1002, v_teacher_1, 'PRIMARY'),
        (v_tk_1003, v_teacher_2, 'PRIMARY'),
        (v_tk_1004, v_admin_id, 'PRIMARY'),
        (v_st_102, v_teacher_2, 'PRIMARY'),
        (v_tk_1005, v_teacher_2, 'PRIMARY'),
        (v_tk_1006, v_teacher_1, 'PRIMARY'),
        (v_tk_1007, v_admin_id, 'PRIMARY'),
        (v_tk_1008, v_admin_id, 'PRIMARY')
    ON CONFLICT DO NOTHING;

    -- ------------------------------------------------------------------------
    -- 9. RECENT ACTIVITY LOGS
    -- ------------------------------------------------------------------------
    INSERT INTO public.work_item_activity_logs (work_item_id, school_id, actor_id, action_type, message, created_at)
    VALUES
        (v_wm_1041, v_school_id, v_teacher_1, 'STATUS_CHANGE', 'Dr. Neha Sharma moved WM-1041 to Resolved', NOW() - INTERVAL '5 minutes'),
        (v_wm_1050, v_school_id, v_admin_id, 'COMMENT_ADDED', 'Amit Kumar commented on WM-1049: "Wi-Fi installation is 80% complete."', NOW() - INTERVAL '12 minutes'),
        (v_wm_1038, v_school_id, v_teacher_2, 'DUE_DATE_CHANGED', 'Prof. R. Iyer changed due date of WM-1038 to Jan 08', NOW() - INTERVAL '25 minutes'),
        (v_wm_1050, v_school_id, v_admin_id, 'REASSIGNED', 'System auto-assigned WM-1056 to Sneha Patel', NOW() - INTERVAL '30 minutes')
    ON CONFLICT DO NOTHING;

END;
$$;
