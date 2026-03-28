class WorkoutExercise {
  final String name;
  final String prescription;
  final String cue;

  const WorkoutExercise({
    required this.name,
    required this.prescription,
    required this.cue,
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
