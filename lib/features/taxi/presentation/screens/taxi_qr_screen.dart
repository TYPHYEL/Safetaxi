// lib/features/taxi/presentation/screens/taxi_qr_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:safetaxi_cameroun/core/constants/app_constants.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/providers/auth_provider.dart';
import 'package:safetaxi_cameroun/features/taxi/presentation/screens/taxi_display_utils.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';

// ─── Provider pour les taxis du chauffeur ─────────────────

final driverTaxisProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final resp = await ref.watch(apiClientProvider).getTaxis();
    final data = resp.data;
    if (data is List) {
      return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (data is Map) {
      final results = data['results'];
      if (results is List) {
        return results.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }
    return [];
  } catch (_) {
    return [
      {
        'id': 'taxi-driver-001',
        'plate': 'LT4521A',
        'brand': 'Toyota',
        'model': 'Corolla',
        'color': 'Jaune',
        'license_number': 'YDE-2024-001',
      },
    ];
  }
});

// ─── Taxi QR Screen ───────────────────────────────────────

class TaxiQrScreen extends ConsumerStatefulWidget {
  const TaxiQrScreen({super.key});

  @override
  ConsumerState<TaxiQrScreen> createState() => _TaxiQrScreenState();
}

class _TaxiQrScreenState extends ConsumerState<TaxiQrScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  String? _selectedTaxiId;
  String? _selectedPlate;
  final GlobalKey _qrKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  String get _qrData =>
      _selectedTaxiId != null
          ? '${AppConstants.qrPrefix}$_selectedTaxiId'
          : '';

  Future<void> _shareQr() async {
    if (_qrData.isEmpty) return;

    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final tmp = await getTemporaryDirectory();
      final file = File(
          '${tmp.path}/safetaxi_${_selectedPlate ?? 'qr'}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Scannez ce QR code SafeTaxi pour rejoindre mon taxi $_selectedPlate',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final taxisAsync = ref.watch(driverTaxisProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('QR Code Taxi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: AppColors.primary),
            onPressed: _qrData.isNotEmpty ? _shareQr : null,
          ),
        ],
      ),
      body: taxisAsync.when(
        data: (taxis) => _buildBody(context, taxis),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(child: Text('Erreur: $e')),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<Map<String, dynamic>> taxis) {
    if (taxis.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_taxi_rounded,
                color: AppColors.textMuted, size: 64),
            const SizedBox(height: 16),
            const Text('Aucun taxi disponible',
                style: AppTextStyles.headlineMedium),
            const SizedBox(height: 8),
            const Text('Enregistrez d\'abord un taxi',
                style: AppTextStyles.bodyMedium),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push(AppRoutes.taxiCreate),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter un taxi'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Sélecteur de taxi
          _buildTaxiSelector(taxis),
          const SizedBox(height: 24),

          // QR Code
          if (_selectedTaxiId != null) ...[
            _buildQrSection(),
            const SizedBox(height: 24),
            _buildInstructions(),
            const SizedBox(height: 24),
            _buildShareButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildTaxiSelector(List<Map<String, dynamic>> taxis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sélectionnez le taxi',
            style: AppTextStyles.titleLarge),
        const SizedBox(height: 12),
        ...taxis.map((t) {
          final displayInfo = TaxiDisplayInfo.fromMap(
            Map<String, dynamic>.from(t),
          );
          final isSelected = _selectedTaxiId == t['id'];
          return GestureDetector(
            onTap: () => setState(() {
              _selectedTaxiId = t['id'].toString();
              _selectedPlate = displayInfo.plate;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primarySurface
                    : AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.border,
                  width: isSelected ? 1.5 : 0.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.local_taxi_rounded,
                      color: isSelected
                          ? AppColors.taxiYellow
                          : AppColors.textMuted,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayInfo.label.isNotEmpty ? displayInfo.label : 'Taxi',
                          style: AppTextStyles.titleMedium,
                        ),
                        Text(
                          displayInfo.plate,
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 16),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildQrSection() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, __) => Transform.scale(
        scale: _pulseAnim.value,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              // Badge plaque
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_taxi_rounded,
                        color: AppColors.taxiYellow, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      _selectedPlate ?? '',
                      style: AppTextStyles.labelLarge.copyWith(
                        letterSpacing: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // QR Code
              RepaintBoundary(
                key: _qrKey,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      QrImageView(
                        data: _qrData,
                        version: QrVersions.auto,
                        size: 200,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppColors.background,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppColors.background,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Logo SafeTaxi sous le QR
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.primarySurface,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.shield_rounded,
                              color: AppColors.primary,
                              size: 12,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'SAFETAXI',
                            style: TextStyle(
                              color: AppColors.background,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Code texte
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _selectedPlate ?? '',
                  style: AppTextStyles.headlineMedium.copyWith(
                    letterSpacing: 4,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text('Comment utiliser',
                  style: AppTextStyles.titleMedium
                      .copyWith(color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 12),
          const _InstructionStep(
              number: '1',
              text: 'Affichez ce code QR à l\'intérieur du taxi'),
          const SizedBox(height: 8),
          const _InstructionStep(
              number: '2',
              text: 'Les passagers le scannent pour rejoindre le trajet'),
          const SizedBox(height: 8),
          const _InstructionStep(
              number: '3',
              text: 'Vous êtes tracable en temps réel automatiquement'),
        ],
      ),
    );
  }

  Widget _buildShareButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _shareQr,
        icon: const Icon(Icons.share_rounded),
        label: const Text('Partager le QR Code'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.driverColor,
        ),
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  final String number;
  final String text;

  const _InstructionStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: AppTextStyles.bodyMedium),
        ),
      ],
    );
  }
}
