import 'package:flutter/foundation.dart';

import '../models/user_model.dart' show workoutDateKey;
import '../models/workout_log_models.dart';
import '../services/analytics_service.dart';
import '../services/workout_log_service.dart';

class WorkoutLogProvider extends ChangeNotifier {
  final WorkoutLogService _service = WorkoutLogService.instance;

  String? _userId;
  List<WorkoutSetLog> _logs = const <WorkoutSetLog>[];

  List<WorkoutSetLog> get logs => _logs;

  Future<void> sync(String? userId) async {
    if (_userId == userId) return;
    _userId = userId;
    await _reload();
  }

  Future<void> _reload() async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      _logs = const <WorkoutSetLog>[];
      notifyListeners();
      return;
    }
    _logs = await _service.all(userId);
    notifyListeners();
  }

  /// The previous session's sets for an exercise (ignoring [todayKey] so a hint
  /// reflects last time, not what was just logged today).
  List<WorkoutSetLog> lastSessionFor(String exerciseName, {String? todayKey}) {
    final key = WorkoutSetLog.keyForName(exerciseName);
    final matching =
        _logs
            .where(
              (l) =>
                  l.exerciseKey == key &&
                  (todayKey == null || l.dateKey != todayKey),
            )
            .toList()
          ..sort((a, b) => b.timestampMillis.compareTo(a.timestampMillis));
    if (matching.isEmpty) return const <WorkoutSetLog>[];
    final latestDate = matching.first.dateKey;
    return (matching.where((l) => l.dateKey == latestDate).toList()
          ..sort((a, b) => a.setNumber.compareTo(b.setNumber)))
        .toList(growable: false);
  }

  double bestWeightFor(String exerciseName) {
    final key = WorkoutSetLog.keyForName(exerciseName);
    return _logs
        .where((l) => l.exerciseKey == key)
        .fold<double>(0, (m, l) => l.weightKg > m ? l.weightKg : m);
  }

  Future<void> logSet({
    required String exerciseName,
    required DateTime date,
    required int setNumber,
    required int reps,
    required double weightKg,
  }) async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) return;

    final log = WorkoutSetLog(
      exerciseKey: WorkoutSetLog.keyForName(exerciseName),
      exerciseName: exerciseName,
      dateKey: workoutDateKey(date),
      setNumber: setNumber,
      reps: reps,
      weightKg: weightKg,
      timestampMillis: DateTime.now().millisecondsSinceEpoch,
    );
    // Update in-memory first for an instant UI, then persist to Firestore.
    _logs = <WorkoutSetLog>[..._logs, log];
    notifyListeners();
    await _service.add(userId, log);
    AnalyticsService.instance.logSetLogged(
      exercise: exerciseName,
      reps: reps,
      weightKg: weightKg,
    );
  }

  /// Per-exercise rollups (with chart series) computed from in-memory logs,
  /// most-recently-trained first.
  List<ExerciseProgress> summaries() {
    final byKey = <String, List<WorkoutSetLog>>{};
    for (final log in _logs) {
      byKey.putIfAbsent(log.exerciseKey, () => <WorkoutSetLog>[]).add(log);
    }

    final result = <ExerciseProgress>[];
    byKey.forEach((key, sets) {
      sets.sort((a, b) => b.timestampMillis.compareTo(a.timestampMillis));
      final latestDate = sets.first.dateKey;
      final lastSession =
          (sets.where((s) => s.dateKey == latestDate).toList()
                ..sort((a, b) => a.setNumber.compareTo(b.setNumber)))
              .toList(growable: false);
      final bestWeight = sets.fold<double>(
        0,
        (m, s) => s.weightKg > m ? s.weightKg : m,
      );
      final bestOrm = sets.fold<double>(
        0,
        (m, s) => s.estimatedOneRepMax > m ? s.estimatedOneRepMax : m,
      );

      // Build a per-day best series (oldest -> newest) for charts.
      final byDate = <String, List<WorkoutSetLog>>{};
      for (final s in sets) {
        byDate.putIfAbsent(s.dateKey, () => <WorkoutSetLog>[]).add(s);
      }
      final series =
          (byDate.entries
                  .map(
                    (e) => ExerciseSessionPoint(
                      dateKey: e.key,
                      bestWeightKg: e.value.fold<double>(
                        0,
                        (m, s) => s.weightKg > m ? s.weightKg : m,
                      ),
                      bestOneRepMax: e.value.fold<double>(
                        0,
                        (m, s) => s.estimatedOneRepMax > m
                            ? s.estimatedOneRepMax
                            : m,
                      ),
                    ),
                  )
                  .toList()
                ..sort((a, b) => a.dateKey.compareTo(b.dateKey)))
              .toList(growable: false);

      result.add(
        ExerciseProgress(
          exerciseKey: key,
          exerciseName: sets.first.exerciseName,
          lastSessionSets: lastSession,
          bestWeightKg: bestWeight,
          bestOneRepMax: bestOrm,
          totalSets: sets.length,
          series: series,
        ),
      );
    });

    result.sort(
      (a, b) => b.lastSessionSets.first.timestampMillis.compareTo(
        a.lastSessionSets.first.timestampMillis,
      ),
    );
    return result;
  }
}
