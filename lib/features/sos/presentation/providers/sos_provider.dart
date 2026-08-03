// lib/features/sos/presentation/providers/sos_provider.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'package:safetaxi_cameroun/core/constants/app_constants.dart';
import 'package:safetaxi_cameroun/core/network/api_client.dart';

import 'package:safetaxi_cameroun/features/auth/presentation/providers/auth_provider.dart';
import 'package:firebase_database/firebase_database.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

// ─── Types d'alertes SOS ──────────────────────────────────

enum SosAlertType {
  aggression('Agression', 'aggression'),
  accident('Accident', 'accident'),
  medical('Urgence médicale', 'medical'),
  kidnapping('Enlèvement', 'kidnapping'),
  robbery('Vol / Braquage', 'robbery'),
  harassment('Harcèlement', 'harassment'),
  other('Autre', 'other');

  final String label;
  final String apiValue;
  const SosAlertType(this.label, this.apiValue);
}

// ─── État SOS ─────────────────────────────────────────────

enum SosStatus { idle, sending, sent, failed }

class SosState {
  final SosStatus status;
  final SosAlertType? alertType;
  final double? lat;
  final double? lng;
  final String? sosId;
  final String? error;
  final DateTime? sentAt;

  const SosState({
    this.status = SosStatus.idle,
    this.alertType,
    this.lat,
    this.lng,
    this.sosId,
    this.error,
    this.sentAt,
  });

  SosState copyWith({
    SosStatus? status,
    SosAlertType? alertType,
    double? lat,
    double? lng,
    String? sosId,
    String? error,
    DateTime? sentAt,
  }) =>
      SosState(
        status: status ?? this.status,
        alertType: alertType ?? this.alertType,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        sosId: sosId ?? this.sosId,
        error: error,
        sentAt: sentAt ?? this.sentAt,
      );
}

// ─── Contact d'urgence lu depuis le storage ───────────────

class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final String relation;

  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.relation,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
        relation: json['relation'] as String,
      );
}

// ─── Notifier SOS ─────────────────────────────────────────

class SosNotifier extends StateNotifier<SosState> {
  final ApiClient _api;
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  SosNotifier(this._api) : super(const SosState());

  // ─── Obtenir la position actuelle ──────────────────────

  Future<Position?> _getCurrentPosition() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      _log.e('Cannot get GPS position: $e');
      return null;
    }
  }

  // ─── Charger les contacts d'urgence ───────────────────

  Future<List<EmergencyContact>> _loadContacts() async {
    try {
      final raw = await _storage.read(key: 'emergency_contacts');
      if (raw == null) return [];
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map((e) => EmergencyContact.fromJson(e))
          .toList();
      return list;
    } catch (_) {
      return [];
    }
  }

  // ─── Déclencher le SOS ─────────────────────────────────
  ///
  ///流程 :
  /// 1. Obtenir la position GPS
  /// 2. Envoyer l'alerte à l'API backend
  /// 3. Sauvegarder dans Firebase Realtime
  /// 4. Envoyer des SMS aux contacts d'urgence
  /// 5. Notifier les autres utilisateurs SafeTaxi à proximité
  Future<void> triggerSos(SosAlertType type) async {
    state = state.copyWith(
      status: SosStatus.sending,
      alertType: type,
    );

    try {
      // 1. Position GPS
      final pos = await _getCurrentPosition();
      state = state.copyWith(
        lat: pos?.latitude,
        lng: pos?.longitude,
      );

      // 2. Envoyer à l'API backend
      final payload = {
        'alert_type': type.apiValue,
        if (pos != null) 'lat': pos.latitude,
        if (pos != null) 'lng': pos.longitude,
        if (pos != null) 'accuracy': pos.accuracy,
      };

      final resp = await _api.sendSos(payload);
      final sosId = resp.data['id'] as String?;

      state = state.copyWith(
        sosId: sosId,
        status: SosStatus.sent,
        sentAt: DateTime.now(),
      );

      // 3. Sauvegarder dans Firebase pour suivi en temps réel
      if (sosId != null) {
        await _saveToFirebase(sosId, type, pos);
      }

      // 4. Charger et alerter les contacts d'urgence
      await _alertEmergencyContacts(type, pos);

      // 5. Publier dans Firebase pour alerter les autres
      await _publishNearbyAlert(sosId, type, pos);

      _log.i('SOS triggered successfully: $sosId');
    } catch (e) {
      _log.e('SOS trigger failed: $e');
      state = state.copyWith(
        status: SosStatus.failed,
        error: e.toString(),
      );
    }
  }

  // ─── Sauvegarder dans Firebase ────────────────────────

  Future<void> _saveToFirebase(
      String sosId, SosAlertType type, Position? pos) async {
    try {
      await _db.ref('${AppConstants.firebaseSosPath}/$sosId').set({
        'alert_type': type.apiValue,
        'lat': pos?.latitude ?? 0,
        'lng': pos?.longitude ?? 0,
        'status': 'active',
        'created_at': ServerValue.timestamp,
      });
    } catch (_) {}
  }

  // ─── Alerter les contacts d'urgence ───────────────────

  Future<void> _alertEmergencyContacts(
      SosAlertType type, Position? pos) async {
    final contacts = await _loadContacts();
    if (contacts.isEmpty) return;

    final message = _buildSosMessage(type, pos);
    _log.d('Would send SMS to ${contacts.length} contacts: $message');

    // TODO: Intégrer un service SMS (Twilio, Africa's Talking, etc.)
    // Pour l'instant on log seulement
    for (final c in contacts) {
      _log.d('SOS → ${c.name} (${c.phone}): $message');
    }
  }

  String _buildSosMessage(SosAlertType type, Position? pos) {
    final typeLabel = type.label;
    final location = pos != null
        ? 'https://maps.google.com/?q=${pos.latitude},${pos.longitude}'
        : 'Position indisponible';

    return '⚠️ ALERTE SAFE TAXI\n'
        'Urgence: $typeLabel\n'
        'Localisation: $location\n'
        'Heure: ${DateTime.now().toLocal()}';
  }

  // ─── Publier pour alerter les utilisateurs à proximité ─

  Future<void> _publishNearbyAlert(
      String? sosId, SosAlertType type, Position? pos) async {
    if (sosId == null || pos == null) return;

    try {
      // Publier l'alerte dans la zone géographique
      // Les autres utilisateurs SafeTaxi dans la zone seront notifiés
      await _db.ref('${AppConstants.firebaseSosPath}/active').push().set({
        'id': sosId,
        'alert_type': type.apiValue,
        'lat': pos.latitude,
        'lng': pos.longitude,
        'radius_km': AppConstants.sosRadiusKm,
        'created_at': ServerValue.timestamp,
      });
    } catch (_) {}
  }

  // ─── Résoudre / Annuler un SOS ─────────────────────────

  Future<void> resolveSos() async {
    if (state.sosId == null) return;

    try {
      await _api.resolveSos(state.sosId!);
      await _db
          .ref('${AppConstants.firebaseSosPath}/${state.sosId}/status')
          .set('resolved');
    } catch (_) {}

    state = const SosState();
  }

  // ─── Reset ─────────────────────────────────────────────

  void reset() => state = const SosState();
}

// ─── Providers ────────────────────────────────────────────

final sosProvider = StateNotifierProvider<SosNotifier, SosState>((ref) {
  return SosNotifier(
    ref.watch(apiClientProvider),
  );
});

// ─── Stream des SOS actifs à proximité ───────────────────
// Utilisé par les chauffeurs pour être alertés des SOS

final nearbySosStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final db = FirebaseDatabase.instance;

  return db
      .ref('${AppConstants.firebaseSosPath}/active')
      .onValue
      .map((event) {
    final data = event.snapshot.value as Map<dynamic, dynamic>?;
    if (data == null) return [];

    return data.entries.map((e) {
      final v = e.value as Map<dynamic, dynamic>;
      return {
        'id': v['id'] ?? e.key,
        'alert_type': v['alert_type'],
        'lat': (v['lat'] as num?)?.toDouble() ?? 0,
        'lng': (v['lng'] as num?)?.toDouble() ?? 0,
        'radius_km': (v['radius_km'] as num?)?.toDouble() ?? 2.0,
        'created_at': v['created_at'],
      };
    }).toList();
  });
});
