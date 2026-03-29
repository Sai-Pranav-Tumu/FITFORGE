import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../services/notification_service.dart';

class WaterProvider extends ChangeNotifier {
  User? _authUser;
  UserModel? _profile;
  double _consumedLiters = 0;
  double _goalLiters = 2.4;
  DateTime? _lastIntakeAt;
  bool _isLoading = false;
  Timer? _dayRolloverTimer;
  String? _activeDayKey;
  bool _remindersEnabled = true;
  int _reminderIntervalMinutes = 90;
  List<_WaterEvent> _events = <_WaterEvent>[];

  double get consumedLiters => _consumedLiters;
  double get goalLiters => _goalLiters;
  DateTime? get lastIntakeAt => _lastIntakeAt;
  bool get isLoading => _isLoading;
  bool get remindersEnabled => _remindersEnabled;
  int get reminderIntervalMinutes => _reminderIntervalMinutes;

  void sync(User? user, UserModel? profile) {
    final changed = _authUser?.uid != user?.uid;
    _authUser = user;
    _profile = profile;
    if (changed) {
      if (_authUser == null) {
        _dayRolloverTimer?.cancel();
        _dayRolloverTimer = null;
        _activeDayKey = null;
        _consumedLiters = 0;
        _lastIntakeAt = null;
        notifyListeners();
      } else {
        load();
      }
    } else if (_authUser != null &&
        (_lastIntakeAt == null || _profile != profile)) {
      load();
    } else if (_authUser != null) {
      final newGoal = _computeGoalLiters();
      if ((newGoal - _goalLiters).abs() > 0.01) {
        _goalLiters = newGoal;
        notifyListeners();
      }
    }
  }

  Future<void> load() async {
    if (_authUser == null) return;
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final dateKey = _todayKey();
    _activeDayKey = dateKey;
    _consumedLiters = prefs.getDouble(_key('water_liters_$dateKey')) ?? 0;
    _remindersEnabled = prefs.getBool(_key('water_reminders_enabled')) ?? true;
    _reminderIntervalMinutes =
        prefs.getInt(_key('water_reminder_interval')) ?? 90;
    _goalLiters = _computeGoalLiters();

    final rawEvents = prefs.getString(_key('water_events_$dateKey'));
    _events = rawEvents == null || rawEvents.isEmpty
        ? <_WaterEvent>[]
        : (jsonDecode(rawEvents) as List<dynamic>)
              .map((item) => _WaterEvent.fromJson(item as Map<String, dynamic>))
              .toList();
    final ts = prefs.getInt(_key('water_last_ts'));
    _lastIntakeAt = _events.isNotEmpty
        ? _events.last.at
        : (ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts));

    _isLoading = false;
    notifyListeners();

    _startDayRolloverMonitor();
    await _rescheduleReminder();
  }

  Future<void> addLiters(double liters) async {
    if (_authUser == null || liters <= 0) return;

    _consumedLiters += liters;
    _lastIntakeAt = DateTime.now();
    _events.add(_WaterEvent(at: _lastIntakeAt!, liters: liters));
    await _save();
    notifyListeners();
    await _rescheduleReminder();
  }

  Future<void> removeLiters(double liters) async {
    if (_authUser == null || liters <= 0) return;

    var remainingToRemove = liters;
    while (remainingToRemove > 0 && _events.isNotEmpty) {
      final last = _events.removeLast();
      if (last.liters > remainingToRemove) {
        _events.add(
          _WaterEvent(at: last.at, liters: last.liters - remainingToRemove),
        );
        remainingToRemove = 0;
      } else {
        remainingToRemove -= last.liters;
      }
    }
    _consumedLiters = _events.fold<double>(
      0,
      (sum, event) => sum + event.liters,
    );
    _lastIntakeAt = _events.isEmpty ? null : _events.last.at;
    await _save();
    notifyListeners();
    await _rescheduleReminder();
  }

  Future<void> setRemindersEnabled(bool enabled) async {
    if (_authUser == null) return;
    _remindersEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key('water_reminders_enabled'), enabled);
    if (enabled) {
      await NotificationService.instance.requestPermissionIfNeeded();
    }
    notifyListeners();
    await _rescheduleReminder();
  }

  Future<void> setReminderIntervalMinutes(int minutes) async {
    if (_authUser == null) return;
    _reminderIntervalMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key('water_reminder_interval'), minutes);
    notifyListeners();
    await _rescheduleReminder();
  }

  Future<void> requestReminderPermissionIfNeeded() async {
    if (_authUser == null || !_remindersEnabled) return;
    await NotificationService.instance.requestPermissionIfNeeded();
    await _rescheduleReminder();
  }

  Future<void> _save() async {
    if (_authUser == null) return;
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _todayKey();
    await prefs.setDouble(_key('water_liters_$dateKey'), _consumedLiters);
    await prefs.setString(
      _key('water_events_$dateKey'),
      jsonEncode(_events.map((event) => event.toJson()).toList()),
    );
    if (_lastIntakeAt != null) {
      await prefs.setInt(
        _key('water_last_ts'),
        _lastIntakeAt!.millisecondsSinceEpoch,
      );
    } else {
      await prefs.remove(_key('water_last_ts'));
    }
  }

  Future<void> _rescheduleReminder() async {
    await NotificationService.instance.cancelHydrationReminder();
    if (!_remindersEnabled) return;
    final now = DateTime.now();
    final anchor = _lastIntakeAt ?? now;
    final firstReminder = anchor.add(
      Duration(minutes: _reminderIntervalMinutes),
    );
    final secondReminder = anchor.add(
      Duration(minutes: _reminderIntervalMinutes * 2),
    );
    final thirdReminder = anchor.add(
      Duration(minutes: _reminderIntervalMinutes * 3),
    );
    await NotificationService.instance.scheduleHydrationReminder(
      after: firstReminder.isAfter(now)
          ? firstReminder.difference(now)
          : const Duration(minutes: 1),
    );
    await NotificationService.instance.scheduleHydrationReminder(
      id: NotificationService.hydrationReminderFollowUpId,
      after: secondReminder.isAfter(now)
          ? secondReminder.difference(now)
          : const Duration(minutes: 2),
      title: 'Still behind on water',
      body: 'A quick glass of water now will help you stay on track.',
    );
    await NotificationService.instance.scheduleHydrationReminder(
      id: NotificationService.hydrationReminderLateId,
      after: thirdReminder.isAfter(now)
          ? thirdReminder.difference(now)
          : const Duration(minutes: 3),
      title: 'Hydration check-in',
      body: 'Log some water in FitForge to keep your hydration streak alive.',
    );
  }

  double _computeGoalLiters() {
    final weight = _profile?.weight ?? 70.0;
    final month = DateTime.now().month;
    var goal = weight > 0 ? weight * 0.033 : 2.4;

    if ((_profile?.workoutDays ?? 0) >= 4) {
      goal += 0.35;
    } else if ((_profile?.workoutDays ?? 0) >= 2) {
      goal += 0.2;
    }

    if (month >= 3 && month <= 6) {
      goal += 0.35;
    } else if (month == 7 || month == 8) {
      goal += 0.2;
    } else if (month == 11 || month == 12 || month == 1 || month == 2) {
      goal -= 0.2;
    }

    return goal.clamp(1.8, 4.8);
  }

  String _todayKey() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  String _key(String leaf) => '${_authUser!.uid}_$leaf';

  void _startDayRolloverMonitor() {
    _dayRolloverTimer ??= Timer.periodic(const Duration(minutes: 1), (_) async {
      if (_authUser == null) return;
      final today = _todayKey();
      if (_activeDayKey == today) return;
      await load();
    });
  }

  @override
  void dispose() {
    _dayRolloverTimer?.cancel();
    super.dispose();
  }
}

class _WaterEvent {
  final DateTime at;
  final double liters;

  const _WaterEvent({required this.at, required this.liters});

  Map<String, dynamic> toJson() => <String, dynamic>{
    'at': at.millisecondsSinceEpoch,
    'liters': liters,
  };

  factory _WaterEvent.fromJson(Map<String, dynamic> json) => _WaterEvent(
    at: DateTime.fromMillisecondsSinceEpoch(json['at'] as int),
    liters: (json['liters'] as num).toDouble(),
  );
}
