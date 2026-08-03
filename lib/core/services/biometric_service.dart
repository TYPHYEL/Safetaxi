// lib/core/services/biometric_service.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:safetaxi_cameroun/core/network/api_client.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

/// Service de reconnaissance faciale pour vérification chauffeurs
/// 
/// Utilise le backend Django pour la vraie vérification faciale via AWS Rekognition
class BiometricService {
  final ImagePicker _imagePicker;
  final ApiClient _apiClient;

  BiometricService(this._apiClient) : _imagePicker = ImagePicker();

  /// Capture un selfie depuis la caméra
  Future<File?> captureSelfie() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        preferredCameraDevice: CameraDevice.front,
      );
      return image != null ? File(image.path) : null;
    } catch (e) {
      _log.e('Erreur capture selfie: $e');
      return null;
    }
  }

  /// Vérifie si le selfie correspond à la référence via le backend
  /// 
  /// Utilise l'endpoint backend /api/biometric/verify/ qui utilise AWS Rekognition
  Future<Map<String, dynamic>> verifyFaceMatch(File selfie, File reference) async {
    try {
      _log.i('Vérification faciale via backend AWS Rekognition');
      
      // Préparer les fichiers pour l'upload
      final selfieBytes = await selfie.readAsBytes();
      final referenceBytes = await reference.readAsBytes();

      final response = await _apiClient.postMultipart(
        '/biometric/verify/',
        files: {
          'selfie': MultipartFile.fromBytes(
            selfieBytes,
            filename: 'selfie.jpg',
          ),
          'reference': MultipartFile.fromBytes(
            referenceBytes,
            filename: 'reference.jpg',
          ),
        },
      );
      
      final data = response.data;
      _log.i('Réponse vérification faciale: $data');
      
      return {
        'match': data['match'] ?? false,
        'confidence': (data['confidence'] as num?)?.toDouble() ?? 0.0,
        'reason': data['reason'],
      };
    } catch (e) {
      _log.e('Erreur vérification faciale: $e');
      return {
        'match': false,
        'confidence': 0.0,
        'reason': 'Erreur lors de la vérification: $e',
      };
    }
  }

  /// Analyse basique de la qualité du selfie
  /// NOTE: Sans ML Kit local, cette fonction fait une vérification simple
  Future<Map<String, dynamic>> analyzeSelfieQuality(File imageFile) async {
    // Vérification basique - le fichier existe et a une taille raisonnable
    try {
      final bytes = await imageFile.readAsBytes();
      final isValidSize = bytes.length > 10000; // Au moins 10KB
      
      return {
        'valid': isValidSize,
        'is_centered': true, // Par défaut, on assume que c'est OK
        'eyes_open': true,
        'reason': isValidSize ? null : 'Image trop petite ou corrompue',
      };
    } catch (e) {
      return {
        'valid': false,
        'reason': 'Erreur lors de l\'analyse: $e',
      };
    }
  }

  void dispose() {
    // Plus rien à disposer sans ML Kit
  }
}

// Provider pour le service biométrique
final biometricServiceProvider = Provider<BiometricService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return BiometricService(apiClient);
});
