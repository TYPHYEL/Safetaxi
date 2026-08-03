// lib/features/auth/presentation/screens/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safetaxi_cameroun/core/constants/app_constants.dart';
import 'package:safetaxi_cameroun/features/auth/domain/entities/user_entity.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/providers/auth_provider.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {

  late final AnimationController _logoCtrl;
  late final AnimationController _textCtrl;
  late final AnimationController _pulseCtrl;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _pulseScale;

  bool _navigated = false;
  bool _disposed = false;
  Timer? _animationTimer;

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: const Interval(0, 0.4)),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _pulseScale = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _startAnimation();
  }

  void _startAnimation() {
    _scheduleAnimationStep(const Duration(milliseconds: 200), () {
      if (_disposed || !mounted) return;
      _logoCtrl.forward();
      _scheduleAnimationStep(const Duration(milliseconds: 500), () {
        if (_disposed || !mounted) return;
        _textCtrl.forward();
        _scheduleAnimationStep(const Duration(milliseconds: 1800), () {
          if (_disposed || !mounted) return;
          _checkNavigation();
        });
      });
    });
  }

  void _scheduleAnimationStep(Duration duration, VoidCallback callback) {
    _animationTimer?.cancel();
    _animationTimer = Timer(duration, callback);
  }

  void _checkNavigation() {
    if (_navigated) return;
    final auth = ref.read(authProvider);
    if (auth.status == AuthStatus.loading || auth.status == AuthStatus.initial) {
      ref.listenManual(authProvider, (_, next) {
        if (next.status != AuthStatus.loading &&
            next.status != AuthStatus.initial) {
          _navigate(next);
        }
      });
    } else {
      _navigate(auth);
    }
  }

  Future<void> _navigate(AuthState auth) async {
    if (_navigated || !mounted) return;
    _navigated = true;

    if (auth.isAuthenticated) {
      final role = auth.user?.role;
      switch (role) {
        case UserRole.driver:
          context.go(AppRoutes.homeDriver);
          break;
        case UserRole.owner:
          context.go(AppRoutes.myTaxis);
          break;
        case UserRole.admin:
          context.go(AppRoutes.adminDashboard);
          break;
        default:
          context.go(AppRoutes.homePassenger);
      }
    } else {
      // Vérifier si onboarding déjà vu
      const storage = FlutterSecureStorage();
      final done = await storage.read(key: AppConstants.onboardingKey);
      if (mounted) {
        context.go(done == 'true' ? AppRoutes.login : AppRoutes.onboarding);
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _animationTimer?.cancel();
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fond avec motif géométrique subtil
          CustomPaint(painter: _GridPainter()),

          // Halo central
          Center(
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => Transform.scale(
                scale: _pulseScale.value,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.08),
                        AppColors.primary.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Logo + texte
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                AnimatedBuilder(
                  animation: _logoCtrl,
                  builder: (_, __) => Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: _buildLogo(),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Texte
                AnimatedBuilder(
                  animation: _textCtrl,
                  builder: (_, __) => Opacity(
                    opacity: _textOpacity.value,
                    child: SlideTransition(
                      position: _textSlide,
                      child: Column(
                        children: [
                          Text(
                            'SAFETAXI',
                            style: AppTextStyles.displayMedium.copyWith(
                              color: AppColors.textPrimary,
                              letterSpacing: 6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'CAMEROUN',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.primary,
                              letterSpacing: 8,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: 40,
                            height: 2,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Vos trajets. Votre sécurité.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Version en bas
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _textCtrl,
              builder: (_, __) => Opacity(
                opacity: _textOpacity.value,
                child: Column(
                  children: [
                    // Tri-couleur camerounaise
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _colorBar(AppColors.cmGreen),
                        _colorBar(AppColors.cmRed),
                        _colorBar(AppColors.cmYellow),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'v1.0.0 · Yaoundé',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 40,
            spreadRadius: 8,
          ),
        ],
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.local_taxi_rounded,
                size: 52, color: AppColors.primary),
            Positioned(
              bottom: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_rounded,
                    size: 18, color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorBar(Color color) => Container(
        width: 28,
        height: 3,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      );
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.4)
      ..strokeWidth = 0.5;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
