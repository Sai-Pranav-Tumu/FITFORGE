import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/nutrition_models.dart';
import '../../providers/nutrition_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/water_provider.dart';
import '../../services/nutrition_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/top_app_bar.dart';

class CaloriesScreen extends StatefulWidget {
  const CaloriesScreen({super.key});

  @override
  State<CaloriesScreen> createState() => _CaloriesScreenState();
}

class _CaloriesScreenState extends State<CaloriesScreen> {
  final NutritionService _nutritionService = NutritionService.instance;
  bool _breakfastExpanded = false;
  bool _lunchExpanded = false;
  bool _dinnerExpanded = false;

  Future<void> _openAddFood(MealType mealType) async {
    final nutritionProvider = context.read<NutritionProvider>();
    final selection = await showModalBottomSheet<_FoodSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddFoodDialog(
        mealType: mealType,
        nutritionService: _nutritionService,
      ),
    );

    if (selection == null) return;
    await nutritionProvider.addEntry(
      mealType: mealType,
      foodId: selection.food.id,
      quantityGrams: selection.quantityGrams,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nutritionProvider = context.watch<NutritionProvider>();
    final waterProvider = context.watch<WaterProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final summary = nutritionProvider.dailySummary;
    final loading = nutritionProvider.isLoading;
    final error = nutritionProvider.error;

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: const TopAppBar(title: 'Calories & Macros'),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: Text(error))
          : summary == null
          ? const SizedBox.shrink()
          : SingleChildScrollView(
              padding: const EdgeInsets.only(
                top: 16,
                bottom: 120,
                left: 16,
                right: 16,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Today's Nutrition",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryContainer,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Text(
                          _dateLabel(summary.date),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildMainCard(context, summary, colorScheme),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/diet-plan'),
                      icon: const Icon(Icons.restaurant_menu_rounded),
                      label: const Text('Open Diet Plan'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSuggestedFoodsCard(context, summary, colorScheme),
                  const SizedBox(height: 24),
                  _buildMealSection(
                    context,
                    title: 'Breakfast',
                    icon: Icons.wb_twilight,
                    iconColor: AppTheme.primaryContainer,
                    entries: _mealEntries(summary, MealType.breakfast),
                    isExpanded: _breakfastExpanded,
                    onExpansionChanged: (expanded) {
                      setState(() {
                        _breakfastExpanded = expanded;
                        if (expanded) {
                          _lunchExpanded = false;
                          _dinnerExpanded = false;
                        }
                      });
                    },
                    onAdd: () => _openAddFood(MealType.breakfast),
                  ),
                  const SizedBox(height: 12),
                  _buildMealSection(
                    context,
                    title: 'Lunch',
                    icon: Icons.sunny,
                    iconColor: AppTheme.secondaryContainer,
                    entries: _mealEntries(summary, MealType.lunch),
                    isExpanded: _lunchExpanded,
                    onExpansionChanged: (expanded) {
                      setState(() {
                        _lunchExpanded = expanded;
                        if (expanded) {
                          _breakfastExpanded = false;
                          _dinnerExpanded = false;
                        }
                      });
                    },
                    onAdd: () => _openAddFood(MealType.lunch),
                  ),
                  const SizedBox(height: 12),
                  _buildMealSection(
                    context,
                    title: 'Dinner',
                    icon: Icons.dark_mode,
                    iconColor: AppTheme.tertiary,
                    entries: _mealEntries(summary, MealType.dinner),
                    isExpanded: _dinnerExpanded,
                    onExpansionChanged: (expanded) {
                      setState(() {
                        _dinnerExpanded = expanded;
                        if (expanded) {
                          _breakfastExpanded = false;
                          _lunchExpanded = false;
                        }
                      });
                    },
                    onAdd: () => _openAddFood(MealType.dinner),
                  ),
                  const SizedBox(height: 24),
                  _buildDeficiencyCard(context, summary, colorScheme),
                  const SizedBox(height: 16),
                  _buildWaterCard(context, waterProvider, colorScheme),
                ],
              ),
            ),
    );
  }

  Widget _buildMainCard(
    BuildContext context,
    DailyNutritionSummary summary,
    ColorScheme colorScheme,
  ) {
    final consumedCalories = summary.totals['caloric_value'] ?? 0;
    final targetCalories = summary.targets['caloric_value'] ?? 1;
    final breakfastCalories = _mealCalories(summary, MealType.breakfast);
    final lunchCalories = _mealCalories(summary, MealType.lunch);
    final dinnerCalories = _mealCalories(summary, MealType.dinner);
    final remaining = (targetCalories - consumedCalories)
        .clamp(0, targetCalories)
        .toDouble();

    final protein = summary.totals['protein'] ?? 0;
    final carbs = summary.totals['carbohydrates'] ?? 0;
    final fat = summary.totals['fat'] ?? 0;
    final proteinTarget = summary.targets['protein'] ?? 0;
    final carbsTarget = summary.targets['carbohydrates'] ?? 0;
    final fatTarget = summary.targets['fat'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 256,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 100,
                    startDegreeOffset: -90,
                    sections: [
                      _pieSection(breakfastCalories, AppTheme.primaryContainer),
                      _pieSection(lunchCalories, AppTheme.secondaryContainer),
                      _pieSection(dinnerCalories, AppTheme.tertiary),
                      _pieSection(
                        remaining,
                        colorScheme.surfaceContainerHighest,
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      consumedCalories.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 2,
                      color: colorScheme.surfaceContainerHighest,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                    GestureDetector(
                      onTap: () => _showTargetInfo(context, summary),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${targetCalories.toStringAsFixed(0)} kcal',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMacroBar(
                context,
                'PROTEIN',
                '${protein.toStringAsFixed(1)} / ${proteinTarget.toStringAsFixed(0)}g',
                _safeFactor(protein, summary.targets['protein'] ?? 1),
                AppTheme.primaryContainer,
              ),
              _buildMacroBar(
                context,
                'CARBS',
                '${carbs.toStringAsFixed(1)} / ${carbsTarget.toStringAsFixed(0)}g',
                _safeFactor(carbs, summary.targets['carbohydrates'] ?? 1),
                AppTheme.secondaryContainer,
              ),
              _buildMacroBar(
                context,
                'FAT',
                '${fat.toStringAsFixed(1)} / ${fatTarget.toStringAsFixed(0)}g',
                _safeFactor(fat, summary.targets['fat'] ?? 1),
                AppTheme.tertiary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroBar(
    BuildContext context,
    String label,
    String value,
    double percentage,
    Color color,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 1.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 80,
          height: 4,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percentage.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMealSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<MealEntry> entries,
    required bool isExpanded,
    required ValueChanged<bool> onExpansionChanged,
    required VoidCallback onAdd,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final calories = entries.fold<double>(0, (sum, e) => sum + e.calories);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('meal_$title'),
          initiallyExpanded: isExpanded,
          maintainState: false,
          onExpansionChanged: onExpansionChanged,
          title: Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              if (calories > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(
                    '${calories.toStringAsFixed(0)} KCAL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
            ],
          ),
          children: [
            if (entries.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  children: entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${entry.food.foodName} (${entry.quantityGrams.toStringAsFixed(0)}g)',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Text(
                            '${entry.calories.toStringAsFixed(0)} kcal',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            onPressed: () async {
                              await context
                                  .read<NutritionProvider>()
                                  .deleteEntry(entry.id);
                            },
                            icon: const Icon(Icons.delete_outline, size: 18),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      '+ Add Food',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDeficiencyCard(
    BuildContext context,
    DailyNutritionSummary summary,
    ColorScheme colorScheme,
  ) {
    final gaps = summary.gaps;
    if (gaps.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Great work. Your tracked nutrients are on target today.',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Suggested Focus',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...gaps.take(3).map((gap) {
            final suggestions = gap.suggestions
                .take(2)
                .map((f) => f.foodName)
                .join(', ');
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${_nutritionService.displayName(gap.nutrient)} ${gap.percent.toStringAsFixed(0)}% of target. Try: $suggestions',
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWaterCard(
    BuildContext context,
    WaterProvider waterProvider,
    ColorScheme colorScheme,
  ) {
    final consumed = waterProvider.consumedLiters;
    final goal = waterProvider.goalLiters;
    final percent = goal <= 0 ? 0.0 : (consumed / goal).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop, color: AppTheme.primaryContainer),
              const SizedBox(width: 8),
              const Text(
                'Water Intake',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${consumed.toStringAsFixed(2)}L / ${goal.toStringAsFixed(1)}L',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.primaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _waterButton(
                  context: context,
                  label: '+250ml',
                  onTap: () => context.read<WaterProvider>().addLiters(0.25),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _waterButton(
                  context: context,
                  label: '+500ml',
                  onTap: () => context.read<WaterProvider>().addLiters(0.50),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _waterButton(
                  context: context,
                  label: '+1L',
                  onTap: () => context.read<WaterProvider>().addLiters(1.0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _waterButton(
                  context: context,
                  label: '-250ml',
                  onTap: () => context.read<WaterProvider>().removeLiters(0.25),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _waterButton(
                  context: context,
                  label: '-500ml',
                  onTap: () => context.read<WaterProvider>().removeLiters(0.50),
                ),
              ),
              const SizedBox(width: 8),
              const Spacer(),
            ],
          ),
          if (waterProvider.lastIntakeAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Last drink: ${_timeLabel(waterProvider.lastIntakeAt!)}',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Daily target adjusts with your body metrics, activity, and season.',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedFoodsCard(
    BuildContext context,
    DailyNutritionSummary summary,
    ColorScheme colorScheme,
  ) {
    final preference =
        context.watch<UserProvider>().userProfile?.dietaryPreference ?? 'any';
    final suggestions = summary.gaps
        .expand((gap) => gap.suggestions)
        .fold<List<FoodItem>>(<FoodItem>[], (list, food) {
          final alreadyAdded = list.any((item) => item.id == food.id);
          if (!alreadyAdded) list.add(food);
          return list;
        })
        .where((food) => _matchesDietPreference(food, preference))
        .take(3)
        .toList();

    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Suggested Foods",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Picked from nutrients you are currently behind on.',
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ...suggestions.map(
            (food) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryContainer,
                      shape: BoxShape.circle,
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
                  Text(
                    '${food.calories.toStringAsFixed(0)} kcal',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showTargetInfo(
    BuildContext context,
    DailyNutritionSummary summary,
  ) async {
    final cs = Theme.of(context).colorScheme;
    final calories = summary.targets['caloric_value'] ?? 0;
    final protein = summary.targets['protein'] ?? 0;
    final carbs = summary.targets['carbohydrates'] ?? 0;
    final fat = summary.targets['fat'] ?? 0;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Why this target?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  'This daily target is based on your age, sex, height, weight, activity level, and fitness goal.',
                  style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
                ),
                const SizedBox(height: 6),
                Text(
                  'We estimate your maintenance calories first, then adjust them for fat loss, muscle gain, stamina, or maintenance.',
                  style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _targetChip(
                      'Calories',
                      '${calories.toStringAsFixed(0)} kcal',
                    ),
                    _targetChip(
                      'Protein',
                      '${(summary.totals['protein'] ?? 0).toStringAsFixed(0)} / ${protein.toStringAsFixed(0)}g',
                    ),
                    _targetChip(
                      'Carbs',
                      '${(summary.totals['carbohydrates'] ?? 0).toStringAsFixed(0)} / ${carbs.toStringAsFixed(0)}g',
                    ),
                    _targetChip(
                      'Fat',
                      '${(summary.totals['fat'] ?? 0).toStringAsFixed(0)} / ${fat.toStringAsFixed(0)}g',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _waterButton({
    required BuildContext context,
    required String label,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryContainer.withValues(alpha: 0.15),
        foregroundColor: AppTheme.primaryContainer,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(
          color: AppTheme.primaryContainer.withValues(alpha: 0.22),
        ),
        shadowColor: Colors.transparent,
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }

  Widget _targetChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryContainer.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  bool _matchesDietPreference(FoodItem food, String preference) {
    if (preference == 'any') return true;
    final name = food.foodName.toLowerCase();
    const nonVegKeywords = <String>[
      'chicken',
      'mutton',
      'fish',
      'prawn',
      'egg',
      'beef',
      'pork',
      'meat',
      'tuna',
      'sardine',
      'crab',
      'liver',
    ];
    final isNonVeg = nonVegKeywords.any(name.contains);
    if (preference == 'veg') return !isNonVeg;
    return isNonVeg;
  }

  List<MealEntry> _mealEntries(
    DailyNutritionSummary summary,
    MealType mealType,
  ) {
    return summary.entries
        .where((entry) => entry.mealType == mealType)
        .toList();
  }

  double _mealCalories(DailyNutritionSummary summary, MealType type) {
    return _mealEntries(
      summary,
      type,
    ).fold<double>(0, (sum, e) => sum + e.calories);
  }

  PieChartSectionData _pieSection(double value, Color color) {
    return PieChartSectionData(
      color: color,
      value: value <= 0 ? 0.001 : value,
      title: '',
      radius: 14,
    );
  }

  String _dateLabel(DateTime d) {
    const days = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }

  double _safeFactor(double value, double target) {
    if (target <= 0) return 0;
    return value / target;
  }

  String _timeLabel(DateTime dt) {
    final h24 = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h24 >= 12 ? 'PM' : 'AM';
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    return '$h12:$m $period';
  }
}

class _FoodSelection {
  final FoodItem food;
  final double quantityGrams;

  const _FoodSelection({required this.food, required this.quantityGrams});
}

class _AddFoodDialog extends StatefulWidget {
  final MealType mealType;
  final NutritionService nutritionService;

  const _AddFoodDialog({
    required this.mealType,
    required this.nutritionService,
  });

  @override
  State<_AddFoodDialog> createState() => _AddFoodDialogState();
}

class _AddFoodDialogState extends State<_AddFoodDialog> {
  final TextEditingController _queryController = TextEditingController();
  final TextEditingController _gramsController = TextEditingController(
    text: '100',
  );
  Timer? _debounce;
  int _searchTicket = 0;
  List<FoodItem> _results = const <FoodItem>[];
  FoodItem? _selected;
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    _gramsController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    final ticket = ++_searchTicket;
    if (q.isEmpty) {
      setState(() {
        _results = const <FoodItem>[];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    final found = await widget.nutritionService.searchFoods(q, limit: 30);
    if (!mounted) return;
    if (ticket != _searchTicket) return;
    setState(() {
      _results = found;
      _loading = false;
    });
  }

  Color _accentColor() {
    return switch (widget.mealType) {
      MealType.breakfast => AppTheme.primaryContainer,
      MealType.lunch => AppTheme.secondaryContainer,
      MealType.dinner => AppTheme.tertiary,
    };
  }

  IconData _accentIcon() {
    return switch (widget.mealType) {
      MealType.breakfast => Icons.wb_twilight_rounded,
      MealType.lunch => Icons.sunny,
      MealType.dinner => Icons.dark_mode_rounded,
    };
  }

  String _headerSubtitle() {
    return switch (widget.mealType) {
      MealType.breakfast =>
        'Pick a clean morning meal and set the serving size clearly.',
      MealType.lunch => 'Search your foods and add an accurate midday portion.',
      MealType.dinner =>
        'Log your evening meal with the right quantity and macros.',
    };
  }

  Widget _fieldLabel(BuildContext context, String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _inputShell(BuildContext context, {required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.22)),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final viewInsets = media.viewInsets.bottom;
    final maxHeight = media.size.height - viewInsets - 10;
    final cs = Theme.of(context).colorScheme;
    final accent = _accentColor();

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: viewInsets),
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: cs.outlineVariant.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: accent.withValues(alpha: 0.16)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(_accentIcon(), color: accent),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add ${widget.mealType.label} Food',
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _headerSubtitle(),
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 12.5,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel(context, 'Food Search'),
                    const SizedBox(height: 8),
                    _inputShell(
                      context,
                      child: TextField(
                        controller: _queryController,
                        onChanged: (value) {
                          _onQueryChanged(value);
                          setState(() {});
                        },
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Search food (dosa, idli, paneer...)',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _queryController.text.trim().isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _queryController.clear();
                                    _onQueryChanged('');
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel(context, 'Quantity (grams)'),
                    const SizedBox(height: 8),
                    _inputShell(
                      context,
                      child: TextField(
                        controller: _gramsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: '100',
                          prefixIcon: Icon(Icons.scale_outlined),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _loading
                    ? Padding(
                        key: const ValueKey('loading'),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: LinearProgressIndicator(
                          minHeight: 3,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      )
                    : const SizedBox(key: ValueKey('idle'), height: 3),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _results.isEmpty
                            ? 'No matches yet'
                            : '${_results.length} foods found',
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _results.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.restaurant_menu_rounded,
                                  color: accent,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _queryController.text.trim().isEmpty
                                    ? 'Start typing to search foods'
                                    : 'No items found for "${_queryController.text.trim()}"',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                        itemCount: _results.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final food = _results[index];
                          final selected = _selected?.id == food.id;
                          return Material(
                            color: selected
                                ? accent.withValues(alpha: 0.14)
                                : cs.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => setState(() => _selected = food),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? accent
                                            : cs.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.restaurant_menu,
                                        size: 18,
                                        color: selected
                                            ? Colors.white
                                            : cs.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            food.foodName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${food.calories.toStringAsFixed(0)} kcal | P ${food.protein.toStringAsFixed(1)} | C ${food.carbs.toStringAsFixed(1)} | F ${food.fat.toStringAsFixed(1)} (100g)',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: cs.onSurfaceVariant,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    AnimatedScale(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      scale: selected ? 1 : 0.9,
                                      child: Icon(
                                        selected
                                            ? Icons.check_circle
                                            : Icons.radio_button_unchecked,
                                        color: selected ? accent : cs.outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh.withValues(alpha: 0.55),
                  border: Border(
                    top: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.18),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _selected == null
                            ? null
                            : () {
                                final grams =
                                    double.tryParse(
                                      _gramsController.text.trim(),
                                    ) ??
                                    100;
                                Navigator.of(context).pop(
                                  _FoodSelection(
                                    food: _selected!,
                                    quantityGrams: grams <= 0 ? 100 : grams,
                                  ),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Add Food'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
