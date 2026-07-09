import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_admin/screens/login_screen.dart';
import 'package:edu_shamiit_admin/screens/dashboard_screen.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/dashboard',
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
        return '/dashboard';
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
        builder: (context, state) => const AdminDashboardScreen(),
      ),
    ],
  );
});
