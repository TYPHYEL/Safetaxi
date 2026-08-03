// lib/core/services/settings_service.dart
// Service de persistance des préférences avec Hive
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

const _boxName = 'safetaxi_settings';

class SettingsService {
  static Box? _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static Box get box {
    if (_box == null || !_box!.isOpen) {
      throw StateError('SettingsService not initialized. Call init() first.');
    }
    return _box!;
  }

  // ─── Lecture ────────────────────────────────────────────
  static T read<T>(String key, T defaultValue) {
    try {
      return box.get(key, defaultValue: defaultValue) as T;
    } catch (_) {
      return defaultValue;
    }
  }

  // ─── Écriture ───────────────────────────────────────────
  static Future<void> write<T>(String key, T value) async {
    await box.put(key, value);
  }

  // ─── Clés de configuration ──────────────────────────────
  static const kNotifSos          = 'notif_sos';
  static const kNotifPassenger    = 'notif_passenger';
  static const kNotifPromo        = 'notif_promo';
  static const kLocationShare     = 'location_share';
  static const kShowPhoto         = 'show_photo';
  static const kOfflineMode       = 'offline_mode';
  static const kVibrations        = 'vibrations';
  static const kThemeMode         = 'theme_mode';     // 'dark' | 'light' | 'system'
  static const kLanguage          = 'language';       // 'fr' | 'en'
  static const kSosVolumeButton   = 'sos_volume_btn';
  static const kFcmToken          = 'fcm_token';
  static const kCachedTrips       = 'cached_trips';
  static const kCachedTaxis       = 'cached_taxis';
  static const kCachedUser        = 'cached_user';
}

// ─── Provider ─────────────────────────────────────────────

class SettingsNotifier extends StateNotifier<Map<String, dynamic>> {
  SettingsNotifier() : super(_loadAll());

  static Map<String, dynamic> _loadAll() {
    return {
      SettingsService.kNotifSos:        SettingsService.read(SettingsService.kNotifSos, true),
      SettingsService.kNotifPassenger:  SettingsService.read(SettingsService.kNotifPassenger, true),
      SettingsService.kNotifPromo:      SettingsService.read(SettingsService.kNotifPromo, false),
      SettingsService.kLocationShare:   SettingsService.read(SettingsService.kLocationShare, true),
      SettingsService.kShowPhoto:       SettingsService.read(SettingsService.kShowPhoto, true),
      SettingsService.kOfflineMode:     SettingsService.read(SettingsService.kOfflineMode, true),
      SettingsService.kVibrations:      SettingsService.read(SettingsService.kVibrations, true),
      SettingsService.kThemeMode:       SettingsService.read(SettingsService.kThemeMode, 'dark'),
      SettingsService.kLanguage:        SettingsService.read(SettingsService.kLanguage, 'fr'),
      SettingsService.kSosVolumeButton: SettingsService.read(SettingsService.kSosVolumeButton, true),
    };
  }

  T get<T>(String key, T defaultValue) {
    return state[key] as T? ?? defaultValue;
  }

  Future<void> set<T>(String key, T value) async {
    await SettingsService.write(key, value);
    state = {...state, key: value};
  }

  void toggle(String key) {
    final current = state[key] as bool? ?? false;
    set(key, !current);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, Map<String, dynamic>>((ref) {
  return SettingsNotifier();
});
