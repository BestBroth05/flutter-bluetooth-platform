import 'ble_permission_status.dart';

/// Port for runtime Bluetooth permission checks and requests.
///
/// Implementations live in infrastructure and must not leak plugin types.
abstract class BlePermissionGateway {
  /// Current aggregated Bluetooth permission status for this platform.
  Future<BlePermissionStatus> status();

  /// Requests the permissions required for BLE central operations.
  Future<BlePermissionStatus> request();

  /// True when the OS requires the user to open system settings to recover.
  Future<bool> get isPermanentlyDenied;
}
