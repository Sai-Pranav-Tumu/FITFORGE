import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/diet_plan_models.dart';
import '../models/nutrition_models.dart';
import '../models/user_model.dart';
import 'nutrition_service.dart';

class DietPlanService {
  DietPlanService._();

  static final DietPlanService instance = DietPlanService._();

  final NutritionService _nutrition = NutritionService.instance;

  Future<DietPlan> generate(UserModel user) async {
    await _nutrition.initialize();

    final tdee = TdeeEngine.calculate(user);
    final allFoods = _filterFoodsByPreference(
      await _nutrition.getAllFoodsForPlanning(),
      user.dietaryPreference,
    );
    if (allFoods.isEmpty) {
      throw StateError('Food database is empty. Import nutrition data first.');
    }

    final days = await compute(
      _buildWeekInIsolate,
      _IsolateArgs(
        foods: allFoods,
        tdee: tdee,
        seed: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    return DietPlan(
      userId: user.id,
      generatedAt: DateTime.now(),
      tdee: tdee,
      days: days,
    );
  }

  Future<PlannedMeal> regenerateMeal({
    required DietPlan plan,
    required int dayIndex,
    required String slot,
    required UserModel user,
  }) async {
    await _nutrition.initialize();
    final allFoods = _filterFoodsByPreference(
      await _nutrition.getAllFoodsForPlanning(),
      user.dietaryPreference,
    );
    final budget = MealPlanBuilder.slotBudget(plan.tdee, slot);
    final rng = math.Random(DateTime.now().microsecondsSinceEpoch);

    final usedIds = plan.days[dayIndex].meals
        .expand((meal) => meal.foods)
        .map((food) => food.foodId)
        .toSet();
    final available = allFoods.where((food) => !usedIds.contains(food.id)).toList();

    return MealPlanBuilder.buildMeal(
      slot: slot,
      foods: available.isNotEmpty ? available : allFoods,
      budget: budget,
      rng: rng,
    );
  }
}

List<FoodItem> _filterFoodsByPreference(
  List<FoodItem> foods,
  String preference,
) {
  if (preference == 'any') return foods;

  final filtered = foods.where((food) {
    final name = food.foodName.toLowerCase();
    final isNonVeg = _nonVegKeywords.any(name.contains);
    if (preference == 'veg') {
      return !isNonVeg;
    }
    return isNonVeg;
  }).toList();

  return filtered.isNotEmpty ? filtered : foods;
}

const List<String> _nonVegKeywords = <String>[
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

List<PlannedDay> _buildWeekInIsolate(_IsolateArgs args) {
  final rng = math.Random(args.seed);
  return MealPlanBuilder.buildWeek(
    foods: args.foods,
    tdee: args.tdee,
    rng: rng,
  );
}

class _IsolateArgs {
  final List<FoodItem> foods;
  final TdeeResult tdee;
  final int seed;

  const _IsolateArgs({
    required this.foods,
    required this.tdee,
    required this.seed,
  });
}

class TdeeEngine {
  TdeeEngine._();

  static TdeeResult calculate(UserModel user) {
    final isMale = user.gender.trim().toLowerCase() == 'male';
    final weight = user.weight.clamp(30.0, 250.0);
    final height = user.height.clamp(100.0, 250.0);
    final age = user.age.clamp(10, 100);

    final bmr = isMale
        ? (10 * weight) + (6.25 * height) - (5 * age) + 5
        : (10 * weight) + (6.25 * height) - (5 * age) - 161;

    final activityLevel = _activityLevel(user);
    final tdee = bmr * _multiplierFor(activityLevel);

    final goal = user.fitnessGoal.trim().toLowerCase();
    late final double targetCalories;
    late final String goalLabel;

    if (goal.contains('lose') || goal.contains('weight')) {
      targetCalories = math.max(isMale ? 1500.0 : 1200.0, tdee - 400);
      goalLabel = 'Fat Loss';
    } else if (goal.contains('muscle') || goal.contains('gain')) {
      targetCalories = tdee + 250;
      goalLabel = 'Muscle Gain';
    } else if (goal.contains('stamina') || goal.contains('endurance')) {
      targetCalories = tdee + 150;
      goalLabel = 'Endurance';
    } else {
      targetCalories = tdee;
      goalLabel = 'Maintenance';
    }

    final proteinPerKg = goal.contains('muscle') ? 2.2 : 1.8;
    final protein = (weight * proteinPerKg).clamp(60.0, 250.0);
    final fatPct = goal.contains('lose') ? 0.25 : 0.28;
    final fat = (targetCalories * fatPct) / 9.0;
    final carbsKcal =
        (targetCalories - (protein * 4.0) - (fat * 9.0)).clamp(0.0, double.infinity);
    final carbs = carbsKcal / 4.0;

    return TdeeResult(
      bmr: bmr,
      tdee: tdee,
      targetCalories: targetCalories,
      targetProtein: protein,
      targetCarbs: carbs,
      targetFat: fat,
      targetFiber: 30.0,
      activityLevel: activityLevel,
      goalLabel: goalLabel,
    );
  }

  static String _activityLevel(UserModel user) {
    final sitting = user.sittingHours.toLowerCase();
    final days = user.workoutDays;

    if (sitting.contains('8') || (sitting.contains('6') && days <= 2)) {
      return 'Sedentary';
    }
    if (sitting.contains('6') || (sitting.contains('4') && days <= 3)) {
      return 'Lightly Active';
    }
    if (days >= 4) return 'Very Active';
    return 'Moderately Active';
  }

  static double _multiplierFor(String level) {
    switch (level) {
      case 'Sedentary':
        return 1.2;
      case 'Lightly Active':
        return 1.375;
      case 'Moderately Active':
        return 1.55;
      case 'Very Active':
        return 1.725;
      default:
        return 1.375;
    }
  }
}

class MealPlanBuilder {
  MealPlanBuilder._();

  static const Map<String, double> _slotFractions = <String, double>{
    'breakfast': 0.25,
    'lunch': 0.35,
    'dinner': 0.30,
    'snack': 0.10,
  };

  static List<PlannedDay> buildWeek({
    required List<FoodItem> foods,
    required TdeeResult tdee,
    required math.Random rng,
  }) {
    return List<PlannedDay>.generate(
      7,
      (dayIndex) => _buildDay(
        dayIndex: dayIndex,
        foods: foods,
        tdee: tdee,
        rng: rng,
      ),
    );
  }

  static PlannedDay _buildDay({
    required int dayIndex,
    required List<FoodItem> foods,
    required TdeeResult tdee,
    required math.Random rng,
  }) {
    final shuffled = List<FoodItem>.from(foods)..shuffle(rng);
    final usedIds = <int>{};
    final meals = <PlannedMeal>[];

    for (final slot in _slotFractions.keys) {
      final available = shuffled.where((food) => !usedIds.contains(food.id)).toList();
      final meal = buildMeal(
        slot: slot,
        foods: available.isNotEmpty ? available : shuffled,
        budget: slotBudget(tdee, slot),
        rng: rng,
      );
      for (final food in meal.foods) {
        usedIds.add(food.foodId);
      }
      meals.add(meal);
    }

    return PlannedDay(dayIndex: dayIndex, meals: meals);
  }

  static _MacroBudget slotBudget(TdeeResult tdee, String slot) {
    final fraction = _slotFractions[slot] ?? 0.25;
    return _MacroBudget(
      calories: tdee.targetCalories * fraction,
      protein: tdee.targetProtein * fraction,
      carbs: tdee.targetCarbs * fraction,
      fat: tdee.targetFat * fraction,
    );
  }

  static PlannedMeal buildMeal({
    required String slot,
    required List<FoodItem> foods,
    required _MacroBudget budget,
    required math.Random rng,
  }) {
    final chosen = <PlannedFood>[];
    var remaining = budget;
    final targetItems = slot == 'snack' ? 1 : _itemsForSlot(slot, rng);

    for (var i = 0; i < targetItems && remaining.calories > 50; i++) {
      final candidate = _pickBestFood(foods, remaining, chosen, rng);
      if (candidate == null) break;

      final fillFraction = i == targetItems - 1 ? 0.9 : (0.4 + rng.nextDouble() * 0.2);
      final calorieTarget = remaining.calories * fillFraction;
      final rawGrams = (calorieTarget / candidate.calories) * 100.0;
      final grams = _roundToPortionSize(rawGrams, slot, i).clamp(25.0, 400.0);
      final ratio = grams / 100.0;

      final plannedFood = PlannedFood(
        foodId: candidate.id,
        foodName: candidate.foodName,
        quantityGrams: grams,
        calories: candidate.calories * ratio,
        protein: candidate.protein * ratio,
        carbs: candidate.carbs * ratio,
        fat: candidate.fat * ratio,
      );

      chosen.add(plannedFood);
      remaining = remaining.subtract(plannedFood);
    }

    return PlannedMeal(slot: slot, foods: chosen);
  }

  static FoodItem? _pickBestFood(
    List<FoodItem> foods,
    _MacroBudget remaining,
    List<PlannedFood> chosen,
    math.Random rng,
  ) {
    final chosenIds = chosen.map((food) => food.foodId).toSet();
    final candidates = foods.where((food) {
      return !chosenIds.contains(food.id) &&
          food.calories > 1 &&
          food.calories <= remaining.calories + 120;
    }).toList();

    if (candidates.isEmpty) return null;

    final sample = candidates.length > 60
        ? (List<FoodItem>.from(candidates)..shuffle(rng)).take(60).toList()
        : candidates;

    var bestScore = -double.infinity;
    FoodItem? best;
    for (final food in sample) {
      final score = _scoreFood(food, remaining);
      if (score > bestScore) {
        bestScore = score;
        best = food;
      }
    }
    return best;
  }

  static double _scoreFood(FoodItem food, _MacroBudget remaining) {
    if (food.calories <= 0) return -999;

    final proteinRatio = (food.protein * 4.0) / food.calories;
    final remainingProteinRatio =
        (remaining.protein * 4.0) / math.max(1.0, remaining.calories);
    final proteinMatch = 1.0 - (proteinRatio - remainingProteinRatio).abs();
    final densityScore = (food.nutrients['nutrition_density'] ?? 0) / 100.0;
    final calorieFit = food.calories <= remaining.calories ? 1.0 : 0.5;
    final fiberBonus = ((food.nutrients['dietary_fiber'] ?? 0) / 15.0).clamp(0.0, 1.0);

    return (proteinMatch * 0.45) +
        (densityScore * 0.25) +
        (calorieFit * 0.15) +
        (fiberBonus * 0.15);
  }

  static int _itemsForSlot(String slot, math.Random rng) {
    switch (slot) {
      case 'breakfast':
        return 2 + rng.nextInt(2);
      case 'lunch':
      case 'dinner':
        return 3 + rng.nextInt(2);
      default:
        return 1;
    }
  }

  static double _roundToPortionSize(double grams, String slot, int itemIndex) {
    if (itemIndex == 0 && slot != 'snack') {
      return (grams / 50).round() * 50.0;
    }
    return (grams / 25).round() * 25.0;
  }
}

class _MacroBudget {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  const _MacroBudget({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  _MacroBudget subtract(PlannedFood food) {
    return _MacroBudget(
      calories: math.max(0, calories - food.calories),
      protein: math.max(0, protein - food.protein),
      carbs: math.max(0, carbs - food.carbs),
      fat: math.max(0, fat - food.fat),
    );
  }
}
