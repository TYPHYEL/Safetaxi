// lib/features/profil/presentation/screens/notifications_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:safetaxi_cameroun/core/constants/app_constants.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';
import 'package:timeago/timeago.dart' as timeago;

// ─── Modèle notification locale ──────────────────────────

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // 'sos' | 'passenger' | 'rating' | 'trip' | 'system'
  final DateTime receivedAt;
  bool isRead;
  final Map<String, dynamic> data;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.receivedAt,
    this.isRead = false,
    this.data = const {},
  });

  factory AppNotification.fromRemote(RemoteMessage msg) {
    return AppNotification(
      id: msg.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: msg.notification?.title ?? 'SafeTaxi',
      body: msg.notification?.body ?? '',
      type: msg.data['type'] as String? ?? 'system',
      receivedAt: DateTime.now(),
      data: Map<String, dynamic>.from(msg.data),
    );
  }
}

// ─── Provider des notifications ──────────────────────────

class NotificationsNotifier extends StateNotifier<List<AppNotification>> {
  StreamSubscription<RemoteMessage>? _fcmSub;

  NotificationsNotifier() : super(_initialNotifications()) {
    _listenToFcm();
  }

  static List<AppNotification> _initialNotifications() {
    // Notifications de démonstration initiales
    return [
      AppNotification(
        id: 'demo-1',
        title: 'Bienvenue sur SafeTaxi',
        body: 'Votre compte est actif. Activez les notifications SOS.',
        type: 'system',
        receivedAt: DateTime.now().subtract(const Duration(hours: 2)),
        isRead: false,
      ),
    ];
  }

  void _listenToFcm() {
    _fcmSub = FirebaseMessaging.onMessage.listen((msg) {
      final notif = AppNotification.fromRemote(msg);
      state = [notif, ...state];
    });
  }

  void addNotification(AppNotification n) {
    state = [n, ...state];
  }

  void markRead(String id) {
    state = state.map((n) {
      if (n.id == id) n.isRead = true;
      return n;
    }).toList();
  }

  void markAllRead() {
    state = state.map((n) {
      n.isRead = true;
      return n;
    }).toList();
  }

  void remove(String id) {
    state = state.where((n) => n.id != id).toList();
  }

  void clearAll() => state = [];

  int get unreadCount => state.where((n) => !n.isRead).length;

  @override
  void dispose() {
    _fcmSub?.cancel();
    super.dispose();
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<AppNotification>>(
  (ref) => NotificationsNotifier(),
);

final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).where((n) => !n.isRead).length;
});

// ─── Écran Notifications ─────────────────────────────────

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifs = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            const Text('Notifications'),
            if (unread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unread',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (notifs.isNotEmpty)
            PopupMenuButton<String>(
              color: AppColors.surface,
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) {
                if (v == 'read_all') {
                  ref.read(notificationsProvider.notifier).markAllRead();
                } else if (v == 'clear_all') {
                  ref.read(notificationsProvider.notifier).clearAll();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'read_all',
                  child: Row(children: [
                    Icon(Icons.done_all_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Tout marquer lu'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Row(children: [
                    Icon(Icons.delete_sweep_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Tout supprimer'),
                  ]),
                ),
              ],
            ),
        ],
      ),
      body: notifs.isEmpty
          ? _buildEmpty()
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: notifs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _NotifTile(
                notif: notifs[i],
                onTap: () {
                  ref
                      .read(notificationsProvider.notifier)
                      .markRead(notifs[i].id);
                  _handleNotifTap(context, notifs[i]);
                },
                onDismiss: () {
                  ref.read(notificationsProvider.notifier).remove(notifs[i].id);
                },
              ),
            ),
    );
  }

  void _handleNotifTap(BuildContext context, AppNotification n) {
    switch (n.type) {
      case 'sos':
        context.push(AppRoutes.sos);
        break;
      case 'trip':
        final tripId = n.data['trip_id'] as String?;
        if (tripId != null) {
          context.push('${AppRoutes.tripActive}?tripId=$tripId');
        }
        break;
      case 'rating':
        context.push(AppRoutes.trustScore);
        break;
      default:
        break;
    }
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none_rounded,
              size: 64, color: AppColors.textMuted),
          SizedBox(height: 16),
          Text('Aucune notification', style: AppTextStyles.headlineMedium),
          SizedBox(height: 8),
          Text(
            'Vous serez notifié des alertes SOS,\nnouveaux passagers et trajets.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final AppNotification notif;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotifTile({
    required this.notif,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.dangerSurface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_rounded, color: AppColors.danger),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: notif.isRead
                ? AppColors.card
                : AppColors.primarySurface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: notif.isRead
                  ? AppColors.border
                  : AppColors.primary.withValues(alpha: 0.3),
              width: notif.isRead ? 0.5 : 1,
            ),
          ),
          child: Row(
            children: [
              _NotifIcon(type: notif.type),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notif.title,
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: notif.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!notif.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(notif.body, style: AppTextStyles.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                      timeago.format(notif.receivedAt, locale: 'fr'),
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotifIcon extends StatelessWidget {
  final String type;
  const _NotifIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (type) {
      'sos' => (Icons.emergency_rounded, AppColors.danger),
      'passenger' => (Icons.person_add_rounded, AppColors.driverColor),
      'rating' => (Icons.star_rounded, AppColors.ownerColor),
      'trip' => (Icons.local_taxi_rounded, AppColors.taxiYellow),
      _ => (Icons.notifications_rounded, AppColors.textSecondary),
    };

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}
