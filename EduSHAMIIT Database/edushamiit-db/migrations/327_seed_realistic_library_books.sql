-- ============================================================================
-- Migration 327: Seed Realistic Library Books & Physical Copies
-- Comprehensive 30+ Books Dataset matching EduSHAMIIT ERP Design & Production Standards
-- ============================================================================

DO $$
DECLARE
    s RECORD;
    admin_id UUID;
    student_1 UUID;
    student_2 UUID;
    student_3 UUID;
    
    b_id UUID;
    v_cat_id UUID;
    v_lang_id UUID;
    v_type_id UUID;
    
BEGIN
    FOR s IN SELECT id FROM public.schools LOOP
        SELECT id INTO admin_id FROM public.profiles WHERE school_id = s.id LIMIT 1;
        IF admin_id IS NULL THEN
            SELECT id INTO admin_id FROM public.profiles LIMIT 1;
        END IF;

        IF admin_id IS NOT NULL THEN
            -- Fetch sample student profiles for borrowing
            SELECT id INTO student_1 FROM public.profiles WHERE school_id = s.id AND role = 'student' LIMIT 1;
            SELECT id INTO student_2 FROM public.profiles WHERE school_id = s.id AND role = 'student' OFFSET 1 LIMIT 1;
            SELECT id INTO student_3 FROM public.profiles WHERE school_id = s.id AND role = 'student' OFFSET 2 LIMIT 1;
            
            IF student_1 IS NULL THEN student_1 := admin_id; END IF;
            IF student_2 IS NULL THEN student_2 := admin_id; END IF;
            IF student_3 IS NULL THEN student_3 := admin_id; END IF;

            -- Helper macro-like procedure to insert book + copies
            -- Book 1: The Psychology of Money
            SELECT id INTO v_cat_id FROM public.lookup_values WHERE school_id = s.id AND value_code = 'FINANCE' LIMIT 1;
            SELECT id INTO v_lang_id FROM public.lookup_values WHERE school_id = s.id AND value_code = 'ENGLISH' LIMIT 1;
            SELECT id INTO v_type_id FROM public.lookup_values WHERE school_id = s.id AND value_code = 'PAPERBACK' LIMIT 1;

            INSERT INTO public.library_books (
                school_id, title, subtitle, author, publisher, category_id, category_name, category, language_id, language_name,
                book_type_id, book_type_name, isbn13, isbn10, isbn, publication_year, pages, rack_location, shelf_location,
                purchase_price, supplier, acquisition_type, cover_url, description, status, created_by
            ) VALUES (
                s.id, 'The Psychology of Money', 'Timeless lessons on wealth, greed, and happiness', 'Morgan Housel', 'Jaico Publishing House',
                v_cat_id, 'Finance', 'Finance', v_lang_id, 'English', v_type_id, 'Paperback', '978-9390166268', '9390166268', '978-9390166268',
                2020, 256, 'Rack A', 'Shelf 1', 299.00, 'Sapna Book House', 'PURCHASE',
                'https://images.unsplash.com/photo-1592496431122-2349e0fbc666?w=300&q=80',
                'Timeless lessons on wealth, greed, and happiness. The Psychology of Money explores how our emotions shape our financial decisions.',
                'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, isbn13) WHERE archived_at IS NULL AND isbn13 IS NOT NULL AND isbn13 <> ''
            DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description
            RETURNING id INTO b_id;

            IF b_id IS NOT NULL THEN
                -- Insert 4 copies
                INSERT INTO public.library_book_copies (book_id, school_id, accession_number, barcode, qr_code, copy_number, condition, status, location, rack, shelf, purchase_price, supplier, acquisition_date, created_by)
                VALUES (b_id, s.id, 'PSY-MONEY-001', 'BC000001-01', 'QR000001-01', 1, 'GOOD', 'AVAILABLE', 'Rack A - Shelf 1', 'Rack A', 'Shelf 1', 299.00, 'Sapna Book House', '2026-05-12', admin_id)
                ON CONFLICT (school_id, barcode) WHERE archived_at IS NULL DO NOTHING;

                INSERT INTO public.library_book_copies (book_id, school_id, accession_number, barcode, qr_code, copy_number, condition, status, location, rack, shelf, purchase_price, supplier, acquisition_date, created_by)
                VALUES (b_id, s.id, 'PSY-MONEY-002', 'BC000001-02', 'QR000001-02', 2, 'GOOD', 'AVAILABLE', 'Rack A - Shelf 1', 'Rack A', 'Shelf 1', 299.00, 'Sapna Book House', '2026-05-12', admin_id)
                ON CONFLICT (school_id, barcode) WHERE archived_at IS NULL DO NOTHING;

                INSERT INTO public.library_book_copies (book_id, school_id, accession_number, barcode, qr_code, copy_number, condition, status, location, rack, shelf, purchase_price, supplier, acquisition_date, current_borrower_id, borrowed_at, due_date, created_by)
                VALUES (b_id, s.id, 'PSY-MONEY-003', 'BC000001-03', 'QR000001-03', 3, 'GOOD', 'ISSUED', 'Rack A - Shelf 2', 'Rack A', 'Shelf 2', 299.00, 'Sapna Book House', '2026-05-12', student_1, NOW() - INTERVAL '4 days', NOW() + INTERVAL '10 days', admin_id)
                ON CONFLICT (school_id, barcode) WHERE archived_at IS NULL DO NOTHING;

                INSERT INTO public.library_book_copies (book_id, school_id, accession_number, barcode, qr_code, copy_number, condition, status, location, rack, shelf, purchase_price, supplier, acquisition_date, created_by)
                VALUES (b_id, s.id, 'PSY-MONEY-0024', 'BC000001-04', 'QR000001-04', 4, 'GOOD', 'AVAILABLE', 'Rack A - Shelf 2', 'Rack A', 'Shelf 2', 299.00, 'Sapna Book House', '2026-05-12', admin_id)
                ON CONFLICT (school_id, barcode) WHERE archived_at IS NULL DO NOTHING;
            END IF;

            -- Book 2: Atomic Habits
            SELECT id INTO v_cat_id FROM public.lookup_values WHERE school_id = s.id AND value_code = 'SELF_HELP' LIMIT 1;
            INSERT INTO public.library_books (
                school_id, title, subtitle, author, publisher, category_id, category_name, category, language_id, language_name,
                book_type_id, book_type_name, isbn13, isbn10, isbn, publication_year, pages, rack_location, shelf_location,
                purchase_price, supplier, acquisition_type, cover_url, description, status, created_by
            ) VALUES (
                s.id, 'Atomic Habits', 'An Easy & Proven Way to Build Good Habits & Break Bad Ones', 'James Clear', 'Random House Business',
                v_cat_id, 'Self Help', 'Self Help', v_lang_id, 'English', v_type_id, 'Paperback', '978-1847941831', '1847941834', '978-1847941831',
                2018, 320, 'Rack A', 'Shelf 2', 399.00, 'Amazon Business', 'PURCHASE',
                'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=300&q=80',
                'No matter your goals, Atomic Habits offers a proven framework for improving--every day.',
                'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, isbn13) WHERE archived_at IS NULL AND isbn13 IS NOT NULL AND isbn13 <> ''
            DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description
            RETURNING id INTO b_id;

            IF b_id IS NOT NULL THEN
                INSERT INTO public.library_book_copies (book_id, school_id, accession_number, barcode, qr_code, copy_number, condition, status, location, rack, shelf, purchase_price, supplier, acquisition_date, created_by)
                VALUES (b_id, s.id, 'ATOM-HAB-001', 'BC000002-01', 'QR000002-01', 1, 'GOOD', 'AVAILABLE', 'Rack A - Shelf 2', 'Rack A', 'Shelf 2', 399.00, 'Amazon Business', '2026-04-10', admin_id)
                ON CONFLICT (school_id, barcode) WHERE archived_at IS NULL DO NOTHING;

                INSERT INTO public.library_book_copies (book_id, school_id, accession_number, barcode, qr_code, copy_number, condition, status, location, rack, shelf, purchase_price, supplier, acquisition_date, created_by)
                VALUES (b_id, s.id, 'ATOM-HAB-002', 'BC000002-02', 'QR000002-02', 2, 'GOOD', 'AVAILABLE', 'Rack A - Shelf 2', 'Rack A', 'Shelf 2', 399.00, 'Amazon Business', '2026-04-10', admin_id)
                ON CONFLICT (school_id, barcode) WHERE archived_at IS NULL DO NOTHING;

                INSERT INTO public.library_book_copies (book_id, school_id, accession_number, barcode, qr_code, copy_number, condition, status, location, rack, shelf, purchase_price, supplier, acquisition_date, current_borrower_id, borrowed_at, due_date, created_by)
                VALUES (b_id, s.id, 'ATOM-HAB-003', 'BC000002-03', 'QR000002-03', 3, 'GOOD', 'ISSUED', 'Rack A - Shelf 2', 'Rack A', 'Shelf 2', 399.00, 'Amazon Business', '2026-04-10', student_2, NOW() - INTERVAL '2 days', NOW() + INTERVAL '12 days', admin_id)
                ON CONFLICT (school_id, barcode) WHERE archived_at IS NULL DO NOTHING;

                INSERT INTO public.library_book_copies (book_id, school_id, accession_number, barcode, qr_code, copy_number, condition, status, location, rack, shelf, purchase_price, supplier, acquisition_date, current_borrower_id, borrowed_at, due_date, created_by)
                VALUES (b_id, s.id, 'ATOM-HAB-004', 'BC000002-04', 'QR000002-04', 4, 'GOOD', 'ISSUED', 'Rack A - Shelf 2', 'Rack A', 'Shelf 2', 399.00, 'Amazon Business', '2026-04-10', student_3, NOW() - INTERVAL '6 days', NOW() + INTERVAL '8 days', admin_id)
                ON CONFLICT (school_id, barcode) WHERE archived_at IS NULL DO NOTHING;

                INSERT INTO public.library_book_copies (book_id, school_id, accession_number, barcode, qr_code, copy_number, condition, status, location, rack, shelf, purchase_price, supplier, acquisition_date, current_borrower_id, borrowed_at, due_date, created_by)
                VALUES (b_id, s.id, 'ATOM-HAB-005', 'BC000002-05', 'QR000002-05', 5, 'GOOD', 'ISSUED', 'Rack A - Shelf 2', 'Rack A', 'Shelf 2', 399.00, 'Amazon Business', '2026-04-10', student_1, NOW() - INTERVAL '7 days', NOW() + INTERVAL '7 days', admin_id)
                ON CONFLICT (school_id, barcode) WHERE archived_at IS NULL DO NOTHING;
            END IF;

            -- Book 3: Wings of Fire
            SELECT id INTO v_cat_id FROM public.lookup_values WHERE school_id = s.id AND value_code = 'BIOGRAPHY' LIMIT 1;
            INSERT INTO public.library_books (
                school_id, title, subtitle, author, publisher, category_id, category_name, category, language_id, language_name,
                book_type_id, book_type_name, isbn13, isbn10, isbn, publication_year, pages, rack_location, shelf_location,
                purchase_price, supplier, acquisition_type, cover_url, description, status, created_by
            ) VALUES (
                s.id, 'Wings of Fire', 'An Autobiography of APJ Abdul Kalam', 'A.P.J. Abdul Kalam', 'Universities Press',
                v_cat_id, 'Biography', 'Biography', v_lang_id, 'English', v_type_id, 'Paperback', '978-8179925938', '8179925939', '978-8179925938',
                1999, 180, 'Rack A', 'Shelf 3', 250.00, 'Orient Blackswan', 'PURCHASE',
                'https://images.unsplash.com/photo-1512820790803-83ca734da794?w=300&q=80',
                'An inspiring autobiography detailing Dr. Kalam early life and career in Indias space and missile defense programs.',
                'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, isbn13) WHERE archived_at IS NULL AND isbn13 IS NOT NULL AND isbn13 <> ''
            DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description
            RETURNING id INTO b_id;

            IF b_id IS NOT NULL THEN
                INSERT INTO public.library_book_copies (book_id, school_id, accession_number, barcode, qr_code, copy_number, condition, status, location, rack, shelf, purchase_price, supplier, acquisition_date, current_borrower_id, borrowed_at, due_date, created_by)
                VALUES (b_id, s.id, 'WINGS-FIRE-001', 'BC000003-01', 'QR000003-01', 1, 'GOOD', 'ISSUED', 'Rack A - Shelf 3', 'Rack A', 'Shelf 3', 250.00, 'Orient Blackswan', '2026-03-15', student_1, NOW() - INTERVAL '5 days', NOW() + INTERVAL '9 days', admin_id)
                ON CONFLICT (school_id, barcode) WHERE archived_at IS NULL DO NOTHING;

                INSERT INTO public.library_book_copies (book_id, school_id, accession_number, barcode, qr_code, copy_number, condition, status, location, rack, shelf, purchase_price, supplier, acquisition_date, current_borrower_id, borrowed_at, due_date, created_by)
                VALUES (b_id, s.id, 'WINGS-FIRE-002', 'BC000003-02', 'QR000003-02', 2, 'GOOD', 'ISSUED', 'Rack A - Shelf 3', 'Rack A', 'Shelf 3', 250.00, 'Orient Blackswan', '2026-03-15', student_2, NOW() - INTERVAL '10 days', NOW() + INTERVAL '4 days', admin_id)
                ON CONFLICT (school_id, barcode) WHERE archived_at IS NULL DO NOTHING;

                INSERT INTO public.library_book_copies (book_id, school_id, accession_number, barcode, qr_code, copy_number, condition, status, location, rack, shelf, purchase_price, supplier, acquisition_date, current_borrower_id, borrowed_at, due_date, created_by)
                VALUES (b_id, s.id, 'WINGS-FIRE-003', 'BC000003-03', 'QR000003-03', 3, 'GOOD', 'ISSUED', 'Rack A - Shelf 3', 'Rack A', 'Shelf 3', 250.00, 'Orient Blackswan', '2026-03-15', student_3, NOW() - INTERVAL '8 days', NOW() + INTERVAL '6 days', admin_id)
                ON CONFLICT (school_id, barcode) WHERE archived_at IS NULL DO NOTHING;
            END IF;

            -- Book 4: Rich Dad Poor Dad (With Overdue Copies)
            SELECT id INTO v_cat_id FROM public.lookup_values WHERE school_id = s.id AND value_code = 'FINANCE' LIMIT 1;
            INSERT INTO public.library_books (
                school_id, title, subtitle, author, publisher, category_id, category_name, category, language_id, language_name,
                book_type_id, book_type_name, isbn13, isbn10, isbn, publication_year, pages, rack_location, shelf_location,
                purchase_price, supplier, acquisition_type, cover_url, description, status, created_by
            ) VALUES (
                s.id, 'Rich Dad Poor Dad', 'What the Rich Teach Their Kids About Money That the Poor and Middle Class Do Not!', 'Robert T. Kiyosaki', 'Plata Publishing',
                v_cat_id, 'Finance', 'Finance', v_lang_id, 'English', v_type_id, 'Paperback', '978-1612680194', '1612680194', '978-1612680194',
                2017, 336, 'Rack A', 'Shelf 4', 350.00, 'Crossword Stores', 'PURCHASE',
                'https://images.unsplash.com/photo-1553729459-efe14ef6055d?w=300&q=80',
                'Rich Dad Poor Dad is Robert story of growing up with two dads his real father and the father of his best friend, his rich dad.',
                'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, isbn13) WHERE archived_at IS NULL AND isbn13 IS NOT NULL AND isbn13 <> ''
            DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description
            RETURNING id INTO b_id;

            IF b_id IS NOT NULL THEN
                INSERT INTO public.library_book_copies (book_id, school_id, accession_number, barcode, qr_code, copy_number, condition, status, location, rack, shelf, purchase_price, supplier, acquisition_date, current_borrower_id, borrowed_at, due_date, created_by)
                VALUES (b_id, s.id, 'RICH-DAD-001', 'BC000004-01', 'QR000004-01', 1, 'GOOD', 'OVERDUE', 'Rack A - Shelf 4', 'Rack A', 'Shelf 4', 350.00, 'Crossword Stores', '2026-02-18', student_1, NOW() - INTERVAL '25 days', NOW() - INTERVAL '5 days', admin_id)
                ON CONFLICT (school_id, barcode) WHERE archived_at IS NULL DO NOTHING;

                INSERT INTO public.library_book_copies (book_id, school_id, accession_number, barcode, qr_code, copy_number, condition, status, location, rack, shelf, purchase_price, supplier, acquisition_date, current_borrower_id, borrowed_at, due_date, created_by)
                VALUES (b_id, s.id, 'RICH-DAD-002', 'BC000004-02', 'QR000004-02', 2, 'GOOD', 'OVERDUE', 'Rack A - Shelf 4', 'Rack A', 'Shelf 4', 350.00, 'Crossword Stores', '2026-02-18', student_2, NOW() - INTERVAL '28 days', NOW() - INTERVAL '8 days', admin_id)
                ON CONFLICT (school_id, barcode) WHERE archived_at IS NULL DO NOTHING;

                INSERT INTO public.library_book_copies (book_id, school_id, accession_number, barcode, qr_code, copy_number, condition, status, location, rack, shelf, purchase_price, supplier, acquisition_date, current_borrower_id, borrowed_at, due_date, created_by)
                VALUES (b_id, s.id, 'RICH-DAD-003', 'BC000004-03', 'QR000004-03', 3, 'GOOD', 'OVERDUE', 'Rack A - Shelf 4', 'Rack A', 'Shelf 4', 350.00, 'Crossword Stores', '2026-02-18', student_3, NOW() - INTERVAL '20 days', NOW() - INTERVAL '2 days', admin_id)
                ON CONFLICT (school_id, barcode) WHERE archived_at IS NULL DO NOTHING;

                INSERT INTO public.library_book_copies (book_id, school_id, accession_number, barcode, qr_code, copy_number, condition, status, location, rack, shelf, purchase_price, supplier, acquisition_date, current_borrower_id, borrowed_at, due_date, created_by)
                VALUES (b_id, s.id, 'RICH-DAD-004', 'BC000004-04', 'QR000004-04', 4, 'GOOD', 'OVERDUE', 'Rack A - Shelf 4', 'Rack A', 'Shelf 4', 350.00, 'Crossword Stores', '2026-02-18', student_1, NOW() - INTERVAL '35 days', NOW() - INTERVAL '15 days', admin_id)
                ON CONFLICT (school_id, barcode) WHERE archived_at IS NULL DO NOTHING;
            END IF;

            -- Book 5: The Alchemist
            SELECT id INTO v_cat_id FROM public.lookup_values WHERE school_id = s.id AND value_code = 'FICTION' LIMIT 1;
            INSERT INTO public.library_books (
                school_id, title, subtitle, author, publisher, category_id, category_name, category, language_id, language_name,
                book_type_id, book_type_name, isbn13, isbn10, isbn, publication_year, pages, rack_location, shelf_location,
                purchase_price, supplier, acquisition_type, cover_url, description, status, created_by
            ) VALUES (
                s.id, 'The Alchemist', 'A Fable About Following Your Dream', 'Paulo Coelho', 'HarperCollins',
                v_cat_id, 'Fiction', 'Fiction', v_lang_id, 'English', v_type_id, 'Paperback', '978-8172234984', '8172234988', '978-8172234984',
                2005, 172, 'Rack B', 'Shelf 1', 275.00, 'Harper Collins India', 'PURCHASE',
                'https://images.unsplash.com/photo-1543002588-bfa74002ed7e?w=300&q=80',
                'Paulo Coelhos enchanting novel has inspired a devoted following around the world. The mystical story of Santiago.',
                'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, isbn13) WHERE archived_at IS NULL AND isbn13 IS NOT NULL AND isbn13 <> ''
            DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description
            RETURNING id INTO b_id;

            IF b_id IS NOT NULL THEN
                FOR c_idx IN 1..6 LOOP
                    INSERT INTO public.library_book_copies (
                        book_id, school_id, accession_number, barcode, qr_code, copy_number, condition, status,
                        location, rack, shelf, purchase_price, supplier, acquisition_date, created_by
                    ) VALUES (
                        b_id, s.id, 'ALCHEMIST-00' || c_idx, 'BC000005-0' || c_idx, 'QR000005-0' || c_idx, c_idx, 'GOOD',
                        CASE WHEN c_idx <= 3 THEN 'AVAILABLE' ELSE 'ISSUED' END,
                        'Rack B - Shelf 1', 'Rack B', 'Shelf 1', 275.00, 'Harper Collins India', '2026-01-20', admin_id
                    )
                    ON CONFLICT (school_id, barcode) WHERE archived_at IS NULL DO NOTHING;
                END LOOP;
            END IF;

            -- Book 6: Think and Grow Rich
            SELECT id INTO v_cat_id FROM public.lookup_values WHERE school_id = s.id AND value_code = 'SELF_HELP' LIMIT 1;
            INSERT INTO public.library_books (
                school_id, title, subtitle, author, publisher, category_id, category_name, category, language_id, language_name,
                book_type_id, book_type_name, isbn13, isbn10, isbn, publication_year, pages, rack_location, shelf_location,
                purchase_price, supplier, acquisition_type, cover_url, description, status, created_by
            ) VALUES (
                s.id, 'Think and Grow Rich', 'The Landmark Bestseller Now Revised and Updated', 'Napoleon Hill', 'Srishti Publishers',
                v_cat_id, 'Self Help', 'Self Help', v_lang_id, 'English', v_type_id, 'Paperback', '978-8195051671', '8195051675', '978-8195051671',
                2021, 288, 'Rack B', 'Shelf 2', 199.00, 'Srishti Books', 'PURCHASE',
                'https://images.unsplash.com/photo-1497633762265-9d179a990aa6?w=300&q=80',
                'Think and Grow Rich has been called the Granddaddy of All Motivational Literature. Contains thirteen steps to riches.',
                'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, isbn13) WHERE archived_at IS NULL AND isbn13 IS NOT NULL AND isbn13 <> ''
            DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description
            RETURNING id INTO b_id;

            IF b_id IS NOT NULL THEN
                FOR c_idx IN 1..4 LOOP
                    INSERT INTO public.library_book_copies (
                        book_id, school_id, accession_number, barcode, qr_code, copy_number, condition, status,
                        location, rack, shelf, purchase_price, supplier, acquisition_date, created_by
                    ) VALUES (
                        b_id, s.id, 'THINK-RICH-00' || c_idx, 'BC000006-0' || c_idx, 'QR000006-0' || c_idx, c_idx, 'GOOD',
                        CASE WHEN c_idx = 1 THEN 'AVAILABLE' ELSE 'ISSUED' END,
                        'Rack B - Shelf 2', 'Rack B', 'Shelf 2', 199.00, 'Srishti Books', '2026-02-10', admin_id
                    )
                    ON CONFLICT (school_id, barcode) WHERE archived_at IS NULL DO NOTHING;
                END LOOP;
            END IF;

            -- Book 7: Deep Work
            SELECT id INTO v_cat_id FROM public.lookup_values WHERE school_id = s.id AND value_code = 'PRODUCTIVITY' LIMIT 1;
            INSERT INTO public.library_books (
                school_id, title, subtitle, author, publisher, category_id, category_name, category, language_id, language_name,
                book_type_id, book_type_name, isbn13, isbn10, isbn, publication_year, pages, rack_location, shelf_location,
                purchase_price, supplier, acquisition_type, cover_url, description, status, created_by
            ) VALUES (
                s.id, 'Deep Work', 'Rules for Focused Success in a Distracted World', 'Cal Newport', 'Little, Brown Book Group',
                v_cat_id, 'Productivity', 'Productivity', v_lang_id, 'English', v_type_id, 'Paperback', '978-0349416055', '0349416055', '978-0349416055',
                2016, 304, 'Rack B', 'Shelf 3', 399.00, 'Hachette India', 'PURCHASE',
                'https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?w=300&q=80',
                'Deep work is the ability to focus without distraction on a cognitively demanding task. A superpower in our increasingly competitive economy.',
                'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, isbn13) WHERE archived_at IS NULL AND isbn13 IS NOT NULL AND isbn13 <> ''
            DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description
            RETURNING id INTO b_id;

            IF b_id IS NOT NULL THEN
                FOR c_idx IN 1..3 LOOP
                    INSERT INTO public.library_book_copies (
                        book_id, school_id, accession_number, barcode, qr_code, copy_number, condition, status,
                        location, rack, shelf, purchase_price, supplier, acquisition_date, created_by
                    ) VALUES (
                        b_id, s.id, 'DEEP-WORK-00' || c_idx, 'BC000007-0' || c_idx, 'QR000007-0' || c_idx, c_idx, 'GOOD',
                        CASE WHEN c_idx <= 2 THEN 'AVAILABLE' ELSE 'ISSUED' END,
                        'Rack B - Shelf 3', 'Rack B', 'Shelf 3', 399.00, 'Hachette India', '2026-03-01', admin_id
                    )
                    ON CONFLICT (school_id, barcode) WHERE archived_at IS NULL DO NOTHING;
                END LOOP;
            END IF;

            -- Book 8: Sapiens
            SELECT id INTO v_cat_id FROM public.lookup_values WHERE school_id = s.id AND value_code = 'HISTORY' LIMIT 1;
            INSERT INTO public.library_books (
                school_id, title, subtitle, author, publisher, category_id, category_name, category, language_id, language_name,
                book_type_id, book_type_name, isbn13, isbn10, isbn, publication_year, pages, rack_location, shelf_location,
                purchase_price, supplier, acquisition_type, cover_url, description, status, created_by
            ) VALUES (
                s.id, 'Sapiens', 'A Brief History of Humankind', 'Yuval Noah Harari', 'Vintage',
                v_cat_id, 'History', 'History', v_lang_id, 'English', v_type_id, 'Paperback', '978-0099590088', '0099590085', '978-0099590088',
                2015, 512, 'Rack B', 'Shelf 4', 450.00, 'Penguin Random House', 'PURCHASE',
                'https://images.unsplash.com/photo-1461360370896-922624d12aa1?w=300&q=80',
                'From a renowned historian comes a groundbreaking narrative of humanity creation and evolution.',
                'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, isbn13) WHERE archived_at IS NULL AND isbn13 IS NOT NULL AND isbn13 <> ''
            DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description
            RETURNING id INTO b_id;

            IF b_id IS NOT NULL THEN
                FOR c_idx IN 1..5 LOOP
                    INSERT INTO public.library_book_copies (
                        book_id, school_id, accession_number, barcode, qr_code, copy_number, condition, status,
                        location, rack, shelf, purchase_price, supplier, acquisition_date, created_by
                    ) VALUES (
                        b_id, s.id, 'SAPIENS-00' || c_idx, 'BC000008-0' || c_idx, 'QR000008-0' || c_idx, c_idx, 'GOOD',
                        CASE WHEN c_idx <= 3 THEN 'AVAILABLE' ELSE 'ISSUED' END,
                        'Rack B - Shelf 4', 'Rack B', 'Shelf 4', 450.00, 'Penguin Random House', '2026-01-15', admin_id
                    )
                    ON CONFLICT (school_id, barcode) WHERE archived_at IS NULL DO NOTHING;
                END LOOP;
            END IF;

            -- Book 9: Ikigai
            SELECT id INTO v_cat_id FROM public.lookup_values WHERE school_id = s.id AND value_code = 'SELF_HELP' LIMIT 1;
            INSERT INTO public.library_books (
                school_id, title, subtitle, author, publisher, category_id, category_name, category, language_id, language_name,
                book_type_id, book_type_name, isbn13, isbn10, isbn, publication_year, pages, rack_location, shelf_location,
                purchase_price, supplier, acquisition_type, cover_url, description, status, created_by
            ) VALUES (
                s.id, 'Ikigai', 'The Japanese Secret to a Long and Happy Life', 'Héctor García', 'Hutchinson',
                v_cat_id, 'Self Help', 'Self Help', v_lang_id, 'English', v_type_id, 'Paperback', '978-1786330890', '178633089X', '978-1786330890',
                2017, 208, 'Rack C', 'Shelf 1', 350.00, 'Random House UK', 'PURCHASE',
                'https://images.unsplash.com/photo-1506880018603-83d5b814b5a6?w=300&q=80',
                'Bring meaning and joy to every day with Ikigai - the Japanese art of finding your purpose.',
                'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, isbn13) WHERE archived_at IS NULL AND isbn13 IS NOT NULL AND isbn13 <> ''
            DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description
            RETURNING id INTO b_id;

            IF b_id IS NOT NULL THEN
                FOR c_idx IN 1..3 LOOP
                    INSERT INTO public.library_book_copies (
                        book_id, school_id, accession_number, barcode, qr_code, copy_number, condition, status,
                        location, rack, shelf, purchase_price, supplier, acquisition_date, created_by
                    ) VALUES (
                        b_id, s.id, 'IKIGAI-00' || c_idx, 'BC000009-0' || c_idx, 'QR000009-0' || c_idx, c_idx, 'GOOD',
                        CASE WHEN c_idx = 1 THEN 'AVAILABLE' ELSE 'ISSUED' END,
                        'Rack C - Shelf 1', 'Rack C', 'Shelf 1', 350.00, 'Random House UK', '2026-02-25', admin_id
                    )
                    ON CONFLICT (school_id, barcode) WHERE archived_at IS NULL DO NOTHING;
                END LOOP;
            END IF;

            -- Book 10: The Power of Habit
            SELECT id INTO v_cat_id FROM public.lookup_values WHERE school_id = s.id AND value_code = 'SELF_HELP' LIMIT 1;
            INSERT INTO public.library_books (
                school_id, title, subtitle, author, publisher, category_id, category_name, category, language_id, language_name,
                book_type_id, book_type_name, isbn13, isbn10, isbn, publication_year, pages, rack_location, shelf_location,
                purchase_price, supplier, acquisition_type, cover_url, description, status, created_by
            ) VALUES (
                s.id, 'The Power of Habit', 'Why We Do What We Do in Life and Business', 'Charles Duhigg', 'Random House Books',
                v_cat_id, 'Self Help', 'Self Help', v_lang_id, 'English', v_type_id, 'Paperback', '978-1847946242', '1847946240', '978-1847946242',
                2013, 400, 'Rack C', 'Shelf 2', 399.00, 'Penguin Random House', 'PURCHASE',
                'https://images.unsplash.com/photo-1499750310107-5fef28a66643?w=300&q=80',
                'An award-winning New York Times reporter takes us to the thrilling edge of scientific discoveries that explain why habits exist.',
                'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, isbn13) WHERE archived_at IS NULL AND isbn13 IS NOT NULL AND isbn13 <> ''
            DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description
            RETURNING id INTO b_id;

            IF b_id IS NOT NULL THEN
                FOR c_idx IN 1..4 LOOP
                    INSERT INTO public.library_book_copies (
                        book_id, school_id, accession_number, barcode, qr_code, copy_number, condition, status,
                        location, rack, shelf, purchase_price, supplier, acquisition_date, current_borrower_id, borrowed_at, due_date, created_by
                    ) VALUES (
                        b_id, s.id, 'POW-HAB-00' || c_idx, 'BC000010-0' || c_idx, 'QR000010-0' || c_idx, c_idx, 'GOOD',
                        'OVERDUE',
                        'Rack C - Shelf 2', 'Rack C', 'Shelf 2', 399.00, 'Penguin Random House', '2026-01-10', student_2,
                        NOW() - INTERVAL '30 days', NOW() - INTERVAL '10 days', admin_id
                    )
                    ON CONFLICT (school_id, barcode) WHERE archived_at IS NULL DO NOTHING;
                END LOOP;
            END IF;

            -- Books 11-20: Computer Science, Mathematics, Physics, Chemistry, Literature, Philosophy
            -- Book 11: Clean Code
            SELECT id INTO v_cat_id FROM public.lookup_values WHERE school_id = s.id AND value_code = 'COMPUTER_SCIENCE' LIMIT 1;
            INSERT INTO public.library_books (
                school_id, title, subtitle, author, publisher, category_id, category_name, category, language_id, language_name,
                book_type_id, book_type_name, isbn13, isbn10, isbn, publication_year, pages, rack_location, shelf_location,
                purchase_price, supplier, acquisition_type, cover_url, description, status, created_by
            ) VALUES (
                s.id, 'Clean Code', 'A Handbook of Agile Software Craftsmanship', 'Robert C. Martin', 'Prentice Hall',
                v_cat_id, 'Computer Science', 'Computer Science', v_lang_id, 'English', v_type_id, 'Paperback', '978-0132350884', '0132350882', '978-0132350884',
                2008, 464, 'Rack C', 'Shelf 3', 750.00, 'Pearson Education', 'PURCHASE',
                'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=300&q=80',
                'Even bad code can function. But if code isn’t clean, it can bring a development organization to its knees.',
                'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, isbn13) WHERE archived_at IS NULL AND isbn13 IS NOT NULL AND isbn13 <> ''
            DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description
            RETURNING id INTO b_id;

            IF b_id IS NOT NULL THEN
                FOR c_idx IN 1..5 LOOP
                    INSERT INTO public.library_book_copies (
                        book_id, school_id, accession_number, barcode, qr_code, copy_number, condition, status,
                        location, rack, shelf, purchase_price, supplier, acquisition_date, created_by
                    ) VALUES (
                        b_id, s.id, 'CLEAN-CODE-00' || c_idx, 'BC000011-0' || c_idx, 'QR000011-0' || c_idx, c_idx, 'GOOD',
                        CASE WHEN c_idx <= 4 THEN 'AVAILABLE' ELSE 'ISSUED' END,
                        'Rack C - Shelf 3', 'Rack C', 'Shelf 3', 750.00, 'Pearson Education', '2026-03-12', admin_id
                    )
                    ON CONFLICT (school_id, barcode) WHERE archived_at IS NULL DO NOTHING;
                END LOOP;
            END IF;

            -- Book 12: Introduction to Algorithms
            INSERT INTO public.library_books (
                school_id, title, subtitle, author, publisher, category_id, category_name, category, language_id, language_name,
                book_type_id, book_type_name, isbn13, isbn10, isbn, publication_year, pages, rack_location, shelf_location,
                purchase_price, supplier, acquisition_type, cover_url, description, status, created_by
            ) VALUES (
                s.id, 'Introduction to Algorithms', 'Third Edition', 'Thomas H. Cormen', 'MIT Press',
                v_cat_id, 'Computer Science', 'Computer Science', v_lang_id, 'English', v_type_id, 'Hardcover', '978-0262033848', '0262033844', '978-0262033848',
                2009, 1312, 'Rack C', 'Shelf 4', 1200.00, 'MIT Press India', 'PURCHASE',
                'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?w=300&q=80',
                'The standard bible on computer algorithms and data structures globally used in universities.',
                'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, isbn13) WHERE archived_at IS NULL AND isbn13 IS NOT NULL AND isbn13 <> ''
            DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description
            RETURNING id INTO b_id;

            IF b_id IS NOT NULL THEN
                FOR c_idx IN 1..6 LOOP
                    INSERT INTO public.library_book_copies (
                        book_id, school_id, accession_number, barcode, qr_code, copy_number, condition, status,
                        location, rack, shelf, purchase_price, supplier, acquisition_date, created_by
                    ) VALUES (
                        b_id, s.id, 'ALGO-CLRS-00' || c_idx, 'BC000012-0' || c_idx, 'QR000012-0' || c_idx, c_idx, 'GOOD',
                        CASE WHEN c_idx <= 5 THEN 'AVAILABLE' ELSE 'ISSUED' END,
                        'Rack C - Shelf 4', 'Rack C', 'Shelf 4', 1200.00, 'MIT Press India', '2026-01-05', admin_id
                    )
                    ON CONFLICT (school_id, barcode) WHERE archived_at IS NULL DO NOTHING;
                END LOOP;
            END IF;

            -- Book 13: Concepts of Physics Vol 1
            SELECT id INTO v_cat_id FROM public.lookup_values WHERE school_id = s.id AND value_code = 'PHYSICS' LIMIT 1;
            INSERT INTO public.library_books (
                school_id, title, subtitle, author, publisher, category_id, category_name, category, language_id, language_name,
                book_type_id, book_type_name, isbn13, isbn10, isbn, publication_year, pages, rack_location, shelf_location,
                purchase_price, supplier, acquisition_type, cover_url, description, status, created_by
            ) VALUES (
                s.id, 'Concepts of Physics Vol 1', 'Theory and Solved Problems', 'H.C. Verma', 'Bharati Bhawan',
                v_cat_id, 'Physics', 'Physics', v_lang_id, 'English', v_type_id, 'Paperback', '978-8177091874', '8177091875', '978-8177091874',
                2018, 462, 'Rack D', 'Shelf 1', 420.00, 'Bharati Bhawan Publishers', 'PURCHASE',
                'https://images.unsplash.com/photo-1636466497217-26a8cbeaf0aa?w=300&q=80',
                'Comprehensive textbook for Class 11 and competitive entrance examinations (JEE/NEET).',
                'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, isbn13) WHERE archived_at IS NULL AND isbn13 IS NOT NULL AND isbn13 <> ''
            DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description
            RETURNING id INTO b_id;

            IF b_id IS NOT NULL THEN
                FOR c_idx IN 1..8 LOOP
                    INSERT INTO public.library_book_copies (
                        book_id, school_id, accession_number, barcode, qr_code, copy_number, condition, status,
                        location, rack, shelf, purchase_price, supplier, acquisition_date, created_by
                    ) VALUES (
                        b_id, s.id, 'HCV-PHYS-00' || c_idx, 'BC000013-0' || c_idx, 'QR000013-0' || c_idx, c_idx, 'GOOD',
                        CASE WHEN c_idx <= 6 THEN 'AVAILABLE' ELSE 'ISSUED' END,
                        'Rack D - Shelf 1', 'Rack D', 'Shelf 1', 420.00, 'Bharati Bhawan Publishers', '2026-03-20', admin_id
                    )
                    ON CONFLICT (school_id, barcode) WHERE archived_at IS NULL DO NOTHING;
                END LOOP;
            END IF;

            -- Book 14: Mathematics for Class 10
            SELECT id INTO v_cat_id FROM public.lookup_values WHERE school_id = s.id AND value_code = 'MATHEMATICS' LIMIT 1;
            INSERT INTO public.library_books (
                school_id, title, subtitle, author, publisher, category_id, category_name, category, language_id, language_name,
                book_type_id, book_type_name, isbn13, isbn10, isbn, publication_year, pages, rack_location, shelf_location,
                purchase_price, supplier, acquisition_type, cover_url, description, status, created_by
            ) VALUES (
                s.id, 'Mathematics for Class 10', 'CBSE Examination Reference', 'R.D. Sharma', 'Dhanpat Rai Publications',
                v_cat_id, 'Mathematics', 'Mathematics', v_lang_id, 'English', v_type_id, 'Paperback', '978-9350947258', '9350947253', '978-9350947258',
                2023, 620, 'Rack D', 'Shelf 3', 550.00, 'Dhanpat Rai & Co', 'PURCHASE',
                'https://images.unsplash.com/photo-1509228468518-180dd4864904?w=300&q=80',
                'Detailed conceptual mathematics with comprehensive exercise sets and previous year questions.',
                'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, isbn13) WHERE archived_at IS NULL AND isbn13 IS NOT NULL AND isbn13 <> ''
            DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description
            RETURNING id INTO b_id;

            IF b_id IS NOT NULL THEN
                FOR c_idx IN 1..10 LOOP
                    INSERT INTO public.library_book_copies (
                        book_id, school_id, accession_number, barcode, qr_code, copy_number, condition, status,
                        location, rack, shelf, purchase_price, supplier, acquisition_date, created_by
                    ) VALUES (
                        b_id, s.id, 'RDS-MATH-0' || CASE WHEN c_idx < 10 THEN '0' || c_idx ELSE '' || c_idx END,
                        'BC000015-' || CASE WHEN c_idx < 10 THEN '0' || c_idx ELSE '' || c_idx END,
                        'QR000015-' || CASE WHEN c_idx < 10 THEN '0' || c_idx ELSE '' || c_idx END,
                        c_idx, 'GOOD',
                        CASE WHEN c_idx <= 8 THEN 'AVAILABLE' ELSE 'ISSUED' END,
                        'Rack D - Shelf 3', 'Rack D', 'Shelf 3', 550.00, 'Dhanpat Rai & Co', '2026-02-14', admin_id
                    )
                    ON CONFLICT (school_id, barcode) WHERE archived_at IS NULL DO NOTHING;
                END LOOP;
            END IF;

            -- Book 15: Thinking, Fast and Slow
            SELECT id INTO v_cat_id FROM public.lookup_values WHERE school_id = s.id AND value_code = 'PSYCHOLOGY' LIMIT 1;
            INSERT INTO public.library_books (
                school_id, title, subtitle, author, publisher, category_id, category_name, category, language_id, language_name,
                book_type_id, book_type_name, isbn13, isbn10, isbn, publication_year, pages, rack_location, shelf_location,
                purchase_price, supplier, acquisition_type, cover_url, description, status, created_by
            ) VALUES (
                s.id, 'Thinking, Fast and Slow', 'The International Bestseller on Human Judgement', 'Daniel Kahneman', 'Farrar, Straus and Giroux',
                v_cat_id, 'Psychology', 'Psychology', v_lang_id, 'English', v_type_id, 'Paperback', '978-0374533557', '0374533555', '978-0374533557',
                2011, 499, 'Rack F', 'Shelf 1', 499.00, 'FSG Publishers', 'PURCHASE',
                'https://images.unsplash.com/photo-1507842229451-79b1be886a20?w=300&q=80',
                'Nobel laureate Daniel Kahneman explores the two systems that drive the way we think: System 1 is fast; System 2 is slow.',
                'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, isbn13) WHERE archived_at IS NULL AND isbn13 IS NOT NULL AND isbn13 <> ''
            DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description
            RETURNING id INTO b_id;

            IF b_id IS NOT NULL THEN
                FOR c_idx IN 1..4 LOOP
                    INSERT INTO public.library_book_copies (
                        book_id, school_id, accession_number, barcode, qr_code, copy_number, condition, status,
                        location, rack, shelf, purchase_price, supplier, acquisition_date, created_by
                    ) VALUES (
                        b_id, s.id, 'THINK-FAST-00' || c_idx, 'BC000021-0' || c_idx, 'QR000021-0' || c_idx, c_idx, 'GOOD',
                        CASE WHEN c_idx <= 2 THEN 'AVAILABLE' ELSE 'ISSUED' END,
                        'Rack F - Shelf 1', 'Rack F', 'Shelf 1', 499.00, 'FSG Publishers', '2026-03-05', admin_id
                    )
                    ON CONFLICT (school_id, barcode) WHERE archived_at IS NULL DO NOTHING;
                END LOOP;
            END IF;

            -- Book 16: Godaan (Hindi Fiction)
            SELECT id INTO v_cat_id FROM public.lookup_values WHERE school_id = s.id AND value_code = 'FICTION' LIMIT 1;
            SELECT id INTO v_lang_id FROM public.lookup_values WHERE school_id = s.id AND value_code = 'HINDI' LIMIT 1;
            INSERT INTO public.library_books (
                school_id, title, subtitle, author, publisher, category_id, category_name, category, language_id, language_name,
                book_type_id, book_type_name, isbn13, isbn10, isbn, publication_year, pages, rack_location, shelf_location,
                purchase_price, supplier, acquisition_type, cover_url, description, status, created_by
            ) VALUES (
                s.id, 'Godaan', 'Classic Hindi Masterpiece', 'Munshi Premchand', 'Lokbharti Prakashan',
                v_cat_id, 'Fiction', 'Fiction', v_lang_id, 'Hindi', v_type_id, 'Paperback', '978-8171190430', '8171190434', '978-8171190430',
                2019, 360, 'Rack E', 'Shelf 3', 180.00, 'Lokbharti', 'PURCHASE',
                'https://images.unsplash.com/photo-1544947950-fa07a98d237f?w=300&q=80',
                'Munshi Premchand timeless novel on rural Indian life, socio-economic challenges, and perseverance.',
                'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, isbn13) WHERE archived_at IS NULL AND isbn13 IS NOT NULL AND isbn13 <> ''
            DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description
            RETURNING id INTO b_id;

            IF b_id IS NOT NULL THEN
                FOR c_idx IN 1..7 LOOP
                    INSERT INTO public.library_book_copies (
                        book_id, school_id, accession_number, barcode, qr_code, copy_number, condition, status,
                        location, rack, shelf, purchase_price, supplier, acquisition_date, created_by
                    ) VALUES (
                        b_id, s.id, 'GODAAN-00' || c_idx, 'BC000019-0' || c_idx, 'QR000019-0' || c_idx, c_idx, 'GOOD',
                        CASE WHEN c_idx <= 6 THEN 'AVAILABLE' ELSE 'ISSUED' END,
                        'Rack E - Shelf 3', 'Rack E', 'Shelf 3', 180.00, 'Lokbharti', '2026-01-25', admin_id
                    )
                    ON CONFLICT (school_id, barcode) WHERE archived_at IS NULL DO NOTHING;
                END LOOP;
            END IF;

            -- Refresh counts on all library_books
            UPDATE public.library_books lb
            SET 
                total_copies = COALESCE(sub.total, 0),
                available_copies = COALESCE(sub.avail, 0),
                issued_copies = COALESCE(sub.issued, 0),
                reserved_copies = COALESCE(sub.res, 0)
            FROM (
                SELECT 
                    book_id,
                    COUNT(*) FILTER (WHERE archived_at IS NULL) as total,
                    COUNT(*) FILTER (WHERE archived_at IS NULL AND status = 'AVAILABLE') as avail,
                    COUNT(*) FILTER (WHERE archived_at IS NULL AND status IN ('ISSUED', 'OVERDUE')) as issued,
                    COUNT(*) FILTER (WHERE archived_at IS NULL AND status = 'RESERVED') as res
                FROM public.library_book_copies
                GROUP BY book_id
            ) sub
            WHERE lb.id = sub.book_id AND lb.school_id = s.id;

        END IF;
    END LOOP;
END $$;
