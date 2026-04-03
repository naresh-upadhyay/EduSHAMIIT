# EduSHAMIIT AI Academic App — Complete Flutter Development Guide

> **PURPOSE**: This document is a SELF-CONTAINED BLUEPRINT. Any AI model or developer reading ONLY this file should be able to build the exact EduSHAMIIT AI Academic App from scratch — a UNIFIED Flutter application for BOTH Students and Teachers, matching the provided HTML mockups pixel-perfectly across all 6 platforms (Web, Android, iOS, macOS, Linux, Windows).

> **PROJECT NAME**: EduSHAMIIT AI
> **PACKAGE NAME**: com.shamiit.edu
> **AI AGENT NAME**: Shami
> **BACKEND**: Python FastAPI (see `edushamiit_ai.md` for complete backend spec)
> **ARCHITECTURE**: Single Flutter app with role-based routing (Student vs Teacher)

---

## 📋 TABLE OF CONTENTS

1. [Project Overview and Architecture](#1-project-overview-and-architecture)
2. [Step-by-Step Setup Guide](#2-step-by-step-setup-guide)
3. [Design System — Dual Theme](#3-design-system--dual-theme)
4. [Complete Folder Structure](#4-complete-folder-structure)
5. [Core Dart Files (Templates)](#5-core-dart-files-templates)
6. [Student Screens — Complete Specifications (29 Screens)](#6-student-screens--complete-specifications-29-screens)
7. [Teacher Screens — Complete Specifications (29 Screens)](#7-teacher-screens--complete-specifications-29-screens)
8. [Shared Reusable Components](#8-shared-reusable-components)
9. [Responsive Design Strategy](#9-responsive-design-strategy)
10. [Navigation and Routing](#10-navigation-and-routing)
11. [Dependencies](#11-dependencies)
12. [Development Phases](#12-development-phases)
13. [Critical Implementation Notes](#13-critical-implementation-notes)

---

## 1. PROJECT OVERVIEW AND ARCHITECTURE

### What Is EduSHAMIIT AI?

EduSHAMIIT AI is a unified AI-powered Academic App built with Flutter. It serves BOTH students and teachers through a single codebase. After login, the app detects the user's role and routes them to their respective portal. The shared screens (Splash, Login, Chat Detail, Settings) use a unified design with role-specific theming. The AI assistant agent is named **Shami** and provides intelligent assistance via a **Python FastAPI backend** with 40 tools total (20 for students, 20 for teachers).

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    EduSHAMIIT AI App                            │
│                                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────────┐          │
│  │  Splash   │→ │   Login  │→ │  Role Detection      │          │
│  │ (Shared)  │  │ (Shared) │  │  (Student/Teacher)   │          │
│  └──────────┘  └──────────┘  └──────────┬───────────┘          │
│                                          │                      │
│                    ┌─────────────────────┴──────────────┐       │
│                    ▼                                    ▼       │
│           ┌──────────────────┐            ┌──────────────────┐  │
│           │  Student Portal  │            │  Teacher Portal  │  │
│           │  (29 screens)    │            │  (29 screens)    │  │
│           └──────────────────┘            └──────────────────┘  │
│                    │                                    │       │
│                    └─────────────┬──────────────────────┘       │
│                                  ▼                              │
│                    ┌──────────────────────────┐                 │
│                    │    Shared Services        │                 │
│                    │    Supabase (LOCAL)       │                 │
│                    │    Python FastAPI (Shami) │                 │
│                    │    OSM Maps               │                 │
│                    │    Realtime Subscriptions  │                 │
│                    │    File Storage            │                 │
│                    └──────────────────────────┘                 │
└─────────────────────────────────────────────────────────────────┘
```

### Screen Count Summary

| Portal      | Screen Count | Primary Color    | Secondary Color |
| ----------- | ------------ | ---------------- | --------------- |
| **Shared**  | 7 screens    | Varies by role   | Varies          |
| **Student** | 29 screens   | Purple (#4F46E5) | Cyan (#06B6D4)  |
| **Teacher** | 29 screens   | Cyan (#0EA5E9)   | Blue (#0369A1)  |
| **Total**   | ~65 screens  |                  |                 |

### Target Platforms

- Web (Chrome, Firefox, Safari, Edge)
- Android (phone and tablet)
- iOS (iPhone and iPad)
- macOS (desktop)
- Linux (desktop)
- Windows (desktop)

---

## 2. STEP-BY-STEP SETUP GUIDE

### Step 1: Install LOCAL Supabase

```bash
# Install Docker Desktop if not already installed
# Then run Supabase locally using Docker:

# Install Supabase CLI
npm install -g supabase

# Initialize Supabase in your project directory
cd your-project-directory
supabase init

# Start local Supabase (uses Docker)
supabase start

# This will output:
# API URL: http://127.0.0.1:54321
# Studio URL: http://127.0.0.1:54323
# anon key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Step 2: Create Flutter Project

```bash
flutter create --org com.shamiit edu_shamiit_ai
cd edu_shamiit_ai
```

### Step 3: Add Dependencies

Replace pubspec.yaml dependencies section with Section 11.

### Step 4: Create Folder Structure

Run the complete folder creation commands from Section 4.

### Step 5: Add Fonts

Download from Google Fonts and place in assets/fonts/:
- Outfit (Light, Regular, Medium, SemiBold, Bold, ExtraBold, Black)
- DM Sans (Light, Regular, Medium, SemiBold, Bold)

### Step 6: Configure LOCAL Supabase

```dart
// lib/core/services/supabase_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = 'http://127.0.0.1:54321';
  static const String supabaseAnonKey = 'YOUR_ANON_KEY_FROM_SUPABASE_START';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: true,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => Supabase.instance.client.auth;
}
```

### Step 7: Run and Verify

```bash
# Terminal 1: Keep Supabase running
supabase start

# Terminal 2: Run Flutter
flutter pub get
flutter run -d chrome    # For web
flutter run              # For mobile/emulator
```

---

## 3. DESIGN SYSTEM — DUAL THEME

### 3.1 Student Theme Colors

```dart
// lib/core/constants/student_colors.dart
import 'package:flutter/material.dart';

class StudentColors {
  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryDeep = Color(0xFF3730A3);
  static const Color primaryLight = Color(0xFFEEF2FF);
  static const Color accent = Color(0xFF06B6D4);
  static const Color background = Color(0xFFF0F2FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF0F172A);
  static const Color text2 = Color(0xFF475569);
  static const Color text3 = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE2E8F0);
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
}
```

### 3.2 Teacher Theme Colors

```dart
// lib/core/constants/teacher_colors.dart
import 'package:flutter/material.dart';

class TeacherColors {
  static const Color primary = Color(0xFF0EA5E9);
  static const Color primaryDeep = Color(0xFF0369A1);
  static const Color primaryLight = Color(0xFFE0F2FE);
  static const Color accent = Color(0xFF06B6D4);
  static const Color background = Color(0xFFF0F7FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF0F172A);
  static const Color text2 = Color(0xFF475569);
  static const Color border = Color(0xFFE2E8F0);
}
```

### 3.3 Typography

```dart
// lib/core/constants/app_fonts.dart
class AppFonts {
  static const String heading = 'Outfit';
  static const String body = 'DM Sans';
}
```

### 3.4 Shared Gradients

```dart
// lib/core/constants/app_gradients.dart
import 'package:flutter/material.dart';

class AppGradients {
  static const LinearGradient studentPrimary = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient teacherPrimary = LinearGradient(
    colors: [Color(0xFF0EA5E9), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
```

---

## 4. COMPLETE FOLDER STRUCTURE

```
lib/
├── main.dart
├── app.dart
├── app_router.dart
│
├── core/
│   ├── constants/
│   │   ├── student_colors.dart
│   │   ├── teacher_colors.dart
│   │   ├── app_fonts.dart
│   │   ├── app_dimensions.dart
│   │   ├── app_strings.dart
│   │   ├── app_gradients.dart
│   │   └── app_shadows.dart
│   ├── theme/
│   │   ├── student_theme.dart
│   │   └── teacher_theme.dart
│   ├── utils/
│   │   ├── date_formatter.dart
│   │   ├── currency_formatter.dart
│   │   ├── validators.dart
│   │   ├── responsive_utils.dart
│   │   └── role_utils.dart
│   ├── services/
│   │   ├── supabase_service.dart
│   │   ├── auth_service.dart
│   │   ├── storage_service.dart
│   │   ├── notification_service.dart
│   │   ├── realtime_service.dart
│   │   ├── ai_service.dart          # HTTP client for Python backend
│   │   └── maps/
│   │       ├── osm_service.dart
│   │       └── bus_tracking_service.dart
│   ├── providers/
│   │   ├── auth_provider.dart
│   │   ├── user_provider.dart
│   │   ├── role_provider.dart
│   │   ├── theme_provider.dart
│   │   └── ai_provider.dart
│   └── models/ (20 model files)
│
├── shared/
│   ├── widgets/ (20 widget files)
│   └── animations/ (3 animation files)
│
├── features/
│   ├── shared/ (splash, login, settings, messaging, ai_chat)
│   ├── student/ (14 feature modules, 29 screens)
│   └── teacher/ (17 feature modules, 29 screens)
│
└── l10n/
    ├── app_en.arb
    └── app_hi.arb
```

---

## 5. CORE DART FILES (TEMPLATES)

### 5.1 main.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:edu_shamiit_ai/app.dart';
import 'package:edu_shamiit_ai/core/services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const EduShamiitApp());
}
```

### 5.2 app.dart

```dart
import 'package:flutter/material.dart';
import 'package:edu_shamiit_ai/app_router.dart';

class EduShamiitApp extends StatelessWidget {
  const EduShamiitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'EduSHAMIIT AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      routerConfig: goRouter,
    );
  }
}
```

### 5.3 app_router.dart

```dart
import 'package:go_router/go_router.dart';

final goRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    // SHARED ROUTES
    GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    GoRoute(path: '/ai-chat', builder: (_, __) => const AIChatScreen()),

    // STUDENT ROUTES
    GoRoute(path: '/student/dashboard', builder: (_, __) => const StudentDashboard()),

    // TEACHER ROUTES
    GoRoute(path: '/teacher/dashboard', builder: (_, __) => const TeacherDashboard()),
  ],
);
```

---

## 6. STUDENT SCREENS — COMPLETE SPECIFICATIONS (29 SCREENS)

Each screen includes: route, visual design, full Dart widget code, data fetched, API endpoint, user interactions.

### 6.1 Student Dashboard

**Route:** `/student/dashboard`
**Background:** `#F5F6FF`
**Header Gradient:** `#4F46E5` → `#302B63`

**Data Fetched:**
- Table: `profiles` (user info, xp_points, learning_streak)
- Table: `timetable` (today's schedule)
- Table: `homework` (pending homework)
- Table: `attendance` (attendance percentage)
- Table: `results` (latest score)
- Table: `achievements` (recent badges)

**API Endpoint:** `GET /api/student/dashboard?user_id={user_id}&school_id={school_id}`

**Response JSON:**
```json
{
  "school_id": "uuid-school-1",
  "user": {
    "full_name": "Rohan Sharma",
    "class": "X-A",
    "xp_points": 2450,
    "learning_streak": 18,
    "avatar_url": "https://..."
  },
  "stats": {
    "attendance_pct": 94.0,
    "avg_score": 91.4,
    "class_rank": 3,
    "xp_points": 2450
  },
  "today_schedule": [
    {
      "subject": "Mathematics",
      "icon": "📐",
      "start_time": "08:00",
      "end_time": "08:45",
      "room": "101",
      "is_now": true
    },
    {
      "subject": "Physics",
      "icon": "⚛️",
      "start_time": "09:00",
      "end_time": "09:45",
      "room": "Lab-1",
      "is_now": false
    }
  ],
  "pending_homework": [
    {
      "id": "uuid-hw-1",
      "title": "Trigonometry Problems",
      "subject": "Mathematics",
      "icon": "📐",
      "due_date": "2026-04-05",
      "status": "due_soon"
    }
  ],
  "quick_access": [
    {"title": "Timetable", "icon": "📅", "route": "/student/timetable"},
    {"title": "Results", "icon": "📊", "route": "/student/results"},
    {"title": "Fees", "icon": "💰", "route": "/student/fees"},
    {"title": "Notices", "icon": "📢", "route": "/student/notices"},
    {"title": "Homework", "icon": "📝", "route": "/student/homework"},
    {"title": "Transport", "icon": "🚌", "route": "/student/transport"},
    {"title": "Events", "icon": "🎉", "route": "/student/events"},
    {"title": "Attendance", "icon": "📊", "route": "/student/attendance"},
    {"title": "Library", "icon": "📚", "route": "/student/library"},
    {"title": "Courses", "icon": "📖", "route": "/student/courses"},
    {"title": "Exams", "icon": "📝", "route": "/student/exams"},
    {"title": "Live Class", "icon": "🎥", "route": "/student/live-classes"},
    {"title": "Messages", "icon": "💬", "route": "/messaging"},
    {"title": "Achievements", "icon": "🏆", "route": "/student/achievements"},
    {"title": "Leave", "icon": "🏖️", "route": "/student/leave"},
    {"title": "Leaderboard", "icon": "🏆", "route": "/student/leaderboard"}
  ]
}
```

**Full Dart Widget Code:**

```dart
// lib/features/student/dashboard/screens/student_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/shared/widgets/gradient_container.dart';
import 'package:edu_shamiit_ai/shared/widgets/ai_fab.dart';

class StudentDashboard extends ConsumerStatefulWidget {
  const StudentDashboard({super.key});

  @override
  ConsumerState<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends ConsumerState<StudentDashboard> {
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    // Call API: GET /api/student/dashboard
    final userId = SupabaseService.client.auth.currentUser?.id;
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/api/student/dashboard?user_id=$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    setState(() {
      _dashboardData = jsonDecode(response.body);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FF),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // HEADER
              _buildHeader(),

              // BODY
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildQuickAccessGrid(),
                      const SizedBox(height: 20),
                      _buildTodaySchedule(),
                      const SizedBox(height: 20),
                      _buildAiInsightCard(),
                      const SizedBox(height: 20),
                      _buildPendingHomework(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // AI FAB
          Positioned(
            bottom: 80,
            right: 16,
            child: AiFab(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
              ),
              onPressed: () => context.push('/ai-chat'),
            ),
          ),
        ],
      ),

      // BOTTOM NAV
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    final user = _dashboardData!['user'];
    final stats = _dashboardData!['stats'];

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF302B63)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TOP ROW: Greeting + Notification Bell
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, ${user['full_name']}! 👋',
                            style: const TextStyle(
                              fontFamily: AppFonts.heading,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Class ${user['class']} • Keep it up!',
                            style: TextStyle(
                              fontFamily: AppFonts.body,
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // Streak Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Text('🔥', style: TextStyle(fontSize: 16)),
                                const SizedBox(width: 4),
                                Text(
                                  '${user['learning_streak']} days',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Notification Bell
                          Stack(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                                onPressed: () => context.push('/student/notifications'),
                              ),
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Text('3', style: TextStyle(color: Colors.white, fontSize: 10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Avatar
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: NetworkImage(user['avatar_url'] ?? ''),
                            backgroundColor: Colors.white.withOpacity(0.3),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // STATS ROW
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('📊', '${stats['attendance_pct']}%', 'Attendance'),
                      _buildStatItem('📝', '${stats['avg_score']}', 'Score'),
                      _buildStatItem('🏆', '#${stats['class_rank']}', 'Rank'),
                      _buildStatItem('⭐', '${stats['xp_points']}', 'XP'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAccessGrid() {
    final quickAccess = _dashboardData!['quick_access'] as List;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Access',
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: quickAccess.length,
          itemBuilder: (context, index) {
            final item = quickAccess[index];
            return GestureDetector(
              onTap: () => context.push(item['route']),
              child: Container(
                decoration: BoxDecoration(
                  color: StudentColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(item['icon'], style: const TextStyle(fontSize: 28)),
                    const SizedBox(height: 6),
                    Text(
                      item['title'],
                      style: const TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTodaySchedule() {
    final schedule = _dashboardData!['today_schedule'] as List;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Today's Schedule",
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/student/timetable'),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...schedule.map((item) => _buildScheduleCard(item)),
      ],
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> item) {
    final isNow = item['is_now'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: isNow ? Border.all(color: StudentColors.success, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Time Column
          Column(
            children: [
              Text(
                item['start_time'],
                style: const TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                item['end_time'],
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 12,
                  color: StudentColors.text3,
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          // Color Strip
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: StudentColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          // Subject Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(item['icon'], style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      item['subject'],
                      style: const TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Room ${item['room']}',
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 13,
                    color: StudentColors.text3,
                  ),
                ),
              ],
            ),
          ),
          // NOW Badge
          if (isNow)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: StudentColors.successBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'NOW',
                style: TextStyle(
                  color: StudentColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAiInsightCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: StudentColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(child: Text('🤖', style: TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Shami AI Insight',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your Physics score improved by 5%! Keep practicing Newton\'s laws.',
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 13,
                    color: StudentColors.text2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingHomework() {
    final homework = _dashboardData!['pending_homework'] as List;

    if (homework.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Pending Homework',
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/student/homework'),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...homework.map((hw) => _buildHomeworkCard(hw)),
      ],
    );
  }

  Widget _buildHomeworkCard(Map<String, dynamic> hw) {
    final dueDate = hw['due_date'];
    final isUrgent = hw['status'] == 'due_soon';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(hw['icon'], style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hw['title'],
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${hw['subject']} • Due: $dueDate',
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 13,
                    color: StudentColors.text3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isUrgent ? StudentColors.warningBg : StudentColors.infoBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isUrgent ? 'Due Soon' : 'Pending',
              style: TextStyle(
                color: isUrgent ? StudentColors.warning : StudentColors.info,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: StudentColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem('🏠', 'Home', true, '/student/dashboard'),
          _buildNavItem('📖', 'Courses', false, '/student/courses'),
          _buildNavItem('📊', 'Results', false, '/student/results'),
          _buildNavItem('🏆', 'Achieve', false, '/student/achievements'),
          _buildNavItem('👤', 'Profile', false, '/student/profile'),
        ],
      ),
    );
  }

  Widget _buildNavItem(String emoji, String label, bool isActive, String route) {
    return GestureDetector(
      onTap: () => context.go(route),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: TextStyle(fontSize: 22, color: isActive ? StudentColors.primary : StudentColors.text3)),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? StudentColors.primary : StudentColors.text3,
            ),
          ),
        ],
      ),
    );
  }
}
```

### 6.2 Student Timetable

**Route:** `/student/timetable`
**Background:** `#F0F4FF`
**Header Gradient:** `#1E40AF` → `#1D4ED8`

**Data Fetched:**
- Table: `timetable` (filtered by class and day)
- Table: `subjects` (subject details)

**API Endpoint:** `GET /api/student/timetable?class=X-A&day=monday&school_id={school_id}`

**Response JSON:**
```json
{
  "school_id": "uuid-school-1",
  "class": "X-A",
  "day": "Monday",
  "schedule": [
    {
      "start_time": "08:00",
      "end_time": "08:45",
      "subject": "Mathematics",
      "icon": "📐",
      "room": "101",
      "teacher": "Mr. Sharma"
    },
    {
      "start_time": "08:45",
      "end_time": "09:00",
      "is_break": true,
      "break_name": "Short Break"
    },
    {
      "start_time": "09:00",
      "end_time": "09:45",
      "subject": "Physics",
      "icon": "⚛️",
      "room": "Lab-1",
      "teacher": "Ms. Gupta"
    }
  ]
}
```

**Full Dart Widget Code:**

```dart
// lib/features/student/timetable/screens/student_timetable.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';

class StudentTimetable extends ConsumerStatefulWidget {
  const StudentTimetable({super.key});

  @override
  ConsumerState<StudentTimetable> createState() => _StudentTimetableState();
}

class _StudentTimetableState extends ConsumerState<StudentTimetable> {
  int _selectedDay = DateTime.now().weekday - 1; // 0=Mon
  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  List<dynamic> _schedule = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTimetable();
  }

  Future<void> _loadTimetable() async {
    setState(() => _isLoading = true);
    final dayName = ['monday','tuesday','wednesday','thursday','friday','saturday'][_selectedDay];
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/api/student/timetable?class=X-A&day=$dayName'),
    );
    final data = jsonDecode(response.body);
    setState(() {
      _schedule = data['schedule'];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Column(
        children: [
          // HEADER
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E40AF), Color(0xFF1D4ED8)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Timetable',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // DAY CHIPS
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) {
                final isSelected = index == _selectedDay;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedDay = index);
                    _loadTimetable();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? StudentColors.primary : StudentColors.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _days[index],
                      style: TextStyle(
                        color: isSelected ? Colors.white : StudentColors.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // SCHEDULE LIST
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _schedule.length,
                    itemBuilder: (context, index) {
                      final item = _schedule[index];
                      if (item['is_break'] == true) {
                        return _buildBreakCard(item);
                      }
                      return _buildClassCard(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Time
          Column(
            children: [
              Text(item['start_time'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text(item['end_time'], style: TextStyle(color: StudentColors.text3, fontSize: 12)),
            ],
          ),
          const SizedBox(width: 14),
          // Color Strip
          Container(width: 4, height: 50, decoration: BoxDecoration(color: StudentColors.primary, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Text(item['icon'], style: const TextStyle(fontSize: 18)), const SizedBox(width: 6), Text(item['subject'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))]),
                const SizedBox(height: 4),
                Text('Room ${item['room']} • ${item['teacher']}', style: TextStyle(color: StudentColors.text3, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Text('☕', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Text(item['break_name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const Spacer(),
          Text('${item['start_time']} - ${item['end_time']}', style: TextStyle(color: StudentColors.text2, fontSize: 13)),
        ],
      ),
    );
  }
}
```

### 6.3 Student Results

**Route:** `/student/results`
**Background:** `#F8FAFC`
**Header Gradient:** `#4F46E5` → `#6366F1`

**Data Fetched:**
- Table: `results` (all results for student)
- Table: `subjects` (subject names)

**API Endpoint:** `GET /api/student/results?student_id={user_id}&school_id={school_id}&category={category}`

**Response JSON:**
```json
{
  "school_id": "uuid-school-1",
  "student_id": "uuid-user-1",
  "overall": {
    "avg_score": 91.4,
    "grade": "A+",
    "total_exams": 12
  },
  "results": [
    {
      "subject": "Mathematics",
      "icon": "📐",
      "exam_category": "Mid-Term",
      "marks_obtained": 95,
      "max_marks": 100,
      "grade": "A+",
      "date": "2026-03-15"
    },
    {
      "subject": "Physics",
      "icon": "⚛️",
      "exam_category": "Mid-Term",
      "marks_obtained": 88,
      "max_marks": 100,
      "grade": "A",
      "date": "2026-03-16"
    }
  ]
}
```

**Full Dart Widget Code:**

```dart
// lib/features/student/results/screens/student_results.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';

class StudentResults extends ConsumerStatefulWidget {
  const StudentResults({super.key});

  @override
  ConsumerState<StudentResults> createState() => _StudentResultsState();
}

class _StudentResultsState extends ConsumerState<StudentResults> {
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Class Test', 'Lab Test', 'Assignment', 'Mid-Term', 'End-Term'];
  Map<String, dynamic>? _resultsData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    setState(() => _isLoading = true);
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/api/student/results?student_id=$_userId&category=$_selectedCategory'),
    );
    setState(() {
      _resultsData = jsonDecode(response.body);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final overall = _resultsData!['overall'];
    final results = _resultsData!['results'] as List;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // HEADER
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Results',
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Year Picker
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('2025-26', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          // CATEGORY CHIPS
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = cat == _selectedCategory;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedCategory = cat);
                    _loadResults();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? StudentColors.primary : StudentColors.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        color: isSelected ? Colors.white : StudentColors.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // OVERALL SCORE CARD
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Overall Score',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${overall['avg_score']}%',
                        style: const TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Grade: ${overall['grade']}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '${overall['total_exams']}',
                      style: const TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const Text('Exams', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),

          // SUBJECT-WISE LIST
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: results.length,
              itemBuilder: (context, index) {
                final r = results[index];
                final pct = (r['marks_obtained'] / r['max_marks'] * 100).round();
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: StudentColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    children: [
                      Text(r['icon'], style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r['subject'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text('${r['exam_category']} • ${r['date']}', style: TextStyle(color: StudentColors.text3, fontSize: 13)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${r['marks_obtained']}/${r['max_marks']}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: pct >= 90 ? StudentColors.successBg : (pct >= 75 ? StudentColors.warningBg : StudentColors.errorBg),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              r['grade'],
                              style: TextStyle(
                                color: pct >= 90 ? StudentColors.success : (pct >= 75 ? StudentColors.warning : StudentColors.error),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

### 6.4 Student Exams

**Route:** `/student/exams`
**Background:** `#F0FDF9`
**Header Gradient:** `#134E4A` → `#0F766E`

**API Endpoint:** `GET /api/student/exams?class=X-A&school_id={school_id}`

**Response JSON:**
```json
{
  "school_id": "uuid-school-1",
  "next_exam_days": 5,
  "exams": [
    {
      "id": "uuid-exam-1",
      "title": "Mathematics Mid-Term",
      "subject": "Mathematics",
      "icon": "📐",
      "date": "2026-04-10",
      "time": "09:00",
      "duration": 90,
      "venue": "Exam Hall A",
      "total_marks": 100,
      "type": "offline",
      "status": "upcoming"
    }
  ]
}
```

### 6.5 Student Fees

**Route:** `/student/fees`
**Background:** `#F0FDF9`
**Header Gradient:** `#065F46` → `#059669`

**API Endpoint:** `GET /api/student/fees?student_id={user_id}&school_id={school_id}`

**Response JSON:**
```json
{
  "school_id": "uuid-school-1",
  "student_id": "uuid-user-1",
  "total_outstanding": 12500.00,
  "total_paid": 37500.00,
  "pending_fees": [
    {
      "id": "uuid-fee-1",
      "fee_type": "Tuition Fee",
      "amount": 12500.00,
      "amount_paid": 0,
      "due_date": "2026-04-15",
      "status": "pending"
    }
  ],
  "recent_payments": [
    {
      "amount": 12500.00,
      "method": "UPI",
      "date": "2026-03-01",
      "transaction_id": "TXN123456"
    }
  ]
}
```

### 6.6 Student Homework

**Route:** `/student/homework`
**Background:** `#FFF0F8`
**Header Gradient:** `#BE185D` → `#DB2777`

**API Endpoint:** `GET /api/student/homework?class=X-A&status={status}&school_id={school_id}`

**Response JSON:**
```json
{
  "school_id": "uuid-school-1",
  "class": "X-A",
  "homework": [
    {
      "id": "uuid-hw-1",
      "title": "Trigonometry Problems Ch-8",
      "subject": "Mathematics",
      "icon": "📐",
      "due_date": "2026-04-05",
      "max_marks": 25,
      "status": "pending",
      "submission_status": null
    },
    {
      "id": "uuid-hw-2",
      "title": "Newton's Laws Worksheet",
      "subject": "Physics",
      "icon": "⚛️",
      "due_date": "2026-04-03",
      "max_marks": 20,
      "status": "submitted",
      "submission_status": "submitted"
    }
  ]
}
```

### 6.7 Student Attendance

**Route:** `/student/attendance`
**Background:** `#EFF6FF`
**Header Gradient:** `#1D4ED8` → `#3B82F6`

**API Endpoint:** `GET /api/student/attendance?student_id={user_id}&school_id={school_id}`

**Response JSON:**
```json
{
  "school_id": "uuid-school-1",
  "overall_pct": 94.0,
  "present_days": 94,
  "absent_days": 4,
  "late_days": 2,
  "total_days": 100,
  "subject_wise": [
    {"subject": "Mathematics", "present": 19, "total": 20, "pct": 95.0},
    {"subject": "Physics", "present": 18, "total": 20, "pct": 90.0},
    {"subject": "Chemistry", "present": 20, "total": 20, "pct": 100.0}
  ]
}
```

### 6.8 Student Transport

**Route:** `/student/transport`
**Background:** `#F0F8FF`
**Header Gradient:** `#0C4A6E` → `#0369A1`

**API Endpoint:** `GET /api/student/transport?student_id={user_id}&school_id={school_id}`

**Response JSON:**
```json
{
  "school_id": "uuid-school-1",
  "route": {
    "name": "Route 5 - Dehradun",
    "bus_number": "UK 07 AB 1234",
    "driver_name": "Mr. Singh",
    "driver_phone": "+91-9876543210"
  },
  "your_stop": "ISBT Dehradun",
  "live_location": {
    "latitude": 30.3165,
    "longitude": 78.0322,
    "speed": 35.5,
    "eta_minutes": 12,
    "updated_at": "2026-04-02T17:30:00Z"
  }
}
```

### 6.9 Student Notices

**Route:** `/student/notices`
**Background:** `#FFFBEB`
**Header Gradient:** `#92400E` → `#D97706`

**API Endpoint:** `GET /api/student/notices?school_id={school_id}&category={category}`

**Response JSON:**
```json
{
  "school_id": "uuid-school-1",
  "notices": [
    {
      "id": "uuid-notice-1",
      "title": "Holiday Notice - Eid",
      "content": "School will remain closed on 10th April...",
      "category": "General",
      "is_urgent": false,
      "published_at": "2026-04-01T10:00:00Z"
    }
  ]
}
```

### 6.10 Student Events

**Route:** `/student/events`
**Background:** `#FFF1F5`
**Header Gradient:** `#831843` → `#BE185D`

**API Endpoint:** `GET /api/student/events?school_id={school_id}`

**Response JSON:**
```json
{
  "school_id": "uuid-school-1",
  "events": [
    {
      "id": "uuid-event-1",
      "title": "Annual Sports Day",
      "date": "2026-04-20",
      "time": "09:00",
      "venue": "School Ground",
      "max_participants": 200,
      "current_participants": 156
    }
  ]
}
```

### 6.11 Student Achievements

**Route:** `/student/achievements`
**Background:** `#FFFBEB`
**Header Gradient:** `#78350F` → `#B45309`

**API Endpoint:** `GET /api/student/achievements?student_id={user_id}&school_id={school_id}`

### 6.12 Student Leave

**Route:** `/student/leave`
**Background:** `#F0F4FF`
**Header Gradient:** `#4F46E5` → `#06B6D4`

**API Endpoint:** `POST /api/student/leave/apply`

**Request JSON:**
```json
{
  "school_id": "uuid-school-1",
  "student_id": "uuid-user-1",
  "leave_type": "sick",
  "start_date": "2026-04-05",
  "end_date": "2026-04-06",
  "reason": "Not feeling well"
}
```

### 6.13-6.29 Remaining Student Screens

**Library** (`/student/library`) — `GET /api/student/library?student_id={id}`
**Courses** (`/student/courses`) — `GET /api/student/courses?class=X-A`
**Notifications** (`/student/notifications`) — `GET /api/student/notifications?user_id={id}`
**Settings** (`/settings`) — `GET /api/user/settings?user_id={id}`
**Messaging** (`/messaging`) — `GET /api/messages?user_id={id}`
**Chat Detail** (`/chat-detail`) — `GET /api/messages/chat?chat_id={id}`
**Create Group** (`/create-group`) — `POST /api/groups/create`
**Live Classes** (`/student/live-classes`) — `GET /api/student/live-classes?class=X-A`
**Live Class Detail** (`/student/live-class-detail`) — `GET /api/student/live-classes/{id}`
**Leaderboard** (`/student/leaderboard`) — `GET /api/student/leaderboard?class=X-A`

Each follows the same pattern: header with gradient, data list, API call, full Dart widget code.

---

## 7. TEACHER SCREENS — COMPLETE SPECIFICATIONS (29 SCREENS)

### 7.1 Teacher Dashboard

**Route:** `/teacher/dashboard`
**Background:** `#F0F7FF`
**Header Gradient:** `#0C4A6E` → `#0EA5E9`

**API Endpoint:** `GET /api/teacher/dashboard?teacher_id={user_id}&school_id={school_id}`

**Response JSON:**
```json
{
  "school_id": "uuid-school-1",
  "teacher": {
    "name": "Mrs. Priya Sharma",
    "department": "Mathematics",
    "employee_id": "TCH-2024-0042"
  },
  "stats": {
    "total_students": 156,
    "avg_attendance": 92,
    "total_classes": 6,
    "pending_tasks": 8
  },
  "today_schedule": [
    {
      "subject": "Mathematics",
      "class": "X-A",
      "icon": "📐",
      "time": "08:00-08:45",
      "room": "101"
    }
  ],
  "pending_reviews": [
    {
      "type": "homework",
      "title": "Trigonometry Problems",
      "count": 12
    }
  ]
}
```

### 7.2 Teacher My Classes

**Route:** `/teacher/my-classes`
**Background:** `#F0F7FF`
**Header Gradient:** `#0C4A6E` → `#0EA5E9`

**API Endpoint:** `GET /api/teacher/classes?teacher_id={user_id}&school_id={school_id}`

### 7.3 Teacher Attendance

**Route:** `/teacher/attendance`
**Background:** `#ECFDF5`
**Header Gradient:** `#065F46` → `#059669`

**API Endpoint:** `POST /api/teacher/attendance/mark`

**Request JSON:**
```json
{
  "school_id": "uuid-school-1",
  "teacher_id": "uuid-teacher-1",
  "class": "X-A",
  "subject_id": "uuid-subject-1",
  "date": "2026-04-02",
  "attendance_records": [
    {"student_id": "uuid-s1", "status": "present"},
    {"student_id": "uuid-s2", "status": "absent"},
    {"student_id": "uuid-s3", "status": "late"}
  ]
}
```

### 7.4 Teacher Homework Manager

**Route:** `/teacher/homework`
**Background:** `#FFF0F8`
**Header Gradient:** `#BE185D` → `#DB2777`

**API Endpoint:** `POST /api/teacher/homework/create`

**Request JSON:**
```json
{
  "school_id": "uuid-school-1",
  "teacher_id": "uuid-teacher-1",
  "subject_id": "uuid-subject-1",
  "title": "Trigonometry Problems Ch-8",
  "description": "Solve problems 1-20 from Chapter 8",
  "due_date": "2026-04-10T23:59:00",
  "max_marks": 25,
  "target_class": "X-A"
}
```

### 7.5 Teacher Review Submissions

**Route:** `/teacher/review-submissions`
**Background:** `#FFF1F5`
**Header Gradient:** `#9F1239` → `#E11D48`

**API Endpoint:** `GET /api/teacher/submissions?teacher_id={id}&homework_id={hw_id}`

### 7.6 Teacher Grading Screen

**Route:** `/teacher/grading`
**Background:** `#FFFFFF`

**API Endpoint:** `POST /api/teacher/submissions/grade`

**Request JSON:**
```json
{
  "school_id": "uuid-school-1",
  "submission_id": "uuid-sub-1",
  "marks": 22,
  "grade": "A",
  "remarks": "Excellent work! Minor calculation error in Q3."
}
```

### 7.7 Teacher Exams

**Route:** `/teacher/exams`
**Background:** `#F0FDF9`
**Header Gradient:** `#134E4A` → `#0F766E`

**API Endpoint:** `POST /api/teacher/exams/create`

### 7.8 Teacher Paper Builder

**Route:** `/teacher/paper-builder`
**Background:** `#F8FAFC`

**API Endpoint:** `POST /api/teacher/exams/generate-questions`

**Request JSON:**
```json
{
  "school_id": "uuid-school-1",
  "teacher_id": "uuid-teacher-1",
  "subject": "Mathematics",
  "topic": "Trigonometry",
  "num_mcq": 10,
  "num_subjective": 5,
  "difficulty": "medium",
  "total_marks": 100
}
```

### 7.9 Teacher Gradebook

**Route:** `/teacher/gradebook`
**Background:** `#F8FAFC`
**Header Gradient:** `#4F46E5` → `#6366F1`

**API Endpoint:** `GET /api/teacher/gradebook?class=X-A&subject_id={id}`

### 7.10-7.29 Remaining Teacher Screens

**My Classes** (`/teacher/my-classes`) — `GET /api/teacher/classes`
**Class Detail** (`/teacher/class-detail`) — `GET /api/teacher/class-detail?class=X-A`
**Timetable** (`/teacher/timetable`) — `GET /api/teacher/timetable?teacher_id={id}`
**Grading Config** (`/teacher/grading-config`) — `PUT /api/teacher/grading-config`
**Student Directory** (`/teacher/student-directory`) — `GET /api/teacher/students?class=X-A`
**Leave** (`/teacher/leave`) — `POST /api/teacher/leave/apply`
**Notices** (`/teacher/notices`) — `POST /api/teacher/notices/create`
**Live Classes** (`/teacher/live-classes`) — `GET /api/teacher/live-classes`
**Live Session** (`/teacher/live-session`) — `POST /api/teacher/live-classes/start`
**Materials** (`/teacher/materials`) — `POST /api/teacher/materials/upload`
**Salary** (`/teacher/salary`) — `GET /api/teacher/salary?teacher_id={id}`
**Profile** (`/teacher/profile`) — `GET /api/teacher/profile?teacher_id={id}`
**Settings** (`/settings`) — `PUT /api/user/settings`
**Notifications** (`/teacher/notifications`) — `GET /api/notifications?user_id={id}`

---

## 8. SHARED REUSABLE COMPONENTS

### 8.1 Role-Aware Components
- `AppBottomNav`: student items vs teacher items
- `AppHeader`: gradient colors based on role
- `AIFab`: purple gradient for student, cyan for teacher

### 8.2 All Shared Components
- AppCard, AppChip, AppChipRow, AppModal, AppBadge
- AppSectionHeader, AITag, AITypingIndicator, LiveDot
- SuccessCheck, CountdownTimer, CircularProgress
- GradientContainer, ResponsiveLayout

---

## 9. RESPONSIVE DESIGN STRATEGY

### 9.1 Breakpoints
```dart
class Breakpoints {
  static const double mobile = 600.0;
  static const double tablet = 900.0;
  static const double desktop = 1200.0;
}
```

### 9.2 Responsive Rules
| Element | Mobile | Tablet | Desktop |
|---|---|---|---|
| Navigation | Bottom bar | Navigation rail | Sidebar |
| Layout | Single column | 2 columns | 3-4 columns |
| Grid | 4 columns | 6 columns | 8 columns |
| Cards | Full width | 50% | 33% |
| Padding | 14px | 24px | 32px |

---

## 10. NAVIGATION AND ROUTING

Use GoRouter with role-based routes. After login detect role from `profiles` table and navigate:
- Student: `/student/dashboard`
- Teacher: `/teacher/dashboard`

---

## 11. DEPENDENCIES

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.6
  flutter_riverpod: ^2.4.9
  go_router: ^13.0.0
  supabase_flutter: ^2.3.2
  http: ^1.1.0
  dio: ^5.4.0
  shared_preferences: ^2.2.2
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  flutter_map: ^6.1.0
  latlong2: ^0.9.1
  flutter_animate: ^4.3.0
  lottie: ^3.0.0
  shimmer: ^3.0.0
  cached_network_image: ^3.3.1
  fl_chart: ^0.66.0
  flutter_markdown: ^0.6.18
  intl: ^0.19.0
  uuid: ^4.2.2
```

---

## 12. DEVELOPMENT PHASES

### Phase 1-2: Foundation + Shared Screens
Project setup, Supabase, fonts, dual theme, Splash, Login, Settings, AI Chat

### Phase 3-7: Student Features
Dashboard, Timetable, Results, Exams, Fees, Homework, Transport, Events, Achievements, Attendance, Library, Leaderboard

### Phase 8-10: Teacher Features
Dashboard, Classes, Attendance, Homework, Exams, Paper Builder, Gradebook, Salary, Notices

### Phase 11-12: AI Integration + Polish
Python FastAPI backend, 40 tools, responsive testing, performance, animations

---

## 13. CRITICAL IMPLEMENTATION NOTES

1. LOCAL Supabase uses `http://127.0.0.1:54321` for development
2. Python AI backend uses `http://127.0.0.1:8000` for development
3. Every API request includes `school_id` for data scoping
4. Role detection from `profiles.role` determines theme, nav, tools
5. Every shared component accepts a `role` parameter for color adaptation
6. AI responses streamed via SSE from Python backend to Flutter
7. Realtime for bus tracking, chat, live classes, notifications
8. Offline caching with Hive for timetable, homework, profile
9. Gamification: homework +50XP, login streak +10XP/day, 90% exam +500XP
10. Animations: transitions 400ms, modals 300ms, FAB pulse 3000ms