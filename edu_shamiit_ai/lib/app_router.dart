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
import 'package:edu_shamiit_ai/features/shared/documents/screens/documents_screen.dart';
import 'package:edu_shamiit_ai/features/student/dashboard/screens/student_dashboard.dart';
import 'package:edu_shamiit_ai/features/student/timetable/screens/student_timetable.dart';
import 'package:edu_shamiit_ai/features/student/results/screens/student_results.dart';
import 'package:edu_shamiit_ai/features/student/homework/screens/student_homework.dart';
import 'package:edu_shamiit_ai/features/student/attendance/screens/student_attendance.dart';
import 'package:edu_shamiit_ai/features/student/fees/screens/student_fees.dart';
import 'package:edu_shamiit_ai/features/shared/leave/screens/leave_screen.dart';
import 'package:edu_shamiit_ai/features/student/profile/screens/student_profile.dart';
import 'package:edu_shamiit_ai/features/student/library/screens/student_library.dart';
import 'package:edu_shamiit_ai/features/student/courses/screens/student_courses.dart';
import 'package:edu_shamiit_ai/features/student/courses/screens/student_course_details.dart';
import 'package:edu_shamiit_ai/features/teacher/my_classes/screens/teacher_class_subjects.dart';
import 'package:edu_shamiit_ai/features/teacher/courses/screens/teacher_course_details.dart';
import 'package:edu_shamiit_ai/features/student/notifications/screens/student_notifications.dart';
import 'package:edu_shamiit_ai/features/student/notices/screens/student_notices_screen.dart';
import 'package:edu_shamiit_ai/features/student/transport/screens/student_transport_screen.dart';

import 'package:edu_shamiit_ai/features/student/achievements/screens/student_achievements_screen.dart';
import 'package:edu_shamiit_ai/features/student/live_classes/screens/student_live_classes.dart';
import 'package:edu_shamiit_ai/features/student/leaderboard/screens/student_leaderboard.dart';
import 'package:edu_shamiit_ai/features/student/messaging/screens/student_messaging.dart';
import 'package:edu_shamiit_ai/features/teacher/messaging/screens/teacher_messaging.dart';
import 'package:edu_shamiit_ai/features/student/settings/screens/student_settings.dart';
import 'package:edu_shamiit_ai/features/student/exams/screens/student_exams.dart';
import 'package:edu_shamiit_ai/features/student/exams/screens/online_exam_screen.dart';
import 'package:edu_shamiit_ai/features/student/exams/screens/exam_details_screen.dart';
import 'package:edu_shamiit_ai/features/student/exams/screens/identity_verification_screen.dart';
import 'package:edu_shamiit_ai/features/student/exams/screens/exam_instructions_screen.dart';
import 'package:edu_shamiit_ai/features/student/exams/screens/live_exam_taking_screen.dart';
import 'package:edu_shamiit_ai/features/student/exams/screens/exam_submission_screen.dart';
import 'package:edu_shamiit_ai/features/student/exams/screens/exam_result_screen.dart';
import 'package:edu_shamiit_ai/features/student/exams/screens/exam_review_screen.dart';

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
import 'package:edu_shamiit_ai/features/teacher/exams/screens/create_exam_screen.dart';
import 'package:edu_shamiit_ai/features/teacher/exams/screens/question_bank_screen.dart';
import 'package:edu_shamiit_ai/features/teacher/exams/screens/exam_paper_builder_screen.dart';
import 'package:edu_shamiit_ai/features/teacher/exams/screens/assign_exam_screen.dart';
import 'package:edu_shamiit_ai/features/teacher/exams/screens/live_monitoring_screen.dart';
import 'package:edu_shamiit_ai/features/teacher/exams/screens/manual_evaluation_screen.dart';
import 'package:edu_shamiit_ai/features/teacher/exams/screens/publish_result_screen.dart';
import 'package:edu_shamiit_ai/features/teacher/exams/screens/teacher_exam_analytics.dart';
// teacher_leave.dart replaced by shared leave_screen.dart
import 'package:edu_shamiit_ai/features/teacher/salary/screens/teacher_salary.dart';
import 'package:edu_shamiit_ai/features/teacher/submissions/screens/teacher_submissions.dart';
import 'package:edu_shamiit_ai/features/teacher/notifications/screens/teacher_notifications.dart';
import 'package:edu_shamiit_ai/features/teacher/live_classes/screens/teacher_live_classes.dart';

import 'package:edu_shamiit_ai/features/teacher/student_directory/screens/teacher_student_directory.dart';
import 'package:edu_shamiit_ai/shared/widgets/student_shell_scaffold.dart';
import 'package:edu_shamiit_ai/shared/widgets/teacher_shell_scaffold.dart';

import 'package:edu_shamiit_ai/shared/screens/in_app_live_room_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final studentShellKey = GlobalKey<NavigatorState>(debugLabel: 'studentShell');
final teacherShellKey = GlobalKey<NavigatorState>(debugLabel: 'teacherShell');

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
    navigatorKey: rootNavigatorKey,
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
    GoRoute(
      path: '/live-room',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return InAppLiveRoomScreen(
          liveClassId: extra['liveClassId'] as String,
          currentUserId: extra['currentUserId'] as String,
          currentUserName: extra['currentUserName'] as String,
          currentUserRole: extra['currentUserRole'] as String,
          title: extra['title'] as String,
        );
      },
    ),

    // ─────────────── STUDENT SHELL (persistent bottom nav) ───────────────
    ShellRoute(
      navigatorKey: studentShellKey,
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
          pageBuilder: (_, __) => const NoTransitionPage(child: LeaveScreen()),
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
          path: '/student/courses/:courseId/details',
          pageBuilder: (context, state) {
            final courseId = state.pathParameters['courseId']!;
            return NoTransitionPage(child: StudentCourseDetailsScreen(courseId: courseId));
          },
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
          pageBuilder: (context, state) {
            final chatId = state.uri.queryParameters['chat_id'];
            return NoTransitionPage(child: StudentMessaging(initialChatId: chatId));
          },
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
          path: '/student/exams/details/:id',
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            return NoTransitionPage(child: ExamDetailsScreen(examId: id));
          },
        ),
        GoRoute(
          path: '/student/exams/verify/:id',
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            final passcode = state.uri.queryParameters['passcode'];
            return NoTransitionPage(child: IdentityVerificationScreen(examId: id, passcode: passcode));
          },
        ),
        GoRoute(
          path: '/student/exams/instructions/:id',
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            final passcode = state.uri.queryParameters['passcode'];
            return NoTransitionPage(child: ExamInstructionsScreen(examId: id, passcode: passcode));
          },
        ),
        GoRoute(
          path: '/student/exams/live/:id',
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            final passcode = state.uri.queryParameters['passcode'];
            return NoTransitionPage(child: LiveExamTakingScreen(examId: id, passcode: passcode));
          },
        ),
        GoRoute(
          path: '/student/exams/submit/:id',
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            final autoStr = state.uri.queryParameters['auto'];
            final autoSubmitted = autoStr == 'true';
            return NoTransitionPage(
              child: ExamSubmissionScreen(examId: id, autoSubmitted: autoSubmitted),
            );
          },
        ),
        GoRoute(
          path: '/student/exams/result/:id',
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            return NoTransitionPage(child: ExamResultScreen(examId: id));
          },
        ),
        GoRoute(
          path: '/student/exams/review/:id',
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            return NoTransitionPage(child: ExamReviewScreen(examId: id));
          },
        ),
        GoRoute(
          path: '/student/online-exam',
          pageBuilder: (_, __) => const NoTransitionPage(child: OnlineExamScreen()),
        ),
        GoRoute(
          path: '/student/ai-chat',
          pageBuilder: (context, state) {
            final from = state.uri.queryParameters['from'];
            return NoTransitionPage(child: AiChatScreen(launchedFrom: from));
          },
        ),
        GoRoute(
          path: '/student/documents',
          pageBuilder: (_, __) => const NoTransitionPage(child: DocumentsScreen()),
        ),
      ],
    ),

    // ─────────────── TEACHER SHELL (persistent bottom nav) ───────────────
    // ─────────────── TEACHER SHELL (persistent bottom nav) ───────────────
    ShellRoute(
      navigatorKey: teacherShellKey,
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
          path: '/teacher/my-classes/:classId/subjects',
          pageBuilder: (context, state) {
            final classId = state.pathParameters['classId']!;
            return NoTransitionPage(child: TeacherClassSubjectsScreen(classId: classId));
          },
        ),
        GoRoute(
          path: '/teacher/courses/:courseId/details',
          pageBuilder: (context, state) {
            final courseId = state.pathParameters['courseId']!;
            return NoTransitionPage(child: TeacherCourseDetailsScreen(courseId: courseId));
          },
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
          path: '/teacher/exams/create',
          pageBuilder: (_, __) => const NoTransitionPage(child: CreateExamScreen()),
        ),
        GoRoute(
          path: '/teacher/exams/edit/:id',
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            return NoTransitionPage(child: CreateExamScreen(examId: id));
          },
        ),
        GoRoute(
          path: '/teacher/exams/question-bank',
          pageBuilder: (_, __) => const NoTransitionPage(child: QuestionBankScreen()),
        ),
        GoRoute(
          path: '/teacher/exams/paper-builder',
          pageBuilder: (context, state) {
            final examId = state.uri.queryParameters['examId'] ?? state.uri.queryParameters['exam_id'];
            return NoTransitionPage(child: ExamPaperBuilderScreen(examId: examId));
          },
        ),
        GoRoute(
          path: '/teacher/exams/assign/:id',
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            return NoTransitionPage(child: AssignExamScreen(examId: id));
          },
        ),
        GoRoute(
          path: '/teacher/exams/monitor/:id',
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            return NoTransitionPage(child: LiveMonitoringScreen(examId: id));
          },
        ),
        GoRoute(
          path: '/teacher/exams/evaluate/:id',
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            return NoTransitionPage(child: ManualEvaluationScreen(examId: id));
          },
        ),
        GoRoute(
          path: '/teacher/exams/publish/:id',
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            return NoTransitionPage(child: PublishResultScreen(examId: id));
          },
        ),
        GoRoute(
          path: '/teacher/exams/analytics/:id',
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            return NoTransitionPage(child: TeacherExamAnalyticsScreen(examId: id));
          },
        ),
        GoRoute(
          path: '/teacher/leave',
          pageBuilder: (_, __) => const NoTransitionPage(child: LeaveScreen()),
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
          path: '/teacher/live-session',
          pageBuilder: (_, __) => const NoTransitionPage(child: TeacherLiveClasses()),
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
          pageBuilder: (context, state) {
            final from = state.uri.queryParameters['from'];
            return NoTransitionPage(child: AiChatScreen(launchedFrom: from));
          },
        ),
        GoRoute(
          path: '/teacher/documents',
          pageBuilder: (_, __) => const NoTransitionPage(child: DocumentsScreen()),
        ),
        GoRoute(
          path: '/teacher/messaging',
          pageBuilder: (context, state) {
            final chatId = state.uri.queryParameters['chat_id'];
            return NoTransitionPage(child: TeacherMessaging(initialChatId: chatId));
          },
        ),
      ],
    ),
  ],
);
});
