import 'dart:math' as math;

import '../models/diet_catalog_models.dart';
import '../models/diet_plan_models.dart';
import '../models/user_model.dart';
import 'diet_catalog_service.dart';
import 'diet_recommender_model.dart';

/// Scores how *suitable* a dish is for a given user (goal/region/diet fit),
/// independent of the running meal budget. Either the on-device TFLite model
/// ([DietRecommenderModel]) or the heuristic fallback supplies this.
typedef DishSuitability = double Function(CatalogDish dish);

class DietPlanService {
  DietPlanService._();

  static final DietPlanService instance = DietPlanService._();

  final DietCatalogService _catalog = DietCatalogService.instance;
  final DietRecommenderModel _model = DietRecommenderModel.instance;

  Future<DietPlan> generate(UserModel user) async {
    final tdee = TdeeEngine.calculate(user);
    final dishes = await _catalog.loadAll();
    if (dishes.isEmpty) {
      throw StateError('Dish catalog is empty. Check diet_catalog.json asset.');
    }

    await _model.ensureLoaded();
    final context = PlanUserContext.forUser(user, tdee);
    final suitability = _resolveSuitability(context);
    final rng = math.Random(DateTime.now().millisecondsSinceEpoch);

    final days = MealPlanBuilder.buildWeek(
      catalog: _catalog,
      allDishes: dishes,
      tdee: tdee,
      context: context,
      suitability: suitability,
      rng: rng,
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
    final dishes = await _catalog.loadAll();
    await _model.ensureLoaded();
    final context = PlanUserContext.forUser(user, plan.tdee);
    final suitability = _resolveSuitability(context);
    final rng = math.Random(DateTime.now().microsecondsSinceEpoch);

    // Avoid repeating dishes already on the plate that day.
    final usedIds = plan.days[dayIndex].meals
        .where((meal) => meal.slot != slot)
        .expand((meal) => meal.foods)
        .map((food) => food.foodId)
        .toSet();

    return MealPlanBuilder.buildMeal(
      catalog: _catalog,
      allDishes: dishes,
      slot: slot,
      tdee: plan.tdee,
      context: context,
      suitability: suitability,
      recentlyUsedIds: usedIds,
      weekUsedIds: usedIds,
      rng: rng,
    );
  }

  /// Picks the model scorer when the TFLite model is available, otherwise the
  /// heuristic. Both share the same `CatalogDish -> 0..1` contract.
  DishSuitability _resolveSuitability(PlanUserContext context) {
    if (_model.isAvailable) {
      return (dish) => _model.score(context: context, dish: dish);
    }
    return (dish) => HeuristicScorer.suitability(dish, context.goalKey);
  }
}

/// Pure-math suitability that mirrors what the Colab model learns, used as the
/// offline fallback (and to bootstrap before any model is trained).
class HeuristicScorer {
  HeuristicScorer._();

  static double suitability(CatalogDish dish, String goalKey) {
    if (dish.kcal <= 0) return 0;

    final proteinScore = (dish.proteinPer100Kcal / 35.0).clamp(0.0, 1.0);
    final absProteinScore = (dish.protein / 35.0).clamp(0.0, 1.0);
    final fiberScore = (dish.fiber / 12.0).clamp(0.0, 1.0);
    final fatPct = (dish.fat * 9.0) / dish.kcal;
    final leanScore = (1.0 - (fatPct / 0.45)).clamp(0.0, 1.0);
    final carbPct = (dish.carbs * 4.0) / dish.kcal;
    final carbScore = (carbPct / 0.6).clamp(0.0, 1.0);

    switch (goalKey) {
      case 'fat_loss':
        return 0.5 * proteinScore + 0.3 * fiberScore + 0.2 * leanScore;
      case 'muscle_gain':
        return 0.6 * proteinScore + 0.25 * absProteinScore + 0.15 * carbScore;
      case 'endurance':
        return 0.5 * carbScore + 0.3 * proteinScore + 0.2 * fiberScore;
      default: // maintenance
        return 0.4 * proteinScore + 0.3 * fiberScore + 0.3 * leanScore;
    }
  }
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
    // How far (kg) the user is from their target weight, when one is set.
    // Positive => wants to lose, negative => wants to gain.
    final targetWeight = user.targetWeight;
    final weightGap = targetWeight > 0 ? weight - targetWeight : 0.0;

    late final double targetCalories;
    late final String goalLabel;

    if (goal.contains('lose') || goal.contains('weight')) {
      // Scale the deficit with how much weight is left to lose: a larger gap
      // earns a slightly larger (still safe) deficit, a near-target gap eases
      // off so the last kilos come off gently.
      final deficit = weightGap > 0
          ? (300.0 + weightGap * 20.0).clamp(300.0, 650.0)
          : 400.0;
      targetCalories = math.max(isMale ? 1500.0 : 1200.0, tdee - deficit);
      goalLabel = 'Fat Loss';
    } else if (goal.contains('muscle') || goal.contains('gain')) {
      // Lean surplus, a touch larger when there is real weight to put on.
      final surplus = weightGap < 0
          ? (250.0 + weightGap.abs() * 12.0).clamp(250.0, 450.0)
          : 250.0;
      targetCalories = tdee + surplus;
      goalLabel = 'Muscle Gain';
    } else if (goal.contains('stamina') || goal.contains('endurance')) {
      targetCalories = tdee + 150;
      goalLabel = 'Endurance';
    } else if (weightGap > 1.0) {
      // "Stay Active" but a lower target weight is set: trend gently down.
      targetCalories = math.max(isMale ? 1500.0 : 1200.0, tdee - 250);
      goalLabel = 'Gentle Fat Loss';
    } else if (weightGap < -1.0) {
      targetCalories = tdee + 200;
      goalLabel = 'Gentle Gain';
    } else {
      targetCalories = tdee;
      goalLabel = 'Maintenance';
    }

    final proteinPerKg = goal.contains('muscle') ? 2.2 : 1.8;
    final protein = (weight * proteinPerKg).clamp(60.0, 250.0);
    final fatPct = goal.contains('lose') ? 0.25 : 0.28;
    final fat = (targetCalories * fatPct) / 9.0;
    final carbsKcal = (targetCalories - (protein * 4.0) - (fat * 9.0)).clamp(
      0.0,
      double.infinity,
    );
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

  static const List<String> _slotOrder = <String>[
    'breakfast',
    'lunch',
    'dinner',
    'snack',
  ];

  static List<PlannedDay> buildWeek({
    required DietCatalogService catalog,
    required List<CatalogDish> allDishes,
    required TdeeResult tdee,
    required PlanUserContext context,
    required DishSuitability suitability,
    required math.Random rng,
  }) {
    // Tracks how recently a dish appeared so the week stays varied: maps dish
    // id -> most recent day index it was used.
    final lastUsedDay = <int, int>{};

    return List<PlannedDay>.generate(7, (dayIndex) {
      final dayUsedIds = <int>{};
      final meals = <PlannedMeal>[];

      for (final slot in _slotOrder) {
        // "Recently used" = used today or in the previous two days.
        final recentlyUsed = <int>{
          ...dayUsedIds,
          ...lastUsedDay.entries
              .where((e) => (dayIndex - e.value) <= 2)
              .map((e) => e.key),
        };

        final meal = buildMeal(
          catalog: catalog,
          allDishes: allDishes,
          slot: slot,
          tdee: tdee,
          context: context,
          suitability: suitability,
          recentlyUsedIds: recentlyUsed,
          weekUsedIds: lastUsedDay.keys.toSet(),
          rng: rng,
        );

        for (final food in meal.foods) {
          dayUsedIds.add(food.foodId);
          lastUsedDay[food.foodId] = dayIndex;
        }
        meals.add(meal);
      }

      return PlannedDay(dayIndex: dayIndex, meals: meals);
    });
  }

  static PlannedMeal buildMeal({
    required DietCatalogService catalog,
    required List<CatalogDish> allDishes,
    required String slot,
    required TdeeResult tdee,
    required PlanUserContext context,
    required DishSuitability suitability,
    required Set<int> recentlyUsedIds,
    required Set<int> weekUsedIds,
    required math.Random rng,
  }) {
    final budget = tdee.targetCalories * (_slotFractions[slot] ?? 0.25);
    final candidates = catalog.dishesFor(
      allDishes: allDishes,
      slot: slot,
      dietaryPreference: context.dietaryPreference,
      country: context.countryCode,
      zone: context.zone,
    );
    if (candidates.isEmpty) {
      return PlannedMeal(slot: slot, foods: const <PlannedFood>[]);
    }

    final chosen = <CatalogDish>[];
    final chosenIds = <int>{};

    // Primary dish: best overall fit for the full slot budget.
    final primary = _pickBest(
      candidates: candidates,
      targetKcal: budget * 0.9,
      hardCap: budget * 1.25 + 120,
      suitability: suitability,
      recentlyUsedIds: recentlyUsedIds,
      weekUsedIds: weekUsedIds,
      excludeIds: chosenIds,
      rng: rng,
    );
    if (primary == null) return PlannedMeal(slot: slot, foods: const []);
    chosen.add(primary);
    chosenIds.add(primary.id);

    // Optional light complement when a single dish leaves a real gap (skip for
    // snacks, which stay a single item).
    final remaining = budget - primary.kcal;
    final maxItems = slot == 'snack' ? 1 : 2;
    if (chosen.length < maxItems && remaining > 220) {
      final side = _pickBest(
        candidates: candidates
            .where((d) => d.kcal <= remaining + 120 && d.kcal <= 320)
            .toList(growable: false),
        targetKcal: remaining * 0.9,
        hardCap: remaining + 130,
        suitability: suitability,
        recentlyUsedIds: recentlyUsedIds,
        weekUsedIds: weekUsedIds,
        excludeIds: chosenIds,
        rng: rng,
      );
      if (side != null) {
        chosen.add(side);
        chosenIds.add(side.id);
      }
    }

    return PlannedMeal(
      slot: slot,
      foods: chosen.map(_toPlannedFood).toList(growable: false),
    );
  }

  static CatalogDish? _pickBest({
    required List<CatalogDish> candidates,
    required double targetKcal,
    required double hardCap,
    required DishSuitability suitability,
    required Set<int> recentlyUsedIds,
    required Set<int> weekUsedIds,
    required Set<int> excludeIds,
    required math.Random rng,
  }) {
    CatalogDish? best;
    var bestScore = -double.infinity;

    for (final dish in candidates) {
      if (excludeIds.contains(dish.id)) continue;
      if (dish.kcal > hardCap) continue;

      final macroFit = _macroFit(dish.kcal, targetKcal);
      final suit = suitability(dish).clamp(0.0, 1.0);

      var penalty = 0.0;
      if (recentlyUsedIds.contains(dish.id)) {
        penalty += 0.6; // strongly discourage same/near-day repeats
      } else if (weekUsedIds.contains(dish.id)) {
        penalty += 0.2; // mildly discourage anything already used this week
      }

      final jitter = rng.nextDouble() * 0.08; // keeps plans from being identical
      final score = (suit * 0.55) + (macroFit * 0.35) - penalty + jitter;

      if (score > bestScore) {
        bestScore = score;
        best = dish;
      }
    }

    // If everything was excluded/penalized away, fall back to the closest-kcal
    // candidate so the slot is never empty.
    if (best == null) {
      for (final dish in candidates) {
        if (excludeIds.contains(dish.id)) continue;
        final macroFit = _macroFit(dish.kcal, targetKcal);
        if (macroFit > bestScore) {
          bestScore = macroFit;
          best = dish;
        }
      }
    }
    return best;
  }

  /// 1.0 when the dish hits the target calories, decaying as it drifts away.
  static double _macroFit(double dishKcal, double targetKcal) {
    if (targetKcal <= 0) return 0;
    final diff = (dishKcal - targetKcal).abs() / targetKcal;
    return (1.0 - diff).clamp(0.0, 1.0);
  }

  static PlannedFood _toPlannedFood(CatalogDish dish) {
    return PlannedFood(
      foodId: dish.id,
      foodName: dish.name,
      quantityGrams: 0,
      servingLabel: dish.serving,
      calories: dish.kcal,
      protein: dish.protein,
      carbs: dish.carbs,
      fat: dish.fat,
    );
  }
}
