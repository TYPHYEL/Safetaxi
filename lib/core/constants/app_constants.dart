// lib/core/constants/app_constants.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Determines the correct API host depending on the runtime platform.
/// - Web browser → localhost
/// - Android emulator → 10.0.2.2 (emulator's alias for host loopback)
/// - Physical Android device → use local network IP (192.168.0.64)
/// - iOS / Desktop → localhost (override with env for real server)
String _resolveHost() {
  if (kIsWeb) return 'http://127.0.0.1:8000';
  try {
    if (Platform.isAndroid) return 'http://192.168.0.64:8000';
  } catch (_) {}
  return 'http://127.0.0.1:8000';
}

class AppConstants {
  // API
  static final String baseUrl = '${_resolveHost()}/api';
  static final String wsUrl = '${_resolveHost().replaceFirst('http', 'ws')}/ws';
  static const int connectTimeout = 30;
  static const int receiveTimeout = 30;

  // Firebase paths
  static const String firebaseTripsPath = 'trips';
  static const String firebaseLocationsPath = 'locations';
  static const String firebaseSosPath = 'sos_alerts';

  // Storage keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'user_data';
  static const String userRoleKey = 'user_role';
  static const String onboardingKey = 'onboarding_done';

  // GPS
  static const int gpsIntervalSeconds = 3;
  static const int gpsDistanceFilterMeters = 10;
  static const double sosRadiusKm = 2.0;

  // Trust Score
  static const double minTrustScore = 0.0;
  static const double maxTrustScore = 5.0;
  static const double minAcceptableScore = 2.5;

  // QR Code
  static const String qrPrefix = 'safetaxi://taxi/';

  // IA Qwen (placeholder — configuré via build env en prod)
  static const String qwenApiKey = String.fromEnvironment(
    'QWEN_API_KEY',
    defaultValue: '',
  );
  static const String qwenBaseUrl = String.fromEnvironment(
    'QWEN_BASE_URL',
    defaultValue: 'https://dashscope.aliyuncs.com/api/v1',
  );

  // Pagination
  static const int pageSize = 20;

  // Yaoundé centre (coordonnées par défaut)
  static const double defaultLat = 3.8480;
  static const double defaultLng = 11.5021;

  // Rôles
  static const String rolePassenger = 'passenger';
  static const String roleDriver = 'driver';
  static const String roleOwner = 'owner';
  static const String roleAdmin = 'admin';
}

class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String otpVerify = '/otp-verify';
  static const String roleSelect = '/role-select';

  // Passager
  static const String homePassenger = '/home-passenger';
  static const String scanTaxi = '/scan-taxi';
  static const String passengers = '/passengers';

  // Chauffeur
  static const String homeDriver = '/home-driver';
  static const String biometric = '/biometric';
  static const String activateShift = '/activate-shift';

  // Commun
  static const String map = '/map';
  static const String tripActive = '/trip-active';
  static const String sos = '/sos';
  static const String history = '/history';
  static const String profil = '/profil';
  static const String notifications = '/notifications';
  static const String trustScore = '/trust-score';
  static const String settings = '/settings';
  static const String incident = '/incident';
  static const String notation = '/notation';
  static const String taxiDetail = '/taxi/:id';

  // Propriétaire
  static const String myTaxis = '/my-taxis';
  static const String manageDrivers = '/manage-drivers';
  static const String taxiCreate = '/taxi-create';

  // Admin
  static const String adminDashboard = '/admin';
  static const String adminDrivers = '/admin/drivers';
  static const String adminTaxis = '/admin/taxis';
  static const String adminAlerts = '/admin/alerts';

  // Chauffeur documents
  static const String driverDocuments = '/driver/documents';
  static const String taxiQr = '/taxi-qr';
  static const String emergencyContacts = '/emergency-contacts';

  // IA
  static const String aiAssistant = '/ai-assistant';
}
