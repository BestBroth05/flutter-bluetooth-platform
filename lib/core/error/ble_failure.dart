/// Typed failures for Bluetooth Low Energy operations.
///
/// These are generic portfolio failures and are not tied to any commercial
/// device protocol.
sealed class BleFailure implements Exception {
  const BleFailure(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class BluetoothUnavailableFailure extends BleFailure {
  const BluetoothUnavailableFailure([
    super.message = 'Bluetooth is not available on this platform.',
  ]);
}

final class PermissionDeniedFailure extends BleFailure {
  const PermissionDeniedFailure([
    super.message = 'Bluetooth permission was denied.',
  ]);
}

final class ScanFailure extends BleFailure {
  const ScanFailure([super.message = 'Bluetooth scan failed.']);
}

final class DeviceNotFoundFailure extends BleFailure {
  const DeviceNotFoundFailure([
    super.message = 'No matching Bluetooth device was found.',
  ]);
}

final class ConnectionFailure extends BleFailure {
  const ConnectionFailure([
    super.message = 'Failed to connect to the Bluetooth device.',
  ]);
}

final class ConnectionTimeoutFailure extends BleFailure {
  const ConnectionTimeoutFailure([
    super.message = 'Connection attempt timed out.',
  ]);
}

final class DisconnectionFailure extends BleFailure {
  const DisconnectionFailure([
    super.message = 'Failed to disconnect from the Bluetooth device.',
  ]);
}

final class ServiceDiscoveryFailure extends BleFailure {
  const ServiceDiscoveryFailure([
    super.message = 'GATT service discovery failed.',
  ]);
}

final class CharacteristicNotFoundFailure extends BleFailure {
  const CharacteristicNotFoundFailure([
    super.message = 'Required GATT characteristic was not found.',
  ]);
}

final class WriteFailure extends BleFailure {
  const WriteFailure([
    super.message = 'Failed to write to the GATT characteristic.',
  ]);
}

final class NotificationFailure extends BleFailure {
  const NotificationFailure([
    super.message = 'Failed to subscribe to notifications.',
  ]);
}

final class FramingFailure extends BleFailure {
  const FramingFailure([
    super.message = 'Failed to reassemble a telemetry packet.',
  ]);
}

final class PersistenceFailure extends BleFailure {
  const PersistenceFailure([
    super.message = 'Failed to persist paired device information.',
  ]);
}

final class CancelledFailure extends BleFailure {
  const CancelledFailure([super.message = 'The operation was cancelled.']);
}

final class UnexpectedBleFailure extends BleFailure {
  const UnexpectedBleFailure([
    super.message = 'An unexpected Bluetooth error occurred.',
  ]);
}
