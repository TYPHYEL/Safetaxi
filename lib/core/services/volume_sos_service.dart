// lib/core/services/volume_sos_service.dart
// Service de détection SOS par triple pression bouton volume
// NOTE: Fonctionnalité désactivée car nécessite un plugin natif spécifique
// TODO: Implémenter via platform channel personnalisé si besoin

import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'settings_service.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

class VolumeSosService {
  static VolumeSosService? _instance;
  factory VolumeSosService() => _instance ??= VolumeSosService._();
  VolumeSosService._();

  Function()? _onSosTrigger;

  // Placeholder : nécessite l'intégration d'un plugin hardware_buttons
  void startListening(Function() onSosTrigger) {
    final enabled =
        SettingsService.read(SettingsService.kSosVolumeButton, true);
    if (!enabled) {
      _log.i('Volume SOS désactivé dans les paramètres');
      return;
    }

    _onSosTrigger = onSosTrigger;
    _log.w('Volume SOS : implémentation native requise (hardware_buttons)');
  }

  void _triggerSos() {
    _log.w('SOS DISCRET déclenché via bouton volume !');
    HapticFeedback.heavyImpact();
    _onSosTrigger?.call();
  }

  // ignore: unused_element
  void _exampleUsage() {
    // Exemple d'utilisation future :
    // startListening(() => triggerSosAlert());
    _triggerSos(); // Appelé quand 3 pressions volume détectées
  }

  void stopListening() {
    _log.i('Volume SOS arrêté');
  }

  void dispose() {
    stopListening();
  }
}
