// lib/features/auth/presentation/screens/driver_verification_screen.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safetaxi_cameroun/core/services/biometric_service.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/providers/auth_provider.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';

class DriverVerificationScreen extends ConsumerStatefulWidget {
  const DriverVerificationScreen({super.key});

  @override
  ConsumerState<DriverVerificationScreen> createState() =>
      _DriverVerificationScreenState();
}

class _DriverVerificationScreenState
    extends ConsumerState<DriverVerificationScreen> {
  BiometricService get _biometricService =>
      ref.read(biometricServiceProvider);
  File? _selfieImage;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _qualityResult;
  bool _isUploading = false;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _captureSelfie() async {
    setState(() => _isAnalyzing = true);

    final image = await _biometricService.captureSelfie();
    if (image != null) {
      final quality = await _biometricService.analyzeSelfieQuality(image);
      setState(() {
        _selfieImage = image;
        _qualityResult = quality;
        _isAnalyzing = false;
      });
    } else {
      setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _uploadSelfie() async {
    if (_selfieImage == null || (_qualityResult?['valid'] != true)) return;

    setState(() => _isUploading = true);

    try {
      final api = ref.read(apiClientProvider);
      final formData = FormData.fromMap({
        'selfie': await MultipartFile.fromFile(
          _selfieImage!.path,
          filename: 'selfie.jpg',
        ),
      });

      await api.createBiometricRequest(formData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selfie envoyé avec succès')),
        );
        context.pop();
      }
    } catch (e) {
      setState(() => _isUploading = false);
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
        title: const Text('Vérification biométrique'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInstructions(),
            const SizedBox(height: 24),
            _buildSelfiePreview(),
            const SizedBox(height: 24),
            _buildQualityIndicator(),
            const SizedBox(height: 32),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Instructions',
                  style: AppTextStyles.titleMedium
                      .copyWith(color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 12),
          _instructionItem('Regardez directement la caméra'),
          _instructionItem('Assurez-vous d\'avoir un bon éclairage'),
          _instructionItem('Gardez les yeux ouverts'),
          _instructionItem('Enlevez lunettes et casquette si possible'),
        ],
      ),
    );
  }

  Widget _instructionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppTextStyles.bodySmall)),
        ],
      ),
    );
  }

  Widget _buildSelfiePreview() {
    return GestureDetector(
      onTap: _isAnalyzing ? null : _captureSelfie,
      child: Container(
        height: 300,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _selfieImage != null ? AppColors.primary : AppColors.border,
            width: _selfieImage != null ? 2 : 1,
          ),
        ),
        child: _isAnalyzing
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Analyse en cours...'),
                  ],
                ),
              )
            : _selfieImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(_selfieImage!, fit: BoxFit.cover),
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt_rounded,
                          size: 64, color: AppColors.textMuted),
                      SizedBox(height: 16),
                      Text('Appuyez pour prendre un selfie',
                          style: AppTextStyles.bodySmall),
                      SizedBox(height: 8),
                      Text('Caméra frontale', style: AppTextStyles.caption),
                    ],
                  ),
      ),
    );
  }

  Widget _buildQualityIndicator() {
    if (_qualityResult == null) return const SizedBox.shrink();

    final isValid = _qualityResult!['valid'] as bool;
    final reason = _qualityResult!['reason'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isValid
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isValid
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle_rounded : Icons.warning_rounded,
            color: isValid ? AppColors.primary : AppColors.warning,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isValid
                      ? 'Photo de bonne qualité'
                      : 'Photo de mauvaise qualité',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: isValid ? AppColors.primary : AppColors.warning,
                  ),
                ),
                if (reason != null) ...[
                  const SizedBox(height: 4),
                  Text(reason, style: AppTextStyles.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final canSubmit =
        _selfieImage != null && (_qualityResult?['valid'] == true);

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: canSubmit && !_isUploading ? _uploadSelfie : null,
            icon: _isUploading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : const Icon(Icons.check_rounded),
            label:
                Text(_isUploading ? 'Envoi en cours...' : 'Envoyer le selfie'),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  canSubmit ? AppColors.primary : AppColors.textMuted,
            ),
          ),
        ),
        if (_selfieImage != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isUploading ? null : _captureSelfie,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reprendre la photo'),
          ),
        ],
      ],
    );
  }
}
