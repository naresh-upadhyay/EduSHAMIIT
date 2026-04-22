-- ============================================================
-- Migration 085 (v2): School Life Data — corrected column names
-- ============================================================

-- ── FEES ─────────────────────────────────────────────────────
-- fees: id, school_id, student_id, fee_type, amount, due_date,
--       status, academic_year, fee_period
INSERT INTO fees (id, school_id, student_id, fee_type, amount, due_date,
                  status, academic_year, fee_period)
VALUES
  ('d1000001-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111',
   'bb000001-0000-0000-0000-000000000001',
   'Tuition Fee', 8500.00, (NOW() + INTERVAL '13 days')::date,
   'pending','2025-26','Q4'),
  ('d1000002-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111',
   'bb000001-0000-0000-0000-000000000001',
   'Transport Fee', 2000.00, (NOW() + INTERVAL '4 days')::date,
   'partial','2025-26','March'),
  ('d1000003-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111',
   'bb000001-0000-0000-0000-000000000001',
   'Lab Fee', 2000.00, (NOW() - INTERVAL '60 days')::date,
   'paid','2025-26','Annual'),
  ('d1000004-0000-0000-0000-000000000004','11111111-1111-1111-1111-111111111111',
   'bb000004-0000-0000-0000-000000000004',
   'Tuition Fee', 8500.00, (NOW() + INTERVAL '13 days')::date,
   'paid','2025-26','Q4'),
  ('d1000005-0000-0000-0000-000000000005','11111111-1111-1111-1111-111111111111',
   'bb000004-0000-0000-0000-000000000004',
   'Transport Fee', 2000.00, (NOW() + INTERVAL '4 days')::date,
   'paid','2025-26','March'),
  ('d1000006-0000-0000-0000-000000000006','11111111-1111-1111-1111-111111111111',
   'bb000005-0000-0000-0000-000000000005',
   'Tuition Fee', 8500.00, (NOW() - INTERVAL '5 days')::date,
   'pending','2025-26','Q4'),
  ('d1000007-0000-0000-0000-000000000007','11111111-1111-1111-1111-111111111111',
   'bb000005-0000-0000-0000-000000000005',
   'Examination Fee', 500.00, (NOW() + INTERVAL '7 days')::date,
   'pending','2025-26','Annual')

ON CONFLICT (id) DO NOTHING;


-- ── NOTICES ──────────────────────────────────────────────────
-- notices: id, school_id, title, content, category, author_id, author_name,
--          target_audience, is_pinned, is_urgent, status, published_at
INSERT INTO notices (id, school_id, title, content, category, author_id,
                     author_name, target_audience, is_pinned, is_urgent,
                     status, published_at)
VALUES
  ('e2000001-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111',
   'Exam Hall Ticket Collection',
   'Collect your hall tickets from the school office between 9:00 AM to 3:00 PM. Mandatory for all students appearing in the final examination. Students without hall tickets will NOT be permitted to enter the exam hall. Please carry your school ID card.',
   'Urgent','aa000001-0000-0000-0000-000000000001','Principal',
   'students', TRUE, TRUE, 'published', NOW() - INTERVAL '5 days'),

  ('e2000002-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111',
   'Fee Payment Deadline Extended',
   'Fee submission deadline has been extended to April 5, 2026 for all students. Late fees waived until this date. After April 5, a penalty of Rs.50/day will apply. EMI options available through the app.',
   'Urgent','aa000001-0000-0000-0000-000000000001','Accounts Department',
   'all', TRUE, TRUE, 'published', NOW() - INTERVAL '7 days'),

  ('e2000003-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111',
   'Annual Sports Day Registration',
   'Register for Sports Day events by March 29. Students can participate in 100m dash, long jump, relay, cricket, football and badminton.',
   'General','aa000003-0000-0000-0000-000000000003','Sports Department',
   'students', FALSE, FALSE, 'published', NOW() - INTERVAL '9 days'),

  ('e2000004-0000-0000-0000-000000000004','11111111-1111-1111-1111-111111111111',
   'Science Exhibition 2026',
   'Submit your project proposals by April 1. Annual Science Exhibition on April 15. Topics: Renewable Energy, AI and Robotics, Environmental Science.',
   'Event','aa000004-0000-0000-0000-000000000004','Science Department',
   'students', FALSE, FALSE, 'published', NOW() - INTERVAL '12 days'),

  ('e2000005-0000-0000-0000-000000000005','11111111-1111-1111-1111-111111111111',
   'Final Grade Submission Deadline',
   'All teachers must submit final grades for Term 2 by April 8, 2026. Use the EduVerse gradebook system. Contact admin for discrepancies.',
   'Academic','aa000001-0000-0000-0000-000000000001','Academic Coordinator',
   'teachers', FALSE, TRUE, 'published', NOW() - INTERVAL '3 days')

ON CONFLICT (id) DO NOTHING;


-- ── EVENTS ───────────────────────────────────────────────────
-- events: id, school_id, title, description, event_date, event_time,
--         venue, max_participants, is_registration_open
INSERT INTO events (id, school_id, title, description, event_date, event_time,
                    venue, max_participants, is_registration_open)
VALUES
  ('f2000001-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111',
   'Annual Sports Day 2026',
   'Celebrate athleticism! Events: 100m dash, relay, long jump, cricket, football, badminton.',
   (NOW() + INTERVAL '20 days')::date, '09:00:00',
   'School Ground', 200, TRUE),

  ('f2000002-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111',
   'Science Exhibition 2026',
   'Showcase your scientific projects. Categories: Renewable Energy, AI & Robotics, Environmental Science.',
   (NOW() + INTERVAL '23 days')::date, '10:00:00',
   'School Auditorium', 150, TRUE),

  ('f2000003-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111',
   'Parent-Teacher Meeting',
   'Discuss student academic performance, attendance, and upcoming exams with class teachers.',
   (NOW() + INTERVAL '14 days')::date, '11:00:00',
   'School Hall', 300, FALSE),

  ('f2000004-0000-0000-0000-000000000004','11111111-1111-1111-1111-111111111111',
   'Inter-School Quiz Competition',
   'District-level quiz competition. Topics: Science, History, Current Affairs, Mathematics.',
   (NOW() + INTERVAL '30 days')::date, '09:30:00',
   'Conference Hall', 80, TRUE)

ON CONFLICT (id) DO NOTHING;


-- ── MESSAGES ─────────────────────────────────────────────────
INSERT INTO messages (id, school_id, sender_id, receiver_id, content, is_read, created_at)
VALUES
  ('a2000001-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111',
   'aa000001-0000-0000-0000-000000000001','bb000001-0000-0000-0000-000000000001',
   'Arjun, your Integration practice set is due today at 5 PM. Please submit before the deadline.',
   TRUE, NOW() - INTERVAL '2 hours'),
  ('a2000002-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111',
   'bb000001-0000-0000-0000-000000000001','aa000001-0000-0000-0000-000000000001',
   'Yes ma''am, I have submitted it. Please check.',
   TRUE, NOW() - INTERVAL '1 hour'),
  ('a2000003-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111',
   'aa000001-0000-0000-0000-000000000001','bb000005-0000-0000-0000-000000000005',
   'Vikram, I am concerned about your attendance (68%) and recent scores. Let''s schedule a remedial session this week.',
   FALSE, NOW() - INTERVAL '1 day'),
  ('a2000004-0000-0000-0000-000000000004','11111111-1111-1111-1111-111111111111',
   'bb000001-0000-0000-0000-000000000001','bb000002-0000-0000-0000-000000000002',
   'Riya, do you have the notes for today''s Physics class?',
   TRUE, NOW() - INTERVAL '3 hours'),
  ('a2000005-0000-0000-0000-000000000005','11111111-1111-1111-1111-111111111111',
   'bb000002-0000-0000-0000-000000000002','bb000001-0000-0000-0000-000000000001',
   'Yes! I will share them after school. Dr. Verma covered Optics today.',
   FALSE, NOW() - INTERVAL '2 hours')

ON CONFLICT (id) DO NOTHING;


-- ── NOTIFICATIONS ────────────────────────────────────────────
-- notifications: type column (not notification_type)
INSERT INTO notifications (id, school_id, user_id, title, body,
                           type, is_read, created_at)
VALUES
  ('b2000001-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111',
   'bb000001-0000-0000-0000-000000000001',
   'Homework Due Today!',
   'Integration Practice Set — Ch.7 is due at 5:00 PM today.',
   'homework', FALSE, NOW() - INTERVAL '1 hour'),
  ('b2000002-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111',
   'bb000001-0000-0000-0000-000000000001',
   'Exam in 5 Days!',
   'Mathematics Final Exam is scheduled in 5 days. Hall A at 9:00 AM.',
   'exam', FALSE, NOW() - INTERVAL '2 hours'),
  ('b2000003-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111',
   'bb000001-0000-0000-0000-000000000001',
   'Result Published: A+ in Maths!',
   'Your Unit Test 3 Calculus result has been published. Score: 95/100. Grade: A+',
   'result', TRUE, NOW() - INTERVAL '1 day'),
  ('b2000004-0000-0000-0000-000000000004','11111111-1111-1111-1111-111111111111',
   'aa000001-0000-0000-0000-000000000001',
   'New Submission — Arjun Kumar',
   'Arjun Kumar has submitted Integration Practice Set — Ch.7 for review.',
   'homework', FALSE, NOW() - INTERVAL '1 hour'),
  ('b2000005-0000-0000-0000-000000000005','11111111-1111-1111-1111-111111111111',
   'aa000001-0000-0000-0000-000000000001',
   'AI Alert: 5 Students Below 40% in X-A',
   'AI Insight: 5 students in X-A scored below 40% in the last unit test. Consider a remedial session.',
   'alert', FALSE, NOW() - INTERVAL '2 days'),
  ('b2000006-0000-0000-0000-000000000006','11111111-1111-1111-1111-111111111111',
   'bb000005-0000-0000-0000-000000000005',
   'Attendance Warning',
   'Your current attendance is 68%. Minimum 75% is required. Please attend all classes.',
   'alert', FALSE, NOW() - INTERVAL '3 days')

ON CONFLICT (id) DO NOTHING;


-- ── ACHIEVEMENTS ─────────────────────────────────────────────
-- achievements: name (not title), icon (not badge_icon), criteria (not category)
INSERT INTO achievements (id, school_id, name, description, icon, xp_reward, criteria)
VALUES
  ('c2000001-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111',
   'Top Scorer','Score 90%+ in any exam','trophy',200,'academic'),
  ('c2000002-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111',
   '100% Attendance','Perfect attendance for a month','star',300,'attendance'),
  ('c2000003-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111',
   'Science Fair Winner','Win the Annual Science Exhibition','microscope',500,'extracurricular'),
  ('c2000004-0000-0000-0000-000000000004','11111111-1111-1111-1111-111111111111',
   'Homework Hero','Submit 10 consecutive assignments on time','book',150,'academic'),
  ('c2000005-0000-0000-0000-000000000005','11111111-1111-1111-1111-111111111111',
   '18-Day Streak','Maintain 18-day learning streak','fire',250,'engagement')
ON CONFLICT (id) DO NOTHING;

-- student_achievements: earned_at (not awarded_at), school_id required
INSERT INTO student_achievements (id, school_id, student_id, achievement_id, earned_at)
VALUES
  ('d2000001-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111',
   'bb000001-0000-0000-0000-000000000001','c2000001-0000-0000-0000-000000000001',NOW()-INTERVAL '30 days'),
  ('d2000002-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111',
   'bb000001-0000-0000-0000-000000000001','c2000003-0000-0000-0000-000000000003',NOW()-INTERVAL '60 days'),
  ('d2000003-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111',
   'bb000001-0000-0000-0000-000000000001','c2000005-0000-0000-0000-000000000005',NOW()-INTERVAL '2 days'),
  ('d2000004-0000-0000-0000-000000000004','11111111-1111-1111-1111-111111111111',
   'bb000004-0000-0000-0000-000000000004','c2000002-0000-0000-0000-000000000002',NOW()-INTERVAL '10 days'),
  ('d2000005-0000-0000-0000-000000000005','11111111-1111-1111-1111-111111111111',
   'bb000004-0000-0000-0000-000000000004','c2000001-0000-0000-0000-000000000001',NOW()-INTERVAL '25 days')
ON CONFLICT (id) DO NOTHING;


-- ── LIBRARY BOOKS ────────────────────────────────────────────
INSERT INTO library_books (id, school_id, title, author, isbn, category,
                           shelf_location, total_copies, available_copies)
VALUES
  ('e3000001-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111',
   'NCERT Mathematics Class 10','NCERT','978-8174506544','Textbook','A-01',50,45),
  ('e3000002-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111',
   'NCERT Physics Class 10','NCERT','978-8174506551','Textbook','A-02',50,42),
  ('e3000003-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111',
   'Concepts of Physics Vol 1','H.C. Verma','978-8177091878','Reference','B-05',20,14),
  ('e3000004-0000-0000-0000-000000000004','11111111-1111-1111-1111-111111111111',
   'Problems in Mathematics','V.K. Jaiswal','978-9350944738','Reference','B-02',15,9),
  ('e3000005-0000-0000-0000-000000000005','11111111-1111-1111-1111-111111111111',
   'The Alchemist','Paulo Coelho','978-0062315007','Fiction','D-12',10,7)
ON CONFLICT (id) DO NOTHING;

-- library_borrows: due_at (not due_date), school_id required
INSERT INTO library_borrows (id, school_id, book_id, student_id,
                             borrowed_at, due_at, returned_at, status)
VALUES
  ('f3000001-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111',
   'e3000003-0000-0000-0000-000000000003','bb000001-0000-0000-0000-000000000001',
   NOW()-INTERVAL '7 days', NOW()+INTERVAL '7 days', NULL,'borrowed'),
  ('f3000002-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111',
   'e3000004-0000-0000-0000-000000000004','bb000004-0000-0000-0000-000000000004',
   NOW()-INTERVAL '3 days', NOW()+INTERVAL '11 days', NULL,'borrowed'),
  ('f3000003-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111',
   'e3000001-0000-0000-0000-000000000001','bb000002-0000-0000-0000-000000000002',
   NOW()-INTERVAL '15 days', NOW()-INTERVAL '1 day', NOW()-INTERVAL '2 days','returned')
ON CONFLICT (id) DO NOTHING;


-- ── LIVE CLASSES ─────────────────────────────────────────────
-- live_classes: target_class (not class), stream_url (not meeting_url)
INSERT INTO live_classes (id, school_id, teacher_id, subject_id, title,
                          description, scheduled_at, duration_minutes,
                          stream_url, target_class, status, is_live)
VALUES
  ('a3000001-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111',
   'aa000001-0000-0000-0000-000000000001','cc000001-0000-0000-0000-000000000001',
   'Integration by Parts — Revision',
   'Live revision session for Integration by Parts (Chapter 7). Practice problems and Q&A.',
   NOW()+INTERVAL '2 hours', 60,
   'https://meet.eduverse.school/math-xa-rev','X-A','scheduled', FALSE),

  ('a3000002-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111',
   'aa000002-0000-0000-0000-000000000002','cc000004-0000-0000-0000-000000000004',
   'Optics — Light Reflection & Refraction',
   'Covering mirror formula, lens formula, and numerical problems for the final exam.',
   NOW()-INTERVAL '30 minutes', 90,
   'https://meet.eduverse.school/phy-xa-live','X-A','live', TRUE),

  ('a3000003-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111',
   'aa000001-0000-0000-0000-000000000001','cc000003-0000-0000-0000-000000000003',
   'Algebra Fundamentals — Exam Prep',
   'Comprehensive revision for IX-A Algebra Unit Test.',
   NOW()+INTERVAL '1 day', 60,
   'https://meet.eduverse.school/math-ixa-prep','IX-A','scheduled', FALSE)

ON CONFLICT (id) DO NOTHING;


-- ── LEAVE APPLICATIONS ───────────────────────────────────────
-- leave_applications: start_date/end_date (not from_date/to_date),
--                     approved_by (not reviewed_by)
INSERT INTO leave_applications (id, school_id, applicant_id, applicant_role,
                                leave_type, start_date, end_date,
                                reason, status, approved_by)
VALUES
  ('b3000001-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111',
   'bb000005-0000-0000-0000-000000000005','student',
   'medical', CURRENT_DATE-3, CURRENT_DATE-1,
   'Fever and viral infection. Doctor certificate attached.',
   'approved','aa000001-0000-0000-0000-000000000001'),

  ('b3000002-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111',
   'bb000003-0000-0000-0000-000000000003','student',
   'personal', CURRENT_DATE+2, CURRENT_DATE+2,
   'Family function — sister''s wedding ceremony.',
   'pending', NULL),

  ('b3000003-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111',
   'aa000001-0000-0000-0000-000000000001','teacher',
   'personal', CURRENT_DATE+10, CURRENT_DATE+11,
   'Medical check-up and family obligations.',
   'pending', NULL)

ON CONFLICT (id) DO NOTHING;


-- ── BUS ROUTES ───────────────────────────────────────────────
-- bus_routes: bus_number (not route_number/vehicle_number)
INSERT INTO bus_routes (id, school_id, route_name, bus_number,
                        driver_name, driver_phone, status)
VALUES
  ('c3000001-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111',
   'Route A — North Campus','MH-12-AB-1234',
   'Ramesh Singh','+91-9811111111','active'),
  ('c3000002-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111',
   'Route B — South Campus','MH-12-CD-5678',
   'Suresh Kumar','+91-9822222222','active')
ON CONFLICT (id) DO NOTHING;

-- bus_stops: estimated_arrival (not pickup_time), school_id required
INSERT INTO bus_stops (id, school_id, route_id, stop_name, stop_order,
                       latitude, longitude, estimated_arrival)
VALUES
  ('d3000001-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111',
   'c3000001-0000-0000-0000-000000000001','Sector 7 Chowk',1,18.5204,73.8567,'07:15:00'),
  ('d3000002-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111',
   'c3000001-0000-0000-0000-000000000001','Gandhi Nagar Bus Stand',2,18.5224,73.8587,'07:25:00'),
  ('d3000003-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111',
   'c3000001-0000-0000-0000-000000000001','City Hospital Junction',3,18.5244,73.8607,'07:35:00'),
  ('d3000004-0000-0000-0000-000000000004','11111111-1111-1111-1111-111111111111',
   'c3000002-0000-0000-0000-000000000002','Patel Colony',1,18.5104,73.8467,'07:20:00'),
  ('d3000005-0000-0000-0000-000000000005','11111111-1111-1111-1111-111111111111',
   'c3000002-0000-0000-0000-000000000002','Railway Station Road',2,18.5124,73.8487,'07:30:00')
ON CONFLICT (id) DO NOTHING;

-- student_transport: school_id required
INSERT INTO student_transport (id, school_id, student_id, route_id, stop_id)
VALUES
  ('e4000001-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111',
   'bb000001-0000-0000-0000-000000000001',
   'c3000001-0000-0000-0000-000000000001','d3000002-0000-0000-0000-000000000002'),
  ('e4000002-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111',
   'bb000004-0000-0000-0000-000000000004',
   'c3000002-0000-0000-0000-000000000002','d3000004-0000-0000-0000-000000000004'),
  ('e4000003-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111',
   'bb000006-0000-0000-0000-000000000006',
   'c3000001-0000-0000-0000-000000000001','d3000001-0000-0000-0000-000000000001')
ON CONFLICT (id) DO NOTHING;


-- ── AI CHAT HISTORY ──────────────────────────────────────────
-- ai_chat_history: role + content (not message/response), session_id required
INSERT INTO ai_chat_history (id, school_id, user_id, role, content, created_at)
VALUES
  ('f4000001-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111',
   'bb000001-0000-0000-0000-000000000001',
   'user','Explain integration by parts with an example.',
   NOW()-INTERVAL '2 hours'),
  ('f4000002-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111',
   'bb000001-0000-0000-0000-000000000001',
   'assistant',
   'Integration by parts: ∫u·dv = u·v - ∫v·du. Example: ∫x·eˣdx — let u=x, dv=eˣdx. Result: eˣ(x-1)+C. Use the LIATE rule to choose u and dv.',
   NOW()-INTERVAL '2 hours'+INTERVAL '30 seconds'),
  ('f4000003-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111',
   'aa000001-0000-0000-0000-000000000001',
   'user','Generate 5 practice questions on Integration by Parts for Class X-A.',
   NOW()-INTERVAL '1 day'),
  ('f4000004-0000-0000-0000-000000000004','11111111-1111-1111-1111-111111111111',
   'aa000001-0000-0000-0000-000000000001',
   'assistant',
   '1. ∫x·sin(x)dx  2. ∫ln(x)dx  3. ∫x²·eˣdx  4. ∫eˣ·cos(x)dx  5. ∫x·arctan(x)dx. Suggested: 5 marks each, 45 minutes.',
   NOW()-INTERVAL '1 day'+INTERVAL '10 seconds')

ON CONFLICT (id) DO NOTHING;
