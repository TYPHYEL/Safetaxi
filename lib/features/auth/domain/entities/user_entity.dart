// lib/features/auth/domain/entities/user_entity.dart
import 'package:equatable/equatable.dart';

enum UserRole { passenger, driver, owner, admin }

enum VerificationStatus { pending, verified, rejected }

class UserEntity extends Equatable {
  final String id;
  final String phone;
  final String firstName;
  final String lastName;
  final String? photoUrl;
  final UserRole role;
  final double trustScore;
  final bool isVerified;
  final bool isActive;
  final DateTime createdAt;

  const UserEntity({
    required this.id,
    required this.phone,
    required this.firstName,
    required this.lastName,
    this.photoUrl,
    required this.role,
    this.trustScore = 5.0,
    this.isVerified = false,
    this.isActive = true,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName';
  String get displayName => '$firstName ${lastName[0]}.';
  String get initials =>
      '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}';

  @override
  List<Object?> get props =>
      [id, phone, firstName, lastName, role, trustScore, isVerified];
}

class PassengerEntity extends Equatable {
  final String id;
  final UserEntity user;
  final String? cniNumber;
  final bool cniVerified;
  final int totalTrips;

  const PassengerEntity({
    required this.id,
    required this.user,
    this.cniNumber,
    this.cniVerified = false,
    this.totalTrips = 0,
  });

  @override
  List<Object?> get props => [id, user.id, cniVerified];
}

class DriverEntity extends Equatable {
  final String id;
  final UserEntity user;
  final String licenseNumber;
  final String? cniUrl;
  final String? selfieUrl;
  final bool biometricOk;
  final bool isApproved;
  final VerificationStatus verificationStatus;
  final DateTime? approvedAt;
  final int totalTrips;
  final bool isCurrentlyActive;

  const DriverEntity({
    required this.id,
    required this.user,
    required this.licenseNumber,
    this.cniUrl,
    this.selfieUrl,
    this.biometricOk = false,
    this.isApproved = false,
    this.verificationStatus = VerificationStatus.pending,
    this.approvedAt,
    this.totalTrips = 0,
    this.isCurrentlyActive = false,
  });

  @override
  List<Object?> get props => [id, licenseNumber, isApproved, isCurrentlyActive];
}
