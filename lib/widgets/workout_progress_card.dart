import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../theme/app_theme.dart';

/// A compact "Your Progress" card: current streak, total workouts, and a small
/// bar chart of workouts completed per week over the last 6 weeks. Reads only
/// the user's completed-workout dates so it's always populated.
class WorkoutProgressCard extends StatelessWidget {
  const WorkoutProgressCard({super.key, required this.profile});

  final UserModel profile;

  static const int _weeks = 6;

  List<int> _weeklyCounts() {
    final counts = List<int>.filled(_weeks, 0);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final key in profile.workoutCompletionDates) {
      final d = DateTime.tryParse(key);
      if (d == null) continue;
      final day = DateTime(d.year, d.month, d.day);
      final diff = today.difference(day).inDays;
      if (diff < 0) continue;
      final w = diff ~/ 7; // 0 = this week
      if (w < _weeks) counts[_weeks - 1 - w]++;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final counts = _weeklyCounts();
    final total = profile.completedWorkoutCount;
    final maxCount = counts.fold<int>(0, (m, c) => c > m ? c : m);
    final maxY = (maxCount + 1).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Your Progress',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              _StatPill(
                icon: Icons.local_fire_department_rounded,
                color: AppTheme.secondaryContainer,
                label: '${profile.streak}d streak',
              ),
              const SizedBox(width: 8),
              _StatPill(
                icon: Icons.fitness_center_rounded,
                color: AppTheme.primaryContainer,
                label: '$total done',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Workouts completed per week',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 120,
            child: total == 0
                ? Center(
                    child: Text(
                      'Complete your first workout to start tracking progress.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12.5,
                      ),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY,
                      minY: 0,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              final weeksAgo = _weeks - 1 - i;
                              final label = weeksAgo == 0 ? 'This' : '${weeksAgo}w';
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < counts.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: counts[i].toDouble(),
                                width: 16,
                                borderRadius: BorderRadius.circular(6),
                                gradient: i == counts.length - 1
                                    ? AppTheme.heroGradient
                                    : null,
                                color: i == counts.length - 1
                                    ? null
                                    : AppTheme.primaryContainer.withValues(
                                        alpha: 0.35,
                                      ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
