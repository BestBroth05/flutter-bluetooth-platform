import '../../domain/permissions/ble_permission_gateway.dart';
import '../../domain/permissions/ble_permission_status.dart';

/// Test double that always reports Bluetooth permissions as granted.
final class AlwaysGrantedBlePermissionGateway implements BlePermissionGateway {
  const AlwaysGrantedBlePermissionGateway();

  @override
  Future<BlePermissionStatus> status() async => BlePermissionStatus.granted;

  @override
  Future<BlePermissionStatus> request() async => BlePermissionStatus.granted;

  @override
  Future<bool> get isPermanentlyDenied async => false;
}
