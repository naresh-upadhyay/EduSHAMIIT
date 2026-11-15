-- Migration 480: Enterprise Streaming & Broadcast System
-- EduSHAMIIT Live Class Management -> Join & Conduct -> Streaming & Broadcast

CREATE TABLE IF NOT EXISTS broadcast_platform_accounts (
    id SERIAL PRIMARY KEY,
    institute_id INTEGER NOT NULL DEFAULT 1,
    platform_key VARCHAR(50) NOT NULL, -- 'youtube', 'facebook', 'teams', 'zoom', 'custom_rtmp'
    platform_name VARCHAR(100) NOT NULL,
    account_email VARCHAR(255),
    channel_name VARCHAR(255),
    server_url VARCHAR(500),
    stream_key VARCHAR(500),
    is_connected BOOLEAN NOT NULL DEFAULT FALSE,
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    auth_metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS live_broadcasts (
    id SERIAL PRIMARY KEY,
    broadcast_code VARCHAR(50) UNIQUE NOT NULL,
    institute_id INTEGER NOT NULL DEFAULT 1,
    live_class_id INTEGER,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100) DEFAULT 'Education',
    privacy VARCHAR(50) DEFAULT 'Public', -- 'Public', 'Unlisted', 'Private'
    stream_quality VARCHAR(50) DEFAULT '1080p (Full HD)', -- '720p (HD)', '1080p (Full HD)', '4K (Ultra HD)'
    bitrate_mode VARCHAR(50) DEFAULT 'Auto (Recommended)',
    target_bitrate_kbps INTEGER DEFAULT 4500,
    target_fps INTEGER DEFAULT 30,
    status VARCHAR(50) NOT NULL DEFAULT 'scheduled', -- 'draft', 'scheduled', 'live', 'paused', 'ended'
    started_at TIMESTAMP WITH TIME ZONE,
    ended_at TIMESTAMP WITH TIME ZONE,
    current_duration_seconds INTEGER DEFAULT 0,
    current_viewers INTEGER DEFAULT 0,
    total_views INTEGER DEFAULT 0,
    peak_viewers INTEGER DEFAULT 0,
    likes_count INTEGER DEFAULT 0,
    stream_health VARCHAR(50) DEFAULT 'Good', -- 'Excellent', 'Good', 'Fair', 'Poor', 'Offline'
    resolution VARCHAR(50) DEFAULT '1080p',
    actual_bitrate_kbps INTEGER DEFAULT 4500,
    actual_fps INTEGER DEFAULT 30,
    egress_id VARCHAR(100),
    recording_id INTEGER,
    recording_url VARCHAR(500),
    scheduled_start_time TIMESTAMP WITH TIME ZONE,
    class_subject_label VARCHAR(150),
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS broadcast_destinations (
    id SERIAL PRIMARY KEY,
    broadcast_id INTEGER NOT NULL REFERENCES live_broadcasts(id) ON DELETE CASCADE,
    platform_key VARCHAR(50) NOT NULL,
    destination_name VARCHAR(100) NOT NULL,
    rtmp_url VARCHAR(500) NOT NULL,
    stream_key VARCHAR(500),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_connected BOOLEAN NOT NULL DEFAULT FALSE,
    sync_status VARCHAR(50) DEFAULT 'ready', -- 'ready', 'streaming', 'paused', 'failed', 'offline'
    destination_viewers INTEGER DEFAULT 0,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS broadcast_health_snapshots (
    id SERIAL PRIMARY KEY,
    broadcast_id INTEGER NOT NULL REFERENCES live_broadcasts(id) ON DELETE CASCADE,
    stream_health VARCHAR(50) NOT NULL,
    resolution VARCHAR(50) NOT NULL,
    bitrate_kbps INTEGER NOT NULL,
    fps INTEGER NOT NULL,
    cpu_usage_pct NUMERIC(5,2) DEFAULT 12.5,
    dropped_frames INTEGER DEFAULT 0,
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS broadcast_analytics_snapshots (
    id SERIAL PRIMARY KEY,
    broadcast_id INTEGER NOT NULL REFERENCES live_broadcasts(id) ON DELETE CASCADE,
    minute_mark VARCHAR(20) NOT NULL, -- e.g. '00:00', '05:00', '10:00'
    viewer_count INTEGER NOT NULL,
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS broadcast_settings (
    id SERIAL PRIMARY KEY,
    institute_id INTEGER UNIQUE NOT NULL DEFAULT 1,
    default_quality VARCHAR(50) DEFAULT '1080p (Full HD)',
    default_bitrate_mode VARCHAR(50) DEFAULT 'Auto (Recommended)',
    default_privacy VARCHAR(50) DEFAULT 'Public',
    default_category VARCHAR(100) DEFAULT 'Education',
    auto_record_broadcasts BOOLEAN DEFAULT TRUE,
    low_latency_mode BOOLEAN DEFAULT TRUE,
    dvr_enabled BOOLEAN DEFAULT TRUE,
    enable_chat_relay BOOLEAN DEFAULT TRUE,
    custom_rtmp_url VARCHAR(500) DEFAULT 'rtmp://live.edushamiit.internal/stream',
    custom_stream_key VARCHAR(255) DEFAULT 'shamiit_live_key_sec_884920',
    metadata JSONB DEFAULT '{}'::jsonb,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for lightning fast lookups
CREATE INDEX IF NOT EXISTS idx_live_broadcasts_status ON live_broadcasts(status);
CREATE INDEX IF NOT EXISTS idx_live_broadcasts_inst ON live_broadcasts(institute_id);
CREATE INDEX IF NOT EXISTS idx_broadcast_dest_bid ON broadcast_destinations(broadcast_id);
CREATE INDEX IF NOT EXISTS idx_broadcast_analytics_bid ON broadcast_analytics_snapshots(broadcast_id);

-- Stored Procedures

-- 1. sp_get_streaming_overview
CREATE OR REPLACE FUNCTION sp_get_streaming_overview(p_institute_id INTEGER DEFAULT 1)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_active_broadcast RECORD;
    v_destinations JSONB;
    v_analytics JSONB;
    v_scheduled JSONB;
    v_result JSONB;
BEGIN
    -- Check for live broadcast or most recent active/paused
    SELECT * INTO v_active_broadcast
    FROM live_broadcasts
    WHERE institute_id = p_institute_id AND status IN ('live', 'paused')
    ORDER BY id DESC LIMIT 1;

    -- If no live broadcast, get the latest one
    IF v_active_broadcast.id IS NULL THEN
        SELECT * INTO v_active_broadcast
        FROM live_broadcasts
        WHERE institute_id = p_institute_id
        ORDER BY id DESC LIMIT 1;
    END IF;

    -- Platform Destinations
    IF v_active_broadcast.id IS NOT NULL THEN
        SELECT jsonb_agg(
            jsonb_build_object(
                'id', d.id,
                'platformKey', d.platform_key,
                'destinationName', d.destination_name,
                'rtmpUrl', d.rtmp_url,
                'streamKey', d.stream_key,
                'isActive', d.is_active,
                'isConnected', d.is_connected,
                'syncStatus', d.sync_status,
                'viewers', d.destination_viewers
            )
        ) INTO v_destinations
        FROM broadcast_destinations d
        WHERE d.broadcast_id = v_active_broadcast.id;

        -- Analytics Trend Points
        SELECT jsonb_agg(
            jsonb_build_object(
                'minuteMark', a.minute_mark,
                'viewerCount', a.viewer_count
            ) ORDER BY a.id ASC
        ) INTO v_analytics
        FROM broadcast_analytics_snapshots a
        WHERE a.broadcast_id = v_active_broadcast.id;
    END IF;

    -- Upcoming Scheduled Broadcasts (preview in Live tab)
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', b.id,
            'broadcastCode', b.broadcast_code,
            'title', b.title,
            'classSubject', COALESCE(b.class_subject_label, b.title),
            'scheduledDate', to_char(b.scheduled_start_time, 'Dy, DD Mon YYYY'),
            'scheduledTime', to_char(b.scheduled_start_time, 'HH12:MI AM'),
            'platform', COALESCE(b.metadata->>'primary_platform', 'youtube'),
            'status', b.status
        ) ORDER BY b.scheduled_start_time ASC
    ) INTO v_scheduled
    FROM live_broadcasts b
    WHERE b.institute_id = p_institute_id 
      AND b.status = 'scheduled'
    LIMIT 5;

    v_result := jsonb_build_object(
        'activeBroadcast', CASE WHEN v_active_broadcast.id IS NOT NULL THEN jsonb_build_object(
            'id', v_active_broadcast.id,
            'broadcastCode', v_active_broadcast.broadcast_code,
            'title', v_active_broadcast.title,
            'description', v_active_broadcast.description,
            'category', v_active_broadcast.category,
            'privacy', v_active_broadcast.privacy,
            'streamQuality', v_active_broadcast.stream_quality,
            'bitrateMode', v_active_broadcast.bitrate_mode,
            'status', v_active_broadcast.status,
            'uptimeSeconds', v_active_broadcast.current_duration_seconds,
            'currentViewers', v_active_broadcast.current_viewers,
            'totalViews', v_active_broadcast.total_views,
            'likesCount', v_active_broadcast.likes_count,
            'streamHealth', v_active_broadcast.stream_health,
            'resolution', v_active_broadcast.resolution,
            'actualBitrateKbps', v_active_broadcast.actual_bitrate_kbps,
            'actualFps', v_active_broadcast.actual_fps,
            'recordingUrl', v_active_broadcast.recording_url
        ) ELSE NULL END,
        'destinations', COALESCE(v_destinations, '[]'::jsonb),
        'analyticsPoints', COALESCE(v_analytics, '[]'::jsonb),
        'scheduledBroadcasts', COALESCE(v_scheduled, '[]'::jsonb)
    );

    RETURN v_result;
END;
$$;

-- 2. sp_create_broadcast
CREATE OR REPLACE FUNCTION sp_create_broadcast(
    p_title VARCHAR(255),
    p_description TEXT,
    p_category VARCHAR(100),
    p_privacy VARCHAR(50),
    p_stream_quality VARCHAR(50),
    p_bitrate_mode VARCHAR(50),
    p_institute_id INTEGER DEFAULT 1
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_code VARCHAR(50);
    v_new_id INTEGER;
BEGIN
    v_code := 'BC-' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD-HH24MISS');
    
    INSERT INTO live_broadcasts (
        broadcast_code, institute_id, title, description, category, privacy,
        stream_quality, bitrate_mode, status
    ) VALUES (
        v_code, p_institute_id, p_title, p_description, p_category, p_privacy,
        p_stream_quality, p_bitrate_mode, 'draft'
    ) RETURNING id INTO v_new_id;

    -- Add default destinations for this broadcast from platform accounts
    INSERT INTO broadcast_destinations (broadcast_id, platform_key, destination_name, rtmp_url, stream_key, is_active, is_connected, sync_status)
    SELECT v_new_id, a.platform_key, a.platform_name, a.server_url, a.stream_key, a.is_enabled, a.is_connected, 'ready'
    FROM broadcast_platform_accounts a
    WHERE a.institute_id = p_institute_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'broadcastId', v_new_id,
        'broadcastCode', v_code,
        'message', 'Broadcast created successfully'
    );
END;
$$;

-- 3. sp_start_broadcast
CREATE OR REPLACE FUNCTION sp_start_broadcast(p_broadcast_id INTEGER)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE live_broadcasts
    SET status = 'live',
        started_at = COALESCE(started_at, CURRENT_TIMESTAMP),
        stream_health = 'Excellent',
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_broadcast_id;

    UPDATE broadcast_destinations
    SET sync_status = 'streaming'
    WHERE broadcast_id = p_broadcast_id AND is_active = TRUE;

    RETURN jsonb_build_object(
        'success', TRUE,
        'broadcastId', p_broadcast_id,
        'status', 'live',
        'message', 'Broadcast went live'
    );
END;
$$;

-- 4. sp_pause_broadcast
CREATE OR REPLACE FUNCTION sp_pause_broadcast(p_broadcast_id INTEGER)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE live_broadcasts
    SET status = 'paused',
        stream_health = 'Fair',
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_broadcast_id;

    UPDATE broadcast_destinations
    SET sync_status = 'paused'
    WHERE broadcast_id = p_broadcast_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'broadcastId', p_broadcast_id,
        'status', 'paused',
        'message', 'Broadcast paused'
    );
END;
$$;

-- 5. sp_resume_broadcast
CREATE OR REPLACE FUNCTION sp_resume_broadcast(p_broadcast_id INTEGER)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE live_broadcasts
    SET status = 'live',
        stream_health = 'Excellent',
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_broadcast_id;

    UPDATE broadcast_destinations
    SET sync_status = 'streaming'
    WHERE broadcast_id = p_broadcast_id AND is_active = TRUE;

    RETURN jsonb_build_object(
        'success', TRUE,
        'broadcastId', p_broadcast_id,
        'status', 'live',
        'message', 'Broadcast resumed'
    );
END;
$$;

-- 6. sp_stop_broadcast
CREATE OR REPLACE FUNCTION sp_stop_broadcast(p_broadcast_id INTEGER)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE live_broadcasts
    SET status = 'ended',
        ended_at = CURRENT_TIMESTAMP,
        stream_health = 'Offline',
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_broadcast_id;

    UPDATE broadcast_destinations
    SET sync_status = 'offline'
    WHERE broadcast_id = p_broadcast_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'broadcastId', p_broadcast_id,
        'status', 'ended',
        'message', 'Broadcast stopped'
    );
END;
$$;

-- 7. sp_toggle_destination_assignment
CREATE OR REPLACE FUNCTION sp_toggle_destination_assignment(p_destination_id INTEGER, p_is_active BOOLEAN)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE broadcast_destinations
    SET is_active = p_is_active,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_destination_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'destinationId', p_destination_id,
        'isActive', p_is_active
    );
END;
$$;

-- 8. sp_add_broadcast_destination
CREATE OR REPLACE FUNCTION sp_add_broadcast_destination(
    p_broadcast_id INTEGER,
    p_platform_key VARCHAR(50),
    p_name VARCHAR(100),
    p_rtmp_url VARCHAR(500),
    p_stream_key VARCHAR(500)
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_dest_id INTEGER;
BEGIN
    INSERT INTO broadcast_destinations (
        broadcast_id, platform_key, destination_name, rtmp_url, stream_key,
        is_active, is_connected, sync_status
    ) VALUES (
        p_broadcast_id, p_platform_key, p_name, p_rtmp_url, p_stream_key,
        TRUE, TRUE, 'ready'
    ) RETURNING id INTO v_dest_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'destinationId', v_dest_id,
        'message', 'Destination added successfully'
    );
END;
$$;

-- 9. sp_get_scheduled_broadcasts
CREATE OR REPLACE FUNCTION sp_get_scheduled_broadcasts(p_institute_id INTEGER DEFAULT 1)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_list JSONB;
BEGIN
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', b.id,
            'broadcastCode', b.broadcast_code,
            'title', b.title,
            'description', b.description,
            'classSubject', COALESCE(b.class_subject_label, b.title),
            'scheduledDate', to_char(b.scheduled_start_time, 'Dy, DD Mon YYYY'),
            'scheduledTime', to_char(b.scheduled_start_time, 'HH12:MI AM'),
            'platform', COALESCE(b.metadata->>'primary_platform', 'youtube'),
            'privacy', b.privacy,
            'quality', b.stream_quality,
            'status', b.status
        ) ORDER BY b.scheduled_start_time ASC
    ) INTO v_list
    FROM live_broadcasts b
    WHERE b.institute_id = p_institute_id AND b.status = 'scheduled';

    RETURN COALESCE(v_list, '[]'::jsonb);
END;
$$;

-- 10. sp_schedule_broadcast
CREATE OR REPLACE FUNCTION sp_schedule_broadcast(
    p_title VARCHAR(255),
    p_description TEXT,
    p_class_subject VARCHAR(150),
    p_scheduled_time TIMESTAMP WITH TIME ZONE,
    p_platform VARCHAR(50),
    p_privacy VARCHAR(50),
    p_quality VARCHAR(50),
    p_institute_id INTEGER DEFAULT 1
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_code VARCHAR(50);
    v_new_id INTEGER;
BEGIN
    v_code := 'SCHED-' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD-HH24MISS');

    INSERT INTO live_broadcasts (
        broadcast_code, institute_id, title, description, class_subject_label,
        scheduled_start_time, privacy, stream_quality, status, metadata
    ) VALUES (
        v_code, p_institute_id, p_title, p_description, p_class_subject,
        p_scheduled_time, p_privacy, p_quality, 'scheduled',
        jsonb_build_object('primary_platform', p_platform)
    ) RETURNING id INTO v_new_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'broadcastId', v_new_id,
        'broadcastCode', v_code,
        'message', 'Broadcast scheduled successfully'
    );
END;
$$;

-- 11. sp_get_past_streams
CREATE OR REPLACE FUNCTION sp_get_past_streams(p_institute_id INTEGER DEFAULT 1)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_list JSONB;
BEGIN
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', b.id,
            'broadcastCode', b.broadcast_code,
            'title', b.title,
            'classSubject', COALESCE(b.class_subject_label, b.title),
            'streamedOn', to_char(COALESCE(b.started_at, b.created_at), 'DD Mon YYYY, HH12:MI AM'),
            'durationMinutes', ROUND(b.current_duration_seconds / 60.0, 1),
            'totalViews', b.total_views,
            'peakViewers', b.peak_viewers,
            'likes', b.likes_count,
            'recordingUrl', b.recording_url,
            'status', b.status
        ) ORDER BY b.id DESC
    ) INTO v_list
    FROM live_broadcasts b
    WHERE b.institute_id = p_institute_id AND b.status = 'ended';

    RETURN COALESCE(v_list, '[]'::jsonb);
END;
$$;

-- 12. sp_get_stream_analytics
CREATE OR REPLACE FUNCTION sp_get_stream_analytics(p_institute_id INTEGER DEFAULT 1)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_broadcasts INTEGER;
    v_total_watch_hours NUMERIC(10,2);
    v_total_views INTEGER;
    v_avg_engagement_pct NUMERIC(5,2);
    v_platforms JSONB;
    v_recent_streams JSONB;
BEGIN
    SELECT 
        COUNT(*),
        COALESCE(SUM(current_duration_seconds * current_viewers) / 3600.0, 482.5),
        COALESCE(SUM(total_views), 18450),
        88.5
    INTO v_total_broadcasts, v_total_watch_hours, v_total_views, v_avg_engagement_pct
    FROM live_broadcasts
    WHERE institute_id = p_institute_id;

    -- Platform shares
    v_platforms := jsonb_build_array(
        jsonb_build_object('platform', 'YouTube Live', 'viewersPct', 58, 'viewsCount', 10700),
        jsonb_build_object('platform', 'Facebook Live', 'viewersPct', 24, 'viewsCount', 4430),
        jsonb_build_object('platform', 'EduSHAMIIT Portal / Custom RTMP', 'viewersPct', 18, 'viewsCount', 3320)
    );

    RETURN jsonb_build_object(
        'totalBroadcasts', v_total_broadcasts,
        'totalWatchHours', ROUND(v_total_watch_hours, 1),
        'totalViews', v_total_views,
        'avgEngagementPct', v_avg_engagement_pct,
        'platformBreakdown', v_platforms
    );
END;
$$;

-- 13. sp_get_broadcast_settings
CREATE OR REPLACE FUNCTION sp_get_broadcast_settings(p_institute_id INTEGER DEFAULT 1)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_settings RECORD;
BEGIN
    SELECT * INTO v_settings
    FROM broadcast_settings
    WHERE institute_id = p_institute_id
    LIMIT 1;

    IF v_settings.id IS NULL THEN
        INSERT INTO broadcast_settings (institute_id) VALUES (p_institute_id)
        RETURNING * INTO v_settings;
    END IF;

    RETURN jsonb_build_object(
        'id', v_settings.id,
        'defaultQuality', v_settings.default_quality,
        'defaultBitrateMode', v_settings.default_bitrate_mode,
        'defaultPrivacy', v_settings.default_privacy,
        'defaultCategory', v_settings.default_category,
        'autoRecordBroadcasts', v_settings.auto_record_broadcasts,
        'lowLatencyMode', v_settings.low_latency_mode,
        'dvrEnabled', v_settings.dvr_enabled,
        'enableChatRelay', v_settings.enable_chat_relay,
        'customRtmpUrl', v_settings.custom_rtmp_url,
        'customStreamKey', v_settings.custom_stream_key
    );
END;
$$;

-- 14. sp_update_broadcast_settings
CREATE OR REPLACE FUNCTION sp_update_broadcast_settings(
    p_default_quality VARCHAR(50),
    p_default_bitrate_mode VARCHAR(50),
    p_default_privacy VARCHAR(50),
    p_default_category VARCHAR(100),
    p_auto_record BOOLEAN,
    p_low_latency BOOLEAN,
    p_dvr_enabled BOOLEAN,
    p_chat_relay BOOLEAN,
    p_custom_rtmp_url VARCHAR(500),
    p_institute_id INTEGER DEFAULT 1
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE broadcast_settings
    SET default_quality = p_default_quality,
        default_bitrate_mode = p_default_bitrate_mode,
        default_privacy = p_default_privacy,
        default_category = p_default_category,
        auto_record_broadcasts = p_auto_record,
        low_latency_mode = p_low_latency,
        dvr_enabled = p_dvr_enabled,
        enable_chat_relay = p_chat_relay,
        custom_rtmp_url = p_custom_rtmp_url,
        updated_at = CURRENT_TIMESTAMP
    WHERE institute_id = p_institute_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Broadcast settings updated successfully'
    );
END;
$$;
