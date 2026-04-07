import 'package:flutter/material.dart';
import 'package:edu_shamiit_ai/core/constants/teacher_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

ThemeData getTeacherTheme() {
  return ThemeData(
    useMaterial3: true,
    primaryColor: TeacherColors.primary,
    scaffoldBackgroundColor: TeacherColors.background,
    colorScheme: const ColorScheme.light(
      primary: TeacherColors.primary,
      secondary: TeacherColors.accent,
      surface: TeacherColors.surface,
      error: TeacherColors.error,
    ),

    // Text Theme
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: AppFonts.heading,
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: TeacherColors.text,
      ),
      displayMedium: TextStyle(
        fontFamily: AppFonts.heading,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: TeacherColors.text,
      ),
      headlineLarge: TextStyle(
        fontFamily: AppFonts.heading,
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: TeacherColors.text,
      ),
      headlineMedium: TextStyle(
        fontFamily: AppFonts.heading,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: TeacherColors.text,
      ),
      headlineSmall: TextStyle(
        fontFamily: AppFonts.heading,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: TeacherColors.text,
      ),
      titleLarge: TextStyle(
        fontFamily: AppFonts.heading,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: TeacherColors.text,
      ),
      titleMedium: TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: TeacherColors.text,
      ),
      bodyLarge: TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: TeacherColors.text,
      ),
      bodyMedium: TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: TeacherColors.text2,
      ),
      bodySmall: TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: TeacherColors.text3,
      ),
      labelLarge: TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),

    // App Bar Theme
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: TeacherColors.text),
    ),

    // Card Theme
    cardTheme: CardThemeData(
      color: TeacherColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      margin: EdgeInsets.zero,
    ),

    // Elevated Button Theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: TeacherColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}