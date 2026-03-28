class TdeeResult {
  final double bmr;
  final double tdee;
  final double targetCalories;
  final double targetProtein;
  final double targetCarbs;
  final double targetFat;
  final double targetFiber;
  final String activityLevel;
  final String goalLabel;

  const TdeeResult({
    required this.bmr,
    required this.tdee,
    required this.targetCalories,
    required this.targetProtein,
    required this.targetCarbs,
    required this.targetFat,
    required this.targetFiber,
    required this.activityLevel,
    required this.goalLabel,
  });

  double get adjustment => targetCalories - tdee;

  Map<String, dynamic> toJson() => {
        'bmr': bmr,
        'tdee': tdee,
        'targetCalories': targetCalories,
        'targetProtein': targetProtein,
        'targetCarbs': targetCarbs,
        'targetFat': targetFat,
        'targetFiber': targetFiber,
        'activityLevel': activityLevel,
        'goalLabel': goalLabel,
      };

  factory TdeeResult.fromJson(Map<String, dynamic> json) => TdeeResult(
        bmr: (json['bmr'] as num).toDouble(),
        tdee: (json['tdee'] as num).toDouble(),
        targetCalories: (json['targetCalories'] as num).toDouble(),
        targetProtein: (json['targetProtein'] as num).toDouble(),
        targetCarbs: (json['targetCarbs'] as num).toDouble(),
        targetFat: (json['targetFat'] as num).toDouble(),
        targetFiber: (json['targetFiber'] as num).toDouble(),
        activityLevel: json['activityLevel'] as String,
        goalLabel: json['goalLabel'] as String,
      );
}

class PlannedFood {
  final int foodId;
  final String foodName;
  final double quantityGrams;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  const PlannedFood({
    required this.foodId,
    required this.foodName,
    required this.quantityGrams,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  Map<String, dynamic> toJson() => {
        'foodId': foodId,
        'foodName': foodName,
        'quantityGrams': quantityGrams,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      };

  factory PlannedFood.fromJson(Map<String, dynamic> json) => PlannedFood(
        foodId: json['foodId'] as int,
        foodName: json['foodName'] as String,
        quantityGrams: (json['quantityGrams'] as num).toDouble(),
        calories: (json['calories'] as num).toDouble(),
        protein: (json['protein'] as num).toDouble(),
        carbs: (json['carbs'] as num).toDouble(),
        fat: (json['fat'] as num).toDouble(),
      );
}

class PlannedMeal {
  final String slot;
  final List<PlannedFood> foods;

  const PlannedMeal({required this.slot, required this.foods});

  double get calories => foods.fold(0, (sum, food) => sum + food.calories);
  double get protein => foods.fold(0, (sum, food) => sum + food.protein);
  double get carbs => foods.fold(0, (sum, food) => sum + food.carbs);
  double get fat => foods.fold(0, (sum, food) => sum + food.fat);

  String get slotLabel {
    switch (slot) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      case 'snack':
        return 'Snack';
      default:
        return slot;
    }
  }

  Map<String, dynamic> toJson() => {
        'slot': slot,
        'foods': foods.map((food) => food.toJson()).toList(),
      };

  factory PlannedMeal.fromJson(Map<String, dynamic> json) => PlannedMeal(
        slot: json['slot'] as String,
        foods: (json['foods'] as List<dynamic>)
            .map((item) => PlannedFood.fromJson(item as Map<String, dynamic>))
            .toList(),
      );

  PlannedMeal copyWith({List<PlannedFood>? foods}) {
    return PlannedMeal(slot: slot, foods: foods ?? this.foods);
  }
}

class PlannedDay {
  final int dayIndex;
  final List<PlannedMeal> meals;

  const PlannedDay({required this.dayIndex, required this.meals});

  static const List<String> _dayNames = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  String get dayName => _dayNames[dayIndex % 7];
  double get totalCalories => meals.fold(0, (sum, meal) => sum + meal.calories);
  double get totalProtein => meals.fold(0, (sum, meal) => sum + meal.protein);
  double get totalCarbs => meals.fold(0, (sum, meal) => sum + meal.carbs);
  double get totalFat => meals.fold(0, (sum, meal) => sum + meal.fat);

  Map<String, dynamic> toJson() => {
        'dayIndex': dayIndex,
        'meals': meals.map((meal) => meal.toJson()).toList(),
      };

  factory PlannedDay.fromJson(Map<String, dynamic> json) => PlannedDay(
        dayIndex: json['dayIndex'] as int,
        meals: (json['meals'] as List<dynamic>)
            .map((item) => PlannedMeal.fromJson(item as Map<String, dynamic>))
            .toList(),
      );

  PlannedDay copyWith({List<PlannedMeal>? meals}) {
    return PlannedDay(dayIndex: dayIndex, meals: meals ?? this.meals);
  }
}

class DietPlan {
  final String userId;
  final DateTime generatedAt;
  final TdeeResult tdee;
  final List<PlannedDay> days;

  const DietPlan({
    required this.userId,
    required this.generatedAt,
    required this.tdee,
    required this.days,
  });

  PlannedDay get today {
    final index = DateTime.now().weekday - 1;
    return days[index % days.length];
  }

  double get avgCalories {
    if (days.isEmpty) return 0;
    return days.fold<double>(0, (sum, day) => sum + day.totalCalories) /
        days.length;
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'generatedAt': generatedAt.toIso8601String(),
        'tdee': tdee.toJson(),
        'days': days.map((day) => day.toJson()).toList(),
      };

  factory DietPlan.fromJson(Map<String, dynamic> json) => DietPlan(
        userId: json['userId'] as String,
        generatedAt: DateTime.parse(json['generatedAt'] as String),
        tdee: TdeeResult.fromJson(json['tdee'] as Map<String, dynamic>),
        days: (json['days'] as List<dynamic>)
            .map((item) => PlannedDay.fromJson(item as Map<String, dynamic>))
            .toList(),
      );

  DietPlan copyWith({List<PlannedDay>? days}) {
    return DietPlan(
      userId: userId,
      generatedAt: generatedAt,
      tdee: tdee,
      days: days ?? this.days,
    );
  }
}
