-- ============================================================================
-- Migration 511: Deduplicate Lookup Values and Harden Lookup Stored Procedure
-- Purpose:
--   1. Clean up duplicate active lookup values in public.lookup_values for all schools
--      (e.g., duplicate '2026 - 2027' entries in ACADEMIC_YEAR, duplicate salary modes, etc.)
--   2. Update public.fn_get_lookup_by_code to return DISTINCT value_name entries
--      preventing duplicate DropdownMenuItems from ever breaking Flutter UI screens.
-- ============================================================================

-- 1. Soft-delete duplicate lookup_values preserving the earliest record for each
--    (lookup_key_id, school_id, UPPER(TRIM(value_name)))
WITH ranked_lookups AS (
    SELECT 
        id,
        ROW_NUMBER() OVER (
            PARTITION BY lookup_key_id, school_id, UPPER(TRIM(value_name))
            ORDER BY sort_order ASC, created_at ASC, id ASC
        ) as rn
    FROM public.lookup_values
    WHERE deleted_at IS NULL
)
UPDATE public.lookup_values
SET 
    deleted_at = NOW(),
    updated_at = NOW()
WHERE id IN (
    SELECT id FROM ranked_lookups WHERE rn > 1
);

-- 2. Update public.fn_get_lookup_by_code to guarantee distinct lookup value names
CREATE OR REPLACE FUNCTION public.fn_get_lookup_by_code(
    p_school_id UUID,
    p_key_code VARCHAR,
    p_include_inactive BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_key RECORD;
    v_values JSONB;
BEGIN
    SELECT id, key_name, key_code, status, icon INTO v_key
    FROM public.lookup_keys
    WHERE school_id = p_school_id 
      AND UPPER(key_code) = UPPER(TRIM(p_key_code))
      AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Lookup code "' || p_key_code || '" not found');
    END IF;

    -- Aggregate distinct active lookup values sorted by sort_order
    WITH distinct_vals AS (
        SELECT DISTINCT ON (UPPER(TRIM(v.value_name)))
            v.id,
            v.value_code,
            v.value_name,
            v.description,
            v.status,
            v.sort_order,
            v.created_at
        FROM public.lookup_values v
        WHERE v.lookup_key_id = v_key.id
          AND v.deleted_at IS NULL
          AND (p_include_inactive OR v.status = 'ACTIVE')
        ORDER BY UPPER(TRIM(v.value_name)), v.sort_order ASC, v.created_at ASC
    )
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', d.id,
                'code', d.value_code,
                'label', d.value_name,
                'description', d.description,
                'status', d.status,
                'sort_order', d.sort_order
            ) ORDER BY d.sort_order ASC, d.created_at ASC
        ),
        '[]'::JSONB
    ) INTO v_values
    FROM distinct_vals d;

    RETURN jsonb_build_object(
        'success', TRUE,
        'key', v_key.key_code,
        'key_name', v_key.key_name,
        'status', v_key.status,
        'values', v_values
    );
END;
$$;
