// lib/features/auth/presentation/screens/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:safetaxi_cameroun/core/constants/app_constants.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';

class _OnboardPage {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<String> bullets;

  const _OnboardPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.bullets,
  });
}

const _pages = [
  _OnboardPage(
    title: 'Taxis sécurisés\nà Yaoundé',
    subtitle: 'La première plateforme de sécurité\npour les taxis conventionnels camerounais',
    icon: Icons.local_taxi_rounded,
    accent: AppColors.primary,
    bullets: [
      'Identification des chauffeurs vérifiés',
      'Traçabilité GPS en temps réel',
      'Alertes SOS instantanées',
    ],
  ),
  _OnboardPage(
    title: 'Montez\nen confiance',
    subtitle: 'Scannez le QR code du taxi, votre trajet\nest enregistré automatiquement',
    icon: Icons.qr_code_scanner_rounded,
    accent: Color(0xFF4A9EFF),
    bullets: [
      'Scan QR code ou code taxi',
      'Passagers visibles dans le taxi',
      'Trust Score pour chaque utilisateur',
    ],
  ),
  _OnboardPage(
    title: 'SOS discret\nen 1 geste',
    subtitle: 'Alertez vos proches et la plateforme\nsans que personne ne s\'en aperçoive',
    icon: Icons.emergency_rounded,
    accent: AppColors.danger,
    bullets: [
      'Triple pression du bouton volume',
      'Position GPS envoyée automatiquement',
      'Contacts d\'urgence alertés',
    ],
  ),
  _OnboardPage(
    title: 'Chauffeurs &\nPassagers protégés',
    subtitle: 'Une protection mutuelle pour tous\nles acteurs du transport urbain',
    icon: Icons.shield_rounded,
    accent: AppColors.ownerColor,
    bullets: [
      'Vérification biométrique chauffeurs',
      'Notation mutuelle après trajet',
      'Historique complet sécurisé',
    ],
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _ctrl = PageController();
  int _current = 0;
  late AnimationController _iconCtrl;
  late Animation<double> _iconScale;

  @override
  void initState() {
    super.initState();
    _iconCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _iconScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _iconCtrl, curve: Curves.elasticOut),
    );
    _iconCtrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _iconCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_current < _pages.length - 1) {
      _ctrl.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    const storage = FlutterSecureStorage();
    await storage.write(key: AppConstants.onboardingKey, value: 'true');
    if (mounted) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_current];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Fond gradient selon la page
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.3),
                radius: 1.2,
                colors: [
                  page.accent.withValues(alpha: 0.08),
                  AppColors.background,
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header skip
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Logo mini
                      Row(
                        children: [
                          const Icon(Icons.local_taxi_rounded,
                              color: AppColors.primary, size: 20),
                          const SizedBox(width: 6),
                          Text('SafeTaxi',
                              style: AppTextStyles.titleMedium.copyWith(
                                  color: AppColors.primary)),
                        ],
                      ),
                      TextButton(
                        onPressed: _finish,
                        child: Text(
                          'Passer',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // PageView
                Expanded(
                  child: PageView.builder(
                    controller: _ctrl,
                    onPageChanged: (i) {
                      setState(() => _current = i);
                      _iconCtrl.reset();
                      _iconCtrl.forward();
                    },
                    itemCount: _pages.length,
                    itemBuilder: (_, i) => _buildPage(_pages[i]),
                  ),
                ),

                // Bas de page
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
                  child: Column(
                    children: [
                      // Indicateurs
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pages.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width:  i == _current ? 24 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == _current
                                  ? page.accent
                                  : AppColors.border,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Bouton suivant
                      _OnboardButton(
                        label: _current == _pages.length - 1
                            ? 'Commencer'
                            : 'Suivant',
                        color: page.accent,
                        onTap: _next,
                      ),

                      if (_current == 0) ...[
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: () => context.go(AppRoutes.login),
                          child: Text(
                            'Déjà un compte ? Se connecter',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(_OnboardPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icône animée
          Center(
            child: ScaleTransition(
              scale: _iconScale,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: page.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: page.accent.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: page.accent.withValues(alpha: 0.2),
                      blurRadius: 32,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(page.icon, size: 56, color: page.accent),
              ),
            ),
          ),
          const SizedBox(height: 40),

          // Titre
          Text(
            page.title,
            style: AppTextStyles.displayMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // Sous-titre
          Text(
            page.subtitle,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),

          // Bullets
          ...page.bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: page.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check, size: 12, color: page.accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(b, style: AppTextStyles.bodyMedium),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OnboardButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.labelLarge.copyWith(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
