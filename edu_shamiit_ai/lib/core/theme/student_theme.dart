import 'package:flutter/material.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

ThemeData getStudentTheme() {
  return ThemeData(
    useMaterial3: true,
    primaryColor: StudentColors.primary,
    scaffoldBackgroundColor: StudentColors.background,
    colorScheme: const ColorScheme.light(
      primary: StudentColors.primary,
      secondary: StudentColors.accent,
      surface: StudentColors.surface,
      error: StudentColors.error,
    ),

    // Text Theme
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: AppFonts.heading,
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: StudentColors.text,
      ),
      displayMedium: TextStyle(
        fontFamily: AppFonts.heading,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: StudentColors.text,
      ),
      headlineLarge: TextStyle(
        fontFamily: AppFonts.heading,
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: StudentColors.text,
      ),
      headlineMedium: TextStyle(
        fontFamily: AppFonts.heading,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: StudentColors.text,
      ),
      headlineSmall: TextStyle(
        fontFamily: AppFonts.heading,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: StudentColors.text,
      ),
      titleLarge: TextStyle(
        fontFamily: AppFonts.heading,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: StudentColors.text,
      ),
      titleMedium: TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: StudentColors.text,
      ),
      bodyLarge: TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: StudentColors.text,
      ),
      bodyMedium: TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: StudentColors.text2,
      ),
      bodySmall: TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: StudentColors.text3,
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
      iconTheme: IconThemeData(color: StudentColors.text),
    ),

    // Card Theme
    cardTheme: CardThemeData(
      color: StudentColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      margin: EdgeInsets.zero,
    ),

    // Elevated Button Theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: StudentColors.primary,
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

    // Input Decoration Theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: StudentColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: StudentColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: StudentColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: StudentColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}