-- Migration 100: Enhance Live Classes with High Fidelity Mockup Seed Data
-- EduSHAMIIT — Shami Innovation and Technologies LLP

-- Delete any existing sample live classes and comments to ensure clean state
DELETE FROM live_class_comments WHERE live_class_id IN (SELECT id FROM live_classes WHERE target_class = '10A');
DELETE FROM live_classes WHERE target_class = '10A';

-- Insert Live Classes for Class 10A matching the mockup exactly
INSERT INTO live_classes (
    id, school_id, subject_id, teacher_id, title, description,
    scheduled_at, duration_minutes, platform, stream_url, recording_url,
    is_live, viewer_count, target_class, status
) VALUES
  -- 1. Physics Live Now
  (
    'a1000000-0000-0000-0000-000000000001',
    '11111111-1111-1111-1111-111111111111',
    '11c305b2-5cf6-4341-8050-1333acf8f815', -- Physics 10A
    'aa000002-0000-0000-0000-000000000002', -- Dr. Arjun Verma
    'Physics — Optics Chapter 9',
    'Live session on Wave Optics, Reflection, and Refraction concepts.',
    NOW() - INTERVAL '25 minutes',
    60,
    'EduSHAMIIT',
    'https://www.youtube.com/embed/dQw4w9WgXcQ?autoplay=1&mute=1&modestbranding=1&rel=0',
    NULL,
    TRUE,
    34,
    '10A',
    'live'
  ),
  -- 2. Mathematics Live Now
  (
    'a1000000-0000-0000-0000-000000000002',
    '11111111-1111-1111-1111-111111111111',
    'e1008873-1ccf-48f9-8ce0-110ff3bce421', -- Mathematics 10A
    'aa000001-0000-0000-0000-000000000001', -- Mrs. Priya Sharma
    'Mathematics — Integration by Parts',
    'Dynamic problem solving workshop covering advanced calculus Integration by Parts technique.',
    NOW() - INTERVAL '10 minutes',
    60,
    'EduSHAMIIT',
    'https://www.youtube.com/embed/dQw4w9WgXcQ?autoplay=1&mute=1&modestbranding=1&rel=0',
    NULL,
    TRUE,
    28,
    '10A',
    'live'
  ),
  -- 3. Chemistry Upcoming
  (
    'a1000000-0000-0000-0000-000000000003',
    '11111111-1111-1111-1111-111111111111',
    'de23de6c-0574-4501-80cb-5bd150d8eac9', -- Chemistry 10A
    'aa000004-0000-0000-0000-000000000004', -- Dr. Suresh Mehta
    'Chemistry — Electrochemistry',
    'Live scheduled session on Electrochemistry, redox reactions, and Galvanic cells.',
    NOW() + INTERVAL '1.5 hours',
    60,
    'EduSHAMIIT',
    NULL,
    NULL,
    FALSE,
    0,
    '10A',
    'scheduled'
  ),
  -- 4. English Upcoming
  (
    'a1000000-0000-0000-0000-000000000004',
    '11111111-1111-1111-1111-111111111111',
    '5f45ac94-a452-42c4-bfa1-1538c2b0b1cb', -- English 10A
    'aa000003-0000-0000-0000-000000000003', -- Ms. Preethi Gupta
    'English — Essay Writing',
    'Live seminar detailing essay writing structures, outline creation, and vocabulary.',
    NOW() + INTERVAL '3 hours',
    60,
    'EduSHAMIIT',
    NULL,
    NULL,
    FALSE,
    0,
    '10A',
    'scheduled'
  ),
  -- 5. Physics Recorded
  (
    'a1000000-0000-0000-0000-000000000005',
    '11111111-1111-1111-1111-111111111111',
    '11c305b2-5cf6-4341-8050-1333acf8f815', -- Physics 10A
    'aa000002-0000-0000-0000-000000000002', -- Dr. Arjun Verma
    'Physics — Wave Optics',
    'Recording of Wave Optics lecture detailing double-slit interference patterns.',
    NOW() - INTERVAL '1 day',
    45,
    'EduSHAMIIT',
    NULL,
    'https://www.youtube.com/embed/dQw4w9WgXcQ?autoplay=1&mute=1&modestbranding=1&rel=0',
    FALSE,
    856,
    '10A',
    'recorded'
  ),
  -- 6. Mathematics Recorded
  (
    'a1000000-0000-0000-0000-000000000006',
    '11111111-1111-1111-1111-111111111111',
    'e1008873-1ccf-48f9-8ce0-110ff3bce421', -- Math 10A
    'aa000001-0000-0000-0000-000000000001', -- Mrs. Priya Sharma
    'Mathematics — Limits',
    'Recording of introductory limits class, calculus fundamentals, and continuous functions.',
    NOW() - INTERVAL '2 days',
    52,
    'EduSHAMIIT',
    NULL,
    'https://www.youtube.com/embed/dQw4w9WgXcQ?autoplay=1&mute=1&modestbranding=1&rel=0',
    FALSE,
    720,
    '10A',
    'recorded'
  ),
  -- 7. Chemistry Recorded
  (
    'a1000000-0000-0000-0000-000000000007',
    '11111111-1111-1111-1111-111111111111',
    'de23de6c-0574-4501-80cb-5bd150d8eac9', -- Chemistry 10A
    'aa000004-0000-0000-0000-000000000004', -- Dr. Suresh Mehta
    'Chemistry — Periodic Table',
    'Recording of periodic properties lecture detailing atomic radius and ionization trends.',
    NOW() - INTERVAL '3 days',
    38,
    'EduSHAMIIT',
    NULL,
    'https://www.youtube.com/embed/dQw4w9WgXcQ?autoplay=1&mute=1&modestbranding=1&rel=0',
    FALSE,
    640,
    '10A',
    'recorded'
  );

-- Seed high-fidelity comments for Physics live class matching the mockup exactly
INSERT INTO live_class_comments (
    id, school_id, live_class_id, user_id, comment, is_pinned, likes, created_at
) VALUES
  -- 1. Pinned comment by teacher
  (
    'c1000000-0000-0000-0000-000000000001',
    '11111111-1111-1111-1111-111111111111',
    'a1000000-0000-0000-0000-000000000001',
    'aa000002-0000-0000-0000-000000000002', -- Dr. Arjun Verma
    'Today we''ll cover Chapter 9: Optics. Please keep your NCERT books open on page 312. Ask doubts in the comment section!',
    TRUE,
    45,
    NOW() - INTERVAL '25 minutes'
  ),
  -- 2. Priya M Comment
  (
    'c1000000-0000-0000-0000-000000000002',
    '11111111-1111-1111-1111-111111111111',
    'a1000000-0000-0000-0000-000000000001',
    '073cf4b4-7678-4a9d-bca8-a186d4e3bf5e', -- student profile Naresh Upadhyay
    'Sir, can you explain the ILATE rule once more? Which function should be u?',
    FALSE,
    12,
    NOW() - INTERVAL '20 minutes'
  ),
  -- 3. Rahul V Comment
  (
    'c1000000-0000-0000-0000-000000000003',
    '11111111-1111-1111-1111-111111111111',
    'a1000000-0000-0000-0000-000000000001',
    '073cf4b4-7678-4a9d-bca8-a186d4e3bf5e',
    'This is the best explanation! Understood everything clearly 🔥🔥',
    FALSE,
    8,
    NOW() - INTERVAL '18 minutes'
  ),
  -- 4. Neha S Comment
  (
    'c1000000-0000-0000-0000-000000000004',
    '11111111-1111-1111-1111-111111111111',
    'a1000000-0000-0000-0000-000000000001',
    '073cf4b4-7678-4a9d-bca8-a186d4e3bf5e',
    'Can we get a practice problem after this section? 🙌',
    FALSE,
    5,
    NOW() - INTERVAL '15 minutes'
  );
