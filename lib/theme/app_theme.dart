import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryContainer = Color(0xFF1A56DB);
  static const Color secondary = Color(0xFFFFB690);
  static const Color secondaryContainer = Color(0xFFEC6A06);
  static const Color tertiary = Color(0xFF4EDEA3);

  static final TextTheme _textTheme = GoogleFonts.interTextTheme(
    const TextTheme(
      displayLarge: TextStyle(fontWeight: FontWeight.bold, fontSize: 48, letterSpacing: -0.02 * 48),
      headlineMedium: TextStyle(fontWeight: FontWeight.bold, fontSize: 26, letterSpacing: -0.01 * 26),
      titleLarge: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
      bodyMedium: TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
      labelSmall: TextStyle(fontWeight: FontWeight.w500, fontSize: 11, letterSpacing: 2.2),
    ),
  );

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        surface: Color(0xFF131313),
        primary: Color(0xFFB5C4FF),
        primaryContainer: Color(0xFF1A56DB),
        onPrimary: Color(0xFF00297A),
        onPrimaryContainer: Color(0xFFD4DCFF),
        secondary: Color(0xFFFFB690),
        secondaryContainer: Color(0xFFEC6A06),
        tertiary: Color(0xFF4EDEA3),
        tertiaryContainer: Color(0xFF006F4B),
        onSurface: Color(0xFFE5E2E1),
        onSurfaceVariant: Color(0xFFC3C5D7),
        outline: Color(0xFF8D90A0),
        outlineVariant: Color(0xFF434654),
        error: Color(0xFFFFB4AB),
        
        // Exposing extended surface colors as surface colors dynamically
        // Using bottom sheet bg instead of surfaceContainerLowest everywhere?
        // Flutter 3.1x introduced surfaceContainer... properties in ColorScheme in some versions, 
        // if they are missing, we can implement them via extensions. Because we are on Flutter 3.29, they are supported natively.
      ),
      scaffoldBackgroundColor: const Color(0xFF131313),
      textTheme: _textTheme.apply(bodyColor: const Color(0xFFE5E2E1), displayColor: const Color(0xFFE5E2E1)),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        surface: Color(0xFFFFFFFF),
        primary: Color(0xFF1A56DB),
        primaryContainer: Color(0xFFDBE1FF),
        onPrimary: Color(0xFFFFFFFF),
        onPrimaryContainer: Color(0xFF001257),
        onSurface: Color(0xFF111827),
        onSurfaceVariant: Color(0xFF6B7280),
        outline: Color(0xFF9CA3AF),
      ),
      scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      textTheme: _textTheme.apply(bodyColor: const Color(0xFF111827), displayColor: const Color(0xFF111827)),
    );
  }
}
