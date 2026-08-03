// lib/features/auth/presentation/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safetaxi_cameroun/core/constants/app_constants.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/providers/auth_provider.dart';

import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  bool _isLoading = false;

  void _hideLoadingDialog() {
    if (!mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  String _normalizePhone(String phone) {
    final raw = phone.trim();
    if (raw.startsWith('+')) return raw;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0') && digits.length == 9) {
      return '+237${digits.substring(1)}';
    }
    if (digits.startsWith('237') && digits.length == 12) {
      return '+$digits';
    }
    if (digits.length == 9) {
      return '+237$digits';
    }
    return '+$digits';
  }

  Future<void> _sendOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final phone = _normalizePhone(_phoneCtrl.text.trim());

    setState(() => _isLoading = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    await ref.read(authProvider.notifier).sendOtp(phone);
    debugPrint('[login] sendOtp completed for $phone');

    if (!mounted) {
      debugPrint('[login] widget unmounted after sendOtp');
      return;
    }

    _hideLoadingDialog();
    setState(() => _isLoading = false);

    final authState = ref.read(authProvider);
    debugPrint(
      '[login] authState after sendOtp: status=${authState.status}, '
      'isOtpSent=${authState.isOtpSent}, error=${authState.error}, '
      'pendingPhone=${authState.pendingPhone}',
    );
    if (authState.isOtpSent) {
      final target = '${AppRoutes.otpVerify}?phone=${Uri.encodeComponent(phone)}';
      debugPrint('[login] navigating to $target');
      context.go(target);
      return;
    }

    debugPrint('[login] OTP not sent, showing error');
    _showError(authState.error ?? 'Erreur lors de l\'envoi de l\'OTP');
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.dangerSurface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Décoration fond
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 48),

                        // Logo compact
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Icon(Icons.local_taxi_rounded,
                                  color: AppColors.primary, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('SafeTaxi',
                                    style: AppTextStyles.titleLarge
                                        .copyWith(color: AppColors.primary)),
                                Text('Cameroun',
                                    style: AppTextStyles.caption
                                        .copyWith(letterSpacing: 2)),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 52),
                        const Text('Bienvenue\nde retour 👋',
                            style: AppTextStyles.displayMedium),
                        const SizedBox(height: 10),
                        const Text(
                          'Entrez votre numéro pour recevoir\nun code de vérification',
                          style: AppTextStyles.bodyMedium,
                        ),

                        const SizedBox(height: 40),

                        // Champ téléphone
                        const Text('Numéro de téléphone',
                            style: AppTextStyles.labelLarge),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(9),
                          ],
                          style: AppTextStyles.bodyLarge,
                          decoration: InputDecoration(
                            prefixIcon: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 16),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('🇨🇲',
                                      style: TextStyle(fontSize: 18)),
                                  const SizedBox(width: 6),
                                  Text('+237',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                          color: AppColors.textPrimary)),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 1,
                                    height: 20,
                                    color: AppColors.border,
                                  ),
                                ],
                              ),
                            ),
                            hintText: '6XX XXX XXX',
                          ),
                          validator: (v) {
                            if (v == null || v.length < 9) {
                              return 'Numéro invalide (9 chiffres)';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 32),

                        // Bouton connexion
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _sendOtp,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Envoyer le code OTP'),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Créer un compte
                        Center(
                          child: GestureDetector(
                            onTap: () => context.go(AppRoutes.roleSelect),
                            child: RichText(
                              text: TextSpan(
                                text: 'Pas encore inscrit ? ',
                                style: AppTextStyles.bodyMedium,
                                children: [
                                  TextSpan(
                                    text: 'Créer un compte',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 48),

                        // Info sécurité
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: AppDecorations.card(),
                          child: Row(
                            children: [
                              const Icon(Icons.security_rounded,
                                  color: AppColors.primary, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Authentification sécurisée par OTP SMS. '
                                  'Aucun mot de passe requis.',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
