import 'package:bluetooth_platform/ble/application/ble_session_coordinator.dart';
import 'package:bluetooth_platform/ble/domain/models/ble_connection_state.dart';
import 'package:bluetooth_platform/ble/domain/models/ble_device.dart';
import 'package:bluetooth_platform/ble/domain/models/signal_strength.dart';
import 'package:bluetooth_platform/ble/domain/policies/reconnection_policy.dart';
import 'package:bluetooth_platform/ble/domain/policies/retry_policy.dart';
import 'package:bluetooth_platform/ble/domain/policies/timeout_policy.dart';
import 'package:bluetooth_platform/ble/domain/repositories/paired_device_store.dart';
import 'package:bluetooth_platform/ble/infrastructure/fake/fake_ble_peripheral.dart';
import 'package:bluetooth_platform/ble/infrastructure/fake/fake_ble_transport.dart';
import 'package:bluetooth_platform/ble/domain/models/paired_device.dart';
import 'package:bluetooth_platform/core/utils/clock.dart';
import 'package:bluetooth_platform/demo_protocol/demo_packet_framer.dart';
import 'package:flutter_test/flutter_test.dart';

final class InMemoryPairedDeviceStore implements PairedDeviceStore {
  final List<PairedDevice> devices = <PairedDevice>[];

  @override
  Future<void> clear() async => devices.clear();

  @override
  Future<List<PairedDevice>> loadAll() async =>
      List<PairedDevice>.from(devices);

  @override
  Future<void> remove(String deviceId) async {
    devices.removeWhere((device) => device.id == deviceId);
  }

  @override
  Future<void> save(PairedDevice device) async {
    devices
      ..removeWhere((item) => item.id == device.id)
      ..add(device);
  }
}

BleSessionCoordinator buildCoordinator(FakeBleTransport transport) {
  final clock = FakeClock();
  final retry = RetryPolicy(
    maxAttempts: 2,
    initialDelay: const Duration(milliseconds: 1),
    clock: clock,
  );
  return BleSessionCoordinator(
    transport: transport,
    pairedDeviceStore: InMemoryPairedDeviceStore(),
    packetFramer: DemoPacketFramer(),
    timeoutPolicy: const TimeoutPolicy(
      scanTimeout: Duration(milliseconds: 50),
      connectionTimeout: Duration(seconds: 1),
    ),
    retryPolicy: retry,
    reconnectionPolicy: ReconnectionPolicy(retryPolicy: retry, clock: clock),
    clock: clock,
  );
}

void main() {
  test('intentional disconnect does not auto-reconnect', () async {
    final transport = FakeBleTransport(
      clock: FakeClock(),
      enableAutoTelemetry: false,
      peripherals: [
        FakeBlePeripheral(
          id: 'sensor-1',
          name: 'Sensor One',
          signalStrength: const SignalStrength(-50),
          connectionDelay: Duration.zero,
        ),
      ],
    );
    final coordinator = buildCoordinator(transport);
    await coordinator.initialize();
    coordinator.autoReconnectEnabled = true;

    await coordinator.connect(
      const BleDevice(
        id: 'sensor-1',
        name: 'Sensor One',
        signalStrength: SignalStrength(-50),
      ),
    );
    expect(transport.currentConnectionState, BleConnectionState.connected);

    await coordinator.disconnect();
    await pumpEventQueue();

    expect(transport.currentConnectionState, BleConnectionState.disconnected);
    expect(transport.lastDisconnectWasIntentional, isTrue);
    await coordinator.dispose();
  });

  test('unexpected disconnect may trigger reconnection', () async {
    final clock = FakeClock();
    final transport = FakeBleTransport(
      clock: clock,
      enableAutoTelemetry: false,
      peripherals: [
        FakeBlePeripheral(
          id: 'sensor-1',
          name: 'Sensor One',
          signalStrength: const SignalStrength(-50),
          connectionDelay: Duration.zero,
        ),
      ],
    );
    final coordinator = buildCoordinator(transport);
    await coordinator.initialize();
    coordinator.autoReconnectEnabled = true;

    await coordinator.connect(
      const BleDevice(
        id: 'sensor-1',
        name: 'Sensor One',
        signalStrength: SignalStrength(-50),
      ),
    );

    await transport.simulateUnexpectedDisconnect();
    await pumpEventQueue();
    // Allow reconnect policy to run through FakeClock delays.
    await Future<void>.delayed(Duration.zero);
    await pumpEventQueue();

    expect(transport.currentConnectionState, BleConnectionState.connected);
    await coordinator.dispose();
  });

  test('switching transport disposes previous streams safely', () async {
    final first = FakeBleTransport(
      clock: FakeClock(),
      enableAutoTelemetry: false,
    );
    final second = FakeBleTransport(
      clock: FakeClock(),
      enableAutoTelemetry: false,
    );
    final coordinator = buildCoordinator(first);
    await coordinator.initialize();
    await coordinator.replaceTransport(second);
    expect(identical(coordinator.transport, second), isTrue);
    await coordinator.dispose();
  });
}
