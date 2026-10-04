import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  const AppTheme._();

  static const Color navy = Color(0xFF17324D);
  static const Color wood = Color(0xFFA66A3F);
  static const Color amber = Color(0xFFD29A5A);
  static const Color cream = Color(0xFFF6F1E8);
  static const Color graphite = Color(0xFF17212B);

  static const Color lightBackground = Color(0xFFF6F7F8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFEEF1F4);
  static const Color lightBorder = Color(0xFFD9DEE5);
  static const Color lightTextPrimary = Color(0xFF17212B);
  static const Color lightTextSecondary = Color(0xFF5F6B78);
  static const Color lightTextMuted = Color(0xFF8A95A1);

  static const Color darkBackground = Color(0xFF0F1720);
  static const Color darkSurface = Color(0xFF162231);
  static const Color darkSurfaceAlt = Color(0xFF1C2B3B);
  static const Color darkBorder = Color(0xFF304255);
  static const Color darkTextPrimary = Color(0xFFF6F1E8);
  static const Color darkTextSecondary = Color(0xFFB8C3CF);
  static const Color darkTextMuted = Color(0xFF7F8C99);
  static const Color darkPrimary = Color(0xFF244968);
  static const Color darkSecondary = Color(0xFFB8794A);

  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: GoogleFonts.cairo().fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: navy,
      brightness: Brightness.light,
      primary: navy,
      secondary: wood,
      tertiary: amber,
      surface: lightSurface,
      surfaceContainerHighest: lightSurfaceAlt,
      outline: lightBorder,
    ),
    scaffoldBackgroundColor: lightBackground,
    canvasColor: lightSurface,
    cardColor: lightSurface,
    dividerColor: lightBorder,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: lightSurface,
      foregroundColor: lightTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: lightSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: lightBorder, width: 1),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    chipTheme: ChipThemeData(
      side: const BorderSide(color: lightBorder),
      selectedColor: navy.withValues(alpha: 0.12),
      backgroundColor: lightSurface,
      labelStyle: GoogleFonts.cairo(color: lightTextPrimary),
      secondaryLabelStyle: GoogleFonts.cairo(color: cream),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    textTheme: GoogleFonts.cairoTextTheme().copyWith(
      displayLarge: GoogleFonts.cairo(
        fontWeight: FontWeight.w700,
        color: lightTextPrimary,
        fontSize: 32,
      ),
      headlineLarge: GoogleFonts.cairo(
        fontWeight: FontWeight.w700,
        color: lightTextPrimary,
        fontSize: 28,
      ),
      headlineMedium: GoogleFonts.cairo(
        fontWeight: FontWeight.w700,
        color: lightTextPrimary,
        fontSize: 24,
      ),
      titleLarge: GoogleFonts.cairo(
        fontWeight: FontWeight.w700,
        color: lightTextPrimary,
        fontSize: 20,
      ),
      titleMedium: GoogleFonts.cairo(
        fontWeight: FontWeight.w600,
        color: lightTextPrimary,
        fontSize: 18,
      ),
      bodyLarge: GoogleFonts.cairo(
        fontWeight: FontWeight.w500,
        color: lightTextPrimary,
        fontSize: 16,
      ),
      bodyMedium: GoogleFonts.cairo(
        fontWeight: FontWeight.w400,
        color: lightTextSecondary,
        fontSize: 14,
      ),
      labelLarge: GoogleFonts.cairo(
        fontWeight: FontWeight.w600,
        color: lightTextPrimary,
        fontSize: 15,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      fillColor: lightSurface,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: navy, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error),
      ),
      labelStyle: GoogleFonts.cairo(color: lightTextPrimary),
      hintStyle: GoogleFonts.cairo(color: lightTextMuted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: navy,
        foregroundColor: cream,
        textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: navy,
        foregroundColor: cream,
        textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 15),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: GoogleFonts.cairo().fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: navy,
      brightness: Brightness.dark,
      primary: darkPrimary,
      secondary: darkSecondary,
      tertiary: amber,
      surface: darkSurface,
      surfaceContainerHighest: darkSurfaceAlt,
      outline: darkBorder,
    ),
    scaffoldBackgroundColor: darkBackground,
    canvasColor: darkSurface,
    cardColor: darkSurface,
    dividerColor: darkBorder,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: darkSurface,
      foregroundColor: darkTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: darkSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: darkBorder, width: 1),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    chipTheme: ChipThemeData(
      side: const BorderSide(color: darkBorder),
      selectedColor: darkPrimary.withValues(alpha: 0.25),
      backgroundColor: darkSurfaceAlt,
      labelStyle: GoogleFonts.cairo(color: darkTextPrimary),
      secondaryLabelStyle: GoogleFonts.cairo(color: darkTextPrimary),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    textTheme:
        GoogleFonts.cairoTextTheme(
          ThemeData(brightness: Brightness.dark).textTheme,
        ).copyWith(
          displayLarge: GoogleFonts.cairo(
            fontWeight: FontWeight.w700,
            color: darkTextPrimary,
            fontSize: 32,
          ),
          headlineLarge: GoogleFonts.cairo(
            fontWeight: FontWeight.w700,
            color: darkTextPrimary,
            fontSize: 28,
          ),
          headlineMedium: GoogleFonts.cairo(
            fontWeight: FontWeight.w700,
            color: darkTextPrimary,
            fontSize: 24,
          ),
          titleLarge: GoogleFonts.cairo(
            fontWeight: FontWeight.w700,
            color: darkTextPrimary,
            fontSize: 20,
          ),
          titleMedium: GoogleFonts.cairo(
            fontWeight: FontWeight.w600,
            color: darkTextPrimary,
            fontSize: 18,
          ),
          bodyLarge: GoogleFonts.cairo(
            fontWeight: FontWeight.w500,
            color: darkTextPrimary,
            fontSize: 16,
          ),
          bodyMedium: GoogleFonts.cairo(
            fontWeight: FontWeight.w400,
            color: darkTextSecondary,
            fontSize: 14,
          ),
          labelLarge: GoogleFonts.cairo(
            fontWeight: FontWeight.w600,
            color: darkTextPrimary,
            fontSize: 15,
          ),
        ),
    inputDecorationTheme: InputDecorationTheme(
      fillColor: darkSurface,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: darkPrimary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error),
      ),
      labelStyle: GoogleFonts.cairo(color: darkTextPrimary),
      hintStyle: GoogleFonts.cairo(color: darkTextMuted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: darkPrimary,
        foregroundColor: darkTextPrimary,
        textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: darkPrimary,
        foregroundColor: darkTextPrimary,
        textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 15),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
