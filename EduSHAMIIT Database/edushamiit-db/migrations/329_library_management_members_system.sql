-- ============================================================================
-- Migration 329: Library Management Members & Circulation Subsystem
-- Multi-tenant, Profile-Linked Membership Engine with Lookups,
-- Active Borrows, Fines Tracking, Renewals, Suspensions, and Auditing.
-- ============================================================================

-- 1. Ensure Lookup Keys for Library Membership Types
DO $$
DECLARE
    r RECORD;
    v_key_id UUID;
BEGIN
    FOR r IN SELECT id FROM public.schools LOOP
        INSERT INTO public.lookup_keys (
            school_id, key_name, key_code, description, key_type, icon, status
        ) VALUES (
            r.id,
            'Library Membership Type',
            'LIBRARY_MEMBERSHIP_TYPE',
            'Categories of library patrons and borrowing privilege tiers.',
            'SYSTEM',
            'badge_rounded',
            'ACTIVE'
        )
        ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL
        DO NOTHING;

        SELECT id INTO v_key_id 
        FROM public.lookup_keys 
        WHERE school_id = r.id AND key_code = 'LIBRARY_MEMBERSHIP_TYPE' AND deleted_at IS NULL 
        LIMIT 1;

        IF v_key_id IS NOT NULL THEN
            INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order)
            VALUES
                (v_key_id, r.id, 'Student', 'STUDENT', 'Enrolled student membership tier.', 'ACTIVE', 1),
                (v_key_id, r.id, 'Teacher', 'TEACHER', 'Academic faculty member tier with extended book allowances.', 'ACTIVE', 2),
                (v_key_id, r.id, 'Staff', 'STAFF', 'Administrative and institutional staff tier.', 'ACTIVE', 3),
                (v_key_id, r.id, 'Librarian', 'LIBRARIAN', 'Library staff & administrative custodian tier.', 'ACTIVE', 4),
                (v_key_id, r.id, 'Special / Research', 'SPECIAL', 'Visiting scholar or special research privileges tier.', 'ACTIVE', 5)
            ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL
            DO NOTHING;
        END IF;
    END LOOP;
END $$;


-- 2. Create public.library_members Table (Profile-Linked, Multi-Tenant)
CREATE TABLE IF NOT EXISTS public.library_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    member_code VARCHAR(100) NOT NULL, -- e.g. LIBM-0001
    membership_type VARCHAR(100) NOT NULL DEFAULT 'Student',
    membership_type_id UUID REFERENCES public.lookup_values(id) ON DELETE SET NULL,
    membership_start_date DATE NOT NULL DEFAULT CURRENT_DATE,
    membership_expiry_date DATE NOT NULL DEFAULT (CURRENT_DATE + INTERVAL '1 year')::DATE,
    borrowing_limit INTEGER NOT NULL DEFAULT 3,
    max_issue_duration_days INTEGER NOT NULL DEFAULT 14,
    renewal_allowed BOOLEAN NOT NULL DEFAULT TRUE,
    max_renewals INTEGER NOT NULL DEFAULT 2,
    current_borrowed_count INTEGER NOT NULL DEFAULT 0,
    total_borrowed_count INTEGER NOT NULL DEFAULT 0,
    total_fines_incurred DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    total_fines_paid DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    outstanding_fine DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, EXPIRING_SOON, EXPIRED, SUSPENDED, INACTIVE
    suspension_reason TEXT,
    suspended_at TIMESTAMPTZ,
    suspended_by UUID REFERENCES public.profiles(id),
    notes TEXT,
    created_by UUID REFERENCES public.profiles(id),
    updated_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    archived_at TIMESTAMPTZ,
    archived_by UUID REFERENCES public.profiles(id),
    CONSTRAINT uq_library_members_school_profile UNIQUE(school_id, profile_id),
    CONSTRAINT uq_library_members_school_code UNIQUE(school_id, member_code)
);

-- Ensure all columns exist
DO $$
BEGIN
    ALTER TABLE public.library_members ADD COLUMN IF NOT EXISTS membership_type_id UUID REFERENCES public.lookup_values(id) ON DELETE SET NULL;
    ALTER TABLE public.library_members ADD COLUMN IF NOT EXISTS membership_start_date DATE NOT NULL DEFAULT CURRENT_DATE;
    ALTER TABLE public.library_members ADD COLUMN IF NOT EXISTS membership_expiry_date DATE NOT NULL DEFAULT (CURRENT_DATE + INTERVAL '1 year')::DATE;
    ALTER TABLE public.library_members ADD COLUMN IF NOT EXISTS borrowing_limit INTEGER NOT NULL DEFAULT 3;
    ALTER TABLE public.library_members ADD COLUMN IF NOT EXISTS max_issue_duration_days INTEGER NOT NULL DEFAULT 14;
    ALTER TABLE public.library_members ADD COLUMN IF NOT EXISTS renewal_allowed BOOLEAN NOT NULL DEFAULT TRUE;
    ALTER TABLE public.library_members ADD COLUMN IF NOT EXISTS max_renewals INTEGER NOT NULL DEFAULT 2;
    ALTER TABLE public.library_members ADD COLUMN IF NOT EXISTS current_borrowed_count INTEGER NOT NULL DEFAULT 0;
    ALTER TABLE public.library_members ADD COLUMN IF NOT EXISTS total_borrowed_count INTEGER NOT NULL DEFAULT 0;
    ALTER TABLE public.library_members ADD COLUMN IF NOT EXISTS total_fines_incurred DECIMAL(10,2) NOT NULL DEFAULT 0.00;
    ALTER TABLE public.library_members ADD COLUMN IF NOT EXISTS total_fines_paid DECIMAL(10,2) NOT NULL DEFAULT 0.00;
    ALTER TABLE public.library_members ADD COLUMN IF NOT EXISTS outstanding_fine DECIMAL(10,2) NOT NULL DEFAULT 0.00;
    ALTER TABLE public.library_members ADD COLUMN IF NOT EXISTS status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE';
    ALTER TABLE public.library_members ADD COLUMN IF NOT EXISTS suspension_reason TEXT;
    ALTER TABLE public.library_members ADD COLUMN IF NOT EXISTS suspended_at TIMESTAMPTZ;
    ALTER TABLE public.library_members ADD COLUMN IF NOT EXISTS suspended_by UUID REFERENCES public.profiles(id);
    ALTER TABLE public.library_members ADD COLUMN IF NOT EXISTS notes TEXT;
    ALTER TABLE public.library_members ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.profiles(id);
    ALTER TABLE public.library_members ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES public.profiles(id);
    ALTER TABLE public.library_members ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
    ALTER TABLE public.library_members ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
    ALTER TABLE public.library_members ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ;
    ALTER TABLE public.library_members ADD COLUMN IF NOT EXISTS archived_by UUID REFERENCES public.profiles(id);
END $$;


-- 3. Enhance public.library_borrows Table
DO $$
BEGIN
    ALTER TABLE public.library_borrows ADD COLUMN IF NOT EXISTS member_id UUID REFERENCES public.library_members(id) ON DELETE CASCADE;
    ALTER TABLE public.library_borrows ADD COLUMN IF NOT EXISTS copy_id UUID REFERENCES public.library_book_copies(id) ON DELETE SET NULL;
    ALTER TABLE public.library_borrows ADD COLUMN IF NOT EXISTS issue_date DATE NOT NULL DEFAULT CURRENT_DATE;
    ALTER TABLE public.library_borrows ADD COLUMN IF NOT EXISTS due_date DATE;
    ALTER TABLE public.library_borrows ADD COLUMN IF NOT EXISTS return_date DATE;
    ALTER TABLE public.library_borrows ADD COLUMN IF NOT EXISTS return_condition VARCHAR(50);
    ALTER TABLE public.library_borrows ADD COLUMN IF NOT EXISTS issued_by UUID REFERENCES public.profiles(id);
    ALTER TABLE public.library_borrows ADD COLUMN IF NOT EXISTS received_by UUID REFERENCES public.profiles(id);
    ALTER TABLE public.library_borrows ADD COLUMN IF NOT EXISTS notes TEXT;
END $$;


-- 4. Create public.library_fines Table
CREATE TABLE IF NOT EXISTS public.library_fines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    member_id UUID NOT NULL REFERENCES public.library_members(id) ON DELETE CASCADE,
    borrow_id UUID REFERENCES public.library_borrows(id) ON DELETE SET NULL,
    amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    paid_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    waived_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    outstanding_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    reason VARCHAR(255) NOT NULL DEFAULT 'OVERDUE_FINE', -- OVERDUE_FINE, DAMAGE_FINE, LOST_BOOK_FINE
    status VARCHAR(50) NOT NULL DEFAULT 'UNPAID', -- UNPAID, PARTIAL, PAID, WAIVED
    paid_at TIMESTAMPTZ,
    waived_at TIMESTAMPTZ,
    waived_by UUID REFERENCES public.profiles(id),
    waiver_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- 5. Create public.library_member_audits Table
CREATE TABLE IF NOT EXISTS public.library_member_audits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    member_id UUID NOT NULL REFERENCES public.library_members(id) ON DELETE CASCADE,
    action_type VARCHAR(100) NOT NULL, -- CREATED, RENEWED, SUSPENDED, ACTIVATED, LIMIT_CHANGED, STATUS_CHANGED
    description TEXT NOT NULL,
    old_values JSONB,
    new_values JSONB,
    performed_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- 6. Indexes for Performance
CREATE INDEX IF NOT EXISTS idx_lib_members_school_status ON public.library_members(school_id, status);
CREATE INDEX IF NOT EXISTS idx_lib_members_profile_id ON public.library_members(profile_id);
CREATE INDEX IF NOT EXISTS idx_lib_members_member_code ON public.library_members(school_id, member_code);
CREATE INDEX IF NOT EXISTS idx_lib_borrows_member_status ON public.library_borrows(member_id, status);
CREATE INDEX IF NOT EXISTS idx_lib_fines_member_status ON public.library_fines(member_id, status);


-- 7. Seed Library Members & Transactions for All Schools
DO $$
DECLARE
    v_school RECORD;
    v_profile RECORD;
    v_member_id UUID;
    v_member_code VARCHAR(50);
    v_counter INT;
    v_book_copy RECORD;
    v_borrow_id UUID;
    v_fine_amount DECIMAL(10,2);
    v_is_overdue BOOLEAN;
    v_book_id UUID;
    v_super_admin_id UUID;
BEGIN
    FOR v_school IN SELECT id FROM public.schools LOOP
        v_counter := 1;

        -- Get super admin if exists for audit attribution
        SELECT id INTO v_super_admin_id FROM public.profiles WHERE school_id = v_school.id AND role IN ('super_admin', 'admin') LIMIT 1;

        -- Loop through active profiles in the school (students, teachers, staff)
        FOR v_profile IN 
            SELECT p.id, p.full_name, p.role, p.class, p.department, p.email, p.phone, p.admission_number, p.employee_id
            FROM public.profiles p
            WHERE p.school_id = v_school.id
              AND p.role IN ('student', 'teacher', 'library', 'admin', 'finance', 'hr')
            ORDER BY 
                CASE WHEN p.role = 'student' THEN 1 WHEN p.role = 'teacher' THEN 2 ELSE 3 END,
                p.full_name
            LIMIT 40
        LOOP
            v_member_code := 'LIBM-' || LPAD(v_counter::TEXT, 4, '0');

            -- Determine membership type and limits based on role
            INSERT INTO public.library_members (
                school_id,
                profile_id,
                member_code,
                membership_type,
                membership_start_date,
                membership_expiry_date,
                borrowing_limit,
                max_issue_duration_days,
                renewal_allowed,
                max_renewals,
                status,
                created_by
            ) VALUES (
                v_school.id,
                v_profile.id,
                v_member_code,
                CASE 
                    WHEN v_profile.role = 'student' THEN 'Student'
                    WHEN v_profile.role = 'teacher' THEN 'Teacher'
                    WHEN v_profile.role = 'library' THEN 'Librarian'
                    ELSE 'Staff'
                END,
                CURRENT_DATE - (v_counter * 10 || ' days')::INTERVAL,
                (CURRENT_DATE + INTERVAL '1 year')::DATE,
                CASE WHEN v_profile.role = 'teacher' THEN 5 WHEN v_profile.role = 'student' THEN 3 ELSE 2 END,
                CASE WHEN v_profile.role = 'teacher' THEN 30 ELSE 14 END,
                TRUE,
                2,
                CASE 
                    WHEN v_counter = 10 THEN 'INACTIVE'
                    WHEN v_counter = 15 THEN 'SUSPENDED'
                    ELSE 'ACTIVE'
                END,
                v_super_admin_id
            )
            ON CONFLICT (school_id, profile_id) 
            DO UPDATE SET 
                member_code = EXCLUDED.member_code,
                membership_type = EXCLUDED.membership_type,
                status = EXCLUDED.status
            RETURNING id INTO v_member_id;

            -- Audit log for membership creation
            INSERT INTO public.library_member_audits (
                school_id, member_id, action_type, description, performed_by
            ) VALUES (
                v_school.id, v_member_id, 'CREATED', 'Library membership created for ' || v_profile.full_name, v_super_admin_id
            ) ON CONFLICT DO NOTHING;

            -- Seed sample active borrows and fines for specific member indices
            IF v_counter IN (1, 2, 3, 5, 6, 9) THEN
                -- Pick an available or issued book copy
                SELECT c.id, c.book_id INTO v_book_copy
                FROM public.library_book_copies c
                WHERE c.school_id = v_school.id AND c.archived_at IS NULL
                ORDER BY RANDOM()
                LIMIT 1;

                IF v_book_copy.id IS NOT NULL THEN
                    v_is_overdue := (v_counter IN (1, 3, 6));
                    v_fine_amount := CASE 
                        WHEN v_counter = 1 THEN 50.00
                        WHEN v_counter = 3 THEN 120.00
                        WHEN v_counter = 6 THEN 25.00
                        WHEN v_counter = 9 THEN 10.00
                        ELSE 0.00
                    END;

                    -- Insert or update library borrow
                    INSERT INTO public.library_borrows (
                        school_id,
                        book_id,
                        copy_id,
                        member_id,
                        student_id,
                        borrowed_at,
                        due_at,
                        issue_date,
                        due_date,
                        status,
                        fine_amount,
                        issued_by
                    ) VALUES (
                        v_school.id,
                        v_book_copy.book_id,
                        v_book_copy.id,
                        v_member_id,
                        v_profile.id,
                        CURRENT_TIMESTAMP - (CASE WHEN v_is_overdue THEN INTERVAL '25 days' ELSE INTERVAL '5 days' END),
                        CURRENT_TIMESTAMP + (CASE WHEN v_is_overdue THEN INTERVAL '-5 days' ELSE INTERVAL '9 days' END),
                        (CURRENT_DATE - (CASE WHEN v_is_overdue THEN 25 ELSE 5 END)),
                        (CURRENT_DATE + (CASE WHEN v_is_overdue THEN -5 ELSE 9 END)),
                        'ISSUED',
                        v_fine_amount,
                        v_super_admin_id
                    ) RETURNING id INTO v_borrow_id;

                    -- Update book copy status
                    UPDATE public.library_book_copies
                    SET status = 'ISSUED',
                        current_borrower_id = v_profile.id,
                        borrowed_at = CURRENT_TIMESTAMP - (CASE WHEN v_is_overdue THEN INTERVAL '25 days' ELSE INTERVAL '5 days' END),
                        due_date = CURRENT_TIMESTAMP + (CASE WHEN v_is_overdue THEN INTERVAL '-5 days' ELSE INTERVAL '9 days' END)
                    WHERE id = v_book_copy.id;

                    -- If fine exists, record in library_fines table
                    IF v_fine_amount > 0 THEN
                        INSERT INTO public.library_fines (
                            school_id, member_id, borrow_id, amount, outstanding_amount, reason, status
                        ) VALUES (
                            v_school.id, v_member_id, v_borrow_id, v_fine_amount, v_fine_amount, 'OVERDUE_FINE', 'UNPAID'
                        );
                    END IF;
                END IF;
            END IF;

            -- If counter == 1 (Aarav Sharma), give a 2nd active book as shown in the screenshot
            IF v_counter = 1 THEN
                SELECT c.id, c.book_id INTO v_book_copy
                FROM public.library_book_copies c
                WHERE c.school_id = v_school.id AND c.archived_at IS NULL AND c.id != v_book_copy.id
                ORDER BY RANDOM()
                LIMIT 1;

                IF v_book_copy.id IS NOT NULL THEN
                    INSERT INTO public.library_borrows (
                        school_id,
                        book_id,
                        copy_id,
                        member_id,
                        student_id,
                        borrowed_at,
                        due_at,
                        issue_date,
                        due_date,
                        status,
                        fine_amount,
                        issued_by
                    ) VALUES (
                        v_school.id,
                        v_book_copy.book_id,
                        v_book_copy.id,
                        v_member_id,
                        v_profile.id,
                        CURRENT_TIMESTAMP - INTERVAL '10 days',
                        CURRENT_TIMESTAMP + INTERVAL '4 days',
                        CURRENT_DATE - 10,
                        CURRENT_DATE + 4,
                        'ISSUED',
                        0.00,
                        v_super_admin_id
                    );

                    UPDATE public.library_book_copies
                    SET status = 'ISSUED',
                        current_borrower_id = v_profile.id,
                        borrowed_at = CURRENT_TIMESTAMP - INTERVAL '10 days',
                        due_date = CURRENT_TIMESTAMP + INTERVAL '4 days'
                    WHERE id = v_book_copy.id;
                END IF;
            END IF;

            -- Sync member aggregates (borrowed count & outstanding fines)
            UPDATE public.library_members m
            SET 
                current_borrowed_count = (
                    SELECT COUNT(*) FROM public.library_borrows b 
                    WHERE b.member_id = m.id AND b.status = 'ISSUED'
                ),
                outstanding_fine = (
                    COALESCE((SELECT SUM(f.outstanding_amount) FROM public.library_fines f WHERE f.member_id = m.id AND f.status != 'PAID' AND f.status != 'WAIVED'), 0.00)
                )
            WHERE m.id = v_member_id;

            v_counter := v_counter + 1;
        END LOOP;
    END LOOP;
END $$;
