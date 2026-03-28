import 'dart:convert';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:xml/xml.dart';

import '../models/nutrition_models.dart';
import '../models/user_model.dart';

class NutritionService {
  NutritionService._();

  static final NutritionService instance = NutritionService._();

  static const String _dbName = 'nutrition.db';
  static const String _datasetVersion = '2026-03-25-v4-local';
  static const List<String> _knownDatabaseAssets = <String>[
    'assets/database/Indian food nutrients.xlsx',
    'assets/database/indian_food_nutrients.xlsx',
    'assets/database/foods.csv',
    'assets/database/food.csv',
  ];

  static const List<String> _nutrientColumns = <String>[
    'caloric_value',
    'fat',
    'saturated_fats',
    'monounsaturated_fats',
    'polyunsaturated_fats',
    'carbohydrates',
    'sugars',
    'protein',
    'dietary_fiber',
    'cholesterol',
    'sodium',
    'water',
    'vitamin_a',
    'vitamin_b1',
    'vitamin_b11',
    'vitamin_b12',
    'vitamin_b2',
    'vitamin_b3',
    'vitamin_b5',
    'vitamin_b6',
    'vitamin_c',
    'vitamin_d',
    'vitamin_e',
    'vitamin_k',
    'calcium',
    'copper',
    'iron',
    'magnesium',
    'manganese',
    'phosphorus',
    'potassium',
    'selenium',
    'zinc',
    'nutrition_density',
  ];

  static const List<String> _vitaminColumns = <String>[
    'vitamin_a',
    'vitamin_b1',
    'vitamin_b11',
    'vitamin_b2',
    'vitamin_b3',
    'vitamin_b5',
    'vitamin_b6',
    'vitamin_c',
    'vitamin_d',
    'vitamin_e',
    'vitamin_k',
  ];

  static const Map<String, String> _columnDisplay = <String, String>{
    'caloric_value': 'Calories',
    'protein': 'Protein',
    'carbohydrates': 'Carbs',
    'fat': 'Fat',
    'dietary_fiber': 'Fiber',
    'vitamin_a': 'Vitamin A',
    'vitamin_b1': 'Vitamin B1',
    'vitamin_b11': 'Folate',
    'vitamin_b2': 'Vitamin B2',
    'vitamin_b3': 'Vitamin B3',
    'vitamin_b5': 'Vitamin B5',
    'vitamin_b6': 'Vitamin B6',
    'vitamin_c': 'Vitamin C',
    'vitamin_d': 'Vitamin D',
    'vitamin_e': 'Vitamin E',
    'vitamin_k': 'Vitamin K',
    'calcium': 'Calcium',
    'iron': 'Iron',
    'magnesium': 'Magnesium',
    'potassium': 'Potassium',
    'zinc': 'Zinc',
  };

  Database? _db;
  Future<void>? _initFuture;
  List<FoodItem>? _foodCache;

  static const Map<String, List<String>> _synonyms = <String, List<String>>{
    'curd': <String>['yogurt', 'dahi'],
    'yogurt': <String>['curd', 'dahi'],
    'dahi': <String>['curd', 'yogurt'],
    'roti': <String>['chapati', 'phulka'],
    'chapati': <String>['roti', 'phulka'],
    'rice': <String>['biryani', 'pulao'],
    'idly': <String>['idli'],
    'idli': <String>['idly'],
    'dosai': <String>['dosa'],
  };

  Future<void> initialize() async {
    _initFuture ??= _initializeInternal();
    await _initFuture;
  }

  Future<void> _initializeInternal() async {
    final db = await _openDb();
    await _ensureImported(db);
  }

  Future<List<FoodItem>> searchFoods(String query, {int limit = 20}) async {
    return searchFoodsAdvanced(query, limit: limit);
  }

  Future<List<FoodItem>> searchFoodsAdvanced(
    String query, {
    int limit = 30,
  }) async {
    await initialize();
    final q = _normalize(query);
    if (q.isEmpty) return const <FoodItem>[];

    var foods = await _getAllFoodsCached();
    if (foods.isEmpty) {
      await _forceReimportFoods();
      foods = await _getAllFoodsCached();
    }
    if (foods.isEmpty) return const <FoodItem>[];

    final expandedQueries = _expandQuery(q);
    final scored = <_RankedFood>[];

    for (final food in foods) {
      final name = _normalize(food.foodName);
      final nameTokens = name.split(' ').where((t) => t.isNotEmpty).toList();
      if (nameTokens.isEmpty) continue;

      var bestScore = -9999.0;
      for (final candidateQuery in expandedQueries) {
        var score = 0.0;
        final queryTokens = candidateQuery
            .split(' ')
            .where((t) => t.isNotEmpty)
            .toList();

        // 1) Exact match
        if (name == candidateQuery) score += 100;

        // 2) Prefix match
        if (name.startsWith(candidateQuery)) score += 55;

        // 3) Substring match
        if (name.contains(candidateQuery)) score += 34;

        // 4) Word-level prefix match
        if (nameTokens.any((w) => w.startsWith(candidateQuery))) {
          score += 44;
        }

        // 5) Multi-word token coverage
        if (queryTokens.isNotEmpty) {
          final matchedTokens = queryTokens
              .where(
                (qt) => nameTokens.any(
                  (nt) => nt.contains(qt) || nt.startsWith(qt),
                ),
              )
              .length;
          score += (matchedTokens / queryTokens.length) * 42.0;
        }

        // 6) Fuzzy score against whole name and nearest token
        final distName = _levenshtein(candidateQuery, name);
        final simName = _similarity(candidateQuery, name, distName);
        score += simName * 24.0;

        final tokenBestSim = queryTokens.isEmpty
            ? 0.0
            : queryTokens
                      .map((qt) {
                        var best = 0.0;
                        for (final nt in nameTokens) {
                          final d = _levenshtein(qt, nt);
                          final s = _similarity(qt, nt, d);
                          if (s > best) best = s;
                        }
                        return best;
                      })
                      .fold<double>(0.0, (a, b) => a + b) /
                  queryTokens.length;
        score += tokenBestSim * 26.0;

        // 7) Prefer concise names slightly
        score -= name.length * 0.08;

        if (score > bestScore) bestScore = score;
      }

      if (bestScore > 10) {
        scored.add(_RankedFood(food: food, score: bestScore));
      }
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.food.foodName.compareTo(b.food.foodName);
    });

    return scored.take(limit).map((e) => e.food).toList();
  }

  Future<List<FoodItem>> getAllFoodsForPlanning() async {
    await initialize();
    final all = await _getAllFoodsCached();
    return all
        .where((f) => f.calories > 1 && f.foodName.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<void> addMealEntry({
    required String userId,
    required DateTime date,
    required MealType mealType,
    required int foodId,
    required double quantityGrams,
  }) async {
    final db = await _openDb();
    await db.insert('meal_entries', <String, Object?>{
      'user_id': userId,
      'meal_date': _dateKey(date),
      'meal_type': mealType.dbValue,
      'food_id': foodId,
      'quantity_grams': quantityGrams,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> deleteMealEntry({
    required String userId,
    required String entryId,
  }) async {
    final db = await _openDb();
    final id = int.tryParse(entryId);
    if (id == null) return;
    await db.delete(
      'meal_entries',
      where: 'id = ? AND user_id = ?',
      whereArgs: <Object>[id, userId],
    );
  }

  Future<DailyNutritionSummary> getDailySummary({
    required String userId,
    required DateTime date,
    required UserModel user,
  }) async {
    final db = await _openDb();
    final day = _dateKey(date);
    final rows = await db.rawQuery(
      '''
      SELECT
        me.id AS entry_id,
        me.user_id,
        me.meal_date,
        me.meal_type,
        me.food_id,
        me.quantity_grams,
        f.*
      FROM meal_entries me
      JOIN foods f ON f.id = me.food_id
      WHERE me.user_id = ? AND me.meal_date = ?
      ORDER BY me.created_at DESC, me.id DESC;
      ''',
      <Object>[userId, day],
    );

    final entries = rows.map(_mealEntryFromRow).toList();
    final totals = _computeTotals(entries);
    final targets = _dailyTargets(user);
    final gaps = await _calculateGaps(
      totals: totals,
      targets: targets,
      topN: 5,
    );

    return DailyNutritionSummary(
      date: DateTime(date.year, date.month, date.day),
      entries: entries,
      totals: totals,
      targets: targets,
      gaps: gaps,
    );
  }

  Future<MonthlyNutritionSummary> getMonthlySummary({
    required String userId,
    required DateTime month,
    required UserModel user,
  }) async {
    final db = await _openDb();
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 1);
    final daysInMonth = monthEnd.difference(monthStart).inDays;

    final rows = await db.rawQuery(
      '''
      SELECT
        me.id AS entry_id,
        me.user_id,
        me.meal_date,
        me.meal_type,
        me.food_id,
        me.quantity_grams,
        f.*
      FROM meal_entries me
      JOIN foods f ON f.id = me.food_id
      WHERE me.user_id = ? AND me.meal_date >= ? AND me.meal_date < ?;
      ''',
      <Object>[userId, _dateKey(monthStart), _dateKey(monthEnd)],
    );

    final entries = rows.map(_mealEntryFromRow).toList();
    final totals = _computeTotals(entries);
    final dailyTargets = _dailyTargets(user);
    final targetTotals = <String, double>{
      for (final entry in dailyTargets.entries)
        entry.key: entry.value * daysInMonth,
    };
    final gaps = await _calculateGaps(
      totals: totals,
      targets: targetTotals,
      topN: 6,
    );

    return MonthlyNutritionSummary(
      month: monthStart,
      daysInMonth: daysInMonth,
      totals: totals,
      targetTotals: targetTotals,
      caloriesPercent: _percent(
        totals['caloric_value'] ?? 0,
        targetTotals['caloric_value'] ?? 0,
      ),
      proteinPercent: _percent(
        totals['protein'] ?? 0,
        targetTotals['protein'] ?? 0,
      ),
      vitaminsPercent: _vitaminPercent(
        totals: totals,
        targetTotals: targetTotals,
      ),
      gaps: gaps,
    );
  }

  String displayName(String nutrientColumn) =>
      _columnDisplay[nutrientColumn] ?? nutrientColumn;

  MealEntry _mealEntryFromRow(Map<String, Object?> row) {
    final date = _parseDate((row['meal_date'] as String?) ?? '');
    final mealTypeRaw =
        row['meal_type'] as String? ?? MealType.breakfast.dbValue;
    final mealType = MealType.values.firstWhere(
      (t) => t.dbValue == mealTypeRaw,
      orElse: () => MealType.breakfast,
    );
    return MealEntry(
      id: '${row['entry_id']}',
      userId: row['user_id'] as String,
      date: date,
      mealType: mealType,
      food: _foodFromRow(row),
      quantityGrams: _numObj(row['quantity_grams']),
    );
  }

  Future<Database> _openDb() async {
    if (_db != null) return _db!;
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, _dbName);
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, _) async => _createSchema(db),
    );
    return _db!;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS foods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        food_name TEXT NOT NULL,
        food_normalized TEXT NOT NULL UNIQUE,
        caloric_value REAL NOT NULL,
        fat REAL NOT NULL,
        saturated_fats REAL NOT NULL,
        monounsaturated_fats REAL NOT NULL,
        polyunsaturated_fats REAL NOT NULL,
        carbohydrates REAL NOT NULL,
        sugars REAL NOT NULL,
        protein REAL NOT NULL,
        dietary_fiber REAL NOT NULL,
        cholesterol REAL NOT NULL,
        sodium REAL NOT NULL,
        water REAL NOT NULL,
        vitamin_a REAL NOT NULL,
        vitamin_b1 REAL NOT NULL,
        vitamin_b11 REAL NOT NULL,
        vitamin_b12 REAL NOT NULL,
        vitamin_b2 REAL NOT NULL,
        vitamin_b3 REAL NOT NULL,
        vitamin_b5 REAL NOT NULL,
        vitamin_b6 REAL NOT NULL,
        vitamin_c REAL NOT NULL,
        vitamin_d REAL NOT NULL,
        vitamin_e REAL NOT NULL,
        vitamin_k REAL NOT NULL,
        calcium REAL NOT NULL,
        copper REAL NOT NULL,
        iron REAL NOT NULL,
        magnesium REAL NOT NULL,
        manganese REAL NOT NULL,
        phosphorus REAL NOT NULL,
        potassium REAL NOT NULL,
        selenium REAL NOT NULL,
        zinc REAL NOT NULL,
        nutrition_density REAL NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS meal_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        meal_date TEXT NOT NULL,
        meal_type TEXT NOT NULL,
        food_id INTEGER NOT NULL,
        quantity_grams REAL NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY(food_id) REFERENCES foods(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_food_name_norm ON foods(food_normalized);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_meal_user_date ON meal_entries(user_id, meal_date);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_meal_food ON meal_entries(food_id);',
    );
  }

  Future<void> _ensureImported(Database db) async {
    final countRows = await db.rawQuery('SELECT COUNT(*) AS c FROM foods;');
    final foodsCount = _numObj(countRows.first['c']).toInt();

    final meta = await db.query(
      'meta',
      columns: <String>['value'],
      where: 'key = ?',
      whereArgs: <Object>['dataset_version'],
      limit: 1,
    );
    final hasLatestVersion =
        meta.isNotEmpty && meta.first['value'] == _datasetVersion;
    if (hasLatestVersion && foodsCount > 0) return;

    final assets = await _discoverDataAssets();
    if (assets.isEmpty) {
      debugPrint('No database assets discovered for nutrition import.');
      return;
    }

    await db.transaction((txn) async {
      await txn.delete('foods');
      var inserted = 0;
      for (final asset in assets) {
        final rows = asset.toLowerCase().endsWith('.csv')
            ? await _readCsvAsset(asset)
            : await _readXlsxAsset(asset);
        inserted += await _importRows(txn, rows);
      }
      if (inserted <= 0) {
        debugPrint('Nutrition import produced 0 rows. Assets: $assets');
        return;
      }
      await txn.insert('meta', <String, Object?>{
        'key': 'dataset_version',
        'value': _datasetVersion,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    _foodCache = null;
  }

  Future<List<String>> _discoverDataAssets() async {
    final discovered = <String>{};

    try {
      final manifestRaw = await rootBundle.loadString('AssetManifest.json');
      final manifest = jsonDecode(manifestRaw) as Map<String, dynamic>;
      discovered.addAll(
        manifest.keys
            .where((key) => key.startsWith('assets/database/'))
            .where(
              (key) =>
                  key.toLowerCase().endsWith('.csv') ||
                  key.toLowerCase().endsWith('.xlsx'),
            ),
      );
    } catch (_) {
      // Ignore and use known-file fallback below.
    }

    for (final asset in _knownDatabaseAssets) {
      try {
        await rootBundle.load(asset);
        discovered.add(asset);
      } catch (_) {
        // Not present in this build.
      }
    }

    final assets = discovered.toList()..sort();
    return assets;
  }

  Future<List<Map<String, String>>> _readCsvAsset(String asset) async {
    final csvText = await rootBundle.loadString(asset);
    final rows = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(csvText);
    if (rows.isEmpty) return const <Map<String, String>>[];
    final header = rows.first.map((h) => (h ?? '').toString()).toList();
    final out = <Map<String, String>>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final map = <String, String>{};
      for (var c = 0; c < header.length; c++) {
        if (c < row.length) {
          map[_normalizeHeader(header[c])] = (row[c] ?? '').toString();
        }
      }
      out.add(map);
    }
    return out;
  }

  Future<List<Map<String, String>>> _readXlsxAsset(String asset) async {
    final byteData = await rootBundle.load(asset);
    final bytes = Uint8List.view(
      byteData.buffer,
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
    final archive = ZipDecoder().decodeBytes(bytes);

    String? sharedStringsXml;
    String? sheetXml;
    for (final file in archive.files) {
      if (file.name == 'xl/sharedStrings.xml') {
        sharedStringsXml = utf8.decode(file.content as List<int>);
      } else if (file.name == 'xl/worksheets/sheet1.xml') {
        sheetXml = utf8.decode(file.content as List<int>);
      }
    }
    if (sheetXml == null) return const <Map<String, String>>[];

    final sharedStrings = <String>[];
    if (sharedStringsXml != null) {
      final sharedDoc = XmlDocument.parse(sharedStringsXml);
      for (final si in _descendantsByLocalName(sharedDoc, 'si')) {
        sharedStrings.add(
          _descendantsByLocalName(si, 't').map((e) => e.innerText).join(),
        );
      }
    }

    final sheetDoc = XmlDocument.parse(sheetXml);
    final rows = _descendantsByLocalName(sheetDoc, 'row').toList();
    if (rows.isEmpty) return const <Map<String, String>>[];

    List<String> header = const <String>[];
    final out = <Map<String, String>>[];
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      final valuesByCol = <int, String>{};
      for (final cell in _childrenByLocalName(row, 'c')) {
        final ref = cell.getAttribute('r') ?? '';
        final col = _cellRefToColIndex(ref);
        if (col >= 0) {
          valuesByCol[col] = _xlsxCellValue(cell, sharedStrings);
        }
      }

      final width = valuesByCol.keys.isEmpty
          ? 0
          : valuesByCol.keys.reduce(max) + 1;
      final rowValues = List<String>.filled(width, '');
      for (final entry in valuesByCol.entries) {
        rowValues[entry.key] = entry.value;
      }

      if (rowIndex == 0) {
        header = rowValues;
      } else {
        final map = <String, String>{};
        for (var c = 0; c < header.length; c++) {
          final key = _normalizeHeader(header[c]);
          if (key.isNotEmpty) {
            map[key] = c < rowValues.length ? rowValues[c] : '';
          }
        }
        out.add(map);
      }
    }
    return out;
  }

  int _cellRefToColIndex(String ref) {
    if (ref.isEmpty) return -1;
    final letters = ref.replaceAll(RegExp(r'[^A-Z]'), '');
    if (letters.isEmpty) return -1;
    var col = 0;
    for (var i = 0; i < letters.length; i++) {
      col = (col * 26) + (letters.codeUnitAt(i) - 64);
    }
    return col - 1;
  }

  String _xlsxCellValue(XmlElement cell, List<String> sharedStrings) {
    final type = cell.getAttribute('t');
    if (type == 'inlineStr') {
      final t = _firstOrNull(
        _childrenByLocalName(
          cell,
          'is',
        ).expand((isNode) => _childrenByLocalName(isNode, 't')),
      );
      return t?.innerText ?? '';
    }
    final valueNode = _firstOrNull(_childrenByLocalName(cell, 'v'));
    if (valueNode == null) return '';
    final raw = valueNode.innerText;
    if (type == 's') {
      final idx = int.tryParse(raw) ?? -1;
      return (idx >= 0 && idx < sharedStrings.length) ? sharedStrings[idx] : '';
    }
    return raw;
  }

  T? _firstOrNull<T>(Iterable<T> items) {
    for (final item in items) {
      return item;
    }
    return null;
  }

  Iterable<XmlElement> _descendantsByLocalName(XmlNode node, String localName) {
    return node.descendants.whereType<XmlElement>().where(
      (e) => e.name.local == localName,
    );
  }

  Iterable<XmlElement> _childrenByLocalName(XmlNode node, String localName) {
    return node.children.whereType<XmlElement>().where(
      (e) => e.name.local == localName,
    );
  }

  Future<int> _importRows(
    Transaction txn,
    List<Map<String, String>> rows,
  ) async {
    var inserted = 0;
    for (final row in rows) {
      final foodName = _pick(row, <String>['food_name', 'food']);
      final normalizedFood = _normalize(foodName);
      if (normalizedFood.isEmpty) continue;

      final payload = <String, Object?>{
        'food_name': foodName.trim(),
        'food_normalized': normalizedFood,
      };
      for (final nutrient in _nutrientColumns) {
        payload[nutrient] = _nutrientValue(nutrient, row);
      }
      await txn.insert(
        'foods',
        payload,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      inserted++;
    }
    return inserted;
  }

  Future<void> _forceReimportFoods() async {
    final db = await _openDb();
    final assets = await _discoverDataAssets();
    if (assets.isEmpty) return;

    await db.transaction((txn) async {
      await txn.delete('foods');
      await txn.delete(
        'meta',
        where: 'key = ?',
        whereArgs: <Object>['dataset_version'],
      );
      var inserted = 0;
      for (final asset in assets) {
        final rows = asset.toLowerCase().endsWith('.csv')
            ? await _readCsvAsset(asset)
            : await _readXlsxAsset(asset);
        inserted += await _importRows(txn, rows);
      }
      if (inserted > 0) {
        await txn.insert('meta', <String, Object?>{
          'key': 'dataset_version',
          'value': _datasetVersion,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });

    _foodCache = null;
  }

  double _nutrientValue(String nutrient, Map<String, String> row) {
    switch (nutrient) {
      case 'caloric_value':
        return _num(_pick(row, <String>['energy_kcal', 'caloricvalue']));
      case 'fat':
        return _num(_pick(row, <String>['fat_g', 'fat']));
      case 'saturated_fats':
        return _num(_pick(row, <String>['sfa_mg', 'saturatedfats']));
      case 'monounsaturated_fats':
        return _num(_pick(row, <String>['mufa_mg', 'monounsaturatedfats']));
      case 'polyunsaturated_fats':
        return _num(_pick(row, <String>['pufa_mg', 'polyunsaturatedfats']));
      case 'carbohydrates':
        return _num(_pick(row, <String>['carb_g', 'carbohydrates']));
      case 'sugars':
        return _num(_pick(row, <String>['freesugar_g', 'sugars']));
      case 'protein':
        return _num(_pick(row, <String>['protein_g', 'protein']));
      case 'dietary_fiber':
        return _num(_pick(row, <String>['fibre_g', 'dietaryfiber']));
      case 'cholesterol':
        return _num(_pick(row, <String>['cholesterol_mg', 'cholesterol']));
      case 'sodium':
        return _num(_pick(row, <String>['sodium_mg', 'sodium']));
      case 'water':
        return 0;
      case 'vitamin_a':
        return _num(_pick(row, <String>['vita_ug', 'vitamina']));
      case 'vitamin_b1':
        return _num(_pick(row, <String>['vitb1_mg', 'vitaminb1']));
      case 'vitamin_b11':
        return _num(
          _pick(row, <String>['folate_ug', 'vitb9_ug', 'vitaminb11']),
        );
      case 'vitamin_b12':
        return _num(_pick(row, <String>['vitaminb12']));
      case 'vitamin_b2':
        return _num(_pick(row, <String>['vitb2_mg', 'vitaminb2']));
      case 'vitamin_b3':
        return _num(_pick(row, <String>['vitb3_mg', 'vitaminb3']));
      case 'vitamin_b5':
        return _num(_pick(row, <String>['vitb5_mg', 'vitaminb5']));
      case 'vitamin_b6':
        return _num(_pick(row, <String>['vitb6_mg', 'vitaminb6']));
      case 'vitamin_c':
        return _num(_pick(row, <String>['vitc_mg', 'vitaminc']));
      case 'vitamin_d':
        return _num(_pick(row, <String>['vitd2_ug'])) +
            _num(_pick(row, <String>['vitd3_ug']));
      case 'vitamin_e':
        return _num(_pick(row, <String>['vite_mg', 'vitamine']));
      case 'vitamin_k':
        return _num(_pick(row, <String>['vitk1_ug'])) +
            _num(_pick(row, <String>['vitk2_ug']));
      case 'calcium':
        return _num(_pick(row, <String>['calcium_mg', 'calcium']));
      case 'copper':
        return _num(_pick(row, <String>['copper_mg', 'copper']));
      case 'iron':
        return _num(_pick(row, <String>['iron_mg', 'iron']));
      case 'magnesium':
        return _num(_pick(row, <String>['magnesium_mg', 'magnesium']));
      case 'manganese':
        return _num(_pick(row, <String>['manganese_mg', 'manganese']));
      case 'phosphorus':
        return _num(_pick(row, <String>['phosphorus_mg', 'phosphorus']));
      case 'potassium':
        return _num(_pick(row, <String>['potassium_mg', 'potassium']));
      case 'selenium':
        return _num(_pick(row, <String>['selenium_ug', 'selenium']));
      case 'zinc':
        return _num(_pick(row, <String>['zinc_mg', 'zinc']));
      case 'nutrition_density':
        final protein = _num(_pick(row, <String>['protein_g', 'protein']));
        final fiber = _num(_pick(row, <String>['fibre_g', 'dietaryfiber']));
        final kcal = _num(_pick(row, <String>['energy_kcal', 'caloricvalue']));
        return kcal <= 0 ? 0 : ((protein * 4) + (fiber * 2)) / kcal * 100;
      default:
        return 0;
    }
  }

  FoodItem _foodFromRow(Map<String, Object?> row) {
    final nutrients = <String, double>{
      for (final nutrient in _nutrientColumns) nutrient: _numObj(row[nutrient]),
    };
    return FoodItem(
      id: row['id'] as int,
      foodName: (row['food_name'] as String?) ?? '',
      calories: nutrients['caloric_value'] ?? 0,
      protein: nutrients['protein'] ?? 0,
      carbs: nutrients['carbohydrates'] ?? 0,
      fat: nutrients['fat'] ?? 0,
      nutrients: nutrients,
    );
  }

  Map<String, double> _computeTotals(List<MealEntry> entries) {
    final totals = <String, double>{
      for (final nutrient in _nutrientColumns) nutrient: 0,
    };
    for (final entry in entries) {
      final ratio = entry.quantityGrams / 100.0;
      for (final nutrient in _nutrientColumns) {
        totals[nutrient] =
            (totals[nutrient] ?? 0) +
            ((entry.food.nutrients[nutrient] ?? 0) * ratio);
      }
    }
    return totals;
  }

  Map<String, double> _dailyTargets(UserModel user) {
    final goal = user.fitnessGoal.toLowerCase();
    final isMale = user.gender.toLowerCase() == 'male';
    final weight = user.weight <= 0 ? 70.0 : user.weight;
    final height = user.height <= 0 ? 170.0 : user.height;
    final age = user.age <= 0 ? 25 : user.age;

    final bmr = isMale
        ? (10 * weight) + (6.25 * height) - (5 * age) + 5
        : (10 * weight) + (6.25 * height) - (5 * age) - 161;
    final sitting = user.sittingHours.toLowerCase();
    double activityMultiplier = 1.375;
    if (sitting.contains('8') || (sitting.contains('6') && user.workoutDays <= 2)) {
      activityMultiplier = 1.2;
    } else if (user.workoutDays >= 5) {
      activityMultiplier = 1.725;
    } else if (user.workoutDays >= 3) {
      activityMultiplier = 1.55;
    }

    var calories = bmr * activityMultiplier;
    if (goal == 'lose weight') calories -= 400;
    if (goal == 'gain muscle') calories += 250;
    if (goal == 'improve stamina') calories += 150;
    calories = calories.clamp(isMale ? 1500.0 : 1200.0, 4200.0);

    final proteinMultiplier = goal == 'gain muscle' ? 2.0 : 1.7;
    final protein = max(60.0, weight * proteinMultiplier);
    final fat = (calories * (goal == 'lose weight' ? 0.25 : 0.28)) / 9.0;
    final carbs = max(120.0, (calories - (protein * 4) - (fat * 9)) / 4);
    return <String, double>{
      'caloric_value': calories,
      'protein': protein,
      'carbohydrates': carbs,
      'fat': fat,
      'dietary_fiber': 30,
      'vitamin_a': 900,
      'vitamin_b1': 1.2,
      'vitamin_b11': 400,
      'vitamin_b2': 1.3,
      'vitamin_b3': 16,
      'vitamin_b5': 5,
      'vitamin_b6': 1.3,
      'vitamin_c': 90,
      'vitamin_d': 15,
      'vitamin_e': 15,
      'vitamin_k': 120,
      'calcium': 1000,
      'iron': isMale ? 8 : 18,
      'magnesium': isMale ? 420 : 320,
      'potassium': 3400,
      'zinc': isMale ? 11 : 8,
    };
  }

  Future<List<NutrientGap>> _calculateGaps({
    required Map<String, double> totals,
    required Map<String, double> targets,
    required int topN,
  }) async {
    final db = await _openDb();
    final gaps = <NutrientGap>[];
    final sorted = targets.keys.toList()
      ..sort((a, b) {
        final pa = _percent(totals[a] ?? 0, targets[a] ?? 0);
        final pb = _percent(totals[b] ?? 0, targets[b] ?? 0);
        return pa.compareTo(pb);
      });

    for (final nutrient in sorted.take(topN)) {
      final consumed = totals[nutrient] ?? 0;
      final target = targets[nutrient] ?? 0;
      final pct = _percent(consumed, target);
      if (pct >= 100) continue;
      final rows = await db.query(
        'foods',
        columns: <String>['id', 'food_name', ..._nutrientColumns],
        orderBy: '$nutrient DESC, nutrition_density DESC',
        limit: 3,
      );
      gaps.add(
        NutrientGap(
          nutrient: nutrient,
          consumed: consumed,
          target: target,
          percent: pct,
          suggestions: rows.map(_foodFromRow).toList(),
        ),
      );
    }
    return gaps;
  }

  String _pick(Map<String, String> row, List<String> keys) {
    for (final key in keys) {
      final found = row[_normalizeHeader(key)];
      if (found != null && found.trim().isNotEmpty) return found.trim();
    }
    return '0';
  }

  String _normalizeHeader(String value) {
    var v = value.toLowerCase().trim();
    if (v.startsWith('unnamed')) return '';
    return v.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _normalize(String value) {
    var v = value.toLowerCase().trim();
    v = v.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    v = v.replaceAll(RegExp(r'\s+'), ' ');
    return v;
  }

  List<String> _expandQuery(String q) {
    final expanded = <String>{q};
    final tokens = q.split(' ').where((t) => t.isNotEmpty).toList();
    for (final token in tokens) {
      final syns = _synonyms[token];
      if (syns == null) continue;
      for (final syn in syns) {
        expanded.add(q.replaceFirst(token, syn));
      }
    }
    return expanded.toList();
  }

  double _similarity(String a, String b, int distance) {
    final denom = max(a.length, b.length);
    if (denom == 0) return 0;
    return 1.0 - (distance / denom);
  }

  DateTime _parseDate(String ymd) {
    final parts = ymd.split('-');
    if (parts.length != 3) return DateTime.now();
    return DateTime(
      int.tryParse(parts[0]) ?? DateTime.now().year,
      int.tryParse(parts[1]) ?? DateTime.now().month,
      int.tryParse(parts[2]) ?? DateTime.now().day,
    );
  }

  String _dateKey(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  double _num(String value) => double.tryParse(value.trim()) ?? 0;
  double _numObj(Object? value) => double.tryParse('${value ?? ''}') ?? 0;

  double _percent(double value, double target) {
    if (target <= 0) return 0;
    return (value / target) * 100;
  }

  double _vitaminPercent({
    required Map<String, double> totals,
    required Map<String, double> targetTotals,
  }) {
    final valid = _vitaminColumns
        .where((v) => (targetTotals[v] ?? 0) > 0)
        .toList();
    if (valid.isEmpty) return 0;
    final sum = valid.fold<double>(
      0,
      (acc, v) => acc + _percent(totals[v] ?? 0, targetTotals[v] ?? 0),
    );
    return sum / valid.length;
  }

  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final costs = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      var prev = i - 1;
      costs[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final temp = costs[j];
        final substitution = a[i - 1] == b[j - 1] ? 0 : 1;
        costs[j] = min(
          min(costs[j] + 1, costs[j - 1] + 1),
          prev + substitution,
        );
        prev = temp;
      }
    }
    return costs[b.length];
  }

  Future<List<FoodItem>> _getAllFoodsCached() async {
    if (_foodCache != null && _foodCache!.isNotEmpty) return _foodCache!;
    final db = await _openDb();
    final rows = await db.query(
      'foods',
      columns: <String>['id', 'food_name', ..._nutrientColumns],
    );
    _foodCache = rows.map(_foodFromRow).toList();
    return _foodCache!;
  }
}

class _RankedFood {
  final FoodItem food;
  final double score;

  const _RankedFood({required this.food, required this.score});
}
