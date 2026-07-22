import '../models/ble_adapter_state.dart';
import '../models/ble_command.dart';
import '../models/ble_connection_state.dart';
import '../models/ble_device.dart';
import '../models/ble_notification_event.dart';
import '../models/ble_scan_filter.dart';
import '../models/ble_write_type.dart';
import '../models/characteristic_ref.dart';
import '../models/gatt_models.dart';

/// Port for Bluetooth Low Energy transport operations.
///
/// Domain and application code depend on this interface so the concrete
/// adapter (fake simulator or real plugin adapter) can be swapped.
abstract class BleTransport {
  /// Emits discovered devices while a scan is active.
  Stream<BleDevice> get scanResults;

  /// Emits connection state transitions for the active session.
  Stream<BleConnectionState> get connectionState;

  /// Emits adapter readiness changes.
  Stream<BleAdapterState> get adapterState;

  /// Emits raw notification/indication events from subscribed characteristics.
  Stream<BleNotificationEvent> get notifications;

  BleConnectionState get currentConnectionState;

  BleAdapterState get currentAdapterState;

  String? get connectedDeviceId;

  bool get isScanning;

  /// False on platforms where real BLE central mode is unavailable.
  bool get supportsRealHardware;

  /// True when the most recent disconnect was requested by the user/app.
  bool get lastDisconnectWasIntentional;

  Future<void> startScan({
    Duration timeout = const Duration(seconds: 10),
    BleScanFilter filter = const BleScanFilter(),
  });

  Future<void> stopScan();

  Future<void> connect(
    String deviceId, {
    Duration timeout = const Duration(seconds: 15),
  });

  Future<void> disconnect();

  Future<List<GattService>> discoverServices();

  Future<List<int>> readCharacteristic(CharacteristicRef characteristic);

  Future<void> writeCharacteristic(
    CharacteristicRef characteristic,
    List<int> bytes, {
    BleWriteType writeType = BleWriteType.withResponse,
  });

  /// Convenience write used by the simulator demo command path.
  Future<void> writeCommand(BleCommand command);

  /// Simulator convenience: subscribe/unsubscribe the demo telemetry characteristic.
  Future<void> setNotificationsEnabled(bool enabled);

  Future<void> subscribe(CharacteristicRef characteristic);

  Future<void> unsubscribe(CharacteristicRef characteristic);

  Future<int> readRssi();

  Future<void> dispose();
}
