// lib/features/admin/presentation/screens/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safetaxi_cameroun/core/constants/app_constants.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/providers/auth_provider.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final resp = await api.getDashboardStats();
      if (mounted) {
        setState(() {
          _stats = resp.data as Map<String, dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Tableau de bord Admin'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Statistiques globales',
                      style: AppTextStyles.headlineLarge),
                  const SizedBox(height: 20),
                  _buildStatsGrid(),
                  const SizedBox(height: 32),
                  const Text('Actions rapides',
                      style: AppTextStyles.headlineLarge),
                  const SizedBox(height: 16),
                  _buildActionsGrid(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _StatCard(
          label: 'Totaux taxis',
          value: '${_stats?['total_taxis'] ?? 0}',
          icon: Icons.directions_car_rounded,
          color: AppColors.ownerColor,
        ),
        _StatCard(
          label: 'Chauffeurs',
          value: '${_stats?['total_drivers'] ?? 0}',
          icon: Icons.people_rounded,
          color: AppColors.driverColor,
        ),
        _StatCard(
          label: 'Passagers',
          value: '${_stats?['total_passengers'] ?? 0}',
          icon: Icons.person_rounded,
          color: AppColors.passengerColor,
        ),
        _StatCard(
          label: 'Trajets actifs',
          value: '${_stats?['active_trips'] ?? 0}',
          icon: Icons.route_rounded,
          color: AppColors.primary,
        ),
        _StatCard(
          label: 'En attente',
          value: '${_stats?['pending_drivers'] ?? 0}',
          icon: Icons.pending_rounded,
          color: AppColors.warning,
        ),
        _StatCard(
          label: 'Alertes SOS',
          value: '${_stats?['sos_alerts'] ?? 0}',
          icon: Icons.emergency_rounded,
          color: AppColors.danger,
        ),
      ],
    );
  }

  Widget _buildActionsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2,
      children: [
        _ActionCard(
          label: 'Valider chauffeurs',
          icon: Icons.check_circle_rounded,
          color: AppColors.primary,
          onTap: () => context.push(AppRoutes.adminDrivers),
        ),
        _ActionCard(
          label: 'Gérer taxis',
          icon: Icons.directions_car_rounded,
          color: AppColors.ownerColor,
          onTap: () {},
        ),
        _ActionCard(
          label: 'Alertes SOS',
          icon: Icons.emergency_rounded,
          color: AppColors.danger,
          onTap: () {},
        ),
        _ActionCard(
          label: 'Rapports',
          icon: Icons.analytics_rounded,
          color: AppColors.driverColor,
          onTap: () {},
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.displayLarge.copyWith(color: color)),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: AppTextStyles.titleMedium),
            ),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    );
  }
}
