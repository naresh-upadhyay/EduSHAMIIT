-- ============================================================================
-- Migration 482: Update Work Item Link Relationship (CHILD, PARENT, BLOCKS, BLOCKED_BY, RELATED)
-- Allows users to update relationship types between work items dynamically.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.sp_update_work_item_link(
    p_school_id uuid,
    p_source_id uuid,
    p_target_id uuid,
    p_new_link_type character varying,
    p_actor_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_source RECORD;
    v_target RECORD;
    v_new_link_type varchar;
    v_actor_name varchar := 'System';
BEGIN
    v_new_link_type := UPPER(BTRIM(COALESCE(p_new_link_type, 'RELATED')));

    SELECT id, item_number, title, parent_id
    INTO v_source
    FROM public.work_items
    WHERE id = p_source_id AND school_id = p_school_id AND is_archived = FALSE;

    IF v_source.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Source work item not found');
    END IF;

    SELECT id, item_number, title, parent_id
    INTO v_target
    FROM public.work_items
    WHERE id = p_target_id AND school_id = p_school_id AND is_archived = FALSE;

    IF v_target.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Target work item not found');
    END IF;

    IF v_source.id = v_target.id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cannot link a work item to itself');
    END IF;

    IF p_actor_id IS NOT NULL THEN
        SELECT COALESCE(full_name, 'System') INTO v_actor_name FROM public.profiles WHERE id = p_actor_id;
    END IF;

    -- Step 1: Clear old relationship between source and target
    -- A: If parent-child in work_items
    IF v_source.parent_id = v_target.id THEN
        UPDATE public.work_items SET parent_id = NULL, updated_at = NOW(), updated_by = p_actor_id WHERE id = v_source.id;
    END IF;
    IF v_target.parent_id = v_source.id THEN
        UPDATE public.work_items SET parent_id = NULL, updated_at = NOW(), updated_by = p_actor_id WHERE id = v_target.id;
    END IF;

    -- B: Remove existing dependency entries between the two
    DELETE FROM public.work_item_dependencies
    WHERE (work_item_id = v_source.id AND depends_on_item_id = v_target.id)
       OR (work_item_id = v_target.id AND depends_on_item_id = v_source.id);

    -- Step 2: Establish the new link type
    IF v_new_link_type = 'CHILD' THEN
        UPDATE public.work_items
        SET parent_id = v_source.id, updated_at = NOW(), updated_by = p_actor_id
        WHERE id = v_target.id;

    ELSIF v_new_link_type = 'PARENT' THEN
        UPDATE public.work_items
        SET parent_id = v_target.id, updated_at = NOW(), updated_by = p_actor_id
        WHERE id = v_source.id;

    ELSIF v_new_link_type = 'BLOCKS' THEN
        INSERT INTO public.work_item_dependencies (id, work_item_id, depends_on_item_id, dependency_type)
        VALUES (uuid_generate_v4(), v_source.id, v_target.id, 'BLOCKS')
        ON CONFLICT (work_item_id, depends_on_item_id, dependency_type) DO NOTHING;

        INSERT INTO public.work_item_dependencies (id, work_item_id, depends_on_item_id, dependency_type)
        VALUES (uuid_generate_v4(), v_target.id, v_source.id, 'BLOCKED_BY')
        ON CONFLICT (work_item_id, depends_on_item_id, dependency_type) DO NOTHING;

    ELSIF v_new_link_type = 'BLOCKED_BY' THEN
        INSERT INTO public.work_item_dependencies (id, work_item_id, depends_on_item_id, dependency_type)
        VALUES (uuid_generate_v4(), v_source.id, v_target.id, 'BLOCKED_BY')
        ON CONFLICT (work_item_id, depends_on_item_id, dependency_type) DO NOTHING;

        INSERT INTO public.work_item_dependencies (id, work_item_id, depends_on_item_id, dependency_type)
        VALUES (uuid_generate_v4(), v_target.id, v_source.id, 'BLOCKS')
        ON CONFLICT (work_item_id, depends_on_item_id, dependency_type) DO NOTHING;

    ELSE
        -- Default: RELATED (bidirectional)
        v_new_link_type := 'RELATED';
        INSERT INTO public.work_item_dependencies (id, work_item_id, depends_on_item_id, dependency_type)
        VALUES (uuid_generate_v4(), v_source.id, v_target.id, 'RELATED')
        ON CONFLICT (work_item_id, depends_on_item_id, dependency_type) DO NOTHING;

        INSERT INTO public.work_item_dependencies (id, work_item_id, depends_on_item_id, dependency_type)
        VALUES (uuid_generate_v4(), v_target.id, v_source.id, 'RELATED')
        ON CONFLICT (work_item_id, depends_on_item_id, dependency_type) DO NOTHING;
    END IF;

    -- Step 3: Log activity on source item
    INSERT INTO public.work_item_activity_logs (
        work_item_id, school_id, actor_id, action_type, field_name, new_value, message
    ) VALUES (
        v_source.id, p_school_id, p_actor_id, 'LINK_UPDATED', 'links', v_target.item_number,
        v_actor_name || ' updated relationship with ' || v_target.item_number || ' to ' || v_new_link_type
    );

    -- Step 4: Log activity on target item
    INSERT INTO public.work_item_activity_logs (
        work_item_id, school_id, actor_id, action_type, field_name, new_value, message
    ) VALUES (
        v_target.id, p_school_id, p_actor_id, 'LINK_UPDATED', 'links', v_source.item_number,
        v_actor_name || ' updated relationship with ' || v_source.item_number || ' to ' || v_new_link_type
    );

    RETURN jsonb_build_object(
        'success', true,
        'source_id', v_source.id,
        'source_number', v_source.item_number,
        'target_id', v_target.id,
        'target_number', v_target.item_number,
        'new_link_type', v_new_link_type
    );
END;
$function$;
