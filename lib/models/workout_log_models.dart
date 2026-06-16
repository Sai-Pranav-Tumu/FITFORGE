/// A single logged working set: how many reps at what load, for one exercise.
class WorkoutSetLog {
  final String exerciseKey; // normalized name, stable across plans
  final String exerciseName;
  final String dateKey; // yyyy-mm-dd
  final int setNumber;
  final int reps;
  final double weightKg;
  final int timestampMillis;

  const WorkoutSetLog({
    required this.exerciseKey,
    required this.exerciseName,
    required this.dateKey,
    required this.setNumber,
    required this.reps,
    required this.weightKg,
    required this.timestampMillis,
  });

  /// Estimated one-rep max (Epley formula) — handy for personal-best tracking.
  double get estimatedOneRepMax =>
      weightKg <= 0 ? 0 : weightKg * (1 + reps / 30.0);

  factory WorkoutSetLog.fromJson(Map<String, dynamic> json) {
    return WorkoutSetLog(
      exerciseKey: json['exerciseKey'] as String? ?? '',
      exerciseName: json['exerciseName'] as String? ?? '',
      dateKey: json['dateKey'] as String? ?? '',
      setNumber: (json['setNumber'] as num?)?.toInt() ?? 1,
      reps: (json['reps'] as num?)?.toInt() ?? 0,
      weightKg: (json['weightKg'] as num?)?.toDouble() ?? 0.0,
      timestampMillis: (json['timestampMillis'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'exerciseKey': exerciseKey,
    'exerciseName': exerciseName,
    'dateKey': dateKey,
    'setNumber': setNumber,
    'reps': reps,
    'weightKg': weightKg,
    'timestampMillis': timestampMillis,
  };

  static String keyForName(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

/// One training day's best effort for an exercise — a point on a progress chart.
class ExerciseSessionPoint {
  final String dateKey;
  final double bestWeightKg;
  final double bestOneRepMax;

  const ExerciseSessionPoint({
    required this.dateKey,
    required this.bestWeightKg,
    required this.bestOneRepMax,
  });
}

/// A compact rollup of an exercise's history used for progression hints/UI.
class ExerciseProgress {
  final String exerciseKey;
  final String exerciseName;
  final List<WorkoutSetLog> lastSessionSets;
  final double bestWeightKg;
  final double bestOneRepMax;
  final int totalSets;

  /// Per-session bests over time, oldest first (for charts).
  final List<ExerciseSessionPoint> series;

  const ExerciseProgress({
    required this.exerciseKey,
    required this.exerciseName,
    required this.lastSessionSets,
    required this.bestWeightKg,
    required this.bestOneRepMax,
    required this.totalSets,
    this.series = const <ExerciseSessionPoint>[],
  });
}
