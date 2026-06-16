class DietaryPreferenceCodes {
  static const String vegetarian = 'veg';
  static const String mixed = 'mixed';
  static const String nonVegOnly = 'nonveg';
}

typedef DietaryPreferenceOption = ({
  String code,
  String label,
  String description,
});

const List<DietaryPreferenceOption>
dietaryPreferenceOptions = <DietaryPreferenceOption>[
  (
    code: DietaryPreferenceCodes.vegetarian,
    label: 'Vegetarian',
    description: 'Only vegetarian foods and plant-based protein options.',
  ),
  (
    code: DietaryPreferenceCodes.mixed,
    label: 'Veg + Non-Veg',
    description:
        'Mostly balanced meals with vegetarian foods and non-veg options mixed in.',
  ),
  (
    code: DietaryPreferenceCodes.nonVegOnly,
    label: 'Only Non-Veg',
    description: 'Meals can be built entirely around non-vegetarian foods.',
  ),
];

String normalizeDietaryPreference(String preference) {
  final normalized = preference.trim().toLowerCase();
  switch (normalized) {
    case '':
    case 'any':
    case 'mixed':
    case 'both':
    case 'veg_nonveg':
    case 'omnivore':
      return DietaryPreferenceCodes.mixed;
    case 'veg':
    case 'vegetarian':
      return DietaryPreferenceCodes.vegetarian;
    case 'nonveg':
    case 'non-veg':
    case 'non veg':
    case 'nonvegetarian':
    case 'non-vegetarian':
    case 'only nonveg':
    case 'only non-veg':
      return DietaryPreferenceCodes.nonVegOnly;
    default:
      return DietaryPreferenceCodes.mixed;
  }
}

String dietaryPreferenceLabel(String preference) {
  switch (normalizeDietaryPreference(preference)) {
    case DietaryPreferenceCodes.vegetarian:
      return 'Vegetarian';
    case DietaryPreferenceCodes.nonVegOnly:
      return 'Only Non-Veg';
    default:
      return 'Veg + Non-Veg';
  }
}

bool isNonVegFoodName(String foodName) {
  final normalized = foodName.toLowerCase();
  return _nonVegKeywords.any(normalized.contains);
}

bool matchesDietaryPreferenceName(String foodName, String preference) {
  final normalizedPreference = normalizeDietaryPreference(preference);
  final isNonVeg = isNonVegFoodName(foodName);

  if (normalizedPreference == DietaryPreferenceCodes.vegetarian) {
    return !isNonVeg;
  }
  if (normalizedPreference == DietaryPreferenceCodes.nonVegOnly) {
    return isNonVeg;
  }
  return true;
}

const List<String> _nonVegKeywords = <String>[
  'chicken',
  'mutton',
  'fish',
  'prawn',
  'egg',
  'beef',
  'pork',
  'meat',
  'tuna',
  'sardine',
  'crab',
  'liver',
  'bacon',
  'sausage',
  'salami',
  'keema',
  'kebab',
];
