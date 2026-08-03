// lib/core/utils/offline_service.dart
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

class OfflineService {
  static const _tripsCacheBox    = 'trips_cache';
  static const _userCacheBox     = 'user_cache';
  static const _pendingSyncBox   = 'pending_sync';
  static const _taxisCacheBox    = 'taxis_cache';

  late Box<String> _tripsBox;
  late Box<String> _userBox;
  late Box<String> _pendingBox;
  late Box<String> _taxisBox;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  final _connectivity = Connectivity();

  Future<void> init() async {
    _tripsBox   = await Hive.openBox<String>(_tripsCacheBox);
    _userBox    = await Hive.openBox<String>(_userCacheBox);
    _pendingBox = await Hive.openBox<String>(_pendingSyncBox);
    _taxisBox   = await Hive.openBox<String>(_taxisCacheBox);

    // Surveiller la connectivité
    _connectivity.onConnectivityChanged.listen((results) {
      final wasOffline = !_isOnline;
      _isOnline = results.any((r) => r != ConnectivityResult.none);
      if (wasOffline && _isOnline) {
        _log.d('Reconnecté — synchronisation...');
        syncPendingData();
      }
    });

    // Statut initial
    final result = await _connectivity.checkConnectivity();
    _isOnline = result.any((r) => r != ConnectivityResult.none);
  }

  // ─── Cache trajets ────────────────────────────────────

  Future<void> cacheTrips(List<Map<String, dynamic>> trips) async {
    await _tripsBox.put('all', jsonEncode(trips));
    await _tripsBox.put(
        'cached_at', DateTime.now().toIso8601String());
  }

  List<Map<String, dynamic>> getCachedTrips() {
    final raw = _tripsBox.get('all');
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  bool get hasCachedTrips => _tripsBox.containsKey('all');

  DateTime? get tripsCachedAt {
    final s = _tripsBox.get('cached_at');
    return s != null ? DateTime.tryParse(s) : null;
  }

  // ─── Cache taxis ──────────────────────────────────────

  Future<void> cacheTaxis(List<Map<String, dynamic>> taxis) async {
    await _taxisBox.put('all', jsonEncode(taxis));
  }

  List<Map<String, dynamic>> getCachedTaxis() {
    final raw = _taxisBox.get('all');
    if (raw == null) return [];
    return (jsonDecode(raw) as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  // ─── Cache utilisateur ────────────────────────────────

  Future<void> cacheUser(Map<String, dynamic> user) async {
    await _userBox.put('profile', jsonEncode(user));
  }

  Map<String, dynamic>? getCachedUser() {
    final raw = _userBox.get('profile');
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  // ─── Sync différée ────────────────────────────────────

  Future<void> queueForSync({
    required String endpoint,
    required String method,
    required Map<String, dynamic> data,
  }) async {
    final item = jsonEncode({
      'endpoint': endpoint,
      'method':   method,
      'data':     data,
      'queued_at': DateTime.now().toIso8601String(),
    });
    await _pendingBox.add(item);
    _log.d('Queued for sync: $method $endpoint');
  }

  Future<void> syncPendingData() async {
    if (!_isOnline) return;
    final keys = _pendingBox.keys.toList();
    _log.d('Syncing ${keys.length} pending items...');

    for (final key in keys) {
      final raw = _pendingBox.get(key);
      if (raw == null) continue;
      try {
        final item = jsonDecode(raw) as Map<String, dynamic>;
        _log.d(
            'Syncing: ${item['method']} ${item['endpoint']}');
        // TODO: appeler l'API pour chaque item en attente
        await _pendingBox.delete(key);
      } catch (e) {
        _log.e('Sync failed for key $key: $e');
      }
    }
    _log.d('Sync terminée');
  }

  int get pendingSyncCount => _pendingBox.length;

  // ─── Cleanup ──────────────────────────────────────────

  Future<void> clearAll() async {
    await _tripsBox.clear();
    await _userBox.clear();
    await _taxisBox.clear();
    // Ne pas vider les pending !
  }

  Future<void> dispose() async {
    await _tripsBox.close();
    await _userBox.close();
    await _pendingBox.close();
    await _taxisBox.close();
  }
}
