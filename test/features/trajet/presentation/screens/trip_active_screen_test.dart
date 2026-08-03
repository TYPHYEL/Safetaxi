import 'package:flutter_test/flutter_test.dart';
import 'package:safetaxi_cameroun/features/trajet/presentation/screens/trip_active_screen.dart';

void main() {
  group('trip preview formatting', () {
    test('returns a safe fallback for empty trip ids', () {
      expect(formatTripPreview(''), '—');
      expect(formatTripPreview('abcdefg'), 'abcdefg');
      expect(formatTripPreview('1234567890'), '12345678...');
    });
  });
}
