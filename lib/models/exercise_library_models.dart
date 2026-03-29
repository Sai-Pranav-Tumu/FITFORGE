class ExerciseLibraryManifest {
  const ExerciseLibraryManifest({
    required this.version,
    required this.generatedAt,
    required this.totalExercises,
    required this.totalImages,
    required this.datasetUrl,
    required this.imageBaseUrl,
  });

  final String version;
  final DateTime generatedAt;
  final int totalExercises;
  final int totalImages;
  final String datasetUrl;
  final String imageBaseUrl;

  factory ExerciseLibraryManifest.fromJson(Map<String, dynamic> json) {
    return ExerciseLibraryManifest(
      version: json['version'] as String? ?? 'unknown',
      generatedAt:
          DateTime.tryParse(json['generatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      totalExercises: (json['totalExercises'] as num?)?.toInt() ?? 0,
      totalImages: (json['totalImages'] as num?)?.toInt() ?? 0,
      datasetUrl: json['datasetUrl'] as String? ?? '',
      imageBaseUrl: json['imageBaseUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'version': version,
      'generatedAt': generatedAt.toUtc().toIso8601String(),
      'totalExercises': totalExercises,
      'totalImages': totalImages,
      'datasetUrl': datasetUrl,
      'imageBaseUrl': imageBaseUrl,
    };
  }
}

class ExerciseDefinition {
  const ExerciseDefinition({
    required this.id,
    required this.name,
    required this.force,
    required this.level,
    required this.mechanic,
    required this.equipment,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    required this.instructions,
    required this.category,
    required this.images,
    this.imageSource = 'asset',
  });

  final String id;
  final String name;
  final String force;
  final String level;
  final String mechanic;
  final String equipment;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final List<String> instructions;
  final String category;
  final List<String> images;
  final String imageSource;

  bool get hasImages => images.isNotEmpty;

  factory ExerciseDefinition.fromJson(Map<String, dynamic> json) {
    return ExerciseDefinition(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      force: json['force'] as String? ?? '',
      level: json['level'] as String? ?? '',
      mechanic: json['mechanic'] as String? ?? '',
      equipment: json['equipment'] as String? ?? '',
      primaryMuscles: _readStringList(json['primaryMuscles']),
      secondaryMuscles: _readStringList(json['secondaryMuscles']),
      instructions: _readStringList(json['instructions']),
      category: json['category'] as String? ?? '',
      images: _readStringList(json['images']),
      imageSource: json['imageSource'] as String? ?? 'asset',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'force': force,
      'level': level,
      'mechanic': mechanic,
      'equipment': equipment,
      'primaryMuscles': primaryMuscles,
      'secondaryMuscles': secondaryMuscles,
      'instructions': instructions,
      'category': category,
      'images': images,
      'imageSource': imageSource,
    };
  }

  ExerciseDefinition copyWith({
    String? id,
    String? name,
    String? force,
    String? level,
    String? mechanic,
    String? equipment,
    List<String>? primaryMuscles,
    List<String>? secondaryMuscles,
    List<String>? instructions,
    String? category,
    List<String>? images,
    String? imageSource,
  }) {
    return ExerciseDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      force: force ?? this.force,
      level: level ?? this.level,
      mechanic: mechanic ?? this.mechanic,
      equipment: equipment ?? this.equipment,
      primaryMuscles: primaryMuscles ?? this.primaryMuscles,
      secondaryMuscles: secondaryMuscles ?? this.secondaryMuscles,
      instructions: instructions ?? this.instructions,
      category: category ?? this.category,
      images: images ?? this.images,
      imageSource: imageSource ?? this.imageSource,
    );
  }
}

List<String> _readStringList(Object? value) {
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
