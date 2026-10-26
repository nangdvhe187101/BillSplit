import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/dio_client.dart';
import 'package:mobile/core/storage/local_storage_service.dart';
import 'package:mobile/main.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({});
  });

  testWidgets('App smoke test - verifies BillSplitApp renders', (WidgetTester tester) async {
    final localStorage = LocalStorageService();
    final dioClient = DioClient();

    await tester.pumpWidget(
      BillSplitApp(
        localStorage: localStorage,
        dioClient: dioClient,
      ),
    );

    // Kiểm tra widget root render thành công
    expect(find.byType(BillSplitApp), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
  });
}
