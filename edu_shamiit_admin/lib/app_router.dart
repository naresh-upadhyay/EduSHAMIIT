import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_admin/screens/login_screen.dart';
import 'package:edu_shamiit_admin/screens/dashboard_screen.dart';
import 'package:edu_shamiit_admin/screens/role_dashboards/super_admin_dashboard_screen.dart';
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
import 'package:edu_shamiit_admin/screens/tabs/system_control_tab.dart';
import 'package:edu_shamiit_admin/screens/modules/quick_access/quick_access_screens.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';

final adminShellKey = GlobalKey<NavigatorState>(debugLabel: 'adminShell');

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/admin/dashboard',
    redirect: (context, state) {
      final loggedIn = authState.isAuthenticated;
      final path = state.matchedLocation;
      final isPublic = path == '/login' ||
          path == '/forgot-password' ||
          path == '/otp-verification' ||
          path == '/reset-password' ||
          path == '/password-reset-success';

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
        path: '/login',
        builder: (context, state) => const AdminLoginScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const SharedForgotPasswordScreen(isAdmin: true),
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
          );
        },
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          final email = args?['email'] as String? ?? '';
          final otp = args?['otp'] as String? ?? '';
          return SharedResetPasswordScreen(email: email, otp: otp, isAdmin: true);
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
            pageBuilder: (_, __) => const NoTransitionPage(child: AdminUsersScreen()),
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
            path: '/admin/system-control',
            pageBuilder: (_, __) => const NoTransitionPage(child: SystemControlTab()),
          ),

          GoRoute(
            path: '/admin/modules',
            pageBuilder: (_, __) => const NoTransitionPage(child: ModuleToggleScreen()),
          ),
          GoRoute(
            path: '/admin/modules-config',
            pageBuilder: (_, __) => const NoTransitionPage(child: ModuleConfigScreen()),
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
            pageBuilder: (_, __) => const NoTransitionPage(child: AuditLogScreen()),
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
