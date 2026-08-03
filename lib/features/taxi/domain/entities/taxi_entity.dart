// lib/features/taxi/domain/entities/taxi_entity.dart
import 'package:equatable/equatable.dart';
import 'package:safetaxi_cameroun/features/auth/domain/entities/user_entity.dart';

class TaxiEntity extends Equatable {
  final String id;
  final String plate;
  final String licenseNumber;
  final String brand;
  final String model;
  final String color;
  final String? photoUrl;
  final String ownerId;
  final bool isActive;
  final DriverEntity? activeDriver;
  final double? latitude;
  final double? longitude;
  final DateTime? lastSeen;

  const TaxiEntity({
    required this.id,
    required this.plate,
    required this.licenseNumber,
    required this.brand,
    required this.model,
    required this.color,
    this.photoUrl,
    required this.ownerId,
    this.isActive = true,
    this.activeDriver,
    this.latitude,
    this.longitude,
    this.lastSeen,
  });

  String get displayName => '$brand $model';
  bool get hasActiveDriver => activeDriver != null;
  bool get hasLocation => latitude != null && longitude != null;

  @override
  List<Object?> get props => [id, plate, brand, model, isActive];
}

// lib/features/trajet/domain/entities/trajet_entity.dart

enum TripStatus { active, ended, incident, cancelled }
enum JoinMethod { qr, code, bluetooth, map }

class TripPassengerEntity extends Equatable {
  final String id;
  final PassengerEntity passenger;
  final JoinMethod joinMethod;
  final DateTime boardedAt;
  final DateTime? alightedAt;
  final double? boardedLat;
  final double? boardedLng;
  final double? alightedLat;
  final double? alightedLng;

  const TripPassengerEntity({
    required this.id,
    required this.passenger,
    required this.joinMethod,
    required this.boardedAt,
    this.alightedAt,
    this.boardedLat,
    this.boardedLng,
    this.alightedLat,
    this.alightedLng,
  });

  bool get isOnboard => alightedAt == null;

  @override
  List<Object?> get props => [id, passenger.id, boardedAt];
}

class TripEntity extends Equatable {
  final String id;
  final TaxiEntity taxi;
  final DriverEntity driver;
  final TripStatus status;
  final List<TripPassengerEntity> passengers;
  final double? currentLat;
  final double? currentLng;
  final double riskScore;
  final DateTime startedAt;
  final DateTime? endedAt;

  const TripEntity({
    required this.id,
    required this.taxi,
    required this.driver,
    required this.status,
    required this.passengers,
    this.currentLat,
    this.currentLng,
    this.riskScore = 0.0,
    required this.startedAt,
    this.endedAt,
  });

  List<TripPassengerEntity> get onboardPassengers =>
      passengers.where((p) => p.isOnboard).toList();

  int get onboardCount => onboardPassengers.length;
  bool get isActive => status == TripStatus.active;

  @override
  List<Object?> get props => [id, status, onboardCount];
}

class SosAlertEntity extends Equatable {
  final String id;
  final String tripId;
  final String senderId;
  final String senderRole;
  final String alertType;
  final double latitude;
  final double longitude;
  final bool isResolved;
  final DateTime createdAt;

  const SosAlertEntity({
    required this.id,
    required this.tripId,
    required this.senderId,
    required this.senderRole,
    required this.alertType,
    required this.latitude,
    required this.longitude,
    this.isResolved = false,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, tripId, isResolved];
}
