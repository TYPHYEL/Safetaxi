// lib/features/taxi/presentation/screens/shift_history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:safetaxi_cameroun/core/services/driver_rotation_service.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';

class ShiftHistoryScreen extends ConsumerStatefulWidget {
  const ShiftHistoryScreen({super.key});

  @override
  ConsumerState<ShiftHistoryScreen> createState() => _ShiftHistoryScreenState();
}

class _ShiftHistoryScreenState extends ConsumerState<ShiftHistoryScreen> {
  DriverRotationService get _rotationService => ref.read(driverRotationServiceProvider);
  List<Map<String, dynamic>> _shiftHistory = [];
  Map<String, dynamic>? _activeShift;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final history = await _rotationService.getShiftHistory();
      final active = await _rotationService.getActiveShift();

      setState(() {
        _shiftHistory = history;
        _activeShift = active;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Erreur chargement données: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.dangerSurface),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des Shifts'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                children: [
                  // Active shift card
                  if (_activeShift != null) ...[
                    _buildActiveShiftCard(_activeShift!),
                    const Divider(),
                  ],

                  // History list
                  if (_shiftHistory.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Aucun historique disponible'),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _shiftHistory.length,
                      itemBuilder: (context, index) {
                        final shift = _shiftHistory[index];
                        return _buildShiftCard(shift);
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildActiveShiftCard(Map<String, dynamic> shift) {
    final startTime = DateTime.parse(shift['shift_start']);
    final duration = DateTime.now().difference(startTime);
    
    return Card(
      color: AppColors.primary.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.play_circle, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Shift Actif',
                  style: AppTextStyles.headline6.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailRow('Taxi', shift['taxi_plate'] ?? 'N/A'),
            _buildDetailRow('Début', DateFormat('dd/MM/yyyy HH:mm').format(startTime)),
            _buildDetailRow('Durée', _formatDuration(duration)),
            if (shift['total_trips'] != null)
              _buildDetailRow('Trajets', shift['total_trips'].toString()),
            if (shift['total_distance'] != null)
              _buildDetailRow('Distance', '${shift['total_distance']} km'),
            if (shift['total_revenue'] != null)
              _buildDetailRow('Revenus', '${shift['total_revenue']} FCFA'),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftCard(Map<String, dynamic> shift) {
    final startTime = DateTime.parse(shift['shift_start']);
    final endTime = shift['shift_end'] != null
        ? DateTime.parse(shift['shift_end'])
        : null;
    
    final duration = endTime?.difference(startTime);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Text(
          DateFormat('dd/MM/yyyy').format(startTime),
          style: AppTextStyles.bodyLarge,
        ),
        subtitle: Text(
          endTime != null
              ? '${DateFormat('HH:mm - HH:mm').format(startTime)} - ${DateFormat('HH:mm').format(endTime)}'
              : 'En cours',
        ),
        trailing: shift['ended_cleanly'] == true
            ? const Icon(Icons.check_circle, color: AppColors.success)
            : const Icon(Icons.warning, color: AppColors.warning),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Taxi', shift['taxi_plate'] ?? 'N/A'),
                _buildDetailRow('Début', DateFormat('HH:mm').format(startTime)),
                if (endTime != null)
                  _buildDetailRow('Fin', DateFormat('HH:mm').format(endTime)),
                if (duration != null)
                  _buildDetailRow('Durée', _formatDuration(duration)),
                if (shift['total_trips'] != null)
                  _buildDetailRow('Trajets', shift['total_trips'].toString()),
                if (shift['total_distance'] != null)
                  _buildDetailRow('Distance', '${shift['total_distance']} km'),
                if (shift['total_revenue'] != null)
                  _buildDetailRow('Revenus', '${shift['total_revenue']} FCFA'),
                if (shift['notes'] != null && shift['notes'].isNotEmpty)
                  _buildDetailRow('Notes', shift['notes']),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours}h ${minutes}min';
  }
}
