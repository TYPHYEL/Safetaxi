// lib/features/trajet/presentation/screens/trip_active_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:safetaxi_cameroun/core/constants/app_constants.dart';
import 'package:safetaxi_cameroun/features/trajet/presentation/providers/trajet_provider.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/providers/auth_provider.dart';
import 'package:safetaxi_cameroun/features/auth/domain/entities/user_entity.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';

String formatTripPreview(String tripId) {
  final normalized = tripId.trim();
  if (normalized.isEmpty) return '—';
  if (normalized.length <= 8) return normalized;
  return '${normalized.substring(0, 8)}...';
}

class TripActiveScreen extends ConsumerStatefulWidget {
  final String tripId;
  const TripActiveScreen({super.key, required this.tripId});
  @override
  ConsumerState<TripActiveScreen> createState() => _TripActiveScreenState();
}

class _TripActiveScreenState extends ConsumerState<TripActiveScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dotCtrl;
  late final Animation<double> _dotAnim;

  // ─── Timer et GPS vitesse ──────────────────────────────
  final DateTime _startTime = DateTime.now();
  Timer? _durationTimer;
  Duration _elapsed = Duration.zero;
  double _currentSpeed = 0.0; // km/h
  StreamSubscription<Position>? _positionSub;

  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _dotAnim = Tween<double>(begin: 0.4, end: 1.0).animate(_dotCtrl);

    // Démarrer le timer de durée
    _startDurationTimer();

    // Écouter le GPS pour la vitesse
    _listenToGpsSpeed();
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(_startTime);
        });
      }
    });
  }

  void _listenToGpsSpeed() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // mètres
    );

    _positionSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) {
      if (mounted) {
        setState(() {
          // Vitesse en m/s → km/h
          _currentSpeed = (position.speed * 3.6).clamp(0.0, 150.0);
        });
      }
    });
  }

  @override
  void dispose() {
    _dotCtrl.dispose();
    _durationTimer?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(userRoleProvider);
    final passengers = ref.watch(tripPassengersStreamProvider(widget.tripId));
    final location = ref.watch(tripLocationStreamProvider(widget.tripId));
    final tripState = ref.watch(activeTripProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, role),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Statut trajet
                    _buildTripStatus(location),
                    const SizedBox(height: 16),

                    // Passagers à bord
                    passengers.when(
                      data: (list) => _buildPassengerStrip(context, list),
                      loading: () => const _ShimmerStrip(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 16),

                    // Mini carte placeholder
                    _buildMapCard(context, location),
                    const SizedBox(height: 16),

                    // Infos trajet
                    _buildTripInfo(),
                    const SizedBox(height: 16),

                    // Actions selon rôle
                    if (role == UserRole.passenger)
                      _buildPassengerActions(context, tripState),
                    if (role == UserRole.driver)
                      _buildDriverActions(context, tripState),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext ctx, UserRole? role) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => ctx.pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _dotCtrl,
                      builder: (_, __) => Opacity(
                        opacity: _dotAnim.value,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Trajet en cours',
                      style: AppTextStyles.titleLarge
                          .copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
                Text(
                  'ID: ${formatTripPreview(widget.tripId)}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          // SOS rapide
          GestureDetector(
            onTap: () => ctx.push(AppRoutes.sos),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.dangerSurface,
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emergency_rounded,
                      color: AppColors.danger, size: 16),
                  const SizedBox(width: 5),
                  Text('SOS',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripStatus(AsyncValue<TripLocation?> location) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.glowCard(glowColor: AppColors.primary),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_taxi_rounded,
                color: AppColors.taxiYellow, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Taxi en mouvement',
                    style: AppTextStyles.titleMedium),
                location.when(
                  data: (loc) => loc != null
                      ? Text(
                          '${loc.lat.toStringAsFixed(4)}, ${loc.lng.toStringAsFixed(4)}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                          ),
                        )
                      : const Text('Localisation en attente…',
                          style: AppTextStyles.bodySmall),
                  loading: () => const Text('Chargement GPS…',
                      style: AppTextStyles.bodySmall),
                  error: (_, __) => Text('GPS indisponible',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.danger)),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () =>
                context.push('${AppRoutes.map}?tripId=${widget.tripId}'),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.map_rounded,
                  color: AppColors.primary, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerStrip(
      BuildContext ctx, List<LivePassenger> passengers) {
    return GestureDetector(
      onTap: () => ctx.push('${AppRoutes.passengers}?tripId=${widget.tripId}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AppDecorations.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${passengers.length} passager${passengers.length > 1 ? 's' : ''} à bord',
                  style: AppTextStyles.titleMedium,
                ),
                Row(
                  children: [
                    Text('Voir tous',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                        )),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.primary, size: 16),
                  ],
                ),
              ],
            ),
            if (passengers.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  // Avatars empilés
                  SizedBox(
                    height: 36,
                    width: (passengers.length.clamp(0, 5) * 26.0) + 10,
                    child: Stack(
                      children: passengers
                          .take(5)
                          .toList()
                          .asMap()
                          .entries
                          .map(
                            (e) => Positioned(
                              left: e.key * 26.0,
                              child: _MiniAvatar(
                                firstName: e.value.firstName,
                                photoUrl: e.value.photoUrl,
                                isVerified: e.value.isVerified,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (passengers.length > 5)
                    Text(
                      '+${passengers.length - 5} autres',
                      style: AppTextStyles.bodySmall,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMapCard(BuildContext ctx, AsyncValue<TripLocation?> location) {
    return GestureDetector(
      onTap: () => ctx.push('${AppRoutes.map}?tripId=${widget.tripId}'),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Fond carte simulé
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.surfaceElevated,
                      AppColors.surface,
                    ],
                  ),
                ),
              ),
              // Grille
              CustomPaint(painter: _MapGridPainter()),
              // Icône taxi central
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 13,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.local_taxi_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.background.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('Suivi en direct',
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600)),
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

  Widget _buildTripInfo() {
    // Formater la durée
    final hours = _elapsed.inHours;
    final minutes = _elapsed.inMinutes.remainder(60);
    final seconds = _elapsed.inSeconds.remainder(60);
    final durationStr =
        hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m ${seconds}s';

    // Formater la vitesse
    final speedStr = _currentSpeed > 0
        ? '${_currentSpeed.toStringAsFixed(0)} km/h'
        : '0 km/h';

    final startTime = _startTime;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.access_time_rounded,
            label: 'Départ',
            value:
                '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
            color: AppColors.driverColor,
          ),
          const Divider(height: 18),
          _InfoRow(
            icon: Icons.timer_rounded,
            label: 'Durée',
            value: durationStr,
            color: AppColors.ownerColor,
          ),
          const Divider(height: 18),
          _InfoRow(
            icon: Icons.speed_rounded,
            label: 'Vitesse',
            value: speedStr,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerActions(BuildContext ctx, ActiveTripState tripState) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    final position = await Geolocator.getCurrentPosition();
                    final lat = position.latitude;
                    final lng = position.longitude;
                    final url = 'https://www.google.com/maps?q=$lat,$lng';
                    await Share.share(
                      'Je suis en trajet SafeTaxi. Suivez ma position : $url\n\nID : ${widget.tripId}',
                      subject: 'Suivi trajet SafeTaxi',
                    );
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Impossible de partager')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.share_location_rounded, size: 18),
                label: const Text('Partager'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _confirmLeave(ctx),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Descendre'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDriverActions(BuildContext ctx, ActiveTripState tripState) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    ctx.push('${AppRoutes.passengers}?tripId=${widget.tripId}'),
                icon: const Icon(Icons.people_rounded, size: 18),
                label: const Text('Passagers'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.driverColor,
                  side: BorderSide(
                      color: AppColors.driverColor.withValues(alpha: 0.4)),
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _confirmEndTrip(ctx),
                icon: const Icon(Icons.stop_rounded, size: 18),
                label: const Text('Fin trajet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.driverColor,
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _confirmLeave(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Descendre du taxi ?',
                style: AppTextStyles.headlineMedium),
            const SizedBox(height: 8),
            const Text(
              'Votre trajet sera terminé et votre heure de descente enregistrée.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning),
                    onPressed: () {
                      Navigator.pop(ctx);
                      ref.read(activeTripProvider.notifier).leaveTrip();
                      ctx.go(AppRoutes.homePassenger);
                    },
                    child: const Text('Descendre'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmEndTrip(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Terminer le trajet ?',
                style: AppTextStyles.headlineMedium),
            const SizedBox(height: 8),
            const Text(
              'Tous les passagers à bord seront notifiés.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.driverColor),
                    onPressed: () {
                      Navigator.pop(ctx);
                      ref.read(activeTripProvider.notifier).endTrip();
                      ctx.go(AppRoutes.homeDriver);
                    },
                    child: const Text('Terminer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  final String firstName;
  final String photoUrl;
  final bool isVerified;
  const _MiniAvatar(
      {required this.firstName,
      required this.photoUrl,
      required this.isVerified});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceElevated,
        border: Border.all(
          color: isVerified ? AppColors.primary : AppColors.border,
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
          style: AppTextStyles.labelMedium.copyWith(
            color: isVerified ? AppColors.primary : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InfoRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: AppTextStyles.bodyMedium),
        ),
        Text(value, style: AppTextStyles.titleMedium.copyWith(color: color)),
      ],
    );
  }
}

class _ShimmerStrip extends StatelessWidget {
  const _ShimmerStrip();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: AppDecorations.card(),
      child: const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2,
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.5)
      ..strokeWidth = 0.5;
    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
