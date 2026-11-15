-- ============================================================================
-- Migration 459: Enterprise Universal Work Management System Schema
-- Multi-Tenant Institute-Wide Boards, Sprints, Backlog, Kanban & Academic Work
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ----------------------------------------------------------------------------
-- 1. WORK BOARDS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.work_boards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    code VARCHAR(50) NOT NULL,
    description TEXT,
    board_type VARCHAR(50) NOT NULL DEFAULT 'KANBAN', -- 'KANBAN', 'SCRUM', 'ACADEMIC', 'SERVICE'
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_work_boards_school_code UNIQUE (school_id, code)
);

CREATE INDEX IF NOT EXISTS idx_work_boards_school ON public.work_boards(school_id);
CREATE INDEX IF NOT EXISTS idx_work_boards_active ON public.work_boards(school_id, is_active);

-- ----------------------------------------------------------------------------
-- 2. WORK BOARD MEMBERS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.work_board_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    board_id UUID NOT NULL REFERENCES public.work_boards(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role VARCHAR(50) NOT NULL DEFAULT 'MEMBER', -- 'ADMIN', 'MAINTAINER', 'MEMBER', 'VIEWER'
    permissions JSONB DEFAULT '[]'::jsonb,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_work_board_members UNIQUE (board_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_work_board_members_user ON public.work_board_members(user_id);
CREATE INDEX IF NOT EXISTS idx_work_board_members_board ON public.work_board_members(board_id);

-- ----------------------------------------------------------------------------
-- 3. WORK SPRINTS / ITERATIONS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.work_sprints (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    board_id UUID NOT NULL REFERENCES public.work_boards(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    sprint_number INT NOT NULL DEFAULT 1,
    goal TEXT,
    status VARCHAR(50) NOT NULL DEFAULT 'PLANNED', -- 'DRAFT', 'PLANNED', 'ACTIVE', 'COMPLETED', 'CANCELLED'
    team_name VARCHAR(100) DEFAULT 'All Teams',
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    working_days INT NOT NULL DEFAULT 10,
    capacity_hours NUMERIC(10,2) NOT NULL DEFAULT 160.00,
    total_points NUMERIC(10,2) DEFAULT 0,
    owner_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    retrospective_notes TEXT,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_work_sprints_school_board ON public.work_sprints(school_id, board_id);
CREATE INDEX IF NOT EXISTS idx_work_sprints_status ON public.work_sprints(school_id, status);
CREATE INDEX IF NOT EXISTS idx_work_sprints_dates ON public.work_sprints(school_id, start_date, end_date);

-- ----------------------------------------------------------------------------
-- 4. UNIVERSAL WORK ITEMS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.work_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    board_id UUID NOT NULL REFERENCES public.work_boards(id) ON DELETE CASCADE,
    sprint_id UUID REFERENCES public.work_sprints(id) ON DELETE SET NULL,
    item_number VARCHAR(30) NOT NULL, -- e.g. 'WM-1050', 'ST-101', 'TK-1001', 'EP-001'
    title VARCHAR(500) NOT NULL,
    description TEXT,
    work_type VARCHAR(50) NOT NULL DEFAULT 'TASK', -- 'EPIC', 'STORY', 'TASK', 'SUBTASK', 'BUG', 'ISSUE', 'HOMEWORK', 'ASSIGNMENT', 'IMPROVEMENT', 'REQUEST', 'MILESTONE'
    priority VARCHAR(50) NOT NULL DEFAULT 'MEDIUM', -- 'CRITICAL', 'URGENT', 'HIGH', 'MEDIUM', 'LOW'
    status VARCHAR(50) NOT NULL DEFAULT 'NEW', -- 'NEW', 'ACTIVE', 'IN_PROGRESS', 'RESOLVED', 'COMPLETED', 'BLOCKED', 'ON_HOLD', 'CANCELLED'
    category VARCHAR(100) NOT NULL DEFAULT 'General', -- 'Academic', 'IT Services', 'Administration', 'Department', 'Student Activity', 'Examination', 'Facilities', 'Other'
    parent_id UUID REFERENCES public.work_items(id) ON DELETE SET NULL,
    rank NUMERIC(15, 4) NOT NULL DEFAULT 1000.0000,
    progress_percentage INT NOT NULL DEFAULT 0,
    story_points NUMERIC(6, 2) DEFAULT 0,
    estimated_hours NUMERIC(6, 2) DEFAULT 0,
    actual_hours NUMERIC(6, 2) DEFAULT 0,
    remaining_hours NUMERIC(6, 2) DEFAULT 0,
    reporter_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    start_date DATE,
    due_date DATE,
    completed_at TIMESTAMPTZ,
    
    -- Academic Work Specifics
    academic_year_id UUID,
    class_id UUID,
    section_id UUID,
    subject_id UUID,
    is_class_wide BOOLEAN DEFAULT TRUE,
    max_marks NUMERIC(6, 2) DEFAULT 0,
    submission_deadline TIMESTAMPTZ,
    submission_format VARCHAR(50) DEFAULT 'ANY', -- 'PDF', 'DOCUMENT', 'IMAGE', 'ANY'
    
    -- Bug / Issue Specifics
    affected_module VARCHAR(100),
    environment VARCHAR(50),
    severity VARCHAR(50),
    reproduction_steps TEXT,
    expected_result TEXT,
    actual_result TEXT,
    resolution_notes TEXT,
    
    -- Request / Approval Specifics
    request_category VARCHAR(100),
    approval_status VARCHAR(50) DEFAULT 'NONE',
    approver_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    
    is_archived BOOLEAN NOT NULL DEFAULT FALSE,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_work_items_school_item_number UNIQUE (school_id, item_number)
);

CREATE INDEX IF NOT EXISTS idx_work_items_school_board ON public.work_items(school_id, board_id);
CREATE INDEX IF NOT EXISTS idx_work_items_school_status ON public.work_items(school_id, status);
CREATE INDEX IF NOT EXISTS idx_work_items_school_type ON public.work_items(school_id, work_type);
CREATE INDEX IF NOT EXISTS idx_work_items_school_priority ON public.work_items(school_id, priority);
CREATE INDEX IF NOT EXISTS idx_work_items_sprint ON public.work_items(sprint_id);
CREATE INDEX IF NOT EXISTS idx_work_items_parent ON public.work_items(parent_id);
CREATE INDEX IF NOT EXISTS idx_work_items_due_date ON public.work_items(school_id, due_date);
CREATE INDEX IF NOT EXISTS idx_work_items_rank ON public.work_items(board_id, rank);

-- ----------------------------------------------------------------------------
-- 5. WORK ITEM ASSIGNEES
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.work_item_assignees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    work_item_id UUID NOT NULL REFERENCES public.work_items(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role_type VARCHAR(50) NOT NULL DEFAULT 'PRIMARY', -- 'PRIMARY', 'COLLABORATOR', 'REVIEWER', 'WATCHER'
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_work_item_assignees UNIQUE (work_item_id, user_id, role_type)
);

CREATE INDEX IF NOT EXISTS idx_work_item_assignees_user ON public.work_item_assignees(user_id);
CREATE INDEX IF NOT EXISTS idx_work_item_assignees_item ON public.work_item_assignees(work_item_id);

-- ----------------------------------------------------------------------------
-- 6. WORK ITEM LABELS / TAGS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.work_item_labels (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    work_item_id UUID NOT NULL REFERENCES public.work_items(id) ON DELETE CASCADE,
    label VARCHAR(100) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_work_item_labels UNIQUE (work_item_id, label)
);

CREATE INDEX IF NOT EXISTS idx_work_item_labels_item ON public.work_item_labels(work_item_id);
CREATE INDEX IF NOT EXISTS idx_work_item_labels_label ON public.work_item_labels(label);

-- ----------------------------------------------------------------------------
-- 7. WORK ITEM CHECKLISTS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.work_item_checklists (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    work_item_id UUID NOT NULL REFERENCES public.work_items(id) ON DELETE CASCADE,
    title VARCHAR(300) NOT NULL,
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_work_item_checklists_item ON public.work_item_checklists(work_item_id, sort_order);

-- ----------------------------------------------------------------------------
-- 8. WORK ITEM ATTACHMENTS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.work_item_attachments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    work_item_id UUID NOT NULL REFERENCES public.work_items(id) ON DELETE CASCADE,
    file_name VARCHAR(255) NOT NULL,
    file_url TEXT NOT NULL,
    file_size_bytes BIGINT NOT NULL DEFAULT 0,
    file_type VARCHAR(100) NOT NULL DEFAULT 'document',
    uploaded_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_work_item_attachments_item ON public.work_item_attachments(work_item_id);

-- ----------------------------------------------------------------------------
-- 9. WORK ITEM COMMENTS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.work_item_comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    work_item_id UUID NOT NULL REFERENCES public.work_items(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    comment_text TEXT NOT NULL,
    is_internal BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_work_item_comments_item ON public.work_item_comments(work_item_id, created_at);

-- ----------------------------------------------------------------------------
-- 10. WORK ITEM ACTIVITY / AUDIT LOG
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.work_item_activity_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    work_item_id UUID NOT NULL REFERENCES public.work_items(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    action_type VARCHAR(50) NOT NULL, -- 'STATUS_CHANGE', 'COMMENT_ADDED', 'REASSIGNED', 'DUE_DATE_CHANGED', 'PRIORITY_CHANGED', 'ATTACHMENT_ADDED', 'CREATED'
    field_name VARCHAR(50),
    old_value TEXT,
    new_value TEXT,
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_work_item_activity_item ON public.work_item_activity_logs(work_item_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_work_item_activity_school ON public.work_item_activity_logs(school_id, created_at DESC);

-- ----------------------------------------------------------------------------
-- 11. WORK ITEM DEPENDENCIES & LINKS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.work_item_dependencies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    work_item_id UUID NOT NULL REFERENCES public.work_items(id) ON DELETE CASCADE,
    depends_on_item_id UUID NOT NULL REFERENCES public.work_items(id) ON DELETE CASCADE,
    dependency_type VARCHAR(50) NOT NULL DEFAULT 'BLOCKS', -- 'BLOCKS', 'IS_BLOCKED_BY', 'RELATES_TO', 'DUPLICATES'
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_work_item_dependency UNIQUE (work_item_id, depends_on_item_id, dependency_type)
);

CREATE INDEX IF NOT EXISTS idx_work_item_dep_item ON public.work_item_dependencies(work_item_id);
CREATE INDEX IF NOT EXISTS idx_work_item_dep_target ON public.work_item_dependencies(depends_on_item_id);

-- ----------------------------------------------------------------------------
-- 12. SPRINT DAILY SNAPSHOTS (BURNDOWN CHART)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.work_sprint_daily_snapshots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sprint_id UUID NOT NULL REFERENCES public.work_sprints(id) ON DELETE CASCADE,
    snapshot_date DATE NOT NULL,
    day_label VARCHAR(30) NOT NULL, -- e.g. 'Jan 01', 'Jan 03'
    ideal_remaining_items INT NOT NULL DEFAULT 0,
    actual_remaining_items INT NOT NULL DEFAULT 0,
    ideal_remaining_hours NUMERIC(8,2) DEFAULT 0,
    actual_remaining_hours NUMERIC(8,2) DEFAULT 0,
    completed_items_count INT NOT NULL DEFAULT 0,
    total_items_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_work_sprint_daily UNIQUE (sprint_id, snapshot_date)
);

CREATE INDEX IF NOT EXISTS idx_work_sprint_daily_sprint ON public.work_sprint_daily_snapshots(sprint_id, snapshot_date);

-- ----------------------------------------------------------------------------
-- 13. ACADEMIC HOMEWORK SUBMISSIONS & EVALUATIONS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.work_homework_submissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    work_item_id UUID NOT NULL REFERENCES public.work_items(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    submission_status VARCHAR(50) NOT NULL DEFAULT 'NOT_SUBMITTED', -- 'NOT_SUBMITTED', 'DRAFT', 'SUBMITTED', 'LATE', 'UNDER_REVIEW', 'NEEDS_REVISION', 'EVALUATED', 'RETURNED'
    submission_text TEXT,
    attachments JSONB DEFAULT '[]'::jsonb,
    submitted_at TIMESTAMPTZ,
    marks_obtained NUMERIC(6, 2),
    teacher_feedback TEXT,
    evaluated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    evaluated_at TIMESTAMPTZ,
    feedback_published BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_work_homework_submission UNIQUE (work_item_id, student_id)
);

CREATE INDEX IF NOT EXISTS idx_work_hw_sub_item ON public.work_homework_submissions(work_item_id);
CREATE INDEX IF NOT EXISTS idx_work_hw_sub_student ON public.work_homework_submissions(student_id);

-- ----------------------------------------------------------------------------
-- 14. SAVED VIEWS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.work_saved_views (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    view_name VARCHAR(150) NOT NULL,
    view_type VARCHAR(50) NOT NULL DEFAULT 'BOARD', -- 'BOARD', 'LIST', 'BACKLOG', 'SPRINTS'
    filters JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_shared BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
