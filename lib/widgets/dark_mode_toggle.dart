import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';

class DarkModeToggle extends StatelessWidget {
  const DarkModeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final colorScheme = Theme.of(context).colorScheme;
    final darkSurface = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        context.read<ThemeProvider>().toggleTheme();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: darkSurface
                  ? const Color(0xFF222A37).withOpacity(0.9)
                  : const Color(0xFFF4EBDC).withOpacity(0.96),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: darkSurface
                    ? colorScheme.outlineVariant.withValues(alpha: 0.9)
                    : const Color(0xFFE1D5C3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildToggleButton(
                  icon: Icons.dark_mode,
                  isActive: isDark,
                  colorScheme: colorScheme,
                ),
                _buildToggleButton(
                  icon: Icons.light_mode,
                  isActive: !isDark,
                  colorScheme: colorScheme,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton({required IconData icon, required bool isActive, required ColorScheme colorScheme}) {
    final darkSurface = colorScheme.brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.primaryContainer
            : (darkSurface ? const Color(0x00000000) : const Color(0xFFF9F4EA)),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 20,
        color: isActive ? Colors.white : colorScheme.onSurfaceVariant,
      ),
    );
  }
}
