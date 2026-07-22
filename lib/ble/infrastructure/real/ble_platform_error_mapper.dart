import '../../../core/error/ble_failure.dart';

/// Maps plugin/platform exceptions into domain [BleFailure] values.
abstract final class BlePlatformErrorMapper {
  static BleFailure map(
    Object error, {
    String fallbackMessage = 'An unexpected Bluetooth error occurred.',
  }) {
    if (error is BleFailure) {
      return error;
    }

    final text = error.toString().toLowerCase();

    if (text.contains('permission') || text.contains('unauthorized')) {
      return PermissionDeniedFailure(error.toString());
    }
    if (text.contains('timeout')) {
      return ConnectionTimeoutFailure(error.toString());
    }
    if (text.contains('not found') || text.contains('no device')) {
      return DeviceNotFoundFailure(error.toString());
    }
    if (text.contains('connect')) {
      return ConnectionFailure(error.toString());
    }
    if (text.contains('disconnect')) {
      return DisconnectionFailure(error.toString());
    }
    if (text.contains('service')) {
      return ServiceDiscoveryFailure(error.toString());
    }
    if (text.contains('characteristic')) {
      return CharacteristicNotFoundFailure(error.toString());
    }
    if (text.contains('write')) {
      return WriteFailure(error.toString());
    }
    if (text.contains('read')) {
      return ReadFailure(error.toString());
    }
    if (text.contains('notify') || text.contains('indicat')) {
      return NotificationFailure(error.toString());
    }
    if (text.contains('unsupported') || text.contains('not available')) {
      return BluetoothUnavailableFailure(error.toString());
    }
    if (text.contains('off') || text.contains('poweredoff')) {
      return AdapterOffFailure(error.toString());
    }

    return UnexpectedBleFailure(
      error.toString().isEmpty ? fallbackMessage : error.toString(),
    );
  }
}
