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
  const GattCharacteristic({required this.uuid, required this.properties});

  final String uuid;
  final GattCharacteristicProperties properties;

  @override
  List<Object?> get props => [uuid, properties];
}

/// Capability flags for a GATT characteristic.
final class GattCharacteristicProperties extends Equatable {
  const GattCharacteristicProperties({
    this.canRead = false,
    this.canWrite = false,
    this.canNotify = false,
    this.canIndicate = false,
  });

  final bool canRead;
  final bool canWrite;
  final bool canNotify;
  final bool canIndicate;

  @override
  List<Object?> get props => [canRead, canWrite, canNotify, canIndicate];
}
