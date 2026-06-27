import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Subscription tiers. Each tier includes everything in the tiers below it.
enum AppTier { free, pro, max }

extension AppTierLabel on AppTier {
  String get label => switch (this) {
    AppTier.free => 'Free',
    AppTier.pro => 'Pro',
    AppTier.max => 'Max',
  };
}

AppTier tierFromName(String? name) {
  switch (name?.trim().toLowerCase()) {
    case 'max':
      return AppTier.max;
    case 'pro':
      return AppTier.pro;
    default:
      return AppTier.free;
  }
}

/// Maps a store product id to the tier it grants.
AppTier tierFromProductId(String id) {
  final p = id.toLowerCase();
  if (p.startsWith('max')) return AppTier.max;
  if (p.startsWith('pro')) return AppTier.pro;
  // Legacy single-"premium" products map to Pro.
  if (p.contains('premium')) return AppTier.pro;
  return AppTier.free;
}

/// Single source of truth for the user's subscription tier.
///
/// Persists the tier locally (and mirrors it to Firestore at `users/{uid}.tier`,
/// written authoritatively by the purchase-verification Cloud Function). The
/// rest of the app gates features via [tier] / [hasPro] / [hasMax]. The legacy
/// boolean [isPremium] is kept so existing call sites keep working.
class EntitlementService extends ChangeNotifier {
  EntitlementService._();
  static final EntitlementService instance = EntitlementService._();

  static const String _tierKey = 'app_tier';
  static const String _legacyKey = 'is_premium';

  /// Build-time demo switch. Build a tester/demo app with EVERY Max feature
  /// unlocked (no purchase needed) via:
  ///   flutter build apk --release --dart-define=DEMO_MAX=true
  /// Production builds omit the flag, so this is false and real tiers apply.
  static const bool demoUnlockAll = bool.fromEnvironment('DEMO_MAX');

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _userId;
  AppTier _tier = AppTier.free;
  bool _loaded = false;

  /// Effective tier — forced to Max in demo builds.
  AppTier get tier => demoUnlockAll ? AppTier.max : _tier;
  bool get loaded => _loaded;

  /// Back-compat: any paid tier counts as "premium".
  bool get isPremium => tier != AppTier.free;
  bool get hasPro => tier == AppTier.pro || tier == AppTier.max;
  bool get hasMax => tier == AppTier.max;

  Future<void> sync(String? userId) async {
    _userId = userId;
    final prefs = await SharedPreferences.getInstance();
    var tier = tierFromName(prefs.getString(_tierKey));
    // Migrate the old boolean premium flag → Pro.
    if (tier == AppTier.free && (prefs.getBool(_legacyKey) ?? false)) {
      tier = AppTier.pro;
    }

    if (userId != null && userId.isNotEmpty) {
      try {
        final doc = await _db.collection('users').doc(userId).get();
        final data = doc.data();
        final remoteTier = data?['tier'];
        final remotePremium = data?['isPremium'];
        if (remoteTier is String) {
          tier = tierFromName(remoteTier);
        } else if (remotePremium is bool) {
          tier = remotePremium ? AppTier.pro : AppTier.free;
        }
        await prefs.setString(_tierKey, tier.name);
      } catch (error) {
        debugPrint('Entitlement sync failed: $error');
      }
    }

    _tier = tier;
    _loaded = true;
    notifyListeners();
  }

  /// Updates the cache from a SERVER-VERIFIED tier (the Cloud Function already
  /// wrote the authoritative value to Firestore).
  Future<void> applyVerifiedTier(AppTier tier) async {
    _tier = tier;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tierKey, tier.name);
  }

  /// Dev/testing + best-effort local grant when server verification is
  /// unavailable. The Cloud Function owns the authoritative Firestore value, so
  /// the write below is denied under locked rules (expected/harmless) while the
  /// local cache still reflects the grant.
  Future<void> setTier(AppTier tier) async {
    _tier = tier;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tierKey, tier.name);
    final userId = _userId;
    if (userId != null && userId.isNotEmpty) {
      try {
        await _db.collection('users').doc(userId).set({
          'tier': tier.name,
          'isPremium': tier != AppTier.free,
        }, SetOptions(merge: true));
      } catch (error) {
        debugPrint(
          'Entitlement persist failed (expected under locked rules): $error',
        );
      }
    }
  }
}
