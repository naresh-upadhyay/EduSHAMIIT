-- Migration 376: Visitor Bulk Check-Out Stored Procedure
-- Allows atomic, loop-free bulk checkout of multiple visitors in a single database transaction.

CREATE OR REPLACE FUNCTION public.fn_visitors_bulk_check_out(
    p_school_id UUID,
    p_visit_ids UUID[],
    p_payload JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_id UUID;
    v_success_count INT := 0;
    v_failed_count INT := 0;
    v_already_checked_out INT := 0;
    v_res JSONB;
BEGIN
    IF p_visit_ids IS NULL OR array_length(p_visit_ids, 1) = 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'detail', 'No visit IDs provided for bulk check-out.'
        );
    END IF;

    FOREACH v_id IN ARRAY p_visit_ids
    LOOP
        v_res := public.fn_visitors_check_out(p_school_id, v_id, p_payload);
        IF (v_res->>'success')::BOOLEAN THEN
            v_success_count := v_success_count + 1;
        ELSE
            IF v_res->>'detail' ILIKE '%already checked out%' THEN
                v_already_checked_out := v_already_checked_out + 1;
            ELSE
                v_failed_count := v_failed_count + 1;
            END IF;
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'total', array_length(p_visit_ids, 1),
        'checked_out_count', v_success_count,
        'already_checked_out_count', v_already_checked_out,
        'failed_count', v_failed_count,
        'message', format('Successfully checked out %s visitor(s).', v_success_count)
    );
END;
$$;
