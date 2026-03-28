import 'dart:ui';
import 'package:flutter/material.dart';
import 'dark_mode_toggle.dart';

class TopAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;

  const TopAppBar({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  Size get preferredSize => const Size.fromHeight(78);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: AppBar(
          backgroundColor: const Color(0xFF131313).withOpacity(0.6),
          elevation: 0,
          toolbarHeight: 78,
          titleSpacing: 12,
          title: Row(
            children: [
              const CircleAvatar(
                radius: 17,
                backgroundColor: Colors.grey,
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
            IconButton(
              constraints: const BoxConstraints.tightFor(width: 38, height: 38),
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.notifications_none,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
              onPressed: () {},
            ),
            const SizedBox(width: 2),
          ],
        ),
      ),
    );
  }
}
