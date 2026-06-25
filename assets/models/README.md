# Diet recommender model assets

This folder holds the **optional** on-device TFLite diet recommender. The app works without it
(it falls back to the heuristic scorer in `lib/services/diet_plan_service.dart`); dropping the
trained model in here automatically upgrades recommendations to the ML-ranked version.

## How to generate the model

1. Open `ml/diet_recommender.ipynb` in Google Colab (Runtime → Change runtime type → GPU).
2. Run all cells. The notebook loads `assets/database/diet_catalog.json`, synthesizes labeled
   training data, trains a small Keras MLP, and exports two files.
3. Download and place them **here**, with these exact names:
   - `diet_recommender.tflite`
   - `feature_scaler.json`

## Contract (must stay in sync)

`feature_scaler.json` is `{ "mean": [...16], "std": [...16] }`. The 16-feature order and formulas
are defined once in `buildDishFeatures()` (`lib/services/diet_recommender_model.dart`) and mirrored
in the notebook. If you change features in one place, change both — otherwise inference silently
diverges from training.

The model takes a `[1, 16]` float32 standardized feature vector and outputs a `[1, 1]` suitability
score in `0..1`.
