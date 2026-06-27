import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/workout_log_models.dart';
import '../../providers/workout_log_provider.dart';
import '../../services/entitlement_service.dart';
import '../../theme/app_theme.dart';
import '../premium/paywall_screen.dart';

class WorkoutHistoryScreen extends StatelessWidget {
  const WorkoutHistoryScreen({super.key});

  String _formatWeight(double kg) {
    if (kg <= 0) return 'bodyweight';
    final rounded = (kg * 10).round() / 10;
    return rounded % 1 == 0 ? '${rounded.toInt()}kg' : '${rounded}kg';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final logProvider = context.watch<WorkoutLogProvider>();
    // Full history + progression charts are a Pro feature.
    final isPremium = context.watch<EntitlementService>().hasPro;
    final summaries = logProvider.summaries();

    if (summaries.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workout Log')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.fitness_center_rounded,
                  size: 48,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                const Text(
                  'No sets logged yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Log your reps and weight during a workout to build a history and unlock progression charts.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Workout Log')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: summaries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final s = summaries[index];
          final last = s.lastSessionSets;
          final lastText = last.isEmpty
              ? '—'
              : '${last.length}×${last.first.reps} @ ${_formatWeight(last.first.weightKg)}';

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.exerciseName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip('Last: $lastText'),
                    if (s.bestWeightKg > 0)
                      _chip('PR ${_formatWeight(s.bestWeightKg)}'),
                    if (s.bestOneRepMax > 0)
                      _chip('Est. 1RM ${_formatWeight(s.bestOneRepMax)}'),
                    _chip('${s.totalSets} sets'),
                  ],
                ),
                if (s.series.length >= 2) ...[
                  const SizedBox(height: 16),
                  _ProgressChartSection(
                    series: s.series,
                    isPremium: isPremium,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryContainer.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryContainer,
        ),
      ),
    );
  }
}

class _ProgressChartSection extends StatelessWidget {
  final List<ExerciseSessionPoint> series;
  final bool isPremium;

  const _ProgressChartSection({required this.series, required this.isPremium});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final chart = SizedBox(height: 120, child: _buildChart(context));

    if (isPremium) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EST. 1RM PROGRESSION',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          chart,
        ],
      );
    }

    // Free users see a blurred teaser with an upgrade CTA.
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          Opacity(opacity: 0.25, child: chart),
          Positioned.fill(
            child: Container(
              color: colorScheme.surface.withValues(alpha: 0.35),
              alignment: Alignment.center,
              child: FilledButton.tonalIcon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PaywallScreen(),
                  ),
                ),
                icon: const Icon(Icons.lock_outline_rounded, size: 18),
                label: const Text('Unlock progression charts'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context) {
    final spots = <FlSpot>[
      for (var i = 0; i < series.length; i++)
        FlSpot(i.toDouble(), series[i].bestOneRepMax),
    ];
    final values = series.map((p) => p.bestOneRepMax).toList();
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final pad = ((maxY - minY) * 0.2).clamp(1.0, 50.0);

    return LineChart(
      LineChartData(
        minY: (minY - pad).clamp(0, double.infinity),
        maxY: maxY + pad,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppTheme.primaryContainer,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.primaryContainer.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
