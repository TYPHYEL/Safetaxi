// lib/features/taxi/presentation/screens/my_taxis_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safetaxi_cameroun/core/constants/app_constants.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/providers/auth_provider.dart';
import 'package:safetaxi_cameroun/features/taxi/presentation/screens/taxi_display_utils.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';

class MyTaxisScreen extends ConsumerStatefulWidget {
  const MyTaxisScreen({super.key});

  @override
  ConsumerState<MyTaxisScreen> createState() => _MyTaxisScreenState();
}

class _MyTaxisScreenState extends ConsumerState<MyTaxisScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _taxis = [];

  @override
  void initState() {
    super.initState();
    _loadTaxis();
  }

  Future<void> _loadTaxis() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final resp = await api.get('/taxis/');
      final data = resp.data;
      final parsed = <Map<String, dynamic>>[];

      if (data is List) {
        parsed.addAll(
            data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
      } else if (data is Map) {
        final results = data['results'];
        if (results is List) {
          parsed.addAll(results
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e)));
        }
      }

      setState(() {
        _taxis = parsed;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Mes taxis'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: 'Mon compte',
            onPressed: () => context.push(AppRoutes.profil),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _taxis.isEmpty
              ? _buildEmptyState()
              : _buildTaxisList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.taxiCreate),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.directions_car_rounded,
              size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text('Aucun taxi enregistré',
              style: AppTextStyles.titleMedium
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          const Text('Ajoutez votre premier taxi',
              style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }

  Widget _buildTaxisList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _taxis.length,
      itemBuilder: (context, index) {
        final taxi = _taxis[index];
        return _TaxiCard(
          taxi: taxi,
          onTap: () => context.push('/taxi/${taxi['id']}'),
        );
      },
    );
  }
}

class _TaxiCard extends StatelessWidget {
  final Map<String, dynamic> taxi;
  final VoidCallback onTap;

  const _TaxiCard({required this.taxi, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final displayInfo = TaxiDisplayInfo.fromMap(taxi);
    final hasActiveDriver = taxi['active_driver'] != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: AppDecorations.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.ownerColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.directions_car_rounded,
                      color: AppColors.ownerColor, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayInfo.plate,
                          style: AppTextStyles.headlineMedium
                              .copyWith(color: AppColors.ownerColor)),
                      const SizedBox(height: 4),
                      Text(displayInfo.label, style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
                _StatusIndicator(
                  isActive: displayInfo.isActive,
                  hasActiveDriver: hasActiveDriver,
                ),
              ],
            ),
            if (hasActiveDriver) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_rounded,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Conduit par: ${taxi['active_driver']['first_name']} ${taxi['active_driver']['last_name']}',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final bool isActive;
  final bool hasActiveDriver;

  const _StatusIndicator(
      {required this.isActive, required this.hasActiveDriver});

  @override
  Widget build(BuildContext context) {
    if (!isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.textMuted.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.textMuted,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text('Inactif',
                style:
                    AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    if (hasActiveDriver) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text('En service',
                style:
                    AppTextStyles.caption.copyWith(color: AppColors.primary)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.warning,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text('Disponible',
              style: AppTextStyles.caption.copyWith(color: AppColors.warning)),
        ],
      ),
    );
  }
}
