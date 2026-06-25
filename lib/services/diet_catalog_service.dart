import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/diet_catalog_models.dart';
import '../utils/dietary_preferences.dart';

/// Loads and caches the curated dish catalog used by the diet planner. Mirrors
/// the lazy-init + in-memory cache style of [NutritionService] but is read-only
/// (the catalog ships as a bundled asset).
class DietCatalogService {
  DietCatalogService._();

  static final DietCatalogService instance = DietCatalogService._();

  static const String _asset = 'assets/database/diet_catalog.json';

  List<CatalogDish>? _cache;
  Future<List<CatalogDish>>? _loading;

  Future<List<CatalogDish>> loadAll() {
    if (_cache != null) return Future<List<CatalogDish>>.value(_cache);
    return _loading ??= _loadInternal();
  }

  Future<List<CatalogDish>> _loadInternal() async {
    try {
      final raw = await rootBundle.loadString(_asset);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final dishes = (decoded['dishes'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => CatalogDish.fromJson(e as Map<String, dynamic>))
          .where((d) => d.name.isNotEmpty && d.kcal > 0)
          .toList(growable: false);
      _cache = dishes;
      return dishes;
    } catch (error, stack) {
      debugPrint('[DietCatalogService] failed to load catalog: $error\n$stack');
      _cache = const <CatalogDish>[];
      return _cache!;
    } finally {
      _loading = null;
    }
  }

  /// Candidate dishes for a meal [slot], honoring the user's dietary preference
  /// and culinary [zone]. Falls back progressively (zone → any zone) so the
  /// returned list is never empty when any dish matches slot + preference.
  ///
  /// [allDishes] is passed in so callers (incl. the planning isolate) can share
  /// a single load.
  List<CatalogDish> dishesFor({
    required List<CatalogDish> allDishes,
    required String slot,
    required String dietaryPreference,
    required String country,
    required String zone,
  }) {
    final pref = normalizeDietaryPreference(dietaryPreference);

    bool matchesDiet(CatalogDish dish) {
      switch (pref) {
        case DietaryPreferenceCodes.vegetarian:
          return dish.isVeg;
        case DietaryPreferenceCodes.nonVegOnly:
          // "Only non-veg" still allows egg dishes, but never pure veg.
          return dish.isNonVeg || dish.isEgg;
        default:
          return true; // mixed: anything goes
      }
    }

    // Hard-filter by country; if that leaves nothing (e.g. an unsupported
    // country), fall back to the whole catalog so a plan is never empty.
    var countryPool = allDishes
        .where((d) => d.servesCountry(country))
        .toList(growable: false);
    if (countryPool.isEmpty) countryPool = allDishes;

    final slotPool = countryPool
        .where((d) => d.fitsSlot(slot) && matchesDiet(d))
        .toList(growable: false);

    if (slotPool.isEmpty) {
      // Last-resort: ignore slot so the planner can still place something.
      final anySlot =
          countryPool.where(matchesDiet).toList(growable: false);
      return anySlot.isNotEmpty
          ? anySlot
          : allDishes.where(matchesDiet).toList(growable: false);
    }

    if (zone.isEmpty) return slotPool;

    final zoneMatched =
        slotPool.where((d) => d.servesZone(zone)).toList(growable: false);
    return zoneMatched.isNotEmpty ? zoneMatched : slotPool;
  }
}
