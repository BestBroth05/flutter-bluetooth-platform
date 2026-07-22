import '../../domain/permissions/ble_permission_gateway.dart';
import '../../domain/permissions/ble_permission_status.dart';

/// Mutable permission gateway for widget and unit tests.
final class FakeBlePermissionGateway implements BlePermissionGateway {
  FakeBlePermissionGateway([this.current = BlePermissionStatus.denied]);

  BlePermissionStatus current;

  @override
  Future<BlePermissionStatus> status() async => current;

  @override
  Future<BlePermissionStatus> request() async {
    current = BlePermissionStatus.granted;
    return current;
  }

  @override
  Future<bool> get isPermanentlyDenied async =>
      current == BlePermissionStatus.permanentlyDenied;
}
