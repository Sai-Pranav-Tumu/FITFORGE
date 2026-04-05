import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get currentUserUsesPasswordSignIn =>
      currentUser?.providerData.any(
        (provider) => provider.providerId == 'password',
      ) ??
      false;

  // ── Email / Password ──────────────────────────────────────────────────────

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
          email: email, password: password);
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential?> registerWithEmail(
      String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
    } catch (e) {
      rethrow;
    }
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────

  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Opens the Google account picker sheet
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // User cancelled the picker
      if (googleUser == null) return null;

      // Get the auth tokens from the selected account
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Build a Firebase credential from the Google tokens
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with that credential
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> reauthenticateForAccountDeletion({
    String? currentPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Sign in again before deleting your account.',
      );
    }

    final providerIds = user.providerData
        .map((provider) => provider.providerId)
        .toSet();

    if (providerIds.contains('password')) {
      final email = user.email?.trim();
      if (email == null || email.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-email',
          message: 'Email address is required to verify your account.',
        );
      }
      if (currentPassword == null || currentPassword.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-password',
          message: 'Enter your current password to delete your account.',
        );
      }
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      return;
    }

    if (providerIds.contains('google.com')) {
      GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
      googleUser ??= await _googleSignIn.signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'reauth-cancelled',
          message: 'Google reauthentication was cancelled.',
        );
      }

      final email = user.email?.trim().toLowerCase();
      if (email != null &&
          email.isNotEmpty &&
          googleUser.email.trim().toLowerCase() != email) {
        throw FirebaseAuthException(
          code: 'user-mismatch',
          message: 'Please choose the same Google account you use for FitForge.',
        );
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
    }
  }

  Future<void> deleteCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Sign in again before deleting your account.',
      );
    }

    await user.delete();

    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      // Ignore disconnect failures for non-Google accounts.
    }
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    // Sign out from both Google and Firebase so the account picker
    // shows again on the next sign-in instead of auto-selecting.
    await Future.wait([
      _googleSignIn.signOut(),
      _auth.signOut(),
    ]);
  }
}
