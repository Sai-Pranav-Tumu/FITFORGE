import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Central wrapper around Firebase Analytics + Crashlytics so the rest of the
/// app logs events and errors through one small, swappable surface.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  /// A navigator observer that auto-logs screen views to Analytics.
  FirebaseAnalyticsObserver get navigatorObserver =>
      FirebaseAnalyticsObserver(analytics: analytics);

  /// Routes Flutter framework + async errors to Crashlytics. Call once at start.
  void installErrorHandlers() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  /// Collection is disabled in debug builds to avoid noise.
  Future<void> enableCollection() async {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode,
    );
    await analytics.setAnalyticsCollectionEnabled(!kDebugMode);
  }

  Future<void> setUser(String? id) async {
    await analytics.setUserId(id: id);
    if (id != null) {
      await FirebaseCrashlytics.instance.setUserIdentifier(id);
    }
  }

  Future<void> log(String name, [Map<String, Object>? params]) async {
    try {
      await analytics.logEvent(name: name, parameters: params);
    } catch (error) {
      debugPrint('Analytics log failed ($name): $error');
    }
  }

  Future<void> logWorkoutCompleted({
    required String planTitle,
    required int exercises,
    required int streak,
  }) => log('workout_completed', {
    'plan_title': planTitle,
    'exercises': exercises,
    'streak': streak,
  });

  Future<void> logSetLogged({
    required String exercise,
    required int reps,
    required double weightKg,
  }) => log('set_logged', {
    'exercise': exercise,
    'reps': reps,
    'weight_kg': weightKg,
  });

  Future<void> logLibraryDownloadStarted() =>
      log('exercise_library_download_started');

  Future<void> logWorkoutFeedback(String rating) =>
      log('workout_feedback', {'rating': rating});
}
