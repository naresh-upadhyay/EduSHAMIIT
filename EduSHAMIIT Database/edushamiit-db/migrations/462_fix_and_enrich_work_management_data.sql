-- ============================================================================
-- Migration 462: Clean, Enrich & Fix Work Management Stored Procedures & Seed Data
-- ============================================================================

-- 1. Ensure clean sprints (remove duplicates)
DELETE FROM public.work_sprints 
WHERE school_id = '11111111-1111-1111-1111-111111111111' 
  AND id NOT IN (
    '35ad7623-f5d2-4935-a203-98a26e2b5444', 
    '332ae580-759a-424f-a647-c3ad9155f6c3', 
    '69680b49-1920-4f82-a7f6-88ca9ececfee'
  );

-- Ensure primary board exists with exact ID
INSERT INTO public.work_boards (id, school_id, name, code, description, board_type, is_active)
VALUES (
    '31dacd93-15ee-4eed-8994-56973fd81245',
    '11111111-1111-1111-1111-111111111111',
    'Institute Work Board',
    'IWB',
    'Main institute-wide agile work board for tracking academic, administrative, and campus operations.',
    'KANBAN',
    TRUE
) ON CONFLICT (id) DO UPDATE SET name = 'Institute Work Board', is_active = TRUE;

-- Ensure Sprint 8, 9, 10 exist with exact IDs
INSERT INTO public.work_sprints (id, school_id, board_id, name, sprint_number, status, goal, start_date, end_date, capacity_hours, team_name)
VALUES 
(
    '35ad7623-f5d2-4935-a203-98a26e2b5444',
    '11111111-1111-1111-1111-111111111111',
    '31dacd93-15ee-4eed-8994-56973fd81245',
    'Sprint 8',
    8,
    'ACTIVE',
    'Deliver student portal enhancement, examination notifications and key infrastructure fixes.',
    '2025-01-01',
    '2025-01-14',
    160.0,
    'Digital Campus Team'
),
(
    '332ae580-759a-424f-a647-c3ad9155f6c3',
    '11111111-1111-1111-1111-111111111111',
    '31dacd93-15ee-4eed-8994-56973fd81245',
    'Sprint 9',
    9,
    'PLANNED',
    'Faculty management modules and attendance auto-sync rollout.',
    '2025-01-15',
    '2025-01-28',
    160.0,
    'Digital Campus Team'
),
(
    '69680b49-1920-4f82-a7f6-88ca9ececfee',
    '11111111-1111-1111-1111-111111111111',
    '31dacd93-15ee-4eed-8994-56973fd81245',
    'Sprint 10',
    10,
    'PLANNED',
    'Mobile application initial release and semester examination scheduling.',
    '2025-01-29',
    '2025-02-11',
    160.0,
    'Digital Campus Team'
) ON CONFLICT (id) DO UPDATE SET 
    name = EXCLUDED.name,
    status = EXCLUDED.status,
    goal = EXCLUDED.goal,
    start_date = EXCLUDED.start_date,
    end_date = EXCLUDED.end_date,
    team_name = EXCLUDED.team_name;

-- 2. Clean & seed work items to match exact 66 total items (12 New, 18 Active, 9 Resolved, 27 Completed)
-- We will run a Python script to populate all 66 items cleanly and idempotently.
