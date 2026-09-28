// lib/features/auth/presentation/providers/auth_provider.dart
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:safetaxi_cameroun/core/constants/app_constants.dart';
import 'package:safetaxi_cameroun/core/network/api_client.dart';
import 'package:safetaxi_cameroun/features/auth/data/models/user_model.dart';
import 'package:safetaxi_cameroun/features/auth/domain/entities/user_entity.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
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

  bool _isMockToken(String token) {
    return token.startsWith('mock_access_token_');
  }

  Future<void> _checkSession() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final token = await _storage.read(key: AppConstants.accessTokenKey);
      debugPrint('[CHECK SESSION] Token found: ${token != null}');
      if (token == null) {
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return;
      }

      debugPrint('[CHECK SESSION] Is mock token: ${_isMockToken(token)}');
      
      // For mock tokens, only load from storage
      if (_isMockToken(token)) {
        final storedUser = await _storage.read(key: AppConstants.userKey);
        debugPrint('[CHECK SESSION] Stored user found: ${storedUser != null}');
        if (storedUser != null && storedUser.isNotEmpty) {
          final decoded = jsonDecode(storedUser) as Map<String, dynamic>;
          final user = UserModel.fromJson(decoded);
          debugPrint('[CHECK SESSION] Reloaded mock user from storage, role: ${user.role}');
          state = state.copyWith(status: AuthStatus.authenticated, user: user);
          return;
        }
        // No stored user for mock token - treat as unauthenticated
        debugPrint('[CHECK SESSION] No stored user for mock token, setting unauthenticated');
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return;
      }

      // For real tokens, try loading from storage first, then API
      final storedUser = await _storage.read(key: AppConstants.userKey);
      if (storedUser != null && storedUser.isNotEmpty) {
        final decoded = jsonDecode(storedUser) as Map<String, dynamic>;
        final user = UserModel.fromJson(decoded);
        debugPrint('[CHECK SESSION] Reloaded user from storage, role: ${user.role}');
        state = state.copyWith(status: AuthStatus.authenticated, user: user);
        return;
      }

      final resp = await _api.getProfile();
      final user = UserModel.fromJson(resp.data as Map<String, dynamic>);
      await _saveUser(user);
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      debugPrint('[CHECK SESSION] Error: $e');
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
      // DEV MODE: Skip SMS server and use mock OTP
      // In production, uncomment the backend API call below
      final otpCode = '123456'; // Mock OTP for development
      
      /* // PRODUCTION: Use backend API for OTP
      final response = await _api.sendOtp(normalizedPhone);
      final otpCode = response.data['code'] as String?;
      */
      
      state = state.copyWith(
        status: AuthStatus.initial,
        isOtpSent: true,
        otpCode: otpCode,
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
    debugPrint('[VERIFY OTP] Called with phone: $phone, code: $code');
    debugPrint('[VERIFY OTP] Pending registration: ${state.pendingRegistration != null}');
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final normalizedPhone = _normalizePhone(phone);
      final pending = state.pendingRegistration;

      // DEV MODE: Accept mock OTP code "123456" - call real backend
      if (code == '123456') {
        // Call real backend API to create/authenticate user
        try {
          final payload = <String, dynamic>{
            'phone': normalizedPhone,
            'code': code,
          };
          
          // If pending registration, include user data
          if (pending != null) {
            payload['first_name'] = pending.firstName;
            payload['last_name'] = pending.lastName;
            payload['role'] = pending.role;
            if (pending.email != null && pending.email!.isNotEmpty) {
              payload['email'] = pending.email;
            }
            if (pending.password != null) {
              payload['password'] = pending.password;
            }
          }
          
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
          return;
        } catch (e) {
          debugPrint('[VERIFY OTP] Backend call failed: $e');
          // Fallback to mock only if backend fails
          if (pending == null) {
            debugPrint('[VERIFY OTP] No pending registration, loading from storage');
            final storedUserByPhone = await _storage.read(key: 'user_$normalizedPhone');
            if (storedUserByPhone != null && storedUserByPhone.isNotEmpty) {
              final decoded = jsonDecode(storedUserByPhone) as Map<String, dynamic>;
              final user = UserModel.fromJson(decoded);
              debugPrint('[VERIFY OTP] Loaded user by phone from storage, role: ${user.role}');
              
              final mockAuth = AuthResponse(
                accessToken: await _storage.read(key: AppConstants.accessTokenKey) ?? 'mock_access_token_${DateTime.now().millisecondsSinceEpoch}',
                refreshToken: await _storage.read(key: AppConstants.refreshTokenKey) ?? 'mock_refresh_token_${DateTime.now().millisecondsSinceEpoch}',
                user: user,
              );
              
              await _saveTokens(mockAuth.accessToken, mockAuth.refreshToken);
              await _saveUser(mockAuth.user);
              
              state = state.copyWith(
                status: AuthStatus.authenticated,
                user: mockAuth.user,
                clearPendingRegistration: true,
                isOtpSent: false,
              );
              return;
            }
          }
          state = state.copyWith(status: AuthStatus.error, error: 'Backend unavailable and no local user');
          return;
        }
      }
        
        // Convert string role to UserRole enum
        UserRole roleEnum = UserRole.passenger;
        if (pending?.role != null) {
          final roleStr = pending!.role.toLowerCase();
          debugPrint('[DEV MODE] Converting role: "$roleStr" to UserRole');
          roleEnum = switch (roleStr) {
            'driver' => UserRole.driver,
            'owner' => UserRole.owner,
            'admin' => UserRole.admin,
            _ => UserRole.passenger,
          };
          debugPrint('[DEV MODE] Converted to: $roleEnum');
        }
        
        // Create a mock authentication response for development
        final mockUser = UserModel(
          id: 'dev_user_${DateTime.now().millisecondsSinceEpoch}',
          phone: normalizedPhone,
          firstName: pending?.firstName ?? 'Utilisateur',
          lastName: pending?.lastName ?? 'Test',
          role: roleEnum,
          photoUrl: null,
          trustScore: 5.0,
          isVerified: true,
          isActive: true,
          createdAt: DateTime.now(),
          driverProfile: pending?.role == 'driver' ? {'license_verified': true, 'cni_verified': true} : null,
        );
        
        debugPrint('[DEV MODE] Created mock user with:');
        debugPrint('[DEV MODE] - First name: ${mockUser.firstName}');
        debugPrint('[DEV MODE] - Last name: ${mockUser.lastName}');
        debugPrint('[DEV MODE] - Role: ${mockUser.role}');
        
        final mockAuth = AuthResponse(
          accessToken: 'mock_access_token_${DateTime.now().millisecondsSinceEpoch}',
          refreshToken: 'mock_refresh_token_${DateTime.now().millisecondsSinceEpoch}',
          user: mockUser,
        );
        
        await _saveTokens(mockAuth.accessToken, mockAuth.refreshToken);
        await _saveUser(mockUser);
        
        debugPrint('[DEV MODE] Saved user with role: ${mockUser.role}');
        debugPrint('[DEV MODE] Verify saved user:');
        final verifyUser = await _storage.read(key: AppConstants.userKey);
        debugPrint('[DEV MODE] - User in storage: ${verifyUser != null ? "Yes" : "No"}');

        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: mockUser,
          clearPendingRegistration: true,
          isOtpSent: false,
        );
        return;
      }

      // PRODUCTION: Use backend API for OTP verification (works on web)
      // Check if driver registration with photos
      if (pending != null &&
          pending.role == 'driver' &&
          (pending.licensePhoto != null ||
              pending.vehiclePhoto != null ||
              pending.cniPhoto != null ||
              pending.profilePhoto != null)) {
        // Use multipart request for file upload with XFile
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
        });

        // Add files as bytes
        if (pending.licensePhoto != null) {
          final bytes = await pending.licensePhoto!.readAsBytes();
          formData.files.add(MapEntry(
            'license_photo',
            MultipartFile.fromBytes(bytes, filename: pending.licensePhoto!.name),
          ));
        }
        if (pending.vehiclePhoto != null) {
          final bytes = await pending.vehiclePhoto!.readAsBytes();
          formData.files.add(MapEntry(
            'vehicle_photo',
            MultipartFile.fromBytes(bytes, filename: pending.vehiclePhoto!.name),
          ));
        }
        if (pending.cniPhoto != null) {
          final bytes = await pending.cniPhoto!.readAsBytes();
          formData.files.add(MapEntry(
            'cni_photo',
            MultipartFile.fromBytes(bytes, filename: pending.cniPhoto!.name),
          ));
        }
        if (pending.profilePhoto != null) {
          final bytes = await pending.profilePhoto!.readAsBytes();
          formData.files.add(MapEntry(
            'profile_photo',
            MultipartFile.fromBytes(bytes, filename: pending.profilePhoto!.name),
          ));
        }

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
        // DEV MODE: For mock OTP without pending registration, load from storage
        if (code == '123456' && pending == null) {
          final storedUser = await _storage.read(key: AppConstants.userKey);
          if (storedUser != null && storedUser.isNotEmpty) {
            final decoded = jsonDecode(storedUser) as Map<String, dynamic>;
            final user = UserModel.fromJson(decoded);
            debugPrint('[DEV MODE] Login without pending - loaded user from storage, role: ${user.role}');
            
            final mockAuth = AuthResponse(
              accessToken: await _storage.read(key: AppConstants.accessTokenKey) ?? 'mock_access_token_${DateTime.now().millisecondsSinceEpoch}',
              refreshToken: await _storage.read(key: AppConstants.refreshTokenKey) ?? 'mock_refresh_token_${DateTime.now().millisecondsSinceEpoch}',
              user: user,
            );
            
            await _saveTokens(mockAuth.accessToken, mockAuth.refreshToken);
            await _saveUser(mockAuth.user);
            
            state = state.copyWith(
              status: AuthStatus.authenticated,
              user: mockAuth.user,
              clearPendingRegistration: true,
              isOtpSent: false,
            );
            return;
          }
        }
        
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
    debugPrint('[REGISTER] Role received: "${req.role}"');
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
    debugPrint('[REGISTER] Stored role in pendingReq: "${pendingReq.role}"');
    state = state.copyWith(
      status: AuthStatus.loading,
      pendingPhone: normalizedPhone,
      pendingRegistration: pendingReq,
    );
    debugPrint('[REGISTER] State updated with pending role: "${state.pendingRegistration?.role}"');
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

  Future<void> updateProfilePhoto(dynamic photo) async {
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
    // Also save by phone number for login
    await _storage.write(
      key: 'user_${user.phone}',
      value: jsonEncode(user.toJson()),
    );
    debugPrint('[SAVE USER] Saved user with phone: ${user.phone}');
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
