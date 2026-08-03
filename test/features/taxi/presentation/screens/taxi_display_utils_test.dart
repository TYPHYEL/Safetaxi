import 'package:flutter_test/flutter_test.dart';
import 'package:safetaxi_cameroun/features/taxi/presentation/screens/taxi_display_utils.dart';

void main() {
  group('TaxiDisplayInfo', () {
    test('parses backend payloads with nested driver and owner data', () {
      final taxi = {
        'id': 7,
        'plate_number': 'LT4521A',
        'brand': 'Toyota',
        'model': 'Corolla',
        'color': 'Jaune',
        'is_active': true,
        'active_driver': {
          'user': {
            'first_name': 'Jean',
            'last_name': 'Ngolo',
          },
        },
        'owner': {
          'first_name': 'André',
          'last_name': 'Belinga',
        },
      };

      final info = TaxiDisplayInfo.fromMap(taxi);

      expect(info.plate, 'LT4521A');
      expect(info.label, 'Toyota Corolla • Jaune');
      expect(info.ownerName, 'André Belinga');
      expect(info.driverName, 'Jean Ngolo');
      expect(info.isActive, isTrue);
    });

    test('falls back to legacy field names when needed', () {
      final taxi = {
        'id': 8,
        'plate': 'CE2890B',
        'brand': 'Honda',
        'model': 'Civic',
        'color': 'Noir',
        'is_active': false,
      };

      final info = TaxiDisplayInfo.fromMap(taxi);

      expect(info.plate, 'CE2890B');
      expect(info.label, 'Honda Civic • Noir');
      expect(info.ownerName, '—');
      expect(info.driverName, '—');
      expect(info.isActive, isFalse);
    });
  });
}
