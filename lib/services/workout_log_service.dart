import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/workout_log_models.dart';

/// Cloud (Firestore) store for logged workout sets, keyed per user, so history
/// survives reinstalls and syncs across devices. Firestore's offline cache
/// keeps logging instant and available without a connection.
///
/// Logs live at `users/{uid}/workoutLogs/{deterministicId}`.
class WorkoutLogService {
  WorkoutLogService._();
  static final WorkoutLogService instance = WorkoutLogService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String userId) =>
      _db.collection('users').doc(userId).collection('workoutLogs');

  String _docId(WorkoutSetLog log) =>
      '${log.timestampMillis}_${log.exerciseKey}_${log.setNumber}';

  Future<List<WorkoutSetLog>> all(String userId) async {
    if (userId.isEmpty) return const <WorkoutSetLog>[];
    await _migrateLocalLogsIfNeeded(userId);
    try {
      final snapshot = await _collection(
        userId,
      ).orderBy('timestampMillis').get();
      return snapshot.docs
          .map((doc) => WorkoutSetLog.fromJson(doc.data()))
          .toList(growable: false);
    } catch (error) {
      debugPrint('Workout log fetch failed: $error');
      return const <WorkoutSetLog>[];
    }
  }

  Future<void> add(String userId, WorkoutSetLog log) async {
    if (userId.isEmpty) return;
    // Do not await network round-trip: Firestore writes to its local cache
    // immediately and syncs to the server in the background.
    unawaited(
      _collection(userId)
          .doc(_docId(log))
          .set(log.toJson())
          .catchError((Object error) {
            debugPrint('Workout log write failed: $error');
          }),
    );
  }

  Future<void> clear(String userId) async {
    if (userId.isEmpty) return;
    final snapshot = await _collection(userId).get();
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// One-time migration of any logs from the previous SharedPreferences store.
  Future<void> _migrateLocalLogsIfNeeded(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final migratedKey = 'workout_logs_migrated_$userId';
    if (prefs.getBool(migratedKey) == true) return;

    final legacyRaw = prefs.getString('workout_logs_$userId');
    if (legacyRaw != null && legacyRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(legacyRaw);
        if (decoded is List) {
          final batch = _db.batch();
          for (final entry in decoded.whereType<Map>()) {
            final log = WorkoutSetLog.fromJson(entry.cast<String, dynamic>());
            batch.set(_collection(userId).doc(_docId(log)), log.toJson());
          }
          await batch.commit();
        }
      } catch (error) {
        debugPrint('Workout log migration failed: $error');
      }
      await prefs.remove('workout_logs_$userId');
    }
    await prefs.setBool(migratedKey, true);
  }
}
