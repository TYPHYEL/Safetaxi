import 'package:flutter_test/flutter_test.dart';
import 'package:safetaxi_cameroun/features/auth/data/models/user_model.dart';
import 'package:safetaxi_cameroun/features/auth/domain/entities/user_entity.dart';

void main() {
  group('UserModel.fromJson', () {
    test('parses numeric ids and nullable values safely', () {
      final json = <String, dynamic>{
        'id': 7,
        'phone': '+237690000000',
        'first_name': 'Alice',
        'last_name': 'Mballa',
        'photo_url': null,
        'role': 'passenger',
        'trust_score': 4.5,
        'is_verified': false,
        'is_active': true,
        'created_at': '2026-07-13T12:00:00.000Z',
      };

      final model = UserModel.fromJson(json);

      expect(model.id, '7');
      expect(model.phone, '+237690000000');
      expect(model.firstName, 'Alice');
      expect(model.lastName, 'Mballa');
      expect(model.photoUrl, isNull);
      expect(model.role, UserRole.passenger);
      expect(model.trustScore, 4.5);
      expect(model.isVerified, isFalse);
      expect(model.isActive, isTrue);
    });
  });
}
