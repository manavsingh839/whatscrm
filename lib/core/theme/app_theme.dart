import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Brand & WhatsApp Colors
  static const Color primary = Color(0xFF10B981); // Emerald / WhatsApp Green
  static const Color primaryDark = Color(0xFF059669);
  static const Color whatsappGreen = Color(0xFF25D366);
  static const Color whatsappDark = Color(0xFF075E54);
  static const Color whatsappLight = Color(0xFFDCF8C6);

  // Dark Theme Palette (Tailwind Zinc/Slate style)
  static const Color darkBg = Color(0xFF09090B); // zinc-950
  static const Color darkCard = Color(0xFF121215); // zinc-900
  static const Color darkSurface = Color(0xFF18181B); // zinc-900 / 800
  static const Color darkBorder = Color(0xFF27272A); // zinc-800
  static const Color darkText = Color(0xFFFAFAFA); // zinc-50
  static const Color darkTextMuted = Color(0xFFA1A1AA); // zinc-400

  // Light Theme Palette
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightCard = Colors.white;
  static const Color lightSurface = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightText = Color(0xFF0F172A);
  static const Color lightTextMuted = Color(0xFF64748B);

  // Status Colors
  static const Color statusOpen = Color(0xFF3B82F6); // Blue
  static const Color statusPending = Color(0xFFF59E0B); // Amber
  static const Color statusClosed = Color(0xFF10B981); // Green
  static const Color statusFailed = Color(0xFFEF4444); // Red
  static const Color statusSending = Color(0xFF94A3B8); // Slate
}

class AppTheme {
  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      primaryColor: AppColors.primary,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.whatsappGreen,
        surface: AppColors.darkCard,
        surfaceContainerHighest: AppColors.darkSurface,
        onSurface: AppColors.darkText,
        outline: AppColors.darkBorder,
        error: AppColors.statusFailed,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        hintStyle: TextStyle(color: AppColors.darkTextMuted, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      textTheme: baseTextTheme.apply(
        bodyColor: AppColors.darkText,
        displayColor: AppColors.darkText,
      ),
    );
  }

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.light().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      primaryColor: AppColors.primary,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.whatsappGreen,
        surface: AppColors.lightCard,
        surfaceContainerHighest: AppColors.lightSurface,
        onSurface: AppColors.lightText,
        outline: AppColors.lightBorder,
        error: AppColors.statusFailed,
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightBorder,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: TextStyle(color: AppColors.lightTextMuted, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      textTheme: baseTextTheme.apply(
        bodyColor: AppColors.lightText,
        displayColor: AppColors.lightText,
      ),
    );
  }
}
