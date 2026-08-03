// lib/core/services/cache_service.dart
// Service de cache offline avec Hive
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import 'settings_service.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

class CacheService {
  static const _boxName = 'safetaxi_cache';
  static Box? _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static Box get _b {
    if (_box == null || !_box!.isOpen) {
      throw StateError('CacheService not initialized.');
    }
    return _box!;
  }

  // ─── Trips ─────────────────────────────────────────────

  static Future<void> cacheTrips(List<Map<String, dynamic>> trips) async {
    try {
      await _b.put(SettingsService.kCachedTrips, jsonEncode(trips));
      _log.d('Cached ${trips.length} trips');
    } catch (e) {
      _log.w('Failed to cache trips: $e');
    }
  }

  static List<Map<String, dynamic>> getCachedTrips() {
    try {
      final raw = _b.get(SettingsService.kCachedTrips) as String?;
      if (raw == null) return [];
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> cacheTripHistory(List<Map<String, dynamic>> trips) async {
    await cacheTrips(trips);
  }

  static List<Map<String, dynamic>> getCachedTripHistory() {
    return getCachedTrips();
  }

  // ─── Taxis ─────────────────────────────────────────────

  static Future<void> cacheTaxis(List<Map<String, dynamic>> taxis) async {
    try {
      await _b.put(SettingsService.kCachedTaxis, jsonEncode(taxis));
      _log.d('Cached ${taxis.length} taxis');
    } catch (e) {
      _log.w('Failed to cache taxis: $e');
    }
  }

  static List<Map<String, dynamic>> getCachedTaxis() {
    try {
      final raw = _b.get(SettingsService.kCachedTaxis) as String?;
      if (raw == null) return [];
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ─── User ──────────────────────────────────────────────

  static Future<void> cacheUser(Map<String, dynamic> user) async {
    try {
      await _b.put(SettingsService.kCachedUser, jsonEncode(user));
    } catch (e) {
      _log.w('Failed to cache user: $e');
    }
  }

  static Map<String, dynamic>? getCachedUser() {
    try {
      final raw = _b.get(SettingsService.kCachedUser) as String?;
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ─── Vider le cache ────────────────────────────────────

  static Future<void> clearAll() async {
    await _b.clear();
    _log.i('Cache cleared');
  }

  // ─── Taille cache ─────────────────────────────────────

  static int get cachedItemCount => _b.length;
}
