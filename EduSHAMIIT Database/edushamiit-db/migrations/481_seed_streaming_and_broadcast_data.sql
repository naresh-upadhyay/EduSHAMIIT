-- Migration 481: Seed Streaming & Broadcast System Data
-- EduSHAMIIT Live Class Management -> Join & Conduct -> Streaming & Broadcast

DO $$
DECLARE
    v_broadcast_id INTEGER;
    v_past_1 INTEGER;
    v_past_2 INTEGER;
    v_past_3 INTEGER;
BEGIN
    -- 1. Ensure broadcast settings exist
    INSERT INTO broadcast_settings (
        institute_id, default_quality, default_bitrate_mode, default_privacy,
        default_category, auto_record_broadcasts, low_latency_mode, dvr_enabled,
        enable_chat_relay, custom_rtmp_url, custom_stream_key
    ) VALUES (
        1, '1080p (Full HD)', 'Auto (Recommended)', 'Public',
        'Education', TRUE, TRUE, TRUE,
        TRUE, 'rtmp://live.edushamiit.internal/stream', 'shamiit_live_key_sec_884920'
    ) ON CONFLICT (institute_id) DO UPDATE SET
        default_quality = EXCLUDED.default_quality,
        default_bitrate_mode = EXCLUDED.default_bitrate_mode,
        updated_at = CURRENT_TIMESTAMP;

    -- 2. Platform Accounts
    DELETE FROM broadcast_platform_accounts WHERE institute_id = 1;

    INSERT INTO broadcast_platform_accounts (
        institute_id, platform_key, platform_name, account_email, channel_name,
        server_url, stream_key, is_connected, is_enabled
    ) VALUES
    (1, 'youtube', 'YouTube Live', 'admin@edushamiit.org', 'EduSHAMIIT Official Channel', 'rtmp://a.rtmp.youtube.com/live2', 'yt_live_edushamiit_9837a281', TRUE, TRUE),
    (1, 'facebook', 'Facebook Live', 'social@edushamiit.org', 'EduSHAMIIT Academy Page', 'rtmps://live-api-s.facebook.com:443/rtmp/', 'fb_live_sec_738491823', TRUE, TRUE),
    (1, 'teams', 'Microsoft Teams', 'teams@edushamiit.org', 'EduSHAMIIT Academic Hub', 'rtmp://teams.edushamiit.org/live', 'teams_key_3847291', FALSE, FALSE),
    (1, 'zoom', 'Zoom Webinar', 'zoom@edushamiit.org', 'EduSHAMIIT Webinar Room', 'rtmp://zoom.edushamiit.org/live', 'zoom_key_9182749', FALSE, FALSE),
    (1, 'custom_rtmp', 'Custom RTMP', 'tech@edushamiit.org', 'EduSHAMIIT Custom CDN Relay', 'rtmp://live.edushamiit.internal/stream', 'shamiit_live_key_sec_884920', TRUE, TRUE);

    -- 3. Live Broadcast matching mockup
    DELETE FROM live_broadcasts WHERE broadcast_code IN ('BC-LIVE-MATH10A', 'SCHED-MATH10', 'SCHED-PHY11', 'SCHED-CHEM12', 'PAST-SCI10', 'PAST-ENG9', 'PAST-MATH11');

    INSERT INTO live_broadcasts (
        broadcast_code, institute_id, title, description, category, privacy,
        stream_quality, bitrate_mode, target_bitrate_kbps, target_fps, status,
        started_at, current_duration_seconds, current_viewers, total_views, peak_viewers,
        likes_count, stream_health, resolution, actual_bitrate_kbps, actual_fps,
        recording_url, scheduled_start_time, class_subject_label, metadata
    ) VALUES (
        'BC-LIVE-MATH10A', 1,
        'Class 10 - Mathematics: Quadratic Equations',
        'Live class on Quadratic Equations, formula, roots and real-life applications.',
        'Education', 'Public', '1080p (Full HD)', 'Auto (Recommended)', 4500, 30, 'live',
        CURRENT_TIMESTAMP - INTERVAL '27 minutes 18 seconds',
        1638, 426, 1248, 489, 267,
        'Excellent', '1080p', 4500, 30,
        'https://storage.edushamiit.internal/recordings/math_quadratic_equations_live.mp4',
        CURRENT_TIMESTAMP - INTERVAL '30 minutes',
        'Class 10 - A : Mathematics',
        '{"teacher_name": "R. Kumar", "subject": "Mathematics", "class": "Class 10 - A", "topic": "Quadratic Equations"}'::jsonb
    ) RETURNING id INTO v_broadcast_id;

    -- Destinations for active live broadcast
    INSERT INTO broadcast_destinations (
        broadcast_id, platform_key, destination_name, rtmp_url, stream_key,
        is_active, is_connected, sync_status, destination_viewers
    ) VALUES
    (v_broadcast_id, 'youtube', 'YouTube Live', 'rtmp://a.rtmp.youtube.com/live2', 'yt_live_edushamiit_9837a281', TRUE, TRUE, 'streaming', 248),
    (v_broadcast_id, 'facebook', 'Facebook Live', 'rtmps://live-api-s.facebook.com:443/rtmp/', 'fb_live_sec_738491823', TRUE, TRUE, 'streaming', 104),
    (v_broadcast_id, 'teams', 'Microsoft Teams', 'rtmp://teams.edushamiit.org/live', 'teams_key_3847291', FALSE, FALSE, 'ready', 0),
    (v_broadcast_id, 'zoom', 'Zoom Webinar', 'rtmp://zoom.edushamiit.org/live', 'zoom_key_9182749', FALSE, FALSE, 'ready', 0),
    (v_broadcast_id, 'custom_rtmp', 'Custom RTMP', 'rtmp://live.edushamiit.internal/stream', 'shamiit_live_key_sec_884920', TRUE, TRUE, 'streaming', 74);

    -- Analytics curve matching mockup (45 -> 160 -> 250 -> 310 -> 360 -> 410 -> 426)
    INSERT INTO broadcast_analytics_snapshots (broadcast_id, minute_mark, viewer_count)
    VALUES
    (v_broadcast_id, '00:00', 45),
    (v_broadcast_id, '05:00', 160),
    (v_broadcast_id, '10:00', 250),
    (v_broadcast_id, '15:00', 310),
    (v_broadcast_id, '20:00', 360),
    (v_broadcast_id, '25:00', 410),
    (v_broadcast_id, '27:18', 426);

    -- Scheduled Broadcasts (Upcoming)
    INSERT INTO live_broadcasts (
        broadcast_code, institute_id, title, description, class_subject_label,
        scheduled_start_time, privacy, stream_quality, status, metadata
    ) VALUES
    ('SCHED-MATH10', 1, 'Class 10 - Mathematics: Coordinate Geometry', 'Upcoming comprehensive live session on coordinate planes and distance formulas.', 'Class 10 - Mathematics',
     CURRENT_TIMESTAMP + INTERVAL '1 day 2 hours', 'Public', '1080p (Full HD)', 'scheduled', '{"primary_platform": "youtube"}'::jsonb),
    ('SCHED-PHY11', 1, 'Class 11 - Physics: Laws of Motion & Friction', 'In-depth interactive discussion on Newton''s Laws with visual experiments.', 'Class 11 - Physics',
     CURRENT_TIMESTAMP + INTERVAL '3 days 4 hours', 'Public', '1080p (Full HD)', 'scheduled', '{"primary_platform": "facebook"}'::jsonb),
    ('SCHED-CHEM12', 1, 'Class 12 - Chemistry: Organic Compounds Reactions', 'Mastering reaction mechanisms and functional groups.', 'Class 12 - Chemistry',
     CURRENT_TIMESTAMP + INTERVAL '6 days 6 hours', 'Public', '1080p (Full HD)', 'scheduled', '{"primary_platform": "youtube"}'::jsonb);

    -- Past Streams
    INSERT INTO live_broadcasts (
        broadcast_code, institute_id, title, class_subject_label, status,
        started_at, ended_at, current_duration_seconds, total_views, peak_viewers,
        likes_count, recording_url
    ) VALUES
    ('PAST-SCI10', 1, 'Class 10 - Science: Chemical Reactions & Equations', 'Class 10 - Science', 'ended',
     CURRENT_TIMESTAMP - INTERVAL '2 days 3 hours', CURRENT_TIMESTAMP - INTERVAL '2 days 2 hours 15 minutes', 2712, 1420, 480, 312, 'https://storage.edushamiit.internal/recordings/science_10_reactions.mp4'),
    ('PAST-ENG9', 1, 'Class 9 - English: Poetry - The Road Not Taken', 'Class 9 - English', 'ended',
     CURRENT_TIMESTAMP - INTERVAL '4 days 5 hours', CURRENT_TIMESTAMP - INTERVAL '4 days 4 hours 18 minutes', 2520, 980, 340, 195, 'https://storage.edushamiit.internal/recordings/english_9_poetry.mp4'),
    ('PAST-MATH11', 1, 'Class 11 - Mathematics: Trigonometric Functions', 'Class 11 - Mathematics', 'ended',
     CURRENT_TIMESTAMP - INTERVAL '6 days 1 hour', CURRENT_TIMESTAMP - INTERVAL '6 days 12 minutes', 3030, 2150, 610, 520, 'https://storage.edushamiit.internal/recordings/math_11_trig.mp4');

END $$;
