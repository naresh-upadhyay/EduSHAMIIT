import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/providers/auth_provider.dart';
import 'package:edu_shamiit_ai/core/providers/role_provider.dart';
import 'package:edu_shamiit_ai/core/config/app_config.dart';

/// Authentication guard for protecting routes
class AuthGuard {
  /// Check if user is authenticated
  static bool isAuthenticated(WidgetRef ref) {
    final authState = ref.read(authProvider);
    return authState.isAuthenticated;
  }

  /// Check if user has specific role
  static bool hasRole(WidgetRef ref, UserRole role) {
    final roleState = ref.read(roleProvider);
    return roleState.role == role;
  }

  /// Check if user is a student
  static bool isStudent(WidgetRef ref) {
    return hasRole(ref, UserRole.student);
  }

  /// Check if user is a teacher
  static bool isTeacher(WidgetRef ref) {
    return hasRole(ref, UserRole.teacher);
  }

  /// Get the appropriate dashboard route based on user role
  static String getDashboardRoute(WidgetRef ref) {
    if (isTeacher(ref)) {
      return AppConfig.teacherDashboardRoute;
    }
    return AppConfig.studentDashboardRoute;
  }

  /// Redirect to login if not authenticated
  /// Returns true if user should be redirected (not authenticated)
  static bool redirectIfNotAuthenticated(WidgetRef ref, BuildContext context) {
    if (!isAuthenticated(ref)) {
      // Store the attempted URL for redirecting after login
      String location = '';
      try {
        location = GoRouterState.of(context).uri.toString();
      } catch (_) {
        try {
          location = GoRouter.of(context).routeInformationProvider.value.uri.toString();
        } catch (_) {}
      }
      context.go('${AppConfig.loginRoute}?redirect=$location');
      return true;
    }
    return false;
  }

  /// Redirect if already authenticated (for login/splash screens)
  /// Returns true if user should be redirected (already authenticated)
  static bool redirectIfAuthenticated(WidgetRef ref, BuildContext context) {
    if (isAuthenticated(ref)) {
      context.go(getDashboardRoute(ref));
      return true;
    }
    return false;
  }

  /// Redirect if user doesn't have required role
  /// Returns true if user should be redirected (wrong role)
  static bool redirectIfNotRole(WidgetRef ref, BuildContext context, UserRole requiredRole) {
    if (!isAuthenticated(ref)) {
      return redirectIfNotAuthenticated(ref, context);
    }
    if (!hasRole(ref, requiredRole)) {
      // Redirect to appropriate dashboard
      context.go(getDashboardRoute(ref));
      return true;
    }
    return false;
  }

  /// Redirect if user is student (for teacher-only routes)
  static bool redirectIfStudent(WidgetRef ref, BuildContext context) {
    return redirectIfNotRole(ref, context, UserRole.teacher);
  }

  /// Redirect if user is teacher (for student-only routes)
  static bool redirectIfTeacher(WidgetRef ref, BuildContext context) {
    return redirectIfNotRole(ref, context, UserRole.student);
  }
}

/// GoRouter redirect handler for authentication
GoRouterRedirect createAuthRedirect(WidgetRef ref) {
  return (context, state) {
    // Paths that don't require authentication
    final publicPaths = [
      AppConfig.splashRoute,
      AppConfig.loginRoute,
      '/forgot-password',
      '/otp-verification',
      '/reset-password',
      '/password-reset-success',
    ];

    final location = state.uri.toString();

    // Check if this is a public path
    if (publicPaths.any((path) => location.startsWith(path))) {
      // If already authenticated, redirect to dashboard
      if (AuthGuard.isAuthenticated(ref)) {
        return AuthGuard.getDashboardRoute(ref);
      }
      return null;
    }

    // For all other paths, require authentication
    if (!AuthGuard.isAuthenticated(ref)) {
      // Redirect to login with the attempted URL
      return '${AppConfig.loginRoute}?redirect=${Uri.encodeComponent(location)}';
    }

    // Check role-based access
    final studentPaths = ['/student/'];
    final teacherPaths = ['/teacher/'];

    if (studentPaths.any((path) => location.startsWith(path))) {
      if (!AuthGuard.isStudent(ref)) {
        return AuthGuard.getDashboardRoute(ref);
      }
    } else if (teacherPaths.any((path) => location.startsWith(path))) {
      if (!AuthGuard.isTeacher(ref)) {
        return AuthGuard.getDashboardRoute(ref);
      }
    }

    return null;
  };
}