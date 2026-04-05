import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/nutrition_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/workout_provider.dart';
import '../../services/nutrition_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_error_card.dart';
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
        padding: const EdgeInsets.only(top: 16, bottom: 28),
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
                            _dietaryPreferenceLabel(
                              user?.dietaryPreference ?? 'any',
                            ),
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
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
                          onPressed: () =>
                              _showWorkoutPreferencesSheet(context),
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
                          ..._focusAreaLabels(
                            user,
                          ).map((label) => _smallChip(label)),
                          ..._jointCareLabels(
                            user,
                          ).map((label) => _smallChip(label)),
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
                Icons.privacy_tip_outlined,
                'Privacy Policy',
                onTap: () => context.push('/privacy-policy'),
                trailing: const Icon(Icons.chevron_right, size: 20),
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
              const SizedBox(height: 24),
              _buildSettingsRow(
                context,
                Icons.delete_forever_rounded,
                'Delete Account',
                onTap: () => _showDeleteAccountDialog(context),
                trailing: Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: colorScheme.error,
                ),
                foregroundColor: colorScheme.error,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Deleting your account permanently removes your FitForge profile and clears your local meal history, diet plan, and hydration data from this device.',
          style: TextStyle(color: colorScheme.onSurfaceVariant, height: 1.45),
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
    Color? foregroundColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveColor = foregroundColor ?? colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: effectiveColor, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: foregroundColor,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();
    final needsPassword = authProvider.requiresPasswordForAccountDeletion;
    final passwordController = TextEditingController();

    final deletedAccount = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        var errorText = '';
        var deleting = false;
        var obscurePassword = true;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> submitDelete() async {
              final navigator = Navigator.of(dialogContext);
              final route = ModalRoute.of(dialogContext);
              var shouldResetDeleting = true;

              if (needsPassword && passwordController.text.isEmpty) {
                setDialogState(() {
                  errorText =
                      'Enter your current password to delete your account.';
                });
                return;
              }

              setDialogState(() {
                deleting = true;
                errorText = '';
              });

              try {
                await authProvider.deleteAccount(
                  currentPassword: needsPassword
                      ? passwordController.text
                      : null,
                );
                shouldResetDeleting = false;
                if (navigator.mounted && (route?.isCurrent ?? false)) {
                  navigator.pop(true);
                }
              } catch (error) {
                if (dialogContext.mounted) {
                  setDialogState(() {
                    errorText = formatAuthError(
                      error,
                      flow: AuthFlow.deleteAccount,
                    );
                  });
                }
              } finally {
                if (shouldResetDeleting && dialogContext.mounted) {
                  setDialogState(() => deleting = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('Delete Account'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This permanently deletes your FitForge account, synced profile, meal history on this device, saved diet plan, and hydration reminder data.',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This action cannot be undone.',
                      style: TextStyle(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (needsPassword) ...[
                      const SizedBox(height: 18),
                      TextField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        enabled: !deleting,
                        decoration: InputDecoration(
                          labelText: 'Current password',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: deleting
                                ? null
                                : () => setDialogState(
                                    () => obscurePassword = !obscurePassword,
                                  ),
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 18),
                      Text(
                        'We may ask you to confirm with Google before deletion finishes.',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (errorText.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        errorText,
                        style: TextStyle(color: colorScheme.error, height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: deleting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: deleting ? null : submitDelete,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    foregroundColor: colorScheme.onError,
                  ),
                  child: deleting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onError,
                          ),
                        )
                      : const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
    );

    passwordController.dispose();

    if (deletedAccount == true) {
      userProvider.clearProfile();
    }
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

  List<String> _focusAreaLabels(UserModel? user) {
    if (user == null) {
      return const <String>[UserModel.defaultTargetMuscleFocus];
    }
    return user.visibleFocusAreas;
  }

  List<String> _jointCareLabels(UserModel? user) {
    if (user == null || user.selectedJointCareAreas.isEmpty) {
      return const <String>['No joint limits'];
    }
    return user.selectedJointCareAreas
        .map((area) => '$area care')
        .toList(growable: false);
  }

  Set<String> _togglePreferenceSelection(
    Set<String> current,
    String value, {
    required String resetOption,
  }) {
    if (value == resetOption) {
      return <String>{resetOption};
    }

    final next = Set<String>.from(current)..remove(resetOption);
    if (!next.add(value)) {
      next.remove(value);
    }

    if (next.isEmpty) {
      next.add(resetOption);
    }

    return next;
  }

  String userUnitsLabel(BuildContext context) {
    final units =
        context.watch<UserProvider>().userProfile?.preferredUnits ?? 'metric';
    return units == 'imperial' ? 'LB/FT' : 'KG/CM';
  }

  String _displayWeight(UserModel? user) {
    final weight = user?.weight ?? 0.0;
    final units = user?.preferredUnits ?? 'metric';
    if (units == 'imperial') {
      return '${(weight * 2.20462).toStringAsFixed(1)} lb';
    }
    return '${weight.toStringAsFixed(1)} kg';
  }

  String _displayHeight(UserModel? user) {
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
                      ? const Icon(
                          Icons.check,
                          color: AppTheme.primaryContainer,
                        )
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
                      ? const Icon(
                          Icons.check,
                          color: AppTheme.primaryContainer,
                        )
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
                        ? const Icon(
                            Icons.check,
                            color: AppTheme.primaryContainer,
                          )
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
    var targetMuscleFocuses = user.targetMuscleFocuses.toSet();
    var jointSensitivities = user.jointSensitivities.toSet();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final cs = Theme.of(context).colorScheme;

            Widget choiceGroup(
              String title,
              String subtitle,
              IconData icon,
              Color accent,
              List<String> options,
              String selected,
              ValueChanged<String> onSelected,
            ) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: accent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: options.map((option) {
                        final isSelected = option == selected;
                        return ChoiceChip(
                          label: Text(option),
                          selected: isSelected,
                          showCheckmark: false,
                          avatar: isSelected
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: accent,
                                )
                              : null,
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? cs.onSurface
                                : cs.onSurfaceVariant,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? accent.withValues(alpha: 0.24)
                                : cs.outlineVariant.withValues(alpha: 0.2),
                          ),
                          backgroundColor: cs.surfaceContainerHighest,
                          selectedColor: accent.withValues(alpha: 0.12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          onSelected: (_) => onSelected(option),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }

            Widget multiChoiceGroup(
              String title,
              String subtitle,
              IconData icon,
              Color accent,
              List<String> options,
              Set<String> selectedValues,
              ValueChanged<String> onToggled,
            ) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: accent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'Selected: ${selectedValues.join(' · ')}',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: options.map((option) {
                        final isSelected = selectedValues.contains(option);
                        return FilterChip(
                          label: Text(option),
                          selected: isSelected,
                          showCheckmark: false,
                          avatar: isSelected
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: accent,
                                )
                              : null,
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? cs.onSurface
                                : cs.onSurfaceVariant,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? accent.withValues(alpha: 0.24)
                                : cs.outlineVariant.withValues(alpha: 0.2),
                          ),
                          backgroundColor: cs.surfaceContainerHighest,
                          selectedColor: accent.withValues(alpha: 0.12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          onSelected: (_) => onToggled(option),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }

            return SafeArea(
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          child: Container(
                            width: 48,
                            height: 5,
                            decoration: BoxDecoration(
                              color: cs.outlineVariant.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: AppTheme.secondaryContainer.withValues(
                                alpha: 0.16,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppTheme.secondaryContainer.withValues(
                                    alpha: 0.16,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.tune_rounded,
                                  color: AppTheme.secondaryContainer,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Workout Preferences',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Shape your plan so it feels realistic, balanced, and sustainable.',
                                      style: TextStyle(
                                        color: cs.onSurfaceVariant,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        choiceGroup(
                          'Training Level',
                          'We tune volume and intensity around this.',
                          Icons.leaderboard_rounded,
                          AppTheme.primaryContainer,
                          const ['Beginner', 'Intermediate', 'Advanced'],
                          trainingLevel,
                          (value) => setModalState(() => trainingLevel = value),
                        ),
                        const SizedBox(height: 14),
                        choiceGroup(
                          'Workout Location',
                          'Keeps the routine realistic for where you train.',
                          Icons.home_work_rounded,
                          AppTheme.tertiary,
                          const ['Home', 'Gym', 'Hybrid'],
                          workoutLocation,
                          (value) =>
                              setModalState(() => workoutLocation = value),
                        ),
                        const SizedBox(height: 14),
                        choiceGroup(
                          'Equipment',
                          'Avoids exercises you cannot actually set up.',
                          Icons.fitness_center_rounded,
                          AppTheme.secondaryContainer,
                          const ['Bodyweight', 'Bands & Dumbbells', 'Full Gym'],
                          availableEquipment,
                          (value) =>
                              setModalState(() => availableEquipment = value),
                        ),
                        const SizedBox(height: 14),
                        choiceGroup(
                          'Session Length',
                          'Matches workout density to your daily schedule.',
                          Icons.schedule_rounded,
                          AppTheme.primaryContainer,
                          const ['20', '30', '45', '60'],
                          '$sessionDurationMinutes',
                          (value) => setModalState(
                            () => sessionDurationMinutes = int.parse(value),
                          ),
                        ),
                        const SizedBox(height: 14),
                        multiChoiceGroup(
                          'Focus Area',
                          'Pick one or more body areas to emphasize together.',
                          Icons.center_focus_strong_rounded,
                          AppTheme.tertiary,
                          UserModel.targetMuscleFocusOptions,
                          targetMuscleFocuses,
                          (value) => setModalState(() {
                            targetMuscleFocuses = _togglePreferenceSelection(
                              targetMuscleFocuses,
                              value,
                              resetOption: UserModel.defaultTargetMuscleFocus,
                            );
                          }),
                        ),
                        const SizedBox(height: 14),
                        multiChoiceGroup(
                          'Joint Care',
                          'Select every area that needs extra care.',
                          Icons.accessibility_new_rounded,
                          AppTheme.secondaryContainer,
                          UserModel.jointSensitivityOptions,
                          jointSensitivities,
                          (value) => setModalState(() {
                            jointSensitivities = _togglePreferenceSelection(
                              jointSensitivities,
                              value,
                              resetOption: UserModel.defaultJointSensitivity,
                            );
                          }),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () async {
                              final userProvider = context.read<UserProvider>();
                              final workoutProvider = context
                                  .read<WorkoutProvider>();
                              final updatedProfile = user.copyWith(
                                trainingLevel: trainingLevel,
                                workoutLocation: workoutLocation,
                                availableEquipment: availableEquipment,
                                sessionDurationMinutes: sessionDurationMinutes,
                                targetMuscleFocuses: targetMuscleFocuses.toList(
                                  growable: false,
                                ),
                                jointSensitivities: jointSensitivities.toList(
                                  growable: false,
                                ),
                              );
                              await userProvider.updateProfile(updatedProfile);
                              await workoutProvider.refresh(
                                profile: updatedProfile,
                              );
                              if (sheetContext.mounted) {
                                Navigator.of(sheetContext).pop();
                              }
                            },
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Save Workout Preferences'),
                          ),
                        ),
                      ],
                    ),
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
        final cs = Theme.of(dialogContext).colorScheme;

        Widget profileField({
          required String label,
          required IconData icon,
          required TextEditingController controller,
          TextInputType? keyboardType,
        }) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  decoration: InputDecoration(
                    prefixIcon: Icon(icon, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryContainer.withValues(
                            alpha: 0.14,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.edit_note_rounded,
                          color: AppTheme.primaryContainer,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Edit Profile',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Update the basics that shape your plan and nutrition targets.',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  profileField(
                    label: 'Name',
                    icon: Icons.person_outline,
                    controller: nameController,
                  ),
                  const SizedBox(height: 14),
                  profileField(
                    label: 'Age',
                    icon: Icons.cake_outlined,
                    controller: ageController,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 14),
                  profileField(
                    label: 'Height (cm)',
                    icon: Icons.height_rounded,
                    controller: heightController,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 14),
                  profileField(
                    label: 'Weight (kg)',
                    icon: Icons.monitor_weight_outlined,
                    controller: weightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            final updated = user.copyWith(
                              name: nameController.text.trim().isEmpty
                                  ? user.name
                                  : nameController.text.trim(),
                              age:
                                  int.tryParse(ageController.text.trim()) ??
                                  user.age,
                              height:
                                  double.tryParse(
                                    heightController.text.trim(),
                                  ) ??
                                  user.height,
                              weight:
                                  double.tryParse(
                                    weightController.text.trim(),
                                  ) ??
                                  user.weight,
                            );
                            await context.read<UserProvider>().updateProfile(
                              updated,
                            );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          },
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
