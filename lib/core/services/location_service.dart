// lib/core/services/location_service.dart
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:safetaxi_cameroun/core/constants/app_constants.dart';
import 'package:safetaxi_cameroun/core/network/api_client.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/providers/auth_provider.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

/// Service GPS qui fonctionne même en arrière-plan.
/// Utilisé par les chauffeurs pour envoyer leur position
/// en temps réel pendant un trajet.
class LocationTrackingService {
  static LocationTrackingService? _instance;
  final ApiClient? _apiClient;

  factory LocationTrackingService({ApiClient? apiClient}) {
    _instance ??= LocationTrackingService._(apiClient: apiClient);
    return _instance!;
  }
  LocationTrackingService._({ApiClient? apiClient}) : _apiClient = apiClient;

  StreamSubscription<Position>? _streamSubscription;
  FirebaseDatabase? _db;
  String? _currentTripId;
  Timer? _heartbeatTimer;
  bool _isTracking = false;

  bool get isTracking => _isTracking;
  String? get currentTripId => _currentTripId;

  FirebaseDatabase? get _database {
    _db ??= (() {
      try {
        return FirebaseDatabase.instance;
      } catch (e) {
        _log.w('Firebase Database unavailable: $e');
        return null;
      }
    })();
    return _db;
  }

  // ─── Vérifier et demander les permissions ───────────────

  Future<bool> requestPermissions() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      // Vérifier si le service GPS est activé
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _log.w('Location services are disabled.');
        // Ouvrir les paramètres de localisation
        final opened = await Geolocator.openLocationSettings();
        if (!opened) {
          _log.w('Failed to open location settings.');
          return false;
        }
        // Réessayer après ouverture
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          return false;
        }
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _log.w('Location permissions are denied.');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _log.w('Location permissions permanently denied. Opening app settings...');
        // Ouvrir les paramètres de l'application pour permettre à l'utilisateur de changer les permissions
        final opened = await Geolocator.openAppSettings();
        if (!opened) {
          _log.w('Failed to open app settings.');
          return false;
        }
        // Réessayer après ouverture
        permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.deniedForever) {
          return false;
        }
      }

      return true;
    } catch (e) {
      _log.w('Location permission check failed: $e');
      return false;
    }
  }

  // ─── Position actuelle ─────────────────────────────────

  Future<Position?> getCurrentPosition() async {
    final granted = await requestPermissions();
    if (!granted) return null;

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // ─── Démarrer le tracking GPS ───────────────────────────
  ///
  /// Appelé quand un chauffeur commence un service.
  /// Envoie la position GPS toutes les [intervalSeconds]
  /// dans Firebase Realtime Database.
  Future<void> startTracking(
    String tripId, {
    int intervalSeconds = AppConstants.gpsIntervalSeconds,
  }) async {
    if (_isTracking) {
      _log.w('Already tracking. Call stopTracking first.');
      return;
    }

    final granted = await requestPermissions();
    if (!granted) {
      _log.e('Cannot start tracking without permissions.');
      return;
    }

    _currentTripId = tripId;
    _isTracking = true;

    // Location settings
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: AppConstants.gpsDistanceFilterMeters,
    );

    // Démarrer le stream GPS
    _streamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (position) {
        _uploadPosition(tripId, position);
      },
      onError: (e) {
        _log.e('GPS stream error: $e');
      },
    );

    // Heartbeat pour marquer le taxi comme actif
    _heartbeatTimer = Timer.periodic(
      Duration(seconds: intervalSeconds * 2),
      (_) => _sendHeartbeat(tripId),
    );

    // Envoyer la première position immédiatement
    final pos = await getCurrentPosition();
    if (pos != null) {
      await _uploadPosition(tripId, pos);
    }

    _log.i('GPS tracking started for trip: $tripId');
  }

  // ─── Arrêter le tracking ────────────────────────────────

  Future<void> stopTracking() async {
    if (!_isTracking) return;

    _streamSubscription?.cancel();
    _streamSubscription = null;

    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    // Marquer le taxi comme inactif
    if (_currentTripId != null) {
      try {
        final db = _database;
        if (db != null) {
          await db
              .ref('${AppConstants.firebaseTripsPath}/$_currentTripId/active')
              .set(false);
          await db
              .ref('${AppConstants.firebaseTripsPath}/$_currentTripId/location')
              .remove();
        }
      } catch (_) {}
    }

    _currentTripId = null;
    _isTracking = false;

    _log.i('GPS tracking stopped.');
  }

  // ─── Uploader la position vers Firebase ─────────────────

  Future<void> _uploadPosition(String tripId, Position pos) async {
    try {
      final db = _database;
      if (db == null) return;

      final ref = db.ref('${AppConstants.firebaseTripsPath}/$tripId');

      // Données de localisation
      await ref.child('location').set({
        'lat': pos.latitude,
        'lng': pos.longitude,
        'accuracy': pos.accuracy,
        'altitude': pos.altitude,
        'speed': pos.speed,
        'heading': pos.heading,
        'timestamp': ServerValue.timestamp,
      });

      // Marquer comme actif
      await ref.child('active').set(true);

      // Synchroniser avec le backend Django pour la persistance
      try {
        await _apiClient?.post('/trips/$tripId/location/', data: {
          'lat': pos.latitude,
          'lng': pos.longitude,
          'accuracy': pos.accuracy,
          'speed': pos.speed,
          'heading': pos.heading,
        });
      } catch (_) {
        // Ne pas bloquer le tracking temps réel si le backend est inaccessible
      }

      _log.d(
        'Position uploaded: ${pos.latitude.toStringAsFixed(4)}, '
        '${pos.longitude.toStringAsFixed(4)}',
      );
    } catch (e) {
      _log.e('Failed to upload position: $e');
    }
  }

  // ─── Heartbeat ──────────────────────────────────────────

  Future<void> _sendHeartbeat(String tripId) async {
    try {
      final db = _database;
      if (db == null) return;

      await db
          .ref('${AppConstants.firebaseTripsPath}/$tripId/active')
          .set(true);
      await db
          .ref('${AppConstants.firebaseTripsPath}/$tripId/heartbeat')
          .set(ServerValue.timestamp);
    } catch (_) {}
  }

  // ─── Lire la position d'un taxi (depuis Firebase) ───────

  Stream<Map<String, dynamic>?> watchTaxiPosition(String tripId) {
    final db = _database;
    if (db == null) {
      return const Stream<Map<String, dynamic>?>.empty();
    }

    return db
        .ref('${AppConstants.firebaseTripsPath}/$tripId/location')
        .onValue
        .map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return null;
      return {
        'lat': (data['lat'] as num).toDouble(),
        'lng': (data['lng'] as num).toDouble(),
        'accuracy': (data['accuracy'] as num?)?.toDouble(),
        'speed': (data['speed'] as num?)?.toDouble(),
        'heading': (data['heading'] as num?)?.toDouble(),
        'timestamp': data['timestamp'],
      };
    });
  }

  // ─── Vérifier si un taxi est actif ─────────────────────

  Stream<bool> watchTaxiActive(String tripId) {
    final db = _database;
    if (db == null) {
      return const Stream<bool>.empty();
    }

    return db
        .ref('${AppConstants.firebaseTripsPath}/$tripId/active')
        .onValue
        .map((event) => event.snapshot.value as bool? ?? false);
  }

  // ─── Distance entre deux positions ──────────────────────

  static double distanceBetween(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  // ─── Nettoyer ───────────────────────────────────────────

  void dispose() {
    stopTracking();
  }
}

// ─── Provider ─────────────────────────────────────────────

final locationTrackingProvider = Provider<LocationTrackingService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final svc = LocationTrackingService(apiClient: apiClient);
  ref.onDispose(svc.dispose);
  return svc;
});
