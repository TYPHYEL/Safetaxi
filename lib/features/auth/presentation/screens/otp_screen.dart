// lib/features/auth/presentation/screens/otp_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:safetaxi_cameroun/core/constants/app_constants.dart';
import 'package:safetaxi_cameroun/features/auth/domain/entities/user_entity.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/providers/auth_provider.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});
  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _ctrl = TextEditingController();
  int _resendCountdown = 60;
  Timer? _timer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    // Auto-fill OTP code if available (for web development testing)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authProvider);
      if (authState.otpCode != null && mounted) {
        _ctrl.text = authState.otpCode!;
        _verify(authState.otpCode!);
      }
    });
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _resendCountdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _verify(String code) async {
    if (code.length < 6) return;
    _timer?.cancel();
    if (mounted) {
      setState(() => _isLoading = true);
    }
    await ref.read(authProvider.notifier).verifyOtp(widget.phone, code);
    if (!mounted) return;
    setState(() => _isLoading = false);
    final state = ref.read(authProvider);
    if (state.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.error!),
          backgroundColor: AppColors.dangerSurface,
        ),
      );
      return;
    }
    if (state.isAuthenticated) {
      final targetPath = switch (state.user?.role) {
        UserRole.driver => AppRoutes.homeDriver,
        UserRole.owner => AppRoutes.myTaxis,
        UserRole.admin => AppRoutes.adminDashboard,
        _ => AppRoutes.homePassenger,
      };
      if (mounted) {
        context.go(targetPath);
      }
    }
  }

  Future<void> _resend() async {
    if (_resendCountdown > 0) return;
    await ref.read(authProvider.notifier).sendOtp(widget.phone);
    _startTimer();
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
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.sms_rounded,
                  color: AppColors.primary, size: 32),
            ),
            const SizedBox(height: 24),
            const Text('Vérification\nOTP', style: AppTextStyles.displayMedium),
            const SizedBox(height: 10),
            RichText(
              text: TextSpan(
                text: 'Code envoyé au ',
                style: AppTextStyles.bodyMedium,
                children: [
                  TextSpan(
                    text: widget.phone,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            PinCodeTextField(
              appContext: context,
              length: 6,
              controller: _ctrl,
              keyboardType: TextInputType.number,
              animationType: AnimationType.scale,
              pinTheme: PinTheme(
                shape: PinCodeFieldShape.box,
                borderRadius: BorderRadius.circular(10),
                fieldHeight: 56,
                fieldWidth: 48,
                activeColor: AppColors.primary,
                inactiveColor: AppColors.border,
                selectedColor: AppColors.primaryLight,
                activeFillColor: AppColors.primarySurface,
                inactiveFillColor: AppColors.surfaceElevated,
                selectedFillColor: AppColors.surfaceElevated,
              ),
              enableActiveFill: true,
              textStyle: AppTextStyles.headlineMedium
                  .copyWith(color: AppColors.primary),
              onCompleted: _verify,
              onChanged: (_) {},
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _verify(_ctrl.text),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Vérifier le code'),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: GestureDetector(
                onTap: _resend,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _resendCountdown > 0
                      ? Text(
                          'Renvoyer dans ${_resendCountdown}s',
                          key: const ValueKey('countdown'),
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textMuted),
                        )
                      : Text(
                          'Renvoyer le code',
                          key: const ValueKey('resend'),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
