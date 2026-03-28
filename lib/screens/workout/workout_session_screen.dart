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

    final shouldAdvance = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
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
    final isLastExercise = _exerciseIndex == widget.plan.exercises.length - 1;
    final displayTime = _isCountdownMode ? _countdownSeconds ?? 0 : _elapsedSeconds;
    final progress = (_exerciseIndex + 1) / widget.plan.exercises.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0C1016),
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
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF162033), Color(0xFF0F141D)],
                    ),
                    border: Border.all(
                      color: AppTheme.primaryContainer.withOpacity(0.16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryContainer.withOpacity(0.08),
                        blurRadius: 36,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
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
                      const SizedBox(height: 18),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
                            color: const Color(0xFF0A111A),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.04),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Lottie.asset(
                                    _animationAssetForExercise(_currentExercise.name),
                                    repeat: true,
                                    animate: true,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text(
                                  'Follow the movement rhythm and keep the form cue in mind.',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
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
                        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withOpacity(0.35),
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
                          _SegmentDivider(color: colorScheme.outlineVariant.withOpacity(0.25)),
                          _SegmentAction(
                            icon: _isRunning ? Icons.pause : Icons.play_arrow,
                            label: _isRunning ? 'Pause' : 'Resume',
                            enabled: true,
                            onTap: _togglePlayback,
                            textColor: AppTheme.primaryContainer,
                          ),
                          _SegmentDivider(color: colorScheme.outlineVariant.withOpacity(0.25)),
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

  String _animationAssetForExercise(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('press') ||
        lower.contains('push') ||
        lower.contains('dip') ||
        lower.contains('raise')) {
      return 'assets/animations/exercise_push.json';
    }
    if (lower.contains('row') ||
        lower.contains('pull') ||
        lower.contains('curl')) {
      return 'assets/animations/exercise_pull.json';
    }
    if (lower.contains('squat') ||
        lower.contains('lunge') ||
        lower.contains('leg') ||
        lower.contains('step')) {
      return 'assets/animations/exercise_squat.json';
    }
    if (lower.contains('plank') ||
        lower.contains('dead bug') ||
        lower.contains('hollow') ||
        lower.contains('core')) {
      return 'assets/animations/exercise_core.json';
    }
    return 'assets/animations/exercise_cardio.json';
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
