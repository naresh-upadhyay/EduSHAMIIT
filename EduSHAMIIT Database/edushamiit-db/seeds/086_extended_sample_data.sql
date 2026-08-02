-- ============================================================
-- Migration 086: Extended Realistic Data (v7)
-- Seeding remaining tables for a complete application experience
-- ============================================================

-- ── SCHOOLS ──────────────────────────────────────────────────
INSERT INTO schools (id, name, address, phone, logo_url)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'EduVerse International School', '123 Academic Hub, Knowledge City, Pune', '+91-20-27654321', 'https://eduverse.school/logo.png')
ON CONFLICT (id) DO NOTHING;


-- ── COURSES ──────────────────────────────────────────────────
INSERT INTO courses (id, school_id, subject_id, teacher_id, title, description, status)
VALUES
  ('a4000001-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'cc000001-0000-0000-0000-000000000001', 'aa000001-0000-0000-0000-000000000001', 'Advanced Calculus Masterclass', 'A deep dive into integration and differentiation for Class X.', 'active'),
  ('a4000002-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'cc000004-0000-0000-0000-000000000004', 'aa000002-0000-0000-0000-000000000002', 'Quantum Physics for Beginners', 'Introduction to modern physics concepts.', 'active'),
  ('a4000003-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'cc000005-0000-0000-0000-000000000005', 'aa000004-0000-0000-0000-000000000004', 'Organic Chemistry Essentials', 'Mastering carbon compounds and reactions.', 'active'),
  ('a4000004-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', 'cc000008-0000-0000-0000-000000000008', 'aa000006-0000-0000-0000-000000000006', 'Python Programming Bootcamp', 'Learn coding from scratch with Python.', 'active'),
  ('a4000005-0000-0000-0000-000000000005', '11111111-1111-1111-1111-111111111111', 'cc000006-0000-0000-0000-000000000006', 'aa000003-0000-0000-0000-000000000003', 'Creative Writing Workshop', 'Improve your storytelling and essay writing.', 'active')
ON CONFLICT (id) DO NOTHING;


-- ── DOCUMENTS ────────────────────────────────────────────────
INSERT INTO documents (id, school_id, user_id, document_type, file_url, file_name, verification_status)
VALUES
  ('b4000001-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'bb000001-0000-0000-0000-000000000001', 'ID Card', 'https://eduverse.school/docs/arjun_id.pdf', 'arjun_id.pdf', 'verified'),
  ('b4000002-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'bb000002-0000-0000-0000-000000000002', 'Transfer Certificate', 'https://eduverse.school/docs/riya_tc.pdf', 'riya_tc.pdf', 'pending'),
  ('b4000003-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'aa000001-0000-0000-0000-000000000001', 'Degree Certificate', 'https://eduverse.school/docs/priya_msc.pdf', 'priya_msc.pdf', 'verified'),
  ('b4000004-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', 'bb000004-0000-0000-0000-000000000004', 'Medical Report', 'https://eduverse.school/docs/neha_med.pdf', 'neha_med.pdf', 'verified')
ON CONFLICT (id) DO NOTHING;


-- ── EVENT REGISTRATIONS ──────────────────────────────────────
INSERT INTO event_registrations (id, school_id, event_id, student_id, status)
VALUES
  ('c4000001-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'f2000001-0000-0000-0000-000000000001', 'bb000001-0000-0000-0000-000000000001', 'confirmed'),
  ('c4000002-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'f2000001-0000-0000-0000-000000000001', 'bb000002-0000-0000-0000-000000000002', 'confirmed'),
  ('c4000003-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'f2000002-0000-0000-0000-000000000002', 'bb000004-0000-0000-0000-000000000004', 'confirmed'),
  ('c4000004-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', 'f2000004-0000-0000-0000-000000000004', 'bb000001-0000-0000-0000-000000000001', 'pending')
ON CONFLICT (id) DO NOTHING;


-- ── EXAM QUESTIONS ───────────────────────────────────────────
INSERT INTO exam_questions (id, exam_id, question_text, question_type, options, correct_answer, marks, order_number)
VALUES
  ('d4000001-0000-0000-0000-000000000001', 'a1000001-0000-0000-0000-000000000001', 'What is the integral of sin(x)?', 'multiple_choice', '{"A": "cos(x)", "B": "-cos(x)", "C": "tan(x)", "D": "-sin(x)"}', 'B', 2, 1),
  ('d4000002-0000-0000-0000-000000000002', 'a1000001-0000-0000-0000-000000000001', 'Define a derivative.', 'descriptive', null, null, 5, 2),
  ('d4000003-0000-0000-0000-000000000003', 'a1000001-0000-0000-0000-000000000001', 'The square of 15 is 225.', 'true_false', '{"T": "True", "F": "False"}', 'T', 1, 3),
  ('d4000004-0000-0000-0000-000000000004', 'a1000006-0000-0000-0000-000000000006', 'Who developed the Mirror Formula?', 'multiple_choice', '{"A": "Newton", "B": "Einstein", "C": "Descartes", "D": "Kepler"}', 'C', 2, 1)
ON CONFLICT (id) DO NOTHING;


-- ── EXAM SESSIONS ───────────────────────────────────────────
INSERT INTO exam_sessions (id, exam_id, student_id, started_at, status)
VALUES
  ('e5000001-0000-0000-0000-000000000001', 'a1000006-0000-0000-0000-000000000006', 'bb000001-0000-0000-0000-000000000001', NOW() - INTERVAL '30 days', 'completed'),
  ('e5000002-0000-0000-0000-000000000002', 'a1000006-0000-0000-0000-000000000006', 'bb000004-0000-0000-0000-000000000004', NOW() - INTERVAL '30 days', 'completed')
ON CONFLICT (id) DO NOTHING;


-- ── EXAM SUBMISSIONS ─────────────────────────────────────────
INSERT INTO exam_submissions (id, exam_id, student_id, answers, score, status)
VALUES
  ('f5000001-0000-0000-0000-000000000001', 'a1000006-0000-0000-0000-000000000006', 'bb000001-0000-0000-0000-000000000001', '{"q1": "B", "q2": "Slope of tangent"}', 48, 'graded'),
  ('f5000002-0000-0000-0000-000000000002', 'a1000006-0000-0000-0000-000000000006', 'bb000004-0000-0000-0000-000000000004', '{"q1": "B", "q2": "Rate of change"}', 49, 'graded')
ON CONFLICT (id) DO NOTHING;


-- ── GRADING POLICIES ─────────────────────────────────────────
INSERT INTO grading_policies (id, school_id, teacher_id, class, subject_id, mid_term_weight, final_term_weight, attendance_weight, assignment_weight)
VALUES
  ('a5000001-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'aa000001-0000-0000-0000-000000000001', 'X-A', 'cc000001-0000-0000-0000-000000000001', 30, 40, 10, 20),
  ('a5000002-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'aa000002-0000-0000-0000-000000000002', 'X-A', 'cc000004-0000-0000-0000-000000000004', 25, 45, 10, 20)
ON CONFLICT (id) DO NOTHING;


-- ── GROUP MEMBERS ────────────────────────────────────────────
DO $$
DECLARE
    grp1_id uuid;
    grp2_id uuid;
BEGIN
    SELECT id INTO grp1_id FROM groups WHERE name = 'Study Group 10A' LIMIT 1;
    SELECT id INTO grp2_id FROM groups WHERE name = 'Science Club' LIMIT 1;

    IF grp1_id IS NOT NULL THEN
        INSERT INTO group_members (id, group_id, member_id, role)
        VALUES
          ('b5000001-0000-0000-0000-000000000001', grp1_id, 'bb000001-0000-0000-0000-000000000001', 'admin'),
          ('b5000002-0000-0000-0000-000000000002', grp1_id, 'bb000002-0000-0000-0000-000000000002', 'member')
        ON CONFLICT (id) DO NOTHING;
    END IF;

    IF grp2_id IS NOT NULL THEN
        INSERT INTO group_members (id, group_id, member_id, role)
        VALUES
          ('b5000003-0000-0000-0000-000000000003', grp2_id, 'bb000004-0000-0000-0000-000000000004', 'admin'),
          ('b5000004-0000-0000-0000-000000000004', grp2_id, 'bb000001-0000-0000-0000-000000000001', 'member')
        ON CONFLICT (id) DO NOTHING;
    END IF;
END $$;


-- ── IOT DEVICES ──────────────────────────────────────────────
INSERT INTO iot_devices (id, school_id, room_id, device_id, ip_address, num_relays, is_online)
VALUES
  ('d5000001-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '301', 'node_math_301', '192.168.1.10', 4, true),
  ('d5000002-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'Lab 2', 'node_phys_lab', '192.168.1.11', 4, true),
  ('d5000003-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'Auditorium', 'node_aud_main', '192.168.1.12', 8, true)
ON CONFLICT (id) DO NOTHING;


-- ── IOT DEVICE STATES ────────────────────────────────────────
INSERT INTO iot_device_states (school_id, device_id, room_id, fan, light1, light2, projector)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'node_math_301', '301', 'ON', 'OFF', 'ON', 'OFF'),
  ('11111111-1111-1111-1111-111111111111', 'node_phys_lab', 'Lab 2', 'OFF', 'ON', 'ON', 'ON')
ON CONFLICT (device_id) DO NOTHING;


-- ── IOT CONTROL LOG ──────────────────────────────────────────
INSERT INTO iot_control_log (id, school_id, room_id, device, action, triggered_by, user_id)
VALUES
  ('c5000001-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '301', 'light1', 'OFF', 'manual', 'aa000001-0000-0000-0000-000000000001'),
  ('c5000002-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'Lab 2', 'projector', 'ON', 'manual', 'aa000002-0000-0000-0000-000000000002')
ON CONFLICT (id) DO NOTHING;


-- ── IOT SCHEDULED ACTIONS ────────────────────────────────────
INSERT INTO iot_scheduled_actions (id, school_id, room_id, device, action, scheduled_time, status)
VALUES
  ('e6000001-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '301', 'fan', 'OFF', NOW() + INTERVAL '1 hour', 'pending'),
  ('e6000002-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'Lab 2', 'light1', 'OFF', NOW() + INTERVAL '2 hours', 'pending')
ON CONFLICT (id) DO NOTHING;


-- ── KNOWLEDGE BASE ───────────────────────────────────────────
INSERT INTO knowledge_base (id, school_id, subject, grade, source, content, metadata)
VALUES
  ('f6000001-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Mathematics', 'Class 10', 'NCERT Textbook', 'Calculus is the mathematical study of continuous change...', '{"chapter": 7, "topic": "Integrals"}'),
  ('f6000002-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'Physics', 'Class 10', 'HC Verma', 'Newton laws of motion describe the relationship between a body and the forces acting upon it...', '{"chapter": 5, "topic": "Motion"}')
ON CONFLICT (id) DO NOTHING;


-- ── LIVE CLASS COMMENTS ──────────────────────────────────────
INSERT INTO live_class_comments (id, school_id, live_class_id, user_id, comment, is_pinned, likes)
VALUES
  ('a6000001-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'a3000002-0000-0000-0000-000000000002', 'bb000001-0000-0000-0000-000000000001', 'Can you please explain the lens formula again?', false, 5),
  ('a6000002-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'a3000002-0000-0000-0000-000000000002', 'aa000002-0000-0000-0000-000000000002', 'Sure Arjun, pay attention to the sign conventions.', true, 2)
ON CONFLICT (id) DO NOTHING;


-- ── PASSWORD RESETS ──────────────────────────────────────────
INSERT INTO password_resets (id, school_id, user_id, otp, expires_at, status)
VALUES
  ('b6000001-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'bb000003-0000-0000-0000-000000000003', '123456', NOW() - INTERVAL '1 hour', 'pending')
ON CONFLICT (id) DO NOTHING;


-- ── PAYMENTS ─────────────────────────────────────────────────
INSERT INTO payments (id, fee_id, student_id, amount, payment_method, status, paid_at)
VALUES
  ('c6000001-0000-0000-0000-000000000001', 'd1000003-0000-0000-0000-000000000003', 'bb000001-0000-0000-0000-000000000001', 2000.00, 'UPI', 'completed', NOW() - INTERVAL '60 days'),
  ('c6000002-0000-0000-0000-000000000002', 'd1000004-0000-0000-0000-000000000004', 'bb000004-0000-0000-0000-000000000004', 8500.00, 'Card', 'completed', NOW() - INTERVAL '5 days')
ON CONFLICT (id) DO NOTHING;


-- ── SALARY ───────────────────────────────────────────────────
INSERT INTO salary (id, school_id, teacher_id, amount, month, year, status, paid_at)
VALUES
  ('d6000001-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'aa000001-0000-0000-0000-000000000001', 75000.00, 3, 2026, 'paid', NOW() - INTERVAL '20 days'),
  ('d6000002-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'aa000002-0000-0000-0000-000000000002', 72000.00, 3, 2026, 'paid', NOW() - INTERVAL '20 days')
ON CONFLICT (id) DO NOTHING;


-- ── STUDY MATERIALS ──────────────────────────────────────────
INSERT INTO study_materials (id, school_id, teacher_id, title, description, material_type, target_class, attachment_urls)
VALUES
  ('e7000001-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'aa000001-0000-0000-0000-000000000001', 'Integration Formula Sheet', 'All important integration formulas in one place.', 'Notes', 'X-A', '["https://eduverse.school/math/integrals.pdf"]'),
  ('e7000002-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'aa000002-0000-0000-0000-000000000002', 'Optics Lab Manual', 'Guide for mirror and lens experiments.', 'Notes', 'X-A', '["https://eduverse.school/physics/optics_lab.pdf"]')
ON CONFLICT (id) DO NOTHING;


-- ── USER SETTINGS ────────────────────────────────────────────
INSERT INTO user_settings (id, school_id, user_id, push_notifications, sms_alerts, email_reports, ai_personalization, biometric_login, dark_mode, language)
VALUES
  ('f7000001-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'bb000001-0000-0000-0000-000000000001', true, true, true, true, false, true, 'en'),
  ('f7000002-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'aa000001-0000-0000-0000-000000000001', true, false, true, true, true, false, 'en')
ON CONFLICT (id) DO NOTHING;


-- ── BUS LOCATIONS ────────────────────────────────────────────
INSERT INTO bus_locations (id, school_id, route_id, latitude, longitude, speed, heading, eta_minutes)
VALUES
  ('a7000001-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'c3000001-0000-0000-0000-000000000001', 18.5204, 73.8567, 40.5, 90.0, 5),
  ('a7000002-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'c3000002-0000-0000-0000-000000000002', 18.5104, 73.8467, 35.0, 180.0, 10)
ON CONFLICT (id) DO NOTHING;
