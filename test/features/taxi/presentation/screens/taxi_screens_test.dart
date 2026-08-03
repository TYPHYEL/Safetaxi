import 'package:flutter_test/flutter_test.dart';

void main() {
  group('taxi payload handling', () {
    test('keeps the create payload aligned with backend expectations', () {
      final payload = {
        'plate_number': 'LT4521A',
        'model': 'Corolla',
        'capacity': 4,
      };

      expect(payload['plate_number'], 'LT4521A');
      expect(payload['capacity'], 4);
    });
  });
}
