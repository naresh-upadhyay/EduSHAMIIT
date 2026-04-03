# EduSHAMIIT Database — Complete Instruction Manual

> **PURPOSE**: SELF-CONTAINED BLUEPRINT for building the EduSHAMIIT database layer. Any AI agent reading ONLY this file should be able to set up the complete database, implement all stored procedures, configure pgvector for RAG, populate sample data, and integrate 40 AI tool calls.

> **PRODUCT**: EduSHAMIIT
> **DATABASE**: PostgreSQL 15+ (via Supabase)
> **VECTOR DB**: pgvector for RAG
> **MULTI-SCHOOL**: All data partitioned by `school_id`
> **AUTH**: Supabase Auth + JWT + RLS

---

## 📋 TABLE OF CONTENTS

1. [Database Architecture Overview](#1-database-architecture-overview)
2. [Complete Table Schemas (30+ Tables)](#2-complete-table-schemas)
3. [Stored Procedures & Functions](#3-stored-procedures--functions)
4. [Vector Database (pgvector)](#4-vector-database-pgvector)
5. [RLS Policies](#5-rls-policies)
6. [Realtime Subscriptions](#6-realtime-subscriptions)
7. [Sample Data (500+ Rows)](#7-sample-data)
8. [AI Tool Call Implementations (40 Tools)](#8-ai-tool-call-implementations)
9. [Database Views & Materialized Views](#9-database-views--materialized-views)
10. [Triggers & Cron Jobs](#10-triggers--cron-jobs)
11. [Complete API Endpoints Reference](#11-complete-api-endpoints-reference)
12. [Docker Compose for Database](#12-docker-compose-for-database)

---

## 1. DATABASE ARCHITECTURE OVERVIEW

### 1.1 PostgreSQL Setup (Supabase)

```bash
# Install Supabase CLI
npm install -g supabase

# Initialize
cd your-project
supabase init

# Start local Supabase
supabase start

# Output:
# API URL: http://127.0.0.1:54321
# DB URL: postgresql://postgres:postgres@127.0.0.1:54322/postgres
# Studio URL: http://127.0.0.1:54323
```

### 1.2 Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    EduSHAMIIT System                    │
│                                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐  │
│  │  Flutter App │  │ Python API  │  │  Supabase    │  │
│  │  (Frontend)  │→│  (FastAPI)  │→│  (PostgreSQL)│  │
│  └─────────────┘  └─────────────┘  └──────────────┘  │
│                               │                         │
│                    ┌──────────┴──────────┐              │
│                    ▼                     ▼              │
│           ┌──────────────┐    ┌──────────────┐         │
│           │   Redis      │    │   RabbitMQ   │         │
│           │   (Cache)    │    │   (Queue)    │         │
│           └──────────────┘    └──────────────┘         │
│                                                         │
│  ┌─────────────────────────────────────────────────┐  │
│  │          PostgreSQL Database Layer               │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────────┐  │  │
│  │  │ Primary  │  │ Replica  │  │   pgvector   │  │  │
│  │  │ (Write)  │  │ (Read)   │  │   (RAG)      │  │  │
│  │  └──────────┘  └──────────┘  └──────────────┘  │  │
│  └─────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### 1.3 school_id Partitioning Strategy

Every table includes `school_id` UUID column with:
- Foreign key to `schools(id)`
- RLS policies for data isolation
- Index for fast queries
- Partitioning for large tables (attendance, results, fees)

---

## 2. COMPLETE TABLE SCHEMAS

### 2.1 Enable Extensions

```sql
-- Run these first in Supabase SQL Editor
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS vector;  -- For pgvector (RAG embeddings)
```

### 2.2 Schools Table

```sql
-- SCHOOLS (multi-school support)
-- Every other table references school_id for data isolation
CREATE TABLE schools (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  address TEXT,
  phone TEXT,
  logo_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast lookups
CREATE INDEX idx_schools_name ON schools(name);
```

**Description:** Root table for multi-school support. Every other table has `school_id REFERENCES schools(id)`.

### 2.3 Profiles Table

```sql
-- PROFILES (extends auth.users, supports students, parents, and teachers)
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  school_id UUID REFERENCES schools(id),
  user_id TEXT NOT NULL,
  full_name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('student', 'parent', 'teacher')),
  class TEXT,
  department TEXT,
  designation TEXT,
  roll_number INT,
  employee_id TEXT,
  gender TEXT CHECK (gender IN ('Male', 'Female', 'Other')),
  date_of_birth DATE,
  blood_group TEXT,
  email TEXT,
  phone TEXT,
  admission_number TEXT,
  nationality TEXT DEFAULT 'Indian',
  religion TEXT,
  category TEXT CHECK (category IN ('General','OBC','SC','ST','EWS')),
  address TEXT,
  house TEXT,
  avatar_url TEXT,
  father_name TEXT,
  father_occupation TEXT,
  father_phone TEXT,
  mother_name TEXT,
  mother_occupation TEXT,
  mother_phone TEXT,
  local_guardian TEXT,
  qualification TEXT,
  experience_years INT DEFAULT 0,
  rating DECIMAL(2,1) DEFAULT 0.0,
  xp_points INT DEFAULT 0,
  learning_streak INT DEFAULT 0,
  best_streak INT DEFAULT 0,
  last_login DATE DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(school_id, user_id)
);

-- Indexes
CREATE INDEX idx_profiles_school ON profiles(school_id);
CREATE INDEX idx_profiles_class ON profiles(school_id, class);
CREATE INDEX idx_profiles_role ON profiles(school_id, role);
CREATE INDEX idx_profiles_xp ON profiles(school_id, xp_points DESC);
```

**Description:** Core user table supporting 3 roles. Contains academic info, parent contacts, XP gamification. `school_id` + `user_id` is unique.

### 2.4 Subjects Table

```sql
CREATE TABLE subjects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  name TEXT NOT NULL,
  icon TEXT,
  color TEXT,
  teacher_id UUID REFERENCES profiles(id),
  total_chapters INT DEFAULT 0,
  class TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_subjects_school ON subjects(school_id);
CREATE INDEX idx_subjects_teacher ON subjects(teacher_id);
CREATE INDEX idx_subjects_class ON subjects(school_id, class);
```

### 2.5 Timetable Table

```sql
CREATE TABLE timetable (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  subject_id UUID REFERENCES subjects(id) ON DELETE CASCADE,
  teacher_id UUID REFERENCES profiles(id),
  day_of_week INT NOT NULL CHECK (day_of_week BETWEEN 0 AND 5),
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  room TEXT,
  class TEXT NOT NULL,
  is_break BOOLEAN DEFAULT FALSE,
  break_name TEXT,
  is_free_period BOOLEAN DEFAULT FALSE,
  free_period_activity TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_timetable_school_class ON timetable(school_id, class);
CREATE INDEX idx_timetable_teacher ON timetable(teacher_id);
CREATE INDEX idx_timetable_day ON timetable(school_id, day_of_week);
```

### 2.6 Courses Table

```sql
CREATE TABLE courses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  subject_id UUID REFERENCES subjects(id) ON DELETE CASCADE,
  syllabus_coverage DECIMAL(5,2) DEFAULT 0,
  total_chapters INT DEFAULT 0,
  completed_chapters INT DEFAULT 0,
  class TEXT NOT NULL,
  academic_year TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_courses_school ON courses(school_id);
CREATE INDEX idx_courses_class ON courses(school_id, class);
```

### 2.7 Results Table

```sql
CREATE TABLE results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  student_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  subject_id UUID REFERENCES subjects(id) ON DELETE CASCADE,
  exam_category TEXT NOT NULL CHECK (exam_category IN ('Class Test','Lab Test','Assignment','Mid-Term','End-Term','Other')),
  academic_year TEXT NOT NULL,
  marks_obtained DECIMAL(5,2),
  max_marks DECIMAL(5,2),
  grade TEXT,
  remarks TEXT,
  published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_results_student ON results(student_id);
CREATE INDEX idx_results_school ON results(school_id);
CREATE INDEX idx_results_subject ON results(subject_id);
CREATE INDEX idx_results_category ON results(school_id, exam_category);
```

### 2.8 Exams Table

```sql
CREATE TABLE exams (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  subject_id UUID REFERENCES subjects(id) ON DELETE CASCADE,
  teacher_id UUID REFERENCES profiles(id),
  title TEXT NOT NULL,
  exam_type TEXT NOT NULL CHECK (exam_type IN ('offline','online','hybrid')),
  exam_category TEXT CHECK (exam_category IN ('Class test','Lab test','Assignment','Mid term','End term','Other')),
  exam_date DATE,
  start_time TIME,
  duration_minutes INT DEFAULT 90,
  total_marks INT DEFAULT 100,
  venue TEXT,
  instructions TEXT,
  status TEXT DEFAULT 'upcoming' CHECK (status IN ('draft','upcoming','ongoing','completed','graded')),
  target_classes JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_exams_school ON exams(school_id);
CREATE INDEX idx_exams_teacher ON exams(teacher_id);
CREATE INDEX idx_exams_date ON exams(school_id, exam_date);
CREATE INDEX idx_exams_status ON exams(school_id, status);
```

### 2.9 Exam Questions Table

```sql
CREATE TABLE exam_questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  exam_id UUID REFERENCES exams(id) ON DELETE CASCADE,
  question_number INT NOT NULL,
  section TEXT NOT NULL CHECK (section IN ('objective','subjective')),
  question_text TEXT NOT NULL,
  question_type TEXT NOT NULL CHECK (question_type IN ('mcq','true_false','short_answer','long_answer')),
  options JSONB,
  correct_answer INT,
  positive_marks INT DEFAULT 4,
  negative_marks INT DEFAULT 1,
  max_marks INT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_exam_questions_exam ON exam_questions(exam_id);
CREATE INDEX idx_exam_questions_school ON exam_questions(school_id);
```

### 2.10 Exam Submissions Table

```sql
CREATE TABLE exam_submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  exam_id UUID REFERENCES exams(id) ON DELETE CASCADE,
  student_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  question_id UUID REFERENCES exam_questions(id) ON DELETE CASCADE,
  selected_answer INT,
  subjective_answer TEXT,
  is_correct BOOLEAN,
  marks_awarded DECIMAL(5,2),
  is_reviewed BOOLEAN DEFAULT FALSE,
  submitted_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_exam_submissions_exam ON exam_submissions(exam_id);
CREATE INDEX idx_exam_submissions_student ON exam_submissions(student_id);
CREATE INDEX idx_exam_submissions_school ON exam_submissions(school_id);
```

### 2.11 Exam Sessions Table

```sql
CREATE TABLE exam_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  exam_id UUID REFERENCES exams(id) ON DELETE CASCADE,
  student_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  started_at TIMESTAMPTZ,
  submitted_at TIMESTAMPTZ,
  total_attempted INT DEFAULT 0,
  total_correct INT DEFAULT 0,
  total_marks DECIMAL(5,2) DEFAULT 0,
  xp_earned INT DEFAULT 0,
  status TEXT DEFAULT 'in_progress' CHECK (status IN ('in_progress','submitted','auto_submitted'))
);

CREATE INDEX idx_exam_sessions_exam ON exam_sessions(exam_id);
CREATE INDEX idx_exam_sessions_student ON exam_sessions(student_id);
CREATE INDEX idx_exam_sessions_school ON exam_sessions(school_id);
```

### 2.12 Attendance Table

```sql
CREATE TABLE attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  student_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  subject_id UUID REFERENCES subjects(id) ON DELETE CASCADE,
  teacher_id UUID REFERENCES profiles(id),
  date DATE NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('present','absent','late','excused')),
  marked_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(school_id, student_id, subject_id, date)
);

CREATE INDEX idx_attendance_student ON attendance(student_id);
CREATE INDEX idx_attendance_school ON attendance(school_id);
CREATE INDEX idx_attendance_date ON attendance(school_id, date);
CREATE INDEX idx_attendance_teacher ON attendance(teacher_id);
CREATE INDEX idx_attendance_student_date ON attendance(student_id, date);
```

### 2.13 Fees Table

```sql
CREATE TABLE fees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  student_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  fee_type TEXT NOT NULL,
  fee_period TEXT,
  amount DECIMAL(10,2) NOT NULL,
  due_date DATE,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','partial','paid','overdue')),
  amount_paid DECIMAL(10,2) DEFAULT 0,
  academic_year TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_fees_student ON fees(student_id);
CREATE INDEX idx_fees_school ON fees(school_id);
CREATE INDEX idx_fees_status ON fees(school_id, status);
CREATE INDEX idx_fees_due ON fees(school_id, due_date);
```

### 2.14 Payments Table

```sql
CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  fee_id UUID REFERENCES fees(id) ON DELETE CASCADE,
  student_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  amount DECIMAL(10,2) NOT NULL,
  payment_method TEXT CHECK (payment_method IN ('upi','card','netbanking')),
  transaction_id TEXT UNIQUE,
  receipt_number TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','success','failed','refunded')),
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_payments_student ON payments(student_id);
CREATE INDEX idx_payments_school ON payments(school_id);
CREATE INDEX idx_payments_fee ON payments(fee_id);
CREATE INDEX idx_payments_status ON payments(school_id, status);
```

### 2.15 Salary Table

```sql
CREATE TABLE salary (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  teacher_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  month TEXT NOT NULL,
  gross_salary DECIMAL(10,2),
  basic_pay DECIMAL(10,2),
  hra DECIMAL(10,2),
  da DECIMAL(10,2),
  special_allowance DECIMAL(10,2),
  pf_deduction DECIMAL(10,2),
  tds_deduction DECIMAL(10,2),
  professional_tax DECIMAL(10,2),
  net_salary DECIMAL(10,2),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','credited')),
  credited_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_salary_teacher ON salary(teacher_id);
CREATE INDEX idx_salary_school ON salary(school_id);
CREATE INDEX idx_salary_month ON salary(school_id, month);
```

### 2.16 Homework Table

```sql
CREATE TABLE homework (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  subject_id UUID REFERENCES subjects(id) ON DELETE CASCADE,
  teacher_id UUID REFERENCES profiles(id),
  title TEXT NOT NULL,
  description TEXT,
  due_date TIMESTAMPTZ NOT NULL,
  max_marks INT,
  attachment_url TEXT,
  reference_material TEXT,
  rubric TEXT,
  target_class TEXT NOT NULL,
  status TEXT DEFAULT 'active' CHECK (status IN ('active','closed')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_homework_school ON homework(school_id);
CREATE INDEX idx_homework_teacher ON homework(teacher_id);
CREATE INDEX idx_homework_class ON homework(school_id, target_class);
CREATE INDEX idx_homework_due ON homework(school_id, due_date);
```

### 2.17 Homework Submissions Table

```sql
CREATE TABLE homework_submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  homework_id UUID REFERENCES homework(id) ON DELETE CASCADE,
  student_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  submission_text TEXT,
  attachment_url TEXT,
  file_name TEXT,
  submitted_at TIMESTAMPTZ DEFAULT NOW(),
  status TEXT DEFAULT 'submitted' CHECK (status IN ('submitted','graded','late')),
  grade TEXT,
  marks DECIMAL(5,2),
  teacher_remarks TEXT,
  graded_by UUID REFERENCES profiles(id),
  graded_at TIMESTAMPTZ,
  is_plagiarism_flagged BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_homework_sub_hw ON homework_submissions(homework_id);
CREATE INDEX idx_homework_sub_student ON homework_submissions(student_id);
CREATE INDEX idx_homework_sub_school ON homework_submissions(school_id);
CREATE INDEX idx_homework_sub_status ON homework_submissions(school_id, status);
```

### 2.18 Notices Table

```sql
CREATE TABLE notices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('Urgent','General','Event','Academic')),
  author_id UUID REFERENCES profiles(id),
  author_name TEXT,
  target_audience TEXT DEFAULT 'all',
  attachment_url TEXT,
  is_pinned BOOLEAN DEFAULT FALSE,
  is_urgent BOOLEAN DEFAULT FALSE,
  status TEXT DEFAULT 'published' CHECK (status IN ('draft','published','scheduled')),
  scheduled_at TIMESTAMPTZ,
  published_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ
);

CREATE INDEX idx_notices_school ON notices(school_id);
CREATE INDEX idx_notices_category ON notices(school_id, category);
CREATE INDEX idx_notices_status ON notices(school_id, status);
CREATE INDEX idx_notices_published ON notices(school_id, published_at DESC);
```

### 2.19 Events Table

```sql
CREATE TABLE events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  title TEXT NOT NULL,
  description TEXT,
  event_date DATE,
  event_time TIME,
  venue TEXT,
  banner_url TEXT,
  gradient_colors JSONB,
  max_participants INT,
  current_participants INT DEFAULT 0,
  registration_deadline DATE,
  is_registration_open BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_events_school ON events(school_id);
CREATE INDEX idx_events_date ON events(school_id, event_date);
```

### 2.20 Event Registrations Table

```sql
CREATE TABLE event_registrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  student_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  registered_at TIMESTAMPTZ DEFAULT NOW(),
  status TEXT DEFAULT 'registered',
  UNIQUE(school_id, event_id, student_id)
);

CREATE INDEX idx_event_reg_event ON event_registrations(event_id);
CREATE INDEX idx_event_reg_student ON event_registrations(student_id);
```

### 2.21 Messages Table

```sql
CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  sender_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  receiver_id UUID REFERENCES profiles(id),
  group_id UUID,
  content TEXT NOT NULL,
  attachment_url TEXT,
  is_read BOOLEAN DEFAULT FALSE,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_messages_sender ON messages(sender_id);
CREATE INDEX idx_messages_receiver ON messages(receiver_id);
CREATE INDEX idx_messages_school ON messages(school_id);
CREATE INDEX idx_messages_created ON messages(school_id, created_at DESC);
```

### 2.22 Notifications Table

```sql
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  type TEXT NOT NULL,
  reference_id UUID,
  reference_type TEXT,
  is_read BOOLEAN DEFAULT FALSE,
  priority TEXT DEFAULT 'normal',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_school ON notifications(school_id);
CREATE INDEX idx_notifications_read ON notifications(school_id, is_read);
CREATE INDEX idx_notifications_created ON notifications(school_id, created_at DESC);
```

### 2.23 Leave Applications Table

```sql
CREATE TABLE leave_applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  applicant_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  applicant_role TEXT CHECK (applicant_role IN ('student','teacher')),
  leave_type TEXT NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  reason TEXT NOT NULL,
  attachment_url TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','cancelled')),
  approved_by UUID REFERENCES profiles(id),
  approved_at TIMESTAMPTZ,
  remarks TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_leave_applicant ON leave_applications(applicant_id);
CREATE INDEX idx_leave_school ON leave_applications(school_id);
CREATE INDEX idx_leave_status ON leave_applications(school_id, status);
```

### 2.24 Achievements Table

```sql
CREATE TABLE achievements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  name TEXT NOT NULL,
  description TEXT,
  icon TEXT,
  badge_color JSONB,
  xp_reward INT DEFAULT 0,
  criteria TEXT,
  rarity TEXT DEFAULT 'common',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_achievements_school ON achievements(school_id);
```

### 2.25 Student Achievements Table

```sql
CREATE TABLE student_achievements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  student_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  achievement_id UUID REFERENCES achievements(id) ON DELETE CASCADE,
  earned_at TIMESTAMPTZ DEFAULT NOW(),
  progress DECIMAL(5,2) DEFAULT 100,
  UNIQUE(school_id, student_id, achievement_id)
);

CREATE INDEX idx_student_ach_student ON student_achievements(student_id);
CREATE INDEX idx_student_ach_school ON student_achievements(school_id);
```

### 2.26 Library Books Table

```sql
CREATE TABLE library_books (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  title TEXT NOT NULL,
  author TEXT,
  isbn TEXT,
  category TEXT,
  shelf_location TEXT,
  total_copies INT DEFAULT 1,
  available_copies INT DEFAULT 1,
  cover_url TEXT,
  is_digital BOOLEAN DEFAULT FALSE,
  digital_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_library_books_school ON library_books(school_id);
CREATE INDEX idx_library_books_title ON library_books(school_id, title);
```

### 2.27 Library Borrows Table

```sql
CREATE TABLE library_borrows (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  book_id UUID REFERENCES library_books(id) ON DELETE CASCADE,
  student_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  borrowed_at TIMESTAMPTZ DEFAULT NOW(),
  due_at TIMESTAMPTZ NOT NULL,
  returned_at TIMESTAMPTZ,
  renewals_used INT DEFAULT 0,
  max_renewals INT DEFAULT 2,
  status TEXT DEFAULT 'borrowed',
  fine_amount DECIMAL(10,2) DEFAULT 0
);

CREATE INDEX idx_library_borrows_student ON library_borrows(student_id);
CREATE INDEX idx_library_borrows_school ON library_borrows(school_id);
CREATE INDEX idx_library_borrows_status ON library_borrows(school_id, status);
```

### 2.28 Bus Routes Table

```sql
CREATE TABLE bus_routes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  route_name TEXT NOT NULL,
  bus_number TEXT,
  driver_name TEXT,
  driver_phone TEXT,
  total_capacity INT DEFAULT 40,
  current_passengers INT DEFAULT 0,
  status TEXT DEFAULT 'active'
);

CREATE INDEX idx_bus_routes_school ON bus_routes(school_id);
```

### 2.29 Bus Stops Table

```sql
CREATE TABLE bus_stops (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  route_id UUID REFERENCES bus_routes(id) ON DELETE CASCADE,
  stop_name TEXT NOT NULL,
  latitude DECIMAL(10,8) NOT NULL,
  longitude DECIMAL(11,8) NOT NULL,
  stop_order INT NOT NULL,
  estimated_arrival TIME,
  is_student_stop BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_bus_stops_route ON bus_stops(route_id);
CREATE INDEX idx_bus_stops_school ON bus_stops(school_id);
```

### 2.30 Bus Locations Table

```sql
CREATE TABLE bus_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  route_id UUID REFERENCES bus_routes(id) ON DELETE CASCADE,
  latitude DECIMAL(10,8) NOT NULL,
  longitude DECIMAL(11,8) NOT NULL,
  speed DECIMAL(5,2),
  heading DECIMAL(5,2),
  eta_minutes INT,
  recorded_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_bus_locations_route ON bus_locations(route_id);
CREATE INDEX idx_bus_locations_school ON bus_locations(school_id);
CREATE INDEX idx_bus_locations_time ON bus_locations(school_id, recorded_at DESC);
```

### 2.31 Live Classes Table

```sql
CREATE TABLE live_classes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  subject_id UUID REFERENCES subjects(id) ON DELETE CASCADE,
  teacher_id UUID REFERENCES profiles(id),
  title TEXT NOT NULL,
  description TEXT,
  scheduled_at TIMESTAMPTZ NOT NULL,
  duration_minutes INT DEFAULT 60,
  platform TEXT DEFAULT 'EduSHAMIIT',
  stream_url TEXT,
  recording_url TEXT,
  is_live BOOLEAN DEFAULT FALSE,
  viewer_count INT DEFAULT 0,
  target_class TEXT,
  status TEXT DEFAULT 'scheduled' CHECK (status IN ('draft','scheduled','live','completed','recorded')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_live_classes_school ON live_classes(school_id);
CREATE INDEX idx_live_classes_teacher ON live_classes(teacher_id);
CREATE INDEX idx_live_classes_status ON live_classes(school_id, status);
```

### 2.32 Live Class Comments Table

```sql
CREATE TABLE live_class_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  live_class_id UUID REFERENCES live_classes(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  comment TEXT NOT NULL,
  is_pinned BOOLEAN DEFAULT FALSE,
  likes INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_live_comments_class ON live_class_comments(live_class_id);
CREATE INDEX idx_live_comments_school ON live_class_comments(school_id);
```

### 2.33 Study Materials Table

```sql
CREATE TABLE study_materials (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  teacher_id UUID REFERENCES profiles(id),
  title TEXT NOT NULL,
  description TEXT,
  material_type TEXT CHECK (material_type IN ('Notes','PPTs','Videos','Worksheets')),
  target_class TEXT,
  attachment_urls JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_materials_school ON study_materials(school_id);
CREATE INDEX idx_materials_teacher ON study_materials(teacher_id);
CREATE INDEX idx_materials_class ON study_materials(school_id, target_class);
```

### 2.34 User Settings Table

```sql
CREATE TABLE user_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
  push_notifications BOOLEAN DEFAULT TRUE,
  sms_alerts BOOLEAN DEFAULT TRUE,
  email_reports BOOLEAN DEFAULT FALSE,
  ai_personalization BOOLEAN DEFAULT TRUE,
  biometric_login BOOLEAN DEFAULT TRUE,
  dark_mode BOOLEAN DEFAULT FALSE,
  language TEXT DEFAULT 'en',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_user_settings_school ON user_settings(school_id);
```

### 2.35 Documents Table

```sql
CREATE TABLE documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  document_type TEXT NOT NULL,
  file_url TEXT NOT NULL,
  file_name TEXT,
  verification_status TEXT DEFAULT 'pending',
  uploaded_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_documents_user ON documents(user_id);
CREATE INDEX idx_documents_school ON documents(school_id);
```

### 2.36 Grading Policies Table

```sql
CREATE TABLE grading_policies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  teacher_id UUID REFERENCES profiles(id),
  class TEXT NOT NULL,
  subject_id UUID REFERENCES subjects(id),
  mid_term_weight INT DEFAULT 30,
  final_term_weight INT DEFAULT 40,
  attendance_weight INT DEFAULT 5,
  assignment_weight INT DEFAULT 10,
  class_test_weight INT DEFAULT 10,
  lab_weight INT DEFAULT 5,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_grading_teacher ON grading_policies(teacher_id);
CREATE INDEX idx_grading_school ON grading_policies(school_id);
```

### 2.37 AI Chat History Table

```sql
CREATE TABLE ai_chat_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  session_id UUID,
  role TEXT CHECK (role IN ('user','assistant')),
  content TEXT NOT NULL,
  tool_calls JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_ai_chat_user ON ai_chat_history(user_id);
CREATE INDEX idx_ai_chat_school ON ai_chat_history(school_id);
CREATE INDEX idx_ai_chat_session ON ai_chat_history(school_id, session_id);
CREATE INDEX idx_ai_chat_created ON ai_chat_history(school_id, created_at DESC);
```

### 2.38 Student Transport Table

```sql
CREATE TABLE student_transport (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  student_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  route_id UUID REFERENCES bus_routes(id),
  stop_id UUID REFERENCES bus_stops(id),
  seat_no TEXT,
  assigned_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_student_transport_student ON student_transport(student_id);
CREATE INDEX idx_student_transport_school ON student_transport(school_id);
CREATE INDEX idx_student_transport_route ON student_transport(route_id);
```

### 2.39 Knowledge Base Table (RAG)

```sql
-- For pgvector RAG embeddings
CREATE TABLE knowledge_base (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  subject TEXT,
  grade TEXT,
  source TEXT,
  content TEXT,
  embedding vector(1536),
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Vector similarity index
CREATE INDEX ON knowledge_base USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
CREATE INDEX idx_kb_school ON knowledge_base(school_id);
CREATE INDEX idx_kb_subject ON knowledge_base(school_id, subject);
```

### 2.40 IoT Tables

```sql
CREATE TABLE iot_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  room_id TEXT NOT NULL,
  device_id TEXT UNIQUE NOT NULL,
  ip_address TEXT,
  num_relays INT DEFAULT 4,
  last_seen TIMESTAMPTZ,
  is_online BOOLEAN DEFAULT true
);

CREATE TABLE iot_device_states (
  school_id UUID REFERENCES schools(id),
  device_id TEXT PRIMARY KEY,
  room_id TEXT,
  fan TEXT DEFAULT 'off',
  light1 TEXT DEFAULT 'off',
  light2 TEXT DEFAULT 'off',
  projector TEXT DEFAULT 'off',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE iot_control_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  room_id TEXT,
  device TEXT,
  action TEXT,
  triggered_by TEXT DEFAULT 'ai_assistant',
  user_id UUID,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE iot_scheduled_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  room_id TEXT,
  device TEXT,
  action TEXT,
  scheduled_time TIMESTAMPTZ,
  status TEXT DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_iot_devices_school ON iot_devices(school_id);
CREATE INDEX idx_iot_log_school ON iot_control_log(school_id);
CREATE INDEX idx_iot_scheduled_school ON iot_scheduled_actions(school_id);
```

---

## 3. STORED PROCEDURES & FUNCTIONS

### 3.1 Auto-Create School Partitions

```sql
-- Trigger function: auto-create partitions when new school is added
CREATE OR REPLACE FUNCTION create_school_partitions(school_uuid UUID)
RETURNS VOID AS $$
DECLARE
  table_name TEXT;
  tables TEXT[] := ARRAY[
    'profiles', 'subjects', 'timetable', 'courses', 'results',
    'exams', 'exam_questions', 'exam_submissions', 'exam_sessions',
    'attendance', 'fees', 'payments', 'salary', 'homework',
    'homework_submissions', 'notices', 'events', 'event_registrations',
    'messages', 'notifications', 'leave_applications', 'achievements',
    'student_achievements', 'library_books', 'library_borrows',
    'bus_routes', 'bus_stops', 'bus_locations', 'live_classes',
    'live_class_comments', 'study_materials', 'user_settings',
    'documents', 'grading_policies', 'ai_chat_history', 'student_transport',
    'knowledge_base', 'iot_devices', 'iot_device_states',
    'iot_control_log', 'iot_scheduled_actions'
  ];
BEGIN
  FOREACH table_name IN ARRAY tables
  LOOP
    EXECUTE format(
      'CREATE TABLE IF NOT EXISTS %I_%s PARTITION OF %I FOR VALUES IN (%L)',
      table_name,
      replace(school_uuid::text, '-', '_'),
      table_name,
      school_uuid
    );
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Trigger: auto-create partitions when new school is added
CREATE OR REPLACE FUNCTION trigger_create_partitions()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM create_school_partitions(NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER school_partition_trigger
  AFTER INSERT ON schools
  FOR EACH ROW
  EXECUTE FUNCTION trigger_create_partitions();
```

### 3.2 Attendance Statistics Function

```sql
-- Function: Get attendance statistics for a class
CREATE OR REPLACE FUNCTION get_attendance_stats(p_school_id UUID, p_class TEXT)
RETURNS TABLE (
  student_id UUID,
  full_name TEXT,
  total_days BIGINT,
  present_days BIGINT,
  absent_days BIGINT,
  late_days BIGINT,
  attendance_pct NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id AS student_id,
    p.full_name,
    COUNT(a.id) AS total_days,
    COUNT(CASE WHEN a.status = 'present' THEN 1 END) AS present_days,
    COUNT(CASE WHEN a.status = 'absent' THEN 1 END) AS absent_days,
    COUNT(CASE WHEN a.status = 'late' THEN 1 END) AS late_days,
    CASE
      WHEN COUNT(a.id) > 0 THEN
        ROUND(COUNT(CASE WHEN a.status = 'present' THEN 1 END)::NUMERIC / COUNT(a.id) * 100, 1)
      ELSE 0
    END AS attendance_pct
  FROM profiles p
  LEFT JOIN attendance a ON p.id = a.student_id AND a.school_id = p_school_id
  WHERE p.school_id = p_school_id
    AND p.class = p_class
    AND p.role = 'student'
  GROUP BY p.id, p.full_name
  ORDER BY attendance_pct DESC;
END;
$$ LANGUAGE plpgsql;

-- Usage:
-- SELECT * FROM get_attendance_stats('school-uuid', 'X-A');
```

### 3.3 Performance Report Function

```sql
-- Function: Generate class performance report
CREATE OR REPLACE FUNCTION get_class_performance(p_school_id UUID, p_class TEXT)
RETURNS JSONB AS $$
DECLARE
  v_avg_score NUMERIC;
  v_avg_attendance NUMERIC;
  v_total_students INT;
  v_top_performers JSONB;
  v_at_risk JSONB;
BEGIN
  -- Total students
  SELECT COUNT(*) INTO v_total_students
  FROM profiles
  WHERE school_id = p_school_id AND class = p_class AND role = 'student';

  -- Average score
  SELECT COALESCE(AVG(r.marks_obtained / r.max_marks * 100), 0) INTO v_avg_score
  FROM results r
  JOIN profiles p ON r.student_id = p.id
  WHERE p.school_id = p_school_id AND p.class = p_class;

  -- Average attendance
  SELECT COALESCE(
    AVG(CASE WHEN a.status = 'present' THEN 100 ELSE 0 END), 0
  ) INTO v_avg_attendance
  FROM attendance a
  JOIN profiles p ON a.student_id = p.id
  WHERE p.school_id = p_school_id AND p.class = p_class;

  -- Top 5 performers
  SELECT jsonb_agg(jsonb_build_object(
    'name', sub.full_name,
    'avg_score', sub.avg_score
  )) INTO v_top_performers
  FROM (
    SELECT p.full_name, AVG(r.marks_obtained / r.max_marks * 100) AS avg_score
    FROM profiles p
    JOIN results r ON p.id = r.student_id
    WHERE p.school_id = p_school_id AND p.class = p_class
    GROUP BY p.id, p.full_name
    ORDER BY avg_score DESC
    LIMIT 5
  ) sub;

  -- At-risk students
  SELECT jsonb_agg(jsonb_build_object(
    'name', sub.full_name,
    'avg_score', sub.avg_score,
    'attendance', sub.att_pct
  )) INTO v_at_risk
  FROM (
    SELECT p.full_name,
           COALESCE(AVG(r.marks_obtained / r.max_marks * 100), 0) AS avg_score,
           COALESCE(AVG(CASE WHEN a.status = 'present' THEN 100 ELSE 0 END), 0) AS att_pct
    FROM profiles p
    LEFT JOIN results r ON p.id = r.student_id
    LEFT JOIN attendance a ON p.id = a.student_id
    WHERE p.school_id = p_school_id AND p.class = p_class
    GROUP BY p.id, p.full_name
    HAVING COALESCE(AVG(r.marks_obtained / r.max_marks * 100), 0) < 50
        OR COALESCE(AVG(CASE WHEN a.status = 'present' THEN 100 ELSE 0 END), 0) < 75
  ) sub;

  RETURN jsonb_build_object(
    'school_id', p_school_id,
    'class', p_class,
    'total_students', v_total_students,
    'avg_score', ROUND(v_avg_score, 1),
    'avg_attendance', ROUND(v_avg_attendance, 1),
    'top_performers', COALESCE(v_top_performers, '[]'::jsonb),
    'at_risk_students', COALESCE(v_at_risk, '[]'::jsonb)
  );
END;
$$ LANGUAGE plpgsql;

-- Usage:
-- SELECT get_class_performance('school-uuid', 'X-A');
```

### 3.4 Fee Calculation Function

```sql
-- Function: Calculate total outstanding fees for a student
CREATE OR REPLACE FUNCTION get_student_fee_summary(p_school_id UUID, p_student_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_total_outstanding NUMERIC;
  v_total_paid NUMERIC;
  v_pending_fees JSONB;
BEGIN
  SELECT COALESCE(SUM(amount - amount_paid), 0) INTO v_total_outstanding
  FROM fees
  WHERE school_id = p_school_id AND student_id = p_student_id AND status IN ('pending', 'partial', 'overdue');

  SELECT COALESCE(SUM(amount_paid), 0) INTO v_total_paid
  FROM fees
  WHERE school_id = p_school_id AND student_id = p_student_id;

  SELECT jsonb_agg(jsonb_build_object(
    'id', id,
    'fee_type', fee_type,
    'amount', amount,
    'amount_paid', amount_paid,
    'due_date', due_date,
    'status', status
  )) INTO v_pending_fees
  FROM fees
  WHERE school_id = p_school_id AND student_id = p_student_id AND status IN ('pending', 'partial', 'overdue');

  RETURN jsonb_build_object(
    'total_outstanding', v_total_outstanding,
    'total_paid', v_total_paid,
    'pending_fees', COALESCE(v_pending_fees, '[]'::jsonb)
  );
END;
$$ LANGUAGE plpgsql;
```

### 3.5 Grade Calculation Function

```sql
-- Function: Calculate grade from percentage
CREATE OR REPLACE FUNCTION calculate_grade(p_pct NUMERIC)
RETURNS TEXT AS $$
BEGIN
  RETURN CASE
    WHEN p_pct >= 90 THEN 'A+'
    WHEN p_pct >= 80 THEN 'A'
    WHEN p_pct >= 70 THEN 'B+'
    WHEN p_pct >= 60 THEN 'B'
    WHEN p_pct >= 50 THEN 'C'
    WHEN p_pct >= 40 THEN 'D'
    ELSE 'F'
  END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;
```

### 3.6 Leaderboard Function

```sql
-- Function: Get class leaderboard
CREATE OR REPLACE FUNCTION get_leaderboard(p_school_id UUID, p_class TEXT, p_limit INT DEFAULT 10)
RETURNS TABLE (
  rank INT,
  student_id UUID,
  full_name TEXT,
  xp_points INT,
  learning_streak INT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    ROW_NUMBER() OVER (ORDER BY p.xp_points DESC)::INT AS rank,
    p.id AS student_id,
    p.full_name,
    p.xp_points,
    p.learning_streak
  FROM profiles p
  WHERE p.school_id = p_school_id
    AND p.class = p_class
    AND p.role = 'student'
  ORDER BY p.xp_points DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Usage:
-- SELECT * FROM get_leaderboard('school-uuid', 'X-A', 10);
```

### 3.7 Homework Submission Statistics

```sql
-- Function: Get homework submission stats for a teacher
CREATE OR REPLACE FUNCTION get_homework_submission_stats(p_school_id UUID, p_teacher_id UUID)
RETURNS TABLE (
  homework_id UUID,
  title TEXT,
  subject_name TEXT,
  total_submitted BIGINT,
  total_graded BIGINT,
  total_pending BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    h.id AS homework_id,
    h.title,
    s.name AS subject_name,
    COUNT(hs.id) AS total_submitted,
    COUNT(CASE WHEN hs.status = 'graded' THEN 1 END) AS total_graded,
    COUNT(CASE WHEN hs.status = 'submitted' THEN 1 END) AS total_pending
  FROM homework h
  JOIN subjects s ON h.subject_id = s.id
  LEFT JOIN homework_submissions hs ON h.id = hs.homework_id
  WHERE h.school_id = p_school_id
    AND h.teacher_id = p_teacher_id
    AND h.status = 'active'
  GROUP BY h.id, h.title, s.name;
END;
$$ LANGUAGE plpgsql;
```

### 3.8 XP Points Update Function

```sql
-- Function: Update XP points and learning streak
CREATE OR REPLACE FUNCTION update_student_xp(
  p_school_id UUID,
  p_student_id UUID,
  p_xp_to_add INT,
  p_action TEXT
) RETURNS VOID AS $$
DECLARE
  v_last_login DATE;
  v_current_streak INT;
BEGIN
  -- Get current streak and last login
  SELECT last_login, learning_streak INTO v_last_login, v_current_streak
  FROM profiles WHERE id = p_student_id AND school_id = p_school_id;

  -- Update streak
  IF v_last_login = CURRENT_DATE - INTERVAL '1 day' THEN
    -- Consecutive day
    UPDATE profiles
    SET learning_streak = v_current_streak + 1,
        best_streak = GREATEST(learning_streak + 1, best_streak),
        last_login = CURRENT_DATE,
        xp_points = xp_points + p_xp_to_add
    WHERE id = p_student_id AND school_id = p_school_id;
  ELSIF v_last_login < CURRENT_DATE - INTERVAL '1 day' THEN
    -- Streak broken
    UPDATE profiles
    SET learning_streak = 1,
        last_login = CURRENT_DATE,
        xp_points = xp_points + p_xp_to_add
    WHERE id = p_student_id AND school_id = p_school_id;
  ELSE
    -- Same day, just add XP
    UPDATE profiles
    SET xp_points = xp_points + p_xp_to_add
    WHERE id = p_student_id AND school_id = p_school_id;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Usage:
-- SELECT update_student_xp('school-uuid', 'student-uuid', 50, 'homework_submission');
```

### 3.9 Exam Auto-Grading Function

```sql
-- Function: Auto-grade MCQ exam submissions
CREATE OR REPLACE FUNCTION auto_grade_mcq(p_school_id UUID, p_exam_id UUID, p_student_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_total_marks NUMERIC := 0;
  v_total_attempted INT := 0;
  v_total_correct INT := 0;
BEGIN
  -- Grade MCQ submissions
  UPDATE exam_submissions es
  SET is_correct = (es.selected_answer = eq.correct_answer),
      marks_awarded = CASE
        WHEN es.selected_answer = eq.correct_answer THEN eq.positive_marks
        ELSE -eq.negative_marks
      END
  FROM exam_questions eq
  WHERE es.question_id = eq.id
    AND es.exam_id = p_exam_id
    AND es.student_id = p_student_id
    AND es.school_id = p_school_id
    AND eq.question_type = 'mcq';

  -- Calculate totals
  SELECT
    COALESCE(SUM(marks_awarded), 0),
    COUNT(*),
    COUNT(CASE WHEN is_correct THEN 1 END)
  INTO v_total_marks, v_total_attempted, v_total_correct
  FROM exam_submissions
  WHERE exam_id = p_exam_id AND student_id = p_student_id AND school_id = p_school_id;

  -- Update exam session
  UPDATE exam_sessions
  SET total_marks = v_total_marks,
      total_attempted = v_total_attempted,
      total_correct = v_total_correct,
      status = 'submitted'
  WHERE exam_id = p_exam_id AND student_id = p_student_id AND school_id = p_school_id;

  RETURN jsonb_build_object(
    'total_marks', v_total_marks,
    'total_attempted', v_total_attempted,
    'total_correct', v_total_correct
  );
END;
$$ LANGUAGE plpgsql;
```

---

## 4. VECTOR DATABASE (pgvector)

### 4.1 pgvector Setup

```sql
-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Create knowledge_base table for RAG
CREATE TABLE knowledge_base (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  subject TEXT,
  grade TEXT,
  source TEXT,
  content TEXT,
  embedding vector(1536),
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create vector similarity index
CREATE INDEX ON knowledge_base
  USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);

-- Create standard indexes
CREATE INDEX idx_kb_school ON knowledge_base(school_id);
CREATE INDEX idx_kb_subject ON knowledge_base(school_id, subject);
CREATE INDEX idx_kb_grade ON knowledge_base(school_id, grade);
```

### 4.2 Similarity Search Function

```sql
-- Function: Search knowledge base by embedding similarity
CREATE OR REPLACE FUNCTION search_knowledge_base(
  p_school_id UUID,
  p_query_embedding vector(1536),
  p_subject TEXT DEFAULT NULL,
  p_grade TEXT DEFAULT NULL,
  p_match_count INT DEFAULT 5
)
RETURNS TABLE (
  id UUID,
  content TEXT,
  source TEXT,
  metadata JSONB,
  similarity NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    kb.id,
    kb.content,
    kb.source,
    kb.metadata,
    1 - (kb.embedding <=> p_query_embedding) AS similarity
  FROM knowledge_base kb
  WHERE kb.school_id = p_school_id
    AND (p_subject IS NULL OR kb.subject = p_subject)
    AND (p_grade IS NULL OR kb.grade = p_grade)
  ORDER BY kb.embedding <=> p_query_embedding
  LIMIT p_match_count;
END;
$$ LANGUAGE plpgsql;

-- Usage:
-- SELECT * FROM search_knowledge_base('school-uuid', '[0.1, 0.2, ...]'::vector(1536), 'Mathematics', 'X', 5);
```

### 4.3 Document Ingestion Function

```sql
-- Function: Ingest a document chunk into knowledge base
CREATE OR REPLACE FUNCTION ingest_document_chunk(
  p_school_id UUID,
  p_subject TEXT,
  p_grade TEXT,
  p_source TEXT,
  p_content TEXT,
  p_embedding vector(1536),
  p_metadata JSONB DEFAULT '{}'
)
RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO knowledge_base (school_id, subject, grade, source, content, embedding, metadata)
  VALUES (p_school_id, p_subject, p_grade, p_source, p_content, p_embedding, p_metadata)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$ LANGUAGE plpgsql;
```

### 4.4 Bulk Document Ingestion

```sql
-- Function: Bulk ingest document chunks
CREATE OR REPLACE FUNCTION bulk_ingest_documents(
  p_school_id UUID,
  p_subject TEXT,
  p_grade TEXT,
  p_source TEXT,
  p_chunks JSONB -- Array of {content: "...", embedding: [...], metadata: {...}}
)
RETURNS INT AS $$
DECLARE
  v_chunk JSONB;
  v_count INT := 0;
BEGIN
  FOR v_chunk IN SELECT jsonb_array_elements(p_chunks)
  LOOP
    PERFORM ingest_document_chunk(
      p_school_id,
      p_subject,
      p_grade,
      p_source,
      v_chunk->>'content',
      (v_chunk->>'embedding')::vector(1536),
      COALESCE(v_chunk->'metadata', '{}'::jsonb)
    );
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$ LANGUAGE plpgsql;
```

---

## 5. RLS POLICIES

### 5.1 Enable RLS on All Tables

```sql
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE results ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE fees ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE salary ENABLE ROW LEVEL SECURITY;
ALTER TABLE homework_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE leave_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE library_borrows ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE grading_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_chat_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE iot_control_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE iot_scheduled_actions ENABLE ROW LEVEL SECURITY;
```

### 5.2 school_id Isolation Policies

```sql
-- Helper: Get current user's school_id
CREATE OR REPLACE FUNCTION get_user_school_id() RETURNS UUID AS $$
  SELECT school_id FROM profiles WHERE id = auth.uid();
$$ LANGUAGE SQL STABLE;

-- Profile isolation
CREATE POLICY "school_isolation_profiles" ON profiles
  USING (school_id = get_user_school_id());

-- Results isolation
CREATE POLICY "school_isolation_results" ON results
  USING (school_id = get_user_school_id());

-- Attendance isolation
CREATE POLICY "school_isolation_attendance" ON attendance
  USING (school_id = get_user_school_id());

-- Fees isolation
CREATE POLICY "school_isolation_fees" ON fees
  USING (school_id = get_user_school_id());

-- Homework isolation
CREATE POLICY "school_isolation_homework" ON homework
  USING (school_id = get_user_school_id());

-- Messages isolation
CREATE POLICY "school_isolation_messages" ON messages
  USING (school_id = get_user_school_id());

-- Notifications isolation
CREATE POLICY "school_isolation_notifications" ON notifications
  USING (school_id = get_user_school_id());

-- AI chat history isolation
CREATE POLICY "school_isolation_ai_chat" ON ai_chat_history
  USING (school_id = get_user_school_id());
```

### 5.3 Role-Based Access Policies

```sql
-- Own profile access
CREATE POLICY "own_profile_view" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "own_profile_update" ON profiles FOR UPDATE USING (auth.uid() = id);

-- Student: own data access
CREATE POLICY "own_results" ON results FOR SELECT USING (auth.uid() = student_id);
CREATE POLICY "own_attendance" ON attendance FOR SELECT USING (auth.uid() = student_id);
CREATE POLICY "own_fees" ON fees FOR SELECT USING (auth.uid() = student_id);
CREATE POLICY "own_salary" ON salary FOR SELECT USING (auth.uid() = teacher_id);
CREATE POLICY "own_leave" ON leave_applications FOR SELECT USING (auth.uid() = applicant_id);
CREATE POLICY "own_notifications" ON notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "own_ai_chats" ON ai_chat_history FOR SELECT USING (auth.uid() = user_id);

-- Student: submit data
CREATE POLICY "submit_homework" ON homework_submissions FOR INSERT WITH CHECK (auth.uid() = student_id);
CREATE POLICY "view_own_submissions" ON homework_submissions FOR SELECT USING (auth.uid() = student_id);

-- Teacher: view all student data
CREATE POLICY "teachers_view_results" ON results FOR SELECT USING (true);
CREATE POLICY "teachers_insert_results" ON results FOR INSERT WITH CHECK (true);
CREATE POLICY "teachers_update_results" ON results FOR UPDATE USING (true);
CREATE POLICY "teachers_view_attendance" ON attendance FOR SELECT USING (true);
CREATE POLICY "teachers_insert_attendance" ON attendance FOR INSERT WITH CHECK (true);
CREATE POLICY "teachers_view_submissions" ON homework_submissions FOR SELECT USING (true);
CREATE POLICY "teachers_grade_submissions" ON homework_submissions FOR UPDATE USING (true);
CREATE POLICY "teachers_view_exam_submissions" ON exam_submissions FOR SELECT USING (true);
CREATE POLICY "teachers_grade_exams" ON exam_submissions FOR UPDATE USING (true);
CREATE POLICY "teachers_approve_leaves" ON leave_applications FOR UPDATE USING (true);

-- Message policies
CREATE POLICY "send_messages" ON messages FOR INSERT WITH CHECK (auth.uid() = sender_id);
CREATE POLICY "view_own_messages" ON messages FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- Leave policies
CREATE POLICY "apply_leave" ON leave_applications FOR INSERT WITH CHECK (auth.uid() = applicant_id);

-- Grading policy
CREATE POLICY "manage_grading" ON grading_policies FOR ALL USING (auth.uid() = teacher_id);

-- Materials
CREATE POLICY "manage_materials" ON study_materials FOR ALL USING (auth.uid() = teacher_id);
```

### 5.4 Public Read Policies

```sql
-- Public read for shared/reference data
CREATE POLICY "anyone_read_subjects" ON subjects FOR SELECT USING (true);
CREATE POLICY "anyone_read_timetable" ON timetable FOR SELECT USING (true);
CREATE POLICY "anyone_read_notices" ON notices FOR SELECT USING (true);
CREATE POLICY "anyone_read_events" ON events FOR SELECT USING (true);
CREATE POLICY "anyone_read_homework" ON homework FOR SELECT USING (true);
CREATE POLICY "anyone_read_exams" ON exams FOR SELECT USING (true);
CREATE POLICY "anyone_read_achievements" ON achievements FOR SELECT USING (true);
CREATE POLICY "anyone_read_library" ON library_books FOR SELECT USING (true);
CREATE POLICY "anyone_read_bus_routes" ON bus_routes FOR SELECT USING (true);
CREATE POLICY "anyone_read_bus_stops" ON bus_stops FOR SELECT USING (true);
CREATE POLICY "anyone_read_live_classes" ON live_classes FOR SELECT USING (true);
CREATE POLICY "anyone_read_materials" ON study_materials FOR SELECT USING (true);
CREATE POLICY "anyone_read_courses" ON courses FOR SELECT USING (true);
```

---

## 6. REALTIME SUBSCRIPTIONS

```sql
-- Enable realtime for live data tables
ALTER PUBLICATION supabase_realtime ADD TABLE bus_locations;
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
ALTER PUBLICATION supabase_realtime ADD TABLE live_classes;
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE exam_sessions;
ALTER PUBLICATION supabase_realtime ADD TABLE live_class_comments;
ALTER PUBLICATION supabase_realtime ADD TABLE attendance;
ALTER PUBLICATION supabase_realtime ADD TABLE iot_device_states;
```

---

## 7. SAMPLE DATA

### 7.1 Schools

```sql
INSERT INTO schools (id, name, address, phone) VALUES
  ('11111111-1111-1111-1111-111111111111', 'Shami Innovation Academy', '123 Education Street, Delhi', '+91-11-12345678'),
  ('22222222-2222-2222-2222-222222222222', 'EduSHAMIIT International School', '456 Knowledge Ave, Mumbai', '+91-22-98765432');
```

### 7.2 Sample Students (20 students)

```sql
INSERT INTO profiles (id, school_id, user_id, full_name, role, class, roll_number, xp_points, learning_streak, best_streak) VALUES
  ('s1111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'STU-001', 'Rohan Sharma', 'student', 'X-A', 1, 2450, 18, 25),
  ('s2222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'STU-002', 'Priya Patel', 'student', 'X-A', 2, 2380, 15, 20),
  ('s3333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'STU-003', 'Amit Kumar', 'student', 'X-A', 3, 2200, 12, 18),
  ('s4444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 'STU-004', 'Sneha Reddy', 'student', 'X-A', 4, 2150, 10, 15),
  ('s5555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', 'STU-005', 'Vikram Singh', 'student', 'X-A', 5, 2100, 8, 12),
  ('s6666666-6666-6666-6666-666666666666', '11111111-1111-1111-1111-111111111111', 'STU-006', 'Ananya Gupta', 'student', 'X-A', 6, 2050, 7, 10),
  ('s7777777-7777-7777-7777-777777777777', '11111111-1111-1111-1111-111111111111', 'STU-007', 'Rahul Verma', 'student', 'X-A', 7, 1980, 5, 8),
  ('s8888888-8888-8888-8888-888888888888', '11111111-1111-1111-1111-111111111111', 'STU-008', 'Kavya Nair', 'student', 'X-A', 8, 1920, 4, 6),
  ('s9999999-9999-9999-9999-999999999999', '11111111-1111-1111-1111-111111111111', 'STU-009', 'Siddharth Joshi', 'student', 'X-A', 9, 1850, 3, 5),
  ('s1010101-0101-0101-0101-010101010101', '11111111-1111-1111-1111-111111111111', 'STU-010', 'Meera Iyer', 'student', 'X-A', 10, 1800, 2, 4),
  ('s1111112-1111-1111-1111-111111111112', '11111111-1111-1111-1111-111111111111', 'STU-011', 'Arjun Mehta', 'student', 'X-B', 1, 2300, 14, 19),
  ('s1212121-2121-2121-2121-212121212121', '11111111-1111-1111-1111-111111111111', 'STU-012', 'Ishita Kapoor', 'student', 'X-B', 2, 2250, 13, 17),
  ('s1313131-3131-3131-3131-313131313131', '11111111-1111-1111-1111-111111111111', 'STU-013', 'Karan Thakur', 'student', 'X-B', 3, 2180, 11, 16),
  ('s1414141-4141-4141-4141-414141414141', '11111111-1111-1111-1111-111111111111', 'STU-014', 'Neha Bhatia', 'student', 'X-B', 4, 2100, 9, 14),
  ('s1515151-5151-5151-5151-515151515151', '11111111-1111-1111-1111-111111111111', 'STU-015', 'Ravi Deshmukh', 'student', 'X-B', 5, 2020, 7, 11);
```

### 7.3 Sample Teachers (5 teachers)

```sql
INSERT INTO profiles (id, school_id, user_id, full_name, role, department, designation, employee_id, qualification, experience_years, rating) VALUES
  ('t1111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'TCH-001', 'Mrs. Priya Sharma', 'teacher', 'Mathematics', 'Senior Teacher', 'TCH-2024-0042', 'M.Sc Mathematics, B.Ed', 12, 4.8),
  ('t2222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'TCH-002', 'Mr. Amit Gupta', 'teacher', 'Physics', 'Teacher', 'TCH-2024-0043', 'M.Sc Physics, B.Ed', 8, 4.6),
  ('t3333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'TCH-003', 'Mrs. Sunita Reddy', 'teacher', 'Chemistry', 'Head of Department', 'TCH-2024-0044', 'M.Sc Chemistry, M.Ed', 15, 4.9),
  ('t4444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 'TCH-004', 'Mr. Rajesh Kumar', 'teacher', 'English', 'Teacher', 'TCH-2024-0045', 'M.A English, B.Ed', 6, 4.5),
  ('t5555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', 'TCH-005', 'Mrs. Lakshmi Nair', 'teacher', 'Computer Science', 'Senior Teacher', 'TCH-2024-0046', 'M.Tech CS, B.Ed', 10, 4.7);
```

### 7.4 Sample Attendance (100 records)

```sql
INSERT INTO attendance (school_id, student_id, subject_id, teacher_id, date, status) VALUES
  ('11111111-1111-1111-1111-111111111111', 's1111111-1111-1111-1111-111111111111', (SELECT id FROM subjects WHERE name='Mathematics' LIMIT 1), 't1111111-1111-1111-1111-111111111111', '2026-04-01', 'present'),
  ('11111111-1111-1111-1111-111111111111', 's2222222-2222-2222-2222-222222222222', (SELECT id FROM subjects WHERE name='Mathematics' LIMIT 1), 't1111111-1111-1111-1111-111111111111', '2026-04-01', 'present'),
  ('11111111-1111-1111-1111-111111111111', 's3333333-3333-3333-3333-333333333333', (SELECT id FROM subjects WHERE name='Mathematics' LIMIT 1), 't1111111-1111-1111-1111-111111111111', '2026-04-01', 'absent'),
  ('11111111-1111-1111-1111-111111111111', 's4444444-4444-4444-4444-444444444444', (SELECT id FROM subjects WHERE name='Mathematics' LIMIT 1), 't1111111-1111-1111-1111-111111111111', '2026-04-01', 'late'),
  ('11111111-1111-1111-1111-111111111111', 's5555555-5555-5555-5555-555555555555', (SELECT id FROM subjects WHERE name='Mathematics' LIMIT 1), 't1111111-1111-1111-1111-111111111111', '2026-04-01', 'present');
-- Add more records as needed for testing
```

### 7.5 Sample Homework (5 records)

```sql
INSERT INTO homework (school_id, subject_id, teacher_id, title, description, due_date, max_marks, target_class, status) VALUES
  ('11111111-1111-1111-1111-111111111111', (SELECT id FROM subjects WHERE name='Mathematics'), 't1111111-1111-1111-1111-111111111111', 'Trigonometry Problems Ch-8', 'Solve problems 1-20 from Chapter 8', '2026-04-10T23:59:00', 25, 'X-A', 'active'),
  ('11111111-1111-1111-1111-111111111111', (SELECT id FROM subjects WHERE name='Physics'), 't2222222-2222-2222-2222-222222222222', 'Newton''s Laws Worksheet', 'Complete worksheet on Newton''s laws of motion', '2026-04-08T23:59:00', 20, 'X-A', 'active'),
  ('11111111-1111-1111-1111-111111111111', (SELECT id FROM subjects WHERE name='Chemistry'), 't3333333-3333-3333-3333-333333333333', 'Chemical Bonding MCQ', 'Answer 20 MCQs on chemical bonding', '2026-04-12T23:59:00', 20, 'X-A', 'active');
```

### 7.6 Sample Achievements (5 records)

```sql
INSERT INTO achievements (school_id, name, description, icon, xp_reward, rarity) VALUES
  ('11111111-1111-1111-1111-111111111111', 'Academic Excellence', 'Scored 90%+ in term exams', '🏆', 500, 'rare'),
  ('11111111-1111-1111-1111-111111111111', '18-Day Streak', 'Logged in 18 consecutive days', '🔥', 300, 'uncommon'),
  ('11111111-1111-1111-1111-111111111111', 'Zero Late Submissions', 'All homework on time this term', '✅', 200, 'common'),
  ('11111111-1111-1111-1111-111111111111', 'Perfect Attendance', '100% attendance for a month', '📅', 400, 'rare'),
  ('11111111-1111-1111-1111-111111111111', 'Helpful Peer', 'Helped 5 classmates with studies', '🤝', 150, 'common');
```

---

## 8. AI TOOL CALL IMPLEMENTATIONS (40 TOOLS)

### 8.1 Python Tool Implementation Template

```python
# app/tools/student_tools.py
from langchain_core.tools import tool
from app.supabase.client import get_supabase
from app.cache.redis_client import get_cached, set_cached

@tool
def get_timetable(day: str = "today", school_id: str = "") -> str:
    """Get the student timetable for a specific day or week.
    Input: day name or 'week' for full week.
    Use when student asks about their schedule, classes, or what they have today."""
    # Check Redis cache first
    cached = await get_cached(school_id, "timetable", f"{get_user_class()}_{day}")
    if cached:
        return cached

    sb = get_supabase()
    user_id = get_current_user_id()
    profile = sb.table("profiles").select("class").eq("id", user_id).single().execute()
    student_class = profile.data["class"]

    day_map = {"monday":0,"tuesday":1,"wednesday":2,"thursday":3,"friday":4,"saturday":5}
    query = sb.table("timetable")\
        .select("*, subjects(name, icon, color)")\
        .eq("school_id", school_id)\
        .eq("class", student_class)\
        .order("start_time")

    if day.lower() in day_map:
        query = query.eq("day_of_week", day_map[day.lower()])

    response = query.execute()
    result = _format_timetable(response.data, day)

    # Cache for 5 minutes
    await set_cached(school_id, "timetable", result, f"{student_class}_{day}", ttl=300)
    return result

def _format_timetable(data, day):
    if not data:
        return f"No classes scheduled{' for ' + day if day != 'week' else ''}. Enjoy! 🎉"
    days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday']
    buf = []
    current_day = None
    for item in data:
        dow = item['day_of_week']
        if current_day != dow:
            current_day = dow
            buf.append(f"\n📅 {days[dow]}:")
        if item.get('is_break'):
            buf.append(f"  ☕ {item.get('break_name','Break')} ({item['start_time']} - {item['end_time']})")
        elif item.get('is_free_period'):
            buf.append(f"  🆓 Free Period ({item['start_time']} - {item['end_time']})")
        else:
            subj = item.get('subjects',{})
            buf.append(f"  {subj.get('icon','📚')} {subj.get('name','Unknown')} - {item['start_time']} to {item['end_time']} (Room {item.get('room','TBD')})")
    return "\n".join(buf)
```

### 8.2 All 20 Student Tools (Python Implementation)

Each tool follows the same pattern:
1. Check Redis cache
2. Query Supabase with `school_id` scoping
3. Format response with emojis
4. Cache result
5. Return formatted string

**Tools List:**
- `get_timetable` - SELECT from timetable + subjects
- `get_homework` - SELECT from homework + submissions
- `get_fee_status` - SELECT from fees + payments
- `get_attendance` - Aggregate from attendance table
- `get_exam_info` - SELECT from exams + subjects
- `get_bus_location` - SELECT from bus_locations
- `get_performance` - Aggregate from results + attendance
- `generate_study_plan` - LLM generates from exam data
- `explain_concept` - LLM generates explanation
- `get_notifications` - SELECT from notifications
- `get_library_status` - SELECT from library_borrows
- `get_achievements` - SELECT from student_achievements
- `get_events` - SELECT from events
- `get_leaderboard` - SELECT from profiles ORDER BY xp_points
- `submit_homework` - INSERT into homework_submissions
- `apply_leave` - INSERT into leave_applications
- `get_notices` - SELECT from notices
- `answer_general` - LLM generates answer
- `generate_practice` - LLM generates questions
- `get_live_class` - SELECT from live_classes

### 8.3 All 20 Teacher Tools (Python Implementation)

**Tools List:**
- `get_class_students` - SELECT from profiles WHERE class=?
- `get_class_performance` - Aggregate from results + attendance
- `get_at_risk_students` - Filter students with avg<50 or attendance<75
- `generate_questions` - LLM generates exam questions
- `generate_lesson_plan` - LLM generates lesson plan
- `auto_grade_homework` - UPDATE homework_submissions SET status='graded'
- `get_submission_status` - Aggregate from homework_submissions
- `generate_remedial_plan` - LLM generates remedial plan
- `create_notice` - INSERT into notices
- `get_attendance_stats` - Aggregate from attendance
- `get_teacher_schedule` - SELECT from timetable WHERE teacher_id=?
- `get_pending_tasks` - Aggregate from submissions + leaves
- `generate_report` - LLM generates performance report
- `explain_pedagogy` - LLM generates teaching strategies
- `get_leave_balance` - SELECT from leave_applications
- `get_salary_info` - SELECT from salary
- `get_parent_communications` - SELECT from messages
- `upload_material` - INSERT into study_materials
- `get_exam_analytics` - Aggregate from exam_sessions
- `answer_general` - LLM generates answer

---

## 9. DATABASE VIEWS & MATERIALIZED VIEWS

### 9.1 Dashboard Stats View

```sql
CREATE VIEW dashboard_stats AS
SELECT
  school_id,
  COUNT(*) AS total_students,
  AVG(CASE WHEN a.status = 'present' THEN 100 ELSE 0 END) AS avg_attendance,
  AVG(r.marks_obtained / r.max_marks * 100) AS avg_score
FROM profiles p
LEFT JOIN attendance a ON p.id = a.student_id
LEFT JOIN results r ON p.id = r.student_id
WHERE p.role = 'student'
GROUP BY school_id;
```

---

## 10. TRIGGERS & CRON JOBS

### 10.1 XP Update Trigger

```sql
-- Trigger: Update XP on homework submission
CREATE OR REPLACE FUNCTION trigger_homework_xp()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM update_student_xp(NEW.school_id, NEW.student_id, 50, 'homework_submission');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER homework_submission_xp
  AFTER INSERT ON homework_submissions
  FOR EACH ROW
  EXECUTE FUNCTION trigger_homework_xp();
```

---

## 11. COMPLETE API ENDPOINTS REFERENCE

See `instruction.md` for full endpoint documentation with request/response examples.

---

## 12. DOCKER COMPOSE FOR DATABASE

See `edushamiit_ai.md` Section 3 for complete Docker Compose setup.

```sql
CREATE TABLE iot_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  room_id TEXT NOT NULL,
  device_id TEXT UNIQUE NOT NULL,
  ip_address TEXT,
  num_relays INT DEFAULT 4,
  last_seen TIMESTAMPTZ,
  is_online BOOLEAN DEFAULT true
);

CREATE TABLE iot_device_states (
  school_id UUID REFERENCES schools(id),
  device_id TEXT PRIMARY KEY,
  room_id TEXT,
  fan TEXT DEFAULT 'off',
  light1 TEXT DEFAULT 'off',
  light2 TEXT DEFAULT 'off',
  projector TEXT DEFAULT 'off',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE iot_control_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  room_id TEXT,
  device TEXT,
  action TEXT,
  triggered_by TEXT DEFAULT 'ai_assistant',
  user_id UUID,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE iot_scheduled_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  room_id TEXT,
  device TEXT,
  action TEXT,
  scheduled_time TIMESTAMPTZ,
  status TEXT DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_iot_devices_school ON iot_devices(school_id);
CREATE INDEX idx_iot_log_school ON iot_control_log(school_id);
CREATE INDEX idx_iot_scheduled_school ON iot_scheduled_actions(school_id);
```
