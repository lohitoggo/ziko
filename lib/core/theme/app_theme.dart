import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary = Color(0xFFE1543D); // warm chili-red/orange
  static const primaryDark = Color(0xFFB33F2C);
  static const cream = Color(0xFFFFF7ED); // background
  static const charcoal = Color(0xFF2B2118); // primary text
  static const gold = Color(0xFFF5A623); // accent
  static const softGreen = Color(0xFF4C9A6A); // success
  static const muted = Color(0xFF8A7B6C); // secondary text
}

class AppTheme {
  static TextTheme get _textTheme {
    final display = GoogleFonts.baloo2TextTheme();
    final body = GoogleFonts.hindSiliguriTextTheme();

    return body.copyWith(
      displayLarge: display.displayLarge?.copyWith(color: AppColors.charcoal),
      displayMedium:
      display.displayMedium?.copyWith(color: AppColors.charcoal),
      headlineLarge: display.headlineLarge?.copyWith(
          color: AppColors.charcoal, fontWeight: FontWeight.w700),
      headlineMedium: display.headlineMedium?.copyWith(
          color: AppColors.charcoal, fontWeight: FontWeight.w700),
      headlineSmall: display.headlineSmall?.copyWith(
          color: AppColors.charcoal, fontWeight: FontWeight.w600),
      titleLarge: display.titleLarge?.copyWith(
          color: AppColors.charcoal, fontWeight: FontWeight.w600),
      titleMedium: body.titleMedium?.copyWith(color: AppColors.charcoal),
      bodyLarge: body.bodyLarge?.copyWith(color: AppColors.charcoal),
      bodyMedium: body.bodyMedium?.copyWith(color: AppColors.muted),
    );
  }

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: AppColors.cream,
    ),
    scaffoldBackgroundColor: AppColors.cream,
    textTheme: _textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.baloo2(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: GoogleFonts.hindSiliguri(
            fontSize: 16, fontWeight: FontWeight.w600),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
    ),
  );
}