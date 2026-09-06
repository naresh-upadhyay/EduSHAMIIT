-- ============================================================================
-- Migration 334: Unified Digital + Physical Library Books System
-- Multi-Format Books Catalogue, Digital Assets Management, DRM-Lite Access,
-- Reading/Audio/Video Progress Tracking, Annotations, Reviews, and Analytics
-- ============================================================================

-- 1. Extend library_books Table with Digital & Advanced Metadata
ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS is_digital BOOLEAN DEFAULT FALSE;
ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS digital_visibility VARCHAR(50) DEFAULT 'PUBLIC'; -- PUBLIC, RESTRICTED, UNLISTED
ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS access_mode VARCHAR(50) DEFAULT 'ALL'; -- ALL, STUDENT_ONLY, TEACHER_ONLY, RESTRICTED_ROLES, CUSTOM
ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS requires_permission BOOLEAN DEFAULT FALSE;
ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS allowed_roles TEXT[] DEFAULT '{}';
ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS allowed_grades TEXT[] DEFAULT '{}';
ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS allowed_departments TEXT[] DEFAULT '{}';
ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS default_access_duration_days INT DEFAULT NULL;

-- DRM & Interaction Toggles
ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS allow_notes BOOLEAN DEFAULT TRUE;
ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS allow_highlights BOOLEAN DEFAULT TRUE;
ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS allow_bookmarks BOOLEAN DEFAULT TRUE;
ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS allow_copy_text BOOLEAN DEFAULT FALSE;
ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS allow_screenshots BOOLEAN DEFAULT FALSE;
ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS max_concurrent_devices INT DEFAULT 2;

-- Engagement & Content Stats
ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS rating NUMERIC(3,2) DEFAULT 0.0;
ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS total_reviews INT DEFAULT 0;
ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS view_count INT DEFAULT 0;
ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS read_count INT DEFAULT 0;
ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS listen_count INT DEFAULT 0;
ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS watch_count INT DEFAULT 0;
ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS total_reading_seconds BIGINT DEFAULT 0;
ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS total_listening_seconds BIGINT DEFAULT 0;
ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS total_watching_seconds BIGINT DEFAULT 0;

-- Additional Academic Classification
ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS preview_url TEXT;
ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS subject VARCHAR(150);
ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS grade_level VARCHAR(100);
ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS curriculum VARCHAR(100);
ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS difficulty_level VARCHAR(50) DEFAULT 'Intermediate';
ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS age_group VARCHAR(50);
ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS published_at TIMESTAMPTZ DEFAULT NOW();


-- 2. Digital Media Files Table
CREATE TABLE IF NOT EXISTS public.library_digital_files (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    book_id UUID NOT NULL REFERENCES public.library_books(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    file_type VARCHAR(50) NOT NULL, -- EBOOK_PDF, EBOOK_EPUB, EBOOK_HTML, AUDIO_MP3, AUDIO_M4A, VIDEO_MP4, VIDEO_HLS, SAMPLE_PREVIEW
    storage_key TEXT NOT NULL,
    file_name TEXT NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    file_size_bytes BIGINT NOT NULL DEFAULT 0,
    duration_seconds INT DEFAULT 0,
    page_count INT DEFAULT 0,
    checksum VARCHAR(128),
    processing_status VARCHAR(50) DEFAULT 'READY', -- UPLOADED, PROCESSING, READY, FAILED, ENCRYPTED
    is_encrypted BOOLEAN DEFAULT FALSE,
    stream_url TEXT,
    is_primary BOOLEAN DEFAULT TRUE,
    created_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_library_digital_files_book_id ON public.library_digital_files(book_id);
CREATE INDEX IF NOT EXISTS idx_library_digital_files_school_id ON public.library_digital_files(school_id);


-- 3. Digital Access Permissions Table
CREATE TABLE IF NOT EXISTS public.library_digital_access_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    book_id UUID NOT NULL REFERENCES public.library_books(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    request_id UUID REFERENCES public.library_requests(id) ON DELETE SET NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'APPROVED', -- PENDING, APPROVED, REJECTED, EXPIRED, REVOKED
    access_scope VARCHAR(50) DEFAULT 'FULL', -- FULL, READ_ONLY, LISTEN_ONLY, WATCH_ONLY
    granted_by UUID REFERENCES public.profiles(id),
    granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NULL,
    revoked_at TIMESTAMPTZ NULL,
    revoked_by UUID REFERENCES public.profiles(id),
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(book_id, user_id, school_id)
);

CREATE INDEX IF NOT EXISTS idx_lib_digital_perm_book_user ON public.library_digital_access_permissions(book_id, user_id);
CREATE INDEX IF NOT EXISTS idx_lib_digital_perm_school ON public.library_digital_access_permissions(school_id);


-- 4. Reading, Audio, & Video Progress Table
CREATE TABLE IF NOT EXISTS public.library_reading_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    book_id UUID NOT NULL REFERENCES public.library_books(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    media_type VARCHAR(50) NOT NULL DEFAULT 'EBOOK', -- EBOOK, AUDIOBOOK, VIDEOBOOK
    current_page INT DEFAULT 1,
    total_pages INT DEFAULT 1,
    progress_pct NUMERIC(5,2) DEFAULT 0.0,
    position_seconds NUMERIC(10,2) DEFAULT 0.0,
    total_duration_seconds NUMERIC(10,2) DEFAULT 0.0,
    playback_speed NUMERIC(3,2) DEFAULT 1.0,
    time_spent_seconds BIGINT DEFAULT 0,
    is_completed BOOLEAN DEFAULT FALSE,
    last_read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(book_id, user_id, media_type)
);

CREATE INDEX IF NOT EXISTS idx_lib_progress_user_book ON public.library_reading_progress(user_id, book_id);


-- 5. Book Annotations & Interactions Table (Bookmarks, Highlights, Notes, Lists)
CREATE TABLE IF NOT EXISTS public.library_book_interactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    book_id UUID NOT NULL REFERENCES public.library_books(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    interaction_type VARCHAR(50) NOT NULL, -- BOOKMARK, HIGHLIGHT, NOTE, FAVORITE, READ_LATER, COMPLETED
    page_number INT,
    timestamp_seconds NUMERIC(10,2),
    selected_text TEXT,
    highlight_color VARCHAR(30) DEFAULT '#FEF08A',
    note_content TEXT,
    chapter_title TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_lib_interactions_book_user ON public.library_book_interactions(book_id, user_id);


-- 6. Book Ratings & Reviews Table
CREATE TABLE IF NOT EXISTS public.library_book_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    book_id UUID NOT NULL REFERENCES public.library_books(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    review_title VARCHAR(200),
    review_text TEXT,
    reaction_emoji VARCHAR(30),
    status VARCHAR(30) DEFAULT 'PUBLISHED', -- PUBLISHED, PENDING_MODERATION, HIDDEN
    helpful_count INT DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(book_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_lib_reviews_book ON public.library_book_reviews(book_id);


-- 7. Seed Dynamic Lookup Keys & Values for Multi-Format Digital Library
DO $$
DECLARE
    s_record RECORD;
    admin_id UUID;
    v_key_id UUID;
BEGIN
    SELECT id INTO admin_id FROM public.profiles WHERE role = 'SUPER_ADMIN' OR role = 'ADMIN' LIMIT 1;
    IF admin_id IS NULL THEN
        SELECT id INTO admin_id FROM public.profiles LIMIT 1;
    END IF;

    FOR s_record IN (SELECT id FROM public.schools) LOOP
        -- 1. BOOK_TYPE
        INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
        VALUES (s_record.id, 'Library Book Types', 'BOOK_TYPE', 'Supported physical and digital library content formats', 'SYSTEM', 'menu_book', 'ACTIVE', admin_id)
        ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
        RETURNING id INTO v_key_id;

        IF v_key_id IS NULL THEN
            SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s_record.id AND key_code = 'BOOK_TYPE' AND deleted_at IS NULL LIMIT 1;
        END IF;

        IF v_key_id IS NOT NULL AND admin_id IS NOT NULL THEN
            INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, sort_order, status, created_by)
            VALUES 
                (v_key_id, s_record.id, 'Physical Book', 'PHYSICAL', 1, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'eBook (PDF/ePub/HTML)', 'EBOOK', 2, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Audiobook', 'AUDIOBOOK', 3, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Video Book', 'VIDEOBOOK', 4, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Research Paper', 'RESEARCH_PAPER', 5, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Magazine', 'MAGAZINE', 6, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Journal', 'JOURNAL', 7, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Reference Material', 'REFERENCE_MATERIAL', 8, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Notes / Study Material', 'STUDY_NOTES', 9, 'ACTIVE', admin_id)
            ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO UPDATE 
            SET value_name = EXCLUDED.value_name, sort_order = EXCLUDED.sort_order, status = 'ACTIVE';
        END IF;

        -- 2. DIGITAL_FORMAT
        INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
        VALUES (s_record.id, 'Digital Media Formats', 'DIGITAL_FORMAT', 'Digital file encoding formats', 'SYSTEM', 'attachment', 'ACTIVE', admin_id)
        ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
        RETURNING id INTO v_key_id;

        IF v_key_id IS NULL THEN
            SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s_record.id AND key_code = 'DIGITAL_FORMAT' AND deleted_at IS NULL LIMIT 1;
        END IF;

        IF v_key_id IS NOT NULL AND admin_id IS NOT NULL THEN
            INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, sort_order, status, created_by)
            VALUES 
                (v_key_id, s_record.id, 'PDF Document', 'PDF', 1, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'EPUB E-Book', 'EPUB', 2, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'HTML Web Book', 'HTML', 3, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'MP3 Audio Stream', 'MP3', 4, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'M4A High Quality Audio', 'M4A', 5, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'MP4 Video Stream', 'MP4', 6, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'HLS Adaptive Video', 'HLS', 7, 'ACTIVE', admin_id)
            ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO UPDATE 
            SET value_name = EXCLUDED.value_name, sort_order = EXCLUDED.sort_order, status = 'ACTIVE';
        END IF;

        -- 3. DIGITAL_VISIBILITY
        INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
        VALUES (s_record.id, 'Digital Visibility', 'DIGITAL_VISIBILITY', 'Access and visibility levels for digital library content', 'SYSTEM', 'visibility', 'ACTIVE', admin_id)
        ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
        RETURNING id INTO v_key_id;

        IF v_key_id IS NULL THEN
            SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s_record.id AND key_code = 'DIGITAL_VISIBILITY' AND deleted_at IS NULL LIMIT 1;
        END IF;

        IF v_key_id IS NOT NULL AND admin_id IS NOT NULL THEN
            INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, sort_order, status, created_by)
            VALUES 
                (v_key_id, s_record.id, 'Public (Open Access)', 'PUBLIC', 1, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Restricted (Permission Required)', 'RESTRICTED', 2, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Unlisted (Direct Link / Class Only)', 'UNLISTED', 3, 'ACTIVE', admin_id)
            ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO UPDATE 
            SET value_name = EXCLUDED.value_name, sort_order = EXCLUDED.sort_order, status = 'ACTIVE';
        END IF;

        -- 4. DIFFICULTY_LEVEL
        INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
        VALUES (s_record.id, 'Content Difficulty Level', 'DIFFICULTY_LEVEL', 'Educational complexity level', 'SYSTEM', 'trending_up', 'ACTIVE', admin_id)
        ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
        RETURNING id INTO v_key_id;

        IF v_key_id IS NULL THEN
            SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s_record.id AND key_code = 'DIFFICULTY_LEVEL' AND deleted_at IS NULL LIMIT 1;
        END IF;

        IF v_key_id IS NOT NULL AND admin_id IS NOT NULL THEN
            INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, sort_order, status, created_by)
            VALUES 
                (v_key_id, s_record.id, 'Beginner', 'BEGINNER', 1, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Intermediate', 'INTERMEDIATE', 2, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Advanced', 'ADVANCED', 3, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Expert', 'EXPERT', 4, 'ACTIVE', admin_id)
            ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO UPDATE 
            SET value_name = EXCLUDED.value_name, sort_order = EXCLUDED.sort_order, status = 'ACTIVE';
        END IF;

    END LOOP;
END;
$$;



-- 8. Stored Procedure: Check User Digital Content Access Permission
CREATE OR REPLACE FUNCTION public.fn_library_check_digital_access(
    p_school_id UUID,
    p_book_id UUID,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_book RECORD;
    v_perm RECORD;
    v_user_role VARCHAR(50);
    v_has_access BOOLEAN := FALSE;
    v_perm_status VARCHAR(50) := 'NONE';
    v_expires_at TIMESTAMPTZ := NULL;
    v_reason TEXT := NULL;
BEGIN
    -- Fetch book metadata
    SELECT id, is_digital, digital_visibility, requires_permission, access_mode, allowed_roles, allowed_grades, allowed_departments
    INTO v_book
    FROM public.library_books
    WHERE id = p_book_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('has_access', FALSE, 'reason', 'Book not found', 'status', 'NOT_FOUND');
    END IF;

    -- If physical-only book without digital files
    IF v_book.is_digital IS NOT TRUE THEN
        RETURN jsonb_build_object('has_access', FALSE, 'reason', 'Book is not in digital format', 'status', 'PHYSICAL_ONLY');
    END IF;

    -- If public digital access and doesn't require permission
    IF (v_book.digital_visibility = 'PUBLIC' OR v_book.digital_visibility IS NULL) AND (v_book.requires_permission IS NOT TRUE) THEN
        RETURN jsonb_build_object(
            'has_access', TRUE,
            'reason', 'Public digital content',
            'status', 'PUBLIC',
            'expires_at', NULL
        );
    END IF;

    -- Check explicit granted permission in library_digital_access_permissions
    SELECT id, status, expires_at, reason
    INTO v_perm
    FROM public.library_digital_access_permissions
    WHERE book_id = p_book_id AND user_id = p_user_id AND school_id = p_school_id;

    IF FOUND THEN
        IF v_perm.status = 'APPROVED' THEN
            -- Check expiration
            IF v_perm.expires_at IS NULL OR v_perm.expires_at > NOW() THEN
                RETURN jsonb_build_object(
                    'has_access', TRUE,
                    'reason', 'Access granted by librarian',
                    'status', 'APPROVED',
                    'expires_at', v_perm.expires_at
                );
            ELSE
                -- Expired
                RETURN jsonb_build_object(
                    'has_access', FALSE,
                    'reason', 'Digital access permission has expired',
                    'status', 'EXPIRED',
                    'expires_at', v_perm.expires_at
                );
            END IF;
        ELSIF v_perm.status = 'PENDING' THEN
            RETURN jsonb_build_object(
                'has_access', FALSE,
                'reason', 'Digital access request pending librarian approval',
                'status', 'PENDING'
            );
        ELSIF v_perm.status = 'REJECTED' THEN
            RETURN jsonb_build_object(
                'has_access', FALSE,
                'reason', COALESCE(v_perm.reason, 'Digital access request was rejected'),
                'status', 'REJECTED'
            );
        ELSIF v_perm.status = 'REVOKED' THEN
            RETURN jsonb_build_object(
                'has_access', FALSE,
                'reason', 'Digital access permission was revoked',
                'status', 'REVOKED'
            );
        END IF;
    END IF;

    -- Default for restricted titles without granted permission
    RETURN jsonb_build_object(
        'has_access', FALSE,
        'reason', 'This title requires librarian approval before reading/listening',
        'status', 'PERMISSION_REQUIRED'
    );
END;
$$;


-- 9. Stored Procedure: Record Digital Reading / Audio / Video Progress
CREATE OR REPLACE FUNCTION public.fn_library_record_digital_progress(
    p_school_id UUID,
    p_book_id UUID,
    p_user_id UUID,
    p_media_type VARCHAR(50),
    p_current_page INT,
    p_total_pages INT,
    p_progress_pct NUMERIC,
    p_position_seconds NUMERIC,
    p_total_duration_seconds NUMERIC,
    p_playback_speed NUMERIC,
    p_session_seconds BIGINT,
    p_is_completed BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_rec RECORD;
BEGIN
    INSERT INTO public.library_reading_progress (
        book_id, user_id, school_id, media_type,
        current_page, total_pages, progress_pct,
        position_seconds, total_duration_seconds, playback_speed,
        time_spent_seconds, is_completed, last_read_at, updated_at
    ) VALUES (
        p_book_id, p_user_id, p_school_id, UPPER(p_media_type),
        GREATEST(1, p_current_page), GREATEST(1, p_total_pages), LEAST(100.0, GREATEST(0.0, p_progress_pct)),
        p_position_seconds, p_total_duration_seconds, p_playback_speed,
        p_session_seconds, p_is_completed, NOW(), NOW()
    )
    ON CONFLICT (book_id, user_id, media_type) DO UPDATE SET
        current_page = EXCLUDED.current_page,
        total_pages = EXCLUDED.total_pages,
        progress_pct = EXCLUDED.progress_pct,
        position_seconds = EXCLUDED.position_seconds,
        total_duration_seconds = EXCLUDED.total_duration_seconds,
        playback_speed = EXCLUDED.playback_speed,
        time_spent_seconds = public.library_reading_progress.time_spent_seconds + p_session_seconds,
        is_completed = EXCLUDED.is_completed OR public.library_reading_progress.is_completed,
        last_read_at = NOW(),
        updated_at = NOW()
    RETURNING * INTO v_rec;

    -- Update aggregate book metrics
    IF UPPER(p_media_type) = 'EBOOK' THEN
        UPDATE public.library_books
        SET read_count = read_count + 1,
            total_reading_seconds = total_reading_seconds + p_session_seconds,
            updated_at = NOW()
        WHERE id = p_book_id;
    ELSIF UPPER(p_media_type) = 'AUDIOBOOK' THEN
        UPDATE public.library_books
        SET listen_count = listen_count + 1,
            total_listening_seconds = total_listening_seconds + p_session_seconds,
            updated_at = NOW()
        WHERE id = p_book_id;
    ELSIF UPPER(p_media_type) = 'VIDEOBOOK' THEN
        UPDATE public.library_books
        SET watch_count = watch_count + 1,
            total_watching_seconds = total_watching_seconds + p_session_seconds,
            updated_at = NOW()
        WHERE id = p_book_id;
    END IF;

    RETURN to_jsonb(v_rec);
END;
$$;


-- 10. Stored Procedure: Comprehensive Digital Library Analytics
CREATE OR REPLACE FUNCTION public.fn_library_get_digital_analytics(
    p_school_id UUID,
    p_book_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_reads BIGINT := 0;
    v_total_listens BIGINT := 0;
    v_total_watches BIGINT := 0;
    v_total_reading_hours NUMERIC := 0.0;
    v_total_listening_hours NUMERIC := 0.0;
    v_total_watching_hours NUMERIC := 0.0;
    v_avg_completion_pct NUMERIC := 0.0;
    v_total_bookmarks BIGINT := 0;
    v_total_highlights BIGINT := 0;
    v_total_notes BIGINT := 0;
    v_unique_readers BIGINT := 0;
    v_top_readers JSONB := '[]'::jsonb;
    v_popular_digital_books JSONB := '[]'::jsonb;
BEGIN
    IF p_book_id IS NOT NULL THEN
        -- Book-specific analytics
        SELECT 
            COALESCE(read_count, 0),
            COALESCE(listen_count, 0),
            COALESCE(watch_count, 0),
            ROUND(COALESCE(total_reading_seconds, 0) / 3600.0, 1),
            ROUND(COALESCE(total_listening_seconds, 0) / 3600.0, 1),
            ROUND(COALESCE(total_watching_seconds, 0) / 3600.0, 1)
        INTO v_total_reads, v_total_listens, v_total_watches, v_total_reading_hours, v_total_listening_hours, v_total_watching_hours
        FROM public.library_books
        WHERE id = p_book_id AND school_id = p_school_id;

        SELECT 
            COALESCE(ROUND(AVG(progress_pct), 1), 0.0),
            COUNT(DISTINCT user_id)
        INTO v_avg_completion_pct, v_unique_readers
        FROM public.library_reading_progress
        WHERE book_id = p_book_id AND school_id = p_school_id;

        SELECT COUNT(*) INTO v_total_bookmarks
        FROM public.library_book_interactions
        WHERE book_id = p_book_id AND school_id = p_school_id AND interaction_type = 'BOOKMARK';

        SELECT COUNT(*) INTO v_total_highlights
        FROM public.library_book_interactions
        WHERE book_id = p_book_id AND school_id = p_school_id AND interaction_type = 'HIGHLIGHT';

        SELECT COUNT(*) INTO v_total_notes
        FROM public.library_book_interactions
        WHERE book_id = p_book_id AND school_id = p_school_id AND interaction_type = 'NOTE';

    ELSE
        -- School-wide Digital Library Analytics
        SELECT 
            COALESCE(SUM(read_count), 0),
            COALESCE(SUM(listen_count), 0),
            COALESCE(SUM(watch_count), 0),
            ROUND(COALESCE(SUM(total_reading_seconds), 0) / 3600.0, 1),
            ROUND(COALESCE(SUM(total_listening_seconds), 0) / 3600.0, 1),
            ROUND(COALESCE(SUM(total_watching_seconds), 0) / 3600.0, 1)
        INTO v_total_reads, v_total_listens, v_total_watches, v_total_reading_hours, v_total_listening_hours, v_total_watching_hours
        FROM public.library_books
        WHERE school_id = p_school_id;

        SELECT 
            COALESCE(ROUND(AVG(progress_pct), 1), 0.0),
            COUNT(DISTINCT user_id)
        INTO v_avg_completion_pct, v_unique_readers
        FROM public.library_reading_progress
        WHERE school_id = p_school_id;

        SELECT COUNT(*) INTO v_total_bookmarks FROM public.library_book_interactions WHERE school_id = p_school_id AND interaction_type = 'BOOKMARK';
        SELECT COUNT(*) INTO v_total_highlights FROM public.library_book_interactions WHERE school_id = p_school_id AND interaction_type = 'HIGHLIGHT';
        SELECT COUNT(*) INTO v_total_notes FROM public.library_book_interactions WHERE school_id = p_school_id AND interaction_type = 'NOTE';

        -- Top 5 Popular Digital Titles
        SELECT COALESCE(jsonb_agg(sub), '[]'::jsonb) INTO v_popular_digital_books
        FROM (
            SELECT id, title, author, book_type_name, cover_url, (read_count + listen_count + watch_count) as total_engagements, rating
            FROM public.library_books
            WHERE school_id = p_school_id AND is_digital = TRUE
            ORDER BY total_engagements DESC, rating DESC
            LIMIT 5
        ) sub;

    END IF;

    -- Top active readers
    SELECT COALESCE(jsonb_agg(sub), '[]'::jsonb) INTO v_top_readers
    FROM (
        SELECT p.id as user_id, p.full_name, p.avatar_url,
               SUM(rp.time_spent_seconds) / 60 as total_minutes_read,
               COUNT(DISTINCT rp.book_id) as books_read_count
        FROM public.library_reading_progress rp
        JOIN public.profiles p ON rp.user_id = p.id
        WHERE rp.school_id = p_school_id AND (p_book_id IS NULL OR rp.book_id = p_book_id)
        GROUP BY p.id, p.full_name, p.avatar_url
        ORDER BY total_minutes_read DESC
        LIMIT 5
    ) sub;

    RETURN jsonb_build_object(
        'total_reads', v_total_reads,
        'total_listens', v_total_listens,
        'total_watches', v_total_watches,
        'total_reading_hours', v_total_reading_hours,
        'total_listening_hours', v_total_listening_hours,
        'total_watching_hours', v_total_watching_hours,
        'avg_completion_pct', v_avg_completion_pct,
        'unique_readers', v_unique_readers,
        'total_bookmarks', v_total_bookmarks,
        'total_highlights', v_total_highlights,
        'total_notes', v_total_notes,
        'top_readers', v_top_readers,
        'popular_digital_books', v_popular_digital_books
    );
END;
$$;


-- 11. Enhanced fn_library_list_books with Digital System Metadata & Formats
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
                     FROM public.library_digital_files df
                     WHERE df.book_id = b.id
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
        p_page_size,
        v_offset
    );

    EXECUTE v_sql USING p_school_id INTO v_items;

    RETURN jsonb_build_object(
        'items', v_items,
        'pagination', jsonb_build_object(
            'page', p_page,
            'page_size', p_page_size,
            'total', v_total,
            'total_items', v_total,
            'total_pages', v_total_pages,
            'pages', v_total_pages
        )
    );
END;
$$;

