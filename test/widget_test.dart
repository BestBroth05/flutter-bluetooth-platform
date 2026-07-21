import 'package:bluetooth_platform/app.dart';
import 'package:bluetooth_platform/ble/infrastructure/fake/fake_ble_transport.dart';
import 'package:bluetooth_platform/core/utils/clock.dart';
import 'package:bluetooth_platform/di/injector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    await configureDependencies(
      sharedPreferences: prefs,
      bleTransport: FakeBleTransport(
        clock: const SystemClock(),
        enableAutoTelemetry: false,
      ),
    );
  });

  testWidgets('simulator dashboard renders scan action', (tester) async {
    await tester.pumpWidget(const BluetoothPlatformApp());
    await tester.pump();

    expect(find.text('BLE Platform Simulator'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Discovered devices'), findsOneWidget);
  });
}
