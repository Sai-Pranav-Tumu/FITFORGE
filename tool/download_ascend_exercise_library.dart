import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  final config = _Config.fromArgs(args);

  if (config.showHelp) {
    _printUsage();
    return;
  }

  final apiKey = config.apiKey ?? Platform.environment['RAPIDAPI_KEY'];
  if (apiKey == null || apiKey.trim().isEmpty) {
    stderr.writeln(
      'Missing RapidAPI key. Pass --api-key=YOUR_KEY or set RAPIDAPI_KEY.',
    );
    exitCode = 64;
    return;
  }

  final downloader = AscendExerciseLibraryDownloader(
    apiKey: apiKey.trim(),
    host: config.host,
    exercisesPath: config.exercisesPath,
    outDir: Directory(config.outDir),
    includeDetails: config.includeDetails,
    force: config.force,
  );

  try {
    await downloader.run();
  } catch (error, stackTrace) {
    stderr.writeln('Download failed: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}

class AscendExerciseLibraryDownloader {
  AscendExerciseLibraryDownloader({
    required this.apiKey,
    required this.host,
    required this.exercisesPath,
    required this.outDir,
    required this.includeDetails,
    required this.force,
  });

  final String apiKey;
  final String host;
  final String exercisesPath;
  final Directory outDir;
  final bool includeDetails;
  final bool force;

  late final Directory _mediaDir = Directory(_join(outDir.path, 'media'));

  Future<void> run() async {
    await outDir.create(recursive: true);
    await _mediaDir.create(recursive: true);

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final rawExercises = await _fetchAllExercises(client);
      final normalized = <Map<String, dynamic>>[];
      final tasks = <_MediaTask>[];
      final seenRemoteUrls = <String>{};

      for (final exercise in rawExercises) {
        final normalizedExercise = _normalizeExercise(exercise);
        normalized.add(normalizedExercise);

        final media = (normalizedExercise['media'] as List<dynamic>)
            .whereType<Map<String, dynamic>>();
        for (final item in media) {
          final remoteUrl = item['remoteUrl'] as String? ?? '';
          final relativePath = item['relativePath'] as String? ?? '';
          if (remoteUrl.isEmpty ||
              relativePath.isEmpty ||
              !seenRemoteUrls.add(remoteUrl)) {
            continue;
          }

          tasks.add(
            _MediaTask(
              url: Uri.parse(remoteUrl),
              file: File(p.join(_mediaDir.path, relativePath)),
            ),
          );
        }
      }

      final failures = await _downloadMedia(client, tasks);
      final version = DateTime.now().toUtc().toIso8601String();

      await _writeJson(
        File(_join(outDir.path, 'raw_exercises.json')),
        rawExercises,
      );
      await _writeJson(File(_join(outDir.path, 'exercises.json')), normalized);
      await _writeJson(File(_join(outDir.path, 'manifest.json')), {
        'version': version,
        'generatedAt': version,
        'totalExercises': normalized.length,
        'totalMediaFiles': tasks.length - failures.length,
        'exercisesFile': 'exercises.json',
        'mediaBasePath': 'media/',
        'source': {'provider': 'RapidAPI', 'host': host, 'path': exercisesPath},
      });

      stdout.writeln('Finished ASCEND library export.');
      stdout.writeln('Exercises: ${normalized.length}');
      stdout.writeln(
        'Media files downloaded: ${tasks.length - failures.length}',
      );
      stdout.writeln('Output folder: ${outDir.path}');
    } finally {
      client.close(force: true);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAllExercises(HttpClient client) async {
    final all = <Map<String, dynamic>>[];
    final seenCursors = <String>{};
    String? cursor;
    while (true) {
      final query = <String, String>{};
      if (cursor != null && cursor.isNotEmpty) {
        query['cursor'] = cursor;
      }
      final uri = Uri.https(host, exercisesPath, query);
      stdout.writeln('Fetching $uri');

      final body = await _getJson(client, uri);
      final page = _unwrapAscendList(body);
      if (page == null || page.items.isEmpty) {
        break;
      }

      for (final item in page.items) {
        final exerciseId = '${item['exerciseId'] ?? ''}'.trim();
        if (exerciseId.isEmpty) {
          continue;
        }

        if (!includeDetails) {
          all.add(item);
          continue;
        }

        final detail = await _fetchExerciseDetail(client, exerciseId);
        all.add(detail ?? item);
      }

      if (!page.hasNextPage || page.nextCursor == null || page.nextCursor!.isEmpty) {
        break;
      }
      if (!seenCursors.add(page.nextCursor!)) {
        stdout.writeln(
          'Stopping pagination because the API repeated cursor ${page.nextCursor}.',
        );
        break;
      }
      cursor = page.nextCursor;
    }

    return all;
  }

  Future<Map<String, dynamic>?> _fetchExerciseDetail(
    HttpClient client,
    String exerciseId,
  ) async {
    final uri = Uri.https(host, '$exercisesPath/$exerciseId');
    stdout.writeln('Fetching detail $uri');
    final body = await _getJson(client, uri);
    if (body is Map<String, dynamic>) {
      if (body['data'] is Map) {
        return (body['data'] as Map).cast<String, dynamic>();
      }
      return body;
    }
    return null;
  }

  Map<String, dynamic> _normalizeExercise(Map<String, dynamic> exercise) {
    final id =
        '${exercise['exerciseId'] ?? exercise['id'] ?? ''}'.trim();
    final name = '${exercise['name'] ?? ''}'.trim();
    final media = _extractMedia(exercise, id, name);

    return <String, dynamic>{
      'id': id,
      'exerciseId': id,
      'name': name,
      'bodyPart': _firstString(exercise['bodyParts'] ?? exercise['bodyPart']),
      'bodyParts': _stringList(exercise['bodyParts'] ?? exercise['bodyPart']),
      'target': _firstString(exercise['targetMuscles'] ?? exercise['target']),
      'targetMuscles': _stringList(exercise['targetMuscles'] ?? exercise['target']),
      'equipment': _firstString(exercise['equipments'] ?? exercise['equipment']),
      'equipments': _stringList(exercise['equipments'] ?? exercise['equipment']),
      'secondaryMuscles': _stringList(exercise['secondaryMuscles']),
      'instructions': _stringList(exercise['instructions']),
      'description':
          '${exercise['overview'] ?? exercise['description'] ?? ''}'.trim(),
      'difficulty': '${exercise['difficulty'] ?? ''}'.trim(),
      'category':
          '${exercise['exerciseType'] ?? exercise['category'] ?? ''}'.trim(),
      'keywords': _stringList(exercise['keywords']),
      'variations': _stringList(exercise['variations']),
      'exerciseTips': _stringList(exercise['exerciseTips']),
      'relatedExerciseIds': _stringList(exercise['relatedExerciseIds']),
      'media': media.map((entry) => entry.toJson()).toList(growable: false),
      'raw': exercise,
    };
  }

  List<_ExerciseMedia> _extractMedia(
    Map<String, dynamic> exercise,
    String id,
    String name,
  ) {
    final found = <_ExerciseMedia>[];
    final seen = <String>{};

    void visit(String role, Object? value) {
      if (value is String) {
        final trimmed = value.trim();
        if (_looksLikeMediaUrl(trimmed) && seen.add(trimmed)) {
          final uri = Uri.tryParse(trimmed);
          final extension = _extensionFromUri(uri);
          final kind = _kindFromExtension(extension);
          found.add(
            _ExerciseMedia(
              kind: kind,
              role: role,
              remoteUrl: trimmed,
              relativePath:
                  '${_slugify('$id-$name')}/${_slugify(role)}$extension',
              contentType: _contentTypeFromExtension(extension),
            ),
          );
        }
      } else if (value is Map) {
        for (final entry in value.entries) {
          visit('${role}_${entry.key}', entry.value);
        }
      } else if (value is List) {
        for (var i = 0; i < value.length; i++) {
          visit('${role}_$i', value[i]);
        }
      }
    }

    for (final entry in exercise.entries) {
      visit('${entry.key}', entry.value);
    }

    return found;
  }

  Future<Set<String>> _downloadMedia(
    HttpClient client,
    List<_MediaTask> tasks,
  ) async {
    final failures = <String>{};
    var index = 0;

    for (final task in tasks) {
      index++;
      final exists = await task.file.exists();
      if (exists && !force && await task.file.length() > 0) {
        stdout.writeln('[skip $index/${tasks.length}] ${task.file.path}');
        continue;
      }

      try {
        await _downloadFile(client, task.url, task.file);
        stdout.writeln('[ok $index/${tasks.length}] ${task.file.path}');
      } catch (error) {
        failures.add(task.url.toString());
        stderr.writeln('[fail $index/${tasks.length}] ${task.url} -> $error');
      }
    }

    return failures;
  }

  Future<void> _downloadFile(HttpClient client, Uri uri, File file) async {
    await file.parent.create(recursive: true);
    final tempFile = File('${file.path}.part');
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Unexpected status ${response.statusCode}', uri: uri);
    }

    final sink = tempFile.openWrite();
    await response.listen(sink.add).asFuture<void>();
    await sink.close();

    if (await file.exists()) {
      await file.delete();
    }
    await tempFile.rename(file.path);
  }

  Future<Object?> _getJson(HttpClient client, Uri uri) async {
    final request = await client.getUrl(uri);
    request.headers.set('x-rapidapi-key', apiKey);
    request.headers.set('x-rapidapi-host', host);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');

    final response = await request.close();
    final body = await utf8.decodeStream(response);
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'RapidAPI returned ${response.statusCode}: $body',
        uri: uri,
      );
    }
    return jsonDecode(body);
  }

  Future<void> _writeJson(File file, Object value) async {
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString('${encoder.convert(value)}\n');
  }
}

class _Config {
  _Config({
    required this.apiKey,
    required this.host,
    required this.exercisesPath,
    required this.outDir,
    required this.includeDetails,
    required this.force,
    required this.showHelp,
  });

  final String? apiKey;
  final String host;
  final String exercisesPath;
  final String outDir;
  final bool includeDetails;
  final bool force;
  final bool showHelp;

  factory _Config.fromArgs(List<String> args) {
    String? apiKey;
    var host = 'edb-with-videos-and-images-by-ascendapi.p.rapidapi.com';
    var exercisesPath = '/api/v1/exercises';
    var outDir = 'exercise_library/ascend';
    var includeDetails = false;
    var force = false;
    var showHelp = false;

    for (final arg in args) {
      if (arg == '--help' || arg == '-h') {
        showHelp = true;
      } else if (arg == '--with-details') {
        includeDetails = true;
      } else if (arg == '--force') {
        force = true;
      } else if (arg.startsWith('--api-key=')) {
        apiKey = arg.substring('--api-key='.length);
      } else if (arg.startsWith('--host=')) {
        host = arg.substring('--host='.length);
      } else if (arg.startsWith('--exercises-path=')) {
        exercisesPath = arg.substring('--exercises-path='.length);
      } else if (arg.startsWith('--out-dir=')) {
        outDir = arg.substring('--out-dir='.length);
      } else {
        throw ArgumentError('Unknown argument: $arg');
      }
    }

    return _Config(
      apiKey: apiKey,
      host: host,
      exercisesPath: exercisesPath,
      outDir: outDir,
      includeDetails: includeDetails,
      force: force,
      showHelp: showHelp,
    );
  }
}

class _MediaTask {
  const _MediaTask({required this.url, required this.file});

  final Uri url;
  final File file;
}

class _ExerciseMedia {
  const _ExerciseMedia({
    required this.kind,
    required this.role,
    required this.remoteUrl,
    required this.relativePath,
    required this.contentType,
  });

  final String kind;
  final String role;
  final String remoteUrl;
  final String relativePath;
  final String contentType;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kind': kind,
      'role': role,
      'remoteUrl': remoteUrl,
      'relativePath': relativePath,
      'contentType': contentType,
    };
  }
}

class _AscendPage {
  const _AscendPage({
    required this.items,
    required this.hasNextPage,
    required this.nextCursor,
  });

  final List<Map<String, dynamic>> items;
  final bool hasNextPage;
  final String? nextCursor;
}

_AscendPage? _unwrapAscendList(Object? body) {
  if (body is! Map<String, dynamic>) {
    return null;
  }

  final rawItems = body['data'];
  if (rawItems is! List) {
    return null;
  }

  final meta = body['meta'];
  return _AscendPage(
    items: rawItems
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList(growable: false),
    hasNextPage: meta is Map ? (meta['hasNextPage'] as bool? ?? false) : false,
    nextCursor: meta is Map ? meta['nextCursor'] as String? : null,
  );
}

List<String> _stringList(Object? value) {
  if (value is List) {
    return value
        .map((entry) => '$entry'.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }
  if (value is String && value.trim().isNotEmpty) {
    return <String>[value.trim()];
  }
  return const <String>[];
}

String _firstString(Object? value) {
  final list = _stringList(value);
  if (list.isEmpty) {
    return '';
  }
  return list.first;
}

bool _looksLikeMediaUrl(String value) {
  if (!(value.startsWith('http://') || value.startsWith('https://'))) {
    return false;
  }

  final lower = value.toLowerCase();
  const mediaHints = <String>[
    '.gif',
    '.mp4',
    '.mov',
    '.webm',
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '/image',
    '/video',
    '/media',
    'thumbnail',
    'preview',
  ];
  return mediaHints.any(lower.contains);
}

String _extensionFromUri(Uri? uri) {
  final path = uri?.path.toLowerCase() ?? '';
  for (final extension in <String>[
    '.gif',
    '.mp4',
    '.mov',
    '.webm',
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
  ]) {
    if (path.endsWith(extension)) {
      return extension;
    }
  }
  return '.bin';
}

String _kindFromExtension(String extension) {
  switch (extension) {
    case '.mp4':
    case '.mov':
    case '.webm':
      return 'video';
    case '.gif':
      return 'gif';
    case '.jpg':
    case '.jpeg':
    case '.png':
    case '.webp':
      return 'image';
    default:
      return 'media';
  }
}

String _contentTypeFromExtension(String extension) {
  switch (extension) {
    case '.mp4':
      return 'video/mp4';
    case '.mov':
      return 'video/quicktime';
    case '.webm':
      return 'video/webm';
    case '.gif':
      return 'image/gif';
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.png':
      return 'image/png';
    case '.webp':
      return 'image/webp';
    default:
      return 'application/octet-stream';
  }
}

String _slugify(String input) {
  final lower = input.toLowerCase().trim();
  final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return cleaned
      .replaceAll(RegExp(r'-{2,}'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}

String _join(String left, String right) {
  if (left.endsWith(Platform.pathSeparator)) {
    return '$left$right';
  }
  return '$left${Platform.pathSeparator}$right';
}

void _printUsage() {
  stdout.writeln('''
Downloads ASCEND ExerciseDB-style records and media into a GitHub-friendly folder.

Usage:
  dart run tool/download_ascend_exercise_library.dart --api-key=YOUR_KEY

Options:
  --api-key=KEY             RapidAPI key. You can also set RAPIDAPI_KEY.
  --host=HOST               RapidAPI host. Default: edb-with-videos-and-images-by-ascendapi.p.rapidapi.com
  --exercises-path=PATH     Exercise endpoint path. Default: /api/v1/exercises
  --out-dir=PATH            Output directory. Default: exercise_library/ascend
  --with-details            Fetch per-exercise detail records for videos and extra image sizes.
  --force                   Re-download media files even if they already exist.
  --help, -h                Show this help message.
''');
}
