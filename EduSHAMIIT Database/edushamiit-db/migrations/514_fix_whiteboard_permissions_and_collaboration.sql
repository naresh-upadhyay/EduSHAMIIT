-- ============================================================================
-- Migration 514: Whiteboard Permissions Role Harmonization & Collaboration Fix
-- Author: EduSHAMIIT Enterprise Virtual Classroom Engine
-- Date: 2026-11-16
-- ============================================================================

-- 1. Upgrade sp_get_whiteboard_user_permission
CREATE OR REPLACE FUNCTION public.sp_get_whiteboard_user_permission(
    p_whiteboard_id UUID,
    p_school_id UUID,
    p_user_id UUID,
    p_user_role TEXT DEFAULT 'student'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_wb RECORD;
    v_perm RECORD;
    v_role_lower TEXT := LOWER(COALESCE(p_user_role, 'student'));
    v_effective TEXT := 'VIEW';
    v_assigned_area JSONB := NULL;
    v_is_staff BOOLEAN := FALSE;
BEGIN
    SELECT id, school_id, owner_user_id, created_by, teacher_only_mode, collaboration_enabled, presentation_mode, default_permissions
    INTO v_wb
    FROM public.live_class_whiteboards
    WHERE id = p_whiteboard_id AND school_id = p_school_id AND deleted_at IS NULL
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('allowed', FALSE, 'permission', 'NONE', 'reason', 'Whiteboard not found');
    END IF;

    -- Check if user is staff/teacher/admin/super_admin or board owner
    IF v_wb.owner_user_id = p_user_id OR v_wb.created_by = p_user_id
       OR v_role_lower IN (
           'super_admin', 'superadmin', 'admin', 'teacher_admin', 'academic_admin',
           'principal', 'director', 'headmaster', 'teacher', 'co_teacher', 'faculty',
           'host', 'co_host'
       ) THEN
        v_is_staff := TRUE;
    END IF;

    IF v_is_staff THEN
        RETURN jsonb_build_object(
            'allowed', TRUE,
            'permission', 'OWNER',
            'can_edit', TRUE,
            'can_manage_pages', TRUE,
            'can_manage_permissions', TRUE,
            'can_export', TRUE,
            'assigned_area', NULL
        );
    END IF;

    -- Check user-specific explicit override in whiteboard_permissions table
    SELECT permission_type, assigned_area INTO v_perm
    FROM public.whiteboard_permissions
    WHERE whiteboard_id = p_whiteboard_id AND user_id = p_user_id
    LIMIT 1;

    IF FOUND THEN
        v_effective := v_perm.permission_type;
        v_assigned_area := v_perm.assigned_area;
    ELSE
        -- Check role override in whiteboard_permissions table
        SELECT permission_type, assigned_area INTO v_perm
        FROM public.whiteboard_permissions
        WHERE whiteboard_id = p_whiteboard_id AND LOWER(COALESCE(role_ref, '')) = v_role_lower
        LIMIT 1;

        IF FOUND THEN
            v_effective := v_perm.permission_type;
            v_assigned_area := v_perm.assigned_area;
        ELSIF COALESCE(v_wb.collaboration_enabled, FALSE) = TRUE
              AND COALESCE(v_wb.presentation_mode, FALSE) = FALSE THEN
            -- Real-time student collaboration is enabled and presentation mode is off
            IF COALESCE(v_wb.teacher_only_mode, FALSE) = FALSE
               OR COALESCE((v_wb.default_permissions->>'students_can_draw')::BOOLEAN, TRUE) = TRUE THEN
                v_effective := 'EDIT';
            ELSIF COALESCE((v_wb.default_permissions->>'students_can_annotate')::BOOLEAN, FALSE) = TRUE THEN
                v_effective := 'ANNOTATE';
            ELSE
                v_effective := 'EDIT';
            END IF;
        ELSE
            v_effective := 'VIEW';
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'allowed', v_effective != 'NONE',
        'permission', v_effective,
        'can_edit', v_effective IN ('OWNER', 'EDIT', 'ANNOTATE'),
        'can_manage_pages', v_effective = 'OWNER',
        'can_manage_permissions', v_effective = 'OWNER',
        'can_export', v_effective IN ('OWNER', 'EDIT', 'ANNOTATE', 'VIEW'),
        'assigned_area', v_assigned_area
    );
END;
$$;

-- 2. Upgrade sp_update_whiteboard_meta
CREATE OR REPLACE FUNCTION public.sp_update_whiteboard_meta(
    p_whiteboard_id UUID,
    p_school_id UUID,
    p_user_id UUID,
    p_title TEXT DEFAULT NULL,
    p_collaboration_enabled BOOLEAN DEFAULT NULL,
    p_presentation_mode BOOLEAN DEFAULT NULL,
    p_teacher_only_mode BOOLEAN DEFAULT NULL,
    p_default_permissions JSONB DEFAULT NULL,
    p_status TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_eff_teacher_only BOOLEAN := p_teacher_only_mode;
    v_eff_perms JSONB := p_default_permissions;
BEGIN
    -- If collaboration is enabled, harmonize teacher_only_mode and student draw permissions
    IF p_collaboration_enabled = TRUE THEN
        v_eff_teacher_only := FALSE;
        IF v_eff_perms IS NULL THEN
            SELECT default_permissions INTO v_eff_perms FROM public.live_class_whiteboards WHERE id = p_whiteboard_id;
        END IF;
        v_eff_perms := jsonb_set(COALESCE(v_eff_perms, '{}'::JSONB), '{students_can_draw}', 'true'::JSONB);
        v_eff_perms := jsonb_set(v_eff_perms, '{students_can_annotate}', 'true'::JSONB);
    ELSIF p_presentation_mode = TRUE THEN
        v_eff_teacher_only := TRUE;
    END IF;

    UPDATE public.live_class_whiteboards
    SET title = COALESCE(NULLIF(TRIM(p_title), ''), title),
        collaboration_enabled = COALESCE(p_collaboration_enabled, collaboration_enabled),
        presentation_mode = COALESCE(p_presentation_mode, presentation_mode),
        teacher_only_mode = COALESCE(v_eff_teacher_only, teacher_only_mode),
        default_permissions = COALESCE(v_eff_perms, default_permissions),
        status = COALESCE(p_status, status),
        last_saved_by = p_user_id,
        updated_at = NOW()
    WHERE id = p_whiteboard_id AND school_id = p_school_id AND deleted_at IS NULL;

    PERFORM public.sp_log_whiteboard_audit(p_whiteboard_id, p_school_id, p_user_id, 'whiteboard.updated', jsonb_build_object(
        'title', p_title, 'collaboration_enabled', p_collaboration_enabled, 'presentation_mode', p_presentation_mode
    ));

    RETURN public.sp_get_whiteboard_full(p_whiteboard_id, p_school_id, p_user_id);
END;
$$;
