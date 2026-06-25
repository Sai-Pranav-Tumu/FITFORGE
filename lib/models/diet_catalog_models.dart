import '../utils/regions.dart';

/// A composed, plated dish from `assets/database/diet_catalog.json`. Unlike the
/// raw nutrient table used for calorie logging, every catalog entry is a real
/// meal a user can actually eat (no standalone spices/condiments).
class CatalogDish {
  final int id;
  final String name;

  /// Human-readable serving, e.g. "1 katori dal + 2 rotis". Shown in the plan
  /// instead of a raw gram amount.
  final String serving;

  /// Meal slots this dish suits: breakfast | lunch | dinner | snack.
  final List<String> slots;

  /// veg | egg | nonveg.
  final String diet;

  /// Catalog country code: india | usa | uk | australia | canada. Defaults to
  /// `india` for legacy entries that predate multi-country support.
  final String country;

  /// Region codes within the country (see [CulinaryZones]); may include the
  /// country-wide fallback (`panindia` for India, `general` elsewhere).
  final List<String> zones;

  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;

  const CatalogDish({
    required this.id,
    required this.name,
    required this.serving,
    required this.slots,
    required this.diet,
    required this.country,
    required this.zones,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
  });

  bool fitsSlot(String slot) => slots.contains(slot);

  bool get isVeg => diet == 'veg';
  bool get isEgg => diet == 'egg';
  bool get isNonVeg => diet == 'nonveg';

  bool servesCountry(String code) => code.isEmpty || country == code;

  /// Within the dish's (already country-matched) country, does it serve the
  /// user's region? Country-wide pools (`panindia`/`general`) match everything.
  bool servesZone(String zone) =>
      zone.isEmpty ||
      zones.contains(zone) ||
      zones.contains(CulinaryZones.panIndia) ||
      zones.contains(CulinaryZones.general);

  /// Protein delivered per 100 kcal — the key "is this a gym-friendly dish"
  /// signal reused by the heuristic scorer.
  double get proteinPer100Kcal => kcal <= 0 ? 0 : (protein * 4.0) / kcal * 100.0;

  static double _num(Object? value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? fallback;
  }

  factory CatalogDish.fromJson(Map<String, dynamic> json) {
    return CatalogDish(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String?)?.trim() ?? '',
      serving: (json['serving'] as String?)?.trim() ?? '',
      slots: ((json['slots'] as List<dynamic>?) ?? const <dynamic>[])
          .map((e) => '$e')
          .toList(growable: false),
      diet: (json['diet'] as String?)?.trim().toLowerCase() ?? 'veg',
      country: (json['country'] as String?)?.trim().toLowerCase() ?? 'india',
      zones: ((json['zones'] as List<dynamic>?) ?? const <dynamic>[])
          .map((e) => '$e')
          .toList(growable: false),
      kcal: _num(json['kcal']),
      protein: _num(json['protein']),
      carbs: _num(json['carbs']),
      fat: _num(json['fat']),
      fiber: _num(json['fiber']),
    );
  }
}
