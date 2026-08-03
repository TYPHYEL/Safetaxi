// lib/features/trajet/presentation/screens/scan_taxi_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:safetaxi_cameroun/core/constants/app_constants.dart';
import 'package:safetaxi_cameroun/features/trajet/presentation/providers/trajet_provider.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';

class ScanTaxiScreen extends ConsumerStatefulWidget {
  const ScanTaxiScreen({super.key});
  @override
  ConsumerState<ScanTaxiScreen> createState() => _ScanTaxiScreenState();
}

class _ScanTaxiScreenState extends ConsumerState<ScanTaxiScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _qrCtrl = MobileScannerController();
  final _codeCtrl = TextEditingController();
  late final TabController _tabCtrl;
  bool _isProcessing = false;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _qrCtrl.dispose();
    _codeCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _joinByCode(String raw) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final tripId = extractTripIdFromInput(raw);
    final joinMethod = joinMethodForInput(raw);

    final ok = await ref
        .read(activeTripProvider.notifier)
        .joinTrip(tripId, joinMethod);

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (ok) {
      context.pushReplacement(
          '${AppRoutes.tripActive}?tripId=$tripId');
    } else {
      _showError('Taxi introuvable ou trajet inactif');
    }
  }

  void _showError(String msg) {
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Rejoindre un taxi'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_scanner_rounded), text: 'Scanner QR'),
            Tab(icon: Icon(Icons.keyboard_rounded), text: 'Code manuel'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildQrTab(),
          _buildManualTab(),
        ],
      ),
    );
  }

  Widget _buildQrTab() {
    return Stack(
      children: [
        // Scanner caméra
        MobileScanner(
          controller: _qrCtrl,
          onDetect: (capture) {
            final barcode = capture.barcodes.firstOrNull;
            if (barcode?.rawValue != null) {
              _joinByCode(barcode!.rawValue!);
            }
          },
        ),

        // Overlay de scan
        CustomPaint(
          painter: _ScanOverlayPainter(),
          child: const SizedBox.expand(),
        ),

        // Zone centrale
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary, width: 2.2),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: _isProcessing
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  )
                : null,
          ),
        ),

        // Texte indicatif
        Positioned(
          top: MediaQuery.of(context).size.height * 0.55,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              'Placez le QR code du taxi dans le cadre',
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.8),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Contrôles
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ScanButton(
                icon: _torchOn
                    ? Icons.flash_off_rounded
                    : Icons.flash_on_rounded,
                label: 'Torche',
                onTap: () {
                  _qrCtrl.toggleTorch();
                  setState(() => _torchOn = !_torchOn);
                },
              ),
              const SizedBox(width: 24),
              _ScanButton(
                icon: Icons.flip_camera_ios_rounded,
                label: 'Caméra',
                onTap: () => _qrCtrl.switchCamera(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManualTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppDecorations.card(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.local_taxi_rounded,
                          color: AppColors.taxiYellow, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Text('Code du taxi',
                        style: AppTextStyles.headlineMedium),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Demandez le code au chauffeur ou repérez-le à l\'intérieur du taxi.',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),
          const Text('Entrez le code', style: AppTextStyles.titleLarge),
          const SizedBox(height: 12),

          TextFormField(
            controller: _codeCtrl,
            style: AppTextStyles.headlineMedium.copyWith(
              letterSpacing: 8,
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            maxLength: 8,
            decoration: const InputDecoration(
              counterText: '',
              hintText: 'EX: AB12CD34',
              hintStyle: TextStyle(
                letterSpacing: 4,
                color: AppColors.textMuted,
                fontSize: 20,
              ),
            ),
          ),

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isProcessing
                  ? null
                  : () {
                      if (_codeCtrl.text.trim().length >= 6) {
                        _joinByCode(_codeCtrl.text.trim());
                      } else {
                        _showError('Code trop court (minimum 6 caractères)');
                      }
                    },
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.login_rounded),
              label: Text(_isProcessing ? 'Connexion...' : 'Rejoindre le taxi'),
            ),
          ),

          const SizedBox(height: 32),

          // Autres méthodes
          const Text('Autres méthodes', style: AppTextStyles.titleLarge),
          const SizedBox(height: 12),
          _MethodTile(
            icon: Icons.bluetooth_rounded,
            title: 'Bluetooth proximité',
            subtitle: 'Détecter automatiquement les taxis proches',
            color: AppColors.driverColor,
            onTap: () => _showBluetoothSheet(),
          ),
          const SizedBox(height: 10),
          _MethodTile(
            icon: Icons.near_me_rounded,
            title: 'Taxis à proximité',
            subtitle: 'Voir les taxis actifs autour de vous',
            color: AppColors.ownerColor,
            onTap: () => context.push(AppRoutes.map),
          ),
        ],
      ),
    );
  }

  void _showBluetoothSheet() {
    showModalBottomSheet(
      context: context,
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
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            const Icon(Icons.bluetooth_searching_rounded,
                color: AppColors.driverColor, size: 48),
            const SizedBox(height: 16),
            const Text('Recherche Bluetooth',
                style: AppTextStyles.headlineMedium),
            const SizedBox(height: 8),
            const Text(
              'Activez le Bluetooth et approchez-vous du taxi pour une connexion automatique.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const LinearProgressIndicator(
              color: AppColors.driverColor,
              backgroundColor: AppColors.surfaceElevated,
            ),
            const SizedBox(height: 16),
            Text('Recherche en cours...',
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.driverColor)),
          ],
        ),
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ScanButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11)),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _MethodTile(
      {required this.icon,
      required this.title,
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
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.titleMedium),
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

class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6);

    final cx = size.width / 2;
    final cy = size.height / 2;
    const half = 110.0;

    final cutout = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(cx, cy), width: half * 2, height: half * 2),
      const Radius.circular(20),
    );

    final full = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = Path()
      ..addRect(full)
      ..addRRect(cutout)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
