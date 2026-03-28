class WorkoutExercise {
  final String name;
  final String prescription;
  final String cue;
  final String animationAsset;
  final String animationType;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final List<String> bodyMapZones;
  final String equipment;
  final String difficulty;
  final String movementPattern;

  const WorkoutExercise({
    required this.name,
    required this.prescription,
    required this.cue,
    required this.animationAsset,
    this.animationType = 'lottie',
    this.primaryMuscles = const [],
    this.secondaryMuscles = const [],
    this.bodyMapZones = const [],
    this.equipment = 'Bodyweight',
    this.difficulty = 'Beginner',
    this.movementPattern = 'General',
  });
}

class WorkoutDayPlan {
  final String title;
  final String description;
  final int durationMinutes;
  final int estimatedCalories;
  final bool isRestDay;
  final List<WorkoutExercise> exercises;

  const WorkoutDayPlan({
    required this.title,
    required this.description,
    required this.durationMinutes,
    required this.estimatedCalories,
    required this.isRestDay,
    required this.exercises,
  });
}

class WorkoutRecommendation {
  final String greeting;
  final String weeklyFocus;
  final String insight;
  final List<WorkoutDayPlan> weeklyPlan;
  final WorkoutDayPlan todaysPlan;

  const WorkoutRecommendation({
    required this.greeting,
    required this.weeklyFocus,
    required this.insight,
    required this.weeklyPlan,
    required this.todaysPlan,
  });
}
