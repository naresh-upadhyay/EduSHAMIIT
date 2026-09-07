-- Migration 347: Fix library_fines member_id not-null violation on book return and enhance member resolution

-- 1. Relax NOT NULL constraint on library_fines and library_fine_payments as defensive measure
ALTER TABLE public.library_fines ALTER COLUMN member_id DROP NOT NULL;
ALTER TABLE public.library_fine_payments ALTER COLUMN member_id DROP NOT NULL;

-- 2. Backfill any library_borrows missing member_id
UPDATE public.library_borrows b
SET member_id = m.id
FROM public.library_members m
WHERE b.member_id IS NULL 
  AND b.student_id = m.profile_id;

-- 3. Enhance fn_library_return_books with auto-resolution of member_id, fine recording, and counter decrement
CREATE OR REPLACE FUNCTION public.fn_library_return_books(
    p_school_id uuid,
    p_items jsonb,
    p_received_by uuid,
    p_collect_fine boolean DEFAULT false,
    p_payment_method character varying DEFAULT 'CASH'::character varying,
    p_payment_ref character varying DEFAULT NULL::character varying
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_item JSONB;
    v_borrow_id UUID;
    v_condition VARCHAR(50);
    v_notes TEXT;
    v_borrow RECORD;
    v_member_id UUID;
    v_days_overdue INT;
    v_fine_rate NUMERIC := 10.00;
    v_calculated_fine NUMERIC := 0.00;
    v_damage_charge NUMERIC := 0.00;
    v_lost_charge NUMERIC := 0.00;
    v_total_item_fine NUMERIC := 0.00;
    v_fine_id UUID;
    v_receipt_no VARCHAR(50);
    v_returned_count INT := 0;
    v_processed_items JSONB := '[]'::jsonb;
    v_book RECORD;
    v_profile RECORD;
BEGIN
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_borrow_id := (v_item->>'borrow_id')::uuid;
        v_condition := COALESCE(v_item->>'condition', 'GOOD');
        v_notes := v_item->>'notes';
        v_damage_charge := COALESCE((v_item->>'damage_charge')::numeric, 0.00);
        v_lost_charge := COALESCE((v_item->>'lost_charge')::numeric, 0.00);

        SELECT * INTO v_borrow FROM public.library_borrows 
        WHERE id = v_borrow_id AND school_id = p_school_id
        FOR UPDATE;

        IF NOT FOUND THEN
            CONTINUE;
        END IF;

        IF v_borrow.is_returned IS TRUE OR UPPER(v_borrow.status) = 'RETURNED' THEN
            RAISE EXCEPTION 'Transaction % has already been returned.', v_borrow.transaction_code;
        END IF;

        -- Logical validation: Book must be in an issued/active state or return-pending
        IF UPPER(COALESCE(v_borrow.status, '')) NOT IN ('ISSUED', 'BORROWED', 'OVERDUE', 'RENEWED', 'PENDING_RETURN') THEN
            RAISE EXCEPTION 'Cannot return book. Transaction % must be in an issued or return-pending state (Current status: "%").', v_borrow.transaction_code, v_borrow.status;
        END IF;

        -- Resolve member_id if missing from borrow row
        v_member_id := v_borrow.member_id;
        IF v_member_id IS NULL AND v_borrow.student_id IS NOT NULL THEN
            SELECT id INTO v_member_id 
            FROM public.library_members 
            WHERE profile_id = v_borrow.student_id AND school_id = p_school_id AND archived_at IS NULL
            LIMIT 1;

            -- Auto-create member record if user doesn't have one
            IF v_member_id IS NULL THEN
                DECLARE
                    v_auto_code VARCHAR(100);
                    v_user_role VARCHAR(50);
                BEGIN
                    SELECT role INTO v_user_role FROM public.profiles WHERE id = v_borrow.student_id;
                    v_auto_code := 'LIBM-' || LPAD((FLOOR(RANDOM() * 90000) + 10000)::text, 5, '0');
                    INSERT INTO public.library_members (
                        school_id, profile_id, member_code, membership_type, status, created_at, updated_at
                    ) VALUES (
                        p_school_id, v_borrow.student_id, v_auto_code,
                        CASE WHEN v_user_role ILIKE '%teacher%' OR v_user_role ILIKE '%staff%' THEN 'Staff' ELSE 'Student' END,
                        'ACTIVE', NOW(), NOW()
                    ) RETURNING id INTO v_member_id;
                EXCEPTION WHEN OTHERS THEN
                    SELECT id INTO v_member_id FROM public.library_members WHERE profile_id = v_borrow.student_id AND school_id = p_school_id LIMIT 1;
                END;
            END IF;

            -- Link member back to the borrow record
            IF v_member_id IS NOT NULL THEN
                UPDATE public.library_borrows SET member_id = v_member_id WHERE id = v_borrow_id;
            END IF;
        END IF;

        -- Calculate overdue days & fine
        v_days_overdue := GREATEST(0, CURRENT_DATE - v_borrow.due_date);
        v_calculated_fine := v_days_overdue * v_fine_rate;
        v_total_item_fine := v_calculated_fine + v_damage_charge + v_lost_charge;

        SELECT full_name INTO v_profile FROM public.profiles p 
        LEFT JOIN public.library_members m ON m.profile_id = p.id 
        WHERE (m.id = v_member_id OR p.id = v_borrow.student_id) 
        LIMIT 1;

        -- If fine generated, record in library_fines
        IF v_total_item_fine > 0 THEN
            INSERT INTO public.library_fines (
                school_id, member_id, borrow_id, amount, paid_amount, waived_amount,
                outstanding_amount, reason, status, created_at, updated_at
            ) VALUES (
                p_school_id, v_member_id, v_borrow_id, v_total_item_fine,
                CASE WHEN p_collect_fine THEN v_total_item_fine ELSE 0.00 END,
                0.00,
                CASE WHEN p_collect_fine THEN 0.00 ELSE v_total_item_fine END,
                format('Overdue: %s days (₹%s), Condition: %s', v_days_overdue, v_calculated_fine, v_condition),
                CASE WHEN p_collect_fine THEN 'PAID' ELSE 'UNPAID' END,
                NOW(), NOW()
            ) RETURNING id INTO v_fine_id;

            -- Record fine payment if collected immediately
            IF p_collect_fine THEN
                v_receipt_no := 'RCP-' || LPAD((FLOOR(RANDOM() * 90000) + 10000)::text, 5, '0');
                INSERT INTO public.library_fine_payments (
                    school_id, fine_id, borrow_id, member_id, amount_paid,
                    payment_method, transaction_reference, receipt_number,
                    notes, collected_by, created_at
                ) VALUES (
                    p_school_id, v_fine_id, v_borrow_id, v_member_id, v_total_item_fine,
                    p_payment_method, p_payment_ref, v_receipt_no,
                    'Instant fine payment upon return', p_received_by, NOW()
                );
            END IF;

            -- Update Member outstanding fine if unpaid
            IF v_member_id IS NOT NULL THEN
                IF NOT p_collect_fine THEN
                    UPDATE public.library_members
                    SET outstanding_fine = outstanding_fine + v_total_item_fine,
                        total_fines_incurred = total_fines_incurred + v_total_item_fine,
                        updated_at = NOW()
                    WHERE id = v_member_id;
                ELSE
                    UPDATE public.library_members
                    SET total_fines_paid = total_fines_paid + v_total_item_fine,
                        total_fines_incurred = total_fines_incurred + v_total_item_fine,
                        updated_at = NOW()
                    WHERE id = v_member_id;
                END IF;
            END IF;
        END IF;

        -- Decrement member currently borrowed count
        IF v_member_id IS NOT NULL THEN
            UPDATE public.library_members
            SET current_borrowed_count = GREATEST(0, current_borrowed_count - 1),
                updated_at = NOW()
            WHERE id = v_member_id;
        END IF;

        -- Update Borrow Record
        UPDATE public.library_borrows
        SET is_returned = TRUE,
            return_date = CURRENT_DATE,
            returned_at = NOW(),
            status = CASE 
                WHEN v_condition = 'LOST' THEN 'LOST' 
                WHEN v_condition IN ('DAMAGED', 'MAJOR_DAMAGE') THEN 'DAMAGED' 
                ELSE 'RETURNED' 
            END,
            transaction_type = 'MANUAL_RETURN',
            return_condition = v_condition,
            fine_amount = v_total_item_fine,
            fine_status = CASE 
                WHEN v_total_item_fine = 0 THEN 'NONE'
                WHEN p_collect_fine THEN 'PAID'
                ELSE 'UNPAID'
            END,
            damage_charge = v_damage_charge,
            lost_charge = v_lost_charge,
            received_by = p_received_by,
            notes = COALESCE(v_notes, notes),
            updated_at = NOW()
        WHERE id = v_borrow_id;

        -- Update Copy Status
        IF v_borrow.copy_id IS NOT NULL THEN
            UPDATE public.library_book_copies
            SET status = CASE 
                    WHEN v_condition = 'LOST' THEN 'LOST'
                    WHEN v_condition IN ('DAMAGED', 'MAJOR_DAMAGE') THEN 'DAMAGED'
                    ELSE 'AVAILABLE'
                END,
                condition = CASE 
                    WHEN v_condition IN ('MINOR_DAMAGE', 'MAJOR_DAMAGE', 'DAMAGED') THEN 'DAMAGED'
                    ELSE condition
                END,
                current_borrower_id = NULL,
                updated_at = NOW()
            WHERE id = v_borrow.copy_id;
        END IF;

        -- Update any associated requests in library_requests
        UPDATE public.library_requests
        SET status = 'COMPLETED',
            approval_status = 'APPROVED',
            approved_by = p_received_by,
            approved_at = NOW(),
            updated_at = NOW()
        WHERE borrow_id = v_borrow_id AND status IN ('PENDING', 'IN_PROGRESS', 'PENDING_RETURN');

        SELECT title INTO v_book FROM public.library_books WHERE id = v_borrow.book_id;

        INSERT INTO public.library_circulation_activities (
            school_id, activity_type, title, description, borrow_id, member_id, performed_by, created_at
        ) VALUES (
            p_school_id, 'RETURN', 'Book Returned',
            'Book "' || COALESCE(v_book.title, 'Book') || '" returned by ' || COALESCE(v_profile.full_name, 'Member') || ' (Fine: ₹' || v_total_item_fine || ', Condition: ' || v_condition || ')',
            v_borrow_id, v_member_id, p_received_by, NOW()
        );

        v_returned_count := v_returned_count + 1;
        v_processed_items := v_processed_items || jsonb_build_object(
            'borrow_id', v_borrow_id,
            'transaction_code', v_borrow.transaction_code,
            'fine_amount', v_total_item_fine,
            'condition', v_condition
        );
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'message', format('Successfully processed return of %s book(s).', v_returned_count),
        'returned_count', v_returned_count,
        'items', v_processed_items
    );
END;
$function$;

-- 4. Enhance fn_library_process_issue_request to link member_id if missing
CREATE OR REPLACE FUNCTION public.fn_library_process_issue_request(
    p_school_id uuid,
    p_borrow_id uuid,
    p_action text,
    p_copy_id uuid DEFAULT NULL::uuid,
    p_issue_date date DEFAULT NULL::date,
    p_due_date date DEFAULT NULL::date,
    p_performed_by uuid DEFAULT NULL::uuid,
    p_notes text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_borrow RECORD;
    v_member_id UUID;
    v_assigned_copy_id UUID := p_copy_id;
    v_barcode VARCHAR(50);
    v_accession VARCHAR(50);
    v_book_title VARCHAR(255);
    v_member_name VARCHAR(150);
    v_is_digital BOOLEAN := false;
    v_action_upper TEXT := UPPER(trim(p_action));
    v_issue_d DATE := COALESCE(p_issue_date, CURRENT_DATE);
    v_due_d DATE := COALESCE(p_due_date, CURRENT_DATE + 14);
BEGIN
    -- Fetch borrow record
    SELECT br.*, b.title AS b_title, b.is_digital AS b_is_digital, p.full_name AS m_name
    INTO v_borrow
    FROM public.library_borrows br
    LEFT JOIN public.library_books b ON br.book_id = b.id
    LEFT JOIN public.library_members m ON br.member_id = m.id
    LEFT JOIN public.profiles p ON (m.profile_id = p.id OR br.student_id = p.id)
    WHERE br.id = p_borrow_id AND br.school_id = p_school_id;

    IF v_borrow.id IS NULL THEN
        RAISE EXCEPTION 'Circulation transaction record not found.';
    END IF;

    v_book_title := COALESCE(v_borrow.b_title, 'Book');
    v_member_name := COALESCE(v_borrow.m_name, 'Member');
    v_is_digital := COALESCE(v_borrow.b_is_digital, false);

    -- Ensure member_id is resolved
    v_member_id := v_borrow.member_id;
    IF v_member_id IS NULL AND v_borrow.student_id IS NOT NULL THEN
        SELECT id INTO v_member_id FROM public.library_members 
        WHERE profile_id = v_borrow.student_id AND school_id = p_school_id AND archived_at IS NULL LIMIT 1;
        IF v_member_id IS NOT NULL THEN
            UPDATE public.library_borrows SET member_id = v_member_id WHERE id = p_borrow_id;
        END IF;
    END IF;

    IF v_action_upper = 'ISSUE' THEN
        -- If copy not specified:
        IF v_assigned_copy_id IS NULL THEN
            -- Try to find an available physical copy
            SELECT id, barcode, accession_number
            INTO v_assigned_copy_id, v_barcode, v_accession
            FROM public.library_book_copies
            WHERE book_id = v_borrow.book_id AND school_id = p_school_id
              AND UPPER(status) IN ('AVAILABLE', 'ACTIVE')
              AND is_deleted IS NOT TRUE
            ORDER BY created_at ASC
            LIMIT 1;

            -- If still null, check if book is digital format (eBook, Audiobook, Videobook)
            IF v_assigned_copy_id IS NULL THEN
                IF v_is_digital OR (SELECT COUNT(*) FROM public.library_digital_files WHERE book_id = v_borrow.book_id) > 0 THEN
                    -- Digital edition access granted without physical copy
                    v_barcode := 'DIGITAL';
                    v_accession := 'DIGITAL';
                ELSE
                    RAISE EXCEPTION 'No available physical copies found for "%" to issue immediately. Please mark as WAITING.', v_book_title;
                END IF;
            END IF;
        ELSE
            SELECT barcode, accession_number
            INTO v_barcode, v_accession
            FROM public.library_book_copies
            WHERE id = v_assigned_copy_id;
        END IF;

        -- Update copy status only if physical copy was assigned
        IF v_assigned_copy_id IS NOT NULL THEN
            UPDATE public.library_book_copies
            SET status = 'BORROWED', 
                current_borrower_id = COALESCE(v_borrow.student_id, (SELECT profile_id FROM public.library_members WHERE id = v_member_id)),
                borrowed_at = NOW(),
                due_date = (v_due_d || ' 23:59:59')::timestamptz,
                last_issued_date = NOW(),
                updated_at = NOW()
            WHERE id = v_assigned_copy_id;
        END IF;

        -- Update borrow row
        UPDATE public.library_borrows
        SET status = 'ISSUED',
            transaction_type = 'REQUEST_APPROVED',
            copy_id = v_assigned_copy_id,
            member_id = COALESCE(v_member_id, member_id),
            issue_date = v_issue_d,
            due_date = v_due_d,
            issued_by = p_performed_by,
            notes = COALESCE(p_notes, v_borrow.notes),
            updated_at = NOW()
        WHERE id = p_borrow_id;

        -- Increment member current_borrowed_count
        IF v_member_id IS NOT NULL THEN
            UPDATE public.library_members
            SET current_borrowed_count = current_borrowed_count + 1,
                total_borrowed_count = total_borrowed_count + 1,
                updated_at = NOW()
            WHERE id = v_member_id;
        END IF;

        -- Update request table
        UPDATE public.library_requests
        SET status = 'COMPLETED',
            approval_status = 'APPROVED',
            approved_by = p_performed_by,
            approved_at = NOW(),
            approval_comments = p_notes,
            updated_at = NOW()
        WHERE borrow_id = p_borrow_id OR (book_id = v_borrow.book_id AND requester_user_id = v_borrow.student_id AND status = 'PENDING');

        -- Activity log
        INSERT INTO public.library_circulation_activities (
            school_id, activity_type, title, description, borrow_id, member_id, performed_by, created_at
        ) VALUES (
            p_school_id, 'ISSUE', 'Issue Request Approved & Issued',
            'Book "' || v_book_title || '" issued to ' || v_member_name || ' (Copy: ' || COALESCE(v_barcode, v_accession, 'Digital Access') || ')',
            p_borrow_id, v_member_id, p_performed_by, NOW()
        );

        RETURN jsonb_build_object(
            'success', true,
            'message', 'Book successfully issued to ' || v_member_name || '.',
            'status', 'ISSUED',
            'copy_barcode', v_barcode,
            'due_date', v_due_d
        );

    ELSIF v_action_upper = 'WAITING' THEN
        UPDATE public.library_borrows
        SET status = 'WAITING',
            notes = COALESCE(p_notes, notes, 'Marked as waiting by librarian'),
            copy_id = COALESCE(v_assigned_copy_id, copy_id),
            member_id = COALESCE(v_member_id, member_id),
            issue_date = COALESCE(v_issue_d, issue_date),
            due_date = COALESCE(v_due_d, due_date),
            updated_at = NOW()
        WHERE id = p_borrow_id;

        UPDATE public.library_requests
        SET status = 'IN_PROGRESS',
            clarification_requested = true,
            clarification_message = COALESCE(p_notes, 'Waiting for book availability / library desk arrival'),
            additional_notes = COALESCE(p_notes, additional_notes),
            updated_at = NOW()
        WHERE borrow_id = p_borrow_id OR (book_id = v_borrow.book_id AND requester_user_id = v_borrow.student_id AND status IN ('PENDING', 'NEW', 'IN_PROGRESS'));

        INSERT INTO public.library_circulation_activities (
            school_id, activity_type, title, description, borrow_id, member_id, performed_by, created_at
        ) VALUES (
            p_school_id, 'WAITING', 'Request Status: Waiting',
            'Request for "' || v_book_title || '" by ' || v_member_name || ' marked as Waiting: ' || COALESCE(p_notes, 'Pending collection/copy'),
            p_borrow_id, v_member_id, p_performed_by, NOW()
        );

        RETURN jsonb_build_object(
            'success', true,
            'message', 'Request status set to Waiting.',
            'status', 'WAITING',
            'notes', p_notes
        );

    ELSIF v_action_upper = 'REJECT' THEN
        UPDATE public.library_borrows
        SET status = 'REJECTED',
            notes = COALESCE(p_notes, notes, 'Request rejected by librarian'),
            updated_at = NOW()
        WHERE id = p_borrow_id;

        UPDATE public.library_requests
        SET status = 'REJECTED',
            approval_status = 'REJECTED',
            approved_by = p_performed_by,
            approved_at = NOW(),
            approval_comments = p_notes,
            updated_at = NOW()
        WHERE borrow_id = p_borrow_id OR (book_id = v_borrow.book_id AND requester_user_id = v_borrow.student_id AND status IN ('PENDING', 'NEW', 'IN_PROGRESS'));

        INSERT INTO public.library_circulation_activities (
            school_id, activity_type, title, description, borrow_id, member_id, performed_by, created_at
        ) VALUES (
            p_school_id, 'REJECT', 'Issue Request Rejected',
            'Request for "' || v_book_title || '" rejected: ' || COALESCE(p_notes, 'No reason provided'),
            p_borrow_id, v_member_id, p_performed_by, NOW()
        );

        RETURN jsonb_build_object(
            'success', true,
            'message', 'Request has been rejected.',
            'status', 'REJECTED'
        );

    ELSE
        RAISE EXCEPTION 'Invalid action "%". Supported actions: ISSUE, WAITING, REJECT.', p_action;
    END IF;
END;
$function$;
