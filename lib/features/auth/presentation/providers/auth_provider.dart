// lib/features/auth/presentation/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:safetaxi_cameroun/core/constants/app_constants.dart';
import 'package:safetaxi_cameroun/core/network/api_client.dart';
import 'package:safetaxi_cameroun/features/auth/data/models/user_model.dart';
import 'package:safetaxi_cameroun/features/auth/domain/entities/user_entity.dart';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:firebase_auth/firebase_auth.dart';

// ─── Providers infrastructure ────────────────────────────

// Global provider for OTP screen visibility
final showOtpScreenProvider = StateProvider<bool>((ref) => false);

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  ),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(secureStorageProvider)),
);

// ─── État d'authentification ─────────────────────────────

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final UserEntity? user;
  final String? error;
  final bool isOtpSent;
  final String? pendingPhone;
  final String? otpCode;
  final String? verificationId;
  final bool shouldNavigateToOtp;
  // Données d'inscription en attente de validation OTP
  final RegisterRequest? pendingRegistration;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
    this.isOtpSent = false,
    this.pendingPhone,
    this.otpCode,
    this.verificationId,
    this.shouldNavigateToOtp = false,
    this.pendingRegistration,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserEntity? user,
    String? error,
    bool? isOtpSent,
    String? pendingPhone,
    String? otpCode,
    String? verificationId,
    bool? shouldNavigateToOtp,
    RegisterRequest? pendingRegistration,
    bool clearPendingRegistration = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error ?? this.error,
      isOtpSent: isOtpSent ?? this.isOtpSent,
      pendingPhone: pendingPhone ?? this.pendingPhone,
      otpCode: otpCode ?? this.otpCode,
      verificationId: verificationId ?? this.verificationId,
      shouldNavigateToOtp: shouldNavigateToOtp ?? this.shouldNavigateToOtp,
      pendingRegistration: clearPendingRegistration
          ? null
          : pendingRegistration ?? this.pendingRegistration,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
}

// ─── Notifier ────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _api;
  final FlutterSecureStorage _storage;

  AuthNotifier(this._api, this._storage) : super(const AuthState()) {
    _checkSession();
  }

  Future<void> _checkSession() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final token = await _storage.read(key: AppConstants.accessTokenKey);
      if (token == null) {
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return;
      }

      final storedUser = await _storage.read(key: AppConstants.userKey);
      if (storedUser != null && storedUser.isNotEmpty) {
        final decoded = jsonDecode(storedUser) as Map<String, dynamic>;
        final user = UserModel.fromJson(decoded);
        state = state.copyWith(status: AuthStatus.authenticated, user: user);
        return;
      }

      final resp = await _api.getProfile();
      final user = UserModel.fromJson(resp.data as Map<String, dynamic>);
      await _saveUser(user);
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } catch (_) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  String _normalizePhone(String phone) {
    final raw = phone.trim();
    if (raw.startsWith('+')) return raw;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0') && digits.length == 9) {
      return '+237${digits.substring(1)}';
    }
    if (digits.startsWith('237') && digits.length == 12) {
      return '+$digits';
    }
    if (digits.length == 9) {
      return '+237$digits';
    }
    return '+$digits';
  }

  Future<void> sendOtp(String phone) async {
    final normalizedPhone = _normalizePhone(phone);
    state = state.copyWith(
      status: AuthStatus.loading,
      pendingPhone: normalizedPhone,
      isOtpSent: false,
    );
    try {
      // Use backend API for OTP (works on web without Firebase Phone Auth issues)
      final response = await _api.sendOtp(normalizedPhone);
      // In DEBUG mode the backend returns the OTP code for convenience;
      // in production, the code is sent via SMS only.
      final otpCode = response.data['code'] as String?;
      state = state.copyWith(
        status: AuthStatus.initial,
        isOtpSent: true,
        otpCode: otpCode, // null in production
        shouldNavigateToOtp: true,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: _parseError(e),
      );
    }
  }

  Future<void> verifyOtp(String phone, String code) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      // Use backend API for OTP verification (works on web)
      final normalizedPhone = _normalizePhone(phone);
      final pending = state.pendingRegistration;

      // Check if driver registration with photos
      if (pending != null &&
          pending.role == 'driver' &&
          (pending.licensePhoto != null ||
              pending.vehiclePhoto != null ||
              pending.cniPhoto != null ||
              pending.profilePhoto != null)) {
        // Use multipart request for file upload
        final formData = FormData.fromMap({
          'phone': normalizedPhone,
          'code': code,
          'first_name': pending.firstName,
          'last_name': pending.lastName,
          'role': pending.role,
          if (pending.email != null && pending.email!.isNotEmpty)
            'email': pending.email,
          if (pending.password != null) 'password': pending.password,
          if (pending.birthDate != null && pending.birthDate!.isNotEmpty)
            'birth_date': pending.birthDate,
          if (pending.gender != null && pending.gender!.isNotEmpty)
            'gender': pending.gender,
          if (pending.licensePhoto != null)
            'license_photo': MultipartFile.fromFileSync(
              pending.licensePhoto!.path,
              filename: p.basename(pending.licensePhoto!.path),
            ),
          if (pending.vehiclePhoto != null)
            'vehicle_photo': MultipartFile.fromFileSync(
              pending.vehiclePhoto!.path,
              filename: p.basename(pending.vehiclePhoto!.path),
            ),
          if (pending.cniPhoto != null)
            'cni_photo': MultipartFile.fromFileSync(
              pending.cniPhoto!.path,
              filename: p.basename(pending.cniPhoto!.path),
            ),
          if (pending.profilePhoto != null)
            'profile_photo': MultipartFile.fromFileSync(
              pending.profilePhoto!.path,
              filename: p.basename(pending.profilePhoto!.path),
            ),
        });

        final resp = await _api.verifyOtpWithFiles(formData);
        final auth = AuthResponse.fromJson(resp.data as Map<String, dynamic>);
        await _saveTokens(auth.accessToken, auth.refreshToken);
        await _saveUser(auth.user);

        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: auth.user,
          clearPendingRegistration: true,
          isOtpSent: false,
        );
      } else {
        // Standard OTP verification without files
        final payload = <String, dynamic>{
          'phone': normalizedPhone,
          'code': code,
          if (pending != null) ...{
            'first_name': pending.firstName,
            'last_name': pending.lastName,
            'role': pending.role,
            if (pending.email != null && pending.email!.isNotEmpty)
              'email': pending.email,
          },
        };
        final resp = await _api.verifyOtp(payload);

        final auth = AuthResponse.fromJson(resp.data as Map<String, dynamic>);
        await _saveTokens(auth.accessToken, auth.refreshToken);
        await _saveUser(auth.user);

        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: auth.user,
          clearPendingRegistration: true,
          isOtpSent: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: _parseError(e),
      );
    }
  }

  Future<void> register(RegisterRequest req) async {
    final normalizedPhone = _normalizePhone(req.phone);
    // Stocker les données d'inscription avant l'OTP (incluant les photos pour chauffeurs)
    final pendingReq = RegisterRequest(
      phone: normalizedPhone,
      firstName: req.firstName,
      lastName: req.lastName,
      role: req.role,
      email: req.email,
      password: req.password,
      licensePhoto: req.licensePhoto,
      vehiclePhoto: req.vehiclePhoto,
      cniPhoto: req.cniPhoto,
      profilePhoto: req.profilePhoto,
      birthDate: req.birthDate,
      gender: req.gender,
    );
    state = state.copyWith(
      status: AuthStatus.loading,
      pendingPhone: normalizedPhone,
      pendingRegistration: pendingReq,
    );
    // OTP backend : connexion existante ou création passager à la vérification
    await sendOtp(normalizedPhone);
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    await _storage.deleteAll();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    try {
      final resp = await _api.updateProfile(data);
      final user = UserModel.fromJson(resp.data as Map<String, dynamic>);
      await _saveUser(user);
      state = state.copyWith(user: user);
    } catch (e) {
      state = state.copyWith(error: _parseError(e));
    }
  }

  Future<void> updateProfilePhoto(File photo) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final resp = await _api.updateProfilePhoto(photo);
      final user = UserModel.fromJson(resp.data as Map<String, dynamic>);
      await _saveUser(user);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
      );
    } catch (e) {
      state = state.copyWith(error: _parseError(e));
    }
  }

  Future<void> _saveTokens(String access, String refresh) async {
    await _storage.write(key: AppConstants.accessTokenKey, value: access);
    await _storage.write(key: AppConstants.refreshTokenKey, value: refresh);
  }

  Future<void> _saveUser(UserModel user) async {
    await _storage.write(
      key: AppConstants.userKey,
      value: jsonEncode(user.toJson()),
    );
  }

  String _parseFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Numéro de téléphone invalide. Utilisez le format +237XXXXXXXXX';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez dans quelques minutes.';
      case 'quota-exceeded':
        return 'Quota SMS dépassé. Contactez le support.';
      case 'invalid-verification-code':
        return 'Code OTP incorrect. Vérifiez et réessayez.';
      case 'session-expired':
        return 'Session expirée. Demandez un nouveau code.';
      case 'network-request-failed':
        return 'Problème de connexion réseau. Vérifiez votre internet.';
      case 'app-not-authorized':
        return 'Application non autorisée. Contactez le support.';
      default:
        return e.message ?? 'Erreur Firebase: ${e.code}';
    }
  }

  String _parseError(dynamic e) {
    if (e is FirebaseAuthException) return _parseFirebaseError(e);
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['detail'] != null) {
        return data['detail'].toString();
      }
      return e.message ?? 'Erreur réseau';
    }
    if (e is Exception) return e.toString().replaceAll('Exception: ', '');
    return 'Une erreur est survenue';
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(
    ref.watch(apiClientProvider),
    ref.watch(secureStorageProvider),
  ),
);

// Raccourcis pratiques
final currentUserProvider = Provider<UserEntity?>((ref) {
  return ref.watch(authProvider).user;
});

final userRoleProvider = Provider<UserRole?>((ref) {
  return ref.watch(currentUserProvider)?.role;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});
