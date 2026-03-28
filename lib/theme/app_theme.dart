import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryContainer = Color(0xFF1A56DB);
  static const Color secondary = Color(0xFFFFB690);
  static const Color secondaryContainer = Color(0xFFEC6A06);
  static const Color tertiary = Color(0xFF4EDEA3);

  static final TextTheme _textTheme = GoogleFonts.interTextTheme(
    const TextTheme(
      displayLarge: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 48,
        letterSpacing: -0.02 * 48,
      ),
      headlineMedium: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 26,
        letterSpacing: -0.01 * 26,
      ),
      titleLarge: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
      bodyMedium: TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
      labelSmall: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 11,
        letterSpacing: 2.2,
      ),
    ),
  );

  static ThemeData get darkTheme {
    final scheme = ColorScheme.fromSeed(
      brightness: Brightness.dark,
      seedColor: primaryContainer,
      primary: const Color(0xFFB5C4FF),
      secondary: secondary,
      tertiary: tertiary,
      surface: const Color(0xFF11141A),
    ).copyWith(
      primaryContainer: primaryContainer,
      secondaryContainer: secondaryContainer,
      tertiaryContainer: const Color(0xFF0D4C39),
      onSurface: const Color(0xFFE7EBF3),
      onSurfaceVariant: const Color(0xFFA7B0C0),
      outline: const Color(0xFF667085),
      outlineVariant: const Color(0xFF2A3140),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF0D1016),
      appBarTheme: const AppBarTheme(
        foregroundColor: Color(0xFFE7EBF3),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF151A22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        shadowColor: Color(0x66000000),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF171D27),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      dividerColor: const Color(0xFF252D39),
      textTheme: _textTheme.apply(
        bodyColor: const Color(0xFFE7EBF3),
        displayColor: const Color(0xFFE7EBF3),
      ),
    );
  }

  static ThemeData get lightTheme {
    final scheme = ColorScheme.fromSeed(
      brightness: Brightness.light,
      seedColor: primaryContainer,
      primary: primaryContainer,
      secondary: secondaryContainer,
      tertiary: const Color(0xFF129B68),
      surface: const Color(0xFFFFFBF3),
    ).copyWith(
      primaryContainer: const Color(0xFFD7E3FF),
      secondaryContainer: const Color(0xFFFFE0CC),
      tertiaryContainer: const Color(0xFFD4F7E8),
      onSurface: const Color(0xFF152033),
      onSurfaceVariant: const Color(0xFF5B6472),
      outline: const Color(0xFF97A3B6),
      outlineVariant: const Color(0xFFD7DFEA),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF7F1E6),
      appBarTheme: const AppBarTheme(
        foregroundColor: Color(0xFF152033),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFFFFCF7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        shadowColor: Color(0x140F172A),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFFFCF7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      dividerColor: const Color(0xFFE2D8C8),
      textTheme: _textTheme.apply(
        bodyColor: const Color(0xFF152033),
        displayColor: const Color(0xFF152033),
      ),
    );
  }
}
