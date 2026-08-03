// lib/features/taxi/presentation/screens/rotation_management_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safetaxi_cameroun/core/services/driver_rotation_service.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';

class RotationManagementScreen extends ConsumerStatefulWidget {
  final String taxiId;

  const RotationManagementScreen({super.key, required this.taxiId});

  @override
  ConsumerState<RotationManagementScreen> createState() => _RotationManagementScreenState();
}

class _RotationManagementScreenState extends ConsumerState<RotationManagementScreen> {
  DriverRotationService get _rotationService => ref.read(driverRotationServiceProvider);
  List<Map<String, dynamic>> _rotations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRotations();
  }

  Future<void> _loadRotations() async {
    setState(() => _isLoading = true);

    try {
      final rotations = await _rotationService.getRotations();
      setState(() {
        _rotations = rotations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Erreur chargement rotations: $e');
    }
  }

  Future<void> _toggleRotation(String rotationId, bool isActive) async {
    try {
      if (isActive) {
        await _rotationService.deactivateRotation(rotationId);
      } else {
        await _rotationService.activateRotation(rotationId);
      }
      await _loadRotations();
      _showSuccess(isActive ? 'Rotation désactivée' : 'Rotation activée');
    } catch (e) {
      _showError('Erreur: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.dangerSurface),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Rotations'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateRotationDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRotations,
              child: _rotations.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'Aucune rotation configurée',
                              style: AppTextStyles.bodyLarge,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Appuyez sur + pour créer une rotation',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _rotations.length,
                      itemBuilder: (context, index) {
                        final rotation = _rotations[index];
                        return _buildRotationCard(rotation);
                      },
                    ),
            ),
    );
  }

  Widget _buildRotationCard(Map<String, dynamic> rotation) {
    final isActive = rotation['is_active'] ?? false;
    final shiftType = rotation['shift_type'] ?? 'full';
    final days = rotation['days_of_week'] as List? ?? [];
    final startTime = rotation['start_time'] ?? '';
    final endTime = rotation['end_time'] ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Icon(
          _getShiftIcon(shiftType),
          color: isActive ? AppColors.primary : Colors.grey,
        ),
        title: Text(
          DriverRotationService.getShiftTypeLabel(shiftType),
          style: AppTextStyles.bodyLarge,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${DriverRotationService.formatTime(startTime)} - ${DriverRotationService.formatTime(endTime)}',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              DriverRotationService.getDayNames(days.map((d) => d as int).toList()).join(', '),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        trailing: Switch(
          value: isActive,
          onChanged: (value) => _toggleRotation(rotation['id'].toString(), value),
        ),
      ),
    );
  }

  IconData _getShiftIcon(String shiftType) {
    switch (shiftType) {
      case 'day':
        return Icons.wb_sunny;
      case 'night':
        return Icons.nightlight;
      default:
        return Icons.access_time;
    }
  }

  void _showCreateRotationDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateRotationDialog(
        taxiId: widget.taxiId,
        onCreated: _loadRotations,
      ),
    );
  }
}

class CreateRotationDialog extends ConsumerStatefulWidget {
  final String taxiId;
  final VoidCallback onCreated;

  const CreateRotationDialog({
    super.key,
    required this.taxiId,
    required this.onCreated,
  });

  @override
  ConsumerState<CreateRotationDialog> createState() =>
      _CreateRotationDialogState();
}

class _CreateRotationDialogState extends ConsumerState<CreateRotationDialog> {
  final _formKey = GlobalKey<FormState>();

  String _shiftType = 'full';
  final List<int> _selectedDays = [1, 2, 3, 4, 5];
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouvelle Rotation'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Shift type
              DropdownButtonFormField<String>(
                value: _shiftType,
                decoration: const InputDecoration(
                  labelText: 'Type de shift',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'day', child: Text('Jour')),
                  DropdownMenuItem(value: 'night', child: Text('Nuit')),
                  DropdownMenuItem(value: 'full', child: Text('Complet')),
                ],
                onChanged: (value) => setState(() => _shiftType = value!),
              ),
              const SizedBox(height: 16),

              // Days of week
              const Text('Jours de la semaine'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildDayChip(1, 'Lun'),
                  _buildDayChip(2, 'Mar'),
                  _buildDayChip(3, 'Mer'),
                  _buildDayChip(4, 'Jeu'),
                  _buildDayChip(5, 'Ven'),
                  _buildDayChip(6, 'Sam'),
                  _buildDayChip(7, 'Dim'),
                ],
              ),
              const SizedBox(height: 16),

              // Start time
              ListTile(
                title: const Text('Heure de début'),
                trailing: Text(
                  _startTime != null ? _startTime!.format(context) : 'Sélectionner',
                ),
                onTap: () => _selectTime(context, true),
              ),
              const SizedBox(height: 8),

              // End time
              ListTile(
                title: const Text('Heure de fin'),
                trailing: Text(
                  _endTime != null ? _endTime!.format(context) : 'Sélectionner',
                ),
                onTap: () => _selectTime(context, false),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createRotation,
          child: _isLoading
              ? const CircularProgressIndicator()
              : const Text('Créer'),
        ),
      ],
    );
  }

  Widget _buildDayChip(int day, String label) {
    final isSelected = _selectedDays.contains(day);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedDays.add(day);
          } else {
            _selectedDays.remove(day);
          }
        });
      },
    );
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _createRotation() async {
    if (_startTime == null || _endTime == null) {
      _showError('Veuillez sélectionner les heures');
      return;
    }

    if (_selectedDays.isEmpty) {
      _showError('Veuillez sélectionner au moins un jour');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final rotationService = ref.read(driverRotationServiceProvider);
      await rotationService.createRotation(
        taxiId: widget.taxiId,
        driverId: '', // Will be set from current user
        shiftType: _shiftType,
        daysOfWeek: _selectedDays,
        startTime: '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}',
        endTime: '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}',
      );

      setState(() => _isLoading = false);
      widget.onCreated();
      if (mounted) {
        Navigator.pop(context);
        _showSuccess('Rotation créée avec succès');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Erreur création: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.dangerSurface),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.success),
    );
  }
}
