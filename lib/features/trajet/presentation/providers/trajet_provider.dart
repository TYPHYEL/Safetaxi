// lib/features/trajet/presentation/providers/trajet_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:safetaxi_cameroun/core/constants/app_constants.dart';
import 'package:safetaxi_cameroun/core/network/api_client.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/providers/auth_provider.dart';

// ─── Modèle léger pour la liste des passagers live ───────

class LivePassenger {
  final String id;
  final String firstName;
  final String photoUrl;
  final bool isVerified;
  final DateTime boardedAt;

  const LivePassenger({
    required this.id,
    required this.firstName,
    required this.photoUrl,
    required this.isVerified,
    required this.boardedAt,
  });

  factory LivePassenger.fromFirebase(String id, Map<dynamic, dynamic> data) =>
      LivePassenger(
        id: id,
        firstName: data['first_name'] as String? ?? 'Passager',
        photoUrl: data['photo_url'] as String? ?? '',
        isVerified: data['is_verified'] as bool? ?? false,
        boardedAt: DateTime.tryParse(data['boarded_at'] as String? ?? '') ??
            DateTime.now(),
      );
}

class TripLocation {
  final double lat;
  final double lng;
  final double? accuracy;
  final DateTime timestamp;

  const TripLocation({
    required this.lat,
    required this.lng,
    this.accuracy,
    required this.timestamp,
  });

  factory TripLocation.fromFirebase(Map<dynamic, dynamic> data) => TripLocation(
        lat: (data['lat'] as num).toDouble(),
        lng: (data['lng'] as num).toDouble(),
        accuracy: (data['accuracy'] as num?)?.toDouble(),
        timestamp: DateTime.now(),
      );
}

// ─── État du trajet actif ────────────────────────────────

String? parseTripId(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is num) return value.toString();
  return value.toString();
}

bool isJoinCodeInput(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return false;
  if (trimmed.startsWith(AppConstants.qrPrefix)) return false;
  return trimmed.length >= 4;
}

String extractTripIdFromInput(String raw) {
  final trimmed = raw.trim();
  if (trimmed.startsWith(AppConstants.qrPrefix)) {
    return trimmed.replaceFirst(AppConstants.qrPrefix, '');
  }
  return trimmed;
}

String joinMethodForInput(String raw) {
  return raw.trim().startsWith(AppConstants.qrPrefix) ? 'qr' : 'code';
}

class ActiveTripState {
  final String? tripId;
  final String? taxiId;
  final bool isActive;
  final List<LivePassenger> passengers;
  final TripLocation? location;
  final double riskScore;
  final bool isLoading;
  final String? error;

  const ActiveTripState({
    this.tripId,
    this.taxiId,
    this.isActive = false,
    this.passengers = const [],
    this.location,
    this.riskScore = 0.0,
    this.isLoading = false,
    this.error,
  });

  ActiveTripState copyWith({
    String? tripId,
    String? taxiId,
    bool? isActive,
    List<LivePassenger>? passengers,
    TripLocation? location,
    double? riskScore,
    bool? isLoading,
    String? error,
  }) =>
      ActiveTripState(
        tripId: tripId ?? this.tripId,
        taxiId: taxiId ?? this.taxiId,
        isActive: isActive ?? this.isActive,
        passengers: passengers ?? this.passengers,
        location: location ?? this.location,
        riskScore: riskScore ?? this.riskScore,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ─── GPS Service ─────────────────────────────────────────

class GpsService {
  StreamSubscription<Position>? _positionStream;
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  Future<bool> requestPermissions() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm != LocationPermission.denied &&
        perm != LocationPermission.deniedForever;
  }

  Future<Position?> getCurrentPosition() async {
    final granted = await requestPermissions();
    if (!granted) return null;
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  void startTracking(String tripId, {required Function(Position) onUpdate}) {
    const locationOptions = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: AppConstants.gpsDistanceFilterMeters,
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationOptions,
    ).listen((pos) {
      onUpdate(pos);
      _uploadToFirebase(tripId, pos);
    });
  }

  Future<void> _uploadToFirebase(String tripId, Position pos) async {
    await _db.ref('${AppConstants.firebaseTripsPath}/$tripId/location').set({
      'lat': pos.latitude,
      'lng': pos.longitude,
      'accuracy': pos.accuracy,
      'timestamp': ServerValue.timestamp,
    });
  }

  Stream<TripLocation?> watchLocation(String tripId) {
    return _db
        .ref('${AppConstants.firebaseTripsPath}/$tripId/location')
        .onValue
        .map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return null;
      return TripLocation.fromFirebase(data);
    });
  }

  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  void dispose() => stopTracking();
}

// ─── Passengers Live Stream ───────────────────────────────

Stream<List<LivePassenger>> watchTripPassengers(String tripId) {
  final db = FirebaseDatabase.instance;
  return db
      .ref('${AppConstants.firebaseTripsPath}/$tripId/passengers')
      .onValue
      .map((event) {
    final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
    return data.entries
        .map((e) => LivePassenger.fromFirebase(
            e.key.toString(), e.value as Map<dynamic, dynamic>))
        .toList()
      ..sort((a, b) => a.boardedAt.compareTo(b.boardedAt));
  });
}

// ─── Providers ───────────────────────────────────────────

final gpsServiceProvider = Provider<GpsService>((ref) {
  final svc = GpsService();
  ref.onDispose(svc.dispose);
  return svc;
});

final activeTripProvider =
    StateNotifierProvider<ActiveTripNotifier, ActiveTripState>(
  (ref) => ActiveTripNotifier(
    ref.watch(apiClientProvider),
    ref.watch(gpsServiceProvider),
  ),
);

final tripPassengersStreamProvider =
    StreamProvider.family<List<LivePassenger>, String>((ref, tripId) {
  return watchTripPassengers(tripId);
});

final tripLocationStreamProvider =
    StreamProvider.family<TripLocation?, String>((ref, tripId) {
  return ref.watch(gpsServiceProvider).watchLocation(tripId);
});

// ─── Notifier trajet actif ───────────────────────────────

class ActiveTripNotifier extends StateNotifier<ActiveTripState> {
  final ApiClient _api;
  final GpsService _gps;

  ActiveTripNotifier(this._api, this._gps) : super(const ActiveTripState()) {
    _loadActiveTrip();
  }

  Future<void> _loadActiveTrip() async {
    try {
      final resp = await _api.getActiveTrip();
      if (resp.data != null && resp.data is Map<String, dynamic>) {
        final data = resp.data as Map<String, dynamic>;
        if (data.isNotEmpty && data['id'] != null) {
          state = state.copyWith(
            tripId: parseTripId(data['id']),
            taxiId: data['taxi_id'] != null ? parseTripId(data['taxi_id']) : null,
            isActive: true,
          );
        }
      }
    } catch (_) {
      // Pas de trajet actif, c'est normal
    }
  }

  // CHAUFFEUR : démarrer un trajet
  Future<void> startTrip(String driverTaxiId) async {
    state = state.copyWith(isLoading: true);
    try {
      final pos = await _gps.getCurrentPosition();
      final resp = await _api.createTrip({
        'driver_taxi_id': driverTaxiId,
        if (pos != null) 'start_lat': pos.latitude,
        if (pos != null) 'start_lng': pos.longitude,
      });
      final data = resp.data as Map<String, dynamic>;
      final tripId = parseTripId(data['id']);

      if (tripId == null || tripId.isEmpty) {
        throw Exception('Trip ID missing from backend response');
      }

      state = state.copyWith(
        tripId: tripId,
        isActive: true,
        isLoading: false,
      );

      // Démarrer le suivi GPS
      _gps.startTracking(tripId, onUpdate: (pos) {});
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // PASSAGER : rejoindre un trajet
  Future<bool> joinTrip(String tripId, String joinMethod) async {
    state = state.copyWith(isLoading: true);
    try {
      final pos = await _gps.getCurrentPosition();
      dynamic response;
      if (isJoinCodeInput(tripId)) {
        response = await _api.post('/trips/join_by_code/', data: {
          'join_code': tripId,
          'join_method': joinMethod,
          if (pos != null) 'boarded_lat': pos.latitude,
          if (pos != null) 'boarded_lng': pos.longitude,
        });
      } else {
        response = await _api.joinTrip(tripId, {
          'join_method': joinMethod,
          if (pos != null) 'boarded_lat': pos.latitude,
          if (pos != null) 'boarded_lng': pos.longitude,
        });
      }
      final data = response.data as Map<String, dynamic>;
      final joinedTripId = parseTripId(data['id']);
      state = state.copyWith(
        tripId: joinedTripId,
        isActive: true,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // PASSAGER : descendre
  Future<void> leaveTrip() async {
    if (state.tripId == null) return;
    try {
      await _api.leaveTrip(state.tripId!);
      state = state.copyWith(isActive: false, tripId: null);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // CHAUFFEUR : terminer le trajet
  Future<void> endTrip() async {
    if (state.tripId == null) return;
    try {
      await _api.endTrip(state.tripId!);
      _gps.stopTracking();
      state = const ActiveTripState();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void clearError() => state = state.copyWith(error: null);
}
