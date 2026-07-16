import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_admin/screens/login_screen.dart';
import 'package:edu_shamiit_admin/screens/dashboard_screen.dart';
import 'package:edu_shamiit_admin/screens/role_dashboards/super_admin_dashboard_screen.dart';
import 'package:edu_shamiit_admin/screens/role_dashboards/my_profile_screen.dart';
import 'package:edu_shamiit_admin/screens/modules/schools/schools_screen.dart';
import 'package:edu_shamiit_admin/screens/modules/users/users_screen.dart';
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
import 'package:edu_shamiit_core/edu_shamiit_core.dart';
import 'package:edu_shamiit_admin/providers/system_config_provider.dart';

final adminShellKey = GlobalKey<NavigatorState>(debugLabel: 'adminShell');

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
  final config = ref.watch(systemConfigProvider);
  final notifier = RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final loggedIn = authState.isAuthenticated;
      final path = state.matchedLocation;
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
          path == '/help-center';

      if (!loggedIn && !isPublic) {
        return '/login';
      }
      if (loggedIn && isPublic) {
        return '/admin/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => SharedHomeScreen(
          systemName: config?.systemName,
          systemLogo: config?.systemLogo,
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const AdminLoginScreen(),
      ),
      GoRoute(
        path: '/contact',
        builder: (context, state) => SharedContactUsScreen(
          systemName: config?.systemName,
          systemLogo: config?.systemLogo,
          illustrationUrl: 'assets/images/contact_illustration.png',
        ),
      ),
      GoRoute(
        path: '/privacy-policy',
        builder: (context, state) => SharedPrivacyPolicyScreen(
          systemName: config?.systemName,
          systemLogo: config?.systemLogo,
          illustrationUrl: 'assets/images/privacy_illustration.png',
        ),
      ),
      GoRoute(
        path: '/terms-conditions',
        builder: (context, state) => SharedTermsConditionsScreen(
          systemName: config?.systemName,
          systemLogo: config?.systemLogo,
          illustrationUrl: 'assets/images/terms_illustration.png',
        ),
      ),
      GoRoute(
        path: '/get-started',
        builder: (context, state) => SharedGetStartedScreen(
          systemName: config?.systemName,
          systemLogo: config?.systemLogo,
        ),
      ),
      GoRoute(
        path: '/faq',
        builder: (context, state) => SharedFaqScreen(
          systemName: config?.systemName,
          systemLogo: config?.systemLogo,
          illustrationUrl: 'assets/images/faq_illustration.png',
        ),
      ),
      GoRoute(
        path: '/user-guides',
        builder: (context, state) {
          final category = state.uri.queryParameters['category'];
          final article = state.uri.queryParameters['article'];
          return SharedUserGuidesScreen(
            systemName: config?.systemName,
            systemLogo: config?.systemLogo,
            illustrationUrl: 'assets/images/user_guide_illustration.png',
            videoIllustrationUrl: 'assets/images/video_tutorials_illustration.png',
            initialCategory: category,
            initialArticleId: article,
          );
        },
      ),
      GoRoute(
        path: '/help-center',
        builder: (context, state) => SharedHelpCenterScreen(
          systemName: config?.systemName,
          systemLogo: config?.systemLogo,
          illustrationUrl: 'assets/images/help_center_illustration.png',
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => SharedForgotPasswordScreen(
          isAdmin: true,
          systemName: config?.systemName,
          systemLogo: config?.systemLogo,
          illustrationUrl: config?.forgotPasswordIllustration,
        ),
      ),
      GoRoute(
        path: '/otp-verification',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          final email = args?['email'] as String? ?? '';
          final isLogin = args?['isLogin'] as bool? ?? false;
          final role = args?['role'] as UserRole?;
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
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) {
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
      GoRoute(
        path: '/password-reset-success',
        builder: (context, state) => const SharedPasswordResetSuccessScreen(isAdmin: true),
      ),
      GoRoute(
        path: '/dashboard',
        redirect: (_, __) => '/admin/dashboard',
      ),
      ShellRoute(
        navigatorKey: adminShellKey,
        builder: (context, state, child) => AdminDashboardScreen(child: child),
        routes: [
          GoRoute(
            path: '/admin/dashboard',
            pageBuilder: (_, __) => const NoTransitionPage(child: SuperAdminDashboardScreen()),
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
            pageBuilder: (_, __) => const NoTransitionPage(child: AdminSystemConfigScreen()),
          ),
          GoRoute(
            path: '/admin/roles',
            pageBuilder: (_, __) => const NoTransitionPage(child: AdminRolesScreen()),
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

          GoRoute(
            path: '/admin/modules',
            pageBuilder: (_, __) => const NoTransitionPage(child: ModuleToggleScreen()),
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
            path: '/admin/announcements',
            pageBuilder: (_, __) => const NoTransitionPage(child: AnnouncementsScreen()),
          ),


        ],
      ),
    ],
  );
});
