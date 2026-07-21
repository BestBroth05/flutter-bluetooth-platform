import 'package:bluetooth_platform/ble/domain/models/ble_connection_state.dart';
import 'package:bluetooth_platform/ble/domain/models/signal_strength.dart';
import 'package:bluetooth_platform/ble/infrastructure/fake/fake_ble_peripheral.dart';
import 'package:bluetooth_platform/ble/infrastructure/fake/fake_ble_transport.dart';
import 'package:bluetooth_platform/core/error/ble_failure.dart';
import 'package:bluetooth_platform/core/utils/clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FakeBleTransport', () {
    test('emits simulated devices while scanning', () async {
      final clock = FakeClock();
      final transport = FakeBleTransport(
        clock: clock,
        enableAutoTelemetry: false,
        peripherals: [
          FakeBlePeripheral(
            id: 'sensor-1',
            name: 'Sensor One',
            signalStrength: const SignalStrength(-60),
          ),
          FakeBlePeripheral(
            id: 'sensor-2',
            name: 'Sensor Two',
            signalStrength: const SignalStrength(-70),
          ),
        ],
      );

      final devicesFuture = transport.scanResults.take(2).toList();
      await transport.startScan(timeout: const Duration(milliseconds: 200));
      final devices = await devicesFuture;

      expect(devices.map((device) => device.id), <String>[
        'sensor-1',
        'sensor-2',
      ]);
      await transport.dispose();
    });

    test(
      'publishes connection state changes on connect and disconnect',
      () async {
        final clock = FakeClock();
        final transport = FakeBleTransport(
          clock: clock,
          enableAutoTelemetry: false,
          peripherals: [
            FakeBlePeripheral(
              id: 'sensor-1',
              name: 'Sensor One',
              signalStrength: const SignalStrength(-60),
              connectionDelay: Duration.zero,
            ),
          ],
        );

        final statesFuture = transport.connectionState
            .take(4)
            .toList();

        final connectFuture = transport.connect(
          'sensor-1',
          timeout: const Duration(seconds: 1),
        );
        await connectFuture;
        expect(transport.currentConnectionState, BleConnectionState.connected);
        expect(transport.connectedDeviceId, 'sensor-1');

        await transport.disconnect();
        expect(
          transport.currentConnectionState,
          BleConnectionState.disconnected,
        );

        final states = await statesFuture;
        expect(states, <BleConnectionState>[
          BleConnectionState.connecting,
          BleConnectionState.connected,
          BleConnectionState.disconnecting,
          BleConnectionState.disconnected,
        ]);
        await transport.dispose();
      },
    );

    test('can simulate connection timeout', () async {
      final clock = FakeClock();
      final transport = FakeBleTransport(
        clock: clock,
        enableAutoTelemetry: false,
        peripherals: [
          FakeBlePeripheral(
            id: 'sensor-1',
            name: 'Sensor One',
            signalStrength: const SignalStrength(-60),
          ),
        ],
      );

      transport.failNextConnectionWithTimeout();

      await expectLater(
        transport.connect(
          'sensor-1',
          timeout: const Duration(milliseconds: 30),
        ),
        throwsA(isA<ConnectionTimeoutFailure>()),
      );
      expect(transport.currentConnectionState, BleConnectionState.disconnected);
      await transport.dispose();
    });
  });
}
