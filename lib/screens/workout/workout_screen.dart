import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../models/workout_plan.dart';
import '../../providers/workout_provider.dart';
import '../../providers/user_provider.dart';
import '../../screens/workout/workout_session_screen.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/exercise_media.dart';
import '../../widgets/top_app_bar.dart';
import '../../widgets/workout_progress_card.dart';

class WorkoutScreen extends StatelessWidget {
  final VoidCallback? onOpenProfile;

  const WorkoutScreen({super.key, this.onOpenProfile});

  @override
  Widget build(BuildContext context) {
    return Consumer2<UserProvider, WorkoutProvider>(
      builder: (context, userProvider, workoutProvider, _) {
        final profile = userProvider.userProfile;
        if (profile == null ||
            (workoutProvider.loading &&
                workoutProvider.recommendation == null)) {
          return const _WorkoutLoadingState();
        }

        // Only hard-block when there is genuinely nothing to show. With the
        // bundled starter pack loaded this is rare; the upgrade to the full
        // library happens via an in-content banner instead.
        if (!workoutProvider.hasExercises) {
          return _WorkoutDownloadPrompt(
            syncingLibrary: workoutProvider.syncingLibrary,
            errorMessage: workoutProvider.error,
            shouldShowPrompt: workoutProvider.shouldShowDownloadPrompt,
            downloadProgress: workoutProvider.downloadProgress,
            downloadPhase: workoutProvider.downloadPhase,
            downloadPhaseMessage: workoutProvider.downloadPhaseMessage,
            onDownload: workoutProvider.acceptExerciseLibraryDownload,
            onSkip: workoutProvider.declineExerciseLibraryDownload,
          );
        }

        if (workoutProvider.recommendation == null) {
          return const _WorkoutLoadingState();
        }

        return _WorkoutContent(
          profile: profile,
          recommendation: workoutProvider.recommendation!,
          usingStarterPack: workoutProvider.usingStarterPack,
          syncingLibrary: workoutProvider.syncingLibrary,
          downloadProgress: workoutProvider.downloadProgress,
          downloadPhase: workoutProvider.downloadPhase,
          downloadPhaseMessage: workoutProvider.downloadPhaseMessage,
          onOpenProfile: onOpenProfile,
        );
      },
    );
  }
}

class _WorkoutContent extends StatefulWidget {
  final UserModel profile;
  final WorkoutRecommendation recommendation;
  final bool usingStarterPack;
  final bool syncingLibrary;
  final double downloadProgress;
  final String downloadPhase;
  final String downloadPhaseMessage;
  final VoidCallback? onOpenProfile;

  const _WorkoutContent({
    required this.profile,
    required this.recommendation,
    required this.usingStarterPack,
    required this.syncingLibrary,
    required this.downloadProgress,
    required this.downloadPhase,
    required this.downloadPhaseMessage,
    this.onOpenProfile,
  });

  @override
  State<_WorkoutContent> createState() => _WorkoutContentState();
}

class _WorkoutContentState extends State<_WorkoutContent> {
  late DateTime _selectedDate;
  double _calendarProgress = 0.0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  void _setCalendarProgress(double value) {
    final nextValue = value.clamp(0.0, 1.0).toDouble();
    if (nextValue == _calendarProgress) {
      return;
    }

    setState(() {
      _calendarProgress = nextValue;
    });
  }

  void _toggleCalendar() {
    _setCalendarProgress(_calendarProgress > 0.5 ? 0.0 : 1.0);
  }

  void _handleCalendarVerticalDragUpdate(
    DragUpdateDetails details,
    double dragRange,
  ) {
    final nextValue = (_calendarProgress + (details.delta.dy / dragRange))
        .clamp(0.0, 1.0)
        .toDouble();
    if (nextValue == _calendarProgress) {
      return;
    }

    setState(() {
      _calendarProgress = nextValue;
    });
  }

  void _handleCalendarVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final shouldExpand = velocity.abs() > 220
        ? velocity > 0
        : _calendarProgress > 0.32;
    _setCalendarProgress(shouldExpand ? 1.0 : 0.0);
  }

  void _handleCalendarHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 220) {
      return;
    }

    if (_calendarProgress < 0.35) {
      _shiftSelectedDateByDays(velocity < 0 ? 7 : -7);
      return;
    }

    _shiftSelectedMonth(velocity < 0 ? 1 : -1);
  }

  void _shiftSelectedDateByDays(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  void _shiftSelectedMonth(int offset) {
    setState(() {
      _selectedDate = _monthShiftedDate(_selectedDate, offset);
    });
  }

  DateTime _monthShiftedDate(DateTime date, int offset) {
    final shiftedMonth = DateTime(date.year, date.month + offset, 1);
    final lastDayOfMonth = DateTime(
      shiftedMonth.year,
      shiftedMonth.month + 1,
      0,
    ).day;

    return DateTime(
      shiftedMonth.year,
      shiftedMonth.month,
      date.day.clamp(1, lastDayOfMonth),
    );
  }

  Future<void> _refreshWorkout() async {
    final userProvider = context.read<UserProvider>();
    final workoutProvider = context.read<WorkoutProvider>();
    final currentProfile = userProvider.userProfile;
    if (currentProfile == null) {
      return;
    }

    await userProvider.fetchUserProfile(currentProfile.id);
    // Keep the current plan visible while recomputing so the dashboard doesn't
    // flash/stutter during the pull-to-refresh.
    await workoutProvider.refresh(
      profile: userProvider.userProfile ?? currentProfile,
      clearCurrent: false,
    );
  }

  Future<void> _openWorkoutSession(
    WorkoutDayPlan plan, {
    int initialExerciseIndex = 0,
    bool trackCompletion = false,
  }) async {
    final result = await Navigator.of(context).push<WorkoutSessionResult>(
      MaterialPageRoute<WorkoutSessionResult>(
        fullscreenDialog: true,
        builder: (_) => WorkoutSessionScreen(
          plan: plan,
          initialExerciseIndex: initialExerciseIndex,
          sessionDate: _selectedDate,
          trackCompletion: trackCompletion,
        ),
      ),
    );

    if (!mounted || result?.newlyCompleted != true) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _WorkoutCompletionDialog(result: result!),
    );

    if (mounted) {
      await _promptWorkoutFeedback();
    }
  }

  Future<void> _promptWorkoutFeedback() async {
    final feedback = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;
        Widget option(String value, String emoji, String label, String sub) {
          return ListTile(
            leading: Text(emoji, style: const TextStyle(fontSize: 26)),
            title: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(sub),
            onTap: () => Navigator.of(sheetContext).pop(value),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'How did that workout feel?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'We use this to fine-tune your next sessions.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                option(
                  'too_easy',
                  '😎',
                  'Too easy',
                  'Add a bit more volume next time',
                ),
                option('just_right', '💪', 'Just right', 'Keep this intensity'),
                option(
                  'too_hard',
                  '🥵',
                  'Too hard',
                  'Ease off the volume a little',
                ),
              ],
            ),
          ),
        );
      },
    );

    if (feedback == null || !mounted) {
      return;
    }

    final userProvider = context.read<UserProvider>();
    final workoutProvider = context.read<WorkoutProvider>();
    final profile = userProvider.userProfile;
    if (profile == null) {
      return;
    }

    final current = profile.intensityAdjustment;
    final next = switch (feedback) {
      'too_easy' => (current + 1).clamp(-2, 2),
      'too_hard' => (current - 1).clamp(-2, 2),
      _ => current,
    };
    AnalyticsService.instance.logWorkoutFeedback(feedback);

    if (next != current) {
      final updated = profile.copyWith(intensityAdjustment: next);
      await userProvider.updateProfile(updated);
      await workoutProvider.refresh(profile: updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              feedback == 'too_easy'
                  ? 'Got it — your upcoming sessions will ramp up.'
                  : 'Got it — we’ll ease off your upcoming sessions.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final recommendation = widget.recommendation;
    final profile = widget.profile;
    final greetingPrefix = recommendation.greeting.split(',').first.trim();
    final todaysPlan = _planForDate(_selectedDate);

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 380;
    final contentBottomPadding = isSmallScreen ? 24.0 : 28.0;

    final weekHeight = isSmallScreen ? 90.0 : 100.0;
    final monthRowHeight = isSmallScreen ? 54.0 : 58.0;
    final monthHeaderAreaHeight = isSmallScreen ? 30.0 : 34.0;
    final monthWeekLabelHeight = isSmallScreen ? 28.0 : 32.0;
    final monthRowSpacing = 8.0;
    final monthRows = _monthRowCount(_selectedDate);
    final monthGridHeight =
        (monthRows * monthRowHeight) + ((monthRows - 1) * monthRowSpacing);
    final monthHeight =
        monthHeaderAreaHeight + monthWeekLabelHeight + monthGridHeight;
    final visibleCalendarHeight =
        weekHeight + ((monthHeight - weekHeight) * _calendarProgress);

    return Scaffold(
      appBar: TopAppBar(
        title: greetingPrefix,
        subtitle: profile.name,
        onAvatarTap: widget.onOpenProfile,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshWorkout,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(16, 12, 16, contentBottomPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (profile.hasTargetWeight) ...[
                _GoalProgressCard(profile: profile),
                const SizedBox(height: 14),
              ],
              WorkoutProgressCard(profile: profile),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weekly Focus',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          recommendation.weeklyFocus,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: isSmallScreen ? 12 : 13,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _calendarProgress >= 0.5 ? 'Month' : 'Week',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                decoration: _cardDecoration(context),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: _MonthHeader(
                        monthLabel: _monthLabel(_selectedDate),
                        onPrevious: () => _shiftSelectedMonth(-1),
                        onNext: () => _shiftSelectedMonth(1),
                      ),
                    ),
                    ClipRect(
                      child: Align(
                        alignment: Alignment.topCenter,
                        heightFactor: (visibleCalendarHeight / monthHeight)
                            .clamp(0.0, 1.0),
                        child: SizedBox(
                          height: monthHeight,
                          child: Stack(
                            children: [
                              Positioned(
                                left: 0,
                                right: 0,
                                top: 0,
                                height: weekHeight,
                                child: IgnorePointer(
                                  ignoring: _calendarProgress > 0.55,
                                  child: Opacity(
                                    opacity: (1 - (_calendarProgress * 1.4))
                                        .clamp(0.0, 1.0),
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onHorizontalDragEnd:
                                          _handleCalendarHorizontalDragEnd,
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          10,
                                          2,
                                          10,
                                          0,
                                        ),
                                        child: _buildWeekStrip(context),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: IgnorePointer(
                                  ignoring: _calendarProgress < 0.12,
                                  child: Opacity(
                                    opacity: ((_calendarProgress - 0.08) / 0.92)
                                        .clamp(0.0, 1.0),
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onHorizontalDragEnd:
                                          _handleCalendarHorizontalDragEnd,
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          10,
                                          2,
                                          10,
                                          0,
                                        ),
                                        child: _buildMonthGrid(
                                          context,
                                          rowHeight: monthRowHeight,
                                          rowSpacing: monthRowSpacing,
                                          showWeekLabels: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (details) {
                        _handleCalendarVerticalDragUpdate(
                          details,
                          monthHeight - weekHeight,
                        );
                      },
                      onVerticalDragEnd: _handleCalendarVerticalDragEnd,
                      onTap: _toggleCalendar,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 12),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _calendarProgress > 0.5
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 2),
                              Container(
                                width: isSmallScreen ? 58 : 64,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: colorScheme.outlineVariant.withValues(
                                    alpha: 0.72,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (widget.syncingLibrary) ...[
                _DownloadProgressPanel(
                  progress: widget.downloadProgress,
                  phase: widget.downloadPhase,
                  message: widget.downloadPhaseMessage,
                  compact: true,
                ),
                const SizedBox(height: 18),
              ] else if (widget.usingStarterPack) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: _cardDecoration(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.cloud_download_outlined,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Using the starter exercise pack',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'You can train now with a curated set. Download the full library to unlock hundreds more exercises with animated demos.',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => context
                              .read<WorkoutProvider>()
                              .acceptExerciseLibraryDownload(),
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text('Download full library'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],
              Container(
                padding: const EdgeInsets.all(18),
                decoration: _cardDecoration(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Plan Logic',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _planReason(context, 'Goal', _goalReason(profile)),
                    const SizedBox(height: 8),
                    _planReason(
                      context,
                      'Lifestyle',
                      _lifestyleReason(profile),
                    ),
                    const SizedBox(height: 8),
                    _planReason(
                      context,
                      'Schedule',
                      'Your ${profile.workoutDays}-day availability determines the split and recovery balance.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              _buildWorkoutCard(context, todaysPlan),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Exercise Routine',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '${todaysPlan.exercises.length} Exercises',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Goal: ${profile.fitnessGoal}  ·  Occupation: ${profile.occupation}',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              ...todaysPlan.exercises.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildExerciseRow(
                    context,
                    entry.value,
                    index: entry.key,
                    plan: todaysPlan,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeekStrip(BuildContext context) {
    final weekDates = List.generate(7, (index) {
      final monday = _selectedDate.subtract(
        Duration(days: _selectedDate.weekday - 1),
      );
      return monday.add(Duration(days: index));
    });

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: weekDates
          .map(
            (date) => _CalendarDay(
              dayLabel: _weekdayLabel(date.weekday - 1),
              day: date.day,
              isSelected: _isSameDate(date, _selectedDate),
              isCompleted: widget.profile.hasCompletedWorkoutOn(date),
              compact: false,
              onTap: () => setState(() => _selectedDate = date),
            ),
          )
          .toList(),
    );
  }

  Widget _buildMonthGrid(
    BuildContext context, {
    required double rowHeight,
    required double rowSpacing,
    required bool showWeekLabels,
  }) {
    final firstDayOfMonth = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      1,
    );
    final daysInMonth = DateTime(
      _selectedDate.year,
      _selectedDate.month + 1,
      0,
    ).day;
    final leadingBlanks = firstDayOfMonth.weekday - 1;
    final rowCount = _monthRowCount(_selectedDate);
    final totalCells = rowCount * 7;
    final trailingBlanks = totalCells - (leadingBlanks + daysInMonth);

    return Column(
      children: [
        if (showWeekLabels) ...[
          Row(
            children: const [
              _CalendarWeekLabel('MON'),
              _CalendarWeekLabel('TUE'),
              _CalendarWeekLabel('WED'),
              _CalendarWeekLabel('THU'),
              _CalendarWeekLabel('FRI'),
              _CalendarWeekLabel('SAT'),
              _CalendarWeekLabel('SUN'),
            ],
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          height: (rowHeight * rowCount) + ((rowCount - 1) * rowSpacing),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: rowSpacing,
              crossAxisSpacing: 4,
              mainAxisExtent: rowHeight,
            ),
            itemBuilder: (context, index) {
              if (index < leadingBlanks ||
                  index >= totalCells - trailingBlanks) {
                return const SizedBox.shrink();
              }

              final dayNumber = index - leadingBlanks + 1;
              final date = DateTime(
                _selectedDate.year,
                _selectedDate.month,
                dayNumber,
              );
              return _CalendarDay(
                dayLabel: '',
                day: dayNumber,
                isSelected: _isSameDate(date, _selectedDate),
                isCompleted: widget.profile.hasCompletedWorkoutOn(date),
                compact: true,
                onTap: () => setState(() => _selectedDate = date),
              );
            },
          ),
        ),
      ],
    );
  }

  int _monthRowCount(DateTime date) {
    final firstDay = DateTime(date.year, date.month, 1);
    final daysInMonth = DateTime(date.year, date.month + 1, 0).day;
    final leadingBlanks = firstDay.weekday - 1;
    return ((leadingBlanks + daysInMonth) / 7).ceil();
  }

  Widget _buildWorkoutCard(BuildContext context, WorkoutDayPlan plan) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCompleted = widget.profile.hasCompletedWorkoutOn(_selectedDate);
    final isToday = _isSameDate(_selectedDate, DateTime.now());
    final streak = widget.profile.streak;
    final statusLabel = isCompleted
        ? (isToday ? 'COMPLETED TODAY' : 'COMPLETED')
        : (plan.isRestDay ? "TODAY'S RECOVERY" : "TODAY'S WORKOUT");
    final actionLabel = isCompleted
        ? 'Review Workout ->'
        : (plan.isRestDay ? 'Start Recovery ->' : 'Start Workout ->');
    final actionColor = isCompleted
        ? const Color(0xFF1FAE6A)
        : AppTheme.primaryContainer;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151A22) : const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? actionColor.withValues(alpha: 0.45)
              : (isDark
                    ? colorScheme.outlineVariant.withValues(alpha: 0.8)
                    : const Color(0xFFE9DECE)),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x33000000) : const Color(0x140F172A),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppTheme.primaryContainer.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? actionColor
                        : (plan.isRestDay
                              ? colorScheme.surfaceContainerHighest
                              : AppTheme.secondaryContainer),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(
                    statusLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  plan.title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  plan.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${plan.exercises.length} exercises  ·  ${plan.durationMinutes} min  ·  ${plan.estimatedCalories} kcal',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (isCompleted) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: actionColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: actionColor.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: actionColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isToday
                                  ? 'Today is done'
                                  : 'This session is completed',
                              style: TextStyle(
                                color: actionColor,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        if (streak > 0)
                          _buildMetaChip(
                            context,
                            Icons.local_fire_department_rounded,
                            '$streak day streak',
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMetaChip(
                      context,
                      Icons.route_rounded,
                      plan.exercises.first.movementPattern,
                    ),
                    _buildMetaChip(
                      context,
                      Icons.bolt_rounded,
                      plan.exercises.first.difficulty,
                    ),
                    _buildMetaChip(
                      context,
                      Icons.sports_gymnastics_rounded,
                      plan.exercises.first.equipment,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => _openWorkoutSession(
                      plan,
                      trackCompletion: !_isFutureDate(_selectedDate),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: actionColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    child: Text(
                      actionLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _weekdayLabel(int index) {
    const labels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return labels[index];
  }

  String _monthLabel(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  WorkoutDayPlan _planForDate(DateTime date) {
    return widget.recommendation.weeklyPlan[date.weekday - 1];
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isFutureDate(DateTime date) {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return normalizedDate.isAfter(normalizedToday);
  }

  String _goalReason(UserModel profile) {
    switch (profile.fitnessGoal) {
      case 'Lose Weight':
        return 'More full-body work and conditioning blocks are used to increase weekly calorie burn.';
      case 'Gain Muscle':
        return 'The plan emphasizes split training and moderate rep ranges for progressive overload.';
      case 'Improve Stamina':
        return 'The plan adds conditioning-focused sessions and denser work blocks.';
      default:
        return 'The plan prioritizes consistency, recovery, and easy-to-follow sessions.';
    }
  }

  String _lifestyleReason(UserModel profile) {
    if (profile.sittingHours == '8+ Hours' ||
        profile.sittingHours == '6-8 Hours') {
      return 'Because you sit for long hours, extra mobility and posture-friendly moves are included.';
    }
    if (profile.occupation == 'Physical Labor') {
      return 'Because your job is already physically demanding, recovery is protected with smarter spacing.';
    }
    return 'Your daily routine supports a balanced mix of strength, conditioning, and recovery.';
  }

  Widget _planReason(BuildContext context, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: colorScheme.primary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseRow(
    BuildContext context,
    WorkoutExercise exercise, {
    required int index,
    required WorkoutDayPlan plan,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openWorkoutSession(
          plan,
          initialExerciseIndex: index,
          trackCompletion: false,
        ),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: _cardDecoration(context),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: exercise.animationFrames.isNotEmpty
                    ? _RoutineExerciseThumbnail(
                        exercise: exercise,
                        fallbackIcon: _exerciseIcon(exercise.movementPattern),
                      )
                    : Icon(
                        _exerciseIcon(exercise.movementPattern),
                        color: colorScheme.primary,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryContainer.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'EX ${index + 1}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: AppTheme.primaryContainer,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Jump In',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.play_circle_fill_rounded,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      exercise.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      exercise.prescription,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      exercise.cue,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ...exercise.primaryMuscles
                            .take(2)
                            .map(
                              (muscle) => _miniChip(
                                context,
                                muscle,
                                AppTheme.secondaryContainer,
                              ),
                            ),
                        _miniChip(
                          context,
                          exercise.equipment,
                          AppTheme.primaryContainer,
                        ),
                        if (exercise.targetDurationSeconds != null)
                          _miniChip(
                            context,
                            '${exercise.targetDurationSeconds}s',
                            AppTheme.tertiary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 34),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniChip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  IconData _exerciseIcon(String movementPattern) {
    final lower = movementPattern.toLowerCase();
    if (lower.contains('push')) return Icons.north_rounded;
    if (lower.contains('pull')) return Icons.south_rounded;
    if (lower.contains('squat') || lower.contains('lunge')) {
      return Icons.accessibility_new_rounded;
    }
    if (lower.contains('core') || lower.contains('carry')) {
      return Icons.blur_circular_rounded;
    }
    if (lower.contains('condition')) return Icons.bolt_rounded;
    return Icons.fitness_center;
  }

  Widget _buildMetaChip(BuildContext context, IconData icon, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration(BuildContext context, {double radius = 16}) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: colorScheme.outlineVariant.withValues(
          alpha: isDark ? 0.24 : 0.32,
        ),
      ),
      boxShadow: [
        BoxShadow(
          color: isDark ? const Color(0x22000000) : const Color(0x120F172A),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

class _RoutineExerciseThumbnail extends StatefulWidget {
  final WorkoutExercise exercise;
  final IconData fallbackIcon;

  const _RoutineExerciseThumbnail({
    required this.exercise,
    required this.fallbackIcon,
  });

  @override
  State<_RoutineExerciseThumbnail> createState() =>
      _RoutineExerciseThumbnailState();
}

class _RoutineExerciseThumbnailState extends State<_RoutineExerciseThumbnail> {
  Timer? _previewTimer;
  Timer? _settleTimer;
  int _frameIndex = 0;
  bool _isPreviewing = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant _RoutineExerciseThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exercise.animationFrames != widget.exercise.animationFrames ||
        oldWidget.exercise.frameDurationMillis !=
            widget.exercise.frameDurationMillis) {
      _stopPreview();
    }
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _settleTimer?.cancel();
    super.dispose();
  }

  void _startPreview() {
    if (widget.exercise.animationFrames.length < 2) {
      return;
    }

    _previewTimer?.cancel();
    _settleTimer?.cancel();
    setState(() {
      _isPreviewing = true;
      _frameIndex = 0;
    });

    _previewTimer = Timer.periodic(
      Duration(milliseconds: widget.exercise.frameDurationMillis),
      (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _frameIndex =
              (_frameIndex + 1) % widget.exercise.animationFrames.length;
        });
      },
    );

    _settleTimer = Timer(
      Duration(milliseconds: widget.exercise.frameDurationMillis * 3),
      _stopPreview,
    );
  }

  void _stopPreview() {
    _previewTimer?.cancel();
    _settleTimer?.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _isPreviewing = false;
      _frameIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final frame =
        widget.exercise.animationFrames[_isPreviewing ? _frameIndex : 0];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _startPreview,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: ExerciseMedia(
            key: ValueKey<String>(frame),
            path: frame,
            source: widget.exercise.animationFramesSource,
            fit: BoxFit.cover,
            fallbackBuilder: (_) =>
                Icon(widget.fallbackIcon, color: colorScheme.primary),
          ),
        ),
      ),
    );
  }
}

class _GoalProgressCard extends StatelessWidget {
  final UserModel profile;

  const _GoalProgressCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isImperial = profile.preferredUnits == 'imperial';
    final progress = profile.goalProgress ?? 0.0;
    final reached = profile.hasReachedWeightGoal;
    final remaining = profile.weightRemainingToTarget;

    String fmt(double kg) {
      if (isImperial) return '${(kg * 2.20462).toStringAsFixed(1)} lb';
      return '${kg.toStringAsFixed(1)} kg';
    }

    final losing = remaining > 0;
    final headline = reached
        ? 'Goal weight reached 🎉'
        : '${fmt(remaining.abs())} to ${losing ? 'lose' : 'gain'}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryContainer.withValues(alpha: 0.16),
            AppTheme.tertiary.withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryContainer.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.flag_rounded,
                color: AppTheme.primaryContainer,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'WEIGHT GOAL',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            headline,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.primaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Now ${fmt(profile.weight)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                'Goal ${fmt(profile.targetWeight)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final String monthLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _MonthHeader({
    required this.monthLabel,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
          splashRadius: 20,
        ),
        Text(
          monthLabel,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
          splashRadius: 20,
          color: colorScheme.onSurface,
        ),
      ],
    );
  }
}

class _CalendarWeekLabel extends StatelessWidget {
  final String label;

  const _CalendarWeekLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  final String dayLabel;
  final int day;
  final bool isSelected;
  final bool isCompleted;
  final bool compact;
  final VoidCallback onTap;

  const _CalendarDay({
    required this.dayLabel,
    required this.day,
    required this.isSelected,
    required this.isCompleted,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final circleSize = compact ? 32.0 : 36.0;
    final dayFont = compact ? 15.0 : 16.0;
    final dotSize = compact ? 5.0 : 6.0;
    final completionSize = compact ? 14.0 : 16.0;
    final labelGap = compact ? 0.0 : 8.0;
    final dotGap = compact ? 6.0 : 8.0;
    final completionColor = const Color(0xFF1FAE6A);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dayLabel.isNotEmpty)
            Text(
              dayLabel,
              style: TextStyle(
                fontSize: 10,
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 1.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (dayLabel.isNotEmpty) SizedBox(height: labelGap),
          Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryContainer
                  : Colors.transparent,
              shape: BoxShape.circle,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryContainer.withValues(alpha: 0.2),
                        spreadRadius: compact ? 2 : 4,
                      ),
                    ]
                  : [],
            ),
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: dayFont,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : colorScheme.onSurface,
                ),
              ),
            ),
          ),
          SizedBox(height: dotGap),
          isCompleted
              ? Container(
                  width: completionSize,
                  height: completionSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: completionColor,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: compact ? 10 : 12,
                    color: Colors.white,
                  ),
                )
              : Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryContainer,
                  ),
                ),
        ],
      ),
    );
  }
}

class _WorkoutCompletionDialog extends StatelessWidget {
  final WorkoutSessionResult result;

  const _WorkoutCompletionDialog({required this.result});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final streakText = result.streak <= 1
        ? 'Your streak has started.'
        : '${result.streak} day streak is on fire.';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.28)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24000000),
              blurRadius: 28,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 180, height: 120, child: _FireBurst()),
            const SizedBox(height: 8),
            Text(
              'Workout Completed',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              streakText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: AppTheme.secondary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${result.streak} day streak',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppTheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Keep Going'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FireBurst extends StatelessWidget {
  const _FireBurst();

  static const List<({double x, double y, double size})> _particles = [
    (x: -54, y: -12, size: 22),
    (x: -36, y: -40, size: 18),
    (x: -8, y: -54, size: 16),
    (x: 24, y: -44, size: 20),
    (x: 52, y: -10, size: 18),
    (x: 38, y: 24, size: 16),
    (x: 6, y: 34, size: 14),
    (x: -30, y: 22, size: 18),
  ];

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutBack,
      builder: (context, value, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            for (final particle in _particles)
              Transform.translate(
                offset: Offset(particle.x * value, particle.y * value),
                child: Opacity(
                  opacity: (0.3 + (value * 0.7)).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.65 + (value * 0.45),
                    child: Icon(
                      Icons.local_fire_department_rounded,
                      size: particle.size,
                      color: AppTheme.secondary,
                    ),
                  ),
                ),
              ),
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.secondary.withValues(alpha: 0.18),
                    AppTheme.secondary.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            const Icon(
              Icons.local_fire_department_rounded,
              size: 42,
              color: AppTheme.secondary,
            ),
          ],
        );
      },
    );
  }
}

class _WorkoutDownloadPrompt extends StatelessWidget {
  final bool syncingLibrary;
  final double downloadProgress;
  final String downloadPhase;
  final String downloadPhaseMessage;
  final String? errorMessage;
  final bool shouldShowPrompt;
  final Future<void> Function() onDownload;
  final Future<void> Function() onSkip;

  const _WorkoutDownloadPrompt({
    required this.syncingLibrary,
    required this.downloadProgress,
    required this.downloadPhase,
    required this.downloadPhaseMessage,
    required this.errorMessage,
    required this.shouldShowPrompt,
    required this.onDownload,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = shouldShowPrompt
        ? 'Download Your Exercise Library'
        : 'Exercise Library Not Available';
    final description = shouldShowPrompt
        ? 'FitForge will download the full exercise dataset locally so your workouts can be personalized and run smoothly without shipping thousands of files.'
        : 'The full exercise dataset is not configured for download yet. Please check your network or ask your app administrator to enable the exercise library source.';

    return Scaffold(
      appBar: const TopAppBar(title: 'Exercise Library'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Text(
              description,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            if (errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  errorMessage!,
                  style: TextStyle(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
            if (syncingLibrary) ...[
              _DownloadProgressPanel(
                progress: downloadProgress,
                phase: downloadPhase,
                message: downloadPhaseMessage,
              ),
            ] else if (shouldShowPrompt) ...[
              ElevatedButton(
                onPressed: onDownload,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Download Now'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onSkip,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Maybe Later'),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Exercise library unavailable'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DownloadProgressPanel extends StatelessWidget {
  final double progress;
  final String phase;
  final String message;
  final bool compact;

  const _DownloadProgressPanel({
    required this.progress,
    required this.phase,
    required this.message,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final phaseTitle = _phaseTitle(phase);
    final percent = (progress.clamp(0.0, 1.0) * 100).round();
    final icon = _phaseIcon(phase);

    return Container(
      padding: EdgeInsets.all(compact ? 16 : 18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(compact ? 18 : 22),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 40 : 48,
                height: compact ? 40 : 48,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      phaseTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$percent% complete',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: compact ? 8 : 10,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: compact ? 13 : 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  static String _phaseTitle(String phase) {
    if (phase == 'dataset' || phase == 'images') {
      return 'Downloading exercise libraries';
    }

    return switch (phase) {
      'extracting' => 'Extracting and organizing files',
      'setup' => 'Setting up your workout library',
      'complete' => 'Exercise library ready',
      'failed' => 'Download interrupted',
      _ => 'Preparing your exercise library',
    };
  }

  static IconData _phaseIcon(String phase) {
    if (phase == 'dataset' || phase == 'images') {
      return Icons.download_for_offline_outlined;
    }

    return switch (phase) {
      'extracting' => Icons.unarchive_outlined,
      'setup' => Icons.folder_copy_outlined,
      'complete' => Icons.check_circle_outline_rounded,
      'failed' => Icons.error_outline_rounded,
      _ => Icons.sync_rounded,
    };
  }
}

class _WorkoutLoadingState extends StatelessWidget {
  const _WorkoutLoadingState();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TopAppBar(title: 'Good Morning'),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
