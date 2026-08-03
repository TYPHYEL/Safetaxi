// lib/features/taxi/presentation/screens/taxi_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:safetaxi_cameroun/core/constants/app_constants.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/providers/auth_provider.dart';
import 'package:safetaxi_cameroun/features/taxi/presentation/screens/taxi_display_utils.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────
// Provider pour les détails d'un taxi
// ─────────────────────────────────────────────────────────

final taxiDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, taxiId) async {
  try {
    final api = ref.watch(apiClientProvider);
    final resp = await api.getTaxiById(taxiId);
    return resp.data as Map<String, dynamic>;
  } catch (_) {
    // Mock data pour le développement
    return {
      'id': taxiId,
      'plate': 'LT4521A',
      'license_number': 'YDE-2024-001',
      'brand': 'Toyota',
      'model': 'Corolla',
      'color': 'Jaune',
      'is_active': true,
      'owner': {'first_name': 'André', 'last_name': 'BELINGA'},
      'active_driver': {
        'user': {'first_name': 'Jean', 'last_name': 'NKOLO'},
        'trust_score': 4.6,
        'total_trips': 287,
        'is_approved': true,
      },
    };
  }
});

// ─────────────────────────────────────────────────────────
// TAXI DETAIL SCREEN
// ─────────────────────────────────────────────────────────

class TaxiDetailScreen extends ConsumerWidget {
  final String taxiId;
  const TaxiDetailScreen({super.key, required this.taxiId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taxiAsync = ref.watch(taxiDetailProvider(taxiId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: taxiAsync.when(
        data: (taxi) => _buildBody(context, ref, taxi),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(child: Text('Erreur: $e')),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, WidgetRef ref, Map<String, dynamic> taxi) {
    final displayInfo = TaxiDisplayInfo.fromMap(taxi);
    final activeDriver = taxi['active_driver'] as Map<String, dynamic>?;
    final driverUser = activeDriver?['user'] as Map<String, dynamic>? ?? {};
    final qrData = '${AppConstants.qrPrefix}$taxiId';

    return CustomScrollView(
      slivers: [
        // AppBar avec photo taxi
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          backgroundColor: AppColors.background,
          leading: GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.surfaceElevated, AppColors.background],
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: const Icon(Icons.local_taxi_rounded,
                            color: AppColors.taxiYellow, size: 52),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        displayInfo.label.isNotEmpty
                            ? displayInfo.label
                            : 'Taxi',
                        style: AppTextStyles.headlineMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 16),

              // Statut + Plaque
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: displayInfo.isActive
                          ? AppColors.primarySurface
                          : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: displayInfo.isActive
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: displayInfo.isActive
                                ? AppColors.primary
                                : AppColors.offline,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          displayInfo.isActive ? 'En service' : 'Hors service',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: displayInfo.isActive
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      displayInfo.plate,
                      style: AppTextStyles.titleLarge.copyWith(
                        color: AppColors.textPrimary,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Infos taxi
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppDecorations.card(),
                child: Column(
                  children: [
                    _InfoRow2('Marque / Modèle', displayInfo.label),
                    const Divider(height: 16),
                    _InfoRow2('Couleur', (taxi['color'] as String?) ?? '—'),
                    const Divider(height: 16),
                    _InfoRow2('N° licence',
                        (taxi['license_number'] as String?) ?? '—'),
                    const Divider(height: 16),
                    _InfoRow2(
                      'Propriétaire',
                      displayInfo.ownerName,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Chauffeur actif
              if (activeDriver != null) ...[
                const Text('Chauffeur en service',
                    style: AppTextStyles.titleLarge),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration:
                      AppDecorations.glowCard(glowColor: AppColors.driverColor),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.driverColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.driverColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            (driverUser['first_name'] as String? ?? 'C')[0],
                            style: AppTextStyles.headlineMedium
                                .copyWith(color: AppColors.driverColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${driverUser['first_name']} ${driverUser['last_name']}',
                                  style: AppTextStyles.titleMedium,
                                ),
                                const SizedBox(width: 6),
                                if (activeDriver['is_approved'] == true)
                                  const Icon(Icons.verified_rounded,
                                      color: AppColors.primary, size: 16),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: AppColors.ownerColor, size: 14),
                                const SizedBox(width: 3),
                                Text(
                                  '${activeDriver['trust_score']} · ${activeDriver['total_trips']} trajets',
                                  style: AppTextStyles.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // QR Code
              const Text('QR Code du taxi', style: AppTextStyles.titleLarge),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: AppDecorations.card(),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 160,
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
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Les passagers scannent ce code\npour rejoindre le trajet',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Action rejoindre
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => context.push(AppRoutes.scanTaxi),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Scanner pour rejoindre'),
                ),
              ),

              const SizedBox(height: 40),
            ]),
          ),
        ),
      ],
    );
  }
}

class _InfoRow2 extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow2(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyMedium),
        Text(value,
            style: AppTextStyles.titleMedium
                .copyWith(color: AppColors.textPrimary)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// MY TAXIS SCREEN
// ─────────────────────────────────────────────────────────

final myTaxisProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final resp = await ref.watch(apiClientProvider).getTaxis();
    final list = resp.data['results'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  } catch (_) {
    return [
      {
        'id': 'taxi-001',
        'plate': 'LT4521A',
        'brand': 'Toyota',
        'model': 'Corolla',
        'color': 'Jaune',
        'is_active': true,
        'active_driver': {
          'user': {'first_name': 'Jean', 'last_name': 'NKOLO'}
        },
      },
      {
        'id': 'taxi-002',
        'plate': 'CE2890B',
        'brand': 'Honda',
        'model': 'Civic',
        'color': 'Blanc',
        'is_active': false,
        'active_driver': null,
      },
    ];
  }
});

// ignore: unused_element
class _TaxiListCard extends StatelessWidget {
  final Map<String, dynamic> taxi;
  final VoidCallback onTap;
  final VoidCallback onManageDrivers;
  const _TaxiListCard({
    required this.taxi,
    required this.onTap,
    required this.onManageDrivers,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = taxi['is_active'] as bool? ?? false;
    final activeDriver = taxi['active_driver'] as Map<String, dynamic>?;
    final dUser = activeDriver?['user'] as Map<String, dynamic>?;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppDecorations.card(),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primarySurface
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.local_taxi_rounded,
                    color:
                        isActive ? AppColors.taxiYellow : AppColors.textMuted,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${taxi['brand']} ${taxi['model']}',
                        style: AppTextStyles.titleLarge,
                      ),
                      Row(
                        children: [
                          Text(
                            taxi['plate'] as String? ?? '—',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: AppColors.textMuted,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            taxi['color'] as String? ?? '—',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primarySurface
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isActive ? 'Actif' : 'Inactif',
                    style: AppTextStyles.caption.copyWith(
                      color: isActive ? AppColors.primary : AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (dUser != null) ...[
              const Divider(height: 18),
              Row(
                children: [
                  const Icon(Icons.drive_eta_rounded,
                      color: AppColors.driverColor, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${dUser['first_name']} ${dUser['last_name']}',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.driverColor),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onManageDrivers,
                    child: Text(
                      'Gérer chauffeurs',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const Divider(height: 18),
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.warning, size: 14),
                  const SizedBox(width: 6),
                  Text('Aucun chauffeur actif',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.warning)),
                  const Spacer(),
                  GestureDetector(
                    onTap: onManageDrivers,
                    child: Text(
                      'Assigner',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _EmptyTaxis extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyTaxis({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_taxi_rounded,
              color: AppColors.textMuted, size: 64),
          const SizedBox(height: 16),
          const Text('Aucun taxi enregistré',
              style: AppTextStyles.headlineMedium),
          const SizedBox(height: 8),
          const Text('Ajoutez votre premier taxi pour commencer',
              style: AppTextStyles.bodyMedium),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Ajouter un taxi'),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _DriverCard extends StatelessWidget {
  final Map<String, dynamic> driver;
  const _DriverCard({required this.driver});

  @override
  Widget build(BuildContext context) {
    final isActive = driver['is_active'] as bool? ?? false;
    final score = (driver['trust_score'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: isActive
          ? AppDecorations.glowCard(glowColor: AppColors.driverColor)
          : AppDecorations.card(),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.driverColor.withValues(alpha: 0.12)
                      : AppColors.surfaceElevated,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    (driver['name'] as String)[0],
                    style: AppTextStyles.headlineMedium.copyWith(
                      color: isActive
                          ? AppColors.driverColor
                          : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driver['name'] as String,
                        style: AppTextStyles.titleMedium),
                    Text(driver['phone'] as String,
                        style: AppTextStyles.bodySmall),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            color: AppColors.textMuted, size: 12),
                        const SizedBox(width: 4),
                        Text(driver['shift'] as String,
                            style: AppTextStyles.caption),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primarySurface
                          : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isActive ? '● En service' : '○ Repos',
                      style: AppTextStyles.caption.copyWith(
                        color:
                            isActive ? AppColors.primary : AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          color: AppColors.ownerColor, size: 12),
                      const SizedBox(width: 3),
                      Text(score.toStringAsFixed(1),
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.ownerColor)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.edit_rounded, size: 14),
                  label: const Text('Modifier'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: Icon(
                    isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 14,
                  ),
                  label: Text(isActive ? 'Désactiver' : 'Activer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isActive ? AppColors.warning : AppColors.primary,
                    minimumSize: const Size(0, 36),
                    textStyle: const TextStyle(fontSize: 12),
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

// ─────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────

// ignore: unused_element
class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);
  @override
  Widget build(BuildContext context) => Text(
        label,
        style: AppTextStyles.labelLarge,
      );
}

// ignore: unused_element
class _FormSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _FormSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: AppTextStyles.caption.copyWith(
            letterSpacing: 1.5,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppDecorations.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}

// ignore: unused_element
class _UploadChip extends StatefulWidget {
  final String label;
  final IconData icon;
  const _UploadChip({required this.label, required this.icon});
  @override
  State<_UploadChip> createState() => _UploadChipState();
}

class _UploadChipState extends State<_UploadChip> {
  bool _uploaded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _uploaded = !_uploaded),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _uploaded
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _uploaded ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _uploaded ? Icons.check_circle_rounded : widget.icon,
              color: _uploaded ? AppColors.primary : AppColors.textMuted,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              widget.label,
              style: AppTextStyles.labelMedium.copyWith(
                color: _uploaded ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            if (!_uploaded) ...[
              const SizedBox(width: 8),
              Text('Appuyer pour uploader',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textMuted)),
            ],
          ],
        ),
      ),
    );
  }
}
