import '../models/ble_command.dart';
import '../models/ble_connection_state.dart';
import '../models/ble_device.dart';
import '../models/gatt_models.dart';

/// Port for Bluetooth Low Energy transport operations.
///
/// Domain and application code depend on this interface so the concrete
/// adapter (fake simulator or real `flutter_blue_plus`) can be swapped.
abstract class BleTransport {
  /// Emits discovered devices while a scan is active.
  Stream<BleDevice> get scanResults;

  /// Emits connection state transitions for the active session.
  Stream<BleConnectionState> get connectionState;

  /// Emits raw notification bytes from the telemetry characteristic.
  Stream<List<int>> get notifications;

  BleConnectionState get currentConnectionState;

  String? get connectedDeviceId;

  Future<void> startScan({Duration timeout = const Duration(seconds: 10)});

  Future<void> stopScan();

  Future<void> connect(
    String deviceId, {
    Duration timeout = const Duration(seconds: 15),
  });

  Future<void> disconnect();

  Future<List<GattService>> discoverServices();

  Future<void> writeCommand(BleCommand command);

  Future<void> setNotificationsEnabled(bool enabled);

  Future<void> dispose();
}
