-- ============================================================================
-- Migration 335: Multi-Digital Assets, Live Streaming & Resource Playlists
-- Multi-file uploads (PDF/ePub/MP3/MP4), Live Stream URLs (HLS/Web/YouTube),
-- Asset Ordering, and Playlist Metadata
-- ============================================================================

-- 1. Extend public.library_digital_files with multi-asset attributes
ALTER TABLE public.library_digital_files ADD COLUMN IF NOT EXISTS title TEXT;
ALTER TABLE public.library_digital_files ADD COLUMN IF NOT EXISTS source_type VARCHAR(50) DEFAULT 'FILE_UPLOAD'; -- FILE_UPLOAD, DIRECT_LINK, LIVE_STREAM, YOUTUBE_STREAM, EXTERNAL_LINK
ALTER TABLE public.library_digital_files ADD COLUMN IF NOT EXISTS is_live_stream BOOLEAN DEFAULT FALSE;
ALTER TABLE public.library_digital_files ADD COLUMN IF NOT EXISTS sort_order INT DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_lib_digital_files_sort ON public.library_digital_files(book_id, sort_order ASC);


-- 2. Update fn_library_list_books to order and aggregate rich digital assets
CREATE OR REPLACE FUNCTION public.fn_library_list_books(
    p_school_id UUID,
    p_search TEXT DEFAULT NULL,
    p_category TEXT DEFAULT NULL,
    p_author TEXT DEFAULT NULL,
    p_publisher TEXT DEFAULT NULL,
    p_language TEXT DEFAULT NULL,
    p_book_type TEXT DEFAULT NULL,
    p_rack TEXT DEFAULT NULL,
    p_status TEXT DEFAULT 'ACTIVE',
    p_availability TEXT DEFAULT 'ALL',
    p_year_min INT DEFAULT NULL,
    p_year_max INT DEFAULT NULL,
    p_sort_by TEXT DEFAULT 'title',
    p_sort_order TEXT DEFAULT 'ASC',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_offset INT;
    v_total INT;
    v_items JSONB;
    v_total_pages INT;
    v_sql TEXT;
    v_where TEXT := 'b.school_id = $1';
    v_order_col TEXT;
    v_order_dir TEXT;
BEGIN
    v_offset := (GREATEST(p_page, 1) - 1) * GREATEST(p_page_size, 1);

    -- Status condition
    IF UPPER(p_status) = 'ARCHIVED' THEN
        v_where := v_where || ' AND b.archived_at IS NOT NULL';
    ELSE
        v_where := v_where || ' AND b.archived_at IS NULL';
    END IF;

    -- Search filter
    IF p_search IS NOT NULL AND TRIM(p_search) != '' THEN
        v_where := v_where || format(' AND (b.title ILIKE %L OR b.author ILIKE %L OR b.isbn13 ILIKE %L OR b.isbn10 ILIKE %L OR b.subject ILIKE %L OR EXISTS (SELECT 1 FROM public.library_book_copies c WHERE c.book_id = b.id AND (c.barcode ILIKE %L OR c.accession_number ILIKE %L)))',
            '%' || TRIM(p_search) || '%',
            '%' || TRIM(p_search) || '%',
            '%' || TRIM(p_search) || '%',
            '%' || TRIM(p_search) || '%',
            '%' || TRIM(p_search) || '%',
            '%' || TRIM(p_search) || '%',
            '%' || TRIM(p_search) || '%'
        );
    END IF;

    -- Category filter
    IF p_category IS NOT NULL AND TRIM(p_category) != '' AND UPPER(p_category) != 'ALL' AND UPPER(p_category) != 'ALL CATEGORIES' THEN
        v_where := v_where || format(' AND (b.category_name ILIKE %L)', '%' || TRIM(p_category) || '%');
    END IF;

    -- Author filter
    IF p_author IS NOT NULL AND TRIM(p_author) != '' AND UPPER(p_author) != 'ALL' AND UPPER(p_author) != 'ALL AUTHORS' THEN
        v_where := v_where || format(' AND (b.author ILIKE %L)', '%' || TRIM(p_author) || '%');
    END IF;

    -- Publisher filter
    IF p_publisher IS NOT NULL AND TRIM(p_publisher) != '' AND UPPER(p_publisher) != 'ALL' AND UPPER(p_publisher) != 'ALL PUBLISHERS' THEN
        v_where := v_where || format(' AND (b.publisher ILIKE %L)', '%' || TRIM(p_publisher) || '%');
    END IF;

    -- Language filter
    IF p_language IS NOT NULL AND TRIM(p_language) != '' AND UPPER(p_language) != 'ALL' THEN
        v_where := v_where || format(' AND (b.language_name ILIKE %L)', '%' || TRIM(p_language) || '%');
    END IF;

    -- Book type / Digital Format filter
    IF p_book_type IS NOT NULL AND TRIM(p_book_type) != '' AND UPPER(p_book_type) != 'ALL' THEN
        IF UPPER(p_book_type) = 'DIGITAL' OR UPPER(p_book_type) = 'ALL DIGITAL' THEN
            v_where := v_where || ' AND b.is_digital = TRUE';
        ELSIF UPPER(p_book_type) = 'PHYSICAL' THEN
            v_where := v_where || ' AND (b.is_digital IS NOT TRUE OR b.book_type_name ILIKE ''%Physical%'')';
        ELSE
            v_where := v_where || format(' AND (b.book_type_name ILIKE %L)', '%' || TRIM(p_book_type) || '%');
        END IF;
    END IF;

    -- Rack location filter
    IF p_rack IS NOT NULL AND TRIM(p_rack) != '' AND UPPER(p_rack) != 'ALL' THEN
        v_where := v_where || format(' AND (b.rack_location ILIKE %L)', '%' || TRIM(p_rack) || '%');
    END IF;

    -- Publication Year range
    IF p_year_min IS NOT NULL THEN
        v_where := v_where || format(' AND b.publication_year >= %s', p_year_min);
    END IF;
    IF p_year_max IS NOT NULL THEN
        v_where := v_where || format(' AND b.publication_year <= %s', p_year_max);
    END IF;

    -- Availability filter
    IF UPPER(p_availability) = 'AVAILABLE' THEN
        v_where := v_where || ' AND (b.available_copies > 0 OR b.is_digital = TRUE)';
    ELSIF UPPER(p_availability) = 'ISSUED' THEN
        v_where := v_where || ' AND b.issued_copies > 0';
    ELSIF UPPER(p_availability) = 'OVERDUE' THEN
        v_where := v_where || ' AND EXISTS (SELECT 1 FROM public.library_book_copies c WHERE c.book_id = b.id AND c.archived_at IS NULL AND (c.status = ''OVERDUE'' OR (c.status = ''ISSUED'' AND c.due_date IS NOT NULL AND c.due_date < CURRENT_DATE)))';
    ELSIF UPPER(p_availability) = 'OUT_OF_STOCK' THEN
        v_where := v_where || ' AND b.available_copies = 0 AND b.is_digital IS NOT TRUE';
    END IF;

    -- Sort column map
    CASE LOWER(COALESCE(p_sort_by, 'title'))
        WHEN 'author' THEN v_order_col := 'b.author';
        WHEN 'category' THEN v_order_col := 'b.category_name';
        WHEN 'publication_year' THEN v_order_col := 'b.publication_year';
        WHEN 'total_copies' THEN v_order_col := 'b.total_copies';
        WHEN 'available_copies' THEN v_order_col := 'b.available_copies';
        WHEN 'rating' THEN v_order_col := 'b.rating';
        WHEN 'reads' THEN v_order_col := 'b.read_count';
        WHEN 'created_at' THEN v_order_col := 'b.created_at';
        ELSE v_order_col := 'b.title';
    END CASE;

    IF LOWER(COALESCE(p_sort_order, 'asc')) = 'desc' THEN
        v_order_dir := 'DESC';
    ELSE
        v_order_dir := 'ASC';
    END IF;

    -- 1. Get Count
    EXECUTE 'SELECT COUNT(*) FROM public.library_books b WHERE ' || v_where
    USING p_school_id
    INTO v_total;

    v_total_pages := GREATEST(CEIL(v_total::NUMERIC / GREATEST(p_page_size, 1)), 1);

    -- 2. Get Paginated Items as JSONB
    v_sql := format(
        'SELECT COALESCE(jsonb_agg(row_to_json(t)), ''[]''::jsonb)
         FROM (
             SELECT
                 b.id,
                 b.school_id,
                 b.title,
                 b.subtitle,
                 b.author,
                 b.co_authors,
                 b.publisher,
                 b.edition,
                 b.publication_year,
                 b.pages,
                 b.description,
                 b.isbn10,
                 b.isbn13,
                 b.isbn,
                 b.category_id,
                 b.category_name,
                 b.language_id,
                 b.language_name,
                 b.book_type_id,
                 b.book_type_name,
                 b.rack_location,
                 b.shelf_location,
                 b.cover_url,
                 b.preview_url,
                 b.total_copies,
                 b.available_copies,
                 b.issued_copies,
                 b.reserved_copies,
                 b.is_digital,
                 b.digital_visibility,
                 b.access_mode,
                 b.requires_permission,
                 b.allowed_roles,
                 b.allowed_grades,
                 b.allowed_departments,
                 b.default_access_duration_days,
                 b.allow_notes,
                 b.allow_highlights,
                 b.allow_bookmarks,
                 b.allow_copy_text,
                 b.allow_screenshots,
                 b.max_concurrent_devices,
                 b.rating,
                 b.total_reviews,
                 b.view_count,
                 b.read_count,
                 b.listen_count,
                 b.watch_count,
                 b.total_reading_seconds,
                 b.total_listening_seconds,
                 b.total_watching_seconds,
                 b.subject,
                 b.grade_level,
                 b.curriculum,
                 b.difficulty_level,
                 b.age_group,
                 b.published_at,
                 b.status,
                 b.created_at,
                 b.updated_at,
                 b.archived_at,
                 (
                     SELECT c.barcode FROM public.library_book_copies c 
                     WHERE c.book_id = b.id AND c.archived_at IS NULL 
                     ORDER BY c.copy_number ASC LIMIT 1
                 ) AS primary_barcode,
                 (
                     SELECT c.accession_number FROM public.library_book_copies c 
                     WHERE c.book_id = b.id AND c.archived_at IS NULL 
                     ORDER BY c.copy_number ASC LIMIT 1
                 ) AS primary_accession_number,
                 (
                     SELECT COUNT(*) FROM public.library_book_copies c 
                     WHERE c.book_id = b.id AND c.archived_at IS NULL 
                       AND (c.status = ''OVERDUE'' OR (c.status = ''ISSUED'' AND c.due_date IS NOT NULL AND c.due_date < CURRENT_DATE))
                 ) AS overdue_copies_count,
                 (
                     SELECT COALESCE(jsonb_agg(row_to_json(df)), ''[]''::jsonb)
                     FROM (
                         SELECT * FROM public.library_digital_files 
                         WHERE book_id = b.id 
                         ORDER BY is_primary DESC, sort_order ASC, created_at ASC
                     ) df
                 ) AS digital_files,
                 b.supplier,
                 b.purchase_price,
                 b.acquisition_type,
                 b.invoice_ref,
                 b.purchase_date
             FROM public.library_books b
             WHERE %s
             ORDER BY %s %s, b.id ASC
             LIMIT %s OFFSET %s
         ) t',
        v_where,
        v_order_col,
        v_order_dir,
        GREATEST(p_page_size, 1),
        v_offset
    );

    EXECUTE v_sql
    USING p_school_id
    INTO v_items;

    RETURN jsonb_build_object(
        'items', COALESCE(v_items, '[]'::jsonb),
        'pagination', jsonb_build_object(
            'total', v_total,
            'page', p_page,
            'page_size', p_page_size,
            'total_pages', v_total_pages,
            'has_next', p_page < v_total_pages,
            'has_prev', p_page > 1
        )
    );
END;
$$;


-- 3. Seed Realistic Multi-Asset Real Data for immediate testing
DO $$
DECLARE
    v_school_id UUID;
    v_admin_id UUID;
    v_book1_id UUID;
    v_book2_id UUID;
BEGIN
    SELECT id INTO v_school_id FROM public.schools LIMIT 1;
    IF v_school_id IS NULL THEN
        RETURN;
    END IF;

    SELECT id INTO v_admin_id FROM public.profiles WHERE school_id = v_school_id LIMIT 1;

    -- Book 1: Multi-Format Quantum Physics (eBook + Audio Lecture + Video + Live Stream)
    SELECT id INTO v_book1_id FROM public.library_books 
    WHERE school_id = v_school_id AND (isbn13 = '978-0198520115' OR title ILIKE '%Quantum Mechanics%')
    LIMIT 1;

    IF v_book1_id IS NULL THEN
        INSERT INTO public.library_books (
            school_id, title, subtitle, author, publisher, category_name, language_name, book_type_name,
            publication_year, pages, description, isbn13, total_copies, available_copies, is_digital,
            digital_visibility, access_mode, requires_permission, rating, total_reviews, read_count,
            listen_count, watch_count, subject, grade_level, difficulty_level,
            cover_url, created_by, updated_by
        ) VALUES (
            v_school_id,
            'Principles of Quantum Mechanics & Modern Physics',
            'Comprehensive Digital Study Edition with Live Classroom Lectures',
            'Prof. R. Shankar & Richard Feynman',
            'Oxford University Press',
            'Science',
            'English',
            'eBook (PDF/ePub/HTML)',
            2026,
            480,
            'Comprehensive text covering wave mechanics, Schrödinger equation, harmonic oscillators, angular momentum, and spin systems with live streaming audio-visual masterclasses.',
            '978-0198520115',
            10,
            10,
            TRUE,
            'PUBLIC',
            'ALL',
            FALSE,
            4.9,
            38,
            142,
            88,
            64,
            'Physics',
            'Class 12 / Undergraduate',
            'Advanced',
            'https://images.unsplash.com/photo-1532094349884-543bc11b234d?w=400&q=80',
            v_admin_id,
            v_admin_id
        ) RETURNING id INTO v_book1_id;
    END IF;

    -- Delete old files for clean reseed
    DELETE FROM public.library_digital_files WHERE book_id = v_book1_id;

    -- Attach 4 diverse assets to Book 1:
    -- Asset 1: Main PDF
    INSERT INTO public.library_digital_files (
        book_id, school_id, file_type, source_type, title, storage_key, file_name, mime_type,
        file_size_bytes, page_count, stream_url, is_primary, is_live_stream, sort_order
    ) VALUES (
        v_book1_id, v_school_id, 'EBOOK_PDF', 'FILE_UPLOAD',
        'Vol 1: Wave Mechanics & State Vectors (Complete Text)',
        'quantum_physics_vol1.pdf', 'quantum_physics_vol1.pdf', 'application/pdf',
        14800000, 240, 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        TRUE, FALSE, 1
    );

    -- Asset 2: Audio Lecture Chapter 1
    INSERT INTO public.library_digital_files (
        book_id, school_id, file_type, source_type, title, storage_key, file_name, mime_type,
        file_size_bytes, duration_seconds, stream_url, is_primary, is_live_stream, sort_order
    ) VALUES (
        v_book1_id, v_school_id, 'AUDIO_MP3', 'DIRECT_LINK',
        'Audio Masterclass: Ch 1 - The Wave-Particle Duality',
        'audio_lecture_ch1.mp3', 'audio_lecture_ch1.mp3', 'audio/mpeg',
        28400000, 2100, 'https://actions.google.com/sounds/v1/ambiences/rain_heavy.ogg',
        FALSE, FALSE, 2
    );

    -- Asset 3: Video Coding / Solution Walkthrough
    INSERT INTO public.library_digital_files (
        book_id, school_id, file_type, source_type, title, storage_key, file_name, mime_type,
        file_size_bytes, duration_seconds, stream_url, is_primary, is_live_stream, sort_order
    ) VALUES (
        v_book1_id, v_school_id, 'VIDEO_MP4', 'DIRECT_LINK',
        'Lecture Recording: Operator Algebra & Matrix Formulations',
        'lecture_matrix_operators.mp4', 'lecture_matrix_operators.mp4', 'video/mp4',
        154000000, 2700, 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        FALSE, FALSE, 3
    );

    -- Asset 4: Live Stream Broadcast
    INSERT INTO public.library_digital_files (
        book_id, school_id, file_type, source_type, title, storage_key, file_name, mime_type,
        file_size_bytes, duration_seconds, stream_url, is_primary, is_live_stream, sort_order
    ) VALUES (
        v_book1_id, v_school_id, 'VIDEO_HLS', 'LIVE_STREAM',
        '🔴 LIVE: Weekly Interactive Problem Solving & Lab Stream',
        'live_quantum_lab.m3u8', 'live_quantum_lab.m3u8', 'application/x-mpegURL',
        0, 0, 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
        FALSE, TRUE, 4
    );


    -- Book 2: Algorithms & Data Structures in Python & Dart
    SELECT id INTO v_book2_id FROM public.library_books 
    WHERE school_id = v_school_id AND (isbn13 = '978-0262033848' OR title ILIKE '%Data Structures%')
    LIMIT 1;

    IF v_book2_id IS NULL THEN
        INSERT INTO public.library_books (
            school_id, title, subtitle, author, publisher, category_name, language_name, book_type_name,
            publication_year, pages, description, isbn13, total_copies, available_copies, is_digital,
            digital_visibility, access_mode, requires_permission, rating, total_reviews, read_count,
            listen_count, watch_count, subject, grade_level, difficulty_level,
            cover_url, created_by, updated_by
        ) VALUES (
            v_school_id,
            'Data Structures & Algorithms in Python',
            'Mastering Trees, Graphs, Dynamic Programming & System Design',
            'Thomas H. Cormen & Guido van Rossum',
            'MIT Press',
            'Computer Science',
            'English',
            'eBook (PDF/ePub/HTML)',
            2026,
            620,
            'A rigorous yet accessible modern computer science guide with step-by-step algorithms, visual animations, audio chapter explanations, and video tutorials.',
            '978-0262033848',
            8,
            8,
            TRUE,
            'PUBLIC',
            'ALL',
            FALSE,
            4.8,
            52,
            210,
            115,
            95,
            'Computer Science',
            'All Grades',
            'Intermediate',
            'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=400&q=80',
            v_admin_id,
            v_admin_id
        ) RETURNING id INTO v_book2_id;
    END IF;

    DELETE FROM public.library_digital_files WHERE book_id = v_book2_id;

    INSERT INTO public.library_digital_files (
        book_id, school_id, file_type, source_type, title, storage_key, file_name, mime_type,
        file_size_bytes, page_count, stream_url, is_primary, is_live_stream, sort_order
    ) VALUES (
        v_book2_id, v_school_id, 'EBOOK_PDF', 'FILE_UPLOAD',
        'Part 1: Linear & Non-Linear Structures PDF',
        'dsa_part1.pdf', 'dsa_part1.pdf', 'application/pdf',
        18500000, 310, 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        TRUE, FALSE, 1
    );

    INSERT INTO public.library_digital_files (
        book_id, school_id, file_type, source_type, title, storage_key, file_name, mime_type,
        file_size_bytes, duration_seconds, stream_url, is_primary, is_live_stream, sort_order
    ) VALUES (
        v_book2_id, v_school_id, 'AUDIO_MP3', 'DIRECT_LINK',
        'Audio Study Guide: Graph Theory & Shortest Path Algorithms',
        'audio_graphs.mp3', 'audio_graphs.mp3', 'audio/mpeg',
        32000000, 2400, 'https://actions.google.com/sounds/v1/ambiences/rain_heavy.ogg',
        FALSE, FALSE, 2
    );

    INSERT INTO public.library_digital_files (
        book_id, school_id, file_type, source_type, title, storage_key, file_name, mime_type,
        file_size_bytes, duration_seconds, stream_url, is_primary, is_live_stream, sort_order
    ) VALUES (
        v_book2_id, v_school_id, 'VIDEO_MP4', 'DIRECT_LINK',
        'Video Lecture: Dynamic Programming From Recursion to Tabulation',
        'video_dp_mastery.mp4', 'video_dp_mastery.mp4', 'video/mp4',
        198000000, 3600, 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
        FALSE, FALSE, 3
    );

END $$;
