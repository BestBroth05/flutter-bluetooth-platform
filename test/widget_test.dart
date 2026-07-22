import 'package:bluetooth_platform/app.dart';
import 'package:bluetooth_platform/ble/infrastructure/fake/fake_ble_transport.dart';
import 'package:bluetooth_platform/ble/infrastructure/real/fake_permission_gateway.dart';
import 'package:bluetooth_platform/ble/domain/models/ble_adapter_state.dart';
import 'package:bluetooth_platform/ble/domain/permissions/ble_permission_status.dart';
import 'package:bluetooth_platform/core/utils/clock.dart';
import 'package:bluetooth_platform/di/injector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpApp(
    WidgetTester tester, {
    FakeBleTransport? transport,
    FakeBlePermissionGateway? permissions,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final bleTransport =
        transport ??
        FakeBleTransport(
          clock: const SystemClock(),
          enableAutoTelemetry: false,
        );
    await configureDependencies(
      sharedPreferences: prefs,
      bleTransport: bleTransport,
      permissionGateway:
          permissions ?? FakeBlePermissionGateway(BlePermissionStatus.granted),
    );
    await tester.pumpWidget(const BluetoothPlatformApp());
    await tester.pump();
  }

  testWidgets('simulator dashboard renders scan action', (tester) async {
    await pumpApp(tester);
    expect(find.text('Flutter Bluetooth Platform'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Discovered devices'), findsOneWidget);
  });

  testWidgets('shows permission-denied state', (tester) async {
    await pumpApp(
      tester,
      permissions: FakeBlePermissionGateway(BlePermissionStatus.denied),
    );
    expect(find.textContaining('Permission: denied'), findsOneWidget);
    expect(find.text('Permission missing'), findsOneWidget);
  });

  testWidgets('shows bluetooth-off adapter state', (tester) async {
    final transport = FakeBleTransport(
      clock: const SystemClock(),
      enableAutoTelemetry: false,
      initialAdapterState: BleAdapterState.off,
    );
    await pumpApp(tester, transport: transport);
    expect(find.textContaining('Adapter: off'), findsOneWidget);
    expect(find.text('Bluetooth is off'), findsOneWidget);
  });

  testWidgets('shows simulator and real mode controls', (tester) async {
    await pumpApp(tester);
    expect(find.text('Simulator'), findsOneWidget);
    expect(find.textContaining('Real'), findsWidgets);
    expect(find.text('Bluetooth readiness'), findsOneWidget);
    expect(find.text('Request permissions'), findsOneWidget);
  });
}
