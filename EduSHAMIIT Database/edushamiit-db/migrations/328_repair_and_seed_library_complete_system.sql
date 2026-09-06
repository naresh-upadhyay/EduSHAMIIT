-- ============================================================================
-- Migration: 328_repair_and_seed_library_complete_system.sql
-- Description: Complete Library Inventory Repair, Lookup Synchronization,
--              Financial Year dataset integration, Legacy Book Cleanup,
--              and Physical Copy Seeding with 100% Data Integrity.
-- ============================================================================

DO $$
DECLARE
    v_school RECORD;
    v_book RECORD;
    v_student_1 UUID;
    v_student_2 UUID;
    v_student_3 UUID;
    v_copy_idx INT;
    v_prefix TEXT;
    v_acc_no TEXT;
    v_barcode TEXT;
    v_qr TEXT;
    v_cond TEXT;
    v_status TEXT;
    v_borrower_id UUID;
    v_borrowed_at TIMESTAMPTZ;
    v_due_date TIMESTAMPTZ;
    v_fy_key_id UUID;
    v_ay_key_id UUID;
    v_cat_key_id UUID;
    v_lang_key_id UUID;
    v_type_key_id UUID;
    v_cond_key_id UUID;
    v_acq_key_id UUID;
BEGIN

    -- 1. Ensure FINANCIAL_YEAR Lookups in System
    FOR v_school IN (SELECT id FROM public.schools) LOOP
        -- Financial Year
        INSERT INTO public.lookup_keys (school_id, key_code, key_name, description, key_type, icon, status)
        VALUES (v_school.id, 'FINANCIAL_YEAR', 'Financial Year', 'Fiscal budgeting and institutional procurement years', 'SYSTEM', 'calendar_today', 'ACTIVE')
        ON CONFLICT DO NOTHING;

        SELECT id INTO v_fy_key_id FROM public.lookup_keys WHERE (school_id = v_school.id OR school_id IS NULL) AND key_code = 'FINANCIAL_YEAR' LIMIT 1;
        IF v_fy_key_id IS NOT NULL THEN
            INSERT INTO public.lookup_values (lookup_key_id, school_id, value_code, value_name, sort_order, status)
            VALUES 
                (v_fy_key_id, v_school.id, 'FY_2026_27', '2026-27', 1, 'ACTIVE'),
                (v_fy_key_id, v_school.id, 'FY_2025_26', '2025-26', 2, 'ACTIVE'),
                (v_fy_key_id, v_school.id, 'FY_2024_25', '2024-25', 3, 'ACTIVE'),
                (v_fy_key_id, v_school.id, 'FY_2023_24', '2023-24', 4, 'ACTIVE'),
                (v_fy_key_id, v_school.id, 'FY_2022_23', '2022-23', 5, 'ACTIVE'),
                (v_fy_key_id, v_school.id, 'FY_2021_22', '2021-22', 6, 'ACTIVE'),
                (v_fy_key_id, v_school.id, 'FY_2020_21', '2020-21', 7, 'ACTIVE')
            ON CONFLICT DO NOTHING;
        END IF;
    END LOOP;

    -- 2. Remove orphaned or ghost duplicate book entries that have no copies and duplicate titles
    DELETE FROM public.library_books b1
    WHERE b1.archived_at IS NULL 
      AND (b1.isbn13 IS NULL OR b1.isbn13 = '')
      AND (SELECT COUNT(*) FROM public.library_book_copies c WHERE c.book_id = b1.id) = 0
      AND EXISTS (
          SELECT 1 FROM public.library_books b2 
          WHERE b2.school_id = b1.school_id 
            AND b2.title = b1.title 
            AND b2.id <> b1.id 
            AND (SELECT COUNT(*) FROM public.library_book_copies c2 WHERE c2.book_id = b2.id) > 0
      );

    -- 3. For any remaining books with 0 physical copies in library_book_copies, generate physical copies!
    FOR v_book IN (
        SELECT b.id, b.school_id, b.title, b.author, b.isbn13, b.rack_location, b.shelf_location, b.purchase_price, b.supplier, COALESCE(b.total_copies, 3) as req_copies
        FROM public.library_books b
        WHERE b.archived_at IS NULL 
          AND (SELECT COUNT(*) FROM public.library_book_copies c WHERE c.book_id = b.id AND c.archived_at IS NULL) = 0
    ) LOOP
        -- Select sample students from this school
        SELECT id INTO v_student_1 FROM public.profiles WHERE school_id = v_book.school_id AND role = 'student' ORDER BY created_at ASC LIMIT 1;
        SELECT id INTO v_student_2 FROM public.profiles WHERE school_id = v_book.school_id AND role = 'student' ORDER BY created_at DESC LIMIT 1;
        SELECT id INTO v_student_3 FROM public.profiles WHERE school_id = v_book.school_id AND role = 'student' OFFSET 1 LIMIT 1;

        v_prefix := COALESCE(NULLIF(UPPER(SUBSTRING(REGEXP_REPLACE(v_book.title, '[^a-zA-Z0-9]', '', 'g') FROM 1 FOR 6)), ''), 'BK');
        
        FOR v_copy_idx IN 1..GREATEST(1, LEAST(v_book.req_copies, 10)) LOOP
            v_acc_no := v_prefix || '-' || LPAD(v_copy_idx::text, 3, '0');
            -- Ensure accession number uniqueness
            WHILE EXISTS (SELECT 1 FROM public.library_book_copies WHERE school_id = v_book.school_id AND accession_number = v_acc_no) LOOP
                v_copy_idx := v_copy_idx + 1;
                v_acc_no := v_prefix || '-' || LPAD(v_copy_idx::text, 3, '0');
            END LOOP;

            v_barcode := 'BC' || LPAD((FLOOR(RANDOM() * 89999999) + 10000000)::text, 8, '0');
            v_qr := 'QR' || LPAD((FLOOR(RANDOM() * 89999999) + 10000000)::text, 8, '0');
            
            IF v_copy_idx = 1 THEN
                v_cond := 'EXCELLENT';
                v_status := 'AVAILABLE';
                v_borrower_id := NULL;
                v_borrowed_at := NULL;
                v_due_date := NULL;
            ELSIF v_copy_idx = 2 AND v_student_1 IS NOT NULL THEN
                v_cond := 'GOOD';
                v_status := 'ISSUED';
                v_borrower_id := v_student_1;
                v_borrowed_at := NOW() - INTERVAL '5 days';
                v_due_date := NOW() + INTERVAL '9 days';
            ELSIF v_copy_idx = 3 AND v_student_2 IS NOT NULL THEN
                v_cond := 'FAIR';
                v_status := 'OVERDUE';
                v_borrower_id := v_student_2;
                v_borrowed_at := NOW() - INTERVAL '20 days';
                v_due_date := NOW() - INTERVAL '6 days';
            ELSE
                v_cond := 'GOOD';
                v_status := 'AVAILABLE';
                v_borrower_id := NULL;
                v_borrowed_at := NULL;
                v_due_date := NULL;
            END IF;

            INSERT INTO public.library_book_copies (
                book_id, school_id, accession_number, barcode, qr_code, copy_number,
                condition, status, location, rack, shelf, purchase_price, supplier,
                acquisition_date, current_borrower_id, borrowed_at, due_date,
                created_at, updated_at
            ) VALUES (
                v_book.id, v_book.school_id, v_acc_no, v_barcode, v_qr, v_copy_idx,
                v_cond, v_status, COALESCE(v_book.rack_location || ' - ' || v_book.shelf_location, 'Rack 1 - Shelf 1'),
                COALESCE(v_book.rack_location, 'Rack 1'), COALESCE(v_book.shelf_location, 'Shelf 1'),
                COALESCE(v_book.purchase_price, 299.00), COALESCE(v_book.supplier, 'Institutional Publisher'),
                CURRENT_DATE - (v_copy_idx * 15), v_borrower_id, v_borrowed_at, v_due_date,
                NOW(), NOW()
            )
            ON CONFLICT DO NOTHING;
        END LOOP;
    END LOOP;

    -- 4. Global synchronization of all copy counts across the catalogue
    UPDATE public.library_books b
    SET 
        total_copies = COALESCE((
            SELECT COUNT(*) FROM public.library_book_copies c 
            WHERE c.book_id = b.id AND c.archived_at IS NULL
        ), 0),
        available_copies = COALESCE((
            SELECT COUNT(*) FROM public.library_book_copies c 
            WHERE c.book_id = b.id AND c.archived_at IS NULL AND c.status = 'AVAILABLE'
        ), 0),
        issued_copies = COALESCE((
            SELECT COUNT(*) FROM public.library_book_copies c 
            WHERE c.book_id = b.id AND c.archived_at IS NULL AND c.status IN ('ISSUED', 'OVERDUE')
        ), 0),
        reserved_copies = COALESCE((
            SELECT COUNT(*) FROM public.library_book_copies c 
            WHERE c.book_id = b.id AND c.archived_at IS NULL AND c.status = 'RESERVED'
        ), 0),
        updated_at = NOW()
    WHERE b.archived_at IS NULL;

END $$;
