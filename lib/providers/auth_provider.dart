import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _user;
  bool _isLoading = true;

  User? get user => _user;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _authService.authStateChanges.listen((User? user) {
      _user = user;
      _isLoading = false;
      notifyListeners();
    });
  }

  // ── Email / Password ──────────────────────────────────────────────────────

  Future<UserCredential?> signIn(String email, String password) async {
    try {
      return await _authService.signInWithEmail(email, password);
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential?> signUp(String email, String password) async {
    try {
      return await _authService.registerWithEmail(email, password);
    } catch (e) {
      rethrow;
    }
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────

  /// Returns null if the user cancelled the Google account picker.
  /// Throws on any other error so the UI can display it.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      return await _authService.signInWithGoogle();
    } catch (e) {
      rethrow;
    }
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _authService.signOut();
  }
}
