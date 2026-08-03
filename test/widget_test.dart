import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safetaxi_cameroun/main.dart';
import 'test_helpers/fake_firebase_service.dart';
import 'package:safetaxi_cameroun/core/network/firebase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Override the notification service with a fake to avoid platform calls.
    firebaseNotificationService = FakeFirebaseService();
    // Still keep the flag for backwards compatibility
    disableFcmInTests = true;
  });

  testWidgets('SafeTaxi app boots with the main material app', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SafeTaxiApp()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(SafeTaxiApp), findsOneWidget);
  });
}
