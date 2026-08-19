// lib/features/auth/data/models/user_model.dart
import 'dart:io';
import 'package:safetaxi_cameroun/features/auth/domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.phone,
    required super.firstName,
    required super.lastName,
    super.photoUrl,
    required super.role,
    super.trustScore,
    super.isVerified,
    super.isActive,
    required super.createdAt,
    super.driverProfile,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    return UserModel(
      id: rawId?.toString() ?? '',
      phone: (json['phone'] as String?) ?? '',
      firstName: (json['first_name'] as String?) ?? '',
      lastName: (json['last_name'] as String?) ?? '',
      photoUrl: json['photo_url'] as String?,
      role: _roleFromString(json['role'] as String),
      trustScore: (json['trust_score'] as num?)?.toDouble() ?? 5.0,
      isVerified: json['is_verified'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      driverProfile: json['driver_profile'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'first_name': firstName,
        'last_name': lastName,
        'photo_url': photoUrl,
        'role': role.name,
        'trust_score': trustScore,
        'is_verified': isVerified,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'driver_profile': driverProfile,
      };

  static UserRole _roleFromString(String s) {
    switch (s) {
      case 'driver':
        return UserRole.driver;
      case 'owner':
        return UserRole.owner;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.passenger;
    }
  }
}

class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final UserModel user;

  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        accessToken: json['access'] as String,
        refreshToken: json['refresh'] as String,
        user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      );
}

class RegisterRequest {
  final String phone;
  final String firstName;
  final String lastName;
  final String role;
  final String? email;
  final String? password;
  final File? licensePhoto;
  final File? vehiclePhoto;
  final File? cniPhoto;
  final File? profilePhoto;
  final String? birthDate;
  final String? gender;

  const RegisterRequest({
    required this.phone,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.email,
    this.password,
    this.licensePhoto,
    this.vehiclePhoto,
    this.cniPhoto,
    this.profilePhoto,
    this.birthDate,
    this.gender,
  });

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'first_name': firstName,
        'last_name': lastName,
        'role': role,
        if (email != null && email!.isNotEmpty) 'email': email,
        if (password != null) 'password': password,
        if (birthDate != null && birthDate!.isNotEmpty) 'birth_date': birthDate,
        if (gender != null && gender!.isNotEmpty) 'gender': gender,
      };
}

class OtpRequest {
  final String phone;
  final String code;

  const OtpRequest({required this.phone, required this.code});

  Map<String, dynamic> toJson() => {'phone': phone, 'code': code};
}
