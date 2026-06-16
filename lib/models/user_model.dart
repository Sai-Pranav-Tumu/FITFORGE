import '../utils/dietary_preferences.dart';

class UserModel {
  static const String defaultTargetMuscleFocus = 'Full Body';
  static const String defaultJointSensitivity = 'None';
  static const List<String> targetMuscleFocusOptions = <String>[
    defaultTargetMuscleFocus,
    'Upper Body',
    'Lower Body',
    'Core',
    'Back & Posture',
  ];
  static const List<String> jointSensitivityOptions = <String>[
    defaultJointSensitivity,
    'Knees',
    'Lower Back',
    'Shoulders',
  ];

  final String id;
  final String email;
  final String name;
  final String gender;
  final int age;
  final String occupation;
  final String sittingHours;
  final String fitnessGoal;
  final int workoutDays;
  final double weight;
  final double height;
  final double targetWeight;

  /// Weight captured when the current goal/target was set, used as the baseline
  /// for goal-progress indicators. 0 when never set.
  final double startWeight;
  final String injuryNotes;

  /// Adaptive difficulty bias from post-workout feedback, clamped to [-2, 2].
  /// Negative => ease off volume, positive => add volume.
  final int intensityAdjustment;
  final String avatarKey;
  final String preferredUnits;
  final String dietaryPreference;
  final String trainingLevel;
  final String workoutLocation;
  final String availableEquipment;
  final int sessionDurationMinutes;
  final String targetMuscleFocus;
  final String jointSensitivity;
  final int streak;
  final List<String> completedWorkoutDates;
  final bool onboardingComplete;

  List<String> get targetMuscleFocuses => _readPreferenceList(
    targetMuscleFocus,
    allowedValues: targetMuscleFocusOptions,
    defaultValue: defaultTargetMuscleFocus,
    resetValue: defaultTargetMuscleFocus,
  );

  List<String> get jointSensitivities => _readPreferenceList(
    jointSensitivity,
    allowedValues: jointSensitivityOptions,
    defaultValue: defaultJointSensitivity,
    resetValue: defaultJointSensitivity,
  );

  List<String> get selectedFocusAreas {
    final selected = targetMuscleFocuses.toSet();
    return targetMuscleFocusOptions
        .where(
          (option) =>
              option != defaultTargetMuscleFocus && selected.contains(option),
        )
        .toList(growable: false);
  }

  List<String> get selectedJointCareAreas {
    final selected = jointSensitivities.toSet();
    return jointSensitivityOptions
        .where(
          (option) =>
              option != defaultJointSensitivity && selected.contains(option),
        )
        .toList(growable: false);
  }

  List<String> get visibleFocusAreas => selectedFocusAreas.isEmpty
      ? <String>[defaultTargetMuscleFocus]
      : selectedFocusAreas;

  bool hasTargetMuscleFocus(String value) =>
      targetMuscleFocuses.contains(value);

  bool hasJointSensitivity(String value) => jointSensitivities.contains(value);

  String get primaryTargetMuscleFocus => targetMuscleFocuses.first;
  String get primaryJointSensitivity => jointSensitivities.first;
  List<String> get workoutCompletionDates =>
      _readDateValues(completedWorkoutDates);
  int get completedWorkoutCount => workoutCompletionDates.length;

  bool hasCompletedWorkoutOn(DateTime date) =>
      workoutCompletionDates.contains(workoutDateKey(date));

  /// Body Mass Index, or 0 when height/weight are not set yet.
  double get bmi {
    if (weight <= 0 || height <= 0) return 0;
    final heightM = height / 100.0;
    return weight / (heightM * heightM);
  }

  bool get hasTargetWeight => targetWeight > 0;

  /// Signed kilograms still to go to reach the target (positive => need to lose).
  double get weightRemainingToTarget =>
      targetWeight > 0 && weight > 0 ? weight - targetWeight : 0.0;

  /// 0..1 progress from [startWeight] toward [targetWeight]. Null when it cannot
  /// be computed (no target/weight set).
  double? get goalProgress {
    if (targetWeight <= 0 || weight <= 0) return null;
    final base = startWeight > 0 ? startWeight : weight;
    if ((base - targetWeight).abs() < 0.1) {
      return (weight - targetWeight).abs() < 0.5 ? 1.0 : 0.0;
    }
    return ((base - weight) / (base - targetWeight)).clamp(0.0, 1.0);
  }

  bool get hasReachedWeightGoal =>
      targetWeight > 0 && weight > 0 && (weight - targetWeight).abs() < 0.5;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.gender = '',
    this.age = 25,
    this.occupation = '',
    this.sittingHours = '',
    this.fitnessGoal = '',
    this.workoutDays = 3,
    this.weight = 0.0,
    this.height = 170.0,
    this.targetWeight = 0.0,
    this.startWeight = 0.0,
    this.injuryNotes = '',
    this.intensityAdjustment = 0,
    this.avatarKey = 'person',
    this.preferredUnits = 'metric',
    this.dietaryPreference = DietaryPreferenceCodes.mixed,
    this.trainingLevel = 'Beginner',
    this.workoutLocation = 'Home',
    this.availableEquipment = 'Bodyweight',
    this.sessionDurationMinutes = 30,
    this.targetMuscleFocus = defaultTargetMuscleFocus,
    this.jointSensitivity = defaultJointSensitivity,
    this.streak = 0,
    this.completedWorkoutDates = const <String>[],
    this.onboardingComplete = false,
  });

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? gender,
    int? age,
    String? occupation,
    String? sittingHours,
    String? fitnessGoal,
    int? workoutDays,
    double? weight,
    double? height,
    double? targetWeight,
    double? startWeight,
    String? injuryNotes,
    int? intensityAdjustment,
    String? avatarKey,
    String? preferredUnits,
    String? dietaryPreference,
    String? trainingLevel,
    String? workoutLocation,
    String? availableEquipment,
    int? sessionDurationMinutes,
    String? targetMuscleFocus,
    String? jointSensitivity,
    List<String>? targetMuscleFocuses,
    List<String>? jointSensitivities,
    int? streak,
    List<String>? completedWorkoutDates,
    bool? onboardingComplete,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      occupation: occupation ?? this.occupation,
      sittingHours: sittingHours ?? this.sittingHours,
      fitnessGoal: fitnessGoal ?? this.fitnessGoal,
      workoutDays: workoutDays ?? this.workoutDays,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      targetWeight: targetWeight ?? this.targetWeight,
      startWeight: startWeight ?? this.startWeight,
      injuryNotes: injuryNotes ?? this.injuryNotes,
      intensityAdjustment: intensityAdjustment ?? this.intensityAdjustment,
      avatarKey: avatarKey ?? this.avatarKey,
      preferredUnits: preferredUnits ?? this.preferredUnits,
      dietaryPreference: normalizeDietaryPreference(
        dietaryPreference ?? this.dietaryPreference,
      ),
      trainingLevel: trainingLevel ?? this.trainingLevel,
      workoutLocation: workoutLocation ?? this.workoutLocation,
      availableEquipment: availableEquipment ?? this.availableEquipment,
      sessionDurationMinutes:
          sessionDurationMinutes ?? this.sessionDurationMinutes,
      targetMuscleFocus: targetMuscleFocuses != null
          ? _writePreferenceList(
              targetMuscleFocuses,
              defaultValue: defaultTargetMuscleFocus,
              resetValue: defaultTargetMuscleFocus,
            )
          : (targetMuscleFocus ?? this.targetMuscleFocus),
      jointSensitivity: jointSensitivities != null
          ? _writePreferenceList(
              jointSensitivities,
              defaultValue: defaultJointSensitivity,
              resetValue: defaultJointSensitivity,
            )
          : (jointSensitivity ?? this.jointSensitivity),
      streak: streak ?? this.streak,
      completedWorkoutDates:
          completedWorkoutDates ?? this.completedWorkoutDates,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      gender: json['gender'] ?? '',
      age: json['age'] ?? 25,
      occupation: json['occupation'] ?? '',
      sittingHours: json['sittingHours'] ?? '',
      fitnessGoal: json['fitnessGoal'] ?? '',
      workoutDays: json['workoutDays'] ?? 3,
      weight: (json['weight'] ?? 0.0).toDouble(),
      height: (json['height'] ?? 170.0).toDouble(),
      targetWeight: (json['targetWeight'] ?? 0.0).toDouble(),
      startWeight: (json['startWeight'] ?? 0.0).toDouble(),
      injuryNotes: json['injuryNotes'] ?? '',
      intensityAdjustment: (json['intensityAdjustment'] ?? 0) as int,
      avatarKey: json['avatarKey'] ?? 'person',
      preferredUnits: json['preferredUnits'] ?? 'metric',
      dietaryPreference: normalizeDietaryPreference(
        json['dietaryPreference'] ?? DietaryPreferenceCodes.mixed,
      ),
      trainingLevel: json['trainingLevel'] ?? 'Beginner',
      workoutLocation: json['workoutLocation'] ?? 'Home',
      availableEquipment: json['availableEquipment'] ?? 'Bodyweight',
      sessionDurationMinutes: json['sessionDurationMinutes'] ?? 30,
      targetMuscleFocus: _writePreferenceList(
        _readPreferenceValues(
          json['targetMuscleFocuses'] ?? json['targetMuscleFocus'],
          allowedValues: targetMuscleFocusOptions,
          defaultValue: defaultTargetMuscleFocus,
          resetValue: defaultTargetMuscleFocus,
        ),
        defaultValue: defaultTargetMuscleFocus,
        resetValue: defaultTargetMuscleFocus,
      ),
      jointSensitivity: _writePreferenceList(
        _readPreferenceValues(
          json['jointSensitivities'] ?? json['jointSensitivity'],
          allowedValues: jointSensitivityOptions,
          defaultValue: defaultJointSensitivity,
          resetValue: defaultJointSensitivity,
        ),
        defaultValue: defaultJointSensitivity,
        resetValue: defaultJointSensitivity,
      ),
      streak:
          json['streak'] ??
          calculateWorkoutStreak(
            _readDateValues(json['completedWorkoutDates']),
          ),
      completedWorkoutDates: _readDateValues(json['completedWorkoutDates']),
      onboardingComplete: json['onboardingComplete'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'gender': gender,
      'age': age,
      'occupation': occupation,
      'sittingHours': sittingHours,
      'fitnessGoal': fitnessGoal,
      'workoutDays': workoutDays,
      'weight': weight,
      'height': height,
      'targetWeight': targetWeight,
      'startWeight': startWeight,
      'injuryNotes': injuryNotes,
      'intensityAdjustment': intensityAdjustment,
      'avatarKey': avatarKey,
      'preferredUnits': preferredUnits,
      'dietaryPreference': dietaryPreference,
      'trainingLevel': trainingLevel,
      'workoutLocation': workoutLocation,
      'availableEquipment': availableEquipment,
      'sessionDurationMinutes': sessionDurationMinutes,
      'targetMuscleFocus': targetMuscleFocus,
      'targetMuscleFocuses': targetMuscleFocuses,
      'jointSensitivity': jointSensitivity,
      'jointSensitivities': jointSensitivities,
      'streak': streak,
      'completedWorkoutDates': workoutCompletionDates,
      'onboardingComplete': onboardingComplete,
    };
  }
}

String workoutDateKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

int calculateWorkoutStreak(List<String> completedWorkoutDates) {
  final normalizedDates = _readDateValues(completedWorkoutDates);
  if (normalizedDates.isEmpty) {
    return 0;
  }

  var streak = 1;
  final lastDate = DateTime.tryParse(normalizedDates.last);
  if (lastDate == null) {
    return 0;
  }
  var previousDate = lastDate;

  for (var index = normalizedDates.length - 2; index >= 0; index--) {
    final currentDate = DateTime.tryParse(normalizedDates[index]);
    if (currentDate == null) {
      continue;
    }

    final difference = previousDate.difference(currentDate).inDays;
    if (difference == 1) {
      streak++;
      previousDate = currentDate;
      continue;
    }
    if (difference > 1) {
      break;
    }
  }

  return streak;
}

List<String> _readPreferenceList(
  String rawValue, {
  required List<String> allowedValues,
  required String defaultValue,
  required String resetValue,
}) {
  return _readPreferenceValues(
    rawValue,
    allowedValues: allowedValues,
    defaultValue: defaultValue,
    resetValue: resetValue,
  );
}

List<String> _readPreferenceValues(
  Object? rawValue, {
  required List<String> allowedValues,
  required String defaultValue,
  required String resetValue,
}) {
  final normalizedOptions = <String, String>{
    for (final option in allowedValues) _normalizePreference(option): option,
  };

  final rawEntries = switch (rawValue) {
    List() => rawValue.map((entry) => '$entry'),
    String() => rawValue.split(RegExp(r'\s*[,|]\s*')),
    _ => const <String>[],
  };

  final selections = <String>[];
  for (final rawEntry in rawEntries) {
    final normalizedEntry = _normalizePreference(rawEntry);
    if (normalizedEntry.isEmpty) {
      continue;
    }
    final option = normalizedOptions[normalizedEntry];
    if (option != null && !selections.contains(option)) {
      selections.add(option);
    }
  }

  if (selections.length > 1) {
    selections.remove(resetValue);
  }

  if (selections.isEmpty) {
    return <String>[defaultValue];
  }

  return selections;
}

String _writePreferenceList(
  List<String> values, {
  required String defaultValue,
  required String resetValue,
}) {
  final filtered = values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
  final normalized = filtered.isEmpty ? <String>[defaultValue] : filtered;
  final selections = normalized.length > 1
      ? normalized.where((value) => value != resetValue).toList(growable: false)
      : normalized;
  return (selections.isEmpty ? <String>[defaultValue] : selections).join(', ');
}

String _normalizePreference(String value) => value.toLowerCase().trim();

List<String> _readDateValues(Object? rawValue) {
  final rawEntries = switch (rawValue) {
    List() => rawValue.map((entry) => '$entry'),
    String() => rawValue.split(RegExp(r'\s*[,|]\s*')),
    _ => const <String>[],
  };

  final normalized = <String>{};
  for (final rawEntry in rawEntries) {
    final entry = rawEntry.trim();
    if (entry.isEmpty) {
      continue;
    }

    final parsed = DateTime.tryParse(entry);
    if (parsed == null) {
      continue;
    }
    normalized.add(workoutDateKey(parsed));
  }

  final sorted = normalized.toList()..sort();
  return sorted;
}
