import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';

class UserProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();

  UserModel? _userProfile;
  bool _isLoading = false;
  String? _activeUid;

  UserModel? get userProfile => _userProfile;
  bool get isLoading => _isLoading;

  void syncAuthUser(User? user) {
    if (user == null) {
      _activeUid = null;
      _userProfile = null;
      _isLoading = false;
      Future.microtask(notifyListeners);
      return;
    }

    if (_activeUid == user.uid && (_userProfile != null || _isLoading)) {
      return;
    }

    _activeUid = user.uid;
    _isLoading = true;
    notifyListeners();
    Future.microtask(() => fetchUserProfile(user.uid));
  }

  Future<void> fetchUserProfile(String uid) async {
    _isLoading = true;
    notifyListeners();

    try {
      _userProfile = await _dbService.getUser(uid);
    } catch (e) {
      debugPrint("Error fetching profile: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<UserModel> ensureProfileForUser(
    User user, {
    String? fallbackName,
  }) async {
    final existingUser = await _dbService.getUser(user.uid);
    if (existingUser != null) {
      _userProfile = existingUser;
      notifyListeners();
      return existingUser;
    }

    final displayName = fallbackName?.trim();
    final newUser = UserModel(
      id: user.uid,
      email: user.email ?? '',
      name: (displayName != null && displayName.isNotEmpty)
          ? displayName
          : (user.displayName?.trim().isNotEmpty ?? false)
          ? user.displayName!.trim()
          : (user.email?.trim().isNotEmpty ?? false)
          ? user.email!.trim()
          : 'User',
    );

    await _dbService.createUser(newUser);
    _userProfile = newUser;
    notifyListeners();
    return newUser;
  }

  Future<void> createProfile(User user, String name) async {
    await ensureProfileForUser(user, fallbackName: name);
  }

  Future<void> saveOnboardingAnswers({
    required User user,
    required String name,
    required String gender,
    required int age,
    required double weight,
    required String occupation,
    required String sittingHours,
    required String fitnessGoal,
    required int workoutDays,
    double height = 170.0,
    String trainingLevel = 'Beginner',
    String workoutLocation = 'Home',
    String availableEquipment = 'Bodyweight',
    int sessionDurationMinutes = 30,
    String targetMuscleFocus = 'Full Body',
    String jointSensitivity = 'None',
    List<String>? targetMuscleFocuses,
    List<String>? jointSensitivities,
  }) async {
    final existingProfile =
        _userProfile ?? await ensureProfileForUser(user, fallbackName: name);

    final updatedProfile = existingProfile.copyWith(
      name: name.trim(),
      gender: gender,
      age: age,
      weight: weight,
      occupation: occupation,
      sittingHours: sittingHours,
      fitnessGoal: fitnessGoal,
      workoutDays: workoutDays,
      height: height,
      trainingLevel: trainingLevel,
      workoutLocation: workoutLocation,
      availableEquipment: availableEquipment,
      sessionDurationMinutes: sessionDurationMinutes,
      targetMuscleFocus: targetMuscleFocus,
      jointSensitivity: jointSensitivity,
      targetMuscleFocuses: targetMuscleFocuses,
      jointSensitivities: jointSensitivities,
      onboardingComplete: true,
    );

    await _dbService.saveUser(updatedProfile);
    _userProfile = updatedProfile;
    notifyListeners();
  }

  Future<void> updateProfile(UserModel updatedProfile) async {
    await _dbService.saveUser(updatedProfile);
    _userProfile = updatedProfile;
    notifyListeners();
  }

  void clearProfile() {
    _userProfile = null;
    _isLoading = false;
    notifyListeners();
  }
}
