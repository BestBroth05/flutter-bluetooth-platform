import '../../domain/models/battery_level.dart';
import '../../domain/models/ble_device.dart';
import '../../domain/models/gatt_models.dart';
import '../../domain/models/signal_strength.dart';
import '../../../demo_protocol/demo_protocol_constants.dart';

/// Simulated Bluetooth peripheral used by [FakeBleTransport].
final class FakeBlePeripheral {
  FakeBlePeripheral({
    required this.id,
    required this.name,
    required this.signalStrength,
    this.batteryLevel = const BatteryLevel(84),
    this.shouldFailConnection = false,
    this.connectionDelay = const Duration(milliseconds: 50),
  });

  final String id;
  final String name;
  SignalStrength signalStrength;
  BatteryLevel batteryLevel;
  bool shouldFailConnection;
  Duration connectionDelay;

  BleDevice toBleDevice() {
    return BleDevice(id: id, name: name, signalStrength: signalStrength);
  }

  List<GattService> get services => <GattService>[
    GattService(
      uuid: DemoProtocolConstants.demoServiceUuid,
      characteristics: const <GattCharacteristic>[
        GattCharacteristic(
          uuid: DemoProtocolConstants.demoCommandCharacteristicUuid,
          properties: GattCharacteristicProperties(
            canWrite: true,
            canWriteWithoutResponse: true,
          ),
        ),
        GattCharacteristic(
          uuid: DemoProtocolConstants.demoTelemetryCharacteristicUuid,
          properties: GattCharacteristicProperties(
            canNotify: true,
            canRead: true,
          ),
        ),
      ],
    ),
    // Standard Battery Service (0x180F) with Battery Level (0x2A19) for simulator demos.
    GattService(
      uuid: '0000180f-0000-1000-8000-00805f9b34fb',
      characteristics: <GattCharacteristic>[
        GattCharacteristic(
          uuid: '00002a19-0000-1000-8000-00805f9b34fb',
          properties: const GattCharacteristicProperties(canRead: true),
          lastValue: <int>[batteryLevel.percent],
        ),
      ],
    ),
  ];
}
