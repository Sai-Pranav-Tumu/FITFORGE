import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';

class WaterProvider extends ChangeNotifier {
  User? _authUser;
  double _consumedLiters = 0;
  final double _goalLiters = 2.4;
  DateTime? _lastIntakeAt;
  bool _isLoading = false;
  Timer? _dayRolloverTimer;
  String? _activeDayKey;

  double get consumedLiters => _consumedLiters;
  double get goalLiters => _goalLiters;
  DateTime? get lastIntakeAt => _lastIntakeAt;
  bool get isLoading => _isLoading;

  void sync(User? user) {
    final changed = _authUser?.uid != user?.uid;
    _authUser = user;
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
    } else if (_authUser != null && _lastIntakeAt == null) {
      load();
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

    final ts = prefs.getInt(_key('water_last_ts'));
    _lastIntakeAt = ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts);

    _isLoading = false;
    notifyListeners();

    _startDayRolloverMonitor();
    await NotificationService.instance.requestPermissionIfNeeded();
    await _rescheduleReminder();
  }

  Future<void> addLiters(double liters) async {
    if (_authUser == null || liters <= 0) return;

    _consumedLiters += liters;
    _lastIntakeAt = DateTime.now();
    await _save();
    notifyListeners();
    await _rescheduleReminder();
  }

  Future<void> _save() async {
    if (_authUser == null) return;
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _todayKey();
    await prefs.setDouble(_key('water_liters_$dateKey'), _consumedLiters);
    if (_lastIntakeAt != null) {
      await prefs.setInt(
        _key('water_last_ts'),
        _lastIntakeAt!.millisecondsSinceEpoch,
      );
    }
  }

  Future<void> _rescheduleReminder() async {
    await NotificationService.instance.cancelHydrationReminder();
    final now = DateTime.now();
    final anchor = _lastIntakeAt ?? now;
    final nextAt = anchor.add(const Duration(hours: 2));
    final after = nextAt.isAfter(now)
        ? nextAt.difference(now)
        : const Duration(minutes: 1);
    await NotificationService.instance.scheduleHydrationReminder(after: after);
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
