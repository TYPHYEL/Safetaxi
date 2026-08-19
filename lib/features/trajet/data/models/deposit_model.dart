// lib/features/trajet/data/models/deposit_model.dart

class Deposit {
  final String id;
  final String passenger;
  final String? passengerName;
  final String? driver;
  final String? driverName;
  final String? taxi;
  final String status;
  final String pickupLocation;
  final double pickupLat;
  final double pickupLng;
  final String dropoffLocation;
  final double dropoffLat;
  final double dropoffLng;
  final double distanceKm;
  final double fare;
  final bool isNight;
  final DateTime? pickupTime;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final double? driverTrustScore;

  Deposit({
    required this.id,
    required this.passenger,
    this.passengerName,
    this.driver,
    this.driverName,
    this.taxi,
    required this.status,
    required this.pickupLocation,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLocation,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.distanceKm,
    required this.fare,
    required this.isNight,
    this.pickupTime,
    this.startedAt,
    this.completedAt,
    required this.createdAt,
    this.expiresAt,
    this.driverTrustScore,
  });

  factory Deposit.fromJson(Map<String, dynamic> json) {
    return Deposit(
      id: json['id']?.toString() ?? '',
      passenger: json['passenger']?.toString() ?? '',
      passengerName: json['passenger_name']?.toString(),
      driver: json['driver']?.toString(),
      driverName: json['driver_name']?.toString(),
      taxi: json['taxi']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      pickupLocation: json['pickup_location']?.toString() ?? '',
      pickupLat: (json['pickup_lat'] as num?)?.toDouble() ?? 0.0,
      pickupLng: (json['pickup_lng'] as num?)?.toDouble() ?? 0.0,
      dropoffLocation: json['dropoff_location']?.toString() ?? '',
      dropoffLat: (json['dropoff_lat'] as num?)?.toDouble() ?? 0.0,
      dropoffLng: (json['dropoff_lng'] as num?)?.toDouble() ?? 0.0,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      fare: (json['fare'] as num?)?.toDouble() ?? 0.0,
      isNight: json['is_night'] as bool? ?? false,
      pickupTime: json['pickup_time'] != null 
          ? DateTime.parse(json['pickup_time']) 
          : null,
      startedAt: json['started_at'] != null 
          ? DateTime.parse(json['started_at']) 
          : null,
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at']) 
          : null,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      expiresAt: json['expires_at'] != null 
          ? DateTime.parse(json['expires_at']) 
          : null,
      driverTrustScore: (json['driver_trust_score'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'passenger': passenger,
      'passenger_name': passengerName,
      'driver': driver,
      'driver_name': driverName,
      'taxi': taxi,
      'status': status,
      'pickup_location': pickupLocation,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'dropoff_location': dropoffLocation,
      'dropoff_lat': dropoffLat,
      'dropoff_lng': dropoffLng,
      'distance_km': distanceKm,
      'fare': fare,
      'is_night': isNight,
      'pickup_time': pickupTime?.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'driver_trust_score': driverTrustScore,
    };
  }

  Deposit copyWith({
    String? id,
    String? passenger,
    String? passengerName,
    String? driver,
    String? driverName,
    String? taxi,
    String? status,
    String? pickupLocation,
    double? pickupLat,
    double? pickupLng,
    String? dropoffLocation,
    double? dropoffLat,
    double? dropoffLng,
    double? distanceKm,
    double? fare,
    bool? isNight,
    DateTime? pickupTime,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? expiresAt,
    double? driverTrustScore,
  }) {
    return Deposit(
      id: id ?? this.id,
      passenger: passenger ?? this.passenger,
      passengerName: passengerName ?? this.passengerName,
      driver: driver ?? this.driver,
      driverName: driverName ?? this.driverName,
      taxi: taxi ?? this.taxi,
      status: status ?? this.status,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      dropoffLat: dropoffLat ?? this.dropoffLat,
      dropoffLng: dropoffLng ?? this.dropoffLng,
      distanceKm: distanceKm ?? this.distanceKm,
      fare: fare ?? this.fare,
      isNight: isNight ?? this.isNight,
      pickupTime: pickupTime ?? this.pickupTime,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      driverTrustScore: driverTrustScore ?? this.driverTrustScore,
    );
  }

  bool get isPending => status == 'pending';
  bool get isOffered => status == 'offered';
  bool get isAccepted => status == 'accepted';
  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isExpired => status == 'expired';

  String get statusText {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'offered':
        return 'Proposé';
      case 'accepted':
        return 'Accepté';
      case 'active':
        return 'En cours';
      case 'completed':
        return 'Terminé';
      case 'cancelled':
        return 'Annulé';
      case 'expired':
        return 'Expiré';
      default:
        return status;
    }
  }
}

class DepositRequest {
  final String pickupLocation;
  final double pickupLat;
  final double pickupLng;
  final String dropoffLocation;
  final double dropoffLat;
  final double dropoffLng;
  final double distanceKm;
  final double fare;
  final bool isNight;

  DepositRequest({
    required this.pickupLocation,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLocation,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.distanceKm,
    required this.fare,
    required this.isNight,
  });

  Map<String, dynamic> toJson() {
    return {
      'pickup_location': pickupLocation,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'dropoff_location': dropoffLocation,
      'dropoff_lat': dropoffLat,
      'dropoff_lng': dropoffLng,
      'distance_km': distanceKm,
      'fare': fare,
      'is_night': isNight,
    };
  }
}

class FareCalculationRequest {
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;

  FareCalculationRequest({
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
  });

  Map<String, dynamic> toJson() {
    return {
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'dropoff_lat': dropoffLat,
      'dropoff_lng': dropoffLng,
    };
  }
}

class FareCalculationResponse {
  final double distanceKm;
  final double fare;
  final bool isNight;
  final double minFare;

  FareCalculationResponse({
    required this.distanceKm,
    required this.fare,
    required this.isNight,
    required this.minFare,
  });

  factory FareCalculationResponse.fromJson(Map<String, dynamic> json) {
    return FareCalculationResponse(
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      fare: (json['fare'] as num?)?.toDouble() ?? 0.0,
      isNight: json['is_night'] as bool? ?? false,
      minFare: (json['min_fare'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
