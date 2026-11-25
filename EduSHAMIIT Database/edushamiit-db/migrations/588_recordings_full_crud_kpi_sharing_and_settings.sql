-- ============================================================================
-- Migration 588: Live Class Recordings Full CRUD, Sharing, Analytics & Settings
-- ============================================================================

-- 1. Extend public.live_class_recordings for standalone uploads & rich metadata
ALTER TABLE public.live_class_recordings
    ALTER COLUMN live_class_id DROP NOT NULL;

ALTER TABLE public.live_class_recordings
    ADD COLUMN IF NOT EXISTS class_id UUID REFERENCES public.academic_classes(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS section_id UUID REFERENCES public.academic_sections(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS subject_id UUID REFERENCES public.subjects(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS teacher_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS teacher_name TEXT,
    ADD COLUMN IF NOT EXISTS recording_type VARCHAR(50) DEFAULT 'Live Class',
    ADD COLUMN IF NOT EXISTS tags JSONB DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS shared_count INT DEFAULT 0;

-- Backfill academic metadata from linked live_classes where missing
UPDATE public.live_class_recordings r
SET
    school_id = COALESCE(r.school_id, c.school_id),
    class_id = COALESCE(r.class_id, c.class_id),
    section_id = COALESCE(r.section_id, c.section_id),
    subject_id = COALESCE(r.subject_id, c.subject_id),
    teacher_id = COALESCE(r.teacher_id, c.teacher_id),
    recording_type = COALESCE(NULLIF(r.recording_type, ''), 'Live Class')
FROM public.live_classes c
WHERE r.live_class_id = c.id
  AND (r.school_id IS NULL OR r.class_id IS NULL OR r.subject_id IS NULL OR r.teacher_id IS NULL);

-- Improve legacy generic 'Live Class Recording' titles using the linked session/class info
UPDATE public.live_class_recordings r
SET title = TRIM(BOTH FROM
    COALESCE(
        NULLIF(NULLIF(TRIM(c.title), ''), 'Live Class Recording'),
        CONCAT_WS(' • ',
            NULLIF(TRIM(COALESCE(ac.name || COALESCE(' - ' || sec.name, ''), c.target_class, '')), ''),
            NULLIF(TRIM(s.name), '')
        ) || ' Lecture Recording',
        'Recorded Lecture'
    )
)
FROM public.live_classes c
LEFT JOIN public.academic_classes ac ON ac.id = c.class_id
LEFT JOIN public.academic_sections sec ON sec.id = c.section_id
LEFT JOIN public.subjects s ON s.id = c.subject_id
WHERE r.live_class_id = c.id
  AND (r.title IS NULL OR TRIM(r.title) = '' OR LOWER(TRIM(r.title)) = 'live class recording');

-- 2. Granular Sharing Table for Recordings (supports Class, Section, Individual users)
CREATE TABLE IF NOT EXISTS public.live_class_recording_shares (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recording_id UUID NOT NULL REFERENCES public.live_class_recordings(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    shared_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    target_type VARCHAR(30) NOT NULL, -- 'class', 'section', 'user', 'role'
    target_id UUID,
    target_label TEXT NOT NULL,
    access_level VARCHAR(20) NOT NULL DEFAULT 'VIEW', -- 'VIEW', 'DOWNLOAD', 'MANAGE'
    capabilities JSONB NOT NULL DEFAULT '{}'::jsonb,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_lc_rec_shares_recording
    ON public.live_class_recording_shares(recording_id);
CREATE INDEX IF NOT EXISTS idx_lc_rec_shares_target
    ON public.live_class_recording_shares(target_type, target_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_lc_rec_shares_entry
    ON public.live_class_recording_shares(
        recording_id,
        target_type,
        COALESCE(target_id, '00000000-0000-0000-0000-000000000000'::uuid),
        target_label
    );

-- 3. Persistent School-Level Recording Settings
CREATE TABLE IF NOT EXISTS public.live_class_recording_settings (
    school_id UUID PRIMARY KEY REFERENCES public.schools(id) ON DELETE CASCADE,
    auto_recording BOOLEAN NOT NULL DEFAULT TRUE,
    cloud_storage BOOLEAN NOT NULL DEFAULT TRUE,
    default_retention_days INT NOT NULL DEFAULT 180,
    recording_quality VARCHAR(40) NOT NULL DEFAULT 'HD (720p)',
    allow_student_download BOOLEAN NOT NULL DEFAULT TRUE,
    auto_rules JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Recording Views & Downloads Event Log for Real 30-Day Analytics
CREATE TABLE IF NOT EXISTS public.live_class_recording_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recording_id UUID NOT NULL REFERENCES public.live_class_recordings(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    event_type VARCHAR(20) NOT NULL CHECK (event_type IN ('view', 'download')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_lc_rec_events_school_date
    ON public.live_class_recording_events(school_id, created_at DESC);

-- 5. Stored Procedure: Real-time Recordings Dashboard KPIs, Storage Breakdown, Settings & Analytics
CREATE OR REPLACE FUNCTION public.sp_get_live_class_recordings_dashboard(p_school_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_recordings INT := 0;
    v_this_week INT := 0;
    v_total_sec BIGINT := 0;
    v_rec_bytes BIGINT := 0;
    v_res_bytes BIGINT := 0;
    v_other_bytes BIGINT := 0;
    v_total_downloads INT := 0;
    v_avg_views INT := 0;
    v_retention_rate_pct INT := 100;
    v_non_expired INT := 0;

    v_hours INT := 0;
    v_mins INT := 0;
    v_duration_display TEXT := '0 min';

    v_total_cap_gb CONSTANT NUMERIC := 1024.0;
    v_rec_gb NUMERIC := 0;
    v_res_gb NUMERIC := 0;
    v_other_gb NUMERIC := 0;
    v_used_gb NUMERIC := 0;
    v_free_gb NUMERIC := 1024.0;
    v_used_pct INT := 0;

    v_settings JSONB;
    v_analytics JSONB;
BEGIN
    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE r.created_at >= NOW() - INTERVAL '7 days'),
        COALESCE(SUM(COALESCE(r.duration, 0)), 0),
        COALESCE(SUM(COALESCE(r.file_size, 0)), 0),
        COALESCE(SUM(COALESCE(r.downloads_count, 0)), 0),
        COALESCE(ROUND(AVG(COALESCE(r.views_count, 0))), 0)::INT,
        COUNT(*) FILTER (WHERE r.retention_until IS NULL OR r.retention_until > NOW())
    INTO
        v_total_recordings,
        v_this_week,
        v_total_sec,
        v_rec_bytes,
        v_total_downloads,
        v_avg_views,
        v_non_expired
    FROM public.live_class_recordings r
    LEFT JOIN public.live_classes c ON c.id = r.live_class_id
    WHERE COALESCE(r.school_id, c.school_id) = p_school_id
      AND r.deleted_at IS NULL;

    IF v_total_recordings > 0 THEN
        v_retention_rate_pct := ROUND((v_non_expired::NUMERIC / v_total_recordings::NUMERIC) * 100)::INT;
    END IF;

    v_hours := FLOOR(v_total_sec / 3600)::INT;
    v_mins := FLOOR((v_total_sec % 3600) / 60)::INT;
    IF v_hours > 0 THEN
        v_duration_display := v_hours || ' h ' || v_mins || ' min';
    ELSIF v_total_sec > 0 AND v_mins = 0 THEN
        v_duration_display := '< 1 min';
    ELSE
        v_duration_display := v_mins || ' min';
    END IF;

    -- Resources & documents storage bytes (safe lookup)
    BEGIN
        SELECT COALESCE(SUM(COALESCE(file_size, 0)), 0) INTO v_res_bytes
        FROM public.live_class_resources
        WHERE school_id = p_school_id;
    EXCEPTION WHEN OTHERS THEN
        v_res_bytes := 0;
    END;

    BEGIN
        SELECT COALESCE(SUM(COALESCE(file_size, 0)), 0) INTO v_other_bytes
        FROM public.user_documents
        WHERE school_id = p_school_id;
    EXCEPTION WHEN OTHERS THEN
        v_other_bytes := 0;
    END;

    v_rec_gb := ROUND((v_rec_bytes::NUMERIC / 1073741824.0), 2);
    v_res_gb := ROUND((v_res_bytes::NUMERIC / 1073741824.0), 2);
    v_other_gb := ROUND((v_other_bytes::NUMERIC / 1073741824.0), 2);
    v_used_gb := ROUND(v_rec_gb + v_res_gb + v_other_gb, 2);
    v_free_gb := GREATEST(0, ROUND(v_total_cap_gb - v_used_gb, 2));
    v_used_pct := LEAST(100, GREATEST(0, ROUND((v_used_gb / v_total_cap_gb) * 100)::INT));

    -- Persisted settings
    SELECT jsonb_build_object(
        'auto_recording', s.auto_recording,
        'cloud_storage', s.cloud_storage,
        'default_retention_days', s.default_retention_days,
        'recording_quality', s.recording_quality,
        'allow_student_download', s.allow_student_download,
        'auto_rules', COALESCE(s.auto_rules, '{}'::jsonb)
    )
    INTO v_settings
    FROM public.live_class_recording_settings s
    WHERE s.school_id = p_school_id;

    IF v_settings IS NULL THEN
        v_settings := jsonb_build_object(
            'auto_recording', TRUE,
            'cloud_storage', TRUE,
            'default_retention_days', 180,
            'recording_quality', 'HD (720p)',
            'allow_student_download', TRUE,
            'auto_rules', '{}'::jsonb
        );
    END IF;

    -- Real 30-day analytics grouped into 10 3-day buckets ending today
    WITH buckets AS (
        SELECT
            idx,
            (CURRENT_DATE - ((9 - idx) * 3) - 2)::DATE AS d_start,
            (CURRENT_DATE - ((9 - idx) * 3))::DATE AS d_end
        FROM generate_series(0, 9) AS idx
    ),
    ev AS (
        SELECT
            b.idx,
            b.d_end,
            COUNT(e.id) FILTER (WHERE e.event_type = 'view') AS ev_views,
            COUNT(e.id) FILTER (WHERE e.event_type = 'download') AS ev_downloads
        FROM buckets b
        LEFT JOIN public.live_class_recording_events e
            ON e.school_id = p_school_id
            AND e.created_at::DATE BETWEEN b.d_start AND b.d_end
        GROUP BY b.idx, b.d_end
    ),
    rec_fallback AS (
        SELECT
            b.idx,
            COALESCE(SUM(r.views_count), 0) AS sum_views,
            COALESCE(SUM(r.downloads_count), 0) AS sum_downloads
        FROM buckets b
        LEFT JOIN public.live_class_recordings r
            LEFT JOIN public.live_classes c ON c.id = r.live_class_id
            ON COALESCE(r.school_id, c.school_id) = p_school_id
            AND r.deleted_at IS NULL
            AND r.created_at::DATE BETWEEN b.d_start AND b.d_end
        GROUP BY b.idx
    )
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'date', TO_CHAR(ev.d_end, 'DD Mon'),
            'views', GREATEST(ev.ev_views, CASE WHEN ev.ev_views = 0 THEN rf.sum_views ELSE 0 END),
            'downloads', GREATEST(ev.ev_downloads, CASE WHEN ev.ev_downloads = 0 THEN rf.sum_downloads ELSE 0 END)
        )
        ORDER BY ev.idx
    ), '[]'::jsonb)
    INTO v_analytics
    FROM ev
    JOIN rec_fallback rf ON rf.idx = ev.idx;

    RETURN jsonb_build_object(
        'kpis', jsonb_build_object(
            'total_recordings', v_total_recordings,
            'this_week', v_this_week,
            'total_duration_seconds', v_total_sec,
            'total_duration_display', v_duration_display,
            'storage_used_bytes', v_used_gb * 1073741824,
            'storage_used_gb', v_used_gb,
            'storage_total_tb', 1.0,
            'storage_used_percentage', v_used_pct,
            'total_downloads', v_total_downloads,
            'avg_views', v_avg_views,
            'retention_rate_pct', v_retention_rate_pct
        ),
        'storage_breakdown', jsonb_build_object(
            'recordings_gb', v_rec_gb,
            'recordings_pct', ROUND((v_rec_gb / v_total_cap_gb) * 100, 2),
            'class_resources_gb', v_res_gb,
            'class_resources_pct', ROUND((v_res_gb / v_total_cap_gb) * 100, 2),
            'others_gb', v_other_gb,
            'others_pct', ROUND((v_other_gb / v_total_cap_gb) * 100, 2),
            'free_space_gb', v_free_gb,
            'free_space_pct', ROUND((v_free_gb / v_total_cap_gb) * 100, 2)
        ),
        'settings', v_settings,
        'analytics_30_days', v_analytics
    );
END;
$$;

-- 6. Stored Procedure: Rich Recordings List with Standalone & Live-Class Support
CREATE OR REPLACE FUNCTION public.sp_get_live_class_recordings_list(
    p_school_id UUID,
    p_class_id UUID DEFAULT NULL,
    p_subject_id UUID DEFAULT NULL,
    p_teacher_id UUID DEFAULT NULL,
    p_search TEXT DEFAULT NULL,
    p_status TEXT DEFAULT NULL,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 8
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_offset INT := (GREATEST(1, p_page) - 1) * GREATEST(1, p_page_size);
    v_total INT := 0;
    v_items JSONB := '[]'::jsonb;
BEGIN
    SELECT COUNT(*) INTO v_total
    FROM public.live_class_recordings r
    LEFT JOIN public.live_classes c ON c.id = r.live_class_id
    WHERE (p_school_id IS NULL OR COALESCE(r.school_id, c.school_id) = p_school_id)
      AND r.deleted_at IS NULL
      AND (p_class_id IS NULL OR COALESCE(r.class_id, c.class_id) = p_class_id)
      AND (p_subject_id IS NULL OR COALESCE(r.subject_id, c.subject_id) = p_subject_id)
      AND (p_teacher_id IS NULL OR COALESCE(r.teacher_id, c.teacher_id) = p_teacher_id)
      AND (p_status IS NULL OR p_status = 'All' OR r.processing_status ILIKE p_status)
      AND (
          p_search IS NULL
          OR r.title ILIKE '%' || p_search || '%'
          OR COALESCE(c.title, '') ILIKE '%' || p_search || '%'
          OR COALESCE(r.description, '') ILIKE '%' || p_search || '%'
      );

    SELECT COALESCE(jsonb_agg(item), '[]'::jsonb) INTO v_items
    FROM (
        SELECT
            r.id,
            COALESCE(r.live_class_id::TEXT, '') AS live_class_id,
            COALESCE(NULLIF(TRIM(r.title), ''), NULLIF(TRIM(c.title), ''), 'Recorded Lecture') AS title,
            r.description,
            r.recording_url,
            r.storage_key,
            COALESCE(r.mime_type, 'video/mp4') AS mime_type,
            COALESCE(r.class_id, c.class_id)::TEXT AS class_id,
            COALESCE(r.section_id, c.section_id)::TEXT AS section_id,
            COALESCE(r.subject_id, c.subject_id)::TEXT AS subject_id,
            COALESCE(r.teacher_id, c.teacher_id)::TEXT AS teacher_id,
            COALESCE(
                NULLIF(TRIM(CONCAT_WS(' - ', ac.name, sec.name)), ''),
                NULLIF(TRIM(c.target_class), ''),
                'Class'
            ) AS class_section,
            COALESCE(s.name, 'General') AS subject_name,
            COALESCE(NULLIF(TRIM(r.teacher_name), ''), p.full_name, 'Teacher') AS teacher_name,
            TO_CHAR(COALESCE(r.created_at, c.scheduled_at, NOW()), 'DD Mon YYYY, HH12:MI AM') AS date_time_str,
            CASE
                WHEN COALESCE(r.duration, 0) < 60 THEN GREATEST(1, ROUND(COALESCE(r.duration, 60) / 60.0)::INT) || ' min'
                ELSE ROUND(r.duration / 60.0)::INT || ' min'
            END AS duration_str,
            COALESCE(r.duration, 0) AS duration_seconds,
            COALESCE(r.views_count, 0) AS views,
            COALESCE(r.downloads_count, 0) AS downloads_count,
            COALESCE(r.file_size, 0) AS file_size,
            CASE
                WHEN COALESCE(r.file_size, 0) >= 1048576 THEN ROUND((r.file_size::NUMERIC / 1048576.0), 1)::TEXT || ' MB'
                WHEN COALESCE(r.file_size, 0) >= 1024 THEN ROUND((r.file_size::NUMERIC / 1024.0), 1)::TEXT || ' KB'
                ELSE COALESCE(r.file_size, 0)::TEXT || ' B'
            END AS size_str,
            COALESCE(r.processing_status, 'Processed') AS status,
            COALESCE(r.visibility, 'CLASS') AS visibility,
            COALESCE(
                NULLIF(TRIM(r.recording_type), ''),
                CASE WHEN r.live_class_id IS NULL THEN 'Uploaded Recording' ELSE 'Live Class' END
            ) AS type,
            COALESCE(
                (SELECT jsonb_agg(t) FROM jsonb_array_elements_text(COALESCE(r.tags, '[]'::jsonb)) t),
                '[]'::jsonb
            ) AS tags,
            GREATEST(
                COALESCE(r.shared_count, 0),
                (SELECT COUNT(*)::INT FROM public.live_class_recording_shares rs WHERE rs.recording_id = r.id)
            ) AS shared_count,
            r.uploaded_by::TEXT AS uploaded_by,
            r.created_at
        FROM public.live_class_recordings r
        LEFT JOIN public.live_classes c ON c.id = r.live_class_id
        LEFT JOIN public.subjects s ON s.id = COALESCE(r.subject_id, c.subject_id)
        LEFT JOIN public.academic_classes ac ON ac.id = COALESCE(r.class_id, c.class_id)
        LEFT JOIN public.academic_sections sec ON sec.id = COALESCE(r.section_id, c.section_id)
        LEFT JOIN public.profiles p ON p.id = COALESCE(r.teacher_id, c.teacher_id)
        WHERE (p_school_id IS NULL OR COALESCE(r.school_id, c.school_id) = p_school_id)
          AND r.deleted_at IS NULL
          AND (p_class_id IS NULL OR COALESCE(r.class_id, c.class_id) = p_class_id)
          AND (p_subject_id IS NULL OR COALESCE(r.subject_id, c.subject_id) = p_subject_id)
          AND (p_teacher_id IS NULL OR COALESCE(r.teacher_id, c.teacher_id) = p_teacher_id)
          AND (p_status IS NULL OR p_status = 'All' OR r.processing_status ILIKE p_status)
          AND (
              p_search IS NULL
              OR r.title ILIKE '%' || p_search || '%'
              OR COALESCE(c.title, '') ILIKE '%' || p_search || '%'
              OR COALESCE(r.description, '') ILIKE '%' || p_search || '%'
          )
        ORDER BY r.created_at DESC
        LIMIT GREATEST(1, p_page_size) OFFSET v_offset
    ) item;

    RETURN jsonb_build_object(
        'total_count', v_total,
        'page', p_page,
        'page_size', p_page_size,
        'total_pages', GREATEST(1, CEIL(v_total::NUMERIC / GREATEST(1, p_page_size)::NUMERIC))::INT,
        'items', v_items
    );
END;
$$;
