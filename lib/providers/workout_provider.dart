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
    _profile = profile;
    await _rebuildRecommendation();
  }

  Future<void> _rebuildRecommendation() async {
    if (_profile == null) {
      _recommendation = null;
      _loading = false;
      _error = null;
      _captureLibrarySnapshot();
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();

    try {
      await _library.initialize();
      if (_profile != null && _library.exercises.isNotEmpty) {
        _recommendation = WorkoutEngineService.buildRecommendation(
          profile: _profile!,
          exercises: _library.exercises,
        );
        _error = _library.error;
      } else {
        _recommendation = null;
        _error = _library.hasExercises
            ? _library.error
            : (_library.shouldShowDownloadPrompt
                  ? null
                  : 'No exercise library is available yet.');
      }
    } catch (error) {
      _error = error.toString();
    } finally {
      _captureLibrarySnapshot();
      _loading = false;
      notifyListeners();
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

  @override
  void dispose() {
    _library.removeListener(_handleLibraryChanged);
    super.dispose();
  }
}
