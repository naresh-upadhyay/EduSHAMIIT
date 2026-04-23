import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Safely navigates back. If there's history to pop, it pops.
/// Otherwise it navigates to the [fallbackRoute] (typically the dashboard).
void safeGoBack(BuildContext context, String fallbackRoute) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallbackRoute);
  }
}

/// Returns the correct dashboard fallback route based on the current location.
String dashboardFallback(BuildContext context) {
  final location = GoRouterState.of(context).uri.toString();
  if (location.startsWith('/teacher')) {
    return '/teacher/dashboard';
  }
  return '/student/dashboard';
}
