// lib/features/taxi/presentation/screens/manage_drivers_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/providers/auth_provider.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';
import 'package:safetaxi_cameroun/shared/widgets/safe_avatar.dart';

class ManageDriversScreen extends ConsumerStatefulWidget {
  final String taxiId;
  const ManageDriversScreen({super.key, required this.taxiId});

  @override
  ConsumerState<ManageDriversScreen> createState() => _ManageDriversScreenState();
}

class _ManageDriversScreenState extends ConsumerState<ManageDriversScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _drivers = [];

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final resp = await api.get('/taxis/${widget.taxiId}/drivers/');
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
        title: const Text('Gérer les chauffeurs'),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDriverDialog,
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
          const Icon(Icons.people_outline_rounded,
              size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text('Aucun chauffeur',
              style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          const Text('Ajoutez des chauffeurs à ce taxi',
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
        return _DriverTile(
          driver: driver,
          onActivate: () => _toggleDriver(driver['id'], true),
          onDeactivate: () => _toggleDriver(driver['id'], false),
          onRemove: () => _removeDriver(driver['id']),
        );
      },
    );
  }

  void _showAddDriverDialog() {
    final phoneCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Ajouter un chauffeur'),
        content: TextField(
          controller: phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Numéro de téléphone',
            hintText: '+237 6XX XXX XXX',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _addDriver(phoneCtrl.text.trim());
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Future<void> _addDriver(String phone) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/taxis/${widget.taxiId}/drivers/', data: {'phone': phone});
      _loadDrivers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _toggleDriver(String driverId, bool activate) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/drivers/$driverId/${activate ? 'activate' : 'deactivate'}/');
      _loadDrivers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _removeDriver(String driverId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Retirer ce chauffeur?'),
        content: const Text('Ce chauffeur ne pourra plus conduire ce taxi.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final api = ref.read(apiClientProvider);
        await api.delete('/taxis/${widget.taxiId}/drivers/$driverId/');
        _loadDrivers();
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

class _DriverTile extends StatelessWidget {
  final Map<String, dynamic> driver;
  final VoidCallback onActivate;
  final VoidCallback onDeactivate;
  final VoidCallback onRemove;

  const _DriverTile({
    required this.driver,
    required this.onActivate,
    required this.onDeactivate,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = driver['is_currently_active'] as bool? ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(),
      child: Row(
        children: [
          SafeAvatar(
            photoUrl: driver['photo_url'] as String?,
            initials: _getInitials(driver),
            size: 48,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${driver['first_name']} ${driver['last_name']}',
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  driver['phone'] as String? ?? '',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _StatusBadge(
                      isActive: isActive,
                      isApproved: driver['is_approved'] as bool? ?? false,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (isActive)
            IconButton(
              icon: const Icon(Icons.stop_circle_rounded),
              color: AppColors.warning,
              onPressed: onDeactivate,
            )
          else
            IconButton(
              icon: const Icon(Icons.play_circle_rounded),
              color: AppColors.primary,
              onPressed: onActivate,
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            color: AppColors.danger,
            onPressed: onRemove,
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

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  final bool isApproved;

  const _StatusBadge({required this.isActive, required this.isApproved});

  @override
  Widget build(BuildContext context) {
    if (!isApproved) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text('En attente',
            style: AppTextStyles.caption.copyWith(color: AppColors.warning)),
      );
    }
    if (isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text('En service',
            style: AppTextStyles.caption.copyWith(color: AppColors.primary)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.textMuted.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('Hors service',
          style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
    );
  }
}

