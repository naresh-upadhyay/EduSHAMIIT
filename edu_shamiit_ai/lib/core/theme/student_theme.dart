import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

ThemeData getStudentTheme({Brightness brightness = Brightness.light}) {
  final isDark = brightness == Brightness.dark;
  final baseTheme = isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
  
  final bgColor = isDark ? StudentColors.darkBackground : StudentColors.background;
  final surfaceColor = isDark ? StudentColors.darkSurface : StudentColors.surface;
  final textColor = isDark ? StudentColors.darkText : StudentColors.text;
  final textColor2 = isDark ? StudentColors.darkText2 : StudentColors.text2;
  final textColor3 = isDark ? StudentColors.darkText3 : StudentColors.text3;
  final borderColor = isDark ? StudentColors.darkBorder : StudentColors.border;

  return baseTheme.copyWith(
    primaryColor: StudentColors.primary,
    scaffoldBackgroundColor: bgColor,
    colorScheme: ColorScheme.fromSeed(
      seedColor: StudentColors.primary,
      brightness: brightness,
      primary: StudentColors.primary,
      secondary: StudentColors.accent,
      surface: surfaceColor,
      error: StudentColors.error,
    ),

    // Text Theme - Use Google Fonts to load Outfit and DM Sans
    textTheme: GoogleFonts.dmSansTextTheme(baseTheme.textTheme).copyWith(
      displayLarge: GoogleFonts.outfit(
        textStyle: baseTheme.textTheme.displayLarge?.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
      displayMedium: GoogleFonts.outfit(
        textStyle: baseTheme.textTheme.displayMedium?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
      headlineLarge: GoogleFonts.outfit(
        textStyle: baseTheme.textTheme.headlineLarge?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
      headlineMedium: GoogleFonts.outfit(
        textStyle: baseTheme.textTheme.headlineMedium?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
      headlineSmall: GoogleFonts.outfit(
        textStyle: baseTheme.textTheme.headlineSmall?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      titleLarge: GoogleFonts.outfit(
        textStyle: baseTheme.textTheme.titleLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
      titleMedium: GoogleFonts.dmSans(
        textStyle: baseTheme.textTheme.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      bodyLarge: GoogleFonts.dmSans(
        textStyle: baseTheme.textTheme.bodyLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
      bodyMedium: GoogleFonts.dmSans(
        textStyle: baseTheme.textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textColor2,
        ),
      ),
      bodySmall: GoogleFonts.dmSans(
        textStyle: baseTheme.textTheme.bodySmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor3,
        ),
      ),
      labelLarge: GoogleFonts.dmSans(
        textStyle: baseTheme.textTheme.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    ),

    // App Bar Theme
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: textColor),
    ),

    // Card Theme
    cardTheme: CardThemeData(
      color: surfaceColor,
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
        textStyle: GoogleFonts.dmSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Input Decoration Theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
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