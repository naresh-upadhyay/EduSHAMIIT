-- ============================================================================
-- Migration 478: Work Item Linking by Item Number or UUID
-- Fixes linking failure when user provides an item number (e.g. WM-1048)
-- instead of a UUID, adds bidirectional dependency & hierarchy support.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.sp_link_work_item_by_ref(
    p_school_id uuid,
    p_source_id uuid,
    p_target_ref text,
    p_link_type character varying DEFAULT 'RELATED'::character varying,
    p_actor_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_source RECORD;
    v_target RECORD;
    v_clean_ref text;
    v_link_type varchar;
    v_actor_name varchar := 'System';
BEGIN
    v_clean_ref := BTRIM(COALESCE(p_target_ref, ''));
    v_link_type := UPPER(BTRIM(COALESCE(p_link_type, 'RELATED')));

    IF v_clean_ref = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Target work item ID or number is required');
    END IF;

    SELECT id, item_number, title, parent_id
    INTO v_source
    FROM public.work_items
    WHERE id = p_source_id AND school_id = p_school_id AND is_archived = FALSE;

    IF v_source.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Source work item not found');
    END IF;

    -- Resolve target either by UUID or by item_number (e.g. WM-1048)
    SELECT id, item_number, title, parent_id
    INTO v_target
    FROM public.work_items
    WHERE school_id = p_school_id
      AND is_archived = FALSE
      AND (
          id::text = v_clean_ref
          OR UPPER(item_number) = UPPER(v_clean_ref)
      )
    LIMIT 1;

    IF v_target.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Work item "' || v_clean_ref || '" not found');
    END IF;

    IF v_source.id = v_target.id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cannot link a work item to itself');
    END IF;

    IF p_actor_id IS NOT NULL THEN
        SELECT COALESCE(full_name, 'System') INTO v_actor_name FROM public.profiles WHERE id = p_actor_id;
    END IF;

    IF v_link_type = 'CHILD' THEN
        IF v_source.parent_id = v_target.id THEN
            RETURN jsonb_build_object('success', false, 'error', 'Circular hierarchy detected: target is already the parent');
        END IF;
        UPDATE public.work_items
        SET parent_id = v_source.id, updated_at = NOW(), updated_by = p_actor_id
        WHERE id = v_target.id;

    ELSIF v_link_type = 'PARENT' THEN
        IF v_target.parent_id = v_source.id THEN
            RETURN jsonb_build_object('success', false, 'error', 'Circular hierarchy detected: target is already a child');
        END IF;
        UPDATE public.work_items
        SET parent_id = v_target.id, updated_at = NOW(), updated_by = p_actor_id
        WHERE id = v_source.id;

    ELSIF v_link_type = 'BLOCKS' THEN
        INSERT INTO public.work_item_dependencies (id, work_item_id, depends_on_item_id, dependency_type)
        VALUES (uuid_generate_v4(), v_source.id, v_target.id, 'BLOCKS')
        ON CONFLICT (work_item_id, depends_on_item_id, dependency_type) DO NOTHING;

        INSERT INTO public.work_item_dependencies (id, work_item_id, depends_on_item_id, dependency_type)
        VALUES (uuid_generate_v4(), v_target.id, v_source.id, 'BLOCKED_BY')
        ON CONFLICT (work_item_id, depends_on_item_id, dependency_type) DO NOTHING;

    ELSIF v_link_type = 'BLOCKED_BY' THEN
        INSERT INTO public.work_item_dependencies (id, work_item_id, depends_on_item_id, dependency_type)
        VALUES (uuid_generate_v4(), v_source.id, v_target.id, 'BLOCKED_BY')
        ON CONFLICT (work_item_id, depends_on_item_id, dependency_type) DO NOTHING;

        INSERT INTO public.work_item_dependencies (id, work_item_id, depends_on_item_id, dependency_type)
        VALUES (uuid_generate_v4(), v_target.id, v_source.id, 'BLOCKS')
        ON CONFLICT (work_item_id, depends_on_item_id, dependency_type) DO NOTHING;

    ELSE
        -- Default: RELATED (bidirectional)
        v_link_type := 'RELATED';
        INSERT INTO public.work_item_dependencies (id, work_item_id, depends_on_item_id, dependency_type)
        VALUES (uuid_generate_v4(), v_source.id, v_target.id, 'RELATED')
        ON CONFLICT (work_item_id, depends_on_item_id, dependency_type) DO NOTHING;

        INSERT INTO public.work_item_dependencies (id, work_item_id, depends_on_item_id, dependency_type)
        VALUES (uuid_generate_v4(), v_target.id, v_source.id, 'RELATED')
        ON CONFLICT (work_item_id, depends_on_item_id, dependency_type) DO NOTHING;
    END IF;

    -- Log activity on source item
    INSERT INTO public.work_item_activity_logs (
        work_item_id, school_id, actor_id, action_type, field_name, new_value, message
    ) VALUES (
        v_source.id, p_school_id, p_actor_id, 'LINK_ADDED', 'links', v_target.item_number,
        v_actor_name || ' linked ' || v_target.item_number || ' (' || v_link_type || ')'
    );

    -- Log activity on target item
    INSERT INTO public.work_item_activity_logs (
        work_item_id, school_id, actor_id, action_type, field_name, new_value, message
    ) VALUES (
        v_target.id, p_school_id, p_actor_id, 'LINK_ADDED', 'links', v_source.item_number,
        v_actor_name || ' linked with ' || v_source.item_number || ' (' || v_link_type || ')'
    );

    RETURN jsonb_build_object(
        'success', true,
        'source_id', v_source.id,
        'source_number', v_source.item_number,
        'target_id', v_target.id,
        'target_number', v_target.item_number,
        'target_title', v_target.title,
        'link_type', v_link_type
    );
END;
$function$;
