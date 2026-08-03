import 'package:flutter_test/flutter_test.dart';
import 'package:safetaxi_cameroun/features/trajet/presentation/screens/history_screen.dart';

void main() {
  group('History payload normalization', () {
    test('extracts trips from paginated results payload', () {
      final payload = {
        'results': [
          {'id': 1, 'status': 'completed'},
          {'id': 2, 'status': 'completed'},
        ],
      };

      final normalized = normalizeTripHistoryPayload(payload);

      expect(normalized, hasLength(2));
      expect(normalized.first['id'], 1);
    });

    test('supports a direct list payload', () {
      final payload = [
        {'id': 7, 'status': 'completed'},
      ];

      final normalized = normalizeTripHistoryPayload(payload);

      expect(normalized, hasLength(1));
      expect(normalized.first['id'], 7);
    });

    test('supports an alternative data field', () {
      final payload = {
        'data': [
          {'id': 9, 'status': 'completed'},
        ],
      };

      final normalized = normalizeTripHistoryPayload(payload);

      expect(normalized, hasLength(1));
      expect(normalized.first['id'], 9);
    });
  });
}
