import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

  final downloader = ExerciseDbDownloader(
    apiKey: apiKey.trim(),
    host: config.host,
    outDir: Directory(config.outDir),
    concurrency: config.concurrency,
    pageSize: config.pageSize,
    force: config.force,
  );

  try {
    await downloader.run();
  } on ProcessException catch (error) {
    stderr.writeln(error.message);
    exitCode = error.errorCode;
  } catch (error, stackTrace) {
    stderr.writeln('Download failed: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}

class ExerciseDbDownloader {
  ExerciseDbDownloader({
    required this.apiKey,
    required this.host,
    required this.outDir,
    required this.concurrency,
    required this.pageSize,
    required this.force,
  });

  final String apiKey;
  final String host;
  final Directory outDir;
  final int concurrency;
  final int pageSize;
  final bool force;

  late final Directory _gifsDir = Directory(_join(outDir.path, 'gifs'));

  Future<void> run() async {
    stdout.writeln('Preparing output directory: ${outDir.path}');
    await outDir.create(recursive: true);
    await _gifsDir.create(recursive: true);

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final exercises = await _fetchExercises(client);
      stdout.writeln('Fetched ${exercises.length} exercises from ExerciseDB.');

      final normalized = _normalizeExercises(exercises);
      final gifTasks = _buildGifTasks(normalized);
      final gifFailures = await _downloadGifs(client, gifTasks);
      final stats = _buildStats(normalized, gifFailures);
      final exercisesWithGifUrls = normalized
          .where((exercise) => (exercise['gifUrl'] as String? ?? '').isNotEmpty)
          .length;

      await _writeJson(
        File(_join(outDir.path, 'raw_exercises.json')),
        exercises,
      );
      await _writeJson(File(_join(outDir.path, 'exercises.json')), normalized);
      await _writeJson(File(_join(outDir.path, 'exercise_index.json')), {
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
        'host': host,
        'pageSize': pageSize,
        'totalExercises': normalized.length,
        'exercisesWithGifUrls': exercisesWithGifUrls,
        'downloadedGifs': stats.downloadedGifs,
        'missingGifs': stats.missingGifs,
        'bodyParts': stats.bodyParts,
        'equipment': stats.equipment,
        'targets': stats.targets,
      });

      stdout.writeln('');
      stdout.writeln('Finished.');
      stdout.writeln('Exercises JSON: ${_join(outDir.path, 'exercises.json')}');
      stdout.writeln('GIF folder: ${_gifsDir.path}');
      if (exercisesWithGifUrls == 0) {
        stdout.writeln(
          'The current RapidAPI ExerciseDB responses did not include gifUrl fields, so no GIFs were downloaded.',
        );
      }
      if (gifFailures.isNotEmpty) {
        stdout.writeln('GIF download failures: ${gifFailures.length}');
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchExercises(HttpClient client) async {
    final allExercises = <Map<String, dynamic>>[];
    final seenIds = <String>{};
    Object? lastError;
    var offset = 0;

    while (true) {
      final uri = Uri.https(host, '/exercises', {
        'limit': '$pageSize',
        'offset': '$offset',
      });

      try {
        stdout.writeln('Fetching exercise list from $uri');
        final response = await _getJson(client, uri);
        if (response is List) {
          final page = response
              .whereType<Map>()
              .map(
                (entry) => entry.map((key, value) => MapEntry('$key', value)),
              )
              .toList();

          if (page.isEmpty) {
            break;
          }

          var addedOnPage = 0;
          for (final entry in page) {
            final id = '${entry['id'] ?? ''}'.trim();
            if (id.isEmpty || seenIds.add(id)) {
              allExercises.add(entry);
              addedOnPage++;
            }
          }

          if (addedOnPage == 0) {
            break;
          }

          offset += page.length;
          continue;
        }
      } on _RateLimitException catch (error) {
        throw ProcessException(
          'dart',
          ['tool/download_exercisedb.dart'],
          'RapidAPI rate limit or quota reached (${error.statusCode}) for $uri. ${error.message}',
          error.statusCode,
        );
      } catch (error) {
        lastError = error;
        break;
      }
    }

    if (allExercises.isNotEmpty) {
      return allExercises;
    }

    throw ProcessException(
      'dart',
      ['run', 'tool/download_exercisedb.dart'],
      'Unable to fetch exercises from RapidAPI. Last error: $lastError',
      1,
    );
  }

  List<Map<String, dynamic>> _normalizeExercises(
    List<Map<String, dynamic>> exercises,
  ) {
    return exercises.map((exercise) {
      final id = '${exercise['id'] ?? ''}'.trim();
      final name = '${exercise['name'] ?? 'exercise'}'.trim();
      final gifUrl = '${exercise['gifUrl'] ?? ''}'.trim();
      final slug = _slugify('$id-$name');
      final gifExtension = _guessExtension(gifUrl);
      final gifRelativePath = gifUrl.isEmpty
          ? null
          : 'assets/database/exercisedb/gifs/$slug$gifExtension';

      return <String, dynamic>{
        'id': id,
        'name': name,
        'bodyPart': '${exercise['bodyPart'] ?? ''}'.trim(),
        'target': '${exercise['target'] ?? ''}'.trim(),
        'equipment': '${exercise['equipment'] ?? ''}'.trim(),
        'secondaryMuscles': _toStringList(exercise['secondaryMuscles']),
        'instructions': _toStringList(exercise['instructions']),
        'gifUrl': gifUrl,
        'gifLocalPath': gifRelativePath,
        'source': {
          'provider': 'RapidAPI',
          'dataset': 'ExerciseDB',
          'host': host,
        },
      };
    }).toList();
  }

  List<_GifTask> _buildGifTasks(List<Map<String, dynamic>> exercises) {
    final tasks = <_GifTask>[];
    final seenUrls = <String>{};

    for (final exercise in exercises) {
      final gifUrl = exercise['gifUrl'] as String? ?? '';
      final gifLocalPath = exercise['gifLocalPath'] as String?;
      if (gifUrl.isEmpty || gifLocalPath == null || !seenUrls.add(gifUrl)) {
        continue;
      }

      final localFile = File(
        _join(
          outDir.path,
          gifLocalPath.replaceFirst('assets/database/exercisedb/', ''),
        ),
      );

      tasks.add(_GifTask(url: Uri.parse(gifUrl), file: localFile));
    }

    return tasks;
  }

  Future<Set<String>> _downloadGifs(
    HttpClient client,
    List<_GifTask> tasks,
  ) async {
    if (tasks.isEmpty) {
      return <String>{};
    }

    stdout.writeln('Downloading ${tasks.length} GIF files...');

    final failures = <String>{};
    var nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        final currentIndex = nextIndex++;
        if (currentIndex >= tasks.length) {
          return;
        }

        final task = tasks[currentIndex];
        final alreadyExists = await task.file.exists();
        if (alreadyExists && !force && (await task.file.length()) > 0) {
          stdout.writeln(
            '[skip ${currentIndex + 1}/${tasks.length}] ${task.file.path}',
          );
          continue;
        }

        try {
          await _downloadFile(client, task.url, task.file);
          stdout.writeln(
            '[ok ${currentIndex + 1}/${tasks.length}] ${task.file.path}',
          );
        } catch (error) {
          failures.add(task.url.toString());
          stderr.writeln(
            '[fail ${currentIndex + 1}/${tasks.length}] ${task.url} -> $error',
          );
        }
      }
    }

    final workers = List.generate(
      concurrency < 1 ? 1 : concurrency,
      (_) => worker(),
    );
    await Future.wait(workers);
    return failures;
  }

  Future<void> _downloadFile(HttpClient client, Uri uri, File file) async {
    await file.parent.create(recursive: true);

    final tempFile = File('${file.path}.part');
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final request = await client.getUrl(uri);
        final response = await request.close();

        if (response.statusCode != HttpStatus.ok) {
          throw HttpException(
            'Unexpected status ${response.statusCode}',
            uri: uri,
          );
        }

        final sink = tempFile.openWrite();
        await response.listen(sink.add).asFuture<void>();
        await sink.close();

        if (await file.exists()) {
          await file.delete();
        }
        await tempFile.rename(file.path);
        return;
      } catch (error) {
        if (attempt == 3) {
          rethrow;
        }
        await Future<void>.delayed(Duration(seconds: attempt));
      }
    }
  }

  Future<Object?> _getJson(HttpClient client, Uri uri) async {
    final request = await client.getUrl(uri);
    request.headers.set('x-rapidapi-key', apiKey);
    request.headers.set('x-rapidapi-host', host);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');

    final response = await request.close();
    final body = await utf8.decodeStream(response);

    if (response.statusCode == HttpStatus.tooManyRequests) {
      throw _RateLimitException(statusCode: response.statusCode, message: body);
    }

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

  _DatasetStats _buildStats(
    List<Map<String, dynamic>> exercises,
    Set<String> gifFailures,
  ) {
    final bodyParts = <String, int>{};
    final equipment = <String, int>{};
    final targets = <String, int>{};

    for (final exercise in exercises) {
      _increment(bodyParts, exercise['bodyPart'] as String? ?? '');
      _increment(equipment, exercise['equipment'] as String? ?? '');
      _increment(targets, exercise['target'] as String? ?? '');
    }

    return _DatasetStats(
      downloadedGifs: exercises.where((exercise) {
        final url = exercise['gifUrl'] as String? ?? '';
        return url.isNotEmpty && !gifFailures.contains(url);
      }).length,
      missingGifs: gifFailures.length,
      bodyParts: _sortedCountMap(bodyParts),
      equipment: _sortedCountMap(equipment),
      targets: _sortedCountMap(targets),
    );
  }
}

class _Config {
  _Config({
    required this.apiKey,
    required this.host,
    required this.outDir,
    required this.concurrency,
    required this.pageSize,
    required this.force,
    required this.showHelp,
  });

  final String? apiKey;
  final String host;
  final String outDir;
  final int concurrency;
  final int pageSize;
  final bool force;
  final bool showHelp;

  factory _Config.fromArgs(List<String> args) {
    String? apiKey;
    var host = 'exercisedb.p.rapidapi.com';
    var outDir = 'assets/database/exercisedb';
    var concurrency = 6;
    var pageSize = 100;
    var force = false;
    var showHelp = false;

    for (final arg in args) {
      if (arg == '--help' || arg == '-h') {
        showHelp = true;
      } else if (arg == '--force') {
        force = true;
      } else if (arg.startsWith('--api-key=')) {
        apiKey = arg.substring('--api-key='.length);
      } else if (arg.startsWith('--host=')) {
        host = arg.substring('--host='.length);
      } else if (arg.startsWith('--out-dir=')) {
        outDir = arg.substring('--out-dir='.length);
      } else if (arg.startsWith('--concurrency=')) {
        concurrency =
            int.tryParse(arg.substring('--concurrency='.length)) ?? concurrency;
      } else if (arg.startsWith('--page-size=')) {
        pageSize = int.tryParse(arg.substring('--page-size='.length)) ?? pageSize;
      } else {
        throw ProcessException(
          'dart',
          ['run', 'tool/download_exercisedb.dart', ...args],
          'Unknown argument: $arg',
          64,
        );
      }
    }

    return _Config(
      apiKey: apiKey,
      host: host,
      outDir: outDir,
      concurrency: concurrency,
      pageSize: pageSize,
      force: force,
      showHelp: showHelp,
    );
  }
}

class _GifTask {
  const _GifTask({required this.url, required this.file});

  final Uri url;
  final File file;
}

class _DatasetStats {
  const _DatasetStats({
    required this.downloadedGifs,
    required this.missingGifs,
    required this.bodyParts,
    required this.equipment,
    required this.targets,
  });

  final int downloadedGifs;
  final int missingGifs;
  final Map<String, int> bodyParts;
  final Map<String, int> equipment;
  final Map<String, int> targets;
}

class _RateLimitException implements Exception {
  const _RateLimitException({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  @override
  String toString() => 'Rate limit reached ($statusCode): $message';
}

void _increment(Map<String, int> counts, String value) {
  final key = value.trim().isEmpty ? 'unknown' : value.trim();
  counts.update(key, (existing) => existing + 1, ifAbsent: () => 1);
}

Map<String, int> _sortedCountMap(Map<String, int> input) {
  final entries = input.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      if (byCount != 0) {
        return byCount;
      }
      return a.key.compareTo(b.key);
    });

  return {for (final entry in entries) entry.key: entry.value};
}

String _guessExtension(String url) {
  final lower = url.toLowerCase();
  if (lower.endsWith('.webp')) return '.webp';
  if (lower.endsWith('.png')) return '.png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return '.jpg';
  return '.gif';
}

List<String> _toStringList(Object? value) {
  if (value is List) {
    return value
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const [];
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
Downloads the ExerciseDB dataset and GIF assets from RapidAPI into this repo.

Usage:
  dart run tool/download_exercisedb.dart --api-key=YOUR_KEY

Options:
  --api-key=KEY         RapidAPI key. You can also set RAPIDAPI_KEY.
  --host=HOST           RapidAPI host. Default: exercisedb.p.rapidapi.com
  --out-dir=PATH        Output directory. Default: assets/database/exercisedb
  --concurrency=NUMBER  Parallel GIF downloads. Default: 6
  --page-size=NUMBER    Exercise page size. Default: 100
  --force               Re-download GIF files even if they already exist.
  --help, -h            Show this help message.
''');
}
