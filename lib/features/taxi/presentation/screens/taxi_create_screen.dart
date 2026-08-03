// lib/features/taxi/presentation/screens/taxi_create_screen.dart
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

  String? _photoUrl;
  bool _isLoading = false;

  @override
  void dispose() {
    _plateCtrl.dispose();
    _licenseCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _colorCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      // TODO: Upload to backend and get URL
      setState(() => _photoUrl = image.path);
    }
  }

  Future<void> _createTaxi() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiClientProvider);
      await api.createTaxi({
        'plate_number': _plateCtrl.text.trim().toUpperCase(),
        'license_number': _licenseCtrl.text.trim(),
        'brand': _brandCtrl.text.trim(),
        'model': _modelCtrl.text.trim(),
        'color': _colorCtrl.text.trim(),
        'capacity': 4,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Taxi créé avec succès')),
        );
        context.pop();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
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
                          child: Image.network(_photoUrl!, fit: BoxFit.cover),
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

              // Plate
              const _FieldLabel('Plaque d\'immatriculation'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _plateCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'Ex: LT4521A',
                  prefixIcon: Icon(Icons.badge_rounded),
                ),
                validator: (v) => (v?.isEmpty ?? true) ? 'Champ requis' : null,
              ),
              const SizedBox(height: 16),

              // License
              const _FieldLabel('Numéro de licence'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _licenseCtrl,
                decoration: const InputDecoration(
                  hintText: 'Ex: LIC-2024-001',
                  prefixIcon: Icon(Icons.card_membership_rounded),
                ),
                validator: (v) => (v?.isEmpty ?? true) ? 'Champ requis' : null,
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
                validator: (v) => (v?.isEmpty ?? true) ? 'Champ requis' : null,
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
                validator: (v) => (v?.isEmpty ?? true) ? 'Champ requis' : null,
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
                validator: (v) => (v?.isEmpty ?? true) ? 'Champ requis' : null,
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
