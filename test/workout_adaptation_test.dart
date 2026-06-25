import 'package:flutter_test/flutter_test.dart';
import 'package:fitforge/models/user_model.dart';
import 'package:fitforge/models/workout_adaptation.dart';
import 'package:fitforge/models/workout_log_models.dart';

UserModel user({int streak = 0, List<String> done = const []}) {
  return UserModel(
    id: 'u',
    email: 'e@x.com',
    name: 'Sam',
    age: 30,
    streak: streak,
    completedWorkoutDates: done,
  );
}

WorkoutSetLog setLog(String date, double weight, {int reps = 8}) {
  return WorkoutSetLog(
    exerciseKey: 'benchpress',
    exerciseName: 'Bench Press',
    dateKey: date,
    setNumber: 1,
    reps: reps,
    weightKg: weight,
    timestampMillis: DateTime.parse(date).millisecondsSinceEpoch,
  );
}

void main() {
  final now = DateTime(2026, 6, 25);

  test('long lay-off triggers a deload', () {
    final a = WorkoutAdaptation.from(
      profile: user(streak: 0, done: const ['2026-06-13']), // 12 days ago
      logs: const [],
      now: now,
    );
    expect(a.daysSinceLastWorkout, 12);
    expect(a.volumeBias, lessThanOrEqualTo(-1));
    expect(a.note.toLowerCase(), contains('welcome back'));
  });

  test('strong streak nudges volume up', () {
    final a = WorkoutAdaptation.from(
      profile: user(streak: 21, done: const ['2026-06-25']),
      logs: const [],
      now: now,
    );
    expect(a.volumeBias, greaterThanOrEqualTo(1));
    expect(a.note, isNotEmpty);
  });

  test('fresh user with no history is neutral', () {
    final a = WorkoutAdaptation.from(
      profile: user(streak: 1, done: const ['2026-06-25']),
      logs: const [],
      now: now,
    );
    expect(a.volumeBias, 0);
    expect(a.progressing, isFalse);
  });

  test('rising logged lifts are detected as progressing', () {
    final logs = <WorkoutSetLog>[
      setLog('2026-06-01', 40),
      setLog('2026-06-08', 42.5),
      setLog('2026-06-15', 45),
      setLog('2026-06-22', 47.5),
    ];
    final a = WorkoutAdaptation.from(
      profile: user(streak: 12, done: const ['2026-06-22']),
      logs: logs,
      now: now,
    );
    expect(a.progressing, isTrue);
    expect(a.loggedSessions, 4);
    expect(a.volumeBias, greaterThanOrEqualTo(1));
  });
}
