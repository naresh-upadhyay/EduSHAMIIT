import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Dynamically resolves the base navigation route for Exams:
/// Returns '/admin/exams' when accessed from admin portal,
/// and '/teacher/exams' when accessed from teacher academic portal.
String getExamsBaseRoute(BuildContext context) {
  String location = '';
  try {
    location = GoRouterState.of(context).uri.toString();
  } catch (_) {
    try {
      location = GoRouter.of(context).routeInformationProvider.value.uri.toString();
    } catch (_) {}
  }
  if (location.startsWith('/admin')) {
    return '/admin/exams';
  }
  if (location.startsWith('/student')) {
    return '/student/exams';
  }
  return '/teacher/exams';
}

/// Returns the correct dashboard fallback route based on the current location.
String dashboardFallback(BuildContext context) {
  String location = '';
  try {
    location = GoRouterState.of(context).uri.toString();
  } catch (_) {
    try {
      location = GoRouter.of(context).routeInformationProvider.value.uri.toString();
    } catch (_) {}
  }
  if (location.startsWith('/admin')) {
    return '/admin/dashboard';
  }
  if (location.startsWith('/teacher')) {
    return '/teacher/dashboard';
  }
  return '/student/dashboard';
}

/// Safely navigates back. If there's history to pop, it pops.
/// Otherwise it navigates to the [fallbackRoute] or [getExamsBaseRoute(context)].
void safeGoBack(BuildContext context, [String? fallbackRoute]) {
  try {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
  } catch (_) {}

  try {
    if (context.canPop()) {
      context.pop();
      return;
    }
  } catch (_) {}

  final target = fallbackRoute ?? getExamsBaseRoute(context);
  context.go(target);
}
