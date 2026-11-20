-- Migration 547: Whiteboard Rich Templates Engine
-- Populates authentic, editable, interactive whiteboard objects for each subject template
-- (Concept Mind Map, Process Flowchart, Mathematics, Physics, Chemistry, Biology, Geography, Engineering, Graph Paper, Ruled Lecture Notebook, Blank Canvas)

CREATE OR REPLACE FUNCTION public.sp_create_whiteboard(
    p_school_id UUID,
    p_session_id UUID,
    p_user_id UUID,
    p_title TEXT,
    p_template_type TEXT DEFAULT 'blank',
    p_collaboration_enabled BOOLEAN DEFAULT TRUE,
    p_description TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_wb_id UUID := gen_random_uuid();
    v_page_id UUID := gen_random_uuid();
    v_snap_id UUID := gen_random_uuid();
    v_bg_type TEXT := 'plain';
    v_page_title TEXT := 'Page 1';
    v_user_name TEXT;
    v_norm_template TEXT := LOWER(TRIM(COALESCE(p_template_type, 'blank')));
    v_page_objects JSONB := '[]'::jsonb;
BEGIN
    SELECT full_name INTO v_user_name FROM public.profiles WHERE id = p_user_id LIMIT 1;

    -- Determine Background Type and Page Title based on template
    IF v_norm_template IN ('mind_map', 'mindmap', 'concept_map') THEN
        v_bg_type := 'dotted';
        v_page_title := '1. Concept Mind Map';
    ELSIF v_norm_template IN ('flowchart', 'flow_chart', 'process') THEN
        v_bg_type := 'light_grid';
        v_page_title := '1. Process Flowchart';
    ELSIF v_norm_template IN ('math', 'mathematics') THEN
        v_bg_type := 'light_grid';
        v_page_title := '1. Concept & Equations';
    ELSIF v_norm_template IN ('physics', 'mechanics') THEN
        v_bg_type := 'engineering';
        v_page_title := '1. Free Body Diagram & Kinematics';
    ELSIF v_norm_template IN ('chemistry', 'chemical') THEN
        v_bg_type := 'dotted';
        v_page_title := '1. Reactions & Molecular Lab';
    ELSIF v_norm_template IN ('biology', 'cell') THEN
        v_bg_type := 'plain';
        v_page_title := '1. Cell Structure & Life Sciences';
    ELSIF v_norm_template IN ('geography', 'maps') THEN
        v_bg_type := 'light_grid';
        v_page_title := '1. Cartography & Map Grid';
    ELSIF v_norm_template = 'engineering' THEN
        v_bg_type := 'engineering';
        v_page_title := '1. Engineering Blueprint';
    ELSIF v_norm_template IN ('graph', 'graph_paper') THEN
        v_bg_type := 'graph';
        v_page_title := '1. Cartesian Plot';
    ELSIF v_norm_template IN ('general_teaching', 'ruled', 'lecture', 'notebook') THEN
        v_bg_type := 'ruled';
        v_page_title := '1. Lecture Notes';
    ELSIF v_norm_template = 'music' THEN
        v_bg_type := 'music';
        v_page_title := '1. Music Staff';
    ELSE
        v_bg_type := 'plain';
        v_page_title := '1. Drawing Canvas';
    END IF;

    -- Create Whiteboard Record
    INSERT INTO public.live_class_whiteboards (
        id, session_id, school_id, title, description,
        created_by, current_revision, teacher_only_mode,
        collaboration_enabled, presentation_mode, template_type,
        default_permissions
    ) VALUES (
        v_wb_id, p_session_id, p_school_id, p_title, p_description,
        p_user_id, 1, FALSE,
        p_collaboration_enabled, FALSE, v_norm_template,
        jsonb_build_object('can_edit', p_collaboration_enabled, 'role_defaults', jsonb_build_object('teacher', 'EDITOR', 'student', CASE WHEN p_collaboration_enabled THEN 'EDITOR' ELSE 'VIEWER' END))
    );

    -- Create Initial Page
    INSERT INTO public.whiteboard_pages (
        id, whiteboard_id, school_id, title, page_order, background_type, created_by
    ) VALUES (
        v_page_id, v_wb_id, p_school_id, v_page_title, 1, v_bg_type, p_user_id
    );

    -- Assign Owner Permissions
    INSERT INTO public.whiteboard_permissions (
        whiteboard_id, school_id, user_id, permission_type, granted_by
    ) VALUES (
        v_wb_id, p_school_id, p_user_id, 'OWNER', p_user_id
    ) ON CONFLICT DO NOTHING;

    -- =========================================================================
    -- POPULATE RICH TEMPLATE OBJECTS
    -- =========================================================================

    IF v_norm_template IN ('mind_map', 'mindmap', 'concept_map') THEN
        -- 1. Central Topic Hub
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'hub_' || substr(gen_random_uuid()::text, 1, 8), 'rectangle',
            jsonb_build_object(
                'x', 420, 'y', 270, 'width', 260, 'height', 95,
                'color', '#1E3A8A', 'bgColor', '#3B82F6', 'textColor', '#FFFFFF',
                'text', '🧠 Core Concept' || E'\n' || '[Central Theme]',
                'fontSize', 16, 'bold', true, 'rounded', true, 'strokeWidth', 3
            ), 1, p_user_id);

        -- 2. Branch 1 (North-West)
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'br1_' || substr(gen_random_uuid()::text, 1, 8), 'rectangle',
            jsonb_build_object(
                'x', 120, 'y', 120, 'width', 220, 'height', 75,
                'color', '#0369A1', 'bgColor', '#0EA5E9', 'textColor', '#FFFFFF',
                'text', '1. Core Foundations' || E'\n' || '& Principles',
                'fontSize', 13, 'bold', true, 'rounded', true, 'strokeWidth', 2
            ), 2, p_user_id);

        -- Connector 1
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'con1_' || substr(gen_random_uuid()::text, 1, 8), 'connector',
            jsonb_build_object('x1', 420, 'y1', 300, 'x2', 340, 'y2', 170, 'color', '#0EA5E9', 'strokeWidth', 3, 'label', 'leads to'), 3, p_user_id);

        -- 3. Branch 2 (North-East)
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'br2_' || substr(gen_random_uuid()::text, 1, 8), 'rectangle',
            jsonb_build_object(
                'x', 760, 'y', 120, 'width', 220, 'height', 75,
                'color', '#047857', 'bgColor', '#10B981', 'textColor', '#FFFFFF',
                'text', '2. Real-World' || E'\n' || 'Applications',
                'fontSize', 13, 'bold', true, 'rounded', true, 'strokeWidth', 2
            ), 4, p_user_id);

        -- Connector 2
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'con2_' || substr(gen_random_uuid()::text, 1, 8), 'connector',
            jsonb_build_object('x1', 680, 'y1', 300, 'x2', 760, 'y2', 170, 'color', '#10B981', 'strokeWidth', 3, 'label', 'applies to'), 5, p_user_id);

        -- 4. Branch 3 (South-West)
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'br3_' || substr(gen_random_uuid()::text, 1, 8), 'rectangle',
            jsonb_build_object(
                'x', 120, 'y', 440, 'width', 220, 'height', 75,
                'color', '#B45309', 'bgColor', '#F59E0B', 'textColor', '#FFFFFF',
                'text', '3. Methodology &' || E'\n' || 'Experimental Data',
                'fontSize', 13, 'bold', true, 'rounded', true, 'strokeWidth', 2
            ), 6, p_user_id);

        -- Connector 3
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'con3_' || substr(gen_random_uuid()::text, 1, 8), 'connector',
            jsonb_build_object('x1', 420, 'y1', 340, 'x2', 340, 'y2', 460, 'color', '#F59E0B', 'strokeWidth', 3, 'label', 'tested by'), 7, p_user_id);

        -- 5. Branch 4 (South-East)
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'br4_' || substr(gen_random_uuid()::text, 1, 8), 'rectangle',
            jsonb_build_object(
                'x', 760, 'y', 440, 'width', 220, 'height', 75,
                'color', '#6D28D9', 'bgColor', '#8B5CF6', 'textColor', '#FFFFFF',
                'text', '4. Quantitative' || E'\n' || 'Outcomes & Results',
                'fontSize', 13, 'bold', true, 'rounded', true, 'strokeWidth', 2
            ), 8, p_user_id);

        -- Connector 4
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'con4_' || substr(gen_random_uuid()::text, 1, 8), 'connector',
            jsonb_build_object('x1', 680, 'y1', 340, 'x2', 760, 'y2', 460, 'color', '#8B5CF6', 'strokeWidth', 3, 'label', 'yields'), 9, p_user_id);

        -- Sticky Note 1
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'nt1_' || substr(gen_random_uuid()::text, 1, 8), 'sticky_note',
            jsonb_build_object(
                'x', 120, 'y', 230, 'width', 200, 'height', 110,
                'text', '💡 Brainstorming Note:' || E'\n' || '• Key variables identified' || E'\n' || '• Working hypotheses',
                'bgColor', '#FEF3C7', 'color', '#0F172A', 'fontSize', 13
            ), 10, p_user_id);

        -- Sticky Note 2
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'nt2_' || substr(gen_random_uuid()::text, 1, 8), 'sticky_note',
            jsonb_build_object(
                'x', 760, 'y', 230, 'width', 200, 'height', 110,
                'text', '🎯 Action Items:' || E'\n' || '• Assign subgroup topics' || E'\n' || '• Review live feedback',
                'bgColor', '#DCFCE7', 'color', '#0F172A', 'fontSize', 13
            ), 11, p_user_id);

    ELSIF v_norm_template IN ('flowchart', 'flow_chart', 'process') THEN
        -- 1. Start Terminator
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'fc_start_' || substr(gen_random_uuid()::text, 1, 8), 'rectangle',
            jsonb_build_object('x', 440, 'y', 60, 'width', 200, 'height', 55, 'color', '#047857', 'bgColor', '#10B981', 'textColor', '#FFFFFF', 'text', 'START PROCESS', 'bold', true, 'rounded', true, 'strokeWidth', 2.5), 1, p_user_id);

        -- Arrow 1
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'fc_a1_' || substr(gen_random_uuid()::text, 1, 8), 'arrow',
            jsonb_build_object('x1', 540, 'y1', 115, 'x2', 540, 'y2', 165, 'color', '#0F172A', 'strokeWidth', 2.5), 2, p_user_id);

        -- Step 1 Process Block
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'fc_p1_' || substr(gen_random_uuid()::text, 1, 8), 'rectangle',
            jsonb_build_object('x', 410, 'y', 165, 'width', 260, 'height', 65, 'color', '#1D4ED8', 'bgColor', '#3B82F6', 'textColor', '#FFFFFF', 'text', '1. Capture Input & Validate', 'bold', true, 'rounded', false, 'strokeWidth', 2), 3, p_user_id);

        -- Arrow 2
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'fc_a2_' || substr(gen_random_uuid()::text, 1, 8), 'arrow',
            jsonb_build_object('x1', 540, 'y1', 230, 'x2', 540, 'y2', 285, 'color', '#0F172A', 'strokeWidth', 2.5), 4, p_user_id);

        -- Decision Block (Diamond)
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'fc_dec_' || substr(gen_random_uuid()::text, 1, 8), 'diamond',
            jsonb_build_object('x', 430, 'y', 285, 'width', 220, 'height', 95, 'color', '#B45309', 'bgColor', '#F59E0B', 'textColor', '#FFFFFF', 'text', 'Parameters Valid?', 'bold', true, 'strokeWidth', 2.5), 5, p_user_id);

        -- Yes Arrow
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'fc_ayes_' || substr(gen_random_uuid()::text, 1, 8), 'arrow',
            jsonb_build_object('x1', 540, 'y1', 380, 'x2', 540, 'y2', 440, 'color', '#059669', 'strokeWidth', 2.5, 'label', 'YES'), 6, p_user_id);

        -- Step 2 Process Block
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'fc_p2_' || substr(gen_random_uuid()::text, 1, 8), 'rectangle',
            jsonb_build_object('x', 410, 'y', 440, 'width', 260, 'height', 65, 'color', '#6D28D9', 'bgColor', '#8B5CF6', 'textColor', '#FFFFFF', 'text', '2. Execute Workflow / Compute', 'bold', true, 'rounded', false, 'strokeWidth', 2), 7, p_user_id);

        -- No Arrow
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'fc_ano_' || substr(gen_random_uuid()::text, 1, 8), 'arrow',
            jsonb_build_object('x1', 650, 'y1', 332, 'x2', 780, 'y2', 332, 'color', '#DC2626', 'strokeWidth', 2.5, 'label', 'NO'), 8, p_user_id);

        -- Error Handling Block
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'fc_err_' || substr(gen_random_uuid()::text, 1, 8), 'rectangle',
            jsonb_build_object('x', 780, 'y', 300, 'width', 200, 'height', 65, 'color', '#B91C1C', 'bgColor', '#EF4444', 'textColor', '#FFFFFF', 'text', 'Log Error & Notify', 'bold', true, 'rounded', true, 'strokeWidth', 2), 9, p_user_id);

        -- Loopback Arrow
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'fc_loop_' || substr(gen_random_uuid()::text, 1, 8), 'curved_line',
            jsonb_build_object('x1', 880, 'y1', 300, 'x2', 670, 'y2', 195, 'color', '#DC2626', 'strokeWidth', 2, 'label', 'retry'), 10, p_user_id);

        -- Arrow 3
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'fc_a3_' || substr(gen_random_uuid()::text, 1, 8), 'arrow',
            jsonb_build_object('x1', 540, 'y1', 505, 'x2', 540, 'y2', 565, 'color', '#0F172A', 'strokeWidth', 2.5), 11, p_user_id);

        -- End Terminator
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'fc_end_' || substr(gen_random_uuid()::text, 1, 8), 'rectangle',
            jsonb_build_object('x', 440, 'y', 565, 'width', 200, 'height', 55, 'color', '#334155', 'bgColor', '#64748B', 'textColor', '#FFFFFF', 'text', 'END PROCESS', 'bold', true, 'rounded', true, 'strokeWidth', 2.5), 12, p_user_id);

    ELSIF v_norm_template IN ('math', 'mathematics') THEN
        -- Coordinate X Axis
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'math_x_' || substr(gen_random_uuid()::text, 1, 8), 'arrow',
            jsonb_build_object('x1', 100, 'y1', 420, 'x2', 640, 'y2', 420, 'color', '#0F172A', 'strokeWidth', 3, 'label', 'X-Axis'), 1, p_user_id);

        -- Coordinate Y Axis
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'math_y_' || substr(gen_random_uuid()::text, 1, 8), 'arrow',
            jsonb_build_object('x1', 370, 'y1', 680, 'x2', 370, 'y2', 120, 'color', '#0F172A', 'strokeWidth', 3, 'label', 'Y-Axis'), 2, p_user_id);

        -- Origin Circle
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'math_orig_' || substr(gen_random_uuid()::text, 1, 8), 'circle',
            jsonb_build_object('x', 366, 'y', 416, 'width', 8, 'height', 8, 'color', '#DC2626', 'bgColor', '#DC2626', 'strokeWidth', 1), 3, p_user_id);

        -- Parabola Curve
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'math_curve_' || substr(gen_random_uuid()::text, 1, 8), 'curved_line',
            jsonb_build_object('x1', 170, 'y1', 200, 'x2', 570, 'y2', 200, 'color', '#2563EB', 'strokeWidth', 3.5, 'label', 'y = x² - 4'), 4, p_user_id);

        -- Vertex Text
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'math_vtxt_' || substr(gen_random_uuid()::text, 1, 8), 'text',
            jsonb_build_object('x', 380, 'y', 430, 'width', 120, 'height', 40, 'text', 'Vertex (0, -4)', 'fontSize', 13, 'bold', true, 'color', '#2563EB'), 5, p_user_id);

        -- Quadratic Standard Form Equation
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'math_eq1_' || substr(gen_random_uuid()::text, 1, 8), 'equation',
            jsonb_build_object('x', 720, 'y', 120, 'width', 340, 'height', 75, 'latex', 'f(x) = ax^2 + bx + c = 0', 'display', 'f(x) = ax² + bx + c = 0', 'color', '#1E3A8A', 'bgColor', '#EFF6FF', 'borderColor', '#3B82F6'), 6, p_user_id);

        -- Quadratic Roots Formula
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'math_eq2_' || substr(gen_random_uuid()::text, 1, 8), 'equation',
            jsonb_build_object('x', 720, 'y', 220, 'width', 340, 'height', 85, 'latex', 'x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}', 'display', 'x = (-b ± √(b² - 4ac)) / 2a', 'color', '#065F46', 'bgColor', '#F0FDF4', 'borderColor', '#10B981'), 7, p_user_id);

        -- Discriminant Sticky Note
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'math_disc_' || substr(gen_random_uuid()::text, 1, 8), 'sticky_note',
            jsonb_build_object(
                'x', 720, 'y', 330, 'width', 340, 'height', 160,
                'text', 'Discriminant Rules (Δ = b² - 4ac):' || E'\n' || '• Δ > 0  ⟶  Two real, distinct roots' || E'\n' || '• Δ = 0  ⟶  One real root (repeated)' || E'\n' || '• Δ < 0  ⟶  Two complex conjugate roots' || E'\n\n' || 'Vertex: (-b/2a, -Δ/4a)',
                'bgColor', '#FEF3C7', 'color', '#0F172A', 'fontSize', 13
            ), 8, p_user_id);

        -- Student Practice Zone
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'math_sz_' || substr(gen_random_uuid()::text, 1, 8), 'student_zone',
            jsonb_build_object('x', 720, 'y', 520, 'width', 340, 'height', 150, 'label', 'Student Practice Zone: Solve 2x² - 5x + 2 = 0', 'color', '#2563EB', 'bgColor', '#EFF6FF'), 9, p_user_id);

    ELSIF v_norm_template IN ('physics', 'mechanics') THEN
        -- Surface line
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'phy_line_' || substr(gen_random_uuid()::text, 1, 8), 'line',
            jsonb_build_object('x1', 140, 'y1', 440, 'x2', 600, 'y2', 440, 'color', '#334155', 'strokeWidth', 4), 1, p_user_id);

        -- Mass Block
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'phy_blk_' || substr(gen_random_uuid()::text, 1, 8), 'rectangle',
            jsonb_build_object('x', 310, 'y', 340, 'width', 120, 'height', 100, 'color', '#1D4ED8', 'bgColor', '#DBEAFE', 'textColor', '#1E3A8A', 'text', 'Mass M' || E'\n' || '[5.0 kg]', 'bold', true, 'rounded', false, 'strokeWidth', 2.5), 2, p_user_id);

        -- Normal Force
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'phy_fn_' || substr(gen_random_uuid()::text, 1, 8), 'arrow',
            jsonb_build_object('x1', 370, 'y1', 340, 'x2', 370, 'y2', 190, 'color', '#059669', 'strokeWidth', 3.5, 'label', 'F_N = mg = 49 N'), 3, p_user_id);

        -- Gravity Force
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'phy_fg_' || substr(gen_random_uuid()::text, 1, 8), 'arrow',
            jsonb_build_object('x1', 370, 'y1', 440, 'x2', 370, 'y2', 590, 'color', '#DC2626', 'strokeWidth', 3.5, 'label', 'F_g = mg = 49 N'), 4, p_user_id);

        -- Applied Force
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'phy_fa_' || substr(gen_random_uuid()::text, 1, 8), 'arrow',
            jsonb_build_object('x1', 430, 'y1', 390, 'x2', 580, 'y2', 390, 'color', '#2563EB', 'strokeWidth', 3.5, 'label', 'F_applied = 25 N'), 5, p_user_id);

        -- Friction Force
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'phy_fk_' || substr(gen_random_uuid()::text, 1, 8), 'arrow',
            jsonb_build_object('x1', 310, 'y1', 390, 'x2', 180, 'y2', 390, 'color', '#D97706', 'strokeWidth', 3.5, 'label', 'f_k = μ_k · F_N'), 6, p_user_id);

        -- Newton's Second Law
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'phy_newt_' || substr(gen_random_uuid()::text, 1, 8), 'equation',
            jsonb_build_object('x', 680, 'y', 130, 'width', 340, 'height', 75, 'latex', '\Sigma \vec{F} = m \cdot \vec{a}', 'display', 'ΣF = m · a', 'color', '#1E3A8A', 'bgColor', '#EFF6FF', 'borderColor', '#3B82F6'), 7, p_user_id);

        -- Kinematics Equation
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'phy_kin_' || substr(gen_random_uuid()::text, 1, 8), 'equation',
            jsonb_build_object('x', 680, 'y', 230, 'width', 340, 'height', 75, 'latex', 'v_f^2 = v_i^2 + 2 a \Delta x', 'display', 'vf² = vi² + 2a·Δx', 'color', '#065F46', 'bgColor', '#F0FDF4', 'borderColor', '#10B981'), 8, p_user_id);

        -- Physics Sticky Note
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'phy_sum_' || substr(gen_random_uuid()::text, 1, 8), 'sticky_note',
            jsonb_build_object(
                'x', 680, 'y', 330, 'width', 340, 'height', 160,
                'text', 'Mechanics Key Principles:' || E'\n' || '• Equilibrium holds when ΣF = 0' || E'\n' || '• Work-Energy: W = ∫ F·dx = ΔKE' || E'\n' || '• Maximum static friction: f_s(max) ≥ f_k' || E'\n' || '• Net Acceleration: a = (F_app - f_k) / m',
                'bgColor', '#FEF3C7', 'color', '#0F172A', 'fontSize', 13
            ), 9, p_user_id);

    ELSIF v_norm_template IN ('chemistry', 'chemical') THEN
        -- Benzene Hexagon
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'chem_hex_' || substr(gen_random_uuid()::text, 1, 8), 'polygon',
            jsonb_build_object('x', 180, 'y', 240, 'width', 140, 'height', 140, 'color', '#0F172A', 'bgColor', '#F8FAFC', 'strokeWidth', 3.5), 1, p_user_id);

        -- Inner Ring
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'chem_ring_' || substr(gen_random_uuid()::text, 1, 8), 'circle',
            jsonb_build_object('x', 215, 'y', 275, 'width', 70, 'height', 70, 'color', '#0F172A', 'strokeWidth', 2), 2, p_user_id);

        -- Substituent Bond
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'chem_bond_' || substr(gen_random_uuid()::text, 1, 8), 'line',
            jsonb_build_object('x1', 250, 'y1', 240, 'x2', 250, 'y2', 180, 'color', '#0F172A', 'strokeWidth', 3), 3, p_user_id);

        -- OH Functional Group Text
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'chem_oh_' || substr(gen_random_uuid()::text, 1, 8), 'text',
            jsonb_build_object('x', 230, 'y', 140, 'width', 80, 'height', 40, 'text', 'OH', 'fontSize', 20, 'bold', true, 'color', '#DC2626'), 4, p_user_id);

        -- Molecule Name Tag
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'chem_tag_' || substr(gen_random_uuid()::text, 1, 8), 'rectangle',
            jsonb_build_object('x', 175, 'y', 400, 'width', 150, 'height', 40, 'color', '#3B82F6', 'bgColor', '#EFF6FF', 'textColor', '#1D4ED8', 'text', 'Phenol (C₆H₅OH)', 'bold', true, 'rounded', true, 'strokeWidth', 1.5), 5, p_user_id);

        -- Reaction Arrow
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'chem_arr_' || substr(gen_random_uuid()::text, 1, 8), 'arrow',
            jsonb_build_object('x1', 380, 'y1', 300, 'x2', 520, 'y2', 300, 'color', '#0F172A', 'strokeWidth', 3, 'label', '+ 3 Br₂ (aq)'), 6, p_user_id);

        -- Reaction Product Card
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'chem_prod_' || substr(gen_random_uuid()::text, 1, 8), 'rectangle',
            jsonb_build_object('x', 550, 'y', 240, 'width', 200, 'height', 120, 'color', '#059669', 'bgColor', '#ECFDF5', 'textColor', '#065F46', 'text', '2,4,6-Tribromophenol' || E'\n' || '(White Precipitate ↓)' || E'\n' || '+ 3 HBr', 'bold', true, 'rounded', true, 'strokeWidth', 2), 7, p_user_id);

        -- Arrhenius Equation
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'chem_arrh_' || substr(gen_random_uuid()::text, 1, 8), 'equation',
            jsonb_build_object('x', 680, 'y', 90, 'width', 340, 'height', 75, 'latex', 'k = A \cdot e^{-\frac{E_a}{R T}}', 'display', 'k = A · e^(-Ea / RT)', 'color', '#1E3A8A', 'bgColor', '#EFF6FF', 'borderColor', '#3B82F6'), 8, p_user_id);

        -- Lab Sticky Note
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'chem_lab_' || substr(gen_random_uuid()::text, 1, 8), 'sticky_note',
            jsonb_build_object(
                'x', 780, 'y', 200, 'width', 300, 'height', 180,
                'text', '🧪 Laboratory Protocol:' || E'\n' || '• Bromine water decolourizes instantly' || E'\n' || '• White solid separates from solution' || E'\n' || '• Diagnostic test for active phenolic -OH' || E'\n' || '• Always wear safety goggles & nitrile gloves!',
                'bgColor', '#FEF3C7', 'color', '#0F172A', 'fontSize', 13
            ), 9, p_user_id);

    ELSIF v_norm_template IN ('biology', 'cell') THEN
        -- Cell Membrane Boundary
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'bio_cell_' || substr(gen_random_uuid()::text, 1, 8), 'ellipse',
            jsonb_build_object('x', 120, 'y', 150, 'width', 480, 'height', 380, 'color', '#059669', 'bgColor', '#ECFDF5', 'strokeWidth', 3.5), 1, p_user_id);

        -- Nucleus
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'bio_nuc_' || substr(gen_random_uuid()::text, 1, 8), 'circle',
            jsonb_build_object('x', 260, 'y', 270, 'width', 140, 'height', 140, 'color', '#D97706', 'bgColor', '#FEF3C7', 'strokeWidth', 3), 2, p_user_id);

        -- Nucleolus
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'bio_nucl_' || substr(gen_random_uuid()::text, 1, 8), 'circle',
            jsonb_build_object('x', 310, 'y', 320, 'width', 45, 'height', 45, 'color', '#B45309', 'bgColor', '#F59E0B', 'strokeWidth', 2), 3, p_user_id);

        -- Mitochondria 1 & 2
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'bio_mito1_' || substr(gen_random_uuid()::text, 1, 8), 'ellipse',
            jsonb_build_object('x', 180, 'y', 230, 'width', 70, 'height', 38, 'color', '#DC2626', 'bgColor', '#FEE2E2', 'strokeWidth', 2), 4, p_user_id);

        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'bio_mito2_' || substr(gen_random_uuid()::text, 1, 8), 'ellipse',
            jsonb_build_object('x', 440, 'y', 390, 'width', 70, 'height', 38, 'color', '#DC2626', 'bgColor', '#FEE2E2', 'strokeWidth', 2), 5, p_user_id);

        -- Pointer Arrows
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'bio_pnuc_' || substr(gen_random_uuid()::text, 1, 8), 'arrow',
            jsonb_build_object('x1', 680, 'y1', 290, 'x2', 400, 'y2', 320, 'color', '#D97706', 'strokeWidth', 2.5, 'label', 'Nucleus (DNA)'), 6, p_user_id);

        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'bio_pmit_' || substr(gen_random_uuid()::text, 1, 8), 'arrow',
            jsonb_build_object('x1', 680, 'y1', 390, 'x2', 510, 'y2', 405, 'color', '#DC2626', 'strokeWidth', 2.5, 'label', 'Mitochondria (ATP)'), 7, p_user_id);

        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'bio_pmem_' || substr(gen_random_uuid()::text, 1, 8), 'arrow',
            jsonb_build_object('x1', 680, 'y1', 190, 'x2', 560, 'y2', 210, 'color', '#059669', 'strokeWidth', 2.5, 'label', 'Plasma Membrane'), 8, p_user_id);

        -- Biology Sticky Note
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'bio_nt_' || substr(gen_random_uuid()::text, 1, 8), 'sticky_note',
            jsonb_build_object(
                'x', 680, 'y', 440, 'width', 340, 'height', 170,
                'text', '🧬 Cell Structure Key Points:' || E'\n' || '• Nucleus: Double membrane, chromatin' || E'\n' || '• Mitochondria: Cristae, oxidative phosphorylation' || E'\n' || '• Phospholipid Bilayer: Selective transport' || E'\n' || '• Ribosomes: Translation & peptide synthesis',
                'bgColor', '#FEF3C7', 'color', '#0F172A', 'fontSize', 13
            ), 9, p_user_id);

    ELSIF v_norm_template IN ('geography', 'maps') THEN
        -- Map Outer Border
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'geo_bd_' || substr(gen_random_uuid()::text, 1, 8), 'rectangle',
            jsonb_build_object('x', 120, 'y', 100, 'width', 800, 'height', 500, 'color', '#334155', 'strokeWidth', 3.5, 'rounded', false), 1, p_user_id);

        -- Equator Line
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'geo_eq_' || substr(gen_random_uuid()::text, 1, 8), 'line',
            jsonb_build_object('x1', 120, 'y1', 350, 'x2', 920, 'y2', 350, 'color', '#DC2626', 'strokeWidth', 2, 'label', 'Equator (0° Latitude)'), 2, p_user_id);

        -- Prime Meridian Line
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'geo_pm_' || substr(gen_random_uuid()::text, 1, 8), 'line',
            jsonb_build_object('x1', 520, 'y1', 100, 'x2', 520, 'y2', 600, 'color', '#2563EB', 'strokeWidth', 2, 'label', 'Prime Meridian (0° Longitude)'), 3, p_user_id);

        -- Compass Star & North Arrow
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'geo_star_' || substr(gen_random_uuid()::text, 1, 8), 'star',
            jsonb_build_object('x', 840, 'y', 130, 'width', 50, 'height', 50, 'color', '#0F172A', 'bgColor', '#0F172A'), 4, p_user_id);

        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'geo_narr_' || substr(gen_random_uuid()::text, 1, 8), 'arrow',
            jsonb_build_object('x1', 865, 'y1', 200, 'x2', 865, 'y2', 120, 'color', '#DC2626', 'strokeWidth', 3, 'label', 'NORTH'), 5, p_user_id);

        -- Map Legend Box
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'geo_leg_' || substr(gen_random_uuid()::text, 1, 8), 'sticky_note',
            jsonb_build_object(
                'x', 140, 'y', 440, 'width', 220, 'height', 140,
                'text', '🗺️ Map Legend:' || E'\n' || '• Scale: 1 cm = 250 km' || E'\n' || '★ Capital City' || E'\n' || '▲ Mountain Peak' || E'\n' || '── River & Coastal Contour',
                'bgColor', '#FEF3C7', 'fontSize', 12
            ), 6, p_user_id);

    ELSIF v_norm_template = 'engineering' THEN
        -- Outer Drawing Border
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'eng_out_' || substr(gen_random_uuid()::text, 1, 8), 'rectangle',
            jsonb_build_object('x', 80, 'y', 60, 'width', 960, 'height', 600, 'color', '#1E3A8A', 'strokeWidth', 3, 'rounded', false), 1, p_user_id);

        -- Inner Drawing Border
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'eng_in_' || substr(gen_random_uuid()::text, 1, 8), 'rectangle',
            jsonb_build_object('x', 92, 'y', 72, 'width', 936, 'height', 576, 'color', '#3B82F6', 'strokeWidth', 1.5, 'rounded', false), 2, p_user_id);

        -- Title Block (Bottom-Right)
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'eng_tblk_' || substr(gen_random_uuid()::text, 1, 8), 'rectangle',
            jsonb_build_object('x', 650, 'y', 510, 'width', 375, 'height', 135, 'color', '#1E3A8A', 'bgColor', '#EFF6FF', 'textColor', '#1E3A8A', 'text', 'PROJECT: CAD-ENG TECHNICAL DRAWING' || E'\n' || 'SCALE: 1:25 | REV: A.02 | SHEET: 1 OF 1' || E'\n' || 'APPROVED: SENIOR DESIGN ENGINEER' || E'\n' || 'DATE: 20-NOV-2026 | EDUSHAMIIT CAD', 'bold', true, 'rounded', false, 'strokeWidth', 2), 3, p_user_id);

        -- Front Elevation Component
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'eng_fe_' || substr(gen_random_uuid()::text, 1, 8), 'rectangle',
            jsonb_build_object('x', 160, 'y', 160, 'width', 200, 'height', 130, 'color', '#2563EB', 'bgColor', '#DBEAFE', 'textColor', '#1E3A8A', 'text', 'FRONT ELEVATION' || E'\n' || '[View A-A]', 'bold', true, 'rounded', false, 'strokeWidth', 2), 4, p_user_id);

        -- Plan View Component
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'eng_pv_' || substr(gen_random_uuid()::text, 1, 8), 'rectangle',
            jsonb_build_object('x', 160, 'y', 340, 'width', 200, 'height', 130, 'color', '#2563EB', 'bgColor', '#DBEAFE', 'textColor', '#1E3A8A', 'text', 'PLAN VIEW' || E'\n' || '[Top Projection]', 'bold', true, 'rounded', false, 'strokeWidth', 2), 5, p_user_id);

        -- Dimension Measurement X
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'eng_dimx_' || substr(gen_random_uuid()::text, 1, 8), 'measurement',
            jsonb_build_object('x1', 160, 'y1', 135, 'x2', 360, 'y2', 135, 'color', '#1E3A8A', 'strokeWidth', 1.5), 6, p_user_id);

        -- Dimension Measurement Y
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'eng_dimy_' || substr(gen_random_uuid()::text, 1, 8), 'measurement',
            jsonb_build_object('x1', 135, 'y1', 160, 'x2', 135, 'y2', 290, 'color', '#1E3A8A', 'strokeWidth', 1.5), 7, p_user_id);

    ELSIF v_norm_template IN ('graph', 'graph_paper') THEN
        -- Primary X Axis
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'grp_x_' || substr(gen_random_uuid()::text, 1, 8), 'arrow',
            jsonb_build_object('x1', 100, 'y1', 380, 'x2', 880, 'y2', 380, 'color', '#0F172A', 'strokeWidth', 3, 'label', 'X (Independent Variable)'), 1, p_user_id);

        -- Primary Y Axis
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'grp_y_' || substr(gen_random_uuid()::text, 1, 8), 'arrow',
            jsonb_build_object('x1', 490, 'y1', 650, 'x2', 490, 'y2', 90, 'color', '#0F172A', 'strokeWidth', 3, 'label', 'Y (Dependent Variable)'), 2, p_user_id);

        -- Linear Regression Line
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'grp_reg_' || substr(gen_random_uuid()::text, 1, 8), 'line',
            jsonb_build_object('x1', 180, 'y1', 540, 'x2', 800, 'y2', 180, 'color', '#2563EB', 'strokeWidth', 3.5, 'label', 'y = 0.58x + 12'), 3, p_user_id);

        -- Points
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'grp_p1_' || substr(gen_random_uuid()::text, 1, 8), 'circle',
            jsonb_build_object('x', 280, 'y', 480, 'width', 10, 'height', 10, 'color', '#DC2626', 'bgColor', '#DC2626', 'strokeWidth', 1), 4, p_user_id);

        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'grp_p2_' || substr(gen_random_uuid()::text, 1, 8), 'circle',
            jsonb_build_object('x', 490, 'y', 360, 'width', 10, 'height', 10, 'color', '#DC2626', 'bgColor', '#DC2626', 'strokeWidth', 1), 5, p_user_id);

        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'grp_p3_' || substr(gen_random_uuid()::text, 1, 8), 'circle',
            jsonb_build_object('x', 700, 'y', 240, 'width', 10, 'height', 10, 'color', '#DC2626', 'bgColor', '#DC2626', 'strokeWidth', 1), 6, p_user_id);

        -- Equation Card
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'grp_eq_' || substr(gen_random_uuid()::text, 1, 8), 'equation',
            jsonb_build_object('x', 620, 'y', 110, 'width', 320, 'height', 75, 'latex', 'y = m \cdot x + c', 'display', 'y = m·x + c', 'color', '#1E3A8A', 'bgColor', '#EFF6FF', 'borderColor', '#3B82F6'), 7, p_user_id);

        -- Plot Info Sticky Note
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'grp_nt_' || substr(gen_random_uuid()::text, 1, 8), 'sticky_note',
            jsonb_build_object(
                'x', 140, 'y', 120, 'width', 260, 'height', 130,
                'text', '📈 Plot Details:' || E'\n' || '• Slope (m) = Δy / Δx = 0.58' || E'\n' || '• Y-Intercept (c) = (0, 12)' || E'\n' || '• Correlation: R² = 0.98',
                'bgColor', '#FEF3C7', 'fontSize', 13
            ), 8, p_user_id);

    ELSIF v_norm_template IN ('general_teaching', 'ruled', 'lecture', 'notebook') THEN
        -- Lecture Header
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'lec_hdr_' || substr(gen_random_uuid()::text, 1, 8), 'text',
            jsonb_build_object('x', 100, 'y', 55, 'width', 620, 'height', 45, 'text', 'Class 12 - Chemistry | Chapter 5: Chemical Kinetics', 'fontSize', 18, 'bold', true, 'color', '#0F172A'), 1, p_user_id);

        -- Date & Period Pill
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'lec_pill_' || substr(gen_random_uuid()::text, 1, 8), 'rectangle',
            jsonb_build_object('x', 740, 'y', 50, 'width', 260, 'height', 35, 'color', '#2563EB', 'bgColor', '#EFF6FF', 'textColor', '#1D4ED8', 'text', 'DATE: 20-NOV-2026 | PERIOD: 2', 'bold', true, 'rounded', true, 'strokeWidth', 1.5), 2, p_user_id);

        -- Lecture Objectives Sticky Note
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'lec_obj_' || substr(gen_random_uuid()::text, 1, 8), 'sticky_note',
            jsonb_build_object(
                'x', 100, 'y', 120, 'width', 440, 'height', 200,
                'text', '📝 Today''s Key Learning Objectives:' || E'\n' || '1. Rate law expressions & order of reaction' || E'\n' || '2. Differential vs integrated rate equations' || E'\n' || '3. Half-life calculations for 1st order reactions' || E'\n' || '4. Temperature dependence: Arrhenius Equation',
                'bgColor', '#FEF3C7', 'color', '#0F172A', 'fontSize', 14
            ), 3, p_user_id);

        -- Rate Law Equation
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'lec_eq1_' || substr(gen_random_uuid()::text, 1, 8), 'equation',
            jsonb_build_object('x', 570, 'y', 120, 'width', 380, 'height', 80, 'latex', '-\frac{d[R]}{dt} = k \cdot [A]^x [B]^y', 'display', '-d[R]/dt = k·[A]^x [B]^y', 'color', '#1E3A8A', 'bgColor', '#EFF6FF', 'borderColor', '#3B82F6'), 4, p_user_id);

        -- Half Life Equation
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'lec_eq2_' || substr(gen_random_uuid()::text, 1, 8), 'equation',
            jsonb_build_object('x', 570, 'y', 220, 'width', 380, 'height', 80, 'latex', 't_{1/2} = \frac{\ln(2)}{k} = \frac{0.693}{k}', 'display', 't½ = ln(2)/k = 0.693 / k', 'color', '#065F46', 'bgColor', '#F0FDF4', 'borderColor', '#10B981'), 5, p_user_id);

        -- Student Interactive Workspace
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'lec_sz_' || substr(gen_random_uuid()::text, 1, 8), 'student_zone',
            jsonb_build_object('x', 100, 'y', 350, 'width', 850, 'height', 260, 'label', 'Student Working Space: Solve Example 5.1 (Integrated Rate Law)', 'color', '#2563EB', 'bgColor', '#F8FAFC'), 6, p_user_id);

    ELSE
        -- Blank Canvas: Welcome Instructional Sticky Note
        INSERT INTO public.whiteboard_objects (whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, created_by)
        VALUES (v_wb_id, v_page_id, p_school_id, 'blank_tip_' || substr(gen_random_uuid()::text, 1, 8), 'sticky_note',
            jsonb_build_object(
                'x', 100, 'y', 100, 'width', 300, 'height', 140,
                'text', '✏️ Interactive Whiteboard Canvas' || E'\n\n' || '• Use pen, shapes, sticky notes & formulas' || E'\n' || '• Click ''+ New Board'' anytime for templates!' || E'\n' || '• Student collaboration is live and synchronized.',
                'bgColor', '#FEF3C7', 'color', '#0F172A', 'fontSize', 13
            ), 1, p_user_id);
    END IF;

    -- Collect all created objects for page 1 snapshot
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', wo.object_id,
            'db_id', wo.id,
            'page_id', wo.page_id,
            'type', wo.object_type,
            'data', wo.object_data,
            'z_index', wo.z_index,
            'is_locked', wo.is_locked,
            'created_by', wo.created_by,
            'updated_at', wo.updated_at
        ) ORDER BY wo.z_index ASC, wo.created_at ASC
    ), '[]'::jsonb) INTO v_page_objects
    FROM public.whiteboard_objects wo
    WHERE wo.page_id = v_page_id AND wo.deleted_at IS NULL;

    -- Save Initial Snapshot with Real Objects
    INSERT INTO public.whiteboard_snapshots (
        id, whiteboard_id, school_id, revision, snapshot_data, created_by
    ) VALUES (
        v_snap_id, v_wb_id, p_school_id, 1,
        jsonb_build_object(
            'pages', jsonb_build_array(
                jsonb_build_object(
                    'id', v_page_id,
                    'title', v_page_title,
                    'page_order', 1,
                    'background_type', v_bg_type,
                    'objects', v_page_objects
                )
            )
        ),
        p_user_id
    );

    -- Create Version Checkpoint
    INSERT INTO public.whiteboard_versions (
        whiteboard_id, school_id, revision, version_name, is_checkpoint, snapshot_id, created_by, created_by_name
    ) VALUES (
        v_wb_id, p_school_id, 1, 'Initial ' || v_page_title, TRUE, v_snap_id, p_user_id, COALESCE(v_user_name, 'Teacher')
    );

    -- Log Whiteboard Created Audit
    PERFORM public.sp_log_whiteboard_audit(v_wb_id, p_school_id, p_user_id, 'whiteboard.created', jsonb_build_object('title', p_title, 'template', p_template_type, 'objects_count', jsonb_array_length(v_page_objects)));

    -- Return Full Whiteboard Document (with all pages & objects populated)
    RETURN public.sp_get_whiteboard_full(v_wb_id, p_school_id, p_user_id);
END;
$$;
