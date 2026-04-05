import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/features/shared/splash/screens/splash_screen.dart';
import 'package:edu_shamiit_ai/features/shared/login/screens/login_screen.dart';
import 'package:edu_shamiit_ai/features/shared/login/screens/forgot_password_screen.dart';
import 'package:edu_shamiit_ai/features/shared/login/screens/otp_verification_screen.dart';
import 'package:edu_shamiit_ai/features/shared/login/screens/reset_password_screen.dart';
import 'package:edu_shamiit_ai/features/shared/login/screens/password_reset_success_screen.dart';
import 'package:edu_shamiit_ai/features/shared/settings/screens/settings_screen.dart';
import 'package:edu_shamiit_ai/features/shared/ai_chat/screens/ai_chat_screen.dart';
import 'package:edu_shamiit_ai/features/student/dashboard/screens/student_dashboard.dart';
import 'package:edu_shamiit_ai/features/student/timetable/screens/student_timetable.dart';
import 'package:edu_shamiit_ai/features/student/results/screens/student_results.dart';
import 'package:edu_shamiit_ai/features/student/homework/screens/student_homework.dart';
import 'package:edu_shamiit_ai/features/student/attendance/screens/student_attendance.dart';
import 'package:edu_shamiit_ai/features/student/fees/screens/student_fees.dart';
import 'package:edu_shamiit_ai/features/teacher/dashboard/screens/teacher_dashboard.dart';

final goRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    // SHARED ROUTES
    GoRoute(
      path: '/splash',
      builder: (_, __) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (_, __) => const LoginScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (_, __) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/otp-verification',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>?;
        final email = args?['email'] as String? ?? '';
        return OtpVerificationScreen(email: email);
      },
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>?;
        final email = args?['email'] as String? ?? '';
        final otp = args?['otp'] as String? ?? '';
        return ResetPasswordScreen(email: email, otp: otp);
      },
    ),
    GoRoute(
      path: '/password-reset-success',
      builder: (_, __) => const PasswordResetSuccessScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (_, __) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/ai-chat',
      builder: (_, __) => const AIChatScreen(),
    ),

    // STUDENT ROUTES
    GoRoute(
      path: '/student/dashboard',
      builder: (_, __) => const StudentDashboard(),
    ),
    GoRoute(
      path: '/student/timetable',
      builder: (_, __) => const StudentTimetable(),
    ),
    GoRoute(
      path: '/student/results',
      builder: (_, __) => const StudentResults(),
    ),
    GoRoute(
      path: '/student/fees',
      builder: (_, __) => const StudentFees(),
    ),
    GoRoute(
      path: '/student/notices',
      builder: (_, __) => const Scaffold(
        body: Center(child: Text('Notices Screen')),
      ),
    ),
    GoRoute(
      path: '/student/homework',
      builder: (_, __) => const StudentHomework(),
    ),
    GoRoute(
      path: '/student/transport',
      builder: (_, __) => const Scaffold(
        body: Center(child: Text('Transport Screen')),
      ),
    ),
    GoRoute(
      path: '/student/events',
      builder: (_, __) => const Scaffold(
        body: Center(child: Text('Events Screen')),
      ),
    ),
    GoRoute(
      path: '/student/attendance',
      builder: (_, __) => const StudentAttendance(),
    ),
    GoRoute(
      path: '/student/courses',
      builder: (_, __) => const Scaffold(
        body: Center(child: Text('Courses Screen')),
      ),
    ),
    GoRoute(
      path: '/student/achievements',
      builder: (_, __) => const Scaffold(
        body: Center(child: Text('Achievements Screen')),
      ),
    ),
    GoRoute(
      path: '/student/profile',
      builder: (_, __) => const Scaffold(
        body: Center(child: Text('Profile Screen')),
      ),
    ),

    // TEACHER ROUTES
    GoRoute(
      path: '/teacher/dashboard',
      builder: (_, __) => const TeacherDashboard(),
    ),
    GoRoute(
      path: '/teacher/timetable',
      builder: (_, __) => const Scaffold(
        body: Center(child: Text('Teacher Timetable Screen')),
      ),
    ),
    GoRoute(
      path: '/teacher/attendance',
      builder: (_, __) => const Scaffold(
        body: Center(child: Text('Teacher Attendance Screen')),
      ),
    ),
    GoRoute(
      path: '/teacher/homework',
      builder: (_, __) => const Scaffold(
        body: Center(child: Text('Teacher Homework Screen')),
      ),
    ),
    GoRoute(
      path: '/teacher/gradebook',
      builder: (_, __) => const Scaffold(
        body: Center(child: Text('Gradebook Screen')),
      ),
    ),
    GoRoute(
      path: '/teacher/my-classes',
      builder: (_, __) => const Scaffold(
        body: Center(child: Text('My Classes Screen')),
      ),
    ),
    GoRoute(
      path: '/teacher/notices',
      builder: (_, __) => const Scaffold(
        body: Center(child: Text('Teacher Notices Screen')),
      ),
    ),
    GoRoute(
      path: '/teacher/profile',
      builder: (_, __) => const Scaffold(
        body: Center(child: Text('Teacher Profile Screen')),
      ),
    ),
  ],
);