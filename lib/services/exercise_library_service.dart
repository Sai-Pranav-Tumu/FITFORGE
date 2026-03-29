import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

  static const String manifestUrl = String.fromEnvironment(
    'FITFORGE_EXERCISE_MANIFEST_URL',
    defaultValue: _defaultManifestUrl,
  );

  static const String _versionKey = 'exercise_library_version';
  static const String _downloadConsentKey = 'exercise_library_download_consent';
  static const String _datasetFileName = 'exercises.json';

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
      final datasetFile = await _localDatasetFile();

      final shouldDownload =
          currentVersion != manifest.version || !await datasetFile.exists();
      if (!shouldDownload) {
        _hasFullDataset = true;
        _activeVersion = currentVersion ?? manifest.version;
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
        phase: 'images',
        progress: 0.22,
        message: 'Downloading exercise images…',
      );
      await _downloadAllImages(
        exercises: preparedExercises,
        imageBaseUrl: manifestUri.resolve(manifest.imageBaseUrl).toString(),
      );

      _updateDownloadState(
        phase: 'setup',
        progress: 0.92,
        message: 'Setting up your workout library…',
      );
      await datasetFile.parent.create(recursive: true);
      const encoder = JsonEncoder.withIndent('  ');
      await datasetFile.writeAsString(
        '${encoder.convert(preparedExercises)}\n',
      );
      _updateDownloadState(
        phase: 'setup',
        progress: 0.97,
        message: 'Loading personalized workouts…',
      );
      await prefs.setString(_versionKey, manifest.version);
      _activeVersion = manifest.version;
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
          totalImages: 0,
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
      totalImages: 0,
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

  Future<void> _downloadAllImages({
    required List<Map<String, dynamic>> exercises,
    required String imageBaseUrl,
  }) async {
    final imageDir = await _localImagesDir();
    final tasks = <_ImageDownloadTask>[];
    final failedImages = <String>[];
    final seen = <String>{};

    for (final exercise in exercises) {
      final images = exercise['images'];
      if (images is! List) {
        continue;
      }
      for (final image in images) {
        final relativePath = '$image'.trim();
        if (relativePath.isEmpty || !seen.add(relativePath)) {
          continue;
        }
        tasks.add(
          _ImageDownloadTask(
            uri: Uri.parse('$imageBaseUrl$relativePath'),
            file: File(p.join(imageDir.path, relativePath)),
          ),
        );
      }
    }

    if (tasks.isEmpty) {
      _updateDownloadState(
        phase: 'images',
        progress: 0.88,
        message: 'Preparing downloaded exercise files…',
      );
      return;
    }

    final totalTasks = tasks.length;
    var downloadedTasks = 0;
    const concurrency = 6;
    var next = 0;

    Future<void> worker() async {
      while (true) {
        final index = next++;
        if (index >= tasks.length) {
          return;
        }
        final task = tasks[index];
        if (await task.file.exists() && await task.file.length() > 0) {
          downloadedTasks++;
          _updateDownloadState(
            phase: 'images',
            progress: 0.22 + 0.66 * (downloadedTasks / totalTasks),
            message:
                'Downloading exercise images ($downloadedTasks/$totalTasks)…',
          );
          continue;
        }
        try {
          await _downloadFile(task.uri, task.file);
        } catch (error) {
          failedImages.add(task.uri.toString());
          debugPrint('Exercise image download failed: ${task.uri} - $error');
        }
        downloadedTasks++;
        _updateDownloadState(
          phase: 'images',
          progress: 0.22 + 0.66 * (downloadedTasks / totalTasks),
          message:
              'Downloading exercise images ($downloadedTasks/$totalTasks)…',
        );
      }
    }

    await Future.wait(List.generate(concurrency, (_) => worker()));

    if (failedImages.isNotEmpty) {
      debugPrint(
        'Exercise library finished with ${failedImages.length} image download failures.',
      );
    }
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

  Future<void> _downloadFile(Uri uri, File file) async {
    await file.parent.create(recursive: true);
    await _runWithRetries<void>(() async {
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
        if (await file.exists()) {
          await file.delete();
        }
        await tempFile.rename(file.path);
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
