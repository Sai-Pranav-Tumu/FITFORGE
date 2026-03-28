import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/diet_plan_models.dart';
import '../../providers/diet_plan_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/top_app_bar.dart';

class DietPlanScreen extends StatefulWidget {
  const DietPlanScreen({super.key});

  @override
  State<DietPlanScreen> createState() => _DietPlanScreenState();
}

class _DietPlanScreenState extends State<DietPlanScreen> {
  int _selectedDay = DateTime.now().weekday - 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoad());
  }

  Future<void> _maybeLoad() async {
    final provider = context.read<DietPlanProvider>();
    final user = context.read<UserProvider>().userProfile;
    if (!provider.hasPlan && user != null) {
      await provider.loadLatest(user.id);
    }
  }

  Future<void> _generatePlan() async {
    final user = context.read<UserProvider>().userProfile;
    if (user == null) return;
    await context.read<DietPlanProvider>().generate(user);
  }

  Future<void> _swapMeal(int dayIndex, String slot) async {
    final user = context.read<UserProvider>().userProfile;
    if (user == null) return;
    await context.read<DietPlanProvider>().swapMeal(
      dayIndex: dayIndex,
      slot: slot,
      user: user,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final provider = context.watch<DietPlanProvider>();

    return Scaffold(
      appBar: const TopAppBar(title: 'Diet Plan'),
      body: provider.loading
          ? const Center(child: CircularProgressIndicator())
          : provider.plan == null
              ? _buildEmptyState(colorScheme)
              : _buildPlan(provider.plan!, colorScheme),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryContainer.withValues(alpha: 0.12),
              ),
              child: const Icon(
                Icons.restaurant_menu_rounded,
                size: 42,
                color: AppTheme.primaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No diet plan yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              'Generate a 7-day meal plan based on your body metrics, activity, and goal.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant, height: 1.45),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _generatePlan,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate Plan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlan(DietPlan plan, ColorScheme colorScheme) {
    final day = plan.days[_selectedDay];
    final progress = (day.totalCalories / plan.tdee.targetCalories).clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TdeeHeader(tdee: plan.tdee),
          const SizedBox(height: 14),
          _DaySelector(
            selectedDay: _selectedDay,
            onSelected: (index) => setState(() => _selectedDay = index),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      day.dayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      '${day.totalCalories.toStringAsFixed(0)} / ${plan.tdee.targetCalories.toStringAsFixed(0)} kcal',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MacroChip('Protein', '${day.totalProtein.toStringAsFixed(0)}g', AppTheme.secondaryContainer),
                    _MacroChip('Carbs', '${day.totalCarbs.toStringAsFixed(0)}g', AppTheme.tertiary),
                    _MacroChip('Fat', '${day.totalFat.toStringAsFixed(0)}g', AppTheme.primaryContainer),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...day.meals.map(
            (meal) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MealCard(
                meal: meal,
                onSwap: () => _swapMeal(_selectedDay, meal.slot),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _generatePlan,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Regenerate 7-Day Plan'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Generated ${_formatDate(plan.generatedAt)} and stored on this device.',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _TdeeHeader extends StatelessWidget {
  final TdeeResult tdee;

  const _TdeeHeader({required this.tdee});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tdee.goalLabel.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.primaryContainer,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${tdee.targetCalories.toStringAsFixed(0)} kcal/day',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'BMR ${tdee.bmr.toStringAsFixed(0)}  •  TDEE ${tdee.tdee.toStringAsFixed(0)}  •  ${tdee.activityLevel}',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MacroChip('Protein', '${tdee.targetProtein.toStringAsFixed(0)}g', AppTheme.secondaryContainer),
              _MacroChip('Carbs', '${tdee.targetCarbs.toStringAsFixed(0)}g', AppTheme.tertiary),
              _MacroChip('Fat', '${tdee.targetFat.toStringAsFixed(0)}g', AppTheme.primaryContainer),
            ],
          ),
        ],
      ),
    );
  }
}

class _DaySelector extends StatelessWidget {
  final int selectedDay;
  final ValueChanged<int> onSelected;

  const _DaySelector({
    required this.selectedDay,
    required this.onSelected,
  });

  static const labels = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday - 1;
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        itemBuilder: (context, index) {
          final isSelected = index == selectedDay;
          final isToday = index == today;
          return GestureDetector(
            onTap: () => onSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 54,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryContainer
                    : colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                border: isToday && !isSelected
                    ? Border.all(color: AppTheme.primaryContainer)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    labels[index],
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isToday
                          ? (isSelected ? Colors.white : AppTheme.primaryContainer)
                          : Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  final PlannedMeal meal;
  final VoidCallback onSwap;

  const _MealCard({
    required this.meal,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                Icon(_iconForSlot(meal.slot), color: AppTheme.primaryContainer, size: 18),
                const SizedBox(width: 8),
                Text(
                  meal.slotLabel,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const Spacer(),
                Text(
                  '${meal.calories.toStringAsFixed(0)} kcal',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                IconButton(
                  onPressed: onSwap,
                  icon: const Icon(Icons.shuffle_rounded, size: 18),
                  tooltip: 'Swap meal',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...meal.foods.map(
            (food) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryContainer.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      food.foodName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${food.quantityGrams.toStringAsFixed(0)}g',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MacroChip('P', '${meal.protein.toStringAsFixed(0)}g', AppTheme.secondaryContainer),
                _MacroChip('C', '${meal.carbs.toStringAsFixed(0)}g', AppTheme.tertiary),
                _MacroChip('F', '${meal.fat.toStringAsFixed(0)}g', AppTheme.primaryContainer),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForSlot(String slot) {
    switch (slot) {
      case 'breakfast':
        return Icons.wb_twilight_rounded;
      case 'lunch':
        return Icons.wb_sunny_rounded;
      case 'dinner':
        return Icons.dark_mode_rounded;
      default:
        return Icons.local_cafe_rounded;
    }
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
