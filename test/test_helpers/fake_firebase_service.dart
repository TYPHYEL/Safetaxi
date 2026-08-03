import 'package:safetaxi_cameroun/core/network/firebase_service.dart';

class FakeFirebaseService implements FirebaseNotificationServiceBase {
  @override
  Future<void> init() async {
    // no-op for tests
    return;
  }

  @override
  Future<String?> getToken() async => 'fake-token';

  @override
  @override
  Future<void> subscribeToTopic(String topic) async {
    // no-op
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    // no-op
  }
}
