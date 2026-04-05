import 'package:shared_preferences/shared_preferences.dart';

import 'database_service.dart';
import 'notification_service.dart';
import 'nutrition_service.dart';

class AccountDeletionService {
  AccountDeletionService._();

  static final AccountDeletionService instance = AccountDeletionService._();

  final DatabaseService _databaseService = DatabaseService();
  final NutritionService _nutritionService = NutritionService.instance;

  Future<void> deleteRemoteDataForUser(String userId) async {
    await _databaseService.deleteUser(userId);
  }

  Future<void> deleteLocalDataForUser(String userId) async {
    await _nutritionService.deleteUserData(userId);
    await NotificationService.instance.cancelHydrationReminder();
    await _clearUserPreferences(userId);
  }

  Future<void> _clearUserPreferences(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final keysToRemove = prefs.getKeys().where((key) {
      return key == 'diet_plan_$userId' || key.startsWith('${userId}_');
    }).toList(growable: false);

    for (final key in keysToRemove) {
      await prefs.remove(key);
    }
  }
}
