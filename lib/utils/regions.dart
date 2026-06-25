/// Countries, their states/regions, and the mapping to the "region codes" used
/// to bias diet recommendations. Region codes must stay in sync with the
/// `zones` field in `assets/database/diet_catalog.json` and the feature spec in
/// `ml/diet_recommender.ipynb`.
///
/// Matching model: a dish belongs to one `country` and is tagged with one or
/// more region codes (`zones`). The planner hard-filters by country, then
/// prefers dishes whose region matches the user's, falling back to the
/// country-wide pool. Both `panindia` (India) and `general` (other countries)
/// act as country-wide fallbacks.
class CulinaryZones {
  // India zones
  static const String north = 'north';
  static const String south = 'south';
  static const String east = 'east';
  static const String west = 'west';
  static const String central = 'central';
  static const String northeast = 'northeast';

  /// India-wide fallback pool.
  static const String panIndia = 'panindia';

  /// Country-wide fallback pool for non-India countries.
  static const String general = 'general';

  static const List<String> indiaZones = <String>[
    north,
    south,
    east,
    west,
    central,
    northeast,
  ];
}

/// Country display names (also used as the stored `UserModel.country`).
class Countries {
  static const String india = 'India';
  static const String usa = 'United States';
  static const String uk = 'United Kingdom';
  static const String australia = 'Australia';
  static const String canada = 'Canada';

  static const List<String> all = <String>[india, usa, uk, australia, canada];
}

/// Catalog `country` codes (lowercase, matches CatalogDish.country).
String countryCodeFor(String country) {
  switch (country.trim()) {
    case Countries.usa:
      return 'usa';
    case Countries.uk:
      return 'uk';
    case Countries.australia:
      return 'australia';
    case Countries.canada:
      return 'canada';
    case Countries.india:
    default:
      return 'india';
  }
}

const List<String> indianStates = <String>[
  'Andhra Pradesh',
  'Arunachal Pradesh',
  'Assam',
  'Bihar',
  'Chhattisgarh',
  'Goa',
  'Gujarat',
  'Haryana',
  'Himachal Pradesh',
  'Jharkhand',
  'Karnataka',
  'Kerala',
  'Madhya Pradesh',
  'Maharashtra',
  'Manipur',
  'Meghalaya',
  'Mizoram',
  'Nagaland',
  'Odisha',
  'Punjab',
  'Rajasthan',
  'Sikkim',
  'Tamil Nadu',
  'Telangana',
  'Tripura',
  'Uttar Pradesh',
  'Uttarakhand',
  'West Bengal',
  'Andaman and Nicobar Islands',
  'Chandigarh',
  'Dadra and Nagar Haveli and Daman and Diu',
  'Delhi',
  'Jammu and Kashmir',
  'Ladakh',
  'Lakshadweep',
  'Puducherry',
];

const List<String> usStates = <String>[
  'Alabama', 'Alaska', 'Arizona', 'Arkansas', 'California', 'Colorado',
  'Connecticut', 'Delaware', 'Florida', 'Georgia', 'Hawaii', 'Idaho',
  'Illinois', 'Indiana', 'Iowa', 'Kansas', 'Kentucky', 'Louisiana', 'Maine',
  'Maryland', 'Massachusetts', 'Michigan', 'Minnesota', 'Mississippi',
  'Missouri', 'Montana', 'Nebraska', 'Nevada', 'New Hampshire', 'New Jersey',
  'New Mexico', 'New York', 'North Carolina', 'North Dakota', 'Ohio',
  'Oklahoma', 'Oregon', 'Pennsylvania', 'Rhode Island', 'South Carolina',
  'South Dakota', 'Tennessee', 'Texas', 'Utah', 'Vermont', 'Virginia',
  'Washington', 'West Virginia', 'Wisconsin', 'Wyoming',
];

const List<String> ukRegions = <String>[
  'England', 'London', 'Scotland', 'Wales', 'Northern Ireland',
];

const List<String> australiaStates = <String>[
  'New South Wales', 'Victoria', 'Queensland', 'Western Australia',
  'South Australia', 'Tasmania', 'Australian Capital Territory',
  'Northern Territory',
];

const List<String> canadaProvinces = <String>[
  'Ontario', 'Quebec', 'British Columbia', 'Alberta', 'Manitoba',
  'Saskatchewan', 'Nova Scotia', 'New Brunswick',
  'Newfoundland and Labrador', 'Prince Edward Island', 'Yukon',
  'Northwest Territories', 'Nunavut',
];

/// States/regions to show in the picker for a given country.
List<String> statesForCountry(String country) {
  switch (country.trim()) {
    case Countries.usa:
      return usStates;
    case Countries.uk:
      return ukRegions;
    case Countries.australia:
      return australiaStates;
    case Countries.canada:
      return canadaProvinces;
    case Countries.india:
    default:
      return indianStates;
  }
}

const Map<String, String> _indiaStateToZone = <String, String>{
  // North
  'Punjab': CulinaryZones.north,
  'Haryana': CulinaryZones.north,
  'Himachal Pradesh': CulinaryZones.north,
  'Uttarakhand': CulinaryZones.north,
  'Uttar Pradesh': CulinaryZones.north,
  'Delhi': CulinaryZones.north,
  'Chandigarh': CulinaryZones.north,
  'Jammu and Kashmir': CulinaryZones.north,
  'Ladakh': CulinaryZones.north,
  // South
  'Andhra Pradesh': CulinaryZones.south,
  'Telangana': CulinaryZones.south,
  'Karnataka': CulinaryZones.south,
  'Kerala': CulinaryZones.south,
  'Tamil Nadu': CulinaryZones.south,
  'Puducherry': CulinaryZones.south,
  'Lakshadweep': CulinaryZones.south,
  'Andaman and Nicobar Islands': CulinaryZones.south,
  // East
  'Bihar': CulinaryZones.east,
  'Jharkhand': CulinaryZones.east,
  'Odisha': CulinaryZones.east,
  'West Bengal': CulinaryZones.east,
  // West
  'Goa': CulinaryZones.west,
  'Gujarat': CulinaryZones.west,
  'Maharashtra': CulinaryZones.west,
  'Rajasthan': CulinaryZones.west,
  'Dadra and Nagar Haveli and Daman and Diu': CulinaryZones.west,
  // Central
  'Madhya Pradesh': CulinaryZones.central,
  'Chhattisgarh': CulinaryZones.central,
  // Northeast
  'Arunachal Pradesh': CulinaryZones.northeast,
  'Assam': CulinaryZones.northeast,
  'Manipur': CulinaryZones.northeast,
  'Meghalaya': CulinaryZones.northeast,
  'Mizoram': CulinaryZones.northeast,
  'Nagaland': CulinaryZones.northeast,
  'Sikkim': CulinaryZones.northeast,
  'Tripura': CulinaryZones.northeast,
};

// US states with a distinct regional cuisine signature; everything else → general.
const Map<String, String> _usStateToRegion = <String, String>{
  'California': 'california',
  'Texas': 'texmex',
  'New Mexico': 'texmex',
  'Arizona': 'texmex',
  'Louisiana': 'south',
  'Georgia': 'south',
  'Alabama': 'south',
  'Mississippi': 'south',
  'Tennessee': 'south',
  'South Carolina': 'south',
  'North Carolina': 'south',
  'New York': 'northeast',
  'New Jersey': 'northeast',
  'Massachusetts': 'northeast',
  'Pennsylvania': 'northeast',
  'Illinois': 'midwest',
  'Michigan': 'midwest',
  'Ohio': 'midwest',
  'Wisconsin': 'midwest',
  'Washington': 'west',
  'Oregon': 'west',
  'Colorado': 'west',
};

const Map<String, String> _ukRegionToRegion = <String, String>{
  'Scotland': 'scotland',
};

const Map<String, String> _canadaProvinceToRegion = <String, String>{
  'Quebec': 'quebec',
};

/// Maps a (country, state) to the dish region code used for biasing. Returns an
/// empty string when unknown/unset so the planner uses the country-wide pool.
String resolveRegion(String country, String state) {
  final s = state.trim();
  switch (country.trim()) {
    case Countries.india:
      return _indiaStateToZone[s] ?? '';
    case Countries.usa:
      return _usStateToRegion[s] ?? CulinaryZones.general;
    case Countries.uk:
      return _ukRegionToRegion[s] ?? CulinaryZones.general;
    case Countries.canada:
      return _canadaProvinceToRegion[s] ?? CulinaryZones.general;
    case Countries.australia:
      return CulinaryZones.general;
    default:
      // Unknown country: treat as India for backward compatibility.
      return _indiaStateToZone[s] ?? '';
  }
}

/// Back-compat shim: India-only state→zone used before countries existed.
String stateToZone(String state) => _indiaStateToZone[state.trim()] ?? '';
