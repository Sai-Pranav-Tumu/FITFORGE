import '../models/user_model.dart';
import '../models/workout_plan.dart';

class WorkoutRecommendationService {
  static WorkoutRecommendation buildPlan(UserModel profile) {
    final weeklyPlan = _buildWeeklyPlan(profile);
    final todayIndex = DateTime.now().weekday - 1;
    final todaysPlan = weeklyPlan[todayIndex];
    final firstName = profile.name.trim().split(' ').first;

    return WorkoutRecommendation(
      greeting: '${_greetingForHour(DateTime.now().hour)}, $firstName',
      weeklyFocus: _weeklyFocus(profile),
      insight: _insight(profile),
      weeklyPlan: weeklyPlan,
      todaysPlan: todaysPlan,
    );
  }

  static String _greetingForHour(int hour) {
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Night';
  }

  static String _weeklyFocus(UserModel profile) {
    final goalLine = switch (profile.fitnessGoal) {
      'Gain Muscle' => 'muscle-building volume',
      'Lose Weight' => 'fat-loss friendly strength and conditioning',
      'Improve Stamina' => 'endurance-focused conditioning',
      _ => 'consistent full-body training',
    };

    final focusLine = switch (profile.targetMuscleFocus) {
      'Upper Body' => 'with extra upper-body emphasis',
      'Lower Body' => 'with extra lower-body emphasis',
      'Core' => 'with extra trunk and posture work',
      'Back & Posture' => 'with posture-supportive pulling and mobility work',
      _ => 'with balanced weekly recovery',
    };

    return '${_capitalize(goalLine)} $focusLine';
  }

  static String _insight(UserModel profile) {
    final mobilityNote =
        profile.sittingHours == '6-8 Hours' ||
            profile.sittingHours == '8+ Hours'
        ? 'Extra mobility is included because you spend long hours sitting.'
        : 'Warm-ups stay efficient so you can get into the session quickly.';

    final equipmentNote = switch (profile.availableEquipment) {
      'Bodyweight' => 'Movements stay simple and home-friendly.',
      'Bands & Dumbbells' =>
        'Band and dumbbell options are mixed in for progression.',
      _ => 'Gym equipment opens up more loading options and variety.',
    };

    final jointNote = switch (profile.jointSensitivity) {
      'Knees' =>
        'Knee-sensitive choices reduce high-impact and deep flexion stress.',
      'Lower Back' =>
        'Lower-back friendly cues and core stability are prioritized.',
      'Shoulders' =>
        'Shoulder-sensitive variations avoid aggressive overhead volume.',
      _ => 'You have no reported joint limitations, so variety stays higher.',
    };

    return '$mobilityNote $equipmentNote $jointNote';
  }

  static List<WorkoutDayPlan> _buildWeeklyPlan(UserModel profile) {
    if (profile.workoutDays <= 2) return _twoDayPlan(profile);
    if (profile.workoutDays == 3) return _threeDayPlan(profile);
    if (profile.workoutDays == 4) return _fourDayPlan(profile);
    return _fivePlusDayPlan(profile);
  }

  static List<WorkoutDayPlan> _twoDayPlan(UserModel profile) {
    return [
      _trainingDay(
        profile: profile,
        title: _titleWithFocus(profile, 'Full Body Strength'),
        description:
            'One efficient session for strength, posture, and core control.',
        calories: 280,
        exercises: [
          _lowerPrimary(profile),
          _pushPrimary(profile),
          _pullPrimary(profile),
          _corePrimary(profile),
        ],
      ),
      _restDay(profile, 'Recovery Walk + Mobility'),
      _trainingDay(
        profile: profile,
        title: _titleWithFocus(profile, 'Conditioning Reset'),
        description:
            'A shorter home-friendly circuit to build weekly momentum.',
        calories: 255,
        exercises: [
          _unilateralLower(profile),
          _pushSecondary(profile),
          _glutePrimary(profile),
          _conditioningPrimary(profile),
        ],
      ),
      _restDay(profile, 'Mobility Reset'),
      _restDay(profile, 'Walking + Stretching'),
      _restDay(profile, 'Optional Core Flow'),
      _restDay(profile, 'Full Recovery'),
    ];
  }

  static List<WorkoutDayPlan> _threeDayPlan(UserModel profile) {
    return [
      _trainingDay(
        profile: profile,
        title: _goalBasedTitle(
          profile,
          'Full Body Strength',
          'Strength Base Day',
        ),
        description:
            'A strong foundation day with simple, high-value movements.',
        calories: 300,
        exercises: [
          _focusLead(profile),
          _pushPrimary(profile),
          _pullPrimary(profile),
          _corePrimary(profile),
        ],
      ),
      _restDay(profile, 'Recovery Walk'),
      _trainingDay(
        profile: profile,
        title: _focusSessionTitle(profile),
        description:
            'This session leans into your selected focus area without losing balance.',
        calories: 310,
        exercises: [
          _secondaryFocus(profile),
          _lowerPrimary(profile),
          _pullSecondary(profile),
          _coreSecondary(profile),
        ],
      ),
      _restDay(profile, 'Stretch + Mobility'),
      _trainingDay(
        profile: profile,
        title: _goalBasedTitle(
          profile,
          'Conditioning Finish',
          'Athletic Capacity Day',
        ),
        description:
            'A tighter, higher-tempo day that matches your goal and available time.',
        calories: 320,
        exercises: [
          _conditioningPrimary(profile),
          _pushSecondary(profile),
          _unilateralLower(profile),
          _carryOrCore(profile),
        ],
      ),
      _restDay(profile, 'Optional Walk'),
      _restDay(profile, 'Full Recovery'),
    ];
  }

  static List<WorkoutDayPlan> _fourDayPlan(UserModel profile) {
    return [
      _trainingDay(
        profile: profile,
        title: 'Upper Body Push',
        description:
            'Pressing work tuned to your equipment and shoulder comfort.',
        calories: 320,
        exercises: [
          _pushPrimary(profile),
          _pushSecondary(profile),
          _upperAccessory(profile),
          _corePrimary(profile),
        ],
      ),
      _trainingDay(
        profile: profile,
        title: 'Lower Body Strength',
        description:
            'Leg work adjusted for your level, location, and joint needs.',
        calories: 350,
        exercises: [
          _lowerPrimary(profile),
          _unilateralLower(profile),
          _glutePrimary(profile),
          _coreSecondary(profile),
        ],
      ),
      _restDay(profile, 'Mobility + Walking'),
      _trainingDay(
        profile: profile,
        title: 'Upper Body Pull',
        description:
            'Back, arm, and posture work to support performance and shape.',
        calories: 300,
        exercises: [
          _pullPrimary(profile),
          _pullSecondary(profile),
          _postureAccessory(profile),
          _carryOrCore(profile),
        ],
      ),
      _trainingDay(
        profile: profile,
        title: _goalBasedTitle(profile, 'Conditioning + Core', 'Power Finish'),
        description:
            'A final punchy day to round out the week without dragging recovery down.',
        calories: 330,
        exercises: [
          _conditioningPrimary(profile),
          _focusLead(profile),
          _secondaryFocus(profile),
          _corePrimary(profile),
        ],
      ),
      _restDay(profile, 'Easy Cardio'),
      _restDay(profile, 'Full Recovery'),
    ];
  }

  static List<WorkoutDayPlan> _fivePlusDayPlan(UserModel profile) {
    return [
      _trainingDay(
        profile: profile,
        title: 'Push Day',
        description:
            'Chest, shoulders, and triceps with level-appropriate loading.',
        calories: 330,
        exercises: [
          _pushPrimary(profile),
          _pushSecondary(profile),
          _upperAccessory(profile),
          _corePrimary(profile),
        ],
      ),
      _trainingDay(
        profile: profile,
        title: 'Pull Day',
        description: 'Back, rear delts, and biceps with posture support.',
        calories: 305,
        exercises: [
          _pullPrimary(profile),
          _pullSecondary(profile),
          _postureAccessory(profile),
          _carryOrCore(profile),
        ],
      ),
      _trainingDay(
        profile: profile,
        title: 'Leg Day',
        description:
            'Lower-body work scaled around your joint tolerance and equipment.',
        calories: 370,
        exercises: [
          _lowerPrimary(profile),
          _unilateralLower(profile),
          _glutePrimary(profile),
          _coreSecondary(profile),
        ],
      ),
      _restDay(profile, 'Mobility + Steps'),
      _trainingDay(
        profile: profile,
        title: _focusSessionTitle(profile),
        description: 'An emphasis day built around your chosen muscle focus.',
        calories: 300,
        exercises: [
          _focusLead(profile),
          _secondaryFocus(profile),
          _conditioningPrimary(profile),
          _corePrimary(profile),
        ],
      ),
      _trainingDay(
        profile: profile,
        title: 'Recovery Strength',
        description:
            'A lighter full-body session so you keep momentum without accumulating fatigue.',
        calories: 240,
        exercises: [
          _glutePrimary(profile),
          _pushSecondary(profile),
          _postureAccessory(profile),
          _coreSecondary(profile),
        ],
      ),
      _restDay(profile, 'Full Recovery'),
    ];
  }

  static WorkoutDayPlan _trainingDay({
    required UserModel profile,
    required String title,
    required String description,
    required int calories,
    required List<WorkoutExercise> exercises,
  }) {
    final minutes = _sessionDuration(profile);
    final calorieScale = ((minutes / 30) * calories).round();
    return WorkoutDayPlan(
      title: title,
      description: description,
      durationMinutes: minutes,
      estimatedCalories: calorieScale,
      isRestDay: false,
      exercises: exercises,
    );
  }

  static WorkoutDayPlan _restDay(UserModel profile, String title) {
    return WorkoutDayPlan(
      title: title,
      description:
          'Light movement, stretching, and recovery work matched to your weekly load.',
      durationMinutes: profile.sessionDurationMinutes <= 20 ? 12 : 20,
      estimatedCalories: 90,
      isRestDay: true,
      exercises: [
        _exercise(
          'Mobility Flow',
          '10 minutes',
          'Move gently, breathe deeply, and reset tight areas.',
        ),
      ],
    );
  }

  static int _sessionDuration(UserModel profile) {
    var minutes = profile.sessionDurationMinutes;
    if (profile.trainingLevel == 'Beginner' && minutes > 45) {
      minutes = 45;
    }
    if (profile.workoutDays >= 5 && minutes < 30) {
      minutes = 30;
    }
    return minutes;
  }

  static String _titleWithFocus(UserModel profile, String base) {
    if (profile.targetMuscleFocus == 'Core') return '$base + Core';
    if (profile.targetMuscleFocus == 'Back & Posture') return '$base + Posture';
    return base;
  }

  static String _goalBasedTitle(
    UserModel profile,
    String standard,
    String athletic,
  ) {
    return profile.fitnessGoal == 'Improve Stamina' ? athletic : standard;
  }

  static String _focusSessionTitle(UserModel profile) {
    switch (profile.targetMuscleFocus) {
      case 'Upper Body':
        return 'Upper Body Focus';
      case 'Lower Body':
        return 'Lower Body Focus';
      case 'Core':
        return 'Core Stability Focus';
      case 'Back & Posture':
        return 'Back + Posture Focus';
      default:
        return 'Full Body Focus';
    }
  }

  static WorkoutExercise _focusLead(UserModel profile) {
    switch (profile.targetMuscleFocus) {
      case 'Upper Body':
        return _pushPrimary(profile);
      case 'Lower Body':
        return _lowerPrimary(profile);
      case 'Core':
        return _corePrimary(profile);
      case 'Back & Posture':
        return _pullPrimary(profile);
      default:
        return _conditioningPrimary(profile);
    }
  }

  static WorkoutExercise _secondaryFocus(UserModel profile) {
    switch (profile.targetMuscleFocus) {
      case 'Upper Body':
        return _pullSecondary(profile);
      case 'Lower Body':
        return _unilateralLower(profile);
      case 'Core':
        return _coreSecondary(profile);
      case 'Back & Posture':
        return _postureAccessory(profile);
      default:
        return _glutePrimary(profile);
    }
  }

  static WorkoutExercise _pushPrimary(UserModel profile) {
    if (profile.jointSensitivity == 'Shoulders') {
      return _exercise(
        'Incline Push-Up',
        '3 sets · 10-12 reps',
        'Keep your ribs tucked and move smoothly.',
      );
    }
    if (profile.availableEquipment == 'Full Gym' &&
        profile.trainingLevel != 'Beginner') {
      return _exercise(
        'Bench Press',
        '4 sets · 6-8 reps',
        'Lower with control and press from a stable base.',
      );
    }
    if (profile.availableEquipment == 'Bands & Dumbbells') {
      return _exercise(
        'Dumbbell Floor Press',
        '4 sets · 8-10 reps',
        'Keep wrists stacked and control the lowering.',
      );
    }
    return _exercise(
      'Push-Up',
      '4 sets · 8-12 reps',
      'Keep your body in one long line.',
    );
  }

  static WorkoutExercise _pushSecondary(UserModel profile) {
    if (profile.jointSensitivity == 'Shoulders') {
      return _exercise(
        'Wall Push-Up',
        '3 sets · 12 reps',
        'Stay tall through the chest and move pain-free.',
      );
    }
    if (profile.availableEquipment == 'Full Gym') {
      return _exercise(
        'Shoulder Press',
        '3 sets · 10 reps',
        'Brace before every press.',
      );
    }
    if (profile.availableEquipment == 'Bands & Dumbbells') {
      return _exercise(
        'Dumbbell Shoulder Press',
        '3 sets · 10 reps',
        'Press up without shrugging.',
      );
    }
    return _exercise(
      'Incline Push-Up',
      '3 sets · 12 reps',
      'Stay strong through the core.',
    );
  }

  static WorkoutExercise _pullPrimary(UserModel profile) {
    if (profile.availableEquipment == 'Full Gym') {
      return _exercise(
        'Lat Pulldown',
        '4 sets · 10 reps',
        'Lead with your elbows and keep the chest proud.',
      );
    }
    if (profile.availableEquipment == 'Bands & Dumbbells') {
      return _exercise(
        'Dumbbell Row',
        '4 sets · 10 each side',
        'Pull to the hip and pause at the top.',
      );
    }
    return _exercise(
      'Band Pull-Apart',
      '4 sets · 15 reps',
      'Open through the chest and squeeze the upper back.',
    );
  }

  static WorkoutExercise _pullSecondary(UserModel profile) {
    if (profile.availableEquipment == 'Full Gym') {
      return _exercise(
        'Seated Row',
        '3 sets · 10-12 reps',
        'Pull shoulders down and back.',
      );
    }
    if (profile.availableEquipment == 'Bands & Dumbbells') {
      return _exercise(
        'Hammer Curl',
        '3 sets · 12 reps',
        'Control the lowering and avoid swinging.',
      );
    }
    return _exercise(
      'Prone Back Extension',
      '3 sets · 12 reps',
      'Lift from the upper back, not the neck.',
    );
  }

  static WorkoutExercise _lowerPrimary(UserModel profile) {
    if (profile.jointSensitivity == 'Knees') {
      return _exercise(
        'Glute Bridge',
        '4 sets · 12 reps',
        'Drive through the heels and pause at the top.',
      );
    }
    if (profile.availableEquipment == 'Full Gym' &&
        profile.trainingLevel != 'Beginner') {
      return _exercise(
        'Back Squat',
        '4 sets · 6-8 reps',
        'Brace before every rep and stay stacked.',
      );
    }
    if (profile.availableEquipment == 'Bands & Dumbbells') {
      return _exercise(
        'Goblet Squat',
        '4 sets · 10 reps',
        'Stay upright and balanced through the foot.',
      );
    }
    return _exercise(
      'Bodyweight Squat',
      '4 sets · 12 reps',
      'Sit down between the hips and stand tall.',
    );
  }

  static WorkoutExercise _unilateralLower(UserModel profile) {
    if (profile.jointSensitivity == 'Knees') {
      return _exercise(
        'Step-Up',
        '3 sets · 10 each side',
        'Use a low step and push through the whole foot.',
      );
    }
    if (profile.availableEquipment == 'Full Gym' ||
        profile.availableEquipment == 'Bands & Dumbbells') {
      return _exercise(
        'Reverse Lunge',
        '3 sets · 10 each side',
        'Step back softly and keep the front heel grounded.',
      );
    }
    return _exercise(
      'Split Squat',
      '3 sets · 10 each side',
      'Stay upright and move under control.',
    );
  }

  static WorkoutExercise _glutePrimary(UserModel profile) {
    if (profile.availableEquipment == 'Full Gym' &&
        profile.trainingLevel == 'Advanced') {
      return _exercise(
        'Romanian Deadlift',
        '3 sets · 8 reps',
        'Hinge through the hips and keep the spine long.',
      );
    }
    if (profile.jointSensitivity == 'Lower Back') {
      return _exercise(
        'Glute Bridge',
        '4 sets · 12 reps',
        'Brace lightly and finish with a glute squeeze.',
      );
    }
    return _exercise(
      'Glute Bridge',
      '4 sets · 12 reps',
      'Drive through the heels and squeeze the glutes at the top.',
    );
  }

  static WorkoutExercise _corePrimary(UserModel profile) {
    if (profile.jointSensitivity == 'Lower Back') {
      return _exercise(
        'Dead Bug',
        '3 sets · 12 reps',
        'Keep the lower back gently pressed down.',
      );
    }
    if (profile.trainingLevel == 'Advanced') {
      return _exercise(
        'Plank Shoulder Taps',
        '3 sets · 20 taps',
        'Minimize hip sway on every reach.',
      );
    }
    return _exercise(
      'Forearm Plank',
      '3 sets · 40 sec',
      'Brace the abs and breathe behind the shield.',
    );
  }

  static WorkoutExercise _coreSecondary(UserModel profile) {
    if (profile.jointSensitivity == 'Lower Back') {
      return _exercise(
        'Bird Dog',
        '3 sets · 10 each side',
        'Reach long and keep the torso quiet.',
      );
    }
    return _exercise(
      'Hollow Hold',
      '3 sets · 30 sec',
      'Flatten the lower back before lifting.',
    );
  }

  static WorkoutExercise _conditioningPrimary(UserModel profile) {
    if (profile.jointSensitivity == 'Knees') {
      return _exercise(
        'Fast March',
        '6 rounds · 40 sec',
        'Pump the arms and keep the pace steady.',
      );
    }
    if (profile.availableEquipment == 'Full Gym') {
      return _exercise(
        'Bike Erg',
        '6 rounds · 40 sec',
        'Push hard, then recover fully.',
      );
    }
    return _exercise(
      'Mountain Climber',
      '4 rounds · 30 sec',
      'Move with rhythm and keep the hips low.',
    );
  }

  static WorkoutExercise _carryOrCore(UserModel profile) {
    if (profile.availableEquipment == 'Full Gym' ||
        profile.availableEquipment == 'Bands & Dumbbells') {
      return _exercise(
        'Farmer Carry',
        '4 rounds · 30 sec',
        'Stand tall and let the core do the stabilizing.',
      );
    }
    return _exercise(
      'Dead Bug',
      '3 sets · 12 reps',
      'Move slowly and own the exhale.',
    );
  }

  static WorkoutExercise _upperAccessory(UserModel profile) {
    if (profile.jointSensitivity == 'Shoulders') {
      return _exercise(
        'Band External Rotation',
        '3 sets · 12 reps',
        'Rotate from the shoulder without flaring the ribs.',
      );
    }
    if (profile.availableEquipment == 'Full Gym') {
      return _exercise(
        'Lateral Raise',
        '3 sets · 15 reps',
        'Lift to shoulder height without shrugging.',
      );
    }
    return _exercise(
      'Pike Push-Up',
      '3 sets · 8 reps',
      'Shift weight forward and stay long through the spine.',
    );
  }

  static WorkoutExercise _postureAccessory(UserModel profile) {
    if (profile.availableEquipment == 'Full Gym') {
      return _exercise(
        'Face Pull',
        '3 sets · 15 reps',
        'Finish with elbows high and shoulder blades back.',
      );
    }
    return _exercise(
      'Band Pull-Apart',
      '3 sets · 20 reps',
      'Spread the band and keep the neck relaxed.',
    );
  }

  static WorkoutExercise _exercise(
    String name,
    String prescription,
    String cue,
  ) {
    final metadata =
        _exerciseCatalog[name] ?? _exerciseCatalog['Mobility Flow']!;
    return WorkoutExercise(
      name: name,
      prescription: prescription,
      cue: cue,
      animationAsset: metadata.animationAsset,
      animationType: metadata.animationType,
      animationFrames: metadata.animationFrames,
      primaryMuscles: metadata.primaryMuscles,
      secondaryMuscles: metadata.secondaryMuscles,
      bodyMapZones: metadata.bodyMapZones,
      equipment: metadata.equipment,
      difficulty: metadata.difficulty,
      movementPattern: metadata.movementPattern,
    );
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}

class _ExerciseMetadata {
  final String animationAsset;
  final String animationType;
  final List<String> animationFrames;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final List<String> bodyMapZones;
  final String equipment;
  final String difficulty;
  final String movementPattern;

  const _ExerciseMetadata({
    required this.animationAsset,
    this.animationType = 'lottie',
    this.animationFrames = const [],
    required this.primaryMuscles,
    this.secondaryMuscles = const [],
    this.bodyMapZones = const [],
    required this.equipment,
    required this.difficulty,
    required this.movementPattern,
  });
}

const Map<String, _ExerciseMetadata> _exerciseCatalog = {
  'Push-Up': _ExerciseMetadata(
    animationAsset: 'assets/animations/clap_push_up.gif',
    animationType: 'gif',
    animationFrames: _frames('Push-Up_Wide'),
    primaryMuscles: ['Chest', 'Triceps'],
    secondaryMuscles: ['Front Delts', 'Core'],
    bodyMapZones: ['chest', 'triceps', 'core'],
    equipment: 'Bodyweight',
    difficulty: 'Beginner',
    movementPattern: 'Horizontal Push',
  ),
  'Incline Push-Up': _ExerciseMetadata(
    animationAsset: 'assets/animations/clap_push_up.gif',
    animationType: 'gif',
    animationFrames: _frames('Incline_Push-Up'),
    primaryMuscles: ['Chest', 'Triceps'],
    secondaryMuscles: ['Shoulders', 'Core'],
    bodyMapZones: ['chest', 'triceps', 'frontShoulders'],
    equipment: 'Bodyweight',
    difficulty: 'Beginner',
    movementPattern: 'Horizontal Push',
  ),
  'Wall Push-Up': _ExerciseMetadata(
    animationAsset: 'assets/animations/clap_push_up.gif',
    animationType: 'gif',
    animationFrames: _frames('Incline_Push-Up'),
    primaryMuscles: ['Chest'],
    secondaryMuscles: ['Triceps', 'Front Delts'],
    bodyMapZones: ['chest', 'triceps'],
    equipment: 'Bodyweight',
    difficulty: 'Beginner',
    movementPattern: 'Horizontal Push',
  ),
  'Bench Press': _ExerciseMetadata(
    animationAsset: 'assets/animations/exercise_push.json',
    animationFrames: _frames('Bench_Press_-_Powerlifting'),
    primaryMuscles: ['Chest', 'Triceps'],
    secondaryMuscles: ['Front Delts'],
    bodyMapZones: ['chest', 'triceps', 'frontShoulders'],
    equipment: 'Barbell',
    difficulty: 'Intermediate',
    movementPattern: 'Horizontal Push',
  ),
  'Dumbbell Floor Press': _ExerciseMetadata(
    animationAsset: 'assets/animations/exercise_push.json',
    animationFrames: _frames('Dumbbell_Floor_Press'),
    primaryMuscles: ['Chest', 'Triceps'],
    secondaryMuscles: ['Front Delts'],
    bodyMapZones: ['chest', 'triceps'],
    equipment: 'Dumbbells',
    difficulty: 'Intermediate',
    movementPattern: 'Horizontal Push',
  ),
  'Shoulder Press': _ExerciseMetadata(
    animationAsset: 'assets/animations/exercise_push.json',
    animationFrames: _frames('Barbell_Shoulder_Press'),
    primaryMuscles: ['Shoulders'],
    secondaryMuscles: ['Triceps', 'Upper Chest'],
    bodyMapZones: ['frontShoulders', 'triceps'],
    equipment: 'Machine/Barbell',
    difficulty: 'Intermediate',
    movementPattern: 'Vertical Push',
  ),
  'Dumbbell Shoulder Press': _ExerciseMetadata(
    animationAsset: 'assets/animations/exercise_push.json',
    animationFrames: _frames('Dumbbell_Shoulder_Press'),
    primaryMuscles: ['Shoulders'],
    secondaryMuscles: ['Triceps'],
    bodyMapZones: ['frontShoulders', 'triceps'],
    equipment: 'Dumbbells',
    difficulty: 'Intermediate',
    movementPattern: 'Vertical Push',
  ),
  'Lateral Raise': _ExerciseMetadata(
    animationAsset: 'assets/animations/exercise_push.json',
    primaryMuscles: ['Lateral Delts'],
    secondaryMuscles: ['Upper Traps'],
    bodyMapZones: ['sideShoulders'],
    equipment: 'Dumbbells',
    difficulty: 'Intermediate',
    movementPattern: 'Shoulder Isolation',
  ),
  'Pike Push-Up': _ExerciseMetadata(
    animationAsset: 'assets/animations/exercise_push.json',
    primaryMuscles: ['Shoulders', 'Triceps'],
    secondaryMuscles: ['Upper Chest', 'Core'],
    bodyMapZones: ['frontShoulders', 'triceps', 'core'],
    equipment: 'Bodyweight',
    difficulty: 'Intermediate',
    movementPattern: 'Vertical Push',
  ),
  'Lat Pulldown': _ExerciseMetadata(
    animationAsset: 'assets/animations/exercise_pull.json',
    animationFrames: _frames('Wide-Grip_Lat_Pulldown'),
    primaryMuscles: ['Lats'],
    secondaryMuscles: ['Biceps', 'Mid Back'],
    bodyMapZones: ['lats', 'midBack', 'biceps'],
    equipment: 'Cable Machine',
    difficulty: 'Intermediate',
    movementPattern: 'Vertical Pull',
  ),
  'Dumbbell Row': _ExerciseMetadata(
    animationAsset: 'assets/animations/exercise_pull.json',
    animationFrames: _frames('One-Arm_Dumbbell_Row'),
    primaryMuscles: ['Lats', 'Mid Back'],
    secondaryMuscles: ['Biceps'],
    bodyMapZones: ['lats', 'midBack', 'biceps'],
    equipment: 'Dumbbells',
    difficulty: 'Beginner',
    movementPattern: 'Horizontal Pull',
  ),
  'Band Pull-Apart': _ExerciseMetadata(
    animationAsset: 'assets/animations/exercise_pull.json',
    animationFrames: _frames('Band_Pull_Apart'),
    primaryMuscles: ['Rear Delts', 'Upper Back'],
    secondaryMuscles: ['Mid Back'],
    bodyMapZones: ['rearShoulders', 'upperBack'],
    equipment: 'Band',
    difficulty: 'Beginner',
    movementPattern: 'Posture Pull',
  ),
  'Seated Row': _ExerciseMetadata(
    animationAsset: 'assets/animations/exercise_pull.json',
    animationFrames: _frames('Seated_Cable_Rows'),
    primaryMuscles: ['Mid Back', 'Lats'],
    secondaryMuscles: ['Biceps'],
    bodyMapZones: ['midBack', 'lats', 'biceps'],
    equipment: 'Cable Machine',
    difficulty: 'Intermediate',
    movementPattern: 'Horizontal Pull',
  ),
  'Hammer Curl': _ExerciseMetadata(
    animationAsset: 'assets/animations/exercise_pull.json',
    animationFrames: _frames('Hammer_Curls'),
    primaryMuscles: ['Biceps', 'Forearms'],
    secondaryMuscles: ['Brachialis'],
    bodyMapZones: ['biceps', 'forearms'],
    equipment: 'Dumbbells',
    difficulty: 'Beginner',
    movementPattern: 'Arm Isolation',
  ),
  'Prone Back Extension': _ExerciseMetadata(
    animationAsset: 'assets/animations/exercise_pull.json',
    primaryMuscles: ['Spinal Erectors'],
    secondaryMuscles: ['Glutes', 'Upper Back'],
    bodyMapZones: ['lowerBack', 'glutes'],
    equipment: 'Bodyweight',
    difficulty: 'Beginner',
    movementPattern: 'Posterior Chain',
  ),
  'Face Pull': _ExerciseMetadata(
    animationAsset: 'assets/animations/exercise_pull.json',
    animationFrames: _frames('Face_Pull'),
    primaryMuscles: ['Rear Delts', 'Upper Back'],
    secondaryMuscles: ['Rotator Cuff'],
    bodyMapZones: ['rearShoulders', 'upperBack'],
    equipment: 'Cable/Band',
    difficulty: 'Intermediate',
    movementPattern: 'Posture Pull',
  ),
  'Bodyweight Squat': _ExerciseMetadata(
    animationAsset: 'assets/animations/exercise_squat.json',
    animationFrames: _frames('Bodyweight_Squat'),
    primaryMuscles: ['Quads', 'Glutes'],
    secondaryMuscles: ['Core'],
    bodyMapZones: ['quads', 'glutes', 'core'],
    equipment: 'Bodyweight',
    difficulty: 'Beginner',
    movementPattern: 'Squat',
  ),
  'Goblet Squat': _ExerciseMetadata(
    animationAsset: 'assets/animations/exercise_squat.json',
    animationFrames: _frames('Goblet_Squat'),
    primaryMuscles: ['Quads', 'Glutes'],
    secondaryMuscles: ['Core', 'Adductors'],
    bodyMapZones: ['quads', 'glutes', 'core'],
    equipment: 'Dumbbell/Kettlebell',
    difficulty: 'Beginner',
    movementPattern: 'Squat',
  ),
  'Back Squat': _ExerciseMetadata(
    animationAsset: 'assets/animations/exercise_squat.json',
    primaryMuscles: ['Quads', 'Glutes'],
    secondaryMuscles: ['Hamstrings', 'Core'],
    bodyMapZones: ['quads', 'glutes', 'hamstrings', 'core'],
    equipment: 'Barbell',
    difficulty: 'Advanced',
    movementPattern: 'Squat',
  ),
  'Split Squat': _ExerciseMetadata(
    animationAsset: 'assets/animations/exercise_squat.json',
    animationFrames: _frames('Split_Squats'),
    primaryMuscles: ['Quads', 'Glutes'],
    secondaryMuscles: ['Core'],
    bodyMapZones: ['quads', 'glutes'],
    equipment: 'Bodyweight',
    difficulty: 'Beginner',
    movementPattern: 'Lunge',
  ),
  'Reverse Lunge': _ExerciseMetadata(
    animationAsset: 'assets/animations/exercise_squat.json',
    animationFrames: _frames('Crossover_Reverse_Lunge'),
    primaryMuscles: ['Glutes', 'Quads'],
    secondaryMuscles: ['Hamstrings'],
    bodyMapZones: ['glutes', 'quads', 'hamstrings'],
    equipment: 'Bodyweight/Dumbbells',
    difficulty: 'Intermediate',
    movementPattern: 'Lunge',
  ),
  'Step-Up': _ExerciseMetadata(
    animationAsset: 'assets/animations/exercise_squat.json',
    animationFrames: _frames('Dumbbell_Step_Ups'),
    primaryMuscles: ['Quads', 'Glutes'],
    secondaryMuscles: ['Calves'],
    bodyMapZones: ['quads', 'glutes', 'calves'],
    equipment: 'Bench/Step',
    difficulty: 'Beginner',
    movementPattern: 'Single-Leg',
  ),
  'Glute Bridge': _ExerciseMetadata(
    animationAsset: 'assets/animations/exercise_squat.json',
    primaryMuscles: ['Glutes'],
    secondaryMuscles: ['Hamstrings', 'Core'],
    bodyMapZones: ['glutes', 'hamstrings', 'core'],
    equipment: 'Bodyweight',
    difficulty: 'Beginner',
    movementPattern: 'Hip Extension',
  ),
  'Romanian Deadlift': _ExerciseMetadata(
    animationAsset: 'assets/animations/exercise_squat.json',
    animationFrames: _frames('Romanian_Deadlift'),
    primaryMuscles: ['Hamstrings', 'Glutes'],
    secondaryMuscles: ['Lower Back'],
    bodyMapZones: ['hamstrings', 'glutes', 'lowerBack'],
    equipment: 'Barbell/Dumbbells',
    difficulty: 'Intermediate',
    movementPattern: 'Hip Hinge',
  ),
  'Hip Hinge Reach': _ExerciseMetadata(
    animationAsset: 'assets/animations/exercise_squat.json',
    primaryMuscles: ['Hamstrings', 'Glutes'],
    secondaryMuscles: ['Core'],
    bodyMapZones: ['hamstrings', 'glutes', 'core'],
    equipment: 'Bodyweight',
    difficulty: 'Beginner',
    movementPattern: 'Hip Hinge',
  ),
  'Forearm Plank': _ExerciseMetadata(
    animationAsset: 'assets/animations/exercise_core.json',
    animationFrames: _frames('Plank'),
    primaryMuscles: ['Core'],
    secondaryMuscles: ['Shoulders', 'Glutes'],
    bodyMapZones: ['core', 'frontShoulders'],
    equipment: 'Bodyweight',
    difficulty: 'Beginner',
    movementPattern: 'Anti-Extension',
  ),
  'Plank Shoulder Taps': _ExerciseMetadata(
    animationAsset: 'assets/animations/exercise_core.json',
    primaryMuscles: ['Core'],
    secondaryMuscles: ['Shoulders', 'Chest'],
    bodyMapZones: ['core', 'frontShoulders', 'chest'],
    equipment: 'Bodyweight',
    difficulty: 'Intermediate',
    movementPattern: 'Anti-Rotation',
  ),
  'Dead Bug': _ExerciseMetadata(
    animationAsset: 'assets/animations/exercise_core.json',
    animationFrames: _frames('Dead_Bug'),
    primaryMuscles: ['Core'],
    secondaryMuscles: ['Hip Flexors'],
    bodyMapZones: ['core'],
    equipment: 'Bodyweight',
    difficulty: 'Beginner',
    movementPattern: 'Core Control',
  ),
  'Hollow Hold': _ExerciseMetadata(
    animationAsset: 'assets/animations/exercise_core.json',
    primaryMuscles: ['Core'],
    secondaryMuscles: ['Hip Flexors'],
    bodyMapZones: ['core'],
    equipment: 'Bodyweight',
    difficulty: 'Intermediate',
    movementPattern: 'Core Control',
  ),
  'Bird Dog': _ExerciseMetadata(
    animationAsset: 'assets/animations/exercise_core.json',
    primaryMuscles: ['Core'],
    secondaryMuscles: ['Glutes', 'Upper Back'],
    bodyMapZones: ['core', 'glutes'],
    equipment: 'Bodyweight',
    difficulty: 'Beginner',
    movementPattern: 'Core Stability',
  ),
  'Mountain Climber': _ExerciseMetadata(
    animationAsset: 'assets/animations/exercise_cardio.json',
    animationFrames: _frames('Mountain_Climbers'),
    primaryMuscles: ['Core', 'Shoulders'],
    secondaryMuscles: ['Hip Flexors'],
    bodyMapZones: ['core', 'frontShoulders'],
    equipment: 'Bodyweight',
    difficulty: 'Intermediate',
    movementPattern: 'Conditioning',
  ),
  'Fast March': _ExerciseMetadata(
    animationAsset: 'assets/animations/exercise_cardio.json',
    primaryMuscles: ['Hip Flexors', 'Calves'],
    secondaryMuscles: ['Core'],
    bodyMapZones: ['calves', 'core'],
    equipment: 'Bodyweight',
    difficulty: 'Beginner',
    movementPattern: 'Conditioning',
  ),
  'Bike Erg': _ExerciseMetadata(
    animationAsset: 'assets/animations/exercise_cardio.json',
    primaryMuscles: ['Quads', 'Calves'],
    secondaryMuscles: ['Glutes'],
    bodyMapZones: ['quads', 'calves'],
    equipment: 'Bike Erg',
    difficulty: 'Intermediate',
    movementPattern: 'Conditioning',
  ),
  'Farmer Carry': _ExerciseMetadata(
    animationAsset: 'assets/animations/exercise_core.json',
    animationFrames: _frames('Farmers_Walk'),
    primaryMuscles: ['Core', 'Forearms'],
    secondaryMuscles: ['Traps'],
    bodyMapZones: ['core', 'forearms', 'upperBack'],
    equipment: 'Dumbbells/Kettlebells',
    difficulty: 'Intermediate',
    movementPattern: 'Carry',
  ),
  'Band External Rotation': _ExerciseMetadata(
    animationAsset: 'assets/animations/exercise_pull.json',
    primaryMuscles: ['Rotator Cuff'],
    secondaryMuscles: ['Rear Delts'],
    bodyMapZones: ['rearShoulders'],
    equipment: 'Band',
    difficulty: 'Beginner',
    movementPattern: 'Shoulder Health',
  ),
  'Mobility Flow': _ExerciseMetadata(
    animationAsset: 'assets/animations/exercise_core.json',
    primaryMuscles: ['Mobility'],
    secondaryMuscles: ['Core'],
    bodyMapZones: ['core', 'glutes', 'upperBack'],
    equipment: 'Bodyweight',
    difficulty: 'Beginner',
    movementPattern: 'Recovery',
  ),
};

List<String> _frames(String folder) {
  return [
    'assets/database/exercise_frames/$folder/0.jpg',
    'assets/database/exercise_frames/$folder/1.jpg',
  ];
}
