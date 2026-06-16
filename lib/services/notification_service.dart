import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// User-configurable workout reminder + streak-nudge settings.
class WorkoutReminderSettings {
  final bool enabled;
  final int hour;
  final int minute;
  final Set<int> weekdays; // 1=Mon … 7=Sun
  final bool streakNudge;

  const WorkoutReminderSettings({
    this.enabled = false,
    this.hour = 18,
    this.minute = 0,
    this.weekdays = const {1, 2, 3, 4, 5, 6, 7},
    this.streakNudge = true,
  });

  WorkoutReminderSettings copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    Set<int>? weekdays,
    bool? streakNudge,
  }) => WorkoutReminderSettings(
    enabled: enabled ?? this.enabled,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    weekdays: weekdays ?? this.weekdays,
    streakNudge: streakNudge ?? this.streakNudge,
  );
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int hydrationReminderId = 2001;
  static const int hydrationReminderFollowUpId = 2002;
  static const int hydrationReminderLateId = 2003;
  static const int _workoutReminderBaseId = 3100; // + weekday (1..7)
  static const int _streakNudgeId = 3200;

  static const String _prefEnabled = 'reminder_enabled';
  static const String _prefHour = 'reminder_hour';
  static const String _prefMinute = 'reminder_minute';
  static const String _prefWeekdays = 'reminder_weekdays';
  static const String _prefStreak = 'reminder_streak';

  static const AndroidNotificationChannel _hydrationChannel =
      AndroidNotificationChannel(
        'hydration_reminders',
        'Hydration Reminders',
        description: 'Reminders to drink water regularly',
        importance: Importance.high,
      );
  static const AndroidNotificationChannel _workoutChannel =
      AndroidNotificationChannel(
        'workout_reminders',
        'Workout Reminders',
        description: 'Reminders to train and keep your streak alive',
        importance: Importance.high,
      );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: android);

    await _plugin.initialize(initSettings);
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_hydrationChannel);
    await androidPlugin?.createNotificationChannel(_workoutChannel);
    _initialized = true;
  }

  Future<bool> requestPermissionIfNeeded() async {
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final notificationsEnabled = await android?.areNotificationsEnabled();
    if (notificationsEnabled != true) {
      await android?.requestNotificationsPermission();
    }
    return await android?.areNotificationsEnabled() ?? true;
  }

  Future<void> scheduleHydrationReminder({
    int id = hydrationReminderId,
    Duration after = const Duration(hours: 2),
    String title = 'Hydration reminder',
    String body = 'Time to drink water. Log a glass in FitForge.',
  }) async {
    await initialize();
    final when = tz.TZDateTime.now(tz.local).add(after);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'hydration_reminders',
          'Hydration Reminders',
          channelDescription: 'Reminders to drink water regularly',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelHydrationReminder() async {
    await initialize();
    await _plugin.cancel(hydrationReminderId);
    await _plugin.cancel(hydrationReminderFollowUpId);
    await _plugin.cancel(hydrationReminderLateId);
  }

  // ── Workout reminders / streak nudges ──────────────────────────────────────

  Future<WorkoutReminderSettings> loadWorkoutReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final weekdays = (prefs.getStringList(_prefWeekdays) ?? const <String>[])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
    return WorkoutReminderSettings(
      enabled: prefs.getBool(_prefEnabled) ?? false,
      hour: prefs.getInt(_prefHour) ?? 18,
      minute: prefs.getInt(_prefMinute) ?? 0,
      weekdays: weekdays.isEmpty ? const {1, 2, 3, 4, 5, 6, 7} : weekdays,
      streakNudge: prefs.getBool(_prefStreak) ?? true,
    );
  }

  /// Persists [settings] and (re)schedules the matching local notifications.
  Future<void> applyWorkoutReminderSettings(
    WorkoutReminderSettings settings,
  ) async {
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, settings.enabled);
    await prefs.setInt(_prefHour, settings.hour);
    await prefs.setInt(_prefMinute, settings.minute);
    await prefs.setStringList(
      _prefWeekdays,
      settings.weekdays.map((d) => '$d').toList(),
    );
    await prefs.setBool(_prefStreak, settings.streakNudge);

    await cancelWorkoutReminders();
    if (!settings.enabled) return;

    if (await requestPermissionIfNeeded() == false) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'workout_reminders',
        'Workout Reminders',
        channelDescription: 'Reminders to train and keep your streak alive',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    for (final weekday in settings.weekdays) {
      await _plugin.zonedSchedule(
        _workoutReminderBaseId + weekday,
        'Time to train 💪',
        'Your FitForge session is ready. Letʼs keep the momentum going.',
        _nextInstanceOfWeekdayTime(weekday, settings.hour, settings.minute),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }

    if (settings.streakNudge) {
      await _plugin.zonedSchedule(
        _streakNudgeId,
        'Keep your streak alive 🔥',
        'Havenʼt logged a workout today? A few minutes still counts.',
        _nextInstanceOfTime(20, 30),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> cancelWorkoutReminders() async {
    await initialize();
    for (var weekday = 1; weekday <= 7; weekday++) {
      await _plugin.cancel(_workoutReminderBaseId + weekday);
    }
    await _plugin.cancel(_streakNudgeId);
  }

  tz.TZDateTime _nextInstanceOfWeekdayTime(int weekday, int hour, int minute) {
    var scheduled = _nextInstanceOfTime(hour, minute);
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
