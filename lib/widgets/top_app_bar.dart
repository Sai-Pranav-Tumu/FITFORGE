import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dark_mode_toggle.dart';
import '../providers/user_provider.dart';
import '../providers/water_provider.dart';

class TopAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final bool showNotificationButton;

  const TopAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.showNotificationButton = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(78);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = context.watch<UserProvider>().userProfile;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topBarColor = isDark
        ? const Color(0xCC141A24)
        : const Color(0xF2FFF8EA);

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: AppBar(
          backgroundColor: topBarColor,
          elevation: 0,
          toolbarHeight: 78,
          titleSpacing: 12,
          shape: Border(
            bottom: BorderSide(
              color: isDark
                  ? colorScheme.outlineVariant.withValues(alpha: 0.55)
                  : const Color(0xFFE6DBC9),
            ),
          ),
          title: Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: _avatarColor(user?.avatarKey),
                child: Icon(
                  _avatarIcon(user?.avatarKey),
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            color: colorScheme.primary,
                          ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.15,
                              fontSize: 10.5,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          actions: [
            Transform.scale(
              scale: 0.82,
              child: const DarkModeToggle(),
            ),
            if (showNotificationButton)
              IconButton(
                constraints: const BoxConstraints.tightFor(width: 38, height: 38),
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.notifications_none,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                onPressed: () => _openNotificationSheet(context),
              ),
            const SizedBox(width: 2),
          ],
        ),
      ),
    );
  }

  Future<void> _openNotificationSheet(BuildContext context) async {
    final waterProvider = context.read<WaterProvider>();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Consumer<WaterProvider>(
          builder: (context, water, _) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notification Settings',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Hydration reminders are personalized around your last water log.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Drink water reminders',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Switch(
                          value: water.remindersEnabled,
                          onChanged: waterProvider.setRemindersEnabled,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Reminder interval',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [60, 90, 120].map((minutes) {
                        final selected = water.reminderIntervalMinutes == minutes;
                        return ChoiceChip(
                          label: Text('$minutes min'),
                          selected: selected,
                          onSelected: (_) => waterProvider.setReminderIntervalMinutes(minutes),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _avatarIcon(String? avatarKey) {
    switch (avatarKey) {
      case 'run':
        return Icons.directions_run;
      case 'strength':
        return Icons.fitness_center;
      case 'yoga':
        return Icons.self_improvement;
      case 'cycle':
        return Icons.pedal_bike;
      default:
        return Icons.person;
    }
  }

  Color _avatarColor(String? avatarKey) {
    switch (avatarKey) {
      case 'run':
        return const Color(0xFF4E8DFF);
      case 'strength':
        return const Color(0xFFFF6B4A);
      case 'yoga':
        return const Color(0xFF2BB673);
      case 'cycle':
        return const Color(0xFF8B5CF6);
      default:
        return Colors.grey;
    }
  }
}
