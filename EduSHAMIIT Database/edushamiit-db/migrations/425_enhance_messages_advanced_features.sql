-- ============================================================================
-- Migration 425: Enterprise Messaging Enhancements
-- 1. Adds message types, attachments metadata, reactions, replies, pins, editing
-- 2. Adds verification flag and ward link to profiles for parent-student messaging
-- 3. Creates indexes for high-throughput messaging & real-time chat
-- ============================================================================

-- 1. ENSURE APP ROLE FOR 'staff' EXISTS IF REFERENCED
INSERT INTO public.app_roles (id, name, code, display_name, permissions, is_custom)
VALUES (gen_random_uuid(), 'staff', 'STAFF', 'Staff Member', '{}', false)
ON CONFLICT (name) DO NOTHING;

-- 2. ENHANCE MESSAGES TABLE
ALTER TABLE public.messages
    ADD COLUMN IF NOT EXISTS message_type VARCHAR(32) DEFAULT 'text',
    ADD COLUMN IF NOT EXISTS file_name TEXT,
    ADD COLUMN IF NOT EXISTS file_size BIGINT,
    ADD COLUMN IF NOT EXISTS reply_to_id UUID REFERENCES public.messages(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS reactions JSONB DEFAULT '{}'::jsonb,
    ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS is_edited BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS edited_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS deleted_for UUID[] DEFAULT ARRAY[]::UUID[];

-- 3. ENHANCE PROFILES TABLE FOR PARENT-STUDENT & VERIFICATION SUPPORT
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS ward_student_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

-- 4. PERFORMANCE INDEXES
CREATE INDEX IF NOT EXISTS idx_messages_reply_to_id ON public.messages(reply_to_id);
CREATE INDEX IF NOT EXISTS idx_messages_pinned ON public.messages(school_id, is_pinned) WHERE is_pinned = TRUE;
CREATE INDEX IF NOT EXISTS idx_messages_group_created ON public.messages(group_id, created_at DESC) WHERE group_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_messages_direct_conversation ON public.messages(school_id, sender_id, receiver_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_ward_student ON public.profiles(ward_student_id) WHERE ward_student_id IS NOT NULL;

-- 5. REALTIME NOTIFICATION ENHANCEMENT
ALTER TABLE public.messages REPLICA IDENTITY FULL;

-- 6. SEED SAMPLE REAL-WORLD CONVERSATIONS (Anita Sharma, Class 10-A, etc.)
DO $$
DECLARE
    v_school_id UUID;
    v_admin_id UUID;
    v_anita_id UUID;
    v_aarav_id UUID;
    v_rohit_id UUID;
    v_pooja_id UUID;
    v_vikas_id UUID;
    v_megha_id UUID;
    v_class10a_group_id UUID;
    v_library_group_id UUID;
    v_transport_group_id UUID;
    v_science_group_id UUID;
    v_ac_group_id UUID;
BEGIN
    SELECT id INTO v_school_id FROM public.schools LIMIT 1;
    IF v_school_id IS NULL THEN
        RETURN;
    END IF;

    -- Look up Super Admin / Current User profile
    SELECT id INTO v_admin_id FROM public.profiles WHERE role IN ('super_admin', 'superadmin', 'admin') LIMIT 1;
    IF v_admin_id IS NULL THEN
        SELECT id INTO v_admin_id FROM public.profiles LIMIT 1;
    END IF;

    -- Ensure Aarav Sharma (Student) exists
    SELECT id INTO v_aarav_id FROM public.profiles WHERE full_name = 'Aarav Sharma' AND school_id = v_school_id LIMIT 1;
    IF v_aarav_id IS NULL THEN
        INSERT INTO public.profiles (
            id, school_id, user_id, full_name, role, class, email, phone, is_verified, is_online
        ) VALUES (
            gen_random_uuid(), v_school_id, 'u_aarav_sharma', 'Aarav Sharma', 'student', 'Class 10-A', 'aarav.sharma@edushamiit.com', '+91 98765 43211', TRUE, TRUE
        ) RETURNING id INTO v_aarav_id;
    ELSE
        UPDATE public.profiles SET class = 'Class 10-A', is_verified = TRUE WHERE id = v_aarav_id;
    END IF;

    -- Ensure Anita Sharma (Parent of Aarav Sharma) exists
    SELECT id INTO v_anita_id FROM public.profiles WHERE full_name = 'Anita Sharma' AND school_id = v_school_id LIMIT 1;
    IF v_anita_id IS NULL THEN
        INSERT INTO public.profiles (
            id, school_id, user_id, full_name, role, email, phone, avatar_url, is_verified, is_online, ward_student_id
        ) VALUES (
            gen_random_uuid(), v_school_id, 'u_anita_sharma', 'Anita Sharma', 'parent', 'anita.sharma@email.com', '+91 98765 43210', 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&q=80&w=256', TRUE, TRUE, v_aarav_id
        ) RETURNING id INTO v_anita_id;
    ELSE
        UPDATE public.profiles 
        SET role = 'parent', 
            phone = '+91 98765 43210', 
            email = 'anita.sharma@email.com', 
            is_verified = TRUE, 
            is_online = TRUE, 
            ward_student_id = v_aarav_id,
            avatar_url = COALESCE(avatar_url, 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&q=80&w=256')
        WHERE id = v_anita_id;
    END IF;

    -- Ensure other contacts from reference image exist (Rohit Malhotra, Pooja Rathi, Vikas Tiwari, Megha Kapoor)
    SELECT id INTO v_rohit_id FROM public.profiles WHERE full_name = 'Rohit Malhotra' AND school_id = v_school_id LIMIT 1;
    IF v_rohit_id IS NULL THEN
        INSERT INTO public.profiles (id, school_id, user_id, full_name, role, email, phone, avatar_url, is_verified)
        VALUES (gen_random_uuid(), v_school_id, 'u_rohit_m', 'Rohit Malhotra', 'student', 'rohit.m@email.com', '+91 98111 22334', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&q=80&w=256', FALSE)
        RETURNING id INTO v_rohit_id;
    END IF;

    SELECT id INTO v_pooja_id FROM public.profiles WHERE full_name = 'Pooja Rathi' AND school_id = v_school_id LIMIT 1;
    IF v_pooja_id IS NULL THEN
        INSERT INTO public.profiles (id, school_id, user_id, full_name, role, email, phone, avatar_url, is_verified)
        VALUES (gen_random_uuid(), v_school_id, 'u_pooja_r', 'Pooja Rathi', 'parent', 'pooja.r@email.com', '+91 98222 33445', 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=256', FALSE)
        RETURNING id INTO v_pooja_id;
    END IF;

    SELECT id INTO v_vikas_id FROM public.profiles WHERE full_name = 'Vikas Tiwari' AND school_id = v_school_id LIMIT 1;
    IF v_vikas_id IS NULL THEN
        INSERT INTO public.profiles (id, school_id, user_id, full_name, role, email, phone, avatar_url, is_verified)
        VALUES (gen_random_uuid(), v_school_id, 'u_vikas_t', 'Vikas Tiwari', 'staff', 'vikas.tiwari@edushamiit.com', '+91 98333 44556', 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&q=80&w=256', FALSE)
        RETURNING id INTO v_vikas_id;
    END IF;

    SELECT id INTO v_megha_id FROM public.profiles WHERE full_name = 'Megha Kapoor' AND school_id = v_school_id LIMIT 1;
    IF v_megha_id IS NULL THEN
        INSERT INTO public.profiles (id, school_id, user_id, full_name, role, email, phone, avatar_url, is_verified)
        VALUES (gen_random_uuid(), v_school_id, 'u_megha_k', 'Megha Kapoor', 'student', 'megha.k@email.com', '+91 98444 55667', 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&q=80&w=256', FALSE)
        RETURNING id INTO v_megha_id;
    END IF;

    -- Groups (Class 10-A Group, Library Team, Transport Team, Science Lab Group, AC Team)
    SELECT id INTO v_class10a_group_id FROM public.groups WHERE name = 'Class 10-A Group' AND school_id = v_school_id LIMIT 1;
    IF v_class10a_group_id IS NULL THEN
        INSERT INTO public.groups (id, school_id, name, description, created_by, is_active)
        VALUES (gen_random_uuid(), v_school_id, 'Class 10-A Group', 'Official communication channel for Class 10-A students, teachers, and parents.', v_admin_id, TRUE)
        RETURNING id INTO v_class10a_group_id;
    END IF;

    SELECT id INTO v_library_group_id FROM public.groups WHERE name = 'Library Team' AND school_id = v_school_id LIMIT 1;
    IF v_library_group_id IS NULL THEN
        INSERT INTO public.groups (id, school_id, name, description, created_by, is_active)
        VALUES (gen_random_uuid(), v_school_id, 'Library Team', 'Updates and coordination from the central campus library.', v_admin_id, TRUE)
        RETURNING id INTO v_library_group_id;
    END IF;

    SELECT id INTO v_transport_group_id FROM public.groups WHERE name = 'Transport Team' AND school_id = v_school_id LIMIT 1;
    IF v_transport_group_id IS NULL THEN
        INSERT INTO public.groups (id, school_id, name, description, created_by, is_active)
        VALUES (gen_random_uuid(), v_school_id, 'Transport Team', 'Live fleet transit notices and bus route updates.', v_admin_id, TRUE)
        RETURNING id INTO v_transport_group_id;
    END IF;

    SELECT id INTO v_science_group_id FROM public.groups WHERE name = 'Science Lab Group' AND school_id = v_school_id LIMIT 1;
    IF v_science_group_id IS NULL THEN
        INSERT INTO public.groups (id, school_id, name, description, created_by, is_active)
        VALUES (gen_random_uuid(), v_school_id, 'Science Lab Group', 'Physics, Chemistry and Biology laboratory schedules and experiments.', v_admin_id, TRUE)
        RETURNING id INTO v_science_group_id;
    END IF;

    SELECT id INTO v_ac_group_id FROM public.groups WHERE name = 'AC Team' AND school_id = v_school_id LIMIT 1;
    IF v_ac_group_id IS NULL THEN
        INSERT INTO public.groups (id, school_id, name, description, created_by, is_active)
        VALUES (gen_random_uuid(), v_school_id, 'AC Team', 'Academic Committee coordination and syllabus review.', v_admin_id, TRUE)
        RETURNING id INTO v_ac_group_id;
    END IF;

    -- Add current admin user to these groups so they appear in their conversations
    IF v_admin_id IS NOT NULL THEN
        INSERT INTO public.group_members (group_id, member_id, role)
        VALUES 
            (v_class10a_group_id, v_admin_id, 'admin'),
            (v_library_group_id, v_admin_id, 'admin'),
            (v_transport_group_id, v_admin_id, 'admin'),
            (v_science_group_id, v_admin_id, 'admin'),
            (v_ac_group_id, v_admin_id, 'admin')
        ON CONFLICT (group_id, member_id) DO NOTHING;
    END IF;

    -- Add seed messages for Anita Sharma conversation matching the screenshot
    IF v_admin_id IS NOT NULL AND v_anita_id IS NOT NULL THEN
        DELETE FROM public.messages 
        WHERE school_id = v_school_id 
          AND ((sender_id = v_admin_id AND receiver_id = v_anita_id) OR (sender_id = v_anita_id AND receiver_id = v_admin_id));

        -- 1. Anita Sharma: "Good Morning Sir, Please share the attendance record of my ward for this month."
        INSERT INTO public.messages (
            school_id, sender_id, receiver_id, content, is_read, created_at, message_type
        ) VALUES (
            v_school_id, v_anita_id, v_admin_id, 
            'Good Morning Sir, Please share the attendance record of my ward for this month.', 
            TRUE, NOW() - INTERVAL '68 minutes', 'text'
        );

        -- 2. Admin: "Good Morning, Here is the attendance report." + PDF attachment
        INSERT INTO public.messages (
            school_id, sender_id, receiver_id, content, attachment_url, file_name, file_size, is_read, created_at, message_type
        ) VALUES (
            v_school_id, v_admin_id, v_anita_id, 
            'Good Morning, Here is the attendance report.', 
            'https://raw.githubusercontent.com/mozilla/pdf.js/ba2edeae/examples/learning/helloworld.pdf',
            'Attendance_Report_Oct2025.pdf', 250880,
            TRUE, NOW() - INTERVAL '52 minutes', 'file'
        );

        -- 3. Anita Sharma: "Thank you for the information."
        INSERT INTO public.messages (
            school_id, sender_id, receiver_id, content, is_read, created_at, message_type
        ) VALUES (
            v_school_id, v_anita_id, v_admin_id, 
            'Thank you for the information.', 
            FALSE, NOW() - INTERVAL '2 minutes', 'text'
        );

        -- 4. Admin: "You are welcome!"
        INSERT INTO public.messages (
            school_id, sender_id, receiver_id, content, is_read, created_at, message_type
        ) VALUES (
            v_school_id, v_admin_id, v_anita_id, 
            'You are welcome!', 
            TRUE, NOW() - INTERVAL '1 minute', 'text'
        );
    END IF;

    -- Add seed messages for groups and other contacts matching screenshot
    IF v_admin_id IS NOT NULL THEN
        -- Class 10-A Group
        IF NOT EXISTS (SELECT 1 FROM public.messages WHERE group_id = v_class10a_group_id) THEN
            INSERT INTO public.messages (school_id, sender_id, group_id, content, is_read, created_at)
            VALUES (v_school_id, v_admin_id, v_class10a_group_id, 'Reminder: Unit Test on Friday...', FALSE, NOW() - INTERVAL '34 minutes');
        END IF;

        -- Rohit Malhotra
        IF v_rohit_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.messages WHERE (sender_id = v_rohit_id AND receiver_id = v_admin_id) OR (sender_id = v_admin_id AND receiver_id = v_rohit_id)) THEN
            INSERT INTO public.messages (school_id, sender_id, receiver_id, content, is_read, created_at)
            VALUES (v_school_id, v_rohit_id, v_admin_id, 'Fees receipt is attached.', TRUE, NOW() - INTERVAL '1 day');
        END IF;

        -- Library Team
        IF NOT EXISTS (SELECT 1 FROM public.messages WHERE group_id = v_library_group_id) THEN
            INSERT INTO public.messages (school_id, sender_id, group_id, content, is_read, created_at)
            VALUES (v_school_id, v_admin_id, v_library_group_id, 'New books are available in library.', TRUE, NOW() - INTERVAL '1 day');
        END IF;

        -- Pooja Rathi
        IF v_pooja_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.messages WHERE (sender_id = v_pooja_id AND receiver_id = v_admin_id) OR (sender_id = v_admin_id AND receiver_id = v_pooja_id)) THEN
            INSERT INTO public.messages (school_id, sender_id, receiver_id, content, is_read, created_at)
            VALUES (v_school_id, v_pooja_id, v_admin_id, 'Okay, will do it.', TRUE, NOW() - INTERVAL '2 days');
        END IF;

        -- Transport Team
        IF NOT EXISTS (SELECT 1 FROM public.messages WHERE group_id = v_transport_group_id) THEN
            INSERT INTO public.messages (school_id, sender_id, group_id, content, is_read, created_at)
            VALUES (v_school_id, v_admin_id, v_transport_group_id, 'Bus No. 3 will be delayed by 10 min.', TRUE, NOW() - INTERVAL '2 days');
        END IF;

        -- Vikas Tiwari
        IF v_vikas_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.messages WHERE (sender_id = v_vikas_id AND receiver_id = v_admin_id) OR (sender_id = v_admin_id AND receiver_id = v_vikas_id)) THEN
            INSERT INTO public.messages (school_id, sender_id, receiver_id, content, is_read, created_at)
            VALUES (v_school_id, v_vikas_id, v_admin_id, 'Noted. Thanks.', TRUE, NOW() - INTERVAL '3 days');
        END IF;

        -- Science Lab Group
        IF NOT EXISTS (SELECT 1 FROM public.messages WHERE group_id = v_science_group_id) THEN
            INSERT INTO public.messages (school_id, sender_id, group_id, content, is_read, created_at)
            VALUES (v_school_id, v_admin_id, v_science_group_id, 'Lab activity scheduled for Friday.', TRUE, NOW() - INTERVAL '4 days');
        END IF;

        -- Megha Kapoor
        IF v_megha_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.messages WHERE (sender_id = v_megha_id AND receiver_id = v_admin_id) OR (sender_id = v_admin_id AND receiver_id = v_megha_id)) THEN
            INSERT INTO public.messages (school_id, sender_id, receiver_id, content, is_read, created_at)
            VALUES (v_school_id, v_megha_id, v_admin_id, 'Could you share the timetable?', TRUE, NOW() - INTERVAL '4 days');
        END IF;

        -- AC Team
        IF NOT EXISTS (SELECT 1 FROM public.messages WHERE group_id = v_ac_group_id) THEN
            INSERT INTO public.messages (school_id, sender_id, group_id, content, is_read, created_at)
            VALUES (v_school_id, v_admin_id, v_ac_group_id, 'Meeting at 4 PM today.', TRUE, NOW() - INTERVAL '5 days');
        END IF;
    END IF;
END $$;
