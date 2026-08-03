// lib/features/auth/presentation/screens/register_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:safetaxi_cameroun/core/constants/app_constants.dart';
import 'package:safetaxi_cameroun/features/auth/data/models/user_model.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/providers/auth_provider.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  final String role; // 'passenger' | 'driver' | 'owner'
  const RegisterScreen({super.key, required this.role});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();
  String _gender = 'M';
  bool _obscure = true;
  bool _isLoading = false;
  bool _acceptTerms = false;
  File? _licensePhoto;
  File? _vehiclePhoto;
  File? _cniPhoto;
  Map<String, dynamic>? _cniValidation;
  Map<String, dynamic>? _licenseValidation;
  Map<String, dynamic>? _vehicleValidation;
  Map<String, dynamic>? _documentComparison;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _birthDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLicensePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (pickedFile != null && mounted) {
      setState(() => _licensePhoto = File(pickedFile.path));
      // Validation OCR désactivée temporairement pour éviter les erreurs
      // await _validateLicense();
      // if (_cniPhoto != null) {
      //   await _compareDocuments();
      // }
    }
  }

  Future<void> _pickVehiclePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (pickedFile != null && mounted) {
      setState(() => _vehiclePhoto = File(pickedFile.path));
      // Validation OCR désactivée temporairement pour éviter les erreurs
      // await _validateVehicle();
    }
  }

  Future<void> _pickCniPhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (pickedFile != null && mounted) {
      setState(() => _cniPhoto = File(pickedFile.path));
      // Validation OCR désactivée temporairement pour éviter les erreurs
      // await _validateCni();
      // if (_licensePhoto != null) {
      //   await _compareDocuments();
      // }
    }
  }

  // ignore: unused_element
  Future<void> _validateCni() async {
    if (_cniPhoto == null) return;

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.validateCni(_cniPhoto!);
      if (mounted && response.data != null) {
        setState(() => _cniValidation = response.data as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('CNI validation error: $e');
    }
  }

  // ignore: unused_element
  Future<void> _validateLicense() async {
    if (_licensePhoto == null) return;

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.validateLicense(_licensePhoto!);
      if (mounted && response.data != null) {
        setState(
            () => _licenseValidation = response.data as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('License validation error: $e');
    }
  }

  // ignore: unused_element
  Future<void> _validateVehicle() async {
    if (_vehiclePhoto == null) return;

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.validateVehicle(_vehiclePhoto!);
      if (mounted && response.data != null) {
        setState(
            () => _vehicleValidation = response.data as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('Vehicle validation error: $e');
    }
  }

  // ignore: unused_element
  Future<void> _compareDocuments() async {
    if (_cniPhoto == null || _licensePhoto == null) return;

    try {
      final apiClient = ref.read(apiClientProvider);
      final response =
          await apiClient.compareDocuments(_cniPhoto!, _licensePhoto!);
      if (mounted && response.data != null) {
        setState(
            () => _documentComparison = response.data as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('Document comparison error: $e');
    }
  }

  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
    );
    if (picked != null && mounted) {
      setState(() =>
          _birthDateCtrl.text = picked.toLocal().toString().split(' ')[0]);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validation des photos pour les chauffeurs
    if (widget.role == 'driver') {
      if (_licensePhoto == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Veuillez ajouter une photo de votre permis.')),
        );
        return;
      }
      if (_vehiclePhoto == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Veuillez ajouter une photo de votre véhicule avec la plaque visible.')),
        );
        return;
      }
      if (_cniPhoto == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Veuillez ajouter une photo de votre CNI.')),
        );
        return;
      }
      if (_birthDateCtrl.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Veuillez entrer votre date de naissance.')),
        );
        return;
      }
    }

    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez accepter les conditions.')),
      );
      return;
    }
    setState(() => _isLoading = true);

    final fullName = _nameCtrl.text.trim();
    final nameParts = fullName.split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts.first : fullName;
    final lastName = nameParts.length > 1 ? nameParts.skip(1).join(' ') : '';

    // register() lance Firebase verifyPhoneNumber — le résultat arrive
    // via le state (isOtpSent) capturé par ref.listen dans build(), pas ici.
    await ref.read(authProvider.notifier).register(
          RegisterRequest(
            phone: _phoneCtrl.text.trim(),
            firstName: firstName,
            lastName: lastName,
            role: widget.role,
            email:
                _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
            licensePhoto: widget.role == 'driver' ? _licensePhoto : null,
            vehiclePhoto: widget.role == 'driver' ? _vehiclePhoto : null,
            cniPhoto: widget.role == 'driver' ? _cniPhoto : null,
            birthDate:
                widget.role == 'driver' ? _birthDateCtrl.text.trim() : null,
            gender: widget.role == 'driver' ? _gender : null,
          ),
        );

    // Ne pas lire le state ici : codeSent arrive en callback asynchrone
    // après que verifyPhoneNumber retourne. ref.listen s'en charge.
    if (mounted) setState(() => _isLoading = false);
  }

  Widget _buildValidationResult(
      Map<String, dynamic> validation, String docType) {
    final parsedInfo = validation['parsed_info'] as Map<String, dynamic>?;
    final confidence = parsedInfo?['confidence'] as double? ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: confidence > 0.5
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: confidence > 0.5 ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                confidence > 0.5
                    ? Icons.check_circle_rounded
                    : Icons.info_rounded,
                color: confidence > 0.5 ? Colors.green : Colors.orange,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Infos extraites ($docType)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: confidence > 0.5 ? Colors.green : Colors.orange,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (parsedInfo != null) ...[
            if (parsedInfo['name'] != null &&
                parsedInfo['name'].toString().isNotEmpty)
              _buildInfoRow('Nom:', parsedInfo['name'].toString()),
            if (parsedInfo['first_name'] != null &&
                parsedInfo['first_name'].toString().isNotEmpty)
              _buildInfoRow('Prénom:', parsedInfo['first_name'].toString()),
            if (parsedInfo['birth_date'] != null &&
                parsedInfo['birth_date'].toString().isNotEmpty)
              _buildInfoRow(
                  'Date naissance:', parsedInfo['birth_date'].toString()),
            if (parsedInfo['sex'] != null &&
                parsedInfo['sex'].toString().isNotEmpty)
              _buildInfoRow('Sexe:', parsedInfo['sex'].toString()),
          ] else
            Text(
              'Aucune information extraite',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVehicleValidationResult(Map<String, dynamic> validation) {
    final validationData = validation['validation'] as Map<String, dynamic>?;
    final plateDetected = validationData?['plate_detected'] as bool? ?? false;
    final plateNumber = validationData?['plate_number'] as String?;
    final message = validationData?['message'] as String?;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: plateDetected
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: plateDetected ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                plateDetected ? Icons.check_circle_rounded : Icons.info_rounded,
                color: plateDetected ? Colors.green : Colors.orange,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Validation véhicule',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: plateDetected ? Colors.green : Colors.orange,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (plateNumber != null)
            _buildInfoRow('Plaque détectée:', plateNumber),
          if (message != null)
            Text(
              message,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentComparisonResult(Map<String, dynamic> comparison) {
    final comparisonData = comparison['comparison'] as Map<String, dynamic>?;
    final overallMatch = comparisonData?['overall_match'] as bool? ?? false;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: overallMatch
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: overallMatch ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                overallMatch ? Icons.check_circle_rounded : Icons.error_rounded,
                color: overallMatch ? Colors.green : Colors.red,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                overallMatch
                    ? 'Documents correspondants'
                    : 'Documents non correspondants',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: overallMatch ? Colors.green : Colors.red,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (comparisonData != null) ...[
            _buildMatchRow('Nom:', comparisonData['name_match']),
            _buildMatchRow('Prénom:', comparisonData['first_name_match']),
            _buildMatchRow(
                'Date naissance:', comparisonData['birth_date_match']),
            _buildMatchRow('Sexe:', comparisonData['sex_match']),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchRow(String label, dynamic match) {
    final isMatch = match as bool? ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            isMatch ? Icons.check_rounded : Icons.close_rounded,
            color: isMatch ? Colors.green : Colors.red,
            size: 14,
          ),
        ],
      ),
    );
  }

  void _onAuthStateChanged(AuthState? prev, AuthState next) {
    if (!mounted) return;

    // Erreur — afficher le SnackBar
    if (next.status == AuthStatus.error && next.error != null) {
      if (mounted) setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(next.error!),
          backgroundColor: AppColors.dangerSurface,
        ),
      );
      return;
    }

    // OTP envoyé — naviguer vers l'écran de vérification
    if (next.isOtpSent &&
        next.pendingPhone != null &&
        !(prev?.isOtpSent ?? false)) {
      if (mounted) setState(() => _isLoading = false);
      context.go(
        '${AppRoutes.otpVerify}?phone=${Uri.encodeComponent(next.pendingPhone!)}',
      );
    }

    // Authentifié directement (auto-verification Android)
    if (next.isAuthenticated && !(prev?.isAuthenticated ?? false)) {
      if (mounted) setState(() => _isLoading = false);
      // Pour les chauffeurs, rediriger vers les documents après inscription
      if (widget.role == 'driver' && mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) context.push(AppRoutes.driverDocuments);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.role;

    // Écouter les changements de state pour naviguer au bon moment
    ref.listen<AuthState>(authProvider, _onAuthStateChanged);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          role == 'driver'
              ? 'Inscription Chauffeur'
              : role == 'owner'
                  ? 'Inscription Propriétaire'
                  : 'Inscription Passager',
          style: AppTextStyles.titleMedium,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Role banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        role == 'driver'
                            ? Icons.drive_eta_rounded
                            : role == 'owner'
                                ? Icons.business_rounded
                                : Icons.person_rounded,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          role == 'driver'
                              ? 'Vous êtes un chauffeur. Des documents seront demandés après.'
                              : role == 'owner'
                                  ? 'Vous êtes un propriétaire de taxis.'
                                  : 'Vous êtes un passager.',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Nom complet
                _label('Nom complet'),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: _input('Votre nom complet', Icons.person_rounded),
                  validator: (v) => (v == null || v.trim().length < 3)
                      ? 'Nom trop court (min. 3 caractères)'
                      : null,
                ),
                const SizedBox(height: 16),

                // Téléphone
                _label('Téléphone'),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration:
                      _input('+237 6XX XX XX XX', Icons.phone_android_rounded),
                  validator: (v) {
                    if (v == null || v.trim().length < 9) {
                      return 'Numéro invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Email (optionnel)
                _label('Email (optionnel)'),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration:
                      _input('vous@exemple.com', Icons.alternate_email_rounded),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    if (!v.contains('@') || !v.contains('.')) {
                      return 'Email invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Genre
                _label('Genre'),
                Row(
                  children: [
                    _genderChip('Homme', 'M'),
                    const SizedBox(width: 8),
                    _genderChip('Femme', 'F'),
                  ],
                ),
                const SizedBox(height: 16),

                // Mot de passe
                _label('Mot de passe'),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  decoration:
                      _input('Min. 6 caractères', Icons.lock_outline_rounded)
                          .copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: AppColors.textMuted),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 6) {
                      return 'Mot de passe trop court (min. 6)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Champs spécifiques pour les chauffeurs
                if (widget.role == 'driver') ...[
                  _label('Date de naissance'),
                  TextFormField(
                    controller: _birthDateCtrl,
                    readOnly: true,
                    decoration:
                        _input('JJ/MM/AAAA', Icons.calendar_today_rounded)
                            .copyWith(
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today_rounded),
                        onPressed: _selectBirthDate,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Date de naissance requise';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _label('Photo du permis'),
                  InkWell(
                    onTap: _pickLicensePhoto,
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _licensePhoto == null
                              ? AppColors.textMuted.withValues(alpha: 0.3)
                              : AppColors.primary,
                          width: 2,
                        ),
                      ),
                      child: _licensePhoto == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.camera_alt_rounded,
                                  size: 40,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Prendre une photo du permis',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                _licensePhoto!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            ),
                    ),
                  ),
                  if (_licenseValidation != null) ...[
                    const SizedBox(height: 8),
                    _buildValidationResult(_licenseValidation!, 'Permis'),
                  ],
                  const SizedBox(height: 16),

                  _label('Photo du véhicule avec plaque'),
                  InkWell(
                    onTap: _pickVehiclePhoto,
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _vehiclePhoto == null
                              ? AppColors.textMuted.withValues(alpha: 0.3)
                              : AppColors.primary,
                          width: 2,
                        ),
                      ),
                      child: _vehiclePhoto == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.directions_car_rounded,
                                  size: 40,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Prendre une photo (plaque visible)',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                _vehiclePhoto!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            ),
                    ),
                  ),
                  if (_vehicleValidation != null) ...[
                    const SizedBox(height: 8),
                    _buildVehicleValidationResult(_vehicleValidation!),
                  ],
                  const SizedBox(height: 16),

                  _label('Photo de la CNI'),
                  InkWell(
                    onTap: _pickCniPhoto,
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _cniPhoto == null
                              ? AppColors.textMuted.withValues(alpha: 0.3)
                              : AppColors.primary,
                          width: 2,
                        ),
                      ),
                      child: _cniPhoto == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.badge_rounded,
                                  size: 40,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Prendre une photo de la CNI',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                _cniPhoto!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            ),
                    ),
                  ),
                  if (_cniValidation != null) ...[
                    const SizedBox(height: 8),
                    _buildValidationResult(_cniValidation!, 'CNI'),
                  ],
                  const SizedBox(height: 16),

                  // Document comparison result
                  if (_documentComparison != null) ...[
                    _buildDocumentComparisonResult(_documentComparison!),
                    const SizedBox(height: 16),
                  ],
                ],

                // Conditions
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _acceptTerms,
                      activeColor: AppColors.primary,
                      onChanged: (v) =>
                          setState(() => _acceptTerms = v ?? false),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: RichText(
                          text: TextSpan(
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textMuted),
                            children: [
                              const TextSpan(text: 'J\'accepte les '),
                              TextSpan(
                                text: 'conditions d\'utilisation',
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.primary),
                              ),
                              const TextSpan(text: ' et la '),
                              TextSpan(
                                text: 'politique de confidentialité',
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.primary),
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Submit
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text('S\'inscrire',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 16),

                // Login link
                Center(
                  child: GestureDetector(
                    onTap: () => context.go(AppRoutes.login),
                    child: RichText(
                      text: TextSpan(
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textMuted),
                        children: [
                          const TextSpan(text: 'Déjà un compte ? '),
                          TextSpan(
                            text: 'Se connecter',
                            style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: AppTextStyles.labelMedium),
      );

  Widget _genderChip(String label, String code) {
    final selected = _gender == code;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _gender = code),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.border),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: selected ? AppColors.primary : AppColors.textMuted,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _input(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle:
            AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
        prefixIcon: Icon(icon, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      );
}
