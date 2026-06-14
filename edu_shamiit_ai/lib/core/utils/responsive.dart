import 'package:flutter/material.dart';

/// Centralized responsive utility for adaptive layouts across
/// mobile, tablet, and desktop (web) screens.
///
/// Breakpoints:
///   mobile  : width < 600
///   tablet  : 600 <= width < 1100
///   desktop : width >= 1100
class Responsive {
  Responsive._();

  // ─── Breakpoints ───────────────────────────────────────────
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1100;

  // ─── Device detection ──────────────────────────────────────
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileBreakpoint;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= mobileBreakpoint && w < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletBreakpoint;

  /// Returns true when the screen is wider than mobile (tablet or desktop).
  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= mobileBreakpoint;

  // ─── Content constraints ───────────────────────────────────

  /// Max width for the main content area.
  /// On mobile this returns double.infinity (no constraint).
  /// On tablet/desktop it caps content so cards don't stretch.
  static double contentMaxWidth(BuildContext context) {
    if (isDesktop(context)) return 900;
    if (isTablet(context)) return 720;
    return double.infinity;
  }

  // ─── Grid helpers ──────────────────────────────────────────

  /// Dynamic cross-axis count for Quick Access–style grids.
  static int gridCrossAxisCount(BuildContext context) {
    if (isDesktop(context)) return 6;
    if (isTablet(context)) return 5;
    return 4; // mobile
  }

  /// Child aspect ratio for Quick Access grid tiles.
  static double gridChildAspectRatio(BuildContext context) {
    if (isDesktop(context)) return 1.0;
    if (isTablet(context)) return 0.95;
    return 0.85;
  }

  // ─── Padding helpers ───────────────────────────────────────

  /// Horizontal body padding that grows with screen width.
  static double horizontalPadding(BuildContext context) {
    if (isDesktop(context)) return 32;
    if (isTablet(context)) return 24;
    return 14; // mobile default
  }

  /// EdgeInsets for the main content area.
  static EdgeInsets contentPadding(BuildContext context) {
    final h = horizontalPadding(context);
    return EdgeInsets.symmetric(horizontal: h);
  }

  // ─── Header helpers ────────────────────────────────────────

  /// Expanded height for SliverAppBar headers.
  static double headerExpandedHeight(BuildContext context) {
    if (isDesktop(context)) return 240;
    if (isTablet(context)) return 240;
    return 250;
  }

  /// Top padding for non-sliver headers (replaces hardcoded 50).
  static double headerTopPadding(BuildContext context) {
    if (isWide(context)) {
      return 6.0; // Compact padding on tablet/desktop to optimize screen height usage
    }
    final top = MediaQuery.paddingOf(context).top;
    // On web/desktop the safe-area top is 0, so add a sensible minimum
    return top > 0 ? top + 8 : 16;
  }

  // ─── Font scaling ──────────────────────────────────────────

  /// Returns the text scale factor clamped to avoid bloated text on web.
  static double clampedTextScale(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final scale = scaler.scale(1.0);
    return scale.clamp(0.8, 1.2);
  }

  // ─── Value selector ────────────────────────────────────────

  /// Pick a value depending on the current breakpoint.
  /// Usage:
  /// ```dart
  /// Responsive.value(context, mobile: 4, tablet: 5, desktop: 6)
  /// ```
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context)) return desktop ?? tablet ?? mobile;
    if (isTablet(context)) return tablet ?? mobile;
    return mobile;
  }
}
