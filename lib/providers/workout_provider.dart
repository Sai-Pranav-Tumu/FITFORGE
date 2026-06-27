import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/exercise_library_models.dart';
import '../models/user_model.dart';
import '../models/workout_adaptation.dart';
import '../models/workout_log_models.dart';
import '../models/workout_plan.dart';
import '../services/analytics_service.dart';
import '../services/exercise_library_service.dart';
import '../services/workout_engine_service.dart';

class WorkoutProvider extends ChangeNotifier {
  WorkoutProvider() {
    _library.addListener(_handleLibraryChanged);
    _bootstrap();
  }

  final ExerciseLibraryService _library = ExerciseLibraryService.instance;

  UserModel? _profile;
  List<WorkoutSetLog> _logs = const <WorkoutSetLog>[];
  bool _hasPro = true;
  WorkoutRecommendation? _recommendation;
  bool _loading = false;
  String? _error;
  String _lastLibraryVersion = '';
  int _lastExerciseCount = 0;
  bool _lastHasExercises = false;
  String _profileSignature = '';
  int _rebuildRequestId = 0;

  WorkoutRecommendation? get recommendation => _recommendation;
  bool get loading => _loading;
  String? get error => _error;
  bool get usingStarterPack => _library.usingStarterPack;
  bool get syncingLibrary => _library.isSyncing;
  bool get hasFullDataset => _library.hasFullDataset;
  bool get hasExercises => _library.hasExercises;
  bool get shouldShowDownloadPrompt => _library.shouldShowDownloadPrompt;
  double get downloadProgress => _library.downloadProgress;
  String get downloadPhase => _library.downloadPhase;
  String get downloadPhaseMessage => _library.downloadPhaseMessage;

  Future<void> acceptExerciseLibraryDownload() {
    AnalyticsService.instance.logLibraryDownloadStarted();
    return _library.acceptDownloadPrompt();
  }

  Future<void> declineExerciseLibraryDownload() =>
      _library.declineDownloadPrompt();

  Future<void> _bootstrap() async {
    await _library.initialize();
    await _rebuildRecommendation();
  }

  Future<void> sync(
    UserModel? profile, [
    List<WorkoutSetLog> logs = const <WorkoutSetLog>[],
    bool hasPro = true,
  ]) async {
    _hasPro = hasPro;
    final nextSignature = _buildProfileSignature(profile, logs, hasPro);
    // Clear (and show a loading state) only when the *profile* changes; when
    // just the logs change we recompute quietly so the dashboard never flashes.
    final profileChanged =
        _signatureProfilePart(nextSignature) !=
        _signatureProfilePart(_profileSignature);
    final anythingChanged = nextSignature != _profileSignature;
    _profile = profile;
    _logs = logs;
    _profileSignature = nextSignature;

    if (!anythingChanged &&
        (_loading || _recommendation != null || _profile == null)) {
      return;
    }

    await _rebuildRecommendation(clearCurrent: profileChanged);
  }

  String _signatureProfilePart(String signature) {
    final idx = signature.indexOf('##logs:');
    return idx < 0 ? signature : signature.substring(0, idx);
  }

  /// Rebuilds the plan. [clearCurrent] false keeps the existing plan on screen
  /// while recomputing (used for pull-to-refresh so the dashboard doesn't flash
  /// to an empty/loading state).
  Future<void> refresh({UserModel? profile, bool clearCurrent = true}) async {
    if (profile != null || _profile != null) {
      _profile = profile ?? _profile;
      _profileSignature = _buildProfileSignature(_profile, _logs, _hasPro);
    }
    await _rebuildRecommendation(clearCurrent: clearCurrent);
  }

  Future<void> _rebuildRecommendation({bool clearCurrent = false}) async {
    final requestId = ++_rebuildRequestId;

    if (_profile == null) {
      _recommendation = null;
      _loading = false;
      _error = null;
      _captureLibrarySnapshot();
      notifyListeners();
      return;
    }

    if (clearCurrent) {
      _recommendation = null;
    }
    _loading = true;
    // Only rebuild into a loading state when there's nothing to show. Otherwise
    // keep the current plan visible (no flash) while we recompute in the
    // background — this avoids the pull-to-refresh stutter.
    if (clearCurrent || _recommendation == null) {
      notifyListeners();
    }

    try {
      await _library.initialize();
      WorkoutRecommendation? nextRecommendation;
      String? nextError;
      if (_profile != null && _library.exercises.isNotEmpty) {
        final base = _profile!;
        // Tier gating: Free is capped at 3 training days/week and gets a static
        // plan; Pro/Max unlock full frequency and the adaptive engine.
        final tieredProfile = _hasPro
            ? base
            : base.copyWith(workoutDays: base.workoutDays.clamp(1, 3));
        final adaptation = _hasPro
            ? WorkoutAdaptation.from(
                profile: base,
                logs: _logs,
                now: DateTime.now(),
              )
            : WorkoutAdaptation.neutral;
        nextRecommendation = await _buildRecommendationOffThread(
          tieredProfile,
          _library.exercises,
          adaptation,
        );
        nextError = _library.error;
      } else {
        nextRecommendation = null;
        nextError = _library.hasExercises
            ? _library.error
            : (_library.shouldShowDownloadPrompt
                  ? null
                  : 'No exercise library is available yet.');
      }

      if (requestId != _rebuildRequestId) {
        return;
      }

      _recommendation = nextRecommendation;
      _error = nextError;
    } catch (error) {
      if (requestId != _rebuildRequestId) {
        return;
      }
      _error = error.toString();
    } finally {
      if (requestId == _rebuildRequestId) {
        _captureLibrarySnapshot();
        _loading = false;
        notifyListeners();
      }
    }
  }

  /// Runs the (CPU-heavy) recommendation build on a background isolate so it
  /// never janks the UI thread. Falls back to an inline build if the isolate
  /// can't be used.
  Future<WorkoutRecommendation> _buildRecommendationOffThread(
    UserModel profile,
    List<ExerciseDefinition> exercises,
    WorkoutAdaptation adaptation,
  ) async {
    try {
      return await compute(
        _computeRecommendation,
        _RecommendationParams(profile, exercises, adaptation),
      );
    } catch (error) {
      debugPrint('Recommendation isolate failed, computing inline: $error');
      return WorkoutEngineService.buildRecommendation(
        profile: profile,
        exercises: exercises,
        adaptation: adaptation,
      );
    }
  }

  void _handleLibraryChanged() {
    _error = _library.error;
    if (_profile == null) {
      notifyListeners();
      return;
    }

    if (_didLibraryDatasetChange()) {
      unawaited(_rebuildRecommendation());
      return;
    }

    notifyListeners();
  }

  bool _didLibraryDatasetChange() {
    return _lastLibraryVersion != _library.activeVersion ||
        _lastExerciseCount != _library.exercises.length ||
        _lastHasExercises != _library.hasExercises;
  }

  void _captureLibrarySnapshot() {
    _lastLibraryVersion = _library.activeVersion;
    _lastExerciseCount = _library.exercises.length;
    _lastHasExercises = _library.hasExercises;
  }

  String _buildProfileSignature(
    UserModel? profile,
    List<WorkoutSetLog> logs,
    bool hasPro,
  ) {
    if (profile == null) {
      return '';
    }

    final profilePart = [
      hasPro ? 'pro' : 'free',
      profile.id,
      profile.name,
      profile.fitnessGoal,
      profile.workoutDays.toString(),
      profile.trainingLevel,
      profile.workoutLocation,
      profile.availableEquipment,
      profile.sessionDurationMinutes.toString(),
      profile.targetMuscleFocuses.join(','),
      profile.jointSensitivities.join(','),
      profile.occupation,
      profile.sittingHours,
      profile.weight.toStringAsFixed(1),
      profile.height.toStringAsFixed(1),
      profile.targetWeight.toStringAsFixed(1),
      profile.age.toString(),
      profile.gender,
      profile.injuryNotes,
      profile.intensityAdjustment.toString(),
      // Streak + recency feed the adaptive engine, so changes must rebuild.
      profile.streak.toString(),
      profile.workoutCompletionDates.length.toString(),
    ].join('|');

    // Logs only nudge weight suggestions / volume, so they live after a marker
    // that lets us detect a logs-only change and avoid a loading flash.
    final logsPart = logs.isEmpty
        ? '0:0'
        : '${logs.length}:${logs.last.timestampMillis}';
    return '$profilePart##logs:$logsPart';
  }

  @override
  void dispose() {
    _library.removeListener(_handleLibraryChanged);
    super.dispose();
  }
}

/// Arguments bundle for the background recommendation build.
class _RecommendationParams {
  final UserModel profile;
  final List<ExerciseDefinition> exercises;
  final WorkoutAdaptation adaptation;

  const _RecommendationParams(this.profile, this.exercises, this.adaptation);
}

/// Top-level isolate entry point (required by `compute`).
WorkoutRecommendation _computeRecommendation(_RecommendationParams params) {
  return WorkoutEngineService.buildRecommendation(
    profile: params.profile,
    exercises: params.exercises,
    adaptation: params.adaptation,
  );
}
