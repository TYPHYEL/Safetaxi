// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:safetaxi_cameroun/config/router/app_router.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';
import 'package:safetaxi_cameroun/core/network/firebase_service.dart';
import 'package:safetaxi_cameroun/core/services/location_service.dart';
import 'package:safetaxi_cameroun/core/services/settings_service.dart';
import 'package:safetaxi_cameroun/core/services/cache_service.dart';
import 'package:safetaxi_cameroun/core/constants/app_constants.dart';

// ─── Handler FCM background (top-level function) ─────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM background: ${message.messageId}');
}

// When running widget tests we may want to disable FCM handlers to avoid
// platform channel calls. Tests can set this flag to `true` before
// pumping the app.
bool disableFcmInTests = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ─── Orientation portrait uniquement ────────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ─── Thème de la barre de statut ──────────────────────
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.background,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // ─── Hive — cache offline ──────────────────────────────
  await Hive.initFlutter();
  await SettingsService.init();
  await CacheService.init();

  // ─── Firebase ───────────────────────────────────────────
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initialiser les notifications push via le service injectable
    await firebaseNotificationService.init();

    // Subscribe aux alerts SOS actives
    await firebaseNotificationService.subscribeToTopic('sos_alerts');

    // Subscribe aux alertes dans la zone Yaoundé
    await firebaseNotificationService.subscribeToTopic('yaounde_alerts');
  } catch (e) {
    // Firebase non configuré (dev local sans google-services.json)
    debugPrint('Firebase non initialisé: $e');
  }

  runApp(
    const ProviderScope(
      child: SafeTaxiApp(),
    ),
  );
}

class SafeTaxiApp extends ConsumerStatefulWidget {
  const SafeTaxiApp({super.key});

  @override
  ConsumerState<SafeTaxiApp> createState() => _SafeTaxiAppState();
}

class _SafeTaxiAppState extends ConsumerState<SafeTaxiApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initLocation();
    if (!disableFcmInTests) {
      _setupFcmHandlers();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ─── Initialiser le service de localisation ─────────────
  Future<void> _initLocation() async {
    // Demander la permission GPS au démarrage si l'utilisateur
    // est un chauffeur
    final locationSvc = LocationTrackingService();
    await locationSvc.requestPermissions();
  }

  // ─── Setup FCM handlers (foreground + open app) ─────────
  void _setupFcmHandlers() {
    final messaging = FirebaseMessaging.instance;

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM foreground: ${message.notification?.title}');
      // Les notifications sont déjà gérées par NotificationsScreen via onMessage stream
      // Optionnel: afficher un snackbar ici
    });

    // App ouverte via notification (depuis background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message);
    });

    // App démarrée via notification (terminée)
    messaging.getInitialMessage().then((message) {
      if (message != null) {
        _handleNotificationTap(message);
      }
    });
  }

  void _handleNotificationTap(RemoteMessage message) {
    final router = ref.read(routerProvider);
    final type = message.data['type'] as String?;

    switch (type) {
      case 'sos':
        router.push(AppRoutes.sos);
        break;
      case 'trip':
        final tripId = message.data['trip_id'] as String?;
        if (tripId != null) {
          router.push('${AppRoutes.tripActive}?tripId=$tripId');
        }
        break;
      case 'rating':
        router.push(AppRoutes.trustScore);
        break;
      case 'passenger':
        router.push(AppRoutes.notifications);
        break;
      default:
        router.push(AppRoutes.notifications);
    }
  }

  // ─── Gérer le cycle de vie de l'app ───────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // ignore: unused_local_variable
    final locationSvc = ref.read(locationTrackingProvider);

    switch (state) {
      case AppLifecycleState.resumed:
        // L'app revient au premier plan
        debugPrint('App resumed');
        break;
      case AppLifecycleState.paused:
        // L'app passe en arrière-plan
        // Le GPS continue si un trajet est actif
        debugPrint('App paused — GPS continues if active');
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'SafeTaxi Cameroun',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'CM'),
        Locale('fr', 'FR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('fr', 'CM'),
      // Optimisations de performance
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child!,
        );
      },
    );
  }
}
