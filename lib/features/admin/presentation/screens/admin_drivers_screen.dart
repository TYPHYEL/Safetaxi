// lib/features/admin/presentation/screens/admin_drivers_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/providers/auth_provider.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';
import 'package:safetaxi_cameroun/shared/widgets/safe_avatar.dart';

class AdminDriversScreen extends ConsumerStatefulWidget {
  const AdminDriversScreen({super.key});

  @override
  ConsumerState<AdminDriversScreen> createState() => _AdminDriversScreenState();
}

class _AdminDriversScreenState extends ConsumerState<AdminDriversScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _drivers = [];

  @override
  void initState() {
    super.initState();
    _loadPendingDrivers();
  }

  Future<void> _loadPendingDrivers() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final resp = await api.get('/admin/drivers/pending/');
      setState(() {
        _drivers = (resp.data as List).cast<Map<String, dynamic>>();
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
        title: const Text('Validation chauffeurs'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _drivers.isEmpty
              ? _buildEmptyState()
              : _buildDriversList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 64, color: AppColors.primary),
          const SizedBox(height: 16),
          Text('Aucun chauffeur en attente',
              style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          const Text('Tous les chauffeurs sont validés',
              style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }

  Widget _buildDriversList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _drivers.length,
      itemBuilder: (context, index) {
        final driver = _drivers[index];
        return _DriverCard(
          driver: driver,
          onApprove: () => _approveDriver(driver['id']),
          onReject: () => _rejectDriver(driver['id']),
        );
      },
    );
  }

  Future<void> _approveDriver(String driverId) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/admin/drivers/$driverId/approve/');
      _loadPendingDrivers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chauffeur approuvé')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _rejectDriver(String driverId) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Rejeter ce chauffeur?'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Motif du rejet',
            hintText: 'Expliquez pourquoi...',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonCtrl.text.isNotEmpty) {
      try {
        final api = ref.read(apiClientProvider);
        await api.post('/admin/drivers/$driverId/reject/',
            data: {'reason': reasonCtrl.text});
        _loadPendingDrivers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chauffeur rejeté')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
  }
}

class _DriverCard extends StatelessWidget {
  final Map<String, dynamic> driver;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _DriverCard({
    required this.driver,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SafeAvatar(
                photoUrl: driver['selfie_url'] as String?,
                initials: _getInitials(driver),
                size: 56,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${driver['first_name']} ${driver['last_name']}',
                      style: AppTextStyles.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      driver['phone'] as String? ?? '',
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Permis: ${driver['license_number'] ?? 'N/A'}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _DocumentChip(
                label: 'CNI',
                hasDoc: driver['cni_url'] != null,
              ),
              const SizedBox(width: 8),
              _DocumentChip(
                label: 'Permis',
                hasDoc: driver['license_url'] != null,
              ),
              const SizedBox(width: 8),
              _DocumentChip(
                label: 'Selfie',
                hasDoc: driver['selfie_url'] != null,
              ),
              const SizedBox(width: 8),
              _DocumentChip(
                label: 'Carte grise',
                hasDoc: driver['registration_url'] != null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Rejeter'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Approuver'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getInitials(Map<String, dynamic> driver) {
    final first = driver['first_name'] as String? ?? '';
    final last = driver['last_name'] as String? ?? '';
    return '${first.isNotEmpty ? first[0] : ''}${last.isNotEmpty ? last[0] : ''}';
  }
}

class _DocumentChip extends StatelessWidget {
  final String label;
  final bool hasDoc;

  const _DocumentChip({required this.label, required this.hasDoc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: hasDoc
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.textMuted.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasDoc
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.textMuted.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasDoc ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 14,
            color: hasDoc ? AppColors.primary : AppColors.textMuted,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: hasDoc ? AppColors.primary : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

