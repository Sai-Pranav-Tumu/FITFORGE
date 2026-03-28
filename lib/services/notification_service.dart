import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int hydrationReminderId = 2001;
  static const int hydrationReminderFollowUpId = 2002;
  static const int hydrationReminderLateId = 2003;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: android);

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  Future<void> requestPermissionIfNeeded() async {
    final android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
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
}
