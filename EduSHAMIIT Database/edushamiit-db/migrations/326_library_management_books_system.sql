-- ============================================================================
-- Migration 326: Library Management Books & Physical Copies System
-- Multi-tenant, Enterprise Catalogue & Inventory Engine with Lookup Integration,
-- Accession/Barcode/QR Tracking, Copy Counts Auto-Sync, and Full Lifecycle Auditing
-- ============================================================================

-- 1. Enhance library_books Table
CREATE TABLE IF NOT EXISTS public.library_books (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    subtitle TEXT,
    isbn10 VARCHAR(30),
    isbn13 VARCHAR(30),
    isbn TEXT, -- Legacy compatibility
    description TEXT,
    author TEXT NOT NULL,
    co_authors TEXT[],
    publisher TEXT,
    edition VARCHAR(50),
    publication_year INTEGER,
    pages INTEGER,
    cover_url TEXT,
    category_id UUID REFERENCES public.lookup_values(id) ON DELETE SET NULL,
    category_name VARCHAR(150),
    category TEXT, -- Legacy compatibility
    language_id UUID REFERENCES public.lookup_values(id) ON DELETE SET NULL,
    language_name VARCHAR(100) DEFAULT 'English',
    book_type_id UUID REFERENCES public.lookup_values(id) ON DELETE SET NULL,
    book_type_name VARCHAR(100) DEFAULT 'Paperback',
    rack_location VARCHAR(100),
    shelf_location TEXT,
    keywords TEXT[],
    tags TEXT[],
    supplier TEXT,
    purchase_date DATE,
    purchase_price DECIMAL(10,2) DEFAULT 0.00,
    invoice_ref TEXT,
    acquisition_type VARCHAR(50) DEFAULT 'PURCHASE',
    total_copies INTEGER NOT NULL DEFAULT 0,
    available_copies INTEGER NOT NULL DEFAULT 0,
    issued_copies INTEGER NOT NULL DEFAULT 0,
    reserved_copies INTEGER NOT NULL DEFAULT 0,
    is_digital BOOLEAN DEFAULT FALSE,
    digital_url TEXT,
    status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, ARCHIVED
    created_by UUID REFERENCES public.profiles(id),
    updated_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    archived_at TIMESTAMPTZ NULL,
    archived_by UUID REFERENCES public.profiles(id)
);

-- Add any missing columns to existing library_books table
DO $$
BEGIN
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS subtitle TEXT;
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS isbn10 VARCHAR(30);
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS isbn13 VARCHAR(30);
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS description TEXT;
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS co_authors TEXT[];
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS publisher TEXT;
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS edition VARCHAR(50);
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS publication_year INTEGER;
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS pages INTEGER;
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS category_id UUID REFERENCES public.lookup_values(id) ON DELETE SET NULL;
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS category_name VARCHAR(150);
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS language_id UUID REFERENCES public.lookup_values(id) ON DELETE SET NULL;
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS language_name VARCHAR(100) DEFAULT 'English';
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS book_type_id UUID REFERENCES public.lookup_values(id) ON DELETE SET NULL;
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS book_type_name VARCHAR(100) DEFAULT 'Paperback';
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS rack_location VARCHAR(100);
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS keywords TEXT[];
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS tags TEXT[];
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS supplier TEXT;
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS purchase_date DATE;
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS purchase_price DECIMAL(10,2) DEFAULT 0.00;
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS invoice_ref TEXT;
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS acquisition_type VARCHAR(50) DEFAULT 'PURCHASE';
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS issued_copies INTEGER NOT NULL DEFAULT 0;
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS reserved_copies INTEGER NOT NULL DEFAULT 0;
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE';
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.profiles(id);
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES public.profiles(id);
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ NULL;
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS archived_by UUID REFERENCES public.profiles(id);
END $$;

-- 2. Create library_book_copies Table (Physical Copies)
CREATE TABLE IF NOT EXISTS public.library_book_copies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    book_id UUID NOT NULL REFERENCES public.library_books(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    accession_number VARCHAR(100) NOT NULL,
    barcode VARCHAR(100) NOT NULL,
    qr_code VARCHAR(100) NOT NULL,
    copy_number INTEGER NOT NULL DEFAULT 1,
    condition VARCHAR(50) NOT NULL DEFAULT 'GOOD', -- NEW, GOOD, FAIR, WORN, DAMAGED, UNDER_REPAIR
    status VARCHAR(50) NOT NULL DEFAULT 'AVAILABLE', -- AVAILABLE, ISSUED, RESERVED, OVERDUE, LOST, DAMAGED, MAINTENANCE, ARCHIVED
    library_name VARCHAR(150) DEFAULT 'Main Campus Library',
    location VARCHAR(100),
    rack VARCHAR(100),
    shelf VARCHAR(100),
    acquisition_date DATE,
    supplier TEXT,
    purchase_price DECIMAL(10,2) DEFAULT 0.00,
    notes TEXT,
    current_borrower_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    borrowed_at TIMESTAMPTZ NULL,
    due_date TIMESTAMPTZ NULL,
    last_issued_date TIMESTAMPTZ NULL,
    last_returned_date TIMESTAMPTZ NULL,
    created_by UUID REFERENCES public.profiles(id),
    updated_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    archived_at TIMESTAMPTZ NULL,
    archived_by UUID REFERENCES public.profiles(id)
);

-- 3. Indexes & Constraints
CREATE INDEX IF NOT EXISTS idx_library_books_school_status 
    ON public.library_books (school_id, status) 
    WHERE archived_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_library_books_category 
    ON public.library_books (school_id, category_name) 
    WHERE archived_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_library_books_author 
    ON public.library_books (school_id, author) 
    WHERE archived_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_library_books_created_at 
    ON public.library_books (school_id, created_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS uq_library_books_school_isbn13
    ON public.library_books (school_id, isbn13)
    WHERE archived_at IS NULL AND isbn13 IS NOT NULL AND isbn13 <> '';

CREATE INDEX IF NOT EXISTS idx_library_book_copies_book 
    ON public.library_book_copies (book_id, status) 
    WHERE archived_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_library_book_copies_school 
    ON public.library_book_copies (school_id, status) 
    WHERE archived_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_library_book_copies_school_accession
    ON public.library_book_copies (school_id, accession_number)
    WHERE archived_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_library_book_copies_school_barcode
    ON public.library_book_copies (school_id, barcode)
    WHERE archived_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_library_book_copies_school_qr
    ON public.library_book_copies (school_id, qr_code)
    WHERE archived_at IS NULL;


-- 4. Sync Trigger: Auto-update book copy counts when copies change
CREATE OR REPLACE FUNCTION public.fn_sync_library_book_copy_counts()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_book_id UUID;
    v_total INT := 0;
    v_avail INT := 0;
    v_issued INT := 0;
    v_res INT := 0;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_book_id := OLD.book_id;
    ELSE
        v_book_id := NEW.book_id;
    END IF;

    SELECT 
        COUNT(*) FILTER (WHERE archived_at IS NULL),
        COUNT(*) FILTER (WHERE archived_at IS NULL AND status = 'AVAILABLE'),
        COUNT(*) FILTER (WHERE archived_at IS NULL AND status IN ('ISSUED', 'OVERDUE')),
        COUNT(*) FILTER (WHERE archived_at IS NULL AND status = 'RESERVED')
    INTO v_total, v_avail, v_issued, v_res
    FROM public.library_book_copies
    WHERE book_id = v_book_id;

    UPDATE public.library_books
    SET 
        total_copies = COALESCE(v_total, 0),
        available_copies = COALESCE(v_avail, 0),
        issued_copies = COALESCE(v_issued, 0),
        reserved_copies = COALESCE(v_res, 0),
        updated_at = NOW()
    WHERE id = v_book_id;

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_library_book_copy_counts ON public.library_book_copies;
CREATE TRIGGER trg_sync_library_book_copy_counts
    AFTER INSERT OR UPDATE OR DELETE ON public.library_book_copies
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_sync_library_book_copy_counts();


-- 5. Seed System Lookups for Library System
DO $$
DECLARE
    s RECORD;
    admin_id UUID;
    v_key_id UUID;
BEGIN
    FOR s IN SELECT id FROM public.schools LOOP
        SELECT id INTO admin_id FROM public.profiles WHERE school_id = s.id LIMIT 1;
        IF admin_id IS NULL THEN
            SELECT id INTO admin_id FROM public.profiles LIMIT 1;
        END IF;

        IF admin_id IS NOT NULL THEN
            -- 1. BOOK_CATEGORY
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Book Category', 'BOOK_CATEGORY', 'Standard classifications and genres for library cataloguing.', 'SYSTEM', 'auto_stories_outlined', 'ACTIVE', admin_id)
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name
            RETURNING id INTO v_key_id;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Finance', 'FINANCE', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Self Help', 'SELF_HELP', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Biography', 'BIOGRAPHY', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Fiction', 'FICTION', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, 'Productivity', 'PRODUCTIVITY', 'ACTIVE', 5, admin_id),
                    (v_key_id, s.id, 'History', 'HISTORY', 'ACTIVE', 6, admin_id),
                    (v_key_id, s.id, 'Science', 'SCIENCE', 'ACTIVE', 7, admin_id),
                    (v_key_id, s.id, 'Mathematics', 'MATHEMATICS', 'ACTIVE', 8, admin_id),
                    (v_key_id, s.id, 'Physics', 'PHYSICS', 'ACTIVE', 9, admin_id),
                    (v_key_id, s.id, 'Chemistry', 'CHEMISTRY', 'ACTIVE', 10, admin_id),
                    (v_key_id, s.id, 'English', 'ENGLISH', 'ACTIVE', 11, admin_id),
                    (v_key_id, s.id, 'Computer Science', 'COMPUTER_SCIENCE', 'ACTIVE', 12, admin_id),
                    (v_key_id, s.id, 'Reference', 'REFERENCE', 'ACTIVE', 13, admin_id),
                    (v_key_id, s.id, 'Philosophy', 'PHILOSOPHY', 'ACTIVE', 14, admin_id),
                    (v_key_id, s.id, 'Psychology', 'PSYCHOLOGY', 'ACTIVE', 15, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;
            END IF;

            -- 2. BOOK_LANGUAGE
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Book Language', 'BOOK_LANGUAGE', 'Primary languages for published library materials.', 'SYSTEM', 'translate_outlined', 'ACTIVE', admin_id)
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name
            RETURNING id INTO v_key_id;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'English', 'ENGLISH', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Hindi', 'HINDI', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Sanskrit', 'SANSKRIT', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Spanish', 'SPANISH', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, 'French', 'FRENCH', 'ACTIVE', 5, admin_id),
                    (v_key_id, s.id, 'German', 'GERMAN', 'ACTIVE', 6, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;
            END IF;

            -- 3. BOOK_TYPE
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Book Type / Format', 'BOOK_TYPE', 'Physical format and binding of library catalogue records.', 'SYSTEM', 'book_outlined', 'ACTIVE', admin_id)
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name
            RETURNING id INTO v_key_id;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Paperback', 'PAPERBACK', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Hardcover', 'HARDCOVER', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Textbook', 'TEXTBOOK', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Reference Book', 'REFERENCE', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, 'Journal / Periodical', 'JOURNAL', 'ACTIVE', 5, admin_id),
                    (v_key_id, s.id, 'E-Book / Digital', 'E_BOOK', 'ACTIVE', 6, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;
            END IF;

            -- 4. BOOK_CONDITION
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Book Physical Condition', 'BOOK_CONDITION', 'Physical quality and wear state of inventory copies.', 'SYSTEM', 'verified_outlined', 'ACTIVE', admin_id)
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name
            RETURNING id INTO v_key_id;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'New / Mint', 'NEW', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Good', 'GOOD', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Fair', 'FAIR', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Worn', 'WORN', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, 'Damaged', 'DAMAGED', 'ACTIVE', 5, admin_id),
                    (v_key_id, s.id, 'Under Repair', 'UNDER_REPAIR', 'ACTIVE', 6, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;
            END IF;

            -- 5. ACQUISITION_TYPE
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Acquisition Method', 'ACQUISITION_TYPE', 'Procurement and acquisition origins of catalogue books.', 'SYSTEM', 'shopping_bag_outlined', 'ACTIVE', admin_id)
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name
            RETURNING id INTO v_key_id;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Direct Purchase', 'PURCHASE', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Donation / Gift', 'DONATION', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Institutional Grant', 'GRANT', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Exchange', 'EXCHANGE', 'ACTIVE', 4, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;
            END IF;
        END IF;
    END LOOP;
END $$;


-- 6. Register Library Module in Lookup Usage Registry
INSERT INTO public.lookup_usage_registry (school_id, lookup_key_id, module_name, table_name, record_count)
SELECT 
    lk.school_id,
    lk.id,
    'Library',
    'library_books',
    0
FROM public.lookup_keys lk
WHERE lk.key_code IN ('BOOK_CATEGORY', 'BOOK_LANGUAGE', 'BOOK_TYPE', 'BOOK_CONDITION', 'ACQUISITION_TYPE')
ON CONFLICT (school_id, lookup_key_id, lookup_value_id, module_name, table_name) DO NOTHING;
