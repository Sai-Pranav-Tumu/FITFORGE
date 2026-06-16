import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Brand palette ──────────────────────────────────────────────────────────
  // One hero accent (indigo → violet) carries the brand. Emerald is reserved
  // for success/positive states, amber is a rare warm highlight. Everything
  // else leans on neutral slate tones for a calm, premium feel.
  static const Color brandIndigo = Color(0xFF5468FF);
  static const Color brandViolet = Color(0xFF8B5CF6);
  static const Color success = Color(0xFF22D39A);
  static const Color warning = Color(0xFFF5A524);

  // Back-compat semantic names (used across the app):
  // - primaryContainer → hero accent (CTAs, key numbers, active state)
  // - secondary        → violet, the hero gradient partner
  // - secondaryContainer → amber, rare warm highlight
  // - tertiary         → emerald, success / positive
  static const Color primaryContainer = brandIndigo;
  static const Color secondary = brandViolet;
  static const Color secondaryContainer = warning;
  static const Color tertiary = success;

  /// Premium hero gradient for primary buttons, badges and feature cards.
  static const LinearGradient heroGradient = LinearGradient(
    colors: [brandIndigo, brandViolet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

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
      seedColor: brandIndigo,
      primary: const Color(0xFFB7C0FF),
      secondary: secondary,
      tertiary: tertiary,
      surface: const Color(0xFF101319),
    ).copyWith(
      primaryContainer: primaryContainer,
      onPrimaryContainer: Colors.white,
      secondaryContainer: const Color(0xFF3A2A06),
      onSecondaryContainer: const Color(0xFFFFD79A),
      tertiaryContainer: const Color(0xFF0C4A39),
      surfaceContainerLowest: const Color(0xFF0B0E14),
      surfaceContainerLow: const Color(0xFF141823),
      surfaceContainer: const Color(0xFF181D29),
      surfaceContainerHigh: const Color(0xFF1F2533),
      surfaceContainerHighest: const Color(0xFF272E3E),
      onSurface: const Color(0xFFE9EDF6),
      onSurfaceVariant: const Color(0xFF9AA4B8),
      outline: const Color(0xFF5C667B),
      outlineVariant: const Color(0xFF2A3140),
    );

    return _buildTheme(
      scheme: scheme,
      scaffold: const Color(0xFF0A0D13),
      cardColor: const Color(0xFF161B25),
      inputFill: const Color(0xFF171D27),
      divider: const Color(0xFF232B38),
      textColor: const Color(0xFFE9EDF6),
      shadow: const Color(0x66000000),
    );
  }

  static ThemeData get lightTheme {
    final scheme = ColorScheme.fromSeed(
      brightness: Brightness.light,
      seedColor: brandIndigo,
      primary: brandIndigo,
      secondary: secondary,
      tertiary: const Color(0xFF0FA980),
      surface: const Color(0xFFFFFFFF),
    ).copyWith(
      primaryContainer: const Color(0xFFE2E5FF),
      onPrimaryContainer: const Color(0xFF1B1F5C),
      secondaryContainer: const Color(0xFFFFEBCB),
      onSecondaryContainer: const Color(0xFF6B4400),
      tertiaryContainer: const Color(0xFFCFF6E8),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF7F9FE),
      surfaceContainer: const Color(0xFFF1F4FB),
      surfaceContainerHigh: const Color(0xFFEAEEF7),
      surfaceContainerHighest: const Color(0xFFE3E9F4),
      onSurface: const Color(0xFF111726),
      onSurfaceVariant: const Color(0xFF5A6478),
      outline: const Color(0xFF98A2B6),
      outlineVariant: const Color(0xFFDDE3EE),
    );

    return _buildTheme(
      scheme: scheme,
      scaffold: const Color(0xFFF4F6FC),
      cardColor: Colors.white,
      inputFill: const Color(0xFFF1F4FB),
      divider: const Color(0xFFE4E9F2),
      textColor: const Color(0xFF111726),
      shadow: const Color(0x14101A33),
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme scheme,
    required Color scaffold,
    required Color cardColor,
    required Color inputFill,
    required Color divider,
    required Color textColor,
    required Color shadow,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      appBarTheme: AppBarTheme(foregroundColor: textColor),
      cardTheme: CardThemeData(
        color: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        shadowColor: shadow,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryContainer,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      dividerColor: divider,
      textTheme: _textTheme.apply(bodyColor: textColor, displayColor: textColor),
    );
  }
}
