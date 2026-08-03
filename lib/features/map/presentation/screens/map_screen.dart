// lib/features/map/presentation/screens/map_screen.dart
// ✅ 100% GRATUIT — OpenStreetMap via flutter_map (aucune clé API requise)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:safetaxi_cameroun/core/constants/app_constants.dart';
import 'package:safetaxi_cameroun/features/trajet/presentation/providers/trajet_provider.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/providers/auth_provider.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';

// ─── Faux taxis pour démonstration ───────────────────────
final _demoTaxis = [
  {
    'id': 'taxi-001',
    'lat': 3.8480,
    'lng': 11.5021,
    'plate': 'LT4521A',
    'driver': 'Jean NKOLO'
  },
  {
    'id': 'taxi-002',
    'lat': 3.8510,
    'lng': 11.5065,
    'plate': 'CE2890B',
    'driver': 'Patrick ETOGA'
  },
  {
    'id': 'taxi-003',
    'lat': 3.8445,
    'lng': 11.4990,
    'plate': 'LT9912C',
    'driver': 'Marie ESSOMBA'
  },
  {
    'id': 'taxi-004',
    'lat': 3.8530,
    'lng': 11.5100,
    'plate': 'AD7743D',
    'driver': 'Paul ATEBA'
  },
  {
    'id': 'taxi-005',
    'lat': 3.8460,
    'lng': 11.5140,
    'plate': 'LT2201E',
    'driver': 'Simon MBIDA'
  },
];

class MapScreen extends ConsumerStatefulWidget {
  final String? tripId;
  const MapScreen({super.key, this.tripId});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with SingleTickerProviderStateMixin {
  final _mapCtrl = MapController();
  LatLng? _myPos;
  bool _loadingPos = false;
  int? _selectedTaxi;
  bool _showTaxis = true;

  // Yaoundé centre
  static const _yaoundeCenter = LatLng(
    AppConstants.defaultLat,
    AppConstants.defaultLng,
  );

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _getMyLocation();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _getMyLocation() async {
    setState(() => _loadingPos = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm != LocationPermission.denied &&
          perm != LocationPermission.deniedForever) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        if (mounted) {
          setState(() {
            _myPos = LatLng(pos.latitude, pos.longitude);
          });
          _mapCtrl.move(_myPos!, 14.5);
        }
      }
    } catch (_) {
      // Fallback sur Yaoundé centre
    } finally {
      if (mounted) setState(() => _loadingPos = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si tripId fourni, surveiller la position du taxi en temps réel
    TripLocation? tripLoc;
    if (widget.tripId != null) {
      final locAsync = ref.watch(tripLocationStreamProvider(widget.tripId!));
      tripLoc = locAsync.value;
      if (tripLoc != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapCtrl.move(LatLng(tripLoc!.lat, tripLoc.lng), 15);
        });
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Carte OpenStreetMap ──────────────────────────
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: _myPos ?? _yaoundeCenter,
              initialZoom: 14.0,
              minZoom: 10.0,
              maxZoom: 19.0,
              onTap: (_, __) => setState(() => _selectedTaxi = null),
            ),
            children: [
              // Tuiles OpenStreetMap (100% gratuit)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.safetaxi.cameroun',
                tileProvider: CancellableNetworkTileProvider(),
                maxZoom: 19,
              ),

              // Attribution obligatoire OpenStreetMap
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),

              // Cercle de zone autour de ma position
              if (_myPos != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _myPos!,
                      radius: 80,
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderColor: AppColors.primary.withValues(alpha: 0.4),
                      borderStrokeWidth: 1.5,
                      useRadiusInMeter: true,
                    ),
                  ],
                ),

              // Marqueurs des taxis (mode liste)
              if (_showTaxis && widget.tripId == null)
                MarkerLayer(
                  markers: _demoTaxis.asMap().entries.map((e) {
                    final taxi = e.value;
                    final idx = e.key;
                    final isSelec = _selectedTaxi == idx;
                    return Marker(
                      point: LatLng(
                        taxi['lat'] as double,
                        taxi['lng'] as double,
                      ),
                      width: isSelec ? 52 : 44,
                      height: isSelec ? 52 : 44,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedTaxi = isSelec ? null : idx;
                          _mapCtrl.move(
                            LatLng(
                              taxi['lat'] as double,
                              taxi['lng'] as double,
                            ),
                            15.5,
                          );
                        }),
                        child: AnimatedBuilder(
                          animation: _pulseCtrl,
                          builder: (_, __) => Transform.scale(
                            scale: isSelec ? _pulseAnim.value : 1.0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelec
                                    ? AppColors.taxiYellow
                                    : AppColors.surface,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.taxiYellow,
                                  width: isSelec ? 2.5 : 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.taxiYellow
                                        .withValues(alpha: isSelec ? 0.4 : 0.2),
                                    blurRadius: isSelec ? 16 : 8,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.local_taxi_rounded,
                                color:
                                    isSelec ? Colors.white : AppColors.taxiYellow,
                                size: isSelec ? 26 : 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

              // Marqueur taxi suivi (mode trajet actif)
              if (widget.tripId != null && tripLoc != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(tripLoc.lat, tripLoc.lng),
                      width: 56,
                      height: 56,
                      child: AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (_, __) => Transform.scale(
                          scale: _pulseAnim.value,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.5),
                                  blurRadius: 20,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.local_taxi_rounded,
                                color: Colors.white, size: 28),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

              // Ma position
              if (_myPos != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _myPos!,
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.driverColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors.driverColor.withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // ── Barre de contrôle haut ───────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Retour
                  _MapBtn(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 10),

                  // Titre
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_taxi_rounded,
                              color: AppColors.taxiYellow, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.tripId != null
                                  ? 'Suivi taxi en temps réel'
                                  : 'Taxis actifs — Yaoundé',
                              style: AppTextStyles.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Compteur
                          if (widget.tripId == null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_demoTaxis.length}',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Badge OpenStreetMap (info) ───────────────────
          Positioned(
            top: 80,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.map_rounded,
                      color: AppColors.primary, size: 12),
                  const SizedBox(width: 4),
                  Text('OpenStreetMap · Gratuit',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.primary)),
                ],
              ),
            ),
          ),

          // ── Contrôles droite ─────────────────────────────
          Positioned(
            right: 16,
            bottom: widget.tripId != null ? 140 : 100,
            child: Column(
              children: [
                // Ma position
                _MapBtn(
                  icon: _loadingPos
                      ? Icons.hourglass_top_rounded
                      : Icons.my_location_rounded,
                  color: AppColors.primary,
                  onTap: _loadingPos ? null : _getMyLocation,
                ),
                const SizedBox(height: 8),

                // Zoom +
                _MapBtn(
                  icon: Icons.add_rounded,
                  onTap: () {
                    _mapCtrl.move(
                      _mapCtrl.camera.center,
                      _mapCtrl.camera.zoom + 1,
                    );
                  },
                ),
                const SizedBox(height: 4),

                // Zoom -
                _MapBtn(
                  icon: Icons.remove_rounded,
                  onTap: () {
                    _mapCtrl.move(
                      _mapCtrl.camera.center,
                      _mapCtrl.camera.zoom - 1,
                    );
                  },
                ),
                const SizedBox(height: 8),

                // Toggle taxis
                if (widget.tripId == null)
                  _MapBtn(
                    icon: _showTaxis
                        ? Icons.local_taxi_rounded
                        : Icons.local_taxi_outlined,
                    color: _showTaxis ? AppColors.taxiYellow : null,
                    onTap: () => setState(() => _showTaxis = !_showTaxis),
                  ),
              ],
            ),
          ),

          // ── Popup taxi sélectionné ───────────────────────
          if (_selectedTaxi != null && widget.tripId == null)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: _TaxiPopup(
                taxi: _demoTaxis[_selectedTaxi!],
                onClose: () => setState(() => _selectedTaxi = null),
                onJoin: () {
                  setState(() => _selectedTaxi = null);
                  context.push(AppRoutes.scanTaxi);
                },
              ),
            ),

          // ── Panneau trajet actif ─────────────────────────
          if (widget.tripId != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _TripMapPanel(tripId: widget.tripId!),
            ),
        ],
      ),
    );
  }
}

// ─── Bouton carte ────────────────────────────────────────

class _MapBtn extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;
  const _MapBtn({required this.icon, this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.95),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(
          icon,
          color: color ?? AppColors.textSecondary,
          size: 20,
        ),
      ),
    );
  }
}

// ─── Popup info taxi ─────────────────────────────────────

class _TaxiPopup extends StatelessWidget {
  final Map<String, dynamic> taxi;
  final VoidCallback onClose;
  final VoidCallback onJoin;
  const _TaxiPopup(
      {required this.taxi, required this.onClose, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColors.primarySurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_taxi_rounded,
                    color: AppColors.taxiYellow, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          taxi['plate'] as String,
                          style: AppTextStyles.titleLarge.copyWith(
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text('Actif',
                              style: AppTextStyles.caption.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    Text(
                      'Chauffeur : ${taxi['driver']}',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close_rounded,
                    color: AppColors.textMuted, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Distance simulée
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.near_me_rounded,
                        color: AppColors.textSecondary, size: 14),
                    const SizedBox(width: 4),
                    Text('~180m',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people_rounded,
                        color: AppColors.textSecondary, size: 14),
                    const SizedBox(width: 4),
                    Text('2 passagers',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: onJoin,
                icon: const Icon(Icons.qr_code_rounded, size: 16),
                label: const Text('Rejoindre'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Panneau trajet actif (bas de la carte) ───────────────

class _TripMapPanel extends ConsumerWidget {
  final String tripId;
  const _TripMapPanel({required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passAsync = ref.watch(tripPassengersStreamProvider(tripId));

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_taxi_rounded,
                color: AppColors.taxiYellow, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trajet en cours',
                    style: AppTextStyles.titleMedium
                        .copyWith(color: AppColors.primary)),
                passAsync.when(
                  data: (list) => Text(
                    '${list.length} passager${list.length > 1 ? 's' : ''} à bord',
                    style: AppTextStyles.bodySmall,
                  ),
                  loading: () =>
                      const Text('…', style: AppTextStyles.bodySmall),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () =>
                context.push('${AppRoutes.passengers}?tripId=$tripId'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: const Text('Passagers'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// NOTATION SCREEN (regroupé ici pour simplifier)
// ═══════════════════════════════════════════════════════

class NotationScreen extends ConsumerStatefulWidget {
  final String tripId;
  final String targetUserId;
  final bool targetIsDriver;
  const NotationScreen({
    super.key,
    required this.tripId,
    required this.targetUserId,
    required this.targetIsDriver,
  });
  @override
  ConsumerState<NotationScreen> createState() => _NotationScreenState();
}

class _NotationScreenState extends ConsumerState<NotationScreen> {
  int _stars = 0;
  String _comment = '';
  bool _isLoading = false;
  final _selectedAspects = <String>{};

  final _aspects = [
    'Conduite sûre',
    'Ponctuel',
    'Respectueux',
    'Véhicule propre',
    'Bonne communication',
  ];

  Future<void> _submit() async {
    if (_stars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donnez au moins 1 étoile')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ref.read(apiClientProvider).rateUser({
        'trip_id': widget.tripId,
        'rated_id': widget.targetUserId,
        'score': _stars,
        'comment': _comment,
        'aspects': _selectedAspects.toList(),
      });
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.surface,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded,
                    color: AppColors.ownerColor, size: 56),
                const SizedBox(height: 12),
                const Text('Merci pour votre note !',
                    style: AppTextStyles.headlineMedium,
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.pop();
                  },
                  child: const Text('Fermer'),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(widget.targetIsDriver
            ? 'Évaluer le chauffeur'
            : 'Évaluer le passager'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.ownerColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.targetIsDriver
                    ? Icons.drive_eta_rounded
                    : Icons.person_rounded,
                color: AppColors.ownerColor,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.targetIsDriver
                  ? 'Comment était le chauffeur ?'
                  : 'Comment était ce passager ?',
              style: AppTextStyles.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  5,
                  (i) => GestureDetector(
                        onTap: () => setState(() => _stars = i + 1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            i < _stars
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: i < _stars
                                ? AppColors.ownerColor
                                : AppColors.textMuted,
                            size: 44,
                          ),
                        ),
                      )),
            ),
            const SizedBox(height: 8),
            Text(
              _stars == 0
                  ? 'Appuyez pour noter'
                  : _stars == 5
                      ? 'Excellent'
                      : _stars >= 3
                          ? 'Bien'
                          : 'Mauvais',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: _stars > 0 ? AppColors.ownerColor : null),
            ),
            const SizedBox(height: 24),
            const Align(
                alignment: Alignment.centerLeft,
                child:
                    Text('Points positifs', style: AppTextStyles.titleLarge)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _aspects.map((a) {
                final sel = _selectedAspects.contains(a);
                return GestureDetector(
                  onTap: () => setState(() {
                    sel ? _selectedAspects.remove(a) : _selectedAspects.add(a);
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.ownerColor.withValues(alpha: 0.15)
                          : AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: sel ? AppColors.ownerColor : AppColors.border),
                    ),
                    child: Text(a,
                        style: AppTextStyles.labelMedium.copyWith(
                            color: sel
                                ? AppColors.ownerColor
                                : AppColors.textSecondary)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            TextFormField(
              maxLines: 3,
              style: AppTextStyles.bodyLarge,
              onChanged: (v) => _comment = v,
              decoration:
                  const InputDecoration(hintText: 'Laissez un commentaire...'),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ownerColor),
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: const Text('Envoyer l\'évaluation'),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// ADMIN DASHBOARD SCREEN
// ═══════════════════════════════════════════════════════

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.adminColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('ADMIN',
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.adminColor,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            const Text('Tableau de bord', style: AppTextStyles.headlineMedium),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: const [
                _AdminStatCard(
                    label: 'Trajets actifs',
                    value: '24',
                    icon: Icons.route_rounded,
                    color: AppColors.primary),
                _AdminStatCard(
                    label: 'Chauffeurs en attente',
                    value: '7',
                    icon: Icons.pending_rounded,
                    color: AppColors.warning),
                _AdminStatCard(
                    label: 'Alertes SOS',
                    value: '2',
                    icon: Icons.emergency_rounded,
                    color: AppColors.danger),
                _AdminStatCard(
                    label: 'Taxis actifs',
                    value: '143',
                    icon: Icons.local_taxi_rounded,
                    color: AppColors.taxiYellow),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Actions rapides', style: AppTextStyles.titleLarge),
            const SizedBox(height: 12),
            _AdminAction(
                icon: Icons.how_to_reg_rounded,
                label: 'Valider les chauffeurs',
                badge: '7',
                color: AppColors.warning,
                onTap: () => context.push(AppRoutes.adminDrivers)),
            const SizedBox(height: 10),
            _AdminAction(
                icon: Icons.emergency_share_rounded,
                label: 'Alertes SOS actives',
                badge: '2',
                color: AppColors.danger,
                onTap: () {}),
            const SizedBox(height: 10),
            _AdminAction(
                icon: Icons.local_taxi_rounded,
                label: 'Gestion des taxis',
                color: AppColors.taxiYellow,
                onTap: () {}),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _AdminStatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _AdminStatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 24),
        const Spacer(),
        Text(value,
            style: AppTextStyles.displayMedium
                .copyWith(color: color, fontSize: 28)),
        Text(label, style: AppTextStyles.bodySmall),
      ]),
    );
  }
}

class _AdminAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final Color color;
  final VoidCallback onTap;
  const _AdminAction(
      {required this.icon,
      required this.label,
      this.badge,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AppDecorations.card(),
        child: Row(children: [
          Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: AppTextStyles.titleMedium)),
          if (badge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(10)),
              child: Text(badge!,
                  style: AppTextStyles.caption.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
          ],
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textMuted, size: 18),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// ADMIN DRIVERS SCREEN
// ═══════════════════════════════════════════════════════

class AdminDriversScreen extends ConsumerWidget {
  const AdminDriversScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drivers = [
      {'name': 'Jean NKOLO', 'phone': '+237 677 123 456', 'h': 2},
      {'name': 'Marie ESSOMBA', 'phone': '+237 655 987 321', 'h': 5},
      {'name': 'Paul ATEBA', 'phone': '+237 699 456 789', 'h': 12},
    ];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.pop()),
        title: const Text('Validation chauffeurs'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        itemCount: drivers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final d = drivers[i];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: AppDecorations.card(),
            child: Column(children: [
              Row(children: [
                Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        shape: BoxShape.circle),
                    child: Center(
                        child: Text((d['name'] as String)[0],
                            style: AppTextStyles.headlineMedium
                                .copyWith(color: AppColors.warning)))),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(d['name'] as String,
                          style: AppTextStyles.titleMedium),
                      Text(d['phone'] as String,
                          style: AppTextStyles.bodySmall),
                    ])),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppColors.warningSurface,
                        borderRadius: BorderRadius.circular(6)),
                    child: Text('En attente',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.warning))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Refuser'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: BorderSide(
                          color: AppColors.danger.withValues(alpha: 0.4)),
                      minimumSize: const Size(0, 40)),
                )),
                const SizedBox(width: 10),
                Expanded(
                    child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Approuver'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(0, 40)),
                )),
              ]),
            ]),
          );
        },
      ),
    );
  }
}

// ─── Helper partage position ─────────────────────────────
Future<void> shareCurrentLocation(BuildContext context, String? tripId) async {
  try {
    final position = await Geolocator.getCurrentPosition();
    final lat = position.latitude;
    final lng = position.longitude;
    final googleMapsUrl = 'https://www.google.com/maps?q=$lat,$lng';

    final message = tripId != null
        ? 'Je suis en trajet SafeTaxi. Suivez ma position : $googleMapsUrl\n\nID trajet : $tripId'
        : 'Ma position actuelle SafeTaxi : $googleMapsUrl';

    await Share.share(message, subject: 'Position SafeTaxi');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de partager la position')),
      );
    }
  }
}
