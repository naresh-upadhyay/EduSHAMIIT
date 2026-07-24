import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_admin/screens/login_screen.dart';
import 'package:edu_shamiit_admin/screens/dashboard_screen.dart';
import 'package:edu_shamiit_admin/screens/role_dashboards/super_admin_dashboard_screen.dart';
import 'package:edu_shamiit_admin/screens/role_dashboards/driver_dashboard_screen.dart';
import 'package:edu_shamiit_admin/screens/role_dashboards/driver_timetable_screen.dart';
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
import 'package:edu_shamiit_admin/screens/modules/quick_access/emergency_screen.dart';
import 'package:edu_shamiit_admin/screens/modules/fleet/driver_management_screen.dart';
import 'package:edu_shamiit_admin/screens/modules/fleet/route_management_screen.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';
import 'package:edu_shamiit_admin/providers/system_config_provider.dart';

final adminShellKey = GlobalKey<NavigatorState>(debugLabel: 'adminShell');

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
        builder: (context, state) {
          final config = ref.watch(systemConfigProvider);
          return SharedHomeScreen(
            systemName: config?.systemName,
            systemLogo: config?.systemLogo,
          );
        },
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const AdminLoginScreen(),
      ),
      GoRoute(
        path: '/contact',
        builder: (context, state) {
          final config = ref.watch(systemConfigProvider);
          return SharedContactUsScreen(
            systemName: config?.systemName,
            systemLogo: config?.systemLogo,
            illustrationUrl: 'assets/images/contact_illustration.png',
          );
        },
      ),
      GoRoute(
        path: '/privacy-policy',
        builder: (context, state) {
          final config = ref.watch(systemConfigProvider);
          return SharedPrivacyPolicyScreen(
            systemName: config?.systemName,
            systemLogo: config?.systemLogo,
            illustrationUrl: 'assets/images/privacy_illustration.png',
          );
        },
      ),
      GoRoute(
        path: '/terms-conditions',
        builder: (context, state) {
          final config = ref.watch(systemConfigProvider);
          return SharedTermsConditionsScreen(
            systemName: config?.systemName,
            systemLogo: config?.systemLogo,
            illustrationUrl: 'assets/images/terms_illustration.png',
          );
        },
      ),
      GoRoute(
        path: '/get-started',
        builder: (context, state) {
          final config = ref.watch(systemConfigProvider);
          return SharedGetStartedScreen(
            systemName: config?.systemName,
            systemLogo: config?.systemLogo,
          );
        },
      ),
      GoRoute(
        path: '/faq',
        builder: (context, state) {
          final config = ref.watch(systemConfigProvider);
          return SharedFaqScreen(
            systemName: config?.systemName,
            systemLogo: config?.systemLogo,
            illustrationUrl: 'assets/images/faq_illustration.png',
          );
        },
      ),
      GoRoute(
        path: '/user-guides',
        builder: (context, state) {
          final config = ref.watch(systemConfigProvider);
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
        builder: (context, state) {
          final config = ref.watch(systemConfigProvider);
          return SharedHelpCenterScreen(
            systemName: config?.systemName,
            systemLogo: config?.systemLogo,
            illustrationUrl: 'assets/images/help_center_illustration.png',
          );
        },
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) {
          final config = ref.watch(systemConfigProvider);
          return SharedForgotPasswordScreen(
            isAdmin: true,
            systemName: config?.systemName,
            systemLogo: config?.systemLogo,
            illustrationUrl: config?.forgotPasswordIllustration,
          );
        },
      ),
      GoRoute(
        path: '/otp-verification',
        builder: (context, state) {
          final config = ref.watch(systemConfigProvider);
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
            pageBuilder: (_, __) => const NoTransitionPage(child: DriverTimetableScreen()),
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
            path: '/admin/alerts-notifications',
            pageBuilder: (_, __) => const NoTransitionPage(child: AlertsNotificationsScreen()),
          ),
          GoRoute(
            path: '/admin/emergency',
            pageBuilder: (_, __) => const NoTransitionPage(child: EmergencyScreen()),
          ),


          GoRoute(
            path: '/admin/announcements',
            pageBuilder: (_, __) => const NoTransitionPage(child: AnnouncementsScreen()),
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
            pageBuilder: (_, __) => const NoTransitionPage(child: RouteManagementScreen(initialIndex: 6)),
          ),
          GoRoute(
            path: '/admin/students',
            pageBuilder: (_, __) => const NoTransitionPage(child: PlaceholderScreen(title: 'Students')),
          ),
          GoRoute(
            path: '/admin/attendance',
            pageBuilder: (_, __) => const NoTransitionPage(child: PlaceholderScreen(title: 'Attendance')),
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
  );
});

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
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
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
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
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  fontFamily: 'Inter',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'This sub-module is fully integrated into the administrative console.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
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
