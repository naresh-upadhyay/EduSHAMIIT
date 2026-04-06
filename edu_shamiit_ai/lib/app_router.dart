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
import 'package:edu_shamiit_ai/features/student/leave/screens/student_leave.dart';
import 'package:edu_shamiit_ai/features/student/profile/screens/student_profile.dart';
import 'package:edu_shamiit_ai/features/student/library/screens/student_library.dart';
import 'package:edu_shamiit_ai/features/student/courses/screens/student_courses.dart';
import 'package:edu_shamiit_ai/features/student/notifications/screens/student_notifications.dart';
import 'package:edu_shamiit_ai/features/student/notices/screens/student_notices_screen.dart';
import 'package:edu_shamiit_ai/features/student/transport/screens/student_transport_screen.dart';
import 'package:edu_shamiit_ai/features/student/events/screens/student_events_screen.dart';
import 'package:edu_shamiit_ai/features/student/achievements/screens/student_achievements_screen.dart';
import 'package:edu_shamiit_ai/features/student/live_classes/screens/student_live_classes.dart';
import 'package:edu_shamiit_ai/features/student/leaderboard/screens/student_leaderboard.dart';
import 'package:edu_shamiit_ai/features/student/messaging/screens/student_messaging.dart';
import 'package:edu_shamiit_ai/features/student/settings/screens/student_settings.dart';
import 'package:edu_shamiit_ai/features/student/exams/screens/student_exams.dart';
import 'package:edu_shamiit_ai/features/student/exams/screens/online_exam_screen.dart';
import 'package:edu_shamiit_ai/features/teacher/dashboard/screens/teacher_dashboard.dart';
import 'package:edu_shamiit_ai/features/teacher/timetable/screens/teacher_timetable.dart';
import 'package:edu_shamiit_ai/features/teacher/attendance/screens/teacher_attendance.dart';
import 'package:edu_shamiit_ai/features/teacher/homework/screens/teacher_homework.dart';
import 'package:edu_shamiit_ai/features/teacher/gradebook/screens/teacher_gradebook.dart';
import 'package:edu_shamiit_ai/features/teacher/my_classes/screens/teacher_my_classes.dart';
import 'package:edu_shamiit_ai/features/teacher/notices/screens/teacher_notices.dart';
import 'package:edu_shamiit_ai/features/teacher/profile/screens/teacher_profile.dart';

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
      builder: (_, __) => const AiChatScreen(),
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
      builder: (_, __) => const StudentNotices(),
    ),
    GoRoute(
      path: '/student/homework',
      builder: (_, __) => const StudentHomework(),
    ),
    GoRoute(
      path: '/student/transport',
      builder: (_, __) => const StudentTransport(),
    ),
    GoRoute(
      path: '/student/events',
      builder: (_, __) => const StudentEvents(),
    ),
    GoRoute(
      path: '/student/attendance',
      builder: (_, __) => const StudentAttendance(),
    ),
    GoRoute(
      path: '/student/achievements',
      builder: (_, __) => const StudentAchievements(),
    ),
    GoRoute(
      path: '/student/profile',
      builder: (_, __) => const StudentProfile(),
    ),
    GoRoute(
      path: '/student/leave-application',
      builder: (_, __) => const StudentLeave(),
    ),
    GoRoute(
      path: '/student/library',
      builder: (_, __) => const StudentLibrary(),
    ),
    GoRoute(
      path: '/student/courses',
      builder: (_, __) => const StudentCourses(),
    ),
    GoRoute(
      path: '/student/notifications',
      builder: (_, __) => const StudentNotifications(),
    ),
    GoRoute(
      path: '/student/live-classes',
      builder: (_, __) => const StudentLiveClasses(),
    ),
    GoRoute(
      path: '/student/leaderboard',
      builder: (_, __) => const StudentLeaderboard(),
    ),
    GoRoute(
      path: '/student/messaging',
      builder: (_, __) => const StudentMessaging(),
    ),
    GoRoute(
      path: '/student/settings',
      builder: (_, __) => const StudentSettings(),
    ),
    GoRoute(
      path: '/student/exams',
      builder: (_, __) => const StudentExamsScreen(),
    ),
    GoRoute(
      path: '/student/online-exam',
      builder: (_, __) => const OnlineExamScreen(),
    ),

    // TEACHER ROUTES
    GoRoute(
      path: '/teacher/dashboard',
      builder: (_, __) => const TeacherDashboard(),
    ),
    GoRoute(
      path: '/teacher/timetable',
      builder: (_, __) => const TeacherTimetable(),
    ),
    GoRoute(
      path: '/teacher/attendance',
      builder: (_, __) => const TeacherAttendance(),
    ),
    GoRoute(
      path: '/teacher/homework',
      builder: (_, __) => const TeacherHomework(),
    ),
    GoRoute(
      path: '/teacher/gradebook',
      builder: (_, __) => const TeacherGradebook(),
    ),
    GoRoute(
      path: '/teacher/my-classes',
      builder: (_, __) => const TeacherMyClasses(),
    ),
    GoRoute(
      path: '/teacher/notices',
      builder: (_, __) => const TeacherNotices(),
    ),
    GoRoute(
      path: '/teacher/profile',
      builder: (_, __) => const TeacherProfile(),
    ),
  ],
);