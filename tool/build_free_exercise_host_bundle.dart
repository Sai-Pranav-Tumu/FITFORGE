import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  final config = _Config.fromArgs(args);

  if (config.showHelp) {
    _printUsage();
    return;
  }

  final sourceDir = Directory(config.sourceDir);
  if (!await sourceDir.exists()) {
    stderr.writeln('Source directory not found: ${sourceDir.path}');
    exitCode = 64;
    return;
  }

  final distFile = File(_join(sourceDir.path, r'dist\exercises.json'));
  if (!await distFile.exists()) {
    stderr.writeln('Could not find dist/exercises.json in ${sourceDir.path}');
    exitCode = 64;
    return;
  }

  final outDir = Directory(config.outDir);
  await outDir.create(recursive: true);

  final exercisesOut = File(_join(outDir.path, 'exercises.json'));
  await distFile.copy(exercisesOut.path);

  final exercisesSourceDir = Directory(_join(sourceDir.path, 'exercises'));
  final exercisesTargetDir = Directory(_join(outDir.path, 'exercises'));
  if (await exercisesTargetDir.exists()) {
    await exercisesTargetDir.delete(recursive: true);
  }
  await exercisesTargetDir.create(recursive: true);

  final imageFiles = await exercisesSourceDir
      .list(recursive: true)
      .where((entity) => entity is File)
      .cast<File>()
      .where(
        (file) =>
            file.path.toLowerCase().endsWith('.jpg') ||
            file.path.toLowerCase().endsWith('.jpeg') ||
            file.path.toLowerCase().endsWith('.png') ||
            file.path.toLowerCase().endsWith('.webp'),
      )
      .toList();

  for (final file in imageFiles) {
    final relative = p.relative(file.path, from: exercisesSourceDir.path);
    final target = File(_join(exercisesTargetDir.path, relative));
    await target.parent.create(recursive: true);
    await file.copy(target.path);
  }

  final exercisesRaw = jsonDecode(await exercisesOut.readAsString());
  final totalExercises = exercisesRaw is List ? exercisesRaw.length : 0;

  final manifest = <String, dynamic>{
    'version': config.version,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'totalExercises': totalExercises,
    'totalImages': imageFiles.length,
    'datasetUrl': config.datasetUrl,
    'imageBaseUrl': config.imageBaseUrl,
  };

  final manifestFile = File(_join(outDir.path, 'manifest.json'));
  const encoder = JsonEncoder.withIndent('  ');
  await manifestFile.writeAsString('${encoder.convert(manifest)}\n');

  stdout.writeln('Built hosting bundle at ${outDir.path}');
  stdout.writeln('Exercises: $totalExercises');
  stdout.writeln('Images: ${imageFiles.length}');
}

class _Config {
  _Config({
    required this.sourceDir,
    required this.outDir,
    required this.datasetUrl,
    required this.imageBaseUrl,
    required this.version,
    required this.showHelp,
  });

  final String sourceDir;
  final String outDir;
  final String datasetUrl;
  final String imageBaseUrl;
  final String version;
  final bool showHelp;

  factory _Config.fromArgs(List<String> args) {
    var sourceDir = '';
    var outDir = 'exercise_library/free_exercise_db';
    var datasetUrl = 'exercises.json';
    var imageBaseUrl = 'exercises/';
    var version = DateTime.now().toUtc().toIso8601String().split('T').first;
    var showHelp = false;

    for (final arg in args) {
      if (arg == '--help' || arg == '-h') {
        showHelp = true;
      } else if (arg.startsWith('--source-dir=')) {
        sourceDir = arg.substring('--source-dir='.length);
      } else if (arg.startsWith('--out-dir=')) {
        outDir = arg.substring('--out-dir='.length);
      } else if (arg.startsWith('--dataset-url=')) {
        datasetUrl = arg.substring('--dataset-url='.length);
      } else if (arg.startsWith('--image-base-url=')) {
        imageBaseUrl = arg.substring('--image-base-url='.length);
      } else if (arg.startsWith('--version=')) {
        version = arg.substring('--version='.length);
      } else {
        throw ArgumentError('Unknown argument: $arg');
      }
    }

    return _Config(
      sourceDir: sourceDir,
      outDir: outDir,
      datasetUrl: datasetUrl,
      imageBaseUrl: imageBaseUrl,
      version: version,
      showHelp: showHelp,
    );
  }
}

String _join(String left, String right) {
  if (left.endsWith(Platform.pathSeparator)) {
    return '$left$right';
  }
  return '$left${Platform.pathSeparator}$right';
}

void _printUsage() {
  stdout.writeln('''
Builds a GitHub-hostable exercise bundle and manifest from a free-exercise-db checkout.

Usage:
  dart run tool/build_free_exercise_host_bundle.dart --source-dir=PATH

Options:
  --source-dir=PATH       Path to the downloaded free-exercise-db folder.
  --out-dir=PATH          Output directory. Default: exercise_library/free_exercise_db
  --dataset-url=URL       Dataset URL inside the manifest. Default: exercises.json
  --image-base-url=URL    Image base URL inside the manifest. Default: exercises/
  --version=VALUE         Version label for the manifest
  --help, -h              Show this help message.
''');
}
