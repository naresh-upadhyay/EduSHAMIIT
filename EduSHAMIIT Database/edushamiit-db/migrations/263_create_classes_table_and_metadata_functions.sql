-- ============================================================================
-- Migration 263: Dynamic Classes & Roles Support for EduSHAMIIT ERP
-- ============================================================================

-- 1. Create public.classes table if not exists
CREATE TABLE IF NOT EXISTS public.classes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    name TEXT NOT NULL,          -- e.g. 'Class 10A', '10A', 'IX-A', 'Class 9B'
    grade_level TEXT,            -- e.g. '10', '9', '8'
    section TEXT,                -- e.g. 'A', 'B', 'C'
    stream TEXT,                 -- e.g. 'Science', 'Commerce', 'Arts', 'General'
    academic_year TEXT DEFAULT '2026-2027',
    room_number TEXT,
    capacity INT DEFAULT 40,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_classes_school_name UNIQUE (school_id, name)
);

CREATE INDEX IF NOT EXISTS idx_classes_school ON public.classes(school_id, is_active);

-- 2. Seed standard classes for all registered schools
INSERT INTO public.classes (school_id, name, grade_level, section, academic_year)
SELECT s.id, c.name, c.grade_level, c.section, '2026-2027'
FROM public.schools s
CROSS JOIN (
    VALUES 
        ('Pre-KG', 'Pre-KG', 'A'),
        ('LKG', 'LKG', 'A'),
        ('UKG', 'UKG', 'A'),
        ('Class 1A', '1', 'A'),
        ('Class 1B', '1', 'B'),
        ('Class 2A', '2', 'A'),
        ('Class 2B', '2', 'B'),
        ('Class 3A', '3', 'A'),
        ('Class 3B', '3', 'B'),
        ('Class 4A', '4', 'A'),
        ('Class 4B', '4', 'B'),
        ('Class 5A', '5', 'A'),
        ('Class 5B', '5', 'B'),
        ('Class 6A', '6', 'A'),
        ('Class 6B', '6', 'B'),
        ('Class 7A', '7', 'A'),
        ('Class 7B', '7', 'B'),
        ('Class 8A', '8', 'A'),
        ('Class 8B', '8', 'B'),
        ('Class 9A', '9', 'A'),
        ('Class 9B', '9', 'B'),
        ('Class 10A', '10', 'A'),
        ('Class 10B', '10', 'B'),
        ('Class 11A (Science)', '11', 'A'),
        ('Class 11B (Commerce)', '11', 'B'),
        ('Class 11C (Arts)', '11', 'C'),
        ('Class 12A (Science)', '12', 'A'),
        ('Class 12B (Commerce)', '12', 'B'),
        ('Class 12C (Arts)', '12', 'C')
) AS c(name, grade_level, section)
ON CONFLICT (school_id, name) DO NOTHING;

-- Also seed any existing classes found in profiles
INSERT INTO public.classes (school_id, name, academic_year)
SELECT DISTINCT p.school_id, p.class, '2026-2027'
FROM public.profiles p
WHERE p.school_id IS NOT NULL 
  AND p.class IS NOT NULL 
  AND TRIM(p.class) != ''
ON CONFLICT (school_id, name) DO NOTHING;

-- 3. Stored function: fn_get_notice_metadata
CREATE OR REPLACE FUNCTION public.fn_get_notice_metadata(p_school_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_roles JSONB;
    v_classes JSONB;
    v_categories JSONB;
BEGIN
    -- 1. Fetch active roles from app_roles + profiles
    SELECT COALESCE(jsonb_agg(sub.name), '[]'::jsonb)
    INTO v_roles
    FROM (
        SELECT DISTINCT name FROM public.app_roles WHERE status = 'Active' OR status IS NULL
        UNION
        SELECT DISTINCT role AS name FROM public.profiles WHERE (school_id = p_school_id OR school_id IS NULL) AND role IS NOT NULL AND role != ''
        ORDER BY name
    ) sub;

    -- 2. Fetch active classes from classes table + profiles
    SELECT COALESCE(jsonb_agg(sub.name), '[]'::jsonb)
    INTO v_classes
    FROM (
        SELECT DISTINCT name FROM public.classes WHERE (school_id = p_school_id OR school_id IS NULL) AND is_active = TRUE
        UNION
        SELECT DISTINCT class AS name FROM public.profiles WHERE (school_id = p_school_id OR school_id IS NULL) AND class IS NOT NULL AND class != ''
        ORDER BY name
    ) sub;

    -- 3. Fetch notice categories
    SELECT COALESCE(jsonb_agg(sub.item), '[]'::jsonb)
    INTO v_categories
    FROM (
        SELECT jsonb_build_object(
            'id', id,
            'name', name,
            'code', code,
            'description', description,
            'icon', icon,
            'color', color,
            'sort_order', sort_order,
            'is_active', is_active
        ) AS item
        FROM public.notice_categories
        WHERE (school_id = p_school_id OR school_id IS NULL) AND is_active = TRUE
        ORDER BY sort_order ASC, name ASC
    ) sub;

    RETURN jsonb_build_object(
        'success', TRUE,
        'roles', v_roles,
        'classes', v_classes,
        'categories', v_categories
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
