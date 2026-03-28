import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/nutrition_models.dart';
import '../models/user_model.dart';
import '../services/nutrition_service.dart';

class NutritionProvider extends ChangeNotifier {
  final NutritionService _service = NutritionService.instance;

  User? _authUser;
  UserModel? _profile;
  Timer? _dayRolloverTimer;
  DateTime? _lastObservedNow;
  DateTime? _selectedMonth;

  DailyNutritionSummary? _dailySummary;
  MonthlyNutritionSummary? _monthlySummary;
  bool _isLoading = false;
  String? _error;

  DailyNutritionSummary? get dailySummary => _dailySummary;
  MonthlyNutritionSummary? get monthlySummary => _monthlySummary;
  DateTime get selectedMonth {
    final m = _selectedMonth ?? DateTime.now();
    return DateTime(m.year, m.month, 1);
  }

  bool get canGoNextMonth {
    final now = DateTime.now();
    final current = DateTime(now.year, now.month, 1);
    final selected = selectedMonth;
    return selected.isBefore(current);
  }

  bool get isLoading => _isLoading;
  String? get error => _error;

  void sync(User? authUser, UserModel? profile) {
    final authChanged = _authUser?.uid != authUser?.uid;
    final profileChanged = _profile != profile;

    _authUser = authUser;
    _profile = profile;

    if (_authUser == null || _profile == null) {
      _dayRolloverTimer?.cancel();
      _dayRolloverTimer = null;
      _lastObservedNow = null;
      _dailySummary = null;
      _monthlySummary = null;
      _isLoading = false;
      _error = null;
      notifyListeners();
      return;
    }

    _selectedMonth ??= DateTime(DateTime.now().year, DateTime.now().month, 1);
    _startDayRolloverMonitor();

    if (authChanged ||
        profileChanged ||
        _dailySummary == null ||
        _monthlySummary == null) {
      refresh();
    }
  }

  Future<void> refresh() async {
    if (_authUser == null || _profile == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final month = selectedMonth;
      final daily = await _service.getDailySummary(
        userId: _authUser!.uid,
        date: now,
        user: _profile!,
      );
      final monthly = await _service.getMonthlySummary(
        userId: _authUser!.uid,
        month: month,
        user: _profile!,
      );
      _dailySummary = daily;
      _monthlySummary = monthly;
    } catch (e) {
      _error = 'Nutrition sync failed: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addEntry({
    required MealType mealType,
    required int foodId,
    required double quantityGrams,
  }) async {
    if (_authUser == null) return;
    await _service.addMealEntry(
      userId: _authUser!.uid,
      date: DateTime.now(),
      mealType: mealType,
      foodId: foodId,
      quantityGrams: quantityGrams,
    );
    await refresh();
  }

  Future<void> deleteEntry(String entryId) async {
    if (_authUser == null) return;
    await _service.deleteMealEntry(userId: _authUser!.uid, entryId: entryId);
    await refresh();
  }

  Future<void> selectMonth(DateTime month) async {
    _selectedMonth = DateTime(month.year, month.month, 1);
    await refresh();
  }

  Future<void> goToPreviousMonth() async {
    final m = selectedMonth;
    await selectMonth(DateTime(m.year, m.month - 1, 1));
  }

  Future<void> goToNextMonth() async {
    if (!canGoNextMonth) return;
    final m = selectedMonth;
    await selectMonth(DateTime(m.year, m.month + 1, 1));
  }

  void _startDayRolloverMonitor() {
    _lastObservedNow ??= DateTime.now();
    _dayRolloverTimer ??= Timer.periodic(const Duration(minutes: 1), (_) async {
      final now = DateTime.now();
      final previous = _lastObservedNow!;

      final dayChanged =
          now.year != previous.year ||
          now.month != previous.month ||
          now.day != previous.day;
      if (!dayChanged) return;

      final previousCurrentMonth = DateTime(previous.year, previous.month, 1);
      if (_selectedMonth != null &&
          _selectedMonth!.year == previousCurrentMonth.year &&
          _selectedMonth!.month == previousCurrentMonth.month) {
        _selectedMonth = DateTime(now.year, now.month, 1);
      }

      _lastObservedNow = now;
      await refresh();
    });
  }

  @override
  void dispose() {
    _dayRolloverTimer?.cancel();
    super.dispose();
  }
}
