import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/diet_catalog_models.dart';
import '../models/diet_plan_models.dart';
import '../models/user_model.dart';
import '../utils/dietary_preferences.dart';
import '../utils/regions.dart';

/// Model-ready view of the user shared by the planner heuristic and the TFLite
/// model, so both build the *same* feature inputs.
class PlanUserContext {
  final String goalKey; // fat_loss | muscle_gain | endurance | maintenance
  final String dietaryPreference;
  final String countryCode; // india | usa | uk | australia | canada
  final String zone; // region code within the country, '' when unset
  final double targetCalories;
  final double targetProtein;
  final bool isMale;

  const PlanUserContext({
    required this.goalKey,
    required this.dietaryPreference,
    required this.countryCode,
    required this.zone,
    required this.targetCalories,
    required this.targetProtein,
    required this.isMale,
  });

  factory PlanUserContext.forUser(UserModel user, TdeeResult tdee) {
    final country = user.country.isEmpty ? Countries.india : user.country;
    return PlanUserContext(
      goalKey: goalKeyForLabel(tdee.goalLabel),
      dietaryPreference: normalizeDietaryPreference(user.dietaryPreference),
      countryCode: countryCodeFor(country),
      zone: resolveRegion(country, user.state),
      targetCalories: tdee.targetCalories,
      targetProtein: tdee.targetProtein,
      isMale: user.gender.trim().toLowerCase() == 'male',
    );
  }

  static String goalKeyForLabel(String goalLabel) {
    final g = goalLabel.toLowerCase();
    if (g.contains('muscle') || g.contains('gain')) return 'muscle_gain';
    if (g.contains('endurance') || g.contains('stamina')) return 'endurance';
    if (g.contains('loss') || g.contains('lose')) return 'fat_loss';
    return 'maintenance';
  }
}

/// Builds the feature vector fed to the model. The ORDER and FORMULAS here MUST
/// match `ml/diet_recommender.ipynb` exactly, or training and inference diverge.
///
/// Index | feature
///   0   kcal / 700
///   1   protein / 50
///   2   carbs / 120
///   3   fat / 45
///   4   fiber / 15
///   5   proteinPer100Kcal / 40
///   6   fat fraction of kcal (fat*9/kcal)
///   7   carb fraction of kcal (carbs*4/kcal)
///   8   diet == veg
///   9   diet == egg
///  10   diet == nonveg
///  11   zone matches user (or zone unset)
///  12   goal == fat_loss
///  13   goal == muscle_gain
///  14   goal == endurance
///  15   goal == maintenance
List<double> buildDishFeatures(PlanUserContext ctx, CatalogDish dish) {
  final kcal = dish.kcal <= 0 ? 1.0 : dish.kcal;
  return <double>[
    dish.kcal / 700.0,
    dish.protein / 50.0,
    dish.carbs / 120.0,
    dish.fat / 45.0,
    dish.fiber / 15.0,
    dish.proteinPer100Kcal / 40.0,
    (dish.fat * 9.0) / kcal,
    (dish.carbs * 4.0) / kcal,
    dish.isVeg ? 1.0 : 0.0,
    dish.isEgg ? 1.0 : 0.0,
    dish.isNonVeg ? 1.0 : 0.0,
    dish.servesZone(ctx.zone) ? 1.0 : 0.0,
    ctx.goalKey == 'fat_loss' ? 1.0 : 0.0,
    ctx.goalKey == 'muscle_gain' ? 1.0 : 0.0,
    ctx.goalKey == 'endurance' ? 1.0 : 0.0,
    ctx.goalKey == 'maintenance' ? 1.0 : 0.0,
  ];
}

const int _featureCount = 16;

/// Wraps the optional on-device TFLite recommender. When the model asset is
/// absent or fails to load, [isAvailable] stays false and callers fall back to
/// the heuristic scorer — so the app ships and works before any model exists.
class DietRecommenderModel {
  DietRecommenderModel._();

  static final DietRecommenderModel instance = DietRecommenderModel._();

  static const String _modelAsset = 'assets/models/diet_recommender.tflite';
  static const String _scalerAsset = 'assets/models/feature_scaler.json';

  Interpreter? _interpreter;
  List<double>? _mean;
  List<double>? _std;
  bool _loaded = false;
  Future<void>? _loading;

  bool get isAvailable => _interpreter != null && _mean != null && _std != null;

  Future<void> ensureLoaded() {
    if (_loaded) return Future<void>.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final scalerRaw = await rootBundle.loadString(_scalerAsset);
      final scaler = jsonDecode(scalerRaw) as Map<String, dynamic>;
      final mean = (scaler['mean'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(growable: false);
      final std = (scaler['std'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(growable: false);
      if (mean.length != _featureCount || std.length != _featureCount) {
        throw StateError('Scaler length mismatch: expected $_featureCount');
      }

      final interpreter = await Interpreter.fromAsset(_modelAsset);
      _interpreter = interpreter;
      _mean = mean;
      _std = std;
      debugPrint('[DietRecommenderModel] TFLite model loaded.');
    } catch (error) {
      // Expected before the model is trained/dropped in — heuristic takes over.
      debugPrint('[DietRecommenderModel] model unavailable, using heuristic: '
          '$error');
      _interpreter = null;
      _mean = null;
      _std = null;
    } finally {
      _loaded = true;
      _loading = null;
    }
  }

  /// Returns a 0..1 suitability score for [dish] given the user [context].
  /// Only call when [isAvailable] is true.
  double score({required PlanUserContext context, required CatalogDish dish}) {
    final interpreter = _interpreter;
    final mean = _mean;
    final std = _std;
    if (interpreter == null || mean == null || std == null) return 0.0;

    final raw = buildDishFeatures(context, dish);
    final standardized = List<double>.generate(
      _featureCount,
      (i) => std[i] == 0 ? 0.0 : (raw[i] - mean[i]) / std[i],
      growable: false,
    );

    try {
      final input = [standardized];
      final output = List<double>.filled(1, 0.0).reshape([1, 1]);
      interpreter.run(input, output);
      final value = (output[0][0] as num).toDouble();
      return value.clamp(0.0, 1.0);
    } catch (error) {
      debugPrint('[DietRecommenderModel] inference failed: $error');
      return 0.0;
    }
  }
}
