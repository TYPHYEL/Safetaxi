// lib/core/network/firebase_service.dart
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

/// Interface for the notification service to allow test injection.
abstract class FirebaseNotificationServiceBase {
  Future<void> init();
  Future<String?> getToken();
  Future<void> subscribeToTopic(String topic);
  Future<void> unsubscribeFromTopic(String topic);
}

/// Top-level instance that can be overridden in tests.
FirebaseNotificationServiceBase firebaseNotificationService =
    FirebaseNotificationService();

// Handler background (top-level function obligatoire)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  _log.d('FCM background: ${message.messageId}');
}

class FirebaseNotificationService implements FirebaseNotificationServiceBase {
  static final FirebaseNotificationService _instance =
      FirebaseNotificationService._();
  factory FirebaseNotificationService() => _instance;
  FirebaseNotificationService._();

  final _fcm = FirebaseMessaging.instance;
  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'safetaxi_alerts';
  static const _channelName = 'SafeTaxi Alertes';
  static const _sosChannelId = 'safetaxi_sos';
  static const _sosChannelName = 'SafeTaxi SOS';

  @override
  Future<void> init() async {
    // Demander les permissions
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
    );
    _log.d('FCM permission: ${settings.authorizationStatus}');

    // Initialiser local notifications
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Créer les canaux Android
    await _createChannels();

    // Handlers
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    // Message initial (app ouverte depuis une notif)
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _handleMessage(initial);

    // Token FCM
    final token = await _fcm.getToken();
    _log.d('FCM token: $token');
  }

  @override
  Future<String?> getToken() => _fcm.getToken();

  @override
  Future<void> subscribeToTopic(String topic) => _fcm.subscribeToTopic(topic);

  @override
  Future<void> unsubscribeFromTopic(String topic) =>
      _fcm.unsubscribeFromTopic(topic);

  Future<void> _createChannels() async {
    const normal = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Notifications générales SafeTaxi',
      importance: Importance.high,
    );
    const sos = AndroidNotificationChannel(
      _sosChannelId,
      _sosChannelName,
      description: 'Alertes SOS urgentes',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(normal);
    await androidPlugin?.createNotificationChannel(sos);
  }

  void _onForegroundMessage(RemoteMessage message) {
    _log.d('FCM foreground: ${message.messageId}');
    final isSos = message.data['type'] == 'sos_alert';
    _showLocalNotification(message, isSos: isSos);
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    _log.d('FCM opened: ${message.messageId}');
    _handleMessage(message);
  }

  void _handleMessage(RemoteMessage message) {
    // TODO: naviguer vers l'écran approprié selon message.data['type']
    final type = message.data['type'] as String?;
    final tripId = message.data['trip_id'] as String?;
    _log.d('Handle message: type=$type tripId=$tripId');
  }

  Future<void> _showLocalNotification(
    RemoteMessage message, {
    bool isSos = false,
  }) async {
    final notification = message.notification;
    if (notification == null) return;

    final androidDetails = AndroidNotificationDetails(
      isSos ? _sosChannelId : _channelId,
      isSos ? _sosChannelName : _channelName,
      importance: isSos ? Importance.max : Importance.high,
      priority: isSos ? Priority.max : Priority.high,
      color: isSos ? const Color(0xFFFF3B30) : const Color(0xFF00C896),
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel:
          isSos ? InterruptionLevel.critical : InterruptionLevel.active,
    );

    await _plugin.show(
      message.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode(message.data),
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    _log.d('Notification tapped: ${response.payload}');
    // TODO: parser le payload et naviguer
  }
}
