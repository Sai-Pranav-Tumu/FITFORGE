import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
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
                      InkWell(
                        onTap: () => _showAvatarPicker(context),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
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
                          child: CircleAvatar(
                            radius: 44,
                            backgroundColor: _avatarColor(user?.avatarKey),
                            child: Icon(
                              _avatarIcon(user?.avatarKey),
                              color: Colors.white,
                              size: 38,
                            ),
                          ),
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
                      _displayWeight(user),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'HEIGHT',
                      _displayHeight(user),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'BMI',
                      _bmiLabel(user?.weight ?? 0, user?.height ?? 170),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'GOAL',
                      _goalShortLabel(user?.fitnessGoal ?? ''),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.restaurant_menu_rounded,
                      color: AppTheme.primaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Diet Preference',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _dietaryPreferenceLabel(user?.dietaryPreference ?? 'any'),
                            style: TextStyle(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showDietPreferenceSheet(context),
                      child: const Text('Change'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.sports_gymnastics_rounded,
                          color: AppTheme.secondaryContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Workout Preferences',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${user?.trainingLevel ?? 'Beginner'} · ${user?.workoutLocation ?? 'Home'} · ${user?.sessionDurationMinutes ?? 30} min',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _showWorkoutPreferencesSheet(context),
                          child: const Text('Change'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _smallChip(user?.availableEquipment ?? 'Bodyweight'),
                          _smallChip(user?.targetMuscleFocus ?? 'Full Body'),
                          _smallChip(
                            (user?.jointSensitivity ?? 'None') == 'None'
                                ? 'No joint limits'
                                : '${user?.jointSensitivity} care',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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

  String _bmiLabel(double weightKg, double heightCm) {
    if (weightKg <= 0 || heightCm <= 0) return '--';
    final heightM = heightCm / 100.0;
    final bmi = weightKg / (heightM * heightM);
    return bmi.toStringAsFixed(1);
  }

  String _goalShortLabel(String goal) {
    if (goal.trim().isEmpty) return '--';
    if (goal == 'Lose Weight') return 'Cut';
    if (goal == 'Gain Muscle') return 'Bulk';
    if (goal == 'Improve Stamina') return 'Endure';
    return 'Active';
  }

  String _dietaryPreferenceLabel(String preference) {
    switch (preference) {
      case 'veg':
        return 'Vegetarian';
      case 'nonveg':
        return 'Non-Vegetarian';
      default:
        return 'No filter';
    }
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
                onTap: () => _showEditProfileDialog(context),
                trailing: const Icon(Icons.chevron_right, size: 20),
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
                'Units',
                onTap: () => _showUnitsSheet(context),
                trailing: Text(
                  userUnitsLabel(context),
                  style: const TextStyle(
                    color: AppTheme.primaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildSettingsRow(
                context,
                Icons.logout,
                'Logout',
                onTap: () async {
                  await context.read<AuthProvider>().signOut();
                },
                trailing: const Icon(Icons.chevron_right, size: 20),
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
    VoidCallback? onTap,
    required Widget trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
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
        ),
      ),
    );
  }

  Widget _smallChip(String label) {
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

  String userUnitsLabel(BuildContext context) {
    final units = context.watch<UserProvider>().userProfile?.preferredUnits ?? 'metric';
    return units == 'imperial' ? 'LB/FT' : 'KG/CM';
  }

  String _displayWeight(user) {
    final weight = user?.weight ?? 0.0;
    final units = user?.preferredUnits ?? 'metric';
    if (units == 'imperial') {
      return '${(weight * 2.20462).toStringAsFixed(1)} lb';
    }
    return '${weight.toStringAsFixed(1)} kg';
  }

  String _displayHeight(user) {
    final height = user?.height ?? 170.0;
    final units = user?.preferredUnits ?? 'metric';
    if (units == 'imperial') {
      final totalInches = height / 2.54;
      final feet = totalInches ~/ 12;
      final inches = (totalInches - (feet * 12)).round();
      return '$feet\'$inches"';
    }
    return '${height.toStringAsFixed(0)} cm';
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

  Future<void> _showUnitsSheet(BuildContext context) async {
    final user = context.read<UserProvider>().userProfile;
    if (user == null) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose Units',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                ListTile(
                  title: const Text('Metric (kg/cm)'),
                  trailing: user.preferredUnits == 'metric'
                      ? const Icon(Icons.check, color: AppTheme.primaryContainer)
                      : null,
                  onTap: () async {
                    await context.read<UserProvider>().updateProfile(
                      user.copyWith(preferredUnits: 'metric'),
                    );
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  title: const Text('Imperial (lb/ft)'),
                  trailing: user.preferredUnits == 'imperial'
                      ? const Icon(Icons.check, color: AppTheme.primaryContainer)
                      : null,
                  onTap: () async {
                    await context.read<UserProvider>().updateProfile(
                      user.copyWith(preferredUnits: 'imperial'),
                    );
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDietPreferenceSheet(BuildContext context) async {
    final user = context.read<UserProvider>().userProfile;
    if (user == null) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Diet Preference',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                ...[
                  ('any', 'No filter'),
                  ('veg', 'Vegetarian'),
                  ('nonveg', 'Non-Vegetarian'),
                ].map((option) {
                  final selected = user.dietaryPreference == option.$1;
                  return ListTile(
                    title: Text(option.$2),
                    trailing: selected
                        ? const Icon(Icons.check, color: AppTheme.primaryContainer)
                        : null,
                    onTap: () async {
                      await context.read<UserProvider>().updateProfile(
                        user.copyWith(dietaryPreference: option.$1),
                      );
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAvatarPicker(BuildContext context) async {
    final user = context.read<UserProvider>().userProfile;
    if (user == null) return;
    const avatars = <String>['person', 'run', 'strength', 'yoga', 'cycle'];

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose Profile Picture',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: avatars.map((avatar) {
                    final selected = user.avatarKey == avatar;
                    return InkWell(
                      onTap: () async {
                        await context.read<UserProvider>().updateProfile(
                          user.copyWith(avatarKey: avatar),
                        );
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      borderRadius: BorderRadius.circular(999),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: _avatarColor(avatar),
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Icon(_avatarIcon(avatar), color: Colors.white),
                            if (selected)
                              const Icon(
                                Icons.check_circle,
                                size: 16,
                                color: Colors.white,
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showWorkoutPreferencesSheet(BuildContext context) async {
    final user = context.read<UserProvider>().userProfile;
    if (user == null) return;

    var trainingLevel = user.trainingLevel;
    var workoutLocation = user.workoutLocation;
    var availableEquipment = user.availableEquipment;
    var sessionDurationMinutes = user.sessionDurationMinutes;
    var targetMuscleFocus = user.targetMuscleFocus;
    var jointSensitivity = user.jointSensitivity;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget choiceGroup(
              String title,
              List<String> options,
              String selected,
              ValueChanged<String> onSelected,
            ) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: options.map((option) {
                      final isSelected = option == selected;
                      return ChoiceChip(
                        label: Text(option),
                        selected: isSelected,
                        onSelected: (_) => onSelected(option),
                      );
                    }).toList(),
                  ),
                ],
              );
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  20 + MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Workout Preferences',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 18),
                      choiceGroup(
                        'Training Level',
                        const ['Beginner', 'Intermediate', 'Advanced'],
                        trainingLevel,
                        (value) => setModalState(() => trainingLevel = value),
                      ),
                      const SizedBox(height: 16),
                      choiceGroup(
                        'Workout Location',
                        const ['Home', 'Gym', 'Hybrid'],
                        workoutLocation,
                        (value) => setModalState(() => workoutLocation = value),
                      ),
                      const SizedBox(height: 16),
                      choiceGroup(
                        'Equipment',
                        const ['Bodyweight', 'Bands & Dumbbells', 'Full Gym'],
                        availableEquipment,
                        (value) => setModalState(() => availableEquipment = value),
                      ),
                      const SizedBox(height: 16),
                      choiceGroup(
                        'Session Length',
                        const ['20', '30', '45', '60'],
                        '$sessionDurationMinutes',
                        (value) => setModalState(
                          () => sessionDurationMinutes = int.parse(value),
                        ),
                      ),
                      const SizedBox(height: 16),
                      choiceGroup(
                        'Focus Area',
                        const [
                          'Full Body',
                          'Upper Body',
                          'Lower Body',
                          'Core',
                          'Back & Posture',
                        ],
                        targetMuscleFocus,
                        (value) => setModalState(() => targetMuscleFocus = value),
                      ),
                      const SizedBox(height: 16),
                      choiceGroup(
                        'Joint Care',
                        const ['None', 'Knees', 'Lower Back', 'Shoulders'],
                        jointSensitivity,
                        (value) => setModalState(() => jointSensitivity = value),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            await context.read<UserProvider>().updateProfile(
                                  user.copyWith(
                                    trainingLevel: trainingLevel,
                                    workoutLocation: workoutLocation,
                                    availableEquipment: availableEquipment,
                                    sessionDurationMinutes: sessionDurationMinutes,
                                    targetMuscleFocus: targetMuscleFocus,
                                    jointSensitivity: jointSensitivity,
                                  ),
                                );
                            if (sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                            }
                          },
                          child: const Text('Save Workout Preferences'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showEditProfileDialog(BuildContext context) async {
    final user = context.read<UserProvider>().userProfile;
    if (user == null) return;

    final nameController = TextEditingController(text: user.name);
    final ageController = TextEditingController(text: user.age.toString());
    final heightController = TextEditingController(
      text: user.height.toStringAsFixed(0),
    );
    final weightController = TextEditingController(
      text: user.weight.toStringAsFixed(1),
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Age'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: heightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Height (cm)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Weight (kg)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final updated = user.copyWith(
                  name: nameController.text.trim().isEmpty
                      ? user.name
                      : nameController.text.trim(),
                  age: int.tryParse(ageController.text.trim()) ?? user.age,
                  height:
                      double.tryParse(heightController.text.trim()) ?? user.height,
                  weight:
                      double.tryParse(weightController.text.trim()) ?? user.weight,
                );
                await context.read<UserProvider>().updateProfile(updated);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
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
