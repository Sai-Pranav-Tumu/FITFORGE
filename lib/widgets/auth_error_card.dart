import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

String formatAuthError(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code.toLowerCase()) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-email':
        return 'That email and password combination does not look right. Double-check it and try again.';
      case 'email-already-in-use':
        return 'An account already exists for this email. Try logging in instead.';
      case 'weak-password':
        return 'Choose a stronger password with at least 6 characters.';
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
