import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_admin/screens/login_screen.dart';
import 'package:edu_shamiit_admin/screens/dashboard_screen.dart';
import 'package:edu_shamiit_admin/screens/role_dashboards/super_admin_dashboard_screen.dart';
import 'package:edu_shamiit_admin/screens/role_dashboards/driver_dashboard_screen.dart';
// MyProfileScreen is now universally imported from edu_shamiit_core
import 'package:edu_shamiit_admin/screens/modules/schools/schools_screen.dart';
import 'package:edu_shamiit_admin/screens/modules/users/users_screen.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';
import 'package:edu_shamiit_admin/screens/modules/infra/infra_monitor_screen.dart';
import 'package:edu_shamiit_admin/screens/modules/config/system_config_screen.dart';
import 'package:edu_shamiit_admin/screens/modules/roles/admin_roles_screen.dart';
import 'package:edu_shamiit_admin/screens/tabs/finance_tab.dart';
import 'package:edu_shamiit_admin/screens/tabs/defaulters_tab.dart';
import 'package:edu_shamiit_admin/screens/tabs/staff_tab.dart';
import 'package:edu_shamiit_admin/screens/tabs/admissions_tab.dart';
import 'package:edu_shamiit_admin/screens/tabs/gate_scanner_tab.dart';
import 'package:edu_shamiit_admin/screens/tabs/support_tab.dart';
import 'package:edu_shamiit_admin/screens/modules/tickets/contact_queries_screen.dart';
import 'package:edu_shamiit_admin/screens/tabs/system_control_tab.dart';
import 'package:edu_shamiit_admin/screens/modules/quick_access/quick_access_screens.dart';
import 'package:edu_shamiit_admin/screens/modules/quick_access/emergency_screen.dart';
import 'package:edu_shamiit_admin/screens/modules/fleet/driver_management_screen.dart';
import 'package:edu_shamiit_admin/screens/modules/fleet/route_management_screen.dart';
import 'package:edu_shamiit_admin/providers/system_config_provider.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/recruitment_screen.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/hr_overview_screen.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/hr_onboarding_screen.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/hr_training_screen.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/hr_policies_screen.dart';

final adminShellKey = GlobalKey<NavigatorState>(debugLabel: 'adminShell');
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'adminRoot');

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(
      authProvider,
      (previous, next) {
        if (previous?.isAuthenticated != next.isAuthenticated) {
          notifyListeners();
        }
      },
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      if (state.uri.path == '/' && Uri.base.hasFragment && Uri.base.fragment.startsWith('/careers')) {
        return Uri.base.fragment;
      }
      final authState = ref.read(authProvider);
      final loggedIn = authState.isAuthenticated;
      final path = state.uri.path;
      final isPublic = path == '/' ||
          path == '/login' ||
          path == '/forgot-password' ||
          path == '/otp-verification' ||
          path == '/reset-password' ||
          path == '/password-reset-success' ||
          path == '/contact' ||
          path == '/privacy-policy' ||
          path == '/terms-conditions' ||
          path == '/get-started' ||
          path == '/faq' ||
          path == '/user-guides' ||
          path == '/help-center' ||
          path.startsWith('/careers');

      if (!loggedIn && !isPublic) {
        return '/login';
      }
      if (loggedIn && isPublic) {
        if (path.startsWith('/careers')) {
          return null; // Allow authenticated users to preview / view careers portal
        }
        final role = authState.userData?['role']?.toString().toLowerCase();
        if (role == 'driver') {
          return '/driver/dashboard';
        }
        return '/admin/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Consumer(
          builder: (context, ref, _) {
            final config = ref.watch(systemConfigProvider);
            return SharedHomeScreen(
              systemName: config?.systemName,
              systemLogo: config?.systemLogo,
            );
          },
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const AdminLoginScreen(),
      ),
      GoRoute(
        path: '/contact',
        builder: (context, state) => Consumer(
          builder: (context, ref, _) {
            final config = ref.watch(systemConfigProvider);
            return SharedContactUsScreen(
              systemName: config?.systemName,
              systemLogo: config?.systemLogo,
              illustrationUrl: 'assets/images/contact_illustration.png',
            );
          },
        ),
      ),
      GoRoute(
        path: '/privacy-policy',
        builder: (context, state) => Consumer(
          builder: (context, ref, _) {
            final config = ref.watch(systemConfigProvider);
            return SharedPrivacyPolicyScreen(
              systemName: config?.systemName,
              systemLogo: config?.systemLogo,
              illustrationUrl: 'assets/images/privacy_illustration.png',
            );
          },
        ),
      ),
      GoRoute(
        path: '/terms-conditions',
        builder: (context, state) => Consumer(
          builder: (context, ref, _) {
            final config = ref.watch(systemConfigProvider);
            return SharedTermsConditionsScreen(
              systemName: config?.systemName,
              systemLogo: config?.systemLogo,
              illustrationUrl: 'assets/images/terms_illustration.png',
            );
          },
        ),
      ),
      GoRoute(
        path: '/get-started',
        builder: (context, state) => Consumer(
          builder: (context, ref, _) {
            final config = ref.watch(systemConfigProvider);
            return SharedGetStartedScreen(
              systemName: config?.systemName,
              systemLogo: config?.systemLogo,
            );
          },
        ),
      ),
      GoRoute(
        path: '/faq',
        builder: (context, state) => Consumer(
          builder: (context, ref, _) {
            final config = ref.watch(systemConfigProvider);
            return SharedFaqScreen(
              systemName: config?.systemName,
              systemLogo: config?.systemLogo,
              illustrationUrl: 'assets/images/faq_illustration.png',
            );
          },
        ),
      ),
      GoRoute(
        path: '/user-guides',
        builder: (context, state) {
          final category = state.uri.queryParameters['category'];
          final article = state.uri.queryParameters['article'];
          return Consumer(
            builder: (context, ref, _) {
              final config = ref.watch(systemConfigProvider);
              return SharedUserGuidesScreen(
                systemName: config?.systemName,
                systemLogo: config?.systemLogo,
                illustrationUrl: 'assets/images/user_guide_illustration.png',
                videoIllustrationUrl: 'assets/images/video_tutorials_illustration.png',
                initialCategory: category,
                initialArticleId: article,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/help-center',
        builder: (context, state) => Consumer(
          builder: (context, ref, _) {
            final config = ref.watch(systemConfigProvider);
            return SharedHelpCenterScreen(
              systemName: config?.systemName,
              systemLogo: config?.systemLogo,
              illustrationUrl: 'assets/images/help_center_illustration.png',
            );
          },
        ),
      ),
      GoRoute(
        path: '/careers',
        builder: (context, state) => Consumer(
          builder: (context, ref, _) {
            final config = ref.watch(systemConfigProvider);
            return SharedCareersScreen(
              systemName: config?.systemName,
              systemLogo: config?.systemLogo,
            );
          },
        ),
      ),
      GoRoute(
        path: '/careers/jobs/:slug',
        builder: (context, state) {
          final slug = state.pathParameters['slug'] ?? '';
          return Consumer(
            builder: (context, ref, _) {
              final config = ref.watch(systemConfigProvider);
              return SharedJobDetailsScreen(
                slug: slug,
                systemName: config?.systemName,
                systemLogo: config?.systemLogo,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => Consumer(
          builder: (context, ref, _) {
            final config = ref.watch(systemConfigProvider);
            return SharedForgotPasswordScreen(
              isAdmin: true,
              systemName: config?.systemName,
              systemLogo: config?.systemLogo,
              illustrationUrl: config?.forgotPasswordIllustration,
            );
          },
        ),
      ),
      GoRoute(
        path: '/otp-verification',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          final email = args?['email'] as String? ?? '';
          final isLogin = args?['isLogin'] as bool? ?? false;
          final role = args?['role'] as UserRole?;
          return Consumer(
            builder: (context, ref, _) {
              final config = ref.watch(systemConfigProvider);
              return SharedOtpVerificationScreen(
                email: email,
                isLogin: isLogin,
                role: role,
                isAdmin: true,
                systemName: config?.systemName,
                systemLogo: config?.systemLogo,
                illustrationUrl: config?.otpVerificationIllustration,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => Consumer(
          builder: (context, ref, _) {
            final config = ref.watch(systemConfigProvider);
            final args = state.extra as Map<String, dynamic>?;
            final email = args?['email'] as String? ?? '';
            final otp = args?['otp'] as String? ?? '';
            return SharedResetPasswordScreen(
              email: email,
              otp: otp,
              isAdmin: true,
              systemName: config?.systemName,
              systemLogo: config?.systemLogo,
              illustrationUrl: config?.resetPasswordIllustration,
            );
          },
        ),
      ),
      GoRoute(
        path: '/password-reset-success',
        builder: (context, state) => const SharedPasswordResetSuccessScreen(isAdmin: true),
      ),
      GoRoute(
        path: '/dashboard',
        redirect: (context, state) {
          final authState = ref.read(authProvider);
          final role = authState.userData?['role']?.toString().toLowerCase();
          if (role == 'driver') {
            return '/driver/dashboard';
          }
          return '/admin/dashboard';
        },
      ),
      ShellRoute(
        navigatorKey: adminShellKey,
        builder: (context, state, child) => AdminDashboardScreen(child: child),
        routes: [
          GoRoute(
            path: '/driver/dashboard',
            pageBuilder: (_, __) => const NoTransitionPage(child: DriverDashboardScreen()),
          ),
          GoRoute(
            path: '/driver/timetable',
            redirect: (_, __) => '/admin/calendar',
          ),
          GoRoute(
            path: '/admin/calendar',
            pageBuilder: (_, __) => const NoTransitionPage(child: UniversalCalendarScreen()),
          ),
          GoRoute(
            path: '/calendar',
            pageBuilder: (_, __) => const NoTransitionPage(child: UniversalCalendarScreen()),
          ),
          GoRoute(
            path: '/admin/messaging',
            pageBuilder: (context, state) {
              final chatId = state.uri.queryParameters['chat_id'];
              return NoTransitionPage(
                child: MessagingScreen(
                  initialChatId: chatId,
                  role: 'admin',
                  primaryColor: const Color(0xFF4F46E5),
                ),
              );
            },
          ),
          GoRoute(
            path: '/admin/messages',
            redirect: (_, state) {
              final chatId = state.uri.queryParameters['chat_id'];
              return chatId != null ? '/admin/messaging?chat_id=$chatId' : '/admin/messaging';
            },
          ),
          GoRoute(
            path: '/admin/ai-chat',
            pageBuilder: (context, state) {
              final from = state.uri.queryParameters['from'];
              return NoTransitionPage(child: AiChatScreen(launchedFrom: from));
            },
          ),
          GoRoute(
            path: '/admin/documents',
            pageBuilder: (_, __) => const NoTransitionPage(child: DocumentsScreen()),
          ),
          GoRoute(
            path: '/admin/dashboard',
            pageBuilder: (context, state) {
              final authState = ref.read(authProvider);
              final role = authState.userData?['role']?.toString().toLowerCase();
              if (role == 'driver') {
                return const NoTransitionPage(child: DriverDashboardScreen());
              }
              return const NoTransitionPage(child: SuperAdminDashboardScreen());
            },
          ),
          GoRoute(
            path: '/admin/schools',
            pageBuilder: (_, __) => const NoTransitionPage(child: AdminSchoolsScreen()),
          ),
          GoRoute(
            path: '/admin/users',
            pageBuilder: (_, state) {
              final role = state.uri.queryParameters['role'];
              return NoTransitionPage(child: AdminUsersScreen(initialRole: role));
            },
          ),
          GoRoute(
            path: '/admin/infra',
            pageBuilder: (_, __) => const NoTransitionPage(child: AdminInfraMonitorScreen()),
          ),
          GoRoute(
            path: '/admin/config',
            pageBuilder: (_, state) {
              final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
              return NoTransitionPage(child: AdminSystemConfigScreen(initialTab: tab));
            },
          ),
          GoRoute(
            path: '/admin/roles',
            pageBuilder: (_, state) {
              final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
              return NoTransitionPage(child: AdminRolesScreen(initialTab: tab));
            },
          ),
          GoRoute(
            path: '/admin/lookups',
            pageBuilder: (_, __) => const NoTransitionPage(child: LookupManagementScreen()),
          ),
          GoRoute(
            path: '/lookups',
            pageBuilder: (_, __) => const NoTransitionPage(child: LookupManagementScreen()),
          ),
          GoRoute(
            path: '/admin/classes',
            pageBuilder: (_, state) {
              final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
              return NoTransitionPage(child: ClassManagementScreen(initialTab: tab));
            },
          ),
          GoRoute(
            path: '/classes',
            pageBuilder: (_, state) {
              final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
              return NoTransitionPage(child: ClassManagementScreen(initialTab: tab));
            },
          ),
          GoRoute(
            path: '/admin/timetable',
            pageBuilder: (_, state) => const NoTransitionPage(child: ClassManagementScreen(initialTab: 1)),
          ),
          GoRoute(
            path: '/admin/timetables',
            pageBuilder: (_, state) => const NoTransitionPage(child: ClassManagementScreen(initialTab: 1)),
          ),
          GoRoute(
            path: '/timetable',
            pageBuilder: (_, state) => const NoTransitionPage(child: ClassManagementScreen(initialTab: 1)),
          ),
          GoRoute(
            path: '/timetables',
            pageBuilder: (_, state) => const NoTransitionPage(child: ClassManagementScreen(initialTab: 1)),
          ),
          GoRoute(
            path: '/admin/library',
            pageBuilder: (_, state) {
              final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
              return NoTransitionPage(child: LibraryManagementScreen(initialTab: tab));
            },
          ),
          GoRoute(
            path: '/library',
            pageBuilder: (_, state) {
              final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
              return NoTransitionPage(child: LibraryManagementScreen(initialTab: tab));
            },
          ),
          // Exams & Question Bank
          GoRoute(
            path: '/admin/exams',
            pageBuilder: (_, __) => const NoTransitionPage(child: ExamsManagementScreen()),
          ),
          GoRoute(
            path: '/exams',
            pageBuilder: (_, __) => const NoTransitionPage(child: ExamsManagementScreen()),
          ),
          GoRoute(
            path: '/admin/exams/create',
            redirect: (_, __) => '/admin/exams',
          ),
          GoRoute(
            path: '/exams/create',
            redirect: (_, __) => '/admin/exams',
          ),
          GoRoute(
            path: '/admin/exams/edit/:id',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id']!;
              return NoTransitionPage(child: CreateExamScreen(examId: id));
            },
          ),
          GoRoute(
            path: '/exams/edit/:id',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id']!;
              return NoTransitionPage(child: CreateExamScreen(examId: id));
            },
          ),
          GoRoute(
            path: '/admin/exams/question-bank',
            pageBuilder: (_, __) => const NoTransitionPage(child: QuestionBankScreen()),
          ),
          GoRoute(
            path: '/exams/question-bank',
            pageBuilder: (_, __) => const NoTransitionPage(child: QuestionBankScreen()),
          ),
          GoRoute(
            path: '/admin/exams/paper-builder',
            pageBuilder: (context, state) {
              final examId = state.uri.queryParameters['examId'] ?? state.uri.queryParameters['exam_id'];
              return NoTransitionPage(child: ExamPaperBuilderScreen(examId: examId));
            },
          ),
          GoRoute(
            path: '/exams/paper-builder',
            pageBuilder: (context, state) {
              final examId = state.uri.queryParameters['examId'] ?? state.uri.queryParameters['exam_id'];
              return NoTransitionPage(child: ExamPaperBuilderScreen(examId: examId));
            },
          ),
          GoRoute(
            path: '/admin/exams/instructions',
            pageBuilder: (context, state) {
              final examId = state.uri.queryParameters['examId'] ?? state.uri.queryParameters['exam_id'];
              return NoTransitionPage(child: ExamPrestartScreen(examId: examId));
            },
          ),
          GoRoute(
            path: '/exams/instructions',
            pageBuilder: (context, state) {
              final examId = state.uri.queryParameters['examId'] ?? state.uri.queryParameters['exam_id'];
              return NoTransitionPage(child: ExamPrestartScreen(examId: examId));
            },
          ),
          GoRoute(
            path: '/admin/exams/take',
            pageBuilder: (context, state) {
              final examId = state.uri.queryParameters['examId'] ?? state.uri.queryParameters['exam_id'];
              return NoTransitionPage(child: TakeExamScreen(examId: examId));
            },
          ),
          GoRoute(
            path: '/exams/take',
            pageBuilder: (context, state) {
              final examId = state.uri.queryParameters['examId'] ?? state.uri.queryParameters['exam_id'];
              return NoTransitionPage(child: TakeExamScreen(examId: examId));
            },
          ),
          GoRoute(
            path: '/admin/exams/assign/:id',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id']!;
              return NoTransitionPage(child: AssignExamScreen(examId: id));
            },
          ),
          GoRoute(
            path: '/exams/assign/:id',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id']!;
              return NoTransitionPage(child: AssignExamScreen(examId: id));
            },
          ),
          GoRoute(
            path: '/admin/exams/monitor/:id',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id']!;
              return NoTransitionPage(child: LiveMonitoringScreen(examId: id));
            },
          ),
          GoRoute(
            path: '/exams/monitor/:id',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id']!;
              return NoTransitionPage(child: LiveMonitoringScreen(examId: id));
            },
          ),
          GoRoute(
            path: '/admin/exams/evaluate/:id',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id']!;
              return NoTransitionPage(child: ManualEvaluationScreen(examId: id));
            },
          ),
          GoRoute(
            path: '/exams/evaluate/:id',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id']!;
              return NoTransitionPage(child: ManualEvaluationScreen(examId: id));
            },
          ),
          GoRoute(
            path: '/admin/exams/publish/:id',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id']!;
              return NoTransitionPage(child: PublishResultScreen(examId: id));
            },
          ),
          GoRoute(
            path: '/exams/publish/:id',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id']!;
              return NoTransitionPage(child: PublishResultScreen(examId: id));
            },
          ),
          GoRoute(
            path: '/admin/exams/analytics/:id',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id']!;
              return NoTransitionPage(child: ExamAnalyticsScreen(examId: id));
            },
          ),
          GoRoute(
            path: '/exams/analytics/:id',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id']!;
              return NoTransitionPage(child: ExamAnalyticsScreen(examId: id));
            },
          ),
          GoRoute(
            path: '/admin/hostel',
            pageBuilder: (_, state) {
              final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
              return NoTransitionPage(child: HostelManagementScreen(initialTab: tab));
            },
          ),
          GoRoute(
            path: '/hostel',
            pageBuilder: (_, state) {
              final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
              return NoTransitionPage(child: HostelManagementScreen(initialTab: tab));
            },
          ),
          GoRoute(
            path: '/admin/hostel/rooms',
            pageBuilder: (_, __) => const NoTransitionPage(child: HostelManagementScreen(initialTab: 1)),
          ),
          GoRoute(
            path: '/hostel/rooms',
            pageBuilder: (_, __) => const NoTransitionPage(child: HostelManagementScreen(initialTab: 1)),
          ),
          GoRoute(
            path: '/admin/visitors',
            pageBuilder: (_, state) {
              final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
              return NoTransitionPage(child: VisitorsManagementScreen(initialTab: tab));
            },
          ),
          GoRoute(
            path: '/visitors',
            pageBuilder: (_, state) {
              final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
              return NoTransitionPage(child: VisitorsManagementScreen(initialTab: tab));
            },
          ),
          GoRoute(
            path: '/admin/inventory',
            pageBuilder: (_, state) {
              final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
              return NoTransitionPage(child: InventoryManagementScreen(initialTab: tab));
            },
          ),
          GoRoute(
            path: '/inventory',
            pageBuilder: (_, state) {
              final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
              return NoTransitionPage(child: InventoryManagementScreen(initialTab: tab));
            },
          ),
          GoRoute(
            path: '/admin/campus',
            pageBuilder: (_, state) {
              final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
              return NoTransitionPage(child: CampusManagementScreen(initialTab: tab));
            },
          ),
          GoRoute(
            path: '/admin/work',
            pageBuilder: (_, state) {
              final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
              return NoTransitionPage(child: WorkManagementScreen(initialTabIndex: tab));
            },
          ),
          GoRoute(
            path: '/work',
            pageBuilder: (_, state) {
              final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
              return NoTransitionPage(child: WorkManagementScreen(initialTabIndex: tab));
            },
          ),
          GoRoute(
            path: '/admin/work/board',
            pageBuilder: (_, __) => const NoTransitionPage(child: WorkManagementScreen(initialTabIndex: 0)),
          ),
          GoRoute(
            path: '/admin/work/list',
            pageBuilder: (_, __) => const NoTransitionPage(child: WorkManagementScreen(initialTabIndex: 1)),
          ),
          GoRoute(
            path: '/admin/work/backlog',
            pageBuilder: (_, __) => const NoTransitionPage(child: WorkManagementScreen(initialTabIndex: 2)),
          ),
          GoRoute(
            path: '/admin/work/sprints',
            pageBuilder: (_, __) => const NoTransitionPage(child: WorkManagementScreen(initialTabIndex: 3)),
          ),
          GoRoute(
            path: '/campus',
            pageBuilder: (_, state) {
              final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
              return NoTransitionPage(child: CampusManagementScreen(initialTab: tab));
            },
          ),
          GoRoute(
            path: '/admin/campus/buildings-rooms',
            pageBuilder: (_, __) => const NoTransitionPage(child: CampusManagementScreen(initialTab: 0)),
          ),
          GoRoute(
            path: '/admin/student-fees',
            pageBuilder: (_, __) => const NoTransitionPage(child: StudentFeeManagementScreen()),
          ),
          GoRoute(
            path: '/student-fees',
            pageBuilder: (_, __) => const NoTransitionPage(child: StudentFeeManagementScreen()),
          ),
          GoRoute(
            path: '/admin/fee-management',
            pageBuilder: (_, __) => const NoTransitionPage(child: StudentFeeManagementScreen()),
          ),
          GoRoute(
            path: '/admin/fees',
            pageBuilder: (_, __) => const NoTransitionPage(child: StudentFeeManagementScreen()),
          ),
          GoRoute(
            path: '/admin/fee',
            pageBuilder: (_, __) => const NoTransitionPage(child: StudentFeeManagementScreen()),
          ),
          GoRoute(
            path: '/fee-management',
            pageBuilder: (_, __) => const NoTransitionPage(child: StudentFeeManagementScreen()),
          ),
          GoRoute(
            path: '/fees',
            pageBuilder: (_, __) => const NoTransitionPage(child: StudentFeeManagementScreen()),
          ),
          GoRoute(
            path: '/admin/staff-salary',
            pageBuilder: (_, __) => const NoTransitionPage(child: StaffSalaryManagementScreen()),
          ),
          GoRoute(
            path: '/staff-salary',
            pageBuilder: (_, __) => const NoTransitionPage(child: StaffSalaryManagementScreen()),
          ),
          // Sub-routes for the operational tabs
          GoRoute(
            path: '/admin/finance',
            pageBuilder: (_, __) => const NoTransitionPage(child: FinanceTab()),
          ),
          GoRoute(
            path: '/admin/defaulters',
            pageBuilder: (_, __) => const NoTransitionPage(child: DefaultersTab()),
          ),
          GoRoute(
            path: '/admin/staff',
            pageBuilder: (_, __) => const NoTransitionPage(child: StaffTab()),
          ),
          GoRoute(
            path: '/admin/admissions',
            pageBuilder: (_, __) => const NoTransitionPage(child: AdmissionsTab()),
          ),
          GoRoute(
            path: '/admin/gate-scanner',
            pageBuilder: (_, __) => const NoTransitionPage(child: GateScannerTab()),
          ),
          GoRoute(
            path: '/admin/support',
            pageBuilder: (_, __) => const NoTransitionPage(child: SupportTab()),
          ),
          GoRoute(
            path: '/admin/contact-queries',
            pageBuilder: (_, __) => const NoTransitionPage(child: ContactQueriesScreen()),
          ),
          GoRoute(
            path: '/admin/system-control',
            pageBuilder: (_, __) => const NoTransitionPage(child: SystemControlTab()),
          ),

          // HR Management Suite
          GoRoute(
            path: '/admin/hr',
            redirect: (_, __) => '/admin/hr/overview',
          ),
          GoRoute(
            path: '/hr',
            redirect: (_, __) => '/admin/hr/overview',
          ),
          GoRoute(
            path: '/admin/hr/overview',
            pageBuilder: (_, __) => const NoTransitionPage(child: HROverviewScreen()),
          ),
          GoRoute(
            path: '/hr/overview',
            pageBuilder: (_, __) => const NoTransitionPage(child: HROverviewScreen()),
          ),
          GoRoute(
            path: '/admin/hr/recruitment',
            pageBuilder: (_, __) => const NoTransitionPage(child: RecruitmentScreen()),
          ),
          GoRoute(
            path: '/hr/recruitment',
            pageBuilder: (_, __) => const NoTransitionPage(child: RecruitmentScreen()),
          ),
          GoRoute(
            path: '/admin/hr/onboarding',
            pageBuilder: (_, __) => const NoTransitionPage(child: HROnboardingScreen()),
          ),
          GoRoute(
            path: '/hr/onboarding',
            pageBuilder: (_, __) => const NoTransitionPage(child: HROnboardingScreen()),
          ),
          GoRoute(
            path: '/admin/hr/training',
            pageBuilder: (_, __) => const NoTransitionPage(child: HRTrainingScreen()),
          ),
          GoRoute(
            path: '/hr/training',
            pageBuilder: (_, __) => const NoTransitionPage(child: HRTrainingScreen()),
          ),
          GoRoute(
            path: '/admin/hr/policies',
            pageBuilder: (_, __) => const NoTransitionPage(child: HRPoliciesScreen()),
          ),
          GoRoute(
            path: '/hr/policies',
            pageBuilder: (_, __) => const NoTransitionPage(child: HRPoliciesScreen()),
          ),

          GoRoute(
            path: '/admin/modules',
            pageBuilder: (_, state) {
              final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
              return NoTransitionPage(child: ModuleToggleScreen(initialTab: tab));
            },
          ),

          GoRoute(
            path: '/admin/automations',
            pageBuilder: (_, __) => const NoTransitionPage(child: AutomationsScreen()),
          ),


          GoRoute(
            path: '/admin/insights',
            pageBuilder: (_, __) => const NoTransitionPage(child: SmartInsightsScreen()),
          ),

          GoRoute(
            path: '/admin/apis',
            pageBuilder: (_, __) => const NoTransitionPage(child: ApisScreen()),
          ),
          GoRoute(
            path: '/admin/vault',
            pageBuilder: (_, __) => const NoTransitionPage(child: VaultSecretsScreen()),
          ),
          GoRoute(
            path: '/admin/audit-log',
            pageBuilder: (context, state) {
              final search = state.uri.queryParameters['search'];
              return NoTransitionPage(child: AuditLogScreen(initialSearch: search));
            },
          ),
          GoRoute(
            path: '/admin/my-profile',
            pageBuilder: (_, __) => const NoTransitionPage(child: MyProfileScreen()),
          ),
          GoRoute(
            path: '/admin/alerts-notifications',
            pageBuilder: (_, __) => const NoTransitionPage(child: AlertsNotificationsScreen()),
          ),
          GoRoute(
            path: '/admin/emergency',
            pageBuilder: (_, __) => const NoTransitionPage(child: EmergencyScreen()),
          ),


          GoRoute(
            path: '/admin/announcements',
            pageBuilder: (_, state) {
              final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
              return NoTransitionPage(child: UniversalNoticesScreen(initialTab: tab));
            },
          ),
          GoRoute(
            path: '/admin/notices',
            pageBuilder: (_, state) {
              final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
              return NoTransitionPage(child: UniversalNoticesScreen(initialTab: tab));
            },
          ),
          GoRoute(
            path: '/notices',
            pageBuilder: (_, state) {
              final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
              return NoTransitionPage(child: UniversalNoticesScreen(initialTab: tab));
            },
          ),

          GoRoute(
            path: '/admin/vehicle-dashboard',
            pageBuilder: (_, __) => const NoTransitionPage(child: VehicleLiveDashboardScreen()),
          ),

          GoRoute(
            path: '/admin/fleet',
            pageBuilder: (context, state) {
              final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
              return NoTransitionPage(child: FleetManagementScreen(initialTab: tab));
            },
          ),
          GoRoute(
            path: '/admin/driver-management',
            pageBuilder: (context, state) {
              final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
              return NoTransitionPage(child: DriverManagementScreen(initialTab: tab));
            },
          ),
          GoRoute(
            path: '/admin/route-management',
            pageBuilder: (context, state) {
              final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
              return NoTransitionPage(child: RouteManagementScreen(initialIndex: tab));
            },
          ),
          GoRoute(
            path: '/admin/trips-schedule',
            pageBuilder: (_, __) => const NoTransitionPage(child: PlaceholderScreen(title: 'Trips & Schedule')),
          ),
          GoRoute(
            path: '/admin/stops',
            pageBuilder: (_, __) => const NoTransitionPage(child: RouteManagementScreen(initialIndex: 4)),
          ),
          GoRoute(
            path: '/admin/students',
            pageBuilder: (_, __) => const NoTransitionPage(child: PlaceholderScreen(title: 'Students')),
          ),
          GoRoute(
            path: '/admin/attendance',
            pageBuilder: (_, state) {
              final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
              return NoTransitionPage(child: AttendanceManagementScreen(initialTab: tab));
            },
          ),
          GoRoute(
            path: '/attendance',
            pageBuilder: (_, state) {
              final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
              return NoTransitionPage(child: AttendanceManagementScreen(initialTab: tab));
            },
          ),
          GoRoute(
            path: '/admin/live-classes',
            pageBuilder: (_, state) {
              final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
              return NoTransitionPage(
                key: ValueKey('live_classes_$tab'),
                child: LiveClassManagementScreen(initialTabIndex: tab),
              );
            },
          ),
          GoRoute(
            path: '/live-classes',
            pageBuilder: (_, state) {
              final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
              return NoTransitionPage(
                key: ValueKey('live_classes_alias_$tab'),
                child: LiveClassManagementScreen(initialTabIndex: tab),
              );
            },
          ),
          GoRoute(
            path: '/admin/live-classes/join',
            pageBuilder: (_, __) => const NoTransitionPage(
              key: ValueKey('live_classes_join'),
              child: LiveClassManagementScreen(initialTabIndex: 0),
            ),
          ),
          GoRoute(
            path: '/admin/live-classes/recordings',
            pageBuilder: (_, __) => const NoTransitionPage(
              key: ValueKey('live_classes_recordings'),
              child: LiveClassManagementScreen(initialTabIndex: 1),
            ),
          ),
          GoRoute(
            path: '/admin/live-classes/attendance',
            pageBuilder: (_, __) => const NoTransitionPage(
              key: ValueKey('live_classes_attendance'),
              child: LiveClassManagementScreen(initialTabIndex: 2),
            ),
          ),

          GoRoute(
            path: '/admin/parent-requests',
            pageBuilder: (_, __) => const NoTransitionPage(child: PlaceholderScreen(title: 'Parent Requests')),
          ),
          GoRoute(
            path: '/admin/incidents',
            pageBuilder: (_, __) => const NoTransitionPage(child: PlaceholderScreen(title: 'Incidents')),
          ),
          GoRoute(
            path: '/admin/maintenance',
            pageBuilder: (_, __) => const NoTransitionPage(child: PlaceholderScreen(title: 'Maintenance')),
          ),
          GoRoute(
            path: '/admin/fuel-management',
            pageBuilder: (_, __) => const NoTransitionPage(child: PlaceholderScreen(title: 'Fuel Management')),
          ),
          GoRoute(
            path: '/admin/reports',
            pageBuilder: (_, __) => const NoTransitionPage(child: PlaceholderScreen(title: 'Reports & Analytics')),
          ),
          GoRoute(
            path: '/admin/notifications',
            pageBuilder: (_, __) => const NoTransitionPage(child: PlaceholderScreen(title: 'Notifications')),
          ),
          GoRoute(
            path: '/admin/geofencing',
            pageBuilder: (_, __) => const NoTransitionPage(child: PlaceholderScreen(title: 'Geofencing')),
          ),
          GoRoute(
            path: '/admin/settings',
            pageBuilder: (_, __) => const NoTransitionPage(child: PlaceholderScreen(title: 'System Settings')),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.explore_off_rounded, size: 64, color: Color(0xFF6366F1)),
                const SizedBox(height: 20),
                const Text(
                  'Page Not Found',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  'The requested route "${state.uri.path}" could not be found or has moved.',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.go('/admin/dashboard'),
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Back to Dashboard'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
});

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? Colors.white10 : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.2 : 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.construction_rounded,
                  color: Color(0xFF4F46E5),
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                  fontFamily: 'Inter',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'This sub-module is fully integrated into the administrative console.',
                style: TextStyle(
                  fontSize: 14,
                  color: textSecondary,
                  fontFamily: 'Inter',
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
