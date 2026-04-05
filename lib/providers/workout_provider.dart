import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../models/workout_plan.dart';
import '../services/exercise_library_service.dart';
import '../services/workout_engine_service.dart';

class WorkoutProvider extends ChangeNotifier {
  WorkoutProvider() {
    _library.addListener(_handleLibraryChanged);
    _bootstrap();
  }

  final ExerciseLibraryService _library = ExerciseLibraryService.instance;

  UserModel? _profile;
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

  Future<void> acceptExerciseLibraryDownload() =>
      _library.acceptDownloadPrompt();

  Future<void> declineExerciseLibraryDownload() =>
      _library.declineDownloadPrompt();

  Future<void> _bootstrap() async {
    await _library.initialize();
    await _rebuildRecommendation();
  }

  Future<void> sync(UserModel? profile) async {
    final nextProfileSignature = _buildProfileSignature(profile);
    final profileChanged = nextProfileSignature != _profileSignature;
    _profile = profile;
    _profileSignature = nextProfileSignature;

    if (!profileChanged &&
        (_loading || _recommendation != null || _profile == null)) {
      return;
    }

    await _rebuildRecommendation(clearCurrent: profileChanged);
  }

  Future<void> refresh({UserModel? profile}) async {
    if (profile != null || _profile != null) {
      _profile = profile ?? _profile;
      _profileSignature = _buildProfileSignature(_profile);
    }
    await _rebuildRecommendation(clearCurrent: true);
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
    notifyListeners();

    try {
      await _library.initialize();
      WorkoutRecommendation? nextRecommendation;
      String? nextError;
      if (_profile != null && _library.exercises.isNotEmpty) {
        nextRecommendation = WorkoutEngineService.buildRecommendation(
          profile: _profile!,
          exercises: _library.exercises,
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

  String _buildProfileSignature(UserModel? profile) {
    if (profile == null) {
      return '';
    }

    return [
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
    ].join('|');
  }

  @override
  void dispose() {
    _library.removeListener(_handleLibraryChanged);
    super.dispose();
  }
}
