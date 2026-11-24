-- Migration 582: Fix Backlog Epics Tasks and Dynamic Single Source of Truth Counts
-- Description:
-- 1. Unarchives all archived child tasks under stories of EP-002, EP-004, EP-005, EP-006.
-- 2. Sets proper titles and categories for EP-004 Student Experience stories and child tasks.
-- 3. Aligns board_id of stories and tasks to their epic so that items are visible both on the specific board and under All Boards.

DO $$
BEGIN
    -- 1. Update EP-004 stories titles and categories
    UPDATE public.work_items
    SET title = 'Student Feedback & Extracurricular Activities',
        category = 'Student Activity',
        board_id = '31dacd93-15ee-4eed-8994-56973fd81245',
        updated_at = NOW()
    WHERE item_number = 'ST-106';

    UPDATE public.work_items
    SET title = 'Campus Dining & Canteen Automation',
        category = 'Student Activity',
        board_id = '31dacd93-15ee-4eed-8994-56973fd81245',
        updated_at = NOW()
    WHERE item_number = 'ST-116';

    UPDATE public.work_items
    SET title = 'Student Wellness & Counseling Hub',
        category = 'Student Activity',
        board_id = '31dacd93-15ee-4eed-8994-56973fd81245',
        updated_at = NOW()
    WHERE item_number = 'ST-1022';

    -- 2. Unarchive and name EP-004 tasks
    UPDATE public.work_items
    SET is_archived = false,
        title = 'Online feedback and suggestion portal',
        status = 'ACTIVE',
        board_id = '31dacd93-15ee-4eed-8994-56973fd81245',
        updated_at = NOW()
    WHERE item_number = 'TK-1020';

    UPDATE public.work_items
    SET is_archived = false,
        title = 'Extracurricular club registrations',
        status = 'ACTIVE',
        board_id = '31dacd93-15ee-4eed-8994-56973fd81245',
        updated_at = NOW()
    WHERE item_number = 'TK-1021';

    UPDATE public.work_items
    SET is_archived = false,
        title = 'Canteen meal pre-ordering workflow',
        status = 'ACTIVE',
        board_id = '31dacd93-15ee-4eed-8994-56973fd81245',
        updated_at = NOW()
    WHERE item_number = 'TK-1022';

    UPDATE public.work_items
    SET is_archived = false,
        title = 'Dietary preferences & menu scheduling',
        status = 'ACTIVE',
        board_id = '31dacd93-15ee-4eed-8994-56973fd81245',
        updated_at = NOW()
    WHERE item_number = 'TK-1023';

    UPDATE public.work_items
    SET is_archived = false,
        title = 'Confidential counselor appointment booking',
        status = 'ACTIVE',
        board_id = '31dacd93-15ee-4eed-8994-56973fd81245',
        updated_at = NOW()
    WHERE item_number = 'TK-1018';

    UPDATE public.work_items
    SET is_archived = false,
        title = 'Student wellness assessment surveys',
        status = 'ACTIVE',
        board_id = '31dacd93-15ee-4eed-8994-56973fd81245',
        updated_at = NOW()
    WHERE item_number = 'TK-1019';

    -- 3. Unarchive remaining archived tasks under EP-002, EP-005, EP-006
    UPDATE public.work_items
    SET is_archived = false,
        updated_at = NOW()
    WHERE item_number IN ('TK-1012', 'TK-1013', 'TK-1014', 'TK-1025', 'TK-1026', 'TK-1027', 'TK-1028', 'TK-1052', 'TK-1053', 'TK-1054', 'TK-1055');

END $$;
