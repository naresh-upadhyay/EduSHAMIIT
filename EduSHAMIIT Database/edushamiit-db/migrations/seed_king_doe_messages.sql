DO $$
DECLARE
    v_king_id UUID := '5198c4b0-f1cb-45db-9649-41688d0438ba';
    v_school_id UUID := '11111111-1111-1111-1111-111111111111';
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
    SELECT id INTO v_aarav_id FROM public.profiles WHERE full_name = 'Aarav Sharma' LIMIT 1;
    SELECT id INTO v_anita_id FROM public.profiles WHERE full_name = 'Anita Sharma' LIMIT 1;
    SELECT id INTO v_rohit_id FROM public.profiles WHERE full_name = 'Rohit Malhotra' LIMIT 1;
    SELECT id INTO v_pooja_id FROM public.profiles WHERE full_name = 'Pooja Rathi' LIMIT 1;
    SELECT id INTO v_vikas_id FROM public.profiles WHERE full_name = 'Vikas Tiwari' LIMIT 1;
    SELECT id INTO v_megha_id FROM public.profiles WHERE full_name = 'Megha Kapoor' LIMIT 1;

    SELECT id INTO v_class10a_group_id FROM public.groups WHERE name = 'Class 10-A Group' LIMIT 1;
    SELECT id INTO v_library_group_id FROM public.groups WHERE name = 'Library Team' LIMIT 1;
    SELECT id INTO v_transport_group_id FROM public.groups WHERE name = 'Transport Team' LIMIT 1;
    SELECT id INTO v_science_group_id FROM public.groups WHERE name = 'Science Lab Group' LIMIT 1;
    SELECT id INTO v_ac_group_id FROM public.groups WHERE name = 'AC Team' LIMIT 1;

    -- Add King Doe to all groups as admin
    IF v_class10a_group_id IS NOT NULL THEN
        INSERT INTO public.group_members (group_id, member_id, role) VALUES (v_class10a_group_id, v_king_id, 'admin') ON CONFLICT (group_id, member_id) DO NOTHING;
    END IF;
    IF v_library_group_id IS NOT NULL THEN
        INSERT INTO public.group_members (group_id, member_id, role) VALUES (v_library_group_id, v_king_id, 'admin') ON CONFLICT (group_id, member_id) DO NOTHING;
    END IF;
    IF v_transport_group_id IS NOT NULL THEN
        INSERT INTO public.group_members (group_id, member_id, role) VALUES (v_transport_group_id, v_king_id, 'admin') ON CONFLICT (group_id, member_id) DO NOTHING;
    END IF;
    IF v_science_group_id IS NOT NULL THEN
        INSERT INTO public.group_members (group_id, member_id, role) VALUES (v_science_group_id, v_king_id, 'admin') ON CONFLICT (group_id, member_id) DO NOTHING;
    END IF;
    IF v_ac_group_id IS NOT NULL THEN
        INSERT INTO public.group_members (group_id, member_id, role) VALUES (v_ac_group_id, v_king_id, 'admin') ON CONFLICT (group_id, member_id) DO NOTHING;
    END IF;

    -- Seed Anita Sharma conversation with King Doe exactly matching reference screenshot
    IF v_anita_id IS NOT NULL THEN
        DELETE FROM public.messages WHERE school_id = v_school_id AND ((sender_id = v_king_id AND receiver_id = v_anita_id) OR (sender_id = v_anita_id AND receiver_id = v_king_id));

        INSERT INTO public.messages (school_id, sender_id, receiver_id, content, is_read, created_at, message_type)
        VALUES (v_school_id, v_anita_id, v_king_id, 'Good Morning Sir, Please share the attendance record of my ward for this month.', TRUE, NOW() - INTERVAL '68 minutes', 'text');

        INSERT INTO public.messages (school_id, sender_id, receiver_id, content, attachment_url, file_name, file_size, is_read, created_at, message_type)
        VALUES (v_school_id, v_king_id, v_anita_id, 'Good Morning, Here is the attendance report.', 'https://raw.githubusercontent.com/mozilla/pdf.js/ba2edeae/examples/learning/helloworld.pdf', 'Attendance_Report_Oct2025.pdf', 250880, TRUE, NOW() - INTERVAL '52 minutes', 'file');

        INSERT INTO public.messages (school_id, sender_id, receiver_id, content, is_read, created_at, message_type)
        VALUES (v_school_id, v_anita_id, v_king_id, 'Thank you for the information.', FALSE, NOW() - INTERVAL '2 minutes', 'text');

        INSERT INTO public.messages (school_id, sender_id, receiver_id, content, is_read, created_at, message_type)
        VALUES (v_school_id, v_king_id, v_anita_id, 'You are welcome!', TRUE, NOW() - INTERVAL '1 minute', 'text');
    END IF;

    -- Seed messages with other contacts
    IF v_rohit_id IS NOT NULL THEN
        INSERT INTO public.messages (school_id, sender_id, receiver_id, content, is_read, created_at)
        VALUES (v_school_id, v_rohit_id, v_king_id, 'Fees receipt is attached.', TRUE, NOW() - INTERVAL '1 day');
    END IF;

    IF v_pooja_id IS NOT NULL THEN
        INSERT INTO public.messages (school_id, sender_id, receiver_id, content, is_read, created_at)
        VALUES (v_school_id, v_pooja_id, v_king_id, 'Okay, will do it.', TRUE, NOW() - INTERVAL '2 days');
    END IF;

    IF v_vikas_id IS NOT NULL THEN
        INSERT INTO public.messages (school_id, sender_id, receiver_id, content, is_read, created_at)
        VALUES (v_school_id, v_vikas_id, v_king_id, 'Noted. Thanks.', TRUE, NOW() - INTERVAL '3 days');
    END IF;

    IF v_megha_id IS NOT NULL THEN
        INSERT INTO public.messages (school_id, sender_id, receiver_id, content, is_read, created_at)
        VALUES (v_school_id, v_megha_id, v_king_id, 'Could you share the timetable?', TRUE, NOW() - INTERVAL '4 days');
    END IF;

    -- Ensure group messages exist
    IF v_class10a_group_id IS NOT NULL THEN
        INSERT INTO public.messages (school_id, sender_id, group_id, content, is_read, created_at)
        VALUES (v_school_id, v_king_id, v_class10a_group_id, 'Reminder: Unit Test on Friday...', FALSE, NOW() - INTERVAL '34 minutes');
    END IF;

    IF v_library_group_id IS NOT NULL THEN
        INSERT INTO public.messages (school_id, sender_id, group_id, content, is_read, created_at)
        VALUES (v_school_id, v_king_id, v_library_group_id, 'New books are available in library.', TRUE, NOW() - INTERVAL '1 day');
    END IF;

    IF v_transport_group_id IS NOT NULL THEN
        INSERT INTO public.messages (school_id, sender_id, group_id, content, is_read, created_at)
        VALUES (v_school_id, v_king_id, v_transport_group_id, 'Bus No. 3 will be delayed by 10 min.', TRUE, NOW() - INTERVAL '2 days');
    END IF;

    IF v_science_group_id IS NOT NULL THEN
        INSERT INTO public.messages (school_id, sender_id, group_id, content, is_read, created_at)
        VALUES (v_school_id, v_king_id, v_science_group_id, 'Lab activity scheduled for Friday.', TRUE, NOW() - INTERVAL '4 days');
    END IF;

    IF v_ac_group_id IS NOT NULL THEN
        INSERT INTO public.messages (school_id, sender_id, group_id, content, is_read, created_at)
        VALUES (v_school_id, v_king_id, v_ac_group_id, 'Meeting at 4 PM today.', TRUE, NOW() - INTERVAL '5 days');
    END IF;
END $$;

