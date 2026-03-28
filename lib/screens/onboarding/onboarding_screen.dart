import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dark_mode_toggle.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  late final FixedExtentScrollController _ageController;
  late final FixedExtentScrollController _heightController;
  late final FixedExtentScrollController _weightController;

  int _currentIndex = 0;
  bool _isSaving = false;

  String? _gender;
  int _age = 25;
  double _height = 170;
  double _weight = 70;
  String? _occupation;
  String? _sittingHours;
  String? _fitnessGoal;
  int? _workoutDays;
  String? _trainingLevel;
  String? _workoutLocation;
  String? _availableEquipment;
  int? _sessionDurationMinutes;
  String? _targetMuscleFocus;
  String? _jointSensitivity;

  static const int _totalQuestions = 15;

  @override
  void initState() {
    super.initState();
    _ageController = FixedExtentScrollController(initialItem: _age - 15);
    _heightController = FixedExtentScrollController(
      initialItem: _height.toInt() - 120,
    );
    _weightController = FixedExtentScrollController(
      initialItem: _weight.toInt() - 30,
    );
  }

  void _nextPage() {
    if (_currentIndex < _totalQuestions - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _prevPage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  Future<void> _completeOnboarding() async {
    final authUser = context.read<AuthProvider>().user;
    if (authUser == null ||
        _nameController.text.trim().isEmpty ||
        _gender == null ||
        _occupation == null ||
        _sittingHours == null ||
        _fitnessGoal == null ||
        _workoutDays == null) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      await context.read<UserProvider>().saveOnboardingAnswers(
            user: authUser,
            name: _nameController.text.trim(),
            gender: _gender!,
            age: _age,
            weight: _weight,
            occupation: _occupation!,
            sittingHours: _sittingHours!,
            fitnessGoal: _fitnessGoal!,
            workoutDays: _workoutDays!,
            height: _height,
            trainingLevel: _trainingLevel ?? 'Beginner',
            workoutLocation: _workoutLocation ?? 'Home',
            availableEquipment: _availableEquipment ?? 'Bodyweight',
            sessionDurationMinutes: _sessionDurationMinutes ?? 30,
            targetMuscleFocus: _targetMuscleFocus ?? 'Full Body',
            jointSensitivity: _jointSensitivity ?? 'None',
          );

      if (!mounted) return;
      context.go('/generating');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save your setup: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = (_currentIndex + 1) / _totalQuestions;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
                    onPressed: _isSaving ? null : _prevPage,
                  ),
                  Text(
                    'STEP ${_currentIndex + 1} OF $_totalQuestions',
                    style: const TextStyle(
                      color: AppTheme.primaryContainer,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const DarkModeToggle(),
                ],
              ),
            ),
            Container(
              height: 3,
              width: double.infinity,
              color: colorScheme.surfaceContainerHigh,
              child: Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOut,
                    width: MediaQuery.of(context).size.width * progress,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryContainer.withOpacity(0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                  },
                  children: [
                    _buildNameQuestion(context),
                    _buildChoiceQuestion(
                      context,
                      title: 'What is your biological sex?',
                      subtitle:
                          'This helps us tune your starter plan and calorie guidance.',
                      selectedValue: _gender,
                      options: const [
                        _ChoiceOption('Male', '♂'),
                        _ChoiceOption('Female', '♀'),
                        _ChoiceOption('Other', '⚧'),
                      ],
                      onSelected: (value) => setState(() => _gender = value),
                    ),
                    _buildAgeQuestion(context),
                    _buildMetricWheelQuestion(
                      context,
                      title: 'What is your height?',
                      subtitle:
                          'Height helps us calculate BMR, calories, and a more accurate diet plan.',
                      value: _height.toInt(),
                      unit: 'cm',
                      min: 120,
                      max: 230,
                      controller: _heightController,
                      onChanged: (value) => setState(() => _height = value.toDouble()),
                    ),
                    _buildMetricWheelQuestion(
                      context,
                      title: 'What is your weight?',
                      subtitle:
                          'Weight helps us personalize calorie targets, protein intake, and progress guidance.',
                      value: _weight.toInt(),
                      unit: 'kg',
                      min: 30,
                      max: 200,
                      controller: _weightController,
                      onChanged: (value) => setState(() => _weight = value.toDouble()),
                    ),
                    _buildChoiceQuestion(
                      context,
                      title: 'What describes your daily occupation?',
                      subtitle:
                          'We use this to estimate how active you already are during the day.',
                      selectedValue: _occupation,
                      options: const [
                        _ChoiceOption(
                          'Desk Job',
                          '💼',
                          subtitle: 'Mostly seated, 6-9 hours a day',
                        ),
                        _ChoiceOption(
                          'Physical Labor',
                          '🏗',
                          subtitle: 'On your feet most of the day',
                        ),
                        _ChoiceOption(
                          'Mixed',
                          '🔀',
                          subtitle: 'A mix of sitting and active work',
                        ),
                        _ChoiceOption(
                          'Student',
                          '🎓',
                          subtitle: 'Variable activity through the week',
                        ),
                      ],
                      onSelected: (value) => setState(() => _occupation = value),
                    ),
                    _buildChoiceQuestion(
                      context,
                      title: 'How many hours do you sit per day?',
                      subtitle:
                          'This helps us add mobility and posture-friendly work where needed.',
                      selectedValue: _sittingHours,
                      options: const [
                        _ChoiceOption('1-2 Hours', '🪑'),
                        _ChoiceOption('3-5 Hours', '🪑'),
                        _ChoiceOption('6-8 Hours', '🪑'),
                        _ChoiceOption('8+ Hours', '🪑'),
                      ],
                      onSelected: (value) => setState(() => _sittingHours = value),
                    ),
                    _buildChoiceQuestion(
                      context,
                      title: 'What is your primary goal?',
                      subtitle:
                          'Your goal changes the exercise mix, pacing, and weekly split.',
                      selectedValue: _fitnessGoal,
                      options: const [
                        _ChoiceOption('Lose Weight', '🔥'),
                        _ChoiceOption('Gain Muscle', '💪'),
                        _ChoiceOption('Improve Stamina', '🏃'),
                        _ChoiceOption('Stay Active', '🧘'),
                      ],
                      onSelected: (value) => setState(() => _fitnessGoal = value),
                    ),
                    _buildChoiceQuestion(
                      context,
                      title: 'What is your current training level?',
                      subtitle:
                          'This lets us choose safer exercise variations and realistic weekly intensity.',
                      selectedValue: _trainingLevel,
                      options: const [
                        _ChoiceOption(
                          'Beginner',
                          '🌱',
                          subtitle: 'New to structured workouts or returning after a break',
                        ),
                        _ChoiceOption(
                          'Intermediate',
                          '⚡',
                          subtitle: 'Comfortable with regular workouts and basic form',
                        ),
                        _ChoiceOption(
                          'Advanced',
                          '🔥',
                          subtitle: 'Experienced with higher volume and harder variations',
                        ),
                      ],
                      onSelected: (value) => setState(() => _trainingLevel = value),
                    ),
                    _buildChoiceQuestion(
                      context,
                      title: 'Where do you mostly work out?',
                      subtitle:
                          'Your workout location changes the kind of exercises we can suggest.',
                      selectedValue: _workoutLocation,
                      options: const [
                        _ChoiceOption('Home', '🏠'),
                        _ChoiceOption('Gym', '🏋'),
                        _ChoiceOption('Hybrid', '🔁'),
                      ],
                      onSelected: (value) => setState(() => _workoutLocation = value),
                    ),
                    _buildChoiceQuestion(
                      context,
                      title: 'What equipment do you usually have?',
                      subtitle:
                          'We use this to avoid suggesting exercises you cannot actually perform.',
                      selectedValue: _availableEquipment,
                      options: const [
                        _ChoiceOption(
                          'Bodyweight',
                          '🤸',
                          subtitle: 'No equipment or only a mat/chair',
                        ),
                        _ChoiceOption(
                          'Bands & Dumbbells',
                          '🟦',
                          subtitle: 'Resistance bands or a light dumbbell setup',
                        ),
                        _ChoiceOption(
                          'Full Gym',
                          '🏟',
                          subtitle: 'Machines, barbells, benches, and cables',
                        ),
                      ],
                      onSelected: (value) =>
                          setState(() => _availableEquipment = value),
                    ),
                    _buildChoiceQuestion(
                      context,
                      title: 'How long should most sessions be?',
                      subtitle:
                          'We match the workout density to the time you can realistically give.',
                      selectedValue: _sessionDurationMinutes == null
                          ? null
                          : '${_sessionDurationMinutes!} min',
                      options: const [
                        _ChoiceOption('20 min', '⏱'),
                        _ChoiceOption('30 min', '⌚'),
                        _ChoiceOption('45 min', '🕒'),
                        _ChoiceOption('60 min', '🧭'),
                      ],
                      onSelected: (value) => setState(
                        () => _sessionDurationMinutes =
                            int.tryParse(value.split(' ').first) ?? 30,
                      ),
                    ),
                    _buildChoiceQuestion(
                      context,
                      title: 'Which area do you want to emphasize most?',
                      subtitle:
                          'This gives your weekly plan a visible personal focus without ignoring balance.',
                      selectedValue: _targetMuscleFocus,
                      options: const [
                        _ChoiceOption('Full Body', '🧍'),
                        _ChoiceOption('Upper Body', '💪'),
                        _ChoiceOption('Lower Body', '🦵'),
                        _ChoiceOption('Core', '⚙'),
                        _ChoiceOption('Back & Posture', '🧠'),
                      ],
                      onSelected: (value) =>
                          setState(() => _targetMuscleFocus = value),
                    ),
                    _buildChoiceQuestion(
                      context,
                      title: 'Any joints or areas we should be extra careful with?',
                      subtitle:
                          'We use this to reduce risky movements and add more friendly alternatives.',
                      selectedValue: _jointSensitivity,
                      options: const [
                        _ChoiceOption('None', '✅'),
                        _ChoiceOption('Knees', '🦵'),
                        _ChoiceOption('Lower Back', '🩻'),
                        _ChoiceOption('Shoulders', '🫳'),
                      ],
                      onSelected: (value) =>
                          setState(() => _jointSensitivity = value),
                    ),
                    _buildWorkoutDaysQuestion(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionScaffold({
    required BuildContext context,
    required String title,
    required String subtitle,
    required Widget body,
    required bool canContinue,
    String buttonLabel = 'Next →',
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primaryContainer.withOpacity(0.2),
            borderRadius: BorderRadius.circular(50),
          ),
          child: Text(
            'Q${_currentIndex + 1} OF $_totalQuestions',
            style: const TextStyle(
              color: AppTheme.primaryContainer,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),
        Expanded(child: body),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: canContinue && !_isSaving ? _nextPage : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryContainer,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            child: _isSaving && _currentIndex == _totalQuestions - 1
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    buttonLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildNameQuestion(BuildContext context) {
    return _buildQuestionScaffold(
      context: context,
      title: 'What should we call you?',
      subtitle:
          'Your name helps us personalize the workout dashboard and profile.',
      canContinue: _nameController.text.trim().isNotEmpty,
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
            ),
            child: TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Enter your name',
                prefixIcon: Icon(Icons.person_outline),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'We will show this on the workout page, greetings, and progress areas.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgeQuestion(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _buildQuestionScaffold(
      context: context,
      title: 'How old are you?',
      subtitle:
          'Age helps us keep your routine realistic and recovery-friendly.',
      canContinue: true,
      body: Center(
        child: SizedBox(
          height: 260,
          width: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 60,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryContainer.withOpacity(0.4),
                    width: 2,
                  ),
                ),
              ),
              ListWheelScrollView.useDelegate(
                controller: _ageController,
                itemExtent: 60,
                physics: const FixedExtentScrollPhysics(),
                perspective: 0.005,
                onSelectedItemChanged: (index) {
                  setState(() => _age = 15 + index);
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: 66,
                  builder: (context, index) {
                    final age = 15 + index;
                    final isSelected = age == _age;
                    return Center(
                      child: Text(
                        '$age',
                        style: TextStyle(
                          fontSize: isSelected ? 36 : 28,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? colorScheme.onSurface
                              : colorScheme.onSurfaceVariant.withOpacity(0.5),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricWheelQuestion(
    BuildContext context, {
    required String title,
    required String subtitle,
    required int value,
    required String unit,
    required int min,
    required int max,
    required FixedExtentScrollController controller,
    required ValueChanged<int> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return _buildQuestionScaffold(
      context: context,
      title: title,
      subtitle: subtitle,
      canContinue: true,
      body: Center(
        child: SizedBox(
          height: 280,
          width: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 64,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppTheme.primaryContainer.withOpacity(0.4),
                    width: 2,
                  ),
                ),
              ),
              ListWheelScrollView.useDelegate(
                controller: controller,
                itemExtent: 60,
                physics: const FixedExtentScrollPhysics(),
                perspective: 0.005,
                onSelectedItemChanged: (index) => onChanged(min + index),
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: max - min + 1,
                  builder: (context, index) {
                    final current = min + index;
                    final isSelected = current == value;
                    return Center(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$current',
                              style: TextStyle(
                                fontSize: isSelected ? 34 : 26,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurfaceVariant.withOpacity(0.5),
                              ),
                            ),
                            TextSpan(
                              text: ' $unit',
                              style: TextStyle(
                                fontSize: isSelected ? 16 : 14,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? AppTheme.primaryContainer
                                    : colorScheme.onSurfaceVariant.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkoutDaysQuestion(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _buildQuestionScaffold(
      context: context,
      title: 'How many days per week can you work out?',
      subtitle:
          'We use this to choose a split you can actually stick with.',
      canContinue: _workoutDays != null,
      buttonLabel: 'Build My Plan',
      body: Wrap(
        spacing: 12,
        runSpacing: 16,
        children: List.generate(7, (index) {
          final days = index + 1;
          final isSelected = _workoutDays == days;
          return GestureDetector(
            onTap: () => setState(() => _workoutDays = days),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryContainer
                    : colorScheme.surfaceContainerLow,
                shape: BoxShape.circle,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryContainer.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : [],
              ),
              child: Center(
                child: Text(
                  '$days',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildChoiceQuestion(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String? selectedValue,
    required List<_ChoiceOption> options,
    required ValueChanged<String> onSelected,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return _buildQuestionScaffold(
      context: context,
      title: title,
      subtitle: subtitle,
      canContinue: selectedValue != null,
      body: ListView.separated(
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final option = options[index];
          final isSelected = selectedValue == option.title;

          return GestureDetector(
            onTap: () => onSelected(option.title),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryContainer.withOpacity(0.06)
                    : colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border(
                  left: BorderSide(
                    color:
                        isSelected ? AppTheme.primaryContainer : Colors.transparent,
                    width: 4,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(option.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        if (option.subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            option.subtitle!,
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryContainer
                            : colorScheme.outline,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? Center(
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChoiceOption {
  final String title;
  final String emoji;
  final String? subtitle;

  const _ChoiceOption(this.title, this.emoji, {this.subtitle});
}
