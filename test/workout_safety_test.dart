import 'package:flutter_test/flutter_test.dart';
import 'package:fitforge/models/exercise_library_models.dart';
import 'package:fitforge/models/user_model.dart';
import 'package:fitforge/services/workout_engine_service.dart';

ExerciseDefinition ex(
  String name, {
  String category = 'strength',
  String force = 'push',
  String mechanic = 'compound',
  List<String> primary = const ['quadriceps'],
  List<String> instructions = const ['Move with control.'],
}) {
  return ExerciseDefinition(
    id: name.toLowerCase().replaceAll(' ', '_'),
    name: name,
    force: force,
    level: 'beginner',
    mechanic: mechanic,
    equipment: 'body only',
    primaryMuscles: primary,
    secondaryMuscles: const <String>[],
    instructions: instructions,
    category: category,
    images: const <String>[],
  );
}

void main() {
  // 60-year-old, heart stent + knee injury, just wants to stay active.
  final grandma = UserModel(
    id: 'u1',
    email: 'g@x.com',
    name: 'Saritha',
    gender: 'female',
    age: 60,
    fitnessGoal: 'Stay Active',
    workoutDays: 2,
    trainingLevel: 'Beginner',
    availableEquipment: 'Bodyweight',
    sessionDurationMinutes: 30,
    jointSensitivity: 'Knees',
    injuryNotes: 'Avoid jumping, avoid running, has a stent in heart.',
  );

  final dangerous = <ExerciseDefinition>[
    ex('Fast Skipping', category: 'cardio', force: 'cardio'),
    ex('Bodyweight Walking Lunge'),
    ex('Wheel Run', instructions: const ['Start in a plank and run on the wheel.']),
    ex('Alternate Leg Diagonal Bound', category: 'cardio'),
    ex('Knee Circles', category: 'stretching', force: 'static'),
    ex('High Knee Run', category: 'cardio', force: 'cardio'),
    ex('Box Jump', category: 'plyometrics'),
    ex('Burpees', category: 'cardio', force: 'cardio'),
    ex('Sprint Intervals', category: 'cardio', force: 'cardio'),
    // No dangerous keyword in its name/cues — only the plyometrics *category*
    // flags it. Guards the category-level gate (old keyword-only logic missed
    // this).
    ex(
      'Reactive Footwork Drill',
      category: 'plyometrics',
      instructions: const ['Move quickly through the pattern.'],
    ),
  ];

  final safe = <ExerciseDefinition>[
    ex('Wall Push-up', primary: const ['pectorals']),
    ex('Glute Bridge', primary: const ['gluteus maximus']),
    ex('Seated Shoulder Stretch', category: 'stretching', force: 'static', primary: const ['deltoids']),
    ex('Bird Dog', primary: const ['abdominals']),
    ex('Standing March', category: 'cardio', force: 'cardio', primary: const ['quadriceps'], instructions: const ['March gently in place.']),
    ex('Seated Band Row', primary: const ['latissimus dorsi']),
    ex('Dead Bug', primary: const ['abdominals']),
    ex('Calf Raise', primary: const ['calves']),
    ex('Wall Sit Hold', primary: const ['quadriceps'], instructions: const ['Hold a seated position against the wall.']),
    ex('Standing Side Leg Lift', primary: const ['gluteus maximus']),
  ];

  test('unsafe movements never reach a cardiac + knee-injured senior plan', () {
    final rec = WorkoutEngineService.buildRecommendation(
      profile: grandma,
      exercises: [...dangerous, ...safe],
    );

    final prescribed = <String>{
      for (final day in rec.weeklyPlan)
        for (final exercise in day.exercises) exercise.name.toLowerCase(),
    };

    for (final bad in dangerous) {
      expect(
        prescribed.contains(bad.name.toLowerCase()),
        isFalse,
        reason: '"${bad.name}" must be filtered out for this profile',
      );
    }

    // The plan should still be built from the safe pool (not empty / not all
    // generic fallback).
    final usedSafe = prescribed.intersection(
      safe.map((e) => e.name.toLowerCase()).toSet(),
    );
    expect(usedSafe, isNotEmpty, reason: 'safe exercises should be selected');
  });

  test('healthy young user is unaffected by the safety gate', () {
    final young = UserModel(
      id: 'u2',
      email: 'y@x.com',
      name: 'Ravi',
      gender: 'male',
      age: 28,
      fitnessGoal: 'Improve Stamina',
      workoutDays: 3,
      trainingLevel: 'Intermediate',
      availableEquipment: 'Bodyweight',
      sessionDurationMinutes: 30,
    );
    final rec = WorkoutEngineService.buildRecommendation(
      profile: young,
      exercises: [...dangerous, ...safe],
    );
    final prescribed = <String>{
      for (final day in rec.weeklyPlan)
        for (final exercise in day.exercises) exercise.name.toLowerCase(),
    };
    // A healthy user can receive higher-intensity work (e.g. sprints/jumps).
    expect(prescribed, isNotEmpty);
  });
}
