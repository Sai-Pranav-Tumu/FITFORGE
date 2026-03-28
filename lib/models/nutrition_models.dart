enum MealType {
  breakfast,
  lunch,
  dinner;

  String get dbValue => name;

  String get label {
    switch (this) {
      case MealType.breakfast:
        return 'Breakfast';
      case MealType.lunch:
        return 'Lunch';
      case MealType.dinner:
        return 'Dinner';
    }
  }
}

class FoodItem {
  final int id;
  final String foodName;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final Map<String, double> nutrients;

  const FoodItem({
    required this.id,
    required this.foodName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.nutrients,
  });
}

class MealEntry {
  final String id;
  final String userId;
  final DateTime date;
  final MealType mealType;
  final FoodItem food;
  final double quantityGrams;

  const MealEntry({
    required this.id,
    required this.userId,
    required this.date,
    required this.mealType,
    required this.food,
    required this.quantityGrams,
  });

  double get ratio => quantityGrams / 100.0;
  double get calories => food.calories * ratio;
}

class DailyNutritionSummary {
  final DateTime date;
  final List<MealEntry> entries;
  final Map<String, double> totals;
  final Map<String, double> targets;
  final List<NutrientGap> gaps;

  const DailyNutritionSummary({
    required this.date,
    required this.entries,
    required this.totals,
    required this.targets,
    required this.gaps,
  });
}

class MonthlyNutritionSummary {
  final DateTime month;
  final int daysInMonth;
  final Map<String, double> totals;
  final Map<String, double> targetTotals;
  final double caloriesPercent;
  final double proteinPercent;
  final double vitaminsPercent;
  final List<NutrientGap> gaps;

  const MonthlyNutritionSummary({
    required this.month,
    required this.daysInMonth,
    required this.totals,
    required this.targetTotals,
    required this.caloriesPercent,
    required this.proteinPercent,
    required this.vitaminsPercent,
    required this.gaps,
  });
}

class NutrientGap {
  final String nutrient;
  final double consumed;
  final double target;
  final double percent;
  final List<FoodItem> suggestions;

  const NutrientGap({
    required this.nutrient,
    required this.consumed,
    required this.target,
    required this.percent,
    required this.suggestions,
  });
}
