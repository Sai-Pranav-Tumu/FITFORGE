import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/exercise_library_models.dart';

class ExerciseLibraryService extends ChangeNotifier
    with WidgetsBindingObserver {
  ExerciseLibraryService._();

  static final ExerciseLibraryService instance = ExerciseLibraryService._();

  // Default remote manifest for the exercise library.
  // Override with --dart-define=FITFORGE_EXERCISE_MANIFEST_URL=<URL>
  static const String _defaultManifestUrl =
      'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/manifest.json';
  static const String _defaultDatasetUrl =
      'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json';
  static const String _defaultImageBaseUrl =
      'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/';

  // Secondary dataset (hasaneyldrm/exercises-dataset) that provides animated
  // GIF demonstrations. On a name collision we keep the richer free-exercise-db
  // metadata (force/level/mechanic) but adopt this dataset's GIF; exercises that
  // exist only here are added as new entries.
  static const String _gifDatasetUrl =
      'https://raw.githubusercontent.com/hasaneyldrm/exercises-dataset/main/data/exercises.json';
  static const String _gifBaseUrl =
      'https://raw.githubusercontent.com/hasaneyldrm/exercises-dataset/main/';
  // Bump this when the merge logic changes so existing installs re-sync.
  static const String _datasetSchemaTag = 'gifmerge-v2-lazygif';

  // Bundled starter pack so users can train immediately, before downloading the
  // full library. Loaded from assets when no full dataset is present yet.
  static const String _starterAssetDir = 'assets/exercise_library';
  static const String _starterManifestAsset =
      '$_starterAssetDir/starter_exercises.json';

  static const String manifestUrl = String.fromEnvironment(
    'FITFORGE_EXERCISE_MANIFEST_URL',
    defaultValue: _defaultManifestUrl,
  );

  static const String _versionKey = 'exercise_library_version';
  static const String _downloadConsentKey = 'exercise_library_download_consent';
  static const String _datasetFileName = 'exercises.json';
  // Measured from the current free-exercise-db image set:
  // 1,746 images totaling 98,671,281 bytes (~94.1 MB).
  static const int _defaultImageLibraryImageCount = 1746;
  static const int _defaultImageLibraryTotalBytes = 98671281;

  Future<void>? _initFuture;
  bool _initialized = false;
  bool _isSyncing = false;
  bool _hasFullDataset = false;
  bool _downloadConsent = false;
  bool _isObservingLifecycle = false;
  String _activeVersion = 'local';
  String? _error;
  double _downloadProgress = 0.0;
  String _downloadPhase = 'idle';
  String _downloadPhaseMessage = 'Ready to download your exercise library.';
  List<ExerciseDefinition> _exercises = const <ExerciseDefinition>[];
  Timer? _resumeRecoveryTimer;

  bool get initialized => _initialized;
  double get downloadProgress => _downloadProgress;
  String get downloadPhase => _downloadPhase;
  String get downloadPhaseMessage => _downloadPhaseMessage;
  bool get isSyncing => _isSyncing;
  bool get hasFullDataset => _hasFullDataset;
  bool get hasExercises => _exercises.isNotEmpty;
  bool get shouldShowDownloadPrompt =>
      manifestUrl.isNotEmpty && !_hasFullDataset;
  bool get usingStarterPack => !_hasFullDataset;
  String get activeVersion => _activeVersion;
  String? get error => _error;
  List<ExerciseDefinition> get exercises =>
      List<ExerciseDefinition>.unmodifiable(_exercises);

  Future<void> initialize() async {
    _initFuture ??= _initializeInternal();
    await _initFuture;
  }

  Future<void> _initializeInternal() async {
    _attachLifecycleObserverIfNeeded();
    await _loadConsentState();
    await _loadLocalDatasetIfAvailable();
    if (!_hasFullDataset) {
      await _loadStarterPackIfNeeded();
    }
    _initialized = true;
    notifyListeners();

    if (_downloadConsent && !_hasFullDataset) {
      _startResumeRecoveryLoop();
      unawaited(_syncRemoteIfConfigured());
    }
  }

  Future<void> _loadConsentState() async {
    final prefs = await SharedPreferences.getInstance();
    _downloadConsent = prefs.getBool(_downloadConsentKey) ?? false;
  }

  Future<void> acceptDownloadPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    _downloadConsent = true;
    await prefs.setBool(_downloadConsentKey, true);
    _startResumeRecoveryLoop();
    notifyListeners();
    await _syncRemoteIfConfigured();
  }

  Future<void> declineDownloadPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    _downloadConsent = false;
    await prefs.setBool(_downloadConsentKey, false);
    _stopResumeRecoveryLoop();
    notifyListeners();
  }

  void _attachLifecycleObserverIfNeeded() {
    if (_isObservingLifecycle) {
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    _isObservingLifecycle = true;
  }

  void _startResumeRecoveryLoop() {
    _resumeRecoveryTimer?.cancel();
    _resumeRecoveryTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!_downloadConsent || _hasFullDataset) {
        timer.cancel();
        _resumeRecoveryTimer = null;
        return;
      }
      if (!_isSyncing) {
        timer.cancel();
        _resumeRecoveryTimer = null;
        unawaited(_syncRemoteIfConfigured());
      }
    });
  }

  void _stopResumeRecoveryLoop() {
    _resumeRecoveryTimer?.cancel();
    _resumeRecoveryTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_downloadConsent && !_hasFullDataset) {
        _startResumeRecoveryLoop();
        if (!_isSyncing) {
          unawaited(_syncRemoteIfConfigured());
        }
      }
      return;
    }

    _stopResumeRecoveryLoop();
  }

  void _updateDownloadState({
    required String phase,
    required double progress,
    required String message,
  }) {
    _downloadPhase = phase;
    _downloadProgress = progress.clamp(0.0, 1.0);
    _downloadPhaseMessage = message;
    notifyListeners();
  }

  Future<void> _loadLocalDatasetIfAvailable() async {
    final datasetFile = await _localDatasetFile();
    if (!await datasetFile.exists()) {
      return;
    }

    try {
      final raw = await datasetFile.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return;
      }

      final imageDir = await _localImagesDir();
      _exercises = decoded
          .whereType<Map>()
          .map(
            (entry) =>
                ExerciseDefinition.fromJson(entry.cast<String, dynamic>()),
          )
          .map(
            (exercise) => exercise.copyWith(
              images: exercise.images
                  .map((relative) => p.join(imageDir.path, relative))
                  .toList(growable: false),
              // GIFs are stored as remote URLs and streamed/cached on demand,
              // so leave them untouched (only local image frames are rebased).
              gif: exercise.gif,
              imageSource: 'file',
            ),
          )
          .toList(growable: false);

      final prefs = await SharedPreferences.getInstance();
      _activeVersion = prefs.getString(_versionKey) ?? 'local';
      _hasFullDataset = _exercises.isNotEmpty;
      _error = null;
      notifyListeners();
    } catch (error) {
      _error = 'Failed to load cached exercise library: $error';
      notifyListeners();
    }
  }

  /// Loads the bundled starter exercises so the app is usable before the full
  /// library download. Keeps [_hasFullDataset] false so the upgrade prompt
  /// still appears.
  Future<void> _loadStarterPackIfNeeded() async {
    if (_exercises.isNotEmpty) {
      return;
    }
    try {
      final raw = await rootBundle.loadString(_starterManifestAsset);
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return;
      }
      _exercises = decoded
          .whereType<Map>()
          .map(
            (entry) =>
                ExerciseDefinition.fromJson(entry.cast<String, dynamic>()),
          )
          .map(
            (exercise) => exercise.copyWith(
              images: exercise.images
                  .map((relative) => '$_starterAssetDir/$relative')
                  .toList(growable: false),
              gif: exercise.gif.isEmpty
                  ? ''
                  : '$_starterAssetDir/${exercise.gif}',
              imageSource: 'asset',
            ),
          )
          .toList(growable: false);
      _activeVersion = 'starter';
      notifyListeners();
    } catch (error) {
      debugPrint('Starter exercise pack load failed: $error');
    }
  }

  Future<void> _syncRemoteIfConfigured() async {
    if (manifestUrl.isEmpty) {
      return;
    }

    _error = null;
    _isSyncing = true;
    _updateDownloadState(
      phase: 'download_start',
      progress: 0.0,
      message: 'Preparing your exercise library download…',
    );

    try {
      final manifest = await _fetchManifest();
      if (manifest == null) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final currentVersion = prefs.getString(_versionKey);
      final targetVersion = '${manifest.version}+$_datasetSchemaTag';
      final datasetFile = await _localDatasetFile();

      final shouldDownload =
          currentVersion != targetVersion || !await datasetFile.exists();
      if (!shouldDownload) {
        _hasFullDataset = true;
        _activeVersion = currentVersion ?? targetVersion;
        _updateDownloadState(
          phase: 'ready',
          progress: 1.0,
          message: 'Exercise library is already available locally.',
        );
        return;
      }

      final manifestUri = Uri.parse(manifestUrl);
      _updateDownloadState(
        phase: 'dataset',
        progress: 0.04,
        message: 'Downloading exercise dataset…',
      );
      final remoteExercises = await _downloadRemoteDataset(
        manifestUri.resolve(manifest.datasetUrl).toString(),
      );
      final preparedExercises = await _normalizeDownloadedExercises(
        remoteExercises,
      );

      _updateDownloadState(
        phase: 'gif_dataset',
        progress: 0.20,
        message: 'Adding animated exercise demonstrations…',
      );
      final mergedExercises = await _mergeGifDataset(preparedExercises);

      _updateDownloadState(
        phase: 'images',
        progress: 0.22,
        message: 'Downloading exercise libraries…',
      );
      await _downloadAssetFiles(
        exercises: mergedExercises,
        relativePathsOf: _imagePathsOf,
        baseUrl: manifestUri.resolve(manifest.imageBaseUrl).toString(),
        expectedTotalBytes: _resolveImageLibraryTotalBytes(manifest),
        startProgress: 0.22,
        endProgress: 0.90,
        phase: 'images',
        label: 'Downloading exercise libraries',
      );

      // NOTE: GIFs are intentionally NOT bulk-downloaded. The merged dataset
      // stores remote GIF URLs that are streamed and disk-cached on demand
      // (CachedNetworkImage), so the full-library download stays light.

      _updateDownloadState(
        phase: 'setup',
        progress: 0.92,
        message: 'Setting up your workout library…',
      );
      await datasetFile.parent.create(recursive: true);
      const encoder = JsonEncoder.withIndent('  ');
      await datasetFile.writeAsString(
        '${encoder.convert(mergedExercises)}\n',
      );
      _updateDownloadState(
        phase: 'setup',
        progress: 0.97,
        message: 'Loading personalized workouts…',
      );
      await prefs.setString(_versionKey, targetVersion);
      _activeVersion = targetVersion;
      await _loadLocalDatasetIfAvailable();
      _hasFullDataset = true;
      _updateDownloadState(
        phase: 'complete',
        progress: 1.0,
        message: 'Exercise library ready. Enjoy your workouts!',
      );
      _stopResumeRecoveryLoop();
    } catch (error) {
      debugPrint('Exercise library sync failed: $error');
      _error = _friendlySyncErrorMessage(error);
      _updateDownloadState(
        phase: 'failed',
        progress: 0.0,
        message: 'Exercise download failed. Please try again.',
      );
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<ExerciseLibraryManifest?> _fetchManifest() async {
    final uri = Uri.parse(manifestUrl);
    try {
      final decoded = await _getJson(uri);
      if (decoded is Map<String, dynamic>) {
        return ExerciseLibraryManifest.fromJson(decoded);
      }
      if (decoded is List) {
        return ExerciseLibraryManifest(
          version: 'direct-dataset-fallback',
          generatedAt: DateTime.now().toUtc(),
          totalExercises: decoded.length,
          totalImages: _defaultImageLibraryImageCount,
          totalImageBytes: _defaultImageLibraryTotalBytes,
          datasetUrl: manifestUrl,
          imageBaseUrl: _defaultImageBaseUrl,
        );
      }
      _error = 'Exercise manifest did not contain a valid manifest or dataset.';
      return null;
    } on HttpException catch (error) {
      if (error.message.contains('404')) {
        return _buildDefaultExerciseLibraryManifest();
      }
      debugPrint('Exercise manifest fetch failed: $error');
      _error = _friendlySyncErrorMessage(error);
      return null;
    } catch (error) {
      debugPrint('Exercise manifest fetch failed: $error');
      _error = _friendlySyncErrorMessage(error);
      return null;
    }
  }

  ExerciseLibraryManifest _buildDefaultExerciseLibraryManifest() {
    return ExerciseLibraryManifest(
      version: 'github-fallback',
      generatedAt: DateTime.now().toUtc(),
      totalExercises: 0,
      totalImages: _defaultImageLibraryImageCount,
      totalImageBytes: _defaultImageLibraryTotalBytes,
      datasetUrl: _defaultDatasetUrl,
      imageBaseUrl: _defaultImageBaseUrl,
    );
  }

  Future<List<Map<String, dynamic>>> _downloadRemoteDataset(
    String datasetUrl,
  ) async {
    final decoded = await _getJson(Uri.parse(datasetUrl));
    if (decoded is! List) {
      return const <Map<String, dynamic>>[];
    }
    return decoded
        .whereType<Map>()
        .map((entry) => entry.cast<String, dynamic>())
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _normalizeDownloadedExercises(
    List<Map<String, dynamic>> exercises,
  ) async {
    if (exercises.isEmpty) {
      _updateDownloadState(
        phase: 'extracting',
        progress: 0.18,
        message: 'Extracting exercise definitions…',
      );
      return const <Map<String, dynamic>>[];
    }

    final normalized = <Map<String, dynamic>>[];
    for (var index = 0; index < exercises.length; index++) {
      final exercise = exercises[index];
      final rawName = '${exercise['name'] ?? ''}'.trim();
      final name = rawName.isEmpty ? 'Exercise ${index + 1}' : rawName;
      final rawId = '${exercise['id'] ?? ''}'.trim();

      normalized.add(<String, dynamic>{
        'id': rawId.isEmpty ? _slugify(name) : rawId,
        'name': name,
        'force': '${exercise['force'] ?? ''}'.trim(),
        'level': '${exercise['level'] ?? ''}'.trim(),
        'mechanic': '${exercise['mechanic'] ?? ''}'.trim(),
        'equipment': '${exercise['equipment'] ?? ''}'.trim(),
        'primaryMuscles': _sanitizeStringList(exercise['primaryMuscles']),
        'secondaryMuscles': _sanitizeStringList(exercise['secondaryMuscles']),
        'instructions': _sanitizeStringList(exercise['instructions']),
        'category': '${exercise['category'] ?? ''}'.trim(),
        'images': _sanitizeStringList(exercise['images'])
            .map(_sanitizeRelativePath)
            .where((path) => path.isNotEmpty)
            .toList(growable: false),
      });

      if ((index + 1) % 32 == 0 || index == exercises.length - 1) {
        _updateDownloadState(
          phase: 'extracting',
          progress: 0.12 + 0.10 * ((index + 1) / exercises.length),
          message:
              'Extracting exercise definitions (${index + 1}/${exercises.length})…',
        );
        await Future<void>.delayed(Duration.zero);
      }
    }

    return normalized;
  }

  static List<String> _imagePathsOf(Map<String, dynamic> exercise) {
    final images = exercise['images'];
    if (images is! List) {
      return const <String>[];
    }
    return images
        .map((image) => '$image'.trim())
        .where((path) => path.isNotEmpty)
        .toList(growable: false);
  }

  /// Downloads a set of remote asset files (images or GIFs) referenced by the
  /// exercises, writing them under the local images directory at the same
  /// relative path. Progress is reported within [startProgress]..[endProgress].
  Future<void> _downloadAssetFiles({
    required List<Map<String, dynamic>> exercises,
    required List<String> Function(Map<String, dynamic>) relativePathsOf,
    required String baseUrl,
    required int expectedTotalBytes,
    required double startProgress,
    required double endProgress,
    required String phase,
    required String label,
  }) async {
    final imageDir = await _localImagesDir();
    final tasks = <_ImageDownloadTask>[];
    final failed = <String>[];
    final seen = <String>{};

    for (final exercise in exercises) {
      for (final relativePath in relativePathsOf(exercise)) {
        if (relativePath.isEmpty || !seen.add(relativePath)) {
          continue;
        }
        tasks.add(
          _ImageDownloadTask(
            uri: Uri.parse('$baseUrl$relativePath'),
            file: File(p.join(imageDir.path, relativePath)),
          ),
        );
      }
    }

    if (tasks.isEmpty) {
      _updateDownloadState(
        phase: phase,
        progress: endProgress,
        message: 'Preparing downloaded exercise files…',
      );
      return;
    }

    final span = endProgress - startProgress;
    final totalTasks = tasks.length;
    var processedTasks = 0;
    var downloadedBytes = 0;
    const concurrency = 6;
    var next = 0;

    void updateProgress() {
      final message = expectedTotalBytes > 0
          ? _libraryDownloadProgressMessage(
              downloadedBytes: downloadedBytes,
              totalBytes: expectedTotalBytes,
            )
          : '$label (${processedTasks.clamp(0, totalTasks)}/$totalTasks)…';
      _updateDownloadState(
        phase: phase,
        progress: startProgress + span * (processedTasks / totalTasks),
        message: message,
      );
    }

    updateProgress();

    Future<void> worker() async {
      while (true) {
        final index = next++;
        if (index >= tasks.length) {
          return;
        }
        final task = tasks[index];
        if (await task.file.exists()) {
          final existingLength = await task.file.length();
          if (existingLength > 0) {
            processedTasks++;
            downloadedBytes += existingLength;
            updateProgress();
            continue;
          }
        }
        try {
          final bytesDownloaded = await _downloadFile(task.uri, task.file);
          downloadedBytes += bytesDownloaded;
        } catch (error) {
          failed.add(task.uri.toString());
          debugPrint('Exercise asset download failed: ${task.uri} - $error');
        } finally {
          processedTasks++;
          updateProgress();
        }
      }
    }

    await Future.wait(List.generate(concurrency, (_) => worker()));

    if (failed.isNotEmpty) {
      debugPrint(
        'Exercise library finished with ${failed.length} $phase download failures.',
      );
    }
  }

  /// Fetches the GIF dataset and merges it into [baseExercises]. On a
  /// normalized-name collision the base (free-exercise-db) entry keeps its
  /// metadata but gains the GIF; GIF-only exercises are appended as new
  /// entries with inferred metadata.
  Future<List<Map<String, dynamic>>> _mergeGifDataset(
    List<Map<String, dynamic>> baseExercises,
  ) async {
    List<Map<String, dynamic>> gifExercises;
    try {
      gifExercises = await _downloadRemoteDataset(_gifDatasetUrl);
    } catch (error) {
      debugPrint('GIF dataset fetch failed, continuing without GIFs: $error');
      return baseExercises;
    }
    if (gifExercises.isEmpty) {
      return baseExercises;
    }

    // Index GIF entries by normalized name (first one wins).
    final gifByName = <String, Map<String, dynamic>>{};
    for (final gifExercise in gifExercises) {
      final key = _normalizeExerciseName('${gifExercise['name'] ?? ''}');
      if (key.isEmpty) {
        continue;
      }
      gifByName.putIfAbsent(key, () => gifExercise);
    }

    final merged = <Map<String, dynamic>>[];
    final usedGifKeys = <String>{};
    final usedIds = <String>{
      for (final exercise in baseExercises) '${exercise['id'] ?? ''}',
    };

    // 1. Existing exercises keep their metadata, gain a GIF when matched.
    for (final exercise in baseExercises) {
      final key = _normalizeExerciseName('${exercise['name'] ?? ''}');
      final gifExercise = gifByName[key];
      if (gifExercise != null) {
        final gifPath = _sanitizeRelativePath('${gifExercise['gif_url'] ?? ''}');
        if (gifPath.isNotEmpty) {
          exercise['gif'] = '$_gifBaseUrl$gifPath';
          usedGifKeys.add(key);
        }
      }
      merged.add(exercise);
    }

    // 2. GIF-only exercises become new entries with inferred metadata.
    for (final entry in gifByName.entries) {
      if (usedGifKeys.contains(entry.key)) {
        continue;
      }
      final gifExercise = entry.value;
      final gifPath = _sanitizeRelativePath('${gifExercise['gif_url'] ?? ''}');
      if (gifPath.isEmpty) {
        continue;
      }
      final name = '${gifExercise['name'] ?? ''}'.trim();
      if (name.isEmpty) {
        continue;
      }

      var id = _slugify(name);
      while (!usedIds.add(id)) {
        id = '${id}_x';
      }

      final equipment = '${gifExercise['equipment'] ?? ''}'.trim();
      final primaryMuscles = _gifPrimaryMuscles(gifExercise);
      final secondaryMuscles = _sanitizeStringList(
        gifExercise['secondary_muscles'],
      );
      final category = '${gifExercise['category'] ?? gifExercise['body_part'] ?? ''}'
          .trim();

      merged.add(<String, dynamic>{
        'id': id,
        'name': name,
        // The GIF dataset lacks force/level/mechanic, which the recommendation
        // scoring relies on, so infer them from the name/equipment/muscles.
        'force': _inferForce(name),
        'level': _inferLevel(name, equipment),
        'mechanic': _inferMechanic(name, primaryMuscles, secondaryMuscles),
        'equipment': equipment,
        'primaryMuscles': primaryMuscles,
        'secondaryMuscles': secondaryMuscles,
        'instructions': _gifInstructions(gifExercise),
        'category': category,
        'images': const <String>[],
        'gif': '$_gifBaseUrl$gifPath',
      });
    }

    return merged;
  }

  String _inferForce(String name) {
    final n = name.toLowerCase();
    const pull = ['row', 'pull', 'curl', 'chin', 'deadlift', 'pulldown', 'face pull'];
    const push = ['press', 'push', 'dip', 'extension', 'fly', 'raise', 'thruster', 'jerk'];
    if (pull.any(n.contains)) return 'pull';
    if (push.any(n.contains)) return 'push';
    return '';
  }

  String _inferLevel(String name, String equipment) {
    final n = name.toLowerCase();
    const advanced = [
      'muscle up',
      'muscle-up',
      'planche',
      'pistol',
      'snatch',
      'clean and jerk',
      'one arm',
      'one-arm',
      'handstand',
    ];
    if (advanced.any(n.contains)) return 'advanced';
    final eq = equipment.toLowerCase();
    if (eq.contains('barbell') || eq.contains('olympic') || eq.contains('cable')) {
      return 'intermediate';
    }
    return 'beginner';
  }

  String _inferMechanic(
    String name,
    List<String> primaryMuscles,
    List<String> secondaryMuscles,
  ) {
    final n = name.toLowerCase();
    const compoundMoves = [
      'squat',
      'deadlift',
      'press',
      'row',
      'pull up',
      'pull-up',
      'chin up',
      'chin-up',
      'lunge',
      'dip',
      'thruster',
      'clean',
      'snatch',
      'push up',
      'push-up',
    ];
    if (compoundMoves.any(n.contains)) return 'compound';
    // Movements that recruit several muscle groups are treated as compound.
    if (secondaryMuscles.length >= 2) return 'compound';
    return 'isolation';
  }

  List<String> _gifPrimaryMuscles(Map<String, dynamic> gifExercise) {
    final muscles = <String>[];
    final target = '${gifExercise['target'] ?? ''}'.trim();
    if (target.isNotEmpty) {
      muscles.add(target);
    }
    final group = '${gifExercise['muscle_group'] ?? ''}'.trim();
    if (group.isNotEmpty && group.toLowerCase() != target.toLowerCase()) {
      muscles.add(group);
    }
    return muscles;
  }

  List<String> _gifInstructions(Map<String, dynamic> gifExercise) {
    final steps = gifExercise['instruction_steps'];
    if (steps is Map && steps['en'] != null) {
      return _sanitizeStringList(steps['en']);
    }
    final instructions = gifExercise['instructions'];
    if (instructions is Map && instructions['en'] != null) {
      return _sanitizeStringList(instructions['en']);
    }
    return _sanitizeStringList(instructions);
  }

  String _normalizeExerciseName(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  Future<Object?> _getJson(Uri uri) async {
    return _runWithRetries<Object?>(() async {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 30);
      try {
        final request = await client.getUrl(uri);
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        final response = await request.close();
        final body = await utf8.decodeStream(response);
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException(
            'Unexpected status ${response.statusCode} for $uri',
            uri: uri,
          );
        }
        return jsonDecode(body);
      } finally {
        client.close(force: true);
      }
    });
  }

  int _resolveImageLibraryTotalBytes(ExerciseLibraryManifest manifest) {
    if (manifest.totalImageBytes > 0) {
      return manifest.totalImageBytes;
    }

    if (manifest.totalImages > 0) {
      final averageImageBytes =
          _defaultImageLibraryTotalBytes / _defaultImageLibraryImageCount;
      return (manifest.totalImages * averageImageBytes).round();
    }

    return _defaultImageLibraryTotalBytes;
  }

  String _libraryDownloadProgressMessage({
    required int downloadedBytes,
    required int totalBytes,
  }) {
    return 'Downloading exercise libraries (${_formatMegabytes(downloadedBytes)}/${_formatMegabytes(totalBytes)} downloaded)…';
  }

  String _formatMegabytes(int bytes) {
    final megabytes = bytes / (1024 * 1024);
    return '${megabytes.toStringAsFixed(1)} MB';
  }

  Future<int> _downloadFile(Uri uri, File file) async {
    await file.parent.create(recursive: true);
    return _runWithRetries<int>(() async {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 30);
      final tempFile = File('${file.path}.part');
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      try {
        final request = await client.getUrl(uri);
        final response = await request.close();
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException(
            'Unexpected status ${response.statusCode} for $uri',
            uri: uri,
          );
        }
        final sink = tempFile.openWrite();
        try {
          await response.listen(sink.add).asFuture<void>();
        } finally {
          await sink.close();
        }
        final downloadedLength = await tempFile.length();
        if (await file.exists()) {
          await file.delete();
        }
        await tempFile.rename(file.path);
        return downloadedLength;
      } catch (_) {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        rethrow;
      } finally {
        client.close(force: true);
      }
    });
  }

  Future<File> _localDatasetFile() async {
    final dir = await _libraryDir();
    return File(p.join(dir.path, _datasetFileName));
  }

  Future<Directory> _localImagesDir() async {
    final dir = await _libraryDir();
    final imageDir = Directory(p.join(dir.path, 'images'));
    await imageDir.create(recursive: true);
    return imageDir;
  }

  Future<Directory> _libraryDir() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, 'exercise_library'));
    await dir.create(recursive: true);
    return dir;
  }

  List<String> _sanitizeStringList(Object? value) {
    final seen = <String>{};
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? const <String>[] : <String>[trimmed];
    }
    if (value is! List) {
      return const <String>[];
    }

    return value
        .map((entry) => '$entry'.trim())
        .where((entry) => entry.isNotEmpty)
        .where(seen.add)
        .toList(growable: false);
  }

  String _sanitizeRelativePath(String value) {
    return value.replaceAll('\\', '/').trim();
  }

  String _slugify(String value) {
    final collapsed = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return collapsed.isEmpty ? 'exercise' : collapsed;
  }

  Future<T> _runWithRetries<T>(
    Future<T> Function() action, {
    int maxAttempts = 3,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await action();
      } catch (error) {
        lastError = error;
        if (attempt == maxAttempts || !_isTransientNetworkError(error)) {
          rethrow;
        }
        await Future<void>.delayed(Duration(seconds: attempt * 2));
      }
    }

    throw lastError!;
  }

  bool _isTransientNetworkError(Object error) {
    if (error is SocketException) {
      return true;
    }
    if (error is HttpException) {
      final message = error.message.toLowerCase();
      return message.contains('abort') ||
          message.contains('connection') ||
          message.contains('timed out') ||
          message.contains('handshake');
    }

    final message = error.toString().toLowerCase();
    return message.contains('software caused connection abort') ||
        message.contains('connection reset by peer') ||
        message.contains('connection closed before full header') ||
        message.contains('network is unreachable');
  }

  String _friendlySyncErrorMessage(Object error) {
    if (_isTransientNetworkError(error)) {
      return 'The exercise library download was interrupted. Reopen FitForge or tap Download Now to resume.';
    }
    return 'FitForge could not finish downloading the exercise library. Please try again.';
  }
}

class _ImageDownloadTask {
  const _ImageDownloadTask({required this.uri, required this.file});

  final Uri uri;
  final File file;
}
