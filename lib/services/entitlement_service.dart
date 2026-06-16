import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Single source of truth for premium entitlement.
///
/// Today it persists a local flag (mirrored to Firestore at
/// `users/{uid}.isPremium`) so the rest of the app can gate features cleanly.
/// When real billing is added, replace [startPremium]/[restore] with
/// `in_app_purchase` (or RevenueCat) purchase flows — the public surface
/// ([isPremium], gating helpers) stays the same, so no UI rewrites are needed.
class EntitlementService extends ChangeNotifier {
  EntitlementService._();
  static final EntitlementService instance = EntitlementService._();

  static const String _prefsKey = 'is_premium';

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _userId;
  bool _isPremium = false;
  bool _loaded = false;

  bool get isPremium => _isPremium;
  bool get loaded => _loaded;

  Future<void> sync(String? userId) async {
    _userId = userId;
    final prefs = await SharedPreferences.getInstance();
    var premium = prefs.getBool(_prefsKey) ?? false;

    if (userId != null && userId.isNotEmpty) {
      try {
        final doc = await _db.collection('users').doc(userId).get();
        final remote = doc.data()?['isPremium'];
        if (remote is bool) {
          premium = remote;
          await prefs.setBool(_prefsKey, premium);
        }
      } catch (error) {
        debugPrint('Entitlement sync failed: $error');
      }
    }

    _isPremium = premium;
    _loaded = true;
    notifyListeners();
  }

  /// Dev/testing fallback that grants entitlement without a purchase. The real
  /// path is a verified store purchase via BillingService → [setPremium].
  Future<void> startPremium() => setPremium(true);

  /// Grants/revokes premium. Called by BillingService after a verified purchase
  /// (or restore). Persists locally and mirrors to Firestore (best-effort).
  Future<void> setPremium(bool premium) => _grant(premium);

  Future<void> _grant(bool premium) async {
    _isPremium = premium;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, premium);
    final userId = _userId;
    if (userId != null && userId.isNotEmpty) {
      try {
        await _db.collection('users').doc(userId).set({
          'isPremium': premium,
        }, SetOptions(merge: true));
      } catch (error) {
        debugPrint('Entitlement persist failed: $error');
      }
    }
  }
}
