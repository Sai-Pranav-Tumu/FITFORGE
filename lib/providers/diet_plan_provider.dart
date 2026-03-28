import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/diet_plan_models.dart';
import '../models/user_model.dart';
import '../services/diet_plan_service.dart';

class DietPlanProvider extends ChangeNotifier {
  DietPlan? _plan;
  bool _loading = false;
  String? _error;
  String? _activeUserId;

  DietPlan? get plan => _plan;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasPlan => _plan != null;

  Future<void> sync(String? userId) async {
    if (_activeUserId == userId) return;
    _activeUserId = userId;
    if (userId == null || userId.isEmpty) {
      _plan = null;
      _loading = false;
      _error = null;
      notifyListeners();
      return;
    }
    await loadLatest(userId);
  }

  Future<void> generate(UserModel user) async {
    _setLoading(true);
    _error = null;
    try {
      final generated = await DietPlanService.instance.generate(user);
      _plan = generated;
      await _savePlan(generated);
    } catch (error) {
      _error = error.toString();
      debugPrint('[DietPlanProvider] generate error: $error');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadLatest(String userId) async {
    _setLoading(true);
    _error = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey(userId));
      if (raw == null || raw.isEmpty) {
        _plan = null;
      } else {
        _plan = DietPlan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (error) {
      _error = error.toString();
      debugPrint('[DietPlanProvider] loadLatest error: $error');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> swapMeal({
    required int dayIndex,
    required String slot,
    required UserModel user,
  }) async {
    if (_plan == null) return;
    _setLoading(true);
    _error = null;
    try {
      final newMeal = await DietPlanService.instance.regenerateMeal(
        plan: _plan!,
        dayIndex: dayIndex,
        slot: slot,
        user: user,
      );
      final updatedDays = List<PlannedDay>.from(_plan!.days);
      final updatedDay = updatedDays[dayIndex].copyWith(
        meals: updatedDays[dayIndex].meals
            .map((meal) => meal.slot == slot ? newMeal : meal)
            .toList(),
      );
      updatedDays[dayIndex] = updatedDay;
      _plan = _plan!.copyWith(days: updatedDays);
      await _savePlan(_plan!);
    } catch (error) {
      _error = error.toString();
      debugPrint('[DietPlanProvider] swapMeal error: $error');
    } finally {
      _setLoading(false);
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> _savePlan(DietPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey(plan.userId), jsonEncode(plan.toJson()));
  }

  String _storageKey(String userId) => 'diet_plan_$userId';

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }
}
