// lib/features/auth/presentation/screens/home_passenger_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safetaxi_cameroun/core/constants/app_constants.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/providers/auth_provider.dart';
import 'package:safetaxi_cameroun/features/trajet/presentation/providers/trajet_provider.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';
import 'package:safetaxi_cameroun/shared/widgets/safe_avatar.dart';

class HomePassengerScreen extends ConsumerStatefulWidget {
  const HomePassengerScreen({super.key});
  @override
  ConsumerState<HomePassengerScreen> createState() =>
      _HomePassengerScreenState();
}

class _HomePassengerScreenState extends ConsumerState<HomePassengerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final List<Animation<double>> _itemAnims;
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _itemAnims = List.generate(
      6,
      (i) => Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _animCtrl,
          curve: Interval(i * 0.1, 0.4 + i * 0.1, curve: Curves.easeOut),
        ),
      ),
    );
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
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
            if (tripState.isLoading)
              const LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.primary,
                backgroundColor: AppColors.surfaceHighest,
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),

                    // Bannière trajet actif
                    if (tripState.isActive && tripState.tripId != null)
                      _buildActiveTripBanner(tripState.tripId!),

                    const SizedBox(height: 20),

                    // Actions rapides
                    FadeTransition(
                      opacity: _itemAnims[0],
                      child: _buildQuickActions(context),
                    ),

                    const SizedBox(height: 24),

                    // Trust score
                    FadeTransition(
                      opacity: _itemAnims[1],
                      child: _buildTrustCard(user?.trustScore ?? 5.0),
                    ),

                    const SizedBox(height: 24),

                    // Conseils sécurité
                    FadeTransition(
                      opacity: _itemAnims[2],
                      child: _buildSecurityTips(),
                    ),

                    const SizedBox(height: 24),

                    // Derniers trajets
                    FadeTransition(
                      opacity: _itemAnims[3],
                      child: _buildRecentTrips(),
                    ),

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
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Bonjour'
        : hour < 18
            ? 'Bonsoir'
            : 'Bonsoir';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting 👋',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user?.displayName ?? 'Passager',
                  style: AppTextStyles.headlineMedium,
                ),
              ],
            ),
          ),
          // Notifications
          GestureDetector(
            onTap: () => context.push(AppRoutes.notifications),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_outlined,
                      color: AppColors.textSecondary, size: 22),
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => context.push(AppRoutes.profil),
            child: SafeAvatar(
              photoUrl: user?.photoUrl,
              initials: user?.initials ?? 'P',
              size: 40,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTripBanner(String tripId) {
    return GestureDetector(
      onTap: () => context.push('${AppRoutes.tripActive}?tripId=$tripId'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primarySurface,
              AppColors.primary.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_taxi_rounded,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Trajet en cours',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      )),
                  Text('Appuyez pour voir les détails',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      )),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext ctx) {
    final actions = [
      _QuickAction(
        label: 'Scanner\nun taxi',
        icon: Icons.qr_code_scanner_rounded,
        color: AppColors.primary,
        onTap: () => ctx.push(AppRoutes.scanTaxi),
      ),
      _QuickAction(
        label: 'Dépôt\nPrivé',
        icon: Icons.local_taxi_rounded,
        color: AppColors.driverColor,
        onTap: () => ctx.push(AppRoutes.depositRequest),
      ),
      _QuickAction(
        label: 'Carte\ntaxis',
        icon: Icons.map_rounded,
        color: AppColors.ownerColor,
        onTap: () => ctx.push(AppRoutes.map),
      ),
      _QuickAction(
        label: 'SOS\nUrgence',
        icon: Icons.emergency_rounded,
        color: AppColors.danger,
        onTap: () => ctx.push(AppRoutes.sos),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Actions rapides', style: AppTextStyles.titleLarge),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: actions.map((a) => _QuickActionButton(action: a)).toList(),
        ),
      ],
    );
  }

  Widget _buildTrustCard(double score) {
    final percent = score / 5.0;
    final color = score >= 4
        ? AppColors.primary
        : score >= 2.5
            ? AppColors.warning
            : AppColors.danger;

    return GestureDetector(
      onTap: () => context.push(AppRoutes.trustScore),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: AppDecorations.glowCard(glowColor: color),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: percent,
                    strokeWidth: 5,
                    backgroundColor: AppColors.surfaceHighest,
                    valueColor: AlwaysStoppedAnimation(color),
                    strokeCap: StrokeCap.round,
                  ),
                  Center(
                    child: Text(
                      score.toStringAsFixed(1),
                      style: AppTextStyles.titleMedium.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Trust Score', style: AppTextStyles.titleMedium),
                      const SizedBox(width: 8),
                      TrustBadge(score: score),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    score >= 4
                        ? 'Excellent · Profil très fiable'
                        : score >= 2.5
                            ? 'Moyen · Améliorez votre score'
                            : 'Faible · Attention requise',
                    style: AppTextStyles.bodySmall,
                  ),
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

  Widget _buildSecurityTips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Conseils sécurité', style: AppTextStyles.titleLarge),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppDecorations.card(),
          child: const Column(
            children: [
              _TipRow(
                icon: Icons.qr_code_rounded,
                text: 'Scannez toujours le QR avant de monter',
                color: AppColors.primary,
              ),
              Divider(height: 20),
              _TipRow(
                icon: Icons.people_rounded,
                text: 'Vérifiez les autres passagers',
                color: AppColors.driverColor,
              ),
              Divider(height: 20),
              _TipRow(
                icon: Icons.location_on_rounded,
                text: 'Partagez votre trajet avec un proche',
                color: AppColors.ownerColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTrips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Trajets récents', style: AppTextStyles.titleLarge),
            TextButton(
              onPressed: () => context.push(AppRoutes.history),
              child: const Text('Voir tout'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: AppDecorations.card(),
          child: const Center(
            child: Column(
              children: [
                Icon(Icons.route_rounded, color: AppColors.textMuted, size: 36),
                SizedBox(height: 10),
                Text('Aucun trajet récent', style: AppTextStyles.bodyMedium),
                SizedBox(height: 4),
                Text(
                  'Scannez un taxi pour commencer',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSosFab() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => context.push(AppRoutes.sos),
        onLongPress: () {
          // SOS immédiat sans confirmation
          context.push(AppRoutes.sos);
        },
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
                spreadRadius: 2,
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
        border: Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _navIndex,
        onTap: (i) {
          setState(() => _navIndex = i);
          switch (i) {
            case 0:
              break; // Home
            case 1:
              context.push(AppRoutes.map);
              break;
            case 2:
              break; // SOS FAB
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
            icon: Icon(Icons.home_rounded),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_rounded),
            label: 'Carte',
          ),
          BottomNavigationBarItem(
            icon: SizedBox.shrink(),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: 'Trajets',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});
}

class _QuickActionButton extends StatelessWidget {
  final _QuickAction action;
  const _QuickActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: action.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: action.color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(action.icon, color: action.color, size: 26),
            const SizedBox(height: 6),
            Text(
              action.label,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _TipRow({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: AppTextStyles.bodyMedium)),
      ],
    );
  }
}
