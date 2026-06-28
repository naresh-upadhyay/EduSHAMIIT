import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/teacher_colors.dart';
import 'responsive_dialog_padding.dart';

ThemeData getTeacherTheme({Brightness brightness = Brightness.light}) {
  final baseTheme = brightness == Brightness.dark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
  
  return baseTheme.copyWith(
    primaryColor: TeacherColors.primary,
    scaffoldBackgroundColor: TeacherColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: TeacherColors.primary,
      brightness: brightness,
      primary: TeacherColors.primary,
      secondary: TeacherColors.accent,
      surface: TeacherColors.surface,
      error: TeacherColors.error,
    ),

    // Text Theme - Use Google Fonts to load Outfit and DM Sans
    textTheme: GoogleFonts.dmSansTextTheme(baseTheme.textTheme).copyWith(
      displayLarge: GoogleFonts.outfit(
        textStyle: baseTheme.textTheme.displayLarge?.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: TeacherColors.text,
        ),
      ),
      displayMedium: GoogleFonts.outfit(
        textStyle: baseTheme.textTheme.displayMedium?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: TeacherColors.text,
        ),
      ),
      headlineLarge: GoogleFonts.outfit(
        textStyle: baseTheme.textTheme.headlineLarge?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: TeacherColors.text,
        ),
      ),
      headlineMedium: GoogleFonts.outfit(
        textStyle: baseTheme.textTheme.headlineMedium?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: TeacherColors.text,
        ),
      ),
      headlineSmall: GoogleFonts.outfit(
        textStyle: baseTheme.textTheme.headlineSmall?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: TeacherColors.text,
        ),
      ),
      titleLarge: GoogleFonts.outfit(
        textStyle: baseTheme.textTheme.titleLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: TeacherColors.text,
        ),
      ),
      titleMedium: GoogleFonts.dmSans(
        textStyle: baseTheme.textTheme.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: TeacherColors.text,
        ),
      ),
      bodyLarge: GoogleFonts.dmSans(
        textStyle: baseTheme.textTheme.bodyLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: TeacherColors.text,
        ),
      ),
      bodyMedium: GoogleFonts.dmSans(
        textStyle: baseTheme.textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: TeacherColors.text2,
        ),
      ),
      bodySmall: GoogleFonts.dmSans(
        textStyle: baseTheme.textTheme.bodySmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: TeacherColors.text3,
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
        textStyle: GoogleFonts.dmSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      insetPadding: ResponsiveInsetPadding(),
    ),
  );
}