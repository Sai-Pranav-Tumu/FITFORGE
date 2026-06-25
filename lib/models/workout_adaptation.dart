import 'user_model.dart';
import 'workout_log_models.dart';

/// A derived, plain-data signal that lets the workout engine auto-tune the plan
/// to how the user is actually training — their streak, how recently they last
/// trained, and whether their logged lifts are trending up. Computed once per
/// plan build and passed into the engine (isolate-safe: primitives only).
class WorkoutAdaptation {
  /// Current consistency streak (consecutive training days).
  final int streak;

  /// Days since the last completed workout (large when never trained).
  final int daysSinceLastWorkout;

  /// Whether recent logged lifts show an upward strength trend.
  final bool progressing;

  /// How many distinct days the user has logged sets on.
  final int loggedSessions;

  /// Net weekly-volume nudge in exercise count, in [-2, 2]. Positive pushes
  /// volume up (consistent / progressing), negative eases off (returning from a
  /// break / stalling).
  final int volumeBias;

  /// One-line, user-facing explanation of the current adaptation.
  final String note;

  const WorkoutAdaptation({
    required this.streak,
    required this.daysSinceLastWorkout,
    required this.progressing,
    required this.loggedSessions,
    required this.volumeBias,
    required this.note,
  });

  /// A neutral adaptation (used when there is no history yet).
  static const WorkoutAdaptation neutral = WorkoutAdaptation(
    streak: 0,
    daysSinceLastWorkout: 9999,
    progressing: false,
    loggedSessions: 0,
    volumeBias: 0,
    note: '',
  );

  factory WorkoutAdaptation.from({
    required UserModel profile,
    required List<WorkoutSetLog> logs,
    required DateTime now,
  }) {
    final streak = profile.streak;
    final completed = profile.workoutCompletionDates; // sorted yyyy-mm-dd
    final today = DateTime(now.year, now.month, now.day);

    var daysSinceLast = 9999;
    if (completed.isNotEmpty) {
      final last = DateTime.tryParse(completed.last);
      if (last != null) {
        daysSinceLast = today.difference(last).inDays.abs();
      }
    }

    final progressing = _isProgressing(logs);
    final loggedSessions = logs.map((l) => l.dateKey).toSet().length;

    // Streak rewards consistency; a long lay-off triggers a gentle deload.
    var bias = 0;
    if (daysSinceLast >= 10) {
      bias -= 2;
    } else if (daysSinceLast >= 5) {
      bias -= 1;
    }
    if (streak >= 21) {
      bias += 2;
    } else if (streak >= 10) {
      bias += 1;
    }
    // A clear upward strength trend earns one more notch of volume.
    if (progressing && bias < 2) bias += 1;
    bias = bias.clamp(-2, 2);

    final note = _noteFor(
      bias: bias,
      streak: streak,
      daysSinceLast: daysSinceLast,
      progressing: progressing,
    );

    return WorkoutAdaptation(
      streak: streak,
      daysSinceLastWorkout: daysSinceLast,
      progressing: progressing,
      loggedSessions: loggedSessions,
      volumeBias: bias,
      note: note,
    );
  }

  /// True when the average best estimated-1RM of the most recent sessions beats
  /// the earliest ones (needs at least 4 logged days to judge a trend).
  static bool _isProgressing(List<WorkoutSetLog> logs) {
    if (logs.length < 4) return false;

    final bestByDate = <String, double>{};
    for (final log in logs) {
      final orm = log.estimatedOneRepMax;
      final current = bestByDate[log.dateKey] ?? 0;
      if (orm > current) bestByDate[log.dateKey] = orm;
    }
    final days = bestByDate.keys.toList()..sort();
    if (days.length < 4) return false;

    final window = (days.length / 2).floor().clamp(1, days.length);
    double avg(Iterable<String> ds) {
      final vals = ds.map((d) => bestByDate[d] ?? 0).toList();
      if (vals.isEmpty) return 0;
      return vals.reduce((a, b) => a + b) / vals.length;
    }

    final earliest = avg(days.take(window));
    final latest = avg(days.skip(days.length - window));
    if (earliest <= 0) return latest > 0;
    return latest >= earliest * 1.02; // ~2% improvement counts as progress
  }

  static String _noteFor({
    required int bias,
    required int streak,
    required int daysSinceLast,
    required bool progressing,
  }) {
    if (daysSinceLast >= 10) {
      return 'Welcome back — we trimmed volume to ease you in safely.';
    }
    if (bias >= 1) {
      if (progressing) {
        return 'Your lifts are trending up — volume nudged up to keep you progressing.';
      }
      if (streak >= 10) {
        return '$streak-day streak — adding a little volume to match your consistency.';
      }
      return 'You\'re consistent — volume nudged up a touch.';
    }
    if (bias <= -1) {
      return 'Easing off the volume a little so recovery keeps up.';
    }
    return 'Holding a balanced volume for steady, sustainable progress.';
  }
}
