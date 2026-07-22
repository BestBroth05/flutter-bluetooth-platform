import 'package:bluetooth_platform/ble/domain/models/ble_adapter_state.dart';
import 'package:bluetooth_platform/ble/domain/models/ble_device.dart';
import 'package:bluetooth_platform/ble/domain/models/ble_scan_filter.dart';
import 'package:bluetooth_platform/ble/domain/models/signal_strength.dart';
import 'package:bluetooth_platform/ble/infrastructure/real/ble_adapter_monitor.dart';
import 'package:bluetooth_platform/ble/infrastructure/real/ble_platform_error_mapper.dart';
import 'package:bluetooth_platform/ble/infrastructure/real/ble_scan_filters.dart';
import 'package:bluetooth_platform/core/error/ble_failure.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BleAdapterMonitor', () {
    test('maps plugin adapter states', () {
      expect(
        BleAdapterMonitor.map(BluetoothAdapterState.on),
        BleAdapterState.on,
      );
      expect(
        BleAdapterMonitor.map(BluetoothAdapterState.off),
        BleAdapterState.off,
      );
      expect(
        BleAdapterMonitor.map(BluetoothAdapterState.unauthorized),
        BleAdapterState.unauthorized,
      );
      expect(
        BleAdapterMonitor.map(BluetoothAdapterState.unavailable),
        BleAdapterState.unsupported,
      );
    });
  });

  group('BleScanFilters', () {
    const device = BleDevice(
      id: 'abc',
      name: 'Demo Sensor Alpha',
      signalStrength: SignalStrength(-60),
    );

    test('deduplicates by id keeping latest', () {
      final first = <String, BleDevice>{};
      final withOne = BleScanFilters.upsert(first, device);
      final updated = BleScanFilters.upsert(
        withOne,
        device.copyWith(signalStrength: const SignalStrength(-40)),
      );
      expect(updated.length, 1);
      expect(updated['abc']!.signalStrength.rssiDbm, -40);
    });

    test('filters by name and rssi', () {
      expect(
        BleScanFilters.matches(
          device,
          const BleScanFilter(nameContains: 'alpha', minRssiDbm: -70),
        ),
        isTrue,
      );
      expect(
        BleScanFilters.matches(
          device,
          const BleScanFilter(nameContains: 'beta'),
        ),
        isFalse,
      );
      expect(
        BleScanFilters.matches(device, const BleScanFilter(minRssiDbm: -50)),
        isFalse,
      );
    });
  });

  group('BlePlatformErrorMapper', () {
    test('maps common plugin exception text', () {
      expect(
        BlePlatformErrorMapper.map(Exception('permission denied')),
        isA<PermissionDeniedFailure>(),
      );
      expect(
        BlePlatformErrorMapper.map(Exception('connection timeout')),
        isA<ConnectionTimeoutFailure>(),
      );
      expect(
        BlePlatformErrorMapper.map(Exception('write failed')),
        isA<WriteFailure>(),
      );
      expect(
        BlePlatformErrorMapper.map(Exception('poweredOff')),
        isA<AdapterOffFailure>(),
      );
    });
  });
}
