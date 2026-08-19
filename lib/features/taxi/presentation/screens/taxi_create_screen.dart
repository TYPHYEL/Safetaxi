// lib/features/taxi/presentation/screens/taxi_create_screen.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/providers/auth_provider.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';

class TaxiCreateScreen extends ConsumerStatefulWidget {
  const TaxiCreateScreen({super.key});

  @override
  ConsumerState<TaxiCreateScreen> createState() => _TaxiCreateScreenState();
}

class _TaxiCreateScreenState extends ConsumerState<TaxiCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _plateCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController(text: '4');

  dynamic _photoFile;
  String? _photoUrl;
  dynamic _registrationPhotoFile;
  String? _registrationPhotoUrl;
  String? _registrationValidationMessage;
  bool _isRegistrationValid = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _plateCtrl.dispose();
    _licenseCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _colorCtrl.dispose();
    _yearCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (image != null) {
      setState(() {
        _photoFile = image;
        _photoUrl = image.path;
      });
    }
  }

  Future<void> _pickRegistrationPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (image == null) return;

    setState(() {
      _registrationPhotoFile = image;
      _registrationPhotoUrl = image.path;
      _registrationValidationMessage = null;
      _isRegistrationValid = false;
    });
  }

  Future<bool> _validateRegistration(String plate) async {
    if (_registrationPhotoFile == null) {
      setState(() {
        _registrationValidationMessage = 'Scan de la carte grise requis';
        _isRegistrationValid = false;
      });
      return false;
    }

    try {
      final api = ref.read(apiClientProvider);
      final response =
          await api.validateRegistration(_registrationPhotoFile!, plate);
      final data = response.data;
      final plateMatch = data['plate_match'] == true;
      setState(() {
        _isRegistrationValid = plateMatch;
        _registrationValidationMessage = data['message'] as String? ??
            (plateMatch ? 'Carte grise validée' : 'Plaque incohérente');
      });
      return plateMatch;
    } catch (e) {
      setState(() {
        _registrationValidationMessage = 'Impossible de valider la carte grise';
        _isRegistrationValid = false;
      });
      return false;
    }
  }

  Future<void> _createTaxi() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiClientProvider);
      final plate =
          _plateCtrl.text.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
      final payload = <String, dynamic>{
        'plate_number': plate,
        'brand': _brandCtrl.text.trim(),
        'model': _modelCtrl.text.trim(),
        'color': _colorCtrl.text.trim(),
        'capacity': int.tryParse(_capacityCtrl.text.trim()) ?? 4,
      };
      final license = _licenseCtrl.text.trim();
      if (license.isNotEmpty) {
        payload['license_number'] = license;
      }

      if (!await _validateRegistration(payload['plate_number'] as String)) {
        setState(() => _isLoading = false);
        return;
      }

      await api.createTaxi(payload, photo: _photoFile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Taxi créé avec succès')),
        );
        context.pop();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        final message = e is DioException
            ? e.response?.data.toString() ?? e.message
            : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $message')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Ajouter un taxi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo upload
              GestureDetector(
                onTap: _pickPhoto,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: _photoUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child:
                              Image.file(File(_photoUrl!), fit: BoxFit.cover),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt_rounded,
                                size: 40, color: AppColors.textMuted),
                            SizedBox(height: 8),
                            Text('Ajouter une photo',
                                style: AppTextStyles.bodySmall),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // Registration scan
              const _FieldLabel('Scan de la carte grise'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickRegistrationPhoto,
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: _registrationPhotoUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(File(_registrationPhotoUrl!),
                              fit: BoxFit.cover),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.description_rounded,
                                size: 40, color: AppColors.textMuted),
                            SizedBox(height: 8),
                            Text('Scanner la carte grise',
                                style: AppTextStyles.bodySmall),
                          ],
                        ),
                ),
              ),
              if (_registrationValidationMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _registrationValidationMessage!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: _isRegistrationValid
                        ? AppColors.primary
                        : AppColors.danger,
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Plate
              const _FieldLabel('Plaque d\'immatriculation'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _plateCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText:
                      'Entrez la plaque telle qu\'elle apparaît sur le véhicule et les documents',
                  prefixIcon: Icon(Icons.badge_rounded),
                ),
                validator: (v) {
                  final value = v?.trim().toUpperCase() ?? '';
                  if (value.isEmpty) {
                    return 'Champ requis';
                  }
                  if (value.length < 3) {
                    return 'Entrez une plaque valide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // License
              const _FieldLabel('Numéro de licence (optionnel)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _licenseCtrl,
                decoration: const InputDecoration(
                  hintText: 'Ex: LIC-2024-001',
                  prefixIcon: Icon(Icons.card_membership_rounded),
                ),
                validator: (_) => null,
              ),
              const SizedBox(height: 16),

              // Brand
              const _FieldLabel('Marque'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _brandCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Ex: Toyota',
                  prefixIcon: Icon(Icons.directions_car_rounded),
                ),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Champ requis' : null,
              ),
              const SizedBox(height: 16),

              // Model
              const _FieldLabel('Modèle'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _modelCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Ex: Corolla',
                  prefixIcon: Icon(Icons.car_repair_rounded),
                ),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Champ requis' : null,
              ),
              const SizedBox(height: 16),

              // Color
              const _FieldLabel('Couleur'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _colorCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Ex: Gris métallisé',
                  prefixIcon: Icon(Icons.palette_rounded),
                ),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Champ requis' : null,
              ),
              const SizedBox(height: 16),

              const _FieldLabel('Capacité'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _capacityCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Ex: 4',
                  prefixIcon: Icon(Icons.event_seat_rounded),
                ),
                validator: (v) {
                  final value = int.tryParse(v?.trim() ?? '');
                  if (value == null || value <= 0) {
                    return 'Capacité valide requise';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Year
              const _FieldLabel('Année (optionnel)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _yearCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Ex: 2020',
                  prefixIcon: Icon(Icons.calendar_today_rounded),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final year = int.tryParse(v);
                  if (year == null ||
                      year < 1990 ||
                      year > DateTime.now().year) {
                    return 'Année invalide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Submit
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createTaxi,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Créer le taxi'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: AppTextStyles.labelLarge,
      );
}
