import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int hydrationReminderId = 2001;

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
    Duration after = const Duration(hours: 2),
  }) async {
    await initialize();
    final when = tz.TZDateTime.now(tz.local).add(after);

    await _plugin.zonedSchedule(
      hydrationReminderId,
      'Hydration reminder',
      'Time to drink water. Log a glass in FitForge.',
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
  }
}
