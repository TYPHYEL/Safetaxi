import 'package:flutter_test/flutter_test.dart';
import 'package:safetaxi_cameroun/features/trajet/presentation/providers/trajet_provider.dart';

void main() {
  group('trip id parsing', () {
    test('coerces numeric ids from the backend into strings', () {
      expect(parseTripId(12), '12');
      expect(parseTripId('abc-42'), 'abc-42');
      expect(parseTripId(null), null);
    });
  });

  group('join code detection', () {
    test('recognizes manual join codes but not QR payloads', () {
      expect(isJoinCodeInput('AB12CD34'), isTrue);
      expect(isJoinCodeInput('ab12cd34'), isTrue);
      expect(isJoinCodeInput('safetaxi://taxi/1234'), isFalse);
      expect(isJoinCodeInput('1234'), isTrue);
    });
  });

  group('trip input normalization', () {
    test('extracts trip ids and selects the right join method', () {
      expect(extractTripIdFromInput('safetaxi://taxi/1234'), '1234');
      expect(extractTripIdFromInput('AB12CD34'), 'AB12CD34');
      expect(joinMethodForInput('safetaxi://taxi/1234'), 'qr');
      expect(joinMethodForInput('AB12CD34'), 'code');
    });
  });
}
