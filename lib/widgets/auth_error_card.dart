import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AuthFlow { signIn, signUp, social, deleteAccount }

String? validateEmailAndPassword({
  required String email,
  required String password,
  bool validateEmailFormat = true,
  bool enforceMinimumPasswordLength = false,
}) {
  final trimmedEmail = email.trim();
  final trimmedPassword = password.trim();

  if (trimmedEmail.isEmpty && trimmedPassword.isEmpty) {
    return 'Enter your email address and password.';
  }
  if (trimmedEmail.isEmpty) {
    return 'Email address is required.';
  }
  if (trimmedPassword.isEmpty) {
    return 'Password is required.';
  }
  if (validateEmailFormat && !_isValidEmail(trimmedEmail)) {
    return 'Enter a valid email address.';
  }
  if (enforceMinimumPasswordLength && password.length < 6) {
    return 'Password must be at least 6 characters long.';
  }
  return null;
}

String formatAuthError(
  Object error, {
  AuthFlow flow = AuthFlow.signIn,
}) {
  if (error is FirebaseAuthException) {
    switch (error.code.toLowerCase()) {
      case 'missing-email':
        return 'Email address is required.';
      case 'missing-password':
        if (flow == AuthFlow.deleteAccount) {
          return 'Enter your current password to delete your account.';
        }
        return 'Password is required.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'invalid-credential':
      case 'wrong-password':
        if (flow == AuthFlow.deleteAccount) {
          return 'The current password you entered is incorrect.';
        }
        return 'Email address or password does not match our records.';
      case 'user-not-found':
        if (flow == AuthFlow.deleteAccount) {
          return 'You need to sign in again before deleting your account.';
        }
        return 'Email address or password does not match our records.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support or try another account.';
      case 'user-mismatch':
        return flow == AuthFlow.deleteAccount
            ? 'Use the same Google account that you used to sign in to FitForge.'
            : 'Please use the same Google account you use for FitForge.';
      case 'email-already-in-use':
        return 'An account already exists for this email. Try logging in instead.';
      case 'weak-password':
        return flow == AuthFlow.signUp
            ? 'Password must be at least 6 characters long.'
            : 'Choose a stronger password with at least 6 characters.';
      case 'reauth-cancelled':
        return 'Account deletion was cancelled before we could verify your identity.';
      case 'requires-recent-login':
      case 'credential-too-old-login-again':
        return 'For your security, sign in again and then retry deleting your account.';
      case 'no-current-user':
        return 'You need to sign in again before deleting your account.';
      case 'operation-not-allowed':
        return flow == AuthFlow.signUp
            ? 'Email sign-up is not available right now. Please try again later.'
            : 'This sign-in method is not available right now. Please try again later.';
      case 'network-request-failed':
        return 'FitForge could not reach the server. Check your connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts were made just now. Please wait a moment and try again.';
    }

    final message = error.message?.trim();
    if (message != null && message.isNotEmpty) {
      return _cleanErrorMessage(message);
    }
  }

  return _cleanErrorMessage(error.toString());
}

String _cleanErrorMessage(String message) {
  var cleaned = message.trim().replaceFirst('Exception: ', '');
  cleaned = cleaned.replaceFirst(RegExp(r'^\[[^\]]+\]\s*'), '');
  return cleaned.isEmpty ? 'Something went wrong. Please try again.' : cleaned;
}

bool _isValidEmail(String email) {
  const emailPattern =
      r"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$";
  return RegExp(emailPattern, caseSensitive: false).hasMatch(email);
}

class AuthErrorCard extends StatelessWidget {
  final String title;
  final String message;

  const AuthErrorCard({super.key, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.errorContainer.withValues(alpha: 0.92),
            colorScheme.surfaceContainerHigh,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.error.withValues(alpha: 0.14),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colorScheme.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.error_outline_rounded, color: colorScheme.error),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(
                    color: colorScheme.onErrorContainer.withValues(alpha: 0.92),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryContainer.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Please try again',
                    style: TextStyle(
                      color: AppTheme.primaryContainer,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
