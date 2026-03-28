import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import '../../models/workout_plan.dart';
import '../../theme/app_theme.dart';

class WorkoutSessionScreen extends StatefulWidget {
  final WorkoutDayPlan plan;

  const WorkoutSessionScreen({
    super.key,
    required this.plan,
  });

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  Timer? _timer;
  int _exerciseIndex = 0;
  int _elapsedSeconds = 0;
  int? _countdownSeconds;
  bool _isRunning = true;
  bool _showingPrompt = false;

  WorkoutExercise get _currentExercise => widget.plan.exercises[_exerciseIndex];

  bool get _isCountdownMode => _countdownSeconds != null;

  @override
  void initState() {
    super.initState();
    _configureCurrentExercise(resetElapsed: true);
  }

  void _configureCurrentExercise({required bool resetElapsed}) {
    _timer?.cancel();

    if (resetElapsed) {
      _elapsedSeconds = 0;
    }

    _countdownSeconds = _extractCountdownSeconds(_currentExercise.prescription);
    _isRunning = true;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isRunning) return;

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
    final numberMatch = RegExp(r'(\d+)').firstMatch(normalized);
    if (numberMatch == null) return null;
    final value = int.tryParse(numberMatch.group(1) ?? '');
    if (value == null) return null;

    if (normalized.contains('sec')) return value;
    if (normalized.contains('min')) return value * 60;
    return null;
  }

  String _formatClock(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _handleCountdownFinished() async {
    if (_showingPrompt) return;
    _showingPrompt = true;
    _isRunning = false;
    await SystemSound.play(SystemSoundType.alert);
    if (!mounted) return;

    final shouldAdvance =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHigh,
              title: const Text('Time Complete'),
              content: Text(
                _exerciseIndex == widget.plan.exercises.length - 1
                    ? 'You completed the last timed exercise. Finish the workout?'
                    : 'Ready to move to the next exercise?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Stay Here'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    _exerciseIndex == widget.plan.exercises.length - 1
                        ? 'Finish'
                        : 'Next Exercise',
                  ),
                ),
              ],
            );
          },
        ) ??
        false;

    _showingPrompt = false;

    if (!mounted) return;

    if (shouldAdvance) {
      _goNext();
      return;
    }

    setState(() {
      _countdownSeconds = _extractCountdownSeconds(_currentExercise.prescription);
      _isRunning = false;
    });
  }

  void _togglePlayback() {
    setState(() => _isRunning = !_isRunning);
  }

  void _goNext() {
    if (_exerciseIndex >= widget.plan.exercises.length - 1) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _exerciseIndex++);
    _configureCurrentExercise(resetElapsed: true);
  }

  void _goPrevious() {
    if (_exerciseIndex == 0) return;

    setState(() => _exerciseIndex--);
    _configureCurrentExercise(resetElapsed: true);
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
    final displayTime = _isCountdownMode ? _countdownSeconds ?? 0 : _elapsedSeconds;
    final progress = (_exerciseIndex + 1) / widget.plan.exercises.length;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C1016) : const Color(0xFFF7F1E6),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
          child: Column(
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
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Exercise ${_exerciseIndex + 1} of ${widget.plan.exercises.length}',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: const AlwaysStoppedAnimation(AppTheme.primaryContainer),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? const [Color(0xFF162033), Color(0xFF0F141D)]
                          : const [Color(0xFFFFFCF7), Color(0xFFF1E8DA)],
                    ),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.primaryContainer.withOpacity(0.16)
                          : const Color(0xFFE6D8C3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? AppTheme.primaryContainer.withOpacity(0.08)
                            : const Color(0x140F172A),
                        blurRadius: isDark ? 36 : 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 360;
                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _InfoPill(
                                  label: _currentExercise.prescription,
                                  color: AppTheme.primaryContainer,
                                ),
                                _InfoPill(
                                  label: _isCountdownMode ? 'Countdown' : 'Stopwatch',
                                  color: AppTheme.secondaryContainer,
                                ),
                                _InfoPill(
                                  label: _currentExercise.movementPattern,
                                  color: AppTheme.tertiary,
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Text(
                              _currentExercise.name,
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _currentExercise.cue,
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 15,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ..._currentExercise.primaryMuscles.map(
                                  (muscle) => _TagPill(
                                    label: muscle,
                                    color: AppTheme.secondaryContainer,
                                  ),
                                ),
                                ..._currentExercise.secondaryMuscles.take(2).map(
                                  (muscle) => _TagPill(
                                    label: muscle,
                                    color: AppTheme.tertiary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            _ExerciseStage(
                              exercise: _currentExercise,
                              compact: compact,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark
                      ? colorScheme.surfaceContainerLow
                      : const Color(0xFFFFFCF7),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? colorScheme.outlineVariant.withOpacity(0.35)
                        : const Color(0xFFE4D9C8),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? const Color(0x22000000)
                          : const Color(0x140F172A),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          color: AppTheme.primaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isCountdownMode ? 'Countdown' : 'Stopwatch',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatClock(displayTime),
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppTheme.primaryContainer,
                        fontWeight: FontWeight.w800,
                        fontSize: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: isDark
                            ? colorScheme.surfaceContainerHighest.withOpacity(0.5)
                            : const Color(0xFFF3EDE2),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark
                              ? colorScheme.outlineVariant.withOpacity(0.35)
                              : const Color(0xFFE0D4C3),
                        ),
                      ),
                      child: Row(
                        children: [
                          _SegmentAction(
                            icon: Icons.chevron_left,
                            label: 'Prev',
                            enabled: _exerciseIndex != 0,
                            onTap: _goPrevious,
                          ),
                          _SegmentDivider(
                            color: colorScheme.outlineVariant.withOpacity(0.25),
                          ),
                          _SegmentAction(
                            icon: _isRunning ? Icons.pause : Icons.play_arrow,
                            label: _isRunning ? 'Pause' : 'Resume',
                            enabled: true,
                            onTap: _togglePlayback,
                            textColor: AppTheme.primaryContainer,
                          ),
                          _SegmentDivider(
                            color: colorScheme.outlineVariant.withOpacity(0.25),
                          ),
                          _SegmentAction(
                            icon: isLastExercise
                                ? Icons.check_circle_outline
                                : Icons.chevron_right,
                            label: isLastExercise ? 'Finish' : 'Next',
                            enabled: true,
                            onTap: _goNext,
                            textColor: colorScheme.secondary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseStage extends StatelessWidget {
  final WorkoutExercise exercise;
  final bool compact;

  const _ExerciseStage({
    required this.exercise,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final animationCard = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: isDark ? const Color(0xFF0A111A) : const Color(0xFFF8F3EA),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFE8DCCB),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.play_circle_outline_rounded, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                exercise.animationType == 'gif' ? 'Exercise GIF' : 'Motion Preview',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: compact ? 1.1 : 1.35,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? const [Color(0xFF0E1520), Color(0xFF111A27)]
                      : const [Color(0xFFFFFFFF), Color(0xFFF1E8DC)],
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: exercise.animationType == 'gif'
                    ? Image.asset(exercise.animationAsset, fit: BoxFit.contain)
                    : Lottie.asset(
                        exercise.animationAsset,
                        repeat: true,
                        animate: true,
                        fit: BoxFit.contain,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            exercise.animationType == 'gif'
                ? 'Real movement reference with highlighted working muscles.'
                : 'Animation placeholder for this movement. We can replace it with a GIF asset later.',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );

    final targetCard = _TargetMapCard(exercise: exercise);

    if (compact) {
      return Column(
        children: [
          animationCard,
          const SizedBox(height: 12),
          targetCard,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: animationCard),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: targetCard),
      ],
    );
  }
}

class _TargetMapCard extends StatelessWidget {
  final WorkoutExercise exercise;

  const _TargetMapCard({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final highlighted = _highlightedAreas(exercise.bodyMapZones);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: colorScheme.surfaceContainerLow,
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.28),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Target Map',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _TargetSection(
            title: 'Primary',
            items: exercise.primaryMuscles,
            color: AppTheme.secondaryContainer,
          ),
          const SizedBox(height: 10),
          _TargetSection(
            title: 'Support',
            items: exercise.secondaryMuscles.isEmpty
                ? const ['Stability']
                : exercise.secondaryMuscles.take(3).toList(),
            color: AppTheme.tertiary,
          ),
          const SizedBox(height: 12),
          Text(
            'Highlighted Areas',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: highlighted
                .map(
                  (label) => _TagPill(
                    label: label,
                    color: AppTheme.primaryContainer,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  List<String> _highlightedAreas(List<String> zones) {
    final labels = <String>{};
    if (zones.contains('chest')) labels.add('Chest');
    if (zones.contains('frontShoulders') ||
        zones.contains('sideShoulders') ||
        zones.contains('rearShoulders')) {
      labels.add('Shoulders');
    }
    if (zones.contains('upperBack') ||
        zones.contains('midBack') ||
        zones.contains('lats') ||
        zones.contains('lowerBack')) {
      labels.add('Back');
    }
    if (zones.contains('triceps') ||
        zones.contains('biceps') ||
        zones.contains('forearms')) {
      labels.add('Arms');
    }
    if (zones.contains('core')) labels.add('Core');
    if (zones.contains('quads') || zones.contains('hamstrings') || zones.contains('calves')) {
      labels.add('Legs');
    }
    if (zones.contains('glutes')) labels.add('Glutes');
    return labels.isEmpty ? <String>['Full Body'] : labels.toList();
  }
}

class _TargetSection extends StatelessWidget {
  final String title;
  final List<String> items;
  final Color color;

  const _TargetSection({
    required this.title,
    required this.items,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items
              .map((item) => _TagPill(label: item, color: color))
              .toList(),
        ),
      ],
    );
  }
}

class _SegmentDivider extends StatelessWidget {
  final Color color;

  const _SegmentDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, color: color);
  }
}

class _SegmentAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final Color? textColor;

  const _SegmentAction({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveColor = enabled
        ? (textColor ?? colorScheme.onSurface)
        : colorScheme.onSurfaceVariant.withOpacity(0.45);

    return Expanded(
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: effectiveColor),
                const SizedBox(width: 6),
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: effectiveColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _RoundIconButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final Color color;

  const _InfoPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  final String label;
  final Color color;

  const _TagPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
