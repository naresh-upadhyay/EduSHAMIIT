-- ============================================================================
-- Migration 479: Seed Rich Multi-Page Quadratic Equations Whiteboard
-- Matches Open Whiteboard mockup: 4 boards/pages with equations, strokes,
-- coordinate graph, discriminant summary, factorisation, and version history.
-- ============================================================================

BEGIN;

DO $$
DECLARE
    v_school_id UUID := '11111111-1111-1111-1111-111111111111';
    v_session_id UUID := 'c1000000-0000-0000-0000-000000000010';
    v_wb_id UUID;
    v_p1 UUID := 'e1000001-0000-0000-0000-000000000001';
    v_p2 UUID := 'e1000001-0000-0000-0000-000000000002';
    v_p3 UUID := 'e1000001-0000-0000-0000-000000000003';
    v_p4 UUID := 'e1000001-0000-0000-0000-000000000004';
    v_teacher_id UUID;
    v_snap_id UUID := gen_random_uuid();
BEGIN
    SELECT id INTO v_teacher_id FROM public.profiles WHERE school_id = v_school_id AND role ILIKE '%teacher%' LIMIT 1;
    IF v_teacher_id IS NULL THEN
        SELECT id INTO v_teacher_id FROM public.profiles WHERE school_id = v_school_id LIMIT 1;
    END IF;

    SELECT id INTO v_wb_id FROM public.live_class_whiteboards WHERE session_id = v_session_id LIMIT 1;

    IF v_wb_id IS NULL THEN
        v_wb_id := 'b5f693e1-bc99-4585-a268-a27a6aae8eab';
        INSERT INTO public.live_class_whiteboards (
            id, session_id, school_id, title, description, created_by, owner_user_id, last_saved_by,
            status, current_revision, teacher_only_mode, collaboration_enabled, template_type
        ) VALUES (
            v_wb_id, v_session_id, v_school_id,
            'Whiteboard - Class 10 – Mathematics',
            'Quadratic Equations & Discriminant Visualisation',
            v_teacher_id, v_teacher_id, v_teacher_id,
            'ACTIVE', 4, FALSE, TRUE, 'mathematics'
        ) ON CONFLICT (id) DO NOTHING;
    ELSE
        UPDATE public.live_class_whiteboards
        SET title = 'Whiteboard - Class 10 – Mathematics',
            description = 'Quadratic Equations & Discriminant Visualisation',
            owner_user_id = COALESCE(owner_user_id, v_teacher_id),
            created_by = COALESCE(created_by, v_teacher_id),
            current_revision = GREATEST(COALESCE(current_revision, 1), 4),
            collaboration_enabled = TRUE,
            teacher_only_mode = FALSE,
            template_type = 'mathematics',
            updated_at = NOW()
        WHERE id = v_wb_id;
    END IF;

    -- Insert 4 Pages matching Mockup ("1. Quadratic Equations", "2. Discriminant", "3. Factorisation", "4. Graph")
    INSERT INTO public.whiteboard_pages (id, whiteboard_id, school_id, title, page_order, background_type, created_by)
    VALUES
        (v_p1, v_wb_id, v_school_id, '1. Quadratic Equations', 1, 'plain', v_teacher_id),
        (v_p2, v_wb_id, v_school_id, '2. Discriminant', 2, 'light_grid', v_teacher_id),
        (v_p3, v_wb_id, v_school_id, '3. Factorisation', 3, 'ruled', v_teacher_id),
        (v_p4, v_wb_id, v_school_id, '4. Graph', 4, 'graph', v_teacher_id)
    ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, page_order = EXCLUDED.page_order, background_type = EXCLUDED.background_type;

    -- Seed Page 1 Objects (Equations, Texts, Highlighted Boxes, Coordinate Parabola Curve)
    INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
    VALUES
        (v_wb_id, v_p1, v_school_id, 'obj_p1_title', 'text', '{"x": 110, "y": 40, "width": 440, "height": 54, "text": "Quadratic Equations", "fontSize": 34, "fontFamily": "sans-serif", "color": "#1D4ED8", "bold": true, "italic": true, "underline": false, "align": "left"}'::jsonb, 1, v_teacher_id),
        (v_wb_id, v_p1, v_school_id, 'obj_p1_underline', 'line', '{"x1": 100, "y1": 94, "x2": 490, "y2": 90, "color": "#DC2626", "strokeWidth": 3}'::jsonb, 2, v_teacher_id),
        (v_wb_id, v_p1, v_school_id, 'obj_p1_std_box', 'equation', '{"x": 120, "y": 116, "width": 320, "height": 56, "latex": "ax^2 + bx + c = 0", "display": "ax² + bx + c = 0", "fontSize": 26, "color": "#0F172A", "bgColor": "#E0F2FE", "borderColor": "#93C5FD"}'::jsonb, 3, v_teacher_id),
        (v_wb_id, v_p1, v_school_id, 'obj_p1_sol_lbl', 'text', '{"x": 70, "y": 200, "width": 160, "height": 38, "text": "Solution:", "fontSize": 22, "color": "#1D4ED8", "bold": true, "underline": true}'::jsonb, 4, v_teacher_id),
        (v_wb_id, v_p1, v_school_id, 'obj_p1_formula', 'equation', '{"x": 95, "y": 248, "width": 350, "height": 84, "latex": "x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}", "display": "x = (-b ± √(b² - 4ac)) / 2a", "fontSize": 24, "color": "#0F172A", "bgColor": "#FEF08A", "borderColor": "#FDE047"}'::jsonb, 5, v_teacher_id),
        (v_wb_id, v_p1, v_school_id, 'obj_p1_notes', 'text', '{"x": 95, "y": 355, "width": 410, "height": 180, "text": "where, a ≠ 0\nD = b² - 4ac   (Discriminant)\n• D > 0 : Two distinct real roots\n• D = 0 : One real (repeated) root\n• D < 0 : No real roots", "fontSize": 17, "color": "#0F172A", "bold": false}'::jsonb, 6, v_teacher_id),
        (v_wb_id, v_p1, v_school_id, 'obj_p1_yaxis', 'arrow', '{"x1": 650, "y1": 370, "x2": 650, "y2": 80, "color": "#1E293B", "strokeWidth": 2.5}'::jsonb, 7, v_teacher_id),
        (v_wb_id, v_p1, v_school_id, 'obj_p1_xaxis', 'arrow', '{"x1": 520, "y1": 280, "x2": 790, "y2": 280, "color": "#1E293B", "strokeWidth": 2.5}'::jsonb, 8, v_teacher_id),
        (v_wb_id, v_p1, v_school_id, 'obj_p1_parabola', 'stroke', '{"color": "#DC2626", "strokeWidth": 3.5, "opacity": 1.0, "points": [[565, 110], [580, 175], [598, 240], [615, 285], [632, 315], [650, 326], [668, 315], [685, 285], [702, 240], [720, 175], [735, 110]]}'::jsonb, 9, v_teacher_id),
        (v_wb_id, v_p1, v_school_id, 'obj_p1_vertex_lbl', 'equation', '{"x": 570, "y": 388, "width": 200, "height": 54, "latex": "(-\\frac{b}{2a}, \\frac{4ac - b^2}{4a})", "display": "(-b/2a , (4ac - b²)/4a)", "fontSize": 15, "color": "#6D28D9", "bgColor": "#F5F3FF", "borderColor": "#DDD6FE"}'::jsonb, 10, v_teacher_id)
    ON CONFLICT (page_id, object_id) DO NOTHING;

    -- Seed Page 2 Objects
    INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
    VALUES
        (v_wb_id, v_p2, v_school_id, 'obj_p2_title', 'text', '{"x": 90, "y": 50, "width": 400, "height": 48, "text": "Discriminant Analysis", "fontSize": 28, "color": "#1D4ED8", "bold": true}'::jsonb, 1, v_teacher_id),
        (v_wb_id, v_p2, v_school_id, 'obj_p2_eq', 'equation', '{"x": 90, "y": 120, "width": 300, "height": 64, "latex": "D = b^2 - 4ac", "display": "D = b² - 4ac", "fontSize": 28, "color": "#0F172A", "bgColor": "#EFF6FF", "borderColor": "#BFDBFE"}'::jsonb, 2, v_teacher_id),
        (v_wb_id, v_p2, v_school_id, 'obj_p2_note', 'sticky_note', '{"x": 90, "y": 220, "width": 260, "height": 140, "text": "Key Rule:\nIf D < 0, parabola does NOT intersect the X-axis.", "bgColor": "#FEF3C7", "color": "#78350F", "fontSize": 15}'::jsonb, 3, v_teacher_id)
    ON CONFLICT (page_id, object_id) DO NOTHING;

    -- Seed Page 3 Objects
    INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
    VALUES
        (v_wb_id, v_p3, v_school_id, 'obj_p3_eq', 'equation', '{"x": 100, "y": 80, "width": 340, "height": 64, "latex": "x^2 - 5x + 6 = 0", "display": "x² - 5x + 6 = 0", "fontSize": 26, "color": "#0F172A", "bgColor": "#F0FDF4", "borderColor": "#BBF7D0"}'::jsonb, 1, v_teacher_id),
        (v_wb_id, v_p3, v_school_id, 'obj_p3_step', 'text', '{"x": 100, "y": 170, "width": 360, "height": 120, "text": "Splitting middle term:\n(x - 2)(x - 3) = 0\n⇒ x = 2  or  x = 3", "fontSize": 20, "color": "#1E293B", "bold": false}'::jsonb, 2, v_teacher_id)
    ON CONFLICT (page_id, object_id) DO NOTHING;

    -- Seed Page 4 Objects
    INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
    VALUES
        (v_wb_id, v_p4, v_school_id, 'obj_p4_yaxis', 'arrow', '{"x1": 420, "y1": 440, "x2": 420, "y2": 60, "color": "#0F172A", "strokeWidth": 2.5}'::jsonb, 1, v_teacher_id),
        (v_wb_id, v_p4, v_school_id, 'obj_p4_xaxis', 'arrow', '{"x1": 160, "y1": 280, "x2": 680, "y2": 280, "color": "#0F172A", "strokeWidth": 2.5}'::jsonb, 2, v_teacher_id),
        (v_wb_id, v_p4, v_school_id, 'obj_p4_curve', 'stroke', '{"color": "#2563EB", "strokeWidth": 3.5, "opacity": 1.0, "points": [[280, 90], [310, 170], [345, 245], [380, 300], [420, 325], [460, 300], [495, 245], [530, 170], [560, 90]]}'::jsonb, 3, v_teacher_id)
    ON CONFLICT (page_id, object_id) DO NOTHING;

    -- Create initial Snapshot & Checkpoint if none exist
    IF NOT EXISTS (SELECT 1 FROM public.whiteboard_versions WHERE whiteboard_id = v_wb_id) THEN
        INSERT INTO public.whiteboard_snapshots (id, whiteboard_id, school_id, revision, snapshot_data, created_by)
        VALUES (v_snap_id, v_wb_id, v_school_id, 4, '{}'::jsonb, v_teacher_id);

        UPDATE public.whiteboard_snapshots
        SET snapshot_data = jsonb_build_object(
            'title', 'Whiteboard - Class 10 – Mathematics',
            'pages', (public.sp_get_whiteboard_full(v_wb_id, v_school_id, v_teacher_id)->'pages')
        )
        WHERE id = v_snap_id;

        INSERT INTO public.whiteboard_versions (whiteboard_id, school_id, revision, version_name, is_checkpoint, snapshot_id, created_by, created_by_name)
        VALUES (v_wb_id, v_school_id, 4, 'Quadratic Equations Lecture Notes', TRUE, v_snap_id, v_teacher_id, 'R. Kumar (Teacher)');
    END IF;
END $$;

COMMIT;
