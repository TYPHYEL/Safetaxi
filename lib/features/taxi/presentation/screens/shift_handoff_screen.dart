// lib/features/taxi/presentation/screens/shift_handoff_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:safetaxi_cameroun/core/services/driver_rotation_service.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';
import 'package:geolocator/geolocator.dart';

class ShiftHandoffScreen extends ConsumerStatefulWidget {
  final String taxiId;
  final String incomingDriverId;
  final String incomingDriverName;

  const ShiftHandoffScreen({
    super.key,
    required this.taxiId,
    required this.incomingDriverId,
    required this.incomingDriverName,
  });

  @override
  ConsumerState<ShiftHandoffScreen> createState() => _ShiftHandoffScreenState();
}

class _ShiftHandoffScreenState extends ConsumerState<ShiftHandoffScreen> {
  DriverRotationService get _rotationService => ref.read(driverRotationServiceProvider);
  final _imagePicker = ImagePicker();
  
  File? _outgoingSelfie;
  File? _incomingSelfie;
  String? _handoffId;
  bool _isVerifying = false;
  bool _isCompleted = false;
  Map<String, dynamic>? _verificationResult;
  
  final _odometerController = TextEditingController();
  final _fuelLevelController = TextEditingController();
  final _notesController = TextEditingController();
  
  @override
  void dispose() {
    _odometerController.dispose();
    _fuelLevelController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _createHandoff() async {
    try {
      final result = await _rotationService.createHandoff(
        taxiId: widget.taxiId,
        incomingDriverId: widget.incomingDriverId,
      );
      setState(() {
        _handoffId = result['id'].toString();
      });
    } catch (e) {
      _showError('Erreur création passation: $e');
    }
  }

  Future<void> _pickOutgoingSelfie() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      preferredCameraDevice: CameraDevice.front,
    );
    if (image != null) {
      setState(() => _outgoingSelfie = File(image.path));
    }
  }

  Future<void> _pickIncomingSelfie() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      preferredCameraDevice: CameraDevice.front,
    );
    if (image != null) {
      setState(() => _incomingSelfie = File(image.path));
    }
  }

  Future<void> _verifyBiometric() async {
    if (_outgoingSelfie == null || _incomingSelfie == null) {
      _showError('Les deux selfies sont requis');
      return;
    }

    if (_handoffId == null) {
      await _createHandoff();
    }

    setState(() => _isVerifying = true);

    try {
      final result = await _rotationService.verifyHandoffBiometric(
        handoffId: _handoffId!,
        outgoingSelfie: _outgoingSelfie!,
        incomingSelfie: _incomingSelfie!,
      );

      setState(() {
        _verificationResult = result;
        _isVerifying = false;
      });

      if (result['verified'] == true) {
        _showSuccess('Vérification biométrique réussie!');
      } else {
        _showError('Vérification échouée: ${result['reason']}');
      }
    } catch (e) {
      setState(() => _isVerifying = false);
      _showError('Erreur vérification: $e');
    }
  }

  Future<void> _completeHandoff() async {
    if (_verificationResult == null || _verificationResult!['verified'] != true) {
      _showError('Vérification biométrique requise');
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      
      await _rotationService.completeHandoff(
        handoffId: _handoffId!,
        lat: position.latitude,
        lng: position.longitude,
        odometer: double.tryParse(_odometerController.text),
        fuelLevel: double.tryParse(_fuelLevelController.text),
        notes: _notesController.text,
      );

      setState(() => _isCompleted = true);
      _showSuccess('Passation complétée avec succès!');
      
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    } catch (e) {
      _showError('Erreur complétion: $e');
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
        title: const Text('Passation de Service'),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Incoming driver info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chauffeur entrant',
                      style: AppTextStyles.headline6,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.incomingDriverName,
                      style: AppTextStyles.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Selfie section
            const Text(
              'Vérification Biométrique',
              style: AppTextStyles.headline6,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildSelfieCard(
                    title: 'Selfie Sortant',
                    image: _outgoingSelfie,
                    onTap: _pickOutgoingSelfie,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSelfieCard(
                    title: 'Selfie Entrant',
                    image: _incomingSelfie,
                    onTap: _pickIncomingSelfie,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Verify button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isVerifying ? null : _verifyBiometric,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isVerifying
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Vérifier Biométrie'),
              ),
            ),

            // Verification result
            if (_verificationResult != null) ...[
              const SizedBox(height: 16),
              Card(
                color: _verificationResult!['verified'] == true
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.dangerSurface.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        _verificationResult!['verified'] == true
                            ? '✓ Vérification Réussie'
                            : '✗ Vérification Échouée',
                        style: AppTextStyles.headline6.copyWith(
                          color: _verificationResult!['verified'] == true
                              ? AppColors.success
                              : AppColors.dangerSurface,
                        ),
                      ),
                      if (_verificationResult!['confidence'] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Confiance: ${(_verificationResult!['confidence'] * 100).toStringAsFixed(1)}%',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                      if (_verificationResult!['reason'] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _verificationResult!['reason'],
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            // Handoff details (only show after verification)
            if (_verificationResult != null && _verificationResult!['verified'] == true) ...[
              const SizedBox(height: 24),
              const Text(
                'Détails de Passation',
                style: AppTextStyles.headline6,
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _odometerController,
                decoration: const InputDecoration(
                  labelText: 'Compteur kilométrique (km)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _fuelLevelController,
                decoration: const InputDecoration(
                  labelText: 'Niveau de carburant (%)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (état du véhicule)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Complete button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isCompleted ? null : _completeHandoff,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isCompleted
                      ? const Text('Passation Complétée ✓')
                      : const Text('Compléter la Passation'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelfieCard({
    required String title,
    required File? image,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            color: image == null ? Colors.grey[200] : null,
          ),
          child: image == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.camera_alt, size: 48, color: Colors.grey),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : Stack(
                  children: [
                    Image.file(
                      image,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      right: 8,
                      child: Container(
                        color: Colors.black54,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          title,
                          style: AppTextStyles.bodySmall.copyWith(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
