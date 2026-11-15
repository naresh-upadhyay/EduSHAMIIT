-- 510_comprehensive_messaging_and_group_management_enhancements.sql
-- Optimizations and schema enhancements for messaging, group management, and user identity resolution.

DO $$
BEGIN
    -- 1. Ensure columns exist on groups
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'groups' AND column_name = 'avatar_url'
    ) THEN
        ALTER TABLE public.groups ADD COLUMN avatar_url TEXT;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'groups' AND column_name = 'description'
    ) THEN
        ALTER TABLE public.groups ADD COLUMN description TEXT;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'groups' AND column_name = 'is_private'
    ) THEN
        ALTER TABLE public.groups ADD COLUMN is_private BOOLEAN DEFAULT false;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'groups' AND column_name = 'group_level'
    ) THEN
        ALTER TABLE public.groups ADD COLUMN group_level TEXT DEFAULT 'school';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'groups' AND column_name = 'class_name'
    ) THEN
        ALTER TABLE public.groups ADD COLUMN class_name TEXT;
    END IF;
END $$;

-- 2. Indexes for group_members performance
CREATE INDEX IF NOT EXISTS idx_group_members_group_member_lookup 
ON public.group_members(group_id, member_id);

CREATE INDEX IF NOT EXISTS idx_group_members_group_role 
ON public.group_members(group_id, role);

CREATE INDEX IF NOT EXISTS idx_group_members_member_school 
ON public.group_members(member_id, school_id);

-- 3. Indexes for messages table performance
CREATE INDEX IF NOT EXISTS idx_messages_group_timeline 
ON public.messages(group_id, created_at DESC) 
WHERE group_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_messages_direct_timeline 
ON public.messages(school_id, sender_id, receiver_id, created_at DESC) 
WHERE group_id IS NULL;

-- 4. Helper function to resolve profile UUID by string user_id or email
CREATE OR REPLACE FUNCTION public.resolve_profile_uuid(p_identifier TEXT)
RETURNS UUID
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_profile_id UUID;
BEGIN
    IF p_identifier IS NULL OR TRIM(p_identifier) = '' THEN
        RETURN NULL;
    END IF;

    -- Try as direct UUID
    BEGIN
        v_profile_id := p_identifier::UUID;
        IF EXISTS (SELECT 1 FROM public.profiles WHERE id = v_profile_id) THEN
            RETURN v_profile_id;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        v_profile_id := NULL;
    END;

    -- Try as user_id string
    SELECT id INTO v_profile_id 
    FROM public.profiles 
    WHERE user_id = p_identifier 
    LIMIT 1;

    IF v_profile_id IS NOT NULL THEN
        RETURN v_profile_id;
    END IF;

    -- Try as email
    SELECT id INTO v_profile_id 
    FROM public.profiles 
    WHERE LOWER(email) = LOWER(p_identifier) 
    LIMIT 1;

    RETURN v_profile_id;
END;
$$;

-- 5. Clean up any invalid or orphaned rows in group_members where group or member does not exist
DELETE FROM public.group_members 
WHERE group_id NOT IN (SELECT id FROM public.groups)
   OR member_id NOT IN (SELECT id FROM public.profiles);
