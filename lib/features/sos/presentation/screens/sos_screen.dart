// lib/features/sos/presentation/screens/sos_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safetaxi_cameroun/features/sos/presentation/providers/sos_provider.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';

class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});
  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _ringCtrl;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _ringAnim;

  SosAlertType? _selectedType;
  bool _holding = false;
  Timer? _holdTimer;
  int _holdProgress = 0;

  final _alertTypes = [
    const _AlertType(SosAlertType.aggression, 'Agression',
        Icons.warning_amber_rounded, AppColors.danger),
    const _AlertType(SosAlertType.accident, 'Accident', Icons.car_crash_rounded,
        AppColors.warning),
    const _AlertType(SosAlertType.medical, 'Urgence médicale',
        Icons.medical_services_rounded, Color(0xFF4A9EFF)),
    const _AlertType(SosAlertType.kidnapping, 'Enlèvement',
        Icons.no_encryption_rounded, Color(0xFFBB86FC)),
    const _AlertType(SosAlertType.robbery, 'Vol / Braquage',
        Icons.money_off_rounded, Color(0xFFFF6B35)),
    const _AlertType(SosAlertType.other, 'Autre', Icons.more_horiz_rounded,
        AppColors.textMuted),
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _ringAnim = Tween<double>(begin: 0.8, end: 1.4).animate(
      CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _ringCtrl.dispose();
    _holdTimer?.cancel();
    super.dispose();
  }

  void _onHoldStart() {
    if (_selectedType == null) {
      _showSelectTypeSnack();
      return;
    }
    setState(() {
      _holding = true;
      _holdProgress = 0;
    });
    HapticFeedback.heavyImpact();

    _holdTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      setState(() => _holdProgress++);
      if (_holdProgress >= 30) {
        t.cancel();
        _triggerSos();
      }
    });
  }

  void _onHoldEnd() {
    _holdTimer?.cancel();
    setState(() {
      _holding = false;
      _holdProgress = 0;
    });
  }

  Future<void> _triggerSos() async {
    HapticFeedback.vibrate();
    if (_selectedType == null) return;
    await ref.read(sosProvider.notifier).triggerSos(_selectedType!);
  }

  void _showSelectTypeSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Choisissez d\'abord le type d\'alerte'),
        backgroundColor: AppColors.warningSurface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sosState = ref.watch(sosProvider);

    // Naviguer automatiquement si SOS envoyé
    ref.listen(sosProvider, (_, next) {
      if (next.status == SosStatus.sent) {
        _showSosConfirmation();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Alerte SOS'),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Annuler',
                style: TextStyle(color: AppColors.textMuted)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // Avertissement discret
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.warning, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Votre position GPS sera partagée avec vos contacts d\'urgence et la plateforme.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Bouton SOS central
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Anneau pulsant
                    if (_holding || sosState.status == SosStatus.sending)
                      AnimatedBuilder(
                        animation: _ringCtrl,
                        builder: (_, __) => Transform.scale(
                          scale: _ringAnim.value,
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.danger.withValues(
                                    alpha: 1.0 - _ringAnim.value * 0.7),
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Bouton principal
                    GestureDetector(
                      onLongPressStart: (_) => _onHoldStart(),
                      onLongPressEnd: (_) => _onHoldEnd(),
                      onLongPressCancel: _onHoldEnd,
                      child: AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (_, __) => Transform.scale(
                          scale: _holding ? _pulseAnim.value : 1.0,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  gradient: const RadialGradient(
                                    colors: [
                                      AppColors.dangerDark,
                                      AppColors.danger,
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.danger.withValues(
                                          alpha: _holding ? 0.6 : 0.35),
                                      blurRadius: _holding ? 40 : 24,
                                      spreadRadius: _holding ? 8 : 4,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    sosState.status == SosStatus.sending
                                        ? const SizedBox(
                                            width: 36,
                                            height: 36,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 3,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.emergency_rounded,
                                            color: Colors.white,
                                            size: 52,
                                          ),
                                    const SizedBox(height: 4),
                                    Text(
                                      sosState.status == SosStatus.sending
                                          ? 'Envoi...'
                                          : 'SOS',
                                      style: AppTextStyles.headlineMedium
                                          .copyWith(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),

                              // Barre de progression circulaire
                              if (_holding)
                                SizedBox(
                                  width: 164,
                                  height: 164,
                                  child: CircularProgressIndicator(
                                    value: _holdProgress / 30,
                                    strokeWidth: 4,
                                    color: Colors.white,
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.2),
                                    strokeCap: StrokeCap.round,
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

              const SizedBox(height: 12),
              Text(
                _holding
                    ? 'Maintenir encore...'
                    : 'Maintenir appuyé pour déclencher',
                style: AppTextStyles.bodySmall.copyWith(
                  color: _holding ? AppColors.danger : AppColors.textMuted,
                  fontWeight: _holding ? FontWeight.w600 : FontWeight.w400,
                ),
              ),

              const SizedBox(height: 32),

              // Sélection type d'alerte
              const Align(
                alignment: Alignment.centerLeft,
                child:
                    Text('Type d\'incident', style: AppTextStyles.titleLarge),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.1,
                  children: _alertTypes.map((t) {
                    final selected = _selectedType == t.type;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedType = t.type),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: selected
                              ? t.color.withValues(alpha: 0.15)
                              : AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? t.color : AppColors.border,
                            width: selected ? 1.5 : 0.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(t.icon,
                                color: selected ? t.color : AppColors.textMuted,
                                size: 26),
                            const SizedBox(height: 6),
                            Text(
                              t.label,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.caption.copyWith(
                                color: selected
                                    ? t.color
                                    : AppColors.textSecondary,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showSosConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 48),
            ),
            const SizedBox(height: 20),
            const Text('Alerte SOS envoyée',
                style: AppTextStyles.headlineMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'Vos contacts d\'urgence ont été notifiés '
              'avec votre position GPS.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.pop();
              },
              child: const Text('Compris'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertType {
  final SosAlertType type;
  final String label;
  final IconData icon;
  final Color color;
  const _AlertType(this.type, this.label, this.icon, this.color);
}
