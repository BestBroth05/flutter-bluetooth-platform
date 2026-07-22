import 'package:equatable/equatable.dart';

/// Stable reference to a GATT characteristic on the connected device.
final class CharacteristicRef extends Equatable {
  const CharacteristicRef({
    required this.serviceUuid,
    required this.characteristicUuid,
  });

  final String serviceUuid;
  final String characteristicUuid;

  @override
  List<Object?> get props => [serviceUuid, characteristicUuid];
}
