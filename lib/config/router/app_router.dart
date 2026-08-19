// lib/config/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safetaxi_cameroun/core/constants/app_constants.dart';
import 'package:safetaxi_cameroun/features/auth/domain/entities/user_entity.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/providers/auth_provider.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/screens/splash_screen.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/screens/login_screen.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/screens/register_screen.dart'
    as auth_reg;
import 'package:safetaxi_cameroun/features/auth/presentation/screens/otp_screen.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/screens/role_select_screen.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/screens/home_passenger_screen.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/screens/home_driver_screen.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/screens/driver_documents_screen.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/screens/driver_verification_screen.dart';
import 'package:safetaxi_cameroun/features/trajet/presentation/screens/trip_active_screen.dart';
import 'package:safetaxi_cameroun/features/trajet/presentation/screens/scan_taxi_screen.dart';
import 'package:safetaxi_cameroun/features/trajet/presentation/screens/passengers_screen.dart';
import 'package:safetaxi_cameroun/features/trajet/presentation/screens/history_screen.dart';
import 'package:safetaxi_cameroun/features/trajet/presentation/screens/deposit_request_screen.dart';
import 'package:safetaxi_cameroun/features/trajet/presentation/screens/deposit_notification_screen.dart';
import 'package:safetaxi_cameroun/features/map/presentation/screens/map_screen.dart'
    hide NotationScreen, AdminDashboardScreen, AdminDriversScreen;
import 'package:safetaxi_cameroun/features/sos/presentation/screens/sos_screen.dart';
import 'package:safetaxi_cameroun/features/sos/presentation/screens/incident_screen.dart';
import 'package:safetaxi_cameroun/features/notation/presentation/screens/notation_screen.dart';
import 'package:safetaxi_cameroun/features/profil/presentation/screens/profil_screen.dart';
import 'package:safetaxi_cameroun/features/profil/presentation/screens/notifications_screen.dart';
import 'package:safetaxi_cameroun/features/profil/presentation/screens/emergency_contacts_screen.dart';
import 'package:safetaxi_cameroun/features/taxi/presentation/screens/taxi_detail_screen.dart';
import 'package:safetaxi_cameroun/features/taxi/presentation/screens/taxi_qr_screen.dart';
import 'package:safetaxi_cameroun/features/taxi/presentation/screens/my_taxis_screen.dart';
import 'package:safetaxi_cameroun/features/taxi/presentation/screens/taxi_create_screen.dart';
import 'package:safetaxi_cameroun/features/taxi/presentation/screens/manage_drivers_screen.dart';
import 'package:safetaxi_cameroun/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:safetaxi_cameroun/features/admin/presentation/screens/admin_drivers_screen.dart';
import 'package:safetaxi_cameroun/features/ai/presentation/screens/ai_assistant_screen.dart';

class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, __) {
      notifyListeners();
    });
  }
}

final routerRefreshProvider = Provider<RouterRefreshNotifier>((ref) {
  final notifier = RouterRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(routerRefreshProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isAuth = authState.isAuthenticated;
      final isLoad = authState.status == AuthStatus.loading;
      final path = state.uri.path;
      debugPrint(
        '[router] redirect check: path=$path, status=${authState.status}, '
        'isAuth=$isAuth, isOtpSent=${authState.isOtpSent}, '
        'pendingPhone=${authState.pendingPhone}',
      );

      final publicRoutes = [
        AppRoutes.splash,
        AppRoutes.onboarding,
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.otpVerify,
        AppRoutes.roleSelect,
      ];

      final isPublicRoute = publicRoutes.contains(path);

      if (isLoad) {
        final target = isPublicRoute ? null : AppRoutes.splash;
        debugPrint('[router] loading redirect => ${target ?? 'stay'}');
        return target;
      }

      if (!isAuth && path == AppRoutes.splash) {
        debugPrint('[router] unauthenticated on splash => ${AppRoutes.login}');
        return AppRoutes.login;
      }

      if (!isAuth && !isPublicRoute) {
        debugPrint(
            '[router] unauthenticated on protected route => ${AppRoutes.login}');
        return AppRoutes.login;
      }

      if (isAuth && isPublicRoute) {
        final target = _homeForRole(authState.user?.role);
        debugPrint('[router] authenticated on public route => $target');
        return target;
      }

      debugPrint('[router] no redirect for path=$path');
      return null;
    },
    routes: [
      // ── Splash & Auth ───────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, state) {
          final role = state.uri.queryParameters['role'] ?? 'passenger';
          return auth_reg.RegisterScreen(role: role);
        },
      ),
      GoRoute(
        path: AppRoutes.otpVerify,
        builder: (_, state) {
          final phone = state.uri.queryParameters['phone'] ?? '';
          return OtpScreen(phone: phone);
        },
      ),
      GoRoute(
        path: AppRoutes.roleSelect,
        builder: (_, __) => const RoleSelectScreen(),
      ),

      // ── Passager ────────────────────────────────────────
      GoRoute(
        path: AppRoutes.homePassenger,
        builder: (_, __) => const HomePassengerScreen(),
      ),
      GoRoute(
        path: AppRoutes.scanTaxi,
        builder: (_, __) => const ScanTaxiScreen(),
      ),
      GoRoute(
        path: AppRoutes.depositRequest,
        builder: (_, __) => const DepositRequestScreen(),
      ),
      GoRoute(
        path: AppRoutes.depositNotification,
        builder: (_, state) {
          final depositId = state.uri.queryParameters['depositId'] ?? '';
          // For now, we'll need to fetch the deposit data
          // In a real app, you might pass the deposit object via state
          return const DepositNotificationScreen(deposit: null);
        },
      ),

      // ── Chauffeur ───────────────────────────────────────
      GoRoute(
        path: AppRoutes.homeDriver,
        builder: (_, __) => const HomeDriverScreen(),
      ),
      GoRoute(
        path: AppRoutes.driverDocuments,
        builder: (_, __) => const DriverDocumentsScreen(),
      ),
      GoRoute(
        path: AppRoutes.biometric,
        builder: (_, __) => const DriverVerificationScreen(),
      ),

      // ── Carte & Trajets ─────────────────────────────────
      GoRoute(
        path: AppRoutes.map,
        builder: (_, state) {
          final tripId = state.uri.queryParameters['tripId'];
          return MapScreen(tripId: tripId);
        },
      ),
      GoRoute(
        path: AppRoutes.tripActive,
        builder: (_, state) {
          final tripId = state.uri.queryParameters['tripId'] ?? '';
          return TripActiveScreen(tripId: tripId);
        },
      ),
      GoRoute(
        path: AppRoutes.passengers,
        builder: (_, state) {
          final tripId = state.uri.queryParameters['tripId'] ?? '';
          return PassengersScreen(tripId: tripId);
        },
      ),
      GoRoute(
        path: AppRoutes.history,
        builder: (_, __) => const HistoryScreen(),
      ),

      // ── SOS ─────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.sos,
        builder: (_, __) => const SosScreen(),
      ),
      GoRoute(
        path: AppRoutes.incident,
        builder: (_, state) {
          final tripId = state.uri.queryParameters['tripId'] ?? '';
          return IncidentScreen(tripId: tripId);
        },
      ),

      // ── Notation ─────────────────────────────────────────
      GoRoute(
        path: AppRoutes.notation,
        builder: (_, state) {
          final tripId = state.uri.queryParameters['tripId'] ?? '';
          final userId = state.uri.queryParameters['userId'] ?? '';
          final isDriver = state.uri.queryParameters['isDriver'] == 'true';
          return NotationScreen(
              tripId: tripId, targetUserId: userId, targetIsDriver: isDriver);
        },
      ),

      // ── Profil ──────────────────────────────────────────
      GoRoute(
        path: AppRoutes.profil,
        builder: (_, __) => const ProfilScreen(),
      ),
      GoRoute(
        path: AppRoutes.trustScore,
        builder: (_, __) => const TrustScoreScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.emergencyContacts,
        builder: (_, __) => const EmergencyContactsScreen(),
      ),

      // ── Taxi ─────────────────────────────────────────────
      GoRoute(
        path: '/taxi/:id',
        builder: (_, state) {
          final id = state.pathParameters['id'] ?? '';
          return TaxiDetailScreen(taxiId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.myTaxis,
        builder: (_, __) => const MyTaxisScreen(),
      ),
      GoRoute(
        path: AppRoutes.taxiCreate,
        builder: (_, __) => const TaxiCreateScreen(),
      ),
      GoRoute(
        path: AppRoutes.taxiQr,
        builder: (_, __) => const TaxiQrScreen(),
      ),
      GoRoute(
        path: AppRoutes.manageDrivers,
        builder: (_, state) {
          final taxiId = state.uri.queryParameters['taxiId'] ?? '';
          return ManageDriversScreen(taxiId: taxiId);
        },
      ),

      // ── Admin ────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.adminDashboard,
        builder: (_, __) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminDrivers,
        builder: (_, __) => const AdminDriversScreen(),
      ),

      // ── Assistant IA ────────────────────────────────────
      GoRoute(
        path: AppRoutes.aiAssistant,
        builder: (_, __) => const AiAssistantScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text('Page introuvable: ${state.uri}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Retour à l\'accueil'),
            ),
          ],
        ),
      ),
    ),
  );
});

String _homeForRole(UserRole? role) {
  switch (role) {
    case UserRole.driver:
      return AppRoutes.homeDriver;
    case UserRole.owner:
      return AppRoutes.myTaxis;
    case UserRole.admin:
      return AppRoutes.adminDashboard;
    default:
      return AppRoutes.homePassenger;
  }
}
