// lib/features/trajet/presentation/screens/deposit_request_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:safetaxi_cameroun/core/constants/app_constants.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/providers/auth_provider.dart';
import 'package:safetaxi_cameroun/features/trajet/data/models/deposit_model.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';

class DepositRequestScreen extends ConsumerStatefulWidget {
  const DepositRequestScreen({super.key});

  @override
  ConsumerState<DepositRequestScreen> createState() => _DepositRequestScreenState();
}

class _DepositRequestScreenState extends ConsumerState<DepositRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isCalculating = false;
  
  // Location data
  String _pickupLocation = '';
  double _pickupLat = 0.0;
  double _pickupLng = 0.0;
  String _dropoffLocation = '';
  double _dropoffLat = 0.0;
  double _dropoffLng = 0.0;
  
  // Fare calculation result
  FareCalculationResponse? _fareCalculation;
  
  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _pickupLat = position.latitude;
        _pickupLng = position.longitude;
        _pickupLocation = 'Ma position actuelle';
      });
    } catch (e) {
      // Use default location (Yaoundé)
      setState(() {
        _pickupLat = AppConstants.defaultLat;
        _pickupLng = AppConstants.defaultLng;
        _pickupLocation = 'Yaoundé Centre';
      });
    }
  }

  Future<void> _calculateFare() async {
    if (_pickupLat == 0 || _pickupLng == 0 || _dropoffLat == 0 || _dropoffLng == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner les points de départ et d\'arrivée')),
      );
      return;
    }

    setState(() => _isCalculating = true);

    try {
      final apiClient = ref.read(apiClientProvider);
      final request = FareCalculationRequest(
        pickupLat: _pickupLat,
        pickupLng: _pickupLng,
        dropoffLat: _dropoffLat,
        dropoffLng: _dropoffLng,
      );

      final response = await apiClient.calculateDepositFare(request.toJson());
      _fareCalculation = FareCalculationResponse.fromJson(response.data as Map<String, dynamic>);

      setState(() => _isCalculating = false);
    } catch (e) {
      setState(() => _isCalculating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de calcul: ${e.toString()}')),
      );
    }
  }

  Future<void> _createDeposit() async {
    if (_fareCalculation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez d\'abord calculer le prix')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiClient = ref.read(apiClientProvider);
      final request = DepositRequest(
        pickupLocation: _pickupLocation,
        pickupLat: _pickupLat,
        pickupLng: _pickupLng,
        dropoffLocation: _dropoffLocation,
        dropoffLat: _dropoffLat,
        dropoffLng: _dropoffLng,
        distanceKm: _fareCalculation!.distanceKm,
        fare: _fareCalculation!.fare,
        isNight: _fareCalculation!.isNight,
      );

      final response = await apiClient.createDeposit(request.toJson());
      final deposit = Deposit.fromJson(response.data as Map<String, dynamic>);

      setState(() => _isLoading = false);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => _DepositCreatedDialog(deposit: deposit),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de création: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Dépôt - Course privée'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Course privée pour un seul passager. Tarif minimum: 3000 FCFA (jour) / 4000 FCFA (nuit)',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Pickup location
              const Text('Point de départ', style: AppTextStyles.titleLarge),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.my_location_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _pickupLocation.isEmpty ? 'Détection de votre position...' : _pickupLocation,
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                    if (_pickupLat != 0 && _pickupLng != 0)
                      Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Dropoff location
              const Text('Point d\'arrivée', style: AppTextStyles.titleLarge),
              const SizedBox(height: 8),
              TextFormField(
                decoration: InputDecoration(
                  hintText: 'Entrez l\'adresse de destination',
                  prefixIcon: Icon(Icons.location_on_rounded, color: AppColors.primary),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
                onChanged: (value) {
                  setState(() => _dropoffLocation = value);
                  // For demo, use a fixed location near Yaoundé
                  _dropoffLat = 3.8520;
                  _dropoffLng = 11.5065;
                },
              ),
              const SizedBox(height: 24),

              // Calculate fare button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isCalculating ? null : _calculateFare,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isCalculating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Calculer le prix'),
                ),
              ),

              // Fare calculation result
              if (_fareCalculation != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 24),
                          const SizedBox(width: 12),
                          const Text('Estimation du prix', style: AppTextStyles.titleLarge),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _FareRow(
                        label: 'Distance',
                        value: '${_fareCalculation!.distanceKm.toStringAsFixed(1)} km',
                      ),
                      const SizedBox(height: 12),
                      _FareRow(
                        label: 'Tarif',
                        value: _fareCalculation!.isNight ? 'Nuit' : 'Jour',
                      ),
                      const SizedBox(height: 12),
                      _FareRow(
                        label: 'Tarif minimum',
                        value: '${_fareCalculation!.minFare.toInt()} FCFA',
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Prix estimé', style: AppTextStyles.titleLarge),
                          Text(
                            '${_fareCalculation!.fare.toInt()} FCFA',
                            style: AppTextStyles.headlineMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Create deposit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createDeposit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Confirmer la demande',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FareRow extends StatelessWidget {
  final String label;
  final String value;

  const _FareRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
        Text(value, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _DepositCreatedDialog extends StatelessWidget {
  final Deposit deposit;

  const _DepositCreatedDialog({required this.deposit});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 48),
          ),
          const SizedBox(height: 16),
          const Text('Demande envoyée', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Votre demande de dépôt a été envoyée. Un chauffeur vous sera assigné prochainement.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (deposit.status == 'offered') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Statut: ${deposit.statusText}',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary),
              ),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.pop(),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
