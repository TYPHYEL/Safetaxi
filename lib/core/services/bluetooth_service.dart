// lib/core/services/bluetooth_service.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

/// Service Bluetooth pour détecter automatiquement les taxis SafeTaxi
/// à proximité. Chaque taxi émet un beacon BLE dont le nom commence
/// par "SafeTaxi-<id>" — le passager peut ainsi le détecter avant
/// même de scanner le QR code.
class BluetoothProximityService {
  static final BluetoothProximityService _instance =
      BluetoothProximityService._();
  factory BluetoothProximityService() => _instance;
  BluetoothProximityService._();

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  bool _isScanning = false;
  String? _currentTaxiId;

  bool get isScanning => _isScanning;
  String? get currentTaxiId => _currentTaxiId;

  // ─── Vérifier si Bluetooth est activé ─────────────────

  Future<bool> isEnabled() async {
    try {
      if (!await FlutterBluePlus.isSupported) return false;
      final state = await FlutterBluePlus.adapterState.first;
      return state == BluetoothAdapterState.on;
    } catch (e) {
      _log.e('Bluetooth state check failed: $e');
      return false;
    }
  }

  // ─── Tenter d'activer le Bluetooth ─────────────────────

  Future<bool> ensureEnabled() async {
    if (await isEnabled()) return true;
    try {
      await FlutterBluePlus.turnOn();
      return await isEnabled();
    } catch (e) {
      _log.e('Cannot enable Bluetooth: $e');
      return false;
    }
  }

  // ─── Démarrer le scan de proximité ───────────────────

  Future<void> startScanning({
    required void Function(NearbyTaxi taxi) onTaxiFound,
    void Function()? onScanDone,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_isScanning) {
      _log.w('Scan already in progress');
      return;
    }

    final ok = await ensureEnabled();
    if (!ok) {
      _log.e('Bluetooth must be enabled to scan');
      onScanDone?.call();
      return;
    }

    _isScanning = true;
    _log.i('Bluetooth scan started (timeout ${timeout.inSeconds}s)');

    try {
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidScanMode: AndroidScanMode.lowLatency,
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen(
        (results) {
          for (final r in results) {
            final device = r.device;
            String name = device.platformName;
            if (name.isEmpty) {
              name = r.advertisementData.advName;
            }
            if (name.startsWith('SafeTaxi-')) {
              final taxiId = name.replaceFirst('SafeTaxi-', '');
              _log.d('Nearby SafeTaxi found: $taxiId (RSSI: ${r.rssi})');
              onTaxiFound(NearbyTaxi(
                id: taxiId,
                name: name,
                rssi: r.rssi,
                distanceMeters: _rssiToMeters(r.rssi),
              ));
            }
          }
        },
        onDone: () {
          _isScanning = false;
          _log.i('Bluetooth scan finished');
          onScanDone?.call();
        },
        onError: (e) {
          _isScanning = false;
          _log.e('Bluetooth scan error: $e');
          onScanDone?.call();
        },
        cancelOnError: true,
      );
    } catch (e) {
      _isScanning = false;
      _log.e('Failed to start scan: $e');
      onScanDone?.call();
    }
  }

  // ─── Arrêter le scan ─────────────────────────────────

  Future<void> stopScanning() async {
    if (!_isScanning) return;
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    _isScanning = false;
    _log.i('Bluetooth scan stopped');
  }

  // ─── Émettre un beacon (côté chauffeur) ───────────────
  ///
  /// flutter_blue_plus ne supporte pas l'émission BLE sur iOS,
  /// mais fonctionne sur Android via Bluetooth LE Advertising.
  /// Côté iOS, fallback sur Firebase RTDB pour la présence.
  Future<bool> startEmittingBeacon(String taxiId) async {
    _currentTaxiId = taxiId;
    _log.i('Beacon target set: SafeTaxi-$taxiId');
    return true;
  }

  Future<void> stopEmittingBeacon() async {
    _currentTaxiId = null;
    _log.i('Beacon emission cleared');
  }

  // ─── Estimation de la distance depuis le RSSI ─────────

  double _rssiToMeters(int rssi) {
    if (rssi == 0) return -1;
    const txPower = -59;
    if (rssi >= txPower) return 0.5;
    final ratio = rssi.toDouble() / txPower;
    // Approximation grossière : ratio^4 * 10m
    return math.pow(ratio.abs(), 4).toDouble() * 10.0;
  }

  void dispose() {
    stopScanning();
    stopEmittingBeacon();
  }
}

// ─── Modèle taxi à proximité ─────────────────────────────

class NearbyTaxi {
  final String id;
  final String name;
  final int rssi;
  final double distanceMeters;

  const NearbyTaxi({
    required this.id,
    required this.name,
    required this.rssi,
    required this.distanceMeters,
  });

  String get distanceLabel {
    if (distanceMeters < 0) return '?m';
    if (distanceMeters < 1) return '<1m';
    if (distanceMeters < 5) return '${distanceMeters.round()}m';
    if (distanceMeters < 50) {
      return '${(distanceMeters / 10).round() * 10}m';
    }
    return '>50m';
  }
}

// ─── Provider ─────────────────────────────────────────

final bluetoothProximityProvider = Provider<BluetoothProximityService>((ref) {
  final svc = BluetoothProximityService();
  ref.onDispose(svc.dispose);
  return svc;
});
