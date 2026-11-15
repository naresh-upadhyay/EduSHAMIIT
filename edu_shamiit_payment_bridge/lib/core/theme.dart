import 'package:flutter/material.dart';

class AppColors {
  // Brand & Header
  static const Color headerNavy = Color(0xFF003F9E);
  static const Color primaryNavy = Color(0xFF003F9E);
  static const Color headerGradientStart = Color(0xFF00388A);
  static const Color headerGradientEnd = Color(0xFF004CB8);

  // Backgrounds
  static const Color background = Color(0xFFF4F7FC);
  static const Color cardBackground = Colors.white;

  // Primary Accent
  static const Color primaryBlue = Color(0xFF0B63F6);
  static const Color primaryBlueLight = Color(0xFFE8F1FE);

  // Status Colors
  static const Color successGreen = Color(0xFF10A352);
  static const Color successGreenBg = Color(0xFFE8F8EE);

  static const Color warningOrange = Color(0xFFE67E22);
  static const Color warningOrangeBg = Color(0xFFFFF4E5);

  static const Color pendingBlue = Color(0xFF2980B9);
  static const Color pendingBlueBg = Color(0xFFE8F4FC);

  static const Color refundPurple = Color(0xFF8E44AD);
  static const Color refundPurpleBg = Color(0xFFF5EEF8);

  static const Color ignoredGrey = Color(0xFF7F8C8D);
  static const Color ignoredGreyBg = Color(0xFFF2F4F4);

  // Text
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderSubtle = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFEDF2F7);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryBlue,
        primary: AppColors.primaryBlue,
        surface: AppColors.cardBackground,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.headerNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primaryBlue,
        unselectedItemColor: AppColors.textMuted,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  static ThemeData get theme => lightTheme;
}
