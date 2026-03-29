class WorkoutExercise {
  final String name;
  final String prescription;
  final int? targetDurationSeconds;
  final int? targetRepCount;
  final int cycleCount;
  final String cycleLabel;
  final String cue;
  final String animationAsset;
  final String animationType;
  final List<String> animationFrames;
  final String animationFramesSource;
  final int frameDurationMillis;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final List<String> bodyMapZones;
  final String equipment;
  final String difficulty;
  final String movementPattern;

  const WorkoutExercise({
    required this.name,
    required this.prescription,
    this.targetDurationSeconds,
    this.targetRepCount,
    this.cycleCount = 1,
    this.cycleLabel = 'Set',
    required this.cue,
    required this.animationAsset,
    this.animationType = 'lottie',
    this.animationFrames = const [],
    this.animationFramesSource = 'asset',
    this.frameDurationMillis = 700,
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
