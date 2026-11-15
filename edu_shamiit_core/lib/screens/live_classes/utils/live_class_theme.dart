import 'package:flutter/material.dart';

/// Centralized dynamic theme utility for Live Class Management.
/// Respects system configuration appearance colors dynamically.
class LiveClassTheme {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color primary(BuildContext context) =>
      Theme.of(context).primaryColor;

  static Color primaryWithOpacity(BuildContext context, double opacity) =>
      Theme.of(context).primaryColor.withValues(alpha: opacity);

  static LinearGradient primaryGradient(BuildContext context) {
    final p = primary(context);
    return LinearGradient(
      colors: [p, Color.lerp(p, Colors.black, 0.25) ?? p],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  static Color cardBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF13182C) : Colors.white;

  static Color cardBorder(BuildContext context) =>
      isDark(context) ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0);

  static Color cardDivider(BuildContext context) =>
      isDark(context) ? const Color(0xFF1F293D) : const Color(0xFFF1F5F9);

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? Colors.white : const Color(0xFF0F172A);

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  static Color inputBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);

  static Color headerRowBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);

  static Color selectedRowBg(BuildContext context) {
    final p = primary(context);
    return isDark(context)
        ? p.withValues(alpha: 0.18)
        : p.withValues(alpha: 0.08);
  }
}
