# EduSHAMIIT Database Setup

Complete PostgreSQL database setup for the EduSHAMIIT School Management System with 45+ tables, 135 functions, stored procedures, RLS policies, pgvector for RAG, and comprehensive sample data.

## 🚀 Quick Start (One Command)

```bash
# Make the setup script executable
chmod +x setup.sh

# Run the setup
./setup.sh
```

This will:
1. Start PostgreSQL (with pgvector), Redis, and RabbitMQ via Docker
2. Run all 80 migration files automatically
3. Set up the complete database with tables, functions, and sample data

## 📋 Prerequisites

- Docker and Docker Compose installed
- Bash shell (Linux/Mac/WSL)

## 🗄️ Database Schema

### Tables (45+)
- **Core**: schools, profiles, subjects, timetable, courses
- **Academic**: results, exams, exam_questions, exam_submissions, exam_sessions
- **Attendance**: attendance
- **Financial**: fees, payments, salary
- **Assignments**: homework, homework_submissions
- **Communication**: notices, events, event_registrations, messages, notifications
- **HR**: leave_applications
- **Gamification**: achievements, student_achievements
- **Library**: library_books, library_borrows
- **Transport**: bus_routes, bus_stops, bus_locations, student_transport
- **Live Classes**: live_classes, live_class_comments
- **Content**: study_materials
- **Settings**: user_settings, documents, grading_policies
- **AI**: ai_chat_history, knowledge_base (pgvector)
- **IoT**: iot_devices, iot_device_states, iot_control_log, iot_scheduled_actions

### Stored Procedures
- `get_attendance_stats()` - Attendance statistics for a class
- `get_class_performance()` - Class performance report (JSONB)
- `get_student_fee_summary()` - Student fee summary
- `calculate_grade()` - Calculate grade from percentage
- `get_leaderboard()` - Class leaderboard by XP
- `get_homework_submission_stats()` - Homework submission statistics
- `update_student_xp()` - Update XP and learning streak
- `auto_grade_mcq()` - Auto-grade MCQ exam submissions
- `search_knowledge_base()` - pgvector similarity search
- `ingest_document_chunk()` - Ingest document into knowledge base
- `bulk_ingest_documents()` - Bulk ingest documents
- `create_school_partitions()` - Auto-create partitions for new schools

### RLS Policies
- Multi-school data isolation via `school_id`
- Role-based access (student, teacher, parent)
- Own data access for students
- Teacher access to class data

### Realtime
- Live updates for bus_locations, messages, notifications, exam_sessions

## 📊 Sample Data

The migrations include comprehensive sample data:

### Core Data
- **2 Schools** - Shami Innovation Academy, EduSHAMIIT International School
- **13 Subjects** - Mathematics, Physics, Chemistry, English, Computer Science
- **20 Students** - Across 2 classes (X-A and X-B) with XP points and learning streaks
- **5 Teachers** - With department assignments and ratings

### Academic Data
- **15 Attendance records** - With subject tracking
- **5 Homework assignments** - With proper formatting and due dates
- **5 Fee records** - Various statuses (pending, paid, partial, overdue)
- **5 Achievements** - With XP rewards and rarity levels
- **4 Student achievements** - Properly linked

### Communication Data
- **5 Notices** - With categories and urgency flags
- **5 Events** - With participant tracking
- **10 Messages** - Student-teacher communication threads
- **10 Notifications** - Fee reminders, homework, achievements, alerts

### New Feature Data
- **12 Library books** - NCERT textbooks, reference books, programming books
- **4 Bus routes** - North, South, East, West Delhi routes
- **12 Bus stops** - GPS-located stops across all routes
- **5 Live classes** - Scheduled live sessions for different subjects
- **6 Leave applications** - Medical, family, sports leave requests
- **7 IoT devices** - Classroom smart devices (ESP32 controllers)
- **7 IoT device states** - Device status tracking (fan, lights, projector)
- **8 Knowledge base entries** - RAG content for Math, Physics, Chemistry, English, CS
- **5 Grading policies** - Weight distributions for different subjects

## 🔗 Connection Information

After running `./setup.sh`, you'll get:

```
PostgreSQL: postgresql://postgres:postgres_password_2026@localhost:5432/edushamiit
Redis:      redis://:redis_password_2026@localhost:6379
RabbitMQ:   amqp://guest:guest@localhost:5672
```

## 🛠️ Manual Setup

If you prefer to run migrations manually:

```bash
# Start containers
docker-compose up -d

# Wait for PostgreSQL to be ready
sleep 10

# Run migrations in order
for file in migrations/*.sql; do
  docker exec -i edushamiit-postgres psql -U postgres -d edushamiit < "$file"
done
```

## 📁 Project Structure

```
edushamiit-db/
├── .env                    # Environment variables
├── docker-compose.yml      # Docker services
├── setup.sh               # One-command setup script
├── README.md              # This file
└── migrations/
    ├── 001_enable_extensions.sql
    ├── 002_schools.sql
    ├── 003_profiles.sql
    ├── ... (76 more files)
    ├── 070_sample_library_books.sql
    ├── 071_sample_bus_routes.sql
    ├── 072_sample_bus_stops.sql
    ├── 073_sample_live_classes.sql
    ├── 074_sample_messages.sql
    ├── 075_sample_notifications.sql
    ├── 076_sample_leave_applications.sql
    ├── 077_sample_iot_devices.sql
    ├── 078_sample_iot_device_states.sql
    ├── 079_sample_knowledge_base.sql
    └── 080_sample_grading_policies.sql
```

## 🧪 Verify Setup

Connect to the database and run:

```sql
-- Check tables
SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';

-- Check functions
SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema = 'public';

-- Check sample data
SELECT * FROM schools;
SELECT * FROM profiles WHERE role = 'student' LIMIT 5;
SELECT * FROM get_leaderboard('11111111-1111-1111-1111-111111111111', 'X-A', 5);
```

## 🔧 Useful Commands

```bash
# Connect to database
docker exec -it edushamiit-postgres psql -U postgres -d edushamiit

# View logs
docker-compose logs -f

# Stop services
docker-compose down

# Reset database (delete all data)
docker-compose down -v && ./setup.sh

# Check Redis
docker exec -it edushamiit-redis redis-cli -a redis_password_2026

# RabbitMQ Management UI
open http://localhost:15672
```

## 📝 Notes

- All tables use UUID primary keys with `gen_random_uuid()`
- Every table has `school_id` for multi-school data isolation
- RLS policies ensure data security
- Indexes are optimized for common queries
- pgvector is configured for 1536-dimension embeddings (OpenAI compatible)
- All sample data uses proper UUID format
- Foreign key relationships are properly maintained

## 🎯 Features Included

### Core Features
- ✅ Multi-school support with data isolation
- ✅ Student, teacher, and parent profiles
- ✅ Subject and timetable management
- ✅ Exam and result management
- ✅ Attendance tracking

### Financial Features
- ✅ Fee management with payment tracking
- ✅ Salary management for teachers
- ✅ Payment status tracking

### Academic Features
- ✅ Homework assignment and submission
- ✅ Grading policies
- ✅ Performance analytics
- ✅ Leaderboard with XP system

### Communication Features
- ✅ Notice board
- ✅ Event management
- ✅ Messaging system
- ✅ Notification system

### New Features
- ✅ Library book management
- ✅ Bus transport tracking with GPS
- ✅ Live class scheduling
- ✅ Leave application system
- ✅ IoT device management
- ✅ RAG knowledge base (pgvector)
- ✅ Grading policy management

## 📄 License

Proprietary - EduSHAMIIT