import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/workout_plan.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_theme.dart';

class WorkoutSessionResult {
  final bool completedWorkout;
  final bool newlyCompleted;
  final int streak;
  final DateTime completedDate;

  const WorkoutSessionResult({
    required this.completedWorkout,
    required this.newlyCompleted,
    required this.streak,
    required this.completedDate,
  });
}

class WorkoutSessionScreen extends StatefulWidget {
  final WorkoutDayPlan plan;
  final int initialExerciseIndex;
  final DateTime sessionDate;
  final bool trackCompletion;

  const WorkoutSessionScreen({
    super.key,
    required this.plan,
    this.initialExerciseIndex = 0,
    required this.sessionDate,
    this.trackCompletion = false,
  });

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  Timer? _timer;
  int _exerciseIndex = 0;
  int _exerciseCycle = 1;
  int _elapsedSeconds = 0;
  int? _countdownSeconds;
  int? _restSecondsRemaining;
  int _restTotalSeconds = 0;
  int? _nextExerciseIndexAfterRest;
  bool _isRunning = true;
  bool _completingWorkout = false;

  WorkoutExercise get _currentExercise => widget.plan.exercises[_exerciseIndex];
  WorkoutExercise get _upcomingExercise =>
      widget.plan.exercises[_nextExerciseIndexAfterRest!];
  WorkoutExercise get _displayExercise =>
      _isResting ? _upcomingExercise : _currentExercise;
  int get _totalCycles => _currentExercise.cycleCount.clamp(1, 99).toInt();
  String get _cycleLabel => _currentExercise.cycleLabel;
  bool get _isCountdownMode => _countdownSeconds != null;
  bool get _hasMoreCyclesInExercise => _exerciseCycle < _totalCycles;
  bool get _isResting =>
      _nextExerciseIndexAfterRest != null && _restSecondsRemaining != null;

  @override
  void initState() {
    super.initState();
    if (widget.plan.exercises.isNotEmpty) {
      _exerciseIndex = widget.initialExerciseIndex.clamp(
        0,
        widget.plan.exercises.length - 1,
      );
    }
    _configureCurrentExercise(resetElapsed: true, resetCycle: true);
  }

  void _configureCurrentExercise({
    required bool resetElapsed,
    bool resetCycle = false,
  }) {
    _timer?.cancel();

    if (resetElapsed) {
      _elapsedSeconds = 0;
    }
    if (resetCycle) {
      _exerciseCycle = 1;
    }

    _restSecondsRemaining = null;
    _restTotalSeconds = 0;
    _nextExerciseIndexAfterRest = null;
    _countdownSeconds =
        _currentExercise.targetDurationSeconds ??
        _extractCountdownSeconds(_currentExercise.prescription);
    _isRunning = true;

    _startTicker();
  }

  void _startTicker() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isRunning) return;

      if (_isResting) {
        setState(() {
          if ((_restSecondsRemaining ?? 0) > 0) {
            _restSecondsRemaining = (_restSecondsRemaining ?? 0) - 1;
          }
        });

        if (_restSecondsRemaining == 0) {
          _advanceAfterRest();
        }
        return;
      }

      setState(() {
        if (_isCountdownMode) {
          if (_countdownSeconds! > 0) {
            _countdownSeconds = _countdownSeconds! - 1;
          }
        } else {
          _elapsedSeconds++;
        }
      });

      if (_isCountdownMode && _countdownSeconds == 0) {
        _handleCountdownFinished();
      }
    });
  }

  int? _extractCountdownSeconds(String prescription) {
    final normalized = prescription.toLowerCase();
    final timedMatches = RegExp(
      r'(\d+)(?:\s*-\s*(\d+))?\s*(sec|min)',
    ).allMatches(normalized).toList(growable: false);
    if (timedMatches.isEmpty) return null;
    final timedMatch = timedMatches.last;

    final start = int.tryParse(timedMatch.group(1) ?? '');
    if (start == null) return null;
    final end = int.tryParse(timedMatch.group(2) ?? '');
    final unit = timedMatch.group(3) ?? 'sec';
    final value = end == null ? start : ((start + end) / 2).round();

    if (unit == 'sec') return value;
    if (unit == 'min') return value * 60;
    return null;
  }

  String _formatClock(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _handleCountdownFinished() async {
    if (_completingWorkout) return;
    _isRunning = false;
    _timer?.cancel();
    await SystemSound.play(SystemSoundType.alert);
    if (!mounted) return;

    if (_hasMoreCyclesInExercise) {
      setState(() {
        _exerciseCycle++;
        _countdownSeconds =
            _currentExercise.targetDurationSeconds ??
            _extractCountdownSeconds(_currentExercise.prescription);
        _elapsedSeconds = 0;
        _isRunning = true;
      });
      _startTicker();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${_cycleLabel.toUpperCase()} $_exerciseCycle of $_totalCycles started.',
            ),
            duration: const Duration(milliseconds: 1400),
          ),
        );
      return;
    }

    if (_exerciseIndex >= widget.plan.exercises.length - 1) {
      await _completeWorkout();
      return;
    }

    _beginRestBeforeNextExercise();
  }

  void _togglePlayback() {
    if (_completingWorkout) return;
    setState(() => _isRunning = !_isRunning);
  }

  void _goNext() {
    if (_completingWorkout) return;

    if (_isResting) {
      _advanceAfterRest();
      return;
    }

    if (_hasMoreCyclesInExercise) {
      setState(() => _exerciseCycle++);
      _configureCurrentExercise(resetElapsed: true);
      return;
    }

    if (_exerciseIndex >= widget.plan.exercises.length - 1) {
      unawaited(_completeWorkout());
      return;
    }

    _beginRestBeforeNextExercise();
  }

  void _goPrevious() {
    if (_isResting) return;

    if (_exerciseCycle > 1) {
      setState(() => _exerciseCycle--);
      _configureCurrentExercise(resetElapsed: true);
      return;
    }

    if (_exerciseIndex == 0) return;

    setState(() {
      _exerciseIndex--;
      _exerciseCycle = widget.plan.exercises[_exerciseIndex].cycleCount
          .clamp(1, 99)
          .toInt();
    });
    _configureCurrentExercise(resetElapsed: true);
  }

  int _recommendedRestSeconds(WorkoutExercise exercise) {
    final movementPattern = exercise.movementPattern.toLowerCase();

    if (widget.plan.isRestDay || movementPattern.contains('recovery')) {
      return 20;
    }
    if (movementPattern.contains('conditioning')) {
      return 25;
    }
    if (movementPattern.contains('carry') ||
        movementPattern.contains('hinge')) {
      return 50;
    }
    switch (exercise.difficulty) {
      case 'Advanced':
        return 60;
      case 'Intermediate':
        return 45;
      default:
        return 30;
    }
  }

  void _beginRestBeforeNextExercise() {
    if (_exerciseIndex >= widget.plan.exercises.length - 1) {
      unawaited(_completeWorkout());
      return;
    }

    final nextExerciseIndex = _exerciseIndex + 1;
    final restSeconds = _recommendedRestSeconds(_currentExercise);
    if (restSeconds <= 0) {
      setState(() => _exerciseIndex = nextExerciseIndex);
      _configureCurrentExercise(resetElapsed: true, resetCycle: true);
      return;
    }

    _timer?.cancel();
    setState(() {
      _nextExerciseIndexAfterRest = nextExerciseIndex;
      _restTotalSeconds = restSeconds;
      _restSecondsRemaining = restSeconds;
      _countdownSeconds = null;
      _elapsedSeconds = 0;
      _isRunning = true;
    });
    _startTicker();

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Take $restSeconds seconds to reset before ${widget.plan.exercises[nextExerciseIndex].name}.',
          ),
          duration: const Duration(milliseconds: 1800),
        ),
      );
  }

  void _advanceAfterRest() {
    final nextExerciseIndex = _nextExerciseIndexAfterRest;
    if (nextExerciseIndex == null) {
      return;
    }

    setState(() => _exerciseIndex = nextExerciseIndex);
    _configureCurrentExercise(resetElapsed: true, resetCycle: true);
  }

  Future<void> _completeWorkout() async {
    if (_completingWorkout) {
      return;
    }

    _completingWorkout = true;
    _isRunning = false;
    _timer?.cancel();

    if (widget.trackCompletion) {
      final newlyCompleted = await context
          .read<UserProvider>()
          .markWorkoutCompleted(widget.sessionDate);
      if (!mounted) {
        return;
      }

      final streak = context.read<UserProvider>().userProfile?.streak ?? 0;
      Navigator.of(context).pop(
        WorkoutSessionResult(
          completedWorkout: true,
          newlyCompleted: newlyCompleted,
          streak: streak,
          completedDate: widget.sessionDate,
        ),
      );
      return;
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  List<String> _exerciseGuideSteps(WorkoutExercise exercise) {
    if (exercise.cue.isEmpty) {
      return ['Move with control, steady breathing, and a strong brace.'];
    }

    final parts = exercise.cue
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    return parts.isNotEmpty
        ? parts.take(3).toList(growable: false)
        : [exercise.cue];
  }

  List<String> _restGuideSteps() {
    return <String>[
      'Let your breathing settle and shake tension out of your arms and legs.',
      'Up next: ${_upcomingExercise.name} for ${_upcomingExercise.prescription}.',
      _upcomingExercise.cue.isNotEmpty
          ? _upcomingExercise.cue
          : 'Tap skip rest as soon as you feel ready to move again.',
    ];
  }

  String _focusHint(WorkoutExercise exercise) {
    if (_isResting) {
      return 'Recovery keeps your form cleaner and your next effort stronger.';
    }

    final pattern = exercise.movementPattern.toLowerCase();
    if (pattern.contains('push')) {
      return 'Focus on shoulder stability and a strong, even press.';
    }
    if (pattern.contains('pull')) {
      return 'Keep your chest lifted and pull with your back, not just your arms.';
    }
    if (pattern.contains('core') || pattern.contains('carry')) {
      return 'Brace your midsection and breathe steadily through the movement.';
    }
    if (pattern.contains('condition')) {
      return 'Maintain a controlled pace with consistent breathing.';
    }
    return 'Move with control, steady breathing, and a strong brace.';
  }

  double _sessionProgress() {
    final totalCycles = widget.plan.exercises.fold<int>(
      0,
      (sum, exercise) => sum + exercise.cycleCount.clamp(1, 99).toInt(),
    );
    if (totalCycles == 0) {
      return 0.0;
    }

    final completedCyclesBeforeCurrent = widget.plan.exercises
        .take(_exerciseIndex)
        .fold<int>(
          0,
          (sum, exercise) => sum + exercise.cycleCount.clamp(1, 99).toInt(),
        );
    final completed =
        completedCyclesBeforeCurrent +
        (_isResting ? _totalCycles : (_exerciseCycle - 1));
    final inFlight = _isResting ? 0 : 1;
    return ((completed + inFlight) / totalCycles).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLastExercise = _exerciseIndex == widget.plan.exercises.length - 1;
    final displayExercise = _displayExercise;
    final displayTime = _isResting
        ? _restSecondsRemaining ?? 0
        : (_isCountdownMode ? _countdownSeconds ?? 0 : _elapsedSeconds);
    final timerLabel = _isResting
        ? 'REST LEFT'
        : (_isCountdownMode ? 'TIME LEFT' : 'ELAPSED');
    final sessionProgress = _sessionProgress();
    final cycleTitle = _isResting
        ? 'EX ${(_nextExerciseIndexAfterRest ?? _exerciseIndex) + 1}/${widget.plan.exercises.length}'
        : '${_cycleLabel.toUpperCase()} $_exerciseCycle/$_totalCycles';
    final canAdvanceWithinExercise = !_isResting && _hasMoreCyclesInExercise;
    final nextButtonLabel = _isResting
        ? 'Skip Rest'
        : canAdvanceWithinExercise
        ? 'Next $_cycleLabel'
        : (isLastExercise ? 'Finish' : 'Next Exercise');
    final targetLabel = displayExercise.primaryMuscles.isNotEmpty
        ? displayExercise.primaryMuscles.first
        : 'Full Body';
    final guideSteps = _isResting
        ? _restGuideSteps()
        : _exerciseGuideSteps(displayExercise);
    final heroFrames = displayExercise.animationFrames;
    final hasHeroImage = heroFrames.isNotEmpty;
    final topLabel = _isResting ? 'RECOVERY WINDOW' : 'CURRENT EXERCISE';
    final headline = _isResting ? 'Rest & Reset' : displayExercise.name;
    final subHeadline = _isResting ? displayExercise.name : null;
    final hintText = _focusHint(displayExercise);
    final guideTitle = _isResting ? 'UP NEXT GUIDE' : 'EXECUTION GUIDE';
    final restPreview = _isResting
        ? 'Skip early if you are ready for the next exercise.'
        : 'Rest after this exercise: ${_recommendedRestSeconds(_currentExercise)} sec';

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0B111A)
          : const Color(0xFFF5F0E6),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _RoundIconButton(
                          icon: Icons.close,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.plan.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: colorScheme.onSurface,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isResting
                                    ? 'Recover before exercise ${(_nextExerciseIndexAfterRest ?? _exerciseIndex) + 1} of ${widget.plan.exercises.length}'
                                    : 'Exercise ${_exerciseIndex + 1} of ${widget.plan.exercises.length}',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      topLabel,
                      style: TextStyle(
                        color: AppTheme.secondaryContainer.withValues(
                          alpha: 0.92,
                        ),
                        fontSize: 11,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      headline,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.02,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (subHeadline != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        subHeadline,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.72,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            _isResting ? 'UP NEXT:' : 'TARGET:',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 11,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            targetLabel,
                            style: TextStyle(
                              color: AppTheme.tertiary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Stack(
                        children: [
                          Container(
                            height: 300,
                            color: isDark
                                ? const Color(0xFF111720)
                                : const Color(0xFFE9E4DF),
                          ),
                          if (hasHeroImage)
                            Positioned.fill(
                              child: _HeroImage(
                                frameAssets: heroFrames,
                                source: displayExercise.animationFramesSource,
                              ),
                            ),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.16),
                                    Colors.black.withValues(alpha: 0.70),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _WorkoutStatCard(
                            label: timerLabel,
                            value: _formatClock(displayTime),
                            subtitle: _isResting
                                ? '${_restTotalSeconds}s reset window'
                                : displayExercise.prescription,
                            color: _isResting
                                ? AppTheme.secondaryContainer
                                : AppTheme.primaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _WorkoutStatCard(
                            label: _isResting ? 'UP NEXT' : 'WORK BLOCK',
                            value: cycleTitle,
                            subtitle: _isResting
                                ? '${displayExercise.name} · ${(sessionProgress * 100).round()}%'
                                : 'Exercise ${_exerciseIndex + 1}/${widget.plan.exercises.length} · ${(sessionProgress * 100).round()}%',
                            color: AppTheme.tertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh.withValues(
                          alpha: 0.72,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isResting
                                ? Icons.hotel_rounded
                                : Icons.timer_outlined,
                            color: _isResting
                                ? AppTheme.secondaryContainer
                                : AppTheme.primaryContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              restPreview,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh.withValues(
                          alpha: 0.80,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppTheme.primaryContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              hintText,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      guideTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurface,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Column(
                      children: guideSteps.asMap().entries.map((entry) {
                        final index = entry.key + 1;
                        final step = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryContainer.withValues(
                                    alpha: 0.14,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Center(
                                  child: Text(
                                    '$index',
                                    style: const TextStyle(
                                      color: AppTheme.primaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  step,
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    height: 1.55,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 110),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
          child: Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Back',
                  icon: Icons.skip_previous,
                  background: colorScheme.surfaceContainerHigh,
                  foreground: colorScheme.onSurface,
                  onPressed:
                      (_exerciseIndex == 0 || _isResting || _completingWorkout)
                      ? null
                      : _goPrevious,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  label: _isRunning ? 'Pause' : 'Resume',
                  icon: _isRunning ? Icons.pause : Icons.play_arrow,
                  background: AppTheme.primaryContainer,
                  foreground: Colors.white,
                  onPressed: _completingWorkout ? null : _togglePlayback,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  label: nextButtonLabel,
                  icon: _isResting
                      ? Icons.fast_forward_rounded
                      : canAdvanceWithinExercise
                      ? Icons.navigate_next
                      : (isLastExercise ? Icons.check : Icons.skip_next),
                  background: colorScheme.surfaceContainerHigh,
                  foreground: colorScheme.onSurface,
                  onPressed: _completingWorkout ? null : _goNext,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  final List<String> frameAssets;
  final String source;

  const _HeroImage({required this.frameAssets, required this.source});

  @override
  Widget build(BuildContext context) {
    if (frameAssets.length >= 2) {
      return _ExerciseFrameLoop(frameAssets: frameAssets, source: source);
    }

    if (frameAssets.isEmpty) {
      return const SizedBox.shrink();
    }

    return source == 'file'
        ? Image.file(
            File(frameAssets.first),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          )
        : Image.asset(
            frameAssets.first,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          );
  }
}

class _WorkoutStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final Color color;

  const _WorkoutStatCard({
    required this.label,
    required this.value,
    this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    maxLines: 1,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseFrameLoop extends StatefulWidget {
  final List<String> frameAssets;
  final String source;

  const _ExerciseFrameLoop({required this.frameAssets, required this.source});

  @override
  State<_ExerciseFrameLoop> createState() => _ExerciseFrameLoopState();
}

class _ExerciseFrameLoopState extends State<_ExerciseFrameLoop> {
  Timer? _frameTimer;
  int _frameIndex = 0;

  @override
  void initState() {
    super.initState();
    _frameTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (!mounted || widget.frameAssets.length < 2) {
        return;
      }
      setState(() {
        _frameIndex = (_frameIndex + 1) % widget.frameAssets.length;
      });
    });
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: widget.source == 'file'
          ? Image.file(
              File(widget.frameAssets[_frameIndex]),
              key: ValueKey<String>(widget.frameAssets[_frameIndex]),
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) =>
                  const _ExercisePreviewFallbackContent(),
            )
          : Image.asset(
              widget.frameAssets[_frameIndex],
              key: ValueKey<String>(widget.frameAssets[_frameIndex]),
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) =>
                  const _ExercisePreviewFallbackContent(),
            ),
    );
  }
}

class _ExercisePreviewFallbackContent extends StatelessWidget {
  const _ExercisePreviewFallbackContent();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
            colorScheme.surfaceContainerLow.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                size: 40,
                color: AppTheme.primaryContainer,
              ),
              const SizedBox(height: 12),
              Text(
                'Preview Unavailable',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'The exercise reference image is still being prepared.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _RoundIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: IconButton(onPressed: onPressed, icon: Icon(icon)),
    );
  }
}
