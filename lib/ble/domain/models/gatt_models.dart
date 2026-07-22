import 'package:equatable/equatable.dart';

/// A GATT service exposed by a connected Bluetooth device.
final class GattService extends Equatable {
  const GattService({required this.uuid, required this.characteristics});

  final String uuid;
  final List<GattCharacteristic> characteristics;

  @override
  List<Object?> get props => [uuid, characteristics];
}

/// A GATT characteristic belonging to a [GattService].
final class GattCharacteristic extends Equatable {
  const GattCharacteristic({
    required this.uuid,
    required this.properties,
    this.lastValue = const <int>[],
  });

  final String uuid;
  final GattCharacteristicProperties properties;
  final List<int> lastValue;

  @override
  List<Object?> get props => [uuid, properties, lastValue];
}

/// Capability flags for a GATT characteristic.
final class GattCharacteristicProperties extends Equatable {
  const GattCharacteristicProperties({
    this.canRead = false,
    this.canWrite = false,
    this.canWriteWithoutResponse = false,
    this.canNotify = false,
    this.canIndicate = false,
  });

  final bool canRead;
  final bool canWrite;
  final bool canWriteWithoutResponse;
  final bool canNotify;
  final bool canIndicate;

  bool get canSubscribe => canNotify || canIndicate;

  @override
  List<Object?> get props => [
    canRead,
    canWrite,
    canWriteWithoutResponse,
    canNotify,
    canIndicate,
  ];
}
