import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [
                    Color(0xF01A202C),
                    Color(0xE8171D28),
                  ]
                : const [
                    Color(0xF9FFFDF8),
                    Color(0xF2FFF6E7),
                  ],
          ),
          borderRadius: BorderRadius.circular(29),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.92),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? const Color(0x7A000000)
                  : AppTheme.primaryContainer.withValues(alpha: 0.12),
              blurRadius: isDark ? 28 : 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          child: Row(
            children: [
              _NavItem(
                icon: Icons.fitness_center_rounded,
                label: 'WORKOUT',
                isSelected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.pie_chart_outline_rounded,
                label: 'CALORIES',
                isSelected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                label: 'PROFILE',
                isSelected: currentIndex == 2,
                onTap: () => onTap(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? const [
              Color(0xFF2F7BFF),
              Color(0xFF174ACD),
            ]
          : const [
              Color(0xFF2A78FF),
              Color(0xFF1A56DB),
            ],
    );

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: isSelected ? 1 : 0.97,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 5.5),
            padding: EdgeInsets.symmetric(
              horizontal: isSelected ? 15 : 13,
              vertical: 11.5,
            ),
            decoration: BoxDecoration(
              gradient: isSelected ? selectedGradient : null,
              color: isSelected
                  ? null
                  : colorScheme.surface.withValues(alpha: isDark ? 0.16 : 0.82),
              borderRadius: BorderRadius.circular(23),
              border: Border.all(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.14)
                    : colorScheme.outlineVariant.withValues(alpha: 0.45),
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryContainer.withValues(alpha: 0.28),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: isSelected ? 19.5 : 18.5,
                  color: isSelected
                      ? Colors.white
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 7.5),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isSelected
                            ? Colors.white
                            : colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.92,
                              ),
                        fontSize: 10.25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
