// lib/features/auth/presentation/screens/home_driver_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safetaxi_cameroun/core/constants/app_constants.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/providers/auth_provider.dart';
import 'package:safetaxi_cameroun/features/trajet/presentation/providers/trajet_provider.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';
import 'package:safetaxi_cameroun/shared/widgets/safe_avatar.dart';

class HomeDriverScreen extends ConsumerStatefulWidget {
  const HomeDriverScreen({super.key});
  @override
  ConsumerState<HomeDriverScreen> createState() => _HomeDriverScreenState();
}

class _HomeDriverScreenState extends ConsumerState<HomeDriverScreen>
    with TickerProviderStateMixin {
  bool _isOnline = false;
  String? _selectedTaxiId;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final tripState = ref.watch(activeTripProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(user),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    // Toggle prise de service
                    _buildServiceToggle(),
                    const SizedBox(height: 20),

                    // Trajet actif
                    if (tripState.isActive && tripState.tripId != null)
                      _buildActiveTripCard(tripState),
                    if (!tripState.isActive) _buildNoTripCard(),

                    const SizedBox(height: 20),

                    // Stats rapides
                    _buildStatsRow(),
                    const SizedBox(height: 20),

                    // Trust Score
                    _buildTrustCard(user?.trustScore ?? 5.0),
                    const SizedBox(height: 20),

                    // Actions
                    _buildDriverActions(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _buildSosFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildHeader(user) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.driverColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'CHAUFFEUR',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.driverColor,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(user?.displayName ?? 'Chauffeur',
                    style: AppTextStyles.headlineMedium),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.push(AppRoutes.notifications),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.notifications_outlined,
                  color: AppColors.textSecondary, size: 22),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => context.push(AppRoutes.profil),
            child: SafeAvatar(
              photoUrl: user?.photoUrl,
              initials: user?.initials ?? 'C',
              size: 40,
              borderColor: AppColors.driverColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceToggle() {
    return GestureDetector(
      onTap: () => setState(() => _isOnline = !_isOnline),
      child: AnimatedBuilder(
        animation: _isOnline ? _pulseAnim : const AlwaysStoppedAnimation(1.0),
        builder: (_, __) => Transform.scale(
          scale: _isOnline ? _pulseAnim.value : 1.0,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: _isOnline
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.15),
                        AppColors.primarySurface,
                      ],
                    )
                  : null,
              color: _isOnline ? null : AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isOnline
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : AppColors.border,
                width: _isOnline ? 1.5 : 0.5,
              ),
              boxShadow: _isOnline
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _isOnline
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : AppColors.surfaceElevated,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isOnline
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: _isOnline ? AppColors.primary : AppColors.textMuted,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isOnline ? 'En service' : 'Hors service',
                        style: AppTextStyles.titleLarge.copyWith(
                          color: _isOnline
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        _isOnline
                            ? 'Votre taxi est visible et traçable'
                            : 'Appuyez pour démarrer votre service',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isOnline,
                  onChanged: (v) => setState(() => _isOnline = v),
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTripCard(ActiveTripState tripState) {
    final count = tripState.passengers.length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppDecorations.glowCard(glowColor: AppColors.driverColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.driverColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.directions_car_rounded,
                    color: AppColors.driverColor, size: 20),
              ),
              const SizedBox(width: 10),
              Text('Trajet en cours',
                  style: AppTextStyles.titleLarge
                      .copyWith(color: AppColors.driverColor)),
              const Spacer(),
              const _OnlineDot(color: AppColors.driverColor),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatChip(
                icon: Icons.people_rounded,
                value: '$count',
                label: 'passager${count > 1 ? 's' : ''}',
                color: AppColors.driverColor,
              ),
              const SizedBox(width: 10),
              const _StatChip(
                icon: Icons.timer_rounded,
                value: '12',
                label: 'min',
                color: AppColors.ownerColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(
                      '${AppRoutes.passengers}?tripId=${tripState.tripId}'),
                  icon: const Icon(Icons.people_outline_rounded, size: 18),
                  label: const Text('Passagers'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.driverColor,
                    side: BorderSide(
                        color: AppColors.driverColor.withValues(alpha: 0.3)),
                    minimumSize: const Size(0, 44),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showEndTripDialog(),
                  icon: const Icon(Icons.stop_rounded, size: 18),
                  label: const Text('Terminer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.driverColor,
                    minimumSize: const Size(0, 44),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoTripCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Column(
        children: [
          const Icon(Icons.local_taxi_rounded,
              color: AppColors.textMuted, size: 40),
          const SizedBox(height: 12),
          Text('Aucun trajet actif',
              style: AppTextStyles.titleMedium
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          const Text(
            'Activez votre service et démarrez\nun trajet pour commencer',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _isOnline ? () => _startTrip() : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.driverColor,
              ),
              child: const Text('Démarrer un trajet'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return const Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Trajets\naujourd\'hui',
            value: '0',
            icon: Icons.route_rounded,
            color: AppColors.driverColor,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Passagers\ntotal',
            value: '0',
            icon: Icons.people_rounded,
            color: AppColors.primary,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Km\nparcourus',
            value: '0',
            icon: Icons.speed_rounded,
            color: AppColors.ownerColor,
          ),
        ),
      ],
    );
  }

  Widget _buildTrustCard(double score) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.trustScore),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppDecorations.card(),
        child: Row(
          children: [
            TrustBadge(score: score, large: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Trust Score : ${score.toStringAsFixed(1)}/5.0',
                      style: AppTextStyles.titleMedium),
                  const SizedBox(height: 3),
                  const Text('Voir les avis et détails',
                      style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Actions', style: AppTextStyles.titleLarge),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.directions_car_rounded,
          label: 'Mon taxi',
          subtitle: 'Gérer les informations de votre taxi',
          color: AppColors.driverColor,
          onTap: () => context.push(AppRoutes.myTaxis),
        ),
        const SizedBox(height: 10),
        _ActionTile(
          icon: Icons.history_rounded,
          label: 'Historique trajets',
          subtitle: 'Voir tous vos trajets passés',
          color: AppColors.ownerColor,
          onTap: () => context.push(AppRoutes.history),
        ),
        const SizedBox(height: 10),
        _ActionTile(
          icon: Icons.report_problem_rounded,
          label: 'Signaler un incident',
          subtitle: 'Déclarer un problème de sécurité',
          color: AppColors.warning,
          onTap: () => context.push(AppRoutes.incident),
        ),
      ],
    );
  }

  Widget _buildSosFab() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => context.push(AppRoutes.sos),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.danger,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.danger.withValues(alpha: 0.4),
                blurRadius: 16,
              ),
            ],
          ),
          child: const Icon(Icons.emergency_rounded,
              color: Colors.white, size: 26),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: BottomNavigationBar(
        currentIndex: _navIndex,
        onTap: (i) {
          setState(() => _navIndex = i);
          switch (i) {
            case 1:
              context.push(AppRoutes.map);
              break;
            case 3:
              context.push(AppRoutes.history);
              break;
            case 4:
              context.push(AppRoutes.profil);
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded), label: 'Accueil'),
          BottomNavigationBarItem(
              icon: Icon(Icons.map_rounded), label: 'Carte'),
          BottomNavigationBarItem(icon: SizedBox.shrink(), label: ''),
          BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded), label: 'Trajets'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded), label: 'Profil'),
        ],
      ),
    );
  }

  Future<void> _startTrip() async {
    final taxiId = _selectedTaxiId ?? 'driver-taxi-id';
    await ref.read(activeTripProvider.notifier).startTrip(taxiId);
    if (!mounted) return;
    final tripState = ref.read(activeTripProvider);
    if (tripState.tripId != null) {
      context.push('${AppRoutes.tripActive}?tripId=${tripState.tripId}');
    }
  }

  void _showEndTripDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Terminer le trajet'),
        content: const Text(
            'Confirmer la fin de ce trajet ? Les passagers seront notifiés.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(activeTripProvider.notifier).endTrip();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.driverColor),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value,
              style: AppTextStyles.headlineLarge.copyWith(color: color)),
          Text(label, style: AppTextStyles.caption.copyWith(height: 1.3)),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatChip(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            '$value $label',
            style: AppTextStyles.labelMedium.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile(
      {required this.icon,
      required this.label,
      required this.subtitle,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AppDecorations.card(),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.titleMedium),
                  Text(subtitle, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

class _OnlineDot extends StatefulWidget {
  final Color color;
  const _OnlineDot({required this.color});
  @override
  State<_OnlineDot> createState() => _OnlineDotState();
}

class _OnlineDotState extends State<_OnlineDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.6, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.5),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}
