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
    switch (profile.fitnessGoal) {
      case 'Gain Muscle':
        return 'Muscle-building split with steady weekly volume';
      case 'Lose Weight':
        return 'Fat-loss friendly plan with strength and conditioning';
      case 'Improve Stamina':
        return 'Endurance-first week with smart full-body sessions';
      default:
        return 'Consistent movement plan built for your schedule';
    }
  }

  static String _insight(UserModel profile) {
    final mobilityNote = profile.sittingHours == '6-8 Hours' ||
            profile.sittingHours == '8+ Hours'
        ? 'Extra mobility is added because you spend long hours sitting.'
        : 'Your warm-ups stay short so you can start quickly.';

    final workloadNote = profile.workoutDays >= 5
        ? 'Higher training frequency unlocks a more focused split.'
        : 'Your sessions are kept efficient to match your available days.';

    return '$mobilityNote $workloadNote';
  }

  static List<WorkoutDayPlan> _buildWeeklyPlan(UserModel profile) {
    if (profile.workoutDays <= 2) return _twoDayPlan();
    if (profile.workoutDays == 3) return _threeDayPlan(profile);
    if (profile.workoutDays == 4) return _fourDayPlan(profile);
    return _fivePlusDayPlan(profile);
  }

  static List<WorkoutDayPlan> _twoDayPlan() {
    return [
      _trainingDay(
        title: 'Full Body Strength',
        description: 'Push, pull, squat, and core in one session.',
        minutes: 42,
        calories: 280,
        exercises: [
          _exercise('Goblet Squat', '4 sets · 10 reps', 'Drive through your heels'),
          _exercise('Push-Up', '4 sets · 8-12 reps', 'Keep your ribs tucked'),
          _exercise('Bent-Over Row', '3 sets · 10 reps', 'Pull elbows toward hips'),
          _exercise('Dead Bug', '3 sets · 12 reps', 'Brace the core throughout'),
        ],
      ),
      _restDay('Recovery Walk + Mobility'),
      _trainingDay(
        title: 'Full Body Conditioning',
        description: 'Low equipment circuit to build work capacity.',
        minutes: 38,
        calories: 260,
        exercises: [
          _exercise('Split Squat', '3 sets · 10 each side', 'Stay upright'),
          _exercise('Incline Push-Up', '3 sets · 12 reps', 'Control the lowering'),
          _exercise('Glute Bridge', '4 sets · 12 reps', 'Pause at the top'),
          _exercise('Plank Shoulder Taps', '3 sets · 20 taps', 'Minimize hip sway'),
        ],
      ),
      _restDay('Mobility Reset'),
      _restDay('Walking + Stretching'),
      _restDay('Optional Core Flow'),
      _restDay('Full Recovery'),
    ];
  }

  static List<WorkoutDayPlan> _threeDayPlan(UserModel profile) {
    if (profile.fitnessGoal == 'Gain Muscle') {
      return [
        _trainingDay(
          title: 'Upper Body Push',
          description: 'Chest, shoulders, and triceps focus.',
          minutes: 45,
          calories: 320,
          exercises: [
            _exercise('Bench Press', '4 sets · 8-10 reps', 'Lower with control'),
            _exercise('Shoulder Press', '3 sets · 10 reps', 'Stack wrists over elbows'),
            _exercise('Tricep Dips', '3 sets · 10-12 reps', 'Stay tall through the chest'),
            _exercise('Lateral Raise', '3 sets · 15 reps', 'Lift to shoulder height'),
          ],
        ),
        _restDay('Mobility + Steps'),
        _trainingDay(
          title: 'Upper Body Pull',
          description: 'Back and biceps strength work.',
          minutes: 44,
          calories: 300,
          exercises: [
            _exercise('Lat Pulldown', '4 sets · 10 reps', 'Lead with elbows'),
            _exercise('Seated Row', '3 sets · 10-12 reps', 'Pause at the squeeze'),
            _exercise('Face Pull', '3 sets · 15 reps', 'Finish with high elbows'),
            _exercise('Hammer Curl', '3 sets · 12 reps', 'Control the lowering'),
          ],
        ),
        _restDay('Recovery Walk'),
        _trainingDay(
          title: 'Leg Day + Core',
          description: 'Lower body strength and trunk stability.',
          minutes: 48,
          calories: 340,
          exercises: [
            _exercise('Leg Press', '4 sets · 10 reps', 'Keep knees tracking out'),
            _exercise('Romanian Deadlift', '3 sets · 10 reps', 'Hinge through the hips'),
            _exercise('Walking Lunge', '3 sets · 12 each side', 'Long controlled steps'),
            _exercise('Forearm Plank', '3 sets · 40 sec', 'Brace and breathe'),
          ],
        ),
        _restDay('Full Recovery'),
        _restDay('Optional Stretch'),
      ];
    }

    return [
      _trainingDay(
        title: 'Full Body Strength',
        description: 'A foundational session built for consistency.',
        minutes: 40,
        calories: 290,
        exercises: [
          _exercise('Squat to Box', '4 sets · 10 reps', 'Stay balanced through the foot'),
          _exercise('Push-Up', '3 sets · 8-12 reps', 'Keep your body in one line'),
          _exercise('Dumbbell Row', '3 sets · 10 each side', 'Squeeze your back'),
          _exercise('Mountain Climber', '3 sets · 30 sec', 'Move with rhythm'),
        ],
      ),
      _restDay('Recovery Walk'),
      _trainingDay(
        title: 'Lower Body + Core',
        description: 'Leg strength with posture-supporting core work.',
        minutes: 42,
        calories: 300,
        exercises: [
          _exercise('Reverse Lunge', '3 sets · 10 each side', 'Step back softly'),
          _exercise('Glute Bridge', '4 sets · 12 reps', 'Finish with a glute squeeze'),
          _exercise('Calf Raise', '3 sets · 15 reps', 'Pause at the top'),
          _exercise('Dead Bug', '3 sets · 12 reps', 'Move slowly'),
        ],
      ),
      _restDay('Stretch + Mobility'),
      _trainingDay(
        title: profile.fitnessGoal == 'Improve Stamina'
            ? 'Conditioning Circuit'
            : 'Upper Body + Conditioning',
        description: 'A higher-tempo session to improve capacity.',
        minutes: 36,
        calories: 310,
        exercises: [
          _exercise('Incline Push-Up', '3 sets · 12 reps', 'Stay strong in the core'),
          _exercise('Band Pull-Apart', '3 sets · 15 reps', 'Open through the chest'),
          _exercise('Step-Up', '3 sets · 12 each side', 'Drive through the front leg'),
          _exercise('Jump Rope / March', '6 rounds · 40 sec', 'Keep a steady pace'),
        ],
      ),
      _restDay('Full Recovery'),
      _restDay('Optional Walk'),
    ];
  }

  static List<WorkoutDayPlan> _fourDayPlan(UserModel profile) {
    return [
      _trainingDay(
        title: 'Upper Body Push',
        description: 'Pressing volume with shoulder support work.',
        minutes: 46,
        calories: 320,
        exercises: [
          _exercise('Bench Press', '4 sets · 8 reps', 'Own each rep'),
          _exercise('Incline Dumbbell Press', '3 sets · 10 reps', 'Control the stretch'),
          _exercise('Shoulder Press', '3 sets · 10 reps', 'Brace before pressing'),
          _exercise('Lateral Raise', '3 sets · 15 reps', 'Avoid shrugging'),
        ],
      ),
      _trainingDay(
        title: 'Lower Body Strength',
        description: 'Squat, hinge, and unilateral work.',
        minutes: 50,
        calories: 360,
        exercises: [
          _exercise('Back Squat', '4 sets · 6-8 reps', 'Stay stacked'),
          _exercise('Romanian Deadlift', '3 sets · 8 reps', 'Push hips back'),
          _exercise('Bulgarian Split Squat', '3 sets · 10 each side', 'Slow on the way down'),
          _exercise('Hollow Hold', '3 sets · 30 sec', 'Flatten the lower back'),
        ],
      ),
      _restDay('Mobility + Walking'),
      _trainingDay(
        title: 'Upper Body Pull',
        description: 'Back, rear delts, and arm work.',
        minutes: 44,
        calories: 300,
        exercises: [
          _exercise('Pull-Down', '4 sets · 10 reps', 'Lead with elbows'),
          _exercise('Chest-Supported Row', '3 sets · 10 reps', 'Pause at the top'),
          _exercise('Rear Delt Fly', '3 sets · 15 reps', 'Move light and controlled'),
          _exercise('Bicep Curl', '3 sets · 12 reps', 'No swinging'),
        ],
      ),
      _trainingDay(
        title: profile.fitnessGoal == 'Lose Weight'
            ? 'Conditioning + Core'
            : 'Lower Body Power',
        description: 'Finish the week with athletic work and conditioning.',
        minutes: 38,
        calories: 330,
        exercises: [
          _exercise('Kettlebell Swing', '4 sets · 15 reps', 'Snap the hips'),
          _exercise('Step-Up', '3 sets · 12 each side', 'Drive through the heel'),
          _exercise('Farmer Carry', '4 rounds · 30 sec', 'Stand tall'),
          _exercise('Plank', '3 sets · 45 sec', 'Brace and breathe'),
        ],
      ),
      _restDay('Easy Cardio'),
      _restDay('Full Recovery'),
    ];
  }

  static List<WorkoutDayPlan> _fivePlusDayPlan(UserModel profile) {
    return [
      _trainingDay(
        title: 'Push Day',
        description: 'Chest, shoulders, and triceps.',
        minutes: 48,
        calories: 330,
        exercises: [
          _exercise('Bench Press', '4 sets · 8 reps', 'Press with intent'),
          _exercise('Shoulder Press', '3 sets · 10 reps', 'Lock in your ribs'),
          _exercise('Cable Fly', '3 sets · 12 reps', 'Own the stretch'),
          _exercise('Tricep Pushdown', '3 sets · 12 reps', 'Finish fully'),
        ],
      ),
      _trainingDay(
        title: 'Pull Day',
        description: 'Back, rear delts, and biceps.',
        minutes: 45,
        calories: 305,
        exercises: [
          _exercise('Lat Pulldown', '4 sets · 10 reps', 'Drive elbows down'),
          _exercise('One-Arm Row', '3 sets · 10 each side', 'Pull to the hip'),
          _exercise('Face Pull', '3 sets · 15 reps', 'Hands high'),
          _exercise('EZ-Bar Curl', '3 sets · 12 reps', 'Control the eccentric'),
        ],
      ),
      _trainingDay(
        title: 'Leg Day',
        description: 'Heavy lower body and core.',
        minutes: 52,
        calories: 370,
        exercises: [
          _exercise('Squat', '4 sets · 6-8 reps', 'Brace before every rep'),
          _exercise('Romanian Deadlift', '3 sets · 8 reps', 'Hinge cleanly'),
          _exercise('Leg Curl', '3 sets · 12 reps', 'Squeeze hamstrings'),
          _exercise('Weighted Plank', '3 sets · 30 sec', 'Stay rigid'),
        ],
      ),
      _restDay('Mobility + Steps'),
      _trainingDay(
        title: profile.fitnessGoal == 'Improve Stamina'
            ? 'Athletic Conditioning'
            : 'Upper Pump + Accessories',
        description: 'Support work to improve capacity and consistency.',
        minutes: 36,
        calories: 300,
        exercises: [
          _exercise('Landmine Press', '3 sets · 10 reps', 'Press on an arc'),
          _exercise('Cable Row', '3 sets · 12 reps', 'Squeeze shoulder blades'),
          _exercise('Walking Lunge', '3 sets · 12 each side', 'Control each step'),
          _exercise('Bike / Row Erg', '8 rounds · 30 sec hard', 'Recover fully between'),
        ],
      ),
      _trainingDay(
        title: 'Core + Recovery Strength',
        description: 'Lighter full-body work to round out the week.',
        minutes: 32,
        calories: 240,
        exercises: [
          _exercise('Goblet Squat', '3 sets · 12 reps', 'Smooth tempo'),
          _exercise('Incline Push-Up', '3 sets · 12 reps', 'Stay long'),
          _exercise('Band Pull-Apart', '3 sets · 20 reps', 'Open the chest'),
          _exercise('Dead Bug', '3 sets · 12 reps', 'Exhale fully'),
        ],
      ),
      _restDay('Full Recovery'),
    ];
  }

  static WorkoutDayPlan _trainingDay({
    required String title,
    required String description,
    required int minutes,
    required int calories,
    required List<WorkoutExercise> exercises,
  }) {
    return WorkoutDayPlan(
      title: title,
      description: description,
      durationMinutes: minutes,
      estimatedCalories: calories,
      isRestDay: false,
      exercises: exercises,
    );
  }

  static WorkoutDayPlan _restDay(String title) {
    return WorkoutDayPlan(
      title: title,
      description: 'Light movement, stretching, and recovery.',
      durationMinutes: 20,
      estimatedCalories: 90,
      isRestDay: true,
      exercises: const [
        WorkoutExercise(
          name: 'Mobility Flow',
          prescription: '10 minutes',
          cue: 'Move gently and breathe',
        ),
      ],
    );
  }

  static WorkoutExercise _exercise(
    String name,
    String prescription,
    String cue,
  ) {
    return WorkoutExercise(
      name: name,
      prescription: prescription,
      cue: cue,
    );
  }
}
