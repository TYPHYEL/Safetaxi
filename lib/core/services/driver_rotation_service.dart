import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:safetaxi_cameroun/core/network/api_client.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/providers/auth_provider.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

/// Service de gestion des rotations de chauffeurs
/// 
/// Permet de gérer les horaires de travail des chauffeurs sur un taxi:
/// - Rotation jour/nuit
/// - Planning hebdomadaire
/// - Historique des rotations
/// - Activation/désactivation automatique
/// - Passation de service sécurisée avec biométrie
class DriverRotationService {
  final ApiClient _api;

  DriverRotationService(this._api);

  /// Crée une nouvelle rotation pour un chauffeur sur un taxi
  Future<Map<String, dynamic>> createRotation({
    required String taxiId,
    required String driverId,
    required String shiftType, // 'day', 'night', 'full'
    required List<int> daysOfWeek, // 1-7 (lundi-dimanche)
    required String startTime, // Format HH:mm
    required String endTime, // Format HH:mm
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final response = await _api.post('/rotations/', data: {
        'taxi': taxiId,
        'driver': driverId,
        'shift_type': shiftType,
        'days_of_week': daysOfWeek,
        'start_time': startTime,
        'end_time': endTime,
        if (startDate != null) 'start_date': startDate.toIso8601String(),
        if (endDate != null) 'end_date': endDate.toIso8601String(),
      });

      return response.data as Map<String, dynamic>;
    } catch (e) {
      _log.e('Erreur création rotation: $e');
      rethrow;
    }
  }

  /// Obtient toutes les rotations
  Future<List<Map<String, dynamic>>> getRotations() async {
    try {
      final response = await _api.get('/rotations/');
      return (response.data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      _log.e('Erreur récupération rotations: $e');
      return [];
    }
  }

  /// Active une rotation
  Future<void> activateRotation(String rotationId) async {
    try {
      await _api.post('/rotations/$rotationId/activate/');
    } catch (e) {
      _log.e('Erreur activation rotation: $e');
      rethrow;
    }
  }

  /// Désactive une rotation
  Future<void> deactivateRotation(String rotationId) async {
    try {
      await _api.post('/rotations/$rotationId/deactivate/');
    } catch (e) {
      _log.e('Erreur désactivation rotation: $e');
      rethrow;
    }
  }

  /// Crée une passation de service
  Future<Map<String, dynamic>> createHandoff({
    required String taxiId,
    required String incomingDriverId,
  }) async {
    try {
      final response = await _api.post('/handoffs/', data: {
        'taxi': taxiId,
        'incoming_driver': incomingDriverId,
      });
      return response.data as Map<String, dynamic>;
    } catch (e) {
      _log.e('Erreur création passation: $e');
      rethrow;
    }
  }

  /// Vérifie biométrie pour passation
  Future<Map<String, dynamic>> verifyHandoffBiometric({
    required String handoffId,
    required File outgoingSelfie,
    required File incomingSelfie,
  }) async {
    try {
      final outgoingBytes = await outgoingSelfie.readAsBytes();
      final incomingBytes = await incomingSelfie.readAsBytes();

      final response = await _api.postMultipart(
        '/handoffs/$handoffId/verify_biometric/',
        files: {
          'outgoing_selfie': MultipartFile.fromBytes(
            outgoingBytes,
            filename: 'outgoing.jpg',
          ),
          'incoming_selfie': MultipartFile.fromBytes(
            incomingBytes,
            filename: 'incoming.jpg',
          ),
        },
      );
      
      return response.data as Map<String, dynamic>;
    } catch (e) {
      _log.e('Erreur vérification biométrie: $e');
      rethrow;
    }
  }

  /// Complète une passation
  Future<void> completeHandoff({
    required String handoffId,
    required double lat,
    required double lng,
    double? odometer,
    double? fuelLevel,
    String? notes,
  }) async {
    try {
      await _api.post('/handoffs/$handoffId/complete/', data: {
        'lat': lat,
        'lng': lng,
        if (odometer != null) 'odometer': odometer,
        if (fuelLevel != null) 'fuel_level': fuelLevel,
        if (notes != null) 'notes': notes,
      });
    } catch (e) {
      _log.e('Erreur complétion passation: $e');
      rethrow;
    }
  }

  /// Annule une passation
  Future<void> cancelHandoff(String handoffId) async {
    try {
      await _api.post('/handoffs/$handoffId/cancel/');
    } catch (e) {
      _log.e('Erreur annulation passation: $e');
      rethrow;
    }
  }

  /// Obtient l'historique des shifts
  Future<List<Map<String, dynamic>>> getShiftHistory() async {
    try {
      final response = await _api.get('/shift-history/');
      return (response.data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      _log.e('Erreur historique shifts: $e');
      return [];
    }
  }

  /// Obtient le shift actif
  Future<Map<String, dynamic>?> getActiveShift() async {
    try {
      final response = await _api.get('/shift-history/active/');
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      _log.e('Erreur shift actif: $e');
      return null;
    }
  }

  /// Obtient les passations
  Future<List<Map<String, dynamic>>> getHandoffs() async {
    try {
      final response = await _api.get('/handoffs/');
      return (response.data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      _log.e('Erreur récupération passations: $e');
      return [];
    }
  }

  /// Helper: Convertit les jours de la semaine en noms
  static List<String> getDayNames(List<int> days) {
    const dayNames = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    return days.map((d) => dayNames[(d - 1) % 7]).toList();
  }

  /// Helper: Formate l'heure pour affichage
  static String formatTime(String time) {
    final parts = time.split(':');
    if (parts.length >= 2) {
      return '${parts[0]}h${parts[1]}';
    }
    return time;
  }

  /// Helper: Obtient le type de shift en français
  static String getShiftTypeLabel(String shiftType) {
    switch (shiftType.toLowerCase()) {
      case 'day':
        return 'Jour';
      case 'night':
        return 'Nuit';
      case 'full':
        return 'Complet';
      default:
        return shiftType;
    }
  }
}

final driverRotationServiceProvider = Provider<DriverRotationService>((ref) {
  final api = ref.watch(apiClientProvider);
  return DriverRotationService(api);
});
