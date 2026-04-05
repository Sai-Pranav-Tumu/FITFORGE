import '../models/exercise_library_models.dart';
import '../models/user_model.dart';
import '../models/workout_plan.dart';

class WorkoutEngineService {
  WorkoutEngineService._();

  static WorkoutRecommendation buildRecommendation({
    required UserModel profile,
    required List<ExerciseDefinition> exercises,
  }) {
    final filtered = _compatibleExercises(profile, exercises);
    final sourcePool = filtered.isNotEmpty ? filtered : exercises;
    final weeklyPlan = _buildWeeklyPlan(profile, sourcePool);
    final todayIndex = DateTime.now().weekday - 1;
    final firstName = profile.name.trim().split(' ').first;

    return WorkoutRecommendation(
      greeting: '${_greetingForHour(DateTime.now().hour)}, $firstName',
      weeklyFocus: _weeklyFocus(profile),
      insight: _insight(profile, sourcePool.length),
      weeklyPlan: weeklyPlan,
      todaysPlan: weeklyPlan[todayIndex],
    );
  }

  static List<ExerciseDefinition> _compatibleExercises(
    UserModel profile,
    List<ExerciseDefinition> exercises,
  ) {
    return exercises
        .where((exercise) {
          if (!_equipmentCompatible(
            profile.availableEquipment,
            exercise.equipment,
          )) {
            return false;
          }
          if (!_levelCompatible(profile.trainingLevel, exercise.level)) {
            return false;
          }
          if (!_jointCompatible(profile.jointSensitivities, exercise)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  static List<WorkoutDayPlan> _buildWeeklyPlan(
    UserModel profile,
    List<ExerciseDefinition> exercises,
  ) {
    if (profile.workoutDays <= 2) {
      return _twoDayPlan(profile, exercises);
    }
    if (profile.workoutDays == 3) {
      return _threeDayPlan(profile, exercises);
    }
    if (profile.workoutDays == 4) {
      return _fourDayPlan(profile, exercises);
    }
    return _fivePlusDayPlan(profile, exercises);
  }

  static List<WorkoutDayPlan> _twoDayPlan(
    UserModel profile,
    List<ExerciseDefinition> exercises,
  ) {
    final used = <String>{};
    return [
      _trainingDay(
        profile: profile,
        title: 'Full Body Strength',
        description:
            'A compact full-body session matched to your setup and goal.',
        calories: 280,
        exercises: _pickSet(
          profile: profile,
          pool: exercises,
          usedIds: used,
          focusMuscles: [
            'pectorals',
            'latissimus dorsi',
            'quadriceps',
            'gluteus maximus',
            'abdominals',
          ],
          count: _exerciseTargetCount(profile),
        ),
      ),
      _restDay(profile, exercises, used, 'Recovery Walk + Mobility'),
      _trainingDay(
        profile: profile,
        title: 'Conditioning Reset',
        description:
            'A shorter mixed session focused on momentum and movement quality.',
        calories: 255,
        exercises: _pickSet(
          profile: profile,
          pool: exercises,
          usedIds: used,
          focusMuscles: [
            'obliques',
            'abdominals',
            'gluteus maximus',
            'quadriceps',
          ],
          forceBias: 'push',
          count: _exerciseTargetCount(profile),
        ),
      ),
      _restDay(profile, exercises, used, 'Mobility Reset'),
      _restDay(profile, exercises, used, 'Walking + Stretching'),
      _restDay(profile, exercises, used, 'Optional Core Flow'),
      _restDay(profile, exercises, used, 'Full Recovery'),
    ];
  }

  static List<WorkoutDayPlan> _threeDayPlan(
    UserModel profile,
    List<ExerciseDefinition> exercises,
  ) {
    final used = <String>{};
    return [
      _trainingDay(
        profile: profile,
        title: _goalBasedTitle(
          profile,
          'Full Body Strength',
          'Strength Base Day',
        ),
        description:
            'A strong foundation day with high-value movements from the full exercise library.',
        calories: 300,
        exercises: _pickSet(
          profile: profile,
          pool: exercises,
          usedIds: used,
          focusMuscles: _focusMusclesForProfile(profile),
          count: _exerciseTargetCount(profile),
        ),
      ),
      _restDay(profile, exercises, used, 'Recovery Walk'),
      _trainingDay(
        profile: profile,
        title: _focusSessionTitle(profile),
        description:
            'This session leans into your selected focus areas without losing overall balance.',
        calories: 310,
        exercises: _pickSet(
          profile: profile,
          pool: exercises,
          usedIds: used,
          focusMuscles: _focusMusclesForProfile(profile, strongFocus: true),
          count: _exerciseTargetCount(profile),
        ),
      ),
      _restDay(profile, exercises, used, 'Stretch + Mobility'),
      _trainingDay(
        profile: profile,
        title: _goalBasedTitle(
          profile,
          'Conditioning Finish',
          'Athletic Capacity Day',
        ),
        description:
            'A punchier finish built around your goal and available time.',
        calories: 320,
        exercises: _pickSet(
          profile: profile,
          pool: exercises,
          usedIds: used,
          focusMuscles: _goalMuscles(profile),
          count: _exerciseTargetCount(profile),
        ),
      ),
      _restDay(profile, exercises, used, 'Optional Walk'),
      _restDay(profile, exercises, used, 'Full Recovery'),
    ];
  }

  static List<WorkoutDayPlan> _fourDayPlan(
    UserModel profile,
    List<ExerciseDefinition> exercises,
  ) {
    final used = <String>{};
    return [
      _trainingDay(
        profile: profile,
        title: 'Upper Body Push',
        description:
            'Pressing work tuned to your equipment and shoulder comfort.',
        calories: 320,
        exercises: _pickSet(
          profile: profile,
          pool: exercises,
          usedIds: used,
          focusMuscles: ['pectorals', 'deltoids', 'triceps'],
          forceBias: 'push',
          count: _exerciseTargetCount(profile),
        ),
      ),
      _trainingDay(
        profile: profile,
        title: 'Lower Body Strength',
        description:
            'Leg work scaled around your level, location, and joint needs.',
        calories: 350,
        exercises: _pickSet(
          profile: profile,
          pool: exercises,
          usedIds: used,
          focusMuscles: [
            'quadriceps',
            'gluteus maximus',
            'hamstrings',
            'abdominals',
          ],
          count: _exerciseTargetCount(profile),
        ),
      ),
      _restDay(profile, exercises, used, 'Mobility + Walking'),
      _trainingDay(
        profile: profile,
        title: 'Upper Body Pull',
        description:
            'Back, arm, and posture work sourced from the full library.',
        calories: 300,
        exercises: _pickSet(
          profile: profile,
          pool: exercises,
          usedIds: used,
          focusMuscles: [
            'latissimus dorsi',
            'trapezius',
            'biceps',
            'rear deltoids',
          ],
          forceBias: 'pull',
          count: _exerciseTargetCount(profile),
        ),
      ),
      _trainingDay(
        profile: profile,
        title: _goalBasedTitle(profile, 'Conditioning + Core', 'Power Finish'),
        description:
            'A final punchy day that keeps training productive without overloading recovery.',
        calories: 330,
        exercises: _pickSet(
          profile: profile,
          pool: exercises,
          usedIds: used,
          focusMuscles: _goalMuscles(profile),
          count: _exerciseTargetCount(profile),
        ),
      ),
      _restDay(profile, exercises, used, 'Easy Cardio'),
      _restDay(profile, exercises, used, 'Full Recovery'),
    ];
  }

  static List<WorkoutDayPlan> _fivePlusDayPlan(
    UserModel profile,
    List<ExerciseDefinition> exercises,
  ) {
    final used = <String>{};
    return [
      _trainingDay(
        profile: profile,
        title: 'Push Day',
        description:
            'Chest, shoulders, and triceps with level-appropriate loading.',
        calories: 330,
        exercises: _pickSet(
          profile: profile,
          pool: exercises,
          usedIds: used,
          focusMuscles: ['pectorals', 'deltoids', 'triceps'],
          forceBias: 'push',
          count: _exerciseTargetCount(profile),
        ),
      ),
      _trainingDay(
        profile: profile,
        title: 'Pull Day',
        description: 'Back, rear delts, and biceps with posture support.',
        calories: 305,
        exercises: _pickSet(
          profile: profile,
          pool: exercises,
          usedIds: used,
          focusMuscles: ['latissimus dorsi', 'trapezius', 'biceps'],
          forceBias: 'pull',
          count: _exerciseTargetCount(profile),
        ),
      ),
      _trainingDay(
        profile: profile,
        title: 'Leg Day',
        description:
            'Lower-body work scaled around your joint tolerance and equipment.',
        calories: 370,
        exercises: _pickSet(
          profile: profile,
          pool: exercises,
          usedIds: used,
          focusMuscles: [
            'quadriceps',
            'gluteus maximus',
            'hamstrings',
            'calves',
          ],
          count: _exerciseTargetCount(profile),
        ),
      ),
      _restDay(profile, exercises, used, 'Mobility + Steps'),
      _trainingDay(
        profile: profile,
        title: _focusSessionTitle(profile),
        description: 'An emphasis day built around your chosen focus areas.',
        calories: 300,
        exercises: _pickSet(
          profile: profile,
          pool: exercises,
          usedIds: used,
          focusMuscles: _focusMusclesForProfile(profile, strongFocus: true),
          count: _exerciseTargetCount(profile),
        ),
      ),
      _trainingDay(
        profile: profile,
        title: 'Recovery Strength',
        description:
            'A lighter full-body session so you keep momentum without accumulating fatigue.',
        calories: 240,
        exercises: _pickSet(
          profile: profile,
          pool: exercises,
          usedIds: used,
          focusMuscles: [
            'abdominals',
            'gluteus maximus',
            'latissimus dorsi',
            'pectorals',
          ],
          count: _exerciseTargetCount(profile),
        ),
      ),
      _restDay(profile, exercises, used, 'Full Recovery'),
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

  static WorkoutDayPlan _restDay(
    UserModel profile,
    List<ExerciseDefinition> pool,
    Set<String> usedIds,
    String title,
  ) {
    return WorkoutDayPlan(
      title: title,
      description:
          'Light movement, posture work, and recovery drills matched to your weekly load.',
      durationMinutes: profile.sessionDurationMinutes <= 20 ? 16 : 24,
      estimatedCalories: profile.sessionDurationMinutes <= 20 ? 90 : 120,
      isRestDay: true,
      exercises: _pickRecoverySet(
        profile: profile,
        pool: pool,
        usedIds: usedIds,
        count: _recoveryExerciseTargetCount(profile),
      ),
    );
  }

  static List<WorkoutExercise> _pickRecoverySet({
    required UserModel profile,
    required List<ExerciseDefinition> pool,
    required Set<String> usedIds,
    required int count,
  }) {
    final ranked =
        pool
            .where((exercise) => !usedIds.contains(exercise.id))
            .map(
              (exercise) => MapEntry(
                exercise,
                _recoveryScoreExercise(profile: profile, exercise: exercise),
              ),
            )
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final selectedDefinitions = <ExerciseDefinition>[];
    for (final entry in ranked) {
      if (selectedDefinitions.length >= count) {
        break;
      }
      selectedDefinitions.add(entry.key);
    }

    if (selectedDefinitions.length < count) {
      final refill =
          pool
              .where(
                (exercise) =>
                    !selectedDefinitions.any((e) => e.id == exercise.id),
              )
              .map(
                (exercise) => MapEntry(
                  exercise,
                  _recoveryScoreExercise(profile: profile, exercise: exercise),
                ),
              )
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value));

      for (final entry in refill) {
        if (selectedDefinitions.length >= count) {
          break;
        }
        selectedDefinitions.add(entry.key);
      }
    }

    if (selectedDefinitions.isEmpty) {
      return _fallbackExercises(profile, count: count, recoveryOnly: true);
    }

    usedIds.addAll(selectedDefinitions.map((exercise) => exercise.id));
    return selectedDefinitions
        .map(
          (exercise) => _toWorkoutExercise(exercise, profile, recovery: true),
        )
        .toList(growable: false);
  }

  static List<WorkoutExercise> _pickSet({
    required UserModel profile,
    required List<ExerciseDefinition> pool,
    required Set<String> usedIds,
    required List<String> focusMuscles,
    String? forceBias,
    required int count,
  }) {
    final selectedDefinitions = _buildSegmentedSelection(
      profile: profile,
      pool: pool,
      usedIds: usedIds,
      focusMuscles: focusMuscles,
      forceBias: forceBias,
      count: count,
      allowReuse: false,
    );

    if (selectedDefinitions.length < count) {
      selectedDefinitions.addAll(
        _buildSegmentedSelection(
          profile: profile,
          pool: pool,
          usedIds: usedIds,
          focusMuscles: focusMuscles,
          forceBias: forceBias,
          count: count - selectedDefinitions.length,
          allowReuse: true,
          excludedIds: selectedDefinitions
              .map((exercise) => exercise.id)
              .toSet(),
        ),
      );
    }

    if (selectedDefinitions.isEmpty) {
      return _fallbackExercises(profile, count: count);
    }

    usedIds.addAll(selectedDefinitions.map((exercise) => exercise.id));
    return selectedDefinitions
        .map((exercise) => _toWorkoutExercise(exercise, profile))
        .toList(growable: false);
  }

  static List<ExerciseDefinition> _buildSegmentedSelection({
    required UserModel profile,
    required List<ExerciseDefinition> pool,
    required Set<String> usedIds,
    required List<String> focusMuscles,
    String? forceBias,
    required int count,
    required bool allowReuse,
    Set<String> excludedIds = const <String>{},
  }) {
    final selected = <ExerciseDefinition>[];
    final blockedIds = <String>{...excludedIds};
    final primaryTarget = switch (_normalize(profile.trainingLevel)) {
      'advanced' => count >= 8 ? 4 : 3,
      _ => 3,
    };
    final mobilityTarget = _mobilitySlotCount(profile, count);
    final coreTarget = _coreSlotCount(profile, count);
    final conditioningTarget = _conditioningSlotCount(
      profile,
      count,
      forceBias: forceBias,
    );

    _appendTopMatches(
      selected: selected,
      blockedIds: blockedIds,
      profile: profile,
      pool: pool,
      usedIds: usedIds,
      focusMuscles: focusMuscles,
      forceBias: forceBias,
      targetCount: mobilityTarget,
      allowReuse: allowReuse,
      filter: (exercise) =>
          _isMobilityExercise(exercise) || _isPostureSupportExercise(exercise),
      segmentBoost: 1.4,
    );

    _appendTopMatches(
      selected: selected,
      blockedIds: blockedIds,
      profile: profile,
      pool: pool,
      usedIds: usedIds,
      focusMuscles: focusMuscles,
      forceBias: forceBias,
      targetCount: primaryTarget,
      allowReuse: allowReuse,
      filter: (exercise) => _isPrimaryStrengthExercise(
        exercise,
        focusMuscles: focusMuscles,
        forceBias: forceBias,
      ),
      segmentBoost: 2.0,
    );

    _appendTopMatches(
      selected: selected,
      blockedIds: blockedIds,
      profile: profile,
      pool: pool,
      usedIds: usedIds,
      focusMuscles: focusMuscles,
      forceBias: forceBias,
      targetCount: (count - selected.length - coreTarget - conditioningTarget)
          .clamp(0, count),
      allowReuse: allowReuse,
      filter: (exercise) =>
          _matchesFocus(exercise, focusMuscles) ||
          _supportsFocus(exercise, focusMuscles),
      segmentBoost: 1.0,
    );

    _appendTopMatches(
      selected: selected,
      blockedIds: blockedIds,
      profile: profile,
      pool: pool,
      usedIds: usedIds,
      focusMuscles: focusMuscles,
      forceBias: forceBias,
      targetCount: coreTarget,
      allowReuse: allowReuse,
      filter: (exercise) =>
          _isCoreExercise(exercise) || _isPostureSupportExercise(exercise),
      segmentBoost: 1.1,
    );

    _appendTopMatches(
      selected: selected,
      blockedIds: blockedIds,
      profile: profile,
      pool: pool,
      usedIds: usedIds,
      focusMuscles: focusMuscles,
      forceBias: forceBias,
      targetCount: conditioningTarget,
      allowReuse: allowReuse,
      filter: _isConditioningExercise,
      segmentBoost: 1.0,
    );

    _appendTopMatches(
      selected: selected,
      blockedIds: blockedIds,
      profile: profile,
      pool: pool,
      usedIds: usedIds,
      focusMuscles: focusMuscles,
      forceBias: forceBias,
      targetCount: count - selected.length,
      allowReuse: allowReuse,
      filter: (_) => true,
    );

    return selected;
  }

  static void _appendTopMatches({
    required List<ExerciseDefinition> selected,
    required Set<String> blockedIds,
    required UserModel profile,
    required List<ExerciseDefinition> pool,
    required Set<String> usedIds,
    required List<String> focusMuscles,
    String? forceBias,
    required int targetCount,
    required bool allowReuse,
    required bool Function(ExerciseDefinition) filter,
    double segmentBoost = 0.0,
  }) {
    if (targetCount <= 0) {
      return;
    }

    final ranked =
        pool
            .where((exercise) => !blockedIds.contains(exercise.id))
            .where((exercise) => allowReuse || !usedIds.contains(exercise.id))
            .where(filter)
            .map(
              (exercise) => MapEntry(
                exercise,
                _candidateScore(
                      profile: profile,
                      exercise: exercise,
                      focusMuscles: focusMuscles,
                      forceBias: forceBias,
                      selected: selected,
                      globallyUnused: !usedIds.contains(exercise.id),
                    ) +
                    segmentBoost,
              ),
            )
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final initialLength = selected.length;
    for (final entry in ranked) {
      if (selected.length - initialLength >= targetCount) {
        break;
      }
      selected.add(entry.key);
      blockedIds.add(entry.key.id);
    }
  }

  static double _candidateScore({
    required UserModel profile,
    required ExerciseDefinition exercise,
    required List<String> focusMuscles,
    String? forceBias,
    required List<ExerciseDefinition> selected,
    bool globallyUnused = true,
  }) {
    return _scoreExercise(
          profile: profile,
          exercise: exercise,
          focusMuscles: focusMuscles,
          forceBias: forceBias,
          globallyUnused: globallyUnused,
        ) +
        _varietyScore(exercise, selected);
  }

  static double _varietyScore(
    ExerciseDefinition exercise,
    List<ExerciseDefinition> selected,
  ) {
    if (selected.isEmpty) {
      return 0.0;
    }

    var score = 0.0;
    final normalizedName = _normalize(exercise.name);
    if (selected.any((entry) => _normalize(entry.name) == normalizedName)) {
      return -8.0;
    }

    final primary = exercise.primaryMuscles.map(_normalize).toSet();
    final selectedPrimary = selected
        .expand((entry) => entry.primaryMuscles.map(_normalize))
        .toList(growable: false);
    final overlapCount = selectedPrimary.where(primary.contains).length;
    score -= overlapCount * 0.35;

    final category = _normalize(exercise.category);
    final seenCategories = selected
        .map((entry) => _normalize(entry.category))
        .where((entry) => entry.isNotEmpty)
        .toSet();
    if (category.isNotEmpty && !seenCategories.contains(category)) {
      score += 0.7;
    }

    final equipment = _normalize(exercise.equipment);
    final repeatedEquipment = selected
        .where((entry) => _normalize(entry.equipment) == equipment)
        .length;
    score -= repeatedEquipment * 0.18;

    final movementPattern = _movementPattern(exercise);
    final repeatedPatterns = selected
        .where((entry) => _movementPattern(entry) == movementPattern)
        .length;
    score -= repeatedPatterns * 0.22;

    if (exercise.images.length >= 2 &&
        !selected.any((entry) => entry.images.length >= 2)) {
      score += 0.4;
    }

    return score;
  }

  static double _scoreExercise({
    required UserModel profile,
    required ExerciseDefinition exercise,
    required List<String> focusMuscles,
    String? forceBias,
    bool globallyUnused = true,
  }) {
    var score = 0.0;
    final primary = exercise.primaryMuscles.map(_normalize).toSet();
    final secondary = exercise.secondaryMuscles.map(_normalize).toSet();
    final focus = focusMuscles.map(_normalize).toSet();

    score += primary.intersection(focus).length * 4.0;
    score += secondary.intersection(focus).length * 1.5;

    if (forceBias != null &&
        _normalize(exercise.force) == _normalize(forceBias)) {
      score += 3.0;
    }

    if (_focusMusclesForProfile(
      profile,
      strongFocus: true,
    ).map(_normalize).toSet().intersection(primary).isNotEmpty) {
      score += 2.5;
    }

    if (_goalMuscles(
      profile,
    ).map(_normalize).toSet().intersection(primary).isNotEmpty) {
      score += 2.0;
    }

    if (_normalize(exercise.mechanic) == 'compound') {
      score += 1.5;
    }

    if (_normalize(profile.fitnessGoal) == 'improve stamina' &&
        _normalize(exercise.category) != 'stretching') {
      score += 1.0;
    }

    final userLevel = _normalize(profile.trainingLevel);
    final exerciseLevel = _normalize(exercise.level);
    if (exerciseLevel.isEmpty) {
      score += 0.5;
    } else if (userLevel == exerciseLevel) {
      score += 2.0;
    } else if (exerciseLevel == 'beginner' && userLevel != 'beginner') {
      score += 0.8;
    }

    if (exercise.images.length >= 2) {
      score += 0.9;
    }

    score += _locationScore(profile, exercise);
    score += _sittingScore(profile, exercise);
    score += _goalScore(profile, exercise);

    if (globallyUnused) {
      score += 0.75;
    }

    return score;
  }

  static double _locationScore(UserModel profile, ExerciseDefinition exercise) {
    if (_normalize(profile.workoutLocation) != 'home') {
      return 0.0;
    }

    final equipment = _normalize(exercise.equipment);
    if (equipment.contains('barbell') ||
        equipment.contains('machine') ||
        equipment.contains('cable') ||
        equipment.contains('smith') ||
        equipment.contains('rack')) {
      return -2.0;
    }
    return 0.0;
  }

  static double _sittingScore(UserModel profile, ExerciseDefinition exercise) {
    final sitting = _normalize(profile.sittingHours);
    if (sitting != '6-8 hours' && sitting != '8+ hours') {
      return 0.0;
    }

    final primary = exercise.primaryMuscles.map(_normalize).toSet();
    if (primary.contains('lower back') ||
        primary.contains('abdominals') ||
        primary.contains('obliques') ||
        primary.contains('latissimus dorsi') ||
        primary.contains('erector spinae')) {
      return 2.0;
    }
    return 0.0;
  }

  static double _goalScore(UserModel profile, ExerciseDefinition exercise) {
    final goal = _normalize(profile.fitnessGoal);
    final category = _normalize(exercise.category);
    final mechanic = _normalize(exercise.mechanic);
    final force = _normalize(exercise.force);
    var score = 0.0;

    if (goal == 'gain muscle' && mechanic == 'compound') {
      score += 1.5;
    }
    if (goal == 'lose weight' && category == 'cardio') {
      score += 1.5;
    }
    if (goal == 'improve stamina' &&
        (category == 'cardio' || force == 'cardio')) {
      score += 1.5;
    }

    return score;
  }

  static int _mobilitySlotCount(UserModel profile, int exerciseCount) {
    if (_needsMobilitySupport(profile)) {
      return exerciseCount >= 8 ? 2 : 1;
    }
    return exerciseCount >= 10 ? 1 : 0;
  }

  static int _coreSlotCount(UserModel profile, int exerciseCount) {
    if (profile.hasTargetMuscleFocus('Core')) {
      return exerciseCount >= 8 ? 2 : 1;
    }
    if (profile.hasTargetMuscleFocus('Back & Posture') ||
        profile.fitnessGoal == 'Lose Weight') {
      return 2;
    }
    return 1;
  }

  static int _conditioningSlotCount(
    UserModel profile,
    int exerciseCount, {
    String? forceBias,
  }) {
    if (forceBias != null && forceBias.isNotEmpty) {
      return 0;
    }
    return switch (profile.fitnessGoal) {
      'Improve Stamina' => exerciseCount >= 8 ? 2 : 1,
      'Lose Weight' => exerciseCount >= 7 ? 2 : 1,
      _ => 0,
    };
  }

  static bool _needsMobilitySupport(UserModel profile) {
    return profile.occupation == 'Desk Job' ||
        profile.sittingHours == '6-8 Hours' ||
        profile.sittingHours == '8+ Hours' ||
        profile.selectedJointCareAreas.isNotEmpty;
  }

  static bool _isPrimaryStrengthExercise(
    ExerciseDefinition exercise, {
    required List<String> focusMuscles,
    String? forceBias,
  }) {
    if (_isMobilityExercise(exercise) || _isConditioningExercise(exercise)) {
      return false;
    }

    final mechanic = _normalize(exercise.mechanic);
    final force = _normalize(exercise.force);
    if (forceBias != null &&
        forceBias.isNotEmpty &&
        force == _normalize(forceBias) &&
        _matchesFocus(exercise, focusMuscles)) {
      return true;
    }

    return _matchesFocus(exercise, focusMuscles) &&
        (mechanic == 'compound' || force == 'push' || force == 'pull');
  }

  static bool _matchesFocus(
    ExerciseDefinition exercise,
    List<String> focusMuscles,
  ) {
    final focus = focusMuscles.map(_normalize).toSet();
    final primary = exercise.primaryMuscles.map(_normalize).toSet();
    return primary.intersection(focus).isNotEmpty;
  }

  static bool _supportsFocus(
    ExerciseDefinition exercise,
    List<String> focusMuscles,
  ) {
    final focus = focusMuscles.map(_normalize).toSet();
    final secondary = exercise.secondaryMuscles.map(_normalize).toSet();
    return secondary.intersection(focus).isNotEmpty ||
        (_normalize(exercise.mechanic) == 'compound' &&
            !_isMobilityExercise(exercise) &&
            !_isConditioningExercise(exercise));
  }

  static bool _isMobilityExercise(ExerciseDefinition exercise) {
    final category = _normalize(exercise.category);
    final force = _normalize(exercise.force);
    final text = _exerciseText(exercise);
    return category == 'stretching' ||
        force == 'static' ||
        text.contains('stretch') ||
        text.contains('mobility') ||
        text.contains('foam roll') ||
        text.contains('rotation') ||
        text.contains('circles');
  }

  static bool _isConditioningExercise(ExerciseDefinition exercise) {
    final category = _normalize(exercise.category);
    final force = _normalize(exercise.force);
    final text = _exerciseText(exercise);
    return category == 'cardio' ||
        force == 'cardio' ||
        text.contains('sprint') ||
        text.contains('jump') ||
        text.contains('run') ||
        text.contains('bike') ||
        text.contains('rope') ||
        text.contains('row');
  }

  static bool _isCoreExercise(ExerciseDefinition exercise) {
    final muscles = <String>{
      ...exercise.primaryMuscles.map(_normalize),
      ...exercise.secondaryMuscles.map(_normalize),
    };
    final text = _exerciseText(exercise);
    return muscles.any(
          (muscle) =>
              muscle.contains('abdominal') ||
              muscle.contains('oblique') ||
              muscle.contains('core') ||
              muscle.contains('lower back'),
        ) ||
        text.contains('plank') ||
        text.contains('dead bug') ||
        text.contains('bird dog') ||
        text.contains('crunch') ||
        text.contains('sit-up');
  }

  static bool _isPostureSupportExercise(ExerciseDefinition exercise) {
    final muscles = <String>{
      ...exercise.primaryMuscles.map(_normalize),
      ...exercise.secondaryMuscles.map(_normalize),
    };
    return muscles.any(
      (muscle) =>
          muscle.contains('lat') ||
          muscle.contains('trape') ||
          muscle.contains('rear delt') ||
          muscle.contains('lower back') ||
          muscle.contains('erector') ||
          muscle.contains('oblique'),
    );
  }

  static String _exerciseText(ExerciseDefinition exercise) {
    return '${exercise.name} ${exercise.instructions.join(' ')}'.toLowerCase();
  }

  static double _recoveryScoreExercise({
    required UserModel profile,
    required ExerciseDefinition exercise,
  }) {
    var score = 0.0;
    final category = _normalize(exercise.category);
    final mechanic = _normalize(exercise.mechanic);
    final equipment = _normalize(exercise.equipment);
    final force = _normalize(exercise.force);
    final allText = '${exercise.name} ${exercise.instructions.join(' ')}'
        .toLowerCase();

    if (exercise.images.length >= 2) {
      score += 2.0;
    }
    if (category == 'stretching') {
      score += 4.0;
    }
    if (category == 'cardio') {
      score += 2.5;
    }
    if (mechanic == 'isolation') {
      score += 1.5;
    }
    if (equipment.isEmpty ||
        equipment == 'body only' ||
        equipment == 'body weight' ||
        equipment == 'none') {
      score += 2.0;
    }
    if (force == 'static') {
      score += 1.5;
    }
    if (allText.contains('stretch') ||
        allText.contains('mobility') ||
        allText.contains('walk') ||
        allText.contains('plank') ||
        allText.contains('dead bug') ||
        allText.contains('bird dog')) {
      score += 2.5;
    }
    if (allText.contains('jump') ||
        allText.contains('sprint') ||
        allText.contains('power') ||
        allText.contains('max')) {
      score -= 3.0;
    }
    if (!_jointCompatible(profile.jointSensitivities, exercise)) {
      score -= 5.0;
    }

    return score;
  }

  static WorkoutExercise _toWorkoutExercise(
    ExerciseDefinition exercise,
    UserModel profile, {
    bool recovery = false,
  }) {
    final muscles = exercise.primaryMuscles.isEmpty
        ? exercise.secondaryMuscles
        : exercise.primaryMuscles;
    final animationFrames = exercise.images.take(2).toList(growable: false);

    return WorkoutExercise(
      name: exercise.name.trim(),
      prescription: _prescriptionFor(profile, exercise, recovery: recovery),
      targetDurationSeconds: _targetDurationSecondsFor(
        profile,
        exercise,
        recovery: recovery,
      ),
      targetRepCount: _targetRepCountFor(profile, exercise, recovery: recovery),
      cycleCount: _cycleCountFor(profile, exercise, recovery: recovery),
      cycleLabel: _cycleLabelFor(exercise, recovery: recovery),
      cue: exercise.instructions.isNotEmpty
          ? exercise.instructions.first
          : 'Move with control and steady breathing.',
      animationAsset: animationFrames.isNotEmpty ? animationFrames.first : '',
      animationType: animationFrames.isNotEmpty ? 'frames' : 'placeholder',
      animationFrames: animationFrames,
      animationFramesSource: exercise.imageSource,
      primaryMuscles: muscles
          .map(_displayMuscle)
          .take(3)
          .toList(growable: false),
      secondaryMuscles: exercise.secondaryMuscles
          .map(_displayMuscle)
          .take(4)
          .toList(growable: false),
      bodyMapZones: _bodyMapZones(exercise),
      equipment: _displayEquipment(exercise.equipment),
      difficulty: _displayDifficulty(exercise.level),
      movementPattern: recovery ? 'Recovery' : _movementPattern(exercise),
    );
  }

  static List<WorkoutExercise> _fallbackExercises(
    UserModel profile, {
    required int count,
    bool recoveryOnly = false,
  }) {
    return List<WorkoutExercise>.generate(
      count,
      (_) => WorkoutExercise(
        name: recoveryOnly ? 'Mobility Reset' : 'Bodyweight Movement',
        prescription: recoveryOnly ? '2 rounds · 35 sec' : '3 sets · 12 reps',
        targetDurationSeconds: recoveryOnly ? 35 : null,
        targetRepCount: recoveryOnly ? null : 12,
        cycleCount: recoveryOnly ? 2 : 3,
        cycleLabel: recoveryOnly ? 'Round' : 'Set',
        cue: recoveryOnly
            ? 'Move gently, breathe deeply, and stay pain-free through each rep.'
            : 'Move with control, steady breathing, and a strong brace.',
        animationAsset: '',
        animationType: 'placeholder',
        primaryMuscles: const ['Full Body'],
        secondaryMuscles: const ['Core', 'Posture'],
        bodyMapZones: const ['core', 'glutes', 'upperBack'],
        equipment: 'Bodyweight',
        difficulty: profile.trainingLevel,
        movementPattern: recoveryOnly ? 'Recovery' : 'General',
      ),
    );
  }

  static int _sessionDuration(UserModel profile) {
    var minutes = profile.sessionDurationMinutes;
    if (profile.trainingLevel == 'Beginner' && minutes > 50) {
      minutes = 50;
    }
    if (profile.workoutDays >= 5 && minutes < 35) {
      minutes = 35;
    }
    return minutes;
  }

  static int _exerciseTargetCount(UserModel profile) {
    final minutes = _sessionDuration(profile);
    var count = switch (minutes) {
      <= 20 => 5,
      <= 30 => 6,
      <= 40 => 7,
      <= 50 => 8,
      <= 65 => 9,
      _ => 10,
    };

    if (profile.workoutDays <= 2) {
      count += 1;
    }
    if (_normalize(profile.fitnessGoal) == 'gain muscle' && count < 7) {
      count = 7;
    }
    if (_normalize(profile.trainingLevel) == 'advanced' && minutes >= 45) {
      count += 1;
    }
    return count.clamp(5, 10).toInt();
  }

  static int _recoveryExerciseTargetCount(UserModel profile) {
    return _sessionDuration(profile) <= 30 ? 4 : 5;
  }

  static String _prescriptionFor(
    UserModel profile,
    ExerciseDefinition exercise, {
    bool recovery = false,
  }) {
    final category = _normalize(exercise.category);
    final force = _normalize(exercise.force);
    final timedSeconds = _targetDurationSecondsFor(
      profile,
      exercise,
      recovery: recovery,
    );
    final cycleCount = _cycleCountFor(profile, exercise, recovery: recovery);
    final cycleLabel = _cycleLabelFor(
      exercise,
      recovery: recovery,
    ).toLowerCase();
    final repCount = _targetRepCountFor(profile, exercise, recovery: recovery);

    if (timedSeconds != null) {
      return '$cycleCount ${_pluralize(cycleLabel, cycleCount)} · $timedSeconds sec';
    }

    if (repCount != null) {
      return '$cycleCount ${_pluralize(cycleLabel, cycleCount)} · $repCount reps';
    }

    if (category == 'stretching' || force == 'static' || recovery) {
      return '$cycleCount ${_pluralize(cycleLabel, cycleCount)} · 30 sec';
    }

    return '$cycleCount ${_pluralize(cycleLabel, cycleCount)} · 12 reps';
  }

  static int _cycleCountFor(
    UserModel profile,
    ExerciseDefinition exercise, {
    bool recovery = false,
  }) {
    final level = _normalize(profile.trainingLevel);
    final goal = _normalize(profile.fitnessGoal);
    final category = _normalize(exercise.category);
    final force = _normalize(exercise.force);
    final mechanic = _normalize(exercise.mechanic);

    if (recovery) {
      return category == 'cardio' ? 3 : 2;
    }
    if (_targetDurationSecondsFor(profile, exercise, recovery: recovery) !=
        null) {
      return level == 'advanced' ? 5 : 4;
    }
    if (force == 'push' || force == 'pull' || mechanic == 'compound') {
      if (goal == 'gain muscle') {
        return switch (level) {
          'advanced' => 5,
          'intermediate' => 4,
          _ => 3,
        };
      }
      return switch (level) {
        'advanced' => 4,
        'intermediate' => 4,
        _ => 3,
      };
    }
    return switch (level) {
      'advanced' => 4,
      'intermediate' => 3,
      _ => 3,
    };
  }

  static String _cycleLabelFor(
    ExerciseDefinition exercise, {
    bool recovery = false,
  }) {
    final category = _normalize(exercise.category);
    final force = _normalize(exercise.force);
    if (recovery || category == 'stretching' || force == 'static') {
      return 'Round';
    }
    if (_isConditioningExercise(exercise)) {
      return 'Round';
    }
    return 'Set';
  }

  static int? _targetRepCountFor(
    UserModel profile,
    ExerciseDefinition exercise, {
    bool recovery = false,
  }) {
    if (_targetDurationSecondsFor(profile, exercise, recovery: recovery) !=
        null) {
      return null;
    }

    final goal = _normalize(profile.fitnessGoal);
    final level = _normalize(profile.trainingLevel);
    final force = _normalize(exercise.force);
    final mechanic = _normalize(exercise.mechanic);

    if (force == 'push' || force == 'pull' || mechanic == 'compound') {
      if (goal == 'gain muscle') {
        return switch (level) {
          'advanced' => 8,
          'intermediate' => 10,
          _ => 10,
        };
      }
      return switch (level) {
        'advanced' => 8,
        'intermediate' => 10,
        _ => 10,
      };
    }

    return switch (level) {
      'advanced' => 12,
      'intermediate' => 12,
      _ => 14,
    };
  }

  static int? _targetDurationSecondsFor(
    UserModel profile,
    ExerciseDefinition exercise, {
    bool recovery = false,
  }) {
    final level = _normalize(profile.trainingLevel);
    final goal = _normalize(profile.fitnessGoal);
    final category = _normalize(exercise.category);
    final force = _normalize(exercise.force);

    if (recovery) {
      if (category == 'cardio') {
        return 45;
      }
      if (_isMobilityExercise(exercise) || force == 'static') {
        return switch (level) {
          'advanced' => 45,
          'intermediate' => 40,
          _ => 35,
        };
      }
      return 30;
    }

    if (category == 'stretching' || force == 'static') {
      return switch (level) {
        'advanced' => 45,
        'intermediate' => 40,
        _ => 30,
      };
    }

    if (goal == 'improve stamina' || _isConditioningExercise(exercise)) {
      return switch (level) {
        'advanced' => 45,
        'intermediate' => 40,
        _ => 30,
      };
    }

    return null;
  }

  static bool _equipmentCompatible(
    String availableEquipment,
    String exerciseEquipment,
  ) {
    final available = _normalize(availableEquipment);
    final equipment = _normalize(exerciseEquipment);

    if (available == 'full gym') {
      return true;
    }
    if (available == 'bodyweight') {
      return equipment.isEmpty ||
          equipment == 'body only' ||
          equipment == 'none' ||
          equipment == 'body weight';
    }
    if (available == 'bands dumbbells' || available == 'bands & dumbbells') {
      return equipment.isEmpty ||
          equipment == 'body only' ||
          equipment == 'body weight' ||
          equipment.contains('dumbbell') ||
          equipment.contains('band') ||
          equipment.contains('kettlebell');
    }
    return true;
  }

  static bool _levelCompatible(String trainingLevel, String exerciseLevel) {
    const order = <String, int>{
      'beginner': 0,
      'intermediate': 1,
      'advanced': 2,
    };
    final userLevel = order[_normalize(trainingLevel)] ?? 0;
    final level = order[_normalize(exerciseLevel)] ?? 0;
    return level <= userLevel;
  }

  static bool _jointCompatible(
    Iterable<String> jointSensitivities,
    ExerciseDefinition exercise,
  ) {
    final sensitivities = jointSensitivities
        .map(_normalize)
        .where((value) => value.isNotEmpty && value != 'none')
        .toSet();
    if (sensitivities.isEmpty) {
      return true;
    }

    final haystack = '${exercise.name} ${exercise.instructions.join(' ')}'
        .toLowerCase();

    if (sensitivities.contains('knees') &&
        (haystack.contains('jump') || haystack.contains('sprint'))) {
      return false;
    }
    if (sensitivities.contains('lower back') &&
        (haystack.contains('good morning') ||
            haystack.contains('maximal') ||
            haystack.contains('heavy'))) {
      return false;
    }
    if (sensitivities.contains('shoulders') &&
        (haystack.contains('upright row') ||
            haystack.contains('behind the neck'))) {
      return false;
    }

    return true;
  }

  static List<String> _focusMusclesForProfile(
    UserModel profile, {
    bool strongFocus = false,
  }) {
    final focusAreas = profile.selectedFocusAreas;
    if (focusAreas.isEmpty) {
      return ['pectorals', 'latissimus dorsi', 'quadriceps', 'abdominals'];
    }

    final focusMuscles = <String>{};
    for (final focusArea in focusAreas) {
      switch (focusArea) {
        case 'Upper Body':
          focusMuscles.addAll(
            strongFocus
                ? const [
                    'pectorals',
                    'latissimus dorsi',
                    'deltoids',
                    'triceps',
                    'biceps',
                  ]
                : const ['pectorals', 'latissimus dorsi', 'deltoids'],
          );
          break;
        case 'Lower Body':
          focusMuscles.addAll(
            strongFocus
                ? const [
                    'quadriceps',
                    'gluteus maximus',
                    'hamstrings',
                    'calves',
                  ]
                : const ['quadriceps', 'gluteus maximus', 'hamstrings'],
          );
          break;
        case 'Core':
          focusMuscles.addAll(
            strongFocus
                ? const ['abdominals', 'obliques', 'lower back']
                : const ['abdominals', 'obliques'],
          );
          break;
        case 'Back & Posture':
          focusMuscles.addAll(
            strongFocus
                ? const [
                    'latissimus dorsi',
                    'trapezius',
                    'rear deltoids',
                    'lower back',
                  ]
                : const ['latissimus dorsi', 'trapezius'],
          );
          break;
      }
    }

    return focusMuscles.toList(growable: false);
  }

  static List<String> _goalMuscles(UserModel profile) {
    switch (profile.fitnessGoal) {
      case 'Gain Muscle':
        return [
          'pectorals',
          'quadriceps',
          'latissimus dorsi',
          'gluteus maximus',
        ];
      case 'Lose Weight':
        return ['abdominals', 'gluteus maximus', 'quadriceps', 'obliques'];
      case 'Improve Stamina':
        return ['abdominals', 'quadriceps', 'calves', 'gluteus maximus'];
      default:
        return ['pectorals', 'latissimus dorsi', 'quadriceps', 'abdominals'];
    }
  }

  static List<String> _bodyMapZones(ExerciseDefinition exercise) {
    final allMuscles = <String>{
      ...exercise.primaryMuscles.map(_normalize),
      ...exercise.secondaryMuscles.map(_normalize),
    };
    final zones = <String>{};

    if (allMuscles.any((m) => m.contains('pectoral') || m.contains('chest'))) {
      zones.add('chest');
    }
    if (allMuscles.any(
      (m) => m.contains('deltoid') || m.contains('shoulder'),
    )) {
      zones.add('frontShoulders');
    }
    if (allMuscles.any(
      (m) => m.contains('lat') || m.contains('trape') || m.contains('back'),
    )) {
      zones.add('upperBack');
    }
    if (allMuscles.any((m) => m.contains('biceps'))) {
      zones.add('biceps');
    }
    if (allMuscles.any((m) => m.contains('triceps'))) {
      zones.add('triceps');
    }
    if (allMuscles.any(
      (m) => m.contains('abdominal') || m.contains('oblique'),
    )) {
      zones.add('core');
    }
    if (allMuscles.any((m) => m.contains('glute'))) {
      zones.add('glutes');
    }
    if (allMuscles.any((m) => m.contains('quad'))) {
      zones.add('quads');
    }
    if (allMuscles.any((m) => m.contains('hamstring'))) {
      zones.add('hamstrings');
    }
    if (allMuscles.any((m) => m.contains('calves') || m.contains('soleus'))) {
      zones.add('calves');
    }

    return zones.isEmpty ? const ['core'] : zones.toList(growable: false);
  }

  static String _movementPattern(ExerciseDefinition exercise) {
    final force = _normalize(exercise.force);
    final category = _normalize(exercise.category);
    final mechanic = _normalize(exercise.mechanic);

    if (category == 'cardio') {
      return 'Conditioning';
    }
    if (force == 'push') {
      return 'Push';
    }
    if (force == 'pull') {
      return 'Pull';
    }
    if (mechanic == 'compound') {
      return 'Compound Strength';
    }
    return 'General';
  }

  static String _displayEquipment(String equipment) {
    if (equipment.isEmpty) {
      return 'Bodyweight';
    }
    return equipment
        .split(RegExp(r'[\s_-]+'))
        .where((part) => part.isNotEmpty)
        .map(_capitalize)
        .join(' ');
  }

  static String _displayDifficulty(String level) {
    final normalized = _normalize(level);
    return switch (normalized) {
      'intermediate' => 'Medium',
      'advanced' => 'Advanced',
      _ => 'Beginner',
    };
  }

  static String _displayMuscle(String muscle) {
    return muscle
        .split(RegExp(r'[\s_-]+'))
        .where((part) => part.isNotEmpty)
        .map(_capitalize)
        .join(' ');
  }

  static String _normalize(String value) {
    return value.toLowerCase().trim();
  }

  static String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }
    return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
  }

  static String _pluralize(String value, int count) {
    return count == 1 ? value : '${value}s';
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

    final focusLine = _focusLine(profile);

    return '${_capitalize(goalLine)} $focusLine';
  }

  static String _insight(UserModel profile, int exerciseCount) {
    final sourceLine = exerciseCount >= 100
        ? 'Your plan is being drawn from the full exercise library.'
        : 'Your plan is using the starter exercise pack while the full library syncs.';
    final densityLine =
        'Each session is curated to ${_exerciseTargetCount(profile)} movements so the workload stays realistic.';
    final postureNote =
        profile.sittingHours == '6-8 Hours' ||
            profile.sittingHours == '8+ Hours'
        ? 'Long sitting days are balanced with posture and mobility support.'
        : '';
    final intensityNote = switch (profile.trainingLevel) {
      'Intermediate' =>
        'You are on a medium training load so progress feels challenging but sustainable.',
      'Advanced' =>
        'The plan keeps higher-output work in the week without overloading every session.',
      _ =>
        'The plan favors approachable progressions so form and consistency stay strong.',
    };
    final equipmentNote = switch (profile.availableEquipment) {
      'Bodyweight' => 'Movements stay simple and home-friendly.',
      'Bands & Dumbbells' =>
        'Band and dumbbell options are mixed in for progression.',
      _ => 'Gym equipment opens up more loading options and variety.',
    };
    return '$sourceLine $densityLine $intensityNote${postureNote.isNotEmpty ? ' $postureNote' : ''} $equipmentNote';
  }

  static String _goalBasedTitle(
    UserModel profile,
    String standard,
    String athletic,
  ) {
    return profile.fitnessGoal == 'Improve Stamina' ? athletic : standard;
  }

  static String _focusSessionTitle(UserModel profile) {
    final focusAreas = profile.visibleFocusAreas;
    if (focusAreas.length == 1) {
      switch (focusAreas.first) {
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

    return '${focusAreas.join(' + ')} Focus';
  }

  static String _focusLine(UserModel profile) {
    final focusAreas = profile.selectedFocusAreas;
    if (focusAreas.isEmpty) {
      return 'with balanced weekly recovery';
    }

    final descriptors = focusAreas
        .map(
          (focusArea) => switch (focusArea) {
            'Upper Body' => 'upper-body',
            'Lower Body' => 'lower-body',
            'Core' => 'trunk and posture',
            'Back & Posture' => 'posture-supportive back',
            _ => _normalize(focusArea),
          },
        )
        .toList(growable: false);

    return 'with extra ${_joinWithAnd(descriptors)} emphasis';
  }

  static String _joinWithAnd(List<String> values) {
    if (values.isEmpty) {
      return '';
    }
    if (values.length == 1) {
      return values.first;
    }
    if (values.length == 2) {
      return '${values[0]} and ${values[1]}';
    }
    return '${values.sublist(0, values.length - 1).join(', ')}, and ${values.last}';
  }
}
