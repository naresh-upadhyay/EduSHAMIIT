import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Safely navigates back. If there's history to pop, it pops.
/// Otherwise it navigates to the [fallbackRoute] (typically the dashboard).
void safeGoBack(BuildContext context, String fallbackRoute) {
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

  context.go(fallbackRoute);
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
  if (location.startsWith('/teacher')) {
    return '/teacher/dashboard';
  }
  return '/student/dashboard';
}
