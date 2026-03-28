import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/nutrition_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/nutrition_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dark_mode_toggle.dart';
import '../../widgets/top_app_bar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final NutritionService _nutritionService = NutritionService.instance;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = context.watch<UserProvider>().userProfile;

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: const TopAppBar(title: 'Profile Settings'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 16, bottom: 120),
        child: Column(
          children: [
            Center(
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryContainer,
                              AppTheme.tertiary,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const CircleAvatar(
                          radius: 44,
                          backgroundColor: Colors.grey,
                        ),
                      ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryContainer,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colorScheme.surface,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    (user?.name.trim().isNotEmpty ?? false)
                        ? user!.name
                        : 'FitForge User',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer.withValues(alpha: 0.2),
                      border: Border.all(
                        color: AppTheme.primaryContainer.withValues(alpha: 0.2),
                      ),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      (user?.fitnessGoal ?? 'Stay Active').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryContainer,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: _buildStatCard(context, 'WORKOUTS', '24')),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'STREAK',
                      '${user?.streak ?? 0}',
                      icon: const Icon(
                        Icons.local_fire_department,
                        color: AppTheme.secondary,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'WEIGHT',
                      '${user?.weight.toStringAsFixed(1) ?? '0.0'} kg',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildMonthlyNutritionCard(context, colorScheme),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildSettingsBlock(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyNutritionCard(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    final nutritionProvider = context.watch<NutritionProvider>();
    final summary = nutritionProvider.monthlySummary;
    if (nutritionProvider.isLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (nutritionProvider.error != null || summary == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          nutritionProvider.error ??
              'Nutrition chart will appear after logging food.',
        ),
      );
    }
    final calories = summary.caloriesPercent.clamp(0, 100);
    final protein = summary.proteinPercent.clamp(0, 100);
    final vitamins = summary.vitaminsPercent.clamp(0, 100);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LIVE NUTRITION TRACKER',
            style: TextStyle(
              fontSize: 10,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              IconButton(
                onPressed: () =>
                    context.read<NutritionProvider>().goToPreviousMonth(),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    _monthLabel(summary.month),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: nutritionProvider.canGoNextMonth
                    ? () => context.read<NutritionProvider>().goToNextMonth()
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 54,
                sectionsSpace: 4,
                sections: [
                  _metricSlice(
                    'Calories',
                    calories.toDouble(),
                    AppTheme.primaryContainer,
                  ),
                  _metricSlice(
                    'Protein',
                    protein.toDouble(),
                    AppTheme.secondaryContainer,
                  ),
                  _metricSlice(
                    'Vitamins',
                    vitamins.toDouble(),
                    AppTheme.tertiary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _legendRow(
            'Calories',
            calories.toDouble(),
            AppTheme.primaryContainer,
          ),
          const SizedBox(height: 4),
          _legendRow(
            'Protein',
            protein.toDouble(),
            AppTheme.secondaryContainer,
          ),
          const SizedBox(height: 4),
          _legendRow('Vitamins', vitamins.toDouble(), AppTheme.tertiary),
          const SizedBox(height: 12),
          if (summary.gaps.isNotEmpty) ...[
            const Text(
              'Deficiency Suggestions',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...summary.gaps.take(3).map((gap) {
              final suggestions = gap.suggestions
                  .take(2)
                  .map((f) => f.foodName)
                  .join(', ');
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${_nutritionService.displayName(gap.nutrient)} ${gap.percent.toStringAsFixed(0)}% of target. Include: $suggestions',
                ),
              );
            }),
          ] else
            const Text(
              'You met your monthly nutrition targets. Keep this streak going.',
            ),
        ],
      ),
    );
  }

  PieChartSectionData _metricSlice(String label, double value, Color color) {
    return PieChartSectionData(
      color: color,
      value: value <= 0 ? 0.001 : value,
      title: '${value.toStringAsFixed(0)}%',
      titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      radius: 42,
      badgeWidget: null,
      showTitle: true,
    );
  }

  Widget _legendRow(String label, double value, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        Text('${value.toStringAsFixed(1)}%'),
      ],
    );
  }

  Widget _buildSettingsBlock(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ACCOUNT SETTINGS',
          style: TextStyle(
            fontSize: 10,
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildSettingsRow(
                context,
                Icons.person,
                'Edit Profile',
                trailing: const Icon(Icons.chevron_right, size: 20),
              ),
              const SizedBox(height: 24),
              _buildSettingsRow(
                context,
                Icons.notifications,
                'Notifications',
                trailing: Switch(
                  value: true,
                  onChanged: (_) {},
                  activeThumbColor: AppTheme.primaryContainer,
                ),
              ),
              const SizedBox(height: 24),
              _buildSettingsRow(
                context,
                Icons.dark_mode,
                'Dark Mode',
                trailing: const DarkModeToggle(),
              ),
              const SizedBox(height: 24),
              _buildSettingsRow(
                context,
                Icons.straighten,
                'Units (kg/cm)',
                trailing: const Text(
                  'CHANGE',
                  style: TextStyle(
                    color: AppTheme.primaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value, {
    Icon? icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (icon != null) ...[const SizedBox(width: 4), icon],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsRow(
    BuildContext context,
    IconData icon,
    String label, {
    required Widget trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: colorScheme.onSurfaceVariant, size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        trailing,
      ],
    );
  }

  String _monthLabel(DateTime month) {
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[month.month - 1]} ${month.year}';
  }
}
