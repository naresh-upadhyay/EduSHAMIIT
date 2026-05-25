import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/providers/auth_provider.dart';
import 'package:edu_shamiit_ai/core/providers/role_provider.dart';
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
import 'package:edu_shamiit_ai/features/teacher/grading/screens/teacher_grading.dart';
import 'package:edu_shamiit_ai/features/teacher/exams/screens/teacher_exams.dart';
import 'package:edu_shamiit_ai/features/teacher/paper_builder/screens/teacher_paper_builder.dart';
import 'package:edu_shamiit_ai/features/teacher/leave/screens/teacher_leave.dart';
import 'package:edu_shamiit_ai/features/teacher/salary/screens/teacher_salary.dart';
import 'package:edu_shamiit_ai/features/teacher/submissions/screens/teacher_submissions.dart';
import 'package:edu_shamiit_ai/features/teacher/notifications/screens/teacher_notifications.dart';
import 'package:edu_shamiit_ai/features/teacher/live_classes/screens/teacher_live_classes.dart';
import 'package:edu_shamiit_ai/features/teacher/materials/screens/teacher_materials.dart';
import 'package:edu_shamiit_ai/features/teacher/student_directory/screens/teacher_student_directory.dart';
import 'package:edu_shamiit_ai/shared/widgets/student_shell_scaffold.dart';
import 'package:edu_shamiit_ai/shared/widgets/teacher_shell_scaffold.dart';

final _studentShellKey = GlobalKey<NavigatorState>(debugLabel: 'studentShell');
final _teacherShellKey = GlobalKey<NavigatorState>(debugLabel: 'teacherShell');

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(
      authProvider,
      (_, __) => notifyListeners(),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isAuth = authState.isAuthenticated;
      
      final path = state.uri.path;
      final isSplash = path == '/splash';
      final isLogin = path == '/login';
      final isForgot = path == '/forgot-password';
      final isOtp = path == '/otp-verification';
      final isReset = path == '/reset-password';
      final isResetSuccess = path == '/password-reset-success';
      
      final isPublic = isSplash || isLogin || isForgot || isOtp || isReset || isResetSuccess;

      // While auth is loading, stay at splash (safety net — should not normally
      // happen since main.dart awaits initialize() before runApp, but guards
      // against any brief isLoading=true state during Supabase token refresh).
      if (authState.isLoading && !isSplash) {
        return '/splash';
      }

      // If user is NOT authenticated, and trying to access a private route, force to login
      if (!isAuth && !isPublic && !authState.isLoading) {
        return '/login';
      }

      // If user IS authenticated and trying to access a public route (like login), push to dashboard
      if (isAuth && isPublic && !isSplash) {
        final role = authState.role;
        if (role.value == 'teacher') {
          return '/teacher/dashboard';
        } else {
          return '/student/dashboard';
        }
      }

      // If user IS authenticated, let's enforce role constraints and path mismatches
      if (isAuth) {
        final role = authState.role;
        final isTeacher = role.value == 'teacher';
        
        if (isTeacher && path.startsWith('/student')) {
          if (path == '/student/settings') return '/teacher/settings';
          return '/teacher/dashboard';
        }
        if (!isTeacher && path.startsWith('/teacher')) {
          if (path == '/teacher/settings') return '/student/settings';
          return '/student/dashboard';
        }
      }

      return null; // No redirect needed
    },
    routes: [
    // ─────────────── SHARED ROUTES (no bottom nav) ───────────────
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
      redirect: (context, state) {
        final authState = ref.read(authProvider);
        final isTeacher = authState.role.value == 'teacher';
        return isTeacher ? '/teacher/settings' : '/student/settings';
      },
    ),

    // ─────────────── STUDENT SHELL (persistent bottom nav) ───────────────
    ShellRoute(
      navigatorKey: _studentShellKey,
      builder: (context, state, child) => StudentShellScaffold(
        location: state.uri.toString(),
        child: child,
      ),
      routes: [
        GoRoute(
          path: '/student/dashboard',
          pageBuilder: (_, __) => const NoTransitionPage(child: StudentDashboard()),
        ),
        GoRoute(
          path: '/student/timetable',
          pageBuilder: (_, __) => const NoTransitionPage(child: StudentTimetable()),
        ),
        GoRoute(
          path: '/student/results',
          pageBuilder: (_, __) => const NoTransitionPage(child: StudentResults()),
        ),
        GoRoute(
          path: '/student/fees',
          pageBuilder: (_, __) => const NoTransitionPage(child: StudentFees()),
        ),
        GoRoute(
          path: '/student/notices',
          pageBuilder: (_, __) => const NoTransitionPage(child: StudentNotices()),
        ),
        GoRoute(
          path: '/student/homework',
          pageBuilder: (_, __) => const NoTransitionPage(child: StudentHomework()),
        ),
        GoRoute(
          path: '/student/transport',
          pageBuilder: (_, __) => const NoTransitionPage(child: StudentTransport()),
        ),
        GoRoute(
          path: '/student/events',
          pageBuilder: (_, __) => const NoTransitionPage(child: StudentEvents()),
        ),
        GoRoute(
          path: '/student/attendance',
          pageBuilder: (_, __) => const NoTransitionPage(child: StudentAttendance()),
        ),
        GoRoute(
          path: '/student/achievements',
          pageBuilder: (_, __) => const NoTransitionPage(child: StudentAchievements()),
        ),
        GoRoute(
          path: '/student/profile',
          pageBuilder: (_, __) => const NoTransitionPage(child: StudentProfile()),
        ),
        GoRoute(
          path: '/student/leave-application',
          pageBuilder: (_, __) => const NoTransitionPage(child: StudentLeave()),
        ),
        GoRoute(
          path: '/student/library',
          pageBuilder: (_, __) => const NoTransitionPage(child: StudentLibrary()),
        ),
        GoRoute(
          path: '/student/courses',
          pageBuilder: (_, __) => const NoTransitionPage(child: StudentCourses()),
        ),
        GoRoute(
          path: '/student/notifications',
          pageBuilder: (_, __) => const NoTransitionPage(child: StudentNotifications()),
        ),
        GoRoute(
          path: '/student/live-classes',
          pageBuilder: (_, __) => const NoTransitionPage(child: StudentLiveClasses()),
          routes: [
            GoRoute(
              path: 'play/:id',
              pageBuilder: (context, state) {
                final classId = state.pathParameters['id']!;
                return NoTransitionPage(
                  child: StudentLiveClassPlayerScreen(classId: classId),
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: '/student/leaderboard',
          pageBuilder: (_, __) => const NoTransitionPage(child: StudentLeaderboard()),
        ),
        GoRoute(
          path: '/student/messaging',
          pageBuilder: (_, __) => const NoTransitionPage(child: StudentMessaging()),
        ),
        GoRoute(
          path: '/student/settings',
          pageBuilder: (_, __) => const NoTransitionPage(child: StudentSettings()),
        ),
        GoRoute(
          path: '/student/exams',
          pageBuilder: (_, __) => const NoTransitionPage(child: StudentExamsScreen()),
        ),
        GoRoute(
          path: '/student/online-exam',
          pageBuilder: (_, __) => const NoTransitionPage(child: OnlineExamScreen()),
        ),
        GoRoute(
          path: '/student/ai-chat',
          pageBuilder: (_, __) => const NoTransitionPage(child: AiChatScreen()),
        ),
      ],
    ),

    // ─────────────── TEACHER SHELL (persistent bottom nav) ───────────────
    // ─────────────── TEACHER SHELL (persistent bottom nav) ───────────────
    ShellRoute(
      navigatorKey: _teacherShellKey,
      builder: (context, state, child) => TeacherShellScaffold(
        location: state.uri.toString(),
        child: child,
      ),
      routes: [
        GoRoute(
          path: '/teacher/dashboard',
          pageBuilder: (_, __) => const NoTransitionPage(child: TeacherDashboardScreen()),
        ),
        GoRoute(
          path: '/teacher/timetable',
          pageBuilder: (_, __) => const NoTransitionPage(child: TeacherTimetable()),
        ),
        GoRoute(
          path: '/teacher/attendance',
          pageBuilder: (_, __) => const NoTransitionPage(child: TeacherAttendance()),
        ),
        GoRoute(
          path: '/teacher/homework',
          pageBuilder: (_, __) => const NoTransitionPage(child: TeacherHomework()),
        ),
        GoRoute(
          path: '/teacher/gradebook',
          pageBuilder: (_, __) => const NoTransitionPage(child: TeacherGradebook()),
        ),
        GoRoute(
          path: '/teacher/my-classes',
          pageBuilder: (_, __) => const NoTransitionPage(child: TeacherMyClasses()),
        ),
        GoRoute(
          path: '/teacher/class-detail',
          pageBuilder: (_, __) => const NoTransitionPage(child: TeacherMyClasses()),
        ),
        GoRoute(
          path: '/teacher/notices',
          pageBuilder: (_, __) => const NoTransitionPage(child: TeacherNotices()),
        ),
        GoRoute(
          path: '/teacher/profile',
          pageBuilder: (_, __) => const NoTransitionPage(child: TeacherProfileScreen()),
        ),
        GoRoute(
          path: '/teacher/grading',
          pageBuilder: (_, __) => const NoTransitionPage(child: TeacherGrading()),
        ),
        GoRoute(
          path: '/teacher/grading-config',
          pageBuilder: (_, __) => const NoTransitionPage(child: TeacherGrading()),
        ),
        GoRoute(
          path: '/teacher/exams',
          pageBuilder: (_, __) => const NoTransitionPage(child: TeacherExams()),
        ),
        GoRoute(
          path: '/teacher/paper-builder',
          pageBuilder: (_, __) => const NoTransitionPage(child: TeacherPaperBuilder()),
        ),
        GoRoute(
          path: '/teacher/leave',
          pageBuilder: (_, __) => const NoTransitionPage(child: TeacherLeaveScreen()),
        ),
        GoRoute(
          path: '/teacher/salary',
          pageBuilder: (_, __) => const NoTransitionPage(child: TeacherSalary()),
        ),
        GoRoute(
          path: '/teacher/submissions',
          pageBuilder: (_, __) => const NoTransitionPage(child: TeacherSubmissions()),
        ),
        GoRoute(
          path: '/teacher/review-submissions',
          pageBuilder: (_, __) => const NoTransitionPage(child: TeacherSubmissions()),
        ),
        GoRoute(
          path: '/teacher/notifications',
          pageBuilder: (_, __) => const NoTransitionPage(child: TeacherNotifications()),
        ),
        GoRoute(
          path: '/teacher/live-classes',
          pageBuilder: (_, __) => const NoTransitionPage(child: TeacherLiveClasses()),
        ),
        GoRoute(
          path: '/teacher/live-session',
          pageBuilder: (_, __) => const NoTransitionPage(child: TeacherLiveClasses()),
        ),
        GoRoute(
          path: '/teacher/materials',
          pageBuilder: (_, __) => const NoTransitionPage(child: TeacherMaterials()),
        ),
        GoRoute(
          path: '/teacher/student-directory',
          pageBuilder: (_, __) => const NoTransitionPage(child: TeacherStudentDirectory()),
        ),
        GoRoute(
          path: '/teacher/settings',
          pageBuilder: (_, __) => const NoTransitionPage(child: SettingsScreen()),
        ),
        GoRoute(
          path: '/teacher/ai-chat',
          pageBuilder: (_, __) => const NoTransitionPage(child: AiChatScreen()),
        ),
      ],
    ),
  ],
);
});
