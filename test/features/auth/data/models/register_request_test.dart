import 'package:flutter_test/flutter_test.dart';
import 'package:safetaxi_cameroun/features/auth/data/models/user_model.dart';

void main() {
  test('RegisterRequest serializes the expected payload', () {
    const req = RegisterRequest(
      phone: '+237690000000',
      firstName: 'Alice',
      lastName: 'Mballa',
      role: 'passenger',
      email: 'alice@example.com',
      password: 'secret123',
    );

    final payload = req.toJson();

    expect(payload['phone'], '+237690000000');
    expect(payload['first_name'], 'Alice');
    expect(payload['last_name'], 'Mballa');
    expect(payload['role'], 'passenger');
    expect(payload['email'], 'alice@example.com');
    expect(payload['password'], 'secret123');
  });
}
